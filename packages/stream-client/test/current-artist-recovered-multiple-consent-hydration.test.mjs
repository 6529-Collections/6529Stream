import test from "node:test";
import assert from "node:assert/strict";
import { ZeroHash, id } from "ethers";
import * as base from "../dist/current-artist-recovered-multiple-hydration.js";
import * as singleton from "../dist/current-artist-recovered-hydration.js";
import * as consent from "../dist/current-artist-recovered-consent-hydration.js";
import { toSafeCall } from "../dist/safe.js";
import { m, semanticFixture, refresh, T, child, zero, coder, H, A, hash, delegateLane, grantRecord, grantDigest, saleRecord } from "./current-artist-recovered-multiple-consent-hydration-semantic-fixture.mjs";
import { compiledInterfaces } from "./current-artist-recovered-multiple-consent-hydration-source-fixture.mjs";

const clone = structuredClone, Z = ZeroHash;
const local = (f, owner) => m.artistRecoveredMultipleConsentHydrationOwnerProvenance(f.provenance, owner);
const contentCheck = f => m.validateArtistRecoveredMultipleConsentHydrationContentBundles(f.contents, f.collections, local(f, 6));
const grantsCheck = f => m.validateArtistRecoveredMultipleConsentHydrationGrantUses(f.identities, f.collections, f.contents, f.bindings, f.provenance);
const identityCheck = (f, i = 0) => m.validateArtistRecoveredMultipleConsentHydrationDelegations(f.identities[i], local(f, 2));
function originalAlias(f, point, surface, scope, commitment) {
  const entry = { surface: id(surface), scope };
  f.provenance.aliases[2].push({ originHash: point.environmentHash, ownerIndex: 2n, ...entry,
    originalKey: m.artistRecoveredMultipleConsentHydrationReplayKey(f.origin, 2, entry),
    cell: { commitment, touchedRevision: point.ownerRevision, kind: 1n, status: 2n }, admittedAt: clone(point) });
}
function syncIdentityCounts(f) {
  const era = f.provenance.eras[0]; era.nativeCounts[2] = BigInt(f.provenance.journals[2].length);
  era.checkpoints[2].replayCount = BigInt(f.provenance.aliases[2].length);
  f.provenance.aliases[2].sort((a, b) => BigInt(a.originalKey) < BigInt(b.originalKey) ? -1 : 1);
}

test("new tag and feature ceiling distinguish direct, delegated and content-required plural graphs", () => {
  for (const delegated of [false, true]) {
    const f = semanticFixture({ delegated });
    const p = m.normalizeArtistRecoveredMultipleConsentHydrationPrepared(f.prepared);
    assert.equal(m.artistRecoveredMultipleConsentHydrationRequiredFeatures(f.identities, f.payouts, 1n, f.bindings, f.contents), f.features);
    assert.deepEqual(m.validateArtistRecoveredMultipleConsentHydrationInput(f.input, p), f.input);
    for (let i = 0; i < 7; i++) assert.equal(m.decodeArtistRecoveredMultipleConsentHydrationOwnerPayload(p.data[i].typedState, i).header.requiredFeatures, f.features);
    assert.equal(f.features & 262144n, 0n); assert.equal(f.request.expectedCapabilities[0].supportedFeatures, 1048575n);
  }
  assert.equal(m.ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_BASE, 524288n);
  assert.equal(m.ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_ALLOWED_FEATURES, 524671n);
});

test("one Artist with multiple collections remains supported and frozen old profiles remain strict", () => {
  const f = semanticFixture({ oneArtist: true, collectionCount: 2, classes: [3n] });
  assert.equal(m.normalizeArtistRecoveredMultipleConsentHydrationPrepared(f.prepared).admission.before_[2].revision, 4n);
  assert.throws(() => base.normalizeArtistRecoveredMultipleHydrationPrepared(f.prepared));
  assert.throws(() => singleton.normalizeArtistRecoveredHydrationPrepared(f.prepared));
  assert.throws(() => consent.normalizeArtistRecoveredConsentHydrationPrepared(f.prepared));
  const bytes = coder.encode(["bytes32", "uint16", "uint8", T.state], [id("6529STREAM_ARTIST_RECOVERED_MULTIPLE_BASE_V1"), 1n, 1n, f.states[1]]);
  assert.throws(() => m.decodeArtistRecoveredMultipleConsentHydrationState(bytes, 1, local(f, 1)), /tag|version|owner|canonical/i);
});

test("both closed Registry and nominal Prepared routes preserve global royalty order and Safe CALL0", () => {
  for (const royalties of [false, true]) {
    const f = semanticFixture({ royalties }), plan = m.prepareArtistRecoveredMultipleConsentHydrationCall(f.coords.registry, A(991), f.input);
    assert.deepEqual(m.normalizeArtistRecoveredMultipleConsentHydrationCall(plan), plan);
    const name = royalties ? "hydrateRecoveredArtistAuthorityWithConsents" : "hydrateRecoveredArtistAuthority";
    assert.equal(plan.call.data, compiledInterfaces.registry.encodeFunctionData(name, royalties ? [f.request, f.input.royaltyFreezes] : [f.request]));
    assert.deepEqual(toSafeCall(plan.call), { to: f.coords.registry, value: "0", data: plan.call.data, operation: 0 });
    const safe = toSafeCall(plan.call); assert.equal(safe.operation, 0);
    assert.equal(m.artistRecoveredMultipleConsentHydrationPreparationCalldata(f.source, f.input).slice(0, 10), royalties ? "0x4925300f" : "0x72c84763");
    for (const change of [p => { p.call.value = 1n; }, p => { p.call.data += "00"; }, p => { p.call.to = A(992); }, p => { p.factsVerified = true; }]) {
      const altered = clone(plan); change(altered); assert.throws(() => m.normalizeArtistRecoveredMultipleConsentHydrationCall(altered));
    }
  }
});

test("economics witnesses are complete collection partitions and royalties follow global journal occurrences", () => {
  const f = semanticFixture();
  assert.notDeepEqual(f.input.royaltyFreezes.map(r => r.collectionId), f.collections.map(q => q.collectionId));
  for (const mutate of [i => i.royaltyFreezes.reverse(), i => i.royaltyFreezes.pop(), i => i.royaltyFreezes.push(clone(i.royaltyFreezes[0])),
    i => i.request.records.witnesses.reverse(), i => i.request.records.witnesses.pop(),
    i => { i.request.records.witnesses[0].economics[0].assignmentHash = H(991); },
    i => { i.request.records.witnesses[0].attestations = [{ terms: { collectionId: f.collections[0].collectionId, subjectKind: 0n, subjectId: H(9), subjectStateHash: Z, schemaId: H(8), statementHash: H(7), statementURI: "ipfs://no-op24" }, nonce: 0n }]; }]) {
    const input = clone(f.input); mutate(input); assert.throws(() => m.validateArtistRecoveredMultipleConsentHydrationInput(input, f.prepared));
  }
});

test("raw ContentBundle codecs preserve original signature-free fields and canonical ABI shape", () => {
  const f = semanticFixture(), raw = coder.encode([T.content], [f.contents[0]]);
  assert.equal(m.encodeArtistRecoveredMultipleConsentHydrationContentBundle(f.contents[0]), raw);
  const decoded = m.decodeArtistRecoveredMultipleConsentHydrationContentBundle(raw);
  assert.deepEqual(decoded, f.contents[0]); assert.ok(Object.isFrozen(decoded.original.economics));
  assert.throws(() => m.decodeArtistRecoveredMultipleConsentHydrationContentBundle(raw + "00".repeat(32)), /canonical/i);
  const zeros = zero(T.content);
  assert.deepEqual(m.decodeArtistRecoveredMultipleConsentHydrationContentBundle(coder.encode([T.content], [zeros])), zeros);
  assert.throws(() => m.validateArtistRecoveredMultipleConsentHydrationContentBundles([zeros], [f.collections[0]], local(f, 6)));
});

test("six families retain immutable collection, generation, state and original sale-record associations", () => {
  const baseline = semanticFixture({ delegated: false }); assert.equal(contentCheck(baseline).length, 3);
  for (const mutate of [f => { f.contents[0].original.artistId = f.contents[2].original.artistId; }, f => { f.contents[0].consents[0].bindingGeneration = 2n; },
    f => { f.contents[0].consents[0].authorityClass = 2n; }, f => { f.contents[0].freezes[0].lockClasses.reverse(); },
    f => { f.contents[0].royalties[0].terms.revenueClass = H(10); }, f => { f.contents[0].original.economics[0].item.association.bindingHash = H(11); },
    f => { f.contents[0].original.sales[0].item.signedAt++; }, f => { f.contents[0].original.sales[0].current = H(12); },
    f => { f.contents[0].original.keys[0].phaseId = H(13); }]) {
    const f = semanticFixture({ delegated: false }); mutate(f); assert.throws(() => contentCheck(f));
  }
});

test("global Consent counts, aliases and era clocks cannot hide missing, extra or relabeled occurrences", () => {
  for (const mutate of [f => { f.contents[0].consents = []; }, f => { f.contents[0].original.policies.push(clone(f.contents[0].original.policies[0])); },
    f => { f.provenance.journals[6][0].receipt.operation = 24n; }, f => { f.provenance.journals[6][0].position.point.ownerRevision++; },
    f => { f.provenance.aliases[6][0].cell.commitment = H(991); }, f => { f.provenance.aliases[6][0].admittedAt.ownerRevision++; },
    f => { f.provenance.eras[0].checkpoints[6].ownerState.revision++; }, f => { f.provenance.journals[6][1].receipt.recordHash = f.provenance.journals[6][0].receipt.recordHash; }]) {
    const f = semanticFixture(); mutate(f); assert.throws(() => contentCheck(f));
  }
});

test("grant use is counted once per retained version across both selected collections", () => {
  const f = semanticFixture(); assert.doesNotThrow(() => grantsCheck(f));
  const shared = f.identities.find(b => f.collections.filter(q => q.artistId === b.artistId).length === 2);
  assert.equal(shared.delegations[0].record.uses, 8n);
  shared.delegations[0].record.uses = 4n;
  assert.throws(() => grantsCheck(f), /complete|uses|cross.collection/i);
  shared.delegations[0].record.uses = 8n;
  f.contents[0].original.policies[0].grant = Z;
  assert.throws(() => grantsCheck(f), /complete|uses|cross.collection/i);
});

test("original grant domain, digest and Artist/delegate lanes match independent preimages", () => {
  const f = semanticFixture();
  for (const identity of f.identities) {
    const d = identity.delegations[0];
    assert.equal(m.artistRecoveredMultipleConsentHydrationGrantRecordHash(f.origin, d.record), grantRecord(f.origin, d.record.grant, d.record.nonce));
    assert.equal(m.artistRecoveredMultipleConsentHydrationGrantDigest(f.origin, d.record), grantDigest(f.origin, d.record.grant, d.record.nonce));
    assert.equal(m.artistRecoveredMultipleConsentHydrationDelegateLane(identity.artistId, d.record.grant.delegate), delegateLane(identity.artistId, d.record.grant.delegate));
  }
  assert.equal(f.identities[0].delegations[0].record.grant.delegate, f.identities[1].delegations[0].record.grant.delegate);
  assert.notEqual(f.identities[0].nonces[1].key, f.identities[1].nonces[1].key);
});

test("kind2 lanes preserve the complete global order, words, prefix and cross-Artist separation", () => {
  const f = semanticFixture(), cp = f.provenance.eras[0].checkpoints[2];
  const ordered = m.artistRecoveredMultipleConsentHydrationNonceUnion(f.states[2], f.nonces, cp);
  assert.deepEqual(ordered.map(n => n.key), f.nonces.map(n => n.index.key));
  for (const mutate of [ids => ids[0].nonces.reverse(), ids => { ids[0].nonces[1].key = ids[1].nonces[1].key; },
    ids => { ids[0].nonces[1].words[0].words[31] = 9n; }, ids => { ids[0].nonces[1].words[0].exhausted = true; },
    ids => { ids[0].nextRegistrationNonce++; }, ids => { ids[0].identity.authorityAddress = ids[1].identity.authorityAddress; }]) {
    const ids = f.identities.map(value => clone(value)); mutate(ids);
    const state = { ...f.states[2], rows: ids.map(b => coder.encode([T.identity], [b])) };
    assert.throws(() => m.artistRecoveredMultipleConsentHydrationNonceUnion(state, f.nonces, cp));
  }
});

test("delegate consumed-bit totals cover all grant versions and are not inferred from exhaustion or hint", () => {
  for (const mutate of [b => { b.nonces[1].words[0].words[0] >>= 1n; }, b => { b.nonces[1].words[0].words[0] = 0n; },
    b => { b.nonces[1].words[0].prefix = 1n << 248n; }, b => { b.nonces = b.nonces.filter(n => n.kind !== 2n); },
    b => { b.delegations[0].record.uses = 0n; }, b => { b.nonces[1].words.push(clone(b.nonces[1].words[0])); }]) {
    const f = semanticFixture(); mutate(f.identities[0]); assert.throws(() => identityCheck(f));
  }
  const f = semanticFixture(); f.identities[0].nonces[1].hint = (1n << 255n) + 19n;
  f.identities[0].nonces[1].words[0].exhausted = true;
  assert.doesNotThrow(() => identityCheck(f));
});

test("revoked and exhausted same-era grants retain prior uses without live authorization", () => {
  const f = semanticFixture(), b = f.identities[0], d = b.delegations[0], recordHash = H(9700);
  assert.equal(d.record.grant.maxUses, d.record.uses); assert.equal(d.record.grant.expiresAt, 2n);
  d.record.revoked = true; d.record.revocationRecordHash = recordHash;
  const point = { environmentHash: f.provenance.eras[0].originHash, ownerIndex: 2n, ownerRevision: 45n };
  f.provenance.journals[2].push({ position: { point, nativeIndex: BigInt(f.provenance.journals[2].length) }, receipt: { operation: 27n, artistId: b.artistId, collectionId: 0n, recordHash } });
  originalAlias(f, point, "identity_authority.replay.one_way_delegation_revocation", d.recordHash, recordHash); syncIdentityCounts(f);
  assert.doesNotThrow(() => identityCheck(f)); assert.doesNotThrow(() => grantsCheck(f));
  d.record.revocationRecordHash = H(9701); assert.throws(() => identityCheck(f));
});

test("unused later replacement remains in complete history and does not consume another nonce lane", () => {
  const f = semanticFixture(), b = f.identities[0], prior = b.delegations[0], next = clone(prior);
  next.record.nonce += 100n; next.record.uses = 0n; next.record.grant.maxUses = 0n;
  next.epoch = 1n; b.heads.delegationEpoch = 1n;
  next.recordHash = grantRecord(f.origin, next.record.grant, next.record.nonce); next.current = next.recordHash; prior.current = next.recordHash;
  const point = { environmentHash: f.provenance.eras[0].originHash, ownerIndex: 2n, ownerRevision: 44n };
  next.position = { point, nativeIndex: BigInt(f.provenance.journals[2].length) };
  f.provenance.journals[2].push({ position: clone(next.position), receipt: { operation: 26n, artistId: b.artistId, collectionId: 0n, recordHash: next.recordHash } }); b.delegations.push(next);
  const digest = grantDigest(f.origin, next.record.grant, next.record.nonce);
  originalAlias(f, point, "identity_authority.replay.delegation_key", next.recordHash, next.recordHash);
  originalAlias(f, point, "identity_authority.replay.nonce_allocator", hash(["bytes32", "uint256"], [b.artistId, next.record.nonce]), digest);
  originalAlias(f, point, "identity_authority.replay.authorization_consumed_digest", hash(["bytes32", "bytes32"], [b.artistId, digest]), digest); syncIdentityCounts(f);
  assert.doesNotThrow(() => identityCheck(f)); assert.doesNotThrow(() => grantsCheck(f));
  prior.current = prior.recordHash; assert.throws(() => identityCheck(f), /head|version/i);
});

test("delegated modes, capabilities, original signer and sale nonce chronology stay source-bound", () => {
  for (const mutate of [f => { f.bindings[0].item.consentMode = 1n; }, f => { f.contents[0].royalties[0].grant = H(998); }]) {
    const f = semanticFixture(); mutate(f); assert.throws(() => grantsCheck(f), /mode2|absent original grant/);
  }
  // Rebuild the original grant record, EIP712 digest, replay identities and every
  // cross-collection reference. A stale hash must not mask the missing capability.
  const cap = semanticFixture(), b = cap.identities.find(b => b.artistId === cap.collections[0].artistId), d = b.delegations[0];
  const oldRecord = d.recordHash, oldDigest = grantDigest(cap.origin, d.record.grant, d.record.nonce);
  d.record.grant.capabilities &= ~2n;
  const newRecord = grantRecord(cap.origin, d.record.grant, d.record.nonce), digest = grantDigest(cap.origin, d.record.grant, d.record.nonce);
  d.recordHash = d.current = newRecord;
  cap.provenance.journals[2].find(j => j.receipt.recordHash === oldRecord).receipt.recordHash = newRecord;
  b.signatures.find(s => s.recordHash === oldRecord).recordHash = newRecord;
  for (const a of cap.provenance.aliases[2]) {
    if (a.surface === id("identity_authority.replay.delegation_key") && a.scope === oldRecord) a.scope = a.cell.commitment = newRecord;
    if (a.surface === id("identity_authority.replay.nonce_allocator") && a.scope === hash(["bytes32", "uint256"], [b.artistId, d.record.nonce])) a.cell.commitment = digest;
    if (a.surface === id("identity_authority.replay.authorization_consumed_digest") && a.scope === hash(["bytes32", "bytes32"], [b.artistId, oldDigest])) {
      a.scope = hash(["bytes32", "bytes32"], [b.artistId, digest]); a.cell.commitment = digest;
    }
    a.originalKey = m.artistRecoveredMultipleConsentHydrationReplayKey(cap.origin, 2, { surface: a.surface, scope: a.scope });
  }
  for (const content of cap.contents) for (const r of [...content.original.policies, ...content.original.economics, ...content.original.sales, ...content.royalties]) {
    if (r.grant === oldRecord) r.grant = newRecord;
  }
  refresh(cap);
  assert.doesNotThrow(() => identityCheck(cap, cap.identities.indexOf(b)));
  assert.doesNotThrow(() => contentCheck(cap));
  assert.throws(() => grantsCheck(cap), { message: "Grant scope or historical era mismatch" });

  // Rehash each changed sale and all retained references; its own source preimage
  // and content journal remain valid before the specific delegation join fails.
  for (const changed of ["signer", "nonce"]) {
    const f = semanticFixture(), row = f.contents[0].original.sales[0], old = row.item.recordHash;
    if (changed === "signer") row.item.signer = A(999); else row.item.nonce += 1000n;
    row.item.recordHash = row.current = saleRecord(f.origin, row.item);
    f.provenance.journals[6].find(j => j.receipt.recordHash === old).receipt.recordHash = row.item.recordHash;
    f.provenance.aliases[6].find(a => a.cell.commitment === old).cell.commitment = row.item.recordHash;
    f.identities.find(b => b.artistId === row.item.artistId).signatures.find(s => s.recordHash === old).recordHash = row.item.recordHash;
    refresh(f); assert.doesNotThrow(() => contentCheck(f));
    assert.throws(() => grantsCheck(f), { message: changed === "signer" ? "Sale delegate identity mismatch" : "Missing original delegated sale nonce" });
  }

  const order = semanticFixture(), a = order.provenance.aliases[2].find(a => a.surface === id("identity_authority.replay.delegated_nonce"));
  a.admittedAt.ownerRevision = a.cell.touchedRevision = 1n;
  refresh(order); assert.doesNotThrow(() => identityCheck(order)); assert.doesNotThrow(() => contentCheck(order));
  assert.throws(() => grantsCheck(order), { message: "Delegated sale nonce chronology mismatch" });
});

test("standalone evidence binds rehashed guard inventories and replay preimages to retained provenance", () => {
  const f = semanticFixture(), p = f.prepared, admission = child(T.prepared, "admission");
  const types = ["bytes32", "uint16", "address", "address", compiledInterfaces.registry.getFunction("hydrateRecoveredArtistAuthority").inputs[0],
    child(admission, "artists"), child(admission, "collections"), child(T.prepared, "query"), child(T.prepared, "data"), child(T.prepared, "timing"), child(T.prepared, "externalGuards")];
  const original = { profile: id("6529STREAM_ARTIST_RECOVERED_AUTHORITY_HYDRATION_V1"), version: 1n,
    prior: p.admission.prior, sourceCoordinator: p.admission.sourceCoordinator, request: clone(f.request), artists: p.admission.artists,
    collections: p.admission.collections, query: p.query, data: p.data, timing: p.timing, externalGuards: p.externalGuards };
  const provenanceHash = hash(["bytes32", "uint16", T.provenance], [id("6529STREAM_ARTIST_RECOVERED_HYDRATION_PROVENANCE_V1"), 1n, f.provenance]);
  const encode = e => {
    e.request.expectedSemanticInventory = hash(["bytes32", "uint16", "bytes32", child(T.prepared, "query"), child(T.prepared, "data"), child(T.prepared, "timing"), child(T.prepared, "externalGuards")],
      [id("6529STREAM_ARTIST_RECOVERED_SEMANTIC_INVENTORY_V1"), 1n, provenanceHash, e.query, e.data, e.timing, e.externalGuards]);
    return coder.encode(types, [e.profile, e.version, e.prior, e.sourceCoordinator, e.request, e.artists, e.collections, e.query, e.data, e.timing, e.externalGuards]);
  };
  const raw = encode(clone(original));
  assert.equal(raw, m.encodeArtistRecoveredMultipleConsentHydrationProfileEvidence(f.request, p));
  assert.deepEqual(m.decodeArtistRecoveredMultipleConsentHydrationProfileEvidence(raw), original);
  const mutations = [
    e => { e.externalGuards.schema = H(9800); },
    e => { e.externalGuards.artistId = H(9801); },
    e => { e.externalGuards.provenanceCommitment = H(9802); },
    e => { e.data[6].sourceKeys[0] = H(9803); },
    e => { e.data[6].cells[0].commitment = H(9804); },
    e => { e.data[6].sourceKeys.pop(); },
    e => { e.data[6].nonces.push(zero(child(child(T.prepared, "data").arrayChildren, "nonces").arrayChildren)); },
    e => { e.request.records.authority.replayOrigins[6][0].scope = H(9805); },
    e => { e.data[6].origins[0].scope = H(9806); e.request.records.authority.replayOrigins[6] = clone(e.data[6].origins); },
  ];
  for (const mutate of mutations) {
    const e = clone(original); mutate(e);
    assert.throws(() => m.decodeArtistRecoveredMultipleConsentHydrationProfileEvidence(encode(e)), /guard|replay|alias/i);
  }
});

test("each original17/20/21 occurrence retains one bounded signature including valid empty bytes", () => {
  const f = semanticFixture(); assert.doesNotThrow(() => grantsCheck(f));
  const b = f.identities.find(b => b.artistId === f.collections[0].artistId), record = f.contents[0].consents[0].recordHash;
  const signature = b.signatures.find(s => s.recordHash === record); signature.signature = "0x";
  assert.doesNotThrow(() => grantsCheck(f)); signature.signature = "0x" + "ab".repeat(4096);
  assert.doesNotThrow(() => grantsCheck(f)); signature.signature += "ab"; assert.throws(() => grantsCheck(f));
  signature.signature = "0x"; b.signatures.push(clone(signature)); assert.throws(() => grantsCheck(f));
  b.signatures = b.signatures.filter(s => s.recordHash !== record); assert.throws(() => grantsCheck(f));
});

test("rehashed non-anchor semantic mutations cannot hide behind unchanged outer record partitions", () => {
  for (const mutate of [f => { f.contents[2].freezes[0].authorityClass = 4n; }, f => { f.contents[2].original.economics[0].item.association.bindingGeneration = 2n; },
    f => { f.identities[0].delegations[0].record.uses--; }, f => { f.contents[2].original.sales[0].item.signer = A(900); },
    f => { f.bindings[2].item.generation = f.bindings[2].history.generation = 2n; }]) {
    const f = semanticFixture(); mutate(f);
    assert.throws(() => { refresh(f); m.normalizeArtistRecoveredMultipleConsentHydrationPrepared(f.prepared); });
  }
});

test("capability advertisement never authorizes BASE, attestations, collaborator or later-family bits", () => {
  const f = semanticFixture();
  for (const bit of [128n, 262144n, 1024n, 2097152n]) {
    assert.throws(() => m.encodeArtistRecoveredMultipleConsentHydrationOwnerPayload(f.payloads[1], 1, f.features | bit));
  }
  const input = clone(f.input); input.request.expectedCapabilities[0].supportedFeatures = 524287n;
  assert.throws(() => m.validateArtistRecoveredMultipleConsentHydrationInput(input, f.prepared));
  const classes = f.identities.map(value => clone(value)); classes[0].identity.authorityClass = 4n;
  assert.throws(() => m.artistRecoveredMultipleConsentHydrationRequiredFeatures(classes, f.payouts, 1n, f.bindings, f.contents));
});

test("strict owned codecs bound data before decode and keep mutable caller inputs detached", () => {
  const f = semanticFixture(), raw = coder.encode([T.content], [f.contents[0]]), copied = m.normalizeArtistRecoveredMultipleConsentHydrationContentBundle(f.contents[0]);
  f.contents[0].freezes[0].lockClasses[0] = H(999); assert.notEqual(copied.freezes[0].lockClasses[0], H(999));
  const extra = clone(f.contents[0]); extra.hidden = 1; assert.throws(() => m.normalizeArtistRecoveredMultipleConsentHydrationContentBundle(extra));
  delete extra.hidden; Object.defineProperty(extra, "original", { get() { throw Error("Must not call getter"); } });
  assert.throws(() => m.normalizeArtistRecoveredMultipleConsentHydrationContentBundle(extra), /owned/i);
  const sparse = clone(f.contents[0]); delete sparse.consents[0]; assert.throws(() => m.normalizeArtistRecoveredMultipleConsentHydrationContentBundle(sparse));
  const numeric = clone(f.contents[0]); numeric.original.collectionId = 3; assert.throws(() => m.normalizeArtistRecoveredMultipleConsentHydrationContentBundle(numeric), /bigint/i);
  assert.throws(() => m.decodeArtistRecoveredMultipleConsentHydrationContentBundle(raw + "00".repeat(32)), /canonical/i);
  assert.throws(() => m.decodeArtistRecoveredMultipleConsentHydrationContentBundle("0x" + "ff".repeat(64)), /offset|capacity|Truncated|allocation/i);
});
