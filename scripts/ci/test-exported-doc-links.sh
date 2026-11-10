#!/usr/bin/env bash
# Shared companions: scripts/ci/fixture-lifecycle.sh scripts/ci/prepare-script-fixture.sh scripts/distribution/refresh-consumer.sh scripts/distribution/governance-files.txt scripts/ci/check-documentation-links.pl scripts/ci/verify-file-checksum.sh scripts/ci/verify-toko-tooling-snapshot.sh .githooks/pre-commit
set -euo pipefail
consumer_only=false
case "${1:-}" in
    '') baseline_only=false ;;
    --baseline-only) baseline_only=true ;;
    --consumer-only) baseline_only=false; consumer_only=true ;;
    *) echo 'usage: test-exported-doc-links.sh [--baseline-only|--consumer-only]' >&2; exit 2 ;;
esac
root="${BASH_SOURCE[0]}"
[[ "$root" == /* ]] || root="$PWD/$root"
root="$(cd -P "${root%/*}/../.." && printf '%s/.' "$PWD")"
root="${root%/.}"
if [[ $# == 0 ]]; then bash "$root/scripts/ci/test-exported-doc-links.sh" --consumer-only; fi
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
if [[ "$baseline_only" == true ]]; then entrypoints=(TOKO-TOOLING.md); fi
if [[ "$consumer_only" == true ]]; then
    entrypoints=(make/consumer.mk TOKO-TOOLING.md scripts/ci/verify-file-checksum.sh
        .githooks/pre-commit rules/git-hooks.md rules/cargo-dependencies.md)
fi
# Qualify current working bytes without staging or committing the real checkout.
source_fixture="$fixture/source"
mkdir "$source_fixture"
bash "$root/scripts/ci/prepare-script-fixture.sh" "$root" "$source_fixture" \
    Cargo.toml scripts/distribution/refresh-consumer.sh scripts/ci/verify-file-checksum.sh \
    scripts/ci/verify-toko-tooling-snapshot.sh "${entrypoints[@]}"
git -C "$source_fixture" init -q
git -C "$source_fixture" remote add origin https://github.com/dragginzgame/toko-tooling
git -C "$source_fixture" -c core.hooksPath=/dev/null add .
git -C "$source_fixture" -c core.hooksPath=/dev/null -c commit.gpgsign=false \
    -c user.name=Fixture -c user.email=fixture@example.invalid commit -qm fixture
arguments=(--source "$source_fixture" --consumer "$consumer")
for path in "${entrypoints[@]}"; do arguments+=(--entrypoint "$path"); done
bash "$source_fixture/scripts/distribution/refresh-consumer.sh" "${arguments[@]}" > "$fixture/export.log" 2>&1
[[ ! -e "$consumer/docs/fleet/fleet-tools.md" && ! -e "$consumer/docs/fleet/stack.md" ]]
check_exported_docs() {
    local directory="$1" path documents=()
    while IFS= read -r path; do documents+=("${path#"$directory/"}"); done < <(find "$directory" -type f -name '*.md' -not -path '*/.git/*' | sort)
    perl "$root/scripts/ci/check-documentation-links.pl" --root "$directory" "${documents[@]}"
}
if [[ "$consumer_only" == true ]]; then
    # Retire the reported reference roots through a complete retained selection.
    # Native documents must survive, even beside removed shared documents.
    mkdir -p "$consumer/docs"
    printf '# Product guide\n' > "$consumer/docs/product.md"
    printf '[Product](docs/product.md)\n' >> "$consumer/README.md"
    arguments=(--source "$source_fixture" --consumer "$consumer")
    for path in make/consumer.mk TOKO-TOOLING.md scripts/ci/verify-file-checksum.sh .githooks/pre-commit; do
        arguments+=(--entrypoint "$path")
    done
    bash "$source_fixture/scripts/distribution/refresh-consumer.sh" "${arguments[@]}" > "$fixture/retirement.log" 2>&1
    [[ ! -e "$consumer/rules/git-hooks.md" && ! -e "$consumer/rules/cargo-dependencies.md" ]]
    [[ -f "$consumer/docs/product.md" && -f "$consumer/.githooks/pre-commit" ]]
    check_exported_docs "$consumer"
    # Both refusal routes must work without a vendored guide and name the same
    # immutable online migration instructions before any release effects.
    printf 'TOKO_TOOLING_RELEASE := 1\ninclude make/consumer.mk\n' > "$consumer/Makefile"
    if make -C "$consumer" RELEASE_FROZEN_GROUPS=alpha release-preflight > "$fixture/make-refusal.log" 2>&1; then exit 1; fi
    if RELEASE_FROZEN_GROUPS=alpha perl "$consumer/scripts/ci/run-release-batch.pl" --root "$consumer" --groups alpha > "$fixture/perl-refusal.log" 2>&1; then exit 1; fi
    guide_pattern='https://github.com/dragginzgame/toko-tooling/blob/[0-9a-f]{40}/docs/releases/release-batches[.]md'
    make_guide=$(grep -Eo "$guide_pattern" "$fixture/make-refusal.log")
    perl_guide=$(grep -Eo "$guide_pattern" "$fixture/perl-refusal.log")
    [[ -n "$make_guide" && "$make_guide" == "$perl_guide" ]]
    fixture_complete=true
    echo 'Consumer reference retirement preserves native docs, valid links and pinned release diagnostics'
    exit 0
fi
check_exported_docs "$consumer"
if [[ "$baseline_only" == true ]]; then
    [[ ! -e "$consumer/audits" && ! -e "$consumer/tasks" && ! -e "$consumer/docs" && ! -e "$consumer/rules" ]]
    # The baseline and the two mandatory integrity verifiers are the whole payload.
    [[ "$(awk -F '\t' '$1 == "file" {n++} END {print n}' "$consumer/.toko-tooling.snapshot")" == 3 ]]
    grep -Eq 'https://github.com/dragginzgame/toko-tooling/blob/[0-9a-f]{40}/rules/' "$consumer/TOKO-TOOLING.md"
    fixture_complete=true
    echo 'Standalone baseline export has valid links and only integrity companions'
    exit 0
fi
# Partial adopters must receive the local documents directly referenced by
# setup/adoption guidance, even without the complete governance entrypoint list.
for entry in docs/adoption/local-setup.md docs/adoption/consuming-snapshots.md; do
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
mv "$consumer/docs/adoption/make-interface.md" "$fixture/make-interface.md"
if perl "$root/scripts/ci/check-documentation-links.pl" --root "$consumer" \
    docs/adoption/local-setup.md > "$fixture/missing-target.log" 2>&1; then
    echo 'exported documentation accepted a missing local target' >&2
    exit 1
fi
fixture_complete=true
printf 'Canonical governance export links pass without central fleet payloads; missing local targets refuse.\n'
