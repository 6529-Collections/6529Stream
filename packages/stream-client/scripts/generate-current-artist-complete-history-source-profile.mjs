// ABI198 projection from ordinary integrated-source compiler evidence only.
// This does not compile, execute contracts, or consume another task's handoff.
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { readFileSync, writeFileSync } from 'node:fs';
import { posix, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { solidityImports } from './generate-current-entropy-policy-succession-fixture.mjs';

export const SOURCE = '5104c901b5bb348829c62a5638291c1bf2fb0e5b';
const TREE = '77176ff83feb16ff31c0df1d220bfd1098f432b2';
const INPUT_SHA = '892685a31fa477f11750e2bbf29d8b2320360ed213323d2df8ffdcbd69145626';
const OUTPUT_SHA = '22fe7f708956aa4f9cc2351fe593e640561f06f570a9c22b6e701f2eef89dfc6';
const BRIDGE_SHA = 'd7e58cac1e4261384ede97185ad1402d15e330d07cc0e0a45f03ff592d99b38d';
const root = fileURLToPath(new URL('../../../', import.meta.url));
const fixtureURL = new URL('../test/fixtures/current-artist-complete-history-source-profile.json', import.meta.url);
const typesURL = new URL('../src/generated/artist-complete-history.ts', import.meta.url);
const sha = raw => createHash('sha256').update(raw).digest('hex');
const sorted = value => Object.fromEntries(Object.entries(value).sort(([a], [b]) => a < b ? -1 : a > b ? 1 : 0));
const ordinaryRoots = ['StreamArtistOnboardingRegistry', 'StreamArtistOnboardingCoordinator',
  'StreamArtistBindingLifecycle', 'StreamArtistCollaboratorLifecycle', 'StreamArtistIdentityAuthority',
  'StreamArtistAcceptanceLifecycle', 'StreamArtistAttributionLifecycle', 'StreamArtistPayoutLifecycle',
  'StreamArtistConsentFinalityLifecycle', 'StreamArtistArchiveV2', 'IStreamArtistArchiveV2', 'StreamArtistOwner',
  'IStreamArtistAuthorityCheckpoint', 'IStreamArtistRecoveredHydrationOwner',
  'IStreamArtistRecoveredNativeChronology', 'IStreamArtistHistory', 'IStreamArtistNativeReceipts',
  'IStreamArtistReconstruction', 'IStreamArtistRecoveredTimingInventory', 'IStreamCorePointers',
  'IStreamCoreGasParameters', 'IStreamGovernanceActionFacts', 'IStreamArtworkFinalityRecovery',
  'IStreamFinalityRecoveryGovernanceBinding', 'IStreamEntropyArtistUnavailability',
  'IStreamEntropyFreshRecovery', 'IStreamArtistAuthorityHydrationOwner',
  'IStreamArtistAuthorityHydrationCoordinator', 'IStreamArtistRecoveredHydrationCoordinator'];
const valueRoots = ['StreamArtistRecoveredAggregateRatificationRows', 'StreamArtistC2PACredentials',
  'StreamArtistRecoveredHydrationCommit'];

function git(args, input) { return execFileSync('git', args, { cwd: root, input, windowsHide: true, maxBuffer: 180 * 1024 * 1024 }); }
function blobs(paths) {
  const raw = git(['cat-file', '--batch'], paths.map(path => `${SOURCE}:${path}\n`).join(''));
  const result = {}; let cursor = 0;
  for (const path of paths) {
    const end = raw.indexOf(10, cursor), line = raw.subarray(cursor, end).toString('utf8');
    const match = /^([a-f0-9]{40}) blob ([0-9]+)$/.exec(line);
    if (!match) throw Error(`Missing committed source ${path}`);
    const count = Number(match[2]); cursor = end + 1;
    const bytes = raw.subarray(cursor, cursor + count); cursor += count;
    if (bytes.length !== count || raw[cursor++] !== 10) throw Error('Invalid Git blob transport');
    const text = bytes.toString('utf8');
    if (!Buffer.from(text).equals(bytes)) throw Error('Invalid source UTF-8');
    result[path] = { blob: match[1], sha256: sha(bytes), bytes: count, text };
  }
  if (cursor !== raw.length) throw Error('Unexpected Git blob tail');
  return result;
}
function pinned(raw, expected, label) {
  if (sha(raw) !== expected) throw Error(`Wrong ${label} bytes`);
  return JSON.parse(raw);
}
const typeName = parameter => parameter.internalType?.replace(/^struct /, '').replace(/(\[[0-9]*\])+$/, '');
function shape(parameter, evidence) {
  let type = parameter.type;
  if (parameter.internalType?.startsWith('enum ') && !/^uint8(?:\[[0-9]*\])*$/.test(type)) {
    const nominal = parameter.internalType.slice(5).replace(/(\[[0-9]*\])+$/, '');
    const suffix = type.slice(nominal.length);
    if (!type.startsWith(nominal) || !/^(\[[0-9]*\])*$/.test(suffix) || !evidence['enum ' + nominal]) throw Error(`Unwitnessed nominal enum ${type}`);
    type = 'uint8' + suffix;
  }
  return { name: parameter.name, type, internalType: parameter.internalType,
    ...(parameter.components ? { components: parameter.components.map(field => shape(field, evidence)) } : {}) };
}

export function completeHistorySchemas(selections, evidence) {
  const schemas = {};
  function collect(parameter) {
    if (!parameter.components) return;
    if (!parameter.internalType?.startsWith('struct ')) throw Error('Unnamed compiler tuple');
    const name = typeName(parameter), fields = parameter.components.map(field => shape(field, evidence));
    if (schemas[name] && JSON.stringify(schemas[name]) !== JSON.stringify(fields)) throw Error(`Conflicting compiler type ${name}`);
    schemas[name] = fields;
    parameter.components.forEach(collect);
  }
  for (const declaration of Object.values(selections)) for (const entry of declaration.abi) {
    for (const parameter of [...entry.inputs ?? [], ...entry.outputs ?? []]) collect(parameter);
  }
  return sorted(schemas);
}

export function completeHistorySourceProfile(inputRaw, outputRaw, bridgeRaw) {
  const input = pinned(inputRaw, INPUT_SHA, 'ABI198 input'), output = pinned(outputRaw, OUTPUT_SHA, 'ABI198 output');
  const bridge = pinned(bridgeRaw, BRIDGE_SHA, 'ABI198 source bridge');
  if (bridge.commit !== SOURCE || bridge.mismatches.length || Object.keys(input.sources).length !== 4620
    || (output.errors ?? []).some(row => row.severity === 'error')
    || git(['rev-parse', `${SOURCE}^{tree}`]).toString().trim() !== TREE) throw Error('Compiler source coordinates differ');
  // Authenticate the entire captured source universe; only the selected closure is retained.
  const captured = blobs(Object.keys(input.sources).sort());
  let normalized = 0;
  for (const [path, row] of Object.entries(captured)) {
    const literal = input.sources[path].content;
    if ((literal !== row.text && literal !== row.text.replace(/\r\n/g, '\n'))
      || bridge.committedBlobSHA256[path] !== row.sha256) throw Error(`Compiler/Git source mismatch ${path}`);
    if (literal !== row.text) normalized++;
  }
  const selections = {};
  for (const [path, declarations] of Object.entries(output.contracts)) {
    if (!path.startsWith('smart-contracts/')) continue;
    for (const [name, declaration] of Object.entries(declarations)) {
      if (!ordinaryRoots.includes(name) && !valueRoots.includes(name) && !name.startsWith('StreamArtistCompleteHistory') && name !== 'StreamArtistRecoveredHydrationPrepared') continue;
      if (selections[name]) throw Error(`Duplicate selected declaration ${name}`);
      const kind = ordinaryRoots.includes(name) ? 'ordinary' : 'library';
      selections[name] = { source: path, kind, abi: declaration.abi, methodIdentifiers: declaration.evm.methodIdentifiers };
    }
  }
  for (const name of [...ordinaryRoots, ...valueRoots, 'StreamArtistRecoveredHydrationPrepared', 'StreamArtistCompleteHistoryCodec', 'StreamArtistCompleteHistoryPreparation']) {
    if (!selections[name]) throw Error(`Missing selected contract ${name}`);
  }
  // Library ABIs use nominal enum names. Retain a complete ordinary ABI entry
  // witnessing each value encoding before substituting it in a value-only tuple.
  const libraryValueTypeEvidence = {};
  function witness(parameter, location, parameterPath) {
    if (parameter.internalType?.startsWith('enum ') && parameter.type === 'uint8' && !libraryValueTypeEvidence[parameter.internalType]) {
      libraryValueTypeEvidence[parameter.internalType] = { ...location, parameterPath, abiType: 'uint8' };
    }
    (parameter.components ?? []).forEach((field, i) => witness(field, location, [...parameterPath, 'components', i]));
  }
  for (const [source, declarations] of Object.entries(output.contracts)) {
    if (!source.startsWith('smart-contracts/')) continue;
    for (const [contract, declaration] of Object.entries(declarations)) declaration.abi.forEach((entry, abiIndex) => {
      for (const direction of ['inputs', 'outputs']) (entry[direction] ?? []).forEach((parameter, i) => witness(parameter, { source, contract, abiIndex, entry, direction }, [i]));
    });
  }
  const requiredEnums = new Set();
  function requireEnum(parameter) {
    if (parameter.internalType?.startsWith('enum ')) requiredEnums.add(parameter.internalType.replace(/(\[[0-9]*\])+$/, ''));
    (parameter.components ?? []).forEach(requireEnum);
  }
  for (const declaration of Object.values(selections)) for (const entry of declaration.abi) for (const parameter of [...entry.inputs ?? [], ...entry.outputs ?? []]) requireEnum(parameter);
  for (const name of Object.keys(libraryValueTypeEvidence)) if (!requiredEnums.has(name)) delete libraryValueTypeEvidence[name];
  const schemas = completeHistorySchemas(selections, libraryValueTypeEvidence);
  const sources = {}, pending = [...new Set([...Object.values(selections).map(row => row.source), ...Object.values(libraryValueTypeEvidence).map(row => row.source)])];
  while (pending.length) {
    const path = pending.pop();
    if (sources[path]) continue;
    const row = captured[path]; if (!row) throw Error(`Missing source dependency ${path}`);
    sources[path] = row;
    for (const imported of solidityImports(row.text)) pending.push(imported.startsWith('.') ? posix.normalize(posix.join(posix.dirname(path), imported)) : imported);
  }
  return { schemaVersion: 1, profile: 'artist-complete-history-v1', currentSource: { commit: SOURCE, tree: TREE },
    compilerEvidence: { capture: 'ABI198', version: '0.8.19+commit.7dd6d404', inputSha256: INPUT_SHA, outputSha256: OUTPUT_SHA,
      bridgeSha256: BRIDGE_SHA, sources: 4620, errors: 0, normalizedLineEndingSources: normalized, settings: input.settings },
    qualification: { nativeExecutionVerified: false, sourceEqualsCompilerInput: normalized === 0,
      description: 'Ordinary committed-source ABI/storage/method-ID capture only. Selected source bytes are authenticated against Git; line-ending normalization is recorded. Library selectors are nominal compiler witnesses, not wallet entrypoints. No held handoff, Class4 implementation, runtime, Safe execution or deployment evidence.' },
    statistics: { selectedDeclarations: Object.keys(selections).length, sourceClosure: Object.keys(sources).length, schemas: Object.keys(schemas).length },
    selections: sorted(selections), libraryValueTypeEvidence: sorted(libraryValueTypeEvidence), schemas, sources: sorted(sources) };
}

/** Emit compact structural types and compositional ABI tuple strings from compiler fields. */
export function completeHistoryTypes(profile) {
  const names = Object.keys(profile.schemas).sort(), ids = new Map(names.map((name, i) => [name, `T${i}`]));
  const declarations = [], emitted = new Set();
  function abi(parameter) {
    if (!parameter.components) return parameter.type;
    const name = typeName(parameter); emit(name);
    return '${' + ids.get(name) + '}' + parameter.type.slice(5);
  }
  function emit(name) {
    if (emitted.has(name)) return;
    emitted.add(name);
    const fields = profile.schemas[name];
    if (!fields) throw Error(`Missing type dependency ${name}`);
    const tuple = 'tuple(' + fields.map(field => `${abi(field)} ${field.name}`).join(',') + ')';
    declarations.push(`const ${ids.get(name)} = \`${tuple}\`;`);
  }
  function ts(parameter) {
    const suffix = parameter.type.match(/(\[[0-9]*\])+$/)?.[0] ?? '';
    const base = parameter.type.slice(0, parameter.type.length - suffix.length);
    let value = parameter.components ? `ArtistCompleteHistoryTypes[${JSON.stringify(typeName(parameter))}]`
      : base === 'address' ? 'Address' : base === 'bool' ? 'boolean' : base === 'string' ? 'string'
        : /^bytes/.test(base) || base === 'function' ? 'Hex' : /^u?int/.test(base) ? 'bigint' : null;
    if (!value) throw Error(`Unsupported ABI type ${parameter.type}`);
    for (const [, count] of suffix.matchAll(/\[([0-9]*)\]/g)) value = count === '' ? `readonly (${value})[]` : `readonly [${Array(Number(count)).fill(value).join(', ')}]`;
    return value;
  }
  names.forEach(emit);
  return '// Generated by generate-current-artist-complete-history-source-profile.mjs; do not edit.\n'
    + 'import type { Address, Hex } from "./contracts.js";\n\n'
    + `export const ARTIST_COMPLETE_HISTORY_COMPILER_SOURCE = ${JSON.stringify(SOURCE)};\n\n`
    + declarations.join('\n') + '\n\nexport const ARTIST_COMPLETE_HISTORY_TUPLES = {\n'
    + names.map(name => `  ${JSON.stringify(name)}: ${ids.get(name)},`).join('\n') + '\n} as const;\n\n'
    + 'export interface ArtistCompleteHistoryTypes {\n'
    + names.map(name => `  ${JSON.stringify(name)}: { ${profile.schemas[name].map(field => `readonly ${field.name}: ${ts(field)};`).join(' ')} };`).join('\n')
    + '\n}\n';
}

function main() {
  const args = process.argv.slice(2), check = args.at(-1) === '--check';
  if (check) args.pop();
  if (args.length !== 3) throw Error('Usage: generator INPUT_JSON OUTPUT_JSON SOURCE_BRIDGE_JSON [--check]');
  const profile = completeHistorySourceProfile(...args.map(path => readFileSync(resolve(path))));
  const outputs = [[fixtureURL, JSON.stringify(profile, null, 2) + '\n'], [typesURL, completeHistoryTypes(profile)]];
  for (const [file, text] of outputs) {
    if (check) { if (readFileSync(file, 'utf8').replace(/\r\n/g, '\n') !== text) throw Error(`Stale projection ${file}`); }
    else writeFileSync(file, text, 'utf8');
  }
  console.log(`Verified ABI198 complete-history projection: ${profile.statistics.selectedDeclarations} declarations, ${profile.statistics.sourceClosure} sources, ${profile.statistics.schemas} types`);
}
if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) main();
