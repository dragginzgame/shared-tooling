# Changelog

## [0.1.20]

### Changed

- Allow agents to complete explicitly requested PRs, including scoped commits
  and branch pushes. Ordinary contributions use PRs; merges, direct integration
  pushes and releases retain separate authorization.
  [Toko #1789](https://github.com/dragginzgame/toko/issues/1789).

### Testing

- Add locked real Prettier/Rust hook qualification to the native CI matrix,
  covering selected files, configuration, ignores and failed-format isolation.
  [#43](https://github.com/dragginzgame/shared-tooling/issues/43).
- Add native installer failure-artifact upload/download checks using the same
  collector as ordinary CI failures, verifying retained payload and log bytes.
  [#29](https://github.com/dragginzgame/shared-tooling/issues/29).

## [0.1.19]

### Added

- Retain a complete combined log for each failed validation batch, plus a latest
  combined view, while preserving raw per-target logs and failure status.
  [#37](https://github.com/dragginzgame/shared-tooling/issues/37).
- Share opt-in PocketIC client/server alignment checks using locked offline
  Cargo metadata, and verify externally selected server bytes before execution.
  [#45](https://github.com/dragginzgame/shared-tooling/issues/45).
- Check runner disk capacity with explicit paths and minimum free space, with
  optional usage diagnostics and no cleanup. Consumers retain their thresholds
  and runner-image policy.
  [#46](https://github.com/dragginzgame/shared-tooling/issues/46).

### Fixed

- Reject redirected Rust-tool installation paths before running tools or Cargo,
  preserving checkout ownership and retained installation evidence.
  [#54](https://github.com/dragginzgame/shared-tooling/issues/54).
- Accept trailing slashes and directory aliases in temporary paths used by tool
  command fixtures, including native macOS scratch directories.
  [#56](https://github.com/dragginzgame/shared-tooling/issues/56).
- Preserve historical changelog bytes, including absent terminal newlines, and
  reject already-dated release targets with varied heading whitespace.
  [#55](https://github.com/dragginzgame/shared-tooling/issues/55).

## [0.1.18]

### Fixed

- Isolate LOC fixtures from enclosing Cargo workspaces and target settings,
  and allow tooling-report tests before committing consumer adoption.
  [#47](https://github.com/dragginzgame/shared-tooling/issues/47),
  [#50](https://github.com/dragginzgame/shared-tooling/issues/50),
  [#53](https://github.com/dragginzgame/shared-tooling/issues/53).
- Reject Make options and assignments as validation targets before running
  any gate. [#30](https://github.com/dragginzgame/shared-tooling/issues/30).
- Reject failed formatter version probes and missing frontend scopes while
  preserving empty hook selections.
  [#49](https://github.com/dragginzgame/shared-tooling/issues/49).
- Exclude Cargo build output from Rust LOC and test totals when its configured
  path uses symlink aliases.
  [#31](https://github.com/dragginzgame/shared-tooling/issues/31).

### Added

- Provide shared pins and explicit local setup/check commands for cargo-sort,
  cargo-sort-derives and candid-extractor. Rust consumers can attach the set
  to their common setup commands.
  [#51](https://github.com/dragginzgame/shared-tooling/issues/51).

### Documentation

- Keep IC identity stores outside local reset and fresh-deploy cleanup paths,
  with home selection and recovery owned by each consumer.
  [#52](https://github.com/dragginzgame/shared-tooling/issues/52).

## [0.1.17]

### Fixed

- Keep LOC fixtures on their own Cargo manifests when temporary files live
  inside a consumer checkout, and isolate inherited target-directory settings.
  [#48](https://github.com/dragginzgame/shared-tooling/issues/48),
  [#47](https://github.com/dragginzgame/shared-tooling/issues/47).

## [0.1.16]

### Added

- Select an independent Cargo workspace with `make cloc CLOC_MANIFEST=testing/Cargo.toml`;
  reports use that workspace's configuration and exclude its generated output.
  [#41](https://github.com/dragginzgame/shared-tooling/issues/41),
  [#31](https://github.com/dragginzgame/shared-tooling/issues/31).
- Retain validation success/failure logs and timing tables in a selected run
  directory, with literal consumer failure-event highlighting and interrupted
  output preservation. Failed targets preserve Make's failure status.
  [#37](https://github.com/dragginzgame/shared-tooling/issues/37).
- Provide a prepared Prettier adapter for selected frontend files in the common
  formatting hook, alongside npm/Node pinning and publication guidance.
  [#43](https://github.com/dragginzgame/shared-tooling/issues/43).

### Fixed

- Finalize drafts with trailing heading whitespace without separating their
  notes from the selected release or rewriting historical headings.
  [#38](https://github.com/dragginzgame/shared-tooling/issues/38).
- Refuse symlinked cache runtime paths before creating directories through them.
  [#32](https://github.com/dragginzgame/shared-tooling/issues/32).
- Count shared tooling correctly with custom manifest locations, nested bundle
  roots and equivalent HTTPS/SSH source URLs. Explicit root selection handles
  other layouts without guessing from matching hashes.
  [#39](https://github.com/dragginzgame/shared-tooling/issues/39).

### Documentation

- Add canister audit guidance for Candid consumers, lifecycle obligations and
  measured Wasm budgets; clarify first-run scope and requested ranked backlogs.
  [#44](https://github.com/dragginzgame/shared-tooling/issues/44).
- Define release fixture ownership before consumer deduplication and document
  the formatting checker's limitation for historical symlinks.
  [#40](https://github.com/dragginzgame/shared-tooling/issues/40),
  [#33](https://github.com/dragginzgame/shared-tooling/issues/33).

## [0.1.15]

### Added

- Inventory sibling CI and tooling with `make cloc-tooling`, separating local
  code from checksum-matching shared snapshots and supporting data. JSON output
  includes file counts and hashes to guide consolidation reviews.
- Summarize sibling repositories' Rust runtime/test LOC and test counts with
  `make cloc`, or `scripts/dev/cloc-siblings.sh` for an explicit parent directory.
  Counts reuse the existing workspace report with locked, offline metadata;
  unavailable or failed reports remain visible alongside successful rows. A
  final total sums successful reports with a combined test percentage and is
  marked partial if any repository fails.
- Install checksum-pinned cloc through `make install-host-tools`. LOC reports
  automatically use prepared local tools and report missing prerequisites once
  before scanning sibling workspaces.
- Supply common setup, offline verification and LOC commands through one shared
  Make include. Consumers adopt it with the reviewed snapshot; Make and CI use
  the same complete tool selection without maintaining copied recipes.

### Documentation

- Define the common required tool inventory and complete consumer setup example,
  including ripgrep and cloc in both installation and offline checks. Explain
  how repository-local installation differs from interactive shell PATH setup.
- Explicitly approve IcyDB's existing `crates/`, `canisters/`, `schema/` and
  `testing/` layout without package moves. Workspace inheritance and full member
  coverage still apply; future layout redesigns require separate approval.
  [#34](https://github.com/dragginzgame/shared-tooling/issues/34),
  [IcyDB #310](https://github.com/dragginzgame/icydb/issues/310).

## [0.1.14]

### Fixed

- Reject inherited Make modes that ignore failures or skip execution before
  release, validation and pre-commit formatting. Preserve release selections and
  parallel-job settings. Consumers add the shared Make execution check to their
  reviewed snapshots when adopting these entrypoints.
  [#30](https://github.com/dragginzgame/shared-tooling/issues/30).
- Exclude Cargo's selected build directory from Rust LOC and test-function
  reports, including custom build paths inside packages.
  [#31](https://github.com/dragginzgame/shared-tooling/issues/31).
- Run snapshot distribution fixtures in existing consumers without replacing
  their snapshot manifest or masking dirty-destination checks.
  [#36](https://github.com/dragginzgame/shared-tooling/issues/36).

### Documentation

- Allow application-owned Rust packages under `apps/` alongside the standard
  `crates/` layout, sharing root workspace versions and dependencies. Existing
  layouts in either tree need no relocation.
  [#34](https://github.com/dragginzgame/shared-tooling/issues/34).
- Correct the four IC Host Tooling package owners in the provisioning and
  provenance guides while preserving historical setup attribution.
  [#35](https://github.com/dragginzgame/shared-tooling/issues/35).

## [0.1.12]

### Added

- Inspect GitHub Actions runs for an exact local commit across workflows, with
  explicit listing limits and clearly labelled historical failure searches.
- Check portable-test tools and formatter prerequisites before starting
  fixtures, reporting missing commands together with setup instructions.

### Fixed

- Keep release observation and atomic push bound to the recorded destination,
  refusing remote changes during validation or before dispatch.
  [#25](https://github.com/dragginzgame/shared-tooling/issues/25).
- Use the common installer for standalone yq, rejecting failed version probes
  and directory destinations while preserving installed tools and failed inputs.
  Consumers also include the common installer in their selected snapshot.
  [#26](https://github.com/dragginzgame/shared-tooling/issues/26).
- Verify snapshot contents independently of the inspected checksum helper,
  preventing a changed helper from approving changed files.
  [#27](https://github.com/dragginzgame/shared-tooling/issues/27).
- Keep the governance snapshot's linked guides complete through one maintained
  file list checked as an isolated consumer export.
  [#28](https://github.com/dragginzgame/shared-tooling/issues/28).
- Collect CI failure evidence after native tool qualification, including retained
  installer candidates and diagnostics. Use pinned local ripgrep without a
  duplicate package-manager installation.
  [#29](https://github.com/dragginzgame/shared-tooling/issues/29).

## [0.1.11]

### Changed

- Apply authorized local fixes directly and report findings to their owning
  repositories under standing issue-reporting authorization. Consumers adopt
  the shared rule through a reviewed governance snapshot.
  [#24](https://github.com/dragginzgame/shared-tooling/issues/24).

### Fixed

- Keep pending changelog notes distinct from undated history when version
  components exceed floating-point integer precision.
  [#23](https://github.com/dragginzgame/shared-tooling/issues/23).
- Keep successful and ignored Rust tests with `error::` names unlabelled in
  validation output. Highlight real diagnostics and failed tests, and retain
  surrounding failure context with a neutral target label.
  [#22](https://github.com/dragginzgame/shared-tooling/issues/22).
- Generate failure-injection launchers portably on macOS and Linux so retention
  checks reach the intended failure and verify preserved evidence.
  [#21](https://github.com/dragginzgame/shared-tooling/issues/21).

## [0.1.10]

### Added

- Add a checksum-verified sccache CI installer for Linux x86-64, retaining failed
  candidates and preserving the installed executable on rejection. Consumers
  continue to select the version, digest and compiler-cache configuration.
  [#20](https://github.com/dragginzgame/shared-tooling/issues/20).

### Fixed

- Preserve failed portable regression fixtures for inspection and CI artifact
  upload, while continuing to remove successful temporary fixtures.
  [#21](https://github.com/dragginzgame/shared-tooling/issues/21).
- Allow tag-maintenance retries to reuse retained evidence directories whose
  generated names contain underscores, while still rejecting unsafe paths.
  [#11](https://github.com/dragginzgame/shared-tooling/issues/11).

## [0.1.9]

### Added

- Share offline formatter prerequisite checks so consumers use their reviewed
  cargo-sort pin and prepared rustfmt consistently, without implicit installs.
  [#19](https://github.com/dragginzgame/shared-tooling/issues/19).

### Fixed

- Restore exact authenticated archive bytes in host-tool recovery fixtures,
  avoiding failures caused by regenerated archive headers. Retain failed CI
  fixtures and diagnostics for native-host investigation.
  [#17](https://github.com/dragginzgame/shared-tooling/issues/17).

## [0.1.8] - 2026-10-06

### Added

- Add opt-in Cargo workspace inheritance checks and a shared read-only workspace
  version reader, covering ordinary dependency tables and valid TOML comments.
  [#18](https://github.com/dragginzgame/shared-tooling/issues/18).
- Allow dependency-free consumers to check their formatting hooks without
  inventing dependencies to test sorting. Rust formatting, manifest preservation
  and hook installation checks remain active.
  [#16](https://github.com/dragginzgame/shared-tooling/issues/16).

### Changed

- Consolidate the actionlint, ShellCheck and gitleaks installers, retaining failed
  candidates and preserving the selected executable on rejection. Snapshot
  consumers must include the new shared installer implementation when refreshing
  these entry points; command arguments and pins are unchanged.
  [#18](https://github.com/dragginzgame/shared-tooling/issues/18).

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
