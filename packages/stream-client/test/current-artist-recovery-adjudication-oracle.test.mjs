import test from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { AbiCoder, Interface, ParamType, TypedDataEncoder, ZeroAddress, ZeroHash, concat, getAddress, id, keccak256 } from "ethers";
import * as client from "../dist/current-artist-recovery-adjudication.js";

const fixture = JSON.parse(readFileSync(new URL("./fixtures/current-artist-recovery-adjudication-abi.json", import.meta.url), "utf8"));
const groups = ["evidence", "selection", "recoveryV2", "recovery", "actionOwner", "guardianVesting", "guardianHistory", "dormancy", "identity", "executor"];
const abi = Object.fromEntries(groups.map(k => [k, new Interface(fixture.abis[k])]));
const coder = AbiCoder.defaultAbiCoder(), hash = (types, values) => keccak256(coder.encode(types, values));
const address = n => getAddress(`0x${BigInt(n).toString(16).padStart(40, "0")}`);
const source = name => fixture.sourceTexts[`smart-contracts/domains/artist/${name}.sol`];
const method = abi.recoveryV2.getFunction("recoverArtistIdentityV2");
const requestType = method.inputs[0], authorizationType = method.inputs[1];
const manifestType = abi.evidence.getFunction("publishResolutionManifest").inputs[0];
const appealType = abi.evidence.getFunction("publishAppealV2").inputs[0];
const basisType = abi.selection.getFunction("selectionV2").outputs[0];
const progressType = abi.selection.getFunction("selectionV2").outputs[1];
const contextType = abi.recoveryV2.getFunction("identityRecoveryContextV2").outputs[0];
const recordType = abi.recovery.getFunction("identityRecoveryRecord").outputs[0];
const noticeType = abi.dormancy.getFunction("dormancyRecord").outputs[0];
const terminalType = abi.dormancy.getFunction("dormancyRecord").outputs[2];
const child = (p, name) => p.components.find(c => c.name === name);
function zero(p) {
  if (p.baseType === "tuple") return Object.fromEntries(p.components.map(c => [c.name, zero(c)]));
  if (p.baseType === "array") return p.arrayLength === -1 ? [] : Array.from({ length: p.arrayLength }, () => zero(p.arrayChildren));
  if (p.type === "address") return ZeroAddress;
  if (p.type === "bool") return false;
  if (p.type.startsWith("uint")) return 0n;
  if (p.type === "string") return "";
  return p.type === "bytes" ? "0x" : `0x${"00".repeat(Number(p.type.slice(5)))}`;
}
function sample() {
  const coordinates = { chainId: (1n << 240n) + 1n, registry: address(1), owner: address(2), ownerCodeHash: id("Identity runtime"), coordinator: address(3), archive: address(4), core: address(5), mintManager: address(6), evidencePublisher: address(7), selectionPreparation: address(8) };
  const request = { artistId: id("Artist"), newAddress: address(9), vestedAuthorityClass: 1n, expectedCauseHash: id("cause"), expectedResolutionHash: ZeroHash, evidenceHash: id("resolution evidence"), reasonHash: id("reason"), supersededRecordHashes: [] };
  const acceptance = { nonce: (1n << 230n) + 2n, time: 900000n, signature: "0x123456" };
  const requestCommitment = hash(["bytes32", "uint16", ...requestType.components], [id("6529STREAM_ARTIST_GUARDIAN_APPEAL_REQUEST_V1"), 1n, ...requestType.components.map(p => p.name === "evidenceHash" ? ZeroHash : request[p.name])]);
  const manifest = { artistId: request.artistId, ownerRevision: 77n, causeHash: request.expectedCauseHash, resolutionHash: ZeroHash, executedHead: ZeroHash, basis: 0n, requestCommitment, resolutionEvidenceHash: request.evidenceHash, contestedVestings: [], supersededRecordHashes: [] };
  return { coordinates, request, acceptance, requestCommitment, manifest };
}
function manifestHash(c, m) {
  return hash(["bytes32", "uint16", "uint256", "address", "address", "bytes32", "address", "address", "address", "address", manifestType],
    [id("6529STREAM_ARTIST_RECOVERY_RESOLUTION_MANIFEST_V1"), 1n, c.chainId, c.registry, c.owner, c.ownerCodeHash, c.coordinator, c.archive, c.core, c.mintManager, m]);
}

test("recovery fixture preserves exact producer and separately identified unchanged governance provenance", () => {
  assert.equal(fixture.sourceCommit, "3ac39b556f17e938c5de2b7401429a2f8903ceb3");
  assert.equal(fixture.adjudicationBaseCommit, "674b96f93edafb60d652fc02e0e270f4434377da");
  assert.equal(fixture.sourceCount, 931);
  assert.equal(fixture.inputSha256, "b2a677a4ce978bf20e3eb23ab846fda6f19a1d25626ac58a80384036f3b75844");
  assert.equal(fixture.outputSha256, "bb9700c66af859c912d321acfc1310274134912b883dae0b50b29a43110ecdf9");
  assert.equal(Object.values(fixture.abis).reduce((n, a) => n + a.length, 0), 1346);
  assert.equal(Object.keys(fixture.abis).length, 36); assert.equal(Object.keys(fixture.sourceHashes).length, 378);
  assert.equal(Object.keys(fixture.sourceTexts).length, 67); assert.equal(Object.keys(fixture.governanceWitness.sourceHashes).length, 35);
  for (const [path, text] of Object.entries(fixture.sourceTexts)) assert.equal(createHash("sha256").update(text).digest("hex"), fixture.sourceHashes[path]);
  for (const [path, expected] of Object.entries(fixture.governanceWitness.sourceHashes)) assert.equal(fixture.sourceHashes[path], expected);
  assert.equal(fixture.selections.core.contract, "IStreamCore"); assert.equal(fixture.selections.executor.capture, "governance");
  assert.equal(fixture.selections.registry.capture, "adjudication");
});

test("public recovery codecs retain compiler tuple names, widths, order and dynamic layout", () => {
  const assoc = abi.actionOwner.getFunction("identityRecoveryActionState").outputs[0];
  const vesting = abi.guardianVesting.getFunction("guardianVestingSnapshot").outputs[0];
  const pairs = {
    REQUEST: requestType, AUTHORIZATION: authorizationType, RESOLUTION_MANIFEST: manifestType,
    VESTING_REFERENCE: child(manifestType, "contestedVestings").arrayChildren,
    APPEAL_DOCUMENT: appealType, FINDING: child(appealType, "findings").arrayChildren,
    SELECTION_BASIS: basisType, SELECTION_PROGRESS: progressType,
    SELECTION_RESULT: abi.selection.getFunction("requireSelectionV2").outputs[0],
    HISTORY_HEAD: child(basisType, "history"), HISTORY_SNAPSHOT: abi.guardianHistory.getFunction("guardianHistoryState").outputs[2],
    CONTEXT: contextType, TRANSITION: child(contextType, "abandonedTransition"),
    EVIDENCE_STATE: abi.recoveryV2.getFunction("identityRecoveryEvidenceState").outputs[0],
    ACTION_ASSOCIATION: assoc, ACTION_WITNESS: child(assoc, "action"), GUARDIAN_RECORD: child(assoc, "guardian"),
    RECORD: recordType, RECORD_FIELDS: child(recordType, "fields"), VESTING: vesting,
    NOTICE: noticeType, TERMINAL: terminalType, DORMANCY_PLAN: child(terminalType, "plan"),
    GOVERNANCE_CALL: abi.executor.getFunction("scheduleGovernanceBatch").inputs[1].arrayChildren,
  };
  for (const [name, compiled] of Object.entries(pairs)) {
    const supplied = ParamType.from(client[`ARTIST_RECOVERY_${name}_TUPLE`]);
    assert.equal(supplied.format("sighash"), compiled.format("sighash"), name);
    assert.deepEqual(supplied.components.map(p => p.format("full")), compiled.components.map(p => p.format("full")), name);
  }
});

test("workflow RPC and event fragments are compiler-backed and every literal read has a decoder", () => {
  const workflow = readFileSync(new URL("../src/current-artist-recovery-adjudication-workflow.ts", import.meta.url), "utf8");
  const section = workflow.slice(workflow.indexOf("const abi ="), workflow.indexOf("const coder ="));
  const rows = [...section.matchAll(/^  (".*")[,]?\r?$/gm)].map(match => JSON.parse(match[1]));
  assert.ok(rows.length >= 85);
  const privateAbi = new Interface(rows);
  // The separately retained internal Bootstrap library includes a Solidity contract-type
  // parameter outside the public JSON ABI type system; it is not used for RPC dispatch.
  const compiled = Object.entries(fixture.abis).filter(([key]) => key !== "governanceIdentity")
    .flatMap(([, entries]) => new Interface(entries).fragments);
  for (const fragment of privateAbi.fragments) {
    assert.ok(compiled.some(original => original.format("minimal") === fragment.format("minimal")), fragment.format("minimal"));
  }
  const names = [...workflow.matchAll(/(?:read\(p,[^\n]*?|m\.(?:one|found)\([^\n]*?), "([A-Za-z0-9_]+)"/g)].map(match => match[1]);
  for (const name of new Set(names)) assert.ok(privateAbi.fragments.some(fragment => fragment.name === name), `Missing decoder for ${name}`);
});

test("request and publisher identities preserve distinct environment and evidence commitments", () => {
  const { coordinates: c, request: p, requestCommitment, manifest: m } = sample();
  assert.equal(client.artistRecoveryRequestCommitment(p), requestCommitment);
  assert.equal(client.artistRecoveryRequestCommitment({ ...p, evidenceHash: id("later appeal") }), requestCommitment);
  assert.notEqual(client.artistRecoveryRequestCommitment({ ...p, reasonHash: id("changed reason") }), requestCommitment);
  const mh = manifestHash(c, m);
  assert.equal(client.artistRecoveryResolutionManifestHash(c, m), mh);
  assert.notEqual(client.artistRecoveryResolutionManifestHash({ ...c, ownerCodeHash: id("other runtime") }, m), mh);
  const document = { resolutionManifestHash: mh, hostileFindingsHash: id("findings"), findings: [{ guardianRecordHash: id("guardian"), parties: [address(11), address(12)] }] };
  const ah = hash(["bytes32", "uint16", "uint256", "address", "address", appealType], [id("6529STREAM_ARTIST_HOSTILE_GUARDIAN_EVIDENCE_V2"), 2n, c.chainId, c.registry, c.owner, document]);
  assert.equal(client.artistRecoveryAppealHash(c, document), ah);
  assert.equal(client.artistRecoveryAppealHash({ ...c, ownerCodeHash: id("other runtime") }, document), ah);
  for (const [kind, field, value, target, expected] of [["publishResolutionManifest", "manifest", m, c.evidencePublisher, mh], ["publishAppealV2", "document", document, c.evidencePublisher, ah]]) {
    const call = client.prepareArtistRecoveryAdjudicationCall(c, address(13), { kind, [field]: value });
    assert.deepEqual(call.call, { to: target, value: 0n, data: abi.evidence.encodeFunctionData(kind, [value]) });
    assert.equal(call.expectedReturnHash, expected); assert.equal(call.factsVerified, false);
  }
});

test("guardian result commits the complete original prefix including an authenticated empty election", () => {
  const { coordinates: c, manifest: m } = sample();
  for (const count of [0n, 8n]) {
    const b = { manifestHash: manifestHash(c, m), artistId: m.artistId, ownerCodeHash: c.ownerCodeHash, history: { count, ownerRevision: count ? 19n : 0n, commitment: count ? id("head") : ZeroHash }, sourceCommitment: id("owner source") };
    const p = { processed: count, lastOwnerRevision: b.history.ownerRevision, historyTip: b.history.commitment, excludedSeen: 0n, selectedRecordHash: ZeroHash, selectedDataHash: ZeroHash, selectedNonce: 0n, complete: true };
    const key = hash(["bytes32", "uint256", "address", "address", basisType], [id("6529STREAM_ARTIST_GUARDIAN_SELECTION_SOURCE_V2"), c.chainId, c.registry, c.owner, b]);
    const commitment = hash(["bytes32", "bytes32", basisType, progressType], [id("6529STREAM_ARTIST_GUARDIAN_SELECTION_RESULT_V2"), key, b, p]);
    assert.equal(client.artistRecoverySelectionKey(c, b), key);
    assert.deepEqual(client.artistRecoverySelectionResult(c, b, p), { sourceKey: key, selectedRecordHash: ZeroHash, selectedDataHash: ZeroHash, selectedNonce: 0n, commitment });
    assert.notEqual(commitment, ZeroHash);
    assert.throws(() => client.artistRecoverySelectionResult(c, b, { ...p, complete: false }));
    assert.throws(() => client.artistRecoverySelectionResult(c, b, { ...p, processed: count + 1n }));
  }
});

test("acceptance retains the original literal typehash without reason, manifest or signature-byte substitution", () => {
  const { coordinates: c, request: p, acceptance: a } = sample(), incumbent = address(20);
  const typehash = "0x87eea3b0d5e1275bbdc74e691b4e19a12e9e76b634bac03ae439ae584859ecd0";
  assert.match(source("StreamArtistRotationHashes"), new RegExp(typehash));
  const structHash = hash(["bytes32", "bytes32", "address", "address", "uint256", "uint64"], [typehash, p.artistId, incumbent, p.newAddress, a.nonce, a.time]);
  const domain = TypedDataEncoder.hashDomain({ name: "6529StreamArtistRegistry", version: "1", chainId: c.chainId, verifyingContract: c.registry });
  const expected = keccak256(concat(["0x1901", domain, structHash]));
  assert.equal(client.artistRecoveryAcceptancePayload(c.chainId, c.registry, p, incumbent, a).digest, expected);
  assert.equal(client.artistRecoveryAcceptancePayload(c.chainId, c.registry, { ...p, evidenceHash: id("appeal"), reasonHash: id("other reason") }, incumbent, { ...a, signature: "0x" }).digest, expected);
  assert.notEqual(client.artistRecoveryAcceptancePayload(c.chainId, c.registry, p, incumbent, { ...a, nonce: a.nonce + 1n }).digest, expected);
});

test("original semantic recovery record and sorted supersession domain remain V1", () => {
  const { coordinates: c, request: p } = sample(), records = [id("a"), id("b")].sort();
  const supersededRecordsHash = hash(["bytes32", "bytes32[]"], ["0x0c8573762967a1af597f2a7afc4b655a87b3e22d2b11fbab6cf13c6f7b1396ae", records]);
  const fields = { artistId: p.artistId, oldAddress: address(20), newAddress: p.newAddress, vestedAuthorityClass: 1n, evidenceHash: p.evidenceHash, reasonHash: p.reasonHash, supersededRecordsHash, governanceActionId: id("action"), recoveredAt: (1n << 63n) + 2n };
  assert.equal(client.artistRecoverySupersededRecordsHash(records), supersededRecordsHash);
  assert.equal(client.artistRecoveryRecordHash(c.chainId, c.registry, fields), hash(["bytes32", "uint256", "address", child(recordType, "fields")], ["0x459749364fd07c3a8f1998b82d893d33ef0942c30d94666b42dac1e37ba5feff", c.chainId, c.registry, fields]));
  assert.throws(() => client.artistRecoverySupersededRecordsHash([...records].reverse()));
});

test("class2 singleton governance uses exact V2 calldata and compiler-derived original action identity", () => {
  const { coordinates: c, request: p, acceptance: a, manifest: m } = sample(), executor = address(30), nonce = (1n << 220n) + 3n;
  const scopeHash = hash(["bytes32", "uint256", "address", "address", "bytes32"], [id("6529STREAM_ARTIST_IDENTITY_RECOVERY_SCOPE_V2"), c.chainId, c.registry, c.owner, p.artistId]);
  const x = { ...zero(contextType), scopeHash, oldValueHash: id("authenticated owner context"), causeHash: p.expectedCauseHash, incumbent: address(20) };
  x.newValueHash = hash(["bytes32", "bytes32", "bytes32", requestType, "uint256", "uint64"], [id("6529STREAM_ARTIST_IDENTITY_RECOVERY_INTENT_V2"), scopeHash, x.oldValueHash, p, a.nonce, a.time]);
  const mh = manifestHash(c, m), window = { notBefore: 400000n, expiresAfter: 1100000n, reasonHash: p.reasonHash, reasonURI: "ipfs://recovery", manifestHash: id("governance manifest") };
  const b = client.artistRecoveryGovernanceBatch(c, p, a, mh, x, executor, nonce, window);
  const data = abi.recoveryV2.encodeFunctionData("recoverArtistIdentityV2", [p, a, mh]);
  const calls = [{ target: c.registry, value: 0n, selector: method.selector, callDataHash: keccak256(data), scopeHash, oldValueHash: x.oldValueHash, newValueHash: x.newValueHash }];
  const callsHash = hash(["bytes32", abi.executor.getFunction("scheduleGovernanceBatch").inputs[1]], ["0x10f09566fb70f7947b61639c2a53b3aec872069a8b46edd08ba14eb2b5942b70", calls]);
  const aggregate = (domain, field) => hash(["bytes32", "bytes32", "bytes32[]"], [domain, callsHash, [calls[0][field]]]);
  const identity = { actionClass: 2n, callsHash, scopeHash: aggregate("0x6cfd5dfd67f064adac45602c05057edddda810734779c0ebe11b447e6985e31c", "scopeHash"), oldValueHash: aggregate("0xc5029f937b44065c2ad92d9253e07f06117567480206189fcc1409d5509222b7", "oldValueHash"), newValueHash: aggregate("0xce958009248d20d9574439fa374bc00c142940af2b496896b5bdbc00b882e98b", "newValueHash"), nonce, notBefore: window.notBefore, expiresAfter: window.expiresAfter, reasonHash: window.reasonHash, manifestHash: window.manifestHash };
  const identityType = ParamType.from(fixture.abis.governanceIdentity.find(f => f.name === "governanceActionId").inputs[0]);
  const actionId = hash(["bytes32", "uint256", "address", identityType], ["0x214cd728538bb3775a7106caff5c761bace11866a984d4a4d97a98f51971ac4b", c.chainId, executor, identity]);
  assert.equal(b.actionId, actionId); assert.equal(b.callsHash, callsHash); assert.deepEqual(b.governanceCall, calls[0]);
  assert.deepEqual(b.targetCall, { to: c.registry, value: 0n, data });
  assert.equal(b.executionCall.data, abi.executor.encodeFunctionData("executeGovernanceBatch", [actionId, calls, [data]]));
  assert.notEqual(method.selector, abi.recovery.getFunction("recoverArtistIdentity").selector);
  const reg = client.prepareArtistRecoveryAdjudicationCall(c, address(31), { kind: "registerIdentityRecoveryActionV2", actionId, calls, request: p, acceptance: a, manifestHash: mh });
  assert.equal(reg.call.data, abi.recoveryV2.encodeFunctionData("registerIdentityRecoveryActionV2", [actionId, calls, p, a, mh]));
  client.assertArtistRecoveryRegistrationWindow(a, window, 140800n, 259200n);
  assert.throws(() => client.assertArtistRecoveryRegistrationWindow(a, window, 140801n, 259200n));
});

test("private current-notice facts retain their source shape separately from Archive evidence", () => {
  const notice = { ...zero(noticeType), recordHash: id("notice"), terms: { artistId: id("artist"), evidenceHash: id("opaque evidence"), reasonURI: "ipfs://original-notice" } };
  const terminal = zero(terminalType), facts = { notice, cancellation: terminal, phase: 1n, activity: 99n, proof: id("source proof") };
  const factsType = `tuple(${noticeType.format("full")} notice,${terminalType.format("full")} cancellation,uint8 phase,uint256 activity,bytes32 proof)`;
  const factsValues = [notice, terminal, 1n, 99n, facts.proof], original = id("original context");
  for (const [fn, domain] of [["artistRecoveryCurrentNoticeContextHash", "6529STREAM_ARTIST_RECOVERY_CURRENT_NOTICE_CONTEXT_V1"], ["artistRecoveryCurrentNoticeSourceHash", "6529STREAM_ARTIST_RECOVERY_CURRENT_NOTICE_SOURCE_V1"]]) {
    assert.equal(client[fn](original, facts), hash(["bytes32", "bytes32", factsType], [id(domain), original, factsValues]));
    assert.equal(client[fn](original, { ...facts, notice: zero(noticeType) }), original);
  }
  const c = sample().coordinates;
  const cancel = { ...terminal, noticeHash: notice.recordHash, actor: address(9), authorityClass: 1n, observedAt: 123n };
  assert.equal(client.artistRecoveryCancellationHash(c, cancel, 100n), hash(["bytes32", "uint256", "address", "address", terminalType, "uint256"], [id("6529STREAM_ARTIST_DORMANCY_CANCELLATION_V1"), c.chainId, c.registry, c.owner, cancel, 100n]));
  assert.throws(() => client.artistRecoveryCancellationHash(c, { ...cancel, appointmentBlock: 4n }, 100n));
});

test("operation evidence preserves the original eight-field envelope and distinct preparation commitment", () => {
  const c = sample().coordinates, actor = address(19), association = id("association"), record = id("recovery");
  const snapshotType = "tuple(bytes32 domainId,uint64 revision,bytes32 stateRoot,bytes32 recordChainTip)";
  const snapshots = Array.from({ length: 7 }, () => zero(ParamType.from(snapshotType)));
  snapshots[2] = { domainId: id("identity"), revision: 99n, stateRoot: id("root"), recordChainTip: id("tip") };
  for (const operation of [65534n, 35n]) {
    const commitment = operation === 35n ? record : association;
    const envelope = { schemaVersion: 1n, configurationHash: id("configuration"), operation, actor, primaryRecordHash: operation === 35n ? record : ZeroHash, before: snapshots, after: snapshots, payload: "0x1234" };
    const bytes = coder.encode(["uint16", "bytes32", "uint16", "address", "bytes32", `${snapshotType}[7]`, `${snapshotType}[7]`, "bytes"], Object.values(envelope));
    assert.equal(client.encodeArtistRecoveryOperationEvidence(envelope), bytes);
    assert.deepEqual(client.decodeArtistRecoveryOperationEvidence(bytes), envelope);
    assert.equal(client.artistRecoveryOperationEvidenceId(c, operation, actor, commitment), hash(["bytes32", "uint256", "address", "address", "uint16", "address", "bytes32"], [id("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"), c.chainId, c.registry, c.coordinator, operation, actor, commitment]));
    assert.throws(() => client.decodeArtistRecoveryOperationEvidence(`${bytes}00`));
  }
});
