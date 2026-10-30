#!/usr/bin/env bash
# Shared companions: make/consumer.mk scripts/ci/fixture-lifecycle.sh
set -euo pipefail
unset MAKEFLAGS MFLAGS MAKEOVERRIDES GNUMAKEFLAGS MAKEFILES
root="${BASH_SOURCE[0]}"
[[ "$root" == /* ]] || root="$PWD/$root"
root="$(cd -P "${root%/*}/../.." && printf '%s/.' "$PWD")"
root="${root%/.}"
# shellcheck source=scripts/ci/fixture-lifecycle.sh
source "$root/scripts/ci/fixture-lifecycle.sh"
fixture="$(fixture_create "${TMPDIR:-/tmp}/publication-adapter.XXXXXX")"
fixture_complete=false
trap 'fixture_finish "$?" "$fixture" "Publication adapter fixture retained"' EXIT
mkdir -p "$fixture/bin" "$fixture/workspace with spaces"
export PUBLICATION_FIXTURE="$fixture"
cat > "$fixture/bin/git" <<'GIT'
#!/usr/bin/env bash
case "$1" in
    rev-parse)
        if [[ "$2" == --show-toplevel ]]; then printf '%s\n' "$PUBLICATION_FIXTURE/workspace with spaces";
        elif [[ "${PUB_DRIFT:-0}" == 1 && -e "$PUBLICATION_FIXTURE/verified" ]]; then printf '%040d\n' 2;
        else printf '%040d\n' 1; fi ;;
    status) [[ "${PUB_DIRTY:-0}" != 1 ]] || echo ' M Cargo.toml' ;;
    *) exit 99 ;;
esac
exit 0
GIT
cat > "$fixture/bin/cargo" <<'CARGO'
#!/usr/bin/env bash
set -euo pipefail
case "$1" in
    metadata)
        printf 'metadata\n' >> "$PUBLICATION_FIXTURE/events"
        cat "$PUBLICATION_FIXTURE/metadata.json"
        if [[ "${PUB_METADATA_FAILURE:-0}" == 1 ]]; then echo metadata-error >&2; exit 43; fi ;;
    publish)
        printf '%s\0' "$@" > "$PUBLICATION_FIXTURE/arguments"
        printf 'publish\n' >> "$PUBLICATION_FIXTURE/events"
        echo publication-output
        exit "${PUB_UPLOAD_STATUS:-0}" ;;
    *) exit 99 ;;
esac
CARGO
chmod +x "$fixture/bin/git" "$fixture/bin/cargo"
export PATH="$fixture/bin:$PATH"
cd "$fixture/workspace with spaces"
printf 'SHARED_TOOLING_ROOT := %s\n' "$root" > Makefile
cat >> Makefile <<'MAKE'
.DEFAULT_GOAL := help
SHARED_TOOLING_RUST := 0
PACKAGE := library
CARGO_PUBLISH_PACKAGES := library cli
CARGO_PUBLISH_REGISTRY := crates-io
CARGO_PUBLISH_VERIFY_TARGETS := prepare verify
include $(SHARED_TOOLING_ROOT)/make/consumer.mk
help:
	@echo help
prepare:
	@if [ "$${PUB_WAIT_PREPARE:-0}" = 1 ]; then sleep 1; fi
	@echo prepare >> "$$PUBLICATION_FIXTURE/events"
	@touch "$$PUBLICATION_FIXTURE/prepared"
verify:
	@test -f "$$PUBLICATION_FIXTURE/prepared"
	@echo verify >> "$$PUBLICATION_FIXTURE/events"
	@touch "$$PUBLICATION_FIXTURE/verified"
	@exit $${PUB_VERIFY_STATUS:-0}
MAKE
cat > "$fixture/metadata-original.json" <<'JSON'
{"version":1,"workspace_members":["library-id","cli-id"],"packages":[{"id":"library-id","name":"library","version":"1.2.3","source":null,"publish":null},{"id":"cli-id","name":"cli","version":"2.0.0","source":null,"publish":["crates-io"]}]}
JSON
reset_case() {
    rm -f "$fixture/arguments" "$fixture/prepared" "$fixture/verified"
    : > "$fixture/events"
    cp "$fixture/metadata-original.json" "$fixture/metadata.json"
    unset PUB_DRIFT PUB_DIRTY PUB_METADATA_FAILURE PUB_VERIFY_STATUS PUB_UPLOAD_STATUS PUB_WAIT_PREPARE
}
run() { make --no-print-directory "$@" > "$fixture/result.log" 2>&1; }
refuse() {
    local status=0
    run "$@" || status=$?
    [[ "$status" != 0 && ! -e "$fixture/arguments" ]] || { cat "$fixture/result.log"; exit 1; }
}
for goal in publish-check publish; do
    for selection in default library cli; do
        reset_case
        package_args=()
        selectors=(--package library@1.2.3 --package cli@2.0.0)
        if [[ "$selection" != default ]]; then
            package_args=("PACKAGE=$selection")
            if [[ "$selection" == library ]]; then selectors=(--package library@1.2.3); else selectors=(--package cli@2.0.0); fi
        fi
        run "$goal" ${package_args[@]+"${package_args[@]}"}
        printf '%s\n' metadata prepare verify publish > "$fixture/expected-events"
        cmp "$fixture/expected-events" "$fixture/events"
        printf '%s\0' publish --locked --registry crates-io "${selectors[@]}" > "$fixture/expected-arguments"
        [[ "$goal" != publish-check ]] || printf '%s\0' --dry-run >> "$fixture/expected-arguments"
        cmp "$fixture/expected-arguments" "$fixture/arguments"
    done
done
reset_case
PUB_WAIT_PREPARE=1 run -j2 publish-check
printf '%s\n' metadata prepare verify publish > "$fixture/expected-events"
cmp "$fixture/expected-events" "$fixture/events"
for selection in '' unknown 'library library' '--workspace' 'library;touch injected'; do
    reset_case
    refuse publish "PACKAGE=$selection"
    [[ ! -e "$fixture/verified" && ! -e injected ]]
done
for scenario in private registry version membership metadata malformed verify upload dirty drift locked; do
    reset_case
    case "$scenario" in
        private) sed 's/"publish":null/"publish":[]/' "$fixture/metadata-original.json" > "$fixture/metadata.json" ;;
        registry) sed 's/"crates-io"/"other"/' "$fixture/metadata-original.json" > "$fixture/metadata.json" ;;
        version) sed 's/1.2.3/1.2.3-beta/' "$fixture/metadata-original.json" > "$fixture/metadata.json" ;;
        membership) sed 's/"workspace_members":\["library-id","cli-id"\]/"workspace_members":["library-id"]/' "$fixture/metadata-original.json" > "$fixture/metadata.json" ;;
        metadata) export PUB_METADATA_FAILURE=1 ;;
        malformed) echo invalid > "$fixture/metadata.json" ;;
        verify) export PUB_VERIFY_STATUS=17 ;;
        upload) export PUB_UPLOAD_STATUS=37 ;;
        dirty) export PUB_DIRTY=1 ;;
        drift) export PUB_DRIFT=1 ;;
        locked) mkdir -p target/publication/.cargo-publication.lock; echo retained > target/publication/.cargo-publication.lock/owner ;;
    esac
    if [[ "$scenario" == upload ]]; then
        if run publish; then exit 1; fi
        [[ -s "$fixture/arguments" ]]
    else
        refuse publish
        if [[ "$scenario" == private || "$scenario" == registry || "$scenario" == version || "$scenario" == membership || "$scenario" == metadata || "$scenario" == malformed ]]; then
            [[ ! -e "$fixture/verified" ]]
        fi
    fi
done
[[ "$(cat target/publication/.cargo-publication.lock/owner)" == retained ]]
for selection in 'CARGO_PUBLISH_PACKAGES=' 'CARGO_PUBLISH_REGISTRY=--invalid' 'CARGO_PUBLISH_VERIFY_TARGETS=publish' 'CARGO_PUBLISH_VERIFY_TARGETS=--help'; do
    reset_case
    refuse publish "$selection"
    [[ ! -s "$fixture/events" ]]
done
for mode in -i -n -t -q; do
    reset_case
    refuse "$mode" publish
    [[ ! -s "$fixture/events" ]]
done
echo 'Publication Make selection, metadata admission, validation ordering and retained dispatch passed (effects substituted)'
fixture_complete=true
