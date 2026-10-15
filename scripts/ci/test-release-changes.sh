#!/usr/bin/env bash
# Shared companions: scripts/ci/collect-release-changes.sh scripts/ci/fixture-lifecycle.sh
set -euo pipefail
root="${BASH_SOURCE[0]}"
[[ "$root" == /* ]] || root="$PWD/$root"
root="$(cd -P "${root%/*}/../.." && pwd)"
collector="$root/scripts/ci/collect-release-changes.sh"
fixture="$(mktemp -d "${TMPDIR:-/tmp}/release-changes-fixture.XXXXXX")"
fixture_complete=false
# shellcheck source=scripts/ci/fixture-lifecycle.sh
source "$root/scripts/ci/fixture-lifecycle.sh"
trap 'fixture_finish "$?" "$fixture" "Failed release-change fixture retained"' EXIT
export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
mkdir "$fixture/repo" "$fixture/bin" "$fixture/scratch"
git init -q "$fixture/repo"
cd "$fixture/repo"
printf 'tracked\n' > tracked.txt
git add tracked.txt
git -c core.hooksPath=/dev/null -c user.name=fixture -c user.email=fixture@example.invalid commit -qm fixture
git tag v0.3.8
bash "$collector" v0.3.8 > "$fixture/observed"
[[ ! -s "$fixture/observed" ]] || exit 1
# A consumer may choose a scratch directory inside its worktree. The collector
# must not count its own newly allocated observation file as a source change.
mkdir scratch
TMPDIR="$PWD/scratch" bash "$collector" v0.3.8 > "$fixture/observed"
[[ ! -s "$fixture/observed" ]] || exit 1
printf 'modified\n' >> tracked.txt
printf '%s\0' tracked.txt > "$fixture/expected"
for path in 'space name' $'tab\tname' $'line\nname' 'quote"name' $'caf\303\251'; do
    printf 'untracked\n' > "$path"
    printf '%s\0' "$path" >> "$fixture/expected"
done
assert_paths() {
    perl -e '
        local $/;
        open my $a, "<", $ARGV[0] or die $!;
        open my $b, "<", $ARGV[1] or die $!;
        my $actual = join "\0", sort split /\0/, <$a>;
        my $expected = join "\0", sort split /\0/, <$b>;
        die "changed path bytes differ\n" unless $actual eq $expected;
    ' "$fixture/observed" "$fixture/expected"
}
git config core.quotePath true
bash "$collector" v0.3.8 > "$fixture/observed"
assert_paths
git add .
bash "$collector" > "$fixture/observed"
assert_paths
# Successful observations must leave the caller's staged bytes untouched.
cp .git/index "$fixture/index-before"
bash "$collector" v0.3.8 > "$fixture/observed"
cmp .git/index "$fixture/index-before"
if bash "$collector" v0.3.9 > "$fixture/observed" 2> "$fixture/error"; then exit 1; fi
[[ ! -s "$fixture/observed" ]] || exit 1
grep -Fq 'base does not resolve to a commit: v0.3.9' "$fixture/error"
REAL_GIT="$(command -v git)"
export REAL_GIT
cat > "$fixture/bin/git" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${MOVE_VERIFIED_TAG:-0}" == 1 && "$1" == rev-parse && "${2:-}" == --verify ]]; then
    "$REAL_GIT" "$@"
    "$REAL_GIT" tag -f v0.3.8 HEAD >/dev/null
    exit 0
fi
if [[ "$1" == "${FAIL_GIT_COMMAND:-}" ]]; then
    if [[ "$PARTIAL_OUTPUT" == 1 ]]; then
        case "$1" in describe) printf 'v0.3.8\n' ;; *) printf 'tracked.txt\0' ;; esac
    fi
    echo "injected $1 failure" >&2
    exit 37
fi
exec "$REAL_GIT" "$@"
STUB
chmod +x "$fixture/bin/git"
for command in diff ls-files describe; do
    for partial in 0 1; do
        args=(v0.3.8)
        if [[ "$command" == describe ]]; then args=(); fi
        status=0
        PATH="$fixture/bin:$PATH" TMPDIR="$fixture/scratch" FAIL_GIT_COMMAND="$command" PARTIAL_OUTPUT="$partial" \
            bash "$collector" ${args[@]+"${args[@]}"} > "$fixture/observed" 2> "$fixture/error" || status=$?
        [[ "$status" == 37 && ! -s "$fixture/observed" ]] || exit 1
        grep -Fq "injected $command failure" "$fixture/error"
        [[ -z "$(find "$fixture/scratch" -type f -print)" ]] || exit 1
        cmp .git/index "$fixture/index-before"
    done
done
# Move the selected tag after its verification. Both explicit and discovered
# selections must still compare against the originally verified commit.
original_base="$(git rev-parse v0.3.8)"
git -c core.hooksPath=/dev/null -c user.name=fixture -c user.email=fixture@example.invalid commit -qm changed
for selection in explicit discovered; do
    git tag -f v0.3.8 "$original_base" >/dev/null
    args=()
    if [[ "$selection" == explicit ]]; then args=(v0.3.8); fi
    PATH="$fixture/bin:$PATH" MOVE_VERIFIED_TAG=1 bash "$collector" ${args[@]+"${args[@]}"} > "$fixture/observed"
    [[ "$(git rev-parse v0.3.8)" == "$(git rev-parse HEAD)" ]] || exit 1
    assert_paths
done
git tag -d v0.3.8 >/dev/null
if bash "$collector" > "$fixture/observed" 2> "$fixture/error"; then exit 1; fi
[[ ! -s "$fixture/observed" ]] || exit 1
fixture_complete=true
echo 'Release-change byte preservation, complete observations and Git failure checks passed'
