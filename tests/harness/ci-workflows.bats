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

# ── install_workflow_file ────────────────────────────────────────────────

@test "install_workflow_file: creates .github/workflows/harness-checks.yml on first run" {
  local harness_dir="$BATS_TEST_DIRNAME/../../harness"
  install_workflow_file "$REPO_DIR" "$harness_dir" "harness-checks.yml"
  [ -f "$REPO_DIR/.github/workflows/harness-checks.yml" ]
}

@test "install_workflow_file: creates .github/harness-manifest.json on first run" {
  local harness_dir="$BATS_TEST_DIRNAME/../../harness"
  install_workflow_file "$REPO_DIR" "$harness_dir" "harness-checks.yml"
  [ -f "$REPO_DIR/.github/harness-manifest.json" ]
}

@test "install_workflow_file: manifest checksum matches template" {
  local harness_dir="$BATS_TEST_DIRNAME/../../harness"
  install_workflow_file "$REPO_DIR" "$harness_dir" "harness-checks.yml"
  local expected
  expected=$(_sha256 "$harness_dir/workflows/harness-checks.yml")
  run _read_manifest_checksum "$REPO_DIR/.github/harness-manifest.json" \
    ".github/workflows/harness-checks.yml"
  [ "$output" = "$expected" ]
}

@test "install_workflow_file: is silent on re-run with unchanged template" {
  local harness_dir="$BATS_TEST_DIRNAME/../../harness"
  install_workflow_file "$REPO_DIR" "$harness_dir" "harness-checks.yml"
  run install_workflow_file "$REPO_DIR" "$harness_dir" "harness-checks.yml"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "install_workflow_file: prints Installed and updates manifest when checksum is stale" {
  local harness_dir="$BATS_TEST_DIRNAME/../../harness"
  install_workflow_file "$REPO_DIR" "$harness_dir" "harness-checks.yml"
  _write_manifest_entry "$REPO_DIR/.github/harness-manifest.json" \
    ".github/workflows/harness-checks.yml" \
    "0000000000000000000000000000000000000000000000000000000000000000"
  run install_workflow_file "$REPO_DIR" "$harness_dir" "harness-checks.yml"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Installed"* ]]
}

@test "install_workflow_file: installs the specified template when template_name given" {
  local tmp_harness="$REPO_DIR/tmp-harness"
  mkdir -p "$tmp_harness/workflows"
  printf 'name: Custom Checks\n' > "$tmp_harness/workflows/custom-checks.yml"
  install_workflow_file "$REPO_DIR" "$tmp_harness" "custom-checks.yml"
  grep -q "name: Custom Checks" "$REPO_DIR/.github/workflows/harness-checks.yml"
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
