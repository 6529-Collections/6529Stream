import test from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { posix } from "node:path";
import { solidityImports } from "../scripts/generate-current-entropy-policy-succession-fixture.mjs";
import { readFileSync } from "node:fs";
import ts from "typescript";
import { Interface, ParamType, id, keccak256, toUtf8Bytes } from "ethers";
import { fixture, compiledInterfaces } from "./current-authority-preservation-archive-v1-fixture.mjs";

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


const pureUrl = new URL("../src/current-authority-preservation-archive-v1.ts", import.meta.url);
const workflowUrl = new URL("../src/current-authority-preservation-archive-v1-workflow.ts", import.meta.url);
const readPure = literalReader(pureUrl);
const readWorkflow = literalReader(workflowUrl);
const sha = value => createHash("sha256").update(value).digest("hex");

test("archive witness is the exact ABI155 source with separate historical inventory evidence", () => {
  assert.equal(fixture.profile, "current-authority-preservation-archive-v1");
  assert.equal(fixture.sourceCommit, "e93cb09169dd90fe3b63cb32e93fe1a8955a0ee1");
  assert.equal(readPure("CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_SOURCE"), fixture.sourceCommit);
  assert.equal(fixture.sourceTree, "0760c6a507204204f0c92201583cc7e5cb915f41");
  assert.equal(fixture.compilerVersion, "0.8.19");
  assert.equal(fixture.sourceCount, 4014);
  assert.equal(fixture.literalBytes, 47822956);
  assert.equal(fixture.inputSha256, "900111cb56eca5266fac836d72e444df5ff5a715e10bbfae22ee0ed29ae54e0b");
  assert.equal(fixture.outputSha256, "e1bbe599cbf87ecfd552360cd7b3687eaa1c7ac710c1da6c89a0d0e2b993f384");
  const { sha256, ...bridge } = fixture.committedSourceBridge;
  assert.equal(sha256, "224b34844a5e586e5f5cb6223567eb3b22027e219459fa2c4722da626ad9d35d");
  assert.equal(sha(JSON.stringify(bridge, null, 2) + "\n"), sha256);
  assert.equal(bridge.commit, fixture.sourceCommit);
  assert.equal(bridge.sources, 4014);
  assert.equal(Object.keys(bridge.committedBlobSHA256).length, 4014);
  assert.deepEqual(bridge.mismatches, []);
  assert.match(fixture.sourceBinding, /no line-ending normalization/);
  assert.match(fixture.qualification, /Historical ABI146 inventory clients retain their original fixture/);
  assert.match(fixture.qualification, /No actual native\/Safe execution/);
  assert.equal(sha(readFileSync(new URL("./fixtures/current-preservation-v2-abi.json", import.meta.url))),
    "6425f868f20cffa0da23dea20aa771a870fa4649ade04fe7229141bb15a4b7dc");
});

test("focused archive fixture retains complete ABIs and exact nominal library identifiers", () => {
  assert.equal(Object.keys(fixture.abis).length, 170);
  assert.equal(Object.keys(fixture.libraryAbis).length, 203);
  let ordinaryCount = 0, nominalCount = 0;
  for (const [name, iface] of Object.entries(compiledInterfaces)) {
    const selection = fixture.selections[name];
    assert.deepEqual(selection, { source: selection.source, contract: name, full: true });
    const functions = iface.fragments.filter(f => f.type === "function");
    assert.equal(functions.length, Object.keys(fixture.methodIdentifiers[name]).length);
    for (const f of functions) {
      assert.equal(fixture.methodIdentifiers[name][f.format("sighash")], f.selector.slice(2), name);
      ordinaryCount++;
    }
  }
  for (const [name, identifiers] of Object.entries(fixture.libraryMethodIdentifiers)) {
    assert.equal(fixture.librarySelections[name].nominal, true);
    assert.equal(fixture.librarySelections[name].full, true);
    assert.equal(compiledInterfaces[name], undefined);
    for (const [signature, selector] of Object.entries(identifiers)) {
      assert.equal(id(signature).slice(2, 10), selector, name + "." + signature);
      nominalCount++;
    }
  }
  assert.equal(ordinaryCount, 1386);
  assert.equal(nominalCount, 378);
});

test("four actual hosts have a complete exact-byte imported source closure", () => {
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
  for (const name of [
    "StreamCurrentAuthorityPreservationPolicyBundleArchiveCoverageV1",
    "StreamCurrentAuthorityScopedPreservationPolicyBundleArchiveCoverageV1",
    "StreamCurrentAuthorityPreservationPolicyRenderCriticalInventoryV1",
    "StreamCurrentAuthorityScopedPreservationPolicyRenderCriticalInventoryV1",
  ]) visit(fixture.selections[name].source);
  assert.equal(visited.size, 333);
  assert.deepEqual([...visited].sort(), Object.keys(fixture.sourceTexts).sort());
  for (const selected of [...Object.values(fixture.selections), ...Object.values(fixture.librarySelections)]) {
    assert.ok(visited.has(selected.source));
  }
  for (const document of Object.values(fixture.documents)) {
    assert.equal(sha(document.text), document.sha256);
    assert.equal(Buffer.byteLength(document.text), document.byteLength);
  }
});

test("client ABIs preserve both concrete archive hosts and all five original writes and events", () => {
  const expected = ["beginCoverage", "coverNext", "coverEmptySegment", "beginRefresh", "refreshNext"].sort();
  for (const [suffix, name] of [
    ["COLLECTION", "StreamCurrentAuthorityPreservationPolicyBundleArchiveCoverageV1"],
    ["SCOPED", "StreamCurrentAuthorityScopedPreservationPolicyBundleArchiveCoverageV1"],
  ]) {
    const actual = new Interface(readPure("CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_" + suffix + "_ABI"));
    const original = compiledInterfaces[name];
    for (const fragment of actual.fragments) {
      const witness = original.fragments.find(f => f.type === fragment.type && f.format("sighash") === fragment.format("sighash"));
      assert.ok(witness, name + "." + fragment.format("sighash"));
      compatibleFragment(fragment, witness);
    }
    const writes = iface => iface.fragments.filter(f => f.type === "function" && !f.constant).map(f => f.name).sort();
    const events = iface => iface.fragments.filter(f => f.type === "event").map(f => f.format("sighash")).sort();
    assert.deepEqual(writes(actual), expected);
    assert.deepEqual(writes(original), expected);
    assert.deepEqual(events(actual), events(original));
  }
  for (const [local, names] of [
    ["resolverAbi", ["IStreamArtistCurrentAuthorityResolver"]],
    ["environmentAbi", ["IStreamArtifactEnvironment", "IStreamExternalArtifactEnvironment"]],
  ]) for (const fragment of new Interface(readWorkflow(local)).fragments) {
    const witness = names.flatMap(name => compiledInterfaces[name].fragments)
      .find(f => f.type === fragment.type && f.format("sighash") === fragment.format("sighash"));
    assert.ok(witness, local + "." + fragment.name);
    compatibleFragment(fragment, witness);
  }
});

test("all archive tuple codecs retain the compiler's recursive named fields", () => {
  const witnesses = [];
  function visit(value) {
    const p = ParamType.from(libraryValue(value), true);
    if (p.baseType === "tuple") witnesses.push(p);
    if (value.components) value.components.forEach(visit);
  }
  for (const abi of [...Object.values(fixture.abis), ...Object.values(fixture.libraryAbis)]) for (const fragment of abi) {
    fragment.inputs?.forEach(visit);
    fragment.outputs?.forEach(visit);
  }
  const names = [...readFileSync(pureUrl, "utf8").matchAll(/export const (CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_\w+_TUPLE) =/g)];
  assert.ok(names.length >= 14);
  for (const [, name] of names) {
    const actual = ParamType.from(readPure(name));
    assert.ok(witnesses.some(original => {
      try { sameFields([actual], [original], name); return true; } catch { return false; }
    }), name + " lacks exact recursive named compiler fields");
  }
});

test("all nine archive workers keep their exact nominal selectors and structural compiler values", () => {
  const workers = readWorkflow("workers");
  assert.deepEqual(Object.keys(workers).sort(), ["capture", "environment", "multiConfiguration", "multiEnvironment",
    "multiOriginSet", "multiOriginAt", "multiRoute", "multiAdmit", "multiCurrent"].sort());
  for (const [role, worker] of Object.entries(workers)) {
    const label = role + ":" + worker.contract + "." + worker.method;
    const nominal = Object.entries(fixture.libraryMethodIdentifiers[worker.contract] ?? {}).filter(([signature, selector]) =>
      signature.startsWith(worker.method + "(") && "0x" + selector === worker.selector);
    assert.equal(nominal.length, 1, label + " unique nominal selector");
    const candidates = fixture.libraryAbis[worker.contract]?.filter(fragment =>
      fragment.type === "function" && fragment.name === worker.method
      && fragment.name + "(" + fragment.inputs.map(value => (value.internalType ?? value.type)
        .replace(/^(?:struct|enum|contract) /, "")).join(",") + ")" === nominal[0][0]);
    assert.equal(candidates?.length, 1, label);
    const original = candidates[0];
    assert.equal(original.stateMutability, "view", label);
    assert.ok(!nominal[0][0].includes(" storage"), label);
    sameFields(worker.inputs.map(type => ParamType.from(type)), original.inputs.map(value => ParamType.from(libraryValue(value))), label + " inputs");
    sameFields(worker.outputs.map(type => ParamType.from(type)), original.outputs.map(value => ParamType.from(libraryValue(value))), label + " outputs");
    const selection = fixture.librarySelections[worker.contract];
    assert.equal(selection.nominal, true);
    assert.match(fixture.sourceTexts[selection.source],
      new RegExp("function\\s+" + worker.method + "\\s*\\([\\s\\S]*?\\)\\s+public\\s+view\\b"));
  }
});

test("archive capability IDs contain the exact own interface functions", () => {
  for (const [name, expected] of Object.entries(readWorkflow("capabilities"))) {
    const source = fixture.sourceTexts[fixture.selections[name].source];
    const names = [...source.matchAll(/\bfunction\s+(\w+)\s*\(/g)].map(m => m[1]);
    let result = 0n;
    assert.ok(names.length > 0);
    for (const fn of names) {
      const candidates = compiledInterfaces[name].fragments.filter(f => f.type === "function" && f.name === fn);
      assert.equal(candidates.length, 1, name + "." + fn);
      result ^= BigInt(candidates[0].selector);
    }
    assert.equal("0x" + result.toString(16).padStart(8, "0"), expected, name);
  }
});

test("the client's eighteen exact correspondence triples come from the frozen Solidity branches", () => {
  const path = "smart-contracts/domains/preservation/StreamInventoryAbiCorrespondence.sol";
  const source = fixture.sourceTexts[path];
  assert.match(source, /if \(item\.algorithm != 1 \|\| item\.byteSize == 0\) return false/);
  assert.match(source, /item\.role == keccak256\("SIGNIFICANT_PROPERTIES"\) && item\.sourceIndex == 8/);
  assert.match(source, /item\.schemaId == 0 && item\.byteSize == 0/);
  assert.match(source, /item\.algorithm == 1 \|\| item\.algorithm == 2/);
  const rows = [];
  for (const [kind, block] of [
    [0n, /if \(item\.kind == T\.Kind\.NATIVE_BYTES\) \{([\s\S]*?)\n        \}/.exec(source)?.[1]],
    [2n, /if \(canon == keccak256\("STREAM_SOLIDITY_ABI_V1"\)\) \{([\s\S]*?)\n        \}/.exec(source)?.[1]],
  ]) {
    assert.ok(block);
    for (const match of block.matchAll(/role == keccak256\("([^"]+)"\)\s*&& schema == keccak256\("([^"]+)"\)/g)) {
      rows.push([kind, match[1], match[2], "STREAM_SOLIDITY_ABI_V1"]);
    }
  }
  for (const branch of source.matchAll(/if \(role == keccak256\("([^"]+)"\)\) \{([\s\S]*?)\n        \}/g)) {
    for (const match of branch[2].matchAll(/schema == keccak256\("([^"]+)"\)\s*&& canon == keccak256\("([^"]+)"\)/g)) {
      rows.push([2n, branch[1], match[1], match[2]]);
    }
  }
  const tail = source.slice(source.lastIndexOf("        return (role"));
  for (const match of tail.matchAll(/role == keccak256\("([^"]+)"\)\s*&& schema == keccak256\("([^"]+)"\)\s*&& canon == keccak256\("([^"]+)"\)/g)) {
    rows.push([2n, match[1], match[2], match[3]]);
  }
  assert.equal(rows.length, 18);
  const client = ts.createSourceFile(pureUrl.href, readFileSync(pureUrl, "utf8"), ts.ScriptTarget.Latest, true);
  const fn = client.statements.find(n => ts.isFunctionDeclaration(n)
    && n.name?.text === "currentAuthorityPreservationArchiveV1SupportedAbiCorrespondence");
  assert.ok(fn);
  const statement = fn.body.statements.find(n => ts.isVariableStatement(n)
    && n.declarationList.declarations[0].name.getText(client) === "cases");
  const cases = statement.declarationList.declarations[0].initializer;
  assert.ok(ts.isArrayLiteralExpression(cases));
  const clientRows = cases.elements.map(row => {
    assert.ok(ts.isArrayLiteralExpression(row) && row.elements.length === 4);
    assert.ok(ts.isBigIntLiteral(row.elements[0]));
    return [BigInt(row.elements[0].text.slice(0, -1)), ...row.elements.slice(1).map(v => {
      assert.ok(ts.isStringLiteral(v)); return v.text;
    })];
  });
  assert.deepEqual(clientRows, rows);
  const older = JSON.parse(readFileSync(new URL("./fixtures/current-preservation-v2-abi.json", import.meta.url)));
  assert.notEqual(fixture.sourceHashes[path], older.sourceHashes[path]);
  for (const name of ["StreamBundleArchiveTypes", "StreamPreservationInventoryTypes",
    "StreamCurrentAuthorityPreservationPolicyBundleArchiveCoverageV1",
    "StreamCurrentAuthorityScopedPreservationPolicyBundleArchiveCoverageV1"]) {
    const matches = Object.keys(fixture.sourceTexts).filter(p => p.endsWith("/" + name + ".sol"));
    assert.equal(matches.length, 1, name);
    assert.equal(fixture.sourceTexts[matches[0]], older.sourceTexts[matches[0]], name);
  }
});
