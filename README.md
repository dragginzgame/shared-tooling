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
Direct atomic branch/tag delivery remains the default. Explicit
[PR delivery](docs/releases.md#pr-delivery) prepares a review branch, waits for
merge, and validates the exact merged commit again before pushing its tag.

`make version` reads the current local version from [`VERSION`](VERSION).
The top undated changelog entry describes the next proposed release. Standard
release preparation updates both files; Git tags establish published release
identity independently.

## Repository fleet ownership

Shared Tooling owns consistency across the Dragginzgame repositories: shared
rules and tools, adoption/pin drift checks, repository and sibling counts,
CI/issue dashboards, LOC/tooling inventories, and repeatable maintenance audits.
The central reports run here. Consumers keep the shared setup and validation
helpers they need locally; they do not need a copy of every fleet dashboard or
an extra CI gate that scans their siblings.

IC Metrics owns reusable measurement arithmetic. Repository discovery, sibling
counts, GitHub status collection and fleet-consistency policy belong here, outside
the IC Metrics product and runtime dependency graph. Product repositories retain
their own behavior, validation evidence and issue resolution; central reporting
does not grant cross-repository edit or deployment authority.

Keep the tooling and fleet checks in this repository while they share the same
maintenance lifecycle. Reconsider a separate application repository if a hosted
dashboard or service needs its own persistent data, authentication, permissions
and deployment lifecycle. Such an application would consume reviewed Shared
Tooling rules and checks; it would not create a second engineering baseline.

## Repeatable maintenance

Open the [task catalog](tasks/README.md) or run `make tasks`. Shared Tooling owns
repeatable cargo-machete, MSRV, Rust freshness, CI/issue, snapshot and dependency
advisory checks, plus bounded code and tooling-duplication audits. Each definition
explains its scope, procedure and evidence; consumers keep their local inputs.

The [local agent schedule](tasks/local-schedule.md) runs a maintenance pass every
three days once explicitly enabled, retaining reports and coordinating findings
through owning GitHub issues. It does not automatically edit sibling source or
upgrade dependencies. Task definitions remain readable and runnable on demand.

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
[contribution rules](rules/contributions.md) support human and agent PRs:
an authorized PR includes its branch, commits and branch push, while merges,
direct integration-branch pushes and releases retain separate authority. The
[changelog rules](rules/changelogs.md) cover automatic next-version selection,
concise release summaries, GitHub issue links, breaking changes and minor-line
detail files. The [Rust workspace rules](rules/rust-workspaces.md) require a
virtual root with packages under `crates/<package-name>/` or application-owned
`apps/<app-name>/` trees. Both use the same workspace inheritance; independent
workspaces and other layouts require explicit exceptions. The rule explicitly
approves IcyDB's existing `crates/`, `canisters/`, `schema/` and `testing/` trees,
with no required package moves. The
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

Use `make install-tools` for the complete common host, IC and Cargo toolsets,
and `make tools-check` for offline verification. Every repository gets the same
12 executables, including tools it does not currently use; setup runs host, IC
and Rust steps in order. Setup first checks platform support and the selected
Rust/Cargo toolchain without downloads or installations. The [required tool inventory](docs/local-setup.md#required-tool-inventory)
is the shared setup list for every repository. See [local setup](docs/local-setup.md)
for Linux Mint/macOS bootstrap packages and shell PATH configuration. Make targets
select the local binaries automatically; direct shell commands need the documented
PATH export in each checkout. Consumers include the reviewed snapshot's
[`make/tools.mk`](make/tools.mk) for setup, offline verification and `make cloc`;
the [adoption guide](docs/consuming-snapshots.md#local-ic-tool-adoption) lists its
companion files and replaces copied Make recipes.

`make install-ic-tools` installs the reviewed Quill, ICP CLI, didc, ic-wasm,
and Binaryen set beneath `.tools/ic/bin`. `make ic-tools-check` verifies
it offline. Setup activates only a complete verified set and preserves prior
sets and failed candidates. See [local IC tools](docs/ic-tools.md) for pins,
PATH setup, native host coverage and consumer adoption.
IC Testkit owns PocketIC setup, offline admission and server lifecycle; see the
[ownership handoff](docs/ic-tools.md#pocketic-ownership-handoff).

The aggregate includes `make install-rust-tools` and offline `make rust-tools-check`
for pinned cargo-sort, cargo-sort-derives and candid-extractor under `.tools/rust/bin`.
Prepare a declared Rust toolchain even for non-Rust repositories. See
[Rust setup](docs/local-setup.md#rust-development-tools) and the
[0.3.0 adoption steps](docs/consuming-snapshots.md#complete-toolset-adoption-in-030)
for the complete pins, removed optional host flags and ordered product extensions.

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
  present, absent or unavailable for one exact stable crates.io version. Its
  optional metadata mode retains bounded response evidence and returns validated
  checksum/yanked facts while leaving publication decisions with the caller. See
  [verification helper contracts and adoption](docs/verification-helpers.md).
- `scripts/ci/verify-evidence-checksums.sh <manifest> [...]` verifies nonempty
  SHA-256 manifests using the shared portable checksum backend. Paths in each
  manifest resolve from the caller's working directory; manifests use ordinary
  unescaped sha256sum text/binary records, including filenames with spaces.
- `scripts/ci/run-nonempty-cargo-test.sh <cargo-test-args...>` runs Cargo in the
  caller's workspace, rejects zero passing tests and retains failed output.
  It requires the normal libtest summary format and preserves Cargo arguments
  and network policy. Cargo and logging failures remain failures.
- `scripts/ci/run-formatting.sh --check|--write COMMAND [ARG ...]` reports one
  success line or a short failure summary with the full retained log path.
  `make/rust-format.mk` uses it for Rust formatting; custom workspace/frontend
  adapters can use the same output contract without changing their policy.
  See the [formatting rules](rules/git-hooks.md).
- `scripts/ci/check-runner-disk-space.sh --path PATH --min-free-mib N` checks
  capacity before a consumer-selected step. Optional diagnostic paths report
  disk usage without cleanup; thresholds stay local. See the
  [disk checker contract](docs/verification-helpers.md#runner-disk-capacity).
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
Opt in to npm root declaration checks with `--npm-root`, `--node-version` and
`--npm-version`, using that consumer's existing selections. The checker needs
neither npm nor Node and leaves resolution to npm's own locked preparation.
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
names and directory layouts do not need to follow a shared prefix. Metadata
inspection is locked and offline; it does not update the selected dependency
graph or fetch missing inputs.

For one line per sibling repository with the same Rust columns, run from Shared
Tooling:

```bash
make install-host-tools  # Explicit setup, including pinned cloc and jq
make cloc
make cloc CLOC_PARENT=/path/to/projects
```

The report prefers this checkout's `.tools/host/bin` automatically, including
when invoked directly. `cloc.sh --check-tools` checks prerequisites without
counting or installing. The sibling report checks once before printing any
rows when a Cargo workspace is present, reporting missing tools together with
the setup command.

Or invoke `scripts/dev/cloc-siblings.sh [parent-directory]` directly from any
directory. By default it scans the parent of the checkout containing the script.
It visits immediate Git checkouts, including linked worktrees and hidden
directories, in name order; symlink aliases and non-repository directories are
skipped. Each row reuses the root Cargo workspace's totals, including members
under `apps/` and `crates/`. Separate excluded workspaces are outside this scope.
Repositories without a root `Cargo.toml` show `N/A`. Failed counts show `ERROR`
with diagnostics on stderr; other repositories are still reported and the command
exits nonzero. No sibling Make targets, builds or setup commands are run.
The final `TOTAL` row sums successful reports and calculates `test_%` from their
combined LOC. `N/A` rows are excluded; failures label the total `TOTAL (partial)`.
If no workspace was successfully counted, the total shows `N/A`.

### CI and tooling inventory

For one independent Cargo workspace, use
`make cloc CLOC_MANIFEST=testing/Cargo.toml`, or
`bash scripts/dev/cloc.sh --manifest testing/Cargo.toml "$PWD"`.
The explicit manifest selects only that graph and its Cargo target directory;
metadata runs from its directory with the selected lockfile, offline. Default
root reporting and sibling totals do not automatically combine independent graphs.

Use `make cloc-tooling [CLOC_PARENT=/path/to/projects]` to find where sibling
repositories maintain the most CI and tooling code. For per-file evidence:

```bash
perl scripts/dev/cloc-tooling.pl --json /path/to/projects > tooling-inventory.json
```

The table separates CI (`.github/`, `scripts/ci/`, `ci/`) from other tooling,
including other scripts, `bin/`, hooks, Make files, `.cargo/`, `tools/`, `xtask/` and
Cargo package `build.rs` files. It reads tracked and nonignored untracked working
files, captures their bytes in temporary files and counts all copies with cloc.
Product source, documentation, caches, build output and symlinks are outside
this inventory; product runtime functions named `build.rs` are not build scripts.
This is a tooling inventory, not a whole-repository or semantic-duplication scan.

`total_loc` is CI plus other tooling code, excluding blank lines and comments.
`shared_loc` matches both the SHA-256 and executable mode in the repository's
`.shared-tooling*.snapshot` manifests; the rest is `local_loc`. File records
resolve from the consumer root, even when a manifest lives under `config/`.
A default `.shared-tooling.snapshot` beside the canonical
`scripts/ci/verify-shared-tooling-snapshot.sh` identifies a nested bundle root;
other manifests default to the Git checkout root. For another explicit mapping,
pass `--snapshot-root /path/to/manifest /path/to/consumer-root` to the Perl command
(repeat for independent bundles). The selected root must stay inside that
checkout, and the manifest must be tracked or nonignored. Selection never tries
different roots until hashes match. HTTPS and SSH spellings of the same Shared
Tooling GitHub repository are accepted. Modified snapshot files
produce a warning and remain local in these counts. Supporting JSON, patches and
CSV/TSV tables appear separately as physical `data_lines`, so frozen baselines
and ablation patches do not inflate executable-tooling LOC.

The table's `shared_snapshot` column shows the recorded version and abbreviated
source commit, such as `0.2.8@b2646cde9abb`; multiple selections are comma-separated.
A version absent from the manifest shows `unrecorded`, never a guess from another
checkout. Refresh records it automatically from the selected committed `VERSION`.
`integrity` is `OK` when every declared file matches its hash and executable mode,
`DRIFT` for changed, missing or symlinked files, `NONE` without a recorded snapshot,
or `ERROR` when the inventory cannot be read. This checks declared documents too,
without including them in LOC. Drift does not prevent the remaining counts and
is reported in stderr/JSON; malformed input produces a partial report and failure.
These observations neither authenticate the manifest's provenance nor qualify
consumer behavior. They run no consumer scripts and require no Cargo package.

JSON output records source commits, dirty state, snapshot versions and full
revisions, per-manifest integrity and drifted paths, per-file
hashes, ownership, counts and any files cloc skipped. Repositories awaiting their
first commit are counted with `head: null` and `unborn: true`; the text report
announces their uncommitted bootstrap state on stderr. A broken existing HEAD
remains an error. Shell `.env` files and jq source filters are counted too.
Errors leave other repository rows visible,
mark totals partial, exit nonzero and retain captured inputs. Healthy shared
copies already have a common owner; high local LOC or matching hashes only
identify candidates for a contract review, not promised removable lines.

The [2026-10-07 inventory and findings](docs/reports/audits/2026/10/07/sibling-tooling/01/report.md)
record the initial measurements and concrete consolidation candidates.

### Validation target runner

`scripts/ci/run-validation-targets.sh` runs one or more Make targets in order,
records their durations, highlights live failures with an `[ERR:<target>]`
prefix, retains complete and condensed failure logs, and writes a GitHub step
summary when one is available. Pass `--fail-fast` to stop after the first
failed target.

Vendor `scripts/ci/check-make-execution.sh` alongside the runner. It rejects
inherited Make ignore-errors, dry-run, question, touch and version-only modes before validation;
normal Make variables and parallel-job settings remain available to targets.
The complete argument list is checked before dispatch: arguments must be named
goals, not Make options, variable assignments or names containing tabs/newlines.
Pass variable selections through the caller's environment or owning Makefile.

```bash
scripts/ci/run-validation-targets.sh fmt-check shellcheck test
scripts/ci/run-validation-targets.sh --fail-fast preflight test
```

The script defaults to the repository containing its vendored copy. Set
`VALIDATION_REPOSITORY_ROOT` and `VALIDATION_FAILURE_LOG_DIR` when invoking it
from another location.
If retaining a failed log in the selected directory fails, the runner keeps its
temporary log directory and prints its location instead of deleting the evidence.

Each completed failed batch also prints a unique combined log path and updates
`latest-combined.log` in that failure directory. This is the byte concatenation
of failed targets' raw logs in dispatch order. `latest.log` continues to hold
the last failed target alone. Successful or interrupted batches leave the last
completed combined view intact; interrupted raw logs remain available separately.
Nested runs combine their own target streams without rediscovering child files.

Set `VALIDATION_LOG_DIR` to retain successful, failed and interrupted raw output
under a unique run directory announced before dispatch. Its `timings.tsv` has
`target`, `result`, `seconds` and `log` columns, with one row per completed target.
An interrupted target can have a partial raw log without a completed timing row.
`VALIDATION_FAILURE_EVENT_PREFIX` adds a literal line prefix, such as
`[CANIC-TEST:E`, to live highlighting and bounded failure details. Raw logs keep
their original bytes. Success returns zero; failure preserves the first failed
Make invocation's status (normally 2, rather than the recipe's own status).
A logging-only pipeline failure also returns nonzero. SIGINT/SIGTERM exit with
130/143 when handled.
Nested invocations retain separate run directories and only the outermost writes
the GitHub summary. Consumer callers still own targets and child color policy:
set a product variable such as `CANIC_TEST_COLOR` before dispatch when the caller
has a terminal, respecting an explicit selection and `NO_COLOR`. The runner
passes that environment through without learning product-specific variable names.

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

### Sibling GitHub dashboard

Run a live terminal dashboard for the connected sibling checkouts:

```bash
scripts/dev/github-siblings.sh
scripts/dev/github-siblings.sh --interval 120
scripts/dev/github-siblings.sh --once /path/to/projects
```

The dashboard scans immediate Git checkouts with `AGENTS.md` and a GitHub.com
`origin`, including Shared Tooling itself. This excludes unconnected checkouts
such as `ichelper`. It skips symlink aliases and counts duplicate GitHub
repositories once. The default parent belongs to the script's checkout; restart
to discover new siblings. Requires Git, jq, Perl core, system timezone data and
an authenticated GitHub CLI; prepare authentication with `gh auth login`.

Rows show `REPOSITORY` first, then centered `ISSUES`, `TODAY` and `PRS` group
headings. Issues have `OPEN` and `FIXED`; TODAY has `FIXED` and `ADDED`; PRs
have `OPEN`, `MERGED` and `CLOSED`.
`FIXED` is centered over the full closed / total and percentage value, such as
`23 / 1,095 (2.1%)`. Numeric padding starts at four characters and expands to fit
the largest comma-separated repository count in that refresh. Totals grow
independently, so a fleet total above 999 does not widen every repository's
`FIXED` ratio: ` 400 /  486 (82.3%)` keeps two spaces after the slash.
Column headings and `ERROR` fit without shifting later columns. Counts remain
right-aligned. Repositories sort by percentage fixed ascending, then open issues
descending and name. Repositories with no issues follow ranked rows; failed
observations come last. Entire repository and total rows use pale red–yellow–green
text from 0% to 100% fixed, preserving the terminal background. `NO_COLOR` or
`TERM=dumb` disables colour, and redirected
reports remain plain text. Dashed separators distinguish the header and combined totals.
Here **fixed means closed**, including duplicates and issues closed as not
planned; the percentage is `closed / (open + closed) * 100`. Pull requests stay
separate from that calculation, and repositories with no issues show `N/A` for
the percentage even if they have PRs. PR `OPEN` includes drafts. PR `CLOSED`
counts only requests closed without merging, following GitHub's
[pull-request states](https://docs.github.com/en/graphql/reference/pulls#pullrequeststate).
`TODAY / FIXED` counts currently closed issues whose latest closure was at or
after 06:00 Europe/Monaco. `TODAY / ADDED` counts issues created since that same
cutoff, whether currently open or closed. Before 06:00 it uses the previous calendar day's cutoff,
including daylight-saving changes. Each refresh recalculates the cutoff;
reopened issues do not count as fixed, and editing an old issue does not count
as adding or fixing it. An issue created and closed today counts in both columns.

Counts use complete GitHub API totals. For `TODAY`, the dashboard paginates
[recently updated issues](https://docs.github.com/en/graphql/reference/issues)
and checks their creation and closure timestamps. In a terminal it refreshes every 60 seconds
using a batched read-only GraphQL request plus any required recent-issue pages.
Press `q` to quit, `r` to refresh early, or Ctrl-C to exit. `--once` prints one report; redirected input/output also selects a single report. Failed
observations show `ERROR` and label the combined total `TOTAL (partial)`;
single reports exit nonzero, while the live dashboard retries on the next cycle.
A repository row requires valid issue, PR and TODAY counts; an unavailable category
never becomes zero. Partial totals include only complete repository rows.

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

`--logs` reports unavailable failed-step evidence if GitHub returns an empty log
for a failed, cancelled or unfinished run. Completed successful, neutral or skipped
runs may legitimately have no failed-step logs. Failed observations retain their
output and diagnostics in the printed temporary directory, and failed fetches
preserve their original exit status. This inspection does not rerun CI or turn
nonempty logs into a green-gate verdict.

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
- `tasks/` — repeatable maintenance procedures, agent prompt and scheduling guidance;
- `docs/` — shared principles and integration guidance;
- `scripts/distribution/` — source-side snapshot refresh tools; and
- `.github/workflows/` — workflows owned by this repository.

Project-specific policy remains in each consuming repository. Shared tooling
must accept explicit inputs rather than silently inferring deployment identity,
network authority, credentials, or release state.
