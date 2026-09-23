import { Interface, ParamType, id, keccak256 } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import * as io from "./current-scoped-policy-inventory-archive-workflow-internal.js";
import * as inv from "./current-view-preservation-inventory-v1.js";
import * as bundle from "./current-view-preservation-bundle-v1.js";
import * as retrieval from "./current-view-retrieval-v1.js";

// Reviewed original memory-only public read workers. Nominal compiler selectors stay separate
// from structural ABI witnesses; these are never wallet endpoints. Linked runtime completeness
// is supplied deployment provenance. The original host call is the transaction admission authority.
const workers = {
  "environment": {
    "contract": "StreamBundleArchiveReads",
    "method": "environment",
    "selector": "0x4f6bb089",
    "inputs": [
      "(address[6] targets, bytes32[6] codeHashes, uint256 chainId, uint256 readGas, uint256 archiveGas) d"
    ],
    "outputs": [
      "bytes32"
    ]
  },
  "admit": {
    "contract": "StreamViewPreservationArchiveReadsV1",
    "method": "admit",
    "selector": "0x77edbfe6",
    "inputs": [
      "(address[6] targets, bytes32[6] codeHashes, uint256 chainId, uint256 readGas, uint256 archiveGas) d",
      "bytes32 artist",
      "(uint8 kind, bytes32 role, address source, bytes32 sourceRecord, uint256 sourceIndex, uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri, uint64 byteSize, bytes32 schemaId, bytes32 formatId, bytes32 catalogId, bytes32 catalogHash, bytes32 objectHash, bytes32 originalCoverageHash, bytes32 provenanceHash) item",
      "(uint8 backend, bytes32 coverageHash, bytes32 objectHash) proof"
    ],
    "outputs": [
      "((uint8 backend, bytes32 coverageHash, bytes32 objectHash) proof, bytes32 originalBundleHash, bytes32 immutablePartsHash, (bytes32 coverageHash, bytes32 objectHash, bytes32 artistId, bytes32 contentHash, bytes32 sha256Digest, bytes32 arweaveDataRoot, uint64 byteSize, bytes32 firstFamilyRecordHash, bytes32 secondFamilyRecordHash, bytes32 firstReceiptHash, bytes32 secondReceiptHash, bytes32 firstFixityHash, bytes32 secondFixityHash, bytes32 checkpointHash, bytes32 profileHash) externalOriginal, (bytes32 completionHash, bytes32 artifactHash, bytes32 artistId, bytes32 schemaId, bytes32 canonicalizationId, bytes32 contentHash, uint64 byteLength, uint32 chunkCount, bytes32 firstFamilyRecordHash, bytes32 secondFamilyRecordHash, uint64 validationEpoch, bytes32 evidenceChainHash) onchainOriginal) result",
      "bytes32 observation"
    ]
  },
  "current": {
    "contract": "StreamViewPreservationArchiveReadsV1",
    "method": "current",
    "selector": "0x29054134",
    "inputs": [
      "(address[6] targets, bytes32[6] codeHashes, uint256 chainId, uint256 readGas, uint256 archiveGas) d",
      "bytes32 artist",
      "(uint8 kind, bytes32 role, address source, bytes32 sourceRecord, uint256 sourceIndex, uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri, uint64 byteSize, bytes32 schemaId, bytes32 formatId, bytes32 catalogId, bytes32 catalogHash, bytes32 objectHash, bytes32 originalCoverageHash, bytes32 provenanceHash) item",
      "((uint8 backend, bytes32 coverageHash, bytes32 objectHash) proof, bytes32 originalBundleHash, bytes32 immutablePartsHash, (bytes32 coverageHash, bytes32 objectHash, bytes32 artistId, bytes32 contentHash, bytes32 sha256Digest, bytes32 arweaveDataRoot, uint64 byteSize, bytes32 firstFamilyRecordHash, bytes32 secondFamilyRecordHash, bytes32 firstReceiptHash, bytes32 secondReceiptHash, bytes32 firstFixityHash, bytes32 secondFixityHash, bytes32 checkpointHash, bytes32 profileHash) externalOriginal, (bytes32 completionHash, bytes32 artifactHash, bytes32 artistId, bytes32 schemaId, bytes32 canonicalizationId, bytes32 contentHash, uint64 byteLength, uint32 chunkCount, bytes32 firstFamilyRecordHash, bytes32 secondFamilyRecordHash, uint64 validationEpoch, bytes32 evidenceChainHash) onchainOriginal) saved"
    ],
    "outputs": [
      "bytes32 observation"
    ]
  },
  "retrievalEnvironment": {
    "contract": "StreamViewRetrievalConsumerV1",
    "method": "environment",
    "selector": "0xb748d450",
    "inputs": [
      "(address[6] targets, bytes32[6] codeHashes, uint256 chainId, uint256 readGas, uint256 archiveGas) d",
      "(uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope",
      "bytes32 originalEnvironment"
    ],
    "outputs": [
      "bytes32"
    ]
  },
  "retrievalContext": {
    "contract": "StreamViewRetrievalConsumerV1",
    "method": "context",
    "selector": "0x74d643a0",
    "inputs": [
      "(address[6] targets, bytes32[6] codeHashes, uint256 chainId, uint256 readGas, uint256 archiveGas) d",
      "bytes32 plan",
      "((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, (bytes32 planId, uint256 collectionId, bytes32 scopeSubject, bytes32 artistId, (bytes32 rootRecordHash, bytes32 snapshotRecordHash, bytes32 referenceRenderRecordHash, bytes32 intentRecordHash, bytes32 intentWaiverRecordHash, bytes32 interviewEvidenceHash, bytes32 rightsStatementRecordHash, bytes32 workDescriptionRecordHash) originals, bytes32 sourceContextHash, bytes32 tokenInventoryHash, uint64 tokenCount, uint64 segmentCount, uint64 itemCount, bytes32 segmentChainHash, bytes32 renderCriticalEvidenceHash) inventory) e"
    ],
    "outputs": [
      "((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, bytes32 subject, bytes32 artistId, (bytes32 recordHash, bytes32 scopeSubject, bytes32 predecessor, uint64 revision, bytes32 chainHash, bytes32 manifestHash, uint32 manifestBytes, bytes32 sourceHash, address publisher, uint8 authorizationClass, uint64 grantRevision, uint8 displayAuthorizationClass, uint64 displayGrantRevision, uint64 recordedAt, bytes32 schemaHash, bytes32 profileHash, bytes32 canonicalizationHash) snapshot, (bytes32 scopeSubject, (bytes32 recordHash, bytes32 recordChainHash, uint256 collectionId, bytes32 referenceId, bytes32 predecessor, uint64 revision, bytes32 payloadHash, uint32 payloadBytes, bytes32 sourcesHash, bytes32 snapshotRecordHash, uint64 snapshotRevision, address recorder, uint8 authorizationClass, uint64 grantRevision, uint64 effectiveAt, uint64 recordedAt, bytes32 reasonHash, bytes32 schemaHash, bytes32 profileHash, bytes32 canonicalizationHash) observation) referenceRender, (bytes32 scopeSubject, bytes32 workDescriptionRecordHash, bytes32 rightsStatementRecordHash, bytes32 workPayloadHash, bytes32 rightsPayloadHash, bytes32 workSelectionHash, bytes32 rightsSelectionHash, uint64 workRevision, uint64 rightsRevision) descriptions, ((bytes32 recordHash, uint8 kind, bytes32 payloadHash, address recorder, uint64 recordedAt, uint64 recordIndex, bytes32 recordChainHash, bytes32 receiptHash, (bytes32 attestationRecordHash, bytes32 artistId, bytes32 bindingHash, uint64 bindingGeneration, address signer, uint8 authorityClass, uint32 requiredCapability, uint64 signedAt, bytes32 publicationHash) publication, bytes32 publicationEvidenceHash) record, (bytes32 artistId, bytes32 bindingHash, uint64 generation, bytes32 identityRecordHash) association, uint8 origin, uint8 interviewStatus, (bytes32 recordHash, uint8 kind, bytes32 payloadHash, address recorder, uint64 recordedAt, uint64 recordIndex, bytes32 recordChainHash, bytes32 receiptHash, (bytes32 attestationRecordHash, bytes32 artistId, bytes32 bindingHash, uint64 bindingGeneration, address signer, uint8 authorityClass, uint32 requiredCapability, uint64 signedAt, bytes32 publicationHash) publication, bytes32 publicationEvidenceHash) interview, bytes32 interviewArchiveReferenceHash, uint8 interviewPayloadCorrespondence, bytes32 predecessor, address submitter, uint64 revision, uint64 selectedAt, bytes32 catalogsHash, bytes32 selectionHash) conservation, bytes32 interviewEvidenceHash, bytes32 nativeHash, bytes32 rootRecordHash, bytes32 tokenInventoryHash, bytes32 checkpointHash, bytes32 outputManifestRecord, bytes32 adoptionRecord, bytes32 viewId, bytes32 payloadHash, bytes32 sourceContextHash, bytes32 policyChainHash, bytes32 outputRoot, bytes32 manifestIndexHash, uint64 tokenCount) c"
    ]
  },
  "retrievalAdmit": {
    "contract": "StreamViewRetrievalConsumerV1",
    "method": "admit",
    "selector": "0xd4a4227c",
    "inputs": [
      "(address[6] targets, bytes32[6] codeHashes, uint256 chainId, uint256 readGas, uint256 archiveGas) d",
      "((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, bytes32 subject, bytes32 artistId, (bytes32 recordHash, bytes32 scopeSubject, bytes32 predecessor, uint64 revision, bytes32 chainHash, bytes32 manifestHash, uint32 manifestBytes, bytes32 sourceHash, address publisher, uint8 authorizationClass, uint64 grantRevision, uint8 displayAuthorizationClass, uint64 displayGrantRevision, uint64 recordedAt, bytes32 schemaHash, bytes32 profileHash, bytes32 canonicalizationHash) snapshot, (bytes32 scopeSubject, (bytes32 recordHash, bytes32 recordChainHash, uint256 collectionId, bytes32 referenceId, bytes32 predecessor, uint64 revision, bytes32 payloadHash, uint32 payloadBytes, bytes32 sourcesHash, bytes32 snapshotRecordHash, uint64 snapshotRevision, address recorder, uint8 authorizationClass, uint64 grantRevision, uint64 effectiveAt, uint64 recordedAt, bytes32 reasonHash, bytes32 schemaHash, bytes32 profileHash, bytes32 canonicalizationHash) observation) referenceRender, (bytes32 scopeSubject, bytes32 workDescriptionRecordHash, bytes32 rightsStatementRecordHash, bytes32 workPayloadHash, bytes32 rightsPayloadHash, bytes32 workSelectionHash, bytes32 rightsSelectionHash, uint64 workRevision, uint64 rightsRevision) descriptions, ((bytes32 recordHash, uint8 kind, bytes32 payloadHash, address recorder, uint64 recordedAt, uint64 recordIndex, bytes32 recordChainHash, bytes32 receiptHash, (bytes32 attestationRecordHash, bytes32 artistId, bytes32 bindingHash, uint64 bindingGeneration, address signer, uint8 authorityClass, uint32 requiredCapability, uint64 signedAt, bytes32 publicationHash) publication, bytes32 publicationEvidenceHash) record, (bytes32 artistId, bytes32 bindingHash, uint64 generation, bytes32 identityRecordHash) association, uint8 origin, uint8 interviewStatus, (bytes32 recordHash, uint8 kind, bytes32 payloadHash, address recorder, uint64 recordedAt, uint64 recordIndex, bytes32 recordChainHash, bytes32 receiptHash, (bytes32 attestationRecordHash, bytes32 artistId, bytes32 bindingHash, uint64 bindingGeneration, address signer, uint8 authorityClass, uint32 requiredCapability, uint64 signedAt, bytes32 publicationHash) publication, bytes32 publicationEvidenceHash) interview, bytes32 interviewArchiveReferenceHash, uint8 interviewPayloadCorrespondence, bytes32 predecessor, address submitter, uint64 revision, uint64 selectedAt, bytes32 catalogsHash, bytes32 selectionHash) conservation, bytes32 interviewEvidenceHash, bytes32 nativeHash, bytes32 rootRecordHash, bytes32 tokenInventoryHash, bytes32 checkpointHash, bytes32 outputManifestRecord, bytes32 adoptionRecord, bytes32 viewId, bytes32 payloadHash, bytes32 sourceContextHash, bytes32 policyChainHash, bytes32 outputRoot, bytes32 manifestIndexHash, uint64 tokenCount) c",
      "(uint8 kind, bytes32 role, address source, bytes32 sourceRecord, uint256 sourceIndex, uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri, uint64 byteSize, bytes32 schemaId, bytes32 formatId, bytes32 catalogId, bytes32 catalogHash, bytes32 objectHash, bytes32 originalCoverageHash, bytes32 provenanceHash) item",
      "bytes32 recordHash"
    ],
    "outputs": [
      "((uint8 backend, bytes32 coverageHash, bytes32 objectHash) proof, bytes32 originalBundleHash, bytes32 immutablePartsHash, (bytes32 coverageHash, bytes32 objectHash, bytes32 artistId, bytes32 contentHash, bytes32 sha256Digest, bytes32 arweaveDataRoot, uint64 byteSize, bytes32 firstFamilyRecordHash, bytes32 secondFamilyRecordHash, bytes32 firstReceiptHash, bytes32 secondReceiptHash, bytes32 firstFixityHash, bytes32 secondFixityHash, bytes32 checkpointHash, bytes32 profileHash) externalOriginal, (bytes32 completionHash, bytes32 artifactHash, bytes32 artistId, bytes32 schemaId, bytes32 canonicalizationId, bytes32 contentHash, uint64 byteLength, uint32 chunkCount, bytes32 firstFamilyRecordHash, bytes32 secondFamilyRecordHash, uint64 validationEpoch, bytes32 evidenceChainHash) onchainOriginal) a",
      "bytes32 observation"
    ]
  },
  "retrievalCurrent": {
    "contract": "StreamViewRetrievalConsumerV1",
    "method": "current",
    "selector": "0xa32f8151",
    "inputs": [
      "(address[6] targets, bytes32[6] codeHashes, uint256 chainId, uint256 readGas, uint256 archiveGas) d",
      "((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, bytes32 subject, bytes32 artistId, (bytes32 recordHash, bytes32 scopeSubject, bytes32 predecessor, uint64 revision, bytes32 chainHash, bytes32 manifestHash, uint32 manifestBytes, bytes32 sourceHash, address publisher, uint8 authorizationClass, uint64 grantRevision, uint8 displayAuthorizationClass, uint64 displayGrantRevision, uint64 recordedAt, bytes32 schemaHash, bytes32 profileHash, bytes32 canonicalizationHash) snapshot, (bytes32 scopeSubject, (bytes32 recordHash, bytes32 recordChainHash, uint256 collectionId, bytes32 referenceId, bytes32 predecessor, uint64 revision, bytes32 payloadHash, uint32 payloadBytes, bytes32 sourcesHash, bytes32 snapshotRecordHash, uint64 snapshotRevision, address recorder, uint8 authorizationClass, uint64 grantRevision, uint64 effectiveAt, uint64 recordedAt, bytes32 reasonHash, bytes32 schemaHash, bytes32 profileHash, bytes32 canonicalizationHash) observation) referenceRender, (bytes32 scopeSubject, bytes32 workDescriptionRecordHash, bytes32 rightsStatementRecordHash, bytes32 workPayloadHash, bytes32 rightsPayloadHash, bytes32 workSelectionHash, bytes32 rightsSelectionHash, uint64 workRevision, uint64 rightsRevision) descriptions, ((bytes32 recordHash, uint8 kind, bytes32 payloadHash, address recorder, uint64 recordedAt, uint64 recordIndex, bytes32 recordChainHash, bytes32 receiptHash, (bytes32 attestationRecordHash, bytes32 artistId, bytes32 bindingHash, uint64 bindingGeneration, address signer, uint8 authorityClass, uint32 requiredCapability, uint64 signedAt, bytes32 publicationHash) publication, bytes32 publicationEvidenceHash) record, (bytes32 artistId, bytes32 bindingHash, uint64 generation, bytes32 identityRecordHash) association, uint8 origin, uint8 interviewStatus, (bytes32 recordHash, uint8 kind, bytes32 payloadHash, address recorder, uint64 recordedAt, uint64 recordIndex, bytes32 recordChainHash, bytes32 receiptHash, (bytes32 attestationRecordHash, bytes32 artistId, bytes32 bindingHash, uint64 bindingGeneration, address signer, uint8 authorityClass, uint32 requiredCapability, uint64 signedAt, bytes32 publicationHash) publication, bytes32 publicationEvidenceHash) interview, bytes32 interviewArchiveReferenceHash, uint8 interviewPayloadCorrespondence, bytes32 predecessor, address submitter, uint64 revision, uint64 selectedAt, bytes32 catalogsHash, bytes32 selectionHash) conservation, bytes32 interviewEvidenceHash, bytes32 nativeHash, bytes32 rootRecordHash, bytes32 tokenInventoryHash, bytes32 checkpointHash, bytes32 outputManifestRecord, bytes32 adoptionRecord, bytes32 viewId, bytes32 payloadHash, bytes32 sourceContextHash, bytes32 policyChainHash, bytes32 outputRoot, bytes32 manifestIndexHash, uint64 tokenCount) c",
      "(uint8 kind, bytes32 role, address source, bytes32 sourceRecord, uint256 sourceIndex, uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri, uint64 byteSize, bytes32 schemaId, bytes32 formatId, bytes32 catalogId, bytes32 catalogHash, bytes32 objectHash, bytes32 originalCoverageHash, bytes32 provenanceHash) item",
      "((uint8 backend, bytes32 coverageHash, bytes32 objectHash) proof, bytes32 originalBundleHash, bytes32 immutablePartsHash, (bytes32 coverageHash, bytes32 objectHash, bytes32 artistId, bytes32 contentHash, bytes32 sha256Digest, bytes32 arweaveDataRoot, uint64 byteSize, bytes32 firstFamilyRecordHash, bytes32 secondFamilyRecordHash, bytes32 firstReceiptHash, bytes32 secondReceiptHash, bytes32 firstFixityHash, bytes32 secondFixityHash, bytes32 checkpointHash, bytes32 profileHash) externalOriginal, (bytes32 completionHash, bytes32 artifactHash, bytes32 artistId, bytes32 schemaId, bytes32 canonicalizationId, bytes32 contentHash, uint64 byteLength, uint32 chunkCount, bytes32 firstFamilyRecordHash, bytes32 secondFamilyRecordHash, uint64 validationEpoch, bytes32 evidenceChainHash) onchainOriginal) saved",
      "bytes32 witnessHash"
    ],
    "outputs": [
      "bytes32 observation"
    ]
  }
} as const;

import { inspectCurrentViewPreservationInventoryV1History, type CurrentViewPreservationInventoryV1SegmentLocator } from "./current-view-preservation-inventory-v1-workflow.js";
export type CurrentViewPreservationBundleV1ReceiptOptions = io.ReceiptOptions;
export type CurrentViewPreservationBundleV1SegmentLocator = CurrentViewPreservationInventoryV1SegmentLocator;
export interface CurrentViewPreservationBundleV1HistoryDeployment { readonly chainId: bigint; readonly core: Address; readonly bundle: io.CodePin }
export interface CurrentViewPreservationBundleV1Deployment extends CurrentViewPreservationBundleV1HistoryDeployment {
  readonly environmentReader: io.CodePin;
  readonly archiveReader: io.CodePin;
  readonly retrievalReader: io.CodePin;
  readonly linkedDependencies: readonly io.CodePin[];
}
type Dependencies = bundle.CurrentViewPreservationBundleV1Dependencies;
type Progress = bundle.CurrentViewPreservationBundleV1Progress;
type Refresh = bundle.CurrentViewPreservationBundleV1Refresh;
type Admission = bundle.CurrentViewPreservationBundleV1Admission;
type Evidence = bundle.CurrentViewPreservationBundleV1Evidence;
type Item = inv.CurrentViewPreservationInventoryV1Item;
type Inventory = Awaited<ReturnType<typeof inspectCurrentViewPreservationInventoryV1History>>;
type Request = bundle.CurrentViewPreservationBundleV1Request;
export interface CurrentViewPreservationBundleV1AdmissionObservation { readonly item: Item; readonly admission: Admission; readonly witnessHash: Hex }
export interface CurrentViewPreservationBundleV1Stage {
  readonly dependencies: Dependencies;
  readonly dependencyHash: Hex;
  readonly inventory: Inventory;
  readonly baseEnvironment: Hex;
  readonly environment: Hex | null;
  readonly companion: io.CodePin | null;
  readonly before: Progress;
  readonly after: Progress;
  readonly admissions: readonly CurrentViewPreservationBundleV1AdmissionObservation[];
  readonly admitted: CurrentViewPreservationBundleV1AdmissionObservation | null;
  readonly observation: Hex | null;
  readonly refreshId: Hex | null;
  readonly refreshBefore: Refresh | null;
  readonly refreshAfter: Refresh | null;
  readonly evidence: Evidence | null;
  readonly existing: boolean;
  readonly initialObservationChainAuthenticated: false;
}
export interface CurrentViewPreservationBundleV1WorkflowCapture {
  readonly deployment: CurrentViewPreservationBundleV1Deployment;
  readonly prepared: bundle.CurrentViewPreservationBundleV1Call;
  readonly observed: io.Block;
  readonly gasLimit: bigint;
  readonly stage: CurrentViewPreservationBundleV1Stage;
  readonly originalCallResult: Hex;
  readonly originalCallSimulated: true;
  readonly captureHash: Hex;
}
const host = () => bundle.currentViewPreservationBundleV1Interface();
const environmentAbi = new Interface([
  "function currentArtifactEnvironment() view returns (bytes32 environmentHash,uint64 validationEpoch)",
  "function currentExternalArtifactEnvironment() view returns (bytes32 environmentHash,uint64 healthRevision)"
]);
const MAX_ITEMS = 65536;
const eventName = (suffix: string) => `ViewPreservationBundle${suffix}`;
function historyDeployment(v: CurrentViewPreservationBundleV1HistoryDeployment): CurrentViewPreservationBundleV1HistoryDeployment {
  io.keys(v, ["chainId", "core", "bundle"]); return io.freeze({ chainId: io.uint(v.chainId), core: io.address(v.core), bundle: io.codePin(v.bundle) });
}
const hd = (d: CurrentViewPreservationBundleV1HistoryDeployment) => historyDeployment({ chainId: d.chainId, core: d.core, bundle: d.bundle });
function deployment(v: CurrentViewPreservationBundleV1Deployment): CurrentViewPreservationBundleV1Deployment {
  io.keys(v, ["chainId", "core", "bundle", "environmentReader", "archiveReader", "retrievalReader", "linkedDependencies"]);
  return io.freeze({ ...hd(v), environmentReader: io.codePin(v.environmentReader), archiveReader: io.codePin(v.archiveReader), retrievalReader: io.codePin(v.retrievalReader), linkedDependencies: io.pinList(v.linkedDependencies) });
}
const coordinates = (d: CurrentViewPreservationBundleV1HistoryDeployment) => ({ chainId: d.chainId, core: d.core, bundle: d.bundle.address });
const read = <T>(p: io.Reader, d: CurrentViewPreservationBundleV1HistoryDeployment, method: string, args: readonly unknown[], tag: number, cap?: bigint): Promise<T> => io.read(p, d.bundle.address, host(), method, args, tag, undefined, cap);
const pins = (d: Dependencies) => d.targets.map((address, i) => ({ address, codeHash: d.codeHashes[i]! }));
function locators(v: readonly CurrentViewPreservationBundleV1SegmentLocator[]) {
  if (!Array.isArray(v) || v.length > 16384) throw Error("Segment client allocation limit exceeded");
  const seen = new Set<string>(); return v.map(value => { io.keys(value, ["transactionHash", "logIndex"]); const row = { transactionHash: io.hash(value.transactionHash), logIndex: io.number(value.logIndex) };
    const key = `${row.transactionHash}:${row.logIndex}`; if (seen.has(key)) throw Error("Duplicate segment locator"); seen.add(key); return row; });
}
function zero(t: ParamType): unknown {
  if (t.baseType === "tuple") return Object.fromEntries(t.components!.map(v => [v.name, zero(v)]));
  if (t.baseType === "array") return Array.from({ length: Math.max(0, t.arrayLength!) }, () => zero(t.arrayChildren!));
  if (t.type === "address") return io.ZERO_ADDRESS;
  if (t.type === "bool") return false;
  if (t.type === "string") return "";
  if (t.type.startsWith("bytes")) return `0x${"00".repeat(Number(t.type.slice(5)) || 0)}`;
  return 0n;
}
const emptyProgress = () => zero(ParamType.from(bundle.CURRENT_VIEW_PRESERVATION_BUNDLE_V1_PROGRESS_TUPLE)) as Progress;
const emptyRefresh = () => zero(ParamType.from(bundle.CURRENT_VIEW_PRESERVATION_BUNDLE_V1_REFRESH_TUPLE)) as Refresh;
const hashOf = (types: readonly string[], values: readonly unknown[]) => keccak256(io.coder.encode(types, values)) as Hex;
const itemChain = (previous: Hex, plan: Hex, index: bigint, item: Item, a: Admission) => hashOf(["bytes32", "bytes32", "bytes32", "uint64", "bytes32", bundle.CURRENT_VIEW_PRESERVATION_BUNDLE_V1_ADMISSION_TUPLE],
  [id("6529STREAM_VIEW_PRESERVATION_BUNDLE_COVERED_ITEM_V1"), previous, plan, index, inv.currentViewPreservationInventoryV1ItemHash(item), a]);
const observationChain = (previous: Hex, index: bigint, item: Item, observation: Hex) => hashOf(["bytes32", "bytes32", "uint64", "bytes32", "bytes32"],
  [id("6529STREAM_VIEW_PRESERVATION_BUNDLE_CURRENT_OBSERVATION_V1"), previous, index, inv.currentViewPreservationInventoryV1ItemHash(item), observation]);
const refreshKey = (d: CurrentViewPreservationBundleV1HistoryDeployment, dep: Hex, plan: Hex, environment: Hex) => hashOf(["bytes32", "uint256", "address", "bytes32", "bytes32", "bytes32"],
  [id("6529STREAM_VIEW_PRESERVATION_BUNDLE_REFRESH_V1"), d.chainId, d.bundle.address, dep, plan, environment]);
async function bindings(p: io.Reader, d: CurrentViewPreservationBundleV1HistoryDeployment, tag: number) {
  await io.runtime(p, d.bundle, tag);
  const dependencies = bundle.normalizeCurrentViewPreservationBundleV1Dependencies(await read(p, d, "dependencies", [], tag));
  if (dependencies.chainId !== d.chainId || dependencies.targets[0] !== d.core) throw Error("Bundle deployment identity differs");
  const dependencyHash = hashOf([bundle.CURRENT_VIEW_PRESERVATION_BUNDLE_V1_DEPENDENCIES_TUPLE], [dependencies]);
  io.equal(await read(p, d, "dependencyHash", [], tag), dependencyHash, "Bundle dependency hash differs");
  io.equal(await read(p, d, "bundleProfile", [], tag), id("6529STREAM_VIEW_PRESERVATION_BUNDLE_IMMUTABLE_STOP_AGGREGATE_V1"), "Wrong original VIEW bundle profile");
  for (const [name, at] of [["core", 0], ["metadataHost", 1], ["renderCriticalInventory", 2], ["artifactCoverage", 3], ["externalCoverage", 4]] as const)
    io.equal(await read(p, d, name, [], tag), dependencies.targets[at], "Named bundle dependency differs");
  for (const [name, at] of [["coreCodeHash", 0], ["metadataCodeHash", 1], ["inventoryCodeHash", 2]] as const)
    io.equal(await read(p, d, name, [], tag), dependencies.codeHashes[at], "Named runtime differs");
  io.equal(await read(p, d, "deploymentChainId", [], tag), d.chainId, "Bundle chain differs");
  return { dependencies, dependencyHash };
}
async function inventoryHistory(p: io.ReceiptReader, d: CurrentViewPreservationBundleV1HistoryDeployment, deps: Dependencies, planId: Hex,
  retained: readonly CurrentViewPreservationBundleV1SegmentLocator[], tag: number): Promise<Inventory> {
  const value = await inspectCurrentViewPreservationInventoryV1History(p, { chainId: d.chainId, core: d.core, inventory: { address: deps.targets[2], codeHash: deps.codeHashes[2] } }, planId, { blockTag: tag, segments: retained });
  const e = value.evidence?.inventory;
  if (!e || e.planId !== planId || e.segmentCount === 0n || e.itemCount === 0n || e.artistId === io.ZERO || e.renderCriticalEvidenceHash === io.ZERO) throw Error("Complete original VIEW inventory required");
  const original = value.dependencies;
  for (const [a, b] of [[0, 0], [1, 1], [10, 3], [11, 4]] as const) io.equal([original.targets[a], original.codeHashes[a]], [deps.targets[b], deps.codeHashes[b]], "Inventory/archive reciprocity differs");
  io.equal([original.artistTargets[4], original.artistCodeHashes[4]], [deps.targets[5], deps.codeHashes[5]], "Original Artist Archive differs");
  return value;
}
async function baseEnvironment(p: io.Reader, d: CurrentViewPreservationBundleV1Deployment, deps: Dependencies, tag: number, cap: bigint) {
  if (deps.readGas < 50000n || deps.archiveGas < deps.readGas) throw Error("Invalid original bundle budgets");
  await io.runtimes(p, [...pins(deps), d.environmentReader, ...d.linkedDependencies], tag);
  const onchain = await io.rpc(p, deps.targets[3], environmentAbi, "currentArtifactEnvironment", [], tag, undefined, deps.archiveGas);
  const external = await io.rpc(p, deps.targets[4], environmentAbi, "currentExternalArtifactEnvironment", [], tag, undefined, deps.archiveGas);
  const a = io.hash(onchain[0]), epoch = io.uint(onchain[1], 64), b = io.hash(external[0]), revision = io.uint(external[1], 64);
  if (epoch === 0n) throw Error("Missing original validation epoch");
  const expected = hashOf(["bytes32", bundle.CURRENT_VIEW_PRESERVATION_BUNDLE_V1_DEPENDENCIES_TUPLE, "bytes32", "uint64", "bytes32", "uint64"],
    [id("6529STREAM_BUNDLE_IMMUTABLE_STOP_ENVIRONMENT_V1"), deps, a, epoch, b, revision]);
  io.equal((await io.worker(p, d.environmentReader, workers.environment, [deps], tag, cap))[0], expected, "Original archive environment differs");
  return expected;
}
async function extendedEnvironment(p: io.Reader, d: CurrentViewPreservationBundleV1Deployment, deps: Dependencies, inventory: Inventory, base: Hex, tag: number, cap: bigint) {
  await io.runtimes(p, [d.archiveReader, d.retrievalReader], tag);
  const binding = await io.rpc(p, deps.targets[2], inv.currentViewPreservationInventoryV1Interface(), "retrievalWitnessBinding", [], tag, undefined, deps.readGas);
  const companion = { address: io.address(binding[0]), codeHash: io.hash(binding[1]) }; await io.runtime(p, companion, tag);
  const epoch = io.uint(await io.read(p, companion.address, retrieval.currentViewRetrievalV1Interface(), "revocationEpoch", [inventory.context.scope], tag, undefined, deps.readGas), 64);
  const expected = hashOf(["bytes32", "bytes32", "address", "bytes32", inv.CURRENT_VIEW_PRESERVATION_INVENTORY_V1_SCOPE_TUPLE, "uint64"],
    [id("6529STREAM_VIEW_RETRIEVAL_ARCHIVE_ENVIRONMENT_V1"), base, companion.address, companion.codeHash, inventory.context.scope, epoch]);
  io.equal((await io.worker(p, d.retrievalReader, workers.retrievalEnvironment, [deps, inventory.context.scope, base], tag, cap))[0], expected, "Companion environment differs");
  return { environment: expected, companion };
}
function suffix(segment: inv.CurrentViewPreservationInventoryV1Segment, items: readonly Item[], at: bigint) {
  let next = io.ZERO;
  for (let i = items.length - 1; i >= Number(at); i--) next = inv.currentViewPreservationInventoryV1Link(segment.key, segment.itemCount, BigInt(i), items[i]!, next);
  return next;
}
function validateProgress(progress: Progress, inventory: Inventory, existing: boolean) {
  if (!existing) { io.equal(progress, emptyProgress(), "Nondefault missing bundle progress"); return; }
  const total = inventory.evidence!.inventory;
  if (progress.itemCount > total.itemCount || progress.segmentIndex > total.segmentCount || progress.complete !== (progress.segmentIndex === total.segmentCount)) throw Error("Bundle progress exceeds inventory");
  let chain = io.ZERO, count = 0n;
  for (let i = 0n; i < progress.segmentIndex; i++) { const s = inventory.segments[Number(i)]!.segment; chain = inv.currentViewPreservationInventoryV1AppendSegment(chain, i, s); count += s.itemCount; }
  io.equal(chain, progress.segmentChainHash, "Consumed segment chain differs");
  if (progress.complete) { if (progress.segmentItemIndex !== 0n || progress.nextLink !== io.ZERO || count !== progress.itemCount) throw Error("Malformed completed progress"); }
  else {
    const current = inventory.segments[Number(progress.segmentIndex)]!;
    if (progress.segmentItemIndex > current.segment.itemCount || (current.segment.itemCount > 0n && progress.segmentItemIndex === current.segment.itemCount)
      || count + progress.segmentItemIndex !== progress.itemCount) throw Error("Bundle item cursor differs");
    io.equal(progress.nextLink, suffix(current.segment, current.items, progress.segmentItemIndex), "Retained item suffix differs");
  }
}
async function admissions(p: io.Reader, d: CurrentViewPreservationBundleV1HistoryDeployment, inventory: Inventory, progress: Progress, tag: number) {
  const items = inventory.segments.flatMap(s => s.items);
  if (items.length > MAX_ITEMS || progress.itemCount > BigInt(items.length)) throw Error("Admission client allocation limit exceeded");
  let chain = io.ZERO, retainedBytes = 0; const result: CurrentViewPreservationBundleV1AdmissionObservation[] = [];
  for (let index = 0n; index < progress.itemCount; index++) {
    const row = await io.rpc(p, d.bundle.address, host(), "admittedItem", [inventory.planId, index], tag);
    const item = inv.normalizeCurrentViewPreservationInventoryV1Item(row[0] as Item);
    const admission = bundle.normalizeCurrentViewPreservationBundleV1Admission(row[1] as Admission);
    retainedBytes += (io.coder.encode([inv.CURRENT_VIEW_PRESERVATION_INVENTORY_V1_ITEM_TUPLE, bundle.CURRENT_VIEW_PRESERVATION_BUNDLE_V1_ADMISSION_TUPLE, "bytes32"], [item, admission, io.ZERO]).length - 2) / 2;
    if (retainedBytes > bundle.CURRENT_VIEW_PRESERVATION_BUNDLE_V1_MAX_HISTORY_BYTES) throw Error("Admission history byte allocation bound exceeded");
    io.equal(item, items[Number(index)], "Stored Item differs from original emitted occurrence"); io.hash(admission.originalBundleHash);
    const witnessHash = io.hash(await read(p, d, "retrievalWitnessForItem", [inventory.planId, index], tag), true);
    bundle.validateCurrentViewPreservationBundleV1RetainedAdmission(inventory.context.artistId, item, admission, witnessHash);
    if (witnessHash !== io.ZERO && (admission.proof.backend !== 1n || ![retrieval.CURRENT_VIEW_RETRIEVAL_V1_ROLE, id("VIEW_ARCHIVE_LOCATOR_IMAGE")].includes(item.role))) throw Error("Stored retrieval dispatch differs");
    if (witnessHash === io.ZERO && item.role === retrieval.CURRENT_VIEW_RETRIEVAL_V1_ROLE) throw Error("Retrieval obligation lacks saved witness");
    chain = itemChain(chain, inventory.planId, index, item, admission); result.push({ item, admission, witnessHash });
  }
  io.equal(chain, progress.evidenceChainHash, "Retained covered Item chain differs"); return result;
}
function completion(d: CurrentViewPreservationBundleV1HistoryDeployment, dependencyHash: Hex, inventory: Inventory, progress: Progress): Evidence {
  const e: Evidence = { scope: inventory.context.scope, coverage: { inventoryPlan: inventory.planId, renderCriticalEvidenceHash: inventory.evidence!.inventory.renderCriticalEvidenceHash,
    itemCount: progress.itemCount, evidenceChainHash: progress.evidenceChainHash, bundleCoverageHash: io.ZERO } };
  return { ...e, coverage: { ...e.coverage, bundleCoverageHash: hashOf(["bytes32", "uint256", "address", "bytes32", "bytes32", inv.CURRENT_VIEW_PRESERVATION_INVENTORY_V1_EVIDENCE_TUPLE, bundle.CURRENT_VIEW_PRESERVATION_BUNDLE_V1_EVIDENCE_TUPLE],
    [id("6529STREAM_VIEW_PRESERVATION_BUNDLE_ARCHIVE_COVERAGE_V1"), d.chainId, d.bundle.address, dependencyHash, id("6529STREAM_VIEW_PRESERVATION_BUNDLE_IMMUTABLE_STOP_AGGREGATE_V1"), inventory.evidence, e]) } };
}
function validateRefresh(value: Refresh, environment: Hex, count: bigint) {
  if (value.environmentHash === io.ZERO) { io.equal(value, emptyRefresh(), "Nondefault absent refresh"); return; }
  if (value.environmentHash !== environment || value.nextIndex > count || value.complete !== (value.nextIndex === count)
    || (value.nextIndex === 0n ? value.currentObservationChain !== io.ZERO : value.currentObservationChain === io.ZERO)) throw Error("Malformed environment refresh");
}
async function currentItem(p: io.Reader, d: CurrentViewPreservationBundleV1Deployment, deps: Dependencies, inventory: Inventory,
  row: CurrentViewPreservationBundleV1AdmissionObservation, tag: number, cap: bigint) {
  if (row.witnessHash === io.ZERO) return io.hash((await io.worker(p, d.archiveReader, workers.current, [deps, inventory.evidence!.inventory.artistId, row.item, row.admission], tag, cap))[0], true);
  io.equal((await io.worker(p, d.retrievalReader, workers.retrievalContext, [deps, inventory.planId, inventory.evidence], tag, cap))[0], inventory.context, "Retrieval original context differs");
  return io.hash((await io.worker(p, d.retrievalReader, workers.retrievalCurrent, [deps, inventory.context, row.item, row.admission, row.witnessHash], tag, cap))[0], true);
}
async function predict(p: io.Reader, d: CurrentViewPreservationBundleV1Deployment, bound: Awaited<ReturnType<typeof bindings>>, inventory: Inventory,
  q: Request, tag: number, cap: bigint): Promise<CurrentViewPreservationBundleV1Stage> {
  const deps = bound.dependencies;
  const before = bundle.normalizeCurrentViewPreservationBundleV1Progress(await read(p, d, "progress", [q.id], tag));
  const existing = io.stable(before) !== io.stable(emptyProgress()); validateProgress(before, inventory, existing);
  const retained = await admissions(p, d, inventory, before, tag), after = { ...before };
  const base = await baseEnvironment(p, d, deps, tag, cap);
  let evidence = before.complete ? completion(d, bound.dependencyHash, inventory, before) : null;
  if (evidence) io.equal(await read(p, d, "bundleEvidence", [q.id], tag), evidence, "Stored bundle evidence differs");
  // The original existing-plan retry returns before every companion/epoch/context/refresh read.
  if (q.method === "beginCoverage" && existing) return io.freeze({ ...bound, inventory, baseEnvironment: base, environment: null, companion: null,
    before, after, admissions: retained, admitted: null, observation: null, refreshId: null, refreshBefore: null, refreshAfter: null, evidence, existing, initialObservationChainAuthenticated: false });
  const { environment, companion } = await extendedEnvironment(p, d, deps, inventory, base, tag, cap);
  const key = refreshKey(d, bound.dependencyHash, q.id, environment), count = inventory.evidence!.inventory.itemCount;
  const refreshBefore = bundle.normalizeCurrentViewPreservationBundleV1Refresh(await read(p, d, "refresh", [key], tag)); validateRefresh(refreshBefore, environment, count);
  let refreshAfter: Refresh | null = refreshBefore, admitted: CurrentViewPreservationBundleV1AdmissionObservation | null = null, observation: Hex | null = null;
  if (q.method === "beginCoverage") { after.environmentHash = environment; after.nextLink = inventory.segments[0]!.segment.firstLink; }
  else if (q.method === "beginRefresh") {
    if (!before.complete) throw Error("Coverage incomplete");
    if (refreshBefore.environmentHash === io.ZERO) refreshAfter = { ...refreshBefore, environmentHash: environment };
  } else if (q.method === "refreshNext") {
    if (!before.complete || refreshBefore.environmentHash !== environment || refreshBefore.complete || refreshBefore.nextIndex !== q.expectedIndex || q.expectedIndex >= BigInt(retained.length)) throw Error("Wrong original refresh cursor");
    const row = retained[Number(q.expectedIndex)]!; observation = await currentItem(p, d, deps, inventory, row, tag, cap);
    refreshAfter = { environmentHash: environment, nextIndex: q.expectedIndex + 1n, currentObservationChain: observationChain(refreshBefore.currentObservationChain, q.expectedIndex, row.item, observation), complete: q.expectedIndex + 1n === count };
  } else {
    if (!existing || before.complete) throw Error("Missing or completed coverage");
    const current = inventory.segments[Number(before.segmentIndex)]!, segment = current.segment;
    if (q.method === "coverEmptySegment") {
      if (segment.itemCount !== 0n || segment.firstLink !== io.ZERO || before.segmentItemIndex !== 0n || before.nextLink !== io.ZERO) throw Error("Not an explicit empty segment");
    } else {
      if (q.method !== "coverNext" && q.method !== "coverRetrievalNext") throw Error("Unsupported cover method");
      const item = current.items[Number(before.segmentItemIndex)]; if (!item) throw Error("Missing next inventory occurrence");
      io.equal(item, q.item, "CALL Item differs from authenticated inventory"); io.equal(q.nextLink, suffix(segment, current.items, before.segmentItemIndex + 1n), "CALL suffix differs");
      let raw: readonly unknown[]; let witnessHash = io.ZERO;
      if (q.method === "coverNext") {
        if (item.role === retrieval.CURRENT_VIEW_RETRIEVAL_V1_ROLE) throw Error("Retrieval obligation requires dedicated witness call");
        raw = await io.worker(p, d.archiveReader, workers.admit, [deps, inventory.context.artistId, item, q.proof], tag, cap);
      } else {
        witnessHash = io.hash(q.witnessHash);
        if (![retrieval.CURRENT_VIEW_RETRIEVAL_V1_ROLE, id("VIEW_ARCHIVE_LOCATOR_IMAGE")].includes(item.role)) throw Error("Wrong retrieval obligation role");
        io.equal((await io.worker(p, d.retrievalReader, workers.retrievalContext, [deps, q.id, inventory.evidence], tag, cap))[0], inventory.context, "Retrieval context differs");
        raw = await io.worker(p, d.retrievalReader, workers.retrievalAdmit, [deps, inventory.context, item, witnessHash], tag, cap);
      }
      const admission = bundle.normalizeCurrentViewPreservationBundleV1Admission(raw[0] as Admission); io.hash(admission.originalBundleHash);
      if (q.method === "coverNext") io.equal(admission.proof, q.proof, "Returned original proof differs");
      else if (admission.proof.backend !== 1n) throw Error("Retrieval admission must preserve external backend");
      observation = io.hash(raw[1], true); admitted = { item, admission, witnessHash };
      after.evidenceChainHash = itemChain(before.evidenceChainHash, q.id, before.itemCount, item, admission);
      after.itemCount++; after.segmentItemIndex++; after.nextLink = q.nextLink;
    }
    if (environment !== before.environmentHash) after.environmentHash = io.ZERO;
    if (after.segmentItemIndex === segment.itemCount) {
      if (after.nextLink !== io.ZERO) throw Error("Segment termination differs");
      after.segmentChainHash = inv.currentViewPreservationInventoryV1AppendSegment(before.segmentChainHash, before.segmentIndex, segment);
      after.segmentIndex++; after.segmentItemIndex = 0n;
      if (after.segmentIndex === BigInt(inventory.segments.length)) {
        if (after.itemCount !== count || after.segmentChainHash !== inventory.evidence!.inventory.segmentChainHash) throw Error("Incomplete original Item chain");
        after.complete = true; evidence = completion(d, bound.dependencyHash, inventory, after);
        if (after.environmentHash !== io.ZERO) refreshAfter = null;
      } else after.nextLink = inventory.segments[Number(after.segmentIndex)]!.segment.firstLink;
    }
  }
  // The outer fixed-block observations do not prove identical nested gas behavior.
  if (q.method !== "coverEmptySegment" && q.method !== "beginCoverage" && q.method !== "beginRefresh") {
    const afterBase = await baseEnvironment(p, d, deps, tag, cap); io.equal(afterBase, base, "Original environment drifted");
    io.equal((await extendedEnvironment(p, d, deps, inventory, afterBase, tag, cap)).environment, environment, "Companion environment drifted");
  }
  return io.freeze({ ...bound, inventory, baseEnvironment: base, environment, companion, before, after, admissions: retained, admitted, observation,
    refreshId: key, refreshBefore, refreshAfter, evidence, existing, initialObservationChainAuthenticated: false });
}
async function original(p: io.Reader, prepared: bundle.CurrentViewPreservationBundleV1Call, tag: number, cap: bigint, expected?: Hex) {
  const raw = io.bytes(await p.call({ ...prepared.call, from: prepared.caller, blockTag: tag, gasLimit: cap }));
  const iface = host(), decoded = iface.decodeFunctionResult(prepared.request.method, raw);
  io.equal(iface.encodeFunctionResult(prepared.request.method, decoded), raw, "Noncanonical original result");
  if (expected !== undefined) io.equal(decoded[0], expected, "Original refresh ID differs"); return raw;
}
export async function captureCurrentViewPreservationBundleV1(p: io.ReceiptReader, input: CurrentViewPreservationBundleV1Deployment, caller: Address, request: Request,
  options: { readonly blockTag: number; readonly gasLimit: bigint; readonly segments: readonly CurrentViewPreservationBundleV1SegmentLocator[] }): Promise<CurrentViewPreservationBundleV1WorkflowCapture> {
  const d = deployment(input), prepared = bundle.prepareCurrentViewPreservationBundleV1Call(coordinates(d), io.address(caller), request);
  io.keys(options, ["blockTag", "gasLimit", "segments"]); const tag = io.number(options.blockTag), cap = io.gas(options.gasLimit), retained = locators(options.segments);
  const observed = await io.chain(p, d.chainId, tag), bound = await bindings(p, d, tag), inventory = await inventoryHistory(p, d, bound.dependencies, prepared.request.id, retained, tag);
  const stage = await predict(p, d, bound, inventory, prepared.request, tag, cap);
  const originalCallResult = await original(p, prepared, tag, cap, prepared.request.method === "beginRefresh" ? stage.refreshId! : undefined);
  await io.unchanged(p, observed); const value = { deployment: d, prepared, observed, gasLimit: cap, stage, originalCallResult, originalCallSimulated: true as const };
  return io.freeze({ ...value, captureHash: io.fingerprint(value) });
}
function savedCapture(input: CurrentViewPreservationBundleV1WorkflowCapture) {
  io.keys(input, ["deployment", "prepared", "observed", "gasLimit", "stage", "originalCallResult", "originalCallSimulated", "captureHash"]);
  const value = structuredClone(input), { captureHash, ...body } = value; io.equal(captureHash, io.fingerprint(body), "Capture fingerprint differs");
  const d = deployment(value.deployment), prepared = bundle.normalizeCurrentViewPreservationBundleV1Call(value.prepared); io.equal(prepared.coordinates, coordinates(d), "Saved deployment/call differs");
  io.gas(value.gasLimit); io.number(value.observed.blockNumber); io.hash(value.observed.blockHash); io.uint(value.observed.timestamp);
  if (value.originalCallSimulated !== true) throw Error("Wrong capture qualification"); return io.freeze({ ...value, deployment: d, prepared });
}
function comparable(v: CurrentViewPreservationBundleV1WorkflowCapture) {
  const { observed, ...inventory } = v.stage.inventory;
  return { deployment: v.deployment, prepared: v.prepared, gasLimit: v.gasLimit, stage: { ...v.stage, inventory }, originalCallResult: v.originalCallResult };
}
async function revalidate(p: io.ReceiptReader, saved: CurrentViewPreservationBundleV1WorkflowCapture, tag: number) {
  await io.unchanged(p, saved.observed); if (tag < saved.observed.blockNumber) throw Error("Observation predates capture");
  const value = await captureCurrentViewPreservationBundleV1(p, saved.deployment, saved.prepared.caller, saved.prepared.request,
    { blockTag: tag, gasLimit: saved.gasLimit, segments: saved.stage.inventory.segments.map(s => s.locator) });
  io.equal(comparable(value), comparable(saved), "Bundle facts changed; recapture"); return value;
}
export async function simulateCurrentViewPreservationBundleV1(p: io.ReceiptReader, input: CurrentViewPreservationBundleV1WorkflowCapture, options: { readonly blockTag: number }) {
  const saved = savedCapture(input); io.keys(options, ["blockTag"]); const tag = io.number(options.blockTag);
  await revalidate(p, saved, saved.observed.blockNumber); const capture = await revalidate(p, saved, tag);
  return io.freeze({ capture, result: capture.originalCallResult, originalCallSucceeded: true as const, stateChangesPersisted: false as const });
}
export async function inspectCurrentViewPreservationBundleV1History(p: io.ReceiptReader, input: CurrentViewPreservationBundleV1HistoryDeployment, inputId: Hex,
  options: { readonly blockTag: number; readonly segments: readonly CurrentViewPreservationBundleV1SegmentLocator[] }) {
  const d = historyDeployment(input), planId = io.hash(inputId); io.keys(options, ["blockTag", "segments"]); const tag = io.number(options.blockTag), retained = locators(options.segments);
  const observed = await io.chain(p, d.chainId, tag), bound = await bindings(p, d, tag), inventory = await inventoryHistory(p, d, bound.dependencies, planId, retained, tag);
  const progress = bundle.normalizeCurrentViewPreservationBundleV1Progress(await read(p, d, "progress", [planId], tag));
  const existing = io.stable(progress) !== io.stable(emptyProgress()); validateProgress(progress, inventory, existing);
  const admitted = await admissions(p, d, inventory, progress, tag);
  const evidence = progress.complete ? completion(d, bound.dependencyHash, inventory, progress) : null;
  if (evidence) io.equal(await read(p, d, "bundleEvidence", [planId], tag), evidence, "Retained bundle commitment differs");
  await io.unchanged(p, observed);
  return io.freeze({ observed, planId, ...bound, inventory, progress, admissions: admitted, evidence,
    currentEnvironmentChecked: false as const, inventoryCurrentSourceChecked: false as const, retrievalWitnessRecordIndependentlyAuthenticated: false as const,
    initialObservationChainAuthenticated: false as const });
}
export async function inspectCurrentViewPreservationBundleV1Current(p: io.ReceiptReader, input: CurrentViewPreservationBundleV1Deployment, inputId: Hex,
  options: { readonly blockTag: number; readonly gasLimit: bigint; readonly segments: readonly CurrentViewPreservationBundleV1SegmentLocator[]; readonly fullCurrentCoverage?: boolean }) {
  const d = deployment(input), planId = io.hash(inputId); io.keys(options, ["blockTag", "gasLimit", "segments"], ["fullCurrentCoverage"]);
  const tag = io.number(options.blockTag), cap = io.gas(options.gasLimit), retained = locators(options.segments);
  if (options.fullCurrentCoverage !== undefined && typeof options.fullCurrentCoverage !== "boolean") throw Error("Expected diagnostic flag"); const full = options.fullCurrentCoverage === true;
  const history = await inspectCurrentViewPreservationBundleV1History(p, hd(d), planId, { blockTag: tag, segments: retained });
  if (!history.evidence) throw Error("Incomplete archive coverage");
  const base = await baseEnvironment(p, d, history.dependencies, tag, cap), ext = await extendedEnvironment(p, d, history.dependencies, history.inventory, base, tag, cap);
  const key = refreshKey(d, history.dependencyHash, planId, ext.environment);
  let refresh: Refresh | null = null;
  if (full) {
    for (const row of history.admissions) await currentItem(p, d, history.dependencies, history.inventory, row, tag, cap);
    io.equal(await read(p, d, "requireFullCurrentCoverage", [planId], tag, cap), history.evidence, "Full current coverage differs");
  } else {
    refresh = bundle.normalizeCurrentViewPreservationBundleV1Refresh(await read(p, d, "refresh", [key], tag));
    validateRefresh(refresh, ext.environment, history.progress.itemCount); if (!refresh.complete) throw Error("Current environment refresh incomplete");
    io.equal(await read(p, d, "requireCoverage", [history.inventory.context.scope, planId, history.inventory.evidence!.inventory.renderCriticalEvidenceHash], tag, cap), history.evidence, "Cached current coverage differs");
  }
  await io.unchanged(p, history.observed);
  return io.freeze({ history, environment: ext.environment, refreshId: key, refresh, currentEnvironmentChecked: true as const,
    cachedCoverageChecked: !full, fullCurrentCoverageChecked: full, inventoryCurrentSourceChecked: false as const, initialObservationChainAuthenticated: false as const });
}
export async function reconcileCurrentViewPreservationBundleV1Receipt(p: io.ReceiptReader, input: CurrentViewPreservationBundleV1WorkflowCapture, inputHash: Hex, options: CurrentViewPreservationBundleV1ReceiptOptions) {
  const saved = savedCapture(input), tx = await io.transport(p, { chainId: saved.deployment.chainId, caller: saved.prepared.caller, call: saved.prepared.call, observed: saved.observed }, io.hash(inputHash), options);
  await revalidate(p, saved, saved.observed.blockNumber); const prior = await revalidate(p, saved, tx.observed.blockNumber - 1);
  const d = prior.deployment, s = prior.stage, tag = tx.observed.blockNumber, q = prior.prepared.request;
  await io.runtimes(p, [d.bundle, d.environmentReader, ...d.linkedDependencies, ...pins(s.dependencies), ...(s.companion ? [s.companion, d.archiveReader, d.retrievalReader] : [])], tag);
  io.equal(await read(p, d, "progress", [q.id], tag), s.after, "End-block progress differs; concurrent progress is not attributed");
  const starts = io.events(tx.logs, d.bundle.address, host(), eventName("CoverageStarted")), items = io.events(tx.logs, d.bundle.address, host(), eventName("ItemAdmitted"));
  const completes = io.events(tx.logs, d.bundle.address, host(), eventName("CoverageCompleted")), advances = io.events(tx.logs, d.bundle.address, host(), eventName("RefreshAdvanced"));
  if (q.method === "beginCoverage") {
    if (starts.length !== (s.existing ? 0 : 1) || items.length || completes.length || advances.length) throw Error("Wrong bundle begin events");
    if (!s.existing) io.one(tx.logs, d.bundle.address, host(), eventName("CoverageStarted"), [1n, q.id, s.inventory.evidence!.inventory.renderCriticalEvidenceHash]);
  } else if (q.method === "beginRefresh") {
    if (starts.length || items.length || completes.length || advances.length) throw Error("Refresh begin must be eventless");
  } else if (q.method === "refreshNext") {
    if (starts.length || items.length || completes.length) throw Error("Wrong refresh events");
    io.one(tx.logs, d.bundle.address, host(), eventName("RefreshAdvanced"), [1n, q.id, s.refreshId, s.refreshAfter!.nextIndex, s.refreshAfter!.currentObservationChain, s.refreshAfter!.complete]);
  } else {
    if (starts.length || advances.length || items.length !== (s.admitted ? 1 : 0) || completes.length !== (s.after.complete ? 1 : 0)) throw Error("Wrong admission events");
    let index = -1;
    if (s.admitted) {
      index = io.one(tx.logs, d.bundle.address, host(), eventName("ItemAdmitted"), [1n, q.id, s.before.itemCount, inv.currentViewPreservationInventoryV1ItemHash(s.admitted.item), s.admitted.admission]).index;
      io.equal(await io.rpc(p, d.bundle.address, host(), "admittedItem", [q.id, s.before.itemCount], tag), [s.admitted.item, s.admitted.admission], "Mined retained admission differs");
      io.equal(await read(p, d, "retrievalWitnessForItem", [q.id, s.before.itemCount], tag), s.admitted.witnessHash, "Mined retrieval witness coordinate differs");
    }
    if (s.after.complete) {
      const complete = io.one(tx.logs, d.bundle.address, host(), eventName("CoverageCompleted"), [1n, q.id, s.evidence!.coverage.bundleCoverageHash, s.evidence]);
      if (complete.index <= index) throw Error("Completion precedes admission");
    }
  }
  if (s.evidence) io.equal(await read(p, d, "bundleEvidence", [q.id], tag), s.evidence, "Mined bundle evidence differs");
  let refresh: Refresh | null = null;
  if (s.refreshId) {
    refresh = bundle.normalizeCurrentViewPreservationBundleV1Refresh(await read(p, d, "refresh", [s.refreshId], tag));
    if (s.refreshAfter) io.equal(refresh, s.refreshAfter, "Mined refresh differs");
    else { validateRefresh(refresh, s.environment!, s.after.itemCount); if (!refresh.complete) throw Error("Automatic refresh incomplete"); }
  }
  io.finish(tx.logs, [d.bundle.address], tx.safeIndex); await io.unchanged(p, tx.observed);
  return io.freeze({ observed: tx.observed, prior: prior.observed, transactionHash: tx.transactionHash, planId: q.id, progress: s.after, admitted: s.admitted,
    evidence: s.evidence, refreshId: s.refreshId, refresh, initialObservationChainAuthenticated: false as const, refreshStepChainAuthenticated: q.method === "refreshNext",
    precedingAndEndBlockAttribution: true as const, currentAfterReceipt: false as const, intraBlockTraceProven: false as const });
}
export async function observeCurrentViewPreservationBundleV1Refusal(p: io.ReceiptReader, input: CurrentViewPreservationBundleV1WorkflowCapture, options: { readonly blockTag: number }) {
  const saved = savedCapture(input); io.keys(options, ["blockTag"]); const tag = io.number(options.blockTag);
  await revalidate(p, saved, saved.observed.blockNumber); if (tag < saved.observed.blockNumber) throw Error("Refusal predates capture");
  const observed = await io.chain(p, saved.deployment.chainId, tag); await io.runtime(p, saved.deployment.bundle, tag);
  const state = async () => ({ progress: await read(p, saved.deployment, "progress", [saved.prepared.request.id], tag),
    refresh: saved.stage.refreshId ? await read(p, saved.deployment, "refresh", [saved.stage.refreshId], tag) : null });
  const before = await state(); let result: Hex | null = null, failure: { code: string; revertData: Hex | null } | null = null;
  try { result = await original(p, saved.prepared, tag, saved.gasLimit); } catch (error) {
    const v = error as { code?: unknown; data?: unknown }, code = typeof v?.code === "string" && ["CALL_EXCEPTION", "NETWORK_ERROR", "SERVER_ERROR", "TIMEOUT"].includes(v.code) ? v.code : "UNKNOWN_ERROR";
    let data: Hex | null = null; try { if (v?.data !== undefined) data = io.bytes(v.data, 4096); } catch { /* opaque transport error */ }
    failure = { code, revertData: data };
  }
  io.equal(await state(), before, "Local state changed during observation"); await io.unchanged(p, observed);
  return io.freeze({ observed, result, failure, outcome: failure ? failure.code === "CALL_EXCEPTION" ? "execution-reverted" as const : "rpc-failed" as const : "call-succeeded" as const,
    currentEnvironmentRevalidated: false as const, stateChangesPersisted: false as const, submittedTransactionRollbackProven: false as const });
}
