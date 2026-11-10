# Setup and formatting verification helpers

## PocketIC provisioning and admission

IC Testkit owns server selection, provisioning, offline admission and
compatibility. Shared 0.2.0 removes its former alignment and binary checkers;
consumer callers and snapshot selections move together under the
[PocketIC ownership handoff](ic-tools.md#pocketic-ownership-handoff).
Generic checksum and evidence helpers remain available for their other callers.

## CI binary installers

Use `scripts/ci/install-ci-tool.sh TOOL` for actionlint, shellcheck, gitleaks,
sccache. Always supply `--install-dir`. The first three tools use validated
version/checksum records from the snapshot's `ci/tool-versions.env`, currently
qualified for Linux x86-64. `--catalog FILE` selects a reviewed catalog exception.
Alternatively supply both `--version` and `--sha256` for an explicit tool/platform
exception; these cannot be combined with `--catalog`. Sccache requires explicit
pins. A missing, malformed or unsupported catalog selection refuses before setup.
Prepare YQ through `make install-host-tools` and admit it with
`make host-tools-check`; standalone YQ installation is retired.
Since 0.16.0, installation requires an explicit destination; add the flag before
refreshing callers that used `TOOL_INSTALL_DIR` or the home-directory default.
Missing or empty destinations refuse before host probes, downloads or filesystem
setup. The implementation shares host selection,
HTTPS download, checksum admission, extraction, exact version admission and
publication. Asset names and version-output formats remain explicit per tool.
Staging lives on the destination filesystem; failures retain the candidate and
leave the installed executable intact. Successful installation removes its own
staging files. Publication uses Perl core's exact-path atomic rename: a directory
introduced at the executable destination during setup is refused, and a late
symlink is replaced without following its target. Perl must be available before
setup starts; no tool is downloaded when this prerequisite is missing.
This does not merge repository-local host/IC bundle activation
or change any consumer's explicit pins. The command declares its checksum
verifier, catalog reader and default catalog as snapshot companions.

`host-platform.sh` in `scripts/dev/` observes `uname -s` and `uname -m` and emits
one normalized `Linux|Darwin:x86_64|arm64` identity. It accepts no arguments and
performs no setup. OS and architecture aliases share this owner; a failed
observer propagates its status without publishing an identity. Each installer
still owns its supported asset matrix, including IC's Linux ARM64 refusal.

`tool-catalog-records.pl host|rust|ic|ci CATALOG [TOOL]` emits validated
tab-separated tool, version, host and digest records. Rust records use `all` and
`-` for host and digest. Optional tool selection filters only after the entire
selected group is admitted; an unknown tool refuses without partial output.
CI records normalize asset-specific host spellings to `LINUX_AMD64`.
Canonical stable-version grammar comes from `StableVersion.pm`; CLOC retains
its two-component version allowance. Catalog admission adds no release u64 bound.
Callers select records directly; the former raw `values` projection is removed.
The IC admission backend, `ic-tool-pins.awk`, always emits the complete validated
matrix. It has no version-only or validation-only output mode. Select individual
tools through `tool-catalog-records.pl ic CATALOG TOOL` after matrix admission.
For example, obtain the formatter pin without recreating catalog variables:

```bash
perl scripts/ci/tool-catalog-records.pl rust ci/tool-versions.env CARGO_SORT
```

`install-ci-tool.sh sccache` uses the same explicit version, SHA-256 and installation
directory arguments. Its reviewed asset scope is Linux x86-64, using the
`sccache-vVERSION-x86_64-unknown-linux-musl.tar.gz` release asset. Other hosts
are rejected before installation or download; consumers retain their explicit
Cargo/native setup on those hosts. Extending binary asset selection requires
reviewed pins and corresponding qualification, not guessed download names.
The installer prints the selected executable path; callers own `GITHUB_PATH`,
`RUSTC_WRAPPER`, cache configuration and any server startup. Include
`install-ci-tool.sh` and `verify-file-checksum.sh` in the same snapshot.

CI, host and IC asset downloads use `tool_store_download` from
`scripts/dev/tool-store.sh`: HTTPS-only transport, TLS 1.2, a 15-second connection
limit, a 300-second attempt limit and three transient retries within a 60-second
retry window. An in-flight attempt retains its own limit. Each installer owns
checksum admission, staging and publication; CI failures retain their candidates.

## Compiler-cache launcher adoption

`scripts/ci/run-sccache.sh` owns stable, repository-scoped temporary files and
socket selection for a cache server that outlives one validation invocation.
It forwards the exact arguments, diagnostics and exit status to `SCCACHE_BIN`.
Set that variable to an absolute executable file. Unset, empty, bare-name,
relative, directory and unavailable selections fail before runtime creation;
there is no PATH fallback. The selected file may be a caller-owned adapter.
The launcher does not select Cargo's compiler wrapper or retry compiler failures.
It refuses a symlinked repository `.tmp`, selected runtime root or `tmp` child
before creating runtime directories. An explicit `SCCACHE_RUNTIME_DIR` owns its
chosen location; its ancestors follow normal filesystem resolution (including
system `/tmp` aliases on macOS). Choose trusted parents and do not mutate those
paths concurrently with launch. This is admission ordering, not a race-proof
filesystem sandbox.

Consumers with an existing cache-failure adapter can select that executable as
`SCCACHE_BIN`, keeping the actual cache executable under a separate local
selection. The shared launcher establishes the runtime before executing the
adapter, which inherits `TMPDIR` and `SCCACHE_SERVER_UDS`. The adapter must not
call the launcher recursively or reselect/delete its stable runtime directory.
Keep fallback classification and diagnostic policy local until independently
qualified for the selected cache version; text resembling a cache diagnostic
does not by itself establish that a compiler has not already run.

During adoption, replace duplicated directory/socket setup and retain focused
checks for exact argv, compiler failure without replay, cache-management calls,
adapter failure status and runtime survival after invocation scratch cleanup.
Snapshot adoption does not change consumer toolchain or compiler-wrapper policy.

## Snapshot adoption

The additional lockfile transformer and formatting adoption checker below are
optional snapshot files too. They retain consumer policy at their input boundary;
do not vendor their upstream fixtures as product tests.

After these files have a reviewed committed revision, adopt each desired helper
and this guide through the [snapshot workflow](../adoption/consuming-snapshots.md). The
documentation, release-command and registry helpers have no dependencies on
other shared scripts. Their upstream fixtures
are `test-documentation-links.pl`, `test-release-commands.sh` and
`test-crates-io-version.sh`; the release fixture additionally uses the upstream
Makefile and is not a consumer's product test.

Replace only the corresponding local mechanical blocks. IcyDB retains its
persisted-inventory and version-example checks, release receipts/cache checks
and publication waiting. Canic and IC Timers can replace their duplicated
release entry-point smoke tests; IC Metrics keeps its publication checks.
Registry callers must explicitly handle all three statuses before deleting
their local observation implementation. Run each consumer's focused checks and
native host qualification, and distinguish that evidence from upstream fixtures.

## Formatter prerequisites

```bash
source ci/tool-versions.env
bash scripts/ci/check-format-tools.sh "$TOKO_TOOLING_CARGO_SORT_VERSION"
# An independent workspace can select its prepared toolchain explicitly:
RUSTUP_TOOLCHAIN="$VALIDATION_TOOLCHAIN" \
  bash scripts/ci/check-format-tools.sh "$TOKO_TOOLING_CARGO_SORT_VERSION" /path/to/cargo
```

The helper requires an explicit exact cargo-sort version and accepts an optional
Cargo executable path, defaulting to `cargo` on PATH. It requires successful
`sort --version` with the exact expected output and successful `fmt --version`.
It forces Cargo offline and disables rustup automatic installation for these
probes; it never installs tools, formats files, resolves dependencies or builds.
A command that prints the expected version but exits unsuccessfully is rejected.
An executable path is one argument, not a shell command; use `RUSTUP_TOOLCHAIN`
for a selected rustup toolchain instead of embedding `cargo +toolchain` in it.

Vendor this file in the reviewed snapshot and call it from a prerequisite shared
by `fmt` and `fmt-check`. Keep the pin in the consumer's reviewed versions file;
setup and CI must use that same value. Retire the replaced local version checks.
Consumers retain workspace discovery, nested manifests, rustfmt configuration,
frontend adapters and additional formatting steps. Probe every independently
selected toolchain. This check establishes availability, not that formatting
covers the right files; the adoption checker below supplies that separate proof.

## Frontend formatting

`scripts/dev/format-frontend.sh --write|--check RELATIVE-DIRECTORY` formats the
selected index-export files during a hook write, or tracked files in the scope
for explicit invocation. Set `PRETTIER_BIN` to a prepared absolute executable
and `PRETTIER_VERSION` to its exact lockfile version. Setup stays explicit.

The pinned Prettier owns language recognition through `--ignore-unknown`;
Toko Tooling does not maintain an extension allowlist. Consumer configuration
and `.prettierignore` own formatting exclusions. The adapter retains scope and
symlink checks, NUL-delimited selection and exact-version admission. Upgrading
to this contract can include previously skipped formats such as `.mjs` and
`.vue`; review exclusions before adopting it. Unknown file types remain untouched.

## Consumer formatting-hook adoption

Formatting-hook qualification and Rust source selection default to the selected
consumer's `target/tmp`; `TMPDIR` overrides that location. The presentation-only
`run-formatting.sh` wrapper uses its caller's working directory as the consumer
root and defaults to `target/tmp`, with `RUNNER_TEMP` then `TMPDIR` taking
precedence. Overrides may be relative and are resolved before changing directory.
No helper exports a global temporary-directory default.

On failure, the checker replays its existing baseline and per-checkout hook logs
to stderr before reporting the retained fixture directory. Diagnostic replay is
best effort and preserves the original failure status; successful checks remove
their scratch directory. Consumers need no outer fixture for log replay or custody.
Nested formatter logs stay inside that fixture, including expected rejection
logs; inherited `RUNNER_TEMP` evidence remains untouched.

```sh
bash scripts/ci/check-formatting-hooks.sh "$PWD" crates/example/src/lib.rs \
  crates/example/Cargo.toml /tmp/example-unsorted.toml ci/tool-versions.env
```

The first two relative paths select an existing Rust module and Cargo manifest.
The fourth argument is a consumer-prepared unsorted copy of that manifest: change
only dependency ordering, so the real formatter restores the selected sorted
bytes exactly. For a consumer with no dependency tables, pass the explicit
`--no-dependency-tables` argument instead. This caller-owned assertion omits only
the dependency-order perturbation; the real `fmt-check` still runs, and manifest
preservation and partial-staging rejection remain checked. The helper does not
infer or parse dependency absence, and that mode supplies no sorting-perturbation
proof. Never add synthetic dependencies to qualify a dependency-free consumer.
Remaining relative arguments explicitly overlay additional current
files needed by the consumer's formatter (other manifests, source, lockfiles,
configuration or Make includes). The checker exports existing HEAD, overlays
the named inputs plus the Makefile, hook, installer and Make execution check,
and stages them only in temporary repositories. It never creates commits or
activates the real checkout's hook.
Pass `--rust-sources` immediately after the fourth argument to discover current
Git-maintained Rust files and Cargo manifests, including unignored additions.
The checker applies their edits/additions and tracked deletions only to its
disposable checkout. Keep selected perturbation inputs and additional Make,
configuration or tooling files explicit. This option avoids maintaining a
second per-module source roster; it does not change formatter or workspace policy.
The companion `scripts/ci/select-rust-formatting-sources.sh ROOT` publishes a
complete NUL-separated relative-path selection only after Git and path admission
succeed. It rejects symlinks, nonregular current files and physical escapes;
tracked missing paths represent deletions. Ignored untracked files and unrelated
extensions are omitted. Neither command stages or edits the real source checkout.
README.md must exist as an unrelated-edit preservation input. Tracked files must
be regular files, matching the shared hook's support contract.
This includes unrelated historical symlinks: the checker rejects them before
running the formatter. A consumer with an approved hook adapter that exports
only regular entries must keep its own qualification for that model, including
selected-symlink refusal and unrelated-evidence preservation. Passing the shared
fixture cannot qualify that adapter. Do not remove historical links merely to
make this checker pass. See [#33](https://github.com/dragginzgame/toko-tooling/issues/33).

Review the consumer's Makefile and formatting commands before execution. This
helper executes those commands; it is not a sandbox for arbitrary Make code.
Prerequisites must already be installed. The selected consumer's `.tools/host/bin`
and `.tools/rust/common/bin` precede inherited PATH for executable lookup;
products requiring IC formatters explicitly publish their prepared IC PATH.
Formatter inputs and configuration still come from the disposable checkout.
Cargo is forced offline, rustup auto
installation is disabled, and inherited Git/Make/logger checkout selections are
cleared. The baseline must pass its real `fmt-check` before perturbation.

Checks cover selected Rust refresh and manifest sorting, idempotence, partial
Rust/manifest staging, malformed Rust formatter failure, preservation of selected
lockfiles and unrelated edits, and installer alias/conflict handling. Failed
exports and logs are retained; successful helper-owned scratch is removed.
Success also requires the checker to reach its final completion point. Premature
exits, including Bash 3.2 expansion failures that report zero, return failure and
retain evidence; existing nonzero statuses are preserved.
Consumer-specific formatter stages and runtime obligations still need their local
tests. Toko Tooling exercises this helper against its real nested Cargo fixture;
that does not qualify a consumer's formatter or establish native macOS adoption.

## Formatter evidence selection

Source `scripts/ci/formatting-evidence.sh`, then call
`select_formatting_evidence ABSOLUTE_LOG_ROOT`. It fills `formatting_evidence`
with root/relative-path pairs for the formatter's retained `formatting.*` files
and final symlinks, including dangling links. Directory/FIFO matches are omitted;
links are archived without following their targets. Missing or relative roots
return 2 and clear the selection. An empty existing root succeeds with no pairs.
Callers pass the array to the evidence archiver and retain archive layout, source
identity, Git custody and upload policy. This helper never removes logs.

The exportable `test-release-source.sh` owns generic source-admission cases in
a minimal disposable Git repository, including exact working-file and index
preservation after literal metadata admission and rename-source refusal.
It also qualifies refusal of plausible output from failed Git observations and
invalid selections before Git dispatch, preserving files and removing scratch.
Consumers retain tests of their actual allowlist, gate ordering and release
adapter. Retention probes use
`retained-completed` for fixtures that intentionally retain successful evidence;
ordinary `completed` still requires successful scratch removal.

## Native host admission

Run `bash scripts/ci/check-native-host.sh Linux x86_64` or
`bash scripts/ci/check-native-host.sh Darwin arm64 15` before native setup.
The caller selects the exact architecture and, on macOS, the explicit major.
The helper observes `uname` and `sw_vers`; it makes no PATH or tool changes.
Status 0 means a match, 1 means mismatch/malformed version, and 2 means invalid
selection. Failed observations preserve the observer's nonzero status, including
when it prints plausible output. Linux does not call `sw_vers`. Consumers retain
their matrices, workflow ordering, PATH changes and native-host qualification.
The portable fixture substitutes observations; it does not qualify macOS.

## Current Rust formatting inputs

Pass `--rust-sources` after the formatting checker's fourth positional argument
to use `scripts/ci/select-rust-formatting-sources.sh`. The canonical selector
includes current maintained Rust/Cargo inputs and tracked deletions, publishing
its complete NUL-separated result only after Git/path admission. Only disposable
hook checkouts are updated. Consumers retain chosen perturbations and additional
non-Rust tooling/lock/configuration overlays. Source and checker bytes match the
delivered Shared contribution; focused coverage is
`scripts/ci/test-rust-formatting-sources.sh`.

