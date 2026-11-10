# Fixtures verification helpers

## Fixture diagnostic replay

`fixture_replay_logs FILE...` in `scripts/ci/fixture-lifecycle.sh` writes existing
regular-file inputs to stderr in caller order, without adding separators. Missing
paths, directories and unmatched glob literals are skipped. Reader/output failures
are best effort and the helper returns success; callers save their original status
before invoking it and retain their existing failure/completion handling. Callers
own explicit file/glob selection, whether replay runs, and cleanup/retention policy.
No files are removed or collected into a separate artifact.

## Cargo dependency-order fixtures

```bash
perl scripts/ci/prepare-cargo-formatting-fixture.pl Cargo.toml workspace.dependencies ic-build ic-wire > unsorted.toml
```

The helper accepts a caller-owned valid Cargo manifest and swaps exactly two
adjacent, single-line declarations selected by table and bare dependency keys.
Only strings and inline-table values are supported; unsupported selections refuse
before any output. Other bytes, comments and newline positions remain unchanged,
and the source is never edited. This is fixture preparation, not TOML validation,
release metadata rendering or a production dependency reorder. Consumers retain
their selected pair and the formatting/hook assertions. Requires Perl core only.

## Consumer fixture retention probes

Source `scripts/ci/fixture-retention-probes.sh` to reuse failure injection and
retained-directory checks. Callers retain the fixture roster and mandatory
product/host assertions. `FIXTURE_PROBE_ROOT_VARIABLE` and
`FIXTURE_PROBE_DIRECTORY_VARIABLE` select explicit shell identifiers (defaults
`ROOT` and `fixture`); use `FIXTURE_ROOT` explicitly for that directory layout.
The helper renders only initialization through the first EXIT trap, replaces
selected root assignments with the supplied source root, and never executes the
actual fixture body. It qualifies nounset, failed commands, nonzero exits,
premature success and completed success/failure using the invoking Bash.
`fixture_probe_prefix SOURCE OUTPUT ROOT_VARIABLE DIRECTORY_VARIABLE INJECTION`
also renders a boundary for caller-owned contradictory assertion checks. Its
child requires `RETENTION_SOURCE_ROOT` and `RETENTION_EXIT_PATH` explicitly.
Only trusted, reviewed fixture sources and caller-owned injection are inputs.
The supported boundary is one physical line beginning with `trap ` in column
one and ending with ` EXIT`, without a trailing comment or whitespace. For a
multiline cleanup action, define a named function before `trap finish EXIT`.
This is a source convention, not a general Bash parser: keep trap-like text out
of quoted initialization data. An absent or unsupported boundary returns nonzero
with a diagnostic naming the source and the required form, leaving the output
empty. Rendering never executes the source; callers must check its status before
running a generated probe.

## Producer and consumer fixture boundaries

Shared's Cargo preflight fixture runs the real release runner against cold,
offline, fetch-failed and tool-failed preparation, proving refusal before version
preparation and retention of its isolated source/index. Consumers keep their
preparation-authority routing, exact package/pin selections and recovery custody.
The tool-version report fixture owns catalog/admission/probe mechanics, including
partial stdout/stderr. Workflow fixtures can substitute that reporter boundary
while checking their own log names, status and later-step refusal.
The native archive fixture owns partial tar/hash failures and preservation of
readable diagnostics plus their checksum. Consumers retain a real archive round
trip for their selected payloads and workflow-level collector failure propagation.

## Consumer flow qualification

Source `scripts/ci/make-adapter-probes.sh` for
`make_probe_target_admission MAKE MAKEFILE DIRECTORY EVENTS TARGET...` and
`make_probe_parallel_dispatch` with the same arguments. Callers prepare reviewed
Makefiles and substituted effects. The first checks each unsafe behavior once;
the second requires observable dispatch under a real pipe jobserver. Exhaustive
flag aliases and hidden assignments stay in `test-consumer-flow-probes.sh`.
The producer-only `make_probe_execution_modes` is no longer exported; consumer
admission checks use `make_probe_target_admission` instead.

`make_probe_lint_order MAKE MAKEFILE DIRECTORY EVENTS TARGET FAILURE_EVENTS
SUCCESS_EVENTS` checks a caller's actual reviewed pipeline under `make -j4`.
Substitute its lint and effect leaves: record ordered lines through
`MAKE_PROBE_EVENTS`, and return `MAKE_PROBE_LINT_STATUS` from the lint stub.
The two expected files hold exact caller-owned event sequences. The probe runs
lint failure (23) and success (0), requires the corresponding Make status, and
compares the entire sequence. The failure sequence should include preparation
and lint but no expensive build/test/package/publication effects. Keep assertions
of the real lint command's packages/features/options local; this probe does not
replace that evidence or execute a real release. Clear inherited Make selections
as for the other disposable consumer probes.

When adopting 0.16.0, update any calls to the removed helper before refreshing
the reviewed snapshot. Keep the consumer's target roster, effect assertions and
parallel jobserver checks. Existing snapshots stay bound to their recorded
source; refresh through the exporter rather than editing vendored helpers.

`fixture_probe_effect SCRIPT RUN PREFIX STATUS BASH MARKER` runs a fixture with
caller-prepared PATH/environment, captures `result.log` and `status.txt`, and
requires exact status, successful cleanup or one retained failure directory and
the supplied marker. `RUN/tmp` must exist. The helper publishes
`fixture_effect_retained` for consumer-owned payload/diagnostic assertions.

`collect-native-diagnostics.sh CHECKOUT EVIDENCE OUTPUT FORMAT-ROOT TOOLS-OUTCOME
HOST-PINS IC-PINS NAME...` archives only the supplied existing top-level files
and writes its SHA-256 before collecting failed tools or formatter logs. The
`OUTPUT.sha256` sidecar contains exactly one lowercase digest and LF, with no
filename. Verify the explicitly selected archive through the checksum owner:

```bash
bash scripts/ci/verify-file-checksum.sh sha256 "$(cat "$archive.sha256")" "$archive"
```

Both `OUTPUT` and `OUTPUT.sha256` must be new paths. Existing checksum entries,
including symlinks, are refused before archiving. Checksum publication uses
noclobber so a file or symlink introduced during archiving cannot be overwritten.

This replaces the filename-bearing sidecar contract; update `shasum -c` callers.
Names cannot traverse directories; the scratch tree is never implicitly selected.
The helper uses the existing tool/formatter owners and returns 0 on success,
the tool collector's nonfatal status on partial collection, or 2 on fatal
admission/archive errors. Consumers retain source/outcome records, the selected
roster, upload policy and complete outer archives including Git recovery state.

Focused coverage is `scripts/ci/test-consumer-flow-probes.sh` and
`scripts/ci/test-native-diagnostics.sh`. The latter owns referenced host/IC/Rust
bundle selection, rejected-store local retention and fatal candidate-archive
failures after readable diagnostics are published. Consumers retain actual
workflow dispatch/status and outer recovery-state checks. No helper is a sandbox
for an unreviewed Makefile, script or selected payload.
## Assertion retention probes

Source `scripts/ci/fixture-retention-probes.sh` for
`fixture_probe_assertion OWNER PROBE_ROOT SOURCE_ROOT NAME
--selected ASSERTION_SOURCE LITERAL_PREFIX BINDINGS`.
Since 0.16.0, assertion selection is mandatory. Replace inferred-assertion calls
with the existing explicit form before refreshing the helper. Consumers retain
the fixture roster, exact assertion selection and contradictory bindings.

Exactly one source line must match the literal prefix after leading whitespace.
The child runs only the owner's initialization through its EXIT trap, followed
by caller bindings and the selected assertion. Bindings are trusted shell source
maintained by the caller; never pass user input. Bodies that build, install or
mutate Git are excluded from execution. Keep contradictory values and product
assertion selection in the consumer.

The probe requires the supported root anchor and EXIT boundary, evidence
retention, status 1, and a receipt proving the intended assertion was reached.
Ignored assertions and earlier setup failures are rejected. The focused owner
suite is `scripts/ci/test-fixture-assertion-probe.sh`.
The owner must contain the literal line `root="${root%/.}"` before a column-one,
single-line `trap ACTION EXIT`, using the same trap convention described under
[consumer fixture retention probes](#consumer-fixture-retention-probes).
Missing or ambiguous assertion selections and unsupported owner layouts report
the source and required form without running a child. A rejected selection clears
any earlier generated script for that probe name; a rejected layout leaves no
partial script content.

## Hosted qualification admission and evidence parents

`qualify-hosted-failure.sh` owns stage/manual-dispatch admission, selected-checkout
comparison and validation of caller catalog/log paths before creating an evidence
parent. Consumers select the five arguments and delegate; they need not repeat
admission or create the parent first. A nonempty missing parent is created only
after admission, then physically anchored so relative paths, aliases and spaces
retain the same scenario identity. Refused inputs create no evidence directories.
The focused owner fixture is `scripts/ci/test-hosted-failure.sh`.

The producer fixture `scripts/ci/test-checker-retention.sh` qualifies retained
release/formatting inputs, logs and Git index after child or assertion failures.
Consumers retain their own status/diagnostic checks without inspecting these
shared checkers' internal directory layout.

IC Metrics' [recovery packaging contribution](https://github.com/dragginzgame/ic-metrics/pull/88)
owns full native recovery packaging under
`scripts/ci/package-native-recovery-evidence.sh` in its repository, including
hidden Git state, inventory replay and archive checksums. Its workflow publishes
separately selected readable diagnostics through the shared sanitized exporter.
The former shared `collect-native-evidence.sh` and its fixture are retired;
remove their snapshot entrypoints when adopting this cut. Full recovery archives
must retain their original contents and failure-preservation contract.

## Controlled hosted-scenario verification

`failure_evidence.py` also exports
`verify_hosted_scenario(members, read, stage, *, scenario_parent, failure_log_root)`.
Call it inside `regular_evidence_archive` with explicit canonical relative archive
prefixes. It independently checks the maintained hosted driver's exact failure
status, preserved input bytes/modes, scenario marker, rejected early download or
late raw/combined logs. It neither extracts archives nor derives expected bytes
from their receipts. Consumers retain source/job/run identity, collection policy,
native tool pins and compact-tool qualification. Negative owner cases exercise
both stages and malformed/missing/ambiguous evidence; consumer collector tests
still qualify the complete upload/download boundary.

## Focused verifier qualification

`bash scripts/ci/test-snapshot-verifier.sh` checks generic snapshot directory
admission, ordinary aliases, resolved manifest parents and corruption of inert
checksum helpers against a controlled three-file export. Distribution tests
retain refresh/source/index obligations; consumers retain their actual exported
manifest and representative payload corruption checks. This Bash 3.2 fixture
requires no Git repository, tool installation or Cargo inputs.

`python3 scripts/ci/test-failure-evidence.py` owns generic downloaded-archive,
compact-tool receipt and hosted-scenario rejection cases. The standard-library
suite runs in Linux CI; it adds no Python prerequisite to native shell consumers.
Consumers retain actual collector integration, source/run identity, caller pin
selection and representative rejection checks through their own verifier.

## Script fixture preparation

`bash scripts/ci/prepare-script-fixture.sh SOURCE EXISTING-FIXTURE ROOT...`
copies explicit reviewed roots and their transitive line-two `Shared companions`
declarations, preserving file modes. It shares the declaration reader with the
snapshot exporter; inspected payloads are never executed. Cycles are deduplicated.
The complete closure and destination parents are admitted before any copying;
unsafe paths, symlink traversal and missing inputs refuse. The fixture must not
contain the source root. Scratch beneath the source is permitted, but the entire
copy plan refuses before effects if an output would overwrite any selected input,
including a hard-linked input reached through a different output path. Distinct
planned outputs must not share a hard link: copying either would change the
other's bytes. Both cases refuse before any selected file is copied.
Existing regular fixture files may be replaced. Callers own an idle disposable
destination and stable reviewed source; copying does not protect against
concurrent mutation. The helper neither creates a snapshot nor proves supplier
custody. Consumers retain product adapters, substitutions and assertions.
Focused coverage is `bash scripts/ci/test-script-fixture.sh`.

