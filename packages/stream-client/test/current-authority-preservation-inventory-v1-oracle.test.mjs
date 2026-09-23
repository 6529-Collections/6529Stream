import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import ts from "typescript";
import { Interface, ParamType, id, keccak256, toUtf8Bytes } from "ethers";
import { fixture, compiledInterfaces } from "./current-preservation-v2-fixture.mjs";

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

const pureUrl = new URL("../src/current-authority-preservation-inventory-v1.ts", import.meta.url);
const workflowUrl = new URL("../src/current-authority-preservation-inventory-v1-workflow.ts", import.meta.url);
const readPure = literalReader(pureUrl);
const readWorkflow = literalReader(workflowUrl);

test("current-authority inventory ABIs match both concrete hosts and all nineteen ordinary writes", () => {
  const common = ["beginInventory", "appendNative", "appendReference", "appendWork", "appendRights",
    "appendIntent", "appendIntentWaiver", "appendInterview", "appendInterviewWaiver",
    "appendRootAuthorization", "appendDefinition", "appendTokenPreservation", "appendOriginRuntime", "sealInventory"];
  for (const [suffix, name, tokens] of [
    ["COLLECTION", "StreamCurrentAuthorityPreservationPolicyRenderCriticalInventoryV1",
      ["appendToken", "appendScript", "appendLibrary", "appendRenderer", "appendCurrentProfile"]],
    ["SCOPED", "StreamCurrentAuthorityScopedPreservationPolicyRenderCriticalInventoryV1",
      ["appendTokenOutput", "appendTokenScript", "appendTokenLibrary", "appendTokenRenderer", "appendTokenCitation"]],
  ]) {
    const actual = new Interface(readPure(`CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_${suffix}_ABI`));
    const original = compiledInterfaces[name];
    assert.ok(original, name);
    for (const fragment of actual.fragments) {
      const witness = original.fragments.find(candidate => candidate.type === fragment.type
        && candidate.format("sighash") === fragment.format("sighash"));
      assert.ok(witness, name + ":" + fragment.format("sighash"));
      compatibleFragment(fragment, witness);
      if (fragment.type === "function") {
        assert.equal(fixture.methodIdentifiers[name][fragment.format("sighash")], fragment.selector.slice(2));
      }
    }
    const writes = iface => iface.fragments.filter(fragment => fragment.type === "function" && !fragment.constant)
      .map(fragment => fragment.name).sort();
    assert.deepEqual(writes(actual), [...common, ...tokens].sort());
    assert.deepEqual(writes(actual), writes(original));
    assert.equal(writes(actual).length, 19);
    const events = iface => iface.fragments.filter(fragment => fragment.type === "event")
      .map(fragment => fragment.format("sighash")).sort();
    assert.deepEqual(events(actual), events(original));
  }
});

test("inventory supporting ordinary reads retain compiler outputs and mutability", () => {
  const source = ts.createSourceFile(workflowUrl.href, readFileSync(workflowUrl, "utf8"), ts.ScriptTarget.Latest, true);
  const names = source.statements.filter(ts.isVariableStatement).flatMap(statement =>
    [...statement.declarationList.declarations].filter(entry => ts.isIdentifier(entry.name)
      && entry.initializer && ts.isNewExpression(entry.initializer)
      && entry.initializer.expression.getText(source) === "Interface").map(entry => entry.name.text));
  assert.ok(names.length >= 4);
  let count = 0;
  for (const name of names) for (const fragment of new Interface(readWorkflow(name)).fragments) {
    const witnesses = Object.values(compiledInterfaces).flatMap(iface => iface.fragments.filter(original =>
      original.type === fragment.type && original.format("sighash") === fragment.format("sighash")));
    assert.ok(witnesses.some(original => {
      try { compatibleFragment(fragment, original); return true; } catch { return false; }
    }), name + ":" + fragment.format("full"));
    count++;
  }
  assert.ok(count >= names.length);
  const hosts = ["StreamCurrentAuthorityPreservationPolicyRenderCriticalInventoryV1",
    "StreamCurrentAuthorityScopedPreservationPolicyRenderCriticalInventoryV1"].map(name => compiledInterfaces[name]);
  function visit(node) {
    if (ts.isCallExpression(node) && ts.isIdentifier(node.expression) && node.expression.text === "read"
      && node.arguments[2] && ts.isStringLiteral(node.arguments[2])) {
      const method = node.arguments[2].text;
      assert.ok(hosts.some(iface => iface.getFunction(method)), "Literal host read is absent from both deployed ABIs: " + method);
    }
    ts.forEachChild(node, visit);
  }
  visit(source);
});

test("every inventory tuple retains exact recursive named ordinary compiler fields", () => {
  const witnesses = [];
  function visit(parameter) {
    if (parameter.baseType === "array") visit(parameter.arrayChildren);
    if (parameter.baseType === "tuple") { witnesses.push(parameter); parameter.components.forEach(visit); }
  }
  for (const iface of Object.values(compiledInterfaces)) for (const fragment of iface.fragments) {
    fragment.inputs?.forEach(visit);
    fragment.outputs?.forEach(visit);
  }
  const names = [...readFileSync(pureUrl, "utf8").matchAll(/export const (CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_\w+_TUPLE) =/g)];
  assert.ok(names.length >= 28);
  for (const [, name] of names) {
    const actual = ParamType.from(readPure(name));
    assert.ok(witnesses.some(original => {
      try { sameFields([actual], [original], name); return true; } catch { return false; }
    }), name + " lacks exact recursive named compiler fields");
  }
});

// Solidity library selectors use nominal struct/enum names, while their calldata
// values use ordinary ABI encodings. Preserve both witnesses independently.
function libraryValue(parameter) {
  assert.ok(!/\bstorage\b/.test(parameter.internalType ?? ""), "memory-only library values");
  let type = parameter.type;
  if (parameter.internalType?.startsWith("enum ")) type = "uint8" + (type.match(/(\[[0-9]*\])+$/)?.[0] ?? "");
  else if (parameter.internalType?.startsWith("contract ")) type = "address" + (type.match(/(\[[0-9]*\])+$/)?.[0] ?? "");
  return { ...parameter, type, ...(parameter.components ? { components: parameter.components.map(libraryValue) } : {}) };
}

test("every deployed read worker retains its nominal selector and structural compiler codec", () => {
  const variants = readWorkflow("workers");
  assert.deepEqual(Object.keys(variants).sort(), ["collection", "scoped"]);
  const expected = ["authority", "source", "native", "reference", "work", "rights", "intent", "waiver", "interview",
    "originals", "document", "documentFacts", "catalogs", "root", "token", "tokenSource", "script", "renderer",
    "profile", "preservation", "definition"].sort();
  for (const [variant, workers] of Object.entries(variants)) {
    assert.deepEqual(Object.keys(workers).sort(), expected, variant);
    for (const [role, worker] of Object.entries(workers)) {
      const label = variant + ":" + role + ":" + worker.contract + "." + worker.method;
      const nominal = Object.entries(fixture.libraryMethodIdentifiers[worker.contract] ?? {}).filter(([signature, selector]) =>
        signature.startsWith(worker.method + "(") && "0x" + selector === worker.selector);
      assert.equal(nominal.length, 1, label + " unique nominal selector");
      const candidates = fixture.libraryAbis[worker.contract]?.filter(fragment =>
        fragment.type === "function" && fragment.name === worker.method
        && fragment.name + "(" + fragment.inputs.map(value => (value.internalType ?? value.type)
          .replace(/^(?:struct|enum|contract) /, "")).join(",") + ")" === nominal[0][0]);
      assert.equal(candidates?.length, 1, label);
      const original = candidates[0];
      assert.ok(["pure", "view"].includes(original.stateMutability), label + " read-only");
      assert.ok(!nominal[0][0].includes(" storage"), label + " memory-only nominal input");
      assert.equal(worker.selector, "0x" + nominal[0][1], label + " nominal selector");
      sameFields(worker.inputs.map(type => ParamType.from(type)), original.inputs.map(value => ParamType.from(libraryValue(value))), label + " inputs");
      sameFields(worker.outputs.map(type => ParamType.from(type)), original.outputs.map(value => ParamType.from(libraryValue(value))), label + " outputs");
      const selection = fixture.librarySelections[worker.contract];
      assert.equal(selection.contract, worker.contract, label);
      assert.equal(selection.nominal, true, label);
      const source = fixture.sourceTexts[selection.source];
      assert.ok(source && fixture.sourceHashes[selection.source], label + " frozen source");
      assert.match(source, new RegExp("function\\s+" + worker.method + "\\s*\\([\\s\\S]*?\\)\\s+public\\s+(?:pure|view)\\b"), label + " public read worker");
    }
  }
});

test("reused item, chain and cursor helpers retain byte-identical historical source", () => {
  const older = JSON.parse(readFileSync(new URL("./fixtures/current-scoped-policy-reference-v2-abi.json", import.meta.url), "utf8"));
  for (const path of [
    "smart-contracts/domains/preservation/StreamPreservationInventoryChains.sol",
    "smart-contracts/domains/preservation/StreamPreservationInventoryIO.sol",
    "smart-contracts/domains/preservation/StreamPreservationInventoryItems.sol",
    "smart-contracts/interfaces/stream/preservation/StreamPreservationInventoryTypes.sol",
    "smart-contracts/interfaces/stream/preservation/StreamBundleArchiveTypes.sol",
  ]) {
    assert.ok(fixture.sourceTexts[path] && older.sourceTexts[path], path);
    assert.equal(fixture.sourceTexts[path], older.sourceTexts[path], path);
    assert.equal(fixture.sourceHashes[path], older.sourceHashes[path], path);
  }
  // Archive read semantics changed at this source; these are deliberately not
  // covered by the inventory's narrower source-equivalence assertion.
  const archive = "smart-contracts/domains/preservation/StreamBundleArchiveReads.sol";
  assert.notEqual(fixture.sourceTexts[archive], older.sourceTexts[archive]);
});

function sourceNamed(name) {
  const matches = Object.entries(fixture.sourceTexts).filter(([path]) => path.endsWith("/" + name + ".sol"));
  assert.equal(matches.length, 1, name);
  return matches[0][1];
}

// Read the original Solidity constants and document literals independently of
// the client table. Exact registered bytes have no synthesized final newline.
function originalDefinitions(scoped) {
  const records = [];
  // ABI146 includes the current record documents. The two unchanged generic
  // canonicalization files are retained by ABI129 and checked against today's
  // literal source/hash below; do not synthesize or normalize their bytes.
  const retained = JSON.parse(readFileSync(new URL("./fixtures/current-scoped-policy-inventory-archive-v2-abi.json", import.meta.url), "utf8")).documents;
  function fixed(name, prefix, path) {
    const source = sourceNamed(name);
    const identity = new RegExp(prefix + '_ID\\s*=\\s*keccak256\\("([^\"]+)"\\)').exec(source)?.[1];
    let hash = new RegExp(prefix + "_HASH\\s*=\\s*(0x[0-9a-f]{64})").exec(source)?.[1];
    let sourceDocument;
    if (!hash) {
      const literal = new RegExp(prefix + '_DOCUMENT\\s*=\\s*("(?:\\\\.|[^"\\\\])*")\\s*;').exec(source)?.[1];
      assert.ok(literal, name + "/" + prefix + " exact document literal");
      sourceDocument = JSON.parse(literal);
      assert.match(source, new RegExp(prefix + "_HASH\\s*=\\s*keccak256\\(bytes\\(" + prefix + "_DOCUMENT\\)\\)"));
      hash = keccak256(toUtf8Bytes(sourceDocument));
    }
    const length = Number(new RegExp(prefix + "_BYTES\\s*=\\s*(\\d+)").exec(source)?.[1]);
    assert.ok(identity && hash && length, name + "/" + prefix);
    const documentPath = path ?? "schemas/records/" + identity + ".json";
    const doc = fixture.documents[documentPath] ?? retained[documentPath];
    assert.ok(doc, identity);
    if (sourceDocument !== undefined) assert.equal(doc.text, sourceDocument);
    assert.equal(doc.byteLength, length);
    assert.equal(keccak256(toUtf8Bytes(doc.text)), hash);
    records.push({ name: identity, id: id(identity), hash, length, bytes: doc.text });
  }
  for (const prefix of ["SCHEMA", "PROFILE", "CATALOG_SCHEMA", "CATALOG_PROFILE"]) fixed("StreamWorkRecordDefinitions", prefix);
  for (const prefix of ["SCHEMA", "PROFILE"]) fixed("StreamRightsRecordDefinitions", prefix);
  for (const prefix of ["INTENT_SCHEMA", "INTENT_PROFILE", "WAIVER_SCHEMA", "WAIVER_PROFILE",
    "INTERVIEW_SCHEMA", "INTERVIEW_PROFILE", "CATALOG_SCHEMA", "CATALOG_PROFILE"]) fixed("StreamConservationDefinitions", prefix);
  for (const prefix of ["ENVIRONMENT_SCHEMA", "PNG_SCHEMA", "ZIP_SCHEMA", "FORMAT_CATALOG"]) fixed("StreamReferenceRenderDefinitions", prefix);
  fixed("StreamSnapshotDefinitions", "CANON", "schemas/museum/account-profile/RFC8785_JCS.json");
  const raw = retained["schemas/museum/genesis/RAW_BYTES.json"];
  const literal = /bytes\(\s*'([^']+)'\s*\)/.exec(sourceNamed("StreamPreservationDocumentReads"))[1];
  assert.equal(raw.text, literal);
  records.push({ name: "RAW_BYTES", id: id("RAW_BYTES"), hash: keccak256(toUtf8Bytes(raw.text)), length: raw.byteLength, bytes: raw.text });
  for (const kind of ["Snapshot", "Reference"]) {
    for (const [prefix, suffix] of [["SCHEMA", "schema"], ["PROFILE", "profile"], ["CANON", "abi"]]) {
      fixed("Stream" + (scoped ? "Scoped" : "") + "PreservationPolicy" + kind + "DefinitionsV2", prefix,
        "docs/schemas/preservation/" + (scoped ? "scoped-preservation-policy-" : "preservation-policy-collection-") + kind.toLowerCase() + "-v2." + suffix + ".json");
    }
  }
  for (const [name, prefixes] of [["StreamPreservationPolicyOutputSchemasV2", ["SCHEMA", "CANON", "LEAF_SCHEMA"]],
    ["Stream" + (scoped ? "Scoped" : "") + "PreservationPolicyContentRootSchemasV2", ["ROOT_SCHEMA", "ROOT_CANON"]]]) {
    const source = sourceNamed(name);
    for (const prefix of prefixes) {
      const identity = new RegExp(prefix + '\\s*=\\s*keccak256\\("([^\"]+)"\\)').exec(source)[1];
      const literal = new RegExp("if \\(id == " + prefix + "\\) \\{\\s*return bytes\\(\\s*'((?:\\\\.|[^'\\\\])*)'\\s*\\);").exec(source)?.[1];
      assert.ok(literal, name + "/" + prefix + " exact source document");
      const text = literal.replace(/\\(['\\])/g, "$1");
      assert.equal(JSON.parse(text).name, identity);
      records.push({ name: identity, id: id(identity), hash: keccak256(toUtf8Bytes(text)), length: Buffer.byteLength(text), bytes: text });
    }
  }
  return records;
}

test("both thirty-one-slot definition tables retain exact V2 source IDs, hashes and complete byte lengths", () => {
  for (const scoped of [false, true]) {
    const expected = originalDefinitions(scoped).map((row, index) => ({ index: BigInt(index), id: row.id, hash: row.hash, byteLength: BigInt(row.length) }));
    assert.equal(expected.length, 31);
    assert.equal(new Set(expected.map(row => row.id)).size, 31);
    assert.deepEqual(readPure(scoped ? "SCOPED_DEFINITIONS" : "COLLECTION_DEFINITIONS"), expected);
    const source = sourceNamed(scoped ? "StreamScopedPreservationPolicyRenderCriticalDefinitionsV1" : "StreamPreservationPolicyRenderCriticalDefinitionStagesV1");
    assert.match(source, /COUNT = 31/);
    assert.match(source, /if \(family != Family.FAMILY_PROFILE\) revert/);
    assert.match(source, /if \(i < 14\) return \(Documents.fixedId\(i\), Documents.fixedHash\(i\)\)/);
    assert.match(source, /if \(i < 20\) return \(Documents.fixedId\(i \+ 6\), Documents.fixedHash\(i \+ 6\)\)/);
    for (let i = 20; i < 26; i++) {
      const group = i < 23 ? "SnapshotV2" : "ReferenceV2", prefix = ["SCHEMA", "PROFILE", "CANON"][(i - 20) % 3];
      assert.ok(source.includes("if (i == " + i + ") return (" + group + "." + prefix + "_ID, " + group + "." + prefix + "_HASH);"));
    }
    assert.ok(source.includes("Roots.ids(family, " + scoped + ")"));
    assert.ok(source.includes("id = ids[i - 26]"));
    assert.ok(source.includes("Roots.definitionHash(family, " + scoped + ", id)"));
  }
});
