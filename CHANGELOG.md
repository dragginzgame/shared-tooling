# Changelog

## [0.1.7]

### Added

- Add explicit-cutoff tag maintenance with a read-only preview, identity-checked
  deletion and saved selection for interrupted retries. Preserve local recovery
  tags until remote deletion is verified, and retain operation evidence.
  [#11](https://github.com/dragginzgame/shared-tooling/issues/11).
- Show the current local version with `make version`, backed by `VERSION` and
  updated alongside the changelog during standard release preparation.
- Share local-package lockfile updates that preserve external dependency
  selections, plus checks of consumers' actual formatting hooks, manifest sorting
  and working-edit preservation. Failed checks retain their evidence.
  [#15](https://github.com/dragginzgame/shared-tooling/issues/15),
  [#16](https://github.com/dragginzgame/shared-tooling/issues/16).
- Include pinned ripgrep with PCRE2 in this repository's `make install-tools`
  and offline `make tools-check`. Existing jq/yq consumers opt in with
  `--with-ripgrep` and reviewed archive pins.
  [#17](https://github.com/dragginzgame/shared-tooling/issues/17).
- Share portable file-digest generation across checksum verification, tool
  receipts and snapshot manifests, including unusual filenames and rejection
  of failed hash output. [#12](https://github.com/dragginzgame/shared-tooling/issues/12).
- Prepare isolated RustSec databases from explicit online or local sources,
  retaining the selected commit and failure logs while consumers keep audit
  policy. [#13](https://github.com/dragginzgame/shared-tooling/issues/13).
- Add shared documentation-link and release-command checks with retained release
  diagnostics. Exact crates.io version checks distinguish an absent version from
  an unavailable registry; publication and retry policy remain with callers.
  [#8](https://github.com/dragginzgame/shared-tooling/issues/8),
  [#9](https://github.com/dragginzgame/shared-tooling/issues/9),
  [#10](https://github.com/dragginzgame/shared-tooling/issues/10).

### Fixed

- Stop on failed or invalid release-version reads on Bash 3.2 before preparation
  and during metadata checks. Reject ignored release-runner failures, failed Git
  identity reads and invalid extracted-tool files explicitly.
  [#14](https://github.com/dragginzgame/shared-tooling/issues/14).
- Make RustSec isolation checks work in shallow CI checkouts, and reject invalid
  revisions or databases still borrowing source objects on Bash 3.2.
  [#13](https://github.com/dragginzgame/shared-tooling/issues/13).

## [0.1.6]

### Added

- Common `install-tools` and offline `tools-check` targets include pinned local
  jq and Mike Farah yq, with Linux Mint/macOS bootstrap instructions and matching
  local/CI parser selection.
- Common repository-local IC tool setup for Quill, ICP CLI, didc, ic-wasm,
  PocketIC and Binaryen, with reviewed platform checksums, offline verification,
  complete-set activation and retained failed installations. Add portable
  evidence-manifest, nonempty Cargo test and exact release-tag checks.
- Consolidated audit methods for code hygiene, flow convergence, complexity and
  module surface review, with a shared evidence contract and authorized cleanup
  procedure. Consumers retain product-specific obligations and historical reports
  while adopting the methods through reviewed snapshots.

## [0.1.5] - 2026-10-06

### Added

- Shared dependency-pinning rules and an offline CI checker for immutable Git and
  Action references, Cargo version constraints, tracked workspace lockfiles and
  explicit exceptions for sibling or moving inputs. Include a checksum-verified
  YAML/TOML parser installer and run the checker in Shared Tooling's release gate.

### Changed

- Require authorized dependency changes to prepare and verify every affected
  independent workspace lockfile, including path-dependent test harnesses,
  before release validation. Keep release fetching locked.
  [#6](https://github.com/dragginzgame/shared-tooling/issues/6).

### Fixed

- Keep nested validation in its intended checkout by limiting logger snapshot
  identity to its own invocation. Isolate independent fixtures' Make selections
  and exercise adoption under inherited release settings while preserving normal
  nested validation and failed logs.
  [#7](https://github.com/dragginzgame/shared-tooling/issues/7).

### Testing

- Keep snapshot fixture identities consistent through temporary-directory aliases,
  including macOS physical-path normalization.

## [0.1.4] - 2026-10-06

### Fixed

- Reject unrelated staged release content even when working files match HEAD,
  and verify that the index contains the prepared release metadata before commit.
- Reject conflicting pending changelog versions during preflight, before the
  validation gate or saved preparation intent can create recovery work.
- Retain actual failed release-validation logs across retries. If the configured
  log destination fails, preserve and report the temporary logs instead of
  deleting the remaining evidence.
- Protect edited, staged, deleted and untracked or ignored snapshot destinations
  before refresh replaces any file. Preserve unrelated edits and allow retries
  when the selected snapshot bytes are already installed.

### Testing

- Exercise real Git index/tree boundaries and the actual release logging adapter
  alongside interruption stubs, including hidden staged edits and retained logs
  after failed retries.

## [0.1.3] - 2026-10-06

### Added

- User-triggered agent commands for checking current CI, reviewing GitHub issues
  and recommending work after a task finishes. Enable checks across a session
  with one instruction; explicit repair requests authorize scoped local fixes.

### Fixed

- Stop pre-commit formatting when the formatter fails under Bash 3.2,
  preserving the selected index and working files.
- Install Rust formatting hooks through physical repository paths, including
  macOS temporary-directory aliases, without rejecting the correct checkout.
  [#1](https://github.com/dragginzgame/shared-tooling/issues/1).
- Normal release commands reconcile an interrupted release at its exact saved
  commit, including after a fix is committed. A different requested increment
  or newer committed source then receives fresh validation for the next release.
  Preserve tags, failed evidence, atomic push scope and conflict checks; bind
  consumer receipt checks to the selected `RELEASE_COMMIT`. Publication and
  cleanup remain separate.
  [#5](https://github.com/dragginzgame/shared-tooling/issues/5).

## [0.1.2] - 2026-10-05

### Added

- Standard Rust pre-commit formatting and safe repository-local installation.
  Format the staged snapshot and refresh only selected files; reject partial
  staging and preserve unrelated edits, including when formatting fails.
- Require Cargo.toml ordering through `cargo sort --workspace`, following IcyDB
  and Canic, with matching non-mutating checks in CI and release validation.
  Cover root, member and separately maintained workspace manifests.

### Changed

- Maintain the next version at the top of the changelog automatically. Compatible
  pre-1.0 changes share the next patch; a breaking hard cut raises the complete
  pending batch to the next minor without requiring a separate version request.
- Require every child Cargo manifest to inherit direct dependencies from root
  `[workspace.dependencies]`, including development, build and target-specific
  dependencies, so their versions and sources have one visible owner.

### Fixed

- Allow ordinary release targets to retry after preflight or validation failures
  against corrected source, preserving failed evidence and running fresh gates.
  Save durable intent immediately before preparation, retain existing early plans
  on restart and require exact resume from preparation onward, including when
  bumped metadata would otherwise select another version.

## [0.1.1] - 2026-10-05

### Added

- Common release contract and Makefile example requiring `release-patch`,
  `release-minor` and `release-major` in every repository. All three share one
  maintainer-owned preflight, validation, version/changelog preparation,
  staging, commit/tag and push workflow, with explicit repository inputs and
  interruption recovery.
- Implement the canonical release runner, bounded version arithmetic and
  changelog finalization. Retain exact release plans, reject concurrent runs,
  reconcile interrupted commit/tag/push effects and push only the selected
  branch and annotated tag atomically. Shared Tooling now provides the three
  standard targets and explicit resume command.
- Exercise release phases, rejection, artifact preservation and interrupted
  replies with offline command stubs; configure the portable regression set
  on Linux and both macOS 15 architectures under Apple's Bash 3.2.

## [0.1.0] - 2026-10-05

Initial release of the shared engineering baseline, developer tools and CI
building blocks for `dragginzgame` repositories.

### Added

- Common engineering baseline in `DRAGGINZGAME.md` and guides for simplicity,
  canonical authority, reviewable changes and Rust code hygiene. Consumers can
  adopt the baseline while retaining their local `AGENTS.md`.
- Cargo workspace LOC and test-attribute reports, a validation target runner
  with retained failure logs, a stable sccache launcher, and GitHub Actions
  inspection through the GitHub CLI.
- Checksum verification and installers for actionlint, Gitleaks and ShellCheck
  using consumer-selected versions and SHA-256 digests.
- Snapshot refresh and offline drift verification, with recorded source
  revisions, file digests and executable modes. Documentation covers the
  complete governance snapshot and interrupted-refresh recovery.
- Offline regression tests and CI jobs for Linux and macOS, plus shell lint,
  workflow lint and repository secret scanning.

### Changed

- Require every repository to maintain an accurate GitHub description aligned
  with its current purpose, README and implementation.
- Require cleanup reports to list every removed function, method and type by
  name, with its former location, removal reason and replacement when applicable.

### Fixed

- Export snapshot files and executable modes from the recorded Git revision.
  Reject files absent from that revision and keep concurrent working-tree edits
  out of consumer snapshots.
- Support snapshot verification on macOS Bash 3.2 with strict unset-variable
  checks, while preserving duplicate file-record rejection.
- Exclude nested workspace members from their parent package's LOC and
  test-attribute counts, and classify paths relative to each package.
- Create custom snapshot manifest directories before replacing consumer files,
  avoiding partial refreshes when a manifest parent is missing or blocked.
