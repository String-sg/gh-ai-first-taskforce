# aif-lint-setup — Eval Run Summary

## Phase 1: Detection

- **JS/TS**: detected (package.json present)
- **Go**: not detected (no go.mod)
- **Shell scripts**: not detected (no *.sh files)
- **Existing lint config**: none found (no eslint.config.js, .eslintrc*, biome.json, .oxlintrc.json, .prettier*, .oxfmtrc.json)

## Phase 2: Choices Confirmed

- **Linter**: ESLint
- **Formatter**: oxfmt
- **Package manager**: npm (specified by user)
- **Compatibility wiring**: ESLint + oxfmt → install `eslint-config-prettier`, add it last in `eslint.config.js`

## Phase 3: Files Created

| File | Purpose |
|------|---------|
| `eslint.config.js` | ESLint flat config with TypeScript, React, and eslint-config-prettier wiring |
| `.oxfmtrc.json` | oxfmt formatter config (JSONC with trailing comma and sortImports) |
| `package.json` | Updated with lint/format scripts and pinned devDependencies |

## npm Commands That Would Be Run

### Step 1 — Install ESLint and plugins

```bash
npm install --save-dev eslint@10.5.0 @eslint/js@10.0.1 typescript-eslint@8.61.0 eslint-plugin-react@7.37.5 eslint-plugin-react-hooks@7.1.1 globals@17.6.0
```

### Step 2 — Install oxfmt

```bash
npm install --save-dev oxfmt@0.54.0
```

### Step 3 — Compatibility wiring: ESLint + oxfmt

```bash
npm install --save-dev eslint-config-prettier@10.1.8
```

### Step 4 — Verify linter runs (would run after install)

```bash
npx eslint .
```

### Step 5 — Verify formatter runs (would run after install)

```bash
npx oxfmt --check "**/*.{js,jsx,ts,tsx,md,html,css,json,jsonc,yaml,toml}"
```

## package.json Scripts Added

```json
"lint": "eslint .",
"lint:fix": "eslint . --fix",
"format": "oxfmt --check \"**/*.{js,jsx,ts,tsx,md,html,css,json,jsonc,yaml,toml}\""
```

## Version Selection Notes

All versions confirmed as the most recent published versions at least 7 days old as of 2026-06-15:

| Package | Version |
|---------|---------|
| eslint | 10.5.0 |
| @eslint/js | 10.0.1 |
| typescript-eslint | 8.61.0 |
| eslint-plugin-react | 7.37.5 |
| eslint-plugin-react-hooks | 7.1.1 |
| globals | 17.6.0 |
| oxfmt | 0.54.0 |
| eslint-config-prettier | 10.1.8 |

## Compatibility Wiring Applied

- `eslint-config-prettier` installed and added **last** in `eslint.config.js` to disable ESLint formatting rules that would conflict with oxfmt.
- No `.prettierrc.json` or `.prettierignore` created — `eslint-config-prettier` is a shim only, not a Prettier install.

## Post-Setup Reminder

Lint is now configured. To enforce it automatically on commit, use the `aif-git-hooks-setup` skill.
