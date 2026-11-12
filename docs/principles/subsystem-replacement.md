# Whole-subsystem replacement

Use this maintainer-invoked approach when an identified architectural problem
keeps producing small cleanups while its competing owners, duplicate state or
fallback paths remain. The outcome is a complete replacement of a bounded
subsystem. The recurring maintainer pain point is identifying a substantial
structural problem, then receiving repeated small cleanups that require another
prompt each time. Internal implementation steps may be incremental; the
deliverable is the complete replacement. Diff size is not a completion measure.

This is optional implementation guidance, not a recurring audit or an automatic
response to frustration. A maintainer explicitly invokes it for a named area.
In engineering requests, "nuke this", "nuke and rewrite" and "the nuclear option"
mean this workflow: validate the responsibility boundary, replace the implementation,
migrate callers, remove superseded machinery and verify the result as one coherent
deliverable. They do not mean leave a deletion-only result. Resolve the named area
from the conversation; ask only when the intended responsibility is materially
ambiguous. Explicit requests to delete an artifact remain separate instructions.
Keep this guide upstream; consumers read their reviewed revision rather than
copying it into local instructions.

## Invoke it

Replace the bracketed fields in this prompt:

> Use Toko Tooling's whole-subsystem replacement for [responsibility]. The problem is [competing
> mechanisms or complexity to remove]. Replace it as one coherent batch;
> incremental cleanup is not the deliverable. Use the existing audit and state
> the replacement boundary, protected behavior and mechanisms to delete, then
> implement without another approval round unless a material decision is missing.
> You may restructure internals, change private interfaces, update required
> callers and replace tests coupled to obsolete machinery. Preserve observable
> behavior, identities, data and recovery guarantees. Finish when one replacement
> owns all in-scope callers, the superseded paths are deleted and focused
> behavioral/recovery checks pass. Keep unrelated edits intact. Keep the work
> bounded to this session; if that is infeasible, identify complete replacement
> slices before starting. Do not commit, publish or deploy unless separately
> authorised.

An already agreed replacement design does not need another planning prompt.
Proceed with that design, revisiting only assumptions contradicted by evidence.

## Quarantine the scope

Validate the architectural boundary before preserving it in a replacement.
An existing directory, dependency cluster or collection of defects is not proof
of a subsystem. Identify one coherent responsibility, its inputs and outputs,
and its callers. Identify tangled concerns that belong to other owners and
separate them as part of the necessary migration. Converge competing
implementations of the same responsibility; retain genuinely distinct ones.
Do not rewrite an accidental collection of concerns as one cleaner monolith.
Keep this boundary check short and grounded in the existing audit.

Quarantine means fixing the work boundary, not adding a new crate, directory,
wrapper layer, feature flag or permanent second implementation. State a compact
contract in the conversation or the repository's existing design/handoff:

| Decision | Required content |
| --- | --- |
| Boundary | Coherent responsibility, inputs/outputs, entrypoints, directly affected callers and concerns that belong elsewhere. |
| Problem | The competing owners, duplicated state or decision paths to remove. |
| Replacement | The single owner and flow that will replace them. |
| Protected behavior | Public behavior, identities, formats, ordering, errors, activation and recovery guarantees relevant to this subsystem. |
| Deletion criteria | Concrete old types, flows, adapters and fallbacks that must disappear. |
| Proof | Existing behavioral tests and focused checks needed for the replacement. |

Use existing evidence. Investigate unresolved boundary or behavior questions;
do not restart a broad audit. Do not create another backlog or audit document
just to initiate this workflow. Preserve unrelated work and coordinate overlapping
edits under the baseline's normal ownership rules.

If the area is too large, divide it into complete behavioral replacements with
explicit integration boundaries. Each slice must retire its old path. Do not
substitute a sequence of helper extractions or arbitrary line-count targets.
Promise the bounded outcome, not an unverified session-duration estimate.

## Replace and integrate

Implement the replacement, migrate every required caller and remove the old
mechanisms in the same batch. Small preparatory edits are intermediate steps;
do not hand them off as completion of an authorised replacement.
Continue through implementation, integration, deletion and verification without
requiring a new prompt for each step. A real blocker or missing material decision
may interrupt the work; an intermediate successful cleanup is not a stopping point.

Internal types, function boundaries and implementation-specific tests may change.
Retain their behavioral obligations and meaningful failure assertions. A test
that names an obsolete helper need not preserve that helper; an identity,
ordering, diagnostic or recovery assertion still needs deliberate coverage.
Do not weaken assertions, remove failing cases or regenerate expected results
merely to make the replacement pass.

A temporary comparison path may help qualify the replacement, but remove it
before completion. Keep one final implementation, without a permanent legacy
fallback or a generic framework added solely to hide the two old paths.
Do not force genuinely distinct responsibilities into one abstraction just to
claim consolidation; explain a discovered necessary separation against the
agreed completion criteria.

This workflow does not authorise deleting unrelated code, resetting user edits,
changing persisted/public contracts, weakening security or recovery, or creating
another checkout. Material contract changes need an explicit decision under the
[baseline](../../TOKO-TOOLING.md#scope-and-authorization). Ask only for the missing
decision and continue independent work where possible. Ordinary internal design
choices do not require repeated confirmation.

## Verify completion

Run the relevant behavioral checks after the coherent batch, including selected
identity, ordering, activation and failure/recovery cases. Use differential
comparisons when useful, but do not treat an old implementation as an oracle for
a known defect. Follow the existing [validation policy](../../TOKO-TOOLING.md#validation-and-evidence);
this option adds no broad suite or release gate.

Review remaining callers, old state, adapters and fallback paths. Finish with:

- what now owns the behavior;
- which named mechanisms were deleted;
- how protected behavior and recovery were checked; and
- any unmet completion criterion or unmeasured effect.

Do not declare success because many files changed, a few allocations disappeared,
or an initial test subset passed. If interrupted, preserve the accepted boundary,
completed migration and remaining deletion/proof work in the existing handoff.
Resume that replacement rather than restarting the audit or drifting into polish.
