---

name: web-app-with-db
stack: Next.js · TypeScript · Prisma · PostgreSQL
description: Skills for a web application with user authentication and a relational database. Opinionated stack choice — see below. Adds function-level architectural checks on top of the stack skill.

---

> This skill set is opinionated: it assumes **Next.js · TypeScript · Prisma · PostgreSQL**.
>
> If your project uses a different stack, ask your agent to read `../../SKILLS.md` and detect your stack automatically, or go directly to `../../by-stack/` to find an exact match.

---

## Available skills

| Skill | What it does | Load this file |
|---|---|---|
| pre-merge-audit | Quick pass/fail checklist before opening a PR | `../../by-stack/nextjs-ts-prisma/pre-merge-audit/SKILL.md` |
| review-pr | Full automated PR review: rebase, scan, build, fix | `../../by-stack/nextjs-ts-prisma/review-pr/SKILL.md` |

Load and execute the matching skill file above, then apply the additional checks below.

---

## Additional checks for database-backed web apps

Run these after the stack skill completes, regardless of which skill was invoked.

### 1. Auth on DB-write routes

For each route in the diff that performs a database write (create, update, delete via Prisma):
- Confirm the route checks authentication before executing the write.
- A middleware check at the layout or route-group level counts — trace the call path if needed.

**Block on:** any DB-write route reachable without an authenticated session.

### 2. Migration rollback plan

If `prisma/migrations/` contains any new migration file in this diff:
- Confirm the PR description documents a rollback path — what command or manual step reverses this migration if it needs to be undone in production.

**Block on:** new migration file with no rollback documented in the PR description.

### 3. Connection string safety

Confirm `DATABASE_URL` and any replica connection strings are sourced from environment variables in all config files, seed scripts, and test helpers — not hardcoded anywhere in the committed codebase.

```bash
grep -rn "postgresql://" . --include="*.ts" --include="*.tsx" --include="*.js" --include="*.env*" \
  | grep -v ".env.example" | grep -v ".git"
```

**Block on:** hardcoded connection string in any committed file other than `.env.example`.
