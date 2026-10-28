# Shared Tooling

Common engineering rules, development tools and CI building blocks for
`dragginzgame` repositories. Shared Tooling has no Cargo workspace or canister
runtime dependency. Consumers retain their product architecture, compiler
policy, deployment identity and validation gates.

## Start here

| Need | Guide |
| --- | --- |
| Adopt or update Shared Tooling | [Reviewed snapshots and upgrade previews](docs/consuming-snapshots.md) |
| Prepare the compiler and tools | [Local setup](docs/local-setup.md) and [supported hosts](docs/supported-hosts.md) |
| Configure a consumer's commands | [Make interface](docs/make-interface.md) |
| Understand the common rules | [Engineering baseline](DRAGGINZGAME.md), then the consumer's `AGENTS.md` |
| Release or recover a release | [Release commands and recovery](docs/releases.md) |
| Inspect the repository fleet | [Fleet reports and CI inspection](docs/fleet-tools.md) |

## Toko stack

Arrows point from consumer to dependency owner. This is a condensed view of
first-party declarations, including optional dependencies, rather than the
contents of a particular Wasm build. Dashed arrows identify native tooling;
redundant solid arrows are omitted. The [detailed inventory](docs/stack.md)
retains direct manifest evidence, build/test declarations and frontend packages.

<!-- stack-graph:start -->
```mermaid
flowchart TD
    r_canic["canic"]
    r_ic_auth["ic-auth"]
    r_ic_backup["ic-backup"]
    r_ic_blob_storage["ic-blob-storage"]
    r_ic_metrics["ic-metrics"]
    r_ic_persistence["ic-persistence"]
    r_ic_platform["ic-platform"]
    r_ic_query["ic-query"]
    r_ic_timers["ic-timers"]
    r_ic_tooling["ic-tooling"]
    r_ic_wire["ic-wire"]
    r_icydb["icydb"]
    r_toko["toko"]
    r_toko_miner["toko-miner"]
    r_canic --> r_ic_auth
    r_canic --> r_ic_backup
    r_canic --> r_ic_blob_storage
    r_canic -.-> r_ic_query
    r_canic --> r_ic_timers
    r_canic -.-> r_ic_tooling
    r_ic_auth --> r_ic_platform
    r_ic_auth -.-> r_ic_tooling
    r_ic_backup --> r_ic_platform
    r_ic_backup -.-> r_ic_tooling
    r_ic_blob_storage --> r_ic_persistence
    r_ic_blob_storage -.-> r_ic_tooling
    r_ic_persistence --> r_ic_metrics
    r_ic_persistence --> r_ic_platform
    r_ic_platform -.-> r_ic_tooling
    r_ic_platform --> r_ic_wire
    r_ic_query --> r_ic_metrics
    r_ic_query --> r_ic_platform
    r_ic_query -.-> r_ic_tooling
    r_ic_timers --> r_ic_metrics
    r_ic_timers --> r_ic_platform
    r_ic_tooling -.-> r_ic_platform
    r_ic_tooling -.-> r_ic_wire
    r_icydb -.-> r_canic
    r_icydb --> r_ic_persistence
    r_icydb -.-> r_ic_tooling
    r_toko --> r_canic
    r_toko --> r_icydb
    r_toko_miner --> r_canic
    r_toko_miner --> r_icydb
```
<!-- stack-graph:end -->

The [daily local refresh](docs/stack.md#automatic-local-refresh) keeps generated
sections current once enabled, leaving changes for the next commit. It neither
fetches upstream changes nor commits them. Manual refresh/check commands remain
available in that guide.

## Repository fleet ownership

Shared Tooling owns common rules and helpers, adoption/pin drift inspection,
repository inventories, CI/issue dashboards and repeatable maintenance audits.
Central reports run here; consumers need only the helpers their workflows use,
not extra CI gates that scan sibling checkouts. Product repositories retain
behavior, acceptance evidence and issue resolution. Reporting does not grant
edit or deployment authority.

Keep reporting here while it shares this maintenance lifecycle. A hosted
application with its own data, authentication and deployment lifecycle would
need a separate owner. The [contribution inclusion test](CONTRIBUTING.md#inclusion-test)
explains what belongs in Shared Tooling.

## Capability ownership

| Capability | Canonical owner |
| --- | --- |
| Common rules, setup, formatting, release mechanics, snapshots and fleet reports | Shared Tooling: `rules/`, `scripts/`, `make/` and `.github/actions/` |
| External IC-specific dependencies and browser SDK boundary | [IC Platform](https://github.com/dragginzgame/ic-platform), through explicit features and interfaces |
| Owned application encoding and generated TypeScript codecs | [IC Wire](https://github.com/dragginzgame/ic-wire); consumers own transport and application semantics |
| Cargo/Wasm builds, host primitives, artifact encoding and PocketIC lifecycle | [IC Tooling](https://github.com/dragginzgame/ic-tooling): Build, Host and Testkit in one workspace |
| Measurement arithmetic | [IC Metrics](https://github.com/dragginzgame/ic-metrics); fleet discovery and dashboards remain here |
| Product deployment, limits, release inputs and acceptance evidence | Each consuming repository |

Shared distributes reviewed commands and source; consumers compile the standalone
Rust scanner with locked dependencies. `ci/frontend` is a private formatting
qualification fixture. Shared's release and snapshot lifecycle is independent
of the product workspaces.

## Consuming repositories

Adopt an exact reviewed revision through the [snapshot exporter](docs/consuming-snapshots.md),
including its declared companion files, and verify the recorded snapshot offline.
Use `--preview` to review an upgrade before applying it. CI and releases use the
reviewed files, rather than loading Shared Tooling from a mutable sibling
checkout, moving download URL or symlink. Interactive read-only fleet reports
may inspect siblings directly.

Consumers use `make/consumer.mk` for shared setup, checks, formatting and release
mechanics, with explicit local inputs. Browser/npm checks are [opt-in](docs/node-tools.md).
Review [migration impact](docs/consuming-snapshots.md#upgrade-impact) alongside
[release notes](CHANGELOG.md); a refreshed snapshot alone does not qualify
consumer behavior. Applicable workflows support macOS under the
[host contract](docs/supported-hosts.md).

## Current tools

| Task | Entry point and reference |
| --- | --- |
| Install or verify prepared tools | `make install-tools`, `make tools-check`; [local setup](docs/local-setup.md) |
| Inspect all existing tool checks | `make tools-report`; [diagnostics](docs/local-setup.md#tool-selection-and-diagnostics) |
| Install selected IC executables | `make install-ic-tools`; [IC tools and ownership](docs/ic-tools.md) |
| Format a Rust consumer or enable its commit hook | Consumer `make fmt`, `make fmt-check`, `make install-hooks`; [formatting contract](rules/git-hooks.md) |
| Check dependency declarations | `make check-pins`; [pinning policy](rules/dependency-pinning.md) and [helper contracts](docs/verification-helpers.md) |
| Report sibling Rust/tooling LOC | `make cloc`, `make cloc-tooling`; [fleet reports](docs/fleet-tools.md) |
| Inspect issues, PRs or CI runs | `scripts/dev/github-siblings.sh`, `scripts/dev/gh-ci.sh`; [usage and limits](docs/fleet-tools.md) |
| Run selected Make checks with retained evidence | [Validation target runner](docs/validation-runner.md) |
| Reuse checksum, source, archive and publication checks | [Verification helper contracts](docs/verification-helpers.md) |

Shared's own integration fixtures additionally require its prepared IC Build
release editor; [local setup](docs/local-setup.md#shared-toolings-integration-editor)
owns that selection. Shared does not activate Rust formatting hooks in this
non-Cargo checkout. Installer pins, platform coverage and command options live
in their guides rather than being repeated here.

## Repeatable maintenance

The [task catalog](tasks/README.md), also available through `make tasks`, covers
CI health, snapshot drift, dependency advisories, compiler/tool freshness,
README accuracy and bounded code/tooling audits. The optional
[agent schedule](tasks/local-schedule.md) runs a read-only maintenance pass every
three days and coordinates findings through owning issues. It is separate
from the deterministic stack-diagram timer.

## Shared principles

Read the [baseline](DRAGGINZGAME.md) and local overlay first. [Engineering
principles](docs/principles/README.md), focused policies in `rules/` and the
[shared audit methods](audits/README.md) support that baseline; product-specific
choices and historical reports remain with consumers. [Provenance](docs/provenance.md)
records earlier extractions rather than defining today's ownership.

## Contributing and validation

Read [CONTRIBUTING.md](CONTRIBUTING.md) and this repository's [AGENTS.md](AGENTS.md).
Prepare [Shared's pinned compiler](docs/local-setup.md#shared-toolings-own-compiler)
before installing Cargo tools. For ordinary changes, select the affected
fixtures and checks; documentation-only changes use `make check-doc-links` and
`git diff --check`. `make ci`, `make test-portable` and `make check-shell` are
aggregate gates for releases or explicit full-check requests.

`make version` reads [VERSION](VERSION); the top undated [changelog](CHANGELOG.md)
entry describes pending work and does not prove publication. Tags establish
release identity. Releases and recovery follow the [release contract](docs/releases.md).

Licensed under [MIT](LICENSE).
