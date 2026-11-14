# Current fleet plan

Maintainer direction, updated 2026-11-14.

## Architectural reconstruction

**IC DB (`ic-db`), Canic (`canic`) and IC Query (`ic-query`) are being recoded.**
The intent is to replace accumulated legacy code, obsolete plans and overlapping
responsibilities with coherent implementations based on current requirements.
This is architectural reconstruction, not a programme of small cleanups that
leaves the old design intact.

For these three repositories:

- Establish the current purpose, required behaviour and responsibility boundaries
  with the owning agent and repository's current instructions before implementing.
  A collection of tangled concerns is not automatically a valid subsystem.
- Treat old code, roadmaps, plans and package boundaries as research inputs.
  Their existence does not make them requirements, acceptance criteria or a
  feature-parity obligation. Do not revive obsolete work merely to complete an
  old checklist.
- Replace a defined responsibility end to end: implementation, actual callers,
  behavioural tests and current documentation. Retire superseded mechanisms and
  misleading guidance within that accepted scope; avoid permanent parallel paths.
- Preserve explicitly required public behaviour, data, security and recovery
  guarantees. Establish which existing contracts remain required before changing
  them; this direction does not authorise destroying live data or history.
- Coordinate with the active repository owner. Do not impose migrations derived
  from the legacy design or interpret a changing checkout as completed adoption.
  Product requirements and acceptance evidence remain with the product repository.

Apply the existing [subsystem replacement guidance](../principles/subsystem-replacement.md)
and [baseline](../../TOKO-TOOLING.md#complete-reviewable-changes). The desired
deliverable is a coherent replacement, not repeated small changes that preserve
the complexity the reconstruction was meant to remove.

## Coordination and maintenance

This plan records direction, not completion or release readiness. Repository
issues own actionable work; their current handoffs own implementation progress,
blockers and evidence. Do not create a duplicate task list here.

The named scope is `ic-db`, `canic` and `ic-query`. This does not declare IcyDB
retired, prescribe a replacement relationship between repositories, or authorise
edits or deployment outside an agent's assigned scope.

Keep this document short and replace superseded direction when the maintainer
changes the plan. It stays in Toko Tooling's reference documentation; do not
vendor copies into consumers or use it as a new release gate.
