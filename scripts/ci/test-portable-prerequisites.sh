#!/usr/bin/env bash
# Shared companions: scripts/ci/fixture-lifecycle.sh
set -euo pipefail
ROOT="$0"
[[ "$ROOT" == /* ]] || ROOT="$PWD/$ROOT"
ROOT="$(cd -P "${ROOT%/*}/../.." && printf '%s/.' "$PWD")"
ROOT="${ROOT%/.}"
fixture="$(mktemp -d "${TMPDIR:-/tmp}/portable-prerequisites-test.XXXXXX")"
fixture="$(CDPATH="" cd -P -- "$fixture" && printf '%s/.' "$PWD")"
fixture="${fixture%/.}"
# shellcheck source=scripts/ci/fixture-lifecycle.sh
source "$ROOT/scripts/ci/fixture-lifecycle.sh"
fixture_complete=false
trap 'fixture_finish "$?" "$fixture" "Prerequisite fixtures retained"' EXIT
# Own these inputs instead of borrowing an enclosing suite's admitted editor.
printf '#!/bin/sh\necho editor-must-not-execute >&2\nexit 97\n' > "$fixture/editor"
chmod +x "$fixture/editor"
export CARGO_RELEASE_METADATA_EDITOR="$fixture/editor" CARGO_RELEASE_METADATA_MAX_BYTES=1
mkdir "$fixture/missing" "$fixture/formatter"
ln -s "$BASH" "$fixture/missing/bash"
ln -s "$(command -v dirname)" "$fixture/missing/dirname"
cat > "$fixture/missing/mktemp" <<'SCRIPT'
#!/usr/bin/env bash
echo 'fixture started before prerequisite admission' >&2
exit 97
SCRIPT
chmod +x "$fixture/missing/mktemp"
status=0
PATH="$fixture/missing" "$BASH" "$ROOT/scripts/ci/test-portable-tools.sh" > "$fixture/missing.log" 2>&1 || status=$?
[[ "$status" == 1 ]] || exit 1
grep -Fx 'Missing portable-test prerequisite: cloc' "$fixture/missing.log"
grep -Fx 'Missing portable-test prerequisite: yq' "$fixture/missing.log"
grep -F 'docs/local-setup.md' "$fixture/missing.log"
if grep -F 'fixture started' "$fixture/missing.log"; then exit 1; fi

# Real available tools plus an unprepared formatter must fail offline before tests.
cat > "$fixture/formatter/cargo" <<'SCRIPT'
#!/usr/bin/env bash
[[ "$CARGO_NET_OFFLINE" == true && "$RUSTUP_AUTO_INSTALL" == 0 ]] || exit 90
[[ "$*" == 'sort --version' ]] || exit 91
echo 'cargo-sort 0.0.0'
SCRIPT
chmod +x "$fixture/formatter/cargo"
status=0
PATH="$fixture/formatter:$PATH" bash "$ROOT/scripts/ci/check-portable-prerequisites.sh" > "$fixture/formatter.log" 2>&1 || status=$?
[[ "$status" == 1 ]] || exit 1
grep -F 'Formatting requires prepared cargo-sort' "$fixture/formatter.log"
grep -F 'no tools were installed' "$fixture/formatter.log"
mkdir "$fixture/module"
PREREQUISITE_REAL_PERL="$(command -v perl)"
export PREREQUISITE_REAL_PERL
cat > "$fixture/module/perl" <<'SCRIPT'
#!/usr/bin/env bash
if [[ "${1:-}" == -MArchive::Tar ]]; then exit 37; fi
exec "$PREREQUISITE_REAL_PERL" "$@"
SCRIPT
chmod +x "$fixture/module/perl"
status=0
PATH="$fixture/module:$PATH" bash "$ROOT/scripts/ci/check-portable-prerequisites.sh" > "$fixture/module.log" 2>&1 || status=$?
[[ "$status" == 1 ]] || exit 1
grep -F 'Portable tests require Perl Archive::Tar' "$fixture/module.log"
# Complete prerequisite admission before suite allocation, including missing or
# malformed editor inputs. The selected executable must never be probed here.
mkdir "$fixture/ready" "$fixture/ready-bin"
cat > "$fixture/ready-bin/cargo" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
case "$*" in
    'sort --version') printf 'cargo-sort %s\n' "$PREREQUISITE_SORT_VERSION" ;;
    'fmt --version') printf 'rustfmt fixture\n' ;;
    *) exit 91 ;;
esac
SCRIPT
chmod +x "$fixture/ready-bin/cargo"
cp "$fixture/missing/mktemp" "$fixture/ready-bin/mktemp"
record="$(perl "$ROOT/scripts/ci/tool-catalog-records.pl" rust "$ROOT/ci/tool-versions.env" CARGO_SORT)"
IFS=$'\t' read -r _ PREREQUISITE_SORT_VERSION _ _ <<< "$record"
export PREREQUISITE_SORT_VERSION
for mode in missing-editor relative missing-file directory non-executable newline carriage-return missing-limit zero invalid success; do (
    case "$mode" in
        missing-editor) unset CARGO_RELEASE_METADATA_EDITOR ;;
        relative) CARGO_RELEASE_METADATA_EDITOR=editor ;;
        missing-file) CARGO_RELEASE_METADATA_EDITOR="$fixture/absent" ;;
        directory) CARGO_RELEASE_METADATA_EDITOR="$fixture/ready" ;;
        non-executable) CARGO_RELEASE_METADATA_EDITOR="$fixture/module.log" ;;
        newline) CARGO_RELEASE_METADATA_EDITOR="$fixture/editor"$'\n' ;;
        carriage-return) CARGO_RELEASE_METADATA_EDITOR="$fixture/editor"$'\r' ;;
        missing-limit) unset CARGO_RELEASE_METADATA_MAX_BYTES ;;
        zero) CARGO_RELEASE_METADATA_MAX_BYTES=0 ;;
        invalid) CARGO_RELEASE_METADATA_MAX_BYTES=1.5 ;;
    esac
    status=0
    entrypoint=test-portable-tools.sh
    [[ "$mode" != success ]] || entrypoint=check-portable-prerequisites.sh
    PATH="$fixture/ready-bin:$PATH" bash "$ROOT/scripts/ci/$entrypoint" \
        > "$fixture/$mode.log" 2>&1 || status=$?
    if [[ "$mode" == success ]]; then [[ "$status" == 0 ]] || exit 1
    else
        [[ "$status" == 1 ]] || exit 1
        grep -F 'run make test-portable' "$fixture/$mode.log" >/dev/null
    fi
    if grep -F editor-must-not-execute "$fixture/$mode.log"; then exit 1; fi
    if grep -F 'fixture started' "$fixture/$mode.log"; then exit 1; fi
); done
echo 'Portable prerequisite early-refusal tests passed'
fixture_complete=true
