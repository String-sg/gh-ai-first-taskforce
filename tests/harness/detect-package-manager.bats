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
