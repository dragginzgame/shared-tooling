# Resolved Cargo graph checks

Shared Tooling owns the observation/checking mechanics. Consumers own the roots,
targets, features, forbidden packages and required identity counts. This helper
complements direct declaration checks; it does not replace them or infer policy
from dependency-role comments.

```sh
perl scripts/ci/check-cargo-graph.pl --consumer . --package production-package \
  --target wasm32-unknown-unknown --all-features \
  --forbid candid_parser --forbid pocket-ic --require ic-cdk-executor=1
```

Pass one or more explicit `--package NAME` selections and one `--target TRIPLE`
(or `all` for a deliberate cross-target union). Match the actual build's default
feature behavior: use `--no-default-features` and `--features LIST` when needed,
or `--all-features`. At least one `--forbid NAME` or `--require NAME=COUNT` is
required. Counts are per package name; zero requires absence. Invalid/conflicting
policy and CR/LF directories fail before Cargo, including resolved path aliases.

The helper runs locked, offline Cargo tree with normal/build edges and flat
`{p}` labels. It admits output only after successful completion; a failed or
signalled child cannot supply a successful observation. Empty/malformed output
or missing selected roots fails. Names are Cargo's canonical package names,
including dependencies renamed by callers. Development edges are excluded.

Identity counting retains each full rendered label, including version and any
source qualifier Cargo prints; only the repeated-node `(*)` marker is removed.
Two versions or differently qualified sources count separately. This deliberately
matches existing consumer tree checks, not a source-authentication or artifact
identity guarantee. Registry/source admission, lock/source custody and exact bytes
remain separate obligations. Do not substitute name/version-only identity parsing.

Consumers may replace their repeated tree invocation, name matching and rendered
identity collectors with this checker, keeping feature matrices, cryptographic
policy, timer placement and lifecycle/recovery tests local. Prefer explicit calls
over new wrappers that only rename this command. Snapshot consumers select this
script as an entrypoint through the canonical exporter; do not copy/edit it.

A passing graph check does not compile or deploy anything. Bind successful locked
build evidence, source/lock identities, actual target/features and final artifact
digest to any deployment. Native hosts and installed IC behavior retain separate
qualification.
