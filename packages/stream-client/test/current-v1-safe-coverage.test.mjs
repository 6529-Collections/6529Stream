import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { createHash } from "node:crypto";
import { FunctionFragment, id } from "ethers";
import {
  buildCurrentV1SafeCoverage,
  serializeCurrentV1SafeCoverage,
  V1_SAFE_SOURCE,
  V1_SAFE_INPUT_SHA256,
  V1_SAFE_OUTPUT_SHA256
} from "../scripts/generate-current-v1-safe-coverage.mjs";

const read = path => JSON.parse(readFileSync(new URL(path, import.meta.url), "utf8"));
const inventory = read("../docs/current-v1-safe-coverage.json");
const bytes = readFileSync(new URL("../docs/current-v1-safe-coverage.json", import.meta.url), "utf8");
const sha = value => createHash("sha256").update(value).digest("hex");
const host = name => inventory.implementations[name];
const method = (name, prefix) => host(name).functions.find(fn => fn.signature.startsWith(`${prefix}(`));

test("ABI102 is a separate exact source inventory, not a deployment or readiness claim", async () => {
  assert.equal(inventory.sourceCommit, V1_SAFE_SOURCE);
  assert.equal(inventory.capture.inputSha256, V1_SAFE_INPUT_SHA256);
  assert.equal(inventory.capture.outputSha256, V1_SAFE_OUTPUT_SHA256);
  assert.equal(inventory.capture.literalSources, 2710);
  assert.equal(inventory.capture.compilerErrors, 0);
  assert.equal(inventory.scope.deploymentOrRuntimeProven, false);
  assert.equal(inventory.scope.completeWorkflowClaims, 0);
  assert.equal(inventory.mappingEvidence.planningInstances, 0);
  await assert.rejects(buildCurrentV1SafeCoverage(Buffer.from("{}"), Buffer.from("{}")), /exact retained ABI102/);
});

test("all 37 roles remain distinct from candidate implementations and factory clones", () => {
  assert.deepEqual(inventory.roles.map(role => role.id), Array.from({ length: 37 }, (_, n) => n + 1));
  assert.equal(new Set(inventory.roles.map(role => role.key)).size, 37);
  for (const role of inventory.roles) {
    for (const implementation of role.implementations) {
      assert.ok(host(implementation), `${role.key}/${implementation}`);
      assert.ok(host(implementation).roles.includes(role.id));
    }
  }
  assert.deepEqual(inventory.roles[1].implementations, ["StreamGovernanceExecutor", "StreamRoleRegistry"]);
  assert.deepEqual(inventory.roles[15].unavailableProfileNames, ["StreamDutchAuctionAdapter"]);
  assert.match(inventory.roles[15].note, /not an approved alias/);
  assert.ok(inventory.roles[19].implementations.includes("StreamERC20FixedPriceSaleAdapter"));
  assert.ok(inventory.roles[19].implementations.includes("StreamERC20PrimarySettlementAdapter"));
  assert.match(inventory.roles[5].note, /singleton implementation is locked/);
  assert.deepEqual(inventory.roles[29].implementations, inventory.roles[33].implementations);
  assert.deepEqual(inventory.roles[10].implementations, inventory.roles[34].implementations);
  assert.equal(host("StreamCoreFinalityAdapter").counts.writes, 0);
});

test("current graph companions have real rows without becoming extra genesis roles", () => {
  assert.equal(Object.keys(inventory.implementations).length, 90);
  assert.ok(inventory.composition.some(row => row.implementation === "StreamArtistAttributionLifecycle"));
  assert.ok(inventory.composition.some(row => row.implementation === "StreamCollectionTokenInventory"));
  assert.ok(inventory.composition.some(row => row.implementation === "StreamSplitWallet" && row.parent === "StreamSplitFactory"));
  for (const name of ["StreamArtistOnboardingReads", "StreamArtistRegistryReadExtension", "StreamArtistRegistryWriterExtension"]) {
    assert.ok(inventory.composition.some(row => row.implementation === name && row.relation.startsWith("library-mediated")), name);
  }
  for (const edge of inventory.composition) {
    assert.ok(host(edge.implementation));
    assert.ok(inventory.sourceEvidence[edge.evidence.path]);
    assert.ok(edge.evidence.line > 0);
    assert.equal(edge.admissionAndRoleAssignment, "review-required");
  }
});

test("full canonical overload signatures drive selector and mutable/read accounting", () => {
  let writes = 0, reads = 0;
  for (const [name, implementation] of Object.entries(inventory.implementations)) {
    assert.equal(new Set(implementation.functions.map(fn => fn.signature)).size, implementation.functions.length, name);
    let w = 0, r = 0;
    for (const fn of implementation.functions) {
      const parsed = FunctionFragment.from(`function ${fn.signature}`);
      assert.equal(parsed.format("sighash"), fn.signature);
      assert.equal(fn.selector, id(fn.signature).slice(0, 10));
      if (["view", "pure"].includes(fn.mutability)) {
        r++;
        assert.equal(fn.stages, "read-default");
      } else {
        w++;
        assert.equal(fn.stages, "write-default");
        if (fn.mutability !== "payable") assert.equal(fn.nativeValue, "0");
      }
    }
    assert.deepEqual(implementation.counts, { writes: w, reads: r });
    writes += w;
    reads += r;
  }
  assert.equal(writes, 1003);
  assert.equal(reads, 3136);
  assert.equal(host("StreamCore").functions.filter(fn => fn.signature.startsWith("safeTransferFrom(")).length, 2);
});

test("protocol-only callbacks and self-only views are not ordinary wallet gaps", () => {
  assert.equal(method("StreamCore", "mintFromManager").endpoint.category, "protocol-only");
  assert.equal(method("StreamSplitWallet", "initialize").endpoint.category, "protocol-only");
  assert.equal(method("StreamERC20PrimarySettlementAdapter", "fundERC20PrimarySale").endpoint.category, "protocol-only");
  assert.equal(method("StreamAssetPolicyRegistry", "setAssetStatus").endpoint.category, "governance");
  assert.equal(method("StreamSplitWallet", "release").endpoint.category, "public-conditional");
  const internalRead = method("StreamArtistAttributionLifecycle", "personhoodResolution");
  assert.equal(internalRead.mutability, "view");
  assert.equal(internalRead.endpoint.category, "self-only");
  assert.equal(inventory.stageDefinitions[internalRead.stages].callerAndValueAuthority, "review-required");
  assert.ok(internalRead.endpoint.evidence.length);
});

test("historical DIRECT29 remains exact, source-qualified, and separate from lexical hits", () => {
  const historical = read("../docs/current-direct-conservation-coverage.json");
  const names = { "native-fixed": "StreamFixedPriceSaleAdapter", "erc20-fixed": "StreamERC20FixedPriceSaleAdapter", "english-auction": "StreamEnglishAuctionHouse" };
  let found = 0;
  for (const call of historical.calls) {
    const row = host(names[call.productKind]).functions.find(fn => fn.signature === call.signature);
    assert.ok(row, call.signature);
    assert.equal(row.selector, call.selector);
    assert.equal(row.historicalProfile, "direct-original-products");
    assert.equal(row.historicalNativeValue, call.nativeValue);
    found++;
  }
  assert.equal(found, 29);
  const prior = inventory.historicalProfiles.find(profile => profile.key === "direct-original-products");
  assert.equal(prior.sourceCommit, "8bb6dfe2957542f641b0d558e1cfd48e1b39ae98");
  assert.ok(prior.sourceCompatibility.changedOrAbsent.length > 0);
  assert.equal(prior.stages, "reviewed-historical-workflow");
  assert.equal(inventory.stageDefinitions["write-default"].safeReceipt, "review-required");
});

test("source-qualified bounded support profiles require exact compiler signatures and retained tests", () => {
  for (const profile of inventory.clientSupportProfiles) {
    const fixtureBytes = readFileSync(new URL(`../${profile.fixturePath}`, import.meta.url));
    assert.equal(sha(fixtureBytes), profile.fixtureSha256);
    const fixture = JSON.parse(fixtureBytes);
    assert.equal(profile.sourceCommit, fixture.sourceCommit);
    const signatures = new Set(Object.values(fixture.abis).flat().filter(row => row.type === "function")
      .map(row => FunctionFragment.from(row).format("sighash")));
    for (const [name, rows] of Object.entries(profile.signatures)) {
      for (const signature of rows) {
        assert.ok(signatures.has(signature), `${profile.key}/${signature}`);
        const row = host(name).functions.find(fn => fn.signature === signature);
        assert.ok(row?.supportProfiles.includes(profile.key));
      }
    }
    assert.ok(profile.restriction.length > 20);
    assert.ok(profile.testReferences.length);
    for (const path of profile.testReferences) assert.ok(inventory.clientEvidence[path]);
  }
  const multiple = method("StreamArtistOnboardingRegistry", "hydrateMultipleArtistAuthority");
  assert.deepEqual(multiple.supportProfiles, ["artist-hydration-baseline-three", "artist-hydration-multiple-delegation"]);
  assert.equal(method("StreamArtistOnboardingRegistry", "hydrateRecoveredArtistAuthority").supportProfiles, undefined);
  const personhood = inventory.clientSupportProfiles.find(profile => profile.key === "artist-canonical-personhood-principal");
  assert.equal(personhood.sourceCommit, inventory.sourceCommit);
  assert.equal(personhood.stages, "reviewed-current-client-workflow");
  assert.deepEqual(personhood.sourceCompatibility.changedOrAbsent, []);
  assert.equal(personhood.validation.focusedClientTests.total, 48);
  assert.equal(personhood.validation.independentCombinedCohort.total, 58);
  assert.equal(personhood.validation.actualContractRuntimeAcceptance, false);
  assert.equal(personhood.validation.actualSafeRuntimeAcceptance, false);
  assert.equal(personhood.validation.wholeGraphAcceptance, false);
  assert.ok(personhood.testReferences.includes("test/current-artist-personhood-reads.test.mjs"));
  for (const path of personhood.additionalEvidence) assert.ok(inventory.clientEvidence[path]);
  assert.match(personhood.restriction, /Other principal subjects/);
  assert.equal(method("StreamArtistAttributionLifecycle", "personhoodResolution").supportProfiles, undefined);
});

test("lexical candidates cannot silently acquire support stages", () => {
  let candidates = 0;
  for (const implementation of Object.values(inventory.implementations)) {
    for (const fn of implementation.functions) {
      if (!fn.lexicalClientCandidates) continue;
      candidates++;
      for (const index of fn.lexicalClientCandidates) {
        assert.ok(Number.isInteger(index) && index >= 0);
        assert.ok(inventory.clientEvidence[inventory.clientCandidatePaths[index]]);
      }
      assert.ok(["read-default", "write-default"].includes(fn.stages));
    }
  }
  assert.ok(candidates > 0);
  assert.match(inventory.stageDefinitions.rule, /Lexical candidates never change a stage/);
  assert.match(inventory.genericSafe.doesNotProve, /governance current-action context/);
});

test("Artist IDs1–60, existing61 and newer method variants remain distinct", () => {
  const artist = inventory.artistOriginalOperations;
  assert.deepEqual(artist.operationReferences.map(row => row.id), Array.from({ length: 61 }, (_, n) => n + 1));
  assert.equal(artist.separatelyRetainedId, 61);
  assert.ok(artist.staleCoverageWarnings.some(warning => warning.includes("Operation 35")));
  assert.ok(artist.additionalCurrentFacadeMutations.some(row => row.signature.startsWith("recoverArtistIdentityV3(")));
  for (const path of artist.sourceRouteReferences) assert.ok(inventory.sourceEvidence[path]);
  assert.match(artist.requiredAudit, /operation IDs are not method counts/);
});

test("compact inventory serialization is deterministic and lossless", () => {
  assert.equal(serializeCurrentV1SafeCoverage(inventory), bytes);
  assert.deepEqual(JSON.parse(serializeCurrentV1SafeCoverage(inventory)), inventory);
  assert.ok(bytes.length < 2_200_000);
});
