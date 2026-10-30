#!/usr/bin/env bash
set -euo pipefail

reject_line_breaks() {
    case "$1" in
        *$'\r'*|*$'\n'*) echo 'error: directory paths must not contain CR or LF' >&2; exit 1 ;;
    esac
}

ROOT="$0"
[[ "$ROOT" == /* ]] || ROOT="$PWD/$ROOT"
reject_line_breaks "${ROOT%/*}"
ROOT="$(cd -P "${ROOT%/*}/../.." && printf '%s/.' "$PWD")"
ROOT="${ROOT%/.}"
reject_line_breaks "$ROOT"
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
ISSUES and PRS each have OVERALL | TODAY groups separated by vertical bars.
Repository labels include dragginzgame/ only when the complete table fits the
terminal width (or an explicit COLUMNS value). Unknown widths use short names.
OVERALL shows OPEN, CLOSED; TODAY shows ADDED, CLOSED for both sections.
Closed PRs include merged PRs.
Open PRs include drafts. Numeric padding starts at four characters and expands
to fit repository counts. Totals grow independently; headings/errors also fit.
Sort by open issues descending, then open PRs descending, then name; errors last.
Rows with no open issues or PRs are grey. Otherwise pale green-to-yellow-to-red
text marks increasing open issue counts, relative to the largest backlog in
this report. Totals and errors stay uncoloured.
NO_COLOR or TERM=dumb disables colour; redirected reports are always plain.
Closed issues include duplicates and issues closed as not planned.
TODAY counts creations in any state and currently closed items whose latest
closure (or PR merge) is since the cutoff.
All use 06:00 Paris time, including daylight-saving changes. Before 06:00, use
the previous day's cutoff.
Failed observations show ERROR, never zero; totals then show TOTAL (partial).
A partial/failed --once report exits nonzero. Watch mode retries next refresh.

Requires Bash 3.2+, Git, jq, Perl core, system timezone data, and an authenticated
GitHub CLI (gh auth login). Uses a batched read-only GraphQL request per refresh,
plus pagination for recently updated issues and PRs. Restart to rescan siblings.
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
reject_line_breaks "$parent"
parent="$(cd -P "$parent" && printf '%s/.' "$PWD")"
parent="${parent%/.}"
reject_line_breaks "$parent"
for tool in git gh jq sort awk perl; do
    command -v "$tool" >/dev/null 2>&1 || { echo "error: missing tool: $tool" >&2; exit 1; }
done

shopt -s nullglob dotglob
repos=()
repo_count=0
short_width=10
full_width=10
# GraphQL variables, not shell interpolation.
# shellcheck disable=SC2016
query='query($since: DateTime!) {'
for checkout in "${parent%/}"/*; do
    [[ -d "$checkout" && ! -L "$checkout" && -e "$checkout/.git" && -f "$checkout/AGENTS.md" ]] || continue
    reject_line_breaks "$checkout"
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
        prRecent: pullRequests(first: 100, orderBy: {field: UPDATED_AT, direction: DESC}) {
            nodes { state createdAt updatedAt closedAt mergedAt }
            pageInfo { hasNextPage endCursor }
        }
        prOpen: pullRequests(states: OPEN) { totalCount }
        prMerged: pullRequests(states: MERGED) { totalCount }
        prClosed: pullRequests(states: CLOSED) { totalCount }
    }"
    repo_count=$((repo_count + 1))
    display_name="${identity#dragginzgame/}"
    [[ ${#display_name} -le $short_width ]] || short_width=${#display_name}
    [[ ${#identity} -le $full_width ]] || full_width=${#identity}
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
    printf '%s%-*s  %*s  %*s | %*s  %*s | %*s  %*s | %*s  %*s%s\n' "${10:-}" "$width" "$1" \
        "$open_width" "$2" "$closed_width" "$3" "$added_width" "$4" "$closed_width" "$5" \
        "$open_width" "$6" "$closed_width" "$7" "$added_width" "$8" "$closed_width" "$9" "${11:-}"
}
print_separator() {
    printf '%*s | %*s | %*s | %*s\n' "$((width + 2 + issues_width))" '' \
        "$today_group_width" '' "$prs_width" '' "$pr_today_width" '' | tr ' ' '-'
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
measure_counts() {
    local value formatted
    for value in "$@"; do
        formatted="$(format_count "$value")"
        [[ ${#formatted} -le "$number_width" ]] || number_width=${#formatted}
    done
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

# PR connections have no since filter. Walk newest updates first, stopping once
# a complete page reaches before the cutoff; event timestamps decide the counts.
count_pr_today() {
    local index="$1" page counts closed added total_closed=0 total_added=0 cursor='' next
    page="$(jq -c --arg key "r$index" '.data[$key].prRecent' "$scratch/response")" || return 1
    while :; do
        counts="$(jq -er --arg since "$cutoff" '
            def timestamp: type == "string" and
                test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$");
            select((.nodes | type == "array") and
                (.pageInfo.hasNextPage | type == "boolean") and
                all(.nodes[]; (.createdAt | timestamp) and (.updatedAt | timestamp) and
                    ((.state == "OPEN" and .closedAt == null and .mergedAt == null) or
                     (.state == "CLOSED" and (.closedAt | timestamp) and .mergedAt == null) or
                     (.state == "MERGED" and (.closedAt | timestamp) and (.mergedAt | timestamp))))) |
            [([.nodes[] | select((.state == "MERGED" and .mergedAt >= $since) or
                                (.state == "CLOSED" and .closedAt >= $since))] | length),
             ([.nodes[] | select(.createdAt >= $since)] | length)] | @tsv
        ' <<< "$page")" || return 1
        read -r closed added <<< "$counts"
        total_closed=$((total_closed + closed))
        total_added=$((total_added + added))
        [[ "$(jq -r '.pageInfo.hasNextPage' <<< "$page")" == true ]] || break
        # An empty page claiming continuation cannot establish completeness.
        jq -e '.nodes | length > 0' <<< "$page" >/dev/null || return 1
        if jq -e --arg since "$cutoff" 'any(.nodes[]; .updatedAt < $since)' <<< "$page" >/dev/null; then break; fi
        next="$(jq -er '.pageInfo.endCursor | select(type == "string" and length > 0)' <<< "$page")" || return 1
        [[ "$next" != "$cursor" ]] || return 1
        cursor="$next"
        # shellcheck disable=SC2016
        if ! gh api graphql --hostname github.com -f query='
            query($owner: String!, $name: String!, $after: String!) {
                repository(owner: $owner, name: $name) {
                    prRecent: pullRequests(first: 100, after: $after,
                        orderBy: {field: UPDATED_AT, direction: DESC}) {
                        nodes { state createdAt updatedAt closedAt mergedAt }
                        pageInfo { hasNextPage endCursor }
                    }
                }
            }' -f "owner=${repos[$index]%/*}" -f "name=${repos[$index]#*/}" \
            -f "after=$cursor" > "$scratch/pr-page" 2>> "$scratch/errors"; then
            return 1
        fi
        page="$(jq -ec 'select((.errors // []) | length == 0) | .data.repository.prRecent' "$scratch/pr-page")" || return 1
    done
    printf '%s\t%s' "$total_closed" "$total_added"
}

colour_open() {
    # Apply the pastel scale to foreground text, preserving the terminal background.
    awk -v open="$1" -v maximum="$2" 'BEGIN {
        p = maximum > 0 ? 1 - open / maximum : 1;
        if (p <= 0.5) { r=238; g=180+80*p; b=180-40*p }
        else { r=238-136*(p-0.5); g=220-12*(p-0.5); b=160+52*(p-0.5) }
        printf "\033[38;2;%d;%d;%dm", r, g, b;
    }'
}
print_counts() {
    local name="$1" open="$2" closed="$3" foreground='' reset=''
    if [[ "$colour" == true && $# == 9 ]]; then
        if [[ "$open" == 0 && "$4" == 0 ]]; then
            foreground=$'\033[38;2;144;144;144m'
        else
            foreground="$(colour_open "$open" "$max_open")"
        fi
        reset=$'\033[39m'
    fi
    print_row "$name" "$(format_count "$open")" "$(format_count "$closed")" \
        "$(format_count "$7")" "$(format_count "$6")" "$(format_count "$4")" \
        "$(format_count "$5")" "$(format_count "$9")" \
        "$(format_count "$8")" "$foreground" "$reset"
}
print_error() {
    print_row "$1" ERROR ERROR ERROR ERROR ERROR ERROR ERROR ERROR
}

render() {
    local width="$short_width" show_owner=false expanded_width="$full_width" table_width
    local i counts name open closed pr_open pr_closed today added day_counts total_open=0 total_closed=0
    local pr_today_closed pr_today_added pr_day_counts total_pr_today_closed=0 total_pr_today_added=0
    local total_added=0 total_today=0 total_pr_open=0 total_pr_closed=0 successful=0 label=TOTAL
    local pr_today_width
    local number_width=4 max_open=0 issues_width prs_width closed_width open_width added_width today_group_width
    printf 'Sibling GitHub issues and pull requests | %s\n' "$(date '+%Y-%m-%d %H:%M:%S %Z')"
    printf 'OVERALL: OPEN, CLOSED. TODAY: ADDED, CLOSED. Closed PRs include merges.\n'
    printf 'TODAY since %s (06:00 Paris time).\n' "$cutoff"
    printf 'Sort: open issues, then open PRs (descending). Refresh: %ss | q quit | r refresh\n\n' "$interval"
    : > "$scratch/rows"
    for ((i=0; i<repo_count; i++)); do
        if counts="$(jq -er --arg key "r$i" '
            def count: type == "number" and . >= 0 and . == floor;
            .data[$key] |
            [.open.totalCount, .closed.totalCount,
             .prOpen.totalCount, .prMerged.totalCount, .prClosed.totalCount] |
            select(all(.[]; count)) | [.[0], .[1], .[2], (.[3] + .[4])] | @tsv
        ' "$scratch/response" 2>/dev/null)" && day_counts="$(count_today "$i" 2>> "$scratch/errors")" &&
            pr_day_counts="$(count_pr_today "$i" 2>> "$scratch/errors")"; then
            read -r open closed pr_open pr_closed <<< "$counts"
            read -r today added <<< "$day_counts"
            read -r pr_today_closed pr_today_added <<< "$pr_day_counts"
            measure_counts "$open" "$closed" "$pr_open" "$pr_closed" "$today" "$added" "$pr_today_closed" "$pr_today_added"
            [[ "$open" -le "$max_open" ]] || max_open="$open"
            printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$open" "${repos[$i]}" "$closed" "$pr_open" "$pr_closed" "$today" "$added" "$pr_today_closed" "$pr_today_added" >> "$scratch/rows"
            total_pr_today_closed=$((total_pr_today_closed + pr_today_closed))
            total_pr_today_added=$((total_pr_today_added + pr_today_added))
            total_today=$((total_today + today))
            total_added=$((total_added + added))
            total_open=$((total_open + open))
            total_closed=$((total_closed + closed))
            total_pr_open=$((total_pr_open + pr_open))
            total_pr_closed=$((total_pr_closed + pr_closed))
            successful=$((successful + 1))
        else
            printf '%s\t%s\t%s\n' -1 "${repos[$i]}" ERROR >> "$scratch/rows"
            status=1
        fi
    done
    if [[ "$status" != 0 && "$width" -lt 15 ]]; then width=15; fi
    if [[ "$successful" -gt 0 ]]; then
        measure_counts "$total_open" "$total_closed" "$total_pr_open" "$total_pr_closed" "$total_today" "$total_added" "$total_pr_today_closed" "$total_pr_today_added"
    fi
    open_width="$number_width"
    if [[ "$successful" -lt "$repo_count" && "$open_width" -lt 5 ]]; then open_width=5; fi
    added_width="$number_width"
    [[ "$added_width" -ge 5 ]] || added_width=5
    closed_width="$number_width"
    [[ "$closed_width" -ge 6 ]] || closed_width=6
    issues_width=$((open_width + 2 + closed_width))
    today_group_width=$((added_width + 2 + closed_width))
    prs_width="$issues_width"
    pr_today_width="$today_group_width"
    [[ "$expanded_width" -ge "$width" ]] || expanded_width="$width"
    table_width=$((expanded_width + 2 + issues_width + today_group_width + prs_width + pr_today_width + 9))
    if [[ "$terminal_columns" -ge "$table_width" ]]; then
        width="$expanded_width"
        show_owner=true
    fi
    sort -t $'\t' -k1,1nr -k4,4nr -k2,2 "$scratch/rows" > "$scratch/sorted"
    printf '%*s  %s | %s\n' "$width" '' "$(center_text ISSUES "$((issues_width + 3 + today_group_width))")" \
        "$(center_text PRS "$((prs_width + 3 + pr_today_width))")"
    printf '%*s  %s | %s | %s | %s\n' "$width" '' "$(center_text OVERALL "$issues_width")" \
        "$(center_text TODAY "$today_group_width")" "$(center_text OVERALL "$prs_width")" "$(center_text TODAY "$pr_today_width")"
    print_row REPOSITORY "$(center_text OPEN "$open_width")" "$(center_text CLOSED "$closed_width")" \
        "$(center_text ADDED "$added_width")" "$(center_text CLOSED "$closed_width")" \
        "$(center_text OPEN "$open_width")" "$(center_text CLOSED "$closed_width")" \
        "$(center_text ADDED "$added_width")" "$(center_text CLOSED "$closed_width")"
    print_separator
    while IFS=$'\t' read -r open name closed pr_open pr_closed today added pr_today_closed pr_today_added; do
        [[ "$show_owner" == true ]] || name="${name#dragginzgame/}"
        if [[ "$open" == -1 ]]; then
            print_error "$name"
        else
            print_counts "$name" "$open" "$closed" "$pr_open" "$pr_closed" "$today" "$added" "$pr_today_closed" "$pr_today_added"
        fi
    done < "$scratch/sorted"
    print_separator
    if [[ "$status" != 0 ]]; then label='TOTAL (partial)'; fi
    if [[ "$successful" -gt 0 ]]; then
        print_counts "$label" "$total_open" "$total_closed" "$total_pr_open" "$total_pr_closed" "$total_today" "$total_added" "$total_pr_today_closed" "$total_pr_today_added" total
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
    # Probe before redirecting render output; remeasure on every refresh.
    terminal_columns="${COLUMNS:-0}"
    if [[ -t 1 ]]; then
        terminal_size="$(stty size <&1 2>/dev/null)" || terminal_size=''
        if [[ "$terminal_size" =~ ^[0-9]+[[:space:]]+([1-9][0-9]{0,5})$ ]]; then
            terminal_columns="${BASH_REMATCH[1]}"
        fi
    fi
    [[ "$terminal_columns" =~ ^[1-9][0-9]{0,5}$ ]] || terminal_columns=0
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
