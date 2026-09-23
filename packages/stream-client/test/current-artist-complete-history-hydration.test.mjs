// Supplied-fact carrier checks. No EVM execution, signature admission or private
// original Composition reconstruction is asserted by these synthetic fixtures.
import test from 'node:test';
import assert from 'node:assert/strict';
import { AbiCoder, ParamType, ZeroHash, ZeroAddress, id, keccak256 } from 'ethers';
import * as m from '../dist/current-artist-complete-history-hydration.js';
import { createArtistRecoveredHydrationCodec } from '../dist/internal/artist-recovered-hydration-codec.js';
import { semanticFixture, refresh, T, zero, A, H, findType } from './current-artist-complete-history-hydration-semantic-fixture.mjs';

const coder = AbiCoder.defaultAbiCoder(), clone = structuredClone, Z = ZeroHash;
const P = 'ARTIST_COMPLETE_HISTORY_HYDRATION_', cache = new Map();
const sample = (options = {}) => { const key = JSON.stringify(options); if (!cache.has(key)) cache.set(key, semanticFixture({ options })); return cache.get(key); };
const child = (type, name) => type.components.find(field => field.name === name);
const bare = type => type.baseType === 'array' ? `${bare(type.arrayChildren)}[${type.arrayLength < 0 ? '' : type.arrayLength}]`
  : type.baseType === 'tuple' ? `tuple(${type.components.map(field => field.format('full')).join(',')})` : type.type;
const local = (f, i) => m.artistCompleteHistoryHydrationOwnerProvenance(f.certificate.admission.provenance, i);
const plain = (p, value) => p.baseType === 'tuple' ? Object.fromEntries(p.components.map((c, i) => [c.name, plain(c, value[i])]))
  : p.baseType === 'array' ? Array.from(value, v => plain(p.arrayChildren, v)) : value;
const prepared = f => m.normalizeArtistCompleteHistoryHydrationPrepared(f.certificate);
function check(f) {
  const p = prepared(f), composition = m.validateArtistCompleteHistoryHydrationComposition(p);
  m.validateArtistCompleteHistoryHydrationInput(f.input, p);
  assert.equal(composition.factsVerified, false);
  assert.equal(composition.originalCompositionAdmissionIndependentlyVerified, false);
  return composition;
}

// Rebuild using raw independent ABI wrappers, not the admitted encoder, so
// malformed semantic facts still carry internally consistent outer commitments.
function inventoryHash(f) {
  const p = f.certificate;
  f.request.expectedSemanticInventory = keccak256(coder.encode([
    'bytes32', 'uint16', 'bytes32', child(T.prepared, 'query'), child(T.prepared, 'data'), child(T.prepared, 'timing'), child(T.prepared, 'externalGuards'),
  ], [id('6529STREAM_ARTIST_RECOVERED_SEMANTIC_INVENTORY_V1'), 1n,
    m.artistCompleteHistoryHydrationProvenanceHash(p.admission.provenance), p.query, p.data, p.timing, p.externalGuards]));
}
function rawReplace(f, owner, edit) {
  const outerType = ParamType.from(m[P + 'ENVELOPE_TUPLE']);
  const outer = plain(outerType, coder.decode(['bytes32', 'uint16', outerType], f.certificate.data[owner].typedState)[2]);
  const payloadType = ParamType.from(m[P + 'OWNER_PAYLOAD_TUPLE']);
  const payload = plain(payloadType, coder.decode(['bytes32', 'uint16', payloadType], outer.payload)[2]);
  const carrier = coder.decode(['bytes32', 'uint16', 'uint8', T.state, 'bytes'], payload.semanticState);
  const state = plain(T.state, carrier[3]), context = { auxiliary: carrier[4], header: outer.header };
  edit(state, context, payload);
  payload.semanticState = coder.encode(['bytes32', 'uint16', 'uint8', T.state, 'bytes'], [m[P + 'SCHEMA'], 1n, BigInt(owner), state, context.auxiliary]);
  context.header.semanticInventory = keccak256(payload.semanticState);
  outer.payload = coder.encode(['bytes32', 'uint16', payloadType], [m[P + 'PAYLOAD_SCHEMA'], 1n, payload]);
  outer.header = context.header;
  f.certificate.data[owner].typedState = coder.encode(['bytes32', 'uint16', outerType], [m.artistCompleteHistoryHydrationOwnerTag(owner), 1n, outer]);
  inventoryHash(f);
}
function commonReplace(f, inventory) {
  const raw = coder.encode([T.inventory], [inventory]);
  for (let owner = 0; owner < 7; owner++) rawReplace(f, owner, (_s, c) => { c.auxiliary = raw; });
}
function rawEvidence(f) {
  const p = f.certificate, admission = child(T.prepared, 'admission');
  return coder.encode(['bytes32', 'uint16', 'address', 'address', m[P + 'REQUEST_TUPLE'], child(admission, 'artists'), child(admission, 'collections'),
    child(T.prepared, 'query'), child(T.prepared, 'data'), child(T.prepared, 'timing'), child(T.prepared, 'externalGuards')],
  [m[P + 'PROFILE'], 1n, p.admission.prior, p.admission.sourceCoordinator, f.request, p.admission.artists, p.admission.collections,
    p.query, p.data, p.timing, p.externalGuards]);
}
function refusesBoth(f, pattern) {
  assert.throws(() => prepared(f), pattern);
  assert.throws(() => m.decodeArtistCompleteHistoryHydrationProfileEvidence(rawEvidence(f)), pattern);
}

test('COMPLETE preserves original domains and is refused by every earlier closed profile', () => {
  const f = sample();
  assert.equal(m[P + 'BASE'], 33554432n); assert.equal(m[P + 'ALLOWED_FEATURES'], 33816575n);
  assert.equal(m[P + 'KNOWN_FEATURES'], 67108863n); assert.equal(m[P + 'SCHEMA'], id('6529STREAM_ARTIST_COMPLETE_HISTORY_V1'));
  for (const mask of [255n, 511n, 262175n, 524671n, 1049087n, 2276351n, 4194335n, 16956415n]) {
    const old = createArtistRecoveredHydrationCodec(mask);
    assert.equal(old.artistRecoveredHydrationOriginHash(f.origin), m.artistCompleteHistoryHydrationOriginHash(f.origin));
    for (let i = 0; i < 7; i++) assert.equal(old.artistRecoveredHydrationOwnerDomain(i), m.artistCompleteHistoryHydrationOwnerDomain(i));
    assert.throws(() => old.decodeArtistRecoveredHydrationOwnerPayload(f.certificate.data[4].typedState, 4), /feature|profile|header/i);
  }
  assert.throws(() => createArtistRecoveredHydrationCodec(33554432n), /profile/i);
  assert.equal(m.ARTIST_COMPLETE_HISTORY_HYDRATION_VALIDATION.actualRegistrySimulationRequired, true);
  assert.equal(m.ARTIST_COMPLETE_HISTORY_HYDRATION_VALIDATION.signatureExecutionIndependentlyVerified, false);
});

test('genuine compiler-shaped raw DTO codecs remain structural and canonically bounded', () => {
  const f = sample({ historical: true });
  const rows = [['Inventory', T.inventory, f.common], ['BindingBundle', T.binding, f.bindings[0]], ['AcceptanceBundle', T.acceptance, f.acceptances[0]],
    ['Platform', T.platform, f.platforms[0]], ['Identity', T.identity, f.identities[0]], ['Attribution', T.attribution, f.attribution[0]],
    ['Consents', T.consents, f.supplements[0].original], ['StateTuple', T.state, f.states[4]]];
  for (const [name, type, value] of rows) {
    const bytes = coder.encode([type], [value]);
    assert.equal(m['encodeArtistCompleteHistoryHydration' + name](value), bytes);
    assert.deepEqual(m['decodeArtistCompleteHistoryHydration' + name](bytes), value);
    assert.throws(() => m['decodeArtistCompleteHistoryHydration' + name](bytes + '00'.repeat(32)), /canonical/i);
  }
  const raw = zero(T.inventory);
  assert.deepEqual(m.decodeArtistCompleteHistoryHydrationInventory(m.encodeArtistCompleteHistoryHydrationInventory(raw)), raw);
  assert.throws(() => m.validateArtistCompleteHistoryHydrationInventory(raw), /provenance|origin|era|array|count|cardinality/i);
});

test('Archive uses its original flat fields and Payout retains its separate tag', () => {
  const f = sample({ historical: true }), source = f.archiveRows[0].raw;
  const e = m.decodeArtistCompleteHistoryHydrationArchiveEnvelope(source);
  assert.equal(m.encodeArtistCompleteHistoryHydrationArchiveEnvelope(e), coder.encode(T.envelope.components, T.envelope.components.map(p => e[p.name])));
  assert.throws(() => m.decodeArtistCompleteHistoryHydrationArchiveEnvelope(coder.encode([T.envelope], [e])), /Recovered ABI allocation capacity/);
  const payout = f.payouts[0], bytes = coder.encode(['bytes32', T.payout], [id('6529STREAM_ARTIST_RECOVERED_PAYOUT_HYDRATION_V1'), payout]);
  assert.equal(m.encodeArtistCompleteHistoryHydrationPayout(payout), bytes);
  assert.deepEqual(m.decodeArtistCompleteHistoryHydrationPayout(bytes), payout);
  assert.throws(() => m.decodeArtistCompleteHistoryHydrationPayout(coder.encode(['bytes32', T.payout], [H('wrong tag'), payout])), /Payout/);
});

test('aggregate consent extension has one canonical tagged or untagged representation', () => {
  const s = clone(sample({ historical: true }).supplements[0]);
  assert.equal(m.encodeArtistCompleteHistoryHydrationConsentsSupplement(s), coder.encode([T.consents], [s.original]));
  assert.deepEqual(m.decodeArtistCompleteHistoryHydrationConsentsSupplement(coder.encode([T.consents], [s.original])), s);
  assert.throws(() => m.decodeArtistCompleteHistoryHydrationConsentsSupplement(coder.encode(['bytes32', 'uint16', T.supplement], [m[P + 'SUPPLEMENT_SCHEMA'], 1n, s])), /empty|canonical/);
  s.ratifications.push({ recordHash: H('ratification'), contentStateHash: H('content'), metadataContract: A(92) });
  const raw = coder.encode(['bytes32', 'uint16', T.supplement], [m[P + 'SUPPLEMENT_SCHEMA'], 1n, s]);
  assert.equal(m.encodeArtistCompleteHistoryHydrationConsentsSupplement(s), raw);
  assert.deepEqual(m.decodeArtistCompleteHistoryHydrationConsentsSupplement(raw), s);
  assert.throws(() => m.decodeArtistCompleteHistoryHydrationConsentsSupplement(coder.encode(['bytes32', 'uint16', T.supplement], [m[P + 'SUPPLEMENT_SCHEMA'], 2n, s])), /canonical/);
});

for (const [name, options] of [['zero-principal Platform', {}], ['historical Artist with royalty', { historical: true }],
  ['historical Artist without royalty', { historical: true, royalties: false }], ['repeated original Platform eras', { repeated: true }]]) {
  test(`COMPLETE ${name} supplied composition retains all seven common inventories`, () => {
    const f = sample(options), c = check(f);
    assert.equal(c.requiredFeatures, f.features);
    const aux = [];
    for (let i = 0; i < 7; i++) {
      const body = m.decodeArtistCompleteHistoryHydrationOwnerPayload(f.certificate.data[i].typedState, i);
      const decoded = m.decodeArtistCompleteHistoryHydrationAuxiliary(body.payload.semanticState, i, body.payload.provenance);
      aux.push(decoded.auxiliary); assert.deepEqual(decoded.state, f.states[i]);
    }
    assert.equal(new Set(aux).size, 1);
    if (options.historical) {
      assert.equal(c.identities.length, 2); assert.equal(f.bindings[0].bindings.current.accepted, false);
      assert.notEqual(f.contents[0].original.economics[0].item.association.artistId, f.collections[0].artistId);
      assert.deepEqual(f.certificate.query.records, f.artists.find(a => a.artistId === f.collections[0].artistId).records);
    } else {
      assert.equal(c.identities.length, 0); assert.deepEqual(f.certificate.query.records, f.collections[0].records);
      assert.equal(f.certificate.externalGuards.schema, id('6529STREAM_ARTIST_UNBOUND_PLATFORM_HYDRATION_V1'));
    }
    if (options.repeated) assert.equal(c.inventory.archive.catalogues.length, 2);
  });
}

test('fully rehashed common catalogue omissions and cutoff substitutions fail both admissions', () => {
  for (const mutate of [v => { v.archive.catalogues = []; }, v => { v.archive.catalogues[0].originHash = H('other era'); }, v => { v.archive.catalogues[0].upper[6]++; }]) {
    const f = clone(sample()), v = clone(f.common); mutate(v); commonReplace(f, v);
    refusesBoth(f, /catalogue|cutoff|roster|origin/i);
  }
});

test('locally coherent owner auxiliary substitution cannot replace the all-seven shared inventory', () => {
  const f = clone(sample()), v = clone(f.common); v.archive.catalogues[0].rowsHash = H('different retained inventory');
  rawReplace(f, 1, (_s, c) => { c.auxiliary = coder.encode([T.inventory], [v]); });
  refusesBoth(f, /all-seven.*auxiliary/i);
});

test('rehashed scope omissions and historical Artist substitution preserve the native partition guard', () => {
  const missing = clone(sample()); rawReplace(missing, 4, s => { s.collections[0].records = []; });
  refusesBoth(missing, /scope|native|partition/i);
  const historical = clone(sample({ historical: true })), v = clone(historical.common);
  v.bindings.bindings[0].bindings.rows[0].item.artistId = H('unselected historical Artist');
  commonReplace(historical, v); refusesBoth(historical, /Historical binding principal/);
});

test('acceptance times and owner row projections cannot be substituted under a rehashed common inventory', () => {
  const f = clone(sample({ historical: true })), v = clone(f.common); v.accepted[0].rows[0].acceptedAt = 0n;
  commonReplace(f, v); refusesBoth(f, /Acceptance generation\/record-time/);
  const row = clone(sample({ historical: true })), changed = clone(row.acceptances[0]); changed.rows[0].recordHash = H('replacement acceptance');
  rawReplace(row, 3, s => { s.rows[0] = coder.encode([T.acceptance], [changed]); });
  refusesBoth(row, /Binding\/Acceptance rows differ/);
});

test('exact required feature union is independent of capability advertisement and retained header claims', () => {
  const f = clone(sample());
  for (let i = 0; i < 7; i++) rawReplace(f, i, (_s, c) => { c.header.requiredFeatures |= 8n; });
  refusesBoth(f, /required-feature union/);
  const original = sample({ historical: true });
  assert.equal(m.artistCompleteHistoryHydrationRequiredFeatures(original.identities, original.payouts, original.common, original.attribution, original.supplements), original.features);
  const changed = clone(original.identities); changed[0].identity.authorityClass = 4n;
  assert.throws(() => m.artistCompleteHistoryHydrationRequiredFeatures(changed, original.payouts, original.common, original.attribution, original.supplements), /Class1\/3/);
});

test('nonce union retains disjoint collaborator account lanes in original insertion order', () => {
  const f = sample(), cp = clone(f.provenance.eras.at(-1).checkpoints[2]);
  const indexType = child(ParamType.from(m[P + 'NONCE_INVENTORY_TUPLE']), 'index'), wordType = child(ParamType.from(m[P + 'NONCE_INVENTORY_TUPLE']), 'words').arrayChildren;
  const key = '0x' + BigInt(A(91)).toString(16).padStart(64, '0'), word = zero(wordType); word.words[0] = 1n;
  const index = { ...zero(indexType), kind: 3n, key, prefixCount: 1n }, global = [{ index, words: [word] }], account = { kind: 3n, key, hint: 0n, words: [word] };
  cp.nonceIndexCount = 1n;
  assert.deepEqual(m.artistCompleteHistoryHydrationNonceUnion(f.states[2], global, cp, [account]), [account]);
  assert.throws(() => m.artistCompleteHistoryHydrationNonceUnion(f.states[2], global, cp, []), /Incomplete global nonce partition/);
  assert.throws(() => m.artistCompleteHistoryHydrationNonceUnion(f.states[2], global, cp, [{ ...account, key: H('not an address') }]), /account nonce/);
  assert.throws(() => m.artistCompleteHistoryHydrationNonceUnion(f.states[2], global, cp, [account, account]), /bijection/);
});

test('standalone profile evidence joins whole replay cells and source coordinates after full rehashing', () => {
  const f = sample(), raw = m.encodeArtistCompleteHistoryHydrationProfileEvidence(f.request, f.certificate);
  assert.deepEqual(m.decodeArtistCompleteHistoryHydrationProfileEvidence(raw).request, f.request);
  const cell = clone(f); cell.certificate.data = clone(cell.certificate.data);
  cell.certificate.data[2].cells[0].touchedRevision++; inventoryHash(cell);
  assert.throws(() => m.decodeArtistCompleteHistoryHydrationProfileEvidence(rawEvidence(cell)), /guard differs from original replay alias/);
  const source = clone(f); source.certificate.admission.sourceCoordinator = A(818);
  assert.throws(() => m.decodeArtistCompleteHistoryHydrationProfileEvidence(rawEvidence(source)), /request\/source selection/);
  const external = clone(f); external.certificate.externalGuards = clone(external.certificate.externalGuards);
  external.certificate.externalGuards.provenanceCommitment = H('wrong full provenance'); inventoryHash(external);
  assert.throws(() => m.decodeArtistCompleteHistoryHydrationProfileEvidence(rawEvidence(external)), /external guards/i);
});

test('historical economics and global royalty witnesses select the unchanged original two or three argument route', () => {
  for (const options of [{}, { historical: true }, { historical: true, royalties: false }]) {
    const f = sample(options), input = m.validateArtistCompleteHistoryHydrationInput(f.input, f.certificate), call = m.prepareArtistCompleteHistoryHydrationCall(A(900), A(901), input);
    const hasRoyalties = input.royaltyFreezes.length !== 0;
    assert.equal(call.capabilityId, hasRoyalties ? '0x1e2d2f62' : '0xb80889ba');
    assert.equal(call.call.value, 0n); assert.equal(call.factsVerified, false);
    assert.deepEqual(m.normalizeArtistCompleteHistoryHydrationCall(call), call);
    assert.equal(m.artistCompleteHistoryHydrationPreparationCalldata(f.source, input).slice(0, 10), hasRoyalties ? '0x4925300f' : '0x72c84763');
    assert.throws(() => m.normalizeArtistCompleteHistoryHydrationCall({ ...call, call: { ...call.call, value: 1n } }), /immutable input/);
  }
  const f = sample({ historical: true });
  const repeatedTerms = [f.input.royaltyFreezes[0], f.input.royaltyFreezes[0]];
  assert.deepEqual(m.normalizeArtistCompleteHistoryHydrationRoyaltyFreezes(repeatedTerms), repeatedTerms);
  assert.throws(() => m.validateArtistCompleteHistoryHydrationInput({ request: f.request, royaltyFreezes: [] }, f.certificate), /global operation20 order/);
  const request = clone(f.request); request.records.witnesses[0].economics[0].assignmentHash = H('replaced old Artist economics');
  assert.throws(() => m.validateArtistCompleteHistoryHydrationInput({ request, royaltyFreezes: f.input.royaltyFreezes }, f.certificate), /witness/i);
});

test('public wrappers reject getters and aggregate hostile arrays before executing supplied accessors', () => {
  let called = 0;
  for (const [fn, value] of [
    [m.normalizeArtistCompleteHistoryHydrationInputDraft, { get request() { called++; throw Error('getter ran'); }, royaltyFreezes: [] }],
    [m.normalizeArtistCompleteHistoryHydrationCall, { ...m.prepareArtistCompleteHistoryHydrationCall(A(900), A(901), sample().input), get call() { called++; throw Error('getter ran'); } }],
  ]) assert.throws(() => fn(value), /owned original data/);
  assert.equal(called, 0);
  const f = sample(), s = clone(f.states[4]);
  Object.defineProperty(s.rows, 0, { enumerable: true, configurable: true, get() { called++; throw Error('array getter ran'); } });
  assert.throws(() => m.normalizeArtistCompleteHistoryHydrationState(s), /owned original data/); assert.equal(called, 0);
  const hidden = clone(f.common); Object.defineProperty(hidden.archive.catalogues, 'extra', { value: 1 });
  assert.throws(() => m.normalizeArtistCompleteHistoryHydrationInventory(hidden), /array|propert|field|key/i);
  const large = clone(f.states[4]); large.rows = Array(128).fill('0x' + 'ab'.repeat(150000));
  assert.throws(() => m.normalizeArtistCompleteHistoryHydrationState(large), /capacity|allocation|byte|bound/i);
});

test('ABI preflight rejects impossible dynamic counts before materializing decoded arrays', () => {
  const raw = m.encodeArtistCompleteHistoryHydrationStateTuple({ artists: [], collections: [], rows: [] });
  const bytes = Buffer.from(raw.slice(2), 'hex');
  const base = Number(BigInt('0x' + bytes.subarray(0, 32).toString('hex'))), offset = Number(BigInt('0x' + bytes.subarray(base, base + 32).toString('hex')));
  bytes.fill(255, base + offset, base + offset + 32);
  assert.throws(() => m.decodeArtistCompleteHistoryHydrationStateTuple('0x' + bytes.toString('hex')), /count|bound|capacity|array|allocation|offset/i);
  assert.throws(() => m.decodeArtistCompleteHistoryHydrationInventory('0x' + '00'.repeat(33)), /ABI|byte|bound|length|offset/i);
});

test('Platform occurrence projection keeps contest11 and correction53 distinct after full rehashing', () => {
  // These two rows isolate the independently checkable occurrence projection.
  // Original Platform transition/record preimages remain original-call admission.
  function occurrence(operation, swap = false) {
    const f = clone(sample()), p = f.platforms[0], native = f.provenance.journals[4][0];
    const point = clone(native.position.point), recordHash = H(`original Platform family ${operation}`);
    p.allegations = []; p.allegationCount = 0n; p.latestAllegation = Z; p.latestDisplayClaim = Z;
    if (operation === 11n) {
      const row = zero(child(T.platform, 'contests').arrayChildren);
      row.point = point; row.record.recordHash = recordHash; row.record.collectionId = p.collectionId;
      p.contests = [row];
    } else {
      p.state.correction.recordHash = recordHash; p.state.correction.collectionId = p.collectionId;
      p.correctionPoint = point;
    }
    native.receipt.operation = swap ? operation === 11n ? 53n : 11n : operation;
    native.receipt.recordHash = recordHash;
    const envelope = m.decodeArtistCompleteHistoryHydrationArchiveEnvelope(f.archiveRows[0].raw);
    const changed = { ...envelope, operation: native.receipt.operation, value: recordHash };
    const raw = coder.encode(T.envelope.components, T.envelope.components.map(t => changed[t.name]));
    const evidenceId = keccak256(coder.encode(['bytes32', 'uint256', 'address', 'address', 'uint16', 'address', 'bytes32'],
      [id('6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1'), f.origin.chainId, f.origin.registry, f.origin.coordinator, changed.operation, changed.actor, recordHash]));
    Object.assign(f.archiveRows[0], { raw, hash: keccak256(raw), evidenceId });
    f.operations[0].operation = changed.operation;
    Object.assign(f.operations[0].evidence, { payloadHash: keccak256(raw), evidenceId });
    return refresh(f);
  }
  for (const operation of [11n, 53n]) {
    const positive = occurrence(operation); check(positive);
    assert.equal(positive.common.archive.operations[0].operation, operation);
    const bad = occurrence(operation, true);
    refusesBoth(bad, /Original Platform native occurrence mismatch/);
  }
});
