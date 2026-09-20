import { Interface, ZeroAddress, getAddress, id, isHexString, keccak256, toQuantity } from "ethers";
import type { Provider } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import type { UnsignedCall } from "./client.js";
import { prepareReferenceInventory, referenceInventoryParts, REFERENCE_INVENTORY_MAX_BYTES } from "./current-reference-inventory.js";
import type { ReferenceInventorySnapshot, ReferenceInventoryPart } from "./current-reference-inventory.js";

export interface ReferenceInventoryCodePin { readonly address: Address; readonly codeHash: Hex }
export interface ReferenceInventoryDeployment {
  readonly chainId: bigint; readonly publicationHost: ReferenceInventoryCodePin; readonly store: ReferenceInventoryCodePin;
}
export interface ReferenceInventoryChunk {
  readonly index: number; readonly hash: Hex; readonly bytes: Hex;
}
export interface ReferenceInventoryStep {
  readonly index: number; readonly kind: "upload" | "part" | "assemble" | "monolithic";
  readonly caller: Address; readonly call: UnsignedCall; readonly identity: Hex;
  readonly chunkIndex: number | null; readonly documentIndex: number | null;
}
export interface PreparedReferenceInventoryPlan {
  readonly deployment: ReferenceInventoryDeployment; readonly preparer: Address; readonly uploader: Address;
  readonly mode: "monolithic" | "staged"; readonly snapshot: ReferenceInventorySnapshot;
  readonly parts: readonly ReferenceInventoryPart[]; readonly chunks: readonly ReferenceInventoryChunk[];
  readonly steps: readonly ReferenceInventoryStep[];
}
export interface ReferenceInventoryChunkAvailability {
  readonly index: number; readonly hash: Hex; readonly available: boolean; readonly pointer: Address;
  readonly byteLength: bigint;
}
export interface ReferenceInventoryStepStatus {
  readonly index: number; readonly status: "complete" | "ready" | "blocked" | "unnecessary"; readonly reason: string;
}
export interface ReferenceInventoryInspection {
  readonly plan: PreparedReferenceInventoryPlan; readonly blockNumber: number; readonly blockHash: Hex;
  readonly completed: boolean;
  /** Empty when the full inventory was already retained; no part history is inferred. */
  readonly parts: readonly { readonly index: number; readonly partId: Hex; readonly prepared: boolean }[];
  readonly chunkAvailability: readonly ReferenceInventoryChunkAvailability[];
  readonly steps: readonly ReferenceInventoryStepStatus[];
}
export interface ReferenceInventoryGasQuote {
  readonly inspection: ReferenceInventoryInspection; readonly step: ReferenceInventoryStep;
  readonly scope: "inner-call"; readonly estimatedGas: bigint;
  readonly maximumGas: bigint | null; readonly withinMaximum: boolean;
}
export interface ReferenceInventoryEventReference {
  readonly address: Address; readonly event: string; readonly logIndex: number;
  readonly transactionHash: Hex; readonly blockHash: Hex;
}
export interface ReferenceInventoryStepReceipt {
  readonly plan: PreparedReferenceInventoryPlan; readonly step: ReferenceInventoryStep;
  readonly transactionHash: Hex; readonly blockNumber: number; readonly blockHash: Hex;
  readonly identity: Hex; readonly events: readonly ReferenceInventoryEventReference[];
}
type Reader = Pick<Provider, "getNetwork" | "getBlock" | "getCode" | "call">;
type ReceiptReader = Reader & Pick<Provider, "getTransaction" | "getTransactionReceipt">;
export type ReferenceInventoryGasProvider = Reader & { send(method: string, params: unknown[]): Promise<unknown> };
const row = "tuple(string path,uint64 byteSize,bytes32 sha256Digest)[]";
const hostAbi = new Interface([
  `function prepareFileInventory(${row},bool) returns(bytes32)`,
  `function prepareFileInventoryPart(${row},bool) returns(bytes32)`,
  `function prepareFileInventoryFromParts(${row},bool) returns(bytes32)`,
  "function preparedFileInventory(bytes32) view returns(bytes)",
  "function deploymentChainId() view returns(uint256)",
  "function dependencies() view returns(tuple(address[7] targets,bytes32[7] codeHashes,uint256 chainId,bytes32 rendererCatalogId,bytes32 rendererCatalogHash,uint32 rendererCatalogBytes,uint256 readGas,uint256 sourceGas,uint256 snapshotGas,uint256 archiveGas))",
  "function supportsInterface(bytes4) pure returns(bool)",
  "event ReferenceInventoryPartPrepared(uint16 schemaVersion,bytes32 indexed partId,bool relative,uint16 rowCount,bytes32 contentHash,uint32 byteLength)",
  "event ReferenceInventoryAssembled(uint16 schemaVersion,bytes32 indexed inventoryId,bool relative,uint256 rowCount,bytes32 contentHash,uint32 byteLength)",
]);
const storeAbi = new Interface([
  "function MAX_CHUNK_BYTES() view returns(uint256)", "function chunk(bytes32) view returns(address pointer,uint32 length)",
  "function publishChunk(bytes) returns(bytes32 hash,address pointer)",
  "event ChunkPublished(bytes32 indexed hash,address indexed pointer,uint32 length)",
]);
const safeAbi = new Interface(["function execTransaction(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,bytes signatures) returns(bool)"]);
const safeLegacy = new Interface(["event ExecutionSuccess(bytes32 txHash,uint256 payment)", "event ExecutionFailure(bytes32 txHash,uint256 payment)"]);
const safeIndexed = new Interface(["event ExecutionSuccess(bytes32 indexed txHash,uint256 payment)", "event ExecutionFailure(bytes32 indexed txHash,uint256 payment)"]);
const invalidManifest = id("InvalidSnapshotManifest()").slice(0, 10);
const companionId = `0x${(BigInt(hostAbi.getFunction("prepareFileInventoryPart")!.selector) ^ BigInt(hostAbi.getFunction("prepareFileInventoryFromParts")!.selector)).toString(16).padStart(8, "0")}`;
const MAX_RPC = REFERENCE_INVENTORY_MAX_BYTES + 96;
function address(v: unknown, zero = false): Address { if (typeof v !== "string") throw Error("Expected address"); const a = getAddress(v) as Address; if (!zero && a === ZeroAddress) throw Error("Zero address"); return a; }
function hash(v: unknown): Hex { if (typeof v !== "string" || !isHexString(v, 32) || /^0x0{64}$/i.test(v)) throw Error("Expected nonzero bytes32"); return v.toLowerCase() as Hex; }
function bytes(v: unknown, max = MAX_RPC): Hex { if (typeof v !== "string" || !isHexString(v, true) || (v.length - 2) / 2 > max) throw Error("Malformed/oversized bytes"); return v.toLowerCase() as Hex; }
function uint(v: unknown, positive = false): bigint { if (typeof v !== "bigint" || v < (positive ? 1n : 0n) || v >= 1n << 256n) throw Error("Expected uint256 bigint"); return v; }
function integer(v: number): number { if (!Number.isSafeInteger(v) || v < 0) throw Error("Expected concrete nonnegative block/index"); return v; }
function same(a: unknown, b: unknown): boolean { return typeof a === "string" && typeof b === "string" && a.toLowerCase() === b.toLowerCase(); }
function stable(v: unknown): string { return JSON.stringify(v, (_, x: unknown) => typeof x === "bigint" ? `${x}n` : x && typeof x === "object" && !Array.isArray(x) ? Object.fromEntries(Object.entries(x).sort(([a], [b]) => a.localeCompare(b))) : x); }
function equal(a: unknown, b: unknown, label = "Prepared plan differs from canonical reconstruction"): void { if (stable(a) !== stable(b)) throw Error(label); }
function keys(v: unknown, names: readonly string[]): asserts v is Record<string, unknown> { if (!v || typeof v !== "object" || Array.isArray(v) || Object.keys(v).sort().join() !== [...names].sort().join()) throw Error("Missing/unknown properties"); }
function freeze<T>(v: T): T { if (v && typeof v === "object") { Object.values(v).forEach(freeze); Object.freeze(v); } return v; }
function call(to: Address, abi: Interface, name: string, args: readonly unknown[]): UnsignedCall { return Object.freeze({ to, value: 0n, data: abi.encodeFunctionData(name, args) as Hex }); }
function pin(v: ReferenceInventoryCodePin): ReferenceInventoryCodePin { keys(v, ["address", "codeHash"]); return Object.freeze({ address: address(v.address), codeHash: hash(v.codeHash) }); }
function deployment(v: ReferenceInventoryDeployment): ReferenceInventoryDeployment { keys(v, ["chainId", "publicationHost", "store"]); const d = Object.freeze({ chainId: uint(v.chainId, true), publicationHost: pin(v.publicationHost), store: pin(v.store) }); if (same(d.publicationHost.address, d.store.address)) throw Error("Host and Store must differ"); return d; }
function sliceChunks(canonical: Hex): { hash: Hex; bytes: Hex }[] { const chunks: { hash: Hex; bytes: Hex }[] = []; for (let offset = 2; offset < canonical.length; offset += 16384) { const raw = `0x${canonical.slice(offset, offset + 16384)}` as Hex; chunks.push({ hash: keccak256(raw) as Hex, bytes: raw }); } return chunks; }
/** Exact canonical arrays are uploaded before retention. Chunk deduplication never changes document ordering. */
export function prepareReferenceInventoryPlan(input: ReferenceInventoryDeployment, preparer: Address, snapshot: ReferenceInventorySnapshot, options: { readonly mode: "monolithic" | "staged"; readonly uploader?: Address }): PreparedReferenceInventoryPlan {
  const d = deployment(input), actor = address(preparer); keys(options, options.uploader === undefined ? ["mode"] : ["mode", "uploader"]);
  if (options.mode !== "monolithic" && options.mode !== "staged") throw Error("Unknown preparation mode");
  const uploader = address(options.uploader ?? actor), normalized = prepareReferenceInventory(d.chainId, d.publicationHost.address, snapshot.relative, snapshot.rows); equal(snapshot, normalized, "Inventory snapshot differs from canonical rows/coordinates");
  const parts = options.mode === "staged" ? referenceInventoryParts(normalized) : Object.freeze([]);
  const chunks: ReferenceInventoryChunk[] = [], steps: ReferenceInventoryStep[] = [], seen = new Set<string>();
  for (const canonical of [...parts.map(p => p.canonical), normalized.canonical]) for (const chunk of sliceChunks(canonical)) if (!seen.has(chunk.hash)) { seen.add(chunk.hash); chunks.push(Object.freeze({ index: chunks.length, ...chunk })); }
  for (const chunk of chunks) steps.push(Object.freeze({ index: steps.length, kind: "upload", caller: uploader, call: call(d.store.address, storeAbi, "publishChunk", [chunk.bytes]), identity: chunk.hash, chunkIndex: chunk.index, documentIndex: null }));
  for (const part of parts) steps.push(Object.freeze({ index: steps.length, kind: "part", caller: actor, call: call(d.publicationHost.address, hostAbi, "prepareFileInventoryPart", [part.rows, normalized.relative]), identity: part.partId, chunkIndex: null, documentIndex: part.index }));
  steps.push(Object.freeze({ index: steps.length, kind: options.mode === "staged" ? "assemble" : "monolithic", caller: actor, call: call(d.publicationHost.address, hostAbi, options.mode === "staged" ? "prepareFileInventoryFromParts" : "prepareFileInventory", [normalized.rows, normalized.relative]), identity: normalized.inventoryId, chunkIndex: null, documentIndex: null }));
  return freeze({ deployment: d, preparer: actor, uploader, mode: options.mode, snapshot: normalized, parts, chunks, steps });
}
function plan(v: PreparedReferenceInventoryPlan): PreparedReferenceInventoryPlan { const p = prepareReferenceInventoryPlan(v.deployment, v.preparer, v.snapshot, { mode: v.mode, uploader: v.uploader }); equal(v, p); return p; }
function step(p: PreparedReferenceInventoryPlan, index: number): ReferenceInventoryStep { integer(index); const s = p.steps[index]; if (!s) throw Error("Step outside plan"); return s; }
async function rpc(provider: Pick<Provider, "call">, target: Address, abi: Interface, method: string, args: readonly unknown[], tag: number, from?: Address): Promise<readonly unknown[]> {
  const raw = bytes(await provider.call({ ...call(target, abi, method, args), blockTag: tag, ...(from ? { from } : {}) }));
  const out = abi.decodeFunctionResult(method, raw); if (!same(abi.encodeFunctionResult(method, out), raw)) throw Error(`Noncanonical ${method} return`); return out;
}
async function header(provider: Pick<Provider, "getBlock">, tag: number): Promise<{ number: number; hash: Hex }> { const b = await provider.getBlock(tag); if (!b || b.number !== tag) throw Error("Missing/mismatched block"); return Object.freeze({ number: tag, hash: hash(b.hash) }); }
async function unchanged(provider: Pick<Provider, "getBlock">, h: { number: number; hash: Hex }): Promise<void> { equal(await header(provider, h.number), h, "Pinned block changed"); }
async function context(provider: Reader, p: PreparedReferenceInventoryPlan, tag: number): Promise<{ number: number; hash: Hex }> {
  const d = p.deployment; if ((await provider.getNetwork()).chainId !== d.chainId) throw Error("RPC chain mismatch"); const h = await header(provider, tag);
  await Promise.all([d.publicationHost, d.store].map(async expected => { const code = bytes(await provider.getCode(expected.address, tag), 65536); if (code === "0x" || !same(keccak256(code), expected.codeHash)) throw Error("Runtime code pin mismatch"); }));
  const [[chain], [dependencies], [maximum]] = await Promise.all([rpc(provider, d.publicationHost.address, hostAbi, "deploymentChainId", [], tag), rpc(provider, d.publicationHost.address, hostAbi, "dependencies", [], tag), rpc(provider, d.store.address, storeAbi, "MAX_CHUNK_BYTES", [], tag)]);
  const dep = dependencies as { chainId: bigint; targets: readonly string[]; codeHashes: readonly string[] };
  if (chain !== d.chainId || dep.chainId !== d.chainId || !same(dep.targets[3], d.store.address) || !same(dep.codeHashes[3], d.store.codeHash) || maximum !== 8192n) throw Error("Configured producer/Store dependencies differ");
  if (p.mode === "staged") { const [supported] = await rpc(provider, d.publicationHost.address, hostAbi, "supportsInterface", [companionId], tag); if (supported !== true) throw Error("Host does not support staged inventory preparation"); }
  return h;
}
async function retained(provider: Reader, p: PreparedReferenceInventoryPlan, identity: Hex, expected: Hex, tag: number): Promise<boolean> {
  let raw: readonly unknown[];
  try { raw = await rpc(provider, p.deployment.publicationHost.address, hostAbi, "preparedFileInventory", [identity], tag); }
  catch (error) { const e = error as { code?: unknown; data?: unknown }; if (e.code === "CALL_EXCEPTION" && same(e.data, invalidManifest)) return false; throw error; }
  if (!same(bytes(raw[0], REFERENCE_INVENTORY_MAX_BYTES), expected)) throw Error("Retained inventory bytes differ from exact canonical document"); return true;
}
async function chunkAvailability(provider: Reader, p: PreparedReferenceInventoryPlan, chunk: ReferenceInventoryChunk, tag: number): Promise<ReferenceInventoryChunkAvailability> {
  const [target, length] = await rpc(provider, p.deployment.store.address, storeAbi, "chunk", [chunk.hash], tag), pointer = address(target, true), byteLength = uint(length);
  if (pointer === ZeroAddress) { if (byteLength !== 0n) throw Error("Missing chunk has nonzero length"); return Object.freeze({ index: chunk.index, hash: chunk.hash, available: false, pointer, byteLength }); }
  if (byteLength !== BigInt((chunk.bytes.length - 2) / 2)) throw Error("Store chunk length differs");
  const code = bytes(await provider.getCode(pointer, tag), 8193);
  if (!same(code, `0x00${chunk.bytes.slice(2)}`)) throw Error("Store pointer runtime differs from STOP plus exact chunk bytes");
  return Object.freeze({ index: chunk.index, hash: chunk.hash, available: true, pointer, byteLength });
}
/** Reads the final original inventory first: an existing monolithic result needs no invented part history. */
export async function inspectReferenceInventoryPreparation(provider: Reader, input: PreparedReferenceInventoryPlan, options: { readonly blockTag: number }): Promise<ReferenceInventoryInspection> {
  const p = plan(input), tag = integer(options.blockTag), h = await context(provider, p, tag);
  if (await retained(provider, p, p.snapshot.inventoryId, p.snapshot.canonical, tag)) {
    await unchanged(provider, h); return freeze({ plan: p, blockNumber: tag, blockHash: h.hash, completed: true, parts: [], chunkAvailability: [], steps: p.steps.map(s => ({ index: s.index, status: s.kind === "assemble" || s.kind === "monolithic" ? "complete" as const : "unnecessary" as const, reason: s.kind === "assemble" || s.kind === "monolithic" ? "Original inventory already retained" : "No further step needed; part/upload history was not inferred" })) });
  }
  const parts: { readonly index: number; readonly partId: Hex; readonly prepared: boolean }[] = [];
  for (const part of p.parts) parts.push(Object.freeze({ index: part.index, partId: part.partId, prepared: await retained(provider, p, part.partId, part.canonical, tag) }));
  const availability: ReferenceInventoryChunkAvailability[] = [];
  for (const chunk of p.chunks) availability.push(await chunkAvailability(provider, p, chunk, tag));
  const available = new Set(availability.filter(c => c.available).map(c => c.hash));
  const completeChunks = (raw: Hex) => sliceChunks(raw).every(c => available.has(c.hash));
  const statuses = p.steps.map(s => {
    const complete = s.kind === "upload" ? availability[s.chunkIndex!]!.available : s.kind === "part" ? parts[s.documentIndex!]!.prepared : false;
    const ready = s.kind === "upload" || s.kind === "part" ? s.kind === "upload" || completeChunks(p.parts[s.documentIndex!]!.canonical) : completeChunks(p.snapshot.canonical) && (s.kind === "monolithic" || parts.every(part => part.prepared));
    return Object.freeze({ index: s.index, status: complete ? "complete" as const : ready ? "ready" as const : "blocked" as const, reason: complete ? "Exact retained bytes verified" : ready ? "Current prerequisites available" : "Required chunks or fixed parts are unavailable" });
  });
  await unchanged(provider, h); return freeze({ plan: p, blockNumber: tag, blockHash: h.hash, completed: false, parts, chunkAvailability: availability, steps: statuses });
}
async function executable(provider: Reader, p: PreparedReferenceInventoryPlan, index: number, tag: number): Promise<ReferenceInventoryInspection> {
  const s = step(p, index), inspection = await inspectReferenceInventoryPreparation(provider, p, { blockTag: tag });
  if (inspection.completed && s.kind !== "assemble" && s.kind !== "monolithic") throw Error("Original inventory is complete; no part/upload execution is needed");
  if (inspection.steps[index]!.status === "blocked") throw Error("Step prerequisites unavailable at pinned block"); return inspection;
}
async function simulate(provider: Reader, p: PreparedReferenceInventoryPlan, s: ReferenceInventoryStep, tag: number): Promise<{ identity: Hex; pointer: Address | null }> {
  const abi = s.kind === "upload" ? storeAbi : hostAbi, fn = abi.getFunction(s.call.data.slice(0, 10))!, args = abi.decodeFunctionData(fn, s.call.data);
  const raw = await rpc(provider, s.call.to, abi, fn.name, [...args], tag, s.caller);
  if (!same(raw[0], s.identity)) throw Error("Simulated step identity differs");
  return Object.freeze({ identity: s.identity, pointer: s.kind === "upload" ? address(raw[1]) : null });
}
export async function simulateReferenceInventoryStep(provider: Reader, input: PreparedReferenceInventoryPlan, stepIndex: number, options: { readonly blockTag: number }): Promise<{ readonly identity: Hex; readonly pointer: Address | null }> {
  const p = plan(input), s = step(p, stepIndex), tag = integer(options.blockTag), inspection = await executable(provider, p, stepIndex, tag), result = await simulate(provider, p, s, tag);
  if (!same((await header(provider, tag)).hash, inspection.blockHash)) throw Error("Simulation block changed"); return result;
}
/** Pinned eth_estimateGas for this inner zero-value CALL, excluding Safe envelope/signature gas. */
export async function quoteReferenceInventoryStepGas(provider: ReferenceInventoryGasProvider, input: PreparedReferenceInventoryPlan, stepIndex: number, options: { readonly blockTag: number; readonly maximumGas?: bigint }): Promise<ReferenceInventoryGasQuote> {
  const p = plan(input), s = step(p, stepIndex), tag = integer(options.blockTag), maximumGas = options.maximumGas === undefined ? null : uint(options.maximumGas, true);
  const inspection = await executable(provider, p, stepIndex, tag); await simulate(provider, p, s, tag);
  const raw = await provider.send("eth_estimateGas", [{ from: s.caller, to: s.call.to, data: s.call.data, value: "0x0" }, toQuantity(tag)]);
  if (typeof raw !== "string" || !/^0x[1-9a-f][0-9a-f]*$/.test(raw) || raw.length > 66) throw Error("Noncanonical gas estimate quantity");
  const estimatedGas = uint(BigInt(raw), true); if (!same((await header(provider, tag)).hash, inspection.blockHash)) throw Error("Gas quote block changed");
  return freeze({ inspection, step: s, scope: "inner-call", estimatedGas, maximumGas, withinMaximum: maximumGas === null || estimatedGas <= maximumGas });
}

/** Bind one mined direct transaction or Safe ordinary CALL to exact retained bytes. Repeats may emit no preparation event. */
export async function inspectReferenceInventoryStepReceipt(provider: ReceiptReader, input: PreparedReferenceInventoryPlan, stepIndex: number, evidence: { readonly transactionHash: Hex; readonly execution: "direct" | "safe" }): Promise<ReferenceInventoryStepReceipt> {
  const p = plan(input), s = step(p, stepIndex); keys(evidence, ["transactionHash", "execution"]);
  const transactionHash = hash(evidence.transactionHash), mode = evidence.execution;
  if (mode !== "direct" && mode !== "safe") throw Error("Unknown receipt execution mode");
  const [tx, receipt] = await Promise.all([provider.getTransaction(transactionHash), provider.getTransactionReceipt(transactionHash)]);
  if (!tx || !receipt || !same(tx.hash, transactionHash) || !same(receipt.hash, transactionHash) || receipt.status !== 1 || tx.blockNumber === null || !tx.blockHash || receipt.blockNumber !== tx.blockNumber || !same(receipt.blockHash, tx.blockHash) || tx.value !== 0n || !tx.to) throw Error("Successful mined transaction/receipt identity differs");
  const tag = integer(receipt.blockNumber), blockHash = hash(receipt.blockHash), data = bytes(tx.data, 2000000);
  if (mode === "direct") { if (!same(tx.from, s.caller) || !same(tx.to, s.call.to) || !same(data, s.call.data)) throw Error("Direct step CALL differs"); }
  else {
    if (!same(tx.to, s.caller)) throw Error("Safe caller differs"); const q = safeAbi.decodeFunctionData("execTransaction", data);
    if (!same(safeAbi.encodeFunctionData("execTransaction", q), data) || !same(q.to, s.call.to) || q.value !== 0n || q.operation !== 0n || !same(q.data, s.call.data)) throw Error("Safe envelope differs from exact zero ordinary CALL");
  }
  if (!Array.isArray(receipt.logs) || receipt.logs.length > 256) throw Error("Receipt log client bound exceeded");
  let last = -1;
  const logs = receipt.logs.map(l => {
    if (l.removed || l.blockNumber !== tag || !same(l.blockHash, blockHash) || !same(l.transactionHash, transactionHash) || integer(l.index) <= last || l.topics.length < 1 || l.topics.length > 4) throw Error("Receipt log identity/order differs");
    last = l.index; return Object.freeze({ address: address(l.address), data: bytes(l.data, 16384), topics: Object.freeze(l.topics.map((v: string) => { if (!isHexString(v, 32)) throw Error("Malformed receipt topic"); return v.toLowerCase() as Hex; })), index: l.index });
  });
  const refs: ReferenceInventoryEventReference[] = [];
  const parse = (target: Address, abi: Interface, name: string) => {
    const fragment = abi.getEvent(name)!;
    return logs.filter(l => same(l.address, target) && same(l.topics[0], fragment.topicHash)).map(l => {
      const decoded = abi.decodeEventLog(fragment, l.data, [...l.topics]), canonical = abi.encodeEventLog(fragment, decoded);
      if (!same(canonical.data, l.data)) throw Error(`Noncanonical ${name} event`); equal(canonical.topics.map(t => t.toLowerCase()), l.topics, `Noncanonical ${name} topics`);
      return { decoded, ref: Object.freeze({ address: target, event: name, logIndex: l.index, transactionHash, blockHash }) };
    });
  };
  if (mode === "safe") {
    const success = logs.filter(l => same(l.address, s.caller) && same(l.topics[0], safeLegacy.getEvent("ExecutionSuccess")!.topicHash));
    if (success.length !== 1 || logs.some(l => same(l.address, s.caller) && same(l.topics[0], safeLegacy.getEvent("ExecutionFailure")!.topicHash))) throw Error("Expected one Safe ExecutionSuccess and no ExecutionFailure");
    const parsed = parse(s.caller, success[0]!.topics.length === 2 ? safeIndexed : safeLegacy, "ExecutionSuccess")[0]!; hash(parsed.decoded.txHash); refs.push(parsed.ref);
  }
  for (const name of ["ReferenceInventoryPartPrepared", "ReferenceInventoryAssembled"] as const) {
    const expected = s.kind === "part" ? "ReferenceInventoryPartPrepared" : s.kind === "assemble" ? "ReferenceInventoryAssembled" : null;
    if (name !== expected && logs.some(l => same(l.address, p.deployment.publicationHost.address) && same(l.topics[0], hostAbi.getEvent(name)!.topicHash))) throw Error("Unexpected preparation event for this step");
  }
  const h = await context(provider, p, tag); if (!same(h.hash, blockHash)) throw Error("Receipt block is not canonical");
  if (s.kind === "upload") {
    const chunk = p.chunks[s.chunkIndex!]!, available = await chunkAvailability(provider, p, chunk, tag);
    if (!available.available) throw Error("Mined uploaded chunk unavailable");
    const emitted = parse(p.deployment.store.address, storeAbi, "ChunkPublished"); if (emitted.length > 1) throw Error("Duplicate chunk publication events");
    for (const e of emitted) { if (!same(e.decoded.hash, s.identity) || !same(e.decoded.pointer, available.pointer) || e.decoded[2] !== available.byteLength) throw Error("Chunk publication event differs from retained bytes"); refs.push(e.ref); }
  } else {
    const doc = s.kind === "part" ? p.parts[s.documentIndex!]! : p.snapshot;
    if (!await retained(provider, p, s.identity, doc.canonical, tag)) throw Error("Mined preparation unavailable");
    if (s.kind !== "monolithic") {
      const name = s.kind === "part" ? "ReferenceInventoryPartPrepared" : "ReferenceInventoryAssembled", emitted = parse(p.deployment.publicationHost.address, hostAbi, name);
      if (emitted.length > 1) throw Error("Duplicate preparation events");
      for (const e of emitted) {
        const v = e.decoded;
        if (v.schemaVersion !== 1n || !same(v[1], s.identity) || v.relative !== p.snapshot.relative || v.rowCount !== BigInt(doc.rows.length) || !same(v.contentHash, doc.contentHash) || v.byteLength !== doc.byteLength) throw Error("Preparation event differs from original canonical document"); refs.push(e.ref);
      }
    }
  }
  await unchanged(provider, h); return freeze({ plan: p, step: s, transactionHash, blockNumber: tag, blockHash, identity: s.identity, events: refs.sort((a, b) => a.logIndex - b.logIndex) });
}
