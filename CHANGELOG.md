# Changelog

## [0.3.3]

### Fixed

- Reject malformed validation nesting depth before dispatch, and require explicit
  runner completion before returning success. Premature exits on Bash 3.2 fail
  and preserve available evidence while completed target failures retain their
  original status.
  ([#104](https://github.com/dragginzgame/shared-tooling/issues/104))

## [0.3.2]

### Fixed

- Require explicit fixture completion before reporting success or deleting test
  evidence, including Bash 3.2 errors that otherwise return a zero exit status.
  ([#103](https://github.com/dragginzgame/shared-tooling/issues/103))
- Preserve Cargo jobserver descriptors through shared formatting, LOC reports
  and Rust tool setup/check commands. Apply the existing Make execution guard to
  standalone tool includes so dry-run, touch, question and ignore-errors modes cannot
  dispatch installers.
  ([#99](https://github.com/dragginzgame/shared-tooling/issues/99))

### Added

- Include advisory README freshness reviews in the routine maintenance pass,
  without rewriting prose or adding release gates.
  ([#100](https://github.com/dragginzgame/shared-tooling/issues/100))

## [0.3.1]

### Fixed

- Refuse unsupported platforms and unavailable Rust/Cargo toolchains before
  common tool setup downloads anything. Host-tool diagnostics identify the tool,
  expected version, selected path and repair command while preserving byte
  authentication, offline checks and retained artifacts.
  ([#101](https://github.com/dragginzgame/shared-tooling/issues/101))

## [0.3.0]

### Breaking

- Standardize `install-tools` and `tools-check` on the complete common host, IC
  and Cargo toolsets in every repository. Host setup always includes ripgrep and
  cloc; remove their optional flags and redundant Rust aggregate prerequisites.
  Register product tools through the ordered local target lists, prepare a Rust
  toolchain, and refresh the shared scripts and pin catalogs together. Existing
  installations and failed evidence remain preserved.
  ([#98](https://github.com/dragginzgame/shared-tooling/issues/98),
  [adoption guide](docs/consuming-snapshots.md#complete-toolset-adoption-in-030))

### Changed

- Highlight sibling issue completion with pale whole-row text colours and list the
  lowest percentages first. Show separate issues fixed and added today columns
  using a daylight-saving-aware 06:00 Europe/Monaco cutoff, and keep repository
  number padding at a minimum of four characters without widening it for fleet
  totals or errors.

## [0.2.14]

### Fixed

- Report unavailable failed-step logs during CI inspection instead of silently
  succeeding. Retain partial logs and fetch errors, while allowing successful
  runs that legitimately have no failed-step logs.
  ([#97](https://github.com/dragginzgame/shared-tooling/issues/97))

## [0.2.13]

### Fixed

- Identify the exact missing or invalid selected Cargo executable in setup/check
  failures. Release preparation now requires the consumer's existing selected-tool
  setup and early offline checks; consumer adapters must adopt that ordering.
  ([#96](https://github.com/dragginzgame/shared-tooling/issues/96))

## [0.2.12]

### Fixed

- Reject line breaks in snapshot directory paths before export or verification
  can select a different checkout. Check resolved aliases as well as supplied
  paths, preserving ordinary paths and existing artifacts.
  ([#95](https://github.com/dragginzgame/shared-tooling/issues/95))

## [0.2.11]

### Fixed

- Reject unsafe Make modes even when `MAKEFLAGS` is cleared or replaced, before
  release or formatting recipes run. Preserve normal parallel and recursive
  commands; refuse assignments that overwrite Make's retained `MFLAGS` evidence.
  ([#30](https://github.com/dragginzgame/shared-tooling/issues/30))

## [0.2.10]

### Changed

- Keep formatting output to one success line or a short failure summary with a
  retained diagnostic log. Shared Rust recipes and custom formatter adapters use
  the same reporter; CI failure artifacts include its logs.
  ([#92](https://github.com/dragginzgame/shared-tooling/issues/92))

### Added

- Observe exact crates.io package metadata through the shared registry checker,
  with bounded, retained responses and validated checksum/yanked facts. Consumers
  can replace duplicate readback while retaining their own publication policy.
  ([#94](https://github.com/dragginzgame/shared-tooling/issues/94))

## [0.2.9]

### Added

- Show open, merged and closed-without-merge pull requests alongside issue counts
  in the sibling GitHub dashboard, keeping issue completion percentages separate.
  Center the issue/PR group headings and completion heading, and expand numeric
  padding from four characters to fit the report's counts and totals.
- Record Shared Tooling's source version during snapshot refresh and show each
  sibling's recorded version, revision and integrity in the tooling report.
  Existing snapshots without a version remain explicit until refreshed.

### Fixed

- Use authenticated, current-run artifact readback for CI evidence qualification,
  preserving exact uploaded IDs and digest/payload verification.
  ([#93](https://github.com/dragginzgame/shared-tooling/issues/93))
- Include every declared snapshot file in fleet integrity checks, so missing
  files and drift in documents or executable modes cannot appear intact merely
  because they are outside the tooling LOC scope.

## [0.2.8]

### Fixed

- Keep Make admission bound to the selected snapshot when another tooling root
  is inherited or supplied on the command line. Support recursive Make commands
  with extra arguments while retaining unsafe execution-mode rejection.
  ([#30](https://github.com/dragginzgame/shared-tooling/issues/30))

## [0.2.7]

### Fixed

- Reject Make modes that can hide failed release or formatting commands at the
  shared entrypoints, preserving the existing runner and hook guards.
  ([#30](https://github.com/dragginzgame/shared-tooling/issues/30))
- Keep release-command qualification bound to its disposable snapshot even when
  the caller exports another tooling root.
  ([#7](https://github.com/dragginzgame/shared-tooling/issues/7))
- Preserve newline-ending checkout paths during formatting-hook qualification,
  including access to the source Git objects.
  ([#90](https://github.com/dragginzgame/shared-tooling/issues/90))

## [0.2.6]

### Added

- Optional shared Make includes for standard release entrypoints and simple
  Rust formatting, giving repeated recipes one maintained owner while leaving
  consumer validation and release policy local. Shared Tooling uses the release
  include; consumers adopt the reviewed files explicitly.
  ([#91](https://github.com/dragginzgame/shared-tooling/issues/91),
  [#92](https://github.com/dragginzgame/shared-tooling/issues/92))

### Fixed

- Let the checkout-local formatter fixture run with Apple's system Make by
  resolving its executable through the recipe's exported PATH. Preserve checks
  for missing and wrong-version tools, and clarify the portable recipe pattern.
  ([#85](https://github.com/dragginzgame/shared-tooling/issues/85))

## [0.2.5]

### Fixed

- Preserve existing hook selections whose paths end in newlines, and allow
  formatting-hook installation and execution in checkouts with trailing-newline
  directory names. Failed Git reads still stop setup without changing config.
  ([#89](https://github.com/dragginzgame/shared-tooling/issues/89))

## [0.2.4]

### Fixed

- Check the required helpers when exporting more reusable test suites and the
  sibling LOC report. Incomplete selections now fail before changing consumer
  files; complete focused selections remain independently runnable.
  ([#73](https://github.com/dragginzgame/shared-tooling/issues/73))

## [0.2.3]

### Fixed

- Reject incomplete CI installer test snapshots during export, before changing
  consumer files. Consumers selecting the optional suite must explicitly include
  all five installer wrappers and their shared dependencies.
  ([#73](https://github.com/dragginzgame/shared-tooling/issues/73))

## [0.2.2]

### Fixed

- Publish CI tools to the exact requested executable path, preventing a directory
  created during setup from redirecting installation or losing existing files.
  Failed publication retains the downloaded candidate; late symlink targets
  remain untouched. Perl is checked before setup for atomic publication.
  ([#88](https://github.com/dragginzgame/shared-tooling/issues/88))

## [0.2.1]

### Fixed

- Install and verify every selected IC tool when its pin matrix has no final
  newline. Setup can no longer silently omit the last tool while offline checks
  report success. Existing pin files and retained bundles are preserved.
  ([#87](https://github.com/dragginzgame/shared-tooling/issues/87))

## [0.2.0]

### Breaking

- Transfer PocketIC provisioning and compatibility admission to IC Testkit.
  The shared IC bundle now contains five tools; PocketIC pins and the separate
  alignment/binary checkers are removed. Consumers must adopt Testkit's explicit
  setup and offline check, update their snapshot selections and server callers,
  and reinstall the shared bundle. Existing bundles and evidence are retained.
  See the [adoption steps](docs/ic-tools.md#pocketic-ownership-handoff).
  ([#76](https://github.com/dragginzgame/shared-tooling/issues/76))

## [0.1.38]

### Fixed

- Reject exception catalogs containing multiple JSON documents, preventing
  malformed dependency-pinning exceptions from bypassing required validation.
  Valid single-array catalogs continue to work unchanged.
  ([#86](https://github.com/dragginzgame/shared-tooling/issues/86))

## [0.1.37]

### Fixed

- Pre-commit formatting and its adoption check now find tools prepared in the
  original checkout without requiring a shell PATH export. Formatting still
  uses isolated staged inputs and rejects missing or incorrectly pinned tools.
  ([#85](https://github.com/dragginzgame/shared-tooling/issues/85))

## [0.1.36]

### Fixed

- Reject conflicting multi-document Cargo tool receipts during setup and offline
  checks, recheck installation-directory ancestors after Cargo returns, and
  preserve Cargo's original failure status alongside retained build evidence.
  Existing valid installations remain reusable.
  ([#65](https://github.com/dragginzgame/shared-tooling/issues/65))

## [0.1.35]

### Changed

- Clarify that authorized dependency updates include registry access, while
  release/deployment preparation fetches locked dependencies before offline
  validation; agents must not impose offline mode on those preparation steps.
  ([#84](https://github.com/dragginzgame/shared-tooling/issues/84))

### Added

- Install consumer-selected Cargo binaries and examples through the shared Rust
  tool installer, with explicit profiles, offline receipt and byte checks, and
  retained failed builds that leave earlier installations usable.
  ([#65](https://github.com/dragginzgame/shared-tooling/issues/65))

## [0.1.34]

### Fixed

- Include locked dependency-cache preparation before compiled release adapters,
  preserving explicit offline settings and interrupted metadata recovery.
  ([#84](https://github.com/dragginzgame/shared-tooling/issues/84))
- Resolve PocketIC alignment manifests correctly under `CDPATH` and unusual
  directory names; stop before Cargo if the selected directory becomes unavailable.
  ([#82](https://github.com/dragginzgame/shared-tooling/issues/82))

### Changed

- Keep small-fix handoffs and issue updates proportionate, linking retained
  evidence and separating independent follow-up work.
  ([#81](https://github.com/dragginzgame/shared-tooling/issues/81))

## [0.1.33]

### Changed

- Make the sibling issue dashboard easier to scan with repository names first,
  repositories ranked by remaining issues, dashed separators and comma-separated
  counts padded with spaces to six characters, followed by the percentage in
  parentheses for closed/total counts.
- Make fleet reports an optional consumer snapshot selection while preserving
  existing commands, so local tool setup and workspace LOC reporting do not
  require copies of fleet reporters or their tests.
  ([#83](https://github.com/dragginzgame/shared-tooling/issues/83))

## [0.1.32]

### Fixed

- Preserve running and queued native CI for each pushed commit while allowing
  newer PR revisions to replace older review runs.
  ([#80](https://github.com/dragginzgame/shared-tooling/issues/80))
- Resolve Cargo-install qualification evidence paths independently of `CDPATH`,
  preserving unusual directory names and refusing existing evidence roots before
  tool execution. Accept both Cargo receipt spellings for `--debug`, fixing a
  false rejection after successful native macOS installation.
  ([#65](https://github.com/dragginzgame/shared-tooling/issues/65))

### Changed

- Document the PocketIC handoff to Testkit, including the published setup/check
  prerequisite and preservation of existing bundles before the current installer
  contract can be retired.
  ([#76](https://github.com/dragginzgame/shared-tooling/issues/76))

## [0.1.31]

### Fixed

- Remove short job/step limits from Cargo-install qualification and portable
  regression so long builds can finish within GitHub Actions' default limits.
  Ordinary failure evidence collection remains enabled.
- Select the intended sibling directory when `CDPATH` is set or its name ends
  in a newline, keeping the issue dashboard scoped to the requested repositories.
  ([#78](https://github.com/dragginzgame/shared-tooling/issues/78))
- Reuse verified IC tools when pin comments or row order change, avoiding
  unnecessary downloads while preserving installation provenance and all
  selection, checksum and version checks.
  ([#79](https://github.com/dragginzgame/shared-tooling/issues/79))

### Changed

- Clarify that Shared Tooling owns fleet consistency and cross-repository reports;
  IC Metrics remains responsible for reusable measurement arithmetic. Consumers
  adopt the tooling they need without adding fleet dashboards to their CI.

## [0.1.30]

### Testing

- Add repeatable native Cargo binary/example installation qualification, including
  offline reuse, concurrency and preservation after compiler failure. An explicit
  Linux/macOS workflow collects the evidence needed for consumer-tool extraction.
  ([#65](https://github.com/dragginzgame/shared-tooling/issues/65))

## [0.1.29]

### Added

- Add a live terminal issue dashboard for connected sibling repositories, with
  total, open and closed counts, percent fixed, combined totals and visible
  observation failures. Refresh automatically or print a single report.
- Add optional, offline npm/Node declaration checks using each consumer's selected
  root and tool versions, including lock agreement, immutable Git inputs and
  qualified sibling paths. Shared Tooling checks its own frontend fixture pins.
  ([#77](https://github.com/dragginzgame/shared-tooling/issues/77))

### Fixed

- Explain refused release source with staged, unstaged and untracked paths while
  preserving files and the index. Initial preflight failures identify that
  validation and version preparation have not started for the attempt.
  ([#74](https://github.com/dragginzgame/shared-tooling/issues/74))
- Update the shared PocketIC server default to 16.1.0 with reviewed archive
  checksums. Consumer protocol qualification remains with IC Testkit and its
  callers. ([#76](https://github.com/dragginzgame/shared-tooling/issues/76))

## [0.1.28]

### Added

- Add a readable maintenance task catalog and an opt-in local agent schedule for
  three-day dependency, MSRV, Rust freshness, CI and snapshot checks, with rotating
  audits, retained reports and owning-repository issue follow-up.

### Fixed

- Reject malformed active host/IC tool links before execution or downloads,
  preserving their exact targets instead of accepting a newline-trimmed name.
  [#75](https://github.com/dragginzgame/shared-tooling/issues/75).
- Keep consumer release-runner tests simulation-only while retaining real-Git
  tracking and recovery qualification in the complete owner suite.
  [#70](https://github.com/dragginzgame/shared-tooling/issues/70).
- Increase the portable regression and job budgets so Intel macOS has time to
  finish validation and retain failure evidence.
  [#71](https://github.com/dragginzgame/shared-tooling/issues/71).

### Testing

- Cover incomplete installer-test snapshots and explicit simulation-test
  selections, checking refusal before any consumer files change.
  [#73](https://github.com/dragginzgame/shared-tooling/issues/73),
  [#60](https://github.com/dragginzgame/shared-tooling/issues/60).

## [0.1.27]

### Fixed

- Resolve script entry paths independently of inherited directory search, and
  preserve physical path bytes while locating helpers.
  [#67](https://github.com/dragginzgame/shared-tooling/issues/67).
- Compact freshly verified active host/IC bundles when explicitly selected,
  retaining caller pins, check logs, IC receipts and full failed candidates.
  [#66](https://github.com/dragginzgame/shared-tooling/issues/66).

- Isolate metadata fixtures from inherited Make includes and GNU flags; qualify
  their own release identity through nested Make/logger execution while preserving
  production selections and jobserver behavior.
  [#7](https://github.com/dragginzgame/shared-tooling/issues/7).

- Retain Rust-tool build evidence and captured setup/check logs in the shared
  failure collector, including when host/IC evidence is compacted.
  [#68](https://github.com/dragginzgame/shared-tooling/issues/68).
- Recognize dotted snapshot names in tooling LOC reports, counting shared files
  once across overlapping manifests while preserving integrity checks.
  [#69](https://github.com/dragginzgame/shared-tooling/issues/69).

## [0.1.26]

### Fixed

- Allow an unchanged, verified snapshot to refresh again before a consumer commit,
  while refusing edited files, staged conflicts and changes made during preparation.
  [#64](https://github.com/dragginzgame/shared-tooling/issues/64).

## [0.1.25]

### Fixed

- Preserve literal evidence roots and output names, including trailing newlines;
  refuse occupied special-file outputs and symlink-parent traversal.
  [#59](https://github.com/dragginzgame/shared-tooling/issues/59).
- Preserve concurrently installed symbolic tracking refs after release, including
  replacements that resolve to the same commit. Check ref type under Git's update
  lock before refreshing local status.
  [#62](https://github.com/dragginzgame/shared-tooling/issues/62).

## [0.1.24]

### Added

- Share evidence archiving across CI collectors, preserving unusual Unix
  filenames, modes and symlinks through a single archive upload.
  [#59](https://github.com/dragginzgame/shared-tooling/issues/59).
- Extend existing snapshots with explicit `--add-file` selections and reject
  missing shared companions before replacing consumer files.
  [#60](https://github.com/dragginzgame/shared-tooling/issues/60).

### Fixed

- Refresh matching local upstream tracking after confirmed direct release or
  completed resume, so already-published commits do not repeatedly appear ahead.
  Preserve captured-URL delivery, concurrent tracking values and unrelated upstreams.
  [#62](https://github.com/dragginzgame/shared-tooling/issues/62).
- Include `bin/` tooling and repositories awaiting their first commit in sibling
  LOC reports, with explicit bootstrap identity and retained corruption checks.
  [#61](https://github.com/dragginzgame/shared-tooling/issues/61).

## [0.1.23]

### Fixed

- Keep PR release lookup working with packaged GitHub CLI versions that lack
  `--slurp`, while rejecting incomplete responses and conflicting PRs across
  pages. [#42](https://github.com/dragginzgame/shared-tooling/issues/42).
- Recheck release payloads and exact tags after final consumer checks, and
  verify published identity when resuming completed direct releases. Refuse
  conflicts without repeating release effects.
  [#58](https://github.com/dragginzgame/shared-tooling/issues/58).

## [0.1.22]

### Fixed

- Prevent false sibling LOC test failures when temporary paths have trailing
  slashes or directory aliases, preserving report and failure-retention checks.
  [#57](https://github.com/dragginzgame/shared-tooling/issues/57).
- Give native CI enough time for the expanded release tests, with a separate
  test-step limit that leaves room for failure-artifact collection.
  [#42](https://github.com/dragginzgame/shared-tooling/issues/42).

## [0.1.21]

### Added

- Support explicitly selected PR-gated releases: prepare one release PR, resume
  after merge/squash/rebase, and fully validate the exact merged commit before
  publishing its tag. Preserve the default direct atomic flow and retained
  recovery evidence. [#42](https://github.com/dragginzgame/shared-tooling/issues/42).

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
