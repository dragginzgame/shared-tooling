#!/usr/bin/env bash
# Shared companions: scripts/ci/check-publication.sh scripts/ci/fixture-lifecycle.sh
set -euo pipefail
root="${BASH_SOURCE[0]}"
[[ "$root" == /* ]] || root="$PWD/$root"
root="$(cd -P "${root%/*}/../.." && printf '%s/.' "$PWD")"; root="${root%/.}"
fixture="$(mktemp -d "${TMPDIR:-/tmp}/publication-test.XXXXXX")"
fixture="$(CDPATH="" cd -P -- "$fixture" && printf '%s/.' "$PWD")"
fixture="${fixture%/.}"
# shellcheck source=scripts/ci/fixture-lifecycle.sh
source "$root/scripts/ci/fixture-lifecycle.sh"
fixture_complete=false
trap 'fixture_finish "$?" "$fixture" "Publication fixture retained"' EXIT
mkdir -p "$fixture/snapshot/scripts/ci" "$fixture/consumer" "$fixture/bin"
cp "$root/scripts/ci/check-publication.sh" "$fixture/snapshot/scripts/ci/"
export PUBLICATION_TEST_TRACE="$fixture/trace" PUBLICATION_TEST_CONSUMER="$fixture/consumer"
for helper in check-make-execution check-release-source read-cargo-workspace-version check-release-tag check-crates-io-version; do
 cat > "$fixture/snapshot/scripts/ci/$helper.sh" <<'HELPER'
#!/usr/bin/env bash
set -euo pipefail
[[ "$PWD" == "$PUBLICATION_TEST_CONSUMER" ]] || exit 48
name="${0##*/}"; printf '%s %s\n' "$name" "$*" >> "$PUBLICATION_TEST_TRACE"
case "$name" in
 check-release-source.sh) [[ "${PUBLICATION_TEST_SOURCE:-clean}" == clean && ! -e "$PUBLICATION_TEST_CONSUMER/dirty" ]] ;;
 read-cargo-workspace-version.sh) echo 1.2.3; [[ "${PUBLICATION_TEST_FAILURE:-}" != version ]] || exit 43 ;;
 check-release-tag.sh) [[ "${PUBLICATION_TEST_TAG:-annotated}" == annotated ]] ;;
 check-crates-io-version.sh) [[ "$*" == 'example-crate 1.2.3' ]] || exit 48; [[ "${PUBLICATION_TEST_RACE:-}" != source ]] || touch "$PUBLICATION_TEST_CONSUMER/dirty"; exit "${PUBLICATION_TEST_REGISTRY:-1}" ;;
 *) ;;
esac
HELPER
 done
cat > "$fixture/bin/git" <<'GIT'
#!/usr/bin/env bash
set -euo pipefail
printf 'git %s\n' "$*" >> "$PUBLICATION_TEST_TRACE"
case "$*" in
 'rev-parse --verify HEAD') if [[ "${PUBLICATION_TEST_RACE:-}" == head && "$(grep -c '^git rev-parse --verify HEAD' "$PUBLICATION_TEST_TRACE")" == 2 ]]; then printf '%040d\n' 3; else printf '%040d\n' 1; fi ;;
 'rev-parse --verify refs/tags/v1.2.3') if [[ "${PUBLICATION_TEST_RACE:-}" == tag && "$(grep -c '^git rev-parse --verify refs/tags/v1.2.3' "$PUBLICATION_TEST_TRACE")" == 2 ]]; then printf '%040d\n' 3; else printf '%040d\n' 2; fi ;;
 'remote get-url --push --all origin') if [[ "${PUBLICATION_TEST_REMOTE:-single}" == single ]]; then echo fixture-remote; else printf 'one\ntwo\n'; fi ;;
 'ls-remote --exit-code -- fixture-remote refs/tags/v1.2.3') printf '%040d\trefs/tags/v1.2.3\n' "${PUBLICATION_TEST_OBSERVED:-2}" ;;
 *) exit 48 ;;
esac
if [[ "${PUBLICATION_TEST_FAILURE:-}" == head && "$*" == 'rev-parse --verify HEAD' &&
      "$(grep -c '^git rev-parse --verify HEAD' "$PUBLICATION_TEST_TRACE")" == 2 ]]; then exit 43; fi
if [[ "${PUBLICATION_TEST_FAILURE:-}" == tag && "$*" == 'rev-parse --verify refs/tags/v1.2.3' &&
      "$(grep -c '^git rev-parse --verify refs/tags/v1.2.3' "$PUBLICATION_TEST_TRACE")" == 2 ]]; then exit 43; fi
if [[ "${PUBLICATION_TEST_FAILURE:-}" == remote && "$*" == 'remote get-url --push --all origin' ]]; then exit 43; fi
if [[ "${PUBLICATION_TEST_FAILURE:-}" == observation && "$1" == ls-remote ]]; then exit 43; fi
GIT
chmod +x "$fixture/bin/git"
export PATH="$fixture/bin:$PATH"
cd "$fixture/consumer"
checker="$fixture/snapshot/scripts/ci/check-publication.sh"
: > "$PUBLICATION_TEST_TRACE"
bash "$checker" example-crate origin
[[ "$(grep -c '^check-release-source.sh' "$PUBLICATION_TEST_TRACE")" == 2 ]] || exit 1
for mode in dirty tag remote mismatch present unknown; do
 : > "$PUBLICATION_TEST_TRACE"
 status=0
 case "$mode" in
 dirty) PUBLICATION_TEST_SOURCE=dirty bash "$checker" example-crate origin > "$fixture/$mode.log" 2>&1 || status=$? ;;
 tag) PUBLICATION_TEST_TAG=lightweight bash "$checker" example-crate origin > "$fixture/$mode.log" 2>&1 || status=$? ;;
 remote) PUBLICATION_TEST_REMOTE=multiple bash "$checker" example-crate origin > "$fixture/$mode.log" 2>&1 || status=$? ;;
 mismatch) PUBLICATION_TEST_OBSERVED=3 bash "$checker" example-crate origin > "$fixture/$mode.log" 2>&1 || status=$? ;;
 present) PUBLICATION_TEST_REGISTRY=0 bash "$checker" example-crate origin > "$fixture/$mode.log" 2>&1 || status=$? ;;
 unknown) PUBLICATION_TEST_REGISTRY=2 bash "$checker" example-crate origin > "$fixture/$mode.log" 2>&1 || status=$? ;;
 esac
 [[ "$status" != 0 ]] || exit 1
 if [[ "$mode" == dirty || "$mode" == tag || "$mode" == remote || "$mode" == mismatch ]]; then
  ! grep -q '^check-crates-io-version.sh' "$PUBLICATION_TEST_TRACE" || exit 1
 fi
done
for failure in version head tag remote observation; do
 : > "$PUBLICATION_TEST_TRACE"
 status=0
 PUBLICATION_TEST_FAILURE="$failure" bash "$checker" example-crate origin > "$fixture/failure-$failure.log" 2>&1 || status=$?
 [[ "$status" != 0 ]] || { echo "failed observation accepted: $failure" >&2; exit 1; }
 case "$failure" in
  version|head|tag) [[ "$status" == 43 ]] || exit 1 ;;
 esac
 if [[ "$failure" == version || "$failure" == remote || "$failure" == observation ]]; then
  ! grep -q '^check-crates-io-version.sh' "$PUBLICATION_TEST_TRACE" || exit 1
 fi
done
for race in source head tag; do
 : > "$PUBLICATION_TEST_TRACE"
 if PUBLICATION_TEST_RACE="$race" bash "$checker" example-crate origin > "$fixture/race-$race.log" 2>&1; then exit 1; fi
 rm -f "$PUBLICATION_TEST_CONSUMER/dirty"
done
if bash "$checker" 'bad crate'  origin > "$fixture/invalid.log" 2>&1; then exit 1; fi
if bash "$checker" example-crate --push > "$fixture/invalid-remote.log" 2>&1; then exit 1; fi
for suffix in $'\n' $'\r'; do
 bad="$fixture/bad$suffix"
 mkdir "$bad"
 if (cd "$bad" && bash "$checker" example-crate origin) > "$fixture/bad-path.log" 2>&1; then exit 1; fi
 grep -F 'directory contains CR/LF' "$fixture/bad-path.log" > /dev/null
 ln -s "$bad" "$fixture/alias"
 if (cd "$fixture/alias" && bash "$checker" example-crate origin) > "$fixture/alias-path.log" 2>&1; then exit 1; fi
 grep -F 'directory contains CR/LF' "$fixture/alias-path.log" > /dev/null
 rm "$fixture/alias"
 rmdir "$bad"
done
fixture_complete=true
echo 'Publication admission ordering passed (substitute observations; no upload or Git writes)'
