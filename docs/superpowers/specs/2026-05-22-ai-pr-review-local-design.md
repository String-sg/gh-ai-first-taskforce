# Design: AI-Assisted Local Pre-Push Review (Issue #13)

**Date:** 2026-05-22
**Status:** Draft
**Issue:** [#13](https://github.com/transformteamsg/ai-first-taskforce/issues/13)

---

## Problem

Developers only get AI review feedback after a PR is opened and CI runs — too late to catch issues before peers look at the code. This story moves that feedback to the developer's terminal, before the push.

---

## Goals

- Surface AI code review in the terminal as part of the pre-push flow
- Zero friction to skip: non-blocking, no key = no error, no Claude = no error
- Opt-in only: not installed unless explicitly enabled in `.harness.yml`

## Non-goals

- Posting anything to GitHub (that is issue #25)
- Blocking the push on review findings
- Supporting non-Claude models in v1

---

## Architecture

```
harness/setup.sh
  └─ reads .harness.yml  (parse_harness_config)
       └─ if ai_review.enabled == true
            └─ ai-review.sh: install_ai_review_hook()
                 └─ merges block into .husky/pre-push
```

A new lib file — `harness/lib/ai-review.sh` — owns all AI review logic, keeping it out of `ci-workflows.sh` (which handles workflow files only) and `secrets.sh` (which handles gitleaks).

`setup.sh` sources `ai-review.sh` and calls `install_ai_review_hook` after the existing hook setup, only when opt-in is confirmed.

---

## Components

### `harness/lib/ai-review.sh`

Three functions:

**`parse_harness_config <repo_root> <key>`**
Reads `.harness.yml` at `<repo_root>` and returns the value for a dotted key (e.g. `ai_review.enabled`). Uses `grep`/`sed` — no external YAML parser required. Returns empty string if the file or key is absent.

**`install_ai_review_hook <repo_root> <model> <api_key_var> <exclude_patterns>`**
Merges the AI review block into `.husky/pre-push` using the existing `merge_block` function. The block contains the inline review script (see below).

**`_ai_review_block <model> <api_key_var> <exclude_patterns>`**
Emits the shell fragment that runs at pre-push time (see Pre-push script below).

### Pre-push script (merged block)

```sh
# harness:ai-review:begin
_harness_ai_review() {
  # skip if claude CLI not available
  command -v claude >/dev/null 2>&1 || { echo "harness: ai-review skipped (claude CLI not found)"; return 0; }
  # skip if API key not set
  [ -n "${<API_KEY_VAR>:-}" ] || { echo "harness: ai-review skipped (<API_KEY_VAR> not set)"; return 0; }

  local base
  base=$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null || echo "origin/main")

  local diff
  diff=$(git diff "$base"..HEAD -- . \
    ':(exclude)**/*.lock' \
    ':(exclude)**/package-lock.json' \
    ':(exclude)**/go.sum' \
    ':(exclude)**/*.generated.*' \
    ':(exclude)**/dist/**' \
    2>/dev/null)

  [ -n "$diff" ] || { echo "harness: ai-review skipped (no diff to review)"; return 0; }

  echo "harness: running AI pre-push review..."
  printf '%s\n\nReview the above diff for code quality, potential bugs, and logic issues. Be concise.' \
    "$diff" | claude --model claude-sonnet-4-6 -p /dev/stdin
}
_harness_ai_review
# harness:ai-review:end
```

The `model`, `api_key_var`, and `exclude_patterns` values from `.harness.yml` are substituted by `install_ai_review_hook` when the block is generated.

### `harness/setup.sh`

After the existing hook setup block, add:

```sh
AI_REVIEW_ENABLED=$(parse_harness_config "$REPO_ROOT" "ai_review.enabled")
if [ "$AI_REVIEW_ENABLED" = "true" ]; then
  AI_MODEL=$(parse_harness_config "$REPO_ROOT" "ai_review.model")
  AI_KEY_VAR=$(parse_harness_config "$REPO_ROOT" "ai_review.api_key_secret")
  AI_EXCLUDES=$(parse_harness_config "$REPO_ROOT" "ai_review.exclude_patterns")
  install_ai_review_hook "$REPO_ROOT" \
    "${AI_MODEL:-claude-sonnet-4-6}" \
    "${AI_KEY_VAR:-ANTHROPIC_API_KEY}" \
    "${AI_EXCLUDES:-}"
  echo "AI pre-push review hook installed."
fi
```

### `.harness.yml` (in target repos)

```yaml
ai_review:
  enabled: true
  model: "claude-sonnet-4-6"          # optional, default: claude-sonnet-4-6
  api_key_secret: "ANTHROPIC_API_KEY" # name of the local env var, optional
  exclude_patterns:                   # optional, harness defaults apply if absent
    - "**/*.lock"
    - "**/package-lock.json"
    - "**/go.sum"
    - "**/*.generated.*"
    - "**/dist/**"
```

---

## Data Flow

```
git push
  └─ pre-push hook fires
       ├─ [existing hooks: lint, format, typecheck, gitleaks]
       └─ _harness_ai_review
            ├─ claude CLI present?  no → warn + exit 0
            ├─ API key set?         no → warn + exit 0
            ├─ git diff upstream..HEAD (exclude patterns applied)
            ├─ diff empty?          yes → skip + exit 0
            └─ pipe diff to: claude --model <model> -p /dev/stdin
                 └─ review printed to terminal
                      └─ exit 0 always
```

---

## Error Handling

| Scenario | Behaviour |
|---|---|
| `claude` CLI not installed | One-line warning, skip, exit 0 |
| API key env var unset or empty | One-line warning, skip, exit 0 |
| No upstream branch configured | Falls back to `origin/main` |
| Diff is empty after filtering | One-line message, skip, exit 0 |
| `claude` CLI exits non-zero | Warning printed, exit 0 (push not blocked) |
| `.harness.yml` absent or `ai_review` block missing | `parse_harness_config` returns empty; setup skips install silently |
| `.harness.yml` malformed | `parse_harness_config` returns empty for the key; setup skips install silently |

---

## Testing

New file: `tests/harness/ai-review.bats`

Scenarios:
- `parse_harness_config` returns correct value for a present key
- `parse_harness_config` returns empty for absent key or missing file
- `install_ai_review_hook` merges the block into `.husky/pre-push`
- `install_ai_review_hook` is idempotent (re-running does not duplicate the block)
- Setup skips install when `ai_review.enabled` is absent or false
- Setup installs hook when `ai_review.enabled: true`
- Pre-push block skips gracefully when `claude` mock is absent (using `tests/mocks/`)
- Pre-push block skips gracefully when API key env var is unset

A mock `claude` binary is added to `tests/mocks/` that echoes a canned review, allowing end-to-end hook execution to be tested without a real API call.

---

## Open Questions

None — all decisions resolved during brainstorming.
