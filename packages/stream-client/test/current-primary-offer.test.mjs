import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";
import {
  AbiCoder,
  Interface,
  ZeroAddress,
  ZeroHash,
  id,
  keccak256,
} from "ethers";
import { buildCuratedManifest } from "../dist/current-curated-content.js";
import {
  primaryOfferBatchHashes,
  primaryOfferConfigurationHash,
  primaryOfferSaleOfferPayload,
  primaryOfferSellerAuthorizationPayload,
} from "../dist/current-primary-offer-signing.js";
import {
  inspectCompletedPrimaryOffer,
  inspectPrimaryOfferAcceptance,
  inspectPrimaryOfferBuyerRevocation,
  inspectPrimaryOfferRegistration,
  inspectPrimaryOfferSellerRevocation,
  preparePrimaryOfferAcceptance,
  preparePrimaryOfferBuyerRevocation,
  preparePrimaryOfferDelegatedRefundClaim,
  preparePrimaryOfferRegistration,
  preparePrimaryOfferSellerRevocation,
  readPrimaryOfferRefundCredit,
  simulatePrimaryOfferAcceptance,
  simulatePrimaryOfferBuyerRevocation,
  simulatePrimaryOfferRegistration,
  simulatePrimaryOfferSellerRevocation,
} from "../dist/current-primary-offer.js";

const fixture = JSON.parse(await readFile(
  new URL("./fixtures/current-primary-offer-abi.json", import.meta.url),
  "utf8",
));
const saleAbi = new Interface(fixture.abis.sale);
const managerAbi = new Interface(fixture.abis.manager);
const coder = AbiCoder.defaultAbiCoder();
const A = value => `0x${BigInt(value).toString(16).padStart(40, "0")}`;
const chainId = 31337n;
const adapter = A(1);
const manager = A(2);
const core = A(3);
const buyer = A(4);
const executor = A(5);
const seller = A(6);
const ledger = A(7);
const owner = A(8);
const buyerSigner = A(9);
const authority = A(10);
const resolver = A(11);
const artists = A(12);
const modules = A(13);
const gate = A(14);
const collectionId = 13n;
const phaseId = id("primary offer phase");
const saleNonce = 8n;
const purchaseNonce = 9n;
const price = (1n << 180n) + 100n;
const tokenData = "0x1234";
const mintCommitment = id("primary offer mint commitment");
const signerEvidenceHash = id("primary offer signer evidence");

function packet(selected = false) {
  const provisionalSaleId = keccak256(coder.encode(
    ["bytes32", "uint256", "address", "uint8", "uint256", "bytes32", "uint256"],
    [id("6529STREAM_SALE_V1"), chainId, adapter, 6n, collectionId, phaseId, saleNonce],
  ));
  const manifest = buildCuratedManifest({
    chainId,
    manager,
    adapter,
    saleId: provisionalSaleId,
    collectionId,
    phaseId,
    counterId: id("primary offer content counter"),
    rows: [{
      contentId: ZeroHash,
      tokenDataHash: keccak256(tokenData),
      previewURI: "ipfs://primary-offer",
    }],
  });
  const contentSelectionHash = selected
    ? manifest.publication.manifestRoot
    : ZeroHash;
  const offer = {
    chainId,
    saleAdapter: adapter,
    core,
    collectionId,
    tokenId: 0n,
    contentSelectionHash,
    buyer,
    asset: ZeroAddress,
    price,
    nonce: id("buyer offer nonce"),
    deadline: 900n,
    finalizeBy: 0n,
  };
  const hashes = primaryOfferBatchHashes(
    adapter,
    buyer,
    tokenData,
    mintCommitment,
  );
  const authorization = {
    chainId,
    saleAdapter: adapter,
    mintManager: manager,
    collectionId,
    phaseId,
    saleId: provisionalSaleId,
    saleKind: 6n,
    revenueClass: id("PRIMARY_SALE"),
    expectedPrimaryPolicyHash: id("primary policy"),
    primaryPolicyMode: 0n,
    ...hashes,
    payer: buyer,
    executor,
    asset: ZeroAddress,
    unitPrice: price,
    quantity: 1n,
    contentSelectionHash,
    policyHash: id("mint policy"),
    nonce: id("seller authorization nonce"),
    deadline: 800n,
    finalizeBy: 0n,
  };
  const configuration = {
    sale: {
      collectionId,
      phaseId,
      price,
      poster: seller,
      startsAt: 100n,
      endsAt: 800n,
      mintPolicyHash: authorization.policyHash,
      expectedPrimaryPolicyHash: authorization.expectedPrimaryPolicyHash,
      primaryPolicyMode: 0n,
      contentManifestRoot: selected ? manifest.publication.manifestRoot : ZeroHash,
    },
    buyer,
    offerDigest: primaryOfferSaleOfferPayload(chainId, adapter, offer).digest,
    contentId: ZeroHash,
    tokenDataHash: selected ? keccak256(tokenData) : ZeroHash,
    signer: seller,
    signerKind: 2n,
    signerEvidenceHash,
    signerRevision: 2n,
    signerAuthority: authority,
  };
  const selection = {
    content: selected
      ? manifest.selections[0]
      : { contentId: ZeroHash, tokenDataHash: ZeroHash, proof: [] },
    tokenData,
    mintCommitment,
    recipient: buyer,
    purchaseNonce,
  };
  const registration = preparePrimaryOfferRegistration(
    chainId,
    adapter,
    owner,
    saleNonce,
    configuration,
    selected ? manifest.selections[0].proof : [],
  );
  const acceptance = preparePrimaryOfferAcceptance(
    chainId,
    adapter,
    core,
    manager,
    configuration,
    {
      offer,
      buyerProof: { authorizer: buyerSigner, kind: 2n, signature: "0x1234" },
      sellerAuthorization: authorization,
      sellerProof: { authorizer: seller, kind: 2n, signature: "0xabcd" },
      selection,
      signerDelegation: { walletWide: true, index: 10n },
      executorDelegation: { walletWide: false, index: 11n },
      revealFeeAllowance: 7n,
    },
  );
  return { selected, manifest, offer, authorization, configuration, registration, acceptance };
}

function saleRecord(source, status = 1n) {
  const selected = source.configuration.sale.contentManifestRoot !== ZeroHash;
  return [
    source.configuration.sale,
    saleNonce,
    6n,
    primaryOfferConfigurationHash(chainId, adapter, source.configuration),
    [90n, 3n],
    id("artist id"),
    2n,
    id("binding hash"),
    selected ? gate : ZeroAddress,
    selected ? id("gate code hash") : ZeroHash,
    selected ? id("gate config hash") : ZeroHash,
    selected ? id("manifest hash") : ZeroHash,
    selected ? id("content counter") : ZeroHash,
    selected ? id("content counter config") : ZeroHash,
    status,
  ];
}

function execution(source, tokenId = 42n) {
  const prepared = source.acceptance;
  return [
    prepared.signing.saleId,
    buyer,
    buyer,
    purchaseNonce,
    prepared.signing.buyerAuthorizationId,
    prepared.signing.sellerReplayDigest,
    prepared.signing.contentSelectionHash,
    keccak256(tokenData),
    mintCommitment,
    price,
    tokenId,
    id("settlement key"),
    id("operation root"),
    id("operation id"),
  ];
}

function provider(source, controls = {}) {
  const seen = [];
  const service = {
    seen,
    getNetwork: async () => {
      if (controls.networkGate) {
        await controls.networkGate;
      }
      return { chainId };
    },
    getBlock: async blockTag => ({ number: blockTag, timestamp: controls.timestamp ?? 500 }),
    call: async transaction => {
      seen.push(transaction);
      assert.equal(transaction.blockTag, 123);
      const target = transaction.to.toLowerCase();
      const iface = target === manager.toLowerCase() ? managerAbi : saleAbi;
      const parsed = iface.parseTransaction({ data: transaction.data });
      if (target === manager.toLowerCase()) {
        switch (parsed.name) {
          case "mintOfferAuthorizationId":
            return managerAbi.encodeFunctionResult(parsed.fragment, [source.acceptance.signing.buyerAuthorizationId]);
          case "isAuthorizationUsed":
            return managerAbi.encodeFunctionResult(parsed.fragment, [controls.buyerUsed ?? false]);
          case "core":
            return managerAbi.encodeFunctionResult(parsed.fragment, [controls.managerCore ?? core]);
          case "mintLedger":
            return managerAbi.encodeFunctionResult(parsed.fragment, [controls.managerLedger ?? ledger]);
          case "voidMintOffer":
            return managerAbi.encodeFunctionResult(parsed.fragment, [source.acceptance.signing.buyerAuthorizationId]);
          default:
            throw new Error(`unexpected manager call ${parsed.name}`);
        }
      }
      switch (parsed.name) {
        case "owner": return saleAbi.encodeFunctionResult(parsed.fragment, [owner]);
        case "nextSaleNonce": return saleAbi.encodeFunctionResult(parsed.fragment, [saleNonce]);
        case "saleIdFor": return saleAbi.encodeFunctionResult(parsed.fragment, [source.registration.expectedSaleId]);
        case "primaryOfferConfigurationHash":
          return saleAbi.encodeFunctionResult(parsed.fragment, [source.registration.configurationHash]);
        case "collectionSigner":
          return saleAbi.encodeFunctionResult(parsed.fragment, [[signerEvidenceHash, 2n, true, authority]]);
        case "core": return saleAbi.encodeFunctionResult(parsed.fragment, [core]);
        case "mintManager": return saleAbi.encodeFunctionResult(parsed.fragment, [controls.carrierManager ?? manager]);
        case "revenueResolver": return saleAbi.encodeFunctionResult(parsed.fragment, [resolver]);
        case "artistRegistry": return saleAbi.encodeFunctionResult(parsed.fragment, [artists]);
        case "moduleRegistry": return saleAbi.encodeFunctionResult(parsed.fragment, [modules]);
        case "registerPrimaryOffer":
          return controls.registrationRaw
            ?? saleAbi.encodeFunctionResult(parsed.fragment, [source.registration.expectedSaleId]);
        case "primaryOfferConfiguration":
          return saleAbi.encodeFunctionResult(parsed.fragment, [source.configuration]);
        case "saleRecord":
          return saleAbi.encodeFunctionResult(parsed.fragment, [saleRecord(source, controls.status ?? 1n)]);
        case "nextPurchaseNonce": return saleAbi.encodeFunctionResult(parsed.fragment, [purchaseNonce]);
        case "purchaseIdFor": return saleAbi.encodeFunctionResult(parsed.fragment, [source.acceptance.expectedPurchaseId]);
        case "offerDigest": return saleAbi.encodeFunctionResult(parsed.fragment, [source.acceptance.signing.offerPayload.digest]);
        case "authorizationDigest":
          return saleAbi.encodeFunctionResult(parsed.fragment, [source.acceptance.signing.sellerReplayDigest]);
        case "digestConsumed":
          return saleAbi.encodeFunctionResult(parsed.fragment, [controls.sellerConsumed ?? false]);
        case "digestRevoked":
          return saleAbi.encodeFunctionResult(parsed.fragment, [controls.sellerRevoked ?? false]);
        case "saleRevealQuote":
          return saleAbi.encodeFunctionResult(parsed.fragment, [[A(20), id("coordinator code"), [true, 0n, id("owner role"), 10n, 5n]]]);
        case "primaryOfferAuthorizationBinding":
          return saleAbi.encodeFunctionResult(parsed.fragment, [
            collectionId,
            phaseId,
            seller,
            2n,
            source.registration.configurationHash,
          ]);
        case "eip712Domain":
          return saleAbi.encodeFunctionResult(parsed.fragment, [
            "0x0f",
            "6529Stream Sales",
            "1",
            chainId,
            adapter,
            ZeroHash,
            [],
          ]);
        case "acceptPrimaryOffer": {
          if (controls.acceptanceRaw) return controls.acceptanceRaw;
          return saleAbi.encodeFunctionResult(parsed.fragment, [execution(source, controls.tokenId ?? 42n)]);
        }
        case "executionRecord":
          return saleAbi.encodeFunctionResult(parsed.fragment, [execution(source, controls.tokenId ?? 42n)]);
        case "revokeAuthorization": return "0x";
        case "refundableBalance": return saleAbi.encodeFunctionResult(parsed.fragment, [17n]);
        default: throw new Error(`unexpected sale call ${parsed.name}`);
      }
    },
  };
  return service;
}

test("compiled fixture and pure preparation retain selected and collection-level paths", () => {
  assert.equal(fixture.sourceCommit, "cf268d24bd0098c90ece4cd2b9d306802d9c1b62");
  assert.equal(fixture.carrierCommit, "6d69483cc7eeee748271f531821ed2bf7643a787");
  assert.equal(fixture.sourceCount, 396);
  assert.equal(saleAbi.getFunction("acceptPrimaryOffer").stateMutability, "payable");
  assert.equal(managerAbi.getFunction("voidMintOffer").inputs[0].components.length, 12);
  for (const selected of [false, true]) {
    const source = packet(selected);
    assert.equal(source.registration.expectedSaleId, source.authorization.saleId);
    assert.equal(source.acceptance.caller, executor);
    assert.notEqual(source.acceptance.caller, buyer);
    assert.equal(source.acceptance.call.value, price + 7n);
    assert.equal(
      source.configuration.sale.contentManifestRoot !== ZeroHash,
      selected,
    );
    const original = source.acceptance.call.data;
    source.offer.deadline = 1n;
    source.authorization.executor = buyer;
    assert.equal(source.acceptance.call.data, original);
    assert.equal(source.acceptance.signing.offer.deadline, 900n);
  }
});

test("registration and acceptance inspect pinned facts and simulate from the real callers", async () => {
  const source = packet(false);
  const registrationRpc = provider(source, { timestamp: 99 });
  const inspectedRegistration = await inspectPrimaryOfferRegistration(
    registrationRpc,
    source.registration,
    { blockTag: 123 },
  );
  assert.equal(inspectedRegistration.signer.revision, 2n);
  assert.equal(
    await simulatePrimaryOfferRegistration(
      registrationRpc,
      source.registration,
      { blockTag: 123 },
    ),
    source.registration.expectedSaleId,
  );
  const rpc = provider(source);
  const inspected = await inspectPrimaryOfferAcceptance(rpc, source.acceptance, { blockTag: 123 });
  assert.equal(inspected.revealFeePerTokenWei, 5n);
  const completed = await simulatePrimaryOfferAcceptance(rpc, source.acceptance, { blockTag: 123 });
  assert.equal(completed.tokenId, 42n);
  const acceptanceCall = rpc.seen.find(value => value.data === source.acceptance.call.data);
  assert.equal(acceptanceCall.from.toLowerCase(), executor.toLowerCase());
  assert.equal(acceptanceCall.value, price + 7n);
});

test("inspection snapshots mutable packets and options before the first await", async () => {
  const source = packet(false);
  let release;
  const networkGate = new Promise(resolve => { release = resolve; });
  const rpc = provider(source, { networkGate });
  const clone = structuredClone(source.acceptance);
  const options = { blockTag: 123 };
  const pending = inspectPrimaryOfferAcceptance(rpc, clone, options);
  clone.call.data = "0x1234";
  clone.revealFeeAllowance = 0n;
  options.blockTag = 999;
  release();
  const inspected = await pending;
  assert.equal(inspected.prepared.call.data, source.acceptance.call.data);
  assert.equal(inspected.prepared.revealFeeAllowance, 7n);
  assert(rpc.seen.every(value => value.blockTag === 123));
  await assert.rejects(
    inspectPrimaryOfferAcceptance(rpc, clone, { blockTag: 123 }),
    /canonical reconstruction/,
  );
});

test("simulation and completed readback reject oversized, zero-token and revoked transcripts", async () => {
  const source = packet(false);
  const valid = saleAbi.encodeFunctionResult("acceptPrimaryOffer", [execution(source)]);
  await assert.rejects(
    simulatePrimaryOfferAcceptance(
      provider(source, { acceptanceRaw: `${valid}${"00".repeat(32)}` }),
      source.acceptance,
      { blockTag: 123 },
    ),
    /Malformed primary offer acceptance/,
  );
  await assert.rejects(
    simulatePrimaryOfferAcceptance(
      provider(source, { tokenId: 0n }),
      source.acceptance,
      { blockTag: 123 },
    ),
    /positive uint256/,
  );
  const completedProvider = provider(source, {
    status: 4n,
    buyerUsed: true,
    sellerConsumed: true,
    sellerRevoked: true,
  });
  await assert.rejects(
    inspectCompletedPrimaryOffer(completedProvider, source.acceptance, { blockTag: 123 }),
    /replay loci/,
  );
  const result = await inspectCompletedPrimaryOffer(
    provider(source, { status: 4n, buyerUsed: true, sellerConsumed: true }),
    source.acceptance,
    { blockTag: 123 },
  );
  assert.equal(result.sellerDigestRevoked, false);
  assert.equal(result.execution.tokenId, 42n);
});

test("historical revocations bind the original Manager coordinates without live admission reads", async () => {
  const source = packet(false);
  const buyerVoid = preparePrimaryOfferBuyerRevocation(
    chainId,
    adapter,
    manager,
    ledger,
    buyer,
    source.offer,
    2n,
    "0x1234",
  );
  const sellerVoid = preparePrimaryOfferSellerRevocation(
    chainId,
    adapter,
    seller,
    source.configuration,
    source.authorization,
    { authorizer: seller, kind: 2n, signature: "0xabcd" },
  );
  assert.equal((await inspectPrimaryOfferBuyerRevocation(provider(source), buyerVoid, { blockTag: 123 })).ledger, ledger);
  assert.equal(await simulatePrimaryOfferBuyerRevocation(provider(source), buyerVoid, { blockTag: 123 }), buyerVoid.authorizationId);
  await assert.rejects(
    inspectPrimaryOfferBuyerRevocation(
      provider(source, { managerLedger: A(99) }),
      buyerVoid,
      { blockTag: 123 },
    ),
    /historical payload/,
  );
  await assert.rejects(
    inspectPrimaryOfferBuyerRevocation(
      provider(source, { managerCore: A(99) }),
      buyerVoid,
      { blockTag: 123 },
    ),
    /historical payload/,
  );
  const historical = provider(source);
  await inspectPrimaryOfferSellerRevocation(historical, sellerVoid, { blockTag: 123 });
  await simulatePrimaryOfferSellerRevocation(historical, sellerVoid, { blockTag: 123 });
  assert.equal(historical.seen.some(tx => {
    const parsed = saleAbi.parseTransaction({ data: tx.data });
    return parsed?.name === "collectionSigner" || parsed?.name === "saleRecord";
  }), false);
  await assert.rejects(
    inspectPrimaryOfferSellerRevocation(
      provider(source, { carrierManager: A(99) }),
      sellerVoid,
      { blockTag: 123 },
    ),
    /Historical seller authorization binding/,
  );
});

test("delegated refund keeps the original buyer as the credit account", async () => {
  const source = packet(false);
  const prepared = preparePrimaryOfferDelegatedRefundClaim(
    adapter,
    executor,
    source.registration.expectedSaleId,
    buyer,
    { walletWide: true, index: 3n },
  );
  const decoded = saleAbi.decodeFunctionData("claimRefundFor", prepared.call.data);
  assert.equal(decoded[1].toLowerCase(), buyer.toLowerCase());
  assert.equal(prepared.caller, executor);
  assert.equal(await readPrimaryOfferRefundCredit(
    provider(source),
    adapter,
    source.registration.expectedSaleId,
    buyer,
    { blockTag: 123 },
  ), 17n);
});
