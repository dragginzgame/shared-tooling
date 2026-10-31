# Core and integration dependency boundary audit

Date: 2026-10-31. Verdict: **PASS WITH FINDINGS** for structural scope, not
runtime, publication or release qualification.

## Scope and identities

The maintainer requested a fleet rule and sibling audit after IcyDB adoption
was held by its Canic stack. This central audit applies
[complexity and technical debt](../../../../../../../../audits/complexity-and-technical-debt.md)
and the [common evidence contract](../../../../../../../../audits/README.md)
from Shared Tooling `62edfbd43087a718bf0283e9040676a49211976d`. The proposed
[core boundary rule](../../../../../../../../rules/rust-workspaces.md#core-and-integration-graph-boundary)
is a working-tree change, not an adopted consumer snapshot.

Inspect 16 active sibling root workspaces, their 165 members, two independent
Canic Blob consumer workspaces and Persistence's independent runtime workspace.
Review manifests, overlays, dependency callers, maintained qualification templates
and relevant owning issues. This is dependency ownership and upgrade-coupling
inspection, not a comprehensive implementation, security or API audit.

Exclude Toko/Toko Miner, asset and frontend repositories: these are application
compositions rather than reusable producers in this scope. Exclude the old
ic-host-tooling checkout, whose remote is the same ic-tooling repository.
Historical audit manifests, generated build trees, vendored IC and frozen
experiments are not additional maintained core workspaces. Review the native
Profiler's declared codec boundary and existing work without rebuilding IC.

| Workspace | Observed commit | Working tree |
| --- | --- | --- |
| canic | 247ba9d35996 | Pending local edits included |
| ic-auth | bd5f3fc55537 | Pending local edits included |
| ic-backup | 2c34f91ce7fb | Pending local edits included |
| ic-blob-storage | 7fe95703365d | Pending local edits included |
| ic-crates | 3c67db335dc0 | Pending local edits included |
| ic-observability | 691fb85ace51 | Clean when observed |
| ic-persistence | b20098dd1f6a | Pending local edits included |
| ic-platform | 2e604060f929 | Clean when observed |
| ic-profiler | afe9ff725f9c | Pending local edits included |
| ic-query | ad77b3f13813 | Pending local edits included |
| ic-relay | 1391bca5b420 | Pending local edits included |
| ic-replica-watch | beca69e305c2 | Clean when observed |
| ic-scheduling | 4746b54e26d8 | Pending local edits included |
| ic-tooling | 85f759d7e964 | Pending local edits included |
| ic-wire | c9d4e7b45b9b | Pending local edits included |
| icydb | 63a70613afc5 | Pending local edits included |

Local declarations include pending edits; a commit or compatible requirement is
not registry publication evidence. Platform, Profiler, Relay and Wire inputs
changed during review; affected metadata was observed again. Platform #109
merged during the audit and is treated as completed cleanup. The local Canic
declarations are newer than the published 0.113 adapter selected by IcyDB.

Detailed source/overlay/manifest hashes, dirty-path inventories, Cargo JSON and
resolver diagnostics are retained at
`/tmp/dragginz-core-boundaries-20261031-01/`. Raw sibling source, issue bodies
and generated IC payloads are not copied into this report.

## Ownership and state-space map

- Engines own arithmetic, authentication, codecs, database/storage semantics,
  timer execution and generic Host mechanics at their package owners.
- Adapters own exports, lifecycle composition and matching runtime/type identities;
  applications own deployment and installed acceptance.
- Independent axes are core target/features, adapter stack selection,
  workspace/lockfile boundary and qualification-gate selection. Qualified stacks
  in independent graphs are valid; conflicting executors in one graph are not.
- Comments, publication flags and default-members do not prove independent
  resolution. A cycle formed by collapsing packages to repository names is not
  itself a Cargo package cycle or a runtime defect.

## Findings

### 1. MEDIUM — IcyDB development resolves its consumer framework stack

**Owner:** IcyDB, with Canic owning the adapter. **Classification:** ownership
debt with demonstrated adoption friction. **Trigger:** the blocked dependency
adoption. Related acceptance: [IcyDB #373](https://github.com/dragginzgame/icydb/issues/373)
and [Canic #590](https://github.com/dragginzgame/canic/issues/590).

The facade has a canic-icydb dev dependency. Its CLI, build helpers and installed
canister fixtures consume the adapter normally in the same workspace. Ordinary
core dependencies do not require Canic, but root lock resolution includes those
consumers. Adoption documentation records rejection of the newer complete stack.
Unpublished supplying-checkout changes do not repair published requirements.

A temporary resolver consumer combining published canic-icydb 0.113.0 and
Platform 0.11.1/runtime fails at Cargo's executor links constraint. Its diagnostic
traces the adapter to Platform 0.8.2's registry executor, conflicting with the
0.11.1 owned runtime guard. This is a minimal incompatibility reproduction,
not an attempted IcyDB update or build.

**Disposition:** fix when completing this adoption. Retain engine invariants in
owner-local tests; place mounting/export/lifecycle composition and its tooling
at the adapter owner or an independent integration graph. Inspect concrete CLI
calls before moving the whole CLI. Preserve precommit response admission,
installed rollback and one memory/lifecycle owner. A retained older integration
stack qualifies only that stack; path-based current-core tests need requalification.

### 2. MEDIUM — Platform checks inherit an incompatible Timers qualification stack

**Owner:** IC Platform. **Classification:** qualification ownership debt.
**Trigger:** updating the installed runtime fixture and its gate ownership.

The generated cdk-runtime workspace already has a separate lockfile, but its
canister always declares ic-timers; the producer catalog selects 0.32.3. Advisory
preparation also prepares this composed runtime graph. A resolver consumer of
current local Platform/cdk and published Timers 0.32.3 reproduces the executor
links conflict through Timers' Platform 0.8.1 dependency. Separate physical
resolution alone has not removed unconditional qualification coupling.

**Disposition:** fix when updating these fixtures. Distinguish installed proof
of Platform's own callback/trap/cancellation/upgrade contracts from its Timers
composition. Retain meaningful owner proofs and the combined fixture's matching
stack; attach composed acceptance to changes affecting that integration. Review
gate ownership explicitly. Do not weaken singleton guards or silently omit
required runtime or release acceptance.

### 3. LOW — The fleet graph catalog describes retired workspace boundaries

**Owner:** Shared Tooling. **Classification:** stale maintenance evidence.
**Trigger:** the next graph/catalog update.

The catalog requires separate ic-jobs and ic-timers checkouts, although both now
belong to ic-scheduling, and retains retired ic-call entries. The actual read-only
stack-graph check stops with `Missing checkout: ic-jobs`, leaving the overview
stale. An adoption order inferred from it can misstate core prerequisites.

**Disposition:** refresh when updating the graph. Catalog current owners and
retain package-level dependency kinds and core/integration distinctions.
Regenerate overview and evidence together; a repository-only cycle must not
imply that every package needs the same release sequence. No catalog/generator
repair was made by this audit.

## Three bounded change rehearsals

| Change and owner crossing | Observation |
| --- | --- |
| Upgrade the application runtime while retaining Canic 0.113; IcyDB crosses its adapter through tests/CLI/fixtures | Published adapter plus Platform 0.11.1/runtime is refused; isolate composition instead of weakening identities |
| Qualify current Platform against its catalogued Timers 0.32.3; producer checks cross the scheduler | Actual local Platform/cdk plus published Timers is refused; distinguish owner and composed proof |
| Consume generic Host gzip without a framework | Published Host Artifacts 0.72.1 resolves without Platform or Wire; no primitive workspace split is justified by this graph |

## Retained boundaries and non-findings

| Workspace(s) | Decision |
| --- | --- |
| IC Persistence | Existing separate runtime qualification is a useful model. Keep real governed Memory/Storage and stable-adapter dependencies. |
| Canic | Framework-owned adapters and independent Blob consumers have the right owner. Current canic-icydb does not depend back on IcyDB. |
| IC Scheduling | Jobs is Serde-only; Timers owns its runtime. Shared versions alone do not justify another split. Isolate qualification only for a demonstrated blocker. |
| IC Tooling | Host primitives and Build have no direct Platform dependency. Testkit and IC-specific Host Tools own explicit Platform capabilities. Keep the coordinated workspace absent a concrete primitive-upgrade blocker. |
| IC Observability | Merged [#102](https://github.com/dragginzgame/ic-observability/pull/102) makes native metadata optional; Logging stays dependency-free. [Tooling #268](https://github.com/dragginzgame/ic-tooling/issues/268) owns subsequent adoption, distinct from publication. |
| IC Platform / IC Profiler gzip | [Platform #109](https://github.com/dragginzgame/ic-platform/pull/109) is merged. Native provider [#110](https://github.com/dragginzgame/ic-platform/pull/110) and recorder [Profiler #14](https://github.com/dragginzgame/ic-profiler/pull/14) remain draft when observed. Preserve their fresh native acceptance; do not duplicate that prepared cleanup. |
| Auth, Blob Storage, Backup, Query, Relay | No Canic/IcyDB dependency in inspected reusable package paths. Actual Platform, storage and optional runtime duties justify their core edges. Framework-free tests sharing a lock are not alone a demonstrated blocker. |
| IC Crates, Replica Watch | Application/native-tool composition legitimately uses framework or simulator capabilities. Version lag alone is not a direction defect. |
| IC Wire | Pure codec and optional Platform capabilities are distinct. No present conflict was established for current selections; no extra codec crate or speculative workspace migration is proposed. |

## Verification and limits

Cargo 1.99.1 metadata with `--no-deps --locked --offline` succeeded for all
16 root and three maintained independent workspaces. This observes declarations
and members, not full lock consistency, feature closure or compilation. Changed
inputs were re-observed. The two minimal incompatibility probes failed as
described; the Host-only full metadata probe succeeded. Only temporary probe
lockfiles were generated; sibling source, indices and locks were not edited.

The existing stack-graph check failed on the stale catalog; it was not refreshed.
Rule and report links and whitespace checks pass. No Rust builds, code suites,
native IC execution, macOS qualification, releases, publication, performance
measurements or consumer snapshot adoption ran. Missing runtime proof is a
qualification limit, not proof of a runtime correctness failure.

This is an immutable observation and owner-action proposal, not a second work
tracker. Existing issues/PRs retain their acceptance. Implementation is separate
from this policy edit and inspection-only sibling audit.
