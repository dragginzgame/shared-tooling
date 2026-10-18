#!/usr/bin/env bash
# Shared companions: scripts/distribution/measure-snapshot-refresh.sh scripts/ci/shared-companions.sh scripts/ci/fixture-lifecycle.sh scripts/ci/extract-workflow-step.sh scripts/ci/archive-evidence.sh scripts/ci/verify-file-checksum.sh .github/workflows/snapshot-performance.yml
set -euo pipefail
ROOT="${BASH_SOURCE[0]}"
[[ "$ROOT" == /* ]] || ROOT="$PWD/$ROOT"
ROOT="$(cd -P "${ROOT%/*}/../.." && printf '%s/.' "$PWD")"
ROOT="${ROOT%/.}"
# This fixture uses existing committed source, never creates fixture commits and
# substitutes only the selected runner read/failure. Successful measurement is
# qualified separately against two real exporter revisions.
fixture="$(mktemp -d "${TMPDIR:-/tmp}/snapshot-performance.XXXXXX")"
# shellcheck source=scripts/ci/fixture-lifecycle.sh
source "$ROOT/scripts/ci/fixture-lifecycle.sh"
fixture_complete=false
trap 'fixture_finish "$?" "$fixture" "Snapshot measurement fixture retained"' EXIT
revision="$(git -C "$ROOT" rev-parse HEAD)"
MEASUREMENT_REAL_GIT="$(command -v git)"
export MEASUREMENT_REAL_GIT MEASUREMENT_REVISION="$revision"
export MEASUREMENT_EXECUTED="$fixture/executed"
export MEASUREMENT_READER_SOURCE="$ROOT/scripts/ci/shared-companions.sh"
MEASUREMENT_READER_BLOB="$(git hash-object "$MEASUREMENT_READER_SOURCE")"
export MEASUREMENT_READER_BLOB
mkdir "$fixture/bin"
cat > "$fixture/bin/git" <<'GIT'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$MEASUREMENT_MODE" == reader-* ]]; then
    if [[ "${3:-}" == ls-tree && "${7:-}" == scripts/ci/shared-companions.sh ]]; then
        echo scripts/ci/shared-companions.sh; exit 0
    elif [[ "${3:-}" == rev-parse && "${4:-}" == "$MEASUREMENT_REVISION:scripts/ci/shared-companions.sh" ]]; then
        echo "$MEASUREMENT_READER_BLOB"; exit 0
    elif [[ "${3:-}" == show && "${4:-}" == "$MEASUREMENT_REVISION:scripts/ci/shared-companions.sh" ]]; then
        if [[ "$MEASUREMENT_MODE" == reader-read-failure ]]; then
            printf 'printf executed > "$MEASUREMENT_EXECUTED"\n'; exit 74
        fi
        cat "$MEASUREMENT_READER_SOURCE"; exit 0
    fi
fi
if [[ "${3:-}" == show && "${4:-}" == "$MEASUREMENT_REVISION:scripts/distribution/refresh-consumer.sh" ]]; then
    case "$MEASUREMENT_MODE" in
        read-failure)
            printf '#!/usr/bin/env bash\nprintf executed > "$MEASUREMENT_EXECUTED"\n'
            exit 73 ;;
        exit-failure) printf '#!/usr/bin/env bash\nexit 47\n'; exit 0 ;;
        reader-present|reader-read-failure)
            cat <<'RUNNER'
#!/usr/bin/env bash
set -euo pipefail
source "${BASH_SOURCE[0]%/scripts/distribution/*}/scripts/ci/shared-companions.sh"
declare -F read_shared_companions > /dev/null
exit 47
RUNNER
            exit 0 ;;
        signal) printf '#!/usr/bin/env bash\nkill -TERM "$$"\n'; exit 0 ;;
        verify-failure|mismatch|cpu-write-failure)
            "$MEASUREMENT_REAL_GIT" "$@"
            cat <<'APPEND'
if [[ "$MEASUREMENT_MODE" == verify-failure ]]; then
    printf corrupt >> "$CONSUMER_ROOT/scripts/ci/verify-shared-tooling-snapshot.sh"
elif [[ "$MEASUREMENT_MODE" == cpu-write-failure ]]; then
    mkdir "${CONSUMER_ROOT%/*}/warmup-0-before.cpu"
elif [[ "${BASH_SOURCE[0]}" == */after/* ]]; then
    printf unexpected > "$CONSUMER_ROOT/unexpected"
fi
APPEND
            exit 0 ;;
    esac
fi
exec "$MEASUREMENT_REAL_GIT" "$@"
GIT
chmod +x "$fixture/bin/git"

# Existing output custody and CR/LF checks run before any measurement starts.
mkdir "$fixture/occupied"
printf 'retained\n' > "$fixture/occupied/sentinel"
ln -s missing "$fixture/dangling"
for selected in "$fixture/occupied" "$fixture/dangling" "$fixture/newline"$'\n'; do
    status=0
    "$BASH" "$ROOT/scripts/distribution/measure-snapshot-refresh.sh" \
        "$revision" "$revision" "$revision" "$selected" > "$fixture/refusal.log" 2>&1 || status=$?
    [[ "$status" == 2 ]] || exit 1
done
[[ "$(cat "$fixture/occupied/sentinel")" == retained && -L "$fixture/dangling" ]] || exit 1
status=0
"$BASH" "$ROOT/scripts/distribution/measure-snapshot-refresh.sh" HEAD "$revision" "$revision" \
    "$fixture/bad-revision" > "$fixture/refusal.log" 2>&1 || status=$?
[[ "$status" == 2 && ! -e "$fixture/bad-revision" ]] || exit 1

for mode in read-failure reader-present reader-read-failure exit-failure signal verify-failure mismatch cpu-write-failure; do
    status=0
    PATH="$fixture/bin:$PATH" MEASUREMENT_MODE="$mode" "$BASH" \
        "$ROOT/scripts/distribution/measure-snapshot-refresh.sh" "$revision" "$revision" "$revision" \
        "$fixture/$mode" > "$fixture/$mode.log" 2>&1 || status=$?
    [[ "$status" != 0 && ! -e "$fixture/$mode/complete.txt" && ! -e "$MEASUREMENT_EXECUTED" ]] || exit 1
    case "$mode" in
        read-failure) [[ "$status" == 73 && ! -e "$fixture/$mode/samples.tsv" ]] || exit 1 ;;
        reader-present)
            [[ "$status" == 47 ]] || exit 1
            for side in before after; do
                cmp "$MEASUREMENT_READER_SOURCE" "$fixture/$mode/$side/scripts/ci/shared-companions.sh"
            done
            grep -F "$MEASUREMENT_READER_BLOB" "$fixture/$mode/identities.txt" > /dev/null ;;
        reader-read-failure) [[ "$status" == 74 && ! -e "$fixture/$mode/samples.tsv" ]] || exit 1 ;;
        exit-failure)
            [[ "$status" == 47 && ! -s "$fixture/$mode/warmup-0-before.seconds" &&
               ! -e "$fixture/$mode/warmup-0-before.cpu" ]] || exit 1 ;;
        signal)
            [[ ! -s "$fixture/$mode/warmup-0-before.seconds" ]] || exit 1
            grep -F 'did not exit normally' "$fixture/$mode/warmup-0-before.log" > /dev/null ;;
        verify-failure)
            grep -F 'differs from the snapshot' "$fixture/$mode/warmup-0-before.verify.log" > /dev/null ;;
        mismatch)
            grep -F 'snapshot verified' "$fixture/$mode/warmup-0-after.verify.log" > /dev/null
            grep -F unexpected "$fixture/$mode/warmup-0.compare.log" > /dev/null ;;
        cpu-write-failure)
            [[ -s "$fixture/$mode/warmup-0-before.seconds" &&
               -d "$fixture/$mode/warmup-0-before.cpu" ]] || exit 1
            grep -F 'open CPU observation:' "$fixture/$mode/warmup-0-before.log" > /dev/null
            [[ "$(wc -l < "$fixture/$mode/samples.tsv" | tr -d ' ')" == 1 &&
               "$(wc -l < "$fixture/$mode/cpu.tsv" | tr -d ' ')" == 1 ]] || exit 1 ;;
    esac
done
echo 'Snapshot measurement refusal, failed reads/exports, signals, verification and pair mismatch passed (substituted runners)'

# Execute the actual always-run packaging body: uploader directory defaults must
# not discard the hidden receipts needed to recheck a downloaded comparison.
yq -o=json '.jobs.paired-exports.steps' "$ROOT/.github/workflows/snapshot-performance.yml" > "$fixture/steps.json"
bash "$ROOT/scripts/ci/extract-workflow-step.sh" "$fixture/steps.json" archive > "$fixture/archive.sh"
jq -e 'map(select(.id == "archive" or .id == "upload")) | length == 2 and all(.[]; .if == "always()")' \
    "$fixture/steps.json" > /dev/null
printf '#!%s\nprintf "partial archive"\nexit 23\n' "$BASH" > "$fixture/bin/tar"
chmod +x "$fixture/bin/tar"
for scenario in complete partial archive-failure; do
    native="$fixture/workflow $scenario"
    evidence="$native/snapshot-comparison"
    mkdir -p "$evidence/consumer-measurement-1-after/.git" "$evidence/source"
    printf 'retained receipt\n' > "$evidence/consumer-measurement-1-after/.shared-tooling.snapshot"
    printf 'Git store must be excluded\n' > "$evidence/consumer-measurement-1-after/.git/config"
    printf 'source clone must be excluded\n' > "$evidence/source/bulk"
    printf 'phase\tpair\tside\tseconds\n' > "$evidence/samples.tsv"
    printf 'phase\tpair\tside\tuser_seconds\tsystem_seconds\nmeasurement\t1\tafter\t0.1\t0.2\n' > "$evidence/cpu.tsv"
    printf 'retained command output\n' > "$native/snapshot-comparison.log"
    [[ "$scenario" != complete ]] || printf 'verified\n' > "$evidence/complete.txt"
    status=0
    if [[ "$scenario" == archive-failure ]]; then
        (cd "$ROOT"; PATH="$fixture/bin:$PATH" RUNNER_TEMP="$native" "$BASH" --noprofile --norc -e -o pipefail \
            "$fixture/archive.sh") > "$native/packaging.log" 2>&1 || status=$?
        [[ "$status" != 0 && ! -e "$native/snapshot-comparison.sha256" &&
           -f "$evidence/consumer-measurement-1-after/.shared-tooling.snapshot" ]] || exit 1
        grep -F 'Evidence archive failed' "$native/snapshot-comparison-archive.log" > /dev/null
        [[ "$(cat "$native/snapshot-comparison.tar.gz")" == 'partial archive' ]] || exit 1
        continue
    fi
    (cd "$ROOT"; RUNNER_TEMP="$native" "$BASH" --noprofile --norc -e -o pipefail \
        "$fixture/archive.sh") > "$native/packaging.log" 2>&1 || status=$?
    [[ "$status" == 0 ]] || exit 1
    digest="$(cat "$native/snapshot-comparison.sha256")"
    bash "$ROOT/scripts/ci/verify-file-checksum.sh" sha256 "$digest" "$native/snapshot-comparison.tar.gz"
    mkdir "$native/unpacked"
    tar -xzf "$native/snapshot-comparison.tar.gz" -C "$native/unpacked"
    replay="$native/unpacked/snapshot-comparison"
    cmp "$evidence/consumer-measurement-1-after/.shared-tooling.snapshot" \
        "$replay/consumer-measurement-1-after/.shared-tooling.snapshot"
    cmp "$evidence/samples.tsv" "$replay/samples.tsv"
    cmp "$evidence/cpu.tsv" "$replay/cpu.tsv"
    [[ ! -e "$replay/source" && ! -e "$replay/consumer-measurement-1-after/.git" ]] || exit 1
    if [[ "$scenario" == complete ]]; then cmp "$evidence/complete.txt" "$replay/complete.txt";
    else [[ ! -e "$replay/complete.txt" ]] || exit 1; fi
done
echo 'Actual workflow archive preserves hidden receipts, incomplete attempts and packaging failures'
fixture_complete=true
