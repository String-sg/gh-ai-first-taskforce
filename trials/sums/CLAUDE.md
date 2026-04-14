# CLAUDE.md — SuMS Project Rules

Rules derived from the Feb–Mar 2026 agentic trial review. Follow these in every session.

---

## Stack & Environment

**Production target:** Next.js + plain PostgreSQL on AWS RDS (ECS/EC2 behind ALB). No Supabase, no managed auth service in prod.

**Auth:** NextAuth.js with bcrypt and the Prisma adapter for test and prod. The Vercel/Supabase dev environment uses Supabase Auth. Do not introduce Supabase Auth helpers into the test or prod code paths.

**ORM:** Prisma `>=7`. Do not install Prisma 6 or earlier — it breaks Docker Compose when `DATABASE_URL` is absent.

**Local dev database:** Use the Docker Compose Postgres service (`docker compose up -d`). Do not point local dev traffic at a cloud database.

**Four environments:**

| Environment | Hosting | Database | Auth | Purpose |
|---|---|---|---|---|
| local | localhost | Docker Compose Postgres (port 5432) | NextAuth | Engineer day-to-day development |
| dev | Vercel | Supabase cloud Postgres | Supabase Auth | Grassroots practitioner dev & early testing |
| test | AWS (ECS/EC2 + ALB) | AWS RDS PostgreSQL | NextAuth | Pre-production stakeholder testing |
| prod | AWS (ECS/EC2 + ALB) | AWS RDS PostgreSQL | NextAuth | Live production |

Generate `.env.local`, `.env.development`, `.env.test`, and `.env.production` with purpose comments at project init so the distinction is explicit. The `AUTH_PROVIDER` env var switches between `nextauth` and `supabase` — ensure it is set correctly for each environment.

---

## Credentials & Secrets

- **Never hardcode credentials.** All secret values (passwords, API keys, connection strings, service role keys) must be read from environment variables.
- Scripts must validate that required env vars are set and exit early with a clear error if they are not.
- Never print passwords or secrets to stdout.
- Never commit `.env`, `.env.local`, `.env.*.local`. Always commit `.env.example` with placeholder values.
- After any credential-touching change, confirm that `git diff --staged` contains no secret values.

---

## `.gitignore` Rules

The `.gitignore` must only exclude:

```
.env
.env.local
.env.*.local
```

**Never use `env*` or similar wildcards** — they silently exclude `.env.example` from the repo, causing prod misconfiguration. If `.env.example` is not tracked by git, add it immediately.

---

## Dependencies

After any `npm install`, `npm uninstall`, or `package.json` change:

1. Run `npm audit`.
2. Fix all high and critical findings before closing the task.
3. If a finding cannot be fixed, document it explicitly with the reason.

Do not leave known high/critical vulnerabilities in the dependency tree.

---

## Testing

When a bug is found through manual testing or a new edge case is identified:

1. Write a test case that reproduces or covers the scenario **before or alongside** the fix.
2. Unit tests for schema validation, pure logic, and utility functions belong in `src/test/` and must pass without a database (`npm test`).
3. API integration tests that require a real database belong in `tests/api/` and are run with `npm run test:api`.
4. Do not close a bug fix task until the covering test is committed and passes.

`npm test` (unit tests only) is enforced automatically on every `git push` via `.husky/pre-push`.

---

## Build & Type Safety

After any edit that touches types, props, function signatures, or shared interfaces:

1. Run `tsc --noEmit` (or `next build`) to confirm the project compiles cleanly.
2. Do not consider the task complete until the build passes with no type errors.

**No `any` casts and no ESLint disable comments** as resolutions for type errors. Model the correct type or ask for clarification on the intended shape. In particular, Prisma `WhereInput` types (e.g. `StudyWhereInput`) should be used for query filter variables instead of `Record<string, any>`.

---

## Code Organisation

- **Shared lookup data** (categories, enums, static lists) must be declared once in `lib/` and imported — never redeclared as local variables per page.
- **When replacing or superseding a file**, delete the old file in the same commit or PR. Do not leave orphaned or deprecated files in the codebase.

---

## Seed Data

`prisma/seed.ts` is the single source of truth for local and test reference data. When any of the following change, update the seed in the same PR:

- **Schema changes** that add or modify fields on seeded models — add the new fields to every relevant `prisma.study.create` (or equivalent) call in the seed. Do not leave seed records missing required or meaningful fields.
- **Enum additions** — add representative seed rows that exercise the new enum values so developers can see realistic data in every state.
- **Model additions** — add seed rows for the new model so local dev has working reference data from day one.

The seed wipes and re-inserts on every run (`deleteMany` → `create`). Re-seed locally after schema changes with:

```bash
docker compose -f docker-compose.local.yml run --rm seed
```

---

## Docker & Prisma

Dockerfiles for Prisma apps must:

```dockerfile
COPY prisma ./prisma
RUN npx prisma generate
```

The `prisma/` directory must be present inside the image so `prisma migrate deploy` can run at container startup. Add `prisma migrate deploy` as an explicit step in the deployment runbook.

---

## Build-Time Constraints

**Build steps must not establish runtime service connections.** Do not add DB queries, API calls, or any network calls to `next build` or any build-time script. Pre-caching strategies that require DB access at build time are incompatible with the GCC build environment (DB-isolated). Use ISR or on-demand revalidation instead.

---

## Infrastructure Operations

- **Never apply production infrastructure changes from a local machine.** All prod infra changes must go through the CI/CD pipeline. If blocked, flag the blocker and wait for human review — do not find a workaround.
- **Never modify KMS configurations autonomously.** If a KMS issue blocks an infra operation, stop and ask for human review. KMS key changes require teardown and re-provisioning if wrong.
- **For any TLS/certificate configuration decision** (global vs regional, cert provider, expiry), present the options and ask for explicit confirmation before recommending a specific type.
- Local AWS credentials used during agentic infra sessions must be scoped to read-only for prod. Audit local credential files (`~/.aws/credentials`, kubeconfig contexts) before any agentic infra session.
