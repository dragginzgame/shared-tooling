#!/usr/bin/env bash
# Shared companions: scripts/ci/wait-for-artifact.sh
set -euo pipefail
ROOT="$0"
[[ "$ROOT" == /* ]] || ROOT="$PWD/$ROOT"
ROOT="$(cd -P "${ROOT%/*}/../.." && printf '%s/.' "$PWD")"
ROOT="${ROOT%/.}"
fixture="$(mktemp -d "${TMPDIR:-/tmp}/artifact-discovery.XXXXXX")"
fixture_complete=false
finish() {
    local status=$?
    [[ "$fixture_complete" == true || "$status" != 0 ]] || status=1
    if [[ "$status" == 0 ]]; then rm -rf "$fixture"
    else printf 'Artifact discovery fixture retained: %s\n' "$fixture" >&2; fi
    exit "$status"
}
trap finish EXIT
mkdir "$fixture/bin"
cat > "$fixture/bin/gh" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
# Every retry must retain the authenticated read-only repository/run selection.
[[ "$*" == 'api --hostname github.com --method GET --paginate repos/owner/repo/actions/runs/42/artifacts?per_page=100' && "$GH_TOKEN" == fixture-token ]] || exit 90
count="$(cat "$PROBE/count")"
count=$((count + 1))
printf '%s\n' "$count" > "$PROBE/count"
[[ "$MODE" != api-error ]] || exit 23
if [[ "$count" -lt "$VISIBLE_AT" ]]; then
    # A same-name artifact from a prior attempt is never an acceptable substitute.
    printf '{"artifacts":[{"id":6,"name":"evidence","expired":false,"workflow_run":{"id":42}}]}\n'
else
    cat "$PROBE/response"
fi
SCRIPT
cat > "$fixture/bin/sleep" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$PROBE/sleeps"
SCRIPT
chmod +x "$fixture/bin/gh" "$fixture/bin/sleep"
export PATH="$fixture/bin:$PATH" GH_TOKEN=fixture-token
export PROBE MODE VISIBLE_AT
valid='{"id":7,"name":"evidence","expired":false,"workflow_run":{"id":42}}'
for scenario in immediate delayed last missing expired wrong-run duplicate malformed missing-array null-record empty api-error; do
    PROBE="$fixture/$scenario"
    mkdir "$PROBE"
    printf '0\n' > "$PROBE/count"
    : > "$PROBE/sleeps"
    MODE="$scenario"
    VISIBLE_AT=1
    expected_reads=1
    expected_status=0
    # gh --paginate emits a stream of complete JSON pages; the exact ID may
    # occur only on a later page. Admission must parse all pages successfully.
    printf '{"artifacts":[]}\n{"artifacts":[%s]}\n' "$valid" > "$PROBE/response"
    case "$scenario" in
        delayed) VISIBLE_AT=3; expected_reads=3 ;;
        last) VISIBLE_AT=6; expected_reads=6 ;;
        missing) VISIBLE_AT=7; expected_reads=6; expected_status=1 ;;
        expired) sed 's/false/true/' "$PROBE/response" > "$PROBE/changed"; mv "$PROBE/changed" "$PROBE/response"; expected_status=error ;;
        wrong-run) sed 's/42/43/' "$PROBE/response" > "$PROBE/changed"; mv "$PROBE/changed" "$PROBE/response"; expected_status=error ;;
        duplicate) printf '{"artifacts":[%s,%s]}\n' "$valid" "$valid" > "$PROBE/response"; expected_status=error ;;
        malformed) printf 'invalid-json\n' >> "$PROBE/response"; expected_status=error ;;
        missing-array) printf '{}\n' > "$PROBE/response"; expected_status=error ;;
        null-record) printf '{"artifacts":[null]}\n' > "$PROBE/response"; expected_status=error ;;
        empty) : > "$PROBE/response"; expected_status=error ;;
        api-error) expected_status=23 ;;
    esac
    status=0
    bash "$ROOT/scripts/ci/wait-for-artifact.sh" owner/repo 42 7 > "$PROBE/log" 2>&1 || status=$?
    # Schema/parser failures must fail; the API's failure status must survive.
    if [[ "$expected_status" == error ]]; then [[ "$status" != 0 ]] || exit 1
    else [[ "$status" == "$expected_status" ]] || { cat "$PROBE/log" >&2; exit 1; }; fi
    [[ "$(cat "$PROBE/count")" == "$expected_reads" ]] || exit 1
    case "$expected_reads" in
        1) [[ ! -s "$PROBE/sleeps" ]] || exit 1 ;;
        3) [[ "$(cat "$PROBE/sleeps")" == $'2\n4' ]] || exit 1 ;;
        6) [[ "$(cat "$PROBE/sleeps")" == $'2\n4\n8\n16\n30' ]] || exit 1 ;;
    esac
done
# Invalid selections and missing credentials must fail before any API request.
printf '0\n' > "$PROBE/count"
for identity in '' 0 -1 7,8 $'7\n'; do
    if bash "$ROOT/scripts/ci/wait-for-artifact.sh" owner/repo 42 "$identity" > "$PROBE/refusal" 2>&1; then exit 1; fi
done
if GH_TOKEN='' bash "$ROOT/scripts/ci/wait-for-artifact.sh" owner/repo 42 7 > "$PROBE/refusal" 2>&1; then exit 1; fi
[[ "$(cat "$PROBE/count")" == 0 ]] || exit 1

# Live workflow invariants: both downloads require their discovery's success,
# retain the same upload ID/repository/run, and fail on digest mismatches.
yq -o=json '.jobs.portable-regression.steps' "$ROOT/.github/workflows/ci.yml" > "$fixture/steps.json"
jq -e '
    [.[] | select((.uses // "") | startswith("actions/download-artifact@"))] as $downloads
    | ($downloads | length) == 2 and all($downloads[];
        . as $download
        | (.with["artifact-ids"] | contains("retention-upload")) as $full
        | (if $full then "retention-discovery" else "compact-discovery" end) as $gate
        | $download.if == ("${{ !cancelled() && steps." + $gate + ".outcome == '\''success'\'' }}")
          and $download.with["digest-mismatch"] == "error"
          and $download.with.repository == "${{ github.repository }}"
          and $download.with["run-id"] == "${{ github.run_id }}"
          and ($download["continue-on-error"] // false) == false
    )
' "$fixture/steps.json" > /dev/null
for gate in retention compact; do
    jq -e --arg id "$gate-discovery" --arg upload "$gate-upload" '
        .[] | select(.id == $id)
        | .["timeout-minutes"] == 2 and (."continue-on-error" // false) == false
          and .env.EVIDENCE_REPOSITORY == "${{ github.repository }}"
          and .env.EVIDENCE_RUN == "${{ github.run_id }}"
          and .env.EVIDENCE_ARTIFACT == ("${{ steps." + $upload + ".outputs.artifact-id }}")
          and .env.GH_TOKEN == "${{ github.token }}"
    ' "$fixture/steps.json" > /dev/null
done
echo 'Artifact discovery recovery, exhaustion, identity and workflow gates passed'
fixture_complete=true
