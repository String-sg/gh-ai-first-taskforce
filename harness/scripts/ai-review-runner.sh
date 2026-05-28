#!/bin/sh
# AI pre-push review — installed by harness. Edit .harness.yml to configure.
HARNESS_AI_MODEL="${HARNESS_AI_MODEL:-claude-sonnet-4-6}"

_harness_ai_review() {
  command -v claude >/dev/null 2>&1 \
    || { echo "harness: ai-review skipped (claude CLI not found)"; return 0; }

  local base
  base=$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null \
    || echo "origin/main")

  local diff
  diff=$(git diff "$base"..HEAD -- . \
    ':(exclude)**/*.lock' \
    ':(exclude)**/package-lock.json' \
    ':(exclude)**/go.sum' \
    ':(exclude)**/*.generated.*' \
    ':(exclude)**/dist/**' \
    2>/dev/null)

  [ -n "$diff" ] \
    || { echo "harness: ai-review skipped (no diff to review)"; return 0; }

  local sha branch today review_dir review_file
  sha=$(git rev-parse --short HEAD)
  branch=$(git rev-parse --abbrev-ref HEAD | tr '/' '-')
  today=$(date +%Y-%m-%d)
  review_dir="$(git rev-parse --show-toplevel)/review"
  review_file="$review_dir/${today}-${branch}-${sha}.md"

  echo "harness: running AI pre-push review..."
  local review
  review=$(printf 'Review the following diff for code quality, potential bugs, and logic issues. Be concise.\n\n%s\n' \
    "$diff" | claude --model "$HARNESS_AI_MODEL" -p /dev/stdin 2>&1) || true

  echo "$review"

  mkdir -p "$review_dir"
  printf '# AI Pre-Push Review\n\n**Date:** %s\n**Branch:** %s\n**Commit:** %s\n\n---\n\n%s\n' \
    "$today" "$branch" "$sha" "$review" > "$review_file"

  git -c commit.gpgsign=false add "review/" \
    && git -c commit.gpgsign=false commit --no-verify \
         -m "chore: ai review for ${branch} @ ${sha}" \
         -- "review/" \
    || true

  echo "harness: review saved to $review_file"
}

_harness_ai_review
