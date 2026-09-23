import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import { AbiCoder, Interface, ZeroAddress, ZeroHash, getAddress, id, keccak256, toUtf8Bytes } from "ethers";
import { inspectBurnFinalityImpact } from "../dist/current-burn-finality.js";
import { burnMintProgramConfigHash } from "../dist/current-burn-mint.js";

const fixture = JSON.parse(readFileSync(new URL("./fixtures/current-burn-finality-abi.json", import.meta.url)));
const abis = Object.fromEntries(Object.entries(fixture.abis).map(([key, values]) => [key, new Interface(values)]));
const erc20Fixture = JSON.parse(readFileSync(new URL("./fixtures/current-erc20-burn-mint-abi.json", import.meta.url)));
const erc20GateAbi = new Interface(erc20Fixture.abis.gate), erc20SaleAbi = new Interface(erc20Fixture.abis.sale);
// Solidity interfaceId excludes inherited IStreamMintGate functions. These are exactly the
// functions declared by IStreamERC20BurnMintGate, resolved from its retained compiler ABI.
const erc20GateId = `0x${["core", "erc20SaleAdapter", "erc20SaleCodeHash", "configureProgram", "program", "programConfigHash",
  "allowedSourceCollections", "burnNullifier", "previewERC20Burn", "executeERC20Burn"]
  .reduce((value, name) => value ^ BigInt(erc20GateAbi.getFunction(name).selector), 0n).toString(16).padStart(8, "0")}`;
const legacyGateAbi = new Interface([...fixture.abis.gate, erc20GateAbi.getFunction("supportsInterface")]);
const coder = AbiCoder.defaultAbiCoder();
const A = n => getAddress(`0x${BigInt(n).toString(16).padStart(40, "0")}`);
const core = A(1), registry = A(2), gate = A(3), redemption = A(4), finality = A(5), manager = A(6), operator = A(7), paidSale = A(8);
const erc20Gate = A(9), carrier = A(10), secondErc20Gate = A(11), extraNativeGate = A(12);
const chainId = 31337n, blockNumber = 20, blockHash = id("block20");
const code = "0x60016000", codeHash = keccak256(code);
const pin = address => ({ address, codeHash });
const snapshotRequest = () => ({ chainId, core: pin(core), moduleRegistry: pin(registry), finality: pin(finality),
  burnMintDeployments: [{ ...pin(gate), fromBlock: 1 }], redemptionDeployments: [{ ...pin(redemption), fromBlock: 1 }],
  action: { kind: "block-burns", collectionId: 1n }, blockNumber, blockHash,
  limits: { maxBlockSpan: 20, maxLogs: 12, maxPrograms: 8, maxCollections: 8 } });
const erc20Pin = (address = erc20Gate) => ({ ...pin(address), fromBlock: 1, saleAdapter: pin(carrier) });
const erc20Request = () => ({ ...snapshotRequest(), erc20BurnMintDeployments: [erc20Pin()] });
const configType = "tuple(uint256 collectionId,uint64 startTime,uint64 endTime,bytes32 termsHash)";
function makeRedemption(config = { collectionId: 1n, startTime: 110n, endTime: 300n, termsHash: id("terms") }, cancelled = false) {
  const saleNonce = 3n;
  const saleId = keccak256(coder.encode(["bytes32", "uint256", "address", "uint8", "uint256", "bytes32", "uint256"], [id("6529STREAM_SALE_V1"), chainId, redemption, 9n, config.collectionId, ZeroHash, saleNonce]));
  const saleConfigHash = keccak256(coder.encode(["bytes32", "uint256", "address", "address", "bytes32", "uint256", "uint8", configType, "bytes32", "address", "uint256", "bytes32", "uint8", "bytes32"], [id("6529STREAM_BURN_REDEMPTION_CONFIG_V1"), chainId, redemption, core, saleId, saleNonce, 9n, config, ZeroHash, ZeroAddress, 0n, ZeroHash, 0n, ZeroHash]));
  return { saleId, program: { config, saleConfigHash, saleNonce, createdAt: 110n, registryRevision: 2n, cancelled } };
}
function emptyFinality() { return { finalized: false, finalityRecordHash: ZeroHash, manifestContentHash: ZeroHash,
  manifestURIHash: ZeroHash, finalityManifestURI: "", componentsHash: ZeroHash, manifestPointer: ZeroAddress, finalizedAt: 0n }; }
function log(abi, name, args, address, number, index) {
  return { address, ...abi.encodeEventLog(name, args), blockNumber: number, blockHash: id(`block${number}`),
    transactionHash: id(`transaction${number}`), transactionIndex: 0, index, removed: false };
}
function context(options = {}) {
  const config = { manager, targetCollectionId: 3n, phaseId: id("burn phase"), sourceCollectionIds: [1n, 2n],
    sourcesPerMint: 2n, startsAt: 100n, endsAt: 0n, prepared: false, nativeSaleAdapter: options.paid ? paidSale : ZeroAddress,
    ...options.mintConfig };
  const mint = { config, configHash: burnMintProgramConfigHash(chainId, gate, core, registry, config),
    managerCodeHash: codeHash, nativeSaleCodeHash: options.paid ? codeHash : ZeroHash };
  const red = makeRedemption(options.redemptionConfig, options.cancelled);
  const mintLog = log(abis.gate, "BurnMintProgramConfigured", [1, config.targetCollectionId, config.manager, config.phaseId, mint.configHash, config], gate, 5, 0);
  const saleLog = log(abis.redemption, "SaleConfigured", [1, red.saleId, red.program.config.collectionId, ZeroHash, 9, ZeroAddress, red.program.saleConfigHash, ZeroHash, 0], redemption, 6, 1);
  const termsLog = log(abis.redemption, "RedemptionTermsRecorded", [1, red.saleId, red.program.config.termsHash, red.program.config.startTime, red.program.config.endTime, red.program.saleNonce, operator], redemption, 6, 2);
  const mints = new Map([[gate, mint]]);
  const erc20Gates = new Set(options.erc20Gates ?? (options.erc20 ? [erc20Gate] : []));
  const extraLogs = [];
  for (const address of [...(options.additionalNative ? [extraNativeGate] : []), ...erc20Gates]) {
    const isERC20 = erc20Gates.has(address);
    const c = { ...config, phaseId: id(`phase ${address}`), prepared: false,
      nativeSaleAdapter: isERC20 ? ZeroAddress : paidSale, ...(isERC20 ? options.erc20Config : {}) };
    const p = { config: c, configHash: burnMintProgramConfigHash(chainId, address, core, registry, c),
      managerCodeHash: codeHash, nativeSaleCodeHash: isERC20 ? options.erc20NativeCodeHash ?? ZeroHash : codeHash };
    mints.set(address, p);
    extraLogs.push(log(isERC20 ? erc20GateAbi : legacyGateAbi, "BurnMintProgramConfigured",
      [1, c.targetCollectionId, c.manager, c.phaseId, p.configHash, c], address, 7, 3 + extraLogs.length));
  }
  const logs = [mintLog, saleLog, termsLog, ...extraLogs];
  const states = new Map([1n, 2n, 3n].map(cid => [cid, {
    exists: true, supplyMode: 1n, status: cid === 1n ? 2n : 0n, hasMaxSupply: true, maxSupply: 10n, mintedEver: 4n,
    frozen: false, burnsBlocked: false, burnsBlockedAtBlock: 0n, finality: emptyFinality(), freezeMode: 0n,
    ...options.collections?.[cid.toString()],
  }]));
  const queries = []; const blockReads = new Map();
  const bindings = new Interface(["function core() view returns (address)", "function moduleRegistry() view returns (address)", "function mintManager() view returns (address)"]);
  const provider = {
    async getNetwork() { options.onNetwork?.(); return { chainId: options.chainId ?? chainId }; },
    async getBlock(number) {
      blockReads.set(number, (blockReads.get(number) ?? 0) + 1);
      const original = { number, hash: id(`block${number}`), timestamp: number === 5 ? 100 : number === 6 ? 110 : options.timestamp ?? 200 };
      return options.block?.(number, blockReads.get(number), original) ?? original;
    },
    async getCode(address, tag) { queries.push({ codeAddress: address, blockTag: tag }); assert.equal(tag, blockNumber); return options.code?.(address) ?? code; },
    async getLogs(filter) {
      queries.push(filter); assert.equal(filter.fromBlock, 1); assert.equal(filter.toBlock, blockNumber);
      return options.logs?.(filter, logs) ?? logs.filter(l => l.address === filter.address && l.topics[0] === filter.topics[0]);
    },
    async call(request) {
      queries.push(request); assert.equal(request.blockTag, blockNumber);
      const abi = request.to === core ? abis.core : erc20Gates.has(request.to) ? erc20GateAbi : mints.has(request.to) ? legacyGateAbi
        : request.to === carrier ? erc20SaleAbi : request.to === redemption ? abis.redemption : request.to === finality ? abis.finality : bindings;
      const parsed = abi.parseTransaction({ data: request.data }), name = parsed.name;
      const raw = options.raw?.(name, parsed.args, request); if (raw !== undefined) return raw;
      let values;
      if (name === "core") values = [core];
      else if (name === "moduleRegistry") values = [registry];
      else if (name === "mintManager") values = [manager];
      else if (["coreCodeHash", "registryCodeHash", "moduleRegistryCodeHash", "mintManagerCodeHash"].includes(name)) values = [codeHash];
      else if (name === "erc20SaleAdapter") values = [carrier];
      else if (name === "erc20SaleCodeHash") values = [codeHash];
      else if (name === "supportsInterface") {
        assert.equal(parsed.args[0], erc20GateId, "exact dedicated interface, excluding inherited selectors");
        values = [erc20Gates.has(request.to)];
      }
      else if (name === "getSatellitePointer") {
        const target = parsed.args[0] === id("MODULE_REGISTRY") ? registry : parsed.args[0] === id("ARTWORK_FINALITY_REGISTRY") ? finality : options.managerPointer ?? manager;
        values = [target, codeHash, false, ZeroHash, "0x00000000", registry, 1, ZeroHash, ZeroHash, 1];
      } else if (name === "program") values = [mints.get(request.to) ?? red.program];
      else if (name === "allowedSourceCollections") values = [mints.get(request.to).config.sourceCollectionIds];
      else if (name === "artworkFreezeMode") {
        assert.equal(parsed.args[0].scopeType, 0n); assert.equal(parsed.args[0].tokenId, 0n); assert.equal(parsed.args[0].scopeId, ZeroHash);
        values = [states.get(parsed.args[0].collectionId).freezeMode];
      } else {
        const s = states.get(parsed.args[0]);
        const fields = { collectionExists: "exists", collectionSupplyMode: "supplyMode", collectionStatus: "status",
          collectionHasMaxSupply: "hasMaxSupply", collectionMaxSupply: "maxSupply", collectionMintedEver: "mintedEver",
          collectionFreezeStatus: "frozen", collectionBurnsBlocked: "burnsBlocked", collectionBurnsBlockedAtBlock: "burnsBlockedAtBlock", collectionFinalityRecord: "finality" };
        if (!fields[name]) throw Error(`Unexpected ${name}`); values = [s[fields[name]]];
      }
      return abi.encodeFunctionResult(name, values);
    },
  };
  return { provider, queries, logs, mint, mints, red, states };
}

test("bounded immutable joins keep CLOSED source burns available and separate action consequences", async () => {
  const ctx = context(), result = await inspectBurnFinalityImpact(ctx.provider, snapshotRequest());
  assert.equal(result.programs.length, 2); assert.equal(result.coverage.inventoryComplete, false);
  assert.equal(result.coverage.executionReadinessChecked, false);
  assert.deepEqual(result.coverage.deployments.map(d => [d.programCount, d.logCount]), [[1, 1], [1, 2]]);
  for (const p of result.programs) {
    assert.equal(p.observedBlockers.length, 0); assert.equal(p.sourceWarnings[0].code, "source-burns-will-stop");
    assert.equal(p.targetWarnings.length, 0); assert.ok(Object.isFrozen(p.sources));
  }
  const source = result.collections.find(c => c.collectionId === 1n);
  assert.equal(source.status, 2n); assert.equal(source.sourceBurnsAllowedByCollection, true);
  assert.equal(result.actionPreconditions.length, 0);
  assert.ok(Object.isFrozen(result)); assert.ok(Object.isFrozen(result.programs[0].program.config.sourceCollectionIds));
});

test("CAPPED_OPEN and UNCAPPED_OPEN targets remain available under Core mint conditions", async () => {
  for (const target of [{ supplyMode: 1n }, { supplyMode: 2n, hasMaxSupply: false, maxSupply: 0n }]) {
    const request = snapshotRequest(); request.action.collectionId = 3n;
    const result = await inspectBurnFinalityImpact(context({ collections: { 3: target } }).provider, request);
    const program = result.programs[0]; assert.equal(program.target.targetMintCapacityAvailable, true);
    assert.equal(program.observedBlockers.length, 0); assert.equal(program.targetWarnings[0].code, "target-closure-required");
    assert.ok(result.actionPreconditions.some(p => p.code === "collection-not-closed"));
  }
});

test("source burn block/freeze warnings remain per-source; target caps distinguish fixed and mutable limits", async () => {
  for (const supplyMode of [0n, 1n]) {
    const result = await inspectBurnFinalityImpact(context({ collections: {
      1: { burnsBlocked: true, burnsBlockedAtBlock: 10n, frozen: true },
      3: { supplyMode, mintedEver: 10n },
    } }).provider, snapshotRequest());
    const p = result.programs[0];
    assert.equal(p.sources[1].sourceBurnsAllowedByCollection, true);
    assert.deepEqual(p.observedBlockers.filter(b => b.role === "source").map(b => b.collectionId), [1n, 1n]);
    const cap = p.observedBlockers.find(b => b.code === "target-cap-reached");
    assert.match(cap.message, supplyMode === 0n ? /immutable cap/ : /permitted cap increase/);
  }
  const paused = await inspectBurnFinalityImpact(context({ collections: { 3: { status: 1n } } }).provider, snapshotRequest());
  assert.equal(paused.programs[0].observedBlockers[0].code, "target-paused");
});

test("collection finality reads only canonical scope0 and validates registry-bound recorded facts", async () => {
  const record = { finalized: true, finalityRecordHash: id("finality"), manifestContentHash: id("manifest"),
    manifestURIHash: keccak256(toUtf8Bytes("")), finalityManifestURI: "", componentsHash: id("components"), manifestPointer: finality, finalizedAt: 190n };
  const request = snapshotRequest(); request.action = { kind: "collection-finality", collectionId: 1n };
  const closed = { status: 2n, burnsBlocked: true, burnsBlockedAtBlock: 10n, frozen: true, finality: record, freezeMode: 2n };
  const result = await inspectBurnFinalityImpact(context({ collections: { 1: closed } }).provider, request);
  assert.equal(result.collections[0].collectionFinality.finalized, true);
  assert.ok(result.actionPreconditions.some(p => p.code === "collection-already-finalized"));
  assert.match(result.programs[0].sourceWarnings[0].message, /does not perform/);
  await assert.rejects(inspectBurnFinalityImpact(context({ collections: { 1: { ...closed, finality: { ...record, manifestPointer: gate } } } }).provider, request), /registry pointer/);
  await assert.rejects(inspectBurnFinalityImpact(context({ collections: { 1: { freezeMode: 1n } } }).provider, request), /freeze mode/);
  for (const scopeType of [1, 2, 3, 4]) {
    const unsupported = { ...snapshotRequest(), action: { kind: "collection-finality", collectionId: 1n, scopeType } };
    await assert.rejects(inspectBurnFinalityImpact({}, unsupported), /unknown fields/);
  }
});

test("expiry is strict, cancelled redemption stays local and zero-ended burn-mint remains open", async () => {
  const exactEnd = context({ timestamp: 300, mintConfig: { endsAt: 300n } });
  assert.equal((await inspectBurnFinalityImpact(exactEnd.provider, snapshotRequest())).programs[0].observedBlockers.length, 0);
  const result = await inspectBurnFinalityImpact(context({ timestamp: 301, cancelled: true }).provider, snapshotRequest());
  assert.equal(result.programs[0].observedBlockers.length, 0);
  assert.deepEqual(result.programs[1].observedBlockers.map(b => b.code), ["program-ended", "program-cancelled"]);
  assert.equal(result.collections[0].sourceBurnsAllowedByCollection, true);
});

test("Manager replacement preserves historical programs and reports current execution blocker", async () => {
  const result = await inspectBurnFinalityImpact(context({ managerPointer: A(99) }).provider, snapshotRequest());
  assert.equal(result.programs[0].program.config.manager, manager);
  assert.equal(result.programs[0].observedBlockers[0].code, "program-manager-not-selected");
  assert.equal(result.programs[1].observedBlockers.length, 0);
  const paid = await inspectBurnFinalityImpact(context({ paid: true }).provider, snapshotRequest());
  assert.equal(paid.programs[0].program.config.nativeSaleAdapter, paidSale);
  await assert.rejects(inspectBurnFinalityImpact(context({ code: a => a === manager ? "0x6002" : undefined }).provider, snapshotRequest()), /code differs/);
});

test("discovery rejects removed/wrong-range/orphaned/duplicate and noncanonical event data", async () => {
  for (const mutate of [
    l => ({ ...l, removed: true }), l => ({ ...l, blockNumber: 0 }),
    l => ({ ...l, blockHash: id("orphaned block") }), l => ({ ...l, data: l.data + "00" }),
  ]) {
    const ctx = context({ logs: (filter, logs) => logs.filter(l => l.address === filter.address && l.topics[0] === filter.topics[0]).map(mutate) });
    await assert.rejects(inspectBurnFinalityImpact(ctx.provider, snapshotRequest()));
  }
  await assert.rejects(inspectBurnFinalityImpact(context({ logs: (f, logs) => logs.filter(l => l.address === f.address && l.topics[0] === f.topics[0]).flatMap(l => [l, l]) }).provider, snapshotRequest()), /Duplicate/);
});

test("redemption kind9, exact TermsRecorded transaction and immutable commitments are mandatory", async () => {
  for (const change of ["missing", "wrong-transaction", "wrong-terms", "wrong-kind"]) {
    const ctx = context({ logs: (filter, logs) => {
      let selected = logs.filter(l => l.address === filter.address && l.topics[0] === filter.topics[0]);
      if (filter.address !== redemption) return selected;
      const terms = filter.topics[0] === abis.redemption.getEvent("RedemptionTermsRecorded").topicHash;
      if (change === "missing" && terms) return [];
      if (change === "wrong-transaction" && terms) return selected.map(l => ({ ...l, transactionHash: id("other transaction") }));
      if (change === "wrong-terms" && terms) return selected.map(l => ({ ...l, topics: [l.topics[0], l.topics[1], id("wrong terms")] }));
      if (change === "wrong-kind" && !terms) return selected.map(l => {
        const args = [...abis.redemption.decodeEventLog("SaleConfigured", l.data, l.topics)]; args[4] = 10n;
        return { ...l, ...abis.redemption.encodeEventLog("SaleConfigured", args) };
      });
      return selected;
    } });
    await assert.rejects(inspectBurnFinalityImpact(ctx.provider, snapshotRequest()), /terms event|kind 9|terms event|configuration requires/);
  }
  const changedCreationBlock = context({ block: (n, c, b) => n === 6 ? { ...b, timestamp: 111 } : undefined });
  await assert.rejects(inspectBurnFinalityImpact(changedCreationBlock.provider, snapshotRequest()), /creation timestamp/);
});

test("unknown collections/programs, source-list disagreement and noncanonical RPC fail closed", async () => {
  await assert.rejects(inspectBurnFinalityImpact(context({ collections: { 2: { exists: false } } }).provider, snapshotRequest()), /Unknown collection/);
  const unknown = abis.gate.encodeFunctionResult("program", coder.getDefaultValue(abis.gate.getFunction("program").outputs));
  await assert.rejects(inspectBurnFinalityImpact(context({ raw: (n, a, req) => n === "program" && req.to === gate ? unknown : undefined }).provider, snapshotRequest()));
  await assert.rejects(inspectBurnFinalityImpact(context({ raw: n => n === "allowedSourceCollections" ? abis.gate.encodeFunctionResult(n, [[1n]]) : undefined }).provider, snapshotRequest()), /allowed source/);
  for (const raw of ["0x" + "00".repeat(8193), "0x" + "0".repeat(63) + "2", "0x"]) {
    await assert.rejects(inspectBurnFinalityImpact(context({ raw: n => n === "collectionExists" ? raw : undefined }).provider, snapshotRequest()), /oversized|Noncanonical|length/);
  }
  await assert.rejects(inspectBurnFinalityImpact(context({ collections: { 1: { burnsBlockedAtBlock: 4n } } }).provider, snapshotRequest()), /Inconsistent/);
});

test("deployment/range/count bounds are explicit and inputs snapshot before the first await", async () => {
  const original = snapshotRequest();
  const rpc = context({ onNetwork() { original.action.collectionId = 999n; original.core.address = gate; original.burnMintDeployments[0].fromBlock = 999; original.limits.maxLogs = 0; } });
  const result = await inspectBurnFinalityImpact(rpc.provider, original); assert.equal(result.action.collectionId, 1n);
  assert.equal(result.request.core.address, core); assert.equal(result.request.burnMintDeployments[0].fromBlock, 1);
  assert.equal(result.request.limits.maxLogs, 12); assert.ok(Object.isFrozen(result.request.core));
  assert.ok(Object.isFrozen(result.request.burnMintDeployments)); assert.ok(Object.isFrozen(result.request.limits));
  for (const limits of [{ maxBlockSpan: 19 }, { maxLogs: 2 }, { maxPrograms: 1 }, { maxCollections: 2 }]) {
    const request = snapshotRequest(); request.limits = { ...request.limits, ...limits };
    await assert.rejects(inspectBurnFinalityImpact(context().provider, request), /bound|exceeds/);
  }
  const duplicate = snapshotRequest(); duplicate.redemptionDeployments[0].address = gate;
  await assert.rejects(inspectBurnFinalityImpact({}, duplicate), /distinct/);
  const excessive = snapshotRequest(); excessive.burnMintDeployments = Array.from({ length: 17 }, (_, i) => ({ ...pin(A(100 + i)), fromBlock: 1 }));
  await assert.rejects(inspectBurnFinalityImpact({}, excessive), /16 deployments/);
  await assert.rejects(inspectBurnFinalityImpact(context({ chainId: 1n }).provider, snapshotRequest()), /chain differs/);
});

test("a supplied empty discovery set remains explicitly incomplete and checks the proposed collection", async () => {
  const request = snapshotRequest(); request.burnMintDeployments = []; request.redemptionDeployments = [];
  request.action = { kind: "freeze", collectionId: 1n };
  const result = await inspectBurnFinalityImpact(context().provider, request);
  assert.equal(result.programs.length, 0); assert.equal(result.collections.length, 1);
  assert.equal(result.coverage.inventoryComplete, false);
  assert.deepEqual(result.actionPreconditions.map(w => w.code), ["burns-not-blocked"]);
});

test("inspection rejects historical or current block changes before returning", async () => {
  for (const number of [5, 6, 20]) {
    const ctx = context({ block: (n, count, b) => n === number && count >= 2 ? { ...b, hash: id("new canonical block") } : undefined });
    await assert.rejects(inspectBurnFinalityImpact(ctx.provider, snapshotRequest()), /block changed/);
  }
});

test("mixed free/native/ERC20/redemption discovery preserves original commitments and independent roles", async () => {
  const request = erc20Request(); request.burnMintDeployments.push({ ...pin(extraNativeGate), fromBlock: 1 });
  const ctx = context({ erc20: true, additionalNative: true });
  const report = await inspectBurnFinalityImpact(ctx.provider, request);
  assert.deepEqual(report.programs.map(p => p.kind).sort(), ["burn-mint", "burn-mint", "burn-redemption", "erc20-burn-mint"].sort());
  const paid = report.programs.find(p => p.kind === "erc20-burn-mint");
  assert.equal(paid.deployment, erc20Gate); assert.equal(paid.program.configHash, ctx.mints.get(erc20Gate).configHash);
  assert.equal(paid.program.config.nativeSaleAdapter, ZeroAddress);
  assert.deepEqual(paid.sourceWarnings.map(w => [w.code, w.collectionId]), [["source-burns-will-stop", 1n]]);
  assert.equal(paid.sources[1].sourceBurnsAllowedByCollection, true);
  assert.equal(paid.targetWarnings.length, 0); assert.equal(paid.observedBlockers.length, 0);
  const covered = report.coverage.deployments.find(p => p.kind === "erc20-burn-mint");
  assert.deepEqual([covered.address, covered.fromBlock, covered.toBlock, covered.logCount, covered.programCount], [erc20Gate, 1, 20, 1, 1]);
  assert.equal(report.coverage.inventoryComplete, false); assert.equal(report.coverage.executionReadinessChecked, false);
  for (const address of [gate, extraNativeGate, erc20Gate]) {
    const calls = ctx.queries.filter(q => q.to === address && q.data.startsWith(erc20GateAbi.getFunction("supportsInterface").selector));
    assert.equal(calls.length, 1); assert.equal(calls[0].blockTag, blockNumber);
  }
  assert.ok(ctx.queries.some(q => q.codeAddress === carrier && q.blockTag === blockNumber));

  request.action = { kind: "collection-finality", collectionId: 3n };
  const closing = await inspectBurnFinalityImpact(context({ erc20: true, additionalNative: true }).provider, request);
  const target = closing.programs.find(p => p.kind === "erc20-burn-mint");
  assert.equal(target.sourceWarnings.length, 0);
  assert.ok(target.targetWarnings.some(w => w.code === "target-finality-requires-closure"));
});

test("an ERC20 gate with no discovered programs still authenticates its dedicated carrier", async () => {
  const request = erc20Request(); request.burnMintDeployments = []; request.redemptionDeployments = [];
  const ctx = context({ erc20: true, logs: () => [] });
  const result = await inspectBurnFinalityImpact(ctx.provider, request);
  assert.deepEqual(result.programs, []); assert.equal(result.collections.length, 1);
  assert.deepEqual(result.coverage.deployments, [{ kind: "erc20-burn-mint", address: erc20Gate,
    fromBlock: 1, toBlock: 20, logCount: 0, programCount: 0 }]);
  assert.equal(result.coverage.inventoryComplete, false);
  assert.ok(ctx.queries.some(q => q.codeAddress === carrier && q.blockTag === blockNumber));
  assert.ok(ctx.queries.some(q => q.to === carrier && q.data === erc20SaleAbi.encodeFunctionData("coreCodeHash")));
  assert.ok(!ctx.queries.some(q => q.to === erc20Gate && q.data.startsWith(erc20GateAbi.getFunction("program").selector)));
  let carrierRead = false;
  const invalid = context({ erc20: true, logs: () => [], raw(name, args, req) {
    if (req.to !== carrier || name !== "core") return undefined;
    carrierRead = true; return erc20SaleAbi.encodeFunctionResult(name, [A(99)]);
  } });
  await assert.rejects(inspectBurnFinalityImpact(invalid.provider, request), /carrier.*dependenc|binding/i);
  assert.equal(carrierRead, true);
});

test("ERC20 program timing retains inclusive start and end boundaries and zero-ended availability", async () => {
  const request = erc20Request(); request.burnMintDeployments = []; request.redemptionDeployments = [];
  for (const [timestamp, endsAt, expected] of [
    [249, 300n, ["program-not-started"]], [250, 300n, []], [300, 300n, []],
    [301, 300n, ["program-ended"]], [301, 0n, []],
  ]) {
    const ctx = context({ erc20: true, timestamp, erc20Config: { startsAt: 250n, endsAt } });
    const result = await inspectBurnFinalityImpact(ctx.provider, request);
    assert.equal(result.programs[0].kind, "erc20-burn-mint");
    assert.deepEqual(result.programs[0].observedBlockers.map(w => w.code), expected, `timestamp ${timestamp}, end ${endsAt}`);
    assert.deepEqual(result.programs[0].sourceWarnings.map(w => w.code), ["source-burns-will-stop"]);
  }
});

test("omitted ERC20 deployments preserve the legacy request shape and explicitly bounded inventory", async () => {
  const ctx = context({ erc20: true });
  const omitted = await inspectBurnFinalityImpact(ctx.provider, snapshotRequest());
  assert.equal(Object.hasOwn(omitted.request, "erc20BurnMintDeployments"), false);
  assert.equal(omitted.programs.length, 2); assert.equal(omitted.coverage.inventoryComplete, false);
  assert.ok(!ctx.queries.some(q => q.to === erc20Gate || q.address === erc20Gate || q.codeAddress === carrier));
  const explicit = { ...snapshotRequest(), erc20BurnMintDeployments: [] };
  const empty = await inspectBurnFinalityImpact(context().provider, explicit);
  assert.deepEqual(empty.request.erc20BurnMintDeployments, []);
  assert.deepEqual(empty.programs, omitted.programs);
});

test("dedicated gates cannot be declared as free and original gates cannot be declared as ERC20", async () => {
  const hidden = snapshotRequest(); hidden.burnMintDeployments = [{ ...pin(erc20Gate), fromBlock: 1 }];
  await assert.rejects(inspectBurnFinalityImpact(context({ erc20: true }).provider, hidden), /ERC20|profile|interface|dedicated/i);
  const wrong = erc20Request(); wrong.burnMintDeployments = []; wrong.erc20BurnMintDeployments[0].address = gate;
  await assert.rejects(inspectBurnFinalityImpact(context().provider, wrong), /ERC20|profile|interface|dedicated/i);
  for (const raw of ["0x", `0x${"0".repeat(63)}2`, `0x${"0".repeat(63)}1${"00".repeat(32)}`]) {
    await assert.rejects(inspectBurnFinalityImpact(context({ erc20: true,
      raw: (name, args, req) => name === "supportsInterface" && req.to === erc20Gate ? raw : undefined,
    }).provider, erc20Request()), /length|Noncanonical|canonical|boolean/i);
  }
});

test("ERC20 gate and carrier runtime pins are independent, nonempty and exact", async () => {
  for (const target of [erc20Gate, carrier]) {
    for (const runtime of ["0x", "0x60026000"]) {
      await assert.rejects(inspectBurnFinalityImpact(context({ erc20: true,
        code: address => address === target ? runtime : undefined,
      }).provider, erc20Request()), /code differs/i);
    }
    const request = erc20Request();
    if (target === carrier) request.erc20BurnMintDeployments[0].saleAdapter.codeHash = id("wrong runtime pin");
    else request.erc20BurnMintDeployments[0].codeHash = id("wrong runtime pin");
    await assert.rejects(inspectBurnFinalityImpact(context({ erc20: true }).provider, request), /code differs/i);
  }
});

test("every ERC20 gate/carrier immutable address and hash binding is authenticated", async () => {
  const mutations = [
    [erc20Gate, erc20GateAbi, "erc20SaleAdapter", A(99)], [erc20Gate, erc20GateAbi, "erc20SaleCodeHash", id("wrong carrier hash")],
    [erc20Gate, erc20GateAbi, "core", A(99)], [erc20Gate, erc20GateAbi, "coreCodeHash", id("wrong core hash")],
    [erc20Gate, erc20GateAbi, "moduleRegistry", A(99)], [erc20Gate, erc20GateAbi, "registryCodeHash", id("wrong registry hash")],
    [carrier, erc20SaleAbi, "core", A(99)], [carrier, erc20SaleAbi, "coreCodeHash", id("wrong core hash")],
    [carrier, erc20SaleAbi, "moduleRegistry", A(99)], [carrier, erc20SaleAbi, "moduleRegistryCodeHash", id("wrong registry hash")],
    [carrier, erc20SaleAbi, "mintManager", A(99)], [carrier, erc20SaleAbi, "mintManagerCodeHash", id("wrong manager hash")],
  ];
  for (const [target, abi, method, replacement] of mutations) {
    let observed = false;
    const ctx = context({ erc20: true, raw(name, args, req) {
      if (req.to !== target || name !== method) return undefined;
      observed = true; return abi.encodeFunctionResult(name, [replacement]);
    } });
    await assert.rejects(inspectBurnFinalityImpact(ctx.provider, erc20Request()), undefined, `${target}.${method}`);
    assert.equal(observed, true, `read ${target}.${method} before rejecting`);
  }
  const replaced = await inspectBurnFinalityImpact(context({ erc20: true, managerPointer: A(99) }).provider, erc20Request());
  assert.ok(replaced.programs.find(p => p.kind === "erc20-burn-mint").observedBlockers.some(w => w.code === "program-manager-not-selected"));
});

test("ERC20 program rejects prepared/native profiles and mismatched original event/getter sources", async () => {
  for (const options of [{ erc20Config: { prepared: true } }, { erc20Config: { nativeSaleAdapter: paidSale } }, { erc20NativeCodeHash: codeHash }]) {
    await assert.rejects(inspectBurnFinalityImpact(context({ erc20: true, ...options }).provider, erc20Request()), /ERC20|prepared|native|profile/i);
  }
  for (const method of ["program", "allowedSourceCollections"]) {
    const ctx = context({ erc20: true });
    const original = ctx.provider.call.bind(ctx.provider);
    ctx.provider.call = async req => {
      if (req.to !== erc20Gate) return original(req);
      const parsed = erc20GateAbi.parseTransaction({ data: req.data });
      if (parsed.name !== method) return original(req);
      return erc20GateAbi.encodeFunctionResult(method, method === "program"
        ? [{ ...ctx.mints.get(erc20Gate), configHash: id("substituted original commitment") }] : [[2n]]);
    };
    await assert.rejects(inspectBurnFinalityImpact(ctx.provider, erc20Request()), /event|program|source/i);
  }
});

test("distinct ERC20 gates may share one exact carrier while conflicting code pins fail", async () => {
  const request = erc20Request(); request.erc20BurnMintDeployments.push(erc20Pin(secondErc20Gate));
  const result = await inspectBurnFinalityImpact(context({ erc20Gates: [erc20Gate, secondErc20Gate] }).provider, request);
  const programs = result.programs.filter(p => p.kind === "erc20-burn-mint");
  assert.deepEqual(programs.map(p => p.deployment), [erc20Gate, secondErc20Gate]);
  assert.notEqual(programs[0].program.configHash, programs[1].program.configHash, "original config hash remains gate-bound");
  assert.deepEqual(result.request.erc20BurnMintDeployments.map(p => p.saleAdapter), [pin(carrier), pin(carrier)]);
  request.erc20BurnMintDeployments[1].saleAdapter.codeHash = id("conflicting shared carrier pin");
  await assert.rejects(inspectBurnFinalityImpact(context({ erc20Gates: [erc20Gate, secondErc20Gate] }).provider, request), /pin|code|conflict|differ/i);
});

test("ERC20 deployment fields, nested pins and aggregate discovery retain explicit bounds", async () => {
  const invalid = [
    r => { r.erc20BurnMintDeployments = null; },
    r => { delete r.erc20BurnMintDeployments[0].saleAdapter; },
    r => { r.erc20BurnMintDeployments[0].saleAdapter.address = ZeroAddress; },
    r => { r.erc20BurnMintDeployments[0].saleAdapter.extra = true; },
    r => { r.erc20BurnMintDeployments[0].extra = true; },
    r => { r.erc20BurnMintDeployments[0].fromBlock = 0; },
    r => { r.erc20BurnMintDeployments.push(erc20Pin()); },
    r => { r.erc20BurnMintDeployments = Array.from({ length: 17 }, (_, i) => erc20Pin(A(100 + i))); },
    r => { r.erc20BurnMintDeployments[0].saleAdapter.address = core; },
    r => { r.erc20BurnMintDeployments[0].saleAdapter.address = erc20Gate; },
  ];
  for (const mutate of invalid) {
    const request = erc20Request(); mutate(request);
    let networkReads = 0;
    await assert.rejects(inspectBurnFinalityImpact({ async getNetwork() { networkReads++; return { chainId }; } }, request));
    assert.equal(networkReads, 0, "reject malformed deployment input before any RPC");
  }
  for (const limits of [{ maxLogs: 3 }, { maxPrograms: 2 }]) {
    const request = erc20Request(); request.limits = { ...request.limits, ...limits };
    await assert.rejects(inspectBurnFinalityImpact(context({ erc20: true }).provider, request), /bound|exceed/i);
  }
});

test("ERC20 nested deployment input is copied before await and its report is deeply frozen", async () => {
  const request = erc20Request();
  const ctx = context({ erc20: true, onNetwork() {
    request.erc20BurnMintDeployments[0].address = A(99);
    request.erc20BurnMintDeployments[0].fromBlock = 999;
    request.erc20BurnMintDeployments[0].saleAdapter.address = A(98);
    request.erc20BurnMintDeployments[0].saleAdapter.codeHash = id("late mutation");
    request.erc20BurnMintDeployments.push(erc20Pin(secondErc20Gate));
  } });
  const result = await inspectBurnFinalityImpact(ctx.provider, request);
  assert.deepEqual(result.request.erc20BurnMintDeployments, [erc20Pin()]);
  assert.ok(Object.isFrozen(result.request.erc20BurnMintDeployments));
  assert.ok(Object.isFrozen(result.request.erc20BurnMintDeployments[0]));
  assert.ok(Object.isFrozen(result.request.erc20BurnMintDeployments[0].saleAdapter));
  assert.ok(Object.isFrozen(result.programs.find(p => p.kind === "erc20-burn-mint").program.config));
});

test("ERC20 discovery rechecks its historical block and rejects malformed carrier return data", async () => {
  await assert.rejects(inspectBurnFinalityImpact(context({ erc20: true,
    block: (number, count, value) => number === 7 && count >= 2 ? { ...value, hash: id("ERC20 orphaned event") } : undefined,
  }).provider, erc20Request()), /block changed/);
  for (const raw of ["0x", `0x${"00".repeat(8193)}`, `0x${"00".repeat(32)}${"00".repeat(32)}`]) {
    await assert.rejects(inspectBurnFinalityImpact(context({ erc20: true,
      raw: (name, args, req) => req.to === carrier && name === "mintManagerCodeHash" ? raw : undefined,
    }).provider, erc20Request()), /length|oversized|canonical/i);
  }
});
