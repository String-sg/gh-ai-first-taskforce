# Agentic Trial Goals & Charter

**Project:** [project name and one-line description]
**PM (grassroots builder):** [name]
**SWE reviewer:** [name]
**DevOps reviewer:** [name]
**Trial period:** [start date] – [end date]
**Review date:** [planned post-trial review date]

---

## Purpose

> Why are we running this trial? What hypothesis are we testing about agentic development?

---

## What we want to learn

> Frame as "After this trial, we will know whether…"

- After this trial, we will know whether…
- After this trial, we will know whether…
- After this trial, we will know whether…

---

## Success criteria

> Define measurable outcomes. These become the basis for the Overall Assessment in the trial review.

| Criterion | How we'll measure it | Target |
|---|---|---|
| PM can ship to test without SWE intervention | Count of gaps requiring SWE action | < [N] gaps |
| No critical security gaps reach prod | Gap log severity ratings | Zero Critical findings |
| Build-to-test cycle time | Days from first commit to test-env deploy | < [N] days |
| | | |

---

## Risk areas to watch

> Which categories are most likely to need engineer intervention? Tick the ones that apply to this project's stack and complexity. Use these to focus monitoring effort during the trial.

- [ ] Security (credential handling, auth, secret scanning)
- [ ] Infrastructure & deployment (cloud hosting, containers, networking)
- [ ] Environment configuration (dev / test / prod separation, env vars)
- [ ] Database & migrations (schema design, migration compatibility)
- [ ] CI/CD & code scanning (pipeline setup, vulnerability gating)
- [ ] Code quality & type safety (TypeScript, linting, build verification)
- [ ] Testing (unit, integration, coverage)
- [ ] Developer experience (onboarding, local setup, runbooks)

**Highest-risk area for this trial:**

> [Which single area is most likely to require the most engineer time, and why?]

---

## Pre-trial checklist

> Signed off by SWE and DevOps before the PM starts the build week.

**Project scaffold**
- [ ] `CLAUDE.md` copied from `templates/CLAUDE.md` with all `[ ]` placeholders filled
- [ ] `docker-compose.yml` with a local Postgres service on port 5432
- [ ] `.env.example` committed with all required env vars
- [ ] `.gitignore` uses only explicit patterns — no `env*` wildcard
- [ ] Prisma `>=7` installed; `prisma/schema.prisma` initialised
- [ ] Three environments defined (local / test / prod) with distinct configs and env files
- [ ] Husky installed with hooks: gitleaks (pre-commit), npm audit + tsc + npm test (pre-push)

**Team alignment**
- [ ] PM has read `CLAUDE.md` and confirmed they understand the rules
- [ ] SWE review cadence agreed (e.g. daily async review of Claude's commits)
- [ ] DevOps has confirmed the test and prod environments are provisioned
- [ ] Escalation path agreed for blockers (who to contact and how)

**Scope definition**
- [ ] Feature list for build week agreed and written down
- [ ] Any hard infra/auth/DB problems are pre-scaffolded by SWE before handoff
- [ ] Compliance or data sensitivity requirements documented

---

## Out of scope for this trial

> What are we explicitly not testing or building during this trial?

-
-

---

## Known constraints

> Any org policies, infra limitations, or tooling restrictions Claude should be aware of.

-
-

---

## Notes

> Any other context, decisions made pre-trial, or things to flag for the review.
