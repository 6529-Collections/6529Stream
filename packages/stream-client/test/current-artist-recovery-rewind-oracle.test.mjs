import test from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { AbiCoder, Interface, ParamType, ZeroAddress, ZeroHash, getAddress, id, keccak256 } from "ethers";
import * as client from "../dist/current-artist-recovery-rewind.js";
import * as original from "../dist/current-artist-recovery-adjudication.js";

const fixture = JSON.parse(readFileSync(new URL("./fixtures/current-artist-recovery-rewind-abi.json", import.meta.url), "utf8"));
const earlier = JSON.parse(readFileSync(new URL("./fixtures/current-artist-recovery-adjudication-abi.json", import.meta.url), "utf8"));
const coder = AbiCoder.defaultAbiCoder(), hash = (types, values) => keccak256(coder.encode(types, values));
const address = n => getAddress(`0x${BigInt(n).toString(16).padStart(40, "0")}`);
const word = n => `0x${BigInt(n).toString(16).padStart(64, "0")}`;
const abi = Object.fromEntries(["registry", "identity", "payout", "recoveryV3", "recoveryOwnerV3", "evidence", "selection", "executor"].map(k => [k, new Interface(fixture.abis[k])]));
const witnessed = new Map();
function collect(value) {
  if (!value || typeof value !== "object") return;
  if (value.internalType?.startsWith("struct StreamArtistRecoveryRewindTypes.")) {
    const name = value.internalType.replace("struct StreamArtistRecoveryRewindTypes.", "").replace(/\[.*$/, "");
    const type = ParamType.from({ ...value, type: "tuple" });
    if (witnessed.has(name)) assert.equal(type.format("sighash"), witnessed.get(name).format("sighash"), `Compiler witnesses disagree: ${name}`);
    else witnessed.set(name, type);
  }
  for (const item of Object.values(value)) if (Array.isArray(item)) item.forEach(collect); else if (item && typeof item === "object") collect(item);
}
Object.values(fixture.abis).forEach(collect);
function zero(p) {
  if (p.baseType === "tuple") return Object.fromEntries(p.components.map(c => [c.name, zero(c)]));
  if (p.baseType === "array") return p.arrayLength === -1 ? [] : Array.from({ length: p.arrayLength }, () => zero(p.arrayChildren));
  if (p.type === "address") return ZeroAddress;
  if (p.type === "bool") return false;
  if (p.type.startsWith("uint")) return 0n;
  if (p.type === "string") return "";
  return p.type === "bytes" ? "0x" : `0x${"00".repeat(Number(p.type.slice(5)))}`;
}
const originalRequest = abi.recoveryV3.getFunction("recoverArtistIdentityV3").inputs[0];
function sample() {
  const environment = { chainId: (1n << 240n) + 5n, registry: address(1), identityOwner: address(2), identityCodeHash: id("Identity runtime"), payoutOwner: address(3), payoutCodeHash: id("Payout runtime"), coordinator: address(4), archive: address(5), core: address(6), manager: address(7) };
  const request = { artistId: id("Artist"), newAddress: address(8), vestedAuthorityClass: 1n, expectedCauseHash: id("cause"), expectedResolutionHash: ZeroHash, evidenceHash: id("resolution evidence"), reasonHash: id("reason"), supersededRecordHashes: [1, 2, 3, 4, 5, 6, 7].map(word) };
  const requestCommitment = hash(["bytes32", "uint16", ...originalRequest.components], [id("6529STREAM_ARTIST_GUARDIAN_APPEAL_REQUEST_V1"), 1n, ...originalRequest.components.map(p => p.name === "evidenceHash" ? ZeroHash : request[p.name])]);
  const identity = { snapshot: { domainId: id("domain:identity_authority"), revision: 7n, stateRoot: id("Identity root"), recordChainTip: id("Identity tip") }, receiptCount: (1n << 80n) + 13n };
  const payout = { snapshot: { domainId: id("domain:payout_lifecycle"), revision: 9n, stateRoot: id("Payout root"), recordChainTip: id("Payout tip") }, receiptCount: (1n << 81n) + 17n };
  const manifest = { ...zero(witnessed.get("ResolutionManifestV3")), artistId: request.artistId, identity, payout, causeHash: request.expectedCauseHash, requestCommitment, resolutionEvidenceHash: request.evidenceHash,
    supersededRecords: request.supersededRecordHashes.map((recordHash, kind) => ({ kind: BigInt(kind), recordHash })) };
  return { environment, request, manifest, identity, payout };
}

test("V3 fixture preserves exact compiler/source provenance and leaves V2 evidence on its original profile", () => {
  assert.equal(fixture.sourceCommit, "898669e5c819ae3ac6c5e7f65159b766fb92d299");
  assert.equal(fixture.sourceTree, "960084faf4eeda849aca6b4837e3d8e2f0732b8f");
  assert.equal(fixture.previousProfileCommit, earlier.sourceCommit);
  assert.equal(earlier.sourceCommit, "3ac39b556f17e938c5de2b7401429a2f8903ceb3");
  assert.equal(fixture.sourceCount, 966); assert.equal(earlier.sourceCount, 931);
  assert.equal(fixture.inputSha256, "9f6ffe9468024b3c3ef506bf3c81aee810fc8f9cff35ca71961fd99ed727a76d");
  assert.equal(fixture.outputSha256, "ab9d3627244361c773798777e2a12f2b3c0bd5db4cfae15d24a96679abb50f91");
  assert.equal(Object.values(fixture.abis).reduce((n, a) => n + a.length, 0), 1523);
  assert.equal(Object.keys(fixture.abis).length, 48); assert.equal(Object.keys(fixture.sourceHashes).length, 429);
  assert.equal(Object.keys(fixture.sourceTexts).length, 101); assert.equal(Object.keys(fixture.governanceWitness.sourceHashes).length, 35);
  for (const [path, text] of Object.entries(fixture.sourceTexts)) assert.equal(createHash("sha256").update(text).digest("hex"), fixture.sourceHashes[path]);
  for (const [path, expected] of Object.entries(fixture.governanceWitness.sourceHashes)) assert.equal(fixture.sourceHashes[path], expected);
  assert.equal(fixture.selections.core.contract, "IStreamCore"); assert.equal(fixture.selections.executor.capture, "governance");
  assert.equal(fixture.selections.evidence.capture, "rewind"); assert.equal(fixture.selections.payout.contract, "StreamArtistPayoutLifecycle");
});

test("all 26 V3 structs preserve recursively named compiler components and original integer widths", () => {
  const aliases = { BasisV3: "SELECTION_BASIS", ProgressV3: "SELECTION_PROGRESS", ResultV3: "SELECTION_RESULT" };
  assert.equal(witnessed.size, 26);
  const names = p => p.baseType === "tuple" ? p.components.map(c => [c.name, names(c)]) : p.baseType === "array" ? [p.arrayLength, names(p.arrayChildren)] : p.type;
  for (const [name, compiled] of witnessed) {
    const constant = aliases[name] ?? name.replace(/V3$/, "").replace(/([a-z])([A-Z])/g, "$1_$2").toUpperCase();
    const supplied = ParamType.from(client[`ARTIST_RECOVERY_REWIND_${constant}_TUPLE`]);
    assert.equal(supplied.format("sighash"), compiled.format("sighash"), name);
    assert.deepEqual(names(supplied), names(compiled), name);
  }
  const { manifest } = sample();
  const encoded = coder.encode([witnessed.get("ResolutionManifestV3")], [manifest]);
  assert.equal(client.encodeArtistRecoveryRewindResolutionManifest(manifest), encoded);
  assert.deepEqual(client.decodeArtistRecoveryRewindResolutionManifest(encoded), manifest);
});

const child = (p, name) => p.components.find(c => c.name === name);
const tuple = p => `tuple(${p.components.map(c => c.format("full")).join(",")})`;
const source = name => {
  const entry = Object.entries(fixture.sourceTexts).find(([path]) => path.endsWith(`/${name}.sol`));
  assert.ok(entry, `Missing retained source ${name}`); return entry[1];
};
function v3(domain, environment, types, values) {
  return hash(["bytes32", "uint16", witnessed.get("EnvironmentV3"), ...types], [id(domain), 3n, environment, ...values]);
}
function coordinates(environment) { return { ...environment, evidencePublisher: address(21), selectionPreparation: address(22) }; }

test("public and private RPC fragments preserve compiler selectors, events and exact result decoders", () => {
  const workflow = readFileSync(new URL("../src/current-artist-recovery-rewind-workflow.ts", import.meta.url), "utf8");
  const section = workflow.slice(workflow.indexOf("const abi ="), workflow.indexOf("const coder ="));
  const rows = [...section.matchAll(/^  (".*")[,]?\r?$/gm)].map(match => JSON.parse(match[1]));
  assert.ok(rows.length >= 100);
  const privateAbi = new Interface(rows), supplied = new Interface(client.CURRENT_ARTIST_RECOVERY_REWIND_ABI);
  const compiled = Object.entries(fixture.abis).filter(([key]) => key !== "governanceIdentity").flatMap(([, entries]) => new Interface(entries).fragments);
  for (const fragment of [...privateAbi.fragments, ...supplied.fragments]) {
    assert.ok(compiled.some(original => original.format("minimal") === fragment.format("minimal")), fragment.format("minimal"));
  }
  const names = [...workflow.matchAll(/(?:read\(p,[^\n]*?|m\.(?:one|found)\([^\n]*?), "([A-Za-z0-9_]+)"/g)].map(match => match[1]);
  for (const name of new Set(names)) assert.ok(privateAbi.fragments.some(fragment => fragment.name === name), `Missing decoder for ${name}`);
  assert.notEqual(abi.recoveryV3.getFunction("identityRecoveryContextV3").selector, abi.recoveryOwnerV3.getFunction("identityRecoveryContextV3").selector);
});

test("V3 publisher identities bind both runtime hashes and retain the original operation-18 record domain", () => {
  const { environment: e, manifest: m, request } = sample(), c = coordinates(e);
  const mh = v3("6529STREAM_ARTIST_RECOVERY_RESOLUTION_MANIFEST_V3", e, [witnessed.get("ResolutionManifestV3")], [m]);
  assert.equal(client.artistRecoveryRewindManifestHash(e, m), mh);
  const appeal = { resolutionManifestHash: mh, hostileFindingsHash: id("hostile findings"), findings: [{ guardianRecordHash: word(1), parties: [address(9), address(10)] }] };
  const ah = v3("6529STREAM_ARTIST_HOSTILE_GUARDIAN_EVIDENCE_V3", e, [witnessed.get("AppealDocumentV3")], [appeal]);
  assert.equal(client.artistRecoveryRewindAppealHash(e, appeal), ah);
  const payout = { recordHash: ZeroHash, terms: { artistId: request.artistId, payoutAccount: address(31), previousDesignationRecordHash: id("predecessor payout") }, signer: address(32), authorityClass: 3n, nonce: (1n << 250n) + 11n, signedAt: (1n << 63n) + 9n };
  const domain = "6529STREAM_ARTIST_PAYOUT_DESIGNATION_RECORD_V1";
  assert.ok(source("StreamArtistHashes").includes(domain));
  payout.recordHash = hash(["bytes32", "uint256", "address", "bytes32", "address", "bytes32", "address", "uint8", "uint256", "uint64"], [id(domain), e.chainId, e.registry, payout.terms.artistId, payout.terms.payoutAccount, payout.terms.previousDesignationRecordHash, payout.signer, payout.authorityClass, payout.nonce, payout.signedAt]);
  const ph = v3("6529STREAM_ARTIST_RECOVERY_PAYOUT_ORIGINAL_V3", e, [witnessed.get("PayoutOriginalV3")], [payout]);
  assert.equal(client.artistRecoveryRewindPayoutRecordHash(e, payout), payout.recordHash);
  assert.equal(client.artistRecoveryRewindPayoutOriginalHash(e, payout), ph);
  for (const field of ["identityCodeHash", "payoutCodeHash"]) {
    const altered = { ...e, [field]: id("different owner runtime") };
    assert.notEqual(client.artistRecoveryRewindManifestHash(altered, m), mh);
    assert.notEqual(client.artistRecoveryRewindAppealHash(altered, appeal), ah);
    assert.notEqual(client.artistRecoveryRewindPayoutOriginalHash(altered, payout), ph);
    assert.equal(client.artistRecoveryRewindPayoutRecordHash(altered, payout), payout.recordHash);
  }
  for (const [kind, field, value, expected] of [["publishResolutionManifestV3", "manifest", m, mh], ["publishAppealV3", "document", appeal, ah], ["publishPayoutOriginalV3", "original", payout, ph]]) {
    const call = client.prepareArtistRecoveryRewindCall(c, address(40), { kind, [field]: value });
    assert.deepEqual(call.call, { to: c.evidencePublisher, value: 0n, data: abi.evidence.encodeFunctionData(kind, [value]) });
    assert.equal(call.expectedReturnHash, expected); assert.equal(call.factsVerified, false);
  }
  assert.throws(() => client.artistRecoveryRewindPayoutOriginalHash(e, { ...payout, nonce: payout.nonce + 1n }));
});

test("selection and seal commitments distinguish complete owner prefixes, inventories and self-hash fields", () => {
  const { environment: e, manifest: m } = sample();
  const basis = { ...zero(witnessed.get("BasisV3")), identity: { ...zero(witnessed.get("IdentityBasisV3")), manifestHash: client.artistRecoveryRewindManifestHash(e, m), artistId: m.artistId, ownerCodeHash: e.identityCodeHash, identity: m.identity, sourceCommitment: id("original Identity source") }, payoutCodeHash: e.payoutCodeHash, payout: m.payout };
  const sourceHash = v3("6529STREAM_ARTIST_RECOVERY_REWIND_SOURCE_V3", e, [witnessed.get("IdentityBasisV3"), "bytes32", witnessed.get("ReceiptPrefix"), witnessed.get("PayoutInventoryV3")], [basis.identity, basis.payoutCodeHash, basis.payout, basis.payoutInventory]);
  basis.sourceCommitment = sourceHash;
  assert.equal(client.artistRecoveryRewindSelectionSourceHash(e, basis), sourceHash);
  assert.equal(client.artistRecoveryRewindSelectionSourceHash(e, { ...basis, sourceCommitment: id("ignored own hash") }), sourceHash);
  const key = v3("6529STREAM_ARTIST_RECOVERY_REWIND_SELECTION_KEY_V3", e, [witnessed.get("BasisV3")], [basis]);
  assert.equal(client.artistRecoveryRewindSelectionKey(e, basis), key);
  assert.notEqual(client.artistRecoveryRewindSelectionKey(e, { ...basis, payout: { ...basis.payout, receiptCount: basis.payout.receiptCount + 1n } }), key);
  const inventory = v3("6529STREAM_ARTIST_RECOVERY_REWIND_INVENTORY_V3", e, [witnessed.get("IdentityInventoryV3"), witnessed.get("PayoutInventoryV3")], [basis.identity.inventory, basis.payoutInventory]);
  assert.equal(client.artistRecoveryRewindSelectionInventoryHash(e, basis.identity.inventory, basis.payoutInventory), inventory);
  const result = { ...zero(witnessed.get("ResultV3")), sourceKey: key, manifestHash: basis.identity.manifestHash, sourceCommitment: sourceHash, inventoryCommitment: inventory, commitment: id("ignored result hash") };
  const rh = v3("6529STREAM_ARTIST_RECOVERY_REWIND_SELECTION_RESULT_V3", e, [witnessed.get("ResultV3")], [{ ...result, commitment: ZeroHash }]);
  assert.equal(client.artistRecoveryRewindSelectionResultHash(e, result), rh);
  assert.notEqual(client.artistRecoveryRewindSelectionResultHash(e, { ...result, payout: { ...result.payout, retainedCandidateRecordHash: id("occupied child") } }), rh);
  const seal = { ...zero(witnessed.get("PreparationSealV3")), manifestHash: basis.identity.manifestHash, sourceKey: key, actionId: id("action"), associationHash: id("association"), identityBefore: m.identity, identityAfterPreparation: { ...m.identity.snapshot, revision: m.identity.snapshot.revision + 1n, stateRoot: id("actual post-preparation root") }, payout: m.payout, evidenceStateHash: id("state"), commitment: id("ignored seal hash") };
  const sh = v3("6529STREAM_ARTIST_RECOVERY_REWIND_PREPARATION_SEAL_V3", e, [witnessed.get("PreparationSealV3")], [{ ...seal, commitment: ZeroHash }]);
  assert.equal(client.artistRecoveryRewindPreparationSealHash(e, seal), sh);
  assert.notEqual(client.artistRecoveryRewindPreparationSealHash(e, { ...seal, identityAfterPreparation: { ...seal.identityAfterPreparation, stateRoot: m.identity.snapshot.stateRoot } }), sh);
});

test("continuations preserve flattened Identity fields and the distinct zeroed Payout tuple", () => {
  const { environment: e, request } = sample();
  for (const [name, domain, own] of [
    ["Revision", "6529STREAM_ARTIST_RECOVERY_REVISION_CONTINUATION_V3", "continuationHash"],
    ["Standing", "6529STREAM_ARTIST_RECOVERY_STANDING_CONTINUATION_V3", "continuationHash"],
    ["Capability", "6529STREAM_ARTIST_RECOVERY_CAPABILITY_CONTINUATION_V3", "commitment"],
    ["Payout", "6529STREAM_ARTIST_RECOVERY_PAYOUT_CONTINUATION_V3", "continuationHash"],
  ]) {
    const type = witnessed.get(`${name}ContinuationV3`), value = { ...zero(type), artistId: request.artistId, recoveryRecordHash: id("original 35"), actionId: id("action"), planCommitment: id("plan"), [own]: id("ignored own hash") };
    const fields = type.components.filter(p => p.name !== own);
    const expected = name === "Payout" ? v3(domain, e, [type], [{ ...value, [own]: ZeroHash }]) : v3(domain, e, fields, fields.map(p => value[p.name]));
    assert.equal(client[`artistRecoveryRewind${name}ContinuationHash`](e, value), expected);
    const wrong = name === "Payout" ? v3(domain, e, fields, fields.map(p => value[p.name])) : v3(domain, e, [type], [{ ...value, [own]: ZeroHash }]);
    assert.notEqual(expected, wrong, `${name} continuation layout`);
  }
});

test("typed exclusions preserve one global order and exact seven-family partition", () => {
  const { request, manifest } = sample();
  assert.deepEqual(client.artistRecoveryRewindPartition(request, manifest.supersededRecords), request.supersededRecordHashes.map(h => [h]));
  assert.throws(() => client.artistRecoveryRewindPartition(request, [...manifest.supersededRecords].reverse()));
  assert.throws(() => client.artistRecoveryRewindPartition(request, manifest.supersededRecords.slice(1)));
  assert.throws(() => client.artistRecoveryRewindPartition(request, manifest.supersededRecords.map((r, i) => i === 0 ? { ...r, kind: 7n } : r)));
  const requestHash = manifest.requestCommitment;
  assert.equal(original.artistRecoveryRequestCommitment(request), requestHash);
  assert.equal(original.artistRecoveryRequestCommitment({ ...request, evidenceHash: id("later appeal document") }), requestHash);
});

test("original class-2 action identity binds exact V3 calldata and Registry context selector", () => {
  const { environment: e, request: p, manifest: m } = sample(), c = coordinates(e), executor = address(30), nonce = (1n << 220n) + 3n;
  const a = { nonce: (1n << 200n) + 5n, time: 1200000n, signature: "0x1234" };
  const method = abi.recoveryV3.getFunction("recoverArtistIdentityV3"), requestType = method.inputs[0];
  const scopeHash = hash(["bytes32", "uint256", "address", "address", "bytes32"], [id("6529STREAM_ARTIST_IDENTITY_RECOVERY_SCOPE_V3"), e.chainId, e.registry, e.identityOwner, p.artistId]);
  const x = { ...zero(abi.recoveryV3.getFunction("identityRecoveryContextV3").outputs[0]), scopeHash, oldValueHash: id("authenticated owner context"), causeHash: p.expectedCauseHash, incumbent: address(20) };
  x.newValueHash = hash(["bytes32", "bytes32", "bytes32", requestType, "uint256", "uint64"], [id("6529STREAM_ARTIST_IDENTITY_RECOVERY_INTENT_V3"), scopeHash, x.oldValueHash, p, a.nonce, a.time]);
  const mh = client.artistRecoveryRewindManifestHash(e, m), window = { notBefore: 400000n, expiresAfter: 1100000n, reasonHash: p.reasonHash, reasonURI: "ipfs://recovery-v3", manifestHash: id("governance manifest") };
  const b = client.artistRecoveryRewindGovernanceBatch(c, p, a, mh, x, executor, nonce, window);
  const data = abi.recoveryV3.encodeFunctionData(method, [p, a, mh]);
  const calls = [{ target: e.registry, value: 0n, selector: method.selector, callDataHash: keccak256(data), scopeHash, oldValueHash: x.oldValueHash, newValueHash: x.newValueHash }];
  const callsHash = hash(["bytes32", abi.executor.getFunction("scheduleGovernanceBatch").inputs[1]], ["0x10f09566fb70f7947b61639c2a53b3aec872069a8b46edd08ba14eb2b5942b70", calls]);
  const aggregate = (domain, field) => hash(["bytes32", "bytes32", "bytes32[]"], [domain, callsHash, [calls[0][field]]]);
  const identity = { actionClass: 2n, callsHash, scopeHash: aggregate("0x6cfd5dfd67f064adac45602c05057edddda810734779c0ebe11b447e6985e31c", "scopeHash"), oldValueHash: aggregate("0xc5029f937b44065c2ad92d9253e07f06117567480206189fcc1409d5509222b7", "oldValueHash"), newValueHash: aggregate("0xce958009248d20d9574439fa374bc00c142940af2b496896b5bdbc00b882e98b", "newValueHash"), nonce, notBefore: window.notBefore, expiresAfter: window.expiresAfter, reasonHash: window.reasonHash, manifestHash: window.manifestHash };
  const identityType = ParamType.from(fixture.abis.governanceIdentity.find(f => f.name === "governanceActionId").inputs[0]);
  const actionId = hash(["bytes32", "uint256", "address", identityType], ["0x214cd728538bb3775a7106caff5c761bace11866a984d4a4d97a98f51971ac4b", e.chainId, executor, identity]);
  assert.equal(b.actionId, actionId); assert.equal(b.callsHash, callsHash); assert.deepEqual(b.governanceCall, calls[0]);
  assert.deepEqual(b.targetCall, { to: e.registry, value: 0n, data });
  assert.equal(b.executionCall.data, abi.executor.encodeFunctionData("executeGovernanceBatch", [actionId, calls, [data]]));
  assert.notEqual(method.selector, new Interface(fixture.abis.recoveryV2).getFunction("recoverArtistIdentityV2").selector);
  const reg = client.prepareArtistRecoveryRewindCall(c, address(31), { kind: "registerIdentityRecoveryActionV3", actionId, calls, request: p, acceptance: a, manifestHash: mh });
  assert.equal(reg.call.data, abi.recoveryV3.encodeFunctionData("registerIdentityRecoveryActionV3", [actionId, calls, p, a, mh]));
});

test("private V3 payloads retain flat arguments and both owner slots in the original Archive envelope", () => {
  const { environment: e, request, identity, payout } = sample();
  const owner = abi.recoveryOwnerV3.getFunction("recoverIdentityV3"), registry = abi.recoveryV3.getFunction("recoverArtistIdentityV3");
  const context = abi.recoveryV3.getFunction("identityRecoveryContextV3").outputs[0];
  const association = new Interface(fixture.abis.actionOwner).getFunction("identityRecoveryActionState").outputs[0];
  const record = new Interface(fixture.abis.recoveryOwner).getFunction("identityRecoveryRecord").outputs[0];
  const appealAuthority = "tuple(address executor,address roles,address root,bytes32 rootCodeHash,uint64 rootRevision,bytes32 roleMutationHash,uint64 roleRevision)";
  const evidence = ParamType.from(`tuple(bytes32 manifestHash,${tuple(witnessed.get("ResolutionManifestV3"))} manifest,${tuple(witnessed.get("AppealDocumentV3"))} appeal,${appealAuthority} appealAuthority,${tuple(witnessed.get("CrossOwnerFactsV3"))} facts)`);
  // Name-preserving compiler tuples are encoded individually; the internal evidence
  // wrapper is source-only and is not presented as an independently compiled ABI.
  const evidenceValue = [ZeroHash, zero(witnessed.get("ResolutionManifestV3")), zero(witnessed.get("AppealDocumentV3")), zero(ParamType.from(appealAuthority)), zero(witnessed.get("CrossOwnerFactsV3"))];
  const preparedType = ["bytes32", registry.inputs[0], registry.inputs[1], context, association, witnessed.get("EvidenceStateV3"), evidence, witnessed.get("PreparationSealV3"), "bytes"];
  const executionType = ["bytes32", registry.inputs[0], registry.inputs[1], owner.inputs[3], owner.inputs[4], context, record, witnessed.get("EvidenceStateV3"), evidence, "bytes32", "bytes", "bytes"];
  const evidenceBytes = coder.encode([evidence], [evidenceValue]);
  const decodedEvidence = client.decodeArtistRecoveryRewindEvidence(evidenceBytes);
  assert.equal(client.encodeArtistRecoveryRewindEvidence(decodedEvidence), evidenceBytes);
  const preparation = { tag: id("6529STREAM_ARTIST_RECOVERY_REWIND_PREPARATION_EVIDENCE_V3"), request, acceptance: zero(registry.inputs[1]), context: zero(context), association: zero(association), state: zero(witnessed.get("EvidenceStateV3")), evidence: decodedEvidence, preparationSeal: zero(witnessed.get("PreparationSealV3")), notice: "0x" };
  const execution = { tag: id("6529STREAM_ARTIST_RECOVERY_REWIND_EXECUTION_EVIDENCE_V3"), request, acceptance: zero(registry.inputs[1]), proof: zero(owner.inputs[3]), governance: zero(owner.inputs[4]), context: zero(context), record: zero(record), state: zero(witnessed.get("EvidenceStateV3")), evidence: decodedEvidence, payoutMutation: id("payout mutation"), noticeBefore: "0x", noticeAfter: "0x" };
  const prepBytes = coder.encode(preparedType, Object.values(preparation).map((v, i) => i === 6 ? evidenceValue : v));
  const execBytes = coder.encode(executionType, Object.values(execution).map((v, i) => i === 8 ? evidenceValue : v));
  assert.equal(client.encodeArtistRecoveryRewindPreparationPayload(preparation), prepBytes);
  assert.equal(client.encodeArtistRecoveryRewindExecutionPayload(execution), execBytes);
  assert.deepEqual(client.decodeArtistRecoveryRewindPreparationPayload(prepBytes), preparation);
  assert.deepEqual(client.decodeArtistRecoveryRewindExecutionPayload(execBytes), execution);
  const snapshotType = child(witnessed.get("ReceiptPrefix"), "snapshot"), snapshots = Array.from({ length: 7 }, () => zero(snapshotType));
  snapshots[2] = identity.snapshot; snapshots[5] = payout.snapshot;
  const actor = address(17);
  for (const [operation, payload] of [[65534n, prepBytes], [35n, execBytes]]) {
    const commitment = id(operation === 35n ? "original recovery" : "preparation association");
    const envelope = { schemaVersion: 1n, configurationHash: id("configuration"), operation, actor, primaryRecordHash: operation === 35n ? commitment : ZeroHash, before: snapshots, after: snapshots, payload };
    const bytes = coder.encode(["uint16", "bytes32", "uint16", "address", "bytes32", `${tuple(snapshotType)}[7]`, `${tuple(snapshotType)}[7]`, "bytes"], Object.values(envelope));
    assert.equal(original.encodeArtistRecoveryOperationEvidence(envelope), bytes);
    assert.deepEqual(original.decodeArtistRecoveryOperationEvidence(bytes), envelope);
    assert.equal(client.artistRecoveryRewindOperationEvidenceId(coordinates(e), operation, actor, commitment), hash(["bytes32", "uint256", "address", "address", "uint16", "address", "bytes32"], [id("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"), e.chainId, e.registry, e.coordinator, operation, actor, commitment]));
  }
});
