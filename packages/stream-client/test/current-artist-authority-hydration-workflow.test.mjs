import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { AbiCoder, Interface, ZeroAddress, ZeroHash, getAddress, id, keccak256 } from 'ethers';
import * as pure from '../dist/current-artist-authority-hydration.js';
import * as workflow from '../dist/current-artist-authority-hydration-workflow.js';
import { createSafeCallPlan } from '../dist/safe-plan.js';

const fixture = JSON.parse(readFileSync(new URL('./fixtures/current-artist-authority-hydration-abi.json', import.meta.url)));
const fragments = Object.values(fixture.abis).flat();
const seen = new Set();
const abi = new Interface(fragments.filter(f => {
  if (f.type !== 'function' && f.type !== 'event') return false;
  const key = JSON.stringify(f);
  if (seen.has(key)) return false;
  seen.add(key); return true;
}));
const coder = AbiCoder.defaultAbiCoder();
const a = n => getAddress(`0x${n.toString(16).padStart(40, '0')}`);
const domains = ['binding_lifecycle', 'collaborator_lifecycle', 'identity_authority', 'acceptance_lifecycle', 'attribution_lifecycle', 'payout_lifecycle', 'consent_finality'].map(n => id(`domain:${n}`));
const code = '0x600060005260206000f3';
const pin = n => ({ address: a(n), codeHash: keccak256(code) });
const safeAbi = new Interface([
  'function execTransaction(address,uint256,bytes,uint8,uint256,uint256,uint256,address,address,bytes) returns(bool)',
  'event ExecutionSuccess(bytes32 txHash,uint256 payment)',
  'event ExecutionFailure(bytes32 txHash,uint256 payment)',
]);
const clone = value => structuredClone(value);

// These are compiler-ABI RPC fixtures. The write eth_call is stubbed to isolate client joins;
// successful cases do not claim native EVM, gas or complete deployed-source admission evidence.
function setup(kind = 'baseline', options = {}) {
  const common = Array.from({ length: 7 }, (_, i) => pin(100 + i));
  const suitePins = base => ({ registry: pin(base + 7), coordinator: pin(base + 20), components: [...Array.from({ length: 9 }, (_, i) => pin(base + i)), ...common] });
  const deployment = { chainId: 1n, source: suitePins(200), destination: suitePins(300) };
  const suite = pins => ({ registry: pins.registry.address, archive: pins.components[8].address,
    owners: pins.components.slice(0, 7).map(p => p.address), core: common[0].address, mintManager: common[1].address,
    roleRegistry: common[2].address, metadata: common[3].address, primaryResolver: common[4].address,
    royaltyResolver: common[5].address, validator: common[6].address, primaryRevenueClass: id('PRIMARY') });
  const source = suite(deployment.source), destination = suite(deployment.destination);
  const actor = a(999), authority = a(998), delegate = a(997);
  const registrationOrder = Array.from({ length: kind === 'multiple' ? 2 : 1 }, (_, i) => ({ authority: a(998 - i * 10),
    artistId: keccak256(coder.encode(['bytes32', 'uint256', 'address', 'address', 'bytes32', 'uint256'], [id('6529STREAM_ARTIST_ID_V1'), 1n, source.registry, a(998 - i * 10), keccak256('0x1234'), BigInt(i)])) }));
  const artistIds = registrationOrder.map(r => r.artistId).sort();
  const artistAuthority = artistId => registrationOrder.find(r => r.artistId === artistId).authority;
  // First collection deliberately belongs to the second Artist; this is the original commitment anchor.
  const collections = kind === 'multiple' ? [{ artistId: artistIds[1], collectionId: 10n, policies: [] }, { artistId: artistIds[0], collectionId: 20n, policies: [] }, { artistId: artistIds[1], collectionId: 30n, policies: [] }]
    : [{ artistId: artistIds[0], collectionId: 10n, policies: kind === 'delegation' ? [{ phaseId: id('phase'), policyHash: id('policy') }] : [] }];
  const journals = Array.from({ length: 7 }, () => []);
  for (const c of collections) {
    journals[0].push({ operation: 1n, artistId: c.artistId, collectionId: c.collectionId, recordHash: id(`binding-${c.collectionId}`) });
    journals[3].push({ operation: 2n, artistId: c.artistId, collectionId: c.collectionId, recordHash: id(`accept-${c.collectionId}`) });
  }
  for (const { artistId } of registrationOrder) journals[2].push({ operation: 1n, artistId, collectionId: 0n, recordHash: artistId });
  const grantHash = keccak256(coder.encode(['bytes32', 'uint256', 'address', 'bytes32', 'address', 'uint256', 'uint32', 'uint64', 'uint64', 'uint64', 'bytes32', 'uint256'],
    [id('6529STREAM_ARTIST_DELEGATION_RECORD_V1'), 1n, source.registry, artistIds[0], delegate, 0n, 2n, 1n, 3n, 1n, ZeroHash, 5n]));
  if (kind === 'delegation') {
    journals[2].push({ operation: 26n, artistId: artistIds[0], collectionId: 0n, recordHash: grantHash });
    journals[6].push({ operation: 14n, artistId: artistIds[0], collectionId: 10n, recordHash: id('recorded-policy') });
  }
  const snapshots = (revisions, prefix) => domains.map((domainId, i) => ({ domainId, revision: revisions[i], stateRoot: id(`${prefix}-state-${i}`), recordChainTip: id(`${prefix}-tip-${i}`) }));
  const sourceRevisions = [BigInt(2 * collections.length), 0n,
    kind === 'delegation' ? 5n : BigInt(artistIds.length + collections.length + 1), BigInt(collections.length), BigInt(2 * collections.length), 0n, BigInt(journals[6].length)];
  const before = snapshots([0n, 0n, kind === 'multiple' ? BigInt(1 + artistIds.length + collections.length) : 3n, 0n, 0n, 0n, 0n], 'destination');
  const replayOrigins = Array.from({ length: 7 }, () => []);
  replayOrigins[2].push({ surface: id('identity_authority.replay.one_way_cutover_latch'), scope: ZeroHash });
  const nonceIndexes = artistIds.map(artistId => ({ kind: 1n, key: artistId, words: [{ prefix: 0n,
    words: [(1n << BigInt(collections.filter(c => c.artistId === artistId).length)) - 1n | (kind === 'delegation' ? 32n : 0n), ...Array(31).fill(0n)], exhausted: false }] }));
  if (kind === 'delegation') nonceIndexes.push({ kind: 2n, key: keccak256(coder.encode(['bytes32', 'bytes32', 'address'], [id('6529STREAM_ARTIST_DELEGATE_NONCE_LANE_V1'), artistIds[0], delegate])), words: [{ prefix: 0n, words: [1n, ...Array(31).fill(0n)], exhausted: false }] });
  const checkpoints = snapshots(sourceRevisions, 'source').map((ownerState, i) => ({ schema: pure.ARTIST_HYDRATION_CHECKPOINT_SCHEMA, ownerState,
    replayRoot: id(`replay-root-${i}`), replayCount: BigInt(replayOrigins[i].length), nonceRoot: id(`nonce-root-${i}`), nonceIndexCount: i === 2 ? BigInt(nonceIndexes.length) : 0n }));
  const request = kind === 'multiple' ? { bindingIndex: 0n, artistIds, collections, expectedSource: checkpoints, replayOrigins }
    : { bindingIndex: 0n, ...collections[0], expectedSource: checkpoints, replayOrigins };
  const input = { kind, request };
  const prepared = pure.prepareArtistAuthorityHydrationCall(destination.registry, actor, input);
  const queries = collections.map(c => ({ ...c, bindingHash: id(`binding-${c.collectionId}`), records: [] }));
  const query = kind === 'multiple' ? queries[0] : { ...queries[0], records: journals.flat().map(r => r.recordHash) };
  const rawState = new Map();
  const identity = (artistId, records) => ({ item: { authorityAddress: artistAuthority(artistId), authorityClass: 1n, status: 1n, registeredAt: 1n, lastAuthorityActionAt: 1n,
    identityRecordHash: keccak256('0x1234'), identityRecordURI: 'ipfs://identity', displayName: 'Artist', nonceHint: BigInt(collections.filter(c => c.artistId === artistId).length) }, document: '0x1234', nextRegistrationNonce: BigInt(artistIds.length),
    estateActivity: 1n, dormancyActivity: 1n, findingActivity: 1n, signatures: records.map(() => '0x') });
  const state = (i, q) => {
    if (i === 0) return { item: { artistId: q.artistId, artistAddress: artistAuthority(q.artistId), identityRecordHash: keccak256('0x1234'), bindingHash: q.bindingHash, generation: 1n,
      consentMode: kind === 'delegation' ? 2n : 1n, saleConsentScope: 1n, registryImmutabilityElection: 0n, proposer: actor, accepted: true },
      terms: { collaboratorSetHash: id('empty-collaborators'), capabilityPolicySetHash: id('empty-capabilities'), mode: 0n, threshold: 0n, count: 0n } };
    if (i === 2) return identity(q.artistId, q.records);
    if (i === 3) return { record: id(`accept-${q.collectionId}`), acceptedAt: 2n };
    if (i === 4) return { state: 2n, generation: 1n };
    if (i === 6) return q.policies.map(() => id('recorded-policy'));
    return null;
  };
  const ownerData = Array.from({ length: 7 }, (_, i) => ({ typedState: '0x', origins: replayOrigins[i], sourceKeys: [], cells: [], nonces: [] }));
  for (let i = 0; i < 7; ++i) {
    for (const origin of replayOrigins[i]) {
      ownerData[i].sourceKeys.push(pure.artistAuthorityHydrationReplayKey({ chainId: 1n, registry: source.registry, coordinator: deployment.source.coordinator.address,
        archive: source.archive, owner: source.owners[i], domain: domains[i] }, origin));
      ownerData[i].cells.push({ commitment: id('cutover'), touchedRevision: checkpoints[i].ownerState.revision, kind: 1n, status: 2n });
    }
  }
  const put = (i, q, raw) => rawState.set(`${i}:${q.artistId}:${q.collectionId}`, raw);
  if (kind === 'multiple') {
    const artistRows = artistIds.map(artistId => {
      const q = { artistId, collectionId: 0n, bindingHash: ZeroHash, policies: [], records: journals.flat().filter(r => r.artistId === artistId).map(r => r.recordHash) };
      const raw = pure.encodeArtistHydrationIdentity(identity(artistId, q.records)); put(2, q, raw);
      return { query: q, state: raw, nonces: nonceIndexes.find(n => n.key === artistId).words };
    });
    for (let i = 0; i < 7; ++i) {
      if (i === 1 || i === 5) continue;
      if (i === 2) ownerData[i].typedState = pure.encodeArtistHydrationMultipleBundle(2, { rows: artistRows, artistIds, collectionIds: collections.map(c => c.collectionId), registrationCount: BigInt(artistIds.length) });
      else ownerData[i].typedState = pure.encodeArtistHydrationMultipleBundle(i, { rows: queries.map(q => {
        const raw = pure.encodeArtistHydrationOwnerState('baseline', i, state(i, q)); put(i, q, raw);
        return { query: { ...q, policies: i === 6 ? q.policies : [] }, state: raw, nonces: [] };
      }), artistIds: [], collectionIds: [], registrationCount: 0n });
    }
  } else {
    ownerData[2].nonces = nonceIndexes[0].words;
    for (let i = 0; i < 7; ++i) {
      let value = state(i, query);
      if (kind === 'delegation' && i === 2) value = { baseline: pure.encodeArtistHydrationOwnerState('baseline', 2, value), epoch: 0n, revisions: [],
        grants: [{ recordHash: grantHash, item: { grant: { artistId: artistIds[0], delegate, collectionId: 0n, capabilities: 2n, notBefore: 1n, expiresAt: 3n, maxUses: 1n, constraintsHash: ZeroHash },
          grantor: authority, nonce: 5n, uses: 1n, revoked: false, revocationRecordHash: ZeroHash }, epoch: 0n, current: grantHash }],
        delegateNonces: [{ key: nonceIndexes[1].key, hint: 1n, words: nonceIndexes[1].words }] };
      if (kind === 'delegation' && i === 6) value = { policies: [{ recordHash: id('recorded-policy'), grant: grantHash }], sales: [] };
      ownerData[i].typedState = pure.encodeArtistHydrationOwnerState(kind, i, value); put(i, query, ownerData[i].typedState);
    }
  }
  const coordinates = { chainId: 1n, registry: destination.registry, coordinator: deployment.destination.coordinator.address, predecessorRegistry: source.registry, sourceCoordinator: deployment.source.coordinator.address };
  const commitment = pure.artistAuthorityHydrationCommitment(coordinates, input, query, ownerData);
  const after = before.map((s, i) => pure.artistAuthorityHydrationOwnerAfter({ chainId: 1n, registry: destination.registry, coordinator: coordinates.coordinator, archive: destination.archive, owner: destination.owners[i], domain: domains[i] }, s, actor, query, ownerData[i], commitment));
  const evidenceId = pure.artistAuthorityHydrationEvidenceId(coordinates, actor, commitment);
  const configurationHash = id('configuration');
  const evidence = pure.encodeArtistAuthorityHydrationEvidence({ schemaVersion: 1n, configurationHash, operationId: 60n, actor, commitment, before, after,
    profileData: pure.encodeArtistAuthorityHydrationProfileEvidence({ profile: prepared.profile, predecessorRegistry: source.registry, sourceCoordinator: coordinates.sourceCoordinator, expectedSource: checkpoints, query, ownerData }) });
  const pointer = a(888), txHash = id('transaction'), blockHash = n => id(`block-${n}`);
  const retained = [
    { pointer: a(889), payloadType: id('ARTIST_IDENTITY_DOCUMENT'), payloadHash: keccak256('0x1234'), bytes: '0x1234' },
    { pointer: a(890), payloadType: id('ARTIST_SIGNATURE_BUNDLE'), payloadHash: keccak256('0x'), bytes: '0x' },
  ];
  const calls = [];
  let mined = false, receipt, transaction;
  const provider = {
    getNetwork: async () => { options.network?.(); return { chainId: 1n }; },
    getBlock: async n => ({ number: n, timestamp: 100 + n, hash: options.blockHash?.(n) ?? blockHash(n) }),
    getCode: async (address, tag) => options.code?.(address, tag) ?? (address === pointer ? `0x00${evidence.slice(2)}` : retained.some(r => r.pointer === address) ? `0x00${retained.find(r => r.pointer === address).bytes.slice(2)}` : code),
    call: async tx => {
      calls.push(tx);
      const parsed = abi.parseTransaction({ data: tx.data });
      assert.ok(parsed, `Unknown selector ${tx.data.slice(0, 10)}`);
      const fn = parsed.name, args = parsed.args, tag = tx.blockTag;
      const injected = await options.read?.({ fn, args, tx });
      if (injected !== undefined) return typeof injected === 'string' ? injected : abi.encodeFunctionResult(fn, injected);
      const s = [source.registry, source.archive, coordinates.sourceCoordinator, ...source.owners].includes(tx.to) ? source : destination;
      const pins = s === source ? deployment.source : deployment.destination;
      const i = s.owners.indexOf(tx.to);
      let values;
      if (fn.startsWith('hydrate')) {
        assert.equal(tx.from, actor); assert.equal(tx.value, 0n); values = [commitment];
      } else if (fn === 'authorityHydrationSuite') values = [s];
      else if (fn === 'core' || fn === 'mintManager') values = [s[fn]];
      else if (fn === 'artistRegistry') values = [s.registry];
      else if (fn === 'operationCoordinator') values = [pins.coordinator.address];
      else if (fn === 'archiveV2') values = [s.archive];
      else if (fn === 'deploymentChainId') values = [1n];
      else if (fn === 'configurationHash') values = [configurationHash];
      else if (fn === 'domainId') values = [domains[i]];
      else if (fn === 'artistArchiveMaxEvidenceBytesV2') values = [24575n];
      else if (fn === 'gasParameterInfo') values = [1000000n, 1n, 2n, 1n];
      else if (fn === 'getSatellitePointer') values = [destination.registry, deployment.destination.registry.codeHash, false, id('ARTIST_REGISTRY'), '0x12345678', a(777), 1n, id('module'), id('deployment'), 1n];
      else if (fn === 'artistRegistryCutover') values = s === source ? [true, destination.registry, 5n] : [false, ZeroAddress, 0n];
      else if (fn === 'importedHistoryBindingCount') values = [s === source ? 0n : 1n];
      else if (fn === 'importedHistoryBinding') values = [source.registry, 5n, id('root'), id('manifest')];
      else if (fn === 'artistHistoryPredecessorBinding') values = [true, deployment.source.registry.codeHash, 1n];
      else if (fn === 'authorityCheckpoint') values = [checkpoints[i]];
      else if (fn === 'ownerStateSnapshotV2') values = [mined && tag === 11 ? after[i] : before[i]];
      else if (fn === 'authorityHydrationCommitment') values = [mined && tag === 11 ? commitment : ZeroHash];
      else if (fn === 'artistNativeReceiptCount') values = [s === source ? BigInt(journals[i].length) : 0n];
      else if (fn === 'artistNativeReceiptAt') values = [journals[i][Number(args[0])]];
      else if (fn === 'artistHistorySourceCursor') values = [0n];
      else if (fn === 'storedPayloadCount') values = [mined && tag === 11 && [destination.owners[2], destination.archive].includes(tx.to) ? 2n : 0n];
      else if (fn === 'storedPayloadAt') { const row = retained[Number(args[0])]; values = [row.pointer, row.payloadType, row.payloadHash]; }
      else if (fn === 'authorityReplayAt') values = [ownerData[i].sourceKeys[Number(args[0])], ownerData[i].cells[Number(args[0])]];
      else if (fn === 'replayCell' || fn === 'importedAuthorityReplayCell') values = [ownerData[i].cells[ownerData[i].sourceKeys.indexOf(args[0])]];
      else if (fn === 'authorityNonceIndexAt') { const n = nonceIndexes[Number(args[0])]; values = [{ kind: n.kind, key: n.key, prefixCount: BigInt(n.words.length) }]; }
      else if (fn === 'authorityNonceWordAt') { const n = nonceIndexes.find(n => n.kind === args[0] && n.key === args[1]).words[Number(args[2])]; values = [n.prefix, n.words, n.exhausted]; }
      else if (fn.includes('HydrationState')) values = [rawState.get(`${i}:${args[0].artistId}:${args[0].collectionId}`)];
      else if (fn === 'artistHistoryLane' || fn === 'importedLaneVerified') {
        const count = journals.flat().filter(r => args[0] === 1n ? r.artistId === args[1] : r.collectionId === BigInt(args[1])).length;
        values = fn === 'artistHistoryLane' ? [id(`lane-${args[1]}`), BigInt(count)] : [true, id(`lane-${args[1]}`), BigInt(count)];
      } else if (fn === 'artistEvidenceMetadataV2') values = [keccak256(evidence), pointer, BigInt((evidence.length - 2) / 2), 11n];
      else if (fn === 'artistEvidenceBytesV2') values = [evidence];
      else throw Error(`Unhandled ${fn}`);
      return abi.encodeFunctionResult(fn, values);
    },
    getTransaction: async () => transaction,
    getTransactionReceipt: async () => receipt,
  };
  function mine(execution = 'direct', indexed = false) {
    mined = true;
    const logs = [];
    function log(address, event, values, selected = abi) {
      const encoded = selected.encodeEventLog(selected.getEvent(event), values);
      logs.push({ address, ...encoded, index: logs.length, blockNumber: 11, blockHash: blockHash(11), transactionHash: txHash, removed: false });
    }
    for (let i = 0; i < retained.length; ++i) { const row = retained[i]; log(destination.owners[2], 'ArtistStoredPayload', [1n, BigInt(i), row.payloadType, row.payloadHash, row.pointer]); }
    log(destination.archive, 'ArtistArchiveEvidenceAppendedV2', [evidenceId, 1n, keccak256(evidence), pointer, BigInt((evidence.length - 2) / 2)]);
    log(coordinates.coordinator, 'ArtistAuthorityHydrated', [1n, query.artistId, query.collectionId, source.registry, prepared.profile, commitment]);
    if (kind === 'multiple') log(coordinates.coordinator, 'MultipleArtistAuthorityHydrated', [source.registry, commitment, artistIds, collections.map(c => c.collectionId)]);
    for (let i = 0; i < retained.length; ++i) { const row = retained[i]; log(destination.archive, 'ArtistStoredPayload', [1n, BigInt(i), row.payloadType, row.payloadHash, row.pointer]); }
    if (execution === 'safe') {
      log(actor, 'ExecutionSuccess', [id('safe-transaction'), 0n], safeAbi);
      if (indexed) { logs.at(-1).topics.push(id('safe-transaction')); logs.at(-1).data = coder.encode(['uint256'], [0n]); }
    }
    const to = execution === 'safe' ? actor : destination.registry;
    const from = execution === 'safe' ? a(996) : actor;
    const data = execution === 'safe' ? safeAbi.encodeFunctionData('execTransaction', [prepared.call.to, 0n, prepared.call.data, 0n, 0n, 0n, 0n, ZeroAddress, ZeroAddress, '0x']) : prepared.call.data;
    transaction = { hash: txHash, blockHash: blockHash(11), blockNumber: 11, to, from, value: 0n, data };
    receipt = { hash: txHash, blockHash: blockHash(11), blockNumber: 11, status: 1, to, from, logs };
    return { transaction, receipt };
  }
  return { deployment, prepared, provider, options, calls, mine, txHash, input, ownerData, query, journals, nonceIndexes, before, after, checkpoints,
    commitment, source, destination, coordinates, rawState, evidence, pointer, blockHash };
}
const capture = s => workflow.captureArtistAuthorityHydration(s.provider, s.deployment, s.prepared, { blockTag: 10 });

test('all three profiles reconstruct complete source data and original actual-caller commitment', async () => {
  for (const kind of ['baseline', 'multiple', 'delegation']) {
    const s = setup(kind), c = await capture(s);
    assert.equal(c.commitment, s.commitment);
    assert.deepEqual(c.ownerData, s.ownerData);
    assert.deepEqual(c.after, s.after);
    assert.equal(c.simulated, true);
    assert.ok(Object.isFrozen(c.ownerData[2].nonces));
    assert.ok(s.calls.every(tx => tx.blockTag === 10));
    if (kind === 'multiple') assert.equal(c.query.artistId, s.input.request.collections[0].artistId);
    if (kind === 'delegation') assert.equal(c.nonceIndexes.length, 2);
  }
});

test('direct and both Safe event layouts join Archive and all seven atomic owner roots', async () => {
  for (const [kind, execution, indexed] of [['baseline', 'direct', false], ['multiple', 'safe', false], ['delegation', 'safe', true]]) {
    const s = setup(kind), c = await capture(s); s.mine(execution, indexed);
    const r = await workflow.inspectArtistAuthorityHydrationReceipt(s.provider, c, s.txHash, { execution });
    assert.equal(r.commitment, c.commitment);
    assert.equal(r.observedOwners.length, 7);
    if (execution === 'safe') assert.equal(r.events.at(-1).event, 'ExecutionSuccess');
  }
});

test('capture and retry retain immutable requests, concrete block identities and exact call bytes', async () => {
  const s = setup(), copied = clone(s.prepared), deployment = clone(s.deployment);
  s.options.network = () => { copied.input.request.artistId = id('mutated'); deployment.source.registry.codeHash = id('mutated'); };
  const c = await workflow.captureArtistAuthorityHydration(s.provider, deployment, copied, { blockTag: 10 });
  assert.equal(c.prepared.input.request.artistId, s.input.request.artistId);
  assert.equal(c.deployment.source.registry.codeHash, s.deployment.source.registry.codeHash);
  delete s.options.network;
  const fresh = await workflow.simulateArtistAuthorityHydration(s.provider, c, { blockTag: 12 });
  assert.equal(fresh.commitment, c.commitment);
  await assert.rejects(workflow.simulateArtistAuthorityHydration(s.provider, c, { blockTag: 9 }), /predates/);
  const forged = clone(c); forged.before[0].revision = '0n';
  await assert.rejects(workflow.simulateArtistAuthorityHydration(s.provider, forged, { blockTag: 12 }), /changed/);
  s.options.read = ({ fn, tx }) => fn === 'ownerStateSnapshotV2' && tx.blockTag === 12 ? [{ ...s.before[0], revision: 99n }] : undefined;
  await assert.rejects(workflow.simulateArtistAuthorityHydration(s.provider, c, { blockTag: 12 }), /not empty/);
});

test('complete source journal, revision, replay, nonce and lane inventories fail closed', async () => {
  const cases = [
    ['artistNativeReceiptCount', ({ tx }) => tx.to === a(200) ? [129n] : undefined, /Excessive/],
    ['artistNativeReceiptAt', ({ tx }) => tx.to === a(202) ? [{ operation: 25n, artistId: setup().query.artistId, collectionId: 0n, recordHash: id('extra') }] : undefined, /Unsupported|Incomplete/],
    ['authorityCheckpoint', ({ tx }) => tx.to === a(200) ? [{ ...setup().checkpoints[0], replayCount: 1n }] : undefined, /checkpoint/],
    ['authorityReplayAt', () => [id('wrong-key'), { commitment: id('cutover'), touchedRevision: 3n, kind: 1n, status: 2n }], /replay/],
    ['authorityNonceIndexAt', () => [{ kind: 2n, key: id('artist-a'), prefixCount: 1n }], /nonce/],
    ['importedLaneVerified', () => [true, id('wrong-tip'), 3n], /lane/],
  ];
  for (const [method, override, error] of cases) {
    const s = setup(); s.options.read = v => v.fn === method ? override(v) : undefined;
    await assert.rejects(capture(s), error, method);
  }
});

test('destination current selection, empty state, cutover and predecessor bindings are mandatory', async () => {
  for (const [fn, condition, value, pattern] of [
    ['getSatellitePointer', () => true, [a(123), keccak256(code), false, id('type'), '0x12345678', a(777), 1n, id('m'), id('d'), 1n], /selected/],
    ['authorityHydrationCommitment', () => true, [id('already-complete')], /not empty/],
    ['artistRegistryCutover', tx => tx.to === a(302), [true, a(900), 9n], /cut over/],
    ['artistHistoryPredecessorBinding', () => true, [true, id('wrong-code'), 1n], /binding/],
    ['importedHistoryBindingCount', tx => tx.to === a(302), [2n], /Exactly one/],
  ]) {
    const s = setup(); s.options.read = v => v.fn === fn && condition(v.tx) ? value : undefined;
    await assert.rejects(capture(s), pattern);
  }
});

test('canonical read decoding and exact original-call result are enforced', async () => {
  for (const method of ['authorityCheckpoint', 'authorityHydrationState', 'hydrateArtistAuthority']) {
    const s = setup();
    if (method === 'authorityCheckpoint') s.options.read = ({ fn }) => fn === method ? `${abi.encodeFunctionResult(fn, [s.checkpoints[0]])}00` : undefined;
    if (method === 'authorityHydrationState') s.options.read = ({ fn, tx }) => fn === method && tx.to === s.source.owners[0] ? [`${s.ownerData[0].typedState}00`] : undefined;
    if (method === 'hydrateArtistAuthority') s.options.read = ({ fn }) => fn === method ? [id('wrong-commitment')] : undefined;
    await assert.rejects(capture(s), /canonical|different reconstructed|invalid length/);
  }
});

test('wrong chain, changed code, delegation-designation code, changing suites and reorgs reject', async () => {
  const wrong = setup(); wrong.provider.getNetwork = async () => ({ chainId: 2n });
  await assert.rejects(capture(wrong), /Wrong chain/);
  const drift = setup(); drift.options.code = address => address === drift.deployment.source.coordinator.address ? '0x6001' : undefined;
  await assert.rejects(capture(drift), /runtime/);
  const delegation = setup(); const designation = `0xef0100${a(50).slice(2)}`;
  const d = clone(delegation.deployment); d.source.coordinator.codeHash = keccak256(designation);
  delegation.options.code = address => address === d.source.coordinator.address ? designation : undefined;
  await assert.rejects(workflow.captureArtistAuthorityHydration(delegation.provider, d, delegation.prepared, { blockTag: 10 }), /runtime/);
  const changing = setup(); let reads = 0;
  changing.options.read = ({ fn, tx }) => fn === 'authorityHydrationSuite' && tx.to === changing.deployment.source.coordinator.address && ++reads > 1 ? [{ ...changing.source, primaryRevenueClass: id('changed') }] : undefined;
  await assert.rejects(capture(changing), /suite changed/);
  const reorg = setup(); let blocks = 0; reorg.options.blockHash = n => n === 10 && ++blocks > 1 ? id('reorg') : reorg.blockHash(n);
  await assert.rejects(capture(reorg), /block changed/);
});

test('expired and exhausted historical grants remain source history without a new live-delegation query', async () => {
  const s = setup('delegation'), c = await capture(s);
  assert.equal(c.prepared.input.kind, 'delegation');
  assert.equal(s.calls.some(c => c.data.startsWith('0x') && abi.parseTransaction({ data: c.data }).name === 'delegationState'), false);
  const d = pure.decodeArtistHydrationOwnerState('delegation', 2, c.ownerData[2].typedState);
  assert.equal(d.grants[0].item.uses, d.grants[0].item.grant.maxUses);
  assert.ok(d.grants[0].item.grant.expiresAt < 110n);
});

test('all three compiled calls compose ordinary Safe operation-zero review plans', async () => {
  for (const kind of ['baseline', 'multiple', 'delegation']) {
    const s = setup(kind), c = await capture(s);
    const plan = createSafeCallPlan(1n, 'Hydrate approved living authority', [{ safe: c.prepared.caller, intent: `Hydrate ${kind} source history`, call: c.prepared.call, abi: fixture.abis.artist }]);
    assert.equal(plan.steps[0].transaction.operation, 0);
    assert.equal(plan.steps[0].transaction.value, '0');
    assert.equal(plan.steps[0].transaction.data, c.prepared.call.data);
  }
});

test('receipt requires all newly retained document/signature and Archive catalog events', async () => {
  for (const remove of ['all', 'document', 'empty-signature', 'archive-only']) {
    const s = setup(), c = await capture(s), { receipt } = s.mine();
    receipt.logs = receipt.logs.filter(log => {
      const parsed = abi.parseLog(log);
      if (parsed.name !== 'ArtistStoredPayload') return true;
      if (remove === 'all') return false;
      if (remove === 'document') return parsed.args.payloadType !== id('ARTIST_IDENTITY_DOCUMENT');
      if (remove === 'empty-signature') return parsed.args.payloadType !== id('ARTIST_SIGNATURE_BUNDLE');
      return log.address !== s.destination.archive;
    });
    await assert.rejects(workflow.inspectArtistAuthorityHydrationReceipt(s.provider, c, s.txHash, { execution: 'direct' }), /payload|Archive/);
  }
});

test('receipt rejects missing owner completion, altered Archive bytes and inconsistent readback', async () => {
  for (const attack of ['marker', 'root', 'replay', 'cursor', 'catalog', 'pointer']) {
    const s = setup(), c = await capture(s); s.mine();
    s.options.read = ({ fn, tx }) => {
      if (tx.blockTag !== 11) return;
      if (attack === 'marker' && fn === 'authorityHydrationCommitment') return [ZeroHash];
      if (attack === 'root' && fn === 'ownerStateSnapshotV2') return [{ ...s.after[0], stateRoot: id('wrong') }];
      if (attack === 'replay' && fn === 'importedAuthorityReplayCell') return [{ ...s.ownerData[2].cells[0], status: 1n }];
      if (attack === 'cursor' && fn === 'artistHistorySourceCursor') return [1n];
      if (attack === 'catalog' && fn === 'storedPayloadAt') return [a(889), id('wrong-type'), id('wrong-hash')];
    };
    if (attack === 'pointer') s.options.code = address => address === s.pointer ? '0x001234' : undefined;
    await assert.rejects(workflow.inspectArtistAuthorityHydrationReceipt(s.provider, c, s.txHash, { execution: 'direct' }), /hydration|state|replay|synchronization|catalog|pointer/);
  }
});

test('historical Archive atomic state allows later end-block owner revisions', async () => {
  const s = setup(), c = await capture(s); s.mine();
  s.options.read = ({ fn, tx }) => {
    if (tx.blockTag === 11 && fn === 'ownerStateSnapshotV2') {
      const i = s.destination.owners.indexOf(tx.to);
      return [{ ...s.after[i], revision: s.after[i].revision + 1n, stateRoot: id(`later-${i}`), recordChainTip: id(`later-tip-${i}`) }];
    }
  };
  const receipt = await workflow.inspectArtistAuthorityHydrationReceipt(s.provider, c, s.txHash, { execution: 'direct' });
  assert.equal(receipt.observedOwners[0].revision, c.after[0].revision + 1n);
});

test('Safe outcome ordering, exact CALL and strict receipt chronology are required', async () => {
  for (const attack of ['missing', 'failure', 'early', 'delegatecall', 'same-block', 'topic-width']) {
    const s = setup(), c = await capture(s), { receipt, transaction } = s.mine('safe');
    if (attack === 'missing') receipt.logs.pop();
    if (attack === 'failure') receipt.logs.at(-1).topics[0] = safeAbi.getEvent('ExecutionFailure').topicHash;
    if (attack === 'early') { receipt.logs.unshift(receipt.logs.pop()); receipt.logs.forEach((log, i) => { log.index = i; }); }
    if (attack === 'delegatecall') transaction.data = safeAbi.encodeFunctionData('execTransaction', [s.prepared.call.to, 0n, s.prepared.call.data, 1n, 0n, 0n, 0n, ZeroAddress, ZeroAddress, '0x']);
    if (attack === 'same-block') { receipt.blockNumber = 10; transaction.blockNumber = 10; }
    if (attack === 'topic-width') receipt.logs[0].topics[0] = '0x00';
    await assert.rejects(workflow.inspectArtistAuthorityHydrationReceipt(s.provider, c, s.txHash, { execution: 'safe' }), /Safe|CALL|capture block|log|bytes32/);
  }
});

test('payload catalog events must retain original row order on owner and Archive', async () => {
  for (const emitter of ['owner', 'archive']) {
    const s = setup(), c = await capture(s), { receipt } = s.mine();
    const address = emitter === 'owner' ? s.destination.owners[2] : s.destination.archive;
    const positions = receipt.logs.flatMap((l, i) => l.address === address && abi.parseLog(l).name === 'ArtistStoredPayload' ? [i] : []);
    [receipt.logs[positions[0]], receipt.logs[positions[1]]] = [receipt.logs[positions[1]], receipt.logs[positions[0]]];
    receipt.logs.forEach((log, i) => { log.index = i; });
    await assert.rejects(workflow.inspectArtistAuthorityHydrationReceipt(s.provider, c, s.txHash, { execution: 'direct' }), /order|Archive payload/);
  }
});
