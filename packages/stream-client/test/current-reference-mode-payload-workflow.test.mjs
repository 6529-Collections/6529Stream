import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { AbiCoder, Interface, ZeroAddress, ZeroHash, getAddress, id, keccak256 } from 'ethers';
import * as pure from '../dist/current-reference-mode-payload.js';
import * as environment from '../dist/current-reference-environment.js';
import * as flow from '../dist/current-reference-mode-payload-workflow.js';
import { createSafeCallPlan, verifySafeCallPlan } from '../dist/safe-plan.js';

const fixture = JSON.parse(readFileSync(new URL('./fixtures/current-reference-mode-payload-abi.json', import.meta.url), 'utf8'));
const abi = new Interface(Object.values(fixture.abis).flat()), coder = AbiCoder.defaultAbiCoder();
const A = n => getAddress('0x' + BigInt(n).toString(16).padStart(40, '0'));
const code = n => '0x60' + Number(n).toString(16).padStart(2, '0');
const pin = n => ({ address: A(n), codeHash: keccak256(code(n)) });
const host = A(1), store = A(2), preparer = A(3), uploader = A(4), recorder = A(5), chainId = 31337n;
const deployment = { chainId, publicationHost: pin(1), store: pin(2) };
const blockHash = n => id('block-' + n);
const deps = {
  targets: [A(10), A(11), A(12), store, A(14), A(15), A(16)],
  codeHashes: [10, 11, 12, 2, 14, 15, 16].map(n => pin(n).codeHash), chainId,
  rendererCatalogId: id('renderer'), rendererCatalogHash: id('renderer-document'), rendererCatalogBytes: 300n,
  readGas: 300000n, sourceGas: 4000000n, snapshotGas: 4000000n, archiveGas: 300000n
};
const bindings = { attestations: A(17), attestationsCodeHash: pin(17).codeHash, conservation: A(18), conservationCodeHash: pin(18).codeHash };
const fields = abi.getFunction('prepareModePayload').inputs;
function empty(type) {
  if (type.baseType === 'tuple') return Object.fromEntries(type.components.map(t => [t.name, empty(t)]));
  if (type.baseType === 'array') return type.arrayLength === -1 ? [] : Array.from({ length: type.arrayLength }, () => empty(type.arrayChildren));
  if (type.type === 'address') return ZeroAddress;
  if (type.type === 'bool') return false;
  if (type.type === 'string') return '';
  if (type.type === 'bytes') return '0x';
  if (type.type.startsWith('bytes')) return '0x' + '00'.repeat(Number(type.type.slice(5)));
  return 0n;
}
function sample({ mode = 1n, authorizationClass = 3n, grantRevision = 7n, modeBindings = bindings, note = 'original declaration' } = {}) {
  const e = {
    objectHash: id('environment-object'), coverageHash: id('environment-coverage'), manifestHash: ZeroHash, manifestBytes: 0n,
    engineName: 'Browser', engineVersion: '1', engineExecutableSha256: id('engine'), toolchainName: 'tool',
    toolchainVersion: '1', toolchainSha256: id('tool'), engineExecutablePath: 'engine.exe', toolchainPath: 'tool.exe',
    packageFiles: [{ path: 'engine.exe', byteSize: 100n, sha256Digest: id('engine') }, { path: 'tool.exe', byteSize: 80n, sha256Digest: id('tool') }],
    platformPrerequisites: [{ path: 'C:\\Windows\\system.dll', byteSize: 500n, sha256Digest: id('system') }], operatingSystem: 'Windows', operatingSystemVersion: 'Server', architecture: 'AMD64',
    viewportWidth: 1024n, viewportHeight: 768n, devicePixelRatio: 1n, colorSpace: 'srgb', softwareRasterization: true,
    captureProfile: environment.REFERENCE_ENVIRONMENT_CAPTURE_PROFILE, licenseNote: note
  };
  const raw = environment.referenceEnvironmentCanonicalBytes(e);
  e.manifestHash = keccak256(raw); e.manifestBytes = BigInt((raw.length - 2) / 2);
  const publication = empty(abi.getFunction('prepareModePublication').inputs[0]);
  Object.assign(publication, { collectionId: 7n, referenceId: id('reference'), snapshotRecordHash: id('snapshot'), snapshotRevision: 2n,
    environment: e, manifestURI: 'ipfs://mode-manifest', effectiveAt: 900n, reasonHash: id('reason') });
  publication.captures = [{ tokenId: 1n, collectionSerial: 1n, metadataJSONHash: id('metadata'), htmlHash: keccak256('0x1234'),
    htmlBytes: 2n, animationHTML: '0x1234', objectHash: id('capture'), coverageHash: id('capture-coverage'), sourceSha256: id('sha'),
    repeatCaptureSha256: [id('first'), id('second')], environmentManifestHash: e.manifestHash, capturedAt: 800n }];
  const evidence = empty(fields[3]); evidence.mode = mode;
  evidence.repeats = [{ objectHash: id('repeat'), coverageHash: id('repeat-coverage') }];
  const source = empty(fields[2]); source.subject = id('subject'); source.mintedEver = 1n; source.artistId = id('artist');
  source.snapshot.recordHash = publication.snapshotRecordHash; source.snapshot.revision = publication.snapshotRevision;
  const facts = empty(fields[4]); facts.mode = mode; facts.interpretationHash = id('interpretation');
  facts.evidenceHash = keccak256(coder.encode([fields[3]], [evidence]));
  const sourceHash = keccak256(coder.encode(['bytes32', 'uint256', 'address', 'address[7]', 'bytes32[7]', 'bytes32', 'bytes32',
    abi.getFunction('modeDependencies').outputs[0], fields[2], fields[4]],
  [id('6529STREAM_REFERENCE_MODE_SOURCES_V1'), chainId, host, deps.targets, deps.codeHashes,
    deps.rendererCatalogId, deps.rendererCatalogHash, modeBindings, source, facts]));
  const receipt = empty(fields[1]);
  Object.assign(receipt, { collectionId: 7n, referenceId: publication.referenceId, revision: 1n,
    sourcesHash: sourceHash, snapshotRecordHash: publication.snapshotRecordHash, snapshotRevision: 2n,
    recorder, authorizationClass, grantRevision, effectiveAt: 900n, reasonHash: publication.reasonHash,
    schemaHash: '0x402d40d87298b197ea58e46ca8cae1346a5391e991331874280fbc4cc039f857',
    profileHash: '0x666e39adf842bca06d06a63b2d92b363dad05e95bad2d0be7fe4ebc17d757f8c',
    canonicalizationHash: '0x88c5f5a1b04f40ebae17a2c6f85ba5cd88c32d9139a809f0a1b209afbe15e883' });
  const snapshot = pure.prepareReferenceModePayload(pure.prepareReferenceModePublication(chainId, host, { ...publication, expectedSourcesHash: sourceHash }),
    { receipt, source, evidence, facts });
  return { publication, evidence, sourceHash, snapshot, modeBindings };
}
function plan(data = sample()) { return flow.prepareReferenceModePayloadPlan(deployment, preparer, data.snapshot, { uploader }); }
function missing(method) {
  const error = new Error('Unknown retained bytes'); error.code = 'CALL_EXCEPTION';
  error.data = id(method === 'preparedModePublication' ? 'InvalidModeEvidence()' : 'InvalidSnapshotManifest()').slice(0, 10);
  throw error;
}
function provider(planned, options = {}) {
  const calls = [], estimates = [], headers = new Map(), snapshot = planned.snapshot;
  const state = (kind, tag) => typeof options[kind] === 'function' ? options[kind](tag) : Boolean(options[kind]);
  return {
    calls, estimates,
    async getNetwork() { options.mutate?.(); return { chainId: options.chainId ?? chainId }; },
    async getBlock(tag) {
      headers.set(tag, (headers.get(tag) ?? 0) + 1);
      return { number: tag, hash: options.reorg && headers.get(tag) > 1 ? id('reorg') : blockHash(tag), timestamp: 1000 + tag };
    },
    async getCode(target, tag) {
      const replaced = options.code?.(target, tag); if (replaced !== undefined) return replaced;
      const chunk = planned.chunks.findIndex((_, n) => target === A(100 + n));
      if (chunk >= 0) return '0x00' + planned.chunks[chunk].bytes.slice(2);
      if ([1, 2, 10, 11, 12, 14, 15, 16, 17, 18].some(n => target === A(n))) return code(Number(BigInt(target)));
      return '0x';
    },
    async call(tx) {
      calls.push(tx);
      const { name, args } = abi.parseTransaction({ data: tx.data }), tag = tx.blockTag;
      const override = options.read?.(name, args, tx);
      if (override?.raw !== undefined) return override.raw;
      if (override !== undefined) return abi.encodeFunctionResult(name, override);
      let out;
      switch (name) {
        case 'deploymentChainId': out = [chainId]; break;
        case 'dependencies': out = [deps]; break;
        case 'modeDependencies': out = [options.modeBindings ?? bindings]; break;
        case 'supportsInterface': out = [true]; break;
        case 'MAX_CHUNK_BYTES': out = [8192n]; break;
        case 'core': out = [A(10)]; break;
        case 'metadataHost': out = [A(11)]; break;
        case 'metadataRouter': out = [A(14)]; break;
        case 'snapshots': out = [A(15)]; break;
        case 'archiveCoverage': out = [A(16)]; break;
        case 'familyWriter': out = [args[2] === snapshot.input.receipt.authorizationClass, snapshot.input.receipt.grantRevision]; break;
        case 'previewModeReference': out = [snapshot.publication.publication.expectedSourcesHash, snapshot.canonical]; break;
        case 'preparedFileInventory':
          if (args[0] !== snapshot.publication.environment.environmentId || !state('environment', tag)) missing(name);
          out = [snapshot.publication.environment.canonical]; break;
        case 'preparedModePublication':
          if (args[0] !== snapshot.publication.publicationPreparationId || !state('publication', tag)) missing(name);
          out = [snapshot.publication.descriptor, snapshot.publication.canonical]; break;
        case 'preparedModePayload':
          if (args[0] !== snapshot.payloadPreparationId || !state('payload', tag)) missing(name);
          out = [snapshot.canonical]; break;
        case 'chunk': {
          const n = planned.chunks.findIndex(c => c.hash === args[0]);
          out = state('chunks', tag) && n >= 0 ? [A(100 + n), BigInt((planned.chunks[n].bytes.length - 2) / 2)] : [ZeroAddress, 0n];
          break;
        }
        case 'publishChunk': {
          const n = planned.chunks.findIndex(c => c.bytes === args[0]);
          out = [keccak256(args[0]), A(100 + n)]; break;
        }
        case 'prepareModePublication': out = [snapshot.publication.publicationPreparationId]; break;
        case 'prepareModePayload': out = [snapshot.payloadPreparationId]; break;
        default: throw Error('Unexpected call ' + name);
      }
      return abi.encodeFunctionResult(name, out);
    },
    async send(method, params) { estimates.push({ method, params }); return options.gas ?? '0x10000'; }
  };
}
const safeAbi = new Interface(['function execTransaction(address,uint256,bytes,uint8,uint256,uint256,uint256,address,address,bytes) returns(bool)']);
function mined(rpc, planned, index, { reused = false, safe = false, indexed = false } = {}) {
  const step = planned.steps[index], transactionHash = id('transaction'), tag = 11, bh = blockHash(tag);
  const specs = [];
  if (!reused) {
    if (step.kind === 'upload') specs.push([store, abi, 'ChunkPublished', [step.identity, A(100 + step.chunkIndex), BigInt((planned.chunks[step.chunkIndex].bytes.length - 2) / 2)]]);
    if (step.kind === 'publication') specs.push([host, abi, 'ReferenceModePublicationPrepared', [1n, step.identity, planned.snapshot.publication.descriptor]]);
    if (step.kind === 'payload') specs.push([host, abi, 'ReferenceModePayloadPrepared', [1n, step.identity, planned.snapshot.publication.publicationPreparationId, planned.snapshot.contentHash, planned.snapshot.byteLength]]);
  }
  const safeEvents = new Interface([`event ExecutionSuccess(bytes32 ${indexed ? 'indexed ' : ''}txHash,uint256 payment)`]);
  if (safe) specs.push([step.caller, safeEvents, 'ExecutionSuccess', [id('safe-hash'), 0n]]);
  const logs = specs.map(([address, iface, name, args], index) => ({ ...iface.encodeEventLog(iface.getEvent(name), args), address, index,
    blockNumber: tag, blockHash: bh, transactionHash, removed: false }));
  const tx = { hash: transactionHash, chainId, blockNumber: tag, blockHash: bh, from: safe ? A(99) : step.caller,
    to: safe ? step.caller : step.call.to, value: 0n, data: safe ? safeAbi.encodeFunctionData('execTransaction',
      [step.call.to, 0n, step.call.data, 0, 0, 0, 0, ZeroAddress, ZeroAddress, '0x']) : step.call.data };
  const receipt = { hash: transactionHash, from: tx.from, to: tx.to, status: 1, blockNumber: tag, blockHash: bh, logs };
  rpc.getTransaction = async () => tx; rpc.getTransactionReceipt = async () => receipt;
  return { transactionHash, tx, receipt };
}

test('original preview retains computed full publication and actual recorder while final publication stays a separate original call', async () => {
  for (const authorizationClass of [3n, 8n]) {
    const data = sample({ authorizationClass }), planned = plan(data), rpc = provider(planned);
    const out = await flow.captureReferenceModePreview(rpc, deployment, recorder, data.publication, data.evidence, { blockTag: 10 });
    assert.equal(out.submitted.publication.expectedSourcesHash, ZeroHash);
    assert.equal(out.snapshot.publication.publication.expectedSourcesHash, data.sourceHash);
    assert.equal(out.snapshot.input.receipt.recorder, recorder);
    assert.equal(out.authority.authorizationClass, authorizationClass);
    assert.equal(out.publicationSimulationRequired, true);
    const preview = abi.decodeFunctionData('previewModeReference', out.previewCall.data);
    const final = abi.decodeFunctionData('publishModeReference', out.publishCall.data);
    assert.equal(preview[2], recorder);
    assert.equal(final[0].expectedSourcesHash, data.sourceHash);
    assert.equal(final[0].environment.coverageHash, data.publication.environment.coverageHash);
    assert.equal(rpc.calls.at(-1).from, recorder);
    assert(Object.isFrozen(out.snapshot.input.source.snapshot));
  }
});

test('preview pins used native runtimes but merely retains unused perceptual Mode bindings', async () => {
  const unused = { attestations: ZeroAddress, attestationsCodeHash: ZeroHash, conservation: ZeroAddress, conservationCodeHash: ZeroHash };
  const data = sample({ modeBindings: unused }), planned = plan(data);
  const out = await flow.captureReferenceModePreview(provider(planned, { modeBindings: unused }), deployment, recorder, data.publication, data.evidence, { blockTag: 10 });
  assert.deepEqual(out.modeBindings, unused);
  const curated = sample({ mode: 2n }), cp = plan(curated);
  await flow.captureReferenceModePreview(provider(cp), deployment, recorder, curated.publication, curated.evidence, { blockTag: 10 });
  await assert.rejects(flow.captureReferenceModePreview(provider(cp, { code: a => a === A(17) ? '0x' : undefined }), deployment,
    recorder, curated.publication, curated.evidence, { blockTag: 10 }), /runtime/);
  for (const options of [
    { code: a => a === A(14) ? '0x6000' : undefined },
    { read: n => n === 'metadataHost' ? [A(99)] : undefined },
    { read: n => n === 'familyWriter' ? [false, 0n] : undefined },
    { read: n => n === 'supportsInterface' ? [false] : undefined }
  ]) await assert.rejects(flow.captureReferenceModePreview(provider(planned, options), deployment, recorder, data.publication, data.evidence, { blockTag: 10 }), /runtime|binding|authority|capability/);
  await assert.rejects(flow.captureReferenceModePreview(provider(planned), deployment, recorder, data.publication,
    { ...data.evidence, mode: 0n }, { blockTag: 10 }), /explicit supported Mode/);
});

test('preview rejects changed publication/evidence, recorder facts, source hash and noncanonical payload', async () => {
  const data = sample(), planned = plan(data);
  const changes = [
    p => { p.publication.publication.reasonHash = id('changed'); },
    p => { p.input.evidence.perceptual.reportURI = 'ipfs://changed'; },
    p => { p.input.receipt.recorder = A(99); },
    p => { p.input.receipt.authorizationClass = 8n; },
    p => { p.input.receipt.schemaHash = id('wrong-schema'); },
    p => { p.input.source.mintedEver++; }
  ];
  for (const change of changes) {
    const changed = structuredClone(data.snapshot); change(changed);
    const modified = pure.prepareReferenceModePayload(pure.prepareReferenceModePublication(chainId, host, changed.publication.publication), changed.input);
    await assert.rejects(flow.captureReferenceModePreview(provider(planned, { read: n => n === 'previewModeReference'
      ? [data.sourceHash, modified.canonical] : undefined }), deployment, recorder, data.publication, data.evidence, { blockTag: 10 }), /Preview/);
  }
  await assert.rejects(flow.captureReferenceModePreview(provider(planned, { read: n => n === 'previewModeReference'
    ? [data.sourceHash, data.snapshot.canonical + '00'] : undefined }), deployment, recorder, data.publication, data.evidence, { blockTag: 10 }), /canonical|length/i);
});

test('preview and preparation snapshot inputs before awaits, reject reorgs and preserve scalar types', async () => {
  const data = sample(), planned = plan(data), submitted = structuredClone(data.publication), ev = structuredClone(data.evidence), options = { blockTag: 10 };
  const out = await flow.captureReferenceModePreview(provider(planned, { mutate() {
    submitted.collectionId = 99n; ev.mode = 2n; options.blockTag = 99;
  } }), deployment, recorder, submitted, ev, options);
  assert.equal(out.submitted.publication.collectionId, 7n);
  assert.equal(out.submitted.evidence.mode, 1n);
  assert.equal(out.blockNumber, 10);
  await assert.rejects(flow.captureReferenceModePreview(provider(planned, { reorg: true }), deployment, recorder, data.publication, data.evidence, { blockTag: 10 }), /Pinned block/);
  const forged = structuredClone(planned); forged.steps[0].call.value = '0n';
  await assert.rejects(flow.inspectReferenceModePayloadPreparation(provider(planned), forged, { blockTag: 10 }), /canonical reconstruction/);
  const mutable = structuredClone(planned);
  const observed = await flow.inspectReferenceModePayloadPreparation(provider(planned, { mutate() { mutable.snapshot.input.receipt.recorder = A(90); } }), mutable, { blockTag: 10 });
  assert.equal(observed.plan.snapshot.input.receipt.recorder, recorder);
});

test('plans preserve separate permissionless callers, exact chunks, original stage identities and full fields', () => {
  const planned = plan(sample({ note: 'x'.repeat(16000) }));
  assert(planned.chunks.length > 3);
  assert(planned.chunks.every(c => (c.bytes.length - 2) / 2 <= 8192 && keccak256(c.bytes) === c.hash));
  assert.equal(new Set(planned.chunks.map(c => c.hash)).size, planned.chunks.length);
  assert(planned.steps.filter(s => s.kind === 'upload').every(s => s.caller === uploader && s.call.to === store));
  assert(planned.steps.slice(-2).every(s => s.caller === preparer && s.call.to === host && s.call.value === 0n));
  const publication = abi.decodeFunctionData('prepareModePublication', planned.steps.at(-2).call.data)[0];
  assert.equal(publication.environment.licenseNote, planned.snapshot.publication.publication.environment.licenseNote);
  const payload = abi.decodeFunctionData('prepareModePayload', planned.steps.at(-1).call.data);
  assert.equal(payload[0], planned.snapshot.publication.publicationPreparationId);
  assert.equal(payload[1].recorder, recorder);
});

test('generic Safe plans preserve original Store and Mode calls, order, callers and zero-value CALL operations', () => {
  const planned = plan(sample({ note: 'x'.repeat(16000) }));
  const catalogs = planned.steps.map(s => s.kind === 'upload' ? fixture.abis.store : fixture.abis.host);
  const review = createSafeCallPlan(chainId, 'Retain original Mode bytes', planned.steps.map((s, index) => ({
    safe: s.caller, intent: `Prepare ${s.kind} ${s.identity}`, call: s.call, abi: catalogs[index]
  })));
  assert.equal(review.steps.length, planned.steps.length);
  assert(review.steps.every((s, i) => s.safe === planned.steps[i].caller && s.transaction.operation === 0
    && s.transaction.value === '0' && s.transaction.data === planned.steps[i].call.data));
  assert(review.steps.at(-2).method.startsWith('prepareModePublication('));
  assert(review.steps.at(-1).method.startsWith('prepareModePayload('));
  assert.equal(verifySafeCallPlan(review, catalogs).hash, review.hash);
  const changed = structuredClone(review);
  changed.steps[0].transaction.operation = 1;
  assert.throws(() => verifySafeCallPlan(changed, catalogs), /Safe CALL/);
});

test('preparation readiness joins exact Environment, publication and payload without rechecking writer or source', async () => {
  const planned = plan();
  for (const [state, publicationReady, payloadReady] of [
    [{}, false, false], [{ environment: true }, false, false],
    [{ environment: true, chunks: true }, true, false],
    [{ environment: true, publication: true, chunks: true }, true, true]
  ]) {
    const out = await flow.inspectReferenceModePayloadPreparation(provider(planned, state), planned, { blockTag: 10 });
    assert.equal(['ready', 'complete'].includes(out.steps.at(-2).status), publicationReady);
    assert.equal(['ready', 'complete'].includes(out.steps.at(-1).status), payloadReady);
  }
  const rpc = provider(planned, { environment: true, publication: true, payload: true, read(n) {
    if (['familyWriter', 'previewModeReference', 'modeDependencies'].includes(n)) throw Error('Unexpected live admission');
  } });
  const complete = await flow.inspectReferenceModePayloadPreparation(rpc, planned, { blockTag: 10 });
  assert(complete.completed);
  assert.deepEqual(complete.retained, { environment: true, publication: true, payload: true });
  assert.equal(complete.chunkAvailability.length, 0);
  assert(complete.steps.slice(0, -2).every(s => s.status === 'unnecessary'));
  await flow.simulateReferenceModePayloadStep(rpc, planned, planned.steps.length - 1, { blockTag: 10 });
  for (const state of [{ publication: true }, { environment: true, payload: true }]) {
    await assert.rejects(flow.inspectReferenceModePayloadPreparation(provider(planned, state), planned, { blockTag: 10 }), /dependency is missing/);
  }
});

test('retained getters fail closed on wrong miss errors, descriptor bytes, missing prerequisites and changed chunk code', async () => {
  const planned = plan();
  const replacements = [
    n => n === 'preparedFileInventory' ? ['0x00'] : undefined,
    n => n === 'preparedModePublication' ? [{ ...planned.snapshot.publication.descriptor, environmentId: id('wrong') }, planned.snapshot.publication.canonical] : undefined,
    n => n === 'preparedModePayload' ? [planned.snapshot.canonical + '00'] : undefined,
    n => { if (n === 'preparedModePublication') missing('preparedFileInventory'); }
  ];
  for (const read of replacements) await assert.rejects(flow.inspectReferenceModePayloadPreparation(provider(planned, { read }), planned, { blockTag: 10 }), /Retained|Unknown/);
  await assert.rejects(flow.inspectReferenceModePayloadPreparation(provider(planned, { chunks: true,
    code: a => a === A(100) ? '0x01' + planned.chunks[0].bytes.slice(2) : undefined }), planned, { blockTag: 10 }), /STOP/);
  const delegated = '0xef0100' + A(222).slice(2);
  const changed = flow.prepareReferenceModePayloadPlan({ ...deployment, publicationHost: { address: host, codeHash: keccak256(delegated) } }, preparer, planned.snapshot);
  await assert.rejects(flow.inspectReferenceModePayloadPreparation(provider(changed, { code: a => a === host ? delegated : undefined }), changed, { blockTag: 10 }), /runtime/);
});

test('actual-caller simulation and pinned inner gas quote reject blocked, wrong-identity and pointer-swap responses', async () => {
  const planned = plan(), rpc = provider(planned, { environment: true, publication: true, chunks: true });
  const uploadIndex = planned.chunks.find(c => c.documents.includes('payload')).index;
  for (const index of [uploadIndex, planned.steps.length - 2, planned.steps.length - 1]) {
    const out = await flow.simulateReferenceModePayloadStep(rpc, planned, index, { blockTag: 10 });
    assert.equal(out.identity, planned.steps[index].identity);
    assert.equal(rpc.calls.at(-1).from, planned.steps[index].caller);
    const quote = await flow.quoteReferenceModePayloadStepGas(rpc, planned, index, { blockTag: 10, maximumGas: 65535n });
    assert.equal(quote.scope, 'inner-call'); assert.equal(quote.withinMaximum, false);
    assert.deepEqual(rpc.estimates.at(-1), { method: 'eth_estimateGas', params: [{ from: planned.steps[index].caller,
      to: planned.steps[index].call.to, data: planned.steps[index].call.data, value: '0x0' }, '0xa'] });
  }
  const blocked = provider(planned);
  await assert.rejects(flow.quoteReferenceModePayloadStepGas(blocked, planned, planned.steps.length - 1, { blockTag: 10 }), /blocked/);
  assert.equal(blocked.estimates.length, 0);
  for (const [method, response] of [['prepareModePayload', [id('wrong')]], ['publishChunk', [planned.chunks[uploadIndex].hash, A(250)]]]) {
    const bad = provider(planned, { environment: true, publication: true, chunks: true, read: n => n === method ? response : undefined });
    await assert.rejects(flow.quoteReferenceModePayloadStepGas(bad, planned, method === 'publishChunk' ? uploadIndex : planned.steps.length - 1, { blockTag: 10 }), /identity|pointer/);
    assert.equal(bad.estimates.length, 0);
  }
  await assert.rejects(flow.quoteReferenceModePayloadStepGas(provider(planned, { gas: '0x0100' }), planned, 0, { blockTag: 10 }), /quantity/);
});

test('direct and both Safe layouts prove first preparation and eventless retries for uploads and both stages', async () => {
  const planned = plan();
  for (const index of [0, planned.steps.length - 2, planned.steps.length - 1]) {
    for (const reused of [false, true]) for (const execution of ['direct', 'safe', 'indexed']) {
      const kind = planned.steps[index].kind;
      const rpc = provider(planned, { environment: true, publication: n => kind === 'payload' || reused || n === 11,
        payload: n => reused || n === 11, chunks: n => reused || n === 11 });
      const tx = mined(rpc, planned, index, { reused, safe: execution !== 'direct', indexed: execution === 'indexed' });
      const out = await flow.inspectReferenceModePayloadStepReceipt(rpc, planned, index,
        { transactionHash: tx.transactionHash, execution: execution === 'direct' ? 'direct' : 'safe' });
      assert.equal(out.retention, reused ? 'reused' : 'created');
      assert.equal(out.priorBlock.retained, reused);
      assert.equal(out.identity, planned.steps[index].identity);
      assert(Object.isFrozen(out.plan.snapshot.publication.environment.environment));
    }
  }
});

test('eventless stage receipts require prior-block related bytes and cannot borrow same-block retention', async () => {
  const planned = plan();
  for (const index of [0, planned.steps.length - 2, planned.steps.length - 1]) {
    const rpc = provider(planned, { environment: true, publication: n => n === 11, payload: n => n === 11, chunks: n => n === 11 });
    const tx = mined(rpc, planned, index, { reused: true });
    await assert.rejects(flow.inspectReferenceModePayloadStepReceipt(rpc, planned, index, { transactionHash: tx.transactionHash, execution: 'direct' }), /prior-block/);
    const prior = provider(planned, { environment: true, publication: true, payload: true, chunks: true });
    const first = mined(prior, planned, index);
    await assert.rejects(flow.inspectReferenceModePayloadStepReceipt(prior, planned, index, { transactionHash: first.transactionHash, execution: 'direct' }), /contradicts/);
  }
  const rpc = provider(planned, { environment: n => n === 11, publication: true, payload: true });
  const tx = mined(rpc, planned, planned.steps.length - 1, { reused: true });
  await assert.rejects(flow.inspectReferenceModePayloadStepReceipt(rpc, planned, planned.steps.length - 1,
    { transactionHash: tx.transactionHash, execution: 'direct' }), /Prior retained Mode prerequisite/);
});

test('receipt rejects wrong original arguments, noncanonical event, bad Safe order, changed historical pins and pointer drift', async () => {
  const planned = plan(), index = planned.steps.length - 1;
  const options = { environment: true, publication: true, payload: n => n === 11 };
  for (const mutate of [
    tx => { tx.tx.data += '00'; },
    tx => { tx.receipt.logs[0].data += '00'; },
    tx => { tx.receipt.logs[0].address = A(99); },
    tx => { tx.receipt.logs[0].topics[1] = '0x12'; }
  ]) {
    const rpc = provider(planned, options), tx = mined(rpc, planned, index); mutate(tx);
    await assert.rejects(flow.inspectReferenceModePayloadStepReceipt(rpc, planned, index, { transactionHash: tx.transactionHash, execution: 'direct' }), /CALL|Noncanonical|prior-block|bytes32/);
  }
  const safe = provider(planned, options), tx = mined(safe, planned, index, { safe: true });
  tx.receipt.logs.reverse().forEach((log, index) => { log.index = index; });
  await assert.rejects(flow.inspectReferenceModePayloadStepReceipt(safe, planned, index, { transactionHash: tx.transactionHash, execution: 'safe' }), /must follow/);
  const wrongPin = provider(planned, { ...options, code: (target, tag) => target === host && tag === 10 ? '0x00' : undefined });
  const pinnedTx = mined(wrongPin, planned, index);
  await assert.rejects(flow.inspectReferenceModePayloadStepReceipt(wrongPin, planned, index, { transactionHash: pinnedTx.transactionHash, execution: 'direct' }), /runtime/);
  const swap = provider(planned, { chunks: true, read: (n, args, tx) => n === 'chunk' && tx.blockTag === 10
    ? [A(250), BigInt((planned.chunks[0].bytes.length - 2) / 2)] : undefined,
    code: target => target === A(250) ? '0x00' + planned.chunks[0].bytes.slice(2) : undefined });
  const swapTx = mined(swap, planned, 0, { reused: true });
  await assert.rejects(flow.inspectReferenceModePayloadStepReceipt(swap, planned, 0, { transactionHash: swapTx.transactionHash, execution: 'direct' }), /pointer changed/);
});
