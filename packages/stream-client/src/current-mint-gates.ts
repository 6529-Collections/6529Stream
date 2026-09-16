import { AbiCoder, ZeroAddress, getAddress, id, isHexString, keccak256 } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import { buildSigningPayload } from "./signing-payload.js";
import type { SigningPayload } from "./signing.js";

export const MINT_GATE_CLIENT_MAX_BATCH = 4096;
export const MINT_GATE_CLIENT_MAX_PROOF_NODES = 256;

export interface MintBatchArrays {
  readonly initialRecipients: readonly Address[];
  readonly beneficiaries: readonly Address[];
  readonly tokenData: readonly Hex[];
  readonly mintCommitments: readonly Hex[];
}

export interface MintGateBatch extends MintBatchArrays {
  readonly collectionId: bigint;
  readonly phaseId: Hex;
  readonly payer: Address;
  readonly authorizer: Address;
  readonly expectedPolicyHash: Hex;
  readonly authorizationId: Hex;
  readonly contextHash: Hex;
  readonly resolverData: Hex;
}

export interface MintBatchHashes {
  readonly initialRecipientsHash: Hex;
  readonly beneficiariesHash: Hex;
  readonly tokenDataArrayHash: Hex;
  readonly mintCommitmentsHash: Hex;
}

export interface MintTicket {
  readonly chainId: bigint;
  readonly manager: Address;
  readonly ledger: Address;
  readonly collectionId: bigint;
  readonly phaseId: Hex;
  readonly executor: Address;
  readonly payer: Address;
  readonly authorizer: Address;
  readonly authorizerKind: bigint;
  readonly initialRecipientsHash: Hex;
  readonly beneficiariesHash: Hex;
  readonly tokenDataArrayHash: Hex;
  readonly mintCommitmentsHash: Hex;
  readonly quantity: bigint;
  readonly contextHash: Hex;
  readonly policyHash: Hex;
  readonly nonce: Hex;
  readonly deadline: bigint;
}

export interface MintTicketInput {
  readonly chainId: bigint;
  readonly manager: Address;
  readonly ledger: Address;
  readonly executor: Address;
  readonly authorizerKind: bigint;
  readonly nonce: Hex;
  readonly deadline: bigint;
}

export interface DelegateMintBatchInput {
  readonly collectionId: bigint;
  readonly phaseId: Hex;
  readonly payer: Address;
  readonly authorizer: Address;
  readonly initialRecipients: readonly Address[];
  readonly beneficiaries: readonly Address[];
  readonly contextHash: Hex;
  readonly expectedPolicyHash: Hex;
}

/** Exact retained narrow validateMint request. It does not bind tokenData or mintCommitments. */
export interface DelegateMintRequest extends DelegateMintBatchInput {
  readonly manager: Address;
  readonly executor: Address;
  readonly gateData: Hex;
}

export interface MintAllowlistProof {
  readonly maxCount: bigint;
  readonly hasPriceOverride: boolean;
  readonly priceOverride: bigint;
  readonly proof: readonly Hex[];
}

export interface MintAllowlistLeafInput {
  readonly chainId: bigint;
  readonly manager: Address;
  readonly collectionId: bigint;
  readonly phaseId: Hex;
  readonly counterId: Hex;
  readonly account: Address;
  readonly maxCount: bigint;
  readonly hasPriceOverride: boolean;
  readonly priceOverride: bigint;
}

export interface MintAllowlistAuthorizationBinding {
  readonly manager: Address;
  readonly ledger: Address;
  readonly executor: Address;
  readonly collectionId: bigint;
  readonly phaseId: Hex;
  readonly payer: Address;
  readonly expectedPolicyHash: Hex;
  readonly contextHash: Hex;
  readonly initialRecipientsHash: Hex;
  readonly beneficiariesHash: Hex;
  readonly tokenDataHash: Hex;
  readonly mintCommitmentsHash: Hex;
  readonly proofValuesHash: Hex;
  readonly nonce: Hex;
}

const coder = AbiCoder.defaultAbiCoder();
const ZERO32 = `0x${"00".repeat(32)}` as Hex;
const MAX_TOKEN_DATA_BYTES = 1_048_576;
const MAX_TOTAL_TOKEN_DATA_BYTES = 4_194_304;

const domains = {
  recipients: id("6529STREAM_MINT_BATCH_RECIPIENTS_V1"),
  beneficiaries: id("6529STREAM_MINT_BATCH_BENEFICIARIES_V1"),
  tokenData: id("6529STREAM_MINT_BATCH_TOKEN_DATA_V1"),
  commitments: id("6529STREAM_MINT_BATCH_COMMITMENTS_V1"),
  ticketAuthorization: id("6529STREAM_MINT_TICKET_AUTHORIZATION_V1"),
  ticketConfig: id("6529STREAM_MINT_TICKET_GATE_CONFIG_V1"),
  delegateModule: id("6529STREAM_DELEGATE_XYZ_V2_GATE_V1"),
  delegateRights: id("6529STREAM_DELEGATE_COLLECTION_RIGHTS_V1"),
  delegateAuthorization: id("6529STREAM_DELEGATE_MINT_AUTHORIZATION_V1"),
  delegateNullifier: id("6529STREAM_DELEGATE_MINT_NONCE_V1"),
  allowlistConfig: id("6529STREAM_MINT_ALLOWLIST_GATE_CONFIG_V1"),
  allowlistLeaf: id("6529STREAM_MINT_ALLOWLIST_LEAF_V1"),
  allowlistProofValues: id("6529STREAM_MINT_ALLOWLIST_GATE_PROOF_VALUES_V1"),
  allowlistAuthorization: id("6529STREAM_MINT_ALLOWLIST_GATE_AUTHORIZATION_V1"),
  allowlistNullifier: id("6529STREAM_MINT_ALLOWLIST_GATE_NONCE_V1"),
} as const;

const ticketFields = [
  { name: "chainId", type: "uint256" },
  { name: "manager", type: "address" },
  { name: "ledger", type: "address" },
  { name: "collectionId", type: "uint256" },
  { name: "phaseId", type: "bytes32" },
  { name: "executor", type: "address" },
  { name: "payer", type: "address" },
  { name: "authorizer", type: "address" },
  { name: "authorizerKind", type: "uint8" },
  { name: "initialRecipientsHash", type: "bytes32" },
  { name: "beneficiariesHash", type: "bytes32" },
  { name: "tokenDataArrayHash", type: "bytes32" },
  { name: "mintCommitmentsHash", type: "bytes32" },
  { name: "quantity", type: "uint256" },
  { name: "contextHash", type: "bytes32" },
  { name: "policyHash", type: "bytes32" },
  { name: "nonce", type: "bytes32" },
  { name: "deadline", type: "uint64" },
] as const;

const ticketTuple = "tuple(uint256 chainId,address manager,address ledger,uint256 collectionId,bytes32 phaseId,address executor,address payer,address authorizer,uint8 authorizerKind,bytes32 initialRecipientsHash,bytes32 beneficiariesHash,bytes32 tokenDataArrayHash,bytes32 mintCommitmentsHash,uint256 quantity,bytes32 contextHash,bytes32 policyHash,bytes32 nonce,uint64 deadline)";
const delegateRequestTuple = "tuple(address manager,address executor,uint256 collectionId,bytes32 phaseId,address payer,address authorizer,address[] initialRecipients,address[] beneficiaries,bytes32 contextHash,bytes32 expectedPolicyHash,bytes gateData)";
const allowlistBindingTuple = "tuple(address manager,address ledger,address executor,uint256 collectionId,bytes32 phaseId,address payer,bytes32 expectedPolicyHash,bytes32 contextHash,bytes32 initialRecipientsHash,bytes32 beneficiariesHash,bytes32 tokenDataHash,bytes32 mintCommitmentsHash,bytes32 proofValuesHash,bytes32 nonce)";
const allowlistProofTuple = "tuple(uint64 maxCount,bool hasPriceOverride,uint256 priceOverride,bytes32[] proof)";

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
  if (typeof value !== "string" || !isHexString(value) || (value.length - 2) % 2 !== 0 || (value.length - 2) / 2 > maxBytes) {
    throw new Error(`${name} must be hex bytes no longer than ${maxBytes} bytes`);
  }
  return value as Hex;
}

function same(a: string, b: string): boolean { return a.toLowerCase() === b.toLowerCase(); }

function freezeArray<T>(values: readonly T[]): readonly T[] { return Object.freeze(Array.from(values)); }

function normalizeArrays(value: unknown, exact: boolean): MintBatchArrays {
  if (exact) exactKeys(value, ["initialRecipients", "beneficiaries", "tokenData", "mintCommitments"], "mint batch arrays");
  if (value === null || typeof value !== "object") throw new Error("mint batch arrays must be an object");
  const raw = value as Record<string, unknown>;
  for (const name of ["initialRecipients", "beneficiaries", "tokenData", "mintCommitments"] as const) {
    if (!Array.isArray(raw[name])) throw new Error(`${name} must be an array`);
  }
  const count = (raw.initialRecipients as unknown[]).length;
  if (count === 0 || count > MINT_GATE_CLIENT_MAX_BATCH || (raw.beneficiaries as unknown[]).length !== count
    || (raw.tokenData as unknown[]).length !== count || (raw.mintCommitments as unknown[]).length !== count) {
    throw new Error(`Batch arrays must have the same length from 1 to ${MINT_GATE_CLIENT_MAX_BATCH}`);
  }
  const initialRecipients = (raw.initialRecipients as unknown[]).map((item, index) => address(item, `initialRecipients[${index}]`));
  const beneficiaries = (raw.beneficiaries as unknown[]).map((item, index) => address(item, `beneficiaries[${index}]`));
  const tokenData = (raw.tokenData as unknown[]).map((item, index) => bytes(item, `tokenData[${index}]`, MAX_TOKEN_DATA_BYTES));
  const mintCommitments = (raw.mintCommitments as unknown[]).map((item, index) => bytes32(item, `mintCommitments[${index}]`));
  if (tokenData.reduce((sum, item) => sum + (item.length - 2) / 2, 0) > MAX_TOTAL_TOKEN_DATA_BYTES) {
    throw new Error(`tokenData exceeds the ${MAX_TOTAL_TOKEN_DATA_BYTES}-byte client boundary`);
  }
  return Object.freeze({ initialRecipients: freezeArray(initialRecipients), beneficiaries: freezeArray(beneficiaries),
    tokenData: freezeArray(tokenData), mintCommitments: freezeArray(mintCommitments) });
}

function normalizeBatch(value: MintGateBatch): MintGateBatch {
  exactKeys(value, ["collectionId", "phaseId", "payer", "authorizer", "initialRecipients", "beneficiaries", "tokenData",
    "mintCommitments", "expectedPolicyHash", "authorizationId", "contextHash", "resolverData"], "mint batch");
  const arrays = normalizeArrays(value, false);
  return Object.freeze({ collectionId: uint(value.collectionId, 256, "collectionId", true), phaseId: bytes32(value.phaseId, "phaseId", false),
    payer: address(value.payer, "payer"), authorizer: address(value.authorizer, "authorizer", true), ...arrays,
    expectedPolicyHash: bytes32(value.expectedPolicyHash, "expectedPolicyHash", false),
    authorizationId: bytes32(value.authorizationId, "authorizationId"), contextHash: bytes32(value.contextHash, "contextHash"),
    resolverData: bytes(value.resolverData, "resolverData", MAX_TOTAL_TOKEN_DATA_BYTES) });
}

function normalizeTicket(value: MintTicket): MintTicket {
  exactKeys(value, ticketFields.map(field => field.name), "mint ticket");
  const output: MintTicket = {
    chainId: uint(value.chainId, 256, "chainId", true), manager: address(value.manager, "manager"), ledger: address(value.ledger, "ledger"),
    collectionId: uint(value.collectionId, 256, "collectionId", true), phaseId: bytes32(value.phaseId, "phaseId", false),
    executor: address(value.executor, "executor"), payer: address(value.payer, "payer"), authorizer: address(value.authorizer, "authorizer"),
    authorizerKind: uint(value.authorizerKind, 8, "authorizerKind"), initialRecipientsHash: bytes32(value.initialRecipientsHash, "initialRecipientsHash"),
    beneficiariesHash: bytes32(value.beneficiariesHash, "beneficiariesHash"), tokenDataArrayHash: bytes32(value.tokenDataArrayHash, "tokenDataArrayHash"),
    mintCommitmentsHash: bytes32(value.mintCommitmentsHash, "mintCommitmentsHash"), quantity: uint(value.quantity, 256, "quantity", true),
    contextHash: bytes32(value.contextHash, "contextHash"), policyHash: bytes32(value.policyHash, "policyHash", false),
    nonce: bytes32(value.nonce, "nonce"), deadline: uint(value.deadline, 64, "deadline"),
  };
  if (output.authorizerKind !== 1n && output.authorizerKind !== 2n) throw new Error("authorizerKind must be EOA_712 (1) or ERC1271_712 (2)");
  return Object.freeze(output);
}

export function mintBatchHashes(input: MintBatchArrays | MintGateBatch): MintBatchHashes {
  const keys = Object.keys(input).sort().join(",");
  const arrayKeys = ["initialRecipients", "beneficiaries", "tokenData", "mintCommitments"].sort().join(",");
  const fullKeys = ["collectionId", "phaseId", "payer", "authorizer", "initialRecipients", "beneficiaries", "tokenData",
    "mintCommitments", "expectedPolicyHash", "authorizationId", "contextHash", "resolverData"].sort().join(",");
  if (keys !== arrayKeys && keys !== fullKeys) throw new Error("mint batch hashes input contains missing or unknown properties");
  const batch = keys === fullKeys ? normalizeBatch(input as MintGateBatch) : normalizeArrays(input, true);
  return Object.freeze({
    initialRecipientsHash: keccak256(coder.encode(["bytes32", "address[]"], [domains.recipients, batch.initialRecipients])) as Hex,
    beneficiariesHash: keccak256(coder.encode(["bytes32", "address[]"], [domains.beneficiaries, batch.beneficiaries])) as Hex,
    tokenDataArrayHash: keccak256(coder.encode(["bytes32", "bytes[]"], [domains.tokenData, batch.tokenData])) as Hex,
    mintCommitmentsHash: keccak256(coder.encode(["bytes32", "bytes32[]"], [domains.commitments, batch.mintCommitments])) as Hex,
  });
}

export function mintTicketForBatch(input: MintTicketInput, rawBatch: MintGateBatch): MintTicket {
  exactKeys(input, ["chainId", "manager", "ledger", "executor", "authorizerKind", "nonce", "deadline"], "mint ticket input");
  const batch = normalizeBatch(rawBatch);
  const kind = uint(input.authorizerKind, 8, "authorizerKind");
  if (kind !== 1n && kind !== 2n) throw new Error("authorizerKind must be EOA_712 (1) or ERC1271_712 (2)");
  if (same(batch.authorizer, ZeroAddress)) throw new Error("Ticket batch authorizer must be nonzero");
  const hashes = mintBatchHashes({ initialRecipients: batch.initialRecipients, beneficiaries: batch.beneficiaries,
    tokenData: batch.tokenData, mintCommitments: batch.mintCommitments });
  return normalizeTicket({ chainId: uint(input.chainId, 256, "chainId", true), manager: address(input.manager, "manager"),
    ledger: address(input.ledger, "ledger"), collectionId: batch.collectionId, phaseId: batch.phaseId,
    executor: address(input.executor, "executor"), payer: batch.payer, authorizer: batch.authorizer, authorizerKind: kind,
    ...hashes, quantity: BigInt(batch.initialRecipients.length), contextHash: batch.contextHash, policyHash: batch.expectedPolicyHash,
    nonce: bytes32(input.nonce, "nonce"), deadline: uint(input.deadline, 64, "deadline") });
}

export function mintTicketTypedData(chainId: bigint, gate: Address, ticket: MintTicket): SigningPayload<MintTicket> {
  const normalized = normalizeTicket(ticket);
  const domainChain = uint(chainId, 256, "chainId", true);
  if (domainChain !== normalized.chainId) throw new Error("EIP-712 domain chainId differs from ticket.chainId");
  return buildSigningPayload(domainChain, address(gate, "ticket gate"), "6529Stream Mint Tickets", "MintTicket", ticketFields, normalized);
}

export function mintTicketAuthorizationId(digest: Hex): Hex {
  return keccak256(coder.encode(["bytes32", "bytes32"], [domains.ticketAuthorization, bytes32(digest, "ticket digest")])) as Hex;
}

export function mintTicketGateConfigHash(signer: Address, kind: bigint): Hex {
  const normalizedKind = uint(kind, 8, "signer kind");
  if (normalizedKind !== 1n && normalizedKind !== 2n) throw new Error("Signer kind must be EOA_712 (1) or ERC1271_712 (2)");
  return keccak256(coder.encode(["bytes32", "address", "uint8"], [domains.ticketConfig, address(signer, "ticket signer"), normalizedKind])) as Hex;
}

export function mintTicketGateData(ticket: MintTicket, signature: Hex): Hex {
  return coder.encode([ticketTuple, "bytes"], [normalizeTicket(ticket), bytes(signature, "signature", 65_536)]) as Hex;
}

/** Safe owners sign Safe's SafeMessage(bytes) envelope over these bytes, not the raw ticket digest. */
export function mintTicketSafeMessageBytes(digest: Hex): Hex {
  return coder.encode(["bytes32"], [bytes32(digest, "ticket digest")]) as Hex;
}

export function delegateGateConfigHash(chainId: bigint, core: Address, registry: Address, registryCodeHash: Hex, usecase: Hex): Hex {
  return keccak256(coder.encode(["bytes32", "uint256", "address", "address", "bytes32", "bytes32"],
    [domains.delegateModule, uint(chainId, 256, "chainId", true), address(core, "core"), address(registry, "delegate registry"),
      bytes32(registryCodeHash, "delegate registry code hash", false), bytes32(usecase, "delegation usecase", false)])) as Hex;
}

export function delegateCollectionRights(chainId: bigint, core: Address, usecase: Hex, collectionId: bigint): Hex {
  return keccak256(coder.encode(["bytes32", "uint256", "address", "bytes32", "uint256"],
    [domains.delegateRights, uint(chainId, 256, "chainId", true), address(core, "core"),
      bytes32(usecase, "delegation usecase", false), uint(collectionId, 256, "collectionId", true)])) as Hex;
}

export function delegateGateData(vault: Address, nonce: Hex): Hex {
  return coder.encode(["address", "bytes32"], [address(vault, "vault"), bytes32(nonce, "nonce")]) as Hex;
}

function normalizeDelegateBatch(value: DelegateMintBatchInput | MintGateBatch, vault: Address): DelegateMintBatchInput {
  const narrowKeys = ["collectionId", "phaseId", "payer", "authorizer", "initialRecipients", "beneficiaries", "contextHash", "expectedPolicyHash"];
  const fullKeys = ["collectionId", "phaseId", "payer", "authorizer", "initialRecipients", "beneficiaries", "tokenData",
    "mintCommitments", "expectedPolicyHash", "authorizationId", "contextHash", "resolverData"];
  const actual = Object.keys(value).sort().join(",");
  const normalizedSource = actual === fullKeys.sort().join(",") ? normalizeBatch(value as MintGateBatch) : value;
  if (actual !== fullKeys.sort().join(",")) exactKeys(value, narrowKeys, "delegate mint batch");
  if (!Array.isArray(normalizedSource.initialRecipients) || !Array.isArray(normalizedSource.beneficiaries)) throw new Error("Delegate recipients and beneficiaries must be arrays");
  if (normalizedSource.initialRecipients.length === 0 || normalizedSource.initialRecipients.length > MINT_GATE_CLIENT_MAX_BATCH
    || normalizedSource.initialRecipients.length !== normalizedSource.beneficiaries.length) throw new Error("Delegate route arrays have invalid lengths");
  const normalizedVault = address(vault, "vault");
  const initialRecipients = normalizedSource.initialRecipients.map((item, i) => address(item, `initialRecipients[${i}]`));
  const beneficiaries = normalizedSource.beneficiaries.map((item, i) => address(item, `beneficiaries[${i}]`));
  if ([...initialRecipients, ...beneficiaries].some(item => !same(item, normalizedVault))) throw new Error("Delegate delivery and beneficiary routes must all equal vault");
  const payer = address(normalizedSource.payer, "payer");
  if (same(payer, normalizedVault)) throw new Error("Delegate payer must differ from vault");
  const authorizer = address(normalizedSource.authorizer, "authorizer", true);
  if (!same(authorizer, ZeroAddress)) throw new Error("Delegate authorizer must be zero");
  return Object.freeze({ collectionId: uint(normalizedSource.collectionId, 256, "collectionId", true), phaseId: bytes32(normalizedSource.phaseId, "phaseId", false),
    payer, authorizer, initialRecipients: freezeArray(initialRecipients), beneficiaries: freezeArray(beneficiaries),
    contextHash: bytes32(normalizedSource.contextHash, "contextHash"), expectedPolicyHash: bytes32(normalizedSource.expectedPolicyHash, "expectedPolicyHash", false) });
}

export function delegateMintRequest(manager: Address, executor: Address, batch: DelegateMintBatchInput | MintGateBatch, vault: Address, nonce: Hex): DelegateMintRequest {
  const normalizedVault = address(vault, "vault");
  const normalized = normalizeDelegateBatch(batch, normalizedVault);
  return Object.freeze({ manager: address(manager, "manager"), executor: address(executor, "executor"), ...normalized,
    gateData: delegateGateData(normalizedVault, nonce) });
}

function normalizeDelegateRequest(value: DelegateMintRequest): DelegateMintRequest {
  exactKeys(value, ["manager", "executor", "collectionId", "phaseId", "payer", "authorizer", "initialRecipients", "beneficiaries",
    "contextHash", "expectedPolicyHash", "gateData"], "delegate mint request");
  const encoded = bytes(value.gateData, "delegate gateData", 64);
  if ((encoded.length - 2) / 2 !== 64) throw new Error("Delegate gateData must contain exactly 64 bytes");
  const [vault] = coder.decode(["address", "bytes32"], encoded) as unknown as [Address, Hex];
  const normalized = normalizeDelegateBatch({ collectionId: value.collectionId, phaseId: value.phaseId, payer: value.payer,
    authorizer: value.authorizer, initialRecipients: value.initialRecipients, beneficiaries: value.beneficiaries,
    contextHash: value.contextHash, expectedPolicyHash: value.expectedPolicyHash }, vault);
  return Object.freeze({ manager: address(value.manager, "manager"), executor: address(value.executor, "executor"), ...normalized, gateData: encoded });
}

export function delegateMintAuthorizationId(chainId: bigint, gate: Address, configHash: Hex, request: DelegateMintRequest): Hex {
  return keccak256(coder.encode(["bytes32", "uint256", "address", "bytes32", delegateRequestTuple],
    [domains.delegateAuthorization, uint(chainId, 256, "chainId", true), address(gate, "delegate gate"),
      bytes32(configHash, "delegate gate config hash", false), normalizeDelegateRequest(request)])) as Hex;
}

export function delegateMintNullifier(chainId: bigint, gate: Address, manager: Address, collectionId: bigint, phaseId: Hex,
  payer: Address, vault: Address, nonce: Hex): Hex {
  const normalizedPayer = address(payer, "payer"), normalizedVault = address(vault, "vault");
  if (same(normalizedPayer, normalizedVault)) throw new Error("Delegate payer must differ from vault");
  return keccak256(coder.encode(["bytes32", "uint256", "address", "address", "uint256", "bytes32", "address", "address", "bytes32"],
    [domains.delegateNullifier, uint(chainId, 256, "chainId", true), address(gate, "delegate gate"), address(manager, "manager"),
      uint(collectionId, 256, "collectionId", true), bytes32(phaseId, "phaseId", false), normalizedPayer, normalizedVault, bytes32(nonce, "nonce")])) as Hex;
}

export function mintAllowlistGateConfigHash(root: Hex, counterId: Hex): Hex {
  return keccak256(coder.encode(["bytes32", "bytes32", "bytes32"],
    [domains.allowlistConfig, bytes32(root, "allowlist root", false), bytes32(counterId, "counterId", false)])) as Hex;
}

function supportedPrice(maxCount: unknown, hasPriceOverride: unknown, priceOverride: unknown): bigint {
  const count = uint(maxCount, 64, "maxCount", true);
  if (typeof hasPriceOverride !== "boolean") throw new Error("hasPriceOverride must be boolean");
  const price = uint(priceOverride, 256, "priceOverride");
  if (!hasPriceOverride && price !== 0n) throw new Error("A disabled allowlist price override must be zero");
  return count;
}

export function mintAllowlistLeaf(input: MintAllowlistLeafInput): Hex {
  exactKeys(input, ["chainId", "manager", "collectionId", "phaseId", "counterId", "account", "maxCount", "hasPriceOverride", "priceOverride"], "allowlist leaf input");
  const inner = keccak256(coder.encode(["bytes32", "uint256", "address", "uint256", "bytes32", "bytes32", "address", "uint64", "bool", "uint256"],
    [domains.allowlistLeaf, uint(input.chainId, 256, "chainId", true), address(input.manager, "manager"),
      uint(input.collectionId, 256, "collectionId", true), bytes32(input.phaseId, "phaseId", false), bytes32(input.counterId, "counterId", false),
      address(input.account, "account"), supportedPrice(input.maxCount, input.hasPriceOverride, input.priceOverride), input.hasPriceOverride, input.priceOverride])) as Hex;
  return keccak256(inner) as Hex;
}

function normalizeProof(value: MintAllowlistProof, name: string): MintAllowlistProof {
  exactKeys(value, ["maxCount", "hasPriceOverride", "priceOverride", "proof"], name);
  if (!Array.isArray(value.proof) || value.proof.length > MINT_GATE_CLIENT_MAX_PROOF_NODES) throw new Error(`${name}.proof exceeds the client boundary`);
  return Object.freeze({ maxCount: supportedPrice(value.maxCount, value.hasPriceOverride, value.priceOverride), hasPriceOverride: value.hasPriceOverride,
    priceOverride: value.priceOverride, proof: freezeArray(value.proof.map((item, index) => bytes32(item, `${name}.proof[${index}]`))) });
}

function sortedPair(a: Hex, b: Hex): Hex {
  return keccak256(coder.encode(["bytes32", "bytes32"], BigInt(a) < BigInt(b) ? [a, b] : [b, a])) as Hex;
}

export function verifyMintAllowlistProof(root: Hex, leaf: Hex, siblings: readonly Hex[]): boolean {
  const expected = bytes32(root, "allowlist root", false);
  let computed = bytes32(leaf, "allowlist leaf");
  if (!Array.isArray(siblings) || siblings.length > MINT_GATE_CLIENT_MAX_PROOF_NODES) throw new Error("Merkle proof exceeds the client boundary");
  for (let i = 0; i < siblings.length; ++i) computed = sortedPair(computed, bytes32(siblings[i], `siblings[${i}]`));
  return same(computed, expected);
}

function normalizeGroups(groups: readonly (readonly MintAllowlistProof[])[]): readonly (readonly MintAllowlistProof[])[] {
  if (!Array.isArray(groups) || groups.length === 0 || groups.length > MINT_GATE_CLIENT_MAX_BATCH) throw new Error("Allowlist proof groups have invalid length");
  const typedGroups: readonly (readonly MintAllowlistProof[])[] = groups;
  let total = 0;
  for (let i = 0; i < typedGroups.length; ++i) {
    const group = typedGroups[i];
    if (!Array.isArray(group) || group.length === 0) throw new Error(`Allowlist proof group ${i} must be nonempty`);
    total += group.length;
    if (total > MINT_GATE_CLIENT_MAX_BATCH) throw new Error("Allowlist proofs exceed the client boundary");
  }
  const output = typedGroups.map((group, i) => freezeArray(group.map((proof, j) => normalizeProof(proof, `proofs[${i}][${j}]`))));
  if (total > MINT_GATE_CLIENT_MAX_BATCH) throw new Error("Allowlist proofs exceed the client boundary");
  return freezeArray(output);
}

export function mintAllowlistResolverData(groups: readonly (readonly MintAllowlistProof[])[]): Hex {
  const encoded = coder.encode([`${allowlistProofTuple}[][]`], [normalizeGroups(groups)]) as Hex;
  return bytes(encoded, "allowlist resolverData", MAX_TOTAL_TOKEN_DATA_BYTES);
}

export function mintAllowlistProofValuesHash(counterIds: readonly Hex[], groups: readonly (readonly MintAllowlistProof[])[]): Hex {
  if (!Array.isArray(counterIds)) throw new Error("counterIds must be an array");
  const proofs = normalizeGroups(groups);
  if (counterIds.length !== proofs.length) throw new Error("counterIds and proof groups must have the same length");
  const ids = counterIds.map((item, index) => bytes32(item, `counterIds[${index}]`, false));
  const groupHashes = proofs.map((group, index) => {
    const values = group.map(proof => keccak256(coder.encode(["uint64", "bool", "uint256"],
      [proof.maxCount, proof.hasPriceOverride, proof.priceOverride])) as Hex);
    return keccak256(coder.encode(["bytes32", "bytes32[]"], [ids[index], values])) as Hex;
  });
  return keccak256(coder.encode(["bytes32", "bytes32[]"], [domains.allowlistProofValues, groupHashes])) as Hex;
}

export function mintAllowlistGateData(nonce: Hex): Hex {
  return coder.encode(["bytes32"], [bytes32(nonce, "nonce")]) as Hex;
}

function normalizeAllowlistBinding(value: MintAllowlistAuthorizationBinding): MintAllowlistAuthorizationBinding {
  exactKeys(value, ["manager", "ledger", "executor", "collectionId", "phaseId", "payer", "expectedPolicyHash", "contextHash",
    "initialRecipientsHash", "beneficiariesHash", "tokenDataHash", "mintCommitmentsHash", "proofValuesHash", "nonce"], "allowlist authorization binding");
  return Object.freeze({ manager: address(value.manager, "manager"), ledger: address(value.ledger, "ledger"), executor: address(value.executor, "executor"),
    collectionId: uint(value.collectionId, 256, "collectionId", true), phaseId: bytes32(value.phaseId, "phaseId", false), payer: address(value.payer, "payer"),
    expectedPolicyHash: bytes32(value.expectedPolicyHash, "expectedPolicyHash", false), contextHash: bytes32(value.contextHash, "contextHash"),
    initialRecipientsHash: bytes32(value.initialRecipientsHash, "initialRecipientsHash"), beneficiariesHash: bytes32(value.beneficiariesHash, "beneficiariesHash"),
    tokenDataHash: bytes32(value.tokenDataHash, "tokenDataHash"), mintCommitmentsHash: bytes32(value.mintCommitmentsHash, "mintCommitmentsHash"),
    proofValuesHash: bytes32(value.proofValuesHash, "proofValuesHash"), nonce: bytes32(value.nonce, "nonce") });
}

export function mintAllowlistAuthorizationBinding(manager: Address, ledger: Address, executor: Address, rawBatch: MintGateBatch,
  proofValuesHash: Hex, nonce: Hex): MintAllowlistAuthorizationBinding {
  const batch = normalizeBatch(rawBatch);
  if (!same(batch.authorizer, ZeroAddress)) throw new Error("Allowlist batch authorizer must be zero");
  const hashes = mintBatchHashes({ initialRecipients: batch.initialRecipients, beneficiaries: batch.beneficiaries,
    tokenData: batch.tokenData, mintCommitments: batch.mintCommitments });
  return normalizeAllowlistBinding({ manager, ledger, executor, collectionId: batch.collectionId, phaseId: batch.phaseId, payer: batch.payer,
    expectedPolicyHash: batch.expectedPolicyHash, contextHash: batch.contextHash, initialRecipientsHash: hashes.initialRecipientsHash,
    beneficiariesHash: hashes.beneficiariesHash, tokenDataHash: hashes.tokenDataArrayHash, mintCommitmentsHash: hashes.mintCommitmentsHash,
    proofValuesHash, nonce });
}

export function mintAllowlistAuthorizationId(chainId: bigint, gate: Address, configHash: Hex, binding: MintAllowlistAuthorizationBinding): Hex {
  return keccak256(coder.encode(["bytes32", "uint256", "address", "bytes32", allowlistBindingTuple],
    [domains.allowlistAuthorization, uint(chainId, 256, "chainId", true), address(gate, "allowlist gate"),
      bytes32(configHash, "allowlist gate config hash", false), normalizeAllowlistBinding(binding)])) as Hex;
}

export function mintAllowlistNullifier(chainId: bigint, gate: Address, manager: Address, ledger: Address, collectionId: bigint,
  phaseId: Hex, payer: Address, nonce: Hex): Hex {
  return keccak256(coder.encode(["bytes32", "uint256", "address", "address", "address", "uint256", "bytes32", "address", "bytes32"],
    [domains.allowlistNullifier, uint(chainId, 256, "chainId", true), address(gate, "allowlist gate"), address(manager, "manager"),
      address(ledger, "ledger"), uint(collectionId, 256, "collectionId", true), bytes32(phaseId, "phaseId", false),
      address(payer, "payer"), bytes32(nonce, "nonce")])) as Hex;
}
