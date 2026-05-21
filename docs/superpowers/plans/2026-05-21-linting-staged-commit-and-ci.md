# Linting — Staged-file Lint on Commit and in CI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend the harness to install ESLint + lint-staged for JS/TS repos (and golangci-lint for mixed repos), merge lint hooks into Husky pre-commit, and generate and install a CI workflow YAML on the fly for the detected repo type and package manager — with no runtime detection in CI.

**Architecture:** A new `harness/lib/lint.sh` library installs linting tools, writes default configs, and merges idempotent pre-commit hook blocks via `merge_block`. `setup.sh` sources it and calls the new functions after Husky setup. A new `generate_workflow_yaml <lang> <pm>` function in `ci-workflows.sh` emits the full workflow YAML using heredocs and case/if branches, baking in the detected PM. `install_workflow_file` accepts `<repo_root> <lang> <pm>`, checksums the generated content, and writes it only when it has changed. No runtime PM or language detection occurs in the installed workflow — `setup.sh` detects both at install time and passes them to the generator.

**Tech Stack:** POSIX sh, bats-core (tests), lint-staged (npm), ESLint (npm), golangci-lint (Go binary), golangci/golangci-lint-action@v6 (GitHub Actions)

---

## File Map

| Action | Path | Responsibility |
|--------|------|----------------|
| Create | `harness/lib/lint.sh` | `_is_npm_dep_present`, `ensure_eslint_installed`, `ensure_lint_staged_installed`, `ensure_eslint_config`, `ensure_lint_staged_config`, `ensure_golangci_lint_available`, `ensure_golangci_config`, `install_lint_staged_hook`, `install_golangci_hook` |
| Create | `tests/harness/lint.bats` | Unit tests for all lint.sh functions |
| Create | `tests/mocks/go` | Mock go binary — logs invocations to $MOCK_LOG, returns 0 |
| Modify | `harness/lib/ci-workflows.sh` | Add `generate_workflow_yaml <lang> <pm>`; redesign `install_workflow_file <repo_root> <lang> <pm>` |
| Modify | `tests/harness/ci-workflows.bats` | Add 4 `generate_workflow_yaml` tests; replace `install_workflow_file` tests with new-signature versions |
| Modify | `harness/setup.sh` | Source lint.sh; call lint functions; detect PM; pass `"$REPO_LANG" "$REPO_PM"` to `install_workflow_file` |
| Modify | `tests/harness/setup.bats` | Add integration assertions for lint hook and config files |
| Modify | `harness/README.md` | Document linting section; update CI workflow prose and directory structure |

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

### Task 4: Implement `generate_workflow_yaml` and redesign `install_workflow_file` (TDD)

**Files:**
- Modify: `tests/harness/ci-workflows.bats`
- Modify: `harness/lib/ci-workflows.sh`

Replace the static-template approach with a `generate_workflow_yaml <lang> <pm>` function that emits the full workflow YAML using heredocs. `install_workflow_file` is redesigned to accept `<repo_root> <lang> <pm>`, call the generator, checksum the output, and write it only when content has changed. The destination in target repos stays `.github/workflows/harness-checks.yml`.

- [ ] **Step 1: Replace the `install_workflow_file` test block in `tests/harness/ci-workflows.bats` (TDD red)**

Find the existing `# ── install_workflow_file ──` section (after the `_write_manifest_entry` tests) and the `# ── detect_overlapping_workflows ──` section. Replace everything between them (the install_workflow_file tests) with:

```bash
# ── generate_workflow_yaml ───────────────────────────────────────────────

@test "generate_workflow_yaml js pnpm: contains pnpm install, not bun or go steps" {
  run generate_workflow_yaml "js" "pnpm"
  [ "$status" -eq 0 ]
  [[ "$output" == *"pnpm install --frozen-lockfile"* ]]
  [[ "$output" != *"bun install"* ]]
  [[ "$output" != *"golangci-lint-action"* ]]
}

@test "generate_workflow_yaml js bun: contains bun install, not pnpm or go steps" {
  run generate_workflow_yaml "js" "bun"
  [ "$status" -eq 0 ]
  [[ "$output" == *"bun install --frozen-lockfile"* ]]
  [[ "$output" != *"pnpm install"* ]]
  [[ "$output" != *"golangci-lint-action"* ]]
}

@test "generate_workflow_yaml mixed pnpm: contains pnpm install and golangci steps" {
  run generate_workflow_yaml "mixed" "pnpm"
  [ "$status" -eq 0 ]
  [[ "$output" == *"pnpm install --frozen-lockfile"* ]]
  [[ "$output" == *"golangci-lint-action@v6"* ]]
}

@test "generate_workflow_yaml mixed bun: contains bun install and golangci steps" {
  run generate_workflow_yaml "mixed" "bun"
  [ "$status" -eq 0 ]
  [[ "$output" == *"bun install --frozen-lockfile"* ]]
  [[ "$output" == *"golangci-lint-action@v6"* ]]
}

# ── install_workflow_file ────────────────────────────────────────────────

@test "install_workflow_file: creates .github/workflows/harness-checks.yml on first run" {
  install_workflow_file "$REPO_DIR" "js" "pnpm"
  [ -f "$REPO_DIR/.github/workflows/harness-checks.yml" ]
}

@test "install_workflow_file: creates .github/harness-manifest.json on first run" {
  install_workflow_file "$REPO_DIR" "js" "pnpm"
  [ -f "$REPO_DIR/.github/harness-manifest.json" ]
}

@test "install_workflow_file: manifest checksum matches generated content" {
  install_workflow_file "$REPO_DIR" "js" "pnpm"
  local expected tmp
  tmp=$(mktemp)
  printf '%s\n' "$(generate_workflow_yaml "js" "pnpm")" > "$tmp"
  expected=$(_sha256 "$tmp")
  rm -f "$tmp"
  run _read_manifest_checksum "$REPO_DIR/.github/harness-manifest.json" \
    ".github/workflows/harness-checks.yml"
  [ "$output" = "$expected" ]
}

@test "install_workflow_file: is silent on re-run with unchanged lang and pm" {
  install_workflow_file "$REPO_DIR" "js" "pnpm"
  run install_workflow_file "$REPO_DIR" "js" "pnpm"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "install_workflow_file: prints Installed and updates when checksum is stale" {
  install_workflow_file "$REPO_DIR" "js" "pnpm"
  _write_manifest_entry "$REPO_DIR/.github/harness-manifest.json" \
    ".github/workflows/harness-checks.yml" \
    "0000000000000000000000000000000000000000000000000000000000000000"
  run install_workflow_file "$REPO_DIR" "js" "pnpm"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Installed"* ]]
}

@test "install_workflow_file: installs pnpm-specific content for pnpm repo" {
  install_workflow_file "$REPO_DIR" "js" "pnpm"
  grep -q "pnpm install --frozen-lockfile" "$REPO_DIR/.github/workflows/harness-checks.yml"
  ! grep -q "bun install" "$REPO_DIR/.github/workflows/harness-checks.yml"
}
```

- [ ] **Step 2: Run ci-workflows.bats to confirm the new tests fail**

```bash
bats tests/harness/ci-workflows.bats
```

Expected: the 10 new/updated `generate_workflow_yaml` and `install_workflow_file` tests FAIL. All `_sha256`, `_read_manifest_checksum`, `_write_manifest_entry`, and `detect_overlapping_workflows` tests still PASS.

- [ ] **Step 3: Commit the failing tests**

```bash
git add tests/harness/ci-workflows.bats
git commit -m "test: replace install_workflow_file tests with generated-YAML variants (TDD red)"
```

- [ ] **Step 4: Replace `harness/lib/ci-workflows.sh` with the on-the-fly implementation**

```sh
# _sha256 <file>: cross-platform SHA-256 hex digest
_sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | cut -d' ' -f1
  else
    shasum -a 256 "$1" | cut -d' ' -f1
  fi
}

# _read_manifest_checksum <manifest_file> <relative_path>
# Prints the stored SHA-256 for <relative_path>, or empty string if absent.
_read_manifest_checksum() {
  local manifest_file="$1" path="$2"
  [ -f "$manifest_file" ] || return 0
  grep -F "\"$path\"" "$manifest_file" | grep -oE '[a-f0-9]{64}' | head -1
}

# _write_manifest_entry <manifest_file> <relative_path> <checksum>
# Writes (or rewrites) a single-entry harness-manifest.json.
# Note: rewrites the full file — extend for multi-file manifests in later stories.
_write_manifest_entry() {
  local manifest_file="$1" path="$2" checksum="$3"
  mkdir -p "$(dirname "$manifest_file")"
  printf '{\n  "harness_version": "1",\n  "files": {\n    "%s": "%s"\n  }\n}\n' \
    "$path" "$checksum" > "$manifest_file"
}

# generate_workflow_yaml <lang> <pm>
# Emits the full harness-checks.yml content for the given repo type and package manager.
# lang: js | mixed
# pm:   pnpm | bun
generate_workflow_yaml() {
  local lang="$1" pm="$2"

  cat <<'YAML'
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

      - uses: actions/setup-node@v4
        with:
          node-version: lts/*
YAML

  case "$pm" in
    pnpm)
      cat <<'YAML'

      - uses: pnpm/action-setup@v4
        with:
          run_install: false

      - name: Install dependencies
        run: pnpm install --frozen-lockfile
YAML
      ;;
    bun)
      cat <<'YAML'

      - name: Install dependencies
        run: bun install --frozen-lockfile
YAML
      ;;
  esac

  cat <<'YAML'

      - name: Lint (ESLint)
        run: npx eslint .
YAML

  if [ "$lang" = "mixed" ]; then
    cat <<'YAML'

      - uses: actions/setup-go@v5
        with:
          go-version-file: go.mod

      - name: Lint (golangci-lint)
        uses: golangci/golangci-lint-action@v6
        with:
          version: latest
YAML
  fi
}

# install_workflow_file <repo_root> <lang> <pm>
# Generates harness-checks.yml for the given lang+pm, writes it to
# .github/workflows/harness-checks.yml only when the content has changed
# (delta update via harness-manifest.json checksum).
install_workflow_file() {
  local repo_root="$1" lang="$2" pm="$3"
  local rel_path=".github/workflows/harness-checks.yml"
  local dest="$repo_root/$rel_path"
  local manifest="$repo_root/.github/harness-manifest.json"
  local content tmp current_checksum installed_checksum

  content=$(generate_workflow_yaml "$lang" "$pm")

  tmp=$(mktemp)
  printf '%s\n' "$content" > "$tmp"
  current_checksum=$(_sha256 "$tmp") || { rm -f "$tmp"; return 1; }
  rm -f "$tmp"

  installed_checksum=$(_read_manifest_checksum "$manifest" "$rel_path")

  if [ "$current_checksum" = "$installed_checksum" ] && [ -f "$dest" ]; then
    return 0
  fi

  mkdir -p "$(dirname "$dest")"
  printf '%s\n' "$content" > "$dest"
  _write_manifest_entry "$manifest" "$rel_path" "$current_checksum"
  echo "Installed $rel_path"
}

# detect_overlapping_workflows <repo_root>
# Warns if any existing non-harness workflow contains keywords harness will own.
detect_overlapping_workflows() {
  local repo_root="$1"
  local workflows_dir="$repo_root/.github/workflows"
  [ -d "$workflows_dir" ] || return 0

  for wf in "$workflows_dir"/*.yml "$workflows_dir"/*.yaml; do
    [ -f "$wf" ] || continue
    case "$(basename "$wf")" in harness-checks.yml) continue ;; esac
    if grep -qiE 'eslint|prettier|tsc|golangci.lint|gitleaks' "$wf" 2>/dev/null; then
      echo "WARNING: $(basename "$wf") contains checks that harness will own."
      echo "  To migrate: remove those steps from $(basename "$wf") and re-run setup."
      echo "  harness-checks.yml will run the same checks automatically."
    fi
  done
}
```

- [ ] **Step 5: Run ci-workflows.bats to verify all tests pass**

```bash
bats tests/harness/ci-workflows.bats
```

Expected: all tests PASS.

- [ ] **Step 6: Run the full test suite to confirm no regressions**

```bash
bats tests/harness/
```

Expected: all tests PASS.

- [ ] **Step 7: Commit**

```bash
git add harness/lib/ci-workflows.sh
git commit -m "feat: generate workflow YAML on the fly from lang and PM"
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
  ! grep -q "golangci-lint-action" "$REPO_DIR/.github/workflows/harness-checks.yml"
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
    REPO_PM=$(detect_package_manager "$REPO_ROOT")
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
    install_workflow_file "$REPO_ROOT" "$REPO_LANG" "$REPO_PM"
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
git commit -m "feat: wire lint setup into setup.sh and pass lang+pm to install_workflow_file"
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

- [ ] **Step 2: Update the `## CI workflow scaffolding` prose**

Replace:

```markdown
Setup installs a dedicated GitHub Actions workflow into the target repo:
```

With:

```markdown
Setup generates and installs a dedicated GitHub Actions workflow into the target repo. The workflow is crafted on the fly for the detected repo type (JS/TS or mixed) and package manager (pnpm or bun) — no runtime detection in CI:
```

- [ ] **Step 3: Update the `## Directory structure` section**

Replace the existing `ci-workflows.sh` and `workflows/` lines:

```
    ci-workflows.sh             # install_workflow_file, detect_overlapping_workflows
  workflows/
    harness-checks.yml          # CI workflow template — installed into target repos
```

With:

```
    ci-workflows.sh             # generate_workflow_yaml, install_workflow_file, detect_overlapping_workflows
    lint.sh                     # ensure_eslint_installed, ensure_golangci_lint_available, install_lint_staged_hook, install_golangci_hook
```

- [ ] **Step 4: Run all tests to confirm nothing broke**

```bash
bats tests/harness/
```

Expected: all tests PASS.

- [ ] **Step 5: Commit**

```bash
git add harness/README.md
git commit -m "docs: document linting setup, generated CI workflow, and required status check"
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
| CI workflow runs ESLint (and golangci-lint for mixed) on every PR | Task 4 (`generate_workflow_yaml` produces lang- and pm-specific YAML); Task 5 wires it in |
| No runtime PM or language detection in installed CI workflow | Task 4 (`generate_workflow_yaml` bakes PM and lang in at install time) |
| pnpm repos get pnpm-only steps in CI | Task 4 (`pnpm` case in `generate_workflow_yaml`) |
| bun repos get bun-only steps in CI | Task 4 (`bun` case in `generate_workflow_yaml`) |
| CI lint check configured as required status check | Task 6 (README documents `gh api` command and GitHub Settings path; not automated — requires admin access) |
| If lint tools missing at hook runtime, hook fails with actionable error | Task 3: lint block checks `command -v node`; golangci block checks `command -v golangci-lint` |

### Placeholder scan

No TBD or TODO entries. All steps include exact code.

### Type consistency

- `generate_workflow_yaml <lang> <pm>` — called inside `install_workflow_file` and directly in tests
- `install_workflow_file <repo_root> <lang> <pm>` — called in `setup.sh` as `install_workflow_file "$REPO_ROOT" "$REPO_LANG" "$REPO_PM"`
- `$REPO_PM` is set from `detect_package_manager "$REPO_ROOT"` inside the `js|mixed` case block — same function used internally by `ensure_eslint_installed` etc.
- Checksum written as `printf '%s\n' "$content" > "$tmp"` in `install_workflow_file`, and replicated as `printf '%s\n' "$(generate_workflow_yaml ...)" > "$tmp"` in the test — identical content → identical checksum
- `merge_block` called with 4 args in setup.sh and 3 args in lint.sh — both match `merge_block <file> <id> <content> [position]`
- `ensure_golangci_lint_available` takes no `repo_root` arg (PATH check only) — consistent across lint.sh and setup.sh
- Hook block IDs `lint` and `golangci` — no conflicts with existing `nvm` block ID
