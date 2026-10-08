# Contributing

Shared Tooling accepts reusable engineering principles, portable developer
tools, and CI building blocks for Dragginz Game repositories.

## Pull requests

People and agents normally contribute through a topic branch and pull request.
Under the [contribution rules](rules/contributions.md), asking an agent to open
a PR authorizes its scoped commits, branch push and PR creation. You do not need
to commit on the agent's behalf. Direct pushes to the default branch, merges and
releases require their own authorization and remain subject to branch protections.
Include relevant validation and update the current changelog draft; preparing
a PR does not require a package version bump.

## Inclusion test

A contribution belongs here when it satisfies at least one of these tests:

1. the same maintained need exists in more than one consuming repository;
2. the behavior is repository-neutral and removes duplicated safety or
   validation mechanics; or
3. a shared principle captures a stable decision test while leaving product
   policy with the consumer.

Code, prose, and automation do not belong here merely because they could be
reused. Keep product architecture, deployment identity, accepted release plans,
release validation gates, network identity, and repository-specific inputs local
within the common baseline. Release command names and sequencing follow the
[common release contract](docs/releases.md).

## Baseline and overlay

Shared Tooling owns the mandatory common baseline in
[`DRAGGINZGAME.md`](DRAGGINZGAME.md). Every consumer adopts a reviewed revision
and identifies its local overlay in `AGENTS.md`. Additional product-specific
rules stay within the baseline's delegated scope. A change to an explicit common
rule requires a maintainer-approved exception with scope and reason, including
when the proposed rule is stricter.
When valid product choices differ, share their invariant and decision criteria
and keep those choices in the local overlays.

Avoid template systems with hidden inheritance. A contributor should be able
to understand the effective rules by reading the consumer repository and its
recorded Shared Tooling snapshot.

## Feedback and adoption

GitHub issues in the owning repository are the sole tracker for reusable gaps
and adoption work. Do not create or maintain local upstream issue files,
feedback ledgers, project-prefixed issue IDs or parallel tracking queues.
Handoffs link to issues without duplicating triage or issue status. Supporting
evidence stays with its existing owner. Reuse a matching issue and include the
reviewed revision, dirty-source identity when relevant, affected owner/callers/hosts,
symptom, focused evidence, smallest proposal and disposition. Relevant GitHub
issue work in `dragginzgame/*` has the baseline's standing authorization;
issue actions in other GitHub repositories require explicit authorization.
Apply authorized local repairs directly. Follow the
[maintenance rules](rules/agent-maintenance.md) for the reporting workflow and
its separate boundaries for sibling file edits and release effects.

Upstream acceptance and verified consumer adoption are separate outcomes. An
accepted shared fix does not prove that a consumer refreshed its rules or tools,
resolved conflicts or ran the relevant checks.

## Documentation contributions

A shared principle should state:

- the problem and maintained invariant;
- the decision test contributors should apply;
- the smallest useful evidence at review;
- explicit non-goals; and
- which choices remain owned by consumers.

Prefer short, durable rules over exhaustive catalogs. Examples must be generic
or clearly marked as examples rather than required repository shape.

Focused mandatory policies belong in `rules/` and must be linked from the
baseline. Keep each policy's rules in one place and include new linked files in
the governance snapshot instructions. Follow the [changelog rules](rules/changelogs.md)
when preparing release notes; consumer audience and presentation choices stay local.

Reusable audit methods live in `audits/`. Share the review questions and proof
requirements; keep product-specific paths, invariants, metrics and execution
commands in consumer overlays. Follow the [common audit contract](audits/README.md)
and preserve old report evidence when consolidating definitions. A new method
needs a distinct review question that an existing method cannot already answer.

## Script contributions

Portable scripts must:

- use explicit inputs for repository-specific behavior;
- validate arguments before mutation or download;
- document non-standard dependencies;
- avoid hidden network, credential, deployment, or release effects;
- use temporary files safely, clean disposable scratch and retain failed evidence;
- fail with a non-zero status and actionable diagnostics;
- preserve consumer-owned version and policy decisions; and
- include an offline regression whenever the behavior can be exercised with a
  fixture or command stub.

CI and release scripts must remain usable as reviewed vendored snapshots. A
new helper dependency must be included in the consumer's declared snapshot
file set. Declare unconditional shared companions on the owning entry point's
second line: `# Shared companions: relative/path another/path`. Use space-separated
canonical paths without whitespace; the exporter checks these from committed
source before replacement. Keep conditional feature dependencies explicit in
the adoption guide. Declarations enforce reviewed selections without implicitly
expanding them.

Contributions must preserve required macOS support. Document host-specific
dependency setup, CI and deployment prerequisites, and qualify the affected
behavior on the declared native hosts. Follow the
[host guidance](docs/supported-hosts.md); a Linux-only pass does not qualify
macOS behavior.

## Validation

For script changes, run the portable regression test and ShellCheck described
in `AGENTS.md`. For documentation-only changes, check links, instruction
consistency and the diff.
Keep scratch and loop variables local to fixture helpers. Construct and assert
each negative case's intended precondition: a partial-staging case must select
the intended file before adding its unstaged edit. Do not rely on copied tooling
already differing from HEAD; fixture setup must remain valid after adoption is
committed and those files match HEAD.
When changing a platform branch, report which host exercised it and which
branches remain install-capable but unverified.
