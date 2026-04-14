# CLAUDE.md — Grassroots Project Template

> **How to use this file:** Copy this file to the root of your project as `CLAUDE.md` and edit the placeholders marked with `[ ]`. These rules apply to every Claude Code session in this project.
>
> **New project:** Drop this file in before running `npm init`, `npx create-next-app`, or any scaffolding command. Work through the [New Project Init Checklist](#new-project-init-checklist) before writing any application code.
>
> **Existing project (refactor):** Drop this file in at the start of the refactor session. Work through the [Existing Project Audit Checklist](#existing-project-audit-checklist) first to understand what gaps need closing before new work begins.

---

## Stack & Environment

**Production target:** Next.js (App Router) + PostgreSQL on [your cloud host, e.g. AWS RDS / Railway / Render]. No managed auth service in prod — use NextAuth.js with bcrypt.

**Auth (production):** OTPaaS (TechPass OTPaaS) is the only permitted authentication mechanism for applications going to production. All login flows must deliver a one-time password through OTPaaS — no password-based auth, no Supabase Auth, Clerk, Auth0, or any other third-party auth service. See [TechPass OTPaaS API docs](https://docs.developer.tech.gov.sg/docs/techpass-otpaas-api/).

**Auth (pre-production):** For projects where OTPaaS is not yet available, NextAuth.js with JWT session cookies is acceptable as an interim. Structure the auth layer with a provider abstraction (see `src/lib/auth/` in the SuMS reference implementation) so that wiring in OTPaaS is a single-file change once the service is provisioned. The OTPaaS client (`src/lib/otpaas.ts`) should be written and tested against the real service before the switchover, not at switchover time.

**ORM:** Prisma `>=7`. Do not install Prisma 6 or earlier — it breaks Docker Compose when `DATABASE_URL` is absent.

**Local dev database:** Always use the Docker Compose Postgres service (`docker compose up -d`). Never point local dev traffic at a cloud database — the local environment must work fully offline.

**Three environments:**

| Environment | Hosting | Database | Auth | Purpose |
|---|---|---|---|---|
| local | localhost | Docker Compose Postgres (port 5432) | NextAuth + OTPaaS | All day-to-day development |
| test | [e.g. Railway / Render / AWS] | Managed Postgres via `DATABASE_URL` | NextAuth + OTPaaS | User-facing testing with an audience |
| prod | [e.g. AWS ECS + RDS] | Managed Postgres | NextAuth + OTPaaS | Live production |

> **Note:** This template enforces local-first dev with Docker Compose Postgres. Do not point local dev traffic at a cloud database — the local environment must work fully offline except for OTPaaS calls.

Generate `.env.example`, `.env.test`, and `.env.production` with purpose comments at project init so the distinction is explicit. `.env` is the local dev file (gitignored); `.env.example` is the committed reference.

---

## OTPaaS Integration

OTPaaS (TechPass OTPaaS) delivers one-time passwords by email. Sessions are managed separately by NextAuth.js JWT cookies — OTPaaS only handles the OTP send/verify leg of the login flow.

**Required env vars** (all environments):

| Variable | Purpose |
|---|---|
| `OTPAAS_BASE_URL` | Base URL of the OTPaaS service |
| `OTPAAS_NAMESPACE` | Your app's namespace in OTPaaS |
| `OTPAAS_APP_ID` | App identifier used to derive the API key |
| `OTPAAS_SECRET` | HMAC secret for API key generation |

**API key derivation** — the key is not stored directly; it is computed at runtime:

```ts
// src/lib/otpaas.ts — API key generation
import crypto from 'crypto'

function getApiKey(): string {
  const { OTPAAS_NAMESPACE, OTPAAS_APP_ID, OTPAAS_SECRET, OTPAAS_BASE_URL } = process.env
  if (!OTPAAS_NAMESPACE || !OTPAAS_APP_ID || !OTPAAS_SECRET || !OTPAAS_BASE_URL) {
    throw new Error(
      'Missing required OTPaaS env vars: OTPAAS_NAMESPACE, OTPAAS_APP_ID, OTPAAS_SECRET, OTPAAS_BASE_URL'
    )
  }
  const hmac = crypto.createHmac('sha256', OTPAAS_SECRET).update(OTPAAS_APP_ID).digest('hex')
  return Buffer.from(`${OTPAAS_NAMESPACE}:${OTPAAS_APP_ID}:${hmac}`).toString('base64')
}
```

**Send OTP** — `POST /otp`:

```ts
export async function sendOtp(email: string): Promise<{ id: string; cooldown: number } | { error: string }> {
  const res = await fetch(`${process.env.OTPAAS_BASE_URL}/otp`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${getApiKey()}`,
    },
    body: JSON.stringify({ email }),
  })
  if (!res.ok) {
    const text = await res.text()
    return { error: text || `OTPaaS error: ${res.status}` }
  }
  const data = await res.json()
  return { id: data.id, cooldown: data.cooldown }
}
```

**Verify OTP** — `PUT /otp/:id`:

```ts
export async function verifyOtp(id: string, pin: string): Promise<{ ok: true } | { error: string }> {
  const res = await fetch(`${process.env.OTPAAS_BASE_URL}/otp/${id}`, {
    method: 'PUT',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${getApiKey()}`,
    },
    body: JSON.stringify({ pin }),
  })
  if (res.status === 200) return { ok: true }
  return { error: 'Invalid or expired OTP' }
}
```

**OTP–email binding** — bind the OTP ID to the requesting email via an HMAC cookie so a code issued for one address cannot be used to authenticate as another:

```ts
// On sendOtp: store binding cookie
const hmac = createHmac('sha256', process.env.NEXTAUTH_SECRET!)
  .update(`${result.id}:${email}`)
  .digest('hex')
cookieStore.set('otp_binding', `${result.id}:${hmac}`, { httpOnly: true, ... })

// On verifyOtp: validate binding before calling OTPaaS
const expectedHmac = createHmac('sha256', process.env.NEXTAUTH_SECRET!)
  .update(`${id}:${email}`)
  .digest('hex')
if (storedId !== id || storedHmac !== expectedHmac) return { error: 'Invalid OTP — request a new code' }
```

See `src/lib/auth/providers/nextauth.ts` in the SuMS reference implementation for the full session creation flow after OTP verification.

**Error codes:**

| Code | Meaning | Action |
|---|---|---|
| `2005` | Email not allowlisted in OTPaaS | Contact OTPaaS administrator to register the email |

**Admin user bootstrap** — create the user row in the database first (the `create-admin` script), then ensure the same email is allowlisted in OTPaaS before attempting login.

---

## New Project Init Checklist

Before writing any application code, confirm all of the following are in place:

- [ ] `docker-compose.yml` with a Postgres service on port 5432
- [ ] `.env` created locally from `.env.example` (gitignored)
- [ ] `.env.example` committed with placeholder values for every required var, including all four `OTPAAS_*` vars
- [ ] `.gitignore` using only explicit patterns — no `env*` wildcard (see `.gitignore` Rules)
- [ ] `prisma/schema.prisma` initialised with `provider = "postgresql"`
- [ ] `package.json` includes `"prepare": "husky"` and husky is installed (`npm install --save-dev husky`)
- [ ] `.husky/pre-commit` running gitleaks (see Credentials & Secrets below)
- [ ] `.husky/pre-push` running `npm audit --audit-level=high` and `tsc --noEmit`
- [ ] `.gitleaks.toml` committed with allowlist for `.env.example` and `docs/` paths
- [ ] `.claude/commands/skills.md` copied from the reference project and committed
- [ ] Admin email(s) allowlisted in OTPaaS before testing login

---

## Existing Project Audit Checklist

Run this audit at the start of a refactor session before making any changes. Each gap must be resolved — either fixed immediately or tracked as a named task — before new feature work begins.

**Environment & Secrets**
- [ ] Is `.env.example` committed and up to date? (`git ls-files .env.example`)
- [ ] Does `.gitignore` use only explicit patterns — no `env*` wildcard? (`grep "env\*" .gitignore`)
- [ ] Are any real secrets hardcoded in source files? (`git log --all -S "password" --oneline` for history; `gitleaks detect --verbose` for current state)
- [ ] Does every `process.env.X` reference in the codebase have a corresponding `.env.example` entry?

**Stack conformance**
- [ ] Is Prisma `>=7`? (`npm list prisma`)
- [ ] Is OTPaaS used for OTP delivery and NextAuth for session management? Check `src/lib/otpaas.ts` and `src/lib/auth/`. No Supabase Auth, Clerk, Auth0, or password-based login.
- [ ] Is the dev database Docker Compose Postgres — not a cloud DB? Check `.env` and `docker-compose.yml`.
- [ ] Does the `Dockerfile` include `COPY prisma ./prisma` before `RUN npx prisma generate`?

**Automated enforcement**
- [ ] Is husky installed and `"prepare": "husky"` in `package.json`?
- [ ] Does `.husky/pre-commit` run `gitleaks protect --staged --verbose`?
- [ ] Does `.husky/pre-commit` block `any` casts and `eslint-disable` in staged additions?
- [ ] Does `.husky/pre-push` run `npm audit --audit-level=high` and `tsc --noEmit`?
- [ ] Is `.gitleaks.toml` present with an allowlist for example/docs files?

**Code quality**
- [ ] Does `tsc --noEmit` pass cleanly right now? Fix all errors before proceeding.
- [ ] Does `npm audit --audit-level=high` pass? Document any findings that cannot be fixed.
- [ ] Are shared lookup data (enums, static lists) in `lib/` rather than redeclared per page?
- [ ] Are there any orphaned or deprecated files that should be deleted?

**Testing**
- [ ] Does `npm test` (unit tests) pass without a database?
- [ ] Does `.husky/pre-push` run `npm test`?
- [ ] Are known bugs covered by a test case in `src/test/` or `tests/api/`?

**Seed data**
- [ ] Does `prisma/seed.ts` include all fields for every seeded model (no missing required or meaningful fields)?
- [ ] Do seed records exercise all meaningful enum values?

**CI/CD**
- [ ] Does the GitHub Actions pipeline include a secret scanning step (`gitleaks/gitleaks-action@v2`)?
- [ ] Does the pipeline prevent prod deploys from running locally?

> For each gap found: if it can be fixed in under 5 minutes, fix it now. If it requires more work, create a named task before continuing. Do not begin feature work with unresolved High or Critical gaps.

---

## Credentials & Secrets

- **Never hardcode credentials.** All secret values (passwords, API keys, connection strings) must be read from environment variables.
- Scripts must validate that required env vars are set and exit early with a clear error if they are not.
- Never print passwords or secrets to stdout.
- Never commit `.env`, `.env.local`, `.env.*.local`. Always commit `.env.example` with placeholder values.
- After any credential-touching change, run `git diff --staged` and confirm no secret values are present.

**Secret scanning is enforced automatically via husky + gitleaks:**

`.husky/pre-commit` must contain:
```sh
gitleaks protect --staged --verbose
```

Install gitleaks: `brew install gitleaks`. See https://github.com/gitleaks/gitleaks for other platforms.

`.gitleaks.toml` at repo root:
```toml
[extend]
useDefault = true

[[allowlists]]
description = "Placeholder values in example env files and documentation"
paths = [
  '''\.env\.example''',
  '''example\.env''',
  '''README\.md''',
  '''docs/.*\.md''',
]
```

---

## `.gitignore` Rules

The `.gitignore` must only exclude env files using explicit patterns:

```
.env
.env.local
.env.*.local
```

**Never use `env*` or similar wildcards** — they silently exclude `.env.example` from the repo, causing prod misconfiguration. If `.env.example` is not tracked by git, add it immediately with `git add .env.example`.

---

## Dependencies

After any `npm install`, `npm uninstall`, or `package.json` change:

1. Run `npm audit`.
2. Fix all high and critical findings before closing the task.
3. If a finding cannot be fixed, document it explicitly with the reason.

`npm audit --audit-level=high` is enforced automatically on every `git push` via `.husky/pre-push`. Do not leave known high/critical vulnerabilities in the dependency tree.

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

`tsc --noEmit` is enforced automatically on every `git push` via `.husky/pre-push`.

**No `any` casts and no ESLint disable comments** as resolutions for type errors. Model the correct type or ask for clarification on the intended shape. Use Prisma `WhereInput` types for query filter variables instead of `Record<string, any>`.

`any` casts and `eslint-disable` comments in staged changes are blocked automatically by `.husky/pre-commit`.

---

## Code Organisation

- **Shared lookup data** (categories, enums, static lists) must be declared once in `lib/` and imported — never redeclared as local variables per page.
- **When replacing or superseding a file**, delete the old file in the same commit or PR. Do not leave orphaned or deprecated files in the codebase.

---

## Seed Data

`prisma/seed.ts` is the single source of truth for local and test reference data. When any of the following change, update the seed in the same PR:

- **Schema changes** that add or modify fields on seeded models — add the new fields to every relevant `create` call in the seed. Do not leave seed records missing required or meaningful fields.
- **Enum additions** — add representative seed rows that exercise the new enum values.
- **Model additions** — add seed rows for the new model so local dev has working reference data from day one.

Re-seed locally after schema changes with:

```bash
docker compose -f docker-compose.local.yml run --rm seed
```

---

## Docker & Prisma

`docker-compose.yml` must define a Postgres service. The app service must depend on it and run `prisma migrate deploy` at startup, not at build time.

Dockerfiles for Prisma apps must include, in order:

```dockerfile
COPY prisma ./prisma
RUN npx prisma generate
```

The `prisma/` directory must be present inside the image so `prisma migrate deploy` can run at container startup. Add `prisma migrate deploy` as an explicit step in the deployment runbook.

---

## Build-Time Constraints

**Build steps must not establish runtime service connections.** Do not add DB queries, API calls, or any network calls to `next build` or any build-time script. Build environments are typically DB-isolated. Use ISR or on-demand revalidation instead of build-time data fetching.

Build-time DB/API calls in `generateStaticParams` or `getStaticProps` are blocked automatically by `.husky/pre-commit`.

---

## Infrastructure Operations

- **Never apply production infrastructure changes from a local machine.** All prod infra changes must go through the CI/CD pipeline. If blocked, flag the blocker and wait for human review.
- **Never modify KMS configurations autonomously.** If a KMS issue blocks an infra operation, stop and ask for human review. KMS key changes require teardown and re-provisioning if wrong.
- **For any TLS/certificate configuration decision** (global vs regional, cert provider, expiry), present the options and ask for explicit confirmation before proceeding.
- Local AWS credentials used during agentic infra sessions must be scoped to read-only for prod.

---

## Pre-Merge Audit

This project uses a `/skills` Claude Code command for pre-merge review. Copy `.claude/commands/skills.md` from the reference project into `.claude/commands/` in this repo to activate it. Run `/skills` before raising any PR.

The `/skills` audit covers the judgment-required checks that hooks cannot automate: env var coverage, code organisation, infrastructure review, and deployment runbook verification.

By Natasha
