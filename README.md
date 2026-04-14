# Agentic SWE Taskforce

Knowledge repository for the Agentic Software Engineering Taskforce. This repo collects best practices, templates, and lessons learned from trials where non-engineer practitioners build production software with Claude Code.

---

## What's here

```
agentic-swe-taskforce/
├── templates/
│   ├── CLAUDE.md           Generalized CLAUDE.md — copy to a new project before build week
│   ├── trial-review.md     Blank post-trial review template
│   └── trial-goals.md      Goals and success criteria template — fill in before each trial
├── skills/
│   ├── skills.md           /skills — lightweight pre-merge checklist (pass/fail table)
│   └── review-pr.md        /review-pr — full automated PR review workflow
└── trials/
    └── sums/               Artifacts from Trial 1: SuMS (Feb–Mar 2026)
        ├── CLAUDE.md       SuMS project rules (the source for templates/CLAUDE.md)
        └── trial-review.md SuMS post-trial review with gaps log
```

---

## Skills

The `skills/` directory contains two Claude Code custom commands. Copy them into any project repo to activate automated code review.

### Installing skills in a project

```bash
mkdir -p .claude/commands
cp path/to/agentic-swe-taskforce/skills/skills.md .claude/commands/skills.md
cp path/to/agentic-swe-taskforce/skills/review-pr.md .claude/commands/review-pr.md
```

Commit `.claude/commands/` to the project repo so the skills are available to everyone working in it.

> **One-time setup:** `review-pr.md` Phase 5 references the trial review file to log new gap patterns. Update the path on line 363 from `docs/agentic-trial-review-template.md` to wherever your project keeps its trial review document (e.g. `trials/<project-name>/trial-review.md` in this repo, or a local `docs/` path in the project repo).

### `/skills` — pre-merge checklist

Invoke with `/skills` in a Claude Code session before opening a PR.

Runs a focused audit of the current working tree and staged changes. Covers:

| Area | How it checks |
|---|---|
| Husky hooks | Verifies pre-commit and pre-push hooks are installed and contain the expected commands |
| Credentials & secrets | Confirms `.env.example` is tracked, `.gitignore` has no `env*` wildcard, no env files staged |
| Code organisation | Scans for shared constants redeclared per page; flags orphaned/deprecated files |
| Docker & Prisma | Confirms `prisma migrate deploy` is in the deployment runbook if Prisma files changed |
| Raw SQL queries | Checks for unsafe `$queryRawUnsafe` / `Prisma.raw()` patterns with user-supplied input |
| Infrastructure | Checks for autonomous KMS changes, local prod applies, undocumented TLS cert decisions |
| Environment config | Verifies every `process.env.VAR` in the codebase has a corresponding `.env.example` entry |

Output: a pass/fail table. Any FAIL on a Critical or High item blocks merge.

**Use this** for a quick sense-check before raising a PR, or during the build week to keep Claude on track.

### `/review-pr` — full PR review workflow

Invoke with `/review-pr` in a Claude Code session on your PR branch.

Runs end-to-end and fixes violations autonomously. Phases:

| Phase | What happens |
|---|---|
| 0 — Rebase | Fetches main, rebases the branch, resolves conflicts, regenerates Prisma client |
| 1 — Analysis | Reads PR metadata, extracts test plan steps, collects changed files and full diff |
| 2 — Test coverage | Maps changed `src/lib/` and `src/app/api/` files to expected unit and integration tests; flags gaps |
| 3 — Code standards | Runs gitleaks, scans for `any` casts, `eslint-disable`, shared constants, orphaned files, missing env vars, build-time DB calls, Dockerfile integrity |
| 4 — Build & test | Runs `npm test`, `npm run build`, and (if a local test DB is available) `npm run test:api` |
| TODO list | Renders all findings prioritised Critical → High → Medium → Low before touching any code |
| 5 — Document | Adds new gap patterns to the trial review doc and updates `CLAUDE.md` rules |
| 6 — Execute | Works through the TODO list one item at a time, each committed separately with a typed commit message |

**Use this** as the SWE's merge-readiness pass before any PR is merged to main. It replaces a manual code review for the categories it covers and produces a clean, commit-per-fix audit trail.

---

## Running a new trial

**Before the build week:**

1. Fill out `templates/trial-goals.md` with the project context, what you want to learn, and success criteria. Sign off with the PM, SWE, and DevOps before the build starts.
2. Copy `templates/CLAUDE.md` to the new project repo as `CLAUDE.md`. Edit all `[ ]` placeholders for the project's stack, hosting, and environments.
3. Work through the **New Project Init Checklist** inside that `CLAUDE.md` before any application code is written.
4. Install the skills (see above) so `/skills` and `/review-pr` are available from day one.

**During the trial:**

5. SWE reviews Claude's commits on an agreed cadence (daily async is the baseline). Running `/skills` at the end of each session is a lightweight way to surface violations before they accumulate. Log gaps as they emerge — don't wait for the end.

**Before merging any PR:**

6. SWE runs `/review-pr` on the PR branch. The skill rebases, scans, builds, and fixes violations — each fix committed separately. Only merge when `/review-pr` exits with no FAIL items.

**After the trial:**

7. Fill out `templates/trial-review.md`. Add the completed review to `trials/<project-name>/trial-review.md`.
8. Review the gaps log and update `templates/CLAUDE.md` with any new rules that would have prevented them. Update the skills if new automated checks are warranted.

---

## Contributing

- Completed trials go in `trials/<project-name>/`.
- When a gap pattern appears in more than one trial, extract it into `templates/CLAUDE.md` as a rule.
- Keep templates generalized — strip project-specific names, commit hashes, and org-specific tooling before committing to `templates/`.
- Dates in this repo use ISO format (YYYY-MM-DD).

---

## Trials

| Trial | Project | Period | Review |
|---|---|---|---|
| 1 | [SuMS](trials/sums/) | Feb–Mar 2026 | [Review](trials/sums/trial-review.md) |
