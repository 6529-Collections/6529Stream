import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { AbiCoder, Interface, ZeroAddress, ZeroHash, getAddress, id, keccak256, toUtf8Bytes } from "ethers";
import { mintFallbackRecoveryTransition, mintFallbackPointerTransition, mintFallbackManifestTransition,
  mintFallbackIncidentActivationCalls, mintFallbackRetirementClassificationCall,
  mintFallbackRawCopyDefinitionsCall, MINT_FALLBACK_MANAGER_INTERFACE_ID } from "../dist/current-mint-fallback.js";
import { prepareMintFallbackGovernance } from "../dist/current-mint-fallback-workflow.js";
import { createMintFallbackSafeReview, createMintFallbackPermissionlessSafeReview } from "../examples/current-mint-fallback.mjs";
import { verifySafeCallPlan } from "../dist/safe-plan.js";

const fixture = JSON.parse(readFileSync(new URL("./fixtures/current-mint-fallback-abi.json", import.meta.url), "utf8"));
const abi = Object.fromEntries(Object.entries(fixture.abis).map(([key, rows]) => [key, new Interface(rows)]));
const recorderFixture = JSON.parse(readFileSync(new URL("./fixtures/current-mint-fallback-recorder-abi.json", import.meta.url), "utf8"));
const coder = AbiCoder.defaultAbiCoder(), A = n => getAddress(`0x${BigInt(n).toString(16).padStart(40, "0")}`);
const H = (types, values) => keccak256(coder.encode(types, values));
const configuration = { chainId: (1n << 240n) + 31337n, core: A(11), ledger: A(12), primary: A(13), fallbackManager: A(14),
  registry: A(15), governance: A(16), coreCodeHash: id("core"), ledgerCodeHash: id("ledger"), primaryCodeHash: id("primary"),
  fallbackCodeHash: id("fallback"), registryCodeHash: id("registry"), governanceCodeHash: id("governance"), moduleVersion: id("moduleVersion"),
  deploymentManifestHash: id("deployment"), moduleManifestHash: id("module"), moduleManifestURI: "ipfs://fallback", moduleGasLimit: 1000000n,
  recorder: ZeroAddress, recorderCodeHash: ZeroHash };

test("fallback compiler fixture retains unchanged Manager surface and explicit recovery companion", () => {
  assert.equal(fixture.sourceCommit, "d1a58e4403cfbb80d921e117e0a7ac9b90ff61c7");
  assert.equal(fixture.sourceCount, 988); assert.equal(Object.keys(fixture.sources).length, 988);
  assert.equal(fixture.inputSha256, "d92d75ef82e9b645b0df856a110bb49f6d52134a2bf42d4c811391a6341586f7");
  assert.equal(fixture.outputSha256, "110472bc5e57b6cea4351ce27daf1d081a9bbb802d763cf0daa2b4f05a61b356");
  for (const row of fixture.abis.manager.filter(row => row.type === "function")) {
    assert.equal(abi.fallback.getFunction(row.name).format("full"), abi.manager.getFunction(row.name).format("full"));
  }
  assert.equal(abi.managerInterface.getFunction("recoverPreparedMint"), null);
  assert.equal(abi.fallback.getFunction("transition"), null);
  assert.equal(abi.recovery.getFunction("transition").format("sighash"), "transition(address,uint256,bytes32)");
  assert.equal(abi.fallback.getFunction("recoverPreparedMint").format("sighash"), "recoverPreparedMint(uint256,bytes32)");
  assert.equal(abi.fallback.getFunction("recoverPreparedMint").stateMutability, "nonpayable");
  const managerId = fixture.abis.managerInterface.filter(row => row.type === "function")
    .reduce((n, row) => n ^ BigInt(abi.managerInterface.getFunction(row.name).selector), 0n);
  assert.equal(`0x${managerId.toString(16).padStart(8, "0")}`, MINT_FALLBACK_MANAGER_INTERFACE_ID);
  const event = abi.fallback.getEvent("MintFallbackPreparedRecovered");
  assert.deepEqual(event.inputs.map(p => [p.name, p.type, p.indexed]), [["schemaVersion", "uint16", false],
    ["actionId", "bytes32", true], ["tokenId", "uint256", true], ["operationId", "bytes32", true], ["collectionId", "uint256", false]]);
  assert.equal(event.format("full"), abi.recovery.getEvent("MintFallbackPreparedRecovered").format("full"));
});

test("concrete paid recorder getters retain separate integration capture provenance", () => {
  assert.equal(recorderFixture.sourceCount, 2138);
  assert.equal(recorderFixture.inputSha256, "c3e27ea0432cbb0548eb191e23243e06f597332045c0f6d96b604f88fc3be159");
  assert.equal(recorderFixture.outputSha256, "70092a7c16deac5fff64a4e8d7a89b2429d988e556387cbe3263e78f3d38c307");
  assert.equal(recorderFixture.abi.length, 5);
  const recorder = new Interface(recorderFixture.abi);
  for (const name of ["core", "moduleRegistry"]) {
    assert.equal(recorder.getFunction(name).format("full"), abi.recorder.getFunction(name).format("full"));
  }
  for (const name of ["coreCodeHash", "moduleRegistryCodeHash"]) {
    assert.equal(recorder.getFunction(name).stateMutability, "view");
    assert.equal(recorder.getFunction(name).outputs[0].type, "bytes32");
  }
});

test("recovery uses independent full-width original scope and unchanged accounting preimages", () => {
  const c = configuration, tokenId = (1n << 245n) + 13n, operationId = id("stranded operation");
  const s = { collectionId: (1n << 229n) + 1n, serial: (1n << 223n) + 2n, lastTokenId: tokenId + 17n,
    nextSerial: (1n << 223n) + 8n, mintedEver: (1n << 219n) + 3n, supply: (1n << 212n) + 4n,
    tokenDataHash: keccak256("0xabcd"), coordinator: A(27) };
  const scope = H(["bytes32", "uint256", "address", "address", "uint256", "bytes32"],
    [id("6529STREAM_MINT_FALLBACK_RECOVERY_SCOPE_V1"), c.chainId, c.core, c.fallbackManager, tokenId, operationId]);
  const retained = H(Array(6).fill("uint256"), [s.collectionId, s.serial, s.lastTokenId, s.nextSerial, s.mintedEver, s.supply]);
  const types = ["bytes32", "bytes32", "bool", "bytes32", "bytes32", "address"], domain = id("6529STREAM_MINT_FALLBACK_RECOVERY_STATE_V1");
  const expected = { scope, oldHash: H(types, [domain, scope, true, retained, s.tokenDataHash, s.coordinator]),
    newHash: H(types, [domain, scope, false, retained, keccak256("0x"), ZeroAddress]) };
  assert.deepEqual(mintFallbackRecoveryTransition(c, tokenId, operationId, s), expected);
  for (const field of ["collectionId", "serial", "lastTokenId", "nextSerial", "mintedEver", "supply"]) {
    const changed = mintFallbackRecoveryTransition(c, tokenId, operationId, { ...s, [field]: s[field] + 1n });
    assert.notEqual(changed.oldHash, expected.oldHash); assert.notEqual(changed.newHash, expected.newHash);
  }
});

test("classification is exact isolated class1 configuration; pointer and manifest remain distinct class3 contexts", () => {
  const c = configuration, selector = abi.ledger.getFunction("retireLedgerWriter").selector;
  const kind = id("6529STREAM_GOVERNANCE_CONFIG_TIGHTENING_CALL"), revision = (1n << 62n) + 7n;
  const stateTypes = ["bytes32", "uint256", "address", "bytes32", "address", "bytes4", "bool", "bytes32", "uint64"];
  const oldHash = H(stateTypes, [id("6529STREAM_GOVERNANCE_CONFIG_STATE_V1"), c.chainId, c.governance, kind, c.ledger, selector, false, ZeroHash, revision]);
  const classified = mintFallbackRetirementClassificationCall(c, { enabled: false, targetCodeHash: ZeroHash, revision, stateHash: oldHash });
  assert.equal(classified.actionClass, 1n); assert.equal(classified.isolated, true); assert.equal(classified.calls.length, 1);
  assert.equal(classified.calls[0].newValueHash, H(stateTypes, [id("6529STREAM_GOVERNANCE_CONFIG_STATE_V1"), c.chainId, c.governance,
    kind, c.ledger, selector, true, c.ledgerCodeHash, revision + 1n]));
  assert.equal(classified.data[0], abi.executor.encodeFunctionData("setTighteningCall", [c.ledger, selector, true]));

  const previous = { target: c.primary, codeHash: c.primaryCodeHash, frozen: false, moduleType: id("MINT_MANAGER"), interfaceId: MINT_FALLBACK_MANAGER_INTERFACE_ID,
    registry: c.registry, registryStatus: 3n, moduleManifestHash: id("old module"), deploymentManifestHash: id("old deployment"), revision: 17n };
  const next = { ...previous, target: c.fallbackManager, codeHash: c.fallbackCodeHash, registryStatus: 1n,
    moduleManifestHash: c.moduleManifestHash, deploymentManifestHash: c.deploymentManifestHash, revision: 18n };
  const pointerScope = H(["bytes32", "uint256", "address", "bytes32"], ["0xf4a381d3d4c51db07c19830799ea01c544326118ea1db1fb59d54af5f637bdbb", c.chainId, c.core, id("MINT_MANAGER")]);
  const pointerHash = p => H(["bytes32", "bytes32", ...abi.core.getFunction("getSatellitePointer").outputs.map(p => p.type)],
    ["0x1fdde0a7122d0fc7c237e721e372e43082581dcc6bd2babca4e09bb1e6b3d043", pointerScope, p.target, p.codeHash, p.frozen,
      p.moduleType, p.interfaceId, p.registry, p.registryStatus, p.moduleManifestHash, p.deploymentManifestHash, p.revision]);
  assert.deepEqual(mintFallbackPointerTransition(c, previous, next), { scope: pointerScope, oldHash: pointerHash(previous), newHash: pointerHash(next) });

  const moduleNames = abi.manifest.getFunction("streamSystemManifest").outputs.slice(2, 13).map(p => p.name);
  const discoveryNames = abi.manifest.getFunction("streamSystemManifest").outputs.slice(13, 20).map(p => p.name);
  const modules = { ...Object.fromEntries(moduleNames.map((name, i) => [name, A(100 + i)])), mintManager: c.primary,
    mintLedger: c.ledger, moduleRegistry: c.registry, streamAdminsOrGovernance: c.governance };
  const discovery = Object.fromEntries(discoveryNames.map(name => [name, id(`old ${name}`)]));
  const update = { ...Object.fromEntries(discoveryNames.map(name => [name, id(`new ${name}`)])), manifestHash: id("next manifest"), manifestURI: "ipfs://next" };
  const activation = { manifest: A(30), payloadRoot: A(31), update, previousPointer: previous,
    current: { modules, discovery, manifestHash: id("prior manifest"), manifestURI: "ipfs://prior", revision: 42n, payloadRoot: A(32) } };
  const scope = H(["bytes32", "uint256", "address"], ["0xf73b4d7b4d260fce0823707f836fdf29a1767a2a2a9cfbce14ec8c5e49e47841", c.chainId, activation.manifest]);
  const manifestHash = (m, d, h, uri, payload, rev) => H(["bytes32", "bytes32", "bytes32", "bytes32", "address", "bytes32", "bytes32", "uint64"],
    ["0x3764ccb415d0aac07f1bddb8d4841ad6d4c2f9b2fe7ce7d221c586bc056aaf60", scope, h, keccak256(toUtf8Bytes(uri)), payload,
      H(Array(11).fill("address"), moduleNames.map(name => m[name])), H(Array(7).fill("bytes32"), discoveryNames.map(name => d[name])), rev]);
  const mt = mintFallbackManifestTransition(c, activation);
  assert.deepEqual(mt, { scope, oldHash: manifestHash(modules, discovery, activation.current.manifestHash, activation.current.manifestURI, A(32), 42n),
    newHash: manifestHash({ ...modules, mintManager: c.fallbackManager }, update, update.manifestHash, update.manifestURI, A(31), 43n) });
  const incident = { tokenId: 71n, operationId: id("operation"), state: { collectionId: 8n, serial: 4n, lastTokenId: 71n,
    nextSerial: 4n, mintedEver: 3n, supply: 2n, tokenDataHash: id("data"), coordinator: A(38) } };
  const plan = mintFallbackIncidentActivationCalls(c, activation, incident);
  assert.equal(plan.actionClass, 3n); assert.equal(plan.factsVerified, false);
  assert.deepEqual(plan.calls.map(row => row.target), [c.core, c.fallbackManager, A(30)]);
  assert.deepEqual(plan.data, [abi.core.encodeFunctionData("updateSatellitePointer", [id("MINT_MANAGER"), c.fallbackManager]),
    abi.fallback.encodeFunctionData("recoverPreparedMint", [71n, incident.operationId]), abi.manifest.encodeFunctionData("publishStreamSystemManifest", [A(31), update])]);
  assert.equal(plan.calls[0].scopeHash, pointerScope); assert.equal(plan.calls[2].scopeHash, scope);
  assert.notEqual(plan.calls[1].scopeHash, scope); assert.equal(plan.calls[2].newValueHash, mt.newHash);
});

test("governance compiled batch carries per-call commitments separately from schedule aggregate fields", () => {
  const schedule = abi.executor.getFunction("scheduleGovernanceBatch"), execute = abi.executor.getFunction("executeGovernanceBatch");
  const fields = [["target", "address"], ["value", "uint256"], ["selector", "bytes4"], ["callDataHash", "bytes32"],
    ["scopeHash", "bytes32"], ["oldValueHash", "bytes32"], ["newValueHash", "bytes32"]];
  assert.deepEqual(schedule.inputs[1].arrayChildren.components.map(p => [p.name, p.type]), fields);
  assert.deepEqual(execute.inputs[1].arrayChildren.components.map(p => [p.name, p.type]), fields);
  assert.deepEqual(schedule.inputs.slice(2, 7).map(p => [p.name, p.type]), [["scopeHash", "bytes32"], ["oldValueHash", "bytes32"],
    ["newValueHash", "bytes32"], ["notBefore", "uint64"], ["expiresAfter", "uint64"]]);
  assert.equal(execute.inputs[2].type, "bytes[]");
  assert.equal(schedule.stateMutability, "nonpayable"); assert.equal(execute.stateMutability, "payable");
  assert.equal(abi.executor.getFunction("minimumDelay").stateMutability, "pure");
  assert.equal(abi.executor.getFunction("setTighteningCall").format("sighash"), "setTighteningCall(address,bytes4,bool)");
  assert.deepEqual(abi.executor.getFunction("tighteningCallConfig").outputs.map(p => p.type), ["bool", "bytes32", "uint64", "bytes32"]);
});

test("compiled pointer and manifest snapshots preserve original complete state ordering", () => {
  assert.deepEqual(abi.core.getFunction("getSatellitePointer").outputs.map(p => p.type),
    ["address", "bytes32", "bool", "bytes32", "bytes4", "address", "uint8", "bytes32", "bytes32", "uint64"]);
  assert.deepEqual(abi.manifest.getFunction("streamSystemManifest").outputs.map(p => p.name), ["manifestHash", "manifestURI",
    "revenueResolver", "metadataRouter", "collectionMetadata", "entropyCoordinator", "mintManager", "mintLedger", "artistRegistry",
    "streamAdminsOrGovernance", "artworkFinalityRegistry", "moduleRegistry", "stateExportPublisher", "eventCatalogHash",
    "compatibilityMatrixHash", "numericIdCatalogHash", "schemaCatalogHash", "canonicalizationCatalogHash", "specBundleHash",
    "reconstructionClientHash", "revision"]);
  const update = abi.manifest.getFunction("publishStreamSystemManifest").inputs[1];
  assert.deepEqual(update.components.map(p => p.name), ["manifestHash", "manifestURI", "eventCatalogHash", "compatibilityMatrixHash",
    "numericIdCatalogHash", "schemaCatalogHash", "canonicalizationCatalogHash", "specBundleHash", "reconstructionClientHash"]);
  assert.equal(update.components.length, 9);
  assert.equal(abi.ledger.getFunction("ledgerWriterRetiredAt").outputs[0].type, "uint64");
  assert.equal(abi.ledger.getFunction("commitCounterImportRoot").inputs[3].type, "uint64");
});

test("Safe example retains exact Executor envelopes, actual actors and full-width ceremony review", () => {
  const c = configuration, selector = abi.ledger.getFunction("retireLedgerWriter").selector;
  const classification = { enabled: false, targetCodeHash: ZeroHash, revision: 0n,
    stateHash: H(["bytes32", "uint256", "address", "bytes32", "address", "bytes4", "bool", "bytes32", "uint64"],
      [id("6529STREAM_GOVERNANCE_CONFIG_STATE_V1"), c.chainId, c.governance, id("6529STREAM_GOVERNANCE_CONFIG_TIGHTENING_CALL"), c.ledger, selector, false, ZeroHash, 0n]) };
  const plan = mintFallbackRetirementClassificationCall(c, classification);
  // Offline review fixture; simulation must independently establish actual pinned chain facts.
  const inspection = { configuration: c, readiness: "configuration", blockNumber: 80, blockHash: id("block80"), timestamp: 900n,
    managerPointer: { target: c.primary, codeHash: c.primaryCodeHash, frozen: false, moduleType: id("MINT_MANAGER"), interfaceId: MINT_FALLBACK_MANAGER_INTERFACE_ID,
      registry: c.registry, registryStatus: 1n, moduleManifestHash: id("primary module"), deploymentManifestHash: id("primary deployment"), revision: 1n },
    classification, primaryRetiredAt: 0n, primaryWriter: true, successorReady: false, governanceNonce: (1n << 243n) + 7n,
    catalog: { candidateProfileHash: id("profile"), catalogHash: id("catalog"), entryCount: 12n, revision: 1n }, import: null, recovery: null };
  const window = { notBefore: 900n + 172800n, expiresAfter: 900n + 172800n + 604800n,
    reasonHash: id("reason"), reasonURI: "ipfs://reviewed", manifestHash: id("ceremony evidence") };
  const prepared = prepareMintFallbackGovernance(inspection, plan, A(82), window);
  const callsHash = H(["bytes32", abi.executor.getFunction("scheduleGovernanceBatch").inputs[1]],
    ["0x10f09566fb70f7947b61639c2a53b3aec872069a8b46edd08ba14eb2b5942b70", plan.calls]);
  const aggregates = [
    ["0x6cfd5dfd67f064adac45602c05057edddda810734779c0ebe11b447e6985e31c", "scopeHash"],
    ["0xc5029f937b44065c2ad92d9253e07f06117567480206189fcc1409d5509222b7", "oldValueHash"],
    ["0xce958009248d20d9574439fa374bc00c142940af2b496896b5bdbc00b882e98b", "newValueHash"],
  ].map(([domain, key]) => H(["bytes32", "bytes32", "bytes32[]"], [domain, callsHash, plan.calls.map(call => call[key])]));
  const identityBody = coder.encode(["tuple(uint8,bytes32,bytes32,bytes32,bytes32,uint256,uint64,uint64,bytes32,bytes32)"],
    [[plan.actionClass, callsHash, ...aggregates, inspection.governanceNonce, window.notBefore, window.expiresAfter, window.reasonHash, window.manifestHash]]);
  const identityHead = coder.encode(["bytes32", "uint256", "address"],
    ["0x214cd728538bb3775a7106caff5c761bace11866a984d4a4d97a98f51971ac4b", c.chainId, c.governance]);
  assert.equal(prepared.batch.callsHash, callsHash);
  assert.equal(prepared.batch.actionId, keccak256(identityHead + identityBody.slice(2)));
  assert.equal(prepared.batch.publicationKey, keccak256(`0x${plan.data.map(bytes => keccak256(bytes).slice(2)).join("")}`));
  for (const [stage, caller, method] of [["publish", A(81), "publishGovernanceCallData"], ["schedule", A(82), "scheduleGovernanceBatch"], ["execute", A(83), "executeGovernanceBatch"]]) {
    const example = createMintFallbackSafeReview({ prepared, stage, safe: caller, executorAbi: fixture.abis.executor });
    verifySafeCallPlan(example.safePlan, [fixture.abis.executor]);
    const step = example.safePlan.steps[0], parsed = abi.executor.parseTransaction({ data: step.transaction.data });
    assert.equal(parsed.name, method); assert.equal(step.safe, caller); assert.equal(step.transaction.to, c.governance);
    assert.equal(step.transaction.value, "0"); assert.equal(step.transaction.operation, 0);
    assert.equal(example.review.actionClass, "1"); assert.equal(example.review.proposer, A(82)); assert.equal(example.review.caller, caller);
    assert.equal(example.review.nonce, inspection.governanceNonce.toString()); assert.equal(example.review.notBefore, window.notBefore.toString());
    assert.equal(example.review.targetCalls[0].target, c.governance); assert.equal(example.review.targetCalls[0].selector, abi.executor.getFunction("setTighteningCall").selector);
    assert.equal(example.review.targetCalls[0].scopeHash, plan.calls[0].scopeHash);
    assert.ok(Object.isFrozen(example.review.targetCalls[0]));
    assert.equal(abi.executor.encodeFunctionData(parsed.fragment, parsed.args), step.transaction.data);
  }
  assert.throws(() => createMintFallbackSafeReview({ prepared, stage: "schedule", safe: A(81), executorAbi: fixture.abis.executor }), /proposer/);
  const copying = mintFallbackRawCopyDefinitionsCall(c, id("actual import root"), 32n);
  const direct = createMintFallbackPermissionlessSafeReview({ inspection, plan: copying, safe: A(84), targetAbi: fixture.abis.ledger });
  verifySafeCallPlan(direct.safePlan, [fixture.abis.ledger]);
  assert.equal(direct.safePlan.steps[0].transaction.to, c.ledger);
  assert.equal(direct.safePlan.steps[0].transaction.data, abi.ledger.encodeFunctionData("importCounterDefinitions", [id("actual import root"), 32n]));
});
