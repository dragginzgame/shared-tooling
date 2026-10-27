.DEFAULT_GOAL := help

export RELEASE_DELIVERY ?= direct
SHELLCHECK ?= shellcheck
CLOC_REPORT := $(CURDIR)/scripts/dev/cloc-siblings.sh
CLOC_ROOT = $(CLOC_PARENT)
CLOC_PARENT ?= $(CURDIR)/..
STACK_PARENT ?= $(CURDIR)/..
SHARED_TOOLING_RUST := 0
# Shared qualifies IC executable provisioning and retained-tool integrity.
LOCAL_TOOL_INSTALL_TARGETS += install-ic-tools install-release-editor
LOCAL_TOOL_CHECK_TARGETS += ic-tools-check release-editor-check
IC_TOOLS := didc ic-wasm icp quill wasm-opt
# Shared's own integration fixtures use this optional product tool. Consumers
# retain their release-tool selections; it is not part of the common Cargo set.
RELEASE_EDITOR_VERSION := 0.18.0
RELEASE_EDITOR_MAX_BYTES := 8388608
RELEASE_EDITOR_COMMAND = bash "$(CURDIR)/scripts/dev/install-rust-tools.sh" --consumer "$(CURDIR)" \
    --package ic-build --version "$(RELEASE_EDITOR_VERSION)" --bin ic-build-release-metadata --profile debug
export PATH := $(CURDIR)/.tools/ic/bin:$(PATH)
include make/consumer.mk

# Only the standard release request authorizes tool preparation. Standalone
# metadata/check commands remain offline; the adapter consumes this selection.
release-patch release-minor release-major release-resume: export SHARED_RELEASE_PREPARE_TOOLS := 1

.PHONY: help tasks version check-shell check-pins check-doc-links check-release-commands test-portable ci \
        release-version release-preflight release-verify \
        release-prepare-version release-prepared-check release-files \
        release-commit-check release-committed-check release-tagged-check release-push-check \
        release-merged-preflight check-cargo-tool-versions check-tool-catalogs test-licenses cloc-tooling \
        install-release-editor release-editor-check check-no-symlinks stack-graph check-stack-graph

help:
	@echo "Current local version: make version"
	@echo "Repeatable maintenance catalog: make tasks"
	@echo "Sibling Rust LOC summaries: make cloc [CLOC_PARENT=/path/to/projects]"
	@echo "Sibling CI/tooling inventory: make cloc-tooling [CLOC_PARENT=/path/to/projects]"
	@echo "Toko stack README diagram: stack-graph, check-stack-graph [STACK_PARENT=/path/to/projects]"
	@echo "Focused: affected script fixtures, check-no-symlinks, check-pins, check-doc-links, check-release-commands"
	@echo "Local IC executables: install-ic-tools; offline verification: ic-tools-check"
	@echo "Complete common host, IC and Rust toolset: install-tools; offline verification: tools-check"
	@echo "Aggregate offline tool diagnostics: tools-report (no installation)"
	@echo "Pinned Cargo tools: install-rust-tools; offline verification: rust-tools-check"
	@echo "Shared integration editor: install-release-editor; offline verification: release-editor-check"
	@echo "Cargo tool freshness (online, read-only): check-cargo-tool-versions"
	@echo "Caller catalog agreement (offline, opt-in): check-tool-catalogs TOOL_CATALOG_BINDINGS=path"
	@echo "Full release/explicit-check gates: ci, test-portable, check-shell"
	@echo "Maintainer releases: release-patch, release-minor, release-major"
	@echo "Delivery: direct by default; RELEASE_DELIVERY=pr selects review then merged validation/tag"
	@echo "Recovery: rerun the normal release target; saved releases reconcile automatically"

tasks:
	@cat tasks/README.md

stack-graph:
	perl scripts/dev/stack-graph.pl --write --parent "$(STACK_PARENT)"

check-stack-graph:
	perl scripts/dev/stack-graph.pl --check --parent "$(STACK_PARENT)"

cloc-tooling:
	@perl scripts/dev/cloc-tooling.pl "$(CLOC_PARENT)"

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
	perl scripts/ci/check-documentation-links.pl --root . *.md audits/*.md rules/*.md tasks/*.md docs/*.md docs/principles/*.md docs/changelog/*.md

check-release-commands:
	bash scripts/ci/check-release-commands.sh . make/consumer.mk

ci:
	+@bash scripts/ci/run-validation-targets.sh --fail-fast check-no-symlinks check-shell check-pins check-doc-links test-portable

version release-version:
	@bash scripts/release/metadata.sh version

release-preflight:
	+@bash scripts/release/metadata.sh preflight

release-verify:
	+@unset SHARED_RELEASE_PREPARE_TOOLS; \
		VALIDATION_FAILURE_LOG_DIR="$$(git rev-parse --git-path release-state)/validation-failures" \
		bash scripts/ci/run-validation-targets.sh ci

release-prepare-version:
	@bash scripts/release/metadata.sh prepare

release-prepared-check:
	@bash scripts/release/metadata.sh check

release-files:
	@printf 'VERSION\0CHANGELOG.md\0'

release-commit-check:
	@bash scripts/release/metadata.sh commit-check

release-committed-check release-tagged-check release-push-check:
	@bash scripts/release/metadata.sh check

release-merged-preflight:
	+@bash scripts/release/metadata.sh merged-preflight
