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

# install_workflow_file <repo_root> <harness_dir> [template_name]
# Copies harness/workflows/<template_name> into .github/workflows/ if the
# template checksum differs from the manifest entry (delta update).
# Defaults to harness-checks.yml if template_name is not provided.
install_workflow_file() {
  local repo_root="$1" harness_dir="$2" template_name="${3:-harness-checks.yml}"
  local template="$harness_dir/workflows/$template_name"
  local rel_path=".github/workflows/harness-checks.yml"
  local dest="$repo_root/$rel_path"
  local manifest="$repo_root/.github/harness-manifest.json"

  local current_checksum
  current_checksum=$(_sha256 "$template")

  local installed_checksum
  installed_checksum=$(_read_manifest_checksum "$manifest" "$rel_path")

  if [ "$current_checksum" = "$installed_checksum" ] && [ -f "$dest" ]; then
    return 0
  fi

  mkdir -p "$(dirname "$dest")"
  cp "$template" "$dest"
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
