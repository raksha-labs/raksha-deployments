"""Shared helpers for release_branch.py and release_tag.py."""

from __future__ import annotations

import shlex
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

import yaml

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_REPOS_FILE = ROOT / "scripts" / "repos.yaml"
DEFAULT_WORKSPACE = ROOT.parent  # …/raksha-labs/


@dataclass
class Repo:
    name: str
    primary_branch: str
    role: str
    optional: bool = False


def load_repos(
    repos_file: Path = DEFAULT_REPOS_FILE,
    roles: Iterable[str] | None = None,
    only: Iterable[str] | None = None,
    exclude: Iterable[str] | None = None,
) -> list[Repo]:
    data = yaml.safe_load(repos_file.read_text(encoding="utf-8"))
    repos = [
        Repo(
            name=r["name"],
            primary_branch=r["primary_branch"],
            role=r["role"],
            optional=bool(r.get("optional", False)),
        )
        for r in data["repos"]
    ]
    if roles:
        rs = set(roles)
        repos = [r for r in repos if r.role in rs]
    if only:
        ns = set(only)
        repos = [r for r in repos if r.name in ns]
    if exclude:
        es = set(exclude)
        repos = [r for r in repos if r.name not in es]
    return repos


def repo_path(workspace: Path, repo: Repo) -> Path:
    return workspace / repo.name


@dataclass
class Result:
    repo: str
    ok: bool
    note: str


def run(cmd: list[str], cwd: Path, dry_run: bool) -> tuple[int, str]:
    pretty = " ".join(shlex.quote(c) for c in cmd)
    if dry_run:
        print(f"  DRY  $ {pretty}")
        return 0, ""
    print(f"  $ {pretty}")
    proc = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True)
    out = (proc.stdout or "") + (proc.stderr or "")
    if out.strip():
        for line in out.strip().splitlines():
            print(f"    {line}")
    return proc.returncode, out


def report(results: list[Result]) -> int:
    print()
    print("─" * 60)
    print(f"{'repo':32} status")
    print("─" * 60)
    failed = 0
    for r in results:
        marker = "✓" if r.ok else "✗"
        if not r.ok:
            failed += 1
        print(f"{r.repo:32} {marker}  {r.note}")
    print("─" * 60)
    if failed:
        print(f"{failed} repo(s) failed", file=sys.stderr)
    return 1 if failed else 0
