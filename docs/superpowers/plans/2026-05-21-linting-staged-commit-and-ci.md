# Linting — Staged-file Lint on Commit and in CI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend the harness to install ESLint + lint-staged for JS/TS repos (and golangci-lint for mixed repos), merge lint hooks into Husky pre-commit, and ship pre-tailored CI workflow templates — one per repo type — with no language detection logic in CI.

**Architecture:** A new `harness/lib/lint.sh` library installs linting tools, writes default configs, and merges idempotent pre-commit hook blocks via `merge_block`. `setup.sh` sources it and calls the new functions after Husky setup. Rather than one workflow template with runtime language if-else, `install_workflow_file` is extended to accept a template filename so `setup.sh` can select `harness-checks-js.yml` or `harness-checks-mixed.yml` at install time — each is a clean, purpose-built workflow. The only remaining runtime detection in CI is pnpm vs bun, which cannot be eliminated without four templates.

**Tech Stack:** POSIX sh, bats-core (tests), lint-staged (npm), ESLint (npm), golangci-lint (Go binary), golangci/golangci-lint-action@v6 (GitHub Actions)

---

## File Map

| Action | Path | Responsibility |
|--------|------|----------------|
| Create | `harness/lib/lint.sh` | `_is_npm_dep_present`, `ensure_eslint_installed`, `ensure_lint_staged_installed`, `ensure_eslint_config`, `ensure_lint_staged_config`, `ensure_golangci_lint_available`, `ensure_golangci_config`, `install_lint_staged_hook`, `install_golangci_hook` |
| Create | `tests/harness/lint.bats` | Unit tests for all lint.sh functions |
| Create | `tests/mocks/go` | Mock go binary — logs invocations to $MOCK_LOG, returns 0 |
| Create | `harness/workflows/harness-checks-js.yml` | CI template for JS/TS repos: node setup + pnpm/bun dep install + ESLint |
| Create | `harness/workflows/harness-checks-mixed.yml` | CI template for mixed repos: same as js plus setup-go + golangci-lint |
| Modify | `harness/lib/ci-workflows.sh` | Add optional `template_name` arg to `install_workflow_file` |
| Modify | `tests/harness/ci-workflows.bats` | Add test for template selection; update call sites to pass template name explicitly |
| Modify | `harness/setup.sh` | Source lint.sh; call lint functions; pass `"harness-checks-${REPO_LANG}.yml"` to `install_workflow_file` |
| Modify | `tests/harness/setup.bats` | Add integration assertions for lint hook and config files |
| Modify | `harness/README.md` | Document linting section and two workflow templates |

---

### Task 1: Create `tests/mocks/go`

**Files:**
- Create: `tests/mocks/go`

The `go` mock prevents real `go install` from running during tests. Without it, `ensure_golangci_lint_available` would call the real `go install` in mixed-repo setup tests.

- [ ] **Step 1: Create `tests/mocks/go`**

```sh
#!/bin/sh
echo "mock-go $*" >> "${MOCK_LOG:-/tmp/mock-calls.log}"
exit 0
```

- [ ] **Step 2: Make it executable**

```bash
chmod +x tests/mocks/go
```

- [ ] **Step 3: Verify it logs correctly**

```bash
MOCK_LOG=$(mktemp)
export MOCK_LOG
tests/mocks/go install some/pkg@latest
grep -q "mock-go install some/pkg@latest" "$MOCK_LOG" && echo "PASS" || echo "FAIL"
rm "$MOCK_LOG"
```

Expected: `PASS`

- [ ] **Step 4: Commit**

```bash
git add tests/mocks/go
git commit -m "test: add mock go binary for lint tests"
```

---

### Task 2: Write failing tests for `lint.sh` (TDD red)

**Files:**
- Create: `tests/harness/lint.bats`

- [ ] **Step 1: Create `tests/harness/lint.bats`**

```bash
#!/usr/bin/env bats

setup() {
  source "$BATS_TEST_DIRNAME/../../harness/lib/detect-package-manager.sh"
  source "$BATS_TEST_DIRNAME/../../harness/lib/merge-hook.sh"
  source "$BATS_TEST_DIRNAME/../../harness/lib/lint.sh"
  REPO_DIR=$(mktemp -d)
  MOCK_LOG=$(mktemp)
  export MOCK_LOG
  MOCKS_DIR="$BATS_TEST_DIRNAME/../mocks"
}

teardown() {
  rm -rf "$REPO_DIR" "$MOCK_LOG"
}

# ── _is_npm_dep_present ────────────────────────────────────────────────────

@test "_is_npm_dep_present: returns 1 when dep absent from package.json" {
  printf '{"devDependencies":{}}\n' > "$REPO_DIR/package.json"
  run _is_npm_dep_present "$REPO_DIR" "eslint"
  [ "$status" -eq 1 ]
}

@test "_is_npm_dep_present: returns 0 when dep present in devDependencies" {
  printf '{"devDependencies":{"eslint":"^8.0.0"}}\n' > "$REPO_DIR/package.json"
  run _is_npm_dep_present "$REPO_DIR" "eslint"
  [ "$status" -eq 0 ]
}

# ── ensure_eslint_installed ────────────────────────────────────────────────

@test "ensure_eslint_installed: runs pnpm add when eslint absent (pnpm repo)" {
  export PATH="$MOCKS_DIR:$PATH"
  printf '{"devDependencies":{}}\n' > "$REPO_DIR/package.json"
  touch "$REPO_DIR/pnpm-lock.yaml"
  ensure_eslint_installed "$REPO_DIR"
  grep -q "mock-pnpm add -D eslint" "$MOCK_LOG"
}

@test "ensure_eslint_installed: runs bun add when eslint absent (bun repo)" {
  export PATH="$MOCKS_DIR:$PATH"
  printf '{"devDependencies":{}}\n' > "$REPO_DIR/package.json"
  touch "$REPO_DIR/bun.lockb"
  ensure_eslint_installed "$REPO_DIR"
  grep -q "mock-bun add -D eslint" "$MOCK_LOG"
}

@test "ensure_eslint_installed: skips install when eslint already present" {
  export PATH="$MOCKS_DIR:$PATH"
  printf '{"devDependencies":{"eslint":"^8.0.0"}}\n' > "$REPO_DIR/package.json"
  touch "$REPO_DIR/pnpm-lock.yaml"
  ensure_eslint_installed "$REPO_DIR"
  run grep "mock-pnpm add -D eslint" "$MOCK_LOG"
  [ "$status" -ne 0 ]
}

@test "ensure_eslint_installed: exits 1 for unsupported package manager" {
  printf '{"devDependencies":{}}\n' > "$REPO_DIR/package.json"
  run ensure_eslint_installed "$REPO_DIR"
  [ "$status" -eq 1 ]
}

# ── ensure_lint_staged_installed ──────────────────────────────────────────

@test "ensure_lint_staged_installed: runs pnpm add when lint-staged absent (pnpm repo)" {
  export PATH="$MOCKS_DIR:$PATH"
  printf '{"devDependencies":{}}\n' > "$REPO_DIR/package.json"
  touch "$REPO_DIR/pnpm-lock.yaml"
  ensure_lint_staged_installed "$REPO_DIR"
  grep -q "mock-pnpm add -D lint-staged" "$MOCK_LOG"
}

@test "ensure_lint_staged_installed: runs bun add when lint-staged absent (bun repo)" {
  export PATH="$MOCKS_DIR:$PATH"
  printf '{"devDependencies":{}}\n' > "$REPO_DIR/package.json"
  touch "$REPO_DIR/bun.lockb"
  ensure_lint_staged_installed "$REPO_DIR"
  grep -q "mock-bun add -D lint-staged" "$MOCK_LOG"
}

@test "ensure_lint_staged_installed: skips install when lint-staged already present" {
  export PATH="$MOCKS_DIR:$PATH"
  printf '{"devDependencies":{"lint-staged":"^15.0.0"}}\n' > "$REPO_DIR/package.json"
  touch "$REPO_DIR/pnpm-lock.yaml"
  ensure_lint_staged_installed "$REPO_DIR"
  run grep "mock-pnpm add -D lint-staged" "$MOCK_LOG"
  [ "$status" -ne 0 ]
}

# ── ensure_eslint_config ──────────────────────────────────────────────────

@test "ensure_eslint_config: creates .eslintrc.json when no config exists" {
  ensure_eslint_config "$REPO_DIR"
  [ -f "$REPO_DIR/.eslintrc.json" ]
}

@test "ensure_eslint_config: .eslintrc.json contains eslint:recommended" {
  ensure_eslint_config "$REPO_DIR"
  grep -q '"eslint:recommended"' "$REPO_DIR/.eslintrc.json"
}

@test "ensure_eslint_config: skips when .eslintrc.json already exists" {
  printf '{"extends":["custom"]}\n' > "$REPO_DIR/.eslintrc.json"
  ensure_eslint_config "$REPO_DIR"
  run grep '"eslint:recommended"' "$REPO_DIR/.eslintrc.json"
  [ "$status" -ne 0 ]
}

@test "ensure_eslint_config: skips when eslint.config.js exists" {
  printf '// custom config\n' > "$REPO_DIR/eslint.config.js"
  ensure_eslint_config "$REPO_DIR"
  [ ! -f "$REPO_DIR/.eslintrc.json" ]
}

@test "ensure_eslint_config: skips when .eslintrc.yml exists" {
  printf 'extends: recommended\n' > "$REPO_DIR/.eslintrc.yml"
  ensure_eslint_config "$REPO_DIR"
  [ ! -f "$REPO_DIR/.eslintrc.json" ]
}

# ── ensure_lint_staged_config ─────────────────────────────────────────────

@test "ensure_lint_staged_config: creates .lintstagedrc.json when no config exists" {
  printf '{"devDependencies":{}}\n' > "$REPO_DIR/package.json"
  ensure_lint_staged_config "$REPO_DIR"
  [ -f "$REPO_DIR/.lintstagedrc.json" ]
}

@test "ensure_lint_staged_config: .lintstagedrc.json targets JS and TS files" {
  printf '{"devDependencies":{}}\n' > "$REPO_DIR/package.json"
  ensure_lint_staged_config "$REPO_DIR"
  grep -q 'tsx' "$REPO_DIR/.lintstagedrc.json"
}

@test "ensure_lint_staged_config: skips when .lintstagedrc.json already exists" {
  printf '{"*.ts":["tsc"]}\n' > "$REPO_DIR/.lintstagedrc.json"
  printf '{"devDependencies":{}}\n' > "$REPO_DIR/package.json"
  ensure_lint_staged_config "$REPO_DIR"
  grep -q '"tsc"' "$REPO_DIR/.lintstagedrc.json"
}

@test "ensure_lint_staged_config: skips when lint-staged key in package.json" {
  printf '{"devDependencies":{},"lint-staged":{"*.ts":["tsc"]}}\n' > "$REPO_DIR/package.json"
  ensure_lint_staged_config "$REPO_DIR"
  [ ! -f "$REPO_DIR/.lintstagedrc.json" ]
}

# ── ensure_golangci_lint_available ────────────────────────────────────────

@test "ensure_golangci_lint_available: returns 0 when golangci-lint in PATH" {
  local bin_dir="$REPO_DIR/bin"
  mkdir -p "$bin_dir"
  printf '#!/bin/sh\nexit 0\n' > "$bin_dir/golangci-lint"
  chmod +x "$bin_dir/golangci-lint"
  export PATH="$bin_dir:/usr/bin:/bin"
  run ensure_golangci_lint_available
  [ "$status" -eq 0 ]
}

@test "ensure_golangci_lint_available: runs go install when go available and golangci-lint absent" {
  local go_bin="$REPO_DIR/go-bin"
  mkdir -p "$go_bin"
  printf '#!/bin/sh\necho "mock-go $*" >> "%s"\n' "$MOCK_LOG" > "$go_bin/go"
  chmod +x "$go_bin/go"
  export PATH="$go_bin:/usr/bin:/bin"
  run ensure_golangci_lint_available
  [ "$status" -eq 0 ]
  grep -q "mock-go install" "$MOCK_LOG"
}

@test "ensure_golangci_lint_available: fails with actionable error when neither found" {
  local empty_dir="$REPO_DIR/empty"
  mkdir -p "$empty_dir"
  export PATH="$empty_dir"
  run ensure_golangci_lint_available
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR"* ]]
  [[ "$output" == *"golangci-lint"* ]]
}

# ── ensure_golangci_config ────────────────────────────────────────────────

@test "ensure_golangci_config: creates .golangci.yml when no config exists" {
  ensure_golangci_config "$REPO_DIR"
  [ -f "$REPO_DIR/.golangci.yml" ]
}

@test "ensure_golangci_config: .golangci.yml enables errcheck and govet" {
  ensure_golangci_config "$REPO_DIR"
  grep -q "errcheck" "$REPO_DIR/.golangci.yml"
  grep -q "govet" "$REPO_DIR/.golangci.yml"
}

@test "ensure_golangci_config: skips when .golangci.yml already exists" {
  printf 'linters:\n  enable:\n    - custom\n' > "$REPO_DIR/.golangci.yml"
  ensure_golangci_config "$REPO_DIR"
  run grep "errcheck" "$REPO_DIR/.golangci.yml"
  [ "$status" -ne 0 ]
}

@test "ensure_golangci_config: skips when .golangci.yaml exists" {
  printf 'linters:\n  enable:\n    - custom\n' > "$REPO_DIR/.golangci.yaml"
  ensure_golangci_config "$REPO_DIR"
  [ ! -f "$REPO_DIR/.golangci.yml" ]
}

# ── install_lint_staged_hook ──────────────────────────────────────────────

@test "install_lint_staged_hook: merges lint block into pre-commit" {
  mkdir -p "$REPO_DIR/.husky"
  printf '#!/bin/sh\n' > "$REPO_DIR/.husky/pre-commit"
  chmod +x "$REPO_DIR/.husky/pre-commit"
  install_lint_staged_hook "$REPO_DIR"
  grep -q "# harness:lint:begin" "$REPO_DIR/.husky/pre-commit"
}

@test "install_lint_staged_hook: pre-commit contains npx lint-staged" {
  mkdir -p "$REPO_DIR/.husky"
  printf '#!/bin/sh\n' > "$REPO_DIR/.husky/pre-commit"
  chmod +x "$REPO_DIR/.husky/pre-commit"
  install_lint_staged_hook "$REPO_DIR"
  grep -q "npx lint-staged" "$REPO_DIR/.husky/pre-commit"
}

@test "install_lint_staged_hook: pre-commit checks for node at runtime" {
  mkdir -p "$REPO_DIR/.husky"
  printf '#!/bin/sh\n' > "$REPO_DIR/.husky/pre-commit"
  chmod +x "$REPO_DIR/.husky/pre-commit"
  install_lint_staged_hook "$REPO_DIR"
  grep -q "command -v node" "$REPO_DIR/.husky/pre-commit"
}

@test "install_lint_staged_hook: is idempotent on re-run" {
  mkdir -p "$REPO_DIR/.husky"
  printf '#!/bin/sh\n' > "$REPO_DIR/.husky/pre-commit"
  chmod +x "$REPO_DIR/.husky/pre-commit"
  install_lint_staged_hook "$REPO_DIR"
  install_lint_staged_hook "$REPO_DIR"
  [ "$(grep -c "harness:lint:begin" "$REPO_DIR/.husky/pre-commit")" = "1" ]
}

# ── install_golangci_hook ─────────────────────────────────────────────────

@test "install_golangci_hook: merges golangci block into pre-commit" {
  mkdir -p "$REPO_DIR/.husky"
  printf '#!/bin/sh\n' > "$REPO_DIR/.husky/pre-commit"
  chmod +x "$REPO_DIR/.husky/pre-commit"
  install_golangci_hook "$REPO_DIR"
  grep -q "# harness:golangci:begin" "$REPO_DIR/.husky/pre-commit"
}

@test "install_golangci_hook: pre-commit contains golangci-lint run" {
  mkdir -p "$REPO_DIR/.husky"
  printf '#!/bin/sh\n' > "$REPO_DIR/.husky/pre-commit"
  chmod +x "$REPO_DIR/.husky/pre-commit"
  install_golangci_hook "$REPO_DIR"
  grep -q "golangci-lint run" "$REPO_DIR/.husky/pre-commit"
}

@test "install_golangci_hook: only runs when staged .go files present" {
  mkdir -p "$REPO_DIR/.husky"
  printf '#!/bin/sh\n' > "$REPO_DIR/.husky/pre-commit"
  chmod +x "$REPO_DIR/.husky/pre-commit"
  install_golangci_hook "$REPO_DIR"
  grep -q '\.go' "$REPO_DIR/.husky/pre-commit"
}

@test "install_golangci_hook: block checks for golangci-lint at runtime" {
  mkdir -p "$REPO_DIR/.husky"
  printf '#!/bin/sh\n' > "$REPO_DIR/.husky/pre-commit"
  chmod +x "$REPO_DIR/.husky/pre-commit"
  install_golangci_hook "$REPO_DIR"
  grep -q "command -v golangci-lint" "$REPO_DIR/.husky/pre-commit"
}

@test "install_golangci_hook: is idempotent on re-run" {
  mkdir -p "$REPO_DIR/.husky"
  printf '#!/bin/sh\n' > "$REPO_DIR/.husky/pre-commit"
  chmod +x "$REPO_DIR/.husky/pre-commit"
  install_golangci_hook "$REPO_DIR"
  install_golangci_hook "$REPO_DIR"
  [ "$(grep -c "harness:golangci:begin" "$REPO_DIR/.husky/pre-commit")" = "1" ]
}
```

- [ ] **Step 2: Run the tests to confirm they all fail**

```bash
bats tests/harness/lint.bats
```

Expected: all tests FAIL with `source: .../lint.sh: No such file or directory` or similar.

- [ ] **Step 3: Commit the failing tests**

```bash
git add tests/harness/lint.bats
git commit -m "test: add failing bats tests for lint.sh (TDD red phase)"
```

---

### Task 3: Implement `harness/lib/lint.sh` (TDD green)

**Files:**
- Create: `harness/lib/lint.sh`

- [ ] **Step 1: Create `harness/lib/lint.sh`**

```sh
# Requires detect_package_manager() and merge_block() to be sourced before this file.

# _is_npm_dep_present <repo_root> <dep>
# Returns 0 if <dep> appears as a key in package.json, 1 otherwise.
_is_npm_dep_present() {
  local repo_root="$1" dep="$2"
  grep -qE "\"$dep\"\s*:" "$repo_root/package.json" 2>/dev/null
}

# ensure_eslint_installed <repo_root>
ensure_eslint_installed() {
  local repo_root="$1"
  if ! _is_npm_dep_present "$repo_root" "eslint"; then
    local pm
    pm=$(detect_package_manager "$repo_root")
    case "$pm" in
      pnpm) (cd "$repo_root" && pnpm add -D eslint) ;;
      bun)  (cd "$repo_root" && bun add -D eslint) ;;
      *)
        echo "ERROR: Unsupported package manager. Expected pnpm-lock.yaml or bun.lock/bun.lockb." >&2
        return 1
        ;;
    esac
  fi
}

# ensure_lint_staged_installed <repo_root>
ensure_lint_staged_installed() {
  local repo_root="$1"
  if ! _is_npm_dep_present "$repo_root" "lint-staged"; then
    local pm
    pm=$(detect_package_manager "$repo_root")
    case "$pm" in
      pnpm) (cd "$repo_root" && pnpm add -D lint-staged) ;;
      bun)  (cd "$repo_root" && bun add -D lint-staged) ;;
      *)
        echo "ERROR: Unsupported package manager. Expected pnpm-lock.yaml or bun.lock/bun.lockb." >&2
        return 1
        ;;
    esac
  fi
}

# ensure_eslint_config <repo_root>
# Writes a default .eslintrc.json if no ESLint config of any kind exists.
ensure_eslint_config() {
  local repo_root="$1"
  for f in .eslintrc .eslintrc.json .eslintrc.js .eslintrc.cjs .eslintrc.yml .eslintrc.yaml \
            eslint.config.js eslint.config.mjs eslint.config.cjs; do
    [ -f "$repo_root/$f" ] && return 0
  done
  printf '{\n  "extends": ["eslint:recommended"],\n  "env": { "node": true, "es2022": true },\n  "parserOptions": { "ecmaVersion": 2022 }\n}\n' \
    > "$repo_root/.eslintrc.json"
  echo "Created default .eslintrc.json"
}

# ensure_lint_staged_config <repo_root>
# Writes a default .lintstagedrc.json if no lint-staged config of any kind exists.
ensure_lint_staged_config() {
  local repo_root="$1"
  for f in .lintstagedrc .lintstagedrc.json .lintstagedrc.js .lintstagedrc.cjs \
            .lintstagedrc.mjs .lintstagedrc.yml .lintstagedrc.yaml; do
    [ -f "$repo_root/$f" ] && return 0
  done
  grep -q '"lint-staged"' "$repo_root/package.json" 2>/dev/null && return 0
  printf '{\n  "*.{js,jsx,ts,tsx}": ["eslint --max-warnings=0"]\n}\n' \
    > "$repo_root/.lintstagedrc.json"
  echo "Created default .lintstagedrc.json"
}

# ensure_golangci_lint_available
# Returns 0 if golangci-lint is in PATH. If not, attempts go install. Fails with
# an actionable error if neither golangci-lint nor go is available.
ensure_golangci_lint_available() {
  if command -v golangci-lint >/dev/null 2>&1; then
    return 0
  fi
  if command -v go >/dev/null 2>&1; then
    go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
    echo "Installed golangci-lint via go install. Ensure your GOPATH/bin is in PATH."
  else
    echo "ERROR: golangci-lint not found. Install: https://golangci-lint.run/usage/install/" >&2
    return 1
  fi
}

# ensure_golangci_config <repo_root>
# Writes a default .golangci.yml if no golangci-lint config of any kind exists.
ensure_golangci_config() {
  local repo_root="$1"
  for f in .golangci.yml .golangci.yaml .golangci.toml .golangci.json; do
    [ -f "$repo_root/$f" ] && return 0
  done
  printf 'linters:\n  enable:\n    - errcheck\n    - gosimple\n    - govet\n    - ineffassign\n    - staticcheck\n    - unused\n' \
    > "$repo_root/.golangci.yml"
  echo "Created default .golangci.yml"
}

# install_lint_staged_hook <repo_root>
# Merges the lint-staged pre-commit block. Checks for node at hook runtime.
install_lint_staged_hook() {
  local repo_root="$1"
  local block='# harness:lint:begin
if ! command -v node >/dev/null 2>&1; then
  echo "ERROR: node not found. Ensure nvm is configured and re-run: gh ai-first-taskforce setup" >&2
  exit 1
fi
npx lint-staged
# harness:lint:end'
  merge_block "$repo_root/.husky/pre-commit" "lint" "$block"
}

# install_golangci_hook <repo_root>
# Merges the golangci-lint pre-commit block (mixed repos only).
# Only lints when staged .go files are present.
install_golangci_hook() {
  local repo_root="$1"
  local block
  block='# harness:golangci:begin
_STAGED_GO=$(git diff --cached --name-only --diff-filter=ACM | grep '"'"'\.go$'"'"' || true)
if [ -n "$_STAGED_GO" ]; then
  if ! command -v golangci-lint >/dev/null 2>&1; then
    echo "ERROR: golangci-lint not found. Run: gh ai-first-taskforce setup" >&2
    exit 1
  fi
  golangci-lint run ./...
fi
unset _STAGED_GO
# harness:golangci:end'
  merge_block "$repo_root/.husky/pre-commit" "golangci" "$block"
}
```

- [ ] **Step 2: Run the tests to verify they all pass**

```bash
bats tests/harness/lint.bats
```

Expected: all tests PASS.

- [ ] **Step 3: Run the full suite to confirm no regressions**

```bash
bats tests/harness/
```

Expected: all tests PASS.

- [ ] **Step 4: Commit**

```bash
git add harness/lib/lint.sh
git commit -m "feat: add lint.sh with ESLint, lint-staged, and golangci-lint setup functions"
```

---

### Task 4: Extend `install_workflow_file` and create per-type workflow templates (TDD)

**Files:**
- Modify: `harness/lib/ci-workflows.sh`
- Modify: `tests/harness/ci-workflows.bats`
- Create: `harness/workflows/harness-checks-js.yml`
- Create: `harness/workflows/harness-checks-mixed.yml`

`install_workflow_file` currently hardcodes `harness-checks.yml` as the source template. This task adds an optional third argument `template_name` so `setup.sh` can select a pre-tailored template at install time. The destination in target repos stays `.github/workflows/harness-checks.yml` regardless of which source template was used.

- [ ] **Step 1: Add a failing test to `tests/harness/ci-workflows.bats`**

Append this test at the end of the existing `# ── install_workflow_file ──` section:

```bash
@test "install_workflow_file: installs the specified template when template_name given" {
  local tmp_harness="$REPO_DIR/tmp-harness"
  mkdir -p "$tmp_harness/workflows"
  printf 'name: Custom Checks\n' > "$tmp_harness/workflows/custom-checks.yml"
  install_workflow_file "$REPO_DIR" "$tmp_harness" "custom-checks.yml"
  grep -q "name: Custom Checks" "$REPO_DIR/.github/workflows/harness-checks.yml"
}
```

- [ ] **Step 2: Run ci-workflows.bats to confirm the new test fails**

```bash
bats tests/harness/ci-workflows.bats
```

Expected: the new test FAILS — `install_workflow_file` ignores the 3rd arg and uses `harness-checks.yml` as source, which doesn't exist in `$tmp_harness/workflows/`. All other tests still PASS.

- [ ] **Step 3: Update `install_workflow_file` in `harness/lib/ci-workflows.sh`**

Replace only the function signature and template path line. The rest of the function body is unchanged. Change from:

```sh
install_workflow_file() {
  local repo_root="$1" harness_dir="$2"
  local template="$harness_dir/workflows/harness-checks.yml"
```

To:

```sh
install_workflow_file() {
  local repo_root="$1" harness_dir="$2" template_name="${3:-harness-checks.yml}"
  local template="$harness_dir/workflows/$template_name"
```

- [ ] **Step 4: Run ci-workflows.bats to verify all tests pass**

```bash
bats tests/harness/ci-workflows.bats
```

Expected: all tests PASS including the new one. Existing tests continue to pass because they call `install_workflow_file` with two args, which defaults to `harness-checks.yml`.

- [ ] **Step 5: Update existing `install_workflow_file` call sites in `tests/harness/ci-workflows.bats` to pass the template name explicitly**

Find every call of the form `install_workflow_file "$REPO_DIR" "$harness_dir"` and add `"harness-checks.yml"` as a third argument. There are six such calls:

```bash
# Before (6 occurrences):
install_workflow_file "$REPO_DIR" "$harness_dir"

# After (6 occurrences):
install_workflow_file "$REPO_DIR" "$harness_dir" "harness-checks.yml"
```

- [ ] **Step 6: Run ci-workflows.bats again to confirm no regressions**

```bash
bats tests/harness/ci-workflows.bats
```

Expected: all tests PASS.

- [ ] **Step 7: Create `harness/workflows/harness-checks-js.yml`**

```yaml
name: Harness Checks

on:
  push:
  pull_request:

jobs:
  harness:
    name: harness / checks
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Detect package manager
        id: pm
        run: |
          if [ -f pnpm-lock.yaml ]; then
            echo "pm=pnpm" >> "$GITHUB_OUTPUT"
          elif [ -f bun.lock ] || [ -f bun.lockb ]; then
            echo "pm=bun" >> "$GITHUB_OUTPUT"
          fi

      - uses: actions/setup-node@v4
        with:
          node-version: lts/*

      - uses: pnpm/action-setup@v4
        if: steps.pm.outputs.pm == 'pnpm'
        with:
          run_install: false

      - name: Install dependencies (pnpm)
        if: steps.pm.outputs.pm == 'pnpm'
        run: pnpm install --frozen-lockfile

      - name: Install dependencies (bun)
        if: steps.pm.outputs.pm == 'bun'
        run: bun install --frozen-lockfile

      - name: Lint (ESLint)
        run: npx eslint .
```

- [ ] **Step 8: Create `harness/workflows/harness-checks-mixed.yml`**

```yaml
name: Harness Checks

on:
  push:
  pull_request:

jobs:
  harness:
    name: harness / checks
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Detect package manager
        id: pm
        run: |
          if [ -f pnpm-lock.yaml ]; then
            echo "pm=pnpm" >> "$GITHUB_OUTPUT"
          elif [ -f bun.lock ] || [ -f bun.lockb ]; then
            echo "pm=bun" >> "$GITHUB_OUTPUT"
          fi

      - uses: actions/setup-node@v4
        with:
          node-version: lts/*

      - uses: pnpm/action-setup@v4
        if: steps.pm.outputs.pm == 'pnpm'
        with:
          run_install: false

      - name: Install dependencies (pnpm)
        if: steps.pm.outputs.pm == 'pnpm'
        run: pnpm install --frozen-lockfile

      - name: Install dependencies (bun)
        if: steps.pm.outputs.pm == 'bun'
        run: bun install --frozen-lockfile

      - name: Lint (ESLint)
        run: npx eslint .

      - uses: actions/setup-go@v5
        with:
          go-version-file: go.mod

      - name: Lint (golangci-lint)
        uses: golangci/golangci-lint-action@v6
        with:
          version: latest
```

- [ ] **Step 9: Run the full test suite to confirm no regressions**

```bash
bats tests/harness/
```

Expected: all tests PASS.

- [ ] **Step 10: Commit**

```bash
git add harness/lib/ci-workflows.sh tests/harness/ci-workflows.bats \
        harness/workflows/harness-checks-js.yml harness/workflows/harness-checks-mixed.yml
git commit -m "feat: add per-type CI workflow templates and extend install_workflow_file with template selection"
```

---

### Task 5: Wire `lint.sh` into `setup.sh` (TDD)

**Files:**
- Modify: `harness/setup.sh`
- Modify: `tests/harness/setup.bats`

- [ ] **Step 1: Append the new failing tests to `tests/harness/setup.bats`**

Add these tests at the end of the file:

```bash
@test "merges lint block into pre-commit for JS repo" {
  _pnpm_repo_with_hooks
  run bash "$SETUP_SCRIPT" "$REPO_DIR"
  [ "$status" -eq 0 ]
  grep -q "# harness:lint:begin" "$REPO_DIR/.husky/pre-commit"
}

@test "creates .eslintrc.json for JS repo when absent" {
  _pnpm_repo_with_hooks
  run bash "$SETUP_SCRIPT" "$REPO_DIR"
  [ "$status" -eq 0 ]
  [ -f "$REPO_DIR/.eslintrc.json" ]
}

@test "creates .lintstagedrc.json for JS repo when absent" {
  _pnpm_repo_with_hooks
  run bash "$SETUP_SCRIPT" "$REPO_DIR"
  [ "$status" -eq 0 ]
  [ -f "$REPO_DIR/.lintstagedrc.json" ]
}

@test "does not merge golangci block for JS-only repo" {
  _pnpm_repo_with_hooks
  run bash "$SETUP_SCRIPT" "$REPO_DIR"
  [ "$status" -eq 0 ]
  run grep "# harness:golangci:begin" "$REPO_DIR/.husky/pre-commit"
  [ "$status" -ne 0 ]
}

@test "merges golangci block into pre-commit for mixed repo" {
  _pnpm_repo_with_hooks
  touch "$REPO_DIR/go.mod"
  run bash "$SETUP_SCRIPT" "$REPO_DIR"
  [ "$status" -eq 0 ]
  grep -q "# harness:golangci:begin" "$REPO_DIR/.husky/pre-commit"
}

@test "creates .golangci.yml for mixed repo when absent" {
  _pnpm_repo_with_hooks
  touch "$REPO_DIR/go.mod"
  run bash "$SETUP_SCRIPT" "$REPO_DIR"
  [ "$status" -eq 0 ]
  [ -f "$REPO_DIR/.golangci.yml" ]
}

@test "installs js workflow template for JS repo" {
  _pnpm_repo_with_hooks
  run bash "$SETUP_SCRIPT" "$REPO_DIR"
  [ "$status" -eq 0 ]
  grep -q "golangci-lint-action" "$REPO_DIR/.github/workflows/harness-checks.yml" && return 1
  grep -q "npx eslint" "$REPO_DIR/.github/workflows/harness-checks.yml"
}

@test "installs mixed workflow template for mixed repo" {
  _pnpm_repo_with_hooks
  touch "$REPO_DIR/go.mod"
  run bash "$SETUP_SCRIPT" "$REPO_DIR"
  [ "$status" -eq 0 ]
  grep -q "golangci-lint-action" "$REPO_DIR/.github/workflows/harness-checks.yml"
}

@test "re-run does not duplicate lint block in pre-commit" {
  _pnpm_repo_with_hooks
  bash "$SETUP_SCRIPT" "$REPO_DIR"
  bash "$SETUP_SCRIPT" "$REPO_DIR"
  [ "$(grep -c "harness:lint:begin" "$REPO_DIR/.husky/pre-commit")" = "1" ]
}

@test "re-run does not duplicate golangci block for mixed repo" {
  _pnpm_repo_with_hooks
  touch "$REPO_DIR/go.mod"
  bash "$SETUP_SCRIPT" "$REPO_DIR"
  bash "$SETUP_SCRIPT" "$REPO_DIR"
  [ "$(grep -c "harness:golangci:begin" "$REPO_DIR/.husky/pre-commit")" = "1" ]
}
```

- [ ] **Step 2: Run setup.bats to confirm the new tests fail**

```bash
bats tests/harness/setup.bats
```

Expected: the ten new tests FAIL. All previously-passing tests still PASS.

- [ ] **Step 3: Replace `harness/setup.sh`**

```sh
#!/bin/sh
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="${1:-$(git rev-parse --show-toplevel)}"

. "$SCRIPT_DIR/lib/detect-language.sh"
. "$SCRIPT_DIR/lib/detect-package-manager.sh"
. "$SCRIPT_DIR/lib/merge-hook.sh"
. "$SCRIPT_DIR/lib/husky.sh"
. "$SCRIPT_DIR/lib/ci-workflows.sh"
. "$SCRIPT_DIR/lib/lint.sh"

NVM_BLOCK='# harness:nvm:begin
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
# harness:nvm:end'

REPO_LANG=$(detect_language "$REPO_ROOT")

case "$REPO_LANG" in
  js|mixed)
    echo "Detected $REPO_LANG repo — setting up Husky hooks..."
    ensure_husky_installed "$REPO_ROOT"
    ensure_husky_init "$REPO_ROOT"
    ensure_hook_exists "$REPO_ROOT/.husky/pre-push"
    merge_block "$REPO_ROOT/.husky/pre-commit" "nvm" "$NVM_BLOCK" "after-shebang"
    merge_block "$REPO_ROOT/.husky/pre-push" "nvm" "$NVM_BLOCK" "after-shebang"
    ensure_eslint_installed "$REPO_ROOT"
    ensure_eslint_config "$REPO_ROOT"
    ensure_lint_staged_installed "$REPO_ROOT"
    ensure_lint_staged_config "$REPO_ROOT"
    install_lint_staged_hook "$REPO_ROOT"
    if [ "$REPO_LANG" = "mixed" ]; then
      ensure_golangci_lint_available
      ensure_golangci_config "$REPO_ROOT"
      install_golangci_hook "$REPO_ROOT"
    fi
    detect_overlapping_workflows "$REPO_ROOT"
    install_workflow_file "$REPO_ROOT" "$SCRIPT_DIR" "harness-checks-${REPO_LANG}.yml"
    echo "Done. Husky hooks configured at $REPO_ROOT/.husky/"
    echo "NOTE: Add 'harness / checks' as a required status check in GitHub branch protection to enforce CI linting on PRs."
    ;;
  unsupported)
    echo "ERROR: No package.json found. Pure Go repos are not supported in v1." >&2
    exit 1
    ;;
esac
```

- [ ] **Step 4: Run the full test suite**

```bash
bats tests/harness/
```

Expected: all tests PASS including the ten new ones.

- [ ] **Step 5: Commit**

```bash
git add harness/setup.sh tests/harness/setup.bats
git commit -m "feat: wire lint setup into setup.sh and select per-type workflow template"
```

---

### Task 6: Update `harness/README.md`

**Files:**
- Modify: `harness/README.md`

- [ ] **Step 1: Add linting section to `harness/README.md`**

After the `## CI workflow scaffolding` section, insert:

```markdown
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
```

- [ ] **Step 2: Update the `## Directory structure` section**

Replace:

```
    ci-workflows.sh             # install_workflow_file, detect_overlapping_workflows
  workflows/
    harness-checks.yml          # CI workflow template — installed into target repos
```

With:

```
    ci-workflows.sh             # install_workflow_file, detect_overlapping_workflows
    lint.sh                     # ensure_eslint_installed, ensure_golangci_lint_available, install_lint_staged_hook, install_golangci_hook
  workflows/
    harness-checks.yml          # base template (test fixture)
    harness-checks-js.yml       # installed for JS/TS repos
    harness-checks-mixed.yml    # installed for Go+JS/TS repos
```

- [ ] **Step 3: Run all tests to confirm nothing broke**

```bash
bats tests/harness/
```

Expected: all tests PASS.

- [ ] **Step 4: Commit**

```bash
git add harness/README.md
git commit -m "docs: document linting setup, per-type workflow templates, and required status check"
```

---

## Self-Review

### Spec coverage

| AC | Task |
|----|------|
| Harness setup installs ESLint and default `.eslintrc` if absent | Task 3 (`ensure_eslint_installed`, `ensure_eslint_config`) + Task 5 (setup.sh) |
| For mixed repos: installs golangci-lint and default `.golangci.yml` if absent | Task 3 (`ensure_golangci_lint_available`, `ensure_golangci_config`) + Task 5 (setup.sh `if mixed`) |
| Husky pre-commit runs ESLint via lint-staged on staged JS/TS files only | Task 3 (`install_lint_staged_hook` + `.lintstagedrc.json` targeting `*.{js,jsx,ts,tsx}`) |
| For mixed repos: pre-commit also runs golangci-lint on staged Go files only | Task 3 (`install_golangci_hook` — block guards with `_STAGED_GO` check) |
| Lint failure exits non-zero and outputs which files failed | Inherent to lint-staged and golangci-lint; hook exits non-zero on tool failure |
| CI workflow runs ESLint (and golangci-lint for mixed) on every PR | Task 4 (`harness-checks-js.yml` and `harness-checks-mixed.yml`); setup selects the right one |
| CI lint check configured as required status check | Task 6 (README documents `gh api` command and GitHub Settings path; not automated — requires admin access) |
| If lint tools missing at hook runtime, hook fails with actionable error | Task 3: lint block checks `command -v node`; golangci block checks `command -v golangci-lint` |

### Placeholder scan

No TBD or TODO entries. All steps include exact code.

### Type consistency

- `install_workflow_file` new signature: `<repo_root> <harness_dir> [template_name]` — existing 2-arg callers in ci-workflows.bats default to `harness-checks.yml`; setup.sh uses explicit 3rd arg
- `merge_block` called with 4 args in setup.sh and 3 args in lint.sh — both match `merge_block <file> <id> <content> [position]`
- `ensure_golangci_lint_available` takes no `repo_root` arg (PATH check only) — consistent across lint.sh and setup.sh
- Hook block IDs `lint` and `golangci` — no conflicts with existing `nvm` block ID
- Template names `harness-checks-js.yml` / `harness-checks-mixed.yml` match `"harness-checks-${REPO_LANG}.yml"` for `REPO_LANG` values `js` and `mixed`
