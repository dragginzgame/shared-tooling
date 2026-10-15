# Canonical software licenses
<!-- Shared companions: scripts/ci/check-license.pl -->

Shared Tooling owns the master wording for the two selected licenses:

- [MIT](../licenses/MIT.txt): the other sibling libraries and tools, including
  Shared Tooling.
- [Dragginz Source Available License — Verifiable ICP Burn 1.0](../licenses/Dragginz-ICP-Burn-1.0.txt):
  IcyDB, Canic and IC Relay. Third-party Live Deployments require verifiable mainnet
  burning: 100% of ordinary resource funding or at least 20% of Cloud Engine
  infrastructure value. Toko Studios Ltd has the express section 5 exception.

The Cloud Engine base includes comparable market value for free or affiliated
infrastructure. Advance burn coverage and public deployment-linked evidence are
required; monthly reconciliation is not permission to operate without burning.
Contributor acceptance must expressly include the organization exception.
The named beneficiary is part of the fixed terms, not a consumer-editable field.

Shared Tooling itself uses the [root MIT license](../LICENSE). These templates
do not retroactively change consumer releases or third-party license grants.
The Dragginz text remains a custom draft requiring legal and contributor-ownership
review before adoption.
Previously granted rights and third-party licenses remain intact.

## Consumer copies

Replace `{{COPYRIGHT_NOTICES}}` with the repository's existing copyright lines.
Preserve every applicable holder and year; do not replace ownership notices with
a blanket organization name. Where no notice exists, use Toko Studios Ltd
and the applicable year. Copy the complete terms into the consumer's
`LICENSE`. Package copies must carry the same terms and applicable notices.
Do not edit the terms in consumers. Changes to the Dragginz terms require a new
versioned master and deliberate consumer adoption; preserve version 1.0 once
adopted. This unadopted draft replaces the earlier blanket-ban draft. MIT stays the standard MIT text.

Canic and IcyDB additionally retain their prior MIT grants: append the exact
[prior-material notice](../licenses/prior-mit-notice.txt), followed by MIT with
the original copyright notices. This is not an MIT alternative for later
contributions offered exclusively under Dragginz. IcyDB also preserves its
original Apache-2.0 and MIT notices for previously covered material, including
in published packages. Relay has no such appendix.

For Cargo, use `license = "MIT"` at the workspace root and inherit it in members.
For Dragginz, use `license-file = "LICENSE"` in `workspace.package` and
`license-file.workspace = true` in members. Do not retain an alternative MIT
declaration for newly restricted code. Check package file lists to ensure the
license ships; root metadata alone does not establish archive contents.

Apply inherited metadata to unpublished workspace members too. For every
publishable package, inspect `cargo package --list --locked -p PACKAGE` and
verify that the applicable license text and preserved notices are present.
A root MIT declaration does not automatically include a root license outside
the package directory; add an unchanged package-local copy where needed.
Cargo can include the workspace-inherited `license-file` automatically, so
check the actual file list before duplicating it. Repeat this focused check
when changing package layout, include/exclude rules or licensing metadata.

## Drift checks

Run centrally against explicit consumer paths:

```bash
perl scripts/ci/check-license.pl --kind mit --file /path/to/library/LICENSE
perl scripts/ci/check-license.pl --kind dragginz --file /path/to/ic-relay/LICENSE
perl scripts/ci/check-license.pl --kind dragginz --prior-mit --file /path/to/canic/LICENSE
```

The checker permits repository-specific opening copyright lines, line wrapping
and whitespace. It rejects altered, missing or additional terms and undeclared
appendices. It does not establish ownership, legal enforceability, completeness
of copyright attribution, Cargo metadata consistency or deployment compliance.

For offline consumer CI, adopt `scripts/ci/check-license.pl` as an entrypoint
through the [reviewed snapshot workflow](consuming-snapshots.md). Its companion
declaration includes all three canonical text files. Pin a committed Shared
Tooling revision; do not point CI at a moving sibling checkout. Wire the explicit
command into the consumer's existing checks when adopting the snapshot.
Snapshot integrity detects edits to the masters; this checker detects drift in
the consumer's distributed license. This addition does not activate consumer CI
or change existing snapshots automatically.

Run the focused checker fixtures with `make test-licenses`.
