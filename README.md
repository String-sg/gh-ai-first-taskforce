# AI-First Taskforce

Knowledge repository for the AI-First Taskforce. This repo collects best practices, templates, and lessons learned from trials where non-engineer practitioners build production software with Claude Code.

---

## Installation

Install as a `gh` CLI extension:

```sh
gh extension install transformteamsg/gh-ai-first-taskforce
```

Then run setup to install the taskforce's Claude Code skills into `~/.claude/skills/`:

```sh
gh ai-first-taskforce setup
```

Skills are available to Claude Code automatically once installed. To get the latest skills after an extension update:

```sh
gh extension upgrade ai-first-taskforce && gh ai-first-taskforce setup
```

---

## Goals

The AI-First Taskforce aims to increase developer productivity through practical application of generative AI in software engineering workflows.

### Ongoing projects

| Project | Description |
|---|---|
| Templatized skills (this repo) | Reusable Claude Code skills and CLAUDE.md templates that any team can adopt, derived from real project trials. |
| [Personal data detection](https://github.com/String-sg/personal-data-detection-tools) | Tooling to detect personal data in codebases and datasets before they reach production or external services. |

### Ideas under exploration

**Local codebase sensitivity scanner**

Scan a local codebase using a local LLM — no data leaves the device — to determine its sensitivity and information classification. The output determines which deployment environment the project is eligible for (Greenlane OPEN, OFFICIAL, or OFFICIAL-CLOSED), without risking data exposure during the scan itself.

**Data masking for restricted projects**

For projects that cannot be deployed to commercial or cloud LLM environments, explore an LLM-assisted pipeline to mask sensitive data and copywriting before it reaches an external model — expanding the scope of projects that can benefit from AI tooling without compromising data handling requirements.

---

## What's here

```
gh-ai-first-taskforce/
├── templates/
│   ├── CLAUDE.md                        Generalized CLAUDE.md — copy to a new project before build week
│   ├── trial-review.md                  Blank post-trial review template
│   ├── trial-goals.md                   Goals and success criteria template — fill in before each trial
│   └── skills/
│       ├── SKILLS.md                    Agent-readable routing index — start here to find the right skill
│       ├── by-stack/
│       │   └── nextjs-ts-prisma/
│       │       ├── pre-merge-audit/     Pre-merge checklist for Next.js + TypeScript + Prisma projects
│       │       └── review-pr/           Full PR review workflow for Next.js + TypeScript + Prisma projects
│       └── by-function/
│           └── web-app-with-db/         Opinionated skill set for web apps with a database (uses nextjs-ts-prisma)
└── trials/
    └── sums/                            Artifacts from Trial 1: SuMS (Feb–Mar 2026)
        ├── CLAUDE.md                    SuMS project rules (the source for templates/CLAUDE.md)
        ├── trial-review.md              SuMS post-trial review with gaps log
        └── skills/                      SuMS-specific skills (source for templates/skills/by-stack/nextjs-ts-prisma/)
            ├── pre-merge-audit/
            ├── review-pr/
            └── run-local/
```

---

## Skills

`templates/skills/` contains Claude Code skills for automated code review. Skills are organized in two ways — by stack (for experienced developers who know their tech) and by function (for non-coders who know what their app does).

### Finding the right skill

The easiest way is to ask your agent to read `templates/skills/SKILLS.md`. It will inspect your project, detect the stack from observable signals, and load the matching skill automatically.

If you know your stack, go directly to `templates/skills/by-stack/<your-stack>/`.

### Installing skills in a project

Copy the matched skill directory into your project's `.claude/skills/` folder:

```bash
mkdir -p .claude/skills
cp -r path/to/gh-ai-first-taskforce/templates/skills/by-stack/nextjs-ts-prisma/pre-merge-audit .claude/skills/
cp -r path/to/gh-ai-first-taskforce/templates/skills/by-stack/nextjs-ts-prisma/review-pr .claude/skills/
```

Commit `.claude/skills/` to the project repo so skills are available to everyone.

> **One-time setup:** `review-pr/SKILL.md` Phase 5 references `[ path/to/trial-review.md ]`. Update this to wherever your project keeps its trial review document before using the skill.

### Available skills

| Skill | What it does |
|---|---|
| `pre-merge-audit` | Focused pass/fail audit before opening a PR. Checks husky hooks, secrets, code organisation, Prisma, raw SQL, infrastructure, and env var coverage. Output: a pass/fail table. Any FAIL on a Critical or High item blocks merge. |
| `review-pr` | Full PR review workflow. Rebases onto main, resolves conflicts, scans for violations, runs build and tests, documents new gap patterns, then fixes each item in a separate commit. Use as the SWE's merge-readiness pass. |

### Available stacks

| Stack | Path |
|---|---|
| Next.js · TypeScript · Prisma · PostgreSQL | `templates/skills/by-stack/nextjs-ts-prisma/` |

More stacks will be added as trials are completed. To contribute a new stack skill, follow the structure in `by-stack/nextjs-ts-prisma/` and open a PR.

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

### Setting up git hooks

This repo uses [Lefthook](https://github.com/evilmartians/lefthook) to manage git hooks. Run once after cloning:

```sh
brew install lefthook gitleaks
lefthook install
```

This activates:
- **pre-commit** — scans staged changes for secrets via gitleaks
- **pre-push** — blocks direct pushes to `main`; open a pull request instead

### Guidelines

- Completed trials go in `trials/<project-name>/`.
- When a gap pattern appears in more than one trial, extract it into `templates/CLAUDE.md` as a rule.
- Keep templates generalized — strip project-specific names, commit hashes, and org-specific tooling before committing to `templates/`.
- Dates in this repo use ISO format (YYYY-MM-DD).

---

## Trials

| Trial | Project | Period | Review |
|---|---|---|---|
| 1 | [SuMS](trials/sums/) | Feb–Mar 2026 | [Review](trials/sums/trial-review.md) |
