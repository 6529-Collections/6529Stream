import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { AbiCoder, Interface, ZeroAddress, ZeroHash, getAddress, id, keccak256 } from "ethers";
import { prepareERC20BurnMintAction, simulateERC20BurnMintAction } from "../dist/current-erc20-burn-mint.js";

const fixture = JSON.parse(readFileSync(new URL("./fixtures/current-erc20-burn-mint-abi.json", import.meta.url), "utf8"));
const abi = Object.fromEntries(["sale", "gate", "payment", "core", "asset"].map(role =>
  [role, new Interface(fixture.abis[role === "asset" ? "token" : role])]));
const coder = AbiCoder.defaultAbiCoder();
const A = n => getAddress(`0x${BigInt(n).toString(16).padStart(40, "0")}`);
const chainId = (1n << 190n) + 31337n, blockTag = 144, blockHash = id("action block"), timestamp = 500;
const pinNames = ["adapter", "core", "moduleRegistry", "manager", "ledger", "gate", "payment", "recorder", "asset"];
const code = "0x600060005260206000f3", codeHash = keccak256(code);
const owner = A(90), sourceOwner = A(91), payer = A(92), artist = A(93), relayer = A(94), governor = A(95);
const nextOwner = A(96), executor = A(97), collectionId = (1n << 170n) + 9n;
const phaseId = id("action phase"), nonce = (1n << 150n) + 7n, tokenId = (1n << 200n) + 5n;
const amount = (1n << 220n) + 1000n;
function deployment() {
  return { chainId, ...Object.fromEntries(pinNames.map((role, index) => [role, { address: A(index + 1), codeHash }])) };
}
function configuration(d = deployment()) {
  return { paymentAdapter: d.payment.address, collectionId, phaseId, asset: d.asset.address, price: amount,
    startsAt: 100n, endsAt: 1000n, mintPolicyHash: id("mint policy"), expectedPrimaryPolicyHash: id("primary policy") };
}
function program(d = deployment()) {
  return { manager: d.manager.address, targetCollectionId: collectionId, phaseId,
    sourceCollectionIds: [1n, collectionId], sourcesPerMint: 2n, startsAt: 100n, endsAt: 1000n,
    prepared: false, nativeSaleAdapter: ZeroAddress };
}
function expectedSaleId(d = deployment(), c = configuration(d), expectedNonce = nonce) {
  return keccak256(coder.encode(["bytes32", "uint256", "address", "uint8", "uint256", "bytes32", "uint256"],
    [id("6529STREAM_SALE_V1"), d.chainId, d.adapter.address, 8n, c.collectionId, c.phaseId, expectedNonce]));
}
function expectedProgramHash(d = deployment(), c = program(d)) {
  return keccak256(coder.encode(["bytes32", "uint256", "address", "address", "address", abi.gate.getFunction("configureProgram").inputs[0]],
    [id("6529STREAM_BURN_MINT_CONFIG_V1"), d.chainId, d.gate.address, d.core.address, d.moduleRegistry.address, c]));
}
function cases(d = deployment()) {
  const config = configuration(d), gateConfig = program(d), saleId = expectedSaleId(d, config);
  return [
    { actor: owner, action: { target: "sale", kind: "registerSale", configuration: config, expectedNonce: nonce }, args: [config], identity: saleId },
    { actor: owner, action: { target: "sale", kind: "cancelSale", saleId }, args: [saleId], identity: null },
    { actor: owner, action: { target: "sale", kind: "setPaused", paused: true }, args: [true], identity: null },
    { actor: artist, action: { target: "sale", kind: "cancelAuthorization", nonce: ZeroHash }, args: [ZeroHash], identity: null },
    { actor: owner, action: { target: "gate", kind: "configureProgram", configuration: gateConfig }, args: [gateConfig], identity: expectedProgramHash(d, gateConfig) },
    ...["sale", "gate"].flatMap(target => [
      { actor: governor, action: { target, kind: "raiseGasParameter", parameterId: id(`${target} governed gas`), value: 700_000n }, args: [id(`${target} governed gas`), 700_000n], identity: null },
      { actor: owner, action: { target, kind: "transferOwnership", newOwner: nextOwner }, args: [nextOwner], identity: null },
      { actor: owner, action: { target, kind: "renounceOwnership" }, args: [], identity: null },
    ]),
    { actor: payer, action: { target: "payment", kind: "revokePaymentIntent", nonce: ZeroHash }, args: [ZeroHash], identity: null },
    { actor: relayer, action: { target: "payment", kind: "revokePaymentIntentWithSignature", revocation: { payer, nonce: ZeroHash, deadline: (1n << 63n) + 3n }, signature: "0xaabb001122" },
      args: [{ payer, nonce: ZeroHash, deadline: (1n << 63n) + 3n }, "0xaabb001122"], identity: null },
    { actor: sourceOwner, action: { target: "core", kind: "approve", approved: d.gate.address, tokenId }, args: [d.gate.address, tokenId], identity: null },
    { actor: sourceOwner, action: { target: "core", kind: "setApprovalForAll", operator: executor, approved: true }, args: [executor, true], identity: null },
    { actor: payer, action: { target: "asset", kind: "approve", spender: d.payment.address, amount }, args: [d.payment.address, amount], identity: null },
  ];
}
function target(d, action) { return d[action.target === "sale" ? "adapter" : action.target].address; }
function mockProvider(d, row, options = {}) {
  const observed = { calls: [], codePins: [], headers: 0 };
  return { observed,
    getNetwork: async () => ({ chainId: options.chainId ?? d.chainId }),
    getBlock: async tag => {
      assert.equal(tag, blockTag); observed.headers++;
      if (options.missingBlock) return null;
      return { number: options.wrongBlockNumber ? tag + 1 : tag,
        hash: options.changedBlock && observed.headers > 1 ? id("replacement block") : blockHash,
        timestamp: options.changedTimestamp && observed.headers > 1 ? timestamp + 1 : timestamp };
    },
    getCode: async (address, tag) => {
      assert.equal(tag, blockTag); assert(pinNames.some(role => d[role].address === address));
      observed.codePins.push(address);
      return address === options.changedCodeAddress ? "0x6001600055" : code;
    },
    call: async request => {
      observed.calls.push(request); assert.equal(request.blockTag, blockTag); assert.equal(request.value, 0n);
      if (request.to === d.adapter.address && request.data === abi.sale.encodeFunctionData("nextSaleNonce")) {
        assert.equal(request.from, undefined);
        return abi.sale.encodeFunctionResult("nextSaleNonce", [options.observedNonce ?? nonce]);
      }
      assert.equal(request.to, target(d, row.action)); assert.equal(request.from, row.actor);
      assert.equal(request.data, abi[row.action.target].encodeFunctionData(row.action.kind, row.args));
      if (options.targetError) throw options.targetError;
      let output;
      if (Object.hasOwn(options, "raw")) return options.raw;
      if (row.identity !== null) output = [options.returnIdentity ?? row.identity];
      else if (row.action.target === "asset") output = [options.approvalResult ?? true];
      else output = [];
      return abi[row.action.target].encodeFunctionResult(row.action.kind, output);
    },
  };
}

test("all sixteen admin, configuration, approval and revocation actions retain compiled target and actual actor", async () => {
  const d = deployment(), rows = cases(d);
  assert.equal(rows.length, 16);
  assert.equal(new Set(rows.map(row => `${row.action.target}:${row.action.kind}`)).size, 16);
  for (const row of rows) {
    const plan = prepareERC20BurnMintAction(d, row.actor, row.action);
    assert.equal(plan.caller, row.actor); assert.equal(plan.call.to, target(d, row.action)); assert.equal(plan.call.value, 0n);
    assert.equal(plan.call.data, abi[row.action.target].encodeFunctionData(row.action.kind, row.args));
    assert.equal(plan.expectedIdentity, row.identity);
    const provider = mockProvider(d, row);
    await simulateERC20BurnMintAction(provider, plan, { blockTag });
    assert.equal(provider.observed.headers, 2);
    assert.deepEqual(provider.observed.codePins.sort(), pinNames.map(role => d[role].address).sort());
    assert.equal(provider.observed.calls.filter(call => call.from === row.actor).length, 1);
  }
});

test("registration retains expected nonce, kind-eight sale identity and original config-hash preimage", async () => {
  const d = deployment(), row = cases(d)[0], plan = prepareERC20BurnMintAction(d, owner, row.action);
  const decoded = abi.sale.decodeFunctionData("registerSale", plan.call.data)[0];
  const configType = abi.sale.getFunction("registerSale").inputs[0];
  const fromCalldata = keccak256(coder.encode(["bytes32", "bytes32", configType],
    [id("6529STREAM_UNIVERSAL_FIXED_PRICE_CONFIG_V1"), plan.expectedIdentity, decoded]));
  assert.equal(fromCalldata, keccak256(coder.encode(["bytes32", "bytes32", configType],
    [id("6529STREAM_UNIVERSAL_FIXED_PRICE_CONFIG_V1"), expectedSaleId(d), configuration(d)])));
  assert.equal(plan.action.expectedNonce, nonce); assert.equal(decoded.price, amount);
  const stale = mockProvider(d, row, { observedNonce: nonce + 1n });
  await assert.rejects(simulateERC20BurnMintAction(stale, plan, { blockTag }), /Registration nonce changed/);
  assert.equal(stale.observed.calls.length, 1); // Do not simulate a different sale registration after nonce drift.
  await assert.rejects(simulateERC20BurnMintAction(mockProvider(d, row, { returnIdentity: id("other sale") }), plan, { blockTag }), /configuration identity differs/);
});

test("program configuration preserves original gate/core/registry hash and ERC20-only immutable profile", async () => {
  const d = deployment(), row = cases(d).find(row => row.action.kind === "configureProgram");
  const plan = prepareERC20BurnMintAction(d, owner, row.action);
  assert.equal(plan.expectedIdentity, expectedProgramHash(d));
  assert.notEqual(plan.expectedIdentity, expectedProgramHash({ ...d, gate: { ...d.gate, address: A(50) } }));
  const decoded = abi.gate.decodeFunctionData("configureProgram", plan.call.data)[0];
  assert.equal(decoded.prepared, false); assert.equal(decoded.nativeSaleAdapter, ZeroAddress);
  assert.deepEqual([...decoded.sourceCollectionIds], [1n, collectionId]);
  for (const changed of [{ manager: A(50) }, { prepared: true }, { nativeSaleAdapter: d.adapter.address }]) {
    assert.throws(() => prepareERC20BurnMintAction(d, owner, { ...row.action, configuration: { ...program(d), ...changed } }));
  }
  await assert.rejects(simulateERC20BurnMintAction(mockProvider(d, row, { returnIdentity: id("other program") }), plan, { blockTag }), /configuration identity differs/);
});

test("source token approval, executor operator approval and payer token allowance remain separate actions", () => {
  const d = deployment(), rows = cases(d).slice(-3);
  const [source, operator, token] = rows.map(row => prepareERC20BurnMintAction(d, row.actor, row.action));
  assert.equal(source.caller, sourceOwner); assert.equal(operator.caller, sourceOwner); assert.equal(token.caller, payer);
  assert.equal(abi.core.decodeFunctionData("approve", source.call.data)[0], d.gate.address);
  assert.equal(abi.core.decodeFunctionData("approve", source.call.data)[1], tokenId);
  assert.equal(abi.core.decodeFunctionData("setApprovalForAll", operator.call.data)[0], executor);
  assert.equal(abi.asset.decodeFunctionData("approve", token.call.data)[0], d.payment.address);
  assert.equal(abi.asset.decodeFunctionData("approve", token.call.data)[1], amount);
  assert.notEqual(token.call.to, source.call.to);
  const clear = prepareERC20BurnMintAction(d, sourceOwner, { target: "core", kind: "approve", approved: ZeroAddress, tokenId });
  assert.equal(abi.core.decodeFunctionData("approve", clear.call.data)[0], ZeroAddress);
  const disable = prepareERC20BurnMintAction(d, sourceOwner, { target: "core", kind: "setApprovalForAll", operator: executor, approved: false });
  assert.equal(abi.core.decodeFunctionData("setApprovalForAll", disable.call.data)[1], false);
  const permit2 = A(60);
  const permitApproval = prepareERC20BurnMintAction(d, payer, { target: "asset", kind: "approve", spender: permit2, amount });
  assert.equal(permitApproval.action.spender, permit2);
  assert.equal(abi.asset.decodeFunctionData("approve", permitApproval.call.data)[0], permit2);
  assert.notEqual(permitApproval.call.data, token.call.data); // Reviewed spender is explicit, never silently substituted.
  assert.throws(() => prepareERC20BurnMintAction(d, payer, { target: "asset", kind: "approve", amount }), /unknown/);
  assert.throws(() => prepareERC20BurnMintAction(d, payer, { target: "asset", kind: "approve", spender: ZeroAddress, amount }));
});

test("Artist and payer zero nonces remain independent and signed payment revocation retains its full tuple", async () => {
  const d = deployment(), rows = cases(d), cancel = rows.find(row => row.action.kind === "cancelAuthorization");
  const direct = rows.find(row => row.action.kind === "revokePaymentIntent"), relayed = rows.find(row => row.action.kind === "revokePaymentIntentWithSignature");
  const artistPlan = prepareERC20BurnMintAction(d, artist, cancel.action), payerPlan = prepareERC20BurnMintAction(d, payer, direct.action);
  const relayedPlan = prepareERC20BurnMintAction(d, relayer, relayed.action);
  assert.equal(artistPlan.action.nonce, ZeroHash); assert.equal(payerPlan.action.nonce, ZeroHash);
  assert.notEqual(artistPlan.call.to, payerPlan.call.to); assert.notEqual(artistPlan.call.data, payerPlan.call.data);
  const decoded = abi.payment.decodeFunctionData("revokePaymentIntentWithSignature", relayedPlan.call.data);
  assert.equal(decoded[0].payer, payer); assert.equal(decoded[0].nonce, ZeroHash);
  assert.equal(decoded[0].deadline, (1n << 63n) + 3n); assert.equal(decoded[1], relayed.action.signature);
  await simulateERC20BurnMintAction(mockProvider(d, relayed), relayedPlan, { blockTag });
  assert.throws(() => prepareERC20BurnMintAction(d, relayer, { ...relayed.action, revocation: { ...relayed.action.revocation, deadline: 1n << 64n } }), /uint64/);
});

test("action plans snapshot nested inputs and reject forged transports before any RPC", async () => {
  const d = deployment(), row = cases(d).find(row => row.action.kind === "configureProgram");
  const original = structuredClone(d), plan = prepareERC20BurnMintAction(d, owner, row.action), data = plan.call.data;
  d.gate.address = A(50); d.core.codeHash = id("changed runtime"); row.action.configuration.sourceCollectionIds[0] = 2n;
  assert.equal(plan.call.data, data); assert.equal(plan.deployment.gate.address, original.gate.address);
  assert.equal(plan.deployment.core.codeHash, original.core.codeHash); assert.equal(plan.action.configuration.sourceCollectionIds[0], 1n);
  assert(Object.isFrozen(plan.action.configuration.sourceCollectionIds)); assert(Object.isFrozen(plan.deployment.gate));
  const revoked = cases(original).find(row => row.action.kind === "revokePaymentIntentWithSignature");
  const savedRevocation = prepareERC20BurnMintAction(original, relayer, revoked.action);
  revoked.action.revocation.payer = executor; assert.equal(savedRevocation.action.revocation.payer, payer);
  const unavailable = new Proxy({}, { get() { throw Error("RPC must not run for a forged plan"); } });
  for (const changed of [{ call: { ...plan.call, value: 1n } }, { call: { ...plan.call, to: original.payment.address } },
    { call: { ...plan.call, data: abi.gate.encodeFunctionData("renounceOwnership") } }, { expectedIdentity: id("invented identity") }]) {
    await assert.rejects(simulateERC20BurnMintAction(unavailable, { ...plan, ...changed }, { blockTag }), /differs/);
  }
});

test("preview, guarded callbacks, unknown target/action pairs and transport widening are rejected", () => {
  const d = deployment();
  for (const [target, kind] of [["sale", "previewExecution"], ["sale", "previewBurnExecution"], ["sale", "executeBurnMint"],
    ["sale", "executeERC20PreRevenueSingleStep"], ["gate", "previewERC20Burn"], ["gate", "executeERC20Burn"],
    ["payment", "fundERC20PrimarySale"], ["gate", "burnAndMint"]]) {
    assert.throws(() => prepareERC20BurnMintAction(d, owner, { target, kind }), /callbacks and preview/);
  }
  for (const action of [{ target: "payment", kind: "transferOwnership", newOwner: owner },
    { target: "gate", kind: "cancelAuthorization", nonce: ZeroHash }, { target: "sale", kind: "revokePaymentIntent", nonce: ZeroHash },
    { target: "sale", kind: "setPaused", paused: "true" }, { target: "core", kind: "approve", approved: owner, tokenId: 1 }]) {
    assert.throws(() => prepareERC20BurnMintAction(d, owner, action));
  }
  assert.throws(() => prepareERC20BurnMintAction(d, owner, { target: "sale", kind: "renounceOwnership", value: 1n }), /unknown/);
  assert.throws(() => prepareERC20BurnMintAction({ ...d, gate: { ...d.adapter } }, owner, { target: "sale", kind: "renounceOwnership" }), /distinct/);
});

test("simulation rejects malformed or noncanonical return bytes, false token approval and target authority failure", async () => {
  const d = deployment(), row = cases(d).at(-1), plan = prepareERC20BurnMintAction(d, payer, row.action);
  for (const raw of ["0x", "0x01", `0x${"00".repeat(31)}02`, `${abi.asset.encodeFunctionResult("approve", [true])}${"00".repeat(32)}`]) {
    await assert.rejects(simulateERC20BurnMintAction(mockProvider(d, row, { raw }), plan, { blockTag }));
  }
  await assert.rejects(simulateERC20BurnMintAction(mockProvider(d, row, { approvalResult: false }), plan, { blockTag }), /approval did not succeed/);
  const admin = cases(d).find(row => row.action.kind === "setPaused"), adminPlan = prepareERC20BurnMintAction(d, admin.actor, admin.action);
  await assert.rejects(simulateERC20BurnMintAction(mockProvider(d, admin, { raw: ZeroHash }), adminPlan, { blockTag }), /Noncanonical/);
  const denied = Error("contract target rejected caller authority");
  await assert.rejects(simulateERC20BurnMintAction(mockProvider(d, admin, { targetError: denied }), adminPlan, { blockTag }), error => error === denied);
});

test("simulation rejects chain mismatch, stale code pins and changing concrete block identity", async () => {
  const d = deployment(), row = cases(d).find(row => row.action.kind === "cancelSale"), plan = prepareERC20BurnMintAction(d, owner, row.action);
  const wrongChain = mockProvider(d, row, { chainId: chainId + 1n });
  await assert.rejects(simulateERC20BurnMintAction(wrongChain, plan, { blockTag }), /chain mismatch/);
  assert.equal(wrongChain.observed.calls.length, 0);
  for (const role of ["adapter", "gate", "core", "payment", "asset"]) {
    const changed = mockProvider(d, row, { changedCodeAddress: d[role].address });
    await assert.rejects(simulateERC20BurnMintAction(changed, plan, { blockTag }), /Runtime code mismatch/);
    assert.equal(changed.observed.calls.length, 0);
  }
  for (const change of [{ changedBlock: true }, { changedTimestamp: true }]) {
    await assert.rejects(simulateERC20BurnMintAction(mockProvider(d, row, change), plan, { blockTag }), /Inspection block changed/);
  }
  for (const change of [{ missingBlock: true }, { wrongBlockNumber: true }]) {
    await assert.rejects(simulateERC20BurnMintAction(mockProvider(d, row, change), plan, { blockTag }), /Missing\/mismatched block/);
  }
});
