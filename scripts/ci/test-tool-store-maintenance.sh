#!/usr/bin/env bash
# Shared companions: scripts/dev/tool-store-maintenance.pl scripts/ci/fixture-lifecycle.sh
set -euo pipefail
umask 077
root="$(cd -P "${BASH_SOURCE[0]%/*}/../.." && pwd -P)"
# shellcheck source=scripts/ci/fixture-lifecycle.sh
source "$root/scripts/ci/fixture-lifecycle.sh"
mkdir -p "$root/target/tmp"
fixture="$(fixture_create "$root/target/tmp/tool-maintenance.XXXXXX")"
fixture_complete=false
trap 'fixture_finish "$?" "$fixture" "Tool maintenance fixture retained"' EXIT
mkdir -p "$fixture/store with spaces" "$fixture/a" "$fixture/b"
store="$fixture/store with spaces"
slot="$store/rust-$(printf '%064d' 1)"
mkdir -p "$slot/set.old/build" "$slot/set.new/build" "$slot/set.unknown" "$slot/set.failed/build"
printf 'old executable\n' > "$slot/set.old/tool"
printf 'new executable\n' > "$slot/set.new/tool"
printf '{"schema":1}\n' > "$slot/set.old/selection.json"
cp "$slot/set.old/selection.json" "$slot/set.new/selection.json"
cp "$slot/set.old/selection.json" "$slot/set.failed/managed.json"
printf 'compiler output\n' > "$slot/set.new/build/object"
printf 'failure evidence\n' > "$slot/set.failed/install.log"
# A killed receipt write must not turn a failed attempt into completed output.
: > "$slot/set.failed/selection.json"
run() { perl "$root/scripts/dev/tool-store-maintenance.pl" "$1" "$store" "${@:2}"; }
run register "$fixture/a" editor "$slot/set.old"
run register "$fixture/b" editor "$slot/set.old"
run register "$fixture/a" editor "$slot/set.new"
# Model the release-editor handles and common bundles used by IC Tooling.
mkdir -p "$fixture/a/.tools/rust/common-set.old/bin"
local_root="$fixture/a/.tools/rust"
old_key="selected-$(printf '%064d' 1)"
new_key="selected-$(printf '%064d' 2)"
ln -s "$slot/set.old" "$local_root/rust-set.old"
ln -s "$slot/set.new" "$local_root/rust-set.new"
ln -s rust-set.old "$local_root/$old_key"
ln -s rust-set.new "$local_root/$new_key"
ln -s "../../$old_key/bin/editor" "$local_root/common-set.old/bin/editor"
ln -s common-set.old "$local_root/common"
ln -s set.old "$slot/current"
run preview > "$fixture/with-peer.json"
jq -e '.entries[] | select(.path|endswith("set.old")) | .reason=="declared-consumer"' "$fixture/with-peer.json" >/dev/null
run apply --quiescent > "$fixture/with-peer-applied.json"
[[ -f "$slot/set.old/tool" && -d "$slot/set.unknown" && -f "$slot/set.failed/install.log" ]]
run forget "$fixture/b" --quiescent
# A failed common refresh still needs its previous complete bundle.
run apply --quiescent > "$fixture/previous-common.json"
[[ -f "$slot/set.old/tool" && -d "$local_root/common-set.old" ]]
rm "$local_root/common"
mkdir -p "$local_root/common-set.new/bin"
ln -s "../../$new_key/bin/editor" "$local_root/common-set.new/bin/editor"
ln -s common-set.new "$local_root/common"
mkdir "$local_root/common.lock"
if run apply --quiescent > "$fixture/common-busy.log" 2>&1; then exit 1; fi
[[ -f "$slot/set.old/tool" ]]
rmdir "$local_root/common.lock"
mkdir "$slot/install.lock"
printf 'pid=%s\nconsumer=%s\n' "$$" "$fixture/a" > "$slot/install.lock/owner"
run preview > "$fixture/busy.json"
jq -e 'all(.entries[]; .reason=="active-installation")' "$fixture/busy.json" >/dev/null
if run trim "$slot/set.new" 999999 > "$fixture/wrong-owner.log" 2>&1; then exit 1; fi
run trim "$slot/set.new" "$$"
[[ ! -e "$slot/set.new/build" && -f "$slot/set.new/tool" && -f "$slot/set.new/selection.json" ]]
rm "$slot/install.lock/owner"
rmdir "$slot/install.lock"
run apply --quiescent > "$fixture/retired.json"
[[ ! -e "$slot/set.old" && -f "$slot/set.new/tool" ]]
[[ ! -L "$local_root/$old_key" && ! -L "$local_root/rust-set.old" && ! -L "$slot/current" ]]
[[ ! -d "$local_root/common-set.old" && -d "$local_root/common-set.new" ]]
# Repeated maintenance converges and keeps immutable receipts.
run apply --quiescent > "$fixture/retry.json"
mkdir "$store/maintenance.lock"
if run apply --quiescent > "$fixture/busy.log" 2>&1; then exit 1; fi
rmdir "$store/maintenance.lock"
# Hardlinks shared with an unrelated file are physical bytes, but not freed bytes.
run preview > "$fixture/hard-before.json"
for name in one two; do
    mkdir "$slot/set.$name"
    cp "$slot/set.new/selection.json" "$slot/set.$name/selection.json"
    cp "$slot/set.new/managed.json" "$slot/set.$name/managed.json"
done
dd if=/dev/zero of="$fixture/unrelated" bs=8192 count=1 2>/dev/null
ln "$fixture/unrelated" "$slot/set.one/payload"
ln "$fixture/unrelated" "$slot/set.two/payload"
run preview > "$fixture/hard-protected.json"
[[ "$(jq -r .reclaimable_physical_bytes "$fixture/hard-before.json")" == "$(jq -r .reclaimable_physical_bytes "$fixture/hard-protected.json")" ]]
allocated="$(perl -e 'print((stat(shift))[12]*512)' "$fixture/unrelated")"
rm "$fixture/unrelated"
run preview > "$fixture/hard-free.json"
[[ "$(jq -r .reclaimable_physical_bytes "$fixture/hard-free.json")" == "$(( $(jq -r .reclaimable_physical_bytes "$fixture/hard-before.json") + allocated ))" ]]
run apply --quiescent > "$fixture/hard-applied.json"
[[ ! -e "$slot/set.one" && ! -e "$slot/set.two" ]]
# Recover a partially removed tree whose managed marker was already removed.
mkdir "$slot/set.partial"
printf 'partial payload\n' > "$slot/set.partial/payload"
saved="$store/receipts/$(printf %s "$slot/set.partial" | perl -MDigest::SHA=sha256_hex -0777 -ne 'print sha256_hex($_)')"
mkdir "$saved"
jq -cn --arg path "$slot/set.partial" '{schema:1,path:$path,state:"removing"}' > "$saved/reclamation.json"
run apply --quiescent > "$fixture/partial.json"
[[ ! -e "$slot/set.partial" ]]
jq -e '.state=="removed"' "$saved/reclamation.json" >/dev/null
# A vanished temporary consumer no longer pins its completed generation.
mkdir "$fixture/temporary" "$slot/set.temporary"
cp "$slot/set.new/selection.json" "$slot/set.temporary/selection.json"
run register "$fixture/temporary" editor "$slot/set.temporary"
rmdir "$fixture/temporary"
run apply --quiescent > "$fixture/temporary.json"
[[ ! -d "$slot/set.temporary" ]]
# Failed build scratch expires after seven days; explicit recovery pins extend it.
perl -e 'utime 1,1,shift or die $!' "$slot/set.failed/managed.json"
future="$(perl -e 'print time+86400')"
run pin "$slot/set.failed" "$future" 'active recovery'
run apply --quiescent > "$fixture/pinned.json"
[[ -f "$slot/set.failed/install.log" ]]
printf '{"schema":1,"until":1,"reason":"expired fixture pin"}\n' > "$slot/set.failed/recovery-pin.json"
run apply --quiescent > "$fixture/expired.json"
[[ ! -d "$slot/set.failed" ]]
saved="$store/receipts/$(printf %s "$slot/set.failed" | perl -MDigest::SHA=sha256_hex -0777 -ne 'print sha256_hex($_)')"
[[ "$(cat "$saved/install.log")" == 'failure evidence' ]]
# Removing a temporary consumer drops its requirement; unknown legacy trees
# and a redirected candidate remain protected.
run forget "$fixture/a" --quiescent
ln -s "$fixture" "$slot/set.new/foreign"
run apply --quiescent > "$fixture/redirect.json"
[[ -L "$slot/set.new/foreign" && -d "$fixture/a" ]]
rm "$slot/set.new/foreign"
run apply --quiescent > "$fixture/final.json"
[[ ! -e "$slot/set.new" && -d "$slot/set.unknown" ]]
run manage "$slot/set.unknown" --quiescent
run preview > "$fixture/migrated.json"
jq -e '.entries[] | select(.path|endswith("set.unknown")) | .reason=="recent-incomplete-attempt"' "$fixture/migrated.json" >/dev/null
mkdir "$fixture/refresh"
baseline=''
for version in 1 2 3; do
    candidate="$slot/set.release$version"
    mkdir "$candidate"
    printf 'tool bytes\n' > "$candidate/tool"
    printf '{"schema":1}\n' > "$candidate/selection.json"
    run register "$fixture/refresh" editor "$candidate"
    run apply --quiescent > "$fixture/converged-$version.json"
    run preview > "$fixture/counts-$version.json"
    jq -e '[.entries[] | select(.reason=="declared-consumer")] | length==1' "$fixture/counts-$version.json" >/dev/null
    bytes="$(jq -r .physical_bytes "$fixture/counts-$version.json")"
    [[ -z "$baseline" || "$baseline" == "$bytes" ]]
    baseline="$bytes"
done
if run apply > "$fixture/no-custody.log" 2>&1; then exit 1; fi
fixture_complete=true
echo 'Tool maintenance protects peers, active work, unknown and redirected trees; retires obsolete generations'
