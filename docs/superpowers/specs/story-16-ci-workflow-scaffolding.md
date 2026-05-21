# Spec: Harness Foundation — CI Workflow Scaffolding (Issue #16)

**Issue:** #16  
**Status:** Planned  
**Plan:** `docs/superpowers/plans/2026-05-20-ci-workflow-scaffolding.md`

---

## SHA-256 hashing

- `_sha256`: returns a 64-character lowercase hex string for any file

*Tests: `tests/harness/ci-workflows.bats`*

---

## Manifest read

- `_read_manifest_checksum`: returns empty string when manifest file is absent
- `_read_manifest_checksum`: returns the stored checksum when the path entry exists
- `_read_manifest_checksum`: returns empty string when the path is not in the manifest

*Tests: `tests/harness/ci-workflows.bats`*

---

## Manifest write

- `_write_manifest_entry`: creates `.github/harness-manifest.json` with `harness_version` and `files` keys
- `_write_manifest_entry`: round-trips correctly through `_read_manifest_checksum`
- `_write_manifest_entry`: overwrites the manifest checksum on a second call for the same path

*Tests: `tests/harness/ci-workflows.bats`*

---

## Workflow file installation

- `install_workflow_file`: creates `.github/workflows/harness-checks.yml` on first run
- `install_workflow_file`: creates `.github/harness-manifest.json` on first run
- `install_workflow_file`: stores a manifest checksum that matches the installed template
- `install_workflow_file`: produces no output on re-run when the template is unchanged (delta skip)
- `install_workflow_file`: overwrites the installed file and prints `Installed` when the manifest checksum is stale
- Harness never modifies existing team-owned workflow files

*Tests: `tests/harness/ci-workflows.bats`*

---

## Overlap detection

- `detect_overlapping_workflows`: produces no output when `.github/workflows/` does not exist
- `detect_overlapping_workflows`: produces no output when the workflows directory is empty
- `detect_overlapping_workflows`: warns when an existing workflow contains `eslint`
- `detect_overlapping_workflows`: warns when an existing workflow contains `prettier`
- `detect_overlapping_workflows`: warns when an existing workflow contains `golangci-lint`
- `detect_overlapping_workflows`: does not warn for `harness-checks.yml` itself
- `detect_overlapping_workflows`: produces no output for workflows with unrelated content
- Warning message names the offending file and includes migration guidance

*Tests: `tests/harness/ci-workflows.bats`*

---

## Setup orchestration integration

- Running `setup.sh` on a valid JS repo installs `.github/workflows/harness-checks.yml`
- Running `setup.sh` on a valid JS repo creates `.github/harness-manifest.json`
- Re-running `setup.sh` does not print `Installed` when the workflow template is unchanged

*Tests: `tests/harness/setup.bats`*
