# Shared Tooling

The authoritative source of mandatory common engineering rules, development
tools, and CI building blocks for all `dragginzgame` repositories.

The repository keeps shared behavior in one place without making individual
projects copy large scripts or encode repository-specific assumptions. Tools
should be deterministic, explicit about their dependencies, and safe to run
from any supported checkout. Each consumer keeps its product architecture,
validation gates, release metadata and deployment identities in a local overlay.
Every repository provides the same three release commands and workflow under
the [release contract](docs/releases.md), which includes a Makefile example.
Differences from the common baseline require maintainer-approved exceptions.

`make version` reads the current local version from [`VERSION`](VERSION).
The top undated changelog entry describes the next proposed release. Standard
release preparation updates both files; Git tags establish published release
identity independently.

## Shared principles

The [`docs/principles/`](docs/principles/README.md) directory contains common
decision guidance for simplicity, canonical authority, decision artifacts,
reviewable changes, and Rust code hygiene. Every consumer must adopt a reviewed
revision of the [engineering baseline](DRAGGINZGAME.md) and identify its local overlay.
These guides explain the baseline; they do not grant consumers permission to
override its common rules.

`DRAGGINZGAME.md` is the reusable baseline. Each repository's `AGENTS.md` is its
local entry point and overlay; Shared Tooling's own validation commands stay in
its [local instructions](AGENTS.md).

The baseline's focused mandatory policies live in `rules/`. The
[changelog rules](rules/changelogs.md) cover automatic next-version selection,
concise release summaries, GitHub issue links, breaking changes and minor-line
detail files. The [Rust workspace rules](rules/rust-workspaces.md) require a
virtual root with packages under `crates/<package-name>/` or application-owned
`apps/<app-name>/` trees. Both use the same workspace inheritance; independent
workspaces and other layouts require explicit exceptions. The
[Cargo dependency rules](rules/cargo-dependencies.md) require one root dependency
catalog inherited by every child manifest. The
[dependency pinning rules](rules/dependency-pinning.md) define immutable source
identities, compatible registry requirements, locked builds and scoped exceptions. The
[Git hook rules](rules/git-hooks.md) standardize Rust pre-commit formatting and
safe repository-local installation. The
[agent maintenance rules](rules/agent-maintenance.md) define user-triggered CI
inspection, issue review and scoped repair requests.

The [shared audit methods](audits/README.md) cover code hygiene, flow convergence,
complexity, module surface review and authorized cleanup. Consumers keep product
invariants, commands and historical reports locally, and adopt the common methods
through the same reviewed snapshot mechanism as the baseline.

See [`CONTRIBUTING.md`](CONTRIBUTING.md) for the inclusion boundary and
[`docs/provenance.md`](docs/provenance.md) for the initial Canic and IcyDB
contributions.

## Current tools

### Local IC executables

Use `make install-tools` for the common local setup, including pinned jq,
Mike Farah yq and ripgrep with PCRE2, and `make tools-check` for offline verification. See
[local setup](docs/local-setup.md) for Linux Mint/macOS bootstrap packages and
shell PATH configuration. Make targets select the local binaries automatically.

`make install-ic-tools` installs the reviewed Quill, ICP CLI, didc, ic-wasm,
PocketIC and Binaryen set beneath `.tools/ic/bin`. `make ic-tools-check` verifies
it offline. Setup activates only a complete verified set and preserves prior
sets and failed candidates. See [local IC tools](docs/ic-tools.md) for pins,
PATH setup, native host coverage and consumer adoption.

### Focused verification helpers

For separately authorized tag maintenance, use
`perl scripts/dev/delete-github-tags-up-to.pl --cutoff X.Y.Z` for a read-only
preview. See [explicit tag maintenance](docs/tag-maintenance.md) for remote
selection, deletion authorization, retained evidence and interrupted retries.

- `scripts/ci/rewrite-local-lock-versions.pl` emits exact local-package version
  changes without resolving external dependencies. `scripts/ci/check-formatting-hooks.sh`
  exercises a consumer's actual formatter in disposable Git exports. See their
  explicit inputs and limits in the [helper contracts](docs/verification-helpers.md).
- `scripts/ci/check-dependency-pins.sh --cargo-inheritance` also checks dependency
  catalogs and member version inheritance. `scripts/ci/read-cargo-workspace-version.sh`
  reads one selected Cargo manifest structurally, with optional stable-only
  admission. See the [Cargo helper contracts](docs/verification-helpers.md#cargo-inheritance-and-workspace-version).
- `scripts/ci/verify-file-checksum.sh --print <sha256|sha512> <file>` generates
  portable digests through the same backend as checksum verification, IC tool
  receipts and snapshot manifests.
- `scripts/ci/prepare-rustsec-db.sh <online|local> <source> <new-destination>`
  isolates an advisory database, records its commit and retains preparation
  diagnostics. Consumers own audit invocation and security policy. See the
  [helper contracts](docs/verification-helpers.md).
- `make check-doc-links` checks local Markdown targets in the selected shared
  documents; `make check-release-commands` tests Make entry points using a
  substitute runner. The read-only `scripts/ci/check-crates-io-version.sh` reports
  present, absent or unavailable for one exact stable crates.io version. See
  [verification helper contracts and adoption](docs/verification-helpers.md).
- `scripts/ci/verify-evidence-checksums.sh <manifest> [...]` verifies nonempty
  SHA-256 manifests using the shared portable checksum backend. Paths in each
  manifest resolve from the caller's working directory; manifests use ordinary
  unescaped sha256sum text/binary records, including filenames with spaces.
- `scripts/ci/run-nonempty-cargo-test.sh <cargo-test-args...>` runs Cargo in the
  caller's workspace, rejects zero passing tests and retains failed output.
  It requires the normal libtest summary format and preserves Cargo arguments
  and network policy. Cargo and logging failures remain failures.
- `scripts/ci/check-release-tag.sh <exact-commit> <version>` checks an annotated
  `vX.Y.Z` tag against the selected full commit, without Git mutations. Consumer
  publication adapters select the version/commit; the release runner keeps its
  existing reconciliation checks.

### Dependency pin checks

`make check-pins` checks parsed Cargo and GitHub Actions declarations and tracked
workspace lockfiles. `scripts/ci/check-dependency-pins.sh --consumer /path/to/repo`
supports read-only consumer inspection. Prepare Mike Farah yq v4.47.2+, jq and Git
first; Cargo is needed for Cargo workspaces. `YQ` can select an installed parser
path. The shared installer requires an explicit reviewed version and checksum.
See the [pinning policy](rules/dependency-pinning.md) for exact constraints,
external inputs, exception records and the checks still owned by consumer gates.

### Cargo workspace LOC report

`scripts/dev/cloc.sh` reports Rust lines in runtime-named and test-named files,
test-attribute counts, inline-test counts, and workspace totals for every member
of a Cargo workspace. Path classification follows `tests/` directories and
files ending in `tests.rs`; inline test code remains part of runtime-file LOC.
Classification uses paths relative to each package, and nested workspace
members are excluded from their parent package's counts. Cargo's selected target
directory is excluded from both LOC and test counts, including a configured build
directory inside a package.

Requirements:

- Bash 3.2 or newer;
- Cargo;
- `cloc`;
- `jq`; and
- standard Unix tools including `awk`, `find`, `grep`, and `sort`.

Run it from the repository being measured:

```bash
../shared-tooling/scripts/dev/cloc.sh
```

Or pass an explicit checkout path:

```bash
/path/to/shared-tooling/scripts/dev/cloc.sh /path/to/repository
```

The report discovers Cargo workspace members from `cargo metadata`; package
names and directory layouts do not need to follow a shared prefix.

### Validation target runner

`scripts/ci/run-validation-targets.sh` runs one or more Make targets in order,
records their durations, highlights live failures with an `[ERR:<target>]`
prefix, retains complete and condensed failure logs, and writes a GitHub step
summary when one is available. Pass `--fail-fast` to stop after the first
failed target.

Vendor `scripts/ci/check-make-execution.sh` alongside the runner. It rejects
inherited Make ignore-errors, dry-run, question, touch and version-only modes before validation;
normal Make variables and parallel-job settings remain available to targets.

```bash
scripts/ci/run-validation-targets.sh fmt-check shellcheck test
scripts/ci/run-validation-targets.sh --fail-fast preflight test
```

The script defaults to the repository containing its vendored copy. Set
`VALIDATION_REPOSITORY_ROOT` and `VALIDATION_FAILURE_LOG_DIR` when invoking it
from another location.
If retaining a failed log in the selected directory fails, the runner keeps its
temporary log directory and prints its location instead of deleting the evidence.

### Stable sccache launcher

`scripts/ci/run-sccache.sh` prevents a long-lived sccache server from inheriting
an invocation-owned temporary directory that will later be deleted. It defaults
to `.tmp/sccache-runtime` in the consuming repository. Override discovery with
`SCCACHE_BIN`, `SCCACHE_REPOSITORY_ROOT`, or `SCCACHE_RUNTIME_DIR`.
Consumers retain cache-failure policy in an explicit adapter; see
[launcher adoption](docs/verification-helpers.md#compiler-cache-launcher-adoption).

### Rust pre-commit formatting

The executable `.githooks/pre-commit` formats an isolated copy of the index with
the consumer's `make fmt`, then refreshes only the selected files. It rejects
partial staging and preserves unselected files and unrelated working edits.
The installer refuses to replace an existing hook setup.
Following IcyDB and Canic, `fmt` runs `cargo sort --workspace` to order Cargo.toml
files before `cargo fmt --all`; `fmt-check` checks both without modifying files.
The shared `scripts/ci/check-format-tools.sh` admits the consumer's pinned
cargo-sort and prepared rustfmt before either target, without installing tools.

Rust consumers vendor the hook, `scripts/dev/install-git-hooks.sh` and
`scripts/ci/check-make-execution.sh`, expose
`make install-hooks`, and include `fmt-check` in CI. See the
[hook contract and adoption steps](rules/git-hooks.md). Shared Tooling has no
Cargo workspace and does not activate the Rust hook in its own checkout.

### Checksum-verified tool installers

The actionlint, Gitleaks, ShellCheck, sccache and yq installers require the consuming
repository to supply an exact version and the SHA-256 digest for the detected
platform. Shared Tooling owns secure download and verification mechanics; each
consumer continues to own version policy.

The sccache binary installer currently selects only the reviewed Linux x86-64
asset. It retains failed candidates and uses the same shared installation
implementation as actionlint, Gitleaks, ShellCheck and standalone yq. Each entry
point requires `scripts/ci/install-ci-tool.sh` in its snapshot. All reject failed
version probes and directory destinations, retain failed candidates and replace
the executable with a rename on the destination filesystem.

```bash
scripts/ci/install-actionlint.sh \
  --version 1.7.12 \
  --sha256 <platform-sha256>
```

Use `--install-dir` or `TOOL_INSTALL_DIR` to change the destination.

### GitHub Actions inspection

`scripts/dev/gh-ci.sh` lists or opens GitHub Actions runs through an already
authenticated GitHub CLI session.

```bash
scripts/dev/gh-ci.sh --failed --logs
scripts/dev/gh-ci.sh --commit HEAD --all-workflows --limit 100
```

`--commit` resolves a local revision to its full commit identity and avoids an
implicit branch filter; add `--branch` explicitly to narrow it. `--all-workflows`
lists runs without the default `CI` workflow filter. The list is bounded by
`--limit`, includes pending and failed runs, and is not a complete CI verdict.
Increase the limit when necessary and inspect listed runs with `--run ID --logs`.
`--failed` deliberately searches historical failures, which may have been
superseded by later successes. Existing branch/workflow defaults remain unchanged.
Select another repository through the GitHub CLI's `GH_REPO` environment variable;
commit revisions still resolve in the current local checkout.

Agents also recognize `check CI`, `check issues` and `check for work` through the
[maintenance rules](rules/agent-maintenance.md). To enable automatic checks during
the current session, tell the agent:

> After each task, check CI; when there's nothing else to do, check issues.

The agent completes its current batch, checks the relevant source's latest CI
runs, and recommends actionable issues. Use `fix CI` or `work on issue #N` to
authorize a local repair. Consumers include the maintenance rule in their
reviewed governance snapshot.

### Focused self-test

Run the portable scripts' offline regression tests with the dependencies from
the support matrix installed:

```bash
bash scripts/ci/test-portable-tools.sh
```

The suite first checks its prepared tools and formatter prerequisites, reporting
missing commands together before creating fixtures. Run only that offline check
with `bash scripts/ci/check-portable-prerequisites.sh`; see
[local setup](docs/local-setup.md) for explicit installation instructions.

### Snapshot distribution

`scripts/distribution/refresh-consumer.sh` copies a declared file set from a
clean Shared Tooling checkout and records its exact revision, content digests,
and executable modes. A vendored
`scripts/ci/verify-shared-tooling-snapshot.sh` checks consumer drift offline.
See [`docs/consuming-snapshots.md`](docs/consuming-snapshots.md).

## Consuming repositories

Interactive read-only tools can be run directly from a sibling checkout.
CI and release tools must be copied into the consuming repository as reviewed
snapshots so builds do not depend on a mutable external checkout or network
availability. Keep Shared Tooling as the source of truth, record the source
commit in the consumer, and review the normal repository diff after refreshing.

Do not replace consumer copies with symlinks. The snapshot refresh and offline
drift-verification flow is documented in
[`docs/consuming-snapshots.md`](docs/consuming-snapshots.md).

Supported hosts and tool dependencies are defined in
[`docs/supported-hosts.md`](docs/supported-hosts.md). Every `dragginzgame` package
must support macOS, including its applicable dependency, build, test and
deployment workflows. Consumers document host-specific setup and qualify their
own macOS versions and architectures.

## Intended layout

- `scripts/dev/` — developer utilities and explicit repository-local setup;
- `.githooks/` — reviewed hooks for consuming repositories;
- `scripts/ci/` — reusable non-interactive validation building blocks;
- `rules/` — focused mandatory policies linked from the engineering baseline;
- `docs/` — shared principles and integration guidance;
- `scripts/distribution/` — source-side snapshot refresh tools; and
- `.github/workflows/` — workflows owned by this repository.

Project-specific policy remains in each consuming repository. Shared tooling
must accept explicit inputs rather than silently inferring deployment identity,
network authority, credentials, or release state.
