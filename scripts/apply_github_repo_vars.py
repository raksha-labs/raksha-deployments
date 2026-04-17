from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any


API_BASE = "https://api.github.com"


def load_config(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as handle:
        data = json.load(handle)
    if not isinstance(data, dict):
        raise ValueError("config root must be a JSON object")
    if not isinstance(data.get("owner"), str) or not data["owner"].strip():
        raise ValueError("config must contain a non-empty 'owner'")
    repos = data.get("repos")
    if not isinstance(repos, dict) or not repos:
        raise ValueError("config must contain a non-empty 'repos' object")
    return data


def request_json(
    method: str,
    url: str,
    token: str,
    payload: dict[str, Any] | None = None,
) -> tuple[int, str]:
    body = None
    headers = {
        "Accept": "application/vnd.github+json",
        "Authorization": f"Bearer {token}",
        "X-GitHub-Api-Version": "2022-11-28",
        "User-Agent": "raksha-deployments/apply_github_repo_vars.py",
    }
    if payload is not None:
        body = json.dumps(payload).encode("utf-8")
        headers["Content-Type"] = "application/json"

    request = urllib.request.Request(url, data=body, headers=headers, method=method)
    with urllib.request.urlopen(request) as response:
        return response.status, response.read().decode("utf-8")


def upsert_repo_variable(
    owner: str,
    repo: str,
    name: str,
    value: str,
    token: str,
    dry_run: bool,
) -> None:
    base_url = f"{API_BASE}/repos/{owner}/{repo}/actions/variables"
    payload = {"name": name, "value": value}

    if dry_run:
        print(f"[dry-run] set repo variable {owner}/{repo}:{name}={value}")
        return

    patch_url = f"{base_url}/{urllib.parse.quote(name, safe='')}"
    try:
        request_json("PATCH", patch_url, token, {"name": name, "value": value})
        print(f"updated repo variable {owner}/{repo}:{name}")
        return
    except urllib.error.HTTPError as exc:
        if exc.code != 404:
            detail = exc.read().decode("utf-8", errors="replace")
            raise RuntimeError(
                f"failed to update variable {owner}/{repo}:{name}: {exc.code} {detail}"
            ) from exc

    try:
        request_json("POST", base_url, token, payload)
        print(f"created repo variable {owner}/{repo}:{name}")
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(
            f"failed to create variable {owner}/{repo}:{name}: {exc.code} {detail}"
        ) from exc


def ensure_environment(owner: str, repo: str, environment: str, token: str, dry_run: bool) -> None:
    url = f"{API_BASE}/repos/{owner}/{repo}/environments/{urllib.parse.quote(environment, safe='')}"
    if dry_run:
        print(f"[dry-run] ensure environment {owner}/{repo}:{environment}")
        return
    try:
        request_json("PUT", url, token, {})
        print(f"ensured environment {owner}/{repo}:{environment}")
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(
            f"failed to ensure environment {owner}/{repo}:{environment}: {exc.code} {detail}"
        ) from exc


def iter_selected_repos(config: dict[str, Any], repo_filters: set[str]) -> list[tuple[str, dict[str, Any]]]:
    repos = []
    for repo_name, repo_cfg in config["repos"].items():
        if repo_filters and repo_name not in repo_filters:
            continue
        if not isinstance(repo_cfg, dict):
            raise ValueError(f"repo config for '{repo_name}' must be an object")
        repos.append((repo_name, repo_cfg))
    if repo_filters and not repos:
        raise ValueError(f"none of the requested repos exist in config: {sorted(repo_filters)}")
    return repos


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Apply GitHub repo variables and environments from one JSON config file."
    )
    parser.add_argument("--config", required=True, help="Path to JSON config file")
    parser.add_argument(
        "--repo",
        action="append",
        default=[],
        help="Limit to one or more repos from the config (repeatable)",
    )
    parser.add_argument(
        "--apply",
        action="store_true",
        help="Perform the changes. Without this flag the script runs in dry-run mode.",
    )
    args = parser.parse_args()

    config = load_config(Path(args.config))
    owner = config["owner"]
    defaults = config.get("defaults", {})
    default_envs = defaults.get("environments", [])
    if default_envs and not isinstance(default_envs, list):
        raise ValueError("'defaults.environments' must be a list if provided")

    token = os.getenv("GITHUB_TOKEN")
    dry_run = not args.apply
    if not dry_run and not token:
        raise ValueError("GITHUB_TOKEN must be set when using --apply")

    selected = iter_selected_repos(config, set(args.repo))
    for repo_name, repo_cfg in selected:
        envs = repo_cfg.get("environments", default_envs)
        if envs:
            if not isinstance(envs, list) or not all(isinstance(item, str) for item in envs):
                raise ValueError(f"repo '{repo_name}' has invalid 'environments' list")
            for env_name in envs:
                ensure_environment(owner, repo_name, env_name, token or "", dry_run)

        variables = repo_cfg.get("variables", {})
        if variables:
            if not isinstance(variables, dict):
                raise ValueError(f"repo '{repo_name}' has invalid 'variables' object")
            for name, value in variables.items():
                if not isinstance(value, str):
                    raise ValueError(
                        f"repo '{repo_name}' variable '{name}' must be a string value"
                    )
                if not value.strip():
                    print(f"skipping empty repo variable {owner}/{repo_name}:{name}")
                    continue
                upsert_repo_variable(owner, repo_name, name, value, token or "", dry_run)

        required_secrets = repo_cfg.get("required_secrets", [])
        if required_secrets:
            if not isinstance(required_secrets, list) or not all(
                isinstance(item, str) for item in required_secrets
            ):
                raise ValueError(f"repo '{repo_name}' has invalid 'required_secrets' list")
            print(f"required secrets for {owner}/{repo_name}: {', '.join(required_secrets)}")

    if dry_run:
        print("dry-run complete. Re-run with --apply to push repo variables/environments.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:  # pragma: no cover
        print(f"GitHub repo setup failed: {exc}", file=sys.stderr)
        raise SystemExit(1)
