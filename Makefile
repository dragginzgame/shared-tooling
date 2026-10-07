.DEFAULT_GOAL := help

RELEASE_REMOTE ?= origin
RELEASE_BRANCH ?= main
export RELEASE_DELIVERY ?= direct
SHELLCHECK ?= shellcheck
CLOC_REPORT := $(CURDIR)/scripts/dev/cloc-siblings.sh
CLOC_ROOT = $(CLOC_PARENT)
include make/tools.mk

.PHONY: help version check-shell check-pins check-doc-links check-release-commands test-portable ci release-patch release-minor release-major \
        release-resume release-version release-preflight release-verify \
        release-prepare-version release-prepared-check release-files \
        release-commit-check release-committed-check release-tagged-check release-push-check \
        release-merged-preflight

ifneq ($(word 2,$(filter release-patch release-minor release-major release-resume,$(MAKECMDGOALS))),)
$(error Select exactly one release target)
endif

help:
	@echo "Current local version: make version"
	@echo "Sibling Rust LOC summaries: make cloc [CLOC_PARENT=/path/to/projects]"
	@echo "Sibling CI/tooling inventory: make cloc-tooling [CLOC_PARENT=/path/to/projects]"
	@echo "Focused: check-shell, check-pins, check-doc-links, check-release-commands, test-portable"
	@echo "Local IC executables: install-ic-tools; offline verification: ic-tools-check"
	@echo "Common host/IC executables (including jq/yq/ripgrep/cloc): install-tools; offline verification: tools-check"
	@echo "Pinned Cargo tools: install-rust-tools; offline verification: rust-tools-check"
	@echo "Full gate: ci (explicit request or configured CI)"
	@echo "Maintainer releases: release-patch, release-minor, release-major"
	@echo "Delivery: direct by default; RELEASE_DELIVERY=pr selects review then merged validation/tag"
	@echo "Recovery: rerun the normal release target; saved releases reconcile automatically"

check-shell:
	$(SHELLCHECK) scripts/ci/*.sh scripts/dev/*.sh scripts/distribution/*.sh scripts/release/*.sh .githooks/pre-commit

test-portable:
	bash scripts/ci/test-portable-tools.sh

check-pins:
	bash scripts/ci/check-dependency-pins.sh

check-doc-links:
	perl scripts/ci/check-documentation-links.pl --root . *.md audits/*.md rules/*.md docs/*.md docs/principles/*.md

check-release-commands:
	bash scripts/ci/check-release-commands.sh . make/tools.mk

ci:
	+$(MAKE) --no-print-directory check-shell
	+$(MAKE) --no-print-directory check-pins
	+$(MAKE) --no-print-directory check-doc-links
	+$(MAKE) --no-print-directory test-portable

release-patch release-minor release-major:
	+@bash scripts/ci/run-release.sh "$(@:release-%=%)" "$(RELEASE_REMOTE)" "$(RELEASE_BRANCH)"

release-resume:
	+@bash scripts/ci/run-release.sh resume "$(VERSION)" "$(RELEASE_REMOTE)" "$(RELEASE_BRANCH)"

version release-version:
	@bash scripts/release/metadata.sh version

release-preflight:
	@bash scripts/release/metadata.sh preflight

release-verify:
	+VALIDATION_FAILURE_LOG_DIR="$$(git rev-parse --git-path release-state)/validation-failures" \
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
	@bash scripts/release/metadata.sh check
