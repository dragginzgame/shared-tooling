#!/usr/bin/env bash
# Shared companions: scripts/ci/archive-evidence.sh scripts/ci/collect-tool-evidence.sh scripts/ci/formatting-evidence.sh scripts/ci/verify-file-checksum.sh
set -euo pipefail
# Caller supplies outcome/source records, explicit top-level selection and custody.
[[ $# -ge 8 ]] || { echo 'usage: collect-native-diagnostics.sh CHECKOUT EVIDENCE OUTPUT FORMAT-ROOT TOOLS-OUTCOME HOST-PINS IC-PINS NAME...' >&2; exit 2; }
checkout="$1" evidence="$2" output="$3" format_root="$4" tools_outcome="$5" host_pins="$6" ic_pins="$7"
shift 7
helper_root="${BASH_SOURCE[0]%/*}"
[[ "$checkout" == /* && -d "$checkout" && "$evidence" == /* && -d "$evidence" ]] || exit 2
selection=()
for name in "$@"; do
    case "$name" in ''|.|..|*/*) exit 2 ;; esac
    if [[ -f "$evidence/$name" ]]; then selection+=("$evidence" "$name"); fi
done
[[ ${#selection[@]} != 0 ]] || exit 2
# The archive and its checksum are both new evidence; never replace a prior
# checksum entry or follow it into another file, even if it appears later.
[[ ! -e "$output.sha256" && ! -L "$output.sha256" ]] || {
    printf 'diagnostic checksum output already exists: %s.sha256\n' "$output" >&2
    exit 2
}
# Publish readable diagnostics first, even when full tool collection later fails.
bash "$helper_root/archive-evidence.sh" "$output" "${selection[@]}" || exit 2
(set -C; bash "$helper_root/verify-file-checksum.sh" --print sha256 "$output" > "$output.sha256") || exit 2
collection_status=0
if [[ "$tools_outcome" == failure ]]; then
    diagnostics="$(mktemp -d "$evidence/tool-evidence.XXXXXX")" || exit 2
    bash "$helper_root/collect-tool-evidence.sh" "$evidence/tool-candidates.tar.gz" \
        "$checkout" "$diagnostics" full "$host_pins" "$ic_pins" > /dev/null || collection_status=$?
    [[ "$collection_status" != 2 ]] || exit 2
fi
# shellcheck source=scripts/ci/formatting-evidence.sh
source "$helper_root/formatting-evidence.sh"
select_formatting_evidence "$format_root" || exit 2
if [[ ${#formatting_evidence[@]} != 0 ]]; then
    bash "$helper_root/archive-evidence.sh" "$evidence/formatting-logs.tar.gz" "${formatting_evidence[@]}" || exit 2
fi
exit "$collection_status"
