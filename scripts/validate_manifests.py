from __future__ import annotations

from pathlib import Path
import sys

import yaml


ROOT = Path(__file__).resolve().parents[1]
CATALOG_PATH = ROOT / "catalog" / "services.yaml"
ENVIRONMENTS = ("dev", "stage", "prod")
ALLOWED_STRATEGIES = {"rolling"}


def load_yaml(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as handle:
        return yaml.safe_load(handle)


def validate_catalog(catalog: dict) -> set[str]:
    services = catalog.get("services")
    if not isinstance(services, list) or not services:
        raise ValueError("catalog/services.yaml must contain a non-empty 'services' list")

    names: list[str] = []
    for item in services:
        if not isinstance(item, dict) or not item.get("name"):
            raise ValueError("each catalog service entry must contain a non-empty 'name'")
        names.append(str(item["name"]))

    duplicates = {name for name in names if names.count(name) > 1}
    if duplicates:
        raise ValueError(f"duplicate service names in catalog: {sorted(duplicates)}")

    return set(names)


def validate_environment(environment: str, expected_services: set[str]) -> None:
    path = ROOT / "environments" / environment / "services.yaml"
    data = load_yaml(path)

    declared_environment = data.get("environment")
    if declared_environment != environment:
        raise ValueError(f"{path}: expected environment '{environment}', found '{declared_environment}'")

    services = data.get("services")
    if not isinstance(services, dict) or not services:
        raise ValueError(f"{path}: 'services' must be a non-empty mapping")

    service_names = set(services.keys())
    missing = expected_services - service_names
    extra = service_names - expected_services

    if missing:
        raise ValueError(f"{path}: missing services {sorted(missing)}")
    if extra:
        raise ValueError(f"{path}: contains unknown services {sorted(extra)}")

    for name, config in services.items():
        if not isinstance(config, dict):
            raise ValueError(f"{path}: service '{name}' must map to an object")
        for key in ("image_tag", "desired_count", "strategy", "config_profile"):
            if key not in config:
                raise ValueError(f"{path}: service '{name}' is missing '{key}'")
        if not isinstance(config["desired_count"], int) or config["desired_count"] < 1:
            raise ValueError(f"{path}: service '{name}' must have desired_count >= 1")
        if config["strategy"] not in ALLOWED_STRATEGIES:
            raise ValueError(
                f"{path}: service '{name}' has unsupported strategy '{config['strategy']}'"
            )
        if config["config_profile"] != environment:
            raise ValueError(
                f"{path}: service '{name}' must use config_profile '{environment}', "
                f"found '{config['config_profile']}'"
            )


def main() -> int:
    catalog = load_yaml(CATALOG_PATH)
    service_names = validate_catalog(catalog)

    for environment in ENVIRONMENTS:
        validate_environment(environment, service_names)

    print("Deployment manifests are valid.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:  # pragma: no cover
        print(f"Validation failed: {exc}", file=sys.stderr)
        raise SystemExit(1)
