import test from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { posix } from "node:path";
import { readFileSync } from "node:fs";
import ts from "typescript";
import { AbiCoder, Interface, id } from "ethers";
import { solidityImports } from "../scripts/generate-current-entropy-policy-succession-fixture.mjs";
import { currentPreservationV2Fixture } from "../scripts/generate-current-preservation-v2-fixture.mjs";
import { fixture, compiledInterfaces, compiledLibraryEvents } from "./current-preservation-v2-fixture.mjs";

const sha = value => createHash("sha256").update(value).digest("hex");
const abi = AbiCoder.defaultAbiCoder();
const hosts = [
  "StreamFinalityFullPreservationPolicyEvidenceProviderV1",
  "StreamCurrentAuthorityFullPreservationPolicyEvidenceProviderV1",
];

test("shared preservation witness is exact ABI146 with no native execution claim", () => {
  assert.equal(fixture.profile, "current-preservation-v2-and-complete-view");
  assert.equal(fixture.sourceCommit, "9381dd999075693a4f63092d9924856a0dd72834");
  assert.equal(fixture.sourceTree, "d494a5f4703c5e35f7804ba8faabeecdceb69ef8");
  assert.equal(fixture.compilerReportedCommit, fixture.sourceCommit);
  assert.equal(fixture.compilerVersion, "0.8.19");
  assert.equal(fixture.sourceCount, 3914);
  assert.equal(fixture.literalBytes, 46592135);
  assert.equal(fixture.inputSha256, "be6679a64a2dec7d5acacab44e72937871b4d07fbdbcacb67de0e29e00f243c4");
  assert.equal(fixture.outputSha256, "955f08a7f6a1da5e1218654d841e6c0a62559b288bfc51a8fbb9fb4fb670cf1a");
  const { sha256, ...bridge } = fixture.committedSourceBridge;
  assert.equal(sha256, "2078dab397cce55469f964b36f6d801329ec2f5d36c6ea175cf7426b1bd45d21");
  assert.equal(sha((JSON.stringify(bridge, null, 2) + "\n").replaceAll("\n", "\r\n")), sha256);
  assert.equal(bridge.commit, fixture.sourceCommit);
  assert.equal(bridge.sources, 3914);
  assert.equal(Object.keys(bridge.committedBlobSHA256).length, 3914);
  assert.deepEqual(bridge.mismatches, []);
  assert.match(fixture.sourceBinding, /no line-ending normalization/);
  assert.match(fixture.qualification, /Fixture inclusion alone does not imply client workflow coverage/);
  assert.match(fixture.qualification, /C\/Burn\/Prepared current VIEW finality dispatch remains pending/);
  assert.match(fixture.qualification, /No actual native\/Safe execution/);
});

test("every ordinary ABI is complete and matches its compiler method identifiers", () => {
  assert.equal(Object.keys(fixture.abis).length, 147);
  assert.equal(Object.values(fixture.abis).reduce((n, a) => n + a.length, 0), 5415);
  let count = 0;
  for (const [name, iface] of Object.entries(compiledInterfaces)) {
    assert.deepEqual(fixture.selections[name], {
      source: fixture.selections[name].source, contract: name, full: true,
    });
    const functions = iface.fragments.filter(f => f.type === "function");
    assert.equal(functions.length, Object.keys(fixture.methodIdentifiers[name]).length, name);
    for (const fn of functions) {
      assert.equal(fixture.methodIdentifiers[name][fn.format("sighash")], fn.selector.slice(2), name + "." + fn.name);
      count++;
    }
  }
  assert.equal(count, 3634);
});

test("raw family and linked worker ABIs retain nominal selectors outside wallet interfaces", () => {
  assert.equal(Object.keys(fixture.libraryAbis).length, 246);
  assert.equal(Object.values(fixture.libraryAbis).reduce((n, a) => n + a.length, 0), 1123);
  let count = 0;
  for (const [name, raw] of Object.entries(fixture.libraryAbis)) {
    assert.equal(fixture.librarySelections[name].nominal, true);
    assert.equal(fixture.librarySelections[name].full, true);
    assert.equal(compiledInterfaces[name], undefined);
    assert.equal(compiledLibraryEvents(name).fragments.length, raw.filter(f => f.type === "event").length);
    for (const [signature, selector] of Object.entries(fixture.libraryMethodIdentifiers[name])) {
      assert.equal(id(signature).slice(2, 10), selector, name + ":" + signature);
      count++;
    }
  }
  assert.equal(count, 508);
  for (const name of [
    "StreamFinalityViewPreservationBindingV1", "StreamFinalityViewPreservationValidationV1",
    "StreamFinalityViewPreservationCompleteValidationV1", "StreamFinalityViewPreservationSourceSelectionV1",
    "StreamFinalityViewDeclarationBindingV1", "StreamFinalityViewPolicyFactoryBindingV1",
  ]) assert.ok(fixture.libraryAbis[name], name);
});

test("one full source closure binds every selected witness to committed Git bytes", () => {
  const visited = new Set();
  function visit(path) {
    if (visited.has(path)) return;
    visited.add(path);
    const text = fixture.sourceTexts[path];
    assert.equal(typeof text, "string", path);
    assert.equal(sha(text), fixture.sourceHashes[path], path);
    assert.equal(sha(text), fixture.committedSourceBridge.committedBlobSHA256[path], path);
    for (const imported of solidityImports(text)) {
      visit(imported.startsWith(".") ? posix.normalize(posix.join(posix.dirname(path), imported)) : imported);
    }
  }
  for (const selection of [...Object.values(fixture.selections), ...Object.values(fixture.librarySelections)]) visit(selection.source);
  assert.deepEqual([...visited].sort(), Object.keys(fixture.sourceHashes).sort());
  assert.deepEqual(Object.keys(fixture.sourceTexts).sort(), Object.keys(fixture.sourceHashes).sort());
  assert.equal(visited.size, 1595);
  assert.equal(Object.values(fixture.sourceTexts).reduce((n, text) => n + Buffer.byteLength(text), 0), 11115125);
});

test("supporting documents preserve exact UTF-8 bytes and current family definitions", () => {
  assert.equal(Object.keys(fixture.documents).length, 144);
  let bytes = 0;
  for (const document of Object.values(fixture.documents)) {
    assert.equal(sha(document.text), document.sha256);
    assert.equal(Buffer.byteLength(document.text), document.byteLength);
    bytes += document.byteLength;
  }
  assert.equal(bytes, 2779467);
  for (const name of [
    "docs/integrations/current-view-complete-preservation.md",
    "docs/integrations/current-authority-preservation-graphs.md",
    "docs/adr/0054-explicit-non-sanction-preservation-rendering.md",
    "docs/schemas/preservation/preservation-policy-collection-reference-v2.abi.json",
    "docs/schemas/preservation/scoped-preservation-policy-reference-v2.abi.json",
    "schemas/metadata/view-preservation-snapshot-v1/schema.json",
  ]) assert.ok(fixture.documents[name], name);
});

test("both genuine hosts share the exact five complete binding method ABIs", () => {
  const interfaces = ["IStreamFinalityViewPreservationCompleteBindingV1", "IStreamViewPreservationFinalitySourcesV1"];
  let methods = 0;
  for (const name of interfaces) for (const fn of compiledInterfaces[name].fragments.filter(f => f.type === "function")) {
    methods++;
    for (const host of hosts) {
      const actual = compiledInterfaces[host].getFunction(fn.name);
      // The concrete implementation calls the third argument "selected";
      // argument labels do not affect the canonical function ABI.
      assert.equal(actual.format("minimal"), fn.format("minimal"), host + "." + fn.name);
      for (let i = 0; i < fn.inputs.length; i++) {
        assert.deepEqual(actual.inputs[i].components, fn.inputs[i].components, host + "." + fn.name);
      }
      assert.equal(actual.selector, fn.selector);
    }
  }
  assert.equal(methods, 5);
  const event = compiledInterfaces.IStreamFinalityViewPreservationCompleteBindingV1.getEvent("ViewPreservationCompleteBound");
  assert.deepEqual(event.inputs.map(p => [p.name, p.type, p.indexed]), [
    ["completeRecordHash", "bytes32", true], ["basicRecordHash", "bytes32", true],
    ["actionId", "bytes32", true], ["fullProposalHash", "bytes32", false],
  ]);
  for (const host of hosts) assert.equal(compiledInterfaces[host].getEvent(event.name).format("full"), event.format("full"));
});

test("complete call tuple widths distinguish uint32 declaration gas from uint256 validation gas", () => {
  const fn = compiledInterfaces.IStreamFinalityViewPreservationCompleteBindingV1.getFunction("bindCompleteViewPreservation");
  assert.deepEqual(fn.inputs.map(p => p.components.length), [7, 6, 6]);
  assert.equal(fn.inputs[0].components[2].type, "uint256");
  assert.deepEqual(fn.inputs[1].components.slice(4).map(p => p.type), ["uint32", "uint32"]);
  const zero = p => p.baseType === "tuple" ? p.components.map(zero)
    : p.baseType === "array" ? Array.from({ length: p.arrayLength }, () => zero(p.arrayChildren))
    : p.type === "address" ? "0x" + "00".repeat(20)
    : p.type === "bytes32" ? "0x" + "00".repeat(32) : 0n;
  assert.equal((abi.encode(fn.inputs, fn.inputs.map(zero)).length - 2) / 2 + 4, 612);
  const source = compiledInterfaces.IStreamViewPreservationFinalitySourcesV1;
  assert.equal((abi.encode(source.getFunction("viewFinalitySources").outputs,
    source.getFunction("viewFinalitySources").outputs.map(zero)).length - 2) / 2, 192);
  assert.equal((abi.encode(source.getFunction("viewFinalitySourcesReceipt").outputs,
    source.getFunction("viewFinalitySourcesReceipt").outputs.map(zero)).length - 2) / 2, 416);
});

test("fixture generator rejects a substituted or partial compiler capture before use", () => {
  assert.throws(() => currentPreservationV2Fixture(Buffer.from("{}"), Buffer.from("{}"), Buffer.from("{}")),
    /Expected exact ABI146 input\/output/);
});

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


const readPure = literalReader(new URL("../src/current-view-complete-binding.ts", import.meta.url));
const readWorkflow = literalReader(new URL("../src/current-view-complete-binding-workflow.ts", import.meta.url));
test("every handwritten complete binding and supporting read fragment matches an ordinary ABI146 witness", () => {
  const declarations = [
    [readPure, "VIEW_COMPLETE_BINDING_ABI"],
    [readPure, "VIEW_COMPLETE_BINDING_OBSERVATION_ABI"],
    ...["governanceAbi", "snapshotAbi", "referenceAbi", "inventoryAbi", "bundleAbi", "factoryAbi",
      "sourceFactoryAbi", "gettersAbi"].map(name => [readWorkflow, name]),
  ];
  let count = 0;
  for (const [read, name] of declarations) {
    const actual = new Interface(read(name));
    for (const fragment of actual.fragments) {
      const matches = Object.values(compiledInterfaces).flatMap(iface =>
        iface.fragments.filter(candidate => candidate.type === fragment.type
          && candidate.format("sighash") === fragment.format("sighash")));
      assert.ok(matches.length > 0, name + ":" + fragment.format("full"));
      let compatible = false;
      for (const match of matches) {
        try { compatibleFragment(fragment, match); compatible = true; break; } catch { /* another ordinary witness may match */ }
      }
      assert.ok(compatible, "No exact ordinary ABI146 result/tuple/mutability witness: " + name + ":" + fragment.format("full"));
      count++;
    }
  }
  assert.ok(count >= 55, "Complete set of supporting fragments");
});

test("reused original Executor and RoleRegistry ABIs remain byte-equivalent at the new source", () => {
  const historical = JSON.parse(readFileSync(new URL("./fixtures/current-scoped-policy-finality-v2-abi.json", import.meta.url), "utf8"));
  for (const [old, name] of [["executor","StreamGovernanceExecutor"],["roleRegistry","StreamRoleRegistry"]]) {
    assert.deepEqual(fixture.abis[name], historical.abis[old], name);
    assert.deepEqual(fixture.methodIdentifiers[name], historical.methodIdentifiers[old], name);
    const path = fixture.selections[name].source;
    assert.equal(fixture.sourceTexts[path], historical.sourceTexts[path], path);
  }
});
