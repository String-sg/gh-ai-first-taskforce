---
name: code-review-report
description: Use when asked to review code changes and produce a written feedback report with code snippets and suggestions. Triggers on "review this", "give me feedback on", "review my changes", or any request for a review output document.
---

# Code Review Report

Produce a structured markdown review report for a set of code changes. Each finding shows the relevant code snippet, the problem, and a concrete suggestion — so the author can act without context-switching.

Use `superpowers:requesting-code-review` instead when you need a fast pass during active development and no saved report is needed.

---

## Severity Labels

- **Critical** — data loss, security flaw, crash on reachable path
- **Important** — logic bug, broken contract, missing error handling
- **Suggestion** — cleanup, simplification, reuse opportunity, style

---

## Process

1. Get branch name: `git rev-parse --abbrev-ref HEAD`
   - If the branch is `main`, `master`, `develop`, or `dev`, **stop immediately** and tell the user: "Code reviews are for feature branches only — switch to a feature branch and re-run."
2. Check for prior reports: `ls review/<branch-name>/` (if the directory exists)
   - If prior reports exist, read the most recent one to find the last reviewed HEAD SHA (recorded in the report's "Reviewed Commits" section), then **prompt the user about prior findings before doing anything else** (see Re-review below)
3. Get the diff:
   - **First review:** `git log main..HEAD --oneline` to list all branch commits, then `git diff $(git merge-base HEAD main)...HEAD` for the full diff. Record every commit SHA + message.
   - **Subsequent review:** Use the last reviewed HEAD SHA from the prior report. Run `git log <last-sha>..HEAD --oneline` to list new commits only, then `git diff <last-sha>..HEAD` for the delta. Record only the new commits.
4. Run all 7 review angles; collect candidates with `file`, `line`, `summary`, `failure_scenario`
5. Deduplicate near-duplicates (same defect, same location → keep one)
6. Verify each candidate — label as **CONFIRMED**, **PLAUSIBLE**, or **REFUTED**
   - PLAUSIBLE by default for: races, nil on rare-but-reachable paths, falsy-zero, off-by-one, regex missing anchor
   - REFUTED only when provably wrong — cite the exact line or invariant that rules it out
7. Drop all REFUTED findings — silently; no mention of them in the report in any form
8. If re-review: reconcile remaining findings with prior dispositions (see Re-review below)
9. Count total kept findings:
   - **< 10:** all findings get full entries including Suggestions
   - **≥ 10:** Critical and Important get full entries; Suggestions roll into a "Cleanup Notes" bullet list
10. Group findings under `### Critical`, `### Important`, `### Suggestion` subsections — omit any subsection with no entries
11. Write the report to `review/<branch-name>/report-<DDMMYYYYHHMMSS>.md` — create the directory if needed: `mkdir -p review/<branch-name>`

---

## Review Angles

Run all seven. Each surfaces up to 6 candidates.

| Angle | What to look for |
|-------|-----------------|
| **Line-by-line** | Inverted conditions, off-by-one, null deref, missing `await`, error swallowed in catch |
| **Removed behavior** | Deleted guards, dropped error paths, narrowed validation, deleted tests covering real cases |
| **Cross-file** | Callers broken by changed signature/return shape/precondition; callees made unsafe |
| **Reuse** | New code re-implementing something that already exists in shared/utility modules |
| **Simplification** | Redundant state, copy-paste with slight variation, deep nesting, dead code |
| **Efficiency** | Redundant computation, repeated I/O, sequential work that could be parallel, hot-path blocking |
| **Altitude** | Special-case bandaids layered on shared infrastructure instead of fixing the underlying mechanism |

---

## Re-review

**Scope:** Only the new commits (delta since last review) are analysed for new findings through the 7 review angles. Prior findings from the last report are each checked against the current code to assign a disposition (see table below) — they are not re-analysed through the 7 review angles.

Before running any analysis, present each prior finding as a numbered list and ask:

> "The previous review on `<date>` found N finding(s). For each one, will it be fixed? If not, please give a reason."

Wait for the user's response, then assign dispositions:

| User response | Disposition |
|---------------|-------------|
| Will be fixed | **Persists** — carry forward into Findings with a `(carried over)` note |
| Won't fix — reason given | **Won't fix** — record reason in the Prior Review table; do not carry into Findings |
| Not mentioned | Reconcile against the diff (table below) |

For findings not covered by the user's response, reconcile against the current diff:

| Prior finding state | Disposition |
|---------------------|-------------|
| Code at the flagged location is fixed | **Resolved** |
| Code at the flagged location is gone (refactored away, deleted) | **No longer applicable** |
| Finding is still present, unchanged | **Persists** — carry forward |
| Finding partially addressed but problem remains | **Partially addressed** — carry forward with a note |

---

## Report Template

```markdown
# Code Review — <branch> (<YYYY-MM-DD HH:MM>)

> **File:** `review/<branch>/report-<DDMMYYYYHHMMSS>.md`
> **Based on:** commits up to `<HEAD short SHA>` *(first review: full branch; subsequent: delta since `<prior HEAD SHA>`)*

## Summary

| Severity | Count |
|----------|-------|
| Critical | N |
| Important | N |
| Suggestion | N |

<One paragraph: what the change does well, the biggest risk, recommended next step.>

---

## Reviewed Commits

| SHA (short) | Message |
|-------------|---------|
| `abc1234` | feat: add X |

*First review: all commits on branch since diverging from main. Subsequent reviews: only commits since the last reviewed SHA.*

---

## Prior Review  *(omit on first review)*

> Previous report: `review/<branch>/report-<prior-DDMMYYYYHHMMSS>.md`

| # | Finding | Disposition |
|---|---------|-------------|
| 1 | <one-line summary> | ✅ Resolved / ➖ No longer applicable / ⚠️ Persists / 🔶 Partially addressed / 🚫 Won't fix — <reason> |

*Persists and Partially addressed findings are carried forward into Findings below.*

---

## Findings

### Critical

#### 1. <One-sentence summary>

**File:** `path/to/file.ext` · **Line:** 42
*(carried over from <prior date> — partially addressed)* ← include only if applicable

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

### Important

#### 1. <One-sentence summary>

*(same structure as Critical)*

---

### Suggestion  *(omit when total findings ≥ 10 — use Cleanup Notes instead)*

#### 1. <One-sentence summary>

*(same structure as Critical)*

---

## Cleanup Notes  *(only when total findings ≥ 10)*

- One bullet per suggestion-level finding — no code excerpts needed

---

## What Looks Good

- 2–4 specific strengths — name the design decision, not just "good code"
```

---

## Output File

- Path: `review/<branch-name>/report-<DDMMYYYYHHMMSS>.md` relative to the repo root
- Sanitise `<branch-name>`: replace `/` with `-`, strip characters outside `[a-zA-Z0-9._-]`
- Datetime: local time, 24-hour — e.g. `report-03062026143045.md`
- After writing, print: `Report saved: review/<branch-name>/<filename>.md`

---

## Rules

**Code excerpts:** 5–15 lines of context · correct language fence identifier · mark problem line with `// ←`

**Problem statements:** name the concrete failure — inputs → wrong output/crash/data loss; never "this could be a problem"

**Suggestions:** always show corrected code; if no single fix is right, show two options with a one-line tradeoff note

**What looks good:** always include; specifics only; 2–4 bullets max

**Scope:** every confirmed or plausible Critical/Important — no cap; Suggestions in full when < 10 total, rolled into Cleanup Notes when ≥ 10

**Refuted findings:** drop silently — no struck-through text, no "considered but dismissed" note, no mention at all
