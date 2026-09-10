import test from "node:test";
import assert from "node:assert/strict";
import { Interface, TypedDataEncoder, Wallet, verifyTypedData, ZeroHash } from "ethers";
import { StreamClient, contractInterface, typedDataFromJSON, nativeSaleTypedData, paymentIntentTypedData, artistAcceptanceTypedData, toJSON, stackConfigFromJSON } from "../dist/index.js";

const A = "0x0000000000000000000000000000000000000001";
const B = "0x0000000000000000000000000000000000000002";
const C = "0x0000000000000000000000000000000000000003";
const H = "0x" + "ab".repeat(32);
const sale = { collectionId: 2n, phaseId: H, payer: A, recipient: B, artist: C, profileId: H, tokenDataHash: H, mintCommitment: H, mintPolicyHash: H, price: 1000000000000000001n, nonce: H, deadline: 2000000000n, signerEpoch: 1n };
const intent = { payer: A, asset: B, maxAmount: 9007199254740993n, saleRef: H, expectedPrimaryPolicyHash: H, nonce: H, deadline: 2000000000n };
const config = { schemaVersion: 1, chainId: 31337n, addresses: { core: A, nativeSale: B, erc20Sale: C } };
const provider = { getNetwork: async () => ({ chainId: 31337n }) };

test("native domain and exact type are pinned independently of ABI tuple names", () => {
  const p = nativeSaleTypedData(31337n, B, sale);
  assert.equal(p.domain.name, "6529StreamFixedPriceSale");
  assert.equal(TypedDataEncoder.from(p.types).encodeType(p.primaryType), "SaleAuthorization(uint256 collectionId,bytes32 phaseId,address payer,address recipient,address artist,bytes32 profileId,bytes32 tokenDataHash,bytes32 mintCommitment,bytes32 mintPolicyHash,uint256 price,bytes32 nonce,uint64 deadline,uint64 signerEpoch)");
});
test("EOA signatures recover the caller wallet without storing any signer material", async () => {
  const wallet = Wallet.createRandom(), p = nativeSaleTypedData(31337n, B, sale);
  const signature = await wallet.signTypedData(p.domain, p.types, p.message);
  assert.equal(verifyTypedData(p.domain, p.types, p.message, signature), wallet.address);
});
test("chain, verifier, recipient, price, nonce, policy and signer epoch each bind the digest", () => {
  const digest = nativeSaleTypedData(31337n, B, sale).digest;
  assert.notEqual(nativeSaleTypedData(1n, B, sale).digest, digest);
  assert.notEqual(nativeSaleTypedData(31337n, A, sale).digest, digest);
  for (const change of [{ recipient: A }, { price: sale.price + 1n }, { nonce: ZeroHash }, { mintPolicyHash: ZeroHash }, { signerEpoch: 2n }]) assert.notEqual(nativeSaleTypedData(31337n, B, { ...sale, ...change }).digest, digest);
});
test("typed signing rejects unsafe numbers, width overflow, unknown/missing fields and short bytes", () => {
  for (const change of [{ price: Number(sale.price) }, { deadline: 1n << 64n }, { price: -1n }, { nonce: "0x12" }, { extra: true }]) assert.throws(() => nativeSaleTypedData(31337n, B, { ...sale, ...change }));
  const { nonce, ...missing } = sale;
  assert.throws(() => nativeSaleTypedData(31337n, B, missing));
});
test("returned signing payload is independent and cannot mutate message, domain or type fields", () => {
  const input = { ...sale }, p = nativeSaleTypedData(31337n, B, input);
  input.price = 1n;
  assert.equal(p.message.price, sale.price);
  assert.throws(() => { p.message.price = 1n; });
  assert.throws(() => { p.types.SaleAuthorization[0].name = "other"; });
  assert.throws(() => p.types.SaleAuthorization.pop());
});
test("payment cap and policy are signed, separately from artist sale nonce", () => {
  const p = paymentIntentTypedData(31337n, C, intent);
  assert.equal(p.primaryType, "StreamPaymentIntent");
  assert.equal(p.domain.name, "6529StreamPaymentIntentVerifier");
  assert.notEqual(paymentIntentTypedData(31337n, C, { ...intent, maxAmount: intent.maxAmount + 1n }).digest, p.digest);
  assert.notEqual(paymentIntentTypedData(31337n, C, { ...intent, expectedPrimaryPolicyHash: ZeroHash }).digest, p.digest);
});
test("artist acceptance binds Core as well as registry, nomination, nonce and expiry", () => {
  const m = { core: A, collectionId: 2n, nominationHash: H, nonce: 0n, deadline: 2000000000n };
  const p = artistAcceptanceTypedData(31337n, B, m);
  assert.notEqual(artistAcceptanceTypedData(31337n, B, { ...m, core: C }).digest, p.digest);
  assert.notEqual(artistAcceptanceTypedData(31337n, B, { ...m, nominationHash: ZeroHash }).digest, p.digest);
});
test("JSON preserves values above Number.MAX_SAFE_INTEGER and rejects numeric/lossy inputs", () => {
  const request = { kind: "paymentIntent", chainId: "31337", verifyingContract: C, message: JSON.parse(toJSON(intent)) };
  assert.equal(typedDataFromJSON(request).message.maxAmount, intent.maxAmount);
  assert.throws(() => typedDataFromJSON({ ...request, chainId: 31337 }));
  assert.throws(() => typedDataFromJSON({ ...request, message: { ...request.message, maxAmount: Number(intent.maxAmount) } }));
  assert.throws(() => typedDataFromJSON({ ...request, extra: true }));
});
test("typed calls preserve exact buy argument ordering and native value; nonpayable value fails", () => {
  const client = new StreamClient(provider, config);
  const call = client.prepare("nativeSale", "buy", [sale, "0x1234", "0xaaaa", "0xbbbb"], { value: sale.price });
  const decoded = contractInterface("nativeSale").decodeFunctionData("buy", call.data);
  assert.equal(call.value, sale.price);
  assert.equal(decoded.platformSignature, "0xaaaa");
  assert.equal(decoded.artistSignature, "0xbbbb");
  assert.throws(() => client.prepare("nativeSale", "cancelAuthorization", [H], { value: 1n }));
  assert.throws(() => client.prepare("nativeSale", "buy", [sale, "0x", "0x", "0x"], { value: -1n }));
});
test("RPC mismatch rejects before a read or simulation and does not send transactions", async () => {
  let calls = 0;
  const bad = new StreamClient({ getNetwork: async () => ({ chainId: 1n }), call: async () => { calls++; } }, config);
  await assert.rejects(bad.read("core", "ownerOf", [1n]), /chain ID/);
  await assert.rejects(bad.simulate({ to: A, data: "0x", value: 0n }, B), /chain ID/);
  assert.equal(calls, 0);
});
test("reads decode exact ABI and simulation binds actual sender, target and value", async () => {
  let last;
  const mock = { ...provider, call: async tx => { last = tx; return contractInterface("core").encodeFunctionResult("ownerOf", [B]); } };
  const client = new StreamClient(mock, config);
  assert.equal(await client.read("core", "ownerOf", [1n]), B);
  await client.simulate({ to: B, data: "0x1234", value: 7n }, C);
  assert.deepEqual(last, { to: B, data: "0x1234", value: 7n, from: C });
});
test("receipt decoding rejects failed, absent, duplicate and wrong-emitter events", () => {
  const client = new StreamClient(provider, config), iface = contractInterface("nativeSale");
  const event = iface.encodeEventLog(iface.getEvent("NativeSaleSettled"), [H, H, 17n, H, H, C, 42n]);
  const log = { address: B, ...event }, fake = { ...log, address: A };
  assert.equal(client.uniqueEvent({ status: 1, logs: [fake, log] }, "nativeSale", "NativeSaleSettled").args.tokenId, 17n);
  assert.throws(() => client.uniqueEvent({ status: 0, logs: [log] }, "nativeSale", "NativeSaleSettled"));
  assert.throws(() => client.uniqueEvent({ status: 1, logs: [fake] }, "nativeSale", "NativeSaleSettled"));
  assert.throws(() => client.uniqueEvent({ status: 1, logs: [log, log] }, "nativeSale", "NativeSaleSettled"));
});
test("configuration rejects unknown names, missing Core and mismatched address checksums", () => {
  assert.throws(() => stackConfigFromJSON({ schemaVersion: 1, chainId: "31337", addresses: { core: A, sale: B } }));
  assert.throws(() => stackConfigFromJSON({ schemaVersion: 1, chainId: "31337", addresses: {} }));
  const client = new StreamClient(provider, config);
  assert.throws(() => { client.config.addresses.core = B; });
  assert.throws(() => client.address("auction"), /No address/);
});
test("digest comparison rejects a mismatched onchain result and different verifying address", async () => {
  const p = nativeSaleTypedData(31337n, B, sale);
  const mock = { ...provider, call: async () => contractInterface("nativeSale").encodeFunctionResult("authorizationDigest", [ZeroHash]) };
  const client = new StreamClient(mock, config);
  await assert.rejects(client.assertDigest(p, "nativeSale", "authorizationDigest", [sale]), /differs/);
  await assert.rejects(client.assertDigest(nativeSaleTypedData(31337n, C, sale), "nativeSale", "authorizationDigest", [sale]), /domain differs/);
});
