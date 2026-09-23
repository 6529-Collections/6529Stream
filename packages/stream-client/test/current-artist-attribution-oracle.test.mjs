import test from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { posix } from "node:path";
import ts from "typescript";
import { AbiCoder, Interface, ParamType, TypedDataEncoder, ZeroAddress, ZeroHash, getAddress, id, keccak256, toBeHex } from "ethers";
import { solidityImports } from "../scripts/generate-current-entropy-policy-succession-fixture.mjs";
import { sourceFunction } from "../scripts/generate-current-artist-attribution-source-profile.mjs";
import { fixture, attributionSourceProfile as profile, attributionSource, compiledABI, compiledInterfaces, libraryValueABI, compiledLibraryValueInterface } from "./current-artist-attribution-source-fixture.mjs";

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
    if (ts.isExportDeclaration(statement) && statement.moduleSpecifier && statement.exportClause && ts.isNamedExports(statement.exportClause)) {
      const target = new URL(statement.moduleSpecifier.text.replace(/\.js$/, ".ts"), url);
      for (const entry of statement.exportClause.elements) imported.set(entry.name.text, { url: target, name: entry.propertyName?.text ?? entry.name.text });
    }
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

const sha = value => createHash("sha256").update(value).digest("hex");
const pureURL = new URL("../src/current-artist-attribution.ts", import.meta.url);
const readPure = literalReader(pureURL);
const source = name => attributionSource("smart-contracts/domains/artist/" + name + ".sol");
const writes = ["fileAttributionClaim", "openAttributionDispute", "recordCounterStatement", "resolveAttributionDispute", "revokeAttribution", "vetoAttributionRepudiation", "cancelAttributionRepudiation", "executeAttributionRepudiation", "withdrawAttributionDispute"];
const selectors = ["061ed7c5", "e9375eda", "24c57a62", "38554d5b", "555185ff", "29e041a6", "99c26e2d", "e907e941", "e1d11786"];
const shape = p => p.baseType === "array" ? { length: p.arrayLength, child: shape(p.arrayChildren) }
  : p.baseType === "tuple" ? p.components.map(p => ({ name: p.name, type: shape(p) })) : p.type;

test("attribution retains the exact bd4 compiler witness and separately pins c715 sources", () => {
  const raw = readFileSync(new URL("./fixtures/" + profile.compilerEvidence.fixtureFile, import.meta.url));
  assert.equal(sha(raw), "2cd33a780cfd61c9d338a917ce029596b2b0a9c62542e7ab1b502a29ea19c6e9");
  assert.equal(raw.length, 39369402);
  assert.equal(profile.compilerEvidence.fixtureSha256, sha(raw));
  assert.equal(profile.compilerEvidence.sourceCommit, fixture.sourceCommit);
  assert.equal(fixture.sourceCommit, "bd4a291e9e159cbbb5079a9a2a418fb151a8c01b");
  assert.equal(fixture.sourceTree, "466dac5d504c33a8a0bf4275997c33c851d65dd0");
  assert.equal(fixture.sourceCount, 1430); assert.equal(fixture.literalBytes, 9829482);
  assert.equal(Object.keys(fixture.committedSourceBridge.committedBlobSHA256).length, 1430);
  assert.equal(profile.currentSource.commit, "c715354ed57d2ab639f874cc595b272a7631de71");
  assert.equal(profile.currentSource.tree, "3df66325b3b251755a6b2df7de0bf239fa4eb8b4");
  assert.equal(readPure("ARTIST_ATTRIBUTION_SOURCE"), profile.currentSource.commit);
  assert.equal(readPure("ARTIST_ATTRIBUTION_ABI_SOURCE"), fixture.sourceCommit);
  assert.equal(profile.qualification.compilerWasRerun, false);
  assert.equal(profile.qualification.currentWholeSuiteSourceEqual, false);
  assert.equal(profile.qualification.nativeExecutionVerified, false);
  assert.equal(profile.qualification.linkedRuntimeAdmissionVerified, false);
});

test("the complete current import closure records every exact, changed and added raw source", () => {
  const seen = new Set();
  const visit = path => {
    if (seen.has(path)) return; seen.add(path);
    const text = attributionSource(path), row = profile.sources[path];
    assert.equal(sha(text), row.sha256, path); assert.equal(Buffer.byteLength(text), row.byteLength, path);
    assert.equal(createHash("sha1").update(Buffer.from(`blob ${Buffer.byteLength(text)}\0`)).update(text).digest("hex"), row.blob, path);
    if (row.retainedCompilerSourceEqual) {
      assert.equal(text, fixture.sourceTexts[path], path);
      assert.equal(sha(text), fixture.committedSourceBridge.committedBlobSHA256[path], path);
    } else assert.equal(text, profile.sourceOverrides[path], path);
    for (const dependency of solidityImports(text)) visit(dependency.startsWith(".") ? posix.normalize(posix.join(posix.dirname(path), dependency)) : dependency);
  };
  profile.rootPaths.forEach(visit);
  assert.deepEqual([...seen].sort(), Object.keys(profile.sources).sort());
  assert.equal(seen.size, 1040); assert.equal([...seen].reduce((n, p) => n + profile.sources[p].byteLength, 0), 6632043);
  assert.equal(Object.values(profile.sources).filter(r => r.retainedCompilerSourceEqual).length, 1027);
  assert.equal(profile.changes.length, 6); assert.equal(profile.additions.length, 7); assert.deepEqual(profile.removedSources, []);
  assert.deepEqual(Object.keys(profile.sourceOverrides).sort(), [...profile.changes.map(r => r.path), ...profile.additions].sort());
  assert.equal(profile.rootPaths.length, 10); assert.equal(profile.operationalSources.length, 22);
  for (const path of [...profile.rootPaths, ...profile.operationalSources]) assert.equal(profile.sources[path].retainedCompilerSourceEqual, true, path);
  for (const row of profile.changes) { assert.equal(sha(fixture.sourceTexts[row.path]), row.compilerSha256); assert.equal(sha(attributionSource(row.path)), row.currentSha256); }
});

test("all nine original Writer bodies survive the exact seven-hydration-forwarder delta", () => {
  const delta = profile.writerDelta, before = fixture.sourceTexts[delta.path], after = attributionSource(delta.path);
  assert.deepEqual(Object.keys(delta.preservedOperationalForwarders), writes);
  for (const name of writes) {
    assert.equal(sourceFunction(before, name), sourceFunction(after, name), name);
    assert.equal(sha(sourceFunction(after, name)), delta.preservedOperationalForwarders[name].sha256);
  }
  let restored = after;
  for (const name of delta.replacedHydrationMethods) restored = restored.replace(sourceFunction(after, name), sourceFunction(before, name));
  const addition = /import\s*\{\s*StreamArtistRegistryAuthorityHydrationWriter[^}]*\}\s*from\s*"\.\/StreamArtistRegistryAuthorityHydrationWriter\.sol";\r?\n/;
  assert.match(restored, addition); assert.equal(restored.replace(addition, ""), before);
  // The specific contest/activity functions avoid the changed recovery context
  // routines. This is a source path assertion, not a dynamic linked-library proof.
  const contest = sourceFunction(source("StreamArtistRepudiationIdentityMutation"), "contest");
  for (const name of ["StreamArtistEstateState.contest", "StreamArtistIdentityRecoveryState.contest", "StreamArtistDormancyState.contest"]) assert.ok(contest.includes(name));
  assert.doesNotMatch(sourceFunction(source("StreamArtistIdentityRecoveryState"), "contest"), /context|Predecessor|Rotation/);
  assert.match(sourceFunction(source("StreamArtistIdentityWriterExtension"), "noteRepudiationCancellation"), /_noteLiving/);
  assert.match(sourceFunction(source("StreamArtistIdentityActivityMutation"), "noteLiving"), /StreamArtistIdentityActivity\.note/);
});

test("ADR48, ADR50 and the operation61 extension retain exact documents and write masks", () => {
  assert.equal(Object.keys(profile.documents).length, 7);
  for (const [path, row] of Object.entries(profile.documents)) {
    assert.equal(sha(row.text), row.sha256, path); assert.equal(Buffer.byteLength(row.text), row.byteLength, path);
    assert.equal(createHash("sha1").update(Buffer.from(`blob ${row.byteLength}\0`)).update(row.text).digest("hex"), row.blob, path);
  }
  const extension = JSON.parse(profile.documents["docs/architecture/artist-operation61-dispute-withdrawal.json"].text);
  assert.equal(extension.operationId, 61);
  assert.match(profile.documents["docs/adr/0050-attribution-dispute-withdrawal.md"].text, /0x15/);
  const recipes = readPure("ARTIST_ATTRIBUTION_RECIPES");
  const expected = [[10,16,16],[44,21,20],[45,23,20],[46,17,16],[47,23,20],[48,20,20],[49,20,20],[50,21,16],[61,21,20]];
  writes.forEach((name, i) => assert.deepEqual(recipes[name], { operationId: BigInt(expected[i][0]), readMask: BigInt(expected[i][1]), writeMask: BigInt(expected[i][2]) }));
  assert.match(source("StreamArtistRepudiationOperations"), /op == 47 \? 0x17 : op == 50 \? 0x15 : 0x14/);
  assert.match(source("StreamArtistDisputeWithdrawalOperations"), /0x15/);
});

test("the nine public calls and every exposed read, event and error are genuine ordinary ABI entries", () => {
  for (const [constant, originalName] of [["ARTIST_ATTRIBUTION_REGISTRY_ABI", "StreamArtistOnboardingRegistry"], ["ARTIST_ATTRIBUTION_OWNER_ABI", "StreamArtistAttributionLifecycle"]]) {
    const actual = new Interface(readPure(constant)), original = compiledInterfaces[originalName];
    for (const fragment of actual.fragments) {
      if (fragment.type === "event" && readPure("ARTIST_ATTRIBUTION_EVENTS_ABI").some(text => new Interface([text]).fragments[0].format("sighash") === fragment.format("sighash"))) continue;
      const expected = original.fragments.find(row => row.type === fragment.type && row.format("sighash") === fragment.format("sighash"));
      assert.ok(expected, constant + " " + fragment.format("sighash")); compatibleFragment(fragment, expected);
    }
    const mutable = actual.fragments.filter(f => f.type === "function" && !["view", "pure"].includes(f.stateMutability)).map(f => f.name).sort();
    assert.deepEqual(mutable, constant.includes("REGISTRY") ? [...writes].sort() : []);
  }
  writes.forEach((name, i) => assert.equal(compiledInterfaces.registry.getFunction(name).selector, "0x" + selectors[i]));
  for (const event of new Interface(readPure("ARTIST_ATTRIBUTION_EVENTS_ABI")).fragments) {
    assert.equal(event.type, "event");
    const candidates = Object.values(compiledInterfaces).flatMap(i => i.fragments).filter(row => row.type === "event" && row.format("sighash") === event.format("sighash"));
    assert.ok(candidates.length, event.name); compatibleFragment(event, candidates[0]);
  }
});

test("workflow observation and Archive fragments match original ordinary ABI; Safe transport stays separately qualified", () => {
  const read = literalReader(new URL("../src/current-artist-attribution-workflow.ts", import.meta.url));
  const originals = Object.values(compiledInterfaces).flatMap(iface => iface.fragments);
  for (const name of ["observationABI", "archiveABI", "identityEvents"]) for (const actual of new Interface(read(name)).fragments) {
    const candidates = originals.filter(row => row.type === actual.type && row.format("sighash") === actual.format("sighash"));
    assert.ok(candidates.length, name + " " + actual.format("sighash"));
    assert.ok(candidates.some(original => { try { compatibleFragment(actual, original); return true; } catch { return false; } }), name + " " + actual.format("sighash"));
    if (actual.type === "function") assert.ok(["view", "pure"].includes(actual.stateMutability));
  }
  // ABI12 does not compile Safe. Check preservation of the existing reviewed
  // three-function transport schema, without presenting it as an original
  // Artist compiler row. Execution events are checked by the shared transport.
  const established = literalReader(new URL("../src/current-governance-executor-v2-workflow.ts", import.meta.url));
  const actualSafe = new Interface(read("safeABI")).fragments.filter(f => f.type === "function");
  const expectedSafe = new Interface(established("safeABI")).fragments.filter(f => f.type === "function");
  assert.deepEqual(actualSafe.map(f => f.name).sort(), ["execTransaction", "getTransactionHash", "nonce"]);
  assert.deepEqual(actualSafe.map(f => f.format("full")).sort(), expectedSafe.map(f => f.format("full")).sort());
});

const coder = AbiCoder.defaultAbiCoder();
const B = n => toBeHex(BigInt(n), 32), A = n => getAddress(toBeHex(BigInt(n), 20));
const coordinates = { chainId: 31337n, registry: A(101), core: A(102) };
const client = () => import("../dist/current-artist-attribution.js");
const filing = action => ({ collectionId: (1n << 230n) + 17n, bindingGeneration: (1n << 63n) + 11n, disputeAction: BigInt(action), evidenceHash: action === 4 ? ZeroHash : B(51), reasonHash: B(52) });

test("all four signing actions retain the original EIP712 domain, exact widths and deadline field", async () => {
  const api = await client();
  const original = source("StreamArtistDisputeHashes"), repudiation = source("StreamArtistRepudiationHashes");
  const signature = original.match(/"(StreamArtistAttributionDispute\([^"\n]+\))"/)[1];
  assert.ok(repudiation.includes('"' + signature + '"'));
  const fields = signature.slice(signature.indexOf("(") + 1, -1).split(",").map(row => { const [type, name] = row.split(" "); return { name, type }; });
  assert.match(source("StreamArtistHashes"), /keccak256\("6529StreamArtistRegistry"\)/);
  assert.match(source("StreamArtistHashes"), /keccak256\("1"\)/);
  for (const action of [1, 2, 3, 4]) {
    const p = filing(action), authorization = { nonce: (1n << 250n) + 99n, time: (1n << 63n) + 123n, signature: "0x1234" };
    const domain = { name: "6529StreamArtistRegistry", version: "1", chainId: coordinates.chainId, verifyingContract: coordinates.registry };
    const message = { core: coordinates.core, ...p, nonce: authorization.nonce, deadline: authorization.time };
    const expected = TypedDataEncoder.hash(domain, { StreamArtistAttributionDispute: fields }, message);
    const actual = api.artistAttributionSigningPayload(coordinates, p, authorization);
    assert.equal(actual.digest, expected); assert.deepEqual(actual.domain, domain); assert.deepEqual(actual.message, message);
    assert.equal(api.artistAttributionSigningPayload(coordinates, p, { ...authorization, signature: "0x" }).digest, expected);
    assert.notEqual(api.artistAttributionSigningPayload(coordinates, p, { ...authorization, time: authorization.time + 1n }).digest, expected);
  }
});

test("all nine closed plans reconstruct exact original ordinary calldata including withdrawal action2", async () => {
  const api = await client(), actor = A(201), authorization = { nonce: (1n << 220n) + 3n, time: 999n, signature: "0x" };
  const standing = { artistId: B(88), bindingGeneration: 1n, collaboratorIndex: 0n, delegation: ZeroHash };
  const zeroStanding = { artistId: ZeroHash, bindingGeneration: 0n, collaboratorIndex: 0n, delegation: ZeroHash };
  const requests = [
    { kind: writes[0], collectionId: 11n, evidenceHash: B(21), reasonHash: B(22), reasonURI: "literal:unicode/🗝?x=1#z" },
    { kind: writes[1], mode: "signed", filing: filing(1), standing, authorization },
    { kind: writes[2], filing: filing(3), standing, authorization },
    { kind: writes[3], resolution: { collectionId: 11n, bindingGeneration: 1n, disputeRecordHash: B(23), resolution: 2n, evidenceHash: B(24), reasonHash: B(25), counterStatementRecordHash: B(26) } },
    { kind: writes[4], filing: filing(4), authorization },
    { kind: writes[5], collectionId: 11n, expectedRepudiation: B(27), reasonHash: B(28) },
    { kind: writes[6], collectionId: 11n, expectedRepudiation: B(27) },
    { kind: writes[7], collectionId: 11n, expectedRepudiation: B(27) },
    { kind: writes[8], filing: filing(2), standing, authorization },
    { kind: writes[1], mode: "governance", filing: filing(1), standing: zeroStanding, authorization: { nonce: 0n, time: 0n, signature: "0x" } },
  ];
  for (const request of requests) {
    const args = request.kind === writes[0] ? [request.collectionId, request.evidenceHash, request.reasonHash, request.reasonURI]
      : request.kind === writes[3] ? [request.resolution] : request.kind === writes[4] ? [request.filing, request.authorization]
      : request.filing ? [request.filing, request.standing, request.authorization]
      : request.kind === writes[5] ? [request.collectionId, request.expectedRepudiation, request.reasonHash] : [request.collectionId, request.expectedRepudiation];
    const actual = api.prepareArtistAttributionCall(coordinates, actor, request);
    assert.deepEqual(actual.call, { to: coordinates.registry, value: 0n, data: compiledInterfaces.registry.encodeFunctionData(request.kind, args) });
    assert.equal(actual.factsVerified, false);
    assert.equal(actual.requiresGovernance, request.kind === writes[3] || request.mode === "governance");
  }
});

const owner = compiledInterfaces.attribution;
const originalTypes = {
  claim: owner.getFunction("attributionClaimRecord").outputs[0],
  record: owner.getFunction("attributionDisputeRecord").outputs[0],
  repudiation: owner.getFunction("attributionRepudiationRecord").outputs[0],
  head: owner.getFunction("attributionDispute").outputs[0],
  binding: compiledInterfaces.binding.getFunction("binding").outputs[0],
  filing: compiledInterfaces.registry.getFunction("openAttributionDispute").inputs[0],
  standing: compiledInterfaces.registry.getFunction("openAttributionDispute").inputs[1],
  authorization: compiledInterfaces.registry.getFunction("openAttributionDispute").inputs[2],
  resolution: compiledInterfaces.registry.getFunction("resolveAttributionDispute").inputs[0],
  snapshot: compiledInterfaces.attribution.getFunction("ownerStateSnapshotV2").outputs[0],
  admission: compiledLibraryValueInterface("StreamArtistDisputeAdmission").getFunction("standing").outputs[0],
  proof: compiledLibraryValueInterface("StreamArtistDisputeAdmission").getFunction("verify").outputs[0],
  context: compiledLibraryValueInterface("StreamArtistDisputeAdmission").getFunction("openingContext").outputs[0],
  repudiationAdmission: compiledLibraryValueInterface("StreamArtistRepudiationFacts").getFunction("stage").outputs[0],
  guardian: compiledLibraryValueInterface("StreamArtistRepudiationFacts").getFunction("guardianProof").outputs[0],
  governance: compiledLibraryValueInterface("StreamArtistGovernanceWitness").getFunction("read").outputs[0],
  claimEvidence: compiledLibraryValueInterface("StreamArtistPlatformEvidence").getFunction("read").outputs[0],
};
function sample(p) {
  if (p.baseType === "tuple") return Object.fromEntries(p.components.map(c => [c.name, sample(c)]));
  if (p.baseType === "array") return Array.from({ length: p.arrayLength < 0 ? 0 : p.arrayLength }, () => sample(p.arrayChildren));
  if (p.type === "address") return A(777);
  if (p.type === "bool") return false;
  if (p.type === "string") return "source-shaped literal";
  if (p.type === "bytes") return "0x123456";
  if (p.type.startsWith("bytes")) return "0x" + "31".repeat(Number(p.type.slice(5)));
  if (p.type.startsWith("uint")) return 1n;
  throw Error("Unsupported compiler sample: " + p.type);
}

test("native claim, dispute and repudiation hashes preserve their distinct original word lists", async () => {
  const api = await client(), claim = sample(originalTypes.claim);
  Object.assign(claim, { collectionId: (1n << 235n) + 7n, claimant: A(205), filedAt: (1n << 63n) + 9n });
  const claimDomain = source("StreamArtistAttributionClaimState").match(/keccak256\("(6529STREAM_ARTIST_ATTRIBUTION_CLAIM_RECORD_V1)"\)/)[1];
  const claimBytes = coder.encode(["bytes32", "uint256", "address", "address", "uint256", "address", "bytes32", "bytes32", "uint64"], [id(claimDomain), coordinates.chainId, coordinates.registry, coordinates.core, claim.collectionId, claim.claimant, claim.evidenceHash, claim.reasonHash, claim.filedAt]);
  assert.equal((claimBytes.length - 2) / 2, 9 * 32);
  assert.equal(api.artistAttributionClaimRecordHash(coordinates, claim), keccak256(claimBytes));
  const changedClaim = { ...claim, reasonURI: "different", proposedArtist: A(999), previousRecordHash: B(888), index: 999n };
  assert.equal(api.artistAttributionClaimRecordHash(coordinates, changedClaim), keccak256(claimBytes));
  assert.equal(api.artistAttributionClaimSubjectHash(claim), keccak256(coder.encode(["uint256", "address", "bytes32", "bytes32"], [claim.collectionId, claim.claimant, claim.evidenceHash, claim.reasonHash])));
  assert.equal(api.artistAttributionClaimSubjectHash(changedClaim), api.artistAttributionClaimSubjectHash(claim));
  const disputeDomain = source("StreamArtistDisputeHashes").match(/keccak256\("(6529STREAM_ARTIST_DISPUTE_RECORD_V1)"\)/)[1];
  for (const action of [1, 2, 3]) {
    const record = { ...sample(originalTypes.record), terms: filing(action), signer: A(203), authorityClass: 2n, nonce: (1n << 248n) + 9n, recordedAt: (1n << 62n) + 1n };
    const p = record.terms;
    const raw = coder.encode(["bytes32", "uint256", "address", "uint256", "uint64", "uint8", "address", "uint8", "bytes32", "bytes32", "uint256", "uint64"], [id(disputeDomain), coordinates.chainId, coordinates.registry, p.collectionId, p.bindingGeneration, p.disputeAction, record.signer, record.authorityClass, p.evidenceHash, p.reasonHash, record.nonce, record.recordedAt]);
    assert.equal((raw.length - 2) / 2, 12 * 32); assert.equal(api.artistAttributionDisputeRecordHash(coordinates, record), keccak256(raw));
    assert.equal(api.artistAttributionDisputeRecordHash(coordinates, { ...record, previousRecordHash: B(987), standing: { ...record.standing, artistId: B(988) } }), keccak256(raw));
  }
  const record = { ...sample(originalTypes.repudiation), terms: filing(4), artistId: B(312), signer: A(202), authorityClass: 3n, nonce: (1n << 240n) + 2n, stagedAt: 12n, executableAt: 604812n };
  const domain = source("StreamArtistRepudiationHashes").match(/keccak256\("(6529STREAM_ARTIST_ATTRIBUTION_REPUDIATION_RECORD_V1)"\)/)[1], p = record.terms;
  const raw = coder.encode(["bytes32", "uint256", "address", "uint256", "uint64", "bytes32", "address", "uint8", "bytes32", "bytes32", "uint256", "uint64", "uint64"], [id(domain), coordinates.chainId, coordinates.registry, p.collectionId, p.bindingGeneration, record.artistId, record.signer, record.authorityClass, p.evidenceHash, p.reasonHash, record.nonce, record.stagedAt, record.executableAt]);
  assert.equal((raw.length - 2) / 2, 13 * 32); assert.equal(api.artistAttributionRepudiationRecordHash(coordinates, record), keccak256(raw));
  assert.equal(api.artistAttributionRepudiationRecordHash(coordinates, { ...record, bindingHash: B(333), capturedGuardianSet: B(334), windowRevision: 999n }), keccak256(raw));
  const headType = originalTypes.repudiation.components.find(p => p.name === "authorityHead");
  assert.equal(api.artistAttributionAuthorityHeadHash(record.authorityHead), keccak256(coder.encode([headType], [record.authorityHead])));
});

test("opening and resolution transitions use original complete Binding/Head tuples and class precedence", async () => {
  const api = await client(), p = filing(1), binding = { ...sample(originalTypes.binding), generation: p.bindingGeneration, consentMode: 1n, accepted: true };
  const closed = { ...sample(originalTypes.head), open: false, reopened: false, restoreState: 3n, revocationReason: 4n };
  const expectedScope = keccak256(coder.encode(["bytes32", "uint256", "address", "address", "uint256", "uint64"], [id("6529STREAM_ARTIST_DISPUTE_OPEN_SCOPE_V1"), coordinates.chainId, coordinates.registry, coordinates.core, p.collectionId, p.bindingGeneration]));
  assert.ok(source("StreamArtistDisputeAdmission").includes('"6529STREAM_ARTIST_DISPUTE_OPEN_SCOPE_V1"'));
  for (const state of [1n, 2n, 3n, 5n]) {
    const old = keccak256(coder.encode([originalTypes.binding, "uint8", originalTypes.head], [binding, state, closed]));
    const next = keccak256(coder.encode(["bytes32", "bytes32", originalTypes.filing], [expectedScope, old, p]));
    assert.deepEqual(api.artistAttributionOpeningContext(coordinates, p, binding, state, closed), { scopeHash: expectedScope, oldValueHash: old, newValueHash: next, requiredClass: 1n, restoredState: state === 5n ? closed.restoreState : state });
  }
  for (const reopened of [false, true]) for (const resolution of [1n, 2n]) {
    const head = { ...closed, open: true, reopened }, request = { collectionId: p.collectionId, bindingGeneration: p.bindingGeneration, disputeRecordHash: head.disputeRecordHash, resolution, evidenceHash: B(311), reasonHash: B(312), counterStatementRecordHash: head.counterStatementRecordHash };
    const scopeHash = keccak256(coder.encode(["bytes32", "uint256", "address", "address", "uint256", "uint64", "bytes32"], [id("6529STREAM_ARTIST_DISPUTE_RESOLUTION_SCOPE_V1"), coordinates.chainId, coordinates.registry, coordinates.core, p.collectionId, p.bindingGeneration, head.disputeRecordHash]));
    const oldValueHash = keccak256(coder.encode([originalTypes.binding, "uint8", originalTypes.head], [binding, 4n, head]));
    const newValueHash = keccak256(coder.encode(["bytes32", "bytes32", originalTypes.resolution], [scopeHash, oldValueHash, request]));
    assert.deepEqual(api.artistAttributionResolutionContext(coordinates, request, binding, 4n, head), { scopeHash, oldValueHash, newValueHash, requiredClass: resolution === 2n || reopened ? 2n : 1n, restoredState: resolution === 2n ? 5n : head.restoreState });
  }
});

test("original operation evidence uses flat eight-argument Archive bytes and exact evidence identity", async () => {
  const api = await client(), coordinator = A(900), actor = A(901), value = B(902);
  const snapshot = sample(originalTypes.snapshot);
  const before_ = Array.from({ length: 7 }, (_, i) => ({ ...snapshot, revision: BigInt(i), domainId: B(i + 100) }));
  const after_ = before_.map(row => ({ ...row, revision: row.revision + 1n }));
  const snapshots = ParamType.from({ type: "tuple[7]", components: JSON.parse(originalTypes.snapshot.format("json")).components });
  const fields = ["uint16", "bytes32", "uint16", "address", "bytes32", snapshots, snapshots, "bytes"];
  const evidenceDomain = source("StreamArtistRepudiationOperations").match(/keccak256\("(6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1)"\)/)[1];
  for (const operation of [10n, 44n, 45n, 46n, 47n, 48n, 49n, 50n, 61n]) {
    const envelope = { version: 1n, configurationHash: B(10), operation, actor, value, before_, after_, payload: "0x123456" };
    const raw = coder.encode(fields, [1n, B(10), operation, actor, value, before_, after_, envelope.payload]);
    assert.equal(api.encodeArtistAttributionArchiveEnvelope(envelope), raw);
    assert.deepEqual(api.decodeArtistAttributionArchiveEnvelope(raw), envelope);
    assert.equal(api.artistAttributionArchivePayloadHash(envelope), keccak256(raw));
    assert.equal(api.artistAttributionEvidenceId(coordinates, coordinator, operation, actor, value), keccak256(coder.encode(["bytes32", "uint256", "address", "address", "uint16", "address", "bytes32"], [id(evidenceDomain), coordinates.chainId, coordinates.registry, coordinator, operation, actor, value])));
    const wrapped = coder.encode([ParamType.from(api.ARTIST_ATTRIBUTION_ARCHIVE_ENVELOPE_TUPLE)], [envelope]);
    assert.notEqual(wrapped, raw); assert.throws(() => api.decodeArtistAttributionArchiveEnvelope(wrapped));
  }
});

test("all nine Archive detail layouts use original flat arguments including the distinct withdrawal layout", async () => {
  const api = await client(), T = originalTypes;
  const layouts = [
    [10n, ["id", "evidence", "reason", "uri", "e", "r", "ep", "rp"], ["uint256", "bytes32", "bytes32", "string", T.claimEvidence, T.claimEvidence, "bytes32", "bytes32"]],
    ...[44n, 45n].map(op => [op, ["p", "standing", "a", "admission", "proof", "context", "g", "head", "ep", "rp"], [T.filing, T.standing, T.authorization, T.admission, T.proof, T.context, T.governance, T.head, "bytes32", "bytes32"]]),
    [46n, ["p", "b", "context", "g", "ep", "rp"], [T.resolution, T.binding, T.context, T.governance, "bytes32", "bytes32"]],
    [47n, ["p", "a", "admission", "proof"], [T.filing, T.authorization, T.repudiationAdmission, T.proof]],
    [48n, ["r", "proof", "contest"], [T.repudiation, T.guardian, "bytes32"]],
    ...[49n, 50n].map(op => [op, ["r"], [T.repudiation]]),
    [61n, ["p", "standing", "a", "admission", "proof", "head", "ep", "rp"], [T.filing, T.standing, T.authorization, T.admission, T.proof, T.head, "bytes32", "bytes32"]],
  ];
  assert.match(source("StreamArtistDisputeOperations"), /abi\.encode\(p, standing_, a, admission, proof, context, g, head, ep, rp\)/);
  assert.match(source("StreamArtistDisputeWithdrawalOperations"), /abi\.encode\(p, standing, a, admission, proof, head, ep, rp\)/);
  for (const [operationId, names, schemas] of layouts) {
    const types = schemas.map(s => typeof s === "string" ? ParamType.from(s) : s), values = types.map(sample);
    const detail = { operationId, ...Object.fromEntries(names.map((name, i) => [name, values[i]])) };
    const raw = coder.encode(types, values);
    assert.equal(api.encodeArtistAttributionArchiveDetail(detail), raw, String(operationId));
    assert.deepEqual(api.decodeArtistAttributionArchiveDetail(operationId, raw), detail);
  }
  const witness = sample(T.governance);
  assert.equal(api.artistAttributionGovernanceWitnessHash(witness), keccak256(coder.encode([T.governance], [witness])));
  const e = sample(T.claimEvidence);
  assert.equal((coder.encode([T.claimEvidence], [e]).length - 2) / 2, 160);
  assert.equal(api.artistAttributionClaimEvidenceHash(e), keccak256(coder.encode([T.claimEvidence], [e])));
  const evidenceMembers = attributionSource("smart-contracts/interfaces/stream/artist/IStreamArtistAttributionDisputes.sol").match(/struct Evidence\s*\{([^}]+)\}/)[1];
  const fields = [...evidenceMembers.matchAll(/\b(uint\d+|bytes\d+)\s+(\w+)\s*;/g)].map(([, type, name]) => ({ type, name }));
  const evidenceType = ParamType.from({ type: "tuple", components: fields }), evidence = sample(evidenceType);
  const bytes = coder.encode([evidenceType], [evidence]); assert.equal((bytes.length - 2) / 2, 192);
  assert.equal(api.artistAttributionEvidenceHash(evidence), keccak256(bytes));
});

test("every exported tuple recursively matches a compiler value witness or explicit flat Archive source", () => {
  const witnesses = new Set();
  const visit = p => { witnesses.add(JSON.stringify(shape(p))); if (p.baseType === "array") visit(p.arrayChildren); if (p.baseType === "tuple") p.components.forEach(visit); };
  for (const iface of Object.values(compiledInterfaces)) for (const f of iface.fragments) [...f.inputs ?? [], ...f.outputs ?? []].forEach(visit);
  for (const name of Object.keys(fixture.libraryAbis)) {
    for (const f of libraryValueABI(name)) for (const p of [...f.inputs ?? [], ...f.outputs ?? []]) {
      const walk = field => { try { visit(ParamType.from(field)); } catch { /* Unencodable nominal storage types remain raw. */ } for (const c of field.components ?? []) walk(c); }; walk(p);
    }
  }
  const text = readFileSync(pureURL, "utf8"), names = [...text.matchAll(/export const (ARTIST_ATTRIBUTION_\w+_TUPLE)\s*=/g)].map(m => m[1]);
  assert.ok(names.length >= 23);
  for (const name of names) {
    const tuple = ParamType.from(readPure(name));
    if (name.endsWith("_ARCHIVE_ENVELOPE_TUPLE")) {
      assert.deepEqual(tuple.components.map(p => p.name), ["version", "configurationHash", "operation", "actor", "value", "before_", "after_", "payload"]);
      assert.deepEqual(tuple.components.map(p => p.format("sighash")), ["uint16", "bytes32", "uint16", "address", "bytes32", "(bytes32,uint64,bytes32,bytes32)[7]", "(bytes32,uint64,bytes32,bytes32)[7]", "bytes"]);
      assert.match(sourceFunction(source("StreamArtistRepudiationOperations"), "_archive"), /abi\.encode\(uint16\(1\), x\.configurationHash, op, actor, record, before_, after_, detail\)/);
    } else if (name === "ARTIST_ATTRIBUTION_EVIDENCE_TUPLE") {
      const declaration = attributionSource("smart-contracts/interfaces/stream/artist/IStreamArtistAttributionDisputes.sol").match(/struct Evidence\s*\{([^}]+)\}/)[1];
      const members = [...declaration.matchAll(/\b(uint\d+|bytes\d+|address|bool)\s+(\w+)\s*;/g)].map(([, type, name]) => ({ name, type }));
      assert.equal(members.length, 6); assert.deepEqual(shape(tuple), members);
    } else assert.ok(witnesses.has(JSON.stringify(shape(tuple))), name);
  }
});
