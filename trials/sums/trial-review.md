# Agentic Development Trial Review

**App:** Sums
**Trial period:** Feb - Mar 2026
**Review date:** 25 Mar 2026

---

## Trial Setup

| Role | Person | Involvement |
|---|---|---|
| Grassroots developer (PM) | Guang Shin (PM) | Full-time for build week |
| Software engineer | Natasha (SWE) | Part-time, merge-readiness gaps |
| DevOps engineer | Chadin (DevOps) | Part-time, infrastructure gaps |

### Timeline

| Phase | Duration | Description |
|---|---|---|
| Requirements & PRD | 1–2 weeks | PM gathers requirements, forms PRD |
| Build | 1 week | PM builds with Claude Code |
| Prod hardening | 2 weeks | Engineers fill gaps, prepare for merge |

### What was built

> Brief description of the app — its purpose, core features, and tech stack.

**Stack:** Next.js 16, React 19, TypeScript, Tailwind CSS v4, Prisma ORM, Vitest
**Auth:** NextAuth.js (credentials provider, bcrypt, Prisma adapter)
**Database:** PostgreSQL — Docker locally, AWS RDS in production
**Deployment target:** AWS VPC (ECS / EC2) behind a load balancer

---

## Gaps Log

> For each gap, describe what Claude produced, what was missing, what the engineer did, and what could close the gap in future trials.

### Risk classification

Risk ratings reflect the potential impact if the gap had reached production undetected — they are not a measure of likelihood.

| Rating | Meaning |
|---|---|
| **Critical** | Could result in full data breach, account takeover, or complete service compromise. Requires immediate remediation regardless of likelihood. |
| **High** | Significant security exposure, data loss, or deployment blocker. Would cause serious harm or extended outage if exploited or triggered in prod. |
| **Medium** | Meaningful impact but limited in scope or requiring specific conditions to trigger. Should be resolved before or shortly after go-live. |
| **Low** | Minor quality, maintainability, or operational issue. No immediate security or availability risk. Address in normal course of work. |
| **Low–Medium** | Sits between Low and Medium — no direct security risk but creates conditions (operational dependency, reduced visibility, technical debt) that could compound into a larger issue if left unaddressed. |

---

### Security

| # | Gap | What Claude produced | What was missing | Risk | Engineer action | Proposed bridge |
|---|---|---|---|---|---|---|
| S1 | Hardcoded credentials in `scripts/create-admin.ts` | Script with live Supabase project URL (`ggvsbeblcyfgeqfstlsc.supabase.co`), service role secret key, hardcoded admin email (`admin@sums.gov.sg`) and password (`Admin1234!`) — password also printed to stdout. Committed in `916c00a` on Feb 27 as part of a login page redesign commit. | All secret values should have been read from env vars. No env var guards. No `.env.local.example` entries. Password exposed in console output. | **Critical.** Supabase service role key grants full admin access to the project — any repo reader could read/write all data and manage all users. Hardcoded admin password creates a known credential that could be used against prod if the same password was reused. Credentials remain permanently in git history even after the code fix; key rotation in Supabase is a required separate action. 19-day exposure window before detection. | Natasha (SWE) caught this via manual audit on Mar 18 (19 days later). Fixed in `40ad36`: replaced all hardcoded values with env vars, added early-exit validation, removed password from stdout, added `ADMIN_EMAIL`/`ADMIN_PASSWORD` to `.env.local.example` with a warning not to use production credentials. **Note: credentials remain in git history and must be rotated.** | (1) Add a pre-commit secret scanning hook (e.g. `gitleaks` or `detect-secrets`) to block credential commits before they reach the repo. (2) Add a CLAUDE.md rule explicitly prohibiting hardcoded credentials and requiring env vars for all secret values. (3) Gate secret scanning in CI so any push containing secret patterns fails the pipeline. |
| S2 | 12 npm package vulnerabilities (6 high, 6 moderate) left unfixed | Claude did not run `npm audit` or `npm audit fix` during the build. 12 vulnerabilities — 6 high, 6 moderate — remained in the dependency tree. A grassroots practitioner would not know to prompt an audit; Claude did not surface it unprompted. | An `npm audit` pass as a standard step at the end of any dependency installation, with vulnerabilities fixed or explicitly acknowledged before the build is considered complete. | **High.** Six high-severity vulnerabilities in production dependencies expose the app to known exploits. A non-dev PM has no visibility into this risk and no way to detect it without tooling. The vulnerabilities would have shipped to prod undetected without engineer intervention. | Natasha (SWE) identified and fixed the vulnerabilities manually. Fix across three commits (`7a129b8`, `46fefad`, `76e4801`), in a PR pending merge. | (1) Add a CLAUDE.md rule: run `npm audit` after any dependency change and fix or document all high/critical findings before closing the task. (2) Gate `npm audit --audit-level=high` in CI so the pipeline fails on high or critical vulnerabilities — this catches regressions without relying on the PM to prompt for it. |

**Notes:**

> Credentials committed in `916c00a` (Feb 27 2026), caught in `40ad36` (Mar 18 2026) — 19 days exposure window. The Supabase service role key grants full admin access to the project (read/write all data, manage all users). Even after the code fix, the plaintext secret remains permanently in git history. Key rotation in Supabase is required as a separate action and was not part of the fix commit.

---

### Infrastructure & Deployment

| # | Gap | What Claude produced | What was missing | Risk | Engineer action | Proposed bridge |
|---|---|---|---|---|---|---|
| I1 | Tight Supabase coupling in dev required full auth and DB refactoring before prod deployment | App initialised with Supabase as both DB and auth provider using cloud-hosted Supabase as the dev environment (`979d924`, Feb 25). Supabase migrations created 9 min later (`ac5f1bc`). Guang Shin (PM) then prompted Claude to add Prisma ORM — Claude replaced the migrations but installed `prisma@6.19.2` (`696680`) despite Prisma 7 being available since Nov 2025. Supabase Auth helpers added 4 min later (`3b3a947`), cementing auth coupling. Dev traffic and data pointed at cloud Supabase throughout the entire build period. | Awareness that prod target was plain Postgres on AWS RDS with no Supabase. An auth abstraction layer. Latest stable Prisma version. A local dev database instead of a cloud service. | **High.** Dev schema, queries, and seeded data crossed the public internet to Supabase cloud throughout build week — no VPC boundary. Supabase-specific `auth.role()` in RLS policies was incompatible with plain Postgres, blocking `prisma migrate deploy` on any non-Supabase instance. Prisma 6 caused Docker Compose failures without a supplied `DATABASE_URL`, blocking the deployment pipeline entirely until upgraded. Auth coupling meant login, middleware, and session logic all had to be rewritten before prod was viable. | Natasha (SWE), Ivan (Tech Lead), and Chadin (DevOps) discussed and Natasha (SWE) wrote a DB infra ADR (`b77814a`, Mar 18) evaluating 4 migration options. Natasha (SWE) implemented full decoupling in `54bfc1a` (Mar 18): added NextAuth + bcrypt, Prisma `User` model, auth abstraction layer (`src/lib/auth/`), removed Supabase client files, updated docker-compose — 526 additions, 100 deletions. Upgraded Prisma 6 → 7 in `1dc6582` (Mar 20), regenerating the entire client (~12,816 lines). Total: ~3 engineer-days across 3 people. | (1) Add a CLAUDE.md rule stating the prod target stack (plain Postgres, no managed auth service) so Claude anchors all dependency decisions to prod constraints from project init. (2) Include a `docker-compose.yml` with a local Postgres service in the project scaffold so Claude defaults to local DB, not a cloud service. (3) Specify required library versions or minimum version constraints in CLAUDE.md (e.g. `prisma: >=7`) to prevent Claude from defaulting to older stable versions when newer ones are available. |
| I2 | No defined test environment for grassroots practitioners; dev/test/prod distinction not prompted to Claude | A single cloud-hosted Supabase environment used for both development and ad-hoc user testing throughout the build period. No separation between dev, test, and prod environment configs. | A clear three-environment model (dev/test/prod) with distinct purposes, configs, and compliance postures. An org-approved test environment for user-facing testing. Explicit CLAUDE.md guidance so Claude generates environment-specific configuration from project init. | **Medium.** Without a defined test environment, the PM naturally used the dev environment for user testing — exposing real user interactions to an uncontrolled cloud setup with no compliance guardrails. Grassroots practitioners are unlikely to spontaneously prompt Claude to scaffold separate environments; Claude will default to a single environment unless instructed otherwise. The conflation of dev and test also means security issues found in "testing" are harder to triage — is it a dev config issue or a real bug? | Natasha (SWE) recommended running dev locally for security. Guang Shin (PM) preferred to keep the Vercel/Supabase environment as a test env with real users, citing the need to test with an audience. Natasha (SWE) evaluated Airbase (`console.v2.airbase.sg`) as an org-compliant test environment option. Chadin (DevOps) assessed Airbase and confirmed it has no built-in managed database. He recommended pairing an Airbase-hosted app with an external Supabase database instance, connected via a `DATABASE_URL` environment variable — Airbase explicitly supports outbound PostgreSQL connections on port 5432. **Note: Airbase has no native DB but is designed to connect to external databases. Airbase also does not provide a container registry (ECR); it integrates with SGTS GitLab Container Registry or Docker Hub.** No formal test environment was established during this trial. | (1) Define a three-environment model (dev = local Docker, test = org-approved compliant cloud e.g. Airbase + Supabase DB, prod = AWS VPC + RDS) and document it in CLAUDE.md before the build starts, so Claude scaffolds environment-specific configs from init. (2) Provision an org-approved test environment (Airbase + Supabase DB) for grassroots practitioners as standard — this gives them a safe, compliant space for user testing without conflating it with dev or prod. (3) Add a CLAUDE.md prompt scaffold that asks Claude to generate `.env.development`, `.env.test`, and `.env.production` with purpose comments at project init, making the distinction explicit even if the PM doesn't think to ask. (4) Treat dev/test/prod environment setup as a pre-build checklist item signed off by the DevOps engineer before the PM starts the build week. |
| I3 | `npm build` required live DB connection due to Claude-added pre-caching, breaking GCC build pipeline | Claude optimised the Next.js app by adding DB pre-queries at build time to pre-cache pages. Works on Vercel (which has DB access during builds), but GCC build jobs have no DB access — so the build pipeline failed entirely until the pre-cache was removed. | Awareness that the GCC build environment is DB-isolated. Pre-caching strategy must be decoupled from build time in environments where DB is not reachable during CI. | **Medium.** Build pipeline completely blocked until the optimization was reverted. Risk of similar regressions if Claude re-adds build-time DB calls in future prompt sessions without being reminded of the constraint. | Chadin (DevOps) identified the root cause. The pre-cache was removed to restore DB-free builds. | (1) Add a CLAUDE.md rule: build steps must not establish runtime service connections (DB, external APIs). (2) Note the GCC build environment constraints explicitly so Claude doesn't re-introduce build-time DB calls during optimization prompts. |
| I4 | Prisma schema absent from Docker image, blocking `prisma migrate deploy` post-deployment | Docker image built without the Prisma schema files needed to run `prisma migrate deploy` at container startup or deployment time. The migration step failed with schema-not-found errors after the container was live. | Prisma schema files (`prisma/`) must be present inside the Docker image for migrations to run. A post-deploy migration step documented and wired into the deployment pipeline. | **Medium.** DB migrations could not run without the schema, leaving the production DB in an un-migrated state until manually resolved. Non-obvious to a PM who does not know how Docker image layers relate to Prisma's runtime expectations. | Chadin (DevOps) identified the gap and updated the Dockerfile to include the `prisma/` directory. Significant back-and-forth required to resolve. | (1) Scaffold Dockerfile to always `COPY prisma ./prisma` before `RUN prisma generate`. (2) Add `prisma migrate deploy` as an explicit, documented step in the deployment runbook. (3) Add a CLAUDE.md rule: Dockerfiles for Prisma apps must include the schema directory. |
| I5 | KMS misconfiguration during RDS provisioning required DB teardown and rebuild | When the agent-written infra code encountered a KMS issue creating the RDS instance, it resolved the blocker by updating the KMS config. The DB was spun up successfully, but with the wrong KMS keys. KMS key mismatches on RDS cannot be corrected in-place — the only fix is to destroy and re-create the DB instance. | Validation of KMS key configuration before applying. Human review gate on any changes to KMS settings. Infra code should fail explicitly rather than auto-resolving KMS blockers by modifying key config. | **High.** Destroying and re-creating a DB instance costs time and risks data loss if the instance had live data. KMS key changes are high-blast-radius and irreversible without full teardown. | Chadin (DevOps) identified the KMS mismatch. DB was destroyed and re-provisioned with the correct keys. | (1) Add an explicit human approval gate before applying any DB provisioning changes. (2) CLAUDE.md rule: do not modify KMS configurations autonomously — flag for human review. (3) Add a pre-apply validation step that checks KMS key ARN matches the expected value before proceeding. |
| I6 | Agent repeatedly attempted to apply production infrastructure changes locally despite explicit instructions | After being told not to apply prod infra changes from a local machine (org workflow requires changes to go through the pipeline), the agent still attempted local applies on multiple occasions. Two guardrails held: Chadin (DevOps) was actively monitoring and stopped the applies; the role configured for the agent had no permissions to make infra changes. However, the concern remains that nothing prevented the agent from discovering and using an admin role that was present on the machine. | Reliable compliance with infra workflow constraints. Architectural enforcement (not just prompting) preventing local prod applies. Scoped credentials that cannot be escalated. | **High (potential).** The two guardrails held in this instance, but both required active human oversight. If the monitoring lapse or if the agent found a higher-privileged local role, a destructive prod apply could have gone through undetected. Not ready for autonomous, unattended infra operations. | Chadin (DevOps) was monitoring and stopped the applies in real time. Ensured the configured role had no prod infra permissions as a second guardrail. | (1) Enforce prod infra changes exclusively through CI/CD pipeline — no local applies permitted by policy and by credential scoping. (2) Ensure all local credentials (AWS profiles, kubeconfig contexts) used by the agent are read-only for prod. (3) Add a CLAUDE.md rule explicitly prohibiting local applies to prod and stating the required pipeline workflow. (4) Audit local credential files before agentic infra sessions to confirm no admin roles are accessible. |
| I8 | SSL error in prod resolved with global certificates without prompting on regional vs global preference | When an SSL error surfaced in prod, the agent's recommended fix (`af067f38b`) used global certificates. The correct approach — and the org preference — was regional certificates, but the agent did not ask before recommending a solution. | The agent should have surfaced the global vs regional certificate trade-off and asked for a preference before applying a fix. Regional vs global cert choice has compliance and routing implications that the agent cannot infer from context alone. | **Low.** Using global certs in a regional deployment can have compliance and latency implications. The wrong cert type was recommended and would have been applied had it not been caught. However, Chadin (DevOps) evaluated that this is just an optimization issue, not a huge security/compliance implication. | Caught during PR review. The fix was revised from global to regional certificates before merge. | (1) CLAUDE.md rule: for any cert, key, or TLS configuration decision, present the options (global vs regional, cert provider, expiry) and ask for explicit confirmation before recommending a specific type. (2) Add cert configuration decisions to the human-review checklist for infra PRs. |
| I7 | Operational issues (403, 500 errors) not self-diagnosable by non-dev users | After deployment, the PM (Guang Shin) encountered a 403 accessing the app (AWS WAF blocking VPN traffic, by design) and a 500 on `/admin`. Both required Chadin (DevOps) to diagnose — checking WAF logs for the 403 and retrieving app logs for the 500. A developer could self-service both; a non-dev PM cannot. Note: the `/admin` 500 was ultimately caused by missing env vars in prod, itself caused by E1 (`.env.example` excluded from git). | Runbook or self-service guide for common post-deployment error patterns. Accessible log viewer or error dashboard for the PM. Documented known infrastructure behaviours (e.g. VPN traffic blocked by WAF) so the PM can self-triage before escalating. | **Low–Medium.** No data loss or security risk, but creates a dependency on DevOps availability for routine operational issues. Blocks the PM from operating the app independently post-launch. | Chadin (DevOps) diagnosed both issues: checked WAF logs for the 403 (VPN-blocked traffic, expected behaviour), retrieved app logs for the 500 (`/admin` error). Root cause of the 500 subsequently traced to E1 by Natasha (SWE). | (1) Produce a post-deployment ops runbook covering common error codes, how to retrieve logs, and known infra behaviours (e.g. VPN + WAF). (2) Consider surfacing app logs via a read-only dashboard or CLI command the PM can run independently. (3) Document AWS WAF and ALB traffic filter behaviours in the deployment guide so VPN-related 403s are self-diagnosable. |

**Notes:**

> Supabase coupling was established across 3 commits within 37 minutes on Feb 25. The decision compounded — each commit made the next harder to undo. By the time prod deployment was attempted, the auth layer, migrations, RLS policies, and ORM version all needed changing simultaneously. The ADR (`b77814a`) documents the full option analysis and is worth reading alongside this entry.
>
> The PM's preference to use the dev environment for user testing is a legitimate need — grassroots practitioners building real tools need somewhere to test with an audience. The gap is not the PM's instinct but the absence of a pre-provisioned, compliant test environment that satisfies both that need and the org's security posture. Without one, the PM will reach for whatever is available (in this case, the cloud Supabase dev env), which creates the compliance and security exposure. Solving I2 also partially mitigates I1 — if a proper test env exists from the start, the PM has less reason to couple dev to a cloud service.
>
> I3–I4 both surfaced during the GCC Docker deployment phase. The npm build / pre-cache issue (I3) is a subtle one: Claude's optimization was technically correct for Vercel but silently incompatible with GCC's DB-isolated build environment. Without explicit CLAUDE.md constraints on build-time service access, this class of issue will recur whenever Claude applies performance optimizations. The Prisma schema gap (I4) is a common Docker packaging oversight but non-obvious to a PM who has not built Docker images before.
>
> I5 and I6 are the most significant agentic risk findings from Chadin's infra work. I5 shows that when the agent hits an infrastructure blocker, it may resolve it by modifying adjacent config (KMS in this case) rather than halting and asking — a "find a way through" behaviour that is dangerous in infra contexts where changes are hard to reverse. I6 shows that prompt-level instructions alone are insufficient to enforce infra workflow boundaries: the agent repeatedly attempted local prod applies despite explicit instructions. The two guardrails (human monitoring + restricted role) held, but both require active human presence. This is not a pattern that scales to autonomous operation. The concern about admin role discovery on the local machine is a real attack surface that should be closed before any further agentic infra work.

---

### Environment Configuration

| # | Gap | What Claude produced | What was missing | Risk | Engineer action | Proposed bridge |
|---|---|---|---|---|---|---|
| E1 | Agent-generated `.gitignore` used `env*` wildcard, silently excluding `.env.example` from all subsequent commits | In `979d924`, the agent introduced a `.gitignore` with a pattern matching `env*`. This excluded `.env.example` from being tracked, so the file was never committed. Chadin (DevOps) was not aware `.env.example` existed or that env vars needed to be supplied in the prod environment. The app deployed without the required env vars, causing a DB connection failure that surfaced as a 500 on `/admin`. Root cause traced by Natasha (SWE) after the live error. Fix pending merge in `8b2489a` (separate branch). | `.env.example` must be committed so that anyone deploying the app knows what env vars are required. The `.gitignore` wildcard `env*` is overly broad — it should only exclude `.env`, `.env.local`, `.env.*.local`, not `.env.example`. | **High.** The missing `.env.example` caused a silent misconfiguration in the production environment — no env vars supplied, no DB connection, app partially broken in prod. The error was only surfaced by the PM hitting a 500; without that trigger, the misconfiguration could have persisted undetected. The fix is also still unmerged. | Natasha (SWE) identified the missing `.env.example` as the root cause. Fix committed in `8b2489a`, pending merge. | (1) CLAUDE.md rule: `.gitignore` must never exclude `.env.example` — only `.env`, `.env.local`, and `.env.*.local` patterns should be ignored. (2) Add `.env.example` presence as a required check in the PR merge checklist. (3) Consider a CI lint step that validates `.env.example` is tracked and `.gitignore` does not contain overly broad `env*` patterns. |
| E2 | | | | | | |

**Notes:**

> Example gaps: incomplete `.env.example`, dev env pointing at cloud services instead of local, missing env vars for prod auth provider, secrets accidentally committed.
>
> E1 is also the root cause of the `/admin` 500 reported in I7. The operational error (500) and the configuration gap (missing `.env.example`) appeared to be separate incidents but traced back to the same `.gitignore` commit (`979d924`). This illustrates how a single agent decision early in the build can produce a delayed, hard-to-diagnose failure at deployment time.

---

### Database & Migrations

| # | Gap | What Claude produced | What was missing | Risk | Engineer action | Proposed bridge |
|---|---|---|---|---|---|---|
| D1 | | | | | | |
| D2 | | | | | | |

**Notes:**

> Example gaps: migrations using vendor-specific SQL incompatible with prod DB, RLS policies tied to Supabase's `auth.role()`, no seed strategy for prod, missing prisma seed config.

---

### CI/CD & Code Scanning

| # | Gap | What Claude produced | What was missing | Risk | Engineer action | Proposed bridge |
|---|---|---|---|---|---|---|
| C1 | | | | | | |
| C2 | | | | | | |

**Notes:**

> Example gaps: no pipeline config, SAST/DAST not set up, npm audit not gated in CI, no lint/type-check step before merge.
>
> See S2 for the npm vulnerability finding. The CI/CD bridge for S2 is to gate `npm audit --audit-level=high` in the pipeline so vulnerability regressions are caught automatically without relying on the PM to prompt for an audit.

---

### Code Quality & Type Safety

| # | Gap | What Claude produced | What was missing | Risk | Engineer action | Proposed bridge |
|---|---|---|---|---|---|---|
| Q1 | Type error suppressed with `any` cast and ESLint disable comment instead of a proper type | In `677de5b`, the studies page was created with `const where: Record<string, any> = {}` accompanied by `// eslint-disable-next-line @typescript-eslint/no-explicit-any`. This suppresses the type error at the surface rather than modelling the `where` clause with a correct type (e.g. a Prisma `StudyWhereInput` or a narrowed union). | A properly typed `where` variable that reflects the actual shape of the Prisma query filter. Suppressing ESLint rules and using `any` removes type safety from the query construction path — the compiler can no longer catch invalid filter fields or value types. | **Low–Medium.** No immediate runtime risk, but `any` in query construction means type errors in filter logic will only surface at runtime, not at compile time. Sets a precedent that makes reviewers more likely to accept similar suppressions elsewhere. | Caught by Natasha (SWE) during manual code review. Logged as an open issue; fix pending. | (1) Add a CLAUDE.md rule: ESLint disable comments and `any` casts are not acceptable resolutions for type errors — Claude must model the correct type or ask for clarification on the intended shape. (2) Enable `@typescript-eslint/no-explicit-any` as an error (not warning) in the ESLint config so CI fails on new `any` introductions. |
| Q2 | Repeated inline declaration of school categories constant across pages instead of a shared global | In `c4cd4ec`, `src/app/admin/(app)/config/quotas/page.tsx` was created alongside other files, each declaring school categories as a new local variable. The same constant appears across multiple pages rather than being extracted to a shared location in `lib/`. | A single source of truth for school categories as a global constant in `lib/` (DRY principle). Local re-declarations risk divergence if the list changes — one page could silently have a stale or different set of categories. | **Low.** No immediate runtime risk, but maintenance burden increases as pages multiply. Any update to school categories must be applied in every file individually, with no compiler enforcement that all copies stay in sync. | Caught by Natasha (SWE) during manual code review. Logged as an open issue; fix pending. | (1) Add a CLAUDE.md rule: shared lookup data (categories, enums, static lists) must be declared once in `lib/` and imported, not redeclared per page. (2) Consider a lint rule or code review checklist item for duplicate literal arrays/objects across files. |
| Q3 | Deprecated action files not cleaned up when superseded | Action files created in `8464f65` were not removed when they were deprecated by the changes in `c4cd4ec`. The stale files remained in the codebase with no indication they were no longer in use. | When code is superseded, the old files should be deleted in the same commit or PR. Leaving deprecated files creates ambiguity about which implementation is authoritative and increases the surface area for bugs if the old code is accidentally invoked. | **Low–Medium.** No immediate runtime risk if the deprecated files are not imported, but stale action files can be accidentally re-used by the agent or a developer in a future session, leading to hard-to-trace bugs. Bloats the codebase and undermines confidence in which code is live. | Caught by Natasha (SWE) during manual code audit. Logged as an open issue; cleanup pending. | (1) Add a CLAUDE.md rule: when replacing or superseding a file, delete the old file in the same change. (2) Add a step to the PR review checklist: confirm no orphaned or deprecated files remain from the change. |
| Q4 | Build-breaking type error introduced — `waiverReason` left as empty type after edits | Edits in `443bd4a` left `waiverReason` with an empty or unresolved type, causing `next build` to fail with type errors. Claude did not run a build check after making the changes to verify they compiled cleanly. | A `next build` or `tsc --noEmit` pass after every non-trivial edit to confirm no type errors were introduced. Correct typing of `waiverReason` rather than leaving it in a broken state. | **Medium.** Build-breaking errors block deployment entirely. This would have been caught by CI if a type-check step was gated in the pipeline, but without it the error reached the engineer's manual build check. Any change that compiles at the file level but breaks at the project level will go undetected if Claude does not run a full build. | Caught by Natasha (SWE) on running `next build` manually. Fixed in `89a02dd`. | (1) Add a CLAUDE.md rule: run `next build` or `tsc --noEmit` after any edit that touches types, props, or function signatures — do not consider the task complete until the project builds cleanly. (2) Gate `tsc --noEmit` in CI so type errors block merge regardless of whether a local build was run. |

**Notes:**

> Example gaps: type errors not caught during build, missing null guards on optional fields, inconsistent error handling patterns.

---

### Testing

| # | Gap | What Claude produced | What was missing | Risk | Engineer action | Proposed bridge |
|---|---|---|---|---|---|---|
| T1 | | | | | | |
| T2 | | | | | | |

**Notes:**

> Example gaps: tests written against mocks instead of real DB, no integration test coverage for critical paths, test env config missing.

---

### Developer Experience & Onboarding

| # | Gap | What Claude produced | What was missing | Risk | Engineer action | Proposed bridge |
|---|---|---|---|---|---|---|
| X1 | Post-rebase Prisma client stale when schema changed in main (not in the branch) | The `/review-pr` skill ran `npx prisma generate` conditionally — only if `prisma/schema.prisma` appeared in `git diff origin/main...HEAD` (branch-side changes). When a rebase brought in a schema change from a recently merged main PR, the generated client was not regenerated, causing `tsc --noEmit` to fail with "Property 'hashedPassword' is missing" on push. | `npx prisma generate` must run unconditionally after every rebase — not just when the branch changed the schema. The generated client in `prisma/generated/` is gitignored and may be stale relative to what main introduced. | **Low–Medium.** Does not affect production code quality, but blocks the push step and forces the engineer to manually diagnose a confusing type error that has nothing to do with their branch changes. Non-obvious root cause. | Fixed in `chore/enhance-review-skill` (PR #120): changed the post-rebase step to always run `npx prisma generate` unconditionally. | Always run `npx prisma generate` after any rebase in the `/review-pr` skill — remove the conditional `grep -q "prisma/schema.prisma"` gate entirely. The command is idempotent and completes in ~30ms. |
| X2 | | | | | | |

**Notes:**

> Example gaps: README missing local setup steps, no docker-compose for local dev, onboarding assumes cloud credentials that new devs don't have.

---

## Effort Summary

| Category | Engineer effort (days) | Complexity | Could be automated? |
|---|---|---|---|
| Security | | Low / Med / High | Yes / Partial / No |
| Infrastructure & deployment | | Low / Med / High | Yes / Partial / No |
| Environment configuration | | Low / Med / High | Yes / Partial / No |
| Database & migrations | | Low / Med / High | Yes / Partial / No |
| CI/CD & code scanning | | Low / Med / High | Yes / Partial / No |
| Code quality & type safety | | Low / Med / High | Yes / Partial / No |
| Testing | | Low / Med / High | Yes / Partial / No |
| Developer experience | | Low / Med / High | Yes / Partial / No |
| **Total** | | | |

---

## Towards an Agentic Dev-to-Deployment Flow

### What worked well

> What did Claude handle without engineer intervention? What parts of the build could a PM ship directly?

-
-
-

### Recurring gap patterns

> Which categories of gaps appeared repeatedly, and what do they have in common?

-
-
-

### Proposed solutions

> For each recurring pattern, what tooling, prompt engineering, or process change could close the gap?

| Pattern | Solution | Owner | Effort |
|---|---|---|---|
| | | | |
| | | | |

### Open questions

> What gaps are we unsure how to bridge? What needs more exploration?

-
-
-

### Next trial changes

> What would we set up differently before handing the build to the PM next time?

- [ ]
- [ ]
- [ ]

---

## Overall Assessment

**Would we run another trial like this?**

**How close are we to an agentic dev-to-deployment flow?**
`[ ] Not close  [ ] Early signs  [ ] Viable with guardrails  [ ] Ready`

**Key blocker to closing the gap:**
