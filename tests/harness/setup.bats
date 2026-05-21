#!/usr/bin/env bats

setup() {
  export PATH="$BATS_TEST_DIRNAME/../mocks:$PATH"
  REPO_DIR=$(mktemp -d)
  MOCK_LOG=$(mktemp)
  export MOCK_LOG
  SETUP_SCRIPT="$BATS_TEST_DIRNAME/../../harness/setup.sh"
}

teardown() {
  rm -rf "$REPO_DIR" "$MOCK_LOG"
}

_pnpm_repo_with_hooks() {
  printf '{"devDependencies":{"husky":"^9.0.0"}}\n' > "$REPO_DIR/package.json"
  touch "$REPO_DIR/pnpm-lock.yaml"
  mkdir -p "$REPO_DIR/.husky"
  printf '#!/bin/sh\n' > "$REPO_DIR/.husky/pre-commit"
  printf '#!/bin/sh\n' > "$REPO_DIR/.husky/pre-push"
  chmod +x "$REPO_DIR/.husky/pre-commit" "$REPO_DIR/.husky/pre-push"
}

_bun_repo_with_hooks() {
  printf '{"devDependencies":{"husky":"^9.0.0"}}\n' > "$REPO_DIR/package.json"
  touch "$REPO_DIR/bun.lockb"
  mkdir -p "$REPO_DIR/.husky"
  printf '#!/bin/sh\n' > "$REPO_DIR/.husky/pre-commit"
  printf '#!/bin/sh\n' > "$REPO_DIR/.husky/pre-push"
  chmod +x "$REPO_DIR/.husky/pre-commit" "$REPO_DIR/.husky/pre-push"
}

@test "exits 1 with clear message for pure Go repo" {
  touch "$REPO_DIR/go.mod"
  run bash "$SETUP_SCRIPT" "$REPO_DIR"
  [ "$status" -eq 1 ]
  [[ "$output" == *"not supported"* ]]
}

@test "exits 1 with clear message for unsupported package manager" {
  printf '{"devDependencies":{}}\n' > "$REPO_DIR/package.json"
  run bash "$SETUP_SCRIPT" "$REPO_DIR"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unsupported package manager"* ]]
}

@test "succeeds for pnpm JS repo" {
  _pnpm_repo_with_hooks
  run bash "$SETUP_SCRIPT" "$REPO_DIR"
  [ "$status" -eq 0 ]
}

@test "succeeds for bun JS repo" {
  _bun_repo_with_hooks
  run bash "$SETUP_SCRIPT" "$REPO_DIR"
  [ "$status" -eq 0 ]
}

@test "succeeds for mixed repo (package.json + go.mod)" {
  _pnpm_repo_with_hooks
  touch "$REPO_DIR/go.mod"
  run bash "$SETUP_SCRIPT" "$REPO_DIR"
  [ "$status" -eq 0 ]
}

@test "merges NVM block into pre-commit" {
  _pnpm_repo_with_hooks
  bash "$SETUP_SCRIPT" "$REPO_DIR"
  grep -q "# harness:nvm:begin" "$REPO_DIR/.husky/pre-commit"
}

@test "merges NVM block into pre-push" {
  _pnpm_repo_with_hooks
  bash "$SETUP_SCRIPT" "$REPO_DIR"
  grep -q "# harness:nvm:begin" "$REPO_DIR/.husky/pre-push"
}

@test "re-run does not duplicate NVM block in pre-commit" {
  _pnpm_repo_with_hooks
  bash "$SETUP_SCRIPT" "$REPO_DIR"
  bash "$SETUP_SCRIPT" "$REPO_DIR"
  [ "$(grep -c "harness:nvm:begin" "$REPO_DIR/.husky/pre-commit")" = "1" ]
}

@test "re-run does not duplicate NVM block in pre-push" {
  _pnpm_repo_with_hooks
  bash "$SETUP_SCRIPT" "$REPO_DIR"
  bash "$SETUP_SCRIPT" "$REPO_DIR"
  [ "$(grep -c "harness:nvm:begin" "$REPO_DIR/.husky/pre-push")" = "1" ]
}

@test "preserves existing team hook content" {
  printf '{"devDependencies":{"husky":"^9.0.0"}}\n' > "$REPO_DIR/package.json"
  touch "$REPO_DIR/pnpm-lock.yaml"
  mkdir -p "$REPO_DIR/.husky"
  printf '#!/bin/sh\n# team custom rule\npnpm run custom\n' > "$REPO_DIR/.husky/pre-commit"
  printf '#!/bin/sh\n' > "$REPO_DIR/.husky/pre-push"
  chmod +x "$REPO_DIR/.husky/pre-commit" "$REPO_DIR/.husky/pre-push"
  bash "$SETUP_SCRIPT" "$REPO_DIR"
  grep -q "# team custom rule" "$REPO_DIR/.husky/pre-commit"
}

@test "installs .github/workflows/harness-checks.yml into target repo" {
  _pnpm_repo_with_hooks
  run bash "$SETUP_SCRIPT" "$REPO_DIR"
  [ "$status" -eq 0 ]
  [ -f "$REPO_DIR/.github/workflows/harness-checks.yml" ]
}

@test "creates .github/harness-manifest.json in target repo" {
  _pnpm_repo_with_hooks
  run bash "$SETUP_SCRIPT" "$REPO_DIR"
  [ "$status" -eq 0 ]
  [ -f "$REPO_DIR/.github/harness-manifest.json" ]
}

@test "re-run does not print Installed when workflow is unchanged" {
  _pnpm_repo_with_hooks
  bash "$SETUP_SCRIPT" "$REPO_DIR"
  run bash "$SETUP_SCRIPT" "$REPO_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" != *"Installed"* ]]
}
