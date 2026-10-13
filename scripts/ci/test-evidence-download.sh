#!/usr/bin/env bash
# Shared companions: scripts/ci/download-evidence.sh
set -euo pipefail
ROOT="$0"; [[ "$ROOT" == /* ]] || ROOT="$PWD/$ROOT"
ROOT="$(cd -P "${ROOT%/*}/../.." && printf '%s/.' "$PWD")"; ROOT="${ROOT%/.}"
fixture="$(mktemp -d "${TMPDIR:-/tmp}/evidence-download.XXXXXX")"
fixture_complete=false
finish() {
    local status=$?
    [[ "$fixture_complete" == true || "$status" != 0 ]] || status=1
    if [[ "$status" == 0 ]]; then rm -rf "$fixture"; else echo "Download fixtures retained: $fixture" >&2; fi
    exit "$status"
}
trap finish EXIT
mkdir "$fixture/bin" "$fixture/payload"
printf 'retained evidence\n' > "$fixture/payload/evidence.tar.gz"
(cd "$fixture/payload" && zip -q "$fixture/artifact.zip" evidence.tar.gz)
digest="$(bash "$ROOT/scripts/ci/verify-file-checksum.sh" --print sha256 "$fixture/artifact.zip")"
cat > "$fixture/bin/gh" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
[[ "$GH_TOKEN" == fixture-token && "$1 $2 $3 $4 $5" == 'api --hostname github.com --method GET' ]] || exit 90
printf '%s\n' "$6" >> "$PROBE/calls"
case "$6" in
    repos/owner/repo/actions/artifacts/7)
        count="$(cat "$PROBE/count")"; count=$((count + 1)); echo "$count" > "$PROBE/count"
        case "$MODE" in
            missing) echo 'gh: Not Found (HTTP 404)' >&2; exit 1 ;;
            auth) echo 'gh: Bad credentials (HTTP 401)' >&2; exit 1 ;;
            transport) echo 'transport failed' >&2; exit 23 ;;
        esac
        cat "$PROBE/metadata" ;;
    repos/owner/repo/actions/artifacts/7/zip)
        case "$MODE" in
            download-missing) echo 'gh: Not Found (HTTP 404)' >&2; exit 1 ;;
            download-auth) echo 'gh: Forbidden (HTTP 403)' >&2; exit 1 ;;
        esac
        if [[ "$MODE" == delayed && "$(cat "$PROBE/count")" -lt 3 ]]; then
            echo 'gh: Not Found (HTTP 404)' >&2; exit 1
        fi
        if [[ "$MODE" == corrupt ]]; then printf corrupt; else cat "$ARCHIVE"; fi ;;
    *) exit 91 ;;
esac
SCRIPT
cat > "$fixture/bin/sleep" <<'SCRIPT'
#!/usr/bin/env bash
printf '%s\n' "$1" >> "$PROBE/sleeps"
SCRIPT
chmod +x "$fixture/bin/"*
export PATH="$fixture/bin:$PATH" GH_TOKEN=fixture-token
export PROBE MODE ARCHIVE="$fixture/artifact.zip"
for MODE in immediate delayed missing download-missing auth download-auth transport malformed wrong-run expired wrong-digest corrupt members; do
    PROBE="$fixture/$MODE"; mkdir "$PROBE"
    echo 0 > "$PROBE/count"; : > "$PROBE/calls"; : > "$PROBE/sleeps"
    selected_digest="$digest"
    printf '{"id":7,"workflow_run":{"id":42},"expired":false,"digest":"sha256:%s"}\n' "$digest" > "$PROBE/metadata"
    case "$MODE" in
        malformed) echo invalid > "$PROBE/metadata" ;;
        wrong-run) sed 's/42/43/' "$PROBE/metadata" > "$PROBE/new"; mv "$PROBE/new" "$PROBE/metadata" ;;
        expired) sed 's/false/true/' "$PROBE/metadata" > "$PROBE/new"; mv "$PROBE/new" "$PROBE/metadata" ;;
        wrong-digest) selected_digest="$(printf '%064d' 0)" ;;
        members)
            printf extra > "$fixture/payload/extra"
            (cd "$fixture/payload" && zip -q "$fixture/extra.zip" evidence.tar.gz extra)
            ARCHIVE="$fixture/extra.zip"
            selected_digest="$(bash "$ROOT/scripts/ci/verify-file-checksum.sh" --print sha256 "$ARCHIVE")"
            sed "s/$digest/$selected_digest/" "$PROBE/metadata" > "$PROBE/new"; mv "$PROBE/new" "$PROBE/metadata" ;;
    esac
    status=0
    bash "$ROOT/scripts/ci/download-evidence.sh" owner/repo 42 7 "$selected_digest" "$PROBE/result" > "$PROBE/log" 2>&1 || status=$?
    case "$MODE" in
        immediate|delayed)
            [[ "$status" == 0 ]] || { cat "$PROBE/log"; exit 1; }
            cmp "$fixture/payload/evidence.tar.gz" "$PROBE/result/evidence.tar.gz" ;;
        *) [[ "$status" != 0 && ! -e "$PROBE/result/evidence.tar.gz" ]] || exit 1 ;;
    esac
    case "$MODE" in
        delayed) [[ "$(cat "$PROBE/count")" == 3 && "$(cat "$PROBE/sleeps")" == $'2\n4' ]] || exit 1 ;;
        missing|download-missing) [[ "$(cat "$PROBE/count")" == 6 && "$(cat "$PROBE/sleeps")" == $'2\n4\n8\n16\n30' ]] || exit 1 ;;
        *) [[ "$(cat "$PROBE/count")" == 1 && ! -s "$PROBE/sleeps" ]] || exit 1 ;;
    esac
    [[ "$MODE" != transport || "$status" == 23 ]] || exit 1
done
# Admission errors cannot contact GitHub or overwrite existing evidence.
: > "$PROBE/calls"
for id in '' 0 -1 7,8 $'7\n'; do
    if bash "$ROOT/scripts/ci/download-evidence.sh" owner/repo 42 "$id" "$digest" "$fixture/refused" > /dev/null 2>&1; then exit 1; fi
done
if GH_TOKEN='' bash "$ROOT/scripts/ci/download-evidence.sh" owner/repo 42 7 "$digest" "$fixture/refused" > /dev/null 2>&1; then exit 1; fi
if bash "$ROOT/scripts/ci/download-evidence.sh" owner/repo 42 7 "$digest" "$PROBE/result" > /dev/null 2>&1; then exit 1; fi
[[ ! -s "$PROBE/calls" && ! -e "$fixture/refused" ]] || exit 1
# Both hosted readbacks bind ID and digest to the same upload and current run.
yq -o=json '.jobs.portable-regression.steps' "$ROOT/.github/workflows/ci.yml" > "$fixture/steps.json"
for kind in retention compact; do
    jq -e --arg kind "$kind" '
        .[] | select((.run // "") | startswith("bash scripts/ci/download-evidence.sh"))
        | select(.env.EVIDENCE_ARTIFACT == ("${{ steps." + $kind + "-upload.outputs.artifact-id }}"))
        | .env.EVIDENCE_DIGEST == ("${{ steps." + $kind + "-upload.outputs.artifact-digest }}") and
          .env.EVIDENCE_REPOSITORY == "${{ github.repository }}" and
          .env.EVIDENCE_RUN == "${{ github.run_id }}" and
          .env.GH_TOKEN == "${{ github.token }}" and .["timeout-minutes"] == 3 and
          (."continue-on-error" // false) == false
    ' "$fixture/steps.json" >/dev/null
done
fixture_complete=true
echo 'Exact evidence download recovery, identity, digest and refusal checks passed'
