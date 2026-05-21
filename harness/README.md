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

## CI workflow scaffolding

Setup installs a dedicated GitHub Actions workflow into the target repo:

```
.github/
  workflows/
    harness-checks.yml   # owned by harness — do not edit manually
  harness-manifest.json  # lockfile — tracks installed checksums
```

`harness-checks.yml` is installed on first run and updated only when the harness template changes (delta update via `harness-manifest.json`). Re-running setup is always safe.

### Overlap detection

If any existing workflow in `.github/workflows/` contains checks that harness will own (ESLint, Prettier, tsc, golangci-lint, or gitleaks), setup prints a warning with migration guidance:

```
WARNING: ci.yml contains checks that harness will own.
  To migrate: remove those steps from ci.yml and re-run setup.
  harness-checks.yml will run the same checks automatically.
```

Harness never modifies team-owned workflow files.

## Linting

Setup installs linting tools and default configs if absent, then merges lint hooks into `.husky/pre-commit`.

### JS / TS repos

- Installs `eslint` and `lint-staged` as dev dependencies (if not already present)
- Writes a default `.eslintrc.json` (extends `eslint:recommended`) if no ESLint config file exists
- Writes a default `.lintstagedrc.json` targeting `*.{js,jsx,ts,tsx}` files if no lint-staged config exists
- Merges a `harness:lint` pre-commit block that runs `npx lint-staged` on staged files

### Mixed (Go + JS/TS) repos

All of the above, plus:

- Checks for `golangci-lint` in PATH; installs via `go install` if absent
- Writes a default `.golangci.yml` (enables errcheck, gosimple, govet, ineffassign, staticcheck, unused) if none exists
- Merges a `harness:golangci` pre-commit block that runs `golangci-lint run ./...` when staged `.go` files are present

Lint failure exits non-zero and outputs which files failed — the commit is blocked.

### Required status check

The CI workflow job is named `harness / checks`. To enforce linting on PRs, configure it as a required status check in GitHub repository settings:

```
Settings → Branches → Branch protection rules → Require status checks to pass → harness / checks
```

Or via the GitHub CLI (requires repo admin):

```sh
gh api repos/{owner}/{repo}/branches/main/protection \
  --method PUT \
  --field required_status_checks='{"strict":true,"contexts":["harness / checks"]}' \
  --field enforce_admins=false \
  --field required_pull_request_reviews=null \
  --field restrictions=null
```

## Directory structure

```
harness/
  setup.sh          # Orchestrator — called by gh-ai-first-taskforce
  lib/
    detect-language.sh          # detect_language <dir>
    detect-package-manager.sh   # detect_package_manager <dir>
    merge-hook.sh               # merge_block, ensure_hook_exists
    husky.sh                    # ensure_husky_installed, ensure_husky_init
    ci-workflows.sh             # install_workflow_file, detect_overlapping_workflows
    lint.sh                     # ensure_eslint_installed, ensure_golangci_lint_available, install_lint_staged_hook, install_golangci_hook
  workflows/
    harness-checks.yml          # base template (test fixture)
    harness-checks-js.yml       # installed for JS/TS repos
    harness-checks-mixed.yml    # installed for Go+JS/TS repos
```

## Running tests

Requires [bats-core](https://github.com/bats-core/bats-core):

```sh
brew install bats-core
bats tests/harness/
```
