#!/usr/bin/env bash
set -euo pipefail

# Opt-in paired export measurements for #219; no installs, commits or network.
[[ $# == 4 ]] || { echo 'usage: measure-snapshot-refresh.sh BEFORE-SHA AFTER-SHA PAYLOAD-SHA NEW-EVIDENCE-DIRECTORY' >&2; exit 2; }
before="$1" after="$2" payload="$3" selected="$4"
for revision in "$before" "$after" "$payload"; do
    [[ "$revision" =~ ^[0-9a-f]{40}$ ]] || { echo 'select full lowercase commit identities' >&2; exit 2; }
done
ROOT="${BASH_SOURCE[0]}"
[[ "$ROOT" == /* ]] || ROOT="$PWD/$ROOT"
case "$ROOT:$selected" in *$'\n'*|*$'\r'*) echo 'paths contain CR/LF' >&2; exit 2 ;; esac
ROOT="$(cd -P "${ROOT%/*}/../.." && printf '%s/.' "$PWD")"
ROOT="${ROOT%/.}"
[[ "$selected" == /* ]] || selected="$PWD/$selected"
parent="$(cd -P "${selected%/*}" && printf '%s/.' "$PWD")"
selected="${parent%/.}/${selected##*/}"
case "$ROOT:$selected" in *$'\n'*|*$'\r'*) echo 'resolved paths contain CR/LF' >&2; exit 2 ;; esac
[[ ! -e "$selected" && ! -L "$selected" ]] || { echo 'evidence destination already exists' >&2; exit 2; }
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR
for revision in "$before" "$after" "$payload"; do
    kind="$(git -C "$ROOT" cat-file -t "$revision")"
    [[ "$kind" == commit ]] || exit 2
done
mkdir "$selected"
complete=false
finish() {
    local status=$?
    [[ "$complete" == true || "$status" != 0 ]] || status=1
    printf 'Snapshot comparison evidence retained: %s\n' "$selected" >&2
    exit "$status"
}
trap finish EXIT
runner_path=scripts/distribution/refresh-consumer.sh
mkdir -p "$selected/before/scripts/distribution" "$selected/after/scripts/distribution"
# Never execute a partial failed Git observation, even if it resembles a script.
git -C "$ROOT" show "$before:$runner_path" > "$selected/before/$runner_path"
git -C "$ROOT" show "$after:$runner_path" > "$selected/after/$runner_path"
harness_commit="$(git -C "$ROOT" rev-parse HEAD)"
harness_blob="$(git hash-object "$ROOT/scripts/distribution/measure-snapshot-refresh.sh")"
harness_state="$(git -C "$ROOT" status --porcelain --untracked-files=all -- scripts/distribution/measure-snapshot-refresh.sh)"
before_blob="$(git -C "$ROOT" rev-parse "$before:$runner_path")"
after_blob="$(git -C "$ROOT" rev-parse "$after:$runner_path")"
{
    printf 'checkout_commit\t%s\n' "$harness_commit"
    printf 'harness_blob\t%s\n' "$harness_blob"
    printf 'harness_worktree\t%s\n' "${harness_state:-clean}"
    printf 'before_commit\t%s\nafter_commit\t%s\npayload_commit\t%s\n' "$before" "$after" "$payload"
    printf 'before_blob\t%s\n' "$before_blob"
    printf 'after_blob\t%s\n' "$after_blob"
    printf 'entrypoint\t%s\n' "$runner_path" scripts/dev/install-rust-tools.sh scripts/ci/run-release.sh
    uname -a
    printf 'selected_bash\t%s\n' "$BASH"
    printf 'PATH\t%s\n' "$PATH"
    command -v git perl bash diff
    git --version
    "$BASH" --version
    bash --version
    perl -V:version
    if command -v sha256sum >/dev/null 2>&1; then
        command -v sha256sum
        sha256sum --version
    else
        command -v shasum
        shasum --version
    fi
} > "$selected/identities.txt"
# One clean committed payload and identical tool selection serve both runners.
git clone --quiet --no-hardlinks --no-checkout "$ROOT" "$selected/source" > "$selected/source.log" 2>&1
git -C "$selected/source" checkout --quiet --detach "$payload" >> "$selected/source.log" 2>&1
git -C "$selected/source" remote set-url origin https://github.com/dragginzgame/shared-tooling
# Freeze runner-local helpers with the payload too. Only the selected exporter
# blob varies; do not introduce unrecorded working-tree code. Historical payloads
# without the declaration reader still support their self-contained exporters.
helpers=(verify-file-checksum.sh verify-shared-tooling-snapshot.sh)
reader="$(git -C "$ROOT" ls-tree --name-only "$payload" -- scripts/ci/shared-companions.sh)"
[[ -z "$reader" ]] || helpers+=(shared-companions.sh)
for helper in "${helpers[@]}"; do
    blob="$(git -C "$ROOT" rev-parse "$payload:scripts/ci/$helper")"
    printf 'integrity_blob\t%s\t%s\n' "$helper" "$blob" >> "$selected/identities.txt"
    for side in before after; do
        mkdir -p "$selected/$side/scripts/ci"
        git -C "$ROOT" show "$payload:scripts/ci/$helper" > "$selected/$side/scripts/ci/$helper"
    done
done
printf 'phase\tpair\tside\tseconds\n' > "$selected/samples.tsv"
sample() {
    local phase="$1" pair="$2" side="$3" label consumer elapsed
    label="$phase-$pair-$side"
    consumer="$selected/consumer-$label"
    mkdir "$consumer"
    git init -q "$consumer"
    # Monotonic timing covers only the real exporter process, excluding clone,
    # consumer initialization, verification and the comparison harness startup.
    perl -MTime::HiRes=clock_gettime,CLOCK_MONOTONIC -MPOSIX=WIFEXITED,WEXITSTATUS -e '
        my $output = shift @ARGV;
        open my $seconds, ">", $output or die "open timing: $!\n";
        my $start = clock_gettime(CLOCK_MONOTONIC);
        system @ARGV;
        my $status = $?;
        my $elapsed = clock_gettime(CLOCK_MONOTONIC) - $start;
        die "exporter did not exit normally (wait=$status)\n" if $status == -1 || !WIFEXITED($status);
        exit WEXITSTATUS($status) if WEXITSTATUS($status);
        die "invalid elapsed time\n" unless $elapsed > 0;
        printf {$seconds} "%.9f\n", $elapsed or die "write timing: $!\n";
        close $seconds or die "close timing: $!\n";
    ' "$selected/$label.seconds" "$BASH" "$selected/$side/$runner_path" \
        --source "$selected/source" --consumer "$consumer" \
        --entrypoint "$runner_path" --entrypoint scripts/dev/install-rust-tools.sh \
        --entrypoint scripts/ci/run-release.sh > "$selected/$label.log" 2>&1
    "$BASH" "$selected/source/scripts/ci/verify-shared-tooling-snapshot.sh" \
        --consumer "$consumer" > "$selected/$label.verify.log" 2>&1
    elapsed="$(cat "$selected/$label.seconds")"
    [[ "$elapsed" =~ ^[0-9]+\.[0-9]+$ ]] || exit 1
    printf '%s\t%s\t%s\t%s\n' "$phase" "$pair" "$side" "$elapsed" >> "$selected/samples.tsv"
}
for pair in 0 1 2 3 4 5 6; do
    phase=measurement
    [[ "$pair" != 0 ]] || phase=warmup
    if (( pair % 2 == 0 )); then order=(before after); else order=(after before); fi
    for side in "${order[@]}"; do sample "$phase" "$pair" "$side"; done
    # Compare receipt and payload bytes; each verifier separately admits modes.
    diff -r -x .git "$selected/consumer-$phase-$pair-before" "$selected/consumer-$phase-$pair-after" \
        > "$selected/$phase-$pair.compare.log" 2>&1
done
cat "$selected/samples.tsv"
printf 'All paired payloads and receipts match; inspect samples.tsv without inferring a whole-suite speedup.\n' > "$selected/completion.tmp"
mv "$selected/completion.tmp" "$selected/complete.txt"
complete=true
