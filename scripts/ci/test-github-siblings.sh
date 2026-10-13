#!/usr/bin/env bash
# Shared companions: scripts/ci/fixture-lifecycle.sh
set -euo pipefail
ROOT="$0"
[[ "$ROOT" == /* ]] || ROOT="$PWD/$ROOT"
ROOT="$(cd -P "${ROOT%/*}/../.." && printf '%s/.' "$PWD")"
ROOT="${ROOT%/.}"
fixture="$(mktemp -d "${TMPDIR:-/tmp}/github-siblings-test.XXXXXX")"
fixture="$(CDPATH="" cd -P -- "$fixture" && printf '%s/.' "$PWD")"
fixture="${fixture%/.}"
# shellcheck source=scripts/ci/fixture-lifecycle.sh
source "$ROOT/scripts/ci/fixture-lifecycle.sh"
fixture_complete=false
trap 'fixture_finish "$?" "$fixture" "GitHub dashboard fixtures retained"' EXIT
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
check_layout 89 34 39 76 55
[[ "$(grep -cE '^-+$' "$fixture/rows")" == 3 ]] || exit 1
grep -Fx 'dragginzgame/alpha 2,500 7,500 / 10,000 0 0 12 1,500 20' "$fixture/rows"
grep -Fx 'dragginzgame/beta 9 1 / 10 0 0 3 7 2' "$fixture/rows"
grep -Fx 'dragginzgame/zero 0 0 / 0 0 0 5 0 1' "$fixture/rows"
grep -Fx 'TOTAL 2,509 7,501 / 10,010 0 0 20 1,507 23' "$fixture/rows"
grep -F 'dragginzgame/beta              9       1 /     10' "$fixture/output"
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

# Reject raw, normalized-away and resolved forbidden directory components.
for suffix in $'\n' $'\r'; do
    invalid_parent="$fixture/projects$suffix"
    mkdir -p "$invalid_parent"
    ln -s "$invalid_parent" "$fixture/invalid-alias"
    for selected in "$invalid_parent" "$invalid_parent/../projects" "$fixture/invalid-alias"; do
        status=0
        run --once "$selected" || status=$?
        [[ "$status" == 1 && ! -s "$GITHUB_SIBLINGS_TEST_CALLS" ]] || exit 1
        grep -Fx 'error: directory paths must not contain CR or LF' "$fixture/output"
    done
    checkout "bad$suffix" https://github.com/dragginzgame/bad
    status=0
    run --once "$fixture/projects" || status=$?
    [[ "$status" == 1 && ! -s "$GITHUB_SIBLINGS_TEST_CALLS" ]] || exit 1
    grep -Fx 'error: directory paths must not contain CR or LF' "$fixture/output"
    rm -rf "$fixture/projects/bad$suffix"
    mkdir -p "$invalid_parent/scripts/dev"
    cp "$script" "$invalid_parent/scripts/dev/"
    for selected in "$invalid_parent" "$fixture/invalid-alias"; do
        status=0
        bash "$selected/scripts/dev/github-siblings.sh" --once "$fixture/projects" > "$fixture/output" 2>&1 || status=$?
        [[ "$status" == 1 && ! -s "$GITHUB_SIBLINGS_TEST_CALLS" ]] || exit 1
        grep -Fx 'error: directory paths must not contain CR or LF' "$fixture/output"
    done
    rm "$fixture/invalid-alias"
done
ln -s "$fixture/projects" "$fixture/valid alias"
run --once "$fixture/valid alias"
cmp "$GITHUB_SIBLINGS_TEST_CALLS" "$fixture/expected-calls"

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

# Rank by open issues, independent of closed issue history.
# Grouped counts widen numeric fields, including the closed / total ratio.
cat > "$GITHUB_SIBLINGS_TEST_RESPONSE" <<'JSON'
{"data":{"r0":{"open":{"totalCount":9},"closed":{"totalCount":999999},"prOpen":{"totalCount":9000},"prMerged":{"totalCount":1234567},"prClosed":{"totalCount":99},"recent":{"nodes":[],"pageInfo":{"hasNextPage":false,"endCursor":null}}},"r1":{"open":{"totalCount":100},"closed":{"totalCount":1},"prOpen":{"totalCount":0},"prMerged":{"totalCount":0},"prClosed":{"totalCount":0},"recent":{"nodes":[],"pageInfo":{"hasNextPage":false,"endCursor":null}}},"r2":{"open":{"totalCount":9},"closed":{"totalCount":0},"prOpen":{"totalCount":1},"prMerged":{"totalCount":2},"prClosed":{"totalCount":3},"recent":{"nodes":[],"pageInfo":{"hasNextPage":false,"endCursor":null}}}}}
JSON
run --once
check_layout 113 39 45 96 67
awk '{$1=$1; print}' "$fixture/output" > "$fixture/rows"
grep -Fx 'dragginzgame/beta 100 1 / 101 0 0 0 0 0' "$fixture/rows"
grep -Fx 'dragginzgame/alpha 9 999,999 / 1,000,008 0 0 9,000 1,234,567 99' "$fixture/rows"
awk '$1 ~ /^dragginzgame\// { print $1 }' "$fixture/output" > "$fixture/order"
printf '%s\n' dragginzgame/beta dragginzgame/alpha dragginzgame/zero > "$fixture/expected-order"
cmp "$fixture/order" "$fixture/expected-order"

# Equal open counts rank by name, regardless of closed counts.
jq '.data.r0.open.totalCount=9 | .data.r0.closed.totalCount=9990 |
    .data.r1.open.totalCount=1 | .data.r1.closed.totalCount=1000 |
    .data.r2.open.totalCount=1 | .data.r2.closed.totalCount=1000' \
    "$GITHUB_SIBLINGS_TEST_RESPONSE" > "$fixture/ranked"
cp "$fixture/ranked" "$GITHUB_SIBLINGS_TEST_RESPONSE"
run --once
awk '$1 ~ /^dragginzgame\// { print $1 }' "$fixture/output" > "$fixture/order"
printf '%s\n' dragginzgame/alpha dragginzgame/beta dragginzgame/zero > "$fixture/expected-order"
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
grep -Fx 'TOTAL (partial) 2,500 7,500 / 10,000 0 0 17 1,500 21' "$fixture/rows"
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
check_layout 79 31 35 67 48
printf '%-24s  %4s  %4s / %4s  %5s  %5s  %4s  %6s  %6s\n' \
    dragginzgame/alpha 10 20 30 0 0 2 3 4 > "$fixture/narrow-row"
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
        grep -Fx 'TOTAL (partial) 0 0 / 0 0 0 0 0 0' "$fixture/rows"
    done
done
# The slash has one separator space plus width-four numeric padding.
# An unavailable sibling must not widen every FIXED number to five characters.
jq '.data.r0.open.totalCount=86 | .data.r0.closed.totalCount=400 | .data.r1=null' \
    "$fixture/valid-response" > "$GITHUB_SIBLINGS_TEST_RESPONSE"
status=0
run --once || status=$?
[[ "$status" == 1 ]] || exit 1
grep -F ' 400 /  486' "$fixture/output"
check_layout 81 32 36 69 49

# A fleet total wider than any repository must not add padding after its slash.
jq '.data.r0.open.totalCount=86 | .data.r0.closed.totalCount=400 |
    .data.r1.open.totalCount=200 | .data.r1.closed.totalCount=500' \
    "$fixture/valid-response" > "$GITHUB_SIBLINGS_TEST_RESPONSE"
run --once
grep -F ' 400 /  486' "$fixture/output"
grep -F '900 / 1,186' "$fixture/output"

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
grep -Fx 'dragginzgame/alpha 10 20 / 30 2 3 2 3 4' "$fixture/rows"
grep -Fx 'TOTAL 10 21 / 31 3 3 2 3 4' "$fixture/rows"
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

# Substitute only terminal detection to exercise coloured rows in this fixture.
plain_script="$script"
sed 's/^colour=false$/colour=true/' "$script" > "${script%.sh}-colour.sh"
script="${script%.sh}-colour.sh"
for scenario in gradient equal zero; do
    case "$scenario" in
        gradient) filter='.data.r1.open.totalCount=5' ;;
        equal) filter='.data.r1.open.totalCount=10 | .data.r1.closed.totalCount=10000' ;;
        zero) filter='.data.r0.open.totalCount=0' ;;
    esac
    jq "$filter" "$fixture/valid-response" > "$GITHUB_SIBLINGS_TEST_RESPONSE"
    run --once
    perl - "$fixture/output" "$scenario" <<'PERL'
use strict;
use warnings;
my ($path, $scenario) = @ARGV;
open my $fh, '<', $path or die $!;
my %colours;
while (<$fh>) {
    if (/^\e\[38;2;(\d+;\d+;\d+)mdragginzgame\/(\w+).*\e\[39m\n$/) {
        $colours{$2}=$1;
    } elsif (/\e/) { die "only repository foregrounds may be coloured\n"; }
}
die "missing coloured repositories\n" unless keys(%colours) == 3;
die "zero backlog must be green\n" unless $colours{zero} eq '170;214;186';
if ($scenario eq 'zero') {
    die "all-zero backlog must be green\n" if grep { $_ ne $colours{zero} } values %colours;
} else {
    die "largest backlog must be red\n" unless $colours{alpha} eq '238;180;180';
    my $expected=$scenario eq 'equal' ? $colours{alpha} : '238;220;160';
    die "colour must follow open counts alone\n" unless $colours{beta} eq $expected;
}
PERL
done
script="$plain_script"

mkdir "$fixture/empty"
status=0
run --once "$fixture/empty" || status=$?
[[ "$status" == 1 && ! -s "$GITHUB_SIBLINGS_TEST_CALLS" ]] || exit 1
echo 'Sibling GitHub dashboard tests passed'
fixture_complete=true
