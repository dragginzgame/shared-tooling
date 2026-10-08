#!/usr/bin/env bash
# Shared companions: scripts/ci/run-release.sh
set -euo pipefail

# Owner qualification: real commits/tags/pushes only in disposable repositories.
unset MAKEFLAGS MFLAGS MAKEOVERRIDES GNUMAKEFLAGS MAKEFILES
export RELEASE_DELIVERY=direct
ROOT="${BASH_SOURCE[0]}"
[[ "$ROOT" == /* ]] || ROOT="$PWD/$ROOT"
ROOT="$(cd -P "${ROOT%/*}/../.." && printf '%s/.' "$PWD")"
ROOT="${ROOT%/.}"
FIXTURE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/release-tracking-test.XXXXXX")"
trap 'if [[ $? == 0 ]]; then rm -rf "$FIXTURE_ROOT"; else printf "Failed release-tracking fixture retained: %s\n" "$FIXTURE_ROOT" >&2; fi' EXIT
export REAL_GIT REAL_MAKE
REAL_GIT="$(command -v git)"
REAL_MAKE="$(command -v make)"

# Use native Git histories and bare destinations for tracking observation. Metadata
# and validation targets are deliberately inert: this qualifies Git, not a product.
TRACKING_ROOT="$FIXTURE_ROOT/real-tracking"
mkdir -p "$TRACKING_ROOT/bin"
cat > "$TRACKING_ROOT/bin/git" <<'GIT'
#!/usr/bin/env bash
set -euo pipefail
case "$1" in
    push)
        echo push >> "$TRACKING_EVENTS"
        [[ "${TRACKING_PUSH_FAIL:-}" != yes ]] || exit 9
        "$REAL_GIT" "$@"
        if [[ "${TRACKING_PUSH_LOST:-}" == yes && ! -e "$TRACKING_EVENTS.lost" ]]; then
            touch "$TRACKING_EVENTS.lost"
            exit 9
        fi
        exit 0
        ;;
    update-ref)
        echo tracking >> "$TRACKING_EVENTS"
        [[ "${TRACKING_UPDATE_FAIL:-}" != yes ]] || exit 9
        if [[ -n "${TRACKING_RACE_OID:-}" && ! -e "$TRACKING_EVENTS.raced" ]]; then
            "$REAL_GIT" update-ref "$TRACKING_SELECTED_REF" "$TRACKING_RACE_OID"
            touch "$TRACKING_EVENTS.raced"
        fi
        if [[ "${TRACKING_SYMBOLIC_RACE:-}" == yes && ! -e "$TRACKING_EVENTS.raced" ]]; then
            "$REAL_GIT" symbolic-ref "$TRACKING_SELECTED_REF" refs/heads/preserved
            touch "$TRACKING_EVENTS.raced"
        fi
        ;;
    symbolic-ref)
        if [[ "${3:-}" == "${TRACKING_SELECTED_REF:-}" &&
            -e "$("$REAL_GIT" rev-parse --git-path "$TRACKING_SELECTED_REF.lock")" ]]; then
            [[ "${TRACKING_INSPECTION_FAIL:-}" != yes ]] || exit 128
            if [[ "${TRACKING_PREPARED_RACE:-}" == yes ]]; then
                if "$REAL_GIT" -c core.filesRefLockTimeout=0 symbolic-ref "$TRACKING_SELECTED_REF" refs/heads/preserved; then
                    echo symbolic-writer-accepted >> "$TRACKING_EVENTS"
                else
                    echo symbolic-writer-refused >> "$TRACKING_EVENTS"
                fi
            fi
        fi
        ;;
esac
exec "$REAL_GIT" "$@"
GIT
chmod +x "$TRACKING_ROOT/bin/git"
for tracking_case in normal completed-resume custom-map missing-ref no-upstream other-remote other-branch fetch-destination symbolic newer divergent rejected-push lost-push update-failure update-race symbolic-race missing-symbolic-race prepared-symbolic-race inspection-failure; do
    (
        unset FIXTURE_DESTINATION FIXTURE_REMOTE_FAIL FIXTURE_PUSH_MUTATION
        unset TRACKING_PUSH_FAIL TRACKING_PUSH_LOST TRACKING_UPDATE_FAIL TRACKING_RACE_OID
        unset TRACKING_SYMBOLIC_RACE TRACKING_PREPARED_RACE TRACKING_INSPECTION_FAIL TRACKING_SELECTED_REF
        selected="$TRACKING_ROOT/$tracking_case"
        mkdir -p "$selected"
        "$REAL_GIT" init --quiet --bare "$selected/destination.git"
        "$REAL_GIT" init --quiet -b main "$selected/work"
        cd "$selected/work"
        "$REAL_GIT" config user.name 'Release fixture'
        "$REAL_GIT" config user.email 'fixture@example.invalid'
        printf '0.1.0\n' > version
        cat > Makefile <<'MAKE'
.PHONY: release-version release-preflight release-verify release-prepare-version release-prepared-check release-files release-commit-check release-committed-check release-tagged-check release-push-check
release-version:
	@cat version
release-prepare-version:
	@printf '%s\n' '$(RELEASE_VERSION)' > version
release-files:
	@printf 'version\0'
release-preflight release-verify release-prepared-check release-commit-check release-committed-check release-tagged-check release-push-check:
	@:
MAKE
        "$REAL_GIT" add Makefile version
        "$REAL_GIT" commit --quiet -m source
        source_head="$("$REAL_GIT" rev-parse HEAD)"
        "$REAL_GIT" remote add origin "$selected/destination.git"
        "$REAL_GIT" push --quiet --set-upstream origin main
        tracking_ref=refs/remotes/origin/main
        case "$tracking_case" in
            custom-map)
                "$REAL_GIT" config remote.origin.fetch '+refs/heads/main:refs/remotes/custom/main'
                tracking_ref=refs/remotes/custom/main
                "$REAL_GIT" update-ref "$tracking_ref" "$source_head"
                ;;
            missing-ref|missing-symbolic-race) "$REAL_GIT" update-ref -d "$tracking_ref" ;;
            no-upstream) "$REAL_GIT" config --unset branch.main.remote; "$REAL_GIT" config --unset branch.main.merge ;;
            other-remote)
                "$REAL_GIT" remote add other "$selected/destination.git"
                "$REAL_GIT" config branch.main.remote other
                "$REAL_GIT" update-ref refs/remotes/other/main "$source_head"
                ;;
            other-branch)
                "$REAL_GIT" config branch.main.merge refs/heads/other
                "$REAL_GIT" update-ref refs/remotes/origin/other "$source_head"
                ;;
            fetch-destination)
                "$REAL_GIT" clone --quiet --bare "$selected/destination.git" "$selected/fetch.git"
                "$REAL_GIT" remote set-url origin "$selected/fetch.git"
                "$REAL_GIT" remote set-url --push origin "$selected/destination.git"
                ;;
            symbolic)
                "$REAL_GIT" branch preserved "$source_head"
                "$REAL_GIT" symbolic-ref "$tracking_ref" refs/heads/preserved
                ;;
        esac
        export TRACKING_EVENTS="$selected/events"
        export TRACKING_SELECTED_REF="$tracking_ref"
        : > "$TRACKING_EVENTS"
        export PATH="$TRACKING_ROOT/bin:$PATH"
        export RELEASE_MAKE="$REAL_MAKE"
        if [[ "$tracking_case" == rejected-push ]]; then export TRACKING_PUSH_FAIL=yes; fi
        if [[ "$tracking_case" == lost-push ]]; then export TRACKING_PUSH_LOST=yes; fi
        if [[ "$tracking_case" == update-failure ]]; then export TRACKING_UPDATE_FAIL=yes; fi
        if [[ "$tracking_case" == inspection-failure ]]; then export TRACKING_INSPECTION_FAIL=yes; fi
        if [[ "$tracking_case" == symbolic-race || "$tracking_case" == prepared-symbolic-race ]]; then
            "$REAL_GIT" branch preserved "$source_head"
        fi
        if [[ "$tracking_case" == symbolic-race || "$tracking_case" == missing-symbolic-race ]]; then
            export TRACKING_SYMBOLIC_RACE=yes
        fi
        if [[ "$tracking_case" == prepared-symbolic-race ]]; then export TRACKING_PREPARED_RACE=yes; fi
        if [[ "$tracking_case" == update-race ]]; then
            TRACKING_RACE_OID="$(printf 'concurrent observation\n' | "$REAL_GIT" commit-tree "$("$REAL_GIT" rev-parse "HEAD^{tree}")" -p "$source_head")"
            export TRACKING_RACE_OID
        fi
        if [[ "$tracking_case" == rejected-push || "$tracking_case" == lost-push ]]; then
            if bash "$ROOT/scripts/ci/run-release.sh" patch origin main > "$selected/first.log" 2>&1; then
                echo "tracking fixture accepted failed/lost push: $tracking_case" >&2; exit 1
            fi
            [[ "$("$REAL_GIT" rev-parse "$tracking_ref")" == "$source_head" ]]
            if [[ "$tracking_case" == rejected-push ]]; then
                [[ "$("$REAL_GIT" --git-dir="$selected/destination.git" rev-parse refs/heads/main)" == "$source_head" ]]
            fi
            unset TRACKING_PUSH_FAIL TRACKING_PUSH_LOST
            bash "$ROOT/scripts/ci/run-release.sh" resume 0.1.1 origin main > "$selected/resume.log" 2>&1
        else
            bash "$ROOT/scripts/ci/run-release.sh" patch origin main > "$selected/first.log" 2>&1
        fi
        release_head="$("$REAL_GIT" rev-parse HEAD)"
        [[ "$("$REAL_GIT" --git-dir="$selected/destination.git" rev-parse refs/heads/main)" == "$release_head" ]]
        [[ "$(tail -n 1 .git/release-state/0.1.1.plan)" == complete ]]
        case "$tracking_case" in
            no-upstream|other-remote|other-branch|fetch-destination|symbolic)
                [[ "$("$REAL_GIT" rev-parse "$tracking_ref")" == "$source_head" ]]
                [[ "$(awk '$0 == "tracking" { count++ } END { print count+0 }' "$TRACKING_EVENTS")" == 0 ]]
                if [[ "$tracking_case" == symbolic ]]; then
                    [[ "$("$REAL_GIT" symbolic-ref "$tracking_ref")" == refs/heads/preserved ]]
                    [[ "$("$REAL_GIT" rev-parse preserved)" == "$source_head" ]]
                fi
                ;;
            update-race)
                [[ "$("$REAL_GIT" rev-parse "$tracking_ref")" == "$TRACKING_RACE_OID" ]]
                [[ "$(awk '$0 == "push" { count++ } END { print count+0 }' "$TRACKING_EVENTS")" == 1 ]]
                ;;
            symbolic-race|missing-symbolic-race)
                [[ "$("$REAL_GIT" symbolic-ref "$tracking_ref")" == refs/heads/preserved ]]
                if [[ "$tracking_case" == symbolic-race ]]; then
                    [[ "$("$REAL_GIT" rev-parse preserved)" == "$source_head" ]]
                else
                    if "$REAL_GIT" show-ref --verify --quiet refs/heads/preserved; then exit 1; fi
                fi
                [[ ! -e "$("$REAL_GIT" rev-parse --git-path "$tracking_ref.lock")" ]]
                bash "$ROOT/scripts/ci/run-release.sh" resume 0.1.1 origin main > "$selected/resume.log" 2>&1
                [[ "$("$REAL_GIT" symbolic-ref "$tracking_ref")" == refs/heads/preserved ]]
                [[ "$(awk '$0 == "push" { count++ } END { print count+0 }' "$TRACKING_EVENTS")" == 1 ]]
                ;;
            update-failure|inspection-failure)
                [[ "$("$REAL_GIT" rev-parse "$tracking_ref")" == "$source_head" ]]
                [[ ! -e "$("$REAL_GIT" rev-parse --git-path "$tracking_ref.lock")" ]]
                unset TRACKING_UPDATE_FAIL TRACKING_INSPECTION_FAIL
                bash "$ROOT/scripts/ci/run-release.sh" resume 0.1.1 origin main > "$selected/resume.log" 2>&1
                [[ "$("$REAL_GIT" rev-parse "$tracking_ref")" == "$release_head" ]]
                [[ "$(awk '$0 == "push" { count++ } END { print count+0 }' "$TRACKING_EVENTS")" == 1 ]]
                ;;
            completed-resume)
                "$REAL_GIT" update-ref "$tracking_ref" "$source_head"
                bash "$ROOT/scripts/ci/run-release.sh" resume 0.1.1 origin main > "$selected/resume.log" 2>&1
                [[ "$("$REAL_GIT" rev-parse "$tracking_ref")" == "$release_head" ]]
                [[ "$(awk '$0 == "push" { count++ } END { print count+0 }' "$TRACKING_EVENTS")" == 1 ]]
                ;;
            newer|divergent)
                tracking_parent="$release_head"
                [[ "$tracking_case" != divergent ]] || tracking_parent="$source_head"
                retained_head="$(printf 'retained observation\n' | "$REAL_GIT" commit-tree "$("$REAL_GIT" rev-parse "HEAD^{tree}")" -p "$tracking_parent")"
                "$REAL_GIT" update-ref "$tracking_ref" "$retained_head"
                bash "$ROOT/scripts/ci/run-release.sh" resume 0.1.1 origin main > "$selected/resume.log" 2>&1
                [[ "$("$REAL_GIT" rev-parse "$tracking_ref")" == "$retained_head" ]]
                [[ "$(awk '$0 == "push" { count++ } END { print count+0 }' "$TRACKING_EVENTS")" == 1 ]]
                ;;
            *)
                [[ "$("$REAL_GIT" rev-parse "$tracking_ref")" == "$release_head" ]]
                [[ "$("$REAL_GIT" rev-list --count "@{upstream}..HEAD")" == 0 ]]
                if [[ "$tracking_case" == prepared-symbolic-race ]]; then
                    [[ "$("$REAL_GIT" rev-parse preserved)" == "$source_head" ]]
                    [[ "$(awk '$0 == "symbolic-writer-refused" { count++ } END { print count+0 }' "$TRACKING_EVENTS")" == 1 ]]
                    if grep -q '^symbolic-writer-accepted$' "$TRACKING_EVENTS"; then exit 1; fi
                fi
                if [[ "$tracking_case" == custom-map ]]; then
                    [[ "$("$REAL_GIT" rev-parse refs/remotes/origin/main)" == "$source_head" ]]
                fi
                if [[ "$tracking_case" == lost-push ]]; then
                    [[ "$(awk '$0 == "push" { count++ } END { print count+0 }' "$TRACKING_EVENTS")" == 1 ]]
                fi
                ;;
        esac
        echo "real Git tracking fixture passed: $tracking_case"
    )
done

echo 'Native release tracking and recovery tests passed'
