from __future__ import annotations

from argparse import ArgumentParser
from pathlib import Path
import sys

import yaml


ROOT = Path(__file__).resolve().parents[1]


def load_yaml(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as handle:
        return yaml.safe_load(handle)


def write_yaml(path: Path, data: dict) -> None:
    with path.open("w", encoding="utf-8") as handle:
        yaml.safe_dump(data, handle, sort_keys=False)


def main() -> int:
    parser = ArgumentParser(description="Promote a service image tag in an environment manifest.")
    parser.add_argument("--environment", required=True, choices=("dev", "stage", "prod"))
    parser.add_argument("--service", required=True)
    parser.add_argument("--image-tag", required=True)
    args = parser.parse_args()

    catalog = load_yaml(ROOT / "catalog" / "services.yaml")
    known_services = {item["name"] for item in catalog["services"]}
    if args.service not in known_services:
        raise ValueError(f"unknown service '{args.service}'")

    manifest_path = ROOT / "environments" / args.environment / "services.yaml"
    manifest = load_yaml(manifest_path)

    if args.service not in manifest["services"]:
        raise ValueError(f"service '{args.service}' is missing from {manifest_path}")

    manifest["services"][args.service]["image_tag"] = args.image_tag
    write_yaml(manifest_path, manifest)
    print(f"Updated {args.service} in {args.environment} to image tag {args.image_tag}.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:  # pragma: no cover
        print(f"Promotion failed: {exc}", file=sys.stderr)
        raise SystemExit(1)
