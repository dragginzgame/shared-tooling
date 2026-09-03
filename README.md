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

## Intended layout

- `scripts/dev/` — interactive, read-only developer utilities;
- `scripts/ci/` — reusable non-interactive validation building blocks;
- `docs/` — shared conventions and integration guidance; and
- `.github/workflows/` — workflows owned by this repository.

Project-specific policy remains in each consuming repository. Shared tooling
must accept explicit inputs rather than silently inferring deployment identity,
network authority, credentials, or release state.

