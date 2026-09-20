import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { AbiCoder, Interface, ParamType, TypedDataEncoder, ZeroAddress, ZeroHash, getAddress, id, keccak256 } from "ethers";
import * as d from "../dist/current-direct-conservation.js";

const fixture = JSON.parse(readFileSync(new URL("./fixtures/current-direct-conservation-abi.json", import.meta.url), "utf8"));
const abi = Object.fromEntries(Object.entries(fixture.abis).map(([key, value]) => [key, new Interface(value)]));
const coder = AbiCoder.defaultAbiCoder();
const addr = value => getAddress(`0x${BigInt(value).toString(16).padStart(40, "0")}`);
const chainId = (1n << 224n) + 17n;
const cid = (1n << 230n) + 53n;
const actor = addr(10);
const coordinates = productKind => ({ chainId, core: addr(1), product: addr(2), productKind });
const floor = { chainId, core: addr(1), floor: addr(3) };
const data = "0x010203";
const signedData = { tokenData: data, platformSignature: "0x", artistSignature: "0x1234" };
const native = () => ({
  collectionId: cid,
  phaseId: id("phase"),
  payer: actor,
  recipient: addr(11),
  artist: addr(12),
  profileId: id("profile"),
  expectedPrimaryPolicyHash: id("primary policy"),
  tokenDataHash: keccak256(data),
  mintCommitment: id("mint commitment"),
  mintPolicyHash: id("mint policy"),
  price: (1n << 200n) + 23n,
  nonce: id("nonce"),
  deadline: 1000n,
  signerEpoch: 5n
});
const auctionAuth = () => {
  const a = native();
  return {
    collectionId: a.collectionId,
    phaseId: a.phaseId,
    artist: a.artist,
    profileId: a.profileId,
    expectedPrimaryPolicyHash: a.expectedPrimaryPolicyHash,
    tokenDataHash: a.tokenDataHash,
    mintCommitment: a.mintCommitment,
    mintPolicyHash: a.mintPolicyHash,
    reservePrice: 0n,
    startTime: 100n,
    endTime: 1000n,
    extensionWindow: 30n,
    minBidIncrementBps: 50n,
    nonce: a.nonce,
    deadline: a.deadline,
    signerEpoch: a.signerEpoch
  };
};
function erc20() {
  const c = coordinates("erc20-fixed");
  const config = {
    collectionId: cid,
    phaseId: id("phase"),
    asset: addr(30),
    revenueClass: id("PRIMARY_SALE"),
    price: 900n,
    mintPolicyHash: id("mint policy"),
    expectedPrimaryPolicyHash: id("primary policy"),
    startsAt: 100n,
    endsAt: 1000n
  };
  const saleNonce = (1n << 240n) + 2n;
  const saleId = d.directConservationERC20SaleId(c, cid, config.phaseId, saleNonce);
  const configHash = d.directConservationERC20ConfigHash(saleId, config);
  const authorization = {
    saleId,
    saleConfigHash: configHash,
    payer: actor,
    recipient: addr(11),
    artist: addr(12),
    tokenDataHash: keccak256(data),
    mintCommitment: id("mint commitment"),
    nonce: ZeroHash,
    deadline: 1000n,
    signerEpoch: 5n
  };
  const intent = {
    payer: actor,
    asset: config.asset,
    maxAmount: config.price + 1n,
    saleRef: saleId,
    expectedPrimaryPolicyHash: config.expectedPrimaryPolicyHash,
    nonce: ZeroHash,
    deadline: 1000n
  };
  return { c, config, authorization, intent, record: { config, saleNonce, configHash, cancelled: false } };
}
function blank(param) {
  if (param.baseType === "tuple") return Object.fromEntries(param.components.map(field => [field.name, blank(field)]));
  if (param.type.startsWith("uint")) return 0n;
  if (param.type === "bool") return false;
  if (param.type === "address") return ZeroAddress;
  return ZeroHash;
}
function populated(param) {
  if (param.baseType === "tuple") return Object.fromEntries(param.components.map(field => [field.name, populated(field)]));
  if (param.type.startsWith("uint")) return (1n << BigInt(Number(param.type.slice(4)) - 1)) + 3n;
  if (param.type === "bool") return true;
  if (param.type === "address") return addr(33);
  return id(param.name);
}
const productReceiptType = abi.directReceipt.getFunction("directPrimarySaleReceipt").outputs[0];
const bindingsType = abi.directReceipt.getFunction("directPrimaryBindings").outputs[0];
const firstType = abi.floor.getFunction("firstSale").outputs[0];
const releaseType = abi.floor.getFunction("releaseFloorReceipt").outputs[0];
const floorType = abi.directFloor.getFunction("directPrimarySaleFloorReceipt").outputs[0];

test("canonical original receipt codecs preserve every full-width nested term and zero unknown record", () => {
  const vectors = [
    ["Bindings", bindingsType],
    ["Receipt", productReceiptType],
    ["FloorReceipt", floorType],
    ["FirstSaleReceipt", firstType],
    ["ReleaseReceipt", releaseType],
    ["Source", abi.floor.getFunction("sourceAt").outputs[0]],
    ["Auction", abi.auction.getFunction("auction").outputs[0]],
    ["ERC20SaleRecord", abi.erc20Sale.getFunction("saleRecord").outputs[0]]
  ];
  for (const [name, tuple] of vectors) {
    for (const value of [blank(tuple), populated(tuple)]) {
      const canonical = coder.encode([tuple], [value]);
      assert.equal(d[`encodeDirectConservation${name}`](value), canonical);
      assert.deepEqual(d[`decodeDirectConservation${name}`](canonical), value);
      assert.throws(() => d[`decodeDirectConservation${name}`](`${canonical}00`), /Noncanonical/);
    }
  }
  const value = populated(floorType);
  const frozen = d.normalizeDirectConservationFloorReceipt(value);
  value.sale.amount = 0n;
  value.bindings.core = addr(99);
  assert.notEqual(frozen.sale.amount, 0n);
  assert.notEqual(frozen.bindings.core, addr(99));
  assert.ok(Object.isFrozen(frozen.sale));
  assert.throws(() => d.normalizeDirectConservationReceipt({ ...blank(productReceiptType), createdAt: 1n << 64n }));
  assert.throws(() => d.normalizeDirectConservationReceipt({ ...blank(productReceiptType), amount: 12 }));
  assert.throws(() => d.normalizeDirectConservationReceipt({ ...blank(productReceiptType), inventedPurchaseId: ZeroHash }));
  assert.throws(() => d.decodeDirectConservationReceipt(`0x${"00".repeat(d.DIRECT_CONSERVATION_MAX_BYTES + 1)}`));
});

test("commercial signatures use exact v2 native/auction and inherited v1 ERC20 domains", () => {
  const e = erc20();
  const vectors = [
    ["native-fixed", "Native", native(), "6529StreamFixedPriceSale", "2", "SaleAuthorization", abi.nativeSale],
    ["erc20-fixed", "ERC20", e.authorization, "6529StreamPaymentIntentVerifier", "1", "ERC20SaleAuthorization", abi.erc20Sale],
    ["english-auction", "Auction", auctionAuth(), "6529StreamEnglishAuction", "2", "AuctionAuthorization", abi.auction]
  ];
  for (const [kind, name, authorization, domainName, version, primaryType, iface] of vectors) {
    const c = coordinates(kind);
    const fields = iface.getFunction("authorizationDigest").inputs[0].components.map(field => ({ name: field.name, type: field.type }));
    const domain = { name: domainName, version, chainId, verifyingContract: c.product };
    const expected = TypedDataEncoder.hash(domain, { [primaryType]: fields }, authorization);
    const payload = d[`directConservation${name}TypedData`](c, authorization);
    assert.equal(payload.digest, expected);
    assert.deepEqual(payload.domain, domain);
    assert.notEqual(payload.digest, TypedDataEncoder.hash({ ...domain, verifyingContract: c.core }, { [primaryType]: fields }, authorization));
    assert.throws(() => d[`directConservation${name}TypedData`]({ ...c, productKind: kind === "erc20-fixed" ? "native-fixed" : "erc20-fixed" }, authorization));
  }
  assert.equal(d.directConservationPaymentIntentTypedData(e.c, e.intent).domain.verifyingContract, e.c.product);
  assert.equal(d.directConservationPaymentRevocationTypedData(e.c, { payer: actor, nonce: ZeroHash, deadline: 1000n }).domain.name, "6529StreamPaymentIntentVerifier");
});

test("original nonce domains and fixed ERC20 kind zero retain identities above JS-safe width", () => {
  const e = erc20();
  const domains = {
    "native-fixed": "6529STREAM_NATIVE_SALE_NONCE_V1",
    "erc20-fixed": "6529STREAM_ERC20_SALE_NONCE_V1",
    "english-auction": "6529STREAM_ENGLISH_AUCTION_NONCE_V1"
  };
  const ids = [];
  for (const [kind, domain] of Object.entries(domains)) {
    const c = coordinates(kind);
    const expected = keccak256(coder.encode(["bytes32", "uint256", "address", "address", "bytes32"], [id(domain), chainId, c.product, actor, ZeroHash]));
    ids.push(d.directConservationAuthorizationId(c, actor, ZeroHash));
    assert.equal(ids.at(-1), expected);
  }
  assert.equal(new Set(ids).size, 3);
  assert.equal(e.authorization.saleId, keccak256(coder.encode(
    ["bytes32", "uint256", "address", "uint8", "uint256", "bytes32", "uint256"],
    [id("6529STREAM_SALE_V1"), chainId, e.c.product, 0n, cid, e.config.phaseId, e.record.saleNonce]
  )));
  const tuple = abi.erc20Sale.getFunction("registerSale").inputs[0];
  assert.equal(e.record.configHash, keccak256(coder.encode(["bytes32", "bytes32", tuple], [id("6529STREAM_CURRENT_ERC20_FIXED_PRICE_CONFIG_V1"), e.authorization.saleId, e.config])));
});

test("all finite original product calls encode compiler calldata, literal caller and exact value", () => {
  const e = erc20();
  const requests = [
    ["native-fixed", { kind: "buy", authorization: native(), ...signedData }, "nativeSale", [native(), data, "0x", "0x1234"], native().price],
    ["native-fixed", { kind: "cancelAuthorization", nonce: id("native nonce") }, "nativeSale", [id("native nonce")], 0n],
    ["erc20-fixed", { kind: "buy", authorization: e.authorization, ...signedData, intent: e.intent, payerSignature: "0x" }, "erc20Sale", [e.authorization, data, "0x", "0x1234", e.intent, "0x"], 0n],
    ["erc20-fixed", { kind: "registerSale", config: e.config }, "erc20Sale", [e.config], 0n],
    ["erc20-fixed", { kind: "cancelSale", saleId: e.authorization.saleId }, "erc20Sale", [e.authorization.saleId], 0n],
    ["erc20-fixed", { kind: "cancelAuthorization", nonce: ZeroHash }, "erc20Sale", [ZeroHash], 0n],
    ["erc20-fixed", { kind: "revokePaymentIntent", nonce: ZeroHash }, "erc20Sale", [ZeroHash], 0n],
    ["erc20-fixed", { kind: "revokePaymentIntentBySignature", payer: actor, nonce: ZeroHash, deadline: 1000n, signature: "0x" }, "erc20Sale", [actor, ZeroHash, 1000n, "0x"], 0n],
    ["english-auction", { kind: "createAuction", authorization: auctionAuth(), ...signedData }, "auction", [auctionAuth(), data, "0x", "0x1234"], 0n],
    ["english-auction", { kind: "bid", tokenId: cid, recipient: addr(22), amount: 901n }, "auction", [cid, addr(22)], 901n],
    ...["settle", "cancel"].map(kind => ["english-auction", { kind, tokenId: cid }, "auction", [cid], 0n]),
    ...["setDeliveryRecipient", "claimNoBidNFT"].map(kind => ["english-auction", { kind, tokenId: cid, recipient: addr(22) }, "auction", [cid, addr(22)], 0n]),
    ["english-auction", { kind: "withdrawRefund", recipient: addr(23) }, "auction", [addr(23)], 0n],
    ["english-auction", { kind: "cancelAuthorization", nonce: id("auction nonce") }, "auction", [id("auction nonce")], 0n]
  ];
  for (const [productKind, request, key, args, value] of requests) {
    const c = coordinates(productKind);
    const plan = d.prepareDirectConservationCall(c, actor, { productKind, ...request });
    assert.deepEqual(plan.call, { to: c.product, value, data: abi[key].encodeFunctionData(request.kind, args) });
    assert.equal(plan.caller, actor);
    assert.equal(plan.factsVerified, false);
    assert.deepEqual(d.normalizeDirectConservationCall(plan), plan);
  }
});

test("caller intent exemption ignores structural intent only for literal payer and empty proof", () => {
  const e = erc20();
  const ignoredIntent = blank(abi.erc20Sale.getFunction("buy").inputs[4]);
  const request = { productKind: "erc20-fixed", kind: "buy", authorization: e.authorization, ...signedData, intent: ignoredIntent, payerSignature: "0x" };
  const direct = d.prepareDirectConservationCall(e.c, actor, request);
  const facts = { timestamp: 1000n, signerEpoch: 5n };
  assert.equal(d.validateDirectConservationExecutionTerms(direct, facts, e.record).paymentLane, "caller");
  const relayed = d.prepareDirectConservationCall(e.c, addr(50), request);
  assert.throws(() => d.validateDirectConservationExecutionTerms(relayed, facts, e.record), /payer intent/);
  const contractRelay = d.prepareDirectConservationCall(e.c, addr(50), { ...request, intent: e.intent });
  assert.equal(d.validateDirectConservationExecutionTerms(contractRelay, facts, e.record).paymentLane, "signature");
  const signedPayer = d.prepareDirectConservationCall(e.c, actor, { ...request, intent: e.intent, payerSignature: "0x12" });
  assert.equal(d.validateDirectConservationExecutionTerms(signedPayer, facts, e.record).paymentLane, "signature");
  for (const change of [{ maxAmount: e.config.price - 1n }, { saleRef: id("wrong") }, { expectedPrimaryPolicyHash: id("wrong") }, { asset: addr(99) }, { payer: addr(99) }, { deadline: 999n }]) {
    const plan = d.prepareDirectConservationCall(e.c, addr(50), { ...request, intent: { ...e.intent, ...change } });
    assert.throws(() => d.validateDirectConservationExecutionTerms(plan, facts, e.record));
  }
});

test("native free purchase remains a mint and all native/auction nonce-zero writes reject", () => {
  const c = coordinates("native-fixed");
  const a = { ...native(), price: 0n };
  const request = { productKind: c.productKind, kind: "buy", authorization: a, ...signedData };
  const plan = d.prepareDirectConservationCall(c, actor, request);
  assert.equal(plan.call.value, 0n);
  assert.equal(d.directConservationMintBatch(plan).payer, actor);
  assert.throws(() => d.prepareDirectConservationCall(c, addr(90), request), /literal caller/);
  for (const productKind of ["native-fixed", "english-auction"]) {
    assert.throws(() => d.prepareDirectConservationCall(coordinates(productKind), actor, { productKind, kind: "cancelAuthorization", nonce: ZeroHash }));
  }
  const b = { core: c.core, coreCodeHash: id("core"), mintManager: addr(5), mintManagerCodeHash: id("manager"), deploymentChainId: chainId, productKind: d.DIRECT_CONSERVATION_PRODUCT_KINDS[c.productKind] };
  assert.equal(d.directConservationReceiptLookupHash(b, c.product, id("unknown"), blank(productReceiptType)), ZeroHash);
  assert.notEqual(d.directConservationReceiptHash(b, c.product, id("unknown"), blank(productReceiptType)), ZeroHash);
});

test("original mint batches retain auction custody and independently signed payer/beneficiary", () => {
  const n = d.prepareDirectConservationCall(coordinates("native-fixed"), actor, { productKind: "native-fixed", kind: "buy", authorization: native(), ...signedData });
  const e = erc20();
  const ep = d.prepareDirectConservationCall(e.c, actor, { productKind: "erc20-fixed", kind: "buy", authorization: e.authorization, ...signedData, intent: e.intent, payerSignature: "0x" });
  const a = d.prepareDirectConservationCall(coordinates("english-auction"), addr(88), { productKind: "english-auction", kind: "createAuction", authorization: auctionAuth(), ...signedData });
  const batches = [d.directConservationMintBatch(n), d.directConservationMintBatch(ep, e.record), d.directConservationMintBatch(a)];
  for (const batch of batches) {
    assert.equal(batch.authorizer, ZeroAddress);
    assert.equal(batch.resolverData, "0x");
    assert.deepEqual(batch.tokenData, [data]);
    assert.equal(batch.collectionId, cid);
    assert.ok(Object.isFrozen(batch.initialRecipients));
  }
  assert.deepEqual(batches[0].initialRecipients, [native().recipient]);
  assert.deepEqual(batches[1].beneficiaries, [e.authorization.recipient]);
  assert.equal(batches[2].payer, ZeroAddress);
  assert.deepEqual(batches[2].initialRecipients, [a.coordinates.product]);
  assert.deepEqual(batches[2].beneficiaries, [auctionAuth().artist]);
  assert.equal(batches[2].contextHash, d.directConservationAuctionTypedData(a.coordinates, auctionAuth()).digest);
  assert.throws(() => d.directConservationMintBatch(ep));
  assert.throws(() => d.directConservationMintBatch(ep, { ...e.record, saleNonce: e.record.saleNonce + 1n }));
  assert.throws(() => d.directConservationMintBatch(ep, { ...e.record, config: { ...e.config, price: 901n } }));
});

test("auction zero reserve, rounded increment, strict bidding end and no-bid terminal statuses", () => {
  const auction = { ...blank(abi.auction.getFunction("auction").outputs[0]), artist: actor, startTime: 100n, endTime: 200n, minBidIncrementBps: 1n };
  assert.equal(d.directConservationMinimumBid(auction), 1n);
  assert.equal(d.directConservationMinimumBid({ ...auction, highestBid: 10001n }), 10003n);
  assert.equal(d.directConservationAuctionStatus(auction, 99n), 1n);
  assert.equal(d.directConservationAuctionStatus(auction, 199n), 2n);
  assert.equal(d.directConservationAuctionStatus(auction, 200n), 3n);
  assert.equal(d.directConservationAuctionStatus({ ...auction, highestBid: 1n }, 200n), 4n);
  assert.equal(d.directConservationAuctionStatus({ ...auction, settled: true }, 200n), 5n);
  assert.equal(d.directConservationAuctionStatus({ ...auction, settled: true, highestBid: 1n }, 200n), 6n);
  assert.equal(d.directConservationAuctionStatus({ ...auction, settled: true, cancelled: true }, 200n), 7n);
  assert.throws(() => d.directConservationMinimumBid({ ...auction, highestBid: (1n << 256n) - 1n }));
});

test("inclusive purchase deadlines differ from auction creation end and registry deprecation boundaries", () => {
  const plan = d.prepareDirectConservationCall(coordinates("native-fixed"), actor, { productKind: "native-fixed", kind: "buy", authorization: native(), ...signedData });
  d.validateDirectConservationExecutionTerms(plan, { timestamp: 1000n, signerEpoch: 5n });
  assert.throws(() => d.validateDirectConservationExecutionTerms(plan, { timestamp: 1001n, signerEpoch: 5n }));
  assert.throws(() => d.validateDirectConservationExecutionTerms(plan, { timestamp: 1000n, signerEpoch: 6n }));
  const ap = d.prepareDirectConservationCall(coordinates("english-auction"), actor, { productKind: "english-auction", kind: "createAuction", authorization: auctionAuth(), ...signedData });
  d.validateDirectConservationExecutionTerms(ap, { timestamp: 999n, signerEpoch: 5n });
  assert.throws(() => d.validateDirectConservationExecutionTerms(ap, { timestamp: 1000n, signerEpoch: 5n }));
  const facts = { status: 2n, registeredAt: 5n, statusUpdatedAt: 100n, revision: 7n, timestamp: 200n };
  d.validateDirectConservationAdmission("english-auction", 99n, 6n, facts);
  assert.throws(() => d.validateDirectConservationAdmission("english-auction", 100n, 6n, facts));
  assert.throws(() => d.validateDirectConservationAdmission("english-auction", 99n, 7n, facts));
  assert.throws(() => d.validateDirectConservationAdmission("native-fixed", 99n, 6n, facts));
  d.validateDirectConservationAdmission("native-fixed", 200n, 7n, { ...facts, status: 1n });
  assert.throws(() => d.validateDirectConservationAdmission("erc20-fixed", 199n, 7n, { ...facts, status: 1n }));
});

test("DIRECT key/product receipt exclude runtime bindings while full floor history retains them", () => {
  const bindings = { ...populated(bindingsType), core: floor.core, deploymentChainId: chainId, productKind: d.DIRECT_CONSERVATION_PRODUCT_KINDS["native-fixed"] };
  const receipt = populated(productReceiptType);
  const adapter = addr(2), authorizationId = id("authorization");
  const key = d.directConservationKey(bindings, adapter, authorizationId);
  const expected = keccak256(coder.encode(["bytes32", "uint256", "address", "address", "bytes32", "bytes32"], [id("6529STREAM_DIRECT_PRIMARY_SALE_KEY_V1"), chainId, floor.core, adapter, bindings.productKind, authorizationId]));
  assert.equal(key, expected);
  const original = d.directConservationReceiptHash(bindings, adapter, authorizationId, receipt);
  const changed = { ...bindings, coreCodeHash: id("later core"), mintManager: addr(99), mintManagerCodeHash: id("later manager") };
  assert.equal(d.directConservationKey(changed, adapter, authorizationId), key);
  assert.equal(d.directConservationReceiptHash(changed, adapter, authorizationId, receipt), original);
  assert.notEqual(d.directConservationKey({ ...bindings, productKind: d.DIRECT_CONSERVATION_PRODUCT_KINDS["english-auction"] }, adapter, authorizationId), key);
  const history = { ...populated(floorType), bindings, sale: receipt };
  assert.notEqual(d.directConservationFloorReceiptHash(floor, history), d.directConservationFloorReceiptHash(floor, { ...history, bindings: changed }));
  assert.equal(d.directConservationFloorReceiptHash(floor, history), d.directConservationFloorReceiptHash(floor, { ...history, receiptHash: ZeroHash }));
});

test("reused first/release history authenticates old origin without substituting the current sale", () => {
  const bindings = { ...populated(bindingsType), core: floor.core, deploymentChainId: chainId, productKind: d.DIRECT_CONSERVATION_PRODUCT_KINDS["native-fixed"] };
  const sale = { ...populated(productReceiptType), collectionId: cid, asset: ZeroAddress };
  const tier = id("MUSEUM_GRADE_LITE");
  const first = { ...populated(firstType), collectionId: cid, effectiveTier: tier, recorder: addr(90), settlementKey: id("older universal key"), recordedAt: 10n };
  first.receiptHash = d.directConservationFirstSaleReceiptHash(floor, first);
  const release = { ...populated(releaseType), collectionId: cid, effectiveTier: tier, recorder: addr(91), settlementKey: id("older other direct key"), recordedAt: 11n };
  release.releaseKey = d.directConservationReleaseKey(chainId, floor.core, cid, release.context);
  release.receiptHash = d.directConservationReleaseReceiptHash(floor, release);
  const receipt = {
    ...populated(floorType),
    adapter: addr(2),
    bindings,
    sale,
    effectiveTier: tier,
    authorizationId: id("current auth"),
    firstSaleReceiptHash: first.receiptHash,
    releaseReceiptHash: release.receiptHash,
    recordedAt: 200n
  };
  receipt.directKey = d.directConservationKey(bindings, receipt.adapter, receipt.authorizationId);
  receipt.originalReceiptHash = d.directConservationReceiptHash(bindings, receipt.adapter, receipt.authorizationId, sale);
  receipt.receiptHash = d.directConservationFloorReceiptHash(floor, receipt);
  const result = d.validateDirectConservationHistory(floor, receipt, first, release);
  assert.equal(result.factsVerified, false);
  assert.equal(result.firstSale.recorder, addr(90));
  assert.notEqual(result.firstSale.settlementKey, result.receipt.directKey);
  assert.throws(() => d.validateDirectConservationHistory(floor, receipt, first, null));
  assert.throws(() => d.validateDirectConservationHistory(floor, receipt, { ...first, recordedAt: 200n }, release));
  assert.throws(() => d.validateDirectConservationHistory(floor, receipt, first, { ...release, facts: { ...release.facts, mediaEvidenceHash: id("changed") } }));
});

test("semantic release key and source append exclude only their original documentary fields", () => {
  const context = populated(ParamType.from(d.DIRECT_CONSERVATION_RELEASE_CONTEXT_TUPLE));
  const key = d.directConservationReleaseKey(chainId, floor.core, cid, context);
  assert.equal(d.directConservationReleaseKey(chainId, floor.core, cid, { ...context, sourceContextHash: id("later source") }), key);
  for (const field of ["scopeSubject", "membershipHash", "mediaInventoryHash", "scriptSourceHash"]) {
    assert.notEqual(d.directConservationReleaseKey(chainId, floor.core, cid, { ...context, [field]: id(`other ${field}`) }), key);
  }
  const source = populated(abi.floor.getFunction("sourceAt").outputs[0]);
  const head = d.directConservationSourceInitialHash(floor);
  const appended = d.directConservationSourceAppendHash(head, 1n, source);
  assert.equal(d.directConservationSourceAppendHash(head, 1n, { ...source, admittedAt: 0n, actionId: ZeroHash }), appended);
  assert.notEqual(d.directConservationSourceAppendHash(head, 1n, { ...source, configurationHash: id("new") }), appended);
});

test("finite historical reads accept raw unknown keys but reject wallet floor writes and cross-product APIs", () => {
  const c = coordinates("native-fixed");
  const read = d.prepareDirectConservationRead(c, { kind: "directPrimarySaleReceipt", authorizationId: ZeroHash });
  assert.equal(read.data, abi.directReceipt.encodeFunctionData("directPrimarySaleReceipt", [ZeroHash]));
  assert.equal(read.value, 0n);
  const first = d.prepareDirectConservationFloorRead(floor, { kind: "firstSale", collectionId: 0n });
  assert.equal(first.data, abi.floor.encodeFunctionData("firstSale", [0n]));
  const release = d.prepareDirectConservationFloorRead(floor, { kind: "releaseFloorReceipt", releaseKey: ZeroHash });
  assert.equal(release.data, abi.floor.encodeFunctionData("releaseFloorReceipt", [ZeroHash]));
  assert.throws(() => d.prepareDirectConservationFloorRead(floor, { kind: "recordDirectPrimarySale", authorizationId: id("a") }));
  assert.throws(() => d.prepareDirectConservationRead(c, { kind: "saleRecord", saleId: ZeroHash }));
  assert.throws(() => d.prepareDirectConservationRead(c, { kind: "minimumBid", tokenId: 0n }));
  assert.throws(() => d.prepareDirectConservationFloorRead(floor, { kind: "sourceAt", sourceId: 1n << 64n }));
  let receiptId = 0n;
  for (const fragment of abi.directReceipt.fragments) {
    if (fragment.type === "function" && fragment.name !== "supportsInterface") {
      receiptId ^= BigInt(abi.directReceipt.getFunction(fragment.format("sighash")).selector);
    }
  }
  assert.equal(d.DIRECT_CONSERVATION_RECEIPT_INTERFACE_ID, `0x${receiptId.toString(16).padStart(8, "0")}`);
});

test("reviewed requests snapshot nested inputs and reject calldata/value/product injection", () => {
  const c = coordinates("native-fixed");
  const request = { productKind: "native-fixed", kind: "buy", authorization: native(), ...signedData };
  const plan = d.prepareDirectConservationCall(c, actor, request);
  const originalData = plan.call.data;
  request.authorization.price = 2n;
  c.product = addr(99);
  assert.equal(plan.call.data, originalData);
  assert.notEqual(plan.request.authorization.price, 2n);
  assert.throws(() => d.normalizeDirectConservationCall({ ...plan, call: { ...plan.call, value: 0n } }));
  assert.throws(() => d.normalizeDirectConservationCall({ ...plan, call: { ...plan.call, data: "0x" } }));
  assert.throws(() => d.normalizeDirectConservationCall({ ...plan, factsVerified: true }));
  assert.throws(() => d.prepareDirectConservationCall(coordinates("erc20-fixed"), actor, request));
  assert.throws(() => d.prepareDirectConservationCall(coordinates("native-fixed"), actor, { ...request, transport: "permit2" }));
  assert.throws(() => d.prepareDirectConservationCall(coordinates("native-fixed"), actor, { ...request, tokenData: "0xab" }));
  assert.throws(() => d.prepareDirectConservationCall(coordinates("native-fixed"), actor, { ...request, platformSignature: `0x${"00".repeat(d.DIRECT_CONSERVATION_MAX_SIGNATURE_BYTES + 1)}` }));
});
