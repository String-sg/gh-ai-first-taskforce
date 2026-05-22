#!/bin/sh
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="${1:-$(git rev-parse --show-toplevel)}"

. "$SCRIPT_DIR/lib/detect-language.sh"
. "$SCRIPT_DIR/lib/detect-package-manager.sh"
. "$SCRIPT_DIR/lib/merge-hook.sh"
. "$SCRIPT_DIR/lib/husky.sh"
. "$SCRIPT_DIR/lib/ci-workflows.sh"
. "$SCRIPT_DIR/lib/lint.sh"
. "$SCRIPT_DIR/lib/format.sh"
. "$SCRIPT_DIR/lib/typecheck.sh"
. "$SCRIPT_DIR/lib/secrets.sh"

NVM_BLOCK='# harness:nvm:begin
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
# harness:nvm:end'

REPO_LANG=$(detect_language "$REPO_ROOT")
ensure_gitleaks_available
ensure_gitleaks_config "$REPO_ROOT"

case "$REPO_LANG" in
  js|mixed)
    REPO_PM=$(detect_package_manager "$REPO_ROOT")
    echo "Detected $REPO_LANG repo — setting up Husky hooks..."
    ensure_husky_installed "$REPO_ROOT"
    ensure_husky_init "$REPO_ROOT"
    ensure_hook_exists "$REPO_ROOT/.husky/pre-push"
    merge_block "$REPO_ROOT/.husky/pre-commit" "nvm" "$NVM_BLOCK" "after-shebang"
    merge_block "$REPO_ROOT/.husky/pre-push" "nvm" "$NVM_BLOCK" "after-shebang"
    ensure_eslint_installed "$REPO_ROOT"
    ensure_eslint_config "$REPO_ROOT"
    ensure_prettier_installed "$REPO_ROOT"
    ensure_prettier_config "$REPO_ROOT"
    ensure_lint_staged_installed "$REPO_ROOT"
    install_lint_staged_hook "$REPO_ROOT"
    install_prettier_staged "$REPO_ROOT"
    if [ "$REPO_LANG" = "mixed" ]; then
      ensure_golangci_lint_available
      ensure_golangci_config "$REPO_ROOT"
      install_golangci_hook "$REPO_ROOT"
      ensure_goimports_available
      install_gofmt_hook "$REPO_ROOT"
    fi
    ensure_typescript_installed "$REPO_ROOT"
    ensure_tsconfig "$REPO_ROOT"
    install_tsc_hook "$REPO_ROOT"
    if [ "$REPO_LANG" = "mixed" ]; then
      ensure_go_vet_available
      install_go_vet_hook "$REPO_ROOT"
    fi
    install_gitleaks_hook "$REPO_ROOT"
    detect_overlapping_workflows "$REPO_ROOT"
    install_workflow_file "$REPO_ROOT" "$REPO_LANG" "$REPO_PM"
    echo "Done. Husky hooks configured at $REPO_ROOT/.husky/"
    echo "NOTE: Add 'harness / checks' as a required status check in GitHub branch protection to enforce CI linting on PRs."
    ;;
  unsupported)
    if [ -f "$REPO_ROOT/go.mod" ]; then
      install_gitleaks_git_hook "$REPO_ROOT"
      echo "Done. gitleaks pre-commit hook installed at $REPO_ROOT/.git/hooks/pre-commit"
      echo "(Pure Go repo — Husky-based checks are not supported in v1.)"
    else
      echo "ERROR: No package.json found. Pure Go repos are not supported in v1." >&2
      exit 1
    fi
    ;;
esac
