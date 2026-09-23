import { createHash } from "node:crypto";
import { readFile, writeFile } from "node:fs/promises";
import { resolve } from "node:path";

export const CURRENT_SOURCE_COMMIT = "a0f92ecae8414d36aa715ae1e37d5fb222c0db97";
const HISTORICAL_ROSTER_SOURCE_COMMIT = "aa2ca4a2764ca981630c668966a665637692842d";
const HISTORICAL_CONTRACT_COUNT = 164;
const HISTORICAL_FUNCTION_COUNT = 6553;
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
    return {
      fqn: product.fqn, source, contract: name, family: familyOf(source),
      sourceSha256: bridge.committedBlobSHA256[source], abiSha256: sha256(canonical(artifact.abi)),
      historicalFunctionCount: product.historicalFunctionCount, functionCount: functions.length,
      functionCountDelta: functions.length - product.historicalFunctionCount,
      viewOrPureCount: viewOrPure, stateChangingCount: functions.length - viewOrPure,
      payableFunctionCount: functions.filter(x => x.payable).length,
      functions, specialEntries, callerAuthorization: "source-review-required",
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
  const candidateByFqn = new Map(currentCandidates.candidates.map(x => [x.fqn, x]));
  const excludedByFqn = new Map(currentCandidates.exclusions.map(x => [x.fqn, x]));
  const genesisRoleCoverage = (genesis.entries ?? []).map(entry => {
    const names = [...new Set([...(entry.implementation?.names ?? []), ...(entry.approved_aliases ?? [])])];
    const products = names.flatMap(name => {
      const matches = new Map();
      for (const product of surfaces.filter(x => x.contract === name)) matches.set(product.fqn, { fqn: product.fqn, status: "supported-by-retained-roster" });
      for (const product of candidateByFqn.values()) if (product.name === name) matches.set(product.fqn, { fqn: product.fqn, status: "anchored-candidate-gap" });
      for (const product of excludedByFqn.values()) if (product.name === name) {
        const status = product.exclusionReason === "already-in-164-supported-roster" ? "supported-by-retained-roster" : "excluded-" + product.exclusionReason;
        if (!matches.has(product.fqn) || status === "supported-by-retained-roster") matches.set(product.fqn, { fqn: product.fqn, status });
      }
      return matches.size ? [...matches.values()] : [{ name, fqn: null, status: "no-matching-concrete-ABI213-product" }];
    });
    const hasCandidate = products.some(x => x.status === "anchored-candidate-gap");
    const hasSupported = products.some(x => x.status === "supported-by-retained-roster");
    const hasMissing = products.some(x => x.status === "no-matching-concrete-ABI213-product");
    const status = names.length === 0 && entry.implementation?.mode === "manifest_equivalent" ? "manifest-equivalent-needs-root-mapping"
      : entry.implementation?.mode === "one_of" && hasCandidate && hasMissing ? "candidate-gap-with-unresolved-alternative"
      : hasCandidate && hasMissing ? "candidate-gap-with-unresolved-name"
      : hasCandidate ? "contains-product-absent-from-164-roster"
      : hasSupported && hasMissing ? "supported-product-with-unresolved-name"
      : products.length && products.every(x => x.status === "supported-by-retained-roster") ? "covered-by-retained-164-roster"
      : "review-required";
    return { id: entry.id, key: entry.key, deploymentScope: entry.deployment_scope, implementationMode: entry.implementation?.mode,
      requiredInterfaces: entry.required_interfaces ?? [], names, status, products };
  });
  return {
    schemaVersion: "6529stream.safe-call-surface.abi213.v1",
    capture: {
      sourceCommit: bridge.commit, compilerInputSha256: sha256(inputRaw), compilerOutputSha256: sha256(outputRaw),
      sourceBridgeSha256: sha256(bridgeRaw), settingsSha256: sha256(canonical(input.settings ?? {})),
      genesisProfileSha256: sha256(genesisRaw), planningCandidateSha256: sha256(planningCandidateRaw),
      currentTargetCatalogSha256: sha256(currentTargetsRaw),
      compilerSourceCount: Object.keys(input.sources).length,
    },
    selection: {
      basis: "Historical 164-FQN supported-contract roster, refreshed against ABI213",
      historicalRosterSourceCommit: HISTORICAL_ROSTER_SOURCE_COMMIT,
      supportedProducts: products.length, compilerOnlyPromotion: false,
      deploymentCandidateStatus: "planning", plannedGenesisRoles: genesis.entries.length,
      planningInstanceCount: Array.isArray(genesis.instances) ? genesis.instances.length : 0,
      scopeNote: "The 164 products are a retained supported set, not a blanket permission to omit later full-v1 products. Separate anchored candidates below require root support-scope decisions.",
    },
    qualifications: {
      abiSurface: "Complete current ABI function signatures and receive/fallback handlers for selected products.",
      callerAuthorization: "Not inferred from ABI; individual caller/role requirements remain source-review work.",
      runtimeEvidence: "Not joined here. Existing source-scoped runtime attestations are preserved and are not promoted or cleared.",
    },
    totals, families, surfaces,
    genesisRoleCoverage,
    candidateProductsAbsent164: currentCandidates.candidates,
    excludedAnchoredProducts: currentCandidates.exclusions,
  };
}
export function renderMarkdown(report) {
  const familyRows = Object.entries(report.families).sort(([a], [b]) => a.localeCompare(b))
    .map(([name, x]) => "| " + name + " | " + x.contracts + " | " + x.functions + " | " + x.viewOrPure + " | " + x.stateChanging + " | " + x.receive + " | " + x.fallback + " |");
  const contractRows = report.surfaces.map(x => "| " + x.fqn + " | " + x.functionCount + " | " + x.viewOrPureCount + " | " + x.stateChangingCount + " | " + x.payableFunctionCount + " | " + x.specialEntries.filter(e => e.kind === "receive").length + " | " + x.specialEntries.filter(e => e.kind === "fallback").length + " |");
  const specialRows = report.surfaces.flatMap(x => x.specialEntries.map(e => "| " + x.fqn + " | " + e.kind + " | " + e.stateMutability + " | " + e.payable + " |"));
  const roleRows = report.genesisRoleCoverage.map(x => "| " + x.id + " | " + x.key + " | " + (x.names.length ? x.names.join(", ") : "—") + " | " + x.status + " | " +
    (x.products.length ? x.products.map(p => (p.name ? p.name + ": " : "") + (p.fqn ?? "—") + " (" + p.status + ")").join("<br>") : "—") + " |");
  const candidateRows = report.candidateProductsAbsent164.map(x => "| " + x.fqn + " | " + x.functionCount + " (" + x.readAndCallEvidence.viewOrPureFunctionCount + " read, " + x.readAndCallEvidence.stateChangingFunctionCount + " state-changing) | " +
    (x.publicationEvidence.currentContractTarget ? "current target" : "") + (x.publicationEvidence.currentContractTarget && x.publicationEvidence.productionContractCatalog ? "; " : "") +
    (x.publicationEvidence.productionContractCatalog ? "release catalog" : "") + " | " + x.readAndCallEvidence.testsObserved.length + " test-source reference(s) | " +
    x.anchors.map(a => a.kind + (a.roleKey ? ":" + a.roleKey : "") + (a.line ? ":" + a.line : "") + " (" + a.path + ")").join("<br>") + " | not established; planning candidate has no instances |" );
  return [
    "# Current Safe call-surface inventory (ABI213)", "",
    "Source: " + report.capture.sourceCommit + ". The compiler bridge authenticates all " + report.capture.compilerSourceCount + " source blobs. The machine file contains exact current signatures, selectors, input/output types and source/ABI hashes for " + report.totals.contracts + " retained supported products.",
    "The selected set contains " + report.totals.functions + " functions, " + report.totals.receive + " receive handlers and " + report.totals.fallback + " fallback handlers. This is an ABI surface inventory, not Safe acceptance.", "",
    "The prior 164-FQN roster is retained selection evidence, not blanket permission to omit later full-v1 products. Candidate products absent from it are separately listed below. The 6,840 compiler FQNs include interfaces, libraries, abstract contracts, tests and legacy products; presence alone does not make them independent supported Safe surfaces.",
    "The deployment planning candidate is planning-only, has no instances and is not production-candidate/readiness evidence; no deployment receipt is included. Target/catalog membership means a committed catalog reference only. ABI read/state-changing counts and selectors describe callable shapes if deployed; they do not establish live reads, successful calls, test execution or deployment.", "",
    "## Keep three questions separate", "",
    "- ABI: signatures and receive/fallback handlers are enumerated from the current compiler output.",
    "- Caller authorization: marked source-review-required. ABI entries do not encode role requirements, caller identity or protocol-only boundaries.",
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
    "## Genesis role coverage (37-role source profile)", "",
    "Role names in the actual genesis profile resolve only to the retained roster, anchored candidate gaps, explicit exclusions, or an unresolved manifest-equivalent decision. This is role mapping evidence, not a deployment assertion.", "",
    "| Role ID | Key | Named implementation/aliases | Roster status | ABI213 products |", "| ---: | --- | --- | --- | --- |", ...roleRows, "",
    "## Anchored concrete products absent from the 164 roster", "",
    "Candidates below are concrete source declarations referenced by current genesis role data, the current target catalog, current deployment/creation scripts, test-source identifiers, or the production contract catalog. Abstract contracts, interfaces, libraries and legacy-only sources are excluded. Test identifiers are not evidence that a test executed. A role/script/catalog reference establishes a candidate path, not a deployed address or successful Safe call. Exact anchors and compiler ABI details are in the machine report.", "",
    "| Candidate FQN | ABI functions | Catalog evidence | Test source | Anchors | Deployment status |",
    "| --- | --- | --- | ---: | --- | --- |", ...(candidateRows.length ? candidateRows : ["| None | — | — | — | — | — |"]), "",
    "## Root decisions and assignment queue", "",
    "1. Confirm which anchored candidates become separately supported products. Prioritize those named in the 37 genesis roles and explicit current creation sources; keep catalog-only entries distinguishable.",
    "2. Assign caller classes per selector: user Safe, artist Safe, administrator/governance Safe, permissionless, protocol-only callback, or caller-sensitive read. For Executor-owned operations, identify the required current-action envelope.",
    "3. Attach exact local-test or deployed instance bindings and per-selector success or intentional-rejection evidence. Do not infer runtime coverage from source presence or test references.",
    "4. Preserve receive/fallback dispatch as explicit raw-call routes. ABI213 has three receive entries in the retained roster and more in anchored candidates.", "",
    "## Reproduce", "",
    "node scripts/generate-safe-call-surface-abi213.mjs ABI_INPUT ABI_OUTPUT SOURCE_BRIDGE --check", "",
  ].join("\n");
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
  const data = JSON.stringify(report, null, 2) + "\n", markdown = renderMarkdown(report);
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
