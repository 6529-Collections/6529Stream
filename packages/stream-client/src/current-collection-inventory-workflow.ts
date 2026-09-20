import { Interface, ZeroAddress, getAddress, isHexString, keccak256 } from "ethers";
import type { Provider } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import type { UnsignedCall } from "./client.js";
import {
  normalizeCollectionInventoryCoordinates, normalizeCollectionInventoryCheckpoint,
  normalizeCollectionInventoryCoreIdentity, decodeCollectionInventoryCoreIdentity,
  replayCollectionInventoryAppend, replayCollectionInventoryScan,
} from "./current-collection-inventory.js";
import type {
  CollectionInventoryCoordinates, CollectionInventoryCheckpoint, CollectionInventoryCoreIdentity,
  CollectionInventoryReplay, CollectionInventoryScanReplay,
} from "./current-collection-inventory.js";

export interface CollectionInventoryCodePin { readonly address: Address; readonly codeHash: Hex }
export interface CollectionInventoryDeployment {
  readonly chainId: bigint; readonly inventory: CollectionInventoryCodePin; readonly core: CollectionInventoryCodePin;
}
export interface CollectionInventoryCapture {
  readonly deployment: CollectionInventoryDeployment; readonly coordinates: CollectionInventoryCoordinates;
  readonly blockNumber: number; readonly blockHash: Hex; readonly checkpoint: CollectionInventoryCheckpoint;
  readonly lastIndexedToken: CollectionInventoryCoreIdentity | null;
  readonly frontier: bigint; readonly mintedEver: bigint;
  /** Completeness at this block, never a statement that minting or finality is closed. */
  readonly complete: boolean;
}
interface OperationBase { readonly capture: CollectionInventoryCapture; readonly caller: Address; readonly call: UnsignedCall }
export interface PreparedCollectionInventoryAppend extends OperationBase { readonly kind: "append"; readonly tokenIds: readonly bigint[] }
export interface PreparedCollectionInventoryScan extends OperationBase { readonly kind: "scan"; readonly maxScan: bigint }
export type PreparedCollectionInventoryOperation = PreparedCollectionInventoryAppend | PreparedCollectionInventoryScan;
export interface CollectionInventorySimulation {
  readonly plan: PreparedCollectionInventoryOperation; readonly capture: CollectionInventoryCapture;
  readonly identities: readonly CollectionInventoryCoreIdentity[];
  readonly replay: CollectionInventoryReplay | CollectionInventoryScanReplay;
}
export interface CollectionInventoryPrefixMember {
  readonly capture: CollectionInventoryCapture; readonly observed: CollectionInventoryCapture;
  readonly collectionSerial: bigint; readonly lookupTokenId: bigint;
  readonly status: "member" | "not-indexed" | "outside-prefix";
  readonly ordinal: bigint | null; readonly identity: CollectionInventoryCoreIdentity | null;
}
export interface CollectionInventoryEventReference {
  readonly address: Address; readonly event: string; readonly logIndex: number;
  readonly transactionHash: Hex; readonly blockHash: Hex;
}
export interface CollectionInventoryOperationReceipt {
  readonly plan: PreparedCollectionInventoryOperation; readonly transactionHash: Hex;
  readonly blockNumber: number; readonly blockHash: Hex;
  /** Prior-block deterministic expectation; scan return data is not present in an ordinary receipt. */
  readonly replay: CollectionInventoryReplay | CollectionInventoryScanReplay;
  readonly observed: CollectionInventoryCapture;
  readonly cursorAttribution: "not-proven";
  readonly events: readonly CollectionInventoryEventReference[];
}
type Reader = Pick<Provider, "call" | "getNetwork" | "getCode" | "getBlock">;
type ReceiptReader = Reader & Pick<Provider, "getTransaction" | "getTransactionReceipt">;
const inventoryAbi = new Interface([
  "function core() view returns(address)", "function coreCodeHash() view returns(bytes32)", "function deploymentChainId() view returns(uint256)",
  "function MAX_INDEX_BATCH() view returns(uint256)", "function collectionInventoryState(uint256) view returns(uint256 indexedCount,bytes32 prefixHash)",
  "function collectionScanThrough(uint256) view returns(uint256)", "function collectionTokenAt(uint256,uint256) view returns(uint256)",
  "function collectionTokenBySerial(uint256,uint256) view returns(uint256)", "function requireCompleteCollection(uint256) view returns(uint256 tokenCount,bytes32 prefixHash)",
  "function appendCollectionTokens(uint256,uint256[])", "function scanCollectionTokens(uint256,uint256) returns(uint256 scannedThrough,uint256 indexedCount,bytes32 prefixHash)",
  "event CollectionTokenIndexed(uint256 indexed collectionId,uint256 indexed tokenId,uint256 collectionSerial,bytes32 prefixHash)",
]);
const coreAbi = new Interface([
  "function collectionExists(uint256) view returns(bool)", "function collectionMintedEver(uint256) view returns(uint256)", "function lastAllocatedTokenId() view returns(uint256)",
  "function tokenCollectionIdentity(uint256) view returns(bool mappingExists,uint256 collectionId,uint256 collectionSerial,bool burned)", "function tokenLifecycle(uint256) view returns(uint8)",
]);
const safeAbi = new Interface(["function execTransaction(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,bytes signatures) returns(bool)"]);
const safeLegacy = new Interface(["event ExecutionSuccess(bytes32 txHash,uint256 payment)", "event ExecutionFailure(bytes32 txHash,uint256 payment)"]);
const safeIndexed = new Interface(["event ExecutionSuccess(bytes32 indexed txHash,uint256 payment)", "event ExecutionFailure(bytes32 indexed txHash,uint256 payment)"]);
function address(v: unknown): Address { if (typeof v !== "string") throw Error("Expected address"); const a = getAddress(v) as Address; if (a === ZeroAddress) throw Error("Zero address"); return a; }
function hash(v: unknown): Hex { if (typeof v !== "string" || !isHexString(v, 32) || /^0x0{64}$/i.test(v)) throw Error("Expected nonzero bytes32"); return v.toLowerCase() as Hex; }
function bytes(v: unknown, max = 16384): Hex { if (typeof v !== "string" || !isHexString(v, true) || (v.length - 2) / 2 > max) throw Error("Malformed or oversized bytes"); return v.toLowerCase() as Hex; }
function uint(v: unknown, positive = false): bigint { if (typeof v !== "bigint" || v < (positive ? 1n : 0n) || v >= 1n << 256n) throw Error("Expected uint256 bigint"); return v; }
function integer(v: number): number { if (!Number.isSafeInteger(v) || v < 0) throw Error("Expected concrete nonnegative block/index"); return v; }
function keys(v: unknown, names: readonly string[]): asserts v is Record<string, unknown> { if (!v || typeof v !== "object" || Array.isArray(v) || Object.keys(v).sort().join() !== [...names].sort().join()) throw Error("Missing/unknown properties"); }
function same(a: unknown, b: unknown): boolean { return typeof a === "string" && typeof b === "string" && a.toLowerCase() === b.toLowerCase(); }
function stable(v: unknown): string { return JSON.stringify(v, (_, x: unknown) => typeof x === "bigint" ? `${x}n` : x && typeof x === "object" && !Array.isArray(x) ? Object.fromEntries(Object.entries(x).sort(([a], [b]) => a.localeCompare(b))) : x); }
function equal(a: unknown, b: unknown, message = "Prepared snapshot differs from canonical reconstruction"): void { if (stable(a) !== stable(b)) throw Error(message); }
function freeze<T>(v: T): T { if (v && typeof v === "object") { Object.values(v).forEach(freeze); Object.freeze(v); } return v; }
function pin(v: CollectionInventoryCodePin): CollectionInventoryCodePin { keys(v, ["address", "codeHash"]); return Object.freeze({ address: address(v.address), codeHash: hash(v.codeHash) }); }
function deployment(v: CollectionInventoryDeployment): CollectionInventoryDeployment { keys(v, ["chainId", "inventory", "core"]); const d = Object.freeze({ chainId: uint(v.chainId, true), inventory: pin(v.inventory), core: pin(v.core) }); if (same(d.inventory.address, d.core.address)) throw Error("Inventory and Core must differ"); return d; }
function call(to: Address, abi: Interface, method: string, args: readonly unknown[]): UnsignedCall { return Object.freeze({ to, value: 0n, data: abi.encodeFunctionData(method, args) as Hex }); }
async function raw(provider: Pick<Provider, "call">, target: Address, abi: Interface, method: string, args: readonly unknown[], tag: number, from?: Address): Promise<Hex> { return bytes(await provider.call({ ...call(target, abi, method, args), blockTag: tag, ...(from ? { from } : {}) })); }
async function rpc(provider: Pick<Provider, "call">, target: Address, abi: Interface, method: string, args: readonly unknown[], tag: number, from?: Address): Promise<readonly unknown[]> { const value = await raw(provider, target, abi, method, args, tag, from), out = abi.decodeFunctionResult(method, value); if (!same(abi.encodeFunctionResult(method, out), value)) throw Error(`Noncanonical ${method} return`); return out; }
async function header(provider: Pick<Provider, "getBlock">, tag: number): Promise<{ number: number; hash: Hex }> { const b = await provider.getBlock(tag); if (!b || b.number !== tag) throw Error("Missing/mismatched block"); return Object.freeze({ number: tag, hash: hash(b.hash) }); }
async function unchanged(provider: Pick<Provider, "getBlock">, h: { number: number; hash: Hex }): Promise<void> { equal(await header(provider, h.number), h, "Pinned block changed"); }
async function context(provider: Reader, d: CollectionInventoryDeployment, tag: number): Promise<{ number: number; hash: Hex }> {
  if ((await provider.getNetwork()).chainId !== d.chainId) throw Error("RPC chain mismatch"); const h = await header(provider, tag);
  await Promise.all([d.inventory, d.core].map(async p => { const code = bytes(await provider.getCode(p.address, tag), 65536); if (code === "0x" || !same(keccak256(code), p.codeHash)) throw Error("Pinned runtime changed"); }));
  const [[core], [codeHash], [chain], [maximum]] = await Promise.all([rpc(provider, d.inventory.address, inventoryAbi, "core", [], tag), rpc(provider, d.inventory.address, inventoryAbi, "coreCodeHash", [], tag), rpc(provider, d.inventory.address, inventoryAbi, "deploymentChainId", [], tag), rpc(provider, d.inventory.address, inventoryAbi, "MAX_INDEX_BATCH", [], tag)]);
  if (!same(core, d.core.address) || !same(codeHash, d.core.codeHash) || chain !== d.chainId || maximum !== 256n) throw Error("Inventory deployment binding differs"); return h;
}
async function identity(provider: Reader, d: CollectionInventoryDeployment, tokenId: bigint, tag: number): Promise<CollectionInventoryCoreIdentity> {
  const [mapped, lifecycle] = await Promise.all([raw(provider, d.core.address, coreAbi, "tokenCollectionIdentity", [tokenId], tag), raw(provider, d.core.address, coreAbi, "tokenLifecycle", [tokenId], tag)]);
  return decodeCollectionInventoryCoreIdentity(tokenId, mapped, lifecycle);
}
function capture(value: CollectionInventoryCapture): CollectionInventoryCapture {
  keys(value, ["deployment", "coordinates", "blockNumber", "blockHash", "checkpoint", "lastIndexedToken", "frontier", "mintedEver", "complete"]);
  const d = deployment(value.deployment), coordinates = normalizeCollectionInventoryCoordinates(value.coordinates);
  if (coordinates.chainId !== d.chainId || !same(coordinates.inventory, d.inventory.address) || !same(coordinates.core, d.core.address)) throw Error("Capture coordinates differ");
  const checkpoint = normalizeCollectionInventoryCheckpoint(coordinates, value.checkpoint), frontier = uint(value.frontier), mintedEver = uint(value.mintedEver);
  const lastIndexedToken = value.lastIndexedToken === null ? null : normalizeCollectionInventoryCoreIdentity(value.lastIndexedToken);
  if (checkpoint.scanThrough > frontier || checkpoint.indexedCount > mintedEver || value.complete !== (checkpoint.indexedCount === mintedEver)) throw Error("Capture count/frontier/completeness differs");
  if (checkpoint.indexedCount === 0n) { if (lastIndexedToken !== null) throw Error("Empty capture has a last token"); }
  else if (!lastIndexedToken || !lastIndexedToken.mappingExists || lastIndexedToken.collectionId !== coordinates.collectionId || lastIndexedToken.collectionSerial !== checkpoint.lastIndexedSerial || lastIndexedToken.lifecycle < 2n || lastIndexedToken.tokenId > checkpoint.scanThrough) throw Error("Capture last ordinal/actual serial differs");
  return freeze({ deployment: d, coordinates, blockNumber: integer(value.blockNumber), blockHash: hash(value.blockHash), checkpoint, lastIndexedToken, frontier, mintedEver, complete: value.complete });
}
/** Captures current completeness separately from cursor progress. A prepared mint does not increment mintedEver. */
export async function captureCollectionInventory(provider: Reader, input: CollectionInventoryDeployment, collectionId: bigint, options: { readonly blockTag: number }): Promise<CollectionInventoryCapture> {
  const d = deployment(input), cid = uint(collectionId, true), tag = integer(options.blockTag), h = await context(provider, d, tag);
  const coordinates = normalizeCollectionInventoryCoordinates({ chainId: d.chainId, inventory: d.inventory.address, core: d.core.address, collectionId: cid });
  const [state, [cursor], [exists], [frontierValue], [mintedValue]] = await Promise.all([rpc(provider, d.inventory.address, inventoryAbi, "collectionInventoryState", [cid], tag), rpc(provider, d.inventory.address, inventoryAbi, "collectionScanThrough", [cid], tag), rpc(provider, d.core.address, coreAbi, "collectionExists", [cid], tag), rpc(provider, d.core.address, coreAbi, "lastAllocatedTokenId", [], tag), rpc(provider, d.core.address, coreAbi, "collectionMintedEver", [cid], tag)]);
  if (exists !== true) throw Error("Unknown collection"); const indexedCount = uint(state[0]), prefixHash = hash(state[1]), scanThrough = uint(cursor), frontier = uint(frontierValue), mintedEver = uint(mintedValue);
  let lastIndexedToken: CollectionInventoryCoreIdentity | null = null;
  if (indexedCount !== 0n) { const [token] = await rpc(provider, d.inventory.address, inventoryAbi, "collectionTokenAt", [cid, indexedCount - 1n], tag); lastIndexedToken = await identity(provider, d, uint(token, true), tag); const [bySerial] = await rpc(provider, d.inventory.address, inventoryAbi, "collectionTokenBySerial", [cid, lastIndexedToken.collectionSerial], tag); if (bySerial !== lastIndexedToken.tokenId) throw Error("Last ordinal differs from actual-serial lookup"); }
  const checkpoint = normalizeCollectionInventoryCheckpoint(coordinates, { indexedCount, prefixHash, lastIndexedSerial: lastIndexedToken?.collectionSerial ?? 0n, scanThrough });
  if (indexedCount === mintedEver) { const complete = await rpc(provider, d.inventory.address, inventoryAbi, "requireCompleteCollection", [cid], tag); equal([...complete], [indexedCount, prefixHash], "Completeness getter differs"); }
  const out = capture({ deployment: d, coordinates, blockNumber: tag, blockHash: h.hash, checkpoint, lastIndexedToken, frontier, mintedEver, complete: indexedCount === mintedEver }); await unchanged(provider, h); return out;
}
export function prepareCollectionInventoryAppend(input: CollectionInventoryCapture, caller: Address, tokenIds: readonly bigint[]): PreparedCollectionInventoryAppend {
  const c = capture(input), actor = address(caller); if (!Array.isArray(tokenIds) || tokenIds.length < 1 || tokenIds.length > 256) throw Error("Append requires 1..256 token IDs");
  const ids = tokenIds.map(v => uint(v, true)); let previous = c.checkpoint.scanThrough; for (const token of ids) { if (token <= previous || token > c.frontier) throw Error("Append token IDs must increase after cursor within captured frontier"); previous = token; }
  return freeze({ capture: c, caller: actor, kind: "append", tokenIds: ids, call: call(c.deployment.inventory.address, inventoryAbi, "appendCollectionTokens", [c.coordinates.collectionId, ids]) });
}
export function prepareCollectionInventoryScan(input: CollectionInventoryCapture, caller: Address, maxScan: bigint): PreparedCollectionInventoryScan {
  const c = capture(input), actor = address(caller), maximum = uint(maxScan, true); if (maximum > 256n) throw Error("Scan requires 1..256 IDs");
  return freeze({ capture: c, caller: actor, kind: "scan", maxScan: maximum, call: call(c.deployment.inventory.address, inventoryAbi, "scanCollectionTokens", [c.coordinates.collectionId, maximum]) });
}
function plan(input: PreparedCollectionInventoryOperation): PreparedCollectionInventoryOperation {
  const out = input.kind === "append" ? prepareCollectionInventoryAppend(input.capture, input.caller, input.tokenIds) : input.kind === "scan" ? prepareCollectionInventoryScan(input.capture, input.caller, input.maxScan) : null;
  if (!out) throw Error("Unknown inventory operation"); equal(input, out); return out;
}
async function replay(provider: Reader, p: PreparedCollectionInventoryOperation, tag: number): Promise<CollectionInventoryReplay | CollectionInventoryScanReplay> {
  const c = p.capture, tokens = p.kind === "append" ? [...p.tokenIds] : Array.from({ length: Number(c.frontier - c.checkpoint.scanThrough < p.maxScan ? c.frontier - c.checkpoint.scanThrough : p.maxScan) }, (_, i) => c.checkpoint.scanThrough + BigInt(i) + 1n);
  const facts: CollectionInventoryCoreIdentity[] = []; for (const tokenId of tokens) facts.push(await identity(provider, c.deployment, tokenId, tag));
  return p.kind === "append" ? replayCollectionInventoryAppend(c.coordinates, c.checkpoint, facts) : replayCollectionInventoryScan(c.coordinates, c.checkpoint, c.frontier, p.maxScan, facts);
}
async function original(provider: Reader, input: CollectionInventoryCapture): Promise<void> {
  const actual = await captureCollectionInventory(provider, input.deployment, input.coordinates.collectionId, { blockTag: input.blockNumber }); equal(actual, input, "Saved checkpoint or its historical block changed");
}
export async function simulateCollectionInventoryOperation(provider: Reader, input: PreparedCollectionInventoryOperation, options: { readonly blockTag: number }): Promise<CollectionInventorySimulation> {
  const p = plan(input), tag = integer(options.blockTag); if (tag < p.capture.blockNumber) throw Error("Simulation predates saved checkpoint"); await original(provider, p.capture);
  const current = await captureCollectionInventory(provider, p.capture.deployment, p.capture.coordinates.collectionId, { blockTag: tag });
  equal(current.checkpoint, p.capture.checkpoint, "Inventory checkpoint changed; refresh the plan"); if (current.frontier !== p.capture.frontier || current.mintedEver !== p.capture.mintedEver) throw Error("Core frontier/minted count changed; refresh the plan");
  const expected = await replay(provider, p, tag), fn = p.kind === "append" ? "appendCollectionTokens" : "scanCollectionTokens", args = inventoryAbi.decodeFunctionData(fn, p.call.data);
  const out = await rpc(provider, p.call.to, inventoryAbi, fn, [...args], tag, p.caller);
  if (p.kind === "scan") equal([...out], [expected.after.scanThrough, expected.after.indexedCount, expected.after.prefixHash], "Scan return differs from deterministic replay");
  if (!same((await header(provider, tag)).hash, current.blockHash)) throw Error("Simulation block changed");
  return freeze({ plan: p, capture: current, identities: expected.facts, replay: expected });
}

/** Prove membership within a saved completed-mint ordinal prefix, never from current serial lookup alone. */
export async function inspectCollectionInventoryPrefixMember(provider: Reader, input: CollectionInventoryCapture, options: { readonly collectionSerial: bigint; readonly blockTag: number }): Promise<CollectionInventoryPrefixMember> {
  const saved = capture(input), serial = uint(options.collectionSerial, true), tag = integer(options.blockTag);
  if (tag < saved.blockNumber) throw Error("Membership observation predates saved checkpoint"); await original(provider, saved);
  const observed = await captureCollectionInventory(provider, saved.deployment, saved.coordinates.collectionId, { blockTag: tag });
  if (observed.checkpoint.indexedCount < saved.checkpoint.indexedCount) throw Error("Observed inventory lost saved prefix");
  const d = saved.deployment, cid = saved.coordinates.collectionId;
  if (saved.lastIndexedToken) { const [last] = await rpc(provider, d.inventory.address, inventoryAbi, "collectionTokenAt", [cid, saved.checkpoint.indexedCount - 1n], tag); if (last !== saved.lastIndexedToken.tokenId) throw Error("Saved final ordinal changed"); }
  const [found] = await rpc(provider, d.inventory.address, inventoryAbi, "collectionTokenBySerial", [cid, serial], tag), tokenId = uint(found);
  let status: CollectionInventoryPrefixMember["status"] = "not-indexed", ordinal: bigint | null = null, fact: CollectionInventoryCoreIdentity | null = null;
  if (tokenId !== 0n) {
    fact = await identity(provider, d, tokenId, tag);
    if (!fact.mappingExists || fact.collectionId !== cid || fact.collectionSerial !== serial || fact.lifecycle < 2n) throw Error("Serial lookup differs from completed Core identity");
    if (!saved.lastIndexedToken || serial > saved.checkpoint.lastIndexedSerial || tokenId > saved.lastIndexedToken.tokenId) status = "outside-prefix";
    else {
      let low = 0n, high = saved.checkpoint.indexedCount;
      for (let reads = 0; low < high && reads < 256; reads++) {
        const middle = (low + high) / 2n, [value] = await rpc(provider, d.inventory.address, inventoryAbi, "collectionTokenAt", [cid, middle], tag), current = uint(value, true);
        if (current === tokenId) { ordinal = middle; break; } if (current < tokenId) low = middle + 1n; else high = middle;
      }
      if (ordinal === null) throw Error("Current serial lookup lacks membership in saved ordinal prefix"); status = "member";
    }
  }
  await unchanged(provider, { number: tag, hash: observed.blockHash }); await unchanged(provider, { number: saved.blockNumber, hash: saved.blockHash });
  return freeze({ capture: saved, observed, collectionSerial: serial, lookupTokenId: tokenId, status, ordinal, identity: fact });
}

/** Join exact submitted CALL and indexed events. Receipt-block cursor/frontier remain observations, not transaction return data. */
export async function inspectCollectionInventoryOperationReceipt(provider: ReceiptReader, input: PreparedCollectionInventoryOperation, evidence: { readonly transactionHash: Hex; readonly execution: "direct" | "safe" }): Promise<CollectionInventoryOperationReceipt> {
  const p = plan(input); keys(evidence, ["transactionHash", "execution"]); const transactionHash = hash(evidence.transactionHash), mode = evidence.execution;
  if (mode !== "direct" && mode !== "safe") throw Error("Unknown receipt execution mode");
  const [tx, receipt] = await Promise.all([provider.getTransaction(transactionHash), provider.getTransactionReceipt(transactionHash)]);
  if (!tx || !receipt || !same(tx.hash, transactionHash) || !same(receipt.hash, transactionHash) || receipt.status !== 1 || tx.blockNumber === null || !tx.blockHash || tx.blockNumber !== receipt.blockNumber || !same(tx.blockHash, receipt.blockHash) || tx.value !== 0n || !tx.to) throw Error("Successful mined transaction/receipt identity differs");
  const tag = integer(receipt.blockNumber), blockHash = hash(receipt.blockHash), data = bytes(tx.data, 262144);
  if (tag <= p.capture.blockNumber) throw Error("Receipt requires a strictly earlier saved checkpoint block");
  if (mode === "direct") { if (!same(tx.from, p.caller) || !same(tx.to, p.call.to) || !same(data, p.call.data)) throw Error("Direct indexing CALL differs"); }
  else {
    if (!same(tx.to, p.caller)) throw Error("Safe caller differs"); const q = safeAbi.decodeFunctionData("execTransaction", data);
    if (!same(safeAbi.encodeFunctionData("execTransaction", q), data) || !same(q.to, p.call.to) || q.value !== 0n || q.operation !== 0n || !same(q.data, p.call.data)) throw Error("Safe envelope differs from ordinary zero CALL");
  }
  if (!Array.isArray(receipt.logs) || receipt.logs.length > 512) throw Error("Receipt exceeds client log bound");
  let previous = -1;
  const logs = receipt.logs.map(l => {
    if (l.removed || l.blockNumber !== tag || !same(l.blockHash, blockHash) || !same(l.transactionHash, transactionHash) || integer(l.index) <= previous || l.topics.length < 1 || l.topics.length > 4) throw Error("Receipt log identity/order differs"); previous = l.index;
    return Object.freeze({ address: address(l.address), data: bytes(l.data), topics: Object.freeze(l.topics.map((v: string) => { if (!isHexString(v, 32)) throw Error("Malformed receipt topic"); return v.toLowerCase() as Hex; })), index: l.index });
  });
  const parse = (target: Address, abi: Interface, name: string) => {
    const fragment = abi.getEvent(name)!;
    return logs.filter(l => same(l.address, target) && same(l.topics[0], fragment.topicHash)).map(l => {
      const args = abi.decodeEventLog(fragment, l.data, [...l.topics]), canonical = abi.encodeEventLog(fragment, args);
      if (!same(canonical.data, l.data)) throw Error(`Noncanonical ${name} event`); equal(canonical.topics.map(t => t.toLowerCase()), l.topics, `Noncanonical ${name} topics`);
      return { args, ref: Object.freeze({ address: target, event: name, logIndex: l.index, transactionHash, blockHash }) };
    });
  };
  const refs: CollectionInventoryEventReference[] = [];
  if (mode === "safe") {
    const successes = logs.filter(l => same(l.address, p.caller) && same(l.topics[0], safeLegacy.getEvent("ExecutionSuccess")!.topicHash));
    if (successes.length !== 1 || logs.some(l => same(l.address, p.caller) && same(l.topics[0], safeLegacy.getEvent("ExecutionFailure")!.topicHash))) throw Error("Expected one Safe ExecutionSuccess and no ExecutionFailure");
    const success = parse(p.caller, successes[0]!.topics.length === 2 ? safeIndexed : safeLegacy, "ExecutionSuccess")[0]!; hash(success.args.txHash); refs.push(success.ref);
  }
  await original(provider, p.capture); const expected = await replay(provider, p, p.capture.blockNumber);
  const actual = parse(p.capture.deployment.inventory.address, inventoryAbi, "CollectionTokenIndexed");
  if (actual.length !== expected.indexed.length) throw Error("Indexed event count differs from saved replay; refresh stale base");
  for (let i = 0; i < actual.length; i++) {
    const event = actual[i]!, e = expected.indexed[i]!;
    equal([...event.args], [p.capture.coordinates.collectionId, e.tokenId, e.collectionSerial, e.prefixHash], "Indexed event differs from saved replay; refresh stale base"); refs.push(event.ref);
  }
  const observed = await captureCollectionInventory(provider, p.capture.deployment, p.capture.coordinates.collectionId, { blockTag: tag });
  if (!same(observed.blockHash, blockHash) || observed.checkpoint.indexedCount < expected.after.indexedCount) throw Error("Receipt block/state differs from committed events");
  if (observed.checkpoint.indexedCount === expected.after.indexedCount && !same(observed.checkpoint.prefixHash, expected.after.prefixHash)) throw Error("Receipt-block retained prefix differs from replay");
  const cid = p.capture.coordinates.collectionId, d = p.capture.deployment;
  if (p.capture.lastIndexedToken) { const [last] = await rpc(provider, d.inventory.address, inventoryAbi, "collectionTokenAt", [cid, p.capture.checkpoint.indexedCount - 1n], tag); if (last !== p.capture.lastIndexedToken.tokenId) throw Error("Receipt-block saved final ordinal changed"); }
  for (const e of expected.indexed) {
    const [[atOrdinal], [atSerial], retained] = await Promise.all([rpc(provider, d.inventory.address, inventoryAbi, "collectionTokenAt", [cid, e.ordinal], tag), rpc(provider, d.inventory.address, inventoryAbi, "collectionTokenBySerial", [cid, e.collectionSerial], tag), identity(provider, d, e.tokenId, tag)]);
    if (atOrdinal !== e.tokenId || atSerial !== e.tokenId || !retained.mappingExists || retained.collectionId !== cid || retained.collectionSerial !== e.collectionSerial || retained.lifecycle < 2n) throw Error("Indexed receipt membership/readback differs");
  }
  // Later calls in this same block may append entries or scan skipped IDs. Never equate observed cursor to this scan's return.
  await unchanged(provider, { number: tag, hash: blockHash }); await unchanged(provider, { number: p.capture.blockNumber, hash: p.capture.blockHash });
  return freeze({ plan: p, transactionHash, blockNumber: tag, blockHash, replay: expected, observed, cursorAttribution: "not-proven", events: refs.sort((a, b) => a.logIndex - b.logIndex) });
}
