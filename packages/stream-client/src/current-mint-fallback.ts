import { AbiCoder, Interface, ZeroAddress, ZeroHash, getAddress, id, isHexString, keccak256, toUtf8Bytes } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import type { UnsignedCall } from "./client.js";
import {
  mintImportGovernanceTransition, prepareCounterDefinitionImport, prepareMintAncestryImport,
  prepareMintImportCommit, prepareMintImportCompletion, prepareMintStateImport, verifyMintContinuityArtifact,
  type MintContinuityArtifact, type MintStateImportBatch,
} from "./current-mint-continuity.js";

/** Original StreamMintFallbackPlan.Configuration; supplied pins are not live validation. */
export interface MintFallbackConfiguration {
  readonly chainId: bigint; readonly core: Address; readonly ledger: Address; readonly primary: Address;
  readonly fallbackManager: Address; readonly registry: Address; readonly governance: Address;
  readonly coreCodeHash: Hex; readonly ledgerCodeHash: Hex; readonly primaryCodeHash: Hex;
  readonly fallbackCodeHash: Hex; readonly registryCodeHash: Hex; readonly governanceCodeHash: Hex;
  readonly moduleVersion: Hex; readonly deploymentManifestHash: Hex; readonly moduleManifestHash: Hex;
  readonly moduleManifestURI: string; readonly moduleGasLimit: bigint; readonly recorder: Address; readonly recorderCodeHash: Hex;
}
export interface MintFallbackSnapshot { readonly snapshotBlock: bigint; readonly importRoot: Hex; readonly manifestHash: Hex }
export interface MintFallbackRegistration {
  readonly module: Address; readonly moduleType: Hex; readonly moduleVersion: Hex; readonly interfaceId: Hex;
  readonly moduleGasLimit: bigint; readonly expectedRuntimeCodeHash: Hex; readonly deploymentManifestHash: Hex;
  readonly moduleManifestHash: Hex; readonly moduleManifestURI: string;
}
export interface MintFallbackGovernanceCall {
  readonly target: Address; readonly value: bigint; readonly selector: Hex; readonly callDataHash: Hex;
  readonly scopeHash: Hex; readonly oldValueHash: Hex; readonly newValueHash: Hex;
}
export interface MintFallbackTransition { readonly scope: Hex; readonly oldHash: Hex; readonly newHash: Hex }
export interface MintFallbackRetirementClassifier {
  readonly enabled: boolean; readonly targetCodeHash: Hex; readonly revision: bigint; readonly stateHash: Hex;
}
export interface MintFallbackPointerState {
  readonly target: Address; readonly codeHash: Hex; readonly frozen: boolean; readonly moduleType: Hex;
  readonly interfaceId: Hex; readonly registry: Address; readonly registryStatus: bigint;
  readonly moduleManifestHash: Hex; readonly deploymentManifestHash: Hex; readonly revision: bigint;
}
export interface MintFallbackManifestModules {
  readonly revenueResolver: Address; readonly metadataRouter: Address; readonly collectionMetadata: Address;
  readonly entropyCoordinator: Address; readonly mintManager: Address; readonly mintLedger: Address;
  readonly artistRegistry: Address; readonly streamAdminsOrGovernance: Address; readonly artworkFinalityRegistry: Address;
  readonly moduleRegistry: Address; readonly stateExportPublisher: Address;
}
export interface MintFallbackManifestDiscovery {
  readonly eventCatalogHash: Hex; readonly compatibilityMatrixHash: Hex; readonly numericIdCatalogHash: Hex;
  readonly schemaCatalogHash: Hex; readonly canonicalizationCatalogHash: Hex; readonly specBundleHash: Hex;
  readonly reconstructionClientHash: Hex;
}
export interface MintFallbackManifestUpdate extends MintFallbackManifestDiscovery { readonly manifestHash: Hex; readonly manifestURI: string }
export interface MintFallbackManifestState {
  readonly manifestHash: Hex; readonly manifestURI: string; readonly modules: MintFallbackManifestModules;
  readonly discovery: MintFallbackManifestDiscovery; readonly revision: bigint; readonly payloadRoot: Address;
}
export interface MintFallbackActivation {
  readonly manifest: Address; readonly payloadRoot: Address; readonly update: MintFallbackManifestUpdate;
  readonly current: MintFallbackManifestState; readonly previousPointer: MintFallbackPointerState;
}
export interface MintFallbackRecoveryState {
  readonly collectionId: bigint; readonly serial: bigint; readonly lastTokenId: bigint; readonly nextSerial: bigint;
  readonly mintedEver: bigint; readonly supply: bigint; readonly tokenDataHash: Hex; readonly coordinator: Address;
}
export interface MintFallbackIncident {
  readonly tokenId: bigint; readonly operationId: Hex; readonly state: MintFallbackRecoveryState;
}
export type MintFallbackPlanKind = "retirement-classification" | "retirement" | "import-commit" | "copy-definitions"
  | "copy-ancestors" | "import-state" | "complete-import" | "activation" | "incident-activation"
  | "raw-import-commit" | "raw-copy-definitions" | "raw-copy-ancestors" | "raw-import-state" | "raw-complete-import";
export interface MintFallbackImportDescriptor {
  readonly importRoot: Hex; readonly counterCount: bigint; readonly nullifierCount: bigint; readonly descriptorProof: readonly Hex[];
}
export type MintFallbackRequest =
  | { readonly kind: "retirement-classification" | "retirement"; readonly classifier: MintFallbackRetirementClassifier }
  | { readonly kind: "import-commit" | "complete-import"; readonly artifact: MintContinuityArtifact }
  | { readonly kind: "copy-definitions" | "copy-ancestors"; readonly artifact: MintContinuityArtifact; readonly maxCount: bigint }
  | { readonly kind: "import-state"; readonly artifact: MintContinuityArtifact; readonly counterIndexes: readonly number[]; readonly nullifierIndexes: readonly number[] }
  | { readonly kind: "activation"; readonly activation: MintFallbackActivation }
  | { readonly kind: "incident-activation"; readonly activation: MintFallbackActivation; readonly incident: MintFallbackIncident }
  | { readonly kind: "raw-import-commit"; readonly snapshot: MintFallbackSnapshot }
  | { readonly kind: "raw-copy-definitions" | "raw-copy-ancestors"; readonly importRoot: Hex; readonly maxCount: bigint }
  | { readonly kind: "raw-import-state"; readonly batch: MintStateImportBatch }
  | { readonly kind: "raw-complete-import"; readonly descriptor: MintFallbackImportDescriptor };
/** Target-call composition only. Scheduling, policy admission and execution authority are separate. */
export interface MintFallbackCallPlan {
  readonly configuration: MintFallbackConfiguration; readonly kind: MintFallbackPlanKind;
  readonly actionClass: 0n | 1n | 3n; readonly actor: Address | null; readonly permissionless: boolean;
  readonly isolated: boolean; readonly calls: readonly MintFallbackGovernanceCall[];
  readonly data: readonly Hex[]; readonly targetCalls: readonly UnsignedCall[]; readonly factsVerified: false;
  readonly request: MintFallbackRequest;
}

export const MINT_FALLBACK_MANAGER_INTERFACE_ID = "0xb4074ed7" as Hex;
const MANAGER = id("MINT_MANAGER") as Hex, coder = AbiCoder.defaultAbiCoder();
const configKeys = ["chainId", "core", "ledger", "primary", "fallbackManager", "registry", "governance", "coreCodeHash", "ledgerCodeHash", "primaryCodeHash", "fallbackCodeHash", "registryCodeHash", "governanceCodeHash", "moduleVersion", "deploymentManifestHash", "moduleManifestHash", "moduleManifestURI", "moduleGasLimit", "recorder", "recorderCodeHash"];
const pointerKeys = ["target", "codeHash", "frozen", "moduleType", "interfaceId", "registry", "registryStatus", "moduleManifestHash", "deploymentManifestHash", "revision"];
const moduleKeys = ["revenueResolver", "metadataRouter", "collectionMetadata", "entropyCoordinator", "mintManager", "mintLedger", "artistRegistry", "streamAdminsOrGovernance", "artworkFinalityRegistry", "moduleRegistry", "stateExportPublisher"] as const;
const discoveryKeys = ["eventCatalogHash", "compatibilityMatrixHash", "numericIdCatalogHash", "schemaCatalogHash", "canonicalizationCatalogHash", "specBundleHash", "reconstructionClientHash"] as const;
const updateTuple = `tuple(bytes32 manifestHash,string manifestURI,${discoveryKeys.map(k => `bytes32 ${k}`).join(",")})`;
const importLeafTuple = "tuple(uint256 collectionId,bytes32 phaseId,bytes32 counterId,uint8 keyMode,bytes32 subjectBasis,bytes32 predecessorSubjectKey,uint64 value)";
const importBatchTuple = `tuple(bytes32 importRoot,${importLeafTuple}[] counters,bytes32[][] counterProofs,bytes32[] nullifiers,bytes32[][] nullifierProofs)`;
const governanceCallTuple = "tuple(address target,uint256 value,bytes4 selector,bytes32 callDataHash,bytes32 scopeHash,bytes32 oldValueHash,bytes32 newValueHash)";
const abi = new Interface([
  "function setTighteningCall(address,bytes4,bool)", "function retireLedgerWriter(address)",
  "function commitCounterImportRoot(address,address,address,uint64,bytes32,bytes32)",
  "function importCounterDefinitions(bytes32,uint256)", "function importMintAncestors(bytes32,uint256)",
  "function importMintState(bytes)", "function completeCounterImport(bytes32,uint64,uint64,bytes32[])",
  "function updateSatellitePointer(bytes32,address)", "function recoverPreparedMint(uint256,bytes32)",
  `function publishStreamSystemManifest(address,${updateTuple})`,
  "function publishGovernanceCallData(bytes[]) returns(address)",
  `function scheduleGovernanceBatch(uint8,${governanceCallTuple}[],bytes32,bytes32,bytes32,uint64,uint64,bytes32,string,bytes32) returns(bytes32)`,
  `function executeGovernanceBatch(bytes32,${governanceCallTuple}[],bytes[]) payable`,
]);
const pointerScopeDomain = "0xf4a381d3d4c51db07c19830799ea01c544326118ea1db1fb59d54af5f637bdbb";
const pointerStateDomain = "0x1fdde0a7122d0fc7c237e721e372e43082581dcc6bd2babca4e09bb1e6b3d043";
const manifestScopeDomain = "0xf73b4d7b4d260fce0823707f836fdf29a1767a2a2a9cfbce14ec8c5e49e47841";
const manifestStateDomain = "0x3764ccb415d0aac07f1bddb8d4841ad6d4c2f9b2fe7ce7d221c586bc056aaf60";
const classifierKind = id("6529STREAM_GOVERNANCE_CONFIG_TIGHTENING_CALL");
function exact(value: unknown, keys: readonly string[], label: string): void {
  if (value === null || typeof value !== "object" || Array.isArray(value)
    || Object.keys(value).sort().join(",") !== [...keys].sort().join(",")) throw Error(`${label} contains missing or unknown properties`);
}
function uint(value: unknown, bits: number, label: string, positive = false): bigint {
  if (typeof value !== "bigint" || value < (positive ? 1n : 0n) || value >= (1n << BigInt(bits))) throw Error(`${label} must fit ${positive ? "positive " : ""}uint${bits} bigint`);
  return value;
}
function address(value: unknown, allowZero = false): Address {
  if (typeof value !== "string") throw Error("Expected address"); const out = getAddress(value) as Address;
  if (!allowZero && out === ZeroAddress) throw Error("Expected nonzero address"); return out;
}
function hash(value: unknown, allowZero = true, size = 32): Hex {
  if (typeof value !== "string" || !isHexString(value, size) || (!allowZero && BigInt(value) === 0n)) throw Error(`Expected ${allowZero ? "" : "nonzero "}bytes${size}`);
  return value.toLowerCase() as Hex;
}
function bool(value: unknown): boolean { if (typeof value !== "boolean") throw Error("Expected boolean"); return value; }
function text(value: unknown, allowEmpty: boolean, max?: number): string {
  if (typeof value !== "string") throw Error("Expected UTF-8 string");
  for (const c of value) { const point = c.codePointAt(0)!; if (point >= 0xd800 && point <= 0xdfff) throw Error("Invalid UTF-8 scalar"); }
  const size = toUtf8Bytes(value).length;
  if ((!allowEmpty && size === 0) || (max !== undefined && size > max)) throw Error("Invalid string byte length"); return value;
}
function nextRevision(value: bigint): bigint { return uint(value + 1n, 64, "Next revision"); }
function digest(types: readonly string[], values: readonly unknown[]): Hex { return keccak256(coder.encode(types, values)) as Hex; }
function transition(scope: Hex, oldHash: Hex, newHash: Hex): MintFallbackTransition { return Object.freeze({ scope, oldHash, newHash }); }
export function normalizeMintFallbackConfiguration(input: MintFallbackConfiguration): MintFallbackConfiguration {
  exact(input, configKeys, "Fallback configuration");
  const c = { chainId: uint(input.chainId, 256, "Chain ID", true), core: address(input.core), ledger: address(input.ledger),
    primary: address(input.primary), fallbackManager: address(input.fallbackManager), registry: address(input.registry), governance: address(input.governance),
    coreCodeHash: hash(input.coreCodeHash, false), ledgerCodeHash: hash(input.ledgerCodeHash, false), primaryCodeHash: hash(input.primaryCodeHash, false),
    fallbackCodeHash: hash(input.fallbackCodeHash, false), registryCodeHash: hash(input.registryCodeHash, false), governanceCodeHash: hash(input.governanceCodeHash, false),
    moduleVersion: hash(input.moduleVersion, false), deploymentManifestHash: hash(input.deploymentManifestHash, false), moduleManifestHash: hash(input.moduleManifestHash, false),
    moduleManifestURI: text(input.moduleManifestURI, false), moduleGasLimit: uint(input.moduleGasLimit, 32, "Module gas limit"),
    recorder: address(input.recorder, true), recorderCodeHash: hash(input.recorderCodeHash) };
  if (c.primary === c.fallbackManager) throw Error("Primary and fallback Managers must differ");
  if ((c.recorder === ZeroAddress) !== (c.recorderCodeHash === ZeroHash)) throw Error("Recorder address/hash zero pair differs");
  return Object.freeze(c);
}
export function normalizeMintFallbackPointerState(input: MintFallbackPointerState): MintFallbackPointerState {
  exact(input, pointerKeys, "Pointer state");
  return Object.freeze({ target: address(input.target, true), codeHash: hash(input.codeHash), frozen: bool(input.frozen), moduleType: hash(input.moduleType),
    interfaceId: hash(input.interfaceId, true, 4), registry: address(input.registry, true), registryStatus: uint(input.registryStatus, 8, "Registry status"),
    moduleManifestHash: hash(input.moduleManifestHash), deploymentManifestHash: hash(input.deploymentManifestHash), revision: uint(input.revision, 64, "Pointer revision") });
}
/** Existing MINT_MANAGER registration, never a new Core pointer family. */
export function mintFallbackRegistration(configuration: MintFallbackConfiguration): MintFallbackRegistration {
  const c = normalizeMintFallbackConfiguration(configuration);
  return Object.freeze({ module: c.fallbackManager, moduleType: MANAGER, moduleVersion: c.moduleVersion,
    interfaceId: MINT_FALLBACK_MANAGER_INTERFACE_ID, moduleGasLimit: c.moduleGasLimit, expectedRuntimeCodeHash: c.fallbackCodeHash,
    deploymentManifestHash: c.deploymentManifestHash, moduleManifestHash: c.moduleManifestHash, moduleManifestURI: c.moduleManifestURI });
}
export function normalizeMintFallbackManifestModules(input: MintFallbackManifestModules): MintFallbackManifestModules {
  exact(input, moduleKeys, "Manifest modules"); return Object.freeze(Object.fromEntries(moduleKeys.map(k => [k, address(input[k], true)]))) as unknown as MintFallbackManifestModules;
}
export function normalizeMintFallbackManifestDiscovery(input: MintFallbackManifestDiscovery): MintFallbackManifestDiscovery {
  exact(input, discoveryKeys, "Manifest discovery"); return Object.freeze(Object.fromEntries(discoveryKeys.map(k => [k, hash(input[k])])) ) as unknown as MintFallbackManifestDiscovery;
}
export function normalizeMintFallbackManifestUpdate(input: MintFallbackManifestUpdate): MintFallbackManifestUpdate {
  exact(input, ["manifestHash", "manifestURI", ...discoveryKeys], "Manifest update");
  return Object.freeze({ manifestHash: hash(input.manifestHash, false), manifestURI: text(input.manifestURI, false, 2048),
    ...Object.fromEntries(discoveryKeys.map(k => [k, hash(input[k], false)])) }) as MintFallbackManifestUpdate;
}
export function normalizeMintFallbackManifestState(input: MintFallbackManifestState): MintFallbackManifestState {
  exact(input, ["manifestHash", "manifestURI", "modules", "discovery", "revision", "payloadRoot"], "Manifest state");
  return Object.freeze({ manifestHash: hash(input.manifestHash), manifestURI: text(input.manifestURI, true, 2048), modules: normalizeMintFallbackManifestModules(input.modules),
    discovery: normalizeMintFallbackManifestDiscovery(input.discovery), revision: uint(input.revision, 64, "Manifest revision"), payloadRoot: address(input.payloadRoot, true) });
}
export function normalizeMintFallbackActivation(input: MintFallbackActivation): MintFallbackActivation {
  exact(input, ["manifest", "payloadRoot", "update", "current", "previousPointer"], "Activation");
  return Object.freeze({ manifest: address(input.manifest), payloadRoot: address(input.payloadRoot), update: normalizeMintFallbackManifestUpdate(input.update),
    current: normalizeMintFallbackManifestState(input.current), previousPointer: normalizeMintFallbackPointerState(input.previousPointer) });
}
export function normalizeMintFallbackRecoveryState(input: MintFallbackRecoveryState): MintFallbackRecoveryState {
  exact(input, ["collectionId", "serial", "lastTokenId", "nextSerial", "mintedEver", "supply", "tokenDataHash", "coordinator"], "Recovery state");
  return Object.freeze({ collectionId: uint(input.collectionId, 256, "Collection ID", true), serial: uint(input.serial, 256, "Collection serial", true),
    lastTokenId: uint(input.lastTokenId, 256, "Last allocated ID"), nextSerial: uint(input.nextSerial, 256, "Next serial"),
    mintedEver: uint(input.mintedEver, 256, "Minted ever"), supply: uint(input.supply, 256, "Supply"), tokenDataHash: hash(input.tokenDataHash), coordinator: address(input.coordinator, true) });
}
export function normalizeMintFallbackIncident(input: MintFallbackIncident): MintFallbackIncident {
  exact(input, ["tokenId", "operationId", "state"], "Incident");
  return Object.freeze({ tokenId: uint(input.tokenId, 256, "Token ID", true), operationId: hash(input.operationId, false), state: normalizeMintFallbackRecoveryState(input.state) });
}
export function normalizeMintFallbackRetirementClassifier(input: MintFallbackRetirementClassifier): MintFallbackRetirementClassifier {
  exact(input, ["enabled", "targetCodeHash", "revision", "stateHash"], "Retirement classifier");
  return Object.freeze({ enabled: bool(input.enabled), targetCodeHash: hash(input.targetCodeHash), revision: uint(input.revision, 64, "Classifier revision"), stateHash: hash(input.stateHash) });
}
function classifierState(c: MintFallbackConfiguration, enabled: boolean, codeHash: Hex, revision: bigint): Hex {
  return digest(["bytes32", "uint256", "address", "bytes32", "address", "bytes4", "bool", "bytes32", "uint64"],
    [id("6529STREAM_GOVERNANCE_CONFIG_STATE_V1"), c.chainId, c.governance, classifierKind, c.ledger, abi.getFunction("retireLedgerWriter")!.selector, enabled, codeHash, revision]);
}
export function mintFallbackRetirementClassificationTransition(configuration: MintFallbackConfiguration, input: MintFallbackRetirementClassifier): MintFallbackTransition {
  const c = normalizeMintFallbackConfiguration(configuration), current = normalizeMintFallbackRetirementClassifier(input);
  if (current.enabled) throw Error("Retirement classifier must be disabled before isolated admission");
  if (current.stateHash !== classifierState(c, current.enabled, current.targetCodeHash, current.revision)) throw Error("Classifier state hash differs from supplied state");
  const scope = digest(["bytes32", "uint256", "address", "bytes32", "address", "bytes4"],
    [id("6529STREAM_GOVERNANCE_CONFIG_SCOPE_V1"), c.chainId, c.governance, classifierKind, c.ledger, abi.getFunction("retireLedgerWriter")!.selector]);
  return transition(scope, current.stateHash, classifierState(c, true, c.ledgerCodeHash, nextRevision(current.revision)));
}
export function mintFallbackRecoveryTransition(configuration: MintFallbackConfiguration, tokenId: bigint, operationId: Hex, input: MintFallbackRecoveryState): MintFallbackTransition {
  const c = normalizeMintFallbackConfiguration(configuration), s = normalizeMintFallbackRecoveryState(input);
  const scope = digest(["bytes32", "uint256", "address", "address", "uint256", "bytes32"],
    [id("6529STREAM_MINT_FALLBACK_RECOVERY_SCOPE_V1"), c.chainId, c.core, c.fallbackManager, uint(tokenId, 256, "Token ID", true), hash(operationId, false)]);
  const retained = digest(Array(6).fill("uint256"), [s.collectionId, s.serial, s.lastTokenId, s.nextSerial, s.mintedEver, s.supply]);
  const types = ["bytes32", "bytes32", "bool", "bytes32", "bytes32", "address"], domain = id("6529STREAM_MINT_FALLBACK_RECOVERY_STATE_V1");
  return transition(scope, digest(types, [domain, scope, true, retained, s.tokenDataHash, s.coordinator]),
    digest(types, [domain, scope, false, retained, keccak256("0x"), ZeroAddress]));
}
export function mintFallbackPointerTransition(configuration: MintFallbackConfiguration, previous: MintFallbackPointerState, next: MintFallbackPointerState): MintFallbackTransition {
  const c = normalizeMintFallbackConfiguration(configuration), before = normalizeMintFallbackPointerState(previous), after = normalizeMintFallbackPointerState(next);
  const scope = digest(["bytes32", "uint256", "address", "bytes32"], [pointerScopeDomain, c.chainId, c.core, MANAGER]);
  const state = (p: MintFallbackPointerState) => digest(["bytes32", "bytes32", "address", "bytes32", "bool", "bytes32", "bytes4", "address", "uint8", "bytes32", "bytes32", "uint64"],
    [pointerStateDomain, scope, p.target, p.codeHash, p.frozen, p.moduleType, p.interfaceId, p.registry, p.registryStatus, p.moduleManifestHash, p.deploymentManifestHash, p.revision]);
  return transition(scope, state(before), state(after));
}
export function mintFallbackNextPointer(configuration: MintFallbackConfiguration, previous: MintFallbackPointerState): MintFallbackPointerState {
  const c = normalizeMintFallbackConfiguration(configuration), p = normalizeMintFallbackPointerState(previous);
  if (p.target !== c.primary || p.codeHash !== c.primaryCodeHash || p.frozen) throw Error("Primary Manager must be selected at its runtime pin with an unfrozen pointer");
  return Object.freeze({ target: c.fallbackManager, codeHash: c.fallbackCodeHash, frozen: false, moduleType: MANAGER,
    interfaceId: MINT_FALLBACK_MANAGER_INTERFACE_ID, registry: c.registry, registryStatus: 1n,
    moduleManifestHash: c.moduleManifestHash, deploymentManifestHash: c.deploymentManifestHash, revision: nextRevision(p.revision) });
}
function modulesHash(modules: MintFallbackManifestModules): Hex { return digest(moduleKeys.map(() => "address"), moduleKeys.map(k => modules[k])); }
function discoveryHash(discovery: MintFallbackManifestDiscovery): Hex { return digest(discoveryKeys.map(() => "bytes32"), discoveryKeys.map(k => discovery[k])); }
export function mintFallbackManifestTransition(configuration: MintFallbackConfiguration, activation: MintFallbackActivation): MintFallbackTransition {
  const c = normalizeMintFallbackConfiguration(configuration), a = normalizeMintFallbackActivation(activation), before = a.current, m = before.modules;
  if (m.mintManager !== c.primary || m.mintLedger !== c.ledger || m.moduleRegistry !== c.registry || m.streamAdminsOrGovernance !== c.governance) throw Error("Current manifest does not bind this primary, Ledger, registry and Executor");
  const scope = digest(["bytes32", "uint256", "address"], [manifestScopeDomain, c.chainId, a.manifest]);
  const state = (manifestHash: Hex, uri: string, payload: Address, modules: MintFallbackManifestModules, discovery: MintFallbackManifestDiscovery, revision: bigint) =>
    digest(["bytes32", "bytes32", "bytes32", "bytes32", "address", "bytes32", "bytes32", "uint64"],
      [manifestStateDomain, scope, manifestHash, keccak256(toUtf8Bytes(uri)), payload, modulesHash(modules), discoveryHash(discovery), revision]);
  return transition(scope, state(before.manifestHash, before.manifestURI, before.payloadRoot, m, before.discovery, before.revision),
    state(a.update.manifestHash, a.update.manifestURI, a.payloadRoot, { ...m, mintManager: c.fallbackManager }, a.update, nextRevision(before.revision)));
}
function targetCall(to: Address, method: string, args: readonly unknown[]): UnsignedCall { return Object.freeze({ to, value: 0n, data: abi.encodeFunctionData(method, args) as Hex }); }
function governed(call: UnsignedCall, t?: MintFallbackTransition): MintFallbackGovernanceCall {
  const dataHash = keccak256(call.data) as Hex;
  return Object.freeze({ target: call.to, value: 0n, selector: call.data.slice(0, 10) as Hex, callDataHash: dataHash,
    scopeHash: t?.scope ?? digest(["address", "bytes"], [call.to, call.data]), oldValueHash: t?.oldHash ?? ZeroHash as Hex, newValueHash: t?.newHash ?? dataHash });
}
function freeze<T>(value: T): T {
  if (Array.isArray(value)) return Object.freeze(value.map(item => freeze(item))) as T;
  if (value !== null && typeof value === "object") return Object.freeze(Object.fromEntries(Object.entries(value).map(([key, item]) => [key, freeze(item)]))) as T;
  return value;
}
function plan(c: MintFallbackConfiguration, request: MintFallbackRequest, actionClass: 0n | 1n | 3n, items: readonly (readonly [UnsignedCall, MintFallbackTransition?])[], permissionless = false, isolated = false): MintFallbackCallPlan {
  const targetCalls = Object.freeze(items.map(([call]) => Object.freeze({ ...call })));
  return Object.freeze({ configuration: c, kind: request.kind, actionClass, actor: permissionless ? null : c.governance, permissionless, isolated,
    calls: Object.freeze(items.map(([call, t]) => governed(call, t))), data: Object.freeze(targetCalls.map(call => call.data)), targetCalls, factsVerified: false, request: freeze(request) });
}
export function mintFallbackRetirementClassificationCall(configuration: MintFallbackConfiguration, current: MintFallbackRetirementClassifier): MintFallbackCallPlan {
  const c = normalizeMintFallbackConfiguration(configuration), t = mintFallbackRetirementClassificationTransition(c, current);
  return plan(c, { kind: "retirement-classification", classifier: normalizeMintFallbackRetirementClassifier(current) }, 1n, [[targetCall(c.governance, "setTighteningCall", [c.ledger, abi.getFunction("retireLedgerWriter")!.selector, true]), t]], false, true);
}
export function mintFallbackRetirementCall(configuration: MintFallbackConfiguration, input: MintFallbackRetirementClassifier): MintFallbackCallPlan {
  const c = normalizeMintFallbackConfiguration(configuration), classifier = normalizeMintFallbackRetirementClassifier(input);
  if (!classifier.enabled || classifier.targetCodeHash !== c.ledgerCodeHash || classifier.stateHash !== classifierState(c, true, classifier.targetCodeHash, classifier.revision)) throw Error("Retirement requires the exact enabled Ledger tightening classification");
  return plan(c, { kind: "retirement", classifier }, 0n, [[targetCall(c.ledger, "retireLedgerWriter", [c.primary])]]);
}
function artifact(c: MintFallbackConfiguration, input: MintContinuityArtifact): MintContinuityArtifact {
  const a = verifyMintContinuityArtifact(input), p = a.coordinates;
  if (p.chainId !== c.chainId || address(p.successorLedger) !== c.ledger || address(p.predecessorLedger) !== c.ledger
    || address(p.predecessorManager) !== c.primary || address(p.successorManager) !== c.fallbackManager || p.snapshotBlock === 0n) throw Error("Continuity artifact must bind this exact same-Ledger primary-to-fallback pair and positive snapshot");
  return a;
}
export function mintFallbackImportCommitCall(configuration: MintFallbackConfiguration, input: MintContinuityArtifact): MintFallbackCallPlan {
  const c = normalizeMintFallbackConfiguration(configuration), a = artifact(c, input), prepared = prepareMintImportCommit(a);
  return plan(c, { kind: "import-commit", artifact: a }, 1n, [[prepared.targetCall, mintImportGovernanceTransition({ ...a.coordinates, importRoot: a.importRoot, manifestHash: a.manifestHash })]]);
}
export function mintFallbackCopyDefinitionsCall(configuration: MintFallbackConfiguration, input: MintContinuityArtifact, maxCount: bigint): MintFallbackCallPlan {
  const c = normalizeMintFallbackConfiguration(configuration), a = artifact(c, input); return plan(c, { kind: "copy-definitions", artifact: a, maxCount }, 1n, [[prepareCounterDefinitionImport(a, maxCount).call]], true);
}
export function mintFallbackCopyAncestorsCall(configuration: MintFallbackConfiguration, input: MintContinuityArtifact, maxCount: bigint): MintFallbackCallPlan {
  const c = normalizeMintFallbackConfiguration(configuration), a = artifact(c, input); return plan(c, { kind: "copy-ancestors", artifact: a, maxCount }, 1n, [[prepareMintAncestryImport(a, maxCount).call]], true);
}
export function mintFallbackImportStateCall(configuration: MintFallbackConfiguration, input: MintContinuityArtifact, counterIndexes: readonly number[], nullifierIndexes: readonly number[]): MintFallbackCallPlan {
  const c = normalizeMintFallbackConfiguration(configuration), a = artifact(c, input); return plan(c, { kind: "import-state", artifact: a, counterIndexes, nullifierIndexes }, 1n, [[prepareMintStateImport(a, c.governance, counterIndexes, nullifierIndexes).call]]);
}
export function mintFallbackCompleteImportCall(configuration: MintFallbackConfiguration, input: MintContinuityArtifact): MintFallbackCallPlan {
  const c = normalizeMintFallbackConfiguration(configuration), a = artifact(c, input); return plan(c, { kind: "complete-import", artifact: a }, 1n, [[prepareMintImportCompletion(a).call]], true);
}
function activationItems(c: MintFallbackConfiguration, a: MintFallbackActivation): readonly (readonly [UnsignedCall, MintFallbackTransition])[] {
  const next = mintFallbackNextPointer(c, a.previousPointer), pointer = mintFallbackPointerTransition(c, a.previousPointer, next);
  return [[targetCall(c.core, "updateSatellitePointer", [MANAGER, c.fallbackManager]), pointer],
    [targetCall(a.manifest, "publishStreamSystemManifest", [a.payloadRoot, a.update]), mintFallbackManifestTransition(c, a)]];
}
export function mintFallbackActivationCalls(configuration: MintFallbackConfiguration, input: MintFallbackActivation): MintFallbackCallPlan {
  const c = normalizeMintFallbackConfiguration(configuration), a = normalizeMintFallbackActivation(input);
  return plan(c, { kind: "activation", activation: a }, 3n, activationItems(c, a));
}
export function mintFallbackIncidentActivationCalls(configuration: MintFallbackConfiguration, input: MintFallbackActivation, incident: MintFallbackIncident): MintFallbackCallPlan {
  const c = normalizeMintFallbackConfiguration(configuration), a = normalizeMintFallbackActivation(input), i = normalizeMintFallbackIncident(incident), normal = activationItems(c, a);
  return plan(c, { kind: "incident-activation", activation: a, incident: i }, 3n, [normal[0]!, [targetCall(c.fallbackManager, "recoverPreparedMint", [i.tokenId, i.operationId]), mintFallbackRecoveryTransition(c, i.tokenId, i.operationId, i.state)], normal[1]!]);
}

export function normalizeMintFallbackSnapshot(input: MintFallbackSnapshot): MintFallbackSnapshot {
  exact(input, ["snapshotBlock", "importRoot", "manifestHash"], "Import snapshot");
  return Object.freeze({ snapshotBlock: uint(input.snapshotBlock, 64, "Snapshot block", true), importRoot: hash(input.importRoot, false), manifestHash: hash(input.manifestHash, false) });
}
function proof(input: readonly Hex[]): readonly Hex[] { if (!Array.isArray(input)) throw Error("Expected descriptor or leaf proof array"); return Object.freeze(input.map(p => hash(p))); }
export function normalizeMintFallbackImportBatch(input: MintStateImportBatch): MintStateImportBatch {
  exact(input, ["importRoot", "counters", "counterProofs", "nullifiers", "nullifierProofs"], "Import batch");
  if (![input.counters, input.counterProofs, input.nullifiers, input.nullifierProofs].every(Array.isArray)
    || input.counters.length + input.nullifiers.length === 0 || input.counters.length + input.nullifiers.length > 32
    || input.counters.length !== input.counterProofs.length || input.nullifiers.length !== input.nullifierProofs.length) throw Error("Import batch requires 1..32 leaves and matching proofs");
  const counters = input.counters.map(leaf => {
    exact(leaf, ["collectionId", "phaseId", "counterId", "keyMode", "subjectBasis", "predecessorSubjectKey", "value"], "Import counter");
    return Object.freeze({ collectionId: uint(leaf.collectionId, 256, "Counter collection"), phaseId: hash(leaf.phaseId), counterId: hash(leaf.counterId),
      keyMode: uint(leaf.keyMode, 8, "Counter key mode"), subjectBasis: hash(leaf.subjectBasis), predecessorSubjectKey: hash(leaf.predecessorSubjectKey), value: uint(leaf.value, 64, "Counter value") });
  });
  return Object.freeze({ importRoot: hash(input.importRoot, false), counters: Object.freeze(counters), counterProofs: Object.freeze(input.counterProofs.map(proof)),
    nullifiers: Object.freeze(input.nullifiers.map(n => hash(n))), nullifierProofs: Object.freeze(input.nullifierProofs.map(proof)) });
}
export function normalizeMintFallbackImportDescriptor(input: MintFallbackImportDescriptor): MintFallbackImportDescriptor {
  exact(input, ["importRoot", "counterCount", "nullifierCount", "descriptorProof"], "Import descriptor");
  return Object.freeze({ importRoot: hash(input.importRoot, false), counterCount: uint(input.counterCount, 64, "Descriptor counter count"),
    nullifierCount: uint(input.nullifierCount, 64, "Descriptor nullifier count"), descriptorProof: proof(input.descriptorProof) });
}
/** Original external-producer route: structural encoding does not prove descriptor completeness. */
export function mintFallbackRawImportCommitCall(configuration: MintFallbackConfiguration, input: MintFallbackSnapshot): MintFallbackCallPlan {
  const c = normalizeMintFallbackConfiguration(configuration), s = normalizeMintFallbackSnapshot(input);
  const t = mintImportGovernanceTransition({ chainId: c.chainId, successorLedger: c.ledger, predecessorLedger: c.ledger,
    predecessorManager: c.primary, successorManager: c.fallbackManager, ...s });
  return plan(c, { kind: "raw-import-commit", snapshot: s }, 1n, [[targetCall(c.ledger, "commitCounterImportRoot", [c.ledger, c.primary, c.fallbackManager, s.snapshotBlock, s.importRoot, s.manifestHash]), t]]);
}
function rawCopy(configuration: MintFallbackConfiguration, importRoot: Hex, maxCount: bigint, kind: "raw-copy-definitions" | "raw-copy-ancestors"): MintFallbackCallPlan {
  const c = normalizeMintFallbackConfiguration(configuration), root = hash(importRoot, false), count = uint(maxCount, 256, "Copy bound", true);
  if (count > 32n) throw Error("Copy bound must be 1..32");
  return plan(c, { kind, importRoot: root, maxCount: count }, 1n, [[targetCall(c.ledger, kind === "raw-copy-definitions" ? "importCounterDefinitions" : "importMintAncestors", [root, count])]], true);
}
export function mintFallbackRawCopyDefinitionsCall(c: MintFallbackConfiguration, root: Hex, maxCount: bigint): MintFallbackCallPlan { return rawCopy(c, root, maxCount, "raw-copy-definitions"); }
export function mintFallbackRawCopyAncestorsCall(c: MintFallbackConfiguration, root: Hex, maxCount: bigint): MintFallbackCallPlan { return rawCopy(c, root, maxCount, "raw-copy-ancestors"); }
export function mintFallbackRawImportStateCall(configuration: MintFallbackConfiguration, input: MintStateImportBatch): MintFallbackCallPlan {
  const c = normalizeMintFallbackConfiguration(configuration), batch = normalizeMintFallbackImportBatch(input);
  return plan(c, { kind: "raw-import-state", batch }, 1n, [[targetCall(c.fallbackManager, "importMintState", [coder.encode([importBatchTuple], [batch])])]]);
}
export function mintFallbackRawCompleteImportCall(configuration: MintFallbackConfiguration, input: MintFallbackImportDescriptor): MintFallbackCallPlan {
  const c = normalizeMintFallbackConfiguration(configuration), d = normalizeMintFallbackImportDescriptor(input);
  return plan(c, { kind: "raw-complete-import", descriptor: d }, 1n, [[targetCall(c.ledger, "completeCounterImport", [d.importRoot, d.counterCount, d.nullifierCount, d.descriptorProof])]], true);
}
export function prepareMintFallbackPlan(c: MintFallbackConfiguration, request: MintFallbackRequest): MintFallbackCallPlan {
  if (!request || typeof request !== "object") throw Error("Expected fallback request");
  const keys: Record<MintFallbackPlanKind, readonly string[]> = {
    "retirement-classification": ["classifier"], retirement: ["classifier"], "import-commit": ["artifact"], "complete-import": ["artifact"],
    "copy-definitions": ["artifact", "maxCount"], "copy-ancestors": ["artifact", "maxCount"], "import-state": ["artifact", "counterIndexes", "nullifierIndexes"],
    activation: ["activation"], "incident-activation": ["activation", "incident"], "raw-import-commit": ["snapshot"],
    "raw-copy-definitions": ["importRoot", "maxCount"], "raw-copy-ancestors": ["importRoot", "maxCount"], "raw-import-state": ["batch"], "raw-complete-import": ["descriptor"],
  };
  if (!Object.hasOwn(keys, request.kind)) throw Error("Unsupported fallback request kind"); exact(request, ["kind", ...keys[request.kind]], "Fallback request");
  switch (request.kind) {
    case "retirement-classification": return mintFallbackRetirementClassificationCall(c, request.classifier);
    case "retirement": return mintFallbackRetirementCall(c, request.classifier);
    case "import-commit": return mintFallbackImportCommitCall(c, request.artifact);
    case "copy-definitions": return mintFallbackCopyDefinitionsCall(c, request.artifact, request.maxCount);
    case "copy-ancestors": return mintFallbackCopyAncestorsCall(c, request.artifact, request.maxCount);
    case "import-state": return mintFallbackImportStateCall(c, request.artifact, request.counterIndexes, request.nullifierIndexes);
    case "complete-import": return mintFallbackCompleteImportCall(c, request.artifact);
    case "activation": return mintFallbackActivationCalls(c, request.activation);
    case "incident-activation": return mintFallbackIncidentActivationCalls(c, request.activation, request.incident);
    case "raw-import-commit": return mintFallbackRawImportCommitCall(c, request.snapshot);
    case "raw-copy-definitions": return mintFallbackRawCopyDefinitionsCall(c, request.importRoot, request.maxCount);
    case "raw-copy-ancestors": return mintFallbackRawCopyAncestorsCall(c, request.importRoot, request.maxCount);
    case "raw-import-state": return mintFallbackRawImportStateCall(c, request.batch);
    case "raw-complete-import": return mintFallbackRawCompleteImportCall(c, request.descriptor);
  }
}
function canonical(value: unknown): string {
  return JSON.stringify(value, (_, item: unknown) => typeof item === "bigint" ? { uint: item.toString() }
    : item !== null && typeof item === "object" && !Array.isArray(item) ? Object.fromEntries(Object.entries(item).sort(([a], [b]) => a.localeCompare(b))) : item);
}
export function normalizeMintFallbackPlan(input: MintFallbackCallPlan): MintFallbackCallPlan {
  exact(input, ["configuration", "kind", "actionClass", "actor", "permissionless", "isolated", "calls", "data", "targetCalls", "factsVerified", "request"], "Fallback plan");
  const rebuilt = prepareMintFallbackPlan(input.configuration, input.request);
  if (canonical(input) !== canonical(rebuilt)) throw Error("Fallback plan differs from canonical call reconstruction"); return rebuilt;
}

export interface MintFallbackGovernanceWindow {
  readonly notBefore: bigint; readonly expiresAfter: bigint; readonly reasonHash: Hex;
  readonly reasonURI: string; readonly manifestHash: Hex;
}
export interface MintFallbackGovernanceBatch {
  readonly plan: MintFallbackCallPlan; readonly nonce: bigint; readonly window: MintFallbackGovernanceWindow;
  readonly callsHash: Hex; readonly scopeHash: Hex; readonly oldValueHash: Hex; readonly newValueHash: Hex;
  readonly actionId: Hex; readonly publicationKey: Hex; readonly publicationCall: UnsignedCall;
  readonly scheduleCall: UnsignedCall; readonly executionCall: UnsignedCall;
}
export function normalizeMintFallbackGovernanceWindow(input: MintFallbackGovernanceWindow): MintFallbackGovernanceWindow {
  exact(input, ["notBefore", "expiresAfter", "reasonHash", "reasonURI", "manifestHash"], "Governance window");
  const notBefore = uint(input.notBefore, 64, "Not before"), expiresAfter = uint(input.expiresAfter, 64, "Expires after");
  if (expiresAfter <= notBefore) throw Error("Governance expiry must follow notBefore");
  return Object.freeze({ notBefore, expiresAfter, reasonHash: hash(input.reasonHash), reasonURI: text(input.reasonURI, true), manifestHash: hash(input.manifestHash) });
}
/** Original Executor batch identities; live time floors, publication and actor admission remain unverified. */
export function mintFallbackGovernanceBatch(input: MintFallbackCallPlan, nonce: bigint, window: MintFallbackGovernanceWindow): MintFallbackGovernanceBatch {
  const plan = normalizeMintFallbackPlan(input), n = uint(nonce, 256, "Governance nonce"), w = normalizeMintFallbackGovernanceWindow(window), c = plan.configuration;
  const callsHash = digest(["bytes32", `${governanceCallTuple}[]`], ["0x10f09566fb70f7947b61639c2a53b3aec872069a8b46edd08ba14eb2b5942b70", plan.calls]);
  const aggregate = (domain: string, key: "scopeHash" | "oldValueHash" | "newValueHash") => digest(["bytes32", "bytes32", "bytes32[]"], [domain, callsHash, plan.calls.map(call => call[key])]);
  const scopeHash = aggregate("0x6cfd5dfd67f064adac45602c05057edddda810734779c0ebe11b447e6985e31c", "scopeHash");
  const oldValueHash = aggregate("0xc5029f937b44065c2ad92d9253e07f06117567480206189fcc1409d5509222b7", "oldValueHash");
  const newValueHash = aggregate("0xce958009248d20d9574439fa374bc00c142940af2b496896b5bdbc00b882e98b", "newValueHash");
  // ActionIdentity is wholly static, so concatenating its ABI encoding gives these exact words.
  const actionId = digest(["bytes32", "uint256", "address", "uint8", "bytes32", "bytes32", "bytes32", "bytes32", "uint256", "uint64", "uint64", "bytes32", "bytes32"],
    ["0x214cd728538bb3775a7106caff5c761bace11866a984d4a4d97a98f51971ac4b", c.chainId, c.governance,
      plan.actionClass, callsHash, scopeHash, oldValueHash, newValueHash, n, w.notBefore, w.expiresAfter, w.reasonHash, w.manifestHash]);
  const publicationKey = keccak256(`0x${plan.calls.map(call => call.callDataHash.slice(2)).join("")}`) as Hex;
  return Object.freeze({ plan, nonce: n, window: w, callsHash, scopeHash, oldValueHash, newValueHash, actionId, publicationKey,
    publicationCall: targetCall(c.governance, "publishGovernanceCallData", [plan.data]),
    scheduleCall: targetCall(c.governance, "scheduleGovernanceBatch", [plan.actionClass, plan.calls, scopeHash, oldValueHash, newValueHash, w.notBefore, w.expiresAfter, w.reasonHash, w.reasonURI, w.manifestHash]),
    executionCall: targetCall(c.governance, "executeGovernanceBatch", [actionId, plan.calls, plan.data]) });
}
export function normalizeMintFallbackGovernanceBatch(input: MintFallbackGovernanceBatch): MintFallbackGovernanceBatch {
  exact(input, ["plan", "nonce", "window", "callsHash", "scopeHash", "oldValueHash", "newValueHash", "actionId", "publicationKey", "publicationCall", "scheduleCall", "executionCall"], "Governance batch");
  const rebuilt = mintFallbackGovernanceBatch(input.plan, input.nonce, input.window);
  if (canonical(input) !== canonical(rebuilt)) throw Error("Governance batch differs from original identity reconstruction"); return rebuilt;
}
