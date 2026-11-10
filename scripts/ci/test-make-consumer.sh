#!/usr/bin/env bash
# Shared companions: scripts/ci/prepare-script-fixture.sh make/consumer.mk scripts/ci/check-make-execution.sh scripts/ci/verify-file-checksum.sh .githooks/pre-commit scripts/ci/check-pipe-jobserver.pl scripts/ci/fixture-lifecycle.sh
set -euo pipefail
unset MAKEFLAGS MFLAGS MAKEOVERRIDES GNUMAKEFLAGS MAKEFILES
root="${BASH_SOURCE[0]}"
[[ "$root" == /* ]] || root="$PWD/$root"
root="$(cd -P "${root%/*}/../.." && printf '%s/.' "$PWD")"
root="${root%/.}"
# shellcheck source=scripts/ci/fixture-lifecycle.sh
source "$root/scripts/ci/fixture-lifecycle.sh"
fixture="$(fixture_create "${TMPDIR:-/tmp}/make-consumer.XXXXXX")"
fixture_complete=false
trap 'fixture_finish "$?" "$fixture" "Consumer Make fixture retained"' EXIT
consumer="$fixture/consumer with spaces"
snapshot="$consumer/vendor/shared"
mkdir -p "$snapshot/make" "$snapshot/scripts/ci" "$snapshot/scripts/dev" \
    "$consumer/ci" "$snapshot/ci" "$consumer/scripts/ci" "$consumer/.githooks" \
    "$consumer/.tools/rust/common/bin"
mkdir "$fixture/templates" "$fixture/bin"
export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null GIT_TEMPLATE_DIR="$fixture/templates"
git init -q "$consumer"
bash "$root/scripts/ci/prepare-script-fixture.sh" "$root" "$snapshot" make/consumer.mk
# Hooks retain their root-layout contract even when other tooling is nested.
bash "$root/scripts/ci/prepare-script-fixture.sh" "$root" "$consumer" \
    .githooks/pre-commit scripts/ci/verify-toko-tooling-snapshot.sh scripts/ci/verify-file-checksum.sh
printf '[workspace]\nmembers = ["app", "helper"]\ndefault-members = ["app"]\n' > "$consumer/Cargo.toml"
printf '\n[workspace.dependencies]\ntoko-tooling = "=0.36.0"\n' >> "$consumer/Cargo.toml"
for member in app helper; do
    mkdir -p "$consumer/$member/src"
    printf '[package]\nname = "fixture-%s"\nversion = "0.0.0"\n' "$member" > "$consumer/$member/Cargo.toml"
    printf 'pub fn fixture() {}\n' > "$consumer/$member/src/lib.rs"
    printf '\n[dev-dependencies]\ntoko-tooling.workspace = true\n' >> "$consumer/$member/Cargo.toml"
done
# Synthetic Cargo observation keeps this Make wiring fixture offline and avoids
# registry/cache dependencies; the real selection and receipt validators run.
checksum=$(printf '%064d' 0)
cat > "$consumer/Cargo.lock" <<LOCK
version = 4
[[package]]
name = "toko-tooling"
version = "0.36.0"
source = "registry+https://github.com/rust-lang/crates.io-index"
checksum = "$checksum"
LOCK
cat > "$fixture/bin/cargo" <<'CARGO'
#!/usr/bin/env bash
set -eu
[[ $# == 8 && "$*" == "metadata --format-version 1 --no-deps --locked --offline --manifest-path $PWD/Cargo.toml" ]]
perl -MJSON::PP -MEncode=decode -MCwd=getcwd -e '
    $p=decode("UTF-8",getcwd());
    print encode_json({workspace_root=>$p, workspace_members=>["app","helper"],
        packages=>[map {{id=>$_, manifest_path=>"$p/$_/Cargo.toml", dependencies=>[
            {name=>"toko-tooling", kind=>"dev", req=>"=0.36.0", optional=>JSON::PP::false,
             source=>"registry+https://github.com/rust-lang/crates.io-index"}]}} qw(app helper)]});'
CARGO
chmod +x "$fixture/bin/cargo"
export PATH="$fixture/bin:$PATH"
{
    printf 'format\t1\nsource\thttps://crates.io/crates/toko-tooling\nrevision\t%s\n# version\t0.36.0\n' "$checksum"
    for path in scripts/ci/verify-file-checksum.sh scripts/ci/verify-toko-tooling-snapshot.sh; do
        digest="$(bash "$root/scripts/ci/verify-file-checksum.sh" --print sha256 "$consumer/$path")"
        mode=-; [[ ! -x "$consumer/$path" ]] || mode=x
        printf 'file\t%s\t%s\t%s\n' "$digest" "$mode" "$path"
    done
} > "$consumer/reviewed snapshot"
printf 'TOKO_TOOLING_CARGO_SORT_VERSION=2.1.4\nTOKO_TOOLING_CARGO_SORT_DERIVES_VERSION=0.1.3\n' > "$snapshot/ci/tool-versions.env"
printf 'exit 99 # obsolete consumer catalog must not execute\n' > "$consumer/ci/tool-versions.env"
export MAKE_CONSUMER_EVENTS="$fixture/events" RUNNER_TEMP="$fixture"
cat > "$consumer/Makefile" <<'MAKE'
override TOKO_TOOLING_ROOT := $(CURDIR)/vendor/shared
TOKO_TOOLING_MANIFEST := reviewed snapshot
TOKO_TOOLING_RELEASE := 1
FORMAT_CARGO := fixture-cargo
FORMAT_RUST_ARGS := --no-cache
RELEASE_RESUME_CHECK_COMMAND = bash "$(CURDIR)/resume-check.sh" "$(VERSION)"
include vendor/shared/make/consumer.mk
.PHONY: help local-admission
help:
	@echo consumer help
local-admission:
	@echo admission >> "$$MAKE_CONSUMER_EVENTS"; test "$${ADMISSION_FAIL:-0}" = 0
release-patch release-minor release-major release-resume: local-admission
release-patch release-minor release-major release-resume: export LOCAL_RELEASE_SELECTION := retained
MAKE
cat > "$consumer/.tools/rust/common/bin/fixture-cargo" <<'CARGO'
#!/usr/bin/env bash
set -eu
[[ "$CARGO_NET_OFFLINE" == true && "$RUSTUP_AUTO_INSTALL" == 0 ]]
case "$*" in
    'metadata --locked --offline --no-deps --format-version 1')
        [[ "${FIXTURE_METADATA_EMPTY:-0}" == 0 ]] || exit 0
        perl -MJSON::PP -MEncode=decode -MCwd=getcwd -e '
            $p=decode("UTF-8",getcwd());
            print encode_json({workspace_root=>$p,
                workspace_members=>["app", "helper"], workspace_default_members=>["app"],
                packages=>[map {{id=>$_, name=>"fixture-$_", manifest_path=>"$p/$_/Cargo.toml"}} qw(app helper)]});'
        exit 0 ;;
    'sort --version') echo "cargo-sort ${FIXTURE_SORT_VERSION:-2.1.4}"; exit 0 ;;
    'fmt --version') exit 0 ;;
esac
printf '%s\n' "$*" >> "$MAKE_CONSUMER_EVENTS"
CARGO
chmod +x "$consumer/.tools/rust/common/bin/fixture-cargo"
cat > "$snapshot/scripts/ci/run-release.sh" <<'RUNNER'
#!/usr/bin/env bash
set -eu
[[ "$LOCAL_RELEASE_SELECTION" == retained ]]
printf '%s\n' "$*" >> "$MAKE_CONSUMER_EVENTS"
exit "${RUNNER_RESULT:-0}"
RUNNER
cat > "$consumer/resume-check.sh" <<'CHECK'
#!/usr/bin/env bash
set -eu
printf 'receipt %s\n' "$1" >> "$MAKE_CONSUMER_EVENTS"
exit "${RECEIPT_RESULT:-0}"
CHECK
[[ "$(make -s -C "$consumer")" == 'consumer help' && ! -e "$MAKE_CONSUMER_EVENTS" ]]
make -s -C "$consumer" fmt-check FORMAT_RUST_ARGS=--no-cache > "$fixture/format.log"
grep -E '^Manifest sorting .*ok \([0-9]+\.[0-9]+s\)$' "$fixture/format.log"
grep -E '^Rust formatting .*ok \([0-9]+\.[0-9]+s\)$' "$fixture/format.log"
printf 'sort --workspace --grouped --check\nfmt --package fixture-app --package fixture-helper -- --check\n' > "$fixture/expected"
cmp "$fixture/expected" "$MAKE_CONSUMER_EVENTS"

# Mandatory owner selection must fail before any formatter runs, including when
# the caller disables caching. Empty successful output is not usable metadata.
: > "$MAKE_CONSUMER_EVENTS"
if FIXTURE_METADATA_EMPTY=1 make -s -C "$consumer" fmt-check > "$fixture/metadata-refusal.log" 2>&1; then exit 1; fi
[[ ! -s "$MAKE_CONSUMER_EVENTS" ]]
grep -q 'malformed JSON' "$fixture/metadata-refusal.log"

# Formatting follows the Rust catalog, including when the host catalog has no
# Cargo pins. Wrong Rust selections still refuse before invoking formatters.
printf 'TOKO_TOOLING_CARGO_SORT_VERSION=2.1.5\nTOKO_TOOLING_CARGO_SORT_DERIVES_VERSION=0.1.3\n' > "$consumer/ci/rust pins.env"
printf '# Host-only catalog\n' > "$consumer/ci/host pins.env"
for host_catalog in tool-versions.env 'host pins.env'; do
    : > "$MAKE_CONSUMER_EVENTS"
    FIXTURE_SORT_VERSION=2.1.5 make -s -C "$consumer" fmt-check \
        "HOST_TOOL_VERSIONS=$consumer/ci/$host_catalog" "RUST_TOOL_VERSIONS=$consumer/ci/rust pins.env"
    cmp "$fixture/expected" "$MAKE_CONSUMER_EVENTS"
done
: > "$MAKE_CONSUMER_EVENTS"
if make -s -C "$consumer" fmt-check "RUST_TOOL_VERSIONS=$consumer/ci/rust pins.env" \
    > "$fixture/rust-pin-refusal.log" 2>&1; then exit 1; fi
[[ ! -s "$MAKE_CONSUMER_EVENTS" ]]

# Product prerequisites and target-specific selections survive the common route.
for kind in patch minor major resume; do
    : > "$MAKE_CONSUMER_EVENTS"
    make -s -C "$consumer" "release-$kind" VERSION=0.1.2 RELEASE_REMOTE=review RELEASE_BRANCH=topic
    if [[ "$kind" == resume ]]; then args='resume 0.1.2 review topic'
    else args="$kind review topic"; fi
    printf 'admission\n%s\n' "$args" > "$fixture/expected"
    if [[ "$kind" == resume ]]; then printf 'receipt 0.1.2\n' >> "$fixture/expected"; fi
    cmp "$fixture/expected" "$MAKE_CONSUMER_EVENTS"
done
: > "$MAKE_CONSUMER_EVENTS"
if ADMISSION_FAIL=1 make -s -C "$consumer" release-patch > "$fixture/admission.log" 2>&1; then exit 1; fi
printf 'admission\n' > "$fixture/expected"
cmp "$fixture/expected" "$MAKE_CONSUMER_EVENTS"
if RUNNER_RESULT=23 make -s -C "$consumer" release-patch > "$fixture/runner.log" 2>&1; then exit 1; fi
: > "$MAKE_CONSUMER_EVENTS"
if RUNNER_RESULT=23 make -s -C "$consumer" release-resume VERSION=0.1.2 > "$fixture/resume-failure.log" 2>&1; then exit 1; fi
printf 'admission\nresume 0.1.2 origin main\n' > "$fixture/expected"
cmp "$fixture/expected" "$MAKE_CONSUMER_EVENTS"
: > "$MAKE_CONSUMER_EVENTS"
if RECEIPT_RESULT=24 make -s -C "$consumer" release-resume VERSION=0.1.2 > "$fixture/receipt-failure.log" 2>&1; then exit 1; fi
printf 'receipt 0.1.2\n' >> "$fixture/expected"
cmp "$fixture/expected" "$MAKE_CONSUMER_EVENTS"
: > "$MAKE_CONSUMER_EVENTS"
if make -s -C "$consumer" release-patch release-minor > "$fixture/conflict.log" 2>&1; then exit 1; fi
[[ ! -s "$MAKE_CONSUMER_EVENTS" ]]

# A complete custom policy receives exact arguments and inherited Cargo context.
cat > "$consumer/custom.mk" <<'MAKE'
FORMAT_WRITE_COMMAND = bash "$(CURDIR)/custom formatter.sh" --write 'workspace with spaces'
FORMAT_CHECK_COMMAND = bash "$(CURDIR)/custom formatter.sh" --check 'workspace with spaces'
fmt fmt-check: export CARGO_HOME := $(CURDIR)/selected cargo home
include Makefile
MAKE
export JOBSERVER_PROBE="$root/scripts/ci/check-pipe-jobserver.pl"
cat > "$consumer/custom formatter.sh" <<'FORMAT'
#!/usr/bin/env bash
set -eu
[[ "$CARGO_HOME" == "$PWD/selected cargo home" ]]
[[ "$CARGO_NET_OFFLINE" == true && "$RUSTUP_AUTO_INSTALL" == 0 ]]
[[ $# == 2 && "$2" == 'workspace with spaces' ]]
if [[ "${REQUIRE_JOBSERVER:-0}" == 1 ]]; then
    perl "$JOBSERVER_PROBE"
fi
echo "$1" >> "$MAKE_CONSUMER_EVENTS"
echo custom-detail >&2
exit "${FORMAT_RESULT:-0}"
FORMAT
parallel=(-j2)
if make --help | grep -q -- --jobserver-style; then parallel+=(--jobserver-style=pipe); fi
: > "$MAKE_CONSUMER_EVENTS"
for target in fmt fmt-check; do
    REQUIRE_JOBSERVER=1 make -s "${parallel[@]}" -C "$consumer" -f custom.mk "$target" > "$fixture/$target.log"
done
printf '%s\n' --write --check > "$fixture/expected"
cmp "$fixture/expected" "$MAKE_CONSUMER_EVENTS"
if FORMAT_RESULT=23 make -s -C "$consumer" -f custom.mk fmt-check > "$fixture/format-failure.log" 2>&1; then exit 1; fi
grep -F 'Checking formatting... FAILED (exit 23)' "$fixture/format-failure.log"
grep -Fx custom-detail "$fixture"/formatting.*
for mode in -i -n -t -q; do
    : > "$MAKE_CONSUMER_EVENTS"
    if make -s "$mode" -C "$consumer" -f custom.mk fmt > "$fixture/mode.log" 2>&1; then exit 1; fi
    [[ ! -s "$MAKE_CONSUMER_EVENTS" ]]
done
for assignment in 'FORMAT_WRITE_COMMAND=echo unexpected' 'FORMAT_CHECK_COMMAND=echo unexpected' \
    'TOKO_TOOLING_RUST=' 'TOKO_TOOLING_RUST=0 1' 'TOKO_TOOLING_RUST=%'; do
    if make -s -C "$consumer" help "$assignment" > "$fixture/invalid.log" 2>&1; then exit 1; fi
done

# Explicit setup changes only this disposable clone, not the nested snapshot.
make -s -C "$consumer" install-hooks
[[ "$(git -C "$consumer" config --local --get core.hooksPath)" == .githooks ]]
git -C "$consumer" config --local core.hooksPath other-hooks
if make -s -C "$consumer" install-hooks > "$fixture/hook-refusal.log" 2>&1; then exit 1; fi
[[ "$(git -C "$consumer" config --local --get core.hooksPath)" == other-hooks ]]

# The nested entrypoint verifies the consumer and its selected manifest offline.
make -s -C "$consumer" toko-tooling-check 'TOKO_TOOLING_MANIFEST=reviewed snapshot'
printf '\n# drift\n' >> "$consumer/scripts/ci/verify-file-checksum.sh"
if make -s -C "$consumer" toko-tooling-check 'TOKO_TOOLING_MANIFEST=reviewed snapshot' > "$fixture/snapshot-failure.log" 2>&1; then exit 1; fi
: > "$MAKE_CONSUMER_EVENTS"
if make -s -C "$consumer" release-patch > "$fixture/release-drift.log" 2>&1; then exit 1; fi
[[ ! -s "$MAKE_CONSUMER_EVENTS" ]]

# Non-Rust owners retain tooling/releases without advertising Rust operations.
[[ "$(make -s -C "$consumer" TOKO_TOOLING_RUST=0)" == 'consumer help' ]]
for target in fmt fmt-check install-hooks; do
    if make -s -C "$consumer" TOKO_TOOLING_RUST=0 "$target" > "$fixture/non-rust.log" 2>&1; then exit 1; fi
done
# A consumer with no release adapter gets no shared release or cleanup targets.
# Even parallel invocations must leave ignored empty source directories intact.
cat > "$consumer/no-release.mk" <<'MAKE'
override TOKO_TOOLING_ROOT := $(CURDIR)/vendor/shared
include vendor/shared/make/consumer.mk
ci:
	@echo ci >> "$$MAKE_CONSUMER_EVENTS"
MAKE
mkdir -p "$consumer/src/ignored-empty"
printf '/src/ignored-empty/\n' > "$consumer/.gitignore"
for target in release-patch release-minor release-major release-resume release-preflight \
    release-batch-resume release-batch-status release-batch-reconcile release-batch-retire clean-empty-source-dirs; do
    : > "$MAKE_CONSUMER_EVENTS"
    if make -s -j4 -C "$consumer" -f no-release.mk "$target" > "$fixture/no-release.log" 2>&1; then exit 1; fi
    grep -q 'No rule to make target' "$fixture/no-release.log"
    [[ -d "$consumer/src/ignored-empty" && ! -s "$MAKE_CONSUMER_EVENTS" ]]
done
# A ci directory cannot shadow the consumer recipe, even without admission deps.
make -s -C "$consumer" -f no-release.mk ci TOKO_TOOLING_PRODUCER=1
printf 'ci\n' > "$fixture/expected"
cmp "$fixture/expected" "$MAKE_CONSUMER_EVENTS"
# Consumer-owned release recipes remain available without opting in.
cat >> "$consumer/no-release.mk" <<'MAKE'
release-patch:
	@echo local-release >> "$$MAKE_CONSUMER_EVENTS"
MAKE
make -s -C "$consumer" -f no-release.mk release-patch
printf 'local-release\n' >> "$fixture/expected"
cmp "$fixture/expected" "$MAKE_CONSUMER_EVENTS"

# Preview real shared routes with sentinel leaves: no formatter, installer,
# recursive Make, publication or release command may run under the opt-out.
cat > "$consumer/preview.mk" <<'MAKE'
include Makefile
CARGO_PUBLISH_PACKAGES := fixture
include vendor/shared/make/cargo-publication.mk
.PHONY: check patch setup-dev install-dev nested-preview
check: fmt-check
patch: fmt
setup-dev: install-hooks
install-dev: install-tools
nested-preview:
	+@$(MAKE) --no-print-directory -f preview.mk install-dev
MAKE
for script in scripts/dev/install-host-tools.sh scripts/dev/install-rust-tools.sh \
    scripts/dev/install-git-hooks.sh scripts/ci/check-format-tools.sh \
    scripts/ci/cargo-publication-adapter.sh; do
    cat > "$snapshot/$script" <<'SENTINEL'
#!/usr/bin/env bash
echo unexpected >> "$MAKE_CONSUMER_EVENTS"
exit 91
SENTINEL
done
for target in check patch setup-dev install-dev nested-preview release-patch release-resume publish; do
    : > "$MAKE_CONSUMER_EVENTS"
    make -s -n -j4 -C "$consumer" -f preview.mk "$target" TOKO_TOOLING_DRY_RUN=1 > "$fixture/preview.log" 2>&1
    [[ ! -s "$MAKE_CONSUMER_EVENTS" && -d "$consumer/src/ignored-empty" ]]
done
# The switch alone cannot disable execution admission in a real invocation.
for mode in normal -i -t -q; do
    args=(); [[ "$mode" == normal ]] || args+=("$mode")
    if make -s ${args[@]+"${args[@]}"} -C "$consumer" -f preview.mk install-dev TOKO_TOOLING_DRY_RUN=1 \
        > "$fixture/preview-refusal.log" 2>&1; then exit 1; fi
    [[ ! -s "$MAKE_CONSUMER_EVENTS" ]]
    grep -q 'requires make -n' "$fixture/preview-refusal.log"
done
# The opt-in admits inherited GNU Make flags too; spoofed/cleared flags refuse.
MAKEFLAGS=n make -s -C "$consumer" -f preview.mk check TOKO_TOOLING_DRY_RUN=1 > "$fixture/inherited-preview.log"
if make -sn -C "$consumer" -f preview.mk check TOKO_TOOLING_DRY_RUN=1 MAKEFLAGS= \
    > "$fixture/preview-cleared.log" 2>&1; then exit 1; fi
[[ ! -s "$MAKE_CONSUMER_EVENTS" ]]
echo 'Consumer Make entrypoint passed (substitute release/format commands; no installation or release)'
fixture_complete=true
