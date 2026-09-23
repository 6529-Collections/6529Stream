// Verifier-unit data only. These fabricated documents are never native execution or current-report evidence.
import test from 'node:test';
import assert from 'node:assert/strict';
import path from 'node:path';
import { id } from 'ethers';
import { buildInventory, canonical, sha256 } from '../scripts/safe-acceptance-inventory.mjs';
import { authenticateCapture, reconcile, verifySourceTree, compactSummary, renderBacklog } from '../scripts/reconcile-safe-acceptance.mjs';

const A = n => `0x${n.toString(16).padStart(40, '0')}`;
const source = 'smart-contracts/SyntheticVerifierTarget.sol', hostSource = 'test/SyntheticVerifierOnly.t.sol';
const fqn = `${source}:SyntheticVerifierTarget`, host = `${hostSource}:SyntheticVerifierOnly`, testName = 'testSyntheticVerifierDocumentsOnly()';
const clone = structuredClone, exact = message => ({ message });

function setup() {
  const input = { language: 'Solidity', settings: { optimizer: { enabled: true, runs: 200 }, viaIR: true, evmVersion: 'paris', metadata: { bytecodeHash: 'none', appendCBOR: false } }, sources: {
    [source]: { content: '// SYNTHETIC VERIFIER UNIT FIXTURE; not compiled.\ncontract SyntheticVerifierTarget {\n function execute(uint256 value) external {}\n function read() external view returns(uint256) { return 1; }\n}\n' },
    [hostSource]: { content: '// SYNTHETIC VERIFIER UNIT FIXTURE; no EVM execution occurred.\ncontract SyntheticVerifierOnly {\n function testSyntheticVerifierDocumentsOnly() external {}\n}\n' },
  } };
  const targetAbi = [
    { type: 'function', name: 'execute', inputs: [{ name: 'value', type: 'uint256' }], outputs: [], stateMutability: 'nonpayable' },
    { type: 'function', name: 'read', inputs: [], outputs: [{ name: '', type: 'uint256' }], stateMutability: 'view' },
  ];
  const hostAbi = [{ type: 'function', name: testName.slice(0, -2), inputs: [], outputs: [], stateMutability: 'nonpayable' }];
  // Synthetic compiler-shaped identifiers resolve only these ordinary fixture functions; no AST or compiler run is invented.
  const output = { contracts: {
    [source]: { SyntheticVerifierTarget: { abi: targetAbi, evm: { methodIdentifiers: { 'execute(uint256)': id('execute(uint256)').slice(2, 10), 'read()': id('read()').slice(2, 10) } } } },
    [hostSource]: { SyntheticVerifierOnly: { abi: hostAbi, evm: { methodIdentifiers: { [testName]: id(testName).slice(2, 10) } } } },
  }, errors: [] };
  const inputBytes = Buffer.from(JSON.stringify(input)), outputBytes = Buffer.from(JSON.stringify(output));
  const capture = { sourceCommit: '1'.repeat(40), inputSha256: sha256(inputBytes), outputSha256: sha256(outputBytes), settingsSha256: sha256(canonical(input.settings)) };
  const configurations = [
    { id: 'safe-two-of-two', version: '1.4.1', threshold: 2, ownerCount: 2, fixtureSha256: sha256('synthetic Safe fixture A'), modules: [], guards: [], nestedOwners: [] },
    { id: 'safe-two-of-three', version: '1.4.1', threshold: 2, ownerCount: 3, fixtureSha256: sha256('synthetic Safe fixture B'), modules: [], guards: [], nestedOwners: [] },
  ];
  const profile = { capture, products: [{ fqn, reason: 'Synthetic verifier testing only', safeExposure: { classification: 'supported-contract', rationale: 'Synthetic ordinary target for verifier testing only.' } }], safeConfigurations: configurations };
  const inventory = clone(buildInventory({ input, output, profile, genesis: { entries: Array.from({ length: 37 }, (_, i) => ({ id: i + 1, key: `synthetic-role-${i + 1}` })) }, deployment: { instances: [] } }));
  const entry = inventory.entries.find(row => row.signature === 'execute(uint256)'), readEntry = inventory.entries.find(row => row.signature === 'read()');
  const ref = path => ({ path, sha256: sha256(input.sources[path].content), startLine: 1, endLine: 3 });
  const scenarios = [
    { id: 'authorized-safe', outcome: 'success', caller: 'authorized Safe', assertions: ['exact-inner-call'] },
    { id: 'invalid-role-safe', outcome: 'rejection', caller: 'Safe without required authority', assertions: ['exact-rejection'] },
    { id: 'owner-eoa', outcome: 'rejection', caller: 'individual Safe owner EOA', assertions: ['exact-rejection'] },
  ];
  const classification = { entryId: entry.id, callerClass: 'admin', route: 'safe-call', callerSensitive: false, rationale: 'Synthetic classification used only to exercise the reconciler.', sourceRefs: [ref(source)], scenarios };
  const binding = { id: 'synthetic-local-target', scope: 'local-test', capture: clone(capture), chainId: 31337, fqn, address: A(100), runtimeSha256: sha256('synthetic runtime, never deployed'), links: [], immutables: [], configurationId: 'synthetic-system', configurationSha256: sha256('synthetic configuration') };
  const claims = { schemaVersion: 1, capture: clone(capture), classifications: [classification], deploymentBindings: [binding], evidence: [] };
  const files = new Map();
  const put = (path, value) => { const bytes = Buffer.isBuffer(value) ? value : Buffer.from(typeof value === 'string' ? value : JSON.stringify(value)); files.set(path, bytes); return { path, sha256: sha256(bytes) }; };
  const readFile = path => { assert.ok(files.has(path), `Unexpected verifier read: ${path}`); return files.get(path); };
  const buildInfo = put('synthetic/build-info.json', { input: clone(input), output: clone(output) });
  const hostArtifact = put('synthetic/host.json', { abi: hostAbi });
  const config = put('synthetic/config.json', { via_ir: true, evm_version: 'paris', optimizer: true, optimizer_runs: 200, isolate: false });
  const tool = put('synthetic/dispatcher.js', '// SYNTHETIC unit-test bytes, not an executable dispatch transcript.');
  const viewInput = put('synthetic/captured-input.json', input);
  const expectedCases = { [host]: [testName] };
  const view = put('synthetic/view.json', { version: 1, status: 'PREPARED_EXECUTION_VIEW', expectedCases, inputFiles: { [viewInput.path]: viewInput.sha256 }, artifacts: { [host]: { owner: 'synthetic-build', sha256: hostArtifact.sha256 } }, viewArtifacts: { 'build-info/synthetic-build.json': buildInfo.sha256 } });
  const stdout = put('synthetic/stdout.json', { [host]: { test_results: { [testName]: { status: 'Success' } } } });
  const result = put('synthetic/result.json', { status: 'PASS_EXACT_TEST_ROSTER', listOnly: false, integrityErrors: [], chainId: 31337, executionViewSha256: view.sha256, expectedCases, runs: { [host]: { status: 'COMPLETE', exitCode: 0, stdoutSha256: stdout.sha256 } }, configSha256: config.sha256, tools: { [tool.path]: tool.sha256 } });
  const native = { result, view, stdout, config, buildInfo, hostArtifact, host, test: testName };
  return { input, output, inputBytes, outputBytes, capture, profile, inventory, entry, readEntry, classification, binding, claims, files, put, readFile, ref, native };
}
function nativeClaim(s, scenarioId = 'authorized-safe', safeConfigurationId = 'safe-two-of-two', suffix = '') {
  const scenario = s.classification.scenarios.find(row => row.id === scenarioId), config = s.profile.safeConfigurations.find(row => row.id === safeConfigurationId);
  return { id: `synthetic:${scenarioId}:${safeConfigurationId}${suffix}`, entryId: s.entry.id, kind: 'actual-safe-native', capture: clone(s.capture),
    scenarioId, safeConfigurationId, deploymentId: s.binding.id, native: clone(s.native), target: clone(s.binding),
    review: { reviewer: 'Synthetic verifier reviewer; not an actual acceptance review', qualification: 'reviewed-per-call-assertions', sourceRefs: [s.ref(hostSource)] },
    safe: { version: config.version, threshold: config.threshold, owners: Array.from({ length: config.ownerCount }, (_, i) => A(i + 1)), address: A(10), singleton: A(11), fallbackHandler: A(12), fixtureSha256: config.fixtureSha256, modules: [], guards: [], nestedOwners: [] },
    invocation: { route: scenarioId === 'owner-eoa' ? 'owner-eoa-call' : scenarioId === 'direct-safe-rejection' ? 'safe-call' : s.classification.route, operation: 0, to: s.binding.address, data: `${s.entry.selector}${'0'.repeat(64)}`, value: '0', nonce: '7', safeTxHash: `0x${'3'.repeat(64)}`, chainId: 31337, caller: scenario.caller },
    outcome: scenario.outcome, innerOutcome: scenario.outcome,
    assertions: scenario.assertions.map(kind => ({ kind, description: 'Synthetic verifier mapping only; does not certify Solidity execution.', sourceRefs: [s.ref(hostSource)] })) };
}
const run = s => reconcile({ inventory: s.inventory, profile: s.profile, claims: s.claims, input: s.input, readFile: s.readFile });
const coverage = (s, report = run(s)) => report.coverage.find(row => row.entryId === s.entry.id);
function updateNativeFile(s, evidence, key, mutate) {
  const ref = evidence.native[key], parsed = JSON.parse(s.readFile(ref.path)); mutate(parsed);
  evidence.native[key] = s.put(ref.path, parsed); return evidence.native[key];
}

test('raw compiler capture authentication accepts exact bytes and rejects either raw hash drift', () => {
  const s = setup(), result = authenticateCapture(s);
  assert.deepEqual(result.input, s.input); assert.deepEqual(result.output, s.output);
  assert.throws(() => authenticateCapture({ ...s, inputBytes: Buffer.concat([s.inputBytes, Buffer.from(' ')]) }), exact('Compiler input hash differs'));
  assert.throws(() => authenticateCapture({ ...s, outputBytes: Buffer.concat([s.outputBytes, Buffer.from('\n')]) }), exact('Compiler output hash differs'));
  assert.deepEqual(authenticateCapture(s), result);
});

test('capture settings, literal source and compiler errors are checked after authenticated hash repair', () => {
  for (const [mutate, message] of [
    [s => { s.profile.capture.settingsSha256 = sha256('wrong settings'); }, 'Compiler settings hash differs'],
    [s => { s.input.sources[source] = { urls: ['https://invalid.example/source.sol'] }; s.inputBytes = Buffer.from(JSON.stringify(s.input)); s.profile.capture.inputSha256 = sha256(s.inputBytes); }, `Non-literal compiler source: ${source}`],
    [s => { s.output.errors = [{ severity: 'error', message: 'synthetic compiler error' }]; s.outputBytes = Buffer.from(JSON.stringify(s.output)); s.profile.capture.outputSha256 = sha256(s.outputBytes); }, 'Compiler output contains errors'],
  ]) { const s = setup(); mutate(s); assert.throws(() => authenticateCapture(s), exact(message)); }
});

test('mocked, authored and source-reviewed evidence remain candidates, never execution coverage', () => {
  const s = setup(); s.claims.classifications = [];
  for (const kind of ['mock-client', 'authored-only', 'source-reviewed']) s.claims.evidence.push({ id: kind, kind, entryId: s.entry.id, capture: clone(s.capture), qualification: 'Synthetic test candidate with no native execution.' });
  const report = run(s); assert.equal(report.candidateEvidence.length, 3); assert.equal(report.summary.actualEvidenceRecords, 0);
  assert.equal(report.summary.coveredLocalReviewed, 0); assert.equal(report.summary.completeAcceptance, false);
  assert.ok(coverage(s, report).gaps.includes('missing-caller-classification'));
});

test('synthetic verifier documents fill only one reviewed scenario/configuration obligation', () => {
  const s = setup(); s.claims.evidence.push(nativeClaim(s));
  const report = run(s), row = coverage(s, report);
  assert.equal(row.obligations.length, 6); assert.equal(row.obligations.filter(x => x.status === 'covered-local-reviewed-test').length, 1);
  assert.equal(row.status, 'uncovered'); assert.equal(report.summary.completeAcceptance, false);
  assert.deepEqual(row.obligations.find(x => x.status === 'covered-local-reviewed-test'), { scenarioId: 'authorized-safe', safeConfigurationId: 'safe-two-of-two', deploymentId: s.binding.id, status: 'covered-local-reviewed-test', evidenceId: s.claims.evidence[0].id });
});

test('every required scenario is independent for each supported Safe configuration', () => {
  const s = setup();
  for (const scenario of s.classification.scenarios) for (const config of s.profile.safeConfigurations) s.claims.evidence.push(nativeClaim(s, scenario.id, config.id));
  const report = run(s); assert.equal(coverage(s, report).status, 'covered-local-reviewed-test');
  assert.equal(report.summary.actualEvidenceRecords, 6); assert.equal(report.summary.completeAcceptance, false);
  for (let i = 0; i < s.claims.evidence.length; i++) {
    const reduced = { ...s, claims: { ...s.claims, evidence: s.claims.evidence.filter((_, j) => i !== j) } }, row = coverage(reduced);
    assert.equal(row.status, 'uncovered'); assert.equal(row.obligations.filter(x => x.status === 'uncovered').length, 1);
  }
});

test('a passing exact test name without per-call reviewed mapping grants no coverage', () => {
  const s = setup(), report = run(s);
  assert.equal(report.summary.actualEvidenceRecords, 0); assert.equal(coverage(s, report).status, 'uncovered');
  const evidence = nativeClaim(s); delete evidence.review; s.claims.evidence.push(evidence);
  assert.throws(() => run(s), exact('Missing per-call reviewer'));
  evidence.review = { reviewer: 'Synthetic reviewer', qualification: 'test-name-match-only', sourceRefs: [s.ref(hostSource)] };
  assert.throws(() => run(s), exact('Missing per-call assertion review'));
  evidence.review.qualification = 'reviewed-per-call-assertions'; evidence.assertions = [];
  assert.throws(() => run(s), exact('Missing exact assertion: exact-inner-call'));
  evidence.assertions = nativeClaim(s).assertions; assert.equal(run(s).summary.actualEvidenceRecords, 1);
  const second = run(s).coverage.find(row => row.entryId === s.readEntry.id); assert.equal(second.status, 'uncovered');
});

test('cross-source claims, evidence, deployment, and profile captures are rejected', () => {
  for (const place of ['claims', 'evidence', 'deployment', 'profile']) {
    const s = setup(); s.claims.evidence = [nativeClaim(s)];
    if (place === 'claims') s.claims.capture.sourceCommit = '2'.repeat(40);
    if (place === 'evidence') s.claims.evidence[0].capture.inputSha256 = sha256('other input');
    if (place === 'deployment') s.claims.deploymentBindings[0].capture.outputSha256 = sha256('other output');
    if (place === 'profile') s.profile.capture = { ...s.profile.capture, sourceCommit: '2'.repeat(40) };
    assert.throws(() => run(s), new RegExp(`Cross-source ${place === 'deployment' ? 'deployment binding' : place === 'profile' ? 'profile' : `${place} capture`}`));
  }
});

test('exact target deployment identity and per-binding obligations cannot be substituted', () => {
  const s = setup(), evidence = nativeClaim(s); s.claims.evidence.push(evidence);
  evidence.target.address = A(101);
  assert.throws(() => run(s), exact('Cross-deployment evidence target'));
  evidence.target = clone(s.binding); evidence.invocation.to = A(101);
  assert.throws(() => run(s), exact('Safe direct target differs'));
  evidence.invocation.to = s.binding.address;
  s.claims.deploymentBindings.push({ ...clone(s.binding), id: 'second-local-target', address: A(102) });
  const row = coverage(s); assert.equal(row.obligations.length, 12);
  assert.equal(row.obligations.filter(x => x.status === 'covered-local-reviewed-test').length, 1);
});

test('duplicate and malformed IDs plus dangling classification/evidence references fail closed', () => {
  for (const [field, key, label] of [['classifications', 'entryId', 'classifications'], ['deploymentBindings', 'id', 'deployment bindings'], ['evidence', 'id', 'evidence']]) {
    const s = setup(); s.claims.evidence = [nativeClaim(s)];
    s.claims[field].push(clone(s.claims[field][0])); assert.throws(() => run(s), new RegExp(`Duplicate ${label}`));
    s.claims[field].pop(); s.claims[field][0][key] = ''; assert.throws(() => run(s), exact(`Missing ${label}.${key}`));
  }
  const s = setup(); s.claims.classifications[0].entryId = 'missing';
  assert.throws(() => run(s), exact('Unknown/stale classified entry: missing'));
  s.claims.classifications[0].entryId = s.entry.id; const evidence = nativeClaim(s); evidence.entryId = 'missing'; s.claims.evidence = [evidence];
  assert.throws(() => run(s), exact('Unknown/stale evidence entry: missing'));
});

test('required scenarios and explicit actual-evidence configuration bindings are mandatory', () => {
  for (const name of ['authorized-safe', 'invalid-role-safe', 'owner-eoa']) {
    const s = setup(); s.classification.scenarios = s.classification.scenarios.filter(row => row.id !== name);
    assert.throws(() => run(s), exact(`Missing required scenario ${name}`));
  }
  for (const key of ['scenarioId', 'safeConfigurationId', 'deploymentId']) {
    const s = setup(), evidence = nativeClaim(s); evidence[key] = 'unbound'; s.claims.evidence = [evidence];
    assert.throws(() => run(s), exact('Unbound actual Safe evidence'));
  }
});
function syncNativeJoins(s, evidence) {
  const view = JSON.parse(s.readFile(evidence.native.view.path));
  view.viewArtifacts[`build-info/${view.artifacts[host].owner}.json`] = evidence.native.buildInfo.sha256;
  view.artifacts[host].sha256 = evidence.native.hostArtifact.sha256;
  evidence.native.view = s.put(evidence.native.view.path, view);
  const result = JSON.parse(s.readFile(evidence.native.result.path));
  result.executionViewSha256 = evidence.native.view.sha256;
  result.runs[host].stdoutSha256 = evidence.native.stdout.sha256;
  result.configSha256 = evidence.native.config.sha256;
  evidence.native.result = s.put(evidence.native.result.path, result);
}

test('candidate references are retained and validated without upgrading their evidence kind', () => {
  const s = setup(), candidate = { id: 'authored-fixture', entryId: s.entry.id, capture: clone(s.capture), kind: 'authored-only', qualification: 'Only verifier source exists', sourceRefs: [s.ref(hostSource)], test: testName, note: 'Synthetic source reference, not executed.' };
  s.claims.evidence.push(candidate);
  assert.deepEqual(run(s).candidateEvidence[0], candidate);
  candidate.sourceRefs[0].sha256 = sha256('changed test source');
  assert.throws(() => run(s), exact(`Changed candidate source: ${hostSource}`));
});

test('duplicate scenario, Safe configuration, inventory and coverage-slot identities are rejected', () => {
  const cases = [
    [s => s.classification.scenarios.push(clone(s.classification.scenarios[0])), 'Duplicate scenarios: authorized-safe'],
    [s => s.profile.safeConfigurations.push(clone(s.profile.safeConfigurations[0])), 'Duplicate Safe configurations: safe-two-of-two'],
    [s => s.inventory.entries.push(clone(s.entry)), `Duplicate inventory entries: `],
    [s => { s.claims.evidence = [nativeClaim(s), nativeClaim(s, 'authorized-safe', 'safe-two-of-two', ':duplicate-slot')]; }, 'Duplicate evidence for scenario/configuration/deployment'],
  ];
  for (const [mutate, message] of cases) {
    const s = setup(); mutate(s);
    assert.throws(() => run(s), message === 'Duplicate inventory entries: ' ? exact(message + s.entry.id) : exact(message));
  }
});

test('required negative outcomes and read returns remain explicit without inventing write return assertions', () => {
  const s = setup(); s.classification.scenarios[1].outcome = 'success';
  assert.throws(() => run(s), exact('invalid-role-safe must reject'));
  s.classification.scenarios[1].outcome = 'rejection'; s.classification.callerSensitive = true;
  run(s); // This caller-sensitive write has no return value in its ABI.
  const r = setup(); r.classification.entryId = r.readEntry.id; r.classification.callerSensitive = true;
  assert.throws(() => run(r), exact('Safe read return assertion required'));
  r.classification.scenarios[0].assertions.push('return-in-safe-context'); run(r);
});

test('protocol-only classification requires independent source review and both distinct invocation routes', () => {
  const s = setup(); Object.assign(s.classification, { callerClass: 'protocol-only', route: 'safe-initiated-protocol', author: 'synthetic author', independentReview: { reviewer: 'different synthetic reviewer', sourceRefs: [s.ref(source)] }, scenarios: [
    { id: 'enclosing-safe-workflow', outcome: 'success', caller: 'Safe calling enclosing workflow', assertions: ['exact-inner-call'] },
    { id: 'direct-safe-rejection', outcome: 'rejection', caller: 'Safe directly attempting protocol method', assertions: ['exact-rejection'] },
  ] });
  const enclosing = nativeClaim(s, 'enclosing-safe-workflow');
  enclosing.invocation.to = A(200); enclosing.innerCall = { fqn, signature: s.entry.signature, selector: s.entry.selector, target: s.binding.address };
  const direct = nativeClaim(s, 'direct-safe-rejection');
  s.claims.evidence = [enclosing, direct]; assert.equal(run(s).summary.actualEvidenceRecords, 2);
  direct.invocation.route = 'safe-initiated-protocol'; assert.throws(() => run(s), exact('Invocation route/operation differs')); direct.invocation.route = 'safe-call';
  delete enclosing.innerCall; assert.throws(() => run(s), exact('Missing exact inner-call binding'));
  enclosing.innerCall = { fqn, signature: s.entry.signature, selector: s.entry.selector, target: s.binding.address };
  s.classification.independentReview.reviewer = s.classification.author;
  assert.throws(() => run(s), exact('Protocol classification review is not independent'));
  s.classification.independentReview.reviewer = 'different synthetic reviewer'; assert.equal(run(s).summary.actualEvidenceRecords, 2);
});

test('individual-owner EOA rejection does not invent Safe nonce or transaction hash evidence', () => {
  const s = setup(), evidence = nativeClaim(s, 'owner-eoa');
  delete evidence.invocation.nonce; delete evidence.invocation.safeTxHash; s.claims.evidence = [evidence];
  assert.equal(run(s).summary.actualEvidenceRecords, 1);
  evidence.invocation.route = 'safe-call'; assert.throws(() => run(s), exact('Invocation route/operation differs'));
});

test('outer successful test status cannot replace exact inner rejection outcome', () => {
  const s = setup(), evidence = nativeClaim(s, 'invalid-role-safe'); s.claims.evidence = [evidence];
  evidence.innerOutcome = 'success'; assert.throws(() => run(s), exact('Inner outcome differs; outer transaction status is insufficient'));
  evidence.innerOutcome = 'rejection'; assert.equal(run(s).summary.actualEvidenceRecords, 1);
});

test('native result requires execution, intact roster, exact case success and local domain', () => {
  const resultCases = [
    [v => { v.listOnly = true; }, 'Not authentic exact-roster execution'],
    [v => { v.integrityErrors = ['synthetic changed artifact']; }, 'Not authentic exact-roster execution'],
    [v => { v.chainId = 1; }, 'Native evidence must remain local chain 31337'],
    [v => { v.runs[host].exitCode = 1; }, 'Native host output join differs'],
    [v => { v.expectedCases = { [host]: ['unrelated()'] }; }, 'Execution roster join differs'],
  ];
  for (const [mutate, message] of resultCases) {
    const s = setup(), evidence = nativeClaim(s); s.claims.evidence = [evidence];
    updateNativeFile(s, evidence, 'result', mutate); assert.throws(() => run(s), exact(message));
  }
  const s = setup(), evidence = nativeClaim(s); s.claims.evidence = [evidence];
  updateNativeFile(s, evidence, 'stdout', v => { v[host].test_results[testName].status = 'Failure'; }); syncNativeJoins(s, evidence);
  assert.throws(() => run(s), exact('Exact native case did not succeed'));
});

test('native source closure and exact target ABI remain tied to the captured inventory', () => {
  for (const [mutate, message] of [
    [v => { v.input.sources[source].content += '// source drift'; }, `Cross-source native compiler input: ${source}`],
    [v => { delete v.input.sources[hostSource]; }, 'Target/test missing from native source closure'],
    [v => { v.output.contracts[source].SyntheticVerifierTarget.abi[0].name = 'different'; }, 'Native target ABI differs'],
  ]) {
    const s = setup(), evidence = nativeClaim(s); s.claims.evidence = [evidence];
    updateNativeFile(s, evidence, 'buildInfo', mutate); syncNativeJoins(s, evidence); assert.throws(() => run(s), exact(message));
  }
});

test('native configuration refuses fork and compiler-profile substitution despite resealed file joins', () => {
  for (const mutate of [v => { v.eth_rpc_url = 'https://example.invalid'; }, v => { v.fork_block_number = 1; }, v => { v.optimizer_runs = 1; }, v => { v.via_ir = false; }]) {
    const s = setup(), evidence = nativeClaim(s); s.claims.evidence = [evidence];
    updateNativeFile(s, evidence, 'config', mutate); syncNativeJoins(s, evidence);
    assert.throws(() => run(s), exact('Native configuration differs'));
  }
});

test('raw retained artifact bytes cannot drift while their references remain unchanged', () => {
  for (const [key, label] of [['result', 'native result'], ['view', 'execution view'], ['stdout', 'native stdout'], ['config', 'native config'], ['buildInfo', 'native build info'], ['hostArtifact', 'native host artifact']]) {
    const s = setup(), evidence = nativeClaim(s); s.claims.evidence = [evidence]; const ref = evidence.native[key];
    s.files.set(ref.path, Buffer.concat([s.readFile(ref.path), Buffer.from(' ')]));
    assert.throws(() => run(s), exact(`Changed ${label}: ${ref.path}`));
  }
});

test('Safe threshold, distinct owners, fixture and installed configuration are exact', () => {
  for (const [mutate, message] of [
    [v => { v.threshold = 1; }, 'Safe configuration differs'],
    [v => { v.owners[1] = v.owners[0]; }, 'Duplicate Safe owners'],
    [v => { v.fixtureSha256 = sha256('another Safe fixture'); }, 'Safe fixture differs'],
    [v => { v.modules = [A(30)]; }, 'Safe modules differ'],
    [v => { v.guards = [A(31)]; }, 'Safe guards differ'],
    [v => { v.nestedOwners = [A(32)]; }, 'Safe nesting differs'],
  ]) { const s = setup(), evidence = nativeClaim(s); s.claims.evidence = [evidence]; mutate(evidence.safe); assert.throws(() => run(s), exact(message)); }
});

test('review and assertion references require unchanged source hashes and bounded exact lines', () => {
  for (const [mutate, message] of [
    [e => { e.review.sourceRefs[0].sha256 = sha256('wrong source'); }, `Changed per-call review source: ${hostSource}`],
    [e => { e.review.sourceRefs[0].endLine = 999; }, 'Invalid per-call review source range'],
    [e => { e.assertions[0].sourceRefs[0].startLine = 0; }, 'Invalid assertion source range'],
  ]) { const s = setup(), evidence = nativeClaim(s); s.claims.evidence = [evidence]; mutate(evidence); assert.throws(() => run(s), exact(message)); }
  const s = setup(), evidence = nativeClaim(s); s.claims.evidence = [evidence]; evidence.review.sourceRefs = [s.ref(source)];
  assert.throws(() => run(s), exact('Review does not identify executed test source'));
});
test('native build settings cannot be substituted behind exact source and ABI claims', () => {
  for (const mutate of [v => { v.optimizer.runs = 1; }, v => { v.viaIR = false; }, v => { v.metadata.appendCBOR = true; }]) {
    const s = setup(), evidence = nativeClaim(s); s.claims.evidence = [evidence];
    updateNativeFile(s, evidence, 'buildInfo', v => mutate(v.input.settings)); syncNativeJoins(s, evidence);
    assert.throws(() => run(s), exact('Native build compiler settings differ'));
  }
});

test('executed host ABI must match the authenticated native build rather than only the view hash', () => {
  const s = setup(), evidence = nativeClaim(s); s.claims.evidence = [evidence];
  updateNativeFile(s, evidence, 'hostArtifact', v => { v.abi[0].name = 'anotherSyntheticTest'; }); syncNativeJoins(s, evidence);
  assert.throws(() => run(s), exact('Executed host ABI differs from native build'));
});

test('candidate labels cannot promote complete native-shaped documents to runtime coverage', () => {
  for (const kind of ['mock-client', 'authored-only', 'source-reviewed']) {
    const s = setup(), evidence = nativeClaim(s); evidence.kind = kind; evidence.qualification = 'Synthetic candidate only';
    s.claims.evidence = [evidence]; const report = run(s);
    assert.equal(report.summary.actualEvidenceRecords, 0); assert.equal(report.candidateEvidence.length, 1);
    assert.equal(coverage(s, report).obligations.every(v => v.status === 'uncovered'), true);
  }
});

test('wrong selector, delegatecall, caller and chain cannot reuse a reviewed call mapping', () => {
  for (const [mutate, message] of [
    [v => { v.data = `0x12345678${'0'.repeat(64)}`; }, 'Call selector differs'],
    [v => { v.operation = 1; }, 'Invocation route/operation differs'],
    [v => { v.caller = 'another Safe'; }, 'Invocation caller/domain differs'],
    [v => { v.chainId = 1; }, 'Invocation caller/domain differs'],
  ]) { const s = setup(), evidence = nativeClaim(s); s.claims.evidence = [evidence]; mutate(evidence.invocation); assert.throws(() => run(s), exact(message)); }
});

test('exact source-tree verification allows Windows CRLF and preserves all other UTF-8 bytes', () => {
  const s = setup(), root = path.resolve('synthetic-verifier-source-root'), requested = [];
  const readFile = file => {
    requested.push(file); const sourceName = Object.keys(s.input.sources).find(name => path.join(root, name) === file);
    assert.ok(sourceName, `Unexpected source read ${file}`); return Buffer.from(s.input.sources[sourceName].content.replace(/\n/g, '\r\n'));
  };
  assert.equal(verifySourceTree({ input: s.input, root, readFile }), 2);
  assert.deepEqual(requested, Object.keys(s.input.sources).map(name => path.join(root, name)));
});

test('source-tree verification rejects changed source without whitespace normalization', () => {
  const s = setup();
  assert.throws(() => verifySourceTree({ input: s.input, root: 'synthetic-verifier-source-root', readFile: () => Buffer.from(`${s.input.sources[source].content} `) }), exact(`Working source differs from capture: ${source}`));
});

test('source-tree verification propagates missing-file failure instead of skipping a source', () => {
  const s = setup(), missing = Object.assign(new Error('Synthetic missing captured source'), { code: 'ENOENT' });
  assert.throws(() => verifySourceTree({ input: s.input, root: 'synthetic-verifier-source-root', readFile: () => { throw missing; } }), error => error === missing);
});

test('source-tree traversal, absolute and Windows drive paths are refused before reads', () => {
  for (const unsafe of ['../outside.sol', '/outside.sol', 'C:/outside.sol', 'folder\\outside.sol', 'folder/./outside.sol']) {
    let reads = 0;
    assert.throws(() => verifySourceTree({ input: { sources: { [unsafe]: { content: 'synthetic' } } }, root: 'synthetic-verifier-source-root', readFile: () => { reads++; return Buffer.from('synthetic'); } }), exact('Unsafe captured source path'));
    assert.equal(reads, 0);
  }
});
test('public reconciliation rejects source content, missing-source and added-source drift despite unchanged capture metadata', () => {
  for (const mutate of [
    input => { input.sources[source].content += '// changed literal source'; },
    input => { delete input.sources[hostSource]; },
    input => { input.sources['test/UnboundSynthetic.sol'] = { content: '// additional unbound source' }; },
  ]) {
    const s = setup(), original = clone(s.input); run(s); mutate(s.input);
    assert.throws(() => run(s), exact('Reconciliation source inventory differs'));
    s.input = original; assert.equal(run(s).summary.completeAcceptance, false);
  }
});
test('unresolved call selectors and unmatched compiler aliases cannot establish actual call coverage', () => {
  const s = setup(), evidence = nativeClaim(s), selector = s.entry.selector, kind = s.entry.kind;
  s.claims.evidence = [evidence]; assert.equal(run(s).summary.actualEvidenceRecords, 1);
  // Deliberate public-API inventory mutants retain the entry ID to isolate the selector admission guard.
  for (const unresolvedKind of ['function', 'compiler-method', 'callback']) {
    s.entry.kind = unresolvedKind; s.entry.selector = null;
    assert.throws(() => run(s), exact(unresolvedKind === 'compiler-method' ? 'Resolve compiler/ABI alias before classifying a call' : 'Unresolved selector cannot establish actual call coverage'));
  }
  s.entry.kind = kind; s.entry.selector = selector;
  assert.equal(run(s).summary.actualEvidenceRecords, 1);
});
function exposureFixture({ helperExposure = 'implementation-only', targetExposure = 'supported-contract' } = {}) {
  const s = setup(), helperSource = 'smart-contracts/SyntheticVerifierHelper.sol', helperFqn = `${helperSource}:SyntheticVerifierHelper`;
  s.input.sources[helperSource] = { content: '// SYNTHETIC helper; not compiled or executed.\nlibrary SyntheticVerifierHelper {\n function helper(uint256 value) public {}\n}\n' };
  s.output.contracts[helperSource] = { SyntheticVerifierHelper: { abi: [{ type: 'function', name: 'helper', inputs: [{ name: 'value', type: 'uint256' }], outputs: [], stateMutability: 'nonpayable' }], evm: { methodIdentifiers: { 'helper(uint256)': id('helper(uint256)').slice(2, 10) } } } };
  const alias = 'execute(SyntheticVerifierTarget.Nominal)';
  s.output.contracts[source].SyntheticVerifierTarget.evm.methodIdentifiers[alias] = id(alias).slice(2, 10);
  if (targetExposure === null) delete s.profile.products[0].safeExposure;
  else s.profile.products[0].safeExposure = { classification: targetExposure, rationale: 'Explicit synthetic target exposure for category tests.' };
  const helper = { fqn: helperFqn, reason: 'Synthetic helper included only to test backlog partitioning.' };
  if (helperExposure !== null) helper.safeExposure = { classification: helperExposure, rationale: 'Explicit synthetic helper exposure; this label is not execution evidence.' };
  s.profile.products.push(helper);
  s.inputBytes = Buffer.from(JSON.stringify(s.input)); s.outputBytes = Buffer.from(JSON.stringify(s.output));
  s.capture = { ...s.capture, inputSha256: sha256(s.inputBytes), outputSha256: sha256(s.outputBytes) };
  s.profile.capture = clone(s.capture); s.claims.capture = clone(s.capture); s.binding.capture = clone(s.capture);
  s.inventory = clone(buildInventory({ input: s.input, output: s.output, profile: s.profile, genesis: { entries: Array.from({ length: 37 }, (_, i) => ({ id: i + 1, key: `synthetic-role-${i + 1}` })) }, deployment: { instances: [] } }));
  s.entry = s.inventory.entries.find(row => row.fqn === fqn && row.signature === 'execute(uint256)');
  s.readEntry = s.inventory.entries.find(row => row.fqn === fqn && row.signature === 'read()');
  s.classification.entryId = s.entry.id;
  s.helperEntry = s.inventory.entries.find(row => row.fqn === helperFqn && row.signature === 'helper(uint256)');
  s.aliasEntry = s.inventory.entries.find(row => row.kind === 'compiler-method' && row.signature === alias);
  return { ...s, helperSource, helperFqn };
}
test('implementation helpers and unmatched compiler aliases stay outside the primary supported-function backlog', () => {
  const s = exposureFixture(), report = run(s);
  assert.equal(report.inventory.entries.length, 4); assert.equal(report.summary.machineRecords, 4);
  assert.equal(report.summary.primaryFunctions, 2); assert.equal(report.summary.primaryUncoveredFunctions, 2);
  assert.equal(report.summary.implementationAbiFunctions, 1); assert.equal(report.summary.unresolvedCompilerAliasRecords, 1);
  assert.deepEqual(report.primaryBacklog.map(row => row.fqn), [fqn]);
  assert.deepEqual(report.primaryBacklog[0].entries.map(row => row.entryId).sort(), [s.entry.id, s.readEntry.id].sort());
  assert.deepEqual(report.implementationBacklog.map(row => row.fqn), [s.helperFqn]);
  assert.deepEqual(report.implementationBacklog[0].entryIds, [s.helperEntry.id]);
  assert.equal(report.coverage.find(row => row.entryId === s.aliasEntry.id).scope, 'compiler-alias');
  assert.equal(report.coverage.find(row => row.entryId === s.helperEntry.id).obligations.length, 0);
  assert.match(report.implementationBacklog[0].requirement, /no independent Safe transaction inferred/);
  const artifacts = { report: { fileName: 'synthetic-unit-report.json', sha256: sha256(canonical(report)) } };
  const summary = compactSummary(report, artifacts); assert.deepEqual(summary.artifacts, artifacts);
  assert.equal(summary.summary.primaryFunctions, 2); assert.equal(summary.summary.machineRecords, 4);
  const backlog = renderBacklog(report); assert.match(backlog, /2 functions across 1 explicitly supported/);
  assert.match(backlog, /1 implementation libraries \(1 ABI functions\)/);
  assert.match(backlog, /1 unmatched compiler method records/);
});

test('explicit external-library support includes its function but does not count an unmatched alias twice', () => {
  const s = exposureFixture({ helperExposure: 'externally-supported-library' }), report = run(s);
  assert.equal(report.summary.primaryContracts, 2); assert.equal(report.summary.primaryFunctions, 3);
  assert.equal(report.summary.primaryUncoveredFunctions, 3); assert.equal(report.summary.implementationAbiFunctions, 0);
  assert.equal(report.summary.unresolvedCompilerAliasRecords, 1); assert.equal(report.summary.machineRecords, 4);
  assert.deepEqual(report.primaryBacklog.find(row => row.fqn === s.helperFqn).entries.map(row => row.entryId), [s.helperEntry.id]);
  assert.equal(report.primaryBacklog.flatMap(row => row.entries).some(row => row.entryId === s.aliasEntry.id), false);
  assert.equal(report.summary.coveredLocalReviewed, 0); assert.equal(report.summary.completeAcceptance, false);
});

test('missing exposure remains unclassified and cannot silently become primary or grant actual coverage', () => {
  const s = exposureFixture({ targetExposure: null }), report = run(s), row = coverage(s, report);
  assert.equal(report.summary.primaryFunctions, 0); assert.equal(report.summary.unclassifiedExposureRecords, 2);
  assert.equal(row.scope, 'unclassified-exposure'); assert.equal(row.status, 'uncovered');
  assert.ok(row.gaps.includes('missing-Safe-exposure-classification'));
  s.claims.evidence = [nativeClaim(s)];
  assert.throws(() => run(s), exact('Missing explicit Safe exposure classification'));
  s.profile.products[0].safeExposure = { classification: 'supported-contract', rationale: 'Explicit synthetic target restoration.' };
  assert.equal(run(s).summary.actualEvidenceRecords, 1);
});

test('implementation classification requires enclosing business and callguard assertions but alone never covers a helper', () => {
  const s = exposureFixture();
  const classification = { entryId: s.helperEntry.id, callerClass: 'implementation-only', route: 'safe-initiated-protocol', callerSensitive: false,
    rationale: 'Synthetic helper is reached only through its enclosing reviewed business workflow.', sourceRefs: [s.ref(s.helperSource)],
    scenarios: [{ id: 'enclosing-safe-workflow', outcome: 'success', caller: 'Safe calling supported business workflow', assertions: ['enclosing-business-path', 'applicable-callguard'] }] };
  s.claims.classifications.push(classification);
  s.claims.deploymentBindings.push({ ...clone(s.binding), id: 'synthetic-helper-binding', fqn: s.helperFqn, address: A(110) });
  let report = run(s), row = report.coverage.find(value => value.entryId === s.helperEntry.id);
  assert.equal(row.scope, 'implementation-path'); assert.equal(row.status, 'uncovered');
  assert.deepEqual(row.obligations.map(value => value.scenarioId), ['enclosing-safe-workflow', 'enclosing-safe-workflow']);
  assert.equal(report.implementationBacklog[0].status, 'uncovered'); assert.equal(report.summary.actualEvidenceRecords, 0);
  assert.equal(report.summary.coveredLocalReviewed, 0);
  classification.scenarios[0].assertions.pop();
  assert.throws(() => run(s), exact('Missing enclosing business path/callguard assertions'));
  classification.scenarios[0].assertions.push('applicable-callguard'); classification.route = 'safe-call';
  assert.throws(() => run(s), exact('Implementation library must use its enclosing workflow'));
  classification.route = 'safe-initiated-protocol'; report = run(s);
  assert.equal(report.implementationBacklog[0].status, 'uncovered');
});