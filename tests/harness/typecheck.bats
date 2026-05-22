#!/usr/bin/env bats

setup() {
  source "$BATS_TEST_DIRNAME/../../harness/lib/detect-package-manager.sh"
  source "$BATS_TEST_DIRNAME/../../harness/lib/merge-hook.sh"
  source "$BATS_TEST_DIRNAME/../../harness/lib/typecheck.sh"
  REPO_DIR=$(mktemp -d)
  MOCK_LOG=$(mktemp)
  export MOCK_LOG
  MOCKS_DIR="$BATS_TEST_DIRNAME/../mocks"
}

teardown() {
  rm -rf "$REPO_DIR" "$MOCK_LOG"
}

# ── ensure_typescript_installed ───────────────────────────────────────────────

@test "ensure_typescript_installed: runs pnpm add -D typescript when absent (pnpm repo)" {
  export PATH="$MOCKS_DIR:$PATH"
  printf '{"devDependencies":{}}\n' > "$REPO_DIR/package.json"
  touch "$REPO_DIR/pnpm-lock.yaml"
  ensure_typescript_installed "$REPO_DIR"
  grep -q "mock-pnpm add -D typescript" "$MOCK_LOG"
}

@test "ensure_typescript_installed: runs bun add -D typescript when absent (bun repo)" {
  export PATH="$MOCKS_DIR:$PATH"
  printf '{"devDependencies":{}}\n' > "$REPO_DIR/package.json"
  touch "$REPO_DIR/bun.lockb"
  ensure_typescript_installed "$REPO_DIR"
  grep -q "mock-bun add -D typescript" "$MOCK_LOG"
}

@test "ensure_typescript_installed: skips install when typescript already in package.json" {
  export PATH="$MOCKS_DIR:$PATH"
  printf '{"devDependencies":{"typescript":"^5.0.0"}}\n' > "$REPO_DIR/package.json"
  touch "$REPO_DIR/pnpm-lock.yaml"
  ensure_typescript_installed "$REPO_DIR"
  run grep "mock-pnpm add -D typescript" "$MOCK_LOG"
  [ "$status" -ne 0 ]
}

@test "ensure_typescript_installed: exits 1 for unsupported package manager" {
  printf '{"devDependencies":{}}\n' > "$REPO_DIR/package.json"
  run ensure_typescript_installed "$REPO_DIR"
  [ "$status" -eq 1 ]
}

# ── ensure_tsconfig ───────────────────────────────────────────────────────────

@test "ensure_tsconfig: creates tsconfig.json when none exists" {
  printf '{"devDependencies":{}}\n' > "$REPO_DIR/package.json"
  ensure_tsconfig "$REPO_DIR"
  [ -f "$REPO_DIR/tsconfig.json" ]
}

@test "ensure_tsconfig: created tsconfig.json contains noEmit: true" {
  printf '{"devDependencies":{}}\n' > "$REPO_DIR/package.json"
  ensure_tsconfig "$REPO_DIR"
  grep -q '"noEmit": true' "$REPO_DIR/tsconfig.json"
}

@test "ensure_tsconfig: created tsconfig.json contains strict: true" {
  printf '{"devDependencies":{}}\n' > "$REPO_DIR/package.json"
  ensure_tsconfig "$REPO_DIR"
  grep -q '"strict": true' "$REPO_DIR/tsconfig.json"
}

@test "ensure_tsconfig: includes vite/client type when vite in package.json" {
  printf '{"devDependencies":{"vite":"^5.0.0"}}\n' > "$REPO_DIR/package.json"
  ensure_tsconfig "$REPO_DIR"
  grep -q '"vite/client"' "$REPO_DIR/tsconfig.json"
}

@test "ensure_tsconfig: excludes vite/client type when vite absent from package.json" {
  printf '{"devDependencies":{}}\n' > "$REPO_DIR/package.json"
  ensure_tsconfig "$REPO_DIR"
  run grep '"vite/client"' "$REPO_DIR/tsconfig.json"
  [ "$status" -ne 0 ]
}

@test "ensure_tsconfig: include is src when src/ dir exists" {
  printf '{"devDependencies":{}}\n' > "$REPO_DIR/package.json"
  mkdir -p "$REPO_DIR/src"
  ensure_tsconfig "$REPO_DIR"
  grep -q '"src"' "$REPO_DIR/tsconfig.json"
}

@test "ensure_tsconfig: include is web when web/ dir exists and src/ absent" {
  printf '{"devDependencies":{}}\n' > "$REPO_DIR/package.json"
  mkdir -p "$REPO_DIR/web"
  ensure_tsconfig "$REPO_DIR"
  grep -q '"web"' "$REPO_DIR/tsconfig.json"
}

@test "ensure_tsconfig: include uses src when both src and web dirs exist" {
  printf '{"devDependencies":{}}\n' > "$REPO_DIR/package.json"
  mkdir "$REPO_DIR/src"
  mkdir "$REPO_DIR/web"
  ensure_tsconfig "$REPO_DIR"
  grep -q '"include": \["src"\]' "$REPO_DIR/tsconfig.json"
}

@test "ensure_tsconfig: include uses app when app dir exists and src/web absent" {
  printf '{"devDependencies":{}}\n' > "$REPO_DIR/package.json"
  mkdir "$REPO_DIR/app"
  ensure_tsconfig "$REPO_DIR"
  grep -q '"include": \["app"\]' "$REPO_DIR/tsconfig.json"
}

@test "ensure_tsconfig: include defaults to src when no known dir exists" {
  printf '{"devDependencies":{}}\n' > "$REPO_DIR/package.json"
  ensure_tsconfig "$REPO_DIR"
  grep -q '"src"' "$REPO_DIR/tsconfig.json"
}

@test "ensure_tsconfig: skips when tsconfig.json already exists at root" {
  printf '{"devDependencies":{}}\n' > "$REPO_DIR/package.json"
  printf '{"compilerOptions":{"target":"es2020"}}\n' > "$REPO_DIR/tsconfig.json"
  ensure_tsconfig "$REPO_DIR"
  run grep '"noEmit": true' "$REPO_DIR/tsconfig.json"
  [ "$status" -ne 0 ]
}

@test "ensure_tsconfig: skips when tsconfig.json exists in a subdirectory (excludes node_modules)" {
  printf '{"devDependencies":{}}\n' > "$REPO_DIR/package.json"
  mkdir -p "$REPO_DIR/packages/app"
  printf '{"compilerOptions":{"target":"es2020"}}\n' > "$REPO_DIR/packages/app/tsconfig.json"
  ensure_tsconfig "$REPO_DIR"
  [ ! -f "$REPO_DIR/tsconfig.json" ]
}

# ── ensure_go_vet_available ───────────────────────────────────────────────────

@test "ensure_go_vet_available: returns 0 when go is in PATH" {
  local bin_dir="$REPO_DIR/bin"
  mkdir -p "$bin_dir"
  printf '#!/bin/sh\nexit 0\n' > "$bin_dir/go"
  chmod +x "$bin_dir/go"
  export PATH="$bin_dir:/usr/bin:/bin"
  run ensure_go_vet_available
  [ "$status" -eq 0 ]
}

@test "ensure_go_vet_available: returns 1 with ERROR message mentioning go when Go absent" {
  local empty_dir="$REPO_DIR/empty"
  mkdir -p "$empty_dir"
  local saved_path="$PATH"
  export PATH="$empty_dir"
  run ensure_go_vet_available
  export PATH="$saved_path"
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR"* ]]
  [[ "$output" == *"go"* ]]
}

# ── install_tsc_hook ──────────────────────────────────────────────────────────

@test "install_tsc_hook: merges harness:tsc:begin sentinel into pre-commit" {
  mkdir -p "$REPO_DIR/.husky"
  printf '#!/bin/sh\n' > "$REPO_DIR/.husky/pre-commit"
  chmod +x "$REPO_DIR/.husky/pre-commit"
  printf '{"devDependencies":{}}\n' > "$REPO_DIR/package.json"
  install_tsc_hook "$REPO_DIR"
  grep -q "# harness:tsc:begin" "$REPO_DIR/.husky/pre-commit"
}

@test "install_tsc_hook: pre-commit contains npx tsc --noEmit" {
  mkdir -p "$REPO_DIR/.husky"
  printf '#!/bin/sh\n' > "$REPO_DIR/.husky/pre-commit"
  chmod +x "$REPO_DIR/.husky/pre-commit"
  printf '{"devDependencies":{}}\n' > "$REPO_DIR/package.json"
  install_tsc_hook "$REPO_DIR"
  grep -q "npx tsc --noEmit" "$REPO_DIR/.husky/pre-commit"
}

@test "install_tsc_hook: pre-commit checks command -v npx at runtime" {
  mkdir -p "$REPO_DIR/.husky"
  printf '#!/bin/sh\n' > "$REPO_DIR/.husky/pre-commit"
  chmod +x "$REPO_DIR/.husky/pre-commit"
  printf '{"devDependencies":{}}\n' > "$REPO_DIR/package.json"
  install_tsc_hook "$REPO_DIR"
  grep -q "command -v npx" "$REPO_DIR/.husky/pre-commit"
}

@test "install_tsc_hook: pre-commit errors when no tsconfig.json found" {
  mkdir -p "$REPO_DIR/.husky"
  printf '#!/bin/sh\n' > "$REPO_DIR/.husky/pre-commit"
  chmod +x "$REPO_DIR/.husky/pre-commit"
  printf '{"devDependencies":{}}\n' > "$REPO_DIR/package.json"
  install_tsc_hook "$REPO_DIR"
  grep -q "tsconfig.json" "$REPO_DIR/.husky/pre-commit"
}

@test "install_tsc_hook: is idempotent on re-run" {
  mkdir -p "$REPO_DIR/.husky"
  printf '#!/bin/sh\n' > "$REPO_DIR/.husky/pre-commit"
  chmod +x "$REPO_DIR/.husky/pre-commit"
  printf '{"devDependencies":{}}\n' > "$REPO_DIR/package.json"
  install_tsc_hook "$REPO_DIR"
  install_tsc_hook "$REPO_DIR"
  [ "$(grep -c "harness:tsc:begin" "$REPO_DIR/.husky/pre-commit")" = "1" ]
}

# ── install_go_vet_hook ───────────────────────────────────────────────────────

@test "install_go_vet_hook: merges harness:govet:begin sentinel into pre-commit" {
  mkdir -p "$REPO_DIR/.husky"
  printf '#!/bin/sh\n' > "$REPO_DIR/.husky/pre-commit"
  chmod +x "$REPO_DIR/.husky/pre-commit"
  install_go_vet_hook "$REPO_DIR"
  grep -q "# harness:govet:begin" "$REPO_DIR/.husky/pre-commit"
}

@test "install_go_vet_hook: pre-commit contains go vet" {
  mkdir -p "$REPO_DIR/.husky"
  printf '#!/bin/sh\n' > "$REPO_DIR/.husky/pre-commit"
  chmod +x "$REPO_DIR/.husky/pre-commit"
  install_go_vet_hook "$REPO_DIR"
  grep -q "go vet" "$REPO_DIR/.husky/pre-commit"
}

@test "install_go_vet_hook: pre-commit checks command -v go at runtime" {
  mkdir -p "$REPO_DIR/.husky"
  printf '#!/bin/sh\n' > "$REPO_DIR/.husky/pre-commit"
  chmod +x "$REPO_DIR/.husky/pre-commit"
  install_go_vet_hook "$REPO_DIR"
  grep -q "command -v go" "$REPO_DIR/.husky/pre-commit"
}

@test "install_go_vet_hook: pre-commit only runs when staged .go files present" {
  mkdir -p "$REPO_DIR/.husky"
  printf '#!/bin/sh\n' > "$REPO_DIR/.husky/pre-commit"
  chmod +x "$REPO_DIR/.husky/pre-commit"
  install_go_vet_hook "$REPO_DIR"
  grep -q '\.go' "$REPO_DIR/.husky/pre-commit"
}

@test "install_go_vet_hook: is idempotent on re-run" {
  mkdir -p "$REPO_DIR/.husky"
  printf '#!/bin/sh\n' > "$REPO_DIR/.husky/pre-commit"
  chmod +x "$REPO_DIR/.husky/pre-commit"
  install_go_vet_hook "$REPO_DIR"
  install_go_vet_hook "$REPO_DIR"
  [ "$(grep -c "harness:govet:begin" "$REPO_DIR/.husky/pre-commit")" = "1" ]
}
