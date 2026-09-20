import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { AbiCoder, Interface, ParamType, ZeroHash, ZeroAddress, getAddress, id, keccak256 } from "ethers";
import * as r from "../dist/current-artist-recovered-hydration.js";
import * as h from "../dist/current-artist-authority-hydration.js";

const coder = AbiCoder.defaultAbiCoder();
const Z = ZeroHash;
const A = n => getAddress(`0x${BigInt(n).toString(16).padStart(40, "0")}`);
const H = n => `0x${BigInt(n).toString(16).padStart(64, "0")}`;
const clone = structuredClone;
import * as c from "../dist/current-artist-recovered-consent-hydration.js";
import { compiledInterfaces, fixture } from "./current-artist-recovered-consent-hydration-fixture.mjs";
const registry = new Interface(fixture.abis.registry);
const hash = (types, values) => keccak256(coder.encode(types, values));
const seven = fn => Array.from({ length: 7 }, (_, i) => fn(i));

// Synthetic structural certificate. Opaque semanticState deliberately makes no live admission claim.
function sample({ witnesses = false, history = false } = {}) {
  const chainId = (1n << 200n) + 11n;
  const suite = {
    registry: A(1), archive: A(3), owners: seven(i => A(10 + i)), core: A(4), mintManager: A(5),
    roleRegistry: A(6), metadata: A(7), primaryResolver: A(8), royaltyResolver: A(9), primaryRevenueClass: H(8), validator: A(17),
  };
  const origin = {
    chainId, registry: suite.registry, coordinator: A(2), archive: suite.archive, owners: suite.owners,
    ownerCodeHashes: seven(i => H(100 + i)), core: suite.core, manager: suite.mintManager,
    suiteConfigurationHash: hash([h.ARTIST_HYDRATION_SUITE_TUPLE], [suite]),
  };
  const originHash = r.artistRecoveredHydrationOriginHash(origin);
  const artistId = H(1000), collectionId = (1n << 240n) + 3n, bindingHash = H(1001);
  const journals = seven(() => []);
  function row(ownerIndex, operation, recordHash, cid, revision) {
    journals[ownerIndex].push({ position: { point: { environmentHash: originHash, ownerIndex: BigInt(ownerIndex), ownerRevision: revision }, nativeIndex: BigInt(journals[ownerIndex].length) },
      receipt: { operation, artistId, collectionId: cid, recordHash } });
  }
  row(0, 2n, bindingHash, collectionId, 1n);
  row(2, 1n, artistId, 0n, 1n);
  row(2, 35n, H(1002), 0n, 2n);
  row(2, 35n, H(1002), 0n, 2n); // Native occurrences may repeat a hash and revision.
  if (witnesses) {
    row(4, 24n, H(1003), collectionId, 1n);
    row(6, 15n, H(1004), collectionId, 1n);
  }
  const checkpoints = seven(i => ({ schema: r.ARTIST_RECOVERED_HYDRATION_CHECKPOINT_SCHEMA,
    ownerState: { domainId: r.artistRecoveredHydrationOwnerDomain(i), revision: 10n, stateRoot: H(200 + i), recordChainTip: H(220 + i) },
    replayRoot: Z, replayCount: 0n, nonceRoot: Z, nonceIndexCount: 0n }));
  const aliases = seven(() => []), logical = seven(() => []);
  if (history) {
    const surfaces = [id("identity_authority.replay.import_binding"), id("identity_authority.replay.one_way_cutover_latch"), id("ordinary.active")];
    for (const surface of surfaces) {
      const entry = { surface, scope: surface === surfaces[1] ? Z : H(2000) };
      logical[2].push(entry);
      const key = r.artistRecoveredHydrationReplayKey(origin, 2, entry);
      aliases[2].push({ originHash, ownerIndex: 2n, ...entry, originalKey: key,
        cell: { commitment: H(3333), touchedRevision: 2n, kind: 1n, status: 2n },
        admittedAt: { environmentHash: originHash, ownerIndex: 2n, ownerRevision: 2n } });
    }
    aliases[2].sort((a, b) => BigInt(a.originalKey) < BigInt(b.originalKey) ? -1 : 1);
    checkpoints[2].replayCount = 3n;
    checkpoints[2].replayRoot = H(2333);
  }
  const provenance = { origins: [origin], eras: [{ originHash, checkpoints, nativeCounts: journals.map(rows => BigInt(rows.length)), lowerRevisions: seven(() => 0n), priorImportCommitment: Z }], journals, aliases };
  const allRecords = journals.flat().map(row => row.receipt.recordHash);
  const collectionRecords = journals.flat().filter(row => row.receipt.collectionId !== 0n).map(row => row.receipt.recordHash);
  const artist = { artistId, collectionId: 0n, bindingHash: Z, policies: [], records: allRecords };
  const collection = { artistId, collectionId, bindingHash, policies: [], records: collectionRecords };
  const query = { ...collection, records: allRecords };
  const features = witnesses ? 161n : 1n;
  const data = seven(i => {
    const local = r.artistRecoveredHydrationOwnerProvenance(provenance, i);
    const payload = { provenance: local, nonces: [], semanticState: "0x1234", publications: [] };
    const sourceKeys = logical[i].map(originLogical => r.artistRecoveredHydrationReplayKey(origin, i, originLogical));
    return { typedState: r.encodeArtistRecoveredHydrationOwnerPayload(payload, i, features), origins: logical[i], sourceKeys,
      cells: sourceKeys.map(key => aliases[i].find(alias => alias.originalKey === key).cell), nonces: [] };
  });
  const before_ = seven(i => ({ domainId: r.artistRecoveredHydrationOwnerDomain(i), revision: i === 2 ? 3n : 0n, stateRoot: H(300 + i), recordChainTip: H(320 + i) }));
  const prepared = { admission: { prior: origin.registry, sourceCoordinator: origin.coordinator, source: suite, provenance, artists: [artist], collections: [collection], before_ },
    query, data, timing: { schema: id("6529STREAM_ARTIST_RECOVERED_TIMING_INVENTORY_V1"), version: 1n, count: 0n, root: Z, configurationHash: H(400) },
    externalGuards: { schema: id("6529STREAM_ARTIST_RECOVERED_EXTERNAL_GUARDS_V1"), provenanceCommitment: r.artistRecoveredHydrationProvenanceHash(provenance), artistId, actions: [], finality: [], entropy: [] } };
  const request = { records: { authority: { bindingIndex: 0n, artistIds: [artistId], collections: [{ artistId, collectionId, policies: [] }], expectedSource: checkpoints, replayOrigins: logical },
    witnesses: witnesses ? [{ collectionId, economics: [{ collectionId, resolver: suite.primaryResolver, revenueClass: H(55), scope: 2n, scopeId: collectionId, assignmentHash: H(56) }],
      attestations: [{ terms: { collectionId, subjectKind: 8n, subjectId: H(57), subjectStateHash: Z, schemaId: H(58), statementHash: H(59), statementURI: "ipfs://original" }, nonce: 0n }] }] : [] },
    expectedCapabilities: seven(i => ({ profile: r.ARTIST_RECOVERED_HYDRATION_PROFILE, version: 1n, ownerIndex: BigInt(i), ownerDomain: r.artistRecoveredHydrationOwnerDomain(i),
      checkpointSchema: r.ARTIST_RECOVERED_HYDRATION_CHECKPOINT_SCHEMA, stateSchema: r.artistRecoveredHydrationOwnerTag(i), supportedFeatures: 255n })),
    expectedSourceImportCommitment: Z, expectedSemanticInventory: r.artistRecoveredHydrationSemanticInventory(prepared) };
  const coords = { chainId, registry: A(101), coordinator: A(102) };
  const destination = { ...origin, registry: coords.registry, coordinator: coords.coordinator, archive: A(103), owners: seven(i => A(110 + i)), ownerCodeHashes: seven(i => H(500 + i)) };
  return { request, prepared, origin, provenance, coords, destination, features };
}

function contentSample() {
  const original = sample();
  const { prepared: p, request, origin, provenance, coords } = original;
  const artistId = p.query.artistId, collectionId = p.query.collectionId;
  const metadataContract = A(3000); // Historical target need not equal current suite.metadata.
  const consentTerms = { collectionId, metadataContract, familyId: H(8000), newStateHash: H(8001) };
  const consents = [H(8100), H(8102)].map(recordHash => ({ recordHash, artistId, bindingGeneration: 1n, terms: clone(consentTerms), authorityClass: 1n }));
  const royalties = [{ terms: { resolver: A(3100), collectionId, revenueClass: id("ROYALTY_ERC2981"), expectedAssignmentHash: H(8101) },
    item: { recordHash: H(8200), artistId, bindingGeneration: 1n }, grant: Z }];
  const freezes = [[H(1), H(2)], [H(2), H(3)]].map((lockClasses, i) => ({ recordHash: H(8300 + i), artistId,
    bindingGeneration: 1n, metadataContract, lockClasses, expectedStateHash: H(8400 + i), authorityClass: i ? 3n : 1n }));
  const sequence = [[17n, consents[0].recordHash], [20n, royalties[0].item.recordHash], [17n, consents[1].recordHash],
    [21n, freezes[0].recordHash], [21n, freezes[1].recordHash]];
  provenance.journals[6] = sequence.map(([operation, recordHash], i) => ({
    position: { point: { environmentHash: provenance.eras[0].originHash, ownerIndex: 6n, ownerRevision: BigInt(i + 1) }, nativeIndex: BigInt(i) },
    receipt: { operation, artistId, collectionId, recordHash },
  }));
  const logical = sequence.map(([operation, recordHash]) => {
    if (operation === 17n) return { surface: id("consent_finality.replay.content_consent_key"),
      scope: hash(["bytes32", "bytes32"], [hash([c.ARTIST_RECOVERED_CONSENT_HYDRATION_CONTENT_TERMS_TUPLE, "uint64"], [consentTerms, 1n]), recordHash]) };
    if (operation === 20n) return { surface: id("consent_finality.replay.freeze_key"),
      scope: hash([c.ARTIST_RECOVERED_CONSENT_HYDRATION_ROYALTY_FREEZE_TUPLE, "bytes32", "uint64"], [royalties[0].terms, artistId, 1n]) };
    return { surface: id("consent_finality.replay.freeze_key"), scope: hash(["bytes32", "uint256", "uint64", "bytes32"], [id("CONTENT"), collectionId, 1n, recordHash]) };
  });
  provenance.aliases[6] = logical.map((entry, i) => ({ originHash: provenance.eras[0].originHash, ownerIndex: 6n, ...entry,
    originalKey: r.artistRecoveredHydrationReplayKey(origin, 6, entry),
    cell: { commitment: sequence[i][1], touchedRevision: BigInt(i + 1), kind: 1n, status: 2n },
    admittedAt: provenance.journals[6][i].position.point,
  })).sort((a, b) => BigInt(a.originalKey) < BigInt(b.originalKey) ? -1 : 1);
  const cp = provenance.eras[0].checkpoints[6];
  cp.ownerState.revision = 5n; cp.replayCount = 5n; cp.replayRoot = H(8500);
  provenance.eras[0].nativeCounts[6] = 5n;
  const local = r.artistRecoveredHydrationOwnerProvenance(provenance, 6);
  const bundle = { original: { provenance: r.artistRecoveredHydrationOwnerProvenanceHash(local, 6), artistId, collectionId,
    bindingHash: p.query.bindingHash, keys: [], policies: [], economics: [], sales: [] }, consents, royalties, freezes };
  p.admission.artists[0].records = provenance.journals.flat().map(row => row.receipt.recordHash);
  p.admission.collections[0].records = provenance.journals.flat().filter(row => row.receipt.collectionId !== 0n).map(row => row.receipt.recordHash);
  p.query.records = p.admission.artists[0].records;
  p.externalGuards.provenanceCommitment = r.artistRecoveredHydrationProvenanceHash(provenance);
  for (let i = 0; i < 7; i++) {
    const priorPayload = r.decodeArtistRecoveredHydrationOwnerPayload(p.data[i].typedState, i).payload;
    const ownerLocal = r.artistRecoveredHydrationOwnerProvenance(provenance, i);
    const semanticState = i === 6 ? c.encodeArtistRecoveredConsentHydrationContentBundle(bundle, p.query, ownerLocal) : priorPayload.semanticState;
    p.data[i].typedState = c.encodeArtistRecoveredConsentHydrationOwnerPayload({ ...priorPayload, provenance: ownerLocal, semanticState }, i, 257n);
  }
  p.data[6].origins = logical;
  p.data[6].sourceKeys = logical.map(row => r.artistRecoveredHydrationReplayKey(origin, 6, row));
  p.data[6].cells = p.data[6].sourceKeys.map(key => provenance.aliases[6].find(row => row.originalKey === key).cell);
  request.records.authority.replayOrigins[6] = logical;
  request.expectedCapabilities = request.expectedCapabilities.map(row => ({ ...row, supportedFeatures: 511n }));
  request.expectedSemanticInventory = c.artistRecoveredConsentHydrationSemanticInventory(p);
  const input = { request, royaltyFreezes: royalties.map(row => row.terms) };
  return { ...original, input, local, bundle };
}

test("all additive content tuple names and widths match retained ABI106 values", () => {
  const shapes = new Set();
  const shape = type => type.baseType === "array"
    ? { length: type.arrayLength, child: shape(type.arrayChildren) }
    : type.baseType === "tuple" ? type.components.map(field => ({ name: field.name, type: shape(field) })) : type.type;
  function visit(type) {
    shapes.add(JSON.stringify(shape(type)));
    if (type.baseType === "array") visit(type.arrayChildren);
    if (type.baseType === "tuple") for (const child of type.components) visit(child);
  }
  for (const iface of Object.values(compiledInterfaces)) for (const fragment of iface.fragments) {
    for (const field of [...fragment.inputs ?? [], ...fragment.outputs ?? []]) visit(field);
  }
  for (const [name, tuple] of Object.entries(c)) {
    if (name.endsWith("_TUPLE") && !name.endsWith("_ENVELOPE_TUPLE")) {
      assert.ok(shapes.has(JSON.stringify(shape(ParamType.from(tuple)))), name);
    }
  }
  const compiled = compiledInterfaces.registry.getFunction("hydrateRecoveredArtistAuthorityWithConsents");
  const client = new Interface(c.CURRENT_ARTIST_RECOVERED_CONSENT_HYDRATION_ABI).getFunction("hydrateRecoveredArtistAuthorityWithConsents");
  assert.equal(client.format("sighash"), compiled.format("sighash"));
  assert.equal(client.selector, "0x1e2d2f62");
  assert.equal(c.ARTIST_RECOVERED_CONSENT_HYDRATION_PREPARE_SELECTOR, "0x4925300f");
  assert.equal(c.ARTIST_RECOVERED_CONSENT_HYDRATION_SOURCE, fixture.sourceCommit);
  assert.equal(r.ARTIST_RECOVERED_HYDRATION_SOURCE, "d56e13ffc8664b322a3a208f21d308918ed47072");
});

test("unchanged no-content255 bytes, commitments, profile evidence and owner roots are identical", () => {
  const { prepared, request, coords, destination } = sample();
  const input = { request, royaltyFreezes: [] };
  c.validateArtistRecoveredConsentHydrationInput(input, prepared);
  assert.deepEqual(c.normalizeArtistRecoveredConsentHydrationPrepared(prepared), r.normalizeArtistRecoveredHydrationPrepared(prepared));
  assert.equal(c.encodeArtistRecoveredConsentHydrationPrepared(prepared), r.encodeArtistRecoveredHydrationPrepared(prepared));
  assert.equal(c.artistRecoveredConsentHydrationSemanticInventory(prepared), r.artistRecoveredHydrationSemanticInventory(prepared));
  assert.equal(c.artistRecoveredConsentHydrationCommitment(coords, request, prepared), r.artistRecoveredHydrationCommitment(coords, request, prepared));
  assert.equal(c.encodeArtistRecoveredConsentHydrationProfileEvidence(request, prepared), r.encodeArtistRecoveredHydrationProfileEvidence(request, prepared));
  assert.deepEqual(c.artistRecoveredConsentHydrationOwnerAfter(destination, 0, prepared.admission.before_[0], prepared.query, prepared.data[0], H(3), A(900), []),
    r.artistRecoveredHydrationOwnerAfter(destination, 0, prepared.admission.before_[0], prepared.query, prepared.data[0], H(3), A(900), []));
});

test("closed511 accepts actualcontent257 while frozen255 continues rejecting256 and future512", () => {
  const { prepared, request, input } = contentSample();
  c.normalizeArtistRecoveredConsentHydrationPrepared(prepared);
  c.validateArtistRecoveredConsentHydrationInput(input, prepared);
  assert.throws(() => r.normalizeArtistRecoveredHydrationPrepared(prepared), /header/);
  const { payload } = c.decodeArtistRecoveredConsentHydrationOwnerPayload(prepared.data[6].typedState, 6);
  assert.throws(() => r.encodeArtistRecoveredHydrationOwnerPayload(payload, 6, 257n));
  assert.throws(() => c.encodeArtistRecoveredConsentHydrationOwnerPayload(payload, 6, 1023n));
  assert.throws(() => c.validateArtistRecoveredConsentHydrationCapability(request.expectedCapabilities[6], 6, 512n));
  assert.equal(c.ARTIST_RECOVERED_CONSENT_HYDRATION_SHAPES.content, 511n);
  assert.equal(r.ARTIST_RECOVERED_HYDRATION_SHAPES.attestation, 255n);
  assert.equal(Object.hasOwn(r.ARTIST_RECOVERED_HYDRATION_SHAPES, "content"), false);
});

test("WithConsents calldata retains full exactterms and actual actor independently of current targets", () => {
  const { input, coords, prepared } = contentSample();
  assert.notEqual(input.royaltyFreezes[0].resolver, prepared.admission.source.royaltyResolver);
  const plan = c.prepareArtistRecoveredConsentHydrationCall(coords.registry, A(900), input);
  assert.equal(plan.call.data, compiledInterfaces.registry.encodeFunctionData("hydrateRecoveredArtistAuthorityWithConsents", [input.request, input.royaltyFreezes]));
  assert.equal(plan.call.value, 0n); assert.equal(plan.caller, A(900)); assert.equal(plan.factsVerified, false);
  input.royaltyFreezes[0].expectedAssignmentHash = H(99999);
  assert.notEqual(plan.royaltyFreezes[0].expectedAssignmentHash, input.royaltyFreezes[0].expectedAssignmentHash);
  assert.deepEqual(c.normalizeArtistRecoveredConsentHydrationCall(plan), plan);
  assert.throws(() => c.normalizeArtistRecoveredConsentHydrationCall({ ...plan, royaltyFreezes: [] }));
  assert.throws(() => c.prepareArtistRecoveredConsentHydrationCall(coords.registry, A(900), { ...input, features: 511n }));
});

test("three-argument preparation uses nominal compiler selector and draft zero is never final call", () => {
  const { input, prepared, coords } = contentSample();
  const draft = { ...input, request: { ...input.request, expectedSemanticInventory: Z } };
  const raw = c.artistRecoveredConsentHydrationPreparationCalldata(prepared.admission.source, draft);
  const method = compiledInterfaces.prepared.fragments.find(fragment => fragment.type === "function" && fragment.name === "prepare" && fragment.inputs.length === 3);
  assert.equal(raw, "0x4925300f" + coder.encode(method.inputs, [prepared.admission.source, draft.request, draft.royaltyFreezes]).slice(2));
  assert.throws(() => c.prepareArtistRecoveredConsentHydrationCall(coords.registry, A(900), draft), /nonzero/);
});

test("original content17 repeatsterms and content21 overlappinglocks remain in native order", () => {
  const { bundle, local, prepared } = contentSample();
  assert.deepEqual(bundle.consents[0].terms, bundle.consents[1].terms);
  const raw = c.encodeArtistRecoveredConsentHydrationContentBundle(bundle, prepared.query, local);
  assert.deepEqual(c.decodeArtistRecoveredConsentHydrationContentBundle(raw, prepared.query, local), bundle);
  const reordered = clone(bundle); reordered.consents.reverse();
  assert.throws(() => c.normalizeArtistRecoveredConsentHydrationContentBundle(reordered, prepared.query, local), /native order/);
  const duplicateLock = clone(bundle); duplicateLock.freezes[0].lockClasses = [H(1), H(1)];
  assert.throws(() => c.normalizeArtistRecoveredConsentHydrationContentBundle(duplicateLock, prepared.query, local), /strictly ordered/);
  const unsortedLock = clone(bundle); unsortedLock.freezes[0].lockClasses.reverse();
  assert.throws(() => c.normalizeArtistRecoveredConsentHydrationContentBundle(unsortedLock, prepared.query, local), /strictly ordered/);
  const delegatedContent = clone(bundle); delegatedContent.consents[0].authorityClass = 2n;
  assert.throws(() => c.normalizeArtistRecoveredConsentHydrationContentBundle(delegatedContent, prepared.query, local), /content consent/);
});

test("royalty selectors cover exact filtered20 inventory and original fullscope without current eligibility", () => {
  const { input, prepared, bundle, local } = contentSample();
  assert.throws(() => c.validateArtistRecoveredConsentHydrationInput({ ...input, royaltyFreezes: [] }, prepared), /every original/);
  const changed = clone(input); changed.royaltyFreezes[0].expectedAssignmentHash = H(999);
  assert.throws(() => c.validateArtistRecoveredConsentHydrationInput(changed, prepared), /retained order and terms/);
  assert.throws(() => c.normalizeArtistRecoveredConsentHydrationRoyaltyFreezes([input.royaltyFreezes[0], input.royaltyFreezes[0]], prepared.query.collectionId), /Duplicate/);
  const wrongClass = clone(bundle); wrongClass.royalties[0].terms.revenueClass = H(9);
  assert.throws(() => c.normalizeArtistRecoveredConsentHydrationContentBundle(wrongClass, prepared.query, local));
  assert.equal(c.artistRecoveredConsentHydrationRoyaltyScope(input.royaltyFreezes[0], prepared.query.artistId),
    hash([c.ARTIST_RECOVERED_CONSENT_HYDRATION_ROYALTY_FREEZE_TUPLE, "bytes32", "uint64"], [input.royaltyFreezes[0], prepared.query.artistId, 1n]));
});

test("typed content codec cannot add absent signer/nonce/time preimages or trailing bytes", () => {
  const { bundle, local, prepared } = contentSample();
  const raw = c.encodeArtistRecoveredConsentHydrationContentBundle(bundle, prepared.query, local);
  assert.throws(() => c.decodeArtistRecoveredConsentHydrationContentBundle(`${raw}${"00".repeat(32)}`, prepared.query, local), /Noncanonical/);
  const invented = clone(bundle); invented.royalties[0].item.signer = A(999);
  assert.throws(() => c.normalizeArtistRecoveredConsentHydrationContentBundle(invented, prepared.query, local), /exact/);
  const extraQuery = { ...prepared.query, inventedAuthority: A(999) };
  assert.throws(() => c.normalizeArtistRecoveredConsentHydrationContentBundle(bundle, extraQuery, local), /exact/);
  const impreciseQuery = { ...prepared.query, collectionId: Number(prepared.query.collectionId) };
  assert.throws(() => c.normalizeArtistRecoveredConsentHydrationContentBundle(bundle, impreciseQuery, local), /bigint/);
  const missing = clone(bundle); missing.freezes.pop();
  assert.throws(() => c.normalizeArtistRecoveredConsentHydrationContentBundle(missing, prepared.query, local), /complete original/);
});

test("complete source journal drives bit256 and explicit511 capability is not enough", () => {
  const facts = { currentAuthorityClass: 1n, recoveryAuthorityClasses: [], hasAdjudicationV2: false, hasRewindsV3: false,
    eraCount: 1n, economicsCount: 0n, hasDelegations: false, bindingConsentMode: 1n, saleConsentCount: 0n, attestationCount: 0n };
  assert.equal(c.artistRecoveredConsentHydrationRequiredFeatures(facts, [14n]), 1n);
  assert.equal(c.artistRecoveredConsentHydrationRequiredFeatures(facts, [17n]), 257n);
  assert.throws(() => c.artistRecoveredConsentHydrationRequiredFeatures(facts, [22n]));
  const { prepared } = sample();
  for (let i = 0; i < 7; i++) {
    const { payload } = r.decodeArtistRecoveredHydrationOwnerPayload(prepared.data[i].typedState, i);
    prepared.data[i].typedState = c.encodeArtistRecoveredConsentHydrationOwnerPayload(payload, i, 257n);
  }
  assert.throws(() => c.normalizeArtistRecoveredConsentHydrationPrepared(prepared), /complete source journal/);
});

test("owner6 exactera and replay joins reject history gaps and changedadmission without rehashing17", () => {
  const { bundle, local, prepared } = contentSample();
  const bad = clone(local); bad.eras[0].checkpoint.ownerState.revision = 6n;
  const matchingBundle = clone(bundle); matchingBundle.original.provenance = r.artistRecoveredHydrationOwnerProvenanceHash(bad, 6);
  assert.throws(() => c.normalizeArtistRecoveredConsentHydrationContentBundle(matchingBundle, prepared.query, bad), /era accounting/);
  const alias = clone(local); alias.aliases[0].cell.commitment = H(7777);
  const alteredBundle = clone(bundle); alteredBundle.original.provenance = r.artistRecoveredHydrationOwnerProvenanceHash(alias, 6);
  assert.throws(() => c.normalizeArtistRecoveredConsentHydrationContentBundle(alteredBundle, prepared.query, alias), /replay alias/);
});
