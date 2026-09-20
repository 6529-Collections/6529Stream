// ABI102 inventory only. This script neither compiles Solidity nor promotes lexical
// client matches to implemented, simulated, or receipt-verified support.
import { createHash } from "node:crypto";
import { execFileSync } from "node:child_process";
import { readFile, readdir, writeFile } from "node:fs/promises";
import { posix, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { FunctionFragment, id } from "ethers";
import { solidityImports } from "./generate-current-entropy-policy-succession-fixture.mjs";

export const V1_SAFE_SOURCE = "70c0d9c37f6435c480b87083af8d1cbd4fa7098d";
export const V1_SAFE_INPUT_SHA256 = "cceb85599b712a445de6ecc8235bd7c7673b287926265982cd0bfe5321577dbe";
export const V1_SAFE_OUTPUT_SHA256 = "101c9b9c30be178034d15548f34aaf2eb87f61f1da8756d3617b8113b4121054";
const packageRoot = resolve(fileURLToPath(new URL("..", import.meta.url)));
const repoRoot = resolve(packageRoot, "../..");
const destination = resolve(packageRoot, "docs/current-v1-safe-coverage.json");
const sha = value => createHash("sha256").update(value).digest("hex");
const compareText = (a, b) => a < b ? -1 : a > b ? 1 : 0;
const stages = [
  "encoding", "typedRequestOrSigning", "callerAndValueAuthority", "pinnedSimulation",
  "directReceipt", "safeCallComposition", "safeReceipt", "typedRead"
];
const graphPaths = [
  "release-artifacts/genesis-deployment-profile.json",
  "docs/launch-conformance-matrix.md",
  "deployments/config/canonical-deployment-candidate-v2-planning.json",
  "release-artifacts/current-contracts.json",
  "tools/deployment/prepare_current_stack_compilation.py",
  "tools/deployment/generate_current_stack_artifacts.py",
  "script/current/StreamCurrentGraphCreation.sol",
  "script/current/StreamCurrentFinalityGraph.sol",
  "script/current/StreamFullV1GenesisProducts.sol",
  "script/current/StreamNativeCommerceDeployment.sol",
  "docs/integrations/native-commerce-deployment.md",
  "release-artifacts/issue-670-adapter-freeze/artist-operation-matrix-v1.json",
  "docs/architecture/artist-operation-extension-v1.json",
  "docs/architecture/artist-operation59-steward-grants.json",
  "docs/architecture/artist-operation60-authority-hydration.json",
  "docs/architecture/artist-operation61-dispute-withdrawal.json"
];

function frozen(path) {
  return execFileSync("git", ["show", `${V1_SAFE_SOURCE}:${path}`], {
    cwd: repoRoot,
    maxBuffer: 40 * 1024 * 1024
  });
}

// A declaration is evidence of the source entry point, not proof of all its
// delegated guards. Balanced scanning avoids braces in comments and strings.
function balancedEnd(text, start, open, close) {
  let depth = 0;
  let quote = null;
  let comment = null;
  for (let at = start; at < text.length; at++) {
    const c = text[at], next = text[at + 1];
    if (comment === "line") {
      if (c === "\n") comment = null;
      continue;
    }
    if (comment === "block") {
      if (c === "*" && next === "/") { comment = null; at++; }
      continue;
    }
    if (quote) {
      if (c === "\\") { at++; continue; }
      if (c === quote) quote = null;
      continue;
    }
    if (c === "/" && next === "/") { comment = "line"; at++; continue; }
    if (c === "/" && next === "*") { comment = "block"; at++; continue; }
    if (c === '"' || c === "'") { quote = c; continue; }
    if (c === open) depth++;
    if (c === close && --depth === 0) return at;
    // A different closing character must not decrement the requested delimiter.
    if (c !== close) continue;
  }
  throw Error("Unbalanced retained Solidity source");
}

function declarations(text, path, name) {
  const result = [];
  const pattern = new RegExp(`\\bfunction\\s+${name}\\s*\\(`, "g");
  for (const match of text.matchAll(pattern)) {
    const args = text.indexOf("(", match.index);
    const argsEnd = balancedEnd(text, args, "(", ")");
    const bodyStart = text.indexOf("{", argsEnd);
    const semicolon = text.indexOf(";", argsEnd);
    if (bodyStart < 0 || (semicolon >= 0 && semicolon < bodyStart)) continue;
    const end = balancedEnd(text, bodyStart, "{", "}");
    result.push({
      path,
      line: text.slice(0, match.index).split("\n").length,
      header: text.slice(match.index, bodyStart).replace(/\s+/g, " ").trim(),
      body: text.slice(bodyStart, end + 1)
    });
  }
  return result;
}

function endpoints(name, fn, decls, implementationPath) {
  const evidence = decls.map(({ path, line }) => path === implementationPath ? { line } : { path, line });
  const body = decls.length === 1 ? decls[0].body : "";
  if (/msg\.sender\s*!=\s*address\(this\)/.test(body)) {
    return { category: "self-only", allowedCaller: "the same contract; ABI visibility does not establish general caller access", evidence };
  }
  if (["view", "pure"].includes(fn.stateMutability)) {
    return { category: fn.stateMutability, ...(evidence.length ? { evidence } : {}) };
  }
  if (decls.length === 1 && /\bonlyOwner\b/.test(decls[0].header)) {
    return { category: "owner", allowedCaller: "current owner; additional body guards remain applicable", evidence };
  }
  if (name === "StreamArtistOnboardingCoordinator" && decls.length === 1 && /\boperation\b/.test(decls[0].header)) {
    return { category: "protocol-only", allowedCaller: "fixed Registry through operation/_beginOperation; fixed suite and current-action checks remain applicable", enclosingWorkflow: "original Artist facade operation", evidence };
  }
  if (name === "StreamCore" && /_requireMintManager\(\)/.test(body)) {
    return { category: "protocol-only", allowedCaller: "selected Mint Manager", enclosingWorkflow: "original Manager mint execution", evidence };
  }
  if (name === "StreamSplitWallet" && fn.name === "initialize") {
    return { category: "protocol-only", allowedCaller: "initializing factory, with predicted clone and initialization guards", enclosingWorkflow: "factory wallet deployment", evidence };
  }
  if (name === "StreamERC20PrimarySettlementAdapter" && fn.name === "fundERC20PrimarySale") {
    return { category: "protocol-only", allowedCaller: "primarySaleSettlement during the exact SALE_CALLBACK", enclosingWorkflow: "original ERC20 settlement funding callback", evidence };
  }
  if (name === "StreamAssetPolicyRegistry" && /msg\.sender\s*!=\s*governanceAuthority/.test(body)) {
    return { category: "governance", allowedCaller: "governanceAuthority with original current-action validation", evidence };
  }
  if (name === "StreamSplitWallet" && fn.name === "release") {
    return { category: "public-conditional", allowedCaller: "any caller to the account itself; only account may select a different recipient", evidence };
  }
  if (name === "StreamSplitWallet" && fn.name === "syncAsset") {
    return { category: "public", allowedCaller: "any caller; asset and accounting checks remain applicable", evidence };
  }
  if (name === "StreamClaimRouter" && ["claimMany", "syncAndClaimMany"].includes(fn.name)) {
    return { category: "public-conditional", allowedCaller: "any caller; nested wallet release recipient rules remain applicable", evidence };
  }
  return { category: "review-required", ...(evidence.length ? { evidence } : {}) };
}

const roleAlternatives = {
  2: ["StreamGovernanceExecutor", "StreamRoleRegistry"],
  16: ["StreamNativeDutchSale"],
  20: [
    "StreamERC20FixedPriceSaleAdapter", "StreamERC20PrimarySettlementAdapter",
    "StreamERC20PrimaryOfferSale", "StreamERC20BurnMintSale"
  ],
  21: ["StreamArtistOnboardingRegistry"],
  24: ["StreamCollectionMetadataV1"]
};

const profileFiles = [
  ["direct-original-products", "docs/current-direct-conservation-coverage.json", "test/fixtures/current-direct-conservation-abi.json"],
  ["artist-original-operations", "docs/current-artist-operation-coverage.json", "test/fixtures/current-artist-operation-current-abi.json"]
];

// These are deliberately finite, manually reviewed semantic profiles. The method
// list is not inferred from string hits. Fixtures retain their original sources.
const supportedProfiles = [
  {
    key: "split-factory-v4", base: "current-split-factory",
    methods: { StreamSplitFactory: ["registerProfile", "createProfile", "deployWallet"] },
    helpers: ["prepareSplitFactoryOperation", "captureSplitFactory", "simulateSplitFactoryOperation", "inspectSplitFactoryOperationReceipt"],
    restriction: "Version-4 factory profile registration/deployment; excludes singleton user releases and factory administration."
  },
  {
    key: "mint-policy-grace", base: "current-mint-policy-grace",
    methods: { StreamMintManager: ["setPhaseExecutorWithGrace"] },
    helpers: ["captureMintPolicyGrace", "inspectMintPolicyGraceChange", "prepareMintPolicyGraceGovernance", "simulateMintPolicyGraceOperation", "inspectMintPolicyGraceOperationReceipt"],
    restriction: "One exact governed executor-grace change; mode2 needs its separately pinned additive profile. No generic phase setter."
  },
  {
    key: "mint-phase-freeze", base: "current-mint-phase-freeze",
    methods: { StreamMintManager: ["freezePhase"], StreamMintLedger: ["importPhaseFreezes"] },
    helpers: ["captureMintPhaseFreeze", "prepareMintPhaseFreezeGovernance", "simulateMintPhaseFreezeOperation", "inspectMintPhaseFreezeReceipt", "captureMintPhaseFreezeImport", "inspectMintPhaseFreezeImportReceipt"],
    restriction: "Class2 Manager freeze and bounded original same-Ledger import; Ledger freeze callback is not a wallet writer."
  },
  {
    key: "entropy-explicit-disabled-async", base: "current-entropy-collection-policy",
    methods: { StreamEntropyCoordinator: ["configureCollectionEntropyPolicy", "freezeCollectionEntropyPolicy"] },
    helpers: ["captureEntropyCollectionPolicy", "inspectEntropyCollectionPolicy", "prepareEntropyCollectionPolicyGovernance", "simulateEntropyCollectionPolicyOperation", "inspectEntropyCollectionPolicyReceipt"],
    restriction: "Original d7 DISABLED/ASYNC policies and exact Artist17 prerequisites; INSTANT excluded."
  },
  {
    key: "entropy-instant", base: "current-entropy-instant",
    methods: { StreamEntropyCoordinator: ["configureCollectionEntropyPolicy", "freezeCollectionEntropyPolicy", "requestEntropy"] },
    helpers: ["captureEntropyInstantPolicy", "prepareEntropyInstantPolicyGovernance", "simulateEntropyInstantPolicyOperation", "inspectEntropyInstantPolicyReceipt", "captureEntropyInstantRequest", "simulateEntropyInstantRequest", "inspectEntropyInstantRequestReceipt"],
    restriction: "Delayed mode1 LOW_SECURITY INSTANT profile; no ASYNC replacement, source-block prediction or finality claim."
  },
  {
    key: "entropy-policy-succession", base: "current-entropy-policy-succession",
    methods: { StreamEntropyCoordinator: ["beginEntropyPolicyImport", "importNextEntropyPolicy", "confirmEntropyRelayRoute", "sealEntropyPolicyImport", "admitEntropyRelay", "activateEntropyPolicyImport"] },
    helpers: ["captureEntropyPolicySuccession", "prepareEntropyPolicySuccession", "prepareEntropyPolicySuccessionGovernance", "simulateEntropyPolicySuccession", "reconcileEntropyPolicySuccessionReceipt"],
    restriction: "Canonical succession only, including exact cutover tail; relay requests, delivery and retries excluded."
  },
  {
    key: "artist-delegated-attestations", base: "current-artist-attestation",
    clientBase: "current-artist-operation", workflowBase: "current-artist-workflow",
    methods: { StreamArtistOnboardingRegistry: ["recordDelegatedArtistAttestation", "recordDelegatedArtistScopedAttestation"] },
    helpers: ["captureCurrentArtistOperation", "simulateCurrentArtistCall", "inspectCurrentArtistReceipt"],
    restriction: "Original delegated op24 profiles; not principal personhood, C2PA, or every subject extension."
  },
  {
    key: "artist-hydration-baseline-three", base: "current-artist-authority-hydration",
    methods: { StreamArtistOnboardingRegistry: ["hydrateArtistAuthority", "hydrateMultipleArtistAuthority", "hydrateArtistAuthorityWithDelegations"] },
    helpers: ["captureArtistAuthorityHydration", "simulateArtistAuthorityHydration", "inspectArtistAuthorityHydrationReceipt"],
    restriction: "Closed baseline single, multiple and single-delegation profiles; advanced and recovered hydration excluded."
  },
  {
    key: "artist-hydration-multiple-delegation", base: "current-artist-multiple-delegation",
    clientBase: "current-artist-authority-hydration", workflowBase: "current-artist-authority-hydration-workflow",
    methods: { StreamArtistOnboardingRegistry: ["hydrateMultipleArtistAuthority"] },
    helpers: ["captureArtistAuthorityHydration", "simulateArtistAuthorityHydration", "inspectArtistAuthorityHydrationReceipt"],
    restriction: "Combined multiple-delegation is a distinct semantic profile on the original multiple selector; no on-chain profile flag."
  },
  {
    key: "artist-canonical-personhood-principal", base: "current-artist-personhood",
    currentSourceClient: true,
    additionalTests: ["test/current-artist-personhood-reads.test.mjs"],
    additionalEvidence: ["test/current-artist-personhood-types.ts", "test/current-artist-personhood-workflow-types.ts"],
    validation: {
      independentSourceAndTypesReview: "clear",
      focusedClientTests: { pure: 12, oracle: 8, reads: 10, workflow: 18, total: 48 },
      independentCombinedCohort: { clientTests: 48, inventoryTests: 10, total: 58, result: "pass" },
      actualContractRuntimeAcceptance: false,
      actualSafeRuntimeAcceptance: false,
      wholeGraphAcceptance: false
    },
    methods: {
      StreamArtistOnboardingRegistry: ["recordArtistAttestation"],
      StreamArtistAttributionLifecycle: ["auditPersonhoodEvidence", "personhoodEvidence", "personhoodEvidenceStatus", "personhoodProofSummary", "personhoodProofSummaryHash"]
    },
    helpers: ["captureArtistPersonhood", "simulateArtistPersonhood", "inspectArtistPersonhood", "reconcileArtistPersonhoodReceipt"],
    restriction: "Canonical personhood principal op24 only; same original signature/domain. Five public reads target Attribution and retain original UNRESOLVED opaque-history results. Other principal subjects, authoring legacy opaque bytes and self-only personhoodResolution remain outside this profile."
  }
];

const additionalClientFamilies = [
  ["current-erc20-primary-offer", "current-erc20-primary-offer"],
  ["current-erc20-burn-mint", "current-erc20-burn-mint"],
  ["current-collection-inventory", "current-collection-inventory-workflow"],
  ["current-reference-inventory", "current-reference-inventory-workflow"],
  ["current-reference-environment", "current-reference-environment-workflow"],
  ["current-reference-mode-payload", "current-reference-mode-payload-workflow"],
  ["current-reference-metric", "current-reference-metric-workflow"],
  ["current-mint-fallback", "current-mint-fallback-workflow"],
  ["current-metadata-citation", "current-metadata-citation-workflow"],
  ["current-museum-anchor-master", "current-museum-anchor-master-workflow"],
  ["current-artist-recovery-adjudication", "current-artist-recovery-adjudication-workflow"],
  ["current-artist-recovery-rewind", "current-artist-recovery-rewind-workflow"],
  ["current-artist-operation", "current-artist-workflow"],
  ["current-artist-ceremony", "current-artist-ceremony"],
  ["current-revenue", "current-revenue"]
];

export async function buildCurrentV1SafeCoverage(inputBytes, outputBytes) {
  if (sha(inputBytes) !== V1_SAFE_INPUT_SHA256 || sha(outputBytes) !== V1_SAFE_OUTPUT_SHA256) {
    throw Error("Expected the exact retained ABI102 input and output");
  }
  const input = JSON.parse(inputBytes), output = JSON.parse(outputBytes);
  if (Object.keys(input.sources ?? {}).length !== 2710 || output.errors?.some(e => e.severity === "error")) {
    throw Error("Invalid ABI102 source count or compiler error");
  }
  const sourceEvidence = {};
  const graphTexts = {};
  for (const path of graphPaths) {
    const bytes = frozen(path);
    graphTexts[path] = bytes.toString("utf8");
    sourceEvidence[path] = sha(bytes);
  }
  const profile = JSON.parse(graphTexts[graphPaths[0]]);
  if (profile.entries.length !== 37 || new Set(profile.entries.map(e => e.key)).size !== 37) {
    throw Error("Expected canonical 37-role genesis profile");
  }
  const contractIndex = new Map();
  for (const [path, contracts] of Object.entries(output.contracts)) {
    if (!path.startsWith("smart-contracts/")) continue;
    for (const [name, contract] of Object.entries(contracts)) {
      if (contractIndex.has(name)) throw Error(`Ambiguous production contract name: ${name}`);
      contractIndex.set(name, { path, abi: contract.abi });
    }
  }
  const clientFiles = [];
  const clientEvidence = {};
  for (const name of (await readdir(resolve(packageRoot, "src"))).sort()) {
    if (!name.endsWith(".ts")) continue;
    const path = `src/${name}`;
    const bytes = await readFile(resolve(packageRoot, path));
    clientEvidence[path] = sha(bytes);
    clientFiles.push({ path, text: bytes.toString("utf8") });
  }
  const oldProfiles = [];
  for (const [key, path, fixturePath] of profileFiles) {
    const bytes = await readFile(resolve(packageRoot, path));
    const prior = JSON.parse(bytes);
    const fixture = JSON.parse(await readFile(resolve(packageRoot, fixturePath)));
    clientEvidence[path] = sha(bytes);
    const witnesses = Object.entries(fixture.sourceHashes ?? prior.sourceWitnesses ?? {});
    const changed = witnesses.filter(([path, hash]) => sha(input.sources[path]?.content ?? "") !== hash);
    oldProfiles.push({
      key, path, fixturePath, sourceCommit: prior.sourceCommit,
      ...(key === "direct-original-products" ? {
        stages: "reviewed-historical-workflow",
        restriction: "Exactly the 29 named original native, ERC20 fixed-price and English calls in this prior coverage file, including owner controls; no newer product or runtime acceptance.",
        helpers: prior.sharedClient,
        safeHelpers: prior.sharedSafe
      } : {}),
      evidenceScope: "historical source, ABI and client tests; no current deployment or actual Safe execution assertion",
      sourceCompatibility: {
        compared: witnesses.length,
        unchanged: witnesses.length - changed.length,
        changedOrAbsent: changed.map(([path]) => path),
        conclusion: "source comparison only; runtime pins, profiles and receipt semantics require separate review"
      }
    });
  }
  const direct = JSON.parse(await readFile(resolve(packageRoot, profileFiles[0][1])));
  const directProducts = {
    StreamFixedPriceSaleAdapter: "native-fixed",
    StreamERC20FixedPriceSaleAdapter: "erc20-fixed",
    StreamEnglishAuctionHouse: "english-auction"
  };
  const clientSupportProfiles = [];
  for (const definition of supportedProfiles) {
    const fixturePath = `test/fixtures/${definition.base}-abi.json`;
    const fixture = JSON.parse(await readFile(resolve(packageRoot, fixturePath)));
    const sourcePath = `src/${definition.clientBase ?? definition.base}.ts`;
    const workflowPath = `src/${definition.workflowBase ?? `${definition.base}-workflow`}.ts`;
    const workflow = clientFiles.find(file => file.path === workflowPath)?.text;
    if (!workflow || !clientFiles.some(file => file.path === sourcePath)) throw Error(`Missing reviewed profile ${definition.key}`);
    for (const helper of definition.helpers) {
      if (!new RegExp(`export\\s+(?:async\\s+)?function\\s+${helper}\\b`).test(workflow)) {
        throw Error(`Reviewed helper disappeared: ${helper}`);
      }
    }
    if (!workflow.includes('"safe"') || !workflow.includes('"direct"')) throw Error(`Missing direct/Safe receipt lanes: ${definition.key}`);
    const witnesses = Object.entries(fixture.sourceHashes ?? {});
    const changed = witnesses.filter(([path, hash]) => sha(input.sources[path]?.content ?? "") !== hash);
    if (definition.currentSourceClient && (fixture.sourceCommit !== V1_SAFE_SOURCE || changed.length)) {
      throw Error(`Current-source client profile no longer matches ABI102: ${definition.key}`);
    }
    const signatures = {};
    for (const [host, methods] of Object.entries(definition.methods)) {
      const segments = Object.entries(fixture.selections ?? {}).filter(([, selection]) => selection.contract === host).map(([segment]) => segment);
      const rows = segments.flatMap(segment => fixture.abis[segment] ?? []);
      // A few early fixtures use contractNames rather than selections. Preserve
      // the exact compiler signatures, never promote a name-only overload match.
      const available = rows.length ? rows : Object.values(fixture.abis).flat();
      signatures[host] = [...new Set(available.filter(row => row.type === "function" && methods.includes(row.name))
        .map(row => FunctionFragment.from(row).format("sighash")))].sort();
      if (methods.some(name => !signatures[host].some(signature => signature.startsWith(`${name}(`)))) {
        throw Error(`Missing historical compiler witness for ${definition.key}/${host}`);
      }
    }
    const testReferences = [];
    const tests = [
      `test/${definition.clientBase ?? definition.base}.test.mjs`,
      `test/${definition.workflowBase ?? `${definition.base}-workflow`}.test.mjs`,
      `test/${definition.base}-oracle.test.mjs`,
      ...(definition.additionalTests ?? [])
    ];
    for (const path of tests) {
      try {
        const bytes = await readFile(resolve(packageRoot, path));
        testReferences.push(path);
        clientEvidence[path] = sha(bytes);
      } catch (error) {
        if (error.code !== "ENOENT") throw error;
      }
    }
    if (!testReferences.length) throw Error(`No retained tests for ${definition.key}`);
    for (const path of definition.additionalEvidence ?? []) {
      clientEvidence[path] = sha(await readFile(resolve(packageRoot, path)));
    }
    clientSupportProfiles.push({
      key: definition.key, sourceCommit: fixture.sourceCommit,
      fixturePath, fixtureSha256: sha(await readFile(resolve(packageRoot, fixturePath))),
      sourcePath, workflowPath, helpers: definition.helpers, restriction: definition.restriction,
      stages: definition.currentSourceClient ? "reviewed-current-client-workflow" : "reviewed-historical-workflow",
      currentQualification: definition.currentSourceClient
        ? "This bounded client profile matches the exact source and ABI102 fixture and has focused client tests plus independent source review. Mocked direct/Safe receipts do not establish actual contract, actual Safe or whole-graph runtime acceptance."
        : "Source-reviewed bounded client implementation; no ABI102 or deployed-runtime acceptance inferred.",
      sourceCompatibility: { compared: witnesses.length, unchanged: witnesses.length - changed.length, changedOrAbsent: changed.map(([path]) => path) },
      methods: definition.methods, signatures, testReferences,
      ...(definition.validation ? { validation: definition.validation, additionalEvidence: definition.additionalEvidence } : {})
    });
  }
  const selected = new Set();
  const roles = profile.entries.map(entry => {
    const names = [...new Set([...entry.implementation.names, ...(roleAlternatives[entry.id] ?? [])])];
    const implementations = names.filter(name => contractIndex.has(name));
    implementations.forEach(name => selected.add(name));
    const unavailable = entry.implementation.names.filter(name => !contractIndex.has(name));
    const graphEvidence = implementations.flatMap(name => graphPaths.slice(6).flatMap(path => {
      const line = graphTexts[path].split("\n").findIndex(text => text.includes(name));
      return line < 0 ? [] : [{ implementation: name, path, line: line + 1 }];
    }));
    return {
      id: entry.id, key: entry.key, deploymentScope: entry.deployment_scope,
      profileImplementation: entry.implementation,
      implementations, unavailableProfileNames: unavailable,
      mapping: roleAlternatives[entry.id]
        ? "current-source-candidates; profile equivalence and deployed instances require review"
        : unavailable.length ? "available profile alternatives only; missing alternative is explicit"
          : "profile-name available in compiler capture; deployment not asserted",
      graphEvidence,
      note: entry.id === 6
        ? "The singleton implementation is locked. Wallet user actions target distinct initialized factory clones."
        : [34, 35].includes(entry.id)
          ? "Distinct fallback instance; shared ABI does not prove admission, activation or identical runtime."
          : entry.id === 2
            ? "Manifest-equivalent composition, not one ABI or proof that these two candidates satisfy every marker."
            : entry.id === 20
              ? "Constrained family candidates: original fixed-price product, payment transport, offer and burn carriers are distinct contracts."
              : entry.id === 16
                ? "StreamNativeDutchSale is a source candidate, not an approved alias for missing StreamDutchAuctionAdapter."
                : entry.id === 21
                  ? "Current Artist facade and routed companions must be reviewed together; legacy profile name is not silently substituted."
                  : entry.id === 24
                    ? "V1 metadata source candidate is not an automatic equivalence claim for the older profile literal."
                    : null
    };
  });
  const composition = [];
  const creationPath = "script/current/StreamCurrentGraphCreation.sol";
  const creationText = graphTexts[creationPath];
  const enumMatch = /enum Kind\s*\{([^}]+)\}/.exec(creationText);
  if (!enumMatch) throw Error("Missing current graph Kind inventory");
  for (const name of enumMatch[1].match(/\bStream\w+/g) ?? []) {
    if (!contractIndex.has(name)) throw Error(`Missing compiled current graph component ${name}`);
    selected.add(name);
    composition.push({
      implementation: name,
      relation: "current graph creation enum; deployable component, not an additional genesis role",
      evidence: { path: creationPath, line: creationText.slice(0, enumMatch.index + enumMatch[0].indexOf(name)).split("\n").length },
      admissionAndRoleAssignment: "review-required"
    });
  }
  // Follow dependency source to find library-mediated constructors as well as
  // direct host constructors. Imported libraries never become wallet endpoints.
  const scannedConstructionSources = new Set();
  function constructionSources(path, result = new Set()) {
    if (result.has(path)) return result;
    const text = input.sources[path]?.content;
    if (typeof text !== "string") throw Error(`Missing construction dependency ${path}`);
    result.add(path);
    for (const dependency of solidityImports(text)) {
      constructionSources(dependency.startsWith(".")
        ? posix.normalize(posix.join(posix.dirname(path), dependency)) : dependency, result);
    }
    return result;
  }
  for (const parent of selected) {
    const parentPath = contractIndex.get(parent).path;
    for (const path of constructionSources(parentPath)) {
      if (scannedConstructionSources.has(path)) continue;
      scannedConstructionSources.add(path);
      const text = input.sources[path].content;
      const pattern = /\bnew\s+(Stream\w+)\s*\(|\btype\((Stream\w+)\)\.creationCode/g;
      for (const match of text.matchAll(pattern)) {
        const name = match[1] ?? match[2];
        const child = contractIndex.get(name);
        if (!child || !new RegExp(`\\bcontract\\s+${name}\\b`).test(input.sources[child.path]?.content ?? "")) continue;
        selected.add(name);
        sourceEvidence[path] = sha(text);
        composition.push({
          implementation: name, parent,
          relation: path === parentPath
            ? "concrete host construction expression; runtime instance and route admission unverified"
            : "library-mediated construction in host dependency closure; runtime instance and route admission unverified",
          evidence: { path, line: text.slice(0, match.index).split("\n").length },
          admissionAndRoleAssignment: "review-required"
        });
      }
    }
  }
  const implementations = {};
  for (const name of [...selected].sort()) {
    const { path, abi } = contractIndex.get(name);
    const source = input.sources[path]?.content;
    if (typeof source !== "string" || !frozen(path).equals(Buffer.from(source))) {
      throw Error(`Selected implementation does not match frozen Git: ${path}`);
    }
    sourceEvidence[path] = sha(source);
    const functions = abi.filter(row => row.type === "function").map(row => {
      const fn = FunctionFragment.from(row);
      const signature = fn.format("sighash");
      const isRead = ["view", "pure"].includes(fn.stateMutability);
      let decls = declarations(source, path, fn.name);
      if (!decls.length && ["transferOwnership", "renounceOwnership", "owner"].includes(fn.name)) {
        const ownable = "smart-contracts/vendor/openzeppelin/Ownable.sol";
        const text = input.sources[ownable]?.content;
        if (text) {
          decls = declarations(text, ownable, fn.name);
          sourceEvidence[ownable] = sha(text);
        }
      }
      const quoted = new RegExp(`["'\x60]${fn.name}(?:["'\x60]|\\()`);
      const candidates = clientFiles.flatMap((file, index) => quoted.test(file.text) ? [index] : []);
      const historical = direct.calls.find(call => call.productKind === directProducts[name] && call.signature === signature);
      const supportProfiles = clientSupportProfiles.filter(profile => profile.signatures[name]?.includes(signature)).map(profile => profile.key);
      return {
        signature, selector: id(signature).slice(0, 10), mutability: fn.stateMutability,
        endpoint: endpoints(name, fn, decls, path),
        nativeValue: isRead ? "eth_call; no transfer" : fn.stateMutability === "payable"
          ? "method-specific payable amount; ABI alone does not establish the correct value" : "0",
        stages: isRead ? "read-default" : "write-default",
        ...(candidates.length ? { lexicalClientCandidates: candidates } : {}),
        ...(supportProfiles.length ? { supportProfiles } : {}),
        ...(historical ? {
          historicalProfile: "direct-original-products",
          historicalRequest: { productKind: historical.productKind, kind: historical.requestKind },
          historicalAuthority: historical.authority,
          historicalNativeValue: historical.nativeValue
        } : {})
      };
    }).sort((a, b) => compareText(a.signature, b.signature));
    implementations[name] = {
      path, abiSha256: sha(JSON.stringify(abi)),
      roles: roles.filter(role => role.implementations.includes(name)).map(role => role.id),
      counts: {
        writes: functions.filter(fn => !["view", "pure"].includes(fn.mutability)).length,
        reads: functions.filter(fn => ["view", "pure"].includes(fn.mutability)).length
      },
      functions,
      otherEntrypoints: abi.filter(row => ["receive", "fallback"].includes(row.type)).map(row => ({
        kind: row.type, mutability: row.stateMutability,
        endpoint: "review-required; fallback routing and receive semantics are outside named ABI functions"
      })),
      fallbackRouting: abi.some(row => row.type === "fallback")
        ? "review-required; concrete companion rows do not by themselves prove the host selector routing table"
        : null
    };
  }
  const artistCoverage = JSON.parse(await readFile(resolve(packageRoot, profileFiles[1][1])));
  const artistRows = artistCoverage.operations ?? artistCoverage.rows ?? [];
  const artistFunctions = implementations.StreamArtistOnboardingRegistry.functions;
  const operationReferences = artistRows.map(row => ({
    id: row.id,
    operation: row.operation,
    historicalCoverage: row.coverage,
    methods: row.methods.map(name => ({
      name,
      currentFacadeFunctions: artistFunctions.filter(fn => fn.signature.startsWith(`${name}(`))
        .map(fn => ({ signature: fn.signature, selector: fn.selector })),
      status: "historical method list; current variant and semantic profile coverage require review"
    }))
  }));
  const existingClientsAwaitingStageAttribution = [];
  for (const [base, workflow] of additionalClientFamilies) {
    const path = `src/${workflow}.ts`;
    const text = clientFiles.find(file => file.path === path)?.text;
    if (!text) throw Error(`Missing previously implemented client ${path}`);
    const fixturePath = `test/fixtures/${base}-abi.json`;
    let sourceCommit = null;
    let fixtureSha256 = null;
    try {
      const bytes = await readFile(resolve(packageRoot, fixturePath));
      sourceCommit = JSON.parse(bytes).sourceCommit ?? null;
      fixtureSha256 = sha(bytes);
    } catch (error) {
      if (error.code !== "ENOENT") throw error;
    }
    const retainedReferences = [];
    for (const reference of [...new Set([`docs/${base}.md`, `test/${base}.test.mjs`, `test/${workflow}.test.mjs`, `test/${base}-oracle.test.mjs`])]) {
      try {
        const bytes = await readFile(resolve(packageRoot, reference));
        retainedReferences.push(reference);
        clientEvidence[reference] = sha(bytes);
      } catch (error) {
        if (error.code !== "ENOENT") throw error;
      }
    }
    existingClientsAwaitingStageAttribution.push({
      family: base, path, fixturePath: fixtureSha256 ? fixturePath : null, fixtureSha256, sourceCommit, retainedReferences,
      status: "existing implementation; per-method/profile stage attribution pending, not an absent-client claim",
      exportedEntryPoints: [...text.matchAll(/export\s+(?:async\s+)?(?:function|class)\s+(\w+)/g)].map(match => match[1]),
      qualification: "Symbol inventory only; this row neither asserts whole-family completeness nor upgrades source compatibility."
    });
  }
  return {
    schemaVersion: "6529stream.current-v1-safe-coverage.v1",
    sourceCommit: V1_SAFE_SOURCE,
    sourceTree: execFileSync("git", ["rev-parse", `${V1_SAFE_SOURCE}^{tree}`], { cwd: repoRoot, encoding: "utf8" }).trim(),
    capture: {
      name: "parallel-feature-batch102-20260920", inputSha256: sha(inputBytes), outputSha256: sha(outputBytes),
      literalSources: Object.keys(input.sources).length, compilerErrors: 0,
      allSourceIdentitySha256: sha(JSON.stringify(Object.entries(input.sources).sort(([a], [b]) => compareText(a, b)).map(([path, value]) => [path, sha(value.content)]))),
      verification: "Exact capture hashes checked; each selected concrete source and graph reference also read at sourceCommit. Full 2710-source Git comparison is separate parent evidence."
    },
    scope: {
      deploymentRoles: 37,
      deploymentOrRuntimeProven: false,
      completeWorkflowClaims: 0,
      productionSolidityMutationsPerformed: false,
      warning: "Function presence, generic ABI encoding, lexical matches and historical coverage are not complete current Safe support. Fallback-routed methods require companion inventory."
    },
    stageDefinitions: {
      vocabulary: ["review-required", "not-applicable", "missing", "partial", "verified"],
      rule: "Each verified stage needs method/profile-specific evidence at its own source/runtime pin. Lexical candidates never change a stage.",
      "reviewed-historical-workflow": {
        encoding: "verified", typedRequestOrSigning: "verified", callerAndValueAuthority: "verified",
        pinnedSimulation: "verified", directReceipt: "verified", safeCallComposition: "verified", safeReceipt: "verified",
        typedRead: "partial",
        evidenceScope: "Manual source review of the named bounded client helpers and retained compiler fixture; existing tests are historical evidence, not rerun by inventory generation. Full protocol runtime and all ABI102 semantics are unverified."
      },
      "reviewed-current-client-workflow": {
        encoding: "verified", typedRequestOrSigning: "verified", callerAndValueAuthority: "verified",
        pinnedSimulation: "verified", directReceipt: "verified", safeCallComposition: "verified", safeReceipt: "verified", typedRead: "verified",
        evidenceScope: "Exact current source and compiler fixture; focused client tests and independent source review. Verified means bounded client behavior, including mocked RPC/direct/Safe receipts, not actual deployed contract, actual Safe or whole-graph runtime acceptance."
      },
      "write-default": Object.fromEntries(stages.map(stage => [stage, stage === "typedRead" ? "not-applicable" : "review-required"])),
      "read-default": Object.fromEntries(stages.map(stage => [stage, ["typedRead", "encoding", "callerAndValueAuthority"].includes(stage) ? "review-required" : "not-applicable"])),
      notApplicableReason: "Read methods do not create transactions or receipts, but caller restrictions still require review; typedRead is not a write-call support stage."
    },
    genericSafe: {
      path: "docs/safe-call-plans.md", operation: 0,
      provides: "ABI-aware ordinary CALL encoding and Safe envelope verification utilities",
      doesNotProve: "target authority, governance current-action context, value correctness, source compatibility, post-state or original receipt attribution"
    },
    endpointDefaults: {
      sourceLocation: "An evidence line without path uses the enclosing implementation.path.",
      view: "Read mutability only; caller restrictions still require review.",
      pure: "Pure mutability only; caller restrictions still require review.",
      "review-required": "Allowed caller is not inferred from ABI or client method names.",
      lexicalClientCandidates: "Numeric references into clientCandidatePaths; candidates alone confer no support stage."
    },
    mappingEvidence: {
      canonicalProfile: graphPaths[0], normativeSource: profile.normative_source,
      currentArtifactSelection: "release-artifacts/current-contracts.json is a smaller compilation target list, not the canonical 37 deployed instances",
      planningInstances: JSON.parse(graphTexts[graphPaths[2]]).instances.length,
      graphReferencesProve: "source construction/use candidates only; no address, runtime, activation or approved-alias proof"
    },
    sourceEvidence, clientEvidence, clientCandidatePaths: clientFiles.map(file => file.path),
    historicalProfiles: oldProfiles, clientSupportProfiles, existingClientsAwaitingStageAttribution,
    artistOriginalOperations: {
      originalIds: { first: 1, last: 60 }, separatelyRetainedId: 61,
      reference: "docs/current-artist-operation-coverage.json",
      sourceCommit: artistCoverage.sourceCommit,
      rowsInReference: artistRows.length,
      staleCoverageWarnings: [
        "Operation 35 also has separate current-artist-recovery-adjudication and current-artist-recovery-rewind clients.",
        "Operation 60 has four bounded baseline/multiple/delegation/multiple-delegation profiles in current-artist-authority-hydration; this does not cover every hydrate selector or recovered profile.",
        "Principal and delegated operation 24 are separate profiles; canonical principal personhood is separately tracked and does not complete every principal subject."
      ],
      currentFacade: "StreamArtistOnboardingRegistry",
      sourceRouteReferences: graphPaths.slice(11),
      operationReferences,
      additionalCurrentFacadeMutations: artistFunctions.filter(fn => !["view", "pure"].includes(fn.mutability)
        && !artistRows.some(row => row.methods.some(name => fn.signature.startsWith(`${name}(`))))
        .map(fn => ({ signature: fn.signature, selector: fn.selector, status: "not represented in the historical operation method list; map separately" })),
      requiredAudit: "Join exact public variants, routed selectors, owner capabilities and semantic profiles; operation IDs are not method counts."
    },
    priorities: [
      { family: "mapping", reason: "Resolve profile/current aliases and role-bound compositions before claiming 37-role completeness.", roles: [2, 16, 20, 21, 24, 32] },
      { family: "revenue-pull", reason: "Review clone release, ClaimRouter and escrow flush/recovery caller/value/receipt workflows; release typed payload alone is partial.", roles: [6, 7, 10] },
      { family: "governance-controls", reason: "Audit role/module lifecycle, original cancellation/veto/export and parameter controls; generic Safe CALL cannot replace Executor current-action context.", roles: [2, 3, 8] },
      { family: "artist-original-variants", reason: "Reconcile stale operation inventory with bounded new clients and remaining principal/delegated/recovery/hydration profiles.", roles: [21] },
      { family: "records-and-views", reason: "Original OwnerRecords, independent attestations, collection views and schema document callers have no dedicated complete family identified by this audit.", roles: [25, 26, 27, 28, 29] },
      { family: "core-and-mint-controls", reason: "Separate wallet and governance collection/phase controls from module-only mint callbacks and existing closed freeze/grace/import clients.", roles: [1, 11, 12] }
    ],
    roles, composition, implementations
  };
}

export function serializeCurrentV1SafeCoverage(value) {
  // Keep each method row on one line, without dropping machine-readable fields.
  const rows = [];
  const json = JSON.stringify(value, (key, current) => {
    if (key !== "functions") return current;
    const marker = `__FUNCTION_ROWS_${rows.length}__`;
    rows.push(current.map(row => `        ${JSON.stringify(row)}`).join(",\n"));
    return marker;
  }, 2);
  return json.replace(/"__FUNCTION_ROWS_(\d+)__"/g, (_, index) => `[\n${rows[Number(index)]}\n      ]`) + "\n";
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const args = process.argv.slice(2);
  const check = args.includes("--check");
  const paths = args.filter(arg => arg !== "--check");
  if (paths.length !== 2) throw Error("Usage: node scripts/generate-current-v1-safe-coverage.mjs ABI_INPUT ABI_OUTPUT [--check]");
  const result = await buildCurrentV1SafeCoverage(await readFile(paths[0]), await readFile(paths[1]));
  const bytes = serializeCurrentV1SafeCoverage(result);
  if (check) {
    if (await readFile(destination, "utf8") !== bytes) throw Error("Current v1 Safe coverage inventory is stale");
  } else {
    await writeFile(destination, bytes, "utf8");
  }
  const hosts = Object.values(result.implementations);
  console.log(`${check ? "Verified" : "Generated"} ${result.roles.length} roles, ${hosts.length} unique candidate implementations, ${hosts.reduce((n, host) => n + host.counts.writes, 0)} mutations and ${hosts.reduce((n, host) => n + host.counts.reads, 0)} reads`);
}
