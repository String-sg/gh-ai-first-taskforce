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
        return 1
        ;;
    esac
  fi
}

ensure_env_sh() {
  local repo_root="$1"
  local env_file="$repo_root/.husky/_/env.sh"
  mkdir -p "$(dirname "$env_file")"
  [ -f "$env_file" ] && return 0
  cat > "$env_file" <<'EOF'
#!/bin/sh
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
EOF
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
        return 1
        ;;
    esac
    # husky init writes a sample "npm test" pre-commit — reset to a bare shebang
    # so merge_block owns all hook content going forward
    printf '#!/bin/sh\n' > "$repo_root/.husky/pre-commit"
    chmod +x "$repo_root/.husky/pre-commit"
  fi
}
