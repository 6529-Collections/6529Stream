import test from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { posix } from "node:path";
import { FunctionFragment, Interface, id } from "ethers";
import ts from "typescript";
import { fixture, compiledInterfaces } from "./current-revenue-pull-fixture.mjs";
import { solidityImports } from "../scripts/generate-current-entropy-policy-succession-fixture.mjs";

const sha = value => createHash("sha256").update(value).digest("hex");
const scope = {
  wallet: ["syncAsset", "release", "releaseWithAuthorization", "revokeReleaseAuthorization", "revokeReleaseAuthorizationBySignature"],
  router: ["claimMany", "syncAndClaimMany"],
  escrow: ["flushEscrow", "flushToVerifiedWalletBestEffort", "publishEscrowRecoveryManifest", "executeEscrowRecovery",
    "submitEscrowRecoveryConsent", "recordEscrowRecoveryConsent", "revokeEscrowRecoveryConsent",
    "scheduleEscrowRecovery", "cancelEscrowRecovery", "authorizeTerminalEscrowRecovery"],
};

test("revenue caller evidence retains its exact ABI107 source and earlier-helper qualification", () => {
  assert.equal(fixture.sourceCommit, "d88ee108080ba1e66f1b8a9b49e3fd9a59d35c4a");
  assert.equal(fixture.sourceTree, "8572b46becb1b0207b2313e6371b034e4a5381ee");
  assert.equal(fixture.sourceCount, 2865);
  assert.equal(fixture.literalBytes, 33_830_434);
  assert.equal(fixture.inputSha256, "8f7a2f3597177dbd5bbc84eebae2cf2f80c5205aefbfa0e913e62590720dc740");
  assert.equal(fixture.outputSha256, "1de19aca0c19df097c8c51123d1975574ff6b997901e77bc6c51806776d92edc");
  assert.match(fixture.sourceBinding, /byte-for-byte/);
  assert.match(fixture.qualification, /singleton implementation is not a claim wallet/);
  assert.match(fixture.qualification, /ordinary Safe CALLs confer no governance authority/);
  assert.match(fixture.qualification, /native contract\/Safe execution/);
  assert.equal(fixture.priorHelperReuse.sourceCommit, "7382327933c90638e8552fc8dd0340e9de53c449");
  assert.equal(Object.keys(fixture.priorHelperReuse.matchingFiles).length, 9);
  for (const [path, digest] of Object.entries(fixture.priorHelperReuse.matchingFiles)) {
    assert.equal(sha(fixture.sourceTexts[path]), digest, path);
  }
  assert.match(fixture.priorHelperReuse.qualification, /not whole-closure/);
});

test("all selected ABI entries and method identifiers retain complete canonical compiler signatures", () => {
  assert.equal(Object.keys(fixture.abis).length, 26);
  assert.equal(Object.values(fixture.abis).reduce((count, abi) => count + abi.length, 0), 1183);
  let functions = 0;
  for (const [key, abi] of Object.entries(fixture.abis)) {
    assert.equal(fixture.selections[key].full, true, key);
    assert.ok(fixture.sourceTexts[fixture.selections[key].source], key);
    const methods = abi.filter(item => item.type === "function");
    assert.equal(methods.length, Object.keys(fixture.methodIdentifiers[key]).length, key);
    for (const entry of methods) {
      const fragment = FunctionFragment.from(entry), signature = fragment.format("sighash");
      assert.equal(fixture.methodIdentifiers[key][signature], id(signature).slice(2, 10), `${key}/${signature}`);
      assert.equal(compiledInterfaces[key].getFunction(signature).format("full"), fragment.format("full"));
      functions++;
    }
  }
  assert.equal(functions, 530);
});

test("retained source texts form the complete selected import closure with exact hashes", () => {
  const visited = new Set();
  function visit(path) {
    if (visited.has(path)) return;
    const source = fixture.sourceTexts[path];
    assert.equal(typeof source, "string", path);
    assert.equal(sha(source), fixture.sourceHashes[path], path);
    visited.add(path);
    for (const imported of solidityImports(source)) {
      visit(imported.startsWith(".") ? posix.normalize(posix.join(posix.dirname(path), imported)) : imported);
    }
  }
  for (const selection of Object.values(fixture.selections)) visit(selection.source);
  for (const path of Object.keys(fixture.priorHelperReuse.matchingFiles)) visit(path);
  assert.equal(visited.size, 75);
  assert.deepEqual([...visited].sort(), Object.keys(fixture.sourceHashes).sort());
  assert.deepEqual(Object.keys(fixture.sourceHashes), Object.keys(fixture.sourceTexts));
  assert.equal(Object.values(fixture.sourceTexts).reduce((bytes, source) => bytes + Buffer.byteLength(source), 0), 744_819);
});

test("frozen interpretation documents retain their bytes and distinct operational evidence boundary", () => {
  assert.equal(Object.keys(fixture.documents).length, 7);
  for (const [path, document] of Object.entries(fixture.documents)) {
    assert.equal(sha(document.text), document.sha256, path);
    assert.equal(Buffer.byteLength(document.text), document.byteLength, path);
  }
  const recovery = fixture.documents["docs/guides/revenue-runtime-escrow-recovery.md"].text;
  assert.match(recovery, /does not\s+verify transaction inclusion/);
  assert.match(recovery, /old code is unavailable/);
  assert.match(recovery, /distinct\s+class-2 TERMINAL_FREEZE action/);
  assert.match(recovery, /No operation here touches funds already resident in the old wallet/);
});

test("the 17 requested methods retain zero value while initialization and producer writes remain separate", () => {
  const excluded = {
    wallet: ["initialize"],
    router: [],
    escrow: ["initializeRevenueRuntimeRegistry", "setCreditProducer", "raiseGasParameter", "creditNative", "creditERC20"],
  };
  let count = 0;
  for (const [key, names] of Object.entries(scope)) {
    for (const name of names) {
      assert.equal(compiledInterfaces[key].getFunction(name).stateMutability, "nonpayable", `${key}/${name}`);
      count++;
    }
    const all = fixture.abis[key].filter(item => item.type === "function" && !["view", "pure"].includes(item.stateMutability)).map(item => item.name).sort();
    assert.deepEqual(all, [...names, ...excluded[key]].sort(), key);
  }
  assert.equal(count, 17);
  assert.equal(compiledInterfaces.escrow.getFunction("creditNative").stateMutability, "payable");
  assert.equal(compiledInterfaces.escrow.getFunction("recoverERC20"), null);
  assert.equal(compiledInterfaces.router.getFunction("recover"), null);
});

test("original claim and release tuples preserve amount, nonce, deadline and failure-index widths", () => {
  const authorization = compiledInterfaces.wallet.getFunction("releaseWithAuthorization").inputs[0];
  assert.deepEqual(authorization.components.map(field => [field.name, field.type]), [
    ["asset", "address"], ["account", "address"], ["recipient", "address"],
    ["releasableSnapshot", "uint256"], ["nonce", "bytes32"], ["deadline", "uint64"],
  ]);
  const claims = compiledInterfaces.router.getFunction("claimMany").inputs[0].arrayChildren;
  assert.deepEqual(claims.components.map(field => [field.name, field.type]), [
    ["wallet", "address"], ["asset", "address"], ["account", "address"],
  ]);
  assert.equal(compiledInterfaces.router.getFunction("claimMany").outputs[0].type, "uint256[]");
  const failure = compiledInterfaces.router.getEvent("ClaimFailed");
  assert.deepEqual(failure.inputs.filter(field => field.indexed).map(field => field.name), ["wallet", "asset", "account"]);
  assert.equal(failure.inputs.find(field => field.name === "claimIndex").type, "uint256");
  assert.equal(failure.inputs.find(field => field.name === "reason").type, "bytes");
});

test("historical ABI102 inventory roles stay distinct from the current initialized-clone caller", () => {
  const inventory = JSON.parse(readFileSync(new URL("../docs/current-v1-safe-coverage.json", import.meta.url), "utf8"));
  assert.equal(inventory.sourceCommit, "70c0d9c37f6435c480b87083af8d1cbd4fa7098d");
  for (const [id, implementation] of [[6, "StreamSplitWallet"], [7, "StreamRevenueEscrow"], [10, "StreamClaimRouter"]]) {
    assert.ok(inventory.roles.find(row => row.id === id).implementations.includes(implementation));
  }
  assert.notEqual(inventory.sourceCommit, fixture.sourceCommit);
});

function literalDeclarations(path) {
  const source = ts.createSourceFile(path, readFileSync(new URL(path, import.meta.url), "utf8"), ts.ScriptTarget.Latest, true);
  const declarations = new Map();
  for (const statement of source.statements) if (ts.isVariableStatement(statement)) {
    for (const entry of statement.declarationList.declarations) if (ts.isIdentifier(entry.name)) declarations.set(entry.name.text, entry.initializer);
  }
  function value(node) {
    if (ts.isStringLiteral(node) || ts.isNoSubstitutionTemplateLiteral(node)) return node.text;
    if (ts.isIdentifier(node)) return value(declarations.get(node.text));
    if (ts.isTemplateExpression(node)) return node.head.text + node.templateSpans.map(span => value(span.expression) + span.literal.text).join("");
    if (ts.isArrayLiteralExpression(node)) return node.elements.map(value);
    if (ts.isCallExpression(node) && node.expression.getText(source) === "Object.freeze") return value(node.arguments[0]);
    if (ts.isNewExpression(node) && node.expression.getText(source) === "Interface") return value(node.arguments[0]);
    throw Error(`Nonliteral ABI expression in ${path}: ${node?.getText(source)}`);
  }
  return name => value(declarations.get(name));
}

test("public pull and escrow ABI literals match compiler fields, selectors, events and errors", () => {
  function fields(actual, expected, label) {
    assert.equal(actual.length, expected.length, label);
    for (let i = 0; i < expected.length; i++) {
      const a = actual[i], e = expected[i];
      // Solidity-generated mapping getters have unnamed parameters; local labels
      // do not change their ABI. Named tuple members remain exact object keys.
      if (e.name) assert.equal(a.name, e.name, `${label}/${e.name}`);
      assert.equal(a.format("sighash"), e.format("sighash"), label);
      assert.equal(a.indexed === true, e.indexed === true, label);
      if (e.baseType === "array") fields([a.arrayChildren], [e.arrayChildren], label);
      if (e.baseType === "tuple") fields(a.components, e.components, label);
    }
  }
  for (const [path, name, key] of [
    ["../src/current-revenue-pull.ts", "REVENUE_PULL_WALLET_ABI", "wallet"],
    ["../src/current-revenue-pull.ts", "REVENUE_PULL_ROUTER_ABI", "router"],
    ["../src/current-revenue-escrow.ts", "CURRENT_REVENUE_ESCROW_ABI", "escrow"],
  ]) {
    const source = new Interface(literalDeclarations(path)(name)), original = compiledInterfaces[key];
    for (const fragment of source.fragments) {
      const signature = fragment.format("sighash");
      const expected = fragment.type === "event" ? original.getEvent(signature)
        : fragment.type === "error" ? original.getError(signature) : original.getFunction(signature);
      assert.ok(expected, `${key}/${signature}`);
      assert.equal(fragment.format("minimal"), expected.format("minimal"), `${key}/${signature}`);
      fields(fragment.inputs, expected.inputs, `${key}/${signature}/input`);
      if (expected.outputs) fields(fragment.outputs, expected.outputs, `${key}/${signature}/output`);
    }
    for (const method of scope[key]) assert.ok(source.getFunction(method), `${name}/${method}`);
  }
});

test("workflow protocol reads and receipt event layouts match complete compiler output", () => {
  for (const [path, names] of [
    ["../src/current-revenue-pull-workflow.ts", ["assetAbi", "tokenAbi", "gasAbi"]],
    ["../src/current-revenue-escrow-workflow.ts", ["abi"]],
  ]) {
    const read = literalDeclarations(path);
    for (const name of names) {
      for (const fragment of new Interface(read(name)).fragments) {
        const signature = fragment.format("sighash");
        const candidates = Object.values(compiledInterfaces).map(abi => fragment.type === "event"
          ? abi.getEvent(signature) : fragment.type === "error" ? abi.getError(signature) : abi.getFunction(signature)).filter(Boolean);
        assert.ok(candidates.length, `${path}/${signature}`);
        const match = candidates.find(candidate => candidate.format("minimal") === fragment.format("minimal"));
        assert.ok(match, `${path}/${signature}: return type, mutability or indexed field mismatch`);
        function tupleNames(actual, expected, tuple = false) {
          for (let i = 0; i < expected.length; i++) {
            const a = actual[i], e = expected[i];
            if (tuple || fragment.type === "event") assert.equal(a.name, e.name, `${path}/${signature}/${e.name}`);
            if (e.baseType === "array") tupleNames([a.arrayChildren], [e.arrayChildren]);
            if (e.baseType === "tuple") tupleNames(a.components, e.components, true);
          }
        }
        tupleNames(fragment.inputs, match.inputs);
        if (match.outputs) tupleNames(fragment.outputs, match.outputs);
      }
    }
  }
});
