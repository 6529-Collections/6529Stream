import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { Interface, ZeroAddress, ZeroHash, id, keccak256 } from "ethers";
import {
  CurrentBurnMintClient, burnMintNullifier, burnMintProgramConfigHash,
} from "../dist/current-burn-mint.js";
import { nativeFixedPriceSaleTypedData } from "../dist/current-signing.js";
import { currentBurnMintFixture } from "../scripts/generate-current-burn-mint-fixture.mjs";

const A = n => `0x${BigInt(n).toString(16).padStart(40, "0")}`;
const chainId = 31337n, gate = A(1), core = A(2), registry = A(3), manager = A(4), operator = A(5),
  sourceOwner = A(6), recipient = A(7), artist = A(8), nativeAdapter = A(9);
const blockHash = id("burn block"), code = "0x60016000", codeHash = keccak256(code);
const fixture = JSON.parse(readFileSync(new URL("./fixtures/current-burn-mint-abi.json", import.meta.url), "utf8"));
const gateAbi = new Interface(fixture.abis.gate);
const coreAbi = new Interface(fixture.abis.core);
const managerAbi = new Interface(fixture.abis.manager);
const saleAbi = new Interface(fixture.abis.nativeSale);
const authNames = ["saleId", "saleConfigHash", "payer", "executor", "recipient", "artist", "tokenDataHash", "mintCommitment", "executionNonce", "nonce", "deadline", "expectedPrimaryPolicyHash"];

function config(native = false) {
  return { manager, targetCollectionId: 100n, phaseId: id(native ? "paid phase" : "free phase"),
    sourceCollectionIds: [20n, 30n], sourcesPerMint: 2n, startsAt: 900n, endsAt: 1100n,
    prepared: native ? false : true, nativeSaleAdapter: native ? nativeAdapter : ZeroAddress };
}
function program(native = false) {
  const c = config(native), configHash = burnMintProgramConfigHash(chainId, gate, core, registry, c);
  return { config: c, configHash, managerCodeHash: codeHash, nativeSaleCodeHash: native ? codeHash : ZeroHash };
}
function rpc(native = false) {
  const p = program(native), state = { approved: gate, owner: sourceOwner, callerOperator: false, gateOperator: false,
    gateOwner: operator, used: false, mutate: undefined, calls: [], credit: 17n, fee: 3n, price: 100n, saleConfigHash: id("sale config") };
  const provider = {
    async getNetwork() { return { chainId }; },
    async getBlock() { if (state.mutate) { const fn = state.mutate; state.mutate = undefined; fn(); } return { number: 7, hash: blockHash, timestamp: 1000 }; },
    async getCode(target) { assert([gate, core, registry, manager, nativeAdapter].includes(target)); return code; },
    async call(tx) {
      state.calls.push(tx);
      if (tx.to === gate) {
        const parsed = gateAbi.parseTransaction(tx); let out;
        if (parsed.name === "core") out = [core];
        else if (parsed.name === "moduleRegistry") out = [registry];
        else if (parsed.name === "coreCodeHash" || parsed.name === "registryCodeHash") out = [codeHash];
        else if (parsed.name === "owner") out = [state.gateOwner];
        else if (parsed.name === "program") out = [p];
        else if (parsed.name === "allowedSourceCollections") out = [p.config.sourceCollectionIds];
        else if (parsed.name === "saleRevealQuote") out = [[A(10), codeHash, [true, 0n, ZeroHash, 25n, state.fee]]];
        else if (parsed.name === "refundableBalance") out = [state.credit];
        else if (parsed.name === "nativeSaleCreditState") out = [[1n, state.credit, state.credit + 5n]];
        else if (parsed.name === "nativeSaleCreditPage") out = [[p.configHash, sourceOwner, state.credit, state.credit, 0n]];
        else throw Error(`unexpected gate read ${parsed.name}`);
        return gateAbi.encodeFunctionResult(parsed.name, out);
      }
      if (tx.to === core) {
        const parsed = coreAbi.parseTransaction(tx); let out;
        if (parsed.name === "collectionExists") out = [true];
        else if (parsed.name === "getSatellitePointer") out = parsed.args[0] === id("MINT_MANAGER")
          ? [manager, codeHash, false, ZeroHash, "0x00000000", ZeroAddress, 0n, ZeroHash, ZeroHash, 1n]
          : [registry, codeHash, false, ZeroHash, "0x00000000", ZeroAddress, 0n, ZeroHash, ZeroHash, 1n];
        else if (parsed.name === "tokenCollectionIdentity") out = [true, parsed.args[0] % 2n === 0n ? 20n : 30n, parsed.args[0], false];
        else if (parsed.name === "ownerOf") out = [state.owner];
        else if (parsed.name === "getApproved") out = [state.approved];
        else if (parsed.name === "isApprovedForAll") out = [parsed.args[1] === gate ? state.gateOperator : state.callerOperator];
        else throw Error(`unexpected Core read ${parsed.name}`);
        return coreAbi.encodeFunctionResult(parsed.name, out);
      }
      if (tx.to === manager) {
        const parsed = managerAbi.parseTransaction(tx); let out;
        if (parsed.name === "core") out = [core];
        else if (parsed.name === "moduleRegistry") out = [registry];
        else if (parsed.name === "isNullifierUsed") out = [state.used];
        else if (parsed.name === "phaseGate") out = [[gate, p.configHash, codeHash, id("metadata"), 1n, 1_000_000n]];
        else throw Error(`unexpected Manager read ${parsed.name}`);
        return managerAbi.encodeFunctionResult(parsed.name, out);
      }
      if (tx.to === nativeAdapter) {
        const parsed = saleAbi.parseTransaction(tx); let out;
        if (parsed.name === "core") out = [core];
        else if (parsed.name === "mintManager") out = [manager];
        else if (parsed.name === "moduleRegistry") out = [registry];
        else if (parsed.name === "saleRecord") out = [[[
          p.config.targetCollectionId, p.config.phaseId, state.price, 0n, 0n, id("mint policy"), id("assignment")],
          1n, state.saleConfigHash, [1n, 1n], false]];
        else if (parsed.name === "authorizationDigest") {
          const plain = Object.fromEntries(authNames.map(name => [name, parsed.args[0][name]]));
          out = [nativeFixedPriceSaleTypedData(chainId, nativeAdapter, plain).digest];
        } else throw Error(`unexpected sale read ${parsed.name}`);
        return saleAbi.encodeFunctionResult(parsed.name, out);
      }
      throw Error(`unexpected target ${tx.to}`);
    },
  };
  return { p, state, provider };
}
function freeBatch(phaseId) {
  return { collectionId: 100n, phaseId, payer: ZeroAddress, authorizer: ZeroAddress,
    initialRecipients: [recipient], beneficiaries: [recipient], tokenData: ["0xabcd"], mintCommitments: [id("mint")],
    expectedPolicyHash: id("policy"), authorizationId: id("authorization"), contextHash: id("context"), resolverData: "0x" };
}

test("capture pins the complete free program and source inspection separates caller from gate approval", async () => {
  const { p, state, provider } = rpc(), client = new CurrentBurnMintClient(chainId, { gate, core, registry });
  const plan = await client.captureProgram(provider, 100n);
  assert.equal(plan.program.configHash, p.configHash); assert.equal(plan.owner, operator); assert(Object.isFrozen(plan.program.config.sourceCollectionIds));
  const ready = await client.inspectSources(provider, plan, sourceOwner, [200n, 201n], 1n);
  assert.equal(ready.ready, true); assert.equal(ready.callerAuthorized, true); assert.equal(ready.gateApproved, true);
  state.owner = A(11); state.approved = sourceOwner;
  const separate = await client.inspectSources(provider, plan, sourceOwner, [200n, 201n], 1n);
  assert.equal(separate.callerAuthorized, true); assert.equal(separate.gateApproved, false); assert.equal(separate.ready, false);
});

test("free preparation clones before awaits, funds a maximum allowance and preserves caller-owned credit", async () => {
  const { p, state, provider } = rpc(), client = new CurrentBurnMintClient(chainId, { gate, core, registry });
  const plan = await client.captureProgram(provider, 100n), batch = freeBatch(p.config.phaseId), sources = [200n, 201n];
  state.mutate = () => { batch.beneficiaries[0] = A(12); sources[0] = 999n; };
  const prepared = await client.prepareFreeBurnMint(provider, plan, sourceOwner, batch, sources, 10n);
  assert.equal(prepared.requiredRevealFee, 3n); assert.equal(prepared.expectedExcessCredit, 7n); assert.equal(prepared.refundCreditKey, p.configHash);
  assert.equal(prepared.call.value, 10n); assert.equal(prepared.batch.beneficiaries[0], recipient);
  const decoded = gateAbi.parseTransaction(prepared.call); assert.equal(decoded.name, "burnAndMint"); assert.deepEqual(Array.from(decoded.args[1]), [200n, 201n]);
  await assert.rejects(client.prepareFreeBurnMint(provider, plan, sourceOwner, freeBatch(p.config.phaseId), [200n, 201n], 2n), /below/);
});

test("earned free credits read and claim without current program admission checks", async () => {
  const { p, state, provider } = rpc(), client = new CurrentBurnMintClient(chainId, { gate, core, registry });
  provider.getCode = async () => { throw Error("credit must not inspect current code"); };
  assert.equal(await client.readFreeBurnRefund(provider, p.configHash, sourceOwner, 7), state.credit);
  assert.deepEqual(await client.readFreeBurnCreditState(provider, 7), { accountCount: 1n, totalLiabilities: 17n, balance: 22n });
  assert.deepEqual(await client.readFreeBurnCreditPage(provider, 0n, 0n, 64n, 7),
    { saleId: p.configHash, account: sourceOwner, owed: 17n, claimable: 17n, nextCursor: 0n });
  const claim = client.freeBurnRefundClaim(p.configHash, sourceOwner, recipient);
  assert.equal(claim.caller, sourceOwner); assert.equal(claim.call.value, 0n); assert.equal(gateAbi.parseTransaction(claim.call).name, "claimRefund");
});

test("native paid preparation reuses the original fixed-sale digest and external purchaseWithBurn only", async () => {
  const { p, state, provider } = rpc(true), client = new CurrentBurnMintClient(chainId, { gate, core, registry });
  const plan = await client.captureProgram(provider, 100n);
  const tokenData = "0xabcd", authorization = { saleId: id("sale"), saleConfigHash: state.saleConfigHash,
    payer: sourceOwner, executor: sourceOwner, recipient, artist, tokenDataHash: keccak256(tokenData), mintCommitment: id("mint"),
    executionNonce: 1n, nonce: id("nonce"), deadline: 2000n, expectedPrimaryPolicyHash: id("primary policy") };
  const prepared = await client.prepareNativePurchaseWithBurn(provider, plan, [200n, 201n], authorization,
    { tokenData, platformSignature: "0x1234", artistSignature: "0x5678", saleAmount: state.price, revealFeeAllowance: 9n });
  assert.equal(prepared.caller, sourceOwner); assert.equal(prepared.call.to, nativeAdapter); assert.equal(prepared.call.value, 109n);
  const decoded = saleAbi.parseTransaction(prepared.call); assert.equal(decoded.name, "purchaseWithBurn");
  assert.deepEqual(Array.from(decoded.args[1]), [200n, 201n]); assert.equal(decoded.args[0].authorization.payer, sourceOwner);
  await assert.rejects(client.prepareNativePurchaseWithBurn(provider, plan, [200n, 201n], { ...authorization, executor: A(15) },
    { tokenData, platformSignature: "0x", artistSignature: "0x", saleAmount: state.price, revealFeeAllowance: 0n }), /same caller/);
});

test("configuration emits exact owner CALL and strict copied program fields", () => {
  const client = new CurrentBurnMintClient(chainId, { gate, core, registry }), c = config();
  const prepared = client.configureProgram(c, operator), decoded = gateAbi.parseTransaction(prepared.call);
  assert.equal(decoded.name, "configureProgram"); assert.equal(prepared.expectedConfigHash, burnMintProgramConfigHash(chainId, gate, core, registry, c));
  assert(Object.isFrozen(prepared.config.sourceCollectionIds));
  assert.throws(() => client.configureProgram({ ...c, sourceCollectionIds: [30n, 20n] }, operator), /increasing/);
  assert.equal(burnMintNullifier(chainId, core, 1n).length, 66);
});

test("renounced ownership remains valid informational capture state for configured programs", async () => {
  const { p, state, provider } = rpc(), client = new CurrentBurnMintClient(chainId, { gate, core, registry });
  state.gateOwner = ZeroAddress;
  const plan = await client.captureProgram(provider, 100n);
  assert.equal(plan.owner, ZeroAddress);
  const prepared = await client.prepareFreeBurnMint(provider, plan, sourceOwner, freeBatch(p.config.phaseId), [200n, 201n], 3n);
  assert.equal(prepared.call.value, 3n);
});

test("fixture identifies the exact final compiler capture and rejects different inputs", () => {
  assert.equal(fixture.sourceCommit, "9310d6e9865db8ffe83fb53c78801ff4151158e3");
  assert.equal(fixture.sourceTree, "ac8bde02e1ee6e88d0dac7887610a6c3eb9c1ea2");
  assert.equal(fixture.sourceCount, 999);
  assert.match(fixture.qualification, /no scoped native runtime/);
  assert.throws(() => currentBurnMintFixture(Buffer.from("{}"), Buffer.from("{}"), Buffer.from("{}")), /differs/);
});
