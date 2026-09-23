import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { AbiCoder, Interface, ZeroAddress, ZeroHash, getAddress, hexlify, id, keccak256, toUtf8Bytes } from 'ethers';
import * as pure from '../dist/current-museum-anchor-master.js';
import * as workflow from '../dist/current-museum-anchor-master-workflow.js';
import { createSafeCallPlan } from '../dist/safe-plan.js';
const fixture = JSON.parse(readFileSync(new URL('./fixtures/current-museum-anchor-master-abi.json', import.meta.url)));
const segments = ['core', 'metadata', 'master', 'conditionInterface', 'floorInterface', 'schemas', 'store', 'servingFacts', 'coverage', 'artistIngress', 'artistOwner', 'artistSuite', 'identity', 'binding', 'attribution', 'publication', 'artistPublication', 'executor'];
const fragments = new Map();
for (const segment of segments) for (const f of fixture.abis[segment] ?? []) {
  if (f.type === 'function' || f.type === 'event') fragments.set(new Interface([f]).fragments[0].format('sighash'), f);
}
const abi = new Interface([...fragments.values()]), coder = AbiCoder.defaultAbiCoder();
const code = '0x600060005260206000f3', codeHash = keccak256(code);
const a = n => getAddress(`0x${n.toString(16).padStart(40, '0')}`), pin = n => ({ address: a(n), codeHash });
const clone = structuredClone, utf8 = s => hexlify(toUtf8Bytes(s));
const FAMILY = { media: id('6529STREAM_RECORD_FAMILY_MEDIA_RELATIONSHIP_V1'), artist: id('6529STREAM_RECORD_FAMILY_ARTIST_V1'), conservation: id('6529STREAM_RECORD_FAMILY_CONSERVATION_V1') };
const safe = new Interface(['function execTransaction(address,uint256,bytes,uint8,uint256,uint256,uint256,address,address,bytes) returns(bool)',
  'event ExecutionSuccess(bytes32 txHash,uint256 payment)', 'event ExecutionFailure(bytes32 txHash,uint256 payment)']);
const indexedSafe = new Interface(['event ExecutionSuccess(bytes32 indexed txHash,uint256 payment)']);
function zero(t) {
  if (t.baseType === 'tuple') return Object.fromEntries(t.components.map(x => [x.name, zero(x)]));
  if (t.baseType === 'array') return t.arrayLength < 0 ? [] : Array.from({ length: t.arrayLength }, () => zero(t.arrayChildren));
  if (t.type === 'bool') return false;
  if (t.type === 'address') return ZeroAddress;
  if (t.type.startsWith('uint')) return 0n;
  if (t.type === 'string') return '';
  return t.type === 'bytes' ? '0x' : `0x${'00'.repeat(Number(t.type.slice(5)))}`;
}
// Exact compiler-ABI RPC fixtures prove client joins. Target/Governor calls are mocked;
// they do not establish native admission, nested gas forwarding, actual Safe acceptance or finality.
function setup(options = {}) {
  const d = { chainId: 1n, core: pin(1), executor: pin(2), metadata: pin(3), masterSelection: pin(4), schemaRegistry: pin(5),
    externalCoverage: pin(6), store: pin(7), artist: { registry: pin(8), coordinator: pin(9), identity: pin(10), binding: pin(11), attribution: pin(12) } };
  const anchor = { chainId: 1n, core: d.core, executor: d.executor }, candidate = pin(13);
  const c = { chainId: 1n, core: a(1), executor: a(2), metadata: a(3), masterSelection: a(4), schemaRegistry: a(5), externalCoverage: a(6) };
  const cid = 4n, caller = a(80), recorder = a(81), subjectId = pure.museumMasterCollectionSubject(1n, a(1), cid), manifestHash = id('manifest');
  const association = { artistId: id('artist'), bindingHash: id('binding'), generation: 2n, identityRecordHash: id('identity') };
  const manifest = { imageSourceType: options.sourceType ?? 7n, imageURI: 'https://display', imageHash: id('display'), imageMimeType: 'image/png',
    animationSourceType: 0n, animationURI: '', animationHash: ZeroHash, animationMimeType: '', contentSourceType: 0n, contentURI: '', contentHash: ZeroHash,
    contentMimeType: '', manifestURI: '', manifestHash: ZeroHash, alternatesURI: '', alternatesHash: ZeroHash };
  if (options.empty) { manifest.imageSourceType = 0n; manifest.imageURI = ''; manifest.imageHash = ZeroHash; }
  const mediaContext = { subjectId, manifestHash, inventoryHash: keccak256(coder.encode(['bytes32', abi.getFunction('mediaManifest').outputs[0]], [id('6529STREAM_MEDIA_MASTER_INVENTORY_V1'), manifest])), occupiedMask: options.empty ? 0n : 1n };
  const objectId = options.empty ? id('unused') : pure.museumMasterObjectId(c, cid, subjectId, manifestHash, 1n, manifest.imageHash);
  const master = { subjectId, selectedMediaManifestHash: manifestHash, mediaSlot: 1n, displayHash: options.empty ? id('unused') : manifest.imageHash,
    masterRole: 0n, masterObjectHash: id('master-object'), coverageHash: id('coverage'), predecessor: options.previous?.original.recordHash ?? ZeroHash };
  const waiver = { subjectId, artist: { artistId: association.artistId, bindingGeneration: association.generation, bindingHash: association.bindingHash },
    scopeSubjectId: subjectId, mediaObjects: [{ objectId, mediaClass: 0n, masterRoles: [1n, 0n] }],
    waiverStatement: { algorithm: 1n, canonicalizationId: id('RAW_BYTES'), digest: id('statement'), uri: 'ipfs://statement' }, reason: 'Original waiver', predecessor: master.predecessor };
  const isWaiver = !!options.waiver, witness = isWaiver ? waiver : master;
  const record = isWaiver ? pure.museumMasterWaiverRecord(waiver, 'ipfs://record', 700n) : pure.museumMasterRecord(master, 'ipfs://record', 700n);
  const author = options.publish && !isWaiver ? caller : recorder;
  const recordHash = pure.museumMasterRecordHash(c, author, cid, record), authorization = id('op24');
  const payload = isWaiver ? pure.museumMasterWaiverCanonical(waiver) : pure.museumMasterCanonical(master);
  const recordReceipt = { collectionId: cid, recorder: author, authorizationClass: isWaiver ? 1n : 6n, recordedAt: options.publish ? 1011n : 800n,
    recordIndex: options.recordIndex ?? 0n, recordChainHash: ZeroHash,
    schemaDefinitionHash: isWaiver ? pure.MUSEUM_MASTER_WAIVER_SCHEMA_HASH : pure.MUSEUM_MASTER_SCHEMA_HASH,
    canonicalizationDefinitionHash: pure.MUSEUM_MASTER_CANONICALIZATION_HASH, artistAuthorization: isWaiver ? authorization : ZeroHash };
  recordReceipt.recordChainHash = pure.museumMasterRecordChainHash(c, cid, record.recordType, recordReceipt.recordIndex ? id('prior-chain') : ZeroHash, recordHash, recordReceipt.recordIndex);
  const pub = pure.museumMasterPublication(c, author, cid, record), evidence = { attestationRecordHash: authorization,
    artistId: association.artistId, bindingHash: association.bindingHash, bindingGeneration: association.generation, signer: author,
    authorityClass: 1n, requiredCapability: 1n, signedAt: 750n, publicationHash: keccak256(pure.encodeMuseumMasterPublication(pub.publication)) };
  const publicationRecord = { publication: pub.publication, evidence, metadataHostCodeHash: codeHash };
  const emptySelection = zero(abi.getFunction('currentMaster').outputs[0]);
  const previous = options.previous ?? emptySelection;
  const docs = new Map(), chunks = new Map();
  for (const [path, row] of Object.entries(fixture.documents)) {
    if (path.includes('/examples/')) continue;
    const raw = utf8(row.text), contentHash = keccak256(raw), pointer = a(100 + chunks.size);
    const name = path.split('/').at(-1).replace('.json', '');
    docs.set(id(name), { raw, contentHash, pointer, kind: name === 'RFC8785_JCS' ? 1n : name.includes('PROFILE') ? 2n : 0n });
    chunks.set(contentHash, { raw, pointer });
  }
  chunks.set(payload.contentHash, { raw: payload.canonical, pointer: a(110) });
  const object = { artistId: association.artistId, schemaId: id('object-schema'), canonicalizationId: id('canon'), contentHash: id('master-bytes'),
    sha256Digest: id('sha'), arweaveDataRoot: id('root'), byteSize: 999n, formatId: id('format'), formatCatalogId: id('catalog'), formatCatalogHash: id('catalog-hash') };
  const coverage = { coverageHash: master.coverageHash, objectHash: master.masterObjectHash, artistId: association.artistId, contentHash: object.contentHash,
    sha256Digest: object.sha256Digest, arweaveDataRoot: object.arweaveDataRoot, byteSize: object.byteSize, firstFamilyRecordHash: id('f1'), secondFamilyRecordHash: id('f2'),
    firstReceiptHash: id('r1'), secondReceiptHash: id('r2'), firstFixityHash: id('x1'), secondFixityHash: id('x2'), checkpointHash: id('checkpoint'), profileHash: id('STREAM_EXTERNAL_ARTIFACT_COVERAGE_V1') };
  const state = { tierAt: Infinity, adoptedAt: Infinity, publishedAt: Infinity, scheduledAt: Infinity, executedAt: Infinity, consumedAt: options.publish ? Infinity : 0, expected: null, batch: null };
  const window = { notBefore: 173820n, expiresAfter: 778620n, reasonHash: id('reason'), reasonURI: 'ipfs://governance', manifestHash: id('system-manifest') };
  const calls = [], blockHash = n => id(`museum-block-${n}`), txHash = id('museum-tx'), safeTxHash = id('independently-verified-safe-tx');
  let transaction, mined;
  const provider = {
    getNetwork: async () => { options.network?.(); return { chainId: options.chainId ?? 1n }; },
    getBlock: async n => ({ number: n, hash: options.blockHash?.(n) ?? blockHash(n), timestamp: options.timestamp?.(n) ?? (n >= 20 ? Number(window.notBefore) + n - 20 : 1000 + n) }),
    getCode: async (address, tag) => options.code?.(address, tag) ?? (address === a(120) ? `0x00${coder.encode(['bytes[]'], [[state.batch.plan.call.data]]).slice(2)}`
      : [...chunks.values()].find(v => v.pointer === address) ? `0x00${[...chunks.values()].find(v => v.pointer === address).raw.slice(2)}` : code),
    call: async tx => {
      calls.push(tx);
      const parsed = abi.parseTransaction({ data: tx.data }), fn = parsed.name, args = parsed.args, tag = tx.blockTag;
      const injected = await options.read?.({ fn, args, tx, parsed, state });
      if (injected !== undefined) return typeof injected === 'string' ? injected : abi.encodeFunctionResult(parsed.fragment, injected);
      let result;
      if (fn === 'core') result = [a(1)];
      else if (['coreCodeHash', 'executorCodeHash', 'schemaRegistryCodeHash', 'chunkStoreCodeHash', 'artistRegistryCodeHash'].includes(fn)) result = [codeHash];
      else if (fn === 'governanceAuthority') result = [a(2)];
      else if (fn === 'metadata') result = [a(3)];
      else if (fn === 'schemaRegistry') result = [a(5)];
      else if (fn === 'chunkStore') result = [a(7)];
      else if (fn === 'externalCoverage') result = [a(6)];
      else if (fn === 'artistRegistry') result = [a(8)];
      else if (fn === 'operationCoordinator') result = [a(9)];
      else if (fn === 'deploymentChainId') result = [1n];
      else if (fn === 'supportsInterface') result = [true];
      else if (fn === 'sourceSetHead') result = [0n, id('empty-source-head')];
      else if (fn === 'profileHash') result = [pure.MUSEUM_MASTER_PROFILE_HASH];
      else if (fn === 'suiteConfiguration') result = [{ registry: a(8), archive: a(30), owners: [a(11), a(31), a(10), a(32), a(12), a(33), a(34)],
        core: a(1), mintManager: a(35), roleRegistry: a(36), metadata: a(3), primaryResolver: a(37), royaltyResolver: a(38), primaryRevenueClass: id('revenue'), validator: a(39) }];
      else if (fn === 'collectionExists') result = [!options.unknown];
      else if (fn === 'collectionMintedEver') result = [options.minted ?? 0n];
      else if (fn === 'declaredConservationTier') result = [tag >= state.tierAt ? pure.MUSEUM_GRADE : options.declared ?? ZeroHash];
      else if (fn === 'conditionSources' || fn === 'conservationFloor') result = tag >= state.executedAt ? [candidate.address, codeHash] : [ZeroAddress, ZeroHash];
      else if (fn.endsWith('Transition')) {
        const plan = pure.prepareMuseumAnchorBinding({ chainId: 1n, core: a(1), executor: a(2) }, { kind: fn.replace('Transition', ''), candidate: candidate.address, runtimeCodeHash: codeHash, previous: { target: ZeroAddress, runtimeCodeHash: ZeroHash } });
        result = Object.values(plan.transition);
      } else if (fn === 'getSatellitePointer') {
        const target = args[0] === id('COLLECTION_METADATA') ? a(3) : args[0] === id('ARTIST_REGISTRY') ? a(8) : a(14);
        result = [target, codeHash, false, args[0], '0x12345678', a(15), 1n, id('module'), id('deployment'), 1n];
      } else if (fn === 'gasParameter') result = [1000000n];
      else if (fn === 'gasParameterInfo') result = [1000000n, 500000n, 2n, 1n];
      else if (fn === 'familyWriter') result = [args[1] === FAMILY.conservation ? args[2] === 7n && args[0] === cid : args[1] === FAMILY.media && args[2] === 6n, 1n];
      else if (fn === 'recordPolicy') result = [{ family: args[0] === id('ARTIST_STATEMENT') ? FAMILY.artist : FAMILY.media, authorizationMask: args[0] === id('ARTIST_STATEMENT') ? 2n : 192n, admitted: true }];
      else if (fn === 'documentFacts') {
        const v = docs.get(args[0]);
        result = [{ exists: true, kind: v.kind, status: 0n, contentHash: v.contentHash, canonicalizationId: id('RAW_BYTES'), supersedesId: ZeroHash,
          totalBytes: BigInt((v.raw.length - 2) / 2), chunkCount: 1n, declarationHash: id('declaration') }];
      } else if (fn === 'documentChunkHashAt') result = [docs.get(args[0]).contentHash];
      else if (fn === 'chunk') { const v = chunks.get(args[0]); result = [v.pointer, BigInt((v.raw.length - 2) / 2)]; }
      else if (fn === 'readChunk') result = [chunks.get(args[0]).raw];
      else if (fn === 'mediaManifestHash') result = [manifestHash];
      else if (fn === 'mediaManifest') result = [manifest];
      else if (fn === 'collectionServingSource') result = [{ name: 'Collection', description: '', imageURI: manifest.imageURI, animationBaseURI: '', script: '' }];
      else if (fn === 'collectionMediaContext') result = Object.values(mediaContext);
      else if (fn === 'binding') result = options.platform ? [zero(abi.getFunction(fn).outputs[0])] : [{ artistId: association.artistId, artistAddress: recorder, identityRecordHash: association.identityRecordHash,
        bindingHash: association.bindingHash, generation: association.generation, consentMode: 1n, saleConsentScope: 0n, registryImmutabilityElection: 0n, proposer: a(82), accepted: true }];
      else if (fn === 'attributionState') result = [2n, 2n];
      else if (fn === 'authorityState') result = [recorder, 1n, 1n, association.identityRecordHash];
      else if (fn === 'collectionRecord') result = [record, recordReceipt];
      else if (fn === 'collectionRecordReceipt') result = [args[0] === recordHash ? recordReceipt : { ...recordReceipt, recordIndex: recordReceipt.recordIndex - 1n, recordChainHash: id('prior-chain') }];
      else if (fn === 'recordHashAt') result = [args[2] === recordReceipt.recordIndex ? recordHash : id('prior-record')];
      else if (fn === 'consumedArtistAuthorization') result = [tag >= state.consumedAt];
      else if (fn === 'publicationAttestation') result = [publicationRecord];
      else if (fn === 'attestationRecord') result = [{ recordHash: authorization, subjectStateHash: ZeroHash, schemaId: id('6529STREAM_ARTIST_RECORD_PUBLICATION_V1'),
        statementHash: pub.statementHash, generation: evidence.bindingGeneration, signedAt: evidence.signedAt, signer: author }];
      else if (fn === 'statementBytes') result = [pub.statement];
      else if (fn === 'requireRecordPublication') { assert.equal(tx.from, a(3)); result = [evidence]; }
      else if (fn === 'currentMaster') result = [tag >= state.adoptedAt ? state.expected : previous];
      else if (fn === 'masterSelectionAt') result = [state.expected];
      else if (fn === 'objectIdentity') result = [object];
      else if (fn === 'requireCoverage') result = [coverage];
      else if (fn === 'adoptMaster' || fn === 'adoptWaiver') result = [state.expected];
      else if (fn === 'declareConservationTier') result = [];
      else if (fn === 'recordCollectionRecordWithPayload' || fn === 'recordArtistCollectionRecordWithPayload') result = [recordHash];
      else if (fn === 'requireCollectionMasters') result = [state.closureHash];
      else if (fn === 'systemManifestBootstrapState') { result = abi.getFunction(fn).outputs.map(zero); result[0] = true; result[1] = true; }
      else if (fn === 'minimumDelay') result = [172800n];
      else if (fn === 'governanceNonce') result = [tag >= state.scheduledAt ? 2n : 1n];
      else if (fn === 'governanceActionPolicyState') result = [id('profile'), id('catalog'), 12n, 0n];
      else if (fn === 'owner') result = [caller];
      else if (fn === 'isProposer') result = [args[0] === caller];
      else if (fn === 'publishedCallData') result = [tag >= state.publishedAt ? a(120) : ZeroAddress];
      else if (fn === 'publishGovernanceCallData') result = [a(120)];
      else if (fn === 'scheduleGovernanceBatch') result = [state.batch.actionId];
      else if (fn === 'executeGovernanceBatch') result = [];
      else if (fn === 'scheduledCallData') result = [[state.batch.plan.call.data]];
      else if (fn === 'scheduledCallDataPointer') result = [a(120)];
      else if (fn === 'governanceAction') {
        const b = state.batch;
        result = [{ status: tag >= state.executedAt ? 3n : 1n, actionClass: 1n, target: a(1), value: 0n, selector: b.plan.governanceCall.selector,
          callHash: b.callsHash, scopeHash: b.scopeHash, oldValueHash: b.oldValueHash, newValueHash: b.newValueHash, notBefore: window.notBefore,
          expiresAfter: window.expiresAfter, proposer: caller, executor: tag >= state.executedAt ? caller : ZeroAddress, canceller: ZeroAddress, vetoer: ZeroAddress,
          reasonHash: window.reasonHash, reasonURI: window.reasonURI, manifestHash: window.manifestHash }];
      } else throw Error(`Missing RPC ${fn}`);
      return abi.encodeFunctionResult(parsed.fragment, result);
    },
    getTransaction: async () => transaction,
    getTransactionReceipt: async () => mined,
  };
  function prepare(kind = options.publish ? (isWaiver ? 'recordArtistCollectionRecordWithPayload' : 'recordCollectionRecordWithPayload') : isWaiver ? 'adoptWaiver' : 'adoptMaster') {
    const request = kind === 'declareConservationTier' ? { kind, collectionId: cid, tier: pure.MUSEUM_GRADE }
      : options.publish ? { kind, collectionId: cid, record, witness, ...(isWaiver ? { recorder: author, authorization } : {}) }
      : { kind, collectionId: cid, recordHash, expectedRevision: previous.revision, original: record, witness, ...(isWaiver ? { slot: 1n, manifestHash } : {}) };
    return pure.prepareMuseumAnchorMasterCall(c, caller, request);
  }
  async function capture(kind) {
    const cap = await workflow.captureMuseumAnchorMaster(provider, d, prepare(kind), { blockTag: 10 });
    state.expected = cap.expectedSelection;
    return cap;
  }
  function event(name, target, args, iface = abi) { const e = iface.encodeEventLog(iface.getEvent(name), args); return { address: target, topics: e.topics, data: e.data }; }
  function install(call, actor, rows, tag = 11, transport = 'direct', indexed = false) {
    if (transport === 'safe') rows.push(event('ExecutionSuccess', actor, [safeTxHash, 0n], indexed ? indexedSafe : safe));
    const data = transport === 'safe' ? safe.encodeFunctionData('execTransaction', [call.to, 0n, call.data, 0n, 0n, 0n, 0n, ZeroAddress, ZeroAddress, '0x']) : call.data;
    transaction = { hash: txHash, chainId: 1n, to: transport === 'safe' ? actor : call.to, from: transport === 'safe' ? a(90) : actor,
      value: 0n, data, blockNumber: tag, blockHash: blockHash(tag) };
    mined = { hash: txHash, status: 1, to: transaction.to, from: transaction.from, blockNumber: tag, blockHash: blockHash(tag), logs: rows };
    reindex();
    return { transaction, mined, options: transport === 'safe' ? { transactionHash: txHash, execution: 'safe', expectedSafeTxHash: safeTxHash } : { transactionHash: txHash, execution: 'direct' } };
  }
  function reindex() { mined.logs.forEach((l, index) => Object.assign(l, { index, blockNumber: mined.blockNumber, blockHash: mined.blockHash, transactionHash: txHash, removed: false })); }
  function installMaster(cap, transport = 'direct', indexed = false) {
    const r = cap.prepared.request;
    let rows;
    if (r.kind === 'declareConservationTier') {
      state.tierAt = 11;
      rows = [event('ConservationTierRecorded', a(1), [1n, cid, r.tier, a(3)]), event('CollectionConservationTierDeclared', a(3), [cid, r.tier, 1n])];
    } else if (options.publish) {
      state.consumedAt = 11;
      rows = [event('CollectionRecordRecorded', a(3), [cid, record.recordType, subjectId, record, recordHash, recordReceipt.recordChainHash, author,
        `0x${recordReceipt.authorizationClass.toString(16).padStart(64, '0')}`, 1n])];
      if (isWaiver) rows.push(event('ArtistRecordAuthorizationConsumed', a(3), [authorization, recordHash, author, caller]));
    } else {
      state.adoptedAt = 11;
      rows = [event('MediaMasterSelected', a(4), [cid, subjectId, 1n, cap.expectedSelection])];
    }
    return install(cap.prepared.call, caller, rows, 11, transport, indexed);
  }
  async function anchorCapture(kind = 'conditionSources') {
    const cap = await workflow.captureMuseumAnchorBinding(provider, anchor, kind, candidate, { blockTag: 10 });
    const prepared = workflow.prepareMuseumAnchorGovernance(cap, caller, window);
    state.batch = prepared.batch;
    return { cap, prepared, operation: stage => workflow.prepareMuseumAnchorGovernanceOperation(prepared, stage, caller) };
  }
  function installGov(op, transport = 'direct', indexed = false, retry = false) {
    const b = op.prepared.batch, kind = op.prepared.capture.kind;
    const common = [1n, b.actionId, 1n, a(1), 0n, b.plan.governanceCall.selector, b.callsHash, b.scopeHash, b.oldValueHash, b.newValueHash];
    let rows, tag = 11;
    if (op.stage === 'publish') { state.publishedAt = retry ? 11 : 12; tag = 12; rows = retry ? [] : [event('GovernanceCallDataPublished', a(2), [1n, b.publicationKey, a(120), caller])]; }
    else if (op.stage === 'schedule') {
      state.publishedAt = 11; state.scheduledAt = 12; tag = 12;
      rows = [event('GovernanceActionScheduled', a(2), [...common, window.notBefore, window.expiresAfter, b.nonce, caller, window.reasonHash, window.reasonURI, window.manifestHash]),
        event('GovernanceActionPolicyValidated', a(2), [1n, b.actionId, 1n, id('profile'), id('catalog')])];
    } else {
      state.publishedAt = 11; state.scheduledAt = 12; state.executedAt = 20; tag = 20;
      rows = [event(kind === 'conditionSources' ? 'ConditionSourcesBound' : 'ConservationFloorBound', a(1), [1n, candidate.address, codeHash, b.actionId]),
        event('GovernanceActionExecuted', a(2), [...common, caller, window.manifestHash]), event('GovernanceActionPolicyValidated', a(2), [1n, b.actionId, 2n, id('profile'), id('catalog')])];
    }
    return install(op.call, caller, rows, tag, transport, indexed);
  }
  return { d, anchor, candidate, c, cid, caller, recorder, record, recordHash, recordReceipt, publicationRecord, pub, evidence, authorization, payload,
    master, waiver, previous, association, manifest, mediaContext, object, coverage, chunks, state, calls, options, provider,
    capture, prepare, anchorCapture, installMaster, installGov, install, event, reindex, safeTxHash, txHash };
}
test('permanent condition/floor capture binds exact transition, empty nonzero source head, independent class1 governance', async () => {
  for (const kind of ['conditionSources', 'conservationFloor']) {
    const s = setup(), { cap, operation } = await s.anchorCapture(kind);
    assert.equal(cap.sourceHead.count, 0n);
    assert.notEqual(cap.sourceHead.head, ZeroHash);
    assert.equal(cap.plan.actionClass, 1n);
    await workflow.simulateMuseumAnchorGovernance(s.provider, operation('publish'), { blockTag: 11 });
    s.state.publishedAt = 11;
    await workflow.simulateMuseumAnchorGovernance(s.provider, operation('schedule'), { blockTag: 12 });
    s.state.scheduledAt = 12;
    await workflow.simulateMuseumAnchorGovernance(s.provider, operation('execute'), { blockTag: 20 });
    assert.ok(Object.isFrozen(cap));
  }
});
test('anchor rejects runtime/interface/chain/source/transition contradictions and permanent rebinding', async () => {
  const cases = [
    ({ fn }) => fn === 'supportsInterface' ? [false] : undefined,
    ({ fn }) => fn === 'deploymentChainId' ? [2n] : undefined,
    ({ fn }) => fn === 'coreCodeHash' ? [id('wrong')] : undefined,
    ({ fn }) => fn === 'sourceSetHead' ? [0n, ZeroHash] : undefined,
    ({ fn }) => fn === 'conditionSourcesTransition' ? [id('wrong'), id('wrong'), id('wrong')] : undefined,
    ({ fn }) => fn === 'conditionSources' ? [a(13), codeHash] : undefined,
  ];
  for (const read of cases) await assert.rejects(setup({ read }).anchorCapture());
  await assert.rejects(setup({ code: (address) => address === a(13) ? `0xef0100${'11'.repeat(20)}` : undefined }).anchorCapture(), /runtime/);
});
test('raw tier distinguishes unknown, pre-mint undeclared, completed-mint default and explicit waived', async () => {
  for (const [options, exists, effective] of [[{ unknown: true }, false, ZeroHash], [{}, true, ZeroHash], [{ minted: 7n }, true, pure.MUSEUM_GRADE_LITE], [{ declared: pure.MUSEUM_CONSERVATION_WAIVED }, true, pure.MUSEUM_CONSERVATION_WAIVED]]) {
    const s = setup(options), r = await workflow.readMuseumConservationTier(s.provider, s.anchor, s.cid, { blockTag: 10 });
    assert.equal(r.exists, exists); assert.equal(r.effective, effective);
  }
});
test('tier needs exact CONSERVATION7 collection or global8 grant, selected Metadata, zero completed mints', async () => {
  const s = setup(), cap = await s.capture('declareConservationTier');
  await workflow.simulateMuseumAnchorMaster(s.provider, cap, { blockTag: 10 });
  const global = setup({ read: ({ fn, args }) => fn === 'familyWriter' ? [args[1] === FAMILY.conservation && args[0] === 0n && args[2] === 8n, 3n] : undefined });
  await global.capture('declareConservationTier');
  for (const options of [{ minted: 1n }, { declared: pure.MUSEUM_GRADE_LITE }, { unknown: true },
    { read: ({ fn }) => fn === 'familyWriter' ? [false, 0n] : undefined },
    { read: ({ fn, args }) => fn === 'getSatellitePointer' ? [a(99), codeHash, false, args[0], '0x12345678', a(15), 1n, id('m'), id('d'), 1n] : undefined }]) {
    await assert.rejects(setup(options).capture('declareConservationTier'));
  }
});
test('native master capture joins flat pointer/context, original MEDIA6 receipt and source kinds6/7/8', async () => {
  for (const sourceType of [6n, 7n, 8n]) {
    const s = setup({ sourceType }), cap = await s.capture();
    assert.equal(cap.expectedSelection.status, 1n);
    assert.equal(cap.expectedSelection.objectId, pure.museumMasterObjectId(s.c, s.cid, s.master.subjectId, s.master.selectedMediaManifestHash, 1n, s.master.displayHash));
    await workflow.simulateMuseumAnchorMaster(s.provider, cap, { blockTag: 10 });
  }
});
test('waiver joins principal original op24 publication, full saved Record hash and ordered first role', async () => {
  const s = setup({ waiver: true }), cap = await s.capture();
  const expected = keccak256(coder.encode([abi.getFunction('publicationAttestation').outputs[0]], [s.publicationRecord]));
  assert.equal(cap.original.evidence.publicationEvidenceHash, expected);
  assert.notEqual(expected, keccak256(pure.encodeMuseumMasterPublicationEvidence(s.evidence)));
  assert.equal(cap.expectedSelection.masterRole, 1n);
  assert.equal(cap.expectedSelection.status, 2n);
  await workflow.simulateMuseumAnchorMaster(s.provider, cap, { blockTag: 10 });
});
test('publication distinguishes actual MEDIA writer from principal waiver recorder and exact live op24 caller', async () => {
  for (const waiver of [false, true]) {
    const s = setup({ publish: true, waiver }), cap = await s.capture();
    await workflow.simulateMuseumAnchorMaster(s.provider, cap, { blockTag: 10 });
    assert.equal(cap.authorizationClass, waiver ? 1n : 6n);
    if (waiver) assert.notEqual(cap.prepared.caller, cap.prepared.request.recorder);
    const tx = s.installMaster(cap, 'safe', waiver);
    const r = await workflow.inspectMuseumAnchorMasterReceipt(s.provider, cap, tx.options);
    assert.equal(r.original.receipt.recorder, waiver ? s.recorder : s.caller);
    assert.equal(r.events.at(-1).event, 'ExecutionSuccess');
  }
});
test('retained JSON, schemas, original record lane, publication and coverage contradictions fail closed', async () => {
  for (const read of [
    ({ fn }) => fn === 'recordPolicy' ? [{ family: id('MEDIA'), authorizationMask: 192n, admitted: true }] : undefined,
    ({ fn }) => fn === 'recordHashAt' ? [id('wrong')] : undefined,
    ({ fn }) => fn === 'readChunk' ? ['0x01'] : undefined,
    ({ fn }) => fn === 'collectionMediaContext' ? [id('wrong'), id('manifest'), id('inventory'), 1n] : undefined,
  ]) await assert.rejects(setup({ read }).capture());
  const s = setup({ waiver: true });
  s.options.read = ({ fn }) => fn === 'publicationAttestation' ? [{ ...s.publicationRecord, evidence: { ...s.evidence, authorityClass: 2n } }] : undefined;
  await assert.rejects(s.capture(), /class1/);
  const t = setup();
  t.options.read = ({ fn }) => fn === 'objectIdentity' ? [{ ...t.object, contentHash: t.master.displayHash }] : undefined;
  await assert.rejects(t.capture(), /object/);
});
test('cross-status lower record index is allowed, but same-status or earlier timestamps regress', async () => {
  const first = setup(), old = (await first.capture()).expectedSelection;
  const prior = { ...old, original: { ...old.original, recordIndex: 20n, recordedAt: 790n } };
  prior.selectionHash = pure.museumMasterSelectionHash(first.c, first.cid, prior);
  const s = setup({ waiver: true, previous: prior }), cap = await s.capture();
  assert.equal(cap.expectedSelection.original.recordIndex, 0n);
  assert.equal(cap.expectedSelection.revision, 2n);
  await assert.rejects(setup({ previous: prior }).capture(), /lineage/);
  const future = { ...prior, original: { ...prior.original, recordedAt: 801n } };
  future.selectionHash = pure.museumMasterSelectionHash(first.c, first.cid, future);
  await assert.rejects(setup({ waiver: true, previous: future }).capture(), /lineage/);
});
test('empty explicit native denominator is valid, including platform association, with exact original closure hash', async () => {
  const s = setup({ empty: true, platform: true });
  const association = { artistId: ZeroHash, bindingHash: ZeroHash, generation: 0n, identityRecordHash: ZeroHash };
  s.state.closureHash = pure.museumMasterFactsHash(s.c, s.cid, s.mediaContext, [ZeroHash, ZeroHash, ZeroHash], association);
  const r = await workflow.requireMuseumCollectionMasters(s.provider, s.d, s.cid, { blockTag: 10 });
  assert.equal(r.factsHash, s.state.closureHash); assert.deepEqual(r.selections, []);
  assert.ok(!s.calls.some(x => ['documentFacts', 'requireCoverage'].includes(abi.parseTransaction({ data: x.data }).name)));
});
test('current closure rechecks original coverage while historical getters survive all current dependency changes', async () => {
  const s = setup(), cap = await s.capture();
  s.state.adoptedAt = 11;
  const archiveHash = keccak256(coder.encode([abi.getFunction('objectIdentity').outputs[0], abi.getFunction('requireCoverage').outputs[0]], [s.object, s.coverage]));
  s.state.closureHash = pure.museumMasterAppendFactsHash(pure.museumMasterFactsHash(s.c, s.cid, s.mediaContext, [s.master.displayHash, ZeroHash, ZeroHash], s.association), 1n, cap.expectedSelection.selectionHash, archiveHash);
  await workflow.requireMuseumCollectionMasters(s.provider, s.d, s.cid, { blockTag: 11 });
  s.options.read = ({ fn }) => { if (['documentFacts', 'binding', 'requireCoverage', 'mediaManifest'].includes(fn)) throw Error('current state changed'); };
  const historical = await workflow.readMuseumMasterSelection(s.provider, s.d, { collectionId: s.cid, subjectId: s.master.subjectId, slot: 1n, revision: 1n }, { blockTag: 12 });
  assert.deepEqual(historical.selection, cap.expectedSelection);
  await assert.rejects(workflow.requireMuseumCollectionMasters(s.provider, s.d, s.cid, { blockTag: 12 }), /current state changed/);
});
test('tier and adoption exact direct/Safe receipts preserve historical selection despite later current changes', async () => {
  for (const [kind, transport, indexed] of [['declareConservationTier', 'safe', false], [undefined, 'safe', true], [undefined, 'direct', false]]) {
    const s = setup(), cap = await s.capture(kind), tx = s.installMaster(cap, transport, indexed);
    if (!kind) s.options.read = ({ fn, tx }) => {
      if (tx.blockTag > 10 && ['currentMaster', 'binding', 'mediaManifest', 'requireCoverage', 'documentFacts'].includes(fn)) throw Error('later state');
    };
    const r = await workflow.inspectMuseumAnchorMasterReceipt(s.provider, cap, tx.options);
    assert.equal(r.transactionHash, s.txHash);
    if (!kind) assert.deepEqual(r.selection, cap.expectedSelection);
  }
});
test('shared Safe verifier binds independent hash, exact ordinary CALL, target success and source event ordering', async () => {
  for (const mode of ['hash', 'delegatecall', 'value', 'substitution', 'failure', 'early']) {
    const s = setup(), cap = await s.capture(), tx = s.installMaster(cap, 'safe');
    if (mode === 'hash') tx.options.expectedSafeTxHash = id('wrong-independent-hash');
    if (['delegatecall', 'value', 'substitution'].includes(mode)) {
      const args = Array.from(safe.decodeFunctionData('execTransaction', tx.transaction.data));
      if (mode === 'delegatecall') args[3] = 1n;
      else if (mode === 'value') args[1] = 1n;
      else args[2] = '0x12345678';
      tx.transaction.data = safe.encodeFunctionData('execTransaction', args);
    }
    if (mode === 'failure') tx.mined.logs.at(-1).topics = safe.encodeEventLog(safe.getEvent('ExecutionFailure'), [s.safeTxHash, 0n]).topics;
    if (mode === 'early') { tx.mined.logs.unshift(tx.mined.logs.pop()); s.reindex(); }
    await assert.rejects(workflow.inspectMuseumAnchorMasterReceipt(s.provider, cap, tx.options));
  }
});
test('Safe verifier uses copied logs even when provider-owned receipt mutates during historical readback', async () => {
  const s = setup(), cap = await s.capture(), tx = s.installMaster(cap, 'safe');
  const success = tx.mined.logs.at(-1), wrong = id('wrong-in-copied-receipt');
  success.data = safe.encodeEventLog(safe.getEvent('ExecutionSuccess'), [wrong, 0n]).data;
  s.options.read = ({ fn, tx: call }) => {
    if (call.blockTag === 11 && fn === 'masterSelectionAt') success.data = safe.encodeEventLog(safe.getEvent('ExecutionSuccess'), [s.safeTxHash, 0n]).data;
  };
  await assert.rejects(workflow.inspectMuseumAnchorMasterReceipt(s.provider, cap, tx.options), /matching Safe/);
});
test('class1 publication/schedule/execute receipts support both anchors and direct/Safe layouts', async () => {
  for (const kind of ['conditionSources', 'conservationFloor']) for (const stage of ['publish', 'schedule', 'execute']) {
    const s = setup(), { operation } = await s.anchorCapture(kind), op = operation(stage);
    const tx = s.installGov(op, stage === 'schedule' ? 'direct' : 'safe', stage === 'execute');
    const result = await workflow.inspectMuseumAnchorGovernanceReceipt(s.provider, op, tx.options);
    if (stage === 'execute') assert.deepEqual(result.binding, { target: s.candidate.address, runtimeCodeHash: codeHash });
  }
});
test('eventless publication needs prior-block immutable bytes and prior Executor pin independently of capture', async () => {
  const s = setup(), { operation } = await s.anchorCapture(), op = operation('publish'), tx = s.installGov(op, 'safe', true, true);
  await workflow.inspectMuseumAnchorGovernanceReceipt(s.provider, op, tx.options);
  s.options.code = (address, tag) => address === a(2) && tag === 11 ? '0x6001' : undefined;
  await assert.rejects(workflow.inspectMuseumAnchorGovernanceReceipt(s.provider, op, tx.options), /runtime/);
  s.options.code = undefined; s.state.publishedAt = 12;
  await assert.rejects(workflow.inspectMuseumAnchorGovernanceReceipt(s.provider, op, tx.options), /prior-block/);
});
test('governance receipts reject reversed original event order, stale catalog and missed permanent binding', async () => {
  for (const mode of ['order', 'catalog', 'binding']) {
    const s = setup(), { operation } = await s.anchorCapture(), op = operation('execute'), tx = s.installGov(op);
    if (mode === 'order') { tx.mined.logs.reverse(); s.reindex(); }
    if (mode === 'catalog') s.options.read = ({ fn, tx }) => fn === 'governanceActionPolicyState' && tx.blockTag === 20 ? [id('profile'), id('changed'), 13n, 1n] : undefined;
    if (mode === 'binding') s.options.read = ({ fn, tx }) => fn === 'conditionSources' && tx.blockTag === 20 ? [ZeroAddress, ZeroHash] : undefined;
    await assert.rejects(workflow.inspectMuseumAnchorGovernanceReceipt(s.provider, op, tx.options));
  }
});
test('strict copies, typed capture hash, canonical RPC, reorg and generic Safe composition remain bounded', async () => {
  const s = setup(), input = clone(s.d), prepared = s.prepare();
  s.options.network = () => { input.metadata.address = a(99); };
  const cap = await workflow.captureMuseumAnchorMaster(s.provider, input, prepared, { blockTag: 10 });
  assert.equal(cap.deployment.metadata.address, a(3));
  const bad = clone(cap); bad.authorizationClass = '6n';
  await assert.rejects(workflow.simulateMuseumAnchorMaster(s.provider, bad, { blockTag: 10 }), /capture changed/);
  const plan = createSafeCallPlan(1n, 'Adopt original Museum master', [{ safe: s.caller, intent: 'Adopt reviewed original master evidence', call: cap.prepared.call, abi: fixture.abis.master }]);
  assert.equal(plan.steps[0].transaction.operation, 0);
  const malformed = setup({ read: ({ fn }) => fn === 'sourceSetHead' ? `${abi.encodeFunctionResult(fn, [0n, id('head')])}${'00'.repeat(32)}` : undefined });
  await assert.rejects(malformed.anchorCapture(), /Noncanonical/);
  let reads = 0;
  const fork = setup({ blockHash: n => n === 10 && reads++ > 0 ? id('changed-block') : undefined });
  await assert.rejects(fork.anchorCapture(), /block changed/);
});
test('original MEDIA class7 publication and adopted record remain separate from tier7 and principal waiver1', async () => {
  const s = setup({ publish: true });
  s.recordReceipt.authorizationClass = 7n;
  s.options.read = ({ fn, args }) => fn === 'familyWriter' ? [args[1] === FAMILY.media && args[2] === 7n, 8n] : undefined;
  const cap = await s.capture();
  assert.equal(cap.authorizationClass, 7n);
  const tx = s.installMaster(cap, 'direct');
  const r = await workflow.inspectMuseumAnchorMasterReceipt(s.provider, cap, tx.options);
  assert.equal(r.original.evidence.authorizationClass, 7n);
  const adopted = setup();
  adopted.recordReceipt.authorizationClass = 7n;
  assert.equal((await adopted.capture()).original.evidence.authorizationClass, 7n);
});
test('WAIVED receipt retains consumed original op24 and full evidence after current mutable admission changes', async () => {
  const s = setup({ waiver: true }), cap = await s.capture(), tx = s.installMaster(cap, 'safe', true);
  s.options.read = ({ fn, tx: call }) => {
    if (call.blockTag > 10 && ['documentFacts', 'binding', 'requireCoverage', 'currentMaster', 'familyWriter', 'requireRecordPublication'].includes(fn)) throw Error('later mutable state unavailable');
  };
  const r = await workflow.inspectMuseumAnchorMasterReceipt(s.provider, cap, tx.options);
  assert.equal(r.selection.status, 2n);
  assert.equal(r.original.evidence.publication.attestationRecordHash, s.authorization);
  s.options.read = ({ fn, tx: call }) => fn === 'consumedArtistAuthorization' && call.blockTag > 10 ? [false] : undefined;
  await assert.rejects(workflow.inspectMuseumAnchorMasterReceipt(s.provider, cap, tx.options), /not consumed/);
});
