import { AbiCoder, Interface, ZeroAddress, concat, getAddress, id, isHexString, keccak256 } from "ethers";
import type { Provider } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import type { UnsignedCall } from "./client.js";
import { normalizeMintFallbackConfiguration, normalizeMintFallbackPlan, normalizeMintFallbackActivation, normalizeMintFallbackManifestUpdate, normalizeMintFallbackPointerState, normalizeMintFallbackIncident, normalizeMintFallbackRetirementClassifier, mintFallbackGovernanceBatch, normalizeMintFallbackGovernanceBatch, mintFallbackNextPointer } from "./current-mint-fallback.js";
import type { MintFallbackConfiguration, MintFallbackPointerState, MintFallbackRecoveryState, MintFallbackCallPlan, MintFallbackActivation, MintFallbackManifestState, MintFallbackManifestUpdate, MintFallbackGovernanceBatch, MintFallbackGovernanceWindow } from "./current-mint-fallback.js";
import { verifyMintContinuityArtifact } from "./current-mint-continuity.js";
import type { MintContinuityArtifact } from "./current-mint-continuity.js";

export interface MintFallbackInspectionOptions {
  readonly blockTag: number; readonly readiness?: "configuration" | "reserve";
  readonly importArtifact?: MintContinuityArtifact;
  readonly recovery?: { readonly tokenId: bigint; readonly operationId: Hex };
}
export interface MintFallbackClassification { readonly enabled: boolean; readonly targetCodeHash: Hex; readonly revision: bigint; readonly stateHash: Hex }
export interface MintFallbackImportInspection {
  readonly artifact: MintContinuityArtifact; readonly snapshotBlockHash: Hex;
  readonly committed: boolean; readonly importedCounters: bigint; readonly importedNullifiers: bigint;
  readonly definitions: { readonly imported: bigint; readonly required: bigint };
  readonly ancestry: { readonly imported: bigint; readonly required: bigint };
  readonly complete: boolean; readonly ready: boolean;
  readonly inventoryCompleteness: "caller-reviewed";
}
export interface MintFallbackInspection {
  readonly configuration: MintFallbackConfiguration; readonly readiness: "configuration" | "reserve";
  readonly blockNumber: number; readonly blockHash: Hex; readonly timestamp: bigint;
  readonly managerPointer: MintFallbackPointerState; readonly classification: MintFallbackClassification;
  readonly primaryRetiredAt: bigint; readonly primaryWriter: boolean; readonly successorReady: boolean;
  readonly governanceNonce: bigint;
  readonly catalog: { readonly candidateProfileHash: Hex; readonly catalogHash: Hex; readonly entryCount: bigint; readonly revision: bigint };
  readonly import: MintFallbackImportInspection | null;
  readonly recovery: { readonly tokenId: bigint; readonly operationId: Hex; readonly state: MintFallbackRecoveryState } | null;
}
type Reader = Pick<Provider, "getNetwork" | "getCode" | "getBlock" | "call">;
type ReceiptReader = Reader & Pick<Provider, "getTransaction" | "getTransactionReceipt">;
const coder = AbiCoder.defaultAbiCoder(), ZERO = `0x${"00".repeat(32)}` as Hex;
function addr(v: unknown, zero = false): Address { if (typeof v !== "string") throw Error("Expected address"); const a = getAddress(v) as Address; if (!zero && a === ZeroAddress) throw Error("Zero address"); return a; }
function hash(v: unknown, zero = false): Hex { if (typeof v !== "string" || !isHexString(v, 32) || (!zero && v.toLowerCase() === ZERO)) throw Error("Expected bytes32"); return v.toLowerCase() as Hex; }
function bytes(v: unknown, max = 32768): Hex { if (typeof v !== "string" || !isHexString(v, true) || (v.length - 2) / 2 > max) throw Error("Malformed or oversized bytes"); return v.toLowerCase() as Hex; }
function uint(v: unknown, positive = false): bigint { if (typeof v !== "bigint" || v < (positive ? 1n : 0n) || v >= 1n << 256n) throw Error("Expected uint256 bigint"); return v; }
function integer(v: number): number { if (!Number.isSafeInteger(v) || v < 0) throw Error("Expected concrete block/index"); return v; }
function same(a: unknown, b: unknown): boolean { return typeof a === "string" && typeof b === "string" && a.toLowerCase() === b.toLowerCase(); }
function stable(v: unknown): string { return JSON.stringify(v, (_, x: unknown) => typeof x === "bigint" ? `${x}n` : x && typeof x === "object" && !Array.isArray(x) ? Object.fromEntries(Object.entries(x).sort(([a], [b]) => a.localeCompare(b))) : x); }
function equal(a: unknown, b: unknown, message = "Prepared facts differ; rebuild and reschedule changed commitments"): void { if (stable(a) !== stable(b)) throw Error(message); }
function freeze<T>(v: T): T { if (v && typeof v === "object") { Object.values(v).forEach(freeze); Object.freeze(v); } return v; }
function clone<T>(v: T): T { return structuredClone(v); }
function call(to: Address, abi: Interface, name: string, args: readonly unknown[]): UnsignedCall { return freeze({ to, value: 0n, data: abi.encodeFunctionData(name, args) as Hex }); }
async function rpc(p: Pick<Provider, "call">, to: Address, abi: Interface, name: string, args: readonly unknown[], tag: number, from?: Address): Promise<readonly unknown[]> { const raw = bytes(await p.call({ ...call(to, abi, name, args), blockTag: tag, ...(from ? { from } : {}) })); const r = abi.decodeFunctionResult(name, raw); if (!same(abi.encodeFunctionResult(name, r), raw)) throw Error(`Noncanonical ${name} return`); return r; }
async function header(p: Pick<Provider, "getBlock">, tag: number): Promise<{ number: number; hash: Hex; timestamp: bigint }> { const b = await p.getBlock(tag); if (!b || b.number !== tag || !Number.isSafeInteger(b.timestamp) || b.timestamp < 0) throw Error("Missing/mismatched block"); return { number: tag, hash: hash(b.hash), timestamp: BigInt(b.timestamp) }; }
async function unchanged(p: Pick<Provider, "getBlock">, h: { number: number; hash: Hex; timestamp: bigint }): Promise<void> { equal(await header(p, h.number), h, "Pinned block changed"); }
async function runtime(p: Pick<Provider, "getCode">, target: Address, expected: Hex, tag: number): Promise<void> { const code = bytes(await p.getCode(target, tag), 65536); if (code === "0x" || (code.length === 48 && code.startsWith("0xef0100")) || !same(keccak256(code), expected)) throw Error("Pinned runtime differs"); }
function record(r: readonly unknown[], names: readonly string[]): Record<string, unknown> { return Object.fromEntries(names.map((n, i) => [n, r[i]])); }
const pointerNames = ["target", "codeHash", "frozen", "moduleType", "interfaceId", "registry", "registryStatus", "moduleManifestHash", "deploymentManifestHash", "revision"];
async function pointer(p: Reader, c: MintFallbackConfiguration, name: string, tag: number): Promise<MintFallbackPointerState> { return record(await rpc(p, c.core, coreAbi, "getSatellitePointer", [id(name)], tag), pointerNames) as unknown as MintFallbackPointerState; }
function requirePointer(v: MintFallbackPointerState, target: Address, codeHash: Hex): void { if (!same(v.target, target) || !same(v.codeHash, codeHash)) throw Error("Canonical Core pointer differs"); }
const moduleNames = ["status", "moduleType", "moduleVersion", "interfaceId", "moduleGasLimit", "runtimeCodeHash", "deploymentManifestHash", "moduleManifestHash", "moduleManifestURI", "registeredAt", "statusUpdatedAt", "revision"];
async function moduleRecord(p: Reader, c: MintFallbackConfiguration, target: Address, tag: number): Promise<Record<string, unknown>> { const [r] = await rpc(p, c.registry, registryAbi, "moduleRecord", [target], tag); const out = record(r as readonly unknown[], moduleNames); if (typeof out.moduleManifestURI !== "string" || new TextEncoder().encode(out.moduleManifestURI).length > 2048) throw Error("Module URI exceeds client bound"); return out; }
async function configuration(p: Reader, c: MintFallbackConfiguration, tag: number): Promise<{ number: number; hash: Hex; timestamp: bigint }> {
  if ((await p.getNetwork()).chainId !== c.chainId) throw Error("RPC chain differs"); const h = await header(p, tag);
  await Promise.all([[c.core, c.coreCodeHash], [c.ledger, c.ledgerCodeHash], [c.primary, c.primaryCodeHash], [c.fallbackManager, c.fallbackCodeHash], [c.registry, c.registryCodeHash], [c.governance, c.governanceCodeHash]].map(([target, codeHash]) => runtime(p, target as Address, codeHash as Hex, tag)));
  const [[marker], [owner], [gov], reg] = await Promise.all([rpc(p, c.ledger, ledgerAbi, "isStreamMintLedger", [], tag), rpc(p, c.ledger, ledgerAbi, "owner", [], tag), rpc(p, c.registry, registryAbi, "governanceExecutor", [], tag), pointer(p, c, "MODULE_REGISTRY", tag)]);
  if (marker !== true || !same(owner, c.governance) || !same(gov, c.governance)) throw Error("Ledger/registry governance binding differs"); requirePointer(reg, c.registry, c.registryCodeHash);
  for (const manager of [c.primary, c.fallbackManager]) {
    for (const [name, expected] of [["core", c.core], ["mintLedger", c.ledger], ["moduleRegistry", c.registry], ["owner", c.governance], ["governanceAuthority", c.governance]] as const) { const [v] = await rpc(p, manager, managerAbi, name, [], tag); if (!same(v, expected)) throw Error(`Manager ${name} differs`); }
    const [[isManager], [supported]] = await Promise.all([rpc(p, manager, managerAbi, "isStreamMintManager", [], tag), rpc(p, manager, managerAbi, "supportsInterface", ["0xb4074ed7"], tag)]); if (isManager !== true || supported !== true) throw Error("Manager marker/interface differs");
    for (const [parameter, floor] of [["6529STREAM_GGP_MINT_GATE_GAS_LIMIT", 400000n], ["6529STREAM_GGP_ARTIST_AUTHORITY_GAS_LIMIT", 150000n]] as const) { const g = await rpc(p, manager, managerAbi, "gasParameterInfo", [id(parameter)], tag); if (uint(g[0]) < floor || g[1] !== floor || g[2] !== 2n || uint(g[3]) === 0n) throw Error("Manager gas policy differs"); }
  }
  return h;
}
async function reserve(p: Reader, c: MintFallbackConfiguration, tag: number, now: bigint, manager: MintFallbackPointerState): Promise<void> {
  requirePointer(await pointer(p, c, "MINT_LEDGER", tag), c.ledger, c.ledgerCodeHash);
  if (!(same(manager.target, c.primary) && same(manager.codeHash, c.primaryCodeHash)) && !(same(manager.target, c.fallbackManager) && same(manager.codeHash, c.fallbackCodeHash))) throw Error("Selected Manager differs");
  for (const [target, type, iface] of [[c.ledger, "MINT_LEDGER", "0x27d4bae6"], [c.fallbackManager, "MINT_MANAGER", "0xb4074ed7"]] as const) { const [eligible] = await rpc(p, c.registry, registryAbi, "isModuleEligible", [target, id(type), iface], tag); if (eligible !== true) throw Error("Reserve dependency is ineligible"); }
  const r = await moduleRecord(p, c, c.fallbackManager, tag);
  for (const [name, expected] of [["status", 1n], ["runtimeCodeHash", c.fallbackCodeHash], ["moduleVersion", c.moduleVersion], ["moduleGasLimit", c.moduleGasLimit], ["deploymentManifestHash", c.deploymentManifestHash], ["moduleManifestHash", c.moduleManifestHash], ["moduleManifestURI", c.moduleManifestURI]] as const) if (r[name] !== expected && (name === "moduleManifestURI" || !same(r[name], expected))) throw Error(`Reserve module ${name} differs`);
  const [[writer], [retired]] = await Promise.all([rpc(p, c.ledger, ledgerAbi, "ledgerWriter", [c.fallbackManager], tag), rpc(p, c.ledger, ledgerAbi, "ledgerWriterRetiredAt", [c.fallbackManager], tag)]); if (writer !== true || retired !== 0n) throw Error("Fallback is not a nonretired Ledger writer");
  if (same(c.recorder, ZeroAddress)) return;
  await runtime(p, c.recorder, c.recorderCodeHash, tag); const rec = await moduleRecord(p, c, c.recorder, tag);
  if ((rec.status !== 1n && rec.status !== 2n) || !same(rec.moduleType, id("PRIMARY_SALE_SETTLEMENT")) || !same(rec.moduleVersion, id("6529STREAM_PREPARED_NATIVE_SETTLEMENT_V1")) || rec.interfaceId !== "0xa00dbd02" || !same(rec.runtimeCodeHash, c.recorderCodeHash) || rec.deploymentManifestHash === ZERO || rec.moduleManifestHash === ZERO || uint(rec.registeredAt) === 0n || uint(rec.registeredAt) > now || uint(rec.statusUpdatedAt) < uint(rec.registeredAt) || uint(rec.statusUpdatedAt) > now || uint(rec.revision) === 0n) throw Error("Prepared recorder lifecycle differs");
  for (const [iface, expected] of [["0x01ffc9a7", true], ["0xffffffff", false], ["0xa00dbd02", true]] as const) { const [v] = await rpc(p, c.recorder, managerAbi, "supportsInterface", [iface], tag); if (v !== expected) throw Error("Recorder ERC165 differs"); }
  for (const manager of [c.primary, c.fallbackManager]) { const binding = await rpc(p, manager, managerAbi, "preparedNativeRecorder", [], tag), at = uint(binding[2]), revision = uint(binding[3]); if (!same(binding[0], c.recorder) || !same(binding[1], c.recorderCodeHash) || at === 0n || at > now || at < uint(rec.registeredAt) || revision === 0n || revision > uint(rec.revision) || (rec.status === 2n && (at >= uint(rec.statusUpdatedAt) || revision >= uint(rec.revision)))) throw Error("Manager recorder binding differs"); }
  for (const [name, expected] of [["core", c.core], ["moduleRegistry", c.registry], ["coreCodeHash", c.coreCodeHash], ["moduleRegistryCodeHash", c.registryCodeHash]] as const) { const [v] = await rpc(p, c.recorder, recorderAbi, name, [], tag); if (!same(v, expected)) throw Error("Recorder immutable binding differs"); }
}

async function recovery(p: Reader, c: MintFallbackConfiguration, tokenId: bigint, operationId: Hex, tag: number): Promise<MintFallbackRecoveryState> {
  const [[prepared], [pending], identity] = await Promise.all([rpc(p, c.core, coreAbi, "preparedMint", [tokenId], tag), rpc(p, c.core, coreAbi, "pendingPreparedMintTokenId", [], tag), rpc(p, c.core, coreAbi, "tokenCollectionIdentity", [tokenId], tag)]), r = prepared as readonly unknown[];
  if (r[0] !== true || !same(r[1], operationId) || pending !== tokenId || identity[0] !== true || identity[3] !== false || uint(identity[1]) === 0n || r[2] !== identity[1] || uint(identity[2]) === 0n) throw Error("Prepared incident facts differ");
  const collectionId = uint(identity[1]), [[lastTokenId], [nextSerial], [mintedEver], [supply], [data], [coordinator]] = await Promise.all([rpc(p, c.core, coreAbi, "lastAllocatedTokenId", [], tag), rpc(p, c.core, coreAbi, "collectionNextSerial", [collectionId], tag), rpc(p, c.core, coreAbi, "collectionMintedEver", [collectionId], tag), rpc(p, c.core, coreAbi, "totalSupply", [], tag), rpc(p, c.core, coreAbi, "tokenData", [tokenId], tag), rpc(p, c.core, coreAbi, "coordinatorAtMint", [tokenId], tag)]);
  return freeze({ collectionId, serial: uint(identity[2]), lastTokenId: uint(lastTokenId), nextSerial: uint(nextSerial), mintedEver: uint(mintedEver), supply: uint(supply), tokenDataHash: keccak256(bytes(data, 16384)) as Hex, coordinator: addr(coordinator, true) });
}
async function imports(p: Reader, c: MintFallbackConfiguration, artifact: MintContinuityArtifact, tag: number, retiredAt: bigint, writer: boolean, ready: boolean): Promise<MintFallbackImportInspection> {
  const a = artifact, ac = a.coordinates;
  if (ac.chainId !== c.chainId || !same(ac.successorLedger, c.ledger) || !same(ac.predecessorLedger, c.ledger) || !same(ac.predecessorManager, c.primary) || !same(ac.successorManager, c.fallbackManager)) throw Error("Import must use the actual same-Ledger Manager pair");
  if (ac.snapshotBlock === 0n || ac.snapshotBlock > BigInt(tag) || retiredAt === 0n || retiredAt > ac.snapshotBlock || writer) throw Error("Import snapshot must follow permanent primary retirement");
  const snapTag = Number(ac.snapshotBlock); if (!Number.isSafeInteger(snapTag)) throw Error("Snapshot block exceeds client range"); const snap = await header(p, snapTag); await runtime(p, c.ledger, c.ledgerCodeHash, snapTag);
  const [[historicalRetired], [historicalWriter]] = await Promise.all([rpc(p, c.ledger, ledgerAbi, "ledgerWriterRetiredAt", [c.primary], snapTag), rpc(p, c.ledger, ledgerAbi, "ledgerWriter", [c.primary], snapTag)]); if (historicalRetired !== retiredAt || historicalWriter !== false) throw Error("Snapshot retirement differs");
  for (const leaf of a.counterLeaves) { const [key] = await rpc(p, c.ledger, ledgerAbi, "deriveCounterValueKey", [c.primary, leaf.collectionId, leaf.phaseId, leaf.counterId, leaf.predecessorSubjectKey], snapTag), [value] = await rpc(p, c.ledger, ledgerAbi, "counterValue", [key], snapTag); if (value !== leaf.value) throw Error("Actual predecessor counter differs from reviewed import"); }
  for (const nullifier of a.nullifiers) { const [used] = await rpc(p, c.ledger, ledgerAbi, "isManagerNullifierUsed", [c.primary, nullifier], snapTag); if (used !== true) throw Error("Actual predecessor nullifier is absent"); }
  const [value] = await rpc(p, c.ledger, ledgerAbi, "mintImportCommitment", [a.importRoot], tag), r = value as readonly unknown[], committed = !same(r[0], ZeroAddress);
  if (!committed) { if (r.some((v, i) => i < 3 ? !same(v, ZeroAddress) : i === 4 ? !same(v, ZERO) : i === 7 ? v !== false : v !== 0n) || ready) throw Error("Unknown import state is inconsistent"); await unchanged(p, snap); return freeze({ artifact: a, snapshotBlockHash: snap.hash, committed: false, importedCounters: 0n, importedNullifiers: 0n, definitions: { imported: 0n, required: 0n }, ancestry: { imported: 0n, required: 0n }, complete: false, ready: false, inventoryCompleteness: "caller-reviewed" }); }
  if (!same(r[0], c.ledger) || !same(r[1], c.primary) || !same(r[2], c.fallbackManager) || r[3] !== ac.snapshotBlock || !same(r[4], a.manifestHash)) throw Error("Known import commitment differs");
  const [def, ancestors, [descendant]] = await Promise.all([rpc(p, c.ledger, ledgerAbi, "mintImportDefinitionProgress", [a.importRoot], tag), rpc(p, c.ledger, ledgerAbi, "mintImportAncestryProgress", [a.importRoot], tag), rpc(p, c.ledger, ledgerAbi, "isCompletedMintDescendant", [c.ledger, c.primary, c.fallbackManager], tag)]), counters = uint(r[5]), nullifiers = uint(r[6]), complete = r[7] === true;
  if (counters > BigInt(a.counterLeaves.length) || nullifiers > BigInt(a.nullifiers.length) || uint(def[0]) > uint(def[1]) || uint(ancestors[0]) > uint(ancestors[1]) || descendant !== ready || (complete && (counters !== BigInt(a.counterLeaves.length) || nullifiers !== BigInt(a.nullifiers.length) || def[0] !== def[1] || ancestors[0] !== ancestors[1])) || (ready && !complete)) throw Error("Import progress/readiness differs");
  if (complete) {
    for (const leaf of a.counterLeaves) { const [key] = await rpc(p, c.ledger, ledgerAbi, "deriveCounterValueKey", [c.fallbackManager, leaf.collectionId, leaf.phaseId, leaf.counterId, leaf.predecessorSubjectKey], tag), [v] = await rpc(p, c.ledger, ledgerAbi, "counterValue", [key], tag); if (uint(v) < leaf.value) throw Error("Successor counter import is absent"); }
    for (const nullifier of a.nullifiers) { const [used] = await rpc(p, c.ledger, ledgerAbi, "isManagerNullifierUsed", [c.fallbackManager, nullifier], tag); if (used !== true) throw Error("Successor nullifier import is absent"); }
  }
  await unchanged(p, snap);
  return freeze({ artifact: a, snapshotBlockHash: snap.hash, committed, importedCounters: counters, importedNullifiers: nullifiers, definitions: { imported: uint(def[0]), required: uint(def[1]) }, ancestry: { imported: uint(ancestors[0]), required: uint(ancestors[1]) }, complete, ready, inventoryCompleteness: "caller-reviewed" });
}
/** Checks original Configuration or reserve readiness at one concrete block. No transaction is sent. */
export async function inspectMintFallback(p: Reader, input: MintFallbackConfiguration, options: MintFallbackInspectionOptions): Promise<MintFallbackInspection> {
  const c = normalizeMintFallbackConfiguration(input), tag = integer(options.blockTag), readiness = options.readiness ?? "reserve", artifact = options.importArtifact ? verifyMintContinuityArtifact(options.importArtifact) : null, incident = options.recovery ? { tokenId: uint(options.recovery.tokenId, true), operationId: hash(options.recovery.operationId) } : null;
  if (readiness !== "configuration" && readiness !== "reserve") throw Error("Unsupported readiness profile"); const h = await configuration(p, c, tag);
  const [managerPointer, classifier, [retired], [writer], [ready], [nonce], catalog] = await Promise.all([pointer(p, c, "MINT_MANAGER", tag), rpc(p, c.governance, executorAbi, "tighteningCallConfig", [c.ledger, ledgerAbi.getFunction("retireLedgerWriter")!.selector], tag), rpc(p, c.ledger, ledgerAbi, "ledgerWriterRetiredAt", [c.primary], tag), rpc(p, c.ledger, ledgerAbi, "ledgerWriter", [c.primary], tag), rpc(p, c.ledger, ledgerAbi, "isMintSuccessorReady", [c.ledger, c.primary, c.fallbackManager], tag), rpc(p, c.governance, executorAbi, "governanceNonce", [], tag), rpc(p, c.governance, executorAbi, "governanceActionPolicyState", [], tag)]);
  if (readiness === "reserve") await reserve(p, c, tag, h.timestamp, managerPointer);
  const primaryRetiredAt = uint(retired); if (primaryRetiredAt > BigInt(tag) || (primaryRetiredAt !== 0n && writer !== false)) throw Error("Permanent retirement state differs");
  const out: MintFallbackInspection = { configuration: c, readiness, blockNumber: tag, blockHash: h.hash, timestamp: h.timestamp, managerPointer, classification: { enabled: classifier[0] === true, targetCodeHash: hash(classifier[1], true), revision: uint(classifier[2]), stateHash: hash(classifier[3], true) }, primaryRetiredAt, primaryWriter: writer === true, successorReady: ready === true, governanceNonce: uint(nonce), catalog: { candidateProfileHash: hash(catalog[0], true), catalogHash: hash(catalog[1], true), entryCount: uint(catalog[2]), revision: uint(catalog[3]) }, import: artifact ? await imports(p, c, artifact, tag, primaryRetiredAt, writer === true, ready === true) : null, recovery: incident ? { ...incident, state: await recovery(p, c, incident.tokenId, incident.operationId, tag) } : null };
  await unchanged(p, h); return freeze(out);
}

const manifestModules = ["revenueResolver", "metadataRouter", "collectionMetadata", "entropyCoordinator", "mintManager", "mintLedger", "artistRegistry", "streamAdminsOrGovernance", "artworkFinalityRegistry", "moduleRegistry", "stateExportPublisher"];
const manifestDiscovery = ["eventCatalogHash", "compatibilityMatrixHash", "numericIdCatalogHash", "schemaCatalogHash", "canonicalizationCatalogHash", "specBundleHash", "reconstructionClientHash"];
async function manifestState(p: Reader, target: Address, tag: number): Promise<MintFallbackManifestState> { const r = await rpc(p, target, manifestAbi, "streamSystemManifest", [], tag), [root] = await rpc(p, target, manifestAbi, "streamSystemManifestPointer", [], tag); return { manifestHash: hash(r[0], true), manifestURI: String(r[1]), modules: record(r.slice(2, 13), manifestModules) as unknown as MintFallbackManifestState["modules"], discovery: record(r.slice(13, 20), manifestDiscovery) as unknown as MintFallbackManifestState["discovery"], revision: uint(r[20]), payloadRoot: addr(root, true) }; }
async function manifestPayload(p: Reader, root: Address, expectedHash: Hex, tag: number): Promise<void> {
  const code = bytes(await p.getCode(root, tag), 3329); if (!code.startsWith("0x00")) throw Error("Manifest descriptor is not canonical SSTORE2"); const raw = `0x${code.slice(4)}` as Hex;
  const types = ["bytes4", "uint16", "bytes32", "bytes32", "uint32", "uint16", "tuple(address pointer,uint32 payloadLength,bytes32 payloadHash)[]"], r = coder.decode(types, raw); if (!same(coder.encode(types, r), raw)) throw Error("Noncanonical manifest descriptor");
  const PAYLOAD = "0x8844b744a67cdcdb84ea3c6e3d686883da175820b9ff07a19cffa14bf62e6e81", JCS = "0x886c7c89c308c459ca8a626e0ef36a5ea9f4c7a7b56aaf86c71a2ddf3b4f9044", ROOT = "0xd6ab89b077c61a288c7168cf8f1c9a7a19464b10475735dae37cb46a0c94c40b", LEAF = "0x852f4811a2eb32694863d94ba41b545a65ef4c76086a32c35881f0c4e250a7b5", LIST = "0xa93750a5551ac5668c8f24cca85acaf1d5f8334fac9406f845fce1ce35548839";
  const total = uint(r[4], true), count = uint(r[5], true), chunks = r[6] as readonly (readonly unknown[])[];
  if (r[0] !== "0x6c9d2530" || r[1] !== 1n || !same(r[2], PAYLOAD) || !same(r[3], JCS) || total > 786400n || count > 32n || BigInt(chunks.length) !== count || BigInt((raw.length - 2) / 2) !== 256n + 96n * count || count !== (total + 24574n) / 24575n) throw Error("Manifest descriptor profile differs");
  let observed = 0n; const leaves: Hex[] = [];
  for (let i = 0; i < chunks.length; i++) { const x = chunks[i]!, length = uint(x[1], true); if (length > 24575n || (i + 1 < chunks.length && length !== 24575n)) throw Error("Manifest chunk length differs"); const chunk = bytes(await p.getCode(addr(x[0]), tag), 24576); if (!chunk.startsWith("0x00") || BigInt((chunk.length - 4) / 2) !== length || !same(keccak256(`0x${chunk.slice(4)}`), hash(x[2]))) throw Error("Manifest chunk bytes differ"); observed += length; leaves.push(keccak256(coder.encode(["bytes32", "uint256", "uint32", "bytes32"], [LEAF, i, length, x[2]])) as Hex); }
  const list = keccak256(coder.encode(["bytes32", "uint32", "bytes32[]"], [LIST, total, leaves])), actual = keccak256(coder.encode(["bytes32", "uint16", "bytes32", "bytes32", "uint32", "uint16", "bytes32"], [ROOT, 1, PAYLOAD, JCS, total, count, list])); if (observed !== total || !same(actual, expectedHash)) throw Error("Manifest payload commitment differs");
}
async function activation(p: Reader, c: MintFallbackConfiguration, a: MintFallbackActivation, tag: number): Promise<void> {
  const ptr = await pointer(p, c, "SYSTEM_MANIFEST", tag); if (!same(ptr.target, a.manifest)) throw Error("SystemManifest pointer differs"); await runtime(p, a.manifest, hash(ptr.codeHash), tag);
  const [[core], [gov]] = await Promise.all([rpc(p, a.manifest, manifestAbi, "core", [], tag), rpc(p, a.manifest, manifestAbi, "governanceExecutor", [], tag)]); if (!same(core, c.core) || !same(gov, c.governance)) throw Error("Manifest authority differs");
  equal(await manifestState(p, a.manifest, tag), a.current); equal(await pointer(p, c, "MINT_MANAGER", tag), a.previousPointer); await manifestPayload(p, a.payloadRoot, a.update.manifestHash, tag);
}
/** Captures the original manifest/pointer preimages and validates retained payload chunks. */
export async function captureMintFallbackActivation(p: Reader, input: MintFallbackConfiguration, options: { readonly blockTag: number; readonly manifest: Address; readonly payloadRoot: Address; readonly update: MintFallbackManifestUpdate }): Promise<MintFallbackActivation> {
  const c = normalizeMintFallbackConfiguration(input), tag = integer(options.blockTag), manifest = addr(options.manifest), payloadRoot = addr(options.payloadRoot), update = normalizeMintFallbackManifestUpdate(options.update), h = await configuration(p, c, tag);
  const out = normalizeMintFallbackActivation({ manifest, payloadRoot, update, current: await manifestState(p, manifest, tag), previousPointer: await pointer(p, c, "MINT_MANAGER", tag) }); await activation(p, c, out, tag); await unchanged(p, h); return out;
}
function inspectionOptions(plan: MintFallbackCallPlan, tag: number, incident = true): MintFallbackInspectionOptions {
  const r = plan.request; return { blockTag: tag, readiness: r.kind === "retirement-classification" ? "configuration" : "reserve", ...("artifact" in r ? { importArtifact: r.artifact } : {}), ...(r.kind === "incident-activation" && incident ? { recovery: { tokenId: r.incident.tokenId, operationId: r.incident.operationId } } : {}) };
}
async function validatePlan(p: Reader, plan: MintFallbackCallPlan, i: MintFallbackInspection, execution: boolean): Promise<void> {
  const c = plan.configuration, r = plan.request, tag = i.blockNumber; equal(c, i.configuration);
  if (r.kind === "retirement-classification" || r.kind === "retirement") { equal(r.classifier, i.classification); if (r.kind === "retirement" && i.primaryRetiredAt !== 0n) throw Error("Primary is already retired"); }
  if (["retirement", "import-commit", "raw-import-commit", "activation", "incident-activation"].includes(r.kind)) requirePointer(i.managerPointer, c.primary, c.primaryCodeHash);
  if (r.kind === "activation" || r.kind === "incident-activation") { await activation(p, c, r.activation, tag); if (execution && !i.successorReady) throw Error("Exact same-Ledger successor import is not ready"); if (r.kind === "incident-activation") equal(i.recovery, r.incident); }
  if (r.kind === "import-commit" && i.import?.committed) throw Error("Import root is already committed");
  const root = "artifact" in r ? r.artifact.importRoot : "importRoot" in r ? r.importRoot : "snapshot" in r ? r.snapshot.importRoot : "batch" in r ? r.batch.importRoot : "descriptor" in r ? r.descriptor.importRoot : null;
  if (root) { const [value] = await rpc(p, c.ledger, ledgerAbi, "mintImportCommitment", [root], tag), known = value as readonly unknown[], exists = !same(known[0], ZeroAddress); if (exists && (!same(known[0], c.ledger) || !same(known[1], c.primary) || !same(known[2], c.fallbackManager))) throw Error("Known root belongs to another Manager pair"); if (execution && r.kind !== "import-commit" && r.kind !== "raw-import-commit" && (!exists || known[7] === true)) throw Error("Import is absent or already complete"); }
  if (r.kind === "raw-import-commit") { if (r.snapshot.snapshotBlock === 0n || r.snapshot.snapshotBlock > BigInt(tag)) throw Error("Invalid import snapshot block"); if (execution && (i.primaryRetiredAt === 0n || i.primaryRetiredAt > r.snapshot.snapshotBlock || i.primaryWriter)) throw Error("Import requires retired predecessor at snapshot"); }
}

export interface PreparedMintFallbackGovernance { readonly inspection: MintFallbackInspection; readonly batch: MintFallbackGovernanceBatch; readonly proposer: Address }
export interface MintFallbackGovernanceOperation { readonly kind: "governance"; readonly prepared: PreparedMintFallbackGovernance; readonly stage: "publish" | "schedule" | "execute"; readonly caller: Address; readonly call: UnsignedCall }
export interface MintFallbackPermissionlessOperation { readonly kind: "permissionless"; readonly inspection: MintFallbackInspection; readonly plan: MintFallbackCallPlan; readonly caller: Address; readonly call: UnsignedCall }
export type MintFallbackOperation = MintFallbackGovernanceOperation | MintFallbackPermissionlessOperation;
export interface MintFallbackSimulation { readonly operation: MintFallbackOperation; readonly observed: MintFallbackInspection; readonly returnData: Hex }
function inspection(value: MintFallbackInspection): MintFallbackInspection {
  const v = { ...clone(value), configuration: normalizeMintFallbackConfiguration(value.configuration) };
  integer(v.blockNumber); hash(v.blockHash); uint(v.timestamp); normalizeMintFallbackPointerState(v.managerPointer); normalizeMintFallbackRetirementClassifier(v.classification);
  uint(v.primaryRetiredAt); uint(v.governanceNonce); hash(v.catalog.candidateProfileHash, true); hash(v.catalog.catalogHash, true); uint(v.catalog.entryCount); uint(v.catalog.revision);
  if (v.catalog.entryCount > 1024n || (v.readiness !== "configuration" && v.readiness !== "reserve") || typeof v.primaryWriter !== "boolean" || typeof v.successorReady !== "boolean" || (v.primaryRetiredAt !== 0n && v.primaryWriter)) throw Error("Malformed fallback inspection");
  if (v.import) verifyMintContinuityArtifact(v.import.artifact); if (v.recovery) normalizeMintFallbackIncident(v.recovery); return freeze(v);
}
function windowCheck(i: MintFallbackInspection, b: MintFallbackGovernanceBatch): void { const delay = b.plan.actionClass === 0n ? 0n : 172800n; if (i.timestamp > (1n << 64n) - 1n - 31536000n || b.window.notBefore < i.timestamp + delay || b.window.expiresAfter > i.timestamp + 31536000n || (delay !== 0n && b.window.expiresAfter - b.window.notBefore < 604800n)) throw Error("Original governance delay/open/lifetime window differs"); }
export function prepareMintFallbackGovernance(input: MintFallbackInspection, plan: MintFallbackCallPlan, proposer: Address, window: MintFallbackGovernanceWindow): PreparedMintFallbackGovernance {
  const i = inspection(input), canonical = normalizeMintFallbackPlan(plan), batch = mintFallbackGovernanceBatch(canonical, i.governanceNonce, window); if (new TextEncoder().encode(batch.window.reasonURI).length > 2048 || (coder.encode(["bytes[]"], [canonical.data]).length - 2) / 2 > 24575) throw Error("Governance reason URI or SSTORE2 publication exceeds supported bounds"); equal(i.configuration, canonical.configuration); windowCheck(i, batch); return freeze({ inspection: i, batch, proposer: addr(proposer) });
}
function prepared(v: PreparedMintFallbackGovernance): PreparedMintFallbackGovernance { const b = normalizeMintFallbackGovernanceBatch(v.batch), out = prepareMintFallbackGovernance(v.inspection, b.plan, v.proposer, b.window); equal(out, v); return out; }
export function prepareMintFallbackGovernanceOperation(input: PreparedMintFallbackGovernance, stage: MintFallbackGovernanceOperation["stage"], caller: Address): MintFallbackGovernanceOperation {
  const p = prepared(input), actor = addr(caller); if (!["publish", "schedule", "execute"].includes(stage)) throw Error("Unsupported governance stage"); if (stage === "schedule" && !same(actor, p.proposer)) throw Error("Schedule caller differs from reviewed proposer"); return freeze({ kind: "governance", prepared: p, stage, caller: actor, call: stage === "publish" ? p.batch.publicationCall : stage === "schedule" ? p.batch.scheduleCall : p.batch.executionCall });
}
export function prepareMintFallbackPermissionless(input: MintFallbackInspection, plan: MintFallbackCallPlan, caller: Address): MintFallbackPermissionlessOperation { const i = inspection(input), canonical = normalizeMintFallbackPlan(plan); equal(i.configuration, canonical.configuration); if (!canonical.permissionless || canonical.targetCalls.length !== 1) throw Error("Target requires the original GovernanceExecutor boundary"); return freeze({ kind: "permissionless", inspection: i, plan: canonical, caller: addr(caller), call: canonical.targetCalls[0]! }); }
function operation(v: MintFallbackOperation): MintFallbackOperation { const out = v.kind === "governance" ? prepareMintFallbackGovernanceOperation(v.prepared, v.stage, v.caller) : v.kind === "permissionless" ? prepareMintFallbackPermissionless(v.inspection, v.plan, v.caller) : null; if (!out) throw Error("Unsupported operation"); equal(out, v); return out; }
function parts(o: MintFallbackOperation): { i: MintFallbackInspection; plan: MintFallbackCallPlan } { return o.kind === "governance" ? { i: o.prepared.inspection, plan: o.prepared.batch.plan } : { i: o.inspection, plan: o.plan }; }
async function originalInspection(p: Reader, i: MintFallbackInspection): Promise<void> { const actual = await inspectMintFallback(p, i.configuration, { blockTag: i.blockNumber, readiness: i.readiness, ...(i.import ? { importArtifact: i.import.artifact } : {}), ...(i.recovery ? { recovery: { tokenId: i.recovery.tokenId, operationId: i.recovery.operationId } } : {}) }); equal(actual, i, "Saved inspection no longer matches its pinned historical block"); }
async function published(p: Reader, b: MintFallbackGovernanceBatch, tag: number): Promise<Address | null> { const [value] = await rpc(p, b.plan.configuration.governance, executorAbi, "publishedCallData", [b.publicationKey], tag); if (same(value, ZeroAddress)) return null; const target = addr(value), code = bytes(await p.getCode(target, tag), 24576), expected = coder.encode(["bytes[]"], [b.plan.data]); if (!same(code, `0x00${expected.slice(2)}`)) throw Error("Published governance bytes differ"); return target; }
const actionNames = ["status", "actionClass", "target", "value", "selector", "callHash", "scopeHash", "oldValueHash", "newValueHash", "notBefore", "expiresAfter", "proposer", "executor", "canceller", "vetoer", "reasonHash", "reasonURI", "manifestHash"];
async function action(p: Reader, prepared: PreparedMintFallbackGovernance, tag: number): Promise<Record<string, unknown>> {
  const b = prepared.batch, c = b.plan.configuration, [value] = await rpc(p, c.governance, executorAbi, "governanceAction", [b.actionId], tag), a = record(value as readonly unknown[], actionNames);
  const expected = { actionClass: b.plan.actionClass, target: b.plan.calls[0]!.target, value: 0n, selector: b.plan.calls[0]!.selector, callHash: b.callsHash, scopeHash: b.scopeHash, oldValueHash: b.oldValueHash, newValueHash: b.newValueHash, notBefore: b.window.notBefore, expiresAfter: b.window.expiresAfter, proposer: prepared.proposer, reasonHash: b.window.reasonHash, reasonURI: b.window.reasonURI, manifestHash: b.window.manifestHash };
  for (const [key, value] of Object.entries(expected)) if (a[key] !== value && (key === "reasonURI" || !same(a[key], value))) throw Error(`Scheduled action ${key} differs`);
  const [data] = await rpc(p, c.governance, executorAbi, "scheduledCallData", [b.actionId], tag); equal(Array.from(data as readonly unknown[]), b.plan.data, "Scheduled calldata differs"); const [ptr] = await rpc(p, c.governance, executorAbi, "scheduledCallDataPointer", [b.actionId], tag), pub = await published(p, b, tag); if (!pub || !same(ptr, pub)) throw Error("Scheduled publication pointer differs"); return a;
}
/** Replays the exact original outer call from its actual caller; never signs or broadcasts. */
export async function simulateMintFallbackOperation(p: Reader, input: MintFallbackOperation, options: { readonly blockTag: number }): Promise<MintFallbackSimulation> {
  const o = operation(input), { i, plan } = parts(o), tag = integer(options.blockTag); if (tag < i.blockNumber) throw Error("Simulation predates prepared inspection"); await originalInspection(p, i);
  const observed = await inspectMintFallback(p, plan.configuration, o.kind === "governance" && o.stage === "publish" ? { blockTag: tag, readiness: "configuration" } : inspectionOptions(plan, tag));
  if (o.kind === "permissionless") await validatePlan(p, plan, observed, true);
  else {
    const b = o.prepared.batch; if (o.stage !== "publish") equal(observed.catalog, i.catalog, "Governance catalog changed; reschedule under the current catalog");
    if (o.stage !== "publish") await validatePlan(p, plan, observed, o.stage === "execute");
    if (o.stage === "schedule") { if (observed.governanceNonce !== b.nonce) throw Error("Governance nonce changed; rebuild the scheduling request"); windowCheck(observed, b); if (!await published(p, b, tag)) throw Error("Governance calldata must be published first"); }
    if (o.stage === "execute") { const a = await action(p, o.prepared, tag); if (a.status !== 1n || observed.timestamp < b.window.notBefore || observed.timestamp > b.window.expiresAfter) throw Error("Action is not scheduled inside its execution window"); }
  }
  const returned = bytes(await p.call({ ...o.call, from: o.caller, blockTag: tag }));
  if (o.kind === "governance" && o.stage !== "execute") { const name = o.stage === "publish" ? "publishGovernanceCallData" : "scheduleGovernanceBatch", r = executorAbi.decodeFunctionResult(name, returned); if (!same(executorAbi.encodeFunctionResult(name, r), returned)) throw Error("Noncanonical simulation return"); if (o.stage === "schedule" && !same(r[0], o.prepared.batch.actionId)) throw Error("Simulated action ID differs"); if (o.stage === "publish") addr(r[0]); } else if (returned !== "0x") throw Error("Unexpected void simulation return");
  await unchanged(p, { number: tag, hash: observed.blockHash, timestamp: observed.timestamp }); return freeze({ operation: o, observed, returnData: returned });
}

export interface MintFallbackEventReference { readonly address: Address; readonly event: string; readonly logIndex: number; readonly transactionHash: Hex; readonly blockHash: Hex }
export interface MintFallbackOperationReceipt {
  readonly operation: MintFallbackOperation; readonly transactionHash: Hex; readonly blockNumber: number; readonly blockHash: Hex;
  readonly observed: MintFallbackInspection; readonly events: readonly MintFallbackEventReference[];
  readonly stateAttribution: "receipt-block observation; exact operation is bound by transaction and events";
}
interface ReceiptLog { address: Address; topics: Hex[]; data: Hex; index: number }
interface ReceiptContext { hash: Hex; blockNumber: number; blockHash: Hex; logs: ReceiptLog[]; refs: MintFallbackEventReference[] }
const safeAbi = new Interface(["function execTransaction(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,bytes signatures) returns(bool)"]);
const safeLegacy = new Interface(["event ExecutionSuccess(bytes32 txHash,uint256 payment)", "event ExecutionFailure(bytes32 txHash,uint256 payment)"]), safeIndexed = new Interface(["event ExecutionSuccess(bytes32 indexed txHash,uint256 payment)", "event ExecutionFailure(bytes32 indexed txHash,uint256 payment)"]);
function events(r: ReceiptContext, target: Address, abi: Interface, name: string): { args: readonly unknown[]; log: ReceiptLog }[] { const fragment = abi.getEvent(name)!; return r.logs.filter(x => same(x.address, target) && same(x.topics[0], fragment.topicHash)).map(log => { const args = abi.decodeEventLog(fragment, log.data, log.topics), encoded = abi.encodeEventLog(fragment, args); equal(encoded.topics.map(x => x.toLowerCase()), log.topics, "Noncanonical event topics"); if (!same(encoded.data, log.data)) throw Error("Noncanonical event data"); return { args, log }; }); }
function ref(r: ReceiptContext, log: ReceiptLog, name: string): void { r.refs.push({ address: log.address, event: name, logIndex: log.index, transactionHash: r.hash, blockHash: r.blockHash }); }
function one(r: ReceiptContext, target: Address, abi: Interface, name: string, expected: readonly unknown[]): ReceiptLog { const found = events(r, target, abi, name); if (found.length !== 1) throw Error(`Expected one ${name}`); equal(Array.from(found[0]!.args), expected, `${name} fields differ`); ref(r, found[0]!.log, name); return found[0]!.log; }
async function mined(p: ReceiptReader, o: MintFallbackOperation, txHash: Hex, execution: "direct" | "safe"): Promise<ReceiptContext> {
  const [receipt, tx] = await Promise.all([p.getTransactionReceipt(txHash), p.getTransaction(txHash)]), { i, plan } = parts(o); if (!receipt || !tx || receipt.status !== 1 || !same(receipt.hash, txHash) || !same(tx.hash, txHash) || tx.chainId !== plan.configuration.chainId || receipt.blockNumber <= i.blockNumber || tx.blockNumber !== receipt.blockNumber || !same(tx.blockHash, receipt.blockHash) || !same(receipt.to, tx.to) || !same(receipt.from, tx.from) || tx.value !== 0n) throw Error("Receipt/transaction identity or chronology differs");
  const data = bytes(tx.data, 262144); if (execution === "direct") { if (!same(tx.from, o.caller) || !same(tx.to, o.call.to) || !same(data, o.call.data)) throw Error("Direct operation differs"); }
  else if (execution === "safe") { if (!same(tx.to, o.caller)) throw Error("Safe address differs"); const decoded = safeAbi.decodeFunctionData("execTransaction", data); if (!same(safeAbi.encodeFunctionData("execTransaction", decoded), data) || !same(decoded[0], o.call.to) || decoded[1] !== 0n || !same(decoded[2], o.call.data) || decoded[3] !== 0n) throw Error("Safe must execute the exact ordinary zero-value CALL"); }
  else throw Error("Unsupported receipt execution mode");
  if (!Array.isArray(receipt.logs) || receipt.logs.length > 1024) throw Error("Receipt logs exceed client bound"); const logs = receipt.logs.map(log => { if (log.removed || !same(log.transactionHash, txHash) || log.blockNumber !== receipt.blockNumber || !same(log.blockHash, receipt.blockHash) || !Array.isArray(log.topics) || log.topics.length > 4) throw Error("Malformed receipt log identity"); return { address: addr(log.address), topics: log.topics.map((v: string) => hash(v, true)), data: bytes(log.data, 32768), index: integer(log.index) }; }); if (new Set(logs.map(x => x.index)).size !== logs.length || logs.some((x, n) => n > 0 && x.index <= logs[n - 1]!.index)) throw Error("Duplicate/unordered receipt log index");
  const r: ReceiptContext = { hash: txHash, blockNumber: integer(receipt.blockNumber), blockHash: hash(receipt.blockHash), logs, refs: [] }; const h = await header(p, r.blockNumber); if (!same(h.hash, r.blockHash)) throw Error("Receipt block is not canonical");
  if (execution === "safe") { const relevant = logs.filter(x => same(x.address, o.caller) && (same(x.topics[0], safeLegacy.getEvent("ExecutionSuccess")!.topicHash) || same(x.topics[0], safeLegacy.getEvent("ExecutionFailure")!.topicHash))); if (relevant.length !== 1 || !same(relevant[0]!.topics[0], safeLegacy.getEvent("ExecutionSuccess")!.topicHash)) throw Error("Safe requires exactly one success and no failure"); const log = relevant[0]!, abi = log.topics.length === 2 ? safeIndexed : safeLegacy, parsed = events(r, o.caller, abi, "ExecutionSuccess"); if (parsed.length !== 1) throw Error("Invalid Safe success"); ref(r, log, "ExecutionSuccess"); }
  return r;
}
async function importReadback(p: Reader, plan: MintFallbackCallPlan, r: ReceiptContext): Promise<void> {
  const c = plan.configuration, q = plan.request, root = "artifact" in q ? q.artifact.importRoot : "importRoot" in q ? q.importRoot : "snapshot" in q ? q.snapshot.importRoot : "batch" in q ? q.batch.importRoot : "descriptor" in q ? q.descriptor.importRoot : null; if (!root) return;
  const [recordValue] = await rpc(p, c.ledger, ledgerAbi, "mintImportCommitment", [root], r.blockNumber), v = recordValue as readonly unknown[]; if (!same(v[0], c.ledger) || !same(v[1], c.primary) || !same(v[2], c.fallbackManager)) throw Error("Receipt import pair differs");
  if ("artifact" in q && (v[3] !== q.artifact.coordinates.snapshotBlock || !same(v[4], q.artifact.manifestHash))) throw Error("Receipt artifact commitment differs");
  const [definitions, ancestry, [sourceDefinitions], [sourceAncestors]] = await Promise.all([rpc(p, c.ledger, ledgerAbi, "mintImportDefinitionProgress", [root], r.blockNumber), rpc(p, c.ledger, ledgerAbi, "mintImportAncestryProgress", [root], r.blockNumber), rpc(p, c.ledger, ledgerAbi, "managerDefinitionCount", [c.primary], r.blockNumber), rpc(p, c.ledger, ledgerAbi, "mintAncestorCount", [c.primary], r.blockNumber)]);
  if (definitions[1] !== sourceDefinitions || ancestry[1] !== sourceAncestors || uint(definitions[0]) > uint(definitions[1]) || uint(ancestry[0]) > uint(ancestry[1]) || (v[7] === true && (definitions[0] !== definitions[1] || ancestry[0] !== ancestry[1]))) throw Error("Receipt definition/ancestry progress differs");
  if (q.kind === "import-commit" || q.kind === "raw-import-commit") { const s = "artifact" in q ? { ...q.artifact.coordinates, importRoot: q.artifact.importRoot, manifestHash: q.artifact.manifestHash } : q.snapshot; one(r, c.ledger, ledgerAbi, "MintLedgerImportRootCommitted", [1n, root, c.primary, c.fallbackManager, c.ledger, s.snapshotBlock, s.manifestHash]); if (v[3] !== s.snapshotBlock || !same(v[4], s.manifestHash)) throw Error("Committed snapshot differs"); }
  if (q.kind === "complete-import" || q.kind === "raw-complete-import") { const counters = "artifact" in q ? BigInt(q.artifact.counterLeaves.length) : q.descriptor.counterCount, nullifiers = "artifact" in q ? BigInt(q.artifact.nullifiers.length) : q.descriptor.nullifierCount; one(r, c.ledger, ledgerAbi, "MintLedgerImportCompleted", [root, c.fallbackManager, counters, nullifiers]); if (v[7] !== true || v[5] !== counters || v[6] !== nullifiers) throw Error("Completed import readback differs"); }
  if (q.kind === "copy-definitions" || q.kind === "raw-copy-definitions" || q.kind === "copy-ancestors" || q.kind === "raw-copy-ancestors") { const definitions = q.kind.endsWith("definitions"), name = definitions ? "MintLedgerImportProfileCopied" : "MintLedgerAncestorImported", found = events(r, c.ledger, ledgerAbi, name); if (found.length > Number(q.maxCount)) throw Error("Copy event count exceeds reviewed bound"); for (const item of found) { if (!same(item.args[0], root) || (!definitions && (!same(item.args[1], c.fallbackManager) || same(item.args[2], ZeroAddress) || same(item.args[3], ZeroAddress) || same(item.args[3], c.fallbackManager)))) throw Error("Copy event belongs to another import"); ref(r, item.log, name); } const progress = await rpc(p, c.ledger, ledgerAbi, definitions ? "mintImportDefinitionProgress" : "mintImportAncestryProgress", [root], r.blockNumber); if (uint(progress[0]) > uint(progress[1])) throw Error("Copy progress differs"); }
  if (q.kind === "import-state" || q.kind === "raw-import-state") {
    const counters = q.kind === "import-state" ? q.counterIndexes.map(index => q.artifact.counterLeaves[index]!) : q.batch.counters, nullifiers = q.kind === "import-state" ? q.nullifierIndexes.map(index => q.artifact.nullifiers[index]!) : q.batch.nullifiers, ce = events(r, c.ledger, ledgerAbi, "MintLedgerCounterImported"), ne = events(r, c.ledger, ledgerAbi, "MintLedgerNullifierImported"); if (ce.length !== counters.length || ne.length !== nullifiers.length || uint(v[5]) < BigInt(ce.length) || uint(v[6]) < BigInt(ne.length)) throw Error("Import leaf event count differs");
    for (let n = 0; n < counters.length; n++) { const leaf = counters[n]!, e = ce[n]!, [key] = await rpc(p, c.ledger, ledgerAbi, "deriveCounterValueKey", [c.fallbackManager, leaf.collectionId, leaf.phaseId, leaf.counterId, leaf.predecessorSubjectKey], r.blockNumber); equal(Array.from(e.args).slice(0, 8), [1n, root, key, leaf.predecessorSubjectKey, leaf.collectionId, leaf.phaseId, leaf.counterId, leaf.value], "Counter import event differs"); if (uint(e.args[8]) < leaf.value) throw Error("Counter resulting value decreased"); const [current] = await rpc(p, c.ledger, ledgerAbi, "counterValue", [key], r.blockNumber); if (uint(current) < uint(e.args[8])) throw Error("Counter readback decreased"); ref(r, e.log, "MintLedgerCounterImported"); }
    for (let n = 0; n < nullifiers.length; n++) { const e = ne[n]!; equal(Array.from(e.args), [1n, root, nullifiers[n], c.fallbackManager], "Nullifier import event differs"); const [used] = await rpc(p, c.ledger, ledgerAbi, "isManagerNullifierUsed", [c.fallbackManager, nullifiers[n]], r.blockNumber); if (used !== true) throw Error("Imported nullifier readback absent"); ref(r, e.log, "MintLedgerNullifierImported"); }
  }
}
async function executedTargets(p: Reader, o: MintFallbackOperation, r: ReceiptContext, observed: MintFallbackInspection): Promise<void> {
  const { plan } = parts(o), c = plan.configuration, q = plan.request, actionId = o.kind === "governance" ? o.prepared.batch.actionId : ZERO;
  if (q.kind === "retirement-classification") { one(r, c.governance, executorAbi, "TighteningCallUpdated", [1n, c.ledger, ledgerAbi.getFunction("retireLedgerWriter")!.selector, true, c.ledgerCodeHash, q.classifier.revision + 1n, actionId]); if (observed.classification.revision < q.classifier.revision + 1n || (observed.classification.revision === q.classifier.revision + 1n && (!observed.classification.enabled || !same(observed.classification.targetCodeHash, c.ledgerCodeHash) || !same(observed.classification.stateHash, plan.calls[0]!.newValueHash)))) throw Error("Classification readback differs"); }
  if (q.kind === "retirement") { one(r, c.ledger, ledgerAbi, "MintLedgerWriterRetired", [c.primary, BigInt(r.blockNumber)]); if (observed.primaryRetiredAt !== BigInt(r.blockNumber) || observed.primaryWriter) throw Error("Retirement readback differs"); }
  await importReadback(p, plan, r);
  if (q.kind === "activation" || q.kind === "incident-activation") {
    const a = q.activation, pe = one(r, c.core, coreAbi, "CoreSatellitePointerUpdated", [1n, id("MINT_MANAGER"), actionId, c.fallbackManager, c.primary]), me = one(r, a.manifest, manifestAbi, "StreamSystemManifestPublished", [1n, a.update.manifestHash, a.payloadRoot, actionId]); if (pe.index >= me.index) throw Error("Manifest must follow pointer activation"); const current = await manifestState(p, a.manifest, r.blockNumber);
    if (observed.managerPointer.revision < a.previousPointer.revision + 1n || (observed.managerPointer.revision === a.previousPointer.revision + 1n && !same(observed.managerPointer.target, c.fallbackManager)) || current.revision < a.current.revision + 1n || (current.revision === a.current.revision + 1n && (!same(current.manifestHash, a.update.manifestHash) || !same(current.payloadRoot, a.payloadRoot)))) throw Error("Activation readback differs");
    if (observed.managerPointer.revision === a.previousPointer.revision + 1n) equal(observed.managerPointer, mintFallbackNextPointer(c, a.previousPointer), "Activation pointer fields differ");
    if (current.revision === a.current.revision + 1n) equal(current, { manifestHash: a.update.manifestHash, manifestURI: a.update.manifestURI, modules: { ...a.current.modules, mintManager: c.fallbackManager }, discovery: Object.fromEntries(manifestDiscovery.map(k => [k, a.update[k as keyof MintFallbackManifestUpdate]])), revision: a.current.revision + 1n, payloadRoot: a.payloadRoot }, "Activation manifest fields differ");
    if (q.kind === "incident-activation") { const x = q.incident, ce = one(r, c.core, coreAbi, "TokenCollectionRegistrationReverted", [1n, x.tokenId, x.state.collectionId]), re = one(r, c.fallbackManager, fallbackAbi, "MintFallbackPreparedRecovered", [1n, actionId, x.tokenId, x.operationId, x.state.collectionId]); if (!(pe.index < ce.index && ce.index < re.index && re.index < me.index)) throw Error("Recovery batch event order differs");
      const [[prepared], identity, [data], [coordinator], [last], [next], [minted]] = await Promise.all([rpc(p, c.core, coreAbi, "preparedMint", [x.tokenId], r.blockNumber), rpc(p, c.core, coreAbi, "tokenCollectionIdentity", [x.tokenId], r.blockNumber), rpc(p, c.core, coreAbi, "tokenData", [x.tokenId], r.blockNumber), rpc(p, c.core, coreAbi, "coordinatorAtMint", [x.tokenId], r.blockNumber), rpc(p, c.core, coreAbi, "lastAllocatedTokenId", [], r.blockNumber), rpc(p, c.core, coreAbi, "collectionNextSerial", [x.state.collectionId], r.blockNumber), rpc(p, c.core, coreAbi, "collectionMintedEver", [x.state.collectionId], r.blockNumber)]); equal(Array.from(prepared as readonly unknown[]), [false, ZERO, 0n], "Recovered preparation persists"); equal(Array.from(identity), [false, 0n, 0n, false], "Recovered collection identity persists"); if (data !== "0x" || !same(coordinator, ZeroAddress) || uint(last) < x.state.lastTokenId || uint(next) < x.state.nextSerial || uint(minted) < x.state.mintedEver) throw Error("Recovered state/readback differs");
    }
  }
}
/** Confirms exact direct/Safe CALL and protocol events, with separately labelled end-of-block state. */
export async function inspectMintFallbackOperationReceipt(p: ReceiptReader, input: MintFallbackOperation, options: { readonly transactionHash: Hex; readonly execution: "direct" | "safe" }): Promise<MintFallbackOperationReceipt> {
  const o = operation(input), txHash = hash(options.transactionHash), execution = options.execution, { i, plan } = parts(o); await originalInspection(p, i); const r = await mined(p, o, txHash, execution);
  const observed = await inspectMintFallback(p, plan.configuration, { blockTag: r.blockNumber, readiness: "configuration" }); if (!same(observed.blockHash, r.blockHash)) throw Error("Receipt block changed");
  if (o.kind === "permissionless") await executedTargets(p, o, r, observed);
  else { const b = o.prepared.batch, c = plan.configuration;
    if (o.stage === "publish") { const ptr = await published(p, b, r.blockNumber); if (!ptr) throw Error("Publication readback absent"); const found = events(r, c.governance, executorAbi, "GovernanceCallDataPublished"); if (found.length > 1) throw Error("Duplicate publication event"); if (found.length) one(r, c.governance, executorAbi, "GovernanceCallDataPublished", [1n, b.publicationKey, ptr, o.caller]); }
    else { const a = await action(p, o.prepared, r.blockNumber), common = [1n, b.actionId, plan.actionClass, plan.calls[0]!.target, 0n, plan.calls[0]!.selector, b.callsHash, b.scopeHash, b.oldValueHash, b.newValueHash];
      one(r, c.governance, executorAbi, "GovernanceActionPolicyValidated", [1n, b.actionId, o.stage === "schedule" ? 1n : 2n, i.catalog.candidateProfileHash, i.catalog.catalogHash]);
      if (o.stage === "schedule" && (uint(a.status) < 1n || uint(a.status) > 5n || observed.governanceNonce < b.nonce + 1n)) throw Error("Scheduled action status/nonce readback differs");
      if (o.stage === "schedule") one(r, c.governance, executorAbi, "GovernanceActionScheduled", [...common, b.window.notBefore, b.window.expiresAfter, b.nonce, o.caller, b.window.reasonHash, b.window.reasonURI, b.window.manifestHash]);
      else { if (a.status !== 3n || !same(a.executor, o.caller)) throw Error("Executed action readback differs"); one(r, c.governance, executorAbi, "GovernanceActionExecuted", [...common, o.caller, b.window.manifestHash]); await executedTargets(p, o, r, observed); }
    }
  }
  await unchanged(p, { number: r.blockNumber, hash: observed.blockHash, timestamp: observed.timestamp }); return freeze({ operation: o, transactionHash: txHash, blockNumber: r.blockNumber, blockHash: r.blockHash, observed, events: r.refs.sort((a, b) => a.logIndex - b.logIndex), stateAttribution: "receipt-block observation; exact operation is bound by transaction and events" });
}

// Exact selected fragments from the retained current-stack compiler capture.
const coreAbi = new Interface([
  "event CoreSatellitePointerUpdated(uint16 schemaVersion, bytes32 indexed pointerType, bytes32 indexed actionId, address indexed newTarget, address oldTarget)",
  "event TokenCollectionRegistrationReverted(uint16 schemaVersion, uint256 indexed tokenId, uint256 indexed collectionId)",
  "function collectionMintedEver(uint256 collectionId) view returns (uint256)",
  "function collectionNextSerial(uint256 collectionId) view returns (uint256)",
  "function coordinatorAtMint(uint256 tokenId) view returns (address)",
  "function getSatellitePointer(bytes32 pointerType) view returns (address target, bytes32 codeHash, bool frozen, bytes32 moduleType, bytes4 interfaceId, address registry, uint8 registryStatus, bytes32 moduleManifestHash, bytes32 deploymentManifestHash, uint64 revision)",
  "function lastAllocatedTokenId() view returns (uint256)",
  "function pendingPreparedMintTokenId() view returns (uint256 tokenId)",
  "function preparedMint(uint256 tokenId) view returns ((bool exists, bytes32 operationId, uint256 collectionId) record)",
  "function tokenCollectionIdentity(uint256 tokenId) view returns (bool mappingExists, uint256 collectionId, uint256 collectionSerial, bool burned)",
  "function tokenData(uint256 tokenId) view returns (bytes)",
  "function tokenLifecycle(uint256 tokenId) view returns (uint8 lifecycle)",
  "function totalSupply() view returns (uint256)",
  "function updateSatellitePointer(bytes32 pointerType, address newTarget)"
]);
const ledgerAbi = new Interface([
  "event MintLedgerAncestorImported(bytes32 indexed importRoot, address indexed successorManager, address indexed ancestorLedger, address ancestorManager)",
  "event MintLedgerCounterImported(uint16 schemaVersion, bytes32 indexed importRoot, bytes32 indexed valueKey, bytes32 indexed subjectKey, uint256 collectionId, bytes32 phaseId, bytes32 counterId, uint64 importedValue, uint64 resultingValue)",
  "event MintLedgerImportCompleted(bytes32 indexed importRoot, address indexed successorManager, uint64 counterLeaves, uint64 nullifierLeaves)",
  "event MintLedgerImportProfileCopied(bytes32 indexed importRoot, bytes32 indexed definitionHash, bool defined)",
  "event MintLedgerImportRootCommitted(uint16 schemaVersion, bytes32 indexed importRoot, address indexed predecessorManager, address indexed successorManager, address predecessorLedger, uint64 snapshotBlock, bytes32 manifestHash)",
  "event MintLedgerNullifierImported(uint16 schemaVersion, bytes32 indexed importRoot, bytes32 indexed nullifier, address indexed successorManager)",
  "event MintLedgerWriterRetired(address indexed writer, uint64 blockNumber)",
  "function commitCounterImportRoot(address predecessorLedger, address predecessorManager, address successorManager, uint64 snapshotBlock, bytes32 importRoot, bytes32 manifestHash)",
  "function completeCounterImport(bytes32 root, uint64 counterLeaves, uint64 nullifierLeaves, bytes32[] descriptorProof)",
  "function counterDefinitionForManager(address manager, bytes32 hash) view returns (bool, (uint8 scope, uint8 keyMode, bytes32 capRoot, bytes32 metadataHash) d)",
  "function counterValue(bytes32) view returns (uint64)",
  "function deriveCounterValueKey(address manager, uint256 collectionId, bytes32 phaseId, bytes32 counterId, bytes32 subjectKey) pure returns (bytes32)",
  "function importCounterDefinitions(bytes32 root, uint256 maxCount)",
  "function importMintAncestors(bytes32 root, uint256 maxCount)",
  "function isCompletedMintDescendant(address ancestorLedger, address ancestorManager, address successorManager) view returns (bool)",
  "function isManagerNullifierUsed(address manager, bytes32 nullifier) view returns (bool)",
  "function isMintSuccessorReady(address predecessorLedger, address predecessorManager, address successorManager) view returns (bool)",
  "function isStreamMintLedger() pure returns (bool)",
  "function ledgerWriter(address) view returns (bool)",
  "function ledgerWriterRetiredAt(address) view returns (uint64)",
  "function managerDefinitionAt(address manager, uint256 index) view returns (bytes32 hash, bool defined, (uint8 scope, uint8 keyMode, bytes32 capRoot, bytes32 metadataHash) d)",
  "function managerDefinitionCount(address manager) view returns (uint256)",
  "function mintAncestorAt(address manager, uint256 index) view returns (address ledger, address ancestorManager)",
  "function mintAncestorCount(address manager) view returns (uint256)",
  "function mintImportAncestryProgress(bytes32 root) view returns (uint256 imported, uint256 required)",
  "function mintImportCommitment(bytes32 root) view returns ((address predecessorLedger, address predecessorManager, address successorManager, uint64 snapshotBlock, bytes32 manifestHash, uint64 importedCounters, uint64 importedNullifiers, bool complete))",
  "function mintImportDefinitionProgress(bytes32 root) view returns (uint256 imported, uint256 required)",
  "function owner() view returns (address)",
  "function retireLedgerWriter(address writer)"
]);
const managerAbi = new Interface([
  "event PreparedNativeRecorderBound(address indexed recorder, bytes32 runtimeCodeHash, uint64 boundAt, uint64 moduleRevision)",
  "function bindPreparedNativeRecorder(address recorder)",
  "function core() view returns (address)",
  "function gasParameterInfo(bytes32 parameterId) view returns (uint256 value, uint256 floor, uint8 failureClass, uint64 revision)",
  "function governanceAuthority() view returns (address)",
  "function importMintState(bytes encodedBatch)",
  "function isStreamMintManager() pure returns (bool)",
  "function mintLedger() view returns (address)",
  "function moduleRegistry() view returns (address)",
  "function owner() view returns (address)",
  "function preparedNativeRecorder() view returns (address, bytes32, uint64, uint64)",
  "function supportsInterface(bytes4 interfaceId) view returns (bool)"
]);
const registryAbi = new Interface([
  "event StreamModuleRegistered(uint16 schemaVersion, address indexed module, bytes32 indexed moduleType, bytes4 indexed interfaceId, bytes32 moduleVersion, uint32 moduleGasLimit, bytes32 runtimeCodeHash, bytes32 deploymentManifestHash, bytes32 moduleManifestHash, string moduleManifestURI, bytes32 recordChainHash)",
  "event StreamModuleStatusChanged(uint16 schemaVersion, address indexed module, bytes32 indexed moduleType, uint8 status, bytes32 reasonHash, string reasonURI)",
  "function governanceExecutor() view returns (address)",
  "function isModuleEligible(address module, bytes32 expectedModuleType, bytes4 expectedInterfaceId) view returns (bool)",
  "function moduleCount() view returns (uint256)",
  "function moduleRecord(address module) view returns ((uint8 status, bytes32 moduleType, bytes32 moduleVersion, bytes4 interfaceId, uint32 moduleGasLimit, bytes32 runtimeCodeHash, bytes32 deploymentManifestHash, bytes32 moduleManifestHash, string moduleManifestURI, uint64 registeredAt, uint64 statusUpdatedAt, uint64 revision))",
  "function registerModule((address module, bytes32 moduleType, bytes32 moduleVersion, bytes4 interfaceId, uint32 moduleGasLimit, bytes32 expectedRuntimeCodeHash, bytes32 deploymentManifestHash, bytes32 moduleManifestHash, string moduleManifestURI) registration)",
  "function registrationChainHash() view returns (bytes32 chainHash, uint64 recordCount)",
  "function setModuleStatus(address module, uint8 newStatus, bytes32 reasonHash, string reasonURI)"
]);
const executorAbi = new Interface([
  "event GovernanceActionCancelled(uint16 schemaVersion, bytes32 indexed actionId, uint8 indexed actionClass, address indexed target, bytes4 selector, bytes32 callHash, bytes32 scopeHash, address canceller, bytes32 reasonHash, string reasonURI)",
  "event GovernanceActionExecuted(uint16 schemaVersion, bytes32 indexed actionId, uint8 indexed actionClass, address indexed target, uint256 value, bytes4 selector, bytes32 callHash, bytes32 scopeHash, bytes32 oldValueHash, bytes32 newValueHash, address executor, bytes32 manifestHash)",
  "event GovernanceActionExpired(uint16 schemaVersion, bytes32 indexed actionId, uint8 indexed actionClass, address materializer)",
  "event GovernanceActionPolicyValidated(uint16 schemaVersion, bytes32 indexed actionId, uint8 indexed phase, bytes32 indexed candidateProfileHash, bytes32 catalogHash)",
  "event GovernanceActionScheduled(uint16 schemaVersion, bytes32 indexed actionId, uint8 indexed actionClass, address indexed target, uint256 value, bytes4 selector, bytes32 callHash, bytes32 scopeHash, bytes32 oldValueHash, bytes32 newValueHash, uint64 notBefore, uint64 expiresAfter, uint256 nonce, address proposer, bytes32 reasonHash, string reasonURI, bytes32 manifestHash)",
  "event GovernanceActionVetoed(uint16 schemaVersion, bytes32 indexed actionId, uint8 indexed actionClass, address indexed vetoer, bytes32 scopeHash, bytes32 reasonHash)",
  "event GovernanceCallDataPublished(uint16 schemaVersion, bytes32 indexed callDataKey, address pointer, address publisher)",
  "event TighteningCallUpdated(uint16 schemaVersion, address indexed target, bytes4 indexed selector, bool tightening, bytes32 targetCodeHash, uint64 revision, bytes32 indexed actionId)",
  "function currentAction() view returns (bool executing, bytes32 actionId, uint8 actionClass, bytes32 scopeHash, bytes32 oldValueHash, bytes32 newValueHash)",
  "function executeGovernanceAction(bytes32 actionId, bytes callData) payable",
  "function executeGovernanceBatch(bytes32 actionId, (address target, uint256 value, bytes4 selector, bytes32 callDataHash, bytes32 scopeHash, bytes32 oldValueHash, bytes32 newValueHash)[] calls, bytes[] callDatas) payable",
  "function governanceAction(bytes32 actionId) view returns ((uint8 status, uint8 actionClass, address target, uint256 value, bytes4 selector, bytes32 callHash, bytes32 scopeHash, bytes32 oldValueHash, bytes32 newValueHash, uint64 notBefore, uint64 expiresAfter, address proposer, address executor, address canceller, address vetoer, bytes32 reasonHash, string reasonURI, bytes32 manifestHash))",
  "function governanceActionFacts(bytes32 id) view returns ((uint8 status, uint8 actionClass, bytes32 callHash, uint64 notBefore, uint64 expiresAfter) facts)",
  "function governanceActionPolicyState() view returns (bytes32 candidateProfileHash, bytes32 catalogHash, uint256 entryCount, uint64 revision)",
  "function governanceNonce() view returns (uint256)",
  "function isProposer(address account) view returns (bool)",
  "function minimumDelay(uint8 actionClass) pure returns (uint64)",
  "function owner() view returns (address)",
  "function publishGovernanceCallData(bytes[] callDatas) returns (address pointer)",
  "function publishedCallData(bytes32 callDataKey) view returns (address)",
  "function scheduleGovernanceAction((uint8 actionClass, address target, uint256 value, bytes4 selector, bytes callData, bytes32 scopeHash, bytes32 oldValueHash, bytes32 newValueHash, uint64 notBefore, uint64 expiresAfter, bytes32 reasonHash, string reasonURI, bytes32 manifestHash) request) returns (bytes32 actionId)",
  "function scheduleGovernanceBatch(uint8 actionClass, (address target, uint256 value, bytes4 selector, bytes32 callDataHash, bytes32 scopeHash, bytes32 oldValueHash, bytes32 newValueHash)[] calls, bytes32 scopeHash, bytes32 oldValueHash, bytes32 newValueHash, uint64 notBefore, uint64 expiresAfter, bytes32 reasonHash, string reasonURI, bytes32 manifestHash) returns (bytes32 actionId)",
  "function scheduledCallData(bytes32 actionId) view returns (bytes[])",
  "function scheduledCallDataPointer(bytes32 actionId) view returns (address)",
  "function setTighteningCall(address target, bytes4 selector, bool tightening)",
  "function systemManifestBatchTailRule(address triggerTarget, bytes4 triggerSelector) view returns (bool registered, bytes32 triggerCodeHash, uint8 allowedActionClassMask, address tailTarget, bytes4 tailSelector, bytes32 tailCodeHash)",
  "function systemManifestBootstrapState() view returns (bool, bool, address, bytes32, address, bytes32, uint64, bytes32, uint256, bytes32, uint64, address, bytes32, address, bytes32, bytes32, uint256, bytes32, uint256, bytes32, bytes32, uint256, bytes32, uint256, address, address, bytes32, bytes32, uint256)",
  "function tighteningCallConfig(address target, bytes4 selector) view returns (bool tightening, bytes32 targetCodeHash, uint64 revision, bytes32 stateHash)"
]);
const manifestAbi = new Interface([
  "event StreamSystemManifestPublished(uint16 schemaVersion, bytes32 indexed manifestHash, address indexed payloadPointer, bytes32 indexed actionId)",
  "function core() view returns (address)",
  "function governanceExecutor() view returns (address)",
  "function publishStreamSystemManifest(address payloadPointer, (bytes32 manifestHash, string manifestURI, bytes32 eventCatalogHash, bytes32 compatibilityMatrixHash, bytes32 numericIdCatalogHash, bytes32 schemaCatalogHash, bytes32 canonicalizationCatalogHash, bytes32 specBundleHash, bytes32 reconstructionClientHash) update)",
  "function streamSystemManifest() view returns (bytes32 manifestHash, string manifestURI, address revenueResolver, address metadataRouter, address collectionMetadata, address entropyCoordinator, address mintManager, address mintLedger, address artistRegistry, address streamAdminsOrGovernance, address artworkFinalityRegistry, address moduleRegistry, address stateExportPublisher, bytes32 eventCatalogHash, bytes32 compatibilityMatrixHash, bytes32 numericIdCatalogHash, bytes32 schemaCatalogHash, bytes32 canonicalizationCatalogHash, bytes32 specBundleHash, bytes32 reconstructionClientHash, uint64 revision)",
  "function streamSystemManifestPointer() view returns (address payloadPointer)"
]);
const fallbackAbi = new Interface([
  "event MintFallbackPreparedRecovered(uint16 schemaVersion, bytes32 indexed actionId, uint256 indexed tokenId, bytes32 indexed operationId, uint256 collectionId)",
  "event PreparedNativeRecorderBound(address indexed recorder, bytes32 runtimeCodeHash, uint64 boundAt, uint64 moduleRevision)",
  "function bindPreparedNativeRecorder(address recorder)",
  "function core() view returns (address)",
  "function gasParameterInfo(bytes32 parameterId) view returns (uint256 value, uint256 floor, uint8 failureClass, uint64 revision)",
  "function governanceAuthority() view returns (address)",
  "function importMintState(bytes encodedBatch)",
  "function isStreamMintManager() pure returns (bool)",
  "function mintLedger() view returns (address)",
  "function moduleRegistry() view returns (address)",
  "function owner() view returns (address)",
  "function preparedNativeRecorder() view returns (address, bytes32, uint64, uint64)",
  "function recoverPreparedMint(uint256 tokenId, bytes32 operationId)",
  "function supportsInterface(bytes4 interfaceId) view returns (bool)"
]);
const recorderAbi = new Interface(["function core() view returns(address)","function moduleRegistry() view returns(address)","function coreCodeHash() view returns(bytes32)","function moduleRegistryCodeHash() view returns(bytes32)"]);
