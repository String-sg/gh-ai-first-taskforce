# Harness

Pre-commit and pre-push hook scaffolding for the AI-First Taskforce harness.

## Setup

Install the `gh` extension from the repo root, then run setup inside any target repo:

```sh
gh extension install transformteamsg/ai-first-taskforce
cd /path/to/your-repo
gh ai-first-taskforce setup
```

Setup will:
1. Detect the repo type (`js` / `mixed` Go+JS — pure Go is not supported in v1)
2. Detect the package manager from the lockfile (`pnpm-lock.yaml` → pnpm, `bun.lockb`/`bun.lock` → bun)
3. Install Husky if not already present
4. Create `.husky/pre-commit` and `.husky/pre-push` if they don't exist
5. Merge the NVM preamble block into both hooks

Setup is safe to re-run — it merges rather than overwrites, and never duplicates content.

## Supported repos

| Repo type | Detected by | Supported |
|-----------|-------------|-----------|
| JS / TS | `package.json` only | ✅ |
| Mixed (Go + JS/TS) | `package.json` + `go.mod` | ✅ |
| Pure Go | `go.mod` only | ❌ v1 out of scope |

| Package manager | Detected by | Supported |
|-----------------|-------------|-----------|
| pnpm | `pnpm-lock.yaml` | ✅ |
| bun | `bun.lockb` / `bun.lock` | ✅ |
| npm / yarn | `package-lock.json` / `yarn.lock` | ❌ |

## Merge behaviour

Each harness rule is wrapped in sentinel comments:

```sh
# harness:<block-id>:begin
... rule content ...
# harness:<block-id>:end
```

`setup` checks for the sentinel before inserting. If it already exists, the block is skipped. This means:
- Re-running setup is always safe
- Existing team hooks are preserved
- Future stories (#9–#12) append their own sentinel blocks using the same mechanism

## Directory structure

```
harness/
  setup.sh          # Orchestrator — called by gh-ai-first-taskforce
  lib/
    detect-language.sh          # detect_language <dir>
    detect-package-manager.sh   # detect_package_manager <dir>
    merge-hook.sh               # merge_block, ensure_hook_exists
    husky.sh                    # ensure_husky_installed, ensure_husky_init
```

## Running tests

Requires [bats-core](https://github.com/bats-core/bats-core):

```sh
brew install bats-core
bats tests/harness/
```
