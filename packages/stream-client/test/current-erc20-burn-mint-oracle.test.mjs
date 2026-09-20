import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { AbiCoder, Interface, ZeroAddress, ZeroHash, concat, getAddress, id, keccak256 } from "ethers";
import { erc20BurnMintAuthorizationPayload, erc20BurnMintAuthorizationId } from "../dist/current-erc20-burn-mint-signing.js";
import { currentERC20BurnMintFixture } from "../scripts/generate-current-erc20-burn-mint-fixture.mjs";
import { erc20BurnMintSafeInventory, createERC20BurnMintSafeReview } from "../examples/current-erc20-burn-mint.mjs";

const fixture = JSON.parse(readFileSync(new URL("./fixtures/current-erc20-burn-mint-abi.json", import.meta.url), "utf8"));
const sale = new Interface(fixture.abis.sale), gate = new Interface(fixture.abis.gate);
const payment = new Interface(fixture.abis.payment), core = new Interface(fixture.abis.core);
const token = new Interface(fixture.abis.token), coder = AbiCoder.defaultAbiCoder();
const A = n => `0x${BigInt(n).toString(16).padStart(40, "0")}`;
const catalog = fixture.abis;

test("original universal digest and TICKET match an independent literal EIP-712 preimage", () => {
  const chainId = (1n << 190n) + 31337n, carrier = A(41);
  const type = "UniversalSaleAuthorization(bytes32 saleId,bytes32 saleConfigHash,address payer,address executor,address recipient,address artist,bytes32 tokenDataHash,bytes32 mintCommitment,uint256 executionNonce,bytes32 nonce,uint64 deadline)";
  const auth = { saleId: id("sale"), saleConfigHash: id("configuration"), payer: A(1), executor: A(2),
    recipient: A(3), artist: A(4), tokenDataHash: id("raw token data"), mintCommitment: id("mint"),
    executionNonce: (1n << 200n) + 7n, nonce: ZeroHash, deadline: (1n << 64n) - 1n };
  const fields = type.slice(type.indexOf("(") + 1, -1).split(",").map(field => field.split(" "));
  const body = keccak256(coder.encode(["bytes32", ...fields.map(field => field[0])], [id(type), ...fields.map(field => auth[field[1]])]));
  const domain = keccak256(coder.encode(["bytes32", "bytes32", "bytes32", "uint256", "address"],
    [id("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
      id("6529StreamUniversalFixedPriceSaleAdapter"), id("1"), chainId, carrier]));
  const digest = keccak256(concat(["0x1901", domain, body]));
  assert.equal(erc20BurnMintAuthorizationPayload(chainId, carrier, auth).digest, digest);
  assert.equal(erc20BurnMintAuthorizationId(chainId, carrier, auth), keccak256(coder.encode(
    ["bytes32", "bytes32"], [id("6529STREAM_MINT_TICKET_AUTHORIZATION_V1"), digest])));
  assert.notEqual(erc20BurnMintAuthorizationPayload(chainId, A(42), auth).digest, digest);
});

test("paid burn fixture retains the exact source capture and complete carrier/gate user surfaces", () => {
  assert.equal(fixture.sourceCommit, "c717a3e10dca06950353c66c6493de41cdfcb9e1");
  assert.equal(fixture.sourceTree, "604224dd42310e747eb329c88e4eb76f1cfed1d5");
  assert.equal(Object.keys(fixture.sources).length, 2108);
  assert.equal(Object.values(fixture.abis).reduce((count, abi) => count + abi.length, 0), 203);
  assert.throws(() => currentERC20BurnMintFixture(Buffer.from("{}"), Buffer.from("{}")), /exact frozen/);
  assert.equal(gate.getFunction("burnAndMint"), null);
  assert.equal(sale.getFunction("purchaseIdFor"), null);
  assert.equal(sale.getFunction("previewExecution").stateMutability, "nonpayable");
  assert.equal(gate.getFunction("previewERC20Burn").stateMutability, "nonpayable");
  assert.equal(sale.getFunction("previewBurnExecution").stateMutability, "view");
});

test("original universal execution nests the full authorization and an ordered dynamic source array", () => {
  const original = "UniversalSaleAuthorization(bytes32 saleId,bytes32 saleConfigHash,address payer,address executor,address recipient,address artist,bytes32 tokenDataHash,bytes32 mintCommitment,uint256 executionNonce,bytes32 nonce,uint64 deadline)";
  const fields = sale.getFunction("authorizationDigest").inputs[0].components;
  assert.equal(fields.map(field => `${field.type} ${field.name}`).join(","), original.slice(original.indexOf("(") + 1, -1));
  const execution = sale.getFunction("previewExecution").inputs[0];
  assert.deepEqual(execution.components.map(field => field.name), ["sale", "sourceTokenIds"]);
  assert.equal(execution.components[1].type, "uint256[]");
  assert.deepEqual(execution.components[0].components.map(field => field.name), ["authorization", "tokenData", "platformSignature", "artistSignature"]);
  for (const [abi, name, expected] of [[sale, "saleRecord", 512], [sale, "previewExecution", 1088],
    [payment, "settleERC20PrimarySaleByPayer", 384], [gate, "executeERC20Burn", 480]]) {
    const outputs = abi.getFunction(name).outputs;
    assert.equal((coder.encode(outputs, coder.getDefaultValue(outputs)).length - 2) / 2, expected);
  }
});

test("Safe inventory accounts for every mutation while separating simulation and guarded transports", () => {
  const inventory = erc20BurnMintSafeInventory(catalog);
  assert.equal(inventory.length, 20); assert(inventory.every(row => !row.payable));
  const exclusions = {
    sale: ["previewExecution", "executeBurnMint", "executeERC20PreRevenueSingleStep"],
    gate: ["previewERC20Burn", "executeERC20Burn"],
    payment: ["fundERC20PrimarySale"], core: [], token: [],
  };
  for (const [kind, excluded] of Object.entries(exclusions)) {
    const abi = new Interface(catalog[kind]);
    const publicWrites = abi.fragments.filter(f => f.type === "function" && !["view", "pure"].includes(f.stateMutability) && !excluded.includes(f.name));
    assert.deepEqual(inventory.filter(row => row.kind === kind).map(row => row.method).sort(), publicWrites.map(f => f.format("sighash")).sort());
  }
});

test("Safe review preserves separate source owner and payer approvals and exact large token values", () => {
  const sourceOwner = A(10), payer = A(11), gateAddress = A(12), paymentAddress = A(13), coreAddress = A(14), asset = A(15);
  const sourceToken = (1n << 220n) + 9n, amount = (1n << 190n) + 100n;
  const review = createERC20BurnMintSafeReview({ chainId: 31337n, title: "Review source and token approvals", catalog,
    actions: [
      { kind: "core", safe: sourceOwner, intent: "Approve gate for the exact source", prepared: { caller: sourceOwner,
        call: { to: coreAddress, data: core.encodeFunctionData("approve", [gateAddress, sourceToken]), value: 0n } } },
      { kind: "token", safe: payer, intent: "Approve contract 20 for the exact price", prepared: { caller: payer,
        call: { to: asset, data: token.encodeFunctionData("approve", [paymentAddress, amount]), value: 0n } } },
    ] });
  assert.equal(review.plan.steps.length, 2);
  assert.equal(review.plan.steps[0].safe, getAddress(sourceOwner)); assert.equal(review.plan.steps[1].safe, getAddress(payer));
  assert.equal(review.plan.steps[0].method, "approve(address,uint256)");
  assert(Object.isFrozen(review));
});

test("Safe review rejects every nonpayable preview/callback despite valid ABI encodings", () => {
  for (const [kind, abi, method] of [["sale", sale, "previewExecution"], ["sale", sale, "executeBurnMint"],
    ["sale", sale, "executeERC20PreRevenueSingleStep"], ["gate", gate, "previewERC20Burn"],
    ["gate", gate, "executeERC20Burn"], ["payment", payment, "fundERC20PrimarySale"]]) {
    const fragment = abi.getFunction(method), args = coder.getDefaultValue(fragment.inputs);
    const prepared = { caller: A(10), call: { to: A(20), data: abi.encodeFunctionData(fragment, args), value: 0n } };
    assert.throws(() => createERC20BurnMintSafeReview({ chainId: 31337n, title: "Invalid user action", catalog,
      actions: [{ kind, safe: A(10), intent: "Invalid transport call", prepared }] }), /not a user-entry/);
  }
  const prepared = { caller: A(10), call: { to: A(20), data: token.encodeFunctionData("approve", [A(21), 1n]), value: 0n } };
  const actions = [{ kind: "token", safe: A(11), intent: "Mismatched payer", prepared }];
  assert.throws(() => createERC20BurnMintSafeReview({ chainId: 31337n, title: "Wrong Safe", catalog, actions }), /actual caller/);
  actions[0].safe = A(10); prepared.call.value = 1n;
  assert.throws(() => createERC20BurnMintSafeReview({ chainId: 31337n, title: "Wrong value", catalog, actions }), /zero native/);
});

test("burn provenance event ABI keeps executor, original source owners and per-token nullifiers", () => {
  assert.deepEqual(gate.getEvent("BurnMintBatchExecuted").inputs.map(f => f.name),
    ["schemaVersion", "targetCollectionId", "operationRoot", "burnCaller", "sourceTokenIds", "sourceOwners", "mintedTokenIds"]);
  const nullifier = id("independently computed source nullifier");
  const log = gate.encodeEventLog("BurnMintExecuted", [1n, 7n, 8n, 9n, nullifier, A(10)]);
  assert.equal(gate.parseLog(log).args.burnNullifier, nullifier);
  const burn = core.encodeEventLog("Transfer", [A(11), ZeroAddress, 7n]);
  assert.equal(core.parseLog(burn).args.to, ZeroAddress);
});
