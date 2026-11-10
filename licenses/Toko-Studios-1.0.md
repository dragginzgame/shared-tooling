# TOKO RECIPROCAL NETWORK LICENCE
## Version 1.0 — Draft for Legal Review

**Toko Studios Ltd**

**Status:** Proposed unified source-available software licence  
**Licence identifier:** TRNL-1.0  
**Intended scope:** All expressly designated Toko Studios software products, libraries, frameworks, databases, runtime components, development tools and associated materials.

---

## 1. Purpose and Scope

### 1.1 Purpose

The Toko Reciprocal Network Licence ("Licence") permits the use, inspection, modification, distribution and commercial exploitation of covered software while preserving:

a. The economic alignment of production deployments with the canonical Internet Computer network and its native ICP token.

b. Public access to modifications of the covered software distributed or operated in production.

c. The intellectual property rights of the relevant copyright holders.

d. The ability of Toko Studios Ltd to develop, commercialise, migrate and separately license the software on other execution networks.

e. Protection against unauthorised appropriation of the covered software for competing blockchain networks, proprietary execution platforms and privately controlled infrastructure.

### 1.2 Application

This Licence applies to source code, documentation, tools, libraries, WebAssembly modules and other copyrightable material expressly identified as being distributed under TRNL-1.0 ("Licensed Material").

It applies to the Licensed Material regardless of its programming language, compilation target, distribution format or execution environment.

The Licence does not automatically apply to independently licensed third-party dependencies or other material merely because they are distributed in the same repository.

### 1.3 Nature of Licence

This is a source-available software licence with reciprocal source-disclosure and network-use restrictions.

It is not the GNU GPL, GNU AGPL, MIT Licence or an Open Source Initiative-approved open-source licence.

Permissions not expressly granted remain reserved to their respective rights holders.

## 2. Definitions

### 2.1 Licensing Organisation

"Organisation" means Toko Studios Ltd, the specifically identified legal entity, acting to the extent that it owns or is authorised to license the relevant intellectual property.

The Organisation does not include its shareholders, parent companies, subsidiaries, purchasers, investors or affiliated entities merely because of that relationship.

### 2.2 Copyright Holder

"Copyright Holder" means a person or legal entity owning or lawfully controlling copyright in the relevant Licensed Material.

Each Copyright Holder grants permissions only to the extent of the rights it lawfully controls.

### 2.3 Licensee

"You" or "Licensee" means any individual or legal entity exercising rights under this Licence.

### 2.4 Covered Software

"Covered Software" means the Licensed Material and copyright-protected portions of any modifications, adaptations, translations, reproductions or derivative works of that material.

Covered Software includes relevant source code and compiled forms, including WebAssembly, native binaries, embedded runtime components and other executable formats.

A change in programming language, compilation target, packaging, module boundaries or execution architecture does not remove copyright-protected material from the scope of this Licence.

Independently created software that does not reproduce or adapt protected expression from the Licensed Material is not Covered Software merely because it performs equivalent functions.

### 2.5 Covered Modification

"Covered Modification" means any alteration, replacement, extension or adaptation of copyright-protected implementation code originating from the Covered Software.

This includes changes to covered runtime logic, database implementation, framework machinery, orchestration, storage components, internal macros and other protected implementation material.

A Covered Modification does not cease to be covered because it is moved to another package, service, process, repository, programming language or WebAssembly module.

### 2.6 Independent Application

"Independent Application" means independently authored application-specific software that uses the Covered Software through its documented interfaces, APIs, macros, schemas, generated bindings or other intended integration mechanisms without constituting a Covered Modification.

An Independent Application may be proprietary and may be distributed without publishing its independently authored source code.

Static linking, compilation into the same WebAssembly module, use of procedural macros or ordinary generation of application bindings does not, by itself, eliminate this exception.

However, independently authored application code must not be used to conceal a modification of the Covered Software itself.

Copyright-protected implementation material copied or adapted from Covered Software remains covered to the extent applicable.

### 2.7 Canonical Internet Computer

"Canonical Internet Computer" means the continuously operating public Internet Computer mainnet existing when this Licence is first published, operating under its Network Nervous System governance architecture and retaining native ICP-based economic resource funding.

Ordinary protocol upgrades, system-canister replacements and governance-approved technical improvements do not create a new network where the same public network continues with its established state history, native ICP economics and governance continuity.

Temporary outages, maintenance or interruptions of service do not, by themselves, end canonical status. Resumption of the same network with that state history, native ICP economics and governance continuity remains within this definition; an interruption does not grant canonical status to a separate replacement network.

The following are not automatically part of the Canonical Internet Computer:

a. Forks or copies of the protocol.

b. Independent networks created from Internet Computer source code.

c. Privately operated or permissioned replacement networks.

d. Networks created by exporting, copying or migrating Internet Computer state.

e. Competing WebAssembly execution networks.

f. Replacement networks operating under a materially separate governance or economic system.

g. Successor networks that replace native ICP-based resource funding with an alternative economic mechanism.

Using the Internet Computer name, software, technology, canister interfaces or historical state does not independently establish canonical status.

### 2.8 Production Operation

"Production Operation" means use of Covered Software to execute, store, coordinate, administer or otherwise support genuine operational workloads.

This includes commercial services, enterprise systems, internal business operations, publicly accessible applications and operational infrastructure, whether or not fees are charged.

It also includes the use of Covered Software as a material component of tooling that provisions, manages or operates a production execution network.

Production Operation does not include isolated non-operational development, testing, benchmarking, security research or validation permitted under Section 4.

Ancillary operational use outside the Canonical Internet Computer is permitted only within Section 4.3 or a separate permission under Section 11; its operational character does not by itself disqualify it from the Section 4.3 exception.

### 2.9 Qualifying ICP Burn

"Qualifying ICP Burn" means the actual, irreversible destruction of native ICP through the canonical Internet Computer's recognised ICP-to-cycles conversion mechanism.

A Qualifying ICP Burn must be independently verifiable from appropriate canonical ledger, cycles-minting and supporting protocol records.

The following do not independently constitute Qualifying ICP Burns:

a. Transfers or staking of ICP.

b. Burning a wrapped or synthetic representation of ICP.

c. Destruction of cycles without evidence of qualifying original ICP conversion.

d. Locally fabricated cycles or resource credits.

e. Resource credits issued by an alternative network without qualifying ICP destruction.

f. Accounting entries, promises, token locks or simulated transactions.

Burns previously completed to fund qualifying resource credits may be counted. This Licence does not require ICP to be destroyed a second time merely because qualifying cycles are transferred or consumed.

### 2.10 Corresponding Source

"Corresponding Source" means the complete human-readable source necessary to understand, modify, compile and reproduce the relevant Covered Software or Covered Modification.

It includes applicable source files, build definitions, dependency specifications, interface definitions, generated-source inputs, relevant patches and necessary build instructions.

It does not require disclosure of credentials, private keys, user information, production databases, proprietary business data or independently authored application code covered by Section 2.6.

For a combined build containing an Independent Application, Corresponding Source must permit reconstruction and compilation of the covered components, not reproduction of the complete proprietary application or its deployed binary. Application-specific inputs may be replaced by documented interface descriptions, non-proprietary fixtures or a minimal build harness sufficient to compile those components. Such replacements must not omit or conceal Covered Modifications. Macro-generated or other generated output containing protected implementation material remains covered to that extent; independently authored application material does not become covered merely because it appears in the same output.

## 3. General Grant of Rights

Subject to the conditions and restrictions of this Licence, each Copyright Holder grants You a worldwide, non-exclusive, royalty-free copyright licence to:

a. Access, inspect, study and reproduce the Covered Software.

b. Modify the Covered Software and create Covered Modifications.

c. Compile the Covered Software to native, WebAssembly or other executable forms.

d. Distribute copies of Covered Software and Covered Modifications in source or executable form.

e. Develop and commercialise Independent Applications using the Covered Software.

f. Operate Covered Software in production on the Canonical Internet Computer in accordance with Sections 5 through 9.

g. Perform the development, testing, research and ancillary activities expressly permitted under Section 4.

These permissions continue for the applicable copyrighted material while You comply with this Licence.

No application-revenue royalty, percentage of business profits or direct licensing fee is payable to the Organisation solely by reason of permitted Canonical Internet Computer use.

The network and economic restrictions in this Licence are express conditions of the operational permissions granted.

No permission for unauthorised alternative-network Production Operation is granted by this Section.

## 4. Development, Testing and Ancillary Use

### 4.1 Permitted non-production use

You may operate Covered Software in local development environments, simulations, disposable test networks, continuous integration systems, security laboratories and benchmarking environments.

Such environments may use fabricated cycles, synthetic accounts, simulated consensus or non-production infrastructure.

### 4.2 Operational boundary

An environment is not exempt merely because it is labelled a test network, research network, staging system or experimental deployment.

An environment supporting genuine third-party or internal operational workloads constitutes Production Operation regardless of its description.

### 4.3 Host tools and client software

Covered Software may execute outside the Canonical Internet Computer when reasonably necessary to build, deploy, administer, monitor, secure, back up, restore or interact with authorised Canonical Internet Computer applications.

This includes development workstations, administrative servers, browsers and supporting client systems.

This is an express exception to Section 5.1 for the ancillary execution described here, including when it supports live operational workloads. Section 6 continues to apply to the authorised Canonical Internet Computer deployment, but imposes no separate ICP-burn requirement on the ancillary host's compute, storage or network costs. Section 9 requires evidence for the supported deployment's applicable funding obligations, not a separate host-infrastructure burn account. Section 8 remains applicable to source access for distributions and to Covered Modifications operated in production on an ancillary host.

Such permission does not authorise the operation of a competing production execution network using Covered Software.

This exception does not permit Covered Software to execute substantive application workloads, serve as a live application database, or provide a substitute production runtime or execution platform outside the Canonical Internet Computer, regardless of motive. Genuine client interaction, deployment administration, monitoring, security operations, backup storage and restoration to an authorised deployment remain permitted ancillary activities. Operating a backup as a live off-network application database or using administrative tooling as a substitute application execution platform is not ancillary use. Isolated recovery tests remain subject to Section 4.1; separate permissions may be granted under Section 11.

## 5. Exclusive Production Network Authorisation

### 5.1 Exclusive permission

Except for ancillary execution expressly permitted by Section 4.3 and permissions under Section 11, Production Operation of Covered Software is permitted only on the Canonical Internet Computer. Third-party alternative-network permissions under Section 11 require the separate written authorisation specified there.

### 5.2 Prohibited alternative networks

Without separate written authorisation, You must not deploy, operate or materially use Covered Software to establish, support or administer:

a. A competing blockchain or decentralised execution network.

b. A functional fork or adaptation of the Internet Computer operated as a separate production network.

c. A privately controlled, permissioned, sovereign or enterprise blockchain outside the Canonical Internet Computer.

d. An alternative WebAssembly-based distributed execution platform.

e. A replacement network intended to supersede the Canonical Internet Computer.

f. An off-chain or hybrid production execution environment used as a substitute for the permitted network's substantive runtime functions.

This prohibition applies whether the alternative platform is commercial, charitable, decentralised, publicly funded, privately owned or operated without fees.

### 5.3 No technical circumvention

Permission is not created merely because a competing platform:

a. Executes compatible WebAssembly modules.

b. Implements Internet Computer system APIs.

c. Reuses canister identifiers or network state.

d. Reproduces the Internet Computer's consensus architecture.

e. Uses compatible Rust libraries or developer tooling.

f. Provides equivalent multi-canister or multi-Wasm execution.

g. Burns ICP or pays other consideration.

### 5.4 Burn payments do not confer network rights

Qualifying ICP Burns do not independently authorise use of Covered Software on an alternative network.

The funding requirements of Section 6 apply only to Production Operations otherwise permitted under this Licence.

Payment or subsequent ICP conversion cannot cure a violation of this Section.

### 5.5 No automatic successor rights

No foundation, protocol developer, governing body, successor corporation, infrastructure operator or network participant acquires additional rights to Covered Software merely by succeeding to, acquiring, administering or replacing part of the Internet Computer ecosystem.

Any materially separate successor network requires express authorisation.

## 6. Canonical Network ICP Funding Requirement

### 6.1 Mandatory economic alignment

Permission for Production Operation on the Canonical Internet Computer is conditional on one hundred percent (100%) of the cycles or other protocol resource credits used to pay the relevant deployment's operational charges originating from Qualifying ICP Burns.

Where charges are denominated in cycles, the cycles applied to those charges must originate from qualifying canonical ICP-to-cycles conversion.

### 6.2 Existing burns and transfers

Qualifying conversions performed by the Licensee, infrastructure providers, service operators or other legitimate funding sources may satisfy this condition.

Transfers through the canonical cycles ledger, canisters or verifiably qualifying funding pools do not create an additional burn obligation.

Compliance may be established through identifiable conversion records together with transfer records or reconciled pool records connecting a quantified share of the qualifying credits to the deployment. Pool records must account for opening balances, qualifying inflows, other inflows, transfers, consumption and closing balances, with allocations sufficient to prevent the same credits being attributed to more than one expenditure. Physical identification of individual fungible cycles is not required; documented quantitative attribution is required. A balance or provider assertion unsupported by those records does not establish qualifying origin.

### 6.3 Non-qualifying funding

No portion of the resource charges subject to Section 6.1 may be funded through unauthorised synthetic issuance, independent alternative-network credits or mechanisms without qualifying canonical ICP destruction.

Mixing qualifying and other credits does not make the other credits qualifying. An operator using a mixed balance must maintain the quantitative allocation records required by Section 6.2 and attribute covered expenditures only to its demonstrated qualifying balance, reducing that balance as credits are spent or transferred. Any amount whose qualifying origin or remaining availability cannot be established must be treated as nonqualifying for this purpose. Later qualifying inflows cannot retrospectively qualify earlier expenditures.

### 6.4 Scope

The requirement applies to resource funding, not to total application revenue, transaction volume, token supply, customer assets or unrelated business turnover.

It does not create an obligation to burn ICP for a request or operation for which the canonical network imposes no resource charge.

## 7. Uniform Funding Rule

Section 6 applies equally to shared, dedicated, reserved and separately controlled capacity within the Canonical Internet Computer. Product names, infrastructure ownership and commercial arrangements do not create a different funding threshold.

There is no additional burn calculated as a percentage of infrastructure cost or value. This Licence requires no infrastructure valuation, market-price comparison, currency-value reconciliation or minimum spend beyond the qualifying origin of the protocol resource credits actually used. Operations for which the canonical network imposes no resource charge incur no separate burn requirement.

Qualifying funding does not authorise an alternative network or substitute off-network production runtime. Sections 4.3, 5 and 11 continue to govern ancillary execution, network eligibility and separate permissions.

## 8. Reciprocal Source-Code Obligations

### 8.1 General obligation

A Licensee that distributes Covered Modifications, or performs Production Operation using Covered Modifications, must make their Corresponding Source publicly available under this same Licence.

This obligation applies whether the Covered Modifications are distributed directly, embedded in compiled software or operated without distributing executable copies.

Production Operation includes internal business operations under Section 2.8, even where access is restricted to employees, contractors or other authorised internal users. Required Corresponding Source must be publicly available; providing it only to those users is insufficient. Compliance with the network and qualifying-burn requirements does not replace this source-publication obligation.

Private creation and use of Covered Modifications solely for non-production activities permitted by Section 4.1 do not, by themselves, trigger publication. Distribution of those modifications or their use in Production Operation triggers this Section. Independently authored application code remains subject to the exceptions in Sections 2.6, 2.10 and 8.5, and is not subject to mandatory disclosure merely because it uses a modified covered component.

The Organisation's separate rights, and permissions expressly granted under a separate written licence, are governed by Section 11.7. Receipt of Covered Software from the Organisation does not by itself create an exception to this Section.

### 8.2 Publication

Corresponding Source must be made available:

a. Without a licensing fee or access charge.

b. In a commonly usable, machine-readable source format.

c. With reasonably complete instructions necessary to build the covered components.

d. Under this Licence, without additional restrictions inconsistent with its terms.

e. No later than the commencement of Production Operation using those modifications, or their first distribution in source or executable form, whichever occurs first.

Publication may be made through a publicly accessible repository or another source-distribution location meeting this Section. It does not require submission of a pull request, delivery through an official Organisation repository, or the Organisation's review, acceptance, merger or maintenance of the modifications. Publication does not transfer copyright ownership; the express grants elsewhere in this Licence remain applicable. Section 12.5 governs official contribution acceptance.

### 8.3 Availability period

The relevant source must remain available throughout Production Operation and for at least three years after the last distribution or Production Operation of the applicable version.

Where unmodified upstream source remains available at a stable, identifiable location, the Licensee may reference that exact upstream version and publish the complete modifications and information necessary to reconstruct the covered result.

### 8.4 Identification of modifications

Material changes to Covered Software must be clearly identified, including sufficient version and build information to distinguish modified implementations from official releases.

### 8.5 Independent Application exception

This Licence does not require publication of independently created application source code solely because that application:

a. Uses a Covered Software library.

b. Calls Covered Software APIs.

c. Includes generated bindings or macro expansions.

d. Links Covered Software statically or dynamically.

e. Is compiled into a WebAssembly module containing unmodified Covered Software.

f. Communicates with Covered Software through inter-canister calls.

This exception does not extend to Covered Modifications embedded within such applications.

### 8.6 No proprietary relicensing of Covered Modifications

A Licensee may not distribute Covered Modifications exclusively under a proprietary licence that denies recipients the reciprocal source-code permissions required by this Section.

Separate licensing of independently authored application code remains permitted.

### 8.7 Source-access notice

Where Covered Modifications are operated as a network service, the operator must provide a reasonably accessible public notice identifying the applicable source location and version.

The notice may be supplied through documentation, a service interface, deployment metadata or another publicly discoverable mechanism appropriate to the deployment.

### 8.8 Source access for unmodified executables

A Licensee distributing Covered Software in unmodified executable form, including as a component of a combined application, must provide public access to the exact Corresponding Source for that covered version no later than its first distribution. The access conditions in Sections 8.2(a) through 8.2(d) and the availability period in Section 8.3 apply. The distribution must identify the covered version and give a reasonably accessible source location. The Independent Application exception and combined-build boundary in Sections 2.6, 2.10 and 8.5 continue to apply.

The distributor may use a stable upstream link identifying the exact source version while that source remains publicly available on those terms. The distributor must retain a copy or another reliable means of supplying that exact source throughout the required period. If the upstream source becomes unavailable, the distributor must promptly provide a replacement source location or host the exact source itself. From discovery or written notice of the outage, whichever occurs first, it must not make further executable distributions until access is restored. Reliance on upstream hosting does not transfer this responsibility to the upstream provider. An inadvertent availability defect may qualify for Section 14.4's correction protection, but that protection does not permit further executable distribution after that discovery or notice while the required source is unavailable.

## 9. Evidence, Verification and Recordkeeping

### 9.1 Verifiable funding

Each Production Operation subject to Section 6 must maintain evidence reasonably sufficient to demonstrate the qualifying origin and available quantity of its operational resource credits.

Appropriately identified canonical protocol funding records and verifiable pooled funding evidence may satisfy this requirement without reconstructing every individual cycle transfer.

### 9.2 Funding records

Records must identify the relevant deployment, qualifying conversion references and quantities of resource credits obtained, together with any transfer or pool-allocation evidence needed under Section 6.2. Records must distinguish qualifying credits available for use from credits already consumed, transferred or allocated elsewhere. No valuation of hardware, hosting contracts, reserved capacity or affiliated services is required.

### 9.3 Timing and retention

Qualifying credits must be available before they are used to meet operational charges. Keep the supporting records current as funding is received, allocated, transferred or consumed. Retain evidence for at least three years after the last expenditure or transfer it supports, and provide the relevant records on a reasonable verification request from an applicable Copyright Holder, subject to Section 9.5. Publicly accessible protocol records may be supplied by reference; no separate monthly valuation report is required.

### 9.4 Pooled funding

Qualifying credits may be pooled across deployments if the records required by Section 6.2 establish their origin, available quantity and allocation without double counting. The aggregate quantity attributed to expenditure, transfers and remaining balances must not exceed the verified qualifying credits received. Moving credits between accounts or deployments does not require another ICP conversion.

### 9.5 Privacy and confidentiality

Evidence may use stable pseudonymous identifiers and omit information not reasonably necessary to verify compliance.

Disclosure of private keys, credentials, customer data, application contents and unrelated commercially sensitive information is not required.

Confidentiality measures must not make the relevant economic compliance claims impossible to verify.

## 10. Anti-Circumvention

### 10.1 Substance over form

A Licensee must not knowingly evade the restrictions of this Licence through:

a. Corporate restructuring or affiliated entities.

b. Contractors, intermediaries or proxy operators.

c. Wrappers, relays or nominally separate services.

d. Repackaging or renaming Covered Software.

e. Translating copyright-protected implementation code into another programming language.

f. Compiling Covered Software into different executable formats.

g. Dividing protected implementation code across multiple Wasm modules, canisters, services or processes.

h. Artificial infrastructure allocation or accounting arrangements.

The technical and commercial substance of an arrangement determines whether the conditions apply.

### 10.2 Responsibility

A person knowingly directing or controlling prohibited Production Operation cannot avoid responsibility merely by interposing another entity.

An independent distributor or ordinary service provider is not responsible solely because an unrelated third party subsequently performs an unauthorised act without the distributor's direction, control or knowing participation.

### 10.3 Limits

This Section does not prohibit independently implemented software merely because it provides similar functionality.

It does not create ownership over abstract algorithms, ideas, protocols, interface specifications or technical concepts that are not protected by applicable intellectual property law.

## 11. Reserved Organisation Rights and Network Migration

### 11.1 Express Organisation grant

Each Copyright Holder who expressly makes copyright-protected material available under this Licence grants Toko Studios Ltd, to the extent of rights the holder lawfully controls, a perpetual, worldwide, non-exclusive, royalty-free, irrevocable, transferable and sublicensable licence to:

a. Use and reproduce that material.

b. Modify, adapt and create derivative works.

c. Distribute, sublicense and commercially exploit the material.

d. Operate the material on public, private, permissioned or alternative execution networks.

e. Authorise use on blockchains other than the Canonical Internet Computer.

f. Make the material available under separate commercial or other licensing arrangements.

This grant applies to the rights expressly controlled by the granting holder and does not override independently licensed third-party material.

### 11.2 Independent migration authority

The Organisation may exercise its rights under Section 11.1 at any time.

Such exercise is not conditional on the Canonical Internet Computer becoming unavailable, being discontinued, losing economic viability or suffering a technical failure.

### 11.3 Strategic alternative-network licensing

The Organisation may enter into separately negotiated arrangements authorising deployment of Covered Software on additional networks.

Such arrangements may include financial consideration, token ownership, equity participation, revenue sharing, protocol economic commitments or other negotiated terms.

No particular equity percentage, token allocation or financial arrangement independently creates authorisation.

### 11.4 Written authorisation

Any third-party permission to perform Production Operation on an alternative network must be granted in a separate written instrument, signed by the Organisation acting with sufficient authority from the applicable rights holders.

That instrument must identify the authorised party, applicable software, permitted network and scope of the permission.

An informal statement, technical compatibility, payment or investment does not constitute authorisation.

### 11.5 No automatic third-party benefit

The Organisation's reserved rights do not automatically extend to:

a. Independent operators of an alternative network.

b. Companies in which the Organisation holds shares or tokens.

c. Investors or shareholders of the Organisation.

d. Affiliates, customers or commercial partners.

e. Purchasers or recipients of software distributed by the Organisation.

Such parties require their own applicable permissions unless acting strictly as authorised agents of the Organisation within the scope of its rights.

### 11.6 Preservation of Organisation rights

The rights expressly granted under Section 11.1 survive termination of other permissions under this Licence to the maximum extent permitted by applicable law.

The Organisation's reserved permissions do not diminish the separate rights of other parties under valid prior licences.

### 11.7 Separate licensing and priority of reserved rights

The grant in Section 11.1 is a separate basis of permission for the Organisation. Its exercise is not conditional on compliance with the public-licence network, funding, source-disclosure or recordkeeping requirements in Sections 5 through 9.

In particular, the Organisation may keep its Covered Modifications private, operate them without publishing Corresponding Source, and distribute or sublicense covered material under proprietary, commercial or other terms without the source-publication, source-access notice or same-Licence requirements in Section 8. Section 8.6 does not prohibit the Organisation from exercising these rights.

The Organisation may expressly grant corresponding exceptions to identified third parties through a separate written licence signed by the Organisation acting with sufficient authority from the applicable rights holders. That instrument must identify the authorised party, covered material, scope of permission and public-licence conditions that it replaces or disapplies. Alternative-network permissions must also satisfy Section 11.4.

A recipient relying only on this public Licence remains subject to its applicable conditions, including Section 8. Neither receipt of Covered Software from the Organisation nor investment, affiliation or a commercial relationship creates an exception. A separately licensed recipient obtains only the exceptions expressly granted by its written instrument; no exception extends automatically to other material, uses or recipients.

Sections 10, 12.6 and 14 must not be interpreted to reimpose the conditions expressly displaced by this Section or a valid separate written licence. Exercising such an exception is not, by itself, circumvention or noncompliance with this Licence. This does not excuse conduct outside the scope of the separate permission or change the enforcement terms of a separate agreement.

These reserved rights and exceptions extend only to intellectual property the relevant grantor is authorised to license. They do not remove applicable copyright or third-party notices, override independently licensed third-party material, expand the patent grants in Section 13, or diminish rights already granted to others under this or an earlier licence.

## 12. Distribution, Ownership and Contributions

### 12.1 Copyright ownership

Copyright remains with the applicable Copyright Holders.

This Licence transfers no ownership merely through publication, receipt, use or distribution.

Employment, company membership, repository access or contribution acceptance does not itself establish that the Organisation owns or may relicense the relevant material. Section 11.1 applies only where the relevant holder has authority and expressly makes that material available under this Licence; it does not acquire rights in unpublished external modifications or independently licensed dependencies. The Organisation must establish sufficient rights through applicable ownership rules, assignments or express grants before offering separate permissions. Copyright authority does not establish patent authority; the trigger and scope of Section 13.3 must be satisfied separately.
### 12.2 Notices

Redistributed copies of Covered Software must preserve applicable copyright notices, licence notices and required third-party attributions.

### 12.3 Third-party material

Nothing in this Licence grants rights to third-party intellectual property beyond those lawfully controlled by the respective Copyright Holders.

Independent third-party dependencies remain subject to their own licence terms.

### 12.4 Existing licences

Nothing in this Licence revokes, cancels or retroactively restricts permissions validly granted under earlier software licences.

Previously acquired MIT, Apache or other valid permissions remain governed by their applicable terms.

New copyrightable material released exclusively under this Licence does not automatically become subject to an earlier permissive licence merely because it is distributed alongside previously licensed material.

### 12.5 Official development

This Licence creates no entitlement to submit, merge, maintain or publish modifications through an official Organisation repository.

The Organisation may restrict official development and contribution acceptance to authorised personnel.

A third party's independent right to create and distribute permitted Covered Modifications does not create a right to have those modifications incorporated into official releases.

### 12.6 No unrestricted sublicensing

Except where expressly authorised, distributors cannot remove this Licence's restrictions or grant additional production-network permissions on behalf of the applicable Copyright Holders.

Recipients obtain their relevant public-licence permissions directly from those Copyright Holders.

## 13. Patent Rights and Defensive Protection

### 13.1 Limited patent grant

Each Copyright Holder granting rights under this Licence also grants, to the extent it controls applicable patent claims, a worldwide, non-exclusive, royalty-free patent licence for use of its Covered Software contribution as expressly authorised by this Licence.

This grant extends only to claims necessarily infringed by the relevant contribution itself or its authorised combination with the Covered Software.

No independently implemented technology or unrelated product is licensed by this Section.

### 13.2 Defensive patent termination

If You initiate, direct or maintain patent proceedings alleging that Covered Software, or another person's use of Covered Software as authorised by this Licence, infringes a patent controlled by You, the patent permissions granted to You under Section 13.1 terminate upon assertion of that claim.

To the extent permitted by applicable law, the relevant Copyright Holders may also terminate Your permissions to the affected Covered Software where the proceedings constitute a material breach of an applicable defensive condition.

Defensive counterclaims responding to proceedings first brought against You, and challenges solely to patent validity, do not independently trigger this provision.

### 13.3 Organisation patent rights

Each patent grantor who expressly distributes a contribution under this Licence also grants the Organisation a perpetual, worldwide, non-exclusive, royalty-free, irrevocable and sublicensable licence to the patent claims described in Section 13.1, for use with that contribution.

This permission is not limited to the Canonical Internet Computer.

### 13.4 Reservation

No patent licence is granted for claims the relevant grantor does not control, for unrelated technologies or for independently developed implementations beyond the express scope of the grant.

## 14. Noncompliance, Suspension and Termination

### 14.1 Scope of permission

The restrictions on Production Operation, network eligibility, ICP funding and source reciprocity are express conditions of the permissions granted.

Use outside those permissions is not authorised by this Licence.

### 14.2 Unauthorised network operation

Unauthorised Production Operation on an alternative execution network is outside the scope of the public licence from its commencement.

Subsequent payment, burn activity, migration or cessation does not retrospectively authorise the earlier activity.

### 14.3 Funding noncompliance

Permission for an affected Production Operation is suspended when it uses resource credits that do not meet Section 6. Operation must not resume until qualifying funding is available and the other applicable conditions are satisfied.

Later conversion of ICP does not retrospectively qualify earlier nonqualifying expenditure. Restoring qualifying funding restores operational permission prospectively, provided the applicable permissions have not separately terminated. A correction demonstrating that sufficient qualifying credits were already available and properly attributable is a documentary correction, not retrospective funding, and may qualify under Section 14.4.

### 14.4 Administrative correction

An inadvertent documentary omission or source-publication defect may be remedied within thirty (30) days after discovery or written notice, whichever occurs first, provided the affected distribution or operation was otherwise authorised, the breach was not deliberate and the Licensee acts promptly and in good faith. "Otherwise authorised" means that all applicable requirements apart from the eligible defect itself were satisfied; the defect does not circularly disqualify its own correction.

This correction period does not authorise alternative-network operation or excuse the use of nonqualifying resource credits. The restriction on further executable distribution during a source outage in Section 8.8 remains applicable.

Permission is not suspended or terminated solely for an eligible defect during that correction period, subject to Section 8.8's express restriction on further distribution. If the Licensee fully corrects the defect within the period, the Copyright Holders granting permissions under this Licence will not suspend or terminate those permissions or pursue claims or remedies based solely on that defect, including for the period before correction. This protection includes an eligible inadvertent failure to publish required source on time.

If the defect remains uncorrected at the deadline, permission for the affected distribution or operation is suspended until correction, unless it has separately terminated under Section 14.5. The protection against claims based solely on the defect is conditional on timely complete correction and does not apply after a failure to meet that deadline. These provisions do not protect deliberate withholding, concealment or unrelated breaches, waive independently arising third-party rights, or reinstate permissions already terminated for deliberate misconduct.

### 14.5 Deliberate violations

Deliberate evasion, material falsification of compliance evidence, intentional withholding of required Covered Modification source or repeated material noncompliance may result in termination of the responsible Licensee's applicable permissions.

Reinstatement following termination for deliberate material misconduct requires express written authorisation from the relevant Copyright Holders.

### 14.6 Independent recipients

Termination of one Licensee's permissions does not automatically terminate the independent permissions of other recipients who remain compliant.

### 14.7 Remedies

Rights holders may pursue remedies available under applicable law.

Nothing in this Licence creates an automatic monetary penalty or authorises remedies beyond those permitted by law.

## 15. Independence and Non-Affiliation

References to the Internet Computer, ICP, cycles, governance systems, system canisters or protocol economics identify technical and economic conditions of this Licence.

They do not imply sponsorship, endorsement, affiliation or approval by DFINITY, the Internet Computer Association, any governance organisation, network participant or infrastructure provider.

This Licence does not grant the Organisation ownership of the Internet Computer network, its governance, its token supply or independently developed protocol software.

No trademark rights are granted except by separate written permission.

## 16. Disclaimer and Limitation of Liability

THE COVERED SOFTWARE IS PROVIDED "AS IS" AND "AS AVAILABLE", WITHOUT WARRANTIES OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, TITLE, NON-INFRINGEMENT, SECURITY, AVAILABILITY OR ACCURACY.

TO THE MAXIMUM EXTENT PERMITTED BY APPLICABLE LAW, NO COPYRIGHT HOLDER OR CONTRIBUTOR SHALL BE LIABLE FOR INDIRECT, INCIDENTAL, SPECIAL, CONSEQUENTIAL, EXEMPLARY OR PUNITIVE DAMAGES ARISING FROM THE COVERED SOFTWARE OR ITS USE.

TO THE MAXIMUM EXTENT PERMITTED BY APPLICABLE LAW, NO COPYRIGHT HOLDER OR CONTRIBUTOR SHALL BE LIABLE FOR OTHER CLAIMS, LOSSES OR DAMAGES ARISING FROM THE COVERED SOFTWARE OR ITS USE, WHETHER IN CONTRACT, TORT OR OTHERWISE.

NOTHING IN THIS SECTION EXCLUDES OR LIMITS LIABILITY THAT APPLICABLE LAW DOES NOT PERMIT TO BE EXCLUDED OR LIMITED.

## 17. Interpretation, Governing Law and Severability

### 17.1 Limited grant

This Licence grants rights only to the extent expressly stated and legally authorised.

It does not restrict statutory exceptions or other rights that applicable law does not permit a copyright licence to restrict.

### 17.2 Severability

If any provision is determined to be invalid or unenforceable, the remaining provisions remain effective to the extent permitted by applicable law.

The limits on network eligibility, source reciprocity and economic funding are essential conditions of the operational grant.

Invalidity of one such provision must not be interpreted as affirmative permission for otherwise unauthorised uses, except where applicable law requires that result.

### 17.3 No waiver

Failure or delay in enforcing a provision does not constitute permanent waiver of that provision.

### 17.4 Licence versions

Each numbered version of this Licence is a distinct legal instrument.

Publication of a later version does not automatically alter permissions already granted under an earlier version.

A Licensee may rely on a later version only where the relevant Copyright Holders expressly make that later version available for the applicable material.

### 17.5 Governing law

This Licence shall be governed by the laws of **[jurisdiction to be selected following legal review]**, excluding conflict-of-laws rules to the extent permitted.

Disputes shall be subject to **[designated courts or dispute-resolution mechanism]**, subject to mandatory applicable law.

### 17.6 Entire permission

This Licence states the public permissions offered for the Covered Software.

Separate written agreements issued by parties holding sufficient intellectual property rights may grant additional permissions to their expressly identified recipients.

---

**End of Toko Reciprocal Network Licence — Version 1.0**

**Draft status: Not approved for publication.**

Copyright © the respective Copyright Holders identified in the applicable licensed materials. All rights not expressly granted are reserved.
