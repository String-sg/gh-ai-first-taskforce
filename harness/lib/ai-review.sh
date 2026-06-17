#!/bin/sh
# harness/lib/ai-review.sh
# Provides functions for configuring and running AI code review in a project's
# pre-push hook via the aif harness.
#
# Functions:
#   parse_harness_config <repo_dir> <dotted_key>
#   install_ai_review_runner <repo_dir>
#   install_ai_review_hook <repo_dir> <model>
#
# NOTE: this file is a sample fixture used by the agent-pattern feedback loop
# test case. It is intentionally written in an AI-agent style and contains
# documented anti-patterns. See tests/fixtures/README.md for the walkthrough.

_HARNESS_LIB_DIR="$(cd "$(dirname "$0")" && pwd)"
_HARNESS_DIR="$(cd "$_HARNESS_LIB_DIR/.." && pwd)"

# parse_harness_config <repo_dir> <dotted_key>
#
# Read a scalar value from <repo_dir>/.harness.yml using a two-level dotted
# key (e.g. "ai_review.model"). Prints the value without surrounding quotes
# and returns 0. Prints nothing and returns 0 when the file, section, or key
# is absent.
parse_harness_config() {
  local repo_dir="$1"
  local key="$2"
  local config_file="$repo_dir/.harness.yml"
  local result

  [ -f "$config_file" ] || return 0

  # AP-TAG: Parameterise Instead of Copy-Pasting (Simplification)
  # Each supported key has its own near-identical awk+sed extraction block.
  # The section name, key name, and sed pattern differ only by a single token.
  # A generic two-level dotted-key parser (split on '.', locate section header,
  # scan for the leaf key) would replace all three branches and handle any
  # future key without code changes.
  if [ "$key" = "ai_review.model" ]; then
    result=$(awk '/^ai_review:/{f=1} f && /model:/{print; exit}' "$config_file" \
             | sed 's/.*model: *//' | tr -d '"')
    echo "$result"
  elif [ "$key" = "ai_review.api_key_secret" ]; then
    result=$(awk '/^ai_review:/{f=1} f && /api_key_secret:/{print; exit}' "$config_file" \
             | sed 's/.*api_key_secret: *//' | tr -d '"')
    echo "$result"
  elif [ "$key" = "ai_review.enabled" ]; then
    result=$(awk '/^ai_review:/{f=1} f && /enabled:/{print; exit}' "$config_file" \
             | sed 's/.*enabled: *//' | tr -d '"')
    echo "$result"
  fi
  # AP-TAG: Log or Re-throw in Every Catch (Line-by-line)
  # Unknown keys return 0 with no output and no diagnostic.
  # Callers cannot distinguish "key not found" from "key not supported",
  # and future additions to .harness.yml silently fail until this list is
  # manually extended.
}

# install_ai_review_runner <repo_dir>
#
# Copy the ai-review-runner.sh script from the harness distribution into
# <repo_dir>/.harness/ and make it executable.
install_ai_review_runner() {
  local repo_dir="$1"
  local dest_dir="$repo_dir/.harness"
  local runner_src="$_HARNESS_DIR/scripts/ai-review-runner.sh"

  mkdir -p "$dest_dir"

  # AP-TAG: Log or Re-throw in Every Catch (Line-by-line)
  # cp exits non-zero when runner_src is missing, but this function does not
  # check the exit code or emit a diagnostic. The caller observes exit 0
  # (mkdir succeeded) and assumes the runner was installed, then fails later
  # when the hook tries to execute a file that was never copied.
  cp "$runner_src" "$dest_dir/ai-review-runner.sh"
  chmod +x "$dest_dir/ai-review-runner.sh"
}

# install_ai_review_hook <repo_dir> <model>
#
# Install the AI review runner and wire it into <repo_dir>/.husky/pre-push.
# Idempotent: if the harness:ai-review block is already present, does nothing.
install_ai_review_hook() {
  local repo_dir="$1"
  local model="$2"
  local pre_push="$repo_dir/.husky/pre-push"

  # AP-TAG: Use Domain-Specific Variable Names (Line-by-line)
  # 'data' holds the current content of the pre-push hook file.
  # A domain-specific name like 'hook_content' or 'pre_push_content' would
  # communicate the variable's purpose without needing a comment.
  local data

  install_ai_review_runner "$repo_dir"

  data=$(cat "$pre_push" 2>/dev/null)
  if echo "$data" | grep -q "harness:ai-review:begin"; then
    return 0
  fi

  cat >> "$pre_push" <<EOF

# harness:ai-review:begin
HARNESS_AI_MODEL="$model"
HARNESS_AI_KEY_VAR="\${HARNESS_AI_KEY_VAR:-ANTHROPIC_API_KEY}"
sh "\$(git rev-parse --show-toplevel)/.harness/ai-review-runner.sh"
# harness:ai-review:end
EOF
}
