import { AbiCoder, Interface, ZeroAddress, ZeroHash, getAddress, isHexString, keccak256 } from "ethers";
import type { Provider } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import type { MintPolicyPhaseConfig } from "./current-mint-policy-grace.js";
import {
  prepareMintCounterReadCall, normalizeMintCounterReadCall, normalizeMintCounterReadPolicy,
  resolveMintCounterRead, mintCounterReadScope, mintCounterReadValueKey, mintCounterReadRemaining,
  mintCounterProoflessRemaining, type MintCounterReadPolicy, type MintCounterResolution
} from "./current-mint-counter-reads.js";

export interface MintCounterReadCodePin { readonly address: Address; readonly codeHash: Hex }
export interface MintCounterReadDeployment {
  readonly chainId: bigint;
  readonly manager: MintCounterReadCodePin;
  readonly ledger: MintCounterReadCodePin;
}
type PreparedRead = ReturnType<typeof prepareMintCounterReadCall>;
type Reader = Pick<Provider, "getNetwork" | "getCode" | "getBlock" | "call">;
export interface MintCounterDefinitionObservation {
  readonly scope: "direct-ledger-observation";
  readonly noNestedGasEquivalence: true;
  readonly probe: "supported" | "legacy-not-supported" | "legacy-call-reverted" | "legacy-noncanonical";
  /** An ordinary RPC probe is not a claim to reproduce the original nested30,000-gas call. */
  readonly probeLimit: "ordinary RPC probe; original Manager result remains authoritative";
  readonly exists: boolean;
  readonly returnedDefinition: MintCounterReadPolicy["definition"];
  /** Scope selected under this direct observation, not proof of the metered nested branch. */
  readonly candidateDefinition: MintCounterReadPolicy["definition"];
}
export interface MintCounterReadObservation {
  readonly deployment: MintCounterReadDeployment;
  readonly prepared: PreparedRead;
  readonly blockNumber: number;
  readonly blockHash: Hex;
  readonly timestamp: bigint;
  readonly phase: MintPolicyPhaseConfig | null;
  readonly policy: MintCounterReadPolicy | null;
  readonly definition: MintCounterDefinitionObservation | null;
  readonly valueKey: Hex;
  readonly scopedCollectionId: bigint | null;
  readonly scopedPhaseId: Hex | null;
  /** Exact scalar returned by raw/value/proofless-remaining methods; null for tuple methods. */
  readonly value: bigint | null;
  readonly resolution: MintCounterResolution | null;
  readonly preScopeSubjectKey: Hex | null;
  readonly current: bigint;
  readonly remaining: bigint | null;
  readonly remainingMeaning: "not-requested" | "uint64-storage-headroom" | "verified-counter-cap";
  /** Counter consumptions, not token quantity; CONTEXT consumes once per batch. */
  readonly remainingConsumptions: bigint | null;
  readonly consumptionUnit: "unknown" | "per-token" | "per-batch";
  readonly returnData: Hex;
  readonly accountingOnly: true;
}

const coder = AbiCoder.defaultAbiCoder();
const PHASE = "(bool paused,uint64 startTime,uint64 endTime,uint32 maxBatchQuantity,bytes32 configHash,bytes32 metadataHash)";
const COUNTER = "(bool enabled,uint8 keyMode,uint8 capMode,uint8 deltaMode,uint64 staticCap,uint64 staticIncrement,bytes32 counterConfigHash)";
const DEFINITION = "(uint8 scope,uint8 keyMode,bytes32 capRoot,bytes32 metadataHash)";
const CONTEXT = "(uint256 collectionId,bytes32 phaseId,bytes32 counterId,address payer,address initialRecipient,address beneficiary,address executor,address authorizer,uint256 tokenIndex,bytes32 contextHash,bytes resolverData)";
const RESOLUTION = "(bytes32 subjectKey,uint64 effectiveCap,uint64 increment,bytes32 resolutionHash)";
const managerAbi = new Interface([
  "function mintLedger() view returns(address)", "function isStreamMintManager() pure returns(bool)",
  "function supportsInterface(bytes4) view returns(bool)",
  `function phase(uint256,bytes32) view returns(bool exists,${PHASE} config)`,
  `function counterConfig(uint256,bytes32,bytes32) view returns(${COUNTER})`,
  "function previewCounterValueKey(uint256,bytes32,bytes32,bytes32) view returns(bytes32)",
  "function rawCounterValue(bytes32) view returns(uint64)",
  "function counterValue(uint256,bytes32,bytes32,bytes32) view returns(uint64)",
  "function remainingForCounter(uint256,bytes32,bytes32,bytes32) view returns(uint64)",
  `function resolveCounter(${CONTEXT}) view returns(${RESOLUTION})`,
  `function remainingForResolvedCounter(${CONTEXT}) view returns(${RESOLUTION},uint64 current,uint64 remaining)`
]);
const ledgerAbi = new Interface([
  "function isStreamMintLedger() pure returns(bool)", "function supportsInterface(bytes4) view returns(bool)",
  "function counterValue(bytes32) view returns(uint64)",
  "function deriveCounterValueKey(address,uint256,bytes32,bytes32,bytes32) pure returns(bytes32)",
  `function counterDefinitionForManager(address,bytes32) view returns(bool exists,${DEFINITION} definition)`
]);
const policyInterface = new Interface([
  `function registerCounterDefinition(${DEFINITION}) returns(bytes32)`,
  `function counterDefinition(bytes32) view returns(bool,${DEFINITION})`,
  `function counterDefinitionForManager(address,bytes32) view returns(bool,${DEFINITION})`,
  "function managerDefinitionCount(address) view returns(uint256)",
  `function managerDefinitionAt(address,uint256) view returns(bytes32,bool,${DEFINITION})`
]);
const policyInterfaceId = `0x${policyInterface.fragments.reduce((value, f) => value ^ BigInt(policyInterface.getFunction(f.format("sighash"))!.selector), 0n).toString(16).padStart(8, "0")}`;
const phaseNames = ["paused", "startTime", "endTime", "maxBatchQuantity", "configHash", "metadataHash"];
const counterNames = ["enabled", "keyMode", "capMode", "deltaMode", "staticCap", "staticIncrement", "counterConfigHash"];
const definitionNames = ["scope", "keyMode", "capRoot", "metadataHash"];
const resolutionNames = ["subjectKey", "effectiveCap", "increment", "resolutionHash"];
function exact(value: unknown, names: readonly string[]): void {
  if (!value || typeof value !== "object" || Array.isArray(value) || Reflect.ownKeys(value).length !== names.length
    || Reflect.ownKeys(value).some(k => typeof k !== "string" || !names.includes(k))) throw Error("Missing/unknown fields");
}
function address(value: unknown): Address {
  if (typeof value !== "string") throw Error("Expected address");
  const result = getAddress(value) as Address;
  if (result === ZeroAddress) throw Error("Expected nonzero address");
  return result;
}
function hash(value: unknown, zero = false): Hex {
  if (typeof value !== "string" || !isHexString(value, 32) || (!zero && value.toLowerCase() === ZeroHash)) throw Error("Expected bytes32");
  return value.toLowerCase() as Hex;
}
function uint(value: unknown, bits = 256): bigint {
  if (typeof value !== "bigint" || value < 0n || value >= 1n << BigInt(bits)) throw Error("Expected bounded unsigned bigint");
  return value;
}
function block(value: unknown): number {
  if (typeof value !== "number" || !Number.isSafeInteger(value) || value < 0) throw Error("Expected concrete block number");
  return value;
}
function bytes(value: unknown, maximum: number): Hex {
  if (typeof value !== "string" || !isHexString(value, true) || (value.length - 2) / 2 > maximum) throw Error("Malformed/oversized RPC bytes");
  return value.toLowerCase() as Hex;
}
function same(a: unknown, b: unknown): boolean { return typeof a === "string" && typeof b === "string" && a.toLowerCase() === b.toLowerCase(); }
function freeze<T>(value: T): T {
  if (value && typeof value === "object") { Object.values(value).forEach(freeze); Object.freeze(value); }
  return value;
}
function pin(value: MintCounterReadCodePin): MintCounterReadCodePin {
  exact(value, ["address", "codeHash"]);
  return { address: address(value.address), codeHash: hash(value.codeHash) };
}
function deployment(value: MintCounterReadDeployment): MintCounterReadDeployment {
  exact(value, ["chainId", "manager", "ledger"]);
  const result = { chainId: uint(value.chainId), manager: pin(value.manager), ledger: pin(value.ledger) };
  if (!result.chainId || result.manager.address === result.ledger.address) throw Error("Invalid deployment coordinates");
  return freeze(result);
}
function object(value: readonly unknown[], names: readonly string[]): any { return Object.fromEntries(names.map((name, i) => [name, value[i]])); }
async function runtime(p: Reader, value: MintCounterReadCodePin, tag: number): Promise<void> {
  const code = bytes(await p.getCode(value.address, tag), 65536);
  if (code === "0x" || (code.length === 48 && code.startsWith("0xef0100")) || !same(keccak256(code), value.codeHash)) throw Error("Pinned runtime differs");
}
async function header(p: Reader, tag: number) {
  const h = await p.getBlock(tag);
  if (!h || h.number !== tag || !Number.isSafeInteger(h.timestamp) || h.timestamp < 0) throw Error("Missing/mismatched block");
  return { blockNumber: tag, blockHash: hash(h.hash), timestamp: BigInt(h.timestamp) };
}
async function read(p: Reader, codec: Interface, to: Address, name: string, args: readonly unknown[], tag: number, from: Address,
  expectedBytes: number): Promise<any> {
  const raw = bytes(await p.call({ to, from, data: codec.encodeFunctionData(name, args), value: 0n, blockTag: tag }), expectedBytes);
  if ((raw.length - 2) / 2 !== expectedBytes) throw Error(`Wrong ${name} return length`);
  const value = codec.decodeFunctionResult(name, raw);
  if (!same(codec.encodeFunctionResult(name, value), raw)) throw Error(`Noncanonical ${name} return`);
  return value;
}
async function definition(p: Reader, d: MintCounterReadDeployment, configHash: Hex, tag: number): Promise<MintCounterDefinitionObservation> {
  let raw: Hex | null = null;
  let probe: MintCounterDefinitionObservation["probe"] = "legacy-call-reverted";
  try {
    raw = bytes(await p.call({ to: d.ledger.address, from: d.manager.address,
      data: ledgerAbi.encodeFunctionData("supportsInterface", [policyInterfaceId]), value: 0n, blockTag: tag }), 4096);
  } catch (error) {
    if (!error || typeof error !== "object" || Reflect.get(error, "code") !== "CALL_EXCEPTION") throw error;
  }
  if (raw !== null) {
    probe = raw === coder.encode(["bool"], [true]) ? "supported"
      : raw === coder.encode(["bool"], [false]) ? "legacy-not-supported" : "legacy-noncanonical";
  }
  let exists = false;
  let returnedDefinition: MintCounterReadPolicy["definition"] = { scope: 2n, keyMode: 0n, capRoot: ZeroHash as Hex, metadataHash: ZeroHash as Hex };
  if (probe === "supported") {
    const value = await read(p, ledgerAbi, d.ledger.address, "counterDefinitionForManager", [d.manager.address, configHash], tag, d.manager.address, 160);
    exists = value[0];
    returnedDefinition = object(value[1], definitionNames);
  }
  const candidateDefinition = { ...returnedDefinition, scope: exists ? returnedDefinition.scope : 2n };
  return freeze({ scope: "direct-ledger-observation", noNestedGasEquivalence: true,
    probe, probeLimit: "ordinary RPC probe; original Manager result remains authoritative", exists,
    returnedDefinition, candidateDefinition });
}

/**
 * The five original accounting views only. No writer, Artist, pause, executor or payment admission
 * is inferred. Every result is checked against its original Manager call and same-block Ledger read.
 */
export async function inspectMintCounterRead(p: Reader, supplied: MintCounterReadDeployment, suppliedCall: PreparedRead,
  options: { readonly blockTag: number }): Promise<MintCounterReadObservation> {
  exact(options, ["blockTag"]);
  // Bound caller-owned dynamic material before normalization re-encodes the complete request.
  bytes(suppliedCall.call.data, 16384);
  if ("context" in suppliedCall.request) bytes(suppliedCall.request.context.resolverData, 8192);
  const d = deployment(supplied), prepared = normalizeMintCounterReadCall(suppliedCall), tag = block(options.blockTag);
  if (!same(prepared.manager, d.manager.address)) throw Error("Prepared Manager differs from deployment");
  if ((await p.getNetwork()).chainId !== d.chainId) throw Error("RPC chain differs");
  const h = await header(p, tag);
  await Promise.all([runtime(p, d.manager, tag), runtime(p, d.ledger, tag)]);
  if (!same((await read(p, managerAbi, d.manager.address, "mintLedger", [], tag, prepared.caller, 32))[0], d.ledger.address)
    || (await read(p, managerAbi, d.manager.address, "isStreamMintManager", [], tag, prepared.caller, 32))[0] !== true
    || (await read(p, managerAbi, d.manager.address, "supportsInterface", ["0xe96c52f4"], tag, prepared.caller, 32))[0] !== true
    || (await read(p, ledgerAbi, d.ledger.address, "isStreamMintLedger", [], tag, d.manager.address, 32))[0] !== true) throw Error("Counter read dependency/capability differs");
  const request = prepared.request, binding = { chainId: d.chainId, manager: d.manager.address, ledger: d.ledger.address };
  let phase: MintPolicyPhaseConfig | null = null, policy: MintCounterReadPolicy | null = null;
  let selectedDefinition: MintCounterDefinitionObservation | null = null;
  let resolution: MintCounterResolution | null = null, preScopeSubjectKey: Hex | null = null;
  let scopedCollectionId: bigint | null = null, scopedPhaseId: Hex | null = null;
  let valueKey: Hex, remaining: bigint | null = null, value: bigint | null = null;
  if (request.method === "rawCounterValue") {
    valueKey = request.valueKey;
  } else {
    const x = "context" in request ? request.context : request;
    const phaseResult = await read(p, managerAbi, d.manager.address, "phase", [x.collectionId, x.phaseId], tag, prepared.caller, 224);
    if (phaseResult[0] !== true) throw Error("Original phase does not exist");
    phase = object(phaseResult[1], phaseNames);
    const [config] = await read(p, managerAbi, d.manager.address, "counterConfig", [x.collectionId, x.phaseId, x.counterId], tag, prepared.caller, 224);
    if (config.enabled !== true) throw Error("Original counter is not enabled");
    selectedDefinition = await definition(p, d, config.counterConfigHash, tag);
    policy = normalizeMintCounterReadPolicy({ phaseExists: phaseResult[0], config: object(config, counterNames),
      definitionExists: selectedDefinition.exists, definition: selectedDefinition.returnedDefinition });
    if ("context" in request) {
      const resolved = resolveMintCounterRead(binding, policy, request.context);
      resolution = resolved.resolution;
      valueKey = resolved.valueKey;
      preScopeSubjectKey = resolved.preScopeSubjectKey;
      scopedCollectionId = resolved.scopedCollectionId;
      scopedPhaseId = resolved.scopedPhaseId;
    } else {
      valueKey = mintCounterReadValueKey(binding, policy, { collectionId: request.collectionId, phaseId: request.phaseId,
        counterId: request.counterId, subjectKey: request.subjectKey });
      const scoped = mintCounterReadScope(policy, request.collectionId, request.phaseId);
      scopedCollectionId = scoped.collectionId;
      scopedPhaseId = scoped.phaseId;
    }
    const subjectKey = resolution?.subjectKey ?? ("subjectKey" in request ? request.subjectKey : ZeroHash);
    const [preview] = await read(p, managerAbi, d.manager.address, "previewCounterValueKey",
      [x.collectionId, x.phaseId, x.counterId, subjectKey], tag, prepared.caller, 32);
    const [ledgerKey] = await read(p, ledgerAbi, d.ledger.address, "deriveCounterValueKey",
      [d.manager.address, scopedCollectionId, scopedPhaseId, x.counterId, subjectKey], tag, d.manager.address, 32);
    if (!same(preview, valueKey) || !same(ledgerKey, valueKey)) throw Error("Original scoped value key differs");
  }
  const [current] = await read(p, ledgerAbi, d.ledger.address, "counterValue", [valueKey], tag, d.manager.address, 32);
  uint(current, 64);
  if (policy && (request.method === "remainingForCounter" || resolution !== null)) {
    remaining = resolution ? mintCounterReadRemaining(policy.config.capMode, resolution.effectiveCap, current)
      : mintCounterProoflessRemaining(policy, current);
  }
  const expectedLength = request.method === "remainingForResolvedCounter" ? 192 : request.method === "resolveCounter" ? 128 : 32;
  const raw = bytes(await p.call({ ...prepared.call, from: prepared.caller, blockTag: tag }), expectedLength);
  if ((raw.length - 2) / 2 !== expectedLength) throw Error("Wrong original counter return length");
  const decoded = managerAbi.decodeFunctionResult(request.method, raw);
  if (!same(managerAbi.encodeFunctionResult(request.method, decoded), raw)) throw Error("Noncanonical original counter return");
  if (resolution) {
    const returned = object(decoded[0], resolutionNames);
    for (const key of resolutionNames as readonly (keyof MintCounterResolution)[]) {
      if (returned[key] !== resolution[key] && !same(returned[key], resolution[key])) throw Error("Original resolution differs");
    }
    if (request.method === "remainingForResolvedCounter" && (decoded[1] !== current || decoded[2] !== remaining)) throw Error("Original combined accounting differs");
  } else {
    value = uint(decoded[0], 64);
    if (value !== (request.method === "remainingForCounter" ? remaining : current)) throw Error("Original scalar accounting differs");
  }
  const final = await header(p, tag);
  if (!same(final.blockHash, h.blockHash) || final.timestamp !== h.timestamp) throw Error("Pinned block changed");
  return freeze({ deployment: d, prepared, ...h, phase, policy, definition: selectedDefinition, valueKey, scopedCollectionId, scopedPhaseId,
    value, resolution, preScopeSubjectKey, current, remaining,
    remainingMeaning: remaining === null ? "not-requested" : policy!.config.capMode === 0n ? "uint64-storage-headroom" : "verified-counter-cap",
    remainingConsumptions: remaining === null || !policy?.config.staticIncrement ? null : remaining / policy.config.staticIncrement,
    consumptionUnit: policy === null ? "unknown" : policy.config.keyMode === 6n ? "per-batch" : "per-token", returnData: raw, accountingOnly: true });
}
