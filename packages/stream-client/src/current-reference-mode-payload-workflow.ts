import { AbiCoder, Interface, ZeroAddress, ZeroHash, getAddress, id, isHexString, keccak256, toQuantity } from "ethers";
import type { Provider } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import type { UnsignedCall } from "./client.js";
import {
  CURRENT_REFERENCE_MODE_PAYLOAD_ABI, prepareReferenceModePublication,
  normalizeReferenceModeEvidence, normalizeReferenceModePayloadSnapshot,
  decodeReferenceModePayload, prepareReferenceModePublicationCall, prepareReferenceModePayloadCall
} from "./current-reference-mode-payload.js";
import type { ReferenceModePublication, ReferenceModeEvidence, ReferenceModePayloadSnapshot } from "./current-reference-mode-payload.js";
import { prepareReferenceEnvironmentPlan } from "./current-reference-environment-workflow.js";
import type {
  ReferenceInventoryDeployment, ReferenceInventoryCodePin, ReferenceInventoryChunk,
  ReferenceInventoryChunkAvailability, ReferenceInventoryStepStatus,
  ReferenceInventoryGasProvider, ReferenceInventoryEventReference
} from "./current-reference-inventory-workflow.js";

export interface ReferenceModeDependencies {
  readonly targets: readonly Address[];
  readonly codeHashes: readonly Hex[];
  readonly chainId: bigint;
  readonly rendererCatalogId: Hex;
  readonly rendererCatalogHash: Hex;
  readonly rendererCatalogBytes: bigint;
  readonly readGas: bigint;
  readonly sourceGas: bigint;
  readonly snapshotGas: bigint;
  readonly archiveGas: bigint;
}
export interface ReferenceModeBindings {
  readonly attestations: Address; readonly attestationsCodeHash: Hex;
  readonly conservation: Address; readonly conservationCodeHash: Hex;
}
export interface ReferenceModePreview {
  readonly deployment: ReferenceInventoryDeployment;
  readonly recorder: Address;
  readonly submitted: { readonly publication: ReferenceModePublication; readonly evidence: ReferenceModeEvidence };
  readonly snapshot: ReferenceModePayloadSnapshot;
  readonly dependencies: ReferenceModeDependencies;
  readonly modeBindings: ReferenceModeBindings;
  readonly authority: { readonly authorizationClass: 3n | 8n; readonly grantRevision: bigint };
  readonly blockNumber: number; readonly blockHash: Hex;
  readonly previewCall: UnsignedCall;
  /** Original full arguments, without preparation IDs. This is not a successful publication. */
  readonly publishCall: UnsignedCall;
  readonly publicationSimulationRequired: true;
}
export interface ReferenceModePayloadStep {
  readonly index: number; readonly kind: "upload" | "publication" | "payload";
  readonly caller: Address; readonly call: UnsignedCall; readonly identity: Hex;
  readonly chunkIndex: number | null;
}
export interface ReferenceModePayloadChunk extends ReferenceInventoryChunk {
  readonly documents: readonly ("publication" | "payload")[];
}
export interface PreparedReferenceModePayloadPlan {
  readonly deployment: ReferenceInventoryDeployment;
  readonly preparer: Address; readonly uploader: Address;
  readonly snapshot: ReferenceModePayloadSnapshot;
  readonly chunks: readonly ReferenceModePayloadChunk[];
  readonly steps: readonly ReferenceModePayloadStep[];
}
export interface ReferenceModePayloadInspection {
  readonly plan: PreparedReferenceModePayloadPlan;
  readonly blockNumber: number; readonly blockHash: Hex;
  readonly completed: boolean;
  readonly retained: { readonly environment: boolean; readonly publication: boolean; readonly payload: boolean };
  readonly chunkAvailability: readonly ReferenceInventoryChunkAvailability[];
  readonly steps: readonly ReferenceInventoryStepStatus[];
}
export interface ReferenceModePayloadGasQuote {
  readonly inspection: ReferenceModePayloadInspection; readonly step: ReferenceModePayloadStep;
  readonly scope: "inner-call"; readonly estimatedGas: bigint;
  readonly maximumGas: bigint | null; readonly withinMaximum: boolean;
}
export interface ReferenceModePayloadStepReceipt {
  readonly plan: PreparedReferenceModePayloadPlan; readonly step: ReferenceModePayloadStep;
  readonly transactionHash: Hex; readonly blockNumber: number; readonly blockHash: Hex;
  readonly identity: Hex; readonly retention: "created" | "reused";
  readonly events: readonly ReferenceInventoryEventReference[];
  readonly priorBlock: { readonly number: number; readonly hash: Hex; readonly retained: boolean };
}
type Reader = Pick<Provider, "getNetwork" | "getBlock" | "getCode" | "call">;
type ReceiptReader = Reader & Pick<Provider, "getTransaction" | "getTransactionReceipt">;
const coder = AbiCoder.defaultAbiCoder();
const preparationAbi = new Interface(CURRENT_REFERENCE_MODE_PAYLOAD_ABI);
const publicationTuple = preparationAbi.getFunction("prepareModePublication")!.inputs[0]!;
const payloadInputs = preparationAbi.getFunction("prepareModePayload")!.inputs;
const dependenciesTuple = "(address[7] targets,bytes32[7] codeHashes,uint256 chainId,bytes32 rendererCatalogId,bytes32 rendererCatalogHash,uint32 rendererCatalogBytes,uint256 readGas,uint256 sourceGas,uint256 snapshotGas,uint256 archiveGas)";
const modeBindingsTuple = "(address attestations,bytes32 attestationsCodeHash,address conservation,bytes32 conservationCodeHash)";
const hostAbi = new Interface([
  ...CURRENT_REFERENCE_MODE_PAYLOAD_ABI,
  `function previewModeReference(${publicationTuple.format("full")},${payloadInputs[3]!.format("full")},address recorder) view returns(bytes32 sourceHash,bytes canonical)`,
  `function publishModeReference(${publicationTuple.format("full")},${payloadInputs[3]!.format("full")}) returns(bytes32)`,
  `function dependencies() view returns(${dependenciesTuple})`,
  `function modeDependencies() view returns(${modeBindingsTuple})`,
  "function deploymentChainId() view returns(uint256)", "function core() view returns(address)",
  "function metadataHost() view returns(address)", "function metadataRouter() view returns(address)",
  "function snapshots() view returns(address)", "function archiveCoverage() view returns(address)",
  "function preparedFileInventory(bytes32) view returns(bytes)",
  "function supportsInterface(bytes4) pure returns(bool)"
]);
const metadataAbi = new Interface(["function familyWriter(uint256,bytes32,uint8,address) view returns(bool enabled,uint64 revision)"]);
const storeAbi = new Interface([
  "function MAX_CHUNK_BYTES() view returns(uint256)",
  "function chunk(bytes32) view returns(address pointer,uint32 length)",
  "function publishChunk(bytes) returns(bytes32 hash,address pointer)",
  "event ChunkPublished(bytes32 indexed hash,address indexed pointer,uint32 length)"
]);
const safeAbi = new Interface(["function execTransaction(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,bytes signatures) returns(bool)"]);
const safeLegacy = new Interface(["event ExecutionSuccess(bytes32 txHash,uint256 payment)", "event ExecutionFailure(bytes32 txHash,uint256 payment)"]);
const safeIndexed = new Interface(["event ExecutionSuccess(bytes32 indexed txHash,uint256 payment)", "event ExecutionFailure(bytes32 indexed txHash,uint256 payment)"]);
const MAX_BYTES = 524288, MAX_RPC = MAX_BYTES + 4096, MAX_CALL = 2000000;
const invalidMode = id("InvalidModeEvidence()").slice(0, 10);
const invalidManifest = id("InvalidSnapshotManifest()").slice(0, 10);

function address(v: unknown, zero = false): Address {
  if (typeof v !== "string") throw Error("Expected address");
  const a = getAddress(v) as Address;
  if (!zero && a === ZeroAddress) throw Error("Zero address");
  return a;
}
function hash(v: unknown, zero = false): Hex {
  if (typeof v !== "string" || !isHexString(v, 32) || (!zero && /^0x0{64}$/i.test(v))) throw Error("Expected bytes32");
  return v.toLowerCase() as Hex;
}
function bytes(v: unknown, maximum = MAX_RPC): Hex {
  if (typeof v !== "string" || !isHexString(v, true) || (v.length - 2) / 2 > maximum) throw Error("Malformed/oversized bytes");
  return v.toLowerCase() as Hex;
}
function uint(v: unknown, positive = false): bigint {
  if (typeof v !== "bigint" || v < (positive ? 1n : 0n) || v >= 1n << 256n) throw Error("Expected uint256 bigint");
  return v;
}
function integer(v: number): number {
  if (!Number.isSafeInteger(v) || v < 0) throw Error("Expected concrete block/index");
  return v;
}
function same(a: unknown, b: unknown): boolean {
  return typeof a === "string" && typeof b === "string" && a.toLowerCase() === b.toLowerCase();
}
function stable(v: unknown): string {
  if (v === null) return '["null"]';
  if (typeof v === "string" || typeof v === "boolean") return JSON.stringify([typeof v, v]);
  if (typeof v === "bigint") return JSON.stringify(["bigint", v.toString()]);
  if (typeof v === "number" && Number.isSafeInteger(v)) return JSON.stringify(["number", v]);
  if (Array.isArray(v)) return JSON.stringify(["array", v.map(stable)]);
  if (v && typeof v === "object") return JSON.stringify(["object", Object.entries(v).sort(([a], [b]) => a.localeCompare(b)).map(([k, x]) => [k, stable(x)])]);
  throw Error("Unsupported observation value");
}
function equal(a: unknown, b: unknown, message = "Prepared Mode plan differs from canonical reconstruction"): void {
  if (stable(a) !== stable(b)) throw Error(message);
}
function keys(v: unknown, names: readonly string[]): void {
  if (!v || typeof v !== "object" || Array.isArray(v) || Object.keys(v).sort().join() !== [...names].sort().join()) throw Error("Missing/unknown properties");
}
function freeze<T>(v: T): T {
  if (v && typeof v === "object") { Object.values(v).forEach(freeze); Object.freeze(v); }
  return v;
}
function call(to: Address, abi: Interface, name: string, args: readonly unknown[]): UnsignedCall {
  return freeze({ to, value: 0n, data: abi.encodeFunctionData(name, args) as Hex });
}
async function rpc(p: Pick<Provider, "call">, target: Address, abi: Interface, name: string,
  args: readonly unknown[], tag: number, from?: Address): Promise<any> {
  const raw = bytes(await p.call({ ...call(target, abi, name, args), blockTag: tag, ...(from ? { from } : {}) }));
  const result = abi.decodeFunctionResult(name, raw);
  if (!same(abi.encodeFunctionResult(name, result), raw)) throw Error(`Noncanonical ${name} return`);
  return result;
}
async function header(p: Pick<Provider, "getBlock">, tag: number): Promise<{ number: number; hash: Hex }> {
  const b = await p.getBlock(tag);
  if (!b || b.number !== tag) throw Error("Missing/mismatched block");
  return { number: tag, hash: hash(b.hash) };
}
async function unchanged(p: Pick<Provider, "getBlock">, h: { number: number; hash: Hex }): Promise<void> {
  equal(await header(p, h.number), h, "Pinned block changed");
}
async function runtime(p: Reader, pin: ReferenceInventoryCodePin, tag: number): Promise<void> {
  const code = bytes(await p.getCode(pin.address, tag), 65536);
  if (code === "0x" || (code.length === 48 && code.startsWith("0xef0100")) || !same(keccak256(code), pin.codeHash)) throw Error("Pinned Mode dependency runtime differs");
}
async function context(p: Reader, d: ReferenceInventoryDeployment, tag: number) {
  if ((await p.getNetwork()).chainId !== d.chainId) throw Error("RPC chain mismatch");
  const h = await header(p, tag);
  await Promise.all([d.publicationHost, d.store].map(pin => runtime(p, pin, tag)));
  const [[chain], [raw], [max], [supported]] = await Promise.all([
    rpc(p, d.publicationHost.address, hostAbi, "deploymentChainId", [], tag),
    rpc(p, d.publicationHost.address, hostAbi, "dependencies", [], tag),
    rpc(p, d.store.address, storeAbi, "MAX_CHUNK_BYTES", [], tag),
    rpc(p, d.publicationHost.address, hostAbi, "supportsInterface", ["0x3092a6e0"], tag)
  ]);
  const dependencies: ReferenceModeDependencies = {
    targets: Array.from(raw.targets, v => address(v, true)), codeHashes: Array.from(raw.codeHashes, v => hash(v, true)),
    chainId: raw.chainId, rendererCatalogId: raw.rendererCatalogId, rendererCatalogHash: raw.rendererCatalogHash,
    rendererCatalogBytes: raw.rendererCatalogBytes, readGas: raw.readGas, sourceGas: raw.sourceGas,
    snapshotGas: raw.snapshotGas, archiveGas: raw.archiveGas
  };
  if (chain !== d.chainId || dependencies.chainId !== d.chainId || !same(dependencies.targets[3], d.store.address)
    || !same(dependencies.codeHashes[3], d.store.codeHash) || max !== 8192n || supported !== true) {
    throw Error("Host/Store chain, dependency or Mode preparation capability differs");
  }
  return { header: h, dependencies };
}

/** Calls the original preview for the intended recorder. Preparation itself accepts no live authority. */
export async function captureReferenceModePreview(p: Reader, deployment: ReferenceInventoryDeployment,
  recorder: Address, publication: ReferenceModePublication, evidence: ReferenceModeEvidence,
  options: { readonly blockTag: number }): Promise<ReferenceModePreview> {
  keys(options, ["blockTag"]);
  const submittedPublication = prepareReferenceModePublication(deployment.chainId, deployment.publicationHost.address, publication);
  const actor = address(recorder), submittedEvidence = normalizeReferenceModeEvidence(evidence), tag = integer(options.blockTag);
  if (submittedEvidence.mode !== 1n && submittedEvidence.mode !== 2n) throw Error("Original preview requires an explicit supported Mode");
  const d = prepareReferenceEnvironmentPlan(deployment, actor, submittedPublication.environment).deployment;
  const { header: h, dependencies } = await context(p, d, tag);
  await Promise.all(dependencies.targets.map((target, index) => runtime(p, {
    address: address(target), codeHash: hash(dependencies.codeHashes[index])
  }, tag)));
  const names = ["core", "metadataHost", "metadataRouter", "snapshots", "archiveCoverage"] as const;
  const indices = [0, 1, 4, 5, 6];
  for (let i = 0; i < names.length; i++) {
    if (!same((await rpc(p, d.publicationHost.address, hostAbi, names[i]!, [], tag))[0], dependencies.targets[indices[i]!])) throw Error("Host native dependency binding differs");
  }
  const [rawBindings] = await rpc(p, d.publicationHost.address, hostAbi, "modeDependencies", [], tag);
  const modeBindings: ReferenceModeBindings = {
    attestations: address(rawBindings.attestations, true), attestationsCodeHash: hash(rawBindings.attestationsCodeHash, true),
    conservation: address(rawBindings.conservation, true), conservationCodeHash: hash(rawBindings.conservationCodeHash, true)
  };
  if (submittedEvidence.mode === 2n) {
    await Promise.all([
      runtime(p, { address: address(modeBindings.attestations), codeHash: hash(modeBindings.attestationsCodeHash) }, tag),
      runtime(p, { address: address(modeBindings.conservation), codeHash: hash(modeBindings.conservationCodeHash) }, tag)
    ]);
  }
  let authority: ReferenceModePreview["authority"] | undefined;
  for (const authorizationClass of [3n, 8n] as const) {
    const [enabled, revision] = await rpc(p, dependencies.targets[1]!, metadataAbi, "familyWriter",
      [authorizationClass === 3n ? submittedPublication.publication.collectionId : 0n, id("6529STREAM_RECORD_FAMILY_CURATOR_V1"), authorizationClass, actor], tag);
    if (enabled && revision !== 0n) { authority = { authorizationClass, grantRevision: revision }; break; }
  }
  if (!authority) throw Error("Intended recorder has no original curator authority");
  const previewCall = call(d.publicationHost.address, hostAbi, "previewModeReference", [submittedPublication.publication, submittedEvidence, actor]);
  const [sourceHash, raw] = await rpc(p, d.publicationHost.address, hostAbi, "previewModeReference",
    [submittedPublication.publication, submittedEvidence, actor], tag, actor);
  const snapshot = decodeReferenceModePayload(d.chainId, d.publicationHost.address, bytes(raw, MAX_BYTES));
  equal(snapshot.publication.publication, { ...submittedPublication.publication, expectedSourcesHash: hash(sourceHash) }, "Preview changed original publication fields");
  equal(snapshot.input.evidence, submittedEvidence, "Preview changed original Mode evidence");
  const receipt = snapshot.input.receipt, returned = snapshot.publication.publication;
  if (receipt.collectionId !== returned.collectionId || !same(receipt.referenceId, returned.referenceId)
    || !same(receipt.predecessor, returned.expectedHead) || receipt.revision !== returned.expectedRevision + 1n
    || !same(receipt.sourcesHash, sourceHash) || !same(receipt.snapshotRecordHash, returned.snapshotRecordHash)
    || receipt.snapshotRevision !== returned.snapshotRevision || !same(receipt.recorder, actor)
    || receipt.authorizationClass !== authority.authorizationClass || receipt.grantRevision !== authority.grantRevision
    || receipt.effectiveAt !== returned.effectiveAt || !same(receipt.reasonHash, returned.reasonHash)
    || !same(receipt.schemaHash, "0x402d40d87298b197ea58e46ca8cae1346a5391e991331874280fbc4cc039f857")
    || !same(receipt.profileHash, "0x666e39adf842bca06d06a63b2d92b363dad05e95bad2d0be7fe4ebc17d757f8c")
    || !same(receipt.canonicalizationHash, "0x88c5f5a1b04f40ebae17a2c6f85ba5cd88c32d9139a809f0a1b209afbe15e883")) throw Error("Preview receipt differs from original recorder and publication");
  const expectedSourceHash = keccak256(coder.encode([
    "bytes32", "uint256", "address", "address[7]", "bytes32[7]", "bytes32", "bytes32", modeBindingsTuple,
    payloadInputs[2]!, payloadInputs[4]!
  ], [id("6529STREAM_REFERENCE_MODE_SOURCES_V1"), d.chainId, d.publicationHost.address,
    dependencies.targets, dependencies.codeHashes, dependencies.rendererCatalogId, dependencies.rendererCatalogHash,
    modeBindings, snapshot.input.source, snapshot.input.facts]));
  if (!same(sourceHash, expectedSourceHash) || snapshot.input.facts.mode !== submittedEvidence.mode
    || !same(snapshot.input.facts.evidenceHash, keccak256(coder.encode([payloadInputs[3]!], [submittedEvidence])))) throw Error("Preview source/evidence identity differs");
  await unchanged(p, h);
  return freeze({ deployment: d, recorder: actor, submitted: { publication: submittedPublication.publication, evidence: submittedEvidence },
    snapshot, dependencies, modeBindings, authority, blockNumber: tag, blockHash: h.hash, previewCall,
    publishCall: call(d.publicationHost.address, hostAbi, "publishModeReference", [returned, submittedEvidence]), publicationSimulationRequired: true });
}

/** Environment/inventory prerequisites remain separate original plans. These steps only retain Mode bytes. */
export function prepareReferenceModePayloadPlan(deployment: ReferenceInventoryDeployment, preparer: Address,
  input: ReferenceModePayloadSnapshot, options: { readonly uploader?: Address } = {}): PreparedReferenceModePayloadPlan {
  keys(options, options.uploader === undefined ? [] : ["uploader"]);
  const snapshot = normalizeReferenceModePayloadSnapshot(input), actor = address(preparer), uploader = address(options.uploader ?? actor);
  const d = prepareReferenceEnvironmentPlan(deployment, actor, snapshot.publication.environment).deployment;
  if (snapshot.publication.chainId !== d.chainId || !same(snapshot.publication.publicationHost, d.publicationHost.address)) throw Error("Mode snapshot coordinates differ");
  const chunks: { index: number; hash: Hex; bytes: Hex; documents: ("publication" | "payload")[] }[] = [];
  for (const [document, canonical] of [["publication", snapshot.publication.canonical], ["payload", snapshot.canonical]] as const) {
    for (let offset = 2; offset < canonical.length; offset += 16384) {
      const raw = `0x${canonical.slice(offset, offset + 16384)}` as Hex, identity = keccak256(raw) as Hex;
      const existing = chunks.find(c => c.hash === identity);
      if (existing) { if (!existing.documents.includes(document)) existing.documents.push(document); }
      else chunks.push({ index: chunks.length, hash: identity, bytes: raw, documents: [document] });
    }
  }
  const steps: ReferenceModePayloadStep[] = chunks.map(c => ({ index: c.index, kind: "upload", caller: uploader,
    call: call(d.store.address, storeAbi, "publishChunk", [c.bytes]), identity: c.hash, chunkIndex: c.index }));
  for (const prepared of [prepareReferenceModePublicationCall(snapshot.publication, actor), prepareReferenceModePayloadCall(snapshot, actor)]) {
    steps.push({ index: steps.length, kind: prepared.kind, caller: actor, call: prepared.call, identity: prepared.identity, chunkIndex: null });
  }
  return freeze({ deployment: d, preparer: actor, uploader, snapshot, chunks, steps });
}
function plan(v: PreparedReferenceModePayloadPlan): PreparedReferenceModePayloadPlan {
  const result = prepareReferenceModePayloadPlan(v.deployment, v.preparer, v.snapshot, { uploader: v.uploader });
  equal(v, result);
  return result;
}
function step(p: PreparedReferenceModePayloadPlan, index: number): ReferenceModePayloadStep {
  integer(index);
  const result = p.steps[index];
  if (!result) throw Error("Step outside plan");
  return result;
}
async function optionalRead(p: Reader, d: ReferenceInventoryDeployment, method: string, identity: Hex, tag: number): Promise<any | null> {
  try { return await rpc(p, d.publicationHost.address, hostAbi, method, [identity], tag); }
  catch (error) {
    const e = error as { code?: unknown; data?: unknown };
    if (e.code === "CALL_EXCEPTION" && same(e.data, method === "preparedModePublication" ? invalidMode : invalidManifest)) return null;
    throw error;
  }
}
async function retained(p: Reader, plan: PreparedReferenceModePayloadPlan, kind: "environment" | "publication" | "payload", tag: number): Promise<boolean> {
  const s = plan.snapshot;
  const method = kind === "environment" ? "preparedFileInventory" : kind === "publication" ? "preparedModePublication" : "preparedModePayload";
  const identity = kind === "environment" ? s.publication.environment.environmentId : kind === "publication" ? s.publication.publicationPreparationId : s.payloadPreparationId;
  const expected = kind === "environment" ? s.publication.environment.canonical : kind === "publication" ? s.publication.canonical : s.canonical;
  const result = await optionalRead(p, plan.deployment, method, identity, tag);
  if (result === null) return false;
  if (!same(bytes(result[kind === "publication" ? 1 : 0], MAX_BYTES), expected)) throw Error("Retained Mode/Environment bytes differ");
  if (kind === "publication" && !same(coder.encode([preparationAbi.getFunction("preparedModePublication")!.outputs[0]!], [result[0]]),
    coder.encode([preparationAbi.getFunction("preparedModePublication")!.outputs[0]!], [s.publication.descriptor]))) throw Error("Retained publication descriptor differs");
  return true;
}
async function availability(p: Reader, d: ReferenceInventoryDeployment, chunk: ReferenceModePayloadChunk, tag: number): Promise<ReferenceInventoryChunkAvailability> {
  const [target, length] = await rpc(p, d.store.address, storeAbi, "chunk", [chunk.hash], tag);
  const pointer = address(target, true), byteLength = uint(length);
  if (pointer === ZeroAddress) {
    if (byteLength !== 0n) throw Error("Missing chunk has nonzero length");
    return { index: chunk.index, hash: chunk.hash, available: false, pointer, byteLength };
  }
  if (byteLength !== BigInt((chunk.bytes.length - 2) / 2)
    || !same(bytes(await p.getCode(pointer, tag), 8193), `0x00${chunk.bytes.slice(2)}`)) throw Error("Store chunk is not exact STOP plus original bytes");
  return { index: chunk.index, hash: chunk.hash, available: true, pointer, byteLength };
}
export async function inspectReferenceModePayloadPreparation(p: Reader, input: PreparedReferenceModePayloadPlan,
  options: { readonly blockTag: number }): Promise<ReferenceModePayloadInspection> {
  keys(options, ["blockTag"]);
  const planned = plan(input), tag = integer(options.blockTag), { header: h } = await context(p, planned.deployment, tag);
  const environment = await retained(p, planned, "environment", tag), publication = await retained(p, planned, "publication", tag), payload = await retained(p, planned, "payload", tag);
  if ((publication && !environment) || (payload && !publication)) throw Error("Retained Mode dependency is missing");
  const chunks: ReferenceInventoryChunkAvailability[] = [];
  if (!payload) for (const chunk of planned.chunks) chunks.push(await availability(p, planned.deployment, chunk, tag));
  const uploaded = (document: "publication" | "payload") => planned.chunks.every(c => !c.documents.includes(document) || chunks[c.index]?.available);
  const steps = planned.steps.map(s => {
    let status: ReferenceInventoryStepStatus["status"], reason: string;
    if (s.kind === "upload") {
      const unnecessary = payload || (publication && planned.chunks[s.chunkIndex!]!.documents.every(d => d === "publication"));
      status = unnecessary ? "unnecessary" : chunks[s.chunkIndex!]!.available ? "complete" : "ready";
      reason = unnecessary ? "Original document already retained; upload history not inferred" : "Exact Store chunk availability inspected";
    } else {
      const complete = s.kind === "publication" ? publication : payload;
      const ready = environment && (s.kind === "publication" || publication) && uploaded(s.kind);
      status = complete ? "complete" : ready ? "ready" : "blocked";
      reason = complete ? "Exact original bytes and prerequisite retention verified" : ready ? "Prerequisite retention and chunks available" : "Environment, publication or required chunks unavailable";
    }
    return { index: s.index, status, reason };
  });
  await unchanged(p, h);
  return freeze({ plan: planned, blockNumber: tag, blockHash: h.hash, completed: payload,
    retained: { environment, publication, payload }, chunkAvailability: chunks, steps });
}
async function executable(p: Reader, planned: PreparedReferenceModePayloadPlan, index: number, tag: number): Promise<ReferenceModePayloadInspection> {
  step(planned, index);
  const inspected = await inspectReferenceModePayloadPreparation(p, planned, { blockTag: tag });
  if (["blocked", "unnecessary"].includes(inspected.steps[index]!.status)) throw Error("Step is blocked or unnecessary at pinned block");
  return inspected;
}
async function simulation(p: Reader, inspection: ReferenceModePayloadInspection, s: ReferenceModePayloadStep, tag: number) {
  const abi = s.kind === "upload" ? storeAbi : hostAbi;
  const method = s.kind === "upload" ? "publishChunk" : s.kind === "publication" ? "prepareModePublication" : "prepareModePayload";
  const result = await rpc(p, s.call.to, abi, method, Array.from(abi.decodeFunctionData(method, s.call.data)), tag, s.caller);
  if (!same(result[0], s.identity)) throw Error("Simulated preparation identity differs");
  const pointer = s.kind === "upload" ? address(result[1]) : null;
  const observed = s.kind === "upload" ? inspection.chunkAvailability[s.chunkIndex!] : undefined;
  if (observed?.available && !same(observed.pointer, pointer)) throw Error("Simulated retained chunk pointer differs");
  return freeze({ identity: s.identity, pointer });
}
export async function simulateReferenceModePayloadStep(p: Reader, input: PreparedReferenceModePayloadPlan, stepIndex: number,
  options: { readonly blockTag: number }): Promise<{ readonly identity: Hex; readonly pointer: Address | null }> {
  keys(options, ["blockTag"]);
  const planned = plan(input), s = step(planned, stepIndex), tag = integer(options.blockTag), inspected = await executable(p, planned, stepIndex, tag);
  const result = await simulation(p, inspected, s, tag);
  await unchanged(p, { number: tag, hash: inspected.blockHash });
  return result;
}
/** Quotes only the actual-caller preparation CALL, excluding the Safe envelope and final publication. */
export async function quoteReferenceModePayloadStepGas(p: ReferenceInventoryGasProvider, input: PreparedReferenceModePayloadPlan,
  stepIndex: number, options: { readonly blockTag: number; readonly maximumGas?: bigint }): Promise<ReferenceModePayloadGasQuote> {
  keys(options, options.maximumGas === undefined ? ["blockTag"] : ["blockTag", "maximumGas"]);
  const planned = plan(input), s = step(planned, stepIndex), tag = integer(options.blockTag);
  const maximumGas = options.maximumGas === undefined ? null : uint(options.maximumGas, true);
  const inspected = await executable(p, planned, stepIndex, tag);
  await simulation(p, inspected, s, tag);
  const raw = await p.send("eth_estimateGas", [{ from: s.caller, to: s.call.to, data: s.call.data, value: "0x0" }, toQuantity(tag)]);
  if (typeof raw !== "string" || !/^0x[1-9a-f][0-9a-f]*$/.test(raw) || raw.length > 66) throw Error("Noncanonical gas estimate quantity");
  const estimatedGas = uint(BigInt(raw), true);
  await unchanged(p, { number: tag, hash: inspected.blockHash });
  return freeze({ inspection: inspected, step: s, scope: "inner-call", estimatedGas, maximumGas, withinMaximum: maximumGas === null || estimatedGas <= maximumGas });
}

/** Verifies one original preparation CALL; this does not attest a final reference publication. */
export async function inspectReferenceModePayloadStepReceipt(p: ReceiptReader, input: PreparedReferenceModePayloadPlan,
  stepIndex: number, evidence: { readonly transactionHash: Hex; readonly execution: "direct" | "safe" }): Promise<ReferenceModePayloadStepReceipt> {
  keys(evidence, ["transactionHash", "execution"]);
  const planned = plan(input), s = step(planned, stepIndex), d = planned.deployment;
  const transactionHash = hash(evidence.transactionHash), execution = evidence.execution;
  if (execution !== "direct" && execution !== "safe") throw Error("Unknown receipt mode");
  const [tx, receipt] = await Promise.all([p.getTransaction(transactionHash), p.getTransactionReceipt(transactionHash)]);
  if (!tx || !receipt || !same(tx.hash, transactionHash) || !same(receipt.hash, transactionHash) || receipt.status !== 1
    || tx.chainId !== d.chainId || tx.blockNumber === null || !tx.blockHash || receipt.blockNumber !== tx.blockNumber
    || !same(receipt.blockHash, tx.blockHash) || !same(receipt.to, tx.to) || !same(receipt.from, tx.from)
    || tx.value !== 0n || !tx.to || receipt.blockNumber < 1) throw Error("Successful mined transaction/receipt identity differs");
  const tag = integer(receipt.blockNumber), blockHash = hash(receipt.blockHash), data = bytes(tx.data, MAX_CALL);
  if (execution === "direct") {
    if (!same(tx.from, s.caller) || !same(tx.to, s.call.to) || !same(data, s.call.data)) throw Error("Direct preparation CALL differs");
  } else {
    if (!same(tx.to, s.caller)) throw Error("Safe caller differs");
    const decoded = safeAbi.decodeFunctionData("execTransaction", data);
    if (!same(safeAbi.encodeFunctionData("execTransaction", decoded), data) || !same(decoded.to, s.call.to)
      || decoded.value !== 0n || decoded.operation !== 0n || !same(decoded.data, s.call.data)) throw Error("Safe envelope differs from exact ordinary zero-value CALL");
  }
  if (!Array.isArray(receipt.logs) || receipt.logs.length > 256) throw Error("Receipt log bound exceeded");
  let last = -1;
  const logs = receipt.logs.map(l => {
    if (l.removed || l.blockNumber !== tag || !same(l.blockHash, blockHash) || !same(l.transactionHash, transactionHash)
      || integer(l.index) <= last || !Array.isArray(l.topics) || l.topics.length > 4) throw Error("Receipt log identity/order differs");
    last = l.index;
    return { address: address(l.address), data: bytes(l.data, 16384), topics: l.topics.map((v: string) => hash(v, true)), index: l.index };
  });
  const refs: ReferenceInventoryEventReference[] = [];
  const parse = (target: Address, abi: Interface, name: string) => {
    const fragment = abi.getEvent(name)!;
    return logs.filter(l => same(l.address, target) && same(l.topics[0], fragment.topicHash)).map(l => {
      const decoded = abi.decodeEventLog(fragment, l.data, l.topics), canonical = abi.encodeEventLog(fragment, decoded);
      if (!same(canonical.data, l.data)) throw Error(`Noncanonical ${name} event`);
      equal(canonical.topics.map(t => t.toLowerCase()), l.topics, "Noncanonical event topics");
      return { decoded, ref: { address: target, event: name, logIndex: l.index, transactionHash, blockHash } };
    });
  };
  if (execution === "safe") {
    const successes = logs.filter(l => same(l.address, s.caller) && same(l.topics[0], safeLegacy.getEvent("ExecutionSuccess")!.topicHash));
    if (successes.length !== 1 || logs.some(l => same(l.address, s.caller) && same(l.topics[0], safeLegacy.getEvent("ExecutionFailure")!.topicHash))) throw Error("Expected one Safe success and no failure");
    const success = parse(s.caller, successes[0]!.topics.length === 2 ? safeIndexed : safeLegacy, "ExecutionSuccess")[0]!;
    hash(success.decoded.txHash);
    refs.push(success.ref);
  }
  const { header: h } = await context(p, d, tag), { header: prior } = await context(p, d, tag - 1);
  if (!same(h.hash, blockHash)) throw Error("Receipt block is not canonical");
  const uploads = parse(d.store.address, storeAbi, "ChunkPublished");
  const publications = parse(d.publicationHost.address, hostAbi, "ReferenceModePublicationPrepared");
  const payloads = parse(d.publicationHost.address, hostAbi, "ReferenceModePayloadPrepared");
  let previouslyRetained: boolean;
  let emitted: ReturnType<typeof parse>;
  if (s.kind === "upload") {
    if (publications.length || payloads.length) throw Error("Unexpected preparation event during upload");
    const chunk = planned.chunks[s.chunkIndex!]!;
    const available = await availability(p, d, chunk, tag), before = await availability(p, d, chunk, tag - 1);
    if (!available.available) throw Error("Mined chunk unavailable");
    previouslyRetained = before.available;
    if (before.available && !same(before.pointer, available.pointer)) throw Error("Immutable retained chunk pointer changed");
    emitted = uploads;
    for (const e of emitted) {
      if (!same(e.decoded.hash, s.identity) || !same(e.decoded.pointer, available.pointer) || e.decoded[2] !== available.byteLength) throw Error("Chunk publication event differs");
    }
  } else {
    if (uploads.length || (s.kind === "publication" ? payloads.length : publications.length)) throw Error("Unexpected other preparation event");
    if (!await retained(p, planned, "environment", tag) || !await retained(p, planned, "publication", tag)
      || (s.kind === "payload" && !await retained(p, planned, "payload", tag))) throw Error("Mined Mode prerequisite or preparation unavailable");
    previouslyRetained = await retained(p, planned, s.kind, tag - 1);
    if (previouslyRetained && (!await retained(p, planned, "environment", tag - 1)
      || (s.kind === "payload" && !await retained(p, planned, "publication", tag - 1)))) throw Error("Prior retained Mode prerequisite is missing");
    emitted = s.kind === "publication" ? publications : payloads;
    for (const e of emitted) {
      if (e.decoded.schemaVersion !== 1n || !same(e.decoded.preparationId, s.identity)) throw Error("Mode preparation event identity differs");
      if (s.kind === "publication") {
        const descriptor = preparationAbi.getFunction("preparedModePublication")!.outputs[0]!;
        if (!same(coder.encode([descriptor], [e.decoded.descriptor]), coder.encode([descriptor], [planned.snapshot.publication.descriptor]))) throw Error("Publication descriptor event differs");
      } else if (!same(e.decoded.publicationPreparationId, planned.snapshot.publication.publicationPreparationId)
        || !same(e.decoded.payloadHash, planned.snapshot.contentHash) || e.decoded.payloadBytes !== planned.snapshot.byteLength) throw Error("Payload event differs from original bytes");
    }
  }
  if (emitted.length > 1) throw Error("Duplicate retention events");
  if (!emitted.length && !previouslyRetained) throw Error("Eventless retry requires prior-block retained evidence; same-block history is unproven");
  if (emitted.length && previouslyRetained) throw Error("First-retention event contradicts immutable prior-block evidence");
  for (const e of emitted) refs.push(e.ref);
  const success = refs.find(e => e.event === "ExecutionSuccess");
  if (success && refs.some(e => e.event !== "ExecutionSuccess" && e.logIndex >= success.logIndex)) throw Error("Safe success must follow retention events");
  await unchanged(p, prior);
  await unchanged(p, h);
  return freeze({ plan: planned, step: s, transactionHash, blockNumber: tag, blockHash, identity: s.identity,
    events: refs.sort((a, b) => a.logIndex - b.logIndex), retention: emitted.length ? "created" : "reused",
    priorBlock: { ...prior, retained: previouslyRetained } });
}
