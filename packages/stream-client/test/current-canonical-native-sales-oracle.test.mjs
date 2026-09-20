import test from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { posix } from "node:path";
import { FunctionFragment, Interface, id } from "ethers";
import ts from "typescript";
import { fixture, compiledInterfaces as compiled } from "./current-canonical-native-sales-fixture.mjs";
import { solidityImports } from "../scripts/generate-current-entropy-policy-succession-fixture.mjs";

const sha = value => createHash("sha256").update(value).digest("hex");
const authorizationFields = [
  ["chainId", "uint256"], ["saleAdapter", "address"], ["mintManager", "address"], ["collectionId", "uint256"],
  ["phaseId", "bytes32"], ["saleId", "bytes32"], ["saleKind", "uint8"], ["revenueClass", "bytes32"],
  ["expectedPrimaryPolicyHash", "bytes32"], ["primaryPolicyMode", "uint8"], ["initialRecipientsHash", "bytes32"],
  ["beneficiariesHash", "bytes32"], ["tokenDataArrayHash", "bytes32"], ["mintCommitmentsHash", "bytes32"],
  ["payer", "address"], ["executor", "address"], ["asset", "address"], ["unitPrice", "uint256"], ["quantity", "uint256"],
  ["contentSelectionHash", "bytes32"], ["policyHash", "bytes32"], ["nonce", "bytes32"], ["deadline", "uint64"], ["finalizeBy", "uint64"],
];

test("canonical native callers retain exact ABI113 coordinates and source-only qualification", () => {
  assert.equal(fixture.sourceCommit, "4fa32ae1c9206b05be848c7553c6492f516a7bfe");
  assert.equal(fixture.sourceTree, "36bc632478b81ca929ab0eebec379f0e696f18c5");
  assert.equal(fixture.sourceCount, 2953);
  assert.equal(fixture.literalBytes, 34_614_289);
  assert.equal(fixture.inputSha256, "47ffa8bf3e2089ae875f0cb477b530a37696f598edc86daf8dff4af391468847");
  assert.equal(fixture.outputSha256, "952debfc67638be049507a9d15a7b2eeae0b0ef7a0077174be12a72258642b7e");
  assert.match(fixture.sourceBinding, /byte-for-byte/);
  assert.match(fixture.qualification, /original 24-field Sales-v1/);
  assert.match(fixture.qualification, /SIGNED mode 1 and PUBLIC mode 2/);
  assert.match(fixture.qualification, /Literal zero Claim execution creates no official settlement/);
  assert.match(fixture.qualification, /native contract\/Safe execution/);
});

test("all 52 selected full compiler ABIs preserve 1158 canonical method identifiers", () => {
  assert.equal(Object.keys(fixture.abis).length, 52);
  assert.equal(Object.values(fixture.abis).reduce((count, abi) => count + abi.length, 0), 2234);
  let count = 0;
  for (const [key, abi] of Object.entries(fixture.abis)) {
    assert.equal(fixture.selections[key].full, true, key);
    assert.equal(abi.filter(item => item.type === "function").length, Object.keys(fixture.methodIdentifiers[key]).length, key);
    for (const item of abi.filter(entry => entry.type === "function")) {
      const fragment = FunctionFragment.from(item), signature = fragment.format("sighash");
      assert.equal(fixture.methodIdentifiers[key][signature], id(signature).slice(2, 10), `${key}/${signature}`);
      assert.equal(compiled[key].getFunction(signature).format("full"), fragment.format("full"));
      count++;
    }
  }
  assert.equal(count, 1158);
});

test("canonical native fixture includes the complete 446-source import closure and nine frozen documents", () => {
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
  assert.equal(visited.size, 446);
  assert.deepEqual([...visited].sort(), Object.keys(fixture.sourceHashes).sort());
  assert.deepEqual(Object.keys(fixture.sourceHashes), Object.keys(fixture.sourceTexts));
  assert.equal(Object.values(fixture.sourceTexts).reduce((bytes, source) => bytes + Buffer.byteLength(source), 0), 2_670_223);
  assert.equal(Object.keys(fixture.documents).length, 9);
  for (const [path, document] of Object.entries(fixture.documents)) {
    assert.equal(sha(document.text), document.sha256, path);
    assert.equal(Buffer.byteLength(document.text), document.byteLength, path);
  }
});

test("both signed carriers and historical Manager revocation retain all 24 original fields", () => {
  for (const key of ["immediate", "claim"]) {
    const auth = compiled[key].getFunction("purchaseSigned").inputs[1];
    assert.deepEqual(auth.components.map(field => [field.name, field.type]), authorizationFields, key);
    assert.equal(compiled[key].getFunction("authorizationDigest").inputs[0].format("sighash"), auth.format("sighash"));
    assert.equal(compiled[key].getFunction("previewSignedPurchase").inputs[1].format("sighash"), auth.format("sighash"));
  }
  const revoke = compiled.revocation.getFunction("voidMintImmediateSaleAuthorization");
  assert.deepEqual(revoke.inputs[0].components.map(field => [field.name, field.type]), authorizationFields);
  assert.deepEqual(revoke.inputs.slice(1).map(field => [field.name, field.type]), [
    ["claimedAuthorizer", "address"], ["authorizerKind", "uint8"], ["revocationSignature", "bytes"],
  ]);
  assert.equal(revoke.selector, "0xf0627264");
});

test("operational selectors and payable values remain separate from lifecycle and gas mutations", () => {
  const excluded = ["closeSale", "configureCollectionSigner", "raiseGasParameter", "registerSale", "renounceOwnership",
    "setGlobalPause", "setSalePause", "syncCollectionContest", "transferOwnership"];
  for (const [key, signed, unsigned] of [["immediate", "0xd61482b3", "0x0228284a"], ["claim", "0x2620ec16", "0x0ce9aa11"]]) {
    assert.equal(compiled[key].getFunction("purchaseSigned").selector, signed);
    assert.equal(compiled[key].getFunction("purchasePublic").selector, unsigned);
    for (const method of ["purchaseSigned", "purchasePublic"]) assert.equal(compiled[key].getFunction(method).stateMutability, "payable");
    assert.equal(compiled[key].getFunction("claimRefund").selector, "0xc6b49688");
    assert.equal(compiled[key].getFunction("claimRefund").stateMutability, "nonpayable");
    const writes = fixture.abis[key].filter(item => item.type === "function" && !["view", "pure"].includes(item.stateMutability)).map(item => item.name).sort();
    assert.deepEqual(writes, [...excluded, "purchaseSigned", "purchasePublic", "claimRefund"].sort(), key);
  }
  assert.equal(compiled.revocation.getFunction("voidMintImmediateSaleAuthorization").stateMutability, "nonpayable");
});

test("native candidates, receipts and reveal quotes retain original component widths", () => {
  const immediate = compiled.immediate.getFunction("purchasePublic").inputs[0];
  const claim = compiled.claim.getFunction("purchasePublic").inputs[0];
  assert.deepEqual(claim.components.map(field => field.name), ["mint", "chosenUnitPrice"]);
  assert.equal(claim.components[0].format("sighash"), immediate.format("sighash"));
  assert.equal(claim.components[1].type, "uint256");
  assert.deepEqual(immediate.components.map(field => field.name), ["saleId", "payer", "executor", "initialRecipient",
    "beneficiary", "tokenData", "mintCommitment", "resolverData", "executionNonce"]);
  const candidate = compiled.claim.getFunction("previewPublicPurchase").outputs[0];
  const lifecycle = candidate.components.find(field => field.name === "lifecycleBinding");
  assert.deepEqual(lifecycle.components.map(field => [field.name, field.type]), [["saleCreatedAt", "uint64"], ["saleAdapterRegistryRevision", "uint64"]]);
  assert.equal(candidate.components.some(field => field.name === "asset" || field.name === "paymentAdapter"), false);
  const receipt = compiled.claim.getFunction("executionReceipt").outputs[0];
  assert.equal(receipt.components.length, 11);
  assert.deepEqual(receipt.components.slice(-3).map(field => [field.name, field.type]), [
    ["chargedAmount", "uint256"], ["revealFee", "uint256"], ["revealCredit", "uint256"],
  ]);
  assert.equal(compiled.recorder.getFunction("settlementResult").outputs[0].components.length, 12);
  const quote = compiled.reveal.getFunction("saleRevealQuote").outputs[0].components[2];
  assert.deepEqual(quote.components.map(field => [field.name, field.type]), [["declared", "bool"], ["requestMode", "uint8"],
    ["revealOwnerRole", "bytes32"], ["requestSLOBlocks", "uint64"], ["revealFeePerTokenWei", "uint256"]]);
});

test("older immediate fixture and original public identifiers keep their own profiles", () => {
  const old = JSON.parse(readFileSync(new URL("./fixtures/current-native-immediate-abi.json", import.meta.url), "utf8"));
  assert.equal(old.sourceCommit, "bfefc417");
  assert.notEqual(old.sourceCommit, fixture.sourceCommit);
  const source = path => fixture.sourceTexts[`smart-contracts/domains/mint/${path}.sol`];
  assert.match(source("StreamNativeImmediateSalesRuntime"), /6529STREAM_NATIVE_PUBLIC_MINT_AUTHORIZATION_V1/);
  assert.match(source("StreamNativeClaimSalesRuntime"), /6529STREAM_NATIVE_PUBLIC_CLAIM_MINT_AUTHORIZATION_V1/);
  assert.match(source("StreamCanonicalSaleAuthorization"), /actual\.nonce == 0/);
  assert.match(source("StreamCanonicalSaleAuthorization"), /actual\.deadline < block\.timestamp/);
  assert.ok(compiled.claim.getEvent("FreeClaimExecuted"));
  assert.equal(compiled.immediate.getEvent("FreeClaimExecuted"), null);
});

// Read literal ABI expressions, including tuple constants imported from existing
// helpers. Do not execute the workflow or replace compiler ABI names/types.
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
  function value(node) {
    if (!node) throw Error(`Missing literal declaration in ${url.pathname}`);
    if (ts.isStringLiteral(node) || ts.isNoSubstitutionTemplateLiteral(node)) return node.text;
    if (ts.isIdentifier(node)) return read(node.text);
    if (ts.isPropertyAccessExpression(node) && ts.isIdentifier(node.expression) && namespaces.has(node.expression.text)) {
      return literalReader(namespaces.get(node.expression.text), cache)(node.name.text);
    }
    if (ts.isTemplateExpression(node)) return node.head.text + node.templateSpans.map(span => value(span.expression) + span.literal.text).join("");
    if (ts.isArrayLiteralExpression(node)) return node.elements.map(value);
    if (ts.isCallExpression(node) && node.expression.getText(source) === "Object.freeze") return value(node.arguments[0]);
    if (ts.isNewExpression(node) && node.expression.getText(source) === "Interface") return value(node.arguments[0]);
    throw Error(`Nonliteral ABI expression in ${url.pathname}: ${node.getText(source)}`);
  }
  return read;
}

test("workflow reads and event tuples match full ABI113 compiler shapes including imported receipts", () => {
  const read = literalReader(new URL("../src/current-canonical-native-sales-workflow.ts", import.meta.url));
  for (const fragment of new Interface(read("abi")).fragments) {
    const signature = fragment.format("sighash");
    const candidates = Object.values(compiled).map(abi => fragment.type === "event"
      ? abi.getEvent(signature) : fragment.type === "error" ? abi.getError(signature) : abi.getFunction(signature)).filter(Boolean);
    assert.ok(candidates.length, signature);
    const expected = candidates.find(candidate => candidate.format("minimal") === fragment.format("minimal"));
    assert.ok(expected, `${signature}: mutability, output or indexed shape differs`);
    function fields(actual, original, tuple = false) {
      assert.equal(actual.length, original.length, signature);
      for (let i = 0; i < original.length; i++) {
        const a = actual[i], e = original[i];
        if (tuple || fragment.type === "event") assert.equal(a.name, e.name, `${signature}/${e.name}`);
        if (e.baseType === "array") fields([a.arrayChildren], [e.arrayChildren]);
        if (e.baseType === "tuple") fields(a.components, e.components, true);
      }
    }
    fields(fragment.inputs, expected.inputs);
    if (expected.outputs) fields(fragment.outputs, expected.outputs);
  }
});
