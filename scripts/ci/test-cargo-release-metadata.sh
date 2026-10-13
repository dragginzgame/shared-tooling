#!/usr/bin/env bash
# Shared companions: scripts/ci/cargo-release-metadata.sh
set -Eeuo pipefail
ROOT="${BASH_SOURCE[0]}"
[[ "$ROOT" == /* ]] || ROOT="$PWD/$ROOT"
ROOT="$(cd -P "${ROOT%/*}/../.." && printf '%s/.' "$PWD")"
ROOT="${ROOT%/.}"
fixture="$(mktemp -d "${TMPDIR:-/tmp}/cargo-release-metadata-test.XXXXXX")"
complete=false
finish() {
    local status=$?
    [[ "$complete" == true || "$status" != 0 ]] || status=1
    if [[ "$status" == 0 ]]; then rm -rf "$fixture"
    else printf 'failed Cargo metadata fixture retained: %s\n' "$fixture" >&2; fi
    exit "$status"
}
trap finish EXIT
REAL_CARGO="$(command -v cargo)"
export REAL_CARGO
mkdir "$fixture/bin"
cat > "$fixture/bin/cargo" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
case "$1" in
    set-version)
        perl -pi -e 's/version = "1\.2\.3"/version = "1.2.4"/' Cargo.toml
        [[ "${CASE:-}" != set-failure ]] || exit 23
        ;;
    sort) [[ "${CASE:-}" != sort-failure ]] || exit 24 ;;
    metadata)
        if [[ "${CASE:-}" == check-failure ]] && grep -q 'version = "1.2.4"' Cargo.toml; then exit 25; fi
        exec "$REAL_CARGO" "$@"
        ;;
    *) exec "$REAL_CARGO" "$@" ;;
esac
STUB
chmod +x "$fixture/bin/cargo"
export PATH="$fixture/bin:$PATH"
export RELEASE_PREVIOUS=1.2.3 RELEASE_VERSION=1.2.4 RELEASE_DATE=2026-10-13
helper="$ROOT/scripts/ci/cargo-release-metadata.sh"
make_workspace() {
    local root="$1" package
    mkdir -p "$root/primary/src" "$root/secondary/src"
    cat > "$root/Cargo.toml" <<'TOML'
[workspace]
members = ["primary", "secondary"]
resolver = "3"
[workspace.package]
version = "1.2.3"
edition = "2024"
TOML
    for package in primary secondary; do
        cat > "$root/$package/Cargo.toml" <<TOML
[package]
name = "$package"
version.workspace = true
edition.workspace = true
TOML
        printf 'pub fn value() -> u64 { 0 }\n' > "$root/$package/src/lib.rs"
    done
    printf '# Changelog\n\n## [1.2.4]\n\n- Prepared change.\n\n## [1.2.3] - 2026-10-12\n\n- Previous.\n' > "$root/CHANGELOG.md"
    (cd "$root" && "$REAL_CARGO" generate-lockfile --offline > /dev/null)
}
mkdir "$fixture/success"
make_workspace "$fixture/success"
(cd "$fixture/success" && bash "$helper" prepare primary > "$fixture/success.log" 2>&1)
(cd "$fixture/success" && bash "$helper" check primary)
for package in primary secondary; do
    jq -e --arg name "$package" '.packages[] | select(.name == $name) | .version == "1.2.4"' \
        < <(cd "$fixture/success" && "$REAL_CARGO" metadata --offline --locked --format-version 1) > /dev/null
done
for mode in set-failure sort-failure check-failure literal-version unknown-local missing-member; do
    root="$fixture/$mode"
    make_workspace "$root"
    case "$mode" in
        literal-version) sed 's/version.workspace = true/version = "1.2.3"/' "$root/secondary/Cargo.toml" > "$fixture/literal"; cp "$fixture/literal" "$root/secondary/Cargo.toml" ;;
        unknown-local) printf '\n[[package]]\nname = "outside"\nversion = "1.2.3"\n' >> "$root/Cargo.lock" ;;
        missing-member) mv "$root/secondary/Cargo.toml" "$root/secondary/retained.toml" ;;
    esac
    mkdir "$root/originals"
    for file in Cargo.toml Cargo.lock CHANGELOG.md; do cp -p "$root/$file" "$root/originals/$file"; done
    status=0
    (cd "$root" && CASE="$mode" bash "$helper" prepare primary) > "$fixture/$mode.log" 2>&1 || status=$?
    [[ "$status" != 0 ]] || { echo "metadata failure case accepted: $mode" >&2; exit 1; }
    case "$mode" in set-failure) [[ "$status" == 23 ]] ;; sort-failure) [[ "$status" == 24 ]] ;; check-failure) [[ "$status" == 25 ]] ;; esac
    for file in Cargo.toml Cargo.lock CHANGELOG.md; do cmp "$root/$file" "$root/originals/$file"; done
    if [[ "$mode" != missing-member ]]; then
        grep -F 'evidence retained:' "$fixture/$mode.log" > /dev/null
    fi
done
# Check a frozen source even when newer working source is incomplete or different.
cd "$fixture/success"
git init -q
git -c user.name=fixture -c user.email=fixture@example.invalid add Cargo.toml Cargo.lock CHANGELOG.md primary secondary
git -c user.name=fixture -c user.email=fixture@example.invalid commit -qm prepared
commit="$(git rev-parse HEAD)"
index_before="$(git write-tree)"
printf 'broken current metadata\n' > Cargo.toml
mv secondary/Cargo.toml secondary/current-manifest.retained
RELEASE_COMMIT="$commit" bash "$helper" check primary
[[ "$(git rev-parse HEAD)" == "$commit" && "$(git write-tree)" == "$index_before" ]]
[[ "$(cat Cargo.toml)" == 'broken current metadata' && ! -e secondary/Cargo.toml ]]
echo 'Cargo metadata preparation, restoration, workspace admission and selected-commit checks passed (version/sort tools substituted).'
complete=true
