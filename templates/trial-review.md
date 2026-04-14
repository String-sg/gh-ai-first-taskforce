# Agentic Development Trial Review

**Project:** [project name]
**Trial period:** [start date] – [end date]
**Review date:** [date]

---

## Trial Setup

| Role | Person | Involvement |
|---|---|---|
| Grassroots developer (PM) | [name] | Full-time for build week |
| Software engineer | [name] | Part-time, merge-readiness gaps |
| DevOps engineer | [name] | Part-time, infrastructure gaps |

### Timeline

| Phase | Duration | Description |
|---|---|---|
| Requirements & PRD | [duration] | PM gathers requirements, forms PRD |
| Build | [duration] | PM builds with Claude Code |
| Prod hardening | [duration] | Engineers fill gaps, prepare for merge |

### What was built

> Brief description of the app — its purpose, core features, and tech stack.

**Stack:**
**Auth:**
**Database:**
**Deployment target:**

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
| S1 | | | | | | |
| S2 | | | | | | |

**Notes:**

> Example gaps: credentials hardcoded in scripts, npm vulnerabilities not audited, secrets committed to git history.

---

### Infrastructure & Deployment

| # | Gap | What Claude produced | What was missing | Risk | Engineer action | Proposed bridge |
|---|---|---|---|---|---|---|
| I1 | | | | | | |
| I2 | | | | | | |

**Notes:**

> Example gaps: dev DB coupled to cloud service, Prisma version mismatch, Dockerfile missing schema files, KMS misconfiguration, agent attempting local prod applies.

---

### Environment Configuration

| # | Gap | What Claude produced | What was missing | Risk | Engineer action | Proposed bridge |
|---|---|---|---|---|---|---|
| E1 | | | | | | |
| E2 | | | | | | |

**Notes:**

> Example gaps: `.gitignore` wildcard excluding `.env.example`, incomplete env var coverage, dev env pointing at cloud services instead of local.

---

### Database & Migrations

| # | Gap | What Claude produced | What was missing | Risk | Engineer action | Proposed bridge |
|---|---|---|---|---|---|---|
| D1 | | | | | | |
| D2 | | | | | | |

**Notes:**

> Example gaps: migrations using vendor-specific SQL incompatible with prod DB, no seed strategy for prod, missing prisma seed config.

---

### CI/CD & Code Scanning

| # | Gap | What Claude produced | What was missing | Risk | Engineer action | Proposed bridge |
|---|---|---|---|---|---|---|
| C1 | | | | | | |
| C2 | | | | | | |

**Notes:**

> Example gaps: no pipeline config, SAST/DAST not set up, npm audit not gated in CI, no lint/type-check step before merge.

---

### Code Quality & Type Safety

| # | Gap | What Claude produced | What was missing | Risk | Engineer action | Proposed bridge |
|---|---|---|---|---|---|---|
| Q1 | | | | | | |
| Q2 | | | | | | |

**Notes:**

> Example gaps: type errors suppressed with `any` casts or `eslint-disable`, shared constants redeclared per page, deprecated files not deleted, build-breaking type errors not caught before push.

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
| X1 | | | | | | |
| X2 | | | | | | |

**Notes:**

> Example gaps: README missing local setup steps, no docker-compose for local dev, stale generated clients after rebase, onboarding assumes cloud credentials new devs don't have.

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
