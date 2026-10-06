.DEFAULT_GOAL := help

RELEASE_REMOTE ?= origin
RELEASE_BRANCH ?= main
SHELLCHECK ?= shellcheck
IC_TOOL_PINS ?= ci/ic-tools.tsv
HOST_TOOL_VERSIONS ?= ci/tool-versions.env
export PATH := $(CURDIR)/.tools/host/bin:$(CURDIR)/.tools/ic/bin:$(PATH)

.PHONY: help version check-shell check-pins check-doc-links check-release-commands test-portable ci release-patch release-minor release-major \
        install-tools tools-check install-host-tools host-tools-check install-ic-tools ic-tools-check \
        release-resume release-version release-preflight release-verify \
        release-prepare-version release-prepared-check release-files \
        release-commit-check release-committed-check release-tagged-check release-push-check

ifneq ($(word 2,$(filter release-patch release-minor release-major release-resume,$(MAKECMDGOALS))),)
$(error Select exactly one release target)
endif

help:
	@echo "Current local version: make version"
	@echo "Focused: check-shell, check-pins, check-doc-links, check-release-commands, test-portable"
	@echo "Local IC executables: install-ic-tools; offline verification: ic-tools-check"
	@echo "All local executables (including jq/yq/ripgrep): install-tools; offline verification: tools-check"
	@echo "Full gate: ci (explicit request or configured CI)"
	@echo "Maintainer releases: release-patch, release-minor, release-major"
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
	bash scripts/ci/check-release-commands.sh .

install-tools:
	+$(MAKE) --no-print-directory install-host-tools
	+$(MAKE) --no-print-directory install-ic-tools

tools-check:
	+$(MAKE) --no-print-directory host-tools-check
	+$(MAKE) --no-print-directory ic-tools-check

install-host-tools:
	bash scripts/dev/install-host-tools.sh --versions "$(HOST_TOOL_VERSIONS)" --with-ripgrep

host-tools-check:
	bash scripts/dev/install-host-tools.sh --versions "$(HOST_TOOL_VERSIONS)" --with-ripgrep --check

install-ic-tools:
	bash scripts/dev/install-ic-tools.sh --pins "$(IC_TOOL_PINS)"

ic-tools-check:
	bash scripts/dev/install-ic-tools.sh --pins "$(IC_TOOL_PINS)" --check

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
