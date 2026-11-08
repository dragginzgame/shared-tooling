#!/usr/bin/env bash
# Shared companions: scripts/dev/cloc.sh scripts/ci/fixture-lifecycle.sh make/tools.mk
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd -P)"
export PATH="$ROOT/.tools/host/bin:$PATH"
unset CARGO_TARGET_DIR
FIXTURE="$(mktemp -d "${TMPDIR:-/tmp}/shared-cloc-siblings.XXXXXX")"
FIXTURE="$(cd "$FIXTURE" && pwd -P)"
# shellcheck source=scripts/ci/fixture-lifecycle.sh
source "$ROOT/scripts/ci/fixture-lifecycle.sh"
fixture_complete=false
trap 'fixture_finish "$?" "$FIXTURE" "Failed sibling LOC fixture retained"' EXIT
parent="$FIXTURE/parent [projects]"
mkdir -p "$parent/alpha repo/src" "$parent/zeta/src" "$parent/.notes" "$parent/not-a-repo" "$FIXTURE/gitdirs"
git init -q "$parent/alpha repo"
git init -q --separate-git-dir "$FIXTURE/gitdirs/zeta" "$parent/zeta"
git init -q "$parent/.notes"
ln -s "$parent/zeta" "$parent/alias"
long_name=icydb_testing_audit_default_empty_fixtures
for repo in 'alpha repo' zeta; do
    mkdir "$parent/$repo/.cargo"
    printf '[build]\ntarget-dir="output"\n' > "$parent/$repo/.cargo/config.toml"
    name=alpha; if [[ "$repo" == zeta ]]; then name="$long_name"; fi
    printf '[package]\nname="%s"\nversion="0.1.0"\n[workspace]\n' "$name" > "$parent/$repo/Cargo.toml"
    printf 'pub fn library() {}\n#[cfg(test)]\nmod tests { fn helper() {} }\n' > "$parent/$repo/src/lib.rs"
    cat > "$parent/$repo/Makefile" <<'MAKE'
$(error consumer Makefiles must never execute for LOC reporting)
MAKE
done
report() { bash "$ROOT/scripts/dev/cloc.sh" "$@"; }
report "$parent" > "$FIXTURE/summary"
(unset TMPDIR RUNNER_TEMP; report "$parent") > "$FIXTURE/default-scratch"
cmp "$FIXTURE/summary" "$FIXTURE/default-scratch"
[[ -d "$ROOT/target/tmp" && ! -d "$parent/target" ]]
[[ -d "$parent/alpha repo/output/tmp" && -d "$parent/zeta/output/tmp" ]]
(cd "$FIXTURE"; TMPDIR='relative scratch' report "$parent") > "$FIXTURE/relative-scratch"
cmp "$FIXTURE/summary" "$FIXTURE/relative-scratch"
[[ -d "$FIXTURE/relative scratch" && ! -e "$parent/zeta/relative scratch" ]]
report -d 0 "$parent" > "$FIXTURE/expanded"
report -d 1 "$parent" > "$FIXTURE/modules"
if grep -Eq '\(root\)|\(self\)' "$FIXTURE/modules"; then exit 1; fi
[[ "$(awk 'END {print $2,$3,$4,$5,$6,$7,$8}' "$FIXTURE/modules")" == '2 4 0 0 0 0 6' ]]
[[ "$(awk 'END {print $2,$3,$4,$5,$6,$7,$8}' "$FIXTURE/summary")" == '2 4 0 0 0 0 6' ]]
[[ "$(awk 'END {print $2,$3,$4,$5,$6,$7,$8}' "$FIXTURE/expanded")" == '2 4 0 0 0 0 6' ]]
awk -v width="$((${#long_name}+2))" 'NR==1 {n=length($0)} length($0)!=n {exit 1} END {if(n!=width+57)exit 1}' "$FIXTURE/expanded"
[[ "$(wc -l < "$FIXTURE/summary" | tr -d ' ')" == 7 ]]
[[ "$(wc -l < "$FIXTURE/expanded" | tr -d ' ')" == 9 ]]
[[ "$(head -1 "$FIXTURE/summary" | xargs)" == 'workspace/crate app/lib tests examples bench tooling ??? total' ]]
[[ "$(grep -Ec '^[- ]+$' "$FIXTURE/summary")" == 2 ]]
(cd "$parent" && report) > "$FIXTURE/default"
cmp "$FIXTURE/summary" "$FIXTURE/default"
make --no-print-directory -s -f "$ROOT/make/tools.mk" cloc SHARED_TOOLING_ROOT="$ROOT" CLOC_ROOT="$parent" CLOC_DEPTH=0 > "$FIXTURE/make"
cmp "$FIXTURE/expanded" "$FIXTURE/make"
ln -s "$parent" "$FIXTURE/parent-alias"
report "$FIXTURE/parent-alias" > "$FIXTURE/alias"
cmp "$FIXTURE/summary" "$FIXTURE/alias"
(cd "$FIXTURE" && CDPATH="$FIXTURE" report 'parent [projects]') > "$FIXTURE/relative"
cmp "$FIXTURE/summary" "$FIXTURE/relative"
# A failed child retains successful later rows and marks totals partial.
git init -q "$parent/middle-broken"
printf '[package\n' > "$parent/middle-broken/Cargo.toml"
if report "$parent" > "$FIXTURE/partial" 2> "$FIXTURE/partial.err"; then exit 1; fi
grep -F 'TOTAL (partial)' "$FIXTURE/partial" >/dev/null
grep -E 'middle-broken +ERROR' "$FIXTURE/partial" >/dev/null
[[ "$(awk 'END {print $3,$4,$5,$6,$7,$8,$9}' "$FIXTURE/partial")" == '2 4 0 0 0 0 6' ]]
# Reject ambiguous path bytes even through an alias.
for suffix in $'\n' $'\r'; do
    mkdir "$FIXTURE/invalid$suffix"
    ln -s "$FIXTURE/invalid$suffix" "$FIXTURE/invalid-alias"
    if report "$FIXTURE/invalid-alias" > "$FIXTURE/invalid.out" 2> "$FIXTURE/invalid.err"; then exit 1; fi
    [[ ! -s "$FIXTURE/invalid.out" ]]
    rm "$FIXTURE/invalid-alias"
done
mkdir "$FIXTURE/no-rust"
git init -q "$FIXTURE/no-rust/notes"
report "$FIXTURE/no-rust" > "$FIXTURE/no-rust.out"
grep -E '^TOTAL +n/a' "$FIXTURE/no-rust.out" >/dev/null
if report --json "$parent" > "$FIXTURE/rejected.json" 2>/dev/null; then exit 1; fi
[[ ! -s "$FIXTURE/rejected.json" ]]
echo 'Sibling category totals, alignment, Make wiring and partial failure passed'
fixture_complete=true
