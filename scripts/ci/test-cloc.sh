#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd -P)"
FIXTURE="$(mktemp -d "${TMPDIR:-/tmp}/shared-tooling-cloc-test.XXXXXX")"
trap 'rm -rf "$FIXTURE"' EXIT

for command in cargo cloc jq; do
    command -v "$command" >/dev/null 2>&1 || {
        echo "cloc test requires $command" >&2
        exit 1
    }
done

mkdir -p \
    "$FIXTURE/crates/alpha/src" \
    "$FIXTURE/crates/alpha/tests" \
    "$FIXTURE/crates/beta/src"

cat >"$FIXTURE/Cargo.toml" <<'TOML'
[workspace]
members = ["crates/alpha", "crates/beta"]
resolver = "2"
TOML

cat >"$FIXTURE/crates/alpha/Cargo.toml" <<'TOML'
[package]
name = "alpha"
version = "0.1.0"
edition = "2021"
TOML

cat >"$FIXTURE/crates/alpha/src/lib.rs" <<'RUST'
pub fn value() -> u8 {
    1
}

#[cfg(test)]
mod tests {
    #[test]
    fn inline_test() {}

    #[testing]
    fn similarly_named_non_test_attribute() {}
}
RUST

cat >"$FIXTURE/crates/alpha/tests/public.rs" <<'RUST'
#[test]
fn integration_test() {}
RUST

cat >"$FIXTURE/crates/beta/Cargo.toml" <<'TOML'
[package]
name = "beta"
version = "0.1.0"
edition = "2021"
TOML

cat >"$FIXTURE/crates/beta/src/lib.rs" <<'RUST'
#[tokio::test(flavor = "current_thread")]
async fn async_test() {}
RUST

output="$(bash "$ROOT/scripts/dev/cloc.sh" "$FIXTURE")"

alpha_row="$(printf '%s\n' "$output" | awk '$1 == "alpha" { print $0 }')"
beta_row="$(printf '%s\n' "$output" | awk '$1 == "beta" { print $0 }')"
total_row="$(printf '%s\n' "$output" | awk '$1 == "TOTAL" { print $0 }')"

read -r _ _ alpha_test_loc _ alpha_test_fns alpha_inline_fns <<<"$alpha_row"
read -r _ _ _ _ beta_test_fns beta_inline_fns <<<"$beta_row"
read -r _ _ _ _ total_test_fns total_inline_fns <<<"$total_row"

[[ "$alpha_test_loc" -gt 0 ]]
[[ "$alpha_test_fns" -eq 2 && "$alpha_inline_fns" -eq 1 ]]
[[ "$beta_test_fns" -eq 1 && "$beta_inline_fns" -eq 1 ]]
[[ "$total_test_fns" -eq 3 && "$total_inline_fns" -eq 2 ]]

echo "cloc tests passed"

