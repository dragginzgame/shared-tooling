.DEFAULT_GOAL := help
# Shared companions: make/consumer.mk make/cargo-dependencies.mk
export RELEASE_DELIVERY ?= direct
WORK_VERSION_KIND ?= patch
SHELLCHECK ?= shellcheck
CLOC_REPORT := $(CURDIR)/scripts/dev/cloc.sh
CLOC_ROOT = $(CLOC_PARENT)
CLOC_PARENT ?= $(CURDIR)/..
STACK_PARENT ?= $(CURDIR)/..
TOKO_TOOLING_RUST := 0
TOKO_TOOLING_RELEASE := 1
# The producer validates its own source package; it has no installed self-snapshot.
TOKO_TOOLING_PRODUCER := 1
CARGO_PUBLISH_PACKAGES := toko-tooling
CARGO_PUBLISH_REGISTRY := crates-io
CARGO_PUBLISH_VERIFY_TARGETS := check-version check-tooling-package
# Shared qualifies IC executable provisioning and retained-tool integrity.
LOCAL_TOOL_INSTALL_TARGETS += install-ic-tools install-release-editor
LOCAL_TOOL_CHECK_TARGETS += ic-tools-check release-editor-check
IC_TOOLS := didc ic-wasm icp quill wasm-opt
# Shared's own integration fixtures use this optional product tool. Consumers
# retain their release-tool selections; it is not part of the common Cargo set.
RELEASE_EDITOR_VERSION := 0.73.0
RELEASE_EDITOR_MAX_BYTES := 8388608
RELEASE_EDITOR_COMMAND = bash "$(CURDIR)/scripts/dev/install-rust-tools.sh" --consumer "$(CURDIR)" \
    --package ic-build --version "$(RELEASE_EDITOR_VERSION)" --bin ic-build-release-metadata --profile debug --features cli
export PATH := $(CURDIR)/.tools/ic/bin:$(PATH)
include make/consumer.mk
include make/cargo-dependencies.mk

# Only the standard release request authorizes tool preparation. Standalone
# metadata/check commands remain offline; the adapter consumes this selection.
release-patch release-minor release-major release-resume: export SHARED_RELEASE_PREPARE_TOOLS := 1
release-patch release-minor release-major release-resume: export RELEASE_VERSION_MODE := pending

.PHONY: help tasks version check-shell check-pins check-doc-links check-release-commands check-tooling-package test-portable ci release-basic \
        prepare-work check-version release-base-version \
        release-version release-preflight release-verify \
        release-prepare-version release-prepared-check release-files \
        release-commit-check release-committed-check release-tagged-check release-push-check \
        release-merged-preflight check-cargo-tool-versions check-tool-catalogs test-licenses \
        install-release-editor release-editor-check check-no-symlinks stack-graph check-stack-graph

help:
	@echo "Current local version: make version"
	@echo "Prepare/reuse pending notes and Cargo.toml: make prepare-work [WORK_VERSION_KIND=patch|minor|major]"
	@echo "Repeatable maintenance catalog: make tasks"
	@echo "Sibling Rust LOC summaries: make cloc [CLOC_PARENT=/path/to/projects]"
	@echo "Toko stack README diagram: stack-graph, check-stack-graph [STACK_PARENT=/path/to/projects]"
	@echo "Focused: affected script fixtures, check-no-symlinks, check-pins, check-doc-links, check-release-commands"
	@echo "Local IC executables: install-ic-tools; offline verification: ic-tools-check"
	@echo "Complete common host, IC and Rust toolset: install-tools; offline verification: tools-check"
	@echo "Aggregate offline tool diagnostics: tools-report (no installation)"
	@echo "Pinned Cargo tools: install-rust-tools; offline verification: rust-tools-check"
	@echo "Shared integration editor: install-release-editor; offline verification: release-editor-check"
	@echo "Cargo tool freshness (online, read-only): check-cargo-tool-versions"
	@echo "Dependencies across root + qualification: deps-update (cargo update -v; changes locks)"
	@echo "Local packages, versions and release groups: deps-list (offline, read-only)"
	@echo "Caller catalog agreement (offline, opt-in): check-tool-catalogs TOOL_CATALOG_BINDINGS=path"
	@echo "Basic local release gate: release-basic (metadata, shell lint, pins, links, source package)"
	@echo "Long-tail CI/explicit local checks: ci, test-portable"
	@echo "Maintainer releases: release-patch, release-minor, release-major"
	@echo "Tooling source bundle publication: publish-check, then publish after the Git release"
	@echo "Delivery: direct by default; RELEASE_DELIVERY=pr selects review then merged validation/tag"
	@echo "Normal releases start fresh; recover a specific saved attempt with release-resume VERSION=X.Y.Z"

tasks:
	@cat tasks/README.md

stack-graph:
	perl scripts/dev/stack-graph.pl --write --parent "$(STACK_PARENT)"

check-stack-graph:
	perl scripts/dev/stack-graph.pl --check --parent "$(STACK_PARENT)"

test-licenses:
	perl scripts/ci/test-license.pl

install-release-editor:
	+@$(RELEASE_EDITOR_COMMAND)

release-editor-check:
	+@$(RELEASE_EDITOR_COMMAND) --check

check-no-symlinks:
	@perl scripts/ci/check-no-symlinks.pl --consumer "$(CURDIR)"

check-cargo-tool-versions:
	@perl scripts/dev/check-cargo-tool-versions.pl --versions "$(RUST_TOOL_VERSIONS)"

TOOL_CATALOG_CONSUMER ?= .
TOOL_CATALOG_BINDINGS ?= ci/tool-catalog-bindings.json
check-tool-catalogs:
	@perl scripts/ci/check-tool-catalogs.pl --consumer "$(TOOL_CATALOG_CONSUMER)" --bindings "$(TOOL_CATALOG_BINDINGS)"

check-shell:
	$(SHELLCHECK) scripts/ci/*.sh scripts/dev/*.sh scripts/distribution/*.sh scripts/release/*.sh .githooks/pre-commit

test-portable:
	+@editor="$$($(RELEASE_EDITOR_COMMAND) --check)" || exit $$?; \
		CARGO_RELEASE_METADATA_EDITOR="$$editor" CARGO_RELEASE_METADATA_MAX_BYTES="$(RELEASE_EDITOR_MAX_BYTES)" \
		bash scripts/ci/test-portable-tools.sh

check-pins:
	bash scripts/ci/check-dependency-pins.sh --npm-root ci/frontend \
		--node-version "$$(jq -er '.engines.node' ci/frontend/package.json)" \
		--npm-version "$$(jq -er '.engines.npm' ci/frontend/package.json)"

check-doc-links:
	perl scripts/ci/check-documentation-links.pl --root . *.md audits rules tasks docs

check-tooling-package:
	@bash scripts/ci/test-tooling-package.sh --installation-only

check-release-commands:
	bash scripts/ci/check-release-commands.sh . make/consumer.mk make/release.mk make/cargo-publication.mk

.PHONY: test-public-docs
test-public-docs:
	perl scripts/ci/test-public-docs.pl

ci:
	+@bash scripts/ci/run-validation-targets.sh --fail-fast check-version check-no-symlinks check-shell check-pins check-doc-links test-portable

# Maintainer-approved source-bundle gate. The complete regression suite stays in CI.
release-basic:
	+@bash scripts/ci/run-validation-targets.sh --fail-fast check-version check-no-symlinks check-shell check-pins check-doc-links check-tooling-package

prepare-work:
	@perl scripts/release/work-version.pl prepare "$(WORK_VERSION_KIND)"

check-version:
	@perl scripts/release/work-version.pl check

release-base-version:
	@perl scripts/release/work-version.pl base

version release-version:
	@bash scripts/release/metadata.sh version

release-preflight:
	+@bash scripts/release/metadata.sh preflight

release-verify:
	+@unset SHARED_RELEASE_PREPARE_TOOLS RELEASE_VERSION_MODE; \
		VALIDATION_FAILURE_LOG_DIR="$$(git rev-parse --git-path release-state)/validation-failures" \
		bash scripts/ci/run-validation-targets.sh release-basic

release-prepare-version:
	@bash scripts/release/metadata.sh prepare

release-prepared-check:
	@bash scripts/release/metadata.sh check

release-files:
	@printf 'Cargo.toml\0CHANGELOG.md\0'

release-commit-check:
	@bash scripts/release/metadata.sh commit-check

release-committed-check release-tagged-check release-push-check:
	@bash scripts/release/metadata.sh check

release-merged-preflight:
	+@bash scripts/release/metadata.sh merged-preflight
