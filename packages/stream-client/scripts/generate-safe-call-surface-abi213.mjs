import { createHash } from "node:crypto";
import { readFile, writeFile } from "node:fs/promises";
import { resolve } from "node:path";

export const CURRENT_SOURCE_COMMIT = "09f32efab40659a11353be75a1d46a3e49959bb7";
const HISTORICAL_ROSTER_SOURCE_COMMIT = "aa2ca4a2764ca981630c668966a665637692842d";
const HISTORICAL_CONTRACT_COUNT = 164;
const HISTORICAL_FUNCTION_COUNT = 6553;
export const CURRENT_37_ROLE_MAP = [
  ["address(f.core)", "StreamCore", "Foundation.core"],
  ["address(f.executor)", "StreamGovernanceExecutor", "Foundation.executor"],
  ["address(f.registry)", "StreamModuleRegistry", "Foundation.registry"],
  ["address(f.revenue)", "StreamRevenueResolver", "Foundation.revenue"],
  ["address(f.factory)", "StreamSplitFactory", "Foundation.factory"],
  ["p.continuity.walletImplementation", "StreamSplitWallet", "ContinuityProducts.walletImplementation; factory-pinned implementation"],
  ["address(f.escrow)", "StreamRevenueEscrow", "Foundation.escrow"],
  ["address(f.assets)", "StreamAssetPolicyRegistry", "Foundation.assets"],
  ["address(p.commerce.native.recorder)", "StreamPrimarySaleSettlement", "CommerceProducts.Products.native.recorder"],
  ["address(p.independent.claims)", "StreamClaimRouter", "GenesisProducts.Products.claims"],
  ["address(f.manager)", "StreamMintManager", "Foundation.manager"],
  ["address(f.ledger)", "StreamMintLedger", "Foundation.ledger"],
  ["address(p.independent.tickets)", "StreamMintTicketGate", "GenesisProducts.Products.tickets"],
  ["address(p.commerce.fixedSale)", "StreamNativeFixedPriceSaleAdapter", "CommerceProducts.Products.fixedSale"],
  ["address(p.commerce.native.house)", "StreamNativeEnglishAuction", "CommerceProducts.Products.native.house"],
  ["address(p.commerce.dutch)", "StreamNativeDutchSale", "CommerceProducts.Products.dutch"],
  ["address(p.commerce.privateSale)", "StreamPrivateSaleAdapter", "CommerceProducts.Products.privateSale"],
  ["address(p.commerce.burn)", "StreamBurnMintGate", "CommerceProducts.Products.burn"],
  ["address(p.independent.delegates)", "StreamDelegateRegistryGate", "GenesisProducts.Products.delegates"],
  ["address(p.commerce.erc20)", "StreamERC20PrimarySettlementAdapter", "CommerceProducts.Products.erc20"],
  ["address(f.artists)", "StreamArtistOnboardingRegistry", "Foundation.artists"],
  ["address(f.router)", "StreamMetadataRouter", "Foundation.router"],
  ["address(p.rendering.renderer)", "StreamRendererV1", "StaticRendererPlan.Products.renderer"],
  ["address(f.metadata)", "StreamCollectionMetadataV1", "Foundation.metadata"],
  ["address(f.schemas)", "StreamSchemaRegistry", "Foundation.schemas"],
  ["address(p.independent.owners)", "StreamOwnerRecords", "GenesisProducts.Products.owners"],
  ["address(p.records.preservation)", "StreamPreservationRecordsV1", "RecordProducts.Products.preservation"],
  ["address(p.independent.attestations)", "StreamCollectionAttestations", "GenesisProducts.Products.attestations"],
  ["address(p.independent.views)", "StreamCollectionViews", "GenesisProducts.Products.views"],
  ["address(f.entropy)", "StreamEntropyCoordinator", "Foundation.entropy"],
  ["address(p.vrf)", "StreamEntropyProviderVRF", "Products.vrf; primary provider"],
  ["address(p.arrng)", "StreamEntropyProviderARRNG", "Products.arrng; configured fallback provider"],
  ["address(f.finality)", "StreamArtworkFinalityRegistry", "Foundation.finality"],
  ["address(p.continuity.entropy)", "StreamEntropyCoordinator", "ContinuityProducts.entropy; distinct backup coordinator"],
  ["address(p.continuity.manager)", "StreamMintManagerFallback", "ContinuityProducts.manager"],
  ["address(f.manifest)", "StreamSystemManifest", "Foundation.manifest"],
  ["address(f.coreFinality)", "StreamCoreFinalityAdapter", "Foundation.coreFinality"],
];
export const CURRENT_SUPPORT_COMPANIONS = [
  ["ROLE_REGISTRY", "StreamRoleRegistry", "_support row 0"],
  ["ROYALTY_RESOLVER", "StreamRoyaltyResolver", "_support row 1"],
  ["ARTIST_COORDINATOR", "StreamArtistOnboardingCoordinator", "_support row 2; suite coordinator"],
  ["ARTIST_ARCHIVE", "StreamArtistArchiveV2", "_support row 3"],
  ["ARTIST_VALIDATOR", "StreamArtistRegistryValidatorBase", "_support row 4"],
  ["ARTIST_OWNER[0]", "StreamArtistBindingLifecycle", "_support row 5; SuiteDeployment owners[0]"],
  ["ARTIST_OWNER[1]", "StreamArtistCollaboratorLifecycle", "_support row 6; SuiteDeployment owners[1]"],
  ["ARTIST_OWNER[2]", "StreamArtistIdentityAuthority", "_support row 7; split identity deployment"],
  ["ARTIST_OWNER[3]", "StreamArtistAcceptanceLifecycle", "_support row 8; SuiteDeployment owners[3]"],
  ["ARTIST_OWNER[4]", "StreamArtistAttributionLifecycle", "_support row 9; SuiteDeployment owners[4]"],
  ["ARTIST_OWNER[5]", "StreamArtistPayoutLifecycle", "_support row 10; SuiteDeployment owners[5]"],
  ["ARTIST_OWNER[6]", "StreamArtistConsentFinalityLifecycle", "_support row 11; SuiteDeployment owners[6]"],
  ["SCHEMA_DOCUMENT_STORE", "StreamSchemaDocumentStore", "_support row 12; StreamSchemaRegistry constructor"],
  ["STATIC_ATTRIBUTION", "StreamStaticAttributionCompanion", "_support row 13; renderer plan product"],
  ["RENDERER_REGISTRY", "StreamRendererRegistryModule", "_support row 14; renderer plan product"],
  ["GENERAL_ATTESTATIONS", "StreamGeneralAttestations", "_support row 15; record products"],
  ["BACKUP_ENTROPY_PROVIDER", "StreamEntropyProviderVRF", "_support row 16; continuity provider"],
  ["FINALITY_CORE_READS", "StreamCore", "_support row 17; CurrentFinalityGraph construction"],
  ["FINALITY_METADATA_READS", "StreamCollectionMetadataV1", "_support row 18; CurrentFinalityGraph construction"],
  ["FINALITY_SCOPE_EVIDENCE", "StreamFinalityNativeEvidenceProvider", "_support row 19; CurrentFinalityGraph Late.PROVIDER"],
  ["FINALITY_ARTIFACT_COVERAGE", "StreamFinalityArtifactCoverage", "_support row 20; CurrentFinalityGraph assemblyArtifact"],
  ["FINALITY_SANCTION_READS", "StreamArtistOnboardingRegistry", "_support row 21; CurrentFinalityGraph construction"],
  ["FINALITY_DISCOVERY", "StreamFinalityCurrentDiscovery", "_support row 22; CurrentFinalityGraph Late.DISCOVERY"],
];
export const CURRENT_IMPLEMENTATION_ONLY_LIBRARIES = [
  ["GENERAL_PAYLOAD_LIBRARY", "StreamGeneralAttestationPayloads", "_support row 23; protocol library, not standalone Safe target"],
  ["SNAPSHOT_BYTES_LIBRARY", "StreamSnapshotManifestBytes", "_support row 24; protocol library, not standalone Safe target"],
];
export const CURRENT_CALLER_ROUTE_RULES = [
  ["StreamNativeFixedPriceSaleAdapter", ["registerPriceProgram", "registerAllowlistPriceProgram", "closePriceProgram", "registerSale", "cancelSale", "setPaused"], "governance-executor-owner-action", "onlyOwner; current deployment owner/Executor binding must be joined before planning.", ["smart-contracts/domains/mint/StreamNativeFixedPriceSaleAdapter.sol"]],
  ["StreamNativeFixedPriceSaleAdapter", ["raiseGasParameter"], "governance-executor-current-action", "Gas parameter update is a governed current-action operation.", ["smart-contracts/domains/mint/StreamNativeFixedPriceSaleAdapter.sol"]],
  ["StreamNativeFixedPriceSaleAdapter", ["purchase", "purchaseWithBurn", "executePriceProgram"], "user-or-artist-safe-executor-action", "Purchase path binds the payer and current Executor action; construct through the captured action envelope.", ["smart-contracts/domains/mint/StreamNativeFixedPriceSaleAdapter.sol"]],
  ["StreamNativeFixedPriceSaleAdapter", ["executeBurnPurchase"], "native-burn-gate-protocol-callback", "Consumes a one-use commitment created by purchaseWithBurn; the gate address and complete purchase inputs are commitment-bound, so a direct Safe call reverts.", ["smart-contracts/domains/mint/StreamNativeFixedPriceSaleAdapter.sol", "smart-contracts/domains/mint/StreamNativeBurnCallback.sol"]],
  ["StreamNativeDutchSale", ["registerDutchSale", "registerAllowlistDutchSale", "closeSale"], "governance-executor-owner-action", "onlyOwner for sale configuration and closure; deployment owner/Executor binding must be joined.", ["smart-contracts/domains/mint/StreamNativeDutchSale.sol"]],
  ["StreamNativeDutchSale", ["pauseAdapter", "unpauseAdapter", "pauseSale", "unpauseSale"], "configured-role-holder-safe-candidate", "Pause and unpause methods require the configured RoleRegistry pause/unpause role; holder-to-Safe binding must be joined.", ["smart-contracts/domains/mint/StreamNativeDutchSale.sol"]],
  ["StreamNativeDutchSale", ["raiseGasParameter"], "governance-executor-current-action", "Gas parameter update is a governed current-action operation.", ["smart-contracts/domains/mint/StreamNativeDutchSale.sol"]],
  ["StreamNativeDutchSale", ["purchase", "purchaseWithAllowlist"], "user-or-artist-safe-executor-action", "Requires msg.sender to equal the bound sale payer and Executor; sale consent also binds the artist.", ["smart-contracts/domains/mint/StreamNativeDutchSale.sol"]],
  ["StreamERC20PrimarySettlementAdapter", ["settleERC20PrimarySaleByPayer", "settleERC20PrimarySaleWithIntent", "settleERC20PrimarySaleWithEIP2612Permit", "settleERC20PrimarySaleWithPermit2", "settleERC20DutchSaleByPayer", "settleERC20DutchSaleWithIntent", "settleERC20DutchSaleWithEIP2612Permit", "settleERC20DutchSaleWithPermit2"], "payer-safe-or-signed-payment-intent", "Direct entry binds msg.sender to payer; intent entry validates payer signature, nonce, deadline and sale/asset caps. Not an unrestricted recorder callback.", ["smart-contracts/domains/revenue/StreamERC20PrimarySettlementAdapter.sol"]],
  ["StreamPrimarySaleSettlement", ["settleERC20PrimarySaleFromAdapter", "settleERC20DutchPrimarySaleFromAdapter", "settleERC20PublicDutchPrimarySaleFromAdapter", "settleNativePrimarySaleFromAdapter", "settleNativePublicPrimarySaleFromAdapter"], "registered-sale-adapter-protocol-callback", "Settlement entry points are adapter protocol calls validated against registered sale and replay state.", ["smart-contracts/domains/revenue/StreamPrimarySaleSettlement.sol"]],
  ["StreamEntropyProviderARRNG", ["requestEntropy"], "entropy-coordinator-protocol-callback", "Requires msg.sender == the configured entropy coordinator.", ["smart-contracts/domains/entropy/StreamEntropyProviderARRNG.sol"]],
  ["StreamEntropyProviderARRNG", ["receiveRandomness"], "arrng-controller-protocol-callback", "Requires msg.sender == the configured ARRNG controller.", ["smart-contracts/domains/entropy/StreamEntropyProviderARRNG.sol"]],
  ["StreamEntropyProviderARRNG", ["retryCoordinatorFulfillment"], "permissionless-protocol-maintenance", "Anyone may retry delivery of an already-authenticated retained provider result; this is not a randomness injection route.", ["smart-contracts/domains/entropy/StreamEntropyProviderARRNG.sol"]],
  ["StreamEntropyProviderARRNG", ["updateRequestPayment", "updateControllerOwnerPin", "withdrawFunds", "raiseGasParameter"], "governance-executor-current-action", "Requires the configured governance authority and matching current-action scope/state transition.", ["smart-contracts/domains/entropy/StreamEntropyProviderARRNG.sol"]],
  ["StreamPreservationRecordsV1", ["registerTokenSubject", "registerMediaSubject"], "permissionless-subject-registration", "Derives the subject from current Core/Metadata reads; registration does not assert an artist record.", ["smart-contracts/domains/preservation/StreamPreservationRecordsV1.sol"]],
  ["StreamPreservationRecordsV1", ["recordCollectionRecordWithPayload"], "artist-safe-authorized-record-write", "The record writer is msg.sender and Reads.admit checks the selected Metadata-family authority before retaining payload bytes.", ["smart-contracts/domains/preservation/StreamPreservationRecordsV1.sol"]],
  ["StreamPreservationRecordsV1", ["raiseGasParameter"], "governance-executor-current-action", "Gas parameter update is a governed current-action operation.", ["smart-contracts/domains/preservation/StreamPreservationRecordsV1.sol"]],
];
const root = resolve(import.meta.dirname, "..");
const rosterPath = resolve(root, "docs/safe-acceptance-backlog.md");
const oldSummaryPath = resolve(root, "docs/safe-acceptance-current-summary.json");
const genesisPath = resolve(root, "../../release-artifacts/genesis-deployment-profile.json");
const planningCandidatePath = resolve(root, "../../deployments/config/canonical-deployment-candidate-v2-planning.json");
const currentTargetsPath = resolve(root, "../../release-artifacts/current-contracts.json");
const productionCatalogPath = resolve(root, "../../release-artifacts/contracts.json");
const resultPath = resolve(root, "docs/current-safe-call-surface-abi213.json");
const markdownPath = resolve(root, "docs/current-safe-call-surface-abi213.md");

function requireThat(ok, message) { if (!ok) throw Error(message); }
export function sha256(value) { return createHash("sha256").update(value).digest("hex"); }
export function canonical(value) {
  if (value === null || typeof value === "string" || typeof value === "boolean") return JSON.stringify(value);
  if (typeof value === "number") {
    requireThat(Number.isSafeInteger(value) && Number.isFinite(value), "Expected safe JSON number");
    return String(value);
  }
  if (Array.isArray(value)) return "[" + value.map(canonical).join(",") + "]";
  requireThat(value && typeof value === "object", "Expected JSON value");
  return "{" + Object.keys(value).sort().map(k => JSON.stringify(k) + ":" + canonical(value[k])).join(",") + "}";
}
function parseJson(raw, name) {
  try { return JSON.parse(raw); } catch (error) { throw Error(name + " is not valid JSON: " + error.message); }
}
function stripTrivia(source) {
  let out = "", i = 0, state = "code", quoteChar = "";
  while (i < source.length) {
    const c = source[i], n = source[i + 1];
    if (state === "code" && c === "/" && n === "/") { out += "  "; i += 2; state = "line"; continue; }
    if (state === "code" && c === "/" && n === "*") { out += "  "; i += 2; state = "block"; continue; }
    if (state === "line") { if (c === "\n") { out += "\n"; state = "code"; } else out += " "; i++; continue; }
    if (state === "block") { if (c === "*" && n === "/") { out += "  "; i += 2; state = "code"; } else { out += c === "\n" ? "\n" : " "; i++; } continue; }
    if (state === "string") {
      if (c === "\\") { out += "  "; i += 2; continue; }
      if (c === quoteChar) { out += " "; i++; state = "code"; continue; }
      out += c === "\n" ? "\n" : " "; i++; continue;
    }
    if (state === "code" && (c === "\"" || c === "'")) { quoteChar = c; out += " "; i++; state = "string"; continue; }
    out += c; i++;
  }
  return out;
}
function declarations(source) {
  const clean = stripTrivia(source), rows = [];
  const pattern = /\b(abstract\s+)?(contract|interface|library)\s+([A-Za-z_$][A-Za-z0-9_$]*)\b/g;
  for (const m of clean.matchAll(pattern)) rows.push({
    name: m[3], kind: m[2] === "interface" ? "interface" : m[2] === "library" ? "library" : m[1] ? "abstract-contract" : "contract",
  });
  return rows;
}
function abiType(parameter) {
  requireThat(parameter && typeof parameter.type === "string", "Malformed ABI parameter");
  let type = parameter.type;
  if (type.startsWith("tuple")) {
    requireThat(Array.isArray(parameter.components), "Tuple ABI parameter lacks components");
    type = "(" + parameter.components.map(abiType).join(",") + ")" + type.slice(5);
  }
  return type === "uint" ? "uint256" : type === "int" ? "int256" : type === "fixed" ? "fixed128x18" : type === "ufixed" ? "ufixed128x18" : type;
}
function signature(fragment) {
  requireThat(typeof fragment.name === "string" && Array.isArray(fragment.inputs), "Malformed ABI function");
  return fragment.name + "(" + fragment.inputs.map(abiType).join(",") + ")";
}
function compilerMethodIdentifierSignature(fragment) {
  const param = p => {
    if (typeof p.internalType === "string" && p.internalType.startsWith("struct ")) {
      return p.internalType.slice("struct ".length).replace(/\s+/g, "") + p.type.slice("tuple".length);
    }
    let type = p.type;
    if (type.startsWith("tuple")) type = "(" + p.components.map(param).join(",") + ")" + type.slice("tuple".length);
    return type === "uint" ? "uint256" : type === "int" ? "int256" : type === "fixed" ? "fixed128x18" : type === "ufixed" ? "ufixed128x18" : type;
  };
  return fragment.name + "(" + fragment.inputs.map(param).join(",") + ")";
}
function compilerSelector(fragment, identifiers, fqn) {
  const canonicalSignature = signature(fragment), compilerKey = identifiers[canonicalSignature] !== undefined
    ? canonicalSignature : compilerMethodIdentifierSignature(fragment);
  const selector = identifiers[compilerKey];
  requireThat(typeof selector === "string" && /^[0-9a-fA-F]{8}$/.test(selector), "Compiler selector missing: " + fqn + ":" + canonicalSignature);
  return { signature: canonicalSignature, compilerKey, selector: "0x" + selector.toLowerCase() };
}
function oldRoster(markdown, oldSummary) {
  requireThat(oldSummary.capture?.sourceCommit === HISTORICAL_ROSTER_SOURCE_COMMIT, "Historical roster source changed");
  requireThat(oldSummary.summary?.primaryContracts === HISTORICAL_CONTRACT_COUNT
    && oldSummary.summary?.primaryFunctions === HISTORICAL_FUNCTION_COUNT, "Historical roster totals changed");
  const rows = [];
  for (const line of markdown.split(/\r?\n/)) {
    if (!line.startsWith("| " + String.fromCharCode(96) + "smart-contracts/")) continue;
    const cells = line.split("|").map(x => x.trim()), cell = cells[1];
    const fqn = cell?.charCodeAt(0) === 96 ? cell.slice(1, -1) : cell;
    requireThat(fqn && Number.isSafeInteger(Number(cells[2])), "Malformed historical product row");
    rows.push({ fqn, historicalFunctionCount: Number(cells[2]) });
  }
  requireThat(rows.length === HISTORICAL_CONTRACT_COUNT, "Historical supported-contract count differs");
  requireThat(rows.reduce((n, x) => n + x.historicalFunctionCount, 0) === HISTORICAL_FUNCTION_COUNT, "Historical function total differs");
  requireThat(new Set(rows.map(x => x.fqn)).size === rows.length, "Duplicate historical product FQN");
  return rows.sort((a, b) => a.fqn.localeCompare(b.fqn));
}
function validateCapture(input, output, bridge) {
  requireThat(bridge.commit === CURRENT_SOURCE_COMMIT, "Expected the retained ABI213 source commit");
  requireThat(Array.isArray(bridge.mismatches) && bridge.mismatches.length === 0, "Source bridge reports mismatches");
  const sources = input.sources, pins = bridge.committedBlobSHA256;
  requireThat(sources && pins && Object.keys(sources).length === Object.keys(pins).length, "Compiler source set differs from source bridge");
  for (const [path, row] of Object.entries(sources)) {
    requireThat(Object.hasOwn(pins, path), "Source bridge lacks " + path);
    requireThat(typeof row.content === "string" && sha256(row.content) === pins[path], "Source bytes differ at " + path);
  }
  requireThat(!output.errors?.some(x => x.severity === "error"), "ABI output contains compiler errors");
}
function familyOf(source) {
  const parts = source.split("/");
  return parts[1] === "domains" ? parts[2] : parts[1] === "core" ? "core" : parts[1];
}
function currentRoleExpressions(source) {
  const clean = stripTrivia(source), match = /\binventory\.roles\s*=\s*\[([\s\S]*?)\]\s*;/.exec(clean);
  requireThat(match, "Current capture source lacks its inventory.roles array");
  const expressions = match[1].split(",").map(x => x.trim()).filter(Boolean);
  requireThat(expressions.length === 37, "Current capture role array is not exactly 37 entries");
  return expressions;
}
function concreteProducts(input, output, bridge) {
  const byName = new Map(), byFqn = new Map();
  for (const [path, artifacts] of Object.entries(output.contracts ?? {})) {
    if (!path.startsWith("smart-contracts/") || !input.sources[path]) continue;
    const declarationsByName = new Map(declarations(input.sources[path].content).map(row => [row.name, row]));
    for (const [name, artifact] of Object.entries(artifacts)) {
      const declaration = declarationsByName.get(name);
      if (!declaration) continue;
      const product = { fqn: path + ":" + name, name, source: path, declarationKind: declaration.kind,
        sourceSha256: bridge.committedBlobSHA256[path], abi: artifact.abi ?? [], methodIdentifiers: artifact.evm?.methodIdentifiers ?? {} };
      byFqn.set(product.fqn, product);
      const rows = byName.get(name) ?? [];
      rows.push(product); byName.set(name, rows);
    }
  }
  return { byName, byFqn };
}
function callerRoutesFor(product, functions) {
  const routeRules = CURRENT_CALLER_ROUTE_RULES.filter(([name]) => name === product.name);
  return routeRules.flatMap(([, methodNames, callerClass, basis, evidencePaths]) => methodNames.map(name => {
    const matches = functions.filter(fn => fn.signature.slice(0, fn.signature.indexOf("(")) === name);
    requireThat(matches.length === 1, "Expected one ABI method for caller-route evidence: " + product.fqn + ":" + name);
    const permissionless = callerClass.startsWith("permissionless-");
    const bindingNote = callerClass.includes("native-burn-gate") ? "bind the configured burn gate and its runtime"
      : callerClass.includes("protocol-callback") ? "bind the configured callback address, runtime and protocol owner"
      : callerClass.includes("registered-sale-adapter") ? "bind the registered adapter identity and runtime"
      : callerClass.includes("payer-safe") ? "bind payer Safe or verify the signed payment intent"
      : callerClass.includes("user-or-artist-safe") ? "bind payer/artist identity and the Executor action envelope"
      : callerClass.includes("artist-safe") ? "bind artist Safe and current Metadata-family authority grant"
      : callerClass.includes("role-holder") ? "bind the RoleRegistry holder to its selected Safe"
      : callerClass.includes("governance-executor") ? "bind owner/authority and the Governance Safe to Executor action flow"
      : permissionless ? "no caller role; deployment/runtime identity remains outside this inventory"
      : "join the exact caller and deployment authority";
    return { signature: matches[0].signature, selector: matches[0].selector, callerClass, basis, evidencePaths,
      callerBindingRequired: !permissionless, bindingNote };
  }));
}
function currentSurface(product, sourceReason) {
  requireThat(product.declarationKind === "contract", "Current support product is not a concrete contract: " + product.fqn);
  const functions = product.abi.filter(x => x.type === "function").map(fragment => {
    const method = compilerSelector(fragment, product.methodIdentifiers, product.fqn);
    return { signature: method.signature, selector: method.selector, stateMutability: fragment.stateMutability,
      payable: fragment.stateMutability === "payable", inputs: fragment.inputs.map(abiType), outputs: (fragment.outputs ?? []).map(abiType) };
  }).sort((a, b) => a.signature.localeCompare(b.signature));
  const specialEntries = product.abi.filter(x => x.type === "receive" || x.type === "fallback").map(fragment => ({
    kind: fragment.type, selector: null, stateMutability: fragment.stateMutability, payable: fragment.stateMutability === "payable",
    inputs: (fragment.inputs ?? []).map(abiType), outputs: (fragment.outputs ?? []).map(abiType),
  })).sort((a, b) => a.kind.localeCompare(b.kind));
  const viewOrPureCount = functions.filter(x => x.stateMutability === "view" || x.stateMutability === "pure").length;
  const callerRoutes = callerRoutesFor(product, functions);
  return { fqn: product.fqn, source: product.source, contract: product.name, family: familyOf(product.source),
    sourceSha256: product.sourceSha256, abiSha256: sha256(canonical(product.abi)), functionCount: functions.length,
    viewOrPureCount, stateChangingCount: functions.length - viewOrPureCount,
    payableFunctionCount: functions.filter(x => x.payable).length, functions, specialEntries,
    selectionReason: sourceReason, callerAuthorization: callerRoutes.length ? "source-scoped-route-candidates" : "source-review-required",
    callerRoutes, safeRuntimeEvidence: "not-joined-by-this-static-inventory" };
}
function buildCandidates({ input, output, bridge, genesis, planningCandidate, currentTargets, catalog, support }) {
  const anchors = new Map();
  const testReferences = new Map();
  const add = (name, row) => {
    const rows = anchors.get(name) ?? [];
    rows.push(row); anchors.set(name, rows);
  };
  for (const entry of genesis.entries ?? []) {
    for (const name of [...(entry.implementation?.names ?? []), ...(entry.approved_aliases ?? [])]) {
      add(name, { kind: "genesis-role", roleId: entry.id, roleKey: entry.key, deploymentScope: entry.deployment_scope,
        implementationMode: entry.implementation?.mode, path: "release-artifacts/genesis-deployment-profile.json" });
    }
  }
  for (const product of currentTargets.contracts ?? []) {
    add(product.name, { kind: "current-contract-target", path: "release-artifacts/current-contracts.json", source: product.source });
  }
  for (const [path, row] of Object.entries(input.sources)) {
    if (!path.startsWith("script/current/") || !path.endsWith(".sol")) continue;
    const clean = stripTrivia(row.content);
    const lineAt = index => clean.slice(0, index).split("\n").length;
    for (const match of clean.matchAll(/\bnew\s+([A-Z][A-Za-z0-9_$]*)\b/g)) add(match[1], { kind: "current-deployment-construction", form: "new", path, line: lineAt(match.index) });
    for (const match of clean.matchAll(/\btype\s*\(\s*([A-Z][A-Za-z0-9_$]*)\s*\)\s*\.creationCode\b/g)) add(match[1], { kind: "current-creation-code", form: "type(...).creationCode", path, line: lineAt(match.index) });
  }
  for (const product of catalog.production_contracts ?? []) {
    add(product.name, { kind: "release-contract-catalog", path: product.source, legacy: product.source.split("/").includes("legacy") });
  }
  for (const [path, row] of Object.entries(input.sources)) {
    if (!/^(test|tests|smart-contracts\/test|smart-contracts\/tests)\//.test(path) || !path.endsWith(".sol")) continue;
    const clean = stripTrivia(row.content);
    const identifiers = new Set([...clean.matchAll(/\b[A-Z][A-Za-z0-9_$]*\b/g)].map(x => x[0]));
    for (const name of identifiers) {
      const rows = testReferences.get(name) ?? [];
      rows.push({ kind: "test-source-reference", path, qualification: "identifier-reference-only-execution-not-verified" });
      testReferences.set(name, rows);
    }
  }

  const decls = new Map();
  for (const [path, row] of Object.entries(input.sources)) {
    if (!path.startsWith("smart-contracts/") || !path.endsWith(".sol")) continue;
    for (const d of declarations(row.content)) {
      const fqn = path + ":" + d.name;
      decls.set(fqn, { ...d, source: path, sourceSha256: bridge.committedBlobSHA256[path] });
    }
  }
  const byName = new Map();
  for (const [path, contracts] of Object.entries(output.contracts ?? {})) {
    if (!path.startsWith("smart-contracts/")) continue;
    for (const name of Object.keys(contracts)) {
      const fqn = path + ":" + name, d = decls.get(fqn);
      if (!d) continue;
      const values = byName.get(name) ?? [];
      values.push({ fqn, declaration: d, abi: contracts[name].abi ?? [], methodIdentifiers: contracts[name].evm?.methodIdentifiers ?? {} });
      byName.set(name, values);
    }
  }
  const candidates = [], exclusions = [];
  for (const [name, evidence] of [...anchors].sort(([a], [b]) => a.localeCompare(b))) {
    for (const product of byName.get(name) ?? []) {
      const row = {
        name, fqn: product.fqn, sourceSha256: product.declaration.sourceSha256,
        declarationKind: product.declaration.kind,
        functionCount: product.abi.filter(x => x.type === "function").length,
        receiveCount: product.abi.filter(x => x.type === "receive").length,
        fallbackCount: product.abi.filter(x => x.type === "fallback").length,
        alreadyInSupportedRoster: support.has(product.fqn), anchors: evidence,
        deploymentEvidence: {
          status: "not-established",
          planningCandidateHasNoInstances: Array.isArray(planningCandidate.instances) && planningCandidate.instances.length === 0,
          productionCandidate: planningCandidate.production_candidate,
          readinessEvidence: planningCandidate.readiness_evidence,
          productionReceiptIncluded: false,
        },
        deploymentCandidate: { id: planningCandidate.candidate_id, status: planningCandidate.status,
          productionCandidate: planningCandidate.production_candidate, readinessEvidence: planningCandidate.readiness_evidence },
        publicationEvidence: {
          currentContractTarget: evidence.some(x => x.kind === "current-contract-target"),
          productionContractCatalog: evidence.some(x => x.kind === "release-contract-catalog"),
          catalogIsDeploymentProof: false,
        },
        readAndCallEvidence: {
          viewOrPureFunctionCount: product.abi.filter(x => x.type === "function" && (x.stateMutability === "view" || x.stateMutability === "pure")).length,
          stateChangingFunctionCount: product.abi.filter(x => x.type === "function" && x.stateMutability !== "view" && x.stateMutability !== "pure").length,
          callableStatus: "ABI exposes selectors; deployed instance and successful runtime call are not established",
          runtimeCallsObserved: false,
          testsObserved: testReferences.get(name) ?? [],
        },
        abiFunctions: product.abi.filter(x => x.type === "function").map(fragment => {
          const method = compilerSelector(fragment, product.methodIdentifiers, product.fqn);
          return { signature: method.signature, selector: method.selector, compilerMethodIdentifierSignature: method.compilerKey, stateMutability: fragment.stateMutability,
            payable: fragment.stateMutability === "payable", inputs: fragment.inputs.map(abiType), outputs: (fragment.outputs ?? []).map(abiType) };
        }).sort((a, b) => a.signature.localeCompare(b.signature)),
        callerAuthorization: "source-review-required",
        safeRuntimeEvidence: "not-joined-by-this-static-inventory",
      };
      const isLegacyOnly = product.declaration.source.split("/").includes("legacy")
        && !evidence.some(x => x.kind === "genesis-role" || x.kind === "current-contract-target"
          || x.kind === "current-deployment-construction" || x.kind === "current-creation-code");
      if (product.declaration.kind !== "contract") exclusions.push({ ...row, exclusionReason: product.declaration.kind });
      else if (isLegacyOnly) exclusions.push({ ...row, exclusionReason: "legacy-only source" });
      else if (support.has(product.fqn)) exclusions.push({ ...row, exclusionReason: "already-in-164-supported-roster" });
      else candidates.push(row);
    }
  }
  const byFqn = new Map();
  for (const row of candidates) {
    const old = byFqn.get(row.fqn);
    if (old) old.anchors = [...old.anchors, ...row.anchors];
    else byFqn.set(row.fqn, row);
  }
  for (const row of byFqn.values()) row.anchors = [...new Map(row.anchors.map(x => [JSON.stringify(x), x])).values()];
  return { candidates: [...byFqn.values()].sort((a, b) => a.fqn.localeCompare(b.fqn)), exclusions };
}
export function buildSurfaceInventory({ inputRaw, outputRaw, bridgeRaw, rosterMarkdown, historicalSummaryRaw, genesisRaw, planningCandidateRaw, currentTargetsRaw, catalogRaw }) {
  const input = parseJson(inputRaw, "Compiler input"), output = parseJson(outputRaw, "Compiler output");
  const bridge = parseJson(bridgeRaw, "Source bridge"), oldSummary = parseJson(historicalSummaryRaw, "Historical summary");
  const genesis = parseJson(genesisRaw, "Genesis profile"), planningCandidate = parseJson(planningCandidateRaw, "Deployment planning candidate");
  const currentTargets = parseJson(currentTargetsRaw, "Current contract targets"), catalog = parseJson(catalogRaw, "Production catalog");
  validateCapture(input, output, bridge);
  requireThat(planningCandidate.status === "planning" && planningCandidate.production_candidate === false
    && planningCandidate.readiness_evidence === false && Array.isArray(planningCandidate.instances)
    && planningCandidate.instances.length === 0, "Expected the retained planning-only candidate without instances");
  requireThat(planningCandidate.genesis_profile?.entry_count === genesis.entries?.length
    && planningCandidate.genesis_profile?.entry_count === 37, "Planning candidate does not bind the 37-role genesis profile");
  const products = oldRoster(rosterMarkdown, oldSummary), support = new Set(products.map(x => x.fqn));
  requireThat(genesis.entries.length === 37, "Historical genesis profile must remain a separate 37-label crosswalk");
  const roleSourcePath = "script/current/StreamFullV1Candidate.sol", roleSource = input.sources[roleSourcePath]?.content;
  requireThat(typeof roleSource === "string", "Compiler input lacks the current full37 capture source");
  const capturedExpressions = currentRoleExpressions(roleSource);
  requireThat(capturedExpressions.length === CURRENT_37_ROLE_MAP.length, "Current role map differs from captured role count");
  const concrete = concreteProducts(input, output, bridge);
  const current37RoleCoverage = CURRENT_37_ROLE_MAP.map(([expression, name, typedField], index) => {
    requireThat(capturedExpressions[index] === expression, "Current role expression changed at capture position " + (index + 1));
    const matches = concrete.byName.get(name) ?? [];
    requireThat(matches.length === 1 && matches[0].declarationKind === "contract", "Expected one current concrete product for role " + (index + 1) + ": " + name);
    const historical = genesis.entries[index];
    const fqn = matches[0].fqn;
    return { rolePosition: index + 1, captureExpression: expression, typedField, currentProduct: name, fqn,
      sourceSha256: matches[0].sourceSha256, historicalProfileLabel: { id: historical.id, key: historical.key,
        implementationMode: historical.implementation?.mode, names: historical.implementation?.names ?? [], approvedAliases: historical.approved_aliases ?? [] },
      historicalRosterContainsProduct: support.has(fqn), supportDisposition: support.has(fqn) ? "retained-164" : "current-role-expansion" };
  });
  const supportRosterByFqn = new Map();
  const addCurrentSupport = (name, kind, reason) => {
    const matches = concrete.byName.get(name) ?? [];
    requireThat(matches.length === 1 && matches[0].declarationKind === "contract", "Expected one current support contract: " + name);
    const product = matches[0], old = supportRosterByFqn.get(product.fqn) ?? { name, fqn: product.fqn,
      sourceSha256: product.sourceSha256, historicalRosterContainsProduct: support.has(product.fqn), current37Roles: [], supportCompanions: [] };
    if (kind === "current37-role") old.current37Roles.push(reason);
    else old.supportCompanions.push(reason);
    supportRosterByFqn.set(product.fqn, old);
  };
  for (const role of current37RoleCoverage) addCurrentSupport(role.currentProduct, "current37-role", role.rolePosition);
  for (const [key, name, evidence] of CURRENT_SUPPORT_COMPANIONS) addCurrentSupport(name, "required-companion", { key, evidence });
  const currentSupportRoster = [...supportRosterByFqn.values()].sort((a, b) => a.fqn.localeCompare(b.fqn));
  const currentSupportSet = new Set(currentSupportRoster.map(x => x.fqn));
  const currentSupportSurfaces = currentSupportRoster.filter(x => !support.has(x.fqn)).map(row => {
    const product = concrete.byFqn.get(row.fqn);
    return currentSurface(product, row.current37Roles.length ? "current37-role" : "required-companion");
  });
  const implementationOnlyLibraries = CURRENT_IMPLEMENTATION_ONLY_LIBRARIES.map(([key, name, evidence]) => {
    const matches = concrete.byName.get(name) ?? [];
    requireThat(matches.length === 1 && matches[0].declarationKind === "library", "Expected one current implementation-only library: " + name);
    return { key, name, fqn: matches[0].fqn, sourceSha256: matches[0].sourceSha256, status: "implementation-only-not-standalone-safe-target", evidence };
  });
  const historicalGenesisRoleLabels = genesis.entries.map(entry => ({ id: entry.id, key: entry.key,
    implementationMode: entry.implementation?.mode, names: entry.implementation?.names ?? [], approvedAliases: entry.approved_aliases ?? [] }));
  const surfaces = products.map(product => {
    const colon = product.fqn.lastIndexOf(":"), source = product.fqn.slice(0, colon), name = product.fqn.slice(colon + 1);
    const artifact = output.contracts?.[source]?.[name];
    requireThat(artifact && Array.isArray(artifact.abi), "Supported product missing from current ABI: " + product.fqn);
    const ids = artifact.evm?.methodIdentifiers ?? {};
    const functions = artifact.abi.filter(x => x.type === "function").map(fragment => {
      const method = compilerSelector(fragment, ids, product.fqn);
      return {
        signature: method.signature, selector: method.selector, stateMutability: fragment.stateMutability,
        payable: fragment.stateMutability === "payable", inputs: fragment.inputs.map(abiType), outputs: (fragment.outputs ?? []).map(abiType),
      };
    }).sort((a, b) => a.signature.localeCompare(b.signature));
    const specialEntries = artifact.abi.filter(x => x.type === "receive" || x.type === "fallback").map(x => ({
      kind: x.type, selector: null, stateMutability: x.stateMutability, payable: x.stateMutability === "payable",
      inputs: (x.inputs ?? []).map(abiType), outputs: (x.outputs ?? []).map(abiType),
    })).sort((a, b) => a.kind.localeCompare(b.kind));
    const viewOrPure = functions.filter(x => x.stateMutability === "view" || x.stateMutability === "pure").length;
    const callerRoutes = callerRoutesFor({ name, fqn: product.fqn }, functions);
    return {
      fqn: product.fqn, source, contract: name, family: familyOf(source),
      sourceSha256: bridge.committedBlobSHA256[source], abiSha256: sha256(canonical(artifact.abi)),
      historicalFunctionCount: product.historicalFunctionCount, functionCount: functions.length,
      functionCountDelta: functions.length - product.historicalFunctionCount,
      viewOrPureCount: viewOrPure, stateChangingCount: functions.length - viewOrPure,
      payableFunctionCount: functions.filter(x => x.payable).length,
      functions, specialEntries, callerAuthorization: callerRoutes.length ? "source-scoped-route-candidates" : "source-review-required", callerRoutes,
      safeRuntimeEvidence: "not-joined-by-this-static-inventory",
    };
  });
  const totals = { contracts: surfaces.length, functions: 0, viewOrPure: 0, stateChanging: 0, payableFunctions: 0, receive: 0, fallback: 0 };
  const families = {};
  for (const row of surfaces) {
    totals.functions += row.functionCount; totals.viewOrPure += row.viewOrPureCount;
    totals.stateChanging += row.stateChangingCount; totals.payableFunctions += row.payableFunctionCount;
    const family = families[row.family] ??= { contracts: 0, functions: 0, viewOrPure: 0, stateChanging: 0, receive: 0, fallback: 0 };
    family.contracts++; family.functions += row.functionCount; family.viewOrPure += row.viewOrPureCount;
    family.stateChanging += row.stateChangingCount;
    for (const entry of row.specialEntries) { totals[entry.kind]++; family[entry.kind]++; }
  }
  const currentCandidates = buildCandidates({ input, output, bridge, genesis, planningCandidate, currentTargets, catalog, support });
  for (const candidate of currentCandidates.candidates) {
    candidate.currentSupportRosterMember = currentSupportSet.has(candidate.fqn);
    candidate.supportDisposition = candidate.currentSupportRosterMember ? "selected-from-current37-or-required-companion"
      : candidate.anchors.every(x => x.kind === "release-contract-catalog") ? "catalog-only-not-promoted"
      : "anchored-candidate-not-selected-by-current37-capture";
    if (candidate.currentSupportRosterMember) {
      candidate.supportedSurfaceFqn = candidate.fqn;
      delete candidate.abiFunctions;
    }
  }
  const currentSupportTotals = { contracts: currentSupportSurfaces.length, functions: 0, viewOrPure: 0, stateChanging: 0, payableFunctions: 0 };
  for (const row of currentSupportSurfaces) {
    currentSupportTotals.functions += row.functionCount; currentSupportTotals.viewOrPure += row.viewOrPureCount;
    currentSupportTotals.stateChanging += row.stateChangingCount; currentSupportTotals.payableFunctions += row.payableFunctionCount;
  }
  const historicalTotals = { ...totals };
  const historicalFamilies = JSON.parse(JSON.stringify(families));
  for (const row of currentSupportSurfaces) {
    totals.contracts++; totals.functions += row.functionCount; totals.viewOrPure += row.viewOrPureCount;
    totals.stateChanging += row.stateChangingCount; totals.payableFunctions += row.payableFunctionCount;
    const family = families[row.family] ??= { contracts: 0, functions: 0, viewOrPure: 0, stateChanging: 0, receive: 0, fallback: 0 };
    family.contracts++; family.functions += row.functionCount; family.viewOrPure += row.viewOrPureCount;
    family.stateChanging += row.stateChangingCount;
    for (const entry of row.specialEntries) { totals[entry.kind]++; family[entry.kind]++; }
  }
  surfaces.push(...currentSupportSurfaces);
  return {
    schemaVersion: "6529stream.safe-call-surface.abi213.v1",
    capture: {
      sourceCommit: bridge.commit, compilerInputSha256: sha256(inputRaw), compilerOutputSha256: sha256(outputRaw),
      sourceBridgeSha256: sha256(bridgeRaw), settingsSha256: sha256(canonical(input.settings ?? {})),
      genesisProfileSha256: sha256(genesisRaw), planningCandidateSha256: sha256(planningCandidateRaw),
      currentTargetCatalogSha256: sha256(currentTargetsRaw),
      current37CaptureSourceSha256: bridge.committedBlobSHA256[roleSourcePath],
      compilerSourceCount: Object.keys(input.sources).length,
    },
    selection: {
      basis: "Retained historical 164-FQN roster plus products in the exact current full37 capture and its explicit required support rows",
      historicalRosterSourceCommit: HISTORICAL_ROSTER_SOURCE_COMMIT,
      historicalSupportedProducts: products.length, supportedProducts: surfaces.length, compilerOnlyPromotion: false,
      current37RoleCount: current37RoleCoverage.length,
      uniqueCurrentRoleAndCompanionProducts: currentSupportRoster.length,
      addedCurrentSupportProducts: currentSupportSurfaces.length,
      currentSupportTotals,
      deploymentCandidateStatus: "planning", plannedGenesisRoles: genesis.entries.length,
      planningInstanceCount: Array.isArray(genesis.instances) ? genesis.instances.length : 0,
      scopeNote: "Historical profile labels are preserved separately. Current support additions derive from exact StreamFullV1Candidate.capture() role order and _support rows; catalog-only candidates are not auto-promoted.",
    },
    qualifications: {
      abiSurface: "Complete current ABI function signatures and receive/fallback handlers for selected products.",
      callerAuthorization: "Not inferred from ABI; individual caller/role requirements remain source-review work.",
      runtimeEvidence: "Not joined here. Existing source-scoped runtime attestations are preserved and are not promoted or cleared.",
    },
    historicalTotals, historicalFamilies, totals, families, surfaces,
    historicalGenesisRoleLabels,
    current37RoleCoverage,
    currentSupportRoster,
    currentSupportSurfaceFqns: currentSupportSurfaces.map(x => x.fqn),
    implementationOnlyLibraries,
    candidateProductsAbsent164: currentCandidates.candidates,
    excludedAnchoredProducts: currentCandidates.exclusions,
  };
}
export function renderMarkdown(report) {
  const familyRows = Object.entries(report.families).sort(([a], [b]) => a.localeCompare(b))
    .map(([name, x]) => "| " + name + " | " + x.contracts + " | " + x.functions + " | " + x.viewOrPure + " | " + x.stateChanging + " | " + x.receive + " | " + x.fallback + " |");
  const contractRows = report.surfaces.map(x => "| " + x.fqn + " | " + x.functionCount + " | " + x.viewOrPureCount + " | " + x.stateChangingCount + " | " + x.payableFunctionCount + " | " + x.specialEntries.filter(e => e.kind === "receive").length + " | " + x.specialEntries.filter(e => e.kind === "fallback").length + " |");
  const specialRows = report.surfaces.flatMap(x => x.specialEntries.map(e => "| " + x.fqn + " | " + e.kind + " | " + e.stateMutability + " | " + e.payable + " |"));
  const roleRows = report.current37RoleCoverage.map(x => "| " + x.rolePosition + " | `" + x.captureExpression + "` | " + x.currentProduct + " | " + x.typedField + " | " +
    x.fqn + " | " + x.supportDisposition + " | " + x.historicalProfileLabel.key + " |");
  const companionRows = report.currentSupportRoster.filter(x => x.supportCompanions.length).map(x => "| " + x.fqn + " | " +
    x.supportCompanions.map(r => r.key + " — " + r.evidence).join("<br>") + " | " + (x.historicalRosterContainsProduct ? "retained 164" : "added current support") + " |" );
  const routeRows = report.surfaces.filter(surface => (surface.callerRoutes ?? []).length).flatMap(surface => surface.callerRoutes.map(route => "| " + surface.fqn + " | `" + route.signature + "` | " + route.selector + " | " + route.callerClass + " | " + route.basis + " | " +
    route.bindingNote + " |" ));
  const historicalRows = report.historicalGenesisRoleLabels.map(x => "| " + x.id + " | " + x.key + " | " + x.implementationMode + " | " +
    (x.names.length ? x.names.join(", ") : "—") + " | " + (x.approvedAliases.length ? x.approvedAliases.join(", ") : "—") + " |" );
  const candidateRows = report.candidateProductsAbsent164.map(x => "| " + x.fqn + " | " + x.functionCount + " (" + x.readAndCallEvidence.viewOrPureFunctionCount + " read, " + x.readAndCallEvidence.stateChangingFunctionCount + " state-changing) | " +
    (x.publicationEvidence.currentContractTarget ? "current target" : "") + (x.publicationEvidence.currentContractTarget && x.publicationEvidence.productionContractCatalog ? "; " : "") +
    (x.publicationEvidence.productionContractCatalog ? "release catalog" : "") + " | " + x.readAndCallEvidence.testsObserved.length + " test-source reference(s) | " +
    x.anchors.map(a => a.kind + (a.roleKey ? ":" + a.roleKey : "") + (a.line ? ":" + a.line : "") + " (" + a.path + ")").join("<br>") + " | not established; planning candidate has no instances |" );
  return [
    "# Current Safe call-surface inventory (ABI213)", "",
    "Source: " + report.capture.sourceCommit + ". The compiler bridge authenticates all " + report.capture.compilerSourceCount + " source blobs. The machine file contains exact current signatures, selectors, input/output types and source/ABI hashes for " + report.totals.contracts + " supported products, including the retained historical roster and explicit current full37 additions.",
    "The selected set contains " + report.totals.functions + " functions, " + report.totals.receive + " receive handlers and " + report.totals.fallback + " fallback handlers. This is an ABI surface inventory, not Safe acceptance.", "",
    "The prior 164-FQN roster is retained selection evidence, not blanket permission to omit later full-v1 products. Candidate products absent from it are separately listed below. The 6,840 compiler FQNs include interfaces, libraries, abstract contracts, tests and legacy products; presence alone does not make them independent supported Safe surfaces.",
    "The deployment planning candidate is planning-only, has no instances and is not production-candidate/readiness evidence; no deployment receipt is included. Target/catalog membership means a committed catalog reference only. ABI read/state-changing counts and selectors describe callable shapes if deployed; they do not establish live reads, successful calls, test execution or deployment.", "",
    "## Keep three questions separate", "",
    "- ABI: signatures and receive/fallback handlers are enumerated from the current compiler output.",
    "- Caller authorization: only focused current-product routes below have source-scoped caller classifications. ABI entries alone do not encode role requirements, caller identity or protocol-only boundaries; unlisted methods remain source-review-required.",
    "- Safe runtime: not joined in this static report. Existing source-scoped attestations remain in their historical evidence records; this report neither promotes nor discards them.", "",
    "## Supported roster by source family", "",
    "| Family | Contracts | Functions | View/pure | State-changing | Receive | Fallback |",
    "| --- | ---: | ---: | ---: | ---: | ---: | ---: |", ...familyRows, "",
    "## Supported contracts", "",
    "| FQN | Functions | View/pure | State-changing | Payable functions | Receive | Fallback |",
    "| --- | ---: | ---: | ---: | ---: | ---: | ---: |", ...contractRows, "",
    "## Receive and fallback", "",
    "| FQN | Entry | Mutability | Payable |", "| --- | --- | --- | --- |",
    ...(specialRows.length ? specialRows : ["| None | — | — | — |"]), "",
    "## Source-backed caller route candidates", "",
    "These focused classifications follow concrete caller and role checks in the current product source. Rows naming the Governance Executor or a configured role identify candidate authority routes; exact owner/authority, role-holder and Safe addresses still require a deployment join. When the target caller is the Executor, a Governance Safe must reach it through the scheduled action flow. User/artist Safe routes remain deployment-binding candidates. Protocol callbacks are source-restricted endpoints, not ordinary Safe targets. Unlisted methods remain source-review-required; none of these rows proves runtime acceptance.", "",
    "| Product | Function | Selector | Caller route | Source basis | Remaining binding |", "| --- | --- | --- | --- | --- | --- |", ...(routeRows.length ? routeRows : ["| No focused route rows | — | — | — | — | — |"]), "",
    "## Current full37 product map", "",
    "This table follows the exact expression order in `StreamFullV1Candidate.capture()` and resolves every captured address expression to its concrete current product using the typed `Foundation` or `Products` field. Historical genesis labels are shown only as a separate crosswalk; they do not override the current source map. The product map proves neither deployment nor Safe acceptance.", "",
    "| Position | Capture expression | Current product | Typed source field | Concrete compiler product | Roster disposition | Historical label |", "| ---: | --- | --- | --- | --- | --- | --- |", ...roleRows, "",
    "## Required current support companions", "",
    "These concrete contracts are constructed or selected by the current deployment's `_support` rows and related typed deployment sources. Libraries are listed separately and are not standalone Safe targets.", "",
    "| Product | Current support evidence | Roster disposition |", "| --- | --- | --- |", ...(companionRows.length ? companionRows : ["| None | — | — |"]), "",
    "## Historical genesis profile labels", "",
    "The original 37 profile entries are retained verbatim as historical labels for traceability only.", "",
    "| Historical ID | Key | Implementation mode | Names | Approved aliases |", "| ---: | --- | --- | --- | --- |", ...historicalRows, "",
    "## Anchored concrete products absent from the 164 roster", "",
    "Candidates below are concrete source declarations referenced by current genesis role data, the current target catalog, current deployment/creation scripts, test-source identifiers, or the production contract catalog. Abstract contracts, interfaces, libraries and legacy-only sources are excluded. Test identifiers are not evidence that a test executed. A role/script/catalog reference establishes a candidate path, not a deployed address or successful Safe call. Exact anchors and compiler ABI details are in the machine report.", "",
    "| Candidate FQN | ABI functions | Catalog evidence | Test source | Anchors | Deployment status |",
    "| --- | --- | --- | ---: | --- | --- |", ...(candidateRows.length ? candidateRows : ["| None | — | — | — | — | — |"]), "",
    "## Root decisions and assignment queue", "",
    "1. The current full37 roster and source-backed companion set are selected explicitly above. Catalog-only candidates remain unpromoted.",
    "2. Review each selector's caller class: user Safe, artist Safe, administrator/governance Safe, permissionless, protocol-only callback, or caller-sensitive read. For Executor-owned operations, identify the required current-action envelope.",
    "3. Attach exact local-test or deployed instance bindings and per-selector success or intentional-rejection evidence. Do not infer runtime coverage from source presence or test references.",
    "4. Preserve receive/fallback dispatch as explicit raw-call routes. ABI213 has three receive entries in the retained roster and more in anchored candidates.", "",
    "## Reproduce", "",
    "node scripts/generate-safe-call-surface-abi213.mjs ABI_INPUT ABI_OUTPUT SOURCE_BRIDGE --check", "",
  ].join("\n");
}

export function serializeInventory(report) {
  const compactObjectArrays = new Set(["functions", "abiFunctions"]);
  const indent = depth => "  ".repeat(depth);
  const write = (value, depth = 0, key = "") => {
    if (value === undefined) return "null";
    if (value === null || typeof value !== "object") return JSON.stringify(value);
    if (Array.isArray(value)) {
      if (!value.length) return "[]";
      if (compactObjectArrays.has(key)) return "[\n" + value.map(row => indent(depth + 1) + JSON.stringify(row)).join(",\n") + "\n" + indent(depth) + "]";
      return "[\n" + value.map(row => indent(depth + 1) + write(row, depth + 1)).join(",\n") + "\n" + indent(depth) + "]";
    }
    const entries = Object.entries(value).filter(([, child]) => child !== undefined);
    if (!entries.length) return "{}";
    return "{\n" + entries.map(([name, child]) => indent(depth + 1) + JSON.stringify(name) + ": " + write(child, depth + 1, name)).join(",\n") + "\n" + indent(depth) + "}";
  };
  return write(report) + "\n";
}

if (process.argv[1] && resolve(process.argv[1]) === resolve(import.meta.filename)) {
  const [inputPath, outputPath, bridgePath, mode] = process.argv.slice(2);
  requireThat(inputPath && outputPath && bridgePath && (!mode || mode === "--check"),
    "Usage: node generate-safe-call-surface-abi213.mjs ABI_INPUT ABI_OUTPUT SOURCE_BRIDGE [--check]");
  const [inputRaw, outputRaw, bridgeRaw, roster, oldSummaryRaw, genesisRaw, planningCandidateRaw, currentTargetsRaw, catalogRaw] = await Promise.all([
    readFile(inputPath, "utf8"), readFile(outputPath, "utf8"), readFile(bridgePath, "utf8"),
    readFile(rosterPath, "utf8"), readFile(oldSummaryPath, "utf8"),
    readFile(genesisPath, "utf8"), readFile(planningCandidatePath, "utf8"), readFile(currentTargetsPath, "utf8"), readFile(productionCatalogPath, "utf8"),
  ]);
  const report = buildSurfaceInventory({ inputRaw, outputRaw, bridgeRaw, rosterMarkdown: roster,
    historicalSummaryRaw: oldSummaryRaw, genesisRaw, planningCandidateRaw, currentTargetsRaw, catalogRaw });
  const data = serializeInventory(report), markdown = renderMarkdown(report);
  if (mode === "--check") {
    const [oldData, oldMarkdown] = await Promise.all([readFile(resultPath, "utf8"), readFile(markdownPath, "utf8")]);
    requireThat(oldData === data && oldMarkdown === markdown, "ABI213 Safe call-surface inventory is stale");
    console.log("ABI213 Safe call-surface inventory is current");
  } else {
    await Promise.all([writeFile(resultPath, data), writeFile(markdownPath, markdown)]);
    console.log("Wrote " + report.totals.contracts + " supported products, " + report.totals.functions + " functions, " +
      report.candidateProductsAbsent164.length + " anchored candidate products, " + report.totals.receive + " receive and " + report.totals.fallback + " fallback entries");
  }
}
