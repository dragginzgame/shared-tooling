# Shared Tooling Agent Instructions

Read and apply [the Dragginzgame engineering baseline](DRAGGINZGAME.md) first.
Shared Tooling owns that canonical baseline; this file contains only its local
overlay. Consumers adopt the baseline and keep their own `AGENTS.md`.

## Validation in Shared Tooling

- After script changes, run `bash scripts/ci/test-portable-tools.sh` and ShellCheck
  over `scripts/ci/*.sh`, `scripts/dev/*.sh` and `scripts/distribution/*.sh`.
- For documentation-only changes, check links, instruction consistency and the
  diff. Do not run the portable script suite solely because prose changed.

The common authority rules apply here: commits remain maintainer-owned, and
version changes, tags, pushes and publication require explicit authorization.
