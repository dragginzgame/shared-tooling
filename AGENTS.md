# Shared Tooling Agent Instructions

Read and apply [the Dragginzgame engineering baseline](DRAGGINZGAME.md) first.
Shared Tooling owns that canonical baseline; this file contains only its local
overlay. Consumers adopt the baseline and keep their own `AGENTS.md`.

## Validation in Shared Tooling

Shared's own compiler is pinned in `rust-toolchain.toml`. Prepare it explicitly
as described in [local setup](docs/local-setup.md#shared-toolings-own-compiler)
before installing Cargo tools. Consumer compiler policy remains locally owned;
the runtime scanner's separate minimum-compiler qualification is unchanged.

The baseline's [validation and evidence policy](DRAGGINZGAME.md#validation-and-evidence)
owns when to run checks. This overlay identifies the local checks only.

- After a coherent edit batch, run selected fixtures and ShellCheck for affected
  scripts once; run checks during development only to answer a specific question.
  Reuse passing evidence for unchanged inputs, following sourced helpers with
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
Ordinary fixes leave reviewable working-tree changes; they do not implicitly
stage, commit or release. A release/ship/deploy request delegates its scoped
delivery workflow under [delegated delivery](rules/contributions.md#delegated-delivery),
including routine release choices and necessary Git effects without per-step
confirmation. An authorized PR alone includes its branch, commits and branch
push, but not its merge or release. Never use blanket staging or bypass protections.
Relevant contributions to other `dragginzgame` repositories use the standing
[isolated PR workflow](rules/contributions.md#cross-repository-pull-requests)
without per-PR approval. Leave sibling working checkouts untouched and respect
the workflow's repository exclusions.
