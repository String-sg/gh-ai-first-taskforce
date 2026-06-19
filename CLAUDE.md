# CLAUDE.md — AI-First Taskforce Repo

Rules for working in this repository. This repo is a documentation and templates repo, not an application repo.

---

## Purpose

This repo holds knowledge artifacts from the AI-First Taskforce: trial reviews, generalized templates, and best-practice rules derived from real project trials.

---

## File Organisation

- `templates/` — Generalized, project-agnostic templates. No project-specific names, commit hashes, or org-specific tooling.
- `trials/<project-name>/` — Completed trial artifacts. These may be project-specific.
- `README.md` — Repo overview and instructions for running a new trial.

When adding a completed trial, create a new directory under `trials/` and add a row to the trials table in `README.md`.

---

## Keeping Templates Generalized

When updating `templates/CLAUDE.md` or `templates/trial-review.md`:

- Replace any project-specific names, commit hashes, or org-specific tooling with `[ ]` placeholders.
- If a new rule is derived from a specific trial's gaps log, cite the gap ID (e.g. `# derived from SuMS S1`) in a comment above the rule — but the rule itself must be general.
- Do not add rules that only apply to one project's stack.

---

## Dates

Use ISO format (YYYY-MM-DD) for all dates in this repo.

---

## No Application Code

This is a documentation repo. Do not add `package.json`, build tooling, or application code. Markdown and plain text only.

**Exception:** `sample/typescript-app/` is a TypeScript app used to test the skills in `skills/`. Application code is permitted inside that directory only.

---

## Shell Scripts (gh Extension)

This repo doubles as a `gh` CLI extension. Shell scripts are permitted in these locations:

- `gh-ai-first-taskforce` — extension entry point (repo root)
- `harness/` — setup scripts and helpers
- `tests/` — bats-based tests for harness scripts
- `tests/mocks/` — stub binaries used during shell testing

Do not add `package.json`, build tooling, or non-shell application code outside of these locations.
