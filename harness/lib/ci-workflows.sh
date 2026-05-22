# _sha256 <file>: cross-platform SHA-256 hex digest
_sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | cut -d' ' -f1
  else
    shasum -a 256 "$1" | cut -d' ' -f1
  fi
}

# _read_manifest_checksum <manifest_file> <relative_path>
# Prints the stored SHA-256 for <relative_path>, or empty string if absent.
_read_manifest_checksum() {
  local manifest_file="$1" path="$2"
  [ -f "$manifest_file" ] || return 0
  grep -F "\"$path\"" "$manifest_file" | grep -oE '[a-f0-9]{64}' | head -1
}

# _write_manifest_entry <manifest_file> <relative_path> <checksum>
# Writes (or rewrites) a single-entry harness-manifest.json.
# Note: rewrites the full file — extend for multi-file manifests in later stories.
_write_manifest_entry() {
  local manifest_file="$1" path="$2" checksum="$3"
  mkdir -p "$(dirname "$manifest_file")"
  printf '{\n  "harness_version": "1",\n  "files": {\n    "%s": "%s"\n  }\n}\n' \
    "$path" "$checksum" > "$manifest_file"
}

# generate_workflow_yaml <lang> <pm>
# Emits the full harness-checks.yml content for the given repo type and package manager.
# lang: js | mixed
# pm:   pnpm | bun
generate_workflow_yaml() {
  local lang="$1" pm="$2"

  cat <<'YAML'
name: Harness Checks

on:
  push:
  pull_request:

jobs:
  harness:
    name: harness / checks
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: lts/*
YAML

  case "$pm" in
    pnpm)
      cat <<'YAML'

      - uses: pnpm/action-setup@v4
        with:
          run_install: false

      - name: Install dependencies
        run: pnpm install --frozen-lockfile
YAML
      ;;
    bun)
      cat <<'YAML'

      - name: Install dependencies
        run: bun install --frozen-lockfile
YAML
      ;;
  esac

  cat <<'YAML'

      - name: Lint (ESLint)
        run: npx eslint .

      - name: Format (Prettier)
        run: npx prettier --check .

      - name: Type-check (tsc)
        run: npx tsc --noEmit
YAML

  if [ "$lang" = "mixed" ]; then
    cat <<'YAML'

      - uses: actions/setup-go@v5
        with:
          go-version-file: go.mod

      - name: Lint (golangci-lint)
        uses: golangci/golangci-lint-action@v6
        with:
          version: latest

      - name: Install goimports
        run: go install golang.org/x/tools/cmd/goimports@latest

      - name: Format (gofmt)
        run: |
          unformatted=$(gofmt -l .)
          if [ -n "$unformatted" ]; then
            echo "The following files are not gofmt-formatted:"
            echo "$unformatted"
            exit 1
          fi

      - name: Format (goimports)
        run: |
          unformatted=$(goimports -l .)
          if [ -n "$unformatted" ]; then
            echo "The following files need import formatting:"
            echo "$unformatted"
            exit 1
          fi

      - name: Type-check (go vet)
        run: go vet ./...
YAML
  fi
}

# install_workflow_file <repo_root> <lang> <pm>
# Generates harness-checks.yml for the given lang+pm, writes it to
# .github/workflows/harness-checks.yml only when the content has changed
# (delta update via harness-manifest.json checksum).
install_workflow_file() {
  local repo_root="$1" lang="$2" pm="$3"
  local rel_path=".github/workflows/harness-checks.yml"
  local dest="$repo_root/$rel_path"
  local manifest="$repo_root/.github/harness-manifest.json"
  local content tmp current_checksum installed_checksum

  content=$(generate_workflow_yaml "$lang" "$pm")

  tmp=$(mktemp)
  printf '%s\n' "$content" > "$tmp"
  current_checksum=$(_sha256 "$tmp") || { rm -f "$tmp"; return 1; }
  rm -f "$tmp"

  installed_checksum=$(_read_manifest_checksum "$manifest" "$rel_path")

  if [ "$current_checksum" = "$installed_checksum" ] && [ -f "$dest" ]; then
    return 0
  fi

  mkdir -p "$(dirname "$dest")"
  printf '%s\n' "$content" > "$dest"
  _write_manifest_entry "$manifest" "$rel_path" "$current_checksum"
  echo "Installed $rel_path"
}

# detect_overlapping_workflows <repo_root>
# Warns if any existing non-harness workflow contains keywords harness will own.
detect_overlapping_workflows() {
  local repo_root="$1"
  local workflows_dir="$repo_root/.github/workflows"
  [ -d "$workflows_dir" ] || return 0

  for wf in "$workflows_dir"/*.yml "$workflows_dir"/*.yaml; do
    [ -f "$wf" ] || continue
    case "$(basename "$wf")" in harness-checks.yml) continue ;; esac
    if grep -qiE 'eslint|prettier|tsc|golangci.lint|gitleaks' "$wf" 2>/dev/null; then
      echo "WARNING: $(basename "$wf") contains checks that harness will own."
      echo "  To migrate: remove those steps from $(basename "$wf") and re-run setup."
      echo "  harness-checks.yml will run the same checks automatically."
    fi
  done
}
