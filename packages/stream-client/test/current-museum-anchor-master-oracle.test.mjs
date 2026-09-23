import test from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { AbiCoder, Interface, ParamType, ZeroAddress, ZeroHash, getAddress, id, keccak256, toUtf8Bytes } from "ethers";
import * as client from "../dist/current-museum-anchor-master.js";
import { createSafeCallPlan, verifySafeCallPlan } from "../dist/safe-plan.js";

const fixture = JSON.parse(readFileSync(new URL("./fixtures/current-museum-anchor-master-abi.json", import.meta.url), "utf8"));
const abi = Object.fromEntries(Object.entries(fixture.abis).map(([key, value]) => [key, new Interface(value)]));
const coder = AbiCoder.defaultAbiCoder();
const hash = (types, values) => keccak256(coder.encode(types, values));
const address = value => getAddress(`0x${BigInt(value).toString(16).padStart(40, "0")}`);
const source = suffix => Object.entries(fixture.sourceTexts).find(([path]) => path.endsWith(`/${suffix}`))[1];
function constant(file, name) {
  const match = source(file).match(new RegExp(`\\b${name}\\s*=\\s*(0x[0-9a-f]{64}|[0-9]+)\\s*;`));
  assert.ok(match, `${file}:${name}`); return match[1].startsWith("0x") ? match[1] : Number(match[1]);
}
function zero(p) {
  if (p.baseType === "tuple") return Object.fromEntries(p.components.map(f => [f.name, zero(f)]));
  if (p.baseType === "array") return p.arrayLength < 0 ? [] : Array.from({ length: p.arrayLength }, () => zero(p.arrayChildren));
  if (p.type === "address") return ZeroAddress;
  if (p.type === "bool") return false;
  if (p.type === "string") return "";
  if (p.type.startsWith("uint")) return 0n;
  return p.type === "bytes" ? "0x" : `0x${"00".repeat(Number(p.type.slice(5)))}`;
}

test("Museum source profile and earlier runtime scope remain separately identified", () => {
  assert.equal(fixture.profile, "museum-anchor-master-v1");
  assert.equal(fixture.sourceCommit, "e558addd5ce1aee15d7ac327482b3822289d3dc7");
  assert.equal(fixture.sourceTree, "22ce31e8d8bcc519989b580214860f85020e9e8a");
  assert.equal(fixture.sourceCount, 2557);
  assert.equal(fixture.inputSha256, "f083e371f3a3e80182194794579338e1bf6d01e44713b78f41fe1af5ceed725d");
  assert.equal(fixture.outputSha256, "4be8ef1f2eec2cebdef60f5dd78756948b4b64de9538edb2b49f672bf7a2bc90");
  assert.equal(Object.keys(fixture.abis).length, 32);
  assert.equal(Object.values(fixture.abis).reduce((n, rows) => n + rows.length, 0), 1087);
  assert.equal(Object.keys(fixture.sourceHashes).length, 189);
  assert.equal(Object.keys(fixture.sourceTexts).length, 66);
  assert.equal(Object.keys(fixture.documents).length, 6);
  for (const [path, text] of Object.entries(fixture.sourceTexts)) {
    assert.equal(createHash("sha256").update(text).digest("hex"), fixture.sourceHashes[path], path);
  }
  assert.equal(fixture.separateRuntimeEvidence.tests, 51);
  assert.deepEqual(fixture.separateRuntimeEvidence.suites, { coreAnchors: 18, conditionCatalog: 12, conservationTier: 21 });
  assert.match(fixture.separateRuntimeEvidence.qualification, /precedes the later Core floor binding/);
  assert.equal(fixture.separateMasterRuntimeEvidence.tests, 47);
  assert.match(fixture.separateMasterRuntimeEvidence.qualification, /excludes later provider/);
});

test("frozen complete interpretation bytes reproduce each original schema/profile/canonicalization pin", () => {
  const definitions = [
    ["schemas/records/STREAM_MEDIA_MASTER_ASSOCIATION_V1.json", "StreamMediaMasterDefinitions.sol", "MASTER_SCHEMA"],
    ["schemas/records/STREAM_MEDIA_MASTER_SELECTED_SLOTS_PROFILE_V1.json", "StreamMediaMasterDefinitions.sol", "PROFILE"],
    ["schemas/records/STREAM_MASTER_WAIVER_V1.json", "StreamMediaMasterDefinitions.sol", "WAIVER_SCHEMA"],
    ["schemas/museum/account-profile/RFC8785_JCS.json", "StreamWorkRecordDefinitions.sol", "CANON"],
  ];
  for (const [path, d] of Object.entries(fixture.documents)) {
    assert.equal(toUtf8Bytes(d.text).length, d.byteLength, path);
    assert.equal(createHash("sha256").update(d.text).digest("hex"), d.sha256, path);
    assert.doesNotThrow(() => JSON.parse(d.text), path);
  }
  for (const [path, file, prefix] of definitions) {
    const document = fixture.documents[path];
    assert.equal(document.byteLength, constant(file, `${prefix}_BYTES`));
    assert.equal(keccak256(toUtf8Bytes(document.text)), constant(file, `${prefix}_HASH`));
  }
});

const child = (type, name) => type.components.find(p => p.name === name);
const recordType = abi.master.getFunction("adoptMaster").inputs[3];
const masterType = abi.master.getFunction("adoptMaster").inputs[4];
const waiverType = abi.master.getFunction("adoptWaiver").inputs[6];
const selectionType = abi.master.getFunction("currentMaster").outputs[0];
const receiptType = abi.recordReceipts.getFunction("collectionRecordReceipt").outputs[0];
const publicationType = abi.artistPublication.getFunction("requireRecordPublication").inputs[1];
const publicationRecordType = abi.publication.getFunction("publicationAttestation").outputs[0];
const configuration = () => ({ chainId: 31337n, core: address(1), executor: address(2), metadata: address(3), masterSelection: address(4), schemaRegistry: address(5), externalCoverage: address(6) });
const anchorCoordinates = c => ({ chainId: c.chainId, core: c.core, executor: c.executor });
function originalMaster(c = configuration(), collectionId = 19n) {
  return { subjectId: hash(["bytes32", "uint256", "address", "uint256"], [id("6529STREAM_SUBJECT_COLLECTION_V1"), c.chainId, c.core, collectionId]), selectedMediaManifestHash: id("manifest"), mediaSlot: 2n, displayHash: id("display"), masterRole: 1n, masterObjectHash: id("master object"), coverageHash: id("original coverage"), predecessor: ZeroHash };
}
function originalWaiver(c = configuration(), collectionId = 19n) {
  const m = originalMaster(c, collectionId);
  return { subjectId: m.subjectId, artist: { artistId: id("artist"), bindingGeneration: (1n << 63n) + 7n, bindingHash: id("binding") }, scopeSubjectId: m.subjectId, mediaObjects: [{ objectId: id("object ID"), mediaClass: 4n, masterRoles: [1n, 0n] }], waiverStatement: { algorithm: 1n, canonicalizationId: id("RFC8785_JCS"), digest: id("statement document"), uri: "ipfs://statement" }, reason: "Artist's original statement — 文 /\n\"", predecessor: ZeroHash };
}
function originalRecord(witness, payloadHash, waiver = false) {
  return { recordType: id(waiver ? "ARTIST_STATEMENT" : "MEDIA_RELATIONSHIP"), subjectId: witness.subjectId, contentHash: { algorithm: 1n, digest: payloadHash, canonicalizationId: id("RFC8785_JCS") }, uri: "ipfs://Original/%2f/é", schemaId: id(waiver ? "STREAM_MASTER_WAIVER_V1" : "STREAM_MEDIA_MASTER_ASSOCIATION_V1"), signatureScheme: ZeroHash, signatureHash: { algorithm: 0n, digest: "0x", canonicalizationId: ZeroHash }, effectiveAt: (1n << 63n) + 1n };
}

test("codecs match complete compiled nested structs, integer widths and field names", () => {
  const pairs = [
    ["MuseumMasterHashRef", child(recordType, "contentHash")], ["MuseumMasterCollectionRecord", recordType],
    ["MuseumMasterReference", child(waiverType, "waiverStatement")], ["MuseumMasterArtist", child(waiverType, "artist")],
    ["MuseumMasterWaivedObject", child(waiverType, "mediaObjects").arrayChildren], ["MuseumMasterWaiver", waiverType],
    ["MuseumMaster", masterType], ["MuseumMasterPublicationEvidence", child(child(selectionType, "original"), "publication")],
    ["MuseumMasterAssociation", child(selectionType, "association")], ["MuseumMasterRecordEvidence", child(selectionType, "original")],
    ["MuseumMasterSelection", selectionType], ["MuseumMasterRecordReceipt", receiptType],
    ["MuseumMasterRecordPolicy", abi.metadata.getFunction("recordPolicy").outputs[0]], ["MuseumMasterPublication", publicationType],
  ];
  for (const [name, type] of pairs) {
    const v = zero(type), encoded = coder.encode([type], [v]);
    assert.equal(client[`encode${name}`](v), encoded, name);
    assert.deepEqual(client[`decode${name}`](encoded), v, name);
    assert.throws(() => client[`decode${name}`](encoded + "00"), name);
    assert.throws(() => client[`encode${name}`]({ ...v, invented: 0n }), name);
  }
  assert.equal(child(child(waiverType, "artist"), "bindingGeneration").type, "uint64");
  assert.equal(child(child(child(selectionType, "original"), "publication"), "requiredCapability").type, "uint32");
  for (const [v, name, type] of [[originalMaster(), "MuseumMaster", masterType], [originalWaiver(), "MuseumMasterWaiver", waiverType]]) {
    assert.equal(client[`encode${name}`](v), coder.encode([type], [v]));
    assert.deepEqual(client[`decode${name}`](coder.encode([type], [v])), v);
  }
});

test("original repository example bytes are reproduced without URI, Unicode or array-order normalization", () => {
  for (const [path, decode, encode] of [
    ["media-master-association.json", client.decodeMuseumMasterCanonical, client.museumMasterCanonical],
    ["master-waiver.json", client.decodeMuseumMasterWaiverCanonical, client.museumMasterWaiverCanonical],
  ]) {
    const document = fixture.documents[`schemas/records/examples/genesis-preservation/${path}`];
    const bytes = `0x${Buffer.from(document.text).toString("hex")}`;
    assert.equal(encode(decode(bytes)).canonical, bytes);
    assert.equal(encode(decode(bytes)).contentHash, keccak256(bytes));
    assert.throws(() => decode(`0x${Buffer.from(document.text + "\n").toString("hex")}`));
  }
  const v = originalWaiver(), p = client.museumMasterWaiverCanonical(v);
  const expected = JSON.stringify({ artist: { artistId: v.artist.artistId, bindingGeneration: v.artist.bindingGeneration.toString(), bindingHash: v.artist.bindingHash }, predecessor: null, reason: v.reason, scope: { mediaObjects: [{ masterRoles: ["PRINT_MASTER", "SOURCE_MASTER"], mediaClass: "interactive_capture", objectId: v.mediaObjects[0].objectId }], subjectId: v.scopeSubjectId }, subjectId: v.subjectId, version: 1, waiverStatement: { hash: { algorithm: 1, canonicalizationId: v.waiverStatement.canonicalizationId, digest: v.waiverStatement.digest }, uri: v.waiverStatement.uri } });
  assert.equal(p.canonical, `0x${Buffer.from(expected).toString("hex")}`);
  assert.deepEqual(client.decodeMuseumMasterWaiverCanonical(p.canonical), v);
  assert.notEqual(client.museumMasterWaiverCanonical({ ...v, mediaObjects: [{ ...v.mediaObjects[0], masterRoles: [0n, 1n] }] }).contentHash, p.contentHash);
});

test("original fourteen-word record and zero-based per-type lane hashes preserve original recorder", () => {
  const c = configuration(), cid = (1n << 240n) + 19n, recorder = address(71), m = originalMaster(c, cid), payload = client.museumMasterCanonical(m), r = originalRecord(m, payload.contentHash);
  const ref = v => hash(["uint16", "bytes32", "bytes32"], [v.algorithm, keccak256(v.digest), v.canonicalizationId]);
  const types = ["bytes32", "uint256", "address", "address", "address", "uint256", "bytes32", "bytes32", "bytes32", "bytes32", "bytes32", "bytes32", "bytes32", "uint64"];
  const recordHash = hash(types, [id("6529stream.preservation-record.v2"), c.chainId, c.metadata, c.core, recorder, cid, r.recordType, r.subjectId, ref(r.contentHash), keccak256(toUtf8Bytes(r.uri)), r.schemaId, r.signatureScheme, ref(r.signatureHash), r.effectiveAt]);
  assert.equal(client.museumMasterRecordHash(c, recorder, cid, r), recordHash);
  assert.notEqual(client.museumMasterRecordHash(c, address(72), cid, r), recordHash);
  for (const [index, previous] of [[0n, ZeroHash], [(1n << 63n) + 1n, id("previous original chain")]]) {
    assert.equal(client.museumMasterRecordChainHash(c, cid, r.recordType, previous, recordHash, index), hash(["bytes32", "uint256", "address", "uint256", "bytes32", "bytes32", "bytes32", "uint64"], [constant("StreamCollectionRecordHashes.sol", "CHAIN_DOMAIN"), c.chainId, c.metadata, cid, r.recordType, previous, recordHash, index]));
  }
});

test("original op24 statement retains full 416 bytes and complete original Publication/Evidence widths", () => {
  const c = configuration(), cid = 19n, recorder = address(71), v = originalWaiver(c, cid), r = originalRecord(v, client.museumMasterWaiverCanonical(v).contentHash, true);
  const recordHash = client.museumMasterRecordHash(c, recorder, cid, r);
  const publication = { metadataHost: c.metadata, recorder, collectionId: cid, subjectId: r.subjectId, recordType: r.recordType, schemaId: r.schemaId, canonicalizationId: r.contentHash.canonicalizationId, payloadAlgorithm: 1n, payloadHash: r.contentHash.digest, uriHash: keccak256(toUtf8Bytes(r.uri)), effectiveAt: r.effectiveAt, candidateRecordHash: recordHash };
  const statement = coder.encode(["uint16", publicationType], [1n, publication]);
  assert.equal((statement.length - 2) / 2, 416);
  assert.equal((coder.encode(["bytes"], [statement]).length - 2) / 2, 480);
  assert.deepEqual(client.museumMasterPublication(c, recorder, cid, r), { publication, statement, statementHash: keccak256(statement) });
  assert.equal((coder.encode([publicationRecordType], [zero(publicationRecordType)]).length - 2) / 2, 704);
  const attestation = abi.attribution.getFunction("attestationRecord").outputs[0];
  assert.equal((coder.encode([attestation], [zero(attestation)]).length - 2) / 2, 224);
  assert.equal((coder.encode([receiptType], [zero(receiptType)]).length - 2) / 2, 288);
});

test("master object, complete selection and occupied-slot facts hashes retain original domains", () => {
  const c = configuration(), cid = 19n, m = originalMaster(c, cid), s = zero(selectionType);
  const objectId = hash(["bytes32", "uint256", "address", "address", "uint256", "bytes32", "bytes32", "uint8", "bytes32"], [id("6529STREAM_MEDIA_MASTER_SLOT_V1"), c.chainId, c.core, c.metadata, cid, m.subjectId, m.selectedMediaManifestHash, 2n, m.displayHash]);
  assert.equal(client.museumMasterCollectionSubject(c.chainId, c.core, cid), m.subjectId);
  assert.equal(client.museumMasterObjectId(c, cid, m.subjectId, m.selectedMediaManifestHash, 2n, m.displayHash), objectId);
  Object.assign(s, { status: 2n, subjectId: m.subjectId, manifestHash: m.selectedMediaManifestHash, mediaSlot: 2n, displayHash: m.displayHash, objectId, masterRole: 1n, revision: 5n, selectionHash: id("ignored self field") });
  Object.assign(s.original, { recordHash: id("waiver record"), recorder: address(71), authorizationClass: 1n, recordIndex: 0n, recordedAt: 400n });
  Object.assign(s.original.publication, { attestationRecordHash: id("op24"), authorityClass: 1n, requiredCapability: 1n, signer: address(71), signedAt: 300n });
  Object.assign(s.association, { artistId: id("artist"), bindingHash: id("binding"), generation: 4n, identityRecordHash: id("identity record") });
  const selectionHash = hash(["bytes32", "uint256", "address", "address", "address", "address", "address", "bytes32", "uint256", selectionType], [id("6529STREAM_MEDIA_MASTER_SELECTION_V1"), c.chainId, c.masterSelection, c.core, c.metadata, c.schemaRegistry, c.externalCoverage, constant("StreamMediaMasterDefinitions.sol", "PROFILE_HASH"), cid, { ...s, selectionHash: ZeroHash }]);
  assert.equal(client.museumMasterSelectionHash(c, cid, s), selectionHash);
  const context = { subjectId: m.subjectId, manifestHash: m.selectedMediaManifestHash, inventoryHash: id("complete native inventory"), occupiedMask: 2n }, displays = [ZeroHash, m.displayHash, ZeroHash];
  const initial = hash(["bytes32", "uint256", "address", "address", "address", "address", "uint256", "bytes32", "bytes32", "bytes32", "bytes32[3]", child(selectionType, "association")], [constant("StreamMediaMasterDefinitions.sol", "PROFILE_HASH"), c.chainId, c.masterSelection, c.core, c.metadata, c.externalCoverage, cid, context.subjectId, context.manifestHash, context.inventoryHash, displays, s.association]);
  assert.equal(client.museumMasterFactsHash(c, cid, context, displays, s.association), initial);
  assert.equal(client.museumMasterAppendFactsHash(initial, 2n, selectionHash, ZeroHash), hash(["bytes32", "uint8", "bytes32", "bytes32"], [initial, 2n, selectionHash, ZeroHash]));
});

test("both permanent anchor transitions and singleton class1 actions reproduce compiled governance", () => {
  const c = configuration(), coordinates = anchorCoordinates(c), candidate = address(90), runtimeCodeHash = id("candidate runtime");
  for (const [kind, family, method] of [["conditionSources", "CONDITION_SOURCES", "bindConditionSources"], ["conservationFloor", "CONSERVATION_FLOOR", "bindConservationFloor"]]) {
    const plan = client.prepareMuseumAnchorBinding(coordinates, { kind, candidate, runtimeCodeHash, previous: { target: ZeroAddress, runtimeCodeHash: ZeroHash } });
    const scope = hash(["bytes32", "uint256", "address"], [id(`6529STREAM_CORE_${family}_SCOPE_V1`), c.chainId, c.core]);
    const state = (target, pin) => hash(["bytes32", "bytes32", "address", "bytes32"], [id(`6529STREAM_CORE_${family}_STATE_V1`), scope, target, pin]);
    assert.deepEqual(plan.transition, { scope, oldHash: state(ZeroAddress, ZeroHash), newHash: state(candidate, runtimeCodeHash) });
    assert.deepEqual(plan.call, { to: c.core, value: 0n, data: abi.core.encodeFunctionData(method, [candidate]) });
    const window = { notBefore: 400000n, expiresAfter: 1100000n, reasonHash: id("reason"), reasonURI: "ipfs://reason", manifestHash: id("manifest") }, nonce = (1n << 230n) + 3n;
    const batch = client.museumAnchorGovernanceBatch(plan, nonce, window), calls = [plan.governanceCall];
    const callsHash = hash(["bytes32", abi.executor.getFunction("scheduleGovernanceBatch").inputs[1]], [constant("StreamGovernanceExecutor.sol", "STREAM_GOVERNANCE_CALLS_V2"), calls]);
    const aggregate = (name, field) => hash(["bytes32", "bytes32", "bytes32[]"], [constant("StreamGovernanceExecutor.sol", name), callsHash, calls.map(call => call[field])]);
    const scopeHash = aggregate("STREAM_GOVERNANCE_BATCH_SCOPE_V2", "scopeHash"), oldHash = aggregate("STREAM_GOVERNANCE_BATCH_OLD_STATE_V2", "oldValueHash"), newHash = aggregate("STREAM_GOVERNANCE_BATCH_NEW_STATE_V2", "newValueHash");
    const actionId = hash(["bytes32", "uint256", "address", "uint8", "bytes32", "bytes32", "bytes32", "bytes32", "uint256", "uint64", "uint64", "bytes32", "bytes32"], [constant("StreamGovernanceExecutor.sol", "STREAM_GOVERNANCE_ACTION_V2"), c.chainId, c.executor, 1n, callsHash, scopeHash, oldHash, newHash, nonce, window.notBefore, window.expiresAfter, window.reasonHash, window.manifestHash]);
    assert.equal(batch.callsHash, callsHash); assert.equal(batch.actionId, actionId);
    for (const [key, name, args] of [["publicationCall", "publishGovernanceCallData", [[plan.call.data]]], ["scheduleCall", "scheduleGovernanceBatch", [1n, calls, scopeHash, oldHash, newHash, window.notBefore, window.expiresAfter, window.reasonHash, window.reasonURI, window.manifestHash]], ["executionCall", "executeGovernanceBatch", [actionId, calls, [plan.call.data]]]]) {
      assert.deepEqual(batch[key], { to: c.executor, value: 0n, data: abi.executor.encodeFunctionData(name, args) });
      const safePlan = createSafeCallPlan(c.chainId, `Museum ${kind}`, [{ safe: address(91), intent: "Execute reviewed permanent binding stage", call: batch[key], abi: fixture.abis.executor }]);
      assert.deepEqual(verifySafeCallPlan(safePlan, [fixture.abis.executor]), safePlan);
      assert.equal(safePlan.steps[0].transaction.operation, 0);
    }
  }
});

test("all five ordinary operations encode original facade/selector ABI with exact original recorder", () => {
  const c = configuration(), cid = 19n, caller = address(70), m = originalMaster(c, cid), w = originalWaiver(c, cid);
  const mr = originalRecord(m, client.museumMasterCanonical(m).contentHash), wr = originalRecord(w, client.museumMasterWaiverCanonical(w).contentHash, true), authorization = id("already recorded original op24");
  const rows = [
    [{ kind: "declareConservationTier", collectionId: cid, tier: id("MUSEUM_GRADE") }, c.metadata, abi.tier, [cid, id("MUSEUM_GRADE")]],
    [{ kind: "recordCollectionRecordWithPayload", collectionId: cid, record: mr, witness: m }, c.metadata, abi.metadata, [cid, mr, client.museumMasterCanonical(m).canonical]],
    [{ kind: "recordArtistCollectionRecordWithPayload", recorder: address(71), collectionId: cid, record: wr, authorization, witness: w }, c.metadata, abi.metadata, [address(71), cid, wr, client.museumMasterWaiverCanonical(w).canonical, authorization]],
    [{ kind: "adoptMaster", collectionId: cid, recordHash: id("master receipt"), expectedRevision: 8n, original: mr, witness: m }, c.masterSelection, abi.master, [cid, id("master receipt"), 8n, mr, m]],
    [{ kind: "adoptWaiver", collectionId: cid, slot: 2n, manifestHash: m.selectedMediaManifestHash, recordHash: id("waiver receipt"), expectedRevision: 9n, original: wr, witness: w }, c.masterSelection, abi.master, [cid, 2n, m.selectedMediaManifestHash, id("waiver receipt"), 9n, wr, w]],
  ];
  for (const [request, target, contract, args] of rows) {
    const p = client.prepareMuseumAnchorMasterCall(c, caller, request);
    assert.deepEqual(p.call, { to: target, value: 0n, data: contract.encodeFunctionData(request.kind, args) });
    assert.equal(p.factsVerified, false);
  }
  assert.deepEqual(client.museumConservationTier(ZeroHash, 0n), { declared: ZeroHash, effective: ZeroHash });
  assert.deepEqual(client.museumConservationTier(ZeroHash, 1n), { declared: ZeroHash, effective: id("MUSEUM_GRADE_LITE") });
  assert.deepEqual(client.museumConservationTier(id("CONSERVATION_WAIVED"), 0n), { declared: id("CONSERVATION_WAIVED"), effective: id("CONSERVATION_WAIVED") });
});

test("pure and workflow ABI fragments match original compiled shapes, widths and indexed topics", () => {
  const workflowSource = readFileSync(new URL("../src/current-museum-anchor-master-workflow.ts", import.meta.url), "utf8");
  const literals = workflowSource.slice(workflowSource.indexOf("const abi = new Interface(["), workflowSource.indexOf("\n]);")).split(/\r?\n/).map(line => line.trim()).filter(line => line.startsWith('"')).map(line => JSON.parse(line.replace(/,$/, "")));
  assert.ok(literals.length > 80);
  for (const fragments of [new Interface(client.CURRENT_MUSEUM_ANCHOR_MASTER_ABI).fragments, new Interface(literals).fragments]) for (const f of fragments) {
    const matches = Object.values(abi).flatMap(a => a.fragments).filter(v => v.type === f.type && v.format("sighash") === f.format("sighash"));
    assert.ok(matches.length, f.format("full"));
    const original = matches.find(v => v.type !== "function" || v.outputs.map(p => p.format("sighash")).join() === f.outputs.map(p => p.format("sighash")).join());
    assert.ok(original, f.format("full"));
    assert.deepEqual(f.inputs.map(p => [p.format("sighash"), !!p.indexed]), original.inputs.map(p => [p.format("sighash"), !!p.indexed]), f.name);
  }
});

test("binding and read interface identities derive only from each original interface's declared selectors", () => {
  for (const [key, name] of [["coreCondition", "MUSEUM_CORE_CONDITION_INTERFACE_ID"], ["coreFloor", "MUSEUM_CORE_FLOOR_INTERFACE_ID"], ["coreTier", "MUSEUM_CORE_TIER_INTERFACE_ID"], ["tier", "MUSEUM_CONSERVATION_TIER_INTERFACE_ID"], ["masterInterface", "MUSEUM_MASTER_SELECTION_INTERFACE_ID"], ["conditionInterface", "MUSEUM_CONDITION_SOURCES_INTERFACE_ID"], ["floorInterface", "MUSEUM_CONSERVATION_FLOOR_INTERFACE_ID"]]) {
    const ownSource = fixture.sourceTexts[fixture.selections[key].source];
    const methods = [...ownSource.matchAll(/\bfunction\s+(\w+)\s*\(/g)].map(m => m[1]);
    assert.ok(methods.length > 0, key);
    const interfaceId = methods.reduce((acc, method) => acc ^ BigInt(abi[key].getFunction(method).selector), 0n);
    assert.equal(client[name], `0x${interfaceId.toString(16).padStart(8, "0")}`, key);
  }
});
