import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { Interface, ZeroAddress, ZeroHash, id, keccak256 } from "ethers";
import {
  CurrentCuratedPrivateClient,
  curatedPrivateBatchHashes,
  curatedPrivateConfigurationHash,
  curatedPrivateMintTicketAuthorizationId,
  curatedPrivateMintTicketRevocationPayload,
  curatedPrivateSaleAuthorizationPayload,
} from "../dist/current-curated-private.js";
import {
  curatedContentLeaf,
  curatedPurchaseId,
  curatedSaleId,
} from "../dist/current-curated-content.js";

const fixture = JSON.parse(readFileSync(new URL("./fixtures/current-curated-abi.json", import.meta.url), "utf8"));
const revocationFixture = JSON.parse(readFileSync(new URL("./fixtures/current-curated-revocation-abi.json", import.meta.url), "utf8"));
const privateAbi = new Interface(fixture.abis.private);
const managerAbi = new Interface(revocationFixture.abis.manager);
const ledgerAbi = new Interface(revocationFixture.abis.ledger);
const A = value => `0x${BigInt(value).toString(16).padStart(40, "0")}`;
const chainId = 31337n, adapter = A(1), manager = A(2), ledger = A(3), owner = A(4);
const buyer = A(5), executor = A(6), signer = A(7), authority = owner, coordinator = A(8);
const phaseId = id("private phase"), collectionId = 88n, nonce = 4n;
const blockHash = id("curated private block"), tokenData = "0x123456", tokenDataHash = keccak256(tokenData);
const saleId = curatedSaleId(chainId, adapter, 5n, collectionId, phaseId, nonce);
const contentId = id("content"), leaf = curatedContentLeaf(chainId, adapter, saleId, contentId, tokenDataHash);
const selection = { content: { contentId, tokenDataHash, proof: [] }, tokenData,
  mintCommitment: id("mint commitment"), recipient: buyer, purchaseNonce: 1n };

function configuration() {
  return { sale: { collectionId, phaseId, price: 1_000n, poster: A(9), startsAt: 1_100n,
    endsAt: 2_000n, mintPolicyHash: id("mint policy"), expectedPrimaryPolicyHash: id("primary policy"),
    primaryPolicyMode: 0n, contentManifestRoot: leaf }, buyer, contentId, tokenDataHash,
    signer, signerKind: 2n, signerEvidenceHash: id("evidence"), signerRevision: 1n, signerAuthority: authority };
}
function authorization(executorAddress = executor) {
  const c = configuration(), batch = curatedPrivateBatchHashes(adapter, buyer, selection);
  return { chainId, saleAdapter: adapter, mintManager: manager, collectionId, phaseId, saleId,
    saleKind: 5n, revenueClass: id("PRIMARY_SALE"), expectedPrimaryPolicyHash: c.sale.expectedPrimaryPolicyHash,
    primaryPolicyMode: 0n, ...batch, payer: buyer, executor: executorAddress, asset: ZeroAddress,
    unitPrice: c.sale.price, quantity: 1n, contentSelectionHash: leaf, policyHash: c.sale.mintPolicyHash,
    nonce: id("authorization nonce"), deadline: 2_000n, finalizeBy: 0n };
}

function rpc() {
  const c = configuration();
  const configHash = curatedPrivateConfigurationHash(chainId, adapter, c);
  const state = { used: false, liveFee: 20n, mutation: undefined, simulationCalls: 0, timestamp: 1_500 };
  const signerMembership = { evidenceHash: c.signerEvidenceHash, revision: 1n, enabled: true, authority };
  const record = { config: c.sale, saleNonce: nonce, saleKind: 5n, configHash,
    lifecycle: { saleCreatedAt: 1_050n, saleAdapterRegistryRevision: 2n }, artistId: id("artist"),
    bindingGeneration: 3n, bindingHash: id("binding"), gate: A(10), gateCodeHash: id("gate code"),
    gateConfigHash: id("gate config"), manifestHash: id("manifest"), contentCounterId: id("counter"),
    contentCounterConfigHash: id("counter config"), status: 1n };
  const provider = {
    async getNetwork() {
      if (state.mutation) { const mutation = state.mutation; state.mutation = undefined; mutation(); }
      return { chainId };
    },
    async getBlock() { return { number: 77, hash: blockHash, timestamp: state.timestamp }; },
    async getCode(target) { assert.equal(target, adapter); return "0x60016000"; },
    async call(tx) {
      if (tx.to === manager) {
        const parsed = managerAbi.parseTransaction(tx); let output;
        if (parsed.name === "mintLedger") output = [ledger];
        else if (parsed.name === "mintSaleAuthorizationId") {
          output = [curatedPrivateMintTicketAuthorizationId(chainId, adapter,
            Object.fromEntries(Object.keys(authorization()).map(key => [key, parsed.args[0][key]])))];
        } else if (parsed.name === "isAuthorizationUsed") output = [state.used];
        else if (parsed.name === "voidMintSaleAuthorization") output = [curatedPrivateMintTicketAuthorizationId(chainId, adapter,
          Object.fromEntries(Object.keys(authorization()).map(key => [key, parsed.args[0][key]])))];
        else throw new Error(`unexpected Manager call ${parsed.name}`);
        return managerAbi.encodeFunctionResult(parsed.name, output);
      }
      if (tx.to === ledger) {
        const parsed = ledgerAbi.parseTransaction(tx);
        assert.equal(parsed.name, "isManagerAuthorizationUsed");
        return ledgerAbi.encodeFunctionResult(parsed.name, [state.used]);
      }
      assert.equal(tx.to, adapter);
      const parsed = privateAbi.parseTransaction(tx); let output;
      if (parsed.name === "owner") output = [owner];
      else if (parsed.name === "mintManager") output = [manager];
      else if (parsed.name === "nextSaleNonce") output = [nonce];
      else if (parsed.name === "saleIdFor") output = [saleId];
      else if (parsed.name === "nextPurchaseNonce") output = [1n];
      else if (parsed.name === "collectionSigner") output = [signerMembership];
      else if (parsed.name === "configureCollectionSigner") output = [];
      else if (parsed.name === "privateConfigurationHash") output = [configHash];
      else if (parsed.name === "registerCuratedPrivateSale") output = [saleId];
      else if (parsed.name === "privateSaleConfiguration") output = [c];
      else if (parsed.name === "saleRecord") output = [record];
      else if (parsed.name === "eip712Domain") output = ["0x0f", "6529Stream Sales", "1", chainId, adapter, ZeroHash, []];
      else if (parsed.name === "saleRevealQuote") output = [[coordinator, id("coordinator code"),
        [true, 0n, ZeroHash, 100n, state.liveFee]]];
      else if (parsed.name === "curatedSaleAuthorizationBinding") output = [collectionId, phaseId, signer, 2n, configHash];
      else if (parsed.name === "purchasePrivateContent") {
        state.simulationCalls++;
        const auth = Object.fromEntries(Object.keys(authorization()).map(key => [key, parsed.args[0][key]]));
        const payload = curatedPrivateSaleAuthorizationPayload(chainId, adapter, auth);
        const authId = curatedPrivateMintTicketAuthorizationId(chainId, adapter, auth);
        output = [[saleId, buyer, buyer, 1n, authId, payload.digest, leaf, tokenDataHash,
          selection.mintCommitment, 1_000n, 123n, id("settlement"), id("operation root"), id("operation")]];
      } else if (parsed.name === "refundableBalance") output = [15n];
      else throw new Error(`unexpected private call ${parsed.name}`);
      return privateAbi.encodeFunctionResult(parsed.name, output);
    },
  };
  return { provider, state, configHash };
}

test("pure private producers retain full arrays, TICKET identity and Sales revocation domain", () => {
  const a = authorization(), payload = curatedPrivateSaleAuthorizationPayload(chainId, adapter, a);
  const authorizationId = curatedPrivateMintTicketAuthorizationId(chainId, adapter, a);
  assert.equal(payload.primaryType, "SaleAuthorization");
  assert.equal(payload.domain.name, "6529Stream Sales");
  assert.equal(payload.message.finalizeBy, 0n);
  assert.equal(payload.message.initialRecipientsHash, curatedPrivateBatchHashes(adapter, buyer, selection).initialRecipientsHash);
  const revocation = curatedPrivateMintTicketRevocationPayload(chainId, adapter, manager, ledger, authorizationId);
  assert.equal(revocation.primaryType, "MintTicketRevocation");
  assert.equal(revocation.domain.name, "6529Stream Sales");
  assert.notEqual(authorizationId, payload.digest);
});

test("owner registration reconstructs config hash, selected leaf and sale identity", async () => {
  const { provider, state, configHash } = rpc();
  state.timestamp = 1_000;
  const client = new CurrentCuratedPrivateClient(provider, chainId, adapter);
  const prepared = await client.prepareRegistration(owner, configuration(), []);
  assert.equal(prepared.saleId, saleId);
  assert.equal(prepared.configurationHash, configHash);
  assert.equal(privateAbi.parseTransaction(prepared.call).name, "registerCuratedPrivateSale");
  const signerInput = { caller: owner, collectionId, signer, signerKind: 2n,
    evidenceHash: id("new evidence"), enabled: false };
  state.mutation = () => { signerInput.enabled = true; };
  const signerCall = await client.prepareCollectionSignerConfiguration(signerInput);
  assert.equal(signerCall.signer.revision, 2n);
  assert.equal(signerCall.signer.enabled, false);
  assert.equal(privateAbi.parseTransaction(signerCall.call).name, "configureCollectionSigner");
});

test("purchase freezes inputs before RPC and simulates exact executor payment", async () => {
  const { provider, state } = rpc();
  const client = new CurrentCuratedPrivateClient(provider, chainId, adapter);
  const mutableSelection = { ...selection, content: { ...selection.content, proof: [] } };
  const input = { authorization: authorization(), signature: { authorizer: signer, kind: 2n, signature: "0x1234" },
    selection: mutableSelection, witness: { walletWide: false, index: 0n }, revealFeeAllowance: 30n };
  state.mutation = () => {
    mutableSelection.content.proof.push(id("hostile mutation"));
    assert.throws(() => { client.adapter = A(99); }, TypeError);
  };
  const prepared = await client.preparePurchase(executor, input);
  assert.equal(prepared.call.value, 1_030n);
  assert.equal(prepared.expectedExcessCredit, 10n);
  assert.equal(prepared.selection.content.proof.length, 0);
  assert.equal(prepared.purchaseId, curatedPurchaseId(chainId, adapter, saleId, buyer, 1n));
  assert.equal(prepared.simulation.authorizationId, prepared.authorizationId);
  assert.equal(state.simulationCalls, 1);
});

test("historical replay and direct or relayed revocation do not require live admission", async () => {
  const { provider, state } = rpc();
  const client = new CurrentCuratedPrivateClient(provider, chainId, adapter);
  const historical = await client.inspectHistoricalAuthorization(authorization());
  assert.equal(historical.signer, signer);
  assert.equal(historical.managerUsed, false);
  const mutableAuthorization = authorization();
  state.mutation = () => { mutableAuthorization.nonce = id("hostile replacement nonce"); };
  const direct = await client.prepareVoidAuthorization(signer, mutableAuthorization, "0x");
  assert.equal(direct.directAuthorizer, true);
  assert.equal(managerAbi.parseTransaction(direct.call).name, "voidMintSaleAuthorization");
  const relayed = await client.prepareVoidAuthorization(A(77), authorization(), "0x1234");
  assert.equal(relayed.directAuthorizer, false);
  assert.equal(relayed.revocationPayload.message.authorizationId, historical.authorizationId);
  state.used = true;
  await assert.rejects(client.prepareVoidAuthorization(signer, authorization(), "0x"), /already consumed or voided/);
  assert.equal(await client.refundableBalance(saleId, buyer), 15n);
});
