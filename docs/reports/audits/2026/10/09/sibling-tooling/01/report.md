# Sibling tooling duplication audit — 2026-10-09

**Verdict: PASS WITH FINDINGS for the bounded tooling review.** The immediate
reduction is optional fleet-report adoption: **5,061 code LOC across 13
consumers** can be reviewed for removal. These are verified vendored copies,
not 5,061 lines of independently maintained implementations or achieved savings.

## Scope and evidence

Method: [flow convergence and duplication](../../../../../../../../audits/flow-convergence-and-duplication.md),
under Shared Tooling `635a39a9dd5f8d021fa9c9196b591e00521a7e02` and its
`AGENTS.md`/`DRAGGINZGAME.md`. Trigger: maintainer request for further 0.1.33
work and sibling duplication reduction. Existing dirty dashboard changes were
preserved. The new Make diagnostic, fixture and adoption guidance are uncommitted
0.1.33 work, not an adoptable snapshot revision.

The read-only inventory covered all 17 immediate Git checkouts using cloc 2.10:
`perl scripts/dev/cloc-tooling.pl --json /home/adam/projects`. Findings cover the
15 connected sibling repositories, excluding Shared Tooling itself and the
unconnected `ichelper` checkout. Their tooling measures **126,177 code LOC**:
**69,624 verified shared** and **56,553 local**. Most local code is not proven
redundant. Supporting data, docs and product runtime code are separate; two
consumer CODEOWNERS files were skipped by cloc. No snapshot drift was reported.

[Measurements](measurements.json) record the inventory identities, dirty flags,
selected snapshot revisions and candidate file hashes/counts. These are
working-tree observations; multiple siblings were under active development.
Raw inventory and focused logs remain in `/tmp/shared-033-duplication/`. This
report is immutable evidence, not an issue-status ledger. Product correctness,
whole-workspace builds, deployment and native consumer adoption were not audited.

## Finding: common setup unnecessarily carries fleet reporting

**LOW — ownership leak / unnecessary adoption.** The engineering baseline assigns
cross-repository inventories to Shared Tooling, but the common tool adoption
instructions also required `scripts/dev/cloc-tooling.pl` in every consumer.
Thirteen consumers carry it; several schedule its tests in Make or CI. This adds
vendored footprint and consumer qualification work without benefiting their own
workspace setup or LOC reporting.

Trace: consumer Makefile includes `make/tools.mk`; setup and offline checks call
their installers, while local `cloc` calls `scripts/dev/cloc.sh`. Only the explicit
`cloc-tooling` target calls `cloc-tooling.pl`. Shared Tooling additionally selects
`cloc-siblings.sh` for its own `cloc` entry point. These fleet reports can remain
centrally owned without becoming dependencies of every product checkout.

The 0.1.33 change corrects the adoption instructions and gives an omitted optional
report a clear diagnostic. Existing selected reports keep their command and
behavior. The fixture qualifies common setup/check/local LOC without a fleet
report and explicit report selection under a snapshot path containing spaces.
There is no implicit sibling execution, download, new framework or automatic
snapshot deletion. Upstream owner: [Shared Tooling #83](https://github.com/dragginzgame/shared-tooling/issues/83).

Consumer issues carry concrete file lists and acceptance checks:

| Consumer | Candidate code LOC | Adoption issue |
| --- | ---: | --- |
| IC Memory | 665 | [#34](https://github.com/dragginzgame/ic-memory/issues/34) |
| IC Blob Storage | 640 | [#37](https://github.com/dragginzgame/ic-blob-storage/issues/37) |
| Canic | 469 | [#500](https://github.com/dragginzgame/canic/issues/500) |
| IC Backup | 405 | [#30](https://github.com/dragginzgame/ic-backup/issues/30) |
| IC Metrics | 405 | [#38](https://github.com/dragginzgame/ic-metrics/issues/38) |
| IC Timers | 405 | [#33](https://github.com/dragginzgame/ic-timers/issues/33) |
| IcyDB | 398 | [#331](https://github.com/dragginzgame/icydb/issues/331) |
| IC Auth | 279 | [#5](https://github.com/dragginzgame/ic-auth/issues/5) |
| IC Host Tooling | 279 | [#32](https://github.com/dragginzgame/ic-host-tooling/issues/32) |
| IC Jobs | 279 | [#1](https://github.com/dragginzgame/ic-jobs/issues/1) |
| IC Query | 279 | [#31](https://github.com/dragginzgame/ic-query/issues/31) |
| IC Testkit | 279 | [#39](https://github.com/dragginzgame/ic-testkit/issues/39) |
| Toko Miner | 279 | [#40](https://github.com/dragginzgame/toko-miner/issues/40) |
| **Total** | **5,061** | |

Counts include only the listed fleet reporters and their dedicated tests, not
Make/CI/help references. Owners should retain intentional local uses explicitly
and remove unused files, snapshot records and callers together. Preserve local
`cloc.sh`, the installed cloc executable, checksum/snapshot helpers needed by
other selections and product integration checks. No consumer files were edited;
the shared change adds a small diagnostic and focused coverage, so there is no
net code deletion in Shared Tooling from this batch.

## Other candidates and retained boundaries

- **Cargo tool installation remains the next extraction candidate**, under
  [#65](https://github.com/dragginzgame/shared-tooling/issues/65). Toko Miner's
  local Blob example installer and fixture measure 124 + 208 code LOC. They are
  an affected surface, not a removal estimate. The existing native assessment
  passed Linux but stopped on both macOS receipts; 0.1.32 corrects the profile
  admission, but no corrected native assessment was available in this review.
  Qualify that existing path before extracting production installation mechanics;
  preserve exact selection, local receipt/path checks, failure retention and
  consumer profile policy. No new installer or qualification run was started.
- **Retain consumer release-fixture ownership.** Backup and Blob's current local
  release fixtures measure 815 and 856 code LOC. Their closed assertion maps and
  [shared #40](https://github.com/dragginzgame/shared-tooling/issues/40) explain
  why retained Git substitutes support different receipt, metadata, historical
  source and publication obligations. Generic runner cases were already retired.
  Raw similarity is insufficient grounds to replace them with a general mock
  framework or delete those checks.
- **Keep product orchestration with its owner.** Canic/IcyDB Wasm reports select
  different artifact rosters, build and evidence contracts; Toko/Miners' local
  fleet orchestration includes deployment authority and recovery. Large file
  counts alone do not justify moving these scripts wholesale into Shared Tooling.
  Timers' already-dirty failure collector delegates to the shared archiver; its
  [existing adoption issue](https://github.com/dragginzgame/ic-timers/issues/30)
  remains the owner, without another competing change.

## Validation and delivery boundary

The focused tool-command fixture passes on Linux Bash 5 and genuine Bash 3.2;
ShellCheck, documentation checks and the complete portable suite pass. The
focused tool-command checks use substitute installers and
reporters; they do not install tools or qualify native consumer builds. No sibling
builds, source edits, commits, pushes, releases or workflow dispatches occurred.
Consumer removals and native qualification remain with the linked owners.
