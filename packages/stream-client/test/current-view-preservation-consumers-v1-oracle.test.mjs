import test from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { posix } from "node:path";
import { solidityImports } from "../scripts/generate-current-entropy-policy-succession-fixture.mjs";
import { readFileSync } from "node:fs";
import ts from "typescript";
import { AbiCoder, Interface, ParamType, id, keccak256, toUtf8Bytes } from "ethers";
import { fixture, compiledInterfaces } from "./current-view-preservation-consumers-v1-fixture.mjs";

function literalReader(url, cache = new Map()) {
  if (cache.has(url.href)) return cache.get(url.href);
  const source = ts.createSourceFile(url.href, readFileSync(url, "utf8"), ts.ScriptTarget.Latest, true);
  const declarations = new Map(), imported = new Map(), namespaces = new Map();
  const read = name => {
    if (imported.has(name)) {
      const entry = imported.get(name);
      return literalReader(entry.url, cache)(entry.name);
    }
    return value(declarations.get(name));
  };
  cache.set(url.href, read);
  for (const statement of source.statements) {
    if (ts.isVariableStatement(statement)) for (const entry of statement.declarationList.declarations) {
      if (ts.isIdentifier(entry.name)) declarations.set(entry.name.text, entry.initializer);
    }
    if (ts.isImportDeclaration(statement) && statement.moduleSpecifier.text.startsWith(".")) {
      const target = new URL(statement.moduleSpecifier.text.replace(/\.js$/, ".ts"), url);
      const bindings = statement.importClause?.namedBindings;
      if (bindings && ts.isNamespaceImport(bindings)) namespaces.set(bindings.name.text, target);
      else if (bindings && ts.isNamedImports(bindings)) for (const entry of bindings.elements) {
        imported.set(entry.name.text, { url: target, name: entry.propertyName?.text ?? entry.name.text });
      }
    }
  }
  function value(node, locals = new Map()) {
    if (!node) throw Error(`Missing literal declaration in ${url.pathname}`);
    if (ts.isAsExpression(node) || ts.isSatisfiesExpression(node) || ts.isParenthesizedExpression(node)) return value(node.expression, locals);
    if (ts.isStringLiteral(node) || ts.isNoSubstitutionTemplateLiteral(node)) return node.text;
    if (ts.isBigIntLiteral(node)) return BigInt(node.text.replace(/n$/, "").replaceAll("_", ""));
    if (ts.isNumericLiteral(node)) return Number(node.text);
    if (ts.isPrefixUnaryExpression(node) && node.operator === ts.SyntaxKind.MinusToken) return -value(node.operand, locals);
    if (ts.isBinaryExpression(node) && node.operatorToken.kind === ts.SyntaxKind.PlusToken) {
      const left = value(node.left, locals), right = value(node.right, locals);
      assert.equal(typeof left, "string");
      assert.equal(typeof right, "string");
      return left + right;
    }
    if (ts.isObjectLiteralExpression(node)) return Object.fromEntries(node.properties.map(property => {
      assert.ok(ts.isPropertyAssignment(property), "literal object property");
      return [property.name.text, value(property.initializer, locals)];
    }));
    if (ts.isIdentifier(node)) return locals.has(node.text) ? locals.get(node.text) : read(node.text);
    if (ts.isPropertyAccessExpression(node) && ts.isIdentifier(node.expression) && namespaces.has(node.expression.text)) {
      return literalReader(namespaces.get(node.expression.text), cache)(node.name.text);
    }
    if (ts.isPropertyAccessExpression(node)) {
      const object = value(node.expression, locals);
      assert.ok(object !== null && typeof object === "object" && Object.hasOwn(object, node.name.text), "own literal property");
      return object[node.name.text];
    }
    if (ts.isTemplateExpression(node)) return node.head.text + node.templateSpans.map(span => value(span.expression, locals) + span.literal.text).join("");
    if (ts.isArrayLiteralExpression(node)) return node.elements.flatMap(element => ts.isSpreadElement(element) ? value(element.expression, locals) : [value(element, locals)]);

    if (ts.isCallExpression(node) && ts.isPropertyAccessExpression(node.expression)
      && node.expression.name.text === "map" && node.arguments.length === 1) {
      const fn = node.arguments[0];
      assert.ok(ts.isArrowFunction(fn) && fn.parameters.length === 1 && ts.isIdentifier(fn.parameters[0].name));
      const name = fn.parameters[0].name.text;
      return value(node.expression.expression, locals).map(item => value(fn.body, new Map([...locals, [name, item]])));
    }
    if (ts.isCallExpression(node) && ts.isPropertyAccessExpression(node.expression) && node.expression.name.text === "slice") {
      const input = value(node.expression.expression, locals), args = node.arguments.map(argument => value(argument, locals));
      assert.equal(typeof input, "string");
      assert.ok(args.length <= 2 && args.every(Number.isInteger));
      return input.slice(...args);
    }
    if (ts.isCallExpression(node) && node.expression.getText(source) === "Object.freeze") return value(node.arguments[0]);
    if (ts.isNewExpression(node) && node.expression.getText(source) === "Interface") return value(node.arguments[0]);
    throw Error(`Nonliteral ABI expression in ${url.pathname}: ${node.getText(source)}`);
  }
  return read;
}

function sameFields(actual, expected, signature, tuple = false) {
  assert.ok(Array.isArray(actual) && Array.isArray(expected), signature + " parameter arrays");
  assert.equal(actual.length, expected.length, signature);
  for (let i = 0; i < expected.length; i++) {
    const a = actual[i], e = expected[i];
    assert.equal(a.format("sighash"), e.format("sighash"), signature);
    if (tuple) assert.equal(a.name, e.name, signature + "/" + e.name);
    if (e.baseType === "array") sameFields([a.arrayChildren], [e.arrayChildren], signature);
    if (e.baseType === "tuple") sameFields(a.components, e.components, signature, true);
  }
}

function compatibleFragment(actual, original) {
  assert.equal(actual.type, original.type);
  sameFields(actual.inputs, original.inputs, actual.format("sighash"));
  if (actual.type === "function") {
    sameFields(actual.outputs, original.outputs, actual.format("sighash"));
    assert.equal(actual.stateMutability, original.stateMutability);
  } else if (actual.type === "event") {
    assert.deepEqual(actual.inputs.map(p => Boolean(p.indexed)), original.inputs.map(p => Boolean(p.indexed)));
    assert.equal(actual.anonymous, original.anonymous);
  }
}

function libraryValue(parameter) {
  assert.ok(!/\bstorage\b/.test(parameter.internalType ?? ""), "memory-only library values");
  let type = parameter.type;
  if (parameter.internalType?.startsWith("enum ")) type = "uint8" + (type.match(/(\[[0-9]*\])+$/)?.[0] ?? "");
  else if (parameter.internalType?.startsWith("contract ")) type = "address" + (type.match(/(\[[0-9]*\])+$/)?.[0] ?? "");
  return { ...parameter, type, ...(parameter.components ? { components: parameter.components.map(libraryValue) } : {}) };
}



const sha = value => createHash("sha256").update(value).digest("hex");

test("VIEW consumer witness binds exact ABI157 and preserves historical fixture identities", () => {
  assert.equal(fixture.profile, "current-view-preservation-consumers-v1");
  assert.equal(fixture.sourceCommit, "a2973d360f6ab18881c04d58193f855704ec56d3");
  assert.equal(fixture.sourceTree, "f66d6a195a9e59b31cfe9ad8bd819e29054298bd");
  assert.equal(fixture.compilerVersion, "0.8.19");
  assert.equal(fixture.sourceCount, 4059);
  assert.equal(fixture.literalBytes, 48186075);
  assert.equal(fixture.inputSha256, "bdeb13c7467525241cfdc4fffe97e11aefbbd310972606eefe1ebebe47358234");
  assert.equal(fixture.outputSha256, "b6b473ed08be283b2efba661132193670d8f2ff2d39e06cd1bb6f31729573da6");
  const { sha256, ...bridge } = fixture.committedSourceBridge;
  assert.equal(sha256, "32d8ad5e406ff13d7558e2d3a29fe44bb9f6108b0644cece83b45e1685d08a6a");
  assert.equal(sha(JSON.stringify(bridge, null, 2) + "\n"), sha256);
  assert.equal(bridge.commit, fixture.sourceCommit);
  assert.equal(bridge.sources, 4059);
  assert.equal(Object.keys(bridge.committedBlobSHA256).length, 4059);
  assert.deepEqual(bridge.mismatches, []);
  assert.match(fixture.sourceBinding, /no line-ending normalization/);
  assert.match(fixture.qualification, /genuine retrieval-enabled VIEW inventory and Bundle hosts/);
  assert.match(fixture.qualification, /does not establish actual native\/Safe execution/);
  for (const [name, hash] of [
    ["current-view-retrieval-v1-abi.json", "5acda86528a3294533ac2cea49389fc859f5f50063195f05836d9f5bb88002c7"],
    ["current-preservation-v2-abi.json", "6425f868f20cffa0da23dea20aa771a870fa4649ade04fe7229141bb15a4b7dc"],
    ["current-authority-preservation-archive-v1-abi.json", "c937f7d585f2192ecfa730125246cc56f5e8cfa64b638cdef698f1116883e62b"],
  ]) assert.equal(sha(readFileSync(new URL("./fixtures/" + name, import.meta.url))), hash, name);
});

test("VIEW consumer compiler ABIs retain every ordinary and nominal selector with the correct declaration kind", () => {
  assert.equal(Object.keys(fixture.abis).length, 150);
  assert.equal(Object.keys(fixture.libraryAbis).length, 153);
  let ordinary = 0, nominal = 0;
  for (const [name, iface] of Object.entries(compiledInterfaces)) {
    const selection = fixture.selections[name];
    assert.deepEqual(selection, { source: selection.source, contract: name, full: true });
    const functions = iface.fragments.filter(f => f.type === "function");
    assert.equal(functions.length, Object.keys(fixture.methodIdentifiers[name]).length, name);
    const text = fixture.sourceTexts[selection.source];
    assert.match(text, new RegExp("\\b(?:contract|interface)\\s+" + name + "\\b"));
    for (const fn of functions) {
      assert.equal(fixture.methodIdentifiers[name][fn.format("sighash")], fn.selector.slice(2), name);
      ordinary++;
    }
  }
  for (const [name, identifiers] of Object.entries(fixture.libraryMethodIdentifiers)) {
    const selection = fixture.librarySelections[name];
    assert.equal(selection.nominal, true);
    assert.equal(selection.full, true);
    assert.equal(compiledInterfaces[name], undefined);
    assert.match(fixture.sourceTexts[selection.source], new RegExp("\\blibrary\\s+" + name + "\\b"));
    for (const [signature, selector] of Object.entries(identifiers)) {
      assert.equal(id(signature).slice(2, 10), selector, name + "." + signature);
      nominal++;
    }
  }
  assert.equal(ordinary, 1102);
  assert.equal(nominal, 277);
});

test("both genuine VIEW consumers have their complete exact-byte imported closure and same-commit interpretation documents", () => {
  const visited = new Set();
  function visit(path) {
    if (visited.has(path)) return;
    visited.add(path);
    const source = fixture.sourceTexts[path];
    assert.equal(typeof source, "string", path);
    assert.equal(sha(source), fixture.sourceHashes[path], path);
    assert.equal(sha(source), fixture.committedSourceBridge.committedBlobSHA256[path], path);
    for (const imported of solidityImports(source)) {
      visit(imported.startsWith(".") ? posix.normalize(posix.join(posix.dirname(path), imported)) : imported);
    }
  }
  visit(fixture.selections.StreamViewPreservationRenderCriticalInventoryV1.source);
  visit(fixture.selections.StreamViewPreservationBundleArchiveCoverageV1.source);
  assert.equal(visited.size, 263);
  assert.deepEqual([...visited].sort(), Object.keys(fixture.sourceTexts).sort());
  assert.equal(Object.values(fixture.sourceTexts).reduce((n, source) => n + Buffer.byteLength(source), 0), 1287901);
  for (const selected of [...Object.values(fixture.selections), ...Object.values(fixture.librarySelections)]) {
    assert.ok(visited.has(selected.source), selected.contract);
  }
  assert.equal(Object.keys(fixture.documents).length, 4);
  for (const document of Object.values(fixture.documents)) {
    assert.equal(sha(document.text), document.sha256);
    assert.equal(Buffer.byteLength(document.text), document.byteLength);
  }
});

const profiles = [
  {
    module: "current-view-preservation-inventory-v1",
    prefix: "CURRENT_VIEW_PRESERVATION_INVENTORY_V1",
    contract: "StreamViewPreservationRenderCriticalInventoryV1",
    writes: ["appendArtwork", "appendDefinition", "appendIntent", "appendIntentWaiver",
      "appendInterview", "appendInterviewWaiver", "appendNative", "appendPreservationAdmission",
      "appendReference", "appendRenderer", "appendRights", "appendRootAuthorization",
      "appendTokenOutput", "appendWork", "beginInventory", "sealInventory"],
  },
  {
    module: "current-view-preservation-bundle-v1",
    prefix: "CURRENT_VIEW_PRESERVATION_BUNDLE_V1",
    contract: "StreamViewPreservationBundleArchiveCoverageV1",
    writes: ["beginCoverage", "beginRefresh", "coverEmptySegment", "coverNext",
      "coverRetrievalNext", "refreshNext"],
  },
];

test("consumer profiles use the distinct original VIEW domains", async () => {
  const inventory = await import("../dist/current-view-preservation-inventory-v1.js");
  const bundle = await import("../dist/current-view-preservation-bundle-v1.js");
  const source = fixture.sourceTexts["smart-contracts/interfaces/stream/preservation/StreamViewPreservationRenderCriticalTypesV1.sol"];
  const host = fixture.sourceTexts[fixture.selections.StreamViewPreservationBundleArchiveCoverageV1.source];
  const inventoryDomain = /\bPROFILE\s*=\s*keccak256\("([^"]+)"\)/.exec(source)?.[1];
  const bundleDomain = /\bPROFILE\s*=\s*keccak256\("([^"]+)"\)/.exec(host)?.[1];
  assert.equal(inventoryDomain, "6529STREAM_VIEW_PRESERVATION_RENDER_CRITICAL_RETRIEVAL_V1");
  assert.equal(bundleDomain, "6529STREAM_VIEW_PRESERVATION_BUNDLE_IMMUTABLE_STOP_AGGREGATE_V1");
  assert.equal(inventory.CURRENT_VIEW_PRESERVATION_INVENTORY_V1_PROFILE, id(inventoryDomain));
  assert.equal(bundle.CURRENT_VIEW_PRESERVATION_BUNDLE_V1_PROFILE, id(bundleDomain));
});

test("both VIEW client ABIs retain every original ordinary write, read, event and error", () => {
  const surface = iface => iface.fragments.filter(f => !["constructor", "fallback", "receive"].includes(f.type))
    .map(f => f.type + ":" + f.format("sighash")).sort();
  for (const profile of profiles) {
    const url = new URL("../src/" + profile.module + ".ts", import.meta.url);
    const actual = new Interface(literalReader(url)(profile.prefix + "_ABI"));
    const original = compiledInterfaces[profile.contract];
    assert.deepEqual(surface(actual), surface(original), profile.contract);
    for (const fragment of actual.fragments) {
      const witness = original.fragments.find(f => f.type === fragment.type && f.format("sighash") === fragment.format("sighash"));
      assert.ok(witness, fragment.format("sighash"));
      compatibleFragment(fragment, witness);
    }
    assert.deepEqual(actual.fragments.filter(f => f.type === "function" && !f.constant).map(f => f.name).sort(), profile.writes);
  }
  // This original interface deliberately omits the six ordinary consumer writes.
  assert.equal(compiledInterfaces.IStreamViewPreservationBundleArchiveCoverageV1.fragments
    .filter(f => f.type === "function" && !f.constant).length, 0);
});

test("VIEW consumer tuple codecs retain recursive original compiler fields and widths", () => {
  const witnesses = [];
  function visit(value) {
    if (/\bstorage\b/.test(value.internalType ?? "")) return;
    let p = ParamType.from(libraryValue(value), true);
    while (p.baseType === "array") p = p.arrayChildren;
    if (p.baseType === "tuple") witnesses.push(p);
    value.components?.forEach(visit);
  }
  for (const abi of [...Object.values(fixture.abis), ...Object.values(fixture.libraryAbis)]) for (const fragment of abi) {
    fragment.inputs?.forEach(visit);
    fragment.outputs?.forEach(visit);
  }
  for (const profile of profiles) {
    const url = new URL("../src/" + profile.module + ".ts", import.meta.url);
    const source = readFileSync(url, "utf8"), literal = literalReader(url);
    const names = [...source.matchAll(new RegExp("export const (" + profile.prefix + "_\\w+_TUPLE) =", "g"))];
    assert.ok(names.length > 0, profile.module);
    for (const [, name] of names) {
      const actual = ParamType.from(literal(name));
      assert.ok(witnesses.some(original => {
        try { sameFields([actual], [original], name); return true; } catch { return false; }
      }), name + " lacks exact recursive compiler fields");
    }
  }
});

test("nine memory-only read workers preserve nominal selectors and ordinary structural return layouts", () => {
  const expected = new Set([
    "StreamViewPreservationRenderCriticalSourceReadsV1.current",
    "StreamViewRetrievalBindingV1.requireInventory",
    "StreamBundleArchiveReads.environment",
    "StreamViewPreservationArchiveReadsV1.admit",
    "StreamViewPreservationArchiveReadsV1.current",
    "StreamViewRetrievalConsumerV1.environment",
    "StreamViewRetrievalConsumerV1.context",
    "StreamViewRetrievalConsumerV1.admit",
    "StreamViewRetrievalConsumerV1.current",
  ]);
  const seen = new Set();
  for (const profile of profiles) {
    const url = new URL("../src/" + profile.module + "-workflow.ts", import.meta.url);
    const workers = literalReader(url)("workers");
    for (const worker of Object.values(workers)) {
      const key = worker.contract + "." + worker.method;
      assert.ok(expected.has(key) && !seen.has(key), key);
      seen.add(key);
      const candidates = fixture.libraryAbis[worker.contract]
        .filter(f => f.type === "function" && f.name === worker.method);
      assert.equal(candidates.length, 1, key);
      const original = candidates[0];
      assert.equal(original.stateMutability, "view", key);
      const selectors = Object.entries(fixture.libraryMethodIdentifiers[worker.contract])
        .filter(([signature]) => signature.startsWith(worker.method + "("));
      assert.equal(selectors.length, 1, key);
      assert.equal(worker.selector, "0x" + selectors[0][1], key);
      assert.equal(worker.selector, id(selectors[0][0]).slice(0, 10), key);
      sameFields(worker.inputs.map(value => ParamType.from(value)),
        original.inputs.map(value => ParamType.from(libraryValue(value))), key + " inputs");
      sameFields(worker.outputs.map(value => ParamType.from(value)),
        original.outputs.map(value => ParamType.from(libraryValue(value))), key + " outputs");
      assert.equal(fixture.selections[worker.contract], undefined, key + " is never an ordinary wallet ABI");
    }
  }
  assert.deepEqual([...seen].sort(), [...expected].sort());
});

const coder = AbiCoder.defaultAbiCoder();
const hash = (types, values) => keccak256(coder.encode(types, values));
const ZERO = "0x" + "00".repeat(32);
function originalDomain(path, value) {
  assert.ok(fixture.sourceTexts[path]?.includes('keccak256("' + value + '")'), value + " original domain");
  return id(value);
}
function exampleFactory() {
  let seed = 1;
  function example(p) {
    if (p.baseType === "array") return Array.from({ length: p.arrayLength < 0 ? 0 : p.arrayLength }, () => example(p.arrayChildren));
    if (p.baseType === "tuple") return Object.fromEntries(p.components.map(c => [c.name, example(c)]));
    if (p.type === "address") return "0x" + (seed++).toString(16).padStart(40, "0");
    if (p.type === "bytes32") return id("independent-VIEW-consumer-vector-" + seed++);
    if (p.type === "bytes") return "0x123456";
    if (p.type === "string") return "https://example.test/literal/%2f?q=1#image";
    if (p.type === "bool") return false;
    const match = /^uint(\d+)$/.exec(p.type);
    assert.ok(match, p.type);
    if (p.name === "scopeType") return 4n;
    if (p.name === "tokenId" || p.type === "uint8") return 0n;
    return (1n << BigInt(Number(match[1]) - 1)) + BigInt(seed++);
  }
  return example;
}

test("original VIEW context, plan and nested evidence preimages preserve complete fields and original intent enum", async () => {
  const client = await import("../dist/current-view-preservation-inventory-v1.js");
  const host = compiledInterfaces.StreamViewPreservationRenderCriticalInventoryV1;
  const contextType = host.getFunction("sourceContext").outputs[0];
  const evidenceType = host.getFunction("inventoryEvidence").outputs[0];
  const progressType = host.getFunction("plan").outputs[0].components.find(p => p.name === "progress");
  const dependencyType = host.getFunction("dependencies").outputs[0];
  const example = exampleFactory(), context = example(contextType), dependencies = example(dependencyType);
  const progress = example(progressType), evidence = example(evidenceType);
  const coordinates = { chainId: dependencies.chainId, core: dependencies.targets[0], inventory: "0x0000000000000000000000000000000000000abc" };
  const dependencyHash = hash([dependencyType], [dependencies]);
  assert.equal(client.currentViewPreservationInventoryV1DependencyHash(dependencies), dependencyHash);
  assert.equal(client.currentViewPreservationInventoryV1ContextHash(context), hash([contextType], [context]));
  const statePath = "smart-contracts/domains/preservation/StreamViewPreservationRenderCriticalStateV1.sol";
  const hostPath = fixture.selections.StreamViewPreservationRenderCriticalInventoryV1.source;
  const planDomain = originalDomain(statePath, "6529STREAM_VIEW_PRESERVATION_RENDER_CRITICAL_PLAN_V1");
  const evidenceDomain = originalDomain(hostPath, "6529STREAM_VIEW_PRESERVATION_RENDER_CRITICAL_EVIDENCE_V1");
  const plan = value => hash(["bytes32", "uint256", "address", "bytes32", contextType],
    [planDomain, coordinates.chainId, coordinates.inventory, dependencyHash, value]);
  assert.equal(client.currentViewPreservationInventoryV1PlanId(coordinates, dependencyHash, context), plan(context));
  const changed = { ...context, sourceContextHash: id("different exact checkpoint context") };
  assert.notEqual(plan(changed), plan(context));
  assert.equal(client.currentViewPreservationInventoryV1PlanId(coordinates, dependencyHash, changed), plan(changed));
  const evidenceHash = value => hash(["bytes32", "uint256", "address", "bytes32", evidenceType],
    [evidenceDomain, coordinates.chainId, coordinates.inventory, dependencyHash,
      { ...value, inventory: { ...value.inventory, renderCriticalEvidenceHash: ZERO } }]);
  assert.equal(client.currentViewPreservationInventoryV1EvidenceHash(coordinates, dependencyHash, evidence), evidenceHash(evidence));
  assert.equal(client.currentViewPreservationInventoryV1EvidenceHash(coordinates, dependencyHash,
    { ...evidence, inventory: { ...evidence.inventory, renderCriticalEvidenceHash: id("ignored self hash") } }), evidenceHash(evidence));
  const selection = fixture.sourceTexts[fixture.selections.IStreamConservationRecordSelection.source];
  const enumNames = /enum RecordKind\s*\{([^}]+)\}/.exec(selection)?.[1].split(",").map(s => s.trim());
  assert.deepEqual(enumNames, ["INTENT", "INTENT_WAIVER", "INTERVIEW"]);
  for (const kind of [0n, 1n]) {
    const c = { ...context, conservation: { ...context.conservation, record: { ...context.conservation.record, kind } } };
    const expected = {
      scope: c.scope,
      inventory: {
        planId: plan(c), collectionId: c.scope.collectionId, scopeSubject: c.subject, artistId: c.artistId,
        originals: {
          rootRecordHash: c.rootRecordHash, snapshotRecordHash: c.snapshot.recordHash,
          referenceRenderRecordHash: c.referenceRender.observation.recordHash,
          intentRecordHash: kind === 0n ? c.conservation.record.recordHash : ZERO,
          intentWaiverRecordHash: kind === 1n ? c.conservation.record.recordHash : ZERO,
          interviewEvidenceHash: c.interviewEvidenceHash,
          rightsStatementRecordHash: c.descriptions.rightsStatementRecordHash,
          workDescriptionRecordHash: c.descriptions.workDescriptionRecordHash,
        },
        sourceContextHash: progress.sourceContextHash, tokenInventoryHash: c.tokenInventoryHash,
        tokenCount: c.tokenCount, segmentCount: progress.segmentCount, itemCount: progress.itemCount,
        segmentChainHash: progress.segmentChainHash, renderCriticalEvidenceHash: ZERO,
      },
    };
    expected.inventory.renderCriticalEvidenceHash = evidenceHash(expected);
    const actual = client.currentViewPreservationInventoryV1Evidence(coordinates, dependencyHash, c, progress);
    assert.equal(coder.encode([evidenceType], [actual]), coder.encode([evidenceType], [expected]), "original kind " + kind);
  }
});

test("original Bundle environment, coverage, refresh and observation domains retain full widths and exact self-hash projection", async () => {
  const client = await import("../dist/current-view-preservation-bundle-v1.js");
  const host = compiledInterfaces.StreamViewPreservationBundleArchiveCoverageV1;
  const inventoryHost = compiledInterfaces.StreamViewPreservationRenderCriticalInventoryV1;
  const dependencyType = host.getFunction("dependencies").outputs[0];
  const evidenceType = host.getFunction("bundleEvidence").outputs[0];
  const inventoryType = inventoryHost.getFunction("inventoryEvidence").outputs[0];
  const admissionType = host.getFunction("admittedItem").outputs[1];
  const example = exampleFactory(), dependencies = example(dependencyType);
  const evidence = example(evidenceType), inventory = example(inventoryType), admission = example(admissionType);
  const coordinates = { chainId: dependencies.chainId, core: dependencies.targets[0], bundle: "0x0000000000000000000000000000000000000def" };
  const dependencyHash = hash([dependencyType], [dependencies]);
  const originalPath = "smart-contracts/domains/preservation/StreamBundleArchiveReads.sol";
  const consumerPath = "smart-contracts/domains/preservation/StreamViewRetrievalConsumerV1.sol";
  const hostPath = fixture.selections.StreamViewPreservationBundleArchiveCoverageV1.source;
  const epoch = (1n << 64n) - 1n, revision = 0n;
  const onchainHash = id("onchain environment"), externalHash = id("external environment");
  const base = hash(["bytes32", dependencyType, "bytes32", "uint64", "bytes32", "uint64"],
    [originalDomain(originalPath, "6529STREAM_BUNDLE_IMMUTABLE_STOP_ENVIRONMENT_V1"), dependencies,
      onchainHash, epoch, externalHash, revision]);
  assert.equal(client.currentViewPreservationBundleV1BaseEnvironmentHash(dependencies, onchainHash, epoch, externalHash, revision), base);
  const witness = "0x0000000000000000000000000000000000000123", codeHash = id("companion runtime");
  const scopeType = evidenceType.components.find(p => p.name === "scope");
  const environment = (scope, revocationEpoch) => hash(["bytes32", "bytes32", "address", "bytes32", scopeType, "uint64"],
    [originalDomain(consumerPath, "6529STREAM_VIEW_RETRIEVAL_ARCHIVE_ENVIRONMENT_V1"), base, witness, codeHash, scope, revocationEpoch]);
  for (const revocationEpoch of [0n, epoch]) assert.equal(
    client.currentViewPreservationBundleV1EnvironmentHash(base, witness, codeHash, evidence.scope, revocationEpoch), environment(evidence.scope, revocationEpoch));
  const env = environment(evidence.scope, epoch), plan = inventory.inventory.planId;
  const refresh = hash(["bytes32", "uint256", "address", "bytes32", "bytes32", "bytes32"],
    [originalDomain(hostPath, "6529STREAM_VIEW_PRESERVATION_BUNDLE_REFRESH_V1"), coordinates.chainId,
      coordinates.bundle, dependencyHash, plan, env]);
  assert.equal(client.currentViewPreservationBundleV1RefreshId(coordinates, dependencyHash, plan, env), refresh);
  const covered = hash(["bytes32", "bytes32", "bytes32", "uint64", "bytes32", admissionType],
    [originalDomain(hostPath, "6529STREAM_VIEW_PRESERVATION_BUNDLE_COVERED_ITEM_V1"), ZERO, plan, epoch, id("item"), admission]);
  assert.equal(client.currentViewPreservationBundleV1CoveredItemChain(ZERO, plan, epoch, id("item"), admission), covered);
  const observation = hash(["bytes32", "bytes32", "uint64", "bytes32", "bytes32"],
    [originalDomain(hostPath, "6529STREAM_VIEW_PRESERVATION_BUNDLE_CURRENT_OBSERVATION_V1"), ZERO, epoch, id("item"), id("current pair")]);
  assert.equal(client.currentViewPreservationBundleV1ObservationChain(ZERO, epoch, id("item"), id("current pair")), observation);
  const coverage = hash(["bytes32", "uint256", "address", "bytes32", "bytes32", inventoryType, evidenceType],
    [originalDomain(hostPath, "6529STREAM_VIEW_PRESERVATION_BUNDLE_ARCHIVE_COVERAGE_V1"), coordinates.chainId,
      coordinates.bundle, dependencyHash, originalDomain(hostPath, "6529STREAM_VIEW_PRESERVATION_BUNDLE_IMMUTABLE_STOP_AGGREGATE_V1"),
      inventory, { ...evidence, coverage: { ...evidence.coverage, bundleCoverageHash: ZERO } }]);
  assert.equal(client.currentViewPreservationBundleV1CoverageHash(coordinates, dependencyHash, inventory, evidence), coverage);
  assert.equal(client.currentViewPreservationBundleV1CoverageHash(coordinates, dependencyHash, inventory,
    { ...evidence, coverage: { ...evidence.coverage, bundleCoverageHash: id("another self hash") } }), coverage);
});

test("retrieval admission and current observation wrap the exact witness, configuration, source and retained receipt", async () => {
  const client = await import("../dist/current-view-preservation-bundle-v1.js");
  const witnessInterface = compiledInterfaces.IStreamViewRetrievalWitnessV1;
  const configurationType = witnessInterface.getFunction("configuration").outputs[0];
  const [sourceType, receiptType] = witnessInterface.getFunction("requireCorrespondence").outputs;
  const example = exampleFactory(), configuration = example(configurationType);
  const source = example(sourceType), receipt = example(receiptType);
  const witness = "0x0000000000000000000000000000000000000321", codeHash = id("original companion code");
  const originalBundle = id("original full Archive admission"), pair = id("fresh fixity on original pair");
  const consumerPath = "smart-contracts/domains/preservation/StreamViewRetrievalConsumerV1.sol";
  const witnessTypesPath = "smart-contracts/interfaces/stream/preservation/StreamViewRetrievalWitnessTypesV1.sol";
  const configHash = hash(["bytes32", configurationType],
    [originalDomain(witnessTypesPath, "6529STREAM_VIEW_ATTRIBUTED_RETRIEVAL_V1"), configuration]);
  const wrapped = hash(["bytes32", "bytes32", "address", "bytes32", "bytes32", "bytes32", "bytes32"],
    [originalDomain(consumerPath, "6529STREAM_VIEW_RETRIEVAL_ADMITTED_BUNDLE_V1"), originalBundle, witness, codeHash,
      configHash, receipt.recordHash, receipt.payloadHash]);
  assert.equal(client.currentViewPreservationBundleV1AdmittedBundleHash(originalBundle, witness, codeHash, configuration, receipt.recordHash, receipt.payloadHash), wrapped);
  const observation = value => hash(["bytes32", sourceType, receiptType, "bytes32"],
    [originalDomain(consumerPath, "6529STREAM_VIEW_RETRIEVAL_CURRENT_OBSERVATION_V1"), value, receipt, pair]);
  assert.equal(client.currentViewPreservationBundleV1CurrentObservationHash(source, receipt, pair), observation(source));
  const changed = { ...source, checkpointContextHash: id("changed checkpoint context") };
  assert.notEqual(observation(source), observation(changed));
  assert.equal(client.currentViewPreservationBundleV1CurrentObservationHash(changed, receipt, pair), observation(changed));
});
