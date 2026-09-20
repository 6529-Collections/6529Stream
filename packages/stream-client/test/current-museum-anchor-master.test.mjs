import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { AbiCoder, Interface, ParamType, ZeroAddress, ZeroHash, getAddress, hexlify, id, keccak256, toUtf8Bytes, toUtf8String } from "ethers";
import * as m from "../dist/current-museum-anchor-master.js";
const fixture = JSON.parse(readFileSync(new URL("./fixtures/current-museum-anchor-master-abi.json", import.meta.url), "utf8"));
const abi = Object.fromEntries(Object.entries(fixture.abis).map(([k, v]) => [k, new Interface(v)])), coder = AbiCoder.defaultAbiCoder();
const a = n => getAddress(`0x${BigInt(n).toString(16).padStart(40, "0")}`), h = id, utf8 = s => hexlify(toUtf8Bytes(s));
const c = { chainId: (1n << 220n) + 31n, core: a(1), executor: a(2), metadata: a(3), masterSelection: a(4), schemaRegistry: a(5), externalCoverage: a(6) }, anchor = { chainId: c.chainId, core: c.core, executor: c.executor }, cid = (1n << 230n) + 51n;
const subject = m.museumMasterCollectionSubject(c.chainId, c.core, cid);
const master = () => ({ subjectId: subject, selectedMediaManifestHash: h("selected"), mediaSlot: 2n, displayHash: h("display"), masterRole: 1n, masterObjectHash: h("source object"), coverageHash: h("coverage"), predecessor: ZeroHash });
const waiver = () => ({ subjectId: subject, artist: { artistId: h("artist"), bindingGeneration: (1n << 63n) + 9n, bindingHash: h("binding") }, scopeSubjectId: subject, mediaObjects: [{ objectId: m.museumMasterObjectId(c, cid, subject, h("selected"), 2n, h("display")), mediaClass: 1n, masterRoles: [1n, 0n] }], waiverStatement: { algorithm: 4n, canonicalizationId: h("reference canon"), digest: "0x01", uri: "ipfs://statement" }, reason: "Original statement: café 😀\n\t\"\\\u0000", predecessor: ZeroHash });
const binding = kind => m.prepareMuseumAnchorBinding(anchor, { kind, candidate: a(20), runtimeCodeHash: h("source runtime"), previous: { target: ZeroAddress, runtimeCodeHash: ZeroHash } });
function zero(p) { if (p.baseType === "tuple") return Object.fromEntries(p.components.map(x => [x.name, zero(x)])); if (p.baseType === "array") return []; if (p.type === "bool") return false; if (p.type.startsWith("uint")) return 0n; if (p.type === "address") return ZeroAddress; if (p.type === "string") return ""; return p.type === "bytes" ? "0x" : `0x${"00".repeat(Number(p.type.slice(5)))}`; }

test("original master and waiver examples roundtrip exact retained JSON bytes", () => {
  for (const [path, document] of Object.entries(fixture.documents)) {
    if (!path.includes("examples/")) continue;
    const raw = utf8(document.text), isWaiver = path.endsWith("master-waiver.json"), witness = isWaiver ? m.decodeMuseumMasterWaiverCanonical(raw) : m.decodeMuseumMasterCanonical(raw), canonical = isWaiver ? m.museumMasterWaiverCanonical(witness) : m.museumMasterCanonical(witness);
    assert.equal(canonical.canonical, raw); assert.equal(canonical.contentHash, keccak256(raw)); assert.equal(canonical.byteLength, BigInt(document.byteLength));
  }
});

test("public original tuple codecs preserve compiler order, full widths and nested immutable arrays", () => {
  const masterInput = abi.masterInterface.getFunction("adoptMaster").inputs, waiverInput = abi.masterInterface.getFunction("adoptWaiver").inputs, selection = abi.masterInterface.getFunction("currentMaster").outputs[0];
  for (const [name, type, value] of [["MuseumMaster", masterInput[4], master()], ["MuseumMasterWaiver", waiverInput[6], waiver()], ["MuseumMasterSelection", selection, zero(selection)]]) {
    const encoded = coder.encode([type], [value]); assert.equal(m[`encode${name}`](value), encoded); assert.deepEqual(m[`decode${name}`](encoded), value); assert.throws(() => m[`decode${name}`](`${encoded}00`));
  }
  const input = waiver(), snapshot = m.normalizeMuseumMasterWaiver(input); input.mediaObjects[0].masterRoles.reverse(); input.artist.bindingGeneration = 1n; assert.deepEqual(snapshot.mediaObjects[0].masterRoles, [1n, 0n]); assert.notEqual(snapshot.artist.bindingGeneration, 1n); assert.ok(Object.isFrozen(snapshot.mediaObjects[0].masterRoles));
  assert.throws(() => m.normalizeMuseumMasterWaiver({ ...input, profileHash: h("invented") })); assert.throws(() => m.normalizeMuseumMasterWaiver({ ...input, mediaObjects: [, input.mediaObjects[0]] })); assert.throws(() => m.normalizeMuseumMaster({ ...master(), masterRole: 2n })); assert.throws(() => m.normalizeMuseumMaster({ ...master(), mediaSlot: 1 }));
  assert.throws(() => m.normalizeMuseumMasterWaiver({ ...input, artist: { ...input.artist, bindingGeneration: 1n << 64n } }));
});

test("waiver serialization preserves role/object order, decimal strings, Unicode and exact escapes", () => {
  const v = waiver(), p = m.museumMasterWaiverCanonical(v), text = toUtf8String(p.canonical);
  assert.match(text, /"bindingGeneration":"9223372036854775817"/); assert.match(text, /"masterRoles":\["PRINT_MASTER","SOURCE_MASTER"\]/); assert.ok(text.includes("café 😀\\n\\t\\\"\\\\\\u0000")); assert.ok(!text.includes("profileHash")); assert.deepEqual(m.decodeMuseumMasterWaiverCanonical(p.canonical), v);
  const changed = structuredClone(v); changed.mediaObjects[0].masterRoles.reverse(); assert.notEqual(m.museumMasterWaiverCanonical(changed).contentHash, p.contentHash);
  changed.mediaObjects.push({ objectId: h("other object"), mediaClass: 4n, masterRoles: [0n] }); const first = m.museumMasterWaiverCanonical(changed).contentHash; changed.mediaObjects.reverse(); assert.notEqual(m.museumMasterWaiverCanonical(changed).contentHash, first);
  assert.throws(() => m.museumMasterWaiverCanonical({ ...v, reason: "\udc00" })); assert.throws(() => m.museumMasterWaiverCanonical({ ...v, reason: "\ud800" }));
  assert.throws(() => m.decodeMuseumMasterWaiverCanonical(utf8(`${text}\n`))); assert.throws(() => m.decodeMuseumMasterWaiverCanonical(utf8(text.replace('"version":1', '"version":1,"version":1'))));
  assert.throws(() => m.decodeMuseumMasterWaiverCanonical(utf8(text.replace('"bindingGeneration":"9223372036854775817"', '"bindingGeneration":9223372036854775817'))));
});

test("complete escaped payload has exact 8192-byte boundary; witness count is independently bounded", () => {
  const v = waiver(); v.reason = "x"; const base = m.museumMasterWaiverCanonical(v).byteLength; v.reason = "x".repeat(Number(8192n - base + 1n)); assert.equal(m.museumMasterWaiverCanonical(v).byteLength, 8192n); v.reason += "x"; assert.throws(() => m.museumMasterWaiverCanonical(v));
  v.reason = "\u0000".repeat(1500); assert.throws(() => m.museumMasterWaiverCanonical(v)); v.reason = "x";
  assert.throws(() => m.museumMasterWaiverCanonical({ ...v, mediaObjects: [] })); assert.throws(() => m.museumMasterWaiverCanonical({ ...v, mediaObjects: [v.mediaObjects[0], v.mediaObjects[0]] })); assert.throws(() => m.museumMasterWaiverCanonical({ ...v, mediaObjects: [{ ...v.mediaObjects[0], masterRoles: [0n, 0n] }] }));
  assert.throws(() => m.normalizeMuseumMasterWaiver({ ...v, mediaObjects: Array.from({ length: 513 }, () => v.mediaObjects[0]) }));
});

test("reference profile uses source literal URI rules and exact algorithm-dependent digest widths", () => {
  const v = waiver();
  for (const uri of ["https://x", "ipfs://x", "ar://x", "https://μ/path", "ipfs://literal%20escape"]) m.museumMasterWaiverCanonical({ ...v, waiverStatement: { ...v.waiverStatement, uri } });
  for (const uri of ["", "HTTPS://x", "http://x", "https:///x", "https://?x", "https://#x", "ipfs://", "ar://", "https://x x", "https://x\u007f", "https://x\n"]) assert.throws(() => m.museumMasterWaiverCanonical({ ...v, waiverStatement: { ...v.waiverStatement, uri } }));
  for (const algorithm of [1n, 2n, 3n, 6n]) { m.museumMasterWaiverCanonical({ ...v, waiverStatement: { ...v.waiverStatement, algorithm, digest: ZeroHash } }); assert.throws(() => m.museumMasterWaiverCanonical({ ...v, waiverStatement: { ...v.waiverStatement, algorithm, digest: "0x01" } })); }
  for (const algorithm of [4n, 5n]) { m.museumMasterWaiverCanonical({ ...v, waiverStatement: { ...v.waiverStatement, algorithm, digest: `0x${"ab".repeat(128)}` } }); assert.throws(() => m.museumMasterWaiverCanonical({ ...v, waiverStatement: { ...v.waiverStatement, algorithm, digest: `0x${"ab".repeat(129)}` } })); }
});

test("native tier separates undeclared/default/waived and uses completed-ever count only", () => {
  assert.deepEqual(m.museumConservationTier(ZeroHash, 0n), { declared: ZeroHash, effective: ZeroHash }); assert.deepEqual(m.museumConservationTier(ZeroHash, 1n << 240n), { declared: ZeroHash, effective: m.MUSEUM_GRADE_LITE });
  for (const declared of [m.MUSEUM_GRADE, m.MUSEUM_GRADE_LITE, m.MUSEUM_CONSERVATION_WAIVED]) assert.deepEqual(m.museumConservationTier(declared, 0n), { declared, effective: declared });
  assert.throws(() => m.museumConservationTier(h("invented tier"), 0n)); assert.throws(() => m.museumConservationTier(ZeroHash, 1));
  const p = m.prepareMuseumAnchorMasterCall(c, a(30), { kind: "declareConservationTier", collectionId: cid, tier: m.MUSEUM_GRADE }); assert.equal(p.call.to, c.metadata); assert.equal(p.call.data, abi.tier.encodeFunctionData("declareConservationTier", [cid, m.MUSEUM_GRADE])); assert.equal(p.call.value, 0n); assert.equal(p.factsVerified, false);
  assert.throws(() => m.prepareMuseumAnchorMasterCall(c, a(30), { kind: "declareConservationTier", collectionId: cid, tier: ZeroHash })); assert.throws(() => m.prepareMuseumAnchorMasterCall(c, a(30), { kind: "recordConservationTier", collectionId: cid, tier: m.MUSEUM_GRADE }));
});

test("record hash binds original recorder and actual Metadata; op24 statement is complete 416 bytes", () => {
  const w = waiver(), record = m.museumMasterWaiverRecord(w, "ipfs://original", 1n << 62n), signer = a(31), publication = m.museumMasterPublication(c, signer, cid, record);
  assert.equal((publication.statement.length - 2) / 2, 416); assert.equal(publication.publication.metadataHost, c.metadata); assert.equal(publication.publication.recorder, signer); assert.equal(publication.publication.candidateRecordHash, m.museumMasterRecordHash(c, signer, cid, record));
  assert.equal(publication.statementHash, keccak256(coder.encode(["uint16", m.MUSEUM_MASTER_PUBLICATION_TUPLE], [1n, publication.publication])));
  assert.notEqual(m.museumMasterRecordHash(c, a(32), cid, record), publication.publication.candidateRecordHash); assert.notEqual(m.museumMasterRecordHash({ ...c, metadata: a(33) }, signer, cid, record), publication.publication.candidateRecordHash);
  assert.equal(publication.publication.payloadHash, m.museumMasterWaiverCanonical(w).contentHash); assert.equal(record.signatureScheme, ZeroHash); assert.equal(record.signatureHash.digest, "0x");
  assert.throws(() => m.museumMasterPublication(c, signer, cid, { ...record, signatureHash: { ...record.signatureHash, digest: "0x00" } }));
});

test("direct MEDIA publication and detached op24 publication preserve distinct original recorders", () => {
  const witness = master(), record = m.museumMasterRecord(witness, "ipfs://master", 101n), caller = a(30), p = m.prepareMuseumAnchorMasterCall(c, caller, { kind: "recordCollectionRecordWithPayload", collectionId: cid, record, witness });
  assert.equal(p.call.data, abi.metadataInterface.encodeFunctionData("recordCollectionRecordWithPayload", [cid, record, m.museumMasterCanonical(witness).canonical])); assert.equal(p.recordHash, m.museumMasterRecordHash(c, caller, cid, record));
  const waived = waiver(), original = m.museumMasterWaiverRecord(waived, "ipfs://waiver", 102n), recorder = a(31), q = m.prepareMuseumAnchorMasterCall(c, caller, { kind: "recordArtistCollectionRecordWithPayload", recorder, collectionId: cid, record: original, authorization: h("original attestation"), witness: waived });
  assert.equal(q.recordHash, m.museumMasterRecordHash(c, recorder, cid, original)); assert.notEqual(q.recordHash, m.museumMasterRecordHash(c, caller, cid, original)); assert.equal(q.call.data, abi.metadataInterface.encodeFunctionData("recordArtistCollectionRecordWithPayload", [recorder, cid, original, q.payload.canonical, h("original attestation")]));
  assert.throws(() => m.prepareMuseumAnchorMasterCall(c, caller, { ...q.request, authorization: ZeroHash })); assert.throws(() => m.prepareMuseumAnchorMasterCall(c, caller, { ...p.request, record: { ...record, contentHash: { ...record.contentHash, digest: h("not payload") } } }));
});

test("permissionless adoption does not substitute submitter for historical recorder or signature", () => {
  const witness = master(), original = m.museumMasterRecord(witness, "ipfs://master", 10n), request = { kind: "adoptMaster", collectionId: cid, recordHash: h("stored original"), expectedRevision: 2n, original, witness }, p = m.prepareMuseumAnchorMasterCall(c, a(41), request), other = m.prepareMuseumAnchorMasterCall(c, a(42), request);
  assert.equal(p.call.data, other.call.data); assert.notEqual(p.caller, other.caller); assert.equal(p.call.data, abi.masterInterface.encodeFunctionData("adoptMaster", [cid, request.recordHash, 2n, original, witness])); assert.equal(p.call.to, c.masterSelection);
  const waived = waiver(), q = m.prepareMuseumAnchorMasterCall(c, a(43), { kind: "adoptWaiver", collectionId: cid, slot: 2n, manifestHash: h("selected"), recordHash: h("stored waiver"), expectedRevision: 3n, original: m.museumMasterWaiverRecord(waived, "ipfs://waiver", 11n), witness: waived }); assert.equal(q.call.data, abi.masterInterface.encodeFunctionData("adoptWaiver", [cid, 2n, h("selected"), h("stored waiver"), 3n, q.request.original, waived]));
  assert.throws(() => m.prepareMuseumAnchorMasterCall(c, a(41), { ...request, expectedRevision: (1n << 64n) - 1n })); assert.throws(() => m.prepareMuseumAnchorMasterCall(c, a(41), { ...request, collectionId: cid + 1n }));
  witness.coverageHash = h("mutated"); assert.notEqual(p.request.witness.coverageHash, witness.coverageHash); assert.ok(Object.isFrozen(q.request.witness.mediaObjects[0])); assert.deepEqual(m.normalizeMuseumAnchorMasterCall(p), p); assert.throws(() => m.normalizeMuseumAnchorMasterCall({ ...p, caller: a(45), call: { ...p.call, value: 1n } }));
});

test("original selection identity zeroes only itself and retains historical evidence and actual host", () => {
  const selection = zero(abi.masterInterface.getFunction("currentMaster").outputs[0]); Object.assign(selection, { status: 2n, subjectId: subject, manifestHash: h("selected"), mediaSlot: 2n, objectId: h("object"), predecessor: h("prior original"), revision: 7n }); selection.original.recordHash = h("waiver record"); selection.original.authorizationClass = 1n;
  const digest = m.museumMasterSelectionHash(c, cid, selection); selection.selectionHash = digest; assert.equal(m.museumMasterSelectionHash(c, cid, selection), digest);
  assert.notEqual(m.museumMasterSelectionHash(c, cid, { ...selection, predecessor: h("prior selection instead") }), digest); assert.notEqual(m.museumMasterSelectionHash({ ...c, masterSelection: a(50) }, cid, selection), digest);
  const changed = structuredClone(selection); changed.original.publication.signedAt = 1n; assert.notEqual(m.museumMasterSelectionHash(c, cid, changed), digest);
});

test("original conservation facts retain all three slot positions and coverage contributions", () => {
  const context = { subjectId: subject, manifestHash: h("manifest"), inventoryHash: h("inventory"), occupiedMask: 5n }, hashes = [h("slot1"), ZeroHash, h("slot3")], association = { artistId: h("artist"), bindingHash: h("binding"), generation: 10n, identityRecordHash: h("identity") };
  const seed = m.museumMasterFactsHash(c, cid, context, hashes, association), first = m.museumMasterAppendFactsHash(seed, 1n, h("selection1"), h("archive1")), final = m.museumMasterAppendFactsHash(first, 3n, h("selection3"), ZeroHash);
  assert.notEqual(seed, final); assert.notEqual(m.museumMasterFactsHash(c, cid, context, [...hashes].reverse(), association), seed); assert.notEqual(m.museumMasterAppendFactsHash(first, 2n, h("selection3"), ZeroHash), final);
  assert.throws(() => m.museumMasterFactsHash(c, cid, context, hashes.slice(1), association));
});

test("read composers distinguish raw default keys, selected context and fresh closure", () => {
  assert.equal(m.prepareMuseumMasterRead(c, { kind: "declaredConservationTier", collectionId: 0n }).to, c.core);
  assert.equal(m.prepareMuseumMasterRead(c, { kind: "conservationTier", collectionId: cid }).to, c.metadata);
  const raw = m.prepareMuseumMasterRead(c, { kind: "currentMaster", collectionId: 0n, subjectId: ZeroHash, slot: 255n }); assert.equal(raw.data, abi.masterInterface.encodeFunctionData("currentMaster", [0n, ZeroHash, 255n]));
  const fresh = m.prepareMuseumMasterRead(c, { kind: "requireCollectionMasters", collectionId: cid, subjectId: subject }); assert.equal(fresh.data, abi.masterInterface.encodeFunctionData("requireCollectionMasters", [cid, subject]));
  assert.throws(() => m.prepareMuseumMasterRead(c, { kind: "masterSelectionAt", collectionId: cid, subjectId: subject, slot: 2n, revision: 0n }));
  assert.equal(m.prepareMuseumAnchorRead(anchor, { kind: "conservationFloorTransition", candidate: a(20) }).data, abi.coreFloor.encodeFunctionData("conservationFloorTransition", [a(20)]));
});

test("permanent anchors bind distinct original class1 scope/state and cannot be reset", () => {
  const condition = binding("conditionSources"), floor = binding("conservationFloor"); assert.notEqual(condition.transition.scope, floor.transition.scope); assert.notEqual(condition.transition.oldHash, ZeroHash); assert.equal(condition.actionClass, 1n);
  assert.equal(condition.call.data, abi.coreCondition.encodeFunctionData("bindConditionSources", [a(20)])); assert.equal(floor.call.data, abi.coreFloor.encodeFunctionData("bindConservationFloor", [a(20)]));
  assert.equal(condition.coordinates.metadata, undefined); assert.equal(condition.factsVerified, false);
  assert.throws(() => m.prepareMuseumAnchorBinding(anchor, { ...condition.request, previous: { target: a(21), runtimeCodeHash: h("bound") } })); assert.throws(() => m.prepareMuseumAnchorBinding(anchor, { ...condition.request, previous: { target: ZeroAddress, runtimeCodeHash: h("mixed") } })); assert.throws(() => m.prepareMuseumAnchorBinding(anchor, { ...condition.request, runtimeCodeHash: ZeroHash }));
  assert.throws(() => m.normalizeMuseumAnchorBindingPlan({ ...condition, transition: floor.transition }));
});

test("original governance publication/schedule/execute preserves actual Core call and class1 time floors", () => {
  const p = binding("conditionSources"), window = { notBefore: 172900n, expiresAfter: 172900n + 604800n, reasonHash: h("reason"), reasonURI: "ipfs://reason", manifestHash: h("manifest") }, batch = m.museumAnchorGovernanceBatch(p, 1n << 240n, window);
  assert.equal(batch.publicationKey, keccak256(p.governanceCall.callDataHash)); assert.equal(batch.publicationCall.data, abi.executor.encodeFunctionData("publishGovernanceCallData", [[p.call.data]])); assert.equal(batch.executionCall.data, abi.executor.encodeFunctionData("executeGovernanceBatch", [batch.actionId, [p.governanceCall], [p.call.data]])); assert.equal(batch.executionCall.to, c.executor);
  m.assertMuseumAnchorGovernanceWindow(window, 100n); assert.throws(() => m.assertMuseumAnchorGovernanceWindow(window, 101n)); assert.throws(() => m.assertMuseumAnchorGovernanceWindow({ ...window, expiresAfter: window.notBefore + 604799n }, 100n)); assert.throws(() => m.assertMuseumAnchorGovernanceWindow({ ...window, expiresAfter: 31536101n }, 100n));
  window.reasonURI = "changed"; assert.equal(batch.window.reasonURI, "ipfs://reason"); assert.deepEqual(m.normalizeMuseumAnchorGovernanceBatch(batch), batch); assert.throws(() => m.normalizeMuseumAnchorGovernanceBatch({ ...batch, actionId: h("invented") }));
});

test("frozen selectors and tuple names match compiler ABI while paid-floor writers stay excluded", () => {
  const compiled = Object.values(abi).flatMap(i => i.fragments.filter(x => x.type === "function")); for (const f of new Interface(m.CURRENT_MUSEUM_ANCHOR_MASTER_ABI).fragments) assert.ok(compiled.some(x => x.format("full") === f.format("full")), f.format("full"));
  const named = p => p.baseType === "tuple" ? p.components.map(c => [c.name, named(c)]) : p.baseType === "array" ? [p.arrayLength, named(p.arrayChildren)] : p.type;
  assert.deepEqual(named(ParamType.from(m.MUSEUM_MASTER_SELECTION_TUPLE)), named(abi.masterInterface.getFunction("currentMaster").outputs[0]));
  assert.equal(new Interface(m.CURRENT_MUSEUM_ANCHOR_MASTER_ABI).getFunction("recordPrimarySale"), null);
});
