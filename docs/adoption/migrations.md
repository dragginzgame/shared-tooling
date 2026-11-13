# Consumer migration history

## Vendor installation in 0.42.0

This minor release moves executable snapshots into `vendor/toko-tooling/`.
The exporter retains upstream bytes and relative layout inside that directory.
Only `TOKO-TOOLING.md`, `LICENSE.md` and `CONTRIBUTING.md` stay at root; the
root `.toko-tooling.snapshot` records physical destination paths and a vendor
layout annotation. Do not hand-edit that receipt or move installed files.

1. Select `=0.42.0` and update every maintained Cargo lock. Keep the old crate
   available for ownership proof; the registry updater downloads it when needed.
2. Inventory actual Make, script, hook and CI callers. Supply a complete
   `--entrypoint` list using **upstream paths**, without the vendor prefix.
   Keep `make/consumer.mk`, the root baseline and the hook if used. Explicitly
   add `make/release.mk` for shared releases, `make/cargo-publication.mk` for
   shared publication, and each directly used helper/action. Drop reference
   docs and producer `scripts/ci/test-*` fixtures; they are rejected in new exports.
3. Run the reviewed installer with `update --preview --snapshot-only --consumer
   /absolute/repository` and those entrypoints. Inspect additions and removals.
   Repeat without `--preview`. `--snapshot-only` avoids invoking the old consumer
   Makefile while its include paths are being migrated.
4. Change the consumer Make include to
   `include vendor/toko-tooling/make/consumer.mk`. Remove an old root-valued
   `TOKO_TOOLING_ROOT` override or set it to `$(CURDIR)/vendor/toko-tooling`.
   Update script calls, source lists, cache inputs and composite-action `uses:`
   paths. For example, use `./vendor/toko-tooling/.github/actions/cache-tool-downloads`.
   Product CI workflows, release policies, configuration and scripts remain local.
5. If the old hook used `core.hooksPath=.githooks`, inspect that directory and
   reconcile any consumer hooks before explicitly unsetting the old local value
   and running `make install-hooks`. The new value is
   `vendor/toko-tooling/.githooks`; setup refuses to replace a different hook
   configuration automatically. Repositories with custom hooks own their dispatch.
6. Run `make install-tools`, `make tools-check`, `make toko-tooling-check`, and
   focused formatting, CI and release-adapter checks for the changed callers.
   Review and commit the pin, locks, receipt, additions, retirements and local
   wiring together. Supplier publication alone does not qualify the consumer.

Use the installed `vendor/toko-tooling/scripts/dev/toko-tooling.sh` for subsequent
direct updates. The old installer can bootstrap the locked newer package; a
reviewed extracted 0.42 installer can also perform the migration. Do not add old
path aliases or wrappers to preserve the former layout.

Retirement requires the exact previous source bytes and mode. Differing existing
destinations now refuse even when clean and committed. Reconcile a collision
explicitly outside the exporter; there is no force-overwrite option. An identical
destination is safe to retry. Preview changes neither consumer files nor tools.
Historical pre-0.42 source exports retain their recorded layout for evidence and
migration fixtures; current installations have one supported vendor layout.

## Bootstrap and binary-test fixes in 0.41.1

The bootstrap observer now admits complete release membership without requiring
unused root dependency aliases. Keep group `members` intact and list only actual
root aliases in each `dependencies` roster. Existing aliases still require valid
paths, requirements and matching policy entries; lock/member identities and
read-only interruption admission remain checked.

Cargo 1.100 can diagnose the mandatory unused tooling dev-dependency in binary-only
unit tests. The installer now also admits this exact source-only marker:

```toml
[target.'cfg(any())'.dev-dependencies]
toko-tooling.workspace = true
```

Move the declaration, do not duplicate it. Keep the exact root pin, Cargo.lock,
member participation and cargo-machete exemption. Standalone packages use the
exact version directly in this table. No dummy Rust import, empty library or
unused-dependency allowance is needed. Upgrade using the released producer
installer before relying on this form: the previous installed verifier rejects
it. Keep strict lint tests for real normal dependencies. Unaffected library
packages may retain unconditional dev-dependencies; no fleet-wide migration is
required.

## Rust 1.100 capabilities in 0.41.0

This release extends the common lint minimum with Cargo's `unused_dependencies`,
`unused_workspace_dependencies`, `unused_workspace_package_fields`,
`missing_lints_inheritance` and `unknown_lints` at deny, plus Rustdoc's
`invalid_markdown_table` at deny. Apply the baseline table to both product and
qualification roots and their inherited members. Remove unused declarations;
do not retain display catalogs through lint allowances or dummy imports.

Use the [tooling adoption choices](../tools/rust-toolchains.md#rust-1100-adoption-choices)
for warning enforcement, artifact discovery, installation and optional cooldowns.
Preserve dev-dependency/feature coverage outside Cargo's lint coverage. Prove a
real warning is rejected with fresh and reused artifacts before replacing a
strict warning command; plain JSON collectors retain their existing refusal.
Do not copy the producer's fixture into every consumer or add a new release gate.
Use existing adapter fixtures and selected source checks. The new cache layout
does not authorize cross-source evidence reuse, cache cleanup or a broad rewrite.

## Package inventory instead of display dependencies in 0.40.2

Use `make deps-list` to view local package versions and release groups. Remove
unused display-only workspace dependencies and their aliases from group
`dependencies` rosters, retaining every package in its group's `members` roster.
Remove lint allowances introduced solely to preserve those unused declarations.
No Cargo.toml group blocks, role sections or changelog comments are required;
this supersedes the older grouping migration below. Existing grouped formatter
support may preserve optional comments without requiring any sections.
Adopt the updated release checker before removing catalog-only aliases: older
snapshots require complete display catalogs. Check actual member inheritance
and release graph admission after cleanup; preserve versions and lock selections.

## Rust 1.100.0 minimum in 0.40.0

Tooling 0.40.0 raises its crate minimum and the shared development/release
compiler policy to Rust 1.100.0. Before adopting it, update each product and
qualification workspace's `rust-version` and compiler pin, including explicit
package overrides and CI selectors. Prepare the pinned compiler, then qualify
the affected locked package/feature graphs and applicable native/Wasm consumers.
Snapshot installation alone does not update those declarations or prove adoption.
This supersedes the compiler minimum recorded in earlier migration entries.

The same release introduces the baseline's
[common Rust lint policy](../../TOKO-TOOLING.md#common-rust-lint-policy).
Adoption is complete only after these consumer-owned steps:

- Reconcile every workspace table and member inheritance, including private
  qualification packages and explicit package-level exceptions.
- Remove blanket nursery/restriction selection and blocking line-count checks;
  retain justified individual checks and review pedantic allowances.
- Remove stale expectations caused by changed selection. Preserve narrow FFI,
  generated-export and configuration-dependent exceptions, stronger safe-package
  prohibitions and meaningful public documentation/debt checks.
- Inspect Clippy/Rustdoc commands and overrides, and run affected native, Wasm,
  feature and macro-consumer checks on Rust 1.100.0. Report unavailable host proof
  separately; do not claim compiler adoption from metadata or snapshot integrity.

Snapshot updates do not rewrite native manifests, toolchain files or CI commands.
Consumer issues track these concrete migrations; updating the tooling pin alone
does not close them. No sibling update or publication happens automatically.

## Online reference documentation in 0.39.5

This replaces the 0.39.3–0.39.4 plan to install shared docs under a separate
directory. Keep root `TOKO-TOOLING.md`, required executable entrypoints and their
runtime inputs; read reference docs, detailed rules, audits and task catalogs
online using reviewed commit-pinned links. Do not copy the reference library or
create `docs/toko-tooling/`. Product docs retain their own topic organisation.

For an existing installation, identify managed files from the snapshot receipt.
Replace consumer-owned links with pinned upstream URLs, then preview a refresh
with the complete retained `--entrypoint` set, omitting reference-document roots.
The exporter retires unchanged files no longer needed by that selection; required
runtime inputs stay. Resolve changed managed copies explicitly, preserve native
files and verify the resulting receipt. Adding entrypoints alone does not remove
old selections. No exporter relocation feature or upstream directory move is
needed. This policy does not automatically refresh sibling repositories.

For example, a consumer selecting `make/consumer.mk`, `TOKO-TOOLING.md`,
`scripts/ci/verify-file-checksum.sh`, `.githooks/pre-commit`, `rules/git-hooks.md`
and `rules/cargo-dependencies.md` retains the first four entrypoints and removes
the two rule documents from its selection. Read those rules through the baseline's
pinned upstream links. Do not expand the snapshot to follow the reference
library's relative links: those links are resolved in the upstream repository.
Check local Markdown links in the resulting consumer, alongside receipt integrity;
the receipt verifier checks owned bytes, not arbitrary documentation links.

For that selection, run this from the consumer root after selecting and locking
the reviewed tooling crate:

```bash
bash scripts/dev/toko-tooling.sh update --preview \
  --entrypoint make/consumer.mk \
  --entrypoint TOKO-TOOLING.md \
  --entrypoint scripts/ci/verify-file-checksum.sh \
  --entrypoint .githooks/pre-commit
```

After reviewing the retirements, repeat the same command with `--snapshot-only`
instead of `--preview`, then run `make toko-tooling-check` and affected consumer
checks. Include any additional executable entrypoints the consumer actually uses
in both commands. This is a complete replacement selection, not an addition.

Plain `make toko-tooling-preview` and `make toko-tooling-update` reuse recorded
entrypoints. If those still include `rules/cargo-dependencies.md`, its declared
companions bring back `rules/engineering-details.md`, contributions, tasks and
audits. “Required” means required by the selected roots; it does not mean those
documents are mandatory for every consumer. Remove the reference roots from the
selection, not their derived records from the receipt. The exporter preserves
canonical bytes rather than rewriting Markdown links in exported copies.

Consumers retaining their own release commands leave `TOKO_TOOLING_RELEASE`
unset (the default is `0`). The shared Make include then provides tooling and
formatting without activating shared release targets. Installed release helper
files do not enable those targets or override the consumer's local release
authority. The common contribution rules describe authorization, not which
release implementation a consumer has enabled.

## Documentation organisation clarification in 0.39.4

Every repository should organise product-owned docs by meaningful topic. That
cleanup can proceed independently during authorised documentation work; no Toko
Tooling update is needed to move native files and repair their local links.

Install shared reference docs only when needed, and keep them separately under
`docs/toko-tooling/` once the canonical upstream paths are migrated. Otherwise,
use pinned upstream links without creating an empty managed directory. The
remaining shared-doc work is a Toko Tooling source-path and reference migration,
not missing exporter relocation support. This patch clarifies the policy; it
does not move exported files. Preserve current receipt-owned paths until the
qualified upstream migration is released, then adopt it through the exporter.

## Documentation ownership policy in 0.39.3

The baseline now specifies a reserved `docs/toko-tooling/` namespace for installed
shared documentation, including rules, audit procedures and task guides. Native
documentation retains its existing topic layout outside that directory; there is
no requirement to introduce `docs/canic/`, `docs/icydb/` or another product wrapper.

This release publishes the policy only. Its exported paths and snapshot format
are unchanged. Do not rename managed files or enable a namespace gate yet.
Toko Tooling must first migrate and qualify its canonical source paths, links,
catalogs and callers. That later release must provide the reviewed entrypoint
mapping and safe refresh/retirement procedure. Until then, receipt verification
continues to govern the installed layout. See the
[ownership boundary](../../TOKO-TOOLING.md#documentation-ownership-boundary).

## Documentation paths in 0.39.0

Guides now live under `docs/adoption/`, `docs/tools/`, `docs/validation/`,
`docs/releases/` and `docs/fleet/`. The old flat paths are removed. Before
refreshing an explicitly selected snapshot, replace old documentation
entrypoints with their new paths and update consumer-owned links. The current
`scripts/distribution/governance-files.txt` lists the comprehensive governance
selection; fleet reports remain producer-only.

For example, select `docs/adoption/consuming-snapshots.md` instead of the old
flat adoption-guide path, and `docs/releases/releases.md` for release commands.
Use the exporter's complete `--entrypoint` selection and preview the refresh;
do not edit snapshot receipts or delete installed guides by hand.

Tool inventories and helper contracts now have focused companion guides.
The exporter follows their declared companions. Existing reviewed snapshots
remain usable until deliberately refreshed.

## Consumer Make changes in 0.39.0

Shared release commands now require `TOKO_TOOLING_RELEASE := 1` before including
`make/consumer.mk`. Set it only for consumers with the required release adapters;
otherwise shared release and cleanup targets are absent. Directly including
`make/release.mk` remains an explicit selection. This is a breaking Make interface
change; consumers already using the shared release runner must add the setting.

For read-only previews through shared prerequisites, use
`make -n check TOKO_TOOLING_DRY_RUN=1`, substituting the desired goal. Shared
formatting, setup, release and publication recipes print without forced execution.
The option refuses without dry-run mode; ordinary failure admission stays enabled.
Review consumer-owned recursive/effectful recipes separately, as described in the
[Make interface](make-interface.md). The shared `ci` target is phony even when a
`ci/` directory exists; product CI checks remain consumer-owned.

## Baseline filename migration in 0.37.0

This is a hard cut to the Toko Tooling name, including `TOKO-TOOLING.md`,
`scripts/dev/toko-tooling.sh`, `.toko-tooling.snapshot`, Make targets prefixed
`toko-tooling-`, environment variables prefixed `TOKO_TOOLING_`, and
`package.metadata.toko-tooling.loc`. There are no command or filename aliases.
Existing reviewed snapshots remain usable until deliberate adoption.

Update the exact Cargo pin and Cargo.lock together. Bootstrap with the installer
from the reviewed new crate, rather than assuming an older installed script can
run the new contract. Preserve the existing receipt: pass its current relative
path with `--manifest` during migration. Select the complete entrypoint set with
repeated `--entrypoint`, replacing renamed paths and preserving other roots.
The exporter authenticates the prior crate and retires unchanged owned files;
never edit receipt hashes or delete modified files to bypass admission. After
refresh, move the receipt to `.toko-tooling.snapshot` and update consumer-owned
Make callers, CI, environment settings, instruction links and LOC metadata in
one adoption batch. Use an explicit manifest setting until that move is complete.

For Git provenance changes, use `refresh-consumer.sh --previous-source` with a
checkout retaining the recorded origin and revision. The new source must contain
that prior revision in its ancestry. Git-to-crate migration uses the installer's
`--source` argument for the same explicit proof. Redirects alone are not identity
proof. Preview first and retain the old receipt until admission succeeds.

### Adoption choices and prerequisites

Adopting the crate also adopts its Rust 1.99.1 minimum. Its
`package.rust-version = "1.99.1"` applies when Cargo builds it as a dev-dependency
in every member's test graph, even though the crate distributes tooling and needs
no Rust imports. Cargo/Rust 1.91 cannot build those tests. Prepare a compiler that
satisfies this requirement before running tests or other commands that compile
dev-dependencies; this requirement is separate from snapshot installation.

- Keep the exact root Cargo pin inherited by every real member, Cargo.lock and
  installed-byte verification. A single carrier or metadata-only pin is not an
  alternative selection contract.
- Before hook activation, inspect tracked symlinks. The formatting hook requires
  regular tracked files, even for internal links permitted by the general source
  policy. For agent instructions, use a regular `AGENTS.md` and a regular
  `CLAUDE.md` containing `@AGENTS.md`. Commit removal of a replaced local hook
  before refreshing: the exporter will not overwrite staged deletions.
- Prepare jq, Mike Farah yq v4, Perl with JSON::PP and Digest::SHA, and Cargo.
  Archive refresh also needs Archive::Tar and IO::Uncompress::Gunzip. Installation
  checks these prerequisites before extracting or changing the snapshot.
- Run `bash scripts/dev/toko-tooling.sh update --preview` or
  `make toko-tooling-preview` to inspect without changing consumer files or tools.
  Preview downloads authenticated archives into external temporary scratch.
  Use `--snapshot-only` or `make toko-tooling-update TOKO_TOOLING_INSTALL_TOOLS=0`
  to apply files without installing tools; prepare tools explicitly before checks
  or workflows that require them. Normal update still installs and checks tools.
- Select executable entrypoints for the runtime closure. Governance guides are
  explicit optional entrypoints, not companions of runtime scripts. Adopt the
  baseline either as the standalone `TOKO-TOOLING.md` entrypoint or
  through a reviewed revision-bound link. The crate still contains the full source
  bundle; a smaller consumer snapshot does not change that distribution.
- Common engineering rules, integrity and execution admission remain mandatory.
  Product architecture, limits, supported targets and local commands belong in
  the consumer overlay. Conflicts such as existing Python tooling need a scoped
  maintainer-approved exception with its reason; they are not implicit defaults.
  Review conflicts before claiming baseline adoption. Snapshot installation and
  policy adoption are distinct results.

The current adoption contract remains exact Cargo selection plus authenticated
export and offline admission. Future incompatible adoption changes require a
minor release and an explicit migration guide; this pre-1.0 contract provides no
deprecation aliases. Verify snapshot integrity, local links and affected callers
before claiming a completed upgrade.

## Explicit IC tool selection in 0.26.0

After this release is reviewed and available, refresh through the canonical
exporter and update IC callers together. Do not export an uncommitted producer
working tree or remove catalog rows to express a subset.

- Declare the needed names in `IC_TOOLS` before including `make/consumer.mk`.
  For example, an optimizer-only job selects `IC_TOOLS := wasm-opt`. Products
  that need the complete set explicitly name `didc ic-wasm icp quill wasm-opt`.
  Host/Cargo-only consumers need no IC selection.
- Add repeated `--tool NAME` arguments to direct installer/check/preflight calls.
  Setup and checks must use the same set. The complete catalog remains validated;
  pins, authenticated archives and Binaryen runtime libraries retain their owners.
- Compact collection uses the caller's declared selection, never one inferred
  from installed files. Pass the action's `ic-tools` input, or the new final
  selection argument to direct compact-selector and compact-collector calls. Full
  collection retains its existing interface. An empty
  list retains full IC evidence. IC version reports require both pins and a
  quoted space-separated selection after the common host/Rust catalog.
- Explicitly prepare the selected tools before offline admission. Old bundles,
  failed candidates, archives and release evidence remain retained. Qualify
  actual consumer routing and applicable native hosts; producer fixtures alone
  do not qualify product builds or deployment.

## Dependency-role adoption in 0.24.0

Completing adoption includes the consumer-owned changes below; copying a new
snapshot alone does not classify dependencies or install a deployment gate.
For registry installation, use [Cargo selection and installation](consuming-snapshots.md#cargo-selection-and-installation)
below. The following Git export procedure remains available for historical
provenance, review and snapshot reorganization.

Select a released, reviewed source revision and refresh through the canonical
exporter. Include `rules/cargo-dependencies.md` and `rules/git-hooks.md` in the
governance selection. If the consumer uses selected-source manifest ordering,
also select `scripts/ci/cargo-release-metadata.sh` and its derived companions.
No step depends on a local draft, sibling working tree or `/tmp` proposal.

1. Identify the actual production packages and supported target/feature
   combinations from the consumer's build and deployment entrypoints. Review
   member normal, build, development and target-specific dependency tables.
   Split the root dependency catalog into two sections with the
   [canonical comment headers](../../rules/cargo-dependencies.md#dependency-roles-and-deployment-checks):
   `# Production dependencies` and `# Tests and tooling only`. Put each header
   once above its section, with a blank line between sections; remove repeated
   role annotations after individual dependencies. Entries shared by production
   and tests belong in production; the catalog remains one owner. These headers
   belong only in `[workspace.dependencies]`, never in `[workspace]`, `members`
   or other tables. Remove role headers added outside the dependency catalog.
2. The shared formatting defaults preserve those sections with grouped sorting.
   Remove local `FORMAT_WRITE_COMMAND`/`FORMAT_CHECK_COMMAND` overrides that only
   repeat root-workspace Cargo sort and rustfmt. Keep complete paired adapters
   for additional work such as derive sorting, nested workspaces or frontend
   formatting; retain grouped sorting in those adapters.
   Use the same grouped policy in independent/nested-workspace formatters and
   all existing release adapter calls. Change `--manifest-order` to
   `--manifest-order-grouped` in current, commit-preparation and committed-source
   checks together. Both remain non-mutating; hooks continue to use `make fmt`.
3. Verify snapshot integrity and run the consumer's focused formatting/hook and
   release-adapter qualification. Show that a formatter rerun preserves groups,
   that check mode rejects unsorted entries within a group, and that a committed
   release check reads its selected source. Preserve dependency selections,
   lockfiles, release versions and unrelated work during adoption.
4. Review the production graph with the actual build target/features before
   deployment. Reuse the consumer's existing dependency-policy check to enforce
   any test-only exclusions, including transitive paths. If that enforcement is
   missing, record the remaining consumer work explicitly: Shared's sorter and
   metadata helper do not enforce role classifications. A passing snapshot or format
   check must not be reported as automated deployment admission.

Report baseline/snapshot adoption, formatting activation and deployment
enforcement separately. To request the complete change, say: "Adopt Toko
Tooling with two comment-headed dependency sections and matching formatting and
release checks; qualify the deployment dependency boundary and report any
remaining enforcement gaps." Registry publication remains a separate fact;
neither role labels nor cached build success establishes it.

## Common catalog ownership in 0.10.0

Common installers now bring their reviewed pin catalogs as required snapshot
companions. Make, standalone setup, formatting, freshness checks and the evidence
action use the executing snapshot's defaults. Consumer-local catalog discovery
and implicit host-to-Rust override inheritance are removed. See
[catalog selection](../tools/tool-inventory.md#catalog-selection) for explicit exceptions.

Before adoption, compare existing host/Cargo versions and IC versions/digests
against the selected source commit. Qualify differences or retain an explicitly
selected consumer exception; do not silently replace a product requirement.
Review direct script calls, CI cache inputs, formatter adapters and evidence
action inputs as well as Make. Product and PocketIC selections stay local.
Compiler selectors are consumer-owned files implementing the
[shared support policy](../../rules/cargo-dependencies.md#minimum-supported-rust-version-msrv);
snapshot export does not update them automatically.

For root-layout snapshots, existing consumer-owned `ci/tool-versions.env` or
`ci/ic-tools.tsv` may occupy the new payload paths. Move any still-needed local
selections to a distinct exception/workflow file and update their callers before
refresh. The exporter must retain its normal ownership and collision refusals;
never force an overwrite or hand-edit snapshot ownership. With a nested snapshot,
remove obsolete consumer copies only after all callers use the new defaults or
explicit exceptions. Do not delete catalogs still used by local CI tools.

Preview the full entrypoint closure, adopt the reviewed commit, explicitly run
`make install-tools` and `make tools-check`, then qualify formatting and the
consumer gate on its supported native hosts. Existing installations, failed logs
and release plans remain retained. This is a Toko Tooling breaking selection
change; a library consumer assesses its own published API impact independently.

## Entrypoint selection in 0.7.0

Select the commands and documents the consumer uses with `--entrypoint`; the
exporter derives their transitive shared companions from the selected commit.
The checksum and snapshot verifiers are always included. There is no separate
bundle registry or dependency download during refresh.

This replaces the `--file` / `--add-file` CLI and manually completed file roster.
On first adoption, pass the complete intended entrypoint set with the new
exporter, including locally used helpers, tests and governance documents. Existing
payload records remain ownership evidence; they are never guessed to be roots.
Review `--preview` before applying. As of 0.8.0, omitted previous payloads are
removed automatically after unchanged-source proof; see the retirement rules below.
Consumers can keep every existing payload by explicitly selecting all of them,
then narrow roots in a later reviewed adoption.

The same v1 manifest retains exact payload hashes, modes, source and revision.
`# entrypoint` annotations record selection intent separately from generated
`file` records. Integrity-only readers can still inspect historical manifests.
New exports require both version and entrypoint annotations, checked before
installation and during final verification with `--require-annotations`.
Refresh without recorded entrypoints requires explicit selection. Never hand-edit
payload records to remove ownership evidence, or use an older exporter after
adopting entrypoint selection. The current verifier validates any recorded roots
against the payload roster; byte integrity does not prove that local callers were
all selected or that runtime/host qualification passed.

Directory paths must not contain LF or CR characters. Snapshot refresh and
verification reject them in both supplied and resolved physical paths, including
ancestor directories and symlink destinations. They never trim a forbidden name
into another checkout. Rename an affected operational directory explicitly before
using these commands; existing artifacts are not renamed or deleted automatically.
Spaces and ordinary physical aliases remain supported. Snapshot-relative file
and manifest paths also reject LF, CR and tab characters.

## Shared host and IC storage adoption in 0.5.0

Select both host/IC installers, `scripts/ci/select-tool-evidence.sh` and the
failure evidence action. The exporter derives `scripts/dev/tool-store.sh` and
the other declared companions, including `scripts/ci/test-tool-store.sh` when
installer fixtures are selected. Review that complete closure in the preview.

Run `make install-host-tools`, `make install-ic-tools`, then their offline
checks. Existing command/PATH entries remain `.tools/host/bin` and
`.tools/ic/bin`; these now resolve to shared bundles. The previous physical
checkout-local bundles remain retained but no longer pass active installation
checks. Use one explicit store setting for setup, checks and failure collection;
see [storage configuration and retention](local-setup.md#shared-executable-storage).
Consumers must not copy payloads or invent their own cache/link manager. Rust
tool installation and PocketIC ownership are unchanged in this batch.

This storage-admission change requires a Toko Tooling minor release. A consumer
library adopting it still classifies its own release by its published contract;
setup changes alone do not require a library minor release.

## CI installer command in 0.11.0

Replace `install-actionlint.sh`, `install-gitleaks.sh`, `install-shellcheck.sh`,
and `install-sccache.sh` calls with `install-ci-tool.sh TOOL`, where
TOOL is respectively `actionlint`, `gitleaks`, `shellcheck` or `sccache`.
Keep existing `--version`, `--sha256` and `--install-dir` arguments and local pins.
There are no forwarding aliases in 0.11.

The former `install-yq.sh` and `install-ci-tool.sh yq` routes are retired. Use
`make install-host-tools` and offline `make host-tools-check`, with yq selected by
the reviewed host catalog. Retire the standalone installer call and its duplicate
pin only after callers use `.tools/host/bin/yq`; retain explicit qualified host
catalog exceptions through `HOST_TOOL_VERSIONS`.

As of 0.16.0, every invocation must include `--install-dir`; an environment-only
destination or the former home-directory default is no longer accepted. Update
callers before refreshing the command and its selected installer fixture.

Before refresh, replace each recorded wrapper entrypoint with
`scripts/ci/install-ci-tool.sh` in the reviewed selection. Pass the complete new
root set with repeated `--entrypoint` arguments; `--add-entrypoint` alone retains
the old roots. Use the normal preview and owned-file retirement checks to remove
snapshot-owned wrappers; preserve modified or consumer-owned files for review.
Refresh `test-installers.sh` too if selected, then qualify the same installer
failure cases and each declared native host. No storage layout or tool upgrade
is part of this command change.


