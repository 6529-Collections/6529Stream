// One closed, additive extension of the retained 1,417-unit timing calibration.
// No test execution, discovery, runner-policy change or network access occurs here.
import { createHash } from 'node:crypto';
import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import ts from 'typescript';
import { verifyUnit } from '../test-runner.mjs';

const HERE = dirname(fileURLToPath(import.meta.url));
const PACKAGE = resolve(HERE, '../..');
const FILE = 'test/current-scoped-policy-inventory-v2-workflow.test.mjs';
const BASE_SHA = 'e8c138a6b1565c15d0560d7ab8a4e13342d6861a0ace335883d4e06b45058c93';
const SEED_SHA = '3ee20513f33cbd1a3898a46ee33683fb234644a098fb81f3bdb5cc934445920c';
const OLD_SHA = '703f2b9e9d34a96ce86d17dbb8de57256b4a09ec7b9634e4d714ff5f3f69dbd6';
const TEST_SHA = '51d6255bd80e47f2b2d5c220d0415537d13ef65d713362f8b82cdcd1487768fb';
const BODY_SHA = '3618305aeb7d3c0ae5c6d273f43fb2cecfac12b9256ff2d8719d29cf92385826';
const ID = 'scoped-policy-inventory-v2-stages-20260922';
const METHODS = ['beginInventory', 'appendNative', 'appendReference', 'appendWork', 'appendRights', 'appendIntent', 'appendIntentWaiver', 'appendInterview', 'appendInterviewWaiver', 'appendRootAuthorization', 'appendDefinition', 'appendTokenOutput', 'appendTokenScript', 'appendTokenLibrary', 'appendTokenRenderer', 'appendTokenCitation', 'sealInventory'];
const MODES = ['direct', 'legacy', 'indexed'];
const oldName = 'all17 original inventory stages capture, simulate and reconcile direct plus both Safe layouts (mocked source producers)';
const names = METHODS.map(method => `original inventory stage ${method}: capture, simulate and reconcile direct plus both Safe layouts (mocked source producers)`);
const hash = value => createHash('sha256').update(value).digest('hex');
const encode = value => Buffer.from(JSON.stringify(value, null, 2) + '\n');
const same = (a, b) => JSON.stringify(a) === JSON.stringify(b);
const readInput = file => readFileSync(resolve(PACKAGE, file));
const registration = name => ({ name, kind: 'test', skip: false, todo: false, only: false });

export function loadInventoryStageTimingEvidence() {
  const bytes = readFileSync(resolve(HERE, 'inventory-stage-timing-extension.json'));
  if (hash(bytes) !== SEED_SHA) throw Error('Sealed stage evidence changed');
  return JSON.parse(bytes);
}

function inspectEvidence(seed) {
  if (seed.schemaVersion !== 1 || seed.id !== ID || seed.testFile !== FILE || seed.baseTableSha256 !== BASE_SHA || seed.oldFileSha256 !== OLD_SHA || seed.newFileSha256 !== TEST_SHA || seed.lifecycleBodySha256 !== BODY_SHA) throw Error('Wrong stage evidence profile');
  if (seed.node !== 'v24.16.0' || seed.platform !== 'win32' || seed.concurrency !== 2 || seed.timeoutMs !== 420000 || seed.inputsUnchanged !== true) throw Error('Wrong measurement environment');
  if (!same(seed.matrix, METHODS.flatMap(method => MODES.map(mode => ({ method, mode }))))) throw Error('Stage/layout matrix differs');
  if (seed.discovery.wholeFile !== false || seed.discovery.registrations.length !== 32 || !same(seed.discovery.registrations.slice(0, 17), names.map(registration))) throw Error('Stage registrations differ');
  if (!same(seed.beforeInputs, seed.afterInputs) || seed.beforeInputs.length !== 52) throw Error('Dependency snapshots differ');
  const paths = new Set();
  for (const input of seed.beforeInputs) {
    if (!/^[\w./-]+$/.test(input.file) || input.file.startsWith('/') || input.file.split('/').includes('..') || paths.has(input.file) || !/^[a-f0-9]{64}$/.test(input.sha256)) throw Error('Invalid dependency inventory');
    paths.add(input.file);
  }
  if (seed.beforeInputs.find(input => input.file === FILE)?.sha256 !== TEST_SHA) throw Error('Missing partitioned source identity');
  if (seed.results.length !== 17) throw Error('Exactly 17 completed stages are required');
  const seen = new Set(), cases = {};
  for (const [index, row] of seed.results.entries()) {
    const name = names[index], unit = { file: FILE, names: [name], id: hash(JSON.stringify([FILE, [name]])).slice(0, 24) };
    if (seen.has(row.unitId)) throw Error('Duplicate stage result');
    seen.add(row.unitId);
    if (row.unitId !== unit.id || row.file !== FILE || !same(row.names, unit.names) || row.error !== null) throw Error('Substituted or failed stage');
    verifyUnit({ inventory: [{ file: FILE, registrations: [registration(name)] }] }, unit, row.report, row);
    if (row.report.length !== 1 || !Number.isFinite(row.elapsedMs) || row.elapsedMs <= 0 || row.elapsedMs > 420000 || !Number.isFinite(row.report[0].durationMs) || row.report[0].durationMs <= 0 || row.report[0].durationMs > row.elapsedMs || row.report[0].error !== null) throw Error('Invalid stage duration or report');
    if (hash(row.tap) !== row.tapSha256 || hash(row.jsonl) !== row.jsonlSha256 || !same(row.jsonl.trim().split(/\r?\n/).map(JSON.parse), row.report)) throw Error('Stage reporter bytes differ');
    const lines = row.tap.split(/\r?\n/);
    for (const line of ['TAP version 13', '# Subtest: ' + name, 'ok 1 - ' + name, '1..1', '# tests 1', '# suites 0', '# pass 1', '# fail 0', '# cancelled 0', '# skipped 0', '# todo 0']) {
      if (lines.filter(value => value === line).length !== 1) throw Error('TAP stage outcome differs');
    }
    if (lines.some(line => /^not ok\b/.test(line)) || lines.filter(line => /^ok\s/.test(line)).length !== 1) throw Error('Unexpected TAP outcome');
    cases[name] = Math.ceil(row.elapsedMs);
  }
  return cases;
}

/** Sealed-source consistency; an explicit reader also checks current applicability.
 * The loader authenticates historical bytes. Arbitrary supplied objects are only
 * consistency-checked here, which permits isolated negative regression fixtures.
 */
export function validateInventoryStageTimingEvidence(seed, read) {
  const cases = inspectEvidence(seed);
  if (read !== undefined) {
    for (const input of seed.beforeInputs) if (hash(read(input.file)) !== input.sha256) throw Error('Stage evidence is inapplicable: ' + input.file);
  }
  const text = seed.testSource;
  if (typeof text !== 'string' || hash(text) !== TEST_SHA) throw Error('Sealed partition source changed');
  const oldBoundary = "test('" + oldName + "',async()=>{\n  for(const kind of methods)for(const mode of ['direct','legacy','indexed']){";
  const newBoundary = "for(const kind of methods)test(`original inventory stage ${kind}: capture, simulate and reconcile direct plus both Safe layouts (mocked source producers)`,async()=>{\n  for(const mode of ['direct','legacy','indexed']){";
  if (text.split(newBoundary).length !== 2 || hash(text.replace(newBoundary, oldBoundary)) !== OLD_SHA) throw Error('Changes outside original registration boundary');
  const ast = ts.createSourceFile(FILE, text, ts.ScriptTarget.Latest, true, ts.ScriptKind.JS);
  const loop = ast.statements.find(ts.isForOfStatement), callback = loop.statement.expression.arguments.find(ts.isArrowFunction);
  if (hash(callback.body.statements[0].statement.getText()) !== BODY_SHA) throw Error('Lifecycle assertions changed');
  const other = ast.statements.filter(node => ts.isExpressionStatement(node) && ts.isCallExpression(node.expression) && node.expression.expression.getText() === 'test')
    .map(node => ({ name: node.expression.arguments[0].text, sha256: hash(node.getText()) }));
  if (other.length !== 15 || !same(other, seed.otherBodies) || !same(seed.discovery.registrations.slice(17), other.map(row => registration(row.name)))) throw Error('Other registrations or assertions changed');
  return cases;
}

function extensionMetadata(seed) {
  return { id: ID, evidenceFile: 'scripts/test-runner/inventory-stage-timing-extension.json', evidenceSha256: SEED_SHA, baseTableSha256: BASE_SHA,
    qualification: '17 successful Windows Node24.16.0 stage measurements; scheduling estimates, not Linux CI guarantees. Original 1,417-unit calibration remains intact.',
    platform: seed.platform, node: seed.node, sourceCommit: seed.sourceCommit, testFile: FILE, testSha256: TEST_SHA,
    dependencyInventorySha256: hash(JSON.stringify(seed.beforeInputs)), addedUnits: 17,
    retiredRegistration: { name: oldName, retainedHistoricalEstimateMs: 361929, retainedForOriginalCalibration: true } };
}

/** Restore the exact original seed without needing the current build or old artifacts. */
export function restoreCalibratedTimings(input) {
  const bytes = Buffer.from(input);
  if (hash(bytes) === BASE_SHA) return bytes;
  const seed = loadInventoryStageTimingEvidence(), cases = inspectEvidence(seed), table = JSON.parse(bytes);
  if (!bytes.equals(encode(table)) || !same(table.timingExtensions, [extensionMetadata(seed)])) throw Error('Unknown or changed timing extension');
  delete table.timingExtensions;
  for (const [name, elapsed] of Object.entries(cases)) {
    if (!Object.hasOwn(table.cases[FILE], name) || table.cases[FILE][name] !== elapsed) throw Error('Changed or missing extended stage estimate');
    delete table.cases[FILE][name];
  }
  const base = encode(table);
  if (hash(base) !== BASE_SHA) throw Error('Original timing calibration changed');
  return base;
}

/** Deterministic historical extension; no live source/build or Git object needed. */
export function applyInventoryStageTimingExtension(input) {
  const seed = loadInventoryStageTimingEvidence(), cases = validateInventoryStageTimingEvidence(seed);
  const base = restoreCalibratedTimings(input), table = JSON.parse(base);
  for (const [name, elapsed] of Object.entries(cases)) {
    if (Object.hasOwn(table.cases[FILE], name)) throw Error('Stage estimate already exists in base');
    table.cases[FILE][name] = elapsed;
  }
  table.timingExtensions = [extensionMetadata(seed)];
  const output = encode(table);
  if (!restoreCalibratedTimings(output).equals(base)) throw Error('Extension changed original calibration');
  return output;
}

function main(args) {
  const path = resolve(HERE, 'timings.json'), bytes = readFileSync(path);
  if (args.length === 2 && args[0] === '--extract-base') {
    const output = resolve(args[1]);
    if (output === path) throw Error('Base extraction must not overwrite the extended seed');
    writeFileSync(output, restoreCalibratedTimings(bytes));
    console.log('Original timing calibration SHA256 ' + BASE_SHA); return;
  }
  if (args.length !== 1 || !['--check', '--write'].includes(args[0])) throw Error('Usage: timing-extension.mjs --check | --write | --extract-base PATH');
  validateInventoryStageTimingEvidence(loadInventoryStageTimingEvidence(), readInput);
  const extended = applyInventoryStageTimingExtension(bytes);
  if (args[0] === '--write') writeFileSync(path, extended);
  else if (!extended.equals(bytes)) throw Error('Timing extension is absent or differs; use --write');
  console.log(JSON.stringify({ stages: 17, baseSha256: BASE_SHA, extendedSha256: hash(extended), evidenceSha256: SEED_SHA, applicabilityInputs: 52 }));
}
if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try { main(process.argv.slice(2)); } catch (error) { console.error(error.stack); process.exitCode = 1; }
}
