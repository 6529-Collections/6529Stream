import test from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { AbiCoder, Interface, ParamType, ZeroHash, getAddress, id, toBeHex, toUtf8Bytes } from "ethers";
import ts from "typescript";
import * as recovered from "../dist/current-artist-recovered-consent-hydration.js";
import * as hydration from "../dist/current-artist-authority-hydration.js";
import { solidityImports } from "../scripts/generate-current-entropy-policy-succession-fixture.mjs";
import { posix } from "node:path";
import { fixture, compiledInterfaces as compiled, verifyLibraryValueTypeEvidence } from "./current-artist-recovered-consent-hydration-fixture.mjs";

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

test("ART36 fixture retains authenticated source, complete ABI selections and document bytes", () => {
  assert.equal(fixture.sourceCommit, recovered.ARTIST_RECOVERED_CONSENT_HYDRATION_SOURCE);
  assert.match(fixture.sourceCommit, /^[a-f0-9]{40}$/);
  assert.match(fixture.sourceTree, /^[a-f0-9]{40}$/);
  assert.equal(fixture.sourceCount, 2830);
  assert.equal(fixture.literalBytes, 33_562_139);
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

test("ART36 complete request, content, certificate and transport tuples match compiler field names and widths", () => {
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
    if (!name.endsWith("_TUPLE") || name === "ARTIST_RECOVERED_CONSENT_HYDRATION_ENVELOPE_TUPLE") continue;
    assert.equal(typeof tuple, "string", name);
    const actual = shape(ParamType.from(tuple));
    assert.ok(witnesses.some(value => JSON.stringify(value) === JSON.stringify(actual)), name);
    checked++;
  }
  assert.ok(checked >= 30);
  const original = source("StreamArtistRecoveredHydrationTypes.sol");
  assert.match(original, /struct Envelope\s*\{\s*ExportHeader header;\s*bytes payload;\s*\}/);
  assert.deepEqual(shape(ParamType.from(recovered.ARTIST_RECOVERED_CONSENT_HYDRATION_ENVELOPE_TUPLE)), [
    { name: "header", type: shape(ParamType.from(recovered.ARTIST_RECOVERED_CONSENT_HYDRATION_EXPORT_HEADER_TUPLE)) },
    { name: "payload", type: "bytes" },
  ]);
});


import * as legacy from "../dist/current-artist-recovered-hydration.js";
import { fixture as legacyFixture, compiledInterfaces as legacyCompiled } from "./current-artist-recovered-hydration-fixture.mjs";

test("ART36 preserves original Request and commitment recipes while adding an explicit transport", () => {
  const original = legacyCompiled.registry.getFunction("hydrateRecoveredArtistAuthority");
  const retained = compiled.registry.getFunction("hydrateRecoveredArtistAuthority");
  const current = compiled.registry.getFunction("hydrateRecoveredArtistAuthorityWithConsents");
  assert.equal(retained.selector, original.selector);
  assert.deepEqual(retained.inputs.map(shape), original.inputs.map(shape));
  assert.equal(current.selector, "0x1e2d2f62");
  assert.equal(current.inputs.length, 2);
  assert.equal(current.stateMutability, "nonpayable");
  assert.deepEqual(shape(current.inputs[0]), shape(original.inputs[0]));
  assert.deepEqual(shape(current.inputs[1].arrayChildren), shape(ParamType.from(recovered.ARTIST_RECOVERED_CONSENT_HYDRATION_ROYALTY_FREEZE_TUPLE)));
  assert.equal(compiled.recoveredConsentsCoordinator.getFunction("coordinateHydrateRecoveredArtistAuthorityWithConsents").selector, "0xbab9201d");
  for (const name of ["StreamArtistRecoveredHydrationCommit.sol", "StreamArtistRecoveredHydrationEvidence.sol",
    "StreamArtistRecoveredHydrationOwnerPayload.sol", "StreamArtistRecoveredHydrationAdmission.sol",
    "StreamArtistRecoveredHydrationSource.sol", "StreamArtistOwnerCommit.sol"]) {
    const old = Object.entries(legacyFixture.sourceTexts).filter(([path]) => path.endsWith(`/${name}`));
    assert.equal(old.length, 1, name);
    assert.equal(source(name), old[0][1], name);
  }
  assert.equal(legacy.ARTIST_RECOVERED_HYDRATION_SOURCE, legacyFixture.sourceCommit);
  assert.equal(legacy.ARTIST_RECOVERED_HYDRATION_SHAPES.attestation, 255n);
  assert.equal(recovered.ARTIST_RECOVERED_CONSENT_HYDRATION_SHAPES.content, 511n);
});

test("all six nominal Prepared selectors retain compiler witnesses distinct from tuple selectors", () => {
  const ids = fixture.librarySelectorEvidence.methodIdentifiers;
  assert.equal(Object.keys(ids).length, 6);
  for (const [signature, selector] of Object.entries(ids)) assert.equal(id(signature).slice(2, 10), selector);
  for (const [signature, selector] of Object.entries(legacyFixture.librarySelectorEvidence.methodIdentifiers)) {
    assert.equal(ids[signature], selector);
  }
  const nominal = "prepare(StreamArtistOnboardingTypes.SuiteConfiguration,StreamArtistRecoveredHydrationTypes.Request,StreamArtistOnboardingTypes.RoyaltyFreeze[])";
  const prepare = compiled.prepared.fragments.find(value => value.type === "function" && value.name === "prepare" && value.inputs.length === 3);
  assert.ok(prepare);
  assert.equal(prepare.stateMutability, "view");
  assert.equal(`0x${ids[nominal]}`, recovered.ARTIST_RECOVERED_CONSENT_HYDRATION_PREPARE_SELECTOR);
  assert.notEqual(prepare.selector, `0x${ids[nominal]}`);
  assert.deepEqual(shape(prepare.outputs[0]), shape(ParamType.from(recovered.ARTIST_RECOVERED_CONSENT_HYDRATION_PREPARED_TUPLE)));
  const transport = new Interface(recovered.CURRENT_ARTIST_RECOVERED_CONSENT_HYDRATION_ABI);
  assert.equal(transport.getFunction("hydrateRecoveredArtistAuthorityWithConsents").selector, "0x1e2d2f62");
});

function workflowABI(path) {
  const text = readFileSync(new URL(path, import.meta.url), "utf8");
  const tree = ts.createSourceFile(path, text, ts.ScriptTarget.Latest, true, ts.ScriptKind.TS);
  const declarations = new Map();
  for (const node of tree.statements) if (ts.isVariableStatement(node)) {
    for (const declaration of node.declarationList.declarations) if (ts.isIdentifier(declaration.name)) {
      declarations.set(declaration.name.text, declaration.initializer);
    }
  }
  const imports = { ...hydration, ...legacy, ...recovered };
  function literal(node) {
    assert.ok(node, "Missing ABI literal binding");
    if (ts.isStringLiteral(node) || ts.isNoSubstitutionTemplateLiteral(node)) return node.text;
    if (ts.isTemplateExpression(node)) return node.head.text + node.templateSpans.map(span => literal(span.expression) + span.literal.text).join("");
    if (ts.isIdentifier(node)) return Object.hasOwn(imports, node.text) ? imports[node.text] : literal(declarations.get(node.text));
    if (ts.isPropertyAccessExpression(node)) {
      assert.ok(["recovered", "hydration", "rh", "consent", "shared"].includes(node.expression.getText(tree)));
      return imports[node.name.text];
    }
    if (ts.isArrayLiteralExpression(node)) return node.elements.flatMap(element => ts.isSpreadElement(element) ? literal(element.expression) : [literal(element)]);
    throw Error(`Unexpected ABI expression ${node.getText(tree)}`);
  }
  const constructor = declarations.get("abi");
  assert.ok(ts.isNewExpression(constructor));
  return new Interface(literal(constructor.arguments[0]));
}

test("shared transport and new historical consent read ABIs match original compiler fragments", () => {
  const witnesses = Object.values(compiled).flatMap(iface => iface.fragments);
  for (const path of ["../src/internal/artist-recovered-hydration-workflow.ts", "../src/current-artist-recovered-consent-hydration-workflow.ts"]) {
    for (const fragment of workflowABI(path).fragments) {
      const matches = witnesses.filter(value => value.type === fragment.type && value.format("sighash") === fragment.format("sighash"));
      assert.ok(matches.length, fragment.format("full"));
      if (fragment.type === "function") assert.ok(matches.some(value => value.stateMutability === fragment.stateMutability
        && JSON.stringify(value.outputs.map(shape)) === JSON.stringify(fragment.outputs.map(shape))), fragment.format("full"));
      if (fragment.type === "event") assert.ok(matches.some(value => JSON.stringify(value.inputs.map(type => Boolean(type.indexed)))
        === JSON.stringify(fragment.inputs.map(type => Boolean(type.indexed)))), fragment.name);
    }
  }
});

test("royalty calldata uses independent compiler argument schemas without changing the original Request", () => {
  const address = n => getAddress(toBeHex(n, 20)), hash = n => toBeHex(n, 32);
  const domains = ["binding_lifecycle", "collaborator_lifecycle", "identity_authority", "acceptance_lifecycle", "attribution_lifecycle", "payout_lifecycle", "consent_finality"];
  const tags = ["BINDING", "COLLABORATOR", "IDENTITY", "ACCEPTANCE", "ATTRIBUTION", "PAYOUT", "CONSENT"];
  const suite = {
    registry: address(1), archive: address(2), owners: Array.from({ length: 7 }, (_, i) => address(i + 3)),
    core: address(10), mintManager: address(11), roleRegistry: address(12), metadata: address(13),
    primaryResolver: address(14), royaltyResolver: address(15), primaryRevenueClass: hash(1), validator: address(16),
  };
  const request = {
    records: { authority: {
      bindingIndex: 0n, artistIds: [hash(2)], collections: [{ artistId: hash(2), collectionId: 1n, policies: [] }],
      expectedSource: domains.map(domain => ({ schema: id("6529STREAM_ARTIST_GUARD_CHECKPOINT_V1"),
        ownerState: { domainId: id(`domain:${domain}`), revision: 1n, stateRoot: hash(3), recordChainTip: hash(4) },
        replayRoot: hash(5), replayCount: 0n, nonceRoot: hash(6), nonceIndexCount: 0n })),
      replayOrigins: Array.from({ length: 7 }, () => []),
    }, witnesses: [] },
    expectedCapabilities: domains.map((domain, i) => ({ profile: id("6529STREAM_ARTIST_RECOVERED_AUTHORITY_HYDRATION_V1"),
      version: 1n, ownerIndex: BigInt(i), ownerDomain: id(`domain:${domain}`), checkpointSchema: id("6529STREAM_ARTIST_GUARD_CHECKPOINT_V1"),
      stateSchema: id(`6529STREAM_ARTIST_RECOVERED_${tags[i]}_STATE_V1`), supportedFeatures: 511n })),
    expectedSourceImportCommitment: ZeroHash, expectedSemanticInventory: ZeroHash,
  };
  const royaltyFreezes = [
    { resolver: address(18), collectionId: 1n, revenueClass: id("ROYALTY_ERC2981"), expectedAssignmentHash: hash(8) },
    { resolver: address(17), collectionId: 1n, revenueClass: id("ROYALTY_ERC2981"), expectedAssignmentHash: hash(6) },
  ];
  const prepare = compiled.prepared.fragments.find(value => value.type === "function" && value.name === "prepare" && value.inputs.length === 3);
  const expected = `0x4925300f${AbiCoder.defaultAbiCoder().encode(prepare.inputs, [suite, request, royaltyFreezes]).slice(2)}`;
  assert.equal(recovered.artistRecoveredConsentHydrationPreparationCalldata(suite, { request, royaltyFreezes }), expected);
  assert.throws(() => recovered.prepareArtistRecoveredConsentHydrationCall(address(1), address(19), { request, royaltyFreezes }));
  const finalInput = { request: { ...request, expectedSemanticInventory: hash(10) }, royaltyFreezes };
  const call = recovered.prepareArtistRecoveredConsentHydrationCall(address(1), address(19), finalInput);
  assert.equal(call.call.data, compiled.registry.encodeFunctionData("hydrateRecoveredArtistAuthorityWithConsents", [finalInput.request, royaltyFreezes]));
  assert.equal(call.call.value, 0n);
  assert.equal(call.factsVerified, false);
  assert.equal(call.royaltyFreezes[0].resolver, address(18));
});

test("public facades expose fixed profiles and never export the internal factories", async () => {
  assert.equal(Object.hasOwn(legacy, "createArtistRecoveredHydrationCodec"), false);
  assert.equal(Object.hasOwn(recovered, "createArtistRecoveredHydrationCodec"), false);
  const oldWorkflow = await import("../dist/current-artist-recovered-hydration-workflow.js");
  const newWorkflow = await import("../dist/current-artist-recovered-consent-hydration-workflow.js");
  assert.equal(Object.hasOwn(oldWorkflow, "createRecoveredHydrationWorkflow"), false);
  assert.equal(Object.hasOwn(newWorkflow, "createRecoveredHydrationWorkflow"), false);
  const exports = JSON.parse(readFileSync(new URL("../package.json", import.meta.url), "utf8")).exports;
  assert.deepEqual(Object.keys(exports), ["."]);
});
