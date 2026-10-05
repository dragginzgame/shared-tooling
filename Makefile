.DEFAULT_GOAL := help

RELEASE_REMOTE ?= origin
RELEASE_BRANCH ?= main
SHELLCHECK ?= shellcheck

.PHONY: help check-shell test-portable ci release-patch release-minor release-major \
        release-resume release-version release-preflight release-verify \
        release-prepare-version release-prepared-check release-files \
        release-commit-check release-committed-check release-tagged-check release-push-check

ifneq ($(word 2,$(filter release-patch release-minor release-major release-resume,$(MAKECMDGOALS))),)
$(error Select exactly one release target)
endif

help:
	@echo "Focused: check-shell, test-portable"
	@echo "Full gate: ci (explicit request or configured CI)"
	@echo "Maintainer releases: release-patch, release-minor, release-major"
	@echo "Recovery: release-resume VERSION=X.Y.Z (inspect retained .git release-state first)"

check-shell:
	$(SHELLCHECK) scripts/ci/*.sh scripts/dev/*.sh scripts/distribution/*.sh scripts/release/*.sh .githooks/pre-commit

test-portable:
	bash scripts/ci/test-portable-tools.sh

ci:
	+$(MAKE) --no-print-directory check-shell
	+$(MAKE) --no-print-directory test-portable

release-patch release-minor release-major:
	+@bash scripts/ci/run-release.sh "$(@:release-%=%)" "$(RELEASE_REMOTE)" "$(RELEASE_BRANCH)"

release-resume:
	+@bash scripts/ci/run-release.sh resume "$(VERSION)" "$(RELEASE_REMOTE)" "$(RELEASE_BRANCH)"

release-version:
	@bash scripts/release/metadata.sh version

release-preflight:
	@bash scripts/release/metadata.sh preflight

release-verify:
	+$(MAKE) --no-print-directory ci

release-prepare-version:
	@bash scripts/release/metadata.sh prepare

release-prepared-check:
	@bash scripts/release/metadata.sh check

release-files:
	@printf 'CHANGELOG.md\0'

release-commit-check:
	@bash scripts/release/metadata.sh commit-check

release-committed-check release-tagged-check release-push-check:
	@bash scripts/release/metadata.sh check
