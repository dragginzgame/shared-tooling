#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd -P)"
FIXTURE="$(mktemp -d "${TMPDIR:-/tmp}/shared-tooling-snapshot-test.XXXXXX")"
trap 'rm -rf "$FIXTURE"' EXIT

source_root="$FIXTURE/source"
consumer_root="$FIXTURE/consumer"
mkdir -p \
    "$source_root/scripts/ci" \
    "$source_root/scripts/distribution" \
    "$consumer_root" \
    "$FIXTURE/bin"

cp "$ROOT/scripts/ci/verify-file-checksum.sh" "$source_root/scripts/ci/"
cp "$ROOT/scripts/ci/verify-shared-tooling-snapshot.sh" "$source_root/scripts/ci/"
cp "$ROOT/scripts/distribution/refresh-consumer.sh" "$source_root/scripts/distribution/"
printf '#!/usr/bin/env bash\nprintf "sample tool\\n"\n' >"$source_root/scripts/ci/sample.sh"
chmod +x "$source_root/scripts/ci/sample.sh"

cat >"$FIXTURE/bin/git" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail

if [[ "$1" != "-C" || "$#" -lt 4 ]]; then
    exit 2
fi

repository="$2"
shift 2

case "$1:$2" in
rev-parse:--show-toplevel)
    printf '%s\n' "$repository"
    ;;
rev-parse:HEAD)
    printf '%s\n' 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
    ;;
status:--porcelain)
    if [[ "${SNAPSHOT_TEST_DIRTY:-}" == "true" ]]; then
        printf ' M scripts/ci/sample.sh\n'
    fi
    ;;
remote:get-url)
    printf '%s\n' 'git@github.com:dragginzgame/shared-tooling.git'
    ;;
*)
    exit 2
    ;;
esac
SCRIPT
chmod +x "$FIXTURE/bin/git"

if PATH="$FIXTURE/bin:$PATH" \
    bash "$source_root/scripts/distribution/refresh-consumer.sh" \
    --source "$source_root" \
    --consumer "$consumer_root" \
    --file scripts/ci/sample.sh >/dev/null 2>&1; then
    echo "snapshot distribution test failed: incomplete verifier set was accepted" >&2
    exit 1
fi
[[ ! -e "$consumer_root/.shared-tooling.snapshot" ]]
[[ ! -e "$consumer_root/scripts/ci/sample.sh" ]]

if ! PATH="$FIXTURE/bin:$PATH" \
    bash "$source_root/scripts/distribution/refresh-consumer.sh" \
    --source "$source_root" \
    --consumer "$consumer_root" \
    --file scripts/ci/verify-file-checksum.sh \
    --file scripts/ci/verify-shared-tooling-snapshot.sh \
    --file scripts/ci/sample.sh >"$FIXTURE/initial-refresh.log" 2>&1; then
    cat "$FIXTURE/initial-refresh.log" >&2
    exit 1
fi

bash "$consumer_root/scripts/ci/verify-shared-tooling-snapshot.sh" \
    --consumer "$consumer_root" >/dev/null

printf '# drift\n' >>"$consumer_root/scripts/ci/sample.sh"
if bash "$consumer_root/scripts/ci/verify-shared-tooling-snapshot.sh" \
    --consumer "$consumer_root" >/dev/null 2>&1; then
    echo "snapshot distribution test failed: consumer drift was accepted" >&2
    exit 1
fi

PATH="$FIXTURE/bin:$PATH" \
    bash "$source_root/scripts/distribution/refresh-consumer.sh" \
    --source "$source_root" \
    --consumer "$consumer_root" >/dev/null
bash "$consumer_root/scripts/ci/verify-shared-tooling-snapshot.sh" \
    --consumer "$consumer_root" >/dev/null

chmod -x "$consumer_root/scripts/ci/sample.sh"
if bash "$consumer_root/scripts/ci/verify-shared-tooling-snapshot.sh" \
    --consumer "$consumer_root" >/dev/null 2>&1; then
    echo "snapshot distribution test failed: executable-mode drift was accepted" >&2
    exit 1
fi
chmod +x "$consumer_root/scripts/ci/sample.sh"

if SNAPSHOT_TEST_DIRTY=true PATH="$FIXTURE/bin:$PATH" \
    bash "$source_root/scripts/distribution/refresh-consumer.sh" \
    --source "$source_root" \
    --consumer "$consumer_root" >/dev/null 2>&1; then
    echo "snapshot distribution test failed: dirty source was accepted" >&2
    exit 1
fi

echo "snapshot distribution test passed"
