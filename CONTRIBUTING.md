# Contributing

Thanks for contributing to the AI-First Taskforce repo. This repo is the taskforce's shared body of knowledge for building software AI-first, captured in two complementary forms:

- **Prose** — the [AI-First Engineering Strategy](docs/ai-first-engineering-strategy.md), `CLAUDE.md` templates, and trial artifacts.
- **Skills** — the `aif-*` Claude Code skills under `skills/`. These are executable workflows *and* a form of documentation: each one encodes a best practice precisely enough for an agent to carry it out.

The skills are distributed as a **`gh` CLI extension** — running `gh ai-first-taskforce setup` installs them into the contributor's own `~/.claude/skills/`, so they're available to Claude Code in any project. The extension is just the delivery mechanism; the skills are the substance.

Most contributions are prose, templates, or skills — not application code. This guide covers the *how*; [`CLAUDE.md`](CLAUDE.md) is the source of truth for the repo's *rules* — please read it before you start.

The thinking behind how the toolkit is built — where capabilities come from and why — lives in **Section 6 of the [strategy doc](docs/ai-first-engineering-strategy.md)**. A worthwhile read before adding a skill.

---

## Ways to contribute

| Contribution | Where it lives |
|---|---|
| A new Claude Code skill | `skills/aif-<name>/` |
| Improving an existing skill | `skills/aif-<name>/` |
| `CLAUDE.md` rules / templates | `templates/` |
| A completed trial's artifacts | `trials/<project-name>/` |
| The `gh` extension or git hooks | `gh-ai-first-taskforce`, `hooks/` |
| Docs (README, strategy, this guide) | repo root, `docs/` |

Capabilities should be **demand-driven**: sourced from a real gap or idea that surfaced in a trial *or* an active development project — not built speculatively. See the strategy doc's capability lifecycle for the full picture.

---

## Start with an issue

For anything beyond a trivial fix, **open a GitHub issue before you start working.** It lets maintainers confirm the change is wanted, prevents two people building the same thing, and is the right place to agree scope before any code or docs are written.

- **Search existing issues first** — the gap or idea may already be tracked. If it is, comment to say you're picking it up.
- **Describe the gap or idea, not just the solution** — what surfaced it (a trial, an active project) and what a good outcome looks like.
- **Use the toolkit to draft it.** The `aif-create-issue` skill produces a well-structured issue with author and implementer sections a coding agent can act on. For a large piece of work, `aif-split-issue` decomposes it into atomic child issues, each sized for a single PR.
- **Reference the issue** from your branch and PR (e.g. `Closes #123`) so the work is traceable end to end.

Trivial fixes — typos, broken links, obvious doc corrections — can skip straight to a PR.

---

## Development setup

1. **Fork and clone** the repo (or branch directly if you have write access).
2. **Install the git hooks** (required — they enforce secret scanning and branch protection):

   ```sh
   brew install lefthook gitleaks
   lefthook install
   ```

   This activates:
   - **pre-commit** — scans staged changes for secrets via `gitleaks`.
   - **pre-push** — blocks direct pushes to `main`; open a pull request instead.

No build step, package manager, or dependencies — this repo is Markdown and shell only.

---

## Repo layout

```
gh-ai-first-taskforce            Extension entry point — `gh ai-first-taskforce setup`
skills/                          aif-* Claude Code skills (the distributed toolkit)
  └── README.md                  Catalogue — keep in sync when adding/removing a skill
templates/                       Generalized CLAUDE.md + trial templates
trials/<project-name>/           Completed trial artifacts (may be project-specific)
docs/                            Strategy and long-form docs
hooks/                           Git hook scripts wired up by Lefthook
```

---

## Branching and commits

- **Never push to `main`.** It's enforced by the pre-push hook. All changes land through a pull request.
- **Branch names** follow `<type>/<short-kebab-summary>`, e.g. `feat/aif-deploy-checklist`, `fix/gh-extension-install`, `docs/contributing-guide`.
- **Commit messages** follow [Conventional Commits](https://www.conventionalcommits.org/): `<type>(<optional scope>): <summary>`.

  Common types: `feat`, `fix`, `chore`, `docs`.

  ```
  feat(aif-create-issue): support native GitHub issue relationships
  docs: add AI-first engineering strategy
  chore: remove obsolete bats tests for deleted harness
  ```
- **Separate unrelated concerns into separate commits** — a reviewer should be able to read one commit and understand one change.
- Dogfood the toolkit: use `aif-create-issue` to scope work, and `aif-code-review` when reviewing a PR (it posts findings as inline comments).

---

## Contributing a skill

A skill is a single directory under `skills/` containing a `SKILL.md` with YAML frontmatter:

```markdown
---
name: aif-<name>
description: Use when … — describe precisely when an agent should trigger this skill.
---

<the skill body: the workflow the agent follows>
```

Guidelines:

- **Prefix the directory `aif-`** so it's namespaced when installed into `~/.claude/skills/`. The `name` must match the directory name.
- **Write the `description` for triggering.** It is the only thing an agent sees when deciding whether to use the skill, so state the situations and trigger phrases explicitly. Don't over-trigger on unrelated requests.
- **Follow an existing skill's structure** (e.g. any `skills/aif-*` directory) for tone and layout.
- **Register it in [`skills/README.md`](skills/README.md)** so the catalogue stays current. The `setup` command installs every skill directory it finds — no central router to update.

### The quality bar

Before a skill ships it must clear this bar:

- **Evals pass, with variance analysis** to confirm the result is stable across runs, not a lucky single pass. The `skill-creator` skill helps build, eval, and tune a skill's triggering.
- **Generalized** — no project-specific names, commit hashes, or org-specific tooling. Replace specifics with `[ ]` placeholders.
- **Passes the repo gates** — gitleaks pre-commit and human review.

> Eval artifacts are generated locally and **not** committed — they're gitignored. skill-creator writes them to `skills/<skill>-workspace/` (a sibling of the skill directory); don't add those directories to your PR.

---

## Contributing templates and rules

When editing `templates/CLAUDE.md` or other templates (see the rules in [`CLAUDE.md`](CLAUDE.md) → *Keeping Templates Generalized*):

- Replace project-specific names, commit hashes, and org-specific tooling with `[ ]` placeholders.
- If a rule is derived from a specific trial's gaps log, cite the gap ID in a comment above it (e.g. `# derived from SuMS S1`) — but the rule itself must be general.
- Don't add rules that only apply to one project's stack.

---

## Contributing a trial

1. Add the completed artifacts under `trials/<project-name>/`.
2. Add a row to the trials table in [`README.md`](README.md).
3. Review the trial's gaps log: when a gap pattern shows up in more than one trial — or recurs in active projects — extract it into `templates/CLAUDE.md` as a generalized rule, or into a skill as an automated check.

---

## Conventions

- **Dates** use ISO format (`YYYY-MM-DD`).
- **No application code.** Markdown and plain text only, except shell scripts for the `gh` extension entry point and git hooks. Do not add `package.json`, build tooling, or other application code.
- **Never commit secrets.** `.env` files, API keys, and tokens stay out of the repo; gitleaks will block obvious leaks, but it's not a substitute for care.
- **Keep templates generalized.** Strip anything project-specific before it lands in `templates/`.

---

## Opening a pull request

1. Push your branch and open a PR against `main`.
2. Describe **what** changed and **why** — link the issue or the gap/idea that motivated it.
3. Make sure the hooks pass (gitleaks clean; you're on a feature branch, not `main`).
4. Keep the PR focused; smaller, single-concern PRs review faster.

A maintainer will review. For skills, expect questions about the description's triggering behaviour and the evals — that's the bar that keeps the toolkit trustworthy.

Thank you for helping the toolkit compound. 🙌
