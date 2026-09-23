import { createHash } from 'node:crypto';
import { spawn, execFileSync } from 'node:child_process';
import { existsSync, lstatSync, mkdirSync, readdirSync, readFileSync, writeFileSync, openSync, closeSync, rmSync } from 'node:fs';
import { dirname, join, relative, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
export const PACKAGE_ROOT = resolve(HERE, '..');
const hash = value => createHash('sha256').update(value).digest('hex');
const slash = value => value.split(sep).join('/');
const canonical = value => JSON.stringify(value);
const readJSON = file => JSON.parse(readFileSync(file, 'utf8'));
const writeJSON = (file, value) => { mkdirSync(dirname(resolve(file)), { recursive: true }); writeFileSync(file, JSON.stringify(value, null, 2) + '\n', 'utf8'); };
const children = new Set();
function integer(value, min, max, label) {
  if (!Number.isSafeInteger(value) || value < min || value > max) throw Error(`Invalid ${label}`);
  return value;
}
function inside(root, file) {
  const result = resolve(root, file), rel = relative(root, result);
  if (!rel || rel.startsWith('..' + sep) || rel === '..' || rel.includes('\0')) throw Error('Path must stay inside the package');
  return result;
}
export function testFiles(root = PACKAGE_ROOT) {
  return readdirSync(join(root, 'test')).filter(name => name.endsWith('.test.mjs')).sort().map(name => 'test/' + name);
}
export function captureInputs(root = PACKAGE_ROOT) {
  const paths = [];
  function walk(file) {
    if (!existsSync(file)) return;
    const stat = lstatSync(file);
    if (stat.isSymbolicLink()) throw Error(`Symlink in test inputs: ${file}`);
    if (stat.isDirectory()) for (const name of readdirSync(file).sort()) walk(join(file, name));
    else paths.push(slash(relative(root, file)));
  }
  for (const entry of ['package.json', 'package-lock.json', 'tsconfig.json', 'tsconfig.test.json', 'src', 'dist', 'scripts', 'test', 'examples']) walk(join(root, entry));
  return paths.sort().map(file => ({ file, sha256: hash(readFileSync(join(root, file))) }));
}
function sourceCommit(root) {
  try { return execFileSync('git', ['-C', root, 'rev-parse', 'HEAD'], { encoding: 'utf8', windowsHide: true, stdio: ['ignore', 'pipe', 'ignore'] }).trim(); }
  catch { return null; }
}
async function pool(items, concurrency, action) {
  let next = 0;
  const result = Array(items.length);
  const workers = await Promise.allSettled(Array.from({ length: Math.min(concurrency, items.length) }, async () => {
    while (next < items.length) { const index = next++; result[index] = await action(items[index], index); }
  }));
  const failed = workers.find(row => row.status === 'rejected');
  if (failed) throw failed.reason;
  return result;
}
export async function boundedNode(args, { cwd, log, timeoutMs, env = process.env }) {
  integer(timeoutMs, 1, 540000, 'child timeout');
  mkdirSync(dirname(log), { recursive: true });
  const fd = openSync(log, 'w'), start = performance.now();
  let child, timedOut = false, spawnError = null;
  try {
    // A parent node --test process sets this internal variable. Each child here
    // owns its native reporters; it must not inherit the parent's IPC reporter.
    const childEnv = { ...env }; delete childEnv.NODE_TEST_CONTEXT;
    child = spawn(process.execPath, args, { cwd, env: childEnv, windowsHide: true, stdio: ['ignore', fd, fd] });
    children.add(child);
    const timer = setTimeout(() => { timedOut = true; child.kill('SIGKILL'); }, timeoutMs);
    const exitCode = await new Promise(done => {
      child.once('error', error => { spawnError = error.message; });
      child.once('close', done);
    });
    clearTimeout(timer);
    return { exitCode, timedOut, spawnError, elapsedMs: performance.now() - start };
  } finally { children.delete(child); closeSync(fd); }
}

export async function discover({ root = PACKAGE_ROOT, directory, concurrency = 4, timeoutMs = 60000, progress = console.log } = {}) {
  integer(concurrency, 1, 16, 'discovery concurrency'); integer(timeoutMs, 1, 120000, 'discovery timeout');
  if (!directory) throw Error('Discovery output directory required');
  const files = testFiles(root);
  if (!files.length) throw Error('No test files found');
  return pool(files, concurrency, async (file, index) => {
    const output = resolve(directory, `discovery-${index}.json`), log = resolve(directory, `discovery-${index}.log`);
    rmSync(output, { force: true });
    const result = await boundedNode([join(HERE, 'test-runner/discover.mjs'), inside(root, file), output], { cwd: root, log, timeoutMs });
    if (result.exitCode !== 0 || result.timedOut || !existsSync(output)) throw Error(`Discovery failed for ${file}; see ${log}`);
    const data = readJSON(output);
    if (!Array.isArray(data.registrations) || !data.registrations.length) throw Error(`Empty discovery for ${file}`);
    progress(`DISCOVER ${index + 1}/${files.length} ${file}: ${data.registrations.length} registrations (${Math.round(result.elapsedMs)}ms)`);
    return { file, registrations: data.registrations, wholeFile: data.wholeFile || !file.endsWith('-workflow.test.mjs') };
  });
}

// Estimates only select where work runs. They never determine whether it passed.
function estimate(file, names, timings) {
  if (names.length === 1 && timings.cases?.[file]?.[names[0]]) return timings.cases[file][names[0]];
  if (timings.files?.[file]) return timings.files[file];
  if (file.endsWith('-workflow.test.mjs')) return /hydration/.test(file) ? 30000 : 2000;
  return /oracle/.test(file) ? 10000 : /hydration/.test(file) ? 45000 : 8000;
}
export function partition(inventory, shards, timings = {}) {
  integer(shards, 1, 64, 'shard count');
  for (const duration of [...Object.values(timings.files ?? {}), ...Object.values(timings.cases ?? {}).flatMap(Object.values)]) {
    if (!Number.isFinite(duration) || duration <= 0 || duration > 540000) throw Error('Invalid timing estimate');
  }
  const pending = [];
  for (const item of inventory) {
    const names = item.registrations.map(row => row.name);
    if (item.wholeFile) pending.push({ file: item.file, names: null, estimateMs: estimate(item.file, names, timings) });
    else for (const name of [...new Set(names)]) pending.push({ file: item.file, names: [name], estimateMs: estimate(item.file, [name], timings) });
  }
  if (pending.length < shards) throw Error('More shards than available work');
  pending.sort((a, b) => b.estimateMs - a.estimateMs || a.file.localeCompare(b.file) || canonical(a.names).localeCompare(canonical(b.names)));
  const loads = Array(shards).fill(0), units = [];
  for (const item of pending) {
    const shard = loads.indexOf(Math.min(...loads)) + 1;
    loads[shard - 1] += item.estimateMs;
    units.push({ ...item, shard, id: hash(canonical([item.file, item.names])).slice(0, 24) });
  }
  return { units, estimatesMs: loads };
}
export function validatePlan(plan) {
  if (!plan || plan.version !== 1 || !Array.isArray(plan.inventory) || !plan.inventory.length || !Array.isArray(plan.units) || !Array.isArray(plan.inputs)) throw Error('Invalid test plan');
  integer(plan.shards, 1, 64, 'plan shard count');
  integer(plan.nodeMajor, 22, 99, 'Node major');
  if (plan.sourceCommit !== null && !/^[a-f0-9]{40}$/.test(plan.sourceCommit)) throw Error('Invalid source commit');
  const inputs = new Set();
  for (const input of plan.inputs) {
    if (!input || typeof input.file !== 'string' || !/^[\w./-]+$/.test(input.file) || input.file.startsWith('/') || input.file.split('/').includes('..') || inputs.has(input.file) || !/^[a-f0-9]{64}$/.test(input.sha256)) throw Error('Invalid or duplicate input');
    inputs.add(input.file);
  }
  if (plan.inputHash !== hash(canonical(plan.inputs))) throw Error('Test input inventory hash differs');
  const files = new Set(), ids = new Set(), shards = new Set();
  for (const item of plan.inventory) {
    if (!item || !/^test\/[^/\\]+\.test\.mjs$/.test(item.file) || files.has(item.file) || typeof item.wholeFile !== 'boolean') throw Error('Duplicate or invalid planned test file');
    files.add(item.file);
    if (!Array.isArray(item.registrations) || !item.registrations.length) throw Error('Missing test registrations');
    for (const row of item.registrations) if (!row || typeof row.name !== 'string' || !row.name || /[\r\n\0]/.test(row.name) || !['test', 'suite'].includes(row.kind) || ['skip', 'todo', 'only'].some(key => typeof row[key] !== 'boolean')) throw Error('Invalid test registration');
    const selected = [];
    for (const unit of plan.units.filter(row => row.file === item.file)) {
      integer(unit.shard, 1, plan.shards, 'unit shard'); shards.add(unit.shard);
      if (ids.has(unit.id) || unit.id !== hash(canonical([unit.file, unit.names])).slice(0, 24)) throw Error('Duplicate or substituted unit');
      ids.add(unit.id);
      if (item.wholeFile ? unit.names !== null : !Array.isArray(unit.names)) throw Error('File execution mode differs');
      if (unit.names !== null && (new Set(unit.names).size !== unit.names.length || !unit.names.length || unit.names.some(name => !item.registrations.some(row => row.name === name)))) throw Error('Unknown or duplicate selected test');
      selected.push(...item.registrations.filter(row => unit.names === null || unit.names.includes(row.name)).map(row => row.name));
    }
    const expected = item.registrations.map(row => row.name).sort();
    if (canonical(selected.sort()) !== canonical(expected)) throw Error(`Incomplete or overlapping case partition: ${item.file}`);
  }
  if (plan.units.some(unit => !files.has(unit.file)) || shards.size !== plan.shards) throw Error('Unknown file or empty shard');
  return plan;
}
export async function createPlan({ root = PACKAGE_ROOT, output, directory, shards = 16, concurrency = 4, timings = {}, progress = console.log } = {}) {
  if (!output || !directory) throw Error('Plan and discovery output paths required');
  const before = captureInputs(root), commit = sourceCommit(root);
  const inventory = await discover({ root, directory, concurrency, progress });
  if (canonical(before) !== canonical(captureInputs(root)) || commit !== sourceCommit(root)) throw Error('Inputs changed during discovery');
  const distribution = partition(inventory, shards, timings);
  const plan = validatePlan({ version: 1, sourceCommit: commit, nodeMajor: Number(process.versions.node.split('.')[0]), shards, inputs: before,
    inputHash: hash(canonical(before)), inventory, ...distribution });
  writeJSON(output, plan);
  progress(`PLAN ${inventory.length} files, ${inventory.reduce((n, row) => n + row.registrations.length, 0)} top-level registrations, ${shards} shards`);
  return plan;
}
export function verifyInputs(plan, root = PACKAGE_ROOT) {
  validatePlan(plan);
  if (plan.nodeMajor !== Number(process.versions.node.split('.')[0])) throw Error('Plan and execution Node major differ');
  if (plan.sourceCommit !== sourceCommit(root)) throw Error('Plan and checkout commits differ');
  if (canonical(testFiles(root)) !== canonical(plan.inventory.map(row => row.file).sort())) throw Error('Test file set changed after planning');
  if (canonical(captureInputs(root)) !== canonical(plan.inputs)) throw Error('Test inputs changed after planning');
}
const escapePattern = name => name.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
function selectedRegistrations(plan, unit) {
  return plan.inventory.find(row => row.file === unit.file).registrations.filter(row => unit.names === null || unit.names.includes(row.name));
}
export function verifyUnit(plan, unit, report, processResult) {
  if (!Array.isArray(report) || report.some(row => !row || !['pass', 'fail'].includes(row.status) || typeof row.skip !== 'boolean' || typeof row.todo !== 'boolean' || !Number.isSafeInteger(row.nesting) || row.nesting < 0)) throw Error('Invalid test report');
  const expected = selectedRegistrations(plan, unit), actual = report.filter(row => row.nesting === 0);
  if (processResult.exitCode !== 0 || processResult.timedOut || processResult.spawnError) throw Error('Test child failed or exceeded its bound');
  if (canonical(actual.map(row => row.name).sort()) !== canonical(expected.map(row => row.name).sort())) throw Error('Executed test inventory differs from selected cases');
  const remaining = [...expected];
  for (const row of actual) {
    const index = remaining.findIndex(value => value.name === row.name); const registered = remaining.splice(index, 1)[0];
    if (row.skip !== registered.skip || row.todo !== registered.todo || row.status === 'fail' && !registered.todo) throw Error('Unexpected skipped, todo or failed test');
  }
}
export async function runShard({ root = PACKAGE_ROOT, plan, shard, output, directory, concurrency = 2, timeoutMs = 420000, progress = console.log } = {}) {
  integer(shard, 1, plan.shards, 'shard'); integer(concurrency, 1, 16, 'execution concurrency'); integer(timeoutMs, 1, 540000, 'test bound');
  if (!output || !directory) throw Error('Result and log output paths required');
  verifyInputs(plan, root);
  const planHash = hash(canonical(plan)), units = plan.units.filter(unit => unit.shard === shard), started = new Date().toISOString();
  const results = await pool(units, concurrency, async unit => {
    const log = resolve(directory, unit.id + '.tap'), reportFile = resolve(directory, unit.id + '.jsonl');
    for (const file of [log, reportFile]) rmSync(file, { force: true });
    const args = ['--test-reporter=tap', '--test-reporter-destination=' + log,
      '--test-reporter=' + new URL('./test-runner/reporter.mjs', import.meta.url).href, '--test-reporter-destination=' + reportFile];
    if (unit.names !== null) args.push('--test-name-pattern=^(?:' + unit.names.map(escapePattern).join('|') + ')$');
    args.push(unit.file);
    progress(`START shard ${shard}/${plan.shards} ${unit.file}: ${unit.names?.join(' | ') ?? 'complete file'}`);
    const child = await boundedNode(args, { cwd: root, log: resolve(directory, unit.id + '.process.log'), timeoutMs });
    let report = [], error = null;
    try {
      report = readFileSync(reportFile, 'utf8').split(/\r?\n/).filter(Boolean).map(line => JSON.parse(line));
      verifyUnit(plan, unit, report, child);
    } catch (cause) { error = String(cause.message || cause); }
    const result = { unitId: unit.id, file: unit.file, names: unit.names, ...child, report, error,
      log: slash(relative(directory, log)), logSha256: existsSync(log) ? hash(readFileSync(log)) : null };
    progress(`${error ? 'FAIL' : 'PASS'} ${unit.id} ${Math.round(child.elapsedMs)}ms (${report.filter(row => row.nesting === 0).length} cases)${error ? ': ' + error : ''}`);
    return result;
  });
  let inputError = null;
  try { verifyInputs(plan, root); } catch (error) { inputError = error.message; }
  const result = { version: 1, planHash, inputHash: plan.inputHash, sourceCommit: plan.sourceCommit, shard, shards: plan.shards, started, completed: new Date().toISOString(),
    inputError, success: !inputError && results.every(row => !row.error), results };
  writeJSON(output, result);
  return result;
}
export function verifyResults(plan, results) {
  validatePlan(plan);
  const planHash = hash(canonical(plan)), seen = new Set(), units = new Set();
  if (results.length !== plan.shards) throw Error('Every shard result is required');
  for (const result of results) {
    integer(result.shard, 1, plan.shards, 'result shard');
    if (result.version !== 1 || seen.has(result.shard) || result.success !== true || result.inputError || !Array.isArray(result.results) || result.planHash !== planHash || result.inputHash !== plan.inputHash || result.sourceCommit !== plan.sourceCommit || result.shards !== plan.shards) throw Error('Duplicate, stale or failed shard result');
    seen.add(result.shard);
    const expected = plan.units.filter(unit => unit.shard === result.shard);
    if (result.results.length !== expected.length) throw Error('Missing unit results');
    for (const row of result.results) {
      const unit = expected.find(unit => unit.id === row.unitId);
      if (!unit || units.has(row.unitId) || row.error || row.file !== unit.file || canonical(row.names) !== canonical(unit.names)) throw Error('Duplicate or substituted unit result');
      units.add(row.unitId); verifyUnit(plan, unit, row.report, row);
    }
  }
  return { files: plan.inventory.length, registrations: plan.inventory.reduce((n, row) => n + row.registrations.length, 0), shards: seen.size, units: units.size };
}

export function options(args, allowed) {
  const result = {};
  for (let i = 0; i < args.length; i += 2) {
    if (!args[i]?.startsWith('--') || !args[i + 1] || args[i + 1].startsWith('--') || Object.hasOwn(result, args[i].slice(2)) || !allowed.includes(args[i].slice(2))) throw Error('Expected known, unique --option value pairs');
    result[args[i].slice(2)] = args[i + 1];
  }
  return result;
}
async function main() {
  const [command, ...args] = process.argv.slice(2);
  const allowed = { plan: ['root', 'output', 'logs', 'shards', 'concurrency', 'timings'], run: ['root', 'plan', 'shard', 'output', 'logs', 'concurrency', 'timeout-ms'], verify: ['plan', 'results'] };
  if (!allowed[command]) throw Error('Usage: test-runner.mjs plan|run|verify [--option value]');
  const value = options(args, allowed[command]), root = value.root ? resolve(value.root) : PACKAGE_ROOT;
  if (command === 'plan') await createPlan({ root, output: resolve(value.output ?? '.test-runs/plan.json'), directory: resolve(value.logs ?? '.test-runs/discovery'),
    shards: Number(value.shards ?? 16), concurrency: Number(value.concurrency ?? 4), timings: readJSON(value.timings ?? join(HERE, 'test-runner/timings.json')) });
  else if (command === 'run') {
    if (!value.plan || !value.shard) throw Error('run requires --plan and --shard');
    const result = await runShard({ root, plan: readJSON(value.plan), shard: Number(value.shard), output: resolve(value.output ?? `.test-runs/shard-${value.shard}.json`),
      directory: resolve(value.logs ?? `.test-runs/shard-${value.shard}`), concurrency: Number(value.concurrency ?? 2), timeoutMs: Number(value['timeout-ms'] ?? 420000) });
    if (!result.success) process.exitCode = 1;
  } else if (command === 'verify') {
    if (!value.plan || !value.results) throw Error('verify requires --plan and --results DIRECTORY');
    const plan = readJSON(value.plan), results = readdirSync(value.results).filter(name => /^shard-\d+\.json$/.test(name)).map(name => readJSON(join(value.results, name)));
    verifyInputs(plan);
    console.log('COVERAGE ' + canonical(verifyResults(plan, results)));
  } else throw Error('Usage: test-runner.mjs plan|run|verify [--option value]');
}
if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  for (const signal of ['SIGINT', 'SIGTERM']) process.once(signal, () => {
    for (const child of children) child.kill('SIGKILL');
    process.exit(signal === 'SIGINT' ? 130 : 143);
  });
  main().catch(error => { console.error(error.stack || error); process.exitCode = 1; });
}
