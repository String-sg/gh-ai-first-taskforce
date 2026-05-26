# Harness

Pre-commit and pre-push hook scaffolding for the AI-First Taskforce harness.

## Setup

Clone the repo, install the `gh` extension from the local clone, then run setup inside any target repo:

```sh
git clone https://github.com/transformteamsg/ai-first-taskforce.git
gh extension install ./ai-first-taskforce
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
| Pure Go | `go.mod` only | ⚠️ gitleaks only (Husky checks not supported in v1) |

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

Setup generates and installs a dedicated GitHub Actions workflow into the target repo. The workflow is crafted on the fly for the detected repo type (JS/TS or mixed) and package manager (pnpm or bun) — no runtime detection in CI:

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
- Merges a `harness:lint` pre-commit block that runs lint-staged on staged files using the detected package manager (`pnpm lint-staged`, `bun run lint-staged`, or `npx lint-staged`)

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

## Formatting

Setup installs formatting tools and default configs if absent, then merges format hooks into `.husky/pre-commit`.

### JS / TS repos

- Installs `prettier` as a dev dependency (if not already present)
- If `tailwindcss` is detected in `package.json`, also installs `prettier-plugin-tailwindcss`
- Writes a default `.prettierrc` if no Prettier config file exists:
  ```json
  {
    "printWidth": 150,
    "tabWidth": 2,
    "singleQuote": true,
    "bracketSameLine": true,
    "trailingComma": "es5"
  }
  ```
  When `tailwindcss` is detected, `"plugins": ["prettier-plugin-tailwindcss"]` is added.
- Writes `.lintstagedrc.json` targeting `*.{js,jsx,ts,tsx}` with both `prettier --check` and `eslint --max-warnings=0` (in check mode — no auto-fixing)
- The existing `harness:lint` pre-commit block already runs lint-staged via the detected package manager, which triggers both tools on staged files

### Mixed (Go + JS/TS) repos

All of the above, plus:

- Checks for `goimports` in PATH; installs via `go install golang.org/x/tools/cmd/goimports@latest` if absent
- Merges a `harness:gofmt` pre-commit block that runs `gofmt -l` then `goimports -l` on staged `.go` files — fails with actionable errors if any files are not formatted

Formatting failure exits non-zero and outputs which files need formatting — the commit is blocked. Run `gofmt -w <file>` or `goimports -w <file>` to fix.

## Type-checking

Setup installs type-checking tools and default configs if absent, then merges type-check hooks into `.husky/pre-commit`.

### JS / TS repos

- Installs `typescript` as a dev dependency (if not already present)
- Writes a default `tsconfig.json` if none exists anywhere in the project (excludes `node_modules`):
  - Detects source directory (`src/`, `web/`, `app/`; defaults to `src`)
  - Includes `"types": ["vite/client"]` only when `vite` is detected in `package.json`
  - Sets `"noEmit": true`, `"strict": true`, and the full recommended strictness flags
- Merges a `harness:tsc` pre-commit block that runs `tsc --noEmit` against the **full project** on every commit (not staged-only — tsc requires whole-project context)
- Monorepo support: if a root `tsconfig.json` with `"references"` exists, runs a single `tsc --noEmit`; otherwise iterates all `tsconfig.json` files found in the project

### Mixed (Go + JS/TS) repos

All of the above, plus:

- Confirms `go` is available in PATH (required for `go vet`, which ships with the Go toolchain); fails with an actionable error if Go is not installed
- Merges a `harness:govet` pre-commit block that runs `go vet` on packages containing staged `.go` files only

Type-check failure exits non-zero, blocks the commit, and outputs which check failed. No auto-fix — hooks run in check mode only.

## Secrets scanning

Setup installs [gitleaks](https://github.com/gitleaks/gitleaks) if not already present and merges a secrets-scan pre-commit hook. This is the only harness check that runs on **all repo types**, including pure Go repos.

### All repo types

- Installs `gitleaks` if absent: tries `brew install gitleaks` (macOS), then `go install github.com/zricethezav/gitleaks/v8@latest`; fails with an actionable error message if neither installer is available
- Writes a default `.gitleaks.toml` if none exists — commit this file to give the team visibility and a place to add allowlist entries for known false positives
- Merges a `harness:gitleaks` pre-commit block that runs `gitleaks protect --staged` on every commit

### JS / TS and mixed repos

The gitleaks block is appended to `.husky/pre-commit` (same as other harness checks).

### Pure Go repos

The gitleaks block is written directly to `.git/hooks/pre-commit` (Husky is not available without `package.json`). Each developer must run `gh ai-first-taskforce setup` after cloning to install the hook locally.

### On detection

When gitleaks finds a secret, the commit is blocked and the hook prints:

```
Secret detected. Next steps:
  - False positive? Add an [[allowlist]] entry to .gitleaks.toml
  - Real credential? Rotate it immediately — do not push
```

If gitleaks is missing at hook runtime, the hook fails with an actionable error including the install command.

## Directory structure

```
harness/
  setup.sh          # Orchestrator — called by gh-ai-first-taskforce
  lib/
    detect-language.sh          # detect_language <dir>
    detect-package-manager.sh   # detect_package_manager <dir>
    merge-hook.sh               # merge_block, ensure_hook_exists
    husky.sh                    # ensure_husky_installed, ensure_husky_init
    ci-workflows.sh             # generate_workflow_yaml, install_workflow_file, detect_overlapping_workflows
    lint.sh                     # ensure_eslint_installed, ensure_golangci_lint_available, install_lint_staged_hook, install_golangci_hook
    format.sh                   # ensure_prettier_installed, ensure_prettier_config, install_prettier_staged, ensure_goimports_available, install_gofmt_hook
    typecheck.sh                # ensure_typescript_installed, ensure_tsconfig, ensure_go_vet_available, install_tsc_hook, install_go_vet_hook
```

## Running tests

Requires [bats-core](https://github.com/bats-core/bats-core):

```sh
brew install bats-core
bats tests/harness/
```
