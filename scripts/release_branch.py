#!/usr/bin/env python3
"""Cut a release branch from each repo's primary branch.

Usage:
    scripts/release_branch.py release/v1.2 \
        [--workspace ~/workspace/blockchain/raksha-labs] \
        [--from origin/master] \
        [--push] [--dry-run] \
        [--only raksha-portal,raksha-engine] \
        [--exclude raksha-core] \
        [--roles runtime,contracts]

Behaviour per repo:
    1. git fetch --tags origin
    2. If <branch> already exists locally → skip with note (idempotent).
    3. git checkout -B <branch> <from>      (default <from> = origin/<primary_branch>)
    4. If --push → git push -u origin <branch> (also idempotent: --force-with-lease NOT used)

Repos are processed independently; one failure does not abort the run.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from _release_common import (
    DEFAULT_REPOS_FILE,
    DEFAULT_WORKSPACE,
    Result,
    load_repos,
    report,
    repo_path,
    run,
)


def main() -> int:
    parser = argparse.ArgumentParser(description="Create a branch across all release repos.")
    parser.add_argument("branch", help="Branch name to create (e.g. release/v1.2).")
    parser.add_argument("--workspace", type=Path, default=DEFAULT_WORKSPACE,
                        help="Parent dir where the repos live as siblings (default: parent of raksha-deployments).")
    parser.add_argument("--from", dest="from_ref", default=None,
                        help="Ref to branch from. Default = origin/<primary_branch> per repo.")
    parser.add_argument("--push", action="store_true", help="Push the new branch to origin.")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--only", default="", help="Comma-separated allowlist of repo names.")
    parser.add_argument("--exclude", default="", help="Comma-separated denylist of repo names.")
    parser.add_argument("--roles", default="", help="Comma-separated role filter (runtime,contracts,deployments,infra,legacy).")
    parser.add_argument("--repos-file", type=Path, default=DEFAULT_REPOS_FILE)
    args = parser.parse_args()

    repos = load_repos(
        repos_file=args.repos_file,
        roles=[r for r in args.roles.split(",") if r] or None,
        only=[r for r in args.only.split(",") if r] or None,
        exclude=[r for r in args.exclude.split(",") if r] or None,
    )

    print(f"==> creating branch '{args.branch}' across {len(repos)} repo(s) in {args.workspace}")
    if args.dry_run:
        print("==> DRY RUN: no changes will be made")
    print()

    results: list[Result] = []

    for repo in repos:
        path = repo_path(args.workspace, repo)
        print(f"── {repo.name}")
        if not path.exists():
            note = "directory missing"
            if repo.optional:
                results.append(Result(repo.name, True, f"skipped ({note}, optional)"))
            else:
                results.append(Result(repo.name, False, note))
            continue

        from_ref = args.from_ref or f"origin/{repo.primary_branch}"

        rc, _ = run(["git", "fetch", "--tags", "origin"], path, args.dry_run)
        if rc != 0:
            results.append(Result(repo.name, False, "git fetch failed"))
            continue

        rc, out = run(["git", "rev-parse", "--verify", "--quiet", f"refs/heads/{args.branch}"],
                      path, args.dry_run)
        if rc == 0 and not args.dry_run:
            results.append(Result(repo.name, True, f"branch already exists; skipped"))
            if args.push:
                run(["git", "push", "-u", "origin", args.branch], path, args.dry_run)
            continue

        rc, _ = run(["git", "checkout", "-B", args.branch, from_ref], path, args.dry_run)
        if rc != 0:
            results.append(Result(repo.name, False, f"checkout from {from_ref} failed"))
            continue

        if args.push:
            rc, _ = run(["git", "push", "-u", "origin", args.branch], path, args.dry_run)
            if rc != 0:
                results.append(Result(repo.name, False, "push failed"))
                continue
            results.append(Result(repo.name, True, f"created from {from_ref} + pushed"))
        else:
            results.append(Result(repo.name, True, f"created from {from_ref} (local only)"))

    return report(results)


if __name__ == "__main__":
    sys.exit(main())
