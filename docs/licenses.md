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

## Proposed TSNL-1.1: legal and release review

The [Toko Studios Network Licence 1.1 draft](../licenses/Toko-Studios-1.1.md)
develops the earlier
[Toko Reciprocal Network Licence 1.0 draft](../licenses/Toko-Studios-1.0.md).
Neither draft is adopted or approved for publication or consumer relicensing.
This checklist is review documentation, not part of either proposed legal
instrument.

The 1.1 draft permits compliant use on the canonical IC and on private,
sovereign, government, enterprise or disconnected IC-based deployments that
provide advance canonical-mainnet ICP burn coverage. Private deployments must
cover 100% of canonical-equivalent operational resource charges, dedicate and
retire the resulting cycles, and publish independently reviewable evidence. No
separate infrastructure-value surcharge applies.

The draft preserves Toko's separate licensing and freedom-to-operate rights and
identifies Toko Studios Limited, IBC No. 1503915, as the Organisation. It does
not implement holding-company, insolvency or founder-control protection.

The selected source-reciprocity policy requires public Corresponding Source for
Covered Modifications distributed or used in Production Operation, including
internal business operation. Independent Applications may remain proprietary,
private non-production modification alone does not trigger publication, and
publication requires neither a pull request nor the Organisation's acceptance.

The fixed Section 18 Resource Equivalence Schedule addresses subsidised, free,
bundled and unmetered production resources, including query execution. It also
aggregates Related Parties, sidecars, authoritative off-chain stores and split
deployments according to operational substance. Qualifying private burns require
objectively verifiable cycle retirement with no recovery or economic benefit.

The query treatment is deliberate: the current official
[cycles overview](https://docs.internetcomputer.org/concepts/cycles/) and
[cycle-cost table](https://docs.internetcomputer.org/references/cycle-costs/)
describe query calls as free even though they consume node resources. Counsel
must decide whether a private licence may and should impose this supplemental
burn condition on canonical operation, and technical review must confirm that
operators can measure it predictably.

The draft conditions Production Operation on tamper-evident measurement,
allocation, burn and retirement evidence. Missing data requires a conservative
upper-bound estimate; provider assertions and screenshots alone are
insufficient. Proportionate supporting-record requests and independent
confidential audits are available for documented material compliance concerns.

Governing-law shortlist:

- Laws of the Principality of Monaco, with disputes subject to the courts of
  Monaco. This is a candidate only; counsel must confirm the appropriate court
  wording, jurisdiction, service, conflict-of-laws treatment and enforcement
  before replacing the draft placeholders.

Before adoption:

- Confirm the Organisation's exact registered identity and select governing law
  and forum with counsel.
- Verify employee, contractor and contributor copyright and patent authority for
  every designated release. Company membership and repository access are not
  evidence of assignment.
- Establish the repository contribution-eligibility and signed-acceptance
  process. The draft does not itself establish contributor consent.
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

These records identify evidence and discrepancies; they do not declare
ownership or authority to relicense. Signed agreements, employment records and
identity documents must remain in a private legal evidence system. Repository
audit records should contain only an immutable digest, custodian and opaque
evidence reference.
