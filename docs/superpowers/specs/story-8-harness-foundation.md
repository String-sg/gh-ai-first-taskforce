# Spec: Harness Foundation — Local Hook Scaffolding (Issue #8)

**Issue:** #8  
**Status:** Implemented  
**Plan:** `docs/superpowers/plans/2026-05-20-harness-foundation-gh-extension-husky.md`

---

## Language detection

- `package.json` only → `js`
- `package.json` + `go.mod` → `mixed`
- `go.mod` only → `unsupported`
- Empty directory → `unsupported`

*Tests: `tests/harness/detect-language.bats`*

---

## Package manager detection

- `pnpm-lock.yaml` present → `pnpm`
- `bun.lockb` present → `bun`
- `bun.lock` present → `bun`
- `package-lock.json` only → `unsupported`
- No lockfile → `unsupported`

*Tests: `tests/harness/detect-package-manager.bats`*

---

## Hook file management

- `ensure_hook_exists`: creates the file with `#!/bin/sh` and executable permissions if absent
- `ensure_hook_exists`: leaves an existing file unchanged
- `merge_block` (append): appends a sentinel-wrapped block when the sentinel is absent
- `merge_block` (append): skips the block when its sentinel is already present
- `merge_block` (after-shebang): inserts the block after line 1, before existing content
- `merge_block` (after-shebang): is idempotent on repeated calls

*Tests: `tests/harness/merge-hook.bats`*

---

## Husky installation and initialisation

- `is_husky_installed`: returns false when `husky` key is absent from `package.json`
- `is_husky_installed`: returns true when `husky` key is present in `devDependencies`
- `ensure_husky_installed`: runs `pnpm add -D husky` when husky is absent (pnpm repo)
- `ensure_husky_installed`: runs `bun add -D husky` when husky is absent (bun repo)
- `ensure_husky_installed`: skips install when husky is already listed in `package.json`
- `ensure_husky_installed`: exits 1 with message when package manager is unsupported
- `ensure_husky_init`: runs `pnpm exec husky init` when `.husky/` is absent (pnpm repo)
- `ensure_husky_init`: runs `bunx husky init` when `.husky/` is absent (bun repo)
- `ensure_husky_init`: resets the sample `pre-commit` written by `husky init` to a bare `#!/bin/sh`
- `ensure_husky_init`: skips init when `.husky/` already exists (preserves existing hook content)

*Tests: `tests/harness/husky.bats`*

---

## Setup orchestration (`setup.sh`)

- Exits 1 with a clear message for pure Go repos (no `package.json`)
- Exits 1 with a clear message when no supported package manager lockfile is found
- Succeeds for a pnpm JS repo with existing hooks
- Succeeds for a bun JS repo with existing hooks
- Succeeds for a mixed (Go + JS) repo with existing hooks
- Merges the NVM preamble block into `.husky/pre-commit`
- Merges the NVM preamble block into `.husky/pre-push`
- Re-run does not duplicate the NVM block in `.husky/pre-commit`
- Re-run does not duplicate the NVM block in `.husky/pre-push`
- Preserves existing team hook content when merging

*Tests: `tests/harness/setup.bats`*
