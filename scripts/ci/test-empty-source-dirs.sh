#!/usr/bin/env bash
# Shared companions: scripts/dev/clean-empty-source-dirs.pl scripts/ci/fixture-lifecycle.sh
set -euo pipefail
ROOT="$(cd "${BASH_SOURCE[0]%/*}/../.." && pwd)"
mkdir -p "$ROOT/target/tmp"
fixture=$(mktemp -d "$ROOT/target/tmp/empty-source.XXXXXX")
source "$ROOT/scripts/ci/fixture-lifecycle.sh"
fixture_complete=false
trap 'fixture_finish "$?" "$fixture" "Empty source fixture retained"' EXIT
cd "$fixture"
git init -q
mkdir -p src/ignored/nested src/ordinary src/full src/tracked src/target/keep outside/empty
printf 'src/ignored/\nsrc/full/\nsrc/tracked/\nsrc/target/\n' > .gitignore
printf 'preserve\n' > src/full/file
printf 'tracked\n' > src/tracked/file
git add -f src/tracked/file
rm src/tracked/file
ln -s ../outside src/link
output=$(perl "$ROOT/scripts/dev/clean-empty-source-dirs.pl" src)
[[ "$output" == 'Deleted 2 empty ignored source directories.' ]]
[[ -d src && -d src/ordinary && -d src/tracked && -d src/target/keep && -d outside/empty && -L src/link && -f src/full/file ]]
[[ ! -e src/ignored ]]
[[ $(perl "$ROOT/scripts/dev/clean-empty-source-dirs.pl" src) == 'Deleted 0 empty ignored source directories.' ]]
for invalid in . ../outside src/link src/target; do
    if perl "$ROOT/scripts/dev/clean-empty-source-dirs.pl" "$invalid" > refusal.log 2>&1; then exit 1; fi
done
# Validate every root before deleting anything.
mkdir -p src/ignored
if perl "$ROOT/scripts/dev/clean-empty-source-dirs.pl" src missing > refusal.log 2>&1; then exit 1; fi
[[ -d src/ignored ]]
# Exercise the real Make preflight dependency, without release effects.
printf 'TOKO_TOOLING_ROOT := %s\ninclude %s/make/release.mk\nrelease-preflight:\n\t@test ! -e src/ignored\n' "$ROOT" "$ROOT" > Makefile
make --no-print-directory release-preflight
# Automatic discovery covers nested frontend sources and skips build artifacts.
mkdir -p frontend/src/ignored/nested crates/demo/src/ignored src/build/keep
printf 'frontend/src/ignored/\ncrates/demo/src/ignored/\nsrc/build/\n' >> .gitignore
[[ $(perl "$ROOT/scripts/dev/clean-empty-source-dirs.pl") == 'Deleted 3 empty ignored source directories.' ]]
[[ -d frontend/src && -d crates && -d src/build/keep ]]
mkdir empty-repo
cd empty-repo
git init -q
[[ $(perl "$ROOT/scripts/dev/clean-empty-source-dirs.pl") == 'Deleted 0 empty ignored source directories.' ]]
cd ..
fixture_complete=true
printf 'Empty source cleanup boundaries and Make routing passed.\n'
