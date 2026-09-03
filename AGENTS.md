# Shared Tooling Agent Rules

This repository owns reusable engineering principles and portable tooling for
Dragginz Game repositories. Keep this file compact; detailed guidance belongs
under `docs/`.

## Scope

- Shared material must be repository-neutral. Product architecture, release
  cadence, deployment authority, network identity, and compatibility policy
  remain in each consuming repository.
- Treat sibling repositories as read-only unless the maintainer explicitly
  authorizes a named repository mutation.
- Preserve unrelated and user-owned worktree changes. Re-read a dirty file
  before editing it.
- Do not run `git commit`, `git tag`, or `git push`.
- Do not add Python to committed files.

## Shared Standards

- A principle is guidance, not hidden inheritance. A consumer adopts it by
  vendoring or explicitly referencing a reviewed revision and may add a local
  overlay.
- Prefer stable principles and decision tests over project-specific commands,
  directory names, numeric limits, or prose copied from one repository.
- When contributors disagree, preserve the common invariant here and keep the
  policy choice in the consumer.
- Do not parse explanatory prose in release-blocking checks. Put facts that
  require machine enforcement in a structured manifest or executable check.

## Portable Tooling

- Scripts must declare dependencies, accept repository-specific inputs
  explicitly, fail closed on invalid input, and avoid implicit credentials,
  deployment targets, or release state.
- Interactive read-only tools may run from this checkout. CI and release tools
  are consumed as exact, reviewed snapshots; do not use symlinks or mutable
  network downloads of this repository during a consumer build.
- Keep supported-host claims aligned with `docs/supported-hosts.md` and CI
  evidence. An installer branch alone is not a support claim.
- Use Bash strict mode for new scripts. Preserve Bash 3.2 compatibility for the
  portable script set unless the support matrix is deliberately changed.
- Downloaded executables require an exact consumer-owned version, a pinned
  digest, HTTPS-only transport, verification before extraction, and a version
  check before installation.

## Validation

- Run `bash scripts/ci/test-portable-tools.sh` after script changes.
- Run ShellCheck over `scripts/ci/*.sh`, `scripts/dev/*.sh`, and
  `scripts/distribution/*.sh`.
- Run the smallest relevant regression first. The complete portable-tool test
  is intentionally small and may be run before handoff.

## Handoff

Report the outcome, files changed, validation status, skipped checks, and
follow-up work. For tooling changes, also state the supported-host and consumer
compatibility impact.
