# Shared Tooling

Reusable development tools, CI building blocks, workflow conventions, and
documentation for Dragginz Game repositories.

The repository keeps shared behavior in one place without making individual
projects copy large scripts or encode repository-specific assumptions. Tools
should be deterministic, explicit about their dependencies, and safe to run
from any supported checkout.

## Current tools

### Cargo workspace LOC report

`scripts/dev/cloc.sh` reports Rust runtime and test lines, test-function counts,
inline-test counts, and workspace totals for every member of a Cargo workspace.

Requirements:

- Bash;
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
summary when one is available.

```bash
scripts/ci/run-validation-targets.sh fmt-check shellcheck test
```

The script defaults to the repository containing its vendored copy. Set
`VALIDATION_REPOSITORY_ROOT` and `VALIDATION_FAILURE_LOG_DIR` when invoking it
from another location.

### Stable sccache launcher

`scripts/ci/run-sccache.sh` prevents a long-lived sccache server from inheriting
an invocation-owned temporary directory that will later be deleted. It defaults
to `.tmp/sccache-runtime` in the consuming repository. Override discovery with
`SCCACHE_BIN`, `SCCACHE_REPOSITORY_ROOT`, or `SCCACHE_RUNTIME_DIR`.

### Checksum-verified tool installers

The actionlint, Gitleaks, and ShellCheck installers require the consuming
repository to supply an exact version and the SHA-256 digest for the detected
platform. Shared Tooling owns secure download and verification mechanics; each
consumer continues to own version policy.

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
```

### Focused self-test

Run the portable scripts' offline regression tests with:

```bash
bash scripts/ci/test-portable-tools.sh
```

## Consuming repositories

Interactive read-only tools can be run directly from a sibling checkout.
CI and release tools should be copied into the consuming repository as reviewed
snapshots so builds do not depend on a mutable external checkout or network
availability. Keep Shared Tooling as the source of truth, record the source
commit in the consumer, and review the normal repository diff after refreshing.

Do not replace consumer copies with symlinks. A future refresh command should
copy a declared file set from one exact Shared Tooling commit, update the
recorded revision, and make no other repository changes.

## Intended layout

- `scripts/dev/` — interactive, read-only developer utilities;
- `scripts/ci/` — reusable non-interactive validation building blocks;
- `docs/` — shared conventions and integration guidance; and
- `.github/workflows/` — workflows owned by this repository.

Project-specific policy remains in each consuming repository. Shared tooling
must accept explicit inputs rather than silently inferring deployment identity,
network authority, credentials, or release state.
