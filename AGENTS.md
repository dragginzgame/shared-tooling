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

- For affected scripts, run selected consumer/contract fixtures and ShellCheck,
  using `shellcheck -x` for sourced helpers. Inspect fixture dispatch and select
  affected cases; expose narrow selections when oversized fixtures are touched.
- Full local checks are `make ci`, `bash scripts/ci/test-portable-tools.sh` and
  blanket ShellCheck over `scripts/ci/*.sh`, `scripts/dev/*.sh` and
  `scripts/distribution/*.sh`. These require release or explicit-check authority
  under the baseline; shared helper/installer/release edits alone do not activate them.
- Documentation/policy-only changes use `make check-doc-links`, instruction
  consistency review and `git diff --check`; they do not require installer/export
  regression suites. Run `make check-version` when maintaining the pending pair.

The common [contribution rules](rules/contributions.md) apply without a local
authority exception. Keep product-specific setup and checks here; do not repeat
the baseline's implementation, PR, checkout or fleet-delivery rules.
