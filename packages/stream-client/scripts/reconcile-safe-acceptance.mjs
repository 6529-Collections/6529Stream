/** Offline inventory reconciliation. Never runs a compiler, EVM, RPC or deployment. */
import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';
import { buildInventory, canonical, sha256 } from './safe-acceptance-inventory.mjs';

function requireThat(condition, message) {
  if (!condition) throw new Error(message);
}
function same(a, b, message) { requireThat(canonical(a) === canonical(b), message); }
function nonempty(value, label) {
  requireThat(typeof value === 'string' && value.trim().length > 0, `Missing ${label}`);
}
function unique(rows, key, label) {
  requireThat(Array.isArray(rows), `${label} must be an array`);
  const map = new Map();
  for (const row of rows) {
    nonempty(row[key], `${label}.${key}`);
    requireThat(!map.has(row[key]), `Duplicate ${label}: ${row[key]}`);
    map.set(row[key], row);
  }
  return map;
}
function digest(value, label) {
  requireThat(typeof value === 'string' && /^[a-f0-9]{64}$/.test(value), `Invalid ${label} SHA256`);
}
function address(value, label) {
  requireThat(typeof value === 'string' && /^0x[0-9a-fA-F]{40}$/.test(value)
    && !/^0x0{40}$/.test(value), `Invalid ${label} address`);
}

export function authenticateCapture({ inputBytes, outputBytes, profile }) {
  const capture = profile.capture;
  requireThat(capture && /^[a-f0-9]{40}$/.test(capture.sourceCommit), 'Capture needs exact source commit');
  digest(capture.inputSha256, 'input'); digest(capture.outputSha256, 'output');
  requireThat(sha256(inputBytes) === capture.inputSha256, 'Compiler input hash differs');
  requireThat(sha256(outputBytes) === capture.outputSha256, 'Compiler output hash differs');
  const input = JSON.parse(inputBytes.toString('utf8'));
  const output = JSON.parse(outputBytes.toString('utf8'));
  requireThat(input.language === 'Solidity', 'Expected Solidity compiler input');
  requireThat(!output.errors?.some(row => row.severity === 'error'), 'Compiler output contains errors');
  requireThat(Object.keys(input.sources ?? {}).length > 0, 'Missing literal compiler sources');
  for (const [name, source] of Object.entries(input.sources)) {
    requireThat(typeof source.content === 'string', `Non-literal compiler source: ${name}`);
  }
  requireThat(sha256(canonical(input.settings ?? {})) === capture.settingsSha256, 'Compiler settings hash differs');
  return { input, output };
}

export function verifySourceTree({ input, root, readFile = fs.readFileSync }) {
  const base = path.resolve(root);
  for (const [source, row] of Object.entries(input.sources)) {
    requireThat(!source.includes('\\') && !source.includes(':') && !path.isAbsolute(source)
      && source.split('/').every(part => part && part !== '.' && part !== '..'), 'Unsafe captured source path');
    const actual = readFile(path.join(base, source)).toString('utf8').replace(/\r\n/g, '\n');
    requireThat(actual === row.content, `Working source differs from capture: ${source}`);
  }
  return Object.keys(input.sources).length;
}

function sourceReferences(refs, input, label) {
  requireThat(Array.isArray(refs) && refs.length > 0, `Missing ${label} source references`);
  for (const ref of refs) {
    const text = input.sources[ref.path]?.content;
    requireThat(typeof text === 'string', `Unknown ${label} source: ${ref.path}`);
    requireThat(sha256(text) === ref.sha256, `Changed ${label} source: ${ref.path}`);
    const lines = text.split('\n').length;
    requireThat(Number.isInteger(ref.startLine) && ref.startLine > 0
      && Number.isInteger(ref.endLine) && ref.endLine >= ref.startLine && ref.endLine <= lines,
    `Invalid ${label} source range`);
  }
}

function fileReference(ref, readFile, label) {
  requireThat(ref && typeof ref.path === 'string', `Missing ${label} reference`);
  digest(ref.sha256, label);
  const bytes = readFile(ref.path);
  requireThat(sha256(bytes) === ref.sha256, `Changed ${label}: ${ref.path}`);
  return bytes;
}
function jsonReference(ref, readFile, label) {
  return JSON.parse(fileReference(ref, readFile, label).toString('utf8'));
}

function validateClassification(row, entry, input, scope) {
  const implementation = scope === 'implementation-path';
  requireThat((implementation ? ['implementation-only'] : ['user', 'artist', 'admin', 'permissionless', 'read', 'protocol-only']).includes(row.callerClass),
    `Unknown caller class: ${row.entryId}`);
  requireThat(['safe-call', 'safe-erc1271-relay', 'safe-initiated-protocol', 'callback'].includes(row.route),
    `Unknown route: ${row.entryId}`);
  nonempty(row.rationale, 'classification rationale');
  sourceReferences(row.sourceRefs, input, 'classification');
  requireThat(typeof row.callerSensitive === 'boolean', 'Explicit callerSensitive required');
  const scenarios = unique(row.scenarios, 'id', 'scenarios');
  requireThat(scenarios.size > 0, 'Classification requires scenarios');
  for (const scenario of scenarios.values()) {
    requireThat(['success', 'rejection'].includes(scenario.outcome), 'Unknown scenario outcome');
    nonempty(scenario.caller, 'scenario caller identity/role');
    requireThat(Array.isArray(scenario.assertions) && scenario.assertions.length > 0
      && scenario.assertions.every(x => typeof x === 'string' && x.length), 'Missing required assertions');
  }
  const needed = implementation ? ['enclosing-safe-workflow'] : row.callerClass === 'protocol-only'
    ? ['enclosing-safe-workflow', 'direct-safe-rejection']
    : ['authorized-safe'];
  if (['user', 'artist', 'admin'].includes(row.callerClass)) needed.push('invalid-role-safe', 'owner-eoa');
  for (const id of needed) requireThat(scenarios.has(id), `Missing required scenario ${id}`);
  if (implementation) {
    requireThat(row.route === 'safe-initiated-protocol', 'Implementation library must use its enclosing workflow');
    const scenario = scenarios.get('enclosing-safe-workflow');
    requireThat(scenario.outcome === 'success' && scenario.assertions.includes('enclosing-business-path')
      && scenario.assertions.includes('applicable-callguard'), 'Missing enclosing business path/callguard assertions');
  } else if (row.callerClass === 'protocol-only') {
    requireThat(row.route === 'safe-initiated-protocol' || row.route === 'callback', 'Protocol-only route differs');
    requireThat(scenarios.get('direct-safe-rejection').outcome === 'rejection'
      && scenarios.get('enclosing-safe-workflow').outcome === 'success', 'Protocol-only outcomes differ');
    nonempty(row.author, 'protocol classification author');
    nonempty(row.independentReview?.reviewer, 'independent protocol classification review');
    requireThat(row.independentReview.reviewer !== row.author, 'Protocol classification review is not independent');
    sourceReferences(row.independentReview.sourceRefs, input, 'protocol review');
  } else {
    requireThat(scenarios.get('authorized-safe').outcome === 'success', 'Authorized Safe must succeed');
    for (const id of ['invalid-role-safe', 'owner-eoa']) {
      if (scenarios.has(id)) requireThat(scenarios.get(id).outcome === 'rejection', `${id} must reject`);
    }
  }
  if (entry.mutability === 'view' || entry.mutability === 'pure') {
    const authorized = scenarios.get('authorized-safe') ?? scenarios.get('enclosing-safe-workflow');
    requireThat(authorized.assertions.includes('return-in-safe-context'), 'Safe read return assertion required');
  }
  return scenarios;
}

function validateDeployment(binding, inventory) {
  requireThat(binding.scope === 'local-test' || binding.scope === 'deployed', 'Unknown deployment scope');
  same(binding.capture, inventory.capture, 'Cross-source deployment binding');
  requireThat(Number.isSafeInteger(binding.chainId) && binding.chainId > 0, 'Missing deployment chain');
  nonempty(binding.fqn, 'deployment FQN'); address(binding.address, 'target');
  digest(binding.runtimeSha256, 'target runtime');
  requireThat(Array.isArray(binding.links) && Array.isArray(binding.immutables), 'Explicit links/immutables required');
  nonempty(binding.configurationId, 'deployment configuration');
  digest(binding.configurationSha256, 'deployment configuration');
  if (binding.scope === 'deployed') {
    const instance = inventory.deployments.find(row => row.id === binding.id);
    requireThat(instance && canonical(instance) === canonical(binding), 'Unrecognized deployed instance');
  }
}

/** A passing case is insufficient: require a reviewed, source-bound per-call assertion map.
 * This checks its identity and retained execution provenance, not Solidity semantics.
 * The review remains explicit report evidence, never an inferred automatic proof.
 */
function verifyNativeEvidence(evidence, context) {
  const { input, inventory, entry, classification, scenario, config, binding, readFile } = context;
  if (['function', 'compiler-method', 'callback'].includes(entry.kind)) {
    requireThat(typeof entry.selector === 'string' && /^0x[0-9a-f]{8}$/.test(entry.selector),
      'Unresolved selector cannot establish actual call coverage');
  }
  const proof = evidence.native;
  requireThat(proof, 'Missing native execution proof');
  const result = jsonReference(proof.result, readFile, 'native result');
  const view = jsonReference(proof.view, readFile, 'execution view');
  requireThat(result.status === 'PASS_EXACT_TEST_ROSTER' && result.listOnly === false
    && Array.isArray(result.integrityErrors) && result.integrityErrors.length === 0,
  'Not authentic exact-roster execution');
  requireThat(view.version === 1 && view.status === 'PREPARED_EXECUTION_VIEW', 'Invalid execution view');
  requireThat(result.executionViewSha256 === proof.view.sha256, 'Execution-view join differs');
  requireThat(binding.scope === 'local-test' && binding.chainId === 31337
    && result.chainId === 31337, 'Native evidence must remain local chain 31337');
  same(result.expectedCases, view.expectedCases, 'Execution roster join differs');
  requireThat(view.expectedCases?.[proof.host]?.includes(proof.test), 'Case absent from native ABI roster');
  const run = result.runs?.[proof.host];
  requireThat(run?.status === 'COMPLETE' && run.exitCode === 0
    && run.stdoutSha256 === proof.stdout.sha256, 'Native host output join differs');
  const stdout = jsonReference(proof.stdout, readFile, 'native stdout');
  requireThat(stdout[proof.host]?.test_results?.[proof.test]?.status === 'Success', 'Exact native case did not succeed');
  const effectiveConfig = jsonReference(proof.config, readFile, 'native config');
  requireThat(result.configSha256 === proof.config.sha256 && effectiveConfig.via_ir === true
    && effectiveConfig.evm_version === 'paris' && effectiveConfig.optimizer === true
    && effectiveConfig.optimizer_runs === 200 && effectiveConfig.isolate === false
    && !effectiveConfig.eth_rpc_url && !effectiveConfig.fork_url
    && effectiveConfig.fork_block_number == null && effectiveConfig.fork_block_hash == null,
  'Native configuration differs');
  requireThat(result.tools && Object.keys(result.tools).length > 0, 'Missing dispatch tool hashes');
  for (const [file, hash] of Object.entries(result.tools)) fileReference({ path: file, sha256: hash }, readFile, 'dispatch tool');
  requireThat(view.inputFiles && Object.keys(view.inputFiles).length > 0, 'Missing view input hashes');
  for (const [file, hash] of Object.entries(view.inputFiles)) fileReference({ path: file, sha256: hash }, readFile, 'view input');
  const build = jsonReference(proof.buildInfo, readFile, 'native build info');
  requireThat(build.input && build.output, 'Native build-info input/output missing');
  const settings = build.input.settings;
  requireThat(settings?.viaIR === true && settings.evmVersion === 'paris'
    && settings.optimizer?.enabled === true && settings.optimizer.runs === 200
    && settings.metadata?.bytecodeHash === 'none' && settings.metadata.appendCBOR === false,
  'Native build compiler settings differ');
  for (const [source, row] of Object.entries(build.input.sources ?? {})) {
    requireThat(typeof row.content === 'string' && row.content === input.sources[source]?.content,
      `Cross-source native compiler input: ${source}`);
  }
  requireThat(Object.keys(build.input.sources ?? {}).length > 0, 'Empty native compiler source closure');
  const source = entry.fqn?.slice(0, entry.fqn.lastIndexOf(':'));
  const contract = entry.fqn?.slice(entry.fqn.lastIndexOf(':') + 1);
  requireThat(build.input.sources[source] && build.input.sources[proof.host.slice(0, proof.host.lastIndexOf(':'))],
    'Target/test missing from native source closure');
  const nativeArtifact = build.output.contracts?.[source]?.[contract];
  requireThat(nativeArtifact && sha256(canonical(nativeArtifact.abi)) === entry.abiSha256, 'Native target ABI differs');
  const owner = view.artifacts?.[proof.host];
  requireThat(owner && proof.buildInfo.sha256 === view.viewArtifacts?.[`build-info/${owner.owner}.json`],
    'Build-info does not own executed host');
  const hostArtifact = jsonReference(proof.hostArtifact, readFile, 'native host artifact');
  requireThat(proof.hostArtifact.sha256 === owner.sha256
    && Array.isArray(hostArtifact.abi), 'Executed host artifact differs');
  const hostSource = proof.host.slice(0, proof.host.lastIndexOf(':'));
  const hostName = proof.host.slice(proof.host.lastIndexOf(':') + 1);
  const compiledHost = build.output.contracts?.[hostSource]?.[hostName];
  requireThat(compiledHost && canonical(hostArtifact.abi) === canonical(compiledHost.abi), 'Executed host ABI differs from native build');
  nonempty(evidence.review?.reviewer, 'per-call reviewer');
  requireThat(evidence.review?.qualification === 'reviewed-per-call-assertions', 'Missing per-call assertion review');
  sourceReferences(evidence.review.sourceRefs, input, 'per-call review');
  requireThat(evidence.review.sourceRefs.some(ref => ref.path === proof.host.slice(0, proof.host.lastIndexOf(':'))),
    'Review does not identify executed test source');
  same(evidence.target, binding, 'Cross-deployment evidence target');
  const safe = evidence.safe;
  requireThat(safe && safe.version === config.version && safe.threshold === config.threshold
    && safe.owners?.length === config.ownerCount, 'Safe configuration differs');
  requireThat(new Set(safe.owners.map(x => x.toLowerCase())).size === safe.owners.length, 'Duplicate Safe owners');
  safe.owners.forEach(ownerAddress => address(ownerAddress, 'Safe owner'));
  requireThat(Number.isInteger(safe.threshold) && safe.threshold > 0 && safe.threshold <= safe.owners.length,
    'Invalid Safe threshold');
  for (const key of ['address', 'singleton', 'fallbackHandler']) address(safe[key], `Safe ${key}`);
  digest(safe.fixtureSha256, 'Safe fixture');
  requireThat(safe.fixtureSha256 === config.fixtureSha256, 'Safe fixture differs');
  requireThat(Array.isArray(safe.modules) && Array.isArray(safe.guards) && Array.isArray(safe.nestedOwners),
    'Explicit Safe modules/guards/nesting required');
  same(safe.modules, config.modules, 'Safe modules differ');
  same(safe.guards, config.guards, 'Safe guards differ');
  same(safe.nestedOwners, config.nestedOwners, 'Safe nesting differs');
  const call = evidence.invocation;
  const expectedRoute = scenario.id === 'owner-eoa' ? 'owner-eoa-call'
    : scenario.id === 'direct-safe-rejection' ? 'safe-call' : classification.route;
  requireThat(call && call.route === expectedRoute && call.operation === 0, 'Invocation route/operation differs');
  address(call.to, 'invocation target');
  requireThat(/^0x(?:[0-9a-fA-F]{2})*$/.test(call.data) && /^(0|[1-9][0-9]*)$/.test(call.value), 'Invalid call data/value');
  if (expectedRoute !== 'owner-eoa-call') {
    requireThat(/^(0|[1-9][0-9]*)$/.test(call.nonce) && /^0x[0-9a-fA-F]{64}$/.test(call.safeTxHash), 'Missing Safe nonce/hash');
  }
  requireThat(call.chainId === binding.chainId && call.caller === scenario.caller, 'Invocation caller/domain differs');
  if (expectedRoute === 'safe-call' || expectedRoute === 'owner-eoa-call') {
    requireThat(call.to.toLowerCase() === binding.address.toLowerCase(), 'Safe direct target differs');
    if (entry.selector) requireThat(call.data.slice(0, 10).toLowerCase() === entry.selector.toLowerCase(), 'Call selector differs');
  } else {
    requireThat(evidence.innerCall && evidence.innerCall.fqn === entry.fqn
      && evidence.innerCall.signature === entry.signature && evidence.innerCall.selector === entry.selector
      && evidence.innerCall.target.toLowerCase() === binding.address.toLowerCase(), 'Missing exact inner-call binding');
  }
  requireThat(evidence.outcome === scenario.outcome && evidence.innerOutcome === scenario.outcome,
    'Inner outcome differs; outer transaction status is insufficient');
  requireThat(Array.isArray(evidence.assertions), 'Missing actual assertions');
  for (const assertion of scenario.assertions) {
    const found = evidence.assertions.find(row => row.kind === assertion);
    requireThat(found && typeof found.description === 'string' && found.description.length > 0,
      `Missing exact assertion: ${assertion}`);
    sourceReferences(found.sourceRefs, input, 'assertion');
  }
  return 'covered-local-reviewed-test';
}

export function reconcile({ inventory, profile, claims, input, readFile = fs.readFileSync }) {
  requireThat(claims.schemaVersion === 1, 'Unknown claims schema');
  same(profile.capture, inventory.capture, 'Cross-source profile capture');
  same(claims.capture, inventory.capture, 'Cross-source claims capture');
  same(Object.fromEntries(Object.entries(input.sources).map(([name, source]) => [name, sha256(source.content)])),
    inventory.sourcePins, 'Reconciliation source inventory differs');
  const entries = unique(inventory.entries, 'id', 'inventory entries');
  const products = new Map(profile.products.map(product => [product.fqn, product]));
  function scopeFor(entry) {
    if (entry.kind === 'compiler-method') return 'compiler-alias';
    if (entry.kind === 'callback') return 'callback';
    const exposure = products.get(entry.fqn)?.safeExposure;
    if (!exposure) return 'unclassified-exposure';
    nonempty(exposure.rationale, 'Safe exposure rationale');
    requireThat(['supported-contract', 'implementation-only', 'externally-supported-library'].includes(exposure.classification),
      'Unknown Safe exposure classification');
    return exposure.classification === 'implementation-only' ? 'implementation-path' : 'primary-contract';
  }
  const scopes = new Map([...entries.values()].map(entry => [entry.id, scopeFor(entry)]));
  const classifications = unique(claims.classifications ?? [], 'entryId', 'classifications');
  const bindings = unique(claims.deploymentBindings ?? [], 'id', 'deployment bindings');
  const configurations = unique(profile.safeConfigurations ?? [], 'id', 'Safe configurations');
  requireThat(configurations.size > 0, 'Supported Safe configurations missing');
  for (const binding of bindings.values()) validateDeployment(binding, inventory);
  const scenarios = new Map();
  for (const [id, row] of classifications) {
    requireThat(entries.has(id), `Unknown/stale classified entry: ${id}`);
    requireThat(scopes.get(id) !== 'compiler-alias', 'Resolve compiler/ABI alias before classifying a call');
    scenarios.set(id, validateClassification(row, entries.get(id), input, scopes.get(id)));
  }
  const evidence = unique(claims.evidence ?? [], 'id', 'evidence');
  const accepted = new Map(); const candidates = [];
  for (const row of evidence.values()) {
    requireThat(entries.has(row.entryId), `Unknown/stale evidence entry: ${row.entryId}`);
    same(row.capture, inventory.capture, 'Cross-source evidence capture');
    requireThat(['mock-client', 'authored-only', 'source-reviewed', 'actual-safe-native'].includes(row.kind), 'Unknown evidence kind');
    if (row.kind !== 'actual-safe-native') {
      nonempty(row.qualification, 'candidate qualification');
      if (row.sourceRefs) sourceReferences(row.sourceRefs, input, 'candidate');
      candidates.push(JSON.parse(canonical(row)));
      continue;
    }
    const classification = classifications.get(row.entryId);
    const scenario = scenarios.get(row.entryId)?.get(row.scenarioId);
    const config = configurations.get(row.safeConfigurationId);
    const binding = bindings.get(row.deploymentId);
    requireThat(classification && scenario && config && binding, 'Unbound actual Safe evidence');
    const entry = entries.get(row.entryId);
    requireThat(scopes.get(entry.id) !== 'unclassified-exposure', 'Missing explicit Safe exposure classification');
    requireThat(binding.fqn === entry.fqn, 'Deployment FQN differs');
    const key = canonical([row.entryId, row.scenarioId, row.safeConfigurationId, row.deploymentId]);
    requireThat(!accepted.has(key), 'Duplicate evidence for scenario/configuration/deployment');
    const status = verifyNativeEvidence(row, { input, inventory, entry, classification, scenario, config, binding, readFile });
    accepted.set(key, { id: row.id, status });
  }
  const coverage = [];
  for (const entry of entries.values()) {
    const classification = classifications.get(entry.id);
    const relevantBindings = [...bindings.values()].filter(binding => binding.fqn === entry.fqn);
    const gaps = [];
    if (scopes.get(entry.id) === 'unclassified-exposure') gaps.push('missing-Safe-exposure-classification');
    if (!classification) gaps.push('missing-caller-classification');
    if (!relevantBindings.length) gaps.push('missing-deployment-binding');
    const obligations = [];
    if (classification) for (const scenario of scenarios.get(entry.id).values()) {
      for (const config of configurations.values()) {
        for (const binding of relevantBindings.length ? relevantBindings : [{ id: null }]) {
          const found = accepted.get(canonical([entry.id, scenario.id, config.id, binding.id]));
          obligations.push({ scenarioId: scenario.id, safeConfigurationId: config.id,
            deploymentId: binding.id, status: found?.status ?? 'uncovered', evidenceId: found?.id ?? null });
        }
      }
    }
    if (obligations.some(row => row.status === 'uncovered')) gaps.push('missing-exact-execution-evidence');
    coverage.push({ entryId: entry.id, scope: scopes.get(entry.id), callerClass: classification?.callerClass ?? null,
      classification: classification ?? null,
      route: classification?.route ?? null, status: gaps.length ? 'uncovered' : 'covered-local-reviewed-test', gaps, obligations });
  }
  const covered = coverage.filter(row => row.status === 'covered-local-reviewed-test').length;
  const coverageById = new Map(coverage.map(row => [row.entryId, row]));
  const primary = [...entries.values()].filter(entry => scopes.get(entry.id) === 'primary-contract');
  const callbacks = [...entries.values()].filter(entry => scopes.get(entry.id) === 'callback');
  const implementationEntries = [...entries.values()].filter(entry => scopes.get(entry.id) === 'implementation-path');
  const primaryFqns = [...products.values()].filter(product => ['supported-contract', 'externally-supported-library'].includes(product.safeExposure?.classification)).map(product => product.fqn);
  const implementationFqns = [...products.values()].filter(product => product.safeExposure?.classification === 'implementation-only').map(product => product.fqn);
  const primaryBacklog = primaryFqns.sort().map(fqn => ({ fqn,
    deploymentStatus: [...bindings.values()].some(binding => binding.fqn === fqn) ? 'explicit-bindings-only' : 'unresolved',
    entries: primary.filter(entry => entry.fqn === fqn).map(entry => ({ entryId: entry.id, kind: entry.kind,
      signature: entry.signature, selector: entry.selector, callerClass: coverageById.get(entry.id).callerClass,
      status: coverageById.get(entry.id).status })) }));
  const implementationBacklog = implementationFqns.sort().map(fqn => ({ fqn,
    requirement: 'Enclosing supported business workflow and applicable library call guard; no independent Safe transaction inferred.',
    entryIds: implementationEntries.filter(entry => entry.fqn === fqn).map(entry => entry.id),
    status: implementationEntries.some(entry => entry.fqn === fqn)
      && implementationEntries.filter(entry => entry.fqn === fqn).every(entry => coverageById.get(entry.id).status === 'covered-local-reviewed-test')
      ? 'covered-local-reviewed-test' : 'uncovered' }));
  const primaryFunctions = primary.filter(entry => entry.kind === 'function');
  // Full tuple-heavy ABIs already live in the authenticated compiler output.
  // Retain their exact hashes and every entry, without duplicating those bytes.
  const reportInventory = { ...inventory, products: inventory.products.map(({ abi, ...product }) => product) };
  return { schemaVersion: 1, profileSha256: sha256(canonical(profile)), inventory: reportInventory, coverage,
    primaryBacklog, implementationBacklog, callbackEntryIds: callbacks.map(entry => entry.id), candidateEvidence: candidates,
    summary: { machineRecords: entries.size, primaryContracts: primaryBacklog.length, primaryFunctions: primaryFunctions.length,
      primaryUncoveredFunctions: primaryFunctions.filter(entry => coverageById.get(entry.id).status !== 'covered-local-reviewed-test').length,
      receiveEntries: primary.filter(entry => entry.kind === 'receive').length, fallbackEntries: primary.filter(entry => entry.kind === 'fallback').length,
      callbackObligations: callbacks.length, implementationArtifacts: implementationBacklog.length,
      implementationAbiFunctions: implementationEntries.filter(entry => entry.kind === 'function').length,
      unresolvedCompilerAliasRecords: [...entries.values()].filter(entry => scopes.get(entry.id) === 'compiler-alias').length,
      unclassifiedExposureRecords: [...entries.values()].filter(entry => scopes.get(entry.id) === 'unclassified-exposure').length,
      classified: classifications.size, deploymentBindings: bindings.size,
      coveredLocalReviewed: covered, machineUncoveredRecords: entries.size - covered, actualEvidenceRecords: accepted.size,
      candidateEvidenceRecords: candidates.length, completeAcceptance: false },
    qualification: 'Offline identity reconciliation of explicit reviewed per-call claims. No semantic proof is inferred from test names, broad passes or mocks. Local reviewed execution is not deployed, all-configuration, gas, audit or release acceptance. Unresolved inventory, deployment and routing obligations remain gaps.' };
}

export function renderBacklog(report) {
  const s = report.summary;
  const lines = ['# Safe acceptance source backlog', '',
    `Frozen source: \`${report.inventory.capture.sourceCommit}\`. No deployed-instance or actual Safe acceptance is implied.`, '',
    `${s.primaryFunctions} functions across ${s.primaryContracts} explicitly supported contract surfaces; ${s.primaryUncoveredFunctions} lack complete scoped evidence.`,
    `${s.receiveEntries} receive, ${s.fallbackEntries} fallback and ${s.callbackObligations} callback obligations are separate.`, '',
    `${s.implementationArtifacts} implementation libraries (${s.implementationAbiFunctions} ABI functions) need enclosing-business-path and applicable-callguard evidence. They are not additional independent Safe transactions.`,
    `${s.unresolvedCompilerAliasRecords} unmatched compiler method records are unresolved representations, not additional supported functions.`, '',
    'Every row below remains source-scoped until exact deployed/test instances, callers, configurations and executions are bound. The complete per-function signatures and selectors are in the externally retained machine report; the compact summary pins its bytes.', '',
    '| Supported contract FQN | Functions | Uncovered functions | Receive/fallback |',
    '| --- | ---: | ---: | ---: |'];
  for (const contract of report.primaryBacklog) {
    const functions = contract.entries.filter(entry => entry.kind === 'function');
    lines.push(`| \`${contract.fqn}\` | ${functions.length} | ${functions.filter(entry => entry.status === 'uncovered').length} | ${contract.entries.length - functions.length} |`);
  }
  lines.push('', 'No classification, source-test candidate, mock or broad test pass counts as actual Safe execution. See [the tool guide](safe-acceptance.md) for regeneration and evidence requirements.', '');
  return lines.join('\n');
}

export function compactSummary(report, artifacts) {
  const unresolvedKinds = {};
  for (const row of report.inventory.unresolved) unresolvedKinds[row.kind] = (unresolvedKinds[row.kind] ?? 0) + 1;
  return { schemaVersion: 1, capture: report.inventory.capture, artifacts, summary: report.summary,
    roleCount: report.inventory.roles.length, planningInstances: report.inventory.deployments.length,
    unresolvedKinds, qualification: report.qualification,
    exposureQualification: 'Primary functions exclude implementation-only library ABI and unmatched compiler alias records. Library classification alone confers no workflow or callguard evidence.' };
}

export function runCli(argv) {
  const usage = 'Usage: node scripts/reconcile-safe-acceptance.mjs --input FILE --output FILE --profile FILE --claims FILE --genesis FILE --deployment FILE --report FILE [--summary FILE] [--backlog FILE] [--source-root DIR] [--check]';
  const args = {}; let check = false;
  const required = ['input', 'output', 'profile', 'claims', 'genesis', 'deployment', 'report'];
  const allowed = new Set([...required, 'source-root', 'summary', 'backlog']);
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === '--check') { requireThat(!check, usage); check = true; continue; }
    const name = argv[i].slice(2);
    requireThat(argv[i].startsWith('--') && allowed.has(name) && !args[name] && argv[i + 1], usage);
    args[name] = argv[++i];
  }
  requireThat(required.every(key => args[key]), usage);
  requireThat(required.filter(key => key !== 'report').every(key => path.resolve(args[key]) !== path.resolve(args.report)),
    'Report must not overwrite an input artifact');
  const inputPaths = required.filter(key => key !== 'report').map(key => path.resolve(args[key]));
  const outputPaths = ['report', 'summary', 'backlog'].filter(key => args[key]).map(key => path.resolve(args[key]));
  requireThat(new Set(outputPaths).size === outputPaths.length && outputPaths.every(file => !inputPaths.includes(file)),
    'Output artifacts must be distinct from inputs and each other');
  const json = file => JSON.parse(fs.readFileSync(file, 'utf8'));
  const profile = json(args.profile); const claims = json(args.claims);
  const { input, output } = authenticateCapture({ inputBytes: fs.readFileSync(args.input), outputBytes: fs.readFileSync(args.output), profile });
  if (args['source-root']) verifySourceTree({ input, root: args['source-root'] });
  for (const key of ['genesis', 'deployment']) {
    requireThat(profile.inputs?.[key]?.sha256 === sha256(fs.readFileSync(args[key])), `${key} inventory input hash differs`);
  }
  const inventory = buildInventory({ input, output, profile, genesis: json(args.genesis), deployment: json(args.deployment) });
  const report = reconcile({ inventory, profile, claims, input });
  const bytes = JSON.stringify(report, null, 2) + '\n';
  const artifacts = { profile: { fileName: path.basename(args.profile), sha256: sha256(fs.readFileSync(args.profile)) },
    report: { fileName: path.basename(args.report), sha256: sha256(bytes) } };
  const outputs = [[args.report, bytes]];
  if (args.summary) outputs.push([args.summary, JSON.stringify(compactSummary(report, artifacts), null, 2) + '\n']);
  if (args.backlog) outputs.push([args.backlog, renderBacklog(report)]);
  for (const [file, content] of outputs) {
    if (check) requireThat(fs.readFileSync(file, 'utf8') === content, 'Safe acceptance artifact drift: ' + file);
    else fs.writeFileSync(file, content, 'utf8');
  }
  console.log(JSON.stringify(report.summary));
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) {
  try { runCli(process.argv.slice(2)); }
  catch (error) { console.error(error.message); process.exitCode = 1; }
}
