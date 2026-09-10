import test from "node:test";
import assert from "node:assert/strict";
import { keccak256, ZeroAddress } from "ethers";
import { purchaseNative } from "../examples/native-purchase.mjs";
import { purchaseERC20 } from "../examples/erc20-purchase.mjs";
import { acceptArtist } from "../examples/artist-acceptance.mjs";
import { createAuction } from "../examples/auction.mjs";
import { StreamClient, nativeSaleTypedData, erc20SaleTypedData, artistAcceptanceTypedData, auctionTypedData } from "../dist/index.js";

const addresses = {
  core: "0x0000000000000000000000000000000000000001", nativeSale: "0x0000000000000000000000000000000000000002",
  erc20Sale: "0x0000000000000000000000000000000000000003", auction: "0x0000000000000000000000000000000000000004",
  artistRegistry: "0x0000000000000000000000000000000000000005",
};
const payerAddress = "0x0000000000000000000000000000000000000011";
const artistAddress = "0x0000000000000000000000000000000000000012";
const platformAddress = "0x0000000000000000000000000000000000000013";
const submitterAddress = "0x0000000000000000000000000000000000000014";
const asset = "0x0000000000000000000000000000000000000015";
const H = "0x" + "11".repeat(32), tokenData = "0x1234";
const sale = { collectionId: 2n, phaseId: H, payer: payerAddress, recipient: payerAddress, artist: artistAddress, profileId: H, tokenDataHash: keccak256(tokenData), mintCommitment: H, mintPolicyHash: H, price: 10n, nonce: H, deadline: 2000000000n, signerEpoch: 1n };
const authorization = { saleId: H, saleConfigHash: H, payer: payerAddress, recipient: payerAddress, artist: artistAddress, tokenDataHash: keccak256(tokenData), mintCommitment: H, nonce: H, deadline: 2000000000n, signerEpoch: 1n };
const intent = { payer: payerAddress, asset, maxAmount: 10n, saleRef: H, expectedPrimaryPolicyHash: H, nonce: H, deadline: 2000000000n };

function fixture(kind, digest) {
  const trace = [], receipt = { status: 1, hash: H, logs: [] };
  const client = new StreamClient({ getNetwork: async () => ({ chainId: 31337n }) }, { schemaVersion: 1, chainId: 31337n, addresses });
  client.read = async (contract, method) => {
    if (method === "platformSigner") return platformAddress;
    if (method === "acceptedArtist") return artistAddress;
    if (method === "signerEpoch") return 1n;
    if (method === "phasePolicyHash") return H;
    if (method === "ownerOf") return kind === "auction" ? addresses.auction : payerAddress;
    if (method === "acceptanceNonces") return 0n;
    if (method === "attribution") return { nominatedArtist: artistAddress, artist: ZeroAddress, nominationHash: H };
    if (method === "isPaymentIntentNonceUsed") return false;
    if (method === "primaryPolicy") return { policyHash: H, profileId: H, wallet: platformAddress };
    if (method === "saleRecord") return { saleNonce: 1n, cancelled: false, configHash: H, config: { collectionId: 2n, asset, price: 10n, revenueClass: H, expectedPrimaryPolicyHash: H } };
    throw Error(`Unexpected ${contract}.${method}`);
  };
  client.assertDigest = async payload => trace.push({ kind: "digest", primaryType: payload.primaryType });
  client.simulate = async (call, sender) => trace.push({ kind: "simulate", call, sender });
  client.uniqueEvent = () => ({ args: { collectionId: 2n, artist: artistAddress, acceptanceHash: digest, authorizationDigest: digest, tokenId: 17n, profileId: H, wallet: platformAddress, asset, amount: 10n, operationRoot: H, saleId: H } });
  const wallet = (address, signature) => ({
    getAddress: async () => address,
    signTypedData: async (_domain, _types, message) => { trace.push({ kind: "sign", address, message }); return signature; },
    sendTransaction: async call => { trace.push({ kind: "send", address, call }); return { hash: H, wait: async () => { trace.push({ kind: "wait" }); return receipt; } }; },
  });
  return { client, trace, wallets: { payer: wallet(payerAddress, "0x1111"), artist: wallet(artistAddress, "0x2222"), platform: wallet(platformAddress, "0x3333"), submitter: wallet(submitterAddress, "0x4444"), relayer: wallet(submitterAddress, "0x4444") } };
}

test("native example signs both parties, simulates payer/value, then submits one ABI-correct transaction", async () => {
  const f = fixture("nativeSale", nativeSaleTypedData(31337n, addresses.nativeSale, sale).digest);
  assert.equal((await purchaseNative(f.client, f.wallets, sale, tokenData, { onSubmitted: hash => f.trace.push({ kind: "journal", hash }) })).tokenId, 17n);
  assert.deepEqual(f.trace.filter(x => x.kind === "sign").map(x => x.address), [platformAddress, artistAddress]);
  const simulation = f.trace.find(x => x.kind === "simulate"), send = f.trace.find(x => x.kind === "send");
  assert.equal(simulation.sender, payerAddress);
  assert.equal(send.call.value, 10n);
  assert.equal(send.address, payerAddress);
  assert.equal(f.trace.filter(x => x.kind === "send").length, 1);
  assert.equal(f.trace.find(x => x.kind === "journal").hash, H);
  assert.ok(f.trace.findIndex(x => x.kind === "journal") < f.trace.findIndex(x => x.kind === "wait"));
});
test("ERC20 example separates platform/artist consent from payer intent and submits through relayer", async () => {
  const f = fixture("erc20Sale", erc20SaleTypedData(31337n, addresses.erc20Sale, authorization).digest);
  assert.equal((await purchaseERC20(f.client, f.wallets, authorization, intent, tokenData)).tokenId, 17n);
  assert.deepEqual(f.trace.filter(x => x.kind === "sign").map(x => x.address), [platformAddress, artistAddress, payerAddress]);
  assert.equal(f.trace.find(x => x.kind === "simulate").sender, submitterAddress);
  assert.equal(f.trace.find(x => x.kind === "send").call.value, 0n);
  for (const change of [{ maxAmount: 9n }, { saleRef: "0x" + "22".repeat(32) }, { payer: artistAddress }]) {
    const bad = fixture("erc20Sale", H);
    await assert.rejects(purchaseERC20(bad.client, bad.wallets, authorization, { ...intent, ...change }, tokenData), /Payer intent/);
    assert.equal(bad.trace.filter(x => x.kind === "sign" || x.kind === "send").length, 0);
  }
});
test("artist acceptance example signs as artist and sends as a different relayer", async () => {
  const message = { core: addresses.core, collectionId: 2n, nominationHash: H, nonce: 0n, deadline: 2000000000n };
  const f = fixture("artistAcceptance", artistAcceptanceTypedData(31337n, addresses.artistRegistry, message).digest);
  assert.equal((await acceptArtist(f.client, f.wallets, 2n, message.deadline)).artist, artistAddress);
  assert.equal(f.trace.find(x => x.kind === "sign").address, artistAddress);
  assert.equal(f.trace.find(x => x.kind === "send").address, submitterAddress);
});
test("auction example creates escrow and rejects token-byte substitution before any wallet prompt", async () => {
  const auction = { collectionId: 2n, phaseId: H, artist: artistAddress, profileId: H, tokenDataHash: keccak256(tokenData), mintCommitment: H, mintPolicyHash: H, reservePrice: 10n, startTime: 1900000000n, endTime: 1900000010n, extensionWindow: 5n, minBidIncrementBps: 500n, nonce: H, deadline: 2000000000n, signerEpoch: 1n };
  const f = fixture("auction", auctionTypedData(31337n, addresses.auction, auction).digest);
  assert.equal((await createAuction(f.client, f.wallets, auction, tokenData)).tokenId, 17n);
  const bad = fixture("auction", H);
  await assert.rejects(createAuction(bad.client, bad.wallets, auction, "0x5678"), /Token bytes/);
  assert.equal(bad.trace.filter(x => x.kind === "sign" || x.kind === "send").length, 0);
});
