import { AbiCoder, Interface, ZeroAddress, ZeroHash, getAddress, id, isHexString, keccak256 } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import type { UnsignedCall } from "./binding.js";
import {
  operatorDistributionBatchForSlice,
  verifyOperatorDistributionManifest,
} from "./current-distribution.js";
import type {
  OperatorDistributionBatch,
  OperatorDistributionContext,
  OperatorDistributionManifest,
  OperatorDistributionProgram,
} from "./current-distribution.js";
import { normalizeMintCounterReadPolicy } from "./current-mint-counter-reads.js";
import type { MintCounterDefinition } from "./current-mint-continuity.js";
import type { MintPolicyCounterConfig } from "./current-mint-policy-grace.js";

export const DISTRIBUTION_MERKLE_SOURCE = "5d1756eb53a28ebc5ecd24513493ce6bfe7ef62f";
export const DISTRIBUTION_MERKLE_INTERFACE_ID = "0x9f2d3027" as const;
export const DISTRIBUTION_MERKLE_ORIGINAL_INTERFACE_ID = "0xe1ceb09a" as const;
/** Allocation bounds of this client, not new protocol constraints. */
export const DISTRIBUTION_MERKLE_MAX_BYTES = 4194304;
export const DISTRIBUTION_MERKLE_MAX_ALLOWANCES = 4096;
export const DISTRIBUTION_MERKLE_MAX_PROOF_DEPTH = 64;
export const DISTRIBUTION_MERKLE_PROGRAM_TUPLE = "tuple(address operator,bytes32 slicesRoot,bytes32 supplyCounterId,bytes32 recipientCounterId,uint64 totalQuantity,uint64 perRecipientCap,uint8 deliveryMode,bool prepared)";
export const DISTRIBUTION_MERKLE_DEFINITION_TUPLE = "tuple(uint8 scope,uint8 keyMode,bytes32 capRoot,bytes32 metadataHash)";
export const DISTRIBUTION_MERKLE_COUNTER_TUPLE = "tuple(bool enabled,uint8 keyMode,uint8 capMode,uint8 deltaMode,uint64 staticCap,uint64 staticIncrement,bytes32 counterConfigHash)";
/** Source-derived internal tuple. Resolver data is the complete original Proof[][] encoding. */
export const DISTRIBUTION_MERKLE_PROOF_TUPLE = "tuple(uint64 maxCount,bool hasPriceOverride,uint256 priceOverride,bytes32[] proof)";
export const DISTRIBUTION_MERKLE_BATCH_TUPLE = "tuple(uint256 collectionId,bytes32 phaseId,address payer,address authorizer,address[] initialRecipients,address[] beneficiaries,bytes[] tokenData,bytes32[] mintCommitments,bytes32 expectedPolicyHash,bytes32 authorizationId,bytes32 contextHash,bytes resolverData)";
export const CURRENT_DISTRIBUTION_MERKLE_ABI = Object.freeze([
  `function merkleProgramHash(uint256 collectionId,bytes32 phaseId,${DISTRIBUTION_MERKLE_PROGRAM_TUPLE} program,bytes32 recipientCounterConfigHash) view returns(bytes32)`,
  `function programHash(uint256 collectionId,bytes32 phaseId,${DISTRIBUTION_MERKLE_PROGRAM_TUPLE} program) view returns(bytes32)`,
  `function sliceHash(uint256 index,${DISTRIBUTION_MERKLE_BATCH_TUPLE} batch) view returns(bytes32)`,
  "function sliceAuthorization(uint256 collectionId,bytes32 phaseId,uint256 index) view returns(bytes32)",
  `function distribute(${DISTRIBUTION_MERKLE_PROGRAM_TUPLE} program,uint256 index,bytes32[] proof,${DISTRIBUTION_MERKLE_BATCH_TUPLE} batch,bytes gateData) payable returns(uint256[] tokenIds,bytes32 root)`,
  "function claimNft(uint256 tokenId,address receiver) returns(bool)",
  "function claimNftFor(uint256 tokenId,bool walletWide,uint256 index) returns(bool)",
]);

export interface DistributionMerkleContext extends OperatorDistributionContext {
  readonly ledger: Address;
}
/** A supplied observation of counterDefinitionForManager(actualManager, counterConfigHash). */
export interface DistributionMerkleDefinitionSelection {
  readonly counterConfigHash: Hex;
  readonly exists: boolean;
  readonly definition: MintCounterDefinition;
}
export interface DistributionMerkleProgram {
  readonly manifest: OperatorDistributionManifest;
  readonly recipientDefinition: DistributionMerkleDefinitionSelection;
  readonly originalProgramHash: Hex;
  readonly applicationConfigHash: Hex;
  readonly factsVerified: false;
}
export interface DistributionMerkleCounterObservation {
  readonly counterId: Hex;
  readonly config: MintPolicyCounterConfig;
  readonly definitionExists: boolean;
  readonly definition: MintCounterDefinition;
}
/** This free-distribution client profile requires false/zero price fields. */
export interface DistributionMerkleProof {
  readonly maxCount: bigint;
  readonly hasPriceOverride: false;
  readonly priceOverride: 0n;
  readonly proof: readonly Hex[];
}
export interface DistributionMerkleAllowance {
  readonly beneficiary: Address;
  readonly maxCount: bigint;
}
export interface DistributionMerkleAllowanceEntry extends DistributionMerkleAllowance {
  readonly leaf: Hex;
  readonly proof: DistributionMerkleProof;
}
export interface DistributionMerkleAllowanceTree {
  readonly root: Hex;
  readonly entries: readonly DistributionMerkleAllowanceEntry[];
}
export interface DistributionMerkleCallInput {
  readonly program: DistributionMerkleProgram;
  readonly sliceIndex: number;
  readonly counters: readonly DistributionMerkleCounterObservation[];
  readonly proofs: readonly (readonly DistributionMerkleProof[])[];
  readonly expectedPolicyHash: Hex;
  readonly gateData: Hex;
  readonly revealFeePerTokenWei: bigint;
}
export interface DistributionMerkleCall {
  readonly kind: "distribute";
  readonly context: DistributionMerkleContext;
  readonly caller: Address;
  readonly input: DistributionMerkleCallInput;
  readonly batch: OperatorDistributionBatch;
  readonly call: UnsignedCall;
  readonly factsVerified: false;
}
export type DistributionMerkleClaimInput =
  | { readonly kind: "claimNft"; readonly tokenId: bigint; readonly receiver: Address }
  | { readonly kind: "claimNftFor"; readonly tokenId: bigint; readonly walletWide: boolean; readonly delegationIndex: bigint };
export interface DistributionMerkleClaim {
  readonly kind: "claim";
  readonly context: DistributionMerkleContext;
  readonly caller: Address;
  readonly input: DistributionMerkleClaimInput;
  readonly call: UnsignedCall;
  readonly factsVerified: false;
}
export type DistributionMerklePreparedCall = DistributionMerkleCall | DistributionMerkleClaim;

const coder = AbiCoder.defaultAbiCoder();
const abi = new Interface(CURRENT_DISTRIBUTION_MERKLE_ABI);
const ZERO = ZeroHash as Hex;

function exact(value: unknown, keys: readonly string[], label: string): void {
  if (!value || typeof value !== "object" || Array.isArray(value)) throw Error(`${label} must be an object`);
  const own = Reflect.ownKeys(value);
  if (own.length !== keys.length || own.some(key => typeof key !== "string" || !keys.includes(key))) {
    throw Error(`${label} has missing or unknown properties`);
  }
}
function uint(value: unknown, bits = 256, positive = false): bigint {
  if (typeof value !== "bigint" || value < 0n || value >= 1n << BigInt(bits) || (positive && value === 0n)) {
    throw Error(`Expected ${positive ? "positive " : ""}uint${bits} bigint`);
  }
  return value;
}
function address(value: unknown, nonzero = true): Address {
  if (typeof value !== "string") throw Error("Expected address");
  const result = getAddress(value) as Address;
  if (nonzero && result === ZeroAddress) throw Error("Expected nonzero address");
  return result;
}
function hash(value: unknown, nonzero = false): Hex {
  if (typeof value !== "string" || !isHexString(value, 32)) throw Error("Expected bytes32");
  const result = value.toLowerCase() as Hex;
  if (nonzero && result === ZERO) throw Error("Expected nonzero bytes32");
  return result;
}
function bytes(value: unknown): Hex {
  if (typeof value !== "string" || !isHexString(value, true) || (value.length - 2) / 2 > DISTRIBUTION_MERKLE_MAX_BYTES) {
    throw Error("Invalid bytes or client allocation limit exceeded");
  }
  return value.toLowerCase() as Hex;
}
function bool(value: unknown): boolean {
  if (typeof value !== "boolean") throw Error("Expected boolean");
  return value;
}
function dense(value: unknown, maximum: number, minimum = 0): readonly unknown[] {
  if (!Array.isArray(value) || value.length < minimum || value.length > maximum
      || Reflect.ownKeys(value).length !== value.length + 1) throw Error("Expected bounded dense array");
  for (let i = 0; i < value.length; i++) {
    if (!Object.hasOwn(value, i)) throw Error("Expected dense array");
  }
  return value;
}
function digest(types: readonly string[], values: readonly unknown[]): Hex {
  return keccak256(coder.encode(types, values)) as Hex;
}
function originalContext(value: DistributionMerkleContext | OperatorDistributionContext): OperatorDistributionContext {
  return Object.freeze({ chainId: uint(value.chainId, 256, true), distributor: address(value.distributor),
    core: address(value.core), manager: address(value.manager) });
}
export function normalizeDistributionMerkleContext(value: DistributionMerkleContext): DistributionMerkleContext {
  exact(value, ["chainId", "distributor", "core", "manager", "ledger"], "Distribution context");
  return Object.freeze({ ...originalContext(value), ledger: address(value.ledger) });
}

/** Structural original Program codec, including zero values accepted by the getter's ABI. */
export function normalizeDistributionMerkleOriginalProgram(value: OperatorDistributionProgram): OperatorDistributionProgram {
  exact(value, ["operator", "slicesRoot", "supplyCounterId", "recipientCounterId", "totalQuantity", "perRecipientCap", "deliveryMode", "prepared"], "Program");
  const deliveryMode = uint(value.deliveryMode, 8);
  if (deliveryMode > 1n) throw Error("Unknown original delivery mode");
  return Object.freeze({
    operator: address(value.operator, false),
    slicesRoot: hash(value.slicesRoot),
    supplyCounterId: hash(value.supplyCounterId),
    recipientCounterId: hash(value.recipientCounterId),
    totalQuantity: uint(value.totalQuantity, 64),
    perRecipientCap: uint(value.perRecipientCap, 64),
    deliveryMode,
    prepared: bool(value.prepared),
  });
}

export function normalizeDistributionMerkleDefinition(value: MintCounterDefinition): MintCounterDefinition {
  exact(value, ["scope", "keyMode", "capRoot", "metadataHash"], "Definition");
  const scope = uint(value.scope, 8);
  const keyMode = uint(value.keyMode, 8);
  if (scope > 2n || keyMode > 6n) throw Error("Unknown original counter enum");
  return Object.freeze({ scope, keyMode, capRoot: hash(value.capRoot), metadataHash: hash(value.metadataHash) });
}

export function distributionMerkleDefinitionHash(value: MintCounterDefinition): Hex {
  return digest(["bytes32", DISTRIBUTION_MERKLE_DEFINITION_TUPLE], [
    id("6529STREAM_MINT_COUNTER_DEFINITION_V1"), normalizeDistributionMerkleDefinition(value),
  ]);
}

export function normalizeDistributionMerkleDefinitionSelection(
  value: DistributionMerkleDefinitionSelection,
): DistributionMerkleDefinitionSelection {
  exact(value, ["counterConfigHash", "exists", "definition"], "Definition selection");
  return Object.freeze({ counterConfigHash: hash(value.counterConfigHash), exists: bool(value.exists),
    definition: normalizeDistributionMerkleDefinition(value.definition) });
}

function requireRecipientDefinition(value: DistributionMerkleDefinitionSelection): DistributionMerkleDefinitionSelection {
  const result = normalizeDistributionMerkleDefinitionSelection(value);
  const d = result.definition;
  if (!result.exists || d.keyMode !== 3n || d.scope === 0n || d.capRoot === ZERO || d.metadataHash === ZERO) {
    throw Error("Selected recipient definition is absent or unsupported");
  }
  if (distributionMerkleDefinitionHash(d) !== result.counterConfigHash) throw Error("Selected definition hash mismatch");
  return result;
}

export function distributionMerkleOriginalProgramHash(
  context: OperatorDistributionContext,
  collectionId: bigint,
  phaseId: Hex,
  program: OperatorDistributionProgram,
): Hex {
  exact(context, ["chainId", "distributor", "core", "manager"], "Original distribution context");
  const c = originalContext(context);
  return digest(["bytes32", "uint256", "address", "address", "address", "uint256", "bytes32", DISTRIBUTION_MERKLE_PROGRAM_TUPLE], [
    id("6529STREAM_OPERATOR_DISTRIBUTION_CONFIG_V1"), c.chainId, c.distributor, c.core, c.manager,
    uint(collectionId), hash(phaseId), normalizeDistributionMerkleOriginalProgram(program),
  ]);
}

/** The supplied selection must come from the actual Manager; this pure function cannot prove that read. */
export function distributionMerkleProgramHash(
  context: OperatorDistributionContext,
  collectionId: bigint,
  phaseId: Hex,
  program: OperatorDistributionProgram,
  selection: DistributionMerkleDefinitionSelection,
): Hex {
  const selected = requireRecipientDefinition(selection);
  return digest(["bytes32", "bytes32", "bytes32", "bytes32"], [
    id("6529STREAM_OPERATOR_DISTRIBUTION_MERKLE_CONFIG_V1"),
    distributionMerkleOriginalProgramHash(context, collectionId, phaseId, program),
    selected.counterConfigHash, selected.definition.metadataHash,
  ]);
}

/** No publication serialization or digest algorithm is mandated by the contract. This helper chooses Keccak. */
export function distributionMerklePublicationKeccak(publication: Hex): Hex {
  return keccak256(bytes(publication)) as Hex;
}

function cloneData(value: unknown, depth = 0): unknown {
  if (depth > 12) throw Error("Client object nesting limit exceeded");
  if (Array.isArray(value)) return dense(value, 4096).map(item => cloneData(item, depth + 1));
  if (value !== null && typeof value === "object") {
    const result: Record<string, unknown> = {};
    for (const key of Reflect.ownKeys(value)) {
      const descriptor = Object.getOwnPropertyDescriptor(value, key)!;
      if (typeof key !== "string" || !descriptor.enumerable || !("value" in descriptor)) throw Error("Expected ordinary immutable input data");
      result[key] = cloneData(descriptor.value, depth + 1);
    }
    return result;
  }
  if (typeof value === "string" || typeof value === "bigint" || typeof value === "boolean"
      || (typeof value === "number" && Number.isSafeInteger(value))) return value;
  throw Error("Unsupported manifest value");
}

/** Reconstructs the existing V1 token/slice manifest; its programHash remains the original V1 value. */
export function prepareDistributionMerkleProgram(
  manifest: OperatorDistributionManifest,
  selection: DistributionMerkleDefinitionSelection,
): DistributionMerkleProgram {
  const a = verifyOperatorDistributionManifest(cloneData(manifest) as OperatorDistributionManifest);
  const selected = requireRecipientDefinition(selection);
  const originalProgramHash = distributionMerkleOriginalProgramHash(a.context, a.collectionId, a.phaseId, a.program);
  if (originalProgramHash !== a.programHash) throw Error("Original program hash mismatch");
  return Object.freeze({ manifest: a, recipientDefinition: selected, originalProgramHash,
    applicationConfigHash: distributionMerkleProgramHash(a.context, a.collectionId, a.phaseId, a.program, selected),
    factsVerified: false });
}

export function normalizeDistributionMerkleProgram(value: DistributionMerkleProgram): DistributionMerkleProgram {
  exact(value, ["manifest", "recipientDefinition", "originalProgramHash", "applicationConfigHash", "factsVerified"], "Merkle program");
  const result = prepareDistributionMerkleProgram(value.manifest, value.recipientDefinition);
  if (value.factsVerified !== false || hash(value.originalProgramHash) !== result.originalProgramHash
      || hash(value.applicationConfigHash) !== result.applicationConfigHash) throw Error("Merkle program differs from inputs");
  return result;
}

export function prepareDistributionMerkleProgramRead(
  context: OperatorDistributionContext,
  collectionId: bigint,
  phaseId: Hex,
  program: OperatorDistributionProgram,
  recipientCounterConfigHash: Hex,
): UnsignedCall {
  exact(context, ["chainId", "distributor", "core", "manager"], "Original distribution context");
  const c = originalContext(context);
  return Object.freeze({ to: c.distributor, value: 0n,
    data: bytes(abi.encodeFunctionData("merkleProgramHash", [uint(collectionId), hash(phaseId),
      normalizeDistributionMerkleOriginalProgram(program), hash(recipientCounterConfigHash)])) });
}

export function normalizeDistributionMerkleProof(value: DistributionMerkleProof): DistributionMerkleProof {
  exact(value, ["maxCount", "hasPriceOverride", "priceOverride", "proof"], "Allowance proof");
  if (value.hasPriceOverride !== false || value.priceOverride !== 0n) {
    throw Error("Free-distribution client profile requires false/zero price fields");
  }
  return Object.freeze({
    maxCount: uint(value.maxCount, 64, true),
    hasPriceOverride: false,
    priceOverride: 0n,
    proof: Object.freeze(dense(value.proof, DISTRIBUTION_MERKLE_MAX_PROOF_DEPTH).map(item => hash(item))),
  });
}

export function normalizeDistributionMerkleProofs(
  value: readonly (readonly DistributionMerkleProof[])[],
): readonly (readonly DistributionMerkleProof[])[] {
  return Object.freeze(dense(value, 16, 1).map(row => Object.freeze(
    dense(row, 10, 1).map(item => normalizeDistributionMerkleProof(item as DistributionMerkleProof)),
  )));
}

/** Canonical encoding is this client's presentation policy; the original batch decoder is more permissive. */
export function encodeDistributionMerkleProofs(value: readonly (readonly DistributionMerkleProof[])[]): Hex {
  return bytes(coder.encode([`${DISTRIBUTION_MERKLE_PROOF_TUPLE}[][]`], [normalizeDistributionMerkleProofs(value)]));
}

export function decodeDistributionMerkleProofs(value: Hex): readonly (readonly DistributionMerkleProof[])[] {
  const raw = bytes(value);
  const decoded = coder.decode([`${DISTRIBUTION_MERKLE_PROOF_TUPLE}[][]`], raw)[0];
  if (decoded.length > 16) throw Error("Too many phase Merkle counters");
  const result = normalizeDistributionMerkleProofs(Array.from(decoded as readonly unknown[], input => {
    const row = input as readonly unknown[];
    if (row.length > 10) throw Error("Too many slice beneficiaries");
    return Array.from(row, item => {
      const proof = item as readonly unknown[];
      return { maxCount: proof[0], hasPriceOverride: proof[1], priceOverride: proof[2],
        proof: Array.from(proof[3] as readonly Hex[]) } as DistributionMerkleProof;
    });
  }));
  if (encodeDistributionMerkleProofs(result) !== raw) throw Error("Noncanonical client proof presentation");
  return result;
}

export function distributionMerkleAllowanceLeaf(
  context: DistributionMerkleContext,
  collectionId: bigint,
  phaseId: Hex,
  counterId: Hex,
  beneficiary: Address,
  proof: DistributionMerkleProof,
): Hex {
  const c = normalizeDistributionMerkleContext(context);
  const p = normalizeDistributionMerkleProof(proof);
  return keccak256(digest([
    "bytes32", "uint256", "address", "uint256", "bytes32", "bytes32", "address", "uint64", "bool", "uint256",
  ], [id("6529STREAM_MINT_ALLOWLIST_LEAF_V1"), c.chainId, c.manager, uint(collectionId), hash(phaseId),
    hash(counterId), address(beneficiary), p.maxCount, false, 0n])) as Hex;
}

function pair(left: Hex, right: Hex): Hex {
  return digest(["bytes32", "bytes32"], BigInt(left) < BigInt(right) ? [left, right] : [right, left]);
}

export function verifyDistributionMerkleAllowanceProof(root: Hex, leaf: Hex, proof: readonly Hex[]): boolean {
  let current = hash(leaf);
  for (const sibling of dense(proof, DISTRIBUTION_MERKLE_MAX_PROOF_DEPTH)) current = pair(current, hash(sibling));
  return current === hash(root);
}

/** Optional client tree construction; preserves input rows and promotes unpaired nodes unchanged. */
export function buildDistributionMerkleAllowanceTree(
  context: DistributionMerkleContext,
  collectionId: bigint,
  phaseId: Hex,
  counterId: Hex,
  capCeiling: bigint,
  allowances: readonly DistributionMerkleAllowance[],
): DistributionMerkleAllowanceTree {
  const c = normalizeDistributionMerkleContext(context);
  const ceiling = uint(capCeiling, 64, true);
  const rows = dense(allowances, DISTRIBUTION_MERKLE_MAX_ALLOWANCES, 1).map(input => {
    const row = input as DistributionMerkleAllowance;
    exact(row, ["beneficiary", "maxCount"], "Allowance row");
    const maxCount = uint(row.maxCount, 64, true);
    if (maxCount > ceiling) throw Error("Allowance exceeds registered cap ceiling");
    const beneficiary = address(row.beneficiary);
    const proof: DistributionMerkleProof = { maxCount, hasPriceOverride: false, priceOverride: 0n, proof: [] };
    return { beneficiary, maxCount, leaf: distributionMerkleAllowanceLeaf(c, collectionId, phaseId, counterId, beneficiary, proof) };
  });
  const layers: Hex[][] = [rows.map(row => row.leaf)];
  while (layers.at(-1)!.length > 1) {
    const prior = layers.at(-1)!;
    const next: Hex[] = [];
    for (let i = 0; i < prior.length; i += 2) next.push(i + 1 < prior.length ? pair(prior[i]!, prior[i + 1]!) : prior[i]!);
    layers.push(next);
  }
  const entries = rows.map((row, originalIndex) => {
    const siblings: Hex[] = [];
    let index = originalIndex;
    for (let level = 0; level < layers.length - 1; level++) {
      const layer = layers[level]!;
      const sibling = index ^ 1;
      if (sibling < layer.length) siblings.push(layer[sibling]!);
      index = Math.floor(index / 2);
    }
    return Object.freeze({ ...row, proof: normalizeDistributionMerkleProof({
      maxCount: row.maxCount, hasPriceOverride: false, priceOverride: 0n, proof: siblings,
    }) });
  });
  return Object.freeze({ root: layers.at(-1)![0]!, entries: Object.freeze(entries) });
}

export function normalizeDistributionMerkleCounters(
  value: readonly DistributionMerkleCounterObservation[],
): readonly DistributionMerkleCounterObservation[] {
  const seen = new Set<Hex>();
  return Object.freeze(dense(value, 16, 1).map(input => {
    const row = input as DistributionMerkleCounterObservation;
    exact(row, ["counterId", "config", "definitionExists", "definition"], "Counter observation");
    const counterId = hash(row.counterId, true);
    if (seen.has(counterId)) throw Error("Duplicate phase counter ID");
    seen.add(counterId);
    const p = normalizeMintCounterReadPolicy({ phaseExists: true, config: row.config,
      definitionExists: row.definitionExists, definition: row.definition });
    return Object.freeze({ counterId, config: p.config, definitionExists: p.definitionExists, definition: p.definition });
  }));
}

/** Verifies complete ordered RECIPIENT Merkle groups against supplied policy facts; it does not prove those facts are live. */
export function distributionMerkleResolverData(
  context: DistributionMerkleContext,
  collectionId: bigint,
  phaseId: Hex,
  beneficiaries: readonly Address[],
  counterObservations: readonly DistributionMerkleCounterObservation[],
  proofInput: readonly (readonly DistributionMerkleProof[])[],
): Hex {
  const c = normalizeDistributionMerkleContext(context);
  const accounts = dense(beneficiaries, 10, 1).map(item => address(item));
  if (accounts.some(account => account === c.distributor)) throw Error("Distributor cannot be a beneficiary");
  const counters = normalizeDistributionMerkleCounters(counterObservations);
  const proofs = normalizeDistributionMerkleProofs(proofInput);
  const merkle = counters.filter(row => row.config.capMode === 3n);
  if (proofs.length !== merkle.length) throw Error("Proof groups differ from complete Merkle counter inventory");
  for (let i = 0; i < merkle.length; i++) {
    const row = merkle[i]!;
    const config = row.config;
    const definition = row.definition;
    if (!config.enabled || config.keyMode !== 3n || !row.definitionExists || definition.keyMode !== 3n
        || definition.scope === 0n || definition.capRoot === ZERO || config.staticCap === 0n
        || distributionMerkleDefinitionHash(definition) !== config.counterConfigHash) {
      throw Error("Unsupported RECIPIENT Merkle counter in free-distribution client profile");
    }
    const group = proofs[i]!;
    if (group.length !== accounts.length) throw Error("Proof row must retain every ordered beneficiary, including duplicates");
    for (let j = 0; j < accounts.length; j++) {
      const proof = group[j]!;
      if (proof.maxCount > config.staticCap) throw Error("Allowance exceeds registered counter ceiling");
      const leaf = distributionMerkleAllowanceLeaf(c, collectionId, phaseId, row.counterId, accounts[j]!, proof);
      if (!verifyDistributionMerkleAllowanceProof(definition.capRoot, leaf, proof.proof)) {
        throw Error("Invalid beneficiary allowance proof");
      }
    }
  }
  return encodeDistributionMerkleProofs(proofs);
}

export interface DistributionMerkleProjectedRow {
  readonly valueKey: Hex;
  readonly current: bigint;
  readonly increment: bigint;
  readonly cap: bigint;
}
export interface DistributionMerkleProjection extends DistributionMerkleProjectedRow {
  readonly projected: bigint;
}

/** Original complete-batch cap arithmetic over supplied resolved keys; no RPC or mint admission claim. */
export function distributionMerkleProjectedCaps(
  input: readonly DistributionMerkleProjectedRow[],
): readonly DistributionMerkleProjection[] {
  const rows = dense(input, 160).map(value => {
    const row = value as DistributionMerkleProjectedRow;
    exact(row, ["valueKey", "current", "increment", "cap"], "Projected counter row");
    return Object.freeze({ valueKey: hash(row.valueKey), current: uint(row.current, 64),
      increment: uint(row.increment, 64), cap: uint(row.cap, 64) });
  });
  return Object.freeze(rows.map(row => {
    const shared = rows.filter(other => other.valueKey === row.valueKey);
    if (shared.some(other => other.current !== row.current)) throw Error("Inconsistent current value for one Ledger key");
    const projected = uint(shared.reduce((sum, other) => sum + other.increment, row.current), 64);
    if (row.cap !== 0n && projected > row.cap) throw Error("Complete projected batch exceeds an applicable allowance");
    return Object.freeze({ ...row, projected });
  }));
}

function requireProgramCounters(program: DistributionMerkleProgram, counters: readonly DistributionMerkleCounterObservation[]): void {
  const p = program.manifest.program;
  const supply = counters.find(row => row.counterId === p.supplyCounterId);
  const recipient = counters.find(row => row.counterId === p.recipientCounterId);
  if (!supply || !recipient) throw Error("Required distribution counters missing");
  const s = supply.config;
  const r = recipient.config;
  if (!s.enabled || s.keyMode !== 1n || s.capMode !== 1n || s.deltaMode !== 0n
      || s.staticCap !== p.totalQuantity || s.staticIncrement !== 1n
      || !r.enabled || r.keyMode !== 3n || r.capMode !== 3n || r.deltaMode !== 0n
      || r.staticCap !== p.perRecipientCap || r.staticIncrement !== 1n) {
    throw Error("Required supply/recipient counter configuration mismatch");
  }
  // The actual Manager's resolver remains the authoritative PHASE-subject check.
  if (supply.definitionExists && supply.definition.scope !== 2n) throw Error("Supply definition must retain PHASE scope");
  const selected = program.recipientDefinition;
  if (!recipient.definitionExists || r.counterConfigHash !== selected.counterConfigHash
      || distributionMerkleDefinitionHash(recipient.definition) !== selected.counterConfigHash) {
    throw Error("Recipient counter differs from selected program definition");
  }
}

export function prepareDistributionMerkleCall(
  context: DistributionMerkleContext,
  caller: Address,
  input: DistributionMerkleCallInput,
): DistributionMerkleCall {
  const c = normalizeDistributionMerkleContext(context);
  const actor = address(caller);
  exact(input, ["program", "sliceIndex", "counters", "proofs", "expectedPolicyHash", "gateData", "revealFeePerTokenWei"], "Distribution call input");
  const program = normalizeDistributionMerkleProgram(input.program);
  const a = program.manifest;
  if (a.context.chainId !== c.chainId || a.context.distributor !== c.distributor
      || a.context.core !== c.core || a.context.manager !== c.manager || actor !== a.program.operator) {
    throw Error("Distribution caller or coordinates differ from manifest");
  }
  if (!Number.isSafeInteger(input.sliceIndex) || input.sliceIndex < 0 || input.sliceIndex >= a.slices.length) {
    throw Error("Invalid manifest slice index");
  }
  const counters = normalizeDistributionMerkleCounters(input.counters);
  requireProgramCounters(program, counters);
  const proofs = normalizeDistributionMerkleProofs(input.proofs);
  const expectedPolicyHash = hash(input.expectedPolicyHash, true);
  const gateData = bytes(input.gateData);
  const revealFeePerTokenWei = uint(input.revealFeePerTokenWei);
  const slice = a.slices[input.sliceIndex]!;
  const beneficiaries = a.tokens.slice(slice.start, slice.start + slice.count).map(row => row.beneficiary);
  const resolverData = distributionMerkleResolverData(c, a.collectionId, a.phaseId, beneficiaries, counters, proofs);
  const batch = operatorDistributionBatchForSlice(a, input.sliceIndex, { expectedPolicyHash, resolverData });
  const value = uint(revealFeePerTokenWei * BigInt(slice.count));
  const data = bytes(abi.encodeFunctionData("distribute", [a.program, slice.index, slice.proof, batch, gateData]));
  return Object.freeze({
    kind: "distribute",
    context: c,
    caller: actor,
    input: Object.freeze({ program, sliceIndex: input.sliceIndex, counters, proofs, expectedPolicyHash, gateData, revealFeePerTokenWei }),
    batch,
    call: Object.freeze({ to: c.distributor, value, data }),
    factsVerified: false,
  });
}

/** Owed-NFT authority is checked by the original call; no current phase or distribution admission is assumed. */
export function prepareDistributionMerkleClaim(
  context: DistributionMerkleContext,
  caller: Address,
  request: DistributionMerkleClaimInput,
): DistributionMerkleClaim {
  const c = normalizeDistributionMerkleContext(context);
  const actor = address(caller);
  let input: DistributionMerkleClaimInput;
  let data: Hex;
  if (request.kind === "claimNft") {
    exact(request, ["kind", "tokenId", "receiver"], "Own NFT claim");
    input = Object.freeze({ kind: request.kind, tokenId: uint(request.tokenId, 256, true), receiver: address(request.receiver) });
    if (input.receiver === c.distributor) throw Error("Claim receiver cannot be distributor");
    data = bytes(abi.encodeFunctionData("claimNft", [input.tokenId, input.receiver]));
  } else if (request.kind === "claimNftFor") {
    exact(request, ["kind", "tokenId", "walletWide", "delegationIndex"], "Delegated NFT claim");
    input = Object.freeze({ kind: request.kind, tokenId: uint(request.tokenId, 256, true),
      walletWide: bool(request.walletWide), delegationIndex: uint(request.delegationIndex) });
    data = bytes(abi.encodeFunctionData("claimNftFor", [input.tokenId, input.walletWide, input.delegationIndex]));
  } else throw Error("Unknown NFT claim method");
  return Object.freeze({ kind: "claim", context: c, caller: actor, input,
    call: Object.freeze({ to: c.distributor, value: 0n, data }), factsVerified: false });
}

export function normalizeDistributionMerklePreparedCall(value: DistributionMerklePreparedCall): DistributionMerklePreparedCall {
  exact(value, value.kind === "distribute"
    ? ["kind", "context", "caller", "input", "batch", "call", "factsVerified"]
    : ["kind", "context", "caller", "input", "call", "factsVerified"], "Prepared distribution call");
  exact(value.call, ["to", "value", "data"], "CALL");
  const result = value.kind === "distribute"
    ? prepareDistributionMerkleCall(value.context, value.caller, value.input)
    : value.kind === "claim" ? prepareDistributionMerkleClaim(value.context, value.caller, value.input)
      : (() => { throw Error("Unknown distribution call kind"); })();
  if (value.factsVerified !== false || address(value.call.to) !== result.call.to
      || uint(value.call.value) !== result.call.value || bytes(value.call.data) !== result.call.data) {
    throw Error("Prepared distribution call differs from inputs");
  }
  if (value.kind === "distribute" && result.kind === "distribute") {
    const batch = cloneData(value.batch);
    const render = (item: unknown) => JSON.stringify(item, (_, v) => typeof v === "bigint" ? v.toString() : v);
    if (render(batch) !== render(result.batch)) throw Error("Prepared batch differs from immutable inputs");
  }
  return result;
}
