# Repository-wide Cargo maintenance; invoked explicitly, never by build/release gates.
# Shared companions: make/execution.mk scripts/dev/cargo-dependencies.pl
_dependency_default_goal := $(.DEFAULT_GOAL)
include $(dir $(lastword $(MAKEFILE_LIST)))execution.mk
DEPENDENCY_CONSUMER ?= $(CURDIR)
DEPENDENCY_PACKAGE ?=
DEPENDENCY_PRECISE ?=
DEPENDENCY_MANIFEST ?=
DEPENDENCY_VERBOSE ?= 0
ifneq ($(DEPENDENCY_VERBOSE),0)
ifneq ($(DEPENDENCY_VERBOSE),1)
$(error DEPENDENCY_VERBOSE must be 0 or 1)
endif
endif
_dependency_quote = '$(subst ','"'"',$(1))'

.PHONY: deps-help deps-review deps-update
deps-help:
	@printf '%s\n' \
	  'make deps-review: compare root and qualification locks with published releases (online; no lock edits)' \
	  'make deps-update: run cargo update -v in both workspaces, then review (changes locks)' \
	  'Optional: DEPENDENCY_PACKAGE=name DEPENDENCY_PRECISE=x.y.z (precise is update-only)' \
	  'Optional: DEPENDENCY_CONSUMER=/path/to/repo DEPENDENCY_MANIFEST=extra/Cargo.toml' \
	  'Default output shows findings only; DEPENDENCY_VERBOSE=1 includes current/local packages.' \
	  'Updates preserve manifest requirements; sequential lock updates are not atomic.' \
	  'Successful updates exit 0 even with review findings. Review exits 1 for newer/yanked selections; errors exit 2.'

deps-update: | toko-execution-check
deps-review deps-update:
	@perl $(call _dependency_quote,$(TOKO_TOOLING_ROOT)/scripts/dev/cargo-dependencies.pl) \
	  $(patsubst deps-%,%,$@) --consumer $(call _dependency_quote,$(DEPENDENCY_CONSUMER)) \
	  $(if $(strip $(DEPENDENCY_PACKAGE)),--package $(call _dependency_quote,$(DEPENDENCY_PACKAGE))) \
	  $(if $(strip $(DEPENDENCY_PRECISE)),--precise $(call _dependency_quote,$(DEPENDENCY_PRECISE))) \
	  $(if $(strip $(DEPENDENCY_MANIFEST)),--manifest $(call _dependency_quote,$(DEPENDENCY_MANIFEST))) \
	  $(if $(filter 1,$(DEPENDENCY_VERBOSE)),--verbose)

.DEFAULT_GOAL := $(_dependency_default_goal)
