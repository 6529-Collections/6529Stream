import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import ts from "typescript";
import { Interface, ParamType } from "ethers";
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



const readWorkflow = literalReader(new URL("../src/current-token-preservation-output-v2-workflow.ts", import.meta.url));
const pureUrl = new URL("../src/current-token-preservation-output-v2.ts", import.meta.url);
const readPure = literalReader(pureUrl);

test("all public token preservation fragments match the actual V2 hosts and original read interfaces", () => {
  const hosts = {
    CHECKPOINT: ["StreamPreservationPolicyContentCheckpointV2", "StreamScopedPreservationPolicyContentCheckpointV2"],
    OUTPUT: ["StreamPreservationPolicyOutputManifestV2"],
    PRODUCER: ["IStreamPreservationRendererV1", "StreamPreservationRendererV1", "StreamCurrentArtistPreservationRendererV1"],
    REGISTRY: ["IStreamPreservationRegistryV1"],
  };
  for (const [suffix, names] of Object.entries(hosts)) {
    const actual = new Interface(readPure(`TOKEN_PRESERVATION_OUTPUT_V2_${suffix}_ABI`));
    for (const name of names) for (const fragment of actual.fragments) {
      const original = compiledInterfaces[name].fragments.find(candidate =>
        candidate.type === fragment.type && candidate.format("sighash") === fragment.format("sighash"));
      assert.ok(original, name + ":" + fragment.format("sighash"));
      compatibleFragment(fragment, original);
      if (fragment.type === "function") {
        assert.equal(fixture.methodIdentifiers[name][fragment.format("sighash")], fragment.selector.slice(2));
      }
    }
  }
});

test("nineteen public named tuples retain the complete recursive ordinary compiler fields", () => {
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
  const exceptions = new Set(["PRODUCER_BINDING", "REGISTRY_ANALYSIS"]);
  const declarations = [...readFileSync(pureUrl, "utf8").matchAll(/export const (TOKEN_PRESERVATION_OUTPUT_V2_(\w+)_TUPLE) =/g)];
  assert.equal(declarations.length, 21);
  let count = 0;
  for (const [, name, suffix] of declarations) {
    if (exceptions.has(suffix)) continue;
    const actual = ParamType.from(readPure(name));
    const matches = witnesses.filter(witness => witness.format("sighash") === actual.format("sighash"));
    assert.ok(matches.some(witness => {
      try { sameFields(actual.components, witness.components, name, true); return true; } catch { return false; }
    }), name + " lacks exact named compiler tuple witness");
    count++;
  }
  assert.equal(count, 19);
});

test("flat producer binding and source-only Registry analysis keep distinct provenance", () => {
  // The concrete producer exposes six flat unnamed results, not a named tuple.
  const flat = compiledInterfaces.StreamPreservationRendererV1.getFunction("preservationBinding").outputs;
  sameFields(ParamType.from(readPure("TOKEN_PRESERVATION_OUTPUT_V2_PRODUCER_BINDING_TUPLE")).components,
    flat, "original flat preservationBinding");
  assert.ok(flat.every(field => field.name === ""));

  // Analysis is carried in canonical bytes; it has no ordinary external tuple witness.
  const source = fixture.sourceTexts["smart-contracts/interfaces/stream/metadata/IStreamPreservationRegistryV1.sol"];
  function sourceTuple(name) {
    const body = source.match(new RegExp(`struct ${name}\\s*\\{([^}]+)\\}`))?.[1];
    assert.ok(body, name);
    const fields = body.split(";").map(field => field.trim()).filter(Boolean).map(field => {
      const [type, fieldName, extra] = field.split(/\s+/);
      assert.equal(extra, undefined);
      return `${type === "ProducerBinding" ? sourceTuple(type) : type} ${fieldName}`;
    });
    return `tuple(${fields.join(",")})`;
  }
  sameFields(ParamType.from(readPure("TOKEN_PRESERVATION_OUTPUT_V2_REGISTRY_ANALYSIS_TUPLE")).components,
    ParamType.from(sourceTuple("PreservationAnalysis")).components, "retained Registry analysis source", true);
});

test("all three definition literals preserve exact frozen Solidity bytes", () => {
  const source = fixture.sourceTexts["smart-contracts/domains/finality/StreamPreservationPolicyOutputSchemasV2.sol"];
  const definitions = [...source.matchAll(/return bytes\(\s*'((?:\\.|[^'\\])*)'\s*\);/g)]
    .map(match => match[1].replace(/\\(['\\])/g, "$1"));
  assert.equal(definitions.length, 3);
  for (const [index, name] of ["SCHEMA_DOCUMENT", "CANONICALIZATION_DOCUMENT", "LEAF_SCHEMA_DOCUMENT"].entries()) {
    assert.equal(readPure(name), definitions[index], name);
  }
});

test("token preservation supporting read fragments match exact ordinary ABI146 fields and mutability", () => {
  const declarations = [
    "checkpointAbi", "outputAbi", "selectionAbi", "sourceAbi", "factoryAbi",
    "routerAbi", "readinessAbi", "registryAbi", "producerAbi", "coreAbi",
    "coverageAbi", "schemaAbi", "entropyAbi",
  ];
  let count = 0;
  for (const name of declarations) {
    const actual = new Interface(readWorkflow(name));
    for (const fragment of actual.fragments) {
      const matches = Object.values(compiledInterfaces).flatMap(iface =>
        iface.fragments.filter(candidate => candidate.type === fragment.type
          && candidate.format("sighash") === fragment.format("sighash")));
      assert.ok(matches.length > 0, name + ":" + fragment.format("full"));
      let compatible = false;
      for (const match of matches) {
        try { compatibleFragment(fragment, match); compatible = true; break; } catch { /* try the next genuine witness */ }
      }
      assert.ok(compatible, "No exact ordinary ABI146 result/tuple/mutability witness: " + name + ":" + fragment.format("full"));
      count++;
    }
  }
  assert.ok(count >= 65, "All original read surfaces are checked");
});

test("the additive shared fixture retains the exact finalized entropy read interface", () => {
  const fn = compiledInterfaces.IStreamStaticEntropySource.getFunction("staticTokenRenderFacts");
  assert.deepEqual(fn.inputs.map(p => p.type), ["uint256"]);
  assert.deepEqual(fn.outputs.map(p => p.type), ["uint8", "bytes32", "address"]);
  assert.equal(fixture.methodIdentifiers.IStreamStaticEntropySource[fn.format("sighash")], fn.selector.slice(2));
});
