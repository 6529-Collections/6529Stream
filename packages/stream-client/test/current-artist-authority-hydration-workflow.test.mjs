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
const combinedFixture = JSON.parse(readFileSync(new URL('./fixtures/current-artist-multiple-delegation-abi.json', import.meta.url)));
const combinedAbi = new Interface(Object.values(combinedFixture.abis).flat().filter(f => f.type === 'function' || f.type === 'event'));
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
  const combined = kind === 'multiple-delegation', multiple = kind === 'multiple' || combined;
  const selectedAbi = combined ? combinedAbi : abi;
  const combinedProfile = options.profile ?? 'delegations';
  const hasGrants = combined && combinedProfile === 'delegations';
  const common = Array.from({ length: 7 }, (_, i) => pin(100 + i));
  const suitePins = base => ({ registry: pin(base + 7), coordinator: pin(base + 20), components: [...Array.from({ length: 9 }, (_, i) => pin(base + i)), ...common] });
  const deployment = { chainId: 1n, source: suitePins(200), destination: suitePins(300) };
  const suite = pins => ({ registry: pins.registry.address, archive: pins.components[8].address,
    owners: pins.components.slice(0, 7).map(p => p.address), core: common[0].address, mintManager: common[1].address,
    roleRegistry: common[2].address, metadata: common[3].address, primaryResolver: common[4].address,
    royaltyResolver: common[5].address, validator: common[6].address, primaryRevenueClass: id('PRIMARY') });
  const source = suite(deployment.source), destination = suite(deployment.destination);
  const actor = a(999), authority = a(998), delegate = a(997);
  const originalDocument = index => combined && index === 1 ? '0x5678' : '0x1234';
  const registrationOrder = Array.from({ length: multiple ? 2 : 1 }, (_, i) => ({ authority: a(998 - i * 10),
    artistId: keccak256(coder.encode(['bytes32', 'uint256', 'address', 'address', 'bytes32', 'uint256'], [id('6529STREAM_ARTIST_ID_V1'), 1n, source.registry, a(998 - i * 10), keccak256(originalDocument(i)), BigInt(i)])) }));
  const artistIds = registrationOrder.map(r => r.artistId).sort();
  const artistDocument = artistId => originalDocument(registrationOrder.findIndex(r => r.artistId === artistId));
  const artistAuthority = artistId => registrationOrder.find(r => r.artistId === artistId).authority;
  // First collection deliberately belongs to the second Artist; this is the original commitment anchor.
  const collections = multiple ? [{ artistId: artistIds[1], collectionId: 10n, policies: [] }, { artistId: artistIds[0], collectionId: 20n, policies: [] }, { artistId: artistIds[1], collectionId: 30n, policies: [] }]
    : [{ artistId: artistIds[0], collectionId: 10n, policies: kind === 'delegation' ? [{ phaseId: id('phase'), policyHash: id('policy') }] : [] }];
  if (hasGrants) for (const c of collections) c.policies = [{ phaseId: id(`phase-${c.collectionId}`), policyHash: id(`policy-${c.collectionId}`) }];
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
  const combinedHistory = new Map(artistIds.map(artistId => [artistId, { revisions: [], grants: [], sales: [] }]));
  if (combined) {
    for (const artistId of artistIds) {
      const history = combinedHistory.get(artistId);
      if ((combinedProfile === 'revision' || options.withRevision) && artistId === artistIds[0]) {
        const document = '0xabcd', previousRecordHash = keccak256(artistDocument(artistId));
        const revisedRecordHash = keccak256(document), signer = artistAuthority(artistId), nonce = 6n, signedAt = 2n;
        const recordHash = keccak256(coder.encode(['bytes32', 'uint256', 'address', 'bytes32', 'bytes32', 'bytes32', 'address', 'uint8', 'uint256', 'uint64'],
          ['0x1b7518e9d16da358d15957ec43218eb0b017fbd017e60c75b3126110006034a4', 1n, source.registry, artistId, previousRecordHash, revisedRecordHash, signer, 1n, nonce, signedAt]));
        history.revisions.push({ item: { recordHash, artistId, previousRevisionRecord: ZeroHash, previousRecordHash, revisedRecordHash,
          identityRecordURI: 'ipfs://revision', displayName: 'Revised', signer, authorityClass: 1n, nonce, signedAt }, document });
        journals[2].push({ operation: 25n, artistId, collectionId: 0n, recordHash });
      }
      if (hasGrants) {
        const uses = BigInt(collections.filter(c => c.artistId === artistId).length + (options.withSale && artistId === collections[0].artistId ? 1 : 0));
        const grant = { artistId, delegate, collectionId: 0n, capabilities: 1026n, notBefore: 1n, expiresAt: 3n, maxUses: uses, constraintsHash: ZeroHash };
        const recordHash = keccak256(coder.encode(['bytes32', 'uint256', 'address', 'bytes32', 'address', 'uint256', 'uint32', 'uint64', 'uint64', 'uint64', 'bytes32', 'uint256'],
          [id('6529STREAM_ARTIST_DELEGATION_RECORD_V1'), 1n, source.registry, artistId, delegate, 0n, 1026n, 1n, 3n, uses, ZeroHash, 5n]));
        const revocationRecordHash = options.revoked ? id(`revocation-${artistId}`) : ZeroHash;
        history.grants.push({ recordHash, item: { grant, grantor: artistAuthority(artistId), nonce: 5n, uses, revoked: !!options.revoked, revocationRecordHash }, epoch: 0n, current: recordHash });
        journals[2].push({ operation: 26n, artistId, collectionId: 0n, recordHash });
        if (options.revoked) journals[2].push({ operation: 27n, artistId, collectionId: 0n, recordHash: revocationRecordHash });
      }
    }
    for (const c of collections) {
      if (hasGrants) journals[6].push({ operation: 14n, artistId: c.artistId, collectionId: c.collectionId, recordHash: id(`recorded-policy-${c.collectionId}`) });
    }
    if (combinedProfile === 'sale' || options.withSale) {
      const c = collections[0], history = combinedHistory.get(c.artistId);
      const terms = { collectionId: c.collectionId, saleAdapter: a(995), saleId: id('sale'), saleConfigHash: id('sale-config') };
      const signer = hasGrants ? delegate : artistAuthority(c.artistId), authorityClass = hasGrants ? 2n : 1n, nonce = 3n, signedAt = 3n;
      const recordHash = keccak256(coder.encode(['bytes32', 'uint256', 'address', 'address', 'address', 'uint256', 'bytes32', 'bytes32', 'bytes32', 'address', 'uint8', 'uint256', 'uint64'],
        [id('6529STREAM_ARTIST_SALE_CONSENT_RECORD_V1'), 1n, source.registry, terms.saleAdapter, source.core, c.collectionId, terms.saleId, terms.saleConfigHash, c.artistId, signer, authorityClass, nonce, signedAt]));
      history.sales.push({ item: { recordHash, terms, artistId: c.artistId, bindingGeneration: 1n, bindingHash: id(`binding-${c.collectionId}`), signer, authorityClass, nonce, signedAt },
        grant: hasGrants ? history.grants[0].recordHash : ZeroHash, current: recordHash });
      journals[6].push({ operation: 16n, artistId: c.artistId, collectionId: c.collectionId, recordHash });
    }
  }
  const snapshots = (revisions, prefix) => domains.map((domainId, i) => ({ domainId, revision: revisions[i], stateRoot: id(`${prefix}-state-${i}`), recordChainTip: id(`${prefix}-tip-${i}`) }));
  const sourceRevisions = [BigInt(2 * collections.length), 0n,
    combined ? BigInt(journals[2].length + collections.length + journals[6].length + 1) : kind === 'delegation' ? 5n : BigInt(artistIds.length + collections.length + 1), BigInt(collections.length), BigInt(2 * collections.length), 0n, BigInt(journals[6].length)];
  const before = snapshots([0n, 0n, multiple ? BigInt(1 + artistIds.length + collections.length) : 3n, 0n, 0n, 0n, 0n], 'destination');
  const replayOrigins = Array.from({ length: 7 }, () => []);
  replayOrigins[2].push({ surface: id('identity_authority.replay.one_way_cutover_latch'), scope: ZeroHash });
  const nonceIndexes = artistIds.map(artistId => ({ kind: 1n, key: artistId, words: [{ prefix: 0n,
    words: [(1n << BigInt(collections.filter(c => c.artistId === artistId).length)) - 1n | (kind === 'delegation' ? 32n : 0n), ...Array(31).fill(0n)], exhausted: false }] }));
  if (kind === 'delegation') nonceIndexes.push({ kind: 2n, key: keccak256(coder.encode(['bytes32', 'bytes32', 'address'], [id('6529STREAM_ARTIST_DELEGATE_NONCE_LANE_V1'), artistIds[0], delegate])), words: [{ prefix: 0n, words: [1n, ...Array(31).fill(0n)], exhausted: false }] });
  if (combined) for (const artistId of artistIds) {
    const history = combinedHistory.get(artistId), principal = nonceIndexes.find(n => n.key === artistId);
    if (history.grants.length) principal.words[0].words[0] |= 32n;
    if (history.revisions.length) principal.words[0].words[0] |= 64n;
    if (options.revoked) principal.words[0].words[0] |= 128n;
    if (!hasGrants && history.sales.length) principal.words[0].words[0] |= 8n;
    if (hasGrants) {
      const uses = history.grants[0].item.uses;
      const key = keccak256(coder.encode(['bytes32', 'bytes32', 'address'], [id('6529STREAM_ARTIST_DELEGATE_NONCE_LANE_V1'), artistId, delegate]));
      nonceIndexes.push({ kind: 2n, key, words: [{ prefix: 0n, words: [(1n << uses) - 1n, ...Array(31).fill(0n)], exhausted: false }] });
    }
  }
  const checkpoints = snapshots(sourceRevisions, 'source').map((ownerState, i) => ({ schema: pure.ARTIST_HYDRATION_CHECKPOINT_SCHEMA, ownerState,
    replayRoot: id(`replay-root-${i}`), replayCount: BigInt(replayOrigins[i].length), nonceRoot: id(`nonce-root-${i}`), nonceIndexCount: i === 2 ? BigInt(nonceIndexes.length) : 0n }));
  const request = multiple ? { bindingIndex: 0n, artistIds, collections, expectedSource: checkpoints, replayOrigins }
    : { bindingIndex: 0n, ...collections[0], expectedSource: checkpoints, replayOrigins };
  const input = { kind, request };
  const prepared = pure.prepareArtistAuthorityHydrationCall(destination.registry, actor, input);
  const queries = collections.map(c => ({ ...c, bindingHash: id(`binding-${c.collectionId}`), records: [] }));
  const query = multiple ? queries[0] : { ...queries[0], records: journals.flat().map(r => r.recordHash) };
  const rawState = new Map();
  const identity = (artistId, records) => ({ item: { authorityAddress: artistAuthority(artistId), authorityClass: 1n, status: 1n, registeredAt: 1n, lastAuthorityActionAt: 1n,
    identityRecordHash: keccak256(artistDocument(artistId)), identityRecordURI: 'ipfs://identity', displayName: 'Artist', nonceHint: BigInt(collections.filter(c => c.artistId === artistId).length) }, document: artistDocument(artistId), nextRegistrationNonce: BigInt(artistIds.length),
    estateActivity: 1n, dormancyActivity: 1n, findingActivity: 1n, signatures: records.map(() => '0x') });
  const state = (i, q) => {
    if (i === 0) return { item: { artistId: q.artistId, artistAddress: artistAuthority(q.artistId), identityRecordHash: keccak256(artistDocument(q.artistId)), bindingHash: q.bindingHash, generation: 1n,
      consentMode: kind === 'delegation' || (combined && ['delegations', 'mode2'].includes(combinedProfile)) ? 2n : 1n, saleConsentScope: 1n, registryImmutabilityElection: 0n, proposer: actor, accepted: true },
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
  if (combined) {
    const rows = artistIds.map(artistId => {
      const records = journals.flat().filter(r => r.artistId === artistId).map(r => r.recordHash);
      const q = { artistId, collectionId: 0n, bindingHash: ZeroHash, policies: [], records };
      const history = combinedHistory.get(artistId);
      const key = keccak256(coder.encode(['bytes32', 'bytes32', 'address'], [id('6529STREAM_ARTIST_DELEGATE_NONCE_LANE_V1'), artistId, delegate]));
      const lane = nonceIndexes.find(n => n.kind === 2n && n.key === key);
      const value = { baseline: pure.encodeArtistHydrationIdentity(identity(artistId, records)), epoch: 0n,
        revisions: history.revisions, grants: history.grants,
        delegateNonces: lane ? [{ key, hint: history.grants[0].item.uses, words: lane.words }] : [] };
      const raw = pure.encodeArtistHydrationDelegationIdentity(value); put(2, q, raw);
      return { artistId, records, state: raw, nonces: nonceIndexes.find(n => n.kind === 1n && n.key === artistId).words };
    });
    ownerData[2].typedState = pure.encodeArtistHydrationOwnerState(kind, 2, { rows, collectionIds: collections.map(c => c.collectionId) });
    const bindings = [], acceptances = [], attributions = [], consents = [];
    for (const q of queries) {
      const binding = state(0, q), acceptance = state(3, q), attribution = state(4, q);
      const history = combinedHistory.get(q.artistId);
      const consent = { policies: q.policies.map(() => ({ recordHash: id(`recorded-policy-${q.collectionId}`), grant: history.grants[0].recordHash })),
        sales: history.sales.filter(s => s.item.terms.collectionId === q.collectionId) };
      put(0, q, pure.encodeArtistHydrationOwnerState('delegation', 0, binding));
      put(3, q, pure.encodeArtistHydrationOwnerState('baseline', 3, acceptance));
      put(4, q, pure.encodeArtistHydrationOwnerState('baseline', 4, attribution));
      put(6, q, pure.encodeArtistHydrationOwnerState('delegation', 6, consent));
      bindings.push({ collectionId: q.collectionId, state: binding });
      acceptances.push({ bindingHash: q.bindingHash, state: acceptance });
      attributions.push({ collectionId: q.collectionId, ...attribution });
      consents.push({ collectionId: q.collectionId, policies: q.policies, state: consent });
    }
    ownerData[0].typedState = pure.encodeArtistHydrationOwnerState(kind, 0, bindings);
    ownerData[3].typedState = pure.encodeArtistHydrationOwnerState(kind, 3, acceptances);
    ownerData[4].typedState = pure.encodeArtistHydrationOwnerState(kind, 4, attributions);
    ownerData[6].typedState = pure.encodeArtistHydrationOwnerState(kind, 6, consents);
  } else if (kind === 'multiple') {
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
  let retained = [
    { pointer: a(889), payloadType: id('ARTIST_IDENTITY_DOCUMENT'), payloadHash: keccak256('0x1234'), bytes: '0x1234' },
    { pointer: a(890), payloadType: id('ARTIST_SIGNATURE_BUNDLE'), payloadHash: keccak256('0x'), bytes: '0x' },
  ];
  if (combined) {
    retained = [];
    const add = (payloadType, bytes) => {
      const payloadHash = keccak256(bytes);
      if (!retained.some(r => r.payloadType === payloadType && r.payloadHash === payloadHash)) {
        retained.push({ pointer: a(889 + retained.length), payloadType, payloadHash, bytes });
      }
    };
    for (const artistId of artistIds) {
      add(id('ARTIST_IDENTITY_DOCUMENT'), artistDocument(artistId));
      for (const receipt of journals.flat().filter(r => r.artistId === artistId)) add(id('ARTIST_SIGNATURE_BUNDLE'), '0x');
      for (const revision of combinedHistory.get(artistId).revisions) add(id('ARTIST_IDENTITY_DOCUMENT'), revision.document);
    }
  }
  const calls = [];
  let mined = false, receipt, transaction;
  const provider = {
    getNetwork: async () => { options.network?.(); return { chainId: 1n }; },
    getBlock: async n => ({ number: n, timestamp: 100 + n, hash: options.blockHash?.(n) ?? blockHash(n) }),
    getCode: async (address, tag) => options.code?.(address, tag) ?? (address === pointer ? `0x00${evidence.slice(2)}` : retained.some(r => r.pointer === address) ? `0x00${retained.find(r => r.pointer === address).bytes.slice(2)}` : code),
    call: async tx => {
      calls.push(tx);
      const parsed = selectedAbi.parseTransaction({ data: tx.data });
      assert.ok(parsed, `Unknown selector ${tx.data.slice(0, 10)}`);
      const fn = parsed.name, args = parsed.args, tag = tx.blockTag;
      const injected = await options.read?.({ fn, args, tx });
      if (injected !== undefined) return typeof injected === 'string' ? injected : selectedAbi.encodeFunctionResult(parsed.fragment, injected);
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
      else if (fn === 'binding') values = [state(0, queries.find(q => q.collectionId === args[0])).item];
      else if (fn === 'authorityCheckpoint') values = [checkpoints[i]];
      else if (fn === 'ownerStateSnapshotV2') values = [mined && tag === 11 ? after[i] : before[i]];
      else if (fn === 'authorityHydrationCommitment') values = [mined && tag === 11 ? commitment : ZeroHash];
      else if (fn === 'artistNativeReceiptCount') values = [s === source ? BigInt(journals[i].length) : 0n];
      else if (fn === 'artistNativeReceiptAt') values = [journals[i][Number(args[0])]];
      else if (fn === 'artistHistorySourceCursor') values = [0n];
      else if (fn === 'storedPayloadCount') values = [mined && tag === 11 && [destination.owners[2], destination.archive].includes(tx.to) ? BigInt(retained.length) : 0n];
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
      return selectedAbi.encodeFunctionResult(parsed.fragment, values);
    },
    getTransaction: async () => transaction,
    getTransactionReceipt: async () => receipt,
  };
  function mine(execution = 'direct', indexed = false) {
    mined = true;
    const logs = [];
    function log(address, event, values, selected = selectedAbi) {
      const encoded = selected.encodeEventLog(selected.getEvent(event), values);
      logs.push({ address, ...encoded, index: logs.length, blockNumber: 11, blockHash: blockHash(11), transactionHash: txHash, removed: false });
    }
    for (let i = 0; i < retained.length; ++i) { const row = retained[i]; log(destination.owners[2], 'ArtistStoredPayload', [1n, BigInt(i), row.payloadType, row.payloadHash, row.pointer]); }
    log(destination.archive, 'ArtistArchiveEvidenceAppendedV2', [evidenceId, 1n, keccak256(evidence), pointer, BigInt((evidence.length - 2) / 2)]);
    log(coordinates.coordinator, 'ArtistAuthorityHydrated', [1n, query.artistId, query.collectionId, source.registry, prepared.profile, commitment]);
    if (multiple) log(coordinates.coordinator, 'MultipleArtistAuthorityHydrated', [source.registry, commitment, artistIds, collections.map(c => c.collectionId)]);
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
    commitment, source, destination, coordinates, rawState, evidence, pointer, blockHash, retained, combinedHistory, selectedAbi };
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


test('combined source selection retains mode2-only, revision-only and direct-sale-only histories', async () => {
  for (const profile of ['mode2', 'revision', 'sale', 'delegations']) {
    const s = setup('multiple-delegation', { profile }), c = await capture(s);
    assert.equal(c.prepared.input.kind, 'multiple-delegation');
    assert.equal(c.prepared.call.data.slice(0, 10), '0x4739d03d');
    assert.deepEqual(c.ownerData, s.ownerData);
    assert.deepEqual(c.query.records, []);
    assert.equal(c.query.artistId, s.input.request.collections[0].artistId);
    assert.equal(c.before[2].revision, 6n);
    assert.equal(c.checkpoints[2].ownerState.revision, BigInt(c.journals[2].length + 3 + c.journals[6].length + 1));
    assert.ok((s.evidence.length - 2) / 2 <= 24575);
  }
});


function rewriteCombinedIdentity(s, artistId, change) {
  const key = `2:${artistId}:0`, value = clone(pure.decodeArtistHydrationDelegationIdentity(s.rawState.get(key)));
  change(value);
  s.rawState.set(key, pure.encodeArtistHydrationDelegationIdentity(value));
}
function rewriteCombinedConsent(s, collection, change) {
  const key = `6:${collection.artistId}:${collection.collectionId}`;
  const value = clone(pure.decodeArtistHydrationOwnerState('delegation', 6, s.rawState.get(key)));
  change(value);
  s.rawState.set(key, pure.encodeArtistHydrationOwnerState('delegation', 6, value));
}

test('requested multiple profile must match authenticated selection without fallback', async () => {
  for (const kind of ['multiple', 'multiple-delegation']) {
    const s = setup(kind, { profile: 'mode2' });
    const mode = kind === 'multiple' ? 2n : 1n;
    s.options.read = ({ fn, args }) => {
      if (fn !== 'binding') return;
      const c = s.input.request.collections.find(c => c.collectionId === args[0]);
      const raw = s.rawState.get(`0:${c.artistId}:${c.collectionId}`);
      const item = pure.decodeArtistHydrationOwnerState(kind === 'multiple' ? 'baseline' : 'delegation', 0, raw).item;
      return [{ ...item, consentMode: mode }];
    };
    await assert.rejects(capture(s), /authenticated source selection/);
    assert.ok(!s.calls.some(tx => tx.data.slice(0, 10) === '0x4739d03d'));
  }
  const s = setup('multiple-delegation');
  s.options.read = ({ fn }) => { if (fn === 'authorityDelegationHydrationState') throw Error('original producer rejected'); };
  await assert.rejects(capture(s), /original producer rejected/);
});

test('combined global grants count uses across collections and isolate same-delegate Artist nonce lanes', async () => {
  const s = setup('multiple-delegation', { revoked: true }), c = await capture(s);
  const rows = pure.decodeArtistHydrationOwnerState('multiple-delegation', 2, c.ownerData[2].typedState).rows;
  const states = rows.map(row => pure.decodeArtistHydrationDelegationIdentity(row.state));
  assert.equal(states[0].grants[0].item.grant.delegate, states[1].grants[0].item.grant.delegate);
  assert.notEqual(states[0].delegateNonces[0].key, states[1].delegateNonces[0].key);
  assert.deepEqual(states.map(state => state.grants[0].item.uses).sort(), [1n, 2n]);
  assert.equal(c.nonceIndexes.filter(n => n.kind === 1n).length, 2);
  assert.equal(c.nonceIndexes.filter(n => n.kind === 2n).length, 2);
  assert.ok(states.every(state => state.grants[0].item.revoked && state.grants[0].item.grant.expiresAt < 110n));
  assert.ok(!s.calls.some(tx => ['delegationState', 'delegatedNonceState'].includes(s.selectedAbi.parseTransaction({ data: tx.data }).name)));
  for (const attack of ['uses', 'foreign-grant', 'swapped-words', 'duplicate-lane']) {
    const broken = setup('multiple-delegation'), [first, second] = broken.input.request.artistIds;
    if (attack === 'uses') rewriteCombinedIdentity(broken, first, value => { value.grants[0].item.uses = 0n; value.delegateNonces = []; });
    if (attack === 'foreign-grant') rewriteCombinedConsent(broken, broken.input.request.collections[0], value => {
      value.policies[0].grant = broken.combinedHistory.get(first).grants[0].recordHash;
    });
    if (attack === 'swapped-words') broken.options.read = ({ fn, args }) => {
      if (fn === 'authorityNonceWordAt' && args[0] === 2n) return [0n, [99n, ...Array(31).fill(0n)], false];
    };
    if (attack === 'duplicate-lane') rewriteCombinedIdentity(broken, first, value => {
      const other = pure.decodeArtistHydrationDelegationIdentity(broken.rawState.get(`2:${second}:0`));
      value.delegateNonces[0].key = other.delegateNonces[0].key;
    });
    await assert.rejects(capture(broken), /nonce|lane|grant|Grant|partition|scope/);
  }
});

test('combined original registration, revision and grant hashes and complete journals are joined', async () => {
  for (const attack of ['registration', 'revision-hash', 'missing-revision', 'grant-hash', 'grant-head', 'journal-before-registration', 'foreign-artist']) {
    const profile = attack.includes('revision') || attack === 'journal-before-registration' ? 'revision' : 'delegations';
    const s = setup('multiple-delegation', { profile }), artistId = s.input.request.artistIds[0];
    if (attack === 'registration') rewriteCombinedIdentity(s, artistId, value => {
      const original = clone(pure.decodeArtistHydrationIdentity(value.baseline));
      original.item.authorityAddress = a(456);
      value.baseline = pure.encodeArtistHydrationIdentity(original);
    });
    if (attack === 'revision-hash') rewriteCombinedIdentity(s, artistId, value => { value.revisions[0].item.nonce += 1n; });
    if (attack === 'missing-revision') rewriteCombinedIdentity(s, artistId, value => { value.revisions = []; });
    if (attack === 'grant-hash') rewriteCombinedIdentity(s, artistId, value => { value.grants[0].item.nonce += 1n; });
    if (attack === 'grant-head') rewriteCombinedIdentity(s, artistId, value => { value.grants[0].current = id('wrong-head'); });
    if (attack === 'journal-before-registration') s.journals[2].unshift(s.journals[2].pop());
    if (attack === 'foreign-artist') s.journals[2][0].artistId = id('unlisted-artist');
    await assert.rejects(capture(s), /registration|revision|grant|Grant|Identity|Artist|identity|record|Foreign/);
  }
});

test('combined sale history uses original record preimage and immutable historical grant association', async () => {
  for (const profile of ['sale', 'delegations']) {
    const s = setup('multiple-delegation', { profile, withSale: true }), c = await capture(s);
    const row = pure.decodeArtistHydrationOwnerState('multiple-delegation', 6, c.ownerData[6].typedState)[0].state.sales[0];
    assert.equal(row.item.authorityClass, profile === 'sale' ? 1n : 2n);
    assert.equal(row.grant === ZeroHash, profile === 'sale');
  }
  for (const attack of ['hash', 'head', 'missing', 'foreign-association']) {
    const s = setup('multiple-delegation', { withSale: true });
    rewriteCombinedConsent(s, s.input.request.collections[0], value => {
      if (attack === 'hash') value.sales[0].item.nonce += 1n;
      if (attack === 'head') value.sales[0].current = id('wrong-head');
      if (attack === 'missing') value.sales = [];
      if (attack === 'foreign-association') value.sales[0].grant = s.combinedHistory.get(s.input.request.artistIds[0]).grants[0].recordHash;
    });
    await assert.rejects(capture(s), /sale|Sales|grant|Grant/);
  }
});

test('combined compact state canonicality, input snapshots and original carrier limit stay enforced', async () => {
  const s = setup('multiple-delegation'), input = clone(s.prepared), d = clone(s.deployment);
  s.options.network = () => { input.input.request.artistIds.reverse(); d.source.coordinator.codeHash = id('mutated'); };
  const c = await workflow.captureArtistAuthorityHydration(s.provider, d, input, { blockTag: 10 });
  assert.deepEqual(c.prepared, s.prepared);
  assert.ok(Object.isFrozen(c.prepared.input.request.collections[0].policies));
  delete s.options.network;
  const forged = clone(c); forged.nonceIndexes[0].kind = '1n';
  await assert.rejects(workflow.simulateArtistAuthorityHydration(s.provider, forged, { blockTag: 12 }), /changed/);
  for (const attack of ['tag', 'trailing', 'oversized']) {
    const broken = setup('multiple-delegation'), artistId = broken.input.request.artistIds[0], key = `2:${artistId}:0`;
    if (attack === 'tag') broken.rawState.set(key, `0x${id('wrong-tag').slice(2)}${broken.rawState.get(key).slice(66)}`);
    if (attack === 'trailing') broken.rawState.set(key, `${broken.rawState.get(key)}00`);
    if (attack === 'oversized') rewriteCombinedIdentity(broken, artistId, value => {
      const original = clone(pure.decodeArtistHydrationIdentity(value.baseline));
      original.signatures = original.signatures.map(() => `0x${'11'.repeat(1500)}`);
      value.baseline = pure.encodeArtistHydrationIdentity(original);
    });
    await assert.rejects(capture(broken), /tag|canonical|limit|bound|bytes|evidence|carrier/i);
  }
});

test('combined direct and both Safe receipts retain atomic roots, profile and full per-Artist payload order', async () => {
  for (const [profile, execution, indexed] of [['revision', 'direct', false], ['mode2', 'safe', false], ['delegations', 'safe', true]]) {
    const s = setup('multiple-delegation', { profile }), c = await capture(s); s.mine(execution, indexed);
    const r = await workflow.inspectArtistAuthorityHydrationReceipt(s.provider, c, s.txHash, { execution });
    assert.equal(r.commitment, c.commitment);
    assert.equal(r.observedOwners.length, 7);
    assert.ok(r.events.some(event => event.event === 'MultipleArtistAuthorityHydrated'));
    if (profile === 'revision') {
      assert.equal(s.retained.length, 4);
      assert.equal(s.retained[1].payloadType, id('ARTIST_SIGNATURE_BUNDLE'));
      assert.equal(s.retained[2].bytes, '0xabcd');
      assert.notEqual(s.retained[0].bytes, s.retained[3].bytes);
    }
    const safe = createSafeCallPlan(1n, 'Review combined hydration', [{ safe: c.prepared.caller, intent: 'Hydrate complete original history', call: c.prepared.call, abi: combinedFixture.abis.artist }]);
    assert.equal(safe.steps[0].transaction.operation, 0);
    assert.equal(safe.steps[0].transaction.data, c.prepared.call.data);
  }
});

test('combined receipts reject omitted revision payloads, false profile evidence and reordered Safe completion', async () => {
  for (const attack of ['revision-payload', 'row-order', 'multiple-event', 'profile', 'safe-order']) {
    const s = setup('multiple-delegation', { profile: 'revision' }), c = await capture(s), { receipt } = s.mine('safe');
    if (attack === 'revision-payload') receipt.logs = receipt.logs.filter(log => {
      const parsed = s.selectedAbi.parseLog(log);
      return parsed?.name !== 'ArtistStoredPayload' || parsed.args.payloadHash !== keccak256('0xabcd');
    });
    if (attack === 'row-order') {
      [receipt.logs[2], receipt.logs[3]] = [receipt.logs[3], receipt.logs[2]];
      receipt.logs.forEach((log, i) => { log.index = i; });
    }
    if (attack === 'multiple-event') receipt.logs = receipt.logs.filter(log => s.selectedAbi.parseLog(log)?.name !== 'MultipleArtistAuthorityHydrated');
    if (attack === 'profile') {
      const log = receipt.logs.find(log => s.selectedAbi.parseLog(log)?.name === 'ArtistAuthorityHydrated');
      const encoded = s.selectedAbi.encodeEventLog(s.selectedAbi.getEvent('ArtistAuthorityHydrated'), [1n, s.query.artistId, s.query.collectionId, s.source.registry, pure.ARTIST_HYDRATION_PROFILES.multiple, s.commitment]);
      Object.assign(log, encoded);
    }
    if (attack === 'safe-order') { receipt.logs.unshift(receipt.logs.pop()); receipt.logs.forEach((log, i) => { log.index = i; }); }
    await assert.rejects(workflow.inspectArtistAuthorityHydrationReceipt(s.provider, c, s.txHash, { execution: 'safe' }), /payload|order|Multiple|event|Safe|Hydrated/);
  }
});
