import test from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, dirname, resolve } from 'node:path';
import { partition, validatePlan } from '../scripts/test-runner.mjs';
import { completeShardTimings, partialShardTimings, timingTable, schedulingModel, importTimingEvidence } from '../scripts/test-runner/timing-evidence.mjs';

const hash = value => createHash('sha256').update(value).digest('hex');
const registration = name => ({ name, kind: 'test', skip: false, todo: false, only: false });
function fixture() {
  const inventory = [
    { file: 'test/first.test.mjs', wholeFile: true, registrations: [registration('a'), registration('b')] },
    { file: 'test/second-workflow.test.mjs', wholeFile: false, registrations: [registration('slow (complete) [case]'), registration('fast')] },
  ];
  const plan = validatePlan({ version: 1, sourceCommit: 'a'.repeat(40), nodeMajor: 24, shards: 2, inputs: [], inputHash: hash('[]'), inventory, ...partition(inventory, 2) });
  const rows = plan.units.map(unit => ({ unitId: unit.id, file: unit.file, names: unit.names, exitCode: 0, timedOut: false, spawnError: null, elapsedMs: unit.names?.[0].startsWith('slow') ? 310000.1 : 5000.1, error: null,
    report: inventory.find(item => item.file === unit.file).registrations.filter(item => unit.names === null || unit.names.includes(item.name)).map(item => ({ name: item.name, nesting: 0, status: 'pass', skip: false, todo: false, durationMs: 1, error: null })) }));
  return { plan, rows };
}
function shardResult(plan, rows, shard) {
  return { version: 1, planHash: hash(JSON.stringify(plan)), inputHash: plan.inputHash, sourceCommit: plan.sourceCommit, shards: plan.shards, shard, success: true, inputError: null,
    results: rows.filter(row => plan.units.find(unit => unit.id === row.unitId).shard === shard) };
}
function partialLog(plan, shard, completed) {
  return ['2026-09-22T00:00:00.000Z ' + plan.sourceCommit,
    ...plan.units.filter(unit => unit.shard === shard).flatMap(unit => [
      `2026-09-22T00:00:01.000Z START shard ${shard}/${plan.shards} ${unit.file}: ${unit.names?.join(' | ') ?? 'complete file'}`,
      ...(completed.some(row => row.unitId === unit.id) ? [`2026-09-22T00:00:06.000Z PASS ${unit.id} 5000ms (1 cases)`] : []),
    ]), '2026-09-22T00:04:00.000Z ##[error]The operation was canceled.'].join('\n');
}

test('timing evidence retains completed elapsed time and rejects stale substituted failed or duplicate results', () => {
  const { plan, rows } = fixture(), result = shardResult(plan, rows, 1);
  assert.equal(completeShardTimings(plan, result)[0].elapsedMs, 5001);
  for (const mutate of [r => { r.sourceCommit = 'b'.repeat(40); }, r => { r.planHash = '0'.repeat(64); }, r => { r.success = false; }, r => { r.results[0].names = ['substituted']; }, r => { r.results[0].timedOut = true; }, r => { r.results[0].report[0].skip = true; }, r => { r.results[0].report[0].status = 'fail'; }, r => { r.results[0].elapsedMs = NaN; }]) {
    const copy = structuredClone(result); mutate(copy); assert.throws(() => completeShardTimings(plan, copy));
  }
  const other = shardResult(plan, rows, 2); other.results[1] = other.results[0];
  assert.throws(() => completeShardTimings(plan, other), /Duplicate/);
});

test('partial runner PASS plus exact reporter inventory is measured; cancellation remains only a lower bound', () => {
  const { plan, rows } = fixture(), completed = rows.filter(row => row.names?.[0] === 'fast'), log = partialLog(plan, 2, completed);
  const value = partialShardTimings(plan, 2, log, id => rows.find(row => row.unitId === id).report);
  assert.equal(value.measurements.length, 1);
  assert.equal(value.measurements[0].elapsedMs, 5000);
  assert.equal(value.incomplete.length, 1);
  assert.equal(value.incomplete[0].observedLowerBoundMs, 239000);
  assert.equal(value.incomplete[0].elapsedMs, undefined);
  assert.throws(() => timingTable(plan, [...completeShardTimings(plan, shardResult(plan, rows, 1)), ...value.measurements]), /Every planned unit/);
});

test('partial evidence rejects wrong source, invented names, duplicates, missing starts and unsuccessful reporters', () => {
  const { plan, rows } = fixture(), completed = rows.filter(row => row.names?.[0] === 'fast'), log = partialLog(plan, 2, completed), reports = id => rows.find(row => row.unitId === id).report;
  for (const changed of [log.replace(plan.sourceCommit, 'b'.repeat(40)), log.replace('slow (complete)', 'invented'), log.replace(/.*START.*slow.*\n/, ''), log + '\n' + log.split('\n').find(line => line.includes(' PASS ')), log.replace('The operation was canceled.', 'finished')]) assert.throws(() => partialShardTimings(plan, 2, changed, reports));
  assert.throws(() => partialShardTimings(plan, 2, log, id => reports(id).map(row => ({ ...row, status: 'fail' }))), /failed test/);
});

test('full timing table and unchanged scheduler preserve every file and case while starting the longest case first', () => {
  const { plan, rows } = fixture(), measurements = rows.map(row => ({ unitId: row.unitId, elapsedMs: row.elapsedMs })), table = timingTable(plan, measurements), model = schedulingModel(plan, measurements, table);
  assert.equal(Object.keys(table.files).length, 1);
  assert.equal(Object.keys(table.cases['test/second-workflow.test.mjs']).length, 2);
  assert.equal(table.cases['test/second-workflow.test.mjs']['slow (complete) [case]'], 310001);
  assert.deepEqual([model.files, model.registrations, model.units], [2, 4, 3]);
  const slow = rows.find(row => row.names?.[0].startsWith('slow')).unitId;
  assert.equal(model.after.flatMap(shard => shard.starts).find(row => row.unitId === slow).startMs, 0);
  assert.throws(() => timingTable(plan, [...measurements, measurements[0]]), /duplicate/);
  assert.throws(() => timingTable(plan, measurements.map(row => ({ ...row, elapsedMs: 540001 }))), /duration/);
});

test('literal test names are data, including object-prototype property names', () => {
  const { plan } = fixture();
  plan.inventory[1].registrations = [registration('__proto__'), registration('constructor')];
  Object.assign(plan, partition(plan.inventory, 2));
  const timings = timingTable(plan, plan.units.map(unit => ({ unitId: unit.id, elapsedMs: 5000 })));
  const names = JSON.parse(JSON.stringify(timings)).cases['test/second-workflow.test.mjs'];
  assert.equal(Object.hasOwn(names, '__proto__'), true);
  assert.equal(names.__proto__, 5000);
  assert.equal(names.constructor, 5000);
});

test('offline importer authenticates TAP/report pairs and supplementary dependencies without upgrading interrupted CI units to passes', () => {
  const directory = mkdtempSync(join(tmpdir(), 'stream-timing-evidence-'));
  try {
    const { plan, rows } = fixture();
    plan.inputs = [{ file: 'test/second-workflow.test.mjs', sha256: 'c'.repeat(64) }]; plan.inputHash = hash(JSON.stringify(plan.inputs));
    const put = (path, value) => { mkdirSync(dirname(path), { recursive: true }); writeFileSync(path, typeof value === 'string' ? value : JSON.stringify(value)); };
    const planPath = join(directory, 'plan.json'), resultDirectory = join(directory, 'remote'), partialPath = join(directory, 'partial.log'), supplementPath = join(directory, 'local', 'result.json');
    put(planPath, plan);
    for (const row of rows) {
      const unit = plan.units.find(unit => unit.id === row.unitId), remote = join(resultDirectory, `stream-client-results-${unit.shard}`, `shard-${unit.shard}`), target = row.names?.[0].startsWith('slow') ? dirname(supplementPath) : remote;
      const tap = '# pass ' + row.report.length + '\n# fail 0\n';
      row.log = row.unitId + '.tap'; row.logSha256 = hash(tap);
      put(join(target, row.log), tap); put(join(target, row.unitId + '.jsonl'), row.report.map(value => JSON.stringify(value)).join('\n') + '\n');
    }
    put(join(resultDirectory, 'stream-client-results-1', 'shard-1.json'), shardResult(plan, rows, 1));
    put(partialPath, partialLog(plan, 2, rows.filter(row => row.names?.[0] === 'fast')));
    const supplement = { remoteSourceCommit: plan.sourceCommit, inputsUnchanged: true, dependencyInputs: plan.inputs, after: plan.inputs, remoteDependencyMismatches: [], dependenciesAbsentFromRemote: [], localSourceCommit: 'd'.repeat(40), node: 'v22.12.0', platform: 'win32', results: rows.filter(row => row.names?.[0].startsWith('slow')) };
    put(supplementPath, supplement);
    const args = { planPath, resultDirectory, partialLogs: new Map([[2, partialPath]]), supplementPaths: [supplementPath] };
    const imported = importTimingEvidence(args);
    assert.equal(imported.incomplete.length, 1);
    assert.deepEqual(imported.measurements.map(row => row.kind).sort(), ['complete-shard', 'isolated-supplement', 'partial-shard-pass']);
    assert.equal(imported.measurements.find(row => row.kind === 'isolated-supplement').platform, 'win32');
    const tap = join(dirname(supplementPath), supplement.results[0].log), original = readFileSync(tap);
    put(tap, '# fail 1\n'); assert.throws(() => importTimingEvidence(args), /TAP differs/); put(tap, original.toString());
    supplement.after = []; put(supplementPath, supplement); assert.throws(() => importTimingEvidence(args), /dependencies/);
  } finally {
    assert.equal(dirname(resolve(directory)), resolve(tmpdir()));
    assert.match(directory.split(/[\\/]/).at(-1), /^stream-timing-evidence-/);
    rmSync(directory, { recursive: true, force: true });
  }
});
