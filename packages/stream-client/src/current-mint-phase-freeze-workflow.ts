import { AbiCoder, Interface, ZeroAddress, ZeroHash, getAddress, id, isHexString, keccak256, toUtf8Bytes } from "ethers";
import type { Provider } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import type { UnsignedCall } from "./client.js";
import { normalizeMintPolicySnapshot, type MintPolicySnapshot } from "./current-mint-policy-grace.js";
import { normalizeMintPhaseFreezeSnapshot, normalizeMintPhaseFreezeConfigurationInput, mintPhaseFreezeConfigurationHash,
  mintPhaseFreezeTransition, mintPhaseFreezeSelectorStateHash, prepareMintPhaseFreeze, prepareMintPhaseFreezeClassifier,
  normalizeMintPhaseFreezePlan, mintPhaseFreezeGovernanceBatch, normalizeMintPhaseFreezeGovernanceBatch,
  assertMintPhaseFreezeGovernanceWindow, prepareMintPhaseFreezeImport, normalizeMintPhaseFreezeImport,
  type MintPhaseFreezeSnapshot, type MintPhaseFreezeRecord, type MintPhaseFreezeSelectorConfig,
  type MintPhaseFreezeConfigurationInput, type MintPhaseFreezePlan, type MintPhaseFreezeGovernanceBatch,
  type MintPhaseFreezeGovernanceWindow, type MintPhaseFreezeImportPlan } from "./current-mint-phase-freeze.js";

export interface MintPhaseFreezeCodePin { readonly address: Address; readonly codeHash: Hex }
export interface MintPhaseFreezeDeployment {
  readonly chainId: bigint;
  readonly core: MintPhaseFreezeCodePin;
  readonly manager: MintPhaseFreezeCodePin;
  readonly ledger: MintPhaseFreezeCodePin;
  readonly moduleRegistry: MintPhaseFreezeCodePin;
  readonly governance: MintPhaseFreezeCodePin;
}
export interface MintPhaseFreezeScope { readonly collectionId: bigint; readonly phaseId: Hex }
export interface MintPhaseFreezeGrace { readonly previousPolicyHash: Hex; readonly previousPolicyRevision: bigint; readonly graceUntil: bigint }
export interface MintPhaseFreezeCatalog {
  readonly candidateProfileHash: Hex; readonly catalogHash: Hex; readonly entryCount: bigint; readonly revision: bigint;
  readonly rowAdmission: "original-call-simulation-required";
}
export interface MintPhaseFreezePhase {
  readonly scope: MintPhaseFreezeScope;
  readonly snapshot: MintPhaseFreezeSnapshot;
  readonly policy: MintPolicySnapshot | null;
  readonly constraints: MintPhaseFreezeConfigurationInput | null;
  readonly configurationHash: Hex | null;
  readonly grace: MintPhaseFreezeGrace;
  readonly executorCeiling: readonly Address[];
  readonly frozen: boolean;
}
export interface MintPhaseFreezeCapture {
  readonly deployment: MintPhaseFreezeDeployment; readonly scope: MintPhaseFreezeScope;
  readonly phase: MintPhaseFreezePhase; readonly frozenInventory: readonly MintPhaseFreezeScope[];
  readonly selector: MintPhaseFreezeSelectorConfig; readonly writer: boolean; readonly retiredAt: bigint;
  readonly blockNumber: number; readonly blockHash: Hex; readonly timestamp: bigint;
  readonly governanceNonce: bigint; readonly catalog: MintPhaseFreezeCatalog;
  readonly roleRegistry: MintPhaseFreezeCodePin;
  readonly captureHash: Hex;
}
export interface PreparedMintPhaseFreezeGovernance {
  readonly capture: MintPhaseFreezeCapture; readonly proposer: Address; readonly batch: MintPhaseFreezeGovernanceBatch;
}
export interface MintPhaseFreezeOperation {
  readonly prepared: PreparedMintPhaseFreezeGovernance; readonly stage: "publish" | "schedule" | "execute";
  readonly caller: Address; readonly call: UnsignedCall;
}
type Reader = Pick<Provider, "getNetwork" | "getCode" | "getBlock" | "call">;
type ReceiptReader = Reader & Pick<Provider, "getTransaction" | "getTransactionReceipt">;
const coder = AbiCoder.defaultAbiCoder();
const SELECTOR = "0xaf55aad7";
const MAX_PHASES = 256;
const abi = new Interface([
  "event MintPhaseFrozen(uint16 schemaVersion, uint256 indexed collectionId, bytes32 indexed phaseId, bool frozen, bytes32 policyHash)",
  "function core() view returns (address)",
  "function counterConfig(uint256 collectionId, bytes32 phaseId, bytes32 counterId) view returns ((bool enabled, uint8 keyMode, uint8 capMode, uint8 deltaMode, uint64 staticCap, uint64 staticIncrement, bytes32 counterConfigHash))",
  "function governanceAuthority() view returns (address)",
  "function isStreamMintManager() pure returns (bool)",
  "function mintLedger() view returns (address)",
  "function moduleRegistry() view returns (address)",
  "function owner() view returns (address)",
  "function phase(uint256 collectionId, bytes32 phaseId) view returns (bool exists, (bool paused, uint64 startTime, uint64 endTime, uint32 maxBatchQuantity, bytes32 configHash, bytes32 metadataHash) config)",
  "function phaseCounterIds(uint256 collectionId, bytes32 phaseId) view returns (bytes32[])",
  "function phaseExecutor(uint256, bytes32, address) view returns (bool)",
  "function phaseExecutors(uint256 collectionId, bytes32 phaseId) view returns (address[])",
  "function phaseFreezeTransitionHashes(uint256 collectionId, bytes32 phaseId) view returns (bytes32 scope, bytes32 oldHash, bytes32 newHash)",
  "function phaseFrozen(uint256 collectionId, bytes32 phaseId) view returns (bool)",
  "function phaseGate(uint256 collectionId, bytes32 phaseId) view returns ((address gate, bytes32 gateConfigHash, bytes32 gateCodehash, bytes32 gateMetadataHash, uint32 gateSemanticVersion, uint32 gateGasLimit))",
  "function phasePolicyGrace(uint256 collectionId, bytes32 phaseId) view returns (bytes32 previousPolicyHash, uint64 graceUntil)",
  "function phasePolicyHash(uint256, bytes32) view returns (bytes32)",
  "function phaseRoyaltyPolicy(uint256 collectionId, bytes32 phaseId) view returns ((bool configured, bytes32 applicationConfigHash, address resolver, bytes32 resolverRuntimeHash, bytes32 electionHash, bytes32 expectedModeAssignmentHash, bytes32 expectedSourceRoyaltyPolicyHash))",
  "function previewPhasePolicyHash(uint256 collectionId, bytes32 phaseId, (bool paused, uint64 startTime, uint64 endTime, uint32 maxBatchQuantity, bytes32 configHash, bytes32 metadataHash) config, (address gate, bytes32 gateConfigHash, bytes32 gateCodehash, bytes32 gateMetadataHash, uint32 gateSemanticVersion, uint32 gateGasLimit) gateConfig, bytes32[] counterIds, (bool enabled, uint8 keyMode, uint8 capMode, uint8 deltaMode, uint64 staticCap, uint64 staticIncrement, bytes32 counterConfigHash)[] counterConfigs, address[] executors) view returns (bytes32)",
  "function supportsInterface(bytes4 interfaceId) pure returns (bool)",
  "event MintLedgerPhaseFreezeImported(bytes32 indexed importRoot, address indexed predecessorManager, address indexed successorManager, uint256 collectionId, bytes32 phaseId, bytes32 predecessorFrozenPolicyHash, bytes32 successorPolicyHash, bytes32 configurationHash)",
  "event MintLedgerPhaseFrozen(uint16 schemaVersion, address indexed manager, uint256 indexed collectionId, bytes32 indexed phaseId, bytes32 policyHash, bytes32 configurationHash)",
  "function counterDefinitionForManager(address manager, bytes32 hash) view returns (bool, (uint8 scope, uint8 keyMode, bytes32 capRoot, bytes32 metadataHash) d)",
  "function frozenPhaseAt(address manager, uint256 index) view returns (uint256 collectionId, bytes32 phaseId)",
  "function frozenPhaseCount(address manager) view returns (uint256)",
  "function frozenPhaseExecutors(address manager, uint256 collectionId, bytes32 phaseId) view returns (address[])",
  "function importPhaseFreezes(bytes32 root, uint256 maxCount)",
  "function isMintSuccessorReady(address predecessorLedger, address predecessorManager, address successorManager) view returns (bool)",
  "function isStreamMintLedger() pure returns (bool)",
  "function ledgerWriter(address) view returns (bool)",
  "function ledgerWriterRetiredAt(address) view returns (uint64)",
  "function mintImportAncestryProgress(bytes32 root) view returns (uint256 imported, uint256 required)",
  "function mintImportCommitment(bytes32 root) view returns ((address predecessorLedger, address predecessorManager, address successorManager, uint64 snapshotBlock, bytes32 manifestHash, uint64 importedCounters, uint64 importedNullifiers, bool complete))",
  "function mintImportDefinitionProgress(bytes32 root) view returns (uint256 imported, uint256 required)",
  "function mintImportFreezeProgress(bytes32 root) view returns (uint256 imported, uint256 required)",
  "function phaseFreeze(address manager, uint256 collectionId, bytes32 phaseId) view returns ((bytes32 policyHash, bytes32 configurationHash))",
  "function policyGrace(address manager, uint256 collectionId, bytes32 phaseId) view returns (bytes32 previousPolicyHash, uint64 previousPolicyRevision, uint64 previousPolicyGraceUntil)",
  "function registeredCounterPolicy(address manager, uint256 collectionId, bytes32 phaseId, bytes32 counterId) view returns ((bool enabled, uint8 capMode, uint8 deltaMode, uint64 staticCap, uint64 staticIncrement, bytes32 counterConfigHash))",
  "function registeredPhasePolicyHash(address, uint256, bytes32) view returns (bytes32)",
  "function collectionExists(uint256 collectionId) view returns (bool)",
  "function governanceExecutor() view returns (address)",
  "event FreezeSelectorUpdated(uint16 schemaVersion, address indexed target, bytes4 indexed selector, bool freeze, bytes32 targetCodeHash, uint64 revision, bytes32 indexed actionId)",
  "event GovernanceActionExecuted(uint16 schemaVersion, bytes32 indexed actionId, uint8 indexed actionClass, address indexed target, uint256 value, bytes4 selector, bytes32 callHash, bytes32 scopeHash, bytes32 oldValueHash, bytes32 newValueHash, address executor, bytes32 manifestHash)",
  "event GovernanceActionPolicyValidated(uint16 schemaVersion, bytes32 indexed actionId, uint8 indexed phase, bytes32 indexed candidateProfileHash, bytes32 catalogHash)",
  "event GovernanceActionScheduled(uint16 schemaVersion, bytes32 indexed actionId, uint8 indexed actionClass, address indexed target, uint256 value, bytes4 selector, bytes32 callHash, bytes32 scopeHash, bytes32 oldValueHash, bytes32 newValueHash, uint64 notBefore, uint64 expiresAfter, uint256 nonce, address proposer, bytes32 reasonHash, string reasonURI, bytes32 manifestHash)",
  "event GovernanceCallDataPublished(uint16 schemaVersion, bytes32 indexed callDataKey, address pointer, address publisher)",
  "event TerminalFreezeActionMembershipUpdated(uint16 schemaVersion, bytes32 indexed scopeHash, bytes32 indexed actionId, address indexed proposer, bool present, uint8 mutationCause, bool usesRootCapacity, uint64 vetoDeadline, uint256 rawIndex, uint256 remainingCount)",
  "event TerminalFreezeGuardianConfigCommitted(uint16 schemaVersion, bytes32 indexed actionId, bytes32 indexed commitment)",
  "function executeGovernanceBatch(bytes32 actionId, (address target, uint256 value, bytes4 selector, bytes32 callDataHash, bytes32 scopeHash, bytes32 oldValueHash, bytes32 newValueHash)[] calls, bytes[] callDatas) payable",
  "function freezeSelectorConfig(address target, bytes4 selector) view returns (bool freeze, bytes32 targetCodeHash, uint64 revision, bytes32 stateHash)",
  "function governanceAction(bytes32 actionId) view returns ((uint8 status, uint8 actionClass, address target, uint256 value, bytes4 selector, bytes32 callHash, bytes32 scopeHash, bytes32 oldValueHash, bytes32 newValueHash, uint64 notBefore, uint64 expiresAfter, address proposer, address executor, address canceller, address vetoer, bytes32 reasonHash, string reasonURI, bytes32 manifestHash))",
  "function governanceActionFacts(bytes32 id) view returns ((uint8 status, uint8 actionClass, bytes32 callHash, uint64 notBefore, uint64 expiresAfter) facts)",
  "function governanceActionPolicyState() view returns (bytes32 candidateProfileHash, bytes32 catalogHash, uint256 entryCount, uint64 revision)",
  "function governanceNonce() view returns (uint256)",
  "function governanceRootState() view returns (address governanceRoot_, bytes32 codeHash, uint64 revision)",
  "function isFreezeSelector(address target, bytes4 selector) view returns (bool)",
  "function isProposer(address account) view returns (bool)",
  "function minimumDelay(uint8 actionClass) pure returns (uint64)",
  "function publishGovernanceCallData(bytes[] callDatas) returns (address pointer)",
  "function publishedCallData(bytes32 callDataKey) view returns (address)",
  "function registerFreezeSelector(address target, bytes4 selector, bool freeze)",
  "function roleRegistry() view returns (address)",
  "function scheduleGovernanceBatch(uint8 actionClass, (address target, uint256 value, bytes4 selector, bytes32 callDataHash, bytes32 scopeHash, bytes32 oldValueHash, bytes32 newValueHash)[] calls, bytes32 scopeHash, bytes32 oldValueHash, bytes32 newValueHash, uint64 notBefore, uint64 expiresAfter, bytes32 reasonHash, string reasonURI, bytes32 manifestHash) returns (bytes32 actionId)",
  "function scheduledCallData(bytes32 actionId) view returns (bytes[])",
  "function scheduledCallDataPointer(bytes32 actionId) view returns (address)",
  "function systemManifestBootstrapState() view returns (bool, bool, address, bytes32, address, bytes32, uint64, bytes32, uint256, bytes32, uint64, address, bytes32, address, bytes32, bytes32, uint256, bytes32, uint256, bytes32, bytes32, uint256, bytes32, uint256, address, address, bytes32, bytes32, uint256)",
  "function terminalFreezeGuardianConfigCommitment(bytes32 actionId) view returns (bytes32 commitment)",
  "function terminalFreezeVetoGuardianSet(bytes32 scopeHash) view returns (address roleRegistryAddress, bytes32 scopedRole, uint256 scopedHolderCount, bytes32 globalRole, uint256 globalHolderCount, uint64 vetoDeadline)",
  "function terminalFreezeVetoRole(bytes32 scopeHash) pure returns (bytes32)",
  "function isRoleRedundant(bytes32 role) view returns (bool)",
  "function roleHolderCount(bytes32 role) view returns (uint256)"
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
    if (Array.isArray(x)) { dense(x, 4096); return ["array", x.map(tagged)]; }
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
function dense(value: readonly unknown[], maximum: number): void {
  if (!Array.isArray(value) || value.length > maximum || Reflect.ownKeys(value).length !== value.length + 1
    || Array.from({ length: value.length }, (_, i) => i).some(i => !Object.hasOwn(value, i))) throw Error("Expected dense bounded array");
}
function pin(v: MintPhaseFreezeCodePin): MintPhaseFreezeCodePin {
  keys(v, ["address", "codeHash"]);
  return { address: address(v.address), codeHash: hash(v.codeHash) };
}
function deployment(v: MintPhaseFreezeDeployment): MintPhaseFreezeDeployment {
  keys(v, ["chainId", "core", "manager", "ledger", "moduleRegistry", "governance"]);
  const chainId = uint(v.chainId);
  if (!chainId) throw Error("Zero chain");
  const out = { chainId, core: pin(v.core), manager: pin(v.manager), ledger: pin(v.ledger),
    moduleRegistry: pin(v.moduleRegistry), governance: pin(v.governance) };
  if (new Set([out.core, out.manager, out.ledger, out.moduleRegistry, out.governance].map(p => p.address)).size !== 5) {
    throw Error("Deployment components must be distinct");
  }
  return freeze(out);
}
function scope(v: MintPhaseFreezeScope): MintPhaseFreezeScope {
  keys(v, ["collectionId", "phaseId"]);
  if (!uint(v.collectionId)) throw Error("Zero collection");
  return freeze({ collectionId: v.collectionId, phaseId: hash(v.phaseId) });
}
function addresses(value: readonly unknown[]): Address[] {
  dense(value, 64);
  const out = value.map(address);
  if (new Set(out).size !== out.length) throw Error("Duplicate executor");
  return out;
}
function object(v: any, names: readonly string[]) { return Object.fromEntries(names.map((n, i) => [n, v[i]])); }
const phaseNames = ["paused", "startTime", "endTime", "maxBatchQuantity", "configHash", "metadataHash"];
const gateNames = ["gate", "gateConfigHash", "gateCodehash", "gateMetadataHash", "gateSemanticVersion", "gateGasLimit"];
const counterNames = ["enabled", "keyMode", "capMode", "deltaMode", "staticCap", "staticIncrement", "counterConfigHash"];
const definitionNames = ["scope", "keyMode", "capRoot", "metadataHash"];
const royaltyNames = ["configured", "applicationConfigHash", "resolver", "resolverRuntimeHash", "electionHash", "expectedModeAssignmentHash", "expectedSourceRoyaltyPolicyHash"];
async function read(p: Reader, to: Address, name: string, args: readonly unknown[], tag: number, from?: Address): Promise<any> {
  const raw = bytes(await p.call({ to, data: abi.encodeFunctionData(name, args), value: 0n, blockTag: tag, ...(from ? { from } : {}) }));
  const decoded = abi.decodeFunctionResult(name, raw);
  if (!same(abi.encodeFunctionResult(name, decoded), raw)) throw Error(`Noncanonical ${name} return`);
  return decoded;
}
async function header(p: Reader, tag: number) {
  const b = await p.getBlock(tag);
  if (!b || b.number !== tag || !Number.isSafeInteger(b.timestamp) || b.timestamp < 0) throw Error("Missing/mismatched block");
  return { blockNumber: tag, blockHash: hash(b.hash), timestamp: BigInt(b.timestamp) };
}
async function unchanged(p: Reader, h: { blockNumber: number; blockHash: Hex; timestamp: bigint }): Promise<void> {
  equal(await header(p, h.blockNumber), { blockNumber: h.blockNumber, blockHash: h.blockHash, timestamp: h.timestamp }, "Pinned block changed");
}
async function runtime(p: Reader, v: MintPhaseFreezeCodePin, tag: number): Promise<void> {
  const code = bytes(await p.getCode(v.address, tag), 65536);
  if (code === "0x" || (code.length === 48 && code.startsWith("0xef0100")) || !same(keccak256(code), v.codeHash)) throw Error("Pinned runtime differs");
}
async function managerBindings(p: Reader, d: MintPhaseFreezeDeployment, manager: MintPhaseFreezeCodePin, tag: number, successor = true): Promise<void> {
  await runtime(p, manager, tag);
  for (const [name, expected] of [["core", d.core.address], ["mintLedger", d.ledger.address], ["moduleRegistry", d.moduleRegistry.address]] as const) {
    if (!same((await read(p, manager.address, name, [], tag))[0], expected)) throw Error(`Manager ${name} differs`);
  }
  if (successor) {
    for (const name of ["owner", "governanceAuthority"]) {
      if (!same((await read(p, manager.address, name, [], tag))[0], d.governance.address)) throw Error(`Manager ${name} differs`);
    }
  }
  if ((await read(p, manager.address, "isStreamMintManager", [], tag))[0] !== true
    || (await read(p, manager.address, "supportsInterface", ["0xb4074ed7"], tag))[0] !== true
    || (await read(p, manager.address, "supportsInterface", ["0x75408bb0"], tag))[0] !== true) throw Error("Manager capability differs");
}
async function context(p: Reader, d: MintPhaseFreezeDeployment, tag: number) {
  if ((await p.getNetwork()).chainId !== d.chainId) throw Error("RPC chain differs");
  const h = await header(p, tag);
  await Promise.all([d.core, d.ledger, d.moduleRegistry, d.governance].map(v => runtime(p, v, tag)));
  await managerBindings(p, d, d.manager, tag);
  if (!same((await read(p, d.ledger.address, "owner", [], tag))[0], d.governance.address)
    || !same((await read(p, d.moduleRegistry.address, "governanceExecutor", [], tag))[0], d.governance.address)
    || (await read(p, d.ledger.address, "isStreamMintLedger", [], tag))[0] !== true
    || (await read(p, d.ledger.address, "supportsInterface", ["0x364317e1"], tag))[0] !== true
    || (await read(p, d.governance.address, "minimumDelay", [2n], tag))[0] !== 259200n
    || (await read(p, d.governance.address, "minimumDelay", [0n], tag))[0] !== 0n) throw Error("Dependency capability/governance differs");
  const boot = await read(p, d.governance.address, "systemManifestBootstrapState", [], tag);
  if (boot[0] !== true || boot[1] !== true) throw Error("Ordinary sealed governance required");
  const roleRegistry = pin({ address: boot[2], codeHash: boot[3] });
  await runtime(p, roleRegistry, tag);
  if (!same((await read(p, d.governance.address, "roleRegistry", [], tag))[0], roleRegistry.address)) throw Error("Role registry differs");
  const [profile, catalog, count, revision] = await read(p, d.governance.address, "governanceActionPolicyState", [], tag);
  if (count === 0n || count > 1024n) throw Error("Unbound/oversized governance catalog");
  return { ...h, roleRegistry, governanceNonce: uint((await read(p, d.governance.address, "governanceNonce", [], tag))[0]),
    catalog: { candidateProfileHash: hash(profile), catalogHash: hash(catalog), entryCount: uint(count), revision: uint(revision, 64),
      rowAdmission: "original-call-simulation-required" as const } };
}
async function inventory(p: Reader, d: MintPhaseFreezeDeployment, manager: Address, tag: number): Promise<MintPhaseFreezeScope[]> {
  const [count] = await read(p, d.ledger.address, "frozenPhaseCount", [manager], tag);
  if (count > BigInt(MAX_PHASES)) throw Error("Frozen inventory exceeds client bound256");
  const result: MintPhaseFreezeScope[] = [];
  for (let i = 0n; i < count; i++) {
    const [collectionId, phaseId] = await read(p, d.ledger.address, "frozenPhaseAt", [manager, i], tag);
    result.push(scope({ collectionId, phaseId }));
  }
  if (new Set(result.map(v => `${v.collectionId}:${v.phaseId}`)).size !== result.length) throw Error("Duplicate frozen identity");
  return result;
}
async function phase(p: Reader, d: MintPhaseFreezeDeployment, manager: Address, s: MintPhaseFreezeScope, tag: number,
  allowAbsent = false): Promise<MintPhaseFreezePhase> {
  const args = [s.collectionId, s.phaseId], ledgerArgs = [manager, ...args];
  if ((await read(p, d.core.address, "collectionExists", [s.collectionId], tag))[0] !== true) throw Error("Unknown collection");
  const [recordTuple] = await read(p, d.ledger.address, "phaseFreeze", ledgerArgs, tag);
  const record = { policyHash: hash(recordTuple[0], true), configurationHash: hash(recordTuple[1], true) };
  if ((record.policyHash === ZeroHash) !== (record.configurationHash === ZeroHash)) throw Error("Partial freeze record");
  const frozen = record.configurationHash !== ZeroHash;
  if ((await read(p, manager, "phaseFrozen", args, tag))[0] !== frozen) throw Error("Manager/Ledger freeze differs");
  const executorCeiling = addresses((await read(p, d.ledger.address, "frozenPhaseExecutors", ledgerArgs, tag))[0]);
  if (!frozen && executorCeiling.length) throw Error("Unfrozen executor ceiling");
  const [exists, config] = await read(p, manager, "phase", args, tag);
  const currentPolicyHash = hash((await read(p, manager, "phasePolicyHash", args, tag))[0], true);
  if (!same((await read(p, d.ledger.address, "registeredPhasePolicyHash", ledgerArgs, tag))[0], currentPolicyHash)) throw Error("Manager/Ledger policy differs");
  const executors = addresses((await read(p, manager, "phaseExecutors", args, tag))[0]);
  const [previous, revision, until] = await read(p, d.ledger.address, "policyGrace", ledgerArgs, tag);
  const grace = { previousPolicyHash: hash(previous, true), previousPolicyRevision: uint(revision, 64), graceUntil: uint(until, 64) };
  if (previous === ZeroHash ? revision !== 0n || until !== 0n : revision === 0n || until === 0n || same(previous, currentPolicyHash)) throw Error("Malformed predecessor grace");
  equal(Array.from(await read(p, manager, "phasePolicyGrace", args, tag)), [previous, until], "Manager/Ledger grace differs");
  const snapshot = normalizeMintPhaseFreezeSnapshot({ chainId: d.chainId, core: d.core.address, manager, ledger: d.ledger.address,
    governanceExecutor: d.governance.address, ...s, currentPolicyHash, record });
  if (!exists) {
    if ((!frozen && !allowAbsent) || currentPolicyHash !== ZeroHash || executors.length || previous !== ZeroHash) throw Error("Unknown/inconsistent unconfigured phase");
    return freeze({ scope: s, snapshot, policy: null, constraints: null, configurationHash: null, grace, executorCeiling, frozen });
  }
  if (currentPolicyHash === ZeroHash) throw Error("Configured phase has no policy");
  const [gate] = await read(p, manager, "phaseGate", args, tag);
  const [ids] = await read(p, manager, "phaseCounterIds", args, tag);
  if (ids.length > 16) throw Error("Counter inventory exceeds16");
  const counterConfigs = [], defined = [], definitions = [];
  for (const counterId of ids) {
    const [value] = await read(p, manager, "counterConfig", [...args, counterId], tag);
    const [ledger] = await read(p, d.ledger.address, "registeredCounterPolicy", [...ledgerArgs, counterId], tag);
    equal(Array.from(ledger), [value.enabled, value.capMode, value.deltaMode, value.staticCap, value.staticIncrement, value.counterConfigHash], "Manager/Ledger counter differs");
    const [present, definition] = await read(p, d.ledger.address, "counterDefinitionForManager", [manager, value.counterConfigHash], tag);
    counterConfigs.push(object(value, counterNames));
    defined.push(present);
    definitions.push(object(definition, definitionNames));
  }
  const policy = normalizeMintPolicySnapshot({ chainId: d.chainId, manager, ledger: d.ledger.address,
    moduleRegistry: d.moduleRegistry.address, ...s, config: object(config, phaseNames), gate: object(gate, gateNames),
    counterIds: Array.from(ids), counterConfigs, executors, currentPolicyHash } as unknown as MintPolicySnapshot);
  const [preview] = await read(p, manager, "previewPhasePolicyHash", [...args, policy.config, policy.gate,
    policy.counterIds, policy.counterConfigs, policy.executors], tag);
  if (!same(preview, currentPolicyHash)) throw Error("Policy inventory preview differs");
  for (const executor of executors) {
    if ((await read(p, manager, "phaseExecutor", [...args, executor], tag))[0] !== true) throw Error("Executor membership differs");
  }
  const [royalty] = await read(p, manager, "phaseRoyaltyPolicy", args, tag);
  const { executors: ignored, currentPolicyHash: ignoredHash, ...base } = policy;
  const constraints = normalizeMintPhaseFreezeConfigurationInput({ ...base, core: d.core.address, defined, definitions,
    royalty: object(royalty, royaltyNames) } as unknown as MintPhaseFreezeConfigurationInput);
  const configurationHash = mintPhaseFreezeConfigurationHash(constraints);
  if (frozen && (!same(configurationHash, record.configurationHash) || executors.length !== executorCeiling.length
    || executors.some(v => !executorCeiling.some(e => same(e, v))))) throw Error("Frozen configuration/remaining ceiling differs");
  equal(Array.from(await read(p, manager, "phaseFreezeTransitionHashes", args, tag)), Object.values(mintPhaseFreezeTransition(snapshot)), "Original transition differs");
  return freeze({ scope: s, snapshot, policy, constraints, configurationHash, grace, executorCeiling, frozen });
}
async function selector(p: Reader, d: MintPhaseFreezeDeployment, tag: number): Promise<MintPhaseFreezeSelectorConfig> {
  const [enabled, targetCodeHash, revision, stateHash] = await read(p, d.governance.address, "freezeSelectorConfig", [d.manager.address, SELECTOR], tag);
  const value = { enabled, targetCodeHash: hash(targetCodeHash, true), revision: uint(revision, 64), stateHash: hash(stateHash) };
  if (!same(value.stateHash, mintPhaseFreezeSelectorStateHash(d.chainId, d.governance.address, d.manager.address,
    { enabled, targetCodeHash: value.targetCodeHash, revision }))) throw Error("Classifier state hash differs");
  if ((await read(p, d.governance.address, "isFreezeSelector", [d.manager.address, SELECTOR], tag))[0] !== enabled) throw Error("Classifier enabled flag differs");
  return value;
}
function digest(v: unknown): Hex { return keccak256(toUtf8Bytes(stable(v))) as Hex; }
function saved(v: MintPhaseFreezeCapture): MintPhaseFreezeCapture {
  keys(v, ["deployment", "scope", "phase", "frozenInventory", "selector", "writer", "retiredAt", "blockNumber", "blockHash", "timestamp", "governanceNonce", "catalog", "roleRegistry", "captureHash"]);
  const out = { ...structuredClone(v), deployment: deployment(v.deployment), scope: scope(v.scope) };
  const { captureHash, ...facts } = out;
  if (!same(digest(facts), hash(captureHash))) throw Error("Saved capture facts changed");
  return freeze(out);
}
/** Concrete block capture. Inventory is the original ordered Ledger inventory, bounded to256 identities. */
export async function captureMintPhaseFreeze(p: Reader, input: MintPhaseFreezeDeployment, supplied: MintPhaseFreezeScope,
  options: { readonly blockTag: number }): Promise<MintPhaseFreezeCapture> {
  keys(options, ["blockTag"]);
  const d = deployment(input), s = scope(supplied), tag = number(options.blockTag);
  const h = await context(p, d, tag);
  const observed = await phase(p, d, d.manager.address, s, tag, true);
  const frozenInventory = await inventory(p, d, d.manager.address, tag);
  if (frozenInventory.some(v => v.collectionId === s.collectionId && same(v.phaseId, s.phaseId)) !== observed.frozen) throw Error("Frozen inventory membership differs");
  const facts = { deployment: d, scope: s, phase: observed, frozenInventory, selector: await selector(p, d, tag),
    writer: (await read(p, d.ledger.address, "ledgerWriter", [d.manager.address], tag))[0] as boolean,
    retiredAt: uint((await read(p, d.ledger.address, "ledgerWriterRetiredAt", [d.manager.address], tag))[0], 64), ...h };
  await unchanged(p, h);
  return freeze({ ...facts, captureHash: digest(facts) });
}
async function original(p: Reader, c: MintPhaseFreezeCapture): Promise<void> {
  equal(await captureMintPhaseFreeze(p, c.deployment, c.scope, { blockTag: c.blockNumber }), c, "Saved capture no longer matches historical block");
}
function planFor(c: MintPhaseFreezeCapture, kind: MintPhaseFreezePlan["kind"]): MintPhaseFreezePlan {
  if (kind === "classifier") {
    return prepareMintPhaseFreezeClassifier({ chainId: c.deployment.chainId, governanceExecutor: c.deployment.governance.address,
      manager: c.deployment.manager.address, managerCodeHash: c.deployment.manager.codeHash, config: c.selector });
  }
  if (kind !== "freeze") throw Error("Unsupported plan kind");
  if (!c.writer || c.retiredAt !== 0n) throw Error("Freeze requires active nonretired Ledger writer");
  if (!c.selector.enabled || !same(c.selector.targetCodeHash, c.deployment.manager.codeHash)) throw Error("Classify this Manager freeze selector first");
  return prepareMintPhaseFreeze(c.phase.snapshot);
}
export function prepareMintPhaseFreezeGovernance(input: MintPhaseFreezeCapture, kind: MintPhaseFreezePlan["kind"], proposer: Address,
  window: MintPhaseFreezeGovernanceWindow): PreparedMintPhaseFreezeGovernance {
  const c = saved(input), plan = planFor(c, kind), batch = mintPhaseFreezeGovernanceBatch(plan, c.governanceNonce, window);
  assertMintPhaseFreezeGovernanceWindow(plan.actionClass, batch.window, c.timestamp);
  if (toUtf8Bytes(batch.window.reasonURI).length > 2048) throw Error("Reason URI exceeds client bound2048");
  return freeze({ capture: c, proposer: address(proposer), batch });
}
function prepared(v: PreparedMintPhaseFreezeGovernance): PreparedMintPhaseFreezeGovernance {
  keys(v, ["capture", "proposer", "batch"]);
  const batch = normalizeMintPhaseFreezeGovernanceBatch(v.batch);
  const out = prepareMintPhaseFreezeGovernance(v.capture, batch.plan.kind, v.proposer, batch.window);
  equal(out, v);
  return out;
}
export function prepareMintPhaseFreezeGovernanceOperation(input: PreparedMintPhaseFreezeGovernance,
  stage: MintPhaseFreezeOperation["stage"], caller: Address): MintPhaseFreezeOperation {
  const p = prepared(input), actor = address(caller);
  if (!["publish", "schedule", "execute"].includes(stage)) throw Error("Unsupported governance stage");
  if (stage === "schedule" && !same(actor, p.proposer)) throw Error("Schedule caller differs from proposer");
  return freeze({ prepared: p, stage, caller: actor, call: stage === "publish" ? p.batch.publicationCall
    : stage === "schedule" ? p.batch.scheduleCall : p.batch.executionCall });
}
function operation(v: MintPhaseFreezeOperation): MintPhaseFreezeOperation {
  keys(v, ["prepared", "stage", "caller", "call"]);
  const out = prepareMintPhaseFreezeGovernanceOperation(v.prepared, v.stage, v.caller);
  equal(out, v);
  return out;
}
async function publication(p: Reader, b: MintPhaseFreezeGovernanceBatch, tag: number): Promise<Address | null> {
  const [ptr] = await read(p, b.plan.governanceExecutor, "publishedCallData", [b.publicationKey], tag);
  if (ptr === ZeroAddress) return null;
  const pointer = address(ptr), expected = coder.encode(["bytes[]"], [[b.plan.targetCall.data]]);
  if (!same(bytes(await p.getCode(pointer, tag), 24576), `0x00${expected.slice(2)}`)) throw Error("Published call data differs");
  return pointer;
}
async function action(p: Reader, o: MintPhaseFreezeOperation, tag: number) {
  const b = o.prepared.batch, executor = b.plan.governanceExecutor;
  const [a] = await read(p, executor, "governanceAction", [b.actionId], tag);
  const expected = { actionClass: b.plan.actionClass, target: b.plan.targetCall.to, value: 0n, selector: b.plan.governanceCall.selector,
    callHash: b.callsHash, scopeHash: b.scopeHash, oldValueHash: b.oldValueHash, newValueHash: b.newValueHash,
    notBefore: b.window.notBefore, expiresAfter: b.window.expiresAfter, proposer: o.prepared.proposer,
    reasonHash: b.window.reasonHash, reasonURI: b.window.reasonURI, manifestHash: b.window.manifestHash };
  for (const [key, value] of Object.entries(expected)) {
    if (a[key] !== value && (key === "reasonURI" || !same(a[key], value))) throw Error(`Scheduled ${key} differs`);
  }
  const [facts] = await read(p, executor, "governanceActionFacts", [b.actionId], tag);
  equal(Array.from(facts), [a.status, a.actionClass, a.callHash, a.notBefore, a.expiresAfter], "Action facts differ");
  const [data] = await read(p, executor, "scheduledCallData", [b.actionId], tag);
  equal(Array.from(data), [b.plan.targetCall.data], "Scheduled bytes differ");
  const ptr = await publication(p, b, tag);
  if (!ptr || !same((await read(p, executor, "scheduledCallDataPointer", [b.actionId], tag))[0], ptr)) throw Error("Scheduled pointer differs");
  return a;
}
export interface MintPhaseFreezeGuardians {
  readonly roleRegistry: MintPhaseFreezeCodePin;
  readonly scopedRole: Hex; readonly scopedHolderCount: bigint;
  readonly globalRole: Hex; readonly globalHolderCount: bigint;
  /** Earliest current live action deadline for this scope, not this new action's deadline. */
  readonly earliestVetoDeadline: bigint;
  readonly globalRedundant: boolean;
  readonly admission: "original-call-simulation-required";
}
async function guardians(p: Reader, c: MintPhaseFreezeCapture, plan: MintPhaseFreezePlan, tag: number): Promise<MintPhaseFreezeGuardians | null> {
  if (plan.kind !== "freeze") return null;
  const [registry, scopedRole, scopedCount, globalRole, globalCount, deadline] = await read(p, c.deployment.governance.address,
    "terminalFreezeVetoGuardianSet", [plan.transition.scopeHash], tag);
  const expectedGlobal = id("ROLE_TERMINAL_FREEZE_VETO");
  if (!same(registry, c.roleRegistry.address) || !same(globalRole, expectedGlobal)
    || !same(scopedRole, keccak256(coder.encode(["bytes32", "bytes32"], [expectedGlobal, plan.transition.scopeHash])))
    || scopedCount > 64n || globalCount > 64n) throw Error("Bounded guardian set differs");
  equal((await read(p, registry, "roleHolderCount", [globalRole], tag))[0], globalCount, "Global guardian count differs");
  equal((await read(p, registry, "roleHolderCount", [scopedRole], tag))[0], scopedCount, "Scoped guardian count differs");
  const redundant = (await read(p, registry, "isRoleRedundant", [globalRole], tag))[0];
  if (!redundant || globalCount < 2n) throw Error("Global terminal freeze guardian redundancy unavailable");
  return freeze({ roleRegistry: c.roleRegistry, scopedRole: hash(scopedRole), scopedHolderCount: scopedCount,
    globalRole: hash(globalRole), globalHolderCount: globalCount, earliestVetoDeadline: uint(deadline, 64),
    globalRedundant: redundant, admission: "original-call-simulation-required" });
}
export interface MintPhaseFreezeSimulation {
  readonly operation: MintPhaseFreezeOperation;
  readonly blockNumber: number; readonly blockHash: Hex; readonly timestamp: bigint;
  readonly observed: MintPhaseFreezeCapture | null; readonly guardians: MintPhaseFreezeGuardians | null;
  readonly guardianCommitment: Hex | null; readonly returnData: Hex;
}
/** Original Executor eth_call; permissionless execute still goes through all catalog, role and guardian admission. */
export async function simulateMintPhaseFreezeOperation(p: Reader, input: MintPhaseFreezeOperation,
  options: { readonly blockTag: number }): Promise<MintPhaseFreezeSimulation> {
  keys(options, ["blockTag"]);
  const o = operation(input), c = o.prepared.capture, b = o.prepared.batch, tag = number(options.blockTag);
  if (tag < c.blockNumber) throw Error("Simulation predates capture");
  await original(p, c);
  const h = await context(p, c.deployment, tag);
  let observed: MintPhaseFreezeCapture | null = null, guardianSet: MintPhaseFreezeGuardians | null = null, guardianCommitment: Hex | null = null;
  if (o.stage !== "publish") {
    equal(h.catalog, c.catalog, "Governance catalog changed; reschedule");
    observed = await captureMintPhaseFreeze(p, c.deployment, c.scope, { blockTag: tag });
    equal(planFor(observed, b.plan.kind), b.plan, "Committed transition changed; recapture and reschedule");
    // The target call has no independent expected-state argument. Compare complete reviewed facts before simulation.
    equal(observed.phase, c.phase, "Phase facts changed; recapture and reschedule");
    guardianSet = await guardians(p, observed, b.plan, tag);
    if (o.stage === "schedule") {
      if (h.governanceNonce !== b.nonce) throw Error("Governance nonce changed");
      assertMintPhaseFreezeGovernanceWindow(b.plan.actionClass, b.window, h.timestamp);
      if (!await publication(p, b, tag)) throw Error("Publish governance call data first");
      const [owner] = await read(p, b.plan.governanceExecutor, "owner", [], tag);
      if (!same(owner, o.caller) && (await read(p, b.plan.governanceExecutor, "isProposer", [o.caller], tag))[0] !== true) throw Error("Caller is not an authorized proposer");
    } else {
      const a = await action(p, o, tag);
      if (a.status !== 1n || h.timestamp < b.window.notBefore || h.timestamp > b.window.expiresAfter) throw Error("Action outside scheduled execution window");
      if (b.plan.kind === "freeze") guardianCommitment = hash((await read(p, b.plan.governanceExecutor, "terminalFreezeGuardianConfigCommitment", [b.actionId], tag))[0]);
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
  return freeze({ operation: o, blockNumber: tag, blockHash: h.blockHash, timestamp: h.timestamp, observed,
    guardians: guardianSet, guardianCommitment, returnData: returned });
}

export interface MintPhaseFreezeImportScope { readonly importRoot: Hex; readonly predecessorManager: MintPhaseFreezeCodePin }
export interface MintPhaseFreezeImportCommitment {
  readonly predecessorLedger: Address; readonly predecessorManager: Address; readonly successorManager: Address;
  readonly snapshotBlock: bigint; readonly manifestHash: Hex; readonly importedCounters: bigint;
  readonly importedNullifiers: bigint; readonly complete: boolean;
}
export interface MintPhaseFreezeProgress { readonly imported: bigint; readonly required: bigint }
export interface MintPhaseFreezeImportCapture {
  readonly deployment: MintPhaseFreezeDeployment; readonly scope: MintPhaseFreezeImportScope;
  readonly commitment: MintPhaseFreezeImportCommitment;
  readonly progress: { readonly freezes: MintPhaseFreezeProgress; readonly definitions: MintPhaseFreezeProgress; readonly ancestry: MintPhaseFreezeProgress };
  readonly predecessorInventory: readonly MintPhaseFreezeScope[]; readonly successorInventory: readonly MintPhaseFreezeScope[];
  /** At most32 next entries; full identities remain in predecessorInventory. */
  readonly next: readonly { readonly ordinal: bigint; readonly predecessor: MintPhaseFreezePhase; readonly successor: MintPhaseFreezePhase }[];
  readonly predecessorRetiredAt: bigint; readonly successorRetiredAt: bigint; readonly successorReady: boolean;
  readonly completionBarrier: "original import completion additionally requires all definitions, ancestry and leaf proofs";
  readonly blockNumber: number; readonly blockHash: Hex; readonly timestamp: bigint;
  readonly captureHash: Hex;
}
export interface MintPhaseFreezeImportOperation {
  readonly capture: MintPhaseFreezeImportCapture; readonly plan: MintPhaseFreezeImportPlan;
  readonly caller: Address; readonly call: UnsignedCall;
}
export interface MintPhaseFreezeImportSimulation {
  readonly operation: MintPhaseFreezeImportOperation;
  readonly observed: MintPhaseFreezeImportCapture;
  readonly returnData: Hex;
}
function importScope(v: MintPhaseFreezeImportScope): MintPhaseFreezeImportScope {
  keys(v, ["importRoot", "predecessorManager"]);
  return freeze({ importRoot: hash(v.importRoot), predecessorManager: pin(v.predecessorManager) });
}
function savedImport(v: MintPhaseFreezeImportCapture): MintPhaseFreezeImportCapture {
  keys(v, ["deployment", "scope", "commitment", "progress", "predecessorInventory", "successorInventory", "next",
    "predecessorRetiredAt", "successorRetiredAt", "successorReady", "completionBarrier", "blockNumber", "blockHash", "timestamp", "captureHash"]);
  const out = { ...structuredClone(v), deployment: deployment(v.deployment), scope: importScope(v.scope) };
  const { captureHash, ...facts } = out;
  if (!same(digest(facts), hash(captureHash))) throw Error("Saved import capture facts changed");
  return freeze(out);
}
/** Existing original same-Ledger import root; no alternate commitment or automatic completion. */
export async function captureMintPhaseFreezeImport(p: Reader, input: MintPhaseFreezeDeployment, supplied: MintPhaseFreezeImportScope,
  options: { readonly blockTag: number }): Promise<MintPhaseFreezeImportCapture> {
  keys(options, ["blockTag"]);
  const d = deployment(input), s = importScope(supplied), tag = number(options.blockTag);
  if (same(s.predecessorManager.address, d.manager.address)) throw Error("Predecessor and successor must differ");
  const h = await context(p, d, tag);
  await managerBindings(p, d, s.predecessorManager, tag, false);
  const [stored] = await read(p, d.ledger.address, "mintImportCommitment", [s.importRoot], tag);
  const commitment = object(stored, ["predecessorLedger", "predecessorManager", "successorManager", "snapshotBlock", "manifestHash",
    "importedCounters", "importedNullifiers", "complete"]) as unknown as MintPhaseFreezeImportCommitment;
  if (!same(commitment.predecessorLedger, d.ledger.address) || !same(commitment.predecessorManager, s.predecessorManager.address)
    || !same(commitment.successorManager, d.manager.address) || commitment.snapshotBlock > BigInt(tag)) throw Error("Unknown/mismatched same-Ledger import root");
  hash(commitment.manifestHash);
  const predecessorRetiredAt = uint((await read(p, d.ledger.address, "ledgerWriterRetiredAt", [s.predecessorManager.address], tag))[0], 64);
  const successorRetiredAt = uint((await read(p, d.ledger.address, "ledgerWriterRetiredAt", [d.manager.address], tag))[0], 64);
  if (predecessorRetiredAt === 0n || predecessorRetiredAt > commitment.snapshotBlock
    || (await read(p, d.ledger.address, "ledgerWriter", [s.predecessorManager.address], tag))[0] !== false) throw Error("Predecessor retirement/snapshot differs");
  const progressOf = async (name: string): Promise<MintPhaseFreezeProgress> => {
    const [imported, required] = await read(p, d.ledger.address, name, [s.importRoot], tag);
    if (imported > required) throw Error("Import progress exceeds required");
    return { imported, required };
  };
  const progress = { freezes: await progressOf("mintImportFreezeProgress"), definitions: await progressOf("mintImportDefinitionProgress"),
    ancestry: await progressOf("mintImportAncestryProgress") };
  const predecessorInventory = await inventory(p, d, s.predecessorManager.address, tag);
  const successorInventory = await inventory(p, d, d.manager.address, tag);
  if (progress.freezes.required !== BigInt(predecessorInventory.length)) throw Error("Committed freeze inventory count differs");
  const successorReady = (await read(p, d.ledger.address, "isMintSuccessorReady", [d.ledger.address, s.predecessorManager.address, d.manager.address], tag))[0];
  const successorWriter = (await read(p, d.ledger.address, "ledgerWriter", [d.manager.address], tag))[0];
  if (successorReady !== (commitment.complete && successorWriter && successorRetiredAt === 0n)) throw Error("Successor readiness differs from original writer/completion predicate");
  if (commitment.complete && Object.values(progress).some(v => v.imported !== v.required)) throw Error("Completed import has incomplete progress");
  const next = [];
  const end = progress.freezes.imported + 32n < progress.freezes.required ? progress.freezes.imported + 32n : progress.freezes.required;
  for (let i = progress.freezes.imported; i < end; i++) {
    const identity = predecessorInventory[Number(i)]!;
    const predecessor = await phase(p, d, s.predecessorManager.address, identity, tag);
    const successor = await phase(p, d, d.manager.address, identity, tag, true);
    if (!predecessor.frozen) throw Error("Predecessor inventory record missing");
    next.push({ ordinal: i, predecessor, successor });
  }
  const facts = { deployment: d, scope: s, commitment, progress, predecessorInventory, successorInventory, next,
    predecessorRetiredAt, successorRetiredAt, successorReady, completionBarrier: "original import completion additionally requires all definitions, ancestry and leaf proofs" as const,
    blockNumber: tag, blockHash: h.blockHash, timestamp: h.timestamp };
  await unchanged(p, h);
  return freeze({ ...facts, captureHash: digest(facts) });
}
async function originalImport(p: Reader, c: MintPhaseFreezeImportCapture): Promise<void> {
  equal(await captureMintPhaseFreezeImport(p, c.deployment, c.scope, { blockTag: c.blockNumber }), c, "Saved import no longer matches historical block");
}
export function prepareMintPhaseFreezeImportOperation(input: MintPhaseFreezeImportCapture, caller: Address, maxCount: bigint): MintPhaseFreezeImportOperation {
  const c = savedImport(input);
  if (c.commitment.complete || c.successorRetiredAt !== 0n) throw Error("Import is complete or successor retired");
  const plan = prepareMintPhaseFreezeImport(c.deployment.ledger.address, caller, c.scope.importRoot, maxCount);
  for (const { predecessor, successor } of c.next.slice(0, Number(plan.maxCount))) {
    if (successor.configurationHash && !same(successor.configurationHash, predecessor.snapshot.record.configurationHash)) throw Error("Successor frozen configuration incompatible");
    const executors = successor.policy?.executors ?? predecessor.executorCeiling;
    if (executors.some(v => !predecessor.executorCeiling.some(e => same(e, v)))) throw Error("Successor executor ceiling exceeds predecessor");
    if (successor.frozen && (!same(successor.snapshot.record.configurationHash, predecessor.snapshot.record.configurationHash)
      || executors.some(v => !successor.executorCeiling.some(e => same(e, v))))) throw Error("Existing successor freeze incompatible");
  }
  return freeze({ capture: c, plan, caller: plan.caller, call: plan.call });
}
function importOperation(v: MintPhaseFreezeImportOperation): MintPhaseFreezeImportOperation {
  keys(v, ["capture", "plan", "caller", "call"]);
  const plan = normalizeMintPhaseFreezeImport(v.plan);
  const out = prepareMintPhaseFreezeImportOperation(v.capture, v.caller, plan.maxCount);
  equal(out, v);
  return out;
}
export async function simulateMintPhaseFreezeImport(p: Reader, input: MintPhaseFreezeImportOperation, options: { readonly blockTag: number }): Promise<MintPhaseFreezeImportSimulation> {
  keys(options, ["blockTag"]);
  const o = importOperation(input), tag = number(options.blockTag), c = o.capture;
  if (tag < c.blockNumber) throw Error("Simulation predates capture");
  await originalImport(p, c);
  const fresh = await captureMintPhaseFreezeImport(p, c.deployment, c.scope, { blockTag: tag });
  for (const key of ["commitment", "progress", "predecessorInventory", "successorInventory", "next", "successorRetiredAt"] as const) {
    equal(fresh[key], c[key], "Import facts changed; recapture");
  }
  const returned = bytes(await p.call({ ...o.call, from: o.caller, blockTag: tag }));
  if (returned !== "0x") throw Error("Noncanonical void import return");
  await unchanged(p, fresh);
  return freeze({ operation: o, observed: fresh, returnData: returned });
}

export interface MintPhaseFreezeEventReference {
  readonly address: Address; readonly event: string; readonly logIndex: number;
  readonly transactionHash: Hex; readonly blockHash: Hex;
}
export interface MintPhaseFreezeReceipt {
  readonly operation: MintPhaseFreezeOperation;
  readonly transactionHash: Hex; readonly blockNumber: number; readonly blockHash: Hex;
  readonly events: readonly MintPhaseFreezeEventReference[]; readonly observed: MintPhaseFreezeCapture | null;
  readonly stateAttribution: "events identify this operation; exact end-of-block phase state required";
}
export interface MintPhaseFreezeImportReceipt {
  readonly operation: MintPhaseFreezeImportOperation;
  readonly transactionHash: Hex; readonly blockNumber: number; readonly blockHash: Hex;
  readonly events: readonly MintPhaseFreezeEventReference[]; readonly observed: MintPhaseFreezeImportCapture;
  readonly copiedOrdinals: readonly bigint[];
  readonly stateAttribution: "copy events identify this operation; progress is an end-of-block observation";
}
const safeAbi = new Interface(["function execTransaction(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,bytes signatures) returns(bool)"]);
const safePlain = new Interface(["event ExecutionSuccess(bytes32 txHash,uint256 payment)", "event ExecutionFailure(bytes32 txHash,uint256 payment)"]);
const safeIndexed = new Interface(["event ExecutionSuccess(bytes32 indexed txHash,uint256 payment)", "event ExecutionFailure(bytes32 indexed txHash,uint256 payment)"]);
interface Log { address: Address; topics: Hex[]; data: Hex; index: number }
interface ReceiptOptions { readonly transactionHash: Hex; readonly execution: "direct" | "safe" }
async function mined(p: ReceiptReader, d: MintPhaseFreezeDeployment, caller: Address, call: UnsignedCall, before: number,
  options: ReceiptOptions) {
  const transactionHash = options.transactionHash, execution = options.execution;
  const [r, tx] = await Promise.all([p.getTransactionReceipt(transactionHash), p.getTransaction(transactionHash)]);
  if (!r || !tx || r.status !== 1 || !same(r.hash, transactionHash) || !same(tx.hash, transactionHash)
    || tx.chainId !== d.chainId || tx.value !== 0n || r.blockNumber <= before || tx.blockNumber !== r.blockNumber
    || !same(tx.blockHash, r.blockHash) || !same(tx.to, r.to) || !same(tx.from, r.from)) throw Error("Receipt/transaction identity or chronology differs");
  const data = bytes(tx.data, 262144);
  if (execution === "direct") {
    if (!same(tx.from, caller) || !same(tx.to, call.to) || !same(data, call.data)) throw Error("Direct call differs");
  } else {
    const decoded = safeAbi.decodeFunctionData("execTransaction", data);
    if (!same(tx.to, caller) || !same(safeAbi.encodeFunctionData("execTransaction", decoded), data)
      || !same(decoded[0], call.to) || decoded[1] !== 0n || !same(decoded[2], call.data) || decoded[3] !== 0n) throw Error("Safe requires exact ordinary zero-value CALL");
  }
  const tag = number(r.blockNumber), h = await context(p, d, tag);
  if (!same(h.blockHash, r.blockHash)) throw Error("Receipt block differs");
  if (!Array.isArray(r.logs) || r.logs.length > 256) throw Error("Receipt exceeds256 logs");
  const logs: Log[] = r.logs.map(l => {
    if (l.removed || !same(l.transactionHash, transactionHash) || l.blockNumber !== tag || !same(l.blockHash, h.blockHash)
      || !Array.isArray(l.topics) || l.topics.length > 4) throw Error("Malformed receipt log identity");
    return { address: address(l.address), topics: l.topics.map((x: string) => hash(x, true)), data: bytes(l.data, 16384), index: number(l.index) };
  });
  if (logs.some((l, n) => n > 0 && l.index <= logs[n - 1]!.index)) throw Error("Duplicate/unordered receipt logs");
  const refs: MintPhaseFreezeEventReference[] = [];
  const found = (target: Address, name: string, iface = abi) => {
    const f = iface.getEvent(name)!;
    return logs.filter(l => same(l.address, target) && same(l.topics[0], f.topicHash)).map(log => {
      const args = iface.decodeEventLog(f, log.data, log.topics), encoded = iface.encodeEventLog(f, args);
      if (!same(encoded.data, log.data)) throw Error(`Noncanonical ${name} event data`);
      equal(encoded.topics.map(v => v.toLowerCase()), log.topics, `Noncanonical ${name} topics`);
      return { log, args };
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
  const finish = async () => {
    if (execution === "safe") {
      const successes = logs.filter(l => same(l.address, caller) && same(l.topics[0], safePlain.getEvent("ExecutionSuccess")!.topicHash));
      if (successes.length !== 1 || logs.some(l => same(l.address, caller) && same(l.topics[0], safePlain.getEvent("ExecutionFailure")!.topicHash))) throw Error("Safe requires one success and no failure");
      const log = successes[0]!, iface = log.topics.length === 2 ? safeIndexed : safePlain;
      const parsed = found(caller, "ExecutionSuccess", iface);
      hash(parsed[0]!.args[0]);
      if (refs.some(v => v.logIndex >= log.index)) throw Error("Safe success must follow protocol events");
      reference(log, "ExecutionSuccess");
    }
    await unchanged(p, h);
    return refs.sort((a, b) => a.logIndex - b.logIndex);
  };
  return { tag, h, transactionHash, found, reference, one, finish };
}
function receiptOptions(v: ReceiptOptions): ReceiptOptions {
  keys(v, ["transactionHash", "execution"]);
  if (v.execution !== "direct" && v.execution !== "safe") throw Error("Unsupported receipt execution");
  return freeze({ transactionHash: hash(v.transactionHash), execution: v.execution });
}
/** Singleton Executor CALL receipts. A repeated freeze always fails; only call-data publication is idempotent. */
export async function inspectMintPhaseFreezeReceipt(p: ReceiptReader, input: MintPhaseFreezeOperation,
  supplied: ReceiptOptions): Promise<MintPhaseFreezeReceipt> {
  const o = operation(input), options = receiptOptions(supplied), c = o.prepared.capture, d = c.deployment, b = o.prepared.batch;
  await original(p, c);
  const m = await mined(p, d, o.caller, o.call, c.blockNumber, options), { tag, h, one, found } = m;
  let observed: MintPhaseFreezeCapture | null = null;
  if (o.stage === "publish") {
    const pointer = await publication(p, b, tag);
    if (!pointer) throw Error("Publication not retained");
    const prior = await header(p, tag - 1);
    await runtime(p, d.governance, tag - 1);
    const previousPointer = await publication(p, b, tag - 1);
    if (previousPointer && !same(previousPointer, pointer)) throw Error("Immutable publication pointer changed");
    if (found(d.governance.address, "GovernanceCallDataPublished").length) {
      if (previousPointer) throw Error("Repeat publication cannot emit first-save event");
      one(d.governance.address, "GovernanceCallDataPublished", [1n, b.publicationKey, pointer, o.caller]);
    } else if (!previousPointer) throw Error("Eventless publication requires previous-block proof");
    await unchanged(p, prior);
  } else {
    equal(h.catalog, c.catalog, "Receipt catalog differs from reviewed catalog");
    const state = await action(p, o, tag);
    const common = [1n, b.actionId, b.plan.actionClass, b.plan.targetCall.to, 0n, b.plan.governanceCall.selector,
      b.callsHash, b.scopeHash, b.oldValueHash, b.newValueHash];
    const policyIndex = one(d.governance.address, "GovernanceActionPolicyValidated", [1n, b.actionId,
      o.stage === "schedule" ? 1n : 2n, c.catalog.candidateProfileHash, c.catalog.catalogHash]);
    if (o.stage === "schedule") {
      assertMintPhaseFreezeGovernanceWindow(b.plan.actionClass, b.window, h.timestamp);
      const statuses = b.plan.kind === "freeze" ? [1n, 2n, 5n] : [1n, 2n, 3n];
      if (!statuses.includes(state.status) || h.governanceNonce < b.nonce + 1n) throw Error("Scheduled action/nonce not retained");
      const scheduled = one(d.governance.address, "GovernanceActionScheduled", [...common, b.window.notBefore,
        b.window.expiresAfter, b.nonce, o.caller, b.window.reasonHash, b.window.reasonURI, b.window.manifestHash]);
      if (b.plan.kind === "freeze") {
        const commitment = hash((await read(p, d.governance.address, "terminalFreezeGuardianConfigCommitment", [b.actionId], tag))[0]);
        const committed = one(d.governance.address, "TerminalFreezeGuardianConfigCommitted", [1n, b.actionId, commitment]);
        const memberships = found(d.governance.address, "TerminalFreezeActionMembershipUpdated")
          .filter(v => same(v.args[2], b.actionId) && v.args[4] === true);
        if (memberships.length !== 1) throw Error("Expected original freeze membership append");
        const entry = memberships[0]!, a = entry.args;
        if (a[0] !== 1n || !same(a[1], b.plan.transition.scopeHash) || !same(a[3], o.caller) || a[5] !== 1n
          || a[7] !== b.window.notBefore || a[9] !== a[8] + 1n || a[9] > 64n) throw Error("Freeze membership fields differ");
        m.reference(entry.log, "TerminalFreezeActionMembershipUpdated");
        if (!(entry.log.index < committed && committed < scheduled)) throw Error("Freeze membership/commitment event order differs");
      }
      if (policyIndex <= scheduled) throw Error("Catalog validation event must follow scheduling");
    } else {
      if (state.status !== 3n || !same(state.executor, o.caller) || h.timestamp < b.window.notBefore || h.timestamp > b.window.expiresAfter) throw Error("Executed action/window differs");
      const executed = one(d.governance.address, "GovernanceActionExecuted", [...common, o.caller, b.window.manifestHash]);
      observed = await captureMintPhaseFreeze(p, d, c.scope, { blockTag: tag });
      if (b.plan.kind === "classifier") {
        const expected = { enabled: true, targetCodeHash: d.manager.codeHash, revision: c.selector.revision + 1n };
        equal(observed.selector, { ...expected, stateHash: mintPhaseFreezeSelectorStateHash(d.chainId, d.governance.address, d.manager.address, expected) }, "Classifier readback differs");
        const updated = one(d.governance.address, "FreezeSelectorUpdated", [1n, d.manager.address, SELECTOR, true,
          d.manager.codeHash, expected.revision, b.actionId]);
        if (updated >= executed) throw Error("Classifier event order differs");
      } else {
        equal(observed.phase.policy, c.phase.policy, "Receipt-block policy changed; exact state unavailable");
        equal(observed.phase.constraints, c.phase.constraints, "Freeze configuration changed");
        equal(observed.phase.grace, c.phase.grace, "Freeze changed grace");
        equal(observed.phase.snapshot.record, { policyHash: c.phase.snapshot.currentPolicyHash, configurationHash: c.phase.configurationHash }, "First freeze record differs");
        if (!observed.phase.frozen) throw Error("Freeze not retained");
        const ledger = one(d.ledger.address, "MintLedgerPhaseFrozen", [1n, d.manager.address, c.scope.collectionId, c.scope.phaseId,
          c.phase.snapshot.currentPolicyHash, c.phase.configurationHash]);
        const manager = one(d.manager.address, "MintPhaseFrozen", [1n, c.scope.collectionId, c.scope.phaseId, true, c.phase.snapshot.currentPolicyHash]);
        if (!(ledger < manager && manager < executed)) throw Error("Ledger/Manager/governance freeze order differs");
      }
      if (policyIndex <= executed) throw Error("Catalog validation event must follow execution");
    }
  }
  const events = await m.finish();
  return freeze({ operation: o, transactionHash: m.transactionHash, blockNumber: tag, blockHash: h.blockHash, events, observed,
    stateAttribution: "events identify this operation; exact end-of-block phase state required" });
}
/** Existing root copy receipt. Completion in the same block is outside this bounded incomplete-import profile. */
export async function inspectMintPhaseFreezeImportReceipt(p: ReceiptReader, input: MintPhaseFreezeImportOperation,
  supplied: ReceiptOptions): Promise<MintPhaseFreezeImportReceipt> {
  const o = importOperation(input), options = receiptOptions(supplied), c = o.capture, d = c.deployment;
  await originalImport(p, c);
  const m = await mined(p, d, o.caller, o.call, c.blockNumber, options), { tag, h } = m;
  const observed = await captureMintPhaseFreezeImport(p, d, c.scope, { blockTag: tag });
  for (const key of ["predecessorLedger", "predecessorManager", "successorManager", "snapshotBlock", "manifestHash"] as const) {
    equal(observed.commitment[key], c.commitment[key], "Import commitment identity changed");
  }
  if (observed.commitment.complete || observed.successorRetiredAt !== 0n) throw Error("Receipt profile requires incomplete nonretired successor");
  equal(observed.predecessorInventory, c.predecessorInventory, "Retired predecessor inventory changed");
  const expected = c.next.slice(0, Number(o.plan.maxCount));
  const events = m.found(d.ledger.address, "MintLedgerPhaseFreezeImported");
  if (events.length !== expected.length) throw Error("Copy event count differs; stale capture cannot be attributed");
  for (let n = 0; n < expected.length; n++) {
    const row = expected[n]!, a = row.predecessor, before = row.successor, event = events[n]!;
    equal(Array.from(event.args), [c.scope.importRoot, c.scope.predecessorManager.address, d.manager.address,
      a.scope.collectionId, a.scope.phaseId, a.snapshot.record.policyHash, before.snapshot.currentPolicyHash,
      a.snapshot.record.configurationHash], "Original copy event fields differ");
    m.reference(event.log, "MintLedgerPhaseFreezeImported");
    const after = await phase(p, d, d.manager.address, a.scope, tag);
    // A preexisting successor freeze retains its own first provenance, even when the event names its predecessor.
    const provenance = before.frozen ? before.snapshot.record.policyHash : a.snapshot.record.policyHash;
    equal(after.snapshot.record, { policyHash: provenance, configurationHash: a.snapshot.record.configurationHash }, "Copied first-freeze record differs");
    const ceiling = before.policy?.executors ?? a.executorCeiling;
    if (after.executorCeiling.some(v => !ceiling.some(e => same(e, v)))) throw Error("Copied executor ceiling expanded");
    if (!observed.successorInventory.some(v => v.collectionId === a.scope.collectionId && same(v.phaseId, a.scope.phaseId))) throw Error("Copied inventory identity absent");
  }
  const minimum = c.progress.freezes.imported + BigInt(expected.length);
  if (observed.progress.freezes.required !== c.progress.freezes.required || observed.progress.freezes.imported < minimum
    || observed.commitment.importedCounters < c.commitment.importedCounters || observed.commitment.importedNullifiers < c.commitment.importedNullifiers
    || observed.progress.definitions.imported < c.progress.definitions.imported || observed.progress.ancestry.imported < c.progress.ancestry.imported) throw Error("Import progress regressed");
  if (expected.length === 0) {
    const prior = await captureMintPhaseFreezeImport(p, d, c.scope, { blockTag: tag - 1 });
    if (prior.commitment.complete || prior.successorRetiredAt !== 0n || prior.progress.freezes.imported !== prior.progress.freezes.required) throw Error("Eventless copy needs prior-block completed-copy proof");
    equal(prior.commitment, observed.commitment, "Eventless copy commitment differs");
    equal(prior.progress.freezes, observed.progress.freezes, "Eventless copy progress differs");
  }
  const references = await m.finish();
  return freeze({ operation: o, transactionHash: m.transactionHash, blockNumber: tag, blockHash: h.blockHash, events: references, observed,
    copiedOrdinals: expected.map(v => v.ordinal), stateAttribution: "copy events identify this operation; progress is an end-of-block observation" });
}
