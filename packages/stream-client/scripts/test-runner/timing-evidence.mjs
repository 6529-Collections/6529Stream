// Offline scheduling evidence only. This neither runs tests nor changes runner policy.
import { createHash } from 'node:crypto';
import { readFileSync, writeFileSync, existsSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { partition, validatePlan, verifyUnit } from '../test-runner.mjs';

const hash = value => createHash('sha256').update(value).digest('hex');
const canonical = JSON.stringify;
const readJSON = path => JSON.parse(readFileSync(path, 'utf8'));
const writeJSON = (path, value) => writeFileSync(path, JSON.stringify(value, null, 2) + '\n', 'utf8');
const reportRows = path => readFileSync(path, 'utf8').split(/\r?\n/).filter(Boolean).map(line => JSON.parse(line));
function duration(value) {
  if (!Number.isFinite(value) || value <= 0 || value > 540000) throw Error('Invalid completed duration');
  return Math.ceil(value);
}
function assertRow(plan, unit, row) {
  if (!unit || row.unitId !== unit.id || row.file !== unit.file || canonical(row.names) !== canonical(unit.names) || row.error) throw Error('Substituted or failed timing unit');
  verifyUnit(plan, unit, row.report, row);
  duration(row.elapsedMs);
}

export function completeShardTimings(plan, result) {
  validatePlan(plan);
  if (result.version !== 1 || result.success !== true || result.inputError || result.planHash !== hash(canonical(plan)) || result.inputHash !== plan.inputHash || result.sourceCommit !== plan.sourceCommit || result.shards !== plan.shards) throw Error('Stale or unsuccessful shard evidence');
  const units = plan.units.filter(unit => unit.shard === result.shard), seen = new Set();
  if (!units.length || result.results.length !== units.length) throw Error('Incomplete shard evidence');
  return result.results.map(row => {
    const unit = units.find(unit => unit.id === row.unitId);
    assertRow(plan, unit, row);
    if (seen.has(unit.id)) throw Error('Duplicate timing unit');
    seen.add(unit.id);
    return { unitId: unit.id, elapsedMs: duration(row.elapsedMs), kind: 'complete-shard' };
  });
}

// PASS lines are emitted only after the runner verifies the child and reporter.
// Cancelled in-flight units retain lower bounds; they never become completions here.
export function partialShardTimings(plan, shard, log, readReport) {
  validatePlan(plan);
  if (!plan.sourceCommit || !log.split(/\r?\n/).some(line => line.trimEnd().endsWith(' ' + plan.sourceCommit))) throw Error('Partial checkout source differs');
  const units = plan.units.filter(unit => unit.shard === shard), starts = new Map(), passes = new Map();
  let cancelledAt = null;
  for (const line of log.split(/\r?\n/)) {
    const stamp = line.match(/(\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d+Z) (.*)$/);
    if (!stamp) continue;
    const at = Date.parse(stamp[1]), message = stamp[2];
    const start = message.match(/^START shard (\d+)\/(\d+) (test\/[^:]+): (.*)$/);
    if (start) {
      if (Number(start[1]) !== shard || Number(start[2]) !== plan.shards) throw Error('Wrong partial shard');
      const matches = units.filter(unit => unit.file === start[3] && (unit.names?.join(' | ') ?? 'complete file') === start[4]);
      if (matches.length !== 1 || starts.has(matches[0].id)) throw Error('Unknown or duplicate partial start');
      starts.set(matches[0].id, at);
    }
    const pass = message.match(/^PASS ([a-f0-9]{24}) (\d+)ms \((\d+) cases\)$/);
    if (pass) {
      const unit = units.find(unit => unit.id === pass[1]);
      if (!unit || !starts.has(unit.id) || passes.has(unit.id) || at < starts.get(unit.id)) throw Error('Unknown or duplicate partial completion');
      const report = readReport(unit.id);
      const row = { unitId: unit.id, file: unit.file, names: unit.names, elapsedMs: Number(pass[2]), report, exitCode: 0, timedOut: false, spawnError: null };
      assertRow(plan, unit, row);
      if (report.filter(value => value.nesting === 0).length !== Number(pass[3])) throw Error('Partial case count differs');
      passes.set(unit.id, { unitId: unit.id, elapsedMs: duration(row.elapsedMs), kind: 'partial-shard-pass' });
    }
    if (/^FAIL [a-f0-9]{24} /.test(message)) throw Error('Failed unit in partial evidence');
    if (message.includes('The operation was canceled.')) cancelledAt = at;
  }
  if (cancelledAt === null || !units.length || starts.size !== units.length) throw Error('Missing partial cancellation or starts');
  const incomplete = units.filter(unit => !passes.has(unit.id)).map(unit => {
    if (cancelledAt < starts.get(unit.id)) throw Error('Invalid cancellation timestamp');
    return { unitId: unit.id, startedAt: new Date(starts.get(unit.id)).toISOString(), observedLowerBoundMs: cancelledAt - starts.get(unit.id) };
  });
  if (!incomplete.length) throw Error('Partial shard has no interrupted unit');
  return { measurements: [...passes.values()], incomplete };
}

export function timingTable(plan, measurements) {
  validatePlan(plan);
  const byId = new Map(), files = Object.create(null), cases = Object.create(null);
  for (const row of measurements) {
    if (!plan.units.some(unit => unit.id === row.unitId) || byId.has(row.unitId)) throw Error('Unknown or duplicate measured unit');
    byId.set(row.unitId, duration(row.elapsedMs));
  }
  if (byId.size !== plan.units.length) throw Error('Every planned unit needs a completed measurement');
  for (const unit of [...plan.units].sort((a, b) => a.file.localeCompare(b.file) || canonical(a.names).localeCompare(canonical(b.names)))) {
    if (unit.names === null) files[unit.file] = byId.get(unit.id);
    else {
      if (unit.names.length !== 1) throw Error('Grouped unit cannot be represented by the existing timing table');
      (cases[unit.file] ??= Object.create(null))[unit.names[0]] = byId.get(unit.id);
    }
  }
  return { files, cases };
}

export function schedulingModel(plan, measurements, timings, concurrency = 2) {
  const table = timingTable(plan, measurements); // Assert complete, non-overlapping evidence first.
  if (!Number.isSafeInteger(concurrency) || concurrency < 1 || concurrency > 16) throw Error('Invalid model concurrency');
  const measured = new Map(measurements.map(row => [row.unitId, row.elapsedMs]));
  const next = { ...plan, ...partition(plan.inventory, plan.shards, timings ?? table) };
  validatePlan(next);
  if (canonical(plan.units.map(unit => unit.id).sort()) !== canonical(next.units.map(unit => unit.id).sort())) throw Error('Repartition changed test inventory');
  function replay(units) {
    return Array.from({ length: plan.shards }, (_, index) => {
      const lanes = Array(concurrency).fill(0), starts = [];
      for (const unit of units.filter(value => value.shard === index + 1)) {
        const lane = lanes.indexOf(Math.min(...lanes));
        starts.push({ unitId: unit.id, startMs: lanes[lane] });
        lanes[lane] += measured.get(unit.id);
      }
      return { shard: index + 1, elapsedMs: Math.ceil(Math.max(...lanes)), starts };
    });
  }
  return { qualification: 'Replay of measured child durations; excludes setup/upload and is not a CI duration guarantee. Local supplements retain their separate platform identity.', concurrency, units: next.units.length,
    files: plan.inventory.length, registrations: plan.inventory.reduce((sum, item) => sum + item.registrations.length, 0), before: replay(plan.units), after: replay(next.units) };
}

export function importTimingEvidence({ planPath, resultDirectory, partialLogs = new Map(), supplementPaths = [] }) {
  const plan = validatePlan(readJSON(planPath)), measurements = [], incomplete = [], evidence = [];
  for (const shard of partialLogs.keys()) if (!Number.isInteger(shard) || shard < 1 || shard > plan.shards) throw Error('Unknown partial shard');
  const retain = path => evidence.push({ path: resolve(path), sha256: hash(readFileSync(path)) });
  retain(planPath);
  for (let shard = 1; shard <= plan.shards; shard++) {
    const directory = join(resultDirectory, `stream-client-results-${shard}`), resultPath = join(directory, `shard-${shard}.json`), logs = join(directory, `shard-${shard}`);
    const readReport = id => { const path = join(logs, id + '.jsonl'); retain(path); return reportRows(path); };
    if (existsSync(resultPath)) {
      if (partialLogs.has(shard)) throw Error('Both complete and partial evidence supplied');
      retain(resultPath);
      const result = readJSON(resultPath);
      if (result.shard !== shard) throw Error('Misplaced shard evidence');
      const rows = completeShardTimings(plan, result);
      for (const row of result.results) {
        const path = join(logs, row.unitId + '.tap'); retain(path);
        if (row.log !== row.unitId + '.tap' || hash(readFileSync(path)) !== row.logSha256 || canonical(readReport(row.unitId)) !== canonical(row.report)) throw Error('Retained reporter or TAP differs');
      }
      measurements.push(...rows);
    } else {
      const path = partialLogs.get(shard);
      if (!path) throw Error('Missing shard evidence');
      retain(path);
      const partial = partialShardTimings(plan, shard, readFileSync(path, 'utf8'), readReport);
      for (const row of partial.measurements) {
        const tap = join(logs, row.unitId + '.tap'); retain(tap);
        if (!/^# fail 0\s*$/m.test(readFileSync(tap, 'utf8'))) throw Error('Partial TAP lacks successful completion');
      }
      measurements.push(...partial.measurements); incomplete.push(...partial.incomplete);
    }
  }
  if (incomplete.length) {
    if (!supplementPaths.length) throw Error('Interrupted units require separate completed measurements');
    for (const supplementPath of supplementPaths) {
      retain(supplementPath);
      const supplement = readJSON(supplementPath), inputs = new Map(plan.inputs.map(value => [value.file, value.sha256]));
      if (supplement.remoteSourceCommit !== plan.sourceCommit || supplement.inputsUnchanged !== true || !supplement.dependencyInputs?.length || canonical(supplement.dependencyInputs) !== canonical(supplement.after) || supplement.remoteDependencyMismatches?.length || supplement.dependenciesAbsentFromRemote?.length) throw Error('Unverified supplemental dependencies');
      const seen = new Set();
      for (const input of supplement.dependencyInputs) {
        if (seen.has(input.file) || inputs.get(input.file) !== input.sha256) throw Error('Supplement input differs from remote plan');
        seen.add(input.file);
      }
      if (!supplement.results.length) throw Error('Empty supplemental evidence');
      for (const row of supplement.results) {
        if (!incomplete.some(value => value.unitId === row.unitId)) throw Error('Supplement replaced completed remote measurement');
        assertRow(plan, plan.units.find(unit => unit.id === row.unitId), row);
        const tap = join(dirname(supplementPath), row.unitId + '.tap'), report = join(dirname(supplementPath), row.unitId + '.jsonl');
        retain(tap); retain(report);
        if (hash(readFileSync(tap)) !== row.logSha256 || canonical(reportRows(report)) !== canonical(row.report)) throw Error('Supplement reporter or TAP differs');
        measurements.push({ unitId: row.unitId, elapsedMs: duration(row.elapsedMs), kind: 'isolated-supplement', platform: supplement.platform, node: supplement.node, sourceCommit: supplement.localSourceCommit });
      }
    }
  } else if (supplementPaths.length) throw Error('Unneeded supplemental measurements');
  const table = timingTable(plan, measurements);
  return { plan, table, measurements, incomplete, evidence };
}

async function main(args) {
  const options = {}, partialLogs = new Map(), supplementPaths = [];
  for (let index = 0; index < args.length; index += 2) {
    const key = args[index], value = args[index + 1];
    if (!value || !['--plan', '--results', '--partial', '--supplement', '--output', '--evidence', '--run'].includes(key)) throw Error('Expected known --option value pairs');
    if (key === '--partial') {
      const match = value.match(/^(\d+)=(.+)$/);
      if (!match || partialLogs.has(Number(match[1]))) throw Error('Use unique --partial SHARD=LOG');
      partialLogs.set(Number(match[1]), match[2]);
    } else if (key === '--supplement') supplementPaths.push(value);
    else {
      if (Object.hasOwn(options, key)) throw Error('Duplicate option');
      options[key] = value;
    }
  }
  for (const key of ['--plan', '--results', '--output', '--evidence', '--run']) if (!options[key]) throw Error(`Missing ${key}`);
  const data = importTimingEvidence({ planPath: options['--plan'], resultDirectory: options['--results'], partialLogs, supplementPaths });
  const timings = {
    description: 'Scheduling estimates only, rounded up from verified completed child elapsed times. Remote CI measurements and separately identified Windows isolated supplements are observations, not runtime guarantees. Unmeasured new units retain the runner heuristics.',
    evidence: { run: options['--run'], sourceCommit: data.plan.sourceCommit, planSha256: hash(readFileSync(options['--plan'])), nodeMajor: data.plan.nodeMajor, completeShardUnits: data.measurements.filter(row => row.kind === 'complete-shard').length, partialShardUnits: data.measurements.filter(row => row.kind === 'partial-shard-pass').length,
      isolatedSupplements: data.measurements.filter(row => row.kind === 'isolated-supplement'), units: data.measurements.length }, ...data.table
  };
  const model = schedulingModel(data.plan, data.measurements, timings);
  writeJSON(options['--output'], timings);
  writeJSON(options['--evidence'], { ...data, plan: { sourceCommit: data.plan.sourceCommit, inputHash: data.plan.inputHash, planSha256: hash(readFileSync(options['--plan'])) }, table: undefined, model, timingsSha256: hash(readFileSync(options['--output'])) });
  console.log(JSON.stringify({ units: model.units, files: model.files, registrations: model.registrations, incompleteRemoteUnits: data.incomplete.length, beforeMaxMs: Math.max(...model.before.map(row => row.elapsedMs)), afterMaxMs: Math.max(...model.after.map(row => row.elapsedMs)) }));
}
if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) main(process.argv.slice(2)).catch(error => { console.error(error.stack); process.exitCode = 1; });
