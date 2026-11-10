# Software title-audit method

Use the [portfolio register](index.md) for overall status and one file in
`repositories/` for each repository. This is a legal evidence workflow, not a
source-code quality audit.

## Why the hybrid structure

A single file is useful for portfolio decisions but becomes unsafe for detailed
ownership evidence. Per-repository records bind conclusions to a commit and let
reviewers track contributors, assignments, inherited history and third-party
material independently. Signed agreements and personal data must remain in a
private legal record system; these Markdown files contain references only.

## Required evidence

For every repository:

1. Freeze the reviewed commit and record all relevant predecessor repositories.
2. Reconcile Git identities to legal persons or entities without publishing
   private identity documents.
3. Establish whether each contribution was created by an employee within scope,
   assigned by a contractor, covered by a signed CLA, or separately licensed.
4. Review historical commits, vendored code, generated output, copied snippets,
   assets, schemas and documentation—not only current dependencies.
5. Record third-party licence texts and existing public grants. Never relabel or
   delete a notice merely to obtain a uniform-looking licence.
6. Review patents, moral rights, confidentiality obligations, funding terms and
   government or university rights where applicable.
7. Link immutable private evidence references, reviewer identity, review date
   and counsel approval.

## Evidence classifications

- **Owned:** a signed assignment, applicable work-made-for-hire rule and verified
  employment scope, or other counsel-approved title evidence establishes Company
  ownership.
- **Permanently licensed:** another person owns the material but a signed,
  irrevocable, transferable and sublicensable grant protects Company use.
- **Third-party:** used under independently applicable terms; not Company-owned.
- **Unresolved:** title, authority, provenance or licence remains unverified.

Do not call a repository cleared merely because it is in the organisation,
contains a copyright notice, has few authors or was produced with an LLM.

## Private evidence

Do not commit signatures, home addresses, private employer documents, identity
records or confidential legal advice. Record a private custodian, agreement
version, immutable digest and opaque evidence identifier instead.
