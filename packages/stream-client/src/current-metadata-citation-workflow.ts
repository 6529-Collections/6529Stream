import { AbiCoder, Interface, ParamType, ZeroAddress, ZeroHash, getAddress, id, isHexString, keccak256, toUtf8Bytes, type Provider } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import type { UnsignedCall } from "./client.js";
import * as citation from "./current-metadata-citation.js";

type Snapshot = ReturnType<typeof citation.normalizeMetadataCitationSnapshot>;
type Registration = Parameters<typeof citation.normalizeMetadataCitationRegistration>[0];
type Read = ReturnType<typeof citation.normalizeMetadataCitationReads>[number];
type Plan = ReturnType<typeof citation.prepareMetadataCitationRegistration>;
type Batch = ReturnType<typeof citation.metadataCitationGovernanceBatch>;
type Window = Parameters<typeof citation.metadataCitationGovernanceBatch>[2];
type Evidence = ReturnType<typeof citation.validateMetadataCitationEvidence>;
type Request = Parameters<typeof citation.normalizeMetadataCitationRenderRequest>[0];
export interface MetadataCitationCodePin { readonly address: Address; readonly codeHash: Hex }
export interface MetadataCitationDeployment {
  readonly chainId: bigint;
  readonly registry: MetadataCitationCodePin;
  readonly schemaRegistry: MetadataCitationCodePin;
  readonly store: MetadataCitationCodePin;
  readonly governance: MetadataCitationCodePin;
  readonly renderer: MetadataCitationCodePin;
  readonly encoding: MetadataCitationCodePin;
}
export interface MetadataCitationCatalog {
  readonly candidateProfileHash: Hex; readonly catalogHash: Hex; readonly entryCount: bigint; readonly revision: bigint;
  readonly rowAdmission: "original-call-simulation-required";
}
export interface MetadataCitationGas {
  readonly value: bigint; readonly floor: bigint; readonly failureClass: bigint; readonly revision: bigint;
}
export interface MetadataCitationCapture {
  readonly deployment: MetadataCitationDeployment; readonly versionKey: Hex; readonly snapshot: Snapshot;
  readonly currentReads: readonly Read[];
  readonly readGas: MetadataCitationGas; readonly goldenGas: MetadataCitationGas;
  readonly blockNumber: number; readonly blockHash: Hex; readonly timestamp: bigint;
  readonly governanceNonce: bigint; readonly catalog: MetadataCitationCatalog; readonly captureHash: Hex;
}
export interface MetadataCitationDocument {
  readonly documentId: Hex; readonly contentHash: Hex; readonly declarationHash: Hex;
  readonly canonicalizationId: Hex; readonly supersedesId: Hex; readonly bytes: Hex;
  readonly chunks: readonly { readonly hash: Hex; readonly pointer: Address; readonly length: bigint }[];
}
export interface MetadataCitationInspection {
  readonly capture: MetadataCitationCapture; readonly plan: Plan; readonly evidence: Evidence;
  readonly analysisDocument: MetadataCitationDocument; readonly goldenDocument: MetadataCitationDocument;
  readonly goldenObservation: "direct renderer calls; no nested gas equivalence";
  readonly inspectionHash: Hex;
}
export interface PreparedMetadataCitationGovernance {
  readonly inspection: MetadataCitationInspection; readonly proposer: Address; readonly batch: Batch;
}
export interface MetadataCitationOperation {
  readonly prepared: PreparedMetadataCitationGovernance; readonly stage: "publish" | "schedule" | "execute";
  readonly caller: Address; readonly call: UnsignedCall;
}
type Reader = Pick<Provider, "getNetwork" | "getCode" | "getBlock" | "call">;
type ReceiptReader = Reader & Pick<Provider, "getTransaction" | "getTransactionReceipt">;
const coder = AbiCoder.defaultAbiCoder();
const REQUEST = "(address core,uint256 tokenId,uint256 collectionId,uint256 collectionSerial,bytes32 tokenHash,uint8 state,uint8 mode,uint8 collectionSupplyMode,uint8 collectionStatus,bytes32 viewId,bytes32 viewManifestHash,bytes32 metadataSnapshotHash)";
const READ = "(uint16 targetIndex,bytes4 selector,uint32 maxReturnBytes,bool exact)";
const TARGET = "(address target,bytes32 codeHash,bytes32 role)";
const VERSION = "(bool exists,bool deprecated,address renderer,bytes32 runtimeHash,bytes32 registrationHash,bytes32 readSetHash,bytes32 analysisHash,bytes32 goldenHash,bytes32 actionId)";
const REGISTRATION = "(bytes32 versionKey,bytes32 profile,bytes4 selector,address encoding,bytes32 encodingRuntimeHash,bytes32 analysisDocument,bytes32 goldenDocument)";
const RECORD = `(${REGISTRATION} registration,bytes32 registrationHash,bytes32 readSetHash,bytes32 analysisHash,bytes32 goldenHash,bytes32 actionId)`;
const GOVERNANCE_CALL = "(address target,uint256 value,bytes4 selector,bytes32 callDataHash,bytes32 scopeHash,bytes32 oldValueHash,bytes32 newValueHash)";
const abi = new Interface([
  "function governanceAuthority() view returns(address)", "function governanceAuthorityCodeHash() view returns(bytes32)",
  "function schemaRegistry() view returns(address)", "function schemaRegistryCodeHash() view returns(bytes32)",
  "function deploymentChainId() view returns(uint256)", "function targetSetHash() view returns(bytes32)",
  "function chunkStore() view returns(address)", "function owner() view returns(address)",
  "function targetCount() view returns(uint256)", `function targetAt(uint256) view returns(${TARGET})`,
  `function version(bytes32) view returns(${VERSION})`, `function reads(bytes32) view returns(${READ}[])`,
  `function registerCurrentCitation(${REGISTRATION},${READ}[])`,
  `function currentCitationTransition(${REGISTRATION},${READ}[]) view returns(bytes32,bytes32,bytes32)`,
  `function currentCitationRecord(bytes32) view returns(${RECORD})`, `function currentCitationReads(bytes32) view returns(${READ}[])`,
  "function requireCurrentCitation(bytes32) view returns(address,bytes32,bytes32,bytes4)",
  "function requireRetained(bytes32) view returns(address,bytes32)",
  "function supportsInterface(bytes4) view returns(bool)", "function currentCitationProfile() pure returns(bytes32)",
  "function encodingBinding() view returns(address,bytes32)", `function renderCurrent(${REQUEST},uint8) view returns(string)`,
  "function gasParameterInfo(bytes32) view returns(uint256 value,uint256 floor,uint8 failureClass,uint64 revision)",
  "function documentFacts(bytes32) view returns((bool exists,uint8 kind,uint8 status,bytes32 contentHash,bytes32 canonicalizationId,bytes32 supersedesId,uint32 totalBytes,uint256 chunkCount,bytes32 declarationHash))",
  "function documentChunkHashAt(bytes32,uint256) view returns(bytes32)", "function documentBytes(bytes32) view returns(bytes)",
  "function chunk(bytes32) view returns(address pointer,uint32 length)", "function readChunk(bytes32) view returns(bytes)",
  "function systemManifestBootstrapState() view returns (bool, bool, address, bytes32, address, bytes32, uint64, bytes32, uint256, bytes32, uint64, address, bytes32, address, bytes32, bytes32, uint256, bytes32, uint256, bytes32, bytes32, uint256, bytes32, uint256, address, address, bytes32, bytes32, uint256)",
  "function governanceNonce() view returns(uint256)",
  "function governanceActionPolicyState() view returns(bytes32 candidateProfileHash,bytes32 catalogHash,uint256 entryCount,uint64 revision)",
  "function isProposer(address) view returns(bool)", "function minimumDelay(uint8) pure returns(uint64)",
  "function publishedCallData(bytes32) view returns(address)",
  "function publishGovernanceCallData(bytes[]) returns(address)",
  `function scheduleGovernanceBatch(uint8,${GOVERNANCE_CALL}[],bytes32,bytes32,bytes32,uint64,uint64,bytes32,string,bytes32) returns(bytes32)`,
  `function executeGovernanceBatch(bytes32,${GOVERNANCE_CALL}[],bytes[]) payable`,
  "function governanceAction(bytes32) view returns((uint8 status,uint8 actionClass,address target,uint256 value,bytes4 selector,bytes32 callHash,bytes32 scopeHash,bytes32 oldValueHash,bytes32 newValueHash,uint64 notBefore,uint64 expiresAfter,address proposer,address executor,address canceller,address vetoer,bytes32 reasonHash,string reasonURI,bytes32 manifestHash))",
  "function scheduledCallData(bytes32) view returns(bytes[])", "function scheduledCallDataPointer(bytes32) view returns(address)",
  "event GovernanceCallDataPublished(uint16 schemaVersion,bytes32 indexed callDataKey,address pointer,address publisher)",
  "event GovernanceActionPolicyValidated(uint16 schemaVersion,bytes32 indexed actionId,uint8 indexed phase,bytes32 indexed candidateProfileHash,bytes32 catalogHash)",
  "event GovernanceActionScheduled(uint16 schemaVersion,bytes32 indexed actionId,uint8 indexed actionClass,address indexed target,uint256 value,bytes4 selector,bytes32 callHash,bytes32 scopeHash,bytes32 oldValueHash,bytes32 newValueHash,uint64 notBefore,uint64 expiresAfter,uint256 nonce,address proposer,bytes32 reasonHash,string reasonURI,bytes32 manifestHash)",
  "event GovernanceActionExecuted(uint16 schemaVersion,bytes32 indexed actionId,uint8 indexed actionClass,address indexed target,uint256 value,bytes4 selector,bytes32 callHash,bytes32 scopeHash,bytes32 oldValueHash,bytes32 newValueHash,address executor,bytes32 manifestHash)",

  `event CurrentCitationRegistered(uint16 schemaVersion,bytes32 indexed versionKey,address indexed renderer,bytes32 indexed actionId,bytes32 registrationHash,${REGISTRATION} registration,${READ}[] reads)`
]);
function keys(v: unknown, required: readonly string[], optional: readonly string[] = []): void {
  if (!v || typeof v !== "object" || Array.isArray(v) || Reflect.ownKeys(v).some(k => typeof k !== "string" || ![...required, ...optional].includes(k))
    || required.some(k => !Object.hasOwn(v, k))) throw Error("Missing/unknown properties");
}
function address(v: unknown): Address {
  if (typeof v !== "string") throw Error("Expected address");
  const a = getAddress(v) as Address;
  if (a === ZeroAddress) throw Error("Zero address");
  return a;
}
function hash(v: unknown, zero = false): Hex {
  if (typeof v !== "string" || !isHexString(v, 32) || (!zero && v.toLowerCase() === ZeroHash)) throw Error("Expected bytes32");
  return v.toLowerCase() as Hex;
}
function uint(v: unknown, bits = 256): bigint {
  if (typeof v !== "bigint" || v < 0n || v >= 1n << BigInt(bits)) throw Error("Expected bounded unsigned bigint");
  return v;
}
function number(v: unknown): number {
  if (typeof v !== "number" || !Number.isSafeInteger(v) || v < 0) throw Error("Expected concrete block/index");
  return v;
}
function bytes(v: unknown, max = 32768): Hex {
  if (typeof v !== "string" || !isHexString(v, true) || (v.length - 2) / 2 > max) throw Error("Malformed or oversized bytes");
  return v.toLowerCase() as Hex;
}
function same(a: unknown, b: unknown): boolean {
  return typeof a === "string" && typeof b === "string" && a.toLowerCase() === b.toLowerCase();
}
function stable(v: unknown): string {
  const tagged = (x: unknown): unknown => {
    if (x === null) return ["null"];
    if (typeof x === "string" || typeof x === "boolean") return [typeof x, x];
    if (typeof x === "bigint") return ["bigint", x.toString()];
    if (typeof x === "number" && Number.isFinite(x)) return ["number", x];
    if (Array.isArray(x)) return ["array", x.map(tagged)];
    if (x && typeof x === "object") return ["object", Object.keys(x).sort().map(k => [k, tagged((x as Record<string, unknown>)[k])])];
    throw Error("Unsupported canonical value");
  };
  return JSON.stringify(tagged(v));
}
function equal(a: unknown, b: unknown, reason = "Prepared facts differ; recapture and review"): void {
  if (stable(a) !== stable(b)) throw Error(reason);
}
function freeze<T>(v: T): T {
  if (v && typeof v === "object") { Object.values(v).forEach(freeze); Object.freeze(v); }
  return v;
}
async function header(p: Reader, tag: number) {
  const b = await p.getBlock(tag);
  if (!b || b.number !== tag || !Number.isSafeInteger(b.timestamp) || b.timestamp < 0) throw Error("Missing/mismatched block");
  return { blockNumber: tag, blockHash: hash(b.hash), timestamp: BigInt(b.timestamp) };
}
async function unchanged(p: Reader, h: { blockNumber: number; blockHash: Hex; timestamp: bigint }): Promise<void> {
  equal(await header(p, h.blockNumber), { blockNumber: h.blockNumber, blockHash: h.blockHash, timestamp: h.timestamp }, "Pinned block changed");
}
async function runtime(p: Reader, v: MetadataCitationCodePin, tag: number): Promise<void> {
  const code = bytes(await p.getCode(v.address, tag), 65536);
  if (code === "0x" || (code.length === 48 && code.startsWith("0xef0100")) || !same(keccak256(code), v.codeHash)) throw Error("Pinned runtime differs");
}

function plain(t: ParamType, value: any): any {
  if (t.baseType === "array") return Array.from(value, item => plain(t.arrayChildren!, item));
  if (t.baseType === "tuple") return Object.fromEntries(t.components!.map((part, i) => [part.name, plain(part, value[i])]));
  return value;
}
async function read(p: Reader, to: Address, name: string, args: readonly unknown[], tag: number, from?: Address, maximum = 32768): Promise<any[]> {
  const raw = bytes(await p.call({ to, data: abi.encodeFunctionData(name, args), value: 0n, blockTag: tag, ...(from ? { from } : {}) }), maximum);
  const decoded = abi.decodeFunctionResult(name, raw);
  if (!same(abi.encodeFunctionResult(name, decoded), raw)) throw Error(`Noncanonical ${name} return`);
  return abi.getFunction(name)!.outputs!.map((part, i) => plain(part, decoded[i]));
}
function pin(v: MetadataCitationCodePin): MetadataCitationCodePin {
  keys(v, ["address", "codeHash"]);
  return { address: address(v.address), codeHash: hash(v.codeHash) };
}
function deployment(v: MetadataCitationDeployment): MetadataCitationDeployment {
  const names = ["registry", "schemaRegistry", "store", "governance", "renderer", "encoding"] as const;
  keys(v, ["chainId", ...names]);
  const chainId = uint(v.chainId);
  if (!chainId) throw Error("Zero chain");
  const out = { chainId, ...Object.fromEntries(names.map(n => [n, pin(v[n])])) } as unknown as MetadataCitationDeployment;
  if (new Set(names.map(n => out[n].address)).size !== names.length) throw Error("Deployment components must be distinct");
  return freeze(out);
}
function interfaceId(names: readonly string[]): Hex {
  return `0x${names.reduce((v, name) => v ^ BigInt(abi.getFunction(name)!.selector), 0n).toString(16).padStart(8, "0")}` as Hex;
}
const CURRENT_REGISTRY = interfaceId(["registerCurrentCitation", "currentCitationTransition", "currentCitationRecord", "currentCitationReads", "requireCurrentCitation"]);
const CURRENT_RENDERER = interfaceId(["currentCitationProfile", "renderCurrent", "encodingBinding"]);
const DOCUMENT_FACTS = interfaceId(["documentFacts", "documentChunkHashAt"]);
async function context(p: Reader, d: MetadataCitationDeployment, tag: number) {
  if ((await p.getNetwork()).chainId !== d.chainId) throw Error("RPC chain differs");
  const h = await header(p, tag);
  await Promise.all([d.registry, d.schemaRegistry, d.store, d.governance, d.renderer, d.encoding].map(v => runtime(p, v, tag)));
  for (const [host, name, expected] of [
    [d.registry, "schemaRegistry", d.schemaRegistry.address], [d.registry, "schemaRegistryCodeHash", d.schemaRegistry.codeHash],
    [d.registry, "governanceAuthority", d.governance.address], [d.registry, "governanceAuthorityCodeHash", d.governance.codeHash],
    [d.schemaRegistry, "governanceAuthority", d.governance.address], [d.schemaRegistry, "governanceAuthorityCodeHash", d.governance.codeHash],
    [d.schemaRegistry, "chunkStore", d.store.address]
  ] as const) {
    if (!same((await read(p, host.address, name, [], tag))[0], expected)) throw Error(`${name} dependency differs`);
  }
  if ((await read(p, d.registry.address, "deploymentChainId", [], tag))[0] !== d.chainId
    || (await read(p, d.registry.address, "supportsInterface", [CURRENT_REGISTRY], tag))[0] !== true
    || (await read(p, d.schemaRegistry.address, "supportsInterface", [DOCUMENT_FACTS], tag))[0] !== true) throw Error("Registry chain/capability differs");
  return h;
}
async function governance(p: Reader, d: MetadataCitationDeployment, tag: number) {
  const boot = await read(p, d.governance.address, "systemManifestBootstrapState", [], tag);
  if (boot[0] !== true || boot[1] !== true) throw Error("Only sealed ordinary governance is supported");
  if ((await read(p, d.governance.address, "minimumDelay", [1n], tag))[0] !== 172800n) throw Error("Original class1 delay differs");
  const [profile, catalogHash, count, revision] = await read(p, d.governance.address, "governanceActionPolicyState", [], tag);
  if (count === 0n || count > 1024n) throw Error("Unbound/oversized governance catalog");
  return { governanceNonce: uint((await read(p, d.governance.address, "governanceNonce", [], tag))[0]),
    catalog: { candidateProfileHash: hash(profile), catalogHash: hash(catalogHash), entryCount: uint(count), revision: uint(revision, 64),
      rowAdmission: "original-call-simulation-required" as const } };
}
async function bindings(p: Reader, d: MetadataCitationDeployment, tag: number): Promise<void> {
  if ((await read(p, d.renderer.address, "supportsInterface", [CURRENT_RENDERER], tag))[0] !== true
    || !same((await read(p, d.renderer.address, "currentCitationProfile", [], tag))[0], id("6529STREAM_CURRENT_BASE_CITATION_V1"))) throw Error("Current renderer capability/profile differs");
  equal(await read(p, d.renderer.address, "encodingBinding", [], tag), [d.encoding.address, d.encoding.codeHash], "Current encoding binding differs");
}
async function gas(p: Reader, registry: Address, name: string, tag: number): Promise<MetadataCitationGas> {
  const [value, floor, failureClass, revision] = await read(p, registry, "gasParameterInfo", [id(name)], tag);
  if (value === 0n || value < floor || failureClass !== 2n || revision === 0n) throw Error("Renderer gas policy differs");
  return { value, floor, failureClass, revision };
}
async function registrySnapshot(p: Reader, d: MetadataCitationDeployment, versionKey: Hex, tag: number) {
  const count = (await read(p, d.registry.address, "targetCount", [], tag))[0];
  if (count === 0n || count > 64n) throw Error("Target inventory exceeds1..64");
  const targets = [];
  for (let i = 0n; i < count; ++i) targets.push((await read(p, d.registry.address, "targetAt", [i], tag))[0]);
  if (!same(citation.metadataCitationTargetSetHash(targets), (await read(p, d.registry.address, "targetSetHash", [], tag))[0])) throw Error("Target set hash differs");
  const originalVersion = (await read(p, d.registry.address, "version", [versionKey], tag))[0];
  if (!originalVersion.exists || !same(originalVersion.renderer, d.renderer.address) || !same(originalVersion.runtimeHash, d.renderer.codeHash)) throw Error("Unknown/different original renderer version");
  for (const name of ["registrationHash", "analysisHash", "goldenHash", "actionId"]) hash(originalVersion[name]);
  equal(await read(p, d.registry.address, "requireRetained", [versionKey], tag), [d.renderer.address, d.renderer.codeHash]);
  const originalReads = citation.normalizeMetadataCitationReads((await read(p, d.registry.address, "reads", [versionKey], tag))[0]);
  if (!same(citation.metadataCitationReadSetHash(targets, originalReads), originalVersion.readSetHash)) throw Error("Original read set hash differs");
  const currentRecord = (await read(p, d.registry.address, "currentCitationRecord", [versionKey], tag))[0];
  const currentReads = citation.normalizeMetadataCitationReads((await read(p, d.registry.address, "currentCitationReads", [versionKey], tag))[0]);
  const snapshot = citation.normalizeMetadataCitationSnapshot({ chainId: d.chainId, registry: d.registry.address,
    schemaRegistry: d.schemaRegistry.address, schemaRegistryCodeHash: d.schemaRegistry.codeHash, governanceExecutor: d.governance.address,
    targets, originalVersion, originalReads, currentRecord });
  if (same(currentRecord.registrationHash, ZeroHash)) {
    const emptyRegistration = { versionKey: ZeroHash, profile: ZeroHash, selector: "0x00000000", encoding: ZeroAddress,
      encodingRuntimeHash: ZeroHash, analysisDocument: ZeroHash, goldenDocument: ZeroHash };
    equal(currentRecord, { registration: emptyRegistration, registrationHash: ZeroHash, readSetHash: ZeroHash,
      analysisHash: ZeroHash, goldenHash: ZeroHash, actionId: ZeroHash }, "Absent current record is not empty");
    if (currentReads.length) throw Error("Absent current record has reads");
  } else {
    for (const name of ["analysisHash", "goldenHash", "actionId"]) hash(currentRecord[name]);
    if (!same(currentRecord.registration.versionKey, versionKey)
      || !same(citation.metadataCitationDeclarationHash(snapshot, currentRecord.registration, currentReads), currentRecord.registrationHash)
      || !same(citation.metadataCitationReadSetHash(targets, currentReads), currentRecord.readSetHash)) throw Error("Retained current declaration differs");
  }
  return { snapshot, currentReads };
}
function digest(v: unknown): Hex { return keccak256(toUtf8Bytes(stable(v))) as Hex; }
function saved(v: MetadataCitationCapture): MetadataCitationCapture {
  keys(v, ["deployment", "versionKey", "snapshot", "currentReads", "readGas", "goldenGas", "blockNumber", "blockHash", "timestamp", "governanceNonce", "catalog", "captureHash"]);
  const out = { ...structuredClone(v), deployment: deployment(v.deployment), versionKey: hash(v.versionKey),
    snapshot: citation.normalizeMetadataCitationSnapshot(v.snapshot), currentReads: citation.normalizeMetadataCitationReads(v.currentReads) };
  const { captureHash, ...facts } = out;
  if (!same(digest(facts), hash(captureHash))) throw Error("Saved capture facts changed");
  return freeze(out);
}
export async function captureMetadataCitation(p: Reader, input: MetadataCitationDeployment, suppliedVersion: Hex,
  options: { readonly blockTag: number }): Promise<MetadataCitationCapture> {
  keys(options, ["blockTag"]);
  const d = deployment(input), versionKey = hash(suppliedVersion), tag = number(options.blockTag);
  const h = await context(p, d, tag), snapshot = await registrySnapshot(p, d, versionKey, tag);
  await bindings(p, d, tag);
  const readGas = await gas(p, d.registry.address, "6529STREAM_GGP_METADATA_DEPENDENCY_READ_GAS", tag);
  const goldenGas = await gas(p, d.registry.address, "6529STREAM_GGP_RENDERER_GOLDEN_VECTOR_GAS", tag);
  const facts = { deployment: d, versionKey, ...snapshot, readGas, goldenGas, ...h, ...await governance(p, d, tag) };
  await unchanged(p, h);
  return freeze({ ...facts, captureHash: digest(facts) });
}
async function original(p: Reader, c: MetadataCitationCapture): Promise<void> {
  equal(await captureMetadataCitation(p, c.deployment, c.versionKey, { blockTag: c.blockNumber }), c, "Saved historical capture differs");
}
async function document(p: Reader, d: MetadataCitationDeployment, documentId: Hex, tag: number): Promise<MetadataCitationDocument> {
  const [f] = await read(p, d.schemaRegistry.address, "documentFacts", [documentId], tag);
  if (!f.exists || f.kind !== 2n || f.status !== 0n || f.totalBytes === 0n || f.totalBytes > 8192n
    || f.chunkCount === 0n || f.chunkCount > 64n) throw Error("Evidence document must be ACTIVE CATALOG within8192 bytes");
  hash(f.contentHash); hash(f.declarationHash);
  const chunks = [], parts: Hex[] = [];
  let total = 0n;
  for (let i = 0n; i < f.chunkCount; ++i) {
    const chunkHash = hash((await read(p, d.schemaRegistry.address, "documentChunkHashAt", [documentId, i], tag))[0]);
    const [pointer, length] = await read(p, d.store.address, "chunk", [chunkHash], tag);
    if (length === 0n || length > 8192n || (total += length) > f.totalBytes) throw Error("Invalid document chunk length");
    const code = bytes(await p.getCode(address(pointer), tag), 8193);
    const value = bytes((await read(p, d.store.address, "readChunk", [chunkHash], tag, undefined, 8256))[0], 8192);
    if (!same(code, `0x00${value.slice(2)}`) || BigInt((value.length - 2) / 2) !== length || !same(keccak256(value), chunkHash)) throw Error("Retained document chunk differs");
    chunks.push({ hash: chunkHash, pointer: address(pointer), length }); parts.push(value);
  }
  const payload = bytes((await read(p, d.schemaRegistry.address, "documentBytes", [documentId], tag, undefined, 8256))[0], 8192);
  if (total !== f.totalBytes || !same(payload, `0x${parts.map(v => v.slice(2)).join("")}`) || !same(keccak256(payload), f.contentHash)) throw Error("Retained evidence bytes differ");
  return freeze({ documentId, contentHash: f.contentHash, declarationHash: f.declarationHash,
    canonicalizationId: f.canonicalizationId, supersedesId: f.supersedesId, bytes: payload, chunks });
}
async function declaredRuntimes(p: Reader, d: MetadataCitationDeployment, s: Snapshot, reads: readonly Read[], tag: number): Promise<void> {
  const seen = new Set<bigint>();
  for (const entry of reads) {
    if (seen.has(entry.targetIndex)) continue;
    seen.add(entry.targetIndex);
    const target = s.targets[Number(entry.targetIndex)]!;
    await runtime(p, { address: target.target, codeHash: target.codeHash }, tag);
  }
}
async function render(p: Reader, d: MetadataCitationDeployment, request: Request, mode: bigint, tag: number): Promise<string> {
  if (![0n, 1n, 2n].includes(mode)) throw Error("Only admitted citation modes0..2 are supported");
  const maximum = mode === 0n ? 18000 : mode === 1n ? 24576 : 16777216;
  const [output] = await read(p, d.renderer.address, "renderCurrent", [request, mode], tag, undefined, 64 + Math.ceil(maximum / 32) * 32);
  if (toUtf8Bytes(output).length > maximum) throw Error("Current output exceeds mode bound");
  return output;
}
function inspection(v: MetadataCitationInspection): MetadataCitationInspection {
  keys(v, ["capture", "plan", "evidence", "analysisDocument", "goldenDocument", "goldenObservation", "inspectionHash"]);
  const out = { capture: saved(v.capture), plan: citation.normalizeMetadataCitationPlan(v.plan),
    evidence: citation.validateMetadataCitationEvidence(v.plan, v.evidence.analysis, v.evidence.goldens),
    analysisDocument: structuredClone(v.analysisDocument), goldenDocument: structuredClone(v.goldenDocument), goldenObservation: v.goldenObservation };
  equal(out.plan.snapshot, out.capture.snapshot);
  if (out.goldenObservation !== "direct renderer calls; no nested gas equivalence" || !same(digest(out), hash(v.inspectionHash))) throw Error("Inspection facts changed");
  return freeze({ ...out, inspectionHash: v.inspectionHash });
}
/** Validates supplied retained expectations. Renderer output is never used to construct a golden expectation. */
export async function inspectMetadataCitationRegistration(p: Reader, input: MetadataCitationCapture, registration: Registration,
  reads: readonly Read[]): Promise<MetadataCitationInspection> {
  const c = saved(input), plan = citation.prepareMetadataCitationRegistration(c.snapshot, registration, reads);
  if (!same(plan.registration.versionKey, c.versionKey) || !same(plan.registration.encoding, c.deployment.encoding.address)
    || !same(plan.registration.encodingRuntimeHash, c.deployment.encoding.codeHash)) throw Error("Registration differs from captured version/encoding");
  await original(p, c);
  const d = c.deployment, tag = c.blockNumber;
  await declaredRuntimes(p, d, c.snapshot, plan.reads, tag);
  equal(await read(p, d.registry.address, "currentCitationTransition", [plan.registration, plan.reads], tag),
    [plan.transition.scopeHash, plan.transition.oldValueHash, plan.transition.newValueHash], "Current declaration transition differs");
  const analysisDocument = await document(p, d, plan.registration.analysisDocument, tag);
  const goldenDocument = await document(p, d, plan.registration.goldenDocument, tag);
  const evidence = citation.validateMetadataCitationEvidence(plan, citation.decodeMetadataCitationAnalysis(analysisDocument.bytes),
    citation.decodeMetadataCitationGoldenVectors(goldenDocument.bytes));
  for (const vector of evidence.goldens) {
    if (!same(keccak256(toUtf8Bytes(await render(p, d, vector.request, vector.mode, tag))), vector.outputHash)) throw Error("Independent golden output hash differs");
  }
  await unchanged(p, c);
  const facts = { capture: c, plan, evidence, analysisDocument, goldenDocument,
    goldenObservation: "direct renderer calls; no nested gas equivalence" as const };
  return freeze({ ...facts, inspectionHash: digest(facts) });
}

function windowCheck(now: bigint, w: Window): void {
  if (now > (1n << 64n) - 1n - 31536000n || w.notBefore < now + 172800n
    || w.expiresAfter > now + 31536000n || w.expiresAfter - w.notBefore < 604800n) throw Error("Original governance48h/7day/365day window differs");
}
export function prepareMetadataCitationGovernance(input: MetadataCitationInspection, proposer: Address,
  window: Window): PreparedMetadataCitationGovernance {
  const i = inspection(input);
  const batch = citation.metadataCitationGovernanceBatch(i.plan, i.capture.governanceNonce, window);
  windowCheck(i.capture.timestamp, batch.window);
  if (toUtf8Bytes(batch.window.reasonURI).length > 2048) throw Error("Reason URI exceeds client bound");
  return freeze({ inspection: i, proposer: address(proposer), batch });
}
function prepared(v: PreparedMetadataCitationGovernance): PreparedMetadataCitationGovernance {
  keys(v, ["inspection", "proposer", "batch"]);
  const b = citation.normalizeMetadataCitationGovernanceBatch(v.batch);
  const out = prepareMetadataCitationGovernance(v.inspection, v.proposer, b.window);
  equal(out, v);
  return out;
}
export function prepareMetadataCitationOperation(input: PreparedMetadataCitationGovernance,
  stage: MetadataCitationOperation["stage"], caller: Address): MetadataCitationOperation {
  const p = prepared(input), actor = address(caller);
  if (!["publish", "schedule", "execute"].includes(stage)) throw Error("Unsupported governance stage");
  if (stage === "schedule" && !same(actor, p.proposer)) throw Error("Schedule caller differs from proposer");
  return freeze({ prepared: p, stage, caller: actor, call: stage === "publish" ? p.batch.publicationCall
    : stage === "schedule" ? p.batch.scheduleCall : p.batch.executionCall });
}
function operation(v: MetadataCitationOperation): MetadataCitationOperation {
  keys(v, ["prepared", "stage", "caller", "call"]);
  const out = prepareMetadataCitationOperation(v.prepared, v.stage, v.caller);
  equal(out, v);
  return out;
}
async function publication(p: Reader, b: Batch, tag: number): Promise<Address | null> {
  const [ptr] = await read(p, b.plan.snapshot.governanceExecutor, "publishedCallData", [b.publicationKey], tag);
  if (ptr === ZeroAddress) return null;
  const pointer = address(ptr), expected = coder.encode(["bytes[]"], [[b.plan.targetCall.data]]);
  if (!same(bytes(await p.getCode(pointer, tag), 24576), `0x00${expected.slice(2)}`)) throw Error("Published call data differs");
  return pointer;
}
async function action(p: Reader, o: MetadataCitationOperation, tag: number) {
  const b = o.prepared.batch;
  const [a] = await read(p, b.plan.snapshot.governanceExecutor, "governanceAction", [b.actionId], tag);
  const expected = { actionClass: 1n, target: b.plan.targetCall.to, value: 0n, selector: b.plan.governanceCall.selector,
    callHash: b.callsHash, scopeHash: b.scopeHash, oldValueHash: b.oldValueHash, newValueHash: b.newValueHash,
    notBefore: b.window.notBefore, expiresAfter: b.window.expiresAfter, proposer: o.prepared.proposer,
    reasonHash: b.window.reasonHash, reasonURI: b.window.reasonURI, manifestHash: b.window.manifestHash };
  for (const [key, value] of Object.entries(expected)) {
    if (a[key] !== value && (key === "reasonURI" || !same(a[key], value))) throw Error(`Scheduled ${key} differs`);
  }
  const [data] = await read(p, b.plan.snapshot.governanceExecutor, "scheduledCallData", [b.actionId], tag);
  equal(Array.from(data), [b.plan.targetCall.data], "Scheduled bytes differ");
  const ptr = await publication(p, b, tag);
  if (!ptr || !same((await read(p, b.plan.snapshot.governanceExecutor, "scheduledCallDataPointer", [b.actionId], tag))[0], ptr)) throw Error("Scheduled pointer differs");
  return a;
}

export interface MetadataCitationSimulation {
  readonly operation: MetadataCitationOperation;
  readonly blockNumber: number; readonly blockHash: Hex; readonly timestamp: bigint;
  readonly observed: MetadataCitationInspection | null; readonly returnData: Hex;
}
/** The original governance call provides admission; direct golden reads are observations only. */
export async function simulateMetadataCitationOperation(p: Reader, input: MetadataCitationOperation,
  options: { readonly blockTag: number }): Promise<MetadataCitationSimulation> {
  keys(options, ["blockTag"]);
  const o = operation(input), i = o.prepared.inspection, c = i.capture, b = o.prepared.batch, d = c.deployment, tag = number(options.blockTag);
  if (tag < c.blockNumber) throw Error("Simulation predates capture");
  await original(p, c);
  const h = await context(p, d, tag);
  let observed: MetadataCitationInspection | null = null;
  if (o.stage !== "publish") {
    const current = await captureMetadataCitation(p, d, c.versionKey, { blockTag: tag });
    equal(current.catalog, c.catalog, "Governance catalog changed; rebuild and reschedule");
    equal(current.snapshot, c.snapshot, "Immutable admission state changed; recapture");
    observed = await inspectMetadataCitationRegistration(p, current, i.plan.registration, i.plan.reads);
    equal(observed.evidence, i.evidence, "Retained citation evidence changed");
    if (o.stage === "schedule") {
      if (current.governanceNonce !== b.nonce) throw Error("Governance nonce changed");
      windowCheck(h.timestamp, b.window);
      if (!await publication(p, b, tag)) throw Error("Publish governance call data first");
      const [owner] = await read(p, d.governance.address, "owner", [], tag);
      if (!same(owner, o.caller) && (await read(p, d.governance.address, "isProposer", [o.caller], tag))[0] !== true) throw Error("Caller is not an authorized proposer");
    } else {
      const a = await action(p, o, tag);
      if (a.status !== 1n || h.timestamp < b.window.notBefore || h.timestamp > b.window.expiresAfter) throw Error("Action is outside scheduled execution window");
    }
  }
  const priorPointer = o.stage === "publish" ? await publication(p, b, tag) : null;
  const returned = bytes(await p.call({ ...o.call, from: o.caller, blockTag: tag }));
  if (o.stage === "execute") {
    if (returned !== "0x") throw Error("Noncanonical void execution return");
  } else {
    const name = o.stage === "publish" ? "publishGovernanceCallData" : "scheduleGovernanceBatch";
    const value = abi.decodeFunctionResult(name, returned);
    if (!same(abi.encodeFunctionResult(name, value), returned)) throw Error("Noncanonical simulation return");
    if (o.stage === "schedule" && !same(value[0], b.actionId)) throw Error("Simulated action ID differs");
    if (o.stage === "publish" && (!address(value[0]) || (priorPointer && !same(priorPointer, value[0])))) throw Error("Published pointer changed");
  }
  await unchanged(p, h);
  return freeze({ operation: o, ...h, observed, returnData: returned });
}
export type MetadataCurrentCitationMode = 0n | 1n | 2n;
export interface MetadataCurrentCitationRead {
  readonly deployment: MetadataCitationDeployment; readonly versionKey: Hex;
  readonly request: ReturnType<typeof citation.normalizeMetadataCitationRenderRequest>; readonly mode: MetadataCurrentCitationMode;
  readonly record: Snapshot["currentRecord"]; readonly reads: readonly Read[]; readonly output: string; readonly outputHash: Hex;
  readonly blockNumber: number; readonly blockHash: Hex; readonly timestamp: bigint;
  readonly admission: "retained current citation; no old-selector fallback";
}
async function retained(p: Reader, d: MetadataCitationDeployment, versionKey: Hex, tag: number) {
  const { snapshot, currentReads } = await registrySnapshot(p, d, versionKey, tag), r = snapshot.currentRecord;
  if (same(r.registrationHash, ZeroHash) || !same(r.registration.encoding, d.encoding.address)
    || !same(r.registration.encodingRuntimeHash, d.encoding.codeHash)) throw Error("Current citation is not admitted");
  await declaredRuntimes(p, d, snapshot, currentReads, tag);
  await bindings(p, d, tag);
  equal(await read(p, d.registry.address, "requireCurrentCitation", [versionKey], tag),
    [d.renderer.address, d.renderer.codeHash, r.registration.profile, r.registration.selector], "Admitted current renderer differs");
  if (!same(r.registration.profile, id("6529STREAM_CURRENT_BASE_CITATION_V1")) || !same(r.registration.selector, abi.getFunction("renderCurrent")!.selector)) throw Error("Unsupported retained current profile");
  return { snapshot, currentReads };
}
/** Reads accepted current evidence without replaying ACTIVE-document or nondeprecated-version admission. */
export async function readMetadataCurrentCitation(p: Reader, input: MetadataCitationDeployment, suppliedVersion: Hex,
  suppliedRequest: Request, suppliedMode: MetadataCurrentCitationMode, options: { readonly blockTag: number }): Promise<MetadataCurrentCitationRead> {
  keys(options, ["blockTag"]);
  const d = deployment(input), versionKey = hash(suppliedVersion), request = citation.normalizeMetadataCitationRenderRequest(suppliedRequest), mode = uint(suppliedMode, 8) as MetadataCurrentCitationMode, tag = number(options.blockTag);
  if (mode > 2n) throw Error("Only admitted citation modes0..2 are supported");
  const h = await context(p, d, tag), current = await retained(p, d, versionKey, tag);
  const output = await render(p, d, request, mode, tag);
  await unchanged(p, h);
  return freeze({ deployment: d, versionKey, request, mode, record: current.snapshot.currentRecord, reads: current.currentReads,
    output, outputHash: keccak256(toUtf8Bytes(output)) as Hex, ...h, admission: "retained current citation; no old-selector fallback" });
}

export interface MetadataCitationEventReference {
  readonly address: Address; readonly event: string; readonly logIndex: number;
  readonly transactionHash: Hex; readonly blockHash: Hex;
}
export interface MetadataCitationOperationReceipt {
  readonly operation: MetadataCitationOperation;
  readonly transactionHash: Hex; readonly blockNumber: number; readonly blockHash: Hex;
  readonly events: readonly MetadataCitationEventReference[];
  readonly record: Snapshot["currentRecord"] | null;
  readonly stateAttribution: "events identify this operation; retained record read at block end";
}
const safeAbi = new Interface(["function execTransaction(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,bytes signatures) returns(bool)"]);
const safePlain = new Interface(["event ExecutionSuccess(bytes32 txHash,uint256 payment)", "event ExecutionFailure(bytes32 txHash,uint256 payment)"]);
const safeIndexed = new Interface(["event ExecutionSuccess(bytes32 indexed txHash,uint256 payment)", "event ExecutionFailure(bytes32 indexed txHash,uint256 payment)"]);
interface Log { address: Address; topics: Hex[]; data: Hex; index: number }
/**
 * Singleton direct/Safe CALL receipt verification. Eventless calldata publication needs prior-block retention.
 */
export async function inspectMetadataCitationOperationReceipt(p: ReceiptReader, input: MetadataCitationOperation,
  options: { readonly transactionHash: Hex; readonly execution: "direct" | "safe" }): Promise<MetadataCitationOperationReceipt> {
  keys(options, ["transactionHash", "execution"]);
  const o = operation(input), i = o.prepared.inspection, c = i.capture, d = c.deployment, b = o.prepared.batch;
  const transactionHash = hash(options.transactionHash), execution = options.execution;
  if (execution !== "direct" && execution !== "safe") throw Error("Unsupported receipt execution");
  await original(p, c);
  const [r, tx] = await Promise.all([p.getTransactionReceipt(transactionHash), p.getTransaction(transactionHash)]);
  if (!r || !tx || r.status !== 1 || !same(r.hash, transactionHash) || !same(tx.hash, transactionHash)
    || tx.chainId !== d.chainId || tx.value !== 0n || r.blockNumber <= c.blockNumber || tx.blockNumber !== r.blockNumber
    || !same(tx.blockHash, r.blockHash) || !same(tx.to, r.to) || !same(tx.from, r.from)) throw Error("Receipt/transaction identity or chronology differs");
  const data = bytes(tx.data, 262144);
  if (execution === "direct") {
    if (!same(tx.from, o.caller) || !same(tx.to, o.call.to) || !same(data, o.call.data)) throw Error("Direct call differs");
  } else {
    const decoded = safeAbi.decodeFunctionData("execTransaction", data);
    if (!same(tx.to, o.caller) || !same(safeAbi.encodeFunctionData("execTransaction", decoded), data)
      || !same(decoded[0], o.call.to) || decoded[1] !== 0n || !same(decoded[2], o.call.data) || decoded[3] !== 0n) throw Error("Safe requires exact ordinary zero-value CALL");
  }
  const tag = number(r.blockNumber), h = await context(p, d, tag);
  if (!same(h.blockHash, r.blockHash)) throw Error("Receipt block differs");
  if (!Array.isArray(r.logs) || r.logs.length > 256) throw Error("Receipt exceeds256 logs");
  const logs: Log[] = r.logs.map(l => {
    if (l.removed || !same(l.transactionHash, transactionHash) || l.blockNumber !== tag || !same(l.blockHash, h.blockHash)
      || !Array.isArray(l.topics) || l.topics.length > 4) throw Error("Malformed receipt log identity");
    return { address: address(l.address), topics: l.topics.map((x: string) => hash(x, true)), data: bytes(l.data, 32768), index: number(l.index) };
  });
  if (logs.some((l, n) => n > 0 && l.index <= logs[n - 1]!.index)) throw Error("Duplicate/unordered receipt logs");
  const refs: MetadataCitationEventReference[] = [];
  const found = (target: Address, name: string, iface = abi) => {
    const f = iface.getEvent(name)!;
    return logs.filter(l => same(l.address, target) && same(l.topics[0], f.topicHash)).map(log => {
      const args = iface.decodeEventLog(f, log.data, log.topics), encoded = iface.encodeEventLog(f, args);
      if (!same(encoded.data, log.data)) throw Error(`Noncanonical ${name} event data`);
      equal(encoded.topics.map(v => v.toLowerCase()), log.topics, `Noncanonical ${name} topics`);
      return { log, args: f.inputs.map((part, i) => plain(part, args[i])) };
    });
  };
  const reference = (log: Log, name: string) => {
    refs.push({ address: log.address, event: name, logIndex: log.index, transactionHash, blockHash: h.blockHash });
  };
  const one = (target: Address, name: string, expected: readonly unknown[]) => {
    const list = found(target, name);
    if (list.length !== 1) throw Error(`Expected exactly one ${name}`);
    equal(Array.from(list[0]!.args), expected, `${name} fields differ`);
    reference(list[0]!.log, name);
    return list[0]!.log.index;
  };

  let record: Snapshot["currentRecord"] | null = null;
  if (o.stage === "publish") {
    const pointer = await publication(p, b, tag);
    if (!pointer) throw Error("Publication not retained");
    const prior = await header(p, tag - 1);
    await runtime(p, d.governance, tag - 1);
    const previousPointer = await publication(p, b, tag - 1);
    if (previousPointer && !same(previousPointer, pointer)) throw Error("Immutable publication pointer changed");
    const events = found(d.governance.address, "GovernanceCallDataPublished");
    if (events.length) {
      if (previousPointer) throw Error("Repeat publication cannot emit first-save event");
      one(d.governance.address, "GovernanceCallDataPublished", [1n, b.publicationKey, pointer, o.caller]);
    } else if (!previousPointer) throw Error("Eventless publication requires previous-block proof");
    await unchanged(p, prior);
  } else {
    const liveGovernance = await governance(p, d, tag);
    equal(liveGovernance.catalog, c.catalog, "Receipt catalog differs from reviewed catalog");
    const state = await action(p, o, tag);
    const common = [1n, b.actionId, 1n, d.registry.address, 0n, i.plan.governanceCall.selector,
      b.callsHash, b.scopeHash, b.oldValueHash, b.newValueHash];
    const policyIndex = one(d.governance.address, "GovernanceActionPolicyValidated", [1n, b.actionId,
      o.stage === "schedule" ? 1n : 2n, c.catalog.candidateProfileHash, c.catalog.catalogHash]);
    if (o.stage === "schedule") {
      windowCheck(h.timestamp, b.window);
      if (![1n, 2n].includes(state.status) || liveGovernance.governanceNonce < b.nonce + 1n) throw Error("Scheduled action/nonce not retained");
      const scheduled = one(d.governance.address, "GovernanceActionScheduled", [...common, b.window.notBefore,
        b.window.expiresAfter, b.nonce, o.caller, b.window.reasonHash, b.window.reasonURI, b.window.manifestHash]);
      if (policyIndex <= scheduled) throw Error("Catalog validation event must follow scheduling");
      if (found(d.registry.address, "CurrentCitationRegistered").length) throw Error("Scheduling cannot register a citation");
    } else {
      if (state.status !== 3n || !same(state.executor, o.caller) || h.timestamp < b.window.notBefore || h.timestamp > b.window.expiresAfter) throw Error("Executed action/window differs");
      const registered = one(d.registry.address, "CurrentCitationRegistered", [1n, c.versionKey, d.renderer.address,
        b.actionId, i.plan.registrationHash, i.plan.registration, i.plan.reads]);
      const executed = one(d.governance.address, "GovernanceActionExecuted", [...common, o.caller, b.window.manifestHash]);
      if (!(registered < executed && executed < policyIndex)) throw Error("Original citation/governance event order differs");
      const current = await retained(p, d, c.versionKey, tag);
      record = current.snapshot.currentRecord;
      equal(record, { registration: i.plan.registration, registrationHash: i.plan.registrationHash, readSetHash: i.plan.readSetHash,
        analysisHash: i.evidence.analysisHash, goldenHash: i.evidence.goldenHash, actionId: b.actionId }, "Immutable current record differs");
      equal(current.currentReads, i.plan.reads, "Retained current reads differ");
      equal(current.snapshot.targets, c.snapshot.targets, "Immutable target inventory differs");
      equal({ ...current.snapshot.originalVersion, deprecated: c.snapshot.originalVersion.deprecated }, c.snapshot.originalVersion,
        "Original version identity changed");
    }
  }
  if (execution === "safe") {
    const successes = logs.filter(l => same(l.address, o.caller) && same(l.topics[0], safePlain.getEvent("ExecutionSuccess")!.topicHash));
    if (successes.length !== 1 || logs.some(l => same(l.address, o.caller) && same(l.topics[0], safePlain.getEvent("ExecutionFailure")!.topicHash))) throw Error("Safe requires one success and no failure");
    const log = successes[0]!, iface = log.topics.length === 2 ? safeIndexed : safePlain;
    const f = iface.getEvent("ExecutionSuccess")!, decoded = iface.decodeEventLog(f, log.data, log.topics), encoded = iface.encodeEventLog(f, decoded);
    if (!same(encoded.data, log.data)) throw Error("Noncanonical Safe success");
    equal(encoded.topics.map(v => v.toLowerCase()), log.topics);
    if (refs.some(r => r.logIndex >= log.index)) throw Error("Safe success must follow target/governance events");
    reference(log, "ExecutionSuccess");
  }
  await unchanged(p, h);
  return freeze({ operation: o, transactionHash, ...h, events: refs.sort((a, b) => a.logIndex - b.logIndex), record,
    stateAttribution: "events identify this operation; retained record read at block end" });
}
