#!/usr/bin/env bash
# Shared companions: scripts/ci/fixture-lifecycle.sh scripts/ci/test-file-digests.sh scripts/ci/prepare-script-fixture.sh scripts/ci/test-cargo-graph.sh scripts/ci/test-release-changelog.sh scripts/ci/prepare-cargo-failure-fixture.sh
set -euo pipefail
ROOT="${BASH_SOURCE[0]}"
[[ "$ROOT" == /* ]] || ROOT="$PWD/$ROOT"
ROOT="$(cd -P "${ROOT%/*}/../.." && printf '%s/.' "$PWD")"
ROOT="${ROOT%/.}"
fixture="$(mktemp -d "${TMPDIR:-/tmp}/script-paths-test.XXXXXX")"
fixture="$(CDPATH="" cd -P -- "$fixture" && printf '%s/.' "$PWD")"
fixture="${fixture%/.}"
# shellcheck source=scripts/ci/fixture-lifecycle.sh
source "$ROOT/scripts/ci/fixture-lifecycle.sh"
fixture_complete=false
trap 'fixture_finish "$?" "$fixture" "Script path fixture retained"' EXIT
checkout="$fixture/checkout"$'\n'
mkdir -p "$checkout/scripts/ci" "$checkout/scripts/dev" "$fixture/decoy/scripts/ci"
for script in check-dependency-pins verify-shared-tooling-snapshot install-ci-tool; do
    cp "$ROOT/scripts/ci/$script.sh" "$checkout/scripts/ci/"
done
for script in install-host-tools install-ic-tools; do cp "$ROOT/scripts/dev/$script.sh" "$checkout/scripts/dev/"; done
# Initial help admission must not resolve a relative script against CDPATH or
# trim a newline from its physical checkout. No setup or Git effects are invoked.
for path in "$checkout"/scripts/ci/*.sh "$checkout"/scripts/dev/*.sh; do
    relative="${path#"$checkout/"}"
    arguments=(--help)
    [[ "${path##*/}" != install-ci-tool.sh ]] || arguments=(shellcheck --help)
    (cd "$checkout"; CDPATH="$fixture/decoy:$checkout" "$BASH" "$relative" "${arguments[@]}") > "$fixture/help.log" 2>&1
    (cd "$fixture"; CDPATH="$checkout" "$BASH" "$path" "${arguments[@]}") >> "$fixture/help.log" 2>&1
done
cp "$ROOT/scripts/ci/test-evidence-archive.sh" "$ROOT/scripts/ci/archive-evidence.sh" "$ROOT/scripts/ci/fixture-lifecycle.sh" "$checkout/scripts/ci/"
(cd "$checkout"; CDPATH="$fixture/decoy:$checkout" bash scripts/ci/test-evidence-archive.sh) > "$fixture/archive.log" 2>&1
# Installer admission rejects both the supplied path and its physical target,
# before sourcing consumer configuration, probing tools or preparing a store.
mkdir "$fixture/valid" "$fixture/physical"$'\r'
ln -s "$fixture/valid" "$fixture/alias"$'\n'
ln -s "$fixture/valid" "$fixture/alias"$'\r'
ln -s "$checkout" "$fixture/redirect"
mkdir -p "$fixture/ancestor"$'\n'/child
printf 'printf reached > %q\nexit 97\n' "$fixture/config-read" > "$fixture/versions.env"
for consumer in "$checkout" "$fixture/physical"$'\r' "$fixture/alias"$'\n' \
    "$fixture/alias"$'\r' "$fixture/redirect" "$fixture/ancestor"$'\n'/child; do
    for kind in host ic rust; do
        for mode in install check preflight; do
            [[ "$kind:$mode" != host:preflight ]] || continue
            args=(--consumer "$consumer")
            if [[ "$kind" == ic ]]; then args+=(--pins "$ROOT/ci/ic-tools.tsv" --tool wasm-opt)
            else args+=(--versions "$fixture/versions.env"); fi
            [[ "$mode" == install ]] || args+=("--$mode")
            if "$BASH" "$ROOT/scripts/dev/install-$kind-tools.sh" "${args[@]}" > "$fixture/path-refusal.log" 2>&1; then
                echo 'installer accepted a CR/LF consumer path' >&2; exit 1
            fi
            [[ ! -e "$fixture/config-read" && ! -e "$consumer/.tools" ]] || {
                echo 'invalid consumer path reached configuration or setup' >&2; exit 1;
            }
        done
    done
done
# The digest fixture changes cwd after allocation. Its tool selections and
# cleanup must remain anchored for both relative and aliased scratch roots.
mkdir -p "$fixture/digest-caller/scratch" "$fixture/decoy/scratch"
ln -s "$fixture/digest-caller/scratch" "$fixture/digest-caller/alias"
for selected_tmp in scratch alias/; do
    (cd "$fixture/digest-caller" && CDPATH="$fixture/decoy" TMPDIR="$selected_tmp" \
        "$BASH" "$ROOT/scripts/ci/test-file-digests.sh") > "$fixture/digest-path.log" 2>&1
    grep -F 'Portable digest vectors, filenames, backend failures and verifier round trips passed' \
        "$fixture/digest-path.log" >/dev/null
    [[ -z "$(ls -A "$fixture/digest-caller/scratch")" && -z "$(ls -A "$fixture/decoy/scratch")" ]] || exit 1
done
# Exercise the affected fixture entrypoints without replaying their test bodies.
# A private companion reports that bootstrap selected the actual fixture root.
entry_checkout="$fixture/fixture checkout"
mkdir "$entry_checkout"
bash "$ROOT/scripts/ci/prepare-script-fixture.sh" "$ROOT" "$entry_checkout" \
    scripts/ci/test-cargo-graph.sh scripts/ci/test-release-changelog.sh
printf 'printf "bootstrap admitted\\n"\nexit 41\n' > "$entry_checkout/scripts/ci/fixture-lifecycle.sh"
for script in test-cargo-graph test-release-changelog; do
    for entry in relative absolute; do
        status=0
        (
            export CDPATH="$fixture/decoy:$entry_checkout"
            if [[ "$entry" == relative ]]; then
                cd "$entry_checkout"
                "$BASH" "scripts/ci/$script.sh"
            else
                cd "$fixture"
                "$BASH" "$entry_checkout/scripts/ci/$script.sh"
            fi
        ) > "$fixture/entry.log" 2> "$fixture/entry.err" || status=$?
        [[ "$status" == 41 && ! -s "$fixture/entry.err" ]] || exit 1
        grep -Fx 'bootstrap admitted' "$fixture/entry.log" > /dev/null
    done
done
# Preparation anchors the selected destination before any later cwd changes.
# The emitted executables are substitutes; no real compiler/build is dispatched.
caller="$fixture/preparation caller"
mkdir -p "$caller/physical" "$fixture/preparation-decoy/relative"
ln -s "$caller/physical" "$caller/alias"
preparer="$ROOT/scripts/ci/prepare-cargo-failure-fixture.sh"
for destination in relative 'with spaces' -leading alias/nested; do
    (cd "$caller" && CDPATH="$fixture/preparation-decoy" "$BASH" "$preparer" "$destination")
    prepared="$caller/$destination"
    [[ "$destination" != alias/nested ]] || prepared="$caller/physical/nested"
    [[ -x "$prepared/bin/rustc" && -x "$prepared/bin/cargo" ]]
    [[ "$(cd / && "$prepared/bin/rustc" --print sysroot)" == "$prepared" ]]
    status=0
    (cd / && HOME="$prepared/home" "$prepared/bin/cargo" install --target-dir "$prepared/build") \
        > "$fixture/prepared-install.log" 2>&1 || status=$?
    [[ "$status" == 23 && -f "$prepared/build/failed-build.txt" ]]
    status=0
    "$BASH" "$preparer" "$prepared" > "$fixture/prepared-retry.log" 2>&1 || status=$?
    [[ "$status" == 2 && -f "$prepared/build/failed-build.txt" ]]
done
[[ -z "$(ls -A "$fixture/preparation-decoy/relative")" ]]
# Refuse invalid supplied paths before mkdir, including the empty path that
# would otherwise turn the requested bin child into /bin. Guard that effect
# independently so a regressed helper cannot write outside this fixture.
mkdir "$fixture/preparation-guard"
# shellcheck disable=SC2016 # The guarded child reads its own effect destination.
printf 'printf "mkdir dispatched\\n" >> "$PREPARATION_EFFECTS"\nexit 93\n' \
    > "$fixture/preparation-guard/mkdir"
chmod +x "$fixture/preparation-guard/mkdir"
for invalid in '' "$caller/line"$'\n'"break" "$caller/line"$'\r'"break"; do
    status=0
    PATH="$fixture/preparation-guard:$PATH" PREPARATION_EFFECTS="$fixture/preparation-effects" \
        "$BASH" "$preparer" "$invalid" > "$fixture/preparation-invalid.log" 2>&1 || status=$?
    [[ "$status" == 2 && ! -e "$fixture/preparation-effects" ]]
done
mkdir "$caller/physical"$'\n'"parent"
ln -s "$caller/physical"$'\n'"parent" "$caller/bad-alias"
status=0
"$BASH" "$preparer" "$caller/bad-alias/retained" > "$fixture/preparation-physical.log" 2>&1 || status=$?
[[ "$status" == 2 && -d "$caller/bad-alias/retained/bin" &&
   ! -e "$caller/bad-alias/retained/bin/rustc" && ! -e "$caller/bad-alias/retained/bin/cargo" ]]
echo 'Relative/absolute entry points, inherited CDPATH and newline checkout bootstrap passed'
fixture_complete=true
