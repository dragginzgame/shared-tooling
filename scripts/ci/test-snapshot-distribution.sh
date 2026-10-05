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

# Freeze the fake revision independently of the source working tree.
revision_root="$FIXTURE/revision"
mkdir -p "$revision_root"
cp -Rp "$source_root/scripts" "$revision_root/"

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
ls-tree:-z)
    path="$5"
    committed_file="$SNAPSHOT_TEST_REVISION_ROOT/$path"
    if [[ -f "$committed_file" ]]; then
        mode=100644
        [[ ! -x "$committed_file" ]] || mode=100755
        printf '%s blob bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\t%s\0' "$mode" "$path"
    fi
    ;;
cat-file:blob)
    path="${3#*:}"
    if [[ "${SNAPSHOT_TEST_SOURCE_DRIFT:-}" == "true" && "$path" == "scripts/ci/sample.sh" ]]; then
        printf '# concurrent source edit\n' >>"$repository/$path"
        chmod -x "$repository/$path"
    fi
    cat "$SNAPSHOT_TEST_REVISION_ROOT/$path"
    ;;
*)
    exit 2
    ;;
esac
SCRIPT
chmod +x "$FIXTURE/bin/git"
export SNAPSHOT_TEST_REVISION_ROOT="$revision_root"

printf 'ignored working-tree content\n' >"$source_root/ignored.txt"
if PATH="$FIXTURE/bin:$PATH" \
    bash "$source_root/scripts/distribution/refresh-consumer.sh" \
    --source "$source_root" \
    --consumer "$consumer_root" \
    --file scripts/ci/verify-file-checksum.sh \
    --file scripts/ci/verify-shared-tooling-snapshot.sh \
    --file ignored.txt >/dev/null 2>&1; then
    echo "snapshot distribution test failed: a file absent from the source revision was accepted" >&2
    exit 1
fi
[[ ! -e "$consumer_root/.shared-tooling.snapshot" ]]
[[ ! -e "$consumer_root/scripts" ]]
[[ ! -e "$consumer_root/ignored.txt" ]]

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

if ! SNAPSHOT_TEST_SOURCE_DRIFT=true PATH="$FIXTURE/bin:$PATH" \
    bash "$source_root/scripts/distribution/refresh-consumer.sh" \
    --source "$source_root" \
    --consumer "$consumer_root" \
    --file scripts/ci/verify-file-checksum.sh \
    --file scripts/ci/verify-shared-tooling-snapshot.sh \
    --file scripts/ci/sample.sh >"$FIXTURE/initial-refresh.log" 2>&1; then
    cat "$FIXTURE/initial-refresh.log" >&2
    exit 1
fi

cmp "$revision_root/scripts/ci/sample.sh" "$consumer_root/scripts/ci/sample.sh"
[[ -x "$consumer_root/scripts/ci/sample.sh" ]]
[[ ! -x "$source_root/scripts/ci/sample.sh" ]]
if cmp -s "$source_root/scripts/ci/sample.sh" "$consumer_root/scripts/ci/sample.sh"; then
    echo "snapshot distribution test failed: concurrent source drift reached the consumer" >&2
    exit 1
fi

bash "$consumer_root/scripts/ci/verify-shared-tooling-snapshot.sh" \
    --consumer "$consumer_root" >/dev/null

cp "$consumer_root/.shared-tooling.snapshot" "$consumer_root/duplicate.snapshot"
awk '$1 == "file" { print; exit }' "$consumer_root/.shared-tooling.snapshot" \
    >>"$consumer_root/duplicate.snapshot"
if bash "$consumer_root/scripts/ci/verify-shared-tooling-snapshot.sh" \
    --consumer "$consumer_root" --manifest duplicate.snapshot \
    >"$FIXTURE/duplicate.log" 2>&1; then
    echo "snapshot distribution test failed: duplicate file record was accepted" >&2
    exit 1
fi
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

# A custom manifest can create its own parent directories on the first refresh.
nested_consumer="$FIXTURE/nested consumer"
mkdir -p "$nested_consumer"
PATH="$FIXTURE/bin:$PATH" \
    bash "$source_root/scripts/distribution/refresh-consumer.sh" \
    --source "$source_root" --consumer "$nested_consumer" \
    --manifest 'config/shared tools/snapshot' \
    --file scripts/ci/verify-file-checksum.sh \
    --file scripts/ci/verify-shared-tooling-snapshot.sh >/dev/null
PATH="$FIXTURE/bin:$PATH" \
    bash "$source_root/scripts/distribution/refresh-consumer.sh" \
    --source "$source_root" --consumer "$nested_consumer" \
    --manifest 'config/shared tools/snapshot' >/dev/null
bash "$nested_consumer/scripts/ci/verify-shared-tooling-snapshot.sh" \
    --consumer "$nested_consumer" --manifest 'config/shared tools/snapshot' >/dev/null

# Failure to create that parent must precede any snapshot file replacement.
blocked_consumer="$FIXTURE/blocked-consumer"
mkdir -p "$blocked_consumer/scripts/ci"
printf 'consumer-owned contents\n' >"$blocked_consumer/scripts/ci/verify-file-checksum.sh"
cp "$blocked_consumer/scripts/ci/verify-file-checksum.sh" "$FIXTURE/original-checksum.sh"
printf 'not a directory\n' >"$blocked_consumer/config"
if PATH="$FIXTURE/bin:$PATH" \
    bash "$source_root/scripts/distribution/refresh-consumer.sh" \
    --source "$source_root" --consumer "$blocked_consumer" \
    --manifest config/shared.snapshot \
    --file scripts/ci/verify-file-checksum.sh \
    --file scripts/ci/verify-shared-tooling-snapshot.sh >/dev/null 2>&1; then
    echo "snapshot distribution test failed: a blocked manifest parent was accepted" >&2
    exit 1
fi
cmp "$FIXTURE/original-checksum.sh" "$blocked_consumer/scripts/ci/verify-file-checksum.sh"
[[ ! -e "$blocked_consumer/scripts/ci/verify-shared-tooling-snapshot.sh" ]]

echo "snapshot distribution test passed"
