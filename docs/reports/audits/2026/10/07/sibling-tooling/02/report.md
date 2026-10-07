# Shared Tooling and sibling re-audit — 2026-10-07

Reviewed the pushed **0.1.15** source,
`bfb50bd0884b5e6c5ee9592056531c6108f96d73`, initially clean, following the
maintainer's request for another code and sibling review. Methods:
`audits/flow-convergence-and-duplication.md` and `audits/code-hygiene.md`, under
`audits/README.md` and this revision's `AGENTS.md`/`DRAGGINZGAME.md`.

The scope is common tooling, distribution, setup, release adapters, publication
wrappers and their fixtures. All 13 siblings were inventoried; deeper source
traces followed the largest relevant local implementations. Product runtime
correctness, live deployment, registry payload identity and whole-workspace
qualification are outside this review. Consumer policy stays local. This report
does not certify every file in every repository.

**Verdict: FAIL for the two reproduced boundary defects below; structural review
has findings.** The pushed Shared Tooling CI nevertheless passes its existing
Linux, macOS Apple Silicon, macOS Intel and lint/security jobs:
[exact-source CI run](https://github.com/dragginzgame/shared-tooling/actions/runs/37593142226).
That run lacks the new failing cases and does not qualify Canic's publisher.

## Inventory and comparison

[Measurement identities](measurements.json) preserve each checkout's initial
HEAD, dirty flag, snapshot selection and counts. The method and totals match
[run 01](../01/report.md): siblings have **78,862 tooling code LOC**, consisting
of **33,467 shared** and **45,395 local**, plus **9,644 supporting data lines**.
Matching vendored copies already have one owner. Local LOC is not all redundant.
The two CODEOWNERS files remain excluded by cloc; no selected snapshot file
drift was reported.

Several consumers were being changed independently. Canic advanced from
`8db6ff3ac40e49783a98fdd50a0ea0088c2872c4` to
`5e0dd13f7b494e800201841223a6167b544a5892`; IC Backup advanced from
`eece44dac79da1bfb36f82ce2cd30d51edd3a9c1` to
`750e4123b56c03c7044f5c1f5a6f2629ad6f5ff5`. The implicated publisher/fixture
files are unchanged across those commits and in the inspected working trees.
IC Blob Storage's fixture is unchanged at
`c727dbc87c07c92738a4cb0d75d2fb0825e32878`.

## Findings and ownership trace

1. **MEDIUM — the new inventory reconstructs the snapshot contract incorrectly.**
   `refresh-consumer.sh --manifest config/.shared-tooling.snapshot` exports paths
   relative to the consumer root; `cloc-tooling.pl::load_snapshot` instead joins
   them to the manifest's directory. A canonical, successfully verified fixture
   reports **198 local / 0 shared LOC**. Moving only the manifest to the root
   changes that to **0 local / 198 shared**. An equivalent SSH source spelling
   also passes canonical verification but makes the report fail. The actual
   sibling layouts in this measurement do not trigger these cases. Converge
   interpretation on the distribution owner, explicitly distinguishing custom
   manifest placement from a nested consumer root; preserve multiple manifests
   and IC Timers' independently rooted helper snapshot. Do not guess a root from
   whichever file happens to match. Owner and focused acceptance:
   [Shared Tooling #39](https://github.com/dragginzgame/shared-tooling/issues/39).

2. **MEDIUM — release tests maintain three versions of the same Git simulation.**
   IC Backup's local release fixture is 767 code LOC; IC Blob Storage's is 672.
   Both `make release-check` targets already run the canonical shared runner
   fixture alongside their local suite. Each local suite nevertheless implements
   fake commit ancestry, stage state, annotated tags, remote refs and lost
   commit/tag/push replies. Map assertions first, then remove runner-only
   duplication. Keep actual Make-to-adapter wiring, receipt and metadata custody,
   selected-commit checks, failed restoration, real index boundaries and
   publication policy local. Extract minimal common effect substitutes only if
   the remaining integration proof still requires them; avoid a general fixture
   framework. **1,439 LOC is the affected surface, not a deletion estimate.**
   [Shared Tooling #40](https://github.com/dragginzgame/shared-tooling/issues/40)
   owns convergence; consumer work is tracked in
   [IC Backup #18](https://github.com/dragginzgame/ic-backup/issues/18) and
   [IC Blob Storage #22](https://github.com/dragginzgame/ic-blob-storage/issues/22).

3. **MEDIUM — Canic's publisher fails before admission under Bash 3.2.**
   `scripts/ci/publish-workspace.sh:72` uses `declare -A` for observed packages.
   An isolated copy with substituted version/admission helpers exits 2 under
   Bash 3.2.57: `declare: -A: invalid option`. A refusing Cargo substitute is never
   invoked. Use a portable representation over the existing fixed package order;
   retain observation reuse, suffix/predecessor completeness and log/timing
   evidence. This is a Linux execution of Bash 3.2, not native macOS publication
   proof. Owner: [Canic #477](https://github.com/dragginzgame/canic/issues/477).
   Its separate unknown-registry-result problem remains owned by
   [Canic #462](https://github.com/dragginzgame/canic/issues/462).

## Retained boundaries and earlier findings

The earlier validation-logger and whitespace-finalizer findings remain separate
work: [#37](https://github.com/dragginzgame/shared-tooling/issues/37) and
[#38](https://github.com/dragginzgame/shared-tooling/issues/38). Toko Miner's private
ShellCheck installer remains the straightforward existing reuse target in
[Toko Miner #23](https://github.com/dragginzgame/toko-miner/issues/23). This run
does not manufacture additional copies of those issues or claim adoption.

Do not move complete publication pipelines into a new shared engine. The
reviewed IC Host Tooling adapter already delegates workspace ordering and upload
to Cargo, while Canic and IcyDB retain different receipts, resume/completeness
rules and evidence. Any later simplification must map those obligations before
retiring orchestration. Likewise, product Wasm analysis policy, release metadata
sets, asset/fleet/staging commands and runtime qualification remain consumer-owned.

## Execution and evidence

Fresh Linux checks: the real 14-checkout JSON inventory and existing
`test-cloc-tooling.sh` pass. The canonical refresh/verification controls pass;
the two additional inventory probes reproduce the contract mismatches. The
isolated Canic publisher probe reproduces the Bash failure without Cargo or
network effects. Documentation links and diff checks pass. No broad local gate,
consumer build or consumer release suite was run; no fixes, package version
changes, commits, real tags, pushes or publication were performed.

Host/tools: Linux x86_64, Git 2.43.0, cloc 2.10, Perl 5.38.2, Bash 5.2.21 and
Bash 3.2.57. Raw artifacts and scripts remain at `/tmp/shared-reaudit.vSexoP`,
including the initial refused no-checkout fixture setup; the successful snapshot
probe restored its selected files before export. Full inventory SHA-256:
`cd81e7b44fa68503c6b83a7c3e9dd91c6da7aab993bf420b7f8a43ae053b1756`.
Counter SHA-256:
`ee956c696a775ffb97863488e1c8b09d586e04e84beb53a79ad5c53c0aa3acbd`.
Canic publisher SHA-256:
`8b53b1ae6159f0026426222a8510b9bc9717a9354cfa188c396d6abcab0af069`.
Only this new audit report and its measurement summary were added to Shared
Tooling. No sibling files changed; GitHub issues own all follow-up work.
