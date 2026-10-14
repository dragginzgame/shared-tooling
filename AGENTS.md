# Shared Tooling Agent Instructions

Read and apply [the Dragginzgame engineering baseline](DRAGGINZGAME.md) first.
Shared Tooling owns that canonical baseline; this file contains only its local
overlay. Consumers adopt the baseline and keep their own `AGENTS.md`.

## Validation in Shared Tooling

- During script development, run focused fixtures and ShellCheck for the affected
  scripts, following their sourced helpers with `shellcheck -x`.
- For changes confined to an isolated, read-only reporting script (such as the
  sibling issue dashboard) and its fixtures, those focused checks plus diff
  review are sufficient for delivery. Cover changed queries, pagination,
  calculations, failure handling and output as applicable. Do not run unrelated
  installer or release fixtures solely because a reporting script changed.
- Run the full `bash scripts/ci/test-portable-tools.sh` suite and ShellCheck over
  `scripts/ci/*.sh`, `scripts/dev/*.sh` and `scripts/distribution/*.sh` before
  delivering shared infrastructure changes or a batch affecting multiple tools.
  This includes shared helpers, installers, release tooling, snapshot/export
  logic, hooks and CI wiring. If a reporting change reaches those paths, use the
  full gate. Required CI and release gates remain unchanged.
- Validation has standing authority; no additional request is needed. Reuse
  passing results for unchanged inputs rather than rerunning at every handoff.
- For documentation-only changes, check links, instruction consistency and the
  diff. Do not run the portable script suite solely because prose changed.

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
