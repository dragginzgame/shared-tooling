# Canonical software licenses
<!-- Shared companions: scripts/ci/check-license.pl -->

Shared Tooling owns the master wording for the two selected licenses:

- [MIT](../licenses/MIT.txt): the other sibling libraries and tools, including
  Shared Tooling.
- [Toko Studios Source Available License — Verifiable ICP Burn 1.1](../licenses/Dragginz-ICP-Burn-1.1.txt), referred to here as Dragginz:
  IcyDB, Canic and IC Relay. Third-party Live Deployments require verifiable mainnet
  burning: 100% of ordinary resource funding or at least 20% of Cloud Engine
  infrastructure value. Toko Studios Ltd has the permanent section 7 exception
  and section 11.2 patent rights.

The Cloud Engine base includes comparable market value for free or affiliated
infrastructure. Advance burn coverage and public deployment-linked evidence are
required; monthly reconciliation is not permission to operate without burning.
Contributor acceptance must expressly include the organization exception.
The named beneficiary is part of the fixed terms, not a consumer-editable field.

Shared Tooling itself uses the [root MIT license](../LICENSE). These templates
do not retroactively change consumer releases or third-party license grants.
Previously granted rights and third-party licenses remain intact.

## Patent protection: Dragginz 1.1

The ICP burn requirements are economic conditions for Live Deployment, separate
from the patent protections below. They do not restrict access to courts or
provide immunity from litigation. Operator conditions use neutral terms; the
express Toko Studios exceptions remain distinct.

Section 11 grants covered contributor patent rights and terminates section 11.1
permissions when the recipient initiates or directs the patent claims described
in section 11.3. It is not a general prohibition on lawsuits or license
enforcement. The exact grant and termination scope are defined by the license.

Toko Studios' section 11.2 patent rights are permanent, sublicensable and exempt
from section 11.3 termination. Its section 7 copyright exception does not itself
exempt independently operated downstream deployments from sections 3 through 6.
No contributor grants patents it lacks authority to license. Existing patent
licenses, including earlier Apache grants, remain unaffected.

Version 1.1 is the current master. The [original 1.0 text](../licenses/Dragginz-ICP-Burn-1.0.txt)
is retained unchanged for historical copies. Promotion does not automatically
replace consumer licenses or establish rights-holder acceptance.

## Contributor agreements and relicensing

The [Dragginz CLA 1.0](../licenses/Dragginz-CLA-1.0.md) is a separate
agreement with Toko Studios Ltd, not another software license. Contributors
retain ownership while granting explicit copyright sublicensing and alternative
licensing rights, including proprietary/commercial terms. This is broader than
the more-permissive-only relicensing provision in
[IC license section 3(J)](https://github.com/dfinity/ic/blob/master/licenses/IC-1.0.txt).
Its permanent patent grant aligns with the Company's protection under section
11.2 of Dragginz 1.1, including survival and sublicensing rights.

For adoption, record the fixed agreement version, covered repositories,
company signatory and private signature custodian.
Provide the exact text and record informed acceptance; merely adding a CLA file,
opening a PR, adding a checkbox or using a Git sign-off is not a signed CLA.
An agent cannot sign for a human, employer or copyright holder.

For each adopting repository, document the signing route in its contribution
guide. Before merging covered contributions, verify an executed agreement for
each relevant rights holder and its repository, account and contribution scope.
For employer-owned work, verify corporate authority or obtain the owner's
agreement. Keep signatures and contact details privately; the PR needs only a
minimal reviewed acceptance reference, bound to the contributor and agreement
version. A bot may check an approved acceptance registry; it cannot infer consent.
No signing service, registry, CI gate or branch protection is installed here yet.

Audit existing contributions separately. Obtain express retrospective grants for
identified material where needed, rely on rights already sufficient for the
proposed use, preserve separately licensed material under its own terms, or
remove/replace it with properly authorized work. A new CLA cannot retroactively
bind previous contributors, revoke recipients' existing grants or relicense
third-party dependencies. Do not claim blanket relicensing clearance from a
clean future-contributor checklist.

## Consumer copies

Replace `{{COPYRIGHT_NOTICES}}` with the repository's existing copyright lines.
Preserve every applicable holder and year; do not replace ownership notices with
a blanket organization name. Where no notice exists, use Toko Studios Ltd
and the applicable year. Copy the complete terms into the consumer's
`LICENSE`. Package copies must carry the same terms and applicable notices.
Do not edit the terms in consumers. Changes to the Dragginz terms require a new
versioned master and deliberate consumer adoption; preserve version 1.0 once
adopted. MIT stays the standard MIT text.

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
the package directory; add an unchanged package-local regular file where needed,
never a symlink to the root license. Preserve the complete terms and notices.
Cargo can include the workspace-inherited `license-file` automatically, so
check the actual file list before duplicating it. Repeat this focused check
when changing package layout, include/exclude rules or licensing metadata.

## Drift checks

Run centrally against explicit consumer paths:

```bash
perl scripts/ci/check-license.pl --kind mit --file /path/to/library/LICENSE
perl scripts/ci/check-license.pl --kind dragginz --file /path/to/ic-relay/LICENSE
perl scripts/ci/check-license.pl --kind dragginz --prior-mit --file /path/to/canic/LICENSE
# Explicit historical verification; not a claim of 1.1 adoption:
perl scripts/ci/check-license.pl --kind dragginz --license-version 1.0 --file /path/to/old/LICENSE
```

The Dragginz checker defaults to 1.1; `--license-version 1.1` may make that
selection explicit. Historical copies require `--license-version 1.0`.
When updating the checker snapshot, update its consumer license deliberately or
select the historical version explicitly; do not mistake a mismatch for a
corrupt historical grant.

The checker permits repository-specific opening copyright lines, line wrapping
and whitespace. It rejects altered, missing or additional terms and undeclared
appendices. It does not establish ownership, legal enforceability, completeness
of copyright attribution, Cargo metadata consistency or deployment compliance.

For offline consumer CI, adopt `scripts/ci/check-license.pl` as an entrypoint
through the [reviewed snapshot workflow](consuming-snapshots.md). Its companion
declaration includes MIT, both versioned Dragginz texts and the prior-material
notice. The CLA is a separately selected agreement, not an appendix to a software
license. Pin a committed Shared
Tooling revision; do not point CI at a moving sibling checkout. Wire the explicit
command into the consumer's existing checks when adopting the snapshot.
Snapshot integrity detects edits to the masters; this checker detects drift in
the consumer's distributed license. This addition does not activate consumer CI
or change existing snapshots automatically.

Run the focused checker fixtures with `make test-licenses`.
