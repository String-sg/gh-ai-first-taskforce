#!/usr/bin/env bats

setup() {
  source "$BATS_TEST_DIRNAME/../../harness/lib/merge-hook.sh"
  source "$BATS_TEST_DIRNAME/../../harness/lib/secrets.sh"
  REPO_DIR=$(mktemp -d)
  MOCK_LOG=$(mktemp)
  export MOCK_LOG
  MOCKS_DIR="$BATS_TEST_DIRNAME/../mocks"
}

teardown() {
  rm -rf "$REPO_DIR" "$MOCK_LOG"
}

# ── ensure_gitleaks_available ─────────────────────────────────────────────────

@test "ensure_gitleaks_available: returns 0 when gitleaks already in PATH" {
  export PATH="$MOCKS_DIR:$PATH"
  run ensure_gitleaks_available
  [ "$status" -eq 0 ]
}

@test "ensure_gitleaks_available: does not invoke brew when gitleaks already installed" {
  export PATH="$MOCKS_DIR:$PATH"
  ensure_gitleaks_available
  run grep "mock-brew" "$MOCK_LOG"
  [ "$status" -ne 0 ]
}

@test "ensure_gitleaks_available: installs via brew when gitleaks absent and brew present" {
  local fake_bin="$REPO_DIR/bin"
  mkdir -p "$fake_bin"
  cp "$MOCKS_DIR/brew" "$fake_bin/brew"
  export PATH="$fake_bin:/usr/bin:/bin"
  ensure_gitleaks_available || true
  grep -q "mock-brew install gitleaks" "$MOCK_LOG"
}

@test "ensure_gitleaks_available: installs via go when gitleaks absent, brew absent, go present" {
  local fake_bin="$REPO_DIR/bin"
  mkdir -p "$fake_bin"
  cp "$MOCKS_DIR/go" "$fake_bin/go"
  export PATH="$fake_bin:/usr/bin:/bin"
  ensure_gitleaks_available || true
  grep -q "mock-go install github.com/zricethezav/gitleaks/v8@latest" "$MOCK_LOG"
}

@test "ensure_gitleaks_available: returns 1 with ERROR when gitleaks absent and no installer available" {
  local empty="$REPO_DIR/empty"
  mkdir -p "$empty"
  export PATH="$empty:/usr/bin:/bin"
  run ensure_gitleaks_available
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR"* ]]
}

@test "ensure_gitleaks_available: error message includes brew install command" {
  local empty="$REPO_DIR/empty"
  mkdir -p "$empty"
  export PATH="$empty:/usr/bin:/bin"
  run ensure_gitleaks_available
  [[ "$output" == *"brew install gitleaks"* ]]
}

@test "ensure_gitleaks_available: error message includes go install command" {
  local empty="$REPO_DIR/empty"
  mkdir -p "$empty"
  export PATH="$empty:/usr/bin:/bin"
  run ensure_gitleaks_available
  [[ "$output" == *"go install"*"gitleaks"* ]]
}

# ── ensure_gitleaks_config ────────────────────────────────────────────────────

@test "ensure_gitleaks_config: creates .gitleaks.toml when none exists" {
  ensure_gitleaks_config "$REPO_DIR"
  [ -f "$REPO_DIR/.gitleaks.toml" ]
}

@test "ensure_gitleaks_config: created config contains useDefault = true" {
  ensure_gitleaks_config "$REPO_DIR"
  grep -q "useDefault = true" "$REPO_DIR/.gitleaks.toml"
}

@test "ensure_gitleaks_config: created config contains allowlist comment guidance" {
  ensure_gitleaks_config "$REPO_DIR"
  grep -q "allowlist" "$REPO_DIR/.gitleaks.toml"
}

@test "ensure_gitleaks_config: skips when .gitleaks.toml already exists" {
  printf 'title = "custom"\n' > "$REPO_DIR/.gitleaks.toml"
  ensure_gitleaks_config "$REPO_DIR"
  run grep "useDefault" "$REPO_DIR/.gitleaks.toml"
  [ "$status" -ne 0 ]
}

@test "ensure_gitleaks_config: is idempotent — does not modify existing config" {
  printf 'title = "custom"\n' > "$REPO_DIR/.gitleaks.toml"
  ensure_gitleaks_config "$REPO_DIR"
  ensure_gitleaks_config "$REPO_DIR"
  [ "$(wc -l < "$REPO_DIR/.gitleaks.toml" | tr -d ' ')" = "1" ]
}

# ── install_gitleaks_hook ─────────────────────────────────────────────────────

@test "install_gitleaks_hook: merges harness:gitleaks:begin sentinel into pre-commit" {
  mkdir -p "$REPO_DIR/.husky"
  printf '#!/bin/sh\n' > "$REPO_DIR/.husky/pre-commit"
  chmod +x "$REPO_DIR/.husky/pre-commit"
  install_gitleaks_hook "$REPO_DIR"
  grep -q "# harness:gitleaks:begin" "$REPO_DIR/.husky/pre-commit"
}

@test "install_gitleaks_hook: pre-commit contains gitleaks protect --staged" {
  mkdir -p "$REPO_DIR/.husky"
  printf '#!/bin/sh\n' > "$REPO_DIR/.husky/pre-commit"
  chmod +x "$REPO_DIR/.husky/pre-commit"
  install_gitleaks_hook "$REPO_DIR"
  grep -q "gitleaks protect --staged" "$REPO_DIR/.husky/pre-commit"
}

@test "install_gitleaks_hook: pre-commit checks command -v gitleaks at runtime" {
  mkdir -p "$REPO_DIR/.husky"
  printf '#!/bin/sh\n' > "$REPO_DIR/.husky/pre-commit"
  chmod +x "$REPO_DIR/.husky/pre-commit"
  install_gitleaks_hook "$REPO_DIR"
  grep -q "command -v gitleaks" "$REPO_DIR/.husky/pre-commit"
}

@test "install_gitleaks_hook: pre-commit error message includes install command" {
  mkdir -p "$REPO_DIR/.husky"
  printf '#!/bin/sh\n' > "$REPO_DIR/.husky/pre-commit"
  chmod +x "$REPO_DIR/.husky/pre-commit"
  install_gitleaks_hook "$REPO_DIR"
  grep -q "brew install gitleaks" "$REPO_DIR/.husky/pre-commit"
}

@test "install_gitleaks_hook: pre-commit output includes next-steps guidance on failure" {
  mkdir -p "$REPO_DIR/.husky"
  printf '#!/bin/sh\n' > "$REPO_DIR/.husky/pre-commit"
  chmod +x "$REPO_DIR/.husky/pre-commit"
  install_gitleaks_hook "$REPO_DIR"
  grep -q "allowlist" "$REPO_DIR/.husky/pre-commit"
}

@test "install_gitleaks_hook: pre-commit output mentions rotating credentials on failure" {
  mkdir -p "$REPO_DIR/.husky"
  printf '#!/bin/sh\n' > "$REPO_DIR/.husky/pre-commit"
  chmod +x "$REPO_DIR/.husky/pre-commit"
  install_gitleaks_hook "$REPO_DIR"
  grep -q "[Rr]otat" "$REPO_DIR/.husky/pre-commit"
}

@test "install_gitleaks_hook: is idempotent on re-run" {
  mkdir -p "$REPO_DIR/.husky"
  printf '#!/bin/sh\n' > "$REPO_DIR/.husky/pre-commit"
  chmod +x "$REPO_DIR/.husky/pre-commit"
  install_gitleaks_hook "$REPO_DIR"
  install_gitleaks_hook "$REPO_DIR"
  [ "$(grep -c "harness:gitleaks:begin" "$REPO_DIR/.husky/pre-commit")" = "1" ]
}

# ── install_gitleaks_git_hook ─────────────────────────────────────────────────

@test "install_gitleaks_git_hook: creates .git/hooks/pre-commit if absent" {
  mkdir -p "$REPO_DIR/.git"
  install_gitleaks_git_hook "$REPO_DIR"
  [ -f "$REPO_DIR/.git/hooks/pre-commit" ]
}

@test "install_gitleaks_git_hook: .git/hooks/pre-commit is executable" {
  mkdir -p "$REPO_DIR/.git"
  install_gitleaks_git_hook "$REPO_DIR"
  [ -x "$REPO_DIR/.git/hooks/pre-commit" ]
}

@test "install_gitleaks_git_hook: merges harness:gitleaks:begin sentinel" {
  mkdir -p "$REPO_DIR/.git/hooks"
  printf '#!/bin/sh\n' > "$REPO_DIR/.git/hooks/pre-commit"
  chmod +x "$REPO_DIR/.git/hooks/pre-commit"
  install_gitleaks_git_hook "$REPO_DIR"
  grep -q "# harness:gitleaks:begin" "$REPO_DIR/.git/hooks/pre-commit"
}

@test "install_gitleaks_git_hook: hook contains gitleaks protect --staged" {
  mkdir -p "$REPO_DIR/.git"
  install_gitleaks_git_hook "$REPO_DIR"
  grep -q "gitleaks protect --staged" "$REPO_DIR/.git/hooks/pre-commit"
}

@test "install_gitleaks_git_hook: is idempotent on re-run" {
  mkdir -p "$REPO_DIR/.git"
  install_gitleaks_git_hook "$REPO_DIR"
  install_gitleaks_git_hook "$REPO_DIR"
  [ "$(grep -c "harness:gitleaks:begin" "$REPO_DIR/.git/hooks/pre-commit")" = "1" ]
}

@test "install_gitleaks_git_hook: preserves existing hook content" {
  mkdir -p "$REPO_DIR/.git/hooks"
  printf '#!/bin/sh\n# existing hook content\n' > "$REPO_DIR/.git/hooks/pre-commit"
  chmod +x "$REPO_DIR/.git/hooks/pre-commit"
  install_gitleaks_git_hook "$REPO_DIR"
  grep -q "# existing hook content" "$REPO_DIR/.git/hooks/pre-commit"
}
