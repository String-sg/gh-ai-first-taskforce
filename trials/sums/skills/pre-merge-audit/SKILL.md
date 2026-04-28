---

name: pre-merge-audit
description: Run a pre-merge audit of the current changes against the SuMS project rules in CLAUDE.md. Checks marked **[automated]** are enforced by husky hooks — confirm the hooks are active, then focus your review on the manual checks below. Use after introducing new features or bug fixes, and before making pull request.

---

## Automated checks (husky)

| Check | Hook | Trigger |
|---|---|---|
| Secret scanning (gitleaks) | `pre-commit` | every commit |
| `any` casts + eslint-disable | `pre-commit` | every commit |
| Dockerfile COPY prisma | `pre-commit` | when Dockerfile staged |
| Build-time DB/API calls | `pre-commit` | when `.ts`/`.tsx` staged |
| Raw SQL unsafe patterns | `pre-commit` | when `.ts`/`.tsx` staged |
| npm audit (high/critical) | `pre-push` | every push |
| tsc --noEmit | `pre-push` | every push |

Verify hooks are installed:
```
cat .husky/pre-commit
cat .husky/pre-push
```

---

## Manual checks (require judgment)

### 1. Credentials & Secrets

- Confirm `.env.example` is tracked by git: `git ls-files .env.example`
- Confirm `.gitignore` does not use `env*` wildcard: `grep "env\*" .gitignore`
- Confirm no `.env`, `.env.local`, or `.env.*.local` files are staged: `git diff --name-only --cached | grep "^\.env"`

**Block on:** `.env.example` not tracked, `env*` wildcard in `.gitignore`, any env file staged.

---

### 2. Code Organisation

- Check for shared lookup data (arrays of categories, enums, static lists) declared as local variables in page files rather than imported from `lib/`:
  ```
  grep -rn "const.*=\s*\[" src/app --include="*.tsx" --include="*.ts"
  ```
  Flag any that appear in more than one file.
- Check for files that appear deprecated or superseded (old action files alongside new ones with the same purpose). List them and ask if they should be deleted.

**Block on:** duplicate shared constants across page files.

---

### 3. Docker & Prisma

If `Dockerfile` or `prisma/` was changed (hook catches the COPY rule — verify the rest):
- Confirm `prisma migrate deploy` is present in the deployment runbook or startup script.

---

### 4. Raw SQL Queries

If any file in the diff contains `$queryRaw`, `$executeRaw`, `$queryRawUnsafe`, `$executeRawUnsafe`, or `Prisma.raw`:

```
grep -rn "\$queryRaw\|\$executeRaw\|Prisma\.raw" src --include="*.ts" --include="*.tsx"
```

For each match, verify:
- **No `$queryRawUnsafe` / `$executeRawUnsafe`** is used with any value traceable to user input (request body, query params, headers). These bypass prepared-statement parameterization entirely.
- **No `Prisma.raw()`** wraps a dynamic or user-supplied value — it must only wrap hard-coded string literals (e.g. column/table names controlled entirely in code).
- All user-supplied values reach the query via `$queryRaw` tagged template interpolation (`${value}`), `Prisma.sql`, or `Prisma.join`. Confirm the data-flow from request parsing (e.g. Zod schema) through to the query parameters.

> The husky `pre-commit` hook blocks the obvious patterns (`$queryRawUnsafe`, `Prisma.raw(`) automatically. This check covers the judgment call: is the parameterized usage actually correct end-to-end?

**Block on:** `Prisma.raw()` or `$queryRawUnsafe` / `$executeRawUnsafe` with any value traceable to user input.

---

### 5. Infrastructure

If any infrastructure code (`terraform/`, `*.tf`, Dockerfile, CI/CD pipeline configs) was changed:
- Confirm no KMS configuration was modified without an explicit comment explaining the human review that approved it.
- Confirm no `aws apply` or equivalent is wired to run locally from a developer machine.
- Confirm TLS/certificate type (regional vs global) is documented in the PR description.

**Block on:** autonomous KMS modification, local prod apply wired in pipeline.

---

### 6. Environment Configuration

- Confirm `.env.example` is up to date — every `process.env.X` referenced in the codebase should have a placeholder entry:
  ```
  grep -rn "process\.env\." src --include="*.ts" --include="*.tsx" | grep -oE "process\.env\.[A-Z_]+" | sort -u
  ```
  Compare against keys in `.env.example`.
- Confirm no new env vars were introduced without a corresponding `.env.example` entry.

**Block on:** env var used in code with no `.env.example` entry.

---

## Summary

After reviewing, output a table:

| Check | Status | Findings |
|---|---|---|
| Husky hooks active | PASS / FAIL | |
| Credentials & Secrets | PASS / FAIL | |
| Code Organisation | PASS / WARN | |
| Docker & Prisma | PASS / FAIL / N/A | |
| Raw SQL Queries | PASS / FAIL / N/A | |
| Infrastructure | PASS / FAIL / N/A | |
| Environment Config | PASS / FAIL | |

**FAIL on any Critical or High item = not merge-ready.** WARN items should be resolved before go-live but do not block merge.
