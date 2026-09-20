import test from "node:test";
import assert from "node:assert/strict";
import { AbiCoder, ZeroAddress, ZeroHash, concat, id, keccak256 } from "ethers";
import * as client from "../dist/current-revenue-escrow.js";
import { fixture, compiledInterfaces as compiled } from "./current-revenue-pull-fixture.mjs";

const coder = AbiCoder.defaultAbiCoder();
const a = n => `0x${BigInt(n).toString(16).padStart(40, "0")}`;
const hash = (types, values) => keccak256(coder.encode(types, values));
const coordinates = { chainId: 11155111n, escrow: a(900) };
const executor = a(901);
const entries = (first, second) => [
  { account: a(101), sharePpm: first, labelId: id("artist") },
  { account: a(102), sharePpm: second, labelId: id("collector") },
];
const document = {
  creditKey: { revenueClass: id("royalty"), profileId: id("original-profile"), wallet: a(902), asset: ZeroAddress },
  successorFactory: a(903), successorWallet: a(904), successorProfileId: id("successor-profile"),
  successorRuntimeCodeHash: id("reviewed-runtime"), expectedAmount: 1_000_000_000_000_000_017n, route: 1n,
  oldEntries: entries(600_000n, 400_000n), oldMetadataURIHash: id("ipfs://original-metadata"),
  successorEntries: entries(500_000n, 500_000n), recipientNotices: [], collectionNotices: [], sourceCredits: [],
  incidentEvidenceHash: id("incident-report"), coverageStatementHash: ZeroHash,
};
// Oracle types come from complete ABI107 compiler output, never client literals.
const documentType = compiled.escrow.getFunction("publishEscrowRecoveryManifest").inputs[0];
const canonicalDocument = coder.encode([documentType], [document]);
const contentHash = hash(["bytes32", "uint256", "address", documentType],
  [id("6529STREAM_ESCROW_RECOVERY_MANIFEST_V1"), coordinates.chainId, coordinates.escrow, document]);
const manifest = {
  uri: "ipfs://recovery-document", uriHash: id("ipfs://recovery-document"), contentHash,
  schemaId: id("STREAM_ESCROW_RECOVERY_MANIFEST_V1"), canonicalizationHash: id("6529STREAM_ESCROW_RECOVERY_ABI_V1"),
};
const terms = {
  creditKey: document.creditKey, successorWallet: document.successorWallet,
  successorProfileId: document.successorProfileId, successorRuntimeCodeHash: document.successorRuntimeCodeHash,
  expectedAmount: document.expectedAmount, recoveryManifest: manifest, executeAfter: 1_800_000_000n,
  reasonHash: id("recovery-reason"), reasonURI: "ipfs://recovery-reason",
};
const recoveryWords = [id("6529STREAM_ESCROW_RECOVERY_V1"), coordinates.chainId, coordinates.escrow,
  document.creditKey.revenueClass, document.creditKey.profileId, document.creditKey.wallet, document.creditKey.asset,
  terms.successorWallet, terms.successorProfileId, terms.successorRuntimeCodeHash, terms.expectedAmount,
  contentHash, terms.executeAfter, terms.reasonHash];
const recoveryTypes = ["bytes32", "uint256", "address", "bytes32", "bytes32", "address", "address", "address",
  "bytes32", "bytes32", "uint256", "bytes32", "uint64", "bytes32"];
const recoveryId = hash(recoveryTypes, recoveryWords);

test("escrow document bytes and content hash match the full compiler tuple and original domain", () => {
  assert.match(fixture.sourceTexts["smart-contracts/domains/revenue/StreamEscrowRecoveryState.sol"],
    /MANIFEST_DOMAIN = keccak256\("6529STREAM_ESCROW_RECOVERY_MANIFEST_V1"\)/);
  assert.equal(client.encodeRevenueEscrowDocument(document), canonicalDocument);
  assert.equal(contentHash, "0x450b5aeb00c877a5734a80389d70b208f129698dfae2484600f6583d4b245808");
  assert.equal(client.revenueEscrowManifestHash(coordinates, document), contentHash);
  const publication = client.prepareRevenueEscrowCall(coordinates, a(905), {
    kind: "publishEscrowRecoveryManifest", document, manifest,
  });
  assert.equal(publication.call.data, compiled.escrow.encodeFunctionData("publishEscrowRecoveryManifest", [document, manifest]));
  assert.notEqual(client.revenueEscrowManifestHash({ ...coordinates, chainId: 1n }, document), contentHash);
  assert.notEqual(client.revenueEscrowManifestHash({ ...coordinates, escrow: a(906) }, document), contentHash);
  assert.notEqual(client.revenueEscrowManifestHash(coordinates, { ...document, expectedAmount: document.expectedAmount + 1n }), contentHash);
});

test("recovery identity retains exactly 14 static words and excludes reference location", () => {
  assert.equal((coder.encode(recoveryTypes, recoveryWords).length - 2) / 2, 14 * 32);
  assert.equal(recoveryId, "0xf33f9bf0bc1c9a84b6737db54975a7e4cb3bd80db1a0f1ecf0d17b7b0ec9d686");
  assert.equal(client.revenueEscrowRecoveryId(coordinates, terms), recoveryId);
  const alternateURI = "https://example.invalid/recovery";
  assert.equal(client.revenueEscrowRecoveryId(coordinates, {
    ...terms, reasonURI: "ipfs://another-reason-location",
    recoveryManifest: { ...manifest, uri: alternateURI, uriHash: id(alternateURI),
      schemaId: id("other-schema"), canonicalizationHash: id("other-canonicalization") },
  }), recoveryId);
  for (const [key, changed] of [["expectedAmount", terms.expectedAmount + 1n], ["executeAfter", terms.executeAfter + 1n],
    ["reasonHash", id("different-reason")], ["successorWallet", a(906)],
    ["successorProfileId", id("other-profile")], ["successorRuntimeCodeHash", id("other-runtime")]]) {
    assert.notEqual(client.revenueEscrowRecoveryId(coordinates, { ...terms, [key]: changed }), recoveryId, key);
  }
  for (const [key, value] of [["revenueClass", id("other-revenue")], ["profileId", id("other-original-profile")],
    ["wallet", a(907)], ["asset", a(908)]]) {
    assert.notEqual(client.revenueEscrowRecoveryId(coordinates, {
      ...terms, creditKey: { ...terms.creditKey, [key]: value },
    }), recoveryId, key);
  }
  assert.notEqual(client.revenueEscrowRecoveryId(coordinates, { ...terms,
    recoveryManifest: { ...manifest, contentHash: id("different-content") } }), recoveryId);
  assert.notEqual(client.revenueEscrowRecoveryId({ ...coordinates, chainId: 1n }, terms), recoveryId);
  assert.notEqual(client.revenueEscrowRecoveryId({ ...coordinates, escrow: a(906) }, terms), recoveryId);
});

test("consent digest uses the original domain, uint64 deadline and zero nonce EIP-712 preimage", () => {
  const consent = { account: a(101), recoveryId, nonce: ZeroHash, deadline: (1n << 64n) - 1n };
  const domain = hash(["bytes32", "bytes32", "bytes32", "uint256", "address"], [
    id("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
    id("6529StreamRevenueEscrow"), id("1"), coordinates.chainId, coordinates.escrow,
  ]);
  const message = hash(["bytes32", "address", "bytes32", "bytes32", "uint64"], [
    id("StreamEscrowRecoveryConsent(address account,bytes32 recoveryId,bytes32 nonce,uint64 deadline)"),
    consent.account, recoveryId, ZeroHash, consent.deadline,
  ]);
  const expected = keccak256(concat(["0x1901", domain, message]));
  assert.equal(expected, "0x09ca6b551319fa3c574d35cfead4511207f1d9edc069f8fd0d9aa72936324096");
  assert.equal(client.revenueEscrowConsentTypedData(coordinates, consent).digest, expected);
  for (const [key, value] of [["account", a(102)], ["recoveryId", id("other-recovery")],
    ["nonce", id("other-nonce")], ["deadline", consent.deadline - 1n]]) {
    assert.notEqual(client.revenueEscrowConsentTypedData(coordinates, { ...consent, [key]: value }).digest, expected, key);
  }
  assert.notEqual(client.revenueEscrowConsentTypedData({ ...coordinates, escrow: a(906) }, consent).digest, expected);
  assert.throws(() => client.revenueEscrowConsentTypedData(coordinates, { ...consent, deadline: 1n << 64n }));
});

test("governance batch commitments match frozen Executor domains and full compiler calls", () => {
  const source = fixture.sourceTexts["smart-contracts/domains/governance/StreamGovernanceExecutor.sol"];
  const domain = name => {
    const match = source.match(new RegExp(`bytes32 private constant ${name}\\s*=\\s*(0x[0-9a-f]{64});`));
    assert.ok(match, name);
    return match[1];
  };
  const transition = { scopeHash: id("credit-scope"), oldValueHash: id("old-state"), newValueHash: id("scheduled-state") };
  const window = { notBefore: 1_799_000_000n, expiresAfter: 1_800_000_000n,
    reasonHash: id("governance-reason"), reasonURI: "ipfs://governance-reason", manifestHash: id("governance-manifest") };
  const data = compiled.escrow.encodeFunctionData("scheduleEscrowRecovery", Object.values(terms));
  const call = { target: coordinates.escrow, value: 0n, selector: data.slice(0, 10), callDataHash: keccak256(data), ...transition };
  const callsType = compiled.executor.getFunction("scheduleGovernanceBatch").inputs[1];
  const callsHash = hash(["bytes32", callsType], [domain("STREAM_GOVERNANCE_CALLS_V2"), [call]]);
  const aggregate = (name, field) => hash(["bytes32", "bytes32", "bytes32[]"], [domain(name), callsHash, [transition[field]]]);
  const scopeHash = aggregate("STREAM_GOVERNANCE_BATCH_SCOPE_V2", "scopeHash");
  const oldValueHash = aggregate("STREAM_GOVERNANCE_BATCH_OLD_STATE_V2", "oldValueHash");
  const newValueHash = aggregate("STREAM_GOVERNANCE_BATCH_NEW_STATE_V2", "newValueHash");
  const nonce = 0n;
  const actionId = hash(["bytes32", "uint256", "address", "uint8", "bytes32", "bytes32", "bytes32", "bytes32",
    "uint256", "uint64", "uint64", "bytes32", "bytes32"], [domain("STREAM_GOVERNANCE_ACTION_V2"), coordinates.chainId,
    executor, 4n, callsHash, scopeHash, oldValueHash, newValueHash, nonce,
    window.notBefore, window.expiresAfter, window.reasonHash, window.manifestHash]);
  assert.equal(callsHash, "0x9cdd7a345b955ed58b0c0939e589cde15e7de87b05ca1ba2cd8293c63238826e");
  assert.equal(actionId, "0x2c51b0f0c10ca495d774a7b2ed7a6f6c4fad7b0f054403dee450f050e62f365a");
  const prepared = client.prepareRevenueEscrowCall(coordinates, executor, { kind: "scheduleEscrowRecovery", terms });
  const batch = client.prepareRevenueEscrowGovernanceBatch(prepared, executor, transition, nonce, window);
  for (const [key, value] of Object.entries({ callsHash, scopeHash, oldValueHash, newValueHash, actionId })) assert.equal(batch[key], value, key);
  assert.equal(batch.publicationKey, keccak256(call.callDataHash));
  assert.equal(batch.publicationCall.data, compiled.executor.encodeFunctionData("publishGovernanceCallData", [[data]]));
  assert.equal(batch.scheduleCall.data, compiled.executor.encodeFunctionData("scheduleGovernanceBatch", [4n, [call], scopeHash,
    oldValueHash, newValueHash, window.notBefore, window.expiresAfter, window.reasonHash, window.reasonURI, window.manifestHash]));
  assert.equal(batch.executionCall.data, compiled.executor.encodeFunctionData("executeGovernanceBatch", [actionId, [call], [data]]));
});
