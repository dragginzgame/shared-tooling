# Changelog

## [0.9.3]

### Fixed

- Retry transient host and IC asset-download failures within bounded attempt and
  time limits. Permanent download errors and checksum failures remain terminal;
  failed candidates and previous tool selections are retained.
  ([#138](https://github.com/dragginzgame/shared-tooling/issues/138))

## [0.9.2]

### Fixed

- Reject NUL bytes in evidence checksum manifests before hashing any referenced
  file, preventing malformed digests or paths from being silently rewritten by
  Bash. Verification parses the same captured input and preserves the evidence.
- Reject CR/LF in supplied and resolved consumer paths before tool setup,
  configuration loading or preflight, including symlinks that previously hid an
  invalid path from the host, IC and Rust installers.

## [0.9.1]

### Fixed

- Host and IC tool installation now share lock, verified-cache reuse and cleanup
  handling. A checkout cleanup failure still releases the shared lock, preserves
  the original installation error and retains failed candidates for inspection.
  Cleanup failures also fail the command when installation otherwise succeeded.

## [0.9.0]

### Changed

- Use one manifest reader for snapshot refresh, integrity verification and fleet
  tooling reports, preventing their format checks from drifting. Existing
  snapshots, refresh commands and drift reporting remain supported.
  ([#133](https://github.com/dragginzgame/shared-tooling/issues/133))
- Expose validated manifest records through
  `verify-shared-tooling-snapshot.sh --read-manifest FILE`. Malformed input emits
  no records; payload integrity and ownership remain separate checks.

### Fixed

- Reject NUL bytes before splitting snapshot records so invalid bytes cannot be
  silently discarded. Validation and parsing use the same captured manifest.

## [0.8.4]

### Added

- Read workspace LOC counts as JSON with `cloc.sh --json`. Sibling aggregation
  consumes numeric totals without parsing display tables; existing human-readable
  reports and partial-failure handling remain unchanged.

### Changed

- Clarify that snapshot refresh derives declared script companions automatically,
  while consumers explicitly select governance roots and optional functionality.
- Archive older release detail by minor version, preserving historical notes,
  dates and issue links behind concise root summaries.

## [0.8.3]

### Fixed

- Reject redirected Cargo build-observation files before writing diagnostics,
  preserving outside files, failed evidence and the previous tool selection.
  ([#136](https://github.com/dragginzgame/shared-tooling/issues/136))
- Formatting admission now uses the selected Rust tool catalog consistently with
  installation, including when host and Rust pins live in separate files.
  ([#135](https://github.com/dragginzgame/shared-tooling/issues/135))
- Minimal Make snapshots include their common installers and default LOC helper.
  Snapshot refresh replaces individual payloads atomically so an interrupted copy
  can be retried without leaving truncated destinations; local-edit and index
  conflict checks remain enforced.
  ([#131](https://github.com/dragginzgame/shared-tooling/issues/131))
- Keep successful ripgrep PCRE2 capability checks quiet while retaining failure
  diagnostics.

## [0.8.2]

### Added

- Check Cargo tool freshness with `make check-cargo-tool-versions`: compare shared
  pins, checkout selections and user-installed packages with current non-yanked
  stable releases. Report missing tools and unavailable registry observations
  separately, retaining response evidence without installing or changing pins.

## [0.8.1]

### Fixed

- Reject malformed snapshot fields consistently during refresh, verification and
  tooling inventory, while preserving literal spaces in filenames.
  ([#133](https://github.com/dragginzgame/shared-tooling/issues/133))
- Retain both build-identity observations when the Cargo tool environment changes
  during installation. Diagnostics identify changed fields and the evidence to
  compare; activation still refuses and preserves the previous selection.
  ([#134](https://github.com/dragginzgame/shared-tooling/issues/134))

## [0.8.0]

### Breaking

- Snapshot refresh automatically removes unchanged, previously owned files outside
  the selected entrypoints and their dependencies. Remove `--retire-file` from
  refresh commands; preview lists removals without requiring individual approvals.
  Select directly used helpers as entrypoints to retain them. Ownership, local-edit,
  staging and concurrency checks still protect retirement and interrupted retries.
  ([#131](https://github.com/dragginzgame/shared-tooling/issues/131))

## [0.7.0]

- **Breaking:** Select snapshot entrypoints and derive their required shared files automatically. Replace `--file` / `--add-file` with `--entrypoint` / `--add-entrypoint` and explicitly select roots for existing snapshots. [Detailed notes](docs/changelog/0.7.md).
  ([#131](https://github.com/dragginzgame/shared-tooling/issues/131))

## [0.6.6]

- Select `cargo-sort-derives` 0.14.1 to preserve literal `$crate` paths during direct and conditional derive sorting. [Detailed notes](docs/changelog/0.6.md).
  ([#113](https://github.com/dragginzgame/shared-tooling/issues/113))

## [0.6.5]

- Admit prepared Rust-tool receipts during staged formatting while checking the exported pins and compiler. [Detailed notes](docs/changelog/0.6.md).
  ([#130](https://github.com/dragginzgame/shared-tooling/issues/130), [#129](https://github.com/dragginzgame/shared-tooling/issues/129), [#128](https://github.com/dragginzgame/shared-tooling/issues/128))

## [0.6.4]

- Provide one shared Make entrypoint for common setup, offline checks, formatting, hook installation and releases. [Detailed notes](docs/changelog/0.6.md).
  ([#130](https://github.com/dragginzgame/shared-tooling/issues/130))

## [0.6.3]

- Restart interrupted direct preparation automatically after its metadata disposition is committed in a clean descendant checkout. [Detailed notes](docs/changelog/0.6.md).
  ([#126](https://github.com/dragginzgame/shared-tooling/issues/126))

## [0.6.2]

- Explain source conflicts in interrupted releases with exact plan and commit identities, and document guarded recovery when consumer evidence proves preparation never began. [Detailed notes](docs/changelog/0.6.md).
  ([#126](https://github.com/dragginzgame/shared-tooling/issues/126), [#123](https://github.com/dragginzgame/shared-tooling/issues/123))

## [0.6.1]

- Stop Cargo setup immediately on lock, validation or activation failures, with the original failure status and retained evidence. [Detailed notes](docs/changelog/0.6.md).
  ([#120](https://github.com/dragginzgame/shared-tooling/issues/120), [#124](https://github.com/dragginzgame/shared-tooling/issues/124), [#127](https://github.com/dragginzgame/shared-tooling/issues/127))

## [0.6.0]

- **Breaking:** Share Cargo-built tools across checkouts using a standard tool-build environment and exact build identities. Refresh installers and evidence collection, then reinstall and check common and selected Cargo tools. [Detailed notes](docs/changelog/0.6.md).
  ([#120](https://github.com/dragginzgame/shared-tooling/issues/120), [#121](https://github.com/dragginzgame/shared-tooling/issues/121), [#122](https://github.com/dragginzgame/shared-tooling/issues/122), [#123](https://github.com/dragginzgame/shared-tooling/issues/123))

## [0.5.0]

- **Breaking:** Share verified host and IC tool bundles across checkouts through a per-user store. Refresh installers and evidence collection, then rerun host/IC setup and offline checks. [Detailed notes](docs/changelog/0.5.md).
  ([#120](https://github.com/dragginzgame/shared-tooling/issues/120))

## [0.4.2]

- Establish the policy that Shared Tooling owns shared executable storage. [Detailed notes](docs/changelog/0.4.md).
  ([#120](https://github.com/dragginzgame/shared-tooling/issues/120))

## [0.4.1]

- Classify releases by their own consumer impact: adopting a breaking Shared Tooling update does not require a library minor release when its published contract remains unchanged. [Detailed notes](docs/changelog/0.4.md).
  ([#118](https://github.com/dragginzgame/shared-tooling/issues/118), [#119](https://github.com/dragginzgame/shared-tooling/issues/119))

## [0.4.0]

- **Breaking:** Install common Rust tools through verified, versioned slots. Refresh shared callers, use `.tools/rust/common/bin` in PATH, then rerun setup and offline checks. [Detailed notes](docs/changelog/0.4.md).
  ([#118](https://github.com/dragginzgame/shared-tooling/issues/118))

## [0.3.12]

- Keep formatting-adoption checks working with relative or symlinked temporary directories, preserving failure diagnostics in the selected location. [Detailed notes](docs/changelog/0.3.md).
  ([#116](https://github.com/dragginzgame/shared-tooling/issues/116))

## [0.3.11]

- Align the canonical version with the delivered 0.3.10 changes so subsequent snapshot exports report the intended source version. [Detailed notes](docs/changelog/0.3.md).
  ([#114](https://github.com/dragginzgame/shared-tooling/issues/114), [#110](https://github.com/dragginzgame/shared-tooling/issues/110))

## [0.3.10]

- Normalize temporary fixture paths so host-tool checks accept symlinked roots and release-command checks keep working with a relative temporary directory, including their nested Make probes. [Detailed notes](docs/changelog/0.3.md).
  ([#111](https://github.com/dragginzgame/shared-tooling/issues/111), [#112](https://github.com/dragginzgame/shared-tooling/issues/112), [#113](https://github.com/dragginzgame/shared-tooling/issues/113))

## [0.3.9]

- Run Rust tool preflight, checks and installation from the selected consumer directory so toolchain and Cargo configuration agree when invoked elsewhere. [Detailed notes](docs/changelog/0.3.md).
  ([#101](https://github.com/dragginzgame/shared-tooling/issues/101), [#110](https://github.com/dragginzgame/shared-tooling/issues/110))

## [0.3.8]

- Show the issue tracker's daily cutoff in Paris time, retaining the 06:00 reset and daylight-saving handling. [Detailed notes](docs/changelog/0.3.md).
  ([#109](https://github.com/dragginzgame/shared-tooling/issues/109))

## [0.3.7]

- Fail mandatory portable assertions explicitly on Bash 3.2, so failed checks cannot continue to report success or remove their evidence. [Detailed notes](docs/changelog/0.3.md).
  ([#107](https://github.com/dragginzgame/shared-tooling/issues/107), [#108](https://github.com/dragginzgame/shared-tooling/issues/108))

## [0.3.6]

- Stop pre-commit formatting when a Git index-tree check fails, preserving its error status and leaving working files and staging unchanged even if Git prints the expected tree ID. [Detailed notes](docs/changelog/0.3.md).
  ([#106](https://github.com/dragginzgame/shared-tooling/issues/106), [#103](https://github.com/dragginzgame/shared-tooling/issues/103), [#96](https://github.com/dragginzgame/shared-tooling/issues/96))

## [0.3.5]

- Isolate validation-runner tests from inherited log destinations and GitHub summaries, preventing false test failures and synthetic results leaking into the parent gate's evidence. [Detailed notes](docs/changelog/0.3.md).
  ([#105](https://github.com/dragginzgame/shared-tooling/issues/105))

## [0.3.4]

- Select Binaryen 133 for the common IC toolset and exercise optimization and execution in native CI. [Detailed notes](docs/changelog/0.3.md).
  ([#102](https://github.com/dragginzgame/shared-tooling/issues/102))

## [0.3.3]

- Reject malformed validation nesting depth before dispatch, and require explicit runner completion before returning success. [Detailed notes](docs/changelog/0.3.md).
  ([#104](https://github.com/dragginzgame/shared-tooling/issues/104))

## [0.3.2]

- Require explicit fixture completion before reporting success or deleting test evidence, including Bash 3.2 errors that otherwise return a zero exit status. [Detailed notes](docs/changelog/0.3.md).
  ([#103](https://github.com/dragginzgame/shared-tooling/issues/103), [#99](https://github.com/dragginzgame/shared-tooling/issues/99), [#100](https://github.com/dragginzgame/shared-tooling/issues/100))

## [0.3.1]

- Refuse unsupported platforms and unavailable Rust/Cargo toolchains before common tool setup downloads anything. [Detailed notes](docs/changelog/0.3.md).
  ([#101](https://github.com/dragginzgame/shared-tooling/issues/101))

## [0.3.0]

- **Breaking:** Standardize `install-tools` and `tools-check` on the complete common host, IC and Cargo toolsets. Remove optional host flags and redundant Rust prerequisites; refresh scripts and pins together, with a prepared Rust toolchain. [Detailed notes](docs/changelog/0.3.md).
  ([#98](https://github.com/dragginzgame/shared-tooling/issues/98))

## [0.2.14]

- Report unavailable failed-step logs during CI inspection instead of silently succeeding. [Detailed notes](docs/changelog/0.2.md).
  ([#97](https://github.com/dragginzgame/shared-tooling/issues/97))

## [0.2.13]

- Identify the exact missing or invalid selected Cargo executable in setup/check failures. [Detailed notes](docs/changelog/0.2.md).
  ([#96](https://github.com/dragginzgame/shared-tooling/issues/96))

## [0.2.12]

- Reject line breaks in snapshot directory paths before export or verification can select a different checkout. [Detailed notes](docs/changelog/0.2.md).
  ([#95](https://github.com/dragginzgame/shared-tooling/issues/95))

## [0.2.11]

- Reject unsafe Make modes even when `MAKEFLAGS` is cleared or replaced, before release or formatting recipes run. [Detailed notes](docs/changelog/0.2.md).
  ([#30](https://github.com/dragginzgame/shared-tooling/issues/30))

## [0.2.10]

- Keep formatting output to one success line or a short failure summary with a retained diagnostic log. [Detailed notes](docs/changelog/0.2.md).
  ([#92](https://github.com/dragginzgame/shared-tooling/issues/92), [#94](https://github.com/dragginzgame/shared-tooling/issues/94))

## [0.2.9]

- Show open, merged and closed-without-merge pull requests alongside issue counts in the sibling GitHub dashboard, keeping issue completion percentages separate. [Detailed notes](docs/changelog/0.2.md).
  ([#93](https://github.com/dragginzgame/shared-tooling/issues/93))

## [0.2.8]

- Keep Make admission bound to the selected snapshot when another tooling root is inherited or supplied on the command line. [Detailed notes](docs/changelog/0.2.md).
  ([#30](https://github.com/dragginzgame/shared-tooling/issues/30))

## [0.2.7]

- Reject Make modes that can hide failed release or formatting commands at the shared entrypoints, preserving the existing runner and hook guards. [Detailed notes](docs/changelog/0.2.md).
  ([#30](https://github.com/dragginzgame/shared-tooling/issues/30), [#7](https://github.com/dragginzgame/shared-tooling/issues/7), [#90](https://github.com/dragginzgame/shared-tooling/issues/90))

## [0.2.6]

- Optional shared Make includes for standard release entrypoints and simple Rust formatting, giving repeated recipes one maintained owner while leaving consumer validation and release policy local. [Detailed notes](docs/changelog/0.2.md).
  ([#91](https://github.com/dragginzgame/shared-tooling/issues/91), [#92](https://github.com/dragginzgame/shared-tooling/issues/92), [#85](https://github.com/dragginzgame/shared-tooling/issues/85))

## [0.2.5]

- Preserve existing hook selections whose paths end in newlines, and allow formatting-hook installation and execution in checkouts with trailing-newline directory names. [Detailed notes](docs/changelog/0.2.md).
  ([#89](https://github.com/dragginzgame/shared-tooling/issues/89))

## [0.2.4]

- Check the required helpers when exporting more reusable test suites and the sibling LOC report. [Detailed notes](docs/changelog/0.2.md).
  ([#73](https://github.com/dragginzgame/shared-tooling/issues/73))

## [0.2.3]

- Reject incomplete CI installer test snapshots during export, before changing consumer files. [Detailed notes](docs/changelog/0.2.md).
  ([#73](https://github.com/dragginzgame/shared-tooling/issues/73))

## [0.2.2]

- Publish CI tools to the exact requested executable path, preventing a directory created during setup from redirecting installation or losing existing files. [Detailed notes](docs/changelog/0.2.md).
  ([#88](https://github.com/dragginzgame/shared-tooling/issues/88))

## [0.2.1]

- Install and verify every selected IC tool when its pin matrix has no final newline. [Detailed notes](docs/changelog/0.2.md).
  ([#87](https://github.com/dragginzgame/shared-tooling/issues/87))

## [0.2.0]

- **Breaking:** Transfer PocketIC provisioning and compatibility admission to IC Testkit. Adopt Testkit setup/checks, update snapshot selections and server callers, then reinstall the shared bundle. [Detailed notes](docs/changelog/0.2.md).
  ([#76](https://github.com/dragginzgame/shared-tooling/issues/76))

## [0.1.38]

- Reject exception catalogs containing multiple JSON documents, preventing malformed dependency-pinning exceptions from bypassing required validation. [Detailed notes](docs/changelog/0.1.md).
  ([#86](https://github.com/dragginzgame/shared-tooling/issues/86))

## [0.1.37]

- Pre-commit formatting and its adoption check now find tools prepared in the original checkout without requiring a shell PATH export. [Detailed notes](docs/changelog/0.1.md).
  ([#85](https://github.com/dragginzgame/shared-tooling/issues/85))

## [0.1.36]

- Reject conflicting multi-document Cargo tool receipts during setup and offline checks, recheck installation-directory ancestors after Cargo returns, and preserve Cargo's original failure status alongside retained build evidence. [Detailed notes](docs/changelog/0.1.md).
  ([#65](https://github.com/dragginzgame/shared-tooling/issues/65))

## [0.1.35]

- Clarify that authorized dependency updates include registry access, while release/deployment preparation fetches locked dependencies before offline validation; agents must not impose offline mode on those preparation steps. [Detailed notes](docs/changelog/0.1.md).
  ([#84](https://github.com/dragginzgame/shared-tooling/issues/84), [#65](https://github.com/dragginzgame/shared-tooling/issues/65))

## [0.1.34]

- Include locked dependency-cache preparation before compiled release adapters, preserving explicit offline settings and interrupted metadata recovery. [Detailed notes](docs/changelog/0.1.md).
  ([#84](https://github.com/dragginzgame/shared-tooling/issues/84), [#82](https://github.com/dragginzgame/shared-tooling/issues/82), [#81](https://github.com/dragginzgame/shared-tooling/issues/81))

## [0.1.33]

- Make the sibling issue dashboard easier to scan with repository names first, repositories ranked by remaining issues, dashed separators and comma-separated counts padded with spaces to six characters, followed by the percentage in parentheses for closed/total counts. [Detailed notes](docs/changelog/0.1.md).
  ([#83](https://github.com/dragginzgame/shared-tooling/issues/83))

## [0.1.32]

- Preserve running and queued native CI for each pushed commit while allowing newer PR revisions to replace older review runs. [Detailed notes](docs/changelog/0.1.md).
  ([#80](https://github.com/dragginzgame/shared-tooling/issues/80), [#65](https://github.com/dragginzgame/shared-tooling/issues/65), [#76](https://github.com/dragginzgame/shared-tooling/issues/76))

## [0.1.31]

- Remove short job/step limits from Cargo-install qualification and portable regression so long builds can finish within GitHub Actions' default limits. [Detailed notes](docs/changelog/0.1.md).
  ([#78](https://github.com/dragginzgame/shared-tooling/issues/78), [#79](https://github.com/dragginzgame/shared-tooling/issues/79))

## [0.1.30]

- Add repeatable native Cargo binary/example installation qualification, including offline reuse, concurrency and preservation after compiler failure. [Detailed notes](docs/changelog/0.1.md).
  ([#65](https://github.com/dragginzgame/shared-tooling/issues/65))

## [0.1.29]

- Add a live terminal issue dashboard for connected sibling repositories, with total, open and closed counts, percent fixed, combined totals and visible observation failures. [Detailed notes](docs/changelog/0.1.md).
  ([#77](https://github.com/dragginzgame/shared-tooling/issues/77), [#74](https://github.com/dragginzgame/shared-tooling/issues/74), [#76](https://github.com/dragginzgame/shared-tooling/issues/76))

## [0.1.28]

- Add a readable maintenance task catalog and an opt-in local agent schedule for three-day dependency, MSRV, Rust freshness, CI and snapshot checks, with rotating audits, retained reports and owning-repository issue follow-up. [Detailed notes](docs/changelog/0.1.md).
  ([#75](https://github.com/dragginzgame/shared-tooling/issues/75), [#70](https://github.com/dragginzgame/shared-tooling/issues/70), [#71](https://github.com/dragginzgame/shared-tooling/issues/71), [#73](https://github.com/dragginzgame/shared-tooling/issues/73), [#60](https://github.com/dragginzgame/shared-tooling/issues/60))

## [0.1.27]

- Resolve script entry paths independently of inherited directory search, and preserve physical path bytes while locating helpers. [Detailed notes](docs/changelog/0.1.md).
  ([#67](https://github.com/dragginzgame/shared-tooling/issues/67), [#66](https://github.com/dragginzgame/shared-tooling/issues/66), [#7](https://github.com/dragginzgame/shared-tooling/issues/7), [#68](https://github.com/dragginzgame/shared-tooling/issues/68), [#69](https://github.com/dragginzgame/shared-tooling/issues/69))

## [0.1.26]

- Allow an unchanged, verified snapshot to refresh again before a consumer commit, while refusing edited files, staged conflicts and changes made during preparation. [Detailed notes](docs/changelog/0.1.md).
  ([#64](https://github.com/dragginzgame/shared-tooling/issues/64))

## [0.1.25]

- Preserve literal evidence roots and output names, including trailing newlines; refuse occupied special-file outputs and symlink-parent traversal. [Detailed notes](docs/changelog/0.1.md).
  ([#59](https://github.com/dragginzgame/shared-tooling/issues/59), [#62](https://github.com/dragginzgame/shared-tooling/issues/62))

## [0.1.24]

- Share evidence archiving across CI collectors, preserving unusual Unix filenames, modes and symlinks through a single archive upload. [Detailed notes](docs/changelog/0.1.md).
  ([#59](https://github.com/dragginzgame/shared-tooling/issues/59), [#60](https://github.com/dragginzgame/shared-tooling/issues/60), [#62](https://github.com/dragginzgame/shared-tooling/issues/62), [#61](https://github.com/dragginzgame/shared-tooling/issues/61))

## [0.1.23]

- Keep PR release lookup working with packaged GitHub CLI versions that lack `--slurp`, while rejecting incomplete responses and conflicting PRs across pages. [Detailed notes](docs/changelog/0.1.md).
  ([#42](https://github.com/dragginzgame/shared-tooling/issues/42), [#58](https://github.com/dragginzgame/shared-tooling/issues/58))

## [0.1.22]

- Prevent false sibling LOC test failures when temporary paths have trailing slashes or directory aliases, preserving report and failure-retention checks. [Detailed notes](docs/changelog/0.1.md).
  ([#57](https://github.com/dragginzgame/shared-tooling/issues/57), [#42](https://github.com/dragginzgame/shared-tooling/issues/42))

## [0.1.21]

- Support explicitly selected PR-gated releases: prepare one release PR, resume after merge/squash/rebase, and fully validate the exact merged commit before publishing its tag. [Detailed notes](docs/changelog/0.1.md).
  ([#42](https://github.com/dragginzgame/shared-tooling/issues/42))

## [0.1.20]

- Allow agents to complete explicitly requested PRs, including scoped commits and branch pushes. [Detailed notes](docs/changelog/0.1.md).
  ([Toko #1789](https://github.com/dragginzgame/toko/issues/1789), [#43](https://github.com/dragginzgame/shared-tooling/issues/43), [#29](https://github.com/dragginzgame/shared-tooling/issues/29))

## [0.1.19]

- Retain a complete combined log for each failed validation batch, plus a latest combined view, while preserving raw per-target logs and failure status. [Detailed notes](docs/changelog/0.1.md).
  ([#37](https://github.com/dragginzgame/shared-tooling/issues/37), [#45](https://github.com/dragginzgame/shared-tooling/issues/45), [#46](https://github.com/dragginzgame/shared-tooling/issues/46), [#54](https://github.com/dragginzgame/shared-tooling/issues/54), [#56](https://github.com/dragginzgame/shared-tooling/issues/56), [#55](https://github.com/dragginzgame/shared-tooling/issues/55))

## [0.1.18]

- Isolate LOC fixtures from enclosing Cargo workspaces and target settings, and allow tooling-report tests before committing consumer adoption. [Detailed notes](docs/changelog/0.1.md).
  ([#47](https://github.com/dragginzgame/shared-tooling/issues/47), [#50](https://github.com/dragginzgame/shared-tooling/issues/50), [#53](https://github.com/dragginzgame/shared-tooling/issues/53), [#30](https://github.com/dragginzgame/shared-tooling/issues/30), [#49](https://github.com/dragginzgame/shared-tooling/issues/49), [#31](https://github.com/dragginzgame/shared-tooling/issues/31), [#51](https://github.com/dragginzgame/shared-tooling/issues/51), [#52](https://github.com/dragginzgame/shared-tooling/issues/52))

## [0.1.17]

- Keep LOC fixtures on their own Cargo manifests when temporary files live inside a consumer checkout, and isolate inherited target-directory settings. [Detailed notes](docs/changelog/0.1.md).
  ([#48](https://github.com/dragginzgame/shared-tooling/issues/48), [#47](https://github.com/dragginzgame/shared-tooling/issues/47))

## [0.1.16]

- Select an independent Cargo workspace with `make cloc CLOC_MANIFEST=testing/Cargo.toml`; reports use that workspace's configuration and exclude its generated output. [Detailed notes](docs/changelog/0.1.md).
  ([#41](https://github.com/dragginzgame/shared-tooling/issues/41), [#31](https://github.com/dragginzgame/shared-tooling/issues/31), [#37](https://github.com/dragginzgame/shared-tooling/issues/37), [#43](https://github.com/dragginzgame/shared-tooling/issues/43), [#38](https://github.com/dragginzgame/shared-tooling/issues/38), [#32](https://github.com/dragginzgame/shared-tooling/issues/32), [#39](https://github.com/dragginzgame/shared-tooling/issues/39), [#44](https://github.com/dragginzgame/shared-tooling/issues/44), [#40](https://github.com/dragginzgame/shared-tooling/issues/40), [#33](https://github.com/dragginzgame/shared-tooling/issues/33))

## [0.1.15]

- Inventory sibling CI and tooling with `make cloc-tooling`, separating local code from checksum-matching shared snapshots and supporting data. [Detailed notes](docs/changelog/0.1.md).
  ([#34](https://github.com/dragginzgame/shared-tooling/issues/34), [IcyDB #310](https://github.com/dragginzgame/icydb/issues/310))

## [0.1.14]

- Reject inherited Make modes that ignore failures or skip execution before release, validation and pre-commit formatting. [Detailed notes](docs/changelog/0.1.md).
  ([#30](https://github.com/dragginzgame/shared-tooling/issues/30), [#31](https://github.com/dragginzgame/shared-tooling/issues/31), [#36](https://github.com/dragginzgame/shared-tooling/issues/36), [#34](https://github.com/dragginzgame/shared-tooling/issues/34), [#35](https://github.com/dragginzgame/shared-tooling/issues/35))

## [0.1.12]

- Inspect GitHub Actions runs for an exact local commit across workflows, with explicit listing limits and clearly labelled historical failure searches. [Detailed notes](docs/changelog/0.1.md).
  ([#25](https://github.com/dragginzgame/shared-tooling/issues/25), [#26](https://github.com/dragginzgame/shared-tooling/issues/26), [#27](https://github.com/dragginzgame/shared-tooling/issues/27), [#28](https://github.com/dragginzgame/shared-tooling/issues/28), [#29](https://github.com/dragginzgame/shared-tooling/issues/29))

## [0.1.11]

- Apply authorized local fixes directly and report findings to their owning repositories under standing issue-reporting authorization. [Detailed notes](docs/changelog/0.1.md).
  ([#24](https://github.com/dragginzgame/shared-tooling/issues/24), [#23](https://github.com/dragginzgame/shared-tooling/issues/23), [#22](https://github.com/dragginzgame/shared-tooling/issues/22), [#21](https://github.com/dragginzgame/shared-tooling/issues/21))

## [0.1.10]

- Add a checksum-verified sccache CI installer for Linux x86-64, retaining failed candidates and preserving the installed executable on rejection. [Detailed notes](docs/changelog/0.1.md).
  ([#20](https://github.com/dragginzgame/shared-tooling/issues/20), [#21](https://github.com/dragginzgame/shared-tooling/issues/21), [#11](https://github.com/dragginzgame/shared-tooling/issues/11))

## [0.1.9]

- Share offline formatter prerequisite checks so consumers use their reviewed cargo-sort pin and prepared rustfmt consistently, without implicit installs. [Detailed notes](docs/changelog/0.1.md).
  ([#19](https://github.com/dragginzgame/shared-tooling/issues/19), [#17](https://github.com/dragginzgame/shared-tooling/issues/17))

## [0.1.8] - 2026-10-06

- Add opt-in Cargo workspace inheritance checks and a shared read-only workspace version reader, covering ordinary dependency tables and valid TOML comments. [Detailed notes](docs/changelog/0.1.md).
  ([#18](https://github.com/dragginzgame/shared-tooling/issues/18), [#16](https://github.com/dragginzgame/shared-tooling/issues/16))

## [0.1.7]

- Add explicit-cutoff tag maintenance with a read-only preview, identity-checked deletion and saved selection for interrupted retries. [Detailed notes](docs/changelog/0.1.md).
  ([#11](https://github.com/dragginzgame/shared-tooling/issues/11), [#15](https://github.com/dragginzgame/shared-tooling/issues/15), [#16](https://github.com/dragginzgame/shared-tooling/issues/16), [#17](https://github.com/dragginzgame/shared-tooling/issues/17), [#12](https://github.com/dragginzgame/shared-tooling/issues/12), [#13](https://github.com/dragginzgame/shared-tooling/issues/13), [#8](https://github.com/dragginzgame/shared-tooling/issues/8), [#9](https://github.com/dragginzgame/shared-tooling/issues/9), [#10](https://github.com/dragginzgame/shared-tooling/issues/10), [#14](https://github.com/dragginzgame/shared-tooling/issues/14))

## [0.1.6]

- Common `install-tools` and offline `tools-check` targets include pinned local jq and Mike Farah yq, with Linux Mint/macOS bootstrap instructions and matching local/CI parser selection. [Detailed notes](docs/changelog/0.1.md).

## [0.1.5] - 2026-10-06

- Shared dependency-pinning rules and an offline CI checker for immutable Git and Action references, Cargo version constraints, tracked workspace lockfiles and explicit exceptions for sibling or moving inputs. [Detailed notes](docs/changelog/0.1.md).
  ([#6](https://github.com/dragginzgame/shared-tooling/issues/6), [#7](https://github.com/dragginzgame/shared-tooling/issues/7))

## [0.1.4] - 2026-10-06

- Reject unrelated staged release content even when working files match HEAD, and verify that the index contains the prepared release metadata before commit. [Detailed notes](docs/changelog/0.1.md).

## [0.1.3] - 2026-10-06

- User-triggered agent commands for checking current CI, reviewing GitHub issues and recommending work after a task finishes. [Detailed notes](docs/changelog/0.1.md).
  ([#1](https://github.com/dragginzgame/shared-tooling/issues/1), [#5](https://github.com/dragginzgame/shared-tooling/issues/5))

## [0.1.2] - 2026-10-05

- Standard Rust pre-commit formatting and safe repository-local installation. [Detailed notes](docs/changelog/0.1.md).

## [0.1.1] - 2026-10-05

- Common release contract and Makefile example requiring `release-patch`, `release-minor` and `release-major` in every repository. [Detailed notes](docs/changelog/0.1.md).

## [0.1.0] - 2026-10-05

- Initial shared engineering baseline, development commands, CI helpers and reviewed snapshots. [Detailed notes](docs/changelog/0.1.md).
