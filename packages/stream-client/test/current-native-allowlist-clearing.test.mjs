import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { Interface, ZeroAddress, ZeroHash, id, keccak256 } from "ethers";
import {
  CurrentNativeAllowlistClearingClient,
  nativeAllowlistClearingConfigHash,
  nativeAllowlistClearingResolverData,
  nativeClearingAuthorizationTypedData,
  nativeClearingOriginalConfigHash,
  nativeClearingPurchaseId,
  nativeClearingSaleId,
  nativeClearingScheduleHash,
  nativeClearingSchedulePrice,
  nativeClearingWindowPolicyHash,
} from "../dist/current-native-allowlist-clearing.js";

const fixture = JSON.parse(readFileSync(new URL("./fixtures/current-native-moving-price-abi.json", import.meta.url), "utf8"));
const clearingAbi = new Interface(fixture.abis.clearing);
const entropyAbi = new Interface(fixture.abis.entropy);
const A = value => `0x${BigInt(value).toString(16).padStart(40, "0")}`;
const chainId = 31337n, adapter = A(1), owner = A(2), payer = A(3), recipient = A(4), artist = A(5), entropy = A(6);
const blockHash = id("clearing block"), counterId = id("price counter"), baseline = id("baseline");
const code = "0x60016000", phaseId = id("phase"), saleNonce = 7n;

function config() {
  return { collectionId: 99n, phaseId,
    schedule: { startPrice: 1_000n, restingPrice: 100n, startTime: 1_000n, endTime: 1_100n,
      decayKind: 0n, stepSeconds: 0n, stepAmount: 0n },
    maxSaleQuantity: 10n, closesAt: 1_200n, finalizationWindowSeconds: 100n,
    absoluteEscapeDeadline: 1_400n, primaryPolicyMode: 1n, mintPolicyHash: id("mint policy") };
}
function coordinates() {
  const c = config(), saleId = nativeClearingSaleId(chainId, adapter, c.collectionId, c.phaseId, saleNonce);
  const scheduleHash = nativeClearingScheduleHash(chainId, adapter, saleId, c.schedule);
  const windowHash = nativeClearingWindowPolicyHash(c);
  const original = nativeClearingOriginalConfigHash(chainId, adapter, saleId, c, baseline);
  return { c, saleId, scheduleHash, windowHash, original,
    configHash: nativeAllowlistClearingConfigHash(original, counterId) };
}
function authorization() {
  const x = coordinates();
  return { saleId: x.saleId, saleConfigHash: x.configHash, payer, executor: payer, recipient, artist,
    tokenDataHash: keccak256("0x1234"), mintCommitment: id("mint commitment"), purchaseNonce: 1n,
    executionNonce: 12n, nonce: id("authorization nonce"), deadline: 1_100n,
    expectedPrimaryPolicyHash: baseline, unitPrice: 700n, hasPriceOverride: true,
    priceOverride: (1n << 255n) + 500n, windowPolicyHash: x.windowHash,
    maximumNominalFinalizeBy: 1_300n, absoluteEscapeDeadline: 1_400n };
}
function proof(sibling = id("initial sibling")) {
  return { maxCount: 2n, hasPriceOverride: true, priceOverride: (1n << 255n) + 500n, proof: [sibling] };
}

function rpc() {
  const x = coordinates();
  const state = { mutate: undefined, mutationError: undefined, expectedResolver: undefined, revealFee: 5n, refund: 17n };
  const record = { config: x.c, saleNonce, configHash: x.configHash, priceScheduleHash: x.scheduleHash,
    windowPolicyHash: x.windowHash, expectedPrimaryPolicyHash: baseline,
    lifecycle: { saleCreatedAt: 900n, saleAdapterRegistryRevision: 4n }, soldOutAt: 0n, earlyCloseAt: 0n,
    priceFixedAt: 0n, terminalAt: 0n, terminalToll: 0n, artistId: ZeroHash,
    bindingGeneration: 0n, bindingHash: ZeroHash };
  const provider = {
    async getNetwork() { return { chainId }; },
    async getBlock() {
      if (state.mutate) { const mutate = state.mutate; state.mutate = undefined; mutate(); }
      return { number: 10, hash: blockHash, timestamp: 1_050 };
    },
    async getCode(target) { assert.equal(target, adapter); return code; },
    async call(tx) {
      if (tx.to === entropy) {
        const parsed = entropyAbi.parseTransaction(tx);
        assert.equal(parsed.name, "collectionRevealPolicy");
        return entropyAbi.encodeFunctionResult(parsed.name, [[true, 0n, ZeroHash, 20n, state.revealFee]]);
      }
      assert.equal(tx.to, adapter);
      const parsed = clearingAbi.parseTransaction(tx);
      let output;
      if (parsed.name === "owner") output = [owner];
      else if (parsed.name === "nextSaleNonce") output = [saleNonce];
      else if (parsed.name === "saleIdFor") output = [x.saleId];
      else if (parsed.name === "registerAllowlistClearingSale") output = [x.saleId];
      else if (parsed.name === "saleRecord") output = [record];
      else if (parsed.name === "allowlistPriceCounter") output = [counterId];
      else if (parsed.name === "currentPrice") output = [550n];
      else if (parsed.name === "nextPurchaseNonce") output = [1n];
      else if (parsed.name === "entropyCoordinator") output = [entropy];
      else if (parsed.name === "authorizationDigest") {
        output = [nativeClearingAuthorizationTypedData(chainId, adapter, Object.fromEntries(
          Object.keys(authorization()).map(key => [key, parsed.args[0][key]]))).digest];
      } else if (parsed.name === "eip712Domain") {
        output = ["0x0f", "6529StreamNativeClearingSale", "1", chainId, adapter, ZeroHash, []];
      } else if (parsed.name === "purchaseWithAllowlist") {
        if (state.expectedResolver) assert.equal(parsed.args[1], state.expectedResolver);
        const value = BigInt(tx.value), charged = 550n;
        output = [[nativeClearingPurchaseId(chainId, adapter, x.saleId, payer, 1n), 123n, charged, 100n,
          450n, state.revealFee, value - charged - state.revealFee, id("execution"), id("operation root"),
          id("operation id"), id("settlement key"), false]];
      } else if (parsed.name === "refundableBalance") output = [state.refund];
      else throw new Error(`unexpected clearing method ${parsed.name}`);
      return clearingAbi.encodeFunctionResult(parsed.name, output);
    },
  };
  return { provider, state, x };
}

test("pure producers preserve full-width ceilings, exact windows and schedule rounding", () => {
  const x = coordinates(), a = authorization();
  assert.equal(nativeClearingSchedulePrice(x.c.schedule, 1_050n), 550n);
  assert.equal(nativeClearingSchedulePrice({ ...x.c.schedule, decayKind: 1n, stepSeconds: 9n, stepAmount: 80n }, 1_050n), 600n);
  assert.equal(nativeClearingAuthorizationTypedData(chainId, adapter, a).message.priceOverride, (1n << 255n) + 500n);
  assert.equal(nativeAllowlistClearingResolverData([{ counterId, proof: proof() }], counterId, a).length > 66, true);
  assert.throws(() => nativeAllowlistClearingResolverData([{ counterId, proof: { ...proof(), priceOverride: 500n } }], counterId, a), /equal/);
});

test("registration uses current owner and nonce while labeling its supplied baseline", async () => {
  const { provider, state, x } = rpc(), client = new CurrentNativeAllowlistClearingClient(chainId, adapter);
  state.mutate = () => {
    try { client.adapter = A(99); } catch (error) { state.mutationError = error; }
  };
  const prepared = await client.prepareRegistration(provider, x.c, counterId, baseline, owner);
  assert(state.mutationError instanceof TypeError);
  assert.equal(client.adapter, adapter);
  assert.equal(prepared.saleId, x.saleId);
  assert.equal(prepared.configHash, x.configHash);
  assert.equal(prepared.baselineProvenance, "caller-supplied-unverified-until-sale-record");
  assert.equal(clearingAbi.parseTransaction(prepared.call).name, "registerAllowlistClearingSale");
});

test("purchase reconstructs stored hashes and payable simulation retains the original proof snapshot", async () => {
  const { provider, state } = rpc(), client = new CurrentNativeAllowlistClearingClient(chainId, adapter);
  const mutableProof = proof(), input = { tokenData: "0x1234", platformSignature: "0x12", artistSignature: "0x34",
    maximumPaymentAllowance: 540n, revealFeeAllowance: 20n, proofGroups: [{ counterId, proof: mutableProof }] };
  state.expectedResolver = nativeAllowlistClearingResolverData(input.proofGroups, counterId, authorization());
  state.mutate = () => { mutableProof.proof[0] = id("mutated sibling"); };
  const prepared = await client.preparePurchase(provider, authorization(), input);
  assert.equal(prepared.chargedAmount, 550n);
  assert.equal(prepared.call.value, 560n);
  assert.equal(prepared.simulation.excessCredited, 5n);
  assert.equal(prepared.resolverData, state.expectedResolver);
  assert.equal(clearingAbi.parseTransaction(prepared.call).name, "purchaseWithAllowlist");
});

test("owed refund and original financial calls remain independent of new purchase admission", async () => {
  const { provider, x } = rpc(), client = new CurrentNativeAllowlistClearingClient(chainId, adapter);
  provider.getCode = async () => { throw new Error("refund must not inspect current runtime"); };
  assert.equal(await client.readRefund(provider, x.saleId, payer), 17n);
  assert.equal(clearingAbi.parseTransaction(client.claimRefund(x.saleId, payer, recipient).call).name, "claimRefund");
  assert.equal(clearingAbi.parseTransaction(client.fixClearingPrice(x.saleId, A(9)).call).name, "fixClearingPrice");
  assert.equal(clearingAbi.parseTransaction(client.settlePurchaseSupplement(id("purchase"), A(9)).call).name, "settlePurchaseSupplement");
  assert.equal(clearingAbi.parseTransaction(client.synchronizeRebate(x.saleId, payer, A(9)).call).name, "synchronizeRebate");
});
