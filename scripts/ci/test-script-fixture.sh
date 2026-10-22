#!/usr/bin/env bash
# Shared companions: scripts/ci/prepare-script-fixture.sh scripts/ci/fixture-lifecycle.sh scripts/dev/install-host-tools.sh scripts/ci/check-formatting-hooks.sh scripts/ci/test-tag-maintenance.pl
set -euo pipefail
ROOT="${BASH_SOURCE[0]}"
[[ "$ROOT" == /* ]] || ROOT="$PWD/$ROOT"
ROOT="$(CDPATH='' cd -P -- "${ROOT%/*}/../.." && pwd -P)"
# shellcheck source=scripts/ci/fixture-lifecycle.sh
source "$ROOT/scripts/ci/fixture-lifecycle.sh"
fixture="$(fixture_create "${TMPDIR:-/tmp}/script-fixture-test.XXXXXX")"
fixture_complete=false
trap 'fixture_finish "$?" "$fixture" "Failed script-fixture test retained"' EXIT
source_root="$fixture/source space"
destination="$fixture/destination space"
mkdir -p "$source_root/scripts" "$source_root/docs" "$destination"
printf '#!/usr/bin/env bash\n# Shared companions: docs/graph.md scripts/leaf.sh\nexit 99\n' > "$source_root/scripts/root.sh"
printf '# Graph\n<!-- Shared companions: scripts/root.sh scripts/leaf.sh -->\n' > "$source_root/docs/graph.md"
# Unterminated line two and repeated edges must still follow the closure once.
printf '#!/usr/bin/env bash\n# Shared companions: docs/graph.md' > "$source_root/scripts/leaf.sh"
printf 'unselected\n' > "$source_root/unselected"
chmod 751 "$source_root/scripts/root.sh"
printf 'old fixture input\n' > "$destination/keep"
cp -p "$destination/keep" "$fixture/keep.before"
"$BASH" "$ROOT/scripts/ci/prepare-script-fixture.sh" "$source_root" "$destination" scripts/root.sh scripts/root.sh
for path in scripts/root.sh scripts/leaf.sh docs/graph.md; do cmp "$source_root/$path" "$destination/$path"; done
[[ -x "$destination/scripts/root.sh" && ! -e "$destination/unselected" ]]
perl -e 'my @a=stat $ARGV[0]; my @b=stat $ARGV[1]; ($a[2]&07777)==($b[2]&07777) or die "mode changed\n"' \
    "$source_root/scripts/root.sh" "$destination/scripts/root.sh"
printf 'obsolete fixture bytes\n' > "$destination/scripts/root.sh"
"$BASH" "$ROOT/scripts/ci/prepare-script-fixture.sh" "$source_root" "$destination" scripts/root.sh
cmp "$source_root/scripts/root.sh" "$destination/scripts/root.sh"
# Admission must fail before replacing even an earlier valid root.
expect_refusal() {
    local status=0
    "$BASH" "$ROOT/scripts/ci/prepare-script-fixture.sh" "$source_root" "$destination" keep "$@" > "$fixture/refusal.log" 2>&1 || status=$?
    [[ "$status" == 2 ]]
    cmp "$fixture/keep.before" "$destination/keep"
}
printf 'must not replace before admission\n' > "$source_root/keep"
for bad in missing /absolute ../outside scripts/../root.sh scripts//root.sh $'scripts/bad\r' $'scripts/bad\n'; do
    expect_refusal "$bad"
done
printf '#!/bin/sh\n# Shared companions: scripts/missing.sh\n' > "$source_root/scripts/broken.sh"
expect_refusal scripts/broken.sh
[[ ! -e "$destination/scripts/broken.sh" ]]
printf '#!/bin/sh\n# Shared companions: ../escape\n' > "$source_root/scripts/broken.sh"
expect_refusal scripts/broken.sh
ln -s scripts/root.sh "$source_root/source-link"
expect_refusal source-link
ln -s "$source_root/scripts" "$source_root/linked"
expect_refusal linked/root.sh
ln -s "$fixture/keep.before" "$destination/output-link"
printf 'new\n' > "$source_root/output-link"
expect_refusal output-link
ln -s "$fixture" "$destination/linked"
mkdir -p "$source_root/linked-dir"
printf 'leaf\n' > "$source_root/linked-dir/leaf"
ln -s "$fixture" "$destination/linked-dir"
expect_refusal linked-dir/leaf
mkdir "$destination/blocked"
printf 'leaf\n' > "$source_root/blocked"
expect_refusal blocked
for overlap in "$source_root" "$fixture"; do
    if "$BASH" "$ROOT/scripts/ci/prepare-script-fixture.sh" "$source_root" "$overlap" keep > "$fixture/overlap.log" 2>&1; then exit 1; fi
done
cmp "$fixture/keep.before" "$destination/keep"
# Consumer evidence directories may be beneath their source checkout. The
# complete graph must still refuse source/output collisions before any copy.
nested="$source_root/target/evidence"
mkdir -p "$nested"
"$BASH" "$ROOT/scripts/ci/prepare-script-fixture.sh" "$source_root" "$nested" scripts/root.sh
for path in scripts/root.sh scripts/leaf.sh docs/graph.md; do cmp "$source_root/$path" "$nested/$path"; done
cp "$fixture/keep.before" "$nested/keep"
printf '#!/bin/sh\n# Shared companions: target/evidence/keep\n' > "$source_root/scripts/collision.sh"
status=0
"$BASH" "$ROOT/scripts/ci/prepare-script-fixture.sh" "$source_root" "$nested" keep scripts/collision.sh \
    > "$fixture/overlap.log" 2>&1 || status=$?
[[ "$status" == 2 && ! -e "$nested/scripts/collision.sh" && ! -e "$nested/target" ]]
cmp "$fixture/keep.before" "$nested/keep"
# Different output names can still alias a selected input through a hard link.
# Refuse the complete plan before copying the earlier root over a companion.
hardlinked="$fixture/hardlinked"
mkdir "$hardlinked"
cp "$source_root/scripts/leaf.sh" "$fixture/leaf.before"
ln "$source_root/scripts/leaf.sh" "$hardlinked/keep"
status=0
"$BASH" "$ROOT/scripts/ci/prepare-script-fixture.sh" "$source_root" "$hardlinked" keep scripts/root.sh \
    > "$fixture/hardlinked.log" 2>&1 || status=$?
[[ "$status" == 2 && ! -e "$hardlinked/scripts" ]] || exit 1
cmp "$fixture/leaf.before" "$source_root/scripts/leaf.sh"
# Existing outputs may alias each other without aliasing the source. Copying
# both would silently leave the earlier root with the later companion's bytes.
aliased_outputs="$fixture/aliased-outputs"
mkdir -p "$aliased_outputs/scripts"
cp "$fixture/keep.before" "$aliased_outputs/keep"
ln "$aliased_outputs/keep" "$aliased_outputs/scripts/leaf.sh"
status=0
"$BASH" "$ROOT/scripts/ci/prepare-script-fixture.sh" "$source_root" "$aliased_outputs" keep scripts/root.sh \
    > "$fixture/aliased-outputs.log" 2>&1 || status=$?
[[ "$status" == 2 && ! -e "$aliased_outputs/scripts/root.sh" && ! -e "$aliased_outputs/docs" ]] || exit 1
cmp "$fixture/keep.before" "$aliased_outputs/keep"
cmp "$fixture/keep.before" "$aliased_outputs/scripts/leaf.sh"
cmp "$fixture/leaf.before" "$source_root/scripts/leaf.sh"
# Static permission failures must refuse before an earlier valid overwrite.
mkdir -p "$source_root/locked/child" "$destination/locked"
printf 'leaf\n' > "$source_root/locked/child/leaf"
chmod 000 "$destination/locked"
if [[ ! -x "$destination/locked" ]]; then expect_refusal locked/child/leaf; fi
chmod 700 "$destination/locked"
printf 'old\n' > "$destination/readonly"
printf 'new\n' > "$source_root/readonly"
chmod 400 "$destination/readonly"
if [[ ! -w "$destination/readonly" ]]; then expect_refusal readonly; fi
chmod 600 "$destination/readonly"
# Qualify real roots whose transitive dependencies have changed independently.
mkdir "$fixture/real"
CDPATH="$fixture" "$BASH" "$ROOT/scripts/ci/prepare-script-fixture.sh" \
    "$ROOT" "$fixture/real" scripts/dev/install-host-tools.sh scripts/ci/check-formatting-hooks.sh \
    scripts/ci/test-tag-maintenance.pl
for path in scripts/ci/tool-catalog-records.pl scripts/ci/ic-tool-pins.awk \
    scripts/dev/tool-store.sh ci/tool-versions.env scripts/ci/fixture-lifecycle.sh \
    scripts/dev/delete-github-tags-up-to.pl scripts/ci/StableVersion.pm; do
    cmp "$ROOT/$path" "$fixture/real/$path"
done
fixture_complete=true
echo 'Script fixture roots, companion closure, modes and effect-free admission passed'
