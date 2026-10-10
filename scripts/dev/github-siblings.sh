#!/usr/bin/env bash
set -euo pipefail

ROOT="$0"
[[ "$ROOT" == /* ]] || ROOT="$PWD/$ROOT"
ROOT="$(cd -P "${ROOT%/*}/../.." && printf '%s/.' "$PWD")"
ROOT="${ROOT%/.}"
export PATH="$ROOT/.tools/host/bin:$PATH"
export LC_ALL=C

usage() {
    cat <<'EOF'
Usage: github-siblings.sh [--once] [--interval SECONDS] [parent-directory]

Show GitHub issue and pull-request totals for Git checkouts with AGENTS.md and a
github.com origin. Defaults to the parent of this script's checkout. Symlink
aliases are skipped; duplicate GitHub repositories are counted once.

In a terminal, refresh every 60 seconds: q quits, r refreshes, Ctrl-C exits.
--once prints one report (also the default when input/output is not a terminal).
--interval selects 1..86400 seconds between completed refreshes.
Grouped headings show ISSUES (OPEN, FIXED), TODAY (FIXED, ADDED), and PRS (OPEN, MERGED, CLOSED).
FIXED shows closed / total, then percent in brackets; CLOSED PRs exclude merges.
Open PRs include drafts. Numeric padding starts at four characters and expands
to fit repository counts. Totals grow independently; headings/errors also fit.
Sort by percent fixed ascending, then open issues descending and name.
Repositories with no issues follow ranked rows; failed rows appear last.
Pale red-to-yellow-to-green row text marks completion in terminals.
NO_COLOR or TERM=dumb disables colour; redirected reports are always plain.
Fixed means closed, including duplicates and issues closed as not planned.
Percent fixed = closed / (open + closed); no issues shows N/A.
TODAY shows issues FIXED (currently closed, latest closure) and ADDED (created
in any state) since 06:00 Paris time, including daylight-saving changes. Before 06:00, use the previous day's cutoff.
Failed observations show ERROR, never zero; totals then show TOTAL (partial).
A partial/failed --once report exits nonzero. Watch mode retries next refresh.

Requires Bash 3.2+, Git, jq, Perl core, system timezone data, and an authenticated
GitHub CLI (gh auth login). Uses a batched read-only GraphQL request per refresh,
plus pagination for recently updated issues. Restart to rescan siblings.
EOF
}

once=false
interval=60
parent=''
while [[ $# -gt 0 ]]; do
    case "$1" in
        --once) once=true; shift ;;
        --interval)
            [[ $# -ge 2 ]] || { usage >&2; exit 2; }
            interval="$2"
            [[ "$interval" =~ ^[1-9][0-9]{0,4}$ ]] && [[ "$interval" -le 86400 ]] || {
                echo 'error: --interval must be an integer from 1 to 86400' >&2; exit 2;
            }
            shift 2 ;;
        -h|--help) usage; exit 0 ;;
        -*) usage >&2; exit 2 ;;
        *)
            [[ -z "$parent" ]] || { usage >&2; exit 2; }
            parent="$1"; shift ;;
    esac
done
parent="${parent:-$ROOT/..}"
[[ "$parent" == /* ]] || parent="$PWD/$parent"
parent="$(cd -P "$parent" && printf '%s/.' "$PWD")"
parent="${parent%/.}"
for tool in git gh jq sort awk perl; do
    command -v "$tool" >/dev/null 2>&1 || { echo "error: missing tool: $tool" >&2; exit 1; }
done

shopt -s nullglob dotglob
repos=()
repo_count=0
width=24
# GraphQL variables, not shell interpolation.
# shellcheck disable=SC2016
query='query($since: DateTime!) {'
for checkout in "${parent%/}"/*; do
    [[ -d "$checkout" && ! -L "$checkout" && -e "$checkout/.git" && -f "$checkout/AGENTS.md" ]] || continue
    remote="$(git -C "$checkout" remote get-url origin 2>/dev/null)" || continue
    case "$remote" in
        https://github.com/*) identity="${remote#https://github.com/}" ;;
        git@github.com:*) identity="${remote#git@github.com:}" ;;
        ssh://git@github.com/*) identity="${remote#ssh://git@github.com/}" ;;
        *) continue ;;
    esac
    identity="${identity%/}"
    identity="${identity%.git}"
    [[ "$identity" =~ ^[A-Za-z0-9_-]+/[A-Za-z0-9_.-]+$ ]] || {
        echo "error: invalid GitHub origin in $checkout" >&2; exit 1;
    }
    # GitHub owner/repository identities are case insensitive.
    identity="$(printf '%s' "$identity" | tr '[:upper:]' '[:lower:]')"
    duplicate=false
    for ((i=0; i<repo_count; i++)); do
        if [[ "${repos[$i]}" == "$identity" ]]; then duplicate=true; break; fi
    done
    [[ "$duplicate" == false ]] || continue
    repos+=("$identity")
    query="$query r$repo_count: repository(owner: \"${identity%/*}\", name: \"${identity#*/}\") {
        open: issues(states: OPEN) { totalCount }
        closed: issues(states: CLOSED) { totalCount }
        recent: issues(first: 100, filterBy: {since: \$since}) {
            nodes { state createdAt closedAt }
            pageInfo { hasNextPage endCursor }
        }
        prOpen: pullRequests(states: OPEN) { totalCount }
        prMerged: pullRequests(states: MERGED) { totalCount }
        prClosed: pullRequests(states: CLOSED) { totalCount }
    }"
    repo_count=$((repo_count + 1))
    [[ ${#identity} -le $width ]] || width=${#identity}
done
query="$query }"
[[ "$repo_count" -gt 0 ]] || { echo "error: no connected GitHub checkouts in $parent" >&2; exit 1; }

interactive=false
if [[ "$once" == false && -t 0 && -t 1 && "${TERM:-dumb}" != dumb ]]; then
    interactive=true
fi
colour=false
if [[ -t 1 && "${TERM:-dumb}" != dumb && -z "${NO_COLOR+x}" ]]; then colour=true; fi
scratch="$(mktemp -d "${TMPDIR:-/tmp}/github-siblings.XXXXXX")"
cleanup() {
    if [[ "$interactive" == true ]]; then printf '\033[?25h\033[?1049l'; fi
    rm -rf "$scratch"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

print_row() {
    printf '%s%-*s  %*s  %s  %*s  %*s  %*s  %*s  %*s%s\n' "${9:-}" "$width" "$1" "$open_width" "$2" "$3" \
        "$today_width" "$4" "$today_width" "$5" "$open_width" "$6" "$pr_result_width" "$7" "$pr_result_width" "$8" "${10:-}"
}
print_separator() {
    printf '%*s\n' "$((width + 6 + issues_width + today_group_width + prs_width))" '' | tr ' ' '-'
}
center_text() {
    local value="$1" span="$2" left
    left=$(((span - ${#value}) / 2))
    printf '%*s%s%*s' "$left" '' "$value" "$((span - ${#value} - left))" ''
}
format_count() {
    local value="$1" grouped=''
    # Group explicitly: LC_ALL=C and macOS locales need not supply separators.
    while [[ ${#value} -gt 3 ]]; do
        grouped=",${value: -3}$grouped"
        value="${value:0:${#value}-3}"
    done
    printf '%s%s' "$value" "$grouped"
}
format_percent() {
    local open="$1" closed="$2" total
    total=$((open + closed))
    if [[ "$total" -gt 0 ]]; then
        awk -v closed="$closed" -v total="$total" 'BEGIN { printf "(%.1f%%)", 100 * closed / total }'
    else
        printf '(N/A)'
    fi
}
measure_counts() {
    local value formatted percent
    for value in "$@" "$(($1 + $2))"; do
        formatted="$(format_count "$value")"
        [[ ${#formatted} -le "$number_width" ]] || number_width=${#formatted}
    done
    percent="$(format_percent "$1" "$2")"
    [[ ${#percent} -le "$percent_width" ]] || percent_width=${#percent}
}
# Calendar arithmetic, not subtracting 24 hours: the cutoff can cross DST.
# Perl's core POSIX functions use the same IANA timezone data on Linux/macOS.
day_cutoff() {
    TZ=Europe/Paris perl -MPOSIX=mktime,strftime,tzset -e '
        tzset();
        my $now = shift;
        my @local = localtime($now);
        my $cutoff = mktime(0, 0, 6, @local[3..5], 0, 0, -1);
        $cutoff = mktime(0, 0, 6, $local[3]-1, @local[4..5], 0, 0, -1)
            if $now < $cutoff;
        print strftime("%Y-%m-%dT%H:%M:%SZ", gmtime($cutoff));
    ' "$(date +%s)"
}

count_today() {
    local index="$1" page counts fixed added total_fixed=0 total_added=0 cursor='' next
    page="$(jq -c --arg key "r$index" '.data[$key].recent' "$scratch/response")" || return 1
    while :; do
        # A missing/invalid page is unavailable, not a zero or partial count.
        counts="$(jq -er --arg since "$cutoff" '
            def timestamp: type == "string" and
                test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$");
            select((.nodes | type == "array") and
                (.pageInfo.hasNextPage | type == "boolean") and
                all(.nodes[]; (.createdAt | timestamp) and
                    ((.state == "OPEN" and .closedAt == null) or
                     (.state == "CLOSED" and (.closedAt | timestamp))))) |
            [([.nodes[] | select(.state == "CLOSED" and .closedAt >= $since)] | length),
             ([.nodes[] | select(.createdAt >= $since)] | length)] | @tsv
        ' <<< "$page")" || return 1
        read -r fixed added <<< "$counts"
        total_fixed=$((total_fixed + fixed))
        total_added=$((total_added + added))
        [[ "$(jq -r '.pageInfo.hasNextPage' <<< "$page")" == true ]] || break
        next="$(jq -er '.pageInfo.endCursor | select(type == "string" and length > 0)' <<< "$page")" || return 1
        [[ "$next" != "$cursor" ]] || return 1
        cursor="$next"
        # shellcheck disable=SC2016
        if ! gh api graphql --hostname github.com -f query='
            query($owner: String!, $name: String!, $since: DateTime!, $after: String!) {
                repository(owner: $owner, name: $name) {
                    recent: issues(first: 100,
                        filterBy: {since: $since}, after: $after) {
                        nodes { state createdAt closedAt }
                        pageInfo { hasNextPage endCursor }
                    }
                }
            }' -f "owner=${repos[$index]%/*}" -f "name=${repos[$index]#*/}" \
            -f "since=$cutoff" -f "after=$cursor" > "$scratch/page" 2>> "$scratch/errors"; then
            return 1
        fi
        page="$(jq -ec 'select((.errors // []) | length == 0) | .data.repository.recent' "$scratch/page")" || return 1
    done
    printf '%s\t%s' "$total_fixed" "$total_added"
}

colour_fixed() {
    # Apply the pastel scale to foreground text, preserving the terminal background.
    awk -v open="$1" -v closed="$2" 'BEGIN {
        p = closed / (open + closed);
        if (p <= 0.5) { r=242; g=196+64*p; b=196-32*p }
        else { r=242-108*(p-0.5); g=228-8*(p-0.5); b=180+42*(p-0.5) }
        printf "\033[38;2;%d;%d;%dm", r, g, b;
    }'
}
print_counts() {
    local name="$1" open="$2" closed="$3" total fixed foreground='' reset=''
    local number_width="${9:-$number_width}"
    total=$((open + closed))
    printf -v fixed '%*s / %*s %-*s' "$number_width" "$(format_count "$closed")" \
        "$number_width" "$(format_count "$total")" "$percent_width" "$(format_percent "$open" "$closed")"
    printf -v fixed '%*s' "$fixed_width" "$fixed"
    if [[ "$colour" == true && "$total" -gt 0 ]]; then
        foreground="$(colour_fixed "$open" "$closed")"
        reset=$'\033[39m'
    fi
    print_row "$name" "$(format_count "$open")" "$fixed" \
        "$(format_count "$7")" "$(format_count "$8")" "$(format_count "$4")" "$(format_count "$5")" "$(format_count "$6")" "$foreground" "$reset"
}
print_error() {
    local fixed
    fixed="$(center_text ERROR "$fixed_width")"
    print_row "$1" ERROR "$fixed" ERROR ERROR ERROR ERROR ERROR
}

render() {
    local i counts name open closed pr_open pr_merged pr_closed today added day_counts rank total_open=0 total_closed=0
    local total_added=0 total_today=0 total_pr_open=0 total_pr_merged=0 total_pr_closed=0 successful=0 label=TOTAL
    local number_width=4 percent_width=5 fixed_width issues_width prs_width pr_result_width open_width today_width today_group_width total_number_width row_number_width
    printf 'Sibling GitHub issues and pull requests | %s\n' "$(date '+%Y-%m-%d %H:%M:%S %Z')"
    printf 'Issues: OPEN / FIXED. PRs: OPEN includes drafts; CLOSED excludes merged.\n'
    printf 'Fixed = closed issues. TODAY since %s (06:00 Paris time).\n' "$cutoff"
    printf 'Lowest percent fixed first. Refresh: %ss | q quit | r refresh\n\n' "$interval"
    : > "$scratch/rows"
    for ((i=0; i<repo_count; i++)); do
        if counts="$(jq -er --arg key "r$i" '
            def count: type == "number" and . >= 0 and . == floor;
            .data[$key] |
            [.open.totalCount, .closed.totalCount,
             .prOpen.totalCount, .prMerged.totalCount, .prClosed.totalCount] |
            select(all(.[]; count)) | @tsv
        ' "$scratch/response" 2>/dev/null)" && day_counts="$(count_today "$i" 2>> "$scratch/errors")"; then
            read -r open closed pr_open pr_merged pr_closed <<< "$counts"
            read -r today added <<< "$day_counts"
            measure_counts "$open" "$closed" "$pr_open" "$pr_merged" "$pr_closed" "$today" "$added"
            rank="$(awk -v o="$open" -v c="$closed" 'BEGIN { if (o+c) printf "%.12f", c/(o+c); else print 2 }')"
            printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$rank" "$open" "${repos[$i]}" "$closed" "$pr_open" "$pr_merged" "$pr_closed" "$today" "$added" >> "$scratch/rows"
            total_today=$((total_today + today))
            total_added=$((total_added + added))
            total_open=$((total_open + open))
            total_closed=$((total_closed + closed))
            total_pr_open=$((total_pr_open + pr_open))
            total_pr_merged=$((total_pr_merged + pr_merged))
            total_pr_closed=$((total_pr_closed + pr_closed))
            successful=$((successful + 1))
        else
            printf '3\t%s\t%s\t%s\n' -1 "${repos[$i]}" ERROR >> "$scratch/rows"
            status=1
        fi
    done
    row_number_width="$number_width"
    if [[ "$successful" -gt 0 ]]; then
        measure_counts "$total_open" "$total_closed" "$total_pr_open" "$total_pr_merged" "$total_pr_closed" "$total_today" "$total_added"
    fi
    total_number_width="$number_width"
    number_width="$row_number_width"
    open_width="$total_number_width"
    if [[ "$successful" -lt "$repo_count" && "$open_width" -lt 5 ]]; then open_width=5; fi
    today_width="$total_number_width"
    [[ "$today_width" -ge 5 ]] || today_width=5
    fixed_width=$((2 * total_number_width + 4 + percent_width))
    issues_width=$((open_width + 2 + fixed_width))
    today_group_width=$((2 * today_width + 2))
    pr_result_width="$total_number_width"
    [[ "$pr_result_width" -ge 6 ]] || pr_result_width=6
    prs_width=$((open_width + 4 + 2 * pr_result_width))
    sort -t $'\t' -k1,1n -k2,2nr -k3,3 "$scratch/rows" > "$scratch/sorted"
    printf '%*s  %s  %s  %s\n' "$width" '' "$(center_text ISSUES "$issues_width")" \
        "$(center_text TODAY "$today_group_width")" "$(center_text PRS "$prs_width")"
    print_row REPOSITORY "$(center_text OPEN "$open_width")" "$(center_text FIXED "$fixed_width")" \
        "$(center_text FIXED "$today_width")" "$(center_text ADDED "$today_width")" "$(center_text OPEN "$open_width")" "$(center_text MERGED "$pr_result_width")" "$(center_text CLOSED "$pr_result_width")"
    print_separator
    while IFS=$'\t' read -r rank open name closed pr_open pr_merged pr_closed today added; do
        if [[ "$open" == -1 ]]; then
            print_error "$name"
        else
            print_counts "$name" "$open" "$closed" "$pr_open" "$pr_merged" "$pr_closed" "$today" "$added"
        fi
    done < "$scratch/sorted"
    print_separator
    if [[ "$status" != 0 ]]; then label='TOTAL (partial)'; fi
    if [[ "$successful" -gt 0 ]]; then
        print_counts "$label" "$total_open" "$total_closed" "$total_pr_open" "$total_pr_merged" "$total_pr_closed" "$total_today" "$total_added" "$total_number_width"
    else
        print_error "$label"
    fi
    print_separator
    if [[ -s "$scratch/errors" ]]; then
        printf '\nGitHub diagnostics:\n'
        cat "$scratch/errors"
    fi
}

if [[ "$interactive" == true ]]; then
    printf '\033[?1049h\033[?25lLoading GitHub issue and pull-request counts...\n'
fi
while :; do
    status=0
    cutoff="$(day_cutoff)"
    # Read-only query, explicitly bound to github.com regardless of GH_HOST/GH_REPO.
    gh api graphql --hostname github.com -f "query=$query" -f "since=$cutoff" \
        > "$scratch/response" 2> "$scratch/errors" || status=1
    render > "$scratch/frame"
    if [[ "$interactive" == true ]]; then printf '\033[H\033[2J'; fi
    cat "$scratch/frame"
    if [[ "$interactive" == false ]]; then exit "$status"; fi
    key=''
    # Bash read restores terminal settings on timeout and signal; no stty state.
    if IFS= read -r -s -n 1 -t "$interval" key; then
        [[ "$key" != q && "$key" != Q ]] || exit 0
    fi
done
