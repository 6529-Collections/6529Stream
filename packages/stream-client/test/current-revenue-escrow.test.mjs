import test from "node:test";
import assert from "node:assert/strict";
import { AbiCoder, getAddress, id, keccak256, toUtf8Bytes, ZeroAddress, ZeroHash } from "ethers";
import * as e from "../dist/current-revenue-escrow.js";
import { compiledInterfaces as c } from "./current-revenue-pull-fixture.mjs";

const A = n => getAddress(`0x${BigInt(n).toString(16).padStart(40, "0")}`);
const coordinates = { chainId: 1n, escrow: A(1) };
const entries = [{ account: A(0xabc), sharePpm: 1_000_000n, labelId: ZeroHash }];
const document = () => ({
  creditKey: { revenueClass: id("class"), profileId: id("profile"), wallet: A(3), asset: ZeroAddress },
  successorFactory: A(4), successorWallet: A(5), successorProfileId: id("successor"), successorRuntimeCodeHash: id("runtime"),
  expectedAmount: 50n, route: 0n, oldEntries: structuredClone(entries), oldMetadataURIHash: id("metadata"),
  successorEntries: structuredClone(entries), recipientNotices: [], collectionNotices: [], sourceCredits: [],
  incidentEvidenceHash: id("incident"), coverageStatementHash: ZeroHash,
});
const reference = d => ({ uri: "ipfs://manifest", uriHash: keccak256(toUtf8Bytes("ipfs://manifest")),
  contentHash: e.revenueEscrowManifestHash(coordinates, d), schemaId: id("STREAM_ESCROW_RECOVERY_MANIFEST_V1"), canonicalizationHash: id("6529STREAM_ESCROW_RECOVERY_ABI_V1") });
const terms = d => ({ creditKey: d.creditKey, successorWallet: d.successorWallet, successorProfileId: d.successorProfileId,
  successorRuntimeCodeHash: d.successorRuntimeCodeHash, expectedAmount: d.expectedAmount, recoveryManifest: reference(d),
  executeAfter: 2_000_000n, reasonHash: id("reason"), reasonURI: "ipfs://reason" });

test("all ten exact original methods are immutable zero-value calls with closed action classes", () => {
  const d = document(), rid = id("recovery");
  const requests = [
    ...["flushEscrow", "flushToVerifiedWalletBestEffort"].map(kind => ({ kind, creditKey: d.creditKey })),
    { kind: "publishEscrowRecoveryManifest", document: d, manifest: reference(d) },
    ...["executeEscrowRecovery", "authorizeTerminalEscrowRecovery", "revokeEscrowRecoveryConsent"].map(kind => ({ kind, recoveryId: rid })),
    { kind: "recordEscrowRecoveryConsent", recoveryId: rid, nonce: ZeroHash },
    { kind: "submitEscrowRecoveryConsent", consent: { account: A(9), recoveryId: rid, nonce: ZeroHash, deadline: 100n }, signature: "0x" },
    { kind: "scheduleEscrowRecovery", terms: terms(d) },
    { kind: "cancelEscrowRecovery", recoveryId: rid, reasonHash: id("reason"), reasonURI: "ipfs://reason" },
  ];
  for (const request of requests) {
    const plan = e.prepareRevenueEscrowCall(coordinates, A(9), request);
    assert.equal(c.escrow.parseTransaction(plan.call).name, request.kind);
    assert.equal(plan.call.value, 0n);
    assert.ok(Object.isFrozen(plan.request));
    assert.deepEqual(e.normalizeRevenueEscrowCall(plan), plan);
    assert.throws(() => e.normalizeRevenueEscrowCall({ ...plan, call: { ...plan.call, value: 1n } }));
    assert.equal(plan.actionClass, ({ scheduleEscrowRecovery: 4n, cancelEscrowRecovery: 0n, authorizeTerminalEscrowRecovery: 2n })[request.kind] ?? null);
  }
  assert.throws(() => e.prepareRevenueEscrowCall(coordinates, A(9), { kind: "creditNative" }));
});

test("canonical complete manifest roundtrip rejects trailing bytes, holes and lossy integers", () => {
  const d = document(), encoded = e.encodeRevenueEscrowDocument(d);
  assert.deepEqual(e.decodeRevenueEscrowDocument(encoded), e.normalizeRevenueEscrowDocument(d));
  assert.throws(() => e.decodeRevenueEscrowDocument(`${encoded}00`));
  assert.throws(() => e.normalizeRevenueEscrowDocument({ ...d, expectedAmount: 50 }));
  const hole = structuredClone(d); hole.oldEntries.length = 2;
  assert.throws(() => e.normalizeRevenueEscrowDocument(hole));
  assert.throws(() => e.normalizeRevenueEscrowDocument({ ...d, unknown: true }));
});

test("affected-account helper independently normalizes mixed-case identities and validates both entry arrays", () => {
  const d = document();
  d.oldEntries[0].account = d.oldEntries[0].account.toLowerCase();
  d.successorEntries[0].account = `0x${d.successorEntries[0].account.slice(2).toUpperCase()}`;
  assert.deepEqual(e.revenueEscrowAffectedAccounts(d), []);
  assert.throws(() => e.revenueEscrowAffectedAccounts({ ...d, successorEntries: [{ ...entries[0], sharePpm: 999_999n }] }));
  assert.throws(() => e.revenueEscrowAffectedAccounts({ ...d, oldEntries: [{ ...entries[0], sharePpm: 1_000_000 }] }));
});

test("route changes aggregate repeated account labels and require complete ordered terminal notices", () => {
  const d = document();
  d.oldEntries = [{ account: A(10), sharePpm: 600_000n, labelId: ZeroHash }, { account: A(10), sharePpm: 400_000n, labelId: id("label") }];
  d.successorEntries = [{ account: A(11), sharePpm: 1_000_000n, labelId: ZeroHash }];
  d.route = 1n;
  assert.deepEqual(e.revenueEscrowAffectedAccounts(d), [A(10)]);
  e.normalizeRevenueEscrowDocument(d);
  d.route = 2n;
  assert.throws(() => e.normalizeRevenueEscrowDocument(d));
  d.coverageStatementHash = id("coverage");
  d.recipientNotices = [{ account: A(10), evidenceHash: id("notice"), noticedAt: 1n }];
  d.collectionNotices = [{ core: A(20), collectionId: 1n, artistBound: false, artistAuthority: ZeroAddress, evidenceHash: ZeroHash, noticedAt: 0n }];
  d.sourceCredits = [{ producer: A(30), transactionHash: id("tx"), blockHash: id("block"), blockNumber: 1n, logIndex: 0n, collectionIndex: 0n }];
  e.normalizeRevenueEscrowDocument(d);
  assert.throws(() => e.normalizeRevenueEscrowDocument({ ...d, recipientNotices: [] }));
});

test("URI boundaries preserve Unicode scalar text and reject lone surrogates", () => {
  const d = document();
  for (const uri of ["x".repeat(2048), "😀".repeat(512)]) {
    const r = { ...reference(d), uri, uriHash: keccak256(toUtf8Bytes(uri)) };
    e.normalizeRevenueEscrowManifestRef(r);
  }
  for (const uri of ["x".repeat(2049), "\udc00", "\ud800"]) {
    assert.throws(() => e.normalizeRevenueEscrowManifestRef({ ...reference(d), uri }));
  }
});

test("consent nonce zero and empty contract proof are represented without invented signer admission", () => {
  const consent = { account: A(9), recoveryId: id("id"), nonce: ZeroHash, deadline: 0n };
  const plan = e.prepareRevenueEscrowCall(coordinates, A(10), { kind: "submitEscrowRecoveryConsent", consent, signature: "0x" });
  assert.equal(plan.request.consent.nonce, ZeroHash);
  assert.equal(plan.factsVerified, false);
  assert.equal(c.escrow.decodeFunctionData("submitEscrowRecoveryConsent", plan.call.data)[4], "0x");
});

test("governed wrapper is the exact original singleton Executor route and resists escaped mutations", () => {
  const p = e.prepareRevenueEscrowCall(coordinates, A(99), { kind: "scheduleEscrowRecovery", terms: terms(document()) });
  const transition = { scopeHash: id("scope"), oldValueHash: id("old"), newValueHash: id("new") };
  const window = { notBefore: 2_000_000n, expiresAfter: 3_000_000n, reasonHash: id("why"), reasonURI: "ipfs://why", manifestHash: id("manifest") };
  const batch = e.prepareRevenueEscrowGovernanceBatch(p, A(99), transition, 0n, window);
  assert.equal(c.executor.parseTransaction(batch.publicationCall).name, "publishGovernanceCallData");
  assert.equal(c.executor.parseTransaction(batch.scheduleCall).args[0], 4n);
  assert.equal(c.executor.parseTransaction(batch.executionCall).args[0], batch.actionId);
  assert.deepEqual(e.normalizeRevenueEscrowGovernanceBatch(batch), batch);
  assert.throws(() => e.normalizeRevenueEscrowGovernanceBatch({ ...batch, actionId: id("other") }));
  assert.throws(() => e.prepareRevenueEscrowGovernanceBatch(p, A(98), transition, 0n, window));
});
