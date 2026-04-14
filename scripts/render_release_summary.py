from __future__ import annotations

from pathlib import Path

import yaml


ROOT = Path(__file__).resolve().parents[1]
ENVIRONMENTS = ("dev", "stage", "prod")


def load_yaml(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as handle:
        return yaml.safe_load(handle)


def main() -> int:
    print("# Release Summary")
    print()

    catalog = load_yaml(ROOT / "catalog" / "services.yaml")
    catalog_index = {item["name"]: item for item in catalog["services"]}

    for environment in ENVIRONMENTS:
      manifest = load_yaml(ROOT / "environments" / environment / "services.yaml")
      print(f"## {environment}")
      print()
      print("| Service | Source Repo | Image Repo | Image Tag | Desired Count | Strategy |")
      print("| --- | --- | --- | --- | ---: | --- |")
      for service_name, config in manifest["services"].items():
          source_repo = catalog_index[service_name]["source_repo"]
          image_repo = catalog_index[service_name]["image_repo"]
          print(
              f"| {service_name} | {source_repo} | {image_repo} | "
              f"{config['image_tag']} | {config['desired_count']} | {config['strategy']} |"
          )
      print()

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
