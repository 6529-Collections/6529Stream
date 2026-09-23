import test from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { posix } from "node:path";
import { AbiCoder, FunctionFragment, Interface, ParamType, ZeroAddress, ZeroHash, getAddress, id, keccak256 } from "ethers";
import ts from "typescript";
import * as native from "../dist/current-canonical-native-dutch.js";
import * as token from "../dist/current-erc20-dutch.js";
import { fixture, compiledInterfaces as compiled } from "./current-canonical-dutch-fixture.mjs";
import { solidityImports } from "../scripts/generate-current-entropy-policy-succession-fixture.mjs";

const sha = value => createHash("sha256").update(value).digest("hex");
const fields = tuple => tuple.components.map(field => [field.name, field.type]);
const authorizationFields = [
  ["chainId", "uint256"], ["saleAdapter", "address"], ["mintManager", "address"], ["collectionId", "uint256"],
  ["phaseId", "bytes32"], ["saleId", "bytes32"], ["saleKind", "uint8"], ["revenueClass", "bytes32"],
  ["expectedPrimaryPolicyHash", "bytes32"], ["primaryPolicyMode", "uint8"], ["initialRecipientsHash", "bytes32"],
  ["beneficiariesHash", "bytes32"], ["tokenDataArrayHash", "bytes32"], ["mintCommitmentsHash", "bytes32"],
  ["payer", "address"], ["executor", "address"], ["asset", "address"], ["unitPrice", "uint256"], ["quantity", "uint256"],
  ["contentSelectionHash", "bytes32"], ["policyHash", "bytes32"], ["nonce", "bytes32"], ["deadline", "uint64"], ["finalizeBy", "uint64"],
];
const scheduleFields = [["startPrice", "uint96"], ["restingPrice", "uint96"], ["startTime", "uint64"],
  ["endTime", "uint64"], ["decayKind", "uint8"], ["stepSeconds", "uint32"], ["stepAmount", "uint96"]];

test("canonical Dutch witness retains ABI121's exact committed bridge and runtime qualification", () => {
  assert.equal(fixture.sourceCommit, "6536c25895ae12eb9d702da9361f067152060d9b");
  assert.equal(fixture.sourceTree, "d4b524e8125570855880f96fe42da5b3fa9c55ba");
  assert.equal(fixture.compilerReportedCommit, "0f30e1d56d145712a1b3cae69a73b233e036e1d9");
  assert.equal(fixture.sourceCount, 3033);
  assert.equal(fixture.literalBytes, 35_616_310);
  assert.equal(fixture.inputSha256, "3c29417776dfd5a5a14c91cd759cb0c84ff336886081dd6e576c3825271fc531");
  assert.equal(fixture.outputSha256, "bc0ad0abc35eeae5e9e645da7fa3ddc6c5faf6474a841952941992c6fa4804ff");
  const bridge = fixture.committedSourceBridge;
  assert.equal(bridge.sha256, "78ba92fd9390ce976a0b5b5ff88476c2a916346acabe64af64f81cf6295c1f7b");
  assert.equal(bridge.commit, fixture.sourceCommit);
  assert.equal(bridge.sources, 3033);
  assert.equal(Object.keys(bridge.committedBlobSHA256).length, 3033);
  assert.deepEqual(bridge.mismatches, []);
  for (const [path, hash] of Object.entries(fixture.sourceHashes)) assert.equal(bridge.committedBlobSHA256[path], hash, path);
  assert.match(fixture.sourceBinding, /byte-for-byte/);
  assert.match(fixture.qualification, /all 24 authorization fields/);
  assert.match(fixture.qualification, /Native reveal funding remains separate from token price/);
  assert.match(fixture.qualification, /Native execution.*remain separately qualified/);
});

test("all 74 complete compiler ABIs preserve 1426 original method identifiers", () => {
  assert.equal(Object.keys(fixture.abis).length, 74);
  assert.equal(Object.values(fixture.abis).reduce((count, abi) => count + abi.length, 0), 2688);
  let count = 0;
  for (const [key, abi] of Object.entries(fixture.abis)) {
    assert.equal(fixture.selections[key].full, true, key);
    const functions = abi.filter(item => item.type === "function");
    assert.equal(functions.length, Object.keys(fixture.methodIdentifiers[key]).length, key);
    for (const item of functions) {
      const fragment = FunctionFragment.from(item), signature = fragment.format("sighash");
      assert.equal(fixture.methodIdentifiers[key][signature], id(signature).slice(2, 10), `${key}/${signature}`);
      assert.equal(compiled[key].getFunction(signature).format("full"), fragment.format("full"));
      count++;
    }
  }
  assert.equal(count, 1426);
});

test("the 466-source closure and 15 interpretation documents retain exact bytes", () => {
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
  assert.equal(visited.size, 466);
  assert.deepEqual([...visited].sort(), Object.keys(fixture.sourceHashes).sort());
  assert.deepEqual(Object.keys(fixture.sourceHashes), Object.keys(fixture.sourceTexts));
  assert.equal(Object.values(fixture.sourceTexts).reduce((bytes, source) => bytes + Buffer.byteLength(source), 0), 2_818_247);
  assert.equal(Object.keys(fixture.documents).length, 15);
  for (const [path, document] of Object.entries(fixture.documents)) {
    assert.equal(sha(document.text), document.sha256, path);
    assert.equal(Buffer.byteLength(document.text), document.byteLength, path);
  }
});

test("both Dutch families and historical Manager revocation keep canonical Sales24", () => {
  for (const key of ["nativeDutch", "erc20Dutch"]) {
    assert.deepEqual(fields(compiled[key].getFunction("authorizationDigest").inputs[0]), authorizationFields, key);
  }
  assert.deepEqual(fields(compiled.nativeDutch.getFunction("purchaseSigned").inputs[1]), authorizationFields);
  const execution = compiled.erc20Dutch.getFunction("previewDutchExecution").inputs[0];
  assert.deepEqual(execution.components.map(field => field.name), ["purchase", "authorization", "signature"]);
  assert.deepEqual(fields(execution.components[1]), authorizationFields);
  assert.equal(execution.components[0].format("sighash"), compiled.nativeDutch.getFunction("purchasePublic").inputs[0].format("sighash"));
  const revoke = compiled.revocation.getFunction("voidMintImmediateSaleAuthorization");
  assert.deepEqual(fields(revoke.inputs[0]), authorizationFields);
  assert.equal(revoke.selector, "0xf0627264");
  assert.equal(revoke.stateMutability, "nonpayable");
  assert.equal(compiled.nativeDutch.getFunction("immediateSaleAuthorizationBinding").outputs.length, 7);
  assert.equal(compiled.erc20Dutch.getFunction("immediateSaleAuthorizationBinding").outputs.length, 7);
});

test("immutable configurations preserve common sale fields and exact Dutch schedule widths", () => {
  const native = compiled.nativeDutch.getFunction("registerSale").inputs[0];
  const token = compiled.erc20Dutch.getFunction("registerDutchSale").inputs[0];
  assert.deepEqual(native.components.map(field => field.name), ["sale", "schedule", "declaredFree"]);
  assert.deepEqual(token.components.map(field => field.name), ["sale", "asset", "paymentAdapter", "schedule", "declaredFree"]);
  assert.equal(native.components[0].components.length, 14);
  assert.equal(native.components[0].format("sighash"), token.components[0].format("sighash"));
  assert.deepEqual(fields(native.components[1]), scheduleFields);
  assert.deepEqual(fields(token.components[3]), scheduleFields);
  for (const key of ["nativeDutch", "erc20Dutch"]) {
    const receipt = compiled[key].getFunction("executionReceipt").outputs[0];
    assert.equal(receipt.components.length, 11);
    assert.deepEqual(fields(receipt).slice(-3), [["chargedAmount", "uint256"], ["revealFee", "uint256"], ["revealCredit", "uint256"]]);
  }
});

test("wallet Payment entries retain maximum permits and payable native funding, distinct from callbacks", () => {
  const names = ["settleERC20DutchSaleByPayer", "settleERC20DutchSaleWithIntent", "settleERC20DutchSaleWithEIP2612Permit", "settleERC20DutchSaleWithPermit2"];
  const functions = compiled.dutchPayments.fragments.filter(fragment => fragment.type === "function");
  assert.deepEqual(functions.map(fragment => fragment.name).sort(), names.sort());
  for (const name of names) {
    const method = compiled.dutchPayments.getFunction(name);
    assert.equal(method.stateMutability, "payable");
    assert.deepEqual(fields(method.inputs[0]), [["saleAdapter", "address"], ["saleAdapterCodeHash", "bytes32"],
      ["saleId", "bytes32"], ["saleConfigHash", "bytes32"], ["maxAmount", "uint256"], ["executionData", "bytes"]]);
    assert.equal(method.outputs[0].components[0].name, "revenueOutcome");
    assert.equal(method.outputs[0].components[2].components.length, 12);
    assert.equal(compiled.payment.getFunction(name).format("minimal"), method.format("minimal"));
  }
  for (const name of ["settleERC20DutchSaleWithEIP2612Permit", "settleERC20DutchSaleWithPermit2"]) {
    const maximum = compiled.dutchPayments.getFunction(name).inputs[1];
    assert.deepEqual(maximum.components.map(field => field.name), ["permittedAmount", "authorization"]);
    assert.equal(maximum.components[0].type, "uint256");
  }
  for (const name of ["executeERC20PreRevenueSingleStep", "executeERC20DutchFreeMint"]) {
    assert.equal(compiled.erc20Dutch.getFunction(name).stateMutability, "payable");
    assert.equal(compiled.dutchPayments.getFunction(name), null);
  }
  for (const name of ["purchaseSigned", "purchasePublic"]) assert.equal(compiled.nativeDutch.getFunction(name).stateMutability, "payable");
  for (const key of ["nativeDutch", "erc20Dutch"]) {
    assert.equal(compiled[key].getFunction("claimRefund").selector, "0xc6b49688");
    assert.equal(compiled[key].getFunction("claimRefund").stateMutability, "nonpayable");
  }
});

test("earlier profiles retain selectors and tuples with only ADR0045's explicit payable widening", () => {
  const native = JSON.parse(readFileSync(new URL("./fixtures/current-canonical-native-sales-abi.json", import.meta.url), "utf8"));
  const token = JSON.parse(readFileSync(new URL("./fixtures/current-erc20-primary-offer-abi.json", import.meta.url), "utf8"));
  assert.equal(native.sourceCommit, "4fa32ae1c9206b05be848c7553c6492f516a7bfe");
  assert.equal(token.sourceCommit, "2e0fca1aef41a023d76a9717651a699bbd7db155");
  const payableWidening = new Set(["settleERC20PrimarySaleByPayer", "settleERC20PrimarySaleWithIntent",
    "settleERC20PrimarySaleWithEIP2612Permit", "settleERC20PrimarySaleWithPermit2"]);
  const widened = new Set();
  for (const [abi, target] of [[native.abis.immediate, compiled.immediate], [native.abis.claim, compiled.claim], [token.abis.payment, compiled.payment]]) {
    for (const fragment of new Interface(abi).fragments.filter(fragment => fragment.type === "function")) {
      const current = target.getFunction(fragment.format("sighash"));
      if (target === compiled.payment && payableWidening.has(fragment.name)) {
        assert.equal(fragment.stateMutability, "nonpayable");
        assert.equal(current.stateMutability, "payable");
        assert.equal(current.format("minimal").replace(" payable", ""), fragment.format("minimal"));
        widened.add(fragment.name);
      } else assert.equal(current.format("minimal"), fragment.format("minimal"));
    }
  }
  assert.deepEqual(widened, payableWidening);
  assert.match(fixture.documents["docs/adr/0045-native-reveal-fees-for-token-sales.md"].text, /widens the relevant entrypoints.*payable/s);
  assert.equal(compiled.nativeDutch.getEvent("FreeDutchExecuted").name, "FreeDutchExecuted");
  assert.equal(compiled.erc20Dutch.getEvent("FreeDutchExecuted"), null);
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


function sameFields(actual, expected, signature, tuple = false) {
  assert.equal(actual.length, expected.length, signature);
  for (let i = 0; i < expected.length; i++) {
    const a = actual[i], e = expected[i];
    assert.equal(a.format("sighash"), e.format("sighash"), signature);
    if (tuple) assert.equal(a.name, e.name, signature + "/" + e.name);
    if (e.baseType === "array") sameFields([a.arrayChildren], [e.arrayChildren], signature);
    if (e.baseType === "tuple") sameFields(a.components, e.components, signature, true);
  }
}

test("new structural tuple codecs retain exact compiler widths and nested field names", () => {
  const native = literalReader(new URL("../src/current-canonical-native-dutch.ts", import.meta.url));
  const token = literalReader(new URL("../src/current-erc20-dutch.ts", import.meta.url));
  const nativeConfig = compiled.nativeDutch.getFunction("registerSale").inputs[0];
  const tokenConfig = compiled.erc20Dutch.getFunction("registerDutchSale").inputs[0];
  const candidates = [
    [native, "CANONICAL_NATIVE_DUTCH_CONFIGURATION_TUPLE", nativeConfig],
    [native, "CANONICAL_NATIVE_DUTCH_SCHEDULE_TUPLE", nativeConfig.components[1]],
    [native, "CANONICAL_NATIVE_DUTCH_RECORD_TUPLE", compiled.nativeDutch.getFunction("saleRecord").outputs[0]],
    [native, "CANONICAL_NATIVE_DUTCH_CANDIDATE_TUPLE", compiled.nativeDutch.getFunction("previewSignedPurchase").outputs[0]],
    [token, "ERC20_DUTCH_CONFIGURATION_TUPLE", tokenConfig],
    [token, "ERC20_DUTCH_EXECUTION_TUPLE", compiled.erc20Dutch.getFunction("previewDutchExecution").inputs[0]],
    [token, "ERC20_DUTCH_RECORD_TUPLE", compiled.erc20Dutch.getFunction("dutchSaleRecord").outputs[0]],
    [token, "ERC20_DUTCH_CANDIDATE_TUPLE", compiled.erc20Dutch.getFunction("previewDutchExecution").outputs[0]],
    [token, "ERC20_DUTCH_RESULT_TUPLE", compiled.dutchPayments.getFunction("settleERC20DutchSaleByPayer").outputs[0]],
    [token, "ERC20_DUTCH_PAYMENT_REQUEST_TUPLE", compiled.dutchPayments.getFunction("settleERC20DutchSaleByPayer").inputs[0]],
    [token, "ERC20_DUTCH_PAYMENT_INTENT_TUPLE", compiled.dutchPayments.getFunction("settleERC20DutchSaleWithIntent").inputs[1]],
    [token, "ERC20_DUTCH_EIP2612_MAXIMUM_TUPLE", compiled.dutchPayments.getFunction("settleERC20DutchSaleWithEIP2612Permit").inputs[1]],
    [token, "ERC20_DUTCH_PERMIT2_MAXIMUM_TUPLE", compiled.dutchPayments.getFunction("settleERC20DutchSaleWithPermit2").inputs[1]],
  ];
  for (const [read, name, expected] of candidates) sameFields([ParamType.from(read(name))], [expected], name);
});

test("private workflow native reads and event ABIs preserve complete compiler shapes", () => {
  const read = literalReader(new URL("../src/current-canonical-dutch-workflow-internal.ts", import.meta.url));
  for (const fragment of new Interface(read("abi")).fragments) {
    const signature = fragment.format("sighash");
    const candidates = Object.values(compiled).map(iface => fragment.type === "event"
      ? iface.getEvent(signature) : fragment.type === "error" ? iface.getError(signature) : iface.getFunction(signature)).filter(Boolean);
    assert.ok(candidates.length, signature);
    const expected = candidates.find(candidate => candidate.format("minimal") === fragment.format("minimal"));
    assert.ok(expected, signature + ": mutability, outputs or indexed fields differ");
    sameFields(fragment.inputs, expected.inputs, signature, fragment.type === "event");
    if (expected.outputs) sameFields(fragment.outputs, expected.outputs, signature);
  }
});

test("public operational ABIs match their concrete original carrier and Payment products", () => {
  for (const [fragments, original] of [[native.CURRENT_CANONICAL_NATIVE_DUTCH_ABI, compiled.nativeDutch],
    [token.CURRENT_ERC20_DUTCH_ABI, compiled.erc20Dutch], [token.CURRENT_ERC20_DUTCH_PAYMENT_ABI, compiled.payment]]) {
    for (const fragment of new Interface(fragments).fragments) {
      const signature = fragment.format("sighash");
      const expected = original.getFunction(signature);
      assert.ok(expected, signature);
      assert.equal(fragment.format("minimal"), expected.format("minimal"));
      sameFields(fragment.inputs, expected.inputs, signature);
      sameFields(fragment.outputs, expected.outputs, signature);
    }
  }
});

const coder = AbiCoder.defaultAbiCoder();
const address = value => getAddress("0x" + BigInt(value).toString(16).padStart(40, "0"));
const coordinate = { chainId: (1n << 150n) + 3n, adapter: address(1), manager: address(2), ledger: address(3), recorder: address(4) };
const tokenCoordinate = { ...coordinate, paymentAdapter: address(5) };
const encodeHash = (types, values) => keccak256(coder.encode(types, values));

test("family configuration, request and public replay hashes use original domains and compiler tuples", () => {
  const schedule = { startPrice: 1000n, restingPrice: 100n, startTime: 100n, endTime: 300n, decayKind: 0n, stepSeconds: 0n, stepAmount: 0n };
  const sale = { collectionId: (1n << 140n) + 9n, phaseId: id("phase"), saleKind: 3n, authorityMode: 1n,
    unitPrice: 1000n, startsAt: 100n, endsAt: 300n, manualClose: false, saleSupplyLimit: 10n,
    mintPolicyHash: id("mint policy"), expectedPrimaryPolicyHash: id("primary policy"), primaryPolicyMode: 0n,
    priceCounterId: id("price counter"), signer: { authorizer: address(10), kind: 1n, evidenceHash: id("signer evidence"),
      revision: 1n, installingAuthority: address(11) } };
  const nativeConfig = { sale, schedule, declaredFree: false };
  const tokenConfig = { sale: { ...sale, unitPrice: 0n, endsAt: 301n }, asset: address(12), paymentAdapter: address(5), schedule, declaredFree: false };
  const purchase = { saleId: id("sale"), payer: address(20), executor: address(20), initialRecipient: address(21),
    beneficiary: address(22), tokenData: "0x000102030400", mintCommitment: id("mint"), resolverData: "0x010203", executionNonce: 1n << 180n };
  const purchaseType = compiled.nativeDutch.getFunction("purchasePublic").inputs[0];
  const cases = [
    { c: coordinate, config: nativeConfig, tuple: compiled.nativeDutch.getFunction("registerSale").inputs[0],
      configDomain: "6529STREAM_NATIVE_DUTCH_SALES_CONFIG_V1", requestDomain: "6529STREAM_NATIVE_DUTCH_SALES_REQUEST_V1",
      publicDomain: "6529STREAM_NATIVE_PUBLIC_DUTCH_MINT_AUTHORIZATION_V1", idDomain: "6529STREAM_NATIVE_DUTCH_SALES_ID_V1",
      configHash: native.canonicalNativeDutchConfigurationHash, requestHash: native.canonicalNativeDutchRequestHash,
      publicId: native.canonicalNativeDutchPublicAuthorizationId, saleId: native.canonicalNativeDutchSaleId },
    { c: tokenCoordinate, config: tokenConfig, tuple: compiled.erc20Dutch.getFunction("registerDutchSale").inputs[0],
      configDomain: "6529STREAM_ERC20_STANDARD_DUTCH_CONFIG_V1", requestDomain: "6529STREAM_ERC20_DUTCH_REQUEST_V1",
      publicDomain: "6529STREAM_ERC20_DUTCH_PUBLIC_AUTHORIZATION_V1", idDomain: "6529STREAM_ERC20_DUTCH_SALE_ID_V1",
      configHash: token.erc20DutchConfigurationHash, requestHash: token.erc20DutchRequestHash,
      publicId: token.erc20DutchPublicAuthorizationId, saleId: token.erc20DutchSaleId },
  ];
  const hashes = [];
  for (const item of cases) {
    const configHash = encodeHash(["bytes32", "uint256", "address", item.tuple], [id(item.configDomain), item.c.chainId, item.c.adapter, item.config]);
    assert.equal(item.configHash(item.c, item.config), configHash);
    const requestHash = encodeHash(["bytes32", "uint256", "address", "bytes32", purchaseType], [id(item.requestDomain), item.c.chainId, item.c.adapter, configHash, purchase]);
    assert.equal(item.requestHash(item.c, configHash, purchase), requestHash);
    assert.equal(item.publicId(item.c, configHash, requestHash), encodeHash(["bytes32", "uint256", "address", "address", "bytes32", "bytes32"],
      [id(item.publicDomain), item.c.chainId, item.c.adapter, item.c.manager, configHash, requestHash]));
    assert.equal(item.saleId(item.c, sale.collectionId, sale.phaseId, 1n << 190n), encodeHash(["bytes32", "uint256", "address", "uint256", "bytes32", "uint256"],
      [id(item.idDomain), item.c.chainId, item.c.adapter, sale.collectionId, sale.phaseId, 1n << 190n]));
    assert.notEqual(item.configHash(item.c, { ...item.config, declaredFree: true }), configHash);
    assert.notEqual(item.requestHash(item.c, configHash, { ...purchase, tokenData: "0x0001020304" }), requestHash);
    hashes.push(configHash, requestHash);
  }
  assert.equal(new Set(hashes).size, 4);
  assert.equal(native.canonicalNativeDutchScheduleHash(coordinate, purchase.saleId, schedule),
    encodeHash(["bytes32", "uint256", "address", "bytes32", compiled.nativeDutch.getFunction("registerSale").inputs[0].components[1]],
      [id("6529STREAM_DUTCH_SCHEDULE_V1"), coordinate.chainId, coordinate.adapter, purchase.saleId, schedule]));
  const publicExecution = token.erc20DutchPublicExecution(purchase);
  assert.equal(token.erc20DutchSaleExecutionHash(publicExecution), encodeHash([compiled.erc20Dutch.getFunction("previewDutchExecution").inputs[0]], [publicExecution]));
});

test("price-only drift changes candidate commitment without adding price to execution or paid settlement identity", () => {
  const nativeCandidate = { saleAdapter: coordinate.adapter, executor: address(20),
    sale: { settlementId: id("sale"), revenueClass: id("PRIMARY_SALE"), policyMode: 0n, collectionId: 7n,
      tokenId: 0n, saleNonce: 1n, payer: address(20), poster: ZeroAddress, beneficiary: address(22), amount: 700n, expectedPrimaryPolicyHash: id("primary") },
    lifecycleBinding: { saleCreatedAt: 90n, saleAdapterRegistryRevision: 1n },
    executionBinding: { executionId: ZeroHash, executionNonce: 1n << 180n, authorityMode: 2n, saleAuthorizationDigest: ZeroHash },
    orchestrationOrder: 0n, mintManager: coordinate.manager, operationIdentityCommitment: id("operation root"), operationId: id("operation"),
    currentPolicyHash: id("current"), boundPolicyHash: id("bound"),
    rights: { profileId: id("profile"), wallet: address(30), templateId: ZeroHash, assignmentHash: id("assignment"), entriesHash: id("entries") },
    saleExecutionHash: id("source execution") };
  const tokenCandidate = { ...nativeCandidate, asset: address(12), lifecycleBinding: { ...nativeCandidate.lifecycleBinding,
    paymentAdapter: tokenCoordinate.paymentAdapter, paymentAdapterRegistryRevision: 2n } };
  for (const [candidate, derive, commit, tuple] of [
    [nativeCandidate, native.canonicalNativeDutchExecutionId,
      c => native.canonicalNativeDutchCandidateCommitment(coordinate.chainId, coordinate.recorder, c), compiled.nativeDutch.getFunction("previewPublicPurchase").outputs[0]],
    [tokenCandidate, token.erc20DutchExecutionId,
      c => token.erc20DutchCandidateCommitment(coordinate.chainId, tokenCoordinate.paymentAdapter, coordinate.recorder, c), compiled.erc20Dutch.getFunction("previewDutchExecution").outputs[0]],
  ]) {
    const earlier = structuredClone(candidate);
    earlier.executionBinding.executionId = derive(coordinate.chainId, earlier);
    const later = { ...earlier, sale: { ...earlier.sale, amount: 600n } };
    assert.equal(derive(coordinate.chainId, later), earlier.executionBinding.executionId);
    assert.notEqual(commit(later), commit(earlier));
    const expected = candidate.asset
      ? encodeHash(["bytes32", "uint256", "address", "address", tuple], [id("6529STREAM_ERC20_SETTLEMENT_CANDIDATE_V2"), coordinate.chainId, tokenCoordinate.paymentAdapter, coordinate.recorder, earlier])
      : encodeHash(["bytes32", "uint256", "address", tuple], [id("6529STREAM_NATIVE_SETTLEMENT_CANDIDATE_V1"), coordinate.chainId, coordinate.recorder, earlier]);
    assert.equal(commit(earlier), expected);
    const expectedKey = encodeHash(["bytes32", "uint256", "address", "address", "bytes32"],
      [id("6529STREAM_PRIMARY_SETTLEMENT_KEY_V2"), coordinate.chainId, coordinate.recorder, coordinate.adapter, earlier.executionBinding.executionId]);
    assert.equal(token.erc20DutchSettlementKey(coordinate.chainId, coordinate.recorder, coordinate.adapter, derive(coordinate.chainId, later)), expectedKey);
  }
});
