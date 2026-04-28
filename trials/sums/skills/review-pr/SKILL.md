---

name: review-pr
description: Run a full pre-merge review of the current PR branch: rebase onto main, resolve any merge conflicts, analyse changes, check test coverage, scan for CLAUDE.md violations, run build and unit tests, document new gap patterns, then work through a sequential TODO list of fixes — each committed separately. Use when user says "review code".

---

## Before you begin

Run these guard checks and stop if any fail — do not proceed with an empty or wrong context.

```bash
# 1. Confirm gh CLI is available
gh --version

# 2. Confirm we are not on main or master
git branch --show-current
```

If the current branch is `main` or `master`: stop and tell the user to switch to their PR branch first.

```bash
# 3. Confirm an open PR exists for this branch
gh pr view --json number,state,title
```

If no PR is found: stop and tell the user to open a PR for this branch first.

```bash
# 4. Check how far behind main this branch is
git fetch origin main --quiet
git log HEAD..origin/main --oneline
```

Count the commits. If main is more than **5 commits ahead**, warn before proceeding:

> "Warning: main is N commits ahead of this branch. The rebase in Phase 0 may produce multiple conflicts. Consider reviewing the main changes first (`git log HEAD..origin/main`) to understand what will need merging."

This is informational — do not stop, but surface it so the user can decide whether to proceed or coordinate with other PRs first.

---

## Phase 0 — Rebase onto main

Run this before any analysis. The diff must reflect the rebased state, not a stale branch.

```bash
# Fetch latest main
git fetch origin main

# Check if rebase is needed
git log HEAD..origin/main --oneline
```

If main has no new commits since the branch diverged: state "Branch is up to date with main — skipping rebase." and proceed to Phase 1.

If main has new commits, rebase:

```bash
git rebase origin/main
```

**If the rebase exits cleanly:** push the rebased branch:

```bash
git push --force-with-lease
```

**If the rebase reports conflicts:** for each conflicted file:

1. Show the conflict:
   ```bash
   git diff --name-only --diff-filter=U
   ```
2. Read the conflicted file — understand what the incoming change (from main) and the branch change both intend.
3. Resolve by editing the file to the correct merged state — do not simply accept one side blindly. If the intent of both changes is unclear, stop and ask the user before resolving.
4. Stage the resolved file:
   ```bash
   git add <resolved_file>
   ```
5. Continue the rebase:
   ```bash
   git rebase --continue
   ```
6. Repeat for each conflict until `git rebase --continue` completes cleanly.

After all conflicts are resolved and rebase is complete:

```bash
git push --force-with-lease
```

`--force-with-lease` is used instead of `--force` to guard against overwriting commits pushed by someone else since the last fetch.

**If a conflict cannot be resolved with confidence:** abort the rebase, restore the branch to its pre-rebase state, and tell the user what needs manual resolution:

```bash
git rebase --abort
```

Do not proceed to Phase 1 with an unresolved or aborted rebase.

### After the rebase — regenerate Prisma client (unconditional)

```bash
npx prisma generate
```

Always run this after any rebase — even if this branch did not touch `prisma/schema.prisma`. The rebase may have brought in schema changes from main (e.g. a recently merged PR that dropped or added columns), leaving the local `prisma/generated/` client stale and causing false type errors. The command is idempotent and completes in ~30 ms.

Also run `npx tsc --noEmit` immediately after to catch any type errors introduced by the rebase before proceeding:

```bash
npx tsc --noEmit 2>&1
```

If type errors are found: add them to the TODO list as HIGH — `fix build error: <summary>` — and resolve them in Phase 6 before the final push.

---

## Phase 1 — PR Analysis

Collect the context that all later phases depend on.

```bash
# PR metadata
gh pr view --json number,title,body,state,baseRefName

# All files changed in this branch vs main
git diff main...HEAD --name-only

# Commits introduced by this branch
git log main..HEAD --oneline

# Full diff (used for grep-based checks in Phase 3)
git diff main...HEAD
```

**Extract the test plan** from the PR body: find the section whose heading contains any of "Test plan", "Steps to test", "Testing", "How to test" (case-insensitive). Extract each checklist item or numbered step.

If no such section exists in the PR body: add to TODO (LOW) — `docs: add test plan section to PR description`.

**Carry forward:**
- `CHANGED_FILES` — output of `git diff main...HEAD --name-only`
- `TS_TSX_CHANGED` — subset of CHANGED_FILES matching `*.ts` / `*.tsx`
- `TEST_PLAN_STEPS` — extracted steps from the PR test plan
- `FULL_DIFF` — output of `git diff main...HEAD`

---

## Phase 2 — Test Coverage Check

**Files to exclude from all coverage checks:**
`src/app/**/page.tsx`, `src/app/**/layout.tsx`, `src/app/**/loading.tsx`, `src/components/**`, `prisma/**`, `*.config.ts`, `src/test/**`, `tests/**`

### Unit test mapping

For each file in `CHANGED_FILES` under `src/lib/` or `src/app/api/` (that is not excluded):

```bash
# Derive expected unit test path
# e.g. src/lib/quota-utils.ts → src/test/quota-utils.test.ts
# e.g. src/lib/api/require-auth.ts → src/test/require-auth.test.ts
ls src/test/<basename>.test.ts
```

If the test file does not exist: add to TODO (LOW) — `test: add unit test for <file>`

### Integration test mapping

For each file matching `src/app/api/**/route.ts` in `CHANGED_FILES`:

```bash
# e.g. src/app/api/studies/route.ts → look for tests/api/studies.test.ts
ls tests/api/ | grep -i "<route-path-segment>"
```

If no integration test file matches: add to TODO (LOW) — `test: add integration test for <route>`

### Test plan step coverage

For each step in `TEST_PLAN_STEPS`, search for keywords from the step in existing test files:

```bash
grep -rn "<keyword>" src/test/ tests/api/ --include="*.test.ts"
```

If no match found: add to TODO (LOW) — `test: add coverage for "<step>"`

**Before writing any new test:** run `git diff main...HEAD -- <source_file>` to read the actual implementation first.

---

## Phase 3 — Code Standards Scan

### A. Hardcoded credentials — gitleaks (authoritative)

```bash
gitleaks detect --log-opts "main..HEAD"
```

gitleaks uses 240+ patterns plus entropy detection. This is the authoritative scan — do not supplement with grep. If gitleaks reports any findings: add to TODO (CRITICAL) — `fix: remove hardcoded credential in <file>` for each finding.

### B. `any` casts — grep (pre-hook safety net)

The pre-commit hook already blocks `any` casts in staged changes. This grep catches anything committed before the hook was installed.

```bash
git diff main...HEAD -- '*.ts' '*.tsx' | grep "^+" | grep -E "(: any|as any|Record<string, any>)"
```

For each match: add to TODO (MEDIUM) — `fix: replace any cast in <file> with correct type`

### C. ESLint disable comments — grep (pre-hook safety net)

```bash
git diff main...HEAD -- '*.ts' '*.tsx' | grep "^+" | grep -E "eslint-disable"
```

For each match: add to TODO (MEDIUM) — `fix: remove eslint-disable comment in <file> and model the correct type`

### D. Shared lookup data declared locally — LLM judgment

```bash
# Find inline array/object declarations in page and component files
git diff main...HEAD -- '*.tsx' '*.ts' | grep "^+" | grep -E "const\s+\w+\s*=\s*\["
```

For each match in a page file or component (not in `src/lib/`): check if the same or equivalent constant already exists in `src/lib/`:

```bash
grep -rn "<matched_name>" src/lib/ --include="*.ts"
```

If the constant is a static list of categories, labels, or options and is not already in `lib/`: add to TODO (MEDIUM) — `fix: move shared constant <name> in <file> to src/lib/ and import it`

This check requires judgment — not all inline arrays are shared lookup data.

### E. Orphaned files — shell first-pass + LLM judgment

```bash
# Files deleted in this branch
git log --diff-filter=D --name-only --format="" main..HEAD | sort -u

# Files added in this branch
git diff main...HEAD --name-only --diff-filter=A
```

For each new file added: check if a same-purpose older file still exists alongside it (same directory, similar name, overlapping function):

```bash
ls $(dirname <new_file>)
```

If an older file exists with the same purpose as a new one and was not deleted: add to TODO (MEDIUM) — `fix: delete orphaned file <path> superseded by <new_file>`

This requires judgment — confirm the older file is actually superseded, not a separate concern.

### F. Env var coverage — shell compare

```bash
# All process.env references introduced in this branch
git diff main...HEAD | grep "^+" | grep -oE "process\.env\.[A-Z_]+" | sort -u

# Keys currently in .env.example
cat .env.example
```

For each `process.env.VAR` in the diff that has no entry in `.env.example`: add to TODO (MEDIUM) — `fix: add <VAR> to .env.example with a placeholder value`

### G. Build-time DB calls — grep (pre-hook safety net)

```bash
git diff main...HEAD -- '*.ts' '*.tsx' | grep "^+" | grep -E "(generateStaticParams|getStaticProps)"
```

If any match found, check whether `prisma.` or `fetch(` appears in the same function context:

```bash
git diff main...HEAD -- <matched_file> | grep -A 20 "generateStaticParams\|getStaticProps" | grep "prisma\.\|fetch("
```

For each match: add to TODO (MEDIUM) — `fix: remove DB/API call from build-time function in <file>; use ISR or on-demand revalidation`

### H. Dockerfile integrity — grep (pre-hook safety net)

```bash
git diff main...HEAD --name-only | grep -q "^Dockerfile$" && grep "COPY prisma ./prisma" Dockerfile
```

If Dockerfile is in the diff but missing `COPY prisma ./prisma`: add to TODO (HIGH) — `fix: add COPY prisma ./prisma to Dockerfile before RUN npx prisma generate`

---

## Phase 4 — Build & Test

Run in this order.

### Unit tests (unconditional — no DB required)

```bash
npm test 2>&1
```

Parse output for `FAIL`, `× `, `Error:` within a test context. For each failure: add to TODO (HIGH) — `fix failing test: <test name>`

### Build (unconditional)

```bash
npm run build 2>&1
```

`npm run build` runs `prisma generate` then `next build`. Parse for `Type error:`, `error TS`, `Build failed`. For each error: add to TODO (HIGH) — `fix build error: <summary> in <file>:<line>`

### Integration tests (conditional — requires local test DB)

```bash
docker ps | grep -q "5433" && npm run test:api 2>&1 || echo "SKIP: no local test DB on port 5433"
```

Only run if a container is found on port 5433. For each failure: add to TODO (HIGH) — `fix failing test: <describe> > <test name>`

---

## TODO List

Render the full accumulated list here before proceeding to Phase 5.

```
TODO LIST
=========

Priority: CRITICAL (blocks merge)
- [ ] fix: <description> in <file>
  Source: Phase 3 / Check A (gitleaks)

Priority: HIGH (must fix before merge)
- [ ] fix build error: <summary> in <file>:<line>
  Source: Phase 4 / npm run build
- [ ] fix failing test: <test name>
  Source: Phase 4 / npm test

Priority: MEDIUM (CLAUDE.md violation)
- [ ] fix: <description> in <file>
  Source: Phase 3 / Check <letter>

Priority: LOW (quality, coverage)
- [ ] test: add coverage for "<step>"
  Source: Phase 2 / test plan step
- [ ] test: add unit test for <file>
  Source: Phase 2 / unit test mapping
```

**If the list is empty:** state "No violations found — PR is clean." and stop.

---

## Phase 5 — Document Findings

Run these checks before fixing anything. Commit documentation changes with `docs:` prefix before Phase 6.

### Update `docs/agentic-trial-review-template.md`

Add a new gap entry only when:
1. A TODO item reveals a pattern not already documented in the template
2. The pattern is systemic — something Claude would likely reproduce without a rule

For each candidate gap:

```bash
# Check if this pattern is already captured
grep -n "<keyword from violation>" docs/agentic-trial-review-template.md
```

If no match: find the correct section table (Security, Infrastructure, Environment Config, Database, CI/CD, Code Quality, Testing, Developer Experience) and fill the next empty placeholder row using this format:

| # | Gap | What Claude produced | What was missing | Risk | Engineer action | Proposed bridge |
|---|---|---|---|---|---|---|
| X1 | _name_ | _what was in the diff_ | _what was missing_ | Low/Medium/High/Critical | _action taken_ | _rule or tooling to prevent recurrence_ |

The "Engineer action" column should reference the current PR fix. The "Proposed bridge" column should reference the CLAUDE.md rule being added or clarified.

### Update `CLAUDE.md`

Add or clarify a rule when a TODO item reveals:
- A violation with no corresponding rule in CLAUDE.md
- An existing rule that is ambiguous in a way the violation exposes

Do not duplicate rules already enforced by husky hooks — CLAUDE.md is the human-readable statement; the hook is the enforcement.

Section placement:
- Credentials → "Credentials & Secrets"
- Type safety → "Build & Type Safety"
- Code organisation → "Code Organisation"
- Env var coverage → near ".gitignore Rules" or create "Environment Variables" subsection
- Build-time constraints → "Build-Time Constraints"
- Testing → "Testing"

---

## Phase 6 — Execute TODO List

Work through TODO items **one at a time, in priority order:**

1. CRITICAL (credentials)
2. HIGH — build errors first, then test failures
3. MEDIUM — env var fixes → type fixes → code organisation → orphan deletions
4. LOW — test additions last

**Per-item protocol:**
1. Announce: "Working on: `<item>`"
2. Read relevant file(s)
3. Implement the fix
4. Stage only the files for this item: `git add <specific files>` (never `git add -A` or `git add .`)
5. Commit immediately (see convention below)
6. `git status` to confirm staging is clean
7. Move to next item

**Never batch multiple TODO items into one commit.**

For test-writing items: read `git diff main...HEAD -- <source_file>` first. Follow existing test patterns:
- Unit test → `src/test/<basename>.test.ts`, import from `vitest`, mock external deps with `vi.mock()`
- Integration test → `tests/api/<route>.test.ts`, use `NextRequest`, import `cleanup` from `tests/helpers/fixtures`

Run the test before committing to confirm it passes:
```bash
npm test          # for unit tests
npm run test:api  # for integration tests (if DB available)
```

---

## Commit Message Convention

```
<type>[(<scope>)]: <imperative description under 50 chars>

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
```

**Types:** `fix:` for violations and broken builds/tests · `test:` for new test coverage · `docs:` for template and CLAUDE.md updates

**Examples:**
```
fix: replace hardcoded token in scripts/create-admin.ts with env var
fix: replace Record<string, any> with StudyWhereInput in studies page
fix: add UPSTASH_REDIS_REST_URL to .env.example
fix: delete orphaned studies-old-action.ts superseded by studies.ts
fix: remove eslint-disable comment in src/app/admin/studies/page.tsx
fix build error: waiverReason type unresolved in escalations page
fix failing test: POST /api/studies returns 409 on quota conflict
test: add unit test for quota-utils null studyCategory edge case
test: add integration test for POST /api/admin/schools
docs: add gap Q5 to agentic-trial-review-template.md
docs: clarify CLAUDE.md Build & Type Safety rule on Record<string, any>
```
