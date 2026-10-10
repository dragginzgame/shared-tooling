#!/usr/bin/env bash
set -euo pipefail

# Native qualification with explicitly prepared tools; never install or download.
# Keep successful and failed artifacts in a fresh caller-selected directory.
[[ $# == 1 && "$1" == /* && "$1" != *$'\n'* && "$1" != *$'\r'* && ! -e "$1" && ! -L "$1" ]] || {
    echo 'usage: qualify-wasm-opt.sh <new-absolute-evidence-directory>' >&2; exit 2;
}
ROOT="$0"
[[ "$ROOT" == /* ]] || ROOT="$PWD/$ROOT"
ROOT="$(cd -P "${ROOT%/*}/../.." && printf '%s/.' "$PWD")"
ROOT="${ROOT%/.}"
bin="$(bash "$ROOT/scripts/dev/install-ic-tools.sh" --check)"
[[ "$(node --version)" == "v$(jq -er '.engines.node' "$ROOT/ci/frontend/package.json")" ]] || exit 1
parent="$(cd -P "${1%/*}/" && printf '%s/.' "$PWD")"
parent="${parent%/.}"
[[ "$parent" != *$'\n'* && "$parent" != *$'\r'* ]] || {
    echo 'evidence parent may not contain LF or CR' >&2; exit 2;
}
evidence="$parent/${1##*/}"
mkdir "$evidence"
echo "Wasm optimization evidence: $evidence"
exec > >(tee "$evidence/qualification.log") 2>&1
{
    git -C "$ROOT" rev-parse HEAD
    uname -sm
    node --version
    "$bin/wasm-opt" --version
    bash "$ROOT/scripts/ci/verify-file-checksum.sh" --print sha256 "$bin/wasm-opt"
    bash "$ROOT/scripts/ci/verify-file-checksum.sh" --print sha256 "$0"
} > "$evidence/source.txt"
cp "$ROOT/ci/ic-tools.tsv" "$evidence/pins.tsv"
cat > "$evidence/input.wat" <<'WAT'
(module
  (import "ic0" "msg_reply_data_append" (func $append (param i32 i32)))
  (import "ic0" "msg_reply" (func $reply))
  (memory (export "memory") 1)
  (func $compute (export "compute") (param $x i32) (result i32)
    (if (result i32) (i32.lt_s (local.get $x) (i32.const 0))
      (then (i32.add (local.get $x) (i32.const 1)))
      (else (if (result i32) (i32.eqz (local.get $x))
        (then (i32.const 42))
        (else (i32.mul (local.get $x) (i32.const 2)))))))
  (func (export "canister_query answer")
    (i32.store (i32.const 0) (call $compute (i32.const 0)))
    (call $append (i32.const 0) (i32.const 4))
    (call $reply)))
WAT
cat > "$evidence/check.cjs" <<'JS'
const assert = require('node:assert/strict');
const fs = require('node:fs');
for (const path of process.argv.slice(2)) {
  const module = new WebAssembly.Module(fs.readFileSync(path));
  assert.deepEqual(WebAssembly.Module.imports(module), [
    { module: 'ic0', name: 'msg_reply_data_append', kind: 'function' },
    { module: 'ic0', name: 'msg_reply', kind: 'function' },
  ]);
  assert.deepEqual(WebAssembly.Module.exports(module).map(e => e.name).sort(),
    ['canister_query answer', 'compute', 'memory']);
  const payload = [];
  let replies = 0;
  const { exports } = new WebAssembly.Instance(module, { ic0: {
    msg_reply_data_append(offset, length) {
      payload.push(...new Uint8Array(exports.memory.buffer, offset, length));
    },
    msg_reply() { replies++; },
  } });
  for (const x of [-2147483648, -100, -1, 0, 1, 100, 1073741824, 2147483647]) {
    assert.equal(exports.compute(x), x < 0 ? (x + 1) | 0 : x === 0 ? 42 : (x * 2) | 0);
  }
  exports['canister_query answer']();
  assert.equal(replies, 1);
  assert.deepEqual(payload, [42, 0, 0, 0]);
  console.log(`Wasm execution passed: ${path}`);
}
JS
"$bin/wasm-opt" "$evidence/input.wat" -O0 -o "$evidence/input.wasm"
for optimization in O3 Os Oz; do
    "$bin/wasm-opt" "$evidence/input.wasm" "-$optimization" -o "$evidence/$optimization.wasm"
done
node "$evidence/check.cjs" "$evidence/input.wasm" \
    "$evidence/O3.wasm" "$evidence/Os.wasm" "$evidence/Oz.wasm"
echo 'Native Wasm optimization and execution passed'
