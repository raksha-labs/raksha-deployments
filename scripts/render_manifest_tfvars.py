from __future__ import annotations

from argparse import ArgumentParser
from pathlib import Path
import sys

import yaml


ROOT = Path(__file__).resolve().parents[1]
SUPPORTED_STRATEGIES = {"rolling"}


def load_yaml(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as handle:
        return yaml.safe_load(handle)


def parse_mapping(raw: str) -> tuple[str, str, str]:
    parts = raw.split(":")
    if len(parts) != 3 or not all(parts):
        raise ValueError(
            f"invalid service mapping '{raw}'; expected service:image_var:desired_count_var"
        )
    return parts[0], parts[1], parts[2]


def assign_var(target: dict[str, str], name: str, value: str) -> None:
    rendered = str(value)
    if name in target and target[name] != rendered:
        raise ValueError(
            f"conflicting values for tf var '{name}': '{target[name]}' vs '{rendered}'"
        )
    target[name] = rendered


def main() -> int:
    parser = ArgumentParser(description="Render Terraform -var lines from an environment manifest.")
    parser.add_argument("--environment", required=True, choices=("dev", "stage", "prod"))
    parser.add_argument(
        "--service",
        action="append",
        default=[],
        help="Mapping in the form service:image_var:desired_count_var.",
    )
    parser.add_argument(
        "--image-tag-override",
        default="",
        help="Optional image tag override applied to every mapped service.",
    )
    args = parser.parse_args()

    if not args.service:
        raise ValueError("at least one --service mapping is required")

    manifest_path = ROOT / "environments" / args.environment / "services.yaml"
    manifest = load_yaml(manifest_path)
    services = manifest.get("services")
    if not isinstance(services, dict):
        raise ValueError(f"{manifest_path}: expected a 'services' mapping")

    tf_vars: dict[str, str] = {}
    override_tag = args.image_tag_override.strip()

    for raw_mapping in args.service:
        service_name, image_var, desired_count_var = parse_mapping(raw_mapping)
        config = services.get(service_name)
        if not isinstance(config, dict):
            raise ValueError(f"{manifest_path}: missing service '{service_name}'")

        strategy = config.get("strategy")
        if strategy not in SUPPORTED_STRATEGIES:
            supported = ", ".join(sorted(SUPPORTED_STRATEGIES))
            raise ValueError(
                f"{manifest_path}: service '{service_name}' uses unsupported strategy "
                f"'{strategy}' (supported: {supported})"
            )

        image_tag = override_tag or config.get("image_tag")
        if not image_tag:
            raise ValueError(f"{manifest_path}: service '{service_name}' is missing image_tag")

        desired_count = config.get("desired_count")
        if not isinstance(desired_count, int) or desired_count < 1:
            raise ValueError(
                f"{manifest_path}: service '{service_name}' has invalid desired_count '{desired_count}'"
            )

        assign_var(tf_vars, image_var, image_tag)
        assign_var(tf_vars, desired_count_var, desired_count)

    for name, value in tf_vars.items():
        print(f"{name}={value}")

    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:  # pragma: no cover
        print(f"Manifest rendering failed: {exc}", file=sys.stderr)
        raise SystemExit(1)
