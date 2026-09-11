import { getAddress, id, isHexString, keccak256, sha256, toUtf8Bytes, toQuantity, type ParamType } from "ethers";
import { StreamClient, contractInterface, stackConfigFromJSON, type ContractName, type StackConfig } from "./client.js";
import { provenance } from "./generated/provenance.js";
import type { Address, Hex } from "./generated/contracts.js";

type JSONValue = string | number | boolean | null | JSONValue[] | { [key: string]: JSONValue };
export interface SnapshotSelection {
  readonly blockNumber: bigint;
  readonly collectionIds: readonly bigint[];
  readonly tokenIds: readonly bigint[];
  readonly saleIds: readonly Hex[];
  readonly phases: readonly { readonly collectionId: bigint; readonly phaseId: Hex }[];
}
interface Query { contract: ContractName; address: Address; method: string; args: JSONValue[] }
interface ReadRecord extends Query { returnData: Hex; value: JSONValue }
interface CodeRecord { address: Address; codeHash: Hex }
export interface SupportedStateSnapshot {
  schemaVersion: 1;
  kind: "6529stream.supported-state";
  chainId: string;
  block: { number: string; hash: Hex };
  compilation: typeof provenance;
  selection: { collectionIds: string[]; tokenIds: string[]; saleIds: Hex[]; phases: { collectionId: string; phaseId: Hex }[] };
  addresses: Record<string, Address>;
  coverage: typeof COVERAGE;
  contracts: CodeRecord[];
  reads: ReadRecord[];
  unavailable: { tokenId: string; reason: "burned" | "prepared-incomplete"; methods: string[] }[];
}
export interface SnapshotPackage { snapshot: string; manifest: string; publication: string }
export class SnapshotReadError extends Error {
  constructor(contract: ContractName, method: string) { super(`Supported getter failed: ${contract}.${method}; capture aborted`); this.name = "SnapshotReadError"; }
}
function deepFreeze<T>(value: T): T {
  if (value && typeof value === "object") {
    for (const child of Object.values(value)) deepFreeze(child);
    Object.freeze(value);
  }
  return value;
}
// Returned snapshots must not expose mutable references to verifier authority.
const COMPILATION: typeof provenance = deepFreeze(JSON.parse(JSON.stringify(provenance)));
export const COVERAGE = deepFreeze({
  included: ["configured contract code hashes", "Core current stored pointers and counters", "selected collection supply, status, freeze, artist attribution and entropy policy", "selected token identity, retained bytes, mint coordinator and entropy state", "Core contractURI and selected minted tokenURI", "selected registered ERC20 sale configuration and current primary assignment", "selected phase configuration, policy and counter identifiers", "configured sale and auction signer/pause/accounting getters"],
  excluded: ["unselected collections, tokens, sales and phases", "private storage and full replay/role/credit mappings", "event or archival history reconstruction", "all phase counter subjects and individual auction/refund records", "router configuration not represented in rendered metadata", "offchain metadata or script URL availability", "full Artist V2, generic record-family and finality-recovery conformance", "proof of chain consensus or trustworthiness of the RPC"],
  semantics: "Public getter observations at one canonical block. Stored pointer registryStatus is not a live registry eligibility proof. Hashes establish package integrity, not consensus or completeness.",
});
const REQUIRED = ["core", "manager", "nativeSale", "erc20Sale", "auction", "artistRegistry", "entropy", "executor"] as const;
const POINTERS = ["MINT_MANAGER", "ENTROPY_COORDINATOR", "METADATA_ROUTER", "ARTIST_REGISTRY", "ROYALTY_RESOLVER", "STATE_EXPORT_PUBLISHER", "SYSTEM_MANIFEST", "ARTWORK_FINALITY_RECOVERY", "ARTWORK_FINALITY_REGISTRY", "COLLECTION_METADATA", "MODULE_REGISTRY", "MINT_LEDGER"];
const COLLECTION_READS = ["collectionExists", "collectionSupplyMode", "collectionStatus", "collectionHasMaxSupply", "collectionMaxSupply", "collectionMintedEver", "collectionNextSerial", "totalSupplyOfCollection", "collectionFreezeStatus", "collectionBurnsBlocked", "collectionBurnsBlockedAtBlock"];
const MAX_RETURN_BYTES = 131072;

/** Canonical format v1: sorted object keys, preserved array order, UTF-8, no whitespace/newline.
 * Integers representing protocol values are decimal strings; numeric schema fields must be safe integers.
 * This is a local explicit format, not a claim to implement every RFC8785 numeric rule.
 */
export function canonicalJSON(value: unknown): string {
  if (value === null || typeof value === "boolean" || typeof value === "string") {
    if (typeof value === "string") toUtf8Bytes(value); // Reject unpaired UTF-16 surrogates.
    return JSON.stringify(value);
  }
  if (typeof value === "number" && Number.isSafeInteger(value) && !Object.is(value, -0)) return JSON.stringify(value);
  if (Array.isArray(value)) return `[${Array.from(value, canonicalJSON).join(",")}]`;
  if (typeof value === "object" && value !== null && Object.getPrototypeOf(value) === Object.prototype) {
    return `{${Object.keys(value).sort().map(key => `${canonicalJSON(key)}:${canonicalJSON((value as Record<string, unknown>)[key])}`).join(",")}}`;
  }
  throw new Error("Noncanonical JSON value (use decimal strings for protocol integers)");
}
function exactKeys(value: unknown, keys: string[], label: string): asserts value is Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value) || Object.keys(value).sort().join(",") !== [...keys].sort().join(",")) throw new Error(`Invalid ${label} fields`);
}
function decimal(value: unknown, label: string, allowZero = false): string {
  if (typeof value !== "string" || !/^(0|[1-9][0-9]*)$/.test(value) || BigInt(value) >= 1n << 256n || (!allowZero && value === "0")) throw new Error(`Invalid ${label} decimal integer`);
  return value;
}
function ids(value: unknown, max: number, label: string, hex = false): string[] {
  if (!Array.isArray(value) || value.length > max) throw new Error(`${label} exceeds its selection limit`);
  const list = value.map(x => {
    if (hex) { if (typeof x !== "string" || !isHexString(x, 32)) throw new Error(`Invalid ${label}`); return x.toLowerCase(); }
    return decimal(x, label);
  });
  if (new Set(list).size !== list.length) throw new Error(`Duplicate ${label}`);
  return list.sort((a, b) => hex ? a < b ? -1 : a > b ? 1 : 0 : BigInt(a) < BigInt(b) ? -1 : BigInt(a) > BigInt(b) ? 1 : 0);
}
export function snapshotSelectionFromJSON(value: unknown): SnapshotSelection {
  exactKeys(value, ["blockNumber", "collectionIds", "tokenIds", "saleIds", "phases"], "selection");
  const blockNumber = BigInt(decimal(value.blockNumber, "blockNumber"));
  const collectionIds = ids(value.collectionIds, 32, "collectionIds").map(BigInt);
  const tokenIds = ids(value.tokenIds, 32, "tokenIds").map(BigInt);
  const saleIds = ids(value.saleIds, 64, "saleIds", true) as Hex[];
  if (!Array.isArray(value.phases) || value.phases.length > 64) throw new Error("phases exceeds its selection limit");
  const phases = value.phases.map(p => {
    exactKeys(p, ["collectionId", "phaseId"], "phase");
    const collectionId = BigInt(decimal(p.collectionId, "phase.collectionId"));
    if (typeof p.phaseId !== "string" || !isHexString(p.phaseId, 32)) throw new Error("Invalid phaseId");
    if (!collectionIds.includes(collectionId)) throw new Error("Selected phase requires its collectionId in collectionIds");
    return { collectionId, phaseId: p.phaseId.toLowerCase() as Hex };
  }).sort((a, b) => a.collectionId < b.collectionId ? -1 : a.collectionId > b.collectionId ? 1 : a.phaseId < b.phaseId ? -1 : a.phaseId > b.phaseId ? 1 : 0);
  if (new Set(phases.map(p => `${p.collectionId}:${p.phaseId}`)).size !== phases.length) throw new Error("Duplicate phase");
  return { blockNumber, collectionIds, tokenIds, saleIds, phases };
}
function selectionJSON(selection: SnapshotSelection): SupportedStateSnapshot["selection"] {
  return { collectionIds: selection.collectionIds.map(String), tokenIds: selection.tokenIds.map(String), saleIds: [...selection.saleIds], phases: selection.phases.map(p => ({ collectionId: String(p.collectionId), phaseId: p.phaseId })) };
}
function configForSnapshot(config: StackConfig): StackConfig {
  for (const name of REQUIRED) if (!config.addresses[name]) throw new Error(`Snapshot requires the ${name} contract address`);
  return config;
}
function query(config: StackConfig, contract: ContractName, method: string, args: JSONValue[] = [], address?: Address): Query {
  const target = address ?? config.addresses[contract];
  if (!target) throw new Error(`No ${contract} address`);
  return { contract, address: getAddress(target).toLowerCase() as Address, method, args };
}
function initialPlan(config: StackConfig, selection: SnapshotSelection): Query[] {
  const q = (c: ContractName, m: string, a: JSONValue[] = []) => query(config, c, m, a);
  const plan = ["lastAllocatedCollectionId", "lastAllocatedTokenId", "totalSupply", "pendingPreparedMintTokenId", "contractURI"].map(m => q("core", m));
  plan.push(...POINTERS.map(p => q("core", "getSatellitePointer", [id(p)])));
  plan.push(q("manager", "core"), q("manager", "mintLedger"), q("manager", "nextOperationNonce"));
  plan.push(q("artistRegistry", "core"), q("entropy", "core"), q("entropy", "pendingRequestCount"), q("entropy", "totalFeeCredits"));
  for (const name of ["nativeSale", "erc20Sale", "auction"] as const) {
    for (const method of ["platformSigner", "signerEpoch", "paused"]) plan.push(q(name, method));
    for (const method of ["mintManager", "artistRegistry", "splitFactory"]) plan.push(q(name, method));
  }
  plan.push(q("auction", "core"), q("erc20Sale", "revenueResolver"), q("erc20Sale", "assetPolicyRegistry"));
  for (const method of ["totalBidEscrow", "totalRefundOwed", "totalOwed", "totalNativeProceeds"]) plan.push(q("auction", method));
  for (const collectionId of selection.collectionIds) {
    plan.push(...COLLECTION_READS.map(m => q("core", m, [String(collectionId)])));
    plan.push(q("artistRegistry", "attribution", [String(collectionId)]), q("entropy", "collectionEntropyConfig", [String(collectionId)]));
  }
  for (const tokenId of selection.tokenIds) {
    for (const method of ["tokenCollectionIdentity", "tokenLifecycle", "coordinatorAtMint", "tokenData"]) plan.push(q("core", method, [String(tokenId)]));
  }
  for (const saleId of selection.saleIds) plan.push(q("erc20Sale", "saleRecord", [saleId]));
  for (const phase of selection.phases) {
    for (const method of ["phase", "phasePolicyHash", "phaseCounterIds", "phaseGate"]) plan.push(q("manager", method, [String(phase.collectionId), phase.phaseId]));
  }
  return plan;
}
function key(q: Query): string { return canonicalJSON(q); }
function readValue(records: ReadRecord[], q: Query): JSONValue {
  const record = records.find(r => key({ contract: r.contract, address: r.address, method: r.method, args: r.args }) === key(q));
  if (!record) throw new Error(`Missing ${q.contract}.${q.method}`);
  return record.value;
}
function followupPlan(config: StackConfig, selection: SnapshotSelection, reads: ReadRecord[]): { plan: Query[]; unavailable: SupportedStateSnapshot["unavailable"] } {
  const plan: Query[] = [], unavailable: SupportedStateSnapshot["unavailable"] = [];
  const val = (c: ContractName, m: string, a: JSONValue[]) => readValue(reads, query(config, c, m, a));
  const sameAddress = (actual: JSONValue, name: ContractName) => {
    const expected = config.addresses[name];
    if (expected && (typeof actual !== "string" || getAddress(actual) !== getAddress(expected))) throw new Error(`Configured ${name} differs from installed dependency`);
  };
  for (const name of ["manager", "artistRegistry", "entropy", "auction"] as const) sameAddress(val(name, "core", []), "core");
  for (const name of ["nativeSale", "erc20Sale", "auction"] as const) {
    sameAddress(val(name, "mintManager", []), "manager"); sameAddress(val(name, "artistRegistry", []), "artistRegistry"); sameAddress(val(name, "splitFactory", []), "splitFactory");
  }
  sameAddress(val("erc20Sale", "revenueResolver", []), "primaryRevenue");
  sameAddress(val("erc20Sale", "assetPolicyRegistry", []), "assetPolicy");
  for (const [type, name] of [["MINT_MANAGER", "manager"], ["ENTROPY_COORDINATOR", "entropy"], ["ARTIST_REGISTRY", "artistRegistry"], ["STATE_EXPORT_PUBLISHER", "executor"]] as const) {
    sameAddress((val("core", "getSatellitePointer", [id(type)]) as Record<string, JSONValue>).target!, name);
  }
  for (const c of selection.collectionIds) if (val("core", "collectionExists", [String(c)]) !== true) throw new Error(`Selected collection ${c} does not exist at the pinned block`);
  for (const tokenId of selection.tokenIds) {
    const args = [String(tokenId)], identity = val("core", "tokenCollectionIdentity", args) as Record<string, JSONValue>;
    if (identity.mappingExists !== true) throw new Error(`Selected token ${tokenId} has no identity at the pinned block`);
    if (!selection.collectionIds.some(c => String(c) === identity.collectionId)) throw new Error(`Token ${tokenId} requires collection ${identity.collectionId} in collectionIds`);
    const lifecycle = val("core", "tokenLifecycle", args);
    const omitted: string[] = [];
    if (lifecycle === "2") { // StreamTokenLifecycle.MINTED
      plan.push(query(config, "core", "ownerOf", args), query(config, "core", "tokenURI", args));
    } else if (lifecycle === "3" || lifecycle === "1") {
      omitted.push("ownerOf", "tokenURI");
      unavailable.push({ tokenId: String(tokenId), reason: lifecycle === "3" ? "burned" : "prepared-incomplete", methods: omitted });
    } else throw new Error(`Unexpected selected token lifecycle ${String(lifecycle)}`);
    const coordinator = val("core", "coordinatorAtMint", args);
    if (typeof coordinator !== "string" || !isHexString(coordinator, 20)) throw new Error(`Token ${tokenId} has no supported entropy coordinator`);
    if (BigInt(coordinator) === 0n) {
      // Core assigns this binding in _completeMint, after a persisted preparation.
      if (lifecycle !== "1") throw new Error(`Token ${tokenId} has no supported entropy coordinator`);
      omitted.push("tokenEntropy", "metadataNotificationPending");
      continue;
    }
    // Historical tokens use their stored coordinator, not a possibly replaced current pointer.
    plan.push(query(config, "entropy", "tokenEntropy", args, coordinator as Address), query(config, "entropy", "metadataNotificationPending", args, coordinator as Address));
  }
  for (const saleId of selection.saleIds) {
    const record = val("erc20Sale", "saleRecord", [saleId]) as Record<string, JSONValue>;
    if (record.saleNonce === "0") throw new Error(`Selected sale ${saleId} does not exist at the pinned block`);
    const cfg = record.config as Record<string, JSONValue>;
    if (!selection.collectionIds.some(c => String(c) === cfg.collectionId)) throw new Error(`Sale ${saleId} requires its collection in collectionIds`);
    plan.push(query(config, "erc20Sale", "primaryPolicy", [cfg.collectionId!, cfg.revenueClass!]));
  }
  for (const p of selection.phases) {
    const value = val("manager", "phase", [String(p.collectionId), p.phaseId]) as Record<string, JSONValue>;
    if (value.exists !== true) throw new Error("Selected phase does not exist at the pinned block");
  }
  const seen = new Set<string>();
  return { plan: plan.filter(q => { const k = key(q); if (seen.has(k)) return false; seen.add(k); return true; }), unavailable };
}
function normalized(param: ParamType, value: unknown): JSONValue {
  if (param.baseType === "array") return [...value as readonly unknown[]].map(v => normalized(param.arrayChildren!, v));
  if (param.baseType === "tuple") return Object.fromEntries(param.components!.map((p, i) => [p.name || String(i), normalized(p, (value as readonly unknown[])[i])]));
  if (/^u?int/.test(param.type)) return String(value);
  if (param.type === "address") return getAddress(String(value)).toLowerCase();
  if (param.type.startsWith("bytes")) return String(value).toLowerCase();
  if (typeof value === "boolean" || typeof value === "string") return value;
  throw new Error("Unsupported ABI snapshot value");
}
function decode(q: Query, returnData: Hex): JSONValue {
  if (!isHexString(returnData) || (returnData.length - 2) / 2 > MAX_RETURN_BYTES) throw new Error("Invalid or oversized ABI return data");
  const iface = contractInterface(q.contract), f = iface.getFunction(q.method);
  if (!f?.constant) throw new Error("Snapshot contains a non-read function");
  const values = iface.decodeFunctionResult(f, returnData);
  if (f.outputs.length === 1) return normalized(f.outputs[0]!, values[0]);
  return Object.fromEntries(f.outputs.map((p, i) => [p.name || String(i), normalized(p, values[i])]));
}
async function boundedMap<T, R>(items: T[], work: (item: T) => Promise<R>): Promise<R[]> {
  const results = new Array<R>(items.length); let index = 0;
  await Promise.all(Array.from({ length: Math.min(6, items.length) }, async () => {
    while (index < items.length) { const i = index++; results[i] = await work(items[i]!); }
  }));
  return results;
}
type SnapshotRPC = (method: string, params: unknown[]) => Promise<unknown>;
function freshRPC(client: StreamClient): SnapshotRPC {
  const provider = client.provider as typeof client.provider & { send?: SnapshotRPC };
  if (typeof provider.send !== "function") throw new Error("Snapshot capture requires a JSON-RPC provider with send(method, params)");
  // Provider.call/getCode/getBlock may reuse cached observations for 250ms.
  // send bypasses that ethers cache for every observation in this capture.
  return provider.send.bind(provider);
}
function blockHeader(value: unknown): { number: bigint; hash: Hex } {
  if (!value || typeof value !== "object") throw new Error("Selected block does not exist");
  const header = value as Record<string, unknown>;
  if (typeof header.number !== "string" || !/^0x(?:0|[1-9a-f][0-9a-f]*)$/i.test(header.number) || typeof header.hash !== "string" || !isHexString(header.hash, 32)) throw new Error("Invalid RPC block header");
  return { number: BigInt(header.number), hash: header.hash.toLowerCase() as Hex };
}
async function captureRead(rpc: SnapshotRPC, blockTag: string, q: Query): Promise<ReadRecord> {
  try {
    const iface = contractInterface(q.contract);
    const result = await rpc("eth_call", [{ to: q.address, data: iface.encodeFunctionData(q.method, q.args), gas: toQuantity(16000000n) }, blockTag]) as Hex;
    return { ...q, returnData: result.toLowerCase() as Hex, value: decode(q, result) };
  } catch { throw new SnapshotReadError(q.contract, q.method); }
}
function codeAddresses(config: StackConfig, reads: ReadRecord[]): Address[] {
  const addresses = Object.values(config.addresses) as Address[];
  for (const r of reads) {
    if (r.method === "getSatellitePointer") {
      const target = (r.value as Record<string, JSONValue>).target;
      if (typeof target === "string" && BigInt(target) !== 0n) addresses.push(target as Address);
    }
    addresses.push(r.address);
  }
  return [...new Set(addresses.map(a => a.toLowerCase() as Address))].sort();
}

export async function captureSupportedState(client: StreamClient, requested: SnapshotSelection): Promise<SupportedStateSnapshot> {
  const selection = snapshotSelectionFromJSON({ blockNumber: String(requested.blockNumber), ...selectionJSON(requested) });
  const config = configForSnapshot(client.config);
  const rpc = freshRPC(client), chainId = await rpc("eth_chainId", []);
  if (typeof chainId !== "string" || !/^0x[0-9a-f]+$/i.test(chainId) || BigInt(chainId) !== config.chainId) throw new Error("RPC chain ID differs from the configured Stream chain");
  const tag = toQuantity(selection.blockNumber), before = blockHeader(await rpc("eth_getBlockByNumber", [tag, false])), latest = blockHeader(await rpc("eth_getBlockByNumber", ["latest", false]));
  if (before.number !== selection.blockNumber || latest.number <= selection.blockNumber) throw new Error("Select an existing past block (not latest/pending)");
  const initial = await boundedMap(initialPlan(config, selection), q => captureRead(rpc, tag, q));
  const next = followupPlan(config, selection, initial);
  const reads = [...initial, ...await boundedMap(next.plan, q => captureRead(rpc, tag, q))];
  const contracts = await boundedMap(codeAddresses(config, reads), async address => {
    const code = await rpc("eth_getCode", [address, tag]);
    if (typeof code !== "string" || !isHexString(code) || code === "0x") throw new Error(`No valid contract code at selected address ${address}`);
    return { address, codeHash: keccak256(code) as Hex };
  });
  const after = blockHeader(await rpc("eth_getBlockByNumber", [tag, false]));
  if (after.number !== before.number || after.hash !== before.hash) throw new Error("Pinned block was reorganized while reading; discard capture");
  const snapshot: SupportedStateSnapshot = {
    schemaVersion: 1, kind: "6529stream.supported-state", chainId: String(config.chainId),
    block: { number: String(selection.blockNumber), hash: before.hash.toLowerCase() as Hex }, compilation: COMPILATION,
    selection: selectionJSON(selection), addresses: Object.fromEntries(Object.entries(config.addresses).map(([k, v]) => [k, v.toLowerCase() as Address])),
    coverage: COVERAGE, contracts, reads, unavailable: next.unavailable,
  };
  validateSnapshot(snapshot);
  return snapshot;
}

/** Structural, ABI and declared-coverage verification; authenticity requires pinned-chain readback. */
export function validateSnapshot(value: unknown): asserts value is SupportedStateSnapshot {
  exactKeys(value, ["schemaVersion", "kind", "chainId", "block", "compilation", "selection", "addresses", "coverage", "contracts", "reads", "unavailable"], "snapshot");
  if (value.schemaVersion !== 1 || value.kind !== "6529stream.supported-state") throw new Error("Unsupported snapshot schema");
  exactKeys(value.block, ["number", "hash"], "block");
  if (typeof value.block.hash !== "string" || !isHexString(value.block.hash, 32)) throw new Error("Invalid block hash");
  exactKeys(value.selection, ["collectionIds", "tokenIds", "saleIds", "phases"], "selection");
  const selection = snapshotSelectionFromJSON({ ...value.selection, blockNumber: value.block.number });
  if (canonicalJSON(selectionJSON(selection)) !== canonicalJSON(value.selection)) throw new Error("Selections must be sorted and canonical");
  const config = configForSnapshot(stackConfigFromJSON({ schemaVersion: 1, chainId: value.chainId, addresses: value.addresses }));
  if (canonicalJSON(value.compilation) !== canonicalJSON(COMPILATION)) throw new Error("Snapshot ABI/compiler identity differs from this client build");
  if (canonicalJSON(value.coverage) !== canonicalJSON(COVERAGE)) throw new Error("Snapshot coverage claim changed");
  if (!Array.isArray(value.reads) || value.reads.length > 1800) throw new Error("Invalid read inventory");
  const reads = value.reads as ReadRecord[];
  for (const r of reads) {
    exactKeys(r, ["contract", "address", "method", "args", "returnData", "value"], "read");
    if (!Array.isArray(r.args)) throw new Error("Invalid read arguments");
    const observed = decode(r, r.returnData);
    if (canonicalJSON(observed) !== canonicalJSON(r.value)) throw new Error("ABI-decoded facts differ from return data");
  }
  const initial = initialPlan(config, selection), next = followupPlan(config, selection, reads);
  const expected = [...initial, ...next.plan];
  if (reads.length !== expected.length || reads.some((r, i) => key({ contract: r.contract, address: r.address, method: r.method, args: r.args }) !== key(expected[i]!))) throw new Error("Snapshot read coverage/order differs from the fixed supported plan");
  if (canonicalJSON(value.unavailable) !== canonicalJSON(next.unavailable)) throw new Error("Token unavailability differs from its observed lifecycle");
  const addresses = codeAddresses(config, reads);
  if (!Array.isArray(value.contracts) || value.contracts.length !== addresses.length) throw new Error("Code hash coverage differs from observed contracts");
  value.contracts.forEach((c, i) => {
    exactKeys(c, ["address", "codeHash"], "contract");
    if (c.address !== addresses[i] || typeof c.codeHash !== "string" || !isHexString(c.codeHash, 32) || c.codeHash === keccak256("0x")) throw new Error("Invalid contract code hash coverage");
  });
}
export function packageSnapshot(snapshot: SupportedStateSnapshot): SnapshotPackage {
  validateSnapshot(snapshot);
  const text = canonicalJSON(snapshot), bytes = toUtf8Bytes(text), exportHash = keccak256(bytes);
  const manifest = canonicalJSON({ schemaVersion: 1, kind: "6529stream.supported-state-manifest", chainId: snapshot.chainId, block: snapshot.block, snapshot: { path: "snapshot.json", bytes: bytes.length, sha256: sha256(bytes), exportHash }, compilerInputSha256: COMPILATION.compilerInputSha256 });
  const publication = canonicalJSON({ blockNumber: snapshot.block.number, blockHash: snapshot.block.hash, exportHash, manifestHash: keccak256(toUtf8Bytes(manifest)) });
  return { snapshot: text, manifest, publication };
}
export function verifySnapshotPackage(files: SnapshotPackage): SupportedStateSnapshot {
  if ([files.snapshot, files.manifest, files.publication].some(x => typeof x !== "string" || toUtf8Bytes(x).length > 24000000)) throw new Error("Invalid or oversized snapshot package");
  const value: unknown = JSON.parse(files.snapshot);
  validateSnapshot(value);
  const expected = packageSnapshot(value);
  if (files.snapshot !== expected.snapshot || files.manifest !== expected.manifest || files.publication !== expected.publication) throw new Error("Noncanonical bytes or mismatched package hash/manifest/publication");
  return value;
}
export async function verifySnapshotReadback(client: StreamClient, files: SnapshotPackage): Promise<void> {
  const original = verifySnapshotPackage(files);
  if (String(client.config.chainId) !== original.chainId || canonicalJSON(Object.fromEntries(Object.entries(client.config.addresses).map(([k,v]) => [k, v.toLowerCase()]))) !== canonicalJSON(original.addresses)) throw new Error("Readback configuration differs from the snapshot");
  const selected = snapshotSelectionFromJSON({ ...original.selection, blockNumber: original.block.number });
  const observed = await captureSupportedState(client, selected);
  if (canonicalJSON(observed) !== files.snapshot) throw new Error("Pinned-chain readback differs from the snapshot");
}
