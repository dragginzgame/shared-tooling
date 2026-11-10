# Evidence verification helpers

## Tool-bundle evidence selection

`select-tool-evidence.sh full REPOSITORY DIAGNOSTICS` emits NUL-separated
root/relative-path pairs for host/IC candidates, local Rust evidence and referenced
shared Cargo generations. Both directories must
already exist; diagnostics must be a regular directory. The neutral archiver
continues to own path admission, namespace collision checks and tar creation.

`select-tool-evidence.sh compact REPOSITORY DIAGNOSTICS HOST-VERSIONS IC-PINS IC-TOOLS`
opts into smaller successful-installation evidence. For each managed relative
active link independently, it runs the existing installer in offline `--check`
mode against a retained copy of the caller's pins. Host checking includes jq,
yq, ripgrep and cloc. Partial, missing, unknown or failed selections stay full;
unselected and failed candidates stay full even when the active set passes.
A changed selection, bundle directory identity or caller pin file refuses
compaction. This is a fresh observation, not authority derived from an earlier
successful installation; stop concurrent toolset mutation during collection.

`IC-TOOLS` is one quoted, space-separated list of requested executable names.
An empty list retains full IC bundles; it never infers the caller's intent from
an installed receipt. A mismatched selection also retains full evidence.
Successful checks retain caller pin bytes, command output and the exact selected
bundle path. IC checks also retain `caller-tools`, `tools`, `pins.tsv`, `host` and `files.sha256`; host
sets have no equivalent bundle receipt, so caller configuration and check evidence
remain explicit. Tiny tool fixtures can grow because diagnostic metadata exceeds
the omitted payload. Archive size and collection time depend on the actual sets.
For shared host/IC storage, the selector retains local references and explicitly
selects their admitted physical bundles under the configured store. It never
scans unrelated store entries or follows arbitrary links. Use the same
`TOKO_TOOLING_STORE` setting as setup; preserved local bundles remain eligible
for full evidence retention, even though installers no longer admit them as active.
The selector requires Perl core modules and the declared host/IC check companions;
it never installs or downloads tools. Invalid selections refuse before dispatch.

The common failure action defaults to full retention. Set
upstream store configuration consistently with setup. If store admission fails,
the selector returns nonzero; its partial output is diagnostic data, not authority
to select physical payloads. The action uses `collect-tool-evidence.sh` to retain
local references without following them, local logs/builds and the selection
diagnostic/status, sets
`collection-complete=false`, uploads that partial evidence, then fails its final
completeness step. A rejected store never authorizes traversal or repair, and
partial evidence is not reported as complete retention. Set
`compact-successful-tools: 'true'` to opt in; `host-versions` and `ic-pins` select
absolute caller pin files, defaulting to the repository's common configuration.
Set `ic-tools` to the same space-separated selection as setup/check when
compacting IC bundles. Omitting it retains their full payloads.
Its native CI control uploads/downloads successful-set diagnostics alongside a
failed candidate, separately from the existing full-failure control. Native
acceptance requires matching executed jobs; a configured control is not evidence
of a successful hosted transport. The selector owns the full physical
`.tools/rust` tree plus its admitted shared generations and original build/log
evidence, independently of host/IC compaction. Custom callers must not also add
the same local tree to the archive. Links are archived without following targets.
Consumers adopt the selector only from a reviewed committed snapshot, rather
than recreating its classifier locally. For collection, prefer the existing
[orchestrator](#tool-evidence-collection-orchestration) over a local selector/read/
archive loop; keep product log selection and upload policy in the consumer.

## Runner disk capacity

```bash
bash scripts/ci/check-runner-disk-space.sh \
  --path "$PWD" --min-free-mib 4096 --label 'before tests'
bash scripts/ci/check-runner-disk-space.sh \
  --path "$PWD" --min-free-mib 0 --label 'failure diagnostics' \
  --diagnostic-path "$PWD/target" --diagnostic-path "$PWD/.tools"
```

The caller selects one existing file or directory on the filesystem to check,
an inclusive minimum in MiB and an optional label. Zero reports capacity without
a positive reserve requirement; negative available capacity still fails. The
path can be absolute or relative to the caller, including spaces and literal
glob characters. Values must be single-line without tabs. The minimum is a
canonical non-negative decimal integer (no leading zeros), at most 18 digits
so integer arithmetic stays bounded on supported hosts.

The read-only Bash 3.2 helper requires system `df` and `awk`; it requests the
C locale and POSIX KiB output with `df -Pk`. It admits one filesystem record
with a KiB header and numeric capacity, rejects failed or malformed observations,
and compares whole MiB rounded down. Available KiB magnitudes over 18 digits
are refused rather than overflowing. Exit statuses are **0** for sufficient
space, **1** for insufficient space and **2** for invalid arguments or an
unavailable/malformed capacity observation. The printed summary is diagnostic
text; callers use the exit status for gating. This samples capacity without
reserving space or proving that a later build will fit.

Each repeated `--diagnostic-path` explicitly requests a recursive `du -sk`
total in KiB, on success or insufficient capacity. This can be expensive on
large trees. Missing paths and failed `du` commands warn and leave the capacity
result unchanged; they are not successful usage measurements. Without these
arguments no `du` scan runs. The helper has no built-in paths, SDK deletion list,
installation, artifact cleanup or filesystem mutation.

Adopt `scripts/ci/check-runner-disk-space.sh` and this guide through the reviewed
snapshot workflow; there are no shared-script dependencies. The upstream
`test-runner-disk-space.sh` covers real host observation plus controlled failure
and threshold cases, and runs in the portable Linux/macOS CI matrix. Consumers
own step ordering, thresholds, filesystem selection, diagnostic paths and their
native qualification. When replacing Canic's local helper, move its path lists
to a consumer-owned caller and express summary-only checks by omitting diagnostic
paths. Retire the duplicated body after qualifying those callers. Any disposable
runner-image cleanup remains a separate, explicitly scoped consumer operation.

## Downloaded failure-evidence verification

The optional host-side `failure_evidence.py` provides non-extracting archive
indexing/regular reads and independent compact Shared tool receipt verification.
`verify_compact_tools` selects a nonempty set of `host`, `ic`, or both from the
caller's `tool_pins` keys. Every selected bundle requires its caller pins, fresh
check log and managed compact selection; unknown or empty selections refuse.
IC selection additionally requires matching installer pins, native host and
checksum receipts. Unselected bundles remain diagnostics and are not qualified.
Consumers keep source/job/run identity and product assertions. The Python helper
is selected only by download-verification consumers, not native shell setup.
Run `python3 scripts/ci/test-failure-evidence.py` on the download-verification
host; the portable shell suite does not introduce a Python prerequisite.

`qualify-hosted-failure.sh early|late CONSUMER EVIDENCE_PARENT HOST_CATALOG
FAILURE_LOG_ROOT` requires explicit workflow dispatch and matching checkout
identity. It creates a new isolated scenario/store, drives the canonical installer
or logger, checks preserved inputs and deliberately returns the verified original
failure status. Callers own evidence selection, upload/download and supported
host gates; the command activates no workflow and changes no active tool selection.

### Fixture allocation

Source `scripts/ci/fixture-lifecycle.sh` and call `fixture_create TEMPLATE` to
allocate one directory and return its absolute physical path before changing cwd.
The caller selects the template/prefix and retains its EXIT trap, completion flag
and evidence policy. Relative templates, ordinary spaces and directory aliases
are supported; CDPATH cannot redirect anchoring or add output. Empty templates,
leading options and CR/LF in templates are rejected before allocation. A resolved
physical path containing CR/LF is refused, retaining the allocation for inspection.
Allocation errors preserve their status; normalization failures retain and report
the created directory without attempting cleanup from an unanchored path.

For example, after sourcing the helper:

```bash
fixture="$(fixture_create "${TMPDIR:-/tmp}/consumer-check.XXXXXX")"
fixture_complete=false
trap 'fixture_finish "$?" "$fixture" "Consumer fixture retained"' EXIT
# Run the caller-owned checks, then mark successful completion.
fixture_complete=true
```

The allocation helper is additive and does not change existing cleanup callers.
Its focused fixture is `scripts/ci/test-fixture-allocation.sh`; selecting that
fixture through the snapshot exporter includes the lifecycle helper.

### Completion admission without cleanup

`fixture_completion_status STATUS COMPLETE` returns the original nonzero status,
or returns 1 for zero-status execution unless COMPLETE is `true`. STATUS must be
a canonical decimal shell exit status from 0 through 255; invalid arguments
return 2 rather than wrapping an invalid status to success. The helper performs
no cleanup, reporting or process exit. Capture refusal in an explicit conditional
under errexit. `fixture_finish` uses this admission before its existing cleanup
policy; qualification runners can instead retain all success and failure evidence.

## Tool evidence collection orchestration

`collect-tool-evidence.sh ARCHIVE REPOSITORY DIAGNOSTICS full|compact HOST IC [IC-TOOLS for compact]
[ROOT PATH]...` composes the selector and neutral archiver. Callers keep their
log roots, run identity, qualified catalogs, upload and retention policy.
Full retention takes no tool-list argument; compact mode requires it even when
empty so a log-root argument cannot accidentally become the requested tool set.
Status 0 means complete, 1 means safe partial evidence was archived, and 2 means
collection/archive failed. A fresh `selection-status` receipt retains the exact
selector status, `archive-status` records an attempted archive failure, and
`selections.nul` retains the original selector output. Failed output
is never used to admit physical payloads. Instead, local Rust evidence and
host/IC references are retained without following redirected roots or links.
Diagnostics remain in the partial archive; completeness is not inferred from
successful archiving. Stdout contains the created archive path only.

Callers still admit their own selected paths. If a parent such as `target` or
`.tools` is a symlink, select the parent link itself instead of its children,
retain a diagnostic and report incomplete collection. This keeps independent
logs eligible for archiving without traversing the redirected parent. The
orchestrator does not repair an invalid caller selection or infer product paths.
Keep consumer tests for these selections, original failures, completeness and
upload/download bindings; Shared owns the generic selector/archiver regression
matrix.

## Workflow run extraction

`scripts/ci/extract-workflow-step.sh STEPS_JSON STEP_ID` emits the selected run
body from one JSON array of workflow steps. It requires exactly one matching
object with a nonblank string `run` and no `uses`. Missing/duplicate selections,
invalid shapes and malformed or multiple JSON documents refuse without emitting
a script. It preserves jq failures and requires prepared jq on PATH. Callers
own YAML-to-JSON selection, ordering/condition assertions and actual execution;
extraction grants no authority to execute unreviewed workflow code. Focused
coverage is `scripts/ci/test-workflow-step.sh`.

