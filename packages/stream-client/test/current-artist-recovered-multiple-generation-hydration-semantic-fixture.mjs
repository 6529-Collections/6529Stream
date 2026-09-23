// Compiler-shaped supplied facts only. Private Identity/Payout lifecycle admission,
// runtime provenance, signature validity and actual Registry execution are mocked.
import { AbiCoder, ParamType, ZeroAddress, ZeroHash, getAddress, id, keccak256, toUtf8Bytes, hexlify } from "ethers";
import * as m from "../dist/current-artist-recovered-multiple-generation-hydration.js";
import { ARTIST_HYDRATION_SUITE_TUPLE } from "../dist/current-artist-authority-hydration.js";
import { fixture, compiledLibraryValueInterface, libraryValueABI, generationTuple } from "./current-artist-recovered-multiple-generation-hydration-source-fixture.mjs";
export { m, fixture };
export const coder = AbiCoder.defaultAbiCoder(), Z = ZeroHash;
export const A = n => getAddress(`0x${BigInt(n).toString(16).padStart(40, "0")}`);
export const H = n => `0x${BigInt(n).toString(16).padStart(64, "0")}`;
export const hash = (types, values) => keccak256(coder.encode(types, values));
export const seven = fn => Array.from({ length: 7 }, (_, i) => fn(i));
export const child = (t, name) => t.components.find(c => c.name === name);
const clone = structuredClone, cached = new Map();
export function findType(name) { return generationTuple(name); }
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
  attestation: findType("StreamArtistRecoveredAttestationHydration.Bundle"),
  clocks: findType("StreamArtistRecoveredMultipleGenerationTypes.Inventory"),
  envelope: findType("StreamArtistRecoveredSanctionHistoryTypes.Envelope"),
  proposal: findType("StreamArtistRecoveredPlatformPayload.Proposal"),
  acceptancePayload: findType("StreamArtistRecoveredPlatformPayload.Acceptance"),
  authority: findType("StreamArtistRotationTypes.AuthorityFact"),
  credential: findType("StreamArtistC2PATypes.Payload"),
  credentialHead: findType("StreamArtistC2PATypes.Head"),
};
T.bindingBundle = findType("StreamArtistRecoveredBindingCorrectionTypes.Bundle");
T.acceptanceBundle = findType("StreamArtistRecoveredAcceptedGenerationTypes.AcceptanceBundle");
T.history = findType("StreamArtistRecoveredAcceptedGenerationTypes.AttributionBundle");
T.generation = findType("StreamArtistRecoveredAcceptedGenerationTypes.Generation");
T.consents = findType("StreamArtistRecoveredMultipleGenerationTypes.Consents");
T.gAttribution = ParamType.from(`tuple(${T.history.format("full")} history,${T.attestation.format("full")} records)`);
T.correctionPayload = findType("StreamArtistRecoveredPlatformPayload.Correction");
T.refusalPayload = findType("StreamArtistRecoveredPlatformPayload.Refusal");
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
export function typed(origin, body) {
  const domain = hash(["bytes32", "bytes32", "bytes32", "uint256", "address"],
    [id("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"), id("6529StreamArtistRegistry"), id("1"), origin.chainId, origin.registry]);
  return keccak256(`0x1901${domain.slice(2)}${body.slice(2)}`);
}
export function attestationRecord(origin, artist, r) {
  const t = r.input.terms;
  return hash(["bytes32", "uint256", "address", "address", "uint256", "uint8", "bytes32", "bytes32", "bytes32", "bytes32", "bytes32", "bytes32", "address", "uint8", "uint256", "uint64"],
    [id("6529STREAM_ARTIST_ATTESTATION_RECORD_V1"), origin.chainId, origin.registry, origin.core, t.collectionId, t.subjectKind, t.subjectId,
      t.subjectStateHash, t.schemaId, t.statementHash, keccak256(toUtf8Bytes(t.statementURI)), artist, r.record.signer, r.authorityClass, r.input.nonce, r.record.signedAt]);
}
export function attestationDigest(origin, r) {
  const t = r.input.terms;
  return typed(origin, hash(["bytes32", "address", "uint256", "uint8", "bytes32", "bytes32", "bytes32", "bytes32", "bytes32", "uint256", "uint64"],
    [id("StreamArtistAttestation(address core,uint256 collectionId,uint8 subjectKind,bytes32 subjectId,bytes32 subjectStateHash,bytes32 schemaId,bytes32 statementHash,bytes32 statementURIHash,uint256 nonce,uint64 signedAt)"),
      origin.core, t.collectionId, t.subjectKind, t.subjectId, t.subjectStateHash, t.schemaId, t.statementHash, keccak256(toUtf8Bytes(t.statementURI)), r.input.nonce, r.record.signedAt]));
}
export function acceptanceRecord(origin, collectionId, binding, signer, authorityClass, nonce, signedAt) {
  return hash(["bytes32", "uint256", "address", "address", "uint256", "uint64", "bytes32", "uint8", "address", "uint8", "uint256", "uint64"],
    [id("6529STREAM_ARTIST_ACCEPTANCE_RECORD_V1"), origin.chainId, origin.registry, origin.core, collectionId, binding.generation, binding.bindingHash, 1n, signer, authorityClass, nonce, signedAt]);
}
export function acceptanceDigest(origin, collectionId, binding, auth) {
  return typed(origin, hash(["bytes32", "address", "uint256", "uint64", "bytes32", "bytes32", "uint256", "uint64"],
    [id("StreamArtistAcceptance(address core,uint256 collectionId,uint64 bindingGeneration,bytes32 bindingHash,bytes32 identityRecordHash,uint256 nonce,uint64 deadline)"),
      origin.core, collectionId, binding.generation, binding.bindingHash, binding.identityRecordHash, auth.nonce, auth.time]));
}


// New-generation constructor. Identity/Payout scaffolding is supplied documentary
// material; their private state machines and every native call remain unexecuted.
export function semanticFixture(args = {}) {
  const options = args.options ?? args;
  const { acceptedHistory = false, attestations = false, collectionCount = 3, oneArtist = false, classes = [1n, 3n], delegated = true, royalties = true, consents = true } = options;
  const ids = oneArtist ? [H(1000)] : [H(1000), H(1001)];
  const source = args.source ?? { registry: A(1), archive: A(3), owners: seven(i => A(10 + i)), core: A(4), mintManager: A(5),
    roleRegistry: A(6), metadata: A(7), primaryResolver: A(8), royaltyResolver: A(9), primaryRevenueClass: H(8), validator: A(17) };
  const chainId = args.origin?.chainId ?? (1n << 200n) + 11n;
  const origin = args.origin ?? { chainId, registry: source.registry, coordinator: A(2), archive: source.archive, owners: source.owners,
    ownerCodeHashes: seven(i => H(100 + i)), core: source.core, manager: source.mintManager, suiteConfigurationHash: hash([ARTIST_HYDRATION_SUITE_TUPLE], [source]) };
  const oh = m.artistRecoveredMultipleGenerationHydrationOriginHash(origin);
  const collections = Array.from({ length: collectionCount }, (_, i) => ({ artistId: ids[oneArtist ? 0 : i === collectionCount - 1 ? 0 : 1],
    collectionId: (1n << 240n) + BigInt(i + 3), bindingHash: Z, policies: [], records: [] }));
  const artists = ids.map(artistId => ({ artistId, collectionId: 0n, bindingHash: Z, policies: [], records: [] }));
  const timing = { schema: id("6529STREAM_ARTIST_RECOVERED_TIMING_INVENTORY_V1"), version: 1n, count: 0n, root: Z, configurationHash: H(400) };
  const identities = ids.map((artistId, i) => {
    const b = zero(T.identity); b.artistId = artistId; b.nextRegistrationNonce = BigInt(ids.length);
    Object.assign(b.identity, { authorityAddress: A(400 + i), authorityClass: classes[i], status: classes[i] === 3n ? 3n : 1n }); b.timing.checkpoint = clone(timing);
    const recovery = zero(child(T.identity, "recoveries").arrayChildren); recovery.record.fields.vestedAuthorityClass = classes[i]; b.recoveries = [recovery];
    b.nonces = [{ kind: 1n, key: artistId, hint: 0n, words: [{ prefix: 0n, words: Array.from({ length: 32 }, (_, k) => k === 0 ? 1n : 0n), exhausted: false }] }];
    return b;
  });
  const journals = seven(() => []), aliases = seven(() => []);
  const clock = seven(i => ({ domainId: m.artistRecoveredMultipleGenerationHydrationOwnerDomain(i), revision: i === 2 ? 20n : 0n, stateRoot: H(9000 + i), recordChainTip: H(9100 + i) }));
  for (const [domain, field] of [["STATE", "stateRoot"], ["RECORD", "recordChainTip"]]) clock[1][field] = hash(["bytes32", "uint256", "address", "address", "address", "address", "bytes32"],
    [id(`6529STREAM_ARTIST_OWNER_${domain}_GENESIS_V2`), chainId, origin.registry, origin.coordinator, origin.archive, origin.owners[1], clock[1].domainId]);
  const point = owner => ({ environmentHash: oh, ownerIndex: BigInt(owner), ownerRevision: clock[owner].revision });
  const row = (owner, operation, artistId, collectionId, recordHash, p = point(owner)) => {
    const j = { position: { point: clone(p), nativeIndex: BigInt(journals[owner].length) }, receipt: { operation, artistId, collectionId, recordHash } };
    journals[owner].push(j); return j;
  };
  const alias = (owner, p, surface, scope, commitment) => {
    const entry = { surface: id(surface), scope };
    aliases[owner].push({ originHash: oh, ownerIndex: BigInt(owner), ...entry, originalKey: m.artistRecoveredMultipleGenerationHydrationReplayKey(origin, owner, entry),
      cell: { commitment, touchedRevision: p.ownerRevision, kind: 1n, status: 2n }, admittedAt: clone(p) });
  };
  ids.forEach((artist, i) => {
    row(2, 1n, artist, 0n, artist, { environmentHash: oh, ownerIndex: 2n, ownerRevision: BigInt(3 * i + 1) });
    for (const n of [1500, 1600]) row(2, 35n, artist, 0n, H(n + i), { environmentHash: oh, ownerIndex: 2n, ownerRevision: BigInt(3 * i + 2) });
  });
  if (delegated && consents) for (const identity of identities) {
    const i = ids.indexOf(identity.artistId), g = zero(child(T.identity, "delegations").arrayChildren);
    const count = BigInt(collections.filter(q => q.artistId === identity.artistId).length * (1 + (acceptedHistory ? 2 : 1) * (royalties ? 3 : 2)));
    Object.assign(g.record.grant, { artistId: identity.artistId, delegate: A(700), capabilities: 1127n, notBefore: 1n, expiresAt: 100n, maxUses: count });
    Object.assign(g.record, { grantor: identity.identity.authorityAddress, nonce: BigInt(7 + i), uses: count });
    g.recordHash = grantRecord(origin, g.record.grant, g.record.nonce); g.current = g.recordHash;
    clock[2].revision++; const j = row(2, 26n, identity.artistId, 0n, g.recordHash); g.position = clone(j.position); identity.delegations.push(g);
    identity.signatures.push({ recordHash: g.recordHash, signature: "0x0102" }); const digest = grantDigest(origin, g.record.grant, g.record.nonce);
    alias(2, point(2), "identity_authority.replay.delegation_key", g.recordHash, g.recordHash);
    alias(2, point(2), "identity_authority.replay.nonce_allocator", hash(["bytes32", "uint256"], [identity.artistId, g.record.nonce]), digest);
    alias(2, point(2), "identity_authority.replay.authorization_consumed_digest", hash(["bytes32", "bytes32"], [identity.artistId, digest]), digest);
    identity.nonces.push({ kind: 2n, key: delegateLane(identity.artistId, A(700)), hint: count,
      words: [{ prefix: 0n, words: Array.from({ length: 32 }, (_, k) => k === 0 ? (1n << count) - 1n : 0n), exhausted: false }] });
  }
  const bindings = collections.map((q, k) => {
    const b = zero(T.bindingBundle); Object.assign(b.bindings, { artistId: q.artistId, collectionId: q.collectionId });
    const rtype = child(child(T.bindingBundle, "bindings"), "rows").arrayChildren;
    for (let g = 0; g < 2; g++) {
      const r = zero(rtype), document = hexlify(toUtf8Bytes(`generation identity ${k}/${g}`)), dh = keccak256(document);
      const d = zero(child(T.identity, "documents").arrayChildren); Object.assign(d, { documentHash: dh, document }); identities.find(i => i.artistId === q.artistId).documents.push(d);
      Object.assign(r.item, { artistId: q.artistId, artistAddress: A(50 + k), identityRecordHash: dh, generation: BigInt(g + 1), consentMode: delegated ? 2n : 1n, proposer: A(70), accepted: g === 1 || acceptedHistory });
      r.terms.collaboratorSetHash = emptyHash("6529STREAM_ARTIST_COLLABORATOR_SET_V1"); r.terms.capabilityPolicySetHash = emptyHash("6529STREAM_ARTIST_CAPABILITY_POLICY_SET_V1");
      r.item.bindingHash = hash(["bytes32", "uint256", "address", "address", "uint256", "uint64", "bytes32", "address", "bytes32", "uint8", "uint8", "uint8", "bytes32", "bytes32"],
        [id("6529STREAM_ARTIST_BINDING_V1"), chainId, origin.registry, origin.core, q.collectionId, r.item.generation, q.artistId, r.item.artistAddress, dh, r.item.consentMode, 0n, 0n, r.terms.collaboratorSetHash, r.terms.capabilityPolicySetHash]);
      if (!r.item.accepted) Object.assign(r.terminal, { kind: k % 2 ? 2n : 1n, reasonHash: H(1800 + k), recordHash: k % 2 ? Z : H(1900 + k) });
      b.bindings.rows.push(r); b.corrections.push(zero(child(T.bindingBundle, "corrections").arrayChildren));
    }
    q.bindingHash = b.bindings.rows[1].item.bindingHash; b.bindings.bindingHash = q.bindingHash; b.bindings.current = clone(b.bindings.rows[1].item); return b;
  });
  const acceptances = collections.map(q => Object.assign(zero(T.acceptanceBundle), { artistId: q.artistId, collectionId: q.collectionId, bindingHash: q.bindingHash }));
  const attribution = collections.map(q => {
    const b = zero(T.gAttribution);
    Object.assign(b.history, { artistId: q.artistId, collectionId: q.collectionId, bindingHash: q.bindingHash, current: { state: 2n, generation: 2n } });
    Object.assign(b.records, { artistId: q.artistId, collectionId: q.collectionId, bindingHash: q.bindingHash, item: { state: 2n, generation: 2n } }); return b;
  });
  const contents = collections.map((q, k) => {
    const c = zero(T.consents); Object.assign(c.rows.original, { artistId: q.artistId, collectionId: q.collectionId, bindingHash: q.bindingHash });
    c.bindings = bindings[k].bindings.rows.map(r => clone(r.item)); return c;
  });
  const generations = collections.map(() => []), envelopes = [], archiveRows = [], operations = [], envelopeFacts = [];
  const credentialHeads = new Map(ids.map(a => [a, zero(T.credentialHead)])), credentialRecords = new Map();
  const used = new Map(ids.map(a => [a, 1n])), delegateUsed = new Map(ids.map(a => [a, 0n]));
  const config = H(8900);
  function advance(owner) { clock[owner].revision++; clock[owner].stateRoot = H(30000 + owner * 1000 + Number(clock[owner].revision)); }
  function publication(k, g, operation) {
    const q = collections[k], retained = bindings[k].bindings.rows[g], binding = { ...retained.item, accepted: false }, identity = identities.find(i => i.artistId === q.artistId);
    const e = zero(T.envelope), mask = operation === 2n ? [0, 1, 2, 3, 4] : operation === 4n ? [0, 4] : [0, 2, 4];
    Object.assign(e, { version: 1n, configurationHash: config, operation, actor: operation === 1n || operation === 4n ? binding.proposer : identity.identity.authorityAddress });
    for (const i of mask) { e.before_[i] = clone(clock[i]); if (i !== 1) advance(i); e.after_[i] = clone(clock[i]); }
    let action, state;
    const proposal = zero(T.proposal); proposal.id = q.collectionId; proposal.reused = true;
    Object.assign(proposal.proposal, { artistId: q.artistId, artistAddress: binding.artistAddress, identityRecordHash: binding.identityRecordHash, consentMode: binding.consentMode, reasonHash: H(9300 + k * 2 + g), reasonURI: "urn:original-generation-proposal" });
    if (operation === 1n) {
      e.value = binding.bindingHash;
      if (g && acceptedHistory) {
        const c = bindings[k].corrections[g], a = c.approval, previous = bindings[k].bindings.rows[g - 1], r = attribution[k].history.revocations[g - 1];
        const rt = child(T.history, "revocations").arrayChildren;
        a.previous = clone(previous.item); a.cause = 4n; a.causeRecord = r.resolution.actionId;
        a.causeData = coder.encode([child(T.binding, "terminal"), ...rt.components], [previous.terminal, r.head, r.opening, r.resolution]);
        a.proposedArtistId = q.artistId; a.approvedAt = 4n;
        a.proposalHash = hash(["uint256", child(T.proposal, "proposal"), "bytes", "string"], [proposal.id, proposal.proposal, proposal.document, proposal.displayName]);
        Object.assign(a.governance, { actionId: H(20000 + k), proposer: A(70), actionClass: 2n, roleMutationHash: H(20100 + k), roleRevision: 1n });
        a.governance.scopeHash = hash(["bytes32", "uint256", "address", "address", "address", "uint256", "uint64"], [id("6529STREAM_ARTIST_BINDING_CORRECTION_SCOPE_V1"), chainId, origin.registry, origin.core, origin.manager, q.collectionId, previous.item.generation]);
        a.governance.oldValueHash = hash([child(T.binding, "item"), "uint8", "uint8", "bytes32", "bytes"], [a.previous, 5n, a.cause, a.causeRecord, a.causeData]);
        a.governance.newValueHash = hash(["bytes32", "bytes32", "bytes32", "bytes32", "uint256"], [a.governance.scopeHash, a.governance.oldValueHash, a.proposalHash, a.proposedArtistId, 0n]);
        c.recordHash = hash(["bytes32", "uint256", "address", "address", "address", "uint256", "bytes32", child(child(T.bindingBundle, "corrections").arrayChildren, "approval")],
          [id("6529STREAM_ARTIST_BINDING_CORRECTION_RECORD_V1"), chainId, origin.registry, origin.core, origin.manager, q.collectionId, binding.bindingHash, a]);
        const payload = zero(T.correctionPayload); Object.assign(payload, proposal, { tag: id("6529STREAM_ARTIST_BINDING_CORRECTION_EVIDENCE_V1"), version: 1n, approval: clone(a) });
        Object.assign(payload.context, { scopeHash: a.governance.scopeHash, oldValueHash: a.governance.oldValueHash, newValueHash: a.governance.newValueHash });
        e.payload = coder.encode(T.correctionPayload.components, T.correctionPayload.components.map(c => payload[c.name]));
        alias(0, point(0), "binding_lifecycle.replay.correction_action", a.governance.actionId, c.recordHash);
      } else e.payload = coder.encode(T.proposal.components, T.proposal.components.map(c => proposal[c.name]));
      action = hash(["uint256", child(T.binding, "item"), "bytes32", "string"], [q.collectionId, binding, proposal.proposal.reasonHash, proposal.proposal.reasonURI]);
      state = hash(["uint256", "uint8", "uint64"], [q.collectionId, 1n, binding.generation]);
      const generation = { bindingHash: binding.bindingHash, generation: binding.generation, accepted: retained.item.accepted, proposal: point(0) };
      generations[k].push(generation); attribution[k].history.generations.push(clone(generation));
      row(0, 1n, q.artistId, q.collectionId, binding.bindingHash); alias(0, point(0), "binding_lifecycle.replay.proposal_key", hash(["uint256", "uint64"], [q.collectionId, binding.generation]), binding.bindingHash);
    } else if (operation === 2n) {
      const payload = zero(T.acceptancePayload); payload.id = q.collectionId; payload.binding_ = binding;
      Object.assign(payload.authorization, { nonce: BigInt(100 + 2 * k + g), time: BigInt(g + 2), signature: "0x" });
      Object.assign(payload.proof, { signer: e.actor, digest: acceptanceDigest(origin, q.collectionId, binding, payload.authorization), direct: true });
      const authority = { artistId: q.artistId, authorityAddress: e.actor, authorityClass: identity.identity.authorityClass, status: identity.identity.status };
      e.value = acceptanceRecord(origin, q.collectionId, binding, e.actor, authority.authorityClass, payload.authorization.nonce, payload.authorization.time);
      acceptances[k].rows.push({ bindingHash: binding.bindingHash, generation: binding.generation, recordHash: e.value, acceptedAt: payload.authorization.time });
      e.payload = coder.encode(["bytes", T.authority], [coder.encode(T.acceptancePayload.components, T.acceptancePayload.components.map(c => payload[c.name])), authority]);
      action = hash(["uint256", child(T.binding, "item"), "bytes32"], [q.collectionId, binding, e.value]); state = hash(["uint256", child(T.attestation, "item")], [q.collectionId, { state: 2n, generation: binding.generation }]);
      row(3, 2n, q.artistId, q.collectionId, e.value); alias(3, point(3), "acceptance_lifecycle.replay.record_uniqueness", H(1400 + 2 * k + g), e.value);
      identity.signatures.push({ recordHash: e.value, signature: "0x" });
    } else {
      const terms = { collectionId: q.collectionId, generation: binding.generation, bindingHash: binding.bindingHash, reasonHash: retained.terminal.reasonHash, reasonURI: "urn:original-generation-terminal" };
      let authority = 0n, nonce = 0n;
      if (operation === 3n) {
        const payload = zero(T.refusalPayload); payload.binding_ = binding; payload.terms = terms;
        Object.assign(payload.authorization, { nonce: BigInt(200 + k), time: 2n, signature: "0x" }); Object.assign(payload.proof, { signer: e.actor, digest: H(2200 + k), direct: true });
        Object.assign(payload.authority, { artistId: q.artistId, authorityAddress: e.actor, authorityClass: identity.identity.authorityClass, status: identity.identity.status });
        authority = payload.authority.authorityClass; nonce = payload.authorization.nonce; e.value = retained.terminal.recordHash;
        e.payload = coder.encode(T.refusalPayload.components, T.refusalPayload.components.map(c => payload[c.name]));
        row(0, 3n, q.artistId, q.collectionId, e.value); identity.signatures.push({ recordHash: e.value, signature: "0x" });
      } else { e.value = binding.bindingHash; e.payload = coder.encode([child(T.binding, "item"), child(T.refusalPayload, "terms")], [binding, terms]); }
      action = hash([child(T.binding, "item"), child(T.refusalPayload, "terms"), "address", "uint8", "uint256", "bytes32"], [binding, terms, e.actor, authority, nonce, e.value]);
      state = hash(["uint256", child(T.attestation, "item")], [q.collectionId, { state: 5n, generation: binding.generation }]);
      alias(0, point(0), operation === 3n ? "binding_lifecycle.replay.refusal_uniqueness" : "binding_lifecycle.replay.proposal_terminal_transition_key", hash(["uint256", "uint64"], [q.collectionId, binding.generation]), e.value);
    }
    e.after_[4].stateRoot = hash(["bytes32", "uint256", "address", "address", "address", "address", "bytes32", "uint64", "uint64", "bytes32", "bytes32", "bytes32", "bytes32", "bytes32"],
      [id("6529STREAM_ARTIST_OWNER_STATE_TRANSITION_V2"), chainId, origin.registry, origin.coordinator, origin.archive, origin.owners[4], e.before_[4].domainId, e.before_[4].revision, e.after_[4].revision,
        e.before_[4].stateRoot, hash(["uint16", "address", "bytes32"], [operation, e.actor, action]), state, Z, hash(["bytes32"], [Z])]);
    e.after_[4].recordChainTip = e.before_[4].recordChainTip; clock[4] = clone(e.after_[4]);
    const raw = coder.encode(T.envelope.components, T.envelope.components.map(c => e[c.name])), pointer = A(9400 + envelopes.length), payloadHash = keccak256(raw);
    const evidenceId = hash(["bytes32", "uint256", "address", "address", "uint16", "address", "bytes32"], [id("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"), chainId, origin.registry, origin.coordinator, operation, e.actor, e.value]);
    const evidence = { catalogueIndex: BigInt(envelopes.length), pointer, payloadHash, evidenceId }, kind = id("ARTIST_OPERATION_EVIDENCE");
    operations.push({ originHash: oh, operation, evidence }); archiveRows.push({ ...evidence, kind, hash: payloadHash, raw, collectionId: q.collectionId, operation, atBlock: 1n });
    args.codes?.set(pointer, `0x00${raw.slice(2)}`); envelopes.push(raw); envelopeFacts.push(e);
  }
  function attest(k, g) {
    const q = collections[k], binding = bindings[k].bindings.rows[g].item, identity = identities.find(i => i.artistId === q.artistId), n = attribution.reduce((n,a) => n + a.records.records.length, 0), saved = zero(child(T.attestation, "records").arrayChildren), r = saved.attestation, t = r.input.terms;
    Object.assign(t, { collectionId: q.collectionId, subjectKind: 10n, subjectId: q.artistId, subjectStateHash: H(7900 + ids.indexOf(q.artistId)), schemaId: id("6529STREAM_ARTIST_C2PA_CREDENTIALS_V1"), statementURI: "urn:original-generation-credential" });
    r.input.nonce = used.get(q.artistId); used.set(q.artistId, r.input.nonce + 1n);
    Object.assign(r.record, { signer: identity.identity.authorityAddress, signedAt: BigInt(3 + g), generation: binding.generation }); r.authorityClass = identity.identity.authorityClass;
    Object.assign(r.association, { artistId: q.artistId, bindingHash: binding.bindingHash, generation: binding.generation });
    Object.assign(r.association.fact, { owner: origin.owners[2], ownerCodeHash: origin.ownerCodeHashes[2], subjectId: t.subjectId, stateHash: t.subjectStateHash });
    r.statement = coder.encode([T.credential], [{ schemaVersion: 1n, artistId: q.artistId, identityRecordHash: t.subjectStateHash, previousRecordHash: credentialHeads.get(q.artistId).recordHash, credentials: [] }]);
    t.statementHash = keccak256(r.statement); Object.assign(r.record, { statementHash: t.statementHash, schemaId: t.schemaId, subjectStateHash: t.subjectStateHash });
    r.record.recordHash = attestationRecord(origin, q.artistId, r); advance(2); const ip = point(2), digest = attestationDigest(origin, r);
    alias(2, ip, "identity_authority.replay.nonce_allocator", hash(["bytes32", "uint256"], [q.artistId, r.input.nonce]), digest);
    alias(2, ip, "identity_authority.replay.attestation_key", hash(["bytes32"], [r.record.recordHash]), r.record.recordHash);
    alias(2, ip, "identity_authority.replay.authorization_consumed_digest", hash(["bytes32", "bytes32"], [q.artistId, digest]), digest);
    identity.signatures.push({ recordHash: r.record.recordHash, signature: "0x" }); identity.nonces[0].words[0].words[0] |= 1n << r.input.nonce;
    advance(4); row(4, 24n, q.artistId, q.collectionId, r.record.recordHash); attribution[k].records.records.push(saved);
    const prior = credentialHeads.get(q.artistId), head = { revision: prior.revision + 1n, recordHash: r.record.recordHash, previousRecordHash: prior.recordHash, artistId: q.artistId, collectionId: q.collectionId,
      bindingHash: binding.bindingHash, generation: binding.generation, identityRecordHash: t.subjectStateHash, statementHash: t.statementHash, sourceRegistry: origin.registry };
    credentialHeads.set(q.artistId, head); credentialRecords.set(r.record.recordHash, head);
  }
  function consent(k, g) {
    if (!consents) return;
    const q = collections[k], binding = bindings[k].bindings.rows[g].item, b = contents[k].rows, identity = identities.find(i => i.artistId === q.artistId), grant = delegated ? identity.delegations[0].recordHash : Z;
    const rows = [], generation = BigInt(g + 1), base = 50000 + k * 100 + g * 10;
    if (!b.original.policies.length) {
      const key = { phaseId: H(4100 + k), policyHash: H(4200 + k) }; q.policies.push(key); b.original.keys.push(clone(key));
      b.original.policies.push({ recordHash: H(base), grant }); rows.push({ op: 14n, record: H(base), surface: "policy_consent_key", scope: hash(["uint256", "bytes32", "bytes32"], [q.collectionId, key.phaseId, key.policyHash]) });
      if (delegated) delegateUsed.set(q.artistId, delegateUsed.get(q.artistId) + 1n);
    }
    const e = zero(child(T.original, "economics").arrayChildren);
    Object.assign(e.item.terms, { collectionId: q.collectionId, resolver: source.primaryResolver, revenueClass: H(5100), scope: 1n, scopeId: q.collectionId, assignmentHash: H(5200 + k) });
    e.item.recordHash = H(base + 1); e.grant = grant;
    const termsType = child(child(child(T.original, "economics").arrayChildren, "item"), "terms"), payloadHash = hash([termsType], [e.item.terms]);
    Object.assign(e.item.association, { artistId: q.artistId, bindingGeneration: generation, bindingHash: binding.bindingHash, payloadHash, originalRecord: b.original.economics[0]?.item.recordHash ?? e.item.recordHash });
    const escope = b.original.economics.length ? hash(["bytes32", "bytes32", termsType, "bytes32", "uint64", "bytes32"], [id("6529STREAM_ARTIST_ECONOMICS_BINDING_CONTINUATION_V1"), e.item.association.originalRecord, e.item.terms, q.artistId, generation, binding.bindingHash]) : payloadHash;
    b.original.economics.push(e); rows.push({ op: 15n, record: e.item.recordHash, surface: "consent_key", scope: escope }); if (delegated) delegateUsed.set(q.artistId, delegateUsed.get(q.artistId) + 1n);
    const sale = zero(child(T.original, "sales").arrayChildren);
    Object.assign(sale.item.terms, { collectionId: q.collectionId, saleAdapter: A(710), saleId: H(5400 + k), saleConfigHash: H(5500 + k) });
    Object.assign(sale.item, { artistId: q.artistId, signer: delegated ? A(700) : identity.identity.authorityAddress, authorityClass: delegated ? 2n : identity.identity.authorityClass,
      nonce: delegated ? delegateUsed.get(q.artistId) : BigInt(50 + k * 2 + g), signedAt: BigInt(3 + g), bindingGeneration: generation, bindingHash: binding.bindingHash });
    sale.item.recordHash = saleRecord(origin, sale.item); sale.current = sale.item.recordHash; sale.grant = grant; b.original.sales.push(sale);
    for (const s of b.original.sales) s.current = sale.item.recordHash;
    rows.push({ op: 16n, record: sale.item.recordHash, surface: "sale_consent_key", scope: hash([child(child(child(T.original, "sales").arrayChildren, "item"), "terms"), "uint64", "bytes32"], [sale.item.terms, generation, binding.bindingHash]) });
    if (delegated) { advance(2); alias(2, point(2), "identity_authority.replay.delegated_nonce", hash(["bytes32", "uint256"], [delegateLane(q.artistId, A(700)), sale.item.nonce]), H(base + 8)); delegateUsed.set(q.artistId, delegateUsed.get(q.artistId) + 1n); }
    const c = { recordHash: H(base + 3), artistId: q.artistId, bindingGeneration: generation, terms: { collectionId: q.collectionId, metadataContract: source.metadata, familyId: H(5700 + k), newStateHash: H(5800 + k) }, authorityClass: identity.identity.authorityClass };
    b.consents.push(c); rows.push({ op: 17n, record: c.recordHash, surface: "content_consent_key", scope: hash(["bytes32", "bytes32"], [hash([child(child(T.content, "consents").arrayChildren, "terms"), "uint64"], [c.terms, generation]), c.recordHash]) });
    if (royalties) {
      const r = { terms: { resolver: source.royaltyResolver, collectionId: q.collectionId, revenueClass: id("ROYALTY_ERC2981"), expectedAssignmentHash: H(5900 + k) }, item: { recordHash: H(base + 4), artistId: q.artistId, bindingGeneration: generation }, grant };
      b.royalties.push(r); rows.push({ op: 20n, record: r.item.recordHash, surface: "freeze_key", scope: hash([child(child(T.content, "royalties").arrayChildren, "terms"), "bytes32", "uint64"], [r.terms, q.artistId, generation]) }); if (delegated) delegateUsed.set(q.artistId, delegateUsed.get(q.artistId) + 1n);
    }
    const f = { recordHash: H(base + 5), artistId: q.artistId, bindingGeneration: generation, metadataContract: source.metadata, lockClasses: [H(1), H(2)], expectedStateHash: H(6200 + k), authorityClass: identity.identity.authorityClass };
    b.freezes.push(f); rows.push({ op: 21n, record: f.recordHash, surface: "freeze_key", scope: hash(["bytes32", "uint256", "uint64", "bytes32"], [id("CONTENT"), q.collectionId, generation, f.recordHash]) });
    for (const r of rows) { advance(6); row(6, r.op, q.artistId, q.collectionId, r.record); alias(6, point(6), `consent_finality.replay.${r.surface}`, r.scope, r.record); identity.signatures.push({ recordHash: r.record, signature: "0x" }); }
  }
  function openDispute(k) {
    const q = collections[k], b = bindings[k].bindings.rows[0].item, r = zero(child(T.history, "revocations").arrayChildren), a = r.opening, d = r.resolution;
    Object.assign(a.terms, { collectionId: q.collectionId, bindingGeneration: 1n, disputeAction: 1n, evidenceHash: H(2500 + k), reasonHash: H(2600 + k) });
    Object.assign(a, { signer: A(71), recordedAt: 3n, artistId: q.artistId, bindingHash: b.bindingHash, governanceActionId: H(2700 + k) });
    a.recordHash = hash(["bytes32", "uint256", "address", "uint256", "uint64", "uint8", "address", "uint8", "bytes32", "bytes32", "uint256", "uint64"],
      [id("6529STREAM_ARTIST_DISPUTE_RECORD_V1"), chainId, origin.registry, q.collectionId, 1n, 1n, a.signer, 0n, a.terms.evidenceHash, a.terms.reasonHash, 0n, a.recordedAt]); a.disputeRecordHash = a.recordHash;
    advance(4); row(4, 44n, q.artistId, q.collectionId, a.recordHash);
    alias(4, point(4), "attribution_lifecycle.replay.dispute_key", hash(["uint256", "uint64", "bytes32", "address", "bytes32", "bytes32"], [q.collectionId, 1n, Z, a.signer, a.terms.evidenceHash, a.terms.reasonHash]), a.recordHash);
    alias(4, point(4), "attribution_lifecycle.replay.governance_action", a.governanceActionId, a.recordHash);
    attribution[k].history.revocations.push(r);
  }
  function resolveDispute(k) {
    const q = collections[k], r = attribution[k].history.revocations[0], a = r.opening, d = r.resolution;
    Object.assign(d.terms, { collectionId: q.collectionId, bindingGeneration: 1n, disputeRecordHash: a.recordHash, resolution: 2n, evidenceHash: H(2800 + k), reasonHash: H(2900 + k) });
    Object.assign(d, { actionId: H(3000 + k), actor: A(71), proposer: A(70), actionClass: 2n, restoredState: 5n, resolvedAt: 4n, witnessHash: H(3100 + k) });
    Object.assign(r.head, { disputeRecordHash: a.recordHash, resolutionActionId: d.actionId, restoreState: 2n, revocationReason: 4n });
    advance(4); alias(4, point(4), "attribution_lifecycle.replay.dispute_resolution_key", a.recordHash, d.actionId); alias(4, point(4), "attribution_lifecycle.replay.governance_action", d.actionId, a.recordHash);
  }
  // Proposals for all collections precede completions. Governed openings and
  // resolutions are separated by other collections' owner4 writes.
  for (let g = 0; g < 2; g++) {
    for (let k = 0; k < collections.length; k++) publication(k, g, 1n);
    for (let k = 0; k < collections.length; k++) {
      publication(k, g, bindings[k].bindings.rows[g].item.accepted ? 2n : k % 2 ? 4n : 3n);
      if (bindings[k].bindings.rows[g].item.accepted) consent(k, g);
      if (bindings[k].bindings.rows[g].item.accepted && attestations) attest(k, g);
    }
    if (g === 0 && acceptedHistory) {
      for (let k = 0; k < collections.length; k++) openDispute(k);
      for (let k = collections.length - 1; k >= 0; k--) resolveDispute(k);
    }
  }
  const nonces = identities.toReversed().flatMap(b => b.nonces.map(n => ({ index: { kind: n.kind, key: n.key, prefixCount: BigInt(n.words.length) }, words: clone(n.words) })));
  const checkpoints = seven(i => ({ schema: m.ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_CHECKPOINT_SCHEMA, ownerState: clone(clock[i]), replayRoot: aliases[i].length ? H(240 + i) : Z,
    replayCount: BigInt(aliases[i].length), nonceRoot: i === 2 ? H(280) : Z, nonceIndexCount: i === 2 ? BigInt(nonces.length) : 0n }));
  const provenance = { origins: [origin], eras: [{ originHash: oh, priorImportCommitment: Z, checkpoints, nativeCounts: journals.map(a => BigInt(a.length)), lowerRevisions: seven(() => 0n) }], journals, aliases };
  const payouts = artists.map(q => Object.assign(zero(T.payout), { artistId: q.artistId, sourceSnapshot: clone(checkpoints[5].ownerState) }));
  const catalogue = { originHash: oh, archiveCodeHash: keccak256(args.codes?.get(origin.archive) ?? "0x6001"), configurationHash: config,
    count: BigInt(envelopes.length), rowsHash: Z, lower: seven(() => 0n), upper: checkpoints.map(c => c.ownerState.revision) };
  catalogue.rowsHash = hash(["bytes32", "bytes32", "address", "bytes32", "bytes32", "uint256"], [id("6529STREAM_ARTIST_RECOVERED_PLATFORM_CATALOGUE_V1"), oh, origin.archive, catalogue.archiveCodeHash, config, catalogue.count]);
  for (const row of archiveRows) catalogue.rowsHash = hash(["bytes32", "uint256", "address", "bytes32", "bytes32"], [catalogue.rowsHash, row.catalogueIndex, row.pointer, row.kind, row.hash]);
  const clocks = { catalogues: [catalogue], operations, bindings, generations };
  const features = 2097152n | 512n | classes.slice(0, ids.length).reduce((n,c) => n | (c === 1n ? 1n : 2n), 0n)
    | (acceptedHistory ? 2048n | 4096n | 8192n : 0n) | (attestations ? 128n | 131072n : 0n) | (consents ? 32n | 64n | 256n | 32768n : delegated ? 64n : 0n);
  const f = { options, source, origin, before: args.before ?? seven(i => ({ domainId: m.artistRecoveredMultipleGenerationHydrationOwnerDomain(i), revision: i === 2 ? BigInt(1 + ids.length + collections.length) : 0n, stateRoot: H(300 + i), recordChainTip: H(320 + i) })),
    artists, collections, bindings, acceptances, attribution, attestations: attribution.map(a => a.records), identities, payouts, contents, provenance, nonces, timing, features,
    clocks, clockFacts: { envelopes, bindings, acceptances }, archiveRows, envelopes: envelopeFacts, credentialHeads, credentialRecords, states: [], payloads: [], codes: args.codes,
    coords: { chainId, registry: A(101), coordinator: A(102) } };
  refresh(f); return f;
}
/** Rebuild commitments after deliberate mutations, without fixing the mutated facts. */
export function refresh(f) {
  const { provenance: p, artists, collections, identities, payouts, contents, attestations, attribution, acceptances, origin, bindings } = f;
  const oh = p.eras[0].originHash, cp = p.eras.at(-1).checkpoints;
  for (const owner of [0, 2, 3, 4, 6]) p.aliases[owner].sort((a, b) => BigInt(a.originalKey) < BigInt(b.originalKey) ? -1 : 1);
  for (const a of artists) a.records = p.journals.flat().filter(j => j.receipt.artistId === a.artistId).map(j => j.receipt.recordHash);
  for (const q of collections) q.records = p.journals.flat().filter(j => j.receipt.collectionId === q.collectionId).map(j => j.receipt.recordHash);
  const logical = p.aliases.map(rows => rows.map(({ surface, scope }) => ({ surface, scope })));
  const data = seven(owner => {
    const local = m.artistRecoveredMultipleGenerationHydrationOwnerProvenance(p, owner), commitment = m.artistRecoveredMultipleGenerationHydrationOwnerProvenanceHash(local, owner);
    let rows = [];
    if (owner === 0) rows = bindings.map(b => { b.bindings.provenanceCommitment = commitment; return coder.encode([T.bindingBundle], [b]); });
    if (owner === 2) rows = identities.map(b => { b.sourceSnapshot = clone(cp[2].ownerState); return coder.encode([T.identity], [b]); });
    if (owner === 3) rows = acceptances.map(b => { b.provenance = commitment; return coder.encode([T.acceptanceBundle], [b]); });
    if (owner === 4) rows = attribution.map(b => { b.history.provenance = commitment; b.records.provenance = commitment; return coder.encode([T.gAttribution], [b]); });
    if (owner === 5) rows = payouts.map(b => coder.encode(["bytes32", T.payout], [id("6529STREAM_ARTIST_RECOVERED_PAYOUT_HYDRATION_V1"), b]));
    if (owner === 6) rows = contents.map(b => { b.rows.original.provenance = commitment; return coder.encode([T.consents], [b]); });
    const s = { artists: clone(artists), collections: clone(collections), rows };
    if (owner === 4) for (const q of s.collections) q.records = p.journals[4].filter(j => j.receipt.collectionId === q.collectionId && j.receipt.operation === 24n).map(j => j.receipt.recordHash);
    f.states[owner] = s;
    const publications = f.codes && [2, 4, 6].includes(owner) ? [{ pointer: A(90 + owner), payloadType: H(800 + owner), payloadHash: keccak256("0x1234") }] : [];
    if (publications.length) f.codes.set(publications[0].pointer, "0x001234");
    const payload = { provenance: local, nonces: owner === 2 ? clone(f.nonces) : [], publications,
      semanticState: coder.encode(["bytes32", "uint16", "uint8", T.state, "bytes"], [id("6529STREAM_ARTIST_RECOVERED_MULTIPLE_GENERATIONS_V1"), 1n, BigInt(owner), s, owner === 0 || owner === 4 ? coder.encode([T.clocks], [f.clocks]) : owner === 3 ? coder.encode([`${T.generation.format("full")}[][]`], [f.clocks.generations]) : "0x"]) };
    f.payloads[owner] = payload;
    const keys = logical[owner].map(v => m.artistRecoveredMultipleGenerationHydrationReplayKey(origin, owner, v));
    return { typedState: m.encodeArtistRecoveredMultipleGenerationHydrationOwnerPayload(payload, owner, f.features), origins: logical[owner], sourceKeys: keys, cells: keys.map(key => p.aliases[owner].find(a => a.originalKey === key).cell), nonces: [] };
  });
  const query = { ...clone(collections[0]), records: clone(artists.find(a => a.artistId === collections[0].artistId).records) };
  f.prepared = f.certificate = { admission: { prior: origin.registry, sourceCoordinator: origin.coordinator, source: f.source, provenance: p, artists, collections, before_: f.before }, query, data, timing: f.timing,
    externalGuards: { schema: id("6529STREAM_ARTIST_RECOVERED_EXTERNAL_GUARDS_V1"), provenanceCommitment: m.artistRecoveredMultipleGenerationHydrationProvenanceHash(p), artistId: artists[0].artistId, actions: [], finality: [], entropy: [] } };
  f.request = { records: { authority: { bindingIndex: 0n, artistIds: artists.map(a => a.artistId), collections: collections.map(q => ({ artistId: q.artistId, collectionId: q.collectionId, policies: clone(q.policies) })), expectedSource: cp, replayOrigins: logical },
    witnesses: collections.map((q, i) => ({ collectionId: q.collectionId, economics: contents[i].rows.original.economics.map(e => clone(e.item.terms)), attestations: attestations[i].records.map(r => clone(r.attestation.input)) })).filter(w => w.economics.length || w.attestations.length) },
    expectedCapabilities: seven(i => ({ profile: m.ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_PROFILE, version: 1n, ownerIndex: BigInt(i), ownerDomain: m.artistRecoveredMultipleGenerationHydrationOwnerDomain(i),
      checkpointSchema: m.ARTIST_RECOVERED_MULTIPLE_GENERATION_HYDRATION_CHECKPOINT_SCHEMA, stateSchema: m.artistRecoveredMultipleGenerationHydrationOwnerTag(i), supportedFeatures: 4194303n })), expectedSourceImportCommitment: Z, expectedSemanticInventory: Z };
  // Original semanticInventory is a supplied-facts preimage, independent of full admission.
  const q = f.prepared;
  f.request.expectedSemanticInventory = hash(["bytes32", "uint16", "bytes32", child(T.prepared, "query"), child(T.prepared, "data"), child(T.prepared, "timing"), child(T.prepared, "externalGuards")],
    [id("6529STREAM_ARTIST_RECOVERED_SEMANTIC_INVENTORY_V1"), 1n, m.artistRecoveredMultipleGenerationHydrationProvenanceHash(p), q.query, q.data, q.timing, q.externalGuards]);
  f.input = { request: f.request, royaltyFreezes: p.journals[6].filter(j => j.receipt.operation === 20n).map(j => clone(contents.flatMap(b => b.rows.royalties).find(r => r.item.recordHash === j.receipt.recordHash).terms)) };
  return f;
}
