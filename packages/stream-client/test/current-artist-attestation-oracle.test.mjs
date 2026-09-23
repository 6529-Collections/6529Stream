import test from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { AbiCoder, Interface, ZeroAddress, ZeroHash, concat, getAddress, id, keccak256, toUtf8Bytes } from "ethers";
import { currentArtistOperationTypedData, prepareCurrentArtistAction, CURRENT_ARTIST_OPERATION_ABI } from "../dist/current-artist-operation.js";

const fixture = JSON.parse(readFileSync(new URL("./fixtures/current-artist-attestation-abi.json", import.meta.url), "utf8"));
const historical = JSON.parse(readFileSync(new URL("./fixtures/current-artist-operation-current-abi.json", import.meta.url), "utf8"));
const abi = Object.fromEntries(Object.entries(fixture.abis).map(([key, rows]) => [key, new Interface(rows)]));
const coder = AbiCoder.defaultAbiCoder(), address = n => getAddress(`0x${BigInt(n).toString(16).padStart(40, "0")}`);
const source = name => fixture.sourceTexts[`smart-contracts/domains/artist/${name}.sol`];
const chainId = (1n << 211n) + 31337n, registry = address(10), core = address(20), artistId = id("attestation artist");
const statementURI = "ipfs://original/attestation/é", statement = "0xabcdef010203";
const message = {
  core, collectionId: (1n << 192n) + 71n, subjectKind: 4n, subjectId: `0x${((1n << 192n) + 71n).toString(16).padStart(64, "0")}`, subjectStateHash: id("subject state"),
  schemaId: id("original application schema"), statementHash: keccak256(statement), statementURIHash: keccak256(toUtf8Bytes(statementURI)),
  nonce: (1n << 227n) + 17n, signedAt: (1n << 63n) + 1n,
};
const declaration = "StreamArtistAttestation(address core,uint256 collectionId,uint8 subjectKind,bytes32 subjectId,bytes32 subjectStateHash,bytes32 schemaId,bytes32 statementHash,bytes32 statementURIHash,uint256 nonce,uint64 signedAt)";
function request(kind = "delegatedAttestation") {
  return { kind, chainId, registry, caller: address(40), signer: address(41), artistId, mode: "signature", signature: "0x1234", message: kind === "delegatedScopedAttestation"
      ? { ...message, subjectId: keccak256(coder.encode(["bytes32", "(uint8,uint256,uint256,bytes32)"],
        [id("6529STREAM_ARTIST_FINALITY_ATTESTATION_SUBJECT_V1"), [2n, message.collectionId, 0n, id("finality scope")]])) } : message,
    details: { grant: id("attestation grant"), statementURI, statement,
      ...(kind === "delegatedScopedAttestation" ? { subject: { scopeType: 2n, tokenId: 0n, scopeId: id("finality scope"), resolver: ZeroAddress } } : {}),
    },
  };
}
function independentDigest(m, verifier = registry) {
  const domain = keccak256(coder.encode(["bytes32", "bytes32", "bytes32", "uint256", "address"],
    [id("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"), id("6529StreamArtistRegistry"), id("1"), chainId, verifier]));
  const hash = keccak256(coder.encode(["bytes32", "address", "uint256", "uint8", "bytes32", "bytes32", "bytes32", "bytes32", "bytes32", "uint256", "uint64"],
    [id(declaration), m.core, m.collectionId, m.subjectKind, m.subjectId, m.subjectStateHash, m.schemaId, m.statementHash, m.statementURIHash, m.nonce, m.signedAt]));
  return keccak256(concat(["0x1901", domain, hash]));
}
function terms(m = message) { return [m.collectionId, m.subjectKind, m.subjectId, m.subjectStateHash, m.schemaId, m.statementHash, statementURI]; }

test("delegated attestation fixture pins ABI56 while preserving the separate original ABI52 fixture", () => {
  assert.equal(fixture.sourceCommit, "ed4d557246a98698167d6986bc4266d9e375d558");
  assert.equal(fixture.sourceCount, 2241);
  assert.equal(fixture.inputSha256, "6aec6f59bb3037d83ee9a3bc2a3a1552bfac224c4b8cbf7bbe9ec79ce6c253c7");
  assert.equal(fixture.outputSha256, "7423844d40d9ee2982473692bee53bb482f578a90e90e340f95d06469cbe3aaf");
  assert.equal(Object.keys(fixture.sourceHashes).length, 368);
  assert.equal(Object.keys(fixture.sourceTexts).length, 12);
  assert.equal(Object.values(fixture.abis).flat().length, 81);
  assert.equal(Object.keys(fixture.abis).length, 26);
  assert.equal(historical.sourceCommit, "44af244ed576cc4b26632b800fe70a068d577940");
  for (const [path, text] of Object.entries(fixture.sourceTexts)) assert.equal(createHash("sha256").update(text).digest("hex"), fixture.sourceHashes[path]);
  assert.match(fixture.qualification, /C2PA caller support is deferred/);
});

test("both delegated calls retain original op24 selectors, widths and the facade signing host", () => {
  const client = new Interface(CURRENT_ARTIST_OPERATION_ABI);
  const methods = {
    delegatedAttestation: ["recordDelegatedArtistAttestation", "0x36854c8f"],
    delegatedScopedAttestation: ["recordDelegatedArtistScopedAttestation", "0xfcb1f760"],
  };
  for (const [kind, [method, selector]] of Object.entries(methods)) {
    const input = request(kind), prepared = prepareCurrentArtistAction(input);
    const args = [terms(input.message), ...(kind === "delegatedScopedAttestation" ? [[2n, 0n, id("finality scope"), ZeroAddress]] : []), input.details.grant,
      [message.nonce, message.signedAt, input.signature], statement];
    assert.equal(prepared.operationId, 24n); assert.equal(prepared.method, method); assert.equal(prepared.digestMethod, "attestationDigest");
    assert.equal(abi.registry.getFunction(method).selector, selector);
    assert.equal(client.getFunction(method).format("sighash"), abi.registry.getFunction(method).format("sighash"));
    assert.deepEqual(prepared.call, { to: registry, value: 0n, data: abi.registry.encodeFunctionData(method, args) });
    assert.deepEqual(prepared.digestCall, { to: registry, value: 0n,
      data: abi.registry.encodeFunctionData("attestationDigest", [terms(input.message), [message.nonce, message.signedAt, "0x"]]) });
    assert.equal(abi.writer.getFunction(method).selector, selector);
    assert.equal(prepared.payload.digest, independentDigest(input.message));
  }
  assert.equal(abi.registry.getFunction("attestationDigest").selector, "0x9bf0ac77");
  assert.equal(abi.writer.getFunction("recordDelegatedArtistScopedAttestation").inputs[1].format("sighash"), "(uint8,uint256,bytes32,address)");
});

test("the original digest binds all ten fields without adding grant, scope descriptor, Artist ID or new domain", () => {
  assert.ok(source("StreamArtistHashes").includes(`"${declaration}"`));
  for (const kind of ["delegatedAttestation", "delegatedScopedAttestation"]) {
    const m = request(kind).message;
    const payload = currentArtistOperationTypedData(kind, chainId, registry, m);
    assert.equal(payload.digest, independentDigest(m));
    assert.notEqual(payload.digest, independentDigest(m, address(99)));
    const original = prepareCurrentArtistAction(request(kind));
    const alternate = prepareCurrentArtistAction({ ...request(kind), artistId: id("different artist"), details: { ...request(kind).details, grant: id("different grant") } });
    assert.equal(original.payload.digest, alternate.payload.digest);
    assert.notEqual(original.call.data, alternate.call.data);
    for (const [key, value] of Object.entries(m)) {
      const changed = typeof value === "bigint" ? value + 1n : key === "core" ? address(88) : id(`changed ${key}`);
      const mutated = { ...m, [key]: changed };
      assert.notEqual(payload.digest, independentDigest(mutated), key);
    }
  }
});

test("zero-time replacement is conditional and delegated positive past timestamps use the original broad admission", () => {
  const text = source("StreamArtistAttestationOperations");
  assert.match(text, /actor == signer && actor != address\(0\) && submitted\.signature\.length == 0\s*&& submitted\.time == 0/);
  assert.match(text, /effective\.time = uint64\(block\.timestamp\)/);
  const delegated = source("StreamArtistDelegatedMutation").split("function consumeDelegatedAttestation(")[1].split("function consumeDelegatedPolicyConsent(")[0];
  assert.match(delegated, /a\.time == 0 \|\| a\.time > block\.timestamp/);
  assert.doesNotMatch(delegated, /a\.time != block\.timestamp/);
  assert.match(delegated, /p\.subjectKind == 7 \? D\.INTENT : D\.ATTEST/);
  const submitted = { ...request(), mode: "direct", caller: address(41), signature: "0x", message: { ...message, signedAt: 0n } };
  const prepared = prepareCurrentArtistAction(submitted);
  assert.equal(abi.registry.decodeFunctionData(prepared.method, prepared.call.data)[2].time, 0n);
  assert.equal(prepared.payload.digest, independentDigest(submitted.message));
  assert.notEqual(prepared.payload.digest, independentDigest({ ...submitted.message, signedAt: 1700000000n }));
});

test("the Archive uses original flat eleven-field payload, op24 snapshots and semantic owner order", () => {
  const recipe = source("StreamArtistAttestationOperations");
  assert.match(recipe, /uint256 mask = op == 25 \? 0x04 : 0x17/);
  assert.match(recipe, /abi\.encode\(\s*b,\s*p,\s*submitted,\s*effective,\s*proof,\s*statement,\s*subject,\s*scoped,\s*admission,\s*delegation,\s*subjectEvidence\s*\)/);
  assert.ok(recipe.indexOf(".consumeDelegatedAttestation(") < recipe.indexOf(".recordAuthenticatedAttestation("));
  assert.ok(recipe.indexOf(".recordAuthenticatedAttestation(") < recipe.indexOf("        _archive("));
  const admission = abi.authenticatedOwner.getFunction("recordAuthenticatedAttestation").inputs[3];
  assert.deepEqual(admission.components.map(row => row.name), ["authority", "signer", "nonce", "signedAt", "delegation", "operativeIdentity", "fact"]);
  assert.equal(abi.attribution.getEvent("ArtistAttestationRecorded").inputs[0].type, "uint16");
  assert.equal(abi.attribution.getEvent("ArtistAttestationDelegation").inputs[1].indexed, true);
  assert.equal(abi.registry.getEvent("ArtistAttestationRecorded"), null);
});

test("durable records and association retain original fields separately from overwriteable latest heads", () => {
  assert.deepEqual(abi.attribution.getFunction("attestationRecord").outputs[0].components.map(row => row.name),
    ["recordHash", "subjectStateHash", "schemaId", "statementHash", "generation", "signedAt", "signer"]);
  assert.deepEqual(abi.attribution.getFunction("attestationAssociation").outputs[0].components.map(row => row.name),
    ["artistId", "bindingHash", "generation", "delegation", "fact"]);
  assert.equal(abi.attribution.getFunction("attestationAuthorityClass").outputs[0].type, "uint8");
  const text = source("StreamArtistAttributionAttestations");
  assert.match(text, /s\.attestationAssociations\[m\.record\] = association/);
  assert.match(text, /s\.records\[m\.record\] = item/);
  assert.match(text, /s\.attestations\[keccak256\(abi\.encode\(p\.collectionId, p\.subjectKind, p\.subjectId\)\)\] = item/);
  assert.match(text, /class_ = 2/);
});

test("snapshot and scoped subject read ABIs retain exact configuration, scope and fact shapes", () => {
  const config = abi.snapshotConfiguration.getFunction("nativeConfiguration").outputs[0];
  assert.equal(32 * config.components.reduce((sum, row) => sum + (row.baseType === "array" ? row.arrayLength : 1), 0), 1568);
  assert.equal(abi.snapshot.getFunction("currentSnapshot").outputs[0].components.length * 32, 672);
  assert.equal(abi.finality.getFunction("artworkScopeFinalityRecord").inputs[0].format("sighash"), "(uint8,uint256,uint256,bytes32)");
  const subjects = source("StreamArtistAttestationSubjectReads");
  assert.match(subjects, /scoped && p\.subjectKind != 4 && p\.subjectKind != 6/);
  assert.match(subjects, /q\.scopeType == 1 && uint256\(q\.scopeId\) != p\.collectionId/);
  assert.match(subjects, /r\.manifestHash[\s\S]*latestSnapshotHash[\s\S]*snapshotHash/);
  assert.match(subjects, /keccak256\("ROYALTY_RESOLVER"\), resolver/);
  assert.match(subjects, /\.resolvePrimaryAssignment\(p\.collectionId, 0, s\.primaryRevenueClass\)/);
});

test("publication schema retains canonical 416 bytes and exact original candidate versus general statement families", () => {
  const publication = abi.publicationHost.getFunction("requireArtistRecordCandidate").inputs[0];
  assert.equal(publication.components.length, 12);
  const values = [address(51), address(41), message.collectionId, id("publication subject"), id("ARTIST_STATEMENT"), id("statement schema"),
    id("canonical schema"), 1n, id("payload"), message.statementURIHash, 0n, id("candidate")];
  const bytes = coder.encode(["uint16", publication], [1n, values]);
  assert.equal((bytes.length - 2) / 2, 416);
  const rules = source("StreamArtistRecordPublicationRules");
  assert.match(rules, /statement\.length != 416/);
  assert.match(rules, /kind == 7 \? publication\.candidateRecordHash : bytes32\(0\)/);
  const input = { ...request(), message: { ...message, subjectKind: 8n, subjectId: values[3], subjectStateHash: ZeroHash,
    schemaId: id("6529STREAM_ARTIST_RECORD_PUBLICATION_V1"), statementHash: keccak256(bytes) }, details: { ...request().details, statement: bytes } };
  assert.equal(prepareCurrentArtistAction(input).operationId, 24n);
  assert.throws(() => prepareCurrentArtistAction({ ...input, message: { ...input.message, subjectStateHash: id("invented nonzero") } }));
});

test("receipt creation and later publication consumption have separate original delegation requirements", () => {
  const reads = source("StreamArtistRecordPublicationReads");
  const consumed = reads.split("function _requireDelegatePublication(")[1];
  assert.match(consumed, /d\.revoked \|\| d\.uses == 0/);
  assert.match(consumed, /block\.timestamp < d\.grant\.notBefore \|\| block\.timestamp >= d\.grant\.expiresAt/);
  assert.match(consumed, /!epoch/);
  assert.doesNotMatch(consumed, /uses >= .*maxUses/);
  assert.match(consumed, /Exhausting maxUses must not invalidate/);
  assert.match(source("StreamArtistAttributionAttestations"), /StreamArtistC2PACredentials\.note\(/);
  assert.throws(() => prepareCurrentArtistAction({ ...request(), message: { ...message, subjectKind: 10n, subjectId: artistId,
    schemaId: id("6529STREAM_ARTIST_C2PA_CREDENTIALS_V1") } }));
});
