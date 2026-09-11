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
const H = "0x" + "ab".repeat(32), tokenData = "0x1234";
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
  for (const change of [{ maxAmount: 9n }, { saleRef: "0x" + "cd".repeat(32) }, { payer: artistAddress }]) {
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
  for (const [method, changed, message] of [["signerEpoch", 2n, /Signer epoch changed/], ["phasePolicyHash", "0x" + "cd".repeat(32), /Phase policy changed/]]) {
    const stale = fixture("auction", H), read = stale.client.read;
    stale.client.read = async (contract, name, args) => {
      if (name === method) {
        assert.equal(contract, method === "signerEpoch" ? "auction" : "manager");
        assert.deepEqual(args, method === "signerEpoch" ? [] : [auction.collectionId, auction.phaseId]);
        return changed;
      }
      return read(contract, name, args);
    };
    await assert.rejects(createAuction(stale.client, stale.wallets, auction, tokenData), message);
    assert.equal(stale.trace.filter(x => ["sign", "simulate", "send"].includes(x.kind)).length, 0);
  }
});

const mixedHash = value => "0x" + [...value.slice(2)].map((c, i) => i % 2 ? c.toUpperCase() : c.toLowerCase()).join("");
const mixedHashes = message => Object.fromEntries(Object.entries(message).map(([key, value]) => [key, typeof value === "string" && /^0x[0-9a-f]{64}$/i.test(value) ? mixedHash(value) : value]));
const auctionTerms = () => ({ collectionId: 2n, phaseId: H, artist: artistAddress, profileId: H, tokenDataHash: keccak256(tokenData), mintCommitment: H, mintPolicyHash: H, reservePrice: 10n, startTime: 1900000000n, endTime: 1900000010n, extensionWindow: 5n, minBidIncrementBps: 500n, nonce: H, deadline: 2000000000n, signerEpoch: 1n });
function mixedReceipt(f) {
  const event = f.client.uniqueEvent;
  f.client.uniqueEvent = (...args) => {
    const values = { ...event(...args).args };
    // Input/policy IDs are mixed-case; their receipt IDs remain decoder-normalized lowercase.
    // Digests instead vary on the receipt side to exercise those comparisons independently.
    for (const field of ["authorizationDigest", "acceptanceHash"]) if (values[field]) values[field] = mixedHash(values[field]);
    return { args: values };
  };
}

test("native and auction examples accept mixed-case commitments and byte-identical receipt hashes", async () => {
  for (const [kind, terms, sign, execute] of [["nativeSale", sale, nativeSaleTypedData, purchaseNative], ["auction", auctionTerms(), auctionTypedData, createAuction]]) {
    const message = mixedHashes(terms), digest = sign(31337n, addresses[kind], message).digest;
    assert.equal(digest, sign(31337n, addresses[kind], terms).digest);
    const f = fixture(kind, digest); mixedReceipt(f);
    assert.equal((await execute(f.client, f.wallets, message, tokenData)).tokenId, 17n);
    assert.equal(f.trace.filter(x => x.kind === "sign").length, 2);
    assert.equal(f.trace.filter(x => x.kind === "send").length, 1);
  }
});

test("ERC20 example accepts equivalent sale, intent, policy and receipt hash representations", async () => {
  const message = mixedHashes(authorization), payerIntent = mixedHashes(intent);
  // Deliberately use opposite representations across the saleRef comparison.
  payerIntent.saleRef = H;
  const digest = erc20SaleTypedData(31337n, addresses.erc20Sale, message).digest;
  assert.equal(digest, erc20SaleTypedData(31337n, addresses.erc20Sale, authorization).digest);
  const f = fixture("erc20Sale", digest), read = f.client.read;
  f.client.read = async (...args) => {
    const value = await read(...args);
    if (args[1] === "saleRecord") return { ...value, config: { ...value.config, expectedPrimaryPolicyHash: mixedHash(H) } };
    if (args[1] === "primaryPolicy") return { ...value, profileId: mixedHash(H) };
    return value;
  };
  mixedReceipt(f);
  assert.equal((await purchaseERC20(f.client, f.wallets, message, payerIntent, tokenData)).tokenId, 17n);
  assert.equal(f.trace.filter(x => x.kind === "sign").length, 3);
  assert.equal(f.trace.filter(x => x.kind === "send").length, 1);
});

test("artist acceptance accepts the same nomination and receipt digest bytes in mixed case", async () => {
  const message = { core: addresses.core, collectionId: 2n, nominationHash: H, nonce: 0n, deadline: 2000000000n };
  const f = fixture("artistAcceptance", artistAcceptanceTypedData(31337n, addresses.artistRegistry, message).digest), read = f.client.read;
  f.client.read = async (...args) => { const value = await read(...args); return args[1] === "attribution" ? { ...value, nominationHash: mixedHash(H) } : value; };
  mixedReceipt(f);
  assert.equal((await acceptArtist(f.client, f.wallets, 2n, message.deadline)).artist, artistAddress);
  assert.equal(f.trace.filter(x => x.kind === "send").length, 1);
});

test("hash normalization rejects malformed input and preserves strict epoch validation before prompts", async () => {
  for (const value of ["0x", "0x" + "zz".repeat(32), "ab".repeat(32), H + "00", 1, null, { toLowerCase: () => H }]) {
    const f = fixture("auction", H);
    await assert.rejects(createAuction(f.client, f.wallets, { ...auctionTerms(), tokenDataHash: value }, tokenData), /Expected a bytes32 hash/);
    assert.equal(f.trace.filter(x => ["sign", "simulate", "send"].includes(x.kind)).length, 0);
  }
  for (const signerEpoch of ["1", 1, 2n]) {
    const f = fixture("auction", H);
    await assert.rejects(createAuction(f.client, f.wallets, { ...auctionTerms(), signerEpoch }, tokenData), /Signer epoch changed/);
    assert.equal(f.trace.filter(x => x.kind === "sign" || x.kind === "send").length, 0);
  }
});

test("hash normalization still rejects genuinely different or malformed receipt commitments", async () => {
  for (const [kind, terms, sign, execute, field] of [
    ["nativeSale", sale, nativeSaleTypedData, purchaseNative, "profileId"],
    ["auction", auctionTerms(), auctionTypedData, createAuction, "profileId"],
    ["erc20Sale", authorization, erc20SaleTypedData, (client, wallets, message, data) => purchaseERC20(client, wallets, message, intent, data), "saleId"],
  ]) {
    for (const wrong of ["0x" + "cd".repeat(32), "0x1234"]) {
      const f = fixture(kind, sign(31337n, addresses[kind], terms).digest), event = f.client.uniqueEvent;
      f.client.uniqueEvent = (...args) => ({ args: { ...event(...args).args, [field]: wrong } });
      await assert.rejects(execute(f.client, f.wallets, terms, tokenData), /receipt differs|Receipt differs|Expected a bytes32 hash/);
      assert.equal(f.trace.filter(x => x.kind === "send").length, 1);
    }
  }
  for (const wrong of ["0x" + "cd".repeat(32), "0x1234"]) {
    const message = { core: addresses.core, collectionId: 2n, nominationHash: H, nonce: 0n, deadline: 2000000000n };
    const f = fixture("artistAcceptance", artistAcceptanceTypedData(31337n, addresses.artistRegistry, message).digest), event = f.client.uniqueEvent;
    f.client.uniqueEvent = (...args) => ({ args: { ...event(...args).args, acceptanceHash: wrong } });
    await assert.rejects(acceptArtist(f.client, f.wallets, 2n, message.deadline), /Acceptance receipt differs|Expected a bytes32 hash/);
    assert.equal(f.trace.filter(x => x.kind === "send").length, 1);
  }
});
