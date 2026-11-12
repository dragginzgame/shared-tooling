# Toko Tooling

Common engineering rules, development tools and CI building blocks for
`dragginzgame` repositories. Toko Tooling has no Cargo workspace or canister
runtime dependency. Consumers retain their product architecture, deployment
identity and validation gates, and implement the shared
[Rust compiler policy](rules/cargo-dependencies.md#minimum-supported-rust-version-msrv).

The complete tooling source is distributed as the `toko-tooling` crate on
crates.io. An exact root Cargo dependency pin is inherited as a dev-dependency
by every workspace package; Cargo.lock pins the archive. `cargo update -v`
reports newer available releases. Explicit
`make toko-tooling-update` and `make toko-tooling-install` install the code.
See [registry adoption and migration](docs/adoption/consuming-snapshots.md#cargo-selection-and-installation).

## Start here

Browse the [documentation index](docs/README.md) for guides organised by topic.

| Need | Guide |
| --- | --- |
| Adopt or update Toko Tooling | [Reviewed snapshots and upgrade previews](docs/adoption/consuming-snapshots.md) |
| Prepare the compiler and tools | [Local setup](docs/adoption/local-setup.md) and [supported hosts](docs/tools/supported-hosts.md) |
| Configure a consumer's commands | [Make interface](docs/adoption/make-interface.md) |
| Understand the common rules | [Engineering baseline](TOKO-TOOLING.md), then the consumer's `AGENTS.md` |
| Release or recover a release | [Release commands and recovery](docs/releases/releases.md) |
| Inspect the repository fleet | [Fleet reports and CI inspection](docs/fleet/fleet-tools.md) |

## Toko stack

See the [application and library overview](docs/fleet/overview.md) and the
[full package graph and manifest evidence](docs/fleet/stack.md). These generated
reports describe local declarations, not published or deployment-qualified graphs.

## Repository fleet ownership

Toko Tooling owns common rules and helpers, adoption/pin drift inspection,
repository inventories, CI/issue dashboards and repeatable maintenance audits.
Central reports run here; consumers need only the helpers their workflows use,
not extra CI gates that scan sibling checkouts. Product repositories retain
behavior, acceptance evidence and issue resolution. Reporting does not grant
edit or deployment authority.

Keep reporting here while it shares this maintenance lifecycle. A hosted
application with its own data, authentication and deployment lifecycle would
need a separate owner. The [contribution inclusion test](docs/adoption/contributing.md#inclusion-test)
explains what belongs in Toko Tooling.

## Capability ownership

| Capability | Canonical owner |
| --- | --- |
| Common rules, setup, formatting, release mechanics, snapshots and fleet reports | Toko Tooling: `rules/`, `scripts/`, `make/` and `.github/actions/` |
| External IC-specific dependencies and browser SDK boundary | [IC Platform](https://github.com/dragginzgame/ic-platform), through explicit features and interfaces |
| Owned application encoding and generated TypeScript codecs | [IC Wire](https://github.com/dragginzgame/ic-wire); consumers own transport and application semantics |
| Cargo/Wasm builds, host primitives, artifact encoding and PocketIC lifecycle | [IC Tooling](https://github.com/dragginzgame/ic-tooling): Build, Host and Testkit in one workspace |
| Metrics and logging | [IC Observability](https://github.com/dragginzgame/ic-observability): `ic-metrics` and `ic-logging`, required by the [shared rule](TOKO-TOOLING.md#metrics-and-logging); fleet discovery and dashboards remain here |
| Product deployment, limits, release inputs and acceptance evidence | Each consuming repository |

Shared distributes reviewed commands and source; consumers compile the standalone
Rust scanner with locked dependencies. `ci/frontend` is a private formatting
qualification fixture. Shared's release and snapshot lifecycle is independent
of the product workspaces.

## Consuming repositories

Adopt an exact reviewed revision through the [snapshot exporter](docs/adoption/consuming-snapshots.md),
including its declared companion files, and verify the recorded snapshot offline.
Use `--preview` to review an upgrade before applying it. CI and releases use the
reviewed files, rather than loading Toko Tooling from a mutable sibling
checkout, moving download URL or symlink. Interactive read-only fleet reports
may inspect siblings directly.

Install the small `TOKO-TOOLING.md` baseline and needed executable entrypoints,
not the reference documentation library. Read supporting guides, detailed rules,
audit methods and task catalogs through immutable upstream links. Consumer docs
remain product-owned and organised by topic; no shared-doc directory is needed.

Consumers use `make/consumer.mk` for shared setup, checks, formatting and release
mechanics, with explicit local inputs. Browser/npm checks are [opt-in](docs/tools/node-tools.md).
Review [migration impact](docs/adoption/consuming-snapshots.md#upgrade-impact) alongside
[release notes](CHANGELOG.md); a refreshed snapshot alone does not qualify
consumer behavior. Applicable workflows support macOS under the
[host contract](docs/tools/supported-hosts.md).

## Current tools

| Task | Entry point and reference |
| --- | --- |
| Install or verify prepared tools | `make install-tools`, `make tools-check`; [local setup](docs/adoption/local-setup.md) |
| Inspect all existing tool checks | `make tools-report`; [diagnostics](docs/adoption/local-setup.md#tool-selection-and-diagnostics) |
| Install selected IC executables | `make install-ic-tools`; [IC tools and ownership](docs/tools/ic-tools.md) |
| Format a Rust consumer or enable its commit hook | Consumer `make fmt`, `make fmt-check`, `make install-hooks`; [formatting contract](rules/git-hooks.md) |
| Check dependency declarations | `make check-pins`; [pinning policy](rules/dependency-pinning.md) and [helper contracts](docs/validation/verification-helpers.md) |
| Update both Cargo workspaces | `make deps-update`; [options and limits](docs/validation/cargo-graph-checks.md#repository-dependency-maintenance) |
| Report Rust LOC | `make cloc`; [workspace and sibling reports](docs/fleet/fleet-tools.md) |
| Audit sibling tooling adoption | [Snapshot integrity and relevant updates](tasks/snapshot-drift.md), [caller wiring and consolidation](tasks/tooling-duplication.md) |
| Inspect issues, PRs or CI runs | `scripts/dev/github-siblings.sh`, `scripts/dev/gh-ci.sh`; [usage and limits](docs/fleet/fleet-tools.md) |
| Run selected Make checks with retained evidence | [Validation target runner](docs/validation/validation-runner.md) |
| Reuse checksum, source, archive and publication checks | [Verification helper contracts](docs/validation/verification-helpers.md) |

Shared's own integration fixtures additionally require its prepared IC Build
release editor; [local setup](docs/adoption/local-setup.md#toko-toolings-integration-editor)
owns that selection. Shared does not activate Rust formatting hooks in this
source-distribution crate. Installer pins, platform coverage and command options live
in their guides rather than being repeated here.

## Repeatable maintenance

The [task catalog](tasks/README.md), also available through `make tasks`, covers
CI health, snapshot drift, dependency advisories, compiler/tool freshness,
README accuracy and bounded code/tooling audits. The optional
[agent schedule](tasks/local-schedule.md) runs a read-only maintenance pass every
three days and writes a local report. Interactive review owns any issue updates.
It is separate
from the deterministic stack-diagram timer.

## Shared principles

Read the [baseline](TOKO-TOOLING.md) and local overlay first. [Engineering
principles](docs/principles/README.md), focused policies in `rules/` and the
[shared audit methods](audits/README.md) support that baseline; product-specific
choices and historical reports remain with consumers.

## Contributing and validation

Read [CONTRIBUTING.md](CONTRIBUTING.md) and this repository's [AGENTS.md](AGENTS.md).
Only authorised Toko Studios personnel may contribute; outside contributions
are not accepted.
Prepare [Shared's pinned compiler](docs/adoption/local-setup.md#toko-toolings-own-compiler)
before installing Cargo tools. For ordinary changes, select the affected
fixtures and checks; documentation-only changes use `make check-doc-links` and
`git diff --check`. Normal releases use `make release-basic`; the complete
regression matrix stays
in hosted CI. Run `make ci` or `make test-portable` locally only when explicitly
requested. See [validation selection](AGENTS.md#validation-in-toko-tooling).

`make version` reads package.version in [Cargo.toml](Cargo.toml); the top undated [changelog](CHANGELOG.md)
entry describes pending work and does not prove publication. Tags establish
release identity. Releases and recovery follow the [release contract](docs/releases/releases.md).

## Licence

Except where a file or notice states otherwise, material in this repository is
offered by each applicable Copyright Holder, to the extent of that holder's
authority, under the [Toko Studios Network Licence 1.0](LICENSE.md). Third-party
material and material previously released under an earlier public grant retain
their applicable terms. See
[the licensing guide](docs/licenses.md).
