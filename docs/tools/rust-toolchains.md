# Rust toolchain preparation

## Rust 1.100 adoption choices

The [release notes](https://doc.rust-lang.org/releases.html#version-11000-2026-11-12)
and [Cargo lints](https://doc.rust-lang.org/cargo/reference/lints.html) underpin
the baseline's common Cargo/Rustdoc policy. Use existing package/feature checks;
do not create an additional fleet-wide build gate just to execute these lints.
Cargo documents dev-dependencies as outside unused-dependency lint coverage,
but the prepared 1.100.0 compiler diagnoses an unused source-bundle dev-dependency
in binary-only tests (the equivalent library passes). Use the admitted
`target.'cfg(any())'.dev-dependencies` marker form for Toko in that case, keeping
its exact inherited pin and lock selection. A selected binary alone may also
miss normal dependency users. Keep meaningful complementary checks and real
feature/target coverage; do not use this marker form to hide unused code dependencies.

### Warning enforcement without changing compilation flags

For normal or `json-render-diagnostics` Cargo/Clippy callers, prefer
`CARGO_BUILD_WARNINGS=deny` over changing `RUSTFLAGS` or appending `-D warnings`
solely to enforce warning-free output. Keep semantic compiler flags unchanged.
Qualify a real warning refusal on both fresh and warm artifacts before changing
an adapter. Toko Tooling's native scanner uses this mode; its policy fixture
demonstrates warning refusal while Cargo reports reused artifacts.

Do not apply this replacement blindly to machine-output collectors. On the
prepared Cargo 1.100.0, plain `--message-format=json` returned success with a
warning even under `build.warnings=deny`; `json-render-diagnostics` refused it.
Keep an existing compiler-level deny or a qualified structured-diagnostic refusal
for those callers. Preserve explicit Rustdoc denial and scope-specific warning
exceptions; this setting is not a substitute for every tool's policy.

### Artifact discovery and tool installation

Use Cargo's `compiler-artifact` filenames/executable and `build-script-executed`
records for intermediate artifacts and build-script outputs. Do not discover
them by globbing `deps/`, `.fingerprint/` or hashed `build/` paths. Rust 1.100
changes that internal layout; final documented target outputs and explicit
`cargo install --root` destinations remain distinct interfaces. Reject ambiguous
package/target records, preserve source identity and qualify warm/cold builds.
The new layout alone does not grant cross-workspace cache reuse or test reuse.

Cargo 1.100 installs using the packaged lockfile by default; its install-only
`--locked` flag is a no-op. The shared installer omits that flag but still admits
the exact package version, archive checksum and packaged lock before building.
Keep `--locked` on build/check/test/metadata/publication commands where it retains
its actual lock-preservation meaning. Do not remove lock custody or reuse checks.

### Dependency cooldowns

Minimum publish age is opt-in, not a fleet default. A global cooldown also affects
fresh first-party crates and must not silently prevent a selected supplier-first
release. If a consumer adopts one, explicitly qualify that resolution policy and
its narrowly scoped urgent-update override before freezing the selected locks.
Already locked versions and `cargo install` do not gain this protection. Keep
the distinction between freshness, age policy and compatibility visible; never
report a deliberately held version as the latest available release. See
[Cargo's release description](https://blog.rust-lang.org/2026/11/12/Rust-1.100.0/).

### Standard-library simplifications

Prefer `core::mem::DropGuard` for a local one-shot cleanup closure when it removes
a bespoke guard without obscuring ownership. Preserve cancellation/unwind tests;
destructors do not promise recovery after abort, process termination or an IC
trap. Named resource-owning guards with additional invariants remain useful.

The never type `!` can express infallible results directly; existing `Infallible`
is now its alias. Do not churn public APIs or empty-error matches merely to change
spelling. Use it when it removes real duplicated type/implementation machinery.

Custom allocators for `Vec`/`Box` merit bounded experiments where measured transient
allocation cost warrants one. They are heap allocation APIs, not replacements for
governed IC stable-memory handles. Prove alignment, growth, lifetime/deallocation,
allocation refusal and native/Wasm behavior before production adoption; keep
unsafe ownership centralized. Compare representative workloads and retain a
no-change outcome when the complexity does not pay for itself. Do not introduce
a generic arena framework or extend unrelated unsafe scopes for this feature.

The inherited-default-feature override and CI incremental-compilation default
arrived in 1.99, not 1.100. Do not add a redundant migration or disable local
incremental compilation merely because CI defaults differ. New `debug` profile
support also does not itself establish a faster profile; keep measured selections.

## Preparation

Use the approved Rust 1.100.0 compiler for development and minimum-version
qualification under the [compiler support policy](../../rules/cargo-dependencies.md#minimum-supported-rust-version-msrv).
Prepare it once from the repository's admitted `rust-toolchain.toml`. Rustup,
`/bin/bash` and the documented policy parsers must already be available.

```yaml
- name: Prepare the selected Rust compiler
  run: bash scripts/dev/prepare-rust-toolchain.sh --toolchain-file rust-toolchain.toml
```

Declare rustfmt, Clippy and applicable targets in that file. Consolidate duplicate
minimum/development compilation only after preserving each distinct feature,
target, consumer and native-host obligation.

The existing `.github/actions/prepare-rust-toolchains/action.yml` remains a
generic two-selection setup helper for explicitly approved compiler exceptions.
It installs the selected `development` and `minimum` compilers with the minimal
profile and caller-selected targets/components without changing rustup's default.
Its availability does not authorize an older support floor. Toolchain arguments
are passed separately, never evaluated as shell code. Missing required values,
leading options and whitespace are rejected before installation. Installation
failure stops immediately and preserves rustup's status and diagnostics.

The action provides setup only. Consumers retain validation gates, caches,
`rustc +VERSION --version --verbose` evidence, release/publication authority and
native host qualification. Optional `minimum-components` selects comma-separated
components when the minimum-toolchain lane also runs lint or formatting.

Local setup or single-toolchain CI lanes can call the same installer directly:

```bash
bash scripts/dev/prepare-rust-toolchain.sh 1.100.0 \
  --component clippy --component rustfmt --target wasm32-unknown-unknown
```

The standalone entrypoint admits the complete explicit argument list before
calling rustup. It accepts repeated component/target options, uses the minimal
profile and preserves rustup failures. Consumers retain their component policy
and implement the approved compiler selection; checks must never call this setup
entrypoint implicitly.

When policy already lives in TOML, put the prepared Mike Farah `yq` and `jq`
on PATH and select the existing file:

```bash
bash scripts/dev/prepare-rust-toolchain.sh --toolchain-file rust-toolchain.toml
bash scripts/dev/prepare-rust-toolchain.sh --workspace-manifest Cargo.toml \
  --target wasm32-unknown-unknown
```

The toolchain-file form owns the complete selection: channel, optional profile
(default minimal), components and targets. It accepts no additional options and
refuses path toolchains. The workspace form reads `workspace.package.rust-version`
and accepts the standalone form's component/target options. Parsing never installs
its prerequisites. Malformed files, missing selections and invalid arguments fail
before rustup; installation failures preserve status and diagnostics. Neither
form changes the default toolchain. These are explicit setup commands, not checks.
Optional fields default only when omitted; boolean values and line breaks in
selections are refused. Policy paths and resolved directories must contain no
CR/LF, including directory aliases.

Validation callers that need only the workspace floor can use the same read-only
projection without calling the installer:

```bash
minimum="$(bash scripts/ci/read-cargo-workspace-rust-version.sh Cargo.toml)"
```

This reader needs only prepared `yq` and `jq`, so it works before Cargo/Rust
bootstrap. `YQ` may select the prepared parser explicitly. It emits one numeric
major/minor or major/minor/patch selection only after both observations succeed;
failed parsers preserve their status without publishing a floor. It does not
validate the complete Cargo manifest or dependencies. Consumers own subsequent
compiler checks, target policy, Rustup auto-install policy and explicit overrides.
Both policy forms require exactly one JSON object from the TOML parser. Empty,
multiple or malformed observations refuse before a floor is published or Rustup
is invoked, including observations with a valid first or last document
([#270 — Reject ambiguous Rust bootstrap policy observations](https://github.com/dragginzgame/toko-tooling/issues/270)).
The setup entrypoint delegates its workspace projection to this reader; snapshot
selection automatically carries that companion.

Adopt from a reviewed, published Toko Tooling revision using the
[snapshot workflow](../adoption/consuming-snapshots.md), then replace the local action and
both ordinary/recovery callers together. The offline fixture executes the actual
YAML body against a substitute rustup, checking argument parity, failure
propagation and input admission. It does not qualify real downloads or macOS;
adopters must retain their native Linux/macOS checks.
