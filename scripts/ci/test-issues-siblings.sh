#!/usr/bin/env bash
set -euo pipefail
ROOT="$0"
[[ "$ROOT" == /* ]] || ROOT="$PWD/$ROOT"
ROOT="$(cd -P "${ROOT%/*}/../.." && printf '%s/.' "$PWD")"
ROOT="${ROOT%/.}"
fixture="$(mktemp -d "${TMPDIR:-/tmp}/issues-siblings-test.XXXXXX")"
trap 'if [[ $? == 0 ]]; then rm -rf "$fixture"; else printf "Issue dashboard fixtures retained: %s\n" "$fixture" >&2; fi' EXIT
mkdir -p "$fixture/bin" "$fixture/projects" "$fixture/elsewhere"
export ISSUES_TEST_RESPONSE="$fixture/response"
export ISSUES_TEST_CALLS="$fixture/calls"
cat > "$fixture/bin/gh" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
printf '%s' "$*" | tr '\n' ' ' >> "$ISSUES_TEST_CALLS"
printf '\n' >> "$ISSUES_TEST_CALLS"
cat "$ISSUES_TEST_RESPONSE"
if [[ "${ISSUES_TEST_STATUS:-0}" != 0 ]]; then echo 'simulated GitHub failure' >&2; fi
exit "${ISSUES_TEST_STATUS:-0}"
SCRIPT
chmod +x "$fixture/bin/gh"
export PATH="$fixture/bin:$PATH"

checkout() {
    local name="$1" remote="$2"
    git init -q "$fixture/projects/$name"
    git -C "$fixture/projects/$name" remote add origin "$remote"
    touch "$fixture/projects/$name/AGENTS.md"
}
checkout 'alpha [copy]' https://github.com/Dragginzgame/Alpha.git
checkout beta git@github.com:dragginzgame/beta.git
checkout zero ssh://git@github.com/dragginzgame/zero.git
checkout duplicate https://github.com/dragginzgame/ALPHA/
checkout ichelper https://github.com/dragginzgame/ichelper
rm "$fixture/projects/ichelper/AGENTS.md"
checkout external https://example.invalid/owner/external
checkout no-origin https://github.com/dragginzgame/no-origin
git -C "$fixture/projects/no-origin" remote remove origin
ln -s "$fixture/projects/beta" "$fixture/projects/alias"
mkdir -p "$fixture/projects/notes"
touch "$fixture/projects/notes/AGENTS.md"
# An installed script defaults to its own checkout's parent, not the caller's.
mkdir -p "$fixture/projects/alpha [copy]/scripts/dev"
cp "$ROOT/scripts/dev/issues-siblings.sh" "$fixture/projects/alpha [copy]/scripts/dev/"
script="$fixture/projects/alpha [copy]/scripts/dev/issues-siblings.sh"
cat > "$ISSUES_TEST_RESPONSE" <<'JSON'
{"data":{"r0":{"open":{"totalCount":2500},"closed":{"totalCount":7500}},"r1":{"open":{"totalCount":9},"closed":{"totalCount":1}},"r2":{"open":{"totalCount":0},"closed":{"totalCount":0}}}}
JSON
run() {
    : > "$ISSUES_TEST_CALLS"
    bash "$script" "$@" > "$fixture/output" 2>&1
}
(cd "$fixture/elsewhere" && run --once)
awk '{$1=$1; print}' "$fixture/output" > "$fixture/rows"
grep -Fx 'REPOSITORY OPEN FIXED' "$fixture/rows"
[[ "$(grep -cE '^-+$' "$fixture/rows")" == 3 ]]
grep -Fx 'dragginzgame/alpha 2,500 7,500 / 10,000 (75.0%)' "$fixture/rows"
grep -Fx 'dragginzgame/beta 9 1 / 10 (10.0%)' "$fixture/rows"
grep -Fx 'dragginzgame/zero 0 0 / 0 (N/A)' "$fixture/rows"
grep -Fx 'TOTAL 2,509 7,501 / 10,010 (74.9%)' "$fixture/rows"
grep -Fx 'dragginzgame/beta              9       1 /     10 (10.0%)' "$fixture/output"
[[ "$(wc -l < "$ISSUES_TEST_CALLS" | tr -d ' ')" == 1 ]]
grep -F 'api graphql --hostname github.com' "$ISSUES_TEST_CALLS"
if grep -E 'ichelper|example.invalid|no-origin|r3:' "$ISSUES_TEST_CALLS"; then exit 1; fi
grep -F 'issues(states: OPEN) { totalCount }' "$ISSUES_TEST_CALLS"
grep -F 'issues(states: CLOSED) { totalCount }' "$ISSUES_TEST_CALLS"

# Relative parents ignore inherited CDPATH output and select the same repositories.
cp "$ISSUES_TEST_CALLS" "$fixture/expected-calls"
(cd "$fixture" && CDPATH="$fixture" run --once projects)
cmp "$ISSUES_TEST_CALLS" "$fixture/expected-calls"

# A trailing newline must not select the ordinary parent with the same prefix.
newline_parent="$fixture/projects"$'\n'
git init -q "$newline_parent/shared-tooling"
git -C "$newline_parent/shared-tooling" remote add origin https://github.com/dragginzgame/shared-tooling
touch "$newline_parent/shared-tooling/AGENTS.md"
run --once "$newline_parent"
grep -F 'name: "shared-tooling"' "$ISSUES_TEST_CALLS"
if grep -E 'name: "(alpha|beta|zero)"|r1:' "$ISSUES_TEST_CALLS"; then exit 1; fi
awk '{$1=$1; print}' "$fixture/output" > "$fixture/rows"
grep -Fx 'dragginzgame/shared-tooling 2,500 7,500 / 10,000 (75.0%)' "$fixture/rows"

# Nonterminal invocation reports once even without --once.
run --interval 1 "$fixture/projects"
[[ "$(grep -c 'api graphql' "$ISSUES_TEST_CALLS")" == 1 ]]
for bad in 0 -1 abc 1.5 86401 99999999999999999999; do
    status=0
    run --interval "$bad" || status=$?
    [[ "$status" == 2 && ! -s "$ISSUES_TEST_CALLS" ]]
done
status=0
run --interval || status=$?
[[ "$status" == 2 && ! -s "$ISSUES_TEST_CALLS" ]]

# Rank numerically by open count, with name ties, irrespective of total count.
# Grouped counts wider than six characters must remain intact.
cat > "$ISSUES_TEST_RESPONSE" <<'JSON'
{"data":{"r0":{"open":{"totalCount":9},"closed":{"totalCount":999999}},"r1":{"open":{"totalCount":100},"closed":{"totalCount":1}},"r2":{"open":{"totalCount":9},"closed":{"totalCount":0}}}}
JSON
run --once
awk '{$1=$1; print}' "$fixture/output" > "$fixture/rows"
grep -Fx 'dragginzgame/beta 100 1 / 101 (1.0%)' "$fixture/rows"
grep -Fx 'dragginzgame/alpha 9 999,999 / 1,000,008 (100.0%)' "$fixture/rows"
awk '$1 ~ /^dragginzgame\// { print $1 }' "$fixture/output" > "$fixture/order"
printf '%s\n' dragginzgame/beta dragginzgame/alpha dragginzgame/zero > "$fixture/expected-order"
cmp "$fixture/order" "$fixture/expected-order"

# A GraphQL partial response retains successful rows and fails the report.
cat > "$ISSUES_TEST_RESPONSE" <<'JSON'
{"data":{"r0":{"open":{"totalCount":2500},"closed":{"totalCount":7500}},"r1":null,"r2":{"open":{"totalCount":0},"closed":{"totalCount":0}}},"errors":[{"message":"unavailable","path":["r1"]}]}
JSON
status=0
ISSUES_TEST_STATUS=1 run --once || status=$?
[[ "$status" == 1 ]]
awk '{$1=$1; print}' "$fixture/output" > "$fixture/rows"
grep -Fx 'dragginzgame/beta ERROR ERROR / ERROR (N/A)' "$fixture/rows"
grep -Fx 'TOTAL (partial) 2,500 7,500 / 10,000 (75.0%)' "$fixture/rows"
awk '$1 ~ /^dragginzgame\// { print $1 }' "$fixture/output" > "$fixture/order"
printf '%s\n' dragginzgame/alpha dragginzgame/zero dragginzgame/beta > "$fixture/expected-order"
cmp "$fixture/order" "$fixture/expected-order"
grep -F 'simulated GitHub failure' "$fixture/output"

# Invalid, missing, fractional and negative observations must never become zero.
for response in '' 'not JSON' '{"data":{}}' \
    '{"data":{"r0":{"open":{"totalCount":-1},"closed":{"totalCount":2}}}}' \
    '{"data":{"r0":{"open":{"totalCount":1.5},"closed":{"totalCount":2}}}}'; do
    printf '%s\n' "$response" > "$ISSUES_TEST_RESPONSE"
    status=0
    run --once || status=$?
    [[ "$status" == 1 ]]
    awk '{$1=$1; print}' "$fixture/output" > "$fixture/rows"
    grep -Fx 'TOTAL (partial) ERROR ERROR / ERROR (N/A)' "$fixture/rows"
done
mkdir "$fixture/empty"
status=0
run --once "$fixture/empty" || status=$?
[[ "$status" == 1 && ! -s "$ISSUES_TEST_CALLS" ]]
echo 'Sibling issue dashboard tests passed'
