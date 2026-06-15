# Lint Setup Summary — ESLint + oxfmt (npm)

## Phase 1: Detection

- **JS/TS detected:** `package.json` present.
- **Go detected:** No (`go.mod` not found).
- **Shell scripts detected:** No (`*.sh` files not found).
- **Existing lint config:** None found. No `eslint.config.js`, `.eslintrc*`, `biome.json`, `.oxlintrc.json`, `.prettier*`, or `.oxfmtrc.json` present.

## Phase 2: Plan Confirmed

User requested:
- **Linter:** ESLint
- **Formatter:** oxfmt
- **Package manager:** npm (user-stated; no lockfile present to detect automatically)

Compatibility wiring required: ESLint + oxfmt → install `eslint-config-prettier` and add `prettier` last in `eslint.config.js`.

## Phase 3: Install and Configure

### Package manager: npm

**Version selection:** Checked npm registry for most recent versions published at least 7 days before 2026-06-15.

### Step 1 — Install ESLint and plugins

```bash
npm install --save-dev eslint@10.5.0 @eslint/js@10.0.1 typescript-eslint@8.61.0 eslint-plugin-react@7.37.5 eslint-plugin-react-hooks@7.1.1 globals@17.6.0
```

### Step 2 — Install oxfmt

```bash
npm install --save-dev oxfmt@0.54.0
```

### Step 3 — Compatibility wiring (ESLint + oxfmt)

Install `eslint-config-prettier` to disable ESLint formatting rules that would conflict with oxfmt:

```bash
npm install --save-dev eslint-config-prettier@10.1.8
```

### Step 4 — Run linter to verify

```bash
npx eslint .
```

### Step 5 — Run formatter check to verify

```bash
npx oxfmt --check "**/*.{js,jsx,ts,tsx,md,html,css,json,jsonc,yaml,toml}"
```

## Files Created

| File | Purpose |
|------|---------|
| `eslint.config.js` | ESLint flat config with TypeScript, React, and react-hooks rules; `eslint-config-prettier` applied last |
| `.oxfmtrc.json` | oxfmt formatter config (printWidth 100, singleQuote, trailingComma all, sortImports) |
| `package.json` | Updated with `lint`, `lint:fix`, and `format` scripts; all devDependencies pinned |

## package.json Scripts Added

```json
"lint": "eslint .",
"lint:fix": "eslint . --fix",
"format": "oxfmt --check \"**/*.{js,jsx,ts,tsx,md,html,css,json,jsonc,yaml,toml}\""
```

## Post-Setup Reminder

Lint is now configured. To enforce it automatically on commit, use the `aif-git-hooks-setup` skill.
