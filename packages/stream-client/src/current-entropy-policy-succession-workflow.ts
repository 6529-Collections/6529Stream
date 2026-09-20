import { AbiCoder, Interface, ParamType, ZeroAddress, ZeroHash, getAddress, id, isHexString, keccak256, toUtf8Bytes } from "ethers";
import type { Provider } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import type { UnsignedCall } from "./binding.js";
import * as succession from "./current-entropy-policy-succession.js";
import { normalizeMintFallbackPointerState, normalizeMintFallbackManifestState } from "./current-mint-fallback.js";
import type { MintFallbackPointerState, MintFallbackManifestState, MintFallbackManifestUpdate } from "./current-mint-fallback.js";

// Exact retained ABI89, source7901f3b; the earlier entropy profiles remain separate.
const abi = new Interface([
  "event GovernanceActionPolicyExtended(uint64 indexed revision, bytes32 indexed oldCatalogHash, bytes32 indexed newCatalogHash, uint256 oldEntryCount, uint256 newEntryCount)",
  "function coordinator() view returns(address)",
  "function streamEntropyProviderConfigHash() view returns (bytes32)",
  "event CoreSatellitePointerUpdated(uint16 schemaVersion, bytes32 indexed pointerType, bytes32 indexed actionId, address indexed newTarget, address oldTarget)",
  "function core() view returns (address)",
  "function authority() view returns (address)",
  "function roleRegistry() view returns (address)",
  "function streamModuleType() pure returns (bytes32)",
  "function streamModuleVersion() pure returns (bytes32)",
  "function streamModuleInterfaceId() pure returns (bytes4)",
  "function streamModuleManifest() view returns (string uri, bytes32 hash)",
  "function streamModuleDeploymentManifestHash() view returns (bytes32)",
  "function supportsInterface(bytes4 id) view returns (bool)",
  "function entropyPolicyInventory() view returns (uint256, uint64, bytes32)",
  "function entropyPolicyCollectionAt(uint256 index) view returns (uint256)",
  "function exportEntropyPolicy(uint256 id) view returns ((uint256 collectionId, uint8 profile, address policyOrigin, bytes32 policyOriginCodeHash, (bool configured, bool explicitPolicy, bool frozen, uint8 mode, uint8 securityClass, uint8 renderRequirement, uint64 revision, uint32 providerEpoch, bytes32 policyHash, bytes32 contentStateHash, bytes32 lastActionId, bytes32 artistConsentRecord) record, (uint8 mode, uint8 securityClass, uint8 renderRequirement, address provider, bytes32 collectionSalt, bool publicRequests, uint64 timeoutBlocks, (bool declared, uint8 requestMode, bytes32 revealOwnerRole, uint64 requestSLOBlocks, uint256 revealFeePerTokenWei) reveal, uint16 maxFreshRecoveryAttempts, bytes32 recoveryPolicyId) policy, bytes32 providerCodeHash, bytes32 providerConfigHash, (bytes32 policyId, bytes32 policyHash, uint16 maxFreshRecoveryAttempts, uint64 revision, bytes32 lastActionId) recovery))",
  "function exportEntropyRecovery(bytes32 id) view returns ((bytes32 policyId, (bool exists, bool frozen, uint16 maxFreshRecoveryAttempts, bytes32 incidentDeclarerRole, bytes32 reasonSchemaHash, bytes32 policyManifestHash, (address provider, uint32 providerEpoch, bytes32 providerConfigHash, uint64 notBeforeBlocks, bool acceptLateOriginalFulfillment)[] steps) policy, bytes32 policyHash, uint64 revision, bytes32 lastActionId, address policyOrigin, bytes32 policyOriginCodeHash, address successor, bytes32 successorCodeHash))",
  "function entropyPolicyImport() view returns ((uint8 state, uint64 nonce, address predecessor, bytes32 predecessorCodeHash, uint64 pointerRevision, uint256 count, uint64 serial, bytes32 idDigest, bytes32 manifestHash, uint256 nextIndex, bytes32 exportDigest, uint256 requiredRelayCount, uint256 confirmedRelayCount, bytes32 importHash, bytes32 beginActionId, bytes32 sealActionId, bytes32 activationActionId))",
  "function importedEntropyPolicy(uint256 id) view returns (bytes32, bytes32, address, bytes32, bytes32)",
  "function entropyPolicyImportReady(address predecessor, bytes32 codeHash, uint64 pointerRevision, uint256 count, uint64 serial, bytes32 idDigest) view returns (bool)",
  "function beginEntropyPolicyImport(address, bytes32)",
  "function importNextEntropyPolicy(uint256)",
  "function confirmEntropyRelayRoute(uint256)",
  "function sealEntropyPolicyImport()",
  "function activateEntropyPolicyImport()",
  "function entropyPolicyImportTransition(address predecessor, bytes32 manifest) view returns (bytes32, bytes32, bytes32)",
  "function entropyPolicyImportSealTransition() view returns (bytes32, bytes32, bytes32)",
  "function entropyPolicyImportActivationTransition() view returns (bytes32, bytes32, bytes32)",
  "function entropyRelayAdmissionTransition(uint256 id, address successor, bytes32 importHash) view returns (bytes32, bytes32, bytes32)",
  "function admitEntropyRelay(uint256 id, address successor, bytes32 importHash)",
  "function entropyRelayAdmission(uint256 id, address successor) view returns (bytes32, bytes32, bytes32)",
  "function entropyProviderRecord(address provider) view returns ((uint8 state, bytes32 runtimeCodeHash, uint64 revision, bytes32 reasonHash, bytes32 lastActionId))",
  "function uncoveredPendingRequestCount(address successor, bytes32 codeHash) view returns (uint256)",
  "event EntropyPolicyImportBegun(uint16 schemaVersion, bytes32 indexed importHash, address indexed predecessor, uint64 nonce, bytes32 predecessorCodeHash, uint64 pointerRevision, uint256 count, uint64 serial, bytes32 idDigest, bytes32 manifestHash, bytes32 actionId)",
  "event EntropyPolicyImported(uint16 schemaVersion, bytes32 indexed importHash, uint256 indexed collectionId, address indexed policyOrigin, uint256 index, bytes32 policyOriginCodeHash, bytes32 policyHash, bytes32 exportDigest)",
  "event EntropyRecoveryPolicyImported(uint16 schemaVersion, bytes32 indexed importHash, bytes32 indexed policyId, address indexed policyOrigin, bytes32 policyOriginCodeHash, bytes32 policyHash)",
  "event EntropyRelayRouteConfirmed(uint16 schemaVersion, bytes32 indexed importHash, uint256 indexed collectionId, address indexed policyOrigin, bytes32 policyHash)",
  "event EntropyPolicyImportSealed(uint16 schemaVersion, bytes32 indexed importHash, bytes32 exportDigest, uint256 count, uint256 confirmedRelayCount, bytes32 actionId)",
  "event EntropyPolicyImportActivated(uint16 schemaVersion, bytes32 indexed importHash, bytes32 actionId)",
  "event EntropyRelayAdmitted(uint16 schemaVersion, uint256 indexed collectionId, address indexed successor, bytes32 indexed importHash, bytes32 successorCodeHash, bytes32 policyHash, bytes32 actionId)",
  "function getSatellitePointer(bytes32 pointerType) view returns (address target, bytes32 codeHash, bool frozen, bytes32 moduleType, bytes4 interfaceId, address registry, uint8 registryStatus, bytes32 moduleManifestHash, bytes32 deploymentManifestHash, uint64 revision)",
  "function updateSatellitePointer(bytes32 pointerType, address newTarget)",
  "function collectionExists(uint256 collectionId) view returns (bool)",
  "function moduleRecord(address module) view returns ((uint8 status, bytes32 moduleType, bytes32 moduleVersion, bytes4 interfaceId, uint32 moduleGasLimit, bytes32 runtimeCodeHash, bytes32 deploymentManifestHash, bytes32 moduleManifestHash, string moduleManifestURI, uint64 registeredAt, uint64 statusUpdatedAt, uint64 revision))",
  "function isModuleEligible(address module, bytes32 expectedModuleType, bytes4 expectedInterfaceId) view returns (bool)",
  "function governanceExecutor() view returns (address)",
  "function streamSystemManifest() view returns (bytes32 manifestHash, string manifestURI, address revenueResolver, address metadataRouter, address collectionMetadata, address entropyCoordinator, address mintManager, address mintLedger, address artistRegistry, address streamAdminsOrGovernance, address artworkFinalityRegistry, address moduleRegistry, address stateExportPublisher, bytes32 eventCatalogHash, bytes32 compatibilityMatrixHash, bytes32 numericIdCatalogHash, bytes32 schemaCatalogHash, bytes32 canonicalizationCatalogHash, bytes32 specBundleHash, bytes32 reconstructionClientHash, uint64 revision)",
  "function streamSystemManifestPointer() view returns (address payloadPointer)",
  "function publishStreamSystemManifest(address payloadPointer, (bytes32 manifestHash, string manifestURI, bytes32 eventCatalogHash, bytes32 compatibilityMatrixHash, bytes32 numericIdCatalogHash, bytes32 schemaCatalogHash, bytes32 canonicalizationCatalogHash, bytes32 specBundleHash, bytes32 reconstructionClientHash) update)",
  "event StreamSystemManifestPublished(uint16 schemaVersion, bytes32 indexed manifestHash, address indexed payloadPointer, bytes32 indexed actionId)",
  "function governanceNonce() view returns (uint256)",
  "function minimumDelay(uint8 actionClass) pure returns (uint64)",
  "function isProposer(address account) view returns (bool)",
  "function publishedCallData(bytes32 callDataKey) view returns (address)",
  "function publishGovernanceCallData(bytes[] callDatas) returns (address pointer)",
  "function scheduleGovernanceBatch(uint8 actionClass, (address target, uint256 value, bytes4 selector, bytes32 callDataHash, bytes32 scopeHash, bytes32 oldValueHash, bytes32 newValueHash)[] calls, bytes32 scopeHash, bytes32 oldValueHash, bytes32 newValueHash, uint64 notBefore, uint64 expiresAfter, bytes32 reasonHash, string reasonURI, bytes32 manifestHash) returns (bytes32 actionId)",
  "function executeGovernanceBatch(bytes32 actionId, (address target, uint256 value, bytes4 selector, bytes32 callDataHash, bytes32 scopeHash, bytes32 oldValueHash, bytes32 newValueHash)[] calls, bytes[] callDatas) payable",
  "function governanceAction(bytes32 actionId) view returns ((uint8 status, uint8 actionClass, address target, uint256 value, bytes4 selector, bytes32 callHash, bytes32 scopeHash, bytes32 oldValueHash, bytes32 newValueHash, uint64 notBefore, uint64 expiresAfter, address proposer, address executor, address canceller, address vetoer, bytes32 reasonHash, string reasonURI, bytes32 manifestHash))",
  "function scheduledCallData(bytes32 actionId) view returns (bytes[])",
  "function scheduledCallDataPointer(bytes32 actionId) view returns (address)",
  "function governanceActionPolicyState() view returns (bytes32 candidateProfileHash, bytes32 catalogHash, uint256 entryCount, uint64 revision)",
  "function systemManifestBootstrapState() view returns (bool, bool, address, bytes32, address, bytes32, uint64, bytes32, uint256, bytes32, uint64, address, bytes32, address, bytes32, bytes32, uint256, bytes32, uint256, bytes32, bytes32, uint256, bytes32, uint256, address, address, bytes32, bytes32, uint256)",
  "event GovernanceCallDataPublished(uint16 schemaVersion, bytes32 indexed callDataKey, address pointer, address publisher)",
  "event GovernanceActionScheduled(uint16 schemaVersion, bytes32 indexed actionId, uint8 indexed actionClass, address indexed target, uint256 value, bytes4 selector, bytes32 callHash, bytes32 scopeHash, bytes32 oldValueHash, bytes32 newValueHash, uint64 notBefore, uint64 expiresAfter, uint256 nonce, address proposer, bytes32 reasonHash, string reasonURI, bytes32 manifestHash)",
  "event GovernanceActionExecuted(uint16 schemaVersion, bytes32 indexed actionId, uint8 indexed actionClass, address indexed target, uint256 value, bytes4 selector, bytes32 callHash, bytes32 scopeHash, bytes32 oldValueHash, bytes32 newValueHash, address executor, bytes32 manifestHash)",
  "event GovernanceActionPolicyValidated(uint16 schemaVersion, bytes32 indexed actionId, uint8 indexed phase, bytes32 indexed candidateProfileHash, bytes32 catalogHash)",
  "function owner() view returns (address)",
  "function hasRole(bytes32 role, address account) view returns (bool)",
]);

type Reader = Pick<Provider, "getNetwork" | "getCode" | "getBlock" | "call">;
type ReceiptReader = Reader & Pick<Provider, "getTransaction" | "getTransactionReceipt">;
const coder = AbiCoder.defaultAbiCoder();
const ENTROPY = id("ENTROPY_COORDINATOR") as Hex;
const MODULES = id("MODULE_REGISTRY") as Hex;
const MANIFEST = id("SYSTEM_MANIFEST") as Hex;
const MAX_COLLECTIONS = 256;
const moduleKeys = ["revenueResolver", "metadataRouter", "collectionMetadata", "entropyCoordinator", "mintManager", "mintLedger", "artistRegistry", "streamAdminsOrGovernance", "artworkFinalityRegistry", "moduleRegistry", "stateExportPublisher"];
const discoveryKeys = ["eventCatalogHash", "compatibilityMatrixHash", "numericIdCatalogHash", "schemaCatalogHash", "canonicalizationCatalogHash", "specBundleHash", "reconstructionClientHash"];

export interface EntropyPolicySuccessionCodePin { readonly address: Address; readonly codeHash: Hex }
export interface EntropyPolicySuccessionDeployment {
  readonly chainId: bigint;
  readonly core: EntropyPolicySuccessionCodePin;
  readonly moduleRegistry: EntropyPolicySuccessionCodePin;
  readonly executor: EntropyPolicySuccessionCodePin;
  readonly roleRegistry: EntropyPolicySuccessionCodePin;
  readonly predecessor: EntropyPolicySuccessionCodePin;
  readonly candidate: EntropyPolicySuccessionCodePin;
  readonly manifest: EntropyPolicySuccessionCodePin;
}
interface Block { readonly blockNumber: number; readonly blockHash: Hex; readonly timestamp: bigint }
function keys(v: unknown, names: readonly string[]): asserts v is Record<string, any> {
  if (!v || typeof v !== "object" || Array.isArray(v) || Object.keys(v).length !== names.length
    || names.some(k => !Object.hasOwn(v, k))) throw Error("Unexpected input fields");
}
function uint(v: unknown, bits = 256): bigint {
  if (typeof v !== "bigint" || v < 0n || v >= 1n << BigInt(bits)) throw Error("Expected bounded bigint");
  return v;
}
function number(v: unknown): number {
  if (typeof v !== "number" || !Number.isSafeInteger(v) || v < 0) throw Error("Expected concrete block/index");
  return v;
}
function address(v: unknown, allowZero = false): Address {
  if (typeof v !== "string") throw Error("Expected address");
  const result = getAddress(v) as Address;
  if (!allowZero && result === ZeroAddress) throw Error("Zero address");
  return result;
}
function hash(v: unknown, allowZero = false): Hex {
  if (typeof v !== "string" || !isHexString(v, 32) || (!allowZero && v.toLowerCase() === ZeroHash)) throw Error("Expected bytes32");
  return v.toLowerCase() as Hex;
}
function bytes(v: unknown, max = 32768): Hex {
  if (typeof v !== "string" || !isHexString(v, true) || (v.length - 2) / 2 > max) throw Error("Malformed/oversized bytes");
  return v.toLowerCase() as Hex;
}
function freeze<T>(v: T): T {
  if (v && typeof v === "object") { Object.values(v).forEach(freeze); Object.freeze(v); }
  return v;
}
function stable(v: unknown): unknown {
  if (v === null) return ["null"];
  if (typeof v === "bigint") return ["bigint", v.toString()];
  if (["string", "boolean"].includes(typeof v)) return [typeof v, v];
  if (typeof v === "number" && Number.isSafeInteger(v)) return ["number", v];
  if (Array.isArray(v)) return ["array", v.map(stable)];
  if (v && typeof v === "object") return ["object", Object.keys(v).sort().map(k => [k, stable((v as Record<string, unknown>)[k])])];
  throw Error("Unsupported observation value");
}
function equal(a: unknown, b: unknown, message = "Observed facts differ"): void {
  if (JSON.stringify(stable(a)) !== JSON.stringify(stable(b))) throw Error(message);
}
function digest(v: unknown): Hex { return keccak256(toUtf8Bytes(JSON.stringify(stable(v)))) as Hex; }
function same(a: unknown, b: unknown): boolean { return typeof a === "string" && typeof b === "string" && a.toLowerCase() === b.toLowerCase(); }
function plain(p: ParamType, v: any): any {
  if (p.baseType === "tuple") return Object.fromEntries(p.components!.map((x, i) => [x.name, plain(x, v[i])]));
  if (p.baseType === "array") return Array.from(v, x => plain(p.arrayChildren!, x));
  return v;
}
function pin(v: EntropyPolicySuccessionCodePin): EntropyPolicySuccessionCodePin {
  keys(v, ["address", "codeHash"]); return freeze({ address: address(v.address), codeHash: hash(v.codeHash) });
}
function deployment(v: EntropyPolicySuccessionDeployment): EntropyPolicySuccessionDeployment {
  const names = ["core", "moduleRegistry", "executor", "roleRegistry", "predecessor", "candidate", "manifest"] as const;
  keys(v, ["chainId", ...names]);
  const result = { chainId: uint(v.chainId), ...Object.fromEntries(names.map(k => [k, pin(v[k])])) } as unknown as EntropyPolicySuccessionDeployment;
  if (result.chainId === 0n || result.predecessor.address === result.candidate.address) throw Error("Distinct source/candidate and chain required");
  return freeze(result);
}
function configuration(d: EntropyPolicySuccessionDeployment): succession.EntropyPolicySuccessionConfiguration {
  return succession.normalizeEntropyPolicySuccessionConfiguration({ chainId: d.chainId, core: d.core.address,
    moduleRegistry: d.moduleRegistry.address, executor: d.executor.address, roleRegistry: d.roleRegistry.address,
    predecessor: d.predecessor.address, predecessorCodeHash: d.predecessor.codeHash,
    candidate: d.candidate.address, candidateCodeHash: d.candidate.codeHash, manifest: d.manifest.address });
}
async function runtime(p: Reader, v: EntropyPolicySuccessionCodePin, tag: number): Promise<void> {
  const code = bytes(await p.getCode(v.address, tag), 65536);
  if (code === "0x" || (code.length === 48 && code.startsWith("0xef0100")) || !same(keccak256(code), v.codeHash)) throw Error("Pinned runtime differs");
}
async function header(p: Reader, tag: number): Promise<Block> {
  const block = await p.getBlock(tag);
  if (!block || block.number !== tag || !Number.isSafeInteger(block.timestamp) || block.timestamp < 0) throw Error("Missing concrete block");
  return { blockNumber: tag, blockHash: hash(block.hash), timestamp: BigInt(block.timestamp) };
}
async function unchanged(p: Reader, b: Block): Promise<void> {
  equal(await header(p, b.blockNumber), { blockNumber: b.blockNumber, blockHash: b.blockHash, timestamp: b.timestamp }, "Pinned block changed");
}
async function read(p: Reader, to: Address, name: string, args: readonly unknown[], tag: number, max = 32768, from?: Address): Promise<any[]> {
  const raw = bytes(await p.call({ to, value: 0n, data: abi.encodeFunctionData(name, args), blockTag: tag, ...(from ? { from } : {}) }), max);
  const f = abi.getFunction(name)!, value = abi.decodeFunctionResult(f, raw);
  equal(abi.encodeFunctionResult(f, value).toLowerCase(), raw, `Noncanonical ${name} return`);
  return f.outputs.map((t, i) => plain(t, value[i]));
}
async function pointer(p: Reader, d: EntropyPolicySuccessionDeployment, kind: Hex, tag: number): Promise<MintFallbackPointerState> {
  const values = await read(p, d.core.address, "getSatellitePointer", [kind], tag);
  return normalizeMintFallbackPointerState(Object.fromEntries(["target", "codeHash", "frozen", "moduleType", "interfaceId", "registry", "registryStatus", "moduleManifestHash", "deploymentManifestHash", "revision"].map((k, i) => [k, values[i]])) as unknown as MintFallbackPointerState);
}
async function manifestState(p: Reader, d: EntropyPolicySuccessionDeployment, tag: number): Promise<MintFallbackManifestState> {
  const values = await read(p, d.manifest.address, "streamSystemManifest", [], tag);
  return normalizeMintFallbackManifestState({ manifestHash: values[0], manifestURI: values[1],
    modules: Object.fromEntries(moduleKeys.map((k, i) => [k, values[2 + i]])) as unknown as MintFallbackManifestState["modules"],
    discovery: Object.fromEntries(discoveryKeys.map((k, i) => [k, values[13 + i]])) as unknown as MintFallbackManifestState["discovery"],
    revision: values[20], payloadRoot: (await read(p, d.manifest.address, "streamSystemManifestPointer", [], tag))[0] });
}
async function context(p: Reader, d: EntropyPolicySuccessionDeployment, tag: number): Promise<Block> {
  const h = await header(p, tag);
  equal((await p.getNetwork()).chainId, d.chainId, "Deployment chain differs");
  for (const v of [d.core, d.moduleRegistry, d.executor, d.roleRegistry, d.predecessor, d.candidate, d.manifest]) await runtime(p, v, tag);
  for (const host of [d.predecessor, d.candidate]) {
    equal((await read(p, host.address, "core", [], tag))[0], d.core.address);
    equal((await read(p, host.address, "authority", [], tag))[0], d.executor.address);
    equal((await read(p, host.address, "roleRegistry", [], tag))[0], d.roleRegistry.address);
    equal((await read(p, host.address, "streamModuleType", [], tag))[0], ENTROPY);
  }
  equal((await read(p, d.moduleRegistry.address, "governanceExecutor", [], tag))[0], d.executor.address);
  equal((await read(p, d.manifest.address, "core", [], tag))[0], d.core.address);
  equal((await read(p, d.manifest.address, "governanceExecutor", [], tag))[0], d.executor.address);
  equal((await read(p, d.roleRegistry.address, "owner", [], tag))[0], d.executor.address);
  for (const [kind, expected] of [[MODULES, d.moduleRegistry], [MANIFEST, d.manifest]] as const) {
    const value = await pointer(p, d, kind, tag);
    equal([value.target, value.codeHash], [expected.address, expected.codeHash]);
    if (value.registryStatus !== 1n || value.revision === 0n) throw Error("Canonical dependency pointer is not ACTIVE");
  }
  return h;
}

export interface EntropyPolicySuccessionInventory {
  readonly header: succession.EntropyPolicySuccessionInventoryHeader;
  readonly policies: readonly succession.EntropyPolicySuccessionPolicyExport[];
  readonly recoveries: readonly succession.EntropyPolicySuccessionRecoveryExport[];
}
export interface EntropyPolicySuccessionImportedObservation {
  readonly collectionId: bigint;
  readonly receipt: succession.EntropyPolicySuccessionImportedPolicy;
}
export interface EntropyPolicySuccessionCapture extends Block {
  readonly deployment: EntropyPolicySuccessionDeployment;
  readonly configuration: succession.EntropyPolicySuccessionConfiguration;
  readonly pointer: MintFallbackPointerState;
  readonly predecessor: EntropyPolicySuccessionInventory;
  readonly candidate: EntropyPolicySuccessionInventory;
  readonly receipt: succession.EntropyPolicySuccessionImportReceipt;
  readonly imported: readonly EntropyPolicySuccessionImportedObservation[];
  readonly ready: boolean;
  readonly registration: succession.EntropyPolicySuccessionRegistration;
  readonly registrationStatus: bigint;
  readonly manifestState: MintFallbackManifestState;
  readonly catalog: { readonly candidateProfileHash: Hex; readonly catalogHash: Hex; readonly entryCount: bigint; readonly revision: bigint };
  readonly governanceNonce: bigint;
  readonly captureHash: Hex;
}
function dense<T>(v: readonly T[], max: number): readonly T[] {
  if (!Array.isArray(v) || v.length > max || Object.keys(v).length !== v.length
    || Array.from({ length: v.length }, (_, i) => i).some(i => !Object.hasOwn(v, i))) throw Error("Expected bounded dense array");
  return v;
}
function clone<T>(v: T): T {
  stable(v);
  if (Array.isArray(v)) return dense(v, 65536).map(clone) as T;
  if (v && typeof v === "object") return Object.fromEntries(Object.entries(v).map(([k, x]) => [k, clone(x)])) as T;
  return v;
}
function captured(input: EntropyPolicySuccessionCapture): EntropyPolicySuccessionCapture {
  keys(input, ["deployment", "configuration", "pointer", "predecessor", "candidate", "receipt", "imported", "ready", "registration", "registrationStatus", "manifestState", "catalog", "governanceNonce", "blockNumber", "blockHash", "timestamp", "captureHash"]);
  const copy = clone(input), { captureHash, ...body } = copy;
  equal(hash(captureHash), digest(body), "Capture hash differs");
  equal(configuration(deployment(copy.deployment)), copy.configuration);
  number(copy.blockNumber); hash(copy.blockHash); uint(copy.timestamp, 64);
  dense(copy.predecessor.policies, MAX_COLLECTIONS); dense(copy.candidate.policies, MAX_COLLECTIONS);
  dense(copy.predecessor.recoveries, MAX_COLLECTIONS); dense(copy.candidate.recoveries, MAX_COLLECTIONS);
  dense(copy.imported, MAX_COLLECTIONS);
  return freeze(copy);
}
async function inventory(p: Reader, d: EntropyPolicySuccessionDeployment, host: Address, tag: number): Promise<EntropyPolicySuccessionInventory> {
  const h = await read(p, host, "entropyPolicyInventory", [], tag, 96);
  const observed = succession.normalizeEntropyPolicySuccessionInventoryHeader({ count: h[0], serial: h[1], idDigest: h[2] });
  if (observed.count > BigInt(MAX_COLLECTIONS)) throw Error("Inventory exceeds 256 collection client bound");
  const policies: succession.EntropyPolicySuccessionPolicyExport[] = [];
  const recoveries: succession.EntropyPolicySuccessionRecoveryExport[] = [];
  for (let i = 0; i < Number(observed.count); i++) {
    const cid = uint((await read(p, host, "entropyPolicyCollectionAt", [BigInt(i)], tag, 32))[0]);
    const policy = succession.validateEntropyPolicySuccessionPolicy(d.chainId, d.core.address,
      (await read(p, host, "exportEntropyPolicy", [cid], tag, 1184))[0]);
    equal(policy.collectionId, cid);
    policies.push(policy);
    if (policy.recovery.maxFreshRecoveryAttempts !== 0n) {
      let r = recoveries.find(v => same(v.policyId, policy.recovery.policyId));
      if (!r) {
        r = succession.validateEntropyPolicySuccessionRecovery(d.chainId, d.core.address,
          (await read(p, host, "exportEntropyRecovery", [policy.recovery.policyId], tag, 5696))[0]);
        equal(r.policyId, policy.recovery.policyId);
        recoveries.push(r);
      }
      succession.verifyEntropyPolicySuccessionRecoveryBinding(policy, r);
    }
  }
  equal(succession.entropyPolicySuccessionInventory(policies.map(v => v.collectionId), observed.serial), observed, "Complete insertion-order inventory differs");
  return freeze({ header: observed, policies, recoveries });
}
function recoveryFor(v: EntropyPolicySuccessionInventory, policy: succession.EntropyPolicySuccessionPolicyExport): succession.EntropyPolicySuccessionRecoveryExport | null {
  if (policy.recovery.maxFreshRecoveryAttempts === 0n) return null;
  const result = v.recoveries.find(r => same(r.policyId, policy.recovery.policyId));
  if (!result) throw Error("Missing complete recovery definition");
  return result;
}
function importState(c: Omit<EntropyPolicySuccessionCapture, "captureHash">): void {
  const r = c.receipt;
  if (r.state === 0n) {
    const empty = succession.decodeEntropyPolicySuccessionImportReceipt(`0x${"00".repeat(544)}` as Hex);
    equal(r, empty, "NONE receipt contains retained fields");
    if (c.ready || c.imported.length !== 0) throw Error("NONE import cannot be ready/imported");
    return;
  }
  if (r.nonce !== 1n || r.nextIndex > r.count || r.count > BigInt(MAX_COLLECTIONS)
    || r.confirmedRelayCount > r.requiredRelayCount || r.requiredRelayCount > r.nextIndex
    || r.beginActionId === ZeroHash || r.manifestHash === ZeroHash || r.pointerRevision === 0n) throw Error("Invalid import progress");
  equal([r.predecessor, r.predecessorCodeHash], [c.configuration.predecessor, c.configuration.predecessorCodeHash]);
  equal(r.importHash, succession.entropyPolicySuccessionImportHash(c.configuration, r), "Import generation hash differs");
  const originalIds = c.predecessor.policies.slice(0, Number(r.count)).map(v => v.collectionId);
  equal(succession.entropyPolicySuccessionInventory(originalIds, r.serial), { count: r.count, serial: r.serial, idDigest: r.idDigest }, "Original source inventory prefix differs");
  if (r.state >= 2n && (r.nextIndex !== r.count || r.requiredRelayCount !== r.confirmedRelayCount || r.sealActionId === ZeroHash)) throw Error("Sealed import is incomplete");
  if ((r.state === 1n && r.sealActionId !== ZeroHash) || (r.state === 3n ? r.activationActionId === ZeroHash : r.activationActionId !== ZeroHash)) throw Error("Import action receipts contradict state");
  equal(c.ready, succession.entropyPolicySuccessionImportReady(r, c.configuration.predecessor,
    c.configuration.predecessorCodeHash, c.pointer.revision, c.predecessor.header), "Readiness differs from current source/header arguments");
  equal(c.imported.length, Number(r.nextIndex));
  for (let i = 0; i < c.imported.length; i++) {
    const v = c.imported[i]!;
    equal(v.collectionId, originalIds[i]);
    equal(v.receipt.importHash, r.importHash);
    hash(v.receipt.exportHash); address(v.receipt.policyOrigin); hash(v.receipt.policyOriginCodeHash);
  }
  // After activation, authorship can update either inventory and local exports.
  // Immutable import receipts are deliberately not equated with those new exports.
  if (r.state === 3n) return;
  if (c.candidate.header.count !== r.nextIndex || c.candidate.header.serial !== r.nextIndex) throw Error("Staged candidate inventory differs");
  const sourceFresh = same(c.predecessor.header.idDigest, r.idDigest)
    && c.predecessor.header.count === r.count && c.predecessor.header.serial === r.serial;
  if (!sourceFresh) return; // retained state is readable; preparing another step fails closed below.
  let exportDigest = succession.entropyPolicySuccessionInitialExportDigest(r.importHash), required = 0n;
  for (let i = 0; i < Number(r.nextIndex); i++) {
    const policy = c.predecessor.policies[i]!, recovery = recoveryFor(c.predecessor, policy);
    const exportHash = succession.entropyPolicySuccessionExportHash(policy);
    equal(c.candidate.policies[i], policy, "Staged copied policy differs");
    equal(c.imported[i]!.receipt, { importHash: r.importHash, exportHash, policyOrigin: policy.policyOrigin, policyOriginCodeHash: policy.policyOriginCodeHash, policyHash: policy.record.policyHash });
    if (recovery) equal(recoveryFor(c.candidate, policy), recovery, "Copied recovery differs");
    if (succession.entropyPolicySuccessionRouteRequired(policy)) required++;
    exportDigest = succession.entropyPolicySuccessionAppendExportDigest(exportDigest, BigInt(i), policy.collectionId, exportHash, recovery ? succession.entropyPolicySuccessionRecoveryExportHash(recovery) : ZeroHash as Hex);
  }
  equal([r.exportDigest, r.requiredRelayCount], [exportDigest, required], "Copied prefix digest/count differs");
}
/** Complete bounded local inventories; ACTIVE is historical evidence, not current readiness. */
export async function captureEntropyPolicySuccession(p: Reader, input: EntropyPolicySuccessionDeployment, options: { readonly blockTag: number }): Promise<EntropyPolicySuccessionCapture> {
  const d = deployment(input); keys(options, ["blockTag"]); const tag = number(options.blockTag);
  const block = await context(p, d, tag);
  const predecessor = await inventory(p, d, d.predecessor.address, tag);
  const candidate = await inventory(p, d, d.candidate.address, tag);
  const receipt = succession.normalizeEntropyPolicySuccessionImportReceipt((await read(p, d.candidate.address, "entropyPolicyImport", [], tag, 544))[0]);
  if (receipt.nextIndex > BigInt(MAX_COLLECTIONS) || receipt.nextIndex > predecessor.header.count) throw Error("Imported prefix exceeds source inventory");
  const imported: EntropyPolicySuccessionImportedObservation[] = [];
  for (let i = 0; i < Number(receipt.nextIndex); i++) {
    const collectionId = predecessor.policies[i]!.collectionId;
    const v = await read(p, d.candidate.address, "importedEntropyPolicy", [collectionId], tag, 160);
    imported.push({ collectionId, receipt: succession.normalizeEntropyPolicySuccessionImportedPolicy({ importHash: v[0], exportHash: v[1], policyOrigin: v[2], policyOriginCodeHash: v[3], policyHash: v[4] }) });
  }
  const currentPointer = await pointer(p, d, ENTROPY, tag);
  const ready = (await read(p, d.candidate.address, "entropyPolicyImportReady", [d.predecessor.address, d.predecessor.codeHash,
    currentPointer.revision, predecessor.header.count, predecessor.header.serial, predecessor.header.idDigest], tag, 32))[0] as boolean;
  const record = (await read(p, d.moduleRegistry.address, "moduleRecord", [d.candidate.address], tag))[0];
  const registration = succession.normalizeEntropyPolicySuccessionRegistration({ module: d.candidate.address,
    moduleType: record.moduleType, moduleVersion: record.moduleVersion, interfaceId: record.interfaceId,
    moduleGasLimit: record.moduleGasLimit, expectedRuntimeCodeHash: record.runtimeCodeHash,
    deploymentManifestHash: record.deploymentManifestHash, moduleManifestHash: record.moduleManifestHash, moduleManifestURI: record.moduleManifestURI });
  const cat = await read(p, d.executor.address, "governanceActionPolicyState", [], tag, 128);
  const body = { deployment: d, configuration: configuration(d), ...block,
    pointer: currentPointer, predecessor, candidate, receipt, imported, ready, registration,
    registrationStatus: uint(record.status, 8), manifestState: await manifestState(p, d, tag),
    catalog: { candidateProfileHash: hash(cat[0]), catalogHash: hash(cat[1]), entryCount: uint(cat[2]), revision: uint(cat[3], 64) },
    governanceNonce: uint((await read(p, d.executor.address, "governanceNonce", [], tag, 32))[0]) };
  importState(body); await unchanged(p, block);
  return freeze({ ...body, captureHash: digest(body) });
}

export type EntropyPolicySuccessionWorkflowRequest =
  | { readonly kind: "begin"; readonly manifestHash: Hex }
  | { readonly kind: "copy"; readonly expectedIndex: bigint }
  | { readonly kind: "confirm-route"; readonly collectionId: bigint }
  | { readonly kind: "admit-route"; readonly collectionId: bigint }
  | { readonly kind: "seal" }
  | { readonly kind: "cutover"; readonly payload: Address; readonly update: MintFallbackManifestUpdate }
  | { readonly kind: "catalog"; readonly inventory: succession.EntropyPolicySuccessionCatalogInventory;
      readonly baseHistory: succession.EntropyPolicySuccessionCatalogHistory; readonly deploymentHash: Hex;
      readonly completedRows: bigint; readonly payload: Address; readonly update: MintFallbackManifestUpdate };
export interface EntropyPolicySuccessionInspection {
  readonly capture: EntropyPolicySuccessionCapture;
  readonly request: EntropyPolicySuccessionWorkflowRequest;
  readonly plan: succession.EntropyPolicySuccessionPlan;
  readonly admissionRequiresOriginalSimulation: true;
  readonly nestedGasEquivalence: false;
  readonly inspectionHash: Hex;
}
function freshSource(c: EntropyPolicySuccessionCapture): void {
  const r = c.receipt;
  if (r.state === 0n || r.state === 3n) throw Error("No staged import generation");
  equal(c.predecessor.header, { count: r.count, serial: r.serial, idDigest: r.idDigest }, "Predecessor inventory changed");
  equal([c.pointer.target, c.pointer.codeHash, c.pointer.revision, c.pointer.registryStatus],
    [r.predecessor, r.predecessorCodeHash, r.pointerRevision, 1n], "Selected predecessor changed");
}
function selectedPolicy(c: EntropyPolicySuccessionCapture, cid: bigint): succession.EntropyPolicySuccessionPolicyExport {
  const result = c.predecessor.policies.find(v => v.collectionId === cid);
  if (!result || !c.imported.some(v => v.collectionId === cid)) throw Error("Collection has not been copied");
  return result;
}
async function admission(p: Reader, origin: Address, successor: Address, cid: bigint, tag: number): Promise<succession.EntropyPolicySuccessionAdmission> {
  const v = await read(p, origin, "entropyRelayAdmission", [cid, successor], tag, 96);
  return succession.normalizeEntropyPolicySuccessionAdmission({ successorCodeHash: v[0], importHash: v[1], policyHash: v[2] });
}
async function coordinator(p: Reader, d: EntropyPolicySuccessionDeployment, origin: succession.EntropyPolicySuccessionRuntime, tag: number): Promise<void> {
  await runtime(p, { address: origin.target, codeHash: origin.codeHash }, tag);
  equal((await read(p, origin.target, "core", [], tag))[0], d.core.address);
  equal((await read(p, origin.target, "authority", [], tag))[0], d.executor.address);
  equal((await read(p, origin.target, "roleRegistry", [], tag))[0], d.roleRegistry.address);
}
async function provider(p: Reader, host: Address, target: Address, expectedCode: Hex | null, config: Hex, origin: Address, tag: number): Promise<void> {
  const record = (await read(p, host, "entropyProviderRecord", [target], tag, 160))[0];
  if (record.state !== 1n || record.revision === 0n) throw Error("Provider is not ACTIVE");
  if (expectedCode !== null) equal(record.runtimeCodeHash, expectedCode, "Provider lifecycle pin differs");
  await runtime(p, { address: target, codeHash: hash(record.runtimeCodeHash) }, tag);
  equal((await read(p, target, "coordinator", [], tag))[0], origin, "Provider belongs to another origin");
  equal((await read(p, target, "streamEntropyProviderConfigHash", [], tag))[0], config, "Provider configuration differs");
}
async function providers(p: Reader, c: EntropyPolicySuccessionCapture, policy: succession.EntropyPolicySuccessionPolicyExport, copy: boolean): Promise<void> {
  const tag = c.blockNumber, d = c.deployment;
  const origin = { target: policy.policyOrigin, codeHash: policy.policyOriginCodeHash };
  await runtime(p, { address: origin.target, codeHash: origin.codeHash }, tag);
  const host = copy ? d.candidate.address : origin.target;
  if (policy.policy.provider !== ZeroAddress) await provider(p, host, policy.policy.provider, policy.providerCodeHash, policy.providerConfigHash, origin.target, tag);
  const recovery = recoveryFor(c.predecessor, policy);
  if (recovery) {
    await runtime(p, { address: recovery.policyOrigin, codeHash: recovery.policyOriginCodeHash }, tag);
    if (recovery.successor !== ZeroAddress) await runtime(p, { address: recovery.successor, codeHash: recovery.successorCodeHash }, tag);
    const steps = copy ? recovery.policy.steps : recovery.policy.steps.slice(0, Number(policy.recovery.maxFreshRecoveryAttempts));
    for (const step of steps) await provider(p, host, step.provider, null, step.providerConfigHash, policy.policyOrigin, tag);
  }
}
async function eligible(p: Reader, c: EntropyPolicySuccessionCapture): Promise<void> {
  for (const host of [c.configuration.predecessor, c.configuration.candidate]) {
    if ((await read(p, c.configuration.moduleRegistry, "isModuleEligible", [host, ENTROPY, succession.ENTROPY_POLICY_SUCCESSION_COORDINATOR_INTERFACE_ID], c.blockNumber, 32))[0] !== true) throw Error("Coordinator is not eligible");
  }
}
async function manifestPayload(p: Reader, root: Address, expectedHash: Hex, tag: number): Promise<void> {
  const code = bytes(await p.getCode(root, tag), 3329);
  if (!code.startsWith("0x00")) throw Error("Manifest descriptor is not canonical SSTORE2");
  const raw = `0x${code.slice(4)}` as Hex;
  const types = ["bytes4", "uint16", "bytes32", "bytes32", "uint32", "uint16", "tuple(address pointer,uint32 payloadLength,bytes32 payloadHash)[]"];
  const r = coder.decode(types, raw);
  equal(coder.encode(types, r).toLowerCase(), raw, "Noncanonical manifest descriptor");
  const PAYLOAD = "0x8844b744a67cdcdb84ea3c6e3d686883da175820b9ff07a19cffa14bf62e6e81", JCS = "0x886c7c89c308c459ca8a626e0ef36a5ea9f4c7a7b56aaf86c71a2ddf3b4f9044";
  const ROOT = "0xd6ab89b077c61a288c7168cf8f1c9a7a19464b10475735dae37cb46a0c94c40b", LEAF = "0x852f4811a2eb32694863d94ba41b545a65ef4c76086a32c35881f0c4e250a7b5", LIST = "0xa93750a5551ac5668c8f24cca85acaf1d5f8334fac9406f845fce1ce35548839";
  const total = uint(r[4], 32), count = uint(r[5], 16), chunks = r[6];
  if (r[0] !== "0x6c9d2530" || r[1] !== 1n || !same(r[2], PAYLOAD) || !same(r[3], JCS)
    || total === 0n || total > 786400n || count === 0n || count > 32n || BigInt(chunks.length) !== count
    || BigInt((raw.length - 2) / 2) !== 256n + 96n * count || count !== (total + 24574n) / 24575n) throw Error("Manifest descriptor profile differs");
  let observed = 0n; const leaves: Hex[] = [];
  for (let i = 0; i < chunks.length; i++) {
    const x = chunks[i], length = uint(x[1], 32);
    if (length === 0n || length > 24575n || (i + 1 < chunks.length && length !== 24575n)) throw Error("Manifest chunk length differs");
    const chunk = bytes(await p.getCode(address(x[0]), tag), 24576);
    if (!chunk.startsWith("0x00") || BigInt((chunk.length - 4) / 2) !== length || !same(keccak256(`0x${chunk.slice(4)}`), hash(x[2]))) throw Error("Manifest chunk bytes differ");
    observed += length;
    leaves.push(keccak256(coder.encode(["bytes32", "uint256", "uint32", "bytes32"], [LEAF, i, length, x[2]])) as Hex);
  }
  const list = keccak256(coder.encode(["bytes32", "uint32", "bytes32[]"], [LIST, total, leaves]));
  const actual = keccak256(coder.encode(["bytes32", "uint16", "bytes32", "bytes32", "uint32", "uint16", "bytes32"], [ROOT, 1n, PAYLOAD, JCS, total, count, list]));
  if (observed !== total || !same(actual, expectedHash)) throw Error("Manifest payload commitment differs");
}
async function exactTransition(p: Reader, plan: succession.EntropyPolicySuccessionPlan, name: string, args: readonly unknown[], callIndex: number, tag: number): Promise<void> {
  const call = plan.calls[callIndex]!;
  equal(await read(p, call.target, name, args, tag, 96), [call.scopeHash, call.oldValueHash, call.newValueHash], "Original transition differs");
}
/** Prepares source-backed calls. Private freshness, replay and nested gas admission remain exact-call checks. */
export async function prepareEntropyPolicySuccession(p: Reader, input: EntropyPolicySuccessionCapture, requestInput: EntropyPolicySuccessionWorkflowRequest): Promise<EntropyPolicySuccessionInspection> {
  const c = captured(input), request = freeze(clone(requestInput)), tag = c.blockNumber;
  equal(await captureEntropyPolicySuccession(p, c.deployment, { blockTag: tag }), c, "Captured state changed");
  const common = { receipt: c.receipt, predecessorInventory: c.predecessor.header, candidateInventory: c.candidate.header };
  let plan: succession.EntropyPolicySuccessionPlan;
  switch (request.kind) {
    case "begin": {
      keys(request, ["kind", "manifestHash"]); await eligible(p, c);
      plan = succession.prepareEntropyPolicySuccessionPlan(c.configuration, { kind: request.kind, ...common, pointer: c.pointer, manifestHash: hash(request.manifestHash) });
      await exactTransition(p, plan, "entropyPolicyImportTransition", [c.configuration.predecessor, request.manifestHash], 0, tag);
      break;
    }
    case "copy": {
      keys(request, ["kind", "expectedIndex"]); freshSource(c); await eligible(p, c);
      if (c.receipt.state !== 1n || uint(request.expectedIndex) !== c.receipt.nextIndex || request.expectedIndex >= c.receipt.count) throw Error("Copy is not the next staged collection");
      await providers(p, c, c.predecessor.policies[Number(request.expectedIndex)]!, true);
      plan = succession.prepareEntropyPolicySuccessionPlan(c.configuration, request);
      break;
    }
    case "confirm-route": {
      keys(request, ["kind", "collectionId"]); freshSource(c); await eligible(p, c);
      if (c.receipt.state !== 1n) throw Error("Route confirmation requires STAGING");
      const policy = selectedPolicy(c, uint(request.collectionId));
      if (!succession.entropyPolicySuccessionRouteRequired(policy)) throw Error("Policy needs no relay route");
      await runtime(p, { address: policy.policyOrigin, codeHash: policy.policyOriginCodeHash }, tag);
      equal(await admission(p, policy.policyOrigin, c.configuration.candidate, policy.collectionId, tag),
        { successorCodeHash: c.configuration.candidateCodeHash, importHash: c.receipt.importHash, policyHash: policy.record.policyHash }, "Original origin admission differs");
      plan = succession.prepareEntropyPolicySuccessionPlan(c.configuration, request);
      break;
    }
    case "seal": {
      keys(request, ["kind"]); freshSource(c); await eligible(p, c);
      plan = succession.prepareEntropyPolicySuccessionPlan(c.configuration, { kind: request.kind, ...common });
      await exactTransition(p, plan, "entropyPolicyImportSealTransition", [], 0, tag);
      break;
    }
    case "admit-route": {
      keys(request, ["kind", "collectionId"]); freshSource(c); await eligible(p, c);
      const policy = selectedPolicy(c, uint(request.collectionId));
      const origin = { target: policy.policyOrigin, codeHash: policy.policyOriginCodeHash };
      await coordinator(p, c.deployment, origin, tag); await providers(p, c, policy, false);
      const currentAdmission = await admission(p, origin.target, c.configuration.candidate, policy.collectionId, tag);
      const predecessorAdmission = same(origin.target, c.configuration.predecessor) ? null : await admission(p, origin.target, c.configuration.predecessor, policy.collectionId, tag);
      plan = succession.prepareEntropyPolicySuccessionPlan(c.configuration, { kind: request.kind, origin, receipt: c.receipt, policy,
        recovery: recoveryFor(c.predecessor, policy), importedPolicy: c.imported.find(v => v.collectionId === policy.collectionId)!.receipt, currentAdmission, predecessorAdmission });
      await exactTransition(p, plan, "entropyRelayAdmissionTransition", [policy.collectionId, c.configuration.candidate, c.receipt.importHash], 0, tag);
      break;
    }
    case "cutover": {
      keys(request, ["kind", "payload", "update"]); freshSource(c); await eligible(p, c);
      if (!c.ready) throw Error("Candidate is not SEALED and ready");
      const r = c.registration;
      equal([r.expectedRuntimeCodeHash, r.moduleType, r.interfaceId], [c.configuration.candidateCodeHash, ENTROPY, succession.ENTROPY_POLICY_SUCCESSION_COORDINATOR_INTERFACE_ID]);
      equal((await read(p, c.configuration.candidate, "streamModuleVersion", [], tag, 32))[0], r.moduleVersion);
      equal((await read(p, c.configuration.candidate, "streamModuleInterfaceId", [], tag, 32))[0], r.interfaceId);
      equal(await read(p, c.configuration.candidate, "streamModuleManifest", [], tag), [r.moduleManifestURI, r.moduleManifestHash]);
      equal((await read(p, c.configuration.candidate, "streamModuleDeploymentManifestHash", [], tag, 32))[0], r.deploymentManifestHash);
      equal((await read(p, c.configuration.predecessor, "uncoveredPendingRequestCount", [c.configuration.candidate, c.configuration.candidateCodeHash], tag, 32))[0], 0n, "Pending requests are not covered");
      plan = succession.prepareEntropyPolicySuccessionPlan(c.configuration, { kind: request.kind, ...common, pointer: c.pointer, registration: r, registrationStatus: c.registrationStatus, manifestState: c.manifestState, payload: address(request.payload), update: request.update });
      await manifestPayload(p, address(request.payload), hash(request.update.manifestHash), tag);
      await exactTransition(p, plan, "entropyPolicyImportActivationTransition", [], 1, tag);
      break;
    }
    case "catalog": {
      keys(request, ["kind", "inventory", "baseHistory", "deploymentHash", "completedRows", "payload", "update"]);
      await ordinary(p, c);
      const originMap = new Map<string, succession.EntropyPolicySuccessionRuntime>();
      for (const policy of c.predecessor.policies.filter(succession.entropyPolicySuccessionRouteRequired)) {
        const key = policy.policyOrigin.toLowerCase(), prior = originMap.get(key);
        if (prior && !same(prior.codeHash, policy.policyOriginCodeHash)) throw Error("Conflicting origin runtime pins");
        originMap.set(key, { target: policy.policyOrigin, codeHash: policy.policyOriginCodeHash });
      }
      const origins = [...originMap.values()];
      for (const origin of origins) await coordinator(p, c.deployment, origin, tag);
      equal(request.inventory.executorCodeHash, c.deployment.executor.codeHash, "Saved catalog Executor runtime differs");
      plan = succession.prepareEntropyPolicySuccessionPlan(c.configuration, { kind: request.kind,
        inventory: request.inventory, baseHistory: request.baseHistory, origins, deploymentHash: request.deploymentHash,
        completedRows: request.completedRows, catalogState: c.catalog, manifestState: c.manifestState,
        payload: request.payload, update: request.update });
      await manifestPayload(p, address(request.payload), hash(request.update.manifestHash), tag);
      break;
    }
    default: throw Error("Unsupported succession step");
  }
  await unchanged(p, c);
  const body = { capture: c, request, plan, admissionRequiresOriginalSimulation: true as const, nestedGasEquivalence: false as const };
  return freeze({ ...body, inspectionHash: digest(body) });
}
function inspected(input: EntropyPolicySuccessionInspection): EntropyPolicySuccessionInspection {
  keys(input, ["capture", "request", "plan", "admissionRequiresOriginalSimulation", "nestedGasEquivalence", "inspectionHash"]);
  const v = clone(input), { inspectionHash, ...body } = v;
  equal(hash(inspectionHash), digest(body), "Inspection hash differs");
  captured(v.capture); succession.normalizeEntropyPolicySuccessionPlan(v.plan);
  equal(v.plan.configuration, v.capture.configuration);
  equal([v.admissionRequiresOriginalSimulation, v.nestedGasEquivalence], [true, false]);
  return freeze(v);
}

export interface PreparedEntropyPolicySuccessionGovernance {
  readonly inspection: EntropyPolicySuccessionInspection;
  readonly proposer: Address;
  readonly batch: succession.EntropyPolicySuccessionGovernanceBatch;
}
export type EntropyPolicySuccessionOperation =
  | { readonly kind: "permissionless"; readonly inspection: EntropyPolicySuccessionInspection; readonly caller: Address; readonly call: UnsignedCall }
  | { readonly kind: "governance"; readonly prepared: PreparedEntropyPolicySuccessionGovernance; readonly stage: "publish" | "schedule" | "execute"; readonly caller: Address; readonly call: UnsignedCall };
export function prepareEntropyPolicySuccessionGovernance(input: EntropyPolicySuccessionInspection, proposer: Address,
  window: succession.EntropyPolicySuccessionGovernanceWindow): PreparedEntropyPolicySuccessionGovernance {
  const inspection = inspected(input);
  if (inspection.plan.actionClass === null) throw Error("Permissionless steps do not use governance");
  return freeze({ inspection, proposer: address(proposer), batch: succession.entropyPolicySuccessionGovernanceBatch(inspection.plan, inspection.capture.governanceNonce, window) });
}
function prepared(input: PreparedEntropyPolicySuccessionGovernance): PreparedEntropyPolicySuccessionGovernance {
  keys(input, ["inspection", "proposer", "batch"]);
  const v = clone(input);
  const expected = prepareEntropyPolicySuccessionGovernance(v.inspection, v.proposer, v.batch.window);
  equal(expected, v, "Governance preparation differs"); return expected;
}
export function entropyPolicySuccessionCall(input: EntropyPolicySuccessionInspection, caller: Address): EntropyPolicySuccessionOperation {
  const inspection = inspected(input);
  if (inspection.plan.actionClass !== null || inspection.plan.targetCalls.length !== 1) throw Error("Expected one permissionless step");
  return freeze({ kind: "permissionless", inspection, caller: address(caller), call: inspection.plan.targetCalls[0]! });
}
export function entropyPolicySuccessionGovernanceCall(input: PreparedEntropyPolicySuccessionGovernance,
  stage: "publish" | "schedule" | "execute", caller: Address): EntropyPolicySuccessionOperation {
  const v = prepared(input), actor = address(caller);
  if (!["publish", "schedule", "execute"].includes(stage)) throw Error("Unknown governance stage");
  if (stage === "schedule" && actor !== v.proposer) throw Error("Schedule caller differs from proposer");
  const call = stage === "publish" ? v.batch.publicationCall : stage === "schedule" ? v.batch.scheduleCall : v.batch.executionCall;
  return freeze({ kind: "governance", prepared: v, stage, caller: actor, call });
}
function operation(input: EntropyPolicySuccessionOperation): EntropyPolicySuccessionOperation {
  const v = clone(input);
  let expected: EntropyPolicySuccessionOperation;
  if (v.kind === "permissionless") {
    keys(v, ["kind", "inspection", "caller", "call"]);
    expected = entropyPolicySuccessionCall(v.inspection, v.caller);
  } else {
    keys(v, ["kind", "prepared", "stage", "caller", "call"]);
    expected = entropyPolicySuccessionGovernanceCall(v.prepared, v.stage, v.caller);
  }
  equal(v, expected, "Operation call differs"); return expected;
}
function inspectionOf(o: EntropyPolicySuccessionOperation): EntropyPolicySuccessionInspection { return o.kind === "permissionless" ? o.inspection : o.prepared.inspection; }
async function historical(p: Reader, i: EntropyPolicySuccessionInspection): Promise<void> {
  equal(await prepareEntropyPolicySuccession(p, i.capture, i.request), i, "Historical inspection differs");
}
async function ordinary(p: Reader, c: EntropyPolicySuccessionCapture): Promise<void> {
  const b = await read(p, c.configuration.executor, "systemManifestBootstrapState", [], c.blockNumber);
  if (b[0] !== true || b[1] !== true) throw Error("Only initialized sealed ordinary governance is supported");
  equal(b[13], c.configuration.manifest, "Bootstrap SystemManifest differs");
}
async function published(p: Reader, d: EntropyPolicySuccessionDeployment, b: succession.EntropyPolicySuccessionGovernanceBatch, tag: number): Promise<Address> {
  const pointer = address((await read(p, d.executor.address, "publishedCallData", [b.publicationKey], tag, 32))[0], true);
  if (pointer === ZeroAddress) return pointer;
  const code = bytes(await p.getCode(pointer, tag), 24576);
  const expected = coder.encode(["bytes[]"], [b.plan.callDatas]).toLowerCase();
  equal(code, `0x00${expected.slice(2)}`, "Published immutable calldata differs");
  return pointer;
}
async function action(p: Reader, v: PreparedEntropyPolicySuccessionGovernance, tag: number): Promise<Record<string, any>> {
  const b = v.batch, c = b.plan.calls[0]!;
  const a = (await read(p, b.plan.configuration.executor, "governanceAction", [b.actionId], tag))[0];
  const expected = { actionClass: b.plan.actionClass, target: c.target, value: 0n, selector: c.selector,
    callHash: b.callsHash, scopeHash: b.scopeHash, oldValueHash: b.oldValueHash, newValueHash: b.newValueHash,
    notBefore: b.window.notBefore, expiresAfter: b.window.expiresAfter, proposer: v.proposer,
    reasonHash: b.window.reasonHash, reasonURI: b.window.reasonURI, manifestHash: b.window.manifestHash };
  for (const [k, value] of Object.entries(expected)) equal(a[k], value, `Scheduled ${k} differs`);
  equal((await read(p, b.plan.configuration.executor, "scheduledCallData", [b.actionId], tag))[0], b.plan.callDatas);
  const pointer = await published(p, v.inspection.capture.deployment, b, tag);
  if (pointer === ZeroAddress) throw Error("Missing published calls");
  equal((await read(p, b.plan.configuration.executor, "scheduledCallDataPointer", [b.actionId], tag, 32))[0], pointer);
  return a;
}
export interface EntropyPolicySuccessionSimulation {
  readonly operation: EntropyPolicySuccessionOperation;
  readonly observed: Block;
  readonly returnData: Hex;
  readonly actualCallSucceeded: true;
  readonly futureExecutionGuaranteed: false;
}
/** The full cutover executes inside the original Executor; activation is never simulated out of order. */
export async function simulateEntropyPolicySuccession(p: Reader, input: EntropyPolicySuccessionOperation,
  options: { readonly blockTag: number; readonly gasLimit: bigint }): Promise<EntropyPolicySuccessionSimulation> {
  const o = operation(input); keys(options, ["blockTag", "gasLimit"]);
  const tag = number(options.blockTag), gasLimit = uint(options.gasLimit, 64);
  if (!gasLimit || gasLimit > 100_000_000n) throw Error("Gas limit outside client bound");
  const i = inspectionOf(o), d = i.capture.deployment;
  await historical(p, i);
  const block = await context(p, d, tag);
  if (o.kind === "permissionless" || o.stage !== "publish") {
    const fresh = await captureEntropyPolicySuccession(p, d, { blockTag: tag });
    const next = await prepareEntropyPolicySuccession(p, fresh, i.request);
    equal(next.plan, i.plan, "Prepared transition changed");
    if (o.kind === "governance") {
      await ordinary(p, fresh);
      if (o.stage === "schedule") {
        equal(fresh.governanceNonce, o.prepared.batch.nonce, "Governance nonce changed");
        if ((await read(p, d.executor.address, "isProposer", [o.caller], tag, 32))[0] !== true) throw Error("Caller is not a proposer");
        const delay = (await read(p, d.executor.address, "minimumDelay", [i.plan.actionClass], tag, 32))[0];
        equal(delay, 172800n);
        succession.assertEntropyPolicySuccessionGovernanceWindow(o.prepared.batch.window, block.timestamp);
        if (await published(p, d, o.prepared.batch, tag) === ZeroAddress) throw Error("Calls must be published first");
      } else {
        const a = await action(p, o.prepared, tag);
        if (a.status !== 1n || block.timestamp < o.prepared.batch.window.notBefore || block.timestamp > o.prepared.batch.window.expiresAfter) throw Error("Action is not executable at this block");
      }
    }
  }
  const raw = bytes(await p.call({ from: o.caller, to: o.call.to, data: o.call.data, value: o.call.value, gasLimit, blockTag: tag }), 32);
  if (o.kind === "governance" && o.stage === "publish") {
    const values = abi.decodeFunctionResult("publishGovernanceCallData", raw);
    equal(abi.encodeFunctionResult("publishGovernanceCallData", values).toLowerCase(), raw);
    const pointer = address(values[0]), prior = await published(p, d, o.prepared.batch, tag);
    if (prior !== ZeroAddress) equal(pointer, prior, "Existing publication pointer changed");
  } else if (o.kind === "governance" && o.stage === "schedule") equal(raw, coder.encode(["bytes32"], [o.prepared.batch.actionId]));
  else equal(raw, "0x", "Original call must return no data");
  await unchanged(p, block);
  return freeze({ operation: o, observed: block, returnData: raw, actualCallSucceeded: true, futureExecutionGuaranteed: false });
}

const safeAbi = new Interface([
  "function execTransaction(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,bytes signatures) returns(bool)",
  "event ExecutionSuccess(bytes32 txHash,uint256 payment)",
  "event ExecutionFailure(bytes32 txHash,uint256 payment)",
]);
const safeIndexed = new Interface(["event ExecutionSuccess(bytes32 indexed txHash,uint256 payment)", "event ExecutionFailure(bytes32 indexed txHash,uint256 payment)"]);
export type EntropyPolicySuccessionReceiptEvidence =
  | { readonly transactionHash: Hex; readonly transport: "direct" }
  | { readonly transactionHash: Hex; readonly transport: "safe"; readonly safe: Address; readonly safeTransactionHash: Hex };
interface Log { readonly address: Address; readonly topics: readonly Hex[]; readonly data: Hex; readonly index: number }
interface Mined extends Block { readonly hash: Hex; readonly logs: readonly Log[]; readonly safeSuccessIndex: number | null }
function evidence(input: EntropyPolicySuccessionReceiptEvidence): EntropyPolicySuccessionReceiptEvidence {
  if (input.transport === "direct") { keys(input, ["transactionHash", "transport"]); return freeze({ transport: "direct", transactionHash: hash(input.transactionHash) }); }
  keys(input, ["transactionHash", "transport", "safe", "safeTransactionHash"]);
  if (input.transport !== "safe") throw Error("Unsupported receipt transport");
  return freeze({ transport: "safe", transactionHash: hash(input.transactionHash), safe: address(input.safe), safeTransactionHash: hash(input.safeTransactionHash) });
}
async function mined(p: ReceiptReader, o: EntropyPolicySuccessionOperation, e: EntropyPolicySuccessionReceiptEvidence): Promise<Mined> {
  const [r, tx] = await Promise.all([p.getTransactionReceipt(e.transactionHash), p.getTransaction(e.transactionHash)]);
  if (!r || !tx || r.status !== 1 || r.hash.toLowerCase() !== e.transactionHash || tx.hash.toLowerCase() !== e.transactionHash) throw Error("Missing successful transaction");
  const tag = number(r.blockNumber), block = await header(p, tag);
  equal(hash(r.blockHash), block.blockHash); equal(hash(tx.blockHash), block.blockHash);
  equal(tx.blockNumber, tag); equal(tx.chainId, inspectionOf(o).capture.deployment.chainId);
  if (r.logs.length > 4096) throw Error("Too many receipt logs");
  const logs = r.logs.map(l => {
    if (l.removed || l.blockNumber !== tag || !same(l.blockHash, block.blockHash) || !same(l.transactionHash, e.transactionHash)) throw Error("Log transaction differs");
    dense(l.topics, 4);
    return freeze({ address: address(l.address), topics: l.topics.map(v => hash(v, true)), data: bytes(l.data, 32768), index: number(l.index) });
  });
  if (new Set(logs.map(v => v.index)).size !== logs.length) throw Error("Duplicate log indices");
  logs.sort((a, b) => a.index - b.index);
  equal(tx.value, 0n, "Outer transaction value differs");
  let safeSuccessIndex: number | null = null;
  if (e.transport === "direct") {
    equal([address(tx.from), address(tx.to), bytes(tx.data, 262144)], [o.caller, address(o.call.to), o.call.data]);
  } else {
    equal([address(tx.to), o.caller], [e.safe, e.safe]);
    const data = bytes(tx.data, 262144), v = safeAbi.decodeFunctionData("execTransaction", data);
    equal(safeAbi.encodeFunctionData("execTransaction", v).toLowerCase(), data, "Noncanonical Safe calldata");
    equal([address(v[0]), v[1], v[2].toLowerCase(), v[3]], [address(o.call.to), o.call.value, o.call.data, 0n], "Safe must make the exact ordinary CALL");
    const good: number[] = [];
    for (const l of logs.filter(v => same(v.address, e.safe))) {
      for (const name of ["ExecutionSuccess", "ExecutionFailure"] as const) {
        if (!same(l.topics[0], safeAbi.getEvent(name)!.topicHash)) continue;
        const decoder = l.topics.length === 1 ? safeAbi : safeIndexed;
        const f = decoder.getEvent(name)!, parsed = decoder.decodeEventLog(f, l.data, [...l.topics]);
        const encoded = decoder.encodeEventLog(f, parsed);
        equal([encoded.topics.map(v => v.toLowerCase()), encoded.data.toLowerCase()], [l.topics, l.data], "Noncanonical Safe event");
        if (name === "ExecutionFailure") throw Error("Safe execution failed");
        equal(parsed[0].toLowerCase(), e.safeTransactionHash, "Safe transaction hash differs"); good.push(l.index);
      }
    }
    if (good.length !== 1) throw Error("Missing/duplicate Safe success");
    safeSuccessIndex = good[0]!;
  }
  return freeze({ ...block, hash: e.transactionHash, logs, safeSuccessIndex });
}
function events(r: Mined, host: Address, name: string): readonly { readonly values: readonly any[]; readonly index: number }[] {
  const f = abi.getEvent(name)!;
  return r.logs.filter(l => same(l.address, host) && same(l.topics[0], f.topicHash)).map(l => {
    const v = abi.decodeEventLog(f, l.data, [...l.topics]), encoded = abi.encodeEventLog(f, v);
    equal([encoded.topics.map(x => x.toLowerCase()), encoded.data.toLowerCase()], [l.topics, l.data], `Noncanonical ${name} event`);
    return { values: f.inputs.map((t, i) => plain(t, v[i])), index: l.index };
  });
}
function one(r: Mined, host: Address, name: string, expected: readonly unknown[]): number {
  const matches = events(r, host, name);
  if (matches.length !== 1) throw Error(`Expected one ${name} event`);
  equal(matches[0]!.values, expected, `${name} fields differ`); return matches[0]!.index;
}
function ordered(...indices: number[]): void { for (let i = 1; i < indices.length; i++) if (indices[i - 1]! >= indices[i]!) throw Error("Required events are out of order"); }
async function beforeAndAfter(p: Reader, i: EntropyPolicySuccessionInspection, r: Mined): Promise<{ before: EntropyPolicySuccessionCapture; after: EntropyPolicySuccessionCapture }> {
  if (r.blockNumber <= i.capture.blockNumber) throw Error("Receipt must be later than captured block");
  const before = await captureEntropyPolicySuccession(p, i.capture.deployment, { blockTag: r.blockNumber - 1 });
  const rebuilt = await prepareEntropyPolicySuccession(p, before, i.request);
  equal(rebuilt.plan, i.plan, "Prior-block plan differs");
  const after = await captureEntropyPolicySuccession(p, i.capture.deployment, { blockTag: r.blockNumber });
  return { before, after };
}
function expectedManifest(c: EntropyPolicySuccessionCapture, payload: Address, update: MintFallbackManifestUpdate, cutover: boolean): MintFallbackManifestState {
  return normalizeMintFallbackManifestState({ manifestHash: update.manifestHash, manifestURI: update.manifestURI,
    modules: { ...c.manifestState.modules, ...(cutover ? { entropyCoordinator: c.configuration.candidate } : {}) },
    discovery: Object.fromEntries(discoveryKeys.map(k => [k, update[k as keyof MintFallbackManifestUpdate]])) as unknown as MintFallbackManifestState["discovery"],
    revision: c.manifestState.revision + 1n, payloadRoot: payload });
}
async function lifecycleReceipt(p: Reader, i: EntropyPolicySuccessionInspection, r: Mined, actionId: Hex | null): Promise<{ readonly before: EntropyPolicySuccessionCapture; readonly after: EntropyPolicySuccessionCapture; readonly last: number }> {
  const { before: b, after: a } = await beforeAndAfter(p, i, r), c = b.configuration, prior = b.receipt, request = i.plan.request;
  if (actionId !== null) await ordinary(p, b);
  let expected: succession.EntropyPolicySuccessionImportReceipt = prior, last: number;
  switch (request.kind) {
    case "begin": {
      const v = { ...prior, state: 1n as const, nonce: 1n, predecessor: c.predecessor, predecessorCodeHash: c.predecessorCodeHash,
        pointerRevision: b.pointer.revision, count: b.predecessor.header.count, serial: b.predecessor.header.serial,
        idDigest: b.predecessor.header.idDigest, manifestHash: request.manifestHash };
      const importHash = succession.entropyPolicySuccessionImportHash(c, v);
      expected = { ...v, importHash, exportDigest: succession.entropyPolicySuccessionInitialExportDigest(importHash), beginActionId: hash(actionId) };
      last = one(r, c.candidate, "EntropyPolicyImportBegun", [1n, importHash, c.predecessor, 1n, c.predecessorCodeHash, b.pointer.revision, v.count, v.serial, v.idDigest, v.manifestHash, actionId]);
      break;
    }
    case "copy": {
      const policy = b.predecessor.policies[Number(request.expectedIndex)]!, recovery = recoveryFor(b.predecessor, policy);
      const exportDigest = succession.entropyPolicySuccessionAppendExportDigest(prior.exportDigest, request.expectedIndex, policy.collectionId,
        succession.entropyPolicySuccessionExportHash(policy), recovery ? succession.entropyPolicySuccessionRecoveryExportHash(recovery) : ZeroHash as Hex);
      expected = { ...prior, nextIndex: prior.nextIndex + 1n, exportDigest,
        requiredRelayCount: prior.requiredRelayCount + (succession.entropyPolicySuccessionRouteRequired(policy) ? 1n : 0n) };
      last = one(r, c.candidate, "EntropyPolicyImported", [1n, prior.importHash, policy.collectionId, policy.policyOrigin, request.expectedIndex, policy.policyOriginCodeHash, policy.record.policyHash, exportDigest]);
      const recoveryEvents = events(r, c.candidate, "EntropyRecoveryPolicyImported");
      const first = recovery && !b.candidate.recoveries.some(v => same(v.policyId, recovery.policyId));
      if (first) {
        const index = one(r, c.candidate, "EntropyRecoveryPolicyImported", [1n, prior.importHash, recovery.policyId, recovery.policyOrigin, recovery.policyOriginCodeHash, recovery.policyHash]);
        ordered(index, last);
      } else if (recoveryEvents.length !== 0) throw Error("Unexpected repeated recovery import event");
      break;
    }
    case "confirm-route": {
      const policy = selectedPolicy(b, request.collectionId);
      expected = { ...prior, confirmedRelayCount: prior.confirmedRelayCount + 1n };
      last = one(r, c.candidate, "EntropyRelayRouteConfirmed", [1n, prior.importHash, policy.collectionId, policy.policyOrigin, policy.record.policyHash]);
      break;
    }
    case "seal": {
      expected = { ...prior, state: 2n, sealActionId: hash(actionId) };
      last = one(r, c.candidate, "EntropyPolicyImportSealed", [1n, prior.importHash, prior.exportDigest, prior.count, prior.confirmedRelayCount, actionId]);
      break;
    }
    case "admit-route": {
      const policy = request.policy;
      equal(await admission(p, request.origin.target, c.candidate, policy.collectionId, r.blockNumber),
        { successorCodeHash: c.candidateCodeHash, importHash: prior.importHash, policyHash: policy.record.policyHash });
      last = one(r, request.origin.target, "EntropyRelayAdmitted", [1n, policy.collectionId, c.candidate, prior.importHash, c.candidateCodeHash, policy.record.policyHash, actionId]);
      break;
    }
    case "catalog": {
      const rows = request.inventory.additions.slice(Number(request.completedRows), Number(request.completedRows) + 64);
      const next = succession.entropyPolicySuccessionCatalogExtension(c.chainId, c.executor, b.catalog, rows).state;
      equal(a.catalog, next, "Catalog extension readback differs");
      equal(a.manifestState, expectedManifest(b, request.payload, request.update, false), "Catalog manifest tail differs");
      await manifestPayload(p, request.payload, request.update.manifestHash, r.blockNumber);
      const first = one(r, c.executor, "GovernanceActionPolicyExtended", [next.revision, b.catalog.catalogHash, next.catalogHash, b.catalog.entryCount, next.entryCount]);
      last = one(r, c.manifest, "StreamSystemManifestPublished", [1n, request.update.manifestHash, request.payload, actionId]);
      ordered(first, last);
      break;
    }
    case "cutover": {
      expected = { ...prior, state: 3n, activationActionId: hash(actionId) };
      const reg = request.registration;
      const ptr = normalizeMintFallbackPointerState({ target: c.candidate, codeHash: c.candidateCodeHash, frozen: false,
        moduleType: reg.moduleType, interfaceId: reg.interfaceId, registry: c.moduleRegistry, registryStatus: request.registrationStatus,
        moduleManifestHash: reg.moduleManifestHash, deploymentManifestHash: reg.deploymentManifestHash, revision: b.pointer.revision + 1n });
      equal(a.pointer, ptr, "Cutover pointer readback differs");
      equal(a.manifestState, expectedManifest(b, request.payload, request.update, true), "Mandatory manifest tail differs");
      await manifestPayload(p, request.payload, request.update.manifestHash, r.blockNumber);
      const first = one(r, c.core, "CoreSatellitePointerUpdated", [1n, ENTROPY, actionId, c.candidate, c.predecessor]);
      const middle = one(r, c.candidate, "EntropyPolicyImportActivated", [1n, prior.importHash, actionId]);
      last = one(r, c.manifest, "StreamSystemManifestPublished", [1n, request.update.manifestHash, request.payload, actionId]);
      ordered(first, middle, last);
      break;
    }
    default: throw Error("Unsupported lifecycle receipt");
  }
  equal(a.receipt, expected, "Receipt-block import progress differs; later same-block changes are outside this profile");
  if (request.kind !== "cutover") equal(a.pointer, b.pointer, "Unexpected pointer mutation");
  if (request.kind !== "cutover" && request.kind !== "catalog") equal(a.manifestState, b.manifestState, "Unexpected manifest mutation");
  if (request.kind !== "catalog") equal(a.catalog, b.catalog, "Unexpected catalog mutation");
  equal(a.predecessor, b.predecessor, "Source changed within receipt block");
  if (request.kind !== "copy") equal(a.candidate, b.candidate, "Unexpected candidate inventory mutation");
  return { before: b, after: a, last };
}
export interface EntropyPolicySuccessionReceipt {
  readonly operation: EntropyPolicySuccessionOperation;
  readonly evidence: EntropyPolicySuccessionReceiptEvidence;
  readonly transactionHash: Hex;
  readonly blockNumber: number;
  readonly blockHash: Hex;
  readonly publication: "created" | "reused" | null;
  readonly before: EntropyPolicySuccessionCapture | null;
  readonly after: EntropyPolicySuccessionCapture | null;
  readonly verified: true;
}
/** Exact direct/Safe CALL evidence, with explicit prior-block and end-of-block observation limits. */
export async function reconcileEntropyPolicySuccessionReceipt(p: ReceiptReader, input: EntropyPolicySuccessionOperation,
  evidenceInput: EntropyPolicySuccessionReceiptEvidence): Promise<EntropyPolicySuccessionReceipt> {
  const o = operation(input), e = evidence(evidenceInput), i = inspectionOf(o), d = i.capture.deployment;
  await historical(p, i);
  const r = await mined(p, o, e);
  if (r.blockNumber <= i.capture.blockNumber) throw Error("Receipt must be later than captured block");
  await context(p, d, r.blockNumber);
  let last = -1, publication: "created" | "reused" | null = null;
  let before: EntropyPolicySuccessionCapture | null = null, after: EntropyPolicySuccessionCapture | null = null;
  if (o.kind === "permissionless") {
    const v = await lifecycleReceipt(p, i, r, null); ({ before, after, last } = v);
  } else {
    const b = o.prepared.batch, config = i.capture.configuration, firstCall = b.plan.calls[0]!;
    if (o.stage === "publish") {
      const current = await published(p, d, b, r.blockNumber);
      if (current === ZeroAddress) throw Error("Missing retained publication");
      const previousBlock = await header(p, r.blockNumber - 1);
      await runtime(p, d.executor, previousBlock.blockNumber);
      const prior = await published(p, d, b, previousBlock.blockNumber);
      const found = events(r, d.executor.address, "GovernanceCallDataPublished");
      if (prior === ZeroAddress) {
        last = one(r, d.executor.address, "GovernanceCallDataPublished", [1n, b.publicationKey, current, o.caller]); publication = "created";
      } else {
        equal(current, prior, "Immutable publication pointer changed");
        if (found.length !== 0) throw Error("Retained publication unexpectedly emitted creation");
        publication = "reused";
      }
      await unchanged(p, previousBlock);
    } else {
      const a = await action(p, o.prepared, r.blockNumber);
      const common = [1n, b.actionId, b.plan.actionClass, firstCall.target, 0n, firstCall.selector, b.callsHash, b.scopeHash, b.oldValueHash, b.newValueHash];
      if (o.stage === "schedule") {
        const observed = await captureEntropyPolicySuccession(p, d, { blockTag: r.blockNumber });
        await ordinary(p, observed);
        succession.assertEntropyPolicySuccessionGovernanceWindow(b.window, r.timestamp);
        if (![1n, 2n].includes(a.status)) throw Error("Impossible same-block scheduled status");
        last = one(r, d.executor.address, "GovernanceActionScheduled", [...common, b.window.notBefore, b.window.expiresAfter, b.nonce, o.caller, b.window.reasonHash, b.window.reasonURI, b.window.manifestHash]);
        const policyIndex = one(r, d.executor.address, "GovernanceActionPolicyValidated", [1n, b.actionId, 1n, observed.catalog.candidateProfileHash, observed.catalog.catalogHash]);
        ordered(last, policyIndex); last = policyIndex;
      } else {
        if (a.status !== 3n || a.executor !== o.caller || r.timestamp < b.window.notBefore || r.timestamp > b.window.expiresAfter) throw Error("Action was not executed in window by caller");
        const v = await lifecycleReceipt(p, i, r, b.actionId); ({ before, after, last } = v);
        const execution = one(r, d.executor.address, "GovernanceActionExecuted", [...common, o.caller, b.window.manifestHash]);
        const policyIndex = one(r, d.executor.address, "GovernanceActionPolicyValidated", [1n, b.actionId, 2n, before.catalog.candidateProfileHash, before.catalog.catalogHash]);
        ordered(last, execution, policyIndex); last = policyIndex;
      }
    }
    equal(config.executor, d.executor.address);
  }
  if (r.safeSuccessIndex !== null && last >= 0) ordered(last, r.safeSuccessIndex);
  await unchanged(p, r);
  return freeze({ operation: o, evidence: e, transactionHash: r.hash, blockNumber: r.blockNumber, blockHash: r.blockHash, publication, before, after, verified: true });
}
