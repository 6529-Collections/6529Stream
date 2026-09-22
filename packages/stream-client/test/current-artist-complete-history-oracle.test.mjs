import test from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { posix } from 'node:path';
import { AbiCoder, Interface, ParamType } from 'ethers';
import { ARTIST_COMPLETE_HISTORY_TUPLES, ARTIST_COMPLETE_HISTORY_COMPILER_SOURCE } from '../dist/generated/artist-complete-history.js';
import { completeHistorySchemas, completeHistoryTypes } from '../scripts/generate-current-artist-complete-history-source-profile.mjs';
import { solidityImports } from '../scripts/generate-current-entropy-policy-succession-fixture.mjs';
import { fixture, valueField, compiledInterfaces, source } from './current-artist-complete-history-source-fixture.mjs';
import { literalReader } from './artist-complete-history-literals.mjs';

const sha = value => createHash('sha256').update(value).digest('hex');
const abi = AbiCoder.defaultAbiCoder();

test('complete-history source witness retains authenticated source closure and explicit execution limits', () => {
  assert.equal(fixture.currentSource.commit, '5104c901b5bb348829c62a5638291c1bf2fb0e5b');
  assert.equal(fixture.currentSource.tree, '77176ff83feb16ff31c0df1d220bfd1098f432b2');
  assert.equal(ARTIST_COMPLETE_HISTORY_COMPILER_SOURCE, fixture.currentSource.commit);
  assert.equal(fixture.compilerEvidence.inputSha256, '892685a31fa477f11750e2bbf29d8b2320360ed213323d2df8ffdcbd69145626');
  assert.equal(fixture.compilerEvidence.outputSha256, '22fe7f708956aa4f9cc2351fe593e640561f06f570a9c22b6e701f2eef89dfc6');
  assert.equal(fixture.compilerEvidence.bridgeSha256, 'd7e58cac1e4261384ede97185ad1402d15e330d07cc0e0a45f03ff592d99b38d');
  assert.equal(fixture.compilerEvidence.sources, 4620);
  assert.equal(fixture.compilerEvidence.errors, 0);
  assert.equal(fixture.qualification.nativeExecutionVerified, false);
  assert.match(fixture.qualification.description, /No held handoff, Class4 implementation, runtime, Safe execution or deployment evidence/);
  for (const [path, row] of Object.entries(fixture.sources)) {
    const raw = Buffer.from(row.text, 'utf8');
    assert.equal(sha(raw), row.sha256, path);
    assert.equal(raw.length, row.bytes, path);
    assert.equal(createHash('sha1').update(Buffer.concat([Buffer.from(`blob ${raw.length}\0`), raw])).digest('hex'), row.blob, path);
    for (const imported of solidityImports(row.text)) {
      const target = imported.startsWith('.') ? posix.normalize(posix.join(posix.dirname(path), imported)) : imported;
      assert.ok(fixture.sources[target], `${path} imports ${target}`);
    }
  }
  assert.equal(Object.keys(fixture.sources).length, fixture.statistics.sourceClosure);
});

test('complete-history generated values retain every original compiler field and array dimension', () => {
  const seen = new Set();
  function visit(field) {
    if (!field.components) return;
    const name = field.internalType.replace(/^struct /, '').replace(/(\[[0-9]*\])+$/, '');
    const expected = ParamType.from({ type: 'tuple', components: valueField(field).components });
    const actual = ParamType.from(ARTIST_COMPLETE_HISTORY_TUPLES[name]);
    assert.equal(actual.format('full'), expected.format('full'), name);
    seen.add(name); field.components.forEach(visit);
  }
  for (const declaration of Object.values(fixture.selections)) for (const entry of declaration.abi) {
    for (const field of [...entry.inputs ?? [], ...entry.outputs ?? []]) visit(field);
  }
  assert.deepEqual([...seen].sort(), Object.keys(ARTIST_COMPLETE_HISTORY_TUPLES).sort());
  assert.deepEqual(completeHistorySchemas(fixture.selections, fixture.libraryValueTypeEvidence), fixture.schemas);
  assert.equal(completeHistoryTypes(fixture), readFileSync(new URL('../src/generated/artist-complete-history.ts', import.meta.url), 'utf8').replace(/\r\n/g, '\n'));
});

test('complete-history nominal enums require an ordinary compiler value witness', () => {
  let count = 0;
  for (const [name, evidence] of Object.entries(fixture.libraryValueTypeEvidence)) {
    let field = evidence.entry[evidence.direction];
    for (const key of evidence.parameterPath) field = field[key];
    assert.equal(field.internalType, name); assert.equal(field.type, 'uint8');
    assert.ok(fixture.sources[evidence.source]); count++;
  }
  assert.ok(count >= 4);
  assert.throws(() => completeHistorySchemas(fixture.selections, {}), /Unwitnessed nominal enum/);
});

test('complete-history uses unchanged original wallet calls and genuine nominal preparation selectors', () => {
  const registry = compiledInterfaces.StreamArtistOnboardingRegistry;
  const coordinator = compiledInterfaces.StreamArtistOnboardingCoordinator;
  assert.equal(registry.getFunction('hydrateRecoveredArtistAuthority').selector, '0xb80889ba');
  assert.equal(registry.getFunction('hydrateRecoveredArtistAuthorityWithConsents').selector, '0x1e2d2f62');
  assert.equal(coordinator.getFunction('coordinateHydrateRecoveredArtistAuthority').selector, '0xff2700ab');
  assert.equal(coordinator.getFunction('coordinateHydrateRecoveredArtistAuthorityWithConsents').selector, '0xbab9201d');
  const selectors = Object.entries(fixture.selections.StreamArtistRecoveredHydrationPrepared.methodIdentifiers).filter(([signature]) => signature.startsWith('prepare('));
  assert.deepEqual(selectors.map(([, selector]) => selector).sort(), ['4925300f', '72c84763']);
  for (const contract of [registry, coordinator]) for (const name of ['HydrateRecoveredArtistAuthority', 'HydrateRecoveredArtistAuthorityWithConsents']) {
    const method = contract === registry ? name[0].toLowerCase() + name.slice(1) : 'coordinate' + name;
    assert.equal(contract.getFunction(method).stateMutability, 'nonpayable');
  }
});

test('complete-history carrier order comes from the original production codec and inventory types', () => {
  const inventory = ParamType.from(ARTIST_COMPLETE_HISTORY_TUPLES['StreamArtistCompleteHistoryTypes.Inventory']);
  assert.deepEqual(inventory.components.map(field => field.name), ['provenance', 'bindings', 'archive', 'platforms', 'accepted', 'accounts']);
  const scope = ParamType.from(ARTIST_COMPLETE_HISTORY_TUPLES['StreamArtistRecoveredMultipleTypes.State']);
  assert.deepEqual(scope.components.map(field => field.name), ['artists', 'collections', 'rows']);
  assert.match(source('StreamArtistCompleteHistoryCodec.sol'), /abi\.encode\(C\.SCHEMA, C\.VERSION, owner, s, auxiliary\)/);
  assert.match(source('StreamArtistCompleteHistoryTypes.sol'), /6529STREAM_ARTIST_COMPLETE_HISTORY_V1/);
  // A populated nonce row catches order, width and dynamic-array changes independently.
  const lane = fixture.schemas['StreamArtistRecoveredIdentityHydrationTypes.NonceLane'];
  assert.ok(lane);
  const fields = lane.map(valueField), parameter = ParamType.from({ type: 'tuple', components: fields });
  function sample(p) {
    if (p.baseType === 'tuple') return p.components.map(sample);
    if (p.baseType === 'array') return Array.from({ length: p.arrayLength < 0 ? 2 : p.arrayLength }, () => sample(p.arrayChildren));
    if (p.type === 'address') return '0x1111111111111111111111111111111111111111';
    if (p.type === 'bool') return true;
    if (p.type === 'string') return 'complete history';
    if (p.type === 'bytes') return '0x010203';
    if (p.type.startsWith('bytes')) return '0x' + 'a5'.repeat(Number(p.type.slice(5)));
    return 7n;
  }
  const values = sample(parameter);
  assert.equal(abi.encode([parameter], [values]), abi.encode([ARTIST_COMPLETE_HISTORY_TUPLES['StreamArtistRecoveredIdentityHydrationTypes.NonceLane']], [values]));
});

test('complete-history ordinary source read fragments match original production compiler interfaces', () => {
  const read = literalReader(new URL('../src/current-artist-complete-history-hydration-workflow.ts', import.meta.url));
  let checked = 0;
  for (const name of ['abi', 'consentAbi', 'identityAbi', 'attestationAbi', 'clockAbi', 'generationAbi', 'collaboratorAbi', 'platformAbi', 'sanctionAbi']) {
    const actual = new Interface(read(name));
    for (const fragment of actual.fragments) {
      assert.equal(fragment.type, 'function');
      const originals = Object.values(compiledInterfaces).map(contract => contract.getFunction(fragment.format('sighash'))).filter(Boolean);
      assert.ok(originals.length, `${name}.${fragment.name} has an original public endpoint`);
      assert.ok(originals.some(original => original.stateMutability === fragment.stateMutability
        && JSON.stringify(original.inputs.map(row => row.format('sighash'))) === JSON.stringify(fragment.inputs.map(row => row.format('sighash')))
        && JSON.stringify(original.outputs.map(row => row.format('sighash'))) === JSON.stringify(fragment.outputs.map(row => row.format('sighash')))), `${name}.${fragment.name} complete return ABI`);
      checked++;
    }
  }
  assert.ok(checked >= 65);
});
