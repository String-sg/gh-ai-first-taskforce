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
  local saved_path="$PATH"
  export PATH="$empty_dir"
  run ensure_golangci_lint_available
  export PATH="$saved_path"
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
