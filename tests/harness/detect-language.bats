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