#!/usr/bin/env bash
# Shared companions: scripts/ci/fixture-lifecycle.sh scripts/distribution/refresh-consumer.sh scripts/distribution/governance-files.txt scripts/ci/check-documentation-links.pl
set -euo pipefail
root="${BASH_SOURCE[0]}"
[[ "$root" == /* ]] || root="$PWD/$root"
root="$(cd -P "${root%/*}/../.." && printf '%s/.' "$PWD")"
root="${root%/.}"
# shellcheck source=scripts/ci/fixture-lifecycle.sh
source "$root/scripts/ci/fixture-lifecycle.sh"
mkdir -p "$root/target/qualification"
fixture="$(fixture_create "$root/target/qualification/exported-doc-links.XXXXXX")"
fixture_complete=false
trap 'fixture_finish "$?" "$fixture" "Exported documentation fixture retained"' EXIT
consumer="$fixture/consumer"
mkdir "$consumer"
git -C "$consumer" init -q
printf '# Consumer-owned readme\n' > "$consumer/README.md"
printf '# Consumer-owned instructions\n' > "$consumer/AGENTS.md"
arguments=(--source "$root" --revision "$(git -C "$root" rev-parse HEAD)" --consumer "$consumer")
while IFS= read -r path; do
    [[ -n "$path" && "$path" != \#* ]] || continue
    arguments+=(--entrypoint "$path")
done < "$root/scripts/distribution/governance-files.txt"
arguments+=(--entrypoint make/consumer.mk --entrypoint scripts/dev/cloc.sh)
bash "$root/scripts/distribution/refresh-consumer.sh" "${arguments[@]}" > "$fixture/export.log" 2>&1
[[ ! -e "$consumer/docs/fleet-tools.md" && ! -e "$consumer/docs/stack.md" ]]
documents=(docs/consuming-snapshots.md docs/local-setup.md docs/make-interface.md docs/principles/rust-code-hygiene.md)
perl "$root/scripts/ci/check-documentation-links.pl" --root "$consumer" "${documents[@]}"
# Missing local targets must still fail in this actual exported context.
mv "$consumer/docs/make-interface.md" "$fixture/make-interface.md"
if perl "$root/scripts/ci/check-documentation-links.pl" --root "$consumer" \
    docs/local-setup.md > "$fixture/missing-target.log" 2>&1; then
    echo 'exported documentation accepted a missing local target' >&2
    exit 1
fi
fixture_complete=true
printf 'Canonical governance export links pass without central fleet payloads; missing local targets refuse.\n'
