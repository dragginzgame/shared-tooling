# Shared Tooling Agent Instructions

Read and apply [the Dragginzgame engineering baseline](DRAGGINZGAME.md) first.
Shared Tooling owns that canonical baseline; this file contains only its local
overlay. Consumers adopt the baseline and keep their own `AGENTS.md`.

## Validation in Shared Tooling

For meaningful new work, run `make prepare-work` and add the batch's notes to
the selected pending entry. Use `WORK_VERSION_KIND=minor` or `major` when the
compatibility assessment requires it. The helper reuses a pending version and
keeps `VERSION` aligned; `make check-version` validates the pair without edits.
This is ordinary local preparation, not staging, committing or releasing.

Shared's own compiler is pinned in `rust-toolchain.toml`. Prepare it explicitly
as described in [local setup](docs/local-setup.md#shared-toolings-own-compiler)
before installing Cargo tools. The runtime scanner uses that same prepared
compiler. Consumers implement the baseline's Rust 1.99.1 support policy with
their own target, feature and host qualification.

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
  Inspect nested fixture dispatch before choosing it. Expose independently
  selectable cases for oversized fixtures as they are touched; keep the existing
  full entrypoint for release qualification. A documentation or policy edit does
  not require rerunning installer/export fixtures merely because it is shared.
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
Cross-repository contributions require explicit scope under the
[PR workflow](rules/contributions.md#cross-repository-pull-requests). Prefer topic
branches in the agreed normal checkout; additional checkout locations require
explicit approval under the shared checkout contract.
Do not open unsolicited adoption PRs or start sibling release procedures.
Leave sibling working checkouts untouched and respect repository exclusions.
