import { AbiCoder, Interface, ParamType, keccak256 } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import * as archive from "./current-authority-preservation-archive-v1.js";
import * as inv from "./current-authority-preservation-inventory-v1.js";
import { inspectCurrentAuthorityPreservationInventoryV1History, type CurrentAuthorityPreservationInventoryV1SegmentLocator } from "./current-authority-preservation-inventory-v1-workflow.js";
import * as io from "./current-scoped-policy-inventory-archive-workflow-internal.js";

// Original public memory-only view workers. Compiler nominal selectors stay separate from
// structurally encoded values. Direct worker reads are supplied-source reconstruction; the
// original host call remains the admission and nested-gas authority. Reviewed linked runtime
// completeness is a deployment metadata input. These are never wallet call endpoints.
const workers = {
  "capture": {
    "contract": "StreamCurrentAuthorityBundleArchiveEnvironment",
    "method": "capture",
    "selector": "0xb0daaf3e",
    "inputs": [
      "(address[6] targets, bytes32[6] codeHashes, uint256 chainId, uint256 readGas, uint256 archiveGas)",
      "(address worker, bytes32 workerCodeHash, uint256 originGas, bytes32 profile)",
      "(address resolver, bytes32 resolverCodeHash, uint256 resolverGas)",
      "bytes32",
      "bytes32"
    ],
    "outputs": [
      "((address[12] targets, bytes32[12] codeHashes, address[5] artistTargets, bytes32[5] artistCodeHashes, address artistContentOwner, bytes32 artistContentOwnerCodeHash, uint256 chainId, uint256 readGas, uint256 sourceGas, uint256 selectionGas, uint256 snapshotGas, uint256 referenceGas) dependencies, (((uint256 chainId, address registry, address coordinator, address archive, address[7] owners, bytes32[7] ownerCodeHashes, address core, address manager, bytes32 suiteConfigurationHash) environment, bytes32 registryCodeHash, bytes32 coordinatorCodeHash, bytes32 archiveCodeHash) origin, bytes32 completion, bytes32 selectionHash) selection)"
    ]
  },
  "environment": {
    "contract": "StreamCurrentAuthorityBundleArchiveEnvironment",
    "method": "environment",
    "selector": "0xb12de225",
    "inputs": [
      "(address[6] targets, bytes32[6] codeHashes, uint256 chainId, uint256 readGas, uint256 archiveGas)",
      "(address worker, bytes32 workerCodeHash, uint256 originGas, bytes32 profile)",
      "(address resolver, bytes32 resolverCodeHash, uint256 resolverGas)",
      "bytes32",
      "bytes32"
    ],
    "outputs": [
      "bytes32"
    ]
  },
  "multiConfiguration": {
    "contract": "StreamMultiOriginBundleArchiveReads",
    "method": "configuration",
    "selector": "0x0adfc3bd",
    "inputs": [
      "(address[6] targets, bytes32[6] codeHashes, uint256 chainId, uint256 readGas, uint256 archiveGas)",
      "(address worker, bytes32 workerCodeHash, uint256 originGas, bytes32 profile)",
      "bytes32"
    ],
    "outputs": []
  },
  "multiEnvironment": {
    "contract": "StreamMultiOriginBundleArchiveReads",
    "method": "environment",
    "selector": "0x312a3613",
    "inputs": [
      "(address[6] targets, bytes32[6] codeHashes, uint256 chainId, uint256 readGas, uint256 archiveGas)",
      "(address worker, bytes32 workerCodeHash, uint256 originGas, bytes32 profile)",
      "bytes32",
      "bytes32"
    ],
    "outputs": [
      "bytes32"
    ]
  },
  "multiOriginSet": {
    "contract": "StreamMultiOriginBundleArchiveReads",
    "method": "originSet",
    "selector": "0x39dd8a0f",
    "inputs": [
      "(address[6] targets, bytes32[6] codeHashes, uint256 chainId, uint256 readGas, uint256 archiveGas)",
      "bytes32"
    ],
    "outputs": [
      "bytes32",
      "uint256"
    ]
  },
  "multiOriginAt": {
    "contract": "StreamMultiOriginBundleArchiveReads",
    "method": "originAt",
    "selector": "0xe3596859",
    "inputs": [
      "(address[6] targets, bytes32[6] codeHashes, uint256 chainId, uint256 readGas, uint256 archiveGas)",
      "bytes32",
      "uint256"
    ],
    "outputs": [
      "((uint256 chainId, address registry, address coordinator, address archive, address[7] owners, bytes32[7] ownerCodeHashes, address core, address manager, bytes32 suiteConfigurationHash) environment, bytes32 registryCodeHash, bytes32 coordinatorCodeHash, bytes32 archiveCodeHash)"
    ]
  },
  "multiRoute": {
    "contract": "StreamMultiOriginBundleArchiveReads",
    "method": "route",
    "selector": "0x6c514657",
    "inputs": [
      "(address[6] targets, bytes32[6] codeHashes, uint256 chainId, uint256 readGas, uint256 archiveGas)",
      "bytes32",
      "(bytes32 planId, uint256 collectionId, bytes32 scopeSubject, bytes32 artistId, (bytes32 rootRecordHash, bytes32 snapshotRecordHash, bytes32 referenceRenderRecordHash, bytes32 intentRecordHash, bytes32 intentWaiverRecordHash, bytes32 interviewEvidenceHash, bytes32 rightsStatementRecordHash, bytes32 workDescriptionRecordHash) originals, bytes32 sourceContextHash, bytes32 tokenInventoryHash, uint64 tokenCount, uint64 segmentCount, uint64 itemCount, bytes32 segmentChainHash, bytes32 renderCriticalEvidenceHash)",
      "(uint8 kind, bytes32 role, address source, bytes32 sourceRecord, uint256 sourceIndex, uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri, uint64 byteSize, bytes32 schemaId, bytes32 formatId, bytes32 catalogId, bytes32 catalogHash, bytes32 objectHash, bytes32 originalCoverageHash, bytes32 provenanceHash)"
    ],
    "outputs": [
      "(address[6] targets, bytes32[6] codeHashes, uint256 chainId, uint256 readGas, uint256 archiveGas)",
      "bytes32"
    ]
  },
  "multiAdmit": {
    "contract": "StreamMultiOriginBundleArchiveReads",
    "method": "admit",
    "selector": "0xd5ade3c9",
    "inputs": [
      "(address[6] targets, bytes32[6] codeHashes, uint256 chainId, uint256 readGas, uint256 archiveGas)",
      "bytes32",
      "(bytes32 planId, uint256 collectionId, bytes32 scopeSubject, bytes32 artistId, (bytes32 rootRecordHash, bytes32 snapshotRecordHash, bytes32 referenceRenderRecordHash, bytes32 intentRecordHash, bytes32 intentWaiverRecordHash, bytes32 interviewEvidenceHash, bytes32 rightsStatementRecordHash, bytes32 workDescriptionRecordHash) originals, bytes32 sourceContextHash, bytes32 tokenInventoryHash, uint64 tokenCount, uint64 segmentCount, uint64 itemCount, bytes32 segmentChainHash, bytes32 renderCriticalEvidenceHash)",
      "(uint8 kind, bytes32 role, address source, bytes32 sourceRecord, uint256 sourceIndex, uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri, uint64 byteSize, bytes32 schemaId, bytes32 formatId, bytes32 catalogId, bytes32 catalogHash, bytes32 objectHash, bytes32 originalCoverageHash, bytes32 provenanceHash)",
      "(uint8 backend, bytes32 coverageHash, bytes32 objectHash)"
    ],
    "outputs": [
      "((uint8 backend, bytes32 coverageHash, bytes32 objectHash) proof, bytes32 originalBundleHash, bytes32 immutablePartsHash, (bytes32 coverageHash, bytes32 objectHash, bytes32 artistId, bytes32 contentHash, bytes32 sha256Digest, bytes32 arweaveDataRoot, uint64 byteSize, bytes32 firstFamilyRecordHash, bytes32 secondFamilyRecordHash, bytes32 firstReceiptHash, bytes32 secondReceiptHash, bytes32 firstFixityHash, bytes32 secondFixityHash, bytes32 checkpointHash, bytes32 profileHash) externalOriginal, (bytes32 completionHash, bytes32 artifactHash, bytes32 artistId, bytes32 schemaId, bytes32 canonicalizationId, bytes32 contentHash, uint64 byteLength, uint32 chunkCount, bytes32 firstFamilyRecordHash, bytes32 secondFamilyRecordHash, uint64 validationEpoch, bytes32 evidenceChainHash) onchainOriginal)",
      "bytes32",
      "bytes32"
    ]
  },
  "multiCurrent": {
    "contract": "StreamMultiOriginBundleArchiveReads",
    "method": "current",
    "selector": "0xad5cfd66",
    "inputs": [
      "(address[6] targets, bytes32[6] codeHashes, uint256 chainId, uint256 readGas, uint256 archiveGas)",
      "bytes32",
      "(bytes32 planId, uint256 collectionId, bytes32 scopeSubject, bytes32 artistId, (bytes32 rootRecordHash, bytes32 snapshotRecordHash, bytes32 referenceRenderRecordHash, bytes32 intentRecordHash, bytes32 intentWaiverRecordHash, bytes32 interviewEvidenceHash, bytes32 rightsStatementRecordHash, bytes32 workDescriptionRecordHash) originals, bytes32 sourceContextHash, bytes32 tokenInventoryHash, uint64 tokenCount, uint64 segmentCount, uint64 itemCount, bytes32 segmentChainHash, bytes32 renderCriticalEvidenceHash)",
      "(uint8 kind, bytes32 role, address source, bytes32 sourceRecord, uint256 sourceIndex, uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri, uint64 byteSize, bytes32 schemaId, bytes32 formatId, bytes32 catalogId, bytes32 catalogHash, bytes32 objectHash, bytes32 originalCoverageHash, bytes32 provenanceHash)",
      "((uint8 backend, bytes32 coverageHash, bytes32 objectHash) proof, bytes32 originalBundleHash, bytes32 immutablePartsHash, (bytes32 coverageHash, bytes32 objectHash, bytes32 artistId, bytes32 contentHash, bytes32 sha256Digest, bytes32 arweaveDataRoot, uint64 byteSize, bytes32 firstFamilyRecordHash, bytes32 secondFamilyRecordHash, bytes32 firstReceiptHash, bytes32 secondReceiptHash, bytes32 firstFixityHash, bytes32 secondFixityHash, bytes32 checkpointHash, bytes32 profileHash) externalOriginal, (bytes32 completionHash, bytes32 artifactHash, bytes32 artistId, bytes32 schemaId, bytes32 canonicalizationId, bytes32 contentHash, uint64 byteLength, uint32 chunkCount, bytes32 firstFamilyRecordHash, bytes32 secondFamilyRecordHash, uint64 validationEpoch, bytes32 evidenceChainHash) onchainOriginal)",
      "bytes32"
    ],
    "outputs": [
      "bytes32"
    ]
  }
} as const;

// Solidity interface IDs exclude inherited functions; these exact own functions are source-witnessed.
const capabilities = {
  "IStreamCurrentAuthorityPreservationPolicyRenderCriticalInventoryV1": "0x1fee95a8",
  "IStreamCurrentAuthorityScopedPreservationPolicyRenderCriticalInventoryV1": "0x6b2054bd",
  "IStreamArtistArchiveOriginInventory": "0x57219121",
  "IStreamCurrentAuthorityInventory": "0xc0d7d0d7"
} as const;

const resolverAbi = new Interface([
  "function anchors() view returns ((address[5] targets, bytes32[5] codeHashes, address finalityRegistry, uint256 chainId, uint256 readGas))",
  "function currentSelection() view returns ((((uint256 chainId, address registry, address coordinator, address archive, address[7] owners, bytes32[7] ownerCodeHashes, address core, address manager, bytes32 suiteConfigurationHash) environment, bytes32 registryCodeHash, bytes32 coordinatorCodeHash, bytes32 archiveCodeHash) origin, bytes32 completion, bytes32 selectionHash))",
  "function currentAuthorityProfile() view returns (bytes32)"
]);
const environmentAbi = new Interface([
  "function currentArtifactEnvironment() view returns (bytes32 environmentHash, uint64 validationEpoch)",
  "function currentExternalArtifactEnvironment() view returns (bytes32 environmentHash, uint64 healthRevision)"
]);

export type CurrentAuthorityPreservationArchiveV1CodePin = io.CodePin;
export type CurrentAuthorityPreservationArchiveV1Block = io.Block;
export type CurrentAuthorityPreservationArchiveV1ReceiptOptions = io.ReceiptOptions;
export interface CurrentAuthorityPreservationArchiveV1Deployment {
  readonly chainId: bigint;
  readonly core: Address;
  readonly scopeKind: "collection" | "scoped";
  readonly archive: io.CodePin;
  readonly authorityReader: io.CodePin;
  readonly archiveReader: io.CodePin;
  readonly linkedDependencies: readonly io.CodePin[];
}
export interface CurrentAuthorityPreservationArchiveV1HistoryDeployment {
  readonly chainId: bigint;
  readonly core: Address;
  readonly scopeKind: "collection" | "scoped";
  readonly archive: io.CodePin;
}
export type CurrentAuthorityPreservationArchiveV1SegmentLocator = CurrentAuthorityPreservationInventoryV1SegmentLocator;
type InventoryHistory = Awaited<ReturnType<typeof inspectCurrentAuthorityPreservationInventoryV1History>>;
type Evidence = archive.CurrentAuthorityPreservationArchiveV1Evidence;
type Dependencies = archive.CurrentAuthorityPreservationArchiveV1Dependencies;
type Kind = "collection" | "scoped";
type Item = inv.CurrentAuthorityPreservationInventoryV1Item;
type Origin = inv.CurrentAuthorityPreservationInventoryV1Origin;
type RecordOrigin = inv.CurrentAuthorityPreservationInventoryV1RecordOrigin;
type Mutable<T> = T extends readonly (infer V)[] ? Mutable<V>[] : T extends object ? { -readonly [K in keyof T]: Mutable<T[K]> } : T;
export interface CurrentAuthorityPreservationArchiveV1AdmissionObservation {
  readonly item: Item;
  readonly admission: archive.CurrentAuthorityPreservationArchiveV1Admission;
  readonly originHash: Hex;
  readonly original: RecordOrigin | null;
}
export interface CurrentAuthorityPreservationArchiveV1Environment {
  readonly hash: Hex;
  readonly onchainHash: Hex;
  readonly epoch: bigint;
  readonly externalHash: Hex;
  readonly revision: bigint;
  readonly baseHash: Hex;
  readonly multiOriginHash: Hex;
  readonly originRoot: Hex;
  readonly originCount: bigint;
  readonly authorityAnchors: inv.CurrentAuthorityPreservationInventoryV1AuthorityAnchors;
  readonly capture: inv.CurrentAuthorityPreservationInventoryV1Capture;
}
export interface CurrentAuthorityPreservationArchiveV1Stage {
  readonly dependencies: Dependencies;
  readonly originDependencies: inv.CurrentAuthorityPreservationInventoryV1OriginDependencies;
  readonly authorityDependencies: inv.CurrentAuthorityPreservationInventoryV1AuthorityDependencies;
  readonly dependencyHash: Hex;
  readonly inventory: InventoryHistory;
  readonly environment: CurrentAuthorityPreservationArchiveV1Environment;
  readonly before: archive.CurrentAuthorityPreservationArchiveV1Progress;
  readonly after: archive.CurrentAuthorityPreservationArchiveV1Progress;
  readonly admissions: readonly CurrentAuthorityPreservationArchiveV1AdmissionObservation[];
  readonly admitted: CurrentAuthorityPreservationArchiveV1AdmissionObservation | null;
  readonly currentObservation: Hex | null;
  readonly refreshId: Hex;
  readonly refreshBefore: archive.CurrentAuthorityPreservationArchiveV1Refresh;
  readonly refreshAfter: archive.CurrentAuthorityPreservationArchiveV1Refresh | null;
  readonly evidence: Evidence | null;
  readonly existing: boolean;
  readonly initialObservationChainAuthenticated: false;
}
export interface CurrentAuthorityPreservationArchiveV1WorkflowCapture {
  readonly deployment: CurrentAuthorityPreservationArchiveV1Deployment;
  readonly prepared: archive.CurrentAuthorityPreservationArchiveV1Call;
  readonly observed: io.Block;
  readonly gasLimit: bigint;
  readonly stage: CurrentAuthorityPreservationArchiveV1Stage;
  readonly captureHash: Hex;
}
const coder = AbiCoder.defaultAbiCoder();
const host = (kind: Kind) => archive.currentAuthorityPreservationArchiveV1Interface(kind);
const commonInventory = (e: inv.CurrentAuthorityPreservationInventoryV1Evidence) => "inventory" in e ? e.inventory : e;
const commonCoverage = (e: Evidence) => "coverage" in e ? e.coverage : e;
const inventoryProfile = (kind: Kind) => kind === "collection" ? inv.CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_COLLECTION_PROFILE : inv.CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_SCOPED_PROFILE;
const profile = (kind: Kind) => kind === "collection" ? archive.CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_COLLECTION_PROFILE : archive.CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_SCOPED_PROFILE;
function historicalDeployment(v: CurrentAuthorityPreservationArchiveV1HistoryDeployment): CurrentAuthorityPreservationArchiveV1HistoryDeployment {
  io.keys(v, ["chainId", "core", "scopeKind", "archive"]);
  if (v.scopeKind !== "collection" && v.scopeKind !== "scoped") throw Error("Unsupported inventory family");
  return io.freeze({ chainId: io.uint(v.chainId), core: io.address(v.core), scopeKind: v.scopeKind, archive: io.codePin(v.archive) });
}
function deployment(v: CurrentAuthorityPreservationArchiveV1Deployment): CurrentAuthorityPreservationArchiveV1Deployment {
  io.keys(v, ["chainId", "core", "scopeKind", "archive", "authorityReader", "archiveReader", "linkedDependencies"]);
  return io.freeze({ ...historicalDeployment({ chainId: v.chainId, core: v.core, scopeKind: v.scopeKind, archive: v.archive }),
    authorityReader: io.codePin(v.authorityReader), archiveReader: io.codePin(v.archiveReader), linkedDependencies: io.pinList(v.linkedDependencies) });
}
const coordinates = (d: CurrentAuthorityPreservationArchiveV1HistoryDeployment): archive.CurrentAuthorityPreservationArchiveV1Coordinates => ({ chainId: d.chainId, core: d.core, scopeKind: d.scopeKind, archive: d.archive.address });
function locators(v: readonly CurrentAuthorityPreservationArchiveV1SegmentLocator[]) {
  if (!Array.isArray(v) || v.length > 16384) throw Error("Segment client allocation limit exceeded");
  const seen = new Set<string>();
  return v.map(row => { io.keys(row, ["transactionHash", "logIndex"]); const result = { transactionHash: io.hash(row.transactionHash), logIndex: io.number(row.logIndex) };
    const key = `${result.transactionHash}:${result.logIndex}`; if (seen.has(key)) throw Error("Duplicate segment locator"); seen.add(key); return result; });
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
const emptyProgress = () => zero(ParamType.from(archive.CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_PROGRESS_TUPLE)) as archive.CurrentAuthorityPreservationArchiveV1Progress;
const emptyRefresh = () => zero(ParamType.from(archive.CURRENT_AUTHORITY_PRESERVATION_ARCHIVE_V1_REFRESH_TUPLE)) as archive.CurrentAuthorityPreservationArchiveV1Refresh;
const read = <T>(p: io.Reader, d: CurrentAuthorityPreservationArchiveV1HistoryDeployment, name: string, args: readonly unknown[], tag: number): Promise<T> => io.read(p, d.archive.address, host(d.scopeKind), name, args, tag);
const dependencyPins = (deps: Dependencies) => deps.targets.map((address, i) => ({ address, codeHash: deps.codeHashes[i]! }));
const inventoryPins = (deps: inv.CurrentAuthorityPreservationInventoryV1Dependencies) => [...deps.targets.map((address, i) => ({ address, codeHash: deps.codeHashes[i]! })),
  ...deps.artistTargets.map((address, i) => ({ address, codeHash: deps.artistCodeHashes[i]! })), { address: deps.artistContentOwner, codeHash: deps.artistContentOwnerCodeHash }];
const archivePins = (origins: readonly Origin[]) => origins.map(o => ({ address: o.environment.archive, codeHash: o.archiveCodeHash }));
async function bindings(p: io.Reader, d: CurrentAuthorityPreservationArchiveV1HistoryDeployment, tag: number) {
  await io.runtime(p, d.archive, tag);
  const dependencies = archive.normalizeCurrentAuthorityPreservationArchiveV1Dependencies(await read(p, d, "dependencies", [], tag));
  const originDependencies = inv.normalizeCurrentAuthorityPreservationInventoryV1OriginDependencies(await read(p, d, "originDependencies", [], tag));
  const authorityDependencies = inv.normalizeCurrentAuthorityPreservationInventoryV1AuthorityDependencies(await read(p, d, "authorityDependencies", [], tag));
  if (dependencies.chainId !== d.chainId || dependencies.targets[0] !== d.core) throw Error("Archive deployment identity differs");
  const dependencyHash = archive.currentAuthorityPreservationArchiveV1DependencyHash(d.scopeKind, dependencies, originDependencies, authorityDependencies);
  io.equal(await read(p, d, "dependencyHash", [], tag), dependencyHash, "Archive dependency hash differs");
  for (const name of [d.scopeKind === "collection" ? "preservationPolicyBundleArchiveProfile" : "scopedPreservationPolicyBundleArchiveProfile", "originProfile"]) {
    io.equal(await read(p, d, name, [], tag), profile(d.scopeKind), "Wrong current-authority archive profile");
  }
  for (const [name, i] of [["core", 0], ["metadataHost", 1], ["renderCriticalInventory", 2], ["artifactCoverage", 3], ["externalCoverage", 4]] as const) io.equal(await read(p, d, name, [], tag), dependencies.targets[i], "Named archive dependency differs");
  for (const [name, i] of [["coreCodeHash", 0], ["metadataCodeHash", 1], ["inventoryCodeHash", 2]] as const) io.equal(await read(p, d, name, [], tag), dependencies.codeHashes[i], "Named archive runtime differs");
  io.equal(await read(p, d, "deploymentChainId", [], tag), d.chainId, "Archive chain differs");
  return { dependencies, originDependencies, authorityDependencies, dependencyHash };
}
async function inventoryHistory(p: io.ReceiptReader, d: CurrentAuthorityPreservationArchiveV1HistoryDeployment, b: Awaited<ReturnType<typeof bindings>>, id: Hex,
  retained: readonly CurrentAuthorityPreservationArchiveV1SegmentLocator[], tag: number): Promise<InventoryHistory> {
  const deps = b.dependencies;
  const value = await inspectCurrentAuthorityPreservationInventoryV1History(p, { chainId: d.chainId, core: d.core, scopeKind: d.scopeKind,
    inventory: { address: deps.targets[2], codeHash: deps.codeHashes[2] } }, id, { blockTag: tag, segments: retained });
  if (!value.evidence) throw Error("Original sealed inventory is required");
  const e = commonInventory(value.evidence);
  if (e.planId !== id || e.segmentCount === 0n || e.itemCount === 0n || e.artistId === io.ZERO || e.renderCriticalEvidenceHash === io.ZERO) throw Error("Incomplete original inventory");
  io.equal(value.originDependencies, b.originDependencies, "Original origin dependencies differ");
  io.equal(value.authorityDependencies, b.authorityDependencies, "Original authority dependencies differ");
  const original = value.originalAnchor;
  for (const [left, right] of [[0, 0], [1, 1], [10, 3], [11, 4]] as const) {
    io.equal([original.targets[left], original.codeHashes[left]], [deps.targets[right], deps.codeHashes[right]], "Original inventory/archive anchors differ");
  }
  io.equal([original.artistTargets[4], original.artistCodeHashes[4], original.chainId], [deps.targets[5], deps.codeHashes[5], d.chainId], "Original Artist archive anchor differs");
  return value;
}
async function currentEnvironment(p: io.Reader, d: CurrentAuthorityPreservationArchiveV1Deployment, b: Awaited<ReturnType<typeof bindings>>,
  inventory: InventoryHistory, tag: number, cap: bigint): Promise<CurrentAuthorityPreservationArchiveV1Environment> {
  const deps = b.dependencies, od = b.originDependencies, ad = b.authorityDependencies, id = inventory.planId;
  if (deps.readGas < 50000n || deps.archiveGas < deps.readGas || od.originGas < 50000n || od.originGas >= 1n << 64n
    || ad.resolverGas < 50000n || ad.resolverGas >= 1n << 64n || od.profile !== inv.CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_ORIGIN_PROFILE) throw Error("Invalid original archive read budgets/profile");
  await io.runtimes(p, [...dependencyPins(deps), d.authorityReader, d.archiveReader, ...d.linkedDependencies,
    { address: od.worker, codeHash: od.workerCodeHash }, { address: ad.resolver, codeHash: ad.resolverCodeHash },
    ...inventoryPins(inventory.originalAnchor), ...inventoryPins(inventory.selection.dependencies), ...archivePins(inventory.origins.origins)], tag);
  const original = inv.currentAuthorityPreservationInventoryV1Interface(d.scopeKind);
  const own = d.scopeKind === "collection" ? capabilities.IStreamCurrentAuthorityPreservationPolicyRenderCriticalInventoryV1 : capabilities.IStreamCurrentAuthorityScopedPreservationPolicyRenderCriticalInventoryV1;
  for (const [capability, expected] of [["0x01ffc9a7", true], ["0xffffffff", false], [own, true], [capabilities.IStreamArtistArchiveOriginInventory, true], [capabilities.IStreamCurrentAuthorityInventory, true]] as const) {
    io.equal(await io.read(p, deps.targets[2], original, "supportsInterface", [capability], tag, undefined, deps.readGas), expected, "Inventory capability differs");
  }
  const args = [deps, od, ad, inventoryProfile(d.scopeKind), id];
  const capture = inv.normalizeCurrentAuthorityPreservationInventoryV1Capture((await io.worker(p, d.authorityReader, workers.capture, args, tag, cap))[0] as inv.CurrentAuthorityPreservationInventoryV1Capture);
  io.equal(capture, inventory.selection, "Current resolver capture differs from sealed inventory");
  const authorityAnchors = inv.normalizeCurrentAuthorityPreservationInventoryV1AuthorityAnchors(await io.read(p, ad.resolver, resolverAbi, "anchors", [], tag, undefined, ad.resolverGas));
  io.equal(await io.read(p, ad.resolver, resolverAbi, "currentAuthorityProfile", [], tag, undefined, ad.resolverGas), inv.CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_AUTHORITY_PROFILE, "Wrong resolver profile");
  io.equal(await io.read(p, ad.resolver, resolverAbi, "currentSelection", [], tag, undefined, ad.resolverGas), capture.selection, "Actual current selection differs");
  inv.validateCurrentAuthorityPreservationInventoryV1Capture(inventory.originalAnchor, authorityAnchors, capture);
  await io.worker(p, d.archiveReader, workers.multiConfiguration, [deps, od, inventoryProfile(d.scopeKind)], tag, cap);
  const [root, count] = await io.worker(p, d.archiveReader, workers.multiOriginSet, [deps, id], tag, cap);
  const originRoot = io.hash(root), originCount = io.uint(count);
  io.equal([originRoot, originCount], [inventory.origins.setHash, BigInt(inventory.origins.origins.length)], "Original sealed origin set differs");
  for (let index = 0; index < inventory.origins.origins.length; index++) io.equal((await io.worker(p, d.archiveReader, workers.multiOriginAt, [deps, id, index], tag, cap))[0], inventory.origins.origins[index], "Original archive route differs");
  const native = await io.rpc(p, deps.targets[3], environmentAbi, "currentArtifactEnvironment", [], tag, undefined, deps.archiveGas);
  const external = await io.rpc(p, deps.targets[4], environmentAbi, "currentExternalArtifactEnvironment", [], tag, undefined, deps.archiveGas);
  const onchainHash = io.hash(native[0]), epoch = io.uint(native[1], 64), externalHash = io.hash(external[0]), revision = io.uint(external[1], 64);
  if (epoch === 0n) throw Error("Missing original validation epoch");
  const baseHash = archive.currentAuthorityPreservationArchiveV1BaseEnvironmentHash(deps, onchainHash, epoch, externalHash, revision);
  const multiOriginHash = archive.currentAuthorityPreservationArchiveV1MultiOriginEnvironmentHash(baseHash, od, d.scopeKind, id, originRoot, originCount);
  io.equal((await io.worker(p, d.archiveReader, workers.multiEnvironment, [deps, od, inventoryProfile(d.scopeKind), id], tag, cap))[0], multiOriginHash, "Multi-origin environment differs");
  const hash = archive.currentAuthorityPreservationArchiveV1EnvironmentHash(multiOriginHash, ad, capture);
  io.equal((await io.worker(p, d.authorityReader, workers.environment, args, tag, cap))[0], hash, "Original current-authority environment differs");
  return io.freeze({ hash, onchainHash, epoch, externalHash, revision, baseHash, multiOriginHash, originRoot, originCount, authorityAnchors, capture });
}
function itemSuffix(segment: inv.CurrentAuthorityPreservationInventoryV1Segment, items: readonly Item[], index: bigint): Hex {
  let next = io.ZERO;
  for (let i = items.length - 1; i >= Number(index); i--) next = inv.currentAuthorityPreservationInventoryV1Link(segment.key, segment.itemCount, BigInt(i), items[i]!, next);
  return next;
}
function originRoute(deps: Dependencies, inventory: InventoryHistory, item: Item) {
  const original = item.kind === 6n ? inventory.origins.records.find(row => row.itemHash === inv.currentAuthorityPreservationInventoryV1ItemHash(item))?.original : null;
  if (original === undefined) throw Error("Original state bundle occurrence is absent from authenticated inventory");
  const route = archive.validateCurrentAuthorityPreservationArchiveV1OriginRoute(deps, inventory.planId, commonInventory(inventory.evidence!), item, original, inventory.origins.origins);
  return { ...route, original };
}
async function observedRoute(p: io.Reader, d: CurrentAuthorityPreservationArchiveV1Deployment, deps: Dependencies, inventory: InventoryHistory, item: Item, tag: number, cap: bigint) {
  const expected = originRoute(deps, inventory, item);
  const raw = await io.worker(p, d.archiveReader, workers.multiRoute, [deps, inventory.planId, commonInventory(inventory.evidence!), item], tag, cap);
  io.equal(raw, [expected.dependencies, expected.originHash], "Original Item archive route differs");
  if (expected.original) await io.runtime(p, { address: expected.original.producer.environment.archive, codeHash: expected.original.producer.archiveCodeHash }, tag);
  return expected;
}
async function retainedAdmissions(p: io.Reader, d: CurrentAuthorityPreservationArchiveV1HistoryDeployment, deps: Dependencies,
  inventory: InventoryHistory, progress: archive.CurrentAuthorityPreservationArchiveV1Progress, tag: number) {
  const all = inventory.segments.flatMap(row => row.items), id = inventory.planId, e = commonInventory(inventory.evidence!);
  if (all.length > 16384 || progress.itemCount > BigInt(all.length)) throw Error("Archive item cursor exceeds authenticated inventory/client allocation");
  let chain = io.ZERO;
  const result: CurrentAuthorityPreservationArchiveV1AdmissionObservation[] = [];
  for (let index = 0n; index < progress.itemCount; index++) {
    const raw = await io.rpc(p, d.archive.address, host(d.scopeKind), "admittedItem", [id, index], tag);
    const item = inv.normalizeCurrentAuthorityPreservationInventoryV1Item(raw[0] as Item);
    io.equal(item, all[Number(index)], "Retained Item differs from original event occurrence");
    const admission = archive.validateCurrentAuthorityPreservationArchiveV1Admission(e.artistId, item, raw[1] as archive.CurrentAuthorityPreservationArchiveV1Admission);
    io.hash(admission.originalBundleHash);
    const routed = originRoute(deps, inventory, item);
    const originHash = io.hash(await read(p, d, "admittedOriginHash", [id, index], tag), true);
    io.equal(originHash, routed.originHash, "Retained original occurrence hash differs");
    chain = archive.currentAuthorityPreservationArchiveV1ItemChain(d.scopeKind, chain, id, index, inv.currentAuthorityPreservationInventoryV1ItemHash(item), admission, originHash);
    result.push({ item, admission, originHash, original: routed.original });
  }
  io.equal(chain, progress.evidenceChainHash, "Retained admission chain differs");
  let segmentChain = io.ZERO, count = 0n;
  for (let index = 0n; index < progress.segmentIndex; index++) {
    const segment = inventory.segments[Number(index)]?.segment;
    if (!segment) throw Error("Segment cursor exceeds original inventory");
    segmentChain = inv.currentAuthorityPreservationInventoryV1AppendSegment(segmentChain, index, segment); count += segment.itemCount;
  }
  io.equal(segmentChain, progress.segmentChainHash, "Consumed segment chain differs");
  if (progress.complete) {
    if (progress.segmentIndex !== BigInt(inventory.segments.length) || progress.segmentItemIndex !== 0n || progress.nextLink !== io.ZERO
      || count !== progress.itemCount || count !== BigInt(all.length)) throw Error("Malformed completed archive cursor");
  } else if (io.stable(progress) !== io.stable(emptyProgress())) {
    const current = inventory.segments[Number(progress.segmentIndex)];
    if (!current || progress.segmentItemIndex > current.segment.itemCount || count + progress.segmentItemIndex !== progress.itemCount) throw Error("Archive Item cursor differs");
    io.equal(itemSuffix(current.segment, current.items, progress.segmentItemIndex), progress.nextLink, "Next original Item suffix differs");
  }
  return io.freeze(result);
}
function completion(d: CurrentAuthorityPreservationArchiveV1HistoryDeployment, dependencyHash: Hex, inventory: InventoryHistory, progress: archive.CurrentAuthorityPreservationArchiveV1Progress): Evidence {
  return archive.currentAuthorityPreservationArchiveV1Evidence(coordinates(d), dependencyHash, inventory.origins.setHash, BigInt(inventory.origins.origins.length), inventory.evidence!, progress.evidenceChainHash);
}
function validateRefresh(value: archive.CurrentAuthorityPreservationArchiveV1Refresh, environment: Hex, count: bigint) {
  if (value.environmentHash === io.ZERO) { io.equal(value, emptyRefresh(), "Nondefault absent refresh"); return; }
  if (value.environmentHash !== environment || value.nextIndex > count || value.complete !== (value.nextIndex === count)
    || (value.nextIndex === 0n ? value.currentObservationChain !== io.ZERO : value.currentObservationChain === io.ZERO)) throw Error("Malformed observed environment refresh");
}
async function predict(p: io.ReceiptReader, d: CurrentAuthorityPreservationArchiveV1Deployment, prepared: archive.CurrentAuthorityPreservationArchiveV1Call,
  b: Awaited<ReturnType<typeof bindings>>, inventory: InventoryHistory, environment: CurrentAuthorityPreservationArchiveV1Environment, tag: number, cap: bigint): Promise<CurrentAuthorityPreservationArchiveV1Stage> {
  const q = prepared.request, deps = b.dependencies, e = commonInventory(inventory.evidence!);
  const before = archive.normalizeCurrentAuthorityPreservationArchiveV1Progress(await read(p, d, "progress", [q.id], tag));
  const existing = io.stable(before) !== io.stable(emptyProgress());
  const admissions = await retainedAdmissions(p, d, deps, inventory, before, tag);
  const refreshId = archive.currentAuthorityPreservationArchiveV1RefreshId(coordinates(d), b.dependencyHash, q.id, environment.hash);
  const refreshBefore = archive.normalizeCurrentAuthorityPreservationArchiveV1Refresh(await read(p, d, "refresh", [refreshId], tag));
  validateRefresh(refreshBefore, environment.hash, e.itemCount);
  const after = structuredClone(before) as Mutable<typeof before>;
  let refreshAfter: archive.CurrentAuthorityPreservationArchiveV1Refresh | null = refreshBefore;
  let admitted: CurrentAuthorityPreservationArchiveV1AdmissionObservation | null = null, currentObservation: Hex | null = null, evidence: Evidence | null = null;
  if (before.complete) {
    evidence = archive.normalizeCurrentAuthorityPreservationArchiveV1Evidence(d.scopeKind, await read(p, d, "bundleEvidence", [q.id], tag));
    io.equal(evidence, completion(d, b.dependencyHash, inventory, before), "Retained archive completion differs");
  }
  if (q.kind === "beginCoverage") {
    if (!existing) { after.environmentHash = environment.hash; after.nextLink = inventory.segments[0]!.segment.firstLink; }
  } else if (q.kind === "beginRefresh") {
    if (!before.complete) throw Error("Cannot refresh incomplete archive coverage");
    if (refreshBefore.environmentHash === io.ZERO) refreshAfter = { ...refreshBefore, environmentHash: environment.hash };
  } else if (q.kind === "refreshNext") {
    if (!before.complete || refreshBefore.environmentHash !== environment.hash || refreshBefore.complete || refreshBefore.nextIndex !== q.expectedIndex
      || q.expectedIndex >= BigInt(admissions.length)) throw Error("Refresh cursor differs");
    const original = admissions[Number(q.expectedIndex)]!;
    await observedRoute(p, d, deps, inventory, original.item, tag, cap);
    const [observation] = await io.worker(p, d.archiveReader, workers.multiCurrent,
      [deps, q.id, e, original.item, original.admission, original.originHash], tag, cap);
    currentObservation = io.hash(observation, true);
    refreshAfter = { environmentHash: environment.hash, nextIndex: q.expectedIndex + 1n,
      currentObservationChain: archive.currentAuthorityPreservationArchiveV1ObservationChain(d.scopeKind, refreshBefore.currentObservationChain, q.expectedIndex,
        inv.currentAuthorityPreservationInventoryV1ItemHash(original.item), currentObservation), complete: q.expectedIndex + 1n === e.itemCount };
  } else {
    if (!existing || before.complete) throw Error("Missing or completed archive coverage");
    const current = inventory.segments[Number(before.segmentIndex)];
    if (!current) throw Error("Missing current original segment");
    const segment = current.segment;
    if (q.kind === "coverEmptySegment") archive.validateCurrentAuthorityPreservationArchiveV1EmptySegment(before, segment);
    else {
      if (q.kind !== "coverNext") throw Error("Unsupported archive stage");
      const item = current.items[Number(before.segmentItemIndex)];
      if (!item) throw Error("Missing next original Item");
      io.equal(item, q.item, "CALL Item differs from exact original occurrence");
      archive.validateCurrentAuthorityPreservationArchiveV1NextItem(before, segment, item, q.nextLink);
      archive.validateCurrentAuthorityPreservationArchiveV1Proof(item, q.proof);
      io.equal(q.nextLink, itemSuffix(segment, current.items, before.segmentItemIndex + 1n), "CALL suffix differs");
      const routed = await observedRoute(p, d, deps, inventory, item, tag, cap);
      const raw = await io.worker(p, d.archiveReader, workers.multiAdmit, [deps, q.id, e, item, q.proof], tag, cap);
      const admission = archive.validateCurrentAuthorityPreservationArchiveV1Admission(e.artistId, item, raw[0] as archive.CurrentAuthorityPreservationArchiveV1Admission);
      io.equal(admission.proof, q.proof, "Original proof differs"); io.hash(admission.originalBundleHash);
      io.equal(raw[2], routed.originHash, "Original admission route hash differs");
      currentObservation = io.hash(raw[1], true);
      admitted = { item, admission, originHash: routed.originHash, original: routed.original };
      after.evidenceChainHash = archive.currentAuthorityPreservationArchiveV1ItemChain(d.scopeKind, before.evidenceChainHash, q.id, before.itemCount,
        inv.currentAuthorityPreservationInventoryV1ItemHash(item), admission, routed.originHash);
      after.itemCount++; after.segmentItemIndex++; after.nextLink = q.nextLink;
    }
    if (environment.hash !== before.environmentHash) after.environmentHash = io.ZERO;
    if (after.segmentItemIndex === segment.itemCount) {
      if (after.nextLink !== io.ZERO) throw Error("Original segment termination differs");
      after.segmentChainHash = inv.currentAuthorityPreservationInventoryV1AppendSegment(before.segmentChainHash, before.segmentIndex, segment);
      after.segmentIndex++; after.segmentItemIndex = 0n;
      if (after.segmentIndex === BigInt(inventory.segments.length)) {
        if (after.itemCount !== e.itemCount || after.segmentChainHash !== e.segmentChainHash) throw Error("Final inventory count/chain differs");
        after.complete = true; evidence = completion(d, b.dependencyHash, inventory, after);
        if (after.environmentHash !== io.ZERO) refreshAfter = null;
      } else after.nextLink = inventory.segments[Number(after.segmentIndex)]!.segment.firstLink;
    }
  }
  // Fixed-block RPC coherence, not an assertion about internal call order or whole-transaction gas.
  io.equal(await currentEnvironment(p, d, b, inventory, tag, cap), environment, "Archive environment changed during capture");
  return io.freeze({ ...b, inventory, environment, before, after, admissions, admitted, currentObservation,
    refreshId, refreshBefore, refreshAfter, evidence, existing, initialObservationChainAuthenticated: false });
}
async function originalCall(p: io.Reader, d: CurrentAuthorityPreservationArchiveV1Deployment, prepared: archive.CurrentAuthorityPreservationArchiveV1Call,
  stage: CurrentAuthorityPreservationArchiveV1Stage, tag: number, cap: bigint) {
  const raw = io.bytes(await p.call({ ...prepared.call, from: prepared.caller, blockTag: tag, gasLimit: cap }));
  const iface = host(d.scopeKind), method = prepared.request.kind, result = iface.decodeFunctionResult(method, raw);
  io.equal(iface.encodeFunctionResult(method, result), raw, "Noncanonical original call result");
  if (method === "beginRefresh") io.equal(result[0], stage.refreshId, "Original refresh identity differs");
  return raw;
}
export async function captureCurrentAuthorityPreservationArchiveV1(p: io.ReceiptReader, inputDeployment: CurrentAuthorityPreservationArchiveV1Deployment,
  inputCaller: Address, request: archive.CurrentAuthorityPreservationArchiveV1Request,
  options: { readonly blockTag: number; readonly gasLimit: bigint; readonly segments: readonly CurrentAuthorityPreservationArchiveV1SegmentLocator[] }): Promise<CurrentAuthorityPreservationArchiveV1WorkflowCapture> {
  const d = deployment(inputDeployment), prepared = archive.prepareCurrentAuthorityPreservationArchiveV1Call(coordinates(d), io.address(inputCaller), request);
  io.keys(options, ["blockTag", "gasLimit", "segments"]);
  const tag = io.number(options.blockTag), cap = io.gas(options.gasLimit), retained = locators(options.segments);
  const observed = await io.chain(p, d.chainId, tag), bound = await bindings(p, d, tag);
  const inventory = await inventoryHistory(p, d, bound, prepared.request.id, retained, tag);
  const environment = await currentEnvironment(p, d, bound, inventory, tag, cap);
  const stage = await predict(p, d, prepared, bound, inventory, environment, tag, cap);
  await originalCall(p, d, prepared, stage, tag, cap);
  await io.unchanged(p, observed);
  const value = { deployment: d, prepared, observed, gasLimit: cap, stage };
  return io.freeze({ ...value, captureHash: io.fingerprint(value) });
}
function savedCapture(input: CurrentAuthorityPreservationArchiveV1WorkflowCapture): CurrentAuthorityPreservationArchiveV1WorkflowCapture {
  io.keys(input, ["deployment", "prepared", "observed", "gasLimit", "stage", "captureHash"]);
  const value = structuredClone(input), { captureHash, ...body } = value;
  io.equal(captureHash, io.fingerprint(body), "Capture fingerprint differs");
  const d = deployment(value.deployment), prepared = archive.normalizeCurrentAuthorityPreservationArchiveV1Call(value.prepared);
  io.equal(prepared.coordinates, coordinates(d), "Saved call/deployment differs");
  io.gas(value.gasLimit); io.number(value.observed.blockNumber); io.hash(value.observed.blockHash); io.uint(value.observed.timestamp);
  return io.freeze({ ...value, deployment: d, prepared });
}
function comparable(v: CurrentAuthorityPreservationArchiveV1WorkflowCapture) {
  // Inventory history observes the selected block; its local facts must remain identical.
  const { observed, ...inventory } = v.stage.inventory;
  return { deployment: v.deployment, prepared: v.prepared, gasLimit: v.gasLimit, stage: { ...v.stage, inventory } };
}
async function revalidate(p: io.ReceiptReader, saved: CurrentAuthorityPreservationArchiveV1WorkflowCapture, tag: number) {
  await io.unchanged(p, saved.observed);
  if (tag < saved.observed.blockNumber) throw Error("Observation predates capture");
  const value = await captureCurrentAuthorityPreservationArchiveV1(p, saved.deployment, saved.prepared.caller, saved.prepared.request,
    { blockTag: tag, gasLimit: saved.gasLimit, segments: saved.stage.inventory.segments.map(row => row.locator) });
  io.equal(comparable(value), comparable(saved), "Saved archive facts changed; recapture");
  return value;
}
export async function simulateCurrentAuthorityPreservationArchiveV1(p: io.ReceiptReader, input: CurrentAuthorityPreservationArchiveV1WorkflowCapture,
  options: { readonly blockTag: number; readonly gasLimit: bigint }) {
  const saved = savedCapture(input); io.keys(options, ["blockTag", "gasLimit"]);
  const tag = io.number(options.blockTag), cap = io.gas(options.gasLimit);
  await revalidate(p, saved, saved.observed.blockNumber);
  const current = await revalidate(p, saved, tag), result = await originalCall(p, current.deployment, current.prepared, current.stage, tag, cap);
  await io.unchanged(p, current.observed);
  return io.freeze({ capture: current, result, originalCallSucceeded: true as const, stateChangesPersisted: false as const, gasLimit: cap });
}
export async function inspectCurrentAuthorityPreservationArchiveV1History(p: io.ReceiptReader, inputDeployment: CurrentAuthorityPreservationArchiveV1HistoryDeployment,
  inputId: Hex, options: { readonly blockTag: number; readonly segments: readonly CurrentAuthorityPreservationArchiveV1SegmentLocator[] }) {
  const d = historicalDeployment(inputDeployment), planId = io.hash(inputId); io.keys(options, ["blockTag", "segments"]);
  const tag = io.number(options.blockTag), retained = locators(options.segments), observed = await io.chain(p, d.chainId, tag);
  const bound = await bindings(p, d, tag), inventory = await inventoryHistory(p, d, bound, planId, retained, tag);
  const progress = archive.normalizeCurrentAuthorityPreservationArchiveV1Progress(await read(p, d, "progress", [planId], tag));
  const admissions = await retainedAdmissions(p, d, bound.dependencies, inventory, progress, tag);
  let evidence: Evidence | null = null;
  if (progress.complete) {
    evidence = archive.normalizeCurrentAuthorityPreservationArchiveV1Evidence(d.scopeKind, await read(p, d, "bundleEvidence", [planId], tag));
    io.equal(evidence, completion(d, bound.dependencyHash, inventory, progress), "Retained complete evidence differs");
  }
  await io.unchanged(p, observed);
  return io.freeze({ observed, planId, ...bound, inventory, progress, admissions, evidence,
    currentAuthorityChecked: false as const, currentEnvironmentChecked: false as const, inventoryCurrentSourceChecked: false as const,
    initialObservationChainAuthenticated: false as const });
}
function completedRefresh(value: archive.CurrentAuthorityPreservationArchiveV1Refresh, environment: Hex, itemCount: bigint) {
  validateRefresh(value, environment, itemCount);
  if (!value.complete || value.environmentHash !== environment || value.nextIndex !== itemCount || value.currentObservationChain === io.ZERO) throw Error("Missing completed environment refresh");
}
export async function inspectCurrentAuthorityPreservationArchiveV1Current(p: io.ReceiptReader, inputDeployment: CurrentAuthorityPreservationArchiveV1Deployment,
  inputId: Hex, options: { readonly blockTag: number; readonly gasLimit: bigint; readonly segments: readonly CurrentAuthorityPreservationArchiveV1SegmentLocator[]; readonly fullCurrentCoverage?: boolean }) {
  const d = deployment(inputDeployment), planId = io.hash(inputId); io.keys(options, ["blockTag", "gasLimit", "segments"], ["fullCurrentCoverage"]);
  const tag = io.number(options.blockTag), cap = io.gas(options.gasLimit), retained = locators(options.segments);
  if (options.fullCurrentCoverage !== undefined && typeof options.fullCurrentCoverage !== "boolean") throw Error("Expected diagnostic flag");
  const full = options.fullCurrentCoverage === true;
  const capture = await captureCurrentAuthorityPreservationArchiveV1(p, d, d.archive.address, { kind: "beginCoverage", id: planId }, { blockTag: tag, gasLimit: cap, segments: retained });
  const stage = capture.stage;
  if (!stage.evidence || !stage.before.complete) throw Error("Archive coverage is incomplete");
  const e = commonInventory(stage.inventory.evidence!);
  completedRefresh(stage.refreshBefore, stage.environment.hash, e.itemCount);
  const args = [planId, e.renderCriticalEvidenceHash];
  const fullArgs = "scope" in stage.inventory.evidence! ? [stage.inventory.evidence.scope, ...args] : args;
  const evidence = archive.normalizeCurrentAuthorityPreservationArchiveV1Evidence(d.scopeKind, await io.read(p, d.archive.address, host(d.scopeKind), "requireCoverage", fullArgs, tag, undefined, cap));
  io.equal(evidence, stage.evidence, "Original bounded current coverage differs");
  if (full) io.equal(await io.read(p, d.archive.address, host(d.scopeKind), "requireFullCurrentCoverage", [planId], tag, undefined, cap), evidence, "Original full diagnostic differs");
  await io.unchanged(p, capture.observed);
  return io.freeze({ capture, evidence, refresh: stage.refreshBefore, currentAuthorityChecked: true as const, currentEnvironmentChecked: true as const,
    fullCurrentCoverageChecked: full, inventoryCurrentSourceChecked: false as const, initialObservationChainAuthenticated: false as const });
}
const eventName = (kind: Kind, suffix: string) => `${kind === "scoped" ? "Scoped" : ""}Bundle${suffix}`;
export async function reconcileCurrentAuthorityPreservationArchiveV1Receipt(p: io.ReceiptReader, input: CurrentAuthorityPreservationArchiveV1WorkflowCapture,
  inputHash: Hex, options: CurrentAuthorityPreservationArchiveV1ReceiptOptions) {
  const saved = savedCapture(input), tx = await io.transport(p, { chainId: saved.deployment.chainId, caller: saved.prepared.caller,
    call: saved.prepared.call, observed: saved.observed }, io.hash(inputHash), options);
  await revalidate(p, saved, saved.observed.blockNumber);
  const prior = await revalidate(p, saved, tx.observed.blockNumber - 1), d = prior.deployment, stage = prior.stage, tag = tx.observed.blockNumber, planId = prior.prepared.request.id;
  await io.runtimes(p, [d.archive, d.authorityReader, d.archiveReader, ...d.linkedDependencies, ...dependencyPins(stage.dependencies),
    { address: stage.originDependencies.worker, codeHash: stage.originDependencies.workerCodeHash },
    { address: stage.authorityDependencies.resolver, codeHash: stage.authorityDependencies.resolverCodeHash },
    ...inventoryPins(stage.inventory.originalAnchor), ...inventoryPins(stage.environment.capture.dependencies), ...archivePins(stage.inventory.origins.origins)], tag);
  io.equal(await read(p, d, "progress", [planId], tag), stage.after, "End-block archive progress differs; concurrent progress is not attributed");
  const iface = host(d.scopeKind), schema = d.scopeKind === "scoped" ? [1n] : [];
  const starts = io.events(tx.logs, d.archive.address, iface, eventName(d.scopeKind, "CoverageStarted"));
  const items = io.events(tx.logs, d.archive.address, iface, eventName(d.scopeKind, "ItemAdmitted"));
  const completes = io.events(tx.logs, d.archive.address, iface, eventName(d.scopeKind, "CoverageCompleted"));
  const advances = io.events(tx.logs, d.archive.address, iface, eventName(d.scopeKind, "RefreshAdvanced"));
  const kind = prior.prepared.request.kind, e = commonInventory(stage.inventory.evidence!);
  if (kind === "beginCoverage") {
    if (starts.length !== (stage.existing ? 0 : 1) || items.length || completes.length || advances.length) throw Error("Unexpected begin coverage events");
    if (!stage.existing) io.one(tx.logs, d.archive.address, iface, eventName(d.scopeKind, "CoverageStarted"), [...schema, planId, e.renderCriticalEvidenceHash]);
  } else if (kind === "beginRefresh") {
    if (starts.length || items.length || completes.length || advances.length) throw Error("Refresh begin is eventless");
  } else if (kind === "refreshNext") {
    if (starts.length || items.length || completes.length) throw Error("Unexpected refresh events");
    io.one(tx.logs, d.archive.address, iface, eventName(d.scopeKind, "RefreshAdvanced"), [...schema, planId, stage.refreshId,
      stage.refreshAfter!.nextIndex, stage.refreshAfter!.currentObservationChain, stage.refreshAfter!.complete]);
  } else {
    if (starts.length || advances.length || items.length !== (kind === "coverNext" ? 1 : 0) || completes.length !== (stage.after.complete ? 1 : 0)) throw Error("Unexpected admission events");
    let index = -1;
    if (stage.admitted) {
      index = io.one(tx.logs, d.archive.address, iface, eventName(d.scopeKind, "ItemAdmitted"), [...schema, planId, stage.before.itemCount,
        inv.currentAuthorityPreservationInventoryV1ItemHash(stage.admitted.item), stage.admitted.admission]).index;
      io.equal(await io.rpc(p, d.archive.address, iface, "admittedItem", [planId, stage.before.itemCount], tag), [stage.admitted.item, stage.admitted.admission], "New retained Item/Admission differs");
      io.equal(await read(p, d, "admittedOriginHash", [planId, stage.before.itemCount], tag), stage.admitted.originHash, "New retained original route differs");
    }
    if (stage.after.complete) {
      const event = io.one(tx.logs, d.archive.address, iface, eventName(d.scopeKind, "CoverageCompleted"), [...schema, planId, commonCoverage(stage.evidence!).bundleCoverageHash, stage.evidence]);
      if (event.index <= index) throw Error("Completion precedes admission");
    }
  }
  if (stage.evidence) io.equal(await read(p, d, "bundleEvidence", [planId], tag), stage.evidence, "Retained completed evidence differs");
  const refresh = archive.normalizeCurrentAuthorityPreservationArchiveV1Refresh(await read(p, d, "refresh", [stage.refreshId], tag));
  if (stage.refreshAfter) io.equal(refresh, stage.refreshAfter, "End-block refresh differs");
  else completedRefresh(refresh, stage.environment.hash, e.itemCount);
  io.finish(tx.logs, [d.archive.address], tx.safeIndex); await io.unchanged(p, tx.observed);
  return io.freeze({ observed: tx.observed, transactionHash: tx.transactionHash, planId, progress: stage.after, admitted: stage.admitted,
    evidence: stage.evidence, refreshId: stage.refreshId, refresh, initialObservationChainAuthenticated: false as const,
    refreshStepChainAuthenticated: kind === "refreshNext", precedingAndEndBlockAttribution: true as const, currentAfterReceipt: false as const });
}
export async function observeCurrentAuthorityPreservationArchiveV1Refusal(p: io.ReceiptReader, input: CurrentAuthorityPreservationArchiveV1WorkflowCapture,
  options: { readonly blockTag: number; readonly gasLimit: bigint }) {
  const saved = savedCapture(input); io.keys(options, ["blockTag", "gasLimit"]);
  const tag = io.number(options.blockTag), cap = io.gas(options.gasLimit);
  await revalidate(p, saved, saved.observed.blockNumber);
  if (tag < saved.observed.blockNumber) throw Error("Refusal predates capture");
  const observed = await io.chain(p, saved.deployment.chainId, tag), d = saved.deployment;
  await io.runtime(p, d.archive, tag);
  const local = async () => ({ progress: await read(p, d, "progress", [saved.prepared.request.id], tag), refresh: await read(p, d, "refresh", [saved.stage.refreshId], tag) });
  const before = await local(); let error: unknown;
  try { await p.call({ ...saved.prepared.call, from: saved.prepared.caller, blockTag: tag, gasLimit: cap }); } catch (failure) { error = failure; }
  if (error === undefined) throw Error("Original call did not refuse");
  const after = await local(); await io.unchanged(p, observed);
  return { observed, error, outcome: (error as { code?: string })?.code === "CALL_EXCEPTION" ? "execution-reverted" as const : "rpc-failed" as const,
    retainedStateUnchanged: io.stable(before) === io.stable(after), rollbackProven: false as const };
}
