import { AbiCoder, Interface, ZeroAddress, getAddress, id, isHexString, keccak256 } from "ethers";
import type { BlockTag, Provider } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import type { UnsignedCall } from "./client.js";
import type { SigningPayload } from "./signing.js";
import type { NativeFixedPriceSaleAuthorization } from "./current-signing.js";
import type { MintGateBatch } from "./current-mint-gates.js";
import {
  prepareNativeImmediateSale,
  type NativeImmediateSaleInput,
} from "./current-native-sales.js";

export interface BurnMintProgramConfig {
  readonly manager: Address;
  readonly targetCollectionId: bigint;
  readonly phaseId: Hex;
  readonly sourceCollectionIds: readonly bigint[];
  readonly sourcesPerMint: bigint;
  readonly startsAt: bigint;
  readonly endsAt: bigint;
  readonly prepared: boolean;
  readonly nativeSaleAdapter: Address;
}

export interface BurnMintProgram {
  readonly config: BurnMintProgramConfig;
  readonly configHash: Hex;
  readonly managerCodeHash: Hex;
  readonly nativeSaleCodeHash: Hex;
}

export interface BurnMintDeployment {
  readonly gate: Address;
  readonly core: Address;
  readonly registry: Address;
}

export interface BurnMintProgramPlan extends BurnMintDeployment {
  readonly chainId: bigint;
  readonly blockNumber: number;
  readonly blockHash: Hex;
  readonly owner: Address;
  readonly gateRuntimeHash: Hex;
  readonly coreRuntimeHash: Hex;
  readonly registryRuntimeHash: Hex;
  readonly program: BurnMintProgram;
}

export interface BurnMintSourceStatus {
  readonly tokenId: bigint;
  readonly collectionId: bigint;
  readonly collectionSerial: bigint;
  readonly owner: Address;
  readonly tokenApproved: Address;
  readonly callerAuthorized: boolean;
  readonly gateApproved: boolean;
  readonly nullifier: Hex;
  readonly nullifierUnused: boolean;
  readonly liveAllowedSource: boolean;
}

export interface BurnMintSourceObservation {
  readonly blockNumber: number;
  readonly blockHash: Hex;
  readonly caller: Address;
  readonly quantity: bigint;
  readonly sources: readonly BurnMintSourceStatus[];
  readonly callerAuthorized: boolean;
  readonly gateApproved: boolean;
  readonly nullifiersUnused: boolean;
  readonly identitiesAllowed: boolean;
  readonly programAvailable: boolean;
  readonly ready: boolean;
}

export interface PreparedBurnMintCall {
  readonly caller: Address;
  readonly intent: string;
  readonly call: UnsignedCall;
}

export interface PreparedBurnMintConfiguration extends PreparedBurnMintCall {
  readonly config: BurnMintProgramConfig;
  readonly expectedConfigHash: Hex;
}

export interface PreparedNativeBurnMint {
  readonly caller: Address;
  readonly payload: SigningPayload<NativeFixedPriceSaleAuthorization>;
  readonly call: UnsignedCall;
  readonly digestCall: UnsignedCall;
  readonly sourceObservation: BurnMintSourceObservation;
  readonly executionBoundary: string;
}

export interface BurnMintRevealQuote {
  readonly coordinator: Address;
  readonly coordinatorCodeHash: Hex;
  readonly requestMode: bigint;
  readonly revealOwnerRole: Hex;
  readonly requestSLOBlocks: bigint;
  readonly revealFeePerTokenWei: bigint;
}

export interface PreparedFreeBurnMint {
  readonly caller: Address;
  readonly call: UnsignedCall;
  readonly batch: MintGateBatch;
  readonly sourceObservation: BurnMintSourceObservation;
  readonly revealQuote: BurnMintRevealQuote;
  readonly requiredRevealFee: bigint;
  readonly maximumRevealFeeAllowance: bigint;
  readonly expectedExcessCredit: bigint;
  readonly refundCreditKey: Hex;
  readonly executionBoundary: string;
}

export interface BurnMintCreditState {
  readonly accountCount: bigint;
  readonly totalLiabilities: bigint;
  readonly balance: bigint;
}

export interface BurnMintCreditPage {
  readonly saleId: Hex;
  readonly account: Address;
  readonly owed: bigint;
  readonly claimable: bigint;
  readonly nextCursor: bigint;
}

const ZERO32 = `0x${"00".repeat(32)}` as Hex;
const coder = AbiCoder.defaultAbiCoder();
const CONFIG_DOMAIN = id("6529STREAM_BURN_MINT_CONFIG_V1");
const NULLIFIER_DOMAIN = id("6529STREAM_BURN_NULLIFIER_V1");
const PROGRAM = "tuple(address manager,uint256 targetCollectionId,bytes32 phaseId,uint256[] sourceCollectionIds,uint8 sourcesPerMint,uint64 startsAt,uint64 endsAt,bool prepared,address nativeSaleAdapter)";
const SALE_AUTH = "tuple(bytes32 saleId,bytes32 saleConfigHash,address payer,address executor,address recipient,address artist,bytes32 tokenDataHash,bytes32 mintCommitment,uint256 executionNonce,bytes32 nonce,uint64 deadline,bytes32 expectedPrimaryPolicyHash)";
const SALE_EXECUTION = `tuple(${SALE_AUTH} authorization,bytes tokenData,bytes platformSignature,bytes artistSignature)`;
const MINT_BATCH = "tuple(uint256 collectionId,bytes32 phaseId,address payer,address authorizer,address[] initialRecipients,address[] beneficiaries,bytes[] tokenData,bytes32[] mintCommitments,bytes32 expectedPolicyHash,bytes32 authorizationId,bytes32 contextHash,bytes resolverData)";
const PHASE_GATE = "tuple(address gate,bytes32 gateConfigHash,bytes32 gateCodehash,bytes32 gateMetadataHash,uint32 gateSemanticVersion,uint32 gateGasLimit)";
const GATE_INTERFACE = new Interface([
  `function configureProgram(${PROGRAM}) returns (bytes32)`,
  `function program(uint256) view returns (tuple(${PROGRAM} config,bytes32 configHash,bytes32 managerCodeHash,bytes32 nativeSaleCodeHash))`,
  "function allowedSourceCollections(uint256) view returns (uint256[])",
  "function owner() view returns (address)",
  "function core() view returns (address)",
  "function moduleRegistry() view returns (address)",
  "function coreCodeHash() view returns (bytes32)",
  "function registryCodeHash() view returns (bytes32)",
  `function burnAndMint(${MINT_BATCH},uint256[]) payable returns (uint256[],bytes32,bytes32[])`,
  "function saleRevealQuote(bytes32) view returns (tuple(address coordinator,bytes32 coordinatorCodeHash,tuple(bool declared,uint8 requestMode,bytes32 revealOwnerRole,uint64 requestSLOBlocks,uint256 revealFeePerTokenWei) policy))",
  "function refundableBalance(bytes32,address) view returns (uint256)",
  "function claimRefund(bytes32,address)",
  "function nativeSaleCreditState() view returns (tuple(uint256 accountCount,uint256 totalLiabilities,uint256 balance))",
  "function nativeSaleCreditPage(uint256,uint256,uint256) view returns (tuple(bytes32 saleId,address account,uint256 owed,uint256 claimable,uint256 nextCursor))",
]);
const CORE_INTERFACE = new Interface([
  "function collectionExists(uint256) view returns (bool)",
  "function tokenCollectionIdentity(uint256) view returns (bool,uint256,uint256,bool)",
  "function ownerOf(uint256) view returns (address)",
  "function getApproved(uint256) view returns (address)",
  "function isApprovedForAll(address,address) view returns (bool)",
  "function getSatellitePointer(bytes32) view returns (address,bytes32,bool,bytes32,bytes4,address,uint8,bytes32,bytes32,uint64)",
]);
const MANAGER_INTERFACE = new Interface([
  "function core() view returns (address)",
  "function moduleRegistry() view returns (address)",
  "function isNullifierUsed(bytes32) view returns (bool)",
  `function phaseGate(uint256,bytes32) view returns (${PHASE_GATE})`,
]);
const SALE_INTERFACE = new Interface([
  `function authorizationDigest(${SALE_AUTH}) view returns (bytes32)`,
  `function purchaseWithBurn(${SALE_EXECUTION},uint256[]) payable returns (tuple(bytes32 candidateCommitment,bytes32 settlementKey,bytes32 profileId,address wallet,address asset,uint256 amount,address executor,bytes32 executionId,bool escrowed,bytes32 operationIdentityCommitment,bytes32 currentPolicyHash,bytes32 boundPolicyHash),uint256)`,
  "function core() view returns (address)",
  "function mintManager() view returns (address)",
  "function moduleRegistry() view returns (address)",
  "function saleRecord(bytes32) view returns (tuple(tuple(uint256 collectionId,bytes32 phaseId,uint256 price,uint64 startsAt,uint64 endsAt,bytes32 mintPolicyHash,bytes32 primaryAssignmentHash) config,uint256 saleNonce,bytes32 configHash,tuple(uint64 saleCreatedAt,uint64 saleAdapterRegistryRevision) lifecycle,bool cancelled))",
]);

function exactKeys(value: unknown, keys: readonly string[], name: string): asserts value is Record<string, unknown> {
  if (value === null || typeof value !== "object" || Array.isArray(value)
    || Object.keys(value).sort().join(",") !== [...keys].sort().join(",")) {
    throw new Error(`${name} contains missing or unknown properties`);
  }
}

function uint(value: unknown, bits: number, name: string, nonzero = false): bigint {
  if (typeof value !== "bigint" || value < 0n || value >= 1n << BigInt(bits) || (nonzero && value === 0n)) {
    throw new Error(`${name} must be ${nonzero ? "a positive" : "a nonnegative"} bigint fitting uint${bits}`);
  }
  return value;
}

function address(value: unknown, name: string, allowZero = false): Address {
  if (typeof value !== "string") throw new Error(`${name} must be an address string`);
  const normalized = getAddress(value) as Address;
  if (!allowZero && normalized === ZeroAddress) throw new Error(`${name} must be nonzero`);
  return normalized;
}

function hash(value: unknown, name: string, allowZero = true): Hex {
  if (typeof value !== "string" || !isHexString(value, 32)
    || (!allowZero && value.toLowerCase() === ZERO32)) throw new Error(`${name} must be ${allowZero ? "a" : "a nonzero"} bytes32`);
  return value as Hex;
}

function hexBytes(value: unknown, name: string, maximum = 1_048_576): Hex {
  if (typeof value !== "string" || !isHexString(value) || (value.length - 2) % 2 !== 0 || (value.length - 2) / 2 > maximum) {
    throw new Error(`${name} must contain complete hex bytes no longer than ${maximum} bytes`);
  }
  return value as Hex;
}

function same(a: string, b: string): boolean { return a.toLowerCase() === b.toLowerCase(); }
function runtimeHash(code: string, name: string): Hex {
  if (typeof code !== "string" || !isHexString(code) || code === "0x") throw new Error(`${name} has no contract runtime`);
  return keccak256(code) as Hex;
}
function concreteBlock(value: number): number {
  if (!Number.isSafeInteger(value) || value < 0) throw new Error("A concrete nonnegative block number is required");
  return value;
}
function frozenCall(to: Address, data: Hex, value = 0n): UnsignedCall {
  return Object.freeze({ to: address(to, "call target"), data: hexBytes(data, "call data", 8_388_608), value: uint(value, 256, "call value") });
}

export function normalizeBurnMintProgramConfig(input: BurnMintProgramConfig): BurnMintProgramConfig {
  exactKeys(input, ["manager", "targetCollectionId", "phaseId", "sourceCollectionIds", "sourcesPerMint", "startsAt", "endsAt", "prepared", "nativeSaleAdapter"], "burn-mint program config");
  if (!Array.isArray(input.sourceCollectionIds) || input.sourceCollectionIds.length === 0 || input.sourceCollectionIds.length > 64) {
    throw new Error("sourceCollectionIds must contain 1..64 sorted collection IDs");
  }
  const sourceCollectionIds = input.sourceCollectionIds.map((item, index) => uint(item, 256, `sourceCollectionIds[${index}]`, true));
  for (let i = 1; i < sourceCollectionIds.length; ++i) {
    if (sourceCollectionIds[i]! <= sourceCollectionIds[i - 1]!) throw new Error("sourceCollectionIds must be strictly increasing");
  }
  const sourcesPerMint = uint(input.sourcesPerMint, 8, "sourcesPerMint", true);
  if (sourcesPerMint > 16n) throw new Error("sourcesPerMint exceeds the 16-source gate limit");
  const startsAt = uint(input.startsAt, 64, "startsAt"), endsAt = uint(input.endsAt, 64, "endsAt");
  if (endsAt !== 0n && endsAt < startsAt) throw new Error("endsAt precedes startsAt");
  if (typeof input.prepared !== "boolean") throw new Error("prepared must be boolean");
  const nativeSaleAdapter = address(input.nativeSaleAdapter, "nativeSaleAdapter", true);
  if (nativeSaleAdapter !== ZeroAddress && input.prepared) throw new Error("Native paid burn programs cannot use prepared minting");
  return Object.freeze({ manager: address(input.manager, "manager"), targetCollectionId: uint(input.targetCollectionId, 256, "targetCollectionId", true),
    phaseId: hash(input.phaseId, "phaseId", false), sourceCollectionIds: Object.freeze(sourceCollectionIds), sourcesPerMint,
    startsAt, endsAt, prepared: input.prepared, nativeSaleAdapter });
}

export function burnMintProgramConfigHash(chainId: bigint, gate: Address, core: Address, registry: Address, config: BurnMintProgramConfig): Hex {
  return keccak256(coder.encode(["bytes32", "uint256", "address", "address", "address", PROGRAM],
    [CONFIG_DOMAIN, uint(chainId, 256, "chainId", true), address(gate, "gate"), address(core, "core"),
      address(registry, "registry"), normalizeBurnMintProgramConfig(config)])) as Hex;
}

export function burnMintNullifier(chainId: bigint, core: Address, sourceTokenId: bigint): Hex {
  return keccak256(coder.encode(["bytes32", "uint256", "address", "uint256"],
    [NULLIFIER_DOMAIN, uint(chainId, 256, "chainId", true), address(core, "core"), uint(sourceTokenId, 256, "sourceTokenId", true)])) as Hex;
}

export function normalizeBurnMintSources(sourceTokenIds: readonly bigint[], sourcesPerMint: bigint, quantity: bigint): readonly bigint[] {
  if (!Array.isArray(sourceTokenIds) || sourceTokenIds.length === 0 || sourceTokenIds.length > 16) throw new Error("Burn source list must contain 1..16 token IDs");
  const ratio = uint(sourcesPerMint, 8, "sourcesPerMint", true), count = uint(quantity, 64, "quantity", true);
  if (ratio > 16n || count > 10n || BigInt(sourceTokenIds.length) !== ratio * count) throw new Error("Burn source count differs from quantity times sourcesPerMint");
  const copy = sourceTokenIds.map((item, index) => uint(item, 256, `sourceTokenIds[${index}]`, true));
  for (let i = 1; i < copy.length; ++i) if (copy[i]! <= copy[i - 1]!) throw new Error("Burn source token IDs must be strictly increasing");
  return Object.freeze(copy);
}

function normalizeProgram(value: BurnMintProgram): BurnMintProgram {
  exactKeys(value, ["config", "configHash", "managerCodeHash", "nativeSaleCodeHash"], "burn-mint program");
  const config = normalizeBurnMintProgramConfig(value.config);
  const nativeSaleCodeHash = hash(value.nativeSaleCodeHash, "nativeSaleCodeHash");
  if ((config.nativeSaleAdapter === ZeroAddress) !== (nativeSaleCodeHash.toLowerCase() === ZERO32)) {
    throw new Error("Native sale adapter and runtime commitment disagree");
  }
  return Object.freeze({ config, configHash: hash(value.configHash, "configHash", false),
    managerCodeHash: hash(value.managerCodeHash, "managerCodeHash", false), nativeSaleCodeHash });
}

function normalizeFreeBatch(value: MintGateBatch, config: BurnMintProgramConfig): MintGateBatch {
  exactKeys(value, ["collectionId", "phaseId", "payer", "authorizer", "initialRecipients", "beneficiaries", "tokenData",
    "mintCommitments", "expectedPolicyHash", "authorizationId", "contextHash", "resolverData"], "free burn mint batch");
  if (!Array.isArray(value.initialRecipients) || !Array.isArray(value.beneficiaries) || !Array.isArray(value.tokenData)
    || !Array.isArray(value.mintCommitments)) throw new Error("Free burn mint batch arrays are required");
  const quantity = value.beneficiaries.length;
  if (quantity === 0 || quantity > 10 || value.initialRecipients.length !== quantity || value.tokenData.length !== quantity
    || value.mintCommitments.length !== quantity) throw new Error("Free burn mint batch arrays must have the same length from 1 to 10");
  const payer = address(value.payer, "payer", true), authorizer = address(value.authorizer, "authorizer", true);
  if (payer !== ZeroAddress || authorizer !== ZeroAddress) throw new Error("Free burn mint payer and authorizer must be zero");
  const initialRecipients = value.initialRecipients.map((item, index) => address(item, `initialRecipients[${index}]`));
  const beneficiaries = value.beneficiaries.map((item, index) => address(item, `beneficiaries[${index}]`));
  if (initialRecipients.some((item, index) => !same(item, beneficiaries[index]!))) throw new Error("Free burn mint initial recipients must equal beneficiaries");
  const tokenData = value.tokenData.map((item, index) => hexBytes(item, `tokenData[${index}]`));
  if (tokenData.reduce((sum, item) => sum + (item.length - 2) / 2, 0) > 4_194_304) throw new Error("Free burn tokenData exceeds the 4 MiB client boundary");
  const mintCommitments = value.mintCommitments.map((item, index) => hash(item, `mintCommitments[${index}]`));
  const collectionId = uint(value.collectionId, 256, "collectionId", true), phaseId = hash(value.phaseId, "phaseId", false);
  if (collectionId !== config.targetCollectionId || !same(phaseId, config.phaseId)) throw new Error("Free batch collection or phase differs from immutable program");
  return Object.freeze({ collectionId, phaseId, payer, authorizer, initialRecipients: Object.freeze(initialRecipients),
    beneficiaries: Object.freeze(beneficiaries), tokenData: Object.freeze(tokenData), mintCommitments: Object.freeze(mintCommitments),
    expectedPolicyHash: hash(value.expectedPolicyHash, "expectedPolicyHash", false), authorizationId: hash(value.authorizationId, "authorizationId", false),
    contextHash: hash(value.contextHash, "contextHash"), resolverData: hexBytes(value.resolverData, "resolverData", 4_194_304) });
}

function resultConfig(value: any): BurnMintProgramConfig {
  return { manager: value.manager, targetCollectionId: value.targetCollectionId, phaseId: value.phaseId,
    sourceCollectionIds: Array.from(value.sourceCollectionIds), sourcesPerMint: value.sourcesPerMint,
    startsAt: value.startsAt, endsAt: value.endsAt, prepared: value.prepared, nativeSaleAdapter: value.nativeSaleAdapter };
}

function resultProgram(value: any): BurnMintProgram {
  return normalizeProgram({ config: resultConfig(value.config), configHash: value.configHash,
    managerCodeHash: value.managerCodeHash, nativeSaleCodeHash: value.nativeSaleCodeHash });
}

function normalizeDeployment(value: BurnMintDeployment): BurnMintDeployment {
  exactKeys(value, ["gate", "core", "registry"], "burn-mint deployment");
  const result = Object.freeze({ gate: address(value.gate, "gate"), core: address(value.core, "core"), registry: address(value.registry, "registry") });
  if (new Set(Object.values(result).map(item => item.toLowerCase())).size !== 3) throw new Error("Gate, Core and registry must be distinct");
  return result;
}

export class CurrentBurnMintClient {
  readonly chainId: bigint;
  readonly deployment: BurnMintDeployment;
  readonly #plans = new WeakSet<BurnMintProgramPlan>();

  constructor(chainId: bigint, deployment: BurnMintDeployment) {
    this.chainId = uint(chainId, 256, "chainId", true);
    this.deployment = normalizeDeployment(deployment);
  }

  #plan(plan: BurnMintProgramPlan): void {
    if (!this.#plans.has(plan) || plan.chainId !== this.chainId || !same(plan.gate, this.deployment.gate)
      || !same(plan.core, this.deployment.core) || !same(plan.registry, this.deployment.registry)) throw new Error("Burn-mint plan belongs to another client or deployment");
  }

  async #block(provider: Pick<Provider, "getBlock">, tag: BlockTag): Promise<{ number: number; hash: Hex; timestamp: bigint }> {
    const block = await provider.getBlock(tag);
    if (!block?.hash) throw new Error("Pinned block is unavailable");
    return { number: concreteBlock(block.number), hash: hash(block.hash, "block hash", false), timestamp: BigInt(block.timestamp) };
  }

  async #read(provider: Pick<Provider, "call">, target: Address, iface: Interface, method: string, args: readonly unknown[], blockTag: number): Promise<any> {
    const data = iface.encodeFunctionData(method, args);
    const output = await provider.call({ to: target, data, blockTag });
    const result = iface.decodeFunctionResult(method, output);
    if (!same(iface.encodeFunctionResult(method, result), output)) throw new Error(`Noncanonical ${method} return data`);
    return result;
  }

  #configure(config: BurnMintProgramConfig): UnsignedCall {
    return frozenCall(this.deployment.gate, GATE_INTERFACE.encodeFunctionData("configureProgram", [config]) as Hex);
  }

  configureProgram(config: BurnMintProgramConfig, caller: Address): PreparedBurnMintConfiguration {
    const normalized = normalizeBurnMintProgramConfig(config);
    return Object.freeze({ caller: address(caller, "program operator"), intent: "Initial-only burn-to-mint program configuration by the gate owner",
      call: this.#configure(normalized), config: normalized,
      expectedConfigHash: burnMintProgramConfigHash(this.chainId, this.deployment.gate, this.deployment.core, this.deployment.registry, normalized) });
  }

  async captureProgram(provider: Pick<Provider, "getNetwork" | "getBlock" | "getCode" | "call">,
    targetCollectionId: bigint, blockTag: BlockTag = "latest"): Promise<BurnMintProgramPlan> {
    const target = uint(targetCollectionId, 256, "targetCollectionId", true);
    const block = await this.#block(provider, blockTag), at = block.number;
    const network = await provider.getNetwork();
    if (network.chainId !== this.chainId) throw new Error("RPC chain differs from burn-mint client");
    const [gateCode, coreCode, registryCode, gateCore, gateRegistry, pinnedCoreHash, pinnedRegistryHash, owner, rawProgram, rawAllowed] = await Promise.all([
      provider.getCode(this.deployment.gate, at), provider.getCode(this.deployment.core, at), provider.getCode(this.deployment.registry, at),
      this.#read(provider, this.deployment.gate, GATE_INTERFACE, "core", [], at),
      this.#read(provider, this.deployment.gate, GATE_INTERFACE, "moduleRegistry", [], at),
      this.#read(provider, this.deployment.gate, GATE_INTERFACE, "coreCodeHash", [], at),
      this.#read(provider, this.deployment.gate, GATE_INTERFACE, "registryCodeHash", [], at),
      this.#read(provider, this.deployment.gate, GATE_INTERFACE, "owner", [], at),
      this.#read(provider, this.deployment.gate, GATE_INTERFACE, "program", [target], at),
      this.#read(provider, this.deployment.gate, GATE_INTERFACE, "allowedSourceCollections", [target], at),
    ]);
    const gateRuntimeHash = runtimeHash(gateCode, "gate"), coreRuntimeHash = runtimeHash(coreCode, "Core"), registryRuntimeHash = runtimeHash(registryCode, "registry");
    if (!same(gateCore[0], this.deployment.core) || !same(gateRegistry[0], this.deployment.registry)
      || !same(pinnedCoreHash[0], coreRuntimeHash) || !same(pinnedRegistryHash[0], registryRuntimeHash)) throw new Error("Gate immutable dependency identity differs");
    const program = resultProgram(rawProgram[0]);
    if (program.config.targetCollectionId !== target || !same(program.configHash,
      burnMintProgramConfigHash(this.chainId, this.deployment.gate, this.deployment.core, this.deployment.registry, program.config))) {
      throw new Error("Stored burn-mint program differs from its canonical config commitment");
    }
    const allowed = Array.from(rawAllowed[0] as readonly bigint[]);
    if (allowed.length !== program.config.sourceCollectionIds.length
      || allowed.some((item, index) => item !== program.config.sourceCollectionIds[index])) throw new Error("Allowed source collection read differs from immutable program");
    const managerCode = await provider.getCode(program.config.manager, at), managerRuntimeHash = runtimeHash(managerCode, "Manager");
    if (!same(managerRuntimeHash, program.managerCodeHash)) throw new Error("Manager runtime differs from program pin");
    const [managerCore, managerRegistry, registryPointer, managerPointer, phaseGate, targetExists, ...sourceExists] = await Promise.all([
      this.#read(provider, program.config.manager, MANAGER_INTERFACE, "core", [], at),
      this.#read(provider, program.config.manager, MANAGER_INTERFACE, "moduleRegistry", [], at),
      this.#read(provider, this.deployment.core, CORE_INTERFACE, "getSatellitePointer", [id("MODULE_REGISTRY")], at),
      this.#read(provider, this.deployment.core, CORE_INTERFACE, "getSatellitePointer", [id("MINT_MANAGER")], at),
      this.#read(provider, program.config.manager, MANAGER_INTERFACE, "phaseGate", [target, program.config.phaseId], at),
      this.#read(provider, this.deployment.core, CORE_INTERFACE, "collectionExists", [target], at),
      ...program.config.sourceCollectionIds.map(source => this.#read(provider, this.deployment.core, CORE_INTERFACE, "collectionExists", [source], at)),
    ]);
    if (!same(managerCore[0], this.deployment.core) || !same(managerRegistry[0], this.deployment.registry)
      || !same(registryPointer[0], this.deployment.registry) || !same(registryPointer[1], registryRuntimeHash)
      || !same(managerPointer[0], program.config.manager) || !same(managerPointer[1], managerRuntimeHash)) throw new Error("Current Core/Manager dependency selection differs from program");
    const phase = phaseGate[0];
    if (!same(phase.gate, this.deployment.gate) || !same(phase.gateConfigHash, program.configHash)
      || !same(phase.gateCodehash, gateRuntimeHash)) throw new Error("Manager phase does not pin this exact burn-mint program");
    if (targetExists[0] !== true || sourceExists.some(item => item[0] !== true)) throw new Error("Program references an unavailable collection");
    if (program.config.nativeSaleAdapter !== ZeroAddress) {
      const nativeCode = await provider.getCode(program.config.nativeSaleAdapter, at);
      if (!same(runtimeHash(nativeCode, "native sale adapter"), program.nativeSaleCodeHash)) throw new Error("Native sale adapter runtime differs from program pin");
      const [saleCore, saleManager, saleRegistry] = await Promise.all([
        this.#read(provider, program.config.nativeSaleAdapter, SALE_INTERFACE, "core", [], at),
        this.#read(provider, program.config.nativeSaleAdapter, SALE_INTERFACE, "mintManager", [], at),
        this.#read(provider, program.config.nativeSaleAdapter, SALE_INTERFACE, "moduleRegistry", [], at),
      ]);
      if (!same(saleCore[0], this.deployment.core) || !same(saleManager[0], program.config.manager)
        || !same(saleRegistry[0], this.deployment.registry)) throw new Error("Native sale adapter dependency identity differs");
    }
    if (!same((await provider.getBlock(at))?.hash ?? "", block.hash)) throw new Error("Pinned capture block changed");
    const plan = Object.freeze({ chainId: this.chainId, blockNumber: at, blockHash: block.hash, ...this.deployment,
      owner: address(owner[0], "gate owner", true), gateRuntimeHash, coreRuntimeHash, registryRuntimeHash, program }) as BurnMintProgramPlan;
    this.#plans.add(plan);
    return plan;
  }

  async #assertCurrent(provider: Pick<Provider, "getCode" | "call">, plan: BurnMintProgramPlan, at: number): Promise<void> {
    const config = plan.program.config;
    const [gateCode, coreCode, registryCode, managerCode, rawProgram, rawAllowed, registryPointer, managerPointer, phaseGate,
      managerCore, managerRegistry] = await Promise.all([
      provider.getCode(plan.gate, at), provider.getCode(plan.core, at), provider.getCode(plan.registry, at), provider.getCode(config.manager, at),
      this.#read(provider, plan.gate, GATE_INTERFACE, "program", [config.targetCollectionId], at),
      this.#read(provider, plan.gate, GATE_INTERFACE, "allowedSourceCollections", [config.targetCollectionId], at),
      this.#read(provider, plan.core, CORE_INTERFACE, "getSatellitePointer", [id("MODULE_REGISTRY")], at),
      this.#read(provider, plan.core, CORE_INTERFACE, "getSatellitePointer", [id("MINT_MANAGER")], at),
      this.#read(provider, config.manager, MANAGER_INTERFACE, "phaseGate", [config.targetCollectionId, config.phaseId], at),
      this.#read(provider, config.manager, MANAGER_INTERFACE, "core", [], at),
      this.#read(provider, config.manager, MANAGER_INTERFACE, "moduleRegistry", [], at),
    ]);
    if (!same(runtimeHash(gateCode, "gate"), plan.gateRuntimeHash) || !same(runtimeHash(coreCode, "Core"), plan.coreRuntimeHash)
      || !same(runtimeHash(registryCode, "registry"), plan.registryRuntimeHash)
      || !same(runtimeHash(managerCode, "Manager"), plan.program.managerCodeHash)) throw new Error("Pinned burn-mint runtime changed");
    const current = resultProgram(rawProgram[0]), allowed = Array.from(rawAllowed[0] as readonly bigint[]);
    if (!same(current.configHash, plan.program.configHash) || !same(current.managerCodeHash, plan.program.managerCodeHash)
      || !same(current.nativeSaleCodeHash, plan.program.nativeSaleCodeHash)
      || allowed.length !== config.sourceCollectionIds.length || allowed.some((item, index) => item !== config.sourceCollectionIds[index])) {
      throw new Error("Pinned burn-mint program changed");
    }
    const phase = phaseGate[0];
    if (!same(registryPointer[0], plan.registry) || !same(registryPointer[1], plan.registryRuntimeHash)
      || !same(managerPointer[0], config.manager) || !same(managerPointer[1], plan.program.managerCodeHash)
      || !same(phase.gate, plan.gate) || !same(phase.gateConfigHash, plan.program.configHash)
      || !same(phase.gateCodehash, plan.gateRuntimeHash) || !same(managerCore[0], plan.core)
      || !same(managerRegistry[0], plan.registry)) throw new Error("Current burn-mint dependency selection changed");
    if (config.nativeSaleAdapter !== ZeroAddress) {
      const nativeCode = await provider.getCode(config.nativeSaleAdapter, at);
      if (!same(runtimeHash(nativeCode, "native sale adapter"), plan.program.nativeSaleCodeHash)) throw new Error("Pinned native sale runtime changed");
      const [saleCore, saleManager, saleRegistry] = await Promise.all([
        this.#read(provider, config.nativeSaleAdapter, SALE_INTERFACE, "core", [], at),
        this.#read(provider, config.nativeSaleAdapter, SALE_INTERFACE, "mintManager", [], at),
        this.#read(provider, config.nativeSaleAdapter, SALE_INTERFACE, "moduleRegistry", [], at),
      ]);
      if (!same(saleCore[0], plan.core) || !same(saleManager[0], config.manager) || !same(saleRegistry[0], plan.registry)) {
        throw new Error("Current native sale dependency identity changed");
      }
    }
  }

  async inspectSources(provider: Pick<Provider, "getNetwork" | "getBlock" | "getCode" | "call">, plan: BurnMintProgramPlan,
    caller: Address, sourceTokenIds: readonly bigint[], quantity: bigint, blockTag: BlockTag = "latest"): Promise<BurnMintSourceObservation> {
    this.#plan(plan);
    const actor = address(caller, "burn caller"), count = uint(quantity, 64, "quantity", true);
    const sources = normalizeBurnMintSources(sourceTokenIds, plan.program.config.sourcesPerMint, count);
    const block = await this.#block(provider, blockTag), at = block.number, network = await provider.getNetwork();
    if (network.chainId !== this.chainId) throw new Error("RPC chain differs from burn-mint plan");
    await this.#assertCurrent(provider, plan, at);
    const preliminary = await Promise.all(sources.map(async tokenId => {
      const nullifier = burnMintNullifier(this.chainId, plan.core, tokenId);
      const [identity, owner, approved, used] = await Promise.all([
        this.#read(provider, plan.core, CORE_INTERFACE, "tokenCollectionIdentity", [tokenId], at),
        this.#read(provider, plan.core, CORE_INTERFACE, "ownerOf", [tokenId], at),
        this.#read(provider, plan.core, CORE_INTERFACE, "getApproved", [tokenId], at),
        this.#read(provider, plan.program.config.manager, MANAGER_INTERFACE, "isNullifierUsed", [nullifier], at),
      ]);
      return { tokenId, mappingExists: identity[0] as boolean, collectionId: identity[1] as bigint,
        collectionSerial: identity[2] as bigint, burned: identity[3] as boolean,
        owner: address(owner[0], "source owner"), tokenApproved: address(approved[0], "token approval", true),
        nullifier, nullifierUnused: used[0] !== true };
    }));
    const rows = await Promise.all(preliminary.map(async item => {
      const [callerOperator, gateOperator] = await Promise.all([
        this.#read(provider, plan.core, CORE_INTERFACE, "isApprovedForAll", [item.owner, actor], at),
        this.#read(provider, plan.core, CORE_INTERFACE, "isApprovedForAll", [item.owner, plan.gate], at),
      ]);
      const liveAllowedSource = item.mappingExists && !item.burned && plan.program.config.sourceCollectionIds.includes(item.collectionId);
      return Object.freeze({ tokenId: item.tokenId, collectionId: item.collectionId, collectionSerial: item.collectionSerial,
        owner: item.owner, tokenApproved: item.tokenApproved,
        callerAuthorized: same(actor, item.owner) || same(actor, item.tokenApproved) || callerOperator[0] === true,
        gateApproved: same(plan.gate, item.tokenApproved) || gateOperator[0] === true,
        nullifier: item.nullifier, nullifierUnused: item.nullifierUnused, liveAllowedSource });
    }));
    const timestamp = block.timestamp, programAvailable = timestamp >= plan.program.config.startsAt
      && (plan.program.config.endsAt === 0n || timestamp <= plan.program.config.endsAt);
    const callerAuthorized = rows.every(row => row.callerAuthorized), gateApproved = rows.every(row => row.gateApproved);
    const nullifiersUnused = rows.every(row => row.nullifierUnused), identitiesAllowed = rows.every(row => row.liveAllowedSource);
    if (!same((await provider.getBlock(at))?.hash ?? "", block.hash)) throw new Error("Pinned source inspection block changed");
    return Object.freeze({ blockNumber: at, blockHash: block.hash, caller: actor, quantity: count, sources: Object.freeze(rows),
      callerAuthorized, gateApproved, nullifiersUnused, identitiesAllowed, programAvailable,
      ready: callerAuthorized && gateApproved && nullifiersUnused && identitiesAllowed && programAvailable });
  }

  async prepareNativePurchaseWithBurn(provider: Pick<Provider, "getNetwork" | "getBlock" | "getCode" | "call">,
    plan: BurnMintProgramPlan, sourceTokenIds: readonly bigint[], authorization: NativeFixedPriceSaleAuthorization,
    input: NativeImmediateSaleInput, blockTag: BlockTag = "latest"): Promise<PreparedNativeBurnMint> {
    this.#plan(plan);
    const config = plan.program.config;
    if (config.nativeSaleAdapter === ZeroAddress) throw new Error("Program selects the free burn route");
    const sources = normalizeBurnMintSources(sourceTokenIds, config.sourcesPerMint, 1n);
    exactKeys(input, ["tokenData", "platformSignature", "artistSignature", "saleAmount", "revealFeeAllowance"], "native burn sale input");
    const clonedInput = Object.freeze({ tokenData: hexBytes(input.tokenData, "tokenData"),
      platformSignature: hexBytes(input.platformSignature, "platformSignature", 65_536),
      artistSignature: hexBytes(input.artistSignature, "artistSignature", 65_536),
      saleAmount: uint(input.saleAmount, 256, "saleAmount"), revealFeeAllowance: uint(input.revealFeeAllowance, 256, "revealFeeAllowance") });
    const prepared = prepareNativeImmediateSale("nativeFixedPriceSale", this.chainId, config.nativeSaleAdapter, authorization, clonedInput);
    const buyer = address(prepared.payload.message.payer, "native payer");
    if (!same(buyer, prepared.payload.message.executor)) throw new Error("Native burn payer and executor must be the same caller");
    address(prepared.payload.message.recipient, "native recipient");
    address(prepared.payload.message.artist, "native artist");
    const block = await this.#block(provider, blockTag), at = block.number;
    const [observation, rawSale, rawDigest] = await Promise.all([
      this.inspectSources(provider, plan, buyer, sources, 1n, at),
      this.#read(provider, config.nativeSaleAdapter, SALE_INTERFACE, "saleRecord", [prepared.payload.message.saleId], at),
      this.#read(provider, config.nativeSaleAdapter, SALE_INTERFACE, "authorizationDigest", [prepared.payload.message], at),
    ]);
    if (!observation.ready) throw new Error("Burn sources are not currently authorized, approved, live and unused");
    const sale = rawSale[0];
    if (sale.saleNonce === 0n || sale.cancelled === true || sale.config.collectionId !== config.targetCollectionId
      || !same(sale.config.phaseId, config.phaseId) || !same(sale.configHash, prepared.payload.message.saleConfigHash)
      || sale.config.price !== clonedInput.saleAmount) throw new Error("Current native sale record differs from the signed burn purchase");
    if (!same(rawDigest[0], prepared.payload.digest)) throw new Error("Current native sale digest differs from signing payload");
    const execution = Object.freeze({ authorization: prepared.payload.message, tokenData: clonedInput.tokenData,
      platformSignature: clonedInput.platformSignature, artistSignature: clonedInput.artistSignature });
    const data = SALE_INTERFACE.encodeFunctionData("purchaseWithBurn", [execution, sources]) as Hex;
    if (!same((await provider.getBlock(at))?.hash ?? "", block.hash)) throw new Error("Pinned native burn preparation block changed");
    return Object.freeze({ caller: buyer, payload: prepared.payload,
      call: frozenCall(config.nativeSaleAdapter, data, prepared.call.value), digestCall: prepared.digestCall,
      sourceObservation: observation,
      executionBoundary: "The payer/executor sends purchaseWithBurn; the adapter retains payment and refund credit while the gate burns only inside its callback." });
  }

  async prepareFreeBurnMint(provider: Pick<Provider, "getNetwork" | "getBlock" | "getCode" | "call">,
    plan: BurnMintProgramPlan, caller: Address, batch: MintGateBatch, sourceTokenIds: readonly bigint[],
    maximumRevealFeeAllowance: bigint, blockTag: BlockTag = "latest"): Promise<PreparedFreeBurnMint> {
    this.#plan(plan);
    const config = plan.program.config;
    if (config.nativeSaleAdapter !== ZeroAddress) throw new Error("Program selects the native paid burn route");
    const actor = address(caller, "burn caller"), normalizedBatch = normalizeFreeBatch(batch, config);
    const quantity = BigInt(normalizedBatch.beneficiaries.length);
    const sources = normalizeBurnMintSources(sourceTokenIds, config.sourcesPerMint, quantity);
    const allowance = uint(maximumRevealFeeAllowance, 256, "maximumRevealFeeAllowance");
    const block = await this.#block(provider, blockTag), at = block.number;
    const [observation, rawQuote] = await Promise.all([
      this.inspectSources(provider, plan, actor, sources, quantity, at),
      this.#read(provider, plan.gate, GATE_INTERFACE, "saleRevealQuote", [plan.program.configHash], at),
    ]);
    if (!observation.ready) throw new Error("Burn sources are not currently authorized, approved, live and unused");
    const q = rawQuote[0];
    if (q.policy.declared !== true || q.policy.requestMode > 1n) throw new Error("Missing or unsupported reveal policy");
    const perToken = uint(q.policy.revealFeePerTokenWei, 256, "revealFeePerTokenWei");
    const required = perToken * quantity;
    if (required >= 1n << 256n || allowance < required) throw new Error("Maximum reveal fee allowance is below the current required fee");
    const revealQuote = Object.freeze({ coordinator: address(q.coordinator, "reveal coordinator"),
      coordinatorCodeHash: hash(q.coordinatorCodeHash, "coordinatorCodeHash", false), requestMode: uint(q.policy.requestMode, 8, "requestMode"),
      revealOwnerRole: hash(q.policy.revealOwnerRole, "revealOwnerRole"), requestSLOBlocks: uint(q.policy.requestSLOBlocks, 64, "requestSLOBlocks"),
      revealFeePerTokenWei: perToken });
    const data = GATE_INTERFACE.encodeFunctionData("burnAndMint", [normalizedBatch, sources]) as Hex;
    if (!same((await provider.getBlock(at))?.hash ?? "", block.hash)) throw new Error("Pinned free burn preparation block changed");
    return Object.freeze({ caller: actor, call: frozenCall(plan.gate, data, allowance), batch: normalizedBatch,
      sourceObservation: observation, revealQuote, requiredRevealFee: required, maximumRevealFeeAllowance: allowance,
      expectedExcessCredit: allowance - required, refundCreditKey: plan.program.configHash,
      executionBoundary: "The burn caller funds a maximum allowance; the live fee is forwarded and excess is credited to that caller under the immutable program hash." });
  }

  freeBurnRefundClaim(programHash: Hex, caller: Address, recipient: Address): PreparedBurnMintCall {
    const actor = address(caller, "credited caller"), to = address(recipient, "refund recipient");
    if (same(to, this.deployment.gate)) throw new Error("Refund recipient cannot be the burn-mint gate");
    const creditKey = hash(programHash, "program config hash", false);
    return Object.freeze({ caller: actor, intent: "Credited burn caller withdraws its existing excess to the selected recipient",
      call: frozenCall(this.deployment.gate, GATE_INTERFACE.encodeFunctionData("claimRefund", [creditKey, to]) as Hex) });
  }

  async readFreeBurnRefund(provider: Pick<Provider, "getNetwork" | "call">, programHash: Hex, account: Address,
    blockTag: BlockTag = "latest"): Promise<bigint> {
    const creditKey = hash(programHash, "program config hash", false), credited = address(account, "credited caller");
    if ((await provider.getNetwork()).chainId !== this.chainId) throw new Error("RPC chain differs from burn-mint client");
    const data = GATE_INTERFACE.encodeFunctionData("refundableBalance", [creditKey, credited]);
    const raw = await provider.call({ to: this.deployment.gate, data, blockTag });
    const decoded = GATE_INTERFACE.decodeFunctionResult("refundableBalance", raw);
    if (!same(GATE_INTERFACE.encodeFunctionResult("refundableBalance", decoded), raw)) throw new Error("Noncanonical refundableBalance return data");
    return decoded[0] as bigint;
  }

  async readFreeBurnCreditState(provider: Pick<Provider, "getNetwork" | "call">,
    blockTag: BlockTag = "latest"): Promise<BurnMintCreditState> {
    if ((await provider.getNetwork()).chainId !== this.chainId) throw new Error("RPC chain differs from burn-mint client");
    const data = GATE_INTERFACE.encodeFunctionData("nativeSaleCreditState");
    const raw = await provider.call({ to: this.deployment.gate, data, blockTag });
    const decoded = GATE_INTERFACE.decodeFunctionResult("nativeSaleCreditState", raw);
    if (!same(GATE_INTERFACE.encodeFunctionResult("nativeSaleCreditState", decoded), raw)) throw new Error("Noncanonical nativeSaleCreditState return data");
    const state = decoded[0];
    return Object.freeze({ accountCount: uint(state.accountCount, 256, "accountCount"),
      totalLiabilities: uint(state.totalLiabilities, 256, "totalLiabilities"), balance: uint(state.balance, 256, "balance") });
  }

  async readFreeBurnCreditPage(provider: Pick<Provider, "getNetwork" | "call">, index: bigint, cursor: bigint,
    limit: bigint, blockTag: BlockTag = "latest"): Promise<BurnMintCreditPage> {
    const normalizedIndex = uint(index, 256, "credit index"), normalizedCursor = uint(cursor, 256, "credit cursor");
    const normalizedLimit = uint(limit, 256, "credit page limit", true);
    if (normalizedLimit > 64n) throw new Error("Credit page limit must be within 1..64");
    if (normalizedCursor !== 0n) throw new Error("Current burn-mint credit rows are single-page and require cursor zero");
    if ((await provider.getNetwork()).chainId !== this.chainId) throw new Error("RPC chain differs from burn-mint client");
    const data = GATE_INTERFACE.encodeFunctionData("nativeSaleCreditPage", [normalizedIndex, normalizedCursor, normalizedLimit]);
    const raw = await provider.call({ to: this.deployment.gate, data, blockTag });
    const decoded = GATE_INTERFACE.decodeFunctionResult("nativeSaleCreditPage", raw);
    if (!same(GATE_INTERFACE.encodeFunctionResult("nativeSaleCreditPage", decoded), raw)) throw new Error("Noncanonical nativeSaleCreditPage return data");
    const page = decoded[0];
    const owed = uint(page.owed, 256, "credit owed"), claimable = uint(page.claimable, 256, "credit claimable");
    const nextCursor = uint(page.nextCursor, 256, "credit nextCursor");
    if (claimable > owed || nextCursor !== 0n) throw new Error("Invalid current burn-mint credit page");
    return Object.freeze({ saleId: hash(page.saleId, "credit saleId", false), account: address(page.account, "credit account"),
      owed, claimable, nextCursor });
  }
}
