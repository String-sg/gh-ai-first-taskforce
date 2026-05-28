_is_npm_dep_present() {
  local repo_root="$1"
  local dep="$2"
  grep -qE "\"$dep\"\s*:" "$repo_root/package.json" 2>/dev/null
}

ensure_eslint_installed() {
  local repo_root="$1"
  if _is_npm_dep_present "$repo_root" "eslint"; then
    return 0
  fi
  local pm
  pm=$(detect_package_manager "$repo_root")
  case "$pm" in
    pnpm)
      (cd "$repo_root" && pnpm add -D eslint)
      ;;
    bun)
      (cd "$repo_root" && bun add -D eslint)
      ;;
    *)
      echo "ERROR: Unsupported package manager" >&2
      return 1
      ;;
  esac
}

ensure_lint_staged_installed() {
  local repo_root="$1"
  if _is_npm_dep_present "$repo_root" "lint-staged"; then
    return 0
  fi
  local pm
  pm=$(detect_package_manager "$repo_root")
  case "$pm" in
    pnpm)
      (cd "$repo_root" && pnpm add -D lint-staged)
      ;;
    bun)
      (cd "$repo_root" && bun add -D lint-staged)
      ;;
    *)
      echo "ERROR: Unsupported package manager" >&2
      return 1
      ;;
  esac
}

ensure_eslint_config() {
  local repo_root="$1"
  for cfg in \
    "$repo_root/.eslintrc" \
    "$repo_root/.eslintrc.json" \
    "$repo_root/.eslintrc.js" \
    "$repo_root/.eslintrc.cjs" \
    "$repo_root/.eslintrc.yml" \
    "$repo_root/.eslintrc.yaml" \
    "$repo_root/eslint.config.js" \
    "$repo_root/eslint.config.mjs" \
    "$repo_root/eslint.config.cjs"; do
    if [ -f "$cfg" ]; then
      return 0
    fi
  done
  cat > "$repo_root/.eslintrc.json" <<'EOF'
{
  "extends": ["eslint:recommended"],
  "env": { "node": true, "es2021": true },
  "parserOptions": { "ecmaVersion": 2021 }
}
EOF
}

ensure_lint_staged_config() {
  local repo_root="$1"
  for cfg in \
    "$repo_root/.lintstagedrc" \
    "$repo_root/.lintstagedrc.json" \
    "$repo_root/.lintstagedrc.js" \
    "$repo_root/.lintstagedrc.cjs" \
    "$repo_root/.lintstagedrc.yml" \
    "$repo_root/.lintstagedrc.yaml"; do
    if [ -f "$cfg" ]; then
      return 0
    fi
  done
  if grep -q '"lint-staged"' "$repo_root/package.json" 2>/dev/null; then
    return 0
  fi
  cat > "$repo_root/.lintstagedrc.json" <<'EOF'
{
  "*.{js,jsx,ts,tsx}": ["eslint --fix", "eslint"]
}
EOF
}

ensure_golangci_lint_available() {
  if command -v golangci-lint >/dev/null 2>&1; then
    return 0
  elif command -v go >/dev/null 2>&1; then
    go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
    return $?
  else
    echo "ERROR: golangci-lint not found and go is not available. Install golangci-lint: https://golangci-lint.run/usage/install/" >&2
    return 1
  fi
}

ensure_golangci_config() {
  local repo_root="$1"
  for cfg in \
    "$repo_root/.golangci.yml" \
    "$repo_root/.golangci.yaml" \
    "$repo_root/.golangci.toml" \
    "$repo_root/.golangci.json"; do
    if [ -f "$cfg" ]; then
      return 0
    fi
  done
  cat > "$repo_root/.golangci.yml" <<'EOF'
linters:
  enable:
    - errcheck
    - govet
    - staticcheck
EOF
}

install_lint_staged_hook() {
  local repo_root="$1" pkg_mgr="$2"
  local runner
  case "$pkg_mgr" in
    pnpm) runner="pnpm lint-staged" ;;
    bun)  runner="bun run lint-staged" ;;
    *)    runner="npx lint-staged" ;;
  esac
  local lint_block="# harness:lint:begin
if ! command -v node >/dev/null 2>&1; then
  echo \"ERROR: node not found. Ensure your Node.js version manager (nvm, fnm, volta, etc.) is configured for non-interactive shells, then re-run: gh ai-first-taskforce setup\" >&2
  exit 1
fi
$runner || exit 1
# harness:lint:end"
  merge_block "$repo_root/.husky/pre-commit" "lint" "$lint_block" "append"
}

install_golangci_hook() {
  local repo_root="$1"
  local golangci_block='# harness:golangci:begin
_STAGED_GO=$(git diff --cached --name-only --diff-filter=ACM | grep '"'"'\.go'"'"' || true)
if [ -n "$_STAGED_GO" ]; then
  if ! command -v golangci-lint >/dev/null 2>&1; then
    echo "ERROR: golangci-lint not found. Run: gh ai-first-taskforce setup" >&2
    exit 1
  fi
  golangci-lint run ./...
fi
unset _STAGED_GO
# harness:golangci:end'
  merge_block "$repo_root/.husky/pre-commit" "golangci" "$golangci_block" "append"
}
