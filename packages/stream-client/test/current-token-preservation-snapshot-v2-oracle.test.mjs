import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import ts from "typescript";
import { Interface, ParamType, keccak256, toUtf8Bytes } from "ethers";
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
    if (ts.isNumericLiteral(node)) return Number(node.text);
    if (ts.isObjectLiteralExpression(node)) return Object.fromEntries(node.properties.map(property => {
      assert.ok(ts.isPropertyAssignment(property), "literal object property");
      return [property.name.text, value(property.initializer, locals)];
    }));
    if (ts.isIdentifier(node)) return locals.has(node.text) ? locals.get(node.text) : read(node.text);
    if (ts.isPropertyAccessExpression(node) && ts.isIdentifier(node.expression) && namespaces.has(node.expression.text)) {
      return literalReader(namespaces.get(node.expression.text), cache)(node.name.text);
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




const pureUrl = new URL("../src/current-token-preservation-snapshot-v2.ts", import.meta.url);
const readPure = literalReader(pureUrl);
const readWorkflow = literalReader(new URL("../src/current-token-preservation-snapshot-v2-workflow.ts", import.meta.url));

test("both snapshot public ABIs match their concrete V2 host and expose only publication writes", () => {
  for (const [suffix, name, selector] of [
    ["COLLECTION", "StreamPreservationPolicySnapshotPublicationV2", "0xc0d79bd7"],
    ["SCOPED", "StreamScopedPreservationPolicySnapshotPublicationV2", "0x178cc408"],
  ]) {
    const actual = new Interface(readPure(`TOKEN_PRESERVATION_SNAPSHOT_V2_${suffix}_ABI`));
    for (const fragment of actual.fragments) {
      const original = compiledInterfaces[name].fragments.find(candidate =>
        candidate.type === fragment.type && candidate.format("sighash") === fragment.format("sighash"));
      assert.ok(original, name + ":" + fragment.format("sighash"));
      compatibleFragment(fragment, original);
      if (fragment.type === "function") {
        assert.equal(fixture.methodIdentifiers[name][fragment.format("sighash")], fragment.selector.slice(2));
      }
    }
    assert.equal(actual.getFunction("publishSnapshot").selector, selector);
    assert.deepEqual(actual.fragments.filter(fragment => fragment.type === "function" && !fragment.constant)
      .map(fragment => fragment.name), ["publishSnapshot"]);
    if (suffix === "SCOPED") {
      assert.equal(actual.getFunction("snapshotChunkCount"), null);
      assert.equal(actual.getFunction("snapshotChunkAt"), null);
    }
  }
});

test("snapshot supporting read fragments match ordinary ABI146 results and mutability", () => {
  const names = ["metadataAbi", "coreAbi", "routerAbi", "schemaAbi", "storeAbi", "membershipAbi",
    "selectionAbi", "checkpointAbi", "outputAbi", "coverageAbi", "sourceAbi", "factoryAbi",
    "moduleRegistryAbi", "moduleAbi"];
  let count = 0;
  for (const name of names) for (const fragment of new Interface(readWorkflow(name)).fragments) {
    const witnesses = Object.values(compiledInterfaces).flatMap(iface => iface.fragments.filter(original =>
      original.type === fragment.type && original.format("sighash") === fragment.format("sighash")));
    assert.ok(witnesses.some(original => {
      try { compatibleFragment(fragment, original); return true; } catch { return false; }
    }), name + ":" + fragment.format("full"));
    count++;
  }
  assert.ok(count >= 60);
});

test("all snapshot public tuple fields preserve their recursive ordinary ABI146 witnesses", () => {
  const witnesses = [];
  function visit(parameter) {
    if (parameter.baseType === "array") visit(parameter.arrayChildren);
    if (parameter.baseType === "tuple") {
      witnesses.push(parameter);
      parameter.components.forEach(visit);
    }
  }
  for (const iface of Object.values(compiledInterfaces)) for (const fragment of iface.fragments) {
    fragment.inputs?.forEach(visit);
    fragment.outputs?.forEach(visit);
  }
  const names = [...readFileSync(pureUrl, "utf8").matchAll(/export const (TOKEN_PRESERVATION_SNAPSHOT_V2_\w+_TUPLE) =/g)];
  assert.equal(names.length, 19);
  for (const [, name] of names) {
    const actual = ParamType.from(readPure(name));
    assert.ok(witnesses.some(original => {
      try { sameFields([actual], [original], name); return true; } catch { return false; }
    }), name + " lacks exact recursive named compiler fields");
  }
});

test("capability markers use precisely the original interface's own declarations", () => {
  const capabilities = readWorkflow("CAPABILITIES");
  assert.equal(Object.keys(capabilities).length, 6);
  for (const [name, expected] of Object.entries(capabilities)) {
    const source = fixture.sourceTexts[fixture.selections[name].source]
      .replace(/\/\*[\s\S]*?\*\//g, "").replace(/\/\/[^\n]*/g, "");
    const declaration = source.match(new RegExp("interface\\s+" + name + "\\b[^\\{]*\\{"));
    assert.ok(declaration, name);
    const start = declaration.index + declaration[0].length;
    let depth = 1, end = start;
    while (depth && end < source.length) {
      if (source[end] === "{") depth++;
      if (source[end] === "}") depth--;
      end++;
    }
    assert.equal(depth, 0);
    const body = source.slice(start, end - 1);
    const functions = [...body.matchAll(/\bfunction\s+(\w+)\s*\(/g)].map(match => match[1]);
    assert.ok(functions.length > 0, name);
    let value = 0n;
    for (const fn of new Set(functions)) {
      const originals = compiledInterfaces[name].fragments.filter(fragment => fragment.type === "function" && fragment.name === fn);
      assert.equal(originals.length, functions.filter(candidate => candidate === fn).length,
        name + "." + fn + " must have unambiguous own overloads");
      for (const original of originals) value ^= BigInt(original.selector);
    }
    assert.equal("0x" + value.toString(16).padStart(8, "0"), expected, name);
  }
});

test("snapshot and collection root definitions preserve complete exact source-bound bytes", () => {
  const collection = fixture.sourceTexts["smart-contracts/domains/records/StreamPreservationPolicySnapshotDefinitionsV2.sol"];
  const scoped = fixture.sourceTexts["smart-contracts/domains/records/StreamScopedPreservationPolicySnapshotDefinitionsV2.sol"];
  for (const [name, original, extension] of [
    ["SCHEMA", "SCHEMA", "schema"], ["PROFILE", "PROFILE", "profile"], ["CANONICALIZATION", "CANON", "abi"],
  ]) {
    const collectionText = fixture.documents[`docs/schemas/preservation/preservation-policy-collection-snapshot-v2.${extension}.json`].text;
    assert.equal(readPure(`COLLECTION_${name}_DOCUMENT`), collectionText);
    const expectedHash = collection.match(new RegExp(original + "_HASH\\s*=\\s*(0x[0-9a-f]{64})"))?.[1];
    const expectedLength = collection.match(new RegExp(original + "_BYTES\\s*=\\s*(\\d+)"))?.[1];
    assert.equal(keccak256(toUtf8Bytes(collectionText)), expectedHash);
    assert.equal(Buffer.byteLength(collectionText), Number(expectedLength));

    const scopedText = fixture.documents[`docs/schemas/preservation/scoped-preservation-policy-snapshot-v2.${extension}.json`].text;
    const literal = scoped.match(new RegExp('string\\s+internal\\s+constant\\s+' + original + '_DOCUMENT\\s*=\\s*("(?:\\\\.|[^"\\\\])*")\\s*;'))?.[1];
    assert.ok(literal, original);
    assert.equal(JSON.parse(literal), scopedText);
    assert.equal(readPure(`SCOPED_${name}_DOCUMENT`), scopedText);
  }
  const root = fixture.sourceTexts["smart-contracts/domains/finality/StreamPreservationPolicyContentRootSchemasV2.sol"];
  const rootLiterals = [...root.matchAll(/return bytes\(\s*'((?:\\.|[^'\\])*)'\s*\);/g)]
    .map(match => match[1].replace(/\\(['\\])/g, "$1"));
  assert.equal(rootLiterals.length, 2);
  assert.equal(readPure("ROOT_SCHEMA_DOCUMENT"), rootLiterals[0]);
  assert.equal(readPure("ROOT_CANONICALIZATION_DOCUMENT"), rootLiterals[1]);
});
