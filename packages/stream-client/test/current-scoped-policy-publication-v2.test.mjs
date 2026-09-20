import test from "node:test";
import assert from "node:assert/strict";
import { AbiCoder, ParamType, ZeroAddress, ZeroHash, getAddress, id, keccak256 } from "ethers";
import * as p from "../dist/current-scoped-policy-publication-v2.js";
import * as graph from "../dist/current-scoped-policy-graph-v2.js";
import { fixture, compiledInterfaces } from "./current-scoped-policy-publication-v2-fixture.mjs";

const coder = AbiCoder.defaultAbiCoder();
const H = n => "0x" + BigInt(n).toString(16).padStart(64, "0");
const A = n => getAddress("0x" + BigInt(n).toString(16).padStart(40, "0"));
const c = { chainId: (1n << 170n) + 6529n, core: A(1), metadata: A(2), checkpoint: A(3), output: A(4), snapshot: A(5) };
const scope = { scopeType: 2n, collectionId: (1n << 190n) + 2n, tokenId: 0n, scopeId: H(7) };
const hash = (types, values) => keccak256(coder.encode(types, values));

function zero(type) {
  const t = typeof type === "string" ? ParamType.from(type) : type;
  if (t.baseType === "tuple") return Object.fromEntries(t.components.map(v => [v.name, zero(v)]));
  if (t.baseType === "array") return Array.from({ length: t.arrayLength < 0 ? 0 : t.arrayLength }, () => zero(t.arrayChildren));
  if (t.type === "address") return ZeroAddress;
  if (t.type === "bool") return false;
  if (t.type === "string") return "";
  if (t.type.startsWith("bytes")) return "0x" + "00".repeat(t.type === "bytes" ? 0 : Number(t.type.slice(5)));
  return 0n;
}

function output(tokenId, mode = "finalized") {
  return {
    leaf: { tokenId, metadataHash: H(10), imageHash: ZeroHash, animationHash: H(11), contentHash: ZeroHash, tokenDataHash: H(12) },
    selectionRowHash: H(13), sourceFactsHash: H(14), htmlHash: H(11),
    entropy: { coordinator: A(20), coordinatorCodeHash: H(20), policyHash: H(21), status: mode === "disabled" ? 1n : mode === "notRequired" ? 2n : 5n,
      mode: mode === "disabled" ? 0n : 2n, securityClass: 1n, renderRequirement: mode === "finalized" ? 0n : 1n,
      terminal: mode !== "finalized", finalized: mode === "finalized", seed: ZeroHash },
    terminalAdmissionHash: mode === "finalized" ? ZeroHash : H(22),
  };
}

function vector() {
  const rows = [output(1n, "disabled"), output(2n, "notRequired"), output(3n)];
  const selected = { scope, membershipHash: H(30), collectionStateHash: H(31), tokenCount: 3n, nextIndex: 3n, selectionRoot: H(32) };
  const identity = { selectionCheckpoint: A(6), selectionId: H(33), selection: selected, entropySourceSet: A(10),
    entropySourceSetCodeHash: H(34), terminalReadiness: A(11), terminalReadinessCodeHash: H(35), inventoryHash: H(36), policyChainHash: H(37), salt: ZeroHash };
  let leafChainHash = ZeroHash, outputRoot = ZeroHash;
  rows.forEach((row, i) => {
    leafChainHash = p.scopedPolicyPublicationV2LeafChain(leafChainHash, BigInt(i), p.scopedPolicyPublicationV2LeafHash(c.chainId, c.core, row.leaf));
    outputRoot = p.scopedPolicyPublicationV2OutputChain(outputRoot, BigInt(i), row);
  });
  const content = { ...p.scopedPolicyPublicationV2InitialContentPlan(identity), nextIndex: 3n, leafChainHash,
    outputRoot, contentRoot: p.scopedPolicyPublicationV2ContentRoot(c.chainId, c.core, rows.map(row => row.leaf)) };
  const checkpointHash = p.scopedPolicyPublicationV2CheckpointId(c, identity);
  const raw = p.scopedPolicyPublicationV2OutputManifestBytes(c, checkpointHash, content, A(10), rows);
  const coverage = { completionHash: H(40), artifactHash: H(41), artistId: H(42), schemaId: p.SCOPED_POLICY_PUBLICATION_V2_OUTPUT_SCHEMA,
    canonicalizationId: p.SCOPED_POLICY_PUBLICATION_V2_OUTPUT_CANONICALIZATION, contentHash: keccak256(raw), byteLength: BigInt((raw.length - 2) / 2),
    chunkCount: 1n, firstFamilyRecordHash: H(43), secondFamilyRecordHash: H(44), validationEpoch: 2n, evidenceChainHash: H(45) };
  const manifest = p.scopedPolicyPublicationV2Manifest(c, checkpointHash, content, A(10), coverage);
  const dependencies = { targets: [c.core, c.metadata, A(12), A(13), A(14), A(15), A(6), c.checkpoint, c.output, A(16), A(10)],
    codeHashes: Array.from({ length: 11 }, (_, i) => H(50 + i)), chainId: c.chainId, readGas: 50000n, sourceGas: 100000n, inventoryGas: 150000n };
  const policy = { ...zero(graph.SCOPED_POLICY_GRAPH_V2_COORDINATOR_POLICY_TUPLE), coordinator: A(20), indexedCodeHash: H(20),
    policyHash: H(21), componentDataHash: H(63), frozen: true };
  const source = { scope, membership: { ...zero(graph.SCOPED_POLICY_GRAPH_V2_MEMBERSHIP_TUPLE),
      scopeSubject: graph.scopedPolicyGraphV2ScopeSubject(c.chainId, c.core, scope), membershipHash: selected.membershipHash, tokenCount: 3n },
    artist: { locked: true, registry: A(30), registryCodeHash: H(70), artistId: coverage.artistId, bindingGeneration: 1n, bindingHash: H(71),
      nominatedArtist: A(31), identityRecordHash: H(72), acceptanceRecordHash: H(73), acceptedAt: 9n, lockedAt: 10n, snapshotHash: H(74) },
    selection: selected, content, outputs: manifest, sourceFactory: A(32), sourceFactoryCodeHash: H(75), factoryDependenciesHash: H(76),
    entropy: { planId: H(77), inventoryHash: content.inventoryHash, policyChainHash: content.policyChainHash, policyCount: 1n, allFrozen: true, policies: [policy] } };
  const publication = { scope, snapshotId: H(80), expectedHead: ZeroHash, expectedRevision: 0n,
    outputManifestRecord: p.scopedPolicyPublicationV2ManifestRecordHash(p.scopedPolicyPublicationV2ManifestPlanHash(c, A(16), manifest)),
    coordinatorInventoryPlan: source.entropy.planId, expectedSourceHash: p.scopedPolicyPublicationV2SourceHash(c, dependencies, source),
    manifestURI: "ipfs://original-document", effectiveAt: 15n, reasonHash: H(81) };
  const receipt = p.scopedPolicyPublicationV2PreviewReceipt(c, publication, A(100), {
    authorizationClass: 7n, grantRevision: 3n, displayAuthorizationClass: 8n, displayGrantRevision: 9n,
  }, publication.expectedSourceHash);
  return { rows, selected, identity, content, checkpointHash, raw, coverage, manifest, dependencies, source, publication, receipt };
}

test("structural codecs retain canonical empty getters and reject noncanonical transport", () => {
  for (const name of ["ContentPlan", "OutputPlan", "Receipt", "Lock", "Source", "TerminalEvidence"]) {
    const key = name.replace(/[A-Z]/g, (s, i) => (i ? "_" : "") + s).toUpperCase();
    const value = zero(p[`SCOPED_POLICY_PUBLICATION_V2_${key}_TUPLE`]);
    const raw = p[`encodeScopedPolicyPublicationV2${name}`](value);
    assert.deepEqual(p[`decodeScopedPolicyPublicationV2${name}`](raw), value);
    assert.throws(() => p[`decodeScopedPolicyPublicationV2${name}`](raw + "00"));
  }
  const r = output(1n);
  const raw = p.encodeScopedPolicyPublicationV2Output(r);
  const dirtyBool = raw.slice(0, 2 + 17 * 64) + H(2).slice(2) + raw.slice(2 + 18 * 64);
  assert.throws(() => p.decodeScopedPolicyPublicationV2Output(dirtyBool));
  assert.throws(() => p.normalizeScopedPolicyPublicationV2Output({ ...r, extra: true }));
  assert.throws(() => p.normalizeScopedPolicyPublicationV2Publication({ ...vector().publication, effectiveAt: 1 }));
});

test("checkpoint supplied identity preserves salt zero, full uints and complete Selection", () => {
  const v = vector();
  assert.equal(p.scopedPolicyPublicationV2InitialContentPlan(v.identity).nextIndex, 0n);
  assert.notEqual(p.scopedPolicyPublicationV2CheckpointId(c, { ...v.identity, salt: H(1) }), v.checkpointHash);
  assert.throws(() => p.scopedPolicyPublicationV2InitialContentPlan({ ...v.identity, unexpected: 1 }));
  assert.throws(() => p.scopedPolicyPublicationV2InitialContentPlan({ ...v.identity, selection: { ...v.selected, nextIndex: 2n } }));
  for (const scopeType of [0n, 4n]) assert.throws(() => p.scopedPolicyPublicationV2InitialContentPlan({ ...v.identity,
    selection: { ...v.selected, scope: { ...scope, scopeType } } }));
});

test("terminal states stay distinct from real finalized seed including valid zero", () => {
  for (const mode of ["disabled", "notRequired", "finalized"]) assert.deepEqual(p.validateScopedPolicyPublicationV2Output(output(1n, mode)), output(1n, mode));
  const terminal = output(1n, "notRequired"), finalized = output(1n);
  for (const entropy of [{ ...terminal.entropy, finalized: true }, { ...terminal.entropy, seed: H(1) },
    { ...terminal.entropy, mode: 1n }, { ...terminal.entropy, status: 5n }]) {
    assert.throws(() => p.validateScopedPolicyPublicationV2Output({ ...terminal, entropy }));
  }
  assert.throws(() => p.validateScopedPolicyPublicationV2Output({ ...finalized, terminalAdmissionHash: H(1) }));
  assert.throws(() => p.validateScopedPolicyPublicationV2Output({ ...terminal, htmlHash: H(99) }));
});

test("ordered content tree promotes an odd leaf unchanged and rejects duplicate or reversed tokens", () => {
  const leaves = vector().rows.map(row => row.leaf);
  const hashes = leaves.map(leaf => p.scopedPolicyPublicationV2LeafHash(c.chainId, c.core, leaf));
  const expected = p.scopedPolicyPublicationV2NodeHash(p.scopedPolicyPublicationV2NodeHash(hashes[0], hashes[1]), hashes[2]);
  assert.equal(p.scopedPolicyPublicationV2ContentRoot(c.chainId, c.core, leaves), expected);
  assert.throws(() => p.scopedPolicyPublicationV2ContentRoot(c.chainId, c.core, [leaves[0], leaves[0]]));
  assert.throws(() => p.scopedPolicyPublicationV2ContentRoot(c.chainId, c.core, [...leaves].reverse()));
});

test("output archive is flat, ordered and cannot substitute a supplied root or incomplete coverage", () => {
  const v = vector();
  assert.equal((v.raw.length - 2) / 2, 576 + 640 * 3);
  assert.equal(BigInt("0x" + v.raw.slice(2 + 16 * 64, 2 + 17 * 64)), 544n);
  assert.deepEqual(p.decodeScopedPolicyPublicationV2OutputManifestBytes(v.raw).rows, v.rows);
  assert.throws(() => p.decodeScopedPolicyPublicationV2OutputManifestBytes(v.raw + "00"));
  assert.throws(() => p.scopedPolicyPublicationV2OutputManifestBytes(c, v.checkpointHash, { ...v.content, leafChainHash: H(99) }, A(10), v.rows));
  assert.throws(() => p.scopedPolicyPublicationV2Manifest(c, v.checkpointHash, v.content, A(10), { ...v.coverage, chunkCount: 2n }));
  assert.throws(() => p.scopedPolicyPublicationV2Manifest(c, v.checkpointHash, v.content, A(10), { ...v.coverage, secondFamilyRecordHash: v.coverage.firstFamilyRecordHash }));
  assert.throws(() => p.scopedPolicyPublicationV2Manifest(c, v.checkpointHash, { ...v.content, tokenCount: 819n, nextIndex: 819n }, A(10), v.coverage));
});

test("tuple-visible snapshot joins bind deterministic output record and locked presentation", () => {
  const v = vector();
  assert.deepEqual(p.validateScopedPolicyPublicationV2Source(c, v.dependencies, v.publication, v.source), v.source);
  assert.throws(() => p.validateScopedPolicyPublicationV2Source(c, v.dependencies, { ...v.publication, outputManifestRecord: H(999) }, v.source));
  assert.throws(() => p.validateScopedPolicyPublicationV2Source(c, v.dependencies, v.publication, { ...v.source, artist: { ...v.source.artist, locked: false } }));
  assert.throws(() => p.validateScopedPolicyPublicationV2Source(c, v.dependencies, v.publication, { ...v.source, entropy: { ...v.source.entropy, policyCount: 2n } }));
  const changed = { ...v.source, outputs: { ...v.manifest, artifactHash: H(999) } };
  assert.throws(() => p.validateScopedPolicyPublicationV2Source(c, v.dependencies, v.publication, changed));
  const linked = { ...v.publication, outputManifestRecord: p.scopedPolicyPublicationV2ManifestRecordHash(p.scopedPolicyPublicationV2ManifestPlanHash(c, A(16), changed.outputs)) };
  assert.deepEqual(p.validateScopedPolicyPublicationV2Source(c, v.dependencies, linked, changed), changed);
});

test("snapshot canonical bytes clear exactly original fields and bind every retained authority fact", () => {
  const v = vector();
  const canonical = p.scopedPolicyPublicationV2SnapshotBytes(c, v.dependencies, v.publication, v.receipt, v.source);
  const decoded = p.decodeScopedPolicyPublicationV2SnapshotBytes(canonical);
  assert.equal(decoded.publication.expectedSourceHash, ZeroHash);
  assert.equal(decoded.receipt.sourceHash, v.publication.expectedSourceHash);
  for (const key of ["recordHash", "chainHash", "manifestHash"]) assert.equal(decoded.receipt[key], ZeroHash);
  assert.equal(decoded.receipt.manifestBytes, 0n);
  assert.equal(decoded.receipt.recordedAt, 0n);
  const completed = { ...v.receipt, recordHash: H(1), chainHash: H(2), manifestHash: H(3), manifestBytes: 7n, recordedAt: 50n };
  assert.equal(p.scopedPolicyPublicationV2SnapshotBytes(c, v.dependencies, v.publication, completed, v.source), canonical);
  assert.notEqual(p.scopedPolicyPublicationV2SnapshotBytes(c, v.dependencies, v.publication, { ...v.receipt, grantRevision: 4n }, v.source), canonical);
  assert.throws(() => p.decodeScopedPolicyPublicationV2SnapshotBytes(canonical + "00"));
  assert.notEqual(p.scopedPolicyPublicationV2SourceHash({ ...c, snapshot: A(999) }, v.dependencies, v.source), v.publication.expectedSourceHash);
  assert.equal(p.scopedPolicyPublicationV2SourceHash(c, { ...v.dependencies, sourceGas: 999999n }, v.source), v.publication.expectedSourceHash);
});

test("mined snapshot identity retains actual expected hash and timestamp while clearing its own hash slots", () => {
  const v = vector();
  const canonical = p.scopedPolicyPublicationV2SnapshotBytes(c, v.dependencies, v.publication, v.receipt, v.source);
  const mined = { ...v.receipt, manifestHash: keccak256(canonical), manifestBytes: BigInt((canonical.length - 2) / 2), recordedAt: 99n };
  const record = p.scopedPolicyPublicationV2SnapshotRecordHash(c, v.publication, mined);
  assert.equal(p.scopedPolicyPublicationV2SnapshotRecordHash(c, v.publication, { ...mined, recordHash: H(4), chainHash: H(5) }), record);
  assert.notEqual(p.scopedPolicyPublicationV2SnapshotRecordHash(c, { ...v.publication, expectedSourceHash: H(6) }, mined), record);
  assert.notEqual(p.scopedPolicyPublicationV2SnapshotRecordHash(c, v.publication, { ...mined, recordedAt: 100n }), record);
  assert.notEqual(p.scopedPolicyPublicationV2SnapshotChainHash(c, scope, ZeroHash, 1n, record),
    p.scopedPolicyPublicationV2SnapshotChainHash(c, scope, H(1), 1n, record));
});

test("snapshot complete envelope and existing Store chunks obey separate bounds", () => {
  const v = vector();
  const many = { ...v.source, entropy: { ...v.source.entropy, policies: Array(631).fill(v.source.entropy.policies[0]) } };
  assert.throws(() => p.scopedPolicyPublicationV2SnapshotBytes(c, v.dependencies, v.publication, v.receipt, many));
  const raw = "0x" + "ab".repeat(8193);
  const chunks = p.scopedPolicyPublicationV2Chunks(raw);
  assert.deepEqual(chunks.map(row => row.byteLength), [8192n, 1n]);
  assert.equal(chunks[1].runtime, "0x00ab");
  assert.equal(chunks[1].runtimeHash, keccak256("0x00ab"));
  assert.equal(p.scopedPolicyPublicationV2Chunks("0x" + "aa".repeat(524288)).length, 64);
  assert.throws(() => p.scopedPolicyPublicationV2Chunks("0x" + "aa".repeat(524289)));
  assert.throws(() => p.scopedPolicyPublicationV2Chunks("0x"));
  assert.ok(Object.isFrozen(chunks) && Object.isFrozen(chunks[0]));
});

test("five writes preserve original compiler calldata, actual caller, CALL0 and mutation reconstruction", () => {
  const v = vector();
  const requests = [
    ["checkpoint", { kind: "begin", selectionId: H(1), salt: ZeroHash }, [H(1), ZeroHash]],
    ["checkpoint", { kind: "append", id: H(1), payloads: [{ tokenId: 1n, image: "0x", animation: "0x6162" }] }, [H(1), [{ tokenId: 1n, image: "0x", animation: "0x6162" }]]],
    ["output", { kind: "beginManifest", checkpointHash: H(1), artifactHash: H(2), coverageHash: H(3), artistId: H(4) }, [H(1), H(2), H(3), H(4)]],
    ["output", { kind: "verifyNextOutputs", planHash: H(1), count: 16n }, [H(1), 16n]],
    ["snapshot", { kind: "publishSnapshot", publication: v.publication }, [v.publication]],
  ];
  for (const [host, request, args] of requests) {
    const plan = p.prepareScopedPolicyPublicationV2Call(c, A(100), request);
    assert.deepEqual(plan.call, { to: c[host], value: 0n, data: compiledInterfaces[host].encodeFunctionData(request.kind, args) });
    assert.equal(plan.caller, A(100)); assert.equal(plan.factsVerified, false);
    assert.deepEqual(p.normalizeScopedPolicyPublicationV2Call(plan), plan);
    assert.throws(() => p.normalizeScopedPolicyPublicationV2Call({ ...plan, call: { ...plan.call, value: 1n } }));
    assert.throws(() => p.normalizeScopedPolicyPublicationV2Call({ ...plan, call: { ...plan.call, data: plan.call.data + "00" } }));
    assert.throws(() => p.normalizeScopedPolicyPublicationV2Call({ ...plan, factsVerified: true }));
  }
  const rows = [{ tokenId: 1n, image: "0x", animation: "0x6162" }];
  const plan = p.prepareScopedPolicyPublicationV2Call(c, A(100), { kind: "append", id: H(1), payloads: rows });
  rows[0].animation = "0x63"; rows.push(rows[0]);
  assert.equal(plan.request.payloads.length, 1); assert.equal(plan.request.payloads[0].animation, "0x6162");
  assert.ok(Object.isFrozen(plan.request.payloads[0]));
});

test("finite write limits reject empty/oversized rows, sparse arrays and excluded authority methods", () => {
  const payload = { tokenId: 1n, image: "0x", animation: "0x01" };
  for (const payloads of [[], Array(5).fill(payload), [undefined], new Array(1)]) {
    assert.throws(() => p.prepareScopedPolicyPublicationV2Call(c, A(100), { kind: "append", id: H(1), payloads }));
  }
  for (const changed of [{ animation: "0x" }, { image: "0x" + "aa".repeat(2049) }, { animation: "0x" + "aa".repeat(16777217) }]) {
    assert.throws(() => p.prepareScopedPolicyPublicationV2Call(c, A(100), { kind: "append", id: H(1), payloads: [{ ...payload, ...changed }] }));
  }
  for (const count of [0n, 17n, 1]) assert.throws(() => p.prepareScopedPolicyPublicationV2Call(c, A(100), { kind: "verifyNextOutputs", planHash: H(1), count }));
  for (const kind of ["lockSnapshot", "raiseGasParameter", "adoptContentRoot", "publishReference"]) {
    assert.throws(() => p.prepareScopedPolicyPublicationV2Call(c, A(100), { kind }));
  }
});

test("preview-only source sentinel and URI grammar preserve original source distinction", () => {
  const v = vector();
  const draft = { ...v.publication, expectedSourceHash: ZeroHash };
  const read = p.prepareScopedPolicyPublicationV2Read(c, ZeroAddress, { host: "snapshot", kind: "previewSnapshot", publication: draft, publisher: A(100) });
  assert.equal(read.call.data, compiledInterfaces.snapshot.encodeFunctionData("previewSnapshot", [draft, A(100)]));
  assert.throws(() => p.prepareScopedPolicyPublicationV2Call(c, A(100), { kind: "publishSnapshot", publication: draft }));
  for (const manifestURI of ["", "https://x/?é", "ipfs://x", "ar://x"]) {
    assert.equal(p.validateScopedPolicyPublicationV2Publication({ ...v.publication, manifestURI }).manifestURI, manifestURI);
  }
  for (const manifestURI of ["HTTPS://x", "https:///x", "https://?x", "ipfs://", "ar://", "https://x/a b", "https://x/\u007f", "https://x/\ud800", "ipfs://" + "x".repeat(2042)]) {
    assert.throws(() => p.validateScopedPolicyPublicationV2Publication({ ...v.publication, manifestURI }));
  }
});

test("closed reads preserve unknown record lookups without exposing excluded mutations", () => {
  const requests = [
    { host: "checkpoint", kind: "checkpoint", id: ZeroHash },
    { host: "checkpoint", kind: "outputAt", id: ZeroHash, index: 1n << 180n },
    { host: "output", kind: "manifestPlan", planHash: ZeroHash },
    { host: "output", kind: "manifestRecord", recordHash: ZeroHash },
    { host: "output", kind: "requireCurrentManifest", recordHash: ZeroHash, artistId: H(1) },
    { host: "snapshot", kind: "dependencies" },
    ...["currentSnapshot", "snapshotCount", "snapshotLock"].map(kind => ({ host: "snapshot", kind, scope })),
    { host: "snapshot", kind: "snapshotAt", scope, index: 1n << 180n },
    ...["snapshotRecord", "snapshotPayload"].map(kind => ({ host: "snapshot", kind, hash: ZeroHash })),
    { host: "snapshot", kind: "requireCurrent", scope, hash: ZeroHash, revision: (1n << 64n) - 1n },
  ];
  for (const request of requests) {
    const read = p.prepareScopedPolicyPublicationV2Read(c, ZeroAddress, request);
    assert.deepEqual(p.normalizeScopedPolicyPublicationV2Read(read), read);
    assert.equal(compiledInterfaces[request.host].parseTransaction({ data: read.call.data }).name, request.kind);
    assert.throws(() => p.normalizeScopedPolicyPublicationV2Read({ ...read, call: { ...read.call, to: A(999) } }));
  }
  assert.throws(() => p.prepareScopedPolicyPublicationV2Read(c, ZeroAddress, { host: "snapshot", kind: "manifestRecord", recordHash: H(1) }));
  assert.throws(() => p.prepareScopedPolicyPublicationV2Read(c, ZeroAddress, { host: "snapshot", kind: "publishSnapshot", publication: vector().publication }));
});

test("definition commitments use exact frozen bytes with no appended newline", () => {
  const outputSource = fixture.sourceTexts["smart-contracts/domains/finality/StreamScopedPolicyOutputSchemasV2.sol"];
  const docs = [...outputSource.matchAll(/return bytes\(\s*'([^']+)'/g)].map(match => match[1]);
  for (const [i, prefix] of ["OUTPUT_SCHEMA", "OUTPUT_CANONICALIZATION", "LEAF_SCHEMA"].entries()) {
    assert.equal(p[`SCOPED_POLICY_PUBLICATION_V2_${prefix}_HASH`], id(docs[i]));
    assert.equal(p[`SCOPED_POLICY_PUBLICATION_V2_${prefix}_BYTES`], BigInt(Buffer.byteLength(docs[i])));
  }
  for (const [name, suffix] of [["SCHEMA", "schema"], ["PROFILE", "profile"], ["CANONICALIZATION", "abi"]]) {
    const doc = fixture.documents[`docs/schemas/preservation/scoped-policy-snapshot-v2.${suffix}.json`].text;
    assert.equal(p[`SCOPED_POLICY_PUBLICATION_V2_SNAPSHOT_${name}_HASH`], id(doc));
    assert.equal(p[`SCOPED_POLICY_PUBLICATION_V2_SNAPSHOT_${name}_BYTES`], BigInt(Buffer.byteLength(doc)));
    assert.notEqual(id(doc + "\n"), id(doc));
  }
});
