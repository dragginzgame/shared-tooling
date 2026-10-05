# Provenance

Shared Tooling is maintained collaboratively across Dragginz Game repositories.

- Canic supplied the initial portable tooling and CI mechanics.
- The first cross-consumer review on 2026-09-03 incorporated IcyDB feedback on
  no-build decisions, state-space control, canonical authority, carried
  decision artifacts, reviewable changes, focused validation, and the boundary
  between shared baselines and project policy.
- The 2026-10-05 changelog review compared the local changelog guidance and current
  ledgers across Canic, IcyDB, IC Backup, IC Blob Storage, IC Host Tools, IC Memory,
  IC Metrics, IC Query, IC Testkit, IC Timers and Toko Miner. Canic and IcyDB supplied
  the main conventions for concise root summaries, minor-line detail files,
  compatibility notes and historical preservation in `rules/changelogs.md`.
  Their reviewed policy files were `docs/governance/changelog.md` at Canic revision
  `481e94d0e93080168fb04546cebb3fc48887a66f` and IcyDB revision
  `8e74b6bac5d054eab9dd9de3435f258d85926040`; those policy files were clean, while
  IcyDB's current ledger included working-tree edits. Shared Tooling retains its
  own draft, release and authority contract; consumer-specific presentation and
  scoped exceptions were not promoted into universal rules. This source review
  does not establish adoption in any consumer.

This record acknowledges sources; it does not make either consumer's local
governance authoritative here. Git history remains the exact source history,
and current repository documents own the maintained shared contract.
