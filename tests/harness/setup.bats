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

@test "exits 0 for pure Go repo with go.mod (gitleaks-only path)" {
  mkdir -p "$REPO_DIR/.git"
  touch "$REPO_DIR/go.mod"
  run bash "$SETUP_SCRIPT" "$REPO_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Pure Go repo"* ]]
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

@test "creates .prettierrc for JS repo when absent" {
  _pnpm_repo_with_hooks
  run bash "$SETUP_SCRIPT" "$REPO_DIR"
  [ "$status" -eq 0 ]
  [ -f "$REPO_DIR/.prettierrc" ]
}

@test ".prettierrc excludes tailwind plugin when tailwindcss absent" {
  _pnpm_repo_with_hooks
  run bash "$SETUP_SCRIPT" "$REPO_DIR"
  [ "$status" -eq 0 ]
  run grep "prettier-plugin-tailwindcss" "$REPO_DIR/.prettierrc"
  [ "$status" -ne 0 ]
}

@test ".prettierrc includes tailwind plugin when tailwindcss in package.json" {
  _pnpm_repo_with_hooks
  printf '{"devDependencies":{"husky":"^9.0.0","tailwindcss":"^3.0.0"}}\n' \
    > "$REPO_DIR/package.json"
  run bash "$SETUP_SCRIPT" "$REPO_DIR"
  [ "$status" -eq 0 ]
  grep -q "prettier-plugin-tailwindcss" "$REPO_DIR/.prettierrc"
}

@test ".lintstagedrc.json includes prettier --check for JS repo" {
  _pnpm_repo_with_hooks
  run bash "$SETUP_SCRIPT" "$REPO_DIR"
  [ "$status" -eq 0 ]
  grep -q "prettier --check" "$REPO_DIR/.lintstagedrc.json"
}

@test "does not merge gofmt block for JS-only repo" {
  _pnpm_repo_with_hooks
  run bash "$SETUP_SCRIPT" "$REPO_DIR"
  [ "$status" -eq 0 ]
  run grep "# harness:gofmt:begin" "$REPO_DIR/.husky/pre-commit"
  [ "$status" -ne 0 ]
}

@test "merges gofmt block into pre-commit for mixed repo" {
  _pnpm_repo_with_hooks
  touch "$REPO_DIR/go.mod"
  run bash "$SETUP_SCRIPT" "$REPO_DIR"
  [ "$status" -eq 0 ]
  grep -q "# harness:gofmt:begin" "$REPO_DIR/.husky/pre-commit"
}

@test "re-run does not duplicate gofmt block for mixed repo" {
  _pnpm_repo_with_hooks
  touch "$REPO_DIR/go.mod"
  bash "$SETUP_SCRIPT" "$REPO_DIR"
  bash "$SETUP_SCRIPT" "$REPO_DIR"
  [ "$(grep -c "harness:gofmt:begin" "$REPO_DIR/.husky/pre-commit")" = "1" ]
}

@test "merges tsc block into pre-commit for JS repo" {
  _pnpm_repo_with_hooks
  run bash "$SETUP_SCRIPT" "$REPO_DIR"
  [ "$status" -eq 0 ]
  grep -q "# harness:tsc:begin" "$REPO_DIR/.husky/pre-commit"
}

@test "merges tsc block into pre-commit for mixed repo" {
  _pnpm_repo_with_hooks
  touch "$REPO_DIR/go.mod"
  run bash "$SETUP_SCRIPT" "$REPO_DIR"
  [ "$status" -eq 0 ]
  grep -q "# harness:tsc:begin" "$REPO_DIR/.husky/pre-commit"
}

@test "merges govet block into pre-commit for mixed repo" {
  _pnpm_repo_with_hooks
  touch "$REPO_DIR/go.mod"
  run bash "$SETUP_SCRIPT" "$REPO_DIR"
  [ "$status" -eq 0 ]
  grep -q "# harness:govet:begin" "$REPO_DIR/.husky/pre-commit"
}

@test "does not merge govet block for JS-only repo" {
  _pnpm_repo_with_hooks
  run bash "$SETUP_SCRIPT" "$REPO_DIR"
  [ "$status" -eq 0 ]
  run grep "# harness:govet:begin" "$REPO_DIR/.husky/pre-commit"
  [ "$status" -ne 0 ]
}

@test "creates tsconfig.json for JS repo when absent" {
  _pnpm_repo_with_hooks
  run bash "$SETUP_SCRIPT" "$REPO_DIR"
  [ "$status" -eq 0 ]
  [ -f "$REPO_DIR/tsconfig.json" ]
}

@test "re-run does not duplicate tsc block in pre-commit" {
  _pnpm_repo_with_hooks
  bash "$SETUP_SCRIPT" "$REPO_DIR"
  bash "$SETUP_SCRIPT" "$REPO_DIR"
  [ "$(grep -c "harness:tsc:begin" "$REPO_DIR/.husky/pre-commit")" = "1" ]
}

@test "re-run does not duplicate govet block for mixed repo" {
  _pnpm_repo_with_hooks
  touch "$REPO_DIR/go.mod"
  bash "$SETUP_SCRIPT" "$REPO_DIR"
  bash "$SETUP_SCRIPT" "$REPO_DIR"
  [ "$(grep -c "harness:govet:begin" "$REPO_DIR/.husky/pre-commit")" = "1" ]
}

# ── gitleaks integration ──────────────────────────────────────────────────────

@test "creates .gitleaks.toml for JS repo" {
  export PATH="$BATS_TEST_DIRNAME/../mocks:$PATH"
  _pnpm_repo_with_hooks
  run bash "$SETUP_SCRIPT" "$REPO_DIR"
  [ "$status" -eq 0 ]
  [ -f "$REPO_DIR/.gitleaks.toml" ]
}

@test "creates .gitleaks.toml for mixed repo" {
  export PATH="$BATS_TEST_DIRNAME/../mocks:$PATH"
  _pnpm_repo_with_hooks
  touch "$REPO_DIR/go.mod"
  run bash "$SETUP_SCRIPT" "$REPO_DIR"
  [ "$status" -eq 0 ]
  [ -f "$REPO_DIR/.gitleaks.toml" ]
}

@test "creates .gitleaks.toml for pure Go repo" {
  export PATH="$BATS_TEST_DIRNAME/../mocks:$PATH"
  mkdir -p "$REPO_DIR/.git"
  touch "$REPO_DIR/go.mod"
  run bash "$SETUP_SCRIPT" "$REPO_DIR"
  [ "$status" -eq 0 ]
  [ -f "$REPO_DIR/.gitleaks.toml" ]
}

@test "merges gitleaks block into .husky/pre-commit for JS repo" {
  export PATH="$BATS_TEST_DIRNAME/../mocks:$PATH"
  _pnpm_repo_with_hooks
  run bash "$SETUP_SCRIPT" "$REPO_DIR"
  [ "$status" -eq 0 ]
  grep -q "# harness:gitleaks:begin" "$REPO_DIR/.husky/pre-commit"
}

@test "merges gitleaks block into .husky/pre-commit for mixed repo" {
  export PATH="$BATS_TEST_DIRNAME/../mocks:$PATH"
  _pnpm_repo_with_hooks
  touch "$REPO_DIR/go.mod"
  run bash "$SETUP_SCRIPT" "$REPO_DIR"
  [ "$status" -eq 0 ]
  grep -q "# harness:gitleaks:begin" "$REPO_DIR/.husky/pre-commit"
}

@test "merges gitleaks block into .git/hooks/pre-commit for pure Go repo" {
  export PATH="$BATS_TEST_DIRNAME/../mocks:$PATH"
  mkdir -p "$REPO_DIR/.git"
  touch "$REPO_DIR/go.mod"
  run bash "$SETUP_SCRIPT" "$REPO_DIR"
  [ "$status" -eq 0 ]
  grep -q "# harness:gitleaks:begin" "$REPO_DIR/.git/hooks/pre-commit"
}

@test "pure Go repo setup exits 0 when go.mod present" {
  export PATH="$BATS_TEST_DIRNAME/../mocks:$PATH"
  mkdir -p "$REPO_DIR/.git"
  touch "$REPO_DIR/go.mod"
  run bash "$SETUP_SCRIPT" "$REPO_DIR"
  [ "$status" -eq 0 ]
}

@test "setup still exits 1 for repo with no package.json and no go.mod" {
  run bash "$SETUP_SCRIPT" "$REPO_DIR"
  [ "$status" -eq 1 ]
  [[ "$output" == *"not supported"* ]]
}

@test "re-run does not duplicate gitleaks block in .husky/pre-commit for JS repo" {
  export PATH="$BATS_TEST_DIRNAME/../mocks:$PATH"
  _pnpm_repo_with_hooks
  bash "$SETUP_SCRIPT" "$REPO_DIR"
  bash "$SETUP_SCRIPT" "$REPO_DIR"
  [ "$(grep -c "harness:gitleaks:begin" "$REPO_DIR/.husky/pre-commit")" = "1" ]
}

@test "re-run does not duplicate gitleaks block in .git/hooks/pre-commit for pure Go repo" {
  export PATH="$BATS_TEST_DIRNAME/../mocks:$PATH"
  mkdir -p "$REPO_DIR/.git"
  touch "$REPO_DIR/go.mod"
  bash "$SETUP_SCRIPT" "$REPO_DIR"
  bash "$SETUP_SCRIPT" "$REPO_DIR"
  [ "$(grep -c "harness:gitleaks:begin" "$REPO_DIR/.git/hooks/pre-commit")" = "1" ]
}

# ── ai-review hook ───────────────────────────────────────────────────────

@test "setup: merges ai-review block into .husky/pre-push for JS repo" {
  _pnpm_repo_with_hooks
  run bash "$SETUP_SCRIPT" "$REPO_DIR"
  [ "$status" -eq 0 ]
  grep -q "# harness:ai-review:begin" "$REPO_DIR/.husky/pre-push"
}

@test "setup: re-run does not duplicate ai-review block in pre-push" {
  _pnpm_repo_with_hooks
  bash "$SETUP_SCRIPT" "$REPO_DIR"
  bash "$SETUP_SCRIPT" "$REPO_DIR"
  [ "$(grep -c 'harness:ai-review:begin' "$REPO_DIR/.husky/pre-push")" = "1" ]
}
