#!/usr/bin/env bats

setup() {
  source "$BATS_TEST_DIRNAME/../../harness/lib/detect-package-manager.sh"
  source "$BATS_TEST_DIRNAME/../../harness/lib/husky.sh"
  export PATH="$BATS_TEST_DIRNAME/../mocks:$PATH"
  REPO_DIR=$(mktemp -d)
  MOCK_LOG=$(mktemp)
  export MOCK_LOG
}

teardown() {
  rm -rf "$REPO_DIR" "$MOCK_LOG"
}

@test "is_husky_installed: returns 1 when no husky in package.json" {
  printf '{"devDependencies":{}}\n' > "$REPO_DIR/package.json"
  run is_husky_installed "$REPO_DIR"
  [ "$status" -eq 1 ]
}

@test "is_husky_installed: returns 0 when husky is in devDependencies" {
  printf '{"devDependencies":{"husky":"^9.0.0"}}\n' > "$REPO_DIR/package.json"
  run is_husky_installed "$REPO_DIR"
  [ "$status" -eq 0 ]
}

@test "ensure_husky_installed: runs pnpm add when husky absent (pnpm repo)" {
  printf '{"devDependencies":{}}\n' > "$REPO_DIR/package.json"
  touch "$REPO_DIR/pnpm-lock.yaml"
  ensure_husky_installed "$REPO_DIR"
  grep -q "mock-pnpm add -D husky" "$MOCK_LOG"
}

@test "ensure_husky_installed: runs bun add when husky absent (bun repo)" {
  printf '{"devDependencies":{}}\n' > "$REPO_DIR/package.json"
  touch "$REPO_DIR/bun.lockb"
  ensure_husky_installed "$REPO_DIR"
  grep -q "mock-bun add -D husky" "$MOCK_LOG"
}

@test "ensure_husky_installed: skips install when husky already present" {
  printf '{"devDependencies":{"husky":"^9.0.0"}}\n' > "$REPO_DIR/package.json"
  touch "$REPO_DIR/pnpm-lock.yaml"
  ensure_husky_installed "$REPO_DIR"
  run grep "mock-pnpm add" "$MOCK_LOG"
  [ "$status" -ne 0 ]
}

@test "ensure_husky_installed: exits 1 for unsupported package manager" {
  printf '{"devDependencies":{}}\n' > "$REPO_DIR/package.json"
  run ensure_husky_installed "$REPO_DIR"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unsupported package manager"* ]]
}

@test "ensure_husky_init: runs pnpm exec husky init when .husky absent" {
  touch "$REPO_DIR/pnpm-lock.yaml"
  ensure_husky_init "$REPO_DIR"
  [ -d "$REPO_DIR/.husky" ]
  grep -q "mock-pnpm exec husky init" "$MOCK_LOG"
}

@test "ensure_husky_init: runs bunx husky init when .husky absent (bun repo)" {
  touch "$REPO_DIR/bun.lockb"
  ensure_husky_init "$REPO_DIR"
  [ -d "$REPO_DIR/.husky" ]
  grep -q "mock-bunx husky init" "$MOCK_LOG"
}

@test "ensure_husky_init: resets sample pre-commit to bare shebang after init" {
  touch "$REPO_DIR/pnpm-lock.yaml"
  ensure_husky_init "$REPO_DIR"
  run cat "$REPO_DIR/.husky/pre-commit"
  [ "$output" = "#!/bin/sh" ]
}

@test "ensure_husky_init: skips init when .husky already exists" {
  mkdir -p "$REPO_DIR/.husky"
  printf '#!/bin/sh\n# existing team hook\n' > "$REPO_DIR/.husky/pre-commit"
  chmod +x "$REPO_DIR/.husky/pre-commit"
  touch "$REPO_DIR/pnpm-lock.yaml"
  ensure_husky_init "$REPO_DIR"
  run grep "mock-pnpm exec husky init" "$MOCK_LOG"
  [ "$status" -ne 0 ]
}
