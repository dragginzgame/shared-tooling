#!/usr/bin/env bash
# Shared companions: scripts/distribution/refresh-consumer.sh scripts/ci/fixture-lifecycle.sh
set -euo pipefail
root="$(cd -P "${BASH_SOURCE[0]%/*}/../.." && pwd -P)"
# shellcheck source=scripts/ci/fixture-lifecycle.sh
source "$root/scripts/ci/fixture-lifecycle.sh"
fixture="$(fixture_create "${TMPDIR:-/tmp}/snapshot-takeover.XXXXXX")"
fixture_complete=false
trap 'fixture_finish "$?" "$fixture" "Snapshot takeover fixture retained"' EXIT
source_root="$fixture/source"; seed="$fixture/seed"
mkdir -p "$source_root/scripts/ci" "$seed" "$fixture/nested"
git init -q "$source_root"
git -C "$source_root" config user.name Fixture
git -C "$source_root" config user.email fixture@example.invalid
git -C "$source_root" config core.hooksPath /dev/null
git -C "$source_root" remote add origin https://example.invalid/shared-tooling
cp -p "$root/scripts/ci/verify-file-checksum.sh" "$root/scripts/ci/verify-shared-tooling-snapshot.sh" "$source_root/scripts/ci/"
printf '0.15.0\n' > "$source_root/VERSION"
printf '#!/bin/sh\necho primary\n' > "$source_root/primary.sh"
printf '#!/bin/sh\necho supplemental\n' > "$source_root/supplemental.sh"
printf '#!/bin/sh\necho nested\n' > "$source_root/nested.sh"
chmod +x "$source_root/nested.sh"
git -C "$source_root" add VERSION primary.sh supplemental.sh nested.sh scripts/ci/verify-file-checksum.sh scripts/ci/verify-shared-tooling-snapshot.sh
git -C "$source_root" -c commit.gpgsign=false commit -qm source
git -C "$source_root" -c tag.gpgsign=false tag -a fixture-revision -m 'Non-commit revision object'
tree_revision="$(git -C "$source_root" rev-parse 'HEAD^{tree}')"
tag_revision="$(git -C "$source_root" rev-parse refs/tags/fixture-revision)"
git init -q "$seed"
bash "$root/scripts/distribution/refresh-consumer.sh" --source "$source_root" --consumer "$seed" --entrypoint primary.sh > "$fixture/root.log"
bash "$root/scripts/distribution/refresh-consumer.sh" --source "$source_root" --consumer "$seed" --manifest .supplement.snapshot --entrypoint supplemental.sh > "$fixture/supplement.log"
git init -q "$fixture/nested"
bash "$root/scripts/distribution/refresh-consumer.sh" --source "$source_root" --consumer "$fixture/nested" --entrypoint nested.sh > "$fixture/nested.log"
mkdir -p "$seed/helpers/scripts/ci"
cp -p "$fixture/nested/.shared-tooling.snapshot" "$fixture/nested/nested.sh" "$seed/helpers/"
cp -p "$fixture/nested/scripts/ci/"*.sh "$seed/helpers/scripts/ci/"
printf 'unrelated\n' > "$seed/unrelated"
git -C "$seed" add unrelated
mkdir "$fixture/kind-bin"
TAKEOVER_REAL_GIT="$(command -v git)"
export TAKEOVER_REAL_GIT
cat > "$fixture/kind-bin/git" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
if [[ $# == 5 && "$1" == -C && "$3" == cat-file && "$4" == -t ]]; then
    printf 'commit\n'
    echo 'fixture kind observation failed' >&2
    exit 73
fi
exec "$TAKEOVER_REAL_GIT" "$@"
STUB
chmod +x "$fixture/kind-bin/git"
for subject in valid interrupted edited mode staged staged-receipt forged wrong-source unavailable tree-revision tag-revision failed-kind missing alias duplicate; do
    consumer="$fixture/$subject"
    cp -Rp "$seed" "$consumer"
    case "$subject" in
        edited) printf 'local\n' >> "$consumer/helpers/nested.sh" ;;
        mode) chmod -x "$consumer/helpers/nested.sh" ;;
        staged) git -C "$consumer" add helpers/nested.sh ;;
        staged-receipt) git -C "$consumer" add .supplement.snapshot ;;
        unavailable) sed -E 's/^(revision[[:space:]]+)[0-9a-f]+$/\11111111111111111111111111111111111111111/' "$consumer/.supplement.snapshot" > "$consumer/missing-revision"; mv "$consumer/missing-revision" "$consumer/.supplement.snapshot" ;;
        tree-revision|tag-revision)
            revision="$tree_revision"
            [[ "$subject" != tag-revision ]] || revision="$tag_revision"
            awk -F '\t' -v OFS='\t' -v revision="$revision" '$1=="revision" {$2=revision} {print}' \
                "$consumer/.supplement.snapshot" > "$consumer/non-commit-revision"
            mv "$consumer/non-commit-revision" "$consumer/.supplement.snapshot" ;;
        forged)
            printf 'forged\n' >> "$consumer/helpers/nested.sh"
            digest="$(bash "$root/scripts/ci/verify-file-checksum.sh" --print sha256 "$consumer/helpers/nested.sh")"
            awk -F '\t' -v OFS='\t' -v digest="$digest" '$1=="file" && $4=="nested.sh" {$2=digest} {print}' \
                "$consumer/helpers/.shared-tooling.snapshot" > "$consumer/forged"
            mv "$consumer/forged" "$consumer/helpers/.shared-tooling.snapshot" ;;
        wrong-source) sed 's,https://example.invalid/shared-tooling,https://example.invalid/other,' "$consumer/.supplement.snapshot" > "$consumer/wrong"; mv "$consumer/wrong" "$consumer/.supplement.snapshot" ;;
        missing) rm "$consumer/helpers/.shared-tooling.snapshot" ;;
        alias) mv "$consumer/helpers" "$consumer/physical"; ln -s physical "$consumer/helpers" ;;
    esac
    args=(--source "$source_root" --consumer "$consumer" --takeover-snapshot . .supplement.snapshot --takeover-snapshot helpers .shared-tooling.snapshot)
    [[ "$subject" != duplicate ]] || args+=(--takeover-snapshot . .supplement.snapshot)
    refresh=(bash "$root/scripts/distribution/refresh-consumer.sh")
    [[ "$subject" != failed-kind ]] || refresh=(env PATH="$fixture/kind-bin:$PATH" "${refresh[@]}")
    cp -Rp "$consumer" "$fixture/before-$subject"
    status=0
    "${refresh[@]}" --preview "${args[@]}" > "$fixture/$subject-preview.log" 2>&1 || status=$?
    diff -r "$fixture/before-$subject" "$consumer" > "$fixture/$subject-diff.log" || { cat "$fixture/$subject-diff.log" >&2; exit 1; }
    if [[ "$subject" == valid || "$subject" == interrupted ]]; then
        [[ "$status" == 0 ]] || { cat "$fixture/$subject-preview.log" >&2; exit 1; }
        if [[ "$subject" == interrupted ]]; then
            mkdir "$fixture/bin"
            TAKEOVER_REAL_MV="$(command -v mv)"
            export TAKEOVER_REAL_MV TAKEOVER_DESTINATION="$consumer/.shared-tooling.snapshot"
            cat > "$fixture/bin/mv" <<'STUB'
#!/usr/bin/env bash
if [[ "$#" == 2 && "$2" == "$TAKEOVER_DESTINATION" ]]; then exit 37; fi
exec "$TAKEOVER_REAL_MV" "$@"
STUB
            chmod +x "$fixture/bin/mv"
            status=0
            PATH="$fixture/bin:$PATH" bash "$root/scripts/distribution/refresh-consumer.sh" "${args[@]}" \
                > "$fixture/interrupted-apply.log" 2>&1 || status=$?
            [[ "$status" == 37 && ! -e "$consumer/helpers/nested.sh" ]] || exit 1
            for receipt in .shared-tooling.snapshot .supplement.snapshot helpers/.shared-tooling.snapshot; do
                cmp "$fixture/before-$subject/$receipt" "$consumer/$receipt"
            done
            cmp "$seed/.git/index" "$consumer/.git/index"
        fi
        bash "$root/scripts/distribution/refresh-consumer.sh" "${args[@]}" > "$fixture/$subject-apply.log" 2>&1
        [[ -f "$consumer/nested.sh" && -x "$consumer/nested.sh" && -f "$consumer/supplemental.sh" ]] || exit 1
        [[ ! -e "$consumer/helpers/nested.sh" && ! -e "$consumer/helpers/.shared-tooling.snapshot" && ! -e "$consumer/.supplement.snapshot" ]] || exit 1
        cmp "$seed/.git/index" "$consumer/.git/index"
        cmp "$seed/unrelated" "$consumer/unrelated"
        bash "$root/scripts/distribution/refresh-consumer.sh" --source "$source_root" --consumer "$consumer" > "$fixture/retry.log"
        bash "$root/scripts/ci/verify-shared-tooling-snapshot.sh" --consumer "$consumer" > "$fixture/verify.log"
    else
        [[ "$status" != 0 ]] || exit 1
        if "${refresh[@]}" "${args[@]}" > "$fixture/$subject-apply.log" 2>&1; then exit 1; fi
        if [[ "$subject" == failed-kind ]]; then
            grep -Fx 'fixture kind observation failed' "$fixture/$subject-preview.log" > /dev/null
            grep -Fx 'fixture kind observation failed' "$fixture/$subject-apply.log" > /dev/null
        fi
        diff -r "$fixture/before-$subject" "$consumer" > "$fixture/$subject-diff.log" || { cat "$fixture/$subject-diff.log" >&2; exit 1; }
    fi
done
fixture_complete=true
echo 'Verified snapshot handover, preview custody, corruption and index preservation passed'
