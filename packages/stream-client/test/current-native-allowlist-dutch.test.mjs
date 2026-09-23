import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";
import { Interface, keccak256, toUtf8Bytes } from "ethers";
import {
  inspectNativeAllowlistDutchPurchase,
  inspectNativeAllowlistDutchRegistration,
  inspectNativeDutchRefund,
  inspectRegisteredNativeAllowlistDutchSale,
  nativeAllowlistDutchCharge,
  nativeAllowlistDutchConfigHash,
  nativeAllowlistDutchSaleId,
  nativeDutchAuthorizationPayload,
  nativeDutchOriginalConfigHash,
  nativeDutchScheduleHash,
  nativeDutchSchedulePrice,
  prepareNativeAllowlistDutchPurchase,
  prepareNativeAllowlistDutchRegistration,
  prepareNativeDutchRefund,
  simulateNativeAllowlistDutchPurchase,
  simulateNativeAllowlistDutchRegistration,
  simulateNativeDutchRefund,
} from "../dist/current-native-allowlist-dutch.js";

const chainId = 31337n;
const A = value => `0x${value.toString(16).padStart(40, "0")}`;
const h = value => keccak256(toUtf8Bytes(value));
const adapter = A(1), owner = A(2), payer = A(3), recipient = A(4), artist = A(5);
const core = A(6), manager = A(7), entropy = A(8), refundRecipient = A(9);
const counterId = h("price-counter"), otherCounterId = h("other-counter");
const schedule = Object.freeze({
  startPrice: 100n,
  restingPrice: 20n,
  startTime: 100n,
  endTime: 200n,
  decayKind: 0n,
  stepSeconds: 0n,
  stepAmount: 0n,
});
const config = Object.freeze({
  collectionId: 7n,
  phaseId: h("phase"),
  schedule,
  maxSaleQuantity: 10n,
  closesAt: 300n,
  declaredFree: true,
  mintPolicyHash: h("mint-policy"),
});
const hashFacts = Object.freeze({
  expectedPrimaryPolicyHash: h("registration-policy"),
  primaryAssignmentHash: h("assignment"),
});
const selectedProof = Object.freeze({
  maxCount: 2n,
  hasPriceOverride: true,
  priceOverride: 50n,
  proof: Object.freeze([h("sibling")]),
});
const ordinaryProof = Object.freeze({
  maxCount: 2n,
  hasPriceOverride: false,
  priceOverride: 0n,
  proof: Object.freeze([]),
});

function registration() {
  return prepareNativeAllowlistDutchRegistration(
    chainId,
    adapter,
    owner,
    4n,
    config,
    counterId,
    hashFacts,
  );
}

function authorization() {
  const prepared = registration();
  return Object.freeze({
    saleId: prepared.saleId,
    saleConfigHash: prepared.configHash,
    payer,
    executor: payer,
    recipient,
    artist,
    tokenDataHash: keccak256("0x1234"),
    mintCommitment: h("mint"),
    executionNonce: 1n,
    nonce: h("nonce"),
    deadline: 999999n,
    expectedPrimaryPolicyHash: h("current-policy"),
    unitPrice: 80n,
  });
}

function purchase() {
  return prepareNativeAllowlistDutchPurchase(
    chainId,
    adapter,
    config,
    counterId,
    hashFacts,
    authorization(),
    {
      tokenData: "0x1234",
      platformSignature: "0xaa",
      artistSignature: "0xbb",
      saleFundingMaximum: 80n,
      revealFeeAllowance: 10n,
      proofGroups: [
        { counterId: otherCounterId, proof: ordinaryProof },
        { counterId, proof: selectedProof },
      ],
    },
  );
}

async function fixtureInterfaces() {
  const fixture = JSON.parse(
    await readFile(new URL("./fixtures/current-native-moving-price-abi.json", import.meta.url)),
  );
  return {
    fixture,
    dutch: new Interface(fixture.abis.dutch),
    entropy: new Interface(fixture.abis.entropy),
  };
}

function result() {
  return [
    2n,
    77n,
    50n,
    7n,
    33n,
    h("execution"),
    h("root"),
    h("operation"),
    h("settlement"),
    false,
  ];
}

function provider(ifaces, controls = {}) {
  const preparedRegistration = registration();
  const preparedPurchase = purchase();
  return {
    getNetwork: async () => ({ chainId }),
    call: async transaction => {
      assert.equal(transaction.blockTag, 123);
      let parsed;
      let iface;
      parsed = ifaces.dutch.parseTransaction({ data: transaction.data });
      if (parsed !== null) {
        iface = ifaces.dutch;
      } else {
        parsed = ifaces.entropy.parseTransaction({ data: transaction.data });
        iface = ifaces.entropy;
      }
      switch (parsed.name) {
        case "owner":
          return iface.encodeFunctionResult(parsed.fragment, [controls.wrongOwner ? A(99) : owner]);
        case "nextSaleNonce":
          return iface.encodeFunctionResult(parsed.fragment, [controls.wrongNonce ? 5n : 4n]);
        case "saleIdFor":
          return iface.encodeFunctionResult(parsed.fragment, [preparedRegistration.saleId]);
        case "core":
          return iface.encodeFunctionResult(parsed.fragment, [core]);
        case "mintManager":
          return iface.encodeFunctionResult(parsed.fragment, [manager]);
        case "entropyCoordinator":
          return iface.encodeFunctionResult(parsed.fragment, [entropy]);
        case "paused":
          return iface.encodeFunctionResult(parsed.fragment, [Boolean(controls.adapterPaused)]);
        case "registerAllowlistDutchSale":
          return iface.encodeFunctionResult(parsed.fragment, [preparedRegistration.saleId]);
        case "saleRecord":
          return iface.encodeFunctionResult(parsed.fragment, [[
            config,
            4n,
            controls.wrongConfigHash ? h("wrong") : preparedRegistration.configHash,
            preparedRegistration.scheduleHash,
            hashFacts.expectedPrimaryPolicyHash,
            hashFacts.primaryAssignmentHash,
            [10n, 3n],
            controls.soldOut ? 10n : 1n,
            Boolean(controls.closed),
            Boolean(controls.salePaused),
          ]]);
        case "allowlistPriceCounter":
          return iface.encodeFunctionResult(parsed.fragment, [
            controls.wrongCounter ? h("wrong-counter") : counterId,
          ]);
        case "currentPrice":
          return iface.encodeFunctionResult(parsed.fragment, [controls.schedulePrice ?? 70n]);
        case "authorizationDigest":
          return iface.encodeFunctionResult(parsed.fragment, [
            controls.wrongDigest ? h("wrong-digest") : preparedPurchase.payload.digest,
          ]);
        case "collectionRevealPolicy":
          return iface.encodeFunctionResult(parsed.fragment, [[
            true,
            0n,
            h("reveal-role"),
            40n,
            controls.fee ?? 7n,
          ]]);
        case "purchaseWithAllowlist":
          assert.equal(transaction.from.toLowerCase(), payer.toLowerCase());
          assert.equal(transaction.value, 90n);
          if (controls.purchaseReject) {
            throw new Error("execution reverted: InvalidSaleAllowlistProof");
          }
          return iface.encodeFunctionResult(parsed.fragment, [
            controls.wrongResult ? [...result().slice(0, 2), 51n, ...result().slice(3)] : result(),
          ]);
        case "refundableBalance":
          return iface.encodeFunctionResult(parsed.fragment, [33n]);
        case "claimRefund":
          assert.equal(transaction.from.toLowerCase(), payer.toLowerCase());
          return "0x";
        default:
          throw new Error(`unexpected ${parsed.name}`);
      }
    },
  };
}

test("compiler fixture pins the exact moving-price capture and Dutch/entropy methods", async () => {
  const { fixture, dutch, entropy: entropyInterface } = await fixtureInterfaces();
  assert.equal(fixture.sourceCommit, "2dc3ea7ee35d4e5d698a2245bed54fcb03665819");
  assert.equal(fixture.sourceTree, "f5cb1a0abd375bbaa087df409775150a884d3767");
  assert.equal(fixture.sourceCount, 290);
  assert.equal(fixture.inputSha256, "996210da666b0f63930cf10f20ac61c4397bc2451b8931e1690c6432d4811ae6");
  assert.equal(fixture.outputSha256, "ad0f34dc0c3ee118d6d5fc117263902d5294f9933b90aef46508ab40ba65cf06");
  assert.equal(fixture.abis.dutch.length, 15);
  for (const selection of fixture.selections.dutch.methods) {
    assert.ok(dutch.getFunction(selection).selector);
  }
  assert.ok(entropyInterface.getFunction("collectionRevealPolicy").selector);
});

test("pure hashes and original Dutch EIP-712 payload retain the pinned fields", () => {
  const prepared = registration();
  assert.equal(
    prepared.saleId,
    nativeAllowlistDutchSaleId(chainId, adapter, config.collectionId, config.phaseId, 4n),
  );
  assert.equal(
    prepared.scheduleHash,
    nativeDutchScheduleHash(chainId, adapter, prepared.saleId, schedule),
  );
  assert.equal(
    prepared.originalConfigHash,
    nativeDutchOriginalConfigHash(prepared.saleId, config, prepared.scheduleHash, hashFacts),
  );
  assert.equal(
    prepared.configHash,
    nativeAllowlistDutchConfigHash(prepared.originalConfigHash, counterId),
  );
  const payload = nativeDutchAuthorizationPayload(chainId, adapter, authorization());
  assert.equal(payload.domain.name, "6529StreamNativeDutchSale");
  assert.equal(payload.primaryType, "DutchAuthorization");
  assert.equal(payload.message.unitPrice, 80n);
});

test("linear and stepped schedule prices preserve exact rounding and boundaries", () => {
  assert.equal(nativeDutchSchedulePrice(schedule, 50n), 100n);
  assert.equal(nativeDutchSchedulePrice(schedule, 125n), 80n);
  assert.equal(nativeDutchSchedulePrice(schedule, 199n), 21n);
  assert.equal(nativeDutchSchedulePrice(schedule, 200n), 20n);
  const stepped = {
    ...schedule,
    decayKind: 1n,
    stepSeconds: 30n,
    stepAmount: 25n,
  };
  assert.equal(nativeDutchSchedulePrice(stepped, 129n), 100n);
  assert.equal(nativeDutchSchedulePrice(stepped, 130n), 75n);
  assert.equal(nativeDutchSchedulePrice(stepped, 199n), 25n);
  assert.equal(nativeDutchSchedulePrice(stepped, 200n), 20n);
});

test("allowlist price is the minimum of schedule and enabled leaf with declared-free zero", () => {
  assert.deepEqual(nativeAllowlistDutchCharge(70n, true, selectedProof), {
    overridden: true,
    schedulePrice: 70n,
    chargedAmount: 50n,
  });
  assert.equal(nativeAllowlistDutchCharge(40n, true, selectedProof).chargedAmount, 40n);
  assert.equal(nativeAllowlistDutchCharge(70n, true, ordinaryProof).chargedAmount, 70n);
  assert.equal(
    nativeAllowlistDutchCharge(70n, true, { ...selectedProof, priceOverride: 0n }).chargedAmount,
    0n,
  );
  assert.throws(
    () => nativeAllowlistDutchCharge(70n, false, { ...selectedProof, priceOverride: 0n }),
    /not declared free/,
  );
});

test("registration inspection binds owner/nonce/id and post-registration readback binds hash facts", async () => {
  const ifaces = await fixtureInterfaces();
  const prepared = registration();
  const current = provider(ifaces);
  const inspected = await inspectNativeAllowlistDutchRegistration(
    current,
    prepared,
    { blockTag: 123 },
  );
  assert.equal(inspected.mintManager.toLowerCase(), manager.toLowerCase());
  assert.equal(
    await simulateNativeAllowlistDutchRegistration(current, prepared, { blockTag: 123 }),
    prepared.saleId,
  );
  assert.equal(
    (await inspectRegisteredNativeAllowlistDutchSale(current, prepared, { blockTag: 123 })).configHash,
    prepared.configHash,
  );
  await assert.rejects(
    inspectNativeAllowlistDutchRegistration(
      provider(ifaces, { wrongNonce: true }),
      prepared,
      { blockTag: 123 },
    ),
    /Live Dutch sale nonce/,
  );
  await assert.rejects(
    inspectRegisteredNativeAllowlistDutchSale(
      provider(ifaces, { wrongConfigHash: true }),
      prepared,
      { blockTag: 123 },
    ),
    /Stored Dutch allowlist record/,
  );
});

test("purchase inspection binds record/digest/fee and exact payer simulation validates proofs", async () => {
  const ifaces = await fixtureInterfaces();
  const prepared = purchase();
  const current = provider(ifaces);
  const parsed = ifaces.dutch.parseTransaction({ data: prepared.call.data });
  assert.equal(parsed.name, "purchaseWithAllowlist");
  assert.equal(prepared.call.value, 90n);
  assert.equal(parsed.args[0].authorization.unitPrice, 80n);
  const inspected = await inspectNativeAllowlistDutchPurchase(
    current,
    prepared,
    { blockTag: 123 },
  );
  assert.equal(inspected.currentSchedulePrice, 70n);
  assert.equal(inspected.expectedCharge.chargedAmount, 50n);
  assert.equal(inspected.revealFeePerTokenWei, 7n);
  assert.equal(inspected.effectiveSaleFundingMaximum, 83n);
  assert.equal(
    (await simulateNativeAllowlistDutchPurchase(current, prepared, { blockTag: 123 })).tokenId,
    77n,
  );
  await assert.rejects(
    inspectNativeAllowlistDutchPurchase(
      provider(ifaces, { wrongCounter: true }),
      prepared,
      { blockTag: 123 },
    ),
    /Stored Dutch allowlist record/,
  );
  await assert.rejects(
    inspectNativeAllowlistDutchPurchase(
      provider(ifaces, { fee: 11n }),
      prepared,
      { blockTag: 123 },
    ),
    /fee allowance/,
  );
  await assert.rejects(
    simulateNativeAllowlistDutchPurchase(
      provider(ifaces, { purchaseReject: true }),
      prepared,
      { blockTag: 123 },
    ),
    /InvalidSaleAllowlistProof/,
  );
  await assert.rejects(
    simulateNativeAllowlistDutchPurchase(
      provider(ifaces, { wrongResult: true }),
      prepared,
      { blockTag: 123 },
    ),
    /payment result/,
  );
  await assert.rejects(
    inspectNativeAllowlistDutchPurchase(
      current,
      { ...prepared, call: { ...prepared.call, value: 89n } },
      { blockTag: 123 },
    ),
    /canonical reconstruction/,
  );
});

test("refund inspection reads only the credited payer lane and simulation preserves fixed caller", async () => {
  const ifaces = await fixtureInterfaces();
  const prepared = prepareNativeDutchRefund(adapter, registration().saleId, payer, refundRecipient);
  const calls = [];
  const base = provider(ifaces);
  const refundProvider = {
    call: async transaction => {
      calls.push(ifaces.dutch.parseTransaction({ data: transaction.data }).name);
      return base.call(transaction);
    },
  };
  assert.equal(
    (await inspectNativeDutchRefund(refundProvider, prepared, { blockTag: 123 })).refundableBalance,
    33n,
  );
  assert.equal(await simulateNativeDutchRefund(refundProvider, prepared, { blockTag: 123 }), 33n);
  assert.deepEqual(calls, ["refundableBalance", "refundableBalance", "claimRefund"]);
  assert.throws(
    () => prepareNativeDutchRefund(adapter, registration().saleId, payer, adapter),
    /cannot be the adapter/,
  );
});

test("strict inputs reject coercion, widths, ambiguous prices, caller substitution and async mutation", async () => {
  assert.doesNotThrow(() => prepareNativeAllowlistDutchPurchase(
    chainId,
    adapter,
    config,
    counterId,
    hashFacts,
    { ...authorization(), tokenDataHash: authorization().tokenDataHash.toUpperCase().replace("0X", "0x") },
    purchase().input,
  ));
  assert.throws(
    () => prepareNativeAllowlistDutchRegistration(
      chainId,
      adapter,
      owner,
      4n,
      { ...config, declaredFree: "true" },
      counterId,
      hashFacts,
    ),
    /boolean/,
  );
  assert.throws(
    () => nativeDutchScheduleHash(
      chainId,
      adapter,
      registration().saleId,
      { ...schedule, decayKind: 1n, stepSeconds: 2n ** 32n, stepAmount: 1n },
    ),
    /uint32/,
  );
  assert.throws(
    () => prepareNativeAllowlistDutchPurchase(
      chainId,
      adapter,
      config,
      counterId,
      hashFacts,
      { ...authorization(), executor: A(99) },
      purchase().input,
    ),
    /payer, executor/,
  );
  assert.throws(
    () => prepareNativeAllowlistDutchPurchase(
      chainId,
      adapter,
      config,
      counterId,
      hashFacts,
      authorization(),
      {
        ...purchase().input,
        proofGroups: [
          { counterId, proof: selectedProof },
          { counterId: otherCounterId, proof: { ...selectedProof, priceOverride: 1n } },
        ],
      },
    ),
    /Only the selected/,
  );
  const ifaces = await fixtureInterfaces();
  const prepared = purchase();
  const mutable = {
    ...prepared,
    input: {
      ...prepared.input,
      proofGroups: prepared.input.proofGroups.map(group => ({
        ...group,
        proof: { ...group.proof, proof: [...group.proof.proof] },
      })),
    },
  };
  let release;
  const wait = new Promise(resolve => { release = resolve; });
  const base = provider(ifaces);
  const delayed = {
    ...base,
    getNetwork: async () => {
      await wait;
      return { chainId };
    },
  };
  const options = { blockTag: 123 };
  const pending = inspectNativeAllowlistDutchPurchase(delayed, mutable, options);
  options.blockTag = 124;
  mutable.input.proofGroups[0].proof.proof.push(h("later"));
  release();
  assert.equal((await pending).expectedCharge.chargedAmount, 50n);
});
