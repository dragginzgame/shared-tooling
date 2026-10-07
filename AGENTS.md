# Shared Tooling Agent Instructions

Read and apply [the Dragginzgame engineering baseline](DRAGGINZGAME.md) first.
Shared Tooling owns that canonical baseline; this file contains only its local
overlay. Consumers adopt the baseline and keep their own `AGENTS.md`.

## Validation in Shared Tooling

- After script changes, run `bash scripts/ci/test-portable-tools.sh` and ShellCheck
  over `scripts/ci/*.sh`, `scripts/dev/*.sh` and `scripts/distribution/*.sh`.
- For documentation-only changes, check links, instruction consistency and the
  diff. Do not run the portable script suite solely because prose changed.

The common [contribution authority rules](rules/contributions.md) apply here.
An authorized PR includes its necessary branch, commits and branch push; merges,
direct integration-branch pushes and releases require their own authorization.
