import test from "node:test";
import assert from "node:assert/strict";
import { readFile, mkdtemp, unlink, rmdir } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { prepareRegisteredInventory, persistInventoryJournal, resumeInventoryOpening, verifyInventoryStep } from "../examples/current-inventory-opening.mjs";
import { AbiCoder, Interface, ZeroAddress, ZeroHash, id, keccak256, toUtf8Bytes } from "ethers";
import { CurrentInventoryWorkflow, CurrentSecondaryClient } from "../dist/index.js";
const fixture = JSON.parse(await readFile(new URL("./fixtures/current-secondary-abi.json", import.meta.url), "utf8"));
const abi = new Interface(fixture.abis.adapter), events = new Interface(fixture.abis.inventory), coder = AbiCoder.defaultAbiCoder();
const adapter = "0x0000000000000000000000000000000000006529", owner = "0x0000000000000000000000000000000000000007";
const relayer = "0x0000000000000000000000000000000000000008", core = "0x0000000000000000000000000000000000000009", buyer = "0x0000000000000000000000000000000000000042";
const hostCode = "0x60016000", coreCode = "0x60026000", chainId = 31337n, nonce = (1n << 200n) + 7n;
const pins = { adapterCodeHash: keccak256(hostCode), core, coreCodeHash: keccak256(coreCode) };
const tokenIds = [9n, (1n << 250n) + 1n];
const cfg = () => ({ collectionId: 77n, consignor: owner, unitPrice: (1n << 150n) + 3n, startTime: 1n,
  deadline: 1000n, perBuyerCap: 2n, signerEvidenceHash: id("approved collection seller"), signerRevision: 3n,
  signerAuthority: owner, secondaryConsignment: true, expectedPrimaryPolicyHash: ZeroHash });
const log = (i, name, args, emitter = adapter) => ({ address: emitter, ...i.encodeEventLog(i.getEvent(name), args) });
const safe = new Interface(["event ExecutionSuccess(bytes32 txHash,uint256 payment)", "event ExecutionFailure(bytes32 txHash,uint256 payment)"]);
function setup() {
  const sales = new CurrentSecondaryClient(chainId, adapter, fixture.abis), workflow = new CurrentInventoryWorkflow(chainId, adapter, fixture.abis);
  const config = cfg(), inventoryHash = keccak256(coder.encode(["uint256[]"], [tokenIds]));
  const saleId = keccak256(coder.encode(["bytes32", "uint256", "address", "uint8", "uint256", "bytes32", "uint256"], [id("6529STREAM_SALE_V1"), chainId, adapter, 14n, config.collectionId, ZeroHash, nonce]));
  const configHash = keccak256(coder.encode(["bytes32", "uint256", "address", "uint256", "address", abi.getFunction("registerInventory").inputs[0], "bytes32"],
    [id("6529STREAM_NATIVE_SECONDARY_INVENTORY_CONFIG_V1"), chainId, adapter, nonce, owner, config, inventoryHash]));
  const inventory = { config, configHash, inventoryHash, saleNonce: nonce, createdAt: 100n, registryRevision: 4n, status: 1n, tokenIds: [...tokenIds] };
  const deposits = tokenIds.map((tokenId, i) => ({ caller: i ? relayer : owner, grant: { chainId, saleAdapter: adapter, core, tokenId, owner, saleRef: saleId, nonce: id(`owner grant ${i}`), deadline: 900n }, ownerKind: 2n, signature: i ? "0xabcd" : "0x" }));
  const digests = deposits.map(x => sales.signing("SaleCustodyGrant", x.grant).payload.digest);
  const items = tokenIds.map(tokenId => ({ config: { saleKind: 14n, collectionId: config.collectionId, tokenId, consignor: owner,
    buyer: ZeroAddress, price: config.unitPrice, startTime: config.startTime, deadline: config.deadline, offerDigest: ZeroHash,
    signerEvidenceHash: config.signerEvidenceHash, signerRevision: config.signerRevision, signerAuthority: owner,
    secondaryConsignment: true, expectedPrimaryPolicyHash: ZeroHash }, configHash, saleNonce: nonce, createdAt: 100n,
    registryRevision: 4n, status: 1n, nftClaim: 0n, custodyGrantDigest: ZeroHash, authorizationDigest: ZeroHash,
    royaltyReceiver: ZeroAddress, royaltyAmount: 0n }));
  const state = { inventory, items, consumed: [false, false], revoked: [false, false], block: 100, timestamp: 200,
    failSimulation: false, trailing: false, badCode: false, wrongCore: false, wrongChain: false, reorg: false, badOrigin: false, calls: [], simulations: [] };
  const provider = {
    async getNetwork() { return { chainId: state.wrongChain ? 1n : chainId }; },
    async getBlock(tag) { const number = typeof tag === "number" ? tag : state.block; return { number, timestamp: state.timestamp, hash: id(`block ${number}${state.reorg || (state.badOrigin && number === 100) ? " changed" : ""}`) }; },
    async getCode(target, at) { assert.equal(at, state.block); return state.badCode ? "0x" : target.toLowerCase() === adapter.toLowerCase() ? hostCode : coreCode; },
    async call(tx) {
      assert.equal(tx.to.toLowerCase(), adapter.toLowerCase()); assert.equal(tx.blockTag, state.block); state.calls.push(tx);
      const p = abi.parseTransaction(tx); let values;
      if (p.name === "core") values = [state.wrongCore ? buyer : core];
      else if (p.name === "coreCodeHash") values = [pins.coreCodeHash];
      else if (p.name === "platformSigner") values = [owner];
      else if (p.name === "custodyGrantDigest") values = [sales.signing("SaleCustodyGrant", p.args[0].toObject()).payload.digest];
      else if (p.name === "inventoryDetails") { assert.equal(p.args[0], saleId); values = [inventory]; }
      else if (p.name === "inventoryToken") { assert.equal(p.args[0], saleId); values = [items[tokenIds.indexOf(p.args[1])]]; }
      else if (p.name === "digestConsumed") values = [state.consumed[digests.indexOf(p.args[0])]];
      else if (p.name === "digestRevoked") values = [state.revoked[digests.indexOf(p.args[0])]];
      else if (p.name === "depositInventoryCustody" || p.name === "openInventory") {
        assert.equal(tx.value, 0n); state.simulations.push(tx);
        if (state.failSimulation) throw Error("actual caller/approval simulation failed");
        return "0x";
      } else throw Error(`unexpected ${p.name}`);
      const raw = abi.encodeFunctionResult(p.name, values); return state.trailing ? raw + "00".repeat(32) : raw;
    },
  };
  const receipt = { status: 1, logs: [log(events, "InventoryConfigured", [1n, saleId, inventoryHash, owner, configHash, tokenIds])] };
  const input = { receipt, config, tokenIds: [...tokenIds], deposits, opener: owner, pins };
  const collect = i => { items[i].status = 2n; items[i].custodyGrantDigest = digests[i]; state.consumed[i] = true; };
  return { workflow, sales, provider, state, input, digests, saleId, configHash, inventoryHash, collect };
}
const save = async s => s.workflow.start(s.provider, s.input);

test("saved inventory opening resumes exact original grants, callers and Safe CALLs through all stages", async () => {
  const s = setup(), saved = await save(s), bytes = saved.json;
  assert.equal(saved.hash, keccak256(toUtf8Bytes(bytes))); assert(Object.isFrozen(saved));
  const j = JSON.parse(bytes); assert.equal(j.saleNonce, nonce.toString()); assert.equal(j.deposits[1].tokenId, tokenIds[1].toString());
  assert.equal(j.inventoryHash, s.inventoryHash); assert.equal(j.configHash, s.configHash);
  s.state.block++;
  let step = await s.workflow.resume(s.provider, saved);
  assert.equal(step.status, "deposit"); assert.equal(step.tokenId, tokenIds[0]);
  assert.equal(step.prepared.call.data, s.sales.depositInventory(owner, s.saleId, s.input.deposits[0].grant, 2n, "0x").call.data);
  assert.deepEqual(s.workflow.safeCall(step), { safe: owner, call: { to: step.prepared.call.to, data: step.prepared.call.data, value: "0", operation: 0 } });
  s.collect(0); step = await s.workflow.resume(s.provider, s.workflow.restore(bytes, saved.hash));
  assert.equal(step.tokenId, tokenIds[1]); assert.equal(step.prepared.caller, relayer);
  assert.equal(step.prepared.call.data, j.deposits[1].data); assert.equal(s.state.simulations.at(-1).from, relayer);
  s.collect(1); step = await s.workflow.resume(s.provider, saved);
  assert.equal(step.status, "open"); assert.equal(step.prepared.call.data, abi.encodeFunctionData("openInventory", [s.saleId]));
  s.state.inventory.status = 2n; const count = s.state.simulations.length;
  step = await s.workflow.resume(s.provider, saved); assert.equal(step.status, "opened"); assert.equal(step.prepared, null);
  assert.equal(s.state.simulations.length, count); assert.equal(saved.json, bytes);
  assert.throws(() => s.workflow.safeCall(step), /No pending/);
});

test("failed full CALL simulation leaves exact saved bytes and zero-value retry unchanged", async () => {
  const s = setup(), saved = await save(s); s.state.block++;
  s.state.failSimulation = true; await assert.rejects(s.workflow.resume(s.provider, saved), /simulation failed/);
  const failed = s.state.simulations.at(-1); s.state.failSimulation = false;
  const step = await s.workflow.resume(s.provider, saved); assert.deepEqual(s.state.simulations.at(-1), failed);
  assert.equal(step.prepared.call.data, JSON.parse(saved.json).deposits[0].data);
  assert.equal(step.prepared.call.value, 0n);
});

test("journal restore rejects altered commitments, unknown fields, widths, grant order and ABI changes", async () => {
  const s = setup(), saved = await save(s), parsed = JSON.parse(saved.json);
  for (const mutation of [{ ...parsed, opener: buyer }, { ...parsed, extra: "ignored" }, { ...parsed, saleNonce: "01" }, { ...parsed, originNumber: "9007199254740992" }, { ...parsed, deposits: [...parsed.deposits].reverse() }]) {
    const text = JSON.stringify(mutation); assert.throws(() => s.workflow.restore(text, saved.hash));
  }
  assert.throws(() => s.workflow.restore(saved.json + "\n", saved.hash));
  assert.throws(() => new CurrentInventoryWorkflow(1n, adapter, fixture.abis).restore(saved.json, saved.hash), /schema\/chain/);
  const changed = { ...fixture.abis, adapter: fixture.abis.adapter.filter(x => x.name !== "digestRevoked") };
  assert.throws(() => new CurrentInventoryWorkflow(chainId, adapter, changed), /digestRevoked/);
  const reordered = new CurrentInventoryWorkflow(chainId, adapter, { ...fixture.abis, adapter: [...fixture.abis.adapter].reverse() });
  assert.equal(reordered.restore(saved.json, saved.hash).hash, saved.hash);
});

test("canonical journal parser rejects self-rehashed malformed documents and substituted original grants", async () => {
  const s = setup(), saved = await save(s);
  const canon = x => Array.isArray(x) ? `[${x.map(canon).join(",")}]` : typeof x === "object" ? `{${Object.keys(x).sort().map(k=>JSON.stringify(k)+":"+canon(x[k])).join(",")}}` : JSON.stringify(x);
  for (const update of [j => j.extra = "x", j => j.saleNonce = "01", j => j.deposits.reverse(), j => j.deposits[0].digest = id("different"), j => j.schema = "new schema", j => j.originNumber = "9007199254740992"]) {
    const j = JSON.parse(saved.json); update(j); const text = canon(j);
    assert.throws(() => s.workflow.restore(text, keccak256(toUtf8Bytes(text))));
  }
});

test("start binds actual event emitter, schema, full config and exact grant token/owner/Core identity", async () => {
  for (const change of [s => s.input.receipt.logs[0].address = owner, s => s.input.receipt.status = 0,
    s => s.input.receipt.logs.push(s.input.receipt.logs[0]), s => s.input.deposits.reverse(),
    s => s.input.deposits[0].grant.owner = buyer, s => s.input.deposits[0].grant.core = buyer,
    s => s.input.deposits[0].grant.saleRef = id("wrong sale"), s => s.input.tokenIds.reverse()]) {
    const s = setup(); change(s); await assert.rejects(save(s));
  }
  const s = setup(); s.input = { ...s.input, config: { ...s.input.config, unitPrice: 5n } }; await assert.rejects(save(s), /identity differs/);
});

test("Safe registration and per-step receipts require exact success plus original adapter facts", async () => {
  const s = setup(), safeHash = id("independently verified Safe CALL hash");
  s.input.registrationSafe = { address: owner, transactionHash: safeHash };
  s.input.receipt.logs.push(log(safe, "ExecutionFailure", [safeHash, 0n], owner));
  await assert.rejects(save(s), /target execution failed/);
  s.input.receipt.logs.pop(); s.input.receipt.logs.push(log(safe, "ExecutionSuccess", [safeHash, 0n], owner));
  const saved = await save(s);
  const receipt = { status: 1, logs: [log(abi, "SaleAuthorizationConsumed", [1n, s.saleId, s.digests[0], owner]),
    log(abi, "SaleCustodyDeposited", [1n, s.saleId, tokenIds[0], owner]), log(safe, "ExecutionSuccess", [safeHash, 0n], owner)] };
  s.workflow.verifyStepReceipt(saved, "deposit", tokenIds[0], receipt, safeHash);
  for (const bad of [{ ...receipt, status: 0 }, { ...receipt, logs: receipt.logs.slice(1) },
    { ...receipt, logs: [...receipt.logs, receipt.logs[0]] }, { ...receipt, logs: receipt.logs.map((x,i)=>i===1?{...x,address:buyer}:x) },
    { ...receipt, logs: [...receipt.logs.slice(0,2), log(safe,"ExecutionFailure",[safeHash,0n],owner)] }]) assert.throws(()=>s.workflow.verifyStepReceipt(saved,"deposit",tokenIds[0],bad,safeHash));
  const opened = { status: 1, logs: [log(events,"InventoryOpened",[1n,s.saleId]),log(safe,"ExecutionSuccess",[safeHash,0n],owner)] };
  s.workflow.verifyStepReceipt(saved,"open",null,opened,safeHash);
  assert.throws(()=>s.workflow.verifyStepReceipt(saved,"open",tokenIds[0],opened,safeHash));
  assert.throws(()=>s.workflow.verifyStepReceipt(saved,"open",null,{...opened,logs:[log(events,"InventoryOpened",[1n,id("other")]),opened.logs[1]]},safeHash));
});

test("resume refuses changed complete registration and per-token storage before offering calls", async () => {
  for (const change of [s => s.state.inventory.configHash = id("different"), s => s.state.inventory.registryRevision++, s => s.state.items[0].config.price++,
    s => s.state.items[1].config.consignor = buyer, s => s.state.items[0].createdAt++, s => s.state.items[0].nftClaim = 2n]) {
    const s=setup(), saved=await save(s); s.state.block++; change(s); await assert.rejects(s.workflow.resume(s.provider,saved)); assert.equal(s.state.simulations.length,0);
  }
});

test("revocation, alternate grant and replay conflict do not masquerade as completed custody", async () => {
  for (const change of [s=>s.state.revoked[1]=true, s=>s.state.consumed[0]=true,
    s=>{s.collect(0);s.state.items[0].custodyGrantDigest=id("another accepted grant");}, s=>s.state.items[0].status=4n]) {
    const s=setup(),saved=await save(s);s.state.block++;change(s);await assert.rejects(s.workflow.resume(s.provider,saved)); assert.equal(s.state.simulations.length,0);
  }
});

test("cancel/expire preserve original exits and are distinct from successful opening", async () => {
  for (const [status,name] of [[4n,"cancelled"],[5n,"expired"]]) {
    const s=setup(),saved=await save(s);s.state.block++;s.state.inventory.status=status;
    const result=await s.workflow.resume(s.provider,saved);assert.equal(result.status,name);assert.equal(result.prepared,null);assert.equal(s.state.simulations.length,0);
  }
});

test("expired pending grants refuse while an already-open inventory survives later purchase and deadlines", async () => {
  const s=setup(),saved=await save(s);s.state.block++;s.state.timestamp=901;
  await assert.rejects(s.workflow.resume(s.provider,saved),/grant expired/);
  s.collect(0);s.collect(1);s.state.inventory.status=2n;s.state.timestamp=2000;
  s.state.items[0].status=3n;s.state.items[0].config.buyer=buyer;s.state.items[0].nftClaim=1n;s.state.items[0].royaltyAmount=4n;s.state.items[0].royaltyReceiver=owner;
  assert.equal((await s.workflow.resume(s.provider,saved)).status,"opened");
  s.state.inventory.status=1n;s.state.items[0].status=2n;s.state.items[0].config.buyer=ZeroAddress;s.state.items[0].nftClaim=0n;s.state.items[0].royaltyAmount=0n;s.state.items[0].royaltyReceiver=ZeroAddress;
  await assert.rejects(s.workflow.resume(s.provider,saved),/deadline elapsed/);
});

test("malformed reads, runtime/context drift and reorgs reject without changing saved journal", async () => {
  for (const field of ["trailing","badCode","wrongCore","wrongChain","badOrigin"]) {
    const s=setup(),saved=await save(s),before=saved.json;s.state.block++;s.state[field]=true;
    await assert.rejects(s.workflow.resume(s.provider,saved));assert.equal(saved.json,before);
  }
  const s=setup(),saved=await save(s);s.state.block++;const original=s.provider.call;
  s.provider.call=async tx=>{const raw=await original(tx);if(abi.parseTransaction(tx).name==="depositInventoryCustody")s.state.reorg=true;return raw;};
  await assert.rejects(s.workflow.resume(s.provider,saved),/block changed/);
});

test("await boundaries snapshot the original signed calldata and reviewed configuration", async () => {
  const s=setup(),original=s.provider.getNetwork;let mutated=false;
  s.provider.getNetwork=async()=>{if(!mutated){mutated=true;s.input.deposits[0].signature="0xbeef";s.input.deposits[0].caller=buyer;s.input.config={...s.input.config,unitPrice:1n};}return original();};
  const saved=await save(s),j=JSON.parse(saved.json);const decoded=abi.decodeFunctionData("depositInventoryCustody",j.deposits[0].data);
  assert.equal(decoded[3],"0x");assert.equal(j.deposits[0].caller,owner);assert.equal(abi.decodeFunctionData("registerInventory",j.registrationData)[0].unitPrice,cfg().unitPrice);
});


test("readable file workflow retains the original journal/hash, resumes and rejects accidental overwrite", async () => {
  const s = setup(), saved = await prepareRegisteredInventory(s.workflow, s.provider, s.input);
  const directory = await mkdtemp(join(tmpdir(), "stream-inventory-example-"));
  const journalPath = join(directory, "opening.json"), hashPath = join(directory, "original.hash");
  try {
    await persistInventoryJournal(saved, journalPath, hashPath);
    assert.equal(await readFile(journalPath, "utf8"), saved.json);
    const originalHash = (await readFile(hashPath, "utf8")).trim(); assert.equal(originalHash, saved.hash);
    await assert.rejects(persistInventoryJournal(saved, journalPath, hashPath), /EEXIST/);
    s.state.block++; const next = await resumeInventoryOpening(s.workflow, s.provider, journalPath, originalHash);
    assert.equal(next.next.safe, owner); assert.equal(next.next.call.value, "0"); assert.equal(next.next.call.operation, 0);
    const receipt = { status: 1, logs: [log(abi,"SaleAuthorizationConsumed",[1n,s.saleId,s.digests[0],owner]), log(abi,"SaleCustodyDeposited",[1n,s.saleId,tokenIds[0],owner])] };
    verifyInventoryStep(s.workflow, saved, next.step, receipt);
    assert.equal(await readFile(journalPath, "utf8"), saved.json);
  } finally { await unlink(journalPath).catch(()=>{}); await unlink(hashPath).catch(()=>{}); await rmdir(directory); }
});
