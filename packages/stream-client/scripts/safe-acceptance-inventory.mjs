import { createHash } from "node:crypto";
import { FunctionFragment, id as keccakId } from "ethers";

/** Sorted, lossless JSON for inventory identities; unsupported JavaScript values fail closed. */
export function canonical(value) {
  const active = new Set();
  function visit(v) {
    if (v === null || typeof v === "boolean" || typeof v === "string") return JSON.stringify(v);
    if (typeof v === "number") {
      if (!Number.isFinite(v) || !Number.isSafeInteger(v) || Object.is(v, -0)) throw Error("Expected safe JSON number");
      return String(v);
    }
    if (!v || typeof v !== "object" || active.has(v)) throw Error("Unsupported or cyclic JSON value");
    active.add(v);
    let encoded;
    if (Array.isArray(v)) {
      if (Reflect.ownKeys(v).length !== v.length + 1 || Array.from({ length: v.length }, (_, i) => i).some(i => !Object.hasOwn(v, i))) throw Error("Expected dense JSON array");
      encoded = "[" + v.map(visit).join(",") + "]";
    } else {
      if (![Object.prototype, null].includes(Object.getPrototypeOf(v))) throw Error("Expected plain JSON object");
      const keys = Reflect.ownKeys(v);
      if (keys.some(k => typeof k !== "string")) throw Error("Symbol JSON key");
      encoded = "{" + keys.sort().map(k => {
        const property = Object.getOwnPropertyDescriptor(v, k);
        if (!property || !Object.hasOwn(property, "value") || !property.enumerable) throw Error("Expected enumerable JSON value");
        return JSON.stringify(k) + ":" + visit(property.value);
      }).join(",") + "}";
    }
    active.delete(v);
    return encoded;
  }
  return visit(value);
}
export function sha256(value) {
  if (typeof value !== "string" && !(value instanceof Uint8Array)) throw Error("sha256 expects UTF-8 text or bytes");
  return createHash("sha256").update(value).digest("hex");
}
const copy = value => JSON.parse(canonical(value));
const compare = (a, b) => a < b ? -1 : a > b ? 1 : 0;
function require(condition, message) { if (!condition) throw Error(message); }
function object(value, label) {
  require(value !== null && typeof value === "object" && !Array.isArray(value), label + " must be an object");
  canonical(value);
  return value;
}
function array(value, label) { require(Array.isArray(value), label + " must be an array"); canonical(value); return value; }
function nonempty(value, label) { require(typeof value === "string" && value.length > 0, label + " must be nonempty"); return value; }
function pin(value, label) { require(typeof value === "string" && /^[a-f0-9]{64}$/.test(value), label + " must be a lowercase SHA-256"); return value; }
function sourcePath(path) {
  require(typeof path === "string" && path.endsWith(".sol") && !path.startsWith("/") && !/[\\:]/.test(path)
    && path.split("/").every(p => p !== "" && p !== "." && p !== ".."), "Noncanonical Solidity source path");
  return path;
}
function coordinate(value) {
  require(typeof value === "string" && value.split(":").length === 2, "Expected full source.sol:Contract FQN");
  const [source, name] = value.split(":");
  sourcePath(source);
  require(/^[A-Za-z_$][A-Za-z0-9_$]*$/.test(name), "Invalid FQN contract name");
  return { source, name };
}
function freeze(value) { if (value && typeof value === "object") { Object.values(value).forEach(freeze); Object.freeze(value); } return value; }
function functionSignature(row) {
  // FunctionFragment resolves nested tuples, arrays and canonical elementary aliases.
  return FunctionFragment.from(row).format("sighash");
}
function nominalType(field) {
  if (field.type.startsWith("tuple")) {
    require(Array.isArray(field.components), "Tuple ABI lacks components");
    return "(" + field.components.map(nominalType).join(",") + ")" + field.type.slice(5);
  }
  return field.type;
}
function nominalSignature(row) {
  require(typeof row.name === "string" && Array.isArray(row.inputs), "Malformed function ABI");
  return row.name + "(" + row.inputs.map(nominalType).join(",") + ")";
}

/**
 * Pure enumeration only. The caller authenticates raw compiler input/output bytes
 * against profile.capture before invoking this function. No coverage is inferred.
 */
export function buildInventory({ input, output, profile, genesis, deployment }) {
  object(input, "input"); object(output, "output"); object(profile, "profile"); object(genesis, "genesis"); object(deployment, "deployment");
  const capture = copy(object(profile.capture, "profile.capture"));
  require(typeof capture.sourceCommit === "string" && /^[a-f0-9]{40}$/.test(capture.sourceCommit), "Expected exact Git source commit");
  for (const key of ["inputSha256", "outputSha256", "settingsSha256"]) pin(capture[key], "capture." + key);
  require(sha256(canonical(input.settings ?? {})) === capture.settingsSha256, "Compiler settings hash differs");
  require(!array(output.errors ?? [], "compiler errors").some(e => e.severity === "error"), "Compiler output contains errors");
  const sources = object(input.sources, "literal compiler sources"), contracts = object(output.contracts, "compiler contracts");
  const sourcePins = {};
  for (const path of Object.keys(sources).sort(compare)) {
    sourcePath(path);
    require(typeof sources[path]?.content === "string", "Missing literal compiler source " + path);
    sourcePins[path] = sha256(sources[path].content);
  }
  const index = new Map(), astContracts = new Map(), astById = new Map();
  for (const [path, result] of Object.entries(output.sources ?? {})) {
    if (!result.ast) continue;
    require(Object.hasOwn(sources, path), "AST source absent from literal input");
    const walk = node => {
      if (!node || typeof node !== "object") return;
      if (node.nodeType === "ContractDefinition") {
        const fqn = path + ":" + node.name;
        require(!astContracts.has(fqn), "Duplicate AST FQN " + fqn);
        astContracts.set(fqn, { node, source: path, fqn });
        if (Number.isSafeInteger(node.id)) {
          require(!astById.has(node.id), "Duplicate contract AST identity");
          astById.set(node.id, { node, source: path, fqn });
        }
      }
      for (const value of Object.values(node)) {
        if (Array.isArray(value)) value.forEach(walk);
        else if (value && typeof value === "object") walk(value);
      }
    };
    walk(result.ast);
  }
  for (const [source, items] of Object.entries(contracts)) {
    sourcePath(source);
    require(Object.hasOwn(sourcePins, source), "Compiled contract lacks literal source");
    for (const [name, artifact] of Object.entries(items)) {
      const fqn = source + ":" + name; coordinate(fqn);
      require(!index.has(fqn), "Duplicate compiler FQN");
      index.set(fqn, { source, name, artifact, ast: astContracts.get(fqn) ?? null });
    }
  }
  const unresolved = copy(array(profile.unresolved ?? [], "profile.unresolved"));
  const note = (kind, details) => unresolved.push({ kind, ...details });
  function refs(value, label) {
    if (value === undefined) return;
    for (const ref of array(value, label)) {
      const path = typeof ref === "string" ? ref : ref?.path;
      require(typeof path === "string" && Object.hasOwn(sourcePins, path), label + " must reference literal compiler input");
      if (typeof ref === "object") {
        if (ref.sha256 !== undefined) require(ref.sha256 === sourcePins[path], "Source reference hash differs");
        if (ref.line !== undefined) require(Number.isSafeInteger(ref.line) && ref.line > 0 && ref.line <= sources[path].content.split("\n").length, "Source reference line out of bounds");
      }
    }
  }
  const seeds = array(profile.products, "profile.products"), selected = new Set(), seedMetadata = new Map();
  for (const row of seeds) {
    object(row, "product"); coordinate(row.fqn); nonempty(row.reason, "product reason");
    require(index.has(row.fqn), "Unknown selected compiler FQN " + row.fqn);
    require(!seedMetadata.has(row.fqn), "Duplicate FQN product alias " + row.fqn);
    refs(row.sourceRefs, "product sourceRefs");
    seedMetadata.set(row.fqn, copy(row)); selected.add(row.fqn);
  }
  require(selected.size > 0, "Explicit product selection is empty");
  const selectionMode = profile.selectionMode ?? "edge-closure";
  require(["edge-closure", "explicit-products"].includes(selectionMode), "Unknown selection mode");
  const edges = copy(array(profile.edges ?? [], "profile.edges")), edgeIdentities = new Set();
  for (const edge of edges) {
    object(edge, "edge"); coordinate(edge.from); coordinate(edge.to); nonempty(edge.kind, "edge kind");
    require(index.has(edge.from) && index.has(edge.to), "Dangling compiler FQN edge");
    if (edge.sourceRef !== undefined) refs([edge.sourceRef], "edge sourceRef");
    refs(edge.sourceRefs, "edge sourceRefs");
    const key = canonical(edge); require(!edgeIdentities.has(key), "Duplicate selection edge"); edgeIdentities.add(key);
  }
  let changed;
  do {
    changed = false;
    for (const edge of edges) if (selectionMode === "edge-closure" && selected.has(edge.from) && !selected.has(edge.to)) { selected.add(edge.to); changed = true; }
  } while (changed);
  for (const edge of edges) if (selectionMode === "edge-closure" && !selected.has(edge.from)) note("unreachable-profile-edge", { from: edge.from, to: edge.to, edgeKind: edge.kind });

  const roleDefinitions = array(genesis.entries, "genesis.entries");
  require(roleDefinitions.length === 37 && new Set(roleDefinitions.map(r => r.key)).size === 37
    && roleDefinitions.every(r => typeof r.key === "string" && r.key), "Expected all37 unique genesis roles");
  const roleIds = roleDefinitions.map(r => r.id).sort((a, b) => a - b);
  require(roleIds.every((id, i) => id === i + 1), "Genesis role IDs must be1..37");
  const mappings = new Map();
  for (const row of array(profile.roleMappings ?? [], "profile.roleMappings")) {
    object(row, "role mapping");
    require(Number.isSafeInteger(row.roleId) && row.roleId >= 1 && row.roleId <= 37 && !mappings.has(row.roleId), "Duplicate/unknown role mapping");
    const fqns = array(row.fqns, "role mapping FQNs");
    require(new Set(fqns).size === fqns.length, "Duplicate FQN role alias");
    for (const fqn of fqns) { coordinate(fqn); require(selected.has(fqn), "Dangling or unselected role FQN " + fqn); }
    nonempty(row.resolution, "role resolution");
    mappings.set(row.roleId, copy(row));
  }
  const roles = [...roleDefinitions].sort((a, b) => a.id - b.id).map(definition => {
    const mapping = mappings.get(definition.id) ?? { roleId: definition.id, fqns: [], resolution: "unresolved" };
    if (mapping.fqns.length === 0 || mapping.resolution !== "resolved") note("unresolved-role", { roleId: definition.id, resolution: mapping.resolution });
    return { ...copy(definition), mapping };
  });
  const entries = [], products = [], functionEntries = new Map();
  function entry(row) {
    const identity = { capture, fqn: row.fqn, kind: row.kind, signature: row.signature, selector: row.selector,
      abiSha256: row.abiSha256, sourceSha256: row.sourceSha256, ...(row.callbackId === undefined ? {} : { callbackId: row.callbackId, obligation: row.obligation }) };
    const result = { id: sha256(canonical(identity)), ...row, status: "uncovered" };
    entries.push(result);
    return result;
  }
  function provenance(item, selector, kind) {
    if (!item.ast) return [];
    const baseIds = item.ast.node.linearizedBaseContracts ?? [item.ast.node.id];
    const found = [];
    for (const baseId of baseIds) {
      const base = astById.get(baseId);
      if (!base) { note("missing-base-AST", { fqn: item.ast.fqn, nodeId: baseId ?? null }); continue; }
      for (const node of base.node.nodes ?? []) {
        if (!["FunctionDefinition", "VariableDeclaration"].includes(node.nodeType)) continue;
        if (kind === "function" ? typeof node.functionSelector !== "string" || "0x" + node.functionSelector.replace(/^0x/, "") !== selector
          : node.nodeType !== "FunctionDefinition" || node.kind !== kind) continue;
        found.push({ fqn: base.fqn, nodeId: node.id ?? null, nodeType: node.nodeType, src: node.src ?? null,
          visibility: node.visibility ?? null, implemented: node.nodeType === "VariableDeclaration" || node.body != null,
          sourceSha256: sourcePins[base.source] });
      }
    }
    return found;
  }
  for (const fqn of [...selected].sort(compare)) {
    const item = index.get(fqn), artifact = item.artifact;
    const abi = copy(array(artifact.abi, "compiler ABI " + fqn)), abiSha256 = sha256(canonical(abi)), sourceSha256 = sourcePins[item.source];
    const contractKind = item.ast?.node.contractKind ?? "unknown";
    require(["contract", "interface", "library", "unknown"].includes(contractKind), "Unknown compiler contract kind");
    if (contractKind === "unknown") note("missing-contract-AST", { fqn });
    if (item.ast?.node.abstract === true || contractKind === "interface") note("non-deployable-product", { fqn, contractKind });
    const methodIdentifiers = copy(object(artifact.evm?.methodIdentifiers ?? {}, "compiler method identifiers"));
    for (const [signature, selector] of Object.entries(methodIdentifiers)) {
      nonempty(signature, "compiler method signature");
      require(/^[a-fA-F0-9]{8}$/.test(selector), "Malformed compiler selector");
    }
    const productEntries = [], identities = new Set(), matchedMethodSignatures = new Set();
    for (let abiIndex = 0; abiIndex < abi.length; abiIndex++) {
      const row = abi[abiIndex];
      if (!["function", "receive", "fallback"].includes(row.type)) continue;
      require(["pure", "view", "nonpayable", "payable"].includes(row.stateMutability), "Missing ABI mutability");
      let signature, selector = null, selectorProvenance;
      if (row.type === "function") {
        let parsed = true;
        try { signature = functionSignature(row); } catch { signature = nominalSignature(row); parsed = false; }
        if (contractKind === "unknown" && parsed && !methodIdentifiers[signature]) {
          // ABI176 has no AST: tuple ABI alone cannot identify a library wire selector.
          selectorProvenance = "unresolved-contract-kind-selector";
          note("unresolved-contract-kind-selector", { fqn, signature });
        } else if (contractKind === "library" || !parsed) {
          const exact = methodIdentifiers[signature];
          selector = exact ? "0x" + exact.toLowerCase() : null;
          selectorProvenance = exact ? "compiler-methodIdentifiers" : "unresolved-library-selector";
          if (!exact) note("unresolved-library-selector", { fqn, signature });
        } else {
          const derived = keccakId(signature).slice(0, 10);
          const exact = methodIdentifiers[signature];
          if (exact) require("0x" + exact.toLowerCase() === derived, "Compiler/ABI selector differs");
          selector = derived;
          selectorProvenance = exact ? "compiler-methodIdentifiers-and-canonical-ABI" : "derived-canonical-ABI";
        }
      } else {
        signature = row.type + "()"; selectorProvenance = "selectorless-entrypoint";
        if (row.type === "receive") require(row.stateMutability === "payable", "Receive ABI must be payable");
        if (row.type === "fallback") require(["payable", "nonpayable"].includes(row.stateMutability), "Invalid fallback mutability");
      }
      if (row.type === "function" && selector && methodIdentifiers[signature]) matchedMethodSignatures.add(signature);
      const identity = row.type + ":" + signature;
      require(!identities.has(identity), "Duplicate ABI entrypoint " + fqn + ":" + signature); identities.add(identity);
      const declarations = provenance(item, selector, row.type);
      if (declarations.length === 0) note("unresolved-declaration", { fqn, signature });
      const call = entry({ fqn, kind: row.type, signature, selector, abiIndex, abiSha256, sourceSha256, mutability: row.stateMutability,
        contractKind, selectorProvenance, declarations, endpoint: "unknown", nativeValue: ["view", "pure"].includes(row.stateMutability)
          ? "read-only" : row.stateMutability === "payable" ? "method-specific" : "0" });
      productEntries.push(call.id);
      if (row.type === "function") functionEntries.set(fqn + ":" + signature, call);
    }
    // Nominal library method keys may describe the same functions as expanded
    // tuple ABI rows. Preserve each compiler signature without guessing that join.
    for (const signature of Object.keys(methodIdentifiers).sort(compare)) {
      if (matchedMethodSignatures.has(signature)) continue;
      const selector = "0x" + methodIdentifiers[signature].toLowerCase();
      const call = entry({ fqn, kind: "compiler-method", signature, selector, abiIndex: null, abiSha256, sourceSha256,
        mutability: null, contractKind, selectorProvenance: "compiler-methodIdentifiers-unmatched-ABI",
        declarations: provenance(item, selector, "function"), endpoint: "unknown", nativeValue: "unknown",
        representation: "unmatched-compiler-method-may-alias-ABI-entry" });
      productEntries.push(call.id);
      note("unmatched-compiler-method-ABI", { fqn, signature, selector, entryId: call.id });
    }
    // A same-selector overload collision is never silently collapsed.
    const selectors = new Map();
    for (const e of entries.filter(e => e.fqn === fqn && e.selector)) {
      if (selectors.has(e.selector)) note("selector-collision", { fqn, selector: e.selector, signatures: [selectors.get(e.selector), e.signature] });
      else selectors.set(e.selector, e.signature);
    }
    products.push({ fqn, source: item.source, name: item.name, contractKind, abstract: item.ast?.node.abstract ?? null,
      abiSha256, sourceSha256, abi, methodIdentifiers, astNodeId: item.ast?.node.id ?? null,
      selection: seedMetadata.get(fqn) ?? { fqn, reason: "explicit edge closure" }, entryIds: productEntries });
  }
  const callbackIds = new Set();
  for (const callback of array(profile.callbackObligations ?? [], "profile.callbackObligations")) {
    object(callback, "callback"); nonempty(callback.id, "callback identity");
    require(!callbackIds.has(callback.id), "Duplicate callback identity"); callbackIds.add(callback.id);
    refs(callback.sourceRefs, "callback sourceRefs");
    const signature = functionSignature("function " + nonempty(callback.signature, "callback signature"));
    require(signature === callback.signature, "Callback signature must be canonical");
    let base = null;
    if (callback.fqn !== null && callback.fqn !== undefined) {
      coordinate(callback.fqn); require(selected.has(callback.fqn), "Dangling callback FQN");
      base = functionEntries.get(callback.fqn + ":" + signature);
      require(base, "Callback absent from selected compiler ABI");
    } else {
      nonempty(callback.externalTarget, "external callback target");
      note("external-callback", { callbackId: callback.id, externalTarget: callback.externalTarget, signature });
    }
    entry({ fqn: base?.fqn ?? null, kind: "callback", callbackId: callback.id, signature, selector: base ? base.selector : keccakId(signature).slice(0, 10),
      abiSha256: base?.abiSha256 ?? null, sourceSha256: base?.sourceSha256 ?? null, mutability: base?.mutability ?? null,
      selectorProvenance: base?.selectorProvenance ?? "derived-external-interface-unverified", declarationEntryId: base?.id ?? null,
      obligation: copy(callback), endpoint: "unknown" });
  }
  const deployments = copy(array(deployment.instances, "deployment.instances")), deploymentIds = new Set(), addresses = new Set();
  for (const row of deployments) {
    object(row, "deployment instance");
    const identity = row.instance_id ?? row.id;
    if (row.instance_id !== undefined && row.id !== undefined) require(row.instance_id === row.id, "Conflicting deployment identity aliases");
    nonempty(identity, "deployment identity"); require(!deploymentIds.has(identity), "Duplicate deployment identity"); deploymentIds.add(identity);
    const fqn = row.fqn ?? (row.target?.source && row.target?.name ? row.target.source + ":" + row.target.name : null);
    if (row.fqn !== undefined && row.target !== undefined) require(row.target.source + ":" + row.target.name === row.fqn, "Conflicting deployment FQN aliases");
    coordinate(fqn); require(selected.has(fqn), "Dangling deployment FQN");
    if (row.address !== null && row.address !== undefined) {
      require(/^0x[0-9a-fA-F]{40}$/.test(row.address) && !/^0x0{40}$/i.test(row.address), "Invalid deployment address");
      const key = String(row.chainId ?? deployment.network?.chain_id ?? "unspecified") + ":" + row.address.toLowerCase();
      require(!addresses.has(key), "Duplicate deployment address alias"); addresses.add(key);
    } else note("unobserved-deployment-address", { instanceId: identity, fqn });
  }
  if (deployments.length === 0) note("no-deployment-instances", {});
  const allIds = entries.map(e => e.id);
  require(new Set(allIds).size === allIds.length, "Duplicate inventory entry identity");
  return freeze({ schemaVersion: 1, capture, sourcePins, products, roles, deployments,
    edges, selectionMode, selectionRoots: copy(array(profile.selectionRoots ?? [], "profile.selectionRoots")),
    entries: entries.sort((a, b) => compare(a.fqn ?? "", b.fqn ?? "") || compare(a.kind, b.kind) || compare(a.signature, b.signature) || compare(a.id, b.id)),
    unresolved: [...new Map(unresolved.map(row => [canonical(row), row])).values()].sort((a, b) => compare(canonical(a), canonical(b))) });
}
