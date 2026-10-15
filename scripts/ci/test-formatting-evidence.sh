#!/usr/bin/env bash
# Shared companions: scripts/ci/formatting-evidence.sh scripts/ci/archive-evidence.sh scripts/ci/run-formatting.sh scripts/ci/fixture-lifecycle.sh
set -euo pipefail
ROOT="${BASH_SOURCE[0]}"
ROOT="$(cd -P "${ROOT%/*}/../.." && pwd)"
# shellcheck source=scripts/ci/fixture-lifecycle.sh
source "$ROOT/scripts/ci/fixture-lifecycle.sh"
# shellcheck source=scripts/ci/formatting-evidence.sh
source "$ROOT/scripts/ci/formatting-evidence.sh"
fixture="$(mktemp -d "${TMPDIR:-/tmp}/formatting-evidence.XXXXXX")"
fixture_complete=false
trap 'fixture_finish "$?" "$fixture" "Formatting evidence retained"' EXIT
mkdir "$fixture/log root" "$fixture/unpacked"
select_formatting_evidence "$fixture/log root"
[[ ${#formatting_evidence[@]} == 0 ]] || exit 1
status=0
RUNNER_TEMP="$fixture/log root" "$BASH" "$ROOT/scripts/ci/run-formatting.sh" --check \
    "$BASH" -c 'printf "formatter failed\n"; exit 23' > "$fixture/formatter.log" 2>&1 || status=$?
[[ "$status" == 23 ]] || exit 1
printf 'space/name diagnostic\n' > "$fixture/log root/formatting.space name"
ln -s "$fixture/outside" "$fixture/log root/formatting.dangling"
mkdir "$fixture/log root/formatting.directory"
mkfifo "$fixture/log root/formatting.fifo"
select_formatting_evidence "$fixture/log root/"
[[ ${#formatting_evidence[@]} == 6 ]] || exit 1
"$BASH" "$ROOT/scripts/ci/archive-evidence.sh" "$fixture/logs.tar.gz" "${formatting_evidence[@]}" > "$fixture/archive-path"
tar -xzf "$fixture/logs.tar.gz" -C "$fixture/unpacked"
cmp "$fixture/log root/formatting.space name" "$fixture/unpacked/formatting.space name"
[[ -L "$fixture/unpacked/formatting.dangling" && ! -e "$fixture/outside" ]] || exit 1
for log in "$fixture/log root"/formatting.*; do
    [[ ! -f "$log" ]] || cmp "$log" "$fixture/unpacked/${log##*/}"
done
formatting_evidence=(stale)
if select_formatting_evidence relative; then exit 1; fi
[[ ${#formatting_evidence[@]} == 0 ]] || exit 1
if select_formatting_evidence "$fixture/missing"; then exit 1; fi
if select_formatting_evidence "$fixture" extra; then exit 1; fi
fixture_complete=true
echo 'Formatter log selection and archive custody passed'
