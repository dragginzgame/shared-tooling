#!/usr/bin/env bash
# Shared companions: scripts/ci/run-rust-formatting.pl scripts/ci/fixture-lifecycle.sh
set -euo pipefail
ROOT="$(CDPATH='' cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=scripts/ci/fixture-lifecycle.sh
source "$ROOT/scripts/ci/fixture-lifecycle.sh"
fixture="$(fixture_create "${TMPDIR:-/tmp}/rust-formatting.XXXXXX")"
fixture_complete=false
trap 'fixture_finish "$?" "$fixture" "Rust formatting fixture retained"' EXIT
consumer="$fixture/consumer with spaces"
mkdir -p "$consumer/src" "$consumer/child workspace/src" "$fixture/logs" "$fixture/bin"
for workspace in "$consumer" "$consumer/child workspace"; do
    printf '[package]\nname = "fixture"\nversion = "0.0.0"\n' > "$workspace/Cargo.toml"
    printf 'fn example() {}\n' > "$workspace/src/lib.rs"
done
cat > "$fixture/bin/cargo" <<'CARGO'
#!/usr/bin/env bash
set -euo pipefail
case "$*" in
    metadata*)
        [[ "${FORMAT_METADATA_FAIL:-0}" == 0 ]] || exit 19
        perl -MJSON::PP -MCwd=getcwd -e '$p=getcwd(); print encode_json({packages=>[{manifest_path=>"$p/Cargo.toml", targets=>[{src_path=>"$p/src/lib.rs"}]}],target_directory=>"$p/target"})'
        exit ;;
    --version|'sort --version'|'fmt --version'|'sort-derives --version') printf 'fixture %s\n' "${FORMAT_VERSION:-1}"; exit ;;
esac
printf '%s\t%s\n' "$PWD" "$*" >> "$FORMAT_EVENTS"
echo 'private formatter detail'
if [[ "$*" == "${FORMAT_FAIL:-}" ]]; then exit 23; fi
if [[ "${FORMAT_INTERRUPT:-0}" == 1 ]]; then kill -TERM "$PPID"; exit 0; fi
if [[ "${FORMAT_REWRITE:-0}" == 1 && "$*" == 'fmt --all' ]]; then
    printf 'fn rewritten() {}\n' > src/lib.rs
fi
CARGO
chmod +x "$fixture/bin/cargo"
export PATH="$fixture/bin:$PATH" FORMAT_EVENTS="$fixture/events" RUNNER_TEMP="$fixture/logs"
driver="$ROOT/scripts/ci/run-rust-formatting.pl"
cd "$consumer"
run() { perl "$driver" "$@" > "$fixture/output" 2>&1; }
receipt="$consumer/target/shared-tooling/formatting.receipt"

# A successful complete selection can serve both check and write. A cache hit
# invokes no formatter, but still observes actual tools/config/source inputs.
: > "$FORMAT_EVENTS"
run --check --sort-derives --extra-workspace 'child workspace' --extra-manifest-order package,workspace
[[ "$(wc -l < "$FORMAT_EVENTS")" -eq 5 ]]
grep -E '^Manifest sorting \[\.\].*ok \([0-9]+\.[0-9]+s\)$' "$fixture/output"
grep -E '^Derive sorting \[\.\].*ok \([0-9]+\.[0-9]+s\)$' "$fixture/output"
grep -E '^Rust formatting \[child workspace\].*ok \([0-9]+\.[0-9]+s\)$' "$fixture/output"
grep -F -- 'sort --workspace --grouped --check --order package,workspace' "$FORMAT_EVENTS"
[[ -f "$receipt" ]]
: > "$FORMAT_EVENTS"
run --write --sort-derives --extra-workspace 'child workspace' --extra-manifest-order package,workspace
[[ ! -s "$FORMAT_EVENTS" ]]
grep -E '^Checking formatting inputs\.\.\. unchanged \([0-9]+\.[0-9]+s\)$' "$fixture/output"

# Real invalidation boundaries, including untracked source, child input, tool
# identity, configuration, workspace/policy selection and the supplying driver.
for change in source same-time child manifest config tool selection; do
    case "$change" in
        source) printf 'fn added() {}\n' > src/untracked.rs ;;
        same-time)
            cp -p src/lib.rs "$fixture/source-timestamp"
            printf 'fn changed() {}\n' > src/lib.rs
            touch -r "$fixture/source-timestamp" src/lib.rs ;;
        child) printf 'fn child() {}\n' > 'child workspace/src/lib.rs' ;;
        manifest) printf '\n# changed\n' >> Cargo.toml ;;
        config) printf 'max_width = 90\n' > rustfmt.toml ;;
        tool) printf '\n# changed executable\n' >> "$fixture/bin/cargo" ;;
        selection) : ;;
    esac
    : > "$FORMAT_EVENTS"
    arguments=(--check --sort-derives --extra-workspace 'child workspace' --extra-manifest-order 'package,workspace')
    [[ "$change" != selection ]] || arguments+=(--manifest-order 'package,workspace')
    run "${arguments[@]}"
    [[ "$(wc -l < "$FORMAT_EVENTS")" -eq 5 ]]
done

# An unsupported/incomplete inventory falls back to actual passes, never a
# cached success. Corrupt or unreadable bookkeeping is just a miss.
printf 'corrupt\n' > "$receipt"
: > "$FORMAT_EVENTS"
run --check
[[ "$(wc -l < "$FORMAT_EVENTS")" -eq 2 ]]
: > "$FORMAT_EVENTS"
FORMAT_METADATA_FAIL=1 run --check
[[ "$(wc -l < "$FORMAT_EVENTS")" -eq 2 ]]
grep -F 'running without shortcut' "$fixture/output"

# Module redirection is outside the standard package-source inventory, whether
# direct or conditional. Arbitrary rustfmt wrappers likewise have unknown inputs.
for attribute in '#[path = "../../external.rs"]' '#[cfg_attr(test, path = "../../external.rs")]'; do
    printf '%s\nmod external;\n' "$attribute" > src/redirect.rs
    : > "$FORMAT_EVENTS"
    run --check
    [[ "$(wc -l < "$FORMAT_EVENTS")" -eq 2 ]]
    grep -F 'running without shortcut' "$fixture/output" > /dev/null
done
rm src/redirect.rs
: > "$FORMAT_EVENTS"
RUSTFMT=custom-rustfmt run --check
[[ "$(wc -l < "$FORMAT_EVENTS")" -eq 2 ]]
grep -F 'running without shortcut' "$fixture/output" > /dev/null

# Failure preserves the exact status/log and prevents the later pass or receipt.
printf 'fn failure_input() {}\n' > src/lib.rs
cp "$receipt" "$fixture/previous-receipt"
: > "$FORMAT_EVENTS"
status=0
FORMAT_FAIL='sort --workspace --grouped --check' run --check || status=$?
[[ "$status" == 23 && "$(wc -l < "$FORMAT_EVENTS")" -eq 1 ]]
cmp "$receipt" "$fixture/previous-receipt"
grep -E '^Manifest sorting .*FAILED \(exit 23, [0-9]+\.[0-9]+s\)$' "$fixture/output"
grep -F 'Details:' "$fixture/output"
grep -l 'private formatter detail' "$fixture/logs"/formatting.* > /dev/null

# A changed write is not a proof about the new inputs; check them once before
# allowing reuse. The write path never runs a duplicate check-before-write pass.
FORMAT_REWRITE=1 run --write
cmp "$receipt" "$fixture/previous-receipt"
: > "$FORMAT_EVENTS"
run --check
[[ "$(wc -l < "$FORMAT_EVENTS")" -eq 2 ]]
: > "$FORMAT_EVENTS"
run --write
[[ ! -s "$FORMAT_EVENTS" ]]

# Explicit qualification and isolated hook inputs do not reuse the developer
# receipt. Source/config changes after a hit must still invalidate it.
for bypass in explicit hook; do
    : > "$FORMAT_EVENTS"
    if [[ "$bypass" == explicit ]]; then run --check --no-cache
    else SHARED_TOOLING_FORMAT_WORKTREE="$consumer" run --check; fi
    [[ "$(wc -l < "$FORMAT_EVENTS")" -eq 2 ]]
done
printf 'fn interrupted() {}\n' > src/lib.rs
cp "$receipt" "$fixture/previous-receipt"
status=0
FORMAT_INTERRUPT=1 run --write || status=$?
[[ "$status" == 143 ]]
cmp "$receipt" "$fixture/previous-receipt"
: > "$FORMAT_EVENTS"
run --check
[[ "$(wc -l < "$FORMAT_EVENTS")" -eq 2 ]]

# Reject an ambiguous roster before any write, including aliases of the root.
: > "$FORMAT_EVENTS"
if run --write --extra-workspace .; then exit 1; fi
[[ ! -s "$FORMAT_EVENTS" ]]
if run --write --extra-workspace ..; then exit 1; fi
[[ ! -s "$FORMAT_EVENTS" ]]

# Untrusted workspace labels remain visible without terminal control effects.
control_workspace=$'control-\033-\342\200\256'
mkdir "$control_workspace"
run --check --no-cache --extra-workspace "$control_workspace"
if LC_ALL=C grep -q $'\e' "$fixture/output"; then exit 1; fi
if grep -q $'\342\200\256' "$fixture/output"; then exit 1; fi
grep -F '\x{202e}' "$fixture/output" > /dev/null

fixture_complete=true
echo 'Rust formatting reuse, invalidation, per-pass timing and failure evidence passed'
