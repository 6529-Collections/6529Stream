import test from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { AbiCoder, Interface, ParamType, ZeroHash, getAddress, id, toBeHex, toUtf8Bytes } from "ethers";
import ts from "typescript";
import * as recovered from "../dist/current-artist-recovered-hydration.js";
import * as hydration from "../dist/current-artist-authority-hydration.js";
import { solidityImports } from "../scripts/generate-current-entropy-policy-succession-fixture.mjs";
import { posix } from "node:path";
import { fixture, compiledInterfaces as compiled, verifyLibraryValueTypeEvidence } from "./current-artist-recovered-hydration-fixture.mjs";

const sha = value => createHash("sha256").update(value).digest("hex");
const source = name => {
  const matches = Object.entries(fixture.sourceTexts).filter(([path]) => path.endsWith(`/${name}`));
  assert.equal(matches.length, 1, name);
  return matches[0][1];
};
const shape = type => {
  if (type.baseType === "array") return { arrayLength: type.arrayLength, child: shape(type.arrayChildren) };
  if (type.baseType === "tuple") return type.components.map(child => ({ name: child.name, type: shape(child) }));
  return type.type;
};

test("recovered fixture retains authenticated source, complete ABI selections and document bytes", () => {
  assert.equal(fixture.sourceCommit, recovered.ARTIST_RECOVERED_HYDRATION_SOURCE);
  assert.match(fixture.sourceCommit, /^[a-f0-9]{40}$/);
  assert.match(fixture.sourceTree, /^[a-f0-9]{40}$/);
  assert.ok(fixture.sourceCount > 2700);
  assert.ok(fixture.literalBytes > 31_000_000);
  assert.match(fixture.inputSha256, /^[a-f0-9]{64}$/);
  assert.match(fixture.outputSha256, /^[a-f0-9]{64}$/);
  assert.match(fixture.qualification, /actual contract\/Safe execution/);
  verifyLibraryValueTypeEvidence();
  assert.equal(Object.keys(fixture.libraryValueTypeEvidence).length, 4);
  for (const [path, text] of Object.entries(fixture.sourceTexts)) {
    assert.equal(sha(text), fixture.sourceHashes[path], path);
    for (const imported of solidityImports(text)) {
      const resolved = imported.startsWith(".") ? posix.normalize(posix.join(posix.dirname(path), imported)) : imported;
      assert.ok(fixture.sourceHashes[resolved], `${path} -> ${resolved}`);
    }
  }
  for (const [key, selection] of Object.entries(fixture.selections)) {
    assert.equal(selection.full, true, key);
    assert.ok(fixture.sourceHashes[selection.source], key);
    assert.ok(Array.isArray(fixture.abis[key]), key);
  }
  for (const [path, document] of Object.entries(fixture.documents)) {
    assert.equal(sha(document.text), document.sha256, path);
    assert.equal(toUtf8Bytes(document.text).length, document.byteLength, path);
  }
});

test("complete request, certificate and transport tuples match compiler field names and widths", () => {
  const witnesses = [];
  function visit(type) {
    witnesses.push(shape(type));
    if (type.baseType === "array") visit(type.arrayChildren);
    if (type.baseType === "tuple") for (const child of type.components) visit(child);
  }
  for (const iface of Object.values(compiled)) {
    for (const fragment of iface.fragments) {
      for (const input of fragment.inputs ?? []) visit(input);
      for (const output of fragment.outputs ?? []) visit(output);
    }
  }
  let checked = 0;
  for (const [name, tuple] of Object.entries(recovered)) {
    if (!name.endsWith("_TUPLE") || name === "ARTIST_RECOVERED_HYDRATION_ENVELOPE_TUPLE") continue;
    assert.equal(typeof tuple, "string", name);
    const actual = shape(ParamType.from(tuple));
    assert.ok(witnesses.some(value => JSON.stringify(value) === JSON.stringify(actual)), name);
    checked++;
  }
  assert.ok(checked >= 30);
  const original = source("StreamArtistRecoveredHydrationTypes.sol");
  assert.match(original, /struct Envelope\s*\{\s*ExportHeader header;\s*bytes payload;\s*\}/);
  assert.deepEqual(shape(ParamType.from(recovered.ARTIST_RECOVERED_HYDRATION_ENVELOPE_TUPLE)), [
    { name: "header", type: shape(ParamType.from(recovered.ARTIST_RECOVERED_HYDRATION_EXPORT_HEADER_TUPLE)) },
    { name: "payload", type: "bytes" },
  ]);
});

test("Registry caller and original nominal preparation-library selector have distinct compiler witnesses", () => {
  const registry = compiled.registry.getFunction("hydrateRecoveredArtistAuthority");
  assert.equal(registry.stateMutability, "nonpayable");
  assert.equal(registry.inputs.length, 1);
  assert.deepEqual(shape(registry.inputs[0]), shape(ParamType.from(recovered.ARTIST_RECOVERED_HYDRATION_REQUEST_TUPLE)));
  const nominal = "prepare(StreamArtistOnboardingTypes.SuiteConfiguration,StreamArtistRecoveredHydrationTypes.Request)";
  const selector = fixture.librarySelectorEvidence.methodIdentifiers[nominal];
  assert.match(selector, /^[a-f0-9]{8}$/);
  assert.equal(id(nominal).slice(2, 10), selector);
  assert.equal(recovered.ARTIST_RECOVERED_HYDRATION_PREPARE_SELECTOR, `0x${selector}`);
  const prepare = compiled.prepared.getFunction("prepare");
  assert.equal(prepare.stateMutability, "view");
  assert.notEqual(prepare.selector, `0x${selector}`);
  assert.deepEqual(shape(prepare.outputs[0]), shape(ParamType.from(recovered.ARTIST_RECOVERED_HYDRATION_PREPARED_TUPLE)));
  const client = new Interface(recovered.CURRENT_ARTIST_RECOVERED_HYDRATION_ABI);
  client.forEachFunction(fragment => {
    const original = compiled.registry.getFunction(fragment.format("sighash"));
    assert.ok(original, fragment.format("full"));
    assert.equal(fragment.selector, original.selector);
    assert.equal(fragment.stateMutability, original.stateMutability);
    assert.deepEqual(fragment.outputs.map(type => type.format("sighash")), original.outputs.map(type => type.format("sighash")));
  });
});

test("workflow protocol ABI literals independently match complete compiler fragments", () => {
  const text = readFileSync(new URL("../src/current-artist-recovered-hydration-workflow.ts", import.meta.url), "utf8");
  const tree = ts.createSourceFile("workflow.ts", text, ts.ScriptTarget.Latest, true, ts.ScriptKind.TS);
  const declarations = new Map();
  for (const node of tree.statements) if (ts.isVariableStatement(node)) {
    for (const declaration of node.declarationList.declarations) if (ts.isIdentifier(declaration.name)) {
      declarations.set(declaration.name.text, declaration.initializer);
    }
  }
  const imports = { ...hydration, ...recovered };
  function literal(node) {
    assert.ok(node, "Missing ABI literal binding");
    if (ts.isStringLiteral(node) || ts.isNoSubstitutionTemplateLiteral(node)) return node.text;
    if (ts.isTemplateExpression(node)) return node.head.text + node.templateSpans.map(span => literal(span.expression) + span.literal.text).join("");
    if (ts.isIdentifier(node)) return Object.hasOwn(imports, node.text) ? imports[node.text] : literal(declarations.get(node.text));
    if (ts.isPropertyAccessExpression(node)) {
      assert.ok(["recovered", "hydration", "rh"].includes(node.expression.getText(tree)));
      return imports[node.name.text];
    }
    if (ts.isArrayLiteralExpression(node)) return node.elements.flatMap(element => ts.isSpreadElement(element) ? literal(element.expression) : [literal(element)]);
    throw Error(`Unexpected ABI expression ${node.getText(tree)}`);
  }
  const constructor = declarations.get("abi");
  assert.ok(ts.isNewExpression(constructor));
  const client = new Interface(literal(constructor.arguments[0]));
  const witnesses = Object.values(compiled).flatMap(iface => iface.fragments);
  for (const fragment of client.fragments) {
    const matches = witnesses.filter(value => value.type === fragment.type && value.format("sighash") === fragment.format("sighash"));
    assert.ok(matches.length, fragment.format("full"));
    if (fragment.type === "function") assert.ok(matches.some(value => value.stateMutability === fragment.stateMutability
      && JSON.stringify(value.outputs.map(type => type.format("sighash"))) === JSON.stringify(fragment.outputs.map(type => type.format("sighash")))), fragment.format("full"));
    if (fragment.type === "event") assert.ok(matches.some(value => JSON.stringify(value.inputs.map(type => Boolean(type.indexed)))
      === JSON.stringify(fragment.inputs.map(type => Boolean(type.indexed)))), fragment.name);
  }
});

test("preparation calldata uses original nominal selector with independently compiled argument encoding", () => {
  const address = n => getAddress(toBeHex(n, 20)), hash = n => toBeHex(n, 32);
  const domains = ["binding_lifecycle", "collaborator_lifecycle", "identity_authority", "acceptance_lifecycle", "attribution_lifecycle", "payout_lifecycle", "consent_finality"];
  const tags = ["BINDING", "COLLABORATOR", "IDENTITY", "ACCEPTANCE", "ATTRIBUTION", "PAYOUT", "CONSENT"];
  const suite = {
    registry: address(1), archive: address(2), owners: Array.from({ length: 7 }, (_, i) => address(i + 3)),
    core: address(10), mintManager: address(11), roleRegistry: address(12), metadata: address(13),
    primaryResolver: address(14), royaltyResolver: address(15), primaryRevenueClass: hash(1), validator: address(16),
  };
  const request = {
    records: {
      authority: {
        bindingIndex: 0n, artistIds: [hash(2)], collections: [{ artistId: hash(2), collectionId: 1n, policies: [] }],
        expectedSource: domains.map(domain => ({ schema: id("6529STREAM_ARTIST_GUARD_CHECKPOINT_V1"),
          ownerState: { domainId: id(`domain:${domain}`), revision: 1n, stateRoot: hash(3), recordChainTip: hash(4) },
          replayRoot: hash(5), replayCount: 0n, nonceRoot: hash(6), nonceIndexCount: 0n })),
        replayOrigins: Array.from({ length: 7 }, () => []),
      }, witnesses: [],
    },
    expectedCapabilities: domains.map((domain, i) => ({ profile: id("6529STREAM_ARTIST_RECOVERED_AUTHORITY_HYDRATION_V1"),
      version: 1n, ownerIndex: BigInt(i), ownerDomain: id(`domain:${domain}`), checkpointSchema: id("6529STREAM_ARTIST_GUARD_CHECKPOINT_V1"),
      stateSchema: id(`6529STREAM_ARTIST_RECOVERED_${tags[i]}_STATE_V1`), supportedFeatures: 31n })),
    expectedSourceImportCommitment: ZeroHash, expectedSemanticInventory: ZeroHash,
  };
  const prepare = compiled.prepared.getFunction("prepare");
  const selector = fixture.librarySelectorEvidence.methodIdentifiers["prepare(StreamArtistOnboardingTypes.SuiteConfiguration,StreamArtistRecoveredHydrationTypes.Request)"];
  const payload = AbiCoder.defaultAbiCoder().encode(prepare.inputs, [suite, request]);
  assert.equal(recovered.artistRecoveredHydrationPreparationCalldata(suite, request), `0x${selector}${payload.slice(2)}`);
  assert.notEqual(`0x${selector}`, prepare.selector);
  assert.throws(() => recovered.prepareArtistRecoveredHydrationCall(suite.registry, address(17), request));
});

test("source keeps permissionless admission, exact source capabilities and complete journal-selected witnesses", () => {
  const prepared = source("StreamArtistRecoveredHydrationPrepared.sol");
  assert.match(prepared, /request\.expectedSemanticInventory == 0/);
  assert.match(prepared, /request\.expectedSemanticInventory != inventory\(prepared\)/);
  assert.match(prepared, /keccak256\(abi\.encode\(actual\)\) != keccak256\(abi\.encode\(expected\)\)/);
  assert.match(prepared, /RH\.DIRECT_ECONOMICS/);
  assert.match(prepared, /RH\.DELEGATED_CONSENT/);
  assert.match(prepared, /RH\.ATTESTATIONS/);
  assert.match(prepared, /prepared\.query\.records = c\.artists\[0\]\.records/);
  const admission = source("StreamArtistRecoveredHydrationAdmission.sol");
  assert.match(admission, /importedHistoryBindingCount\(\) != 1/);
  assert.match(admission, /!sealed_ \|\| successor != destination\.registry/);
  const commit = source("StreamArtistRecoveredHydrationCommit.sol");
  assert.match(commit, /actor == address\(0\) \|\| configurationHash == 0/);
  assert.match(commit, /after_\[i\]\.revision != c\.before_\[i\]\.revision \+ 1/);
  assert.match(commit, /after_\[i\]\.recordChainTip != c\.before_\[i\]\.recordChainTip/);
  assert.match(commit, /T\.ActionContext\(60, actor, c\.before_\[i\]\)/);
});

test("source finite transport and paged Archive evidence remain separate from authority", () => {
  const types = source("StreamArtistRecoveredHydrationTypes.sol");
  for (const [name, value] of [["MAX_ERAS", 16], ["MAX_JOURNAL_ENTRIES", 4096], ["MAX_REPLAY_ALIASES", 8192], ["MAX_NONCE_INDICES", 128], ["MAX_NONCE_PREFIXES", 256]]) {
    assert.match(types, new RegExp(`${name} = ${value};`));
  }
  const evidence = source("StreamArtistRecoveredHydrationEvidence.sol");
  assert.match(evidence, /PAGE_BYTES = 20_480/);
  assert.match(evidence, /MAX_PAGES = 128/);
  assert.equal(recovered.ARTIST_RECOVERED_HYDRATION_PAGE_BYTES, 20480);
  assert.equal(recovered.ARTIST_RECOVERED_HYDRATION_MAX_BYTES, 2621440);
  assert.match(source("StreamArtistRecoveredPayloadHydration.sol"), /MAX_ROWS = 16_384/);
  assert.match(evidence, /if \(!added \|\| hash != descriptor\.pageHashes\[i\]\)/);
  assert.match(source("StreamArtistRecoveredHydrationCommit.sol"), /Evidence\.append\(destination\.archive, destination\.registry, value, profileBytes\)/);
});
