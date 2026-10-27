# Fleet reports and CI inspection

Shared Tooling owns these central reports. They inspect selected repositories;
they do not run sibling setup, build or release targets. Consumers retain their
own validation and issue resolution. See the [ownership boundary](../README.md#repository-fleet-ownership)
and [supported tool dependencies](supported-hosts.md#tool-specific-dependencies).

Prepare tools explicitly using [local setup](local-setup.md). Commands below run
from Shared Tooling unless another working directory is specified. Prepared
host tools in this checkout's `.tools/host/bin` take precedence over `PATH`.

## Cargo workspace LOC report

For one row per sibling root workspace:

```bash
make cloc
make cloc CLOC_PARENT=/path/to/projects
```

For a single checkout or an independent workspace:

```bash
bash scripts/dev/cloc.sh /path/to/repository
bash scripts/dev/cloc.sh --manifest testing/Cargo.toml /path/to/repository
bash scripts/dev/cloc.sh --json /path/to/repository
bash scripts/dev/cloc.sh --check-tools
```

The workspace report discovers members through locked, offline Cargo metadata.
It counts runtime-named and test-named Rust files, test attributes and inline
test functions. `tests/` paths and filenames ending in `tests.rs` classify test
files; inline tests remain in runtime-file LOC. Nested members and Cargo's
selected target directory are excluded from their containing package's counts.
Each admitted path counts once, including separate copies with identical bytes.

JSON contains the selected `manifest`, `crates` and `totals`, with numeric
`runtime_loc`, `test_loc`, `test_pct`, `test_fns` and `inline_fns`; crate rows add
`crate`. Percentages use the table's one-decimal rounding. A failed report exits
nonzero without emitting a partial JSON document.

The sibling report, [cloc-siblings.sh](../scripts/dev/cloc-siblings.sh), visits
immediate Git checkouts in name order, including linked worktrees and hidden
directories, skipping symlink aliases and non-repositories. Its default parent
belongs to the script's checkout. It checks prerequisites once before reporting
Cargo workspaces. A repository without a root manifest shows `N/A`; a failed
count shows `ERROR`, retains other rows and makes the command fail. Totals sum
successful workspaces and recompute their combined test percentage; failures
label the sum `TOTAL (partial)`. Independent excluded workspaces are not silently
combined with root counts. Select them explicitly with `--manifest` or the
consumer Make interface's `CLOC_MANIFEST` input.

## CI and tooling inventory

```bash
make cloc-tooling
make cloc-tooling CLOC_PARENT=/path/to/projects
perl scripts/dev/cloc-tooling.pl --json /path/to/projects > tooling-inventory.json
```

This separates CI code (`.github/`, `scripts/ci/`, `ci/`) from other tooling:
scripts, `bin/`, hooks, Make files, `.cargo/`, `tools/`, `xtask/` and Cargo package
`build.rs` files. It captures tracked and nonignored untracked working files,
counts every copy with cloc and does not run Cargo or consumer commands.
Documentation, product source, caches, generated build output and symlinks are
outside the inventory. Product functions named `build.rs` are not Cargo build
scripts. Supporting JSON, patches and CSV/TSV are physical `data_lines`, separate
from executable/configuration LOC; blank lines and comments are excluded from
the latter.

`total_loc` is CI plus other tooling code. `shared_loc` matches both SHA-256 and
executable mode against `.shared-tooling*.snapshot`; unrecorded or changed files
remain `local_loc`. Records normally resolve from the Git checkout root, even
for manifests under `config/`. A default `.shared-tooling.snapshot` beside the
canonical verifier identifies a nested bundle root. Other explicit mappings use
repeated `--snapshot-root MANIFEST CONSUMER_ROOT` options; selected roots must
remain in the checkout, and manifests must be tracked or nonignored. Selection
never tries alternative roots until hashes happen to match.

`shared_snapshot` shows recorded version and abbreviated revision, retaining
separate selections. Missing versions remain `unrecorded`; no nearby checkout
or tag supplies a guess. `integrity` is `OK`, `DRIFT`, `NONE` or `ERROR`.
Integrity includes every declared file, even documents outside LOC scope;
drifted files are reported while other counts continue. Malformed/unreadable
inputs produce partial totals and a failing status, preserving captured inputs.

JSON includes full source revisions, dirty state, snapshot observations, per-file
hashes/counts and skipped files. Unborn checkouts have `head: null` and
`unborn: true`; a broken existing HEAD is an error. High local LOC and matching
hashes identify review candidates, not proof of removable duplication or
interchangeable contracts. The [initial inventory](reports/audits/2026/10/07/sibling-tooling/01/report.md)
is historical evidence, not a current fleet measurement.

## Sibling GitHub dashboard

```bash
bash scripts/dev/github-siblings.sh
bash scripts/dev/github-siblings.sh --interval 120
bash scripts/dev/github-siblings.sh --once /path/to/projects
```

The dashboard inventories immediate Git checkouts with `AGENTS.md` and a GitHub
`origin`. It skips symlink aliases, deduplicates repositories and defaults to
the script checkout's parent. Restart it to discover new siblings. It needs an
already authenticated GitHub CLI (`gh auth login`), Git, jq, Perl core and IANA
timezone data.

Both **ISSUES** and **PRS** have **OVERALL** (`OPEN`, `CLOSED`) and **TODAY**
(`ADDED`, `CLOSED`) groups. Closed PRs include merges; open PRs include drafts.
Closed issues include duplicates and issues closed as not planned. These are
GitHub state counts, not proof of substantive fixes.

TODAY starts at **06:00 Europe/Paris**, including daylight-saving changes; before
06:00 it uses the previous day's cutoff. Added counts include creations in any
current state. Closed counts include currently closed items whose latest
closure or PR merge falls within that window. Reopened issues do not count as
currently closed. Complete totals use batched GraphQL requests; recent activity
uses pagination. Failed observations show `ERROR`, never zero, and totals become
`TOTAL (partial)`.

In a terminal the dashboard refreshes every 60 seconds; `q` quits and `r`
refreshes early. `--once` and redirected input/output produce one report and
fail on partial observations. Watch mode retries on its next cycle. Rows sort
by open issues descending, with errors last; colour scales relative to the
largest observed backlog. `NO_COLOR`, `TERM=dumb` and redirected output disable
colour. Repository labels include the organization only when the table fits
the known terminal width.

## GitHub Actions inspection

```bash
bash scripts/dev/gh-ci.sh --commit HEAD --all-workflows --limit 100
bash scripts/dev/gh-ci.sh --run 123456 --logs
bash scripts/dev/gh-ci.sh --failed --logs
```

The default workflow is `CI`. `--commit` resolves a local revision to a full
commit identity without an implicit branch filter; add `--branch` to restrict
it. `--all-workflows` removes the workflow filter. Lists are bounded by `--limit`,
not a complete CI verdict; inspect the relevant run explicitly. `--failed`
searches historical failures that may have been superseded by later successes.
`GH_REPO` selects another GitHub repository, but commit revisions still resolve
in the caller's local checkout. Detached HEAD needs an explicit selector.

Run IDs must be positive integers. `--run` excludes list/search filters;
`--list --logs` is rejected. `--logs` pins the repository, run and attempt before
fetching evidence. Empty failed-step logs for a completed failed/timed-out
attempt trigger a download of only that attempt's failed/timed-out job logs.
The original observation and recovered logs remain in the announced temporary
directory. API failures and empty logs for cancelled/unfinished attempts remain
failures; completed successful, neutral or skipped runs may have no failed logs.
The command never reruns CI or converts logs into a passing qualification.

For agent-driven inspection and separately authorized fixes, use the
[maintenance rules](../rules/agent-maintenance.md). Repeatable fleet tasks and
their optional schedule live in the [task catalog](../tasks/README.md).

## Stack dependency overview

The [README diagram](../README.md#toko-stack) and [manifest evidence](stack.md)
have a separate deterministic daily local refresher. It reads existing checkouts
and leaves generated documentation changes for the next commit; it does not
launch an agent, stage files or fetch upstream changes.
