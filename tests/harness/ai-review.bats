#!/usr/bin/env bats

setup() {
  SCRIPT_DIR="$BATS_TEST_DIRNAME/../../harness"
  source "$BATS_TEST_DIRNAME/../../harness/lib/ai-review.sh"
  REPO_DIR=$(mktemp -d)
}

teardown() {
  rm -rf "$REPO_DIR"
}

# ── parse_harness_config ─────────────────────────────────────────────────

@test "parse_harness_config: returns value for present scalar key" {
  cat > "$REPO_DIR/.harness.yml" <<'YAML'
ai_review:
  model: "claude-sonnet-4-6"
  api_key_secret: "MY_API_KEY"
YAML
  run parse_harness_config "$REPO_DIR" "ai_review.model"
  [ "$status" -eq 0 ]
  [ "$output" = "claude-sonnet-4-6" ]
}

@test "parse_harness_config: returns empty for missing key" {
  cat > "$REPO_DIR/.harness.yml" <<'YAML'
ai_review:
  model: "claude-sonnet-4-6"
YAML
  run parse_harness_config "$REPO_DIR" "ai_review.api_key_secret"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "parse_harness_config: returns empty for missing file" {
  run parse_harness_config "$REPO_DIR" "ai_review.model"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "parse_harness_config: returns empty for missing parent section" {
  cat > "$REPO_DIR/.harness.yml" <<'YAML'
other_section:
  key: "value"
YAML
  run parse_harness_config "$REPO_DIR" "ai_review.model"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "parse_harness_config: strips surrounding quotes from value" {
  cat > "$REPO_DIR/.harness.yml" <<'YAML'
ai_review:
  api_key_secret: "ANTHROPIC_API_KEY"
YAML
  run parse_harness_config "$REPO_DIR" "ai_review.api_key_secret"
  [ "$status" -eq 0 ]
  [ "$output" = "ANTHROPIC_API_KEY" ]
}

# ── ai-review-runner.sh skip guards ─────────────────────────────────────

_runner_setup() {
  RUNNER="$BATS_TEST_DIRNAME/../../harness/scripts/ai-review-runner.sh"
  MOCK_PATH="$BATS_TEST_DIRNAME/../mocks"
}

@test "runner: skips with warning when claude CLI not in PATH" {
  _runner_setup
  run env PATH="/usr/bin:/bin" \
    HARNESS_AI_KEY_VAR="ANTHROPIC_API_KEY" ANTHROPIC_API_KEY="test-key" \
    sh "$RUNNER"
  [ "$status" -eq 0 ]
  [[ "$output" == *"claude CLI not found"* ]]
}

# ── ai-review-runner.sh review flow ─────────────────────────────────────

_git_repo_setup() {
  REMOTE_DIR=$(mktemp -d)
  WORK_DIR=$(mktemp -d)

  git -C "$REMOTE_DIR" init --bare -q

  git clone -q "$REMOTE_DIR" "$WORK_DIR" 2>/dev/null
  git -C "$WORK_DIR" config user.email "test@test.com"
  git -C "$WORK_DIR" config user.name "Test"
  git -C "$WORK_DIR" config commit.gpgsign false

  echo "init" > "$WORK_DIR/README.md"
  git -C "$WORK_DIR" add .
  git -C "$WORK_DIR" commit -q -m "init"
  git -C "$WORK_DIR" push -q -u origin main 2>/dev/null

  # Unpushed local commit — this is what the runner will review
  echo "local change" > "$WORK_DIR/app.js"
  git -C "$WORK_DIR" add .
  git -C "$WORK_DIR" commit -q -m "local work"
}

@test "runner: skips when there are no unpushed commits" {
  _runner_setup
  local remote work
  remote=$(mktemp -d)
  work=$(mktemp -d)
  git -C "$remote" init --bare -q
  git clone -q "$remote" "$work" 2>/dev/null
  git -C "$work" config user.email "t@t.com"
  git -C "$work" config user.name "T"
  git -C "$work" config commit.gpgsign false
  echo "init" > "$work/README.md"
  git -C "$work" add .
  git -C "$work" commit -q -m "init"
  git -C "$work" push -q -u origin main 2>/dev/null

  run env PATH="$MOCK_PATH:/usr/bin:/bin:/usr/local/bin" \
    HARNESS_AI_KEY_VAR="ANTHROPIC_API_KEY" ANTHROPIC_API_KEY="test-key" \
    sh -c "cd '$work' && sh '$RUNNER'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"no diff to review"* ]]
  rm -rf "$remote" "$work"
}

@test "runner: calls claude and prints review to terminal" {
  _runner_setup
  _git_repo_setup

  run env PATH="$MOCK_PATH:/usr/bin:/bin:/usr/local/bin" \
    HARNESS_AI_KEY_VAR="ANTHROPIC_API_KEY" ANTHROPIC_API_KEY="test-key" \
    sh -c "cd '$WORK_DIR' && sh '$RUNNER'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"running AI pre-push review"* ]]
  [[ "$output" == *"canned test review"* ]]
  rm -rf "$REMOTE_DIR" "$WORK_DIR"
}

@test "runner: saves review to review/YYYY-MM-DD-<branch>-<sha>.md" {
  _runner_setup
  _git_repo_setup
  local sha branch today
  sha=$(git -C "$WORK_DIR" rev-parse --short HEAD)
  branch=$(git -C "$WORK_DIR" rev-parse --abbrev-ref HEAD | tr '/' '-')
  today=$(date +%Y-%m-%d)

  env PATH="$MOCK_PATH:/usr/bin:/bin:/usr/local/bin" \
    HARNESS_AI_KEY_VAR="ANTHROPIC_API_KEY" ANTHROPIC_API_KEY="test-key" \
    sh -c "cd '$WORK_DIR' && sh '$RUNNER'"

  [ -f "$WORK_DIR/review/${today}-${branch}-${sha}.md" ]
  grep -q "canned test review" "$WORK_DIR/review/${today}-${branch}-${sha}.md"
  rm -rf "$REMOTE_DIR" "$WORK_DIR"
}

@test "runner: review file contains date, branch, and commit SHA header" {
  _runner_setup
  _git_repo_setup
  local sha branch today
  sha=$(git -C "$WORK_DIR" rev-parse --short HEAD)
  branch=$(git -C "$WORK_DIR" rev-parse --abbrev-ref HEAD | tr '/' '-')
  today=$(date +%Y-%m-%d)

  env PATH="$MOCK_PATH:/usr/bin:/bin:/usr/local/bin" \
    HARNESS_AI_KEY_VAR="ANTHROPIC_API_KEY" ANTHROPIC_API_KEY="test-key" \
    sh -c "cd '$WORK_DIR' && sh '$RUNNER'"

  local review_file="$WORK_DIR/review/${today}-${branch}-${sha}.md"
  grep -qF "**Date:** $today" "$review_file"
  grep -qF "**Branch:** $branch" "$review_file"
  grep -qF "**Commit:** $sha" "$review_file"
  rm -rf "$REMOTE_DIR" "$WORK_DIR"
}

@test "runner: does not create a new commit after writing review" {
  _runner_setup
  _git_repo_setup

  env PATH="$MOCK_PATH:/usr/bin:/bin:/usr/local/bin" \
    sh -c "cd '$WORK_DIR' && sh '$RUNNER'"

  [ "$(git -C "$WORK_DIR" log -1 --format='%s')" = "local work" ]
  rm -rf "$REMOTE_DIR" "$WORK_DIR"
}

# ── install_ai_review_runner ─────────────────────────────────────────────

@test "install_ai_review_runner: copies runner to .harness/ai-review-runner.sh" {
  run install_ai_review_runner "$REPO_DIR"
  [ "$status" -eq 0 ]
  [ -f "$REPO_DIR/.harness/ai-review-runner.sh" ]
}

@test "install_ai_review_runner: installed script is executable" {
  install_ai_review_runner "$REPO_DIR"
  [ -x "$REPO_DIR/.harness/ai-review-runner.sh" ]
}

@test "install_ai_review_runner: creates .harness/ directory if absent" {
  [ ! -d "$REPO_DIR/.harness" ]
  install_ai_review_runner "$REPO_DIR"
  [ -d "$REPO_DIR/.harness" ]
}

@test "install_ai_review_runner: is idempotent" {
  install_ai_review_runner "$REPO_DIR"
  run install_ai_review_runner "$REPO_DIR"
  [ "$status" -eq 0 ]
  [ -f "$REPO_DIR/.harness/ai-review-runner.sh" ]
}

# ── install_ai_review_hook ───────────────────────────────────────────────

_husky_setup() {
  source "$BATS_TEST_DIRNAME/../../harness/lib/merge-hook.sh"
  mkdir -p "$REPO_DIR/.husky"
  printf '#!/bin/sh\n' > "$REPO_DIR/.husky/pre-push"
  chmod +x "$REPO_DIR/.husky/pre-push"
}

@test "install_ai_review_hook: copies runner to .harness/" {
  _husky_setup
  run install_ai_review_hook "$REPO_DIR" "claude-sonnet-4-6"
  [ "$status" -eq 0 ]
  [ -f "$REPO_DIR/.harness/ai-review-runner.sh" ]
}

@test "install_ai_review_hook: merges call block into .husky/pre-push" {
  _husky_setup
  install_ai_review_hook "$REPO_DIR" "claude-sonnet-4-6"
  grep -q "# harness:ai-review:begin" "$REPO_DIR/.husky/pre-push"
  grep -q "ai-review-runner.sh" "$REPO_DIR/.husky/pre-push"
  grep -qF 'HARNESS_AI_MODEL="claude-sonnet-4-6"' "$REPO_DIR/.husky/pre-push"
}

@test "install_ai_review_hook: is idempotent — does not duplicate block" {
  _husky_setup
  install_ai_review_hook "$REPO_DIR" "claude-sonnet-4-6"
  install_ai_review_hook "$REPO_DIR" "claude-sonnet-4-6"
  [ "$(grep -c 'harness:ai-review:begin' "$REPO_DIR/.husky/pre-push")" = "1" ]
}
