# Sibling CI and tooling inventory — 2026-10-07

The 13 sibling repositories contain **78,862 code LOC** in the selected tooling
scope: **33,467 match recorded Shared Tooling snapshots** and **45,395 are local**.
An additional 9,644 physical lines are supporting data. These are working-tree
measurements, not promised deletion counts or a repository health score.

## Scope and evidence

Triggered by the maintainer's request for repeatable tooling counts and concrete
consolidation findings. Method: `audits/flow-convergence-and-duplication.md` with
`audits/README.md`, Shared Tooling `AGENTS.md` and `DRAGGINZGAME.md`. Shared Tooling
base: `25e7ce83149e081e4dcc52c55c33724e44153f2a`; the counter, Make integration,
fixtures and pending 0.1.15 documentation are uncommitted additions. Earlier dirty
setup, governance and Rust LOC work is included and preserved.

Mode: read-only sibling inventory and selected source/caller inspection. Consumer
overlays and runtime invariants were not audited; this is an aggregate Shared
Tooling discovery report, not consumer release qualification. The inventory
captures tracked and nonignored untracked bytes before cloc. It includes scripts,
workflows, hooks, Make/build configuration and Cargo package `build.rs`, including
nested shared snapshots. Product crates, Rust integration binaries outside these
directories, documentation, caches, generated build output and symlinks are out of
scope. JSON, patch and table files count as supporting data rather than code.

[Counts](counts.txt) retain every checkout, including Shared Tooling itself.
[Measurement identities](measurements.json) retain each HEAD, dirty flag, snapshot
revision, totals and skipped/drifted paths. The full per-file JSON is retained at
`/tmp/tooling-inventory.vaIdWt/inventory-final.json` with SHA-256
`1a4d45e713455cf222aa298615f7d007f0aabb6ca197a56eaf09721ccf718ba9`.
That temporary artifact contains file hashes; the checked-in summary is compact
historical evidence, not a live follow-up ledger.

Commands: `make cloc-tooling` and
`perl scripts/dev/cloc-tooling.pl --json /home/adam/projects`.
Host: Linux x86_64, kernel 7.0.0-38-generic; cloc 2.10, Perl 5.38.2, Git 2.43.0.
Counter SHA-256:
`ee956c696a775ffb97863488e1c8b09d586e04e84beb53a79ad5c53c0aa3acbd`.
The two audit methods are unchanged from the base revision; the local overlay
hash is `249a21316d0bf47047dc1dc94a72aab8762aac6ca891fbbf91996b5e38119315`.
The dirty baseline hash is
`3223e7ba5635ac31592a0b3f0c770ef18708f5230fc617883fea9a4fb8656453`.

There is no comparable prior run with this scope. cloc omitted the two CODEOWNERS
files in Canic and IcyDB; no selected snapshot file drifted. Multiple/nested
ic-timers manifests already record its shared installer and fixture copies;
there is no demonstrated provenance gap there. Its HEAD advanced during this
review from `0c90c39` to `e082e04`; the inspected finalizer and fixture are unchanged
between those commits, and the final measurements record the latter.

## Results

| Sibling | CI LOC | Other LOC | Shared LOC | Local LOC |
| --- | ---: | ---: | ---: | ---: |
| canic | 14,552 | 2,173 | 4,587 | 12,138 |
| ic-backup | 3,348 | 2,249 | 3,496 | 2,101 |
| ic-blob-storage | 3,399 | 2,252 | 4,181 | 1,470 |
| ic-host-tooling | 2,666 | 1,328 | 3,189 | 805 |
| ic-memory | 2,900 | 726 | 2,946 | 680 |
| ic-metrics | 2,952 | 1,317 | 3,166 | 1,103 |
| ic-query | 3,853 | 1,839 | 2,094 | 3,598 |
| ic-testkit | 3,038 | 1,163 | 2,449 | 1,752 |
| ic-timers | 4,095 | 3,274 | 3,464 | 3,905 |
| ichelper | 0 | 131 | 0 | 131 |
| icydb | 7,632 | 2,343 | 3,345 | 6,630 |
| toko-miner | 345 | 11,287 | 550 | 11,082 |
| toko-miner-assets | 0 | 0 | 0 | 0 |
| **Sibling total** | **48,780** | **30,082** | **33,467** | **45,395** |

## Ownership trace and findings

The structural review is **PASS WITH FINDINGS**. Separately, the shared changelog
selector has an evidenced contract failure: it misses draft headings with
trailing horizontal whitespace. Its focused reproduction is **FAIL**, tracked in
the owning issue below. No broader correctness verdict is implied.

| Behavior and entry-to-result trace | Canonical owner | Retained consumer contract |
| --- | --- | --- |
| Make/CI setup entrypoints → tool selection → installers/checks/LOC | `make/tools.mk` and shared helpers | Reviewed pins, installed paths and product toolchains |
| Toko developer setup/CI → private ShellCheck installer → verified executable | Shared `install-shellcheck.sh`, `install-ci-tool.sh`, checksum verifier | Pin/destination and refusal to overwrite an invalid existing installation |
| Canic validation targets → dispatch/logging/timing → status and raw evidence | Shared `run-validation-targets.sh`, after evidence contract enhancement | Test membership, target policy, structured product events and release receipts |
| ic-timers bump precheck/write → private draft selector → replacement file | Shared `finalize-release-changelog.awk`, after whitespace fix | Check-only mode, IO atomicity, mode preservation and failure retention |

1. **LOW — copied common Make recipes.** Consolidate setup/check/LOC dispatch on
   the new common include, adopted through a reviewed committed snapshot. This
   reduces inconsistent tool selection and missing commands. Existing consumer
   actions: [ic-query #15](https://github.com/dragginzgame/ic-query/issues/15),
   [ic-metrics #16](https://github.com/dragginzgame/ic-metrics/issues/16),
   [Canic #461](https://github.com/dragginzgame/canic/issues/461) and
   [IcyDB #302](https://github.com/dragginzgame/icydb/issues/302).
2. **LOW — duplicate installer mechanics.** Toko Miner's unchanged
   `scripts/dev/install-shellcheck.sh` is 82 code LOC and is called by developer
   setup and CI. Reuse the shared downloader/verifier with a thin policy adapter.
   Evidence added to [Toko Miner #23](https://github.com/dragginzgame/toko-miner/issues/23).
3. **MEDIUM — divergent validation evidence engines.** Canic's unchanged local
   runner is 245 code LOC and its fixture 156. Its retained success/interruption
   logs, timing table and structured errors must survive consolidation. IcyDB's
   41-LOC wrapper already delegates execution but aggregates raw failure logs.
   Extend the shared evidence contract before deleting Canic's engine; evidence
   added to [Shared Tooling #37](https://github.com/dragginzgame/shared-tooling/issues/37).
4. **MEDIUM upstream defect; LOW duplication — changelog draft selection.**
   A whitespace-suffixed `## [0.1.1]` makes the shared helper emit an empty dated
   release above the existing notes. Reproduction and smallest repair are in
   [Shared Tooling #38](https://github.com/dragginzgame/shared-tooling/issues/38).
   After that fix, replace ic-timers' private selection engine while preserving
   its check-only, exact SemVer, history and transactional file behavior:
   [ic-timers #24](https://github.com/dragginzgame/ic-timers/issues/24).
   Its 108-LOC wrapper and 163-LOC fixture identify the surface, not savings.

## Intentional retention and verification

Keep Canic's product Wasm audit/ablation policy and Toko Miner's asset, fleet,
staging and release-bundle policy local. Their size does not prove duplicate
semantics. IcyDB's Rust size-report binary already uses the shared
`ic_host_artifacts::wasm` inspection API and lies outside this path-based report.
Canic's 7,893 supporting data lines and ic-query's 1,352 are separated to avoid
treating baselines and patches as executable duplication. Existing matching
snapshot copies already have a canonical owner.

The full portable suite, ShellCheck 0.11.0 across the three required script
directories, focused inventory fixtures under Bash 5.2 and 3.2.57, Perl syntax,
documentation links and diff checks passed. The report ran successfully against
all 14 checkouts. Fixtures cover repeated files, spaces in paths, nested/multiple
snapshots, byte/mode drift, excluded paths and retained partial failures.
Logs and reproduction inputs remain in `/tmp/tooling-inventory.vaIdWt`.

No sibling files were edited and no consumer build, deployment or release gate
ran. Native macOS qualification remains for configured CI. The new command is
an additive, compatible pending 0.1.15 change; VERSION remains 0.1.14. GitHub
issues own subsequent work, and consumer adoption requires a reviewed committed
snapshot plus each consumer's focused host evidence.
