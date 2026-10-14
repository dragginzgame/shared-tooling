# Item-level rustdoc debt

`scripts/ci/check-public-docs.py` compares Cargo/rustdoc JSONL missing-doc warnings
with an explicitly selected JSON baseline of item identities. Requires Python 3.9
or newer. It runs no Cargo command, installer, network request or source edit.
Select the helper as a snapshot entrypoint; this guide is its declared companion.

Run from the source checkout so relative diagnostic paths name the intended
files. The caller owns source/diagnostic custody, package/features, compiler
selection, warning policy and admission of Cargo's exit status. A warning set is
not proof that compilation completed successfully. Preserve failed compiler logs
before invoking the comparison. For an already admitted diagnostic file:

```bash
python3 scripts/ci/check-public-docs.py target/rustdoc.jsonl ci/docs-baseline.json
```

Identities include source path, owner scopes, item kind and declared name.
Line movement does not change an identity. Multiplicity is retained: documenting
an unrelated field cannot offset new debt, and resolved baseline entries must
be removed explicitly. Added or resolved items return status 1; malformed JSON,
missing source/baseline and unsupported macro identities refuse with nonzero
status. Success does not rewrite the caller's baseline or sources.

The small scanner skips literals, raw strings and nested comments while finding
struct/enum/variant/impl owners. It is not a Rust parser, resolver or API inventory.
Expanded diagnostics need explicit identities and remain refused. Compiler
warning shape and source custody remain consumer qualification obligations.

Baseline creation/replacement is a separately selected operation:

```bash
python3 scripts/ci/check-public-docs.py target/rustdoc.jsonl ci/docs-baseline.json \
  --write-baseline
```

That option writes sorted identities only after complete input processing. It
must not be used automatically to make a failing gate pass. Query retains its
Cargo wrapper, current debt file and section-style type-doc checker; those have
separate contracts. Shared's focused identity/CLI fixtures use synthetic admitted
compiler records and temporary sources, without invoking compilation. Consumers
must qualify their own real compiler output before retiring a local checker.
