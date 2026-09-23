// Compiler-shaped supplied facts only. Private Identity/Payout lifecycle admission,
// runtime provenance, signature validity and actual Registry execution are mocked.
import { AbiCoder, ParamType, ZeroAddress, ZeroHash, getAddress, id, keccak256 } from "ethers";
import * as m from "../dist/current-artist-recovered-multiple-consent-hydration.js";
import { ARTIST_HYDRATION_SUITE_TUPLE } from "../dist/current-artist-authority-hydration.js";
import { fixture, compiledLibraryValueInterface, libraryValueABI } from "./current-artist-recovered-multiple-consent-hydration-source-fixture.mjs";
export { m, fixture };
export const coder = AbiCoder.defaultAbiCoder(), Z = ZeroHash;
export const A = n => getAddress(`0x${BigInt(n).toString(16).padStart(40, "0")}`);
export const H = n => `0x${BigInt(n).toString(16).padStart(64, "0")}`;
export const hash = (types, values) => keccak256(coder.encode(types, values));
export const seven = fn => Array.from({ length: 7 }, (_, i) => fn(i));
export const child = (t, name) => t.components.find(c => c.name === name);
const clone = structuredClone, cached = new Map();
export function findType(name) {
  if (cached.has(name)) return cached.get(name);
  function visit(p) {
    if (p.internalType === `struct ${name}`) return ParamType.from({ ...p, name: "" });
    for (const c of p.components ?? []) { const found = visit(c); if (found) return found; }
  }
  for (const group of [fixture.abis, fixture.libraryAbis]) for (const [key, entries] of Object.entries(group)) {
    for (const e of group === fixture.libraryAbis ? libraryValueABI(key) : entries) {
      for (const p of [...e.inputs ?? [], ...e.outputs ?? []]) {
        const found = visit(p); if (found) { cached.set(name, found); return found; }
      }
    }
  }
  throw Error(`Missing exact compiler tuple ${name}`);
}
export const T = {
  state: findType("StreamArtistRecoveredMultipleTypes.State"),
  identity: findType("StreamArtistRecoveredIdentityHydrationTypes.Bundle"),
  payout: findType("StreamArtistRecoveredPayoutTypes.Bundle"),
  binding: findType("StreamArtistRecoveredSimpleHydrationTypes.Binding"),
  acceptance: findType("StreamArtistRecoveredSimpleHydrationTypes.Acceptance"),
  attribution: findType("StreamArtistRecoveredCollectionHydration.AttributionBundle"),
  content: findType("StreamArtistRecoveredContentConsentHydration.Bundle"),
  provenance: findType("StreamArtistRecoveredHydrationTypes.Provenance"),
  ownerProvenance: findType("StreamArtistRecoveredHydrationTypes.OwnerProvenance"),
};
T.prepared = compiledLibraryValueInterface("prepared").fragments.find(f => f.type === "function" && f.name === "prepare" && f.inputs.length === 2).outputs[0];
T.original = child(T.content, "original");
T.grant = child(child(T.identity, "delegations").arrayChildren, "record").components.find(c => c.name === "grant");
export function zero(t) {
  if (typeof t === "string") t = ParamType.from(t);
  if (t.baseType === "array") return Array.from({ length: Math.max(0, t.arrayLength) }, () => zero(t.arrayChildren));
  if (t.baseType === "tuple") return Object.fromEntries(t.components.map(c => [c.name, zero(c)]));
  if (t.type === "address") return ZeroAddress;
  if (t.type === "bool") return false;
  if (t.type === "string") return "";
  if (t.type === "bytes") return "0x";
  if (t.type.startsWith("bytes")) return "0x" + "00".repeat(Number(t.type.slice(5)));
  return 0n;
}
const emptyHash = domain => hash(["bytes32", "bytes32[]"], [id(domain), []]);
export const delegateLane = (artist, delegate) => hash(["bytes32", "bytes32", "address"], [id("6529STREAM_ARTIST_DELEGATE_NONCE_LANE_V1"), artist, delegate]);
export function grantRecord(origin, grant, nonce) {
  return hash(["bytes32", "uint256", "address", "bytes32", "address", "uint256", "uint32", "uint64", "uint64", "uint64", "bytes32", "uint256"],
    [id("6529STREAM_ARTIST_DELEGATION_RECORD_V1"), origin.chainId, origin.registry, grant.artistId, grant.delegate, grant.collectionId,
      grant.capabilities, grant.notBefore, grant.expiresAt, grant.maxUses, grant.constraintsHash, nonce]);
}
export function grantDigest(origin, g, nonce) {
  const domain = hash(["bytes32", "bytes32", "bytes32", "uint256", "address"],
    [id("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"), id("6529StreamArtistRegistry"), id("1"), origin.chainId, origin.registry]);
  const body = hash(["bytes32", "address", "address", "uint256", "uint32", "uint64", "uint64", "uint64", "bytes32", "uint256"],
    [id("StreamArtistDelegation(address core,address delegate,uint256 collectionId,uint32 capabilities,uint64 notBefore,uint64 expiresAt,uint64 maxUses,bytes32 constraintsHash,uint256 nonce)"),
      origin.core, g.delegate, g.collectionId, g.capabilities, g.notBefore, g.expiresAt, g.maxUses, g.constraintsHash, nonce]);
  return keccak256(`0x1901${domain.slice(2)}${body.slice(2)}`);
}
export function saleRecord(origin, r) {
  return hash(["bytes32", "uint256", "address", "address", "address", "uint256", "bytes32", "bytes32", "bytes32", "address", "uint8", "uint256", "uint64"],
    [id("6529STREAM_ARTIST_SALE_CONSENT_RECORD_V1"), origin.chainId, origin.registry, r.terms.saleAdapter, origin.core, r.terms.collectionId,
      r.terms.saleId, r.terms.saleConfigHash, r.artistId, r.signer, r.authorityClass, r.nonce, r.signedAt]);
}

/** No helper here claims that these complete supplied facts were admitted onchain. */
export function semanticFixture(args = {}) {
  const options = args.options ?? args;
  const { classes = [1n, 3n], oneArtist = false, delegated = true, royalties = true, collectionCount = 3 } = options;
  const ids = oneArtist ? [H(1000)] : [H(1000), H(1001)];
  const chainId = args.origin?.chainId ?? (1n << 200n) + 11n;
  const suite = args.source ?? { registry: A(1), archive: A(3), owners: seven(i => A(10 + i)), core: A(4), mintManager: A(5),
    roleRegistry: A(6), metadata: A(7), primaryResolver: A(8), royaltyResolver: A(9), primaryRevenueClass: H(8), validator: A(17) };
  const origin = args.origin ?? { chainId, registry: suite.registry, coordinator: A(2), archive: suite.archive, owners: suite.owners,
    ownerCodeHashes: seven(i => H(100 + i)), core: suite.core, manager: suite.mintManager, suiteConfigurationHash: hash([ARTIST_HYDRATION_SUITE_TUPLE], [suite]) };
  const oh = m.artistRecoveredMultipleConsentHydrationOriginHash(origin);
  const collections = Array.from({ length: collectionCount }, (_, i) => ({ artistId: ids[oneArtist ? 0 : i === collectionCount - 1 ? 0 : 1],
    collectionId: (1n << 240n) + BigInt(i + 3), bindingHash: Z, policies: [{ phaseId: H(4100 + i), policyHash: H(4200 + i) }], records: [] }));
  const bindings = collections.map((q, i) => {
    const b = zero(T.binding), mode = delegated ? 2n : 1n;
    Object.assign(b.item, { artistId: q.artistId, artistAddress: A(50 + i), identityRecordHash: H(1200 + i), generation: 1n, consentMode: mode, proposer: A(70), accepted: true });
    q.bindingHash = hash(["bytes32", "uint256", "address", "address", "uint256", "uint64", "bytes32", "address", "bytes32", "uint8", "uint8", "uint8", "bytes32", "bytes32"],
      [id("6529STREAM_ARTIST_BINDING_V1"), chainId, origin.registry, origin.core, q.collectionId, 1n, q.artistId, b.item.artistAddress,
        b.item.identityRecordHash, mode, 0n, 0n, emptyHash("6529STREAM_ARTIST_COLLABORATOR_SET_V1"), emptyHash("6529STREAM_ARTIST_CAPABILITY_POLICY_SET_V1")]);
    b.item.bindingHash = q.bindingHash; b.history = clone(b.item); b.scope = { artistId: q.artistId, collectionId: q.collectionId, bindingHash: q.bindingHash };
    b.terms.collaboratorSetHash = emptyHash("6529STREAM_ARTIST_COLLABORATOR_SET_V1"); b.terms.capabilityPolicySetHash = emptyHash("6529STREAM_ARTIST_CAPABILITY_POLICY_SET_V1");
    return b;
  });
  const journals = seven(() => []), aliases = seven(() => []), logical = seven(() => []);
  const row = (owner, operation, artistId, collectionId, recordHash, revision) => {
    const j = { position: { point: { environmentHash: oh, ownerIndex: BigInt(owner), ownerRevision: revision }, nativeIndex: BigInt(journals[owner].length) }, receipt: { operation, artistId, collectionId, recordHash } };
    journals[owner].push(j); return j;
  };
  const alias = (owner, point, surface, scope, commitment) => {
    const entry = { surface: id(surface), scope }; logical[owner].push(entry);
    aliases[owner].push({ originHash: oh, ownerIndex: BigInt(owner), ...entry,
      originalKey: m.artistRecoveredMultipleConsentHydrationReplayKey(origin, owner, entry),
      cell: { commitment, touchedRevision: point.ownerRevision, kind: 1n, status: 2n }, admittedAt: clone(point) });
  };
  collections.forEach((q, i) => {
    const j = row(0, 1n, q.artistId, q.collectionId, q.bindingHash, BigInt(2 * i + 1));
    alias(0, j.position.point, "binding_lifecycle.replay.proposal_key", hash(["uint256", "uint64"], [q.collectionId, 1n]), q.bindingHash);
    const a = row(3, 2n, q.artistId, q.collectionId, H(1300 + i), BigInt(i + 1));
    alias(3, a.position.point, "acceptance_lifecycle.replay.record_uniqueness", H(1400 + i), a.receipt.recordHash);
  });
  ids.forEach((artist, i) => {
    row(2, 1n, artist, 0n, artist, BigInt(3 * i + 1)); row(2, 35n, artist, 0n, H(1500 + i), BigInt(3 * i + 2)); row(2, 35n, artist, 0n, H(1600 + i), BigInt(3 * i + 2));
  });
  const timing = { schema: id("6529STREAM_ARTIST_RECOVERED_TIMING_INVENTORY_V1"), version: 1n, count: 0n, root: Z, configurationHash: H(400) };
  const identities = ids.map((artist, i) => {
    const b = zero(T.identity); b.artistId = artist; b.nextRegistrationNonce = BigInt(ids.length);
    Object.assign(b.identity, { authorityAddress: A(400 + i), authorityClass: classes[i], status: 1n }); b.timing.checkpoint = clone(timing);
    b.nonces = [{ kind: 1n, key: artist, hint: 0n, words: [{ prefix: 0n, words: Array.from({ length: 32 }, (_, i) => i === 0 ? 1n : 0n), exhausted: false }] }];
    const recovery = zero(child(T.identity, "recoveries").arrayChildren); recovery.record.fields.vestedAuthorityClass = classes[i]; b.recoveries = [recovery];
    return b;
  });
  if (delegated) identities.forEach((b, i) => {
    const g = zero(child(T.identity, "delegations").arrayChildren), uses = BigInt(collections.filter(q => q.artistId === b.artistId).length * (royalties ? 4 : 3));
    Object.assign(g.record.grant, { artistId: b.artistId, delegate: A(700), capabilities: 1062n, notBefore: 1n, expiresAt: 2n, maxUses: uses });
    Object.assign(g.record, { grantor: A(400 + i), nonce: BigInt(i + 7), uses });
    g.recordHash = grantRecord(origin, g.record.grant, g.record.nonce); g.current = g.recordHash;
    const j = row(2, 26n, b.artistId, 0n, g.recordHash, BigInt(20 + i)); g.position = clone(j.position);
    b.delegations = [g]; b.signatures.push({ recordHash: g.recordHash, signature: "0x0102" });
    const digest = grantDigest(origin, g.record.grant, g.record.nonce);
    alias(2, j.position.point, "identity_authority.replay.delegation_key", g.recordHash, g.recordHash);
    alias(2, j.position.point, "identity_authority.replay.nonce_allocator", hash(["bytes32", "uint256"], [b.artistId, g.record.nonce]), digest);
    alias(2, j.position.point, "identity_authority.replay.authorization_consumed_digest", hash(["bytes32", "bytes32"], [b.artistId, digest]), digest);
    b.nonces.push({ kind: 2n, key: delegateLane(b.artistId, A(700)), hint: uses,
      words: [{ prefix: 0n, words: Array.from({ length: 32 }, (_, k) => k === 0 ? (1n << uses) - 1n : 0n), exhausted: false }] });
  });
  const used = new Map(ids.map(artist => [artist, 0n]));
  const contents = collections.map((q, i) => {
    const b = zero(T.content), identity = identities.find(a => a.artistId === q.artistId), grant = delegated ? identity.delegations[0].recordHash : Z;
    Object.assign(b.original, { artistId: q.artistId, collectionId: q.collectionId, bindingHash: q.bindingHash, keys: clone(q.policies) });
    b.original.policies = [{ recordHash: H(5000 + i), grant }];
    const e = zero(child(T.original, "economics").arrayChildren);
    Object.assign(e.item.terms, { collectionId: q.collectionId, resolver: suite.primaryResolver, revenueClass: H(5100), scope: 1n, scopeId: q.collectionId, assignmentHash: H(5200 + i) });
    e.item.recordHash = H(5300 + i); e.grant = grant;
    Object.assign(e.item.association, { artistId: q.artistId, bindingGeneration: 1n, bindingHash: q.bindingHash, payloadHash: hash([child(child(T.original, "economics").arrayChildren, "item").components.find(c => c.name === "terms")], [e.item.terms]), originalRecord: e.item.recordHash });
    b.original.economics = [e];
    const sale = zero(child(T.original, "sales").arrayChildren);
    Object.assign(sale.item.terms, { collectionId: q.collectionId, saleAdapter: A(710), saleId: H(5400 + i), saleConfigHash: H(5500 + i) });
    const nonce = used.get(q.artistId) + 2n; used.set(q.artistId, used.get(q.artistId) + (royalties ? 4n : 3n));
    Object.assign(sale.item, { artistId: q.artistId, signer: delegated ? A(700) : identity.identity.authorityAddress, authorityClass: delegated ? 2n : identity.identity.authorityClass,
      nonce, signedAt: 1n, bindingGeneration: 1n, bindingHash: q.bindingHash });
    sale.item.recordHash = saleRecord(origin, sale.item); sale.current = sale.item.recordHash; sale.grant = grant; b.original.sales = [sale];
    b.consents = [{ recordHash: H(5600 + i), artistId: q.artistId, bindingGeneration: 1n,
      terms: { collectionId: q.collectionId, metadataContract: suite.metadata, familyId: H(5700 + i), newStateHash: H(5800 + i) }, authorityClass: identity.identity.authorityClass }];
    b.royalties = royalties ? [{ terms: { resolver: suite.royaltyResolver, collectionId: q.collectionId, revenueClass: id("ROYALTY_ERC2981"), expectedAssignmentHash: H(5900 + i) }, item: { recordHash: H(6000 + i), artistId: q.artistId, bindingGeneration: 1n }, grant }] : [];
    b.freezes = [{ recordHash: H(6100 + i), artistId: q.artistId, bindingGeneration: 1n, metadataContract: suite.metadata, lockClasses: [H(1), H(2)], expectedStateHash: H(6200 + i), authorityClass: identity.identity.authorityClass }];
    if (delegated) alias(2, { environmentHash: oh, ownerIndex: 2n, ownerRevision: BigInt(30 + i) }, "identity_authority.replay.delegated_nonce", hash(["bytes32", "uint256"], [delegateLane(q.artistId, A(700)), nonce]), H(6300 + i));
    for (const recordHash of [b.original.policies[0].recordHash, e.item.recordHash, sale.item.recordHash, b.consents[0].recordHash, ...b.royalties.map(r => r.item.recordHash), b.freezes[0].recordHash]) identity.signatures.push({ recordHash, signature: i % 2 ? "0x" : "0x1234" });
    return b;
  });
  // Interleave by operation and reverse collection order, so global royalty ordering
  // cannot accidentally be replaced by concatenating per-collection arrays.
  for (const op of [14n, 15n, 16n, 17n, 20n, 21n]) for (const i of collections.map((_, i) => i).reverse()) {
    const q = collections[i], b = contents[i]; if (op === 20n && !royalties) continue;
    let recordHash, surface, scope;
    if (op === 14n) { recordHash = b.original.policies[0].recordHash; surface = "policy_consent_key"; scope = hash(["uint256", "bytes32", "bytes32"], [q.collectionId, q.policies[0].phaseId, q.policies[0].policyHash]); }
    if (op === 15n) { recordHash = b.original.economics[0].item.recordHash; surface = "consent_key"; scope = b.original.economics[0].item.association.payloadHash; }
    if (op === 16n) { const r = b.original.sales[0].item; recordHash = r.recordHash; surface = "sale_consent_key"; scope = hash([child(child(T.original, "sales").arrayChildren, "item").components.find(c => c.name === "terms"), "uint64", "bytes32"], [r.terms, 1n, q.bindingHash]); }
    if (op === 17n) { const r = b.consents[0]; recordHash = r.recordHash; surface = "content_consent_key"; scope = hash(["bytes32", "bytes32"], [hash([child(child(T.content, "consents").arrayChildren, "terms"), "uint64"], [r.terms, 1n]), recordHash]); }
    if (op === 20n) { const r = b.royalties[0]; recordHash = r.item.recordHash; surface = "freeze_key"; scope = hash([child(child(T.content, "royalties").arrayChildren, "terms"), "bytes32", "uint64"], [r.terms, q.artistId, 1n]); }
    if (op === 21n) { recordHash = b.freezes[0].recordHash; surface = "freeze_key"; scope = hash(["bytes32", "uint256", "uint64", "bytes32"], [id("CONTENT"), q.collectionId, 1n, recordHash]); }
    const j = row(6, op, q.artistId, q.collectionId, recordHash, BigInt(journals[6].length + 1)); alias(6, j.position.point, `consent_finality.replay.${surface}`, scope, recordHash);
  }
  const nonces = identities.toReversed().flatMap(b => b.nonces.map(n => ({ index: { kind: n.kind, key: n.key, prefixCount: BigInt(n.words.length) }, words: clone(n.words) })));
  const checkpoints = seven(i => ({ schema: m.ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_CHECKPOINT_SCHEMA,
    ownerState: { domainId: m.artistRecoveredMultipleConsentHydrationOwnerDomain(i), revision: [BigInt(2 * collectionCount), 0n, 50n, BigInt(collectionCount), BigInt(2 * collectionCount), 0n, BigInt(journals[6].length)][i], stateRoot: H(200 + i), recordChainTip: H(220 + i) },
    replayRoot: aliases[i].length ? H(240 + i) : Z, replayCount: BigInt(aliases[i].length), nonceRoot: i === 2 ? H(280) : Z, nonceIndexCount: i === 2 ? BigInt(nonces.length) : 0n }));
  for (const [domain, field] of [["STATE", "stateRoot"], ["RECORD", "recordChainTip"]]) checkpoints[1].ownerState[field] = hash(["bytes32", "uint256", "address", "address", "address", "address", "bytes32"],
    [id(`6529STREAM_ARTIST_OWNER_${domain}_GENESIS_V2`), chainId, origin.registry, origin.coordinator, origin.archive, origin.owners[1], m.artistRecoveredMultipleConsentHydrationOwnerDomain(1)]);
  const provenance = { origins: [origin], eras: [{ originHash: oh, priorImportCommitment: Z, checkpoints, nativeCounts: journals.map(a => BigInt(a.length)), lowerRevisions: seven(() => 0n) }], journals, aliases };
  const artists = ids.map(artistId => ({ artistId, collectionId: 0n, bindingHash: Z, policies: [], records: [] }));
  const payouts = artists.map(a => { const b = zero(T.payout); b.artistId = a.artistId; b.sourceSnapshot = clone(checkpoints[5].ownerState); return b; });
  const before = args.before ?? seven(i => ({ domainId: m.artistRecoveredMultipleConsentHydrationOwnerDomain(i), revision: i === 2 ? 1n + BigInt(ids.length + collectionCount) : 0n, stateRoot: H(300 + i), recordChainTip: H(320 + i) }));
  // Every synthetic collection has a sale, so bit64 is required even in direct mode1.
  const features = 524288n | 32n | 64n | 256n | classes.slice(0, ids.length).reduce((a, c) => a | (c === 1n ? 1n : 2n), 0n);
  const f = { options, request: null, input: null, prepared: null, certificate: null, states: [], payloads: [], identities, payouts, contents, nonces, provenance, features, origin, bindings, artists, collections, timing, before, source: suite,
    coords: { chainId, registry: A(101), coordinator: A(102) }, codes: args.codes };
  refresh(f);
  return f;
}

/** Rebuild commitments after deliberate mutations, without fixing the mutated facts. */
export function refresh(f) {
  const { provenance: p, artists, collections, identities, payouts, contents, origin, bindings } = f;
  const oh = p.eras[0].originHash, cp = p.eras.at(-1).checkpoints;
  for (const owner of [0, 2, 3, 6]) p.aliases[owner].sort((a, b) => BigInt(a.originalKey) < BigInt(b.originalKey) ? -1 : 1);
  for (const a of artists) a.records = p.journals.flat().filter(j => j.receipt.artistId === a.artistId).map(j => j.receipt.recordHash);
  for (const q of collections) q.records = p.journals.flat().filter(j => j.receipt.collectionId === q.collectionId).map(j => j.receipt.recordHash);
  const logical = p.aliases.map(rows => rows.map(({ surface, scope }) => ({ surface, scope })));
  const data = seven(owner => {
    const local = m.artistRecoveredMultipleConsentHydrationOwnerProvenance(p, owner), commitment = m.artistRecoveredMultipleConsentHydrationOwnerProvenanceHash(local, owner);
    let rows = [];
    if (owner === 0) rows = bindings.map(b => { b.provenanceCommitment = commitment; return coder.encode([T.binding], [b]); });
    if (owner === 2) rows = identities.map(b => { b.sourceSnapshot = clone(cp[2].ownerState); return coder.encode([T.identity], [b]); });
    if (owner === 3) rows = collections.map((q, i) => coder.encode([T.acceptance], [{ scope: { artistId: q.artistId, collectionId: q.collectionId, bindingHash: q.bindingHash }, provenanceCommitment: commitment, record: H(1300 + i), acceptedAt: 1n }]));
    if (owner === 4) rows = collections.map(q => coder.encode([`tuple(${T.attribution.format("full")} state,bytes32 proposalOrigin)`], [{ state: { provenance: commitment, artistId: q.artistId, collectionId: q.collectionId, bindingHash: q.bindingHash, item: { state: 2n, generation: 1n } }, proposalOrigin: oh }]));
    if (owner === 5) rows = payouts.map(b => coder.encode(["bytes32", T.payout], [id("6529STREAM_ARTIST_RECOVERED_PAYOUT_HYDRATION_V1"), b]));
    if (owner === 6) rows = contents.map(b => { b.original.provenance = commitment; return coder.encode([T.content], [b]); });
    const s = { artists: clone(artists), collections: clone(collections), rows }; f.states[owner] = s;
    const publications = f.codes && [2, 4, 6].includes(owner) ? [{ pointer: A(90 + owner), payloadType: H(800 + owner), payloadHash: keccak256("0x1234") }] : [];
    if (publications.length) f.codes.set(publications[0].pointer, "0x001234");
    const payload = { provenance: local, nonces: owner === 2 ? clone(f.nonces) : [], publications,
      semanticState: coder.encode(["bytes32", "uint16", "uint8", T.state], [id("6529STREAM_ARTIST_RECOVERED_MULTIPLE_CONSENTS_V1"), 1n, BigInt(owner), s]) };
    f.payloads[owner] = payload;
    const keys = logical[owner].map(v => m.artistRecoveredMultipleConsentHydrationReplayKey(origin, owner, v));
    return { typedState: m.encodeArtistRecoveredMultipleConsentHydrationOwnerPayload(payload, owner, f.features), origins: logical[owner], sourceKeys: keys, cells: keys.map(key => p.aliases[owner].find(a => a.originalKey === key).cell), nonces: [] };
  });
  const query = { ...clone(collections[0]), records: clone(artists.find(a => a.artistId === collections[0].artistId).records) };
  f.prepared = f.certificate = { admission: { prior: origin.registry, sourceCoordinator: origin.coordinator, source: f.source, provenance: p, artists, collections, before_: f.before }, query, data, timing: f.timing,
    externalGuards: { schema: id("6529STREAM_ARTIST_RECOVERED_EXTERNAL_GUARDS_V1"), provenanceCommitment: m.artistRecoveredMultipleConsentHydrationProvenanceHash(p), artistId: artists[0].artistId, actions: [], finality: [], entropy: [] } };
  f.request = { records: { authority: { bindingIndex: 0n, artistIds: artists.map(a => a.artistId), collections: collections.map(q => ({ artistId: q.artistId, collectionId: q.collectionId, policies: clone(q.policies) })), expectedSource: cp, replayOrigins: logical },
    witnesses: contents.filter(b => b.original.economics.length).map(b => ({ collectionId: b.original.collectionId, economics: b.original.economics.map(e => clone(e.item.terms)), attestations: [] })) },
    expectedCapabilities: seven(i => ({ profile: m.ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_PROFILE, version: 1n, ownerIndex: BigInt(i), ownerDomain: m.artistRecoveredMultipleConsentHydrationOwnerDomain(i),
      checkpointSchema: m.ARTIST_RECOVERED_MULTIPLE_CONSENT_HYDRATION_CHECKPOINT_SCHEMA, stateSchema: m.artistRecoveredMultipleConsentHydrationOwnerTag(i), supportedFeatures: 1048575n })), expectedSourceImportCommitment: Z, expectedSemanticInventory: Z };
  // Original semanticInventory is a supplied-facts preimage, independent of full admission.
  const q = f.prepared;
  f.request.expectedSemanticInventory = hash(["bytes32", "uint16", "bytes32", child(T.prepared, "query"), child(T.prepared, "data"), child(T.prepared, "timing"), child(T.prepared, "externalGuards")],
    [id("6529STREAM_ARTIST_RECOVERED_SEMANTIC_INVENTORY_V1"), 1n, m.artistRecoveredMultipleConsentHydrationProvenanceHash(p), q.query, q.data, q.timing, q.externalGuards]);
  f.input = { request: f.request, royaltyFreezes: p.journals[6].filter(j => j.receipt.operation === 20n).map(j => clone(contents.flatMap(b => b.royalties).find(r => r.item.recordHash === j.receipt.recordHash).terms)) };
  return f;
}
