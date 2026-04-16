# Coordinated release scripts

Two scripts in `scripts/` cut release branches and tag every relevant repo
in one shot. The list of repos lives in [`scripts/repos.yaml`](../scripts/repos.yaml)
— add or remove repos there, never hard-code in the scripts.

Both scripts assume sibling-repo layout:

```
~/workspace/raksha-labs/
├── raksha-deployments/      ← scripts run from here
├── raksha-portal/
├── raksha-engine/
├── raksha-notifier-gateway/
├── raksha-ingestion-gateway/
├── raksha-contracts/
├── raksha-foundation-infra/
└── raksha-core/             (optional)
```

Override with `--workspace /some/other/path` if your checkout is elsewhere.

## Cut a release branch

```bash
# Local only — safe to inspect before pushing
python3 scripts/release_branch.py release/v1.2 --dry-run
python3 scripts/release_branch.py release/v1.2

# Local + push to origin
python3 scripts/release_branch.py release/v1.2 --push

# Only some repos
python3 scripts/release_branch.py release/v1.2 --push \
    --only raksha-portal,raksha-engine

# Only certain roles (runtime|contracts|deployments|infra|legacy)
python3 scripts/release_branch.py release/v1.2 --push --roles runtime,contracts

# Branch from a specific ref (default = origin/<primary_branch>)
python3 scripts/release_branch.py hotfix/v1.1.1 --from v1.1.0 --push
```

Idempotent: if the branch already exists locally, that repo is skipped (the
push is still attempted if `--push` is given).

## Tag a release

```bash
# Local only
python3 scripts/release_tag.py v1.2.0

# Local + push
python3 scripts/release_tag.py v1.2.0 --push

# Tag every repo on the release branch instead of master
python3 scripts/release_tag.py v1.2.0 --ref origin/release/v1.2 --push

# GPG-sign the tag
python3 scripts/release_tag.py v1.2.0 --sign --push

# Re-tag (force) if you fat-fingered the previous tag
python3 scripts/release_tag.py v1.2.0 --force --push
```

The default tag message is `Release <tag>`; override with
`--message "Release v1.2.0 — adds notifier dispatch v2"`.

## Typical release flow

```bash
# 1. Cut release branch from master across the whole org
python3 scripts/release_branch.py release/v1.2 --push

# 2. Bake / smoke / test on those branches in CI

# 3. Once green, tag the SHA on each release branch
python3 scripts/release_tag.py v1.2.0 \
    --ref origin/release/v1.2 \
    --message "Release v1.2.0" \
    --push

# 4. Trigger deployments (each repo's deploy.yml or the central
#    dispatch-deploy.yml in raksha-deployments) with image_tag=v1.2.0
```

## Exit codes

Both scripts process repos independently and print a summary table at the
end. They exit `1` if any repo failed, `0` otherwise — safe to use in CI
without partial-success masking.
