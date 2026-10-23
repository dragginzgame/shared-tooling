#!/usr/bin/env bash
# Shared companions: scripts/dev/tool-store.sh scripts/ci/fixture-lifecycle.sh
set -euo pipefail
ROOT="${BASH_SOURCE[0]}"
[[ "$ROOT" == /* ]] || ROOT="$PWD/$ROOT"
ROOT="$(CDPATH='' cd -P -- "${ROOT%/*}/../.." && printf '%s/.' "$PWD")"
ROOT="${ROOT%/.}"
# shellcheck source=scripts/ci/fixture-lifecycle.sh
source "$ROOT/scripts/ci/fixture-lifecycle.sh"
# shellcheck source=scripts/dev/tool-store.sh
source "$ROOT/scripts/dev/tool-store.sh"
fixture="$(fixture_create "${TMPDIR:-/tmp}/tool-store-wait.XXXXXX")"
fixture_complete=false
pending=''
finish() {
    local status=$?
    if [[ -n "$pending" ]]; then kill "$pending" 2>/dev/null || :; wait "$pending" 2>/dev/null || :; fi
    fixture_finish "$status" "$fixture" 'Tool-store wait fixture retained'
}
trap finish EXIT
store_root="$fixture/store"
store_slot="$store_root/rust-test"
consumer="$fixture/consumer"
mkdir -p "$store_slot" "$consumer"
chmod 700 "$store_root" "$store_slot"
lock="$store_slot/install.lock"
await_waiter() {
    local attempt
    for ((attempt=0; attempt<100; attempt++)); do
        if grep -qF 'Waiting for tool installation slot:' "$fixture/wait.log"; then return 0; fi
        sleep 0.05
    done
    cat "$fixture/wait.log" >&2
    return 1
}
tool_store_wait_unlocked 1
[[ "$tool_store_waited" == false ]]
mkdir -m 700 "$lock"
printf 'pid=%s\nconsumer=%s\n' "$$" "$consumer" > "$lock/owner"
cp "$lock/owner" "$fixture/owner.before"
# Waiting never claims or clears the owner's lock. Acquisition remains atomic.
tool_store_acquire 5 > "$fixture/wait.log" 2>&1 & pending=$!
await_waiter
cmp "$lock/owner" "$fixture/owner.before"
# Exercise the real releaser's record-before-rmdir scheduling interval.
(
    rmdir() { sleep 2; command rmdir "$@"; }
    store_lock="$lock"
    tool_store_release
)
wait "$pending"; pending=''
grep -F 'rechecking inputs' "$fixture/wait.log" >/dev/null
[[ -f "$lock/owner" ]]
# The acquisition ran in the child; release its known fixture lock explicitly.
store_lock="$lock"
tool_store_release
# Force owner cleanup between observations, including its record-before-rmdir
# window. A missing initial record or replacement directory still refuses.
for withdrawal in directory record replacement; do
    mkdir -m 700 "$lock"
    cp "$fixture/owner.before" "$lock/owner"
    rm -f "$fixture/observed-owner"
    status=0
    (
        perl() {
            if [[ "$withdrawal" == directory && "${!#}" == "$store_slot" ]]; then
                rm "$lock/owner"
                rmdir "$lock"
            elif [[ "$withdrawal" != directory && "$2" == *'malformed tool installation owner record'* ]]; then
                if [[ ! -f "$fixture/observed-owner" ]]; then touch "$fixture/observed-owner";
                elif [[ "$withdrawal" == replacement ]]; then
                    mv "$lock" "$fixture/retained-owner-lock"
                    mkdir -m 700 "$lock"
                elif [[ -f "$lock/owner" ]]; then
                    rm "$lock/owner"
                    touch "$fixture/observed-withdrawal"
                else rmdir "$lock"; fi
            fi
            command perl "$@"
        }
        tool_store_wait_unlocked 5 || exit $?
        [[ ! -e "$lock" ]] || exit 1
        if [[ "$withdrawal" == record ]]; then
            [[ "$tool_store_waited" == true && -f "$fixture/observed-withdrawal" ]]
        fi
    ) > "$fixture/$withdrawal-withdrawal.log" 2>&1 || status=$?
    if [[ "$withdrawal" == replacement ]]; then
        [[ "$status" != 0 && -d "$lock" && ! -e "$lock/owner" ]]
        cmp "$fixture/owner.before" "$fixture/retained-owner-lock/owner"
        rm "$fixture/retained-owner-lock/owner"
        rmdir "$fixture/retained-owner-lock" "$lock"
    elif [[ "$status" != 0 ]]; then
        cat "$fixture/$withdrawal-withdrawal.log" >&2
        exit 1
    fi
done
# A failed release may leave its admitted directory without a record. Keep the
# original deadline; absence of the record is not permission to acquire it.
mkdir -m 700 "$lock"
cp "$fixture/owner.before" "$lock/owner"
tool_store_wait_unlocked 2 > "$fixture/wait.log" 2>&1 & pending=$!
await_waiter
rm "$lock/owner"
status=0
wait "$pending" || status=$?; pending=''
[[ "$status" == 1 && -d "$lock" && ! -e "$lock/owner" ]]
grep -F 'wait timed out' "$fixture/wait.log" >/dev/null
rmdir "$lock"
# Other slots have no reason to wait, even while this one is occupied.
mkdir -m 700 "$lock"
cp "$fixture/owner.before" "$lock/owner"
(store_slot="$store_root/other"; mkdir -m 700 "$store_slot"; tool_store_acquire 1; tool_store_release)
status=0
tool_store_wait_unlocked 1 > "$fixture/timeout.log" 2>&1 || status=$?
[[ "$status" == 1 ]]
grep -F 'wait timed out' "$fixture/timeout.log" >/dev/null
cmp "$lock/owner" "$fixture/owner.before"
# Zero opts out without inspecting or sleeping on the occupied lock.
tool_store_wait_unlocked 0
[[ "$tool_store_waited" == false ]]
# Interrupt the waiter, preserving the foreign owner and exact signal status.
(
    trap 'exit 143' TERM
    tool_store_wait_unlocked 5
) > "$fixture/wait.log" 2>&1 & pending=$!
await_waiter
kill -TERM "$pending"
status=0
wait "$pending" || status=$?
pending=''
[[ "$status" == 143 ]]
cmp "$lock/owner" "$fixture/owner.before"
rm "$lock/owner"
rmdir "$lock"
# Invalid, redirected and inaccessible lock records must never enter polling.
for kind in file link malformed missing-owner linked-owner unreadable-owner unsearchable-lock; do
    case "$kind" in
        file) printf 'foreign file\n' > "$lock" ;;
        link) ln -s "$fixture/absent" "$lock" ;;
        *)
            mkdir -m 700 "$lock"
            cp "$fixture/owner.before" "$lock/owner"
            case "$kind" in
                malformed) printf 'foreign owner\n' > "$lock/owner" ;;
                missing-owner) rm "$lock/owner" ;;
                linked-owner) rm "$lock/owner"; ln -s "$fixture/owner.before" "$lock/owner" ;;
                unreadable-owner) chmod 000 "$lock/owner" ;;
                unsearchable-lock) chmod 600 "$lock" ;;
            esac ;;
    esac
    if [[ ( "$kind" == unreadable-owner && -r "$lock/owner" ) ||
          ( "$kind" == unsearchable-lock && -x "$lock" ) ]]; then
        rm -rf "$lock"
        continue
    fi
    status=0
    tool_store_wait_unlocked 1 > "$fixture/$kind.log" 2>&1 || status=$?
    [[ "$status" != 0 ]]
    if grep -F 'Waiting for' "$fixture/$kind.log"; then exit 1; fi
    [[ "$kind" != unsearchable-lock ]] || chmod 700 "$lock"
    rm -rf "$lock"
done
# Never retry or relabel an atomic mkdir permission failure as contention.
(
    mkdir() {
        if [[ "${!#}" == "$lock" ]]; then echo 'permission observation' >&2; return 13; fi
        command mkdir "$@"
    }
    status=0
    tool_store_acquire 1 2> "$fixture/permission.log" || status=$?
    [[ "$status" == 13 ]]
    grep -Fx 'permission observation' "$fixture/permission.log" >/dev/null
    if grep -E 'already exists|Waiting for' "$fixture/permission.log"; then exit 1; fi
)
fixture_complete=true
echo 'Tool-store bounded waiting, owner refusal, timeout, interruption and acquisition failures passed'
