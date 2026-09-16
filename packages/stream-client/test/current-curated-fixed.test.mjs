import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";
import { Interface, keccak256, toUtf8Bytes } from "ethers";
import {
  inspectCuratedFixedRegistration,
  inspectCuratedPublicPurchase,
  inspectCuratedSelectionCommit,
  inspectCuratedSelectionDeposit,
  inspectCuratedSelectionReveal,
  inspectRegisteredCuratedFixedSale,
  prepareCuratedContestSync,
  prepareCuratedExcessRefundClaim,
  prepareCuratedExcessRefundDelegatedClaim,
  prepareCuratedFixedCancel,
  prepareCuratedFixedRegistration,
  prepareCuratedMaturityUnlock,
  prepareCuratedPublicPurchase,
  prepareCuratedReasonUnlock,
  prepareCuratedSelectionCommit,
  prepareCuratedSelectionRefundClaim,
  prepareCuratedSelectionRefundDelegatedClaim,
  prepareCuratedSelectionReveal,
  readCuratedExcessRefundCredit,
  readCuratedFixedExecution,
  readCuratedSelectionRefundCredit,
  simulateCuratedFixedRegistration,
  simulateCuratedPublicPurchase,
  simulateCuratedSelectionCommit,
  simulateCuratedSelectionReveal,
} from "../dist/current-curated-fixed.js";
import {
  buildCuratedManifest,
  curatedSaleId,
} from "../dist/current-curated-content.js";

const chainId = 31337n;
const A = value => `0x${value.toString(16).padStart(40, "0")}`;
const h = value => keccak256(toUtf8Bytes(value));
const ZERO32 = `0x${"00".repeat(32)}`;
const adapter = A(1), owner = A(2), buyer = A(3), recipient = A(4), delegate = A(5);
const core = A(6), manager = A(7), resolver = A(8), artists = A(9), modules = A(10);
const gate = A(11), poster = A(12), claimRecipient = A(13);
const collectionId = 7n, phaseId = h("phase"), saleNonce = 4n;
const saleId = curatedSaleId(chainId, adapter, 0n, collectionId, phaseId, saleNonce);
const manifest = buildCuratedManifest({
  chainId,
  manager,
  adapter,
  saleId,
  collectionId,
  phaseId,
  counterId: h("content-counter"),
  rows: [
    { contentId: ZERO32, tokenDataHash: keccak256("0x"), previewURI: "ipfs://zero" },
    { contentId: h("work"), tokenDataHash: keccak256("0x1234"), previewURI: "ipfs://work" },
  ],
});
const sale = Object.freeze({
  collectionId,
  phaseId,
  price: 100n,
  poster,
  startsAt: 100n,
  endsAt: 200n,
  mintPolicyHash: h("mint-policy"),
  expectedPrimaryPolicyHash: h("primary-policy"),
  primaryPolicyMode: 0n,
  contentManifestRoot: manifest.publication.manifestRoot,
});
const emptyWindows = Object.freeze({
  commitOpen: 0n,
  commitClose: 0n,
  revealOpen: 0n,
  revealClose: 0n,
  absoluteEscape: 0n,
});
const publicConfiguration = Object.freeze({
  sale,
  mode: 1n,
  differentiatedContent: false,
  publicSelectionDisclosure: true,
  windows: emptyWindows,
});
const commitConfiguration = Object.freeze({
  sale: Object.freeze({ ...sale, primaryPolicyMode: 1n }),
  mode: 0n,
  differentiatedContent: true,
  publicSelectionDisclosure: false,
  windows: Object.freeze({
    commitOpen: 100n,
    commitClose: 120n,
    revealOpen: 130n,
    revealClose: 200n,
    absoluteEscape: 220n,
  }),
});
const selection = Object.freeze({
  content: manifest.selections[1],
  tokenData: "0x1234",
  mintCommitment: h("mint"),
  recipient,
  purchaseNonce: 1n,
});
const salt = ZERO32;

function registration(configuration = publicConfiguration) {
  return prepareCuratedFixedRegistration(
    chainId,
    adapter,
    owner,
    saleNonce,
    configuration,
  );
}

function publicPurchase() {
  return prepareCuratedPublicPurchase(
    chainId,
    adapter,
    buyer,
    saleId,
    publicConfiguration,
    selection,
    10n,
  );
}

function commitment() {
  return prepareCuratedSelectionCommit(
    chainId,
    adapter,
    buyer,
    saleId,
    commitConfiguration,
    selection.content,
    salt,
    selection.purchaseNonce,
  );
}

function reveal() {
  return prepareCuratedSelectionReveal(
    chainId,
    adapter,
    buyer,
    saleId,
    commitConfiguration,
    selection,
    salt,
    10n,
  );
}

async function fixtureInterface() {
  const fixture = JSON.parse(
    await readFile(new URL("./fixtures/current-curated-abi.json", import.meta.url)),
  );
  return { fixture, fixed: new Interface(fixture.abis.fixed) };
}

function execution(prepared, tokenId = 42n) {
  const leaf = prepared.expectedContentLeaf ?? prepared.contentLeaf;
  return [
    prepared.saleId,
    prepared.caller,
    prepared.selection.recipient,
    prepared.selection.purchaseNonce,
    h("authorization-id"),
    h("authorization-digest"),
    leaf,
    prepared.selection.content.tokenDataHash,
    prepared.selection.mintCommitment,
    prepared.configuration.sale.price,
    tokenId,
    h("settlement"),
    h("operation-root"),
    h("operation-id"),
  ];
}

function provider(fixed, configuration, controls = {}) {
  const preparedRegistration = registration(configuration);
  const preparedPublic = publicPurchase();
  const preparedCommit = commitment();
  const preparedReveal = reveal();
  return {
    getNetwork: async () => ({ chainId }),
    getBlock: async blockTag => ({ number: blockTag, timestamp: controls.timestamp ?? 50 }),
    call: async transaction => {
      assert.equal(transaction.blockTag, 123);
      const parsed = fixed.parseTransaction({ data: transaction.data });
      switch (parsed.name) {
        case "owner":
          return fixed.encodeFunctionResult(parsed.fragment, [controls.wrongOwner ? A(99) : owner]);
        case "nextSaleNonce":
          return fixed.encodeFunctionResult(parsed.fragment, [controls.wrongSaleNonce ? 5n : saleNonce]);
        case "saleIdFor":
          return fixed.encodeFunctionResult(parsed.fragment, [preparedRegistration.expectedSaleId]);
        case "fixedConfigurationHash":
          return fixed.encodeFunctionResult(parsed.fragment, [preparedRegistration.configurationHash]);
        case "core":
          return fixed.encodeFunctionResult(parsed.fragment, [core]);
        case "mintManager":
          return fixed.encodeFunctionResult(parsed.fragment, [manager]);
        case "revenueResolver":
          return fixed.encodeFunctionResult(parsed.fragment, [resolver]);
        case "artistRegistry":
          return fixed.encodeFunctionResult(parsed.fragment, [artists]);
        case "moduleRegistry":
          return fixed.encodeFunctionResult(parsed.fragment, [modules]);
        case "registerCuratedFixedSale":
          assert.equal(transaction.from.toLowerCase(), owner.toLowerCase());
          return fixed.encodeFunctionResult(parsed.fragment, [preparedRegistration.expectedSaleId]);
        case "fixedSaleConfiguration":
          return fixed.encodeFunctionResult(parsed.fragment, [configuration]);
        case "saleRecord":
          return fixed.encodeFunctionResult(parsed.fragment, [[
            configuration.sale,
            saleNonce,
            0n,
            preparedRegistration.configurationHash,
            [50n, 2n],
            h("artist-id"),
            1n,
            h("binding"),
            gate,
            h("gate-code"),
            h("gate-config"),
            manifest.publication.manifestHash,
            manifest.publication.counterId,
            h("counter-config"),
            controls.cancelled ? 2n : 1n,
          ]]);
        case "nextPurchaseNonce":
          return fixed.encodeFunctionResult(parsed.fragment, [controls.wrongPurchaseNonce ? 2n : 1n]);
        case "purchaseIdFor": {
          const prepared = configuration.mode === 1n ? preparedPublic : preparedCommit;
          return fixed.encodeFunctionResult(parsed.fragment, [prepared.expectedPurchaseId]);
        }
        case "saleRevealQuote":
          return fixed.encodeFunctionResult(parsed.fragment, [[
            A(14),
            h("entropy-code"),
            [true, 0n, h("reveal-role"), 20n, controls.fee ?? 7n],
          ]]);
        case "selectionCommitment":
          return fixed.encodeFunctionResult(parsed.fragment, [preparedCommit.commitment]);
        case "selectionWindows":
          return fixed.encodeFunctionResult(parsed.fragment, [[
            100n,
            120n,
            130n,
            200n,
            0n,
            0n,
            controls.commitLive ?? true,
            controls.revealLive ?? true,
            false,
            false,
            false,
            false,
            false,
            false,
          ]]);
        case "selectionDeposit":
          return fixed.encodeFunctionResult(parsed.fragment, [
            [100n, controls.committedBlock ?? 122n, controls.depositStatus ?? 1n],
            preparedCommit.expectedPurchaseId,
            1n,
          ]);
        case "purchaseSelectedContent":
          assert.equal(transaction.from.toLowerCase(), buyer.toLowerCase());
          assert.equal(transaction.value, 110n);
          return fixed.encodeFunctionResult(parsed.fragment, [
            execution(preparedPublic, controls.zeroTokenId ? 0n : 42n),
          ]);
        case "commitSelection":
          assert.equal(transaction.from.toLowerCase(), buyer.toLowerCase());
          assert.equal(transaction.value, 100n);
          return fixed.encodeFunctionResult(parsed.fragment, [preparedCommit.expectedPurchaseId]);
        case "revealSelection":
          assert.equal(transaction.from.toLowerCase(), buyer.toLowerCase());
          assert.equal(transaction.value, 10n);
          return fixed.encodeFunctionResult(parsed.fragment, [execution(preparedReveal)]);
        case "executionRecord":
          return fixed.encodeFunctionResult(parsed.fragment, [execution(preparedPublic)]);
        case "selectionRefundCredit":
          return fixed.encodeFunctionResult(parsed.fragment, [25n]);
        case "refundableBalance":
          return fixed.encodeFunctionResult(parsed.fragment, [3n]);
        default:
          throw new Error(`unexpected ${parsed.name}`);
      }
    },
  };
}

test("curated ABI fixture pins the final 128-source carrier capture", async () => {
  const { fixture, fixed } = await fixtureInterface();
  assert.equal(fixture.sourceCommit, "5605d019bc9cb933398f626df77b84d1cd2a51ba");
  assert.equal(fixture.sourceTree, "0b12c46b997a6682cd48e2d8d7049d55ff6d755d");
  assert.equal(fixture.sourceCount, 128);
  assert.equal(fixture.inputSha256, "d1db6188f922acc490973cae67fbfecdd4fcfb31df18b909901acb57bb6a8101");
  assert.equal(fixture.outputSha256, "a2783ea8778a84012c7c9b96d9983b434fdb75e6ceade1dbbe2bf8a26aa14ca7");
  assert.equal(fixture.abis.fixed.length, 33);
  for (const method of fixture.selections.fixed.methods) {
    assert.ok(fixed.getFunction(method).selector);
  }
});

test("fixed preparation preserves PUBLIC and COMMIT_REVEAL payment boundaries", () => {
  const publicPrepared = publicPurchase();
  const commitPrepared = commitment();
  const revealPrepared = reveal();
  assert.equal(publicPrepared.call.value, 110n);
  assert.equal(commitPrepared.call.value, 100n);
  assert.equal(revealPrepared.call.value, 10n);
  assert.equal(commitPrepared.salt, ZERO32);
  assert.equal(commitPrepared.expectedPurchaseId, revealPrepared.expectedPurchaseId);
  assert.notEqual(commitPrepared.expectedPurchaseId, h("operation-id"));
  assert.throws(
    () => prepareCuratedFixedRegistration(
      chainId,
      adapter,
      owner,
      saleNonce,
      { ...commitConfiguration, windows: { ...commitConfiguration.windows, commitClose: 131n } },
    ),
    /invalid policy or windows/,
  );
  assert.throws(
    () => prepareCuratedPublicPurchase(
      chainId,
      adapter,
      buyer,
      saleId,
      publicConfiguration,
      { ...selection, recipient: adapter },
      10n,
    ),
    /cannot be the adapter/,
  );
});

test("registration verifies future start, exact nonce/hash and post-registration record", async () => {
  const { fixed } = await fixtureInterface();
  const rpc = provider(fixed, publicConfiguration);
  const inspected = await inspectCuratedFixedRegistration(
    rpc,
    registration(),
    { blockTag: 123 },
  );
  assert.equal(inspected.dependencies.mintManager, manager);
  assert.equal(await simulateCuratedFixedRegistration(
    rpc,
    registration(),
    { blockTag: 123 },
  ), saleId);
  assert.equal((await inspectRegisteredCuratedFixedSale(
    rpc,
    registration(),
    { blockTag: 123 },
  )).saleNonce, saleNonce);
  await assert.rejects(
    inspectCuratedFixedRegistration(
      provider(fixed, publicConfiguration, { timestamp: 100 }),
      registration(),
      { blockTag: 123 },
    ),
    /strictly future/,
  );
});

test("PUBLIC inspection and same-block payer simulation preserve fee and selection", async () => {
  const { fixed } = await fixtureInterface();
  const rpc = provider(fixed, publicConfiguration, { timestamp: 150 });
  const inspected = await inspectCuratedPublicPurchase(
    rpc,
    publicPurchase(),
    { blockTag: 123 },
  );
  assert.equal(inspected.revealFeePerTokenWei, 7n);
  assert.equal((await simulateCuratedPublicPurchase(
    rpc,
    publicPurchase(),
    { blockTag: 123 },
  )).tokenId, 42n);
  const forged = publicPurchase();
  await assert.rejects(
    inspectCuratedPublicPurchase(
      rpc,
      { ...forged, call: { ...forged.call, value: 111n } },
      { blockTag: 123 },
    ),
    /canonical reconstruction/,
  );
  await assert.rejects(
    simulateCuratedPublicPurchase(
      provider(fixed, publicConfiguration, { timestamp: 150, zeroTokenId: true }),
      publicPurchase(),
      { blockTag: 123 },
    ),
    /positive uint256/,
  );
});

test("commit inspection binds price-only value, effective window and returned purchase ID", async () => {
  const { fixed } = await fixtureInterface();
  const rpc = provider(fixed, commitConfiguration);
  const inspected = await inspectCuratedSelectionCommit(
    rpc,
    commitment(),
    { blockTag: 123 },
  );
  assert.equal(inspected.windows.commitLive, true);
  assert.equal(await simulateCuratedSelectionCommit(
    rpc,
    commitment(),
    { blockTag: 123 },
  ), commitment().expectedPurchaseId);
  assert.equal((await inspectCuratedSelectionDeposit(
    rpc,
    commitment(),
    { blockTag: 123 },
  )).amount, 100n);
  await assert.rejects(
    inspectCuratedSelectionCommit(
      provider(fixed, commitConfiguration, { commitLive: false }),
      commitment(),
      { blockTag: 123 },
    ),
    /not live/,
  );
});

test("reveal inspection requires pending saved nonce, later block and fee-only value", async () => {
  const { fixed } = await fixtureInterface();
  const rpc = provider(fixed, commitConfiguration);
  const inspected = await inspectCuratedSelectionReveal(
    rpc,
    reveal(),
    { blockTag: 123 },
  );
  assert.equal(inspected.deposit.purchaseNonce, 1n);
  assert.equal(inspected.revealFeePerTokenWei, 7n);
  assert.equal((await simulateCuratedSelectionReveal(
    rpc,
    reveal(),
    { blockTag: 123 },
  )).price, 100n);
  await assert.rejects(
    inspectCuratedSelectionReveal(
      provider(fixed, commitConfiguration, { committedBlock: 123n }),
      reveal(),
      { blockTag: 123 },
    ),
    /Stored curated selection deposit/,
  );
  await assert.rejects(
    inspectCuratedSelectionReveal(
      provider(fixed, commitConfiguration, { fee: 11n }),
      reveal(),
      { blockTag: 123 },
    ),
    /fee-only allowance/,
  );
});

test("refund lanes, recovery calls and execution reads stay separate", async () => {
  const { fixed } = await fixtureInterface();
  const commit = commitment();
  const actions = [
    prepareCuratedMaturityUnlock(adapter, delegate, saleId, buyer, commit.commitment),
    prepareCuratedReasonUnlock(
      chainId,
      adapter,
      delegate,
      saleId,
      buyer,
      commitConfiguration,
      selection,
      salt,
      2n,
    ),
    prepareCuratedSelectionRefundClaim(adapter, buyer, saleId, claimRecipient),
    prepareCuratedSelectionRefundDelegatedClaim(
      adapter,
      delegate,
      saleId,
      buyer,
      { walletWide: true, index: 1n },
    ),
    prepareCuratedExcessRefundClaim(adapter, buyer, saleId, claimRecipient),
    prepareCuratedExcessRefundDelegatedClaim(
      adapter,
      delegate,
      saleId,
      buyer,
      { walletWide: false, index: 2n },
    ),
    prepareCuratedFixedCancel(adapter, owner, saleId),
    prepareCuratedContestSync(adapter, delegate, collectionId),
  ];
  assert.deepEqual(actions.map(action => fixed.parseTransaction({ data: action.call.data }).name), [
    "unlockSelectionRefund",
    "unlockSelectionRefundForReason",
    "claimSelectionRefund",
    "claimSelectionRefundDelegated",
    "claimRefund",
    "claimRefundFor",
    "cancelSale",
    "syncCollectionContest",
  ]);
  assert.ok(actions.every(action => action.call.value === 0n));
  const rpc = provider(fixed, publicConfiguration);
  assert.equal(await readCuratedSelectionRefundCredit(
    rpc,
    adapter,
    saleId,
    buyer,
    { blockTag: 123 },
  ), 25n);
  assert.equal(await readCuratedExcessRefundCredit(
    rpc,
    adapter,
    saleId,
    buyer,
    { blockTag: 123 },
  ), 3n);
  assert.equal((await readCuratedFixedExecution(
    rpc,
    adapter,
    publicPurchase().expectedPurchaseId,
    { blockTag: 123 },
  )).operationId, h("operation-id"));
});
