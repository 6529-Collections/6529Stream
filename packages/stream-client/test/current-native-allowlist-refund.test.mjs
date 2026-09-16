import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";
import { Interface, keccak256, toUtf8Bytes } from "ethers";
import {
  inspectNativeAllowlistRefundPurchase,
  inspectNativeAllowlistRefundRegistration,
  inspectRegisteredNativeAllowlistRefundSale,
  nativeAllowlistRefundCharge,
  nativeAllowlistRefundConfigHash,
  nativeAllowlistRefundSaleId,
  nativeRefundOriginalConfigHash,
  nativeRefundPurchaseAuthorizationPayload,
  nativeRefundPurchaseId,
  nativeRefundWindowPolicyHash,
  prepareNativeAllowlistRefundPurchase,
  prepareNativeAllowlistRefundRegistration,
  prepareNativeRefundClaim,
  prepareNativeRefundFinalize,
  prepareNativeRefundRefund,
  prepareNativeRefundSynchronize,
  prepareNativeRefundUnlock,
  readNativeRefundCredit,
  simulateNativeAllowlistRefundPurchase,
  simulateNativeAllowlistRefundRegistration,
} from "../dist/current-native-allowlist-refund.js";

const chainId = 31337n;
const A = value => `0x${value.toString(16).padStart(40, "0")}`;
const h = value => keccak256(toUtf8Bytes(value));
const ZERO32 = `0x${"00".repeat(32)}`;
const adapter = A(1), owner = A(2), payer = A(3), recipient = A(4), artist = A(5);
const core = A(6), manager = A(7), entropy = A(8), claimRecipient = A(9);
const counterId = h("refund-price-counter"), otherCounterId = h("other-counter");
const expectedPrimaryPolicyHash = h("registration-policy");
const config = Object.freeze({
  collectionId: 7n,
  phaseId: h("phase"),
  price: 120n,
  maxSaleQuantity: 10n,
  startsAt: 100n,
  endsAt: 200n,
  refundWindowSeconds: 3_600n,
  finalizationWindowSeconds: 86_400n,
  primaryPolicyMode: 1n,
  mintPolicyHash: h("mint-policy"),
});
const policy = Object.freeze({ counterId, allowFree: true });
const selectedProof = Object.freeze({
  maxCount: 2n,
  hasPriceOverride: true,
  priceOverride: 100n,
  proof: Object.freeze([h("selected-sibling")]),
});
const ordinaryProof = Object.freeze({
  maxCount: 1n,
  hasPriceOverride: false,
  priceOverride: 0n,
  proof: Object.freeze([]),
});

function registration() {
  return prepareNativeAllowlistRefundRegistration(
    chainId,
    adapter,
    owner,
    4n,
    config,
    policy,
    expectedPrimaryPolicyHash,
  );
}

function authorization() {
  const prepared = registration();
  return Object.freeze({
    saleId: prepared.saleId,
    saleConfigHash: prepared.configHash,
    payer,
    recipient,
    artist,
    tokenDataHash: keccak256("0x1234"),
    mintCommitment: h("mint"),
    purchaseNonce: 1n,
    nonce: ZERO32,
    price: config.price,
    deadline: 999_999n,
    windowPolicyHash: prepared.windowPolicyHash,
    maximumNominalFinalizeBy: 999_000n,
    absoluteEscapeDeadline: 1_100_000n,
    expectedPrimaryPolicyHash: h("current-policy"),
  });
}

function purchase(overrides = {}) {
  return prepareNativeAllowlistRefundPurchase(
    chainId,
    adapter,
    config,
    policy,
    expectedPrimaryPolicyHash,
    authorization(),
    {
      tokenData: "0x1234",
      platformSignature: "0xaa",
      artistSignature: "0xbb",
      priceFundingMaximum: 90n,
      revealFeeAllowance: 20n,
      proofGroups: [
        { counterId: otherCounterId, proof: ordinaryProof },
        { counterId, proof: selectedProof },
      ],
      ...overrides,
    },
  );
}

async function fixtureInterfaces() {
  const fixture = JSON.parse(
    await readFile(new URL("./fixtures/current-native-refund-price-abi.json", import.meta.url)),
  );
  return {
    fixture,
    refund: new Interface(fixture.abis.refund),
    entropy: new Interface(fixture.abis.entropy),
  };
}

function provider(ifaces, controls = {}) {
  const preparedRegistration = registration();
  const preparedPurchase = purchase();
  return {
    getNetwork: async () => ({ chainId }),
    call: async transaction => {
      assert.equal(transaction.blockTag, 123);
      let parsed = ifaces.refund.parseTransaction({ data: transaction.data });
      let iface = ifaces.refund;
      if (parsed === null) {
        parsed = ifaces.entropy.parseTransaction({ data: transaction.data });
        iface = ifaces.entropy;
      }
      switch (parsed.name) {
        case "owner":
          return iface.encodeFunctionResult(parsed.fragment, [controls.wrongOwner ? A(99) : owner]);
        case "nextSaleNonce":
          return iface.encodeFunctionResult(parsed.fragment, [controls.wrongSaleNonce ? 5n : 4n]);
        case "core":
          return iface.encodeFunctionResult(parsed.fragment, [core]);
        case "mintManager":
          return iface.encodeFunctionResult(parsed.fragment, [manager]);
        case "entropyCoordinator":
          return iface.encodeFunctionResult(parsed.fragment, [entropy]);
        case "registerAllowlistRefundSale":
          assert.equal(transaction.from.toLowerCase(), owner.toLowerCase());
          return iface.encodeFunctionResult(parsed.fragment, [preparedRegistration.saleId]);
        case "refundSaleRecord":
          return iface.encodeFunctionResult(parsed.fragment, [[
            config,
            4n,
            controls.wrongConfigHash ? h("wrong-config") : preparedRegistration.configHash,
            preparedRegistration.windowPolicyHash,
            [1_000n, 3n],
            controls.soldOut ? config.maxSaleQuantity : 1n,
            expectedPrimaryPolicyHash,
          ]]);
        case "allowlistRefundSalePolicy":
          return iface.encodeFunctionResult(parsed.fragment, [[
            controls.wrongCounter ? h("wrong-counter") : counterId,
            true,
          ]]);
        case "refundPurchaseAuthorizationDigest":
          return iface.encodeFunctionResult(parsed.fragment, [
            controls.wrongDigest ? h("wrong-digest") : preparedPurchase.payload.digest,
          ]);
        case "nextPurchaseNonce":
          return iface.encodeFunctionResult(parsed.fragment, [controls.wrongPurchaseNonce ? 2n : 1n]);
        case "collectionRevealPolicy":
          return iface.encodeFunctionResult(parsed.fragment, [[
            true,
            0n,
            h("reveal-role"),
            40n,
            controls.fee ?? 5n,
          ]]);
        case "purchaseAllowlistRefundWindow":
          assert.equal(transaction.from.toLowerCase(), payer.toLowerCase());
          assert.equal(transaction.value, 110n);
          if (controls.purchaseReject) {
            throw new Error("execution reverted: InvalidMintAllowlistProof");
          }
          return iface.encodeFunctionResult(parsed.fragment, [
            controls.wrongPurchaseId ? h("wrong-purchase") : preparedPurchase.expectedPurchaseId,
          ]);
        case "refundableBalance":
          return iface.encodeFunctionResult(parsed.fragment, [37n]);
        default:
          throw new Error(`unexpected ${parsed.name}`);
      }
    },
  };
}

test("refund fixture pins the accepted compiler capture and selected methods", async () => {
  const { fixture, refund, entropy: entropyInterface } = await fixtureInterfaces();
  assert.equal(fixture.sourceCommit, "90e68ebfc62e63eb46c6f23b23c32f3ccf2957a8");
  assert.equal(fixture.sourceTree, "1011eb3e1470dab54cf770904f0fb3ac749777fe");
  assert.equal(fixture.sourceCount, 291);
  assert.equal(fixture.inputSha256, "43a641fea018f20fe0119d4c4003a0c4b5dacc335b49eb13263c3e338a711a09");
  assert.equal(fixture.outputSha256, "2c5d098727bcba813eb8215a78be8efc2faedd333628946691be3548d729210f");
  assert.equal(fixture.abis.refund.length, 21);
  for (const selection of fixture.selections.refund.methods) {
    assert.ok(refund.getFunction(selection).selector);
  }
  assert.ok(entropyInterface.getFunction("collectionRevealPolicy").selector);
});

test("pure refund helpers retain original public price and exact allowlist charge", () => {
  const preparedRegistration = registration();
  assert.equal(
    preparedRegistration.saleId,
    nativeAllowlistRefundSaleId(chainId, adapter, config.collectionId, config.phaseId, 4n),
  );
  assert.equal(preparedRegistration.windowPolicyHash, nativeRefundWindowPolicyHash(config));
  assert.equal(
    preparedRegistration.originalConfigHash,
    nativeRefundOriginalConfigHash(preparedRegistration.saleId, config, expectedPrimaryPolicyHash),
  );
  assert.equal(
    preparedRegistration.configHash,
    nativeAllowlistRefundConfigHash(preparedRegistration.originalConfigHash, policy),
  );
  const auth = authorization();
  const payload = nativeRefundPurchaseAuthorizationPayload(chainId, adapter, auth);
  assert.equal(payload.message.price, 120n);
  assert.equal(payload.message.nonce, ZERO32);
  assert.equal(
    nativeRefundPurchaseId(chainId, adapter, auth.saleId, payer, auth.purchaseNonce),
    purchase().expectedPurchaseId,
  );
  assert.deepEqual(nativeAllowlistRefundCharge(120n, policy, selectedProof), {
    overridden: true,
    publicPrice: 120n,
    chargedPrice: 100n,
  });
  assert.equal(purchase().call.value, 110n);
});

test("refund input boundaries reject coercion, undeclared free and forged packets", async () => {
  assert.throws(
    () => prepareNativeAllowlistRefundRegistration(
      chainId,
      adapter,
      owner,
      4n,
      { ...config, primaryPolicyMode: 0n },
      policy,
      expectedPrimaryPolicyHash,
    ),
    /ALLOW_CURRENT/,
  );
  assert.throws(
    () => nativeAllowlistRefundCharge(120n, { ...policy, allowFree: false }, {
      ...selectedProof,
      priceOverride: 0n,
    }),
    /not declared free/,
  );
  assert.throws(
    () => purchase({
      proofGroups: [
        { counterId: otherCounterId, proof: selectedProof },
        { counterId, proof: selectedProof },
      ],
    }),
    /Only the selected/,
  );
  const { refund, entropy: entropyInterface } = await fixtureInterfaces();
  const prepared = purchase();
  await assert.rejects(
    inspectNativeAllowlistRefundPurchase(
      provider({ refund, entropy: entropyInterface }),
      { ...prepared, call: { ...prepared.call, value: prepared.call.value + 1n } },
      { blockTag: 123 },
    ),
    /canonical reconstruction/,
  );
});

test("registration inspection pins owner and nonce, then requires stored record readback", async () => {
  const { refund, entropy: entropyInterface } = await fixtureInterfaces();
  const rpc = provider({ refund, entropy: entropyInterface });
  const inspected = await inspectNativeAllowlistRefundRegistration(
    rpc,
    registration(),
    { blockTag: 123 },
  );
  assert.equal(inspected.core, core);
  assert.match(inspected.limitations[0], /post-registration/);
  assert.equal(await simulateNativeAllowlistRefundRegistration(
    rpc,
    registration(),
    { blockTag: 123 },
  ), registration().saleId);
  assert.equal((await inspectRegisteredNativeAllowlistRefundSale(
    rpc,
    registration(),
    { blockTag: 123 },
  )).saleNonce, 4n);
  await assert.rejects(
    inspectNativeAllowlistRefundRegistration(
      provider({ refund, entropy: entropyInterface }, { wrongSaleNonce: true }),
      registration(),
      { blockTag: 123 },
    ),
    /sale nonce/,
  );
});

test("purchase inspection accepts fungible combined funding and simulates from payer", async () => {
  const { refund, entropy: entropyInterface } = await fixtureInterfaces();
  const rpc = provider({ refund, entropy: entropyInterface });
  const inspected = await inspectNativeAllowlistRefundPurchase(
    rpc,
    purchase(),
    { blockTag: 123 },
  );
  assert.equal(inspected.revealFeePerTokenWei, 5n);
  assert.equal(inspected.effectivePriceFundingMaximum, 105n);
  assert.equal(await simulateNativeAllowlistRefundPurchase(
    rpc,
    purchase(),
    { blockTag: 123 },
  ), purchase().expectedPurchaseId);
  await assert.rejects(
    inspectNativeAllowlistRefundPurchase(
      provider({ refund, entropy: entropyInterface }, { wrongDigest: true }),
      purchase(),
      { blockTag: 123 },
    ),
    /digest getter/,
  );
  await assert.rejects(
    inspectNativeAllowlistRefundPurchase(
      provider({ refund, entropy: entropyInterface }, { fee: 21n }),
      purchase(),
      { blockTag: 123 },
    ),
    /fee allowance/,
  );
});

test("lifecycle and credit helpers remain narrow unsigned calls without admission reads", async () => {
  const { refund, entropy: entropyInterface } = await fixtureInterfaces();
  const prepared = purchase();
  const purchaseId = prepared.expectedPurchaseId;
  const actions = [
    prepareNativeRefundFinalize(adapter, purchaseId, owner),
    prepareNativeRefundRefund(adapter, purchaseId, payer),
    prepareNativeRefundUnlock(adapter, purchaseId, 0n, owner),
    prepareNativeRefundSynchronize(adapter, purchaseId, owner),
    prepareNativeRefundClaim(adapter, prepared.authorization.saleId, payer, claimRecipient),
  ];
  assert.deepEqual(actions.map(action => action.kind), [
    "finalize",
    "refund",
    "unlock",
    "synchronize",
    "claim",
  ]);
  assert.deepEqual(actions.map(action => refund.parseTransaction({ data: action.call.data }).name), [
    "finalizeRefundWindow",
    "refundPurchase",
    "unlockRefund",
    "synchronizePurchaseWindow",
    "claimRefund",
  ]);
  assert.throws(
    () => prepareNativeRefundClaim(adapter, prepared.authorization.saleId, payer, adapter),
    /cannot be the adapter/,
  );
  assert.throws(
    () => prepareNativeRefundUnlock(adapter, purchaseId, 6n, owner),
    /Unsupported/,
  );
  assert.equal(await readNativeRefundCredit(
    provider({ refund, entropy: entropyInterface }),
    adapter,
    prepared.authorization.saleId,
    payer,
    { blockTag: 123 },
  ), 37n);
});
