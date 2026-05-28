# Requires merge_block() and ensure_hook_exists() from merge-hook.sh to be sourced first.

# ensure_gitleaks_available
# Returns 0 if gitleaks is in PATH. Tries brew, then go install.
# Prints an actionable error and returns 1 if no installer is available.
ensure_gitleaks_available() {
  if command -v gitleaks >/dev/null 2>&1; then
    return 0
  fi

  if command -v brew >/dev/null 2>&1; then
    if ! brew install gitleaks; then
      echo "ERROR: brew install gitleaks failed. Install manually:" >&2
      echo "  brew install gitleaks" >&2
      return 1
    fi
    return 0
  fi

  if command -v go >/dev/null 2>&1; then
    if ! go install github.com/zricethezav/gitleaks/v8@latest; then
      echo "ERROR: go install gitleaks failed. Install manually:" >&2
      echo "  go install github.com/zricethezav/gitleaks/v8@latest" >&2
      return 1
    fi
    return 0
  fi

  echo "ERROR: gitleaks not found and could not be installed automatically." >&2
  echo "  macOS:  brew install gitleaks" >&2
  echo "  other:  go install github.com/zricethezav/gitleaks/v8@latest" >&2
  echo "  manual: https://github.com/gitleaks/gitleaks#installing" >&2
  return 1
}

# ensure_gitleaks_config <repo_root>
# Writes a default .gitleaks.toml if none exists.
ensure_gitleaks_config() {
  local repo_root="$1"

  if [ -f "$repo_root/.gitleaks.toml" ]; then
    return 0
  fi

  cat > "$repo_root/.gitleaks.toml" <<'EOF'
title = "gitleaks config"

[extend]
useDefault = true

# To allowlist a false positive, add an entry below:
# [allowlist]
# description = "describe what is being allowed"
# paths = ['''path/to/false-positive-file''']
# regexes = ['''EXAMPLE_PLACEHOLDER_[A-Z0-9]+''']
EOF

  echo "Created default .gitleaks.toml"
}

# _gitleaks_hook_block
# Outputs the harness:gitleaks pre-commit block content.
_gitleaks_hook_block() {
  cat <<'BLOCK'
# harness:gitleaks:begin
if ! command -v gitleaks >/dev/null 2>&1; then
  echo "ERROR: gitleaks not found. Install it and re-run: gh ai-first-taskforce setup" >&2
  echo "  macOS:  brew install gitleaks" >&2
  echo "  other:  go install github.com/zricethezav/gitleaks/v8@latest" >&2
  exit 1
fi
unset _GL_ARGS
[ -f .gitleaks.toml ] && _GL_ARGS=1
gitleaks protect --staged ${_GL_ARGS:+--config .gitleaks.toml} || {
  echo "" >&2
  echo "Secret detected. Next steps:" >&2
  echo "  - False positive? Add an [[allowlist]] entry to .gitleaks.toml" >&2
  echo "  - Real credential? Rotate it immediately — do not push" >&2
  exit 1
}
unset _GL_ARGS
# harness:gitleaks:end
BLOCK
}

# install_gitleaks_hook <repo_root>
# Merges the gitleaks pre-commit block into .husky/pre-commit.
install_gitleaks_hook() {
  local repo_root="$1"
  merge_block "$repo_root/.husky/pre-commit" "gitleaks" "$(_gitleaks_hook_block)" "append"
}

# install_gitleaks_git_hook <repo_root>
# For pure Go repos: merges the gitleaks block into .git/hooks/pre-commit directly.
# Creates .git/hooks/pre-commit with a shebang if it does not already exist.
install_gitleaks_git_hook() {
  local repo_root="$1"
  local hook_file="$repo_root/.git/hooks/pre-commit"
  ensure_hook_exists "$hook_file"
  merge_block "$hook_file" "gitleaks" "$(_gitleaks_hook_block)" "append"
}
