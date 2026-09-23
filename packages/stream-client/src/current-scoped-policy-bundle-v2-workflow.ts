import { AbiCoder, Interface, ParamType, keccak256 } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import * as bundle from "./current-scoped-policy-bundle-v2.js";
import * as inv from "./current-scoped-policy-inventory-v2.js";
import { inspectScopedPolicyInventoryV2History, type ScopedPolicyInventoryV2SegmentLocator } from "./current-scoped-policy-inventory-v2-workflow.js";
import * as io from "./current-scoped-policy-inventory-archive-workflow-internal.js";

// Separate ABI129 nominal selectors and source/ordinary-ABI-authenticated value tuples.
const workers = {
  environment: {
    selector: "0x4f6bb089",
    inputs: ["(address[6] targets, bytes32[6] codeHashes, uint256 chainId, uint256 readGas, uint256 archiveGas)"],
    outputs: ["bytes32"]
  },
  admit: {
    selector: "0x77edbfe6",
    inputs: ["(address[6] targets, bytes32[6] codeHashes, uint256 chainId, uint256 readGas, uint256 archiveGas)","bytes32","(uint8 kind, bytes32 role, address source, bytes32 sourceRecord, uint256 sourceIndex, uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri, uint64 byteSize, bytes32 schemaId, bytes32 formatId, bytes32 catalogId, bytes32 catalogHash, bytes32 objectHash, bytes32 originalCoverageHash, bytes32 provenanceHash)","(uint8 backend, bytes32 coverageHash, bytes32 objectHash)"],
    outputs: ["((uint8 backend, bytes32 coverageHash, bytes32 objectHash) proof, bytes32 originalBundleHash, bytes32 immutablePartsHash, (bytes32 coverageHash, bytes32 objectHash, bytes32 artistId, bytes32 contentHash, bytes32 sha256Digest, bytes32 arweaveDataRoot, uint64 byteSize, bytes32 firstFamilyRecordHash, bytes32 secondFamilyRecordHash, bytes32 firstReceiptHash, bytes32 secondReceiptHash, bytes32 firstFixityHash, bytes32 secondFixityHash, bytes32 checkpointHash, bytes32 profileHash) externalOriginal, (bytes32 completionHash, bytes32 artifactHash, bytes32 artistId, bytes32 schemaId, bytes32 canonicalizationId, bytes32 contentHash, uint64 byteLength, uint32 chunkCount, bytes32 firstFamilyRecordHash, bytes32 secondFamilyRecordHash, uint64 validationEpoch, bytes32 evidenceChainHash) onchainOriginal)","bytes32"]
  },
  current: {
    selector: "0x29054134",
    inputs: ["(address[6] targets, bytes32[6] codeHashes, uint256 chainId, uint256 readGas, uint256 archiveGas)","bytes32","(uint8 kind, bytes32 role, address source, bytes32 sourceRecord, uint256 sourceIndex, uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri, uint64 byteSize, bytes32 schemaId, bytes32 formatId, bytes32 catalogId, bytes32 catalogHash, bytes32 objectHash, bytes32 originalCoverageHash, bytes32 provenanceHash)","((uint8 backend, bytes32 coverageHash, bytes32 objectHash) proof, bytes32 originalBundleHash, bytes32 immutablePartsHash, (bytes32 coverageHash, bytes32 objectHash, bytes32 artistId, bytes32 contentHash, bytes32 sha256Digest, bytes32 arweaveDataRoot, uint64 byteSize, bytes32 firstFamilyRecordHash, bytes32 secondFamilyRecordHash, bytes32 firstReceiptHash, bytes32 secondReceiptHash, bytes32 firstFixityHash, bytes32 secondFixityHash, bytes32 checkpointHash, bytes32 profileHash) externalOriginal, (bytes32 completionHash, bytes32 artifactHash, bytes32 artistId, bytes32 schemaId, bytes32 canonicalizationId, bytes32 contentHash, uint64 byteLength, uint32 chunkCount, bytes32 firstFamilyRecordHash, bytes32 secondFamilyRecordHash, uint64 validationEpoch, bytes32 evidenceChainHash) onchainOriginal)"],
    outputs: ["bytes32"]
  },
} as const satisfies Record<string, io.WorkerMethod>;

const environmentAbi = new Interface([
  "function currentArtifactEnvironment() view returns (bytes32 environmentHash, uint64 validationEpoch)",
  "function currentExternalArtifactEnvironment() view returns (bytes32 environmentHash, uint64 healthRevision)"
]);

export type ScopedPolicyBundleV2CodePin = io.CodePin;
export type ScopedPolicyBundleV2Block = io.Block;
export type ScopedPolicyBundleV2ReceiptOptions = io.ReceiptOptions;
export interface ScopedPolicyBundleV2Deployment {
  readonly chainId: bigint;
  readonly core: Address;
  readonly bundle: io.CodePin;
  /** Original public view library, authenticated by reviewed release/link metadata. */
  readonly archiveReader: io.CodePin;
  readonly linkedDependencies: readonly io.CodePin[];
}
export interface ScopedPolicyBundleV2HistoryDeployment {
  readonly chainId: bigint;
  readonly core: Address;
  readonly bundle: io.CodePin;
}
export interface ScopedPolicyBundleV2AdmissionObservation {
  readonly item: inv.ScopedPolicyInventoryV2Item;
  readonly admission: bundle.ScopedPolicyBundleV2Admission;
}
export interface ScopedPolicyBundleV2Environment {
  readonly hash: Hex;
  readonly onchainHash: Hex;
  readonly epoch: bigint;
  readonly externalHash: Hex;
  readonly revision: bigint;
}
export interface ScopedPolicyBundleV2Stage {
  readonly dependencies: bundle.ScopedPolicyBundleV2Dependencies;
  readonly dependencyHash: Hex;
  readonly inventory: inv.ScopedPolicyInventoryV2Evidence;
  readonly segments: readonly import("./current-scoped-policy-inventory-v2-workflow.js").ScopedPolicyInventoryV2SegmentObservation[];
  readonly environment: ScopedPolicyBundleV2Environment;
  readonly before: bundle.ScopedPolicyBundleV2Progress;
  readonly after: bundle.ScopedPolicyBundleV2Progress;
  readonly admissions: readonly ScopedPolicyBundleV2AdmissionObservation[];
  readonly admitted: ScopedPolicyBundleV2AdmissionObservation | null;
  readonly currentObservation: Hex | null;
  readonly refreshId: Hex;
  readonly refreshBefore: bundle.ScopedPolicyBundleV2Refresh;
  readonly refreshAfter: bundle.ScopedPolicyBundleV2Refresh | null;
  readonly evidence: bundle.ScopedPolicyBundleV2Evidence | null;
  readonly existing: boolean;
  readonly initialObservationChainAuthenticated: false;
}
export interface ScopedPolicyBundleV2WorkflowCapture {
  readonly deployment: ScopedPolicyBundleV2Deployment;
  readonly prepared: bundle.ScopedPolicyBundleV2Call;
  readonly observed: io.Block;
  readonly gasLimit: bigint;
  readonly stage: ScopedPolicyBundleV2Stage;
  readonly captureHash: Hex;
}
type Mutable<T> = T extends readonly (infer V)[] ? Mutable<V>[] : T extends object ? { -readonly [K in keyof T]: Mutable<T[K]> } : T;
const coder = AbiCoder.defaultAbiCoder();
const host = () => bundle.scopedPolicyBundleV2Interface();
function deployment(input: ScopedPolicyBundleV2Deployment): ScopedPolicyBundleV2Deployment {
  io.keys(input, ["chainId", "core", "bundle", "archiveReader", "linkedDependencies"]);
  return io.freeze({ chainId: io.uint(input.chainId), core: io.address(input.core), bundle: io.codePin(input.bundle),
    archiveReader: io.codePin(input.archiveReader), linkedDependencies: io.pinList(input.linkedDependencies) });
}
function historicalDeployment(input: ScopedPolicyBundleV2HistoryDeployment): ScopedPolicyBundleV2HistoryDeployment {
  io.keys(input, ["chainId", "core", "bundle"]);
  return io.freeze({ chainId: io.uint(input.chainId), core: io.address(input.core), bundle: io.codePin(input.bundle) });
}
function coordinates(d: ScopedPolicyBundleV2HistoryDeployment): bundle.ScopedPolicyBundleV2Coordinates {
  return { chainId: d.chainId, core: d.core, bundle: d.bundle.address };
}
function zero(type: ParamType): unknown {
  if (type.baseType === "array") return type.arrayLength === -1 ? [] : Array.from({ length: type.arrayLength! }, () => zero(type.arrayChildren!));
  if (type.baseType === "tuple") return Object.fromEntries(type.components!.map(p => [p.name, zero(p)]));
  if (type.type === "address") return io.ZERO_ADDRESS;
  if (type.type === "bool") return false;
  if (type.type === "string") return "";
  if (type.type === "bytes") return "0x";
  if (type.type.startsWith("bytes")) return `0x${"00".repeat(Number(type.type.slice(5)))}`;
  return 0n;
}
const emptyProgress = () => zero(ParamType.from(bundle.SCOPED_POLICY_BUNDLE_V2_PROGRESS_TUPLE)) as bundle.ScopedPolicyBundleV2Progress;
const emptyRefresh = () => zero(ParamType.from(bundle.SCOPED_POLICY_BUNDLE_V2_REFRESH_TUPLE)) as bundle.ScopedPolicyBundleV2Refresh;
async function read<T>(p: io.Reader, d: ScopedPolicyBundleV2HistoryDeployment, method: string, args: readonly unknown[], tag: number) {
  return io.read<T>(p, d.bundle.address, host(), method, args, tag);
}
async function bindings(p: io.Reader, d: ScopedPolicyBundleV2HistoryDeployment, tag: number) {
  await io.runtime(p, d.bundle, tag);
  const deps = bundle.normalizeScopedPolicyBundleV2Dependencies(await read(p, d, "dependencies", [], tag));
  if (deps.chainId !== d.chainId || !io.same(deps.targets[0], d.core)) throw Error("Bundle deployment binding differs");
  const dependencyHash = bundle.scopedPolicyBundleV2DependencyHash(deps);
  io.equal(await read(p, d, "dependencyHash", [], tag), dependencyHash, "Bundle dependency hash differs");
  io.equal(await read(p, d, "scopedPolicyBundleArchiveProfile", [], tag), bundle.SCOPED_POLICY_BUNDLE_V2_PROFILE, "Wrong bundle profile");
  io.equal(await read(p, d, "supportsInterface", [bundle.SCOPED_POLICY_BUNDLE_V2_INTERFACE_ID], tag), true, "Missing original bundle capability");
  const names = [["core", 0], ["metadataHost", 1], ["renderCriticalInventory", 2], ["artifactCoverage", 3], ["externalCoverage", 4]] as const;
  for (const [name, slot] of names) io.equal(await read(p, d, name, [], tag), deps.targets[slot], "Named bundle dependency differs");
  io.equal(await read(p, d, "deploymentChainId", [], tag), d.chainId, "Bundle deployment chain differs");
  for (const [name, slot] of [["coreCodeHash", 0], ["metadataCodeHash", 1], ["inventoryCodeHash", 2]] as const) {
    io.equal(await read(p, d, name, [], tag), deps.codeHashes[slot], "Named bundle runtime differs");
  }
  return { deps, dependencyHash };
}
async function currentEnvironment(
  p: io.Reader, d: ScopedPolicyBundleV2Deployment, deps: bundle.ScopedPolicyBundleV2Dependencies, tag: number, cap: bigint
): Promise<ScopedPolicyBundleV2Environment> {
  await io.runtimes(p, [...deps.targets.map((address, i) => ({ address, codeHash: deps.codeHashes[i]! })),
    d.archiveReader, ...d.linkedDependencies], tag);
  const inventory = inv.scopedPolicyInventoryV2Interface();
  io.equal(await io.read(p, deps.targets[2], inventory, "supportsInterface", [inv.SCOPED_POLICY_INVENTORY_V2_INTERFACE_ID], tag), true,
    "Missing scoped inventory capability");
  io.equal(await io.read(p, deps.targets[2], inventory, "scopedPolicyInventoryProfile", [], tag), inv.SCOPED_POLICY_INVENTORY_V2_PROFILE,
    "Wrong scoped inventory profile");
  const native = await io.rpc(p, deps.targets[3], environmentAbi, "currentArtifactEnvironment", [], tag, undefined, deps.archiveGas);
  const external = await io.rpc(p, deps.targets[4], environmentAbi, "currentExternalArtifactEnvironment", [], tag, undefined, deps.archiveGas);
  const onchainHash = io.hash(native[0]);
  const epoch = io.uint(native[1], 64);
  const externalHash = io.hash(external[0]);
  const revision = io.uint(external[1], 64);
  if (epoch === 0n) throw Error("Missing native archival epoch");
  const hash = bundle.scopedPolicyBundleV2EnvironmentHash(deps, onchainHash, epoch, externalHash, revision);
  const [original] = await io.worker(p, d.archiveReader, workers.environment, [deps], tag, cap);
  io.equal(original, hash, "Original archival environment differs");
  return { hash, onchainHash, epoch, externalHash, revision };
}

function itemSuffix(segment: inv.ScopedPolicyInventoryV2Segment, items: readonly inv.ScopedPolicyInventoryV2Item[], index: bigint): Hex {
  let next = io.ZERO;
  for (let at = items.length - 1; at >= Number(index); at--) {
    next = inv.scopedPolicyInventoryV2Link(segment.key, segment.itemCount, BigInt(at), items[at]!, next);
  }
  return next;
}
async function retainedAdmissions(
  p: io.Reader, d: ScopedPolicyBundleV2HistoryDeployment, planId: Hex,
  progress: bundle.ScopedPolicyBundleV2Progress,
  segments: ScopedPolicyBundleV2Stage["segments"], artistId: Hex, tag: number
): Promise<readonly ScopedPolicyBundleV2AdmissionObservation[]> {
  const all = segments.flatMap(segment => segment.items);
  if (progress.itemCount > BigInt(all.length) || progress.itemCount > BigInt(io.MAX_ROWS)) throw Error("Bundle item count exceeds authenticated inventory");
  let evidenceChain = io.ZERO;
  const result: ScopedPolicyBundleV2AdmissionObservation[] = [];
  for (let index = 0n; index < progress.itemCount; index++) {
    const values = await io.rpc(p, d.bundle.address, host(), "admittedItem", [planId, index], tag);
    const item = inv.normalizeScopedPolicyInventoryV2Item(values[0] as inv.ScopedPolicyInventoryV2Item);
    const admission = bundle.validateScopedPolicyBundleV2Admission(artistId, item, values[1] as bundle.ScopedPolicyBundleV2Admission);
    io.equal(item, all[Number(index)], "Retained admission Item differs from original event occurrence");
    io.hash(admission.originalBundleHash);
    evidenceChain = bundle.scopedPolicyBundleV2ItemChain(evidenceChain, planId, index, inv.scopedPolicyInventoryV2ItemHash(item), admission);
    result.push({ item, admission });
  }
  io.equal(evidenceChain, progress.evidenceChainHash, "Retained admission chain differs");
  let segmentChain = io.ZERO;
  let count = 0n;
  for (let index = 0n; index < progress.segmentIndex; index++) {
    const segment = segments[Number(index)]?.segment;
    if (!segment) throw Error("Bundle segment cursor exceeds inventory");
    count += segment.itemCount;
    segmentChain = inv.scopedPolicyInventoryV2AppendSegment(segmentChain, index, segment);
  }
  io.equal(segmentChain, progress.segmentChainHash, "Consumed segment chain differs");
  if (progress.complete) {
    if (progress.segmentIndex !== BigInt(segments.length) || progress.segmentItemIndex !== 0n || progress.nextLink !== io.ZERO
      || count !== progress.itemCount || progress.itemCount !== BigInt(all.length)) throw Error("Malformed completed bundle cursor");
  } else if (progress.environmentHash !== io.ZERO || progress.itemCount !== 0n || progress.segmentIndex !== 0n || progress.nextLink !== io.ZERO) {
    const current = segments[Number(progress.segmentIndex)];
    if (!current || progress.segmentItemIndex > current.segment.itemCount || count + progress.segmentItemIndex !== progress.itemCount) {
      throw Error("Bundle item cursor differs");
    }
    io.equal(itemSuffix(current.segment, current.items, progress.segmentItemIndex), progress.nextLink, "Next original Item suffix differs");
  } else io.equal(progress, emptyProgress(), "Nondefault missing bundle progress");
  return io.freeze(result);
}
function completion(
  d: ScopedPolicyBundleV2HistoryDeployment, dependencyHash: Hex, inventory: inv.ScopedPolicyInventoryV2Evidence,
  progress: bundle.ScopedPolicyBundleV2Progress
): bundle.ScopedPolicyBundleV2Evidence {
  const result = { scope: inventory.scope, coverage: { inventoryPlan: inventory.inventory.planId,
    renderCriticalEvidenceHash: inventory.inventory.renderCriticalEvidenceHash, itemCount: progress.itemCount,
    evidenceChainHash: progress.evidenceChainHash, bundleCoverageHash: io.ZERO } };
  return bundle.normalizeScopedPolicyBundleV2Evidence({ ...result, coverage: { ...result.coverage,
    bundleCoverageHash: bundle.scopedPolicyBundleV2CoverageHash(coordinates(d), dependencyHash, inventory, result) } });
}

async function predict(
  p: io.ReceiptReader, d: ScopedPolicyBundleV2Deployment, prepared: bundle.ScopedPolicyBundleV2Call,
  deps: bundle.ScopedPolicyBundleV2Dependencies, dependencyHash: Hex,
  inventory: inv.ScopedPolicyInventoryV2Evidence, segments: ScopedPolicyBundleV2Stage["segments"],
  environment: ScopedPolicyBundleV2Environment, tag: number, cap: bigint
): Promise<ScopedPolicyBundleV2Stage> {
  const q = prepared.request;
  const before = bundle.normalizeScopedPolicyBundleV2Progress(await read(p, d, "progress", [q.id], tag));
  const existing = io.stable(before) !== io.stable(emptyProgress());
  const admissions = await retainedAdmissions(p, d, q.id, before, segments, inventory.inventory.artistId, tag);
  const refreshId = bundle.scopedPolicyBundleV2RefreshId(coordinates(d), dependencyHash, q.id, environment.hash);
  const refreshBefore = bundle.normalizeScopedPolicyBundleV2Refresh(await read(p, d, "refresh", [refreshId], tag));
  if (refreshBefore.environmentHash === io.ZERO) io.equal(refreshBefore, emptyRefresh(), "Nondefault missing refresh");
  else if (refreshBefore.environmentHash !== environment.hash || refreshBefore.nextIndex > inventory.inventory.itemCount
    || refreshBefore.complete !== (refreshBefore.nextIndex === inventory.inventory.itemCount)
    || (refreshBefore.nextIndex === 0n ? refreshBefore.currentObservationChain !== io.ZERO : refreshBefore.currentObservationChain === io.ZERO)) {
    throw Error("Malformed current environment refresh");
  }
  const after = structuredClone(before) as Mutable<bundle.ScopedPolicyBundleV2Progress>;
  let refreshAfter: bundle.ScopedPolicyBundleV2Refresh | null = refreshBefore;
  let admitted: ScopedPolicyBundleV2AdmissionObservation | null = null;
  let currentObservation: Hex | null = null;
  let evidence: bundle.ScopedPolicyBundleV2Evidence | null = null;
  if (before.complete) {
    evidence = bundle.normalizeScopedPolicyBundleV2Evidence(await read(p, d, "bundleEvidence", [q.id], tag));
    io.equal(evidence, completion(d, dependencyHash, inventory, before), "Retained completed coverage differs");
  }
  if (q.kind === "beginCoverage") {
    if (!existing) {
      if (!segments.length || inventory.inventory.itemCount === 0n) throw Error("Inventory has no complete evidence");
      after.environmentHash = environment.hash;
      after.nextLink = segments[0]!.segment.firstLink;
    }
  } else if (q.kind === "beginRefresh") {
    if (!before.complete) throw Error("Cannot refresh incomplete coverage");
    if (refreshBefore.environmentHash === io.ZERO) refreshAfter = { ...refreshBefore, environmentHash: environment.hash };
  } else if (q.kind === "refreshNext") {
    if (!before.complete || refreshBefore.environmentHash !== environment.hash || refreshBefore.complete
      || refreshBefore.nextIndex !== q.expectedIndex || q.expectedIndex >= BigInt(admissions.length)) throw Error("Refresh cursor differs");
    const original = admissions[Number(q.expectedIndex)]!;
    const [observation] = await io.worker(p, d.archiveReader, workers.current,
      [deps, inventory.inventory.artistId, original.item, original.admission], tag, cap);
    currentObservation = io.hash(observation, true);
    refreshAfter = { environmentHash: environment.hash, nextIndex: q.expectedIndex + 1n,
      currentObservationChain: bundle.scopedPolicyBundleV2ObservationChain(refreshBefore.currentObservationChain, q.expectedIndex,
        inv.scopedPolicyInventoryV2ItemHash(original.item), currentObservation),
      complete: q.expectedIndex + 1n === inventory.inventory.itemCount };
  } else {
    if (!existing || before.complete) throw Error("Missing or completed bundle coverage");
    const current = segments[Number(before.segmentIndex)];
    if (!current) throw Error("Missing current original segment");
    const segment = current.segment;
    if (q.kind === "coverEmptySegment") {
      bundle.validateScopedPolicyBundleV2EmptySegment(before, segment);
      if (segment.itemCount !== 0n || segment.firstLink !== io.ZERO || before.segmentItemIndex !== 0n || before.nextLink !== io.ZERO) {
        throw Error("Original segment is not empty");
      }
    } else {
      if (q.kind !== "coverNext") throw Error("Unsupported bundle admission stage");
      const item = current.items[Number(before.segmentItemIndex)];
      if (!item) throw Error("No next original Item");
      io.equal(q.item, item, "CALL Item differs from authenticated original occurrence");
      bundle.validateScopedPolicyBundleV2NextItem(before, segment, item, q.nextLink);
      bundle.validateScopedPolicyBundleV2Proof(item, q.proof);
      io.equal(q.nextLink, itemSuffix(segment, current.items, before.segmentItemIndex + 1n), "CALL suffix differs");
      io.equal(inv.scopedPolicyInventoryV2Link(segment.key, segment.itemCount, before.segmentItemIndex, q.item, q.nextLink), before.nextLink,
        "CALL link differs from retained cursor");
      const values = await io.worker(p, d.archiveReader, workers.admit, [deps, inventory.inventory.artistId, item, q.proof], tag, cap);
      const admission = bundle.validateScopedPolicyBundleV2Admission(inventory.inventory.artistId, item, values[0] as bundle.ScopedPolicyBundleV2Admission);
      io.equal(admission.proof, q.proof, "Original admission proof differs");
      io.hash(admission.originalBundleHash);
      admitted = { item, admission };
      currentObservation = io.hash(values[1], true);
      after.evidenceChainHash = bundle.scopedPolicyBundleV2ItemChain(before.evidenceChainHash, q.id, before.itemCount,
        inv.scopedPolicyInventoryV2ItemHash(item), admission);
      after.itemCount++;
      after.segmentItemIndex++;
      after.nextLink = q.nextLink;
    }
    if (environment.hash !== after.environmentHash) after.environmentHash = io.ZERO;
    if (after.segmentItemIndex === segment.itemCount) {
      if (after.nextLink !== io.ZERO) throw Error("Original segment termination differs");
      after.segmentChainHash = inv.scopedPolicyInventoryV2AppendSegment(before.segmentChainHash, before.segmentIndex, segment);
      after.segmentIndex++;
      after.segmentItemIndex = 0n;
      if (after.segmentIndex === BigInt(segments.length)) {
        if (after.itemCount !== inventory.inventory.itemCount || after.segmentChainHash !== inventory.inventory.segmentChainHash) {
          throw Error("Completed bundle count/segment chain differs");
        }
        after.complete = true;
        evidence = completion(d, dependencyHash, inventory, after);
        // The original contract's private initial observation accumulator has no getter/event.
        // Its automatic refresh is checked as a host observation at receipt reconciliation.
        if (after.environmentHash !== io.ZERO) refreshAfter = null;
      } else after.nextLink = segments[Number(after.segmentIndex)]!.segment.firstLink;
    }
  }
  io.equal(await currentEnvironment(p, d, deps, tag, cap), environment, "Archival environment changed during reconstruction");
  return { dependencies: deps, dependencyHash, inventory, segments, environment, before,
    after: bundle.normalizeScopedPolicyBundleV2Progress(after), admissions, admitted, currentObservation,
    refreshId, refreshBefore, refreshAfter, evidence, existing, initialObservationChainAuthenticated: false };
}

export async function captureScopedPolicyBundleV2(
  p: io.ReceiptReader,
  inputDeployment: ScopedPolicyBundleV2Deployment,
  inputCaller: Address,
  request: bundle.ScopedPolicyBundleV2Request,
  options: { readonly blockTag: number; readonly gasLimit: bigint; readonly segments: readonly ScopedPolicyInventoryV2SegmentLocator[] }
): Promise<ScopedPolicyBundleV2WorkflowCapture> {
  const d = deployment(inputDeployment);
  const prepared = bundle.prepareScopedPolicyBundleV2Call(coordinates(d), io.address(inputCaller), request);
  io.keys(options, ["blockTag", "gasLimit", "segments"]);
  const tag = io.number(options.blockTag);
  const cap = io.gas(options.gasLimit);
  const retained = structuredClone(options.segments);
  const observed = await io.chain(p, d.chainId, tag);
  const { deps, dependencyHash } = await bindings(p, d, tag);
  const environment = await currentEnvironment(p, d, deps, tag, cap);
  const historical = await inspectScopedPolicyInventoryV2History(p, { chainId: d.chainId, core: d.core,
    inventory: { address: deps.targets[2], codeHash: deps.codeHashes[2] } }, prepared.request.id, { blockTag: tag, segments: retained });
  if (!historical.evidence) throw Error("Original inventory is incomplete");
  const stage = await predict(p, d, prepared, deps, dependencyHash, historical.evidence, historical.segments, environment, tag, cap);
  await io.unchanged(p, observed);
  const result = { deployment: d, prepared, observed, gasLimit: cap, stage };
  return io.freeze({ ...result, captureHash: io.fingerprint(result) });
}
function savedCapture(input: ScopedPolicyBundleV2WorkflowCapture): ScopedPolicyBundleV2WorkflowCapture {
  io.keys(input, ["deployment", "prepared", "observed", "gasLimit", "stage", "captureHash"]);
  const cloned = structuredClone(input);
  const { captureHash, ...body } = cloned;
  io.equal(io.fingerprint(body), io.hash(captureHash), "Capture fingerprint differs");
  const d = deployment(body.deployment);
  const prepared = bundle.normalizeScopedPolicyBundleV2Call(body.prepared);
  io.equal(prepared.coordinates, coordinates(d), "Capture deployment/call differs");
  io.gas(body.gasLimit);
  io.number(body.observed.blockNumber);
  io.hash(body.observed.blockHash);
  io.uint(body.observed.timestamp);
  return io.freeze({ ...cloned, deployment: d, prepared });
}
function comparable(capture: ScopedPolicyBundleV2WorkflowCapture) {
  return { deployment: capture.deployment, prepared: capture.prepared, gasLimit: capture.gasLimit, stage: capture.stage };
}
async function revalidate(p: io.ReceiptReader, saved: ScopedPolicyBundleV2WorkflowCapture, tag: number) {
  await io.unchanged(p, saved.observed);
  if (tag < saved.observed.blockNumber) throw Error("Observation predates capture");
  const result = await captureScopedPolicyBundleV2(p, saved.deployment, saved.prepared.caller, saved.prepared.request,
    { blockTag: tag, gasLimit: saved.gasLimit, segments: saved.stage.segments.map(segment => segment.locator) });
  io.equal(comparable(result), comparable(saved));
  return result;
}
export async function simulateScopedPolicyBundleV2(
  p: io.ReceiptReader,
  input: ScopedPolicyBundleV2WorkflowCapture,
  options: { readonly blockTag: number; readonly gasLimit: bigint }
) {
  const saved = savedCapture(input);
  io.keys(options, ["blockTag", "gasLimit"]);
  const tag = io.number(options.blockTag);
  const cap = io.gas(options.gasLimit);
  await revalidate(p, saved, saved.observed.blockNumber);
  const current = await revalidate(p, saved, tag);
  const raw = io.bytes(await p.call({ ...current.prepared.call, from: current.prepared.caller, blockTag: tag, gasLimit: cap }));
  const kind = current.prepared.request.kind;
  const result = host().decodeFunctionResult(kind, raw);
  if (!io.same(host().encodeFunctionResult(kind, result), raw)) throw Error("Noncanonical original call result");
  if (kind === "beginRefresh") io.equal(result[0], current.stage.refreshId, "Simulated refresh identity differs");
  await io.unchanged(p, current.observed);
  return io.freeze({ capture: current, result: raw, originalCallSucceeded: true as const, gasLimit: cap, stateChangesPersisted: false as const });
}

export async function inspectScopedPolicyBundleV2History(
  p: io.ReceiptReader,
  inputDeployment: ScopedPolicyBundleV2HistoryDeployment,
  inputId: Hex,
  options: { readonly blockTag: number; readonly segments: readonly ScopedPolicyInventoryV2SegmentLocator[] }
) {
  const d = historicalDeployment(inputDeployment);
  const planId = io.hash(inputId);
  io.keys(options, ["blockTag", "segments"]);
  const tag = io.number(options.blockTag);
  const retained = structuredClone(options.segments);
  const observed = await io.chain(p, d.chainId, tag);
  const { deps, dependencyHash } = await bindings(p, d, tag);
  const historical = await inspectScopedPolicyInventoryV2History(p, {
    chainId: d.chainId, core: d.core, inventory: { address: deps.targets[2], codeHash: deps.codeHashes[2] }
  }, planId, { blockTag: tag, segments: retained });
  if (!historical.evidence) throw Error("Original inventory is incomplete");
  const progress = bundle.normalizeScopedPolicyBundleV2Progress(await read(p, d, "progress", [planId], tag));
  const admissions = await retainedAdmissions(p, d, planId, progress, historical.segments, historical.evidence.inventory.artistId, tag);
  let evidence: bundle.ScopedPolicyBundleV2Evidence | null = null;
  if (progress.complete) {
    evidence = bundle.validateScopedPolicyBundleV2Evidence(coordinates(d), dependencyHash, historical.evidence,
      await read(p, d, "bundleEvidence", [planId], tag));
    io.equal(evidence, completion(d, dependencyHash, historical.evidence, progress), "Retained bundle evidence differs");
  }
  await io.unchanged(p, observed);
  return io.freeze({ observed, planId, dependencies: deps, dependencyHash, inventory: historical.evidence,
    segments: historical.segments, progress, admissions, evidence, currentEnvironmentChecked: false as const,
    inventoryCurrentSourceChecked: false as const, initialObservationChainAuthenticated: false as const });
}

function completedRefresh(
  refresh: bundle.ScopedPolicyBundleV2Refresh,
  environment: Hex,
  itemCount: bigint
): void {
  if (refresh.environmentHash !== environment || !refresh.complete || refresh.nextIndex !== itemCount
    || refresh.currentObservationChain === io.ZERO) throw Error("Missing or malformed completed environment refresh");
}

export async function inspectScopedPolicyBundleV2Current(
  p: io.ReceiptReader,
  inputDeployment: ScopedPolicyBundleV2Deployment,
  inputId: Hex,
  options: {
    readonly blockTag: number;
    readonly gasLimit: bigint;
    readonly segments: readonly ScopedPolicyInventoryV2SegmentLocator[];
    readonly fullCurrentCoverage?: boolean;
  }
) {
  io.keys(options, ["blockTag", "gasLimit", "segments"], ["fullCurrentCoverage"]);
  if (options.fullCurrentCoverage !== undefined && typeof options.fullCurrentCoverage !== "boolean") throw Error("Expected diagnostic flag");
  const full = options.fullCurrentCoverage === true;
  const d = deployment(inputDeployment);
  const planId = io.hash(inputId);
  const tag = io.number(options.blockTag);
  const cap = io.gas(options.gasLimit);
  const capture = await captureScopedPolicyBundleV2(p, d, d.bundle.address, { kind: "beginCoverage", id: planId },
    { blockTag: tag, gasLimit: cap, segments: options.segments });
  const stage = capture.stage;
  if (!stage.evidence || !stage.before.complete) throw Error("Bundle coverage is incomplete");
  completedRefresh(stage.refreshBefore, stage.environment.hash, stage.inventory.inventory.itemCount);
  const result = bundle.validateScopedPolicyBundleV2Evidence(coordinates(d), stage.dependencyHash, stage.inventory,
    await io.read(p, d.bundle.address, host(), "requireCoverage",
      [stage.inventory.scope, planId, stage.evidence.coverage.renderCriticalEvidenceHash], tag, undefined, cap));
  io.equal(result, stage.evidence, "Current bundle evidence differs");
  if (full) {
    const diagnostic = await io.read(p, d.bundle.address, host(), "requireFullCurrentCoverage", [planId], tag, undefined, cap);
    io.equal(diagnostic, stage.evidence, "Full current coverage differs");
  }
  await io.unchanged(p, capture.observed);
  return io.freeze({ capture, evidence: result, refresh: stage.refreshBefore, currentEnvironmentChecked: true as const,
    fullCurrentCoverageChecked: full, inventoryCurrentSourceChecked: false as const, initialObservationChainAuthenticated: false as const });
}

export async function reconcileScopedPolicyBundleV2Receipt(
  p: io.ReceiptReader,
  input: ScopedPolicyBundleV2WorkflowCapture,
  inputHash: Hex,
  options: ScopedPolicyBundleV2ReceiptOptions
) {
  const saved = savedCapture(input);
  const tx = await io.transport(p, { chainId: saved.deployment.chainId, caller: saved.prepared.caller,
    call: saved.prepared.call, observed: saved.observed }, io.hash(inputHash), options);
  await revalidate(p, saved, saved.observed.blockNumber);
  const prior = await revalidate(p, saved, tx.observed.blockNumber - 1);
  const d = prior.deployment;
  const stage = prior.stage;
  const planId = prior.prepared.request.id;
  const tag = tx.observed.blockNumber;
  await io.runtime(p, d.bundle, tag);
  await io.runtimes(p, [d.archiveReader, ...d.linkedDependencies], tag);
  io.equal(bundle.normalizeScopedPolicyBundleV2Progress(await read(p, d, "progress", [planId], tag)), stage.after,
    "Receipt end-block progress differs; concurrent progress is not attributed");
  const starts = io.events(tx.logs, d.bundle.address, host(), "ScopedBundleCoverageStarted");
  const items = io.events(tx.logs, d.bundle.address, host(), "ScopedBundleItemAdmitted");
  const completes = io.events(tx.logs, d.bundle.address, host(), "ScopedBundleCoverageCompleted");
  const advances = io.events(tx.logs, d.bundle.address, host(), "ScopedBundleRefreshAdvanced");
  const kind = prior.prepared.request.kind;
  let itemIndex = -1;
  if (kind === "beginCoverage") {
    if (starts.length !== (stage.existing ? 0 : 1) || items.length || completes.length || advances.length) {
      throw Error("Unexpected bundle begin events");
    }
    if (!stage.existing) io.one(tx.logs, d.bundle.address, host(), "ScopedBundleCoverageStarted",
      [2n, planId, stage.inventory.inventory.renderCriticalEvidenceHash]);
  } else if (kind === "beginRefresh") {
    if (starts.length || items.length || completes.length || advances.length) throw Error("Unexpected refresh begin events");
  } else if (kind === "refreshNext") {
    if (starts.length || items.length || completes.length) throw Error("Unexpected refresh advancement events");
    io.one(tx.logs, d.bundle.address, host(), "ScopedBundleRefreshAdvanced",
      [2n, planId, stage.refreshId, stage.refreshAfter!.nextIndex, stage.refreshAfter!.currentObservationChain, stage.refreshAfter!.complete]);
  } else {
    if (starts.length || advances.length || items.length !== (kind === "coverNext" ? 1 : 0)
      || completes.length !== (stage.after.complete ? 1 : 0)) throw Error("Unexpected bundle admission events");
    if (stage.admitted) {
      itemIndex = io.one(tx.logs, d.bundle.address, host(), "ScopedBundleItemAdmitted", [2n, planId, stage.before.itemCount,
        inv.scopedPolicyInventoryV2ItemHash(stage.admitted.item), stage.admitted.admission]).index;
      const values = await io.rpc(p, d.bundle.address, host(), "admittedItem", [planId, stage.before.itemCount], tag);
      io.equal(values, [stage.admitted.item, stage.admitted.admission], "Retained new Item/Admission differs");
    }
    if (stage.after.complete) {
      const event = io.one(tx.logs, d.bundle.address, host(), "ScopedBundleCoverageCompleted",
        [2n, planId, stage.evidence!.coverage.bundleCoverageHash, stage.evidence]);
      if (event.index <= itemIndex) throw Error("Coverage completion precedes admission");
    }
  }
  if (stage.evidence) io.equal(await read(p, d, "bundleEvidence", [planId], tag), stage.evidence, "Retained completion differs");
  const refresh = bundle.normalizeScopedPolicyBundleV2Refresh(await read(p, d, "refresh", [stage.refreshId], tag));
  if (stage.refreshAfter) io.equal(refresh, stage.refreshAfter, "Receipt end-block refresh differs");
  else completedRefresh(refresh, stage.environment.hash, stage.inventory.inventory.itemCount);
  io.finish(tx.logs, [d.bundle.address], tx.safeIndex);
  await io.unchanged(p, tx.observed);
  return io.freeze({ observed: tx.observed, transactionHash: tx.transactionHash, planId, progress: stage.after,
    admitted: stage.admitted, evidence: stage.evidence, refreshId: stage.refreshId, refresh,
    initialObservationChainAuthenticated: false as const,
    refreshStepChainAuthenticated: kind === "refreshNext", precedingAndEndBlockAttribution: true as const,
    currentAfterReceipt: false as const });
}

export async function observeScopedPolicyBundleV2Refusal(
  p: io.ReceiptReader,
  input: ScopedPolicyBundleV2WorkflowCapture,
  options: { readonly blockTag: number; readonly gasLimit: bigint }
) {
  const saved = savedCapture(input);
  io.keys(options, ["blockTag", "gasLimit"]);
  const tag = io.number(options.blockTag);
  const cap = io.gas(options.gasLimit);
  await revalidate(p, saved, saved.observed.blockNumber);
  if (tag < saved.observed.blockNumber) throw Error("Refusal predates capture");
  const observed = await io.chain(p, saved.deployment.chainId, tag);
  await io.runtime(p, saved.deployment.bundle, tag);
  const local = async () => ({ progress: await read(p, saved.deployment, "progress", [saved.prepared.request.id], tag),
    refresh: await read(p, saved.deployment, "refresh", [saved.stage.refreshId], tag) });
  const before = await local();
  let error: unknown;
  try { await p.call({ ...saved.prepared.call, from: saved.prepared.caller, blockTag: tag, gasLimit: cap }); }
  catch (failure) { error = failure; }
  if (error === undefined) throw Error("Original call did not refuse");
  const after = await local();
  await io.unchanged(p, observed);
  return { observed, error, outcome: (error as { code?: string })?.code === "CALL_EXCEPTION" ? "execution-reverted" as const : "rpc-failed" as const,
    retainedStateUnchanged: io.stable(before) === io.stable(after), rollbackProven: false as const };
}
