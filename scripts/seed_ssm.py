#!/usr/bin/env python3
"""Seed AWS SSM Parameter Store with per-service runtime config.

Reads a YAML file describing values per container, then upserts each into
SSM under /raksha/<env>/<container>/static/<KEY> (String) or
/raksha/<env>/<container>/secret/<KEY> (SecureString).

Values file (see config/ssm/raksha-ssm.example.yaml) is local-only and
gitignored — it never enters the repo. The raksha-ingestion-gateway and
peer service Terraform stacks read these parameters via
aws_ssm_parameters_by_path data sources, so a deploy picks up whatever
is in SSM at apply time.

Usage:
  ./seed_ssm.py --env dev --file ../config/ssm/raksha-ssm.dev.yaml
  ./seed_ssm.py --env dev --file ../config/ssm/raksha-ssm.dev.yaml --apply

Without --apply the script does a dry run and prints what would change.

Requires AWS CLI credentials with ssm:PutParameter on the target paths.
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    print("PyYAML is required: pip install pyyaml", file=sys.stderr)
    raise SystemExit(2)


def aws_cli(args: list[str], capture: bool = True) -> str:
    result = subprocess.run(
        ["aws", *args],
        check=False,
        capture_output=capture,
        text=True,
    )
    if result.returncode != 0:
        raise RuntimeError(f"aws {' '.join(args)} failed: {result.stderr.strip()}")
    return result.stdout


def get_existing(name: str) -> tuple[str | None, str | None]:
    """Return (current_value, current_type) or (None, None) if not present."""
    try:
        out = aws_cli([
            "ssm", "get-parameter",
            "--name", name,
            "--with-decryption",
            "--output", "json",
        ])
    except RuntimeError as exc:
        if "ParameterNotFound" in str(exc):
            return None, None
        raise
    p = json.loads(out)["Parameter"]
    return p.get("Value"), p.get("Type")


def put(name: str, value: str, kind: str, apply: bool) -> str:
    """Upsert one parameter. Returns one of: 'create', 'update', 'noop'."""
    current_value, current_type = get_existing(name)
    if current_value == value and current_type == kind:
        return "noop"
    action = "update" if current_value is not None else "create"
    if not apply:
        return action
    args = [
        "ssm", "put-parameter",
        "--name", name,
        "--type", kind,
        "--value", value,
        "--overwrite",
    ]
    aws_cli(args, capture=True)
    return action


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--env", required=True, help="Environment name (dev, stage, prod)")
    parser.add_argument("--file", required=True, type=Path, help="YAML values file")
    parser.add_argument("--apply", action="store_true", help="Actually write to SSM (without it, dry-run only)")
    args = parser.parse_args()

    if not args.file.is_file():
        print(f"file not found: {args.file}", file=sys.stderr)
        return 2

    spec = yaml.safe_load(args.file.read_text())
    if not isinstance(spec, dict):
        print("values file root must be a mapping of container name to {static, secret}", file=sys.stderr)
        return 2

    summary = {"create": 0, "update": 0, "noop": 0}
    for container, blocks in spec.items():
        if not isinstance(blocks, dict):
            print(f"skip {container}: expected mapping with 'static' and/or 'secret'", file=sys.stderr)
            continue
        for kind_label, ssm_type in (("static", "String"), ("secret", "SecureString")):
            entries = blocks.get(kind_label) or {}
            if not isinstance(entries, dict):
                print(f"skip {container}/{kind_label}: expected key/value mapping", file=sys.stderr)
                continue
            for key, value in entries.items():
                if value is None:
                    continue
                name = f"/raksha/{args.env}/{container}/{kind_label}/{key}"
                action = put(name, str(value), ssm_type, args.apply)
                summary[action] += 1
                marker = "[dry-run]" if not args.apply else ""
                print(f"{marker} {action:6s} {ssm_type:13s} {name}")

    print()
    print(f"create={summary['create']}  update={summary['update']}  noop={summary['noop']}")
    if not args.apply:
        print("(dry run — re-run with --apply to write changes)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
