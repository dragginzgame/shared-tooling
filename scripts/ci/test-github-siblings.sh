#!/usr/bin/env bash
set -euo pipefail
ROOT="$0"
[[ "$ROOT" == /* ]] || ROOT="$PWD/$ROOT"
ROOT="$(cd -P "${ROOT%/*}/../.." && printf '%s/.' "$PWD")"
ROOT="${ROOT%/.}"
fixture="$(mktemp -d "${TMPDIR:-/tmp}/github-siblings-test.XXXXXX")"
# Bash 3.2 can enter EXIT with status zero after nounset; require completion too.
fixture_complete=false
finish() {
    local status=$?
    [[ "$fixture_complete" == true || "$status" != 0 ]] || status=1
    if [[ "$status" == 0 ]]; then rm -rf "$fixture"
    else printf "GitHub dashboard fixtures retained: %s\n" "$fixture" >&2; fi
    exit "$status"
}
trap finish EXIT
mkdir -p "$fixture/bin" "$fixture/projects" "$fixture/elsewhere"
export GITHUB_SIBLINGS_TEST_RESPONSE="$fixture/response"
export GITHUB_SIBLINGS_TEST_PAGE="$fixture/page"
export GITHUB_SIBLINGS_TEST_CALLS="$fixture/calls"
cat > "$fixture/bin/gh" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
printf '%s' "$*" | tr '\n' ' ' >> "$GITHUB_SIBLINGS_TEST_CALLS"
printf '\n' >> "$GITHUB_SIBLINGS_TEST_CALLS"
for arg in "$@"; do
    if [[ "$arg" == after=* ]]; then
        cat "$GITHUB_SIBLINGS_TEST_PAGE"
        exit "${GITHUB_SIBLINGS_TEST_PAGE_STATUS:-0}"
    fi
done
cat "$GITHUB_SIBLINGS_TEST_RESPONSE"
if [[ "${GITHUB_SIBLINGS_TEST_STATUS:-0}" != 0 ]]; then echo 'simulated GitHub failure' >&2; fi
exit "${GITHUB_SIBLINGS_TEST_STATUS:-0}"
SCRIPT
chmod +x "$fixture/bin/gh"
GITHUB_SIBLINGS_TEST_DATE="$(command -v date)"
export GITHUB_SIBLINGS_TEST_DATE
export GITHUB_SIBLINGS_TEST_NOW=1768478400 # 2026-01-15 12:00 UTC
cat > "$fixture/bin/date" <<'SCRIPT'
#!/usr/bin/env bash
if [[ "$1" == +%s ]]; then printf '%s\n' "$GITHUB_SIBLINGS_TEST_NOW";
else exec "$GITHUB_SIBLINGS_TEST_DATE" "$@"; fi
SCRIPT
chmod +x "$fixture/bin/date"
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
cp "$ROOT/scripts/dev/github-siblings.sh" "$fixture/projects/alpha [copy]/scripts/dev/"
script="$fixture/projects/alpha [copy]/scripts/dev/github-siblings.sh"
cat > "$GITHUB_SIBLINGS_TEST_RESPONSE" <<'JSON'
{"data":{"r0":{"open":{"totalCount":2500},"closed":{"totalCount":7500},"prOpen":{"totalCount":12},"prMerged":{"totalCount":1500},"prClosed":{"totalCount":20},"recent":{"nodes":[],"pageInfo":{"hasNextPage":false,"endCursor":null}}},"r1":{"open":{"totalCount":9},"closed":{"totalCount":1},"prOpen":{"totalCount":3},"prMerged":{"totalCount":7},"prClosed":{"totalCount":2},"recent":{"nodes":[],"pageInfo":{"hasNextPage":false,"endCursor":null}}},"r2":{"open":{"totalCount":0},"closed":{"totalCount":0},"prOpen":{"totalCount":5},"prMerged":{"totalCount":0},"prClosed":{"totalCount":1},"recent":{"nodes":[],"pageInfo":{"hasNextPage":false,"endCursor":null}}}}}
JSON
run() {
    : > "$GITHUB_SIBLINGS_TEST_CALLS"
    bash "$script" "$@" > "$fixture/output" 2>&1
}
check_layout() {
    # Check visible heading positions and whole-table alignment, including the
    # totals, against the expected narrow/wide layouts for these known counts.
    perl - "$fixture/output" "$@" <<'PERL'
use strict;
use warnings;
my ($path, $width, $issues, $fixed, $prs, $today) = @ARGV;
open my $fh, '<', $path or die $!;
my @lines = <$fh>;
chomp @lines;
my ($groups) = grep { /^\s+ISSUES\s+TODAY\s+PRS\s*$/ } @lines;
my ($columns) = grep { /^REPOSITORY\s/ } @lines;
die "group headings not centered\n" unless defined $groups &&
    index($groups, 'ISSUES') == $issues && index($groups, 'PRS') == $prs && index($groups, 'TODAY') == $today;
die "FIXED heading not centered\n" unless index($columns, 'FIXED') == $fixed;
for my $line (grep { /^(?:REPOSITORY\s|dragginzgame\/|TOTAL\s|---)/ } @lines) {
    die "table column alignment changed\n" unless length($line) == $width;
}
PERL
}
(cd "$fixture/elsewhere" && run --once)
awk '{$1=$1; print}' "$fixture/output" > "$fixture/rows"
grep -Fx 'ISSUES TODAY PRS' "$fixture/rows"
grep -Fx 'REPOSITORY OPEN FIXED FIXED ADDED OPEN MERGED CLOSED' "$fixture/rows"
check_layout 97 38 43 84 63
[[ "$(grep -cE '^-+$' "$fixture/rows")" == 3 ]] || exit 1
grep -Fx 'dragginzgame/alpha 2,500 7,500 / 10,000 (75.0%) 0 0 12 1,500 20' "$fixture/rows"
grep -Fx 'dragginzgame/beta 9 1 / 10 (10.0%) 0 0 3 7 2' "$fixture/rows"
grep -Fx 'dragginzgame/zero 0 0 / 0 (N/A) 0 0 5 0 1' "$fixture/rows"
grep -Fx 'TOTAL 2,509 7,501 / 10,010 (74.9%) 0 0 20 1,507 23' "$fixture/rows"
grep -F 'dragginzgame/beta              9       1 /     10 (10.0%)' "$fixture/output"
[[ "$(wc -l < "$GITHUB_SIBLINGS_TEST_CALLS" | tr -d ' ')" == 1 ]] || exit 1
grep -F 'api graphql --hostname github.com' "$GITHUB_SIBLINGS_TEST_CALLS"
if grep -E 'ichelper|example.invalid|no-origin|r3:' "$GITHUB_SIBLINGS_TEST_CALLS"; then exit 1; fi
grep -F 'issues(states: OPEN) { totalCount }' "$GITHUB_SIBLINGS_TEST_CALLS"
grep -F 'issues(states: CLOSED) { totalCount }' "$GITHUB_SIBLINGS_TEST_CALLS"
for state in OPEN MERGED CLOSED; do
    grep -F "pullRequests(states: $state) { totalCount }" "$GITHUB_SIBLINGS_TEST_CALLS"
done

# Relative parents ignore inherited CDPATH output and select the same repositories.
cp "$GITHUB_SIBLINGS_TEST_CALLS" "$fixture/expected-calls"
(cd "$fixture" && CDPATH="$fixture" run --once projects)
cmp "$GITHUB_SIBLINGS_TEST_CALLS" "$fixture/expected-calls"

# A trailing newline must not select the ordinary parent with the same prefix.
newline_parent="$fixture/projects"$'\n'
git init -q "$newline_parent/shared-tooling"
git -C "$newline_parent/shared-tooling" remote add origin https://github.com/dragginzgame/shared-tooling
touch "$newline_parent/shared-tooling/AGENTS.md"
run --once "$newline_parent"
grep -F 'name: "shared-tooling"' "$GITHUB_SIBLINGS_TEST_CALLS"
if grep -E 'name: "(alpha|beta|zero)"|r1:' "$GITHUB_SIBLINGS_TEST_CALLS"; then exit 1; fi
awk '{$1=$1; print}' "$fixture/output" > "$fixture/rows"
grep -Fx 'dragginzgame/shared-tooling 2,500 7,500 / 10,000 (75.0%) 0 0 12 1,500 20' "$fixture/rows"

# Nonterminal invocation reports once even without --once.
run --interval 1 "$fixture/projects"
[[ "$(grep -c 'api graphql' "$GITHUB_SIBLINGS_TEST_CALLS")" == 1 ]] || exit 1
for bad in 0 -1 abc 1.5 86401 99999999999999999999; do
    status=0
    run --interval "$bad" || status=$?
    [[ "$status" == 2 && ! -s "$GITHUB_SIBLINGS_TEST_CALLS" ]] || exit 1
done
status=0
run --interval || status=$?
[[ "$status" == 2 && ! -s "$GITHUB_SIBLINGS_TEST_CALLS" ]] || exit 1

# Rank by completion fraction, not the rounded display or open count.
# Grouped counts widen every numeric field, including the completion ratio.
cat > "$GITHUB_SIBLINGS_TEST_RESPONSE" <<'JSON'
{"data":{"r0":{"open":{"totalCount":9},"closed":{"totalCount":999999},"prOpen":{"totalCount":9000},"prMerged":{"totalCount":1234567},"prClosed":{"totalCount":99},"recent":{"nodes":[],"pageInfo":{"hasNextPage":false,"endCursor":null}}},"r1":{"open":{"totalCount":100},"closed":{"totalCount":1},"prOpen":{"totalCount":0},"prMerged":{"totalCount":0},"prClosed":{"totalCount":0},"recent":{"nodes":[],"pageInfo":{"hasNextPage":false,"endCursor":null}}},"r2":{"open":{"totalCount":9},"closed":{"totalCount":0},"prOpen":{"totalCount":1},"prMerged":{"totalCount":2},"prClosed":{"totalCount":3},"recent":{"nodes":[],"pageInfo":{"hasNextPage":false,"endCursor":null}}}}}
JSON
run --once
check_layout 122 43 49 105 76
awk '{$1=$1; print}' "$fixture/output" > "$fixture/rows"
grep -Fx 'dragginzgame/beta 100 1 / 101 (1.0%) 0 0 0 0 0' "$fixture/rows"
grep -Fx 'dragginzgame/alpha 9 999,999 / 1,000,008 (100.0%) 0 0 9,000 1,234,567 99' "$fixture/rows"
awk '$1 ~ /^dragginzgame\// { print $1 }' "$fixture/output" > "$fixture/order"
printf '%s\n' dragginzgame/zero dragginzgame/beta dragginzgame/alpha > "$fixture/expected-order"
cmp "$fixture/order" "$fixture/expected-order"

# Equal displayed percentages still rank by the underlying fraction, then name.
jq '.data.r0.open.totalCount=9 | .data.r0.closed.totalCount=9990 |
    .data.r1.open.totalCount=1 | .data.r1.closed.totalCount=1000 |
    .data.r2.open.totalCount=1 | .data.r2.closed.totalCount=1000' \
    "$GITHUB_SIBLINGS_TEST_RESPONSE" > "$fixture/ranked"
cp "$fixture/ranked" "$GITHUB_SIBLINGS_TEST_RESPONSE"
run --once
awk '$1 ~ /^dragginzgame\// { print $1 }' "$fixture/output" > "$fixture/order"
printf '%s\n' dragginzgame/beta dragginzgame/zero dragginzgame/alpha > "$fixture/expected-order"
cmp "$fixture/order" "$fixture/expected-order"

# A GraphQL partial response retains successful rows and fails the report.
cat > "$GITHUB_SIBLINGS_TEST_RESPONSE" <<'JSON'
{"data":{"r0":{"open":{"totalCount":2500},"closed":{"totalCount":7500},"prOpen":{"totalCount":12},"prMerged":{"totalCount":1500},"prClosed":{"totalCount":20},"recent":{"nodes":[],"pageInfo":{"hasNextPage":false,"endCursor":null}}},"r1":null,"r2":{"open":{"totalCount":0},"closed":{"totalCount":0},"prOpen":{"totalCount":5},"prMerged":{"totalCount":0},"prClosed":{"totalCount":1},"recent":{"nodes":[],"pageInfo":{"hasNextPage":false,"endCursor":null}}}},"errors":[{"message":"unavailable","path":["r1"]}]}
JSON
status=0
GITHUB_SIBLINGS_TEST_STATUS=1 run --once || status=$?
[[ "$status" == 1 ]] || exit 1
awk '{$1=$1; print}' "$fixture/output" > "$fixture/rows"
grep -Fx 'dragginzgame/beta ERROR ERROR ERROR ERROR ERROR ERROR ERROR' "$fixture/rows"
grep -Fx 'TOTAL (partial) 2,500 7,500 / 10,000 (75.0%) 0 0 17 1,500 21' "$fixture/rows"
awk '$1 ~ /^dragginzgame\// { print $1 }' "$fixture/output" > "$fixture/order"
printf '%s\n' dragginzgame/alpha dragginzgame/zero dragginzgame/beta > "$fixture/expected-order"
cmp "$fixture/order" "$fixture/expected-order"
grep -F 'simulated GitHub failure' "$fixture/output"

# Invalid and missing observations must never become zero.
for response in '' 'not JSON' '{"data":{}}'; do
    printf '%s\n' "$response" > "$GITHUB_SIBLINGS_TEST_RESPONSE"
    status=0
    run --once || status=$?
    [[ "$status" == 1 ]] || exit 1
    awk '{$1=$1; print}' "$fixture/output" > "$fixture/rows"
    grep -Fx 'TOTAL (partial) ERROR ERROR ERROR ERROR ERROR ERROR ERROR' "$fixture/rows"
done
# Every issue/PR field must be a valid count. A failed PR read cannot silently
# turn into zero, or let the row's otherwise valid issue totals appear complete.
cat > "$fixture/valid-response" <<'JSON'
{"data":{"r0":{"open":{"totalCount":10},"closed":{"totalCount":20},"prOpen":{"totalCount":2},"prMerged":{"totalCount":3},"prClosed":{"totalCount":4},"recent":{"nodes":[],"pageInfo":{"hasNextPage":false,"endCursor":null}}},"r1":{"open":{"totalCount":0},"closed":{"totalCount":0},"prOpen":{"totalCount":0},"prMerged":{"totalCount":0},"prClosed":{"totalCount":0},"recent":{"nodes":[],"pageInfo":{"hasNextPage":false,"endCursor":null}}},"r2":{"open":{"totalCount":0},"closed":{"totalCount":0},"prOpen":{"totalCount":0},"prMerged":{"totalCount":0},"prClosed":{"totalCount":0},"recent":{"nodes":[],"pageInfo":{"hasNextPage":false,"endCursor":null}}}}}
JSON
cp "$fixture/valid-response" "$GITHUB_SIBLINGS_TEST_RESPONSE"
run --once
check_layout 87 35 39 75 56
printf '%-24s  %4s  %4s / %4s %-7s  %5s  %5s  %4s  %6s  %6s\n' \
    dragginzgame/alpha 10 20 30 '(66.7%)' 0 0 2 3 4 > "$fixture/narrow-row"
grep '^dragginzgame/alpha ' "$fixture/output" > "$fixture/actual-narrow-row"
cmp "$fixture/narrow-row" "$fixture/actual-narrow-row"
for field in open closed prOpen prMerged prClosed; do
    for invalid in null -1 1.5 '"2"'; do
        jq --arg field "$field" --argjson invalid "$invalid" \
            '.data.r0[$field].totalCount = $invalid' "$fixture/valid-response" > "$GITHUB_SIBLINGS_TEST_RESPONSE"
        status=0
        run --once || status=$?
        [[ "$status" == 1 ]] || exit 1
        awk '{$1=$1; print}' "$fixture/output" > "$fixture/rows"
        grep -Fx 'dragginzgame/alpha ERROR ERROR ERROR ERROR ERROR ERROR ERROR' "$fixture/rows"
        grep -Fx 'TOTAL (partial) 0 0 / 0 (N/A) 0 0 0 0 0' "$fixture/rows"
    done
done
# The slash has one separator space plus width-four numeric padding.
# An unavailable sibling must not widen every FIXED number to five characters.
jq '.data.r0.open.totalCount=86 | .data.r0.closed.totalCount=400 | .data.r1=null' \
    "$fixture/valid-response" > "$GITHUB_SIBLINGS_TEST_RESPONSE"
status=0
run --once || status=$?
[[ "$status" == 1 ]] || exit 1
grep -F ' 400 /  486 (82.3%)' "$fixture/output"
check_layout 89 36 40 77 57

# A fleet total wider than any repository must not add padding after its slash.
jq '.data.r0.open.totalCount=86 | .data.r0.closed.totalCount=400 |
    .data.r1.open.totalCount=200 | .data.r1.closed.totalCount=500' \
    "$fixture/valid-response" > "$GITHUB_SIBLINGS_TEST_RESPONSE"
run --once
grep -F ' 400 /  486 (82.3%)' "$fixture/output"
grep -F '900 / 1,186 (75.9%)' "$fixture/output"

# Calendar boundaries include both DST transitions (23/25-hour reporting days).
# These epochs are UTC, independent of the fixture host timezone.
cp "$fixture/valid-response" "$GITHUB_SIBLINGS_TEST_RESPONSE"
while read -r now expected; do
    GITHUB_SIBLINGS_TEST_NOW="$now" run --once
    grep -F "since=$expected" "$GITHUB_SIBLINGS_TEST_CALLS"
done <<'DATES'
1768453199 2026-01-14T05:00:00Z
1768453200 2026-01-15T05:00:00Z
1774756799 2026-03-28T05:00:00Z
1774756800 2026-03-29T04:00:00Z
1792904399 2026-10-24T04:00:00Z
1792904400 2026-10-25T05:00:00Z
DATES

# Fetch every recent page. Count creations in either state, with a shared cutoff.
# Old issues updated today are not additions; reopened issues are not fixes.
jq '.data.r0.recent = {
    nodes: [
        {state:"CLOSED",createdAt:"2026-01-15T05:00:00Z",closedAt:"2026-01-15T05:00:00Z"},
        {state:"CLOSED",createdAt:"2026-01-15T04:59:59Z",closedAt:"2026-01-15T04:59:59Z"},
        {state:"OPEN",createdAt:"2026-01-15T06:00:00Z",closedAt:null},
        {state:"OPEN",createdAt:"2026-01-14T10:00:00Z",closedAt:null}],
    pageInfo:{hasNextPage:true,endCursor:"page-one"}}
    | .data.r1.closed.totalCount=1
    | .data.r1.recent.nodes=[{state:"CLOSED",createdAt:"2026-01-14T00:00:00Z",closedAt:"2026-01-15T06:00:00Z"}]' \
    "$fixture/valid-response" > "$GITHUB_SIBLINGS_TEST_RESPONSE"
cat > "$GITHUB_SIBLINGS_TEST_PAGE" <<'JSON'
{"data":{"repository":{"recent":{"nodes":[{"state":"CLOSED","createdAt":"2026-01-14T00:00:00Z","closedAt":"2026-01-15T10:00:00Z"},{"state":"OPEN","createdAt":"2026-01-15T10:00:00Z","closedAt":null}],"pageInfo":{"hasNextPage":false,"endCursor":"last"}}}}}
JSON
run --once
awk '{$1=$1; print}' "$fixture/output" > "$fixture/rows"
grep -Fx 'dragginzgame/alpha 10 20 / 30 (66.7%) 2 3 2 3 4' "$fixture/rows"
grep -Fx 'TOTAL 10 21 / 31 (67.7%) 3 3 2 3 4' "$fixture/rows"
[[ "$(wc -l < "$GITHUB_SIBLINGS_TEST_CALLS" | tr -d ' ')" == 2 ]] || exit 1
grep -F 'after=page-one' "$GITHUB_SIBLINGS_TEST_CALLS"
# Failures, malformed pages and stalled cursors cannot publish a partial count.
cp "$GITHUB_SIBLINGS_TEST_PAGE" "$fixture/valid-page"
for response in '{}' '{"data":{"repository":{"recent":{"nodes":[],"pageInfo":{"hasNextPage":true,"endCursor":"page-one"}}}}}' \
    '{"errors":[{"message":"unavailable"}]}' \
    '{"data":{"repository":{"recent":{"nodes":[{"state":"CLOSED","createdAt":null,"closedAt":"2026-01-15T10:00:00Z"}],"pageInfo":{"hasNextPage":false}}}}}' \
    '{"data":{"repository":{"recent":{"nodes":[{"closedAt":null}],"pageInfo":{"hasNextPage":false}}}}}'; do
    printf '%s\n' "$response" > "$GITHUB_SIBLINGS_TEST_PAGE"
    status=0
    run --once || status=$?
    [[ "$status" == 1 ]] || exit 1
    awk '{$1=$1; print}' "$fixture/output" > "$fixture/rows"
    grep -Fx 'dragginzgame/alpha ERROR ERROR ERROR ERROR ERROR ERROR ERROR' "$fixture/rows"
done
cp "$fixture/valid-page" "$GITHUB_SIBLINGS_TEST_PAGE"
status=0
GITHUB_SIBLINGS_TEST_PAGE_STATUS=1 run --once || status=$?
[[ "$status" == 1 ]] || exit 1
# Redirected output stays plain even when TERM advertises colour.
cp "$fixture/valid-response" "$GITHUB_SIBLINGS_TEST_RESPONSE"
TERM=xterm-256color run --once
if LC_ALL=C grep -q $'\033' "$fixture/output"; then exit 1; fi

mkdir "$fixture/empty"
status=0
run --once "$fixture/empty" || status=$?
[[ "$status" == 1 && ! -s "$GITHUB_SIBLINGS_TEST_CALLS" ]] || exit 1
echo 'Sibling GitHub dashboard tests passed'
fixture_complete=true
