#!/usr/bin/env bash
# Shared companions: scripts/ci/fixture-lifecycle.sh scripts/ci/prepare-script-fixture.sh scripts/distribution/refresh-consumer.sh scripts/distribution/governance-files.txt scripts/ci/check-documentation-links.pl
set -euo pipefail
root="${BASH_SOURCE[0]}"
[[ "$root" == /* ]] || root="$PWD/$root"
root="$(cd -P "${root%/*}/../.." && printf '%s/.' "$PWD")"
root="${root%/.}"
git_context="$(git -C "$root" rev-parse --local-env-vars)"
while IFS= read -r variable; do unset "$variable"; done <<< "$git_context"
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
entrypoints=()
while IFS= read -r path; do
    [[ -n "$path" && "$path" != \#* ]] || continue
    entrypoints+=("$path")
done < "$root/scripts/distribution/governance-files.txt"
entrypoints+=(make/consumer.mk scripts/dev/cloc.sh)
# Qualify current working bytes without staging or committing the real checkout.
source_fixture="$fixture/source"
mkdir "$source_fixture"
bash "$root/scripts/ci/prepare-script-fixture.sh" "$root" "$source_fixture" \
    VERSION scripts/distribution/refresh-consumer.sh "${entrypoints[@]}"
git -C "$source_fixture" init -q
git -C "$source_fixture" remote add origin https://github.com/dragginzgame/shared-tooling
git -C "$source_fixture" -c core.hooksPath=/dev/null add .
git -C "$source_fixture" -c core.hooksPath=/dev/null -c commit.gpgsign=false \
    -c user.name=Fixture -c user.email=fixture@example.invalid commit -qm fixture
arguments=(--source "$source_fixture" --consumer "$consumer")
for path in "${entrypoints[@]}"; do arguments+=(--entrypoint "$path"); done
bash "$source_fixture/scripts/distribution/refresh-consumer.sh" "${arguments[@]}" > "$fixture/export.log" 2>&1
[[ ! -e "$consumer/docs/fleet-tools.md" && ! -e "$consumer/docs/stack.md" ]]
check_exported_docs() {
    local directory="$1" path documents=()
    while IFS= read -r path; do documents+=("${path#"$directory/"}"); done < <(find "$directory" -type f -name '*.md' -not -path '*/.git/*' | sort)
    perl "$root/scripts/ci/check-documentation-links.pl" --root "$directory" "${documents[@]}"
}
check_exported_docs "$consumer"
# Partial adopters must receive the local documents directly referenced by
# setup/adoption guidance, even without the complete governance entrypoint list.
for entry in docs/local-setup.md docs/consuming-snapshots.md; do
    partial="$fixture/partial-$(basename "$entry" .md)"
    mkdir "$partial"
    git -C "$partial" init -q
    printf '# Local instructions\n' > "$partial/AGENTS.md"
    printf '# Local readme\n' > "$partial/README.md"
    bash "$source_fixture/scripts/distribution/refresh-consumer.sh" --source "$source_fixture" \
        --consumer "$partial" --entrypoint "$entry" > "$partial-export.log" 2>&1
    check_exported_docs "$partial"
done
# Missing local targets must still fail in this actual exported context.
mv "$consumer/docs/make-interface.md" "$fixture/make-interface.md"
if perl "$root/scripts/ci/check-documentation-links.pl" --root "$consumer" \
    docs/local-setup.md > "$fixture/missing-target.log" 2>&1; then
    echo 'exported documentation accepted a missing local target' >&2
    exit 1
fi
fixture_complete=true
printf 'Canonical governance export links pass without central fleet payloads; missing local targets refuse.\n'
