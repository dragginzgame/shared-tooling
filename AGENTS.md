# Shared Tooling Agent Instructions

Read and apply [the Dragginzgame engineering baseline](DRAGGINZGAME.md) first.
Shared Tooling owns that canonical baseline; this file contains only its local
overlay. Consumers adopt the baseline and keep their own `AGENTS.md`.

## Validation in Shared Tooling

The baseline's [validation and evidence policy](DRAGGINZGAME.md#validation-and-evidence)
owns when to run checks. This overlay identifies the local checks only.

- During development and before handing off a change, run focused fixtures and
  ShellCheck for the affected scripts, following sourced helpers with
  `shellcheck -x`. Select checks for the changed behavior and directly affected
  callers, including rejection and recovery paths where relevant.
- Shared helper, installer, release-tooling, snapshot/export, hook and CI edits
  need their affected consumer/contract fixtures, not an automatic full suite.
  Multiple changed files or tools do not by themselves justify the full gate.
- Full local checks are `make ci`, `bash scripts/ci/test-portable-tools.sh`
  and blanket ShellCheck over `scripts/ci/*.sh`, `scripts/dev/*.sh` and
  `scripts/distribution/*.sh`; run them only under the baseline's release or
  explicit-check authority.
- For documentation-only changes, use `make check-doc-links`, instruction
  consistency review and `git diff --check`.

The common [contribution authority rules](rules/contributions.md) apply here.
Staging, commits, version changes, tags and `make release-*` are user-owned by
default. Ordinary fixes and continuation leave reviewable working-tree changes;
they do not authorize `git add .`, `git commit` or release execution.
An authorized PR includes its necessary branch, commits and branch push; merges,
direct integration-branch pushes and releases require their own authorization.
Relevant contributions to other `dragginzgame` repositories use the standing
[isolated PR workflow](rules/contributions.md#cross-repository-pull-requests)
without per-PR approval. Leave sibling working checkouts untouched and respect
the workflow's repository exclusions.
