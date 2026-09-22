# Running the complete client suite in CI

`npm test` retains its complete ABI check, build, strict test types and native
`node --test test/*.test.mjs` command. CI uses the same test files through an
additional sharded runner; it does not maintain a reduced test list.

From `packages/stream-client`, with the pinned dependencies installed:

```bash
npm run test:prepare
npm run test:plan -- --shards 16
npm run test:shard -- --plan .test-runs/plan.json --shard 1
# Run every shard number from 1 through 16 before verification.
npm run test:verify -- --plan .test-runs/plan.json --results .test-runs
```

In Windows PowerShell, use `npm.cmd` for these commands so flags after `--`
reach the runner unchanged.

Preparation checks generated ABIs, builds once and checks strict test types.
The separate collector test remains in the CI preparation job. The plan and
built `dist` directory travel together to each shard. Use the same checkout,
Node major, dependencies and package inputs for preparation and execution.
Changing the checkout commit or captured input bytes requires a fresh plan.

## Inventory and execution

Discovery imports every top-level `test/*.test.mjs` file while substituting
registration functions for that file's `node:test` import. It records names and
declared skip/TODO flags without invoking test callbacks, suites or hooks.
Module initialization still runs. Unsupported registration APIs and helpers
that independently import `node:test` fail discovery and require explicit
runner support; they are never silently omitted.

Only flat `*-workflow.test.mjs` modules can be divided by test name. Duplicate
names stay together. Suites, context-taking callbacks, registration factories
and hook-bearing modules use complete-file execution. Every other file,
including source/fixture oracles, executes once as a complete file. The plan
checks that every discovered registration belongs to exactly one unit.

Execution uses ordinary Node tests and native name filters, with no discovery
loader or replacement assertions. Each child writes TAP plus a structured
report. The runner checks the exact selected name multiset and declared
skip/TODO flags. Nested tests execute under their original parent; Node's exit
status still determines success. Reports retain nested results. New test files
are automatically included; new names must appear in the completed reports.

## Bounds, scheduling and results

CI schedules 16 shards, at most eight simultaneously, with two children per
shard. Each child has a seven-minute bound; each CI job retains its ten-minute
bound. A timeout is a failure. Shards continue collecting other case results
after a test failure, and CI preserves available TAP, process and structured
logs for 14 days. A canceled job can leave an incomplete result, which fails
the aggregate.

The planner greedily balances estimated work. The checked-in timing seed covers
all 1,417 units from [CI run 35706718194](https://github.com/6529-Collections/6529Stream/actions/runs/35706718194):
1,239 units from 14 complete shards, 176 successful units from two cancelled
shards, and two separately recorded Windows measurements of the interrupted
tests. The CI plan identifies tested merge commit `f88799e6200f8f6d1c3cc8ef646c0e0547f23c1b`.
The isolated tests' 47 dependency inputs match that plan byte-for-byte. The
bundle test passed in 312 seconds on Node 22.12; the inventory test passed in
362 seconds on CI-matching Node 24.16 after an earlier Node 22 timeout.

Both interrupted tests previously had two-second estimates and started late.
The revised schedule starts them immediately. Replaying the measured durations
reduces the maximum estimated shard from 740 to 380 seconds, excluding job setup
and artifact upload. This is a scheduling model; a fresh full CI run remains
required. That calibration preserved every original file, registration,
assertion and timeout.

In [the next run](https://github.com/6529-Collections/6529Stream/actions/runs/35714135709),
the bundle passed in 351 seconds, but the inventory child still reached its
420-second bound despite starting first. The inventory regression now reports
its 17 independent stages separately. Each stage retains all three layouts and
the original lifecycle assertions, for the same 51 fresh-fixture flows. The
other 15 tests in that file remain unchanged. The original aggregate timing is
historical; these new stage names use the normal scheduling heuristics until
their measurements are incorporated into a later timing seed.

Unmeasured new units use explicit scheduling heuristics. Estimates affect
placement only and are not CI runtime guarantees. Pass `--timings PATH` to use an updated
JSON object with `files` (file to milliseconds) and/or `cases` (file to name to
milliseconds). Result reports include measured child and case durations for
future calibration. Avoid increasing bounds until the slow cases are examined.

The offline importer authenticates completed reports and their TAP/report files,
keeps interrupted observations separate, and requires completed supplements
before generating a full timing table:

```bash
node scripts/test-runner/timing-evidence.mjs --plan PLAN_JSON --results ARTIFACT_DIRECTORY --partial 4=SHARD4_LOG --partial 7=SHARD7_LOG --supplement BUNDLE_RESULT --supplement INVENTORY_RESULT --run RUN_URL --output TIMINGS_JSON --evidence LOCAL_EVIDENCE_JSON
```

Its evidence file records input hashes and the scheduling model. It cannot turn
a cancelled or timed-out child into successful test evidence.

The original `TypeScript client` check is the required aggregate. It requires
successful preparation and every matrix job, then checks all shard reports
against the plan, source commit and captured package inputs. Missing, duplicate,
stale, substituted, failed or unexpectedly skipped results fail verification.
This verifies client test execution; it makes no contract, Safe, deployment or
release-readiness claim.

Runner regression coverage is included in the normal suite and can be checked
alone with `node --test test/test-runner.test.mjs test/test-runner-timing-evidence.test.mjs`.
