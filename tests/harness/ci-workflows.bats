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
  run _write_manifest_entry "$manifest" ".github/workflows/harness-checks.yml" \
    "abc123def456abc123def456abc123def456abc123def456abc123def456abc1"
  [ "$status" -eq 0 ]
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

# ── generate_workflow_yaml ───────────────────────────────────────────────

@test "generate_workflow_yaml js pnpm: contains pnpm install, not bun or go steps" {
  run generate_workflow_yaml "js" "pnpm"
  [ "$status" -eq 0 ]
  [[ "$output" == *"pnpm install --frozen-lockfile"* ]]
  [[ "$output" != *"bun install"* ]]
  [[ "$output" != *"golangci-lint-action"* ]]
}

@test "generate_workflow_yaml js bun: contains bun install, not pnpm or go steps" {
  run generate_workflow_yaml "js" "bun"
  [ "$status" -eq 0 ]
  [[ "$output" == *"bun install --frozen-lockfile"* ]]
  [[ "$output" != *"pnpm install"* ]]
  [[ "$output" != *"golangci-lint-action"* ]]
}

@test "generate_workflow_yaml mixed pnpm: contains pnpm install and golangci steps" {
  run generate_workflow_yaml "mixed" "pnpm"
  [ "$status" -eq 0 ]
  [[ "$output" == *"pnpm install --frozen-lockfile"* ]]
  [[ "$output" == *"golangci-lint-action@v6"* ]]
}

@test "generate_workflow_yaml mixed bun: contains bun install and golangci steps" {
  run generate_workflow_yaml "mixed" "bun"
  [ "$status" -eq 0 ]
  [[ "$output" == *"bun install --frozen-lockfile"* ]]
  [[ "$output" == *"golangci-lint-action@v6"* ]]
}

@test "generate_workflow_yaml js pnpm: contains prettier --check, not gofmt" {
  run generate_workflow_yaml "js" "pnpm"
  [ "$status" -eq 0 ]
  [[ "$output" == *"prettier --check"* ]]
  [[ "$output" != *"gofmt"* ]]
}

@test "generate_workflow_yaml js bun: contains prettier --check, not gofmt" {
  run generate_workflow_yaml "js" "bun"
  [ "$status" -eq 0 ]
  [[ "$output" == *"prettier --check"* ]]
  [[ "$output" != *"gofmt"* ]]
}

@test "generate_workflow_yaml mixed pnpm: contains prettier --check and gofmt and goimports" {
  run generate_workflow_yaml "mixed" "pnpm"
  [ "$status" -eq 0 ]
  [[ "$output" == *"prettier --check"* ]]
  [[ "$output" == *"gofmt -l"* ]]
  [[ "$output" == *"goimports -l"* ]]
}

@test "generate_workflow_yaml mixed bun: contains prettier --check and gofmt and goimports" {
  run generate_workflow_yaml "mixed" "bun"
  [ "$status" -eq 0 ]
  [[ "$output" == *"prettier --check"* ]]
  [[ "$output" == *"gofmt -l"* ]]
  [[ "$output" == *"goimports -l"* ]]
}

# ── install_workflow_file ────────────────────────────────────────────────

@test "install_workflow_file: creates .github/workflows/harness-checks.yml on first run" {
  install_workflow_file "$REPO_DIR" "js" "pnpm"
  [ -f "$REPO_DIR/.github/workflows/harness-checks.yml" ]
}

@test "install_workflow_file: creates .github/harness-manifest.json on first run" {
  install_workflow_file "$REPO_DIR" "js" "pnpm"
  [ -f "$REPO_DIR/.github/harness-manifest.json" ]
}

@test "install_workflow_file: manifest checksum matches generated content" {
  install_workflow_file "$REPO_DIR" "js" "pnpm"
  local expected tmp
  tmp=$(mktemp)
  printf '%s\n' "$(generate_workflow_yaml "js" "pnpm")" > "$tmp"
  expected=$(_sha256 "$tmp")
  rm -f "$tmp"
  run _read_manifest_checksum "$REPO_DIR/.github/harness-manifest.json" \
    ".github/workflows/harness-checks.yml"
  [ "$output" = "$expected" ]
}

@test "install_workflow_file: is silent on re-run with unchanged lang and pm" {
  install_workflow_file "$REPO_DIR" "js" "pnpm"
  run install_workflow_file "$REPO_DIR" "js" "pnpm"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "install_workflow_file: prints Installed and updates when checksum is stale" {
  install_workflow_file "$REPO_DIR" "js" "pnpm"
  _write_manifest_entry "$REPO_DIR/.github/harness-manifest.json" \
    ".github/workflows/harness-checks.yml" \
    "0000000000000000000000000000000000000000000000000000000000000000"
  run install_workflow_file "$REPO_DIR" "js" "pnpm"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Installed"* ]]
}

@test "install_workflow_file: installs pnpm-specific content for pnpm repo" {
  install_workflow_file "$REPO_DIR" "js" "pnpm"
  grep -q "pnpm install --frozen-lockfile" "$REPO_DIR/.github/workflows/harness-checks.yml"
  ! grep -q "bun install" "$REPO_DIR/.github/workflows/harness-checks.yml"
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
  [ "$status" -eq 0 ]
  [[ "$output" == *"WARNING"* ]]
}

@test "detect_overlapping_workflows: warns when workflow contains golangci-lint" {
  mkdir -p "$REPO_DIR/.github/workflows"
  printf 'name: Go\njobs:\n  lint:\n    steps:\n      - run: golangci-lint run\n' \
    > "$REPO_DIR/.github/workflows/go.yml"
  run detect_overlapping_workflows "$REPO_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" == *"WARNING"* ]]
}

@test "detect_overlapping_workflows: warns when workflow contains tsc" {
  mkdir -p "$REPO_DIR/.github/workflows"
  printf 'name: CI\njobs:\n  typecheck:\n    steps:\n      - run: tsc --noEmit\n' \
    > "$REPO_DIR/.github/workflows/ci.yml"
  run detect_overlapping_workflows "$REPO_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" == *"WARNING"* ]]
}

@test "detect_overlapping_workflows: warns when workflow contains gitleaks" {
  mkdir -p "$REPO_DIR/.github/workflows"
  printf 'name: Security\njobs:\n  secrets:\n    steps:\n      - run: gitleaks detect\n' \
    > "$REPO_DIR/.github/workflows/security.yml"
  run detect_overlapping_workflows "$REPO_DIR"
  [ "$status" -eq 0 ]
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

# ── generate_workflow_yaml: type-check steps ────────────────────────────────

@test "generate_workflow_yaml js pnpm: contains tsc --noEmit, not go vet" {
  run generate_workflow_yaml "js" "pnpm"
  [ "$status" -eq 0 ]
  grep -q "tsc --noEmit" <<< "$output"
  [[ "$output" != *"go vet"* ]]
}

@test "generate_workflow_yaml js bun: contains tsc --noEmit, not go vet" {
  run generate_workflow_yaml "js" "bun"
  [ "$status" -eq 0 ]
  grep -q "tsc --noEmit" <<< "$output"
  [[ "$output" != *"go vet"* ]]
}

@test "generate_workflow_yaml mixed pnpm: contains tsc --noEmit and go vet ./..." {
  run generate_workflow_yaml "mixed" "pnpm"
  [ "$status" -eq 0 ]
  grep -q "tsc --noEmit" <<< "$output"
  grep -q "go vet ./..." <<< "$output"
}

@test "generate_workflow_yaml mixed bun: contains tsc --noEmit and go vet ./..." {
  run generate_workflow_yaml "mixed" "bun"
  [ "$status" -eq 0 ]
  grep -q "tsc --noEmit" <<< "$output"
  grep -q "go vet ./..." <<< "$output"
}
