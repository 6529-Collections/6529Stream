import { AbiCoder, Interface, ZeroAddress, getAddress, id, isHexString, keccak256 } from "ethers";
import type { Provider } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import type { UnsignedCall } from "./client.js";

export const OPERATOR_DISTRIBUTION_DELIVERY_MODE = Object.freeze({ DIRECT: 0n, FAILURE_ISOLATED: 1n });
export const OPERATOR_DISTRIBUTION_MAX_TOKENS = 4096;
export const OPERATOR_DISTRIBUTION_MAX_SLICE = 10;

export interface OperatorDistributionContext {
  readonly chainId: bigint;
  readonly distributor: Address;
  readonly core: Address;
  readonly manager: Address;
}

export interface OperatorDistributionProgram {
  readonly operator: Address;
  readonly slicesRoot: Hex;
  readonly supplyCounterId: Hex;
  readonly recipientCounterId: Hex;
  readonly totalQuantity: bigint;
  readonly perRecipientCap: bigint;
  readonly deliveryMode: bigint;
  readonly prepared: boolean;
}

export interface OperatorDistributionToken {
  readonly beneficiary: Address;
  readonly tokenData: Hex;
  readonly mintCommitment: Hex;
}

export interface OperatorDistributionBatch {
  readonly collectionId: bigint;
  readonly phaseId: Hex;
  readonly payer: Address;
  readonly authorizer: Address;
  readonly initialRecipients: readonly Address[];
  readonly beneficiaries: readonly Address[];
  readonly tokenData: readonly Hex[];
  readonly mintCommitments: readonly Hex[];
  readonly expectedPolicyHash: Hex;
  readonly authorizationId: Hex;
  readonly contextHash: Hex;
  readonly resolverData: Hex;
}

export interface OperatorDistributionSlice {
  readonly index: bigint;
  readonly start: number;
  readonly count: number;
  readonly sliceHash: Hex;
  readonly proof: readonly Hex[];
}

export interface OperatorDistributionManifest {
  readonly schemaVersion: 1;
  readonly profile: "STREAM_CLIENT_OPERATOR_DISTRIBUTION_MANIFEST_V1";
  readonly context: OperatorDistributionContext;
  readonly collectionId: bigint;
  readonly phaseId: Hex;
  readonly sliceQuantity: number;
  readonly manifestCompletenessReviewed: true;
  readonly program: OperatorDistributionProgram;
  readonly programHash: Hex;
  readonly tokens: readonly OperatorDistributionToken[];
  readonly slices: readonly OperatorDistributionSlice[];
}

export interface DistributionPresentation {
  readonly resolverData: Hex;
  readonly gateData: Hex;
}

export interface PreparedOperatorDistribution {
  readonly artifact: OperatorDistributionManifest;
  readonly sliceIndex: number;
  readonly presentation: DistributionPresentation;
  readonly expectedPolicyHash: Hex;
  readonly revealFeePerTokenWei: bigint;
  readonly caller: Address;
  readonly call: UnsignedCall;
  readonly checked: readonly string[];
  readonly limitations: readonly string[];
}

export interface DistributionClaimExpectation {
  readonly collectionId: bigint;
  readonly phaseId: Hex;
  readonly beneficiary: Address;
}

export interface PreparedDistributionClaim {
  readonly kind: "own" | "delegate";
  readonly chainId: bigint;
  readonly distributor: Address;
  readonly caller: Address;
  readonly tokenId: bigint;
  readonly expectedClaim: DistributionClaimExpectation;
  readonly receiver: Address;
  readonly walletWide: boolean | null;
  readonly delegationIndex: bigint | null;
  readonly call: UnsignedCall;
}

const coder = AbiCoder.defaultAbiCoder();
const ZERO32 = `0x${"00".repeat(32)}` as Hex;
const MAX_UINT256 = (1n << 256n) - 1n;
const MAX_TOKEN_DATA_BYTES = 16_384;
const MAX_TOTAL_TOKEN_DATA_BYTES = 4_194_304;
const MAX_JSON_CHARS = 16_777_216;
const programTuple = "tuple(address operator,bytes32 slicesRoot,bytes32 supplyCounterId,bytes32 recipientCounterId,uint64 totalQuantity,uint64 perRecipientCap,uint8 deliveryMode,bool prepared)";
const batchTuple = "tuple(uint256 collectionId,bytes32 phaseId,address payer,address authorizer,address[] initialRecipients,address[] beneficiaries,bytes[] tokenData,bytes32[] mintCommitments,bytes32 expectedPolicyHash,bytes32 authorizationId,bytes32 contextHash,bytes resolverData)";
const phaseTuple = "tuple(bool paused,uint64 startTime,uint64 endTime,uint32 maxBatchQuantity,bytes32 configHash,bytes32 metadataHash)";
const counterTuple = "tuple(bool enabled,uint8 keyMode,uint8 capMode,uint8 deltaMode,uint64 staticCap,uint64 staticIncrement,bytes32 counterConfigHash)";
const royaltyTuple = "tuple(bool configured,bytes32 applicationConfigHash,address resolver,bytes32 resolverRuntimeHash,bytes32 electionHash,bytes32 expectedModeAssignmentHash,bytes32 expectedSourceRoyaltyPolicyHash)";
const revealTuple = "tuple(bool declared,uint8 requestMode,bytes32 revealOwnerRole,uint64 requestSLOBlocks,uint256 revealFeePerTokenWei)";

const distributionAbi = new Interface([
  `function programHash(uint256,bytes32,${programTuple}) view returns (bytes32)`,
  `function sliceHash(uint256,${batchTuple}) view returns (bytes32)`,
  "function sliceAuthorization(uint256,bytes32,uint256) view returns (bytes32)",
  `function distribute(${programTuple},uint256,bytes32[],${batchTuple},bytes) payable returns (uint256[],bytes32)`,
  "function sliceUsed(uint256,bytes32,uint256) view returns (bool)",
  "function nftClaim(uint256) view returns (tuple(uint256 collectionId,bytes32 phaseId,address beneficiary))",
  "function claimNft(uint256,address) returns (bool)",
  "function claimNftFor(uint256,bool,uint256) returns (bool)",
  "function core() view returns (address)",
  "function manager() view returns (address)",
]);
const managerAbi = new Interface([
  "function core() view returns (address)",
  "function mintLedger() view returns (address)",
  `function phase(uint256,bytes32) view returns (bool,${phaseTuple})`,
  "function phasePolicyHash(uint256,bytes32) view returns (bytes32)",
  "function phaseExecutor(uint256,bytes32,address) view returns (bool)",
  `function counterConfig(uint256,bytes32,bytes32) view returns (${counterTuple})`,
  `function phaseRoyaltyPolicy(uint256,bytes32) view returns (${royaltyTuple})`,
  `function phaseRoyaltyConfigHash(uint256,bytes32,${royaltyTuple}) view returns (bytes32)`,
]);
const coreAbi = new Interface([
  "function getSatellitePointer(bytes32) view returns (address,bytes32,bool,bytes32,bytes4,address,uint8,bytes32,bytes32,uint64)",
]);
const entropyAbi = new Interface([
  "function core() view returns (address)",
  `function collectionRevealPolicy(uint256) view returns (${revealTuple})`,
]);

const domains = Object.freeze({
  program: id("6529STREAM_OPERATOR_DISTRIBUTION_CONFIG_V1"),
  slice: id("6529STREAM_OPERATOR_DISTRIBUTION_SLICE_V1"),
  authorization: id("6529STREAM_OPERATOR_DISTRIBUTION_AUTHORIZATION_V1"),
  mintManagerPointer: id("MINT_MANAGER"),
  entropyPointer: id("ENTROPY_COORDINATOR"),
});
const DISTRIBUTION_CHECKED = Object.freeze(["distributor Core and Manager", "Core-selected current Manager", "phase config and active policy hash", "distribution executor and exact counters", "program, slice and authorization hashes", "unused slice", "selected entropy coordinator and declared reveal fee"]);
const DISTRIBUTION_LIMITATIONS = Object.freeze(["numeric block pin has no reorg hash check", "runtime code identity, module/delegation admission and the phase time window are enforced only by simulation or execution", "inspection does not prove Safe threshold authority or future transaction acceptance"]);

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

function bytes32(value: unknown, name: string, allowZero = true): Hex {
  if (typeof value !== "string" || !isHexString(value, 32)
    || (!allowZero && value.toLowerCase() === ZERO32)) {
    throw new Error(`${name} must be ${allowZero ? "a" : "a nonzero"} bytes32`);
  }
  return value as Hex;
}

function bytes(value: unknown, name: string, maxBytes: number): Hex {
  if (typeof value !== "string" || !isHexString(value, true) || (value.length - 2) / 2 > maxBytes) {
    throw new Error(`${name} must be hex bytes no longer than ${maxBytes} bytes`);
  }
  return value as Hex;
}

function boolean(value: unknown, name: string): boolean {
  if (typeof value !== "boolean") throw new Error(`${name} must be boolean`);
  return value;
}

function same(a: unknown, b: string): boolean { return typeof a === "string" && a.toLowerCase() === b.toLowerCase(); }
function frozen<T>(values: readonly T[]): readonly T[] { return Object.freeze(Array.from(values)); }
function concreteBlock(value: unknown): number {
  if (typeof value !== "number" || !Number.isSafeInteger(value) || value < 0) throw new Error("A concrete nonnegative block number is required");
  return value;
}

function normalizeContext(value: OperatorDistributionContext): OperatorDistributionContext {
  exactKeys(value, ["chainId", "distributor", "core", "manager"], "distribution context");
  return Object.freeze({ chainId: uint(value.chainId, 256, "chainId", true), distributor: address(value.distributor, "distributor"),
    core: address(value.core, "core"), manager: address(value.manager, "manager") });
}

function normalizeProgram(value: OperatorDistributionProgram, allowEmptyRoot = false): OperatorDistributionProgram {
  exactKeys(value, ["operator", "slicesRoot", "supplyCounterId", "recipientCounterId", "totalQuantity", "perRecipientCap", "deliveryMode", "prepared"], "distribution program");
  const program = Object.freeze({ operator: address(value.operator, "operator"), slicesRoot: bytes32(value.slicesRoot, "slicesRoot", allowEmptyRoot),
    supplyCounterId: bytes32(value.supplyCounterId, "supplyCounterId", false), recipientCounterId: bytes32(value.recipientCounterId, "recipientCounterId", false),
    totalQuantity: uint(value.totalQuantity, 64, "totalQuantity", true), perRecipientCap: uint(value.perRecipientCap, 64, "perRecipientCap", true),
    deliveryMode: uint(value.deliveryMode, 8, "deliveryMode"), prepared: boolean(value.prepared, "prepared") });
  if (program.supplyCounterId.toLowerCase() === program.recipientCounterId.toLowerCase() || program.perRecipientCap > program.totalQuantity
    || (program.deliveryMode !== 0n && program.deliveryMode !== 1n)) throw new Error("Invalid distribution program counters, caps or delivery mode");
  return program;
}

function normalizeToken(value: OperatorDistributionToken, distributor: Address, index: number): OperatorDistributionToken {
  exactKeys(value, ["beneficiary", "tokenData", "mintCommitment"], `distribution token ${index}`);
  const beneficiary = address(value.beneficiary, `tokens[${index}].beneficiary`);
  if (beneficiary.toLowerCase() === distributor.toLowerCase()) throw new Error("A distribution beneficiary cannot be the distributor");
  return Object.freeze({ beneficiary, tokenData: bytes(value.tokenData, `tokens[${index}].tokenData`, MAX_TOKEN_DATA_BYTES),
    mintCommitment: bytes32(value.mintCommitment, `tokens[${index}].mintCommitment`) });
}

function normalizePresentation(value: DistributionPresentation): DistributionPresentation {
  exactKeys(value, ["resolverData", "gateData"], "distribution presentation");
  return Object.freeze({ resolverData: bytes(value.resolverData, "resolverData", MAX_TOTAL_TOKEN_DATA_BYTES),
    gateData: bytes(value.gateData, "gateData", MAX_TOTAL_TOKEN_DATA_BYTES) });
}

export function operatorDistributionProgramHash(context: OperatorDistributionContext, collectionId: bigint, phaseId: Hex, program: OperatorDistributionProgram): Hex {
  const x = normalizeContext(context), p = normalizeProgram(program);
  return keccak256(coder.encode(["bytes32", "uint256", "address", "address", "address", "uint256", "bytes32", programTuple],
    [domains.program, x.chainId, x.distributor, x.core, x.manager, uint(collectionId, 256, "collectionId"), bytes32(phaseId, "phaseId"), p])) as Hex;
}

export function operatorDistributionSliceAuthorization(context: OperatorDistributionContext, collectionId: bigint, phaseId: Hex, sliceIndex: bigint): Hex {
  const x = normalizeContext(context);
  return keccak256(coder.encode(["bytes32", "uint256", "address", "address", "address", "uint256", "bytes32", "uint256"],
    [domains.authorization, x.chainId, x.distributor, x.core, x.manager, uint(collectionId, 256, "collectionId"), bytes32(phaseId, "phaseId"), uint(sliceIndex, 256, "sliceIndex")])) as Hex;
}

export function operatorDistributionSliceHash(context: OperatorDistributionContext, sliceIndex: bigint, input: {
  readonly collectionId: bigint; readonly phaseId: Hex; readonly beneficiaries: readonly Address[];
  readonly tokenData: readonly Hex[]; readonly mintCommitments: readonly Hex[];
}): Hex {
  const x = normalizeContext(context);
  exactKeys(input, ["collectionId", "phaseId", "beneficiaries", "tokenData", "mintCommitments"], "distribution slice preimage");
  if (!Array.isArray(input.beneficiaries) || !Array.isArray(input.tokenData) || !Array.isArray(input.mintCommitments)
    || input.beneficiaries.length < 1 || input.beneficiaries.length > OPERATOR_DISTRIBUTION_MAX_SLICE
    || input.tokenData.length !== input.beneficiaries.length || input.mintCommitments.length !== input.beneficiaries.length) {
    throw new Error("Distribution slice arrays must have equal length from 1 to 10");
  }
  const beneficiaries = input.beneficiaries.map((item, index) => address(item, `beneficiaries[${index}]`));
  const tokenData = input.tokenData.map((item, index) => bytes(item, `tokenData[${index}]`, MAX_TOKEN_DATA_BYTES));
  const commitments = input.mintCommitments.map((item, index) => bytes32(item, `mintCommitments[${index}]`));
  return keccak256(coder.encode(["bytes32", "uint256", "address", "address", "address", "uint256", "bytes32", "uint256", "address[]", "bytes[]", "bytes32[]"],
    [domains.slice, x.chainId, x.distributor, x.core, x.manager, uint(input.collectionId, 256, "collectionId"), bytes32(input.phaseId, "phaseId"), uint(sliceIndex, 256, "sliceIndex"), beneficiaries, tokenData, commitments])) as Hex;
}

function pair(a: Hex, b: Hex): Hex {
  return keccak256(coder.encode(["bytes32", "bytes32"], BigInt(a) < BigInt(b) ? [a, b] : [b, a])) as Hex;
}

function tree(leaves: readonly Hex[]): { readonly root: Hex; readonly proofs: readonly (readonly Hex[])[] } {
  if (leaves.length < 1) throw new Error("Distribution tree requires at least one slice");
  const layers: Hex[][] = [Array.from(leaves)];
  while (layers.at(-1)!.length > 1) {
    const prior = layers.at(-1)!, next: Hex[] = [];
    for (let index = 0; index < prior.length; index += 2) next.push(index + 1 < prior.length ? pair(prior[index]!, prior[index + 1]!) : prior[index]!);
    layers.push(next);
  }
  const proofs = leaves.map((_, original) => {
    let index = original; const proof: Hex[] = [];
    for (let level = 0; level < layers.length - 1; level++) {
      const sibling = index ^ 1, layer = layers[level]!; if (sibling < layer.length) proof.push(layer[sibling]!); index = Math.floor(index / 2);
    }
    if (proof.length > 32) throw new Error("Distribution proof exceeds the protocol depth of 32");
    return Object.freeze(proof);
  });
  return Object.freeze({ root: layers.at(-1)![0]!, proofs: Object.freeze(proofs) });
}

export function buildOperatorDistributionManifest(input: {
  readonly context: OperatorDistributionContext;
  readonly collectionId: bigint;
  readonly phaseId: Hex;
  readonly operator: Address;
  readonly supplyCounterId: Hex;
  readonly recipientCounterId: Hex;
  readonly perRecipientCap: bigint;
  readonly deliveryMode: bigint;
  readonly prepared: boolean;
  readonly sliceQuantity: number;
  readonly tokens: readonly OperatorDistributionToken[];
  readonly manifestCompletenessReviewed: boolean;
}): OperatorDistributionManifest {
  exactKeys(input, ["context", "collectionId", "phaseId", "operator", "supplyCounterId", "recipientCounterId", "perRecipientCap", "deliveryMode", "prepared", "sliceQuantity", "tokens", "manifestCompletenessReviewed"], "distribution manifest input");
  if (input.manifestCompletenessReviewed !== true) throw new Error("Caller must explicitly attest that the ordered distribution manifest was reviewed for completeness");
  const context = normalizeContext(input.context), collectionId = uint(input.collectionId, 256, "collectionId"), phaseId = bytes32(input.phaseId, "phaseId");
  if (!Number.isSafeInteger(input.sliceQuantity) || input.sliceQuantity < 1 || input.sliceQuantity > OPERATOR_DISTRIBUTION_MAX_SLICE) throw new Error("sliceQuantity must be an integer from 1 to 10");
  if (!Array.isArray(input.tokens) || input.tokens.length < 1 || input.tokens.length > OPERATOR_DISTRIBUTION_MAX_TOKENS) throw new Error(`tokens must contain 1 through ${OPERATOR_DISTRIBUTION_MAX_TOKENS} ordered entries`);
  const tokens = input.tokens.map((item, index) => normalizeToken(item, context.distributor, index));
  if (tokens.reduce((sum, item) => sum + (item.tokenData.length - 2) / 2, 0) > MAX_TOTAL_TOKEN_DATA_BYTES) throw new Error("Distribution tokenData exceeds the 4 MiB client artifact boundary");
  const emptyProgram = normalizeProgram({ operator: input.operator, slicesRoot: ZERO32, supplyCounterId: input.supplyCounterId,
    recipientCounterId: input.recipientCounterId, totalQuantity: BigInt(tokens.length), perRecipientCap: input.perRecipientCap,
    deliveryMode: input.deliveryMode, prepared: input.prepared }, true);
  const sliceDrafts: Omit<OperatorDistributionSlice, "proof">[] = [];
  for (let start = 0, index = 0; start < tokens.length; start += input.sliceQuantity, index++) {
    const selected = tokens.slice(start, start + input.sliceQuantity), sliceIndex = BigInt(index);
    sliceDrafts.push(Object.freeze({ index: sliceIndex, start, count: selected.length,
      sliceHash: operatorDistributionSliceHash(context, sliceIndex, { collectionId, phaseId,
        beneficiaries: selected.map(item => item.beneficiary), tokenData: selected.map(item => item.tokenData), mintCommitments: selected.map(item => item.mintCommitment) }) }));
  }
  const built = tree(sliceDrafts.map(item => item.sliceHash));
  const program = normalizeProgram({ ...emptyProgram, slicesRoot: built.root });
  const programHash = operatorDistributionProgramHash(context, collectionId, phaseId, program);
  const slices = sliceDrafts.map((item, index) => Object.freeze({ ...item, proof: built.proofs[index]! }));
  return Object.freeze({ schemaVersion: 1, profile: "STREAM_CLIENT_OPERATOR_DISTRIBUTION_MANIFEST_V1", context, collectionId, phaseId,
    sliceQuantity: input.sliceQuantity, manifestCompletenessReviewed: true, program, programHash, tokens: Object.freeze(tokens), slices: Object.freeze(slices) });
}

export function verifyOperatorDistributionManifest(artifact: OperatorDistributionManifest): OperatorDistributionManifest {
  if (artifact.schemaVersion !== 1 || artifact.profile !== "STREAM_CLIENT_OPERATOR_DISTRIBUTION_MANIFEST_V1" || artifact.manifestCompletenessReviewed !== true) throw new Error("Unsupported or unreviewed distribution artifact");
  const rebuilt = buildOperatorDistributionManifest({ context: artifact.context, collectionId: artifact.collectionId, phaseId: artifact.phaseId,
    operator: artifact.program.operator, supplyCounterId: artifact.program.supplyCounterId, recipientCounterId: artifact.program.recipientCounterId,
    perRecipientCap: artifact.program.perRecipientCap, deliveryMode: artifact.program.deliveryMode, prepared: artifact.program.prepared,
    sliceQuantity: artifact.sliceQuantity, tokens: artifact.tokens, manifestCompletenessReviewed: true });
  const render = (value: unknown) => JSON.stringify(value, (_, item) => typeof item === "bigint" ? item.toString() : item);
  if (render(rebuilt) !== render(artifact)) throw new Error("Distribution artifact differs from canonical reconstruction");
  return rebuilt;
}

export function operatorDistributionManifestToJSON(artifact: OperatorDistributionManifest): string {
  const rendered = JSON.stringify(verifyOperatorDistributionManifest(artifact), (_, value) => typeof value === "bigint" ? value.toString() : value, 2);
  if (rendered.length > MAX_JSON_CHARS) throw new Error("Canonical distribution artifact JSON exceeds 16 MiB");
  return rendered;
}

export function operatorDistributionManifestFromJSON(value: string | unknown): OperatorDistributionManifest {
  if (typeof value === "string" && value.length > MAX_JSON_CHARS) throw new Error("Distribution artifact JSON exceeds 16 MiB");
  const raw: unknown = typeof value === "string" ? JSON.parse(value) : value;
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) throw new Error("Expected distribution artifact object");
  const a = raw as Record<string, unknown>, x = a.context as Record<string, unknown>, p = a.program as Record<string, unknown>;
  if (!x || typeof x !== "object" || !p || typeof p !== "object" || !Array.isArray(a.tokens) || a.tokens.length > OPERATOR_DISTRIBUTION_MAX_TOKENS
    || !Array.isArray(a.slices) || a.slices.length > OPERATOR_DISTRIBUTION_MAX_TOKENS) throw new Error("Distribution artifact structure or bounds are invalid");
  const decimal = (item: unknown, name: string) => {
    if (typeof item !== "string" || item.length > 78 || !/^(0|[1-9][0-9]*)$/.test(item)) throw new Error(`${name} must be a bounded decimal string`);
    return BigInt(item);
  };
  return verifyOperatorDistributionManifest({ ...a, context: { ...x, chainId: decimal(x.chainId, "chainId") },
    collectionId: decimal(a.collectionId, "collectionId"), program: { ...p, totalQuantity: decimal(p.totalQuantity, "totalQuantity"),
      perRecipientCap: decimal(p.perRecipientCap, "perRecipientCap"), deliveryMode: decimal(p.deliveryMode, "deliveryMode") },
    slices: (a.slices as Record<string, unknown>[]).map(item => ({ ...item, index: decimal(item.index, "slice index") })) } as unknown as OperatorDistributionManifest);
}

export function operatorDistributionBatchForSlice(artifact: OperatorDistributionManifest, sliceIndex: number, binding: {
  readonly expectedPolicyHash: Hex;
  readonly resolverData: Hex;
}): OperatorDistributionBatch {
  const a = verifyOperatorDistributionManifest(artifact);
  exactKeys(binding, ["expectedPolicyHash", "resolverData"], "distribution batch binding");
  if (!Number.isSafeInteger(sliceIndex) || sliceIndex < 0 || sliceIndex >= a.slices.length) throw new Error("Invalid distribution slice index");
  const slice = a.slices[sliceIndex]!, selected = a.tokens.slice(slice.start, slice.start + slice.count);
  const beneficiaries = selected.map(item => item.beneficiary), direct = a.program.deliveryMode === OPERATOR_DISTRIBUTION_DELIVERY_MODE.DIRECT;
  return Object.freeze({ collectionId: a.collectionId, phaseId: a.phaseId, payer: ZeroAddress as Address, authorizer: ZeroAddress as Address,
    initialRecipients: frozen(direct ? beneficiaries : beneficiaries.map(() => a.context.distributor)), beneficiaries: frozen(beneficiaries),
    tokenData: frozen(selected.map(item => item.tokenData)), mintCommitments: frozen(selected.map(item => item.mintCommitment)),
    expectedPolicyHash: bytes32(binding.expectedPolicyHash, "expectedPolicyHash", false),
    authorizationId: operatorDistributionSliceAuthorization(a.context, a.collectionId, a.phaseId, slice.index), contextHash: slice.sliceHash,
    resolverData: bytes(binding.resolverData, "resolverData", MAX_TOTAL_TOKEN_DATA_BYTES) });
}

async function read(provider: Pick<Provider, "call">, target: Address, iface: Interface, method: string, args: readonly unknown[], blockTag: number): Promise<readonly unknown[]> {
  const raw = await provider.call({ to: target, data: iface.encodeFunctionData(method, args), blockTag });
  if (!isHexString(raw, true)) throw new Error(`Malformed ${method} return`);
  const decoded = iface.decodeFunctionResult(method, raw);
  if (iface.encodeFunctionResult(method, decoded).toLowerCase() !== raw.toLowerCase()) throw new Error(`Noncanonical ${method} return`);
  return Array.from(decoded);
}

function tuple(value: unknown): readonly unknown[] {
  if (value === null || typeof value !== "object" || !(Symbol.iterator in value)) throw new Error("Malformed ABI tuple return");
  return Array.from(value as Iterable<unknown>);
}

function callForDistribution(a: OperatorDistributionManifest, sliceIndex: number, presentation: DistributionPresentation,
  expectedPolicyHash: Hex, revealFeePerTokenWei: bigint): UnsignedCall {
  const slice = a.slices[sliceIndex]!, batch = operatorDistributionBatchForSlice(a, sliceIndex, { expectedPolicyHash, resolverData: presentation.resolverData });
  const value = revealFeePerTokenWei * BigInt(slice.count);
  if (value > MAX_UINT256) throw new Error("Distribution reveal fee value overflows uint256");
  return Object.freeze({ to: a.context.distributor,
    data: distributionAbi.encodeFunctionData("distribute", [a.program, slice.index, slice.proof, batch, presentation.gateData]) as Hex, value });
}

export async function inspectAndPrepareOperatorDistribution(provider: Pick<Provider, "getNetwork" | "call">,
  artifact: OperatorDistributionManifest, sliceIndex: number, presentationInput: DistributionPresentation,
  options: { readonly blockTag: number }): Promise<PreparedOperatorDistribution> {
  const a = verifyOperatorDistributionManifest(artifact), presentation = normalizePresentation(presentationInput), blockTag = concreteBlock(options.blockTag);
  if (!Number.isSafeInteger(sliceIndex) || sliceIndex < 0 || sliceIndex >= a.slices.length) throw new Error("Invalid distribution slice index");
  const x = a.context, slice = a.slices[sliceIndex]!;
  if ((await provider.getNetwork()).chainId !== x.chainId) throw new Error("RPC chain differs from distribution artifact");
  const [[actualCore], [actualManager]] = await Promise.all([
    read(provider, x.distributor, distributionAbi, "core", [], blockTag), read(provider, x.distributor, distributionAbi, "manager", [], blockTag),
  ]);
  if (!same(actualCore, x.core) || !same(actualManager, x.manager)) throw new Error("Distributor dependencies differ from reviewed context");
  const hashBatch = operatorDistributionBatchForSlice(a, sliceIndex, { expectedPolicyHash: a.program.slicesRoot, resolverData: presentation.resolverData });
  const reads = await Promise.all([
    read(provider, x.manager, managerAbi, "core", [], blockTag), read(provider, x.manager, managerAbi, "mintLedger", [], blockTag),
    read(provider, x.core, coreAbi, "getSatellitePointer", [domains.mintManagerPointer], blockTag),
    read(provider, x.core, coreAbi, "getSatellitePointer", [domains.entropyPointer], blockTag),
    read(provider, x.manager, managerAbi, "phase", [a.collectionId, a.phaseId], blockTag),
    read(provider, x.manager, managerAbi, "phasePolicyHash", [a.collectionId, a.phaseId], blockTag),
    read(provider, x.manager, managerAbi, "phaseExecutor", [a.collectionId, a.phaseId, x.distributor], blockTag),
    read(provider, x.manager, managerAbi, "counterConfig", [a.collectionId, a.phaseId, a.program.supplyCounterId], blockTag),
    read(provider, x.manager, managerAbi, "counterConfig", [a.collectionId, a.phaseId, a.program.recipientCounterId], blockTag),
    read(provider, x.manager, managerAbi, "phaseRoyaltyPolicy", [a.collectionId, a.phaseId], blockTag),
    read(provider, x.distributor, distributionAbi, "sliceUsed", [a.collectionId, a.phaseId, slice.index], blockTag),
    read(provider, x.distributor, distributionAbi, "programHash", [a.collectionId, a.phaseId, a.program], blockTag),
    read(provider, x.distributor, distributionAbi, "sliceHash", [slice.index, hashBatch], blockTag),
    read(provider, x.distributor, distributionAbi, "sliceAuthorization", [a.collectionId, a.phaseId, slice.index], blockTag),
  ]);
  const [managerCore] = reads[0]!, [mintLedger] = reads[1]!, mintPointer = reads[2]!, entropyPointer = reads[3]!;
  if (!same(managerCore, x.core) || !same(mintPointer[0], x.manager) || !mintLedger || same(mintLedger, ZeroAddress)
    || !isHexString(mintPointer[1], 32) || String(mintPointer[1]).toLowerCase() === ZERO32) throw new Error("Manager is not the reviewed Core's live selected Manager");
  const coordinator = address(entropyPointer[0], "selected entropy coordinator");
  if (!isHexString(entropyPointer[1], 32) || String(entropyPointer[1]).toLowerCase() === ZERO32) throw new Error("Selected entropy coordinator has no runtime commitment");
  const [[coordinatorCore], [policyRaw]] = await Promise.all([
    read(provider, coordinator, entropyAbi, "core", [], blockTag), read(provider, coordinator, entropyAbi, "collectionRevealPolicy", [a.collectionId], blockTag),
  ]);
  if (!same(coordinatorCore, x.core)) throw new Error("Selected entropy coordinator belongs to a different Core");
  const reveal = tuple(policyRaw); if (reveal.length !== 5 || reveal[0] !== true || (BigInt(String(reveal[1])) !== 0n && BigInt(String(reveal[1])) !== 1n)) throw new Error("Collection has no supported declared reveal policy");
  const revealFee = uint(BigInt(String(reveal[4])), 256, "revealFeePerTokenWei");
  const [phaseExists, phaseRaw] = reads[4]!, phase = tuple(phaseRaw), [policyHashRaw] = reads[5]!, [executorAllowed] = reads[6]!;
  const supply = tuple(reads[7]![0]), recipient = tuple(reads[8]![0]), royalty = tuple(reads[9]![0]);
  const [used] = reads[10]!, [onchainProgramHash] = reads[11]!, [onchainSliceHash] = reads[12]!, [onchainAuthorization] = reads[13]!;
  const programHash = operatorDistributionProgramHash(x, a.collectionId, a.phaseId, a.program), policyHash = bytes32(policyHashRaw, "phase policy hash", false);
  let effectiveConfigHash = programHash;
  if (royalty[0] === true) {
    if (!a.program.prepared || !same(royalty[1], programHash)) throw new Error("Royalty policy does not bind the prepared distribution program");
    const [royaltyHash] = await read(provider, x.manager, managerAbi, "phaseRoyaltyConfigHash", [a.collectionId, a.phaseId, royalty], blockTag);
    effectiveConfigHash = bytes32(royaltyHash, "royalty config hash", false);
  }
  const validCounter = (value: readonly unknown[], mode: bigint, cap: bigint) => value.length === 7 && value[0] === true
    && BigInt(String(value[1])) === mode && BigInt(String(value[2])) === 1n && BigInt(String(value[3])) === 0n
    && BigInt(String(value[4])) === cap && BigInt(String(value[5])) === 1n;
  if (phaseExists !== true || phase.length !== 6 || phase[0] !== false || BigInt(String(phase[3])) < BigInt(slice.count)
    || !same(phase[4], effectiveConfigHash) || executorAllowed !== true || !validCounter(supply, 1n, a.program.totalQuantity)
    || !validCounter(recipient, 3n, a.program.perRecipientCap) || used !== false
    || !same(onchainProgramHash, programHash) || !same(onchainSliceHash, slice.sliceHash)
    || !same(onchainAuthorization, hashBatch.authorizationId)) throw new Error("Live phase, counters, executor, slice or distribution hashes differ from the reviewed manifest");
  const call = callForDistribution(a, sliceIndex, presentation, policyHash, revealFee);
  return Object.freeze({ artifact: a, sliceIndex, presentation, expectedPolicyHash: policyHash, revealFeePerTokenWei: revealFee,
    caller: a.program.operator, call, checked: DISTRIBUTION_CHECKED, limitations: DISTRIBUTION_LIMITATIONS });
}

function assertPreparedDistribution(value: PreparedOperatorDistribution): PreparedOperatorDistribution {
  exactKeys(value, ["artifact", "sliceIndex", "presentation", "expectedPolicyHash", "revealFeePerTokenWei", "caller", "call", "checked", "limitations"], "prepared distribution");
  exactKeys(value.call, ["to", "data", "value"], "prepared distribution CALL");
  const a = verifyOperatorDistributionManifest(value.artifact), presentation = normalizePresentation(value.presentation);
  if (!Number.isSafeInteger(value.sliceIndex) || value.sliceIndex < 0 || value.sliceIndex >= a.slices.length) throw new Error("Invalid prepared distribution slice index");
  const expectedPolicyHash = bytes32(value.expectedPolicyHash, "expectedPolicyHash", false), fee = uint(value.revealFeePerTokenWei, 256, "revealFeePerTokenWei");
  const caller = address(value.caller, "operator"), call = callForDistribution(a, value.sliceIndex, presentation, expectedPolicyHash, fee);
  if (caller.toLowerCase() !== a.program.operator.toLowerCase() || value.call.to.toLowerCase() !== call.to.toLowerCase()
    || value.call.data.toLowerCase() !== call.data.toLowerCase() || value.call.value !== call.value
    || JSON.stringify(value.checked) !== JSON.stringify(DISTRIBUTION_CHECKED) || JSON.stringify(value.limitations) !== JSON.stringify(DISTRIBUTION_LIMITATIONS)) {
    throw new Error("Prepared distribution facts, caller or CALL differ from canonical reconstruction");
  }
  return Object.freeze({ artifact: a, sliceIndex: value.sliceIndex, presentation, expectedPolicyHash, revealFeePerTokenWei: fee,
    caller, call, checked: DISTRIBUTION_CHECKED, limitations: DISTRIBUTION_LIMITATIONS });
}

export async function simulatePreparedOperatorDistribution(provider: Pick<Provider, "getNetwork" | "call">,
  preparedInput: PreparedOperatorDistribution, options: { readonly blockTag: number }): Promise<{ readonly tokenIds: readonly bigint[]; readonly operationRoot: Hex }> {
  const prepared = assertPreparedDistribution(preparedInput), blockTag = concreteBlock(options.blockTag);
  const current = await inspectAndPrepareOperatorDistribution(provider, prepared.artifact, prepared.sliceIndex, prepared.presentation, { blockTag });
  if (current.expectedPolicyHash.toLowerCase() !== prepared.expectedPolicyHash.toLowerCase() || current.revealFeePerTokenWei !== prepared.revealFeePerTokenWei
    || current.call.data.toLowerCase() !== prepared.call.data.toLowerCase() || current.call.value !== prepared.call.value) throw new Error("Prepared distribution no longer matches pinned live facts");
  const raw = await provider.call({ ...prepared.call, from: prepared.caller, blockTag });
  if (!isHexString(raw, true)) throw new Error("Malformed distribute simulation return");
  const decoded = distributionAbi.decodeFunctionResult("distribute", raw);
  if (distributionAbi.encodeFunctionResult("distribute", decoded).toLowerCase() !== raw.toLowerCase()) throw new Error("Noncanonical distribute simulation return");
  return Object.freeze({ tokenIds: Object.freeze(Array.from(decoded[0] as Iterable<bigint>)), operationRoot: bytes32(decoded[1], "operationRoot", false) });
}

function normalizeClaimExpectation(value: DistributionClaimExpectation): DistributionClaimExpectation {
  exactKeys(value, ["collectionId", "phaseId", "beneficiary"], "distribution claim expectation");
  return Object.freeze({ collectionId: uint(value.collectionId, 256, "collectionId"), phaseId: bytes32(value.phaseId, "phaseId"), beneficiary: address(value.beneficiary, "beneficiary") });
}

export function prepareOwnDistributionClaim(chainId: bigint, distributor: Address, tokenId: bigint,
  expectedClaim: DistributionClaimExpectation, receiver: Address): PreparedDistributionClaim {
  const claim = normalizeClaimExpectation(expectedClaim), target = address(distributor, "distributor"), destination = address(receiver, "receiver");
  if (destination.toLowerCase() === target.toLowerCase() || claim.beneficiary.toLowerCase() === target.toLowerCase()) throw new Error("Claim receiver or beneficiary cannot be the distributor");
  const idValue = uint(tokenId, 256, "tokenId", true), caller = claim.beneficiary;
  return Object.freeze({ kind: "own", chainId: uint(chainId, 256, "chainId", true), distributor: target, caller, tokenId: idValue,
    expectedClaim: claim, receiver: destination, walletWide: null, delegationIndex: null,
    call: Object.freeze({ to: target, data: distributionAbi.encodeFunctionData("claimNft", [idValue, destination]) as Hex, value: 0n }) });
}

export function prepareDelegatedDistributionClaim(chainId: bigint, distributor: Address, delegate: Address, tokenId: bigint,
  expectedClaim: DistributionClaimExpectation, walletWide: boolean, delegationIndex: bigint): PreparedDistributionClaim {
  const claim = normalizeClaimExpectation(expectedClaim), target = address(distributor, "distributor"), caller = address(delegate, "delegate"), idValue = uint(tokenId, 256, "tokenId", true);
  if (claim.beneficiary.toLowerCase() === target.toLowerCase()) throw new Error("Claim beneficiary cannot be the distributor");
  const wide = boolean(walletWide, "walletWide"), index = uint(delegationIndex, 256, "delegationIndex");
  return Object.freeze({ kind: "delegate", chainId: uint(chainId, 256, "chainId", true), distributor: target, caller, tokenId: idValue,
    expectedClaim: claim, receiver: claim.beneficiary, walletWide: wide, delegationIndex: index,
    call: Object.freeze({ to: target, data: distributionAbi.encodeFunctionData("claimNftFor", [idValue, wide, index]) as Hex, value: 0n }) });
}

function normalizePreparedClaim(value: PreparedDistributionClaim): PreparedDistributionClaim {
  exactKeys(value, ["kind", "chainId", "distributor", "caller", "tokenId", "expectedClaim", "receiver", "walletWide", "delegationIndex", "call"], "prepared distribution claim");
  exactKeys(value.call, ["to", "data", "value"], "prepared distribution claim CALL");
  const expected = normalizeClaimExpectation(value.expectedClaim);
  const rebuilt = value.kind === "own"
    ? prepareOwnDistributionClaim(value.chainId, value.distributor, value.tokenId, expected, value.receiver)
    : value.kind === "delegate" && value.walletWide !== null && value.delegationIndex !== null
      ? prepareDelegatedDistributionClaim(value.chainId, value.distributor, value.caller, value.tokenId, expected, value.walletWide, value.delegationIndex)
      : (() => { throw new Error("Invalid distribution claim kind or delegation witness"); })();
  if (rebuilt.caller.toLowerCase() !== value.caller.toLowerCase() || rebuilt.receiver.toLowerCase() !== value.receiver.toLowerCase()
    || rebuilt.walletWide !== value.walletWide || rebuilt.delegationIndex !== value.delegationIndex
    || rebuilt.call.to.toLowerCase() !== value.call.to.toLowerCase() || rebuilt.call.data.toLowerCase() !== value.call.data.toLowerCase()
    || value.call.value !== 0n) throw new Error("Prepared distribution claim differs from canonical reconstruction");
  return rebuilt;
}

export async function inspectDistributionClaim(provider: Pick<Provider, "getNetwork" | "call">, preparedInput: PreparedDistributionClaim,
  options: { readonly blockTag: number }): Promise<{ readonly claim: PreparedDistributionClaim; readonly checked: readonly string[]; readonly limitations: readonly string[] }> {
  const prepared = normalizePreparedClaim(preparedInput), blockTag = concreteBlock(options.blockTag);
  if ((await provider.getNetwork()).chainId !== prepared.chainId) throw new Error("RPC chain differs from prepared distribution claim");
  const [raw] = await read(provider, prepared.distributor, distributionAbi, "nftClaim", [prepared.tokenId], blockTag), claim = tuple(raw), expected = prepared.expectedClaim;
  if (claim.length !== 3 || BigInt(String(claim[0])) !== expected.collectionId || !same(claim[1], expected.phaseId) || !same(claim[2], expected.beneficiary)) throw new Error("Live NFT claim differs from the reviewed fixed beneficiary claim");
  return Object.freeze({ claim: prepared, checked: Object.freeze(["exact token claim collection and phase", "fixed original beneficiary"]),
    limitations: Object.freeze([prepared.kind === "delegate" ? "delegation scope, expiry and use-case remain live contract checks" : "receiver acceptance remains a live call result", "claim inspection does not prove runtime code identity, later delivery or caller authority"]) });
}

export async function simulatePreparedDistributionClaim(provider: Pick<Provider, "getNetwork" | "call">, preparedInput: PreparedDistributionClaim,
  options: { readonly blockTag: number }): Promise<boolean> {
  const blockTag = concreteBlock(options.blockTag), inspected = await inspectDistributionClaim(provider, preparedInput, { blockTag }), prepared = inspected.claim;
  const raw = await provider.call({ ...prepared.call, from: prepared.caller, blockTag });
  if (!isHexString(raw, true)) throw new Error("Malformed distribution claim simulation return");
  const method = prepared.kind === "own" ? "claimNft" : "claimNftFor", decoded = distributionAbi.decodeFunctionResult(method, raw);
  if (distributionAbi.encodeFunctionResult(method, decoded).toLowerCase() !== raw.toLowerCase()) throw new Error("Noncanonical distribution claim simulation return");
  return Boolean(decoded[0]);
}
