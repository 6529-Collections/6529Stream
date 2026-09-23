import test from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { partition } from '../scripts/test-runner.mjs';
import { loadInventoryStageTimingEvidence, validateInventoryStageTimingEvidence, restoreCalibratedTimings, applyInventoryStageTimingExtension } from '../scripts/test-runner/timing-extension.mjs';

const hash = value => createHash('sha256').update(value).digest('hex');
const encode = value => Buffer.from(JSON.stringify(value, null, 2) + '\n');
const BASE_SHA = 'e8c138a6b1565c15d0560d7ab8a4e13342d6861a0ace335883d4e06b45058c93';
const file = 'test/current-scoped-policy-inventory-v2-workflow.test.mjs';
const registration = name => ({ name, kind: 'test', skip: false, todo: false, only: false });
const current = () => readFileSync(new URL('../scripts/test-runner/timings.json', import.meta.url));
const base = () => restoreCalibratedTimings(current());
const seed = () => loadInventoryStageTimingEvidence();

// Ordinary regressions read sealed evidence only. They do not require current
// production/dist bytes or the historical local sourceCommit to still exist.
test('stage timing evidence authenticates all 17 successful reports and the unchanged 51 lifecycle assertions', () => {
  const evidence = seed(), values = validateInventoryStageTimingEvidence(evidence);
  assert.equal(evidence.platform, 'win32');
  assert.equal(evidence.node, 'v24.16.0');
  assert.equal(evidence.timeoutMs, 420000);
  assert.equal(evidence.matrix.length, 51);
  assert.equal(new Set(evidence.matrix.map(row => `${row.method}/${row.mode}`)).size, 51);
  assert.equal(evidence.otherBodies.length, 15);
  assert.equal(Object.keys(values).length, 17);
  assert.deepEqual(Object.values(values), evidence.results.map(row => Math.ceil(row.elapsedMs)));
  assert.equal(Math.max(...Object.values(values)), 49208);
  assert.equal(evidence.beforeInputs.length, 52);
});

test('additive extension restores byte-exact original calibration and applies idempotently without private artifacts', () => {
  const original = base(), extended = applyInventoryStageTimingExtension(original);
  assert.equal(hash(original), BASE_SHA);
  assert.equal(original.length, 147730);
  assert.deepEqual(restoreCalibratedTimings(extended), original);
  assert.deepEqual(applyInventoryStageTimingExtension(extended), extended);
  assert.deepEqual(current(), extended);
  const before = JSON.parse(original), after = JSON.parse(extended), evidence = seed();
  assert.deepEqual(after.evidence, before.evidence);
  assert.deepEqual(after.files, before.files);
  for (const [path, entries] of Object.entries(before.cases)) {
    for (const [name, duration] of Object.entries(entries)) assert.equal(after.cases[path][name], duration);
  }
  assert.equal(after.cases[file][after.timingExtensions[0].retiredRegistration.name], 361929);
  assert.equal(after.timingExtensions[0].addedUnits, 17);
  assert.equal(after.timingExtensions[0].evidenceSha256, hash(readFileSync(new URL('../scripts/test-runner/inventory-stage-timing-extension.json', import.meta.url))));
  assert.equal(after.timingExtensions[0].sourceCommit, evidence.sourceCommit);
  assert.match(after.timingExtensions[0].qualification, /Windows.*not Linux CI guarantees/);
});

test('old 1417 scheduling units retain identical weights and partition; new stage registrations use measured weights exactly once', () => {
  const original = JSON.parse(base()), extended = JSON.parse(applyInventoryStageTimingExtension(base()));
  // The base table retains the exact unit keys. A whole-file placeholder is
  // enough for scheduling; this does not reconstruct its internal assertions.
  const inventory = [
    ...Object.keys(original.files).map(path => ({ file: path, wholeFile: true, registrations: [registration('whole file')] })),
    ...Object.entries(original.cases).map(([path, entries]) => ({ file: path, wholeFile: false, registrations: Object.keys(entries).map(registration) })),
  ];
  const before = partition(inventory, 16, original), after = partition(inventory, 16, extended);
  assert.equal(before.units.length, 1417);
  assert.deepEqual(after, before);
  const evidence = seed(), changed = inventory.map(row => row.file === file ? { ...row, registrations: evidence.discovery.registrations } : row);
  const planned = partition(changed, 16, extended), selected = planned.units.filter(row => row.file === file);
  assert.equal(planned.units.length, 1433);
  assert.equal(selected.length, 32);
  for (const result of evidence.results) {
    const matches = selected.filter(row => row.id === result.unitId);
    assert.equal(matches.length, 1);
    assert.equal(matches[0].estimateMs, Math.ceil(result.elapsedMs));
  }
  assert.equal(selected.some(row => row.names.includes(extended.timingExtensions[0].retiredRegistration.name)), false);
});

test('stage extension refuses incomplete, duplicate, substituted, failed, skipped and out-of-bound observations', () => {
  for (const mutate of [
    value => { value.results.pop(); },
    value => { value.results[1] = value.results[0]; },
    value => { value.results[0].names = ['other stage']; },
    value => { value.results[0].exitCode = 1; },
    value => { value.results[0].timedOut = true; },
    value => { value.results[0].spawnError = 'interrupted'; },
    value => { value.results[0].report[0].status = 'fail'; },
    value => { value.results[0].report[0].skip = true; },
    value => { value.results[0].report[0].todo = true; },
    value => { value.results[0].elapsedMs = 420001; },
    value => { value.results[0].elapsedMs = NaN; },
    value => { value.results[0].report[0].durationMs = value.results[0].elapsedMs + 1; },
  ]) {
    const evidence = seed(); mutate(evidence);
    assert.throws(() => validateInventoryStageTimingEvidence(evidence));
  }
});

test('raw TAP and reporter hashes plus exact outcomes reject internally rehashed unsuccessful or extra results', () => {
  let evidence = seed(); evidence.results[0].tap += '\n';
  assert.throws(() => validateInventoryStageTimingEvidence(evidence), /reporter bytes/);
  for (const mutate of [
    row => { row.tap = row.tap.replace('# pass 1', '# pass 0'); },
    row => { row.tap += 'ok 2 - unselected stage\n'; },
    row => { row.tap += 'not ok 2 - failed stage\n'; },
    row => { row.jsonl = row.jsonl.replace('"status":"pass"', '"status":"fail"'); },
  ]) {
    evidence = seed(); const row = evidence.results[0]; mutate(row);
    row.tapSha256 = hash(row.tap); row.jsonlSha256 = hash(row.jsonl);
    assert.throws(() => validateInventoryStageTimingEvidence(evidence), /TAP|reporter/);
  }
});

test('source parity, full stage matrix and dependency snapshot consistency remain explicit evidence requirements', () => {
  for (const mutate of [
    value => { value.matrix.pop(); },
    value => { value.discovery.registrations[0].skip = true; },
    value => { value.discovery.registrations[20].name += ' changed'; },
    value => { value.otherBodies[0].sha256 = '0'.repeat(64); },
    value => { value.testSource = value.testSource.replace('captureScopedPolicyInventoryV2', 'changedCapture'); },
    value => { value.afterInputs[0].sha256 = '0'.repeat(64); },
    value => { value.beforeInputs[0] = value.beforeInputs[1]; value.afterInputs = structuredClone(value.beforeInputs); },
  ]) {
    const evidence = seed(); mutate(evidence);
    assert.throws(() => validateInventoryStageTimingEvidence(evidence));
  }
});

test('explicit applicability reader rejects changed or missing bytes without coupling ordinary regressions to live production', () => {
  const evidence = seed(), inputs = new Map();
  // A synthetic dependency inventory for this isolated consistency test. The
  // historical sealed loader/application still accepts only the pinned JSON.
  for (const input of evidence.beforeInputs) {
    const bytes = Buffer.from(input.file === file ? evidence.testSource : `synthetic ${input.file}\n`);
    inputs.set(input.file, bytes); input.sha256 = hash(bytes);
  }
  evidence.afterInputs = structuredClone(evidence.beforeInputs);
  const reader = path => { if (!inputs.has(path)) throw Error('Missing input: ' + path); return inputs.get(path); };
  assert.equal(Object.keys(validateInventoryStageTimingEvidence(evidence, reader)).length, 17);
  const selected = evidence.beforeInputs.find(row => row.file !== file).file;
  inputs.set(selected, Buffer.from('changed'));
  assert.throws(() => validateInventoryStageTimingEvidence(evidence, reader), /inapplicable/);
  inputs.delete(selected);
  assert.throws(() => validateInventoryStageTimingEvidence(evidence, reader), /Missing input/);
  assert.equal(Object.keys(validateInventoryStageTimingEvidence(evidence)).length, 17);
});

test('base and extended table tampering cannot silently replace calibration or stage provenance', () => {
  const original = base(), extended = applyInventoryStageTimingExtension(original);
  const changedBase = JSON.parse(original); changedBase.files[Object.keys(changedBase.files)[0]]++;
  assert.throws(() => applyInventoryStageTimingExtension(encode(changedBase)), /Unknown|calibration/);
  for (const mutate of [
    value => { value.files[Object.keys(value.files)[0]]++; },
    value => { value.cases[file][seed().results[0].names[0]]++; },
    value => { delete value.cases[file][seed().results[0].names[0]]; },
    value => { value.timingExtensions[0].platform = 'linux'; },
    value => { value.timingExtensions.push(value.timingExtensions[0]); },
  ]) {
    const table = JSON.parse(extended); mutate(table);
    assert.throws(() => restoreCalibratedTimings(encode(table)));
  }
  assert.throws(() => restoreCalibratedTimings(Buffer.concat([extended, Buffer.from('\n')])), /Unknown/);
});
