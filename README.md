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

A compact view of the applications and main library crates. Rounded nodes group
each application's packages; library crates such as `ic-memory` and `ic-storage`
stay separate. Arrows follow consumer → dependency paths through omitted internal
helpers; redundant arrows are omitted. Optional declarations are included, so
this is not a particular Wasm build. The [full package graph and manifest
evidence](docs/stack.md#full-package-graph) include internal, browser and native tools.

<!-- stack-graph:start -->
```mermaid
flowchart TD
    p_app_3atoko(["toko"])
    p_app_3atoko_2dminer(["toko-miner"])
    p_canic_7ccargo_3acanic["canic"]
    p_ic_2dauth_7ccargo_3aic_2dauth["ic-auth"]
    p_ic_2dblob_2dstorage_7ccargo_3aic_2dblob_2dstorage["ic-blob-storage"]
    p_ic_2dobservability_7ccargo_3aic_2dlogging["ic-logging"]
    p_ic_2dobservability_7ccargo_3aic_2dmetrics["ic-metrics"]
    p_ic_2dpersistence_7ccargo_3aic_2dmemory["ic-memory"]
    p_ic_2dpersistence_7ccargo_3aic_2dmetrics_2dstable["ic-metrics-stable"]
    p_ic_2dpersistence_7ccargo_3aic_2dstorage["ic-storage"]
    p_ic_2dplatform_7ccargo_3aic_2dplatform["ic-platform"]
    p_ic_2dscheduling_7ccargo_3aic_2dtimers["ic-timers"]
    p_ic_2dwire_7ccargo_3aic_2dwire["ic-wire"]
    p_icydb_7ccargo_3aicydb["icydb"]
    p_app_3atoko --> p_canic_7ccargo_3acanic
    p_app_3atoko --> p_icydb_7ccargo_3aicydb
    p_app_3atoko_2dminer --> p_canic_7ccargo_3acanic
    p_app_3atoko_2dminer --> p_ic_2dblob_2dstorage_7ccargo_3aic_2dblob_2dstorage
    p_app_3atoko_2dminer --> p_icydb_7ccargo_3aicydb
    p_canic_7ccargo_3acanic --> p_ic_2dauth_7ccargo_3aic_2dauth
    p_canic_7ccargo_3acanic --> p_ic_2dobservability_7ccargo_3aic_2dlogging
    p_canic_7ccargo_3acanic --> p_ic_2dpersistence_7ccargo_3aic_2dmetrics_2dstable
    p_canic_7ccargo_3acanic --> p_ic_2dscheduling_7ccargo_3aic_2dtimers
    p_ic_2dauth_7ccargo_3aic_2dauth --> p_ic_2dwire_7ccargo_3aic_2dwire
    p_ic_2dblob_2dstorage_7ccargo_3aic_2dblob_2dstorage --> p_ic_2dobservability_7ccargo_3aic_2dmetrics
    p_ic_2dblob_2dstorage_7ccargo_3aic_2dblob_2dstorage --> p_ic_2dpersistence_7ccargo_3aic_2dstorage
    p_ic_2dobservability_7ccargo_3aic_2dmetrics --> p_ic_2dwire_7ccargo_3aic_2dwire
    p_ic_2dpersistence_7ccargo_3aic_2dmemory --> p_ic_2dwire_7ccargo_3aic_2dwire
    p_ic_2dpersistence_7ccargo_3aic_2dmetrics_2dstable --> p_ic_2dobservability_7ccargo_3aic_2dmetrics
    p_ic_2dpersistence_7ccargo_3aic_2dmetrics_2dstable --> p_ic_2dpersistence_7ccargo_3aic_2dstorage
    p_ic_2dpersistence_7ccargo_3aic_2dstorage --> p_ic_2dpersistence_7ccargo_3aic_2dmemory
    p_ic_2dscheduling_7ccargo_3aic_2dtimers --> p_ic_2dobservability_7ccargo_3aic_2dmetrics
    p_ic_2dwire_7ccargo_3aic_2dwire --> p_ic_2dplatform_7ccargo_3aic_2dplatform
    p_icydb_7ccargo_3aicydb --> p_ic_2dobservability_7ccargo_3aic_2dmetrics
    p_icydb_7ccargo_3aicydb --> p_ic_2dpersistence_7ccargo_3aic_2dstorage
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
| Metrics and logging | [IC Observability](https://github.com/dragginzgame/ic-observability): `ic-metrics` and `ic-logging`, required by the [shared rule](DRAGGINZGAME.md#metrics-and-logging); fleet discovery and dashboards remain here |
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
