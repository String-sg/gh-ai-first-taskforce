#!/usr/bin/env bats

setup() {
  source "$BATS_TEST_DIRNAME/../../harness/lib/detect-package-manager.sh"
  source "$BATS_TEST_DIRNAME/../../harness/lib/merge-hook.sh"
  source "$BATS_TEST_DIRNAME/../../harness/lib/format.sh"
  REPO_DIR=$(mktemp -d)
  MOCK_LOG=$(mktemp)
  export MOCK_LOG
  MOCKS_DIR="$BATS_TEST_DIRNAME/../mocks"
}

teardown() {
  rm -rf "$REPO_DIR" "$MOCK_LOG"
}

# ── _has_tailwind ──────────────────────────────────────────────────────────

@test "_has_tailwind: returns 0 when tailwindcss in package.json" {
  printf '{"dependencies":{"tailwindcss":"^3.0.0"}}\n' > "$REPO_DIR/package.json"
  run _has_tailwind "$REPO_DIR"
  [ "$status" -eq 0 ]
}

@test "_has_tailwind: returns 1 when tailwindcss absent from package.json" {
  printf '{"devDependencies":{}}\n' > "$REPO_DIR/package.json"
  run _has_tailwind "$REPO_DIR"
  [ "$status" -eq 1 ]
}

# ── ensure_prettier_installed ──────────────────────────────────────────────

@test "ensure_prettier_installed: runs pnpm add when prettier absent (pnpm repo)" {
  export PATH="$MOCKS_DIR:$PATH"
  printf '{"devDependencies":{}}\n' > "$REPO_DIR/package.json"
  touch "$REPO_DIR/pnpm-lock.yaml"
  ensure_prettier_installed "$REPO_DIR"
  grep -q "mock-pnpm add -D prettier" "$MOCK_LOG"
}

@test "ensure_prettier_installed: runs bun add when prettier absent (bun repo)" {
  export PATH="$MOCKS_DIR:$PATH"
  printf '{"devDependencies":{}}\n' > "$REPO_DIR/package.json"
  touch "$REPO_DIR/bun.lockb"
  ensure_prettier_installed "$REPO_DIR"
  grep -q "mock-bun add -D prettier" "$MOCK_LOG"
}

@test "ensure_prettier_installed: skips install when prettier already present" {
  export PATH="$MOCKS_DIR:$PATH"
  printf '{"devDependencies":{"prettier":"^3.0.0"}}\n' > "$REPO_DIR/package.json"
  touch "$REPO_DIR/pnpm-lock.yaml"
  ensure_prettier_installed "$REPO_DIR"
  run grep "mock-pnpm add -D prettier$" "$MOCK_LOG"
  [ "$status" -ne 0 ]
}

@test "ensure_prettier_installed: exits 1 for unsupported package manager" {
  printf '{"devDependencies":{}}\n' > "$REPO_DIR/package.json"
  run ensure_prettier_installed "$REPO_DIR"
  [ "$status" -eq 1 ]
}

@test "ensure_prettier_installed: installs prettier-plugin-tailwindcss when tailwindcss present" {
  export PATH="$MOCKS_DIR:$PATH"
  printf '{"dependencies":{"tailwindcss":"^3.0.0"},"devDependencies":{"prettier":"^3.0.0"}}\n' \
    > "$REPO_DIR/package.json"
  touch "$REPO_DIR/pnpm-lock.yaml"
  ensure_prettier_installed "$REPO_DIR"
  grep -q "mock-pnpm add -D prettier-plugin-tailwindcss" "$MOCK_LOG"
}

@test "ensure_prettier_installed: does not install tailwind plugin when tailwindcss absent" {
  export PATH="$MOCKS_DIR:$PATH"
  printf '{"devDependencies":{"prettier":"^3.0.0"}}\n' > "$REPO_DIR/package.json"
  touch "$REPO_DIR/pnpm-lock.yaml"
  ensure_prettier_installed "$REPO_DIR"
  run grep "mock-pnpm add -D prettier-plugin-tailwindcss" "$MOCK_LOG"
  [ "$status" -ne 0 ]
}

@test "ensure_prettier_installed: skips tailwind plugin when already present" {
  export PATH="$MOCKS_DIR:$PATH"
  printf '{"dependencies":{"tailwindcss":"^3.0.0"},"devDependencies":{"prettier":"^3.0.0","prettier-plugin-tailwindcss":"^0.5.0"}}\n' \
    > "$REPO_DIR/package.json"
  touch "$REPO_DIR/pnpm-lock.yaml"
  ensure_prettier_installed "$REPO_DIR"
  run grep "mock-pnpm add -D prettier-plugin-tailwindcss" "$MOCK_LOG"
  [ "$status" -ne 0 ]
}

# ── ensure_prettier_config ─────────────────────────────────────────────────

@test "ensure_prettier_config: creates .prettierrc when no config exists" {
  printf '{"devDependencies":{}}\n' > "$REPO_DIR/package.json"
  ensure_prettier_config "$REPO_DIR"
  [ -f "$REPO_DIR/.prettierrc" ]
}

@test "ensure_prettier_config: .prettierrc contains printWidth 150" {
  printf '{"devDependencies":{}}\n' > "$REPO_DIR/package.json"
  ensure_prettier_config "$REPO_DIR"
  grep -q '"printWidth": 150' "$REPO_DIR/.prettierrc"
}

@test "ensure_prettier_config: .prettierrc includes tailwind plugin when tailwindcss present" {
  printf '{"dependencies":{"tailwindcss":"^3.0.0"}}\n' > "$REPO_DIR/package.json"
  ensure_prettier_config "$REPO_DIR"
  grep -q "prettier-plugin-tailwindcss" "$REPO_DIR/.prettierrc"
}

@test "ensure_prettier_config: .prettierrc excludes tailwind plugin when tailwindcss absent" {
  printf '{"devDependencies":{}}\n' > "$REPO_DIR/package.json"
  ensure_prettier_config "$REPO_DIR"
  run grep "prettier-plugin-tailwindcss" "$REPO_DIR/.prettierrc"
  [ "$status" -ne 0 ]
}

@test "ensure_prettier_config: skips when .prettierrc already exists" {
  printf '{"devDependencies":{}}\n' > "$REPO_DIR/package.json"
  printf '{"printWidth": 80}\n' > "$REPO_DIR/.prettierrc"
  ensure_prettier_config "$REPO_DIR"
  run grep '"printWidth": 150' "$REPO_DIR/.prettierrc"
  [ "$status" -ne 0 ]
}

@test "ensure_prettier_config: skips when .prettierrc.json already exists" {
  printf '{"devDependencies":{}}\n' > "$REPO_DIR/package.json"
  printf '{"printWidth": 80}\n' > "$REPO_DIR/.prettierrc.json"
  ensure_prettier_config "$REPO_DIR"
  [ ! -f "$REPO_DIR/.prettierrc" ]
}

@test "ensure_prettier_config: skips when prettier.config.js already exists" {
  printf '{"devDependencies":{}}\n' > "$REPO_DIR/package.json"
  printf 'module.exports = {}\n' > "$REPO_DIR/prettier.config.js"
  ensure_prettier_config "$REPO_DIR"
  [ ! -f "$REPO_DIR/.prettierrc" ]
}

# ── install_prettier_staged ────────────────────────────────────────────────

@test "install_prettier_staged: creates .lintstagedrc.json with prettier when no config exists" {
  install_prettier_staged "$REPO_DIR"
  [ -f "$REPO_DIR/.lintstagedrc.json" ]
}

@test "install_prettier_staged: .lintstagedrc.json contains prettier --check" {
  install_prettier_staged "$REPO_DIR"
  grep -q "prettier --check" "$REPO_DIR/.lintstagedrc.json"
}

@test "install_prettier_staged: .lintstagedrc.json contains eslint" {
  install_prettier_staged "$REPO_DIR"
  grep -q "eslint" "$REPO_DIR/.lintstagedrc.json"
}

@test "install_prettier_staged: is idempotent when prettier already in .lintstagedrc.json" {
  printf '{"*.{js,jsx,ts,tsx}":["prettier --check","eslint"]}\n' \
    > "$REPO_DIR/.lintstagedrc.json"
  install_prettier_staged "$REPO_DIR"
  [ "$(grep -c "prettier" "$REPO_DIR/.lintstagedrc.json")" = "1" ]
}

@test "install_prettier_staged: skips when lint-staged key in package.json has prettier" {
  printf '{"lint-staged":{"*.ts":["prettier --check"]}}\n' > "$REPO_DIR/package.json"
  install_prettier_staged "$REPO_DIR"
  [ ! -f "$REPO_DIR/.lintstagedrc.json" ]
}

# ── ensure_goimports_available ────────────────────────────────────────────

@test "ensure_goimports_available: returns 0 when goimports in PATH" {
  local bin_dir="$REPO_DIR/bin"
  mkdir -p "$bin_dir"
  printf '#!/bin/sh\nexit 0\n' > "$bin_dir/goimports"
  chmod +x "$bin_dir/goimports"
  export PATH="$bin_dir:/usr/bin:/bin"
  run ensure_goimports_available
  [ "$status" -eq 0 ]
}

@test "ensure_goimports_available: runs go install when go available and goimports absent" {
  local go_bin="$REPO_DIR/go-bin"
  mkdir -p "$go_bin"
  printf '#!/bin/sh\necho "mock-go $*" >> "%s"\n' "$MOCK_LOG" > "$go_bin/go"
  chmod +x "$go_bin/go"
  export PATH="$go_bin:/usr/bin:/bin"
  run ensure_goimports_available
  [ "$status" -eq 0 ]
  grep -q "mock-go install golang.org/x/tools/cmd/goimports" "$MOCK_LOG"
}

@test "ensure_goimports_available: fails with actionable error when neither found" {
  local empty_dir="$REPO_DIR/empty"
  mkdir -p "$empty_dir"
  local saved_path="$PATH"
  export PATH="$empty_dir"
  run ensure_goimports_available
  export PATH="$saved_path"
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR"* ]]
  [[ "$output" == *"goimports"* ]]
}

# ── install_gofmt_hook ────────────────────────────────────────────────────

@test "install_gofmt_hook: merges gofmt block into pre-commit" {
  mkdir -p "$REPO_DIR/.husky"
  printf '#!/bin/sh\n' > "$REPO_DIR/.husky/pre-commit"
  chmod +x "$REPO_DIR/.husky/pre-commit"
  install_gofmt_hook "$REPO_DIR"
  grep -q "# harness:gofmt:begin" "$REPO_DIR/.husky/pre-commit"
}

@test "install_gofmt_hook: pre-commit contains gofmt -l" {
  mkdir -p "$REPO_DIR/.husky"
  printf '#!/bin/sh\n' > "$REPO_DIR/.husky/pre-commit"
  chmod +x "$REPO_DIR/.husky/pre-commit"
  install_gofmt_hook "$REPO_DIR"
  grep -q "gofmt -l" "$REPO_DIR/.husky/pre-commit"
}

@test "install_gofmt_hook: pre-commit contains goimports -l" {
  mkdir -p "$REPO_DIR/.husky"
  printf '#!/bin/sh\n' > "$REPO_DIR/.husky/pre-commit"
  chmod +x "$REPO_DIR/.husky/pre-commit"
  install_gofmt_hook "$REPO_DIR"
  grep -q "goimports -l" "$REPO_DIR/.husky/pre-commit"
}

@test "install_gofmt_hook: only runs when staged .go files present" {
  mkdir -p "$REPO_DIR/.husky"
  printf '#!/bin/sh\n' > "$REPO_DIR/.husky/pre-commit"
  chmod +x "$REPO_DIR/.husky/pre-commit"
  install_gofmt_hook "$REPO_DIR"
  grep -q '\.go' "$REPO_DIR/.husky/pre-commit"
}

@test "install_gofmt_hook: block checks for gofmt at runtime" {
  mkdir -p "$REPO_DIR/.husky"
  printf '#!/bin/sh\n' > "$REPO_DIR/.husky/pre-commit"
  chmod +x "$REPO_DIR/.husky/pre-commit"
  install_gofmt_hook "$REPO_DIR"
  grep -q "command -v gofmt" "$REPO_DIR/.husky/pre-commit"
}

@test "install_gofmt_hook: is idempotent on re-run" {
  mkdir -p "$REPO_DIR/.husky"
  printf '#!/bin/sh\n' > "$REPO_DIR/.husky/pre-commit"
  chmod +x "$REPO_DIR/.husky/pre-commit"
  install_gofmt_hook "$REPO_DIR"
  install_gofmt_hook "$REPO_DIR"
  [ "$(grep -c "harness:gofmt:begin" "$REPO_DIR/.husky/pre-commit")" = "1" ]
}
