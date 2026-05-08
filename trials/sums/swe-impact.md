# SWE Impact Summary — SuMs Trial

**Author:** Natasha (SWE)
**Period covered:** 2026-03-27 to 2026-05-08
**Total commits:** 83 (35 fixes, 16 docs, 11 tests, 9 chores, 4 feats + merges)
**Lines changed:** +5,582 / −2,325

---

## Executive Summary

The SuMs trial tested whether a product manager using an AI coding assistant could build and ship a production application with minimal engineering involvement. The short answer is: the AI can build features at speed, but it cannot be trusted to ship safely without a dedicated human evaluator on the other side.

My role was that evaluator. I joined after the PM's build week to assess what the AI had produced and prepare it for production deployment. What I found — before a single user had accessed the app — was a critical security exposure: the AI had embedded live system credentials directly in the code, where anyone with access to the repository could read them. This went undetected for 19 days. Left unaddressed, it would have given any repository reader full administrative access to the project's data.

That finding set the direction for the rest of the trial. Rather than repeatedly reviewing code by hand, I built an automated quality-checking layer — a set of tools that run every time the AI submits new code for review, looking for the same classes of problems I had found manually. This shifted the model: instead of the engineer catching issues after the fact, the tooling catches them at the point of submission.

The automated checks proved effective at catching structural and consistency problems — mistyped code, missing safety checks, shortcuts that would cause errors in production. But two bugs slipped through that the tooling could not catch, because they only became visible when someone actually used the application. The AI's code review passed both. Human testing caught them. This finding drove the final phase of work: adding browser-level automated tests that simulate a real user interacting with the app, so that class of runtime bug can be caught automatically in future.

**Four findings for leadership:**

1. **The AI needs an evaluator, not just a reviewer.** The same AI that wrote the code is also lenient when asked to check its own work. A separate review process — run independently, not by the generator — is what catches the gaps. This trial demonstrated the pattern works; the key is keeping the roles distinct.

2. **Automation beats instruction.** Telling the AI not to expose secrets is not a reliable control — it is non-deterministic by nature and cannot guarantee compliance. Wiring an automated secrets scanner into the submission process is. Where we were able to replace agent-dependent behaviour with deterministic automation, we got guarantees. Where we relied on instructions alone, we got probabilities.

3. **Human testing remains load-bearing for auth and user-facing flows.** The AI cannot log in to the application and click through a user journey. For any behaviour that only manifests at runtime — race conditions in the UI, environment mismatches, flows that depend on what the browser actually does — a human tester is still required. The tooling built in this trial makes that boundary explicit: every PR now classifies which test steps are automated and which require a human to verify before the code can ship.

4. **The SWE's most durable contribution is the review tooling, not the fixes.** The individual bugs found and fixed during this trial have limited shelf life — the codebase will change and new issues will emerge. What compounds in value is the review infrastructure: the automated checks, the rules codified from each gap, and critically, the self-improving feedback loop built into the review process. After each review, the tooling is prompted to identify any gap it caught that was not already in its ruleset, and to propose adding it. The SWE approves or rejects the addition. Over time, this means the review process gets more thorough with each cycle, tailored to how this specific codebase and this specific team's AI tend to produce errors — without requiring the SWE to manually anticipate every future failure mode in advance.

---

## Role

Software engineer evaluating agentic engineering workflows. Joined after the PM's build week and was responsible for: auditing what the agent produced, bridging the gaps required for production deployment, and building the review infrastructure that would catch future regressions.

The work divides into two distinct modes, separated by the introduction of the `review-pr` skill on 2026-04-09:

- **Before the review skill:** gaps were found through manual human audit
- **After the review skill:** gaps in subsequent agent-generated PRs were surfaced by running the skill, with the SWE resolving what it flagged

A third category emerged later — functional bugs that passed both the review skill's static analysis *and* human code review, and were only caught through manual runtime testing. These ultimately drove the addition of E2E test infrastructure.

---

## Part 1 — Manual Audit Phase (2026-03-27 to 2026-04-08)

Everything in this phase was found and fixed before any review tooling existed. Findings came entirely from reading the codebase, the git history, and test output by hand.

### Critical security findings (2026-03-27)

**Hardcoded credentials** (`54eabd1`, gap S1): The agent committed a Supabase service role key, admin email, and admin password in plaintext in `scripts/create-admin.ts` on 2026-02-27 — a 19-day exposure window. Fixed by replacing all secret values with environment variables, adding early-exit validation, and correcting the `.gitignore` wildcard (`env*`) that had silently excluded `example.env` from all subsequent commits. This same `.gitignore` bug (`979d924`) was also the root cause of the `/admin` 500 error in production (gap E1): without `example.env` in the repo, Chadin (DevOps) had no way to know which env vars to supply to the deployment.

**12 npm vulnerabilities — 6 high, 6 moderate** (`d45f1be`, gap S2): The agent had not run `npm audit` at any point during the build week. Fixed via dependency overrides in `package.json` targeting `next`, `hono`, and `lodash`.

### Tooling scaffold (2026-03-27)

`08e7a87` introduced the entire developer tooling layer the project was missing:

- `CLAUDE.md` (108 lines) — first version of project rules derived from the audit
- `.husky/pre-commit` — gitleaks secret scanning, ESLint, and type checking on every commit
- `.husky/pre-push` — unit test enforcement on every push
- `.gitleaks.toml` — org-specific secret detection patterns
- `docs/grassroots-claude-template.md` — template for future grassroots agentic projects
- Initial Claude Code skills scaffold

### Infrastructure stabilisation (2026-03-31)

Following Chadin (DevOps) identifying Docker deployment failures:

- `ced061b` — added `COPY prisma ./prisma` to the Dockerfile so `prisma migrate deploy` could run at container startup (gap I4)
- `6c61873` — fixed the local Docker Compose setup
- `ced1284` — npm audit pass after package changes

---

## Inflection Point — Review Skill Added (2026-04-09)

**Commit `11fe9e2`** added `.claude/commands/review-pr.md` — a 363-line structured pre-merge review workflow. From this point, the SWE's role shifted: instead of reading PRs manually to find issues, the review skill was run on each incoming PR and its output drove the fix list. The SWE resolved what the skill flagged and fed newly discovered patterns back into CLAUDE.md so the skill would catch them in future.

The skill covers: rebase onto main, merge conflict resolution, change analysis, test coverage gaps, CLAUDE.md compliance scanning, build and type-check verification, and a sequential fix loop with one commit per fix.

Three immediate enhancements followed on the same day:

- `bdb59ee` — added rebase-on-main as the first step
- `278b86a` — added divergence warning and unconditional post-rebase Prisma regeneration
- `48069530` (gap X1) — the initial skill ran `npx prisma generate` only when the branch had modified `prisma/schema.prisma`. A schema change introduced by a recently merged PR landed via rebase without appearing in the branch diff, leaving the generated client stale. The condition was removed; the command now runs unconditionally after every rebase.

---

## Part 2 — Review-Skill-Driven Fixes (2026-04-09 to 2026-05-05)

All gaps in this section were surfaced by running `review-pr` against agent-generated PRs. The SWE did not find these through manual reading; the skill flagged them, and the SWE resolved them and updated CLAUDE.md with the rule that would prevent recurrence.

### First review pass — code quality (2026-04-09)

The first batch of PRs reviewed on the day the skill launched produced a sweep of code quality fixes against the patterns the initial manual audit had identified (Q1, Q2, Q3):

| Commit | Fix | Gap |
|---|---|---|
| `a82e2ee` | Extracted `STUDY_CATEGORIES` and quota colour helpers to `src/lib/` | Q2 |
| `bf71870` | Replaced `Record<string, any>` + eslint-disable with `Prisma.StudyWhereInput`; fixed CSV line endings and export row cap; added integration tests for the export route | Q1 |
| `46c5e11` | Resolved follow-on type errors from the `StudyWhereInput` adoption | Q1 |
| `54361a3` | Removed `hashedPassword` from seed — OTP auth has no password column | — |
| `2503a36` | Added director routing tests and clarified middleware comments | — |
| `313ef1e` | Simplified `user_notification_prefs` — dropped the unused `enabled` column | — |
| `7d6a97f` | Made `getDirectorEmail` deterministic with `orderBy createdAt` | — |
| `5400f8a` | Added unit test for auth/index provider dispatch | — |

### Supabase removal (2026-04-14)

`924a50b` completed the full decoupling from Supabase that the agent had coupled during its build week (gap I1). This was the largest single commit: 706 additions, 1,065 deletions. Removed: `src/lib/auth/providers/supabase.ts`, the Supabase test suite, `supabase/config.toml` (388 lines), and all related `node_modules` entries. Added: `setup-local.sh` (377 lines), `.claude/commands/run-local.md` (240 lines), updated `src/lib/auth/index.ts` and `src/middleware.ts`. Concurrently, `98a2627` upgraded Prisma 6 → 7 and added all required OTPaaS environment variables.

### Bug-fix test content gap (2026-04-16, gap T1)

The review skill flagged that a bug-fix PR had written tests that checked `res.status === 400` and the shape of the `errors` key, but never asserted the actual error string — the behaviour the fix was meant to correct. A test that still passes with the broken code is not a covering test.

`fd3d377` added `.toMatch(/startDate/)` and `.not.toContain('"issues"')` assertions to `tests/api/studies-validation.test.ts`. `2e2485f` documented this as gap T1 in CLAUDE.md: bug-fix tests must assert corrected content, not only status codes.

`ee3f310` and `2a73344` added unit and integration tests for the `updateSystemConfigSchema` null branch, a path the agent had not tested.

### External API error mapping (2026-04-27, gap Q5)

The review skill flagged that `sendOtp` was returning raw OTPaaS JSON blobs (`{"code":2008,"message":"Wait for 51 seconds..."}`) directly to the login UI. `01af0eb` documented gap Q5 and the CLAUDE.md rule: in any `lib/` function wrapping an external API call, the `!res.ok` branch must map to a user-friendly string — never return `res.text()` or raw JSON. `769bdb2` added a test for the edge case where code 2008 arrives without a `cooldown` field.

`3918a99` extracted `STATUS_LABELS` and `STUDY_TYPE_LABELS` from inline declarations into `src/lib/reporting/labels.ts` (Q2 continuation). `f4f2a33` added unit tests for the reporting CSV utilities. `ed28e30` clarified that the shared lookup data rule applies to route handlers and components, not just pages.

### OTPaaS network resilience (2026-05-04, gaps T2, Q6)

`59e6818` wrapped both `sendOtp` and `verifyOtp` fetch calls in try-catch so network failures return a user-facing error instead of an unhandled promise rejection.

The review skill then flagged gap T2 (`1975c7b`): `getApiKey()` — which throws a deterministic error when env vars are absent — was inside the try block, so a misconfigured deployment silently returned "Couldn't send code" instead of crashing loudly. Fix: move `getApiKey()` before the try block so configuration errors still propagate.

The skill also caught gap Q6 (`07b6a93`): extending `SendOtpResult`/`VerifyOtpResult` to add a required `errorCode` field had left the catch-block return sites without the new field, breaking the build. The fix added `errorCode: 'network_error'` to both catch blocks and tests for both fetch-throws paths.

`7558d8c` documented T2 and T3 in CLAUDE.md.

---

## Part 3 — Functional Bugs Found Only Through Manual Testing (2026-05-04 – 2026-05-05)

The review skill operates by static code analysis: it reads the diff, checks type safety, scans for CLAUDE.md violations, and confirms the build passes. It cannot execute the application. Two bugs in this period passed static review without issue and were only caught when a human ran the actual login flow.

### Bug 1 — OTP double-send (`901f2cf`)

A previous PR (PR #149) had disabled the submit button using `useFormStatus().pending` to prevent double submissions. The review skill had reviewed that PR and raised no objection — the approach is correct React practice and the types were clean.

Manual testing of the login flow revealed the fix was insufficient: `useFormStatus().pending` is a React state value set during re-render, which is asynchronous. A second click fires before the DOM updates, so the race condition that allows multiple OTP requests through still existed.

The root cause was only visible at runtime. The fix (`901f2cf`) replaced the async state guard with a synchronous `useRef` guard on each form's `onSubmit` handler. `e.preventDefault()` runs in the same call stack as the click event, cancelling the second submission before React is involved. This required extracting `SendCodeForm` and `VerifyOtpForm` as client components to own the `onSubmit` handler. The same commit also fixed a migration that referenced `"Study"` (the Prisma model name) instead of `"studies"` (the actual Postgres table), causing P3009 on every fresh database — another runtime failure invisible to static analysis.

### Bug 2 — Division code case sensitivity (`08e0240`)

The review skill had passed a PR adding `prefilledEmail` and `prefilledDivision` props to the study form. Static analysis confirmed the initialisation and reset logic was correct. When asked explicitly to verify the PR's five stated test criteria, the evaluator agent returned a full PASS on all five, based solely on reading the implementation.

Manual testing revealed Criterion 2 (editing a prefilled division value before submit) did not work as expected. Root cause: `ADMIN_DIVISION=DxD` was set in the local env, but division codes are case-sensitive and the stored value used a different casing, causing a silent mismatch. This class of bug — arising from a misconfigured environment value, not a code logic error — is invisible to both static review and unit tests.

`08e0240` extended `scripts/create-admin.ts` to read `ADMIN_ROLE` and `ADMIN_DIVISION` from environment variables so the values could be set correctly and consistently across environments.

`2a2dc50` (gap T3) then added `src/test/study-form-prefill.test.ts` covering all five test-plan steps: initialisation on load, edit-and-submit, submit-as-is, re-prefill after reset, and public-form regression. The PR had shipped with two of its own test-plan steps unchecked.

`828b2ef` and `a7c90ba` updated the pre-merge audit and review-pr skills to classify each test criterion as `[AUTOMATED]`, `[AGENT E2E]`, or `[HUMAN REQUIRED]`, and to surface a distinct top-level "Human Testing Required" section in review output so the SWE cannot overlook which criteria need runtime verification.

### Why unit tests are not enough

Both bugs above share a property: the failure mode is a runtime interaction between the application state, the browser event model, or the environment configuration — none of which are visible to a type checker or a unit test asserting pure function output. The static review skill is a strong gate for structural and type-safety issues; it is not a substitute for executing the application.

This is the direct cause of the E2E test infrastructure added in the following phase.

---

## Part 4 — E2E Test Infrastructure (2026-05-06 – 2026-05-08)

The OTP double-send and division mismatch bugs established that a category of defects exists which unit tests and static analysis cannot catch. Encoding those scenarios as automated E2E tests closes the gap for regressions — if either fix regresses, a Playwright test catches it before the PR merges.

### Integration test expansion

- `c7acf21` — added `docker-compose.test.yml` with an ephemeral Postgres container on port 5433 for local integration test runs
- `03433c7` — wired integration tests into the pre-push hook: detects changes under `prisma/`, `src/app/api/`, `src/lib/`, or `tests/api/` and runs `npm run test:api:local` automatically
- `8e02017` — integration tests for report export routes
- `27714c8` — integration tests for `POST /api/admin/studies/[id]/withdraw`
- `776a008` — unit tests for `checkQuotaSchema` null `staffProportion` branch

### E2E test gate (2026-05-08)

`2f614a2` wired Playwright E2E tests into the pre-commit hook: when any file under `src/`, `e2e/`, or `playwright.config.ts` is staged, the hook verifies Playwright browsers are installed, the local Postgres container is running, and then runs `npm run test:e2e` before allowing the commit. This makes E2E coverage mandatory for all application code changes, not optional.

`2c94bf8` fixed the Playwright local setup: switched `webServer` to port 3001 (so Playwright always starts its own `next dev` instance with dev-bypass auth enabled rather than reusing the Docker production app on port 3000) and set `override: true` in `dotenv.config` so `.env.local` values win over shell-exported vars.

Note: E2E coverage of flows that pass through OTPaaS remains structurally blocked — the OTP delivery mechanism is specifically designed to resist automation, and no sandbox with whitelisted test credentials exists. Test criteria that require a live OTP login are permanently marked `[HUMAN REQUIRED]` in the review skill. The E2E gate covers authenticated flows that use the dev-bypass auth path; auth flows themselves require human execution.

### Developer experience

- `67738ca` — troubleshoot skill matching common local env error symptoms to known fixes
- `8f0f528` — self-signed cert error and resolution documented
- `cf7d299` — local and test Docker setup documented
- `c351e81` — created the missing `src/lib/auth/dev-bypass.ts` module (gap Q7: the file was imported by `admin/login` pages but never created, causing TS2307 build errors caught only by the pre-push hook — the pre-commit hook does not run `tsc`)
- `1224f6e` — documented Q7 in CLAUDE.md

---

## Impact Summary

### Gaps directly remediated

| Gap | Description | Risk | How found | Action |
|---|---|---|---|---|
| S1 | Hardcoded credentials in `scripts/create-admin.ts` | Critical | Manual audit | Replaced with env vars, fixed gitignore |
| S2 | 12 npm vulnerabilities (6 high, 6 moderate) | High | Manual audit | Resolved via package overrides |
| E1 | `.gitignore` `env*` wildcard excluded `example.env` | High | Manual audit | Fixed gitignore, committed `example.env` |
| I4 | Prisma schema absent from Docker image | Medium | Manual audit | Added `COPY prisma ./prisma` to Dockerfile |
| Q1 | `any` cast suppressing type errors | Low–Medium | Review skill | Replaced with `Prisma.StudyWhereInput` |
| Q2 | Constants redeclared per file instead of shared in `lib/` | Low | Review skill | Extracted to `src/lib/` |
| Q3 | Deprecated files not cleaned up | Low–Medium | Review skill | Removed stale files in same PR |
| Q5 | Raw external API errors returned to users | Medium | Review skill | Added `mapOtpaasError()` in `src/lib/otpaas.ts` |
| Q6 | Discriminated union extended without updating all return sites | Medium | Review skill | Fixed catch-block returns, added tests |
| Q7 | Import from module that was never created (TS2307) | Medium | Review skill | Created `src/lib/auth/dev-bypass.ts` |
| T1 | Bug-fix tests asserting status only, not corrected content | Medium | Review skill | Added content assertions to existing tests |
| T2 | try-catch swallowing configuration-error throws | Medium | Review skill | Moved `getApiKey()` before try block |
| T3 | New form prefill shipped without test coverage | Low–Medium | Review skill | Added 5-step unit test suite |
| X1 | Post-rebase Prisma client stale when schema changed in main | Low–Medium | Review skill | Made `npx prisma generate` unconditional |
| — | OTP double-send race condition | Medium | Manual testing | Replaced async state guard with synchronous `useRef` |
| — | Division code case-sensitivity mismatch | Medium | Manual testing | Read `ADMIN_DIVISION` from env; added prefill tests |

### Infrastructure built

| Artifact | Purpose |
|---|---|
| `.husky/pre-commit` | Secret scanning (gitleaks), lint, type check, E2E tests on every commit |
| `.husky/pre-push` | Unit tests on every push; integration tests on DB-related changes |
| `.gitleaks.toml` | Org-specific secret detection patterns |
| `CLAUDE.md` (initial + ongoing) | Project rules derived from gap analysis, updated as new patterns emerged |
| `.claude/commands/review-pr.md` | Full pre-merge review workflow (rebase, gap scanning, fix loop) |
| `.claude/commands/pre-merge-audit.md` | Pre-PR audit classifying criteria as `[AUTOMATED]` / `[AGENT E2E]` / `[HUMAN REQUIRED]` |
| `.claude/commands/run-local.md` | Non-developer-friendly local setup |
| `.claude/commands/troubleshoot.md` | Symptom-matched troubleshooting for common local env errors |
| `setup-local.sh` | Scripted local environment setup |
| `docker-compose.test.yml` | Ephemeral Postgres for local integration test runs |
| `docs/grassroots-claude-template.md` | Template for future grassroots agentic projects |

### Test coverage added

| Test file | Coverage |
|---|---|
| `tests/api/studies-export.test.ts` | Export route: auth, columns, filter, validation |
| `tests/api/users.test.ts` | Admin user CRUD routes |
| `tests/api/studies-validation.test.ts` | Validation error content (not just status) |
| `tests/api/withdraw.test.ts` | Study withdrawal route |
| `tests/api/reports-export.test.ts` | Report export routes |
| `tests/api/system-config.test.ts` | System config null-value PATCH |
| `src/test/auth-index.test.ts` | Auth provider dispatch |
| `src/test/div-rep-quota.test.ts` | Quota colour helpers |
| `src/test/otpaas.test.ts` | `mapOtpaasError` edge cases; network-failure catch paths |
| `src/test/reporting.test.ts` | CSV utility functions |
| `src/test/study-form-prefill.test.ts` | Prefill initialisation, edit, reset, regression |
| `src/test/checkQuota.test.ts` | Null `staffProportion` branch |

---

## Observations on the Agentic Workflow

The trial produced a clear picture of what the review skill can and cannot cover, and of how the two modes of gap detection are complementary rather than competitive.

**What the review skill catches reliably:** type errors, CLAUDE.md violations (hardcoded values, inline constants, raw error passthrough), missing or shallow test coverage, stale imports, and build regressions. These are all statically verifiable properties. The skill surfaces them faster and more consistently than manual PR reading, and because it runs in a separate agent context it does not carry the generator's leniency about its own work.

**What the review skill cannot catch:** functional behaviour that only emerges at runtime. The OTP double-send existed in code that was type-safe, correctly structured, and passed a `tsc --noEmit` check. The division mismatch existed in code that was logically correct given its inputs — the problem was the environment value, not the code. Neither bug was detectable by static analysis. Both required a human to run the application and observe the wrong behaviour.

**The implication for test infrastructure:** once you understand this boundary, the direction is clear. Unit and integration tests cover the static layer; E2E tests cover the runtime layer. The decision to wire Playwright into the pre-commit hook in Part 4 is a direct consequence of Parts 1–3 demonstrating that each layer catches a distinct class of bug, and that no single layer is sufficient on its own.

**The review skill is a living document, not a one-time setup.** Every gap found during this trial — whether caught by the skill, by human code review, or by manual testing — was written back into the skill and into CLAUDE.md. The Q5 rule on external API errors, the T1 rule on bug-fix test content, the T2 rule on precondition checks before try-catch blocks: each of these exists because a specific pattern was observed in this codebase and codified so the skill would recognise it in future PRs. A skill that is never updated becomes stale as the codebase grows and new patterns emerge; a skill that is updated after every meaningful finding becomes progressively sharper.

The SWE's ongoing role is therefore not just to run the skill but to maintain it — treating it as a shared engineering asset rather than a fixed checklist. Each review session is an opportunity to ask whether the skill would have caught any issues that slipped through, and if not, to add the rule. This is the mechanism by which the review process improves faster than the rate at which the AI introduces new categories of error.

**The self-improving function.** The review skill was extended with a prompt instructing the agent to inspect its own output at the end of each review — specifically, to identify any gap it flagged that was not already covered by an existing CLAUDE.md rule, and if so, to propose a new rule and update the skill file accordingly. This means the skill can grow its own rule set through use: a pattern the SWE might not think to add manually gets surfaced by the reviewing agent itself and fed back into the harness. The SWE reviews and accepts or rejects the proposed addition, keeping a human in the loop on what the skill learns. Over time, this creates a feedback loop where the review skill becomes more tailored to the specific codebase and less reliant on the SWE manually anticipating every new failure mode.

The remaining hard boundary is authentication: OTPaaS is designed to resist automation, and any test criterion that passes through the real login flow requires human execution. That boundary is permanent unless a sandbox environment with whitelisted test credentials is provisioned. Until then, auth flows are marked `[HUMAN REQUIRED]` in the review skill, and the process requires explicit human sign-off before a PR containing auth-path changes can merge.
