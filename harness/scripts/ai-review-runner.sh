#!/bin/sh
# AI pre-push review — installed by harness. Edit .harness.yml to configure.
HARNESS_AI_MODEL="${HARNESS_AI_MODEL:-claude-sonnet-4-6}"

command -v claude >/dev/null 2>&1 \
  || { echo "harness: ai-review skipped (claude CLI not found)"; exit 0; }

base=$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null \
  || echo "origin/main")

diff=$(git diff "$base"..HEAD -- . \
  ':(exclude)**/*.lock' \
  ':(exclude)**/package-lock.json' \
  ':(exclude)**/go.sum' \
  ':(exclude)**/*.generated.*' \
  ':(exclude)**/dist/**' \
  ':(exclude)**/review/**' \
  2>/dev/null)

[ -n "$diff" ] \
  || { echo "harness: ai-review skipped (no diff to review)"; exit 0; }

sha=$(git rev-parse --short HEAD)
branch=$(git rev-parse --abbrev-ref HEAD | tr '/' '-')
today=$(date +%Y-%m-%d)
review_dir="$(git rev-parse --show-toplevel)/review"
review_file="$review_dir/${today}-${branch}-${sha}.md"

echo "harness: running AI pre-push review..."
review=$(printf 'Review the following diff for code quality, potential bugs, and logic issues. Be concise.\n\n%s\n' \
  "$diff" | claude --model "$HARNESS_AI_MODEL" -p /dev/stdin 2>&1)
review_status=$?

if [ "$review_status" -ne 0 ]; then
  echo "harness: ai-review: claude exited $review_status — review skipped" >&2
  exit 0
fi

echo "$review"

mkdir -p "$review_dir"
printf '# AI Pre-Push Review\n\n**Date:** %s\n**Branch:** %s\n**Commit:** %s\n\n---\n\n%s\n' \
  "$today" "$branch" "$sha" "$review" > "$review_file"

echo "harness: review saved to $review_file"
