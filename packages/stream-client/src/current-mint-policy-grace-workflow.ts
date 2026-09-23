import { AbiCoder, Interface, ZeroAddress, ZeroHash, getAddress, id, isHexString, keccak256, toUtf8Bytes } from "ethers";
import type { Provider } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import type { UnsignedCall } from "./client.js";
import {
  normalizeMintPolicySnapshot, prepareMintPolicyGraceChange, normalizeMintPolicyGracePlan,
  mintPolicyGraceGovernanceBatch, normalizeMintPolicyGraceGovernanceBatch, assertMintPolicyGraceDeadline
} from "./current-mint-policy-grace.js";
import type { MintPolicySnapshot, MintPolicyGracePlan, MintPolicyGraceRequest, MintPolicyGraceGovernanceBatch, MintPolicyGraceGovernanceWindow } from "./current-mint-policy-grace.js";

export interface MintPolicyGraceCodePin { readonly address: Address; readonly codeHash: Hex }
export interface MintPolicyGraceDeployment {
  readonly chainId: bigint;
  readonly core: MintPolicyGraceCodePin;
  readonly manager: MintPolicyGraceCodePin;
  readonly ledger: MintPolicyGraceCodePin;
  readonly moduleRegistry: MintPolicyGraceCodePin;
  readonly governance: MintPolicyGraceCodePin;
  readonly artistRegistry: MintPolicyGraceCodePin;
  /** Reviewed Manager runtime capability; not discoverable from its unchanged ABI. Omitted means false. */
  readonly supportsDelegatedPolicyConsent?: boolean;
  /** Required only when the Artist facade retains a different original Manager domain. */
  readonly artistOrigin?: { readonly manager: MintPolicyGraceCodePin; readonly ledger: MintPolicyGraceCodePin };
}
export interface MintPolicyGraceScope {
  readonly collectionId: bigint;
  readonly phaseId: Hex;
  /** Caller-supplied inventory, proved by the original complete policy hash, not membership reads alone. */
  readonly executors: readonly Address[];
}
export interface MintPolicyGraceState {
  readonly previousPolicyHash: Hex;
  readonly previousPolicyRevision: bigint;
  readonly graceUntil: bigint;
}
export interface MintPolicyGraceCatalog {
  readonly candidateProfileHash: Hex;
  readonly catalogHash: Hex;
  readonly entryCount: bigint;
  readonly revision: bigint;
  readonly rowAdmission: "original-call-simulation-required";
}
export interface MintPolicyGraceCapture {
  readonly deployment: MintPolicyGraceDeployment;
  readonly scope: MintPolicyGraceScope;
  readonly snapshot: MintPolicySnapshot;
  readonly grace: MintPolicyGraceState;
  readonly blockNumber: number;
  readonly blockHash: Hex;
  readonly timestamp: bigint;
  readonly governanceNonce: bigint;
  readonly catalog: MintPolicyGraceCatalog;
  readonly captureHash: Hex;
}
export interface MintPolicyGraceArtistConsent {
  readonly artistRegistry: Address;
  readonly signingManager: Address;
  readonly consentMode: bigint;
  readonly consented: boolean;
  readonly evidenceHash: Hex;
  readonly registrationReady: boolean;
}
export interface MintPolicyGraceInspection {
  readonly capture: MintPolicyGraceCapture;
  readonly plan: MintPolicyGracePlan;
  readonly artistConsent: MintPolicyGraceArtistConsent | null;
  readonly inspectionHash: Hex;
}
export interface PreparedMintPolicyGraceGovernance {
  readonly inspection: MintPolicyGraceInspection;
  readonly proposer: Address;
  readonly batch: MintPolicyGraceGovernanceBatch;
}
export interface MintPolicyGraceOperation {
  readonly prepared: PreparedMintPolicyGraceGovernance;
  readonly stage: "publish" | "schedule" | "execute";
  readonly caller: Address;
  readonly call: UnsignedCall;
}
type Reader = Pick<Provider, "getNetwork" | "getCode" | "getBlock" | "call">;
type ReceiptReader = Reader & Pick<Provider, "getTransaction" | "getTransactionReceipt">;
const coder = AbiCoder.defaultAbiCoder();
const PHASE = "(bool paused,uint64 startTime,uint64 endTime,uint32 maxBatchQuantity,bytes32 configHash,bytes32 metadataHash)";
const GATE = "(address gate,bytes32 gateConfigHash,bytes32 gateCodehash,bytes32 gateMetadataHash,uint32 gateSemanticVersion,uint32 gateGasLimit)";
const COUNTER = "(bool enabled,uint8 keyMode,uint8 capMode,uint8 deltaMode,uint64 staticCap,uint64 staticIncrement,bytes32 counterConfigHash)";
const LEDGER_COUNTER = "(bool enabled,uint8 capMode,uint8 deltaMode,uint64 staticCap,uint64 staticIncrement,bytes32 counterConfigHash)";
const GOVERNANCE_CALL = "(address target,uint256 value,bytes4 selector,bytes32 callDataHash,bytes32 scopeHash,bytes32 oldValueHash,bytes32 newValueHash)";
const abi = new Interface([
  "function core() view returns(address)", "function mintLedger() view returns(address)",
  "function moduleRegistry() view returns(address)", "function governanceExecutor() view returns(address)",
  "function governanceAuthority() view returns(address)", "function owner() view returns(address)",
  "function mintManager() view returns(address)", "function supportsInterface(bytes4) view returns(bool)",
  "function isStreamMintManager() pure returns(bool)", "function isStreamMintLedger() pure returns(bool)",
  "function collectionExists(uint256) view returns(bool)",
  "function getSatellitePointer(bytes32) view returns(address target,bytes32 codeHash,bool frozen,bytes32 moduleType,bytes4 interfaceId,address registry,uint8 registryStatus,bytes32 moduleManifestHash,bytes32 deploymentManifestHash,uint64 revision)",
  `function phase(uint256,bytes32) view returns(bool exists,${PHASE} config)`,
  `function phaseGate(uint256,bytes32) view returns(${GATE})`,
  `function counterConfig(uint256,bytes32,bytes32) view returns(${COUNTER})`,
  "function phaseCounterIds(uint256,bytes32) view returns(bytes32[])",
  "function phaseExecutor(uint256,bytes32,address) view returns(bool)",
  "function phasePolicyHash(uint256,bytes32) view returns(bytes32)",
  "function phasePolicyGrace(uint256,bytes32) view returns(bytes32,uint64)",
  `function previewPhasePolicyHash(uint256,bytes32,${PHASE},${GATE},bytes32[],${COUNTER}[],address[]) view returns(bytes32)`,
  "function setPhaseExecutorWithGrace(uint256,bytes32,address,bool,uint64)",
  "function gasParameterInfo(bytes32) view returns(uint256 value,uint256 floor,uint8 failureClass,uint64 revision)",
  "function ledgerWriter(address) view returns(bool)", "function ledgerWriterRetiredAt(address) view returns(uint64)",
  "function registeredPhasePolicyHash(address,uint256,bytes32) view returns(bytes32)",
  `function registeredCounterPolicy(address,uint256,bytes32,bytes32) view returns(${LEDGER_COUNTER})`,
  "function policyGrace(address,uint256,bytes32) view returns(bytes32,uint64,uint64)",
  "function isCompletedMintDescendant(address,address,address) view returns(bool)",
  "function consentMode(uint256) view returns(uint8)",
  "function isPolicyConsented(uint256,bytes32,bytes32) view returns(bool,bytes32)",
  "function platformWorksDeclaration(uint256) view returns(bool,bytes32,uint64)",
  "function requireMintConsent(uint256,bytes32,bytes32) view",
  "function governanceNonce() view returns(uint256)",
  "function governanceActionPolicyState() view returns(bytes32 candidateProfileHash,bytes32 catalogHash,uint256 entryCount,uint64 revision)",
  "function isProposer(address) view returns(bool)", "function minimumDelay(uint8) pure returns(uint64)",
  "function publishedCallData(bytes32) view returns(address)",
  "function publishGovernanceCallData(bytes[]) returns(address)",
  `function scheduleGovernanceBatch(uint8,${GOVERNANCE_CALL}[],bytes32,bytes32,bytes32,uint64,uint64,bytes32,string,bytes32) returns(bytes32)`,
  `function executeGovernanceBatch(bytes32,${GOVERNANCE_CALL}[],bytes[]) payable`,
  "function governanceAction(bytes32) view returns((uint8 status,uint8 actionClass,address target,uint256 value,bytes4 selector,bytes32 callHash,bytes32 scopeHash,bytes32 oldValueHash,bytes32 newValueHash,uint64 notBefore,uint64 expiresAfter,address proposer,address executor,address canceller,address vetoer,bytes32 reasonHash,string reasonURI,bytes32 manifestHash))",
  "function scheduledCallData(bytes32) view returns(bytes[])", "function scheduledCallDataPointer(bytes32) view returns(address)",
  "event MintPhaseConsentRecorded(uint16 schemaVersion,uint256 indexed collectionId,bytes32 indexed phaseId,bytes32 indexed policyHash,uint8 consentMode,bytes32 consentEvidenceHash)",
  "event MintPhaseExecutorUpdated(uint256 indexed collectionId,bytes32 indexed phaseId,address indexed executor,bool allowed,bytes32 policyHash,address admin)",
  "event MintLedgerPolicyGraceSet(uint16 schemaVersion,uint256 indexed collectionId,bytes32 indexed phaseId,address indexed manager,bytes32 previousPolicyHash,bytes32 newPolicyHash,uint64 graceUntil)",
  "event MintLedgerPhasePolicyRegistered(address indexed manager,uint256 indexed collectionId,bytes32 indexed phaseId,bytes32 policyHash)",
  "event MintLedgerCounterPolicyRegistered(address indexed manager,uint256 indexed collectionId,bytes32 indexed phaseId,bytes32 counterId,uint8 capMode,uint8 deltaMode,uint64 staticCap,uint64 staticIncrement,bytes32 counterConfigHash,bytes32 policyHash)",
  "event GovernanceCallDataPublished(uint16 schemaVersion,bytes32 indexed callDataKey,address pointer,address publisher)",
  "event GovernanceActionPolicyValidated(uint16 schemaVersion,bytes32 indexed actionId,uint8 indexed phase,bytes32 indexed candidateProfileHash,bytes32 catalogHash)",
  "event GovernanceActionScheduled(uint16 schemaVersion,bytes32 indexed actionId,uint8 indexed actionClass,address indexed target,uint256 value,bytes4 selector,bytes32 callHash,bytes32 scopeHash,bytes32 oldValueHash,bytes32 newValueHash,uint64 notBefore,uint64 expiresAfter,uint256 nonce,address proposer,bytes32 reasonHash,string reasonURI,bytes32 manifestHash)",
  "event GovernanceActionExecuted(uint16 schemaVersion,bytes32 indexed actionId,uint8 indexed actionClass,address indexed target,uint256 value,bytes4 selector,bytes32 callHash,bytes32 scopeHash,bytes32 oldValueHash,bytes32 newValueHash,address executor,bytes32 manifestHash)"
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
function pin(v: MintPolicyGraceCodePin): MintPolicyGraceCodePin {
  keys(v, ["address", "codeHash"]);
  return { address: address(v.address), codeHash: hash(v.codeHash) };
}
function deployment(v: MintPolicyGraceDeployment): MintPolicyGraceDeployment {
  keys(v, ["chainId", "core", "manager", "ledger", "moduleRegistry", "governance", "artistRegistry"], ["artistOrigin", "supportsDelegatedPolicyConsent"]);
  const chainId = uint(v.chainId);
  if (!chainId) throw Error("Zero chain");
  if (v.supportsDelegatedPolicyConsent !== undefined && typeof v.supportsDelegatedPolicyConsent !== "boolean") {
    throw Error("Expected boolean delegated policy consent capability");
  }
  const origin = v.artistOrigin;
  if (origin) keys(origin, ["manager", "ledger"]);
  const out = { chainId, core: pin(v.core), manager: pin(v.manager), ledger: pin(v.ledger),
    moduleRegistry: pin(v.moduleRegistry), governance: pin(v.governance), artistRegistry: pin(v.artistRegistry),
    ...(v.supportsDelegatedPolicyConsent === undefined ? {} : { supportsDelegatedPolicyConsent: v.supportsDelegatedPolicyConsent }),
    ...(origin ? { artistOrigin: { manager: pin(origin.manager), ledger: pin(origin.ledger) } } : {}) };
  if (new Set([out.core, out.manager, out.ledger, out.moduleRegistry, out.governance, out.artistRegistry].map(p => p.address)).size !== 6) {
    throw Error("Deployment components must be distinct");
  }
  return freeze(out);
}
function scope(v: MintPolicyGraceScope): MintPolicyGraceScope {
  keys(v, ["collectionId", "phaseId", "executors"]);
  if (!Array.isArray(v.executors) || v.executors.length > 64) throw Error("Executor inventory exceeds64");
  const executors = v.executors.map(address).sort((a, b) => a.toLowerCase().localeCompare(b.toLowerCase()));
  if (!uint(v.collectionId) || new Set(executors).size !== executors.length) throw Error("Invalid collection/executor inventory");
  return freeze({ collectionId: v.collectionId, phaseId: hash(v.phaseId), executors });
}
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
async function runtime(p: Reader, v: MintPolicyGraceCodePin, tag: number): Promise<void> {
  const code = bytes(await p.getCode(v.address, tag), 65536);
  if (code === "0x" || (code.length === 48 && code.startsWith("0xef0100")) || !same(keccak256(code), v.codeHash)) throw Error("Pinned runtime differs");
}
async function context(p: Reader, d: MintPolicyGraceDeployment, tag: number) {
  if ((await p.getNetwork()).chainId !== d.chainId) throw Error("RPC chain differs");
  const h = await header(p, tag);
  await Promise.all([d.core, d.manager, d.ledger, d.moduleRegistry, d.governance, d.artistRegistry].map(v => runtime(p, v, tag)));
  for (const [kind, pin] of [["MINT_MANAGER", d.manager], ["MINT_LEDGER", d.ledger], ["MODULE_REGISTRY", d.moduleRegistry], ["ARTIST_REGISTRY", d.artistRegistry]] as const) {
    const pointer = await read(p, d.core.address, "getSatellitePointer", [id(kind)], tag);
    if (!same(pointer[0], pin.address) || !same(pointer[1], pin.codeHash)) throw Error(`Selected ${kind} differs`);
  }
  for (const [name, expected] of [["core", d.core.address], ["mintLedger", d.ledger.address], ["moduleRegistry", d.moduleRegistry.address], ["owner", d.governance.address], ["governanceAuthority", d.governance.address]] as const) {
    if (!same((await read(p, d.manager.address, name, [], tag))[0], expected)) throw Error(`Manager ${name} differs`);
  }
  if (!same((await read(p, d.ledger.address, "owner", [], tag))[0], d.governance.address)
    || !same((await read(p, d.moduleRegistry.address, "governanceExecutor", [], tag))[0], d.governance.address)
    || (await read(p, d.manager.address, "isStreamMintManager", [], tag))[0] !== true
    || (await read(p, d.ledger.address, "isStreamMintLedger", [], tag))[0] !== true
    || (await read(p, d.manager.address, "supportsInterface", ["0xb4074ed7"], tag))[0] !== true
    || (await read(p, d.manager.address, "supportsInterface", ["0xdef72e30"], tag))[0] !== true
    || (await read(p, d.governance.address, "minimumDelay", [1], tag))[0] !== 172800n) throw Error("Dependency capability/governance differs");
  const [profile, catalog, count, revision] = await read(p, d.governance.address, "governanceActionPolicyState", [], tag);
  if (count === 0n || count > 1024n) throw Error("Unbound/oversized governance catalog");
  return { ...h, governanceNonce: uint((await read(p, d.governance.address, "governanceNonce", [], tag))[0]),
    catalog: { candidateProfileHash: hash(profile), catalogHash: hash(catalog), entryCount: uint(count), revision: uint(revision, 64),
      rowAdmission: "original-call-simulation-required" as const } };
}
function object(v: any, names: readonly string[]) { return Object.fromEntries(names.map((n, i) => [n, v[i]])); }
const phaseNames = ["paused", "startTime", "endTime", "maxBatchQuantity", "configHash", "metadataHash"];
const gateNames = ["gate", "gateConfigHash", "gateCodehash", "gateMetadataHash", "gateSemanticVersion", "gateGasLimit"];
const counterNames = ["enabled", "keyMode", "capMode", "deltaMode", "staticCap", "staticIncrement", "counterConfigHash"];
function captureDigest(v: Omit<MintPolicyGraceCapture, "captureHash">): Hex { return keccak256(toUtf8Bytes(stable(v))) as Hex; }
function saved(v: MintPolicyGraceCapture): MintPolicyGraceCapture {
  keys(v, ["deployment", "scope", "snapshot", "grace", "blockNumber", "blockHash", "timestamp", "governanceNonce", "catalog", "captureHash"]);
  const out = { ...structuredClone(v), deployment: deployment(v.deployment), scope: scope(v.scope),
    snapshot: normalizeMintPolicySnapshot(v.snapshot) };
  const { captureHash, ...facts } = out;
  if (!same(captureDigest(facts), hash(captureHash))) throw Error("Saved capture facts changed");
  return freeze(out);
}
/** Proves a bounded supplied executor inventory against both stored and previewed original policy hashes. */
export async function captureMintPolicyGrace(p: Reader, input: MintPolicyGraceDeployment, supplied: MintPolicyGraceScope,
  options: { readonly blockTag: number }): Promise<MintPolicyGraceCapture> {
  keys(options, ["blockTag"]);
  const d = deployment(input), s = scope(supplied), tag = number(options.blockTag);
  const h = await context(p, d, tag);
  const args = [s.collectionId, s.phaseId];
  if ((await read(p, d.core.address, "collectionExists", [s.collectionId], tag))[0] !== true) throw Error("Unknown collection");
  const [exists, config] = await read(p, d.manager.address, "phase", args, tag);
  if (!exists) throw Error("Unknown phase");
  const [gate] = await read(p, d.manager.address, "phaseGate", args, tag);
  const [ids] = await read(p, d.manager.address, "phaseCounterIds", args, tag);
  if (ids.length > 16) throw Error("Counter inventory exceeds16");
  const counterConfigs = [];
  for (const counterId of ids) {
    const [value] = await read(p, d.manager.address, "counterConfig", [...args, counterId], tag);
    const [ledger] = await read(p, d.ledger.address, "registeredCounterPolicy", [d.manager.address, ...args, counterId], tag);
    equal(Array.from(ledger), [value.enabled, value.capMode, value.deltaMode, value.staticCap, value.staticIncrement, value.counterConfigHash], "Manager/Ledger counter policy differs");
    counterConfigs.push(object(value, counterNames));
  }
  const [currentPolicyHash] = await read(p, d.manager.address, "phasePolicyHash", args, tag);
  const snapshot = normalizeMintPolicySnapshot({ chainId: d.chainId, manager: d.manager.address, ledger: d.ledger.address,
    moduleRegistry: d.moduleRegistry.address, ...s, config: object(config, phaseNames), gate: object(gate, gateNames),
    counterIds: Array.from(ids), counterConfigs, currentPolicyHash } as unknown as MintPolicySnapshot);
  const preview = await read(p, d.manager.address, "previewPhasePolicyHash", [...args, snapshot.config, snapshot.gate,
    snapshot.counterIds, snapshot.counterConfigs, snapshot.executors], tag);
  if (!same(preview[0], currentPolicyHash)
    || !same((await read(p, d.ledger.address, "registeredPhasePolicyHash", [d.manager.address, ...args], tag))[0], currentPolicyHash)) throw Error("Current policy hash differs");
  for (const executor of s.executors) {
    if ((await read(p, d.manager.address, "phaseExecutor", [...args, executor], tag))[0] !== true) throw Error("Executor membership differs");
  }
  const [previous, revision, until] = await read(p, d.ledger.address, "policyGrace", [d.manager.address, ...args], tag);
  const grace = { previousPolicyHash: hash(previous, true), previousPolicyRevision: uint(revision, 64), graceUntil: uint(until, 64) };
  if (previous === ZeroHash ? revision !== 0n || until !== 0n : revision === 0n || until === 0n || same(previous, currentPolicyHash)) throw Error("Malformed predecessor grace");
  equal(Array.from(await read(p, d.manager.address, "phasePolicyGrace", args, tag)), [previous, until], "Manager/Ledger grace differs");
  const facts = { deployment: d, scope: s, snapshot, grace, ...h };
  await unchanged(p, h);
  return freeze({ ...facts, captureHash: captureDigest(facts) });
}

async function original(p: Reader, c: MintPolicyGraceCapture): Promise<void> {
  equal(await captureMintPolicyGrace(p, c.deployment, c.scope, { blockTag: c.blockNumber }), c,
    "Saved capture no longer matches its historical block");
}
async function artistConsent(p: Reader, c: MintPolicyGraceCapture, plan: MintPolicyGracePlan): Promise<MintPolicyGraceArtistConsent> {
  const d = c.deployment, tag = c.blockNumber, artist = d.artistRegistry.address;
  if (!same((await read(p, artist, "core", [], tag))[0], d.core.address)) throw Error("Artist Core differs");
  const signingManager = address((await read(p, artist, "mintManager", [], tag))[0]);
  if (!same(signingManager, d.manager.address)) {
    const origin = d.artistOrigin;
    if (!origin || !same(origin.manager.address, signingManager)) throw Error("Original Artist Manager pin required");
    await Promise.all([runtime(p, origin.manager, tag), runtime(p, origin.ledger, tag)]);
    if (!same((await read(p, signingManager, "core", [], tag))[0], d.core.address)
      || !same((await read(p, signingManager, "mintLedger", [], tag))[0], origin.ledger.address)
      || (await read(p, d.ledger.address, "isCompletedMintDescendant", [origin.ledger.address, signingManager, d.manager.address], tag))[0] !== true) {
      throw Error("Original Artist Manager ancestry differs");
    }
  }
  const gas = await read(p, d.manager.address, "gasParameterInfo", [id("6529STREAM_GGP_ARTIST_AUTHORITY_GAS_LIMIT")], tag);
  if (gas.value < 150000n || gas.floor !== 150000n || gas.failureClass !== 2n || gas.revision === 0n) throw Error("Artist read gas policy differs");
  if ((await read(p, d.ledger.address, "ledgerWriter", [d.manager.address], tag))[0] !== true
    || (await read(p, d.ledger.address, "ledgerWriterRetiredAt", [d.manager.address], tag))[0] !== 0n) throw Error("Manager is not an active Ledger writer");
  const args = [c.scope.collectionId, c.scope.phaseId, plan.prospectivePolicyHash];
  const consentMode = uint((await read(p, artist, "consentMode", [c.scope.collectionId], tag))[0], 8);
  const [consented, evidence] = await read(p, artist, "isPolicyConsented", args, tag);
  const evidenceHash = hash(evidence, true);
  let registrationReady = consentModeSupported(d, consentMode) && consented && evidenceHash !== ZeroHash;
  if (consentMode === 3n) {
    const supported = (await read(p, artist, "supportsInterface", ["0x523cbf7c"], tag))[0];
    const [declared, declaration, declaredAt] = await read(p, artist, "platformWorksDeclaration", [c.scope.collectionId], tag);
    registrationReady = registrationReady && supported && declared && same(declaration, evidenceHash) && declaredAt <= c.timestamp;
  }
  if (registrationReady) await read(p, artist, "requireMintConsent", args, tag, d.manager.address);
  return freeze({ artistRegistry: artist, signingManager, consentMode, consented, evidenceHash, registrationReady });
}
function consentModeSupported(d: MintPolicyGraceDeployment, mode: bigint): boolean {
  return mode === 1n || mode === 3n || (mode === 2n && d.supportsDelegatedPolicyConsent === true);
}
function inspection(v: MintPolicyGraceInspection): MintPolicyGraceInspection {
  keys(v, ["capture", "plan", "artistConsent", "inspectionHash"]);
  const out = { capture: saved(v.capture), plan: normalizeMintPolicyGracePlan(v.plan), artistConsent: structuredClone(v.artistConsent) };
  equal(out.plan.snapshot, out.capture.snapshot);
  if ((out.artistConsent === null) !== !out.plan.changed) throw Error("Consent observation does not match change");
  if (!same(keccak256(toUtf8Bytes(stable(out))), hash(v.inspectionHash))) throw Error("Inspection facts changed");
  return freeze({ ...out, inspectionHash: v.inspectionHash });
}
/** Missing prospective consent is reported without inventing a new signature or changing an old ticket. */
export async function inspectMintPolicyGraceChange(p: Reader, input: MintPolicyGraceCapture, request: MintPolicyGraceRequest,
  options: { readonly blockTag: number }): Promise<MintPolicyGraceInspection> {
  keys(options, ["blockTag"]);
  const c = saved(input), prepared = prepareMintPolicyGraceChange(c.snapshot, request), tag = number(options.blockTag);
  if (tag < c.blockNumber) throw Error("Inspection predates capture");
  await original(p, c);
  const capture = await captureMintPolicyGrace(p, c.deployment, c.scope, { blockTag: tag });
  equal(capture.snapshot, c.snapshot, "Phase/executor state changed; recapture");
  equal(capture.grace, c.grace, "Grace state changed; recapture");
  const plan = prepareMintPolicyGraceChange(capture.snapshot, prepared.request);
  const preview = bytes(await p.call({ ...plan.previewCall, blockTag: tag }));
  if (!isHexString(preview, 32) || !same(preview, plan.prospectivePolicyHash)) throw Error("Prospective preview differs");
  const membership = (await read(p, c.deployment.manager.address, "phaseExecutor",
    [c.scope.collectionId, c.scope.phaseId, plan.request.executor], tag))[0];
  if (membership !== capture.snapshot.executors.some(v => same(v, plan.request.executor))) throw Error("Target membership differs");
  const consent = plan.changed ? await artistConsent(p, capture, plan) : null;
  await unchanged(p, capture);
  const facts = { capture, plan, artistConsent: consent };
  return freeze({ ...facts, inspectionHash: keccak256(toUtf8Bytes(stable(facts))) as Hex });
}
function windowCheck(now: bigint, w: MintPolicyGraceGovernanceWindow): void {
  if (now > (1n << 64n) - 1n - 31536000n || w.notBefore < now + 172800n
    || w.expiresAfter > now + 31536000n || w.expiresAfter - w.notBefore < 604800n) throw Error("Original governance48h/7day/365day window differs");
}
export function prepareMintPolicyGraceGovernance(input: MintPolicyGraceInspection, proposer: Address,
  window: MintPolicyGraceGovernanceWindow): PreparedMintPolicyGraceGovernance {
  const i = inspection(input);
  const batch = mintPolicyGraceGovernanceBatch(i.plan, i.capture.deployment.governance.address, i.capture.governanceNonce, window);
  windowCheck(i.capture.timestamp, batch.window);
  if (toUtf8Bytes(batch.window.reasonURI).length > 2048) throw Error("Reason URI exceeds client bound");
  return freeze({ inspection: i, proposer: address(proposer), batch });
}
function prepared(v: PreparedMintPolicyGraceGovernance): PreparedMintPolicyGraceGovernance {
  keys(v, ["inspection", "proposer", "batch"]);
  const b = normalizeMintPolicyGraceGovernanceBatch(v.batch);
  const out = prepareMintPolicyGraceGovernance(v.inspection, v.proposer, b.window);
  equal(out, v);
  return out;
}
export function prepareMintPolicyGraceGovernanceOperation(input: PreparedMintPolicyGraceGovernance,
  stage: MintPolicyGraceOperation["stage"], caller: Address): MintPolicyGraceOperation {
  const p = prepared(input), actor = address(caller);
  if (!["publish", "schedule", "execute"].includes(stage)) throw Error("Unsupported governance stage");
  if (stage === "schedule" && !same(actor, p.proposer)) throw Error("Schedule caller differs from proposer");
  return freeze({ prepared: p, stage, caller: actor, call: stage === "publish" ? p.batch.publicationCall
    : stage === "schedule" ? p.batch.scheduleCall : p.batch.executionCall });
}
function operation(v: MintPolicyGraceOperation): MintPolicyGraceOperation {
  keys(v, ["prepared", "stage", "caller", "call"]);
  const out = prepareMintPolicyGraceGovernanceOperation(v.prepared, v.stage, v.caller);
  equal(out, v);
  return out;
}
async function publication(p: Reader, b: MintPolicyGraceGovernanceBatch, tag: number): Promise<Address | null> {
  const [ptr] = await read(p, b.governanceExecutor, "publishedCallData", [b.publicationKey], tag);
  if (ptr === ZeroAddress) return null;
  const pointer = address(ptr), expected = coder.encode(["bytes[]"], [[b.plan.targetCall.data]]);
  if (!same(bytes(await p.getCode(pointer, tag), 24576), `0x00${expected.slice(2)}`)) throw Error("Published call data differs");
  return pointer;
}
async function action(p: Reader, o: MintPolicyGraceOperation, tag: number) {
  const b = o.prepared.batch;
  const [a] = await read(p, b.governanceExecutor, "governanceAction", [b.actionId], tag);
  const expected = { actionClass: 1n, target: b.plan.targetCall.to, value: 0n, selector: b.plan.governanceCall.selector,
    callHash: b.callsHash, scopeHash: b.scopeHash, oldValueHash: b.oldValueHash, newValueHash: b.newValueHash,
    notBefore: b.window.notBefore, expiresAfter: b.window.expiresAfter, proposer: o.prepared.proposer,
    reasonHash: b.window.reasonHash, reasonURI: b.window.reasonURI, manifestHash: b.window.manifestHash };
  for (const [key, value] of Object.entries(expected)) {
    if (a[key] !== value && (key === "reasonURI" || !same(a[key], value))) throw Error(`Scheduled ${key} differs`);
  }
  const [data] = await read(p, b.governanceExecutor, "scheduledCallData", [b.actionId], tag);
  equal(Array.from(data), [b.plan.targetCall.data], "Scheduled bytes differ");
  const ptr = await publication(p, b, tag);
  if (!ptr || !same((await read(p, b.governanceExecutor, "scheduledCallDataPointer", [b.actionId], tag))[0], ptr)) throw Error("Scheduled pointer differs");
  return a;
}
export interface MintPolicyGraceSimulation {
  readonly operation: MintPolicyGraceOperation;
  readonly blockNumber: number; readonly blockHash: Hex; readonly timestamp: bigint;
  readonly observed: MintPolicyGraceInspection | null;
  readonly returnData: Hex;
}
/** Exact original governance eth_call, with the reviewed caller and concrete block. Never signs or broadcasts. */
export async function simulateMintPolicyGraceOperation(p: Reader, input: MintPolicyGraceOperation,
  options: { readonly blockTag: number }): Promise<MintPolicyGraceSimulation> {
  keys(options, ["blockTag"]);
  const o = operation(input), i = o.prepared.inspection, c = i.capture, b = o.prepared.batch, tag = number(options.blockTag);
  if (tag < c.blockNumber) throw Error("Simulation predates capture");
  await original(p, c);
  const h = await context(p, c.deployment, tag);
  let observed: MintPolicyGraceInspection | null = null;
  if (o.stage !== "publish") {
    equal(h.catalog, c.catalog, "Governance catalog changed; rebuild and reschedule");
    observed = await inspectMintPolicyGraceChange(p, c, i.plan.request, { blockTag: tag });
    if (o.stage === "schedule") {
      if (h.governanceNonce !== b.nonce) throw Error("Governance nonce changed");
      windowCheck(h.timestamp, b.window);
      if (!await publication(p, b, tag)) throw Error("Publish governance call data first");
      const [owner] = await read(p, b.governanceExecutor, "owner", [], tag);
      if (!same(owner, o.caller) && (await read(p, b.governanceExecutor, "isProposer", [o.caller], tag))[0] !== true) throw Error("Caller is not an authorized proposer");
    } else {
      const a = await action(p, o, tag);
      if (a.status !== 1n || h.timestamp < b.window.notBefore || h.timestamp > b.window.expiresAfter) throw Error("Action is outside scheduled execution window");
      if (i.plan.changed) {
        assertMintPolicyGraceDeadline(i.plan.request.graceUntil, h.timestamp);
        if (!observed.artistConsent?.registrationReady) throw Error("Prospective Artist consent unavailable");
      }
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
  return freeze({ operation: o, blockNumber: tag, blockHash: h.blockHash, timestamp: h.timestamp, observed, returnData: returned });
}

export interface MintPolicyGraceEventReference {
  readonly address: Address; readonly event: string; readonly logIndex: number;
  readonly transactionHash: Hex; readonly blockHash: Hex;
}
export interface MintPolicyGraceOperationReceipt {
  readonly operation: MintPolicyGraceOperation;
  readonly transactionHash: Hex; readonly blockNumber: number; readonly blockHash: Hex;
  readonly events: readonly MintPolicyGraceEventReference[];
  readonly observedPolicy: MintPolicyGraceCapture | null;
  readonly stateAttribution: "exact end-of-block policy required; events identify this operation";
}
const safeAbi = new Interface(["function execTransaction(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,bytes signatures) returns(bool)"]);
const safePlain = new Interface(["event ExecutionSuccess(bytes32 txHash,uint256 payment)", "event ExecutionFailure(bytes32 txHash,uint256 payment)"]);
const safeIndexed = new Interface(["event ExecutionSuccess(bytes32 indexed txHash,uint256 payment)", "event ExecutionFailure(bytes32 indexed txHash,uint256 payment)"]);
interface Log { address: Address; topics: Hex[]; data: Hex; index: number }
/**
 * Singleton direct/Safe CALL receipt verification. End-of-block policy drift fails closed; a no-op
 * additionally needs the same policy/grace in the previous block because it has no target events.
 */
export async function inspectMintPolicyGraceOperationReceipt(p: ReceiptReader, input: MintPolicyGraceOperation,
  options: { readonly transactionHash: Hex; readonly execution: "direct" | "safe" }): Promise<MintPolicyGraceOperationReceipt> {
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
    return { address: address(l.address), topics: l.topics.map((x: string) => hash(x, true)), data: bytes(l.data, 16384), index: number(l.index) };
  });
  if (logs.some((l, n) => n > 0 && l.index <= logs[n - 1]!.index)) throw Error("Duplicate/unordered receipt logs");
  const refs: MintPolicyGraceEventReference[] = [];
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
  let observedPolicy: MintPolicyGraceCapture | null = null;
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
    equal(h.catalog, c.catalog, "Receipt catalog differs from reviewed catalog");
    const state = await action(p, o, tag);
    const common = [1n, b.actionId, 1n, d.manager.address, 0n, i.plan.governanceCall.selector,
      b.callsHash, b.scopeHash, b.oldValueHash, b.newValueHash];
    const policyIndex = one(d.governance.address, "GovernanceActionPolicyValidated", [1n, b.actionId,
      o.stage === "schedule" ? 1n : 2n, c.catalog.candidateProfileHash, c.catalog.catalogHash]);
    if (o.stage === "schedule") {
      windowCheck(h.timestamp, b.window);
      if (![1n, 2n].includes(state.status) || h.governanceNonce < b.nonce + 1n) throw Error("Scheduled action/nonce not retained");
      const scheduled = one(d.governance.address, "GovernanceActionScheduled", [...common, b.window.notBefore,
        b.window.expiresAfter, b.nonce, o.caller, b.window.reasonHash, b.window.reasonURI, b.window.manifestHash]);
      if (policyIndex <= scheduled) throw Error("Catalog validation event must follow scheduling");
    } else {
      if (state.status !== 3n || !same(state.executor, o.caller) || h.timestamp < b.window.notBefore || h.timestamp > b.window.expiresAfter) throw Error("Executed action/window differs");
      const executed = one(d.governance.address, "GovernanceActionExecuted", [...common, o.caller, b.window.manifestHash]);
      const scopeAfter = { ...c.scope, executors: i.plan.prospectiveExecutors };
      observedPolicy = await captureMintPolicyGrace(p, d, scopeAfter, { blockTag: tag });
      equal(observedPolicy.snapshot, { ...c.snapshot, executors: i.plan.prospectiveExecutors, currentPolicyHash: i.plan.prospectivePolicyHash }, "Receipt-block policy changed; exact state unavailable");
      const targetNames = ["MintPhaseConsentRecorded", "MintPhaseExecutorUpdated"];
      const ledgerNames = ["MintLedgerPolicyGraceSet", "MintLedgerPhasePolicyRegistered", "MintLedgerCounterPolicyRegistered"];
      if (!i.plan.changed) {
        if (targetNames.some(name => found(d.manager.address, name).length)
          || ledgerNames.some(name => found(d.ledger.address, name).length)) throw Error("No-op emitted policy events");
        const prior = await captureMintPolicyGrace(p, d, c.scope, { blockTag: tag - 1 });
        equal(prior.snapshot, c.snapshot, "No-op requires previous-block policy proof");
        equal(prior.grace, c.grace, "No-op requires previous-block grace proof");
        equal(observedPolicy.grace, prior.grace, "No-op changed existing grace");
      } else {
        assertMintPolicyGraceDeadline(i.plan.request.graceUntil, h.timestamp);
        const consent = found(d.manager.address, "MintPhaseConsentRecorded");
        if (consent.length !== 1 || !consentModeSupported(d, consent[0]!.args[4])) throw Error("Original Artist consent event unavailable");
        const evidence = hash(consent[0]!.args[5]);
        const consentIndex = one(d.manager.address, "MintPhaseConsentRecorded", [1n, c.scope.collectionId, c.scope.phaseId,
          i.plan.prospectivePolicyHash, consent[0]!.args[4], evidence]);
        const graceIndex = one(d.ledger.address, "MintLedgerPolicyGraceSet", [1n, c.scope.collectionId, c.scope.phaseId,
          d.manager.address, c.snapshot.currentPolicyHash, i.plan.prospectivePolicyHash, i.plan.request.graceUntil]);
        const registered = one(d.ledger.address, "MintLedgerPhasePolicyRegistered", [d.manager.address,
          c.scope.collectionId, c.scope.phaseId, i.plan.prospectivePolicyHash]);
        const counters = found(d.ledger.address, "MintLedgerCounterPolicyRegistered");
        if (counters.length !== c.snapshot.counterIds.length) throw Error("Counter registration event count differs");
        let previous = registered;
        counters.forEach((entry, n) => {
          const config = c.snapshot.counterConfigs[n]!;
          equal(Array.from(entry.args), [d.manager.address, c.scope.collectionId, c.scope.phaseId,
            c.snapshot.counterIds[n], config.capMode, config.deltaMode, config.staticCap, config.staticIncrement,
            config.counterConfigHash, i.plan.prospectivePolicyHash], "Counter registration event differs");
          if (entry.log.index <= previous) throw Error("Counter registration order differs");
          reference(entry.log, "MintLedgerCounterPolicyRegistered");
          previous = entry.log.index;
        });
        const updated = one(d.manager.address, "MintPhaseExecutorUpdated", [c.scope.collectionId, c.scope.phaseId,
          i.plan.request.executor, i.plan.request.allowed, i.plan.prospectivePolicyHash, d.governance.address]);
        if (!(consentIndex < graceIndex && graceIndex < registered && previous < updated && updated < executed)) throw Error("Original policy/governance event order differs");
        if (i.plan.request.graceUntil === 0n) {
          equal(observedPolicy.grace, { previousPolicyHash: ZeroHash, previousPolicyRevision: 0n, graceUntil: 0n }, "Zero rotation did not clear grace");
        } else if (!same(observedPolicy.grace.previousPolicyHash, c.snapshot.currentPolicyHash)
          || observedPolicy.grace.graceUntil !== i.plan.request.graceUntil
          || (c.grace.previousPolicyRevision !== 0n && observedPolicy.grace.previousPolicyRevision <= c.grace.previousPolicyRevision)) {
          throw Error("Predecessor grace readback differs");
        }
      }
      if (policyIndex <= executed) throw Error("Catalog validation event must follow execution");
    }
  }
  if (execution === "safe") {
    const successes = logs.filter(l => same(l.address, o.caller) && same(l.topics[0], safePlain.getEvent("ExecutionSuccess")!.topicHash));
    if (successes.length !== 1 || logs.some(l => same(l.address, o.caller) && same(l.topics[0], safePlain.getEvent("ExecutionFailure")!.topicHash))) throw Error("Safe requires one success and no failure");
    const log = successes[0]!, iface = log.topics.length === 2 ? safeIndexed : safePlain;
    const parsed = found(o.caller, "ExecutionSuccess", iface);
    hash(parsed[0]!.args[0]);
    if (refs.some(v => v.logIndex >= log.index)) throw Error("Safe success must follow protocol events");
    reference(log, "ExecutionSuccess");
  }
  await unchanged(p, h);
  return freeze({ operation: o, transactionHash, blockNumber: tag, blockHash: h.blockHash,
    events: refs.sort((a, b) => a.logIndex - b.logIndex), observedPolicy,
    stateAttribution: "exact end-of-block policy required; events identify this operation" });
}
