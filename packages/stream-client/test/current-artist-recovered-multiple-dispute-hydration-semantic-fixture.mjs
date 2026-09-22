// Compiler-shaped supplied facts only. Private Identity/Payout lifecycle admission,
// runtime provenance, signature validity and actual Registry execution are mocked.
import { AbiCoder, ParamType, ZeroAddress, ZeroHash, getAddress, id, keccak256, toUtf8Bytes, hexlify } from "ethers";
import * as originalAttribution from "../dist/current-artist-attribution.js";
import * as m from "../dist/current-artist-recovered-multiple-dispute-hydration.js";
import { ARTIST_HYDRATION_SUITE_TUPLE } from "../dist/current-artist-authority-hydration.js";
import { fixture, compiledLibraryValueInterface, libraryValueABI, multipleDisputeTuple } from "./current-artist-recovered-multiple-dispute-hydration-source-fixture.mjs";
export { m, fixture };
export const coder = AbiCoder.defaultAbiCoder(), Z = ZeroHash;
export const A = n => getAddress(`0x${BigInt(n).toString(16).padStart(40, "0")}`);
export const H = n => `0x${BigInt(n).toString(16).padStart(64, "0")}`;
export const hash = (types, values) => keccak256(coder.encode(types, values));
export const seven = fn => Array.from({ length: 7 }, (_, i) => fn(i));
export const child = (t, name) => t.components.find(c => c.name === name);
const clone = structuredClone, cached = new Map();
export function findType(name) { return multipleDisputeTuple(name); }
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
T.history = findType("StreamArtistRecoveredDisputeHistoryTypes.Bundle");
T.head = child(T.history, "heads").arrayChildren;
T.disputeRow = child(T.history, "disputes").arrayChildren;
T.resolutionRow = child(T.history, "resolutions").arrayChildren;
T.repudiationRow = child(T.history, "repudiations").arrayChildren;
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
  const { history = "withdrawal", attestations = false, collectionCount = 3, oneArtist = false, classes = [1n, 3n], delegated = true, royalties = true, consents = true, oneGeneration = false, repeated = false } = options;
  if (repeated && history !== "withdrawal") throw Error("Repeated fixture supports the original withdrawal chain only");
  const acceptedHistory = history === "executed", pendingRevoked = history === "pending-revoked", generationCount = oneGeneration ? 1 : 2;
  const ids = oneArtist ? [H(1000)] : [H(1000), H(1001)];
  const source = args.source ?? { registry: A(1), archive: A(3), owners: seven(i => A(10 + i)), core: A(4), mintManager: A(5),
    roleRegistry: A(6), metadata: A(7), primaryResolver: A(8), royaltyResolver: A(9), primaryRevenueClass: H(8), validator: A(17) };
  const chainId = args.origin?.chainId ?? (1n << 200n) + 11n;
  const finalOrigin = args.origin ?? { chainId, registry: source.registry, coordinator: A(2), archive: source.archive, owners: source.owners,
    ownerCodeHashes: seven(i => H(100 + i)), core: source.core, manager: source.mintManager, suiteConfigurationHash: hash([ARTIST_HYDRATION_SUITE_TUPLE], [source]) };
  const originalSuite = {...source, registry:A(4100), archive:A(4102), owners:seven(i=>A(4110+i))};
  let origin = repeated ? {...finalOrigin, registry:originalSuite.registry, coordinator:A(4101), archive:originalSuite.archive, owners:originalSuite.owners, suiteConfigurationHash:hash([ARTIST_HYDRATION_SUITE_TUPLE],[originalSuite])} : finalOrigin;
  let oh = m.artistRecoveredMultipleDisputeHydrationOriginHash(origin);
  const origins=[clone(origin)], eras=[], catalogues=[];
  let eraStart=seven(()=>0), archiveStart=0, lower=seven(()=>0n);
  if(args.codes) for(const o of [origin,finalOrigin]) {
    for(let i=0;i<7;i++)if(!args.codes.has(o.owners[i]))args.codes.set(o.owners[i],args.codes.get(finalOrigin.owners[i])??"0x60006000");
    for(const key of ["registry","coordinator","archive"])if(!args.codes.has(o[key]))args.codes.set(o[key],args.codes.get(finalOrigin[key])??"0x60016000");
  }
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
  const clock = seven(i => ({ domainId: m.artistRecoveredMultipleDisputeHydrationOwnerDomain(i), revision: i === 2 ? 20n : 0n, stateRoot: H(9000 + i), recordChainTip: H(9100 + i) }));
  for (const [domain, field] of [["STATE", "stateRoot"], ["RECORD", "recordChainTip"]]) clock[1][field] = hash(["bytes32", "uint256", "address", "address", "address", "address", "bytes32"],
    [id(`6529STREAM_ARTIST_OWNER_${domain}_GENESIS_V2`), chainId, origin.registry, origin.coordinator, origin.archive, origin.owners[1], clock[1].domainId]);
  const point = owner => ({ environmentHash: oh, ownerIndex: BigInt(owner), ownerRevision: clock[owner].revision });
  const row = (owner, operation, artistId, collectionId, recordHash, p = point(owner)) => {
    const j = { position: { point: clone(p), nativeIndex: BigInt(journals[owner].length-eraStart[owner]) }, receipt: { operation, artistId, collectionId, recordHash } };
    journals[owner].push(j); return j;
  };
  const alias = (owner, p, surface, scope, commitment) => {
    const entry = { surface: id(surface), scope };
    aliases[owner].push({ originHash: oh, ownerIndex: BigInt(owner), ...entry, originalKey: m.artistRecoveredMultipleDisputeHydrationReplayKey(origin, owner, entry),
      cell: { commitment, touchedRevision: p.ownerRevision, kind: 1n, status: 2n }, admittedAt: clone(p) });
  };
  ids.forEach((artist, i) => {
    row(2, 1n, artist, 0n, artist, { environmentHash: oh, ownerIndex: 2n, ownerRevision: BigInt(3 * i + 1) });
    for (const n of [1500, 1600]) row(2, 35n, artist, 0n, H(n + i), { environmentHash: oh, ownerIndex: 2n, ownerRevision: BigInt(3 * i + 2) });
  });
  if (delegated && consents) for (const identity of identities) {
    const i = ids.indexOf(identity.artistId), g = zero(child(T.identity, "delegations").arrayChildren);
    const count = BigInt(collections.filter(q => q.artistId === identity.artistId).length * (1 + (acceptedHistory ? 2 : 1) * (royalties ? 3 : 2)));
    Object.assign(g.record.grant, { artistId: identity.artistId, delegate: A(700), capabilities: 1143n, notBefore: 1n, expiresAt: 100n, maxUses: 128n });
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
    for (let g = 0; g < generationCount; g++) {
      const r = zero(rtype), document = hexlify(toUtf8Bytes(`generation identity ${k}/${g}`)), dh = keccak256(document);
      const d = zero(child(T.identity, "documents").arrayChildren); Object.assign(d, { documentHash: dh, document }); identities.find(i => i.artistId === q.artistId).documents.push(d);
      Object.assign(r.item, { artistId: q.artistId, artistAddress: A(50 + k), identityRecordHash: dh, generation: BigInt(g + 1), consentMode: delegated ? 2n : 1n, proposer: A(70), accepted: g === generationCount - 1 || acceptedHistory });
      r.terms.collaboratorSetHash = emptyHash("6529STREAM_ARTIST_COLLABORATOR_SET_V1"); r.terms.capabilityPolicySetHash = emptyHash("6529STREAM_ARTIST_CAPABILITY_POLICY_SET_V1");
      r.item.bindingHash = hash(["bytes32", "uint256", "address", "address", "uint256", "uint64", "bytes32", "address", "bytes32", "uint8", "uint8", "uint8", "bytes32", "bytes32"],
        [id("6529STREAM_ARTIST_BINDING_V1"), chainId, origin.registry, origin.core, q.collectionId, r.item.generation, q.artistId, r.item.artistAddress, dh, r.item.consentMode, 0n, 0n, r.terms.collaboratorSetHash, r.terms.capabilityPolicySetHash]);
      if (!r.item.accepted && !pendingRevoked) Object.assign(r.terminal, { kind: k % 2 ? 2n : 1n, reasonHash: H(1800 + k), recordHash: k % 2 ? Z : H(1900 + k) });
      b.bindings.rows.push(r); b.corrections.push(zero(child(T.bindingBundle, "corrections").arrayChildren));
    }
    q.bindingHash = b.bindings.rows[generationCount - 1].item.bindingHash; b.bindings.bindingHash = q.bindingHash; b.bindings.current = clone(b.bindings.rows[generationCount - 1].item); return b;
  });
  const acceptances = collections.map(q => Object.assign(zero(T.acceptanceBundle), { artistId: q.artistId, collectionId: q.collectionId, bindingHash: q.bindingHash }));
  const attribution = collections.map(q => {
    const b = zero(T.gAttribution);
    Object.assign(b.history, { artistId: q.artistId, collectionId: q.collectionId, bindingHash: q.bindingHash, current: { state: 2n, generation: BigInt(generationCount) } });
    Object.assign(b.records, { artistId: q.artistId, collectionId: q.collectionId, bindingHash: q.bindingHash, item: { state: 2n, generation: BigInt(generationCount) } }); b.history.heads = Array.from({length:generationCount}, () => zero(T.head)); return b;
  });
  const contents = collections.map((q, k) => {
    const c = zero(T.consents); Object.assign(c.rows.original, { artistId: q.artistId, collectionId: q.collectionId, bindingHash: q.bindingHash });
    c.bindings = bindings[k].bindings.rows.map(r => clone(r.item)); return c;
  });
  const generations = collections.map(() => []), envelopes = [], archiveRows = [], operations = [], envelopeFacts = [];
  const credentialHeads = new Map(ids.map(a => [a, zero(T.credentialHead)])), credentialRecords = new Map();
  const used = new Map(ids.map(a => [a, 1n])), delegateUsed = new Map(ids.map(a => [a, 0n]));
  let config = H(8900);
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
      if (g && (acceptedHistory || pendingRevoked)) {
        const c = bindings[k].corrections[g], a = c.approval, previous = bindings[k].bindings.rows[g - 1], h = attribution[k].history;
        a.previous = clone(previous.item);
        if (history === "executed") {
          const r = h.repudiations.find(r => r.record.terms.bindingGeneration === BigInt(g) && r.terminal.phase === 4n);
          a.cause = 3n; a.causeRecord = r.record.recordHash;
          a.causeData = coder.encode([child(T.binding,"terminal"),T.head,child(T.repudiationRow,"record"),child(T.repudiationRow,"terminal")], [previous.terminal,h.heads[g-1],r.record,r.terminal]);
        } else {
          const r = h.disputes.find(r => r.record.terms.bindingGeneration === BigInt(g)), d = h.resolutions.find(r => r.record.terms.bindingGeneration === BigInt(g));
          a.cause = 4n; a.causeRecord = d.record.actionId;
          a.causeData = coder.encode([child(T.binding,"terminal"),T.head,child(T.disputeRow,"record"),child(T.resolutionRow,"record")], [previous.terminal,h.heads[g-1],r.record,d.record]);
        }
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
    const evidence = { catalogueIndex: BigInt(envelopes.length-archiveStart), pointer, payloadHash, evidenceId }, kind = id("ARTIST_OPERATION_EVIDENCE");
    operations.push({ originHash: oh, operation, evidence }); archiveRows.push({ ...evidence, originHash: oh, kind, hash: payloadHash, raw, collectionId: q.collectionId, operation, atBlock: 1n });
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
  // Dispute constructors appended below before the complete global checkpoints.

  let serial = 0;
  const principalUsed = new Map(ids.map(a=>[a,128n]));
  let at = {chainId,registry:origin.registry,core:origin.core};
  function saveArchive(e,k) {
    const raw=coder.encode(T.envelope.components,T.envelope.components.map(c=>e[c.name])),pointer=A(9400+envelopes.length),payloadHash=keccak256(raw);
    const evidenceId=hash(["bytes32","uint256","address","address","uint16","address","bytes32"],[id("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"),chainId,origin.registry,origin.coordinator,e.operation,e.actor,e.value]);
    const evidence={catalogueIndex:BigInt(envelopes.length-archiveStart),pointer,payloadHash,evidenceId},kind=id("ARTIST_OPERATION_EVIDENCE");
    operations.push({originHash:oh,operation:e.operation,evidence});archiveRows.push({...evidence,originHash:oh,kind,hash:payloadHash,raw,collectionId:collections[k].collectionId,operation:e.operation,atBlock:1n});
    args.codes?.set(pointer,`0x00${raw.slice(2)}`);envelopes.push(raw);envelopeFacts.push(e);
  }
  function envelope(op,actor,value,identityWrite) {
    const e=zero(T.envelope);Object.assign(e,{version:1n,configurationHash:config,operation:op,actor,value});
    const slots=op===45n||op===47n?[0,1,2,4]:op===46n?[0,4]:op===48n||op===49n?[2,4]:[0,2,4];
    for(const i of slots) { e.before_[i]=clone(clock[i]);if(i===4||i===2&&identityWrite)advance(i);e.after_[i]=clone(clock[i]); }
    return e;
  }
  function authorize(identity,record,nonce,digest,delegate=false) {
    const laneKey=delegate?delegateLane(identity.artistId,A(700)):identity.artistId,kind=delegate?2n:1n;
    alias(2,point(2),delegate?"identity_authority.replay.delegated_nonce":"identity_authority.replay.nonce_allocator",hash(["bytes32","uint256"],[laneKey,nonce]),digest);
    alias(2,point(2),"identity_authority.replay.authorization_consumed_digest",hash(["bytes32","bytes32"],[identity.artistId,digest]),digest);
    const lane=identity.nonces.find(n=>n.kind===kind&&n.key===laneKey),prefix=nonce>>8n;
    let word=lane.words.find(w=>w.prefix===prefix);if(!word){word={prefix,words:Array(32).fill(0n),exhausted:false};lane.words.push(word);}
    word.words[0]|=1n<<(nonce&255n);identity.signatures.push({recordHash:record,signature:"0x0102"});
  }
  function dispute(k,g,action,governed) {
    const q=collections[k],binding=bindings[k].bindings.rows[g].item,b=attribution[k].history,head=b.heads[g],identity=identities.find(a=>a.artistId===q.artistId),saved=zero(T.disputeRow),r=saved.record;
    const isDelegate=!governed&&delegated&&consents,nonce=governed?0n:isDelegate?delegateUsed.get(q.artistId):principalUsed.get(q.artistId);
    if(!governed){if(isDelegate)delegateUsed.set(q.artistId,nonce+1n);else principalUsed.set(q.artistId,nonce+1n);}
    const opening=b.disputes.filter(d=>d.record.terms.bindingGeneration===BigInt(g+1)&&d.record.terms.disputeAction===1n).at(-1),beforeHead=clone(head),n=serial++;
    Object.assign(r.terms,{collectionId:q.collectionId,bindingGeneration:BigInt(g+1),disputeAction:action,evidenceHash:H(100000+n),reasonHash:H(110000+n)});
    Object.assign(r,{artistId:q.artistId,bindingHash:binding.bindingHash,signer:governed?A(71):isDelegate?A(700):identity.identity.authorityAddress,authorityClass:governed?0n:isDelegate?2n:identity.identity.authorityClass,nonce,recordedAt:30n+BigInt(n),governanceActionId:governed?H(120000+n):Z});
    if(!governed)Object.assign(r.standing,{artistId:q.artistId,bindingGeneration:BigInt(g+1),delegation:isDelegate?identity.delegations[0].recordHash:Z});
    r.recordHash=originalAttribution.artistAttributionDisputeRecordHash(at,r);
    r.disputeRecordHash=action===1n?r.recordHash:opening.record.recordHash;r.previousRecordHash=action===1n?(opening?.record.recordHash??Z):action===3n?head.counterStatementRecordHash:head.counterStatementRecordHash===Z?r.disputeRecordHash:head.counterStatementRecordHash;
    const op=action===1n?44n:action===2n?61n:45n,e=envelope(op,r.signer,r.recordHash,!governed);saved.point=point(4);
    const auth={nonce,time:1000n,signature:governed?"0x":"0x0102"},digest=governed?Z:originalAttribution.artistAttributionSigningPayload(at,r.terms,auth).digest;
    if(!governed)authorize(identity,r.recordHash,nonce,digest,isDelegate);
    row(4,op,q.artistId,q.collectionId,r.recordHash);
    alias(4,point(4),`attribution_lifecycle.replay.${action===1n?"dispute_key":action===2n?"dispute_withdrawal_key":"counter_statement_key"}`,action===2n?r.disputeRecordHash:hash(["uint256","uint64","bytes32","address","bytes32","bytes32"],[q.collectionId,BigInt(g+1),action===1n?Z:r.disputeRecordHash,r.signer,r.terms.evidenceHash,r.terms.reasonHash]),r.recordHash);
    if(governed)alias(4,point(4),"attribution_lifecycle.replay.governance_action",r.governanceActionId,r.recordHash);
    const detail={operationId:op,p:clone(r.terms),standing:clone(r.standing),a:auth,admission:{binding_:clone(binding),standing:clone(r.standing),signer:r.signer,authorityClass:r.authorityClass,recordedAt:r.recordedAt,digest},proof:{signer:r.signer,digest,direct:false},head:beforeHead,ep:H(130000+n),rp:H(140000+n)};
    if(op!==61n){detail.context=zero(originalAttribution.ARTIST_ATTRIBUTION_CONTEXT_TUPLE);detail.g=zero(originalAttribution.ARTIST_ATTRIBUTION_GOVERNANCE_WITNESS_TUPLE);if(governed)Object.assign(detail.g,{actionId:r.governanceActionId,proposer:A(70),actionClass:2n});}
    e.payload=originalAttribution.encodeArtistAttributionArchiveDetail(detail);
    if(action===1n){
      const lastResolution=b.resolutions.filter(d=>d.record.terms.bindingGeneration===BigInt(g+1)).at(-1);
      Object.assign(head,{disputeRecordHash:r.recordHash,counterStatementRecordHash:Z,restoreState:2n,revocationReason:lastResolution?.record.terms.resolution===2n?4n:0n,open:true,reopened:lastResolution?.record.terms.resolution===2n});
      for(const pending of b.repudiations.filter(v=>v.terminal.phase===1n)) Object.assign(pending.terminal,{phase:5n,actor:ZeroAddress,reasonHash:r.recordHash,recordedAt:r.recordedAt});
      b.pending=Z;b.current.state=4n;
    } else if(action===3n)head.counterStatementRecordHash=r.recordHash;
    else {Object.assign(opening.withdrawal,{recordHash:r.recordHash,counterStatementRecordHash:head.counterStatementRecordHash,restoredState:2n});head.open=false;head.revocationReason=0n;b.current.state=2n;}
    attribution[k].records.item.state=b.current.state;b.disputes.push(saved);saveArchive(e,k);return saved;
  }
  function resolve(k,g,resolution) {
    const q=collections[k],binding=bindings[k].bindings.rows[g].item,b=attribution[k].history,head=b.heads[g],saved=zero(T.resolutionRow),r=saved.record,n=serial++;
    Object.assign(r.terms,{collectionId:q.collectionId,bindingGeneration:BigInt(g+1),disputeRecordHash:head.disputeRecordHash,resolution,evidenceHash:H(150000+n),reasonHash:H(160000+n),counterStatementRecordHash:head.counterStatementRecordHash});
    Object.assign(r,{actionId:H(170000+n),actor:A(71),proposer:A(70),actionClass:2n,restoredState:resolution===2n?5n:2n,resolvedAt:100n+BigInt(n),previousResolutionActionId:head.resolutionActionId});
    const gov={actionId:r.actionId,proposer:r.proposer,actionClass:r.actionClass,roleMutationHash:H(180000+n),roleRevision:1n,scopeHash:H(190000+n),oldValueHash:H(200000+n),newValueHash:H(210000+n)};
    r.witnessHash=hash([originalAttribution.ARTIST_ATTRIBUTION_GOVERNANCE_WITNESS_TUPLE],[gov]);
    const e=envelope(46n,r.actor,r.actionId,false);saved.point=point(4);
    e.payload=originalAttribution.encodeArtistAttributionArchiveDetail({operationId:46n,p:clone(r.terms),b:clone(binding),context:{scopeHash:gov.scopeHash,oldValueHash:gov.oldValueHash,newValueHash:gov.newValueHash,requiredClass:2n,restoredState:r.restoredState},g:gov,ep:H(220000+n),rp:H(230000+n)});
    alias(4,point(4),"attribution_lifecycle.replay.dispute_resolution_key",r.terms.disputeRecordHash,r.actionId);alias(4,point(4),"attribution_lifecycle.replay.governance_action",r.actionId,r.terms.disputeRecordHash);
    Object.assign(head,{resolutionActionId:r.actionId,open:false,revocationReason:resolution===2n?4n:0n,restoreState:2n});b.current.state=r.restoredState;attribution[k].records.item.state=b.current.state;
    b.resolutions.push(saved);saveArchive(e,k);return saved;
  }
  function stage(k,g) {
    const q=collections[k],binding=bindings[k].bindings.rows[g].item,b=attribution[k].history,identity=identities.find(a=>a.artistId===q.artistId),saved=zero(T.repudiationRow),r=saved.record,n=serial++;
    const nonce=principalUsed.get(q.artistId);principalUsed.set(q.artistId,nonce+1n);
    Object.assign(r.terms,{collectionId:q.collectionId,bindingGeneration:BigInt(g+1),disputeAction:4n,evidenceHash:H(240000+n),reasonHash:H(250000+n)});
    Object.assign(r,{artistId:q.artistId,signer:identity.identity.authorityAddress,authorityClass:identity.identity.authorityClass,nonce,stagedAt:20n+BigInt(n),executableAt:200n+BigInt(n),bindingHash:binding.bindingHash,capturedGuardianSet:H(260000+ids.indexOf(q.artistId)),windowRevision:1n});
    Object.assign(r.authorityHead,{principal:r.signer,authorityClass:r.authorityClass});r.recordHash=originalAttribution.artistAttributionRepudiationRecordHash(at,r);saved.terminal.phase=1n;
    const e=envelope(47n,r.signer,r.recordHash,true);saved.point=point(4);const auth={nonce,time:1000n,signature:"0x0102"};
    const digest=originalAttribution.artistAttributionSigningPayload(at,r.terms,auth).digest;authorize(identity,r.recordHash,nonce,digest,false);
    e.payload=originalAttribution.encodeArtistAttributionArchiveDetail({operationId:47n,p:clone(r.terms),a:auth,admission:{binding_:clone(binding),authorityHead:clone(r.authorityHead),guardianSet:r.capturedGuardianSet,stagedAt:r.stagedAt,executableAt:r.executableAt,windowRevision:r.windowRevision},proof:{signer:r.signer,digest,direct:false}});
    row(4,47n,q.artistId,q.collectionId,r.recordHash);alias(4,point(4),"attribution_lifecycle.replay.repudiation_key",r.recordHash,r.recordHash);
    b.pending=r.recordHash;b.repudiations.push(saved);saveArchive(e,k);return saved;
  }
  function terminal(k,phase) {
    const q=collections[k],b=attribution[k].history,saved=b.repudiations.at(-1),r=saved.record,identity=identities.find(a=>a.artistId===q.artistId),n=serial++,actor=phase===3n?r.signer:A(800),reason=phase===2n?H(270000+n):phase===4n?r.terms.reasonHash:Z;
    Object.assign(saved.terminal,{phase,actor,reasonHash:reason,recordedAt:300n+BigInt(n)});
    const op=phase+46n,e=envelope(op,actor,r.recordHash,phase!==4n);saved.terminalPoint=point(4);
    const detail={operationId:op,r:clone(r)};
    if(phase===2n){
      if(!identity.guardians.some(g=>g.record.recordHash===r.capturedGuardianSet)){const g=zero(child(T.identity,"guardians").arrayChildren);g.record.recordHash=r.capturedGuardianSet;g.record.terms.artistId=q.artistId;g.record.terms.guardians=[actor];identity.guardians.push(g);}
      const c=zero(child(T.identity,"contests").arrayChildren);Object.assign(c.record,{recordHash:H(280000+n),contester:actor,contestedAt:saved.terminal.recordedAt,guardianSetRecordHash:r.capturedGuardianSet});Object.assign(c.record.terms,{artistId:q.artistId,evidenceHash:r.recordHash,reasonHash:reason});
      c.position=clone(row(2,48n,q.artistId,q.collectionId,c.record.recordHash).position);identity.contests.push(c);
      const cause=zero(child(T.identity,"causes").arrayChildren);cause.point=point(2);cause.cause.causeHash=H(290000+n);Object.assign(cause.cause.facts,{kind:1n,artistId:q.artistId,referenceHash:c.record.recordHash,actor,evidenceHash:r.recordHash,reasonHash:reason,enteredAt:saved.terminal.recordedAt});identity.causes.push(cause);row(2,48n,q.artistId,q.collectionId,cause.cause.causeHash);
      detail.proof={collectionId:q.collectionId,repudiationRecordHash:r.recordHash,capturedGuardianSet:r.capturedGuardianSet,currentGuardianSet:r.capturedGuardianSet,vetoer:actor,reasonHash:reason,vetoedAt:saved.terminal.recordedAt};detail.contest=c.record.recordHash;
    }
    e.payload=originalAttribution.encodeArtistAttributionArchiveDetail(detail);
    alias(4,point(4),`attribution_lifecycle.replay.${phase===2n?"repudiation_veto_key":phase===3n?"repudiation_cancellation_key":"repudiation_execution_key"}`,r.recordHash,hash(["bytes32","uint8","bytes32"],[r.recordHash,phase,reason]));
    b.pending=Z;if(phase===4n){b.heads[Number(r.terms.bindingGeneration-1n)].revocationReason=3n;b.current.state=5n;attribution[k].records.item.state=5n;}saveArchive(e,k);return saved;
  }

  function finishEra() {
    const count=identities.reduce((n,b)=>n+b.nonces.length,0);
    const checkpoints=seven(i=>({schema:m.ARTIST_RECOVERED_MULTIPLE_DISPUTE_HYDRATION_CHECKPOINT_SCHEMA,ownerState:clone(clock[i]),replayRoot:aliases[i].some(a=>a.originHash===oh)?H(240+eras.length*10+i):Z,
      replayCount:BigInt(aliases[i].filter(a=>a.originHash===oh).length),nonceRoot:i===2?H(280+eras.length):Z,nonceIndexCount:i===2?BigInt(count):0n}));
    eras.push({originHash:oh,priorImportCommitment:eras.length?H(89001):Z,checkpoints,nativeCounts:journals.map((a,i)=>BigInt(a.length-eraStart[i])),lowerRevisions:clone(lower)});
    const rows=archiveRows.filter(r=>r.originHash===oh),catalogue={originHash:oh,archiveCodeHash:keccak256(args.codes?.get(origin.archive)??"0x6001"),configurationHash:config,count:BigInt(rows.length),rowsHash:Z,lower:clone(lower),upper:checkpoints.map(c=>c.ownerState.revision)};
    catalogue.rowsHash=hash(["bytes32","bytes32","address","bytes32","bytes32","uint256"],[id("6529STREAM_ARTIST_RECOVERED_PLATFORM_CATALOGUE_V1"),oh,origin.archive,catalogue.archiveCodeHash,config,catalogue.count]);
    for(const row of rows)catalogue.rowsHash=hash(["bytes32","uint256","address","bytes32","bytes32"],[catalogue.rowsHash,row.catalogueIndex,row.pointer,row.kind,row.hash]);
    catalogues.push(catalogue);
  }
  function cutover() {
    finishEra();
    const previous=oh;
    origin=finalOrigin;oh=m.artistRecoveredMultipleDisputeHydrationOriginHash(origin);origins.push(clone(origin));config=H(8901);at={chainId,registry:origin.registry,core:origin.core};
    eraStart=journals.map(a=>a.length);archiveStart=envelopes.length;lower=seven(i=>i===2?2n+BigInt(ids.length+collections.length):1n);
    for(let i=0;i<7;i++) {
      clock[i]={domainId:m.artistRecoveredMultipleDisputeHydrationOwnerDomain(i),revision:lower[i],stateRoot:H(99000+i),recordChainTip:H(99100+i)};
      for(const a of aliases[i].filter(a=>a.originHash===previous)) aliases[i].push({...clone(a),originHash:oh,originalKey:m.artistRecoveredMultipleDisputeHydrationReplayKey(origin,i,{surface:a.surface,scope:a.scope})});
    }
  }
  for (let g = 0; g < generationCount; g++) {
    for (let k = 0; k < collections.length; k++) publication(k, g, 1n);
    for (let k = 0; k < collections.length; k++) {
      if (!(g === 0 && pendingRevoked && generationCount > 1)) publication(k, g, bindings[k].bindings.rows[g].item.accepted ? 2n : k % 2 ? 4n : 3n);
      if (bindings[k].bindings.rows[g].item.accepted) consent(k, g);
      if (bindings[k].bindings.rows[g].item.accepted && attestations) attest(k, g);
    }
    if (g === 0 && generationCount > 1 && acceptedHistory) {
      for (let k=0;k<collections.length;k++) stage(k,g);
      for (let k=collections.length-1;k>=0;k--) terminal(k,4n);
    } else if (g === 0 && generationCount > 1 && pendingRevoked) {
      for (let k=0;k<collections.length;k++) dispute(k,g,1n,true);
      for (let k=collections.length-1;k>=0;k--) resolve(k,g,2n);
    }
  }
  const current = generationCount-1;
  for (let k=0;k<collections.length;k++) { attribution[k].history.current.state=2n; attribution[k].records.item.state=2n; }
  if (["pending","cancel","veto"].includes(history)) {
    for (let k=0;k<collections.length;k++) stage(k,current);
    if (history!=="pending") for (let k=collections.length-1;k>=0;k--) terminal(k,history==="veto"?2n:3n);
  } else if (history==="reopen") {
    for (let k=0;k<collections.length;k++) { stage(k,current); dispute(k,current,1n,false); }
    for (let k=collections.length-1;k>=0;k--) resolve(k,current,2n);
    for (let k=0;k<collections.length;k++) dispute(k,current,1n,true);
    for (let k=collections.length-1;k>=0;k--) resolve(k,current,2n);
  } else if (history!=="pending-revoked") {
    for (let k=0;k<collections.length;k++) dispute(k,current,1n,false);
    for (let k=collections.length-1;k>=0;k--) dispute(k,current,3n,false);
    if(repeated) cutover();
    for (let k=0;k<collections.length;k++) dispute(k,current,2n,false);
  }
  // Grant conservation combines every content and dispute use, including retained earlier generations.
  for (const identity of identities) for (const d of identity.delegations) {
    const total = delegateUsed.get(identity.artistId); d.record.uses=total;
    // maxUses was intentionally reserved when the grant was admitted; never rehash its identity here.
    const lane=identity.nonces.find(n=>n.kind===2n); if(lane) { lane.hint=total; lane.words[0].words[0]=(1n<<total)-1n; }
  }
  const nonces = identities.toReversed().flatMap(b => b.nonces.map(n => ({ index: { kind: n.kind, key: n.key, prefixCount: BigInt(n.words.length) }, words: clone(n.words) })));
  finishEra();
  const provenance = {origins,eras,journals,aliases}, checkpoints=eras.at(-1).checkpoints;
  const payouts = artists.map(q => Object.assign(zero(T.payout), {artistId:q.artistId,sourceSnapshot:clone(checkpoints[5].ownerState)}));
  const clocks={catalogues,operations,bindings,generations};
  const features = 16777216n | 8192n | (repeated ? 16n : 0n) | (generationCount > 1 ? 512n : 0n) | classes.slice(0, ids.length).reduce((n,c) => n | (c === 1n ? 1n : 2n), 0n)
    | ((acceptedHistory || pendingRevoked) && generationCount > 1 ? 2048n : 0n) | (attribution.some(a=>a.history.resolutions.length||a.history.repudiations.length) ? 4096n : 0n) | (attestations ? 128n | 131072n : 0n) | (consents ? 32n | 64n | 256n | 32768n : delegated ? 64n : 0n);
  const f = { options, histories: attribution.map(a=>a.history), source, origin, before: args.before ?? seven(i => ({ domainId: m.artistRecoveredMultipleDisputeHydrationOwnerDomain(i), revision: i === 2 ? BigInt(1 + ids.length + collections.length) : 0n, stateRoot: H(300 + i), recordChainTip: H(320 + i) })),
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
  const logical = p.aliases.map(rows => rows.filter(a=>a.originHash===p.eras.at(-1).originHash).map(({ surface, scope }) => ({ surface, scope })));
  const data = seven(owner => {
    const local = m.artistRecoveredMultipleDisputeHydrationOwnerProvenance(p, owner), commitment = m.artistRecoveredMultipleDisputeHydrationOwnerProvenanceHash(local, owner);
    let rows = [];
    if (owner === 0) rows = bindings.map(b => { b.bindings.provenanceCommitment = commitment; return coder.encode([T.bindingBundle], [b]); });
    if (owner === 2) rows = identities.map(b => { b.sourceSnapshot = clone(cp[2].ownerState); return coder.encode([T.identity], [b]); });
    if (owner === 3) rows = acceptances.map(b => { b.provenance = commitment; return coder.encode([T.acceptanceBundle], [b]); });
    if (owner === 4) rows = attribution.map(b => { b.history.provenance = commitment; b.records.provenance = commitment; return coder.encode([T.gAttribution], [b]); });
    if (owner === 5) rows = payouts.map(b => coder.encode(["bytes32", T.payout], [id("6529STREAM_ARTIST_RECOVERED_PAYOUT_HYDRATION_V1"), b]));
    if (owner === 6) rows = contents.map(b => { b.rows.original.provenance = commitment; return coder.encode([T.consents], [b]); });
    const s = { artists: clone(artists), collections: clone(collections), rows };
    f.states[owner] = s;
    const publications = f.codes && [2, 4, 6].includes(owner) ? [{ pointer: A(90 + owner), payloadType: H(800 + owner), payloadHash: keccak256("0x1234") }] : [];
    if (publications.length) f.codes.set(publications[0].pointer, "0x001234");
    const payload = { provenance: local, nonces: owner === 2 ? clone(f.nonces) : [], publications,
      semanticState: coder.encode(["bytes32", "uint16", "uint8", T.state, "bytes"], [id("6529STREAM_ARTIST_MULTIPLE_DISPUTE_HISTORY_V1"), 1n, BigInt(owner), s, owner === 0 || owner === 4 ? coder.encode([T.clocks], [f.clocks]) : owner === 3 ? coder.encode([`${T.generation.format("full")}[][]`], [f.clocks.generations]) : "0x"]) };
    f.payloads[owner] = payload;
    const keys = logical[owner].map(v => m.artistRecoveredMultipleDisputeHydrationReplayKey(origin, owner, v));
    return { typedState: m.encodeArtistRecoveredMultipleDisputeHydrationOwnerPayload(payload, owner, f.features), origins: logical[owner], sourceKeys: keys, cells: keys.map(key => p.aliases[owner].find(a => a.originalKey === key).cell), nonces: [] };
  });
  const query = { ...clone(collections[0]), records: clone(artists.find(a => a.artistId === collections[0].artistId).records) };
  f.prepared = f.certificate = { admission: { prior: origin.registry, sourceCoordinator: origin.coordinator, source: f.source, provenance: p, artists, collections, before_: f.before }, query, data, timing: f.timing,
    externalGuards: { schema: id("6529STREAM_ARTIST_RECOVERED_EXTERNAL_GUARDS_V1"), provenanceCommitment: m.artistRecoveredMultipleDisputeHydrationProvenanceHash(p), artistId: artists[0].artistId, actions: [], finality: [], entropy: [] } };
  f.request = { records: { authority: { bindingIndex: 0n, artistIds: artists.map(a => a.artistId), collections: collections.map(q => ({ artistId: q.artistId, collectionId: q.collectionId, policies: clone(q.policies) })), expectedSource: cp, replayOrigins: logical },
    witnesses: collections.map((q, i) => ({ collectionId: q.collectionId, economics: contents[i].rows.original.economics.map(e => clone(e.item.terms)), attestations: attestations[i].records.map(r => clone(r.attestation.input)) })).filter(w => w.economics.length || w.attestations.length) },
    expectedCapabilities: seven(i => ({ profile: m.ARTIST_RECOVERED_MULTIPLE_DISPUTE_HYDRATION_PROFILE, version: 1n, ownerIndex: BigInt(i), ownerDomain: m.artistRecoveredMultipleDisputeHydrationOwnerDomain(i),
      checkpointSchema: m.ARTIST_RECOVERED_MULTIPLE_DISPUTE_HYDRATION_CHECKPOINT_SCHEMA, stateSchema: m.artistRecoveredMultipleDisputeHydrationOwnerTag(i), supportedFeatures: 33554431n })), expectedSourceImportCommitment: p.eras.at(-1).priorImportCommitment, expectedSemanticInventory: Z };
  // Original semanticInventory is a supplied-facts preimage, independent of full admission.
  const q = f.prepared;
  f.request.expectedSemanticInventory = hash(["bytes32", "uint16", "bytes32", child(T.prepared, "query"), child(T.prepared, "data"), child(T.prepared, "timing"), child(T.prepared, "externalGuards")],
    [id("6529STREAM_ARTIST_RECOVERED_SEMANTIC_INVENTORY_V1"), 1n, m.artistRecoveredMultipleDisputeHydrationProvenanceHash(p), q.query, q.data, q.timing, q.externalGuards]);
  f.input = { request: f.request, royaltyFreezes: p.journals[6].filter(j => j.receipt.operation === 20n).map(j => clone(contents.flatMap(b => b.rows.royalties).find(r => r.item.recordHash === j.receipt.recordHash).terms)) };
  return f;
}
