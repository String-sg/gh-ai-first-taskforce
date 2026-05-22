# Story 11: Type-checking (tsc + go vet) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add type-checking to the harness — tsc (full project) on commit and in CI for JS/mixed repos, go vet (staged packages) on commit and all packages in CI for mixed repos.

**Architecture:** A new `harness/lib/typecheck.sh` library follows the same pattern as `lint.sh` and `format.sh` — functions for bootstrapping tools, writing default configs, and merging pre-commit blocks. `generate_workflow_yaml` in `ci-workflows.sh` gains tsc and go vet CI steps. `setup.sh` sources and calls the new library. All changes follow TDD: red test commit first, then green implementation commit.

**Tech Stack:** bats-core (tests), POSIX sh, TypeScript/tsc via npx, go vet (ships with Go toolchain), Husky merge_block pattern.

**Feature branch:** `feat/story-11-type-checking-tsc-and-go-vet` (create from main before any code changes — see Task 1)

---

## File Map

| Action | Path | Responsibility |
|--------|------|----------------|
| Create | `harness/lib/typecheck.sh` | `ensure_typescript_installed`, `ensure_tsconfig`, `ensure_go_vet_available`, `install_tsc_hook`, `install_go_vet_hook` |
| Create | `tests/harness/typecheck.bats` | Unit tests for all typecheck.sh functions |
| Modify | `harness/lib/ci-workflows.sh` | Add `tsc --noEmit` step (JS+mixed) and `go vet ./...` step (mixed only) to `generate_workflow_yaml` |
| Modify | `tests/harness/ci-workflows.bats` | Tests for new tsc/go vet CI steps |
| Modify | `harness/setup.sh` | Source typecheck.sh; call its functions in js/mixed case |
| Modify | `tests/harness/setup.bats` | Integration tests for tsc/govet hook installation |
| Modify | `harness/README.md` | Add Type-checking section |

---

## Task 1: Create feature branch

**Files:** none

- [ ] **Step 1: Create and switch to feature branch**

  ```bash
  git checkout main && git pull
  git checkout -b feat/story-11-type-checking-tsc-and-go-vet
  ```

  Expected: branch created off latest main.

---

## Task 2: TDD — Failing tests for typecheck.sh library (red)

**Files:**
- Create: `tests/harness/typecheck.bats`

- [ ] **Step 1: Create the failing test file**

  ```bash
  cat > tests/harness/typecheck.bats << 'BATS'
  #!/usr/bin/env bats

  setup() {
    source "$BATS_TEST_DIRNAME/../../harness/lib/detect-package-manager.sh"
    source "$BATS_TEST_DIRNAME/../../harness/lib/merge-hook.sh"
    source "$BATS_TEST_DIRNAME/../../harness/lib/typecheck.sh"
    REPO_DIR=$(mktemp -d)
    MOCK_LOG=$(mktemp)
    export MOCK_LOG
    MOCKS_DIR="$BATS_TEST_DIRNAME/../mocks"
  }

  teardown() {
    rm -rf "$REPO_DIR" "$MOCK_LOG"
  }

  # ── ensure_typescript_installed ──────────────────────────────────────────────

  @test "ensure_typescript_installed: runs pnpm add when typescript absent (pnpm repo)" {
    export PATH="$MOCKS_DIR:$PATH"
    printf '{"devDependencies":{}}\n' > "$REPO_DIR/package.json"
    touch "$REPO_DIR/pnpm-lock.yaml"
    ensure_typescript_installed "$REPO_DIR"
    grep -q "mock-pnpm add -D typescript" "$MOCK_LOG"
  }

  @test "ensure_typescript_installed: runs bun add when typescript absent (bun repo)" {
    export PATH="$MOCKS_DIR:$PATH"
    printf '{"devDependencies":{}}\n' > "$REPO_DIR/package.json"
    touch "$REPO_DIR/bun.lockb"
    ensure_typescript_installed "$REPO_DIR"
    grep -q "mock-bun add -D typescript" "$MOCK_LOG"
  }

  @test "ensure_typescript_installed: skips install when typescript already present" {
    export PATH="$MOCKS_DIR:$PATH"
    printf '{"devDependencies":{"typescript":"^5.0.0"}}\n' > "$REPO_DIR/package.json"
    touch "$REPO_DIR/pnpm-lock.yaml"
    ensure_typescript_installed "$REPO_DIR"
    run grep "mock-pnpm add -D typescript" "$MOCK_LOG"
    [ "$status" -ne 0 ]
  }

  @test "ensure_typescript_installed: exits 1 for unsupported package manager" {
    printf '{"devDependencies":{}}\n' > "$REPO_DIR/package.json"
    run ensure_typescript_installed "$REPO_DIR"
    [ "$status" -eq 1 ]
  }

  # ── ensure_tsconfig ──────────────────────────────────────────────────────────

  @test "ensure_tsconfig: creates tsconfig.json when none exists" {
    printf '{"devDependencies":{}}\n' > "$REPO_DIR/package.json"
    ensure_tsconfig "$REPO_DIR"
    [ -f "$REPO_DIR/tsconfig.json" ]
  }

  @test "ensure_tsconfig: tsconfig.json contains noEmit true" {
    printf '{"devDependencies":{}}\n' > "$REPO_DIR/package.json"
    ensure_tsconfig "$REPO_DIR"
    grep -q '"noEmit": true' "$REPO_DIR/tsconfig.json"
  }

  @test "ensure_tsconfig: tsconfig.json contains strict true" {
    printf '{"devDependencies":{}}\n' > "$REPO_DIR/package.json"
    ensure_tsconfig "$REPO_DIR"
    grep -q '"strict": true' "$REPO_DIR/tsconfig.json"
  }

  @test "ensure_tsconfig: includes vite/client type when vite in package.json" {
    printf '{"devDependencies":{"vite":"^5.0.0"}}\n' > "$REPO_DIR/package.json"
    ensure_tsconfig "$REPO_DIR"
    grep -q '"vite/client"' "$REPO_DIR/tsconfig.json"
  }

  @test "ensure_tsconfig: excludes vite/client type when vite absent" {
    printf '{"devDependencies":{}}\n' > "$REPO_DIR/package.json"
    ensure_tsconfig "$REPO_DIR"
    run grep '"vite/client"' "$REPO_DIR/tsconfig.json"
    [ "$status" -ne 0 ]
  }

  @test "ensure_tsconfig: include uses src when src dir exists" {
    printf '{"devDependencies":{}}\n' > "$REPO_DIR/package.json"
    mkdir "$REPO_DIR/src"
    ensure_tsconfig "$REPO_DIR"
    grep -q '"include": \["src"\]' "$REPO_DIR/tsconfig.json"
  }

  @test "ensure_tsconfig: include uses web when web dir exists and src absent" {
    printf '{"devDependencies":{}}\n' > "$REPO_DIR/package.json"
    mkdir "$REPO_DIR/web"
    ensure_tsconfig "$REPO_DIR"
    grep -q '"include": \["web"\]' "$REPO_DIR/tsconfig.json"
  }

  @test "ensure_tsconfig: include defaults to src when no known dir exists" {
    printf '{"devDependencies":{}}\n' > "$REPO_DIR/package.json"
    ensure_tsconfig "$REPO_DIR"
    grep -q '"include": \["src"\]' "$REPO_DIR/tsconfig.json"
  }

  @test "ensure_tsconfig: skips when tsconfig.json already exists at root" {
    printf '{"devDependencies":{}}\n' > "$REPO_DIR/package.json"
    printf '{"compilerOptions":{"target":"ES5"}}\n' > "$REPO_DIR/tsconfig.json"
    ensure_tsconfig "$REPO_DIR"
    run grep '"target": "ES2022"' "$REPO_DIR/tsconfig.json"
    [ "$status" -ne 0 ]
  }

  @test "ensure_tsconfig: skips when tsconfig.json exists in subdirectory" {
    printf '{"devDependencies":{}}\n' > "$REPO_DIR/package.json"
    mkdir -p "$REPO_DIR/packages/app"
    printf '{"compilerOptions":{}}\n' > "$REPO_DIR/packages/app/tsconfig.json"
    ensure_tsconfig "$REPO_DIR"
    [ ! -f "$REPO_DIR/tsconfig.json" ]
  }

  # ── ensure_go_vet_available ──────────────────────────────────────────────────

  @test "ensure_go_vet_available: returns 0 when go in PATH" {
    local bin_dir="$REPO_DIR/bin"
    mkdir -p "$bin_dir"
    printf '#!/bin/sh\nexit 0\n' > "$bin_dir/go"
    chmod +x "$bin_dir/go"
    export PATH="$bin_dir:/usr/bin:/bin"
    run ensure_go_vet_available
    [ "$status" -eq 0 ]
  }

  @test "ensure_go_vet_available: returns 1 with actionable error when go absent" {
    local empty_dir="$REPO_DIR/empty"
    mkdir -p "$empty_dir"
    local saved_path="$PATH"
    export PATH="$empty_dir"
    run ensure_go_vet_available
    export PATH="$saved_path"
    [ "$status" -eq 1 ]
    [[ "$output" == *"ERROR"* ]]
    [[ "$output" == *"go"* ]]
  }

  # ── install_tsc_hook ─────────────────────────────────────────────────────────

  @test "install_tsc_hook: merges tsc block into pre-commit" {
    mkdir -p "$REPO_DIR/.husky"
    printf '#!/bin/sh\n' > "$REPO_DIR/.husky/pre-commit"
    chmod +x "$REPO_DIR/.husky/pre-commit"
    install_tsc_hook "$REPO_DIR"
    grep -q "# harness:tsc:begin" "$REPO_DIR/.husky/pre-commit"
  }

  @test "install_tsc_hook: pre-commit contains npx tsc --noEmit" {
    mkdir -p "$REPO_DIR/.husky"
    printf '#!/bin/sh\n' > "$REPO_DIR/.husky/pre-commit"
    chmod +x "$REPO_DIR/.husky/pre-commit"
    install_tsc_hook "$REPO_DIR"
    grep -q "npx tsc --noEmit" "$REPO_DIR/.husky/pre-commit"
  }

  @test "install_tsc_hook: pre-commit checks for npx at runtime" {
    mkdir -p "$REPO_DIR/.husky"
    printf '#!/bin/sh\n' > "$REPO_DIR/.husky/pre-commit"
    chmod +x "$REPO_DIR/.husky/pre-commit"
    install_tsc_hook "$REPO_DIR"
    grep -q "command -v npx" "$REPO_DIR/.husky/pre-commit"
  }

  @test "install_tsc_hook: pre-commit errors when no tsconfig.json found" {
    mkdir -p "$REPO_DIR/.husky"
    printf '#!/bin/sh\n' > "$REPO_DIR/.husky/pre-commit"
    chmod +x "$REPO_DIR/.husky/pre-commit"
    install_tsc_hook "$REPO_DIR"
    grep -q "tsconfig.json" "$REPO_DIR/.husky/pre-commit"
  }

  @test "install_tsc_hook: is idempotent on re-run" {
    mkdir -p "$REPO_DIR/.husky"
    printf '#!/bin/sh\n' > "$REPO_DIR/.husky/pre-commit"
    chmod +x "$REPO_DIR/.husky/pre-commit"
    install_tsc_hook "$REPO_DIR"
    install_tsc_hook "$REPO_DIR"
    [ "$(grep -c "harness:tsc:begin" "$REPO_DIR/.husky/pre-commit")" = "1" ]
  }

  # ── install_go_vet_hook ──────────────────────────────────────────────────────

  @test "install_go_vet_hook: merges govet block into pre-commit" {
    mkdir -p "$REPO_DIR/.husky"
    printf '#!/bin/sh\n' > "$REPO_DIR/.husky/pre-commit"
    chmod +x "$REPO_DIR/.husky/pre-commit"
    install_go_vet_hook "$REPO_DIR"
    grep -q "# harness:govet:begin" "$REPO_DIR/.husky/pre-commit"
  }

  @test "install_go_vet_hook: pre-commit contains go vet" {
    mkdir -p "$REPO_DIR/.husky"
    printf '#!/bin/sh\n' > "$REPO_DIR/.husky/pre-commit"
    chmod +x "$REPO_DIR/.husky/pre-commit"
    install_go_vet_hook "$REPO_DIR"
    grep -q "go vet" "$REPO_DIR/.husky/pre-commit"
  }

  @test "install_go_vet_hook: pre-commit checks for go at runtime" {
    mkdir -p "$REPO_DIR/.husky"
    printf '#!/bin/sh\n' > "$REPO_DIR/.husky/pre-commit"
    chmod +x "$REPO_DIR/.husky/pre-commit"
    install_go_vet_hook "$REPO_DIR"
    grep -q "command -v go" "$REPO_DIR/.husky/pre-commit"
  }

  @test "install_go_vet_hook: only runs when staged .go files present" {
    mkdir -p "$REPO_DIR/.husky"
    printf '#!/bin/sh\n' > "$REPO_DIR/.husky/pre-commit"
    chmod +x "$REPO_DIR/.husky/pre-commit"
    install_go_vet_hook "$REPO_DIR"
    grep -q '\.go' "$REPO_DIR/.husky/pre-commit"
  }

  @test "install_go_vet_hook: is idempotent on re-run" {
    mkdir -p "$REPO_DIR/.husky"
    printf '#!/bin/sh\n' > "$REPO_DIR/.husky/pre-commit"
    chmod +x "$REPO_DIR/.husky/pre-commit"
    install_go_vet_hook "$REPO_DIR"
    install_go_vet_hook "$REPO_DIR"
    [ "$(grep -c "harness:govet:begin" "$REPO_DIR/.husky/pre-commit")" = "1" ]
  }
  BATS
  ```

- [ ] **Step 2: Verify tests fail (typecheck.sh does not yet exist)**

  Run: `bats tests/harness/typecheck.bats`

  Expected: all tests FAIL with `source: ... typecheck.sh: No such file or directory` or similar.

- [ ] **Step 3: Commit the red tests**

  ```bash
  git add tests/harness/typecheck.bats
  git commit -m "test: add failing typecheck.bats unit tests for typecheck.sh (TDD red)"
  ```

---

## Task 3: Implement typecheck.sh (green)

**Files:**
- Create: `harness/lib/typecheck.sh`

- [ ] **Step 1: Create the library file**

  Create `harness/lib/typecheck.sh` with exactly this content:

  ```sh
  # Requires detect_package_manager() from detect-package-manager.sh
  # and merge_block() from merge-hook.sh to be sourced before this file.

  ensure_typescript_installed() {
    local repo_root="$1"
    if grep -qE '"typescript"\s*:' "$repo_root/package.json" 2>/dev/null; then
      return 0
    fi
    local pm
    pm=$(detect_package_manager "$repo_root")
    case "$pm" in
      pnpm) (cd "$repo_root" && pnpm add -D typescript) ;;
      bun)  (cd "$repo_root" && bun add -D typescript) ;;
      *)
        echo "ERROR: Unsupported package manager" >&2
        return 1
        ;;
    esac
  }

  # ensure_tsconfig <repo_root>
  # Writes a default tsconfig.json if no tsconfig.json exists anywhere in the project
  # (excluding node_modules). Auto-detects source directory (src/, web/, app/) and
  # whether vite is present in package.json.
  ensure_tsconfig() {
    local repo_root="$1"
    local existing
    existing=$(find "$repo_root" -maxdepth 3 -name 'tsconfig.json' \
      -not -path '*/node_modules/*' 2>/dev/null | head -1)
    [ -n "$existing" ] && return 0

    local src_dir="src"
    for candidate in src web app; do
      [ -d "$repo_root/$candidate" ] && src_dir="$candidate" && break
    done

    local has_vite=0
    grep -q '"vite"' "$repo_root/package.json" 2>/dev/null && has_vite=1

    {
      printf '{\n'
      printf '  "compilerOptions": {\n'
      printf '    "target": "ES2022",\n'
      printf '    "useDefineForClassFields": true,\n'
      printf '    "lib": ["ES2022", "DOM", "DOM.Iterable"],\n'
      printf '    "module": "ESNext",\n'
      [ "$has_vite" = "1" ] && printf '    "types": ["vite/client"],\n'
      printf '    "skipLibCheck": true,\n'
      printf '\n'
      printf '    "moduleResolution": "bundler",\n'
      printf '    "allowImportingTsExtensions": true,\n'
      printf '    "verbatimModuleSyntax": true,\n'
      printf '    "moduleDetection": "force",\n'
      printf '    "noEmit": true,\n'
      printf '    "jsx": "react-jsx",\n'
      printf '\n'
      printf '    "strict": true,\n'
      printf '    "noUnusedLocals": true,\n'
      printf '    "noUnusedParameters": true,\n'
      printf '    "erasableSyntaxOnly": true,\n'
      printf '    "noFallthroughCasesInSwitch": true,\n'
      printf '    "noUncheckedSideEffectImports": true\n'
      printf '  },\n'
      printf '  "include": ["%s"]\n' "$src_dir"
      printf '}\n'
    } > "$repo_root/tsconfig.json"
    echo "Created default tsconfig.json (include: [\"$src_dir\"])"
  }

  # ensure_go_vet_available
  # go vet ships with the Go toolchain — no installation needed.
  # Fails with an actionable error if Go is not installed.
  ensure_go_vet_available() {
    if command -v go >/dev/null 2>&1; then
      return 0
    fi
    echo "ERROR: go not found. go vet requires the Go toolchain. Install Go: https://go.dev/dl/" >&2
    return 1
  }

  # install_tsc_hook <repo_root>
  # Merges the tsc --noEmit pre-commit block (JS and mixed repos).
  # Full-project check on every commit. Handles monorepos: uses project references
  # if a root tsconfig.json with "references" exists; otherwise iterates all configs.
  install_tsc_hook() {
    local repo_root="$1"
    local tsc_block='# harness:tsc:begin
  if ! command -v npx >/dev/null 2>&1; then
    echo "ERROR: npx not found. Ensure nvm is configured and re-run: gh ai-first-taskforce setup" >&2
    exit 1
  fi
  _TSC_LIST=$(mktemp)
  find . -name tsconfig.json -not -path "*/node_modules/*" | sort > "$_TSC_LIST"
  if [ ! -s "$_TSC_LIST" ]; then
    rm -f "$_TSC_LIST"
    echo "ERROR: No tsconfig.json found. Run: gh ai-first-taskforce setup" >&2
    exit 1
  fi
  if [ -f ./tsconfig.json ] && grep -q references ./tsconfig.json; then
    rm -f "$_TSC_LIST"
    npx tsc --noEmit || exit 1
  else
    _TSC_FAIL=0
    while IFS= read -r _cfg; do
      npx tsc --noEmit -p "$_cfg" || _TSC_FAIL=1
    done < "$_TSC_LIST"
    rm -f "$_TSC_LIST"
    [ "$_TSC_FAIL" = "0" ] || exit 1
    unset _TSC_FAIL _cfg
  fi
  unset _TSC_LIST
  # harness:tsc:end'
    merge_block "$repo_root/.husky/pre-commit" "tsc" "$tsc_block" "append"
  }

  # install_go_vet_hook <repo_root>
  # Merges the go vet pre-commit block (mixed repos only).
  # Runs go vet on the packages containing staged Go files.
  install_go_vet_hook() {
    local repo_root="$1"
    local govet_block='# harness:govet:begin
  _STAGED_GO=$(git diff --cached --name-only --diff-filter=ACM | grep '"'"'\.go$'"'"' || true)
  if [ -n "$_STAGED_GO" ]; then
    if ! command -v go >/dev/null 2>&1; then
      echo "ERROR: go not found. Install Go: https://go.dev/dl/" >&2
      exit 1
    fi
    _VET_DIRS=$(mktemp)
    echo "$_STAGED_GO" | xargs dirname | sort -u > "$_VET_DIRS"
    _VET_FAIL=0
    while IFS= read -r _dir; do
      go vet "./$_dir" || _VET_FAIL=1
    done < "$_VET_DIRS"
    rm -f "$_VET_DIRS"
    [ "$_VET_FAIL" = "0" ] || exit 1
    unset _VET_DIRS _VET_FAIL _dir
  fi
  unset _STAGED_GO
  # harness:govet:end'
    merge_block "$repo_root/.husky/pre-commit" "govet" "$govet_block" "append"
  }
  ```

  > **Note on shell quoting:** The `'\.go$'` inside `install_go_vet_hook`'s single-quoted string is encoded as `'"'"'\.go$'"'"'`. The outer single-quote string is broken around each embedded single-quote using the `'"'"'` pattern (end single-quote + double-quoted single-quote + reopen single-quote).

- [ ] **Step 2: Run unit tests — verify they pass**

  Run: `bats tests/harness/typecheck.bats`

  Expected: all tests PASS.

- [ ] **Step 3: Commit the implementation**

  ```bash
  git add harness/lib/typecheck.sh
  git commit -m "feat: add typecheck.sh — ensure_typescript_installed, ensure_tsconfig, ensure_go_vet_available, install_tsc_hook, install_go_vet_hook"
  ```

---

## Task 4: TDD — Failing tests for CI workflow tsc/go vet steps (red)

**Files:**
- Modify: `tests/harness/ci-workflows.bats`

- [ ] **Step 1: Append the four failing tests to ci-workflows.bats**

  Add these tests at the end of `tests/harness/ci-workflows.bats` (after the last `detect_overlapping_workflows` test block):

  ```bats
  # ── generate_workflow_yaml: type-check steps ────────────────────────────────

  @test "generate_workflow_yaml js pnpm: contains tsc --noEmit, not go vet" {
    run generate_workflow_yaml "js" "pnpm"
    [ "$status" -eq 0 ]
    [[ "$output" == *"tsc --noEmit"* ]]
    [[ "$output" != *"go vet"* ]]
  }

  @test "generate_workflow_yaml js bun: contains tsc --noEmit, not go vet" {
    run generate_workflow_yaml "js" "bun"
    [ "$status" -eq 0 ]
    [[ "$output" == *"tsc --noEmit"* ]]
    [[ "$output" != *"go vet"* ]]
  }

  @test "generate_workflow_yaml mixed pnpm: contains tsc --noEmit and go vet ./..." {
    run generate_workflow_yaml "mixed" "pnpm"
    [ "$status" -eq 0 ]
    [[ "$output" == *"tsc --noEmit"* ]]
    [[ "$output" == *"go vet ./..."* ]]
  }

  @test "generate_workflow_yaml mixed bun: contains tsc --noEmit and go vet ./..." {
    run generate_workflow_yaml "mixed" "bun"
    [ "$status" -eq 0 ]
    [[ "$output" == *"tsc --noEmit"* ]]
    [[ "$output" == *"go vet ./..."* ]]
  }
  ```

- [ ] **Step 2: Run ci-workflows.bats — verify new tests fail**

  Run: `bats tests/harness/ci-workflows.bats`

  Expected: the four new tests FAIL (`tsc --noEmit` not yet in workflow output), existing tests pass.

- [ ] **Step 3: Commit the red tests**

  ```bash
  git add tests/harness/ci-workflows.bats
  git commit -m "test: add failing generate_workflow_yaml tests for tsc and go vet CI steps (TDD red)"
  ```

---

## Task 5: Update generate_workflow_yaml for tsc and go vet (green)

**Files:**
- Modify: `harness/lib/ci-workflows.sh`

- [ ] **Step 1: Add tsc step after the Prettier step (applies to both js and mixed)**

  In `harness/lib/ci-workflows.sh`, find the block that ends with the Prettier step (around line 82):

  ```sh
    cat <<'YAML'

        - name: Format (Prettier)
          run: npx prettier --check .
  YAML
  ```

  Add a new `cat` block immediately after it, before the `if [ "$lang" = "mixed" ]` check:

  ```sh
    cat <<'YAML'

        - name: Type-check (tsc)
          run: npx tsc --noEmit
  YAML
  ```

- [ ] **Step 2: Add go vet step inside the mixed block after the goimports check**

  Find the end of the goimports step inside the `if [ "$lang" = "mixed" ]` block (around line 116):

  ```sh
        - name: Format (goimports)
          run: |
            unformatted=$(goimports -l .)
            if [ -n "$unformatted" ]; then
              echo "The following files need import formatting:"
              echo "$unformatted"
              exit 1
            fi
  YAML
    fi
  ```

  Add a go vet step before the closing `YAML` and `fi`:

  ```sh
        - name: Format (goimports)
          run: |
            unformatted=$(goimports -l .)
            if [ -n "$unformatted" ]; then
              echo "The following files need import formatting:"
              echo "$unformatted"
              exit 1
            fi

        - name: Type-check (go vet)
          run: go vet ./...
  YAML
    fi
  ```

- [ ] **Step 3: Run ci-workflows.bats — verify all tests pass**

  Run: `bats tests/harness/ci-workflows.bats`

  Expected: all tests PASS (including the 4 new ones).

- [ ] **Step 4: Commit the implementation**

  ```bash
  git add harness/lib/ci-workflows.sh
  git commit -m "feat: add tsc --noEmit and go vet ./... steps to generated CI workflow"
  ```

---

## Task 6: TDD — Failing setup.bats integration tests for typecheck (red)

**Files:**
- Modify: `tests/harness/setup.bats`

- [ ] **Step 1: Append integration tests to setup.bats**

  Add these tests at the end of `tests/harness/setup.bats`:

  ```bats
  @test "merges tsc block into pre-commit for JS repo" {
    _pnpm_repo_with_hooks
    run bash "$SETUP_SCRIPT" "$REPO_DIR"
    [ "$status" -eq 0 ]
    grep -q "# harness:tsc:begin" "$REPO_DIR/.husky/pre-commit"
  }

  @test "merges tsc block into pre-commit for mixed repo" {
    _pnpm_repo_with_hooks
    touch "$REPO_DIR/go.mod"
    run bash "$SETUP_SCRIPT" "$REPO_DIR"
    [ "$status" -eq 0 ]
    grep -q "# harness:tsc:begin" "$REPO_DIR/.husky/pre-commit"
  }

  @test "merges govet block into pre-commit for mixed repo" {
    _pnpm_repo_with_hooks
    touch "$REPO_DIR/go.mod"
    run bash "$SETUP_SCRIPT" "$REPO_DIR"
    [ "$status" -eq 0 ]
    grep -q "# harness:govet:begin" "$REPO_DIR/.husky/pre-commit"
  }

  @test "does not merge govet block for JS-only repo" {
    _pnpm_repo_with_hooks
    run bash "$SETUP_SCRIPT" "$REPO_DIR"
    [ "$status" -eq 0 ]
    run grep "# harness:govet:begin" "$REPO_DIR/.husky/pre-commit"
    [ "$status" -ne 0 ]
  }

  @test "creates tsconfig.json for JS repo when absent" {
    _pnpm_repo_with_hooks
    run bash "$SETUP_SCRIPT" "$REPO_DIR"
    [ "$status" -eq 0 ]
    [ -f "$REPO_DIR/tsconfig.json" ]
  }

  @test "re-run does not duplicate tsc block in pre-commit" {
    _pnpm_repo_with_hooks
    bash "$SETUP_SCRIPT" "$REPO_DIR"
    bash "$SETUP_SCRIPT" "$REPO_DIR"
    [ "$(grep -c "harness:tsc:begin" "$REPO_DIR/.husky/pre-commit")" = "1" ]
  }

  @test "re-run does not duplicate govet block for mixed repo" {
    _pnpm_repo_with_hooks
    touch "$REPO_DIR/go.mod"
    bash "$SETUP_SCRIPT" "$REPO_DIR"
    bash "$SETUP_SCRIPT" "$REPO_DIR"
    [ "$(grep -c "harness:govet:begin" "$REPO_DIR/.husky/pre-commit")" = "1" ]
  }
  ```

- [ ] **Step 2: Run setup.bats — verify new tests fail**

  Run: `bats tests/harness/setup.bats`

  Expected: the 7 new tests FAIL (setup.sh doesn't call typecheck functions yet), existing tests pass.

- [ ] **Step 3: Commit the red tests**

  ```bash
  git add tests/harness/setup.bats
  git commit -m "test: add failing setup.bats integration tests for typecheck hooks (TDD red)"
  ```

---

## Task 7: Wire typecheck.sh into setup.sh (green)

**Files:**
- Modify: `harness/setup.sh`

- [ ] **Step 1: Source typecheck.sh in setup.sh**

  In `harness/setup.sh`, find the block that sources the lib files (lines 7–13):

  ```sh
  . "$SCRIPT_DIR/lib/detect-language.sh"
  . "$SCRIPT_DIR/lib/detect-package-manager.sh"
  . "$SCRIPT_DIR/lib/merge-hook.sh"
  . "$SCRIPT_DIR/lib/husky.sh"
  . "$SCRIPT_DIR/lib/ci-workflows.sh"
  . "$SCRIPT_DIR/lib/lint.sh"
  . "$SCRIPT_DIR/lib/format.sh"
  ```

  Add `. "$SCRIPT_DIR/lib/typecheck.sh"` after `format.sh`:

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

- [ ] **Step 2: Add typecheck calls to the js|mixed case in setup.sh**

  Find the `js|mixed` case block (the section with `ensure_eslint_installed`, `ensure_prettier_installed`, etc.) and add the typecheck calls after `install_gofmt_hook` and before `detect_overlapping_workflows`.

  Current end of the `js|mixed` block (lines 36–47):

  ```sh
      install_lint_staged_hook "$REPO_ROOT"
      install_prettier_staged "$REPO_ROOT"
      if [ "$REPO_LANG" = "mixed" ]; then
        ensure_golangci_lint_available
        ensure_golangci_config "$REPO_ROOT"
        install_golangci_hook "$REPO_ROOT"
        ensure_goimports_available
        install_gofmt_hook "$REPO_ROOT"
      fi
      detect_overlapping_workflows "$REPO_ROOT"
  ```

  Replace with:

  ```sh
      install_lint_staged_hook "$REPO_ROOT"
      install_prettier_staged "$REPO_ROOT"
      if [ "$REPO_LANG" = "mixed" ]; then
        ensure_golangci_lint_available
        ensure_golangci_config "$REPO_ROOT"
        install_golangci_hook "$REPO_ROOT"
        ensure_goimports_available
        install_gofmt_hook "$REPO_ROOT"
      fi
      ensure_typescript_installed "$REPO_ROOT"
      ensure_tsconfig "$REPO_ROOT"
      install_tsc_hook "$REPO_ROOT"
      if [ "$REPO_LANG" = "mixed" ]; then
        ensure_go_vet_available
        install_go_vet_hook "$REPO_ROOT"
      fi
      detect_overlapping_workflows "$REPO_ROOT"
  ```

- [ ] **Step 3: Run setup.bats — verify all tests pass**

  Run: `bats tests/harness/setup.bats`

  Expected: all tests PASS (including the 7 new integration tests).

- [ ] **Step 4: Run the full test suite to check for regressions**

  Run: `bats tests/harness/`

  Expected: all tests PASS with no regressions.

- [ ] **Step 5: Commit the implementation**

  ```bash
  git add harness/setup.sh
  git commit -m "feat: wire typecheck.sh into setup.sh — tsc and go vet hooks for JS and mixed repos"
  ```

---

## Task 8: Update harness/README.md

**Files:**
- Modify: `harness/README.md`

- [ ] **Step 1: Add a Type-checking section after the Formatting section**

  In `harness/README.md`, find the line `## Directory structure` and insert the following before it:

  ```markdown
  ## Type-checking

  Setup installs type-checking tools and default configs if absent, then merges type-check hooks into `.husky/pre-commit`.

  ### JS / TS repos

  - Installs `typescript` as a dev dependency (if not already present)
  - Writes a default `tsconfig.json` if none exists anywhere in the project (excludes `node_modules`):
    - Detects source directory (`src/`, `web/`, `app/`; defaults to `src`)
    - Includes `"types": ["vite/client"]` only when `vite` is detected in `package.json`
    - Sets `"noEmit": true`, `"strict": true`, and the full recommended strictness flags
  - Merges a `harness:tsc` pre-commit block that runs `tsc --noEmit` against the **full project** on every commit (not staged-only — tsc requires whole-project context)
  - Monorepo support: if a root `tsconfig.json` with `"references"` exists, runs a single `tsc --noEmit`; otherwise iterates all `tsconfig.json` files found in the project

  ### Mixed (Go + JS/TS) repos

  All of the above, plus:

  - Confirms `go` is available in PATH (required for `go vet`, which ships with the Go toolchain); fails with an actionable error if Go is not installed
  - Merges a `harness:govet` pre-commit block that runs `go vet` on packages containing staged `.go` files only

  Type-check failure exits non-zero, blocks the commit, and outputs which check failed. No auto-fix — hooks run in check mode only.

  ```

- [ ] **Step 2: Update the Directory structure table to include typecheck.sh**

  Find the directory structure code block in the README and add `typecheck.sh` to the lib listing:

  ```
  harness/
    setup.sh          # Orchestrator — called by gh-ai-first-taskforce
    lib/
      detect-language.sh          # detect_language <dir>
      detect-package-manager.sh   # detect_package_manager <dir>
      merge-hook.sh               # merge_block, ensure_hook_exists
      husky.sh                    # ensure_husky_installed, ensure_husky_init
      ci-workflows.sh             # generate_workflow_yaml, install_workflow_file, detect_overlapping_workflows
      lint.sh                     # ensure_eslint_installed, ensure_golangci_lint_available, install_lint_staged_hook, install_golangci_hook
      format.sh                   # ensure_prettier_installed, ensure_prettier_config, install_prettier_staged, ensure_goimports_available, install_gofmt_hook
      typecheck.sh                # ensure_typescript_installed, ensure_tsconfig, ensure_go_vet_available, install_tsc_hook, install_go_vet_hook
  ```

- [ ] **Step 3: Commit the docs update**

  ```bash
  git add harness/README.md
  git commit -m "docs: add Type-checking section and typecheck.sh to harness/README.md"
  ```

---

## Self-Review

### Spec Coverage

| AC | Task that covers it |
|----|---------------------|
| Installs `typescript` as dev dep, writes default `tsconfig.json`, auto-detects source dir and Vite | Task 3 (`ensure_typescript_installed`, `ensure_tsconfig`) + Task 7 (wired into setup.sh) |
| For mixed repos, confirms `go vet` available with clear error if Go missing | Task 3 (`ensure_go_vet_available`) + Task 7 |
| Husky pre-commit hook runs `tsc --noEmit` against full project | Task 3 (`install_tsc_hook`) + Task 7 |
| Monorepos: all `tsconfig.json` files checked, one failure blocks commit | Task 3 (loop in `install_tsc_hook` hook content) |
| Mixed repos: `go vet` on staged packages only; absent for JS-only repos | Task 3 (`install_go_vet_hook`) + Task 7 (mixed-only guard) |
| Type-check failure exits non-zero, blocks commit, outputs clear error | Task 3 (hook content design) |
| CI workflow runs `tsc --noEmit` and `go vet ./...` (mixed) on every PR | Task 5 (`generate_workflow_yaml`) |
| CI type-check is required status check | Satisfied by existing `harness / checks` job name + Task 5 |
| If `tsc` missing or no `tsconfig.json` at hook runtime, fail with actionable error | Task 3 (hook content: checks `command -v npx` and `tsconfig.json` existence) |

All acceptance criteria are covered.

### Placeholder Scan

No TBDs, TODOs, or vague steps — every step includes exact file paths, complete code, and expected output.

### Type Consistency

- `install_tsc_hook` uses block ID `"tsc"` → sentinel is `harness:tsc:begin` (consistent across typecheck.sh, typecheck.bats, setup.bats)
- `install_go_vet_hook` uses block ID `"govet"` → sentinel is `harness:govet:begin` (consistent throughout)
- `ensure_typescript_installed` / `ensure_tsconfig` / `ensure_go_vet_available` follow the exact naming convention of `lint.sh` and `format.sh` analogues
