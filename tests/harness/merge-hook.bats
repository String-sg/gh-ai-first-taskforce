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
  [ -x "$hook" ]
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
