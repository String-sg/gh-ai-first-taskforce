# CI Workflow Scaffolding Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend the harness setup script to install a dedicated GitHub Actions workflow file into target repos, track installed versions with a lockfile, apply delta updates on re-run, and warn when existing team workflows overlap with harness-owned checks.

**Architecture:** A new `harness/lib/ci-workflows.sh` library provides four functions — SHA-256 hashing, manifest read/write, `install_workflow_file`, and `detect_overlapping_workflows` — all sourced and called by `setup.sh` after Husky hook setup. The template workflow lives at `harness/workflows/harness-checks.yml` and is copied into `.github/workflows/` in each target repo; `.github/harness-manifest.json` records the SHA-256 of the installed template so re-runs skip unchanged files. Overlap detection scans existing team workflows for keywords the harness will own (eslint, prettier, tsc, golangci-lint, gitleaks) and warns with migration guidance.

**Tech Stack:** POSIX sh, bats-core (tests), GitHub Actions YAML, sha256sum / shasum

---

## File Map

| Action | Path | Responsibility |
|--------|------|----------------|
| Create | `harness/lib/ci-workflows.sh` | `_sha256`, `_read_manifest_checksum`, `_write_manifest_entry`, `install_workflow_file`, `detect_overlapping_workflows` |
| Create | `harness/workflows/harness-checks.yml` | Template workflow installed into target repos |
| Create | `tests/harness/ci-workflows.bats` | Unit tests for all ci-workflows.sh functions |
| Modify | `harness/setup.sh` | Source ci-workflows.sh; call detect + install after Husky |
| Modify | `tests/harness/setup.bats` | Add integration assertions for workflow install |
| Modify | `harness/README.md` | Document CI scaffolding, manifest, and overlap detection |

---

### Task 1: Create the workflow template

**Files:**
- Create: `harness/workflows/harness-checks.yml`

This template is copied verbatim into target repos. Its checksum is what the manifest tracks. Stories #9–#14 will extend it with actual check steps.

- [ ] **Step 1: Create `harness/workflows/harness-checks.yml`**

```yaml
name: Harness Checks

on:
  push:
  pull_request:

jobs:
  harness:
    name: harness / checks
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
```

- [ ] **Step 2: Commit**

```bash
git add harness/workflows/harness-checks.yml
git commit -m "feat: add harness-checks.yml workflow template"
```

---

### Task 2: Write failing tests for `_sha256` and manifest helpers

**Files:**
- Create: `tests/harness/ci-workflows.bats`

- [ ] **Step 1: Create `tests/harness/ci-workflows.bats` with failing tests**

```bash
#!/usr/bin/env bats

setup() {
  source "$BATS_TEST_DIRNAME/../../harness/lib/ci-workflows.sh"
  REPO_DIR=$(mktemp -d)
}

teardown() {
  rm -rf "$REPO_DIR"
}

# ── _sha256 ──────────────────────────────────────────────────────────────

@test "_sha256: returns a 64-char lowercase hex string" {
  local tmp
  tmp=$(mktemp)
  printf 'hello\n' > "$tmp"
  run _sha256 "$tmp"
  rm -f "$tmp"
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^[a-f0-9]{64}$ ]]
}

# ── _read_manifest_checksum ──────────────────────────────────────────────

@test "_read_manifest_checksum: returns empty for missing manifest" {
  run _read_manifest_checksum "/nonexistent/manifest.json" ".github/workflows/harness-checks.yml"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "_read_manifest_checksum: returns checksum for existing entry" {
  local manifest="$REPO_DIR/.github/harness-manifest.json"
  mkdir -p "$(dirname "$manifest")"
  printf '{\n  "harness_version": "1",\n  "files": {\n    ".github/workflows/harness-checks.yml": "abc123def456abc123def456abc123def456abc123def456abc123def456abc1"\n  }\n}\n' \
    > "$manifest"
  run _read_manifest_checksum "$manifest" ".github/workflows/harness-checks.yml"
  [ "$status" -eq 0 ]
  [ "$output" = "abc123def456abc123def456abc123def456abc123def456abc123def456abc1" ]
}

@test "_read_manifest_checksum: returns empty when path not in manifest" {
  local manifest="$REPO_DIR/.github/harness-manifest.json"
  mkdir -p "$(dirname "$manifest")"
  printf '{\n  "harness_version": "1",\n  "files": {}\n}\n' > "$manifest"
  run _read_manifest_checksum "$manifest" ".github/workflows/harness-checks.yml"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# ── _write_manifest_entry ────────────────────────────────────────────────

@test "_write_manifest_entry: creates manifest with correct JSON structure" {
  local manifest="$REPO_DIR/.github/harness-manifest.json"
  _write_manifest_entry "$manifest" ".github/workflows/harness-checks.yml" \
    "abc123def456abc123def456abc123def456abc123def456abc123def456abc1"
  [ -f "$manifest" ]
  grep -q '"harness_version": "1"' "$manifest"
  grep -q '".github/workflows/harness-checks.yml"' "$manifest"
  grep -q '"abc123def456abc123def456abc123def456abc123def456abc123def456abc1"' "$manifest"
}

@test "_write_manifest_entry: round-trips through _read_manifest_checksum" {
  local manifest="$REPO_DIR/.github/harness-manifest.json"
  _write_manifest_entry "$manifest" ".github/workflows/harness-checks.yml" \
    "aaa000aaa000aaa000aaa000aaa000aaa000aaa000aaa000aaa000aaa000aaa0"
  run _read_manifest_checksum "$manifest" ".github/workflows/harness-checks.yml"
  [ "$output" = "aaa000aaa000aaa000aaa000aaa000aaa000aaa000aaa000aaa000aaa000aaa0" ]
}

@test "_write_manifest_entry: second write updates the checksum" {
  local manifest="$REPO_DIR/.github/harness-manifest.json"
  _write_manifest_entry "$manifest" ".github/workflows/harness-checks.yml" \
    "aaa000aaa000aaa000aaa000aaa000aaa000aaa000aaa000aaa000aaa000aaa0"
  _write_manifest_entry "$manifest" ".github/workflows/harness-checks.yml" \
    "bbb111bbb111bbb111bbb111bbb111bbb111bbb111bbb111bbb111bbb111bbb1"
  run _read_manifest_checksum "$manifest" ".github/workflows/harness-checks.yml"
  [ "$output" = "bbb111bbb111bbb111bbb111bbb111bbb111bbb111bbb111bbb111bbb111bbb1" ]
}

# ── install_workflow_file ────────────────────────────────────────────────

@test "install_workflow_file: creates .github/workflows/harness-checks.yml on first run" {
  local harness_dir="$BATS_TEST_DIRNAME/../../harness"
  install_workflow_file "$REPO_DIR" "$harness_dir"
  [ -f "$REPO_DIR/.github/workflows/harness-checks.yml" ]
}

@test "install_workflow_file: creates .github/harness-manifest.json on first run" {
  local harness_dir="$BATS_TEST_DIRNAME/../../harness"
  install_workflow_file "$REPO_DIR" "$harness_dir"
  [ -f "$REPO_DIR/.github/harness-manifest.json" ]
}

@test "install_workflow_file: manifest checksum matches template" {
  local harness_dir="$BATS_TEST_DIRNAME/../../harness"
  install_workflow_file "$REPO_DIR" "$harness_dir"
  local expected
  expected=$(_sha256 "$harness_dir/workflows/harness-checks.yml")
  run _read_manifest_checksum "$REPO_DIR/.github/harness-manifest.json" \
    ".github/workflows/harness-checks.yml"
  [ "$output" = "$expected" ]
}

@test "install_workflow_file: is silent on re-run with unchanged template" {
  local harness_dir="$BATS_TEST_DIRNAME/../../harness"
  install_workflow_file "$REPO_DIR" "$harness_dir"
  run install_workflow_file "$REPO_DIR" "$harness_dir"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "install_workflow_file: prints Installed and updates manifest when checksum is stale" {
  local harness_dir="$BATS_TEST_DIRNAME/../../harness"
  install_workflow_file "$REPO_DIR" "$harness_dir"
  _write_manifest_entry "$REPO_DIR/.github/harness-manifest.json" \
    ".github/workflows/harness-checks.yml" \
    "0000000000000000000000000000000000000000000000000000000000000000"
  run install_workflow_file "$REPO_DIR" "$harness_dir"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Installed"* ]]
}

# ── detect_overlapping_workflows ─────────────────────────────────────────

@test "detect_overlapping_workflows: no output when .github/workflows absent" {
  run detect_overlapping_workflows "$REPO_DIR"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "detect_overlapping_workflows: no output for empty workflows dir" {
  mkdir -p "$REPO_DIR/.github/workflows"
  run detect_overlapping_workflows "$REPO_DIR"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "detect_overlapping_workflows: warns when workflow contains eslint" {
  mkdir -p "$REPO_DIR/.github/workflows"
  printf 'name: CI\njobs:\n  lint:\n    steps:\n      - run: npx eslint .\n' \
    > "$REPO_DIR/.github/workflows/ci.yml"
  run detect_overlapping_workflows "$REPO_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" == *"WARNING"* ]]
  [[ "$output" == *"ci.yml"* ]]
}

@test "detect_overlapping_workflows: warns when workflow contains prettier" {
  mkdir -p "$REPO_DIR/.github/workflows"
  printf 'name: CI\njobs:\n  fmt:\n    steps:\n      - run: prettier --check .\n' \
    > "$REPO_DIR/.github/workflows/ci.yml"
  run detect_overlapping_workflows "$REPO_DIR"
  [[ "$output" == *"WARNING"* ]]
}

@test "detect_overlapping_workflows: warns when workflow contains golangci-lint" {
  mkdir -p "$REPO_DIR/.github/workflows"
  printf 'name: Go\njobs:\n  lint:\n    steps:\n      - run: golangci-lint run\n' \
    > "$REPO_DIR/.github/workflows/go.yml"
  run detect_overlapping_workflows "$REPO_DIR"
  [[ "$output" == *"WARNING"* ]]
}

@test "detect_overlapping_workflows: does not warn for harness-checks.yml itself" {
  mkdir -p "$REPO_DIR/.github/workflows"
  printf 'name: Harness\njobs:\n  harness:\n    steps:\n      - run: npx eslint .\n' \
    > "$REPO_DIR/.github/workflows/harness-checks.yml"
  run detect_overlapping_workflows "$REPO_DIR"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "detect_overlapping_workflows: no warning for unrelated workflow content" {
  mkdir -p "$REPO_DIR/.github/workflows"
  printf 'name: Deploy\njobs:\n  deploy:\n    steps:\n      - run: echo deploying\n' \
    > "$REPO_DIR/.github/workflows/deploy.yml"
  run detect_overlapping_workflows "$REPO_DIR"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
```

- [ ] **Step 2: Run the tests to confirm they all fail (ci-workflows.sh does not exist yet)**

```bash
bats tests/harness/ci-workflows.bats
```

Expected: all tests FAIL with `source: ... No such file or directory` or similar.

---

### Task 3: Implement `harness/lib/ci-workflows.sh`

**Files:**
- Create: `harness/lib/ci-workflows.sh`

- [ ] **Step 1: Create `harness/lib/ci-workflows.sh`**

```sh
# _sha256 <file>: cross-platform SHA-256 hex digest
_sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | cut -d' ' -f1
  else
    shasum -a 256 "$1" | cut -d' ' -f1
  fi
}

# _read_manifest_checksum <manifest_file> <relative_path>
# Prints the stored SHA-256 for <relative_path>, or empty string if absent.
_read_manifest_checksum() {
  local manifest_file="$1" path="$2"
  [ -f "$manifest_file" ] || return 0
  grep -F "\"$path\"" "$manifest_file" | grep -oE '[a-f0-9]{64}' | head -1
}

# _write_manifest_entry <manifest_file> <relative_path> <checksum>
# Writes (or rewrites) a single-entry harness-manifest.json.
# Note: rewrites the full file — extend for multi-file manifests in later stories.
_write_manifest_entry() {
  local manifest_file="$1" path="$2" checksum="$3"
  mkdir -p "$(dirname "$manifest_file")"
  printf '{\n  "harness_version": "1",\n  "files": {\n    "%s": "%s"\n  }\n}\n' \
    "$path" "$checksum" > "$manifest_file"
}

# install_workflow_file <repo_root> <harness_dir>
# Copies harness/workflows/harness-checks.yml into .github/workflows/ if the
# template checksum differs from the manifest entry (delta update).
install_workflow_file() {
  local repo_root="$1" harness_dir="$2"
  local template="$harness_dir/workflows/harness-checks.yml"
  local rel_path=".github/workflows/harness-checks.yml"
  local dest="$repo_root/$rel_path"
  local manifest="$repo_root/.github/harness-manifest.json"

  local current_checksum
  current_checksum=$(_sha256 "$template")

  local installed_checksum
  installed_checksum=$(_read_manifest_checksum "$manifest" "$rel_path")

  if [ "$current_checksum" = "$installed_checksum" ] && [ -f "$dest" ]; then
    return 0
  fi

  mkdir -p "$(dirname "$dest")"
  cp "$template" "$dest"
  _write_manifest_entry "$manifest" "$rel_path" "$current_checksum"
  echo "Installed $rel_path"
}

# detect_overlapping_workflows <repo_root>
# Warns if any existing non-harness workflow contains keywords harness will own.
detect_overlapping_workflows() {
  local repo_root="$1"
  local workflows_dir="$repo_root/.github/workflows"
  [ -d "$workflows_dir" ] || return 0

  for wf in "$workflows_dir"/*.yml "$workflows_dir"/*.yaml; do
    [ -f "$wf" ] || continue
    case "$(basename "$wf")" in harness-checks.yml) continue ;; esac
    if grep -qiE 'eslint|prettier|tsc|golangci.lint|gitleaks' "$wf" 2>/dev/null; then
      echo "WARNING: $(basename "$wf") contains checks that harness will own."
      echo "  To migrate: remove those steps from $(basename "$wf") and re-run setup."
      echo "  harness-checks.yml will run the same checks automatically."
    fi
  done
}
```

- [ ] **Step 2: Run the tests to verify they pass**

```bash
bats tests/harness/ci-workflows.bats
```

Expected: all tests PASS.

- [ ] **Step 3: Commit**

```bash
git add harness/lib/ci-workflows.sh tests/harness/ci-workflows.bats
git commit -m "feat: add ci-workflows.sh with install and overlap detection"
```

---

### Task 4: Wire ci-workflows.sh into setup.sh

**Files:**
- Modify: `harness/setup.sh`
- Modify: `tests/harness/setup.bats`

- [ ] **Step 1: Write the new setup.bats tests first (TDD)**

Append these tests to `tests/harness/setup.bats`:

```bash
@test "installs .github/workflows/harness-checks.yml into target repo" {
  _pnpm_repo_with_hooks
  run bash "$SETUP_SCRIPT" "$REPO_DIR"
  [ "$status" -eq 0 ]
  [ -f "$REPO_DIR/.github/workflows/harness-checks.yml" ]
}

@test "creates .github/harness-manifest.json in target repo" {
  _pnpm_repo_with_hooks
  run bash "$SETUP_SCRIPT" "$REPO_DIR"
  [ "$status" -eq 0 ]
  [ -f "$REPO_DIR/.github/harness-manifest.json" ]
}

@test "re-run does not print Installed when workflow is unchanged" {
  _pnpm_repo_with_hooks
  bash "$SETUP_SCRIPT" "$REPO_DIR"
  run bash "$SETUP_SCRIPT" "$REPO_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" != *"Installed"* ]]
}
```

- [ ] **Step 2: Run the new tests to confirm they fail**

```bash
bats tests/harness/setup.bats
```

Expected: the three new tests FAIL (workflow file not installed yet). All original tests still PASS.

- [ ] **Step 3: Update `harness/setup.sh` to source ci-workflows.sh and call the new functions**

Replace the contents of `harness/setup.sh` with:

```sh
#!/bin/sh
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="${1:-$(git rev-parse --show-toplevel)}"

. "$SCRIPT_DIR/lib/detect-language.sh"
. "$SCRIPT_DIR/lib/detect-package-manager.sh"
. "$SCRIPT_DIR/lib/merge-hook.sh"
. "$SCRIPT_DIR/lib/husky.sh"
. "$SCRIPT_DIR/lib/ci-workflows.sh"

NVM_BLOCK='# harness:nvm:begin
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
# harness:nvm:end'

REPO_LANG=$(detect_language "$REPO_ROOT")

case "$REPO_LANG" in
  js|mixed)
    echo "Detected $REPO_LANG repo — setting up Husky hooks..."
    ensure_husky_installed "$REPO_ROOT"
    ensure_husky_init "$REPO_ROOT"
    ensure_hook_exists "$REPO_ROOT/.husky/pre-push"
    merge_block "$REPO_ROOT/.husky/pre-commit" "nvm" "$NVM_BLOCK" "after-shebang"
    merge_block "$REPO_ROOT/.husky/pre-push" "nvm" "$NVM_BLOCK" "after-shebang"
    detect_overlapping_workflows "$REPO_ROOT"
    install_workflow_file "$REPO_ROOT" "$SCRIPT_DIR"
    echo "Done. Husky hooks configured at $REPO_ROOT/.husky/"
    ;;
  unsupported)
    echo "ERROR: No package.json found. Pure Go repos are not supported in v1." >&2
    exit 1
    ;;
esac
```

- [ ] **Step 4: Run the full test suite**

```bash
bats tests/harness/
```

Expected: all tests PASS including the three new ones.

- [ ] **Step 5: Commit**

```bash
git add harness/setup.sh tests/harness/setup.bats
git commit -m "feat: wire CI workflow install into setup.sh"
```

---

### Task 5: Update README

**Files:**
- Modify: `harness/README.md`

- [ ] **Step 1: Add CI scaffolding section to `harness/README.md`**

After the "Merge behaviour" section, insert:

```markdown
## CI workflow scaffolding

Setup installs a dedicated GitHub Actions workflow into the target repo:

```
.github/
  workflows/
    harness-checks.yml   # owned by harness — do not edit manually
  harness-manifest.json  # lockfile — tracks installed checksums
```

`harness-checks.yml` is installed on first run and updated only when the harness template changes (delta update via `harness-manifest.json`). Re-running setup is always safe.

### Overlap detection

If any existing workflow in `.github/workflows/` contains checks that harness will own (ESLint, Prettier, tsc, golangci-lint, or gitleaks), setup prints a warning with migration guidance:

```
WARNING: ci.yml contains checks that harness will own.
  To migrate: remove those steps from ci.yml and re-run setup.
  harness-checks.yml will run the same checks automatically.
```

Harness never modifies team-owned workflow files.
```

- [ ] **Step 2: Run all tests to confirm nothing broke**

```bash
bats tests/harness/
```

Expected: all tests PASS.

- [ ] **Step 3: Commit**

```bash
git add harness/README.md
git commit -m "docs: document CI workflow scaffolding and overlap detection"
```

---

## Self-Review

### Spec coverage

| AC | Task |
|----|------|
| Installs `.github/workflows/harness-checks.yml` without touching existing workflows | Task 4 (setup.sh) + Task 1 (template) |
| Lockfile `.github/harness-manifest.json` records installed version | Task 3 (`_write_manifest_entry`) |
| Re-run applies only delta changes | Task 3 (`install_workflow_file` checksum check) |
| Warns if existing team workflow overlaps with harness checks | Task 3 (`detect_overlapping_workflows`) + migration guidance text |
| CI and local Husky hooks reference same check definitions — no drift | Template is the single source; Stories #9–#14 extend it |

### Notes

- `_write_manifest_entry` rewrites the full manifest — fine for Story 16's single file. Stories #9–#14 will need to extend it to preserve other entries.
- The workflow template is intentionally minimal (checkout only). Stories #9–#14 add steps.
- `detect_overlapping_workflows` uses grep for keyword matching; it may produce false positives for comments mentioning those tools. Acceptable for a warning-only mechanism.
