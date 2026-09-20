import { AbiCoder, Interface, ZeroAddress, ZeroHash, getAddress, hexlify, id, keccak256, toUtf8Bytes } from "ethers";
import * as view from "../dist/current-tagged-policy-view-v2.js";
import { fixture, compiledInterfaces as c, compiledLibraryEvents } from "./current-tagged-policy-view-v2-fixture.mjs";

export { c };
export const A = value => getAddress(`0x${BigInt(value).toString(16).padStart(40, "0")}`);
export const H = value => id(String(value));
export const Z = ZeroHash;
export const ZA = ZeroAddress;
export const coder = AbiCoder.defaultAbiCoder();
export const safeABI = new Interface([
  "function execTransaction(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,bytes signatures) returns(bool)",
  "event ExecutionSuccess(bytes32 txHash,uint256 payment)",
  "event ExecutionFailure(bytes32 txHash,uint256 payment)"
]);
const all = new Interface(Object.values(fixture.abis).flat().filter(fragment => fragment.type === "function"));
const adoption = compiledLibraryEvents("adoptionWorker");

/** Compiler-ABI RPC consistency fixture. It does not execute Solidity or prove nested gas admission. */
export function setup() {
  const f = { overrides: null, calls: [], codeOverride: null, receipt: null, transaction: null,
    resultRecord: null, profile: view.TAGGED_POLICY_VIEW_V2_PROFILE, priorCatalog: false, wrongChain: false };
  const names = ["core", "router", "artist", "artistCoordinator", "artistConsentOwner", "finality", "provider", "metadata",
    "schemas", "store", "views", "membership", "moduleRegistry", "rendererRegistry", "renderer", "policyFactory",
    "sourceSet", "inventory", "encoding", "liveAttribution"];
  const codes = new Map();
  const d = { chainId: 111n };
  names.forEach((name, index) => {
    const address = A(index + 1);
    const raw = `0x6000${(index + 1).toString(16).padStart(2, "0")}`;
    d[name] = { address, codeHash: keccak256(raw) };
    codes.set(address, raw);
  });
  d.linkedDependencies = [{ address: A(90), codeHash: keccak256("0x6010") }];
  codes.set(A(90), "0x6010");
  const coords = { chainId: d.chainId, core: d.core.address, router: d.router.address };
  const caller = A(70);
  const scope = { scopeType: 4n, collectionId: 13n, tokenId: 0n, scopeId: H("scope") };
  const payload = { contextVersion: view.TAGGED_POLICY_VIEW_V2_CONTEXT, name: "Original VIEW", description: "Full policy", imageURI: "",
    script: hexlify(toUtf8Bytes("window.complete = true;")) };
  const rawPayload = view.encodeTaggedPolicyViewV2Payload(payload);
  const manifest = { viewId: H("view declaration"), schemaId: view.TAGGED_POLICY_VIEW_V2_SCHEMA_ID, uri: "https://example.test/view",
    contentHash: keccak256(rawPayload), mimeType: "application/octet-stream", defaultForView: false };
  const documents = new Map([
    [manifest.schemaId, hexlify(toUtf8Bytes(view.TAGGED_POLICY_VIEW_V2_PAYLOAD_SCHEMA))],
    [H("STREAM_COLLECTION_VIEW_MANIFEST_ABI_V1"), hexlify(toUtf8Bytes(view.TAGGED_POLICY_VIEW_V2_MANIFEST_SCHEMA))],
    [H("RAW_BYTES"), hexlify(toUtf8Bytes("Raw exact bytes"))]
  ]);
  const declarationReceipt = { collectionId: scope.collectionId, viewId: manifest.viewId, revision: 2n, previousRecordHash: H("previous declaration"),
    recorder: A(71), authorizationClass: 8n, grantCollectionId: 0n, grantRevision: 4n, recordedAt: 5n, recordIndex: 1n,
    recordChainHash: H("declaration chain"), viewSchemaDefinitionHash: keccak256(documents.get(manifest.schemaId)),
    manifestSchemaDefinitionHash: keccak256(documents.get(H("STREAM_COLLECTION_VIEW_MANIFEST_ABI_V1"))),
    canonicalizationDefinitionHash: keccak256(documents.get(H("RAW_BYTES"))) };
  const manifestRaw = coder.encode(["uint256", "uint64", "bytes32", c.views.getFunction("viewRecord").outputs[0]],
    [scope.collectionId, declarationReceipt.revision, declarationReceipt.previousRecordHash, manifest]);
  const collectionRecord = { recordType: H("DISPLAY_VIEW_MANIFEST"), subjectId: keccak256(coder.encode(
    ["bytes32", "uint256", "address", "uint256", "uint8", "bytes32"], [H("6529STREAM_SUBJECT_SCOPE_V1"), d.chainId, d.core.address, scope.collectionId, 4, manifest.viewId])),
    contentHash: { algorithm: 1n, digest: keccak256(manifestRaw), canonicalizationId: H("RAW_BYTES") }, uri: manifest.uri,
    schemaId: H("STREAM_COLLECTION_VIEW_MANIFEST_ABI_V1"), signatureScheme: Z,
    signatureHash: { algorithm: 0n, digest: "0x", canonicalizationId: Z }, effectiveAt: 0n };
  const ref = value => keccak256(coder.encode(["uint16", "bytes32", "bytes32"], [value.algorithm, keccak256(value.digest), value.canonicalizationId]));
  const declarationHash = keccak256(coder.encode(["bytes32", "uint256", "address", "address", "address", "uint256", "bytes32", "bytes32",
    "bytes32", "bytes32", "bytes32", "bytes32", "bytes32", "uint64"], [H("6529stream.preservation-record.v2"), d.chainId,
    d.views.address, d.core.address, declarationReceipt.recorder, scope.collectionId, collectionRecord.recordType, collectionRecord.subjectId,
    ref(collectionRecord.contentHash), keccak256(toUtf8Bytes(collectionRecord.uri)), collectionRecord.schemaId, Z, ref(collectionRecord.signatureHash), 0n]));
  const rendererManifest = { rendererId: H("renderer"), rendererVersion: H("version"), contextVersion: view.TAGGED_POLICY_VIEW_V2_CONTEXT,
    rendererClass: H("STATIC"), schemaHash: view.TAGGED_POLICY_VIEW_V2_OUTPUT_SCHEMA_HASH, schemaURI: "https://example.test/schema",
    manifestURI: "https://example.test/renderer", manifestHash: H("manifest"), maxJSONBytes: 262144n, maxHTMLBytes: 262144n, deprecated: false };
  const key = keccak256(coder.encode(["bytes32", "bytes32", "bytes32"], [H("6529STREAM_RENDERER_VERSION_V1"), rendererManifest.rendererId, rendererManifest.rendererVersion]));
  const input = { scope, viewId: manifest.viewId, viewRecordHash: declarationHash, expectedPrevious: Z, rendererRegistry: d.rendererRegistry.address,
    rendererVersionKey: key, expectedSourceHash: Z };
  const membership = { scopeSubject: view.taggedPolicyViewV2ScopeSubject(coords, scope), scopeManifestHash: H("membership manifest"), sourceRecordHash: H("membership source"),
    tokenCount: 2n, tokenListHash: H("tokens"), membershipHash: H("membership"), inventoryCount: 0n, inventoryPrefixHash: Z };
  const route = Object.fromEntries(["core", "router", "artist", "finality", "provider", "metadata", "schemas", "store"].flatMap(name =>
    [[name, d[name].address], [`${name}CodeHash`, d[name].codeHash]]));
  route.binding = { views: d.views.address, viewsCodeHash: d.views.codeHash, membership: d.membership.address,
    membershipCodeHash: d.membership.codeHash, readGas: 50000n, sourceGas: 500000n };
  const selection = { registry: d.rendererRegistry.address, registryCodeHash: d.rendererRegistry.codeHash, versionKey: key,
    renderer: d.renderer.address, rendererCodeHash: d.renderer.codeHash, rendererId: rendererManifest.rendererId, rendererVersion: rendererManifest.rendererVersion,
    contextVersion: rendererManifest.contextVersion, schemaHash: rendererManifest.schemaHash, readSetHash: H("reads"), registrationHash: H("registration") };
  const source = { route, membership, renderer: selection, schemaHash: declarationReceipt.viewSchemaDefinitionHash,
    manifestSchemaHash: declarationReceipt.manifestSchemaDefinitionHash, canonicalizationHash: declarationReceipt.canonicalizationDefinitionHash,
    manifestPayloadHash: keccak256(manifestRaw), viewReceiptHash: keccak256(coder.encode([c.views.getFunction("viewRecord").outputs[1]], [declarationReceipt])),
    payloadHash: keccak256(rawPayload), payloadBytes: BigInt((rawPayload.length - 2) / 2), payloadPointers: [A(101), ZA, ZA, ZA, ZA],
    payloadChunkHashes: [keccak256(rawPayload), Z, Z, Z, Z] };
  const binding = { core: d.core.address, coreCodeHash: d.core.codeHash, factory: d.policyFactory.address, factoryCodeHash: d.policyFactory.codeHash,
    sourceSet: d.sourceSet.address, sourceSetCodeHash: d.sourceSet.codeHash, chainId: d.chainId, scope, membership,
    inventoryPlan: H("inventory plan"), inventoryHash: H("inventory hash"), policyChainHash: H("policy chain"), policyCount: 1n };
  const policyHash = H("explicit policy");
  const rule = { coordinator: A(80), indexedCodeHash: keccak256("0x6060"), firstTokenIndex: 0n, frozen: true,
    moduleVersion: H("module version"), moduleManifestHash: H("module manifest"), moduleSchemaHash: H("module schema"), deploymentManifestHash: H("deployment"),
    policyHash, provider: ZA, epoch: 0n, salt: Z, componentDataHash: H("component"), explicitPolicy: true,
    collectionPolicy: { configured: true, explicitPolicy: true, frozen: true, mode: 0n, securityClass: 0n, renderRequirement: 1n, revision: 1n,
      providerEpoch: 0n, policyHash, contentStateHash: keccak256(coder.encode(["bytes32", "bytes32", "bool"], [H("6529STREAM_ENTROPY_CONFIGURATION_V1"), policyHash, true])),
      lastActionId: H("action"), artistConsentRecord: H("entropy consent") } };
  codes.set(A(80), "0x6060");
  codes.set(A(100), `0x00${manifestRaw.slice(2)}`);
  codes.set(A(101), `0x00${rawPayload.slice(2)}`);
  const family = H("new complete renderer family");
  const consent = { recordHash: H("original op17"), artistId: H("artist"), bindingGeneration: 3n,
    terms: { collectionId: scope.collectionId, metadataContract: d.router.address, familyId: H("RENDERER_CONFIG"), newStateHash: family }, authorityClass: 1n };
  const aggregate = { revision: 5n, transitionChain: H("other scopes already adopted") };
  Object.assign(f, { d, coords, caller, input, source, binding, rule, consent, aggregate, family, codes, manifest, declarationReceipt, collectionRecord,
    rendererManifest, documents, rawPayload, manifestRaw, historyRecords: new Map(), writerClass: 7n, grantCid: scope.collectionId, grantRevision: 9n,
    ratification: [false, Z, Z], evolution: [Z, Z], beforeContent: H("complete current content"), afterContent: H("complete resulting content"),
    beforeFamily: H("old renderer family"), output: '{"terminal":true,"finalized":false}' });
  f.header = n => ({ number: n, hash: H(`block${n}`), timestamp: n * 10 });
  f.post = tag => Boolean(f.resultRecord && tag >= 12);
  f.defaultCall = ({ name, args, to, tag }) => {
    const post = f.post(tag);
    const roles = { METADATA_ROUTER: "router", ARTWORK_FINALITY_REGISTRY: "finality", COLLECTION_METADATA: "metadata", ARTIST_REGISTRY: "artist", MODULE_REGISTRY: "moduleRegistry" };
    switch (name) {
      case "core": return [d.core.address];
      case "artistRegistry": return [d.artist.address];
      case "authority": case "governanceAuthority": return [A(72)];
      case "getSatellitePointer": {
        const key = Object.entries(roles).find(([name]) => H(name) === args[0])?.[1];
        if (!key) throw Error("Unknown pointer");
        return [d[key].address, d[key].codeHash, false, args[0], "0x12345678", d.moduleRegistry.address, 1n, H("module"), H("deployment"), 2n];
      }
      case "finalityRegistry": return [d.finality.address];
      case "finalityRegistryCodeHash": return [d.finality.codeHash];
      case "operationCoordinator": return [d.artistCoordinator.address];
      case "coreReads": return [d.core.address];
      case "sanctionReads": return [d.artist.address];
      case "metadataReads": case "metadataHost": return [d.metadata.address];
      case "scopeEvidenceProvider": return [d.provider.address];
      case "scopeEvidenceProviderCodeHash": return [d.provider.codeHash];
      case "schemaRegistry": return [d.schemas.address];
      case "chunkStore": return [d.store.address];
      case "suiteConfiguration": return [{ registry: d.artist.address, archive: A(73), owners: [A(74), A(75), A(76), A(77), A(78), A(79), d.artistConsentOwner.address],
        core: d.core.address, mintManager: A(81), roleRegistry: A(82), metadata: d.router.address, primaryResolver: A(83), royaltyResolver: A(84), primaryRevenueClass: H("primary"), validator: A(85) }];
      case "gasParameter": return [500000n];
      case "viewSourceBinding": return [source.route.binding];
      case "isModuleEligible": case "supportsInterface": case "collectionExists": return [true];
      case "collectionFreezeStatus": return [false];
      case "artworkFreezeMode": return [0n];
      case "staticMetadataActivation": return [H("activation"), 2n, H("overrides")];
      case "artistContentLockState": return [true, false];
      case "selectedViewRecord": return [input.viewRecordHash, false];
      case "viewRecord": return [manifest, declarationReceipt, collectionRecord];
      case "documentFacts": {
        const body = documents.get(args[0]);
        return [{ exists: true, kind: args[0] === H("RAW_BYTES") ? 1n : 0n, status: 0n, contentHash: keccak256(body), canonicalizationId: H("RAW_BYTES"),
          supersedesId: Z, totalBytes: BigInt((body.length - 2) / 2), chunkCount: 1n, declarationHash: H("definition") }];
      }
      case "documentBytes": return [documents.get(args[0])];
      case "recordHashAt": return [input.viewRecordHash];
      case "manifestPayload": return [A(100), manifestRaw];
      case "viewPayload": return [A(101), rawPayload];
      case "chunk": {
        if (args[0] === source.payloadHash) return [A(101), source.payloadBytes];
        if (f.resultRecord && args[0] === f.resultCarrier.contentHash && (post || f.priorCatalog)) return [f.resultCarrier.pointer, f.resultCarrier.byteSize];
        return [ZA, 0n];
      }
      case "version": return [{ exists: true, deprecated: false, renderer: d.renderer.address, runtimeHash: d.renderer.codeHash,
        registrationHash: selection.registrationHash, readSetHash: selection.readSetHash, analysisHash: H("analysis"), goldenHash: H("golden"), actionId: H("renderer action") }];
      case "registration": return [{ renderer: d.renderer.address, manifest: rendererManifest, schemaDocument: H("schema"), contextDocument: H("context"),
        manifestDocument: H("manifest"), analysisDocument: H("analysis"), goldenDocument: H("golden") }];
      case "rendererManifest": return [rendererManifest];
      case "requireAssignable": case "requireRetained": return [d.renderer.address, d.renderer.codeHash];
      case "sourceBindings": return [[d.core.address, d.router.address, d.sourceSet.address, d.liveAttribution.address],
        [d.core.codeHash, d.router.codeHash, d.sourceSet.codeHash, d.liveAttribution.codeHash]];
      case "encodingBinding": return [d.encoding.address, d.encoding.codeHash];
      case "targetCount": return [1n];
      case "targetAt": return [{ target: d.core.address, codeHash: d.core.codeHash, role: H("core") }];
      case "reads": return [[{ targetIndex: 0n, selector: c.core.getFunction("tokenCollectionIdentity").selector, maxReturnBytes: 128n, exact: true }]];
      case "viewPolicySourceFactoryV2": return [d.policyFactory.address];
      case "viewPolicySourceFactoryV2CodeHash": return [d.policyFactory.codeHash];
      case "dependencies": return [{ targets: [d.core.address, d.metadata.address, d.membership.address, d.inventory.address],
        codeHashes: [d.core.codeHash, d.metadata.codeHash, d.membership.codeHash, d.inventory.codeHash], chainId: d.chainId, readGas: 50000n, inventoryGas: 500000n }];
      case "policyViewBinding": return [binding];
      case "scopedPolicyFactoryProfile": return [H("6529STREAM_SCOPED_ENTROPY_POLICY_SOURCE_FACTORY_V2")];
      case "SOURCE_SET_PROFILE": return [H("6529STREAM_ENTROPY_POLICY_SOURCE_SET_V2")];
      case "factory": return [d.policyFactory.address];
      case "sourceScope": return [scope];
      case "inventoryPlan": case "currentInventoryPlan": return [binding.inventoryPlan];
      case "originalInventoryHash": return [binding.inventoryHash];
      case "originalPolicyChainHash": return [binding.policyChainHash];
      case "sourceSetForPlan": return [d.sourceSet.address, d.sourceSet.codeHash];
      case "requireCurrentSelection": return [];
      case "requireScopeMembership": case "scopeMembershipFacts": return [source.membership];
      case "sourceCount": return [binding.policyCount];
      case "sourcePolicyAt": return [rule];
      case "requireCompleteInventory": return [{ exists: true, complete: true, processedTokens: source.membership.tokenCount,
        tokenCount: source.membership.tokenCount, coordinatorCount: binding.policyCount, tokenChain: H("tokenchain"), coordinatorChain: H("coordinatorchain"), commitment: binding.inventoryHash }];
      case "inventoryScope": return [scope, source.membership];
      case "requireCoordinator": return [{ coordinator: rule.coordinator, indexedCodeHash: rule.indexedCodeHash, firstTokenIndex: rule.firstTokenIndex }];
      case "viewAdoptionHead": return [post ? f.resultRecord.recordHash : input.expectedPrevious];
      case "viewAdoptionAggregate": return [post ? f.resultRecord.aggregate : aggregate];
      case "familyWriter": return [args[2] === f.writerClass && args[0] === f.grantCid, f.grantRevision];
      case "previewPolicyViewAdoption": return [family, view.taggedPolicyViewV2SourceHash(coords, input, source, binding)];
      case "artistContentFamilyState": return [true, post ? family : f.beforeFamily];
      case "contentConsentEvidence": return [consent.recordHash];
      case "contentConsentAt": case "contentConsentRecord": return [consent];
      case "collectionArtistState": return [2n, consent.bindingGeneration, consent.artistId, 1n, H("binding")];
      case "consumedArtistContentConsent": return [post];
      case "currentArtistContentState": return [d.router.address, post ? f.afterContent : f.beforeContent];
      case "firstReleaseRatification": return f.ratification;
      case "artistContentEvolution": return post && f.ratification[0] ? [f.ratification[2], f.afterContent] : f.evolution;
      case "adoptPolicyView": {
        const currentInput = { ...input, expectedSourceHash: view.taggedPolicyViewV2SourceHash(coords, input, source, binding) };
        const record = { input: currentInput, source, sourceHash: currentInput.expectedSourceHash, recordHash: Z,
          revision: input.expectedPrevious === Z ? 1n : f.historyRecords.get(input.expectedPrevious).record.revision + 1n,
          actor: f.caller, authorizationClass: f.writerClass, grantCollectionId: f.grantCid, grantRevision: f.grantRevision,
          artistConsent: consent.recordHash, adoptedAt: BigInt(f.header(tag).timestamp), aggregate };
        record.aggregate = view.taggedPolicyViewV2NextAggregate(coords, aggregate, record);
        return [view.taggedPolicyViewV2RecordHash(coords, record)];
      }
      case "viewAdoptionCarrier": case "viewAdoptionEncoded": case "viewAdoptionProfile": {
        const record = f.historyRecords.get(args[0]);
        if (!record) throw Error("Unknown VIEW history");
        return name === "viewAdoptionCarrier" ? [record.carrier.pointer, record.carrier.contentHash, record.carrier.byteSize]
          : name === "viewAdoptionEncoded" ? [record.raw] : [record.profile];
      }
      case "tokenCollectionIdentity": return [true, scope.collectionId, 1n, false];
      case "tokenLifecycle": return [2n];
      case "tokenJSONForView": case "tokenHTMLForView": case "historicalTokenJSONForView": case "historicalTokenHTMLForView": return [f.output];
      default: throw Error(`Unmocked ${name} at ${to}`);
    }
  };
  f.provider = {
    getNetwork: async () => ({ chainId: f.wrongChain ? 999n : d.chainId }),
    getBlock: async tag => f.header(tag),
    getCode: async (target, tag) => f.codeOverride?.(getAddress(target), tag) ?? codes.get(getAddress(target)) ?? "0x",
    call: async request => {
      const parsed = all.parseTransaction({ data: request.data });
      if (!parsed) throw Error("Unknown original selector");
      const entry = { name: parsed.name, args: parsed.args, to: getAddress(request.to), tag: request.blockTag, request };
      const originalTarget = { contentConsentRecord: d.artistConsentOwner.address, contentConsentAt: d.artistConsentOwner.address,
        contentConsentEvidence: d.artist.address, suiteConfiguration: d.artistCoordinator.address }[entry.name];
      if (originalTarget && entry.to !== originalTarget) throw Error(`Wrong original ${entry.name} target`);
      f.calls.push(entry);
      const values = await f.overrides?.(entry) ?? f.defaultCall(entry);
      if (typeof values === "string") return values;
      return all.encodeFunctionResult(parsed.fragment, values);
    },
    getTransaction: async () => f.transaction,
    getTransactionReceipt: async () => f.receipt
  };
  f.addHistory = (record, profile = view.TAGGED_POLICY_VIEW_V2_PROFILE, pointer = A(102)) => {
    const raw = view.encodeTaggedPolicyViewV2Record(record);
    const carrier = { pointer, contentHash: keccak256(raw), byteSize: BigInt((raw.length - 2) / 2) };
    codes.set(pointer, `0x00${raw.slice(2)}`);
    f.historyRecords.set(record.recordHash, { record, raw, carrier, profile });
    return carrier;
  };
  f.install = (capture, mode = "direct") => {
    const p = capture.preflight;
    const draft = { input: p.input, source: p.source, sourceHash: p.input.expectedSourceHash, recordHash: Z,
      revision: p.previousRevision + 1n, actor: p.caller, authorizationClass: p.authorizationClass,
      grantCollectionId: p.grantCollectionId, grantRevision: p.grantRevision, artistConsent: consent.recordHash,
      adoptedAt: 120n, aggregate: p.aggregate };
    draft.aggregate = view.taggedPolicyViewV2NextAggregate(coords, p.aggregate, draft);
    draft.recordHash = view.taggedPolicyViewV2RecordHash(coords, draft);
    f.resultRecord = draft;
    f.resultCarrier = f.addHistory(draft);
    const txHash = H("transaction");
    const blockHash = f.header(12).hash;
    const rawLogs = [];
    const add = (iface, name, args, target) => rawLogs.push({ address: target, ...iface.encodeEventLog(iface.getEvent(name), args) });
    if (!f.priorCatalog) add(c.store, "ChunkPublished", [f.resultCarrier.contentHash, f.resultCarrier.pointer, f.resultCarrier.byteSize], d.store.address);
    add(c.router, "ArtistContentConsentApplied", [scope.collectionId, H("RENDERER_CONFIG"), consent.recordHash, f.afterContent, 1n], d.router.address);
    add(adoption, "ViewAdopted", [2n, view.TAGGED_POLICY_VIEW_V2_PROFILE, scope.collectionId, source.membership.scopeSubject, draft.recordHash, draft], d.router.address);
    const expectedSafeTxHash = H("independent safe hash");
    if (mode !== "direct") {
      if (mode === "indexed") rawLogs.push({ address: caller, topics: [safeABI.getEvent("ExecutionSuccess").topicHash, expectedSafeTxHash], data: coder.encode(["uint256"], [0n]) });
      else add(safeABI, "ExecutionSuccess", [expectedSafeTxHash, 0n], caller);
    }
    f.receipt = { hash: txHash, status: 1, blockNumber: 12, blockHash, from: mode === "direct" ? caller : A(98),
      to: mode === "direct" ? d.router.address : caller, logs: rawLogs.map((log, index) => ({ ...log, index, removed: false, transactionHash: txHash, blockNumber: 12, blockHash })) };
    f.transaction = { hash: txHash, blockNumber: 12, blockHash, chainId: d.chainId, from: f.receipt.from, to: f.receipt.to, value: 0n,
      data: mode === "direct" ? capture.prepared.call.data : safeABI.encodeFunctionData("execTransaction", [d.router.address, 0n,
        capture.prepared.call.data, 0n, 1_000_000n, 0n, 0n, ZA, ZA, "0x1234"]) };
    return { txHash, options: mode === "direct" ? { execution: "direct" } : { execution: "safe", expectedSafeTxHash } };
  };
  return f;
}
