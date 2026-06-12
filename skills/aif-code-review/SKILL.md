---
name: aif-code-review
description: Use when asked to review code changes — either posting findings as inline PR comments or running an interactive local branch review with optional report generation. Triggers on "review this", "give me feedback on", "review my changes", "review this PR", "post findings to PR", "add review comments to the pull request", or any request for a code review.
---

# Code Review

Reviews code changes using 7 structured angles across the diff. Posts findings as inline PR comments directly on GitHub, or runs an interactive triage session on a local working branch with optional report generation at the end.

---

## Mode Selection

**Before spawning a subagent**, ask the user:

> "Are you reviewing a PR or your local working branch?"
> - **PR** — if a PR link or number wasn't provided, ask for it now.
> - **Local branch** — proceed.

- **PR** → spawn a fresh subagent and pass it: the full skill content, the selected mode, and the PR number. The subagent runs the PR Review Path from scratch — no user interaction is needed.
- **Local branch** → before doing anything else, explicitly state: *"Starting fresh local branch review — all prior session context discarded."* Then treat every subsequent step as if this were the first message in a new conversation: no prior analysis, no prior findings, no prior assumptions. Run the Local Branch Review Path from step 1. (Interactive triage in step 8 means this path cannot run as a subagent.)

---

## Severity Levels

| Level | What it means |
|-------|--------------|
| **Critical** | Data loss, security vulnerability, or crash on a reachable code path. Must be fixed before merge. |
| **High** | Logic bug producing a wrong result, broken API contract, missing error handler on a reachable failure path, or race condition. Should be fixed before merge. |
| **Medium** | Inefficiency with measurable impact, duplicated logic that creates a maintenance risk, missing validation that produces confusing but non-crashing behaviour, or a reuse opportunity that meaningfully reduces risk. Worth addressing soon. |
| **Low** | Minor cleanup, simplification, style improvement, or naming. Can be deferred without meaningful risk. |

---

## PR Review Path

Source the diff from GitHub via `gh` — the branch does not need to be checked out locally. No report file is written; all findings are posted as inline PR comments.

**Focus:** correctness first. The goal is to catch bugs, broken contracts, and missing error handling before the code merges — not to push cleanup or style improvements. When running the lower-altitude angles (Simplification, Reuse, Efficiency, Altitude), apply judgment: only raise findings that represent a genuine problem, not cosmetic preferences.

### Skill marker

Every comment posted by this skill ends with the following footer so that skill comments are identifiable on re-reviews. Replace `{model}` with the model ID powering the current session (e.g. `claude-sonnet-4-6`):

```
---
*🤖 aif-code-review · {model}*
```

### Steps

1. Parse the PR number:
   - Full URL (e.g. `https://github.com/owner/repo/pull/42`) → extract the trailing number.
   - Number provided directly → use as-is.
2. Fetch PR metadata and repo identity:
   ```bash
   gh pr view {number} --json number,headRefName,headRefOid,baseRefName,title
   gh repo view --json owner,name
   ```
3. Fetch all existing review threads on the PR — used for both deduplication (step 10) and conversation resolution (step 11):
   ```bash
   gh api graphql -f query='
   query($owner: String!, $repo: String!, $number: Int!) {
     repository(owner: $owner, name: $repo) {
       pullRequest(number: $number) {
         reviewThreads(first: 100) {
           nodes {
             id
             isResolved
             comments(first: 1) {
               nodes { body path originalLine }
             }
           }
         }
       }
     }
   }' -f owner="{owner}" -f repo="{repo}" -F number={number}
   ```
   From the result, derive two sets:
   - **All open threads** — all threads where `isResolved` is false (used for dedup in step 10)
   - **Open skill threads** — subset where `comments[0].body` also contains `aif-code-review` (used for resolution in step 11)
4. Fetch the full PR diff:
   ```bash
   gh pr diff {number}
   ```
5. Run all 7 review angles on the diff; collect candidates with `file`, `line`, `summary`, `failure_scenario`, and assign a severity level (Critical / High / Medium / Low) to each based on the Severity Levels table
6. Deduplicate near-duplicates (same defect, same location → keep one)
7. Verify each candidate — label as **CONFIRMED**, **PLAUSIBLE**, or **REFUTED**
   - PLAUSIBLE by default for: races, nil on rare-but-reachable paths, falsy-zero, off-by-one, regex missing anchor
   - REFUTED only when provably wrong — cite the exact line or invariant that rules it out
8. For each CONFIRMED or PLAUSIBLE finding, validate the suggestion:
   - Look for `package.json`, `go.mod`, `requirements.txt`, or `Gemfile` at the repo root
   - If found: verify any library referenced in the suggestion is available in the installed version; revise or note a required upgrade if not
   - If none found: note no manifest detected and mentally trace any shell commands against the failure modes described
9. Drop all REFUTED findings — see Rules › Refuted findings
10. Deduplicate against existing comments — using the **all open threads** set from step 3, check each remaining finding against every open thread. If any thread's comment already addresses the same issue at the same `path` and `originalLine`, or raises the same concern in substance (regardless of who posted it), skip posting to avoid repeating feedback already given.
11. Resolve addressed conversations — for each open skill thread, check whether the current diff has addressed the issue it describes. If yes, resolve the thread:
    ```bash
    gh api graphql -f query='
    mutation($threadId: ID!) {
      resolveReviewThread(input: {threadId: $threadId}) {
        thread { isResolved }
      }
    }' -f threadId="{thread_id}"
    ```
12. Post each remaining new finding as an inline PR comment — see Inline Comment Format.
13. Determine outcome and print summary:
    - **No new findings and no open skill threads remaining** (all were resolved in step 11): post the following as a PR comment, then print `Review complete — LGTM posted to PR #{number}.`
      ```
      LGTM 👍

      ---
      *🤖 aif-code-review · {model}*
      ```
    - **Otherwise**: post the following as a PR comment, then print `Review complete — posted N comment(s) to PR #{number}.`
      ```
      ## Code Review Summary

      | Severity | Count |
      |----------|-------|
      | Critical | N |
      | High     | N |
      | Medium   | N |
      | Low      | N |

      ## What Looks Good
      - 2–4 specific strengths — name the design decision, not just "good code"

      ---
      *🤖 aif-code-review · {model}*
      ```

---

## Local Branch Review Path

Run the review, triage each finding interactively with the user, then optionally generate a report at the end. Every invocation is treated as a fresh review of the full branch.

### Steps

1. Get branch name: `git rev-parse --abbrev-ref HEAD`
   - If the branch is `main`, `master`, `develop`, or `dev`, **stop immediately** and tell the user: "Code reviews are for feature branches only — switch to a feature branch and re-run."
   - Sanitise the branch name for use as a directory: replace `/` with `-`, strip characters outside `[a-zA-Z0-9._-]`. Store as `<safe-branch>` — used for the report path in step 10 if the user requests one.
2. Get the diff:
   - **Detect the default branch:** try `main`, then `master`, then `develop`, then `dev` — use whichever resolves as a local ref (`git rev-parse --verify <name>`). If none resolve, stop and tell the user: "Cannot find a base branch — please run: `git fetch origin` and ensure the default branch is checked out locally".
   - `git diff $(git merge-base HEAD <base>)...HEAD` for the full diff.
3. Run all 7 review angles on the full diff; collect candidates with `file`, `line`, `summary`, `failure_scenario`, and assign a severity level (Critical / High / Medium / Low) to each based on the Severity Levels table
4. Deduplicate near-duplicates (same defect, same location → keep one)
5. Verify each candidate — label as **CONFIRMED**, **PLAUSIBLE**, or **REFUTED**
   - PLAUSIBLE by default for: races, nil on rare-but-reachable paths, falsy-zero, off-by-one, regex missing anchor
   - REFUTED only when provably wrong — cite the exact line or invariant that rules it out
6. For each CONFIRMED or PLAUSIBLE finding, validate the suggestion:
   - Look for `package.json`, `go.mod`, `requirements.txt`, or `Gemfile` at the repo root
   - If found: check the installed version of any library referenced in the suggestion; if the suggestion uses an API or option not available in that version, revise it to match or note the required upgrade explicitly
   - If none found: note that no manifest was detected, skip version validation, and ensure any shell commands are mentally traced against the failure modes described in the finding
7. Drop all REFUTED findings — see Rules › Refuted findings
8. Triage each finding with the user — if no findings remain after step 7, skip to step 9. Otherwise present findings one at a time in severity order (Critical → High → Medium → Low). For each, show the full finding details (file, line, code excerpt, problem, suggestion) and ask:

   > "Fix now or later?"

   Record the user's answer against each finding. If the user wants to fix it now, assist with the fix before moving to the next finding — mark it **Fixed** once done. If later, mark it **To be fixed**.

9. Print the full review summary:
   - Severity counts table (Critical / High / Medium / Low)
   - All findings grouped by triage: **Fixed** first, then **To be fixed** — each with severity, file, line, and one-line summary
   - What Looks Good (2–4 specific strengths)

10. Ask: "Would you like to generate a written report?"
    - **Yes** → write the report to `review/<safe-branch>/report-<YYYYMMDDHHMMSS>.md` (create the directory if needed: `mkdir -p review/<safe-branch>`). The report follows the Report Template; include each finding's triage status alongside its entry. Print: `Report saved: review/<safe-branch>/<filename>.md`
    - **No** → done.

---

## Review Angles

Shared by both paths. Run all seven; each surfaces up to 6 candidates. Work through each checklist item explicitly — don't just scan.

### Line-by-line

Look for defects in individual statements or small expressions.

- **Condition logic:** inverted `==`/`!=`, wrong boolean operator (`&&` vs `||`), missing negation, condition that is always-true or always-false
- **Off-by-one:** boundary comparisons (`<` vs `<=`), slice/index ranges, loop start/end values, fence-post in pagination or chunking
- **Null/nil safety:** value used before a null check, null returned by a function and immediately dereferenced by its caller, optional field accessed unconditionally
- **Async correctness:** async call made without `await`, `await` on a non-async value, fire-and-forget on a critical path with no error handling
- **Error handling:** catch block that swallows the error (no re-throw, no log, no observable side-effect), error return value ignored at the call site
- **Type coercion:** implicit comparison between incompatible types, string + number concatenation where arithmetic addition was intended
- **Mutation:** function modifying an argument it doesn't own, shared collection mutated during iteration

### Removed behavior

Look for functionality that was deleted but whose absence creates a gap.

- **Input validation:** was a null, length, type, or range check removed from an entry point or guard clause?
- **Error propagation:** was an error path dropped — try/catch added without re-throw, error return ignored, promise rejection left unhandled?
- **Test deletions:** were any tests deleted that cover code paths still present in production code?
- **Guards:** was a defensive condition removed or its predicate weakened (e.g. `> 0` changed to `>= 0`)?
- **Rate limiting / throttling:** was a call-frequency cap, debounce, or retry limit removed?
- **Observability:** was a log, metric, or trace statement removed from an error path or a significant state transition?

### Cross-file

Look for callers or dependents broken by changes in this diff.

- **Signature changes:** function/method signature changed — are all call sites updated to match?
- **Return type changes:** return shape or type changed — do all callers handle the new shape correctly?
- **Precondition strengthening:** function now requires a new invariant (non-null param, specific ordering, pre-initialised state) — do all callers satisfy it?
- **Interface / type changes:** a shared type, interface, or schema changed — are all implementations and consumers updated?
- **Shared utility changes:** a utility used in more than one place was changed — check every caller, not just the one that motivated the change

### Reuse

Look for new code that duplicates something already available.

- **Utility duplication:** does this logic already exist in a shared, utils, or helpers module?
- **Custom error types:** does this code define a new error class or sentinel value that already exists elsewhere in the codebase?
- **Parsing / serialisation:** does this code re-implement data transformation that a shared formatter or library already provides?
- **Validation:** does this code validate inputs in a way an existing validator already handles?

### Simplification

Look for complexity that doesn't pay for itself.

- **Redundant variable:** variable assigned once and used once — could inline it without losing clarity
- **Dead branch:** a condition provably always true or always false given surrounding invariants
- **Copy-paste variation:** two or more blocks doing nearly the same thing with minor differences — could be parameterised
- **Deep nesting:** three or more levels of `if`/loop nesting that a guard clause or extracted function would flatten
- **Unnecessary intermediate:** value transformed through multiple named steps that could be composed directly

### Efficiency

Look for performance problems on reachable paths.

- **Loop-internal constant:** value that doesn't change across iterations computed inside the loop body
- **N+1 I/O:** database query, network call, or file read inside a loop over a result set
- **Sequential I/O:** multiple independent I/O operations run in series when they could run concurrently
- **Over-fetching:** loading a full record or collection when only a small subset of fields or items is needed downstream
- **Blocking hot path:** synchronous or CPU-heavy work on a latency-sensitive request path that should be deferred or offloaded

### Altitude

Look for band-aid patches to shared infrastructure instead of fixing the underlying problem.

- **Special-case parameter:** new parameter added to a shared function whose only purpose is to change behaviour for one specific caller
- **Caller-specific branch:** `if (callerContext === 'X')` or equivalent inside shared infrastructure — shared code shouldn't know about its callers
- **Output patching:** post-processing the result of a shared function at the call site to fix a problem that belongs inside the function itself
- **Layered duplication:** the same logic implemented at multiple layers (e.g. controller + service + repo) because no single layer owns it

---

## Inline Comment Format

Used by the PR Review Path (step 12). All values are already available from steps 1–2: owner and repo from `gh repo view`, PR number from step 1, and `{head_sha}` from the `headRefOid` field in the `gh pr view` response.

### Posting each finding

Assign the body to a variable first to avoid shell escaping issues with multiline content:

```bash
BODY="**[Severity] One-sentence summary**

\`\`\`<lang>
// 5–10 lines of context; problem line marked with // ←
\`\`\`

**Problem:** What breaks, what input/state triggers it, what goes wrong.

**Suggestion:**
\`\`\`<lang>
// Corrected version
\`\`\`

---
*🤖 aif-code-review · {model}*"

gh api \
  --method POST \
  "repos/{owner}/{repo}/pulls/{pr_number}/comments" \
  -f body="$BODY" \
  -f commit_id="{head_sha}" \
  -f path="{file_path}" \
  -F line={line_number} \
  -f side="RIGHT"
```

**Fallback:** If the API returns a 422 (the line is not part of the diff), post as a regular PR comment:

```bash
gh pr comment {pr_number} --body "$BODY"
```

---

## Report Template

*(Local Branch Review Path only)*

```markdown
# Code Review — <branch> (<YYYY-MM-DD HH:MM>)

> **File:** `review/<safe-branch>/report-<YYYYMMDDHHMMSS>.md`
> **Based on:** full branch diff since diverging from `<base>`

## Summary

| Severity | Count |
|----------|-------|
| Critical | N |
| High     | N |
| Medium   | N |
| Low      | N |

<One paragraph: what the change does well, the biggest risk, recommended next step.>

---

## Findings

Each finding follows this structure, grouped under `### Critical`, `### High`, `### Medium`, `### Low` — omit any section with no entries.

#### 1. <One-sentence summary>

**File:** `path/to/file.ext` · **Line:** 42 · **Triage:** Fixed / To be fixed

```<lang>
// 5–15 lines of context; mark the problem line with // ←
```

**Problem:** What breaks, what input/state triggers it, what goes wrong.

**Suggestion:**
```<lang>
// Corrected version
```

> Optional one-line tradeoff note.

---

## What Looks Good

- 2–4 specific strengths — name the design decision, not just "good code"
```

---

## Rules

**Code excerpts:** 5–15 lines of context · correct language fence identifier · mark problem line with `// ←`

**Problem statements:** name the concrete failure — inputs → wrong output/crash/data loss; never "this could be a problem"

**Fix suggestions:** always show corrected code; if no single fix is right, show two options with a one-line tradeoff note

**What looks good:** always include; specifics only; 2–4 bullets max

**Scope:** every confirmed or plausible finding regardless of severity — no cap

**Refuted findings:** drop silently — no struck-through text, no "considered but dismissed" note, no mention at all
