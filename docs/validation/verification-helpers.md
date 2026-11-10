# Focused verification helpers
<!-- Shared companions: docs/validation/cargo-graph-checks.md docs/releases/release-helpers.md docs/tools/setup-helpers.md docs/validation/evidence-helpers.md docs/validation/fixtures-helpers.md docs/validation/source-helpers.md -->

These optional helpers share mechanical checks. Consumers retain document
selection, release validation gates, publication authority and registry polling
policy. They require Perl core modules or Bash 3.2+, as noted below, and run on
Linux and macOS. The portable regression suite includes offline fixtures;
native CI qualifies each supported host separately.

## Helper contracts by topic

- [Source and dependency checks](source-helpers.md): file admission, Cargo metadata, digests, RustSec and documentation links.
- [Evidence checks](evidence-helpers.md): archives, tool bundles, disk capacity, evidence collection and workflow observations.
- [Fixture qualification](fixtures-helpers.md): diagnostics, retention, consumer flows and hosted scenarios.
- [Setup and formatting](../tools/setup-helpers.md): installers, compiler caches, snapshots, formatters and native hosts.
- [Release checks](../releases/release-helpers.md): change paths, receipts, publication admission and registry observations.

Each helper retains its own calling contract and qualification requirements.
