# AI-First Taskforce

The AI-First Taskforce's shared body of knowledge for building production software AI-first. It's captured in two complementary forms:

- **Prose** — best practices, `CLAUDE.md` templates, trial artifacts, and the [AI-First Engineering Strategy](docs/ai-first-engineering-strategy.md).
- **Skills** — the `aif-*` Claude Code skills under `skills/`: executable workflows *and* a form of documentation, each encoding a best practice precisely enough for an agent to carry it out.

The skills are delivered as a `gh` CLI extension that installs them into your own Claude Code (`~/.claude/skills/`) — see [Installation](#installation).

---

## Installation

Install as a `gh` CLI extension:

```sh
gh extension install String-sg/gh-ai-first-taskforce
```

Then run setup to install the taskforce's Claude Code skills into `~/.claude/skills/`:

```sh
gh ai-first-taskforce setup
```

Skills are available to Claude Code automatically once installed. To get the latest skills after an extension update:

```sh
gh extension upgrade gh-ai-first-taskforce && gh ai-first-taskforce setup
```

---

## Goals

The AI-First Taskforce aims to increase developer productivity through practical application of generative AI in software engineering workflows.

See [**AI-First Engineering Strategy**](docs/ai-first-engineering-strategy.md) — how AI modernizes software engineering: the progression from ad-hoc AI use to structured agentic software engineering, and how teams adopt it safely.

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
├── lefthook.yml                         Lefthook config — pre-commit secret scan, pre-push main protection
├── hooks/                               Git hook scripts wired up by Lefthook
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
│   └── ai-first-engineering-strategy.md  How AI modernizes engineering — the progression and toolkit
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

See [`skills/README.md`](skills/README.md) for the catalogue of installed skills — the single source of truth, kept in sync as skills are added or removed.

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

See **[CONTRIBUTING.md](CONTRIBUTING.md)** for the full guide — ways to contribute, the issue-first workflow, local setup (installing the git hooks), branching and Conventional Commits, how to add a skill and the quality bar, and the PR flow.

---

## Trials

| Trial | Project | Period | Review |
|---|---|---|---|
| 1 | [SuMS](trials/sums/) | Feb–Mar 2026 | [Review](trials/sums/trial-review.md) |
