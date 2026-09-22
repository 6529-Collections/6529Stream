// Compiler-encoded RPC consistency tests. No EVM, signature validation, Safe threshold, or owner-root execution is implied.
import test from "node:test";
import assert from "node:assert/strict";
import { AbiCoder, Interface, ZeroAddress, ZeroHash, getAddress, id, keccak256 } from "ethers";
import { fixture, compiledInterfaces } from "./current-artist-recovered-multiple-attestation-hydration-source-fixture.mjs";
import * as pure from "../dist/current-artist-collaborator.js";
import * as workflow from "../dist/current-artist-collaborator-workflow.js";

// Only the retained bd4 compiler witness encodes provider results and native event inputs.
const abi = new Interface(Object.values(fixture.abis).flat().filter(f => f.type !== "constructor"));
const events = new Interface([...Object.values(fixture.abis).flat(), ...Object.values(fixture.libraryAbis).flat()].filter(f => f.type === "event"));
const coder = AbiCoder.defaultAbiCoder(), A = n => getAddress(`0x${BigInt(n).toString(16).padStart(40, "0")}`), H = id;
const hash = (types, values) => keccak256(coder.encode(types, values));
const tuple = (method, index = 0, output = false) => (output ? abi.getFunction(method).outputs : abi.getFunction(method).inputs)[index].format("full");
const domains = ["binding_lifecycle", "collaborator_lifecycle", "identity_authority", "acceptance_lifecycle", "attribution_lifecycle", "payout_lifecycle", "consent_finality"].map(v => H(`domain:${v}`));
const snapshotType = tuple("ownerStateSnapshotV2", 0, true), proofType = "(address signer,bytes32 digest,bool direct)";
const emptySnapshot = () => ({ domainId: ZeroHash, revision: 0n, stateRoot: ZeroHash, recordChainTip: ZeroHash });
const emptyCell = () => ({ commitment: ZeroHash, touchedRevision: 0n, kind: 0n, status: 0n });
const safeABI = new Interface(["function execTransaction(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,bytes signatures) returns(bool)", "event ExecutionSuccess(bytes32 txHash,uint256 payment)", "event ExecutionFailure(bytes32 txHash,uint256 payment)"]);

function sourceDigest(st, request = st.request) {
  const auth = request.authorization;
  const struct = request.kind === "acceptIdentity"
    ? hash(["bytes32", "address", "bytes32", "uint256", "uint64"], [H("StreamCollaboratorIdentityAcceptance(address account,bytes32 identityRecordHash,uint256 nonce,uint64 deadline)"), request.account, request.identityRecordHash, auth.nonce, auth.time])
    : hash(["bytes32", "address", "uint256", "uint64", "bytes32", "address", "bytes32", "bytes32", "uint256", "uint64"], [H("StreamCollaboratorAcceptance(address core,uint256 collectionId,uint64 bindingGeneration,bytes32 bindingHash,address collaborator,bytes32 role,bytes32 shareLabelId,uint256 nonce,uint64 deadline)"), request.core, request.terms.collectionId, request.terms.generation, request.terms.bindingHash, request.terms.account, request.terms.role, request.terms.shareLabelId, auth.nonce, auth.time]);
  const domain = hash(["bytes32", "bytes32", "bytes32", "uint256", "address"], [H("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"), H("6529StreamArtistRegistry"), H("1"), 1n, st.deployment.registry.address]);
  return keccak256(`0x1901${domain.slice(2)}${struct.slice(2)}`);
}
function sourceProposal(st, proposer = st.proposer) {
  return hash(["bytes32", "uint256", "address", tuple("proposeCollaboratorIdentity"), "address"], [H("6529STREAM_COLLABORATOR_IDENTITY_PROPOSAL_V1"), 1n, st.deployment.registry.address, st.request.kind === "proposeIdentity" ? st.request.proposal : st.proposal.proposal, proposer]);
}
function sourceArtistId(st, allocationNonce = st.allocationNonce) {
  return hash(["bytes32", "uint256", "address", "address", "bytes32", "uint256"], [H("6529STREAM_ARTIST_ID_V1"), 1n, st.deployment.registry.address, st.account, st.documentHash, allocationNonce]);
}
function sourceAcceptance(st, timestamp = st.timestamp) {
  const p = st.request.terms;
  return hash(["bytes32", "uint256", "address", "address", "uint256", "uint64", "bytes32", "uint8", "address", "uint8", "uint256", "uint64"], [H("6529STREAM_ARTIST_ACCEPTANCE_RECORD_V1"), 1n, st.deployment.registry.address, st.deployment.components[9].address, p.collectionId, p.generation, p.bindingHash, 2n, p.account, st.authorityClass, st.request.authorization.nonce, timestamp]);
}
function accountReplayKey(st, kind) {
  const scope = kind === "nonce" ? hash(["address", "uint256"], [st.account, st.request.authorization.nonce]) : hash(["address", "bytes32"], [st.account, sourceDigest(st)]);
  return hash(["bytes32", "uint256", "address", "address", "address", "address", "bytes32", "bytes32", "bytes32"], [H("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"), 1n, st.deployment.registry.address, st.deployment.coordinator.address, st.deployment.components[8].address, st.deployment.components[2].address, domains[2], H(`identity_authority.replay.collaborator_account_${kind}`), scope]);
}
function rebind(s) {
  const st = s.state, b = st.binding;
  const terms = st.rows.map(({ account, role, shareLabelId }) => ({ account, role, shareLabelId }));
  st.bindingTerms.collaboratorSetHash = hash(["bytes32", "(address account,bytes32 role,bytes32 shareLabelId)[]"], [H("6529STREAM_ARTIST_COLLABORATOR_SET_V1"), terms]);
  st.bindingTerms.count = BigInt(terms.length);
  b.bindingHash = hash(["bytes32", "uint256", "address", "address", "uint256", "uint64", "bytes32", "address", "bytes32", "uint8", "uint8", "uint8", "uint8", "uint32", "bytes32", "bytes32"], [H("6529STREAM_ARTIST_BINDING_V1"), 1n, st.deployment.registry.address, st.deployment.components[9].address, 42n, b.generation, b.artistId, b.artistAddress, b.identityRecordHash, b.consentMode, b.saleConsentScope, b.registryImmutabilityElection, 0n, 0n, st.bindingTerms.collaboratorSetHash, st.bindingTerms.capabilityPolicySetHash]);
  st.request.terms.bindingHash = b.bindingHash;
  s.prepared = pure.prepareCollaboratorCall(st.request);
}
function setup(kind = "acceptRow", options = {}) {
  const codes = new Map();
  const pin = n => { const address = A(n), code = `0x60${n.toString(16).padStart(2, "0")}6000`; codes.set(address, code); return { address, codeHash: keccak256(code) }; };
  const components = Array.from({ length: 16 }, (_, i) => pin(i + 1));
  const deployment = { chainId: 1n, registry: components[7], coordinator: pin(20), components, reads: pin(21) };
  const account = A(60), proposer = A(70), caller = options.caller ?? (kind === "proposeIdentity" ? proposer : account);
  const timestamp = 1000000n, document = "0x7b226e616d65223a22636f6c6c61626f7261746f72227d", documentHash = keccak256(document);
  const proposal = { proposal: { account, identityRecordHash: documentHash, identityRecordURI: "ipfs://identity", reasonHash: H("admit collaborator"), reasonURI: "ipfs://reason" }, proposer, proposalHash: ZeroHash, acceptedArtistId: ZeroHash };
  const authorization = { nonce: 7n, time: timestamp + 100n, signature: options.signature ?? "0x" };
  const binding = { artistId: H("collection primary artist"), artistAddress: A(80), identityRecordHash: H("primary identity"), bindingHash: H("placeholder"), generation: 3n, consentMode: 1n, saleConsentScope: 0n, registryImmutabilityElection: 0n, proposer, accepted: false };
  const rows = [{ account, role: H("image"), shareLabelId: H("artist share"), collaboratorArtistId: ZeroHash, acceptanceRecordHash: ZeroHash, accepted: false },
    { account: A(61), role: H("audio"), shareLabelId: H("music share"), collaboratorArtistId: H("other artist"), acceptanceRecordHash: H("other row accepted"), accepted: true }];
  const bindingTerms = { collaboratorSetHash: ZeroHash, capabilityPolicySetHash: hash(["bytes32", "bytes32[]"], [H("6529STREAM_ARTIST_CAPABILITY_POLICY_SET_V1"), []]), mode: 0n, threshold: 0n, count: 2n };
  const context = { chainId: 1n, registry: deployment.registry.address, caller };
  const request = kind === "proposeIdentity" ? { ...context, kind, proposal: proposal.proposal }
    : kind === "acceptIdentity" ? { ...context, kind, account, identityRecordHash: documentHash, authorization, document, displayName: "Collaborator" }
    : { ...context, kind, core: components[9].address, terms: { collectionId: 42n, generation: 3n, bindingHash: binding.bindingHash, account, role: rows[0].role, shareLabelId: rows[0].shareLabelId }, authorization };
  const state = { codes, deployment, request, account, proposer, timestamp, documentHash, proposal, binding, bindingTerms, rows,
    artistId: H("collaborator own artist"), authorityClass: 1n, authorityStatus: 1n, capabilities: 4095n,
    allocationNonce: 93n, registrationNonce: [false, 7n], nonceCell: emptyCell(), digestCell: emptyCell(),
    replay: { digestObserved: false, digestRevoked: false, nonceConsumed: false, nonceRevoked: false, nextUnusedNonce: kind === "acceptIdentity" ? 0n : 7n },
    acceptedCount: 1n, primaryRecord: H("primary acceptance"), attribution: [1n, 3n], exists: true, roleAllowed: true,
    hooks: [], calls: [], blockCalls: 0, codeHook: undefined, blockHook: undefined, failSimulation: false, simulationResult: undefined,
    nativeCount: 4n, native: [], archive: null, tx: null, receipt: null,
    snapshots: domains.map((domainId, i) => ({ domainId, revision: BigInt(10 + i), stateRoot: H(`root${i}`), recordChainTip: H(`tip${i}`) })) };
  state.proposal.proposalHash = sourceProposal(state);
  if (kind === "proposeIdentity") state.proposal = { proposal: { account: ZeroAddress, identityRecordHash: ZeroHash, identityRecordURI: "", reasonHash: ZeroHash, reasonURI: "" }, proposer: ZeroAddress, proposalHash: ZeroHash, acceptedArtistId: ZeroHash };
  const suite = { registry: components[7].address, archive: components[8].address, owners: components.slice(0, 7).map(v => v.address), core: components[9].address, mintManager: components[10].address, roleRegistry: components[11].address, metadata: components[12].address, primaryResolver: components[13].address, royaltyResolver: components[14].address, primaryRevenueClass: H("PRIMARY_SALE"), validator: components[15].address };
  const encode = (f, values) => abi.encodeFunctionResult(f, values);
  const provider = {
    async getNetwork() { return { chainId: 1n }; },
    async getBlock(tag) { state.blockCalls++; return state.blockHook?.(tag, state.blockCalls) ?? { number: tag, hash: H(`block${tag}`), timestamp: Number(state.timestamp) }; },
    async getCode(addr, tag) { return state.codeHook?.(getAddress(addr), tag) ?? codes.get(getAddress(addr)) ?? "0x"; },
    async getTransaction() { return state.tx; }, async getTransactionReceipt() { return state.receipt; },
    async call(tx) {
      const parsed = abi.parseTransaction({ data: tx.data }), f = parsed.fragment, method = f.name, args = parsed.args, to = getAddress(tx.to);
      state.calls.push({ ...tx, method, args });
      for (const hook of state.hooks) { const result = await hook({ method, args, to, tx, fragment: f }); if (result !== undefined) return typeof result === "string" ? result : encode(f, result); }
      switch (method) {
        case "deploymentChainId": return encode(f, [1n]); case "suiteConfiguration": return encode(f, [suite]);
        case "configurationHash": return encode(f, [H("configuration")]); case "reads": return encode(f, [deployment.reads.address]);
        case "core": return encode(f, [components[9].address]); case "mintManager": return encode(f, [components[10].address]);
        case "artistRegistry": return encode(f, [deployment.registry.address]); case "operationCoordinator": return encode(f, [deployment.coordinator.address]);
        case "archiveV2": return encode(f, [components[8].address]); case "domainId": return encode(f, [domains[components.findIndex(v => v.address === to)]]);
        case "getSatellitePointer": return encode(f, [deployment.registry.address, deployment.registry.codeHash, false, ZeroHash, "0x00000000", ZeroAddress, 0n, ZeroHash, ZeroHash, 1n]);
        case "artistRegistryCutover": return encode(f, [false, ZeroAddress, 0n]);
        case "ownerStateSnapshotV2": return encode(f, [state.snapshots[components.findIndex(v => v.address === to)]]);
        case "hasRole": return encode(f, [state.roleAllowed]); case "roleMutationState": return encode(f, [H("admin mutation"), 8n]);
        case "collaboratorIdentityProposal": return encode(f, [state.proposal]);
        case "activeIdentity": return encode(f, [kind === "acceptRow" ? state.artistId : ZeroHash]);
        case "nextRegistrationNonce": return encode(f, [state.allocationNonce]);
        case "collaboratorRegistrationNonceState": return encode(f, tx.blockTag >= 12 && state.archive ? state.minedRegistrationNonce ?? [true, 8n] : state.registrationNonce);
        case "replayCell": {
          if (args[0] === accountReplayKey(state, "nonce")) return encode(f, [state.nonceCell]);
          if (args[0] === accountReplayKey(state, "digest")) return encode(f, [tx.blockTag >= 12 && state.archive ? state.minedDigestCell ?? { commitment: sourceDigest(state), touchedRevision: state.receiptAfter[2].revision, kind: 1n, status: 2n } : state.digestCell]);
          throw Error("Unexpected account replay key: original nine-word scope required");
        }
        case "artistAuthorizationState": return encode(f, [tx.blockTag >= 12 && state.archive ? state.minedReplay ?? { ...state.replay, digestObserved: true, nonceConsumed: true } : state.replay]);
        case "collaboratorIdentityDigest": case "collaboratorAcceptanceDigest": return encode(f, [sourceDigest(state)]);
        case "binding": return encode(f, [state.binding]); case "bindingTerms": return encode(f, [state.bindingTerms]);
        case "collectionExists": return encode(f, [state.exists]); case "attributionState": return encode(f, state.attribution);
        case "collaboratorCount": return encode(f, [BigInt(state.rows.length)]); case "collaboratorAt": return encode(f, [state.rows[Number(args[2])]]);
        case "acceptedCount": return encode(f, [state.acceptedCount]); case "acceptanceRecord": return encode(f, [state.primaryRecord]);
        case "authorityState": return encode(f, [account, state.authorityClass, state.authorityStatus, H("identity")]);
        case "currentAuthorityCapabilities": return encode(f, [{ authorityAddress: account, authorityClass: state.authorityClass, status: state.authorityStatus, effectiveCapabilities: state.capabilities, activationRecordHash: state.authorityClass === 1n ? ZeroHash : H("estate activation") }]);
        case "artistNativeReceiptCount": return encode(f, [tx.blockTag >= 12 && state.archive ? state.nativeCount : 4n]);
        case "artistNativeReceiptAt": return encode(f, [state.native[Number(args[0] - 4n)].receipt]);
        case "artistNativeReceiptRevisionAt": return encode(f, [state.native[Number(args[0] - 4n)].revision]);
        case "artistEvidenceMetadataV2": return encode(f, [state.archive.contentHash, state.archive.pointer, BigInt((state.archive.bytes.length - 2) / 2), 12n]);
        case "artistEvidenceBytesV2": return encode(f, [state.archive.bytes]);
        case "proposeCollaboratorIdentity": case "acceptCollaboratorIdentity": case "acceptCollaborator":
          if (state.failSimulation) throw Error("original contract refused collaborator operation");
          return encode(f, [state.simulationResult ?? (kind === "proposeIdentity" ? sourceProposal(state, request.caller) : kind === "acceptIdentity" ? sourceArtistId(state) : sourceAcceptance(state))]);
        default: throw Error(`Unhandled compiler fixture call ${method}`);
      }
    },
  };
  const s = { state, provider, deployment, encode, prepared: pure.prepareCollaboratorCall(request) };
  if (kind === "acceptRow") rebind(s);
  return s;
}
const capture = s => workflow.captureCollaborator(s.provider, s.deployment, s.prepared, { blockTag: 10 });
const exact = message => ({ message });
function installReceipt(s, c, execution = "direct", change = {}) {
  const st = s.state, q = c.prepared.request, op = BigInt(c.prepared.operation), blockNumber = 12;
  const transactionHash = H("collaborator transaction"), blockHash = H("block12");
  const allocationNonce = change.allocationNonce ?? st.allocationNonce, priorCount = change.priorCount ?? st.acceptedCount, primaryRecord = change.primaryRecord ?? st.primaryRecord;
  const complete = q.kind === "acceptRow" && priorCount + 1n === BigInt(st.rows.length) && primaryRecord !== ZeroHash;
  const record = q.kind === "proposeIdentity" ? sourceProposal(st, q.caller) : q.kind === "acceptIdentity" ? sourceArtistId(st, allocationNonce) : sourceAcceptance(st);
  const before = structuredClone(change.before ?? c.snapshots), after = structuredClone(before);
  const changed = q.kind === "proposeIdentity" ? [1] : q.kind === "acceptIdentity" ? [1, 2] : complete ? [0, 1, 2, 3, 4] : [1, 2, 3];
  for (const i of changed) after[i] = { ...after[i], revision: after[i].revision + 1n, stateRoot: H(`after root${i}`), recordChainTip: q.kind === "acceptIdentity" && i === 2 || q.kind === "acceptRow" && i === 3 ? H(`after tip${i}`) : before[i].recordChainTip };
  const proof = q.kind === "proposeIdentity" ? null : { signer: st.account, digest: sourceDigest(st), direct: q.caller === st.account && q.authorization.signature === "0x" };
  let payload;
  if (op === 5n) payload = coder.encode([tuple("proposeCollaboratorIdentity"), "bytes32", "uint64"], [q.proposal, H("admin mutation"), 8n]);
  else if (op === 6n) payload = coder.encode([tuple("collaboratorIdentityProposal", 0, true), tuple("acceptCollaboratorIdentity", 2), proofType, "bytes", "string", "uint256"], [st.proposal, q.authorization, proof, q.document, q.displayName, allocationNonce]);
  else payload = coder.encode([tuple("binding", 0, true), tuple("acceptCollaborator"), "bytes32", tuple("acceptCollaborator", 1), proofType, tuple("bindingTerms", 0, true), "uint32", "uint32", "bytes32", "bool"], [st.binding, q.terms, st.artistId, q.authorization, proof, st.bindingTerms, priorCount, priorCount + 1n, primaryRecord, complete]);
  const envelope = { schema: 1n, configurationHash: H("configuration"), operation: op, actor: q.caller, record, before, after, payload, ...change };
  const raw = coder.encode(["uint16", "bytes32", "uint16", "address", "bytes32", `${snapshotType}[7]`, `${snapshotType}[7]`, "bytes"], [envelope.schema, envelope.configurationHash, envelope.operation, envelope.actor, envelope.record, envelope.before, envelope.after, envelope.payload]);
  const evidenceId = hash(["bytes32", "uint256", "address", "address", "uint16", "address", "bytes32"], [H("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"), 1n, s.deployment.registry.address, s.deployment.coordinator.address, op, q.caller, record]);
  const contentHash = keccak256(raw), pointer = A(100);
  st.receiptAfter = envelope.after;
  st.archive = { evidenceId, contentHash, pointer, bytes: raw }; st.codes.set(pointer, `0x00${raw.slice(2)}`);
  const logs = [];
  const add = (name, address, values, iface = events) => { const encoded = iface.encodeEventLog(iface.getEvent(name), values); logs.push({ address, topics: encoded.topics, data: encoded.data, index: logs.length, transactionHash, blockHash, blockNumber, removed: false }); };
  if (op === 5n) add("CollaboratorIdentityProposed", s.deployment.components[1].address, [1n, q.proposal.account, q.proposal.identityRecordHash, q.proposal.identityRecordURI, q.caller, q.proposal.reasonHash, q.proposal.reasonURI]);
  if (op === 6n) {
    add("ArtistIdentityRegistered", s.deployment.components[2].address, [1n, record, st.account, st.documentHash, st.proposal.proposal.identityRecordURI, allocationNonce]);
    add("ArtistIdentityDisplayNameStored", s.deployment.components[2].address, [record, st.documentHash, q.displayName]);
  }
  if (op === 7n) {
    add("CollaboratorAccepted", s.deployment.components[3].address, [1n, q.terms.collectionId, st.account, st.artistId, q.terms.generation, q.terms.role, q.terms.shareLabelId, st.authorityClass, q.authorization.nonce, st.timestamp, record, q.terms.bindingHash]);
    if (complete) add("ArtistAttributionStateChanged", s.deployment.components[4].address, [1n, q.terms.collectionId, 2n, q.terms.generation, 1n, st.account, st.authorityClass, record, ZeroHash, ""]);
  }
  add("ArtistArchiveEvidenceAppendedV2", s.deployment.components[8].address, [evidenceId, 1n, contentHash, pointer, BigInt((raw.length - 2) / 2)]);
  if (op !== 5n) {
    st.nativeCount = 5n;
    st.native = [{ receipt: { operation: op, artistId: op === 6n ? record : st.artistId, collectionId: op === 6n ? 0n : q.terms.collectionId, recordHash: record }, revision: envelope.after[op === 6n ? 2 : 3].revision }];
  }
  const data = execution === "safe" ? safeABI.encodeFunctionData("execTransaction", [c.prepared.call.to, 0n, c.prepared.call.data, 0, 0n, 0n, 0n, ZeroAddress, ZeroAddress, "0x1234"]) : c.prepared.call.data;
  st.tx = { hash: transactionHash, blockNumber, blockHash, chainId: 1n, from: execution === "safe" ? A(200) : q.caller, to: execution === "safe" ? q.caller : c.prepared.call.to, value: 0n, data };
  if (execution === "safe") add("ExecutionSuccess", q.caller, [H("safe signing hash"), 0n], safeABI);
  st.receipt = { hash: transactionHash, transactionHash, blockNumber, blockHash, status: 1, from: st.tx.from, to: st.tx.to, logs };
  return { transactionHash, execution, record, envelope, evidenceId, complete };
}
const inspect = (s, c, r) => workflow.inspectCollaboratorReceipt(s.provider, c, { transactionHash: r.transactionHash, execution: r.execution });

for (const kind of ["proposeIdentity", "acceptIdentity", "acceptRow"]) {
  test(`${kind}: capture, exact target simulation, and caller-bound Safe plan`, async () => {
    const s = setup(kind), c = await capture(s);
    assert.equal(c.prepared.factsVerified, false); assert.equal(c.simulationRequired, true);
    const observedSlots = s.state.calls.filter(v => v.method === "ownerStateSnapshotV2").map(v => v.to);
    assert.deepEqual(observedSlots, (kind === "acceptRow" ? [0, 1, 2, 3, 4] : [1, 2]).map(i => s.deployment.components[i].address));
    if (kind !== "proposeIdentity") { assert.equal(c.signing.digest, sourceDigest(s.state)); assert.equal(c.signing.signatureVerified, false); }
    const sim = await workflow.simulateCollaborator(s.provider, c, { gasLimit: 3000000n });
    assert.equal(sim.targetCallOnly, true);
    assert.equal(sim.recordHash, kind === "proposeIdentity" ? sourceProposal(s.state, s.state.request.caller) : kind === "acceptIdentity" ? sourceArtistId(s.state) : sourceAcceptance(s.state));
    const call = s.state.calls.findLast(v => ["proposeCollaboratorIdentity", "acceptCollaboratorIdentity", "acceptCollaborator"].includes(v.method));
    assert.equal(call.from, s.state.request.caller); assert.equal(call.value, 0n); assert.equal(call.data, s.prepared.call.data);
    const plan = workflow.createCollaboratorSafePlan(c, { safe: s.state.request.caller, title: `Review ${kind}` });
    assert.equal(plan.steps.length, 1); assert.equal(plan.steps[0].transaction.operation, 0); assert.equal(plan.steps[0].transaction.data, s.prepared.call.data);
  });
  for (const execution of ["direct", "safe"]) test(`${kind}: independently encoded ${execution} receipt joins original owners and Archive`, async () => {
    const s = setup(kind), c = await capture(s), r = installReceipt(s, c, execution), result = await inspect(s, c, r);
    assert.equal(result.recordHash, r.record);
    assert.equal(result.transactionHash, r.transactionHash);
  });
}

test("registration uses independent global allocation and account replay scopes", async () => {
  const s = setup("acceptIdentity"), c = await capture(s);
  assert.equal(c.registration.allocationNonce, 93n); assert.equal(c.prepared.request.authorization.nonce, 7n);
  assert.equal(c.registration.predictedArtistId, sourceArtistId(s.state));
  assert.deepEqual(s.state.calls.filter(v => v.method === "replayCell").map(v => v.args[0]), [accountReplayKey(s.state, "nonce"), accountReplayKey(s.state, "digest")]);
  const replay = s.state.calls.find(v => v.method === "artistAuthorizationState");
  assert.equal(replay.args[0], sourceArtistId(s.state)); assert.equal(replay.args[2], 7n);
});

test("PRIMARY_ONLY completion requires final row and primary record independently", async () => {
  for (const [otherAccepted, primaryPresent, completes] of [[true, true, true], [true, false, false], [false, true, false], [false, false, false]]) {
    const s = setup();
    if (!otherAccepted) { Object.assign(s.state.rows[1], { accepted: false, collaboratorArtistId: ZeroHash, acceptanceRecordHash: ZeroHash }); s.state.acceptedCount = 0n; }
    if (!primaryPresent) s.state.primaryRecord = ZeroHash;
    const c = await capture(s); assert.equal(c.row.completesIfExecuted, completes);
    assert.notEqual(c.row.artistId, c.row.binding.artistId);
    const r = installReceipt(s, c); await inspect(s, c, r);
    assert.equal(r.complete, completes);
    assert.equal(s.state.receipt.logs.filter(v => v.topics[0] === events.getEvent("ArtistAttributionStateChanged").topicHash).length, completes ? 1 : 0);
  }
});
test("admin denial reaches its role guard and restored role permits the same proposal", async () => {
  const s = setup("proposeIdentity"); s.state.roleAllowed = false;
  await assert.rejects(capture(s), exact("Proposal requires Registry admin"));
  s.state.roleAllowed = true; const c = await capture(s);
  assert.equal(c.role.role, H("ROLE_ARTIST_REGISTRY_ADMIN"));
  const roleRead = s.state.calls.findLast(v => v.method === "hasRole");
  assert.deepEqual([...roleRead.args], [H("ROLE_ARTIST_REGISTRY_ADMIN"), s.state.request.caller]);
});

test("proposal pair replay and an already-active account are distinct refusals", async () => {
  const s = setup("proposeIdentity"); s.state.proposal.proposalHash = H("previous proposal");
  await assert.rejects(capture(s), exact("Proposal pair already exists"));
  s.state.proposal.proposalHash = ZeroHash; await capture(s);
  s.state.hooks.push(({ method }) => method === "activeIdentity" ? [H("registered artist")] : undefined);
  await assert.rejects(capture(s), exact("Account already registered"));
  s.state.hooks.pop(); await capture(s);
});

test("registration checks the permanent proposal hash separately from pending acceptance", async () => {
  const s = setup("acceptIdentity"), original = s.state.proposal.proposalHash;
  s.state.proposal.proposalHash = H("wrong proposal");
  await assert.rejects(capture(s), exact("Proposal hash correspondence differs"));
  s.state.proposal.proposalHash = original; s.state.proposal.acceptedArtistId = H("already accepted");
  await assert.rejects(capture(s), exact("Proposal is not pending for this account/document"));
  s.state.proposal.acceptedArtistId = ZeroHash; await capture(s);
});

test("both account replay cells and registration nonce block reuse independently", async () => {
  for (const which of ["nonce", "digest", "index"]) {
    const s = setup("acceptIdentity");
    if (which === "index") s.state.registrationNonce[0] = true;
    else s.state[`${which}Cell`] = { commitment: sourceDigest(s.state), touchedRevision: 12n, kind: 1n, status: 2n };
    await assert.rejects(capture(s), exact("Account registration authorization already consumed"));
    s.state.registrationNonce[0] = false; s.state.nonceCell = emptyCell(); s.state.digestCell = emptyCell();
    const c = await capture(s); assert.equal(c.signing.replay.nextUnusedNonce, 0n); assert.equal(c.registration.nonce.firstUnused, 7n);
  }
});

test("direct account and principal nonce hints are independent while relayed nonces remain explicit", async () => {
  for (const kind of ["acceptIdentity", "acceptRow"]) {
    const s = setup(kind);
    if (kind === "acceptIdentity") s.state.registrationNonce[1] = 8n; else s.state.replay.nextUnusedNonce = 8n;
    await assert.rejects(capture(s), exact("Direct authorization requires first unused nonce"));
    s.state.request.authorization.signature = "0x1234"; s.prepared = pure.prepareCollaboratorCall(s.state.request);
    const c = await capture(s); assert.equal(c.signing.direct, false); assert.equal(c.signing.signatureVerified, false);
    if (kind === "acceptIdentity") s.state.registrationNonce[1] = 7n; else s.state.replay.nextUnusedNonce = 7n;
    s.state.request.authorization.signature = "0x"; s.prepared = pure.prepareCollaboratorCall(s.state.request);
    assert.equal((await capture(s)).signing.direct, true);
  }
});

test("raw observed principal digest is allowed; each revocation or nonce consumption is refused", async () => {
  for (const kind of ["acceptIdentity", "acceptRow"]) {
    const s = setup(kind); s.state.replay.digestObserved = true;
    assert.equal((await capture(s)).signing.replay.digestObserved, true);
    for (const field of ["digestRevoked", "nonceConsumed", "nonceRevoked"]) {
      s.state.replay[field] = true;
      await assert.rejects(capture(s), exact("Authorization is revoked or consumed"));
      s.state.replay[field] = false; await capture(s);
    }
  }
});

test("deadline equality is allowed and relay-empty EOA proof remains unverified contract boundary", async () => {
  for (const kind of ["acceptIdentity", "acceptRow"]) {
    const s = setup(kind); s.state.request.authorization.time = s.state.timestamp - 1n; s.prepared = pure.prepareCollaboratorCall(s.state.request);
    await assert.rejects(capture(s), exact("Collaborator deadline expired"));
    s.state.request.authorization.time = s.state.timestamp; s.prepared = pure.prepareCollaboratorCall(s.state.request); await capture(s);
    s.state.request.caller = A(90); s.prepared = pure.prepareCollaboratorCall(s.state.request);
    await assert.rejects(capture(s), exact("Empty relayed EOA proof"));
    s.state.codes.set(s.state.account, "0x60006000");
    const c = await capture(s); assert.equal(c.signing.direct, false); assert.equal(c.signing.signatureVerified, false);
    s.state.failSimulation = true;
    await assert.rejects(workflow.simulateCollaborator(s.provider, c, { gasLimit: 3000000n }), exact("original contract refused collaborator operation"));
    s.state.failSimulation = false; await workflow.simulateCollaborator(s.provider, c, { gasLimit: 3000000n });
  }
});

test("generation and binding-hash drift fail the live binding join; role and label mismatch reach exact-row guard", async () => {
  for (const field of ["generation", "bindingHash", "role", "shareLabelId"]) {
    const s = setup(), original = s.state.request.terms[field];
    s.state.request.terms[field] = field === "generation" ? 4n : H(`wrong ${field}`); s.prepared = pure.prepareCollaboratorCall(s.state.request);
    await assert.rejects(capture(s), exact(["generation", "bindingHash"].includes(field) ? "Acceptance requires current claimed binding" : "Exact unaccepted collaborator row missing"));
    s.state.request.terms[field] = original; s.prepared = pure.prepareCollaboratorCall(s.state.request); await capture(s);
  }
});

test("joined accepted row is refused without relying on malformed row state", async () => {
  const s = setup(); Object.assign(s.state.rows[0], { accepted: true, collaboratorArtistId: s.state.artistId, acceptanceRecordHash: H("selected acceptance") });
  s.state.acceptedCount = 2n;
  await assert.rejects(capture(s), exact("Exact unaccepted collaborator row missing"));
  Object.assign(s.state.rows[0], { accepted: false, collaboratorArtistId: ZeroHash, acceptanceRecordHash: ZeroHash }); s.state.acceptedCount = 1n;
  await capture(s);
});

test("immutable row hash, accepted count and PRIMARY_ONLY mode have separate oracles", async () => {
  const s = setup(), original = s.state.bindingTerms.collaboratorSetHash;
  s.state.bindingTerms.collaboratorSetHash = H("substitute set");
  await assert.rejects(capture(s), exact("Immutable binding/row hash differs"));
  s.state.bindingTerms.collaboratorSetHash = original; s.state.acceptedCount = 0n;
  await assert.rejects(capture(s), exact("Collaborator accepted count differs"));
  s.state.acceptedCount = 1n; s.state.bindingTerms.mode = 1n;
  await assert.rejects(capture(s), exact("Only original PRIMARY_ONLY collaborator terms supported"));
  s.state.bindingTerms.mode = 0n; await capture(s);
});

test("row acceptance uses collaborator ordinary principal, including active estate classes, not primary Artist", async () => {
  const s = setup();
  for (const authorityClass of [1n, 3n, 4n]) {
    s.state.authorityClass = authorityClass; s.state.authorityStatus = authorityClass === 1n ? 2n : 3n; s.state.capabilities = 0n;
    const c = await capture(s); assert.equal(c.row.authority.address, s.state.account); assert.equal(c.row.authority.authorityClass, authorityClass);
    assert.notEqual(c.row.artistId, c.row.binding.artistId);
  }
  s.state.authorityClass = 2n;
  await assert.rejects(capture(s), exact("Collaborator requires its own current ordinary principal"));
  s.state.authorityClass = 1n; s.state.authorityStatus = 1n;
  s.state.hooks.push(({ method }) => method === "authorityState" ? [s.state.binding.artistAddress, 1n, 1n, H("identity")] : undefined);
  await assert.rejects(capture(s), exact("Collaborator requires its own current ordinary principal"));
  s.state.hooks.pop(); await capture(s);
});

test("original digest getter drift is detected before signature claims", async () => {
  const s = setup(); s.state.hooks.push(({ method }) => method === "collaboratorAcceptanceDigest" ? [H("different digest")] : undefined);
  await assert.rejects(capture(s), exact("Original signing digest getter differs"));
  s.state.hooks.pop(); assert.equal((await capture(s)).signing.signatureVerified, false);
});

test("pinned code and block changes refuse capture with exact cause", async () => {
  const s = setup(), owner = s.deployment.components[1].address, oldCode = s.state.codes.get(owner);
  s.state.codes.set(owner, "0x60006001");
  await assert.rejects(capture(s), exact("Pinned Artist runtime differs"));
  s.state.codes.set(owner, oldCode); await capture(s);
  let reads = 0; s.state.blockHook = tag => ({ number: tag, hash: H(++reads === 1 ? `block${tag}` : "reorg"), timestamp: Number(s.state.timestamp) });
  await assert.rejects(capture(s), exact("Pinned block changed"));
  s.state.blockHook = undefined; await capture(s);
});

test("simulation refuses wrong original return and saved-capture mutation; Safe caller cannot be substituted", async () => {
  const s = setup(), c = await capture(s);
  s.state.simulationResult = H("wrong record");
  await assert.rejects(workflow.simulateCollaborator(s.provider, c, { gasLimit: 3000000n }), exact("Simulated original return differs"));
  s.state.simulationResult = undefined; await workflow.simulateCollaborator(s.provider, c, { gasLimit: 3000000n });
  const changed = structuredClone(c); changed.row.acceptedCount = 0n;
  await assert.rejects(workflow.simulateCollaborator(s.provider, changed, { gasLimit: 3000000n }), exact("Changed collaborator capture"));
  assert.throws(() => workflow.createCollaboratorSafePlan(c, { safe: A(99), title: "Wrong caller" }), exact("Safe differs from prepared actual actor"));
});
function rewriteEvent(st, name, mutate, iface = events) {
  const fragment = iface.getEvent(name), log = st.receipt.logs.find(v => v.topics[0] === fragment.topicHash);
  const values = Array.from(iface.decodeEventLog(fragment, log.data, log.topics));
  mutate(values); const encoded = iface.encodeEventLog(fragment, values); Object.assign(log, encoded);
}
function partial(s) {
  Object.assign(s.state.rows[1], { accepted: false, collaboratorArtistId: ZeroHash, acceptanceRecordHash: ZeroHash });
  s.state.acceptedCount = 0n; s.state.primaryRecord = ZeroHash;
}

test("mined registration derives actual artist from a later global allocation without conflating account nonce", async () => {
  const s = setup("acceptIdentity"), c = await capture(s);
  const before = structuredClone(c.snapshots);
  before[2] = { ...before[2], revision: before[2].revision + 1n, stateRoot: H("intervening registration root"), recordChainTip: H("intervening registration tip") };
  const r = installReceipt(s, c, "safe", { allocationNonce: 94n, before });
  const current = s.state.native[0];
  s.state.native = [{ receipt: { operation: 1n, artistId: H("another registration"), collectionId: 0n, recordHash: H("another registration") }, revision: before[2].revision }, current];
  s.state.nativeCount = 6n;
  const observed = await inspect(s, c, r);
  assert.equal(c.registration.allocationNonce, 93n); assert.equal(observed.allocationNonce, 94n);
  assert.equal(observed.artistId, sourceArtistId(s.state, 94n)); assert.notEqual(observed.artistId, c.registration.predictedArtistId);
  assert.equal(observed.native.index, 5n); assert.equal(observed.observedAccountNonce.used, true);
  const minedRead = s.state.calls.findLast(v => v.method === "artistAuthorizationState" && v.blockTag === 12);
  assert.equal(minedRead.args[0], observed.artistId); assert.equal(minedRead.args[2], 7n);
});

test("mined final row admits intervening row acceptance and primary arrival with source-clock progress", async () => {
  const s = setup(); partial(s); const c = await capture(s);
  assert.equal(c.row.completesIfExecuted, false);
  const before = structuredClone(c.snapshots);
  for (const i of [1, 2, 3]) before[i] = { ...before[i], revision: before[i].revision + (i === 1 ? 1n : 2n), stateRoot: H(`intervening root${i}`), recordChainTip: i === 3 ? H("intervening acceptance tip") : before[i].recordChainTip };
  const primaryRecord = H("primary arrived after capture"), r = installReceipt(s, c, "direct", { priorCount: 1n, primaryRecord, before });
  s.state.native.unshift(
    { receipt: { operation: 7n, artistId: H("other artist"), collectionId: 42n, recordHash: H("intervening other row") }, revision: before[3].revision - 1n },
    { receipt: { operation: 2n, artistId: s.state.binding.artistId, collectionId: 42n, recordHash: primaryRecord }, revision: before[3].revision });
  s.state.nativeCount = 7n;
  const observed = await inspect(s, c, r);
  assert.deepEqual(observed.completion, { priorCount: 1n, count: 2n, primaryRecord, complete: true });
  assert.equal(observed.native.index, 6n); assert.equal(observed.historicalEvidenceOnly, true);
});

test("mined role mutation may advance but same revision cannot name a different mutation", async () => {
  const s = setup("proposeIdentity"), c = await capture(s);
  const payload = coder.encode([tuple("proposeCollaboratorIdentity"), "bytes32", "uint64"], [c.prepared.request.proposal, H("later admin membership"), 9n]);
  let r = installReceipt(s, c, "direct", { payload });
  assert.equal((await inspect(s, c, r)).observedRole.revision, 9n);
  const wrong = coder.encode([tuple("proposeCollaboratorIdentity"), "bytes32", "uint64"], [c.prepared.request.proposal, H("different same-revision membership"), 8n]);
  r = installReceipt(s, c, "direct", { payload: wrong });
  await assert.rejects(inspect(s, c, r), exact("Archived admin role mutation differs"));
  r = installReceipt(s, c); await inspect(s, c, r);
});

test("receipt role and share label must match original native event and independently retained payload", async () => {
  for (const [field, index] of [["role", 5], ["shareLabelId", 6]]) {
    const s = setup(), c = await capture(s); let r = installReceipt(s, c);
    rewriteEvent(s.state, "CollaboratorAccepted", values => { values[index] = H(`wrong event ${field}`); });
    await assert.rejects(inspect(s, c, r), exact("CollaboratorAccepted correspondence differs"));
    r = installReceipt(s, c); await inspect(s, c, r);
    const types = [tuple("binding", 0, true), tuple("acceptCollaborator"), "bytes32", tuple("acceptCollaborator", 1), proofType, tuple("bindingTerms", 0, true), "uint32", "uint32", "bytes32", "bool"];
    const p = { ...s.state.request.terms, [field]: H(`wrong archived ${field}`) };
    const payload = coder.encode(types, [s.state.binding, p, s.state.artistId, s.state.request.authorization, { signer: s.state.account, digest: sourceDigest(s.state), direct: true }, s.state.bindingTerms, 1n, 2n, s.state.primaryRecord, true]);
    r = installReceipt(s, c, "direct", { payload });
    await assert.rejects(inspect(s, c, r), exact("Archived collaborator terms/role/label/principal/proof differ"));
    r = installReceipt(s, c); await inspect(s, c, r);
  }
});

test("archived completion count cannot skip a row or falsely complete without primary acceptance", async () => {
  for (const [count, primary, complete] of [[3n, H("primary acceptance"), true], [2n, ZeroHash, true], [2n, H("primary acceptance"), false]]) {
    const s = setup();
    if (primary === ZeroHash) s.state.primaryRecord = ZeroHash;
    const c = await capture(s);
    const types = [tuple("binding", 0, true), tuple("acceptCollaborator"), "bytes32", tuple("acceptCollaborator", 1), proofType, tuple("bindingTerms", 0, true), "uint32", "uint32", "bytes32", "bool"];
    const payload = coder.encode(types, [s.state.binding, s.state.request.terms, s.state.artistId, s.state.request.authorization, { signer: s.state.account, digest: sourceDigest(s.state), direct: true }, s.state.bindingTerms, 1n, count, primary, complete]);
    let r = installReceipt(s, c, "direct", { payload });
    await assert.rejects(inspect(s, c, r), exact("Archived row completion differs"));
    r = installReceipt(s, c); await inspect(s, c, r);
  }
});

test("receipt selected snapshot clocks, unchanged owners, and unselected zero slots are independently checked", async () => {
  const s = setup(); partial(s); const c = await capture(s);
  for (const [slot, field, value, message] of [
    [0, "revision", c.snapshots[0].revision + 1n, "Unchanged recipe owner mutated"],
    [1, "revision", c.snapshots[1].revision + 2n, "Original owner transition differs"],
    [2, "recordChainTip", H("illegal row Identity tip"), "Original owner transition differs"],
    [5, "stateRoot", H("unexpected payout root"), "Unexpected owner after snapshot"],
  ]) {
    const normal = installReceipt(s, c), after = structuredClone(normal.envelope.after); after[slot][field] = value;
    let r = installReceipt(s, c, "direct", { after });
    await assert.rejects(inspect(s, c, r), exact(message));
    r = installReceipt(s, c); await inspect(s, c, r);
  }
});

test("receipt native journal requires exact operation, Artist, collection, unique record and admitted revision", async () => {
  for (const mutate of [v => { v.receipt.operation = 6n; }, v => { v.receipt.artistId = H("wrong native artist"); }, v => { v.receipt.collectionId = 43n; }]) {
    const s = setup(), c = await capture(s); let r = installReceipt(s, c); mutate(s.state.native[0]);
    await assert.rejects(inspect(s, c, r), exact("Original native receipt correspondence differs"));
    r = installReceipt(s, c); await inspect(s, c, r);
  }
  const s = setup(), c = await capture(s); let r = installReceipt(s, c);
  s.state.native[0].revision++;
  await assert.rejects(inspect(s, c, r), exact("Native receipt admission revision differs"));
  r = installReceipt(s, c); s.state.native.push(structuredClone(s.state.native[0])); s.state.nativeCount = 6n;
  await assert.rejects(inspect(s, c, r), exact("Original native receipt correspondence differs"));
  r = installReceipt(s, c); s.state.native[0].receipt.recordHash = H("unrelated native record");
  await assert.rejects(inspect(s, c, r), exact("Original native receipt missing"));
  r = installReceipt(s, c); s.state.nativeCount = 133n;
  await assert.rejects(inspect(s, c, r), exact("Native receipt search exceeds bounded captured cursor"));
  r = installReceipt(s, c); await inspect(s, c, r);
});

test("mined principal and account replay facts remain required after otherwise joined registration evidence", async () => {
  const s = setup("acceptIdentity"), c = await capture(s), r = installReceipt(s, c);
  s.state.minedReplay = { ...s.state.replay, digestObserved: false, nonceConsumed: true };
  await assert.rejects(inspect(s, c, r), exact("Mined principal replay consumption missing"));
  s.state.minedReplay = undefined; s.state.minedRegistrationNonce = [false, 8n];
  await assert.rejects(inspect(s, c, r), exact("Mined account registration nonce missing"));
  s.state.minedRegistrationNonce = undefined;
  s.state.minedDigestCell = { commitment: sourceDigest(s.state), touchedRevision: s.state.receiptAfter[2].revision - 1n, kind: 1n, status: 2n };
  await assert.rejects(inspect(s, c, r), exact("Mined account digest receipt differs"));
  s.state.minedDigestCell = undefined; await inspect(s, c, r);
});

test("Archive STOP carrier, content metadata and retained actor each fail their own receipt guard", async () => {
  const s = setup(), c = await capture(s); let r = installReceipt(s, c);
  s.state.codes.set(s.state.archive.pointer, `0x01${s.state.archive.bytes.slice(2)}`);
  await assert.rejects(inspect(s, c, r), exact("Archive retained STOP bytes differ"));
  r = installReceipt(s, c); s.state.archive.contentHash = H("wrong content hash");
  await assert.rejects(inspect(s, c, r), exact("Original Archive content metadata differs"));
  r = installReceipt(s, c, "direct", { actor: A(99) });
  await assert.rejects(inspect(s, c, r), exact("Archive operation identity differs"));
  r = installReceipt(s, c); await inspect(s, c, r);
});

test("receipt cannot substitute original calldata, event emitter, or source operation event", async () => {
  const s = setup(), c = await capture(s); let r = installReceipt(s, c);
  s.state.tx.data = `${s.state.tx.data}00`;
  await assert.rejects(inspect(s, c, r), exact("Direct original call differs"));
  r = installReceipt(s, c); s.state.receipt.logs[0].address = s.deployment.registry.address;
  await assert.rejects(inspect(s, c, r), exact("Expected one original CollaboratorAccepted"));
  r = installReceipt(s, c); s.state.receipt.logs.shift();
  await assert.rejects(inspect(s, c, r), exact("Expected one original CollaboratorAccepted"));
  r = installReceipt(s, c); await inspect(s, c, r);
});

test("Safe receipt requires actual original CALL and success after Archive; delegatecall and failure are refused", async () => {
  const s = setup(), c = await capture(s); let r = installReceipt(s, c, "safe");
  const args = Array.from(safeABI.decodeFunctionData("execTransaction", s.state.tx.data)); args[3] = 1n;
  s.state.tx.data = safeABI.encodeFunctionData("execTransaction", args);
  await assert.rejects(inspect(s, c, r), exact("Safe original CALL differs"));
  r = installReceipt(s, c, "safe"); s.state.receipt.logs.pop();
  await assert.rejects(inspect(s, c, r), exact("Expected Safe success without failure"));
  r = installReceipt(s, c, "safe");
  const failure = safeABI.encodeEventLog(safeABI.getEvent("ExecutionFailure"), [H("failed safe hash"), 0n]);
  s.state.receipt.logs.push({ ...s.state.receipt.logs.at(-1), ...failure, index: s.state.receipt.logs.length });
  await assert.rejects(inspect(s, c, r), exact("Expected Safe success without failure"));
  r = installReceipt(s, c, "safe");
  const success = s.state.receipt.logs.pop(); s.state.receipt.logs.unshift(success); s.state.receipt.logs.forEach((v, i) => { v.index = i; });
  await assert.rejects(inspect(s, c, r), exact("Safe success precedes original evidence"));
  r = installReceipt(s, c, "safe"); assert.equal((await inspect(s, c, r)).historicalEvidenceOnly, true);
});
test("workflow function and event shapes match the frozen full compiler witness", () => {
  const declared = new Interface(workflow.CURRENT_ARTIST_COLLABORATOR_WORKFLOW_ABI);
  for (const f of declared.fragments) {
    const original = f.type === "function" ? abi.getFunction(f.format("sighash")) : events.getEvent(f.format("sighash"));
    assert.ok(original, f.format("sighash"));
    assert.equal(f.format("sighash"), original.format("sighash"));
    if (f.type === "function") {
      assert.equal(f.selector, original.selector); assert.equal(f.stateMutability, original.stateMutability);
      assert.deepEqual(f.outputs.map(v => v.format("sighash")), original.outputs.map(v => v.format("sighash")));
    } else {
      assert.equal(f.topicHash, original.topicHash); assert.equal(f.anonymous, original.anonymous);
      assert.deepEqual(f.inputs.map(v => Boolean(v.indexed)), original.inputs.map(v => Boolean(v.indexed)));
    }
  }
  // The fixture helper exposes original ordinary interfaces; nominal library selectors are never RPC endpoints.
  assert.equal(compiledInterfaces.registry.getFunction("acceptCollaborator").selector, declared.getFunction("acceptCollaborator").selector);
});

test("contested status and missing estate activation refuse the own-principal route before coherent restoration", async () => {
  const s = setup(); s.state.authorityStatus = 4n;
  await assert.rejects(capture(s), exact("Collaborator requires its own current ordinary principal"));
  s.state.authorityStatus = 1n; await capture(s);
  s.state.authorityClass = 3n; s.state.authorityStatus = 3n;
  s.state.hooks.push(({ method }) => method === "currentAuthorityCapabilities" ? [{ authorityAddress: s.state.account, authorityClass: 3n, status: 3n, effectiveCapabilities: 0n, activationRecordHash: ZeroHash }] : undefined);
  await assert.rejects(capture(s), exact("Collaborator requires its own current ordinary principal"));
  s.state.hooks.pop(); assert.equal((await capture(s)).row.authority.authorityClass, 3n);
});

test("estate row receipts retain the collaborator authority class in native event and permanent record", async () => {
  for (const authorityClass of [3n, 4n]) {
    const s = setup(); s.state.authorityClass = authorityClass; s.state.authorityStatus = 3n;
    const c = await capture(s), r = installReceipt(s, c, "safe"), result = await inspect(s, c, r);
    assert.equal(result.recordHash, sourceAcceptance(s.state));
    const log = s.state.receipt.logs.find(v => v.topics[0] === events.getEvent("CollaboratorAccepted").topicHash);
    assert.equal(events.decodeEventLog("CollaboratorAccepted", log.data, log.topics).authorityClass, authorityClass);
    rewriteEvent(s.state, "CollaboratorAccepted", values => { values[7] = 1n; });
    await assert.rejects(inspect(s, c, r), exact("CollaboratorAccepted correspondence differs"));
  }
});
test("same collaborator account may accept the exact second ordered role without substituting its first row", async () => {
  const s = setup(), roles = [H("collaborator image role"), H("collaborator audio role")].sort((a, b) => BigInt(a) < BigInt(b) ? -1 : 1);
  s.state.rows = roles.map((role, i) => ({ account: s.state.account, role, shareLabelId: H(`separate role label${i}`),
    collaboratorArtistId: i === 0 ? s.state.artistId : ZeroHash, acceptanceRecordHash: i === 0 ? H("previous same-account first role") : ZeroHash, accepted: i === 0 }));
  Object.assign(s.state.request.terms, { role: s.state.rows[1].role, shareLabelId: s.state.rows[1].shareLabelId }); rebind(s);
  const c = await capture(s);
  assert.equal(c.row.rows[0].account, c.row.rows[1].account); assert.equal(c.row.rows[0].accepted, true); assert.equal(c.row.rows[1].accepted, false);
  assert.equal(c.row.completesIfExecuted, true);
  const r = installReceipt(s, c), observed = await inspect(s, c, r);
  assert.equal(observed.completion.complete, true);
  const log = s.state.receipt.logs.find(v => v.topics[0] === events.getEvent("CollaboratorAccepted").topicHash);
  assert.equal(events.decodeEventLog("CollaboratorAccepted", log.data, log.topics).role, roles[1]);
});