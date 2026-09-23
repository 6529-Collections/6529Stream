import test from "node:test";
import assert from "node:assert/strict";
import { buildSurfaceInventory, canonical, sha256 } from "../scripts/generate-safe-call-surface-abi213.mjs";

function fixture() {
  const sources = {}, committedBlobSHA256 = {}, contracts = {};
  const addSource = (path, content, artifact) => {
    sources[path] = { content };
    committedBlobSHA256[path] = sha256(content);
    if (artifact) contracts[path] = artifact;
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
  addSource("smart-contracts/legacy/OldCandidate.sol", "contract OldCandidate {}", { OldCandidate: { abi: [] } });
  addSource("smart-contracts/legacy/UsedLegacyModule.sol", "contract UsedLegacyModule {}", { UsedLegacyModule: { abi: [] } });
  addSource("smart-contracts/domains/mint/TupleCandidate.sol", "contract TupleCandidate {}", { TupleCandidate: {
    abi: [{ type: "function", name: "configure", stateMutability: "nonpayable", inputs: [{ name: "config", type: "tuple", internalType: "struct Config", components: [{ name: "value", type: "uint256" }] }], outputs: [] }],
    evm: { methodIdentifiers: { "configure(Config)": "ddeeccbb" } },
  } });
  addSource("script/current/DeployCandidate.s.sol", "contract DeployCandidate { function x() external { new Candidate(); type(Candidate).creationCode; type(TupleCandidate).creationCode; type(UsedLegacyModule).creationCode; } }");
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

test("ABI213 refresh preserves the exact 164 roster and inventories selectors and special entries", () => {
  const report = buildSurfaceInventory(fixture());
  assert.deepEqual(report.totals, { contracts: 164, functions: 6553, viewOrPure: 3276, stateChanging: 3277, payableFunctions: 0, receive: 0, fallback: 0 });
  assert.equal(report.surfaces.length, 164);
  assert.equal(report.capture.sourceCommit, "a0f92ecae8414d36aa715ae1e37d5fb222c0db97");
  assert.equal(report.surfaces[0].functions[0].selector, "0x00000000");
});

test("anchored gap list keeps concrete current products and qualifies deployment, catalog, reads, and tests", () => {
  const report = buildSurfaceInventory(fixture());
  assert.equal(report.genesisRoleCoverage.length, 37);
  assert.equal(report.genesisRoleCoverage[0].status, "contains-product-absent-from-164-roster");
  assert.equal(report.genesisRoleCoverage[1].status, "covered-by-retained-164-roster");
  assert.equal(report.genesisRoleCoverage[2].status, "manifest-equivalent-needs-root-mapping");
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
