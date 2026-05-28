# Requires detect_package_manager() from detect-package-manager.sh
# and merge_block() from merge-hook.sh to be sourced before this file.

# ensure_typescript_installed <repo_root>
# Installs typescript as a dev dependency if absent from package.json.
ensure_typescript_installed() {
  local repo_root="$1"
  local pm

  if grep -qE '"typescript"\s*:' "$repo_root/package.json" 2>/dev/null; then
    return 0
  fi

  pm=$(detect_package_manager "$repo_root")
  case "$pm" in
    pnpm) (cd "$repo_root" && pnpm add -D typescript) ;;
    bun)  (cd "$repo_root" && bun add -D typescript) ;;
    *)
      echo "ERROR: Unsupported package manager" >&2
      return 1
      ;;
  esac
}

# ensure_tsconfig <repo_root>
# Writes a default tsconfig.json if none exists (up to depth 3, excluding node_modules).
ensure_tsconfig() {
  local repo_root="$1"

  # Skip if any tsconfig.json already exists (excluding node_modules, up to depth 3)
  if [ -n "$(find "$repo_root" -maxdepth 3 -name tsconfig.json -not -path "*/node_modules/*" | head -1)" ]; then
    return 0
  fi

  # Detect source directory
  local src_dir="src"
  for candidate in src web app; do
    [ -d "$repo_root/$candidate" ] && src_dir="$candidate" && break
  done

  # Detect Vite
  local has_vite=0
  grep -q '"vite"' "$repo_root/package.json" 2>/dev/null && has_vite=1

  printf '{\n  "compilerOptions": {\n    "target": "ES2022",\n    "useDefineForClassFields": true,\n    "lib": ["ES2022", "DOM", "DOM.Iterable"],\n    "module": "ESNext",\n' \
    > "$repo_root/tsconfig.json"
  [ "$has_vite" = "1" ] && printf '    "types": ["vite/client"],\n' >> "$repo_root/tsconfig.json"
  printf '    "skipLibCheck": true,\n\n    "moduleResolution": "bundler",\n    "allowImportingTsExtensions": true,\n    "verbatimModuleSyntax": true,\n    "moduleDetection": "force",\n    "noEmit": true,\n    "jsx": "react-jsx",\n\n    "strict": true,\n    "noUnusedLocals": true,\n    "noUnusedParameters": true,\n    "erasableSyntaxOnly": true,\n    "noFallthroughCasesInSwitch": true,\n    "noUncheckedSideEffectImports": true\n  },\n  "include": ["%s"]\n}\n' \
    "$src_dir" >> "$repo_root/tsconfig.json"

  echo "Created default tsconfig.json (include: [\"$src_dir\"])"
}

# ensure_go_vet_available
# Returns 0 if go is in PATH, 1 with an actionable error if not.
ensure_go_vet_available() {
  if command -v go >/dev/null 2>&1; then
    return 0
  fi
  echo "ERROR: go not found. go vet requires the Go toolchain. Install Go: https://go.dev/dl/" >&2
  return 1
}

# install_tsc_hook <repo_root> <pkg_mgr>
# Merges the tsc pre-commit block into .husky/pre-commit.
install_tsc_hook() {
  local repo_root="$1" pkg_mgr="$2"
  local tsc_runner
  case "$pkg_mgr" in
    pnpm) tsc_runner="pnpm exec tsc" ;;
    bun)  tsc_runner="bun run tsc" ;;
    *)    tsc_runner="npx tsc" ;;
  esac
  local tsc_block
  tsc_block="# harness:tsc:begin
if ! command -v node >/dev/null 2>&1; then
  echo \"ERROR: node not found. Ensure your Node.js version manager (nvm, fnm, volta, etc.) is configured for non-interactive shells, then re-run: gh ai-first-taskforce setup\" >&2
  exit 1
fi
_TSC_LIST=\$(mktemp)
trap 'rm -f \"\$_TSC_LIST\"' EXIT
git ls-files | grep 'tsconfig\.json\$' | sort > \"\$_TSC_LIST\"
if [ ! -s \"\$_TSC_LIST\" ]; then
  rm -f \"\$_TSC_LIST\"
  echo \"ERROR: No tsconfig.json found. Run: gh ai-first-taskforce setup\" >&2
  exit 1
fi
if [ -f ./tsconfig.json ] && grep -qE '^\s*\"references\"\s*:' ./tsconfig.json; then
  rm -f \"\$_TSC_LIST\"
  $tsc_runner --noEmit || exit 1
else
  _TSC_FAIL=0
  while IFS= read -r _cfg; do
    $tsc_runner --noEmit -p \"\$_cfg\" || _TSC_FAIL=1
  done < \"\$_TSC_LIST\"
  rm -f \"\$_TSC_LIST\"
  [ \"\$_TSC_FAIL\" = \"0\" ] || exit 1
  unset _TSC_FAIL _cfg
fi
unset _TSC_LIST
trap - EXIT
# harness:tsc:end"
  merge_block "$repo_root/.husky/pre-commit" "tsc" "$tsc_block" "append"
}

# install_go_vet_hook <repo_root>
# Merges the go vet pre-commit block into .husky/pre-commit.
install_go_vet_hook() {
  local repo_root="$1"
  local govet_block
  govet_block='# harness:govet:begin
_STAGED_GO=$(git diff --cached --name-only --diff-filter=ACM | grep '"'"'\.go$'"'"' || true)
if [ -n "$_STAGED_GO" ]; then
  if ! command -v go >/dev/null 2>&1; then
    echo "ERROR: go not found. Install Go: https://go.dev/dl/" >&2
    exit 1
  fi
  _VET_DIRS=$(mktemp)
  echo "$_STAGED_GO" | xargs dirname | sort -u > "$_VET_DIRS"
  _VET_FAIL=0
  while IFS= read -r _dir; do
    go vet "./$_dir" || _VET_FAIL=1
  done < "$_VET_DIRS"
  rm -f "$_VET_DIRS"
  [ "$_VET_FAIL" = "0" ] || exit 1
  unset _VET_DIRS _VET_FAIL _dir
fi
unset _STAGED_GO
# harness:govet:end'
  merge_block "$repo_root/.husky/pre-commit" "govet" "$govet_block" "append"
}
