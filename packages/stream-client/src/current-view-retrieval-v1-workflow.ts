import { Interface, id, keccak256, sha256 } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import * as p from "./current-view-retrieval-v1.js";
import * as view from "./current-tagged-policy-view-v2.js";
import * as io from "./current-scoped-policy-inventory-archive-workflow-internal.js";

// These reused tuples are structurally identical to the original ABI157 witnesses.
const producerTuple = "(address core,address router,address liveRenderer,bytes32 liveRendererRuntimeHash,address preservationAttribution,bytes32 preservationAttributionRuntimeHash)";
const admissionTuple = "(address registry,bytes32 registryCodeHash,bytes32 versionKey,bytes32 registrationHash,bytes32 readSetHash,bytes32 analysisHash,bytes32 goldenHash)";
const checkpointConfigurationTuple = "(address core,bytes32 coreCodeHash,address router,bytes32 routerCodeHash,address authority,bytes32 authorityCodeHash,address serving,bytes32 servingCodeHash,bytes32 servingConfigurationHash,uint256 chainId,uint32 readGas,uint32 servingGas)";
const checkpointSourceTuple = `(${view.TAGGED_POLICY_VIEW_V2_RECORD_TUPLE} adoption,${view.TAGGED_POLICY_VIEW_V2_POLICY_BINDING_TUPLE} policy,${producerTuple} preservation,${admissionTuple} admission,bytes32 contextHash)`;
const artistTuple = "(bool locked,address registry,bytes32 registryCodeHash,bytes32 artistId,uint64 bindingGeneration,bytes32 bindingHash,address nominatedArtist,bytes32 identityRecordHash,bytes32 acceptanceRecordHash,uint64 acceptedAt,uint64 lockedAt,bytes32 snapshotHash)";
const checkpointAbi = new Interface([
  `function configuration() view returns (${checkpointConfigurationTuple})`,
  "function checkpointProfile() pure returns (bytes32)",
  `function currentSource(${p.CURRENT_VIEW_RETRIEVAL_V1_SCOPE_TUPLE} scope) view returns (${checkpointSourceTuple})`,
]);
const routerAbi = new Interface([
  "function core() view returns (address)",
  `function artistPresentation(uint256 collectionId) view returns (${artistTuple})`,
]);
const capabilityAbi = new Interface(["function supportsInterface(bytes4 id) view returns (bool)"]);
const archiveAbi = new Interface([
  "function core() view returns (address)", "function profileHash() view returns (bytes32)",
  `function coverage(bytes32 hash) view returns (${p.CURRENT_VIEW_RETRIEVAL_V1_COVERAGE_TUPLE})`,
  `function objectIdentity(bytes32 objectHash) view returns (${p.CURRENT_VIEW_RETRIEVAL_V1_OBJECT_TUPLE})`,
  `function receipt(bytes32 hash) view returns (${p.CURRENT_VIEW_RETRIEVAL_V1_ARCHIVE_RECEIPT_TUPLE},bytes identifier,bytes signature)`,
  `function family(bytes32 hash) view returns (${p.CURRENT_VIEW_RETRIEVAL_V1_FAMILY_TUPLE},uint8 status,uint64 revision)`,
  `function currentReceiptPair(bytes32 firstReceipt,bytes32 secondReceipt,bytes32 artistId,bytes32 objectHash) view returns (${p.CURRENT_VIEW_RETRIEVAL_V1_CURRENT_PAIR_TUPLE})`,
]);
const storeAbi = new Interface(["function chunk(bytes32) view returns (address pointer,uint32 length)"]);
// Original consumer type(...).interfaceId; these are not getter-only approximations.
const CHECKPOINT_INTERFACE = "0xc5a3fffa";
const ARCHIVE_INTERFACE = "0x138c8955";
const host = p.currentViewRetrievalV1Interface();
type Reader = io.Reader;
type ReceiptReader = io.ReceiptReader;
type Configuration = p.CurrentViewRetrievalV1Configuration;
type Observation = p.CurrentViewRetrievalV1Observation;
type Receipt = p.CurrentViewRetrievalV1Receipt;
type Scope = p.CurrentViewRetrievalV1Scope;

export interface CurrentViewRetrievalV1HistoryDeployment {
  readonly chainId: bigint;
  readonly witness: io.CodePin;
  readonly configuration: Configuration;
  /** Reviewed complete Bytes.read linked closure. Supplied deployment provenance. */
  readonly historyLinkedDependencies: readonly io.CodePin[];
}
export interface CurrentViewRetrievalV1Deployment extends CurrentViewRetrievalV1HistoryDeployment {
  /** Reviewed complete original source, Archive, signature and retention linked closure. */
  readonly linkedDependencies: readonly io.CodePin[];
}
export interface CurrentViewRetrievalV1RetainedPayload {
  readonly receipt: Receipt;
  readonly payload: Hex;
}
interface Artist {
  readonly locked: boolean; readonly registry: Address; readonly registryCodeHash: Hex; readonly artistId: Hex;
  readonly bindingGeneration: bigint; readonly bindingHash: Hex; readonly nominatedArtist: Address;
  readonly identityRecordHash: Hex; readonly acceptanceRecordHash: Hex; readonly acceptedAt: bigint;
  readonly lockedAt: bigint; readonly snapshotHash: Hex;
}
interface CheckpointSource {
  readonly adoption: view.TaggedPolicyViewV2Record;
  readonly policy: view.TaggedPolicyViewV2PolicyBinding;
  readonly preservation: { readonly core: Address; readonly router: Address; readonly liveRenderer: Address; readonly liveRendererRuntimeHash: Hex; readonly preservationAttribution: Address; readonly preservationAttributionRuntimeHash: Hex };
  readonly admission: { readonly registry: Address; readonly registryCodeHash: Hex; readonly versionKey: Hex; readonly registrationHash: Hex; readonly readSetHash: Hex; readonly analysisHash: Hex; readonly goldenHash: Hex };
  readonly contextHash: Hex;
}
interface CheckpointConfiguration {
  readonly core: Address; readonly coreCodeHash: Hex; readonly router: Address; readonly routerCodeHash: Hex;
  readonly authority: Address; readonly authorityCodeHash: Hex; readonly serving: Address; readonly servingCodeHash: Hex;
  readonly servingConfigurationHash: Hex; readonly chainId: bigint; readonly readGas: bigint; readonly servingGas: bigint;
}
interface ArchiveFacts {
  readonly coverage: p.CurrentViewRetrievalV1Coverage;
  readonly object: p.CurrentViewRetrievalV1Object;
  readonly pair: p.CurrentViewRetrievalV1CurrentPair;
  readonly writer: p.CurrentViewRetrievalV1WriterEvidence;
  readonly writerSignature: Hex;
}
interface TransactionFacts extends p.CurrentViewRetrievalV1TransactionEvidence { readonly signature: Hex }
interface SourceFacts {
  readonly checkpointConfiguration: CheckpointConfiguration;
  readonly checkpoint: CheckpointSource;
  readonly artist: Artist;
  readonly payloadRuntimes: readonly Hex[];
  readonly store: io.CodePin;
  readonly runtimePins: readonly io.CodePin[];
}
export interface CurrentViewRetrievalV1Preview {
  readonly deployment: CurrentViewRetrievalV1Deployment;
  readonly caller: Address;
  readonly request: p.CurrentViewRetrievalV1Request;
  readonly observed: io.Block;
  readonly observation: Observation;
  readonly digest: Hex;
  readonly source: SourceFacts;
  readonly archive: ArchiveFacts;
  readonly manifests: readonly { readonly stepIndex: bigint; readonly archive: ArchiveFacts; readonly transaction: TransactionFacts }[];
  readonly finalTransaction: TransactionFacts | null;
  readonly nonceKey: Hex;
  readonly nonceUsed: boolean;
  readonly revocationEpoch: bigint;
  readonly originalPreparationSucceeded: true;
  readonly signatureVerified: false;
  readonly storeAvailabilityChecked: false;
}
export interface CurrentViewRetrievalV1History {
  readonly deployment: CurrentViewRetrievalV1HistoryDeployment;
  readonly observed: io.Block;
  readonly receipt: Receipt;
  readonly payload: Hex;
  readonly observation: Observation;
  readonly signature: Hex;
  readonly revoked: boolean;
  readonly revocationEpoch: bigint;
  readonly nonceUsed: boolean;
  readonly currentnessVerified: false;
  readonly signatureVerified: false;
  readonly suppliedPayload: boolean;
}
type PublishStage = Readonly<{
  kind: "publish"; preview: CurrentViewRetrievalV1Preview; payload: Hex;
  chunks: readonly (p.CurrentViewRetrievalV1Chunk & { readonly pointer: Address })[];
  writerCode: Hex; signatureRoute: p.CurrentViewRetrievalV1SignatureRoute; predictedReceipt: Receipt;
}>;
type RevokeStage = Readonly<{ kind: "revoke"; history: CurrentViewRetrievalV1History; nextEpoch: bigint }>;
export interface CurrentViewRetrievalV1Capture {
  readonly deployment: CurrentViewRetrievalV1Deployment;
  readonly prepared: p.CurrentViewRetrievalV1Call;
  readonly observed: io.Block;
  readonly gasLimit: bigint;
  readonly retainedPayload: CurrentViewRetrievalV1RetainedPayload | null;
  readonly stage: PublishStage | RevokeStage;
  readonly captureHash: Hex;
  readonly originalCallSimulated: false;
}
export type CurrentViewRetrievalV1ReceiptOptions = io.ReceiptOptions;

function coordinates(d: CurrentViewRetrievalV1HistoryDeployment) { return { chainId: d.chainId, witness: d.witness.address }; }
function historyDeployment(input: CurrentViewRetrievalV1HistoryDeployment): CurrentViewRetrievalV1HistoryDeployment {
  io.keys(input, ["chainId", "witness", "configuration", "historyLinkedDependencies"]);
  const chainId = io.uint(input.chainId); if (chainId === 0n) throw Error("Zero chain");
  const witness = io.codePin(input.witness);
  const configuration = p.validateCurrentViewRetrievalV1Configuration({ chainId, witness: witness.address }, input.configuration);
  return io.freeze({ chainId, witness, configuration, historyLinkedDependencies: io.pinList(input.historyLinkedDependencies) });
}
function deployment(input: CurrentViewRetrievalV1Deployment): CurrentViewRetrievalV1Deployment {
  io.keys(input, ["chainId", "witness", "configuration", "historyLinkedDependencies", "linkedDependencies"]);
  return io.freeze({ ...historyDeployment({ chainId: input.chainId, witness: input.witness, configuration: input.configuration, historyLinkedDependencies: input.historyLinkedDependencies }), linkedDependencies: io.pinList(input.linkedDependencies) });
}
function localDeployment(d: CurrentViewRetrievalV1HistoryDeployment): CurrentViewRetrievalV1HistoryDeployment {
  return { chainId: d.chainId, witness: d.witness, configuration: d.configuration, historyLinkedDependencies: d.historyLinkedDependencies };
}
function retained(input: CurrentViewRetrievalV1RetainedPayload | undefined): CurrentViewRetrievalV1RetainedPayload | null {
  if (input === undefined) return null;
  io.keys(input, ["receipt", "payload"]);
  return io.freeze({ receipt: p.normalizeCurrentViewRetrievalV1Receipt(input.receipt), payload: io.bytes(input.payload, 524288) });
}
async function read<T>(provider: Reader, d: CurrentViewRetrievalV1HistoryDeployment, method: string, args: readonly unknown[], tag: number): Promise<T> {
  return io.read(provider, d.witness.address, host, method, args, tag, undefined, d.configuration.readGas);
}
function configurationPins(d: CurrentViewRetrievalV1Deployment): readonly io.CodePin[] {
  return (["core", "router", "checkpoint", "archive"] as const).map(name => ({ address: d.configuration[name], codeHash: d.configuration[`${name}CodeHash`] }));
}
async function localBindings(provider: Reader, d: CurrentViewRetrievalV1HistoryDeployment, tag: number): Promise<void> {
  await io.runtime(provider, d.witness, tag);
  io.equal(await read(provider, d, "configuration", [], tag), d.configuration, "Original configuration differs");
  io.equal(await read(provider, d, "configurationHash", [], tag), p.currentViewRetrievalV1ConfigurationHash(d.configuration), "Configuration hash differs");
  io.equal(await read(provider, d, "retrievalProfile", [], tag), p.CURRENT_VIEW_RETRIEVAL_V1_PROFILE, "Unsupported retrieval profile");
}
async function currentBindings(provider: Reader, d: CurrentViewRetrievalV1Deployment, tag: number): Promise<void> {
  await localBindings(provider, d, tag);
  await io.runtimes(provider, [...configurationPins(d), ...d.linkedDependencies], tag);
  io.equal(await read(provider, d, "supportsInterface", [p.currentViewRetrievalV1InterfaceId()], tag), true, "Witness capability absent");
  const c = d.configuration;
  io.equal(await io.read(provider, c.checkpoint, capabilityAbi, "supportsInterface", [CHECKPOINT_INTERFACE], tag, undefined, c.readGas), true, "Checkpoint capability absent");
  io.equal(await io.read(provider, c.archive, capabilityAbi, "supportsInterface", [ARCHIVE_INTERFACE], tag, undefined, c.readGas), true, "Archive capability absent");
  io.equal(await io.read(provider, c.archive, archiveAbi, "profileHash", [], tag, undefined, c.readGas), id("STREAM_EXTERNAL_ARTIFACT_COVERAGE_V1"), "Archive profile differs");
  io.equal(await io.read(provider, c.archive, archiveAbi, "core", [], tag, undefined, c.readGas), c.core, "Archive Core differs");
  io.equal(await io.read(provider, c.router, routerAbi, "core", [], tag, undefined, c.readGas), c.core, "Router Core differs");
  io.equal(await io.read(provider, c.checkpoint, checkpointAbi, "checkpointProfile", [], tag, undefined, c.readGas), id("6529STREAM_ADOPTED_VIEW_PRESERVATION_CHECKPOINT_V1"), "Checkpoint profile differs");
}
async function sourceFacts(provider: Reader, d: CurrentViewRetrievalV1Deployment, scope: Scope, tag: number): Promise<SourceFacts> {
  const c = d.configuration;
  const checkpointConfiguration = await io.read<CheckpointConfiguration>(provider, c.checkpoint, checkpointAbi, "configuration", [], tag, undefined, c.readGas);
  for (const key of ["core", "coreCodeHash", "router", "routerCodeHash", "chainId"] as const) io.equal(checkpointConfiguration[key], c[key], "Checkpoint configuration differs");
  const checkpoint = await io.read<CheckpointSource>(provider, c.checkpoint, checkpointAbi, "currentSource", [scope], tag, undefined, c.sourceGas);
  const adoption = checkpoint.adoption, route = adoption.source.route;
  io.hash(adoption.recordHash); io.hash(adoption.sourceHash); io.hash(checkpoint.contextHash);
  io.equal(adoption.input.scope, scope, "Original adopted full scope differs");
  for (const key of ["core", "coreCodeHash", "router", "routerCodeHash"] as const) io.equal(route[key], c[key], "Original adopted route differs");
  const artist = await io.read<Artist>(provider, c.router, routerAbi, "artistPresentation", [scope.collectionId], tag, undefined, c.readGas);
  if (!artist.locked || artist.registry !== route.artist || artist.registryCodeHash !== route.artistCodeHash
    || artist.bindingGeneration === 0n || artist.acceptedAt === 0n || artist.lockedAt === 0n) throw Error("Original locked Artist differs");
  for (const key of ["artistId", "snapshotHash", "bindingHash", "identityRecordHash", "acceptanceRecordHash"] as const) io.hash(artist[key]);
  io.address(artist.nominatedArtist);
  const runtimePins = (["core", "router", "artist", "finality", "provider", "metadata", "schemas", "store"] as const)
    .map(name => ({ address: route[name], codeHash: route[`${name}CodeHash`] }));
  runtimePins.push({ address: checkpointConfiguration.authority, codeHash: checkpointConfiguration.authorityCodeHash },
    { address: checkpointConfiguration.serving, codeHash: checkpointConfiguration.servingCodeHash },
    { address: route.binding.views, codeHash: route.binding.viewsCodeHash }, { address: route.binding.membership, codeHash: route.binding.membershipCodeHash },
    { address: checkpoint.policy.factory, codeHash: checkpoint.policy.factoryCodeHash }, { address: checkpoint.policy.sourceSet, codeHash: checkpoint.policy.sourceSetCodeHash },
    { address: adoption.source.renderer.registry, codeHash: adoption.source.renderer.registryCodeHash }, { address: adoption.source.renderer.renderer, codeHash: adoption.source.renderer.rendererCodeHash },
    { address: checkpoint.preservation.liveRenderer, codeHash: checkpoint.preservation.liveRendererRuntimeHash }, { address: checkpoint.preservation.preservationAttribution, codeHash: checkpoint.preservation.preservationAttributionRuntimeHash },
    { address: checkpoint.admission.registry, codeHash: checkpoint.admission.registryCodeHash });
  await io.runtimes(provider, runtimePins, tag);
  const count = Number((adoption.source.payloadBytes + 8191n) / 8192n);
  if (count < 1 || count > 5) throw Error("Original VIEW payload bound");
  const payloadRuntimes: Hex[] = [];
  for (let i = 0; i < count; i++) payloadRuntimes.push(io.bytes(await provider.getCode(adoption.source.payloadPointers[i]!, tag), 8193));
  view.validateTaggedPolicyViewV2PayloadCarriers(adoption.source, payloadRuntimes);
  return io.freeze({ checkpointConfiguration, checkpoint, artist, payloadRuntimes, store: { address: route.store, codeHash: route.storeCodeHash }, runtimePins });
}
function expectedSource(d: CurrentViewRetrievalV1Deployment, facts: SourceFacts): p.CurrentViewRetrievalV1Source {
  const a = facts.checkpoint.adoption;
  const payload = view.validateTaggedPolicyViewV2PayloadCarriers(a.source, facts.payloadRuntimes);
  return { scope: a.input.scope, core: d.configuration.core, router: d.configuration.router,
    adoptionRecord: a.recordHash, adoptionSourceHash: a.sourceHash, declaration: a.source.route.binding.views,
    declarationRecord: a.input.viewRecordHash, payloadHash: a.source.payloadHash, checkpointContextHash: facts.checkpoint.contextHash,
    requestedURI: payload.imageURI, artistId: facts.artist.artistId, artistPresentationHash: keccak256(io.coder.encode([artistTuple], [facts.artist])) as Hex };
}
async function archiveFacts(provider: Reader, d: CurrentViewRetrievalV1Deployment, source: p.CurrentViewRetrievalV1Source, coverageHash: Hex, tag: number): Promise<ArchiveFacts> {
  const c = d.configuration;
  const coverage = p.normalizeCurrentViewRetrievalV1Coverage(await io.read(provider, c.archive, archiveAbi, "coverage", [coverageHash], tag, undefined, c.readGas));
  io.equal(coverage.coverageHash, coverageHash, "Original coverage key differs");
  const object = p.normalizeCurrentViewRetrievalV1Object(await io.read(provider, c.archive, archiveAbi, "objectIdentity", [coverage.objectHash], tag, undefined, c.readGas));
  io.equal(object.artistId, source.artistId, "Original object Artist differs");
  for (const key of ["artistId", "contentHash", "sha256Digest", "arweaveDataRoot", "byteSize"] as const) io.equal(object[key], coverage[key], "Original object/coverage differs");
  io.equal(object.canonicalizationId, id("RAW_BYTES"), "Original object canonicalization differs");
  const pair = p.normalizeCurrentViewRetrievalV1CurrentPair(await io.read(provider, c.archive, archiveAbi, "currentReceiptPair", [coverage.firstReceiptHash, coverage.secondReceiptHash, source.artistId, coverage.objectHash], tag, undefined, c.archiveGas));
  p.validateCurrentViewRetrievalV1CurrentPair(coverage, pair);
  const receiptRow = await io.rpc(provider, c.archive, archiveAbi, "receipt", [coverage.secondReceiptHash], tag, undefined, c.archiveGas);
  io.bytes(archiveAbi.encodeFunctionResult("receipt", receiptRow), 65536);
  const family = await io.rpc(provider, c.archive, archiveAbi, "family", [coverage.secondFamilyRecordHash], tag, undefined, c.readGas);
  const writer: p.CurrentViewRetrievalV1WriterEvidence = { receipt: p.normalizeCurrentViewRetrievalV1ArchiveReceipt(receiptRow[0] as p.CurrentViewRetrievalV1ArchiveReceipt), identifier: io.bytes(receiptRow[1], 65536), family: p.normalizeCurrentViewRetrievalV1Family(family[0] as p.CurrentViewRetrievalV1Family), status: io.uint(family[1], 8), revision: io.uint(family[2], 64) };
  p.validateCurrentViewRetrievalV1WriterEvidence(c, coverage, writer);
  return io.freeze({ coverage, object, pair, writer, writerSignature: io.bytes(receiptRow[2], 65536) });
}
async function transactionFacts(provider: Reader, d: CurrentViewRetrievalV1Deployment, coverage: p.CurrentViewRetrievalV1Coverage, txId: Hex, tag: number): Promise<TransactionFacts> {
  const row = await io.rpc(provider, d.configuration.archive, archiveAbi, "receipt", [coverage.firstReceiptHash], tag, undefined, d.configuration.archiveGas);
  io.bytes(archiveAbi.encodeFunctionResult("receipt", row), 65536);
  const result = { receipt: p.normalizeCurrentViewRetrievalV1ArchiveReceipt(row[0] as p.CurrentViewRetrievalV1ArchiveReceipt), locator: io.bytes(row[1], 32), signature: io.bytes(row[2], 65536) };
  p.validateCurrentViewRetrievalV1TransactionEvidence(d.configuration, coverage, txId, { receipt: result.receipt, locator: result.locator });
  return io.freeze(result);
}

async function prepareAt(provider: Reader, d: CurrentViewRetrievalV1Deployment, caller: Address, request: p.CurrentViewRetrievalV1Request,
  tag: number, gasLimit: bigint): Promise<CurrentViewRetrievalV1Preview> {
  const observed = await io.chain(provider, d.chainId, tag);
  await currentBindings(provider, d, tag);
  const source = await sourceFacts(provider, d, request.scope, tag);
  // The original host executes complete capped Archive admission, including native proof bundles.
  // Independent direct reads below join its returned coordinates; they do not replace that call.
  const original = await io.rpc(provider, d.witness.address, host, "prepare", [request], tag, caller, gasLimit);
  const observation = p.normalizeCurrentViewRetrievalV1Observation(original[0] as Observation), digest = io.hash(original[1]);
  io.equal(observation.source, expectedSource(d, source), "Prepared source differs from actual current source");
  const archive = await archiveFacts(provider, d, observation.source, request.coverageHash, tag);
  io.equal(observation.object, archive.object, "Prepared object differs");
  io.equal(observation.coverage, archive.coverage, "Prepared original coverage differs");
  const writer = p.validateCurrentViewRetrievalV1WriterEvidence(d.configuration, archive.coverage, archive.writer);
  io.equal(observation.writer, writer.writer, "Prepared writer differs");
  p.validateCurrentViewRetrievalV1Prepared(coordinates(d), d.configuration, request, observation, digest,
    { timestamp: observed.timestamp, adoptedAt: source.checkpoint.adoption.adoptedAt, institutionalObservedAt: writer.observedAt });
  const manifests: { stepIndex: bigint; archive: ArchiveFacts; transaction: TransactionFacts }[] = [];
  for (let i = 0; i < observation.steps.length; i++) {
    const step = observation.steps[i]!;
    if (step.kind !== 3n) continue;
    const facts = await archiveFacts(provider, d, observation.source, step.manifestCoverage, tag);
    io.equal(facts.coverage.objectHash, step.manifestObject, "Manifest object differs");
    io.equal(facts.object.byteSize, BigInt((step.manifestBytes.length - 2) / 2), "Manifest byte size differs");
    io.equal(facts.object.contentHash, keccak256(step.manifestBytes), "Manifest full bytes differ");
    io.equal(facts.object.sha256Digest, sha256(step.manifestBytes), "Manifest SHA256 differs");
    manifests.push({ stepIndex: BigInt(i), archive: facts,
      transaction: await transactionFacts(provider, d, facts.coverage, p.currentViewRetrievalV1URI(step.fromURI).transactionId, tag) });
  }
  const uri = p.currentViewRetrievalV1URI(observation.resolvedURI);
  const finalTransaction = uri.kind === 2n ? await transactionFacts(provider, d, observation.coverage, uri.transactionId, tag) : null;
  const nonceKey = p.currentViewRetrievalV1NonceKey(observation.writer, observation.nonce);
  const nonceUsed = await read<boolean>(provider, d, "nonceUsed", [nonceKey], tag);
  const revocationEpoch = io.uint(await read(provider, d, "revocationEpoch", [request.scope], tag), 64);
  await io.unchanged(provider, observed);
  return io.freeze({ deployment: d, caller, request, observed, observation, digest, source, archive, manifests,
    finalTransaction, nonceKey, nonceUsed, revocationEpoch, originalPreparationSucceeded: true,
    signatureVerified: false, storeAvailabilityChecked: false });
}
/** Actual original prepare; it intentionally does not consume/check a nonce or validate a writer signature. */
export async function previewCurrentViewRetrievalV1(provider: Reader, inputDeployment: CurrentViewRetrievalV1Deployment,
  inputCaller: Address, inputRequest: p.CurrentViewRetrievalV1Request,
  options: { readonly blockTag: number; readonly gasLimit: bigint }): Promise<CurrentViewRetrievalV1Preview> {
  const d = deployment(inputDeployment), caller = io.address(inputCaller), request = p.validateCurrentViewRetrievalV1Request(inputRequest);
  io.keys(options, ["blockTag", "gasLimit"]); const tag = io.number(options.blockTag), cap = io.gas(options.gasLimit);
  return prepareAt(provider, d, caller, request, tag, cap);
}
async function historyAt(provider: Reader, d: CurrentViewRetrievalV1HistoryDeployment, recordHash: Hex, tag: number,
  supplied: CurrentViewRetrievalV1RetainedPayload | null, gasLimit: bigint): Promise<CurrentViewRetrievalV1History> {
  const observed = await io.chain(provider, d.chainId, tag);
  await localBindings(provider, d, tag);
  const receipt = p.normalizeCurrentViewRetrievalV1Receipt(await read(provider, d, "record", [recordHash], tag));
  io.equal(receipt.recordHash, recordHash, "Original record key differs");
  if (receipt.recordedAt > observed.timestamp) throw Error("Retained record is newer than observed block");
  let payload: Hex;
  if (supplied) { io.equal(receipt, supplied.receipt, "Supplied retained receipt differs"); payload = supplied.payload; }
  else {
    await io.runtimes(provider, d.historyLinkedDependencies, tag);
    // This public retained-byte read is not a source readGas-capped protocol subcall.
    payload = io.bytes(await io.read(provider, d.witness.address, host, "encoded", [recordHash], tag, undefined, gasLimit), 524288);
  }
  const authenticated = p.authenticateCurrentViewRetrievalV1History(coordinates(d), d.configuration, receipt, payload);
  const revoked = await read<boolean>(provider, d, "revoked", [recordHash], tag);
  const revocationEpoch = io.uint(await read(provider, d, "revocationEpoch", [authenticated.observation.source.scope], tag), 64);
  if (revoked && revocationEpoch === 0n) throw Error("Revoked record has no scope epoch");
  const nonceUsed = await read<boolean>(provider, d, "nonceUsed", [p.currentViewRetrievalV1NonceKey(receipt.writer, authenticated.observation.nonce)], tag);
  if (!nonceUsed) throw Error("Retained publication nonce was not consumed");
  await io.unchanged(provider, observed);
  return io.freeze({ deployment: d, observed, receipt, payload, observation: authenticated.observation, signature: authenticated.signature,
    revoked, revocationEpoch, nonceUsed, currentnessVerified: false, signatureVerified: false, suppliedPayload: supplied !== null });
}
export async function inspectCurrentViewRetrievalV1History(provider: Reader, inputDeployment: CurrentViewRetrievalV1HistoryDeployment,
  inputRecordHash: Hex, options: { readonly blockTag: number; readonly gasLimit: bigint; readonly retainedPayload?: CurrentViewRetrievalV1RetainedPayload }): Promise<CurrentViewRetrievalV1History> {
  const d = historyDeployment(inputDeployment), recordHash = io.hash(inputRecordHash);
  io.keys(options, ["blockTag", "gasLimit"], ["retainedPayload"]); const tag = io.number(options.blockTag), cap = io.gas(options.gasLimit), supplied = retained(options.retainedPayload);
  return historyAt(provider, d, recordHash, tag, supplied, cap);
}
async function payloadChunks(provider: Reader, store: io.CodePin, payload: Hex, tag: number, cap: bigint): Promise<PublishStage["chunks"]> {
  await io.runtime(provider, store, tag);
  const result: (p.CurrentViewRetrievalV1Chunk & { pointer: Address })[] = [];
  for (const chunk of p.currentViewRetrievalV1Chunks(payload)) {
    const row = await io.rpc(provider, store.address, storeAbi, "chunk", [chunk.hash], tag, undefined, cap);
    const pointer = io.address(row[0]); io.equal(row[1], chunk.byteLength, "Stored payload chunk length differs");
    io.equal(io.bytes(await provider.getCode(pointer, tag), 8193), chunk.runtime, "Stored payload STOP bytes differ");
    result.push({ ...chunk, pointer });
  }
  return io.freeze(result);
}
function sealCapture(value: Omit<CurrentViewRetrievalV1Capture, "captureHash">): CurrentViewRetrievalV1Capture {
  return io.freeze({ ...value, captureHash: io.fingerprint(value) });
}
function snapshotCapture(input: CurrentViewRetrievalV1Capture): CurrentViewRetrievalV1Capture {
  io.keys(input, ["deployment", "prepared", "observed", "gasLimit", "retainedPayload", "stage", "captureHash", "originalCallSimulated"]);
  const saved = structuredClone(input); const { captureHash, ...facts } = saved;
  io.equal(io.fingerprint(facts), io.hash(captureHash), "Capture fingerprint differs");
  const d = deployment(saved.deployment), call = p.normalizeCurrentViewRetrievalV1Call(saved.prepared);
  io.equal(call.coordinates, coordinates(d), "Capture deployment/call differs");
  io.gas(saved.gasLimit); io.number(saved.observed.blockNumber); io.hash(saved.observed.blockHash); io.uint(saved.observed.timestamp, 64);
  if (saved.originalCallSimulated !== false || saved.stage.kind !== call.request.kind) throw Error("Capture stage differs");
  return io.freeze(saved);
}
export async function captureCurrentViewRetrievalV1(provider: Reader, inputDeployment: CurrentViewRetrievalV1Deployment,
  inputCaller: Address, inputRequest: p.CurrentViewRetrievalV1CallRequest,
  options: { readonly blockTag: number; readonly gasLimit: bigint; readonly retainedPayload?: CurrentViewRetrievalV1RetainedPayload }): Promise<CurrentViewRetrievalV1Capture> {
  const d = deployment(inputDeployment), prepared = p.prepareCurrentViewRetrievalV1Call(coordinates(d), inputCaller, inputRequest);
  io.keys(options, ["blockTag", "gasLimit"], ["retainedPayload"]);
  const tag = io.number(options.blockTag), cap = io.gas(options.gasLimit), supplied = retained(options.retainedPayload);
  let stage: PublishStage | RevokeStage, observed: io.Block;
  if (prepared.request.kind === "publish") {
    if (supplied) throw Error("Supplied retained payload only applies to revoke");
    const preview = await prepareAt(provider, d, prepared.caller, prepared.request.request, tag, cap);
    if (preview.nonceUsed) throw Error("Original writer nonce is already used");
    const signature = prepared.request.signature;
    // The direct-writer branch does not examine account code in the original validator.
    const direct = prepared.caller === preview.observation.writer && signature === "0x";
    const writerCode = direct ? "0x" as Hex : io.bytes(await provider.getCode(preview.observation.writer, tag), io.MAX_RUNTIME);
    const signatureRoute = p.currentViewRetrievalV1SignatureRoute(prepared.caller, preview.observation.writer, preview.digest, signature, writerCode);
    const payload = p.currentViewRetrievalV1Payload(preview.observation, signature);
    const chunks = await payloadChunks(provider, preview.source.store, payload, tag, d.configuration.readGas);
    observed = preview.observed;
    stage = { kind: "publish", preview, payload, chunks, writerCode, signatureRoute,
      predictedReceipt: p.currentViewRetrievalV1PreviewReceipt(coordinates(d), d.configuration, preview.observation, signature, observed.timestamp) };
  } else {
    const history = await historyAt(provider, localDeployment(d), prepared.request.recordHash, tag, supplied, cap);
    const revocation = p.validateCurrentViewRetrievalV1Revocation(prepared.caller, history.receipt, prepared.request.reasonHash, history.revoked, history.revocationEpoch);
    stage = { kind: "revoke", history, nextEpoch: revocation.nextEpoch }; observed = history.observed;
  }
  await io.unchanged(provider, observed);
  return sealCapture({ deployment: d, prepared, observed, gasLimit: cap, retainedPayload: supplied, stage, originalCallSimulated: false });
}
function comparable(input: CurrentViewRetrievalV1Capture): unknown {
  if (input.stage.kind === "revoke") {
    const { observed: _observed, ...history } = input.stage.history;
    return { deployment: input.deployment, prepared: input.prepared, gasLimit: input.gasLimit, retainedPayload: input.retainedPayload,
      stage: { kind: input.stage.kind, history, nextEpoch: input.stage.nextEpoch } };
  }
  const { observed: _observed, ...preview } = input.stage.preview;
  const stableArchive = ({ pair: _pair, ...facts }: ArchiveFacts) => facts;
  return { deployment: input.deployment, prepared: input.prepared, gasLimit: input.gasLimit,
    stage: { kind: "publish", preview: { ...preview, archive: stableArchive(preview.archive), manifests: preview.manifests.map(m => ({ ...m, archive: stableArchive(m.archive) })) },
      payload: input.stage.payload, chunks: input.stage.chunks, writerCode: input.stage.writerCode, signatureRoute: input.stage.signatureRoute } };
}
async function revalidate(provider: Reader, saved: CurrentViewRetrievalV1Capture, tag: number): Promise<CurrentViewRetrievalV1Capture> {
  await io.unchanged(provider, saved.observed);
  const fresh = await captureCurrentViewRetrievalV1(provider, saved.deployment, saved.prepared.caller, saved.prepared.request,
    { blockTag: tag, gasLimit: saved.gasLimit, ...(saved.retainedPayload ? { retainedPayload: saved.retainedPayload } : {}) });
  io.equal(comparable(fresh), comparable(saved)); return fresh;
}
async function originalCall(provider: Reader, saved: CurrentViewRetrievalV1Capture, tag: number, timestamp: bigint, compareCaptured = true): Promise<Hex | null> {
  const result = await io.rpc(provider, saved.deployment.witness.address, host, saved.prepared.request.kind,
    saved.prepared.request.kind === "publish" ? [saved.prepared.request.request, saved.prepared.request.signature]
      : [saved.prepared.request.recordHash, saved.prepared.request.reasonHash], tag, saved.prepared.caller, saved.gasLimit);
  if (saved.stage.kind === "publish" && saved.prepared.request.kind === "publish") {
    if (!compareCaptured) return io.hash(result[0]);
    const expected = p.currentViewRetrievalV1PreviewReceipt(coordinates(saved.deployment), saved.deployment.configuration,
      saved.stage.preview.observation, saved.prepared.request.signature, timestamp).recordHash;
    io.equal(result, [expected], "Original publication return differs at simulated timestamp"); return expected;
  }
  io.equal(result, [], "Original revocation return differs"); return null;
}
export async function simulateCurrentViewRetrievalV1(provider: Reader, input: CurrentViewRetrievalV1Capture,
  options: { readonly blockTag: number }) {
  const saved = snapshotCapture(input); io.keys(options, ["blockTag"]); const tag = io.number(options.blockTag);
  if (tag < saved.observed.blockNumber) throw Error("Simulation predates capture");
  await revalidate(provider, saved, saved.observed.blockNumber);
  const current = await revalidate(provider, saved, tag), result = await originalCall(provider, current, tag, current.observed.timestamp);
  await io.unchanged(provider, current.observed);
  return io.freeze({ capture: current, result, originalCallSucceeded: true as const, stateChangesPersisted: false as const,
    signatureAuthority: current.stage.kind === "publish" ? "original-publish-call" as const : "original-revoke-caller" as const });
}

export async function inspectCurrentViewRetrievalV1Current(provider: Reader, inputDeployment: CurrentViewRetrievalV1Deployment,
  inputRecordHash: Hex, options: { readonly blockTag: number; readonly gasLimit: bigint }) {
  const d = deployment(inputDeployment), recordHash = io.hash(inputRecordHash);
  io.keys(options, ["blockTag", "gasLimit"]); const tag = io.number(options.blockTag), cap = io.gas(options.gasLimit);
  const history = await historyAt(provider, localDeployment(d), recordHash, tag, null, cap);
  if (history.revoked) throw Error("Original witness revoked");
  await currentBindings(provider, d, tag);
  const source = await sourceFacts(provider, d, history.observation.source.scope, tag);
  io.equal(expectedSource(d, source), history.observation.source, "Retained source is no longer current");
  const original = await io.rpc(provider, d.witness.address, host, "requireCorrespondence", [recordHash], tag, undefined, cap);
  const currentSource = p.normalizeCurrentViewRetrievalV1Source(original[0] as p.CurrentViewRetrievalV1Source);
  const receipt = p.normalizeCurrentViewRetrievalV1Receipt(original[1] as Receipt);
  const admission = p.normalizeCurrentViewRetrievalV1Admission(original[2] as p.CurrentViewRetrievalV1Admission);
  io.equal(currentSource, history.observation.source, "Original current source differs");
  io.equal(receipt, history.receipt, "Original current receipt differs");
  p.validateCurrentViewRetrievalV1ArchiveAdmission(history.observation, admission);
  const archive = await archiveFacts(provider, d, currentSource, receipt.coverageHash, tag);
  io.equal(archive.object, history.observation.object, "Current object differs");
  io.equal(archive.coverage, history.observation.coverage, "Current retained coverage differs");
  io.equal(archive.writer.receipt.writer, receipt.writer, "Current institutional writer differs");
  await io.unchanged(provider, history.observed);
  return io.freeze({ history, source, archive, admission, originalCurrentCallSucceeded: true as const,
    freshSignatureRevalidated: false as const, historicalDeadlineRevalidated: false as const });
}

async function receiptPins(provider: Reader, saved: CurrentViewRetrievalV1Capture, tag: number): Promise<void> {
  await io.runtime(provider, saved.deployment.witness, tag);
  if (saved.stage.kind !== "publish") return;
  await io.runtimes(provider, [...configurationPins(saved.deployment), ...saved.deployment.linkedDependencies,
    ...saved.deployment.historyLinkedDependencies, ...saved.stage.preview.source.runtimePins], tag);
  for (const chunk of saved.stage.chunks) io.equal(io.bytes(await provider.getCode(chunk.pointer, tag), 8193), chunk.runtime, "Mined retained chunk runtime differs");
  const a = saved.stage.preview.source.checkpoint.adoption.source;
  for (let i = 0; i < saved.stage.preview.source.payloadRuntimes.length; i++) {
    io.equal(io.bytes(await provider.getCode(a.payloadPointers[i]!, tag), 8193), saved.stage.preview.source.payloadRuntimes[i], "Mined adopted payload runtime differs");
  }
  if (saved.stage.signatureRoute.route !== "direct-writer") io.equal(io.bytes(await provider.getCode(saved.stage.preview.observation.writer, tag), io.MAX_RUNTIME), saved.stage.writerCode, "Mined writer code differs");
}
/** Exact preceding/end-block attribution. Unrelated same-block nonce/epoch changes cause refusal. */
export async function reconcileCurrentViewRetrievalV1Receipt(provider: ReceiptReader, input: CurrentViewRetrievalV1Capture,
  inputTransactionHash: Hex, options: CurrentViewRetrievalV1ReceiptOptions) {
  const saved = snapshotCapture(input), transactionHash = io.hash(inputTransactionHash);
  const checked: CurrentViewRetrievalV1ReceiptOptions = options.execution === "direct"
    ? (io.keys(options, ["execution"]), { execution: "direct" })
    : (io.keys(options, ["execution", "expectedSafeTxHash"]), { execution: "safe", expectedSafeTxHash: io.hash(options.expectedSafeTxHash) });
  if (options.execution !== "direct" && options.execution !== "safe") throw Error("Unsupported receipt transport");
  const transport = await io.transport(provider, { chainId: saved.deployment.chainId, caller: saved.prepared.caller,
    call: saved.prepared.call, observed: saved.observed }, transactionHash, checked);
  await revalidate(provider, saved, saved.observed.blockNumber);
  const prior = await revalidate(provider, saved, transport.observed.blockNumber - 1), d = saved.deployment;
  await receiptPins(provider, prior, transport.observed.blockNumber);
  const originalLogs = transport.logs.filter(log => io.same(log.address, d.witness.address));
  if (originalLogs.length !== 1) throw Error("Expected exactly one original witness event");
  let after: CurrentViewRetrievalV1History;
  if (prior.stage.kind === "publish" && prior.prepared.request.kind === "publish") {
    const receipt = p.currentViewRetrievalV1PreviewReceipt(coordinates(d), d.configuration,
      prior.stage.preview.observation, prior.prepared.request.signature, transport.observed.timestamp);
    io.one(transport.logs, d.witness.address, host, "ViewRetrievalRecorded", [receipt.recordHash, receipt.sourceKey, receipt.writer, receipt]);
    after = await historyAt(provider, localDeployment(d), receipt.recordHash, transport.observed.blockNumber, null, saved.gasLimit);
    io.equal(after.receipt, receipt, "Mined record differs");
    io.equal(after.payload, prior.stage.payload, "Mined retained payload differs");
    io.equal(after.revoked, false, "New record revoked within receipt block");
    io.equal(after.revocationEpoch, prior.stage.preview.revocationEpoch, "Receipt scope epoch attribution differs");
    if (!after.nonceUsed) throw Error("Publication nonce not consumed");
  } else if (prior.stage.kind === "revoke" && prior.prepared.request.kind === "revoke") {
    io.one(transport.logs, d.witness.address, host, "ViewRetrievalRevoked", [prior.prepared.request.recordHash, prior.prepared.caller, prior.prepared.request.reasonHash]);
    // Revocation never needs current source/Archive or live retained carriers.
    after = await historyAt(provider, localDeployment(d), prior.prepared.request.recordHash, transport.observed.blockNumber,
      { receipt: prior.stage.history.receipt, payload: prior.stage.history.payload }, saved.gasLimit);
    io.equal(after.receipt, prior.stage.history.receipt, "Revocation changed immutable record");
    io.equal(after.revoked, true, "Revocation state absent");
    io.equal(after.revocationEpoch, prior.stage.nextEpoch, "Exact scope epoch increment differs");
    io.equal(after.nonceUsed, prior.stage.history.nonceUsed, "Revocation changed publication nonce");
  } else throw Error("Capture branch differs");
  io.finish(transport.logs, [d.witness.address], transport.safeIndex);
  await io.unchanged(provider, prior.observed); await io.unchanged(provider, transport.observed);
  return io.freeze({ transactionHash, observed: transport.observed, prior: prior.observed, kind: prior.stage.kind, history: after,
    timestampRecomputed: prior.stage.kind === "publish", originalEventAuthenticated: true as const,
    currentSourceReauthorizedAtEndBlock: false as const, intraBlockTraceProven: false as const });
}
function errorSummary(error: unknown) {
  const e = error && typeof error === "object" ? error as { code?: unknown; data?: unknown } : {};
  const code = typeof e.code === "string" && ["CALL_EXCEPTION", "NETWORK_ERROR", "SERVER_ERROR", "TIMEOUT"].includes(e.code) ? e.code : "UNKNOWN_ERROR";
  let data: Hex | null = null;
  if (typeof e.data === "string" && /^0x[0-9a-fA-F]*$/.test(e.data) && e.data.length % 2 === 0 && e.data.length <= 8194) data = e.data.toLowerCase() as Hex;
  return { code, data };
}
/** Refusal observation is a fixed-block eth_call, never proof of a submitted transaction's rollback. */
export async function observeCurrentViewRetrievalV1Refusal(provider: Reader, input: CurrentViewRetrievalV1Capture,
  options: { readonly blockTag: number }) {
  const saved = snapshotCapture(input); io.keys(options, ["blockTag"]); const tag = io.number(options.blockTag);
  if (tag < saved.observed.blockNumber) throw Error("Refusal observation predates capture");
  await revalidate(provider, saved, saved.observed.blockNumber);
  const d = saved.deployment, observed = await io.chain(provider, d.chainId, tag);
  await localBindings(provider, d, tag);
  const observation = saved.stage.kind === "publish" ? saved.stage.preview.observation : saved.stage.history.observation;
  async function local() {
    return { nonceUsed: await read<boolean>(provider, d, "nonceUsed", [p.currentViewRetrievalV1NonceKey(observation.writer, observation.nonce)], tag),
      epoch: io.uint(await read(provider, d, "revocationEpoch", [observation.source.scope], tag), 64),
      revoked: saved.prepared.request.kind === "revoke" ? await read<boolean>(provider, d, "revoked", [saved.prepared.request.recordHash], tag) : null };
  }
  const before = await local(); let result: Hex | null = null, error: ReturnType<typeof errorSummary> | null = null;
  try { result = await originalCall(provider, saved, tag, observed.timestamp, false); } catch (cause) { error = errorSummary(cause); }
  const after = await local(); io.equal(after, before, "Fixed-block local observation changed"); await io.unchanged(provider, observed);
  return io.freeze({ observed, before, after, result, error,
    outcome: error === null ? "call-succeeded" as const : error.code === "CALL_EXCEPTION" ? "execution-reverted" as const : "rpc-failed" as const,
    capturePredictionChecked: false as const, stateChangesPersisted: false as const, submittedTransactionRollbackProven: false as const });
}
