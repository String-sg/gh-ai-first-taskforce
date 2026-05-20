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
