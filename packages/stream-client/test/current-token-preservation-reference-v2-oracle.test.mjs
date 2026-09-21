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


const pureUrl = new URL("../src/current-token-preservation-reference-v2.ts", import.meta.url);
const workflowUrl = new URL("../src/current-token-preservation-reference-v2-workflow.ts", import.meta.url);
const readPure = literalReader(pureUrl);
const readWorkflow = literalReader(workflowUrl);

test("both reference public ABIs match concrete V2 hosts and exactly five ordinary writes", () => {
  const writes = ["prepareEnvironment", "prepareFileInventory", "prepareFileInventoryFromParts", "prepareFileInventoryPart", "publishReference"];
  const selectors = ["0xe5dc1cfc", "0xc7ca6887", "0x3b1c5322", "0x33fda048", "0x3d620828"];
  for (const [suffix, name] of [
    ["COLLECTION", "StreamPreservationPolicyReferencePublicationV2"],
    ["SCOPED", "StreamScopedPreservationPolicyReferencePublicationV2"],
  ]) {
    const actual = new Interface(readPure(`TOKEN_PRESERVATION_REFERENCE_V2_${suffix}_ABI`));
    for (const fragment of actual.fragments) {
      const original = compiledInterfaces[name].fragments.find(candidate =>
        candidate.type === fragment.type && candidate.format("sighash") === fragment.format("sighash"));
      assert.ok(original, name + ":" + fragment.format("sighash"));
      compatibleFragment(fragment, original);
      if (fragment.type === "function") {
        assert.equal(fixture.methodIdentifiers[name][fragment.format("sighash")], fragment.selector.slice(2));
      }
    }
    assert.deepEqual(actual.fragments.filter(fragment => fragment.type === "function" && !fragment.constant)
      .map(fragment => fragment.name).sort(), writes);
    writes.forEach((name, i) => assert.equal(actual.getFunction(name).selector, selectors[i]));
    if (suffix === "SCOPED") {
      assert.equal(actual.getFunction("referenceChunkCount"), null);
      assert.equal(actual.getFunction("referenceChunkAt"), null);
    }
  }
});

test("reference supporting read fragments preserve ordinary ABI146 results and mutability", () => {
  const source = ts.createSourceFile(workflowUrl.href, readFileSync(workflowUrl, "utf8"), ts.ScriptTarget.Latest, true);
  const names = source.statements.filter(ts.isVariableStatement).flatMap(statement =>
    [...statement.declarationList.declarations].filter(entry =>
      ts.isIdentifier(entry.name) && entry.initializer && ts.isNewExpression(entry.initializer)
      && entry.initializer.expression.getText(source) === "Interface").map(entry => entry.name.text));
  assert.ok(names.length >= 9);
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
});

test("every reference exported tuple preserves exact recursive ordinary ABI146 fields", () => {
  const witnesses = [];
  function visit(parameter) {
    if (parameter.baseType === "array") visit(parameter.arrayChildren);
    if (parameter.baseType === "tuple") { witnesses.push(parameter); parameter.components.forEach(visit); }
  }
  for (const iface of Object.values(compiledInterfaces)) for (const fragment of iface.fragments) {
    fragment.inputs?.forEach(visit);
    fragment.outputs?.forEach(visit);
  }
  const names = [...readFileSync(pureUrl, "utf8").matchAll(/export const (TOKEN_PRESERVATION_REFERENCE_V2_\w+_TUPLE) =/g)];
  assert.ok(names.length >= 19);
  for (const [, name] of names) {
    const actual = ParamType.from(readPure(name));
    assert.ok(witnesses.some(original => {
      try { sameFields([actual], [original], name); return true; } catch { return false; }
    }), name + " lacks exact recursive named compiler fields");
  }
});

test("shared preparation and archive helpers have byte-identical original source witnesses", () => {
  const older = JSON.parse(readFileSync(new URL("./fixtures/current-scoped-policy-reference-v2-abi.json", import.meta.url), "utf8"));
  const paths = [
    "smart-contracts/domains/preservation/StreamReferenceInventoryPreparation.sol",
    "smart-contracts/domains/preservation/StreamReferenceRenderPreparation.sol",
    "smart-contracts/domains/preservation/StreamReferenceRenderSourceReads.sol",
    "smart-contracts/domains/records/StreamReferenceEnvironmentJson.sol",
    "smart-contracts/interfaces/stream/preservation/IStreamReferenceEnvironmentPreparation.sol",
    "smart-contracts/interfaces/stream/preservation/IStreamReferenceInventoryPreparation.sol",
    "smart-contracts/interfaces/stream/preservation/StreamReferenceRenderTypes.sol",
  ];
  for (const path of paths) {
    assert.ok(fixture.sourceTexts[path] && older.sourceTexts[path], path);
    assert.equal(fixture.sourceTexts[path], older.sourceTexts[path], path);
    assert.equal(fixture.sourceHashes[path], older.sourceHashes[path], path);
  }
});

test("all ten reference definitions and scoped root hashes retain complete frozen source bytes", () => {
  function exactDefinition(name, documentPath, original, sourcePrefix) {
    const document = fixture.documents[documentPath].text;
    assert.equal(readPure(name), document, documentPath);
    const hash = original.match(new RegExp(sourcePrefix + "_HASH\\s*=\\s*(0x[0-9a-f]{64})"))?.[1];
    const length = original.match(new RegExp(sourcePrefix + "_BYTES\\s*=\\s*(\\d+)"))?.[1];
    assert.equal(keccak256(toUtf8Bytes(document)), hash, documentPath);
    assert.equal(Buffer.byteLength(document), Number(length), documentPath);
  }
  for (const [prefix, library, stem] of [
    ["COLLECTION", "StreamPreservationPolicyReferenceDefinitionsV2", "preservation-policy-collection-reference-v2"],
    ["SCOPED", "StreamScopedPreservationPolicyReferenceDefinitionsV2", "scoped-preservation-policy-reference-v2"],
  ]) {
    const original = fixture.sourceTexts[`smart-contracts/domains/records/${library}.sol`];
    for (const [name, sourcePrefix, extension] of [
      ["SCHEMA", "SCHEMA", "schema"], ["PROFILE", "PROFILE", "profile"], ["CANONICALIZATION", "CANON", "abi"],
    ]) {
      exactDefinition(`${prefix}_${name}_DOCUMENT`, `docs/schemas/preservation/${stem}.${extension}.json`, original, sourcePrefix);
    }
  }
  const original = fixture.sourceTexts["smart-contracts/domains/records/StreamReferenceRenderDefinitions.sol"];
  for (const [name, sourcePrefix] of [
    ["STREAM_REFERENCE_NATIVE_ENVIRONMENT_V1", "ENVIRONMENT_SCHEMA"],
    ["STREAM_REFERENCE_PNG_OBJECT_V1", "PNG_SCHEMA"],
    ["STREAM_REFERENCE_RUNTIME_ZIP_OBJECT_V1", "ZIP_SCHEMA"],
    ["STREAM_REFERENCE_NATIVE_FORMATS_V1", "FORMAT_CATALOG"],
  ]) exactDefinition(`${name}_DOCUMENT`, `schemas/records/${name}.json`, original, sourcePrefix);

  const root = fixture.sourceTexts["smart-contracts/domains/finality/StreamScopedPreservationPolicyContentRootSchemasV2.sol"];
  const literals = [...root.matchAll(/return bytes\(\s*'((?:\\.|[^'\\])*)'\s*\);/g)]
    .map(match => match[1].replace(/\\(['\\])/g, "$1"));
  assert.equal(literals.length, 2);
  for (const [i, name] of ["SCHEMA", "CANONICALIZATION"].entries()) {
    assert.equal(readPure(`TOKEN_PRESERVATION_REFERENCE_V2_SCOPED_ROOT_${name}_HASH`), keccak256(toUtf8Bytes(literals[i])));
  }
});
