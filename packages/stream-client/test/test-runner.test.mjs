import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, existsSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve, dirname, basename } from 'node:path';
import { boundedNode, createPlan, runShard, verifyInputs, verifyResults, validatePlan, partition, options } from '../scripts/test-runner.mjs';

const quiet = () => {};
async function fixture(files, action) {
  const root = mkdtempSync(join(tmpdir(), 'stream-test-runner-'));
  try {
    writeFileSync(join(root, 'package.json'), '{"type":"module"}\n');
    for (const [name, text] of Object.entries(files)) {
      const path = join(root, name); mkdirSync(dirname(path), { recursive: true }); writeFileSync(path, text, 'utf8');
    }
    await action(root);
  } finally {
    // Delete only the exact task-owned directory returned by mkdtemp.
    assert.equal(dirname(resolve(root)), resolve(tmpdir()));
    assert.match(basename(root), /^stream-test-runner-/);
    rmSync(root, { recursive: true, force: true });
  }
}
const makePlan = (root, shards = 1) => createPlan({ root, shards, concurrency: 2, output: join(root, '.runs/plan.json'), directory: join(root, '.runs/discovery'), progress: quiet });
const run = (root, plan, shard = 1, timeoutMs = 10000) => runShard({ root, plan, shard, timeoutMs, concurrency: 2, output: join(root, `.runs/shard-${shard}.json`), directory: join(root, `.runs/logs-${shard}`), progress: quiet });
const ordinary = "import test from 'node:test'; test('one', () => {}); test('two', () => {});";

test('discovery records registrations without executing tests or hooks', async () => {
  await fixture({ 'test/sample-workflow.test.mjs': "import test, { before } from 'node:test'; before(() => { throw Error('hook ran'); }); test('never called', () => { throw Error('body ran'); });" }, async root => {
    const plan = await makePlan(root);
    assert.deepEqual(plan.inventory[0].registrations.map(row => row.name), ['never called']);
    assert.equal(plan.inventory[0].wholeFile, true);
  });
});

test('partition and native reporters preserve duplicate names, regex punctuation and every file', async () => {
  await fixture({
    'test/simple.test.mjs': ordinary,
    'test/sample-workflow.test.mjs': "import test from 'node:test'; test('punctuation.* [x] (a) $', () => {}); test('duplicate', () => {}); test('duplicate', () => {}); test('last', () => {});"
  }, async root => {
    const plan = await makePlan(root, 3);
    assert.equal(plan.units.filter(row => row.file === 'test/simple.test.mjs').length, 1);
    assert.equal(plan.units.filter(row => row.names?.includes('duplicate')).length, 1);
    const results = [];
    for (let shard = 1; shard <= 3; shard++) results.push(await run(root, plan, shard));
    assert.deepEqual(verifyResults(plan, results), { files: 2, registrations: 6, shards: 3, units: 4 });
    for (const result of results) for (const row of result.results) {
      assert.match(row.logSha256, /^[a-f0-9]{64}$/);
      assert.match(readFileSync(join(root, `.runs/logs-${result.shard}`, row.log), 'utf8'), /TAP version 13/);
    }
  });
});

test('suites, context subtests and factory registrations keep complete-file execution', async () => {
  await fixture({
    'test/suite-workflow.test.mjs': "import { describe, it } from 'node:test'; describe('suite', () => { it('nested', () => {}); });",
    'test/context-workflow.test.mjs': "import test from 'node:test'; test('parent', async t => { await t.test('child', () => {}); });",
    'test/factory-workflow.test.mjs': "import test from 'node:test'; function register(name) { test(name, () => {}); } register('factory');"
  }, async root => {
    const plan = await makePlan(root);
    assert.ok(plan.inventory.every(row => row.wholeFile));
    const result = await run(root, plan);
    assert.equal(verifyResults(plan, [result]).files, 3);
    assert.ok(result.results.some(row => row.report.some(entry => entry.nesting === 1)));
  });
});

test('retained skip and todo registrations stay visible in the result', async () => {
  await fixture({ 'test/skip-workflow.test.mjs': "import test from 'node:test'; test.skip('skip', () => { throw Error('skip'); }); test.todo('todo', () => { throw Error('expected todo'); }); test('ordinary', () => {});" }, async root => {
    const plan = await makePlan(root); const result = await run(root, plan);
    assert.equal(verifyResults(plan, [result]).registrations, 3);
    assert.equal(result.results.flatMap(row => row.report).filter(row => row.skip || row.todo).length, 2);
  });
});

test('test assertions fail the shard and cannot be relabeled as success', async () => {
  await fixture({ 'test/failure.test.mjs': "import test from 'node:test'; test('broken', () => { throw Error('actual assertion'); });" }, async root => {
    const plan = await makePlan(root); const result = await run(root, plan);
    assert.equal(result.success, false);
    assert.throws(() => verifyResults(plan, [result]), /failed shard/);
    result.success = true; result.results[0].error = null;
    assert.throws(() => verifyResults(plan, [result]), /Test child failed/);
  });
});

test('bounded children terminate hangs and preserve their failure output', async () => {
  await fixture({ 'test/hang.test.mjs': "import test from 'node:test'; test('hang', async () => { await new Promise(() => setInterval(() => {}, 100)); });" }, async root => {
    const plan = await makePlan(root); const result = await run(root, plan, 1, 500);
    assert.equal(result.success, false); assert.equal(result.results[0].timedOut, true);
    assert.ok(result.results[0].elapsedMs < 10000);
    assert.ok(existsSync(join(root, '.runs/shard-1.json')));
  });
});

test('missing and duplicate shards or unit reports fail coverage verification', async () => {
  await fixture({ 'test/simple-workflow.test.mjs': ordinary }, async root => {
    const plan = await makePlan(root, 2); const results = [await run(root, plan, 1), await run(root, plan, 2)];
    assert.throws(() => verifyResults(plan, results.slice(0, 1)), /Every shard/);
    assert.throws(() => verifyResults(plan, [results[0], results[0]]), /Duplicate/);
    const missing = structuredClone(results); missing[0].results = [];
    assert.throws(() => verifyResults(plan, missing), /Missing unit/);
    const duplicate = structuredClone(results); duplicate[1].results = duplicate[0].results;
    assert.throws(() => verifyResults(plan, duplicate), /substituted unit/);
  });
});

test('missing names, extra names, unexpected skips and fabricated statuses fail coverage', async () => {
  await fixture({ 'test/simple.test.mjs': ordinary }, async root => {
    const plan = await makePlan(root); const result = await run(root, plan);
    const mutations = [
      rows => rows.pop(), rows => rows.push({ ...rows[0], name: 'unexpected' }),
      rows => { rows[0].skip = true; }, rows => { rows[0].todo = true; },
      rows => { rows[0].status = 'unknown'; }, rows => { rows[0].status = 'fail'; }
    ];
    for (const mutate of mutations) {
      const modified = structuredClone(result); mutate(modified.results[0].report);
      assert.throws(() => verifyResults(plan, [modified]), /inventory|Unexpected|Invalid test report/);
    }
  });
});

test('added test files and changed source bytes invalidate an existing plan', async () => {
  await fixture({ 'test/simple.test.mjs': ordinary, 'src/value.mjs': 'export const value = 1;' }, async root => {
    const plan = await makePlan(root); verifyInputs(plan, root);
    writeFileSync(join(root, 'src/value.mjs'), 'export const value = 2;');
    assert.throws(() => verifyInputs(plan, root), /inputs changed/);
    writeFileSync(join(root, 'test/new.test.mjs'), ordinary);
    assert.throws(() => verifyInputs(plan, root), /file set changed/);
  });
});

test('input mutation during execution fails the completed shard', async () => {
  await fixture({ 'test/change.test.mjs': "import test from 'node:test'; import { writeFileSync } from 'node:fs'; test('mutate', () => writeFileSync('package.json', '{}'));" }, async root => {
    const plan = await makePlan(root); const result = await run(root, plan);
    assert.equal(result.success, false); assert.match(result.inputError, /inputs changed/);
  });
});

test('stale plan identity and edited or overlapping partitions are rejected', async () => {
  await fixture({ 'test/simple-workflow.test.mjs': ordinary }, async root => {
    const plan = await makePlan(root); const result = await run(root, plan);
    const stale = structuredClone(result); stale.planHash = '0'.repeat(64);
    assert.throws(() => verifyResults(plan, [stale]), /stale/);
    const missing = structuredClone(plan); missing.units.pop();
    assert.throws(() => validatePlan(missing), /Incomplete/);
    const duplicate = structuredClone(plan); duplicate.units.push(duplicate.units[0]);
    assert.throws(() => validatePlan(duplicate), /Duplicate/);
    const replaced = structuredClone(plan); replaced.units[0].names = ['not registered'];
    assert.throws(() => validatePlan(replaced), /substituted/);
    const edited = structuredClone(plan); edited.inputs[0].sha256 = '0'.repeat(64);
    assert.throws(() => validatePlan(edited), /inventory hash/);
  });
});

test('discovery rejects unsupported helper imports before their tests execute', async () => {
  await fixture({
    'test/sample.test.mjs': "import './helper.mjs'; import test from 'node:test'; test('main', () => {});",
    'test/helper.mjs': "import test from 'node:test'; import { writeFileSync } from 'node:fs'; test('hidden', () => writeFileSync('body-ran', 'yes'));"
  }, async root => {
    await assert.rejects(makePlan(root), /Discovery failed/);
    assert.equal(existsSync(join(root, 'body-ran')), false);
  });
});

test('strict CLI options and timing inputs reject ambiguous scheduling', () => {
  assert.deepEqual(options(['--shards', '2'], ['shards']), { shards: '2' });
  for (const args of [['--shards'], ['--unknown', '2'], ['--shards', '2', '--shards', '3']]) assert.throws(() => options(args, ['shards']), /unique/);
  assert.throws(() => partition([], 1, { files: { bad: NaN } }), /timing/);
  assert.throws(() => partition([], 1, { cases: { bad: { case: -1 } } }), /timing/);
  assert.throws(() => partition([], 1), /More shards/);
});

test('native startup failures retain nonzero exit status and process output', async () => {
  await fixture({ 'test/simple.test.mjs': ordinary }, async root => {
    const log = join(root, '.runs/process.log');
    const result = await boundedNode(['--not-a-node-option'], { cwd: root, log, timeoutMs: 5000 });
    assert.notEqual(result.exitCode, 0); assert.equal(result.timedOut, false);
    assert.match(readFileSync(log, 'utf8'), /bad option/);
  });
});
