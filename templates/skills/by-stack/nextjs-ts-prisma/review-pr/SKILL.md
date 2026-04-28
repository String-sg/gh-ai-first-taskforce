---

name: review-pr
stack: Next.js · TypeScript · Prisma · PostgreSQL
description: Full pre-merge review for Next.js + TypeScript + Prisma projects. Rebases onto main, resolves merge conflicts, scans for violations, runs build and tests, documents new gap patterns, then works through fixes — each committed separately. Use when the SWE is ready to merge a PR.

---

## Before you begin

Run these guard checks and stop if any fail.

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

If main is more than **5 commits ahead**, warn before proceeding:

> "Warning: main is N commits ahead of this branch. The rebase in Phase 0 may produce multiple conflicts. Consider reviewing the main changes first (`git log HEAD..origin/main`) before proceeding."

Do not stop — surface it so the user can decide whether to proceed.

---

## Phase 0 — Rebase onto main

```bash
git fetch origin main
git log HEAD..origin/main --oneline
```

If main has no new commits since the branch diverged: state "Branch is up to date with main — skipping rebase." and proceed to Phase 1.

If main has new commits:

```bash
git rebase origin/main
```

**If the rebase exits cleanly:**

```bash
git push --force-with-lease
```

**If the rebase reports conflicts:** for each conflicted file:

1. Show conflicted files: `git diff --name-only --diff-filter=U`
2. Read the conflicted file — understand what both sides intend.
3. Resolve by editing to the correct merged state. If the intent of either side is unclear, stop and ask the user.
4. Stage: `git add <resolved_file>`
5. Continue: `git rebase --continue`
6. Repeat until complete, then `git push --force-with-lease`.

**If a conflict cannot be resolved with confidence:** abort and tell the user what needs manual resolution:

```bash
git rebase --abort
```

Do not proceed to Phase 1 with an aborted rebase.

### After rebase — regenerate Prisma client (unconditional)

```bash
npx prisma generate
```

Always run this after any rebase — even if this branch did not touch `prisma/schema.prisma`. The rebase may have brought in schema changes from main, leaving the local client stale.

Then check for type errors introduced by the rebase:

```bash
npx tsc --noEmit 2>&1
```

If type errors are found: add to TODO (HIGH) — `fix build error: <summary>` — and resolve in Phase 6.

---

## Phase 1 — PR Analysis

```bash
gh pr view --json number,title,body,state,baseRefName
git diff main...HEAD --name-only
git log main..HEAD --oneline
git diff main...HEAD
```

**Extract the test plan** from the PR body: find any section headed "Test plan", "Steps to test", "Testing", or "How to test" (case-insensitive). Extract each checklist item or numbered step.

If no such section exists: add to TODO (LOW) — `docs: add test plan section to PR description`.

**Carry forward:**
- `CHANGED_FILES` — output of `git diff main...HEAD --name-only`
- `TS_TSX_CHANGED` — subset matching `*.ts` / `*.tsx`
- `TEST_PLAN_STEPS` — extracted steps from the PR test plan
- `FULL_DIFF` — output of `git diff main...HEAD`

---

## Phase 2 — Test Coverage Check

**Exclude from all coverage checks:**
`src/app/**/page.tsx`, `src/app/**/layout.tsx`, `src/app/**/loading.tsx`, `src/components/**`, `prisma/**`, `*.config.ts`, `src/test/**`, `tests/**`

### Unit test mapping

For each file in `CHANGED_FILES` under `src/lib/` or `src/app/api/` (not excluded):

```bash
# e.g. src/lib/quota-utils.ts → src/test/quota-utils.test.ts
ls src/test/<basename>.test.ts
```

If the test file does not exist: add to TODO (LOW) — `test: add unit test for <file>`

### Integration test mapping

For each file matching `src/app/api/**/route.ts` in `CHANGED_FILES`:

```bash
# e.g. src/app/api/studies/route.ts → tests/api/studies.test.ts
ls tests/api/ | grep -i "<route-path-segment>"
```

If no integration test matches: add to TODO (LOW) — `test: add integration test for <route>`

### Test plan step coverage

For each step in `TEST_PLAN_STEPS`, search for keywords in existing test files:

```bash
grep -rn "<keyword>" src/test/ tests/api/ --include="*.test.ts"
```

If no match: add to TODO (LOW) — `test: add coverage for "<step>"`

**Before writing any new test:** run `git diff main...HEAD -- <source_file>` to read the actual implementation first.

---

## Phase 3 — Code Standards Scan

### A. Hardcoded credentials — gitleaks

```bash
gitleaks detect --log-opts "main..HEAD"
```

If gitleaks reports any findings: add to TODO (CRITICAL) — `fix: remove hardcoded credential in <file>`.

### B. `any` casts

```bash
git diff main...HEAD -- '*.ts' '*.tsx' | grep "^+" | grep -E "(: any|as any|Record<string, any>)"
```

For each match: add to TODO (MEDIUM) — `fix: replace any cast in <file> with correct type`

### C. ESLint disable comments

```bash
git diff main...HEAD -- '*.ts' '*.tsx' | grep "^+" | grep -E "eslint-disable"
```

For each match: add to TODO (MEDIUM) — `fix: remove eslint-disable comment in <file> and model the correct type`

### D. Shared lookup data declared locally

```bash
git diff main...HEAD -- '*.tsx' '*.ts' | grep "^+" | grep -E "const\s+\w+\s*=\s*\["
```

For each match in a page or component file (not `src/lib/`): check if the constant already exists in `src/lib/`:

```bash
grep -rn "<matched_name>" src/lib/ --include="*.ts"
```

If it is a static list of categories, labels, or options and is not already in `lib/`: add to TODO (MEDIUM) — `fix: move shared constant <name> in <file> to src/lib/ and import it`

### E. Orphaned files

```bash
git log --diff-filter=D --name-only --format="" main..HEAD | sort -u
git diff main...HEAD --name-only --diff-filter=A
```

For each new file added, check if a same-purpose older file still exists alongside it:

```bash
ls $(dirname <new_file>)
```

If an older file with the same purpose was not deleted: add to TODO (MEDIUM) — `fix: delete orphaned file <path> superseded by <new_file>`

### F. Env var coverage

```bash
git diff main...HEAD | grep "^+" | grep -oE "process\.env\.[A-Z_]+" | sort -u
cat .env.example
```

For each `process.env.VAR` in the diff with no entry in `.env.example`: add to TODO (MEDIUM) — `fix: add <VAR> to .env.example with a placeholder value`

### G. Build-time DB calls

```bash
git diff main...HEAD -- '*.ts' '*.tsx' | grep "^+" | grep -E "(generateStaticParams|getStaticProps)"
```

If any match found, check whether `prisma.` or `fetch(` appears in the same function context:

```bash
git diff main...HEAD -- <matched_file> | grep -A 20 "generateStaticParams\|getStaticProps" | grep "prisma\.\|fetch("
```

For each match: add to TODO (MEDIUM) — `fix: remove DB/API call from build-time function in <file>; use ISR or on-demand revalidation`

### H. Dockerfile integrity

```bash
git diff main...HEAD --name-only | grep -q "^Dockerfile$" && grep "COPY prisma ./prisma" Dockerfile
```

If Dockerfile is in the diff but missing `COPY prisma ./prisma`: add to TODO (HIGH) — `fix: add COPY prisma ./prisma to Dockerfile before RUN npx prisma generate`

---

## Phase 4 — Build & Test

### Unit tests

```bash
npm test 2>&1
```

For each failure: add to TODO (HIGH) — `fix failing test: <test name>`

### Build

```bash
npm run build 2>&1
```

Parse for `Type error:`, `error TS`, `Build failed`. For each error: add to TODO (HIGH) — `fix build error: <summary> in <file>:<line>`

### Integration tests (conditional — requires local test DB)

```bash
docker ps | grep -q "[ your integration test DB port ]" && npm run test:api 2>&1 || echo "SKIP: no local test DB"
```

Only run if a container is found on the integration test DB port. For each failure: add to TODO (HIGH) — `fix failing test: <describe> > <test name>`

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

Priority: MEDIUM (code standards violation)
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

### Update `[ path/to/trial-review.md ]`

Add a new gap entry only when:
1. A TODO item reveals a pattern not already documented in the trial review
2. The pattern is systemic — something Claude would likely reproduce without a rule

For each candidate gap, fill the next empty placeholder row:

| # | Gap | What Claude produced | What was missing | Risk | Engineer action | Proposed bridge |
|---|---|---|---|---|---|---|
| X1 | _name_ | _what was in the diff_ | _what was missing_ | Low/Medium/High/Critical | _action taken_ | _rule or tooling to prevent recurrence_ |

### Update `CLAUDE.md`

Add or clarify a rule when a TODO item reveals:
- A violation with no corresponding rule in CLAUDE.md
- An existing rule that is ambiguous in a way the violation exposes

Do not duplicate rules already enforced by husky hooks.

Section placement:
- Credentials → "Credentials & Secrets"
- Type safety → "Build & Type Safety"
- Code organisation → "Code Organisation"
- Env var coverage → "Environment Variables"
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

Run the test before committing:

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

**Types:** `fix:` for violations and broken builds/tests · `test:` for new test coverage · `docs:` for trial review and CLAUDE.md updates

**Examples:**
```
fix: replace hardcoded token in scripts/create-admin.ts with env var
fix: replace Record<string, any> with correct type in studies page
fix: add UPSTASH_REDIS_REST_URL to .env.example
fix: delete orphaned studies-old-action.ts superseded by studies.ts
fix: remove eslint-disable comment in src/app/admin/studies/page.tsx
fix build error: waiverReason type unresolved in escalations page
fix failing test: POST /api/studies returns 409 on quota conflict
test: add unit test for quota-utils null studyCategory edge case
test: add integration test for POST /api/admin/schools
docs: add gap to trial-review.md
docs: clarify CLAUDE.md Build & Type Safety rule on Record<string, any>
```
