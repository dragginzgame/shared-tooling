#!/usr/bin/env bash
# Shared companions: scripts/distribution/refresh-consumer.sh scripts/ci/fixture-lifecycle.sh
set -euo pipefail
root="${BASH_SOURCE[0]}"
[[ "$root" == /* ]] || root="$PWD/$root"
root="$(CDPATH='' cd -P -- "${root%/*}/../.." && printf '%s/.' "$PWD")"
root="${root%/.}"
source "$root/scripts/ci/fixture-lifecycle.sh"
fixture="$(fixture_create "${TMPDIR:-/tmp}/snapshot-impact.XXXXXX")"
fixture_complete=false
trap 'fixture_finish "$?" "$fixture" "Snapshot impact fixture retained"' EXIT
# Producer-only qualification uses existing history, never creates commits, and
# leaves the original refs/index untouched. Select a recorded changelog change.
head="$(git -C "$root" rev-parse HEAD)"
change="$(git -C "$root" log -1 --format=%H -- CHANGELOG.md)"
base="$(git -C "$root" rev-parse "$change^")"
git clone -q --shared --no-checkout "$root" "$fixture/source"
git -C "$fixture/source" remote set-url origin "$(git -C "$root" remote get-url origin)"
git -C "$fixture/source" checkout -q --detach "$base"
mkdir "$fixture/consumer"
git init -q "$fixture/consumer"
bash "$root/scripts/distribution/refresh-consumer.sh" --source "$fixture/source" \
    --consumer "$fixture/consumer" --entrypoint CHANGELOG.md > "$fixture/adopt.log"
cp -Rp "$fixture/consumer" "$fixture/before"
git -C "$fixture/source" checkout -q --detach "$head"
bash "$root/scripts/distribution/refresh-consumer.sh" --impact --source "$fixture/source" \
    --consumer "$fixture/consumer" > "$fixture/impact.log"
grep -F $'AFFECTS\tCHANGELOG.md\tCHANGELOG.md' "$fixture/impact.log" >/dev/null
grep -F "$(printf 'COMMIT\t%s\t' "$change")" "$fixture/impact.log" >/dev/null
diff -r "$fixture/before" "$fixture/consumer"
git -C "$fixture/source" checkout -q --detach "$base"
bash "$root/scripts/distribution/refresh-consumer.sh" --impact --source "$fixture/source" \
    --consumer "$fixture/consumer" > "$fixture/unchanged.log"
grep -F 'no changed payload history' "$fixture/unchanged.log" >/dev/null
if grep -q '^AFFECTS' "$fixture/unchanged.log"; then exit 1; fi
diff -r "$fixture/before" "$fixture/consumer"
fixture_complete=true
echo 'Committed snapshot impact, relevant history and unchanged consumer checks passed'
