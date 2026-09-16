import {
  Interface, TypedDataEncoder, ZeroAddress, ZeroHash, getAddress, isHexString, keccak256, toQuantity, toUtf8Bytes,
  type BlockTag, type Provider,
} from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import {
  assertCurrentArtistDigest, currentArtistTypedData, prepareCurrentArtistOperation,
  type CurrentArtistSigningKind, type CurrentArtistSigningMessages, type CurrentArtistSubmissions,
  type PreparedCurrentArtistOperation,
} from "./current-artist.js";
import type { SigningPayload } from "./signing.js";

export const CURRENT_ARTIST_CEREMONY_TOOL = Object.freeze({
  name: "6529 Stream Artist Ceremony",
  version: "0.1.0",
  supportedWalletClasses: Object.freeze(["eoa", "safe-erc1271"] as const),
});

export type CurrentArtistWalletClass = (typeof CURRENT_ARTIST_CEREMONY_TOOL.supportedWalletClasses)[number];
export type CurrentArtistExecutionMode = "direct" | "relayed";
export type CurrentArtistCeremonyDetails<K extends CurrentArtistSigningKind> = Omit<CurrentArtistSubmissions[K], "signature">;

export interface CurrentArtistFactPreimage {
  readonly encoding: "utf8" | "hex";
  readonly value: string;
}
export interface CurrentArtistFactInput {
  /** Exact EIP-712 message field. Every signed field must appear once. */
  readonly field: string;
  readonly label: string;
  /** Human-readable resolved meaning, not the bare signed value. */
  readonly meaning: string;
  /** Public read, artifact, or review input from which the meaning was resolved. */
  readonly source: string;
  /** Required for raw bytes32 identifiers whose bytes are meaningful without hashing. */
  readonly representation?: string;
  /** Required for known nonzero hash commitments so the commitment can be recomputed locally. */
  readonly preimage?: CurrentArtistFactPreimage;
}
export interface CurrentArtistSigningFact extends CurrentArtistFactInput {
  readonly solidityType: string;
  readonly signedValue: string;
  readonly recomputedValue?: Hex;
}
export type CurrentArtistCeremonyAuthority =
  | { readonly kind: "artist"; readonly artistId: Hex }
  | { readonly kind: "collaborator-registration"; readonly account: Address };
export interface CurrentArtistCeremonyContext {
  readonly signer: Address;
  readonly walletClass: CurrentArtistWalletClass;
  readonly executionMode: CurrentArtistExecutionMode;
  readonly authority: CurrentArtistCeremonyAuthority;
  readonly facts: readonly CurrentArtistFactInput[];
}
export interface CurrentArtistCeremony<K extends CurrentArtistSigningKind = CurrentArtistSigningKind> {
  readonly tool: typeof CURRENT_ARTIST_CEREMONY_TOOL;
  readonly kind: K;
  readonly signer: Address;
  readonly walletClass: CurrentArtistWalletClass;
  readonly executionMode: CurrentArtistExecutionMode;
  readonly authority: CurrentArtistCeremonyAuthority;
  readonly details: CurrentArtistCeremonyDetails<K>;
  readonly facts: readonly CurrentArtistSigningFact[];
  readonly payload: SigningPayload<CurrentArtistSigningMessages[K]>;
  /** Contains an empty signature. Attach a signature with prepareCurrentArtistCeremonySubmission. */
  readonly unsignedOperation: PreparedCurrentArtistOperation<CurrentArtistSigningMessages[K]>;
  /** Local integrity commitment over the complete reviewed packet, including nonce-lane context. */
  readonly reviewHash: Hex;
}
export interface CurrentArtistAuthorizationObservation {
  readonly digestObserved: boolean;
  readonly digestRevoked: boolean;
  readonly nonceConsumed: boolean;
  readonly nonceRevoked: boolean;
  readonly nextUnusedNonce: bigint;
}
export interface CurrentArtistCeremonyObservation {
  readonly blockNumber: bigint;
  readonly blockHash: Hex;
  readonly timestamp: bigint;
  /** Direct payout/attestation uses a zero submitted sentinel; its effective digest is formed at execution time. */
  readonly digestSemantics: "exact" | "execution-time-sentinel";
  readonly authorization: CurrentArtistAuthorizationObservation;
}

type RPC = Pick<Provider, "call" | "getNetwork" | "getBlock">;
const replayReads = new Interface([
  "function artistAuthorizationState(bytes32 artistId,bytes32 digest,uint256 nonce) view returns ((bool digestObserved,bool digestRevoked,bool nonceConsumed,bool nonceRevoked,uint256 nextUnusedNonce))",
  "function collaboratorRegistrationNonceState(address account,uint256 nonce) view returns (bool consumed,uint256 nextUnusedNonce)",
]);
const commitmentFields: Readonly<Record<CurrentArtistSigningKind, readonly string[]>> = Object.freeze({
  artistAcceptance: Object.freeze(["bindingHash", "identityRecordHash"]),
  artistPolicyConsent: Object.freeze(["policyHash"]),
  artistEconomicsConsent: Object.freeze(["assignmentHash"]),
  artistPayoutDesignation: Object.freeze(["previousDesignationRecordHash"]),
  artistAttestation: Object.freeze(["subjectStateHash", "statementHash", "statementURIHash"]),
  artistContentRatification: Object.freeze(["contentStateHash"]),
  collaboratorIdentityAcceptance: Object.freeze(["identityRecordHash"]),
  collaboratorAcceptance: Object.freeze(["bindingHash"]),
});

const equal = (a: string, b: string) => a.toLowerCase() === b.toLowerCase();
function address(value: unknown): Address {
  if (typeof value !== "string") throw new Error("Expected address");
  const result = getAddress(value) as Address;
  if (result === ZeroAddress) throw new Error("Zero ceremony address");
  return result;
}
function hash(value: unknown, name: string): Hex {
  if (typeof value !== "string" || !isHexString(value, 32)) throw new Error(`${name} must be bytes32`);
  return value.toLowerCase() as Hex;
}
function text(value: unknown, name: string): string {
  if (typeof value !== "string" || value.length === 0 || value.length > 4096 || value.trim() !== value || /[\u0000-\u001f\u007f]/u.test(value)) {
    throw new Error(`${name} must be bounded, trimmed human-readable text`);
  }
  return value;
}
function immutable<T>(value: T): T {
  if (Array.isArray(value)) return Object.freeze(value.map(item => immutable(item))) as T;
  if (value && typeof value === "object") {
    return Object.freeze(Object.fromEntries(Object.entries(value).map(([key, item]) => [key, immutable(item)]))) as T;
  }
  return value;
}
function stable(value: unknown): string {
  if (typeof value === "bigint") return `{"$bigint":"${value.toString()}"}`;
  if (typeof value === "string" || typeof value === "boolean" || value === null) return JSON.stringify(value);
  if (Array.isArray(value)) return `[${value.map(stable).join(",")}]`;
  if (value && typeof value === "object") return `{${Object.keys(value).sort().map(key => `${JSON.stringify(key)}:${stable((value as Record<string, unknown>)[key])}`).join(",")}}`;
  throw new Error("Unsupported Artist ceremony packet value");
}
function reviewHash(value: object): Hex { return keccak256(toUtf8Bytes(stable(value))) as Hex; }
function valueText(value: unknown): string {
  if (typeof value === "bigint") return value.toString();
  if (typeof value === "string") return value.startsWith("0x") ? value.toLowerCase() : value;
  throw new Error("Unsupported signed fact value");
}
function factPreimage(kind: CurrentArtistSigningKind, input: CurrentArtistFactInput, signedValue: string): { representation?: string; preimage?: CurrentArtistFactPreimage; recomputedValue?: Hex } {
  if (!isHexString(signedValue, 32)) {
    if (input.preimage !== undefined || input.representation !== undefined) throw new Error(`${input.field} is not a bytes32 fact`);
    return {};
  }
  const commitment = commitmentFields[kind].includes(input.field);
  if (!commitment) {
    if (input.preimage !== undefined) throw new Error(`${input.field} is a raw identifier, not a hash commitment`);
    return { representation: text(input.representation, `${input.field} representation`) };
  }
  if (input.representation !== undefined) throw new Error(`${input.field} is a hash commitment, not a raw identifier`);
  if (equal(signedValue, ZeroHash)) {
    if (input.preimage !== undefined) throw new Error(`${input.field} is zero and has no committed preimage`);
    return {};
  }
  if (!input.preimage || (input.preimage.encoding !== "utf8" && input.preimage.encoding !== "hex")) {
    throw new Error(`${input.field} requires a utf8 or hex preimage`);
  }
  let bytes: string | Uint8Array;
  if (input.preimage.encoding === "utf8") bytes = toUtf8Bytes(text(input.preimage.value, `${input.field} preimage`));
  else {
    if (!isHexString(input.preimage.value, true)) throw new Error(`${input.field} hex preimage is invalid`);
    bytes = input.preimage.value;
  }
  const recomputedValue = keccak256(bytes).toLowerCase() as Hex;
  if (!equal(recomputedValue, signedValue)) throw new Error(`${input.field} preimage differs from the signed commitment`);
  return { preimage: immutable({ ...input.preimage }), recomputedValue };
}
function exactFacts<K extends CurrentArtistSigningKind>(
  kind: K, payload: SigningPayload<CurrentArtistSigningMessages[K]>, inputs: readonly CurrentArtistFactInput[],
): readonly CurrentArtistSigningFact[] {
  if (!Array.isArray(inputs)) throw new Error("facts must be an array");
  const fields = payload.types[payload.primaryType]!;
  const expected = fields.map(field => field.name).sort();
  const actual = inputs.map(fact => fact?.field).sort();
  if (expected.join("\u0000") !== actual.join("\u0000")) throw new Error("facts must cover every signed field exactly once");
  const byName = new Map(inputs.map(input => [input.field, input]));
  return Object.freeze(fields.map(field => {
    const input = byName.get(field.name)!;
    const signedValue = valueText((payload.message as unknown as Record<string, unknown>)[field.name]);
    const label = text(input.label, `${field.name} label`), meaning = text(input.meaning, `${field.name} meaning`), source = text(input.source, `${field.name} source`);
    if (equal(meaning, signedValue)) throw new Error(`${field.name} meaning must resolve the signed value`);
    return Object.freeze({ field: field.name, solidityType: field.type, signedValue, label, meaning, source, ...factPreimage(kind, input, signedValue) });
  }));
}
function exactAuthority(kind: CurrentArtistSigningKind, signer: Address, message: Record<string, unknown>, value: CurrentArtistCeremonyAuthority): CurrentArtistCeremonyAuthority {
  if (!value || typeof value !== "object") throw new Error("Expected ceremony authority locator");
  if (kind === "collaboratorIdentityAcceptance") {
    if (value.kind !== "collaborator-registration") throw new Error("Collaborator identity acceptance requires the account nonce lane");
    const account = address(value.account);
    if (!equal(account, signer) || !equal(account, String(message.account))) throw new Error("Collaborator registration signer differs from signed account");
    return Object.freeze({ kind: value.kind, account });
  }
  if (value.kind !== "artist") throw new Error("Current Artist operation requires an artistId nonce lane");
  const artistId = hash(value.artistId, "artistId");
  if (equal(artistId, ZeroHash)) throw new Error("Zero artistId");
  if (kind === "artistPayoutDesignation" && !equal(artistId, String(message.artistId))) throw new Error("Payout artistId differs from the nonce lane");
  return Object.freeze({ kind: value.kind, artistId });
}
function exactDetails<K extends CurrentArtistSigningKind>(kind: K, details: CurrentArtistCeremonyDetails<K>): CurrentArtistCeremonyDetails<K> {
  if (!details || typeof details !== "object" || Array.isArray(details)) throw new Error("Expected ceremony operation details");
  const expected = kind === "artistEconomicsConsent" ? ["collectionId"]
    : kind === "artistAttestation" ? ["statement", "statementURI"]
      : kind === "collaboratorIdentityAcceptance" ? ["displayName", "document"] : [];
  if (Object.keys(details).sort().join("\u0000") !== expected.join("\u0000")) throw new Error("Unexpected ceremony operation details");
  return immutable({ ...details }) as CurrentArtistCeremonyDetails<K>;
}
function validateDatedMode(kind: CurrentArtistSigningKind, message: Record<string, unknown>, mode: CurrentArtistExecutionMode): void {
  if (kind !== "artistPayoutDesignation" && kind !== "artistAttestation") return;
  const signedAt = message.signedAt;
  if (typeof signedAt !== "bigint") throw new Error("Dated Artist ceremony signedAt is invalid");
  if (mode === "direct" && signedAt !== 0n) throw new Error("Direct dated Artist ceremony must use the zero execution-time sentinel");
  if (mode === "relayed" && signedAt === 0n) throw new Error("Relayed dated Artist ceremony requires an explicit signedAt");
}

/**
 * Capture the exact signed fields and their resolved public meaning before asking a wallet to sign.
 * This is a bounded client packet for the eight families supported by current-artist.ts.
 */
export function captureCurrentArtistCeremony<K extends CurrentArtistSigningKind>(
  kind: K,
  chainId: bigint,
  registry: Address,
  message: CurrentArtistSigningMessages[K],
  details: CurrentArtistCeremonyDetails<K>,
  context: CurrentArtistCeremonyContext,
): CurrentArtistCeremony<K> {
  const signer = address(context.signer);
  if (!CURRENT_ARTIST_CEREMONY_TOOL.supportedWalletClasses.includes(context.walletClass)) throw new Error("Unsupported Artist wallet class");
  if (context.executionMode !== "direct" && context.executionMode !== "relayed") throw new Error("Unsupported Artist execution mode");
  const payload = currentArtistTypedData(kind, chainId, registry, message);
  validateDatedMode(kind, payload.message as unknown as Record<string, unknown>, context.executionMode);
  const authority = exactAuthority(kind, signer, payload.message as unknown as Record<string, unknown>, context.authority);
  const frozenDetails = exactDetails(kind, details);
  const unsignedOperation = prepareCurrentArtistOperation(kind, chainId, registry, payload.message,
    { ...frozenDetails, signature: "0x" } as unknown as CurrentArtistSubmissions[K]);
  const packet = { tool: CURRENT_ARTIST_CEREMONY_TOOL, kind, signer, walletClass: context.walletClass,
    executionMode: context.executionMode, authority, details: frozenDetails, facts: exactFacts(kind, payload, context.facts), payload, unsignedOperation };
  return Object.freeze({ ...packet, reviewHash: reviewHash(packet) });
}

/** Recompute every disclosed bytes32 fact and the EIP-712 digest without an RPC or operator service. */
export function recomputeCurrentArtistCeremony(ceremony: CurrentArtistCeremony): Hex {
  if (!ceremony || typeof ceremony !== "object" || ceremony.tool.name !== CURRENT_ARTIST_CEREMONY_TOOL.name
    || ceremony.tool.version !== CURRENT_ARTIST_CEREMONY_TOOL.version
    || JSON.stringify(ceremony.tool.supportedWalletClasses) !== JSON.stringify(CURRENT_ARTIST_CEREMONY_TOOL.supportedWalletClasses)) {
    throw new Error("Unknown Artist ceremony packet");
  }
  const signer = address(ceremony.signer);
  if (!CURRENT_ARTIST_CEREMONY_TOOL.supportedWalletClasses.includes(ceremony.walletClass)) throw new Error("Unsupported Artist wallet class");
  if (ceremony.executionMode !== "direct" && ceremony.executionMode !== "relayed") throw new Error("Unsupported Artist execution mode");
  const canonical = currentArtistTypedData(ceremony.kind, BigInt(ceremony.payload.domain.chainId ?? 0),
    ceremony.payload.domain.verifyingContract as Address, ceremony.payload.message);
  const authority = exactAuthority(ceremony.kind, signer, canonical.message as unknown as Record<string, unknown>, ceremony.authority);
  validateDatedMode(ceremony.kind, canonical.message as unknown as Record<string, unknown>, ceremony.executionMode);
  if (JSON.stringify(authority) !== JSON.stringify(ceremony.authority)) throw new Error("Artist ceremony authority locator differs");
  const details = exactDetails(ceremony.kind, ceremony.details);
  if (canonical.primaryType !== ceremony.payload.primaryType
    || JSON.stringify(canonical.types) !== JSON.stringify(ceremony.payload.types)) throw new Error("Artist ceremony schema differs");
  const facts = exactFacts(ceremony.kind, canonical, ceremony.facts);
  for (let index = 0; index < facts.length; index++) {
    if (JSON.stringify(facts[index]) !== JSON.stringify(ceremony.facts[index])) throw new Error("Artist ceremony fact capture differs");
  }
  const digest = TypedDataEncoder.hash(ceremony.payload.domain, ceremony.payload.types, ceremony.payload.message).toLowerCase() as Hex;
  if (!equal(digest, canonical.digest) || !equal(digest, ceremony.payload.digest)) throw new Error("Artist ceremony digest differs");
  const operation = prepareCurrentArtistOperation(ceremony.kind, BigInt(ceremony.payload.domain.chainId ?? 0),
    ceremony.payload.domain.verifyingContract as Address, ceremony.payload.message,
    { ...details, signature: "0x" } as unknown as CurrentArtistSubmissions[CurrentArtistSigningKind]);
  if (operation.method !== ceremony.unsignedOperation.method || operation.digestMethod !== ceremony.unsignedOperation.digestMethod
    || !equal(operation.call.to, ceremony.unsignedOperation.call.to) || !equal(operation.call.data, ceremony.unsignedOperation.call.data)
    || operation.call.value !== ceremony.unsignedOperation.call.value || !equal(operation.digestCall.to, ceremony.unsignedOperation.digestCall.to)
    || !equal(operation.digestCall.data, ceremony.unsignedOperation.digestCall.data) || operation.digestCall.value !== ceremony.unsignedOperation.digestCall.value) {
    throw new Error("Artist ceremony operation differs");
  }
  const packet = { tool: CURRENT_ARTIST_CEREMONY_TOOL, kind: ceremony.kind, signer, walletClass: ceremony.walletClass,
    executionMode: ceremony.executionMode, authority, details, facts, payload: canonical, unsignedOperation: operation };
  if (!equal(reviewHash(packet), ceremony.reviewHash)) throw new Error("Artist ceremony reviewed context differs");
  return digest;
}

function canonicalUnsignedOperation(ceremony: CurrentArtistCeremony): PreparedCurrentArtistOperation<CurrentArtistSigningMessages[CurrentArtistSigningKind]> {
  return prepareCurrentArtistOperation(ceremony.kind, BigInt(ceremony.payload.domain.chainId ?? 0),
    ceremony.payload.domain.verifyingContract as Address, ceremony.payload.message,
    { ...exactDetails(ceremony.kind, ceremony.details), signature: "0x" } as unknown as CurrentArtistSubmissions[CurrentArtistSigningKind]);
}

/** Add direct or relayed authorization bytes without changing any previously reviewed signing fact. */
export function prepareCurrentArtistCeremonySubmission<K extends CurrentArtistSigningKind>(
  ceremony: CurrentArtistCeremony<K>, signature: Hex,
): PreparedCurrentArtistOperation<CurrentArtistSigningMessages[K]> {
  recomputeCurrentArtistCeremony(ceremony);
  if (typeof signature !== "string" || !isHexString(signature, true)) throw new Error("signature must contain complete hex bytes");
  if ((ceremony.executionMode === "direct") !== (signature === "0x")) throw new Error("Signature bytes differ from the reviewed execution mode");
  return prepareCurrentArtistOperation(ceremony.kind, BigInt(ceremony.payload.domain.chainId ?? 0),
    ceremony.payload.domain.verifyingContract as Address, ceremony.payload.message,
    { ...ceremony.details, signature } as unknown as CurrentArtistSubmissions[K]);
}

/** Explicit consent-churn check against a freshly recomputed policy or assignment hash. */
export function assertCurrentArtistConsentCurrent(ceremony: CurrentArtistCeremony, currentCommitment: Hex): void {
  const current = hash(currentCommitment, "current consent commitment");
  const message = ceremony.payload.message as unknown as Record<string, unknown>;
  const field = ceremony.kind === "artistPolicyConsent" ? "policyHash"
    : ceremony.kind === "artistEconomicsConsent" ? "assignmentHash" : undefined;
  if (!field) throw new Error("Ceremony is not a policy or economics consent");
  if (!equal(current, String(message[field]))) throw new Error(`${field} changed; discard the stale ceremony and present the changed facts`);
}

async function checkedRead(provider: RPC, to: Address, method: string, args: readonly unknown[], blockTag: BlockTag): Promise<readonly unknown[]> {
  const data = replayReads.encodeFunctionData(method, args) as Hex;
  const raw = await provider.call({ to, data, value: 0n, blockTag });
  if (!isHexString(raw, true)) throw new Error("Malformed Artist authorization-state return");
  const decoded = replayReads.decodeFunctionResult(method, raw);
  if (!equal(replayReads.encodeFunctionResult(method, decoded), raw)) throw new Error("Noncanonical Artist authorization-state return");
  return decoded;
}

/**
 * Recheck chain, facade digest, deadline/signedAt, and the applicable replay lane at one pinned block.
 * A successful result is a read-only signing observation; it does not prove authority or write success.
 */
export async function inspectCurrentArtistCeremony(
  provider: RPC, ceremony: CurrentArtistCeremony, blockTag: BlockTag = "latest",
): Promise<CurrentArtistCeremonyObservation> {
  const digest = recomputeCurrentArtistCeremony(ceremony);
  const chainId = BigInt(ceremony.payload.domain.chainId ?? 0);
  if ((await provider.getNetwork()).chainId !== chainId) throw new Error("RPC chain differs from the Artist ceremony domain");
  const block = await provider.getBlock(blockTag);
  if (!block?.hash || !Number.isSafeInteger(block.number) || block.number < 0 || !Number.isSafeInteger(block.timestamp) || block.timestamp < 0) {
    throw new Error("Artist ceremony block is unavailable");
  }
  const tag = toQuantity(block.number), timestamp = BigInt(block.timestamp);
  const canonicalOperation = canonicalUnsignedOperation(ceremony);
  await assertCurrentArtistDigest(provider, canonicalOperation, { blockTag: tag });
  const message = ceremony.payload.message as unknown as Record<string, unknown>;
  const nonce = message.nonce;
  if (typeof nonce !== "bigint") throw new Error("Artist ceremony nonce is invalid");
  const deadline = message.deadline;
  if (typeof deadline === "bigint" && timestamp > deadline) throw new Error("Artist ceremony authorization expired");
  const signedAt = message.signedAt;
  const executionTimeSentinel = typeof signedAt === "bigint" && ceremony.executionMode === "direct";
  if (typeof signedAt === "bigint" && !executionTimeSentinel && (signedAt === 0n || signedAt > timestamp)) throw new Error("Artist ceremony signedAt is stale or invalid for the execution mode");
  let authorization: CurrentArtistAuthorizationObservation;
  if (ceremony.authority.kind === "artist") {
    const [state] = await checkedRead(provider, ceremony.payload.domain.verifyingContract as Address,
      "artistAuthorizationState", [ceremony.authority.artistId, digest, nonce], tag);
    const item = state as { digestObserved: boolean; digestRevoked: boolean; nonceConsumed: boolean; nonceRevoked: boolean; nextUnusedNonce: bigint };
    authorization = Object.freeze({ digestObserved: item.digestObserved, digestRevoked: item.digestRevoked,
      nonceConsumed: item.nonceConsumed, nonceRevoked: item.nonceRevoked, nextUnusedNonce: item.nextUnusedNonce });
  } else {
    const [consumed, nextUnusedNonce] = await checkedRead(provider, ceremony.payload.domain.verifyingContract as Address,
      "collaboratorRegistrationNonceState", [ceremony.authority.account, nonce], tag);
    authorization = Object.freeze({ digestObserved: false, digestRevoked: false, nonceConsumed: consumed as boolean,
      nonceRevoked: false, nextUnusedNonce: nextUnusedNonce as bigint });
  }
  if ((!executionTimeSentinel && (authorization.digestObserved || authorization.digestRevoked)) || authorization.nonceConsumed || authorization.nonceRevoked) {
    throw new Error("Artist ceremony nonce or digest is already used or revoked");
  }
  if (ceremony.executionMode === "direct" && nonce !== authorization.nextUnusedNonce) {
    throw new Error("Direct Artist ceremony nonce differs from the current allocator hint");
  }
  const finish = await provider.getBlock(tag);
  if (!finish?.hash || !equal(finish.hash, block.hash)) throw new Error("Artist ceremony observation block changed");
  return Object.freeze({ blockNumber: BigInt(block.number), blockHash: hash(block.hash, "block hash"), timestamp,
    digestSemantics: executionTimeSentinel ? "execution-time-sentinel" : "exact", authorization });
}
