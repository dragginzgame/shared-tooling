# Changelog

## [Draft]

- Fix snapshot verification on macOS Bash 3.2 with strict unset-variable checks,
  while preserving duplicate file-record rejection.
- Require cleanup reports to list every removed function, method and type by
  name, with its former location, removal reason and replacement when applicable.
- Export snapshot files and executable modes from the recorded Git revision.
  Reject files absent from that revision and keep concurrent working-tree edits
  out of consumer snapshots.
- Provide the common engineering baseline as `DRAGGINZGAME.md`, so consumers can
  adopt it without overwriting their local `AGENTS.md`. Document the complete
  governance snapshot and interrupted-refresh recovery.
