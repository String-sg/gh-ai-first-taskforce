# Test Fixtures — Agent Pattern Feedback Loop

This directory documents the sample test case for the `aif-code-review` →
`aif-implement-issue` feedback loop introduced in this repo.

## Sample app

`harness/lib/ai-review.sh` is the fixture. It is a realistic but intentionally
agent-flavoured implementation of the harness library. It embeds four documented
AI-characteristic patterns (tagged `AP-TAG` in the source):

| Tag location | Pattern name | Angle |
|---|---|---|
| `parse_harness_config`, branch block | Parameterise Instead of Copy-Pasting | Simplification |
| `parse_harness_config`, end of function | Log or Re-throw in Every Catch | Line-by-line |
| `install_ai_review_runner`, after `mkdir -p` | Log or Re-throw in Every Catch | Line-by-line |
| `install_ai_review_hook`, `local data` declaration | Use Domain-Specific Variable Names | Line-by-line |

## How to run the walkthrough

See the PR test plan for the step-by-step workflow. In brief:

1. On a branch containing `harness/lib/ai-review.sh`, run `/aif-code-review`
   (Local Branch path). The new step 8 should tag the four patterns above and
   write them to `review/agent-patterns.md`.

2. Create a GitHub issue that asks for a function similar to
   `parse_harness_config` and run `/aif-implement-issue`. Step 3 should read
   `review/agent-patterns.md` and apply the Prevention instructions before
   writing any code.

3. Verify the resulting implementation uses a generic dotted-key parser (no
   per-key branches), emits a diagnostic on unknown keys, and uses a
   domain-specific variable name instead of `data`.
