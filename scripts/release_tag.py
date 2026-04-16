#!/usr/bin/env python3
"""Tag every release repo at a given ref.

Usage:
    scripts/release_tag.py v1.2.3 \
        [--workspace ~/workspace/blockchain/raksha-labs] \
        [--ref origin/master] \
        [--message "Release v1.2.3"] \
        [--push] [--dry-run] [--force] \
        [--only raksha-portal,raksha-engine] \
        [--exclude raksha-core] \
        [--roles runtime,contracts]

Behaviour per repo:
    1. git fetch --tags origin
    2. If <tag> already exists locally:
         - without --force → skip with note
         - with    --force → re-tag at <ref> (annotated, signed if --sign)
    3. git tag -a <tag> -m <message> <ref>     (default ref = origin/<primary_branch>)
    4. If --push → git push origin <tag> (or `--force` for retag).

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
    parser = argparse.ArgumentParser(description="Tag all release repos at a given ref.")
    parser.add_argument("tag", help="Tag name (e.g. v1.2.3).")
    parser.add_argument("--workspace", type=Path, default=DEFAULT_WORKSPACE,
                        help="Parent dir where the repos live as siblings (default: parent of raksha-deployments).")
    parser.add_argument("--ref", default=None,
                        help="Ref to tag. Default = origin/<primary_branch> per repo.")
    parser.add_argument("--message", default=None,
                        help="Annotated tag message. Default: 'Release <tag>'.")
    parser.add_argument("--sign", action="store_true", help="GPG-sign the tag (-s instead of -a).")
    parser.add_argument("--push", action="store_true", help="Push the tag to origin.")
    parser.add_argument("--force", action="store_true",
                        help="Re-tag if it already exists. Implies --force on push too.")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--only", default="", help="Comma-separated allowlist of repo names.")
    parser.add_argument("--exclude", default="", help="Comma-separated denylist of repo names.")
    parser.add_argument("--roles", default="",
                        help="Comma-separated role filter (runtime,contracts,deployments,infra,legacy).")
    parser.add_argument("--repos-file", type=Path, default=DEFAULT_REPOS_FILE)
    args = parser.parse_args()

    msg = args.message or f"Release {args.tag}"
    repos = load_repos(
        repos_file=args.repos_file,
        roles=[r for r in args.roles.split(",") if r] or None,
        only=[r for r in args.only.split(",") if r] or None,
        exclude=[r for r in args.exclude.split(",") if r] or None,
    )

    print(f"==> tagging '{args.tag}' across {len(repos)} repo(s) in {args.workspace}")
    if args.force:
        print("==> --force: existing tags will be overwritten")
    if args.dry_run:
        print("==> DRY RUN: no changes will be made")
    print()

    results: list[Result] = []
    tag_flag = "-s" if args.sign else "-a"

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

        ref = args.ref or f"origin/{repo.primary_branch}"

        rc, _ = run(["git", "fetch", "--tags", "origin"], path, args.dry_run)
        if rc != 0:
            results.append(Result(repo.name, False, "git fetch failed"))
            continue

        rc, _ = run(["git", "rev-parse", "--verify", "--quiet", f"refs/tags/{args.tag}"],
                    path, args.dry_run)
        tag_exists = rc == 0 and not args.dry_run

        if tag_exists and not args.force:
            results.append(Result(repo.name, True, "tag already exists; skipped"))
            continue

        if tag_exists and args.force:
            run(["git", "tag", "-d", args.tag], path, args.dry_run)

        rc, _ = run(["git", "tag", tag_flag, args.tag, "-m", msg, ref], path, args.dry_run)
        if rc != 0:
            results.append(Result(repo.name, False, f"tag failed at {ref}"))
            continue

        if args.push:
            push_cmd = ["git", "push", "origin", args.tag]
            if args.force:
                push_cmd.insert(2, "--force")
            rc, _ = run(push_cmd, path, args.dry_run)
            if rc != 0:
                results.append(Result(repo.name, False, "push failed"))
                continue
            results.append(Result(repo.name, True, f"tagged at {ref} + pushed"))
        else:
            results.append(Result(repo.name, True, f"tagged at {ref} (local only)"))

    return report(results)


if __name__ == "__main__":
    sys.exit(main())
