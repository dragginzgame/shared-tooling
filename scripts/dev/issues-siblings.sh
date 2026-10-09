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
Usage: issues-siblings.sh [--once] [--interval SECONDS] [parent-directory]

Show GitHub issue totals for immediate Git checkouts with AGENTS.md and a
github.com origin. Defaults to the parent of this script's checkout. Symlink
aliases are skipped; duplicate GitHub repositories are counted once.

In a terminal, refresh every 60 seconds: q quits, r refreshes, Ctrl-C exits.
--once prints one report (also the default when input/output is not a terminal).
--interval selects 1..86400 seconds between completed refreshes.
Rows show REPOSITORY, OPEN and FIXED (closed / total, then percent in brackets).
Counts use comma separators and six-character, space-padded fields.
Sort by open issues descending, then repository name; failed rows appear last.
Fixed means closed, including duplicates and issues closed as not planned.
Percent fixed = closed / (open + closed); no issues shows N/A. PRs are excluded.
Failed observations show ERROR, never zero; totals then show TOTAL (partial).
A partial/failed --once report exits nonzero. Watch mode retries next refresh.

Requires Bash 3.2+, Git, jq, and an authenticated GitHub CLI (gh auth login).
Uses one read-only GitHub GraphQL request per refresh. Restart to rescan siblings.
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
for tool in git gh jq sort; do
    command -v "$tool" >/dev/null 2>&1 || { echo "error: missing tool: $tool" >&2; exit 1; }
done

shopt -s nullglob dotglob
repos=()
repo_count=0
width=24
query='query {'
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
scratch="$(mktemp -d "${TMPDIR:-/tmp}/issues-siblings.XXXXXX")"
cleanup() {
    if [[ "$interactive" == true ]]; then printf '\033[?25h\033[?1049l'; fi
    rm -rf "$scratch"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

print_row() {
    printf '%-*s  %6s  %s\n' "$width" "$1" "$2" "$3"
}
print_separator() {
    printf '%*s\n' "$((width + 34))" '' | tr ' ' '-'
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
print_counts() {
    local name="$1" open="$2" closed="$3" total fixed percent=N/A
    total=$((open + closed))
    if [[ "$total" -gt 0 ]]; then
        percent="$(awk -v closed="$closed" -v total="$total" 'BEGIN { printf "%.1f%%", 100 * closed / total }')"
    fi
    printf -v fixed '%6s / %6s (%s)' "$(format_count "$closed")" "$(format_count "$total")" "$percent"
    print_row "$name" "$(format_count "$open")" "$fixed"
}

render() {
    local i counts name open closed total_open=0 total_closed=0 successful=0 label=TOTAL
    printf 'Sibling GitHub issues | %s\n' "$(date '+%Y-%m-%d %H:%M:%S %Z')"
    printf 'Fixed = closed; PRs excluded. Refresh: %ss | q quit | r refresh\n\n' "$interval"
    : > "$scratch/rows"
    for ((i=0; i<repo_count; i++)); do
        if counts="$(jq -er --arg key "r$i" '
            def count: type == "number" and . >= 0 and . == floor;
            .data[$key] |
            select((.open.totalCount | count) and (.closed.totalCount | count)) |
            [.open.totalCount, .closed.totalCount] | @tsv
        ' "$scratch/response" 2>/dev/null)"; then
            read -r open closed <<< "$counts"
            printf '%s\t%s\t%s\n' "$open" "${repos[$i]}" "$closed" >> "$scratch/rows"
            total_open=$((total_open + open))
            total_closed=$((total_closed + closed))
            successful=$((successful + 1))
        else
            printf '%s\t%s\t%s\n' -1 "${repos[$i]}" ERROR >> "$scratch/rows"
            status=1
        fi
    done
    sort -t $'\t' -k1,1nr -k2,2 "$scratch/rows" > "$scratch/sorted"
    print_row REPOSITORY OPEN FIXED
    print_separator
    while IFS=$'\t' read -r open name closed; do
        if [[ "$open" == -1 ]]; then
            print_row "$name" ERROR ' ERROR /  ERROR (N/A)'
        else
            print_counts "$name" "$open" "$closed"
        fi
    done < "$scratch/sorted"
    print_separator
    if [[ "$status" != 0 ]]; then label='TOTAL (partial)'; fi
    if [[ "$successful" -gt 0 ]]; then
        print_counts "$label" "$total_open" "$total_closed"
    else
        print_row "$label" ERROR ' ERROR /  ERROR (N/A)'
    fi
    print_separator
    if [[ -s "$scratch/errors" ]]; then
        printf '\nGitHub diagnostics:\n'
        cat "$scratch/errors"
    fi
}

if [[ "$interactive" == true ]]; then
    printf '\033[?1049h\033[?25lLoading GitHub issue counts...\n'
fi
while :; do
    status=0
    # Read-only query, explicitly bound to github.com regardless of GH_HOST/GH_REPO.
    gh api graphql --hostname github.com -f "query=$query" \
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
