#!/usr/bin/env bash
# Shared companions: scripts/ci/check-cargo-graph.pl scripts/ci/fixture-lifecycle.sh
set -euo pipefail
root="${BASH_SOURCE[0]}"
[[ "$root" == /* ]] || root="$PWD/$root"
root="$(CDPATH='' cd -P "${root%/*}/../.." && printf '%s/.' "$PWD")"
root="${root%/.}"
# shellcheck source=scripts/ci/fixture-lifecycle.sh
source "$root/scripts/ci/fixture-lifecycle.sh"
fixture="$(fixture_create "${TMPDIR:-/tmp}/cargo-graph.XXXXXX")"
fixture_complete=false
trap 'fixture_finish "$?" "$fixture" "Cargo graph fixture retained"' EXIT
original_path="$PATH"
mkdir -p "$fixture/bin" "$fixture/consumer"
printf '[workspace]\n' > "$fixture/consumer/Cargo.toml"
export GRAPH_CALLS="$fixture/calls" GRAPH_INPUT="$fixture/graph" GRAPH_MODE=pass
cat > "$fixture/bin/cargo" <<'CARGO'
#!/usr/bin/env bash
set -euo pipefail
[[ "$*" == 'tree --locked --offline --color never --target wasm32-unknown-unknown --edges normal,build --prefix none --format {p} --package consumer'* || "$*" == 'tree --locked --offline --color never --target wasm32-unknown-unknown --edges normal,build,features --prefix none --format {p} --package consumer'* ]]
[[ "$CARGO_NET_OFFLINE" == true && "$RUSTUP_AUTO_INSTALL" == 0 ]]
printf '%s\n' "$*" >> "$GRAPH_CALLS"
cat "$GRAPH_INPUT"
case "$GRAPH_MODE" in failed) exit 29 ;; signal) kill -TERM "$$" ;; esac
CARGO
chmod +x "$fixture/bin/cargo"
export PATH="$fixture/bin:$PATH"
checker=(perl "$root/scripts/ci/check-cargo-graph.pl" --consumer "$fixture/consumer" --package consumer --target wasm32-unknown-unknown)
printf 'consumer v0.1.0\nsubstrate v2.0.0 (proc-macro)\nsubstrate v2.0.0 (proc-macro) (*)\n' > "$GRAPH_INPUT"
"${checker[@]}" --require substrate=1 --forbid absent --forbid absent
# Source labels and versions remain separate; repeated markers are not identities.
for other in 'substrate v2.0.1' 'substrate v2.0.0 (file:///different source#12345678)'; do
 printf '%s\n' "$other" >> "$GRAPH_INPUT"
 if "${checker[@]}" --require substrate=1 > "$fixture/duplicates.log" 2>&1; then exit 1; fi
 grep -F 'observed 2' "$fixture/duplicates.log" > /dev/null
 printf 'consumer v0.1.0\nsubstrate v2.0.0 (proc-macro)\n' > "$GRAPH_INPUT"
done
"${checker[@]}" --max-count substrate=1 --max-count absent=1
if "${checker[@]}" --max-count substrate=0 > "$fixture/cap.log" 2>&1; then exit 1; fi
printf 'substrate v2.0.0 (file:///other#123)\n' >> "$GRAPH_INPUT"
if "${checker[@]}" --max-count substrate=1 > "$fixture/cap.log" 2>&1; then exit 1; fi
grep -F 'observed 2' "$fixture/cap.log" > /dev/null
printf 'consumer v0.1.0\nsubstrate v2.0.0 (proc-macro)\n' > "$GRAPH_INPUT"
if "${checker[@]}" --forbid-pattern '^substrate($|-)' > "$fixture/family.log" 2>&1; then exit 1; fi
"${checker[@]}" --forbid-pattern '^substrate-extra$' --depth 1
if "${checker[@]}" --forbid substrate > "$fixture/denied.log" 2>&1; then exit 1; fi
grep -F 'forbidden substrate:' "$fixture/denied.log" > /dev/null
printf 'consumer v0.1.0\nsubstrate-extra v2.0.0\n' > "$GRAPH_INPUT"
"${checker[@]}" --forbid substrate --require missing=0 --features 'consumer/a,consumer/b' --no-default-features
printf 'consumer v0.1.0\nsubstrate feature "danger"\nsubstrate v2.0.0\n' > "$GRAPH_INPUT"
if "${checker[@]}" --forbid-feature substrate/danger > "$fixture/feature.log" 2>&1; then exit 1; fi
grep -F 'forbidden dependency feature edge: substrate/danger' "$fixture/feature.log" > /dev/null
"${checker[@]}" --forbid-feature substrate/other
# Overlapping selected roots carry a Cargo-owned command-line feature marker.
# Feature labels, including repeated ones, must not become package identities.
printf 'consumer v0.1.0\nsubstrate feature "default" (command-line)\nsubstrate v2.0.0\nsubstrate feature "default" (command-line) (*)\nsubstrate v2.0.0 (*)\n' > "$GRAPH_INPUT"
"${checker[@]}" --package substrate --require consumer=1 --require substrate=1 --forbid-feature substrate/other
if "${checker[@]}" --package substrate --forbid-feature substrate/default > "$fixture/annotated-feature.log" 2>&1; then exit 1; fi
grep -F 'forbidden dependency feature edge: substrate/default' "$fixture/annotated-feature.log" > /dev/null
for invalid in 'substrate feature "default" (unknown)' \
 'substrate feature "default" (command-line) trailing' \
 'substrate feature "default" (command-line) (command-line)' \
 'substrate feature "default (command-line)'; do
 printf 'consumer v0.1.0\n%s\n' "$invalid" > "$GRAPH_INPUT"
 if "${checker[@]}" --forbid-feature substrate/other > "$fixture/invalid-feature.log" 2>&1; then exit 1; fi
done
printf 'consumer v0.1.0\n' > "$GRAPH_INPUT"
# Complete successful observations only, including child signals and root identity.
for mode in failed signal; do
 for edges in package feature; do
  printf 'consumer v0.1.0\n' > "$GRAPH_INPUT"
  policy=(--forbid absent)
  if [[ "$edges" == feature ]]; then
   policy+=(--forbid-feature substrate/other)
   printf 'substrate feature "default" (command-line)\n' >> "$GRAPH_INPUT"
  fi
  if GRAPH_MODE="$mode" "${checker[@]}" "${policy[@]}" > "$fixture/$mode-$edges.log" 2>&1; then exit 1; else status=$?; fi
  if [[ "$mode" == failed ]]; then [[ "$status" == 29 ]] || exit 1; else [[ "$status" == 143 ]] || exit 1; fi
  if grep -q 'graph passed' "$fixture/$mode-$edges.log"; then exit 1; fi
 done
done
for invalid in '' 'not a Cargo graph' 'other v0.1.0' 'consumer v0.1.0 invalid'; do
 printf '%s\n' "$invalid" > "$GRAPH_INPUT"
 if "${checker[@]}" --forbid absent > "$fixture/invalid.log" 2>&1; then exit 1; fi
done
: > "$GRAPH_CALLS"
for invalid in substrate=-1 substrate=01 substrate=1.2 substrate; do
 if "${checker[@]}" --require "$invalid" > "$fixture/policy.log" 2>&1; then exit 1; fi
done
if "${checker[@]}" --forbid substrate --require substrate=0 > "$fixture/policy.log" 2>&1; then exit 1; fi
if "${checker[@]}" --require substrate=1 --require substrate=1 > "$fixture/policy.log" 2>&1; then exit 1; fi
if "${checker[@]}" --forbid absent --features a --all-features > "$fixture/policy.log" 2>&1; then exit 1; fi
if "${checker[@]}" --forbid-pattern '[' > "$fixture/pattern.log" 2>&1; then exit 1; fi
if "${checker[@]}" --max-count substrate=1 --require substrate=1 > "$fixture/policy.log" 2>&1; then exit 1; fi
if "${checker[@]}" --max-count substrate=1 --forbid substrate > "$fixture/policy.log" 2>&1; then exit 1; fi
if "${checker[@]}" --max-count substrate=1 --max-count substrate=1 > "$fixture/policy.log" 2>&1; then exit 1; fi
if "${checker[@]}" --forbid absent --depth -1 > "$fixture/depth.log" 2>&1; then exit 1; fi
[[ ! -s "$GRAPH_CALLS" ]]
for suffix in $'\n' $'\r'; do
 bad="$fixture/directory$suffix"
 mkdir "$bad"
 ln -s "$bad" "$fixture/alias"
 for selected in "$bad" "$fixture/alias"; do
  if perl "$root/scripts/ci/check-cargo-graph.pl" --consumer "$selected" --package consumer --target all --forbid absent > "$fixture/path.log" 2>&1; then exit 1; fi
 done
 rm "$fixture/alias"
done
[[ ! -s "$GRAPH_CALLS" ]]
# Real offline Cargo: transitive aliases, optional features, build/dev edges and
# target placement. No registry dependencies, compilation or network is involved.
export PATH="$original_path"
actual="$fixture/actual workspace"
mkdir "$actual"
printf '[workspace]\nmembers=["consumer","bridge","substrate","build-only","dev-only","wasm-only"]\nresolver="2"\n' > "$actual/Cargo.toml"
for package in consumer bridge substrate build-only dev-only wasm-only; do
 mkdir -p "$actual/$package/src"
 printf '[package]\nname="%s"\nversion="0.1.0"\nedition="2021"\n' "$package" > "$actual/$package/Cargo.toml"
 : > "$actual/$package/src/lib.rs"
done
cat >> "$actual/consumer/Cargo.toml" <<'TOML'
[features]
default=[]
runtime=["dep:renamed"]
[dependencies]
renamed={package="bridge",path="../bridge",optional=true,features=["danger"]}
[build-dependencies]
build-only={path="../build-only"}
[dev-dependencies]
dev-only={path="../dev-only"}
[target.'cfg(target_arch="wasm32")'.dependencies]
wasm-only={path="../wasm-only"}
TOML
printf '[features]\ndefault=[]\ndanger=[]\n[dependencies]\nhidden={package="substrate",path="../substrate"}\n' >> "$actual/bridge/Cargo.toml"
(cd "$actual"; cargo generate-lockfile --offline)
cp "$actual/Cargo.lock" "$fixture/lock.before"
native="$(rustc -vV | sed -n 's/^host: //p')"
checker=(perl "$root/scripts/ci/check-cargo-graph.pl" --consumer "$actual" --package consumer)
"${checker[@]}" --target "$native" --forbid substrate --forbid wasm-only --forbid dev-only --require build-only=1
"${checker[@]}" --target wasm32-unknown-unknown --all-features --require substrate=1 --require wasm-only=1 --require build-only=1 --forbid dev-only
if "${checker[@]}" --target "$native" --features runtime --forbid substrate > "$fixture/actual-denied.log" 2>&1; then exit 1; fi
grep -F 'forbidden substrate:' "$fixture/actual-denied.log" > /dev/null
"${checker[@]}" --target "$native" --features runtime --depth 1 --forbid substrate --require bridge=1
"${checker[@]}" --target "$native" --max-count substrate=1
if "${checker[@]}" --target "$native" --features runtime --forbid-pattern '^substrate($|-)' > "$fixture/actual-family.log" 2>&1; then exit 1; fi
"${checker[@]}" --target "$native" --forbid-feature bridge/danger
if "${checker[@]}" --target "$native" --features runtime --forbid-feature bridge/danger > "$fixture/actual-feature.log" 2>&1; then exit 1; fi
grep -F 'forbidden dependency feature edge: bridge/danger' "$fixture/actual-feature.log" > /dev/null
"${checker[@]}" --target "$native" --no-default-features --require bridge=0 --forbid-feature bridge/danger
overlapping=("${checker[@]}" --package bridge --target "$native" --require consumer=1 --require bridge=1 --require substrate=1)
"${overlapping[@]}" --features consumer/runtime --forbid-feature bridge/other
"${overlapping[@]}" --all-features --forbid-feature bridge/other
"${overlapping[@]}" --no-default-features --features consumer/runtime --forbid-feature bridge/other
if "${overlapping[@]}" --features consumer/runtime --forbid-feature bridge/default > "$fixture/actual-annotated-feature.log" 2>&1; then exit 1; fi
grep -F 'forbidden dependency feature edge: bridge/default' "$fixture/actual-annotated-feature.log" > /dev/null
cmp "$fixture/lock.before" "$actual/Cargo.lock"
fixture_complete=true
echo 'Locked graph selection, identity counts, aliases, failed observations and offline Cargo checks passed'
