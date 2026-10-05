# Changelog

## [Draft]

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
