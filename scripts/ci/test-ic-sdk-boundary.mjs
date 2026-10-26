import assert from 'node:assert/strict';
import { mkdir, mkdtemp, readFile, rm, symlink, writeFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { tmpdir } from 'node:os';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
import { checkIcSdkBoundary } from './check-ic-sdk-boundary.mjs';

const fixture = await mkdtemp(join(tmpdir(), 'shared-sdk-boundary.'));
const sdk = '@icp-sdk/core';
const platform = '@tokostudios/ic-platform';
let complete = false;
try {
  async function write(path, content) {
    const selected = join(fixture, path);
    await mkdir(dirname(selected), { recursive: true });
    await writeFile(selected, content);
    return selected;
  }
  async function reject(path, expected) {
    const before = await readFile(path);
    await assert.rejects(checkIcSdkBoundary([path]), expected);
    assert.deepEqual(await readFile(path), before, 'Refusal changed the selected input');
  }
  function cli(args) {
    const result = spawnSync(process.execPath, [fileURLToPath(new URL('./check-ic-sdk-boundary.mjs', import.meta.url)), ...args],
      { cwd: fixture, encoding: 'utf8', timeout: 30_000, maxBuffer: 16 * 1024 });
    assert.ifError(result.error);
    return result;
  }
  const manifest = {
    dependencies: { [platform]: '^0.1.0', '@caffeineai/object-storage': '1.1.2' },
    devDependencies: { '@icp-sdk/auth': '10.0.2' },
    overrides: { '@caffeineai/object-storage': { [sdk]: '6.1.1' } },
    scripts: { build: 'node build.mjs' },
  };
  const packageFile = await write('browser/package.json', JSON.stringify(manifest));
  const lockFile = await write('browser/package-lock.json', 'Not parsed: transitive graph admission is separate.');
  const sourceFile = await write('browser/client.ts', `import type { Identity } from '${platform}/agent';
export { Principal } from '${platform}/principal';
throw new Error('Selected source must never execute');`);
  const scriptFile = await write('scripts/build.mjs', `import '${platform}/identity';`);
  const inputs = await Promise.all([packageFile, lockFile, sourceFile, scriptFile].map(path => readFile(path)));
  // Prepared dependency trees and ordinary build outputs are not owned sources.
  // Explicitly selecting a generated subtree below still checks its files.
  for (const directory of ['node_modules', '.git', '.tools', 'target', 'dist']) {
    await write(`browser/${directory}/escape.js`, `import '${sdk}/agent';`);
    await write(`browser/${directory}/package.json`, '{invalid external input');
  }
  assert.deepEqual(await checkIcSdkBoundary([join(fixture, 'browser'), join(fixture, 'scripts'), sourceFile]),
    { manifests: 1, sources: 2 }, 'Overlapping roots should not multiply observations');
  assert.deepEqual(await Promise.all([packageFile, lockFile, sourceFile, scriptFile].map(path => readFile(path))), inputs);

  const imports = [
    `import { Principal } from '${sdk}/principal';`,
    `import type { Identity } from '${sdk}/agent';`,
    `export { HttpAgent } from '${sdk}/agent';`,
    `export type { Identity } from '${sdk}/agent';`,
    `export * from '${sdk}/agent';`,
    `import '${sdk}';`,
    `await import('${sdk}/agent');`,
    `await import(\`${sdk}/agent\`);`,
    `require('${sdk}/agent');`,
    `require.resolve('${sdk}/agent');`,
    `import /* consumer */ { Principal } from /* retained */ '${sdk}/principal';`,
    `await import(// selected module\n '${sdk}/agent');`,
    `const generated = \`export { Principal } from '${sdk}/principal';\`;`,
  ];
  for (const source of imports) {
    const path = await write('escape.ts', source);
    await reject(path, /direct SDK import/);
  }
  for (const extension of ['js', 'mjs', 'cjs', 'jsx', 'ts', 'mts', 'cts', 'tsx']) {
    await reject(await write(`escape.${extension}`, imports[0]), /:1: direct SDK import/);
  }
  await reject(await write('escape.ts', `// first line\n\n${imports[0]}`), /:3: direct SDK import/);
  await reject(join(fixture, 'browser/target/escape.js'), /direct SDK import/);
  assert.deepEqual(await checkIcSdkBoundary([await write('safe.mjs', `
import '@icp-sdk/auth';
import '@icp-sdk/ic-wasm';
import '@dfinity/auth-client';
import '@dfinity/agent-extra';
const sdkName = '${sdk}';
`)]), { manifests: 0, sources: 1 });

  for (const name of [sdk, '@dfinity/agent', '@dfinity/principal', '@dfinity/identity',
    '@dfinity/identity-secp256k1', '@dfinity/candid']) {
    await reject(await write('escape.ts', `import '${name}';`), /direct SDK import/);
    for (const field of ['dependencies', 'devDependencies', 'optionalDependencies', 'peerDependencies']) {
      for (const [dependency, selector] of [[name, '^1.0.0'], ['renamed-sdk', `npm:${name}@^1.0.0`]]) {
        await write('browser/package.json', JSON.stringify({ ...manifest, [field]: { [dependency]: selector } }));
        await reject(packageFile, /direct SDK dependency/);
      }
    }
  }
  for (const source of imports) {
    await write('browser/package.json', JSON.stringify({ ...manifest, scripts: { verify: `node -e "${source}"` } }));
    await reject(packageFile, /script verify:1: direct SDK import/);
  }
  for (const malformed of ['{invalid', 'null', '[]', '{"dependencies":[]}', '{"optionalDependencies":null}', '{"peerDependencies":{"sdk":null}}']) {
    await write('browser/package.json', malformed);
    await assert.rejects(checkIcSdkBoundary([packageFile]));
  }
  await write('browser/package.json', JSON.stringify(manifest));

  await assert.rejects(checkIcSdkBoundary([]), /Select at least one/);
  await assert.rejects(checkIcSdkBoundary([join(fixture, 'missing')]), /ENOENT/);
  await mkdir(join(fixture, 'empty'));
  await assert.rejects(checkIcSdkBoundary([join(fixture, 'empty')]), /no package.json or supported/);
  await assert.rejects(checkIcSdkBoundary([await write('README.md', 'Documentation is not an import root')]), /no package.json or supported/);
  await symlink(sourceFile, join(fixture, 'linked.ts'));
  await assert.rejects(checkIcSdkBoundary([join(fixture, 'linked.ts')]), /must not be symlinks/);
  await symlink(join(fixture, 'scripts'), join(fixture, 'browser/redirect'));
  await assert.rejects(checkIcSdkBoundary([join(fixture, 'browser')]), /must not be symlinks/);
  await rm(join(fixture, 'browser/redirect'));
  await rm(join(fixture, 'browser/node_modules'), { recursive: true });
  await symlink(join(fixture, 'scripts'), join(fixture, 'browser/node_modules'));
  assert.deepEqual(await checkIcSdkBoundary([join(fixture, 'browser')]), { manifests: 1, sources: 1 });
  await write('consumer with spaces/safe.ts', `import '${platform}/principal';`);
  assert.equal(cli(['consumer with spaces/safe.ts']).status, 0);
  await write('-client.ts', `import '${platform}/principal';`);
  assert.equal(cli(['--', '-client.ts']).status, 0);
  const help = cli(['--help']);
  assert.equal(help.status, 0);
  assert.match(help.stdout, /usage:/);
  for (const args of [[], ['--unknown'], ['missing'], ['escape.ts']]) {
    const result = cli(args);
    assert.equal(result.status, 1);
    assert.equal(result.stdout, '');
    assert.notEqual(result.stderr, '');
  }
  complete = true;
  console.log('SDK boundary declarations, aliases, literal imports, selected roots, path refusal and read-only checks passed.');
} finally {
  if (complete) await rm(fixture, { recursive: true });
  else console.error(`Failed SDK boundary fixture retained: ${fixture}`);
}
