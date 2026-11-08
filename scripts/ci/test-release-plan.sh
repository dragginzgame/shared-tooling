#!/usr/bin/env bash
# Shared companions: scripts/ci/release-plan.pl scripts/ci/fixture-lifecycle.sh
set -euo pipefail
ROOT="$(cd "${BASH_SOURCE[0]%/*}/../.." && pwd -P)"
mkdir -p "$ROOT/target/tmp"
fixture="$(mktemp -d "$ROOT/target/tmp/release-plan.XXXXXX")"
# shellcheck source=scripts/ci/fixture-lifecycle.sh
source "$ROOT/scripts/ci/fixture-lifecycle.sh"
fixture_complete=false
trap 'fixture_finish "$?" "$fixture" "Release-plan query fixture retained"' EXIT
mkdir -p "$fixture/work/.git/release-state/lock" "$fixture/bin"
printf 'occupied lock\n' > "$fixture/work/.git/release-state/lock/owner"
export PLAN_QUERY_REAL_GIT PLAN_QUERY_EFFECTS
PLAN_QUERY_REAL_GIT="$(command -v git)"
PLAN_QUERY_EFFECTS="$fixture/effects"
cat > "$fixture/bin/git" <<'GIT'
#!/usr/bin/env bash
if [[ $# == 2 && "$1" == check-ref-format ]]; then exec "$PLAN_QUERY_REAL_GIT" "$@"; fi
printf 'git %s\n' "$*" >> "$PLAN_QUERY_EFFECTS"
exit 98
GIT
for tool in make cargo curl gh; do
    # shellcheck disable=SC2016 # The fixture command reads this exported variable at runtime.
    printf '#!/bin/sh\nprintf "unexpected command\\n" >> "$PLAN_QUERY_EFFECTS"\nexit 98\n' > "$fixture/bin/$tool"
done
chmod +x "$fixture/bin/"*
export PATH="$fixture/bin:$PATH"
cd "$fixture/work"
plan="$PWD/.git/release-state/retained.plan"
query() { perl "$ROOT/scripts/ci/release-plan.pl" --plan "$plan" --group "$group" --version 0.2.0; }
reject() {
    cp "$plan" "$fixture/before.plan"
    if query > "$fixture/output" 2> "$fixture/error"; then echo 'invalid release journal accepted' >&2; exit 1; fi
    [[ ! -s "$fixture/output" ]]
    cmp "$plan" "$fixture/before.plan"
}
for schema in release-plan-1 release-pr-plan-1 release-group-plan-1 release-group-pr-plan-1; do
    group=''; case "$schema" in release-group-*) group=engine ;; esac
    phases='preflight validate prepare stage commit complete'
    case "$schema" in *pr*) phases="$phases pr-publish pr-review pr-validate pr-tag pr-push" ;; *) phases="$phases tag push" ;; esac
    for phase in $phases; do
        printf '%s\n' "$schema" minor 0.1.9 0.2.0 2024-02-29 \
            aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa origin release/main \
            bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb '' "$phase" > "$plan"
        [[ -z "$group" ]] || printf '%s\n' "$group" >> "$plan"
        cp "$plan" "$fixture/before.plan"
        query > "$fixture/output"
        jq -e --arg schema "$schema" --arg phase "$phase" --arg group "$group" \
            '.schema==$schema and .phase==$phase and .group==$group and .candidate=="0.2.0" and .source=="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"' "$fixture/output" >/dev/null
        cmp "$plan" "$fixture/before.plan"
    done
done
cp "$plan" "$fixture/valid.plan"
# Invalid values, unknown schemas, cross-delivery phases and embedded control bytes.
for change in '1 unknown-schema' '2 bogus' '3 00.1.9' '4 0.3.0' '5 2023-02-29' \
    '6 short' '7 bad/remote' '8 bad..branch' '9 BAD' '10 short' '11 push' '12 wrong'; do
    read -r line value <<< "$change"
    awk -v line="$line" -v value="$value" 'NR==line {$0=value} {print}' "$fixture/valid.plan" > "$plan"
    reject
done
for cut in 1 5 10 11; do head -n "$cut" "$fixture/valid.plan" > "$plan"; reject; done
cp "$fixture/valid.plan" "$plan"; printf '\n' >> "$plan"; reject
cp "$fixture/valid.plan" "$plan"; printf extra >> "$plan"; reject
perl -pe 's/engine/eng\x00ine/' "$fixture/valid.plan" > "$plan"; reject
perl -pe 's/\n/\r\n/' "$fixture/valid.plan" > "$plan"; reject
perl -0pe 'chop' "$fixture/valid.plan" > "$plan"; reject
cp "$fixture/valid.plan" "$plan"
group=''; reject; group=engine
# SHA-256 object identities are retained without truncation.
perl -pe 's/^a{40}$/"a" x 64/e; s/^b{40}$/"b" x 64/e' "$fixture/valid.plan" > "$plan"
query > "$fixture/output"
jq -e '(.source|length)==64' "$fixture/output" >/dev/null
# Missing files and symlinks (including ancestors) never produce a projection.
rm "$plan"
if query > "$fixture/output" 2> "$fixture/error"; then exit 1; fi
[[ ! -s "$fixture/output" ]]
ln -s "$fixture/valid.plan" "$plan"; reject; rm "$plan"
ln -s "$fixture/work/.git/release-state" "$fixture/link"
cp "$fixture/valid.plan" "$fixture/work/.git/release-state/retained.plan"
plan="$fixture/link/retained.plan"; reject
# The query neither acquires/removes the occupied lock nor creates other state.
[[ ! -e "$fixture/effects" ]]
printf 'occupied lock\n' > "$fixture/owner"
cmp "$fixture/owner" "$fixture/work/.git/release-state/lock/owner"
[[ "$(find "$fixture/work" -type f | wc -l | tr -d ' ')" == 2 ]]
echo 'Release journal schemas, strict projection, retained bytes and no-effects checks passed'
fixture_complete=true
