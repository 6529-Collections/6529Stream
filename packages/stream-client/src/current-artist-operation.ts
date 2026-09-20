import { Interface, ZeroAddress, ZeroHash, getAddress, id, isHexString, keccak256, toUtf8Bytes } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import type { UnsignedCall } from "./binding.js";
import type { SigningPayload } from "./signing.js";
import { buildSigningPayload } from "./signing-payload.js";
import { currentArtistTypedData, type CurrentArtistPolicyConsent } from "./current-artist.js";

interface DeadlineAuthorization { readonly nonce: bigint; readonly deadline: bigint }
export interface CurrentArtistBindingRefusal extends DeadlineAuthorization {
  readonly core: Address; readonly collectionId: bigint; readonly bindingGeneration: bigint;
  readonly bindingHash: Hex; readonly reasonHash: Hex;
}
export interface CurrentArtistSaleConsent extends DeadlineAuthorization {
  readonly core: Address; readonly saleAdapter: Address; readonly collectionId: bigint;
  readonly saleId: Hex; readonly saleConfigHash: Hex;
}
export interface CurrentArtistRoyaltyFreeze extends DeadlineAuthorization {
  readonly core: Address; readonly resolver: Address; readonly collectionId: bigint;
  readonly revenueClass: Hex; readonly expectedAssignmentHash: Hex;
}
export interface CurrentArtistContentFreeze extends DeadlineAuthorization {
  readonly core: Address; readonly metadataContract: Address; readonly collectionId: bigint;
  readonly lockClasses: readonly Hex[]; readonly expectedStateHash: Hex;
}
export interface CurrentArtistAuthorizationRevocation extends DeadlineAuthorization {
  readonly artistId: Hex; readonly revokedDigest: Hex; readonly revokedNonce: bigint;
}
export interface CurrentArtistIdentityRevision {
  readonly artistId: Hex; readonly previousRecordHash: Hex; readonly revisedRecordHash: Hex;
  readonly nonce: bigint;
  /** Direct zero is an execution-time sentinel; positive values are the original signedAt. */
  readonly signedAt: bigint;
}
export interface CurrentArtistDelegationGrant {
  readonly core: Address; readonly delegate: Address;
  /** Zero grants global collection scope. */
  readonly collectionId: bigint;
  readonly capabilities: bigint; readonly notBefore: bigint; readonly expiresAt: bigint;
  /** Zero means unlimited uses. */
  readonly maxUses: bigint;
  readonly constraintsHash: Hex; readonly nonce: bigint;
}
export interface CurrentArtistDelegationRevocation extends DeadlineAuthorization {
  readonly artistId: Hex; readonly delegate: Address; readonly delegationRecordHash: Hex;
  readonly reasonHash: Hex;
}
/** Delegation changes the authorization lane and calldata, never the original signed schema. */
export type CurrentArtistDelegatedPolicyConsent = CurrentArtistPolicyConsent;
export type CurrentArtistDelegatedSaleConsent = CurrentArtistSaleConsent;
export interface CurrentArtistOperationMessages {
  bindingRefusal: CurrentArtistBindingRefusal;
  saleConsent: CurrentArtistSaleConsent;
  royaltyFreeze: CurrentArtistRoyaltyFreeze;
  contentFreeze: CurrentArtistContentFreeze;
  authorizationRevocation: CurrentArtistAuthorizationRevocation;
  identityRevision: CurrentArtistIdentityRevision;
  delegationGrant: CurrentArtistDelegationGrant;
  delegationRevocation: CurrentArtistDelegationRevocation;
  delegatedPolicyConsent: CurrentArtistDelegatedPolicyConsent;
  delegatedSaleConsent: CurrentArtistDelegatedSaleConsent;
}
export type CurrentArtistOperationKind = keyof CurrentArtistOperationMessages;
export interface CurrentArtistOperationDetails {
  /** Supplemental calldata: reasonURI is outside the original signed digest. */
  bindingRefusal: { readonly reasonURI: string };
  saleConsent: Readonly<Record<string, never>>;
  royaltyFreeze: Readonly<Record<string, never>>;
  contentFreeze: Readonly<Record<string, never>>;
  authorizationRevocation: Readonly<Record<string, never>>;
  /** The original signature binds the document hash, not its URI or display name. */
  identityRevision: { readonly identityRecordURI: string; readonly document: Hex; readonly displayName: string };
  delegationGrant: Readonly<Record<string, never>>;
  delegationRevocation: Readonly<Record<string, never>>;
  /** Original grant association, outside the policy/sale signed fields. */
  delegatedPolicyConsent: { readonly grant: Hex };
  delegatedSaleConsent: { readonly grant: Hex };
}
interface OperationContext {
  readonly chainId: bigint;
  /** Actual immutable Onboarding Registry facade, never an owner or coordinator. */
  readonly registry: Address;
  readonly caller: Address;
  /** Supplied signer claim: grantor for delegation revocation, delegate for delegated consent; live reads establish authority. */
  readonly signer: Address;
  /** Supplied authority/replay locator; delegation grant keeps this outside its original signed schema. */
  readonly artistId: Hex;
  readonly mode: "direct" | "signature";
  /** Opaque EOA/ERC-1271 proof; an empty contract proof can be valid for a distinct caller. */
  readonly signature: Hex;
}
export type CurrentArtistOperationRequest<K extends CurrentArtistOperationKind = CurrentArtistOperationKind> = {
  [P in K]: OperationContext & {
    readonly kind: P;
    readonly message: CurrentArtistOperationMessages[P];
    readonly details: CurrentArtistOperationDetails[P];
  }
}[K];
export interface PreparedCurrentArtistAction<K extends CurrentArtistOperationKind = CurrentArtistOperationKind> {
  readonly request: CurrentArtistOperationRequest<K>;
  readonly payload: SigningPayload<CurrentArtistOperationMessages[K]>;
  readonly operationId: bigint;
  readonly method: string;
  readonly digestMethod: string;
  readonly call: UnsignedCall;
  readonly digestCall: UnsignedCall;
}

const saleSigning = ["StreamArtistSaleConsent", "address core,address saleAdapter,uint256 collectionId,bytes32 saleId,bytes32 saleConfigHash,uint256 nonce,uint64 deadline"] as const;
const saleTerms = "(uint256 collectionId,address saleAdapter,bytes32 saleId,bytes32 saleConfigHash)";
const schemes = {
  bindingRefusal: ["StreamArtistBindingRefusal", "address core,uint256 collectionId,uint64 bindingGeneration,bytes32 bindingHash,bytes32 reasonHash,uint256 nonce,uint64 deadline", 3n, "refuseArtistBinding", "bindingRefusalDigest", "(uint256 collectionId,uint64 generation,bytes32 bindingHash,bytes32 reasonHash,string reasonURI)"],
  saleConsent: [...saleSigning, 16n, "recordSaleConsent", "saleConsentDigest", saleTerms],
  royaltyFreeze: ["StreamArtistRoyaltyFreeze", "address core,address resolver,uint256 collectionId,bytes32 revenueClass,bytes32 expectedAssignmentHash,uint256 nonce,uint64 deadline", 20n, "authorizeArtistRoyaltyFreeze", "royaltyFreezeDigest", "(address resolver,uint256 collectionId,bytes32 revenueClass,bytes32 expectedAssignmentHash)"],
  contentFreeze: ["StreamArtistContentFreeze", "address core,address metadataContract,uint256 collectionId,bytes32[] lockClasses,bytes32 expectedStateHash,uint256 nonce,uint64 deadline", 21n, "authorizeArtistContentFreeze", "contentFreezeDigest", "(uint256 collectionId,address metadataContract,bytes32[] lockClasses,bytes32 expectedStateHash)"],
  authorizationRevocation: ["StreamArtistAuthorizationRevocation", "bytes32 artistId,bytes32 revokedDigest,uint256 revokedNonce,uint256 nonce,uint64 deadline", 54n, "revokeArtistAuthorization", "authorizationRevocationDigest", "(bytes32 artistId,bytes32 revokedDigest,uint256 revokedNonce)"],
  identityRevision: ["StreamArtistIdentityRevision", "bytes32 artistId,bytes32 previousRecordHash,bytes32 revisedRecordHash,uint256 nonce,uint64 signedAt", 25n, "recordIdentityRevision", "identityRevisionDigest", "(bytes32 artistId,bytes32 previousRecordHash,bytes32 revisedRecordHash,string identityRecordURI)"],
  delegationGrant: ["StreamArtistDelegation", "address core,address delegate,uint256 collectionId,uint32 capabilities,uint64 notBefore,uint64 expiresAt,uint64 maxUses,bytes32 constraintsHash,uint256 nonce", 26n, "grantArtistDelegation", "delegationGrantDigest", "(bytes32 artistId,address delegate,uint256 collectionId,uint32 capabilities,uint64 notBefore,uint64 expiresAt,uint64 maxUses,bytes32 constraintsHash)"],
  delegationRevocation: ["StreamArtistDelegationRevocation", "bytes32 artistId,address delegate,bytes32 delegationRecordHash,bytes32 reasonHash,uint256 nonce,uint64 deadline", 27n, "revokeArtistDelegation", "delegationRevocationDigest", "(bytes32 artistId,address delegate,bytes32 delegationRecordHash,bytes32 reasonHash)"],
  delegatedPolicyConsent: ["StreamArtistPolicyConsent", "address core,address mintManager,uint256 collectionId,bytes32 phaseId,bytes32 policyHash,uint256 nonce,uint64 deadline", 14n, "recordDelegatedPolicyConsent", "policyConsentDigest", "(uint256 collectionId,bytes32 phaseId,bytes32 policyHash)"],
  delegatedSaleConsent: [...saleSigning, 16n, "recordDelegatedSaleConsent", "saleConsentDigest", saleTerms],
} as const;
const authorization = "(uint256 nonce,uint64 time,bytes signature)";
/** Original Artist write/getter variants, including the additive delegated op14/op16 transports. */
export const CURRENT_ARTIST_OPERATION_ABI: readonly string[] = Object.freeze([...new Set(Object.values(schemes).flatMap(([, , , method, getter, tuple]) => [
  `function ${method}(${tuple},${method === "recordDelegatedPolicyConsent" || method === "recordDelegatedSaleConsent" ? "bytes32 grant," : ""}${authorization}${method === "recordIdentityRevision" ? ",bytes document,string displayName" : ""}) returns (bytes32)`,
  `function ${getter}(${tuple},${authorization}) view returns (bytes32)`,
]))]);
const operations = new Interface(CURRENT_ARTIST_OPERATION_ABI);
const royaltyClass = id("ROYALTY_ERC2981");

function exact(input: unknown, keys: readonly string[], label: string): asserts input is Record<string, unknown> {
  if (!input || typeof input !== "object" || Array.isArray(input)) throw new Error(`${label} must be an object`);
  const own = Reflect.ownKeys(input);
  if (own.length !== keys.length || own.some(key => typeof key !== "string" || !keys.includes(key))) throw new Error(`${label} has unexpected fields`);
}
function address(input: unknown, label: string): Address {
  if (typeof input !== "string") throw new Error(`${label} must be an address`);
  const result = getAddress(input) as Address;
  if (result === ZeroAddress) throw new Error(`${label} must be nonzero`);
  return result;
}
function nonzeroHash(input: unknown, label: string): Hex {
  if (typeof input !== "string" || !isHexString(input, 32) || input.toLowerCase() === ZeroHash) throw new Error(`${label} must be nonzero bytes32`);
  return input.toLowerCase() as Hex;
}
function text(input: unknown, label: string, minimum: number, maximum: number): string {
  if (typeof input !== "string") throw new Error(`${label} must be text`);
  // This API accepts Unicode text. Solidity strings can also hold arbitrary non-UTF-8 bytes.
  for (const character of input) {
    const point = character.codePointAt(0)!;
    if (point >= 0xd800 && point <= 0xdfff) throw new Error(`${label} must contain valid Unicode scalars`);
  }
  const length = toUtf8Bytes(input).length;
  if (length < minimum || length > maximum) throw new Error(`${label} must contain ${minimum}..${maximum} UTF-8 bytes`);
  return input;
}
function selected(kind: CurrentArtistOperationKind) {
  if (typeof kind !== "string" || !Object.hasOwn(schemes, kind)) throw new Error("Unknown current Artist operation kind");
  const [primaryType, declaration, operationId, method, digestMethod] = schemes[kind];
  const fields = declaration.split(",").map(field => {
    const [type, name] = field.split(" "); return { type: type!, name: name! };
  });
  return { primaryType, fields, operationId, method, digestMethod };
}

/** Exact original signed fields. This performs structural checks, not live state or signature validation. */
export function currentArtistOperationTypedData<K extends CurrentArtistOperationKind>(
  kind: K, chainId: bigint, registry: Address, message: CurrentArtistOperationMessages[NoInfer<K>],
): SigningPayload<CurrentArtistOperationMessages[K]> {
  const scheme = selected(kind);
  exact(message, scheme.fields.map(field => field.name), "Artist operation message");
  const facade = address(registry, "Registry");
  const payload = (kind === "delegatedPolicyConsent"
    ? currentArtistTypedData("artistPolicyConsent", chainId, facade, message as CurrentArtistPolicyConsent)
    : buildSigningPayload(chainId, facade, "6529StreamArtistRegistry", scheme.primaryType,
      scheme.fields, message, kind === "contentFreeze" ? { lockClasses: { minimum: 1, maximum: 16 } } : {})) as SigningPayload<CurrentArtistOperationMessages[K]>;
  const m = payload.message as unknown as Record<string, unknown>;
  for (const field of scheme.fields) {
    if (field.type === "address") address(m[field.name], field.name);
    const zeroAllowed = field.name === "revokedDigest" || (kind === "delegationGrant" && field.name === "constraintsHash")
      || (kind === "delegationRevocation" && field.name === "reasonHash");
    if (field.type === "bytes32" && !zeroAllowed) nonzeroHash(m[field.name], field.name);
  }
  if (kind !== "delegationGrant" && "collectionId" in m && (m.collectionId as bigint) === 0n) throw new Error("collectionId must be positive");
  if (kind === "bindingRefusal" && m.bindingGeneration === 0n) throw new Error("bindingGeneration must be positive");
  if (kind === "royaltyFreeze" && String(m.revenueClass).toLowerCase() !== royaltyClass) throw new Error("Royalty freeze requires ROYALTY_ERC2981");
  if (kind === "contentFreeze") {
    let prior = 0n;
    for (const item of m.lockClasses as readonly Hex[]) {
      const current = BigInt(item);
      if (current <= prior) throw new Error("lockClasses must be nonzero and strictly increasing");
      prior = current;
    }
  }
  if (kind === "authorizationRevocation") {
    const zeroDigest = String(m.revokedDigest).toLowerCase() === ZeroHash;
    if (zeroDigest === (m.revokedNonce === 0n)) throw new Error("Revocation requires exactly one digest or nonzero nonce target");
    if (String(m.revokedDigest).toLowerCase() === payload.digest || (zeroDigest && m.revokedNonce === m.nonce)) throw new Error("Authorization cannot revoke itself");
  }
  if (kind === "identityRevision" && String(m.previousRecordHash).toLowerCase() === String(m.revisedRecordHash).toLowerCase()) throw new Error("Identity revision must change the document hash");
  if (kind === "delegationGrant") {
    if (m.capabilities === 0n || ((m.capabilities as bigint) & ~1143n) !== 0n) throw new Error("Delegation capabilities must be a nonzero subset of 1143");
    if ((m.expiresAt as bigint) <= (m.notBefore as bigint)) throw new Error("Delegation expiresAt must follow notBefore");
  }
  return payload;
}

/** Copy all signed and supplemental fields before any asynchronous read or wallet interaction. */
export function normalizeCurrentArtistOperationRequest<K extends CurrentArtistOperationKind>(
  input: CurrentArtistOperationRequest<K>,
): CurrentArtistOperationRequest<K> {
  exact(input, ["kind", "chainId", "registry", "caller", "signer", "artistId", "mode", "signature", "message", "details"], "Artist operation request");
  const payload = currentArtistOperationTypedData(input.kind, input.chainId, input.registry, input.message);
  const caller = address(input.caller, "Caller"), signer = address(input.signer, "Signer"), artistId = nonzeroHash(input.artistId, "artistId");
  if (typeof input.signature !== "string" || !isHexString(input.signature, true) || input.signature.length > 2 + 4096 * 2) throw new Error("Signature must be complete hex bytes, at most 4096 bytes");
  const signature = input.signature.toLowerCase() as Hex;
  if (input.mode !== "direct" && input.mode !== "signature") throw new Error("Unknown Artist authorization mode");
  const direct = caller === signer && signature === "0x";
  if ((input.mode === "direct") !== direct) throw new Error("Authorization mode differs from the actual caller/signature predicate");
  exact(input.details, input.kind === "bindingRefusal" ? ["reasonURI"]
    : input.kind === "identityRevision" ? ["identityRecordURI", "document", "displayName"]
      : input.kind === "delegatedPolicyConsent" || input.kind === "delegatedSaleConsent" ? ["grant"] : [], "Artist operation details");
  let details: CurrentArtistOperationDetails[CurrentArtistOperationKind] = Object.freeze({});
  if (input.kind === "bindingRefusal") {
    const reasonURI = text((input.details as CurrentArtistOperationDetails["bindingRefusal"]).reasonURI, "reasonURI", 0, 2048);
    details = Object.freeze({ reasonURI });
  }
  if (input.kind === "identityRevision") {
    const original = input.details as CurrentArtistOperationDetails["identityRevision"];
    const identityRecordURI = text(original.identityRecordURI, "identityRecordURI", 0, 2048), displayName = text(original.displayName, "displayName", 1, 256);
    if (typeof original.document !== "string" || !isHexString(original.document, true) || original.document.length <= 2 || original.document.length > 2 + 8192 * 2) throw new Error("Identity document must contain 1..8192 complete hex bytes");
    const document = original.document.toLowerCase() as Hex, m = payload.message as CurrentArtistIdentityRevision;
    if (keccak256(document) !== m.revisedRecordHash.toLowerCase()) throw new Error("Identity document differs from revisedRecordHash");
    if (!direct && m.signedAt === 0n) throw new Error("Signed identity revision requires positive signedAt");
    details = Object.freeze({ identityRecordURI, document, displayName });
  }
  if (input.kind === "delegatedPolicyConsent" || input.kind === "delegatedSaleConsent") {
    details = Object.freeze({ grant: nonzeroHash((input.details as CurrentArtistOperationDetails["delegatedPolicyConsent"]).grant, "grant") });
  }
  if ("artistId" in payload.message && payload.message.artistId.toLowerCase() !== artistId) throw new Error("Signed artistId differs from the authority/replay locator");
  if (input.kind === "delegationGrant" && (payload.message as CurrentArtistDelegationGrant).delegate === signer) throw new Error("Artist cannot delegate to its own grantor address");
  return Object.freeze({ kind: input.kind, chainId: input.chainId, registry: payload.domain.verifyingContract as Address,
    caller, signer, artistId, mode: input.mode, signature, message: payload.message, details }) as CurrentArtistOperationRequest<K>;
}

/**
 * No transaction or authorization is performed; both calls target the actual signing facade.
 * A direct revision with signedAt zero retains that submitted sentinel in its payload/getter;
 * its effective execution digest requires the eventual block timestamp and is not asserted here.
 */
export function prepareCurrentArtistAction<K extends CurrentArtistOperationKind>(input: CurrentArtistOperationRequest<K>): PreparedCurrentArtistAction<K> {
  const request = normalizeCurrentArtistOperationRequest(input), scheme = selected(request.kind);
  const payload = currentArtistOperationTypedData(request.kind, request.chainId, request.registry, request.message);
  const m = payload.message as unknown as Record<string, unknown>;
  let terms: unknown[];
  switch (request.kind) {
    case "bindingRefusal": terms = [m.collectionId, m.bindingGeneration, m.bindingHash, m.reasonHash, (request.details as CurrentArtistOperationDetails["bindingRefusal"]).reasonURI]; break;
    case "saleConsent":
    case "delegatedSaleConsent": terms = [m.collectionId, m.saleAdapter, m.saleId, m.saleConfigHash]; break;
    case "royaltyFreeze": terms = [m.resolver, m.collectionId, m.revenueClass, m.expectedAssignmentHash]; break;
    case "contentFreeze": terms = [m.collectionId, m.metadataContract, m.lockClasses, m.expectedStateHash]; break;
    case "authorizationRevocation": terms = [m.artistId, m.revokedDigest, m.revokedNonce]; break;
    case "identityRevision": terms = [m.artistId, m.previousRecordHash, m.revisedRecordHash, (request.details as CurrentArtistOperationDetails["identityRevision"]).identityRecordURI]; break;
    case "delegationGrant": terms = [request.artistId, m.delegate, m.collectionId, m.capabilities, m.notBefore, m.expiresAt, m.maxUses, m.constraintsHash]; break;
    case "delegationRevocation": terms = [m.artistId, m.delegate, m.delegationRecordHash, m.reasonHash]; break;
    case "delegatedPolicyConsent": terms = [m.collectionId, m.phaseId, m.policyHash]; break;
    default: throw new Error("Unknown current Artist operation kind");
  }
  const time = request.kind === "delegationGrant" ? 0n : request.kind === "identityRevision" ? m.signedAt : m.deadline;
  const call = (method: string, signature: Hex): UnsignedCall => {
    const args: unknown[] = [terms, [m.nonce, time, signature]];
    if ((request.kind === "delegatedPolicyConsent" || request.kind === "delegatedSaleConsent") && method === scheme.method) {
      args.splice(1, 0, (request.details as CurrentArtistOperationDetails["delegatedPolicyConsent"]).grant);
    }
    if (request.kind === "identityRevision" && method === scheme.method) {
      const details = request.details as CurrentArtistOperationDetails["identityRevision"];
      args.push(details.document, details.displayName);
    }
    return Object.freeze({ to: request.registry, value: 0n, data: operations.encodeFunctionData(method, args) as Hex });
  };
  return Object.freeze({ request, payload, operationId: scheme.operationId, method: scheme.method, digestMethod: scheme.digestMethod,
    call: call(scheme.method, request.signature), digestCall: call(scheme.digestMethod, "0x") });
}

function sameTree(actual: unknown, expected: unknown): boolean {
  if (actual === expected) return true;
  if (!actual || !expected || typeof actual !== "object" || typeof expected !== "object") return false;
  if (Array.isArray(actual) !== Array.isArray(expected)) return false;
  const a = Reflect.ownKeys(actual), b = Reflect.ownKeys(expected);
  return a.length === b.length && a.every(key => b.includes(key) && sameTree(Reflect.get(actual, key), Reflect.get(expected, key)));
}
/** Reconstruct every derived field; rejects altered calldata, payload, labels or unsupported variants. */
export function normalizeCurrentArtistAction<K extends CurrentArtistOperationKind>(input: PreparedCurrentArtistAction<K>): PreparedCurrentArtistAction<K> {
  exact(input, ["request", "payload", "operationId", "method", "digestMethod", "call", "digestCall"], "Prepared Artist action");
  const rebuilt = prepareCurrentArtistAction(input.request);
  if (!sameTree(input, rebuilt)) throw new Error("Prepared Artist action differs from exact request reconstruction");
  return rebuilt;
}
