# Skills Index

## How to use this file

You are an agent helping a user set up or run code review skills for their project.

1. Check the user's project for the signals listed in the detection table below.
2. Match the first row in the routing table whose signals are all present.
3. Read and execute the SKILL.md at the listed path.

If the user describes their app by what it does rather than its tech stack, use the function-based routing table at the bottom instead.

If the user has asked for a specific skill by name (e.g. "run a pre-merge audit"), find the skill with that name inside the matched directory.

---

## Signal detection

Run these checks against the user's project root:

| Signal | Command |
|---|---|
| Has `package.json` | `ls package.json` |
| Has `prisma/` directory | `ls -d prisma/ 2>/dev/null` |
| Has `src/app/` directory (Next.js app router) | `ls -d src/app/ 2>/dev/null` |
| Has `next.config.*` | `ls next.config.* 2>/dev/null` |
| Has `manage.py` (Django) | `ls manage.py 2>/dev/null` |
| Has `requirements.txt` or `pyproject.toml` (Python) | `ls requirements.txt pyproject.toml 2>/dev/null` |
| Has `Gemfile` (Ruby/Rails) | `ls Gemfile 2>/dev/null` |
| Has `config/database.yml` (Rails) | `ls config/database.yml 2>/dev/null` |

---

## Routing table — by stack

Match the first row whose signals are all present.

| Stack | Signals required | Skill path |
|---|---|---|
| Next.js · TypeScript · Prisma · PostgreSQL | `package.json` + `prisma/` + `src/app/` + `next.config.*` | `by-stack/nextjs-ts-prisma/` |
| Next.js · TypeScript (no DB) | `package.json` + `src/app/` + `next.config.*`, no `prisma/` | `by-stack/nextjs-static/` *(coming soon)* |
| Django · Python · PostgreSQL | `manage.py` + `requirements.txt` or `pyproject.toml` | `by-stack/django-postgres/` *(coming soon)* |
| Rails · PostgreSQL | `Gemfile` + `config/database.yml` | `by-stack/rails-postgres/` *(coming soon)* |

> Skills marked *coming soon* do not yet exist. If your project matches one, contribute a skill or open an issue.

---

## Routing table — by function (for non-coders)

Use this table when the user describes what their app does rather than what it is built with. Each function-based skill declares its opinionated stack and adds architectural checks on top of the stack skill.

| App type | Opinionated stack | Skill path |
|---|---|---|
| Web app with user login and a database | Next.js · TypeScript · Prisma · PostgreSQL | `by-function/web-app-with-db/` |

---

## Available skills (by name)

Each stack or function directory contains these skill files:

| Skill | What it does |
|---|---|
| `pre-merge-audit` | Quick pass/fail checklist before opening a PR. Use before raising a PR or at the end of a build session. |
| `review-pr` | Full automated PR review: rebase onto main, scan for violations, run build and tests, fix each item in a separate commit. Use as the SWE's merge-readiness pass. |

---

## Fallback — no match found

Ask the user these questions in plain language:

1. What language is the project written in? (e.g. JavaScript, Python, Ruby)
2. Does the app store data in a database? (yes / no)
3. Is there a framework the app uses? (e.g. Next.js, Django, Rails — or "not sure")

Use the answers to match the routing table manually. If there is still no match, tell the user no skill exists yet for their stack and direct them to `templates/skills/by-stack/` to see what is available or to contribute a new one.
