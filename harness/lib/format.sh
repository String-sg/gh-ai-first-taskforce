# Requires detect_package_manager() from detect-package-manager.sh
# and merge_block() from merge-hook.sh to be sourced before this file.

# _has_tailwind <repo_root>
# Returns 0 if tailwindcss appears in package.json, 1 otherwise.
_has_tailwind() {
  grep -q '"tailwindcss"' "${1}/package.json" 2>/dev/null
}

# ensure_prettier_installed <repo_root>
# Installs prettier as a dev dependency if absent.
# Also installs prettier-plugin-tailwindcss if tailwindcss is detected and plugin is absent.
ensure_prettier_installed() {
  local repo_root="$1"
  local pm
  pm=$(detect_package_manager "$repo_root")

  if ! grep -q '"prettier"' "$repo_root/package.json" 2>/dev/null; then
    case "$pm" in
      pnpm) (cd "$repo_root" && pnpm add -D prettier) ;;
      bun)  (cd "$repo_root" && bun add -D prettier) ;;
      *)
        echo "ERROR: Unsupported package manager" >&2
        return 1
        ;;
    esac
  fi

  if _has_tailwind "$repo_root" && \
     ! grep -q '"prettier-plugin-tailwindcss"' "$repo_root/package.json" 2>/dev/null; then
    case "$pm" in
      pnpm) (cd "$repo_root" && pnpm add -D prettier-plugin-tailwindcss) ;;
      bun)  (cd "$repo_root" && bun add -D prettier-plugin-tailwindcss) ;;
    esac
  fi
}

# ensure_prettier_config <repo_root>
# Writes a default .prettierrc if no Prettier config of any kind exists.
# Includes prettier-plugin-tailwindcss in the plugins array when tailwindcss is detected.
ensure_prettier_config() {
  local repo_root="$1"
  for cfg in .prettierrc .prettierrc.json .prettierrc.js .prettierrc.cjs \
             .prettierrc.mjs .prettierrc.yml .prettierrc.yaml \
             prettier.config.js prettier.config.cjs prettier.config.mjs; do
    [ -f "$repo_root/$cfg" ] && return 0
  done
  grep -q '"prettier"' "$repo_root/package.json" 2>/dev/null && return 0

  if _has_tailwind "$repo_root"; then
    printf '{\n  "printWidth": 150,\n  "tabWidth": 2,\n  "singleQuote": true,\n  "bracketSameLine": true,\n  "trailingComma": "es5",\n  "plugins": ["prettier-plugin-tailwindcss"]\n}\n' \
      > "$repo_root/.prettierrc"
  else
    printf '{\n  "printWidth": 150,\n  "tabWidth": 2,\n  "singleQuote": true,\n  "bracketSameLine": true,\n  "trailingComma": "es5"\n}\n' \
      > "$repo_root/.prettierrc"
  fi
  echo "Created default .prettierrc"
}

# install_prettier_staged <repo_root>
# Writes .lintstagedrc.json with prettier --check and eslint --max-warnings=0.
# Skips if prettier is already present in any lint-staged config.
# This function owns the lint-staged config — it supersedes ensure_lint_staged_config.
install_prettier_staged() {
  local repo_root="$1"
  local config="$repo_root/.lintstagedrc.json"

  grep -q '"prettier' "$config" 2>/dev/null && return 0
  grep -q '"prettier' "$repo_root/package.json" 2>/dev/null && return 0

  printf '{\n  "*.{js,jsx,ts,tsx}": ["prettier --check", "eslint --max-warnings=0"]\n}\n' \
    > "$config"
  echo "Updated .lintstagedrc.json"
}

# ensure_goimports_available
# Returns 0 if goimports is in PATH. If not, attempts go install.
# Fails with an actionable error if neither goimports nor go is available.
ensure_goimports_available() {
  if command -v goimports >/dev/null 2>&1; then
    return 0
  fi
  if command -v go >/dev/null 2>&1; then
    go install golang.org/x/tools/cmd/goimports@latest
    echo "Installed goimports via go install. Ensure your GOPATH/bin is in PATH."
  else
    echo "ERROR: goimports not found and go is not available. Install Go: https://go.dev/dl/" >&2
    return 1
  fi
}

# install_gofmt_hook <repo_root>
# Merges the gofmt + goimports pre-commit block (mixed repos only).
# Only runs when staged .go files are present. Fails with actionable errors.
install_gofmt_hook() {
  local repo_root="$1"
  local gofmt_block
  gofmt_block='# harness:gofmt:begin
_STAGED_GO=$(git diff --cached --name-only --diff-filter=ACM | grep '"'"'\.go$'"'"' || true)
if [ -n "$_STAGED_GO" ]; then
  if ! command -v gofmt >/dev/null 2>&1; then
    echo "ERROR: gofmt not found. Install Go: https://go.dev/dl/" >&2
    exit 1
  fi
  _FMT=$(echo "$_STAGED_GO" | xargs gofmt -l)
  if [ -n "$_FMT" ]; then
    echo "ERROR: The following Go files are not gofmt-formatted (run gofmt -w <file>):"
    echo "$_FMT"
    exit 1
  fi
  if command -v goimports >/dev/null 2>&1; then
    _IMP=$(echo "$_STAGED_GO" | xargs goimports -l)
    if [ -n "$_IMP" ]; then
      echo "ERROR: The following Go files need import formatting (run goimports -w <file>):"
      echo "$_IMP"
      exit 1
    fi
  fi
fi
unset _STAGED_GO _FMT _IMP
# harness:gofmt:end'
  merge_block "$repo_root/.husky/pre-commit" "gofmt" "$gofmt_block" "append"
}
