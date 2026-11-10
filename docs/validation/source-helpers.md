# Source verification helpers

## Repository symlink admission

This optional helper enforces an all-regular repository inventory. It is stricter
than the [baseline file policy](../../TOKO-TOOLING.md#repository-files-no-symlinks),
which permits justified internal links. It is not a universal compliance gate.

```sh
perl scripts/ci/check-no-symlinks.pl --consumer /path/to/checkout
```

The offline reader checks the selected checkout's actual Git index modes and
tracked/nonignored working paths, including every parent below the checkout
root. Indexed links refuse even if their working replacement is regular;
dangling links and directory links refuse without following their targets.
Tracked deletions are allowed. Failed Git/filesystem observations never pass.
Inventory uses NUL delimiters and disables optional Git index writes; inherited
Git directory/index overrides cannot select another source.

Shared's `make check-no-symlinks` runs in its CI and release gate as a local choice.
Consumers choosing the same stricter inventory may adopt it as a snapshot
entrypoint. Repositories using justified internal links should select checks for
their packaging and filesystem security boundaries instead; do not add a second
exception framework or copy/sync machinery just to satisfy this helper.
Ignored tool stores and isolated negative-test scratch are outside the inventory;
this is not admission of arbitrary ignored files or generated package contents.
Those remain subject to the baseline rule and their artifact checks.

## Evidence archives

```bash
bash scripts/ci/archive-evidence.sh "$RUNNER_TEMP/evidence.tar.gz" \
  "$RUNNER_TEMP" portable-fixtures "$PWD" .tools/ic-set.failed
```

The Bash 3.2 helper takes a new output path followed by explicit root/relative-path
pairs. Relative roots and output paths resolve from the caller's current directory,
independently of `CDPATH` or option-like names. It requires tar and gzip.
Select only existing evidence; the caller decides
which optional paths exist. The output parent must exist and the output must stay
outside every selected input. Creation refuses an occupied output, including a
symlink or a named pipe. Failed creation retains any partial archive and all original inputs.
Success prints the archive's absolute path and leaves the inputs intact.

Each path becomes an archive member relative to its supplied root. Paths must
be canonical and relative; `.` selects a complete root. Duplicate or overlapping
member paths are refused, including across different roots. Parent-directory
symlinks are refused; final symlinks are archived without following their targets.
Git metadata named `.git` is excluded. If release-state evidence is needed,
select the specific evidence directory as a root rather than archiving `.git`.

Upload the resulting single `.tar.gz` file to preserve filenames, modes and links
that a raw artifact upload cannot reliably represent. The archive supports Unix
filenames containing spaces, colons and newlines; it does not widen line-oriented
checksum-manifest formats. Callers retain ownership of selection, source and run
identity, command outcomes, manifests, upload and retention. Archiving alone
does not qualify evidence or prove a hosted upload/download round trip.

Adopt `scripts/ci/archive-evidence.sh` through a reviewed snapshot; it has no
shared-script dependencies. Toko Tooling's failure-collection action uses this
helper too. Consumers can replace their tar mechanics while preserving their
product-specific collection and identity records.

## Cargo inheritance and workspace version

```bash
bash scripts/ci/check-dependency-pins.sh --consumer /path/to/repo --cargo-inheritance
bash scripts/ci/read-cargo-workspace-version.sh --stable /path/to/repo/Cargo.toml
```

The additive `--cargo-inheritance` check reuses the pin checker's Git inventory,
TOML parser and offline Cargo workspace discovery. It checks every inventoried
Cargo manifest against its owning root: member package versions inherit
`workspace.package.version`; ordinary, development, build and target dependencies
inherit catalog entries by alias. Root packages also inherit their dependencies.
Child dependencies may select only `features`, `optional` and `default-features`
alongside `workspace = true`. Versions, paths, Git/registry sources and renamed
package identities stay in the root catalog. Both inline and ordinary TOML tables
are parsed structurally. Existing pin-only callers retain their current scope.

Nested workspace discovery does not approve a governance exception: consumers
must still document their authorized independent roots. Ignored files are outside
the Git inventory. Product dependency bans, lock graph constraints and feature
qualification remain local. Adopt the option in CI/release callers before
retiring their equivalent inheritance checks.

The version reader requires Cargo, jq and Mike Farah yq v4.47.2+. It accepts one
explicit `Cargo.toml` path and prints its `workspace.package.version` as canonical
SemVer, including prerelease/build components unless `--stable` is selected.
It rejects missing/non-string versions and malformed manifests, with no accepted
version on failure. Cargo's offline `locate-project --workspace` validates the
manifest first, including duplicate keys that yq alone accepts. It neither
resolves dependencies nor builds; the selected Cargo toolchain must be prepared.
Keep root-package targets available when reading an exported manifest, since
Cargo also checks package structure. The reader never chooses a Git commit,
updates a version or lockfile, or finalizes release notes. Consumers own selection
of working versus committed sources and their release/preparation transactions.

## Saved Cargo source context

```bash
bash scripts/ci/read-cargo-source-context.sh /path/to/repo COMMIT manifest.json crates/library apps/cli
```

The caller supplies admitted root-manifest JSON and explicit relative member
directories. The helper reads package names from that exact local commit and
returns the saved `source_root`, `manifest` and `members` context accepted by the
Cargo metadata renderers. Current member files are never read. Missing members,
invalid paths, duplicate package identities, ambiguous parser streams and failed
Git/TOML readers refuse without a partial context. Git, jq and prepared Mike Farah
yq are required; no Cargo invocation, fetch, installation, editing or Git mutation occurs.

Consumers retain root-manifest authentication, member/package eligibility,
version policy and independent graph admission. This input preparation does not
implement a TOML editor and survives the planned editor replacement in
[#273 — Adopt released IC Build Cargo editor and retire Perl renderers](https://github.com/dragginzgame/toko-tooling/issues/273).

## Local documentation links

```sh
perl scripts/ci/check-documentation-links.pl --root /path/to/repo README.md docs/guide.md
```

Supply a root and at least one document or directory. Directories are searched
recursively for regular Markdown files without following symlinks; overlapping
inputs are deduplicated. Relative input arguments resolve
from that root; absolute arguments are also accepted. Relative links
resolve from their containing document. Absolute link paths retain filesystem
semantics: `/guide.md` means the host's `/guide.md`, not the repository root.
Use relative links for repository navigation. Targets outside the root are not
prohibited; this is an existence check, not a containment boundary.

The Perl checker handles ordinary inline links, images and reference definitions,
angle-bracket paths with spaces, percent-encoded filenames and optional titles.
It removes query/fragment suffixes before checking existence, skips URI schemes,
protocol-relative URLs and anchor-only links, and ignores backtick/tilde fenced
examples and inline backtick code. Both files and directories may be targets.
Missing input documents or local targets fail the command.

This deliberately follows IcyDB's lightweight checker. It does not validate
anchors, network availability, reference-label resolution or a complete Markdown
renderer grammar (for example, nested/escaped parentheses in bare destinations,
HTML links and indented code blocks). Use angle brackets around complex paths.
A passing check only covers the supported local references in the supplied
roster. Product-specific inventories, version examples and document selection
remain consumer-owned.

Toko Tooling's `make check-doc-links` selects root, audit, rule and guide
Markdown files and runs in CI and the release gate. Consumers choose their own
roster; snapshot-relative links must exist in the adopted file set.

## Portable file digests

```sh
bash scripts/ci/verify-file-checksum.sh --print sha256 artifact.wasm
bash scripts/ci/verify-file-checksum.sh sha256 EXPECTED_HEX artifact.wasm
```

`--print` emits only one lowercase SHA-256 or SHA-512 digest on successful stdout.
The existing three-argument comparison form retains its interface and silent
success. Both forms require a regular file (including a symlink resolving to a
regular file). Relative paths resolve from the caller's working directory.

The verifier owns backend selection: native `sha256sum`/`sha512sum` when available,
otherwise Perl's `shasum`. It hashes the file through stdin, so spaces, leading
dashes, backslashes and newlines in filenames do not become options or escaped
checksum records. Embedded NUL bytes are rejected before shell capture can discard
them. File-read errors, backend failures and malformed output fail without emitting
a digest; a failing backend is never retried through another.
No network access or build is involved.

Toko Tooling uses this same owner for IC installer receipts and snapshot
manifest generation. Their existing manifest formats are unchanged. Digest
support for arbitrary filenames does not widen those formats: IC receipts still
use unescaped line records and reject backslashes/newlines. Failed receipt
traversal or hashing preserves the candidate and previous active toolset.

Consumers already vendoring `verify-file-checksum.sh` need no additional shared
file for digest generation. After refreshing its committed snapshot, replace
only the file-hash bodies in IcyDB/Canic Wasm reports with `--print`; keep report
schemas, subject selection and stream/tree identity encodings local.

## Isolated RustSec database preparation

```sh
# The parent directory exists; rustsec-attempt must be a new path.
bash scripts/ci/prepare-rustsec-db.sh online \
  https://github.com/RustSec/advisory-db.git "$work_dir/rustsec-attempt" || exit $?
cargo audit --no-fetch --db "$work_dir/rustsec-attempt/db"
```

Select exactly `online SOURCE DESTINATION` or `local SOURCE DESTINATION`.
Online mode requires an explicit HTTPS repository URL without embedded credentials,
query parameters or fragments; it creates a fresh shallow clone with Git's
low-speed connection protection and terminal prompts disabled. It resolves the
moving feed to the commit actually cloned. This records the observation, not a
pin for future refreshes. Git configuration and available credentials remain
host-owned; the helper does not install credentials or alter Git configuration.

Local mode takes an existing Git repository directory and selects its committed
HEAD before cloning. It never copies working-tree edits or untracked cache files.
It clones without hardlinks, dissociates borrowed objects, and checks out that
exact commit, retaining failure if it cannot obtain it. This allows the prepared
database to outlive the selected cache. Only the file transport is allowed in
local mode; there is no network fallback. Neither mode recurses into submodules.
Inherited repository-specific Git environment variables cannot redirect these
operations into another checkout.

The helper exclusively creates DESTINATION, rejecting occupied paths and symlinks.
Its parent must already exist. Within it, `db/` is the isolated checkout,
`prepare.log` records source/mode and Git diagnostics, and `revision` records the
verified full commit on success. Successful stdout contains that same commit.
Preparation failures retain the destination
and log, report its location, and omit the success revision. Invalid arguments or
an unavailable local directory fail before claiming a destination.

The caller owns this directory and its evidence lifetime on both success and
failure. Preserve failed attempts; choose a new destination when retrying. Do
not attach an unconditional cleanup trap that deletes the only failed evidence.
Retain `revision` beside the resulting audit evidence. Preparation success proves
isolation and source identity, not database schema validity, advisory freshness
or a passing security audit; Cargo audit remains the database reader.

Consumers must stop on preparation failure and invoke their audit with `--no-fetch`
against the prepared `db/`. Canic retains dependency fetching, lockfile selection
and its risk inventory; IC Query retains warning/exemption policy and subsequent
cargo-machete ordering. Neither adapter should let cargo-audit fetch again and
change the recorded database identity. The helper never invokes Cargo, selects
exemptions or changes a shared advisory cache.

Adopt `scripts/ci/prepare-rustsec-db.sh` and this guide from a reviewed committed
snapshot before replacing consumer preparation bodies. It requires Bash 3.2+
and Git, with no shared-script dependencies. `test-rustsec-db.sh` covers simulated
online/failure cases and real local isolation using existing Git history; it
neither creates commits nor performs a live vulnerability audit. Consumer tests
must retain policy/order checks and prove audit cannot run after preparation fails.

## Local Cargo.lock versions

Use the explicitly prepared IC Build release editor for manifest and local lock
versions. Its lock renderer changes only selected unsourced package versions and
exact unqualified local references. Toko Tooling retains originals and runs
locked/offline Cargo graph validation before completing preparation.

See [Cargo candidate rendering](../releases/releases.md#cargo-release-candidate-rendering) for
the required executable and byte-allowance selections. Candidate bytes are never
redirected onto their inputs. Tool preparation, package selection and release
authorization remain consumer-owned.

## Coordinated Cargo graph admission

`cargo-release-metadata.sh check-graph PRIMARY_PACKAGE` validates regular root
Cargo inputs, locked/offline resolution and the complete coordinated workspace/
local-lock roster without requiring release notes or dates. It performs no
version writes, fetching or compilation. The existing `check` operation adds
release-note/date admission; both retain selected-commit and failed-evidence
semantics. Consumers can project a successful Cargo member document through
`cargo-workspace-members.jq` after a literal manifest bump; use full locked
resolution for the final graph check rather than treating `--no-deps` as proof.

`compare-stable-versions.pl VERSION BASELINE` prints -1, 0 or 1 using exact
canonical decimal component ordering. It rejects malformed stable identities
before output and uses no floating-point or shell-integer arithmetic. The release
finalizer rejects non-increasing previous/target pairs itself.

Approved independently versioned groups use
[`cargo-release-group.sh`](../releases/releases.md#explicit-cargo-release-groups).
Its complete locked member/lock admission is also used by `--cargo-inheritance`
before accepting literal package versions. A group declaration alone never
suppresses inheritance, dependency pinning or graph failures.

## Resolved dependency graphs

Use [the graph checker](cargo-graph-checks.md) to enforce consumer-selected
transitive exclusions and rendered package identity counts. Direct ownership
checks and product feature/lifecycle policies remain separate.
