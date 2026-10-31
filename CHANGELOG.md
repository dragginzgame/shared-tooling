# Changelog

## [0.27.13]

### 🩹 Fixed

- Admit registry Principal conversions in Platform’s canonical `ic-platform-types`
  owner. Keep every other external IC dependency restricted to the facade and
  preserve stricter consumer policies.
- Exclude two exact historical generated Mermaid node fingerprints from secret
  scanning; retain detection for other files, commits and candidate credentials.

### ➕ Added

- Support explicitly approved Cargo release groups through the existing metadata
  transaction and release runner. Preserve other groups' public versions and
  external lock selections, retain full graph qualification, bind receipts/resume
  and tags to the group, and admit group-owned versions in inheritance checks
  ([#328](https://github.com/dragginzgame/shared-tooling/issues/328)).

## [0.27.12]

### 🥾 Governance

- Keep reusable cores independently upgradable. Adapters own matching integration
  stacks; isolate demonstrated integration blockers without dropping core or
  composition qualification, changing public versioning or weakening runtime guards.

### 🩹 Fixed

- Refresh the stack graph for the combined Scheduling workspace and retire the
  separate Call package entry. Preserve package-level dependency evidence and
  distinguish the declaration map from workspace adoption prerequisites.

### ➕ Added

- Carry explicit manifest/target paths, feature selections and check-only dirty
  admission through the publication Make adapter without evaluating argument text.
  Preserve path admission, source checks and retained attempts
  ([#326 — Support explicit Cargo options in the opt-in publication adapter](https://github.com/dragginzgame/shared-tooling/issues/326)).

### 🧪 Testing

- Prepare documentation alongside script companions in snapshot fixtures so
  publication adapters remain exportable through their committed closure.

## [0.27.11]

### 🥾 Governance

- Prohibit Rust `#[path]` module wiring, including conditional overrides and
  generated code. Require ordinary module layouts or a shared library owner
  across production code, tests, examples and benchmarks.
- Prefer scoped Rust lint expectations over allowances. Require repositories to
  review every `allow` for conversion, explain retained exceptions, and keep
  unfulfilled expectations visible.

## [0.27.10]

### ➕ Added

- Add an opt-in publication Make adapter over the retained Cargo attempt runner.
  Consumers declare their package roster, registry and validation targets; shared
  mechanics select exact workspace versions for default or `PACKAGE=` requests.

## [0.27.9]

### 🧹 Cleanup

- Let Cargo graph policies export rendered source/version identities and effective
  feature unions from one locked offline observation. Keep existing output and
  policy behavior unless `--json --observations` is selected.
- Keep validation input checkpointing in a declared companion captured with the
  runner, preserving input-drift refusal even when a gate replaces source files.
- Share coordinated Cargo workspace admission across preparation and checks,
  retaining independent observations, original-lock admission and complete
  Cargo/logger failure evidence at each boundary.

### 🥾 Governance

- Prefer existing Host owners and safe standard-library/Rustix interfaces for
  native operations, retaining documented raw-FFI exceptions and native-host
  qualification without requiring Rustix in unrelated or Wasm packages.

### 🧪 Testing

- Qualify release tracking against Git's observed post-push ref, including Git
  versions that refresh it during a URL push. Continue to require the runner to
  leave that ref alone when no matching upstream is configured.

## [0.27.8]

### 🥾 Governance

- Make the [Clap contract](rules/engineering-details.md#cli-applications) explicit
  across Rust CLIs, generators, benchmarks and maintained examples. Use its typed
  values, argument relationships, command composition, help and diagnostics;
  remove duplicate CLI mechanics while preserving domain and runtime validation.
- Document the [canonical observability owners](rules/engineering-details.md#metrics-and-logging):
  use `ic-metrics` and `ic-logging`, and resolve capability gaps in IC Observability.
  Keep application policy and governed persistence integration with their owners.

### 📊 Audit

- Audit sibling codecs and imports for IC Wire reuse, filing or extending owning
  issues for codec migrations and byte-buffer reuse. Retain external-protocol,
  signing and ordered-storage boundaries; the migrations remain follow-up work.
- Audit sibling Clap usage and record owning issues for command composition,
  typed argument values and handwritten example, generator and benchmark parsers.
  These findings identify follow-up work rather than completed CLI migrations.

### 📚 Documentation

- Refresh the stack diagrams and manifest evidence for stable metrics/logging
  integration, Canic's current package layout and updated sibling dependencies.

## [0.27.7]

### 🩹 Fixed

- Keep the README stack diagram compact by grouping application packages and
  showing main library crates, with Memory and Storage separate. Retain the full
  package graph in an expandable detailed view alongside direct manifest evidence.
- Refresh the stack catalog for IC Observability and Canic's current package
  layout so the daily refresh follows the existing checkouts.
- Grey out sibling dashboard rows with no open issues or PRs, and rank by open
  issues, then open PRs, highest first.

## [0.27.6]

### 🩹 Fixed

- Keep single-tool freshness checks independent of unrelated Cargo installations,
  while preserving refusal for unsupported selected identities and invalid receipts.
- Correct release help to distinguish fresh releases from explicit saved-attempt
  recovery with `release-resume VERSION=X.Y.Z`.

## [0.27.5]

### 🩹 Fixed

- Admit maintenance permissions with a no-model sandbox preflight before recording
  dispatch. Reuse the same settings for execution, carry one completed prior
  report, and scope scheduled work to the checks its offline permissions support.

### ♻️ Changed

- Run one documentation-only CI job while retaining all native hosts for code
  changes. Build real-helper test fixtures from their declared dependency roots.
- Select failed-target excerpts once for retained reports and replay them only
  in the outer runner's final console summary, preserving complete raw logs.

## [0.27.4]

### 🩹 Fixed

- Serialize maintenance filesystem permissions as one table so Codex admits
  literal paths containing dots and slashes. Qualify the report-only runner
  through the installed host environment before unattended execution
  ([#320](https://github.com/dragginzgame/shared-tooling/issues/320)).

## [0.27.3]

### 🔒 Security

- Make unattended maintenance report-only, with explicit source-read/evidence-write
  permissions, no network or connected apps, no approval escalation and a cleared
  launch environment. Requalify the installed host configuration before resuming
  scheduled runs ([#320](https://github.com/dragginzgame/shared-tooling/issues/320)).

### ➕ Added

- Compare snapshot payloads against an independently reviewed source commit at
  adoption, while retaining offline local integrity checks for ordinary builds
  ([#321](https://github.com/dragginzgame/shared-tooling/issues/321)).
- Supply optional sccache 0.19.0 through the existing catalog and installer, with
  maintenance-only freshness inspection and explicit compatibility exceptions
  ([#319](https://github.com/dragginzgame/shared-tooling/issues/319)).
  
### 🩹 Fixed

- Build consumer formatting-hook fixtures from explicit roots and their declared
  companion closure, including new unstaged helpers, instead of requiring each
  consumer to repeat the transitive file list. Preserve opaque Git submodules
  and newline-bearing consumer paths while retaining relative-path admission.

## [0.27.2]

### 📚 Documentation

- Clarify native/system bootstrap before Cargo-tool preparation, including the
  release editor, and explicit re-preparation after build-environment changes.
  Document complete release-prerequisite coverage and consumer ordering fixtures
  without changing installer ownership or receipt admission
  ([#317 — Document native bootstrap ordering before Cargo tool preparation](https://github.com/dragginzgame/shared-tooling/issues/317)).

## [0.27.1]

### 🥾 Governance

- Require one remediation issue at the supplying owner for shared dependency
  defects and advisories, including crypto/Agent findings at IC Platform.
  Retain consumer evidence there; separate consumer issues need distinct
  actionable work. Keep security gates and scoped risk decisions intact
  ([#50 — Resolve RUSTSEC-2026-0387 at the IC Platform crypto/Agent boundary](https://github.com/dragginzgame/ic-platform/issues/50)).

## [0.27.0]

### ➕ Added

- Maintain a Toko stack dependency diagram in the README, with an offline
  regeneration/check command and linked workspace and manifest evidence.
  Distinguish declared dependencies from resolved builds and runtime deployment.
- Add an opt-in daily local refresh that keeps the generated diagram and
  dependency evidence current, leaving changes for the next normal commit.
  No automatic staging, commits, dependency downloads or GitHub credentials.

### 📚 Documentation

- Shorten the README to orientation, ownership and supported entry points.
  Consolidate fleet-report and validation-runner references in dedicated guides,
  correcting the dashboard description and linking canonical setup and formatting
  instructions instead of repeating stale examples.

## [0.26.26]

### 🩹 Fixed

- Keep formatting reuse enabled for ordinary conditional attributes followed by
  unrelated path text. Inspect balanced Rust attributes through the shared lexer,
  retaining uncached execution for actual module overrides or incomplete syntax
  ([#315](https://github.com/dragginzgame/shared-tooling/issues/315)).

## [0.26.25]

### 🩹 Fixed

- Qualify non-UTF8 scanner arguments without requiring the host filesystem to
  create invalid-UTF8 filenames. Preserve successful scans where those names are
  supported and source-IO diagnostics where they are rejected, fixing native
  macOS qualification ([#310](https://github.com/dragginzgame/shared-tooling/issues/310)).

## [0.26.24]

### 🩹 Fixed

- Allow formatting commits in repositories with tracked submodules. Keep each
  child checkout opaque, preserve staged gitlink identities, and format only
  selected regular files without reading or changing child contents.
- Include the Node prerequisite guide in governance exports and declare its
  documentation dependency without enabling Node setup
  ([#311](https://github.com/dragginzgame/shared-tooling/issues/311)).
- Keep CI-inspection fixtures concise on success and replay their last observation
  and command trace on failure, retaining exact status and fixture evidence
  ([#313](https://github.com/dragginzgame/shared-tooling/issues/313)).

### ➕ Added

- Format explicitly selected standalone Rust files with a declared edition and
  visible pass timing. Keep these selections uncached so module/configuration
  inputs cannot be skipped by an incomplete proof
  ([#314](https://github.com/dragginzgame/shared-tooling/issues/314)).
- Use Clap for runtime-scanner help and argument handling while preserving
  source diagnostics, non-UTF8 paths and exit-status contracts. Consumers compiling
  the source must add Clap to their private compiler package
  ([#310](https://github.com/dragginzgame/shared-tooling/issues/310)).

## [0.26.23]

### ➕ Added

- Own Rust formatting orchestration for extra workspaces, optional derive sorting
  and manifest order through declarative consumer inputs, replacing copied
  workspace adapters while preserving custom formatter commands.

### 🔧 Changed

- Show progress and elapsed time for each Rust formatting pass. Reuse successful
  results only for unchanged inputs, with prepared tools still checked; retain
  failed logs and provide an explicit option to run every pass.

### 📊 Audit

- Trace unreadable Canic release output to expected-error assertions in Shared's
  generic CI-inspection tests. **Pending cleanup:** give those tests concise
  success summaries with detailed failure evidence
  ([#313](https://github.com/dragginzgame/shared-tooling/issues/313)).
- Track removal of unnecessary generic CI-inspection tests from routine
  [Canic](https://github.com/dragginzgame/canic/issues/461) and
  [IcyDB](https://github.com/dragginzgame/icydb/issues/474) gates separately,
  retaining snapshot integrity and consumer integration checks.

### 🥾 Governance

- Make IC Tooling's bounded artifact encoder the gzip owner for production and
  fixtures. Prefer fast compression for ordinary fixtures and production settings
  for byte-contract tests. Keep compression policy with consumers, independent
  interoperability controls explicit, and retained compressed-byte hashes qualified
  across backend changes; no Platform migration is required.

### 🧭 Migration Notes

- Consumers with paired formatter overrides must explicitly migrate their local
  inputs and caller fixtures; a snapshot refresh alone preserves the overrides.
  Follow-through is tracked for
  [Canic](https://github.com/dragginzgame/canic/issues/455) and
  [IcyDB](https://github.com/dragginzgame/icydb/issues/473).
- Preserve complete standalone-source adapters in Platform and Persistence;
  shared support for those extra Rustfmt passes remains
  [follow-up work](https://github.com/dragginzgame/shared-tooling/issues/314).

## [0.26.22]

### 🥾 Governance

- Make the owned-type `CandidType` prohibition explicit. Prefer IC Wire for
  application payloads; isolate unavoidable Candid projections at named external
  protocol or retained-data boundaries, including in tests and generators.
- Require the existing `thiserror` dependency for mechanical native error
  implementations while preserving messages, conversions, source identity and
  meaningful recovery projections.
- Strengthen coding rules and audit checkpoints for complete source inspections,
  strict machine-output decoding, bounded subprocess capture and safe terminal
  diagnostics. Require focused negative regression cases in the owning normal
  test/CI path; adopting the rules alone does not install executable enforcement.

## [0.26.21]

### 🔧 Changed

- Use IcyDB-style emoji sections for latest/current and future root release
  notes. Include only relevant categories, with one `📝 Summary` section for
  small entries; preserve older history, release identities and dates.

## [0.26.20]

### ➕ Added

- Offer an opt-in npm SDK boundary check for direct SDK declarations, aliases
  and literal imports, supporting adoption of `@tokostudios/ic-platform` without
  requiring npm in Rust-only repositories.

### 🔧 Changed

- Reduce routine agent overhead with a compact baseline, task-specific detailed
  rules, batched focused validation and opt-in change accounting.
- Use documentation-only CI for reviewed root documentation and developer guides;
  unknown paths, executable inputs and policy changes retain full qualification.
- Make the separate `@tokostudios/ic-platform` npm package explicit in the
  JavaScript/TypeScript SDK boundary rules, with independent Rust/npm release
  identities and consumer-owned provider qualification.

### 🩹 Fixed

- Reject optional and peer dependency drift between npm manifests and lock roots
  during Node prerequisite checks.

## [0.26.19]

### Fixed

- Preserve archived Draft labels inside historical changelog sections without
  blocking a new release. Current draft and candidate conflicts still refuse.

## [0.26.18]

### Fixed

- Start normal release commands fresh from current committed metadata without
  scanning historical plans or replaying old release effects. Use
  `release-resume VERSION=X.Y.Z` for explicit recovery; current source, lock,
  candidate-ref and destination checks still apply
  ([#309 — Fresh normal releases without historical-plan blockers](https://github.com/dragginzgame/shared-tooling/issues/309)).

## [0.26.17]

### Fixed

- Explain rejected assertion selections and initialization layouts in retention
  probes, clearing stale or partial generated scripts before refusing execution.
- Diagnose unsupported fixture-retention EXIT trap layouts and leave no partial
  generated probe when the required boundary is missing. Document the supported
  one-line trap convention
  ([#308 — Diagnose unsupported EXIT-trap shapes in fixture_probe_prefix](https://github.com/dragginzgame/shared-tooling/issues/308)).

### Changed

- Treat edits confined to the reviewed RPC-budget guide as documentation-only
  CI changes. Snapshot catalogs, release versions and executable changes still
  require full qualification.

## [0.26.16]

### Added

- Require one product owner for generated RPC budgets, with a qualification
  recipe for browser/server policy drift, intentional asymmetry and runtime
  boundary behavior. Numeric defaults and consumer qualification remain local
  ([#307 — Require one policy owner and boundary qualification for browser RPC budgets](https://github.com/dragginzgame/shared-tooling/issues/307)).

## [0.26.15]

### Changed

- Preserve established workspace groupings and coordinated versions. Prefer
  batching related breaking changes over repeated downstream migrations, and
  classify dependency upgrades by their actual impact on each consumer's public
  contract.
- Clarify dependency-adoption checks: verify the selected consumer graphs and
  important type identities without treating temporary migration states or
  whole-lockfile duplicates as defects.

## [0.26.14]

### Fixed

- Distinguish admitted Cargo-tool contention from missing installation with exit
  status 75. Allow explicit bounded read-only admission waits during release
  recovery, rechecking selection and inputs without installation or lock cleanup
  ([#306 — Busy tool admission during release recovery](https://github.com/dragginzgame/shared-tooling/issues/306)).

## [0.26.13]

### Fixed

- Allow a normal release to advance from clean, manually committed candidate
  metadata despite missing earlier tags or incomplete Git delivery. Preserve the
  earlier plan without claiming completion, validate the next version afresh,
  and retain conflicting-source/ref refusals ([#305 — Make committed-preparation recovery actionable when the release tag is missing](https://github.com/dragginzgame/shared-tooling/issues/305)).

## [0.26.12]

### Fixed

- Fetch complete history for the portable CI matrix so snapshot-impact
  qualification can inspect the previous committed source on every host.
- Align the recorded snapshot source version with the delivered 0.26.11
  implementation ([#304 — Reconcile committed VERSION with the delivered 0.26.11 snapshot source](https://github.com/dragginzgame/shared-tooling/issues/304)).

## [0.26.11]

### Added

- Report Cargo-tool setup phases, durations and outcomes on stderr while
  preserving path-only stdout, offline checks, build identities and failure
  evidence ([#303 — Report Cargo tool setup phases and durations](https://github.com/dragginzgame/shared-tooling/issues/303)).

## [0.26.10]

### Added

- Opt-in common external IC dependency guards, composed with stricter local
  ownership rules; existing consumers select adoption explicitly.
- Optional exact Cargo-tool caching in common CI setup, plus aggregate offline
  tool diagnostics and read-only installer selection reports.
- Snapshot upgrade impact previews and structured dependency-graph failures with
  representative introducing paths, preserving consumer selection policy.
- Reusable parallel-Make lint-order qualification for consumer release and
  deployment pipelines, using substituted effects.

### Fixed

- Formatting now reads the same literal tool catalog as installation and caching,
  refusing duplicate assignments and executable configuration.
- Keep the remaining standalone CI fixture bootstraps independent of inherited
  `CDPATH` and invocation style. Preserve physical checkout paths before loading
  helpers, including spaces and trailing newlines in isolated path fixtures.
- Reuse shared allocation in the allocation, jobserver, dependency-boundary,
  publication-attempt, Rust-tool and release-receipt fixtures. Keep scratch paths and cleanup
  anchored to the caller rather than a `CDPATH` lookup.
- Direct current Build, Host and Testkit contributions to their consolidated
  IC Tooling workspace while preserving historical qualification references.
- Ignore the retired checkout-local build directory during Cargo-tool setup and
  checks, preserving old evidence and all current shared-store path checks.

### Changed

- Reuse fixture lifecycle and companion-copy helpers, remove duplicate IC receipt
  membership checks and evidence-test cases, and select the compact-evidence CI
  step by its stable ID through the existing workflow extractor.

## [0.26.9]

### Fixed

- Keep Cargo graph and changelog fixtures working with inherited `CDPATH` and
  relative entrypoints. Anchor Cargo failure-fixture preparation to its physical
  destination, preserving spaces and refusing empty or CR/LF paths.

## [0.26.8] - Unreleased

### Fixed

- Keep explicit Cargo setup waiting through an admitted owner's lock cleanup.
  A disappearing directory is rechecked before atomic acquisition; a missing
  record is tolerated only for the same previously admitted physical lock.
  Invalid claims, timeouts and atomic acquisition failures still refuse.
  This fixes the Intel macOS contention regression in 0.26.7 ([#301](https://github.com/dragginzgame/shared-tooling/issues/301)).

### Changed

- Initialize the Cargo source cache without a global installation lock. Concurrent
  creators use idempotent private directory creation with existing path admission;
  Cargo continues to own downloads and selected-tool slots still serialize builds.
  After adopting this build-policy change, rerun explicit Cargo-tool setup once.
  Previous generations and old source-preparation slots remain retained.

## [0.26.7]

### Fixed

- Let explicit Cargo-tool setup wait briefly for an admitted shared-slot owner,
  then recheck inputs and reuse its verified result. Keep offline checks
  immediate and never remove another owner's lock. Setup waits up to 60 seconds
  per occupied slot; set `SHARED_TOOLING_SETUP_WAIT_SECONDS=0` for immediate refusal
  ([#301 — Bound cross-checkout tool setup contention](https://github.com/dragginzgame/shared-tooling/issues/301)).

## [0.26.6]

### Changed

- Clarify asynchronous merge guidance when agent-runtime approval blocks an
  otherwise authorized action. Keep GitHub requirements and runtime restrictions
  distinct, with one canonical policy for reporting and handling the blocker
  ([#300 — Clarify runtime approval boundaries](https://github.com/dragginzgame/shared-tooling/issues/300)).

### Fixed

- Reuse shared temporary-directory allocation in native-host, formatter-evidence
  and tool-version fixtures, preserving evidence and cleanup with relative or
  aliased scratch directories and inherited `CDPATH`.
- Include the required tag-maintenance helper when copying fixture companions,
  so isolated checks do not depend on files outside their selected bundle.
- Derive validation-runner child bundles from declared script roots instead of
  repeated helper lists, and include verification helpers in isolated fixtures.

## [0.26.5]

### Added

- Share CI/release trust and artifact review guidance, and focused boundary-handoff
  proof within flow audits. Keep product invariants and historical evidence local.

### Fixed

- Resolve retained validation logs from the caller's directory, independently of
  inherited `CDPATH`, and support relative log directories with a leading dash.
- Keep digest fixtures working with relative or aliased temporary directories,
  reusing shared allocation and cleanup to preserve failure evidence paths.

## [0.26.4]

### Fixed

- Preserve independent parent errors alongside nested validation diagnostics in
  highlighted logs and GitHub summaries, without adding duplicate annotations.
- Limit failure excerpts before capturing them in shell memory, preserving full
  raw logs while avoiding excessive memory use for large diagnostic output.
- Publish latest failure logs atomically without following symlinks or copying
  into directories; report unique retained evidence when a latest update fails.
- Preserve target failure statuses through GitHub summary and temporary-cleanup
  errors; retain complete local summaries and evidence when publication fails.
- Reject NUL-bearing checksum-tool output before shell capture can discard bytes,
  preserving backend failure handling in digest generation and verification.
- Preserve existing diagnostic checksum files and symlink targets, including
  checksum destinations introduced while the archive is being created.
- Require one artifact metadata document before downloading retained evidence;
  reject concatenated responses without requesting the ZIP.

## [0.26.3]

### Fixed

- Accept Cargo's command-line feature annotations when selected dependency roots
  overlap, preserving package identity counts and forbidden-feature checks
  ([#299 — Cargo graph feature checks reject command-line root annotations](https://github.com/dragginzgame/shared-tooling/issues/299)).

## [0.26.2]

### Fixed

- Enable Testkit's required `cli` feature in lockfile-selected server setup and
  offline-check examples; keep `cli` out of library-only dependencies
  ([#297 — Add required cli feature to lockfile-selected Testkit setup example](https://github.com/dragginzgame/shared-tooling/issues/297)).
- Accept padded BSD `wc` output in IC fixture download-count assertions and
  exercise that padding on Linux as well.

## [0.26.1]

### Added

- Document focused dependency-adoption checks across independent consumer graphs,
  reusing existing checks while keeping package, identity and artifact policy local
  ([#295 — Provide a focused dependency-adoption check contract](https://github.com/dragginzgame/shared-tooling/issues/295)).

### Fixed

- Include selected IC-tool preflight in release-editor setup and recovery
  fixture expectations
  ([#296 — Update release-editor setup fixture for selected IC preflight](https://github.com/dragginzgame/shared-tooling/issues/296)).
- Keep IC tool-selection arguments to awk on one line so macOS can prepare
  multiple selected tools; preserve canonical selections and store identities
  ([#294 — Make multi-tool IC selection portable to macOS awk](https://github.com/dragginzgame/shared-tooling/issues/294)).

## [0.26.0]

### Breaking

- Require explicit IC executable selections: set `IC_TOOLS` for Make callers
  or pass repeated `--tool NAME` arguments to the installer. Only requested tools
  are downloaded and admitted; subset identities, offline checks and retained
  receipts use the same selection. Prepare tools explicitly after adoption;
  prior bundles and failed candidates remain retained.
- Pass the IC tool selection to compact evidence collection. The failure action
  accepts `ic-tools`; omitted or mismatched selections retain full IC payloads.
  Direct compact-selector and compact-collector callers must supply the new list
  argument; full-retention calls keep their existing interface.
  IC version reports likewise require an explicit list and probe only selected tools.

## [0.25.9]

### Fixed

- Use the source checkout's declared compiler in native cross-checkout tool
  reuse qualification, so the probe compares the same prepared build identities.
- Refuse a second release increment after committing failed preparation until
  the saved candidate's Git delivery is confirmed. Retain the plan and evidence
  when delivery is missing or uncertain
  ([#292 — Prevent committed release preparation from silently incrementing twice](https://github.com/dragginzgame/shared-tooling/issues/292)).

## [0.25.8]

### Fixed

- Accept numbered `- Unreleased` changelog headings during release preflight
  and replace the marker with the saved UTC release date during preparation,
  before the release commit, tag and push.

## [0.25.7]

### Changed

- Require Rust release and deployment entrypoints to pass their existing Clippy
  gate before expensive builds, tests, packaging or new external effects, with
  failure stopping later stages even under parallel Make. Consumers retain the
  selected lint scope and must apply the ordering in their own entrypoints.

## [0.25.6]

### Fixed

- Retain Cargo metadata failure diagnostics, root inputs and separate command/
  logger statuses, preserving the original failure without automatic retries
  ([#291 — Retain failed Cargo metadata diagnostics and root inputs](https://github.com/dragginzgame/shared-tooling/issues/291)).

## [0.25.5]

### Changed

- Qualify focused fixture exports from one entrypoint each, deriving helpers
  through declared companions instead of selecting a second helper roster.
  Independent exports prevent one fixture from masking another's missing dependency.
- Derive installer, tooling-report and failure-retention fixture inputs from
  declared companions rather than copied helper rosters. Failure-evidence checks
  use the shared step reader to reject ambiguous or incomplete run selections,
  reusing one parsed action for collection and policy assertions.
- Prepare installer fixture checksums through the shared digest reader, removing
  a separate backend-selection and checksum-output parser.

## [0.25.4]

### Fixed

- Clarify failure-evidence collection: use the existing orchestrator, treat failed
  selector output as diagnostics and retain redirected parent links without
  traversing them. Keep product log selections and hosted transport checks local.

## [0.25.3]

### Added

- Enable explicit Cargo features when preparing and checking selected tools,
  including Host's `ic-host-file` CLI. Bind canonical feature sets to immutable
  selections and Cargo receipts; offline checks never install or repair tools
  ([#289 — Support explicit Cargo features in selected-tool installation and admission](https://github.com/dragginzgame/shared-tooling/issues/289)).
  After adoption, rerun explicit tool setup for the updated build policy;
  previous installations and failed attempts remain retained.

## [0.25.2]

### Fixed

- Use the shared fixture lifecycle for remaining plain cleanup handlers, keeping
  failed inputs and cleanup diagnostics consistent across metadata, registry,
  Make, release and snapshot checks.
- Prepare installer and tool-report fixtures from their entrypoints' declared
  companions, so helper changes propagate without separate copied file lists.
  Keep fixture-specific catalogs and effect substitutes explicit.

## [0.25.1]

### Changed

- Require Wire for owned application endpoints, including public and third-party
  callers. Reserve Candid for required independent protocols and existing
  checkpoint compatibility; qualify actual frames and bindings during migration.
- Clarify maintenance of imported runtime and cryptographic code: preserve
  provenance, review applicable upstream fixes and qualify intentional source
  changes. Require isolated recovery evidence before claiming build independence.

### Fixed

- Prepare Shared's selected tools during admitted fresh release preflight and
  merged-source qualification. Keep saved preparation and standalone preflight
  checks offline, with setup failures stopping before validation or version writes.
- Retain Perl fixture inputs when setup crashes, execution ends early or cleanup
  fails, preserving the original failure status and diagnostic evidence.
- Preserve Shared release-preparation originals and candidates on failure while
  keeping VERSION-last replacement and retry behavior. Report retained evidence
  when scratch cleanup fails.
- Use shared lifecycle handling in Cargo freshness and release-metadata fixtures
  so cleanup failures identify retained inputs and preserve their failure status.
- Pin Shared's own development compiler and prepare it before CI computes Cargo
  cache identity or builds tools, preserving the runtime scanner's separate floor.
- Refuse missing or malformed release-editor inputs before portable fixtures
  start. Use `make test-portable` to supply the admitted editor and byte allowance.
- Explain Cargo-tool admission failures with the rejected source or receipt path
  and an explicit setup command retaining the requested selection. Rerun setup
  after adopting the updated build-helper policy; prior generations stay retained.

## [0.25.0]

### Breaking

- License admission requires regular non-symlink source files. Replace license
  aliases with complete regular copies before checking source or package archives.
- Delegate Cargo manifest and lock candidate rendering to released IC Build.
  Cargo adapters must supply the prepared editor's absolute path and a positive
  input byte allowance to the renderer. The standalone Perl editors
  `render-cargo-workspace-version.pl` and `rewrite-local-lock-versions.pl` are
  removed; direct callers must adopt the owner command. See
  [Cargo candidate rendering](docs/releases.md#cargo-release-candidate-rendering)
  and [#273 — Adopt released IC Build Cargo editor and retire Perl renderers](https://github.com/dragginzgame/shared-tooling/issues/273).

### Added

- Check indexed and tracked/nonignored working paths for repository symlinks,
  including dangling links and redirected parent directories. Shared CI and
  release validation run this check without following targets or changing Git state.
- Verify licenses inside explicitly selected prepared Cargo archives against
  canonical terms and the source's exact bytes. Refuse missing, duplicate, linked
  or altered entries and corrupt archives without extraction or publication.
- Share selected Cargo graph checks for canonical package identities, optional
  identity caps and forbidden dependency-feature edges. Consumers keep their
  roots, targets, feature selections and policy; failed or malformed Cargo
  observations cannot pass admission.
- Retain child user/system CPU observations alongside paired snapshot export
  timings, preserving the elapsed-time format and payload checks. This supports
  native investigation of
  [#219 — Reduce repeated snapshot work](https://github.com/dragginzgame/shared-tooling/issues/219).

### Changed

- Prohibit symlinks in maintained source and package assets, including licenses.
  Keep narrowly admitted tool-store selection pointers and isolated rejection
  fixtures; use regular package-local copies where needed.
- Prefer IC Wire for supported controlled application messages. Require a concrete
  reason for retained Candid use, and audit actual exports and codec consumers
  across both protocols while preserving required interoperability.
- Allow production and test/tooling package headers inside `workspace.members`,
  distinct from dependency-role headers in `workspace.dependencies`.
- Require Clap for Rust CLI argument handling, using its existing parsing,
  validation and help capabilities before adding custom CLI mechanics.

### Fixed

- Require release adapters to select admitted tool paths themselves, preserving
  the one-shot release commands without per-shell environment exports. Keep
  fresh setup after source admission and recovery bound to saved selections.
- Prepare Shared's required release editor through local setup and use the same
  offline-admitted selection in Make and CI. Missing tools stop before fixture
  dispatch; consumers retain their own release-tool choices.
- Prepare governance snapshot fixtures from their complete companion closure,
  so exported guides retain newly linked documentation without extra roots.

## [0.24.3]

### Changed

- Require external IC-specific dependencies, including DFINITY packages, to go
  through `ic-platform` in production, build, test and tooling code. Keep product
  policy with its owning crate and track missing Platform capabilities and
  existing direct dependencies under the
  [dependency boundary](rules/cargo-dependencies.md#external-ic-dependency-boundary).

### Fixed

- Use the shared preparation transaction for coordinated Cargo releases. Finish
  rendering every candidate before installation and preserve originals and
  candidates when rendering, installation, validation or restoration fails.

## [0.24.2]

### Added

- Share selected-file release preparation and previous-attempt evidence archives.
  Admit every candidate before installation, restore bytes and modes on caught
  failure, and retain originals when preparation or restoration fails. Consumers
  keep rendering, source qualification, receipt schemas and recovery policy
  ([PR #283 — Share release metadata preparation and retained evidence custody](https://github.com/dragginzgame/shared-tooling/pull/283)).

## [0.24.1]

### Added

- Share exact validation and prepared-file receipts with atomic replacement.
  Consumers retain selected files, trusted state custody and release policy
  ([#278 — Share release validation and prepared receipt mechanics](https://github.com/dragginzgame/shared-tooling/issues/278)).
- Share prepared-package provenance checks and saved-source member context.
  Require exact source identities and one parser observation per selected member;
  retain failure evidence without taking over package eligibility or publication.

### Changed

- Replay retained formatting-adoption logs on failure without an outer consumer
  fixture, preserving the original status and evidence custody.
- Permit fixture scratch beneath its source only when the complete copy plan
  preserves every selected input; reject source/output collisions, including
  hard-linked aliases, before copying.
- Preserve dependency sections in the default Cargo formatter and check command.
  Consumers can remove paired overrides that only repeat grouped sorting and
  rustfmt; adapters for additional formatting steps remain consumer-owned.

### Fixed

- Point exported capability-map links at their Shared owner rather than a
  consumer-owned README ([#284 — Keep exported capability-map links at Shared](https://github.com/dragginzgame/shared-tooling/issues/284)).
- Check current dependency declarations after unstaged tracked deletions without
  changing the consumer index. Keep dangling symlinks and failed filesystem
  observations as refusals, including inaccessible or non-directory parents
  ([#271 — Dependency pin checker rejects tracked manifest and workflow deletions](https://github.com/dragginzgame/shared-tooling/issues/271)).
- Follow the common-tool setup action when qualifying CI cache ordering and
  retained installer failure evidence, replacing stale inline-step assumptions.
- Reject fixture outputs that hard-link to selected inputs or each other before
  copying. Prepare checker-retention fixtures with their complete companion
  closure so intended
  child/assertion failures run and retain their evidence
  ([#274 — Prepare script fixtures from their declared companion closure](https://github.com/dragginzgame/shared-tooling/issues/274)).

## [0.24.0]

### Breaking

- **Common Rust tools:** setup selects cargo-sort and cargo-sort-derives only.
  Candid extraction consumers must explicitly prepare/check their selected
  extractor and publish its admitted PATH. Integrate
  [Canic PR #597 — Own explicit Candid extractor setup](https://github.com/dragginzgame/canic/pull/597)
  before Canic adopts this snapshot. Existing retained installations remain intact.
- **IC catalog output:** direct AWK admission emits complete validated records.
  Replace version-only and validation-only calls with `tool-catalog-records.pl ic
  CATALOG [TOOL]`; discard output explicitly when only admission is required.
- **Diagnostic checksums:** native archive sidecars contain a bare digest.
  Verify against the explicitly selected archive with the shared checksum helper;
  replace calls that pass the sidecar directly to `shasum -c`.
- **Release adoption checks:** fixture preparation follows selected inputs'
  declared companion closure. Refresh partial snapshots with the shared fixture
  preparer and required companions; release execution remains substituted.

### Changed

- Support grouped Cargo manifest ordering in current and committed-source release
  checks. Adoption guidance pairs formatter/release policies and distinguishes
  production dependencies from tests/tooling without implying publication or
  automated deployment enforcement.
- Verify compact evidence for the caller-selected host/IC bundles, requiring all
  selected receipts and preserving IC-specific admission when IC is selected
  ([#282 — Verify compact evidence for caller-selected tool bundles](https://github.com/dragginzgame/shared-tooling/issues/282)).
- Release preflight and increment calculation share canonical version/date
  admission and exact u64 arithmetic, rejecting overflow without rounding.
  The public increment command retains its invocation and invalid-input status.
- IC installation and retained-bundle checks consume canonical catalog records,
  preserving archive authentication and checking versions only after the complete
  set is authenticated. Tool catalogs share stable-version grammar while retaining
  CLOC's two-component versions and separate release numeric bounds.
- CI reuses the common preparation action while publishing its selected IC PATH
  explicitly. Cargo binary qualification removes unused example handling after
  Blob's extraction; current setup guidance identifies the capability owners.

### Fixed

- Native CI reuse checks derive the common Rust selection from its catalog and
  reject missing or non-executable tools before comparing physical paths.
- Align the hook fixture's Prettier substitute with the maintained invocation,
  preserving selected-file and failure-isolation checks
  ([PR #281 — Fix hook fixture Prettier argument admission](https://github.com/dragginzgame/shared-tooling/pull/281)).

## [0.23.0]

### Breaking

- Move the frozen Blob example-installation assessment to
  [IC Blob Storage PR #80 — Own frozen published-example installation qualification](https://github.com/dragginzgame/ic-blob-storage/pull/80).
  Integrate that owner before adoption; Shared keeps common Cargo binary
  qualification and installer mechanics
  ([#280 — Retire frozen Blob example assessment after native owner qualification](https://github.com/dragginzgame/shared-tooling/issues/280)).
- Frontend formatting delegates language recognition to pinned Prettier. Review
  `.prettierignore` before adoption: supported formats such as `.mjs` and `.vue`
  now participate without a Shared Tooling extension allowlist.
- Catalog ownership checks require the canonical snapshot manifest grammar.
  Refresh incomplete or malformed ownership receipts before adoption; selected
  catalog hashing remains separate from whole-snapshot verification.
- Remove the separate Make-fixture copier. Select Make roots through the script
  companion-closure preparer, then apply consumer-owned adapters and substitutions.
- Remove the local semantic Wasm qualification command and CI step. Integrate
  [IC Build PR #62 — Own native Wasm optimizer qualification](https://github.com/dragginzgame/ic-build/pull/62)
  before adopting this snapshot; its native matrix owns the optimizer/cache/reply
  oracle. Shared retains archive integrity and executable installation checks
  ([#277 — Retire semantic Wasm qualification after IC Build native coverage](https://github.com/dragginzgame/shared-tooling/issues/277)).

### Changed

- Normalize installer OS/architecture aliases through one read-only observer,
  retaining each toolset's asset matrix and rejecting failed host observations
  before installation or download.
- Carry the GitHub dashboard's displayed closed-PR count directly through rows,
  totals and layout, preserving merge timestamps, pagination and partial errors.
- Common Rust setup projects validated catalog records directly into tool
  selections, removing the reconstructed variables and duplicate default roster.
- CI binary installation reuses the host/IC downloader's bounded transient-retry
  policy while retaining checksum admission, atomic publication and failed stages.

## [0.22.1]

### Added

- Prepare disposable script fixtures from explicit roots and their declared
  companion closure, reusing snapshot distribution's nonexecuting reader. Keep
  export measurements bound to frozen helper blobs, including that reader
  ([#274 — Prepare script fixtures from their declared companion closure](https://github.com/dragginzgame/shared-tooling/issues/274)).

### Changed

- Update the canonical evidence and snapshot-comparison uploaders to the exact
  7.0.2 source, preserving archive preparation and failure policy
  ([#275 — Update the canonical artifact uploader to 7.0.2](https://github.com/dragginzgame/shared-tooling/issues/275)).

## [0.22.0]

### Changed

- Select common CI binary pins directly from the reviewed tool catalog. Linux
  x86-64 callers need only a tool and installation directory; explicit catalog
  exceptions and paired version/checksum inputs remain available. Reuse the
  shared fixture lifecycle for formatting adoption, installer and download checks,
  preserving failed evidence and cleanup failures.

### Breaking

- Remove the raw catalog `values` projection. Consume validated `host`, `rust`,
  `ic` or `ci` records, optionally selecting a tool after complete group admission.
- Move the temporary public-documentation debt checker, guide and dedicated
  fixtures to IC Query. Integrate
  [Query PR #76 — Own public documentation debt tooling](https://github.com/dragginzgame/ic-query/pull/76)
  before adopting this snapshot; other consumers must own any local debt policy
  ([Query #75 — Own temporary public-documentation debt policy](https://github.com/dragginzgame/ic-query/issues/75)).
  The common section-style type checker and Rust tokenizer remain shared.

## [0.21.0]

### Added

- Compare repeated snapshot exports on Linux and both native macOS hosts through
  an opt-in workflow. Both exporters use one frozen payload, retain alternating
  timing samples and verify matching receipts and files. Routine CI stays focused
  on correctness; native performance acceptance still requires observed results
  ([#219 — Reduce repeated snapshot work](https://github.com/dragginzgame/shared-tooling/issues/219)).
- Package comparison evidence through the canonical archiver so downloads retain
  hidden snapshot receipts, logs and incomplete attempts. Exclude source clones
  and Git stores, and preserve packaging failures
  ([#219 — Reduce repeated snapshot work](https://github.com/dragginzgame/shared-tooling/issues/219)).

### Changed

- Consume validated host-tool records directly during installation, preserving
  payload authentication and offline checks without reconstructing catalog
  environment variables or repeating catalog admission.
- Select ICP CLI 1.7.0 for the three supported IC-tool hosts using official
  release-asset digests. Other tool pins and explicit setup policy are unchanged;
  adopters run IC-tool setup before offline checks with the new catalog
  ([#268 — Adopt ICP CLI 1.7.0](https://github.com/dragginzgame/shared-tooling/issues/268)).

### Fixed

- Require one complete Rust policy observation before publishing a workspace
  compiler floor or preparing a toolchain. Reject ambiguous parser streams before
  Rustup while preserving valid bootstrap inputs and parser failure statuses
  ([#270 — Reject ambiguous Rust bootstrap policy observations](https://github.com/dragginzgame/shared-tooling/issues/270)).

### Breaking

- Remove the complete Cargo publication preflight command. Consumers own package,
  registry and release-tag policy while reusing the shared source, version, tag
  and registry observers. IC Jobs adopts its local policy in
  [PR #67 — Own publication admission locally](https://github.com/dragginzgame/ic-jobs/pull/67);
  integrate that caller before adopting this snapshot.

## [0.20.0]

### Added

- Check consumer-owned Cargo dependency boundaries across canonical package names,
  including renamed, target-specific, build and development dependencies. Refuse
  failed, incomplete or mismatched metadata before reporting success; run locked
  and offline without changing dependency selection
  ([PR #257 — Add declarative Cargo dependency boundaries](https://github.com/dragginzgame/shared-tooling/pull/257),
  [Storage #4 — Adopt fail-closed dependency-boundary admission](https://github.com/dragginzgame/ic-storage/issues/4)).
- Declare supported release-delivery modes once in a consumer-owned data file.
  Common Make admission and standalone metadata entrypoints reuse the same
  read-only check, rejecting unsupported selections before effects while leaving
  unrelated goals unchanged
  ([#258 — Declare consumer-supported release delivery once](https://github.com/dragginzgame/shared-tooling/issues/258)).

### Fixed

- Keep installer CLI smoke checks with their owning fixture instead of a second
  portable-runner roster. Remove the stale YQ call that made 0.19 Linux CI exit
  after all named shell fixtures had passed
  ([#266 — Retire standalone YQ installation](https://github.com/dragginzgame/shared-tooling/issues/266)).

### Breaking

- Common setup, offline checks and action PATH publication now cover host/Cargo
  tools. Repositories using IC executables must select `install-ic-tools` and
  `ic-tools-check` in their ordered local target lists and publish `.tools/ic/bin`
  explicitly. Existing installations and reviewed tool pins are retained.
- Formatting hooks and their adoption checks expose only common host/Cargo
  paths by default. Product formatters requiring IC tools must select their
  prepared IC PATH explicitly, including the original tool root for index exports.
- Version reporting defaults to host/Cargo selections. Pass both the version
  catalog and IC pin catalog to include IC admission and observations
  ([#253 — Make the IC executable bundle an explicit product selection](https://github.com/dragginzgame/shared-tooling/issues/253),
  [PR #254](https://github.com/dragginzgame/shared-tooling/pull/254)).

## [0.19.0]

### Breaking

- Retire standalone `install-ci-tool.sh yq`; prepare and check YQ through the
  common host bundle instead. Other CI installers retain authenticated atomic
  publication and failure preservation
  ([#266 — Retire standalone YQ installation](https://github.com/dragginzgame/shared-tooling/issues/266)).
- Move full native recovery-archive packaging and its fixtures into IC Metrics.
  Remove the former `collect-native-evidence.sh` snapshot entrypoint on adoption;
  preserve hidden Git recovery state through Metrics' local helper and keep
  sanitized diagnostics on the shared exporter
  ([Metrics #89 — Own native recovery-archive packaging](https://github.com/dragginzgame/ic-metrics/issues/89),
  [Metrics PR #88](https://github.com/dragginzgame/ic-metrics/pull/88)).
- Require literal Host/Rust tool catalogs for installation, inspection and cache
  keys. Replace computed catalogs and duplicate assignments with complete literal
  selections before adoption
  ([#263 — Require literal data-only tool catalogs](https://github.com/dragginzgame/shared-tooling/issues/263)).
- Retire the release-prose heuristic and its fixture; remove consumer invocations
  and snapshot entrypoints while retaining metadata and receipt checks
  ([#264 — Retire the release-prose heuristic](https://github.com/dragginzgame/shared-tooling/issues/264)).
- Count every selected Rust source path in LOC reports, including identical file
  contents. Runtime and test totals share one per-file count instead of separate
  duplicate-suppressing passes
  ([#265 — Count Rust LOC from one per-file projection](https://github.com/dragginzgame/shared-tooling/issues/265)).
- Retire the README dependency-example version renderer and its fixture. Consumers
  must remove its snapshot entrypoint and automatic README rewriting before
  adoption; IC Memory tracks that update separately
  ([#260 — Retire the README version renderer](https://github.com/dragginzgame/shared-tooling/issues/260),
  [Memory #119 — Retire README version rendering](https://github.com/dragginzgame/ic-memory/issues/119)).

### Changed

- Reuse canonical stable-version comparison in tag maintenance while preserving
  minor-only cutoffs, arbitrary-size components, tag-spelling ordering and the
  existing deletion authorization, lease and recovery boundaries
  ([#267 — Reuse stable-version comparison in tag maintenance](https://github.com/dragginzgame/shared-tooling/issues/267)).
- Share literal/comment masking between documentation checkers while preserving
  source offsets, Unicode identifiers and separate documentation policies
  ([#261 — Share Rust lexical masking](https://github.com/dragginzgame/shared-tooling/issues/261)).
- Use canonical stable-version admission across Cargo release helpers, retaining
  exact large components and separate release bounds
  ([#262 — Use canonical stable-version admission](https://github.com/dragginzgame/shared-tooling/issues/262)).

- Reject signal-terminated version-ordering and tool-catalog fixture checks even
  when they emit valid output, preserving normal checker exit classifications
  ([#256 — Reject signal-terminated ordering and catalog checks](https://github.com/dragginzgame/shared-tooling/issues/256)).

## [0.17.2] - 2026-10-16

## [0.17.1]

- Keep expected type-documentation rejections out of passing CI output, replay
  unexpected failures from retained case logs, reject signal-terminated checks
  and print Unicode diagnostic names without encoding warnings
  ([#255 — Retain type-doc diagnostics and reject signal-terminated checks](https://github.com/dragginzgame/shared-tooling/issues/255)).
- Avoid external comparisons for empty snapshot index records while retaining
  every Git re-observation, staged-change refusal and publication recheck
  ([#219 — Reduce repeated snapshot work](https://github.com/dragginzgame/shared-tooling/issues/219)).
- Identify invalid pending changelog headings with their source line and the
  expected numbered spelling before release preparation; retain strict candidate
  and exact-date recovery checks
  ([#252 — Explain unsupported pending changelog headings](https://github.com/dragginzgame/shared-tooling/issues/252)).

## [0.17.0]

### Breaking

- Require `--consumer <repository>` for hook installation. Update direct setup
  callers before snapshot adoption; `make install-hooks` already supplies it.
- Require `SCCACHE_BIN` to select an absolute executable file for the stable
  compiler-cache launcher. Remove implicit PATH discovery; consumers select
  the binary or their own cache-failure adapter explicitly before launch.

### Changed

- Qualify repeated validation-log retention and Cargo/logger status combinations
  at their Shared owners. Earlier failure bytes survive retries and unusable
  evidence destinations; consumers retain their adapter and lock-cleanup checks
  ([PR #249 — Repeated logger failures](https://github.com/dragginzgame/shared-tooling/pull/249),
  [PR #250 — Publication logger status](https://github.com/dragginzgame/shared-tooling/pull/250)).
- Require a commit object when proving prior snapshot ownership, including
  takeover receipts. Refuse tree/tag identities and failed type observations
  before changing consumer files
  ([#248 — Require commit objects for prior snapshot ownership proofs](https://github.com/dragginzgame/shared-tooling/issues/248)).
- Avoid repeated directory-creation commands for existing snapshot payload
  parents, retaining manifest admission, drift checks and atomic replacement
  ([#219 — Reduce repeated snapshot work](https://github.com/dragginzgame/shared-tooling/issues/219)).
- Qualify release preflight refusals at the shared runner/helper boundary,
  preserving source, index and existing tools before version preparation.
  Shared fixtures also own reporter partial output and archive diagnostic
  checksum preservation, keeping consumer checks focused on their own adapters
  ([PR #247 — Keep generic release and evidence qualification at Shared owners](https://github.com/dragginzgame/shared-tooling/pull/247)).

## [0.16.1]

- Read snapshot companion headers with Bash instead of launching a parser for
  each payload, preserving literal second-line selection and EOF handling
  ([#219 — Reduce repeated snapshot work](https://github.com/dragginzgame/shared-tooling/issues/219)).
- Share the read-only workspace Rust-floor projection between explicit Rust
  setup and consumer validation. It uses prepared TOML/JSON parsers without
  requiring Cargo/Rust or performing installation; failed parser observations
  publish no selection
  ([PR #246 — Share read-only workspace Rust floor selection](https://github.com/dragginzgame/shared-tooling/pull/246)).
- Qualify exact working-file and Git index preservation when release-source
  checks admit an allowed metadata edit or refuse an unapproved rename source
  ([PR #242 — Own release-source allowance and rename preservation checks](https://github.com/dragginzgame/shared-tooling/pull/242)).
- Qualify release-source refusal of failed Git observations even when they emit
  plausible output, and invalid selections before Git dispatch, with input
  preservation and scratch cleanup.

## [0.16.0]

### Breaking

- Require `--install-dir` for CI binary installation, removing environment and
  home-directory destination selection. Update installer invocations before
  adopting this release
  ([#244 — Require explicit CI tool installation destinations](https://github.com/dragginzgame/shared-tooling/issues/244)).
- Require explicit assertion source, prefix and contradictory bindings for
  retention probes. The probe executes only owner initialization and the selected
  assertion; migrate inferred-assertion callers to `--selected` before refresh
  ([#245 — Require explicit assertion selection in retention probes](https://github.com/dragginzgame/shared-tooling/issues/245)).
- Keep `make cloc-tooling` and `CLOC_PARENT` in Shared Tooling's own Makefile.
  Consumer includes no longer export the fleet command; run it centrally or
  explicitly select and invoke the Perl reporter when adopting this release
  ([#243 — Keep fleet tooling Make command at its Shared Tooling owner](https://github.com/dragginzgame/shared-tooling/issues/243)).
- Remove the exported exhaustive Make execution-mode probe. Consumers must use
  `make_probe_target_admission` for target admission when adopting this release;
  parallel-dispatch checks remain available. The complete flag matrix stays in
  the producer fixture
  ([PR #241 — Keep exhaustive qualification at Shared owners](https://github.com/dragginzgame/shared-tooling/pull/241)).

## [0.15.10]

- Qualify standalone formatting success and cleanup at the wrapper owner,
  preserving earlier failure logs byte-for-byte
  ([PR #240 — Standalone formatting and retained-log qualification](https://github.com/dragginzgame/shared-tooling/pull/240)).
- Qualify missing workspace versions and duplicate TOML tables at the Cargo
  version-reader owner, keeping release-adapter checks focused on their boundary
  ([PR #241 — Keep exhaustive qualification at Shared owners](https://github.com/dragginzgame/shared-tooling/pull/241)).

## [0.15.9]

- Read Rust setup selections from existing toolchain or workspace TOML policy,
  rejecting invalid selections and directory paths before installation
  ([PR #239 — Read Rust setup selections from TOML policy](https://github.com/dragginzgame/shared-tooling/pull/239)).
- Qualify common publication eligibility with real local Git histories and bare
  destinations, keeping package selection and upload recovery consumer-owned
  ([PR #238 — Real-Git publication eligibility qualification](https://github.com/dragginzgame/shared-tooling/pull/238)).

## [0.15.8]

- Include cleanup refusal in the standard fixture exit probes, preserving
  caller-specific diagnostic checks without a duplicate injection
  ([PR #237 — Include cleanup refusal in standard exit probes](https://github.com/dragginzgame/shared-tooling/pull/237)).
- Qualify nested workflow discovery and failed Git inventories at the dependency
  checker owner, including partial output and scratch cleanup
  ([PR #236 — Qualify dependency workflow inventory failures](https://github.com/dragginzgame/shared-tooling/pull/236)).
- Keep scanner semantic-fixture evidence and cleanup anchored when temporary
  directory aliases change. Native qualification retains and checksums the
  shared lifecycle companion with its source inputs
  ([#225 — Structural Rust runtime panic scanner](https://github.com/dragginzgame/shared-tooling/issues/225)).

## [0.15.7]

- Qualify real Cargo environment and configuration offline refusal on a frozen
  minimal graph before tool dispatch, preserving its manifest and lock
  ([PR #235 — Qualify real Cargo offline policy](https://github.com/dragginzgame/shared-tooling/pull/235)).
- Reuse exit-retention checks across caller-selected completion variables and
  physical scratch roots, including relative paths and aliases. Require a fresh
  child receipt on repeated probes while preserving earlier retained evidence
  ([PR #234 — Reuse fixture exit qualification](https://github.com/dragginzgame/shared-tooling/pull/234)).
- Accept padded BSD line counts in scanner qualification so native macOS
  refusal checks reach the full retained-failure matrix
  ([#225 — Structural Rust runtime panic scanner](https://github.com/dragginzgame/shared-tooling/issues/225)).

## [0.15.6]

- Refuse failed Git file-mode observations during snapshot refresh even when
  they emit a complete row, before publishing payloads or a manifest
  ([#219 — Reduce repeated snapshot work](https://github.com/dragginzgame/shared-tooling/issues/219)).
- Preserve the release adapter's selected Make executable during Cargo preflight,
  including paths with spaces and exact failure propagation
  ([PR #233 — Honor selected Make during Cargo release preflight](https://github.com/dragginzgame/shared-tooling/pull/233)).
- Avoid external path-utility launches during snapshot refresh, reusing each
  output parent while retaining source, consumer and index drift checks
  ([#219 — Reduce repeated snapshot work](https://github.com/dragginzgame/shared-tooling/issues/219)).
- Compile and exercise the shared Rust panic scanner in each native CI lane,
  using a locked producer-only fixture without changing consumer dependency
  selection. Retain exact source inputs, compiler identity and failure logs
  ([#225 — Structural Rust runtime panic scanner](https://github.com/dragginzgame/shared-tooling/issues/225)).
- Qualify selected-source release metadata refusals and retained inputs,
  including invalid Git identities and Git commands that emit output then fail
  ([PR #232 — Selected-source metadata qualification](https://github.com/dragginzgame/shared-tooling/pull/232)).

## [0.15.5]

- Share structural Rust runtime-panic scanning as snapshot source, including
  raw identifiers and generic method calls inside macro tokens. Consumers retain
  their selected dependencies and production-source inventories
  ([#225 — Structural Rust runtime panic scanner](https://github.com/dragginzgame/shared-tooling/issues/225),
  [PR #226 — Shared scanner source](https://github.com/dragginzgame/shared-tooling/pull/226)).
- Share hosted common-tool preparation and disposable Make fixture setup,
  preserving ordered setup/check logs, failure status and PATH publication.
  Reject forbidden directory paths before copying fixture inputs
  ([PR #227 — Common preparation and fixtures](https://github.com/dragginzgame/shared-tooling/pull/227)).
- Offer focused per-target Make admission checks while keeping exhaustive flag
  and installer-failure permutations with the shared producer
  ([PR #231 — Producer qualification matrices](https://github.com/dragginzgame/shared-tooling/pull/231)).
- Replay explicitly selected fixture diagnostics without replacing the original
  failure status or taking over retention policy
  ([PR #221 — Fixture diagnostic replay](https://github.com/dragginzgame/shared-tooling/pull/221)).
- Upload caller-prepared failure archives and collection logs without collecting
  tools again; retain available diagnostics before reporting incomplete inputs.
  Ordinary collection still refuses missing roots before any collection effects
  ([PR #230 — Prepared failure evidence](https://github.com/dragginzgame/shared-tooling/pull/230)).
- Own native diagnostic-store and candidate-archive regressions, focused snapshot
  verification, and downloaded-archive rejection cases at Shared Tooling
  ([PR #222 — Native diagnostics](https://github.com/dragginzgame/shared-tooling/pull/222),
  [PR #224 — Verifier qualification](https://github.com/dragginzgame/shared-tooling/pull/224)).
- Expand simulated release-preflight cache and tool-admission coverage; consumers
  retain actual adapter, runner and recovery checks
  ([PR #228 — Release-preflight cases](https://github.com/dragginzgame/shared-tooling/pull/228)).
- Correct Rust preparation adoption guidance to include its automatically exported
  helper companion
  ([PR #223 — Rust action companion](https://github.com/dragginzgame/shared-tooling/pull/223)).

## [0.15.4]

- Make maintenance runners and scheduler files optional for consumers while
  retaining shared task guidance. Existing snapshots use explicit selection and
  guarded retirement to remove these files
  ([PR #220 — Optional maintenance runtime](https://github.com/dragginzgame/shared-tooling/pull/220)).

## [0.15.3]

- Promote Dragginz 1.1 and CLA 1.0 as the current texts, including permanent
  Toko Studios patent rights and the narrowed downstream copyright exception.
  License checks default to 1.1; historical copies require explicit 1.0 selection.
  Consumer adoption and contributor signatures remain separate recorded actions.

- Reuse immutable committed payloads and modes during snapshot refresh instead
  of reading them again after companion discovery. Consumer and index drift
  checks remain independent
  ([#219 — Reduce repeated snapshot work](https://github.com/dragginzgame/shared-tooling/issues/219)).

- Consolidate overlapping consumer snapshots through explicit, verified ownership
  handover, preserving local edits and Git index state. Add read-only changelog
  preflight before setup or release preparation
  ([PR #217 — Snapshot handover and changelog preflight](https://github.com/dragginzgame/shared-tooling/pull/217)).
- Share explicit Rust installation between local setup and hosted workflows,
  including optional Clippy/rustfmt components for minimum-Rust lanes. Keep
  toolchain selection with consumers and installation out of validation checks
  ([PR #218 — Shared Rust toolchain setup](https://github.com/dragginzgame/shared-tooling/pull/218)).

## [0.15.2]

- Add a contributor agreement granting Toko Studios explicit alternative
  licensing rights, with contributor/employer authority and signed-scope records.
  Acceptance and existing-contribution clearance remain separately recorded.

- Prepare Dragginz license 1.1 with contributor patent grants and defensive
  patent termination. The current text preserves permanent Toko Studios rights;
  existing licenses and grants remain unchanged without deliberate adoption.
- Separate optional maintenance runner/systemd selection roots from the governance
  catalog. Keep task guidance available without operational payloads; explicit
  opt-in and guarded retirement use the existing snapshot exporter contract.

- Share explicit Rust installation between local callers and the existing
  toolchain action; allow minimum-toolchain components for MSRV lint lanes.

- Add read-only changelog preflight using the canonical candidate selector.
- Support explicit verified snapshot ownership handover during consumer refresh,
  preserving source proof, local edits, index custody and selected entrypoints.


- Complete saved-source Cargo dependency projection, previously noted as pending
  in 0.15.1. Archived manifests now use recorded workspace identity without
  reconstructing the old checkout, preserving unrelated bytes and rejecting
  incomplete ownership evidence
  ([#210 — Saved-source dependency projection](https://github.com/dragginzgame/shared-tooling/issues/210)).

## [0.15.1]

- Project saved Cargo manifests using recorded source identity, updating owned
  dependency requirements without reconstructing the original workspace. Preserve
  unrelated bytes and refuse incomplete ownership evidence before emitting output
  ([#210 — Saved-source dependency projection](https://github.com/dragginzgame/shared-tooling/issues/210)).
- Clarify which regression checks Shared Tooling owns and which integration,
  recovery and native checks consumers retain. Review each proof before removing
  duplicate test dispatch; existing validation gates remain unchanged
  ([#212 — Producer and consumer qualification ownership](https://github.com/dragginzgame/shared-tooling/issues/212)).

## [0.15.0]

### Breaking

- Prepare coordinated Cargo releases with literal manifest updates instead of
  implicit Cargo-edit/Cargo-sort mutation. Consumers must keep ordering checks
  explicit; unsupported manifest layouts refuse without installing changes.
- Select consumer fixture variables explicitly instead of guessing aliases.
  Non-default layouts must set `FIXTURE_PROBE_ROOT_VARIABLE` and
  `FIXTURE_PROBE_DIRECTORY_VARIABLE`; failure status and evidence remain preserved.

### Changed

- Keep exhaustive shared implementation regressions at their producer; consumers
  retain actual integration and admission checks against their reviewed snapshot.
- Share complete native evidence packaging with hidden Git recovery state,
  replayable inventories, checksums and original failure/partial-output custody.

### Fixed

- Own release/formatting checker failure-retention payload and formatting
  completion qualification here, allowing consumers to check only their own logs.
- Advance workspace-owned path dependency requirements across minor and major
  releases, preserving unrelated manifest bytes and restoring originals on failure
  ([PR #197 — Coordinated Cargo requirements](https://github.com/dragginzgame/shared-tooling/pull/197)).
- Preserve Cargo metadata failures under Bash 3.2, even when the failed command
  emits valid-looking output.
- Reject successful cleanup claims when hidden files or dangling links remain.
- Exclude failed tool-selection output from archive payload selection while
  retaining safe local evidence and original diagnostics.

### Added

- Prepare deliberately unsorted Cargo formatting fixtures from caller-selected
  adjacent dependencies, preserving manifest bytes and rejecting unsupported
  layouts before emitting output.

- Verify controlled hosted-scenario artifacts beside their Shared producer;
  consumers select archive prefixes and keep source/run and tool-pin admission
  ([PR #209 — Independent scenario verification](https://github.com/dragginzgame/shared-tooling/pull/209)).

- Check manifest ordering against the selected immutable release source, and
  create hosted evidence parents only after complete input admission
  ([PR #208 — Hosted qualification admission](https://github.com/dragginzgame/shared-tooling/pull/208)).

- Share locked release preflight with catalog identity checks and exact workflow
  run-body extraction; callers retain preparation authority and execution policy
  ([PR #207 — Workflow extraction and release preflight](https://github.com/dragginzgame/shared-tooling/pull/207)).

- Add Shared Tooling’s MIT license and clarify the fleet license selection:
  Dragginz for IcyDB, Canic and IC Relay; MIT for other sibling libraries and
  tools, preserving existing notices and earlier grants.

- Qualify caller-selected assertions without executing the remaining fixture
  body; require proof that the assertion was reached
  ([PR #203 — Selected assertion probes](https://github.com/dragginzgame/shared-tooling/pull/203)).
- Share native host checks, admitted tool-version reports and pipe jobserver
  observation while keeping host matrices and tool selections with consumers.
- Share Make adapter checks, retained-effect probes and selected diagnostic
  archives; consumers retain payload selection, upload policy and Git recovery
  custody
  ([PR #201 — Consumer qualification flows](https://github.com/dragginzgame/shared-tooling/pull/201)).

## [0.14.1]

- Qualify failed status assertions through a shared fixture-retention probe with
  explicit source/root inputs and fail-closed layout admission.
- Add caller-selected rustdoc debt and type-documentation checks, completing
  their previously pending integration
  ([#181 — Rustdoc debt comparison](https://github.com/dragginzgame/shared-tooling/issues/181),
  [#187 — Type documentation checks](https://github.com/dragginzgame/shared-tooling/issues/187)).
- Add complete release-change collection bound to the verified base commit and
  a non-blocking prose advisory
  ([PR #191 — Release observation helpers](https://github.com/dragginzgame/shared-tooling/pull/191)).
- Validate release versions and calendar dates exactly, preserving readable
  failure evidence
  ([#193 — Release input admission](https://github.com/dragginzgame/shared-tooling/issues/193)).
- Discover current Rust sources for opt-in formatting qualification, including
  new files and tracked deletions without changing the caller's index
  ([#195 — Formatting source discovery](https://github.com/dragginzgame/shared-tooling/issues/195)).
- Support consumer fixture root names and diagnostic failure probes while
  preserving original status and retained evidence
  ([PR #183 — IcyDB fixture support](https://github.com/dragginzgame/shared-tooling/pull/183)).

## [0.14.0]

This draft includes local changes and work prepared in open PRs; integration
and required native CI remain pending. The earlier 0.13.1/0.13.3 descriptions
remain historical pending notes.

### Added

- Own canonical MIT and Dragginz Verifiable ICP Burn license templates with an
  opt-in drift checker, preserving consumer copyright and prior-license notices.
  Third-party live use requires verifiable mainnet burning; the named organization
  receives an express operational exception.

- Prepare item-level rustdoc debt comparison and opt-in type-documentation
  layout checks, preserving caller-owned source selection and policy
  ([#181 — Extract caller-owned rustdoc item-debt comparison](https://github.com/dragginzgame/shared-tooling/issues/181),
  [#187 — Share opt-in section-style Rust type documentation checks](https://github.com/dragginzgame/shared-tooling/issues/187)).
- Prepare complete release-change collection bound to the verified base commit,
  plus a non-blocking release-prose advisory
  ([PR #191 — Share release-prose and complete change-observation helpers](https://github.com/dragginzgame/shared-tooling/pull/191)).

### Fixed

- Prepare exact stable-version and calendar-date admission for release inputs,
  with snapshot qualification and readable retained failure evidence
  ([#193 — Own release version and calendar-date admission](https://github.com/dragginzgame/shared-tooling/issues/193)).

## [0.13.3]

Pending integration: the changes below are in
[PR #194 — Release version and date admission](https://github.com/dragginzgame/shared-tooling/pull/194)
and [PR #191 — Release prose and change observation](https://github.com/dragginzgame/shared-tooling/pull/191),
and are not yet on `main`.

### Fixed

- Reject impossible dates in saved release plans through shared stable-version
  and Gregorian UTC-date admission. Preserve exact u64 components and the
  increment helper's stricter signed arithmetic headroom
  ([#193 — Own release version and calendar-date admission](https://github.com/dragginzgame/shared-tooling/issues/193)).
- Bind release-change collection to the verified base commit, so a moving tag
  cannot silently change the comparison. Qualify the collector's failure and
  tag-movement cases under Bash 3.2 as well as current Bash.
- Include the release-input helper in snapshot qualification and restore the
  unreadable-manifest fixture's permissions so later failures retain archivable
  evidence.

### Added

- Share complete NUL-separated release-change collection, publishing paths only
  after both tracked and untracked Git observations succeed. Keep package-impact
  policy with consumers.
- Share the optional release-prose advisory, keeping missing inputs and reader
  failures non-blocking and release decisions with callers.

## [0.13.2]

### Added

- Share fixture completion checks independently of cleanup, so qualification
  runners can reject incomplete execution while retaining successful evidence.
  Preserve original failure statuses and reject invalid status values
  ([#192 — Share fixture completion admission](https://github.com/dragginzgame/shared-tooling/issues/192)).

## [0.13.1]

These notes are pending PR integration; the changes below are not yet on `main`.

### Added

- Provide opt-in, item-level rustdoc debt comparison using Perl. Preserve caller
  ownership of Cargo execution and baselines; distinguish raw identifiers,
  Unicode owners and lowercase variant fields so equal warning counts cannot
  hide replacement debt
  ([#181 — Extract item-level rustdoc debt comparison](https://github.com/dragginzgame/shared-tooling/issues/181)).
- Provide selected-source Rust type-documentation layout checks, including raw
  and Unicode names, indented declarations and multiline attributes. Reject
  unreadable subtrees instead of reporting success for an incomplete scan
  ([#187 — Share opt-in Rust type documentation checks](https://github.com/dragginzgame/shared-tooling/issues/187)).

### Changed

- Extend fixture-exit probes for consumer root names and diagnostic failures,
  preserving original failure status and retained evidence
  ([#174 — Share fixture exit and retained-evidence probes](https://github.com/dragginzgame/shared-tooling/issues/174)).

## [0.13.0]

### Added

- Share fixture-directory allocation and physical-path anchoring, preserving
  failed allocations for diagnosis and keeping cleanup policy with callers
  ([#189 — Share fixture-directory allocation](https://github.com/dragginzgame/shared-tooling/issues/189)).

## [0.12.9]

### Fixed

- Keep fixture timing labels accurate for commands with interpreter flags, and
  verify failure propagation without depending on portable-suite ordering.

## [0.12.8]

### Fixed

- Include the publication guide when refreshing existing release-documentation
  snapshots, without enabling publication commands
  ([#176 — Export the publication guide](https://github.com/dragginzgame/shared-tooling/issues/176)).

## [0.12.7]

### Added

- Share explicit development/MSRV Rust toolchain preparation across native
  workflows, preserving caller-selected versions and targets
  ([#177 — Share explicit Rust toolchain preparation](https://github.com/dragginzgame/shared-tooling/issues/177)).

## [0.12.6]

### Fixed

- Qualify reviewed governance-only changes without native toolchain setup, while
  retaining required check names, documentation checks and full validation for
  unknown or code changes
  ([#182 — Documentation-only CI selection](https://github.com/dragginzgame/shared-tooling/issues/182)).

## [0.12.5]

### Changed

- Show full repository names in the issue dashboard when they fit the terminal;
  shorten Dragginzgame names when space is limited or the width is unknown.

## [0.12.4]

### Changed

- Provide advisory, package-selected Cargo README dependency rendering; preserve
  unsupported or ambiguous examples with a reminder
  ([#178 — Own advisory README dependency rendering](https://github.com/dragginzgame/shared-tooling/issues/178)).

- Give issues and PRs matching OPEN/CLOSED overall and ADDED/CLOSED today
  columns; closed PR counts include merges.

- Replace repeated full tool-fixture runs under temporary-directory aliases with
  focused installation, checking, failure-retention and cleanup coverage.
- Consolidate host and IC tool selection admission in the shared tool store,
  preserving read-only checks and tool-specific payload verification.

### Fixed

- Use the same exact stable-version ordering for Cargo tool freshness and release
  admission, avoiding precision loss when comparing large version components.

## [0.12.3]

### Changed

- Shorten the issue dashboard’s repository labels and give ISSUES and PRS
  matching OVERALL | TODAY groups, including daily merged, closed and added PRs
  using the same 06:00 Paris cutoff.

- Share fixture exit injection and retained-evidence qualification with consumers,
  retaining caller rosters, physical anchoring and actual archive round trips
  ([#174](https://github.com/dragginzgame/shared-tooling/issues/174)).

### Fixed

- Make mixed-snapshot inventory fixtures independent of the current commit hash.
  Version and revision substitutions now affect only their exact records, with
  regression coverage for the hash that broke Linux and macOS CI.
  ([#175](https://github.com/dragginzgame/shared-tooling/issues/175))

## [0.12.2]

### Changed

- Consolidate tool evidence selection and archive orchestration in a shared
  collector used by the failure-retention action; callers retain log selections,
  outer Git custody, uploads and retention.
- Own generic Cargo metadata edge-case coverage for historical note bytes,
  dated/conflicting notes, missing release selections and incomplete restoration.

### Fixed

- Correct ShellCheck handling of deliberately deferred variable expansion in
  retention probes, restoring the CI lint gate without changing probe behavior.

## [0.12.1]

### Added

- Expose coordinated Cargo member projection and graph-only admission without
  finalized release notes, retaining complete lock/workspace checks ([#171](https://github.com/dragginzgame/shared-tooling/issues/171)).
- Own exact stable-version ordering and reject non-increasing finalizer targets
  at the canonical boundary ([#172](https://github.com/dragginzgame/shared-tooling/issues/172)).
- Provide optional downloaded-evidence verification and explicit hosted failure
  stages, preserving independent receipt checks and consumer product gates
  ([#173](https://github.com/dragginzgame/shared-tooling/issues/173)).

### Fixed

- Include the caller catalog guide when exporting the snapshot-drift task,
  preventing broken documentation links in reduced consumer snapshots without
  activating the optional checker.
  ([#170](https://github.com/dragginzgame/shared-tooling/issues/170))

## [0.12.0]

### Changed

- Use the latest delivered implementation and complete required CI matrix for
  routine issue acceptance. Superseded runs remain evidence, with an explicit
  version-specific reason required to keep them as active closure gates.
  ([#169](https://github.com/dragginzgame/shared-tooling/issues/169))

### Breaking

- Require release candidates to be numbered and at the top of the changelog.
  Reject `Draft` headings and misplaced candidates instead of relocating them;
  consumers can retire equivalent guards after qualifying adoption.
  ([#162](https://github.com/dragginzgame/shared-tooling/issues/162))

### Added

- Record and execute one explicitly selected Cargo publication attempt with
  retained intent, arguments, logs and command statuses. Consumer adapters keep
  package admission, registry reconciliation and recovery policy.
  ([#163](https://github.com/dragginzgame/shared-tooling/issues/163))

## [0.11.4]

### Added

- Add pure literal Cargo workspace-version rendering with exact previous-value
  admission, byte preservation and no metadata writes. Consumers retain TOML
  admission, candidate checks and release recovery
  ([#159](https://github.com/dragginzgame/shared-tooling/issues/159)).

- Add offline comparison of workflow callers' host, Rust and IC catalogs,
  distinguishing declared bindings from recorded CLI observations and reporting
  unresolved selections explicitly. The maintenance/CI check is opt-in and
  leaves consumer pins, installation and release gates unchanged.
  ([#168](https://github.com/dragginzgame/shared-tooling/issues/168))

### Changed

- IC-tool fixtures report cleanup start, elapsed time and exit status to help
  locate macOS post-success stalls, while retaining failed attempts.
  ([#164](https://github.com/dragginzgame/shared-tooling/issues/164))

## [0.11.3]

### Added

- Add shared read-only Cargo publication admission for clean source, stable
  workspace version, matching local/pushed release tag and confirmed registry
  absence. Consumers retain package policy, upload and recovery ownership.
  ([#165](https://github.com/dragginzgame/shared-tooling/issues/165))

## [0.11.2]

### Fixed

- Fixture cleanup reports removal failures and preserves the original failure
  status when diagnostics also fail. Temporary directories remain anchored to
  their physical location across working-directory and symlink changes.
  ([#166](https://github.com/dragginzgame/shared-tooling/issues/166))

## [0.11.1]

### Fixed

- Cargo metadata checks preserve failed Git/version-reader status even when a
  producer emits valid-looking output; source object admission precedes scratch
  export ([#167](https://github.com/dragginzgame/shared-tooling/issues/167)).

### Changed

- Release recovery uses the shared annotated-tag checker, keeping exact commit
  identity checks consistent across release paths.
- Standalone fixtures share successful cleanup and failed-evidence retention.
  Snapshot refresh includes the required helper automatically.

## [0.11.0]

### Breaking

- CI binary installation now uses `install-ci-tool.sh TOOL ...`; the five
  per-tool forwarding scripts are removed. Replace their command paths and
  snapshot entrypoints when adopting this revision. Pins and installation
  arguments are unchanged.
  ([#161](https://github.com/dragginzgame/shared-tooling/issues/161))

### Added

- Add coordinated Cargo workspace release-metadata preparation and selected-commit
  checks. Consumers retain source/cache/tool admission, package policy, staging
  and release effects; failed preparation restores exact metadata and retains
  originals. Registry lock selections remain unchanged.

- Add a read-only Node/npm prerequisite checker for caller-selected package roots
  and executables, including exact tool versions and root manifest/lock agreement.

### Fixed

- Evidence readback downloads the exact uploaded artifact directly and retries
  temporary HTTP 404 responses at the download boundary. Upload digests and
  repository/run identity remain mandatory; all attempts are retained.
  ([#158](https://github.com/dragginzgame/shared-tooling/issues/158))

- CI inspection rejects invalid run identities and conflicting selectors instead
  of silently ignoring a requested run, search filter or log inspection.
  ([#157](https://github.com/dragginzgame/shared-tooling/issues/157))
- Tooling LOC inventories reject line breaks in parent and explicit snapshot
  paths before normalization or tool probes, including resolved aliases.
  ([#156](https://github.com/dragginzgame/shared-tooling/issues/156))

## [0.10.2]

### Fixed

- The GitHub sibling dashboard rejects directory paths containing line breaks,
  including resolved aliases, before submitting a report query.
  ([#155](https://github.com/dragginzgame/shared-tooling/issues/155))

## [0.10.1]

### Fixed

- Cargo CI caches remain reusable after unrelated pin, comment or record-order
  changes in literal tool catalogs. Cargo selections and build identities still
  invalidate caches; complex catalogs retain conservative byte-based keys.
  ([#154](https://github.com/dragginzgame/shared-tooling/issues/154))

## [0.10.0]

### Breaking

- Reviewed snapshots now own the default common tool catalogs. Setup, formatting,
  freshness checks and failure-evidence collection no longer discover consumer
  catalogs implicitly; host overrides no longer change Rust selections. Adopt
  the catalog companions and explicitly select any qualified exceptions before
  running setup. Tool versions and shared binary storage are unchanged.
  [Adoption guide](docs/consuming-snapshots.md#common-catalog-ownership-in-0100).
  ([#153](https://github.com/dragginzgame/shared-tooling/issues/153))

## [0.9.16]

### Fixed

- LOC reports reject directory paths containing line breaks, including resolved
  aliases, before they can select a different checkout or print misleading totals.
  ([#151](https://github.com/dragginzgame/shared-tooling/issues/151))
- Release lock failures preserve the filesystem error and exit status, and
  distinguish an existing lock from other acquisition failures.
  ([#152](https://github.com/dragginzgame/shared-tooling/issues/152))

## [0.9.15]

### Fixed

- Maintenance checks and runs reject directory paths containing line breaks,
  including resolved aliases, before probing the CLI or writing state. Existing
  reports and scheduling timestamps remain untouched on refusal.
  ([#150](https://github.com/dragginzgame/shared-tooling/issues/150))

## [0.9.14]

### Fixed

- CI inspection retrieves the selected attempt's failed-job logs when GitHub
  returns empty failed-step logs, retaining the original and recovered evidence.
  Missing logs and API failures remain explicit inspection failures.
  ([#149](https://github.com/dragginzgame/shared-tooling/issues/149))

## [0.9.13]

### Fixed

- CI inspection refuses a failed or empty current-branch observation instead of
  silently selecting unrelated runs. Explicit branch, commit and run selections
  remain available, including run inspection outside a checkout.
  ([#148](https://github.com/dragginzgame/shared-tooling/issues/148))

## [0.9.12]

### Changed

- Authorized development and validation include fetching missing Cargo sources
  for the existing lockfile without another maintainer approval. Explicit offline
  settings remain authoritative; dependency upgrades, executable-tool setup and
  release operations retain their separate authority.
  ([#147](https://github.com/dragginzgame/shared-tooling/issues/147))

## [0.9.11]

### Fixed

- Tool installation preserves filesystem errors and their exit status when
  acquiring a shared-store or checkout lock. Existing lock paths are distinguished
  from other acquisition failures, without retrying or removing another owner's
  lock or retained tools.
  ([#145](https://github.com/dragginzgame/shared-tooling/issues/145))
- Cargo tool setup preserves the original source-acquisition failure status for
  both common tools and selected package executables, stopping before build or
  activation and retaining existing tools and evidence.
  ([#146](https://github.com/dragginzgame/shared-tooling/issues/146))

## [0.9.10]

### Changed

- Maintainer reports separate genuine symbol deletions from moves and renames,
  and include scoped Rust, type and documentation change counts with explicit
  zeroes. Counting guidance distinguishes physical line churn from semantic
  removals and keeps detailed inventories in the final Codex handoff.
  ([#141](https://github.com/dragginzgame/shared-tooling/issues/141))

## [0.9.9]

### Fixed

- Rust-tool qualification now isolates its prepared compiler context from the
  invoking consumer's toolchain and reuses existing Git history without creating
  commits. Real staging, hook and receipt checks remain covered, with forbidden
  Git effects recorded even during expected failures.
  ([#143](https://github.com/dragginzgame/shared-tooling/issues/143),
  [#144](https://github.com/dragginzgame/shared-tooling/issues/144))

## [0.9.8]

### Changed

- Reuse verified Cargo tool builds between matching native CI runs while
  retaining complete setup/admission and all three host gates. Save reusable
  builds before the test suite so a later cancellation need not repeat setup.
  Portable tests now report individual fixture durations and failure statuses.
  ([#142](https://github.com/dragginzgame/shared-tooling/issues/142))

## [0.9.7]

### Fixed

- Reject non-boolean Cargo `net.offline` configuration before tool setup or
  admission, while preserving explicit environment overrides. Refreshing this
  build policy requires explicit Cargo-tool setup; earlier builds are retained.
  ([#140](https://github.com/dragginzgame/shared-tooling/issues/140))
- Compare the complete GitHub repository identity before preparing a PR release,
  rejecting malformed responses without trimming newlines. Each raw observation
  is retained across retries for diagnosis.
  ([#139](https://github.com/dragginzgame/shared-tooling/issues/139))

## [0.9.6]

### Fixed

- Reject newline-suffixed PR release identities before saving recovery state or
  accepting a merged commit. Malformed saved records and API observations remain
  available for diagnosis; valid same-release reconciliation stays supported.
  ([#139](https://github.com/dragginzgame/shared-tooling/issues/139))

## [0.9.5]

### Fixed

- Wait for newly uploaded CI evidence to become visible through bounded,
  exact-ID discovery retries. Downloads retain the pinned transport, strict
  digest checks and independent payload verification; exhausted discovery fails
  without repeating the upload or selecting another artifact.
  ([#63](https://github.com/dragginzgame/shared-tooling/issues/63))

## [0.9.4]

### Fixed

- Require complete 40- or 64-character Git identities in snapshots, refresh
  observations and release recovery. Malformed intermediate-length IDs are
  rejected before refresh or release effects, preserving existing evidence.
  ([#133](https://github.com/dragginzgame/shared-tooling/issues/133))

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
