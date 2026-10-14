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
REAL_CP="$(command -v cp)"
export REAL_CP
REAL_GIT="$(command -v git)"
export REAL_GIT
mkdir "$fixture/bin"
cat > "$fixture/bin/cargo" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
case "$1" in
    set-version|sort) echo 'preparation must not dispatch manifest mutation tools' >&2; exit 91 ;;
    metadata)
        if [[ "${CASE:-}" == interrupt ]] && grep -q 'version = "1.2.4"' Cargo.toml; then
            kill -TERM "$PPID"; exit 1
        fi
        if [[ "${CASE:-}" == graph-failure ]]; then
            "$REAL_CARGO" "$@"
            exit 37
        fi
        if [[ "${CASE:-}" == check-failure || "${CASE:-}" == restore-failure ]] && grep -q 'version = "1.2.4"' Cargo.toml; then exit 25; fi
        exec "$REAL_CARGO" "$@"
        ;;
    *) exec "$REAL_CARGO" "$@" ;;
esac
STUB
chmod +x "$fixture/bin/cargo"
cat > "$fixture/bin/git" <<'GIT'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${GIT_FAILURE:-}" == type && "$*" == cat-file\ -t\ * ]]; then
    printf 'commit\n'; exit 43
fi
if [[ "${GIT_FAILURE:-}" == export && "$1" == archive ]]; then
    "$REAL_GIT" "$@"; exit 43
fi
exec "$REAL_GIT" "$@"
GIT
chmod +x "$fixture/bin/git"
cat > "$fixture/bin/cp" <<'CP'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${CASE:-}" == restore-failure && "$1" == -p && "$2" == */cargo-release-backup.*/Cargo.lock ]]; then
    echo 'controlled lockfile restoration failure' >&2
    exit 43
fi
exec "$REAL_CP" "$@"
CP
chmod +x "$fixture/bin/cp"
REAL_PERL="$(command -v perl)"
export REAL_PERL
cat > "$fixture/bin/perl" <<'PERL'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-}" in
    */render-cargo-workspace-version.pl)
        if [[ "${CASE:-}" == renderer-failure ]]; then "$REAL_PERL" "$@"; exit 23; fi ;;
esac
exec "$REAL_PERL" "$@"
PERL
chmod +x "$fixture/bin/perl"
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
  version = "1.2.3" # Preserve this literal layout.
edition = "2024"
[workspace.dependencies.example]
version = "1.2.3"
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
    chmod 0640 "$root/Cargo.toml"
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
for mode in renderer-failure check-failure interrupt literal-version unknown-local missing-member; do
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
    case "$mode" in renderer-failure) [[ "$status" == 23 ]] ;; interrupt) [[ "$status" == 143 ]] ;; check-failure) [[ "$status" == 25 ]] ;; esac
    for file in Cargo.toml Cargo.lock CHANGELOG.md; do cmp "$root/$file" "$root/originals/$file"; done
    if [[ "$mode" != missing-member ]]; then
        grep -F 'evidence retained:' "$fixture/$mode.log" > /dev/null
    fi
done
# Successful preparation preserves all unrelated bytes and metadata modes.
grep -Fqx '  version = "1.2.4" # Preserve this literal layout.' "$fixture/success/Cargo.toml"
grep -Fqx 'version = "1.2.3"' "$fixture/success/Cargo.toml"
[[ "$(perl -e 'printf "%o", (stat($ARGV[0]))[2]&07777' "$fixture/success/Cargo.toml")" == 640 ]] || exit 1

# Generic notes and failure restoration belong to the metadata producer.
for mode in undated-history history-no-lf dated-notes conflicting-date conflicting-notes restore-failure missing-date missing-version; do
    root="$fixture/$mode"
    make_workspace "$root"
    case "$mode" in
        undated-history) perl -pi -e 's/## \[1\.2\.3\] - 2026-10-12/## [1.2.3]/' "$root/CHANGELOG.md" ;;
        history-no-lf) perl -0pi -e 's/\n\z//' "$root/CHANGELOG.md" ;;
        dated-notes) perl -pi -e 's/## \[1\.2\.4\]/## [1.2.4] - 2026-10-13/' "$root/CHANGELOG.md" ;;
        conflicting-date) perl -pi -e 's/## \[1\.2\.4\]/## [1.2.4] - 2026-10-11/' "$root/CHANGELOG.md" ;;
        conflicting-notes) perl -pi -e 's/## \[1\.2\.4\]/## [9.9.9]/' "$root/CHANGELOG.md" ;;
    esac
    mkdir "$root/originals" "$root/attempts"
    for file in Cargo.toml Cargo.lock CHANGELOG.md; do cp -p "$root/$file" "$root/originals/$file"; done
    status=0
    case "$mode" in
        missing-date) (cd "$root" && env -u RELEASE_DATE TMPDIR="$root/attempts" bash "$helper" prepare primary) ;;
        missing-version) (cd "$root" && env -u RELEASE_VERSION TMPDIR="$root/attempts" bash "$helper" prepare primary) ;;
        *) (cd "$root" && CASE="$mode" TMPDIR="$root/attempts" bash "$helper" prepare primary) ;;
    esac > "$fixture/$mode.log" 2>&1 || status=$?
    case "$mode" in
        undated-history|history-no-lf)
            [[ "$status" == 0 ]] || exit 1
            perl -pe 's/## \[1\.2\.4\](?: - 2026-10-13)?/## [1.2.4] - 2026-10-13/' \
                "$root/originals/CHANGELOG.md" > "$root/expected-notes"
            cmp "$root/expected-notes" "$root/CHANGELOG.md"
            (cd "$root" && bash "$helper" check primary)
            ;;
        restore-failure)
            [[ "$status" == 1 ]] || exit 1
            for file in Cargo.toml CHANGELOG.md; do cmp "$root/originals/$file" "$root/$file"; done
            if cmp -s "$root/originals/Cargo.lock" "$root/Cargo.lock"; then exit 1; fi
            set -- "$root/attempts/"cargo-release-backup.*
            [[ $# == 1 ]] || exit 1
            cmp "$1/candidate.lock" "$root/Cargo.lock"
            for file in Cargo.toml Cargo.lock CHANGELOG.md; do cmp "$root/originals/$file" "$1/$file"; done
            grep -F 'metadata restoration incomplete; originals retained:' "$fixture/$mode.log" > /dev/null
            ;;
        *)
            [[ "$status" != 0 ]] || exit 1
            for file in Cargo.toml Cargo.lock CHANGELOG.md; do cmp "$root/originals/$file" "$root/$file"; done
            ;;
    esac
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
for failure in type export; do
    status=0
    GIT_FAILURE="$failure" RELEASE_COMMIT="$commit" bash "$helper" check primary > "$fixture/git-$failure.log" 2>&1 || status=$?
    [[ "$status" == 43 ]] || { echo 'failed Git output was accepted or its status lost' >&2; exit 1; }
done
# Graph admission is independent of release notes and pending-version variables.
root="$fixture/graph"
make_workspace "$root"
rm "$root/CHANGELOG.md"
(cd "$root" && bash "$helper" check-graph primary)
for file in Cargo.toml Cargo.lock; do cp -p "$root/$file" "$root/$file.before"; done
status=0
(cd "$root" && CASE=graph-failure bash "$helper" check-graph primary) > "$fixture/graph-failure.log" 2>&1 || status=$?
[[ "$status" == 37 ]] || exit 1
for file in Cargo.toml Cargo.lock; do cmp "$root/$file" "$root/$file.before"; done
[[ ! -e "$root/CHANGELOG.md" ]] || exit 1
for mode in mixed-version extra-lock missing-lock unknown-primary; do
    root="$fixture/graph-$mode"
    make_workspace "$root"
    rm "$root/CHANGELOG.md"
    primary=primary
    case "$mode" in
        mixed-version)
            perl -pi -e 's/version.workspace = true/version = "1.2.2"/' "$root/secondary/Cargo.toml"
            (cd "$root" && "$REAL_CARGO" generate-lockfile --offline >/dev/null)
            ;;
        extra-lock) printf '\n[[package]]\nname = "outside"\nversion = "1.2.3"\n' >> "$root/Cargo.lock" ;;
        missing-lock) perl -0pi -e 's/\[\[package\]\]\nname = "secondary"\nversion = "1.2.3"\n//' "$root/Cargo.lock" ;;
        unknown-primary) primary=unknown ;;
    esac
    for file in Cargo.toml Cargo.lock; do cp -p "$root/$file" "$root/$file.before"; done
    if (cd "$root" && bash "$helper" check-graph "$primary") > "$fixture/graph-$mode.log" 2>&1; then
        echo "graph admission accepted $mode" >&2; exit 1
    fi
    for file in Cargo.toml Cargo.lock; do cmp "$root/$file" "$root/$file.before"; done
    [[ ! -e "$root/CHANGELOG.md" ]] || exit 1
done
echo 'Cargo metadata preparation, restoration, workspace admission and selected-commit checks passed (literal rendering; no manifest mutation tools).'
complete=true
