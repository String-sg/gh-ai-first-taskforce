# Harness Foundation — gh Extension and Local Husky Hook Scaffolding

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a `gh` CLI extension entry point and Husky scaffolding logic so engineers can run `gh ai-first-taskforce setup` to install the harness's pre-commit and pre-push hooks into their repo, with idempotent merge behaviour.

**Architecture:** A shell-script `gh` extension (`gh-ai-first-taskforce`) routes the `setup` subcommand to `harness/setup.sh`. The orchestrator detects repo type (from `package.json` / `go.mod`) and package manager (from lockfile), installs Husky if absent, initialises `.husky/`, and merges sentinel-delimited NVM preamble blocks into `.husky/pre-commit` and `.husky/pre-push`. Blocks are idempotent: re-running checks for the sentinel before inserting, so no content is duplicated or overwritten. Subsequent stories (#9–#12) use the same `merge_block()` primitive to append their own check rules. Unsupported package managers (npm, yarn, or no lockfile) exit with a clear error rather than silently falling back.

**Tech Stack:** POSIX sh, Husky v9 (`pnpm exec husky init` / `bunx husky init`), bats-core for tests (`brew install bats-core`).

---

## File Map

| Action | Path | Responsibility |
|--------|------|----------------|
| Create | `gh-ai-first-taskforce` | gh extension entry point; routes `setup` subcommand |
| Create | `harness/setup.sh` | Orchestrates detection → Husky init → hook merge |
| Create | `harness/lib/detect-language.sh` | `detect_language <dir>` — echoes `js`, `mixed`, or `unsupported` |
| Create | `harness/lib/detect-package-manager.sh` | `detect_package_manager <dir>` — echoes `pnpm`, `bun`, or `unsupported` |
| Create | `harness/lib/merge-hook.sh` | `merge_block` and `ensure_hook_exists` — idempotent sentinel merge |
| Create | `harness/lib/husky.sh` | `is_husky_installed`, `ensure_husky_installed`, `ensure_husky_init` |
| Create | `tests/harness/detect-language.bats` | Tests for `detect_language()` |
| Create | `tests/harness/detect-package-manager.bats` | Tests for `detect_package_manager()` |
| Create | `tests/harness/merge-hook.bats` | Tests for `merge_block()` and `ensure_hook_exists()` |
| Create | `tests/harness/husky.bats` | Tests for Husky install/init helpers |
| Create | `tests/harness/setup.bats` | Integration tests for the full setup flow |
| Create | `tests/mocks/pnpm` | Stub for `pnpm add` and `pnpm exec husky init` |
| Create | `tests/mocks/bun` | Stub for `bun add` |
| Create | `tests/mocks/bunx` | Stub for `bunx husky init` |
| Modify | `CLAUDE.md` | Document shell scripts as permitted for the gh extension |

---

## Task 1: Language Detection

**Files:**
- Create: `harness/lib/detect-language.sh`
- Create: `tests/harness/detect-language.bats`

- [ ] **Step 1: Create the test file**

```bash
# tests/harness/detect-language.bats
#!/usr/bin/env bats

setup() {
  source "$BATS_TEST_DIRNAME/../../harness/lib/detect-language.sh"
}

@test "js: package.json only → 'js'" {
  local dir
  dir=$(mktemp -d)
  touch "$dir/package.json"
  run detect_language "$dir"
  rm -rf "$dir"
  [ "$status" -eq 0 ]
  [ "$output" = "js" ]
}

@test "mixed: package.json + go.mod → 'mixed'" {
  local dir
  dir=$(mktemp -d)
  touch "$dir/package.json" "$dir/go.mod"
  run detect_language "$dir"
  rm -rf "$dir"
  [ "$status" -eq 0 ]
  [ "$output" = "mixed" ]
}

@test "unsupported: go.mod only → 'unsupported'" {
  local dir
  dir=$(mktemp -d)
  touch "$dir/go.mod"
  run detect_language "$dir"
  rm -rf "$dir"
  [ "$status" -eq 0 ]
  [ "$output" = "unsupported" ]
}

@test "unsupported: empty dir → 'unsupported'" {
  local dir
  dir=$(mktemp -d)
  run detect_language "$dir"
  rm -rf "$dir"
  [ "$status" -eq 0 ]
  [ "$output" = "unsupported" ]
}
```

- [ ] **Step 2: Run tests — expect failure (function not defined)**

```bash
bats tests/harness/detect-language.bats
```

Expected: 4 tests fail with `detect_language: command not found` or similar.

- [ ] **Step 3: Create the implementation**

```bash
# harness/lib/detect-language.sh
detect_language() {
  local root="$1"
  if [ -f "$root/package.json" ] && [ -f "$root/go.mod" ]; then
    echo "mixed"
  elif [ -f "$root/package.json" ]; then
    echo "js"
  else
    echo "unsupported"
  fi
}
```

- [ ] **Step 4: Run tests — expect all pass**

```bash
bats tests/harness/detect-language.bats
```

Expected: 4 tests, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add harness/lib/detect-language.sh tests/harness/detect-language.bats
git commit -m "feat: add detect_language() for JS/TS, mixed, and unsupported repo detection"
```

---

## Task 2: Package Manager Detection

**Files:**
- Create: `harness/lib/detect-package-manager.sh`
- Create: `tests/harness/detect-package-manager.bats`

Detection rules:
- `pnpm-lock.yaml` present → `pnpm`
- `bun.lockb` or `bun.lock` present → `bun`
- anything else (npm, yarn, no lockfile) → `unsupported`

- [ ] **Step 1: Create the test file**

```bash
# tests/harness/detect-package-manager.bats
#!/usr/bin/env bats

setup() {
  source "$BATS_TEST_DIRNAME/../../harness/lib/detect-package-manager.sh"
}

@test "pnpm-lock.yaml → 'pnpm'" {
  local dir
  dir=$(mktemp -d)
  touch "$dir/pnpm-lock.yaml"
  run detect_package_manager "$dir"
  rm -rf "$dir"
  [ "$status" -eq 0 ]
  [ "$output" = "pnpm" ]
}

@test "bun.lockb → 'bun'" {
  local dir
  dir=$(mktemp -d)
  touch "$dir/bun.lockb"
  run detect_package_manager "$dir"
  rm -rf "$dir"
  [ "$status" -eq 0 ]
  [ "$output" = "bun" ]
}

@test "bun.lock → 'bun'" {
  local dir
  dir=$(mktemp -d)
  touch "$dir/bun.lock"
  run detect_package_manager "$dir"
  rm -rf "$dir"
  [ "$status" -eq 0 ]
  [ "$output" = "bun" ]
}

@test "package-lock.json only → 'unsupported'" {
  local dir
  dir=$(mktemp -d)
  touch "$dir/package-lock.json"
  run detect_package_manager "$dir"
  rm -rf "$dir"
  [ "$status" -eq 0 ]
  [ "$output" = "unsupported" ]
}

@test "no lockfile → 'unsupported'" {
  local dir
  dir=$(mktemp -d)
  run detect_package_manager "$dir"
  rm -rf "$dir"
  [ "$status" -eq 0 ]
  [ "$output" = "unsupported" ]
}
```

- [ ] **Step 2: Run tests — expect failure**

```bash
bats tests/harness/detect-package-manager.bats
```

Expected: 5 tests fail with `detect_package_manager: command not found`.

- [ ] **Step 3: Create the implementation**

```bash
# harness/lib/detect-package-manager.sh
detect_package_manager() {
  local root="$1"
  if [ -f "$root/pnpm-lock.yaml" ]; then
    echo "pnpm"
  elif [ -f "$root/bun.lockb" ] || [ -f "$root/bun.lock" ]; then
    echo "bun"
  else
    echo "unsupported"
  fi
}
```

- [ ] **Step 4: Run tests — expect all pass**

```bash
bats tests/harness/detect-package-manager.bats
```

Expected: 5 tests, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add harness/lib/detect-package-manager.sh tests/harness/detect-package-manager.bats
git commit -m "feat: add detect_package_manager() for pnpm/bun detection"
```

---

## Task 3: Hook Merge Logic

**Files:**
- Create: `harness/lib/merge-hook.sh`
- Create: `tests/harness/merge-hook.bats`

- [ ] **Step 1: Create the test file**

```bash
# tests/harness/merge-hook.bats
#!/usr/bin/env bats

setup() {
  source "$BATS_TEST_DIRNAME/../../harness/lib/merge-hook.sh"
  HOOK_DIR=$(mktemp -d)
}

teardown() {
  rm -rf "$HOOK_DIR"
}

@test "ensure_hook_exists: creates file with shebang if absent" {
  local hook="$HOOK_DIR/pre-commit"
  ensure_hook_exists "$hook"
  [ -f "$hook" ]
  [ -x "$hook" ]
  run head -1 "$hook"
  [ "$output" = "#!/bin/sh" ]
}

@test "ensure_hook_exists: leaves existing file unchanged" {
  local hook="$HOOK_DIR/pre-commit"
  printf '#!/bin/sh\nnpm test\n' > "$hook"
  chmod +x "$hook"
  ensure_hook_exists "$hook"
  [ "$(wc -l < "$hook" | tr -d ' ')" = "2" ]
}

@test "merge_block append: appends block when sentinel absent" {
  local hook="$HOOK_DIR/pre-commit"
  printf '#!/bin/sh\n' > "$hook"
  chmod +x "$hook"
  local block
  block='# harness:nvm:begin
export NVM_DIR="$HOME/.nvm"
# harness:nvm:end'
  merge_block "$hook" "nvm" "$block"
  grep -q "# harness:nvm:begin" "$hook"
  grep -q 'export NVM_DIR' "$hook"
  grep -q "# harness:nvm:end" "$hook"
}

@test "merge_block append: skips block when sentinel already present" {
  local hook="$HOOK_DIR/pre-commit"
  printf '#!/bin/sh\n# harness:nvm:begin\nexport NVM_DIR="$HOME/.nvm"\n# harness:nvm:end\n' > "$hook"
  chmod +x "$hook"
  local lines_before
  lines_before=$(wc -l < "$hook" | tr -d ' ')
  local block
  block='# harness:nvm:begin
export NVM_DIR="$HOME/.nvm"
# harness:nvm:end'
  merge_block "$hook" "nvm" "$block"
  [ "$(wc -l < "$hook" | tr -d ' ')" = "$lines_before" ]
}

@test "merge_block after-shebang: inserts block after line 1" {
  local hook="$HOOK_DIR/pre-commit"
  printf '#!/bin/sh\nexisting content\n' > "$hook"
  chmod +x "$hook"
  local block
  block='# harness:nvm:begin
export NVM_DIR="$HOME/.nvm"
# harness:nvm:end'
  merge_block "$hook" "nvm" "$block" "after-shebang"
  run sed -n '3p' "$hook"
  [ "$output" = "# harness:nvm:begin" ]
}

@test "merge_block after-shebang: second call is idempotent" {
  local hook="$HOOK_DIR/pre-commit"
  printf '#!/bin/sh\n' > "$hook"
  chmod +x "$hook"
  local block
  block='# harness:nvm:begin
export NVM_DIR="$HOME/.nvm"
# harness:nvm:end'
  merge_block "$hook" "nvm" "$block" "after-shebang"
  local lines_after_first
  lines_after_first=$(wc -l < "$hook" | tr -d ' ')
  merge_block "$hook" "nvm" "$block" "after-shebang"
  [ "$(wc -l < "$hook" | tr -d ' ')" = "$lines_after_first" ]
}
```

- [ ] **Step 2: Run tests — expect failure**

```bash
bats tests/harness/merge-hook.bats
```

Expected: 5 tests fail.

- [ ] **Step 3: Create the implementation**

```bash
# harness/lib/merge-hook.sh

ensure_hook_exists() {
  local hook_file="$1"
  if [ ! -f "$hook_file" ]; then
    mkdir -p "$(dirname "$hook_file")"
    printf '#!/bin/sh\n' > "$hook_file"
    chmod +x "$hook_file"
  fi
}

# merge_block <hook_file> <block_id> <block_content> [position]
# position: "append" (default) | "after-shebang"
# block_content must include the # harness:<block_id>:begin / :end sentinels.
merge_block() {
  local hook_file="$1"
  local block_id="$2"
  local block_content="$3"
  local position="${4:-append}"

  if grep -qF "# harness:${block_id}:begin" "$hook_file" 2>/dev/null; then
    return 0
  fi

  if [ "$position" = "after-shebang" ]; then
    local tmp
    tmp=$(mktemp)
    head -1 "$hook_file" > "$tmp"
    printf '\n%s\n' "$block_content" >> "$tmp"
    tail -n +2 "$hook_file" >> "$tmp"
    mv "$tmp" "$hook_file"
  else
    printf '\n%s\n' "$block_content" >> "$hook_file"
  fi
}
```

- [ ] **Step 4: Run tests — expect all pass**

```bash
bats tests/harness/merge-hook.bats
```

Expected: 5 tests, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add harness/lib/merge-hook.sh tests/harness/merge-hook.bats
git commit -m "feat: add merge_block() and ensure_hook_exists() for idempotent hook management"
```

---

## Task 4: Husky Installation Helpers

**Files:**
- Create: `harness/lib/husky.sh`
- Create: `tests/harness/husky.bats`
- Create: `tests/mocks/pnpm`
- Create: `tests/mocks/bun`
- Create: `tests/mocks/bunx`

PM-to-command mapping:
- pnpm install: `pnpm add -D husky`
- pnpm exec:    `pnpm exec husky init`
- bun install:  `bun add -D husky`
- bun exec:     `bunx husky init`

`detect_package_manager` is sourced by `setup.sh` before `husky.sh`, so it is available when the lib functions run. In tests, the bats `setup()` block sources it explicitly first.

- [ ] **Step 1: Create test mocks**

All three mocks write to the shared `$MOCK_LOG` so tests can assert on a single file.

```bash
# tests/mocks/pnpm
#!/bin/sh
echo "mock-pnpm $*" >> "${MOCK_LOG:-/tmp/mock-calls.log}"
if [ "$1" = "exec" ] && [ "$2" = "husky" ] && [ "$3" = "init" ]; then
  mkdir -p "$(pwd)/.husky"
  printf '#!/bin/sh\nnpm test\n' > "$(pwd)/.husky/pre-commit"
  chmod +x "$(pwd)/.husky/pre-commit"
fi
exit 0
```

```bash
# tests/mocks/bun
#!/bin/sh
echo "mock-bun $*" >> "${MOCK_LOG:-/tmp/mock-calls.log}"
exit 0
```

```bash
# tests/mocks/bunx
#!/bin/sh
echo "mock-bunx $*" >> "${MOCK_LOG:-/tmp/mock-calls.log}"
if [ "$1" = "husky" ] && [ "$2" = "init" ]; then
  mkdir -p "$(pwd)/.husky"
  printf '#!/bin/sh\nnpm test\n' > "$(pwd)/.husky/pre-commit"
  chmod +x "$(pwd)/.husky/pre-commit"
fi
exit 0
```

Make them executable:

```bash
chmod +x tests/mocks/pnpm tests/mocks/bun tests/mocks/bunx
```

- [ ] **Step 2: Create the test file**

```bash
# tests/harness/husky.bats
#!/usr/bin/env bats

setup() {
  source "$BATS_TEST_DIRNAME/../../harness/lib/detect-package-manager.sh"
  source "$BATS_TEST_DIRNAME/../../harness/lib/husky.sh"
  export PATH="$BATS_TEST_DIRNAME/../mocks:$PATH"
  REPO_DIR=$(mktemp -d)
  MOCK_LOG=$(mktemp)
  export MOCK_LOG
}

teardown() {
  rm -rf "$REPO_DIR" "$MOCK_LOG"
}

@test "is_husky_installed: returns 1 when no husky in package.json" {
  printf '{"devDependencies":{}}\n' > "$REPO_DIR/package.json"
  run is_husky_installed "$REPO_DIR"
  [ "$status" -eq 1 ]
}

@test "is_husky_installed: returns 0 when husky is in devDependencies" {
  printf '{"devDependencies":{"husky":"^9.0.0"}}\n' > "$REPO_DIR/package.json"
  run is_husky_installed "$REPO_DIR"
  [ "$status" -eq 0 ]
}

@test "ensure_husky_installed: runs pnpm add when husky absent (pnpm repo)" {
  printf '{"devDependencies":{}}\n' > "$REPO_DIR/package.json"
  touch "$REPO_DIR/pnpm-lock.yaml"
  ensure_husky_installed "$REPO_DIR"
  grep -q "mock-pnpm add -D husky" "$MOCK_LOG"
}

@test "ensure_husky_installed: runs bun add when husky absent (bun repo)" {
  printf '{"devDependencies":{}}\n' > "$REPO_DIR/package.json"
  touch "$REPO_DIR/bun.lockb"
  ensure_husky_installed "$REPO_DIR"
  grep -q "mock-bun add -D husky" "$MOCK_LOG"
}

@test "ensure_husky_installed: skips install when husky already present" {
  printf '{"devDependencies":{"husky":"^9.0.0"}}\n' > "$REPO_DIR/package.json"
  touch "$REPO_DIR/pnpm-lock.yaml"
  ensure_husky_installed "$REPO_DIR"
  run grep "mock-pnpm add" "$MOCK_LOG"
  [ "$status" -ne 0 ]
}

@test "ensure_husky_installed: exits 1 for unsupported package manager" {
  printf '{"devDependencies":{}}\n' > "$REPO_DIR/package.json"
  run ensure_husky_installed "$REPO_DIR"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unsupported package manager"* ]]
}

@test "ensure_husky_init: runs pnpm exec husky init when .husky absent" {
  touch "$REPO_DIR/pnpm-lock.yaml"
  ensure_husky_init "$REPO_DIR"
  [ -d "$REPO_DIR/.husky" ]
  grep -q "mock-pnpm exec husky init" "$MOCK_LOG"
}

@test "ensure_husky_init: runs bunx husky init when .husky absent (bun repo)" {
  touch "$REPO_DIR/bun.lockb"
  ensure_husky_init "$REPO_DIR"
  [ -d "$REPO_DIR/.husky" ]
  grep -q "mock-bunx husky init" "$MOCK_LOG"
}

@test "ensure_husky_init: resets sample pre-commit to bare shebang after init" {
  touch "$REPO_DIR/pnpm-lock.yaml"
  ensure_husky_init "$REPO_DIR"
  run cat "$REPO_DIR/.husky/pre-commit"
  [ "$output" = "#!/bin/sh" ]
}

@test "ensure_husky_init: skips init when .husky already exists" {
  mkdir -p "$REPO_DIR/.husky"
  printf '#!/bin/sh\n# existing team hook\n' > "$REPO_DIR/.husky/pre-commit"
  chmod +x "$REPO_DIR/.husky/pre-commit"
  touch "$REPO_DIR/pnpm-lock.yaml"
  ensure_husky_init "$REPO_DIR"
  run grep "mock-pnpm exec husky init" "$MOCK_LOG"
  [ "$status" -ne 0 ]
}
```

- [ ] **Step 3: Run tests — expect failure**

```bash
bats tests/harness/husky.bats
```

Expected: 10 tests fail.

- [ ] **Step 4: Create the implementation**

```bash
# harness/lib/husky.sh
# Requires detect_package_manager() to be sourced before this file.

is_husky_installed() {
  local repo_root="$1"
  grep -qE '"husky"\s*:' "$repo_root/package.json" 2>/dev/null
}

ensure_husky_installed() {
  local repo_root="$1"
  if ! is_husky_installed "$repo_root"; then
    local pm
    pm=$(detect_package_manager "$repo_root")
    case "$pm" in
      pnpm) (cd "$repo_root" && pnpm add -D husky) ;;
      bun)  (cd "$repo_root" && bun add -D husky) ;;
      *)
        echo "ERROR: Unsupported package manager. Expected pnpm-lock.yaml or bun.lock/bun.lockb." >&2
        exit 1
        ;;
    esac
  fi
}

ensure_husky_init() {
  local repo_root="$1"
  if [ ! -d "$repo_root/.husky" ]; then
    local pm
    pm=$(detect_package_manager "$repo_root")
    case "$pm" in
      pnpm) (cd "$repo_root" && pnpm exec husky init) ;;
      bun)  (cd "$repo_root" && bunx husky init) ;;
      *)
        echo "ERROR: Unsupported package manager. Expected pnpm-lock.yaml or bun.lock/bun.lockb." >&2
        exit 1
        ;;
    esac
    # husky init writes a sample "npm test" pre-commit — reset to bare shebang
    # so merge_block owns all hook content going forward
    printf '#!/bin/sh\n' > "$repo_root/.husky/pre-commit"
    chmod +x "$repo_root/.husky/pre-commit"
  fi
}
```

- [ ] **Step 5: Run tests — expect all pass**

```bash
bats tests/harness/husky.bats
```

Expected: 10 tests, 0 failures.

- [ ] **Step 6: Commit**

```bash
git add harness/lib/husky.sh tests/harness/husky.bats tests/mocks/pnpm tests/mocks/bun tests/mocks/bunx
git commit -m "feat: add Husky install/init helpers supporting pnpm and bun"
```

---

## Task 5: Setup Orchestrator

**Files:**
- Create: `harness/setup.sh`
- Create: `tests/harness/setup.bats`

The NVM block merged into both hooks by this story:

```
# harness:nvm:begin
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
# harness:nvm:end
```

- [ ] **Step 1: Create the test file**

```bash
# tests/harness/setup.bats
#!/usr/bin/env bats

setup() {
  export PATH="$BATS_TEST_DIRNAME/../mocks:$PATH"
  REPO_DIR=$(mktemp -d)
  MOCK_LOG=$(mktemp)
  export MOCK_LOG
  SETUP_SCRIPT="$BATS_TEST_DIRNAME/../../harness/setup.sh"
}

teardown() {
  rm -rf "$REPO_DIR" "$MOCK_LOG"
}

_pnpm_repo_with_hooks() {
  printf '{"devDependencies":{"husky":"^9.0.0"}}\n' > "$REPO_DIR/package.json"
  touch "$REPO_DIR/pnpm-lock.yaml"
  mkdir -p "$REPO_DIR/.husky"
  printf '#!/bin/sh\n' > "$REPO_DIR/.husky/pre-commit"
  printf '#!/bin/sh\n' > "$REPO_DIR/.husky/pre-push"
  chmod +x "$REPO_DIR/.husky/pre-commit" "$REPO_DIR/.husky/pre-push"
}

_bun_repo_with_hooks() {
  printf '{"devDependencies":{"husky":"^9.0.0"}}\n' > "$REPO_DIR/package.json"
  touch "$REPO_DIR/bun.lockb"
  mkdir -p "$REPO_DIR/.husky"
  printf '#!/bin/sh\n' > "$REPO_DIR/.husky/pre-commit"
  printf '#!/bin/sh\n' > "$REPO_DIR/.husky/pre-push"
  chmod +x "$REPO_DIR/.husky/pre-commit" "$REPO_DIR/.husky/pre-push"
}

@test "exits 1 with clear message for pure Go repo" {
  touch "$REPO_DIR/go.mod"
  run bash "$SETUP_SCRIPT" "$REPO_DIR"
  [ "$status" -eq 1 ]
  [[ "$output" == *"not supported"* ]]
}

@test "exits 1 with clear message for unsupported package manager" {
  printf '{"devDependencies":{}}\n' > "$REPO_DIR/package.json"
  run bash "$SETUP_SCRIPT" "$REPO_DIR"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unsupported package manager"* ]]
}

@test "succeeds for pnpm JS repo" {
  _pnpm_repo_with_hooks
  run bash "$SETUP_SCRIPT" "$REPO_DIR"
  [ "$status" -eq 0 ]
}

@test "succeeds for bun JS repo" {
  _bun_repo_with_hooks
  run bash "$SETUP_SCRIPT" "$REPO_DIR"
  [ "$status" -eq 0 ]
}

@test "succeeds for mixed repo (package.json + go.mod)" {
  _pnpm_repo_with_hooks
  touch "$REPO_DIR/go.mod"
  run bash "$SETUP_SCRIPT" "$REPO_DIR"
  [ "$status" -eq 0 ]
}

@test "merges NVM block into pre-commit" {
  _pnpm_repo_with_hooks
  bash "$SETUP_SCRIPT" "$REPO_DIR"
  grep -q "# harness:nvm:begin" "$REPO_DIR/.husky/pre-commit"
}

@test "merges NVM block into pre-push" {
  _pnpm_repo_with_hooks
  bash "$SETUP_SCRIPT" "$REPO_DIR"
  grep -q "# harness:nvm:begin" "$REPO_DIR/.husky/pre-push"
}

@test "re-run does not duplicate NVM block in pre-commit" {
  _pnpm_repo_with_hooks
  bash "$SETUP_SCRIPT" "$REPO_DIR"
  bash "$SETUP_SCRIPT" "$REPO_DIR"
  [ "$(grep -c "harness:nvm:begin" "$REPO_DIR/.husky/pre-commit")" = "1" ]
}

@test "re-run does not duplicate NVM block in pre-push" {
  _pnpm_repo_with_hooks
  bash "$SETUP_SCRIPT" "$REPO_DIR"
  bash "$SETUP_SCRIPT" "$REPO_DIR"
  [ "$(grep -c "harness:nvm:begin" "$REPO_DIR/.husky/pre-push")" = "1" ]
}

@test "preserves existing team hook content" {
  printf '{"devDependencies":{"husky":"^9.0.0"}}\n' > "$REPO_DIR/package.json"
  touch "$REPO_DIR/pnpm-lock.yaml"
  mkdir -p "$REPO_DIR/.husky"
  printf '#!/bin/sh\n# team custom rule\npnpm run custom\n' > "$REPO_DIR/.husky/pre-commit"
  printf '#!/bin/sh\n' > "$REPO_DIR/.husky/pre-push"
  chmod +x "$REPO_DIR/.husky/pre-commit" "$REPO_DIR/.husky/pre-push"
  bash "$SETUP_SCRIPT" "$REPO_DIR"
  grep -q "# team custom rule" "$REPO_DIR/.husky/pre-commit"
}
```

- [ ] **Step 2: Run tests — expect failure**

```bash
bats tests/harness/setup.bats
```

Expected: 10 tests fail (setup.sh does not exist).

- [ ] **Step 3: Create the implementation**

```bash
# harness/setup.sh
#!/bin/sh
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="${1:-$(git rev-parse --show-toplevel)}"

. "$SCRIPT_DIR/lib/detect-language.sh"
. "$SCRIPT_DIR/lib/detect-package-manager.sh"
. "$SCRIPT_DIR/lib/merge-hook.sh"
. "$SCRIPT_DIR/lib/husky.sh"

NVM_BLOCK='# harness:nvm:begin
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
# harness:nvm:end'

LANG=$(detect_language "$REPO_ROOT")

case "$LANG" in
  js|mixed)
    echo "Detected $LANG repo — setting up Husky hooks..."
    ensure_husky_installed "$REPO_ROOT"
    ensure_husky_init "$REPO_ROOT"
    ensure_hook_exists "$REPO_ROOT/.husky/pre-push"
    merge_block "$REPO_ROOT/.husky/pre-commit" "nvm" "$NVM_BLOCK" "after-shebang"
    merge_block "$REPO_ROOT/.husky/pre-push" "nvm" "$NVM_BLOCK" "after-shebang"
    echo "Done. Husky hooks configured at $REPO_ROOT/.husky/"
    ;;
  unsupported)
    echo "ERROR: No package.json found. Pure Go repos are not supported in v1." >&2
    exit 1
    ;;
esac
```

Make it executable:

```bash
chmod +x harness/setup.sh
```

- [ ] **Step 4: Run tests — expect all pass**

```bash
bats tests/harness/setup.bats
```

Expected: 10 tests, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add harness/setup.sh tests/harness/setup.bats
git commit -m "feat: add setup.sh orchestrator for Husky hook scaffolding"
```

---

## Task 6: gh Extension Entry Point

**Files:**
- Create: `gh-ai-first-taskforce`

- [ ] **Step 1: Create the entry point**

```bash
# gh-ai-first-taskforce
#!/bin/sh
set -e

EXTENSION_DIR="$(cd "$(dirname "$0")" && pwd)"
COMMAND="${1:-help}"
shift 2>/dev/null || true

case "$COMMAND" in
  setup)
    bash "$EXTENSION_DIR/harness/setup.sh"
    ;;
  help|--help|-h)
    echo "Usage: gh ai-first-taskforce <command>"
    echo ""
    echo "Commands:"
    echo "  setup    Scaffold Husky hooks into the current repo"
    ;;
  *)
    echo "Unknown command: $COMMAND" >&2
    echo "Run 'gh ai-first-taskforce help' for usage." >&2
    exit 1
    ;;
esac
```

- [ ] **Step 2: Make it executable**

```bash
chmod +x gh-ai-first-taskforce
```

- [ ] **Step 3: Smoke-test help output**

```bash
bash gh-ai-first-taskforce help
```

Expected:
```
Usage: gh ai-first-taskforce <command>

Commands:
  setup    Scaffold Husky hooks into the current repo
```

- [ ] **Step 4: Smoke-test the unsupported-repo and unsupported-PM paths**

Pure Go repo (no package.json):
```bash
mkdir /tmp/test-pure-go && touch /tmp/test-pure-go/go.mod
bash harness/setup.sh /tmp/test-pure-go
```
Expected: exit 1 with `ERROR: No package.json found. Pure Go repos are not supported in v1.`

No lockfile (npm or yarn repo):
```bash
mkdir /tmp/test-npm && printf '{"devDependencies":{}}\n' > /tmp/test-npm/package.json
bash harness/setup.sh /tmp/test-npm
```
Expected: exit 1 with `ERROR: Unsupported package manager. Expected pnpm-lock.yaml or bun.lock/bun.lockb.`

Clean up:
```bash
rm -rf /tmp/test-pure-go /tmp/test-npm
```

- [ ] **Step 5: Commit**

```bash
git add gh-ai-first-taskforce
git commit -m "feat: add gh-ai-first-taskforce extension entry point"
```

---

## Task 7: Update CLAUDE.md

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Add shell script section to CLAUDE.md**

Open `CLAUDE.md` and add this section after the "No Application Code" section:

```markdown
## Shell Scripts (gh Extension)

This repo doubles as a `gh` CLI extension. Shell scripts are permitted in these locations:

- `gh-ai-first-taskforce` — extension entry point (repo root)
- `harness/` — setup scripts and helpers
- `tests/` — bats-based tests for harness scripts
- `tests/mocks/` — stub binaries used during shell testing

Do not add `package.json`, build tooling, or non-shell application code outside of these locations.
```

- [ ] **Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: document shell scripts as permitted for the gh extension"
```

---

## Self-Review

### Spec Coverage

| Acceptance Criterion | Covered By |
|---------------------|------------|
| Install via `gh extension install transformteamsg/ai-first-taskforce` | `gh-ai-first-taskforce` entry point (Task 6) |
| Auto-detects JS/TS repo from `package.json` | `detect_language()` → `"js"` (Task 1) |
| Auto-detects mixed repo from `package.json` + `go.mod` | `detect_language()` → `"mixed"` (Task 1) |
| Setup merges with existing Husky config | `merge_block()` appends without overwriting; `ensure_husky_init` skips when `.husky/` exists (Tasks 3, 4) |
| On re-run, only new harness rules merged in | Sentinel check in `merge_block()` makes all merges idempotent (Task 3) |
| Repos without `package.json` exit with clear message | `setup.sh` `unsupported` language case (Task 5) |
| Re-running setup never produces duplicate hooks | Duplicate-count tests in `setup.bats` (Task 5) |

### Placeholder Scan

No TBD, TODO, or placeholder content present.

### Type/Name Consistency

Shell function signatures are consistent across all tasks:
- `detect_language <dir>` — 1 arg throughout
- `detect_package_manager <dir>` — 1 arg throughout
- `merge_block <file> <id> <content> [position]` — 3–4 args throughout
- `ensure_hook_exists <file>` — 1 arg throughout
- `is_husky_installed <repo_root>` — 1 arg throughout
- `ensure_husky_installed <repo_root>` — 1 arg throughout
- `ensure_husky_init <repo_root>` — 1 arg throughout
