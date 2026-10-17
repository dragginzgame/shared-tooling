#!/usr/bin/env bash
# Shared companions: scripts/ci/check-cargo-dependency-boundaries.sh scripts/ci/fixture-lifecycle.sh
set -euo pipefail
root=$(cd -- "$(dirname -- "$0")/../.." && pwd -P)
FIXTURE=$(mktemp -d "${TMPDIR:-/tmp}/cargo-boundaries.XXXXXX")
# shellcheck source=scripts/ci/fixture-lifecycle.sh
source "$root/scripts/ci/fixture-lifecycle.sh"
fixture_complete=false
trap 'fixture_finish "$?" "$FIXTURE" "Boundary fixture retained"' EXIT
mkdir -p "$FIXTURE/ci" "$FIXTURE/bin"
cat > "$FIXTURE/bin/cargo" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
[[ "$*" == 'metadata --no-deps --locked --format-version 1' ]]
[[ "$CARGO_NET_OFFLINE" == true && "$RUSTUP_AUTO_INSTALL" == 0 ]]
cat metadata.json
MOCK
chmod +x "$FIXTURE/bin/cargo"
export PATH="$FIXTURE/bin:$PATH"
cat > "$FIXTURE/metadata.json" <<'JSON'
{"workspace_members":["consumer"],"packages":[{"id":"consumer","name":"consumer","dependencies":[{"name":"substrate","rename":"hidden","kind":"dev","target":"cfg(windows)"}]}]}
JSON
printf '%s\n' '[{"dependency":"substrate","allowed_packages":["consumer"]}]' > "$FIXTURE/ci/cargo-dependency-boundaries.json"
bash "$root/scripts/ci/check-cargo-dependency-boundaries.sh" --consumer "$FIXTURE"
for policy in \
    '[{"dependency":"substrate","allowed_packages":[]}]' \
    '[{"dependency":"substrate","allowed_packages":["owner"]}]' \
    '[{"dependency":"substrate","allowed_packages":["consumer"],"typo":true}]' \
    '[{"dependency":"substrate","allowed_packages":"consumer"}]' \
    '[{"dependency":"substrate","allowed_packages":[]},{"dependency":"substrate","allowed_packages":["consumer"]}]' \
    '[{"dependency":"substrate","allowed_packages":["consumer","consumer"]}]' \
    '[]' '{' ; do
    printf '%s\n' "$policy" > "$FIXTURE/ci/cargo-dependency-boundaries.json"
    if bash "$root/scripts/ci/check-cargo-dependency-boundaries.sh" --consumer "$FIXTURE" > "$FIXTURE/output" 2>&1; then
        echo "incorrectly accepted policy: $policy" >&2
        exit 1
    fi
done
printf '%s\n' '[{"dependency":"different","allowed_packages":[]}]' > "$FIXTURE/ci/cargo-dependency-boundaries.json"
bash "$root/scripts/ci/check-cargo-dependency-boundaries.sh" --consumer "$FIXTURE"
fixture_complete=true
