# Changelog

## [Draft]

- Export snapshot files and executable modes from the recorded Git revision.
  Reject files absent from that revision and keep concurrent working-tree edits
  out of consumer snapshots.
- Provide the common engineering baseline as `DRAGGINZGAME.md`, so consumers can
  adopt it without overwriting their local `AGENTS.md`. Document the complete
  governance snapshot and interrupted-refresh recovery.
