#!/usr/bin/env bash
# Shared companions: scripts/ci/fixture-lifecycle.sh scripts/release/metadata.sh
set -euo pipefail

# This independent fixture owns its Make selections and logger checkout.
unset MAKEFLAGS MFLAGS MAKEOVERRIDES GNUMAKEFLAGS MAKEFILES
unset VALIDATION_REPOSITORY_ROOT VALIDATION_RUNNER_SNAPSHOT_PATH

ROOT="$0"
[[ "$ROOT" == /* ]] || ROOT="$PWD/$ROOT"
ROOT="$(cd -P "${ROOT%/*}/../.." && printf '%s/.' "$PWD")"
ROOT="${ROOT%/.}"
# shellcheck source=scripts/ci/fixture-lifecycle.sh
source "$ROOT/scripts/ci/fixture-lifecycle.sh"
FIXTURE="$(fixture_create "${TMPDIR:-/tmp}/release-metadata-test.XXXXXX")"
fixture_complete=false
trap 'fixture_finish "$?" "$FIXTURE" "Release metadata fixtures retained"' EXIT

# Reuse existing history; exercise real indexes and trees without new commits.
git clone --quiet --shared --no-checkout "$ROOT" "$FIXTURE/repository"
cd "$FIXTURE/repository"
git read-tree HEAD
git checkout-index --all
# Metadata qualification does not install real tools. Setup/check routing through
# the real Makefile and runner is covered by test-release-editor-setup.sh.
cat > "$FIXTURE/tool-make" <<'MAKE'
#!/usr/bin/env bash
set -euo pipefail
[[ "$*" == '--no-print-directory tools-check' ]] || exit 91
MAKE
chmod +x "$FIXTURE/tool-make"
export RELEASE_MAKE="$FIXTURE/tool-make"
export RELEASE_PREVIOUS=0.1.0 RELEASE_VERSION=0.1.1 RELEASE_DATE=2026-10-06
export RELEASE_COMMIT=''
printf '0.1.0\n' > VERSION
cat > CHANGELOG.md <<'NOTES'
# Changelog

## [0.1.1]

- Pending change.

## [0.1.0]

- Preserved history.
NOTES
cp CHANGELOG.md "$FIXTURE/pending-notes"
bash "$ROOT/scripts/release/metadata.sh" preflight
cmp CHANGELOG.md "$FIXTURE/pending-notes"

# Both pending spellings finalize automatically; preflight remains read-only.
for heading in '## [0.1.1] - Unreleased' $'##\t[0.1.1]  -\tUnreleased'; do
    printf '# Changelog\n\n%s\n\n- Pending change.\n' "$heading" > CHANGELOG.md
    cp CHANGELOG.md "$FIXTURE/unreleased-notes"
    bash "$ROOT/scripts/release/metadata.sh" preflight
    cmp CHANGELOG.md "$FIXTURE/unreleased-notes"
    [[ "$(cat VERSION)" == 0.1.0 ]] || exit 1
    bash "$ROOT/scripts/release/metadata.sh" prepare
    printf '# Changelog\n\n## [0.1.1] - 2026-10-06\n\n- Pending change.\n' > "$FIXTURE/dated-notes"
    cmp CHANGELOG.md "$FIXTURE/dated-notes"
    [[ "$(cat VERSION)" == 0.1.1 ]] || exit 1
    bash "$ROOT/scripts/release/metadata.sh" check
    printf '0.1.0\n' > VERSION
done
cp "$FIXTURE/pending-notes" CHANGELOG.md

# Invalid identity must stop every preparation path before changing either file.
for bad in invalid-version 01.1.0 0.1.0-beta; do
    printf '%s\n' "$bad" > VERSION
    for operation in preflight prepare; do
        if bash "$ROOT/scripts/release/metadata.sh" "$operation" > "$FIXTURE/invalid-$operation.log" 2>&1; then
            echo 'release metadata test failed: invalid version accepted' >&2; exit 1
        fi
        [[ "$(cat VERSION)" == "$bad" ]] || exit 1
        cmp CHANGELOG.md "$FIXTURE/pending-notes"
    done
done
printf '0.1.0\n' > VERSION

# A read failure must not turn a partial, version-shaped value into an identity.
mkdir "$FIXTURE/read-failure-bin"
cat > "$FIXTURE/read-failure-bin/cat" <<'STUB'
#!/usr/bin/env bash
printf '0.1.0\n'
exit 9
STUB
chmod +x "$FIXTURE/read-failure-bin/cat"
if PATH="$FIXTURE/read-failure-bin:$PATH" bash "$ROOT/scripts/release/metadata.sh" preflight \
    > "$FIXTURE/read-failure.log" 2>&1; then
    echo 'release metadata test failed: partial version read passed preflight' >&2
    exit 1
fi

# Staged content can differ while the working file still matches HEAD exactly.
original_tree="$(git write-tree)"
replacement="$(git rev-parse HEAD:README.md)"
git update-index --cacheinfo "100644,$replacement,AGENTS.md"
[[ "$(git write-tree)" != "$original_tree" ]] || exit 1
git diff --quiet HEAD -- AGENTS.md
if git diff --cached --quiet HEAD -- AGENTS.md; then
    echo 'release metadata test failed: hidden staged-change fixture is invalid' >&2
    exit 1
fi
if bash "$ROOT/scripts/release/metadata.sh" preflight > "$FIXTURE/staged.log" 2>&1; then
    echo 'release metadata test failed: hidden staged change passed preflight' >&2
    exit 1
fi
rg -F AGENTS.md "$FIXTURE/staged.log" >/dev/null
git read-tree HEAD

# Ordinary working edits and untracked files must also remain excluded.
for state in unstaged untracked; do
    if [[ "$state" == unstaged ]]; then
        printf '\nUnrelated working edit.\n' >> AGENTS.md
    else
        printf 'Unrelated untracked file.\n' > unrelated.txt
    fi
    if bash "$ROOT/scripts/release/metadata.sh" preflight > "$FIXTURE/$state.log" 2>&1; then
        echo "release metadata test failed: $state work passed preflight" >&2
        exit 1
    fi
    git checkout-index --force -- AGENTS.md
    rm -f unrelated.txt
done

# A selection mismatch must fail without modifying notes or needing a plan.
if RELEASE_VERSION=0.2.0 bash "$ROOT/scripts/release/metadata.sh" preflight \
    > "$FIXTURE/candidate.log" 2>&1; then
    echo 'release metadata test failed: conflicting candidate passed preflight' >&2
    exit 1
fi
cmp CHANGELOG.md "$FIXTURE/pending-notes"
[[ ! -e .git/release-state ]] || exit 1
# Exercise the real adapter's publication boundaries without release commits,
# tags or tool setup. Failed attempts retain both snapshots; retry keeps them.
mkdir "$FIXTURE/failure-bin"
export METADATA_REAL_CP METADATA_REAL_MV METADATA_REAL_RM
METADATA_REAL_CP="$(command -v cp)"
METADATA_REAL_MV="$(command -v mv)"
METADATA_REAL_RM="$(command -v rm)"
cat > "$FIXTURE/failure-bin/cp" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$METADATA_FAILURE" == stage && "$*" == *'/candidate/VERSION '* ]]; then exit 37; fi
exec "$METADATA_REAL_CP" "$@"
STUB
cat > "$FIXTURE/failure-bin/mv" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
case "$METADATA_FAILURE:${!#}" in
    notes:CHANGELOG.md|version:VERSION) exit 37 ;;
    signal:VERSION) kill -TERM "$PPID"; exit 0 ;;
esac
exec "$METADATA_REAL_MV" "$@"
STUB
cat > "$FIXTURE/failure-bin/rm" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$METADATA_FAILURE" == cleanup && "${!#}" == */release-metadata.* ]]; then exit 41; fi
exec "$METADATA_REAL_RM" "$@"
STUB
chmod +x "$FIXTURE/failure-bin/"*
for failure in stage notes version signal cleanup; do
    printf '0.1.0\n' > VERSION
    cp "$FIXTURE/pending-notes" CHANGELOG.md
    chmod 640 VERSION CHANGELOG.md
    status=0
    PATH="$FIXTURE/failure-bin:$PATH" METADATA_FAILURE="$failure" \
        bash "$ROOT/scripts/release/metadata.sh" prepare > "$FIXTURE/$failure.log" 2>&1 || status=$?
    expected=37
    case "$failure" in signal) expected=143 ;; cleanup) expected=41 ;; esac
    [[ "$status" == "$expected" ]] || exit 1
    retained="$(sed -n 's/^Shared release metadata evidence retained: //p' "$FIXTURE/$failure.log")"
    [[ "$retained" == "$PWD/.git/release-metadata."* && -d "$retained" ]] || exit 1
    cmp "$FIXTURE/pending-notes" "$retained/original/CHANGELOG.md"
    [[ "$(cat "$retained/original/VERSION")" == 0.1.0 &&
       "$(cat "$retained/candidate/VERSION")" == 0.1.1 ]] || exit 1
    rg -Fx '## [0.1.1] - 2026-10-06' "$retained/candidate/CHANGELOG.md" > /dev/null
    case "$failure" in
        stage|notes) cmp "$FIXTURE/pending-notes" CHANGELOG.md ;;
        *) cmp "$retained/candidate/CHANGELOG.md" CHANGELOG.md ;;
    esac
    live_version=0.1.0
    [[ "$failure" != cleanup ]] || live_version=0.1.1
    [[ "$(cat VERSION)" == "$live_version" ]] || exit 1
    perl -e 'for (@ARGV) { ((stat $_)[2] & 0777) == 0640 or die "metadata mode changed: $_\n" }' \
        VERSION CHANGELOG.md "$retained/original/VERSION" "$retained/original/CHANGELOG.md" \
        "$retained/candidate/VERSION" "$retained/candidate/CHANGELOG.md"
    cp -R "$retained" "$FIXTURE/saved-$failure"
    find .git -maxdepth 1 -name 'release-metadata.*' | LC_ALL=C sort > "$FIXTURE/before-retry"
    if [[ "$failure" != cleanup ]]; then
        bash "$ROOT/scripts/release/metadata.sh" preflight
        bash "$ROOT/scripts/release/metadata.sh" prepare
    fi
    bash "$ROOT/scripts/release/metadata.sh" check
    find .git -maxdepth 1 -name 'release-metadata.*' | LC_ALL=C sort > "$FIXTURE/after-retry"
    cmp "$FIXTURE/before-retry" "$FIXTURE/after-retry"
    diff -r "$FIXTURE/saved-$failure" "$retained"
    [[ "$(cat VERSION)" == 0.1.1 ]] || exit 1
done
printf '0.1.0\n' > VERSION
cp "$FIXTURE/pending-notes" CHANGELOG.md
bash "$ROOT/scripts/release/metadata.sh" preflight
bash "$ROOT/scripts/release/metadata.sh" prepare
[[ "$(bash "$ROOT/scripts/release/metadata.sh" version)" == 0.1.1 ]] || exit 1
cp CHANGELOG.md "$FIXTURE/prepared-notes"
# Simulate interruption after notes replacement, before VERSION replacement.
printf '0.1.0\n' > VERSION
bash "$ROOT/scripts/release/metadata.sh" preflight
bash "$ROOT/scripts/release/metadata.sh" prepare
cmp CHANGELOG.md "$FIXTURE/prepared-notes"
[[ "$(cat VERSION)" == 0.1.1 ]] || exit 1
rg -x '## \[0.1.0\]' CHANGELOG.md >/dev/null
git add -- CHANGELOG.md VERSION
bash "$ROOT/scripts/release/metadata.sh" commit-check
[[ "$(git diff --cached --name-only HEAD)" == $'CHANGELOG.md\nVERSION' ]] || exit 1

# Versions must be canonical and both metadata index entries must match.
for bad in '01.1.1' '0.1.1-beta' '0.1.2'; do
    printf '%s\n' "$bad" > VERSION
    if bash "$ROOT/scripts/release/metadata.sh" check > "$FIXTURE/version-check.log" 2>&1; then exit 1; fi
    if bash "$ROOT/scripts/release/metadata.sh" commit-check > "$FIXTURE/version.log" 2>&1; then exit 1; fi
done
printf '0.1.1\n' > VERSION

# The final boundary must reject both unrelated index entries and stale staging.
git update-index --cacheinfo "100644,$replacement,AGENTS.md"
if bash "$ROOT/scripts/release/metadata.sh" commit-check > "$FIXTURE/commit.log" 2>&1; then
    echo 'release metadata test failed: hidden staged change passed commit check' >&2
    exit 1
fi
git read-tree HEAD
if bash "$ROOT/scripts/release/metadata.sh" commit-check > "$FIXTURE/stale-index.log" 2>&1; then
    echo 'release metadata test failed: unstaged prepared metadata passed commit check' >&2
    exit 1
fi
git add -- CHANGELOG.md VERSION
bash "$ROOT/scripts/release/metadata.sh" commit-check

# Late checks select the saved commit's two metadata blobs, not current files.
# Use an immutable existing Git tree as the selected object; no commit is created.
selected_tree="$(git write-tree)"
printf '0.1.2\n' > VERSION
printf '\nLater working notes.\n' >> CHANGELOG.md
RELEASE_COMMIT="$selected_tree" bash "$ROOT/scripts/release/metadata.sh" check
if RELEASE_COMMIT=HEAD bash "$ROOT/scripts/release/metadata.sh" check > "$FIXTURE/old-commit.log" 2>&1; then exit 1; fi

# Already-finalized notes for a different date are an identity conflict.
printf '0.1.0\n' > VERSION
cp "$FIXTURE/prepared-notes" CHANGELOG.md
if RELEASE_DATE=2026-10-07 bash "$ROOT/scripts/release/metadata.sh" preflight > "$FIXTURE/date.log" 2>&1; then exit 1; fi

# Use the actual Makefile adapter and logger, replacing only the expensive gate.
logging_root="$FIXTURE/logging"
mkdir -p "$logging_root/scripts/ci"
git init -q "$logging_root"
cp "$ROOT/scripts/ci/run-validation-targets.sh" "$logging_root/scripts/ci/"
cp "$ROOT/scripts/ci/check-make-execution.sh" "$logging_root/scripts/ci/"
cp "$ROOT/scripts/ci/verify-file-checksum.sh" "$logging_root/scripts/ci/"
cp "$ROOT/Makefile" "$logging_root/Makefile"
mkdir -p "$logging_root/make"
cp "$ROOT/make/consumer.mk" "$logging_root/make/"
cp "$ROOT/make/tools.mk" "$logging_root/make/"
cp "$ROOT/make/release.mk" "$logging_root/make/"
cp "$ROOT/make/execution.mk" "$logging_root/make/"
cat >> "$logging_root/Makefile" <<'MAKE'
ci:
	@test "$(RELEASE_VERSION)" = 0.1.1
	@test -z "$(RELEASE_COMMIT)"
	@echo release-gate-failure-marker
	@exit 7
MAKE
for attempt in first second; do
    if make --no-print-directory -C "$logging_root" release-verify \
        > "$FIXTURE/$attempt-gate.log" 2>&1; then
        echo 'release metadata test failed: failing release gate passed' >&2
        exit 1
    fi
    rg -F release-gate-failure-marker \
        "$logging_root/.git/release-state/validation-failures/latest.log" >/dev/null || {
        cat "$FIXTURE/$attempt-gate.log" >&2
        echo 'release metadata test failed: wrong gate or inherited release selection' >&2
        exit 1
    }
    if [[ "$attempt" == first ]]; then
        retained_logs=("$logging_root"/.git/release-state/validation-failures/*-0-ci.log)
        retained_log="${retained_logs[0]}"
        cp "$retained_log" "$FIXTURE/first-retained.log"
    fi
done
cmp "$retained_log" "$FIXTURE/first-retained.log"
retained_logs=("$logging_root"/.git/release-state/validation-failures/*-0-ci.log)
[[ "${#retained_logs[@]}" == 2 ]] || exit 1

echo 'release metadata real-Git and validation-retention tests passed'
fixture_complete=true
