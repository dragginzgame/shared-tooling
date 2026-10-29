#!/usr/bin/env bash
# Shared companions: scripts/ci/fixture-lifecycle.sh
set -euo pipefail
export COLUMNS=0 # Ordinary redirected reports have no known terminal width.
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
export GITHUB_SIBLINGS_TEST_PR_PAGE="$fixture/pr-page"
export GITHUB_SIBLINGS_TEST_PAGE="$fixture/page"
export GITHUB_SIBLINGS_TEST_CALLS="$fixture/calls"
cat > "$fixture/bin/gh" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
printf '%s' "$*" | tr '\n' ' ' >> "$GITHUB_SIBLINGS_TEST_CALLS"
printf '\n' >> "$GITHUB_SIBLINGS_TEST_CALLS"
for arg in "$@"; do
    if [[ "$arg" == after=* ]]; then
        if [[ "$*" == *prRecent* ]]; then
            cat "$GITHUB_SIBLINGS_TEST_PR_PAGE"
            exit "${GITHUB_SIBLINGS_TEST_PR_PAGE_STATUS:-0}"
        fi
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
{"data":{"r0":{"open":{"totalCount":2500},"closed":{"totalCount":7500},"prRecent":{"nodes":[],"pageInfo":{"hasNextPage":false,"endCursor":null}},"prOpen":{"totalCount":12},"prMerged":{"totalCount":1500},"prClosed":{"totalCount":20},"recent":{"nodes":[],"pageInfo":{"hasNextPage":false,"endCursor":null}}},"r1":{"open":{"totalCount":9},"closed":{"totalCount":1},"prRecent":{"nodes":[],"pageInfo":{"hasNextPage":false,"endCursor":null}},"prOpen":{"totalCount":3},"prMerged":{"totalCount":7},"prClosed":{"totalCount":2},"recent":{"nodes":[],"pageInfo":{"hasNextPage":false,"endCursor":null}}},"r2":{"open":{"totalCount":0},"closed":{"totalCount":0},"prRecent":{"nodes":[],"pageInfo":{"hasNextPage":false,"endCursor":null}},"prOpen":{"totalCount":5},"prMerged":{"totalCount":0},"prClosed":{"totalCount":1},"recent":{"nodes":[],"pageInfo":{"hasNextPage":false,"endCursor":null}}}}}
JSON
run() {
    : > "$GITHUB_SIBLINGS_TEST_CALLS"
    bash "$script" "$@" > "$fixture/output" 2>&1
}
check_layout() {
    # Check centered headings and aligned separators for narrow/wide counts,
    # totals and partial results.
    perl - "$fixture/output" "$@" <<'PERL'
use strict;
use warnings;
my ($path, $width, $closed) = @ARGV;
open my $fh, '<', $path or die $!;
my @lines = <$fh>;
chomp @lines;
my ($groups) = grep { /^\s+ISSUES\s+\|\s+PRS\s*$/ } @lines;
my ($subgroups) = grep { /^\s+OVERALL\s+\|\s+TODAY\s+\|\s+OVERALL\s+\|\s+TODAY\s*$/ } @lines;
my ($columns) = grep { /^REPOSITORY\s/ } @lines;
die "missing group headings\n" unless defined $groups && defined $subgroups;
die "CLOSED heading not centered\n" unless index($columns, 'CLOSED') == $closed;
my @bars = map { $_ } grep { substr($subgroups, $_, 1) eq '|' } 0 .. length($subgroups)-1;
my $start = 12;
$start = 17 if grep { /^TOTAL \(partial\)/ } @lines;
for my $spec ([$groups,'ISSUES',$start,$bars[1]-1], [$groups,'PRS',$bars[1]+2,$width],
              [$subgroups,'OVERALL',$start,$bars[0]-1], [$subgroups,'TODAY',$bars[0]+2,$bars[1]-1],
              [$subgroups,'OVERALL',$bars[1]+2,$bars[2]-1], [$subgroups,'TODAY',$bars[2]+2,$width]) {
    my ($line,$label,$left,$right) = @$spec;
    # Verify symmetry within each group independently of number widths.
    my $region = substr($line, $left, $right-$left);
    $region =~ /^(\s*)\Q$label\E(\s*)$/ or die "invalid heading region: $region\n";
    die "heading not centered: $label\n" if abs(length($1)-length($2)) > 1;
}
for my $line ($groups, $subgroups, grep { /^(?:REPOSITORY\s|(?:alpha|beta|zero)\s|TOTAL\s|---)/ } @lines) {
    die "table column alignment changed: ".length($line)." != $width\n" unless length($line) == $width;
    next if $line eq $groups;
    my @actual = ($line =~ /\|/g);
    die "missing group separators\n" unless @actual == 3;
    for my $position (@bars) {
        die "misaligned group separator\n" unless substr($line, $position, 1) eq "|";
    }
}

PERL
}
(cd "$fixture/elsewhere" && run --once)
awk '{gsub(/\|/, " "); $1=$1; print}' "$fixture/output" > "$fixture/rows"
grep -Fx 'ISSUES PRS' "$fixture/rows"
grep -Fx 'REPOSITORY OPEN CLOSED ADDED CLOSED OPEN CLOSED ADDED CLOSED' "$fixture/rows"
check_layout 73 19
[[ "$(grep -cE '^[-|]+$' "$fixture/output")" == 3 ]] || exit 1
grep -Fx 'alpha 2,500 7,500 0 0 12 1,520 0 0' "$fixture/rows"
grep -Fx 'beta 9 1 0 0 3 9 0 0' "$fixture/rows"
grep -Fx 'zero 0 0 0 0 5 1 0 0' "$fixture/rows"
grep -Fx 'TOTAL 2,509 7,501 0 0 20 1,530 0 0' "$fixture/rows"
grep -E '^beta +9 +1 \|' "$fixture/output"
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
{"data":{"r0":{"open":{"totalCount":9},"closed":{"totalCount":999999},"prRecent":{"nodes":[],"pageInfo":{"hasNextPage":false,"endCursor":null}},"prOpen":{"totalCount":9000},"prMerged":{"totalCount":1234567},"prClosed":{"totalCount":99},"recent":{"nodes":[],"pageInfo":{"hasNextPage":false,"endCursor":null}}},"r1":{"open":{"totalCount":100},"closed":{"totalCount":1},"prRecent":{"nodes":[],"pageInfo":{"hasNextPage":false,"endCursor":null}},"prOpen":{"totalCount":0},"prMerged":{"totalCount":0},"prClosed":{"totalCount":0},"recent":{"nodes":[],"pageInfo":{"hasNextPage":false,"endCursor":null}}},"r2":{"open":{"totalCount":9},"closed":{"totalCount":0},"prRecent":{"nodes":[],"pageInfo":{"hasNextPage":false,"endCursor":null}},"prOpen":{"totalCount":1},"prMerged":{"totalCount":2},"prClosed":{"totalCount":3},"recent":{"nodes":[],"pageInfo":{"hasNextPage":false,"endCursor":null}}}}}
JSON
run --once
check_layout 101 24
awk '{gsub(/\|/, " "); $1=$1; print}' "$fixture/output" > "$fixture/rows"
grep -Fx 'beta 100 1 0 0 0 0 0 0' "$fixture/rows"
grep -Fx 'alpha 9 999,999 0 0 9,000 1,234,666 0 0' "$fixture/rows"
awk '$1 ~ /^(alpha|beta|zero)$/ { print $1 }' "$fixture/output" > "$fixture/order"
printf '%s\n' beta alpha zero > "$fixture/expected-order"
cmp "$fixture/order" "$fixture/expected-order"

# Equal issue counts rank by open PRs numerically, regardless of closed counts.
jq '.data.r0.open.totalCount=9 | .data.r0.closed.totalCount=9990 |
    .data.r1.open.totalCount=1 | .data.r1.closed.totalCount=1000 | .data.r1.prOpen.totalCount=3 |
    .data.r2.open.totalCount=1 | .data.r2.closed.totalCount=1000 | .data.r2.prOpen.totalCount=12' \
    "$GITHUB_SIBLINGS_TEST_RESPONSE" > "$fixture/ranked"
cp "$fixture/ranked" "$GITHUB_SIBLINGS_TEST_RESPONSE"
run --once
awk '$1 ~ /^(alpha|beta|zero)$/ { print $1 }' "$fixture/output" > "$fixture/order"
printf '%s\n' alpha zero beta > "$fixture/expected-order"
cmp "$fixture/order" "$fixture/expected-order"

# Exact ties use repository name for a stable order.
jq '.data.r2.prOpen.totalCount=3' "$GITHUB_SIBLINGS_TEST_RESPONSE" > "$fixture/ranked"
cp "$fixture/ranked" "$GITHUB_SIBLINGS_TEST_RESPONSE"
run --once
awk '$1 ~ /^(alpha|beta|zero)$/ { print $1 }' "$fixture/output" > "$fixture/order"
printf '%s\n' alpha beta zero > "$fixture/expected-order"
cmp "$fixture/order" "$fixture/expected-order"

# PR-only work sorts above repositories with neither issues nor PRs open.
jq '.data[].open.totalCount=0 | .data.r0.prOpen.totalCount=0 |
    .data.r1.prOpen.totalCount=3 | .data.r2.prOpen.totalCount=12' \
    "$GITHUB_SIBLINGS_TEST_RESPONSE" > "$fixture/ranked"
cp "$fixture/ranked" "$GITHUB_SIBLINGS_TEST_RESPONSE"
run --once
awk '$1 ~ /^(alpha|beta|zero)$/ { print $1 }' "$fixture/output" > "$fixture/order"
printf '%s\n' zero beta alpha > "$fixture/expected-order"
cmp "$fixture/order" "$fixture/expected-order"

# A GraphQL partial response retains successful rows and fails the report.
cat > "$GITHUB_SIBLINGS_TEST_RESPONSE" <<'JSON'
{"data":{"r0":{"open":{"totalCount":2500},"closed":{"totalCount":7500},"prRecent":{"nodes":[],"pageInfo":{"hasNextPage":false,"endCursor":null}},"prOpen":{"totalCount":12},"prMerged":{"totalCount":1500},"prClosed":{"totalCount":20},"recent":{"nodes":[],"pageInfo":{"hasNextPage":false,"endCursor":null}}},"r1":null,"r2":{"open":{"totalCount":0},"closed":{"totalCount":0},"prRecent":{"nodes":[],"pageInfo":{"hasNextPage":false,"endCursor":null}},"prOpen":{"totalCount":5},"prMerged":{"totalCount":0},"prClosed":{"totalCount":1},"recent":{"nodes":[],"pageInfo":{"hasNextPage":false,"endCursor":null}}}},"errors":[{"message":"unavailable","path":["r1"]}]}
JSON
status=0
GITHUB_SIBLINGS_TEST_STATUS=1 run --once || status=$?
[[ "$status" == 1 ]] || exit 1
awk '{gsub(/\|/, " "); $1=$1; print}' "$fixture/output" > "$fixture/rows"
grep -Fx 'beta ERROR ERROR ERROR ERROR ERROR ERROR ERROR ERROR' "$fixture/rows"
grep -Fx 'TOTAL (partial) 2,500 7,500 0 0 17 1,521 0 0' "$fixture/rows"
awk '$1 ~ /^(alpha|beta|zero)$/ { print $1 }' "$fixture/output" > "$fixture/order"
printf '%s\n' alpha zero beta > "$fixture/expected-order"
cmp "$fixture/order" "$fixture/expected-order"
grep -F 'simulated GitHub failure' "$fixture/output"

# Invalid and missing observations must never become zero.
for response in '' 'not JSON' '{"data":{}}'; do
    printf '%s\n' "$response" > "$GITHUB_SIBLINGS_TEST_RESPONSE"
    status=0
    run --once || status=$?
    [[ "$status" == 1 ]] || exit 1
    awk '{gsub(/\|/, " "); $1=$1; print}' "$fixture/output" > "$fixture/rows"
    grep -Fx 'TOTAL (partial) ERROR ERROR ERROR ERROR ERROR ERROR ERROR ERROR' "$fixture/rows"
done
# Every issue/PR field must be a valid count. A failed PR read cannot silently
# turn into zero, or let the row's otherwise valid issue totals appear complete.
cat > "$fixture/valid-response" <<'JSON'
{"data":{"r0":{"open":{"totalCount":10},"closed":{"totalCount":20},"prRecent":{"nodes":[],"pageInfo":{"hasNextPage":false,"endCursor":null}},"prOpen":{"totalCount":2},"prMerged":{"totalCount":3},"prClosed":{"totalCount":4},"recent":{"nodes":[],"pageInfo":{"hasNextPage":false,"endCursor":null}}},"r1":{"open":{"totalCount":0},"closed":{"totalCount":0},"prRecent":{"nodes":[],"pageInfo":{"hasNextPage":false,"endCursor":null}},"prOpen":{"totalCount":0},"prMerged":{"totalCount":0},"prClosed":{"totalCount":0},"recent":{"nodes":[],"pageInfo":{"hasNextPage":false,"endCursor":null}}},"r2":{"open":{"totalCount":0},"closed":{"totalCount":0},"prRecent":{"nodes":[],"pageInfo":{"hasNextPage":false,"endCursor":null}},"prOpen":{"totalCount":0},"prMerged":{"totalCount":0},"prClosed":{"totalCount":0},"recent":{"nodes":[],"pageInfo":{"hasNextPage":false,"endCursor":null}}}}}
JSON
cp "$fixture/valid-response" "$GITHUB_SIBLINGS_TEST_RESPONSE"
run --once
check_layout 71 18
printf '%-10s  %4s  %6s | %5s  %6s | %4s  %6s | %5s  %6s\n' \
    alpha 10 20 0 0 2 7 0 0 > "$fixture/narrow-row"
grep '^alpha ' "$fixture/output" > "$fixture/actual-narrow-row"
cmp "$fixture/narrow-row" "$fixture/actual-narrow-row"
for field in open closed prOpen prMerged prClosed; do
    for invalid in null -1 1.5 '"2"'; do
        jq --arg field "$field" --argjson invalid "$invalid" \
            '.data.r0[$field].totalCount = $invalid' "$fixture/valid-response" > "$GITHUB_SIBLINGS_TEST_RESPONSE"
        status=0
        run --once || status=$?
        [[ "$status" == 1 ]] || exit 1
        awk '{gsub(/\|/, " "); $1=$1; print}' "$fixture/output" > "$fixture/rows"
        grep -Fx 'alpha ERROR ERROR ERROR ERROR ERROR ERROR ERROR ERROR' "$fixture/rows"
        grep -Fx 'TOTAL (partial) 0 0 0 0 0 0 0 0' "$fixture/rows"
    done
done
# Closed values remain counts rather than a closed/total ratio, including
# unavailable siblings and totals wider than individual repository counts.
jq '.data.r0.open.totalCount=86 | .data.r0.closed.totalCount=400 | .data.r1=null' \
    "$fixture/valid-response" > "$GITHUB_SIBLINGS_TEST_RESPONSE"
status=0
run --once || status=$?
[[ "$status" == 1 ]] || exit 1
grep -E '^alpha +86 +400 \|' "$fixture/output"
check_layout 78 24

# Fleet totals sum open and closed independently.
jq '.data.r0.open.totalCount=86 | .data.r0.closed.totalCount=400 |
    .data.r1.open.totalCount=200 | .data.r1.closed.totalCount=500' \
    "$fixture/valid-response" > "$GITHUB_SIBLINGS_TEST_RESPONSE"
run --once
grep -E '^alpha +86 +400 \|' "$fixture/output"
grep -E '^TOTAL +286 +900 \|' "$fixture/output"

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
awk '{gsub(/\|/, " "); $1=$1; print}' "$fixture/output" > "$fixture/rows"
grep -Fx 'alpha 10 20 3 2 2 7 0 0' "$fixture/rows"
grep -Fx 'TOTAL 10 21 3 3 2 7 0 0' "$fixture/rows"
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
    awk '{gsub(/\|/, " "); $1=$1; print}' "$fixture/output" > "$fixture/rows"
    grep -Fx 'alpha ERROR ERROR ERROR ERROR ERROR ERROR ERROR ERROR' "$fixture/rows"
done
cp "$fixture/valid-page" "$GITHUB_SIBLINGS_TEST_PAGE"
status=0
GITHUB_SIBLINGS_TEST_PAGE_STATUS=1 run --once || status=$?
[[ "$status" == 1 ]] || exit 1
# Daily PR activity uses event timestamps, not updatedAt; merges are not closed
# without merging, and reopened PRs are not counted as closures.
jq '.data.r0.prRecent = {
    nodes: [
        {state:"MERGED",createdAt:"2026-01-14T00:00:00Z",updatedAt:"2026-01-15T10:00:00Z",closedAt:"2026-01-15T05:00:00Z",mergedAt:"2026-01-15T05:00:00Z"},
        {state:"CLOSED",createdAt:"2026-01-15T05:00:00Z",updatedAt:"2026-01-15T09:00:00Z",closedAt:"2026-01-15T06:00:00Z",mergedAt:null},
        {state:"OPEN",createdAt:"2026-01-14T00:00:00Z",updatedAt:"2026-01-15T08:00:00Z",closedAt:null,mergedAt:null}],
    pageInfo:{hasNextPage:true,endCursor:"pr-one"}}' \
    "$fixture/valid-response" > "$GITHUB_SIBLINGS_TEST_RESPONSE"
cat > "$GITHUB_SIBLINGS_TEST_PR_PAGE" <<'JSON'
{"data":{"repository":{"prRecent":{"nodes":[{"state":"OPEN","createdAt":"2026-01-15T05:00:00Z","updatedAt":"2026-01-15T05:00:00Z","closedAt":null,"mergedAt":null},{"state":"MERGED","createdAt":"2026-01-14T00:00:00Z","updatedAt":"2026-01-15T04:59:59Z","closedAt":"2026-01-15T04:59:59Z","mergedAt":"2026-01-15T04:59:59Z"}],"pageInfo":{"hasNextPage":true,"endCursor":"older"}}}}}
JSON
run --once
awk '{gsub(/\|/, " "); $1=$1; print}' "$fixture/output" > "$fixture/rows"
grep -Fx 'alpha 10 20 0 0 2 7 2 2' "$fixture/rows"
grep -Fx 'TOTAL 10 20 0 0 2 7 2 2' "$fixture/rows"
[[ "$(wc -l < "$GITHUB_SIBLINGS_TEST_CALLS" | tr -d ' ')" == 2 ]]
grep -F 'orderBy: {field: UPDATED_AT, direction: DESC}' "$GITHUB_SIBLINGS_TEST_CALLS" >/dev/null
cp "$GITHUB_SIBLINGS_TEST_PR_PAGE" "$fixture/valid-pr-page"
# Stopping before older pages avoids scanning the repository's full history.
# Missing, failed and malformed PR pages invalidate the entire row.
for response in '{}' '{"errors":[{"message":"unavailable"}]}' \
    '{"data":{"repository":{"prRecent":{"nodes":[],"pageInfo":{"hasNextPage":true,"endCursor":"pr-one"}}}}}' \
    '{"data":{"repository":{"prRecent":{"nodes":[{"state":"MERGED","createdAt":"2026-01-15T05:00:00Z","updatedAt":"2026-01-15T05:00:00Z","closedAt":"2026-01-15T05:00:00Z","mergedAt":null}],"pageInfo":{"hasNextPage":false}}}}}'; do
    printf '%s\n' "$response" > "$GITHUB_SIBLINGS_TEST_PR_PAGE"
    status=0
    run --once || status=$?
    [[ "$status" == 1 ]]
    awk '{gsub(/\|/, " "); $1=$1; print}' "$fixture/output" > "$fixture/rows"
    grep -Fx 'alpha ERROR ERROR ERROR ERROR ERROR ERROR ERROR ERROR' "$fixture/rows"
    grep -Fx 'TOTAL (partial) 0 0 0 0 0 0 0 0' "$fixture/rows"
done
# A nonempty, recent page with the same cursor must not loop.
jq '.data.repository.prRecent.nodes |= [.[0]] |
    .data.repository.prRecent.pageInfo.endCursor="pr-one"' \
    "$fixture/valid-pr-page" > "$GITHUB_SIBLINGS_TEST_PR_PAGE"
status=0
run --once || status=$?
[[ "$status" == 1 ]]
cp "$fixture/valid-pr-page" "$GITHUB_SIBLINGS_TEST_PR_PAGE"
status=0
GITHUB_SIBLINGS_TEST_PR_PAGE_STATUS=1 run --once || status=$?
[[ "$status" == 1 ]]
# A missing initial PR connection is not zero activity.
jq 'del(.data.r0.prRecent)' "$fixture/valid-response" > "$GITHUB_SIBLINGS_TEST_RESPONSE"
status=0
run --once || status=$?
[[ "$status" == 1 ]]

# Redirected output stays plain even when TERM advertises colour.
cp "$fixture/valid-response" "$GITHUB_SIBLINGS_TEST_RESPONSE"
TERM=xterm-256color run --once
if LC_ALL=C grep -q $'\033' "$fixture/output"; then exit 1; fi

# Substitute only terminal detection to exercise coloured rows in this fixture.
plain_script="$script"
sed 's/^colour=false$/colour=true/' "$script" > "${script%.sh}-colour.sh"
script="${script%.sh}-colour.sh"
for scenario in gradient equal pr_only all_clear; do
    case "$scenario" in
        gradient) filter='.data.r1.open.totalCount=5' ;;
        equal) filter='.data.r1.open.totalCount=10 | .data.r1.closed.totalCount=10000' ;;
        pr_only) filter='.data.r0.open.totalCount=0' ;;
        all_clear) filter='.data.r0.open.totalCount=0 | .data.r0.prOpen.totalCount=0' ;;
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
    if (/^\e\[38;2;(\d+;\d+;\d+)m(\w+).*\e\[39m\n$/) {
        $colours{$2}=$1;
    } elsif (/\e/) { die "only repository foregrounds may be coloured\n"; }
}
die "missing coloured repositories\n" unless keys(%colours) == 3;
die "no open issues or PRs must be grey\n" unless $colours{zero} eq '144;144;144';
if ($scenario eq 'all_clear') {
    die "empty backlogs must all be grey\n" if grep { $_ ne $colours{zero} } values %colours;
} elsif ($scenario eq 'pr_only') {
    die "PR-only work must remain green\n" unless $colours{alpha} eq '170;214;186';
    die "empty backlog must be grey\n" unless $colours{beta} eq $colours{zero};
} else {
    die "largest backlog must be red\n" unless $colours{alpha} eq '238;180;180';
    my $expected=$scenario eq 'equal' ? $colours{alpha} : '238;220;160';
    die "colour must follow open counts alone\n" unless $colours{beta} eq $expected;
}
PERL
done
script="$plain_script"

# Full names fit exactly at 79 columns with these counts; one less must
# shorten them. Repeated invocations also cover shrinking and unknown widths.
cp "$fixture/valid-response" "$GITHUB_SIBLINGS_TEST_RESPONSE"
for columns in 79 78 120 0 invalid 9999999 79 78; do
    COLUMNS="$columns" run --once
    case "$columns" in
        79|120)
            grep -E '^dragginzgame/alpha +10 +20' "$fixture/output" >/dev/null
            awk '/^dragginzgame\// { if (length($0) > 79) exit 1 }' "$fixture/output"
            ;;
        *) grep -E '^alpha +10 +20' "$fixture/output" >/dev/null ;;
    esac
done
# Recalculate using larger values, not just repository-name length.
jq '.data.r0.prMerged.totalCount=1234567' "$fixture/valid-response" > "$GITHUB_SIBLINGS_TEST_RESPONSE"
COLUMNS=79 run --once
grep -E '^alpha +10 +20' "$fixture/output" >/dev/null
COLUMNS=109 run --once
grep -E '^dragginzgame/alpha +10 +20' "$fixture/output" >/dev/null

mkdir "$fixture/empty"
status=0
run --once "$fixture/empty" || status=$?
[[ "$status" == 1 && ! -s "$GITHUB_SIBLINGS_TEST_CALLS" ]] || exit 1
echo 'Sibling GitHub dashboard tests passed'
fixture_complete=true
