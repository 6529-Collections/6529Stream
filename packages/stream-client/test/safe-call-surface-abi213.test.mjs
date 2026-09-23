import test from "node:test";
import assert from "node:assert/strict";
import { buildSurfaceInventory, canonical, sha256, serializeInventory, CURRENT_37_ROLE_MAP, CURRENT_SUPPORT_COMPANIONS, CURRENT_IMPLEMENTATION_ONLY_LIBRARIES, CURRENT_CALLER_ROUTE_RULES } from "../scripts/generate-safe-call-surface-abi213.mjs";

function fixture() {
  const sources = {}, committedBlobSHA256 = {}, contracts = {};
  const addSource = (path, content, artifact) => {
    sources[path] = { content };
    committedBlobSHA256[path] = sha256(content);
    if (artifact) contracts[path] = artifact;
  };
  const addCurrentProduct = (name, kind = "contract") => {
    const path = "smart-contracts/current-roster/" + name + ".sol";
    const methods = [...new Set(["readCurrent", "writeCurrent", ...CURRENT_CALLER_ROUTE_RULES.filter(([contract]) => contract === name).flatMap(([, names]) => names)])];
    const abi = kind === "library" ? [] : methods.map((method, index) => ({ type: "function", name: method,
      stateMutability: index === 0 ? "view" : "nonpayable", inputs: [], outputs: [] }));
    const methodIdentifiers = Object.fromEntries(methods.map((method, index) => [method + "()", (index + 1).toString(16).padStart(8, "0")]));
    addSource(path, kind + " " + name + " {}", { [name]: { abi, evm: { methodIdentifiers } } });
  };
  const roster = [];
  for (let i = 0; i < 164; i++) {
    const name = "Supported" + i, path = "smart-contracts/supported/" + name + ".sol";
    const count = i === 163 ? 33 : 40;
    addSource(path, "contract " + name + " {}", { [name]: {
      abi: Array.from({ length: count }, (_, j) => ({ type: "function", name: "f" + j,
        stateMutability: j % 2 ? "view" : "nonpayable", inputs: [{ name: "value", type: "uint256" }], outputs: [] })),
      evm: { methodIdentifiers: Object.fromEntries(Array.from({ length: count }, (_, j) => ["f" + j + "(uint256)", (i * 40 + j).toString(16).padStart(8, "0")])) },
    } });
    roster.push("| `" + path + ":" + name + "` | " + count + " | retained |");
  }
  const candidateAbi = [
    { type: "function", name: "readValue", stateMutability: "view", inputs: [], outputs: [{ type: "uint256" }] },
    { type: "function", name: "writeValue", stateMutability: "nonpayable", inputs: [], outputs: [] },
    { type: "receive", stateMutability: "payable" },
    { type: "fallback", stateMutability: "payable" },
  ];
  addSource("smart-contracts/domains/mint/Candidate.sol", "contract Candidate {}", { Candidate: {
    abi: candidateAbi, evm: { methodIdentifiers: { "readValue()": "aabbccdd", "writeValue()": "11223344" } },
  } });
  addSource("smart-contracts/domains/mint/ICandidate.sol", "interface ICandidate {}", { ICandidate: { abi: [] } });
  addSource("smart-contracts/domains/mint/AbstractCandidate.sol", "abstract contract AbstractCandidate {}", { AbstractCandidate: { abi: [] } });
  addSource("smart-contracts/domains/mint/CandidateLib.sol", "library CandidateLib {}", { CandidateLib: { abi: [] } });
  addSource("smart-contracts/domains/catalog/CatalogOnly.sol", "contract CatalogOnly {}", { CatalogOnly: {
    abi: [{ type: "function", name: "readCatalogOnly", stateMutability: "view", inputs: [], outputs: [] }],
    evm: { methodIdentifiers: { "readCatalogOnly()": "12345678" } },
  } });
  addSource("smart-contracts/legacy/OldCandidate.sol", "contract OldCandidate {}", { OldCandidate: { abi: [] } });
  addSource("smart-contracts/legacy/UsedLegacyModule.sol", "contract UsedLegacyModule {}", { UsedLegacyModule: { abi: [] } });
  addSource("smart-contracts/domains/mint/TupleCandidate.sol", "contract TupleCandidate {}", { TupleCandidate: {
    abi: [{ type: "function", name: "configure", stateMutability: "nonpayable", inputs: [{ name: "config", type: "tuple", internalType: "struct Config", components: [{ name: "value", type: "uint256" }] }], outputs: [] }],
    evm: { methodIdentifiers: { "configure(Config)": "ddeeccbb" } },
  } });
  addSource("script/current/DeployCandidate.s.sol", "contract DeployCandidate { function x() external { new Candidate(); new StreamNativeFixedPriceSaleAdapter(); type(Candidate).creationCode; type(TupleCandidate).creationCode; type(UsedLegacyModule).creationCode; } }");
  const currentNames = [...new Set([...CURRENT_37_ROLE_MAP.map(([, name]) => name), ...CURRENT_SUPPORT_COMPANIONS.map(([, name]) => name)])];
  for (const name of currentNames) addCurrentProduct(name);
  for (const [, name] of CURRENT_IMPLEMENTATION_ONLY_LIBRARIES) addCurrentProduct(name, "library");
  const roleSource = "contract StreamFullV1Candidate { function capture() external { inventory.roles = [" +
    CURRENT_37_ROLE_MAP.map(([expression]) => expression).join(", ") + "]; } }";
  addSource("script/current/StreamFullV1Candidate.sol", roleSource);
  addSource("test/Candidate.t.sol", "contract CandidateTest { // CommentOnly\n string memory ignored = \"StringOnly\"; Candidate target; ICandidate api; CandidateLib lib; AbstractCandidate abstractTarget; }");

  const input = { sources, settings: { optimizer: { enabled: true } } };
  const bridge = { commit: "a0f92ecae8414d36aa715ae1e37d5fb222c0db97", committedBlobSHA256, mismatches: [] };
  const output = { contracts };
  const entries = [{ id: 1, key: "CANDIDATE_ROLE", deployment_scope: "singleton", implementation: { mode: "exact", names: ["Candidate"] }, approved_aliases: [] }];
  for (let i = 2; i <= 37; i++) entries.push({ id: i, key: "ROLE_" + i,
    implementation: i === 2 ? { mode: "exact", names: ["Supported0"] } : { mode: "manifest_equivalent", names: [] }, approved_aliases: [] });
  const genesis = { entries };
  const planningCandidate = { candidate_id: "planning", status: "planning", production_candidate: false,
    readiness_evidence: false, instances: [], genesis_profile: { entry_count: 37 } };
  const currentTargets = { contracts: [{ name: "Candidate", source: "smart-contracts/domains/mint/Candidate.sol" }] };
  const catalog = { production_contracts: [
    { name: "Candidate", source: "smart-contracts/domains/mint/Candidate.sol" },
    { name: "CatalogOnly", source: "smart-contracts/domains/catalog/CatalogOnly.sol" },
    { name: "ICandidate", source: "smart-contracts/domains/mint/ICandidate.sol" },
    { name: "CandidateLib", source: "smart-contracts/domains/mint/CandidateLib.sol" },
    { name: "AbstractCandidate", source: "smart-contracts/domains/mint/AbstractCandidate.sol" },
    { name: "OldCandidate", source: "smart-contracts/legacy/OldCandidate.sol" },
  ] };
  const oldSummary = { capture: { sourceCommit: "aa2ca4a2764ca981630c668966a665637692842d" },
    summary: { primaryContracts: 164, primaryFunctions: 6553 } };
  return {
    inputRaw: JSON.stringify(input), outputRaw: JSON.stringify(output), bridgeRaw: JSON.stringify(bridge),
    rosterMarkdown: roster.join("\n"), historicalSummaryRaw: JSON.stringify(oldSummary), genesisRaw: JSON.stringify(genesis),
    planningCandidateRaw: JSON.stringify(planningCandidate), currentTargetsRaw: JSON.stringify(currentTargets), catalogRaw: JSON.stringify(catalog),
  };
}

test("ABI213 refresh preserves historical totals and expands the supported roster from the current capture", () => {
  const report = buildSurfaceInventory(fixture());
  assert.deepEqual(report.historicalTotals, { contracts: 164, functions: 6553, viewOrPure: 3276, stateChanging: 3277, payableFunctions: 0, receive: 0, fallback: 0 });
  assert.equal(report.surfaces.length, 164 + report.selection.addedCurrentSupportProducts);
  assert.equal(report.totals.contracts, 164 + report.selection.addedCurrentSupportProducts);
  assert.equal(report.capture.sourceCommit, "a0f92ecae8414d36aa715ae1e37d5fb222c0db97");
  assert.equal(report.surfaces[0].functions[0].selector, "0x00000000");
});

test("current full37 capture resolves to concrete products while preserving historical labels separately", () => {
  const report = buildSurfaceInventory(fixture());
  assert.equal(report.current37RoleCoverage.length, 37);
  assert.equal(report.current37RoleCoverage[0].currentProduct, "StreamCore");
  assert.equal(report.current37RoleCoverage[1].currentProduct, "StreamGovernanceExecutor");
  assert.equal(report.current37RoleCoverage[13].currentProduct, "StreamNativeFixedPriceSaleAdapter");
  assert.equal(report.current37RoleCoverage[15].currentProduct, "StreamNativeDutchSale");
  assert.equal(report.current37RoleCoverage[20].currentProduct, "StreamArtistOnboardingRegistry");
  assert.equal(report.current37RoleCoverage[23].currentProduct, "StreamCollectionMetadataV1");
  assert.equal(report.current37RoleCoverage[26].currentProduct, "StreamPreservationRecordsV1");
  assert.equal(report.current37RoleCoverage[31].currentProduct, "StreamEntropyProviderARRNG");
  assert.equal(report.current37RoleCoverage[34].currentProduct, "StreamMintManagerFallback");
  assert.equal(report.current37RoleCoverage[1].supportDisposition, "current-role-expansion");
  assert.equal(report.current37RoleCoverage[1].historicalProfileLabel.key, "ROLE_2");
  assert.equal(report.historicalGenesisRoleLabels.length, 37);
  assert.equal(report.genesisRoleCoverage, undefined);
  assert.ok(report.currentSupportRoster.some(x => x.name === "StreamArtistBindingLifecycle" && x.supportCompanions.length));
  assert.ok(report.implementationOnlyLibraries.every(x => x.status === "implementation-only-not-standalone-safe-target"));
  assert.ok(report.candidateProductsAbsent164.every(x => x.supportDisposition === "catalog-only-not-promoted"
    || x.supportDisposition === "anchored-candidate-not-selected-by-current37-capture" || x.currentSupportRosterMember));
  const catalogOnly = report.candidateProductsAbsent164.find(x => x.name === "CatalogOnly");
  assert.equal(catalogOnly.supportDisposition, "catalog-only-not-promoted");
  assert.equal(catalogOnly.currentSupportRosterMember, false);
  const selected = report.candidateProductsAbsent164.find(x => x.name === "StreamNativeFixedPriceSaleAdapter");
  assert.equal(selected.supportedSurfaceFqn, selected.fqn);
  assert.equal(Object.hasOwn(selected, "abiFunctions"), false);
  assert.ok(report.surfaces.find(x => x.contract === "StreamNativeFixedPriceSaleAdapter").functions.length > 0);
  const serialized = serializeInventory(report);
  assert.deepEqual(JSON.parse(serialized), JSON.parse(JSON.stringify(report)));
  assert.match(serialized, /"functions": \[\n\s+\{"signature":/);
});

test("new commerce, ARRNG, and records surfaces carry focused source-backed caller routes", () => {
  const report = buildSurfaceInventory(fixture());
  const surface = name => report.surfaces.find(x => x.contract === name);
  const route = (product, method) => surface(product).callerRoutes.find(x => x.signature.startsWith(method + "("));
  assert.equal(route("StreamNativeDutchSale", "registerDutchSale").callerClass, "governance-executor-owner-action");
  assert.equal(route("StreamNativeDutchSale", "pauseAdapter").callerClass, "configured-role-holder-safe-candidate");
  assert.equal(route("StreamNativeDutchSale", "purchase").callerClass, "user-or-artist-safe-executor-action");
  assert.equal(route("StreamNativeFixedPriceSaleAdapter", "purchaseWithBurn").callerClass, "user-or-artist-safe-executor-action");
  assert.equal(route("StreamNativeFixedPriceSaleAdapter", "executeBurnPurchase").callerClass, "native-burn-gate-protocol-callback");
  assert.match(route("StreamNativeFixedPriceSaleAdapter", "executeBurnPurchase").basis, /one-use commitment/);
  assert.equal(route("StreamERC20PrimarySettlementAdapter", "settleERC20PrimarySaleByPayer").callerClass, "payer-safe-or-signed-payment-intent");
  assert.equal(route("StreamPrimarySaleSettlement", "settleNativePrimarySaleFromAdapter").callerClass, "registered-sale-adapter-protocol-callback");
  assert.equal(route("StreamEntropyProviderARRNG", "requestEntropy").callerClass, "entropy-coordinator-protocol-callback");
  assert.equal(route("StreamEntropyProviderARRNG", "receiveRandomness").callerClass, "arrng-controller-protocol-callback");
  assert.equal(route("StreamEntropyProviderARRNG", "updateRequestPayment").callerClass, "governance-executor-current-action");
  assert.equal(route("StreamPreservationRecordsV1", "recordCollectionRecordWithPayload").callerClass, "artist-safe-authorized-record-write");
  assert.equal(route("StreamPreservationRecordsV1", "recordCollectionRecordWithPayload").callerBindingRequired, true);
  assert.equal(route("StreamNativeDutchSale", "registerDutchSale").callerBindingRequired, true);
  assert.equal(route("StreamNativeFixedPriceSaleAdapter", "executeBurnPurchase").callerBindingRequired, true);
  assert.match(route("StreamNativeFixedPriceSaleAdapter", "executeBurnPurchase").bindingNote, /burn gate/);
  for (const product of ["StreamNativeDutchSale", "StreamEntropyProviderARRNG", "StreamPreservationRecordsV1"]) {
    assert.ok(surface(product).callerRoutes.every(x => x.selector && x.evidencePaths.length > 0));
  }
});

test("anchored gap list keeps concrete current products and qualifies deployment, catalog, reads, and tests", () => {
  const report = buildSurfaceInventory(fixture());
  const candidate = report.candidateProductsAbsent164.find(row => row.fqn === "smart-contracts/domains/mint/Candidate.sol:Candidate");
  assert.ok(candidate);
  assert.equal(candidate.deploymentEvidence.status, "not-established");
  assert.equal(candidate.deploymentEvidence.planningCandidateHasNoInstances, true);
  assert.equal(candidate.deploymentEvidence.productionReceiptIncluded, false);
  assert.equal(candidate.publicationEvidence.currentContractTarget, true);
  assert.equal(candidate.publicationEvidence.productionContractCatalog, true);
  assert.equal(candidate.readAndCallEvidence.viewOrPureFunctionCount, 1);
  assert.equal(candidate.readAndCallEvidence.stateChangingFunctionCount, 1);
  assert.equal(candidate.readAndCallEvidence.runtimeCallsObserved, false);
  assert.equal(candidate.abiFunctions.find(fn => fn.signature === "readValue()").selector, "0xaabbccdd");
  const tupleCandidate = report.candidateProductsAbsent164.find(row => row.fqn.endsWith(":TupleCandidate"));
  assert.equal(tupleCandidate.abiFunctions[0].signature, "configure((uint256))");
  assert.equal(tupleCandidate.abiFunctions[0].compilerMethodIdentifierSignature, "configure(Config)");
  assert.equal(tupleCandidate.abiFunctions[0].selector, "0xddeeccbb");
  assert.deepEqual(tupleCandidate.abiFunctions[0].inputs, ["(uint256)"]);
  assert.equal(candidate.receiveCount, 1);
  assert.equal(candidate.fallbackCount, 1);
  assert.ok(candidate.anchors.some(anchor => anchor.kind === "genesis-role" && anchor.roleKey === "CANDIDATE_ROLE"));
  assert.ok(candidate.anchors.some(anchor => anchor.kind === "current-deployment-construction"));
  assert.ok(candidate.readAndCallEvidence.testsObserved.some(anchor => anchor.path === "test/Candidate.t.sol"));
  assert.ok(!candidate.anchors.some(anchor => anchor.path.includes("CommentOnly") || anchor.path.includes("StringOnly")));
  assert.ok(report.excludedAnchoredProducts.some(row => row.fqn.endsWith(":OldCandidate") && row.exclusionReason === "legacy-only source"));
  assert.ok(report.candidateProductsAbsent164.some(row => row.fqn.endsWith(":UsedLegacyModule")), "current creation-code use prevents legacy-only exclusion");
  assert.ok(report.excludedAnchoredProducts.some(row => row.fqn.endsWith(":ICandidate") && row.exclusionReason === "interface"));
  assert.ok(report.excludedAnchoredProducts.some(row => row.fqn.endsWith(":CandidateLib") && row.exclusionReason === "library"));
  assert.ok(report.excludedAnchoredProducts.some(row => row.fqn.endsWith(":AbstractCandidate") && row.exclusionReason === "abstract-contract"));
});

test("source bridge, planning-candidate identity, and selector coverage fail closed", () => {
  const original = fixture();
  const brokenBridge = JSON.parse(original.bridgeRaw);
  brokenBridge.committedBlobSHA256["script/current/DeployCandidate.s.sol"] = "0".repeat(64);
  assert.throws(() => buildSurfaceInventory({ ...original, bridgeRaw: JSON.stringify(brokenBridge) }), /Source bytes differ/);
  const changedRole = JSON.parse(original.inputRaw), rolePath = "script/current/StreamFullV1Candidate.sol";
  changedRole.sources[rolePath].content = changedRole.sources[rolePath].content.replace("address(f.core)", "address(TEMP)")
    .replace("address(f.executor)", "address(f.core)").replace("address(TEMP)", "address(f.executor)");
  const roleBridge = JSON.parse(original.bridgeRaw);
  roleBridge.committedBlobSHA256[rolePath] = sha256(changedRole.sources[rolePath].content);
  assert.throws(() => buildSurfaceInventory({ ...original, inputRaw: JSON.stringify(changedRole), bridgeRaw: JSON.stringify(roleBridge) }), /role expression changed at capture position 1/);
  const badPlanning = JSON.parse(original.planningCandidateRaw);
  badPlanning.instances.push({ address: "0x0000000000000000000000000000000000000001" });
  assert.throws(() => buildSurfaceInventory({ ...original, planningCandidateRaw: JSON.stringify(badPlanning) }), /planning-only candidate without instances/);
  const badOutput = JSON.parse(original.outputRaw);
  delete badOutput.contracts["smart-contracts/supported/Supported0.sol"].Supported0.evm.methodIdentifiers["f0(uint256)"];
  assert.throws(() => buildSurfaceInventory({ ...original, outputRaw: JSON.stringify(badOutput) }), /Compiler selector missing/);
});

test("canonical serialization is stable across object key order", () => {
  assert.equal(canonical({ z: 1, a: { y: true, x: null } }), canonical({ a: { x: null, y: true }, z: 1 }));
});
