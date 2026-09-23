import test from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import ts from "typescript";
import {
  AbiCoder, Interface, ParamType, ZeroAddress, ZeroHash,
  concat, getAddress, id, keccak256, toUtf8Bytes
} from "ethers";
import * as client from "../dist/current-direct-conservation.js";
import { requireSafeExecution, toSafeCall } from "../dist/safe.js";
import { createSafeCallPlan, verifySafeCallPlan } from "../dist/safe-plan.js";

const fixture = JSON.parse(readFileSync(
  new URL("./fixtures/current-direct-conservation-abi.json", import.meta.url), "utf8"
));
const abi = Object.fromEntries(
  Object.entries(fixture.abis).map(([key, value]) => [key, new Interface(value)])
);
const coder = AbiCoder.defaultAbiCoder();
const hash = (types, values) => keccak256(coder.encode(types, values));
const address = value => getAddress(`0x${BigInt(value).toString(16).padStart(40, "0")}`);
const source = suffix => Object.entries(fixture.sourceTexts)
  .find(([path]) => path.endsWith(`/${suffix}`))[1];
const child = (tuple, name) => tuple.components.find(field => field.name === name);

function specimen(param, empty = false) {
  if (param.baseType === "tuple") {
    return Object.fromEntries(param.components.map(field => [field.name, specimen(field, empty)]));
  }
  if (param.type === "address") return empty ? ZeroAddress : address(91);
  if (param.type === "bool") return !empty;
  if (param.type.startsWith("uint")) {
    return empty ? 0n : (1n << BigInt(Number(param.type.slice(4)) - 1)) + 7n;
  }
  assert.equal(param.type, "bytes32");
  return empty ? ZeroHash : id(`original ${param.name}`);
}

test("DIRECT fixture preserves the exact source and separately qualified native evidence", () => {
  assert.equal(fixture.sourceCommit, "8bb6dfe2957542f641b0d558e1cfd48e1b39ae98");
  assert.equal(client.DIRECT_CONSERVATION_SOURCE, fixture.sourceCommit);
  assert.equal(fixture.sourceTree, "d521268a11aaeb867c6c43f9a8140042a187c1cc");
  assert.equal(fixture.inputSha256, "5828313cd35628ec3935cc0447faefb592b12b1ef79b2ac0ae225b2106c7152c");
  assert.equal(fixture.outputSha256, "573e271eb99807b2847e47502d3a7f3fc751ce07e07918d5ad5791062732e55a");
  assert.equal(fixture.sourceCount, 2591);
  assert.equal(Object.keys(fixture.abis).length, 35);
  assert.equal(Object.values(fixture.abis).reduce((count, rows) => count + rows.length, 0), 1944);
  assert.equal(Object.keys(fixture.sourceHashes).length, 1232);
  assert.equal(Object.keys(fixture.sourceTexts).length, 69);
  assert.equal(Object.keys(fixture.documents).length, 3);
  for (const [path, text] of Object.entries(fixture.sourceTexts)) {
    assert.equal(createHash("sha256").update(text).digest("hex"), fixture.sourceHashes[path], path);
  }
  for (const [path, document] of Object.entries(fixture.documents)) {
    assert.equal(createHash("sha256").update(document.text).digest("hex"), document.sha256, path);
    assert.equal(toUtf8Bytes(document.text).length, document.byteLength, path);
  }
  assert.equal(fixture.separateRuntimeEvidence.sourceCommit, "844d5f323acb459adec33db7b218901545ec84c2");
  assert.deepEqual(fixture.separateRuntimeEvidence.suites, {
    floorLedger: 34, typedDirectFloor: 25, nativeProvider: 14
  });
  assert.equal(fixture.separateRuntimeEvidence.tests, 73);
  assert.match(fixture.separateRuntimeEvidence.qualification, /excludes original adapter signatures/);
  assert.match(fixture.qualification, /whole-paid-transaction gas target/);
});

const receiptType = abi.directReceipt.getFunction("directPrimarySaleReceipt").outputs[0];
const bindingsType = abi.directReceipt.getFunction("directPrimaryBindings").outputs[0];
const floorType = abi.directFloor.getFunction("directPrimarySaleFloorReceipt").outputs[0];
const firstType = abi.floor.getFunction("firstSale").outputs[0];
const releaseType = abi.floor.getFunction("releaseFloorReceipt").outputs[0];
const configType = abi.erc20Sale.getFunction("registerSale").inputs[0];
const sourceType = abi.floor.getFunction("sourceAt").outputs[0];
const coordinates = productKind => ({
  chainId: 31337n, core: address(1), product: address(2), productKind
});
const floorCoordinates = { chainId: 31337n, core: address(1), floor: address(3) };

test("complete codecs preserve original tuple field names, widths and all-zero history", () => {
  const rows = [
    ["Bindings", bindingsType], ["Receipt", receiptType], ["FloorReceipt", floorType],
    ["CollectionFacts", child(firstType, "facts")],
    ["ReleaseContext", child(releaseType, "context")],
    ["ReleaseFacts", child(releaseType, "facts")], ["Source", sourceType],
    ["FirstSaleReceipt", firstType], ["ReleaseReceipt", releaseType],
    ["NativeAuthorization", abi.nativeSale.getFunction("buy").inputs[0]],
    ["ERC20Authorization", abi.erc20Sale.getFunction("buy").inputs[0]],
    ["ERC20Config", configType],
    ["ERC20SaleRecord", abi.erc20Sale.getFunction("saleRecord").outputs[0]],
    ["AuctionAuthorization", abi.auction.getFunction("createAuction").inputs[0]],
    ["Auction", abi.auction.getFunction("auction").outputs[0]],
    ["PaymentIntent", abi.erc20Sale.getFunction("buy").inputs[4]],
    ["PaymentRevocation", ParamType.from("tuple(address payer,bytes32 nonce,uint64 deadline)")]
  ];
  for (const [name, tuple] of rows) {
    for (const empty of [false, true]) {
      const value = specimen(tuple, empty);
      const encoded = coder.encode([tuple], [value]);
      assert.equal(client[`encodeDirectConservation${name}`](value), encoded, name);
      assert.deepEqual(client[`decodeDirectConservation${name}`](encoded), value, name);
      assert.throws(() => client[`decodeDirectConservation${name}`](encoded + "00"), name);
      assert.throws(() => client[`encodeDirectConservation${name}`]({ ...value, invented: 1n }), name);
    }
  }
  assert.equal((coder.encode([bindingsType], [specimen(bindingsType)]).length - 2) / 2, 192);
  assert.equal((coder.encode([receiptType], [specimen(receiptType)]).length - 2) / 2, 512);
  assert.equal(child(receiptType, "createdAt").type, "uint64");
  assert.equal(child(receiptType, "registryRevision").type, "uint64");
  assert.equal(child(receiptType, "escrowed").type, "bool");
});

test("three original authorization domains and complete typehash preimages remain distinct", () => {
  const cases = [
    ["native-fixed", "Native", "StreamFixedPriceSaleAdapter.sol", "SaleAuthorization", "6529StreamFixedPriceSale", "2", abi.nativeSale.getFunction("buy").inputs[0]],
    ["erc20-fixed", "ERC20", "StreamERC20FixedPriceSaleAdapter.sol", "ERC20SaleAuthorization", "6529StreamPaymentIntentVerifier", "1", abi.erc20Sale.getFunction("buy").inputs[0]],
    ["english-auction", "Auction", "StreamEnglishAuctionHouse.sol", "AuctionAuthorization", "6529StreamEnglishAuction", "2", abi.auction.getFunction("createAuction").inputs[0]],
    ["erc20-fixed", "PaymentIntent", "StreamPaymentIntentVerifier.sol", "StreamPaymentIntent", "6529StreamPaymentIntentVerifier", "1", abi.erc20Sale.getFunction("buy").inputs[4]],
    ["erc20-fixed", "PaymentRevocation", "StreamPaymentIntentVerifier.sol", "StreamPaymentIntentRevocation", "6529StreamPaymentIntentVerifier", "1", ParamType.from("tuple(address payer,bytes32 nonce,uint64 deadline)")]
  ];
  for (const [kind, helper, file, primaryType, name, version, tuple] of cases) {
    const c = coordinates(kind), message = specimen(tuple);
    message.nonce = ZeroHash;
    const originalType = `${primaryType}(${tuple.components.map(field => `${field.type} ${field.name}`).join(",")})`;
    assert.ok(source(file).includes(`"${originalType}"`), `${file}: original typehash`);
    const domain = hash(
      ["bytes32", "bytes32", "bytes32", "uint256", "address"],
      [id("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"), id(name), id(version), c.chainId, c.product]
    );
    const structHash = hash(["bytes32", tuple], [id(originalType), message]);
    const result = client[`directConservation${helper}TypedData`](c, message);
    assert.equal(result.digest, keccak256(concat(["0x1901", domain, structHash])));
    assert.deepEqual(result.domain, { name, version, chainId: c.chainId, verifyingContract: c.product });
    assert.equal(result.message.nonce, ZeroHash);
    assert.notEqual(client[`directConservation${helper}TypedData`]({ ...c, product: address(4) }, message).digest, result.digest);
    assert.notEqual(client[`directConservation${helper}TypedData`]({ ...c, chainId: c.chainId + 1n }, message).digest, result.digest);
  }
});

test("commercial replay and raw ERC20 sale-ID hashes retain full original namespaces", () => {
  for (const [kind, domain] of [
    ["native-fixed", "6529STREAM_NATIVE_SALE_NONCE_V1"],
    ["erc20-fixed", "6529STREAM_ERC20_SALE_NONCE_V1"],
    ["english-auction", "6529STREAM_ENGLISH_AUCTION_NONCE_V1"]
  ]) {
    const c = coordinates(kind), artist = address(6);
    for (const nonce of [ZeroHash, id("commercial nonce")]) {
      assert.equal(client.directConservationAuthorizationId(c, artist, nonce), hash(
        ["bytes32", "uint256", "address", "address", "bytes32"],
        [id(domain), c.chainId, c.product, artist, nonce]
      ));
    }
  }
  const c = coordinates("erc20-fixed"), config = specimen(configType);
  const saleId = hash(
    ["bytes32", "uint256", "address", "uint8", "uint256", "bytes32", "uint256"],
    [id("6529STREAM_SALE_V1"), c.chainId, c.product, 0n, config.collectionId, config.phaseId, 0n]
  );
  assert.equal(client.directConservationERC20SaleId(c, config.collectionId, config.phaseId, 0n), saleId);
  assert.equal(client.directConservationERC20ConfigHash(saleId, config), hash(
    ["bytes32", "bytes32", configType],
    [id("6529STREAM_CURRENT_ERC20_FIXED_PRICE_CONFIG_V1"), saleId, config]
  ));
});

test("DIRECT key and complete sixteen-word receipt hash bind the original product and paid identities", () => {
  const b = { ...specimen(bindingsType), deploymentChainId: 31337n, core: address(1) };
  const adapter = address(2), authorizationId = id("original authorization");
  const sale = specimen(receiptType);
  sale.asset = ZeroAddress;
  for (const kind of Object.values(client.DIRECT_CONSERVATION_PRODUCT_KINDS)) {
    b.productKind = kind;
    const prefixTypes = ["bytes32", "uint256", "address", "address", "bytes32", "bytes32"];
    const prefix = [b.deploymentChainId, b.core, adapter, kind, authorizationId];
    assert.equal(client.directConservationKey(b, adapter, authorizationId), hash(
      prefixTypes, [id("6529STREAM_DIRECT_PRIMARY_SALE_KEY_V1"), ...prefix]
    ));
    const expected = hash([...prefixTypes, receiptType], [
      id("6529STREAM_DIRECT_PRIMARY_SALE_RECEIPT_V1"), ...prefix, sale
    ]);
    assert.equal(client.directConservationReceiptHash(b, adapter, authorizationId, sale), expected);
    for (const field of receiptType.components) {
      const changed = specimen(ParamType.from(field.type), true);
      const replacement = sale[field.name] === changed
        ? specimen(ParamType.from(`${field.type} changed`)) : changed;
      assert.notEqual(client.directConservationReceiptHash(b, adapter, authorizationId, {
        ...sale, [field.name]: replacement
      }), expected, field.name);
    }
    assert.equal(client.directConservationReceiptLookupHash(b, adapter, authorizationId, {
      ...sale, amount: 0n
    }), ZeroHash);
  }
});

test("DIRECT, first-sale and semantic-release receipt hashes retain the zero self-hash field", () => {
  for (const [tuple, helper, domain] of [
    [floorType, "FloorReceipt", "6529STREAM_CONSERVATION_DIRECT_RECEIPT_V1"],
    [firstType, "FirstSaleReceipt", "6529STREAM_CONSERVATION_FIRST_SALE_V1"],
    [releaseType, "ReleaseReceipt", "6529STREAM_CONSERVATION_RELEASE_RECEIPT_V1"]
  ]) {
    const record = specimen(tuple), c = floorCoordinates;
    const expected = hash(["bytes32", "uint256", "address", "address", tuple], [
      id(domain), c.chainId, c.core, c.floor, { ...record, receiptHash: ZeroHash }
    ]);
    assert.equal(client[`directConservation${helper}Hash`](c, record), expected);
    assert.equal(client[`directConservation${helper}Hash`](c, { ...record, receiptHash: id("different self hash") }), expected);
    assert.notEqual(client[`directConservation${helper}Hash`]({ ...c, floor: address(5) }, record), expected);
  }
});

test("semantic release identity excludes provider context while retaining content and membership", () => {
  const context = specimen(child(releaseType, "context")), c = floorCoordinates, cid = 19n;
  const expected = hash(
    ["bytes32", "uint256", "address", "uint256", "bytes32", "bytes32", "bytes32", "bytes32", "bool"],
    [id("6529STREAM_CONSERVATION_RELEASE_V1"), c.chainId, c.core, cid,
      context.scopeSubject, context.membershipHash, context.mediaInventoryHash, context.scriptSourceHash, context.scriptWork]
  );
  assert.equal(client.directConservationReleaseKey(c.chainId, c.core, cid, context), expected);
  assert.equal(client.directConservationReleaseKey(c.chainId, c.core, cid, {
    ...context, sourceContextHash: id("benign provider replacement")
  }), expected);
  assert.notEqual(client.directConservationReleaseKey(c.chainId, c.core, cid, {
    ...context, membershipHash: id("different release membership")
  }), expected);
});

test("source head starts nonzero at count zero and appends original immutable source pins", () => {
  const c = floorCoordinates, s = specimen(sourceType), domain = id("6529STREAM_CONSERVATION_FLOOR_SOURCES_V1");
  const initial = hash(["bytes32", "uint256", "address", "address"], [domain, c.chainId, c.core, c.floor]);
  assert.equal(client.directConservationSourceInitialHash(c), initial);
  assert.notEqual(initial, ZeroHash);
  const expected = hash(
    ["bytes32", "bytes32", "uint64", "address", "bytes32", "address", "bytes32", "bytes32", "uint64"],
    [domain, initial, 1n, s.metadata, s.metadataCodeHash, s.provider, s.providerCodeHash, s.configurationHash, s.predecessor]
  );
  assert.equal(client.directConservationSourceAppendHash(initial, 1n, s), expected);
  assert.equal(client.directConservationSourceAppendHash(initial, 1n, {
    ...s, admittedAt: s.admittedAt + 1n, actionId: id("different admission action")
  }), expected);
});

test("original declared selectors determine receipt interfaces without optional module self-report", () => {
  for (const [key, exported] of [
    ["directReceipt", "DIRECT_CONSERVATION_RECEIPT_INTERFACE_ID"],
    ["directFloor", "DIRECT_CONSERVATION_FLOOR_INTERFACE_ID"]
  ]) {
    const original = fixture.sourceTexts[fixture.selections[key].source];
    const methods = [...original.matchAll(/\bfunction\s+(\w+)\s*\(/g)].map(match => match[1]);
    const value = methods.reduce((result, method) => result ^ BigInt(abi[key].getFunction(method).selector), 0n);
    assert.equal(client[exported], `0x${value.toString(16).padStart(8, "0")}`);
  }
  for (const key of ["nativeSale", "erc20Sale", "auction"]) {
    assert.equal(abi[key].getFunction("moduleType"), null);
    assert.equal(abi[key].getFunction("moduleVersion"), null);
  }
  assert.ok(new Interface(client.DIRECT_CONSERVATION_FLOOR_ABI).fragments.every(fragment =>
    fragment.type !== "function" || ["view", "pure"].includes(fragment.stateMutability)
  ));
});

test("protocol fragments match compiled ABI; shared Safe transport retains its separate witness", () => {
  const workflow = readFileSync(new URL("../src/current-direct-conservation-workflow.ts", import.meta.url), "utf8");
  const parsed = ts.createSourceFile("workflow.ts", workflow, ts.ScriptTarget.Latest, true);
  const literals = [];
  function visit(node) {
    if (ts.isStringLiteral(node) && /^(function|event) /.test(node.text)) literals.push(node.text);
    ts.forEachChild(node, visit);
  }
  visit(parsed);
  assert.ok(literals.length >= 60);
  const original = Object.values(abi).flatMap(contract => contract.fragments);
  // These are shared Safe transport shapes, not compiler projections of ABI98.
  const safeWitness = new Interface([
    "function execTransaction(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,bytes signatures) payable returns (bool success)",
    "event ExecutionSuccess(bytes32 txHash,uint256 payment)",
    "event ExecutionFailure(bytes32 txHash,uint256 payment)",
    "event ExecutionSuccess(bytes32 indexed txHash,uint256 payment)",
    "event ExecutionFailure(bytes32 indexed txHash,uint256 payment)"
  ]);
  const safeNames = new Set(["execTransaction", "ExecutionSuccess", "ExecutionFailure"]);
  let safeCount = 0;
  for (const rows of [
    client.DIRECT_CONSERVATION_NATIVE_ABI, client.DIRECT_CONSERVATION_ERC20_ABI,
    client.DIRECT_CONSERVATION_AUCTION_ABI, client.DIRECT_CONSERVATION_FLOOR_ABI, literals
  ]) {
    for (const fragment of new Interface(rows).fragments) {
      if (safeNames.has(fragment.name)) {
        assert.ok(safeWitness.fragments.some(item => item.format("full") === fragment.format("full")));
        safeCount++;
        continue;
      }
      const matches = original.filter(item => item.type === fragment.type
        && item.format("sighash") === fragment.format("sighash"));
      const exact = matches.find(item => item.type !== "function"
        || item.outputs.map(field => field.format("sighash")).join()
          === fragment.outputs.map(field => field.format("sighash")).join());
      assert.ok(exact, fragment.format("full"));
      assert.deepEqual(fragment.inputs.map(field => [field.format("sighash"), !!field.indexed]),
        exact.inputs.map(field => [field.format("sighash"), !!field.indexed]), fragment.name);
      if (fragment.type === "function") {
        assert.equal(fragment.payable, exact.payable, fragment.name);
        assert.equal(fragment.constant, exact.constant, fragment.name);
      }
    }
  }
  assert.equal(safeCount, 5);
  for (const indexed of [false, true]) {
    const safe = address(10), safeTxHash = id("independently verified Safe authorization");
    const event = safeWitness.fragments.find(item => item.name === "ExecutionSuccess"
      && !!item.inputs[0].indexed === indexed);
    const encoded = safeWitness.encodeEventLog(event, [safeTxHash, 0n]);
    assert.equal(requireSafeExecution({ status: 1, logs: [{ address: safe, ...encoded }] },
      safe, safeTxHash).safeTxHash, safeTxHash);
  }
});

test("coverage register exhausts all 29 original mutable selectors and preserves source qualification", () => {
  const coverage = JSON.parse(readFileSync(
    new URL("../docs/current-direct-conservation-coverage.json", import.meta.url), "utf8"
  ));
  assert.equal(coverage.sourceCommit, fixture.sourceCommit);
  assert.equal(coverage.sourceTree, fixture.sourceTree);
  assert.equal(coverage.compilerCapture, fixture.capture);
  assert.deepEqual(coverage.counts, {
    "native-fixed": 6, "erc20-fixed": 11, "english-auction": 12, total: 29
  });
  assert.equal(coverage.calls.length, 29);
  assert.equal(coverage.calls.filter(row => row.workflow === "owner-control").length, 13);
  assert.equal(new Set(coverage.calls.map(row => `${row.productKind}:${row.selector}`)).size, 29);
  assert.match(coverage.evidence, /does not establish real Safe, native contract/);
  assert.equal(coverage.sharedSafe.operation, 0);
  assert.equal(coverage.sharedSafe.outerNativeValue, "0");
  assert.deepEqual(coverage.sharedSafe.prepare, ["toSafeCall", "createSafeCallPlan"]);
  assert.equal(coverage.sharedClient.prepare, "prepareDirectConservationCall");
  assert.equal(coverage.sharedClient.receipt, coverage.sharedSafe.receipt);
  for (const [path, sha256] of Object.entries(coverage.sourceWitnesses)) {
    assert.equal(sha256, fixture.sourceHashes[path], path);
  }
  const products = {
    "native-fixed": ["nativeSale", client.DIRECT_CONSERVATION_NATIVE_ABI],
    "erc20-fixed": ["erc20Sale", client.DIRECT_CONSERVATION_ERC20_ABI],
    "english-auction": ["auction", client.DIRECT_CONSERVATION_AUCTION_ABI]
  };
  for (const [kind, [key, clientAbi]] of Object.entries(products)) {
    const originals = abi[key].fragments.filter(fragment => fragment.type === "function" && !fragment.constant);
    const exposed = new Interface(clientAbi).fragments.filter(fragment => fragment.type === "function" && !fragment.constant);
    const rows = coverage.calls.filter(row => row.productKind === kind);
    assert.deepEqual(rows.map(row => row.signature).sort(), originals.map(fragment => fragment.format("sighash")).sort());
    assert.deepEqual(exposed.map(fragment => fragment.format("sighash")).sort(), rows.map(row => row.signature).sort());
    assert.ok(!fixture.abis[key].some(fragment => ["receive", "fallback"].includes(fragment.type)));
    assert.equal(abi[key].getFunction("acceptOwnership"), null);
    assert.equal(abi[key].getFunction("pendingOwner"), null);
    for (const row of rows) {
      const fragment = abi[key].getFunction(row.signature);
      assert.equal(row.abiSegment, key);
      assert.equal(row.selector, fragment.selector);
      assert.equal(row.requestKind, fragment.name);
      assert.equal(row.mutability, fragment.stateMutability);
      assert.equal(row.client, "sharedClient");
      assert.equal(row.safe, "sharedSafe");
      if (row.workflow === "owner-control") {
        assert.equal(row.authority, "product owner");
        assert.equal(row.nativeValue, "0");
      }
    }
  }
});

test("all thirteen original owner controls reuse exact generic Safe CALLs and compiled calldata", () => {
  const rows = [
    ["setPaused", { paused: true }, [true]],
    ["setPlatformSigner", { signer: address(9) }, [address(9)]],
    ["transferOwnership", { newOwner: address(10) }, [address(10)]],
    ["renounceOwnership", {}, []]
  ];
  let count = 0;
  for (const [kind, key] of [
    ["native-fixed", "nativeSale"], ["erc20-fixed", "erc20Sale"], ["english-auction", "auction"]
  ]) {
    const c = coordinates(kind), owner = address(7);
    const calls = kind === "erc20-fixed"
      ? [...rows, ["raiseSignatureGasLimit", { value: (1n << 64n) - 1n }, [(1n << 64n) - 1n]]]
      : rows;
    for (const [method, fields, args] of calls) {
      const prepared = client.prepareDirectConservationCall(c, owner, {
        productKind: kind, kind: method, ...fields
      });
      const original = { to: c.product, value: 0n, data: abi[key].encodeFunctionData(method, args) };
      assert.deepEqual(prepared.call, original);
      assert.equal(prepared.caller, owner);
      assert.equal(prepared.factsVerified, false);
      assert.deepEqual(toSafeCall(prepared.call), { ...original, value: "0", operation: 0 });
      const plan = createSafeCallPlan(c.chainId, `Original ${kind} ${method}`, [{
        safe: owner, intent: `Execute reviewed original ${method}`, call: prepared.call, abi: fixture.abis[key]
      }]);
      assert.deepEqual(verifySafeCallPlan(plan, [fixture.abis[key]]), plan);
      assert.equal(plan.steps[0].method, abi[key].getFunction(method).format("sighash"));
      assert.equal(plan.steps[0].transaction.operation, 0);
      count++;
    }
  }
  assert.equal(count, 13);
});
