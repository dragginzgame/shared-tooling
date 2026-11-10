# Local developer setup
<!-- Shared companions: .github/actions/cache-tool-downloads/action.yml scripts/ci/report-tool-versions.sh docs/tools/tool-store-maintenance.md docs/tools/tool-catalog-bindings.md docs/validation/verification-helpers.md docs/tools/ic-tools.md docs/tools/supported-hosts.md docs/adoption/make-interface.md docs/adoption/consuming-snapshots.md docs/releases/releases.md TOKO-TOOLING.md rules/cargo-dependencies.md rules/git-hooks.md docs/tools/tool-inventory.md -->

## Related guides

- [Required tool inventory](../tools/tool-inventory.md#required-tool-inventory)
- [Catalog selection](../tools/tool-inventory.md#catalog-selection)
- [Pinned local tool sets](../tools/tool-inventory.md#pinned-local-tool-sets)
- [Rust development tools](../tools/tool-inventory.md#rust-development-tools)
- [Cargo installation assessment](../tools/tool-inventory.md#cargo-installation-assessment)
- [Observed common tool versions](../tools/tool-inventory.md#observed-common-tool-versions)


## Tool selection and diagnostics

`make tools-report` runs all existing host, common Rust and selected local check
targets, retaining individual failures through the shared validation logger.
It returns nonzero if any check fails and never calls install targets. It is an
optional diagnostic, not release admission: `make tools-check` keeps its existing
fail-fast behavior. Local check targets must retain their offline/no-install
contract. The report uses the consumer root even with a nested shared snapshot.

The host, IC and Rust installers accept `--describe` instead of installation,
`--check` or `--preflight`. They print JSON after parsing the same selection
used by normal operation, without creating stores, probing installed binaries,
invoking Cargo/Rustup or downloading. For example:

```bash
bash scripts/dev/install-rust-tools.sh --consumer "$PWD" --describe
bash scripts/dev/install-ic-tools.sh --consumer "$PWD" --tool wasm-opt --describe
```

Catalog selections include absolute consumer/catalog/source paths, the installer
source fingerprint and selected version/digest records. Explicit Cargo recipes
instead report package/version, binary or example, profile, features and lockfile.
Lock-selected recipes still need prepared yq/jq to read the supplied lockfile.
No output claims installed-tool integrity or registry availability. For catalog
agreement, capture the JSON as a [caller observation](../tools/tool-catalog-bindings.md);
retain the actual command and its source context. Product pins remain local.

## Common setup

Prepare the declared compiler and the consumer's
[native/system prerequisites](#native-bootstrap-before-cargo-tools) first. Then,
from the checkout root, prepare the common executables explicitly:

```bash
make install-tools
make tools-check
export PATH="$PWD/.tools/host/bin:$PWD/.tools/rust/common/bin:$PATH"
```

Prepare the declared Rust/Cargo toolchain and native build prerequisites first,
even when the repository has no Rust packages. The Makefile uses local tool
paths automatically. Interactive shells need the
export above; setup does not edit shell profiles. Installation downloads tools;
tool checks are offline and never install missing executables. Preparing missing
workspace dependency sources during authorized development/validation follows
the [locked Cargo fetch policy](../../rules/cargo-dependencies.md#cargo-network-policy).
Before tool downloads,
`install-tools` uses the Rust installer to admit its selected
platform/pins and probe the consumer's selected `rustc` and `cargo`. This
read-only `--preflight` call creates no tool/build directories and disables
Rustup auto-installation; missing or unavailable toolchains require explicit
bootstrap. This is not a compiler/linker qualification or a toolchain upgrade.
Setup then runs host and Rust installation in that order, followed by declared product tools;
`tools-check` checks the same sets in order. Each stops at the first failure.
Sets activate independently: a later failure preserves earlier completed sets.

### Native bootstrap before Cargo tools

System/native setup that changes Cargo build inputs must finish **before**
`make install-tools`, `make install-rust-tools` or selected Cargo executable
setup, including the release metadata editor. This includes compiler/linker and
SDK setup and the consumer's system packages. The
[standard build identity](../tools/tool-inventory.md#standard-cargo-tool-build-environment) includes native
compiler/linker digests and build-relevant Linux packages or macOS/Xcode/SDK identity;
changing those after Cargo setup correctly invalidates the earlier selection.

Keep an explicit sequence in the consumer's existing setup/release-preparation
adapter:

1. Install required system/native prerequisites and prepare the selected Rust
   toolchain; admit those prerequisites with the consumer's read-only checker.
2. Prepare common Shared tools and selected Cargo executables, including the
   release editor when used.
3. Prepare browser and other product dependencies that leave the compiler/native
   environment unchanged. Any step that changes fingerprinted build inputs
   belongs in the first phase instead.
4. Run offline tool admission and all other prerequisite checks needed by the
   actual release gate, then dispatch validation.

OS package lists, supported-host setup and local names such as
`install-native-tools` / `native-tools-check` remain consumer-owned. The ordered
`LOCAL_TOOL_INSTALL_TARGETS` list runs **after** the common host/Cargo sets, so it
is too late for native bootstrap. Do not add unordered prerequisites to shared
aggregates, replace their recipes or invent another tool catalog. Use the
[consumer adapter example](make-interface.md#native-bootstrap-adapter).

If system packages, a compiler or an SDK change after preparation and offline
admission reports “No prepared Cargo tool selection for the current compiler/build
inputs”, finish native setup and explicitly rerun the affected common/selected
Cargo setup before checking again. Preserve selected deliverables and required diagnostic
evidence; do not edit receipts, bypass fingerprints or make a checker install
packages. `tools-check` admits only its declared common/local tool sets, not every
native or product prerequisite of a release. The consumer must check those too.

## Toko Tooling's integration editor

Toko Tooling's own `make install-tools` also prepares the released IC Build
editor used by its integration fixtures; `make tools-check` admits that selection
offline. The standalone targets are `make install-release-editor` and
`make release-editor-check`. The latter prints the verified absolute executable
path and never installs it. Its version, profile and fixture byte allowance are
selected in Shared's root Makefile.

The selection is IC Build 0.73.0 with the explicit `cli` feature. Portable CI
includes endpoint-only release-group preparation, rollback and delivery/resume
qualification alongside the coordinated-workspace fixture. An older prepared
editor cannot qualify that contract; rerun `make install-release-editor` after
adopting this selection, then use `make release-editor-check` for offline admission.

`make test-portable` checks that prepared selection before starting any fixtures
and supplies its path and allowance to the suite. CI uses these same setup and
test targets. The cache key includes the owning Makefile, so a changed selection
cannot keep reusing a cache key for an older tool set. Cache presence never
replaces installed-byte admission.

Direct suite and prerequisite-helper calls must also supply
`CARGO_RELEASE_METADATA_EDITOR` (an absolute executable file) and
`CARGO_RELEASE_METADATA_MAX_BYTES` (a positive decimal integer). The prerequisite
helper checks those inputs before fixture allocation without executing the
editor. Prefer `make test-portable`, which supplies the offline-admitted values.

This editor is a Shared-local requirement, not an addition to every consumer's
common Cargo tools. Consumer release adapters retain the explicit selections in
[Cargo candidate rendering](../releases/releases.md#cargo-release-candidate-rendering).

Shared's standard release commands prepare and check these tools after fresh
source/changelog admission, before validation. Reconciliation of saved preparation
and standalone `release-preflight` only check prepared tools; neither installs
against interrupted metadata. PR delivery prepares the exact merged checkout's
tools before its fresh validation. Ordinary metadata preparation and late checks
do not install tools.

## Shared executable storage

Toko Tooling owns storage for the common executable sets. Host and IC setup
reuse verified bundles in a per-user store across checkouts with the same host
and pins. Each repository retains its reviewed snapshot and command
selection; changing one repository's selection must not change another's.
Providing every common command does not require duplicating its binary in every
checkout. Consumers must adopt the canonical implementation through reviewed
snapshots rather than create independent stores or new bespoke `.tools`
installers. Reviewed script snapshots remain repository-local.

The default store is `${XDG_DATA_HOME:-$HOME/.local/share}/toko-tooling/tools`.
Set `TOKO_TOOLING_STORE` to an absolute directory to choose another location;
use the same setting for setup, checks and evidence collection. Fixtures use
isolated temporary stores. Store directories must be owned by the current user,
physical, and not writable by other users. Existing ancestor aliases such as
macOS `/var` are resolved; managed directories and payloads cannot redirect
outside their admitted locations. CR/LF paths are refused.

The existing `.tools/host/bin` and `.tools/ic/bin` command paths remain, backed
by lightweight local references to exact shared bundle generations. No new host
or IC payload is stored inside the checkout. A complete matching bundle is
verified again before reuse without downloads. Changed pins or platforms select
a different store entry; updating its reusable selection never retargets other
checkouts. Locks protect setup across repositories as well as local activation.
Offline checks never install or repair tools. Corrupt bundles are refused;
explicit setup can prepare a fresh generation without overwriting retained ones.

Adoption requires refreshed installers, `scripts/dev/tool-store.sh`, and the
evidence selector, followed by `make install-host-tools`, `make install-ic-tools`
and their offline checks. Older physical checkout-local bundles are preserved
but no longer admitted as active installations. Do not manually relocate them
or delete them during adoption. Failed attempts and earlier selections remain
referenced from the originating checkout for evidence collection. The collector
archives those admitted shared bundles, not the entire machine's store. Deleting
a checkout or a reference does not reclaim its stored payload; cleanup remains
an explicitly authorized separate operation.

Cargo tools also live in the shared store. Local `.tools/rust` contains selections
and references; successful compiler scratch is discarded after byte admission.
Current declared requirements across checkouts protect their selections; obsolete
managed Rust generations use [previewed reclamation](../tools/tool-store-maintenance.md).
Legacy physical installations require explicit migration. Reuse requires the exact
compiler, native environment, published
source/lock, target and profile under the standard environment described below.
The store's `cargo-cache` holds Cargo-managed registry sources separately from
retained installation generations; preserve it for offline admission and reuse.

## Diagnosing a missing command

Installing tools in Toko Tooling does not select them in another checkout.
Run setup in each checkout; matching host/IC bundles reuse the shared store.
From the affected repository's root, compare:

```bash
.tools/host/bin/cloc --version
command -v cloc
```

If the first command works but the second is missing or points elsewhere, select
this checkout's tools in the current terminal:

```bash
export PATH="$PWD/.tools/host/bin:$PWD/.tools/rust/common/bin:$PATH"
```

Select the paths again when switching repositories; do not permanently select a
sibling checkout's tool directory in a shell profile. Repository Make targets
must work without this manual export. If the local executable is absent, run
`make install-host-tools` and `make host-tools-check` in that repository. If its
setup still omits cloc, adopt the reviewed shared installer, pins and complete
Make/CI selection first. A PATH change cannot supply an uninstalled executable.
Installing `cloc` also does not create a `make cloc` target: Rust LOC report
adoption needs the shared report script and the Make include shown in the
[consumer adoption guide](consuming-snapshots.md#local-ic-tool-adoption).

## Bootstrap prerequisites

Use the host package manager for the shell, Git, GNU Make, curl, archive tools,
Perl and ordinary utilities. For Linux Mint/Ubuntu:

```bash
sudo apt-get update
sudo apt-get install -y bash git make curl ca-certificates tar gzip xz-utils zip unzip perl
```

On macOS, with Xcode Command Line Tools and Homebrew already installed:

```bash
brew install make curl xz
```

macOS supplies Bash, Git (through Command Line Tools), tar, gzip, Perl and shasum.
Homebrew GNU Make is available as `gmake`; use it where the system Make does not
meet a consumer's requirements. These system packages follow the host's package
manager updates; they are not claimed to be checksum-pinned shared binaries.
Shared setup never invokes sudo or installs a package manager implicitly.
The pinned local host set supplies ripgrep and cloc; neither is a bootstrap dependency.

### Toko Tooling's own compiler

Shared pins its development and Cargo-tool-build compiler in its own root
`rust-toolchain.toml`. With Rustup and native build prerequisites available,
prepare the host parser tools, then the selected compiler:

```bash
make install-host-tools
export PATH="$PWD/.tools/host/bin:$PATH"
bash scripts/dev/prepare-rust-toolchain.sh --toolchain-file rust-toolchain.toml
```

Then run `make install-tools` and `make tools-check`. CI prepares this same file
before computing Cargo build-cache identity or qualifying registry builds. The
runtime scanner uses that same prepared compiler; it needs no older-toolchain
installation. Consumers adopt the Rust 1.99.1 support policy explicitly in their
manifests, compiler selection and validation; exporting a snapshot alone does
not edit those files or qualify their builds.
After changing the pin or the shared build-helper policy, rerun explicit setup;
current requirements and required evidence remain protected under the
[retention policy](../tools/tool-store-maintenance.md).

### Portable suite prerequisites

Every repository prepares its declared Rust/Cargo toolchain and native build
prerequisites before the common tool setup. Rust development and Toko Tooling's
portable fixtures also need rustfmt. After that bootstrap, use the common setup
and select its paths before invoking scripts directly:

```bash
make install-tools
make tools-check
export PATH="$PWD/.tools/host/bin:$PWD/.tools/rust/common/bin:$PATH"
```

Before starting portable fixtures, `test-portable-tools.sh` checks the required
commands on PATH (including cloc, shasum, jq, Mike Farah yq and ripgrep), the editor
inputs described [above](#toko-toolings-integration-editor), and reuses
the offline formatter prerequisite check. With those inputs supplied, run this
admission independently with `bash scripts/ci/check-portable-prerequisites.sh`.
It reports missing commands together and points back here; it never installs
tools or replaces the individual
fixtures' version, feature and behavior checks. Standard Unix utilities from the
bootstrap environment are still required. This is Toko Tooling's own suite
setup, not a new prerequisite gate for every consumer.
The download retry fixture starts a temporary IPv4 loopback HTTP listener and
uses real curl with test-only transport substitution. It needs permission to bind
`127.0.0.1`, but contacts no public server and adds no TLS/certificate prerequisite.

ShellCheck, actionlint and Gitleaks use the existing explicit CI installers and
pins; GitHub maintenance needs an installed, authenticated `gh`. Consumer-owned
Node/Rust toolchains, SDKs and product dependencies remain part of that repo's
declared setup. See the [complete script dependency table](../tools/supported-hosts.md#tool-specific-dependencies).

