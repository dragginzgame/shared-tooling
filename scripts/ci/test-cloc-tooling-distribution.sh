#!/usr/bin/env bash
# Shared companions: scripts/ci/fixture-lifecycle.sh
set -euo pipefail
# Upstream integration only: consumers vendor test-cloc-tooling.sh instead.
ROOT="$0"
[[ "$ROOT" == /* ]] || ROOT="$PWD/$ROOT"
ROOT="$(cd -P "${ROOT%/*}/../.." && printf '%s/.' "$PWD")"
ROOT="${ROOT%/.}"
fixture="$(mktemp -d "${TMPDIR:-/tmp}/cloc-tooling-distribution.XXXXXX")"
# shellcheck source=scripts/ci/fixture-lifecycle.sh
source "$ROOT/scripts/ci/fixture-lifecycle.sh"
fixture_complete=false
trap 'fixture_finish "$?" "$fixture" "Failed tooling distribution fixture retained"' EXIT

# Export actual committed scripts, verify, then inventory the same bytes.
# Existing objects suffice; no fixture commits or network access are needed.
source_repo="$fixture/source"
export_parent="$fixture/exported"
consumer="$export_parent/consumer"
git clone -q --shared "$ROOT" "$source_repo"
source_version="$(git -C "$source_repo" show HEAD:VERSION)"
mkdir "$export_parent"
git clone -q --shared --no-checkout "$ROOT" "$consumer"
export_files=(scripts/ci/verify-file-checksum.sh scripts/ci/verify-shared-tooling-snapshot.sh scripts/ci/check-make-execution.sh)
git -C "$consumer" checkout HEAD -- "${export_files[@]}"
for source in https://github.com/dragginzgame/shared-tooling.git git@github.com:dragginzgame/shared-tooling.git ssh://git@github.com/dragginzgame/shared-tooling; do
    git -C "$source_repo" remote set-url origin "$source"
    rm -f "$consumer/config/.shared-tooling.snapshot"
    bash "$ROOT/scripts/distribution/refresh-consumer.sh" --source "$source_repo" \
        --consumer "$consumer" --manifest config/.shared-tooling.snapshot \
        --entrypoint "${export_files[0]}" --entrypoint "${export_files[1]}" --entrypoint "${export_files[2]}" > "$fixture/export.log"
    bash "$consumer/scripts/ci/verify-shared-tooling-snapshot.sh" --manifest config/.shared-tooling.snapshot > "$fixture/verify.log"
    perl "$ROOT/scripts/dev/cloc-tooling.pl" --json "$export_parent" > "$fixture/export.json"
    jq -e --arg version "$source_version" '.partial == false and .totals.shared_loc > 0 and .totals.local_loc == 0 and
      .repositories[0].snapshot_manifests[0].version == $version and
      .repositories[0].snapshot_manifests[0].integrity == "ok"' "$fixture/export.json" >/dev/null
done
mv "$consumer/config/.shared-tooling.snapshot" "$consumer/.shared-tooling.snapshot"
perl "$ROOT/scripts/dev/cloc-tooling.pl" --json "$export_parent" > "$fixture/export-root.json"
[[ "$(jq -c .totals "$fixture/export.json")" == "$(jq -c .totals "$fixture/export-root.json")" ]] || exit 1
# Export/verify a real dotted manifest with records overlapping the default.
# Its name must not require a special root option in the inventory.
git -C "$consumer" checkout HEAD -- scripts/ci/archive-evidence.sh
bash "$ROOT/scripts/distribution/refresh-consumer.sh" --source "$source_repo" \
    --consumer "$consumer" --manifest .shared-tooling.archives.snapshot \
    --entrypoint "${export_files[0]}" --entrypoint "${export_files[1]}" --entrypoint scripts/ci/archive-evidence.sh > "$fixture/dotted-export.log"
bash "$consumer/scripts/ci/verify-shared-tooling-snapshot.sh" --manifest .shared-tooling.archives.snapshot > "$fixture/dotted-verify.log"
perl "$ROOT/scripts/dev/cloc-tooling.pl" --json "$export_parent" > "$fixture/export-dotted.json"
jq -e '.partial == false and .totals.shared_loc > 0 and .totals.local_loc == 0 and
  (.repositories[0].snapshot_manifests | length) == 2' "$fixture/export-dotted.json" >/dev/null
# Return to the original bundle for the nested-root comparison below.
rm "$consumer/.shared-tooling.archives.snapshot" "$consumer/scripts/ci/archive-evidence.sh"
mkdir -p "$consumer/vendor/shared"
cp -Rp "$consumer/scripts" "$consumer/vendor/shared/"
cp "$consumer/.shared-tooling.snapshot" "$consumer/vendor/shared/"
bash "$consumer/vendor/shared/scripts/ci/verify-shared-tooling-snapshot.sh" > "$fixture/nested-verify.log"
perl "$ROOT/scripts/dev/cloc-tooling.pl" --json "$export_parent" > "$fixture/export-nested.json"
expected_shared="$(jq '.totals.shared_loc * 2' "$fixture/export-root.json")"
jq -e --argjson expected "$expected_shared" '.partial == false and .totals.shared_loc == $expected and .totals.local_loc == 0' "$fixture/export-nested.json" >/dev/null

# All readers reject the same malformed records, including empty tab fields.
# Only this disposable source receives a commit, to exercise a literal spaced path.
spaced_path='scripts/ci/ spaced helper .sh'
printf '#!/usr/bin/env bash\nprintf "fixture\\n"\n' > "$source_repo/$spaced_path"
git -C "$source_repo" add -- "$spaced_path"
git -C "$source_repo" -c core.hooksPath=/dev/null -c user.name=Fixture -c user.email=fixture@example.invalid \
    commit -qm 'Add spaced fixture path'
mkdir -p "$fixture/records/consumer"
records="$fixture/records/consumer"
git -C "$records" init -q
git -C "$records" remote add origin https://github.com/dragginzgame/snapshot-fixture.git
bash "$ROOT/scripts/distribution/refresh-consumer.sh" --source "$source_repo" --consumer "$records" \
    --entrypoint "${export_files[0]}" --entrypoint "${export_files[1]}" --entrypoint "$spaced_path" > "$fixture/records-export.log"
git -C "$records" add -- scripts .shared-tooling.snapshot
cp "$records/.shared-tooling.snapshot" "$fixture/valid.snapshot"
bash "$ROOT/scripts/ci/verify-shared-tooling-snapshot.sh" --consumer "$records" > "$fixture/records-verify.log"
bash "$ROOT/scripts/distribution/refresh-consumer.sh" --source "$source_repo" --consumer "$records" --preview > "$fixture/records-preview.log"
perl "$ROOT/scripts/dev/cloc-tooling.pl" --json "$fixture/records" > "$fixture/records.json"
jq -e '.partial == false' "$fixture/records.json" >/dev/null
for record in format source revision file '# version' '# entrypoint'; do
    for mutation in trailing empty extra leading; do
        perl -e '
            my ($kind, $mutation, $path) = @ARGV;
            open my $in, "<", $path or die $!;
            my $changed = 0;
            while (my $line = <$in>) {
                if (!$changed && index($line, "$kind\t") == 0) {
                    chomp $line;
                    $line .= "\t" if $mutation eq "trailing";
                    $line =~ s/\t/\t\t/ if $mutation eq "empty";
                    $line .= "\textra" if $mutation eq "extra";
                    $line = "\t$line" if $mutation eq "leading";
                    $line .= "\n";
                    $changed = 1;
                }
                print $line;
            }
            die "missing fixture record" unless $changed;
        ' "$record" "$mutation" "$fixture/valid.snapshot" > "$records/.shared-tooling.snapshot"
        cp "$records/.shared-tooling.snapshot" "$fixture/malformed.snapshot"
        if bash "$ROOT/scripts/ci/verify-shared-tooling-snapshot.sh" --consumer "$records" > "$fixture/malformed-verify.log" 2>&1; then
            echo "verifier accepted $record/$mutation" >&2; exit 1
        fi
        if bash "$ROOT/scripts/ci/verify-shared-tooling-snapshot.sh" --read-manifest "$records/.shared-tooling.snapshot" \
            > "$fixture/malformed-records.out" 2> "$fixture/malformed-records.log"; then
            echo "record reader accepted $record/$mutation" >&2; exit 1
        fi
        [[ ! -s "$fixture/malformed-records.out" ]] || exit 1
        if bash "$ROOT/scripts/distribution/refresh-consumer.sh" --source "$source_repo" --consumer "$records" --preview > "$fixture/malformed-refresh.log" 2>&1; then
            echo "refresh accepted $record/$mutation" >&2; exit 1
        fi
        if perl "$ROOT/scripts/dev/cloc-tooling.pl" --json "$fixture/records" > "$fixture/malformed-report.json" 2> "$fixture/malformed-report.log"; then
            echo "report accepted $record/$mutation" >&2; exit 1
        fi
        jq -e '.partial == true' "$fixture/malformed-report.json" >/dev/null
        cmp "$fixture/malformed.snapshot" "$records/.shared-tooling.snapshot"
    done
done
cp "$fixture/valid.snapshot" "$records/.shared-tooling.snapshot"

# Qualify the consumer fixture before commit, with only its declared companions
# present in the worktree. In particular there is no distribution helper.
adoption="$fixture/adoption"
git clone -q --shared --no-checkout "$ROOT" "$adoption"
mkdir -p "$adoption/scripts/ci" "$adoption/scripts/dev"
cp "$ROOT/scripts/ci/test-cloc-tooling.sh" "$ROOT/scripts/ci/verify-file-checksum.sh" "$ROOT/scripts/ci/fixture-lifecycle.sh" \
    "$ROOT/scripts/ci/verify-shared-tooling-snapshot.sh" "$adoption/scripts/ci/"
cp "$ROOT/scripts/dev/cloc-tooling.pl" "$adoption/scripts/dev/"
bash "$adoption/scripts/ci/test-cloc-tooling.sh" > "$fixture/adoption.log" 2>&1
echo 'Tooling LOC exporter integration and uncommitted consumer fixture passed'
fixture_complete=true
