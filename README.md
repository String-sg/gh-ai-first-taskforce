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

See [**AI-First Engineering Strategy**](docs/ai-first-engineering-strategy.md) for the practitioner roadmap and playbook — how teams move from AI-assisted to AI-first work, safely.

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
├── gh-ai-first-taskforce                Extension entry point — `gh ai-first-taskforce setup`
├── skills/                              Claude Code skills (aif-*) installed by the extension
│   ├── README.md                        Catalogue of installed skills
│   ├── aif-code-review/
│   ├── aif-create-issue/
│   ├── aif-git-hooks-setup/
│   ├── aif-implement-issue/
│   ├── aif-lint-setup/
│   ├── aif-split-issue/
│   └── aif-update-npm-dependencies/
├── docs/
│   └── ai-first-engineering-strategy.md  Adoption roadmap + build strategy
├── templates/
│   ├── CLAUDE.md                        Generalized CLAUDE.md — copy to a new project before build week
│   ├── trial-review.md                  Blank post-trial review template
│   ├── trial-goals.md                   Goals and success criteria template — fill in before each trial
│   └── skills/                          Legacy: copy-in stack/function review skills (superseded by aif-* skills)
└── trials/
    └── sums/                            Artifacts from Trial 1: SuMS (Feb–Mar 2026)
        ├── CLAUDE.md                    SuMS project rules (the source for templates/CLAUDE.md)
        ├── trial-review.md              SuMS post-trial review with gaps log
        └── skills/                      SuMS-specific skills (source for templates/skills/by-stack/nextjs-ts-prisma/)
```

---

## Skills

The taskforce ships Claude Code skills as a `gh` extension. Install them with `gh ai-first-taskforce setup` (see [Installation](#installation)) — they land in `~/.claude/skills/` and Claude Code picks them up automatically. Each skill is self-describing: its `SKILL.md` declares when to trigger, so there is no router to maintain.

See [`skills/README.md`](skills/README.md) for the full catalogue.

| Skill | What it does |
|---|---|
| `aif-create-issue` | Creates a well-structured GitHub issue with complete author and implementer sections for a coding agent to action. |
| `aif-split-issue` | Decomposes a GitHub issue into atomic child issues, each sized for a single coding-agent PR. |
| `aif-implement-issue` | Implements a GitHub issue given an issue number or pasted markdown body. |
| `aif-code-review` | Reviews code changes — inline PR comments or an interactive local branch review with an optional written report. |
| `aif-lint-setup` | Sets up linting and/or formatting (ESLint, oxlint, Biome, Prettier, oxfmt, golangci-lint, shellcheck) after auditing gaps. |
| `aif-git-hooks-setup` | Sets up or audits pre-commit and pre-push git hooks (Husky or Lefthook) for JS/TS, Go, shell, or mixed projects. |
| `aif-update-npm-dependencies` | Audits and updates vulnerable JS/TS dependencies across npm, pnpm, Yarn, and Bun with a 7-day release cooldown. |

For the strategy behind these skills — how teams adopt them, and how the toolkit itself is built — see [AI-First Engineering Strategy](docs/ai-first-engineering-strategy.md).

### Legacy: copy-in stack templates

Before the `gh` extension, review skills were distributed as copy-in templates under `templates/skills/`, organized by stack and by function with a `SKILLS.md` routing index (`pre-merge-audit` and `review-pr` for Next.js · TypeScript · Prisma). These are **superseded by the `aif-*` skills above** and kept for reference. To use one, copy its directory into a project's `.claude/skills/` and commit it.

---

## Running a new trial

**Before the build week:**

1. Fill out `templates/trial-goals.md` with the project context, what you want to learn, and success criteria. Sign off with the PM, SWE, and DevOps before the build starts.
2. Copy `templates/CLAUDE.md` to the new project repo as `CLAUDE.md`. Edit all `[ ]` placeholders for the project's stack, hosting, and environments.
3. Work through the **New Project Init Checklist** inside that `CLAUDE.md` before any application code is written.
4. Install the taskforce skills with `gh ai-first-taskforce setup` so the `aif-*` skills are available from day one.

**During the trial:**

5. SWE reviews Claude's commits on an agreed cadence (daily async is the baseline). Running `aif-code-review` at the end of each session is a lightweight way to surface violations before they accumulate. Log gaps as they emerge — don't wait for the end.

**Before merging any PR:**

6. SWE runs `aif-code-review` on the PR branch to scan for violations and capture findings before merge. Only merge once the findings are resolved.

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
