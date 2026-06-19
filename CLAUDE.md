# CLAUDE.md — AI-First Taskforce Repo

Rules for working in this repository. This repo is a knowledge base and a `gh` CLI extension — not an application repo.

---

## Purpose

This repo holds the AI-First Taskforce's shared body of knowledge for building software AI-first, in two forms:

- **Prose** — `CLAUDE.md` templates, trial artifacts, and long-form docs (the AI-First Engineering Strategy).
- **Skills** — the `aif-*` Claude Code skills under `skills/`, distributed via the `gh` extension. They are executable workflows *and* a form of documentation.

Capabilities and rules are **demand-driven**: derived from gaps and ideas that surface in real trials or active development projects — not built speculatively.

---

## File Organisation

- `skills/` — `aif-*` Claude Code skills installed by `gh ai-first-taskforce setup`. Each skill is a directory containing a `SKILL.md`; `skills/README.md` is the catalogue.
- `templates/` — Generalized, project-agnostic templates (`CLAUDE.md`, trial templates). No project-specific names, commit hashes, or org-specific tooling.
- `trials/<project-name>/` — Completed trial artifacts. These may be project-specific.
- `docs/` — Long-form documentation (e.g. the engineering strategy).
- `gh-ai-first-taskforce` — The `gh` extension entry point.
- `hooks/` — Git hook scripts wired up by Lefthook.
- `README.md` — Repo overview. `CONTRIBUTING.md` — how to contribute.

When adding a completed trial, create a new directory under `trials/` and add a row to the trials table in `README.md`.

---

## Skills

- Name each skill directory `aif-<name>`; the `name` in the `SKILL.md` frontmatter must match the directory name.
- Write the `description` for triggering — state precisely when an agent should use the skill.
- Register every skill in `skills/README.md` (the `setup` command installs every skill directory it finds; there is no central router).
- Keep skills generalized — no project-specific names or org-specific tooling.
- Eval artifacts are generated locally and gitignored — never commit them. skill-creator writes them to `skills/<skill>-workspace/` (a sibling of the skill directory).

See `CONTRIBUTING.md` for the full contribution workflow and the skill quality bar.

---

## Keeping Templates Generalized

When updating `templates/CLAUDE.md` or `templates/trial-review.md`:

- Replace any project-specific names, commit hashes, or org-specific tooling with `[ ]` placeholders.
- If a rule is derived from a specific trial's gaps log (or an active project), cite the source (e.g. `# derived from SuMS S1`) in a comment above the rule — but the rule itself must be general.
- Do not add rules that only apply to one project's stack.

---

## Dates

Use ISO format (YYYY-MM-DD) for all dates in this repo.

---

## Git Workflow

- **Never push directly to `main`** — it is blocked by the pre-push hook. Open a pull request.
- Branch names follow `<type>/<short-kebab-summary>` (e.g. `feat/…`, `fix/…`, `docs/…`, `chore/…`).
- Commit messages follow [Conventional Commits](https://www.conventionalcommits.org/). Keep unrelated concerns in separate commits.

**Exception:** `sample/typescript-app/` is a TypeScript app used to test the skills in `skills/`. Application code is permitted inside that directory only.

---

## No Application Code

This is a documentation and skills repo. Do not add `package.json`, build tooling, or application code. Markdown and plain text only — except the shell scripts noted below.

---

## Shell Scripts

Shell scripts are permitted only in these locations:

- `gh-ai-first-taskforce` — the `gh` extension entry point (repo root).
- `hooks/` — git hook scripts.

Do not add `package.json`, build tooling, or non-shell application code outside of these locations.
