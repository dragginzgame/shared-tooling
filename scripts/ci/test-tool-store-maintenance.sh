#!/usr/bin/env bash
# Shared companions: scripts/dev/tool-store-maintenance.pl scripts/dev/compiler-cache-maintenance.pl scripts/ci/fixture-lifecycle.sh scripts/ci/shared-companions.sh
set -euo pipefail
umask 077
root="$(cd -P "${BASH_SOURCE[0]%/*}/../.." && pwd -P)"
# shellcheck source=scripts/ci/fixture-lifecycle.sh
source "$root/scripts/ci/fixture-lifecycle.sh"
mkdir -p "$root/target/tmp"
fixture="$(fixture_create "$root/target/tmp/tool-maintenance.XXXXXX")"
fixture_complete=false
trap 'fixture_finish "$?" "$fixture" "Tool maintenance fixture retained"' EXIT
# The snapshot reader must discover the extracted module from either public
# helper. Compile copied entrypoints with only their declared companions.
# shellcheck source=scripts/ci/shared-companions.sh
source "$root/scripts/ci/shared-companions.sh"
for helper in tool-store-maintenance.pl compiler-cache-maintenance.pl; do
    exported="$fixture/export-$helper"
    mkdir -p "$exported/scripts/dev"
    cp "$root/scripts/dev/$helper" "$exported/scripts/dev/$helper"
    read_shared_companions "$root/scripts/dev/$helper" "scripts/dev/$helper"
    for companion in "${shared_companions[@]}"; do
        mkdir -p "$exported/${companion%/*}"
        cp "$root/$companion" "$exported/$companion"
    done
    perl -c "$exported/scripts/dev/$helper"
done
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
# A realistic nested scratch tree can contain internal hardlinks and external
# symlinks. Trim unlinks scratch only, preserving the admitted artifact/receipts.
mkdir -p "$slot/set.new/build/deps" "$slot/set.new/home"
ln "$slot/set.new/build/object" "$slot/set.new/build/deps/hardlink"
ln "$slot/set.new/build/object" "$slot/set.new/home/hardlink"
ln -s "$slot/set.new/tool" "$slot/set.new/build/deps/artifact"
run trim "$slot/set.new" "$$"
[[ ! -e "$slot/set.new/build" && -f "$slot/set.new/tool" && -f "$slot/set.new/selection.json" ]]
[[ ! -e "$slot/set.new/home" ]]
run trim "$slot/set.new" "$$"
# Deterministically mutate after inventory, before removal. Keep the refusal
# and name the changed field/path so a real report can distinguish its cause.
perl -I "$root/scripts/dev" -MOwnedTree=inventory,remove_owned - "$fixture" <<'PERL'
use strict;
use warnings;
my $root=shift;
for my $change (qw(size mode inode paths target)) {
    my $dir="$root/mutation-$change";
    mkdir $dir or die $!;
    my $file="$dir/payload";
    open my $out,'>',$file or die $!; print {$out} 'original'; close $out or die $!;
    symlink 'payload',"$dir/link" or die $!;
    my $before=inventory($dir,1);
    if ($change eq 'size') { open my $f,'>>',$file or die $!; print {$f} 'changed'; close $f or die $!; }
    elsif ($change eq 'mode') { chmod 0400,$file or die $!; }
    elsif ($change eq 'inode') { rename $file,"$root/held" or die $!; open my $f,'>',$file or die $!; print {$f} 'original'; close $f or die $!; }
    elsif ($change eq 'paths') { mkdir "$dir/added" or die $!; }
    else { unlink "$dir/link" or die $!; symlink '../held',"$dir/link" or die $!; }
    eval { remove_owned($dir,$before,1); 1 } and die "accepted changed $change tree";
    $@ =~ /maintenance tree changed:.*changed:|maintenance tree changed:.*path added or removed:/
        or die "missing actionable refusal: $@";
    -d $dir && -f $file or die 'removed changed tree';
}
PERL
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
# A readable generation root does not establish custody of an unreadable child.
# Preview and apply must protect it rather than accept a partial inventory.
mkdir "$slot/set.new/unreadable"
printf 'keep original payload\n' > "$slot/set.new/unreadable/payload"
chmod 000 "$slot/set.new/unreadable"
if [[ ! -r "$slot/set.new/unreadable" ]]; then
    run preview > "$fixture/unreadable-preview.json"
    run apply --quiescent > "$fixture/unreadable-applied.json"
    chmod 700 "$slot/set.new/unreadable"
    for observed in unreadable-preview unreadable-applied; do
        jq -e --arg path "$slot/set.new" '
            .entries[] | select(.path==$path)
            | .status=="protected" and .reason=="unsafe-or-changing-tree"
        ' "$fixture/$observed.json" >/dev/null
    done
    [[ "$(cat "$slot/set.new/unreadable/payload")" == 'keep original payload' ]]
else
    chmod 700 "$slot/set.new/unreadable"
    echo 'Unreadable-generation probe unavailable: runner bypasses directory permissions'
fi
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
# A corrupt truthy string must not bypass the failed-attempt recovery window.
printf '{"schema":1,"complete":"false"}\n' > "$slot/set.unknown/managed.json"
if run apply --quiescent > "$fixture/corrupt-marker.log" 2>&1; then exit 1; fi
[[ -d "$slot/set.unknown" ]]
if run apply > "$fixture/no-custody.log" 2>&1; then exit 1; fi
fixture_complete=true
echo 'Tool maintenance protects peers, active work, unknown and redirected trees; retires obsolete generations'
