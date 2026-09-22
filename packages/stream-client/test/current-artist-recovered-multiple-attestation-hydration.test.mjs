import test from "node:test";
import assert from "node:assert/strict";
import { id, keccak256, hexlify, toUtf8Bytes } from "ethers";
import * as base from "../dist/current-artist-recovered-multiple-hydration.js";
import * as consents from "../dist/current-artist-recovered-multiple-consent-hydration.js";
import { toSafeCall } from "../dist/safe.js";
import { m, semanticFixture, refresh, T, child, zero, coder, H, A, Z, hash, attestationRecord, attestationDigest, grantRecord, grantDigest, delegateLane } from "./current-artist-recovered-multiple-attestation-hydration-semantic-fixture.mjs";
import { compiledInterfaces } from "./current-artist-recovered-multiple-attestation-hydration-source-fixture.mjs";

const clone = structuredClone;
const local = (f, owner) => m.artistRecoveredMultipleAttestationHydrationOwnerProvenance(f.provenance, owner);
const attest = f => m.validateArtistRecoveredMultipleAttestationHydrationAttestations(f.identities, f.collections, f.attestations, f.provenance);
const grants = f => m.validateArtistRecoveredMultipleAttestationHydrationGrantUses(f.identities, f.collections, f.contents, f.bindings, f.provenance, f.attestations);
const clocks = f => m.validateArtistRecoveredMultipleAttestationHydrationClocks(f.states[4], f.provenance, f.clocks, f.clockFacts);

// Rebuild all available commitment aliases so a semantic negative cannot stop at
// an obsolete record preimage. This does not repair the deliberately changed fact.
function mutateAttestation(f, collection, index, change) {
  const b = f.attestations[collection], saved = b.records[index], r = saved.attestation;
  const oldRecord = r.record.recordHash, oldDigest = attestationDigest(f.origin, r), oldNonce = r.input.nonce;
  const identity = f.identities.find(v => v.artistId === b.artistId), oldSigner = r.record.signer;
  change(saved);
  const t = r.input.terms;
  t.statementHash = keccak256(r.statement);
  Object.assign(r.record, { statementHash: t.statementHash, schemaId: t.schemaId, subjectStateHash: t.subjectStateHash });
  const record = attestationRecord(f.origin, b.artistId, r), digest = attestationDigest(f.origin, r);
  r.record.recordHash = record;
  for (const j of f.provenance.journals[4]) if (j.receipt.recordHash === oldRecord) j.receipt.recordHash = record;
  for (const s of identity.signatures) if (s.recordHash === oldRecord) s.recordHash = record;
  for (const p of b.personhood) if (p.recordHash === oldRecord) p.recordHash = record;
  if (saved.publication.evidence.attestationRecordHash === oldRecord) saved.publication.evidence.attestationRecordHash = record;
  const delegatedOld = hash(["bytes32", "uint256"], [delegateLane(b.artistId, oldSigner), oldNonce]);
  for (const a of f.provenance.aliases[2]) {
    if (a.surface === id("identity_authority.replay.delegated_nonce") && a.scope === delegatedOld && a.cell.commitment === oldDigest) {
      a.scope = hash(["bytes32", "uint256"], [delegateLane(b.artistId, r.record.signer), r.input.nonce]); a.cell.commitment = digest;
    } else if (a.surface === id("identity_authority.replay.nonce_allocator") && a.cell.commitment === oldDigest) {
      a.scope = hash(["bytes32", "uint256"], [b.artistId, r.input.nonce]); a.cell.commitment = digest;
    } else if (a.surface === id("identity_authority.replay.attestation_key") && a.cell.commitment === oldRecord) {
      a.scope = hash(["bytes32"], [record]); a.cell.commitment = record;
    } else if (a.surface === id("identity_authority.replay.authorization_consumed_digest") && a.cell.commitment === oldDigest) {
      a.scope = hash(["bytes32", "bytes32"], [b.artistId, digest]); a.cell.commitment = digest;
    }
    a.originalKey = m.artistRecoveredMultipleAttestationHydrationReplayKey(f.origin, 2, { surface: a.surface, scope: a.scope });
  }
  refresh(f); return f;
}
function rehashGrant(f, artistIndex, mutate) {
  const identity = f.identities[artistIndex], d = identity.delegations[0], old = d.recordHash, oldDigest = grantDigest(f.origin, d.record.grant, d.record.nonce);
  mutate(d.record.grant);
  d.recordHash = d.current = grantRecord(f.origin, d.record.grant, d.record.nonce);
  const digest = grantDigest(f.origin, d.record.grant, d.record.nonce);
  for (const j of f.provenance.journals[2]) if (j.receipt.recordHash === old) j.receipt.recordHash = d.recordHash;
  for (const s of identity.signatures) if (s.recordHash === old) s.recordHash = d.recordHash;
  for (const a of f.provenance.aliases[2]) {
    if (a.surface === id("identity_authority.replay.delegation_key") && a.scope === old) { a.scope = d.recordHash; a.cell.commitment = d.recordHash; }
    else if (a.cell.commitment === oldDigest) {
      a.cell.commitment = digest;
      if (a.surface === id("identity_authority.replay.authorization_consumed_digest")) a.scope = hash(["bytes32", "bytes32"], [identity.artistId, digest]);
    }
    a.originalKey = m.artistRecoveredMultipleAttestationHydrationReplayKey(f.origin, 2, { surface: a.surface, scope: a.scope });
  }
  for (const b of f.contents) for (const list of [b.original.policies, b.original.economics, b.original.sales, b.royalties]) for (const r of list) if (r.grant === old) r.grant = d.recordHash;
  for (const b of f.attestations) for (const r of b.records) if (r.attestation.association.delegation === old) r.attestation.association.delegation = d.recordHash;
  refresh(f); return f;
}
function rehashClock(f, index, change) {
  const envelope = f.envelopes[index]; change(envelope);
  const raw = coder.encode(T.envelope.components, T.envelope.components.map(c => envelope[c.name]));
  f.clockFacts.envelopes[index] = raw;
  const op = f.clocks.operations[index]; op.evidence.payloadHash = keccak256(raw);
  op.evidence.evidenceId = hash(["bytes32", "uint256", "address", "address", "uint16", "address", "bytes32"],
    [id("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"), f.origin.chainId, f.origin.registry, f.origin.coordinator, envelope.operation, envelope.actor, envelope.value]);
  refresh(f); return f;
}

test("new five-field profile derives original features for direct and delegated consent plus op24 graphs", () => {
  for (const delegated of [false, true]) {
    const f = semanticFixture({ delegated });
    assert.equal(m.artistRecoveredMultipleAttestationHydrationRequiredFeatures(f.identities, f.payouts, 1n, f.bindings, f.contents, f.attestations), f.features);
    assert.deepEqual(m.validateArtistRecoveredMultipleAttestationHydrationInput(f.input, f.prepared), f.input);
    assert.equal(m.normalizeArtistRecoveredMultipleAttestationHydrationPrepared(f.prepared).admission.artists.length, 2);
    assert.equal(f.request.expectedCapabilities[0].supportedFeatures, 2097151n);
    assert.equal(f.features & (262144n | 524288n), 0n);
  }
  assert.equal(m.ARTIST_RECOVERED_MULTIPLE_ATTESTATION_HYDRATION_ALLOWED_FEATURES, 1049087n);
});

test("only owner4 collection records are projected while Artist records and anchor stay complete", () => {
  const f = semanticFixture();
  for (let owner = 0; owner < 7; owner++) {
    const p = f.payloads[owner], decoded = m.decodeArtistRecoveredMultipleAttestationHydrationAuxiliary(p.semanticState, owner, p.provenance);
    assert.deepEqual(decoded.state.artists, f.artists);
    assert.deepEqual(m.artistRecoveredMultipleAttestationHydrationAnchor(decoded.state), f.prepared.query);
    assert.deepEqual(decoded.state.collections, owner === 4 ? f.states[4].collections : f.collections);
    assert.equal(decoded.auxiliary === "0x", owner !== 4);
  }
  assert.ok(f.collections[0].records.length > f.states[4].collections[0].records.length);
  assert.throws(() => m.encodeArtistRecoveredMultipleAttestationHydrationState(f.states[4], 4, local(f, 4)), /Archive/);
  const wrong = coder.encode(["bytes32", "uint16", "uint8", T.state], [id("6529STREAM_ARTIST_RECOVERED_MULTIPLE_ATTESTATIONS_V1"), 1n, 1n, f.states[1]]);
  assert.throws(() => m.decodeArtistRecoveredMultipleAttestationHydrationState(wrong, 1, local(f, 1)));
  for (const owner of [1, 4]) {
    const raw = coder.encode(["bytes32", "uint16", "uint8", T.state, "bytes"], [id("6529STREAM_ARTIST_RECOVERED_MULTIPLE_ATTESTATIONS_V1"), 1n, BigInt(owner), f.states[owner], owner === 4 ? "0x" : "0x1234"]);
    assert.throws(() => m.decodeArtistRecoveredMultipleAttestationHydrationState(raw, owner, local(f, owner)), /auxiliary/i);
  }
});

test("closed original Registry routes keep ordered economics, attestation and royalty witnesses and Safe CALL0", () => {
  for (const royalties of [false, true]) {
    const f = semanticFixture({ royalties }), plan = m.prepareArtistRecoveredMultipleAttestationHydrationCall(f.coords.registry, A(991), f.input);
    const name = royalties ? "hydrateRecoveredArtistAuthorityWithConsents" : "hydrateRecoveredArtistAuthority";
    assert.equal(plan.call.data, compiledInterfaces.registry.encodeFunctionData(name, royalties ? [f.request, f.input.royaltyFreezes] : [f.request]));
    assert.deepEqual(toSafeCall(plan.call), { to: f.coords.registry, value: "0", data: plan.call.data, operation: 0 });
    assert.equal(m.artistRecoveredMultipleAttestationHydrationPreparationCalldata(f.source, f.input).slice(0, 10), royalties ? "0x4925300f" : "0x72c84763");
    for (const mutate of [i => i.request.records.witnesses.reverse(), i => i.request.records.witnesses[0].attestations.pop(), i => { i.request.records.witnesses[0].economics[0].assignmentHash = H(999); }]) {
      const input = clone(f.input); mutate(input); assert.throws(() => m.validateArtistRecoveredMultipleAttestationHydrationInput(input, f.prepared));
    }
    const bad = clone(plan); bad.call.value = 1n; assert.throws(() => m.normalizeArtistRecoveredMultipleAttestationHydrationCall(bad));
  }
});

test("raw original attestation and clock codecs preserve compiler bytes and reject noncanonical tails", () => {
  const f = semanticFixture();
  for (const [type, value, encode, decode] of [
    [T.attestation, f.attestations[0], m.encodeArtistRecoveredMultipleAttestationHydrationAttestationBundle, m.decodeArtistRecoveredMultipleAttestationHydrationAttestationBundle],
    [T.clocks, f.clocks, m.encodeArtistRecoveredMultipleAttestationHydrationClocksInventory, m.decodeArtistRecoveredMultipleAttestationHydrationClocksInventory],
  ]) {
    const raw = coder.encode([type], [value]); assert.equal(encode(value), raw); assert.deepEqual(decode(raw), value);
    assert.throws(() => decode(raw + "00".repeat(32)), /canonical/i);
    assert.deepEqual(decode(coder.encode([type], [zero(type)])), zero(type));
  }
});

test("all ten original subject kinds remain distinct and malformed resolved subjects fail after rehash", () => {
  const f = semanticFixture({ delegated: false, attestationPlan: Array.from({ length: 10 }, (_, i) => ({ collection: i % 3, kind: i + 1 })) });
  assert.equal(attest(f).factsVerified, false);
  mutateAttestation(f, 0, 0, row => { row.attestation.input.terms.subjectStateHash = Z; row.attestation.association.fact.stateHash = Z; });
  assert.throws(() => attest(f), /resolved subject/);
});

test("publication rows join the exact 416-byte statement, saved evidence, schema and recorder", () => {
  const f = semanticFixture(), at = f.attestations[0].records.findIndex(r => r.attestation.input.terms.subjectKind === 7n);
  assert.equal((f.attestations[0].records[at].attestation.statement.length - 2) / 2, 416);
  const bad = clone(f); bad.attestations[0].records[at].publication.evidence.requiredCapability = 1n;
  assert.throws(() => attest(bad), /publication evidence/);
  mutateAttestation(f, 0, at, row => {
    row.publication.publication.payloadAlgorithm = 2n;
    row.attestation.statement = coder.encode(["uint16", child(child(child(T.attestation, "records").arrayChildren, "publication"), "publication")], [1n, row.publication.publication]);
  });
  assert.throws(() => attest(f), /publication family/);
});

test("C2PA predecessor is global per Artist across interleaved collections", () => {
  const f = semanticFixture(), result = attest(f);
  assert.deepEqual(result.credentialRecords, [...f.credentialRecords.values()]);
  assert.deepEqual(result.credentialHeads, f.artists.map(a => f.credentialHeads.get(a.artistId)));
  const k = 1, r = f.attestations[k].records[0].attestation;
  const decoded = coder.decode([T.credential], r.statement)[0];
  const payload = { schemaVersion: decoded.schemaVersion, artistId: decoded.artistId, identityRecordHash: decoded.identityRecordHash,
    previousRecordHash: decoded.previousRecordHash, credentials: Array.from(decoded.credentials, c => ({
      kind: c.kind, fingerprint: c.fingerprint, keyId: c.keyId, validFrom: c.validFrom, validUntil: c.validUntil,
    })) };
  assert.notEqual(payload.previousRecordHash, Z); payload.previousRecordHash = Z;
  mutateAttestation(f, k, 0, row => { row.attestation.statement = coder.encode([T.credential], [payload]); });
  assert.throws(() => attest(f), /C2PA predecessor/);
});

test("credential rows enforce original limits and ordering without current identity admission", () => {
  const f = semanticFixture(), r = f.attestations[0].records[0].attestation;
  const payload = { schemaVersion: 1n, artistId: f.collections[0].artistId, identityRecordHash: r.input.terms.subjectStateHash, previousRecordHash: Z,
    credentials: [{ kind: 1n, fingerprint: H(1), keyId: H(2), validFrom: 4n, validUntil: 0n }] };
  const decode = value => m.decodeArtistRecoveredMultipleAttestationHydrationCredentialPayload(coder.encode([T.credential], [value]), payload.artistId, payload.identityRecordHash);
  assert.deepEqual(decode(payload), payload);
  for (const mutate of [p => { p.credentials[0].validUntil = 4n; }, p => p.credentials.push(clone(p.credentials[0])), p => { p.schemaVersion = 2n; }]) {
    const changed = clone(payload); mutate(changed); assert.throws(() => decode(changed));
  }
});

test("opaque personhood waiver retains empty summary and its exact original Registry", () => {
  const f = semanticFixture(); assert.equal(attest(f).personhoodHeads[2].recordHash, f.attestations[2].personhood[0].recordHash);
  for (const change of [b => { b.personhood[0].originalRegistry = A(888); }, b => { b.personhood[0].summaryHash = H(1); }, b => { b.personhood[0].summary.version = 1n; }]) {
    const bad = clone(f); change(bad.attestations[2]); assert.throws(() => attest(bad), /personhood/);
  }
  assert.equal(m.artistRecoveredMultipleAttestationHydrationPersonhoodReference(hexlify(toUtf8Bytes("opaque retained waiver"))), null);
  const full = semanticFixture(), b = full.attestations[2], n = b.records.findIndex(v => v.attestation.input.terms.schemaId === id("6529STREAM_ARTIST_PERSONHOOD_WAIVER_V1"));
  const original = b.records[n].attestation;
  const ref = { artistId: b.artistId, artistRegistry: full.origin.registry.toLowerCase(), notarizationHost: A(8800).toLowerCase(),
    notarizationRecordHash: H(8801), notarizationRuntimeHash: H(8802), operativeIdentityRecordHash: original.input.terms.subjectStateHash,
    profileHash: "0x06eaf449a0abe6a4305706d589bc597f14f7d23f62acc661b4b1fff128b921c3", version: 1 };
  const canonical = hexlify(toUtf8Bytes(JSON.stringify(ref))); assert.equal((canonical.length - 2) / 2, 590);
  const decoded = m.artistRecoveredMultipleAttestationHydrationPersonhoodReference(canonical); assert.ok(decoded);
  mutateAttestation(full, 2, n, saved => { saved.attestation.statement = canonical; saved.attestation.input.terms.schemaId = id("6529STREAM_ARTIST_PERSONHOOD_EVIDENCE_V1"); });
  const r = b.records[n].attestation, person = b.personhood[0], summaryType = child(child(T.attestation, "personhood").arrayChildren, "summary");
  Object.assign(person.summary, { version: 1n, chainId: full.origin.chainId, nativeRecordHash: r.record.recordHash, statementHash: r.record.statementHash,
    artistId: b.artistId, bindingHash: b.bindingHash, generation: 1n, collectionId: b.collectionId, identityRecordHash: r.record.subjectStateHash,
    evidenceReference: decoded, originalRegistryCodeHash: H(8803), core: full.origin.core, coreCodeHash: H(8804), documentaryHash: H(8805) });
  person.summaryHash = hash(["bytes32", summaryType], [id("6529STREAM_ARTIST_PERSONHOOD_PROOF_SUMMARY_V1"), person.summary]);
  refresh(full); attest(full);
  person.summary.collectionId++;
  person.summaryHash = hash(["bytes32", summaryType], [id("6529STREAM_ARTIST_PERSONHOOD_PROOF_SUMMARY_V1"), person.summary]);
  refresh(full); assert.throws(() => attest(full), /personhood summary/);
});

test("every op24 occurrence has exactly one bounded original signature including empty signatures", () => {
  const f = semanticFixture(), record = f.attestations[0].records[0].attestation.record.recordHash;
  const identity = f.identities.find(i => i.artistId === f.collections[0].artistId), signature = identity.signatures.find(s => s.recordHash === record);
  signature.signature = "0x"; attest(f);
  for (const mutate of [i => i.signatures.push(clone(signature)), i => { i.signatures = i.signatures.filter(s => s.recordHash !== record); },
    i => { i.signatures.find(s => s.recordHash === record).signature = "0x" + "11".repeat(4097); }]) {
    const bad = clone(f); mutate(bad.identities.find(i => i.artistId === identity.artistId)); assert.throws(() => attest(bad), /signature/);
  }
});

test("consent and attestation uses are summed once across collections and nonce lanes", () => {
  const f = semanticFixture(); grants(f);
  const result = attest(f), i = 1, identity = f.identities[i], used = result.uses[i][0];
  assert.ok(used > 1n); assert.ok(identity.delegations[0].record.uses > used);
  // Retain consistent bit counts while incorrectly treating op24 as the whole grant.
  identity.delegations[0].record.uses = used;
  identity.nonces.find(n => n.kind === 2n).words[0].words[0] = (1n << used) - 1n;
  assert.throws(() => grants(f), /complete cross-collection consent occurrences/);
});

test("rehashing a grant cannot hide an absent attestation capability or altered nonce chronology", () => {
  const f = semanticFixture(); rehashGrant(f, 1, grant => { grant.capabilities &= ~64n; });
  assert.throws(() => grants(f), /op24 grant scope or chronology/);
  const bad = semanticFixture(), r = bad.attestations[0].records[0].attestation, digest = attestationDigest(bad.origin, r);
  const alias = bad.provenance.aliases[2].find(a => a.surface === id("identity_authority.replay.delegated_nonce") && a.cell.commitment === digest);
  alias.admittedAt.ownerRevision = alias.cell.touchedRevision = 1n;
  refresh(bad); assert.throws(() => attest(bad), /op24 grant scope or chronology/);
  const observed = semanticFixture(), row = observed.attestations[0].records[0].attestation, d = attestationDigest(observed.origin, row);
  const seen = observed.provenance.aliases[2].find(a => a.surface === id("identity_authority.replay.authorization_consumed_digest") && a.cell.commitment === d);
  seen.admittedAt.ownerRevision++; seen.cell.touchedRevision++;
  refresh(observed); assert.throws(() => attest(observed), /first observed digest clock/);
});

test("nonce union preserves global lane order and mutation of a consumed alias is refused", () => {
  const f = semanticFixture(); m.artistRecoveredMultipleAttestationHydrationNonceUnion(f.states[2], f.nonces, f.provenance.eras[0].checkpoints[2]);
  const missing = clone(f); missing.provenance.aliases[2] = missing.provenance.aliases[2].filter(a => a.cell.commitment !== attestationDigest(f.origin, f.attestations[0].records[0].attestation));
  missing.provenance.eras[0].checkpoints[2].replayCount = BigInt(missing.provenance.aliases[2].length); refresh(missing);
  assert.throws(() => attest(missing), /Missing original attestation Identity replay alias/);
  const flipped = clone(f.nonces); flipped.reverse(); assert.throws(() => m.artistRecoveredMultipleAttestationHydrationNonceUnion(f.states[2], flipped, f.provenance.eras[0].checkpoints[2]));
});

test("original Archive completion clocks authenticate flat envelopes and exact same-owner transitions", () => {
  const f = semanticFixture(); clocks(f);
  assert.equal(f.clocks.operations.length, 2 * f.collections.length);
  for (let i = 0; i < f.envelopes.length; i++) {
    const e = f.envelopes[i], raw = coder.encode(T.envelope.components, T.envelope.components.map(c => e[c.name]));
    assert.equal(raw, f.clockFacts.envelopes[i]); assert.equal(keccak256(raw), f.clocks.operations[i].evidence.payloadHash);
    assert.notEqual(raw, coder.encode([T.envelope], [e]));
  }
  // Identity revisions are deliberately much larger than owner4's. They are
  // separate clocks, and must never be compared to owner4 completion revisions.
  assert.ok(f.provenance.aliases[2].some(a => a.admittedAt.ownerRevision > f.provenance.eras[0].checkpoints[4].ownerState.revision));
});

test("Archive inventory rejects missing, duplicate, reordered and mismatched original proofs", () => {
  for (const mutate of [f => f.clocks.operations.pop(), f => { f.clocks.operations[1] = clone(f.clocks.operations[0]); },
    f => f.clocks.operations.reverse(), f => { f.clocks.catalogues[0].upper[4]--; }, f => { f.clocks.operations[0].evidence.payloadHash = H(2); }]) {
    const f = semanticFixture(); mutate(f); assert.throws(() => clocks(f));
  }
  const mixed = semanticFixture(); rehashClock(mixed, 0, e => { e.after_[4].stateRoot = H(99); });
  assert.throws(() => clocks(mixed), /transition|state|clock/i);
  const foreign = semanticFixture(); rehashClock(foreign, 0, e => { e.before_[6].revision = 1n; });
  assert.throws(() => clocks(foreign), /snapshot|mask|clock/i);
  const cutoff = semanticFixture(); cutoff.clocks.catalogues[0].upper[2]++;
  // All owner payload/header and semantic commitments are recomputed; only the
  // non-owner4 cutoff differs from the retained whole-provenance checkpoints.
  refresh(cutoff);
  assert.throws(() => m.normalizeArtistRecoveredMultipleAttestationHydrationPrepared(cutoff.prepared), /cutoff/i);
});

test("original acceptance digest, principal and direct flag remain exact even with rehashed envelopes", () => {
  for (const mutate of [p => { p.proof.digest = H(3); }, p => { p.proof.direct = false; }, p => { p.authorization.nonce++; }]) {
    const f = semanticFixture();
    rehashClock(f, 1, e => {
      const outer = coder.decode(["bytes", T.authority], e.payload), inner = coder.decode(T.acceptancePayload.components, outer[0]);
      const p = Object.fromEntries(T.acceptancePayload.components.map((c, i) => [c.name, inner[i]?.toObject ? inner[i].toObject(true) : inner[i]]));
      mutate(p); e.payload = coder.encode(["bytes", T.authority], [coder.encode(T.acceptancePayload.components, T.acceptancePayload.components.map(c => p[c.name])), outer[1]]);
    });
    assert.throws(() => clocks(f), /accepted-completion|digest|direct/i);
  }
});

test("old profiles, unsupported required bits and zero op24 inventory remain closed", () => {
  const f = semanticFixture();
  assert.throws(() => base.normalizeArtistRecoveredMultipleHydrationPrepared(f.prepared));
  assert.throws(() => consents.normalizeArtistRecoveredMultipleConsentHydrationPrepared(f.prepared));
  for (const bit of [262144n, 524288n, 1024n, 2097152n]) assert.throws(() => m.encodeArtistRecoveredMultipleAttestationHydrationOwnerPayload(f.payloads[1], 1, f.features | bit));
  const rows = clone(f.attestations); rows.forEach(b => { b.records = []; b.personhood = []; });
  assert.throws(() => m.artistRecoveredMultipleAttestationHydrationRequiredFeatures(f.identities, f.payouts, 1n, f.bindings, f.contents, rows), /op24/);
  const bad = clone(f.input); bad.request.expectedCapabilities[0].supportedFeatures = 1048575n;
  assert.throws(() => m.validateArtistRecoveredMultipleAttestationHydrationInput(bad, f.prepared));
});

test("owned structural copies reject accessors, sparse rows, numeric coercion and hostile ABI offsets", () => {
  const f = semanticFixture(), row = f.attestations[0], copied = m.normalizeArtistRecoveredMultipleAttestationHydrationAttestationBundle(row);
  row.records[0].attestation.input.nonce++; assert.notEqual(copied.records[0].attestation.input.nonce, row.records[0].attestation.input.nonce);
  assert.ok(Object.isFrozen(copied.records[0].attestation));
  for (const change of [b => { delete b.records[0]; }, b => { b.collectionId = 3; }, b => { b.surplus = 1n; },
    b => Object.defineProperty(b, "records", { get() { throw Error("getter must not execute"); } })]) {
    const bad = clone(row); change(bad); assert.throws(() => m.normalizeArtistRecoveredMultipleAttestationHydrationAttestationBundle(bad));
  }
  assert.throws(() => m.decodeArtistRecoveredMultipleAttestationHydrationAttestationBundle("0x" + "ff".repeat(64)));
  const raw = coder.encode([T.attestation], [copied]); assert.throws(() => m.decodeArtistRecoveredMultipleAttestationHydrationAttestationBundle(raw + "00".repeat(32)), /canonical/i);
});

test("retained profile evidence roundtrip authenticates full scope and guards without original Archive read claims", () => {
  const f = semanticFixture();
  const raw = m.encodeArtistRecoveredMultipleAttestationHydrationProfileEvidence(f.request, f.prepared), decoded = m.decodeArtistRecoveredMultipleAttestationHydrationProfileEvidence(raw);
  assert.equal(decoded.request.expectedSemanticInventory, f.request.expectedSemanticInventory);
  assert.equal(m.ARTIST_RECOVERED_MULTIPLE_ATTESTATION_HYDRATION_VALIDATION.completeIdentityAndPayoutSemanticsIndependentlyVerified, false);
  assert.throws(() => m.decodeArtistRecoveredMultipleAttestationHydrationProfileEvidence(raw + "00".repeat(32)), /canonical/i);
  const bad = clone(f); bad.prepared.externalGuards.artistId = H(888);
  assert.throws(() => m.encodeArtistRecoveredMultipleAttestationHydrationProfileEvidence(bad.request, bad.prepared));
});
