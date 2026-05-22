# Story 12 — Secrets Scanning (gitleaks) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a language-agnostic gitleaks pre-commit hook that scans staged files for secrets on every commit, covering JS/TS, mixed, and pure Go repos.

**Architecture:** A new `harness/lib/secrets.sh` module provides four shell functions: `ensure_gitleaks_available` (install gitleaks if absent), `ensure_gitleaks_config` (write a default `.gitleaks.toml`), `install_gitleaks_hook` (for Husky repos — appends the scan block to `.husky/pre-commit`), and `install_gitleaks_git_hook` (for pure Go repos — appends to `.git/hooks/pre-commit` directly). `setup.sh` calls the first two unconditionally, then routes to the appropriate hook installer based on repo language. All hook blocks follow the existing `# harness:<id>:begin/end` sentinel pattern via `merge_block`, making setup idempotent.

**Tech Stack:** POSIX sh, bats-core (tests), gitleaks v8 (runtime tool)

---

## File Map

| Action | Path | Responsibility |
|--------|------|----------------|
| Create | `harness/lib/secrets.sh` | All gitleaks functions |
| Create | `tests/harness/secrets.bats` | Unit tests for secrets.sh |
| Create | `tests/mocks/gitleaks` | Mock gitleaks binary (logs calls, exits 0) |
| Create | `tests/mocks/brew` | Mock brew binary (logs calls, exits 0) |
| Modify | `harness/setup.sh` | Source secrets.sh; call gitleaks functions |
| Modify | `tests/harness/setup.bats` | Integration tests for gitleaks in setup |
| Modify | `harness/README.md` | Document secrets scanning section |

---

## Task 1: Create mock binaries

**Files:**
- Create: `tests/mocks/gitleaks`
- Create: `tests/mocks/brew`

- [ ] **Step 1: Write `tests/mocks/gitleaks`**

```sh
#!/bin/sh
echo "mock-gitleaks $*" >> "${MOCK_LOG:-/tmp/mock-calls.log}"
exit 0
```

- [ ] **Step 2: Write `tests/mocks/brew`**

```sh
#!/bin/sh
echo "mock-brew $*" >> "${MOCK_LOG:-/tmp/mock-calls.log}"
exit 0
```

- [ ] **Step 3: Make both mocks executable**

```bash
chmod +x tests/mocks/gitleaks tests/mocks/brew
```

- [ ] **Step 4: Commit**

```bash
git add tests/mocks/gitleaks tests/mocks/brew
git commit -m "test: add gitleaks and brew mock binaries"
```

---

## Task 2: `ensure_gitleaks_available` — tests then implementation

**Files:**
- Create: `tests/harness/secrets.bats` (new)
- Create: `harness/lib/secrets.sh` (skeleton + first function)

- [ ] **Step 1: Create the test file with the setup boilerplate and tests for `ensure_gitleaks_available`**

Create `tests/harness/secrets.bats`:

```bash
#!/usr/bin/env bats

setup() {
  source "$BATS_TEST_DIRNAME/../../harness/lib/merge-hook.sh"
  source "$BATS_TEST_DIRNAME/../../harness/lib/secrets.sh"
  REPO_DIR=$(mktemp -d)
  MOCK_LOG=$(mktemp)
  export MOCK_LOG
  MOCKS_DIR="$BATS_TEST_DIRNAME/../mocks"
}

teardown() {
  rm -rf "$REPO_DIR" "$MOCK_LOG"
}

# ── ensure_gitleaks_available ─────────────────────────────────────────────────

@test "ensure_gitleaks_available: returns 0 when gitleaks already in PATH" {
  export PATH="$MOCKS_DIR:$PATH"
  run ensure_gitleaks_available
  [ "$status" -eq 0 ]
}

@test "ensure_gitleaks_available: does not invoke brew when gitleaks already installed" {
  export PATH="$MOCKS_DIR:$PATH"
  ensure_gitleaks_available
  run grep "mock-brew" "$MOCK_LOG"
  [ "$status" -ne 0 ]
}

@test "ensure_gitleaks_available: installs via brew when gitleaks absent and brew present" {
  local fake_bin="$REPO_DIR/bin"
  mkdir -p "$fake_bin"
  cp "$MOCKS_DIR/brew" "$fake_bin/brew"
  export PATH="$fake_bin"
  ensure_gitleaks_available || true
  grep -q "mock-brew install gitleaks" "$MOCK_LOG"
}

@test "ensure_gitleaks_available: installs via go when gitleaks absent, brew absent, go present" {
  export PATH="$MOCKS_DIR:$PATH"
  local fake_bin="$REPO_DIR/bin"
  mkdir -p "$fake_bin"
  # put go mock in path but not gitleaks or brew
  cp "$MOCKS_DIR/go" "$fake_bin/go"
  # override PATH so gitleaks and brew are not found, but go is
  export PATH="$fake_bin"
  ensure_gitleaks_available || true
  grep -q "mock-go install github.com/zricethezav/gitleaks/v8@latest" "$MOCK_LOG"
}

@test "ensure_gitleaks_available: returns 1 with ERROR when gitleaks absent and no installer available" {
  local empty="$REPO_DIR/empty"
  mkdir -p "$empty"
  export PATH="$empty"
  run ensure_gitleaks_available
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR"* ]]
}

@test "ensure_gitleaks_available: error message includes brew install command" {
  local empty="$REPO_DIR/empty"
  mkdir -p "$empty"
  export PATH="$empty"
  run ensure_gitleaks_available
  [[ "$output" == *"brew install gitleaks"* ]]
}

@test "ensure_gitleaks_available: error message includes go install command" {
  local empty="$REPO_DIR/empty"
  mkdir -p "$empty"
  export PATH="$empty"
  run ensure_gitleaks_available
  [[ "$output" == *"go install"*"gitleaks"* ]]
}
```

- [ ] **Step 2: Run the tests to confirm they fail (secrets.sh does not exist yet)**

```bash
bats tests/harness/secrets.bats 2>&1 | head -20
```

Expected: errors about `secrets.sh` not found or function not defined.

- [ ] **Step 3: Create `harness/lib/secrets.sh` with `ensure_gitleaks_available`**

```sh
# Requires merge_block() and ensure_hook_exists() from merge-hook.sh to be sourced first.

# ensure_gitleaks_available
# Returns 0 if gitleaks is in PATH. Tries brew, then go install.
# Prints an actionable error and returns 1 if no installer is available.
ensure_gitleaks_available() {
  if command -v gitleaks >/dev/null 2>&1; then
    return 0
  fi

  if command -v brew >/dev/null 2>&1; then
    if ! brew install gitleaks; then
      echo "ERROR: brew install gitleaks failed. Install manually:" >&2
      echo "  brew install gitleaks" >&2
      return 1
    fi
    return 0
  fi

  if command -v go >/dev/null 2>&1; then
    if ! go install github.com/zricethezav/gitleaks/v8@latest; then
      echo "ERROR: go install gitleaks failed. Install manually:" >&2
      echo "  go install github.com/zricethezav/gitleaks/v8@latest" >&2
      return 1
    fi
    return 0
  fi

  echo "ERROR: gitleaks not found and could not be installed automatically." >&2
  echo "  macOS:  brew install gitleaks" >&2
  echo "  other:  go install github.com/zricethezav/gitleaks/v8@latest" >&2
  echo "  manual: https://github.com/gitleaks/gitleaks#installing" >&2
  return 1
}
```

- [ ] **Step 4: Run the tests and verify they pass**

```bash
bats tests/harness/secrets.bats 2>&1
```

Expected: all 7 tests pass.

- [ ] **Step 5: Commit**

```bash
git add harness/lib/secrets.sh tests/harness/secrets.bats
git commit -m "feat: add ensure_gitleaks_available with brew/go auto-install"
```

---

## Task 3: `ensure_gitleaks_config` — tests then implementation

**Files:**
- Modify: `tests/harness/secrets.bats`
- Modify: `harness/lib/secrets.sh`

- [ ] **Step 1: Append tests for `ensure_gitleaks_config` to `tests/harness/secrets.bats`**

Add after the existing tests:

```bash
# ── ensure_gitleaks_config ────────────────────────────────────────────────────

@test "ensure_gitleaks_config: creates .gitleaks.toml when none exists" {
  ensure_gitleaks_config "$REPO_DIR"
  [ -f "$REPO_DIR/.gitleaks.toml" ]
}

@test "ensure_gitleaks_config: created config contains useDefault = true" {
  ensure_gitleaks_config "$REPO_DIR"
  grep -q "useDefault = true" "$REPO_DIR/.gitleaks.toml"
}

@test "ensure_gitleaks_config: created config contains allowlist comment guidance" {
  ensure_gitleaks_config "$REPO_DIR"
  grep -q "allowlist" "$REPO_DIR/.gitleaks.toml"
}

@test "ensure_gitleaks_config: skips when .gitleaks.toml already exists" {
  printf 'title = "custom"\n' > "$REPO_DIR/.gitleaks.toml"
  ensure_gitleaks_config "$REPO_DIR"
  run grep "useDefault" "$REPO_DIR/.gitleaks.toml"
  [ "$status" -ne 0 ]
}

@test "ensure_gitleaks_config: is idempotent — does not modify existing config" {
  printf 'title = "custom"\n' > "$REPO_DIR/.gitleaks.toml"
  ensure_gitleaks_config "$REPO_DIR"
  ensure_gitleaks_config "$REPO_DIR"
  [ "$(wc -l < "$REPO_DIR/.gitleaks.toml")" = "1" ]
}
```

- [ ] **Step 2: Run the tests to confirm they fail**

```bash
bats tests/harness/secrets.bats 2>&1 | grep -E "not ok|FAILED"
```

Expected: 5 new failures for `ensure_gitleaks_config`.

- [ ] **Step 3: Implement `ensure_gitleaks_config` in `harness/lib/secrets.sh`**

Append to `harness/lib/secrets.sh`:

```sh
# ensure_gitleaks_config <repo_root>
# Writes a default .gitleaks.toml if none exists.
ensure_gitleaks_config() {
  local repo_root="$1"

  if [ -f "$repo_root/.gitleaks.toml" ]; then
    return 0
  fi

  cat > "$repo_root/.gitleaks.toml" <<'EOF'
title = "gitleaks config"

[extend]
useDefault = true

# To allowlist a false positive, add an entry below:
# [allowlist]
# description = "describe what is being allowed"
# paths = ['''path/to/false-positive-file''']
# regexes = ['''EXAMPLE_PLACEHOLDER_[A-Z0-9]+''']
EOF

  echo "Created default .gitleaks.toml"
}
```

- [ ] **Step 4: Run all tests and verify they pass**

```bash
bats tests/harness/secrets.bats 2>&1
```

Expected: all 12 tests pass.

- [ ] **Step 5: Commit**

```bash
git add harness/lib/secrets.sh tests/harness/secrets.bats
git commit -m "feat: add ensure_gitleaks_config — writes default .gitleaks.toml"
```

---

## Task 4: `install_gitleaks_hook` (Husky) — tests then implementation

**Files:**
- Modify: `tests/harness/secrets.bats`
- Modify: `harness/lib/secrets.sh`

- [ ] **Step 1: Append tests for `install_gitleaks_hook` to `tests/harness/secrets.bats`**

```bash
# ── install_gitleaks_hook ─────────────────────────────────────────────────────

@test "install_gitleaks_hook: merges harness:gitleaks:begin sentinel into pre-commit" {
  mkdir -p "$REPO_DIR/.husky"
  printf '#!/bin/sh\n' > "$REPO_DIR/.husky/pre-commit"
  chmod +x "$REPO_DIR/.husky/pre-commit"
  install_gitleaks_hook "$REPO_DIR"
  grep -q "# harness:gitleaks:begin" "$REPO_DIR/.husky/pre-commit"
}

@test "install_gitleaks_hook: pre-commit contains gitleaks protect --staged" {
  mkdir -p "$REPO_DIR/.husky"
  printf '#!/bin/sh\n' > "$REPO_DIR/.husky/pre-commit"
  chmod +x "$REPO_DIR/.husky/pre-commit"
  install_gitleaks_hook "$REPO_DIR"
  grep -q "gitleaks protect --staged" "$REPO_DIR/.husky/pre-commit"
}

@test "install_gitleaks_hook: pre-commit checks command -v gitleaks at runtime" {
  mkdir -p "$REPO_DIR/.husky"
  printf '#!/bin/sh\n' > "$REPO_DIR/.husky/pre-commit"
  chmod +x "$REPO_DIR/.husky/pre-commit"
  install_gitleaks_hook "$REPO_DIR"
  grep -q "command -v gitleaks" "$REPO_DIR/.husky/pre-commit"
}

@test "install_gitleaks_hook: pre-commit error message includes install command" {
  mkdir -p "$REPO_DIR/.husky"
  printf '#!/bin/sh\n' > "$REPO_DIR/.husky/pre-commit"
  chmod +x "$REPO_DIR/.husky/pre-commit"
  install_gitleaks_hook "$REPO_DIR"
  grep -q "brew install gitleaks" "$REPO_DIR/.husky/pre-commit"
}

@test "install_gitleaks_hook: pre-commit output includes next-steps guidance on failure" {
  mkdir -p "$REPO_DIR/.husky"
  printf '#!/bin/sh\n' > "$REPO_DIR/.husky/pre-commit"
  chmod +x "$REPO_DIR/.husky/pre-commit"
  install_gitleaks_hook "$REPO_DIR"
  grep -q "allowlist" "$REPO_DIR/.husky/pre-commit"
}

@test "install_gitleaks_hook: pre-commit output mentions rotating credentials on failure" {
  mkdir -p "$REPO_DIR/.husky"
  printf '#!/bin/sh\n' > "$REPO_DIR/.husky/pre-commit"
  chmod +x "$REPO_DIR/.husky/pre-commit"
  install_gitleaks_hook "$REPO_DIR"
  grep -q "[Rr]otat" "$REPO_DIR/.husky/pre-commit"
}

@test "install_gitleaks_hook: is idempotent on re-run" {
  mkdir -p "$REPO_DIR/.husky"
  printf '#!/bin/sh\n' > "$REPO_DIR/.husky/pre-commit"
  chmod +x "$REPO_DIR/.husky/pre-commit"
  install_gitleaks_hook "$REPO_DIR"
  install_gitleaks_hook "$REPO_DIR"
  [ "$(grep -c "harness:gitleaks:begin" "$REPO_DIR/.husky/pre-commit")" = "1" ]
}
```

- [ ] **Step 2: Run failing tests**

```bash
bats tests/harness/secrets.bats 2>&1 | grep -E "not ok|FAILED"
```

Expected: 7 failures for `install_gitleaks_hook`.

- [ ] **Step 3: Implement `install_gitleaks_hook` in `harness/lib/secrets.sh`**

Append to `harness/lib/secrets.sh`:

```sh
# _gitleaks_hook_block
# Outputs the harness:gitleaks pre-commit block content.
_gitleaks_hook_block() {
  cat <<'BLOCK'
# harness:gitleaks:begin
if ! command -v gitleaks >/dev/null 2>&1; then
  echo "ERROR: gitleaks not found. Install it and re-run: gh ai-first-taskforce setup" >&2
  echo "  macOS:  brew install gitleaks" >&2
  echo "  other:  go install github.com/zricethezav/gitleaks/v8@latest" >&2
  exit 1
fi
if [ -f .gitleaks.toml ]; then
  gitleaks protect --staged --config .gitleaks.toml || {
    echo "" >&2
    echo "Secret detected. Next steps:" >&2
    echo "  - False positive? Add an [[allowlist]] entry to .gitleaks.toml" >&2
    echo "  - Real credential? Rotate it immediately — do not push" >&2
    exit 1
  }
else
  gitleaks protect --staged || {
    echo "" >&2
    echo "Secret detected. Next steps:" >&2
    echo "  - False positive? Add an [[allowlist]] entry to .gitleaks.toml" >&2
    echo "  - Real credential? Rotate it immediately — do not push" >&2
    exit 1
  }
fi
# harness:gitleaks:end
BLOCK
}

# install_gitleaks_hook <repo_root>
# Merges the gitleaks pre-commit block into .husky/pre-commit.
install_gitleaks_hook() {
  local repo_root="$1"
  merge_block "$repo_root/.husky/pre-commit" "gitleaks" "$(_gitleaks_hook_block)" "append"
}
```

- [ ] **Step 4: Run all tests**

```bash
bats tests/harness/secrets.bats 2>&1
```

Expected: all 19 tests pass.

- [ ] **Step 5: Commit**

```bash
git add harness/lib/secrets.sh tests/harness/secrets.bats
git commit -m "feat: add install_gitleaks_hook — gitleaks pre-commit block for Husky repos"
```

---

## Task 5: `install_gitleaks_git_hook` (pure Go) — tests then implementation

**Files:**
- Modify: `tests/harness/secrets.bats`
- Modify: `harness/lib/secrets.sh`

- [ ] **Step 1: Append tests for `install_gitleaks_git_hook` to `tests/harness/secrets.bats`**

```bash
# ── install_gitleaks_git_hook ─────────────────────────────────────────────────

@test "install_gitleaks_git_hook: creates .git/hooks/pre-commit if absent" {
  mkdir -p "$REPO_DIR/.git"
  install_gitleaks_git_hook "$REPO_DIR"
  [ -f "$REPO_DIR/.git/hooks/pre-commit" ]
}

@test "install_gitleaks_git_hook: .git/hooks/pre-commit is executable" {
  mkdir -p "$REPO_DIR/.git"
  install_gitleaks_git_hook "$REPO_DIR"
  [ -x "$REPO_DIR/.git/hooks/pre-commit" ]
}

@test "install_gitleaks_git_hook: merges harness:gitleaks:begin sentinel" {
  mkdir -p "$REPO_DIR/.git/hooks"
  printf '#!/bin/sh\n' > "$REPO_DIR/.git/hooks/pre-commit"
  chmod +x "$REPO_DIR/.git/hooks/pre-commit"
  install_gitleaks_git_hook "$REPO_DIR"
  grep -q "# harness:gitleaks:begin" "$REPO_DIR/.git/hooks/pre-commit"
}

@test "install_gitleaks_git_hook: hook contains gitleaks protect --staged" {
  mkdir -p "$REPO_DIR/.git"
  install_gitleaks_git_hook "$REPO_DIR"
  grep -q "gitleaks protect --staged" "$REPO_DIR/.git/hooks/pre-commit"
}

@test "install_gitleaks_git_hook: is idempotent on re-run" {
  mkdir -p "$REPO_DIR/.git"
  install_gitleaks_git_hook "$REPO_DIR"
  install_gitleaks_git_hook "$REPO_DIR"
  [ "$(grep -c "harness:gitleaks:begin" "$REPO_DIR/.git/hooks/pre-commit")" = "1" ]
}

@test "install_gitleaks_git_hook: preserves existing hook content" {
  mkdir -p "$REPO_DIR/.git/hooks"
  printf '#!/bin/sh\n# existing hook content\n' > "$REPO_DIR/.git/hooks/pre-commit"
  chmod +x "$REPO_DIR/.git/hooks/pre-commit"
  install_gitleaks_git_hook "$REPO_DIR"
  grep -q "# existing hook content" "$REPO_DIR/.git/hooks/pre-commit"
}
```

- [ ] **Step 2: Run failing tests**

```bash
bats tests/harness/secrets.bats 2>&1 | grep -E "not ok|FAILED"
```

Expected: 6 failures for `install_gitleaks_git_hook`.

- [ ] **Step 3: Implement `install_gitleaks_git_hook` in `harness/lib/secrets.sh`**

Append to `harness/lib/secrets.sh`:

```sh
# install_gitleaks_git_hook <repo_root>
# For pure Go repos: merges the gitleaks block into .git/hooks/pre-commit directly.
# Creates .git/hooks/pre-commit with a shebang if it does not already exist.
install_gitleaks_git_hook() {
  local repo_root="$1"
  local hook_file="$repo_root/.git/hooks/pre-commit"
  ensure_hook_exists "$hook_file"
  merge_block "$hook_file" "gitleaks" "$(_gitleaks_hook_block)" "append"
}
```

- [ ] **Step 4: Run all tests**

```bash
bats tests/harness/secrets.bats 2>&1
```

Expected: all 25 tests pass.

- [ ] **Step 5: Commit**

```bash
git add harness/lib/secrets.sh tests/harness/secrets.bats
git commit -m "feat: add install_gitleaks_git_hook — direct git hook for pure Go repos"
```

---

## Task 6: Wire secrets.sh into setup.sh + integration tests

**Files:**
- Modify: `harness/setup.sh`
- Modify: `tests/harness/setup.bats`

- [ ] **Step 1: Append integration tests to `tests/harness/setup.bats`**

Add at the end of `tests/harness/setup.bats`:

```bash
# ── gitleaks integration ──────────────────────────────────────────────────────

@test "creates .gitleaks.toml for JS repo" {
  export PATH="$BATS_TEST_DIRNAME/../mocks:$PATH"
  _pnpm_repo_with_hooks
  run bash "$SETUP_SCRIPT" "$REPO_DIR"
  [ "$status" -eq 0 ]
  [ -f "$REPO_DIR/.gitleaks.toml" ]
}

@test "creates .gitleaks.toml for mixed repo" {
  export PATH="$BATS_TEST_DIRNAME/../mocks:$PATH"
  _pnpm_repo_with_hooks
  touch "$REPO_DIR/go.mod"
  run bash "$SETUP_SCRIPT" "$REPO_DIR"
  [ "$status" -eq 0 ]
  [ -f "$REPO_DIR/.gitleaks.toml" ]
}

@test "creates .gitleaks.toml for pure Go repo" {
  export PATH="$BATS_TEST_DIRNAME/../mocks:$PATH"
  mkdir -p "$REPO_DIR/.git"
  touch "$REPO_DIR/go.mod"
  run bash "$SETUP_SCRIPT" "$REPO_DIR"
  [ "$status" -eq 0 ]
  [ -f "$REPO_DIR/.gitleaks.toml" ]
}

@test "merges gitleaks block into .husky/pre-commit for JS repo" {
  export PATH="$BATS_TEST_DIRNAME/../mocks:$PATH"
  _pnpm_repo_with_hooks
  run bash "$SETUP_SCRIPT" "$REPO_DIR"
  [ "$status" -eq 0 ]
  grep -q "# harness:gitleaks:begin" "$REPO_DIR/.husky/pre-commit"
}

@test "merges gitleaks block into .husky/pre-commit for mixed repo" {
  export PATH="$BATS_TEST_DIRNAME/../mocks:$PATH"
  _pnpm_repo_with_hooks
  touch "$REPO_DIR/go.mod"
  run bash "$SETUP_SCRIPT" "$REPO_DIR"
  [ "$status" -eq 0 ]
  grep -q "# harness:gitleaks:begin" "$REPO_DIR/.husky/pre-commit"
}

@test "merges gitleaks block into .git/hooks/pre-commit for pure Go repo" {
  export PATH="$BATS_TEST_DIRNAME/../mocks:$PATH"
  mkdir -p "$REPO_DIR/.git"
  touch "$REPO_DIR/go.mod"
  run bash "$SETUP_SCRIPT" "$REPO_DIR"
  [ "$status" -eq 0 ]
  grep -q "# harness:gitleaks:begin" "$REPO_DIR/.git/hooks/pre-commit"
}

@test "pure Go repo setup exits 0 (not 1) when go.mod present" {
  export PATH="$BATS_TEST_DIRNAME/../mocks:$PATH"
  mkdir -p "$REPO_DIR/.git"
  touch "$REPO_DIR/go.mod"
  run bash "$SETUP_SCRIPT" "$REPO_DIR"
  [ "$status" -eq 0 ]
}

@test "setup still exits 1 for repo with no package.json and no go.mod" {
  run bash "$SETUP_SCRIPT" "$REPO_DIR"
  [ "$status" -eq 1 ]
  [[ "$output" == *"not supported"* ]]
}

@test "re-run does not duplicate gitleaks block in .husky/pre-commit for JS repo" {
  export PATH="$BATS_TEST_DIRNAME/../mocks:$PATH"
  _pnpm_repo_with_hooks
  bash "$SETUP_SCRIPT" "$REPO_DIR"
  bash "$SETUP_SCRIPT" "$REPO_DIR"
  [ "$(grep -c "harness:gitleaks:begin" "$REPO_DIR/.husky/pre-commit")" = "1" ]
}

@test "re-run does not duplicate gitleaks block in .git/hooks/pre-commit for pure Go repo" {
  export PATH="$BATS_TEST_DIRNAME/../mocks:$PATH"
  mkdir -p "$REPO_DIR/.git"
  touch "$REPO_DIR/go.mod"
  bash "$SETUP_SCRIPT" "$REPO_DIR"
  bash "$SETUP_SCRIPT" "$REPO_DIR"
  [ "$(grep -c "harness:gitleaks:begin" "$REPO_DIR/.git/hooks/pre-commit")" = "1" ]
}
```

- [ ] **Step 2: Run failing integration tests**

```bash
bats tests/harness/setup.bats 2>&1 | grep -E "not ok|FAILED"
```

Expected: 10 new failures related to gitleaks.

- [ ] **Step 3: Modify `harness/setup.sh` — source secrets.sh**

In `harness/setup.sh`, add the source line after `typecheck.sh`:

Find this block (lines 8-14 of setup.sh):
```sh
. "$SCRIPT_DIR/lib/detect-language.sh"
. "$SCRIPT_DIR/lib/detect-package-manager.sh"
. "$SCRIPT_DIR/lib/merge-hook.sh"
. "$SCRIPT_DIR/lib/husky.sh"
. "$SCRIPT_DIR/lib/ci-workflows.sh"
. "$SCRIPT_DIR/lib/lint.sh"
. "$SCRIPT_DIR/lib/format.sh"
. "$SCRIPT_DIR/lib/typecheck.sh"
```

Change to:
```sh
. "$SCRIPT_DIR/lib/detect-language.sh"
. "$SCRIPT_DIR/lib/detect-package-manager.sh"
. "$SCRIPT_DIR/lib/merge-hook.sh"
. "$SCRIPT_DIR/lib/husky.sh"
. "$SCRIPT_DIR/lib/ci-workflows.sh"
. "$SCRIPT_DIR/lib/lint.sh"
. "$SCRIPT_DIR/lib/format.sh"
. "$SCRIPT_DIR/lib/typecheck.sh"
. "$SCRIPT_DIR/lib/secrets.sh"
```

- [ ] **Step 4: Modify `harness/setup.sh` — call gitleaks before the case and wire hook installs**

After `REPO_LANG=$(detect_language "$REPO_ROOT")` and before the `case` statement, add:

```sh
ensure_gitleaks_available
ensure_gitleaks_config "$REPO_ROOT"
```

In the `js|mixed` case, add `install_gitleaks_hook "$REPO_ROOT"` after the existing typecheck/govet block and before `detect_overlapping_workflows`. The modified js|mixed case tail should look like:

```sh
    ensure_typescript_installed "$REPO_ROOT"
    ensure_tsconfig "$REPO_ROOT"
    install_tsc_hook "$REPO_ROOT"
    if [ "$REPO_LANG" = "mixed" ]; then
      ensure_go_vet_available
      install_go_vet_hook "$REPO_ROOT"
    fi
    install_gitleaks_hook "$REPO_ROOT"
    detect_overlapping_workflows "$REPO_ROOT"
    install_workflow_file "$REPO_ROOT" "$REPO_LANG" "$REPO_PM"
    echo "Done. Husky hooks configured at $REPO_ROOT/.husky/"
    echo "NOTE: Add 'harness / checks' as a required status check in GitHub branch protection to enforce CI linting on PRs."
    ;;
```

Replace the `unsupported` case:

```sh
  unsupported)
    if [ -f "$REPO_ROOT/go.mod" ]; then
      install_gitleaks_git_hook "$REPO_ROOT"
      echo "Done. gitleaks pre-commit hook installed at $REPO_ROOT/.git/hooks/pre-commit"
      echo "(Pure Go repo — Husky-based checks are not supported in v1.)"
    else
      echo "ERROR: No package.json found. Pure Go repos are not supported in v1." >&2
      exit 1
    fi
    ;;
```

- [ ] **Step 5: Run all tests**

```bash
bats tests/harness/ 2>&1
```

Expected: all tests in all files pass. Note the count before and after to confirm no regressions.

- [ ] **Step 6: Commit**

```bash
git add harness/setup.sh tests/harness/setup.bats
git commit -m "feat: wire secrets.sh into setup.sh — gitleaks for all repo types"
```

---

## Task 7: Update harness README

**Files:**
- Modify: `harness/README.md`

- [ ] **Step 1: Update the Supported repos table**

Find the Pure Go row:
```markdown
| Pure Go | `go.mod` only | ❌ v1 out of scope |
```

Replace with:
```markdown
| Pure Go | `go.mod` only | ⚠️ gitleaks only (Husky checks not supported in v1) |
```

- [ ] **Step 2: Add a Secrets scanning section to `harness/README.md`**

Append before the final `## Running tests` section (insert between the Type-checking section and Running tests):

```markdown
## Secrets scanning

Setup installs [gitleaks](https://github.com/gitleaks/gitleaks) if not already present and merges a secrets-scan pre-commit hook. This is the only harness check that runs on all repo types, including pure Go repos.

### All repo types

- Installs `gitleaks` if absent: tries `brew install gitleaks` (macOS), then `go install github.com/zricethezav/gitleaks/v8@latest`; fails with an actionable error message if neither installer is available
- Writes a default `.gitleaks.toml` if none exists — commit this file to give the team visibility and a place to add allowlist entries for known false positives
- Merges a `harness:gitleaks` pre-commit block that runs `gitleaks protect --staged` on every commit

### JS / TS and mixed repos

The gitleaks block is appended to `.husky/pre-commit` (same as other harness checks).

### Pure Go repos

The gitleaks block is written directly to `.git/hooks/pre-commit` (Husky is not available without `package.json`). Each developer must run `gh ai-first-taskforce setup` after cloning to install the hook locally.

### On detection

When gitleaks finds a secret, the commit is blocked and the hook prints:

```
Secret detected. Next steps:
  - False positive? Add an [[allowlist]] entry to .gitleaks.toml
  - Real credential? Rotate it immediately — do not push
```

If gitleaks is missing at hook runtime (e.g., on a fresh clone before setup has been run), the hook fails with an actionable error including the install command.
```

- [ ] **Step 3: Run all tests to confirm no regressions**

```bash
bats tests/harness/ 2>&1
```

Expected: all tests pass.

- [ ] **Step 4: Commit**

```bash
git add harness/README.md
git commit -m "docs: document gitleaks secrets scanning in harness README"
```

---

## Self-Review

### Spec coverage

| Acceptance criterion | Task |
|----------------------|------|
| Harness setup installs gitleaks; surfaces clear install command on failure | Task 2 (`ensure_gitleaks_available`) |
| Default `.gitleaks.toml` written to repo root if none exists | Task 3 (`ensure_gitleaks_config`) |
| Husky pre-commit hook runs gitleaks in `--staged` mode | Task 4 (`install_gitleaks_hook`) |
| Secret detection exits non-zero, blocks commit, outputs file+pattern | Task 4 (gitleaks itself outputs findings; hook exits 1) |
| Hook output includes next steps — false positive allowlist, rotate credential | Task 4 (guidance in hook block) |
| Hook runs on all repo types — language detection does not gate it | Task 6 (wired before the case, pure Go handled in `unsupported` branch) |
| If gitleaks missing at hook runtime, hook fails with actionable error + install command | Tasks 4 & 5 (runtime guard in `_gitleaks_hook_block`) |

All criteria are covered. No gaps found.

### Placeholder scan

No TBD, TODO, or "implement later" text. All code blocks are complete. All expected outputs are specified.

### Type consistency

- `_gitleaks_hook_block` is defined in Task 4 and reused in Task 5 — names match.
- `ensure_hook_exists` is sourced from `merge-hook.sh` — already tested in other bats files.
- `merge_block` signature used throughout is `merge_block <file> <id> <content> <position>` — consistent with existing usage.
