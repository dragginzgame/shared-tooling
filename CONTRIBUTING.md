# Contributing

Shared Tooling accepts reusable engineering principles, portable developer
tools, and CI building blocks for Dragginz Game repositories.

## Inclusion test

A contribution belongs here when it satisfies at least one of these tests:

1. the same maintained need exists in more than one consuming repository;
2. the behavior is repository-neutral and removes duplicated safety or
   validation mechanics; or
3. a shared principle captures a stable decision test while leaving product
   policy with the consumer.

Code, prose, and automation do not belong here merely because they could be
reused. Keep product architecture, deployment identity, release cadence,
version policy, network authority, and repository-specific commands local.

## Baseline and overlay

Shared documents define a baseline. A consumer adopts a reviewed revision and
adds a local overlay for stricter or product-specific rules. If two consumers
make different valid choices, share the invariant and decision criteria—not
one consumer's choice.

Avoid template systems with hidden inheritance. A contributor should be able
to understand the effective rules by reading the consumer repository and its
recorded Shared Tooling snapshot.

## Documentation contributions

A shared principle should state:

- the problem and maintained invariant;
- the decision test contributors should apply;
- the smallest useful evidence at review;
- explicit non-goals; and
- which choices remain owned by consumers.

Prefer short, durable rules over exhaustive catalogs. Examples must be generic
or clearly marked as examples rather than required repository shape.

## Script contributions

Portable scripts must:

- use explicit inputs for repository-specific behavior;
- validate arguments before mutation or download;
- document non-standard dependencies;
- avoid hidden network, credential, deployment, or release effects;
- use temporary files safely and clean them on exit;
- fail with a non-zero status and actionable diagnostics;
- preserve consumer-owned version and policy decisions; and
- include an offline regression whenever the behavior can be exercised with a
  fixture or command stub.

CI and release scripts must remain usable as reviewed vendored snapshots. A
new helper dependency must be included in the consumer's declared snapshot
file set.

## Validation

Run the portable regression test and ShellCheck described in `AGENTS.md`.
When changing a platform branch, report which host exercised it and which
branches remain install-capable but unverified.
