# Toko Studios licensing work

Toko Tooling no longer carries the retired MIT, Dragginz burn-licence or
Dragginz CLA master copies removed in the 0.39.0 work. Their removal does not
revoke earlier grants, erase third-party terms or establish authority to
relicense existing material. Consumer repositories must preserve every licence
and notice already applicable to their code and releases.

New in-house code must follow the
[independent implementation rule](../TOKO-TOOLING.md#independently-owned-implementations).
Maintaining an upstream fork does not establish ownership. External dependencies
remain separately licensed, and existing imports retain their terms and notices
during an explicitly recorded migration or exception. Removing a notice is not
a migration.

## Adopted TSNL-1.0

The [Toko Studios Network Licence 1.0](../LICENSE.md) was adopted by Toko
Studios Limited on 10 November 2026. It is the first adopted TSNL version; the
superseded development drafts have been removed from the working tree. Its
governing law is the law of the Principality of Monaco and disputes are subject
to the exclusive jurisdiction of Monaco's competent courts, subject to
mandatory applicable law.

Except where a file or notice states otherwise, the repository notice offers
material under TSNL-1.0 by each applicable Copyright Holder only to the extent
that holder owns or is authorised to license the relevant rights. Adoption does
not transfer contributor copyright to Toko Studios Limited, cure a missing
assignment or override an earlier or third-party grant.

TSNL-1.0 permits compliant use on the canonical IC and on private, sovereign,
government, enterprise or disconnected IC-based deployments that provide
advance canonical-mainnet ICP burn coverage. Private deployments must cover
100% of canonical-equivalent operational resource charges, dedicate and retire
the resulting cycles, and publish independently reviewable evidence. No
separate infrastructure-value surcharge applies.

The Licence preserves Toko's separate licensing and freedom-to-operate rights
and identifies Toko Studios Limited, IBC No. 1503915, as the Organisation. It
does not implement holding-company, insolvency or founder-control protection.

This selection does not relicense consumers or external dependencies. The root
licence preserves the original MIT notice for previously MIT-licensed material;
that notice does not offer later additions under MIT.

## Outstanding legal and operational review

The query treatment is deliberate: the current official
[cycles overview](https://docs.internetcomputer.org/concepts/cycles/) and
[cycle-cost table](https://docs.internetcomputer.org/references/cycle-costs/)
describe query calls as free even though they consume node resources. TSNL-1.0
nevertheless includes the supplemental resource-equivalence condition. Legal
and technical reviewers should continue testing its enforceability and whether
operators can measure it predictably; a later revision cannot retract grants
already made under TSNL-1.0.

The Licence conditions Production Operation on tamper-evident measurement,
allocation, burn and retirement evidence. Missing data requires a conservative
upper-bound estimate; provider assertions and screenshots alone are
insufficient. Proportionate supporting-record requests and independent
confidential audits are available for documented material compliance concerns.

Post-adoption review and rollout:

- Verify employee, contractor and contributor copyright and patent authority for
  every designated release. Company membership and repository access are not
  evidence of assignment.
- Establish the repository contribution-eligibility and signed-acceptance
  process. The Licence does not itself establish contributor consent or transfer
  ownership of a contribution.
- Validate private-deployment resource classification, transferred credits,
  pooled balances, measurement and funding evidence against real deployments.
- Test Section 18 against free queries, later protocol subsidies, bundled
  services, authoritative sidecars, off-chain storage and split Related Party
  deployments.
- Validate the mechanism for dedicating and irreversibly retiring cycles and
  proving no sale, reuse or double counting without exposing protected data.
- Confirm that evidence requests, confidential audits, cost allocation,
  suspension and correction rules are enforceable and proportionate.
- Preserve earlier public grants and independently licensed dependencies in
  every publication artifact.
- Obtain Monaco-qualified advice on forum wording, service, conflict-of-laws
  treatment and enforcement. Record any amendment as a new licence version;
  never silently change TSNL-1.0 after publication.

## Proposed Toko Studios CLA 1.0

The [Toko Studios Contributor Licence and Copyright Assignment Agreement 1.0
draft](../licenses/Toko-Studios-CLA-1.0.md) is the proposed contribution
agreement for TSNL-covered projects. It uses the supplied Company identity and
assigns copyright to Toko Studios Limited, with a broad irrevocable fallback
licence if an assignment is ineffective.

It also addresses future rights, employer and contractor authority, historical
contribution schedules, third-party and generated material, moral-rights consent,
and patent licensing and non-assertion.

The draft is not approved for signature. Governing-law and forum placeholders
remain open, and counsel must confirm consideration, execution, future-rights,
moral-rights, patent, insolvency, privacy and recording requirements in every
relevant jurisdiction. Existing contributors are not bound without individual
signed acceptance.

## Software title audits

The [portfolio title-audit register](legal/title-audits/index.md) records the
first evidence pass across the repositories returned by the GitHub organisation
listing and additional local-only checkouts. The accompanying
[method](legal/title-audits/README.md) uses a central register plus one record per
repository.

The [contributor identity and rights register](legal/title-audits/contributors.md)
records maintainer-supplied alias mappings separately from legal clearance. It
flags unsigned current and former contractors, uncertain small contributions and
the unverified Mana Point-to-Toko chain so a matched name is never mistaken for
an assignment.

These records identify evidence and discrepancies; they do not declare
ownership or authority to relicense. Signed agreements, employment records and
identity documents must remain in a private legal evidence system. Repository
audit records should contain only an immutable digest, custodian and opaque
evidence reference.
