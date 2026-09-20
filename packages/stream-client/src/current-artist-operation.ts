import { Interface, ZeroAddress, ZeroHash, getAddress, id, isHexString, toUtf8Bytes } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import type { UnsignedCall } from "./binding.js";
import type { SigningPayload } from "./signing.js";
import { buildSigningPayload } from "./signing-payload.js";

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
export interface CurrentArtistOperationMessages {
  bindingRefusal: CurrentArtistBindingRefusal;
  saleConsent: CurrentArtistSaleConsent;
  royaltyFreeze: CurrentArtistRoyaltyFreeze;
  contentFreeze: CurrentArtistContentFreeze;
  authorizationRevocation: CurrentArtistAuthorizationRevocation;
}
export type CurrentArtistOperationKind = keyof CurrentArtistOperationMessages;
export interface CurrentArtistOperationDetails {
  /** Supplemental calldata: reasonURI is outside the original signed digest. */
  bindingRefusal: { readonly reasonURI: string };
  saleConsent: Readonly<Record<string, never>>;
  royaltyFreeze: Readonly<Record<string, never>>;
  contentFreeze: Readonly<Record<string, never>>;
  authorizationRevocation: Readonly<Record<string, never>>;
}
interface OperationContext {
  readonly chainId: bigint;
  /** Actual immutable Onboarding Registry facade, never an owner or coordinator. */
  readonly registry: Address;
  readonly caller: Address;
  /** Supplied authority claim; the pure codec does not establish current authority. */
  readonly signer: Address;
  /** Supplied authority/replay locator, outside the signed schema except for operation 54. */
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

const schemes = {
  bindingRefusal: ["StreamArtistBindingRefusal", "address core,uint256 collectionId,uint64 bindingGeneration,bytes32 bindingHash,bytes32 reasonHash,uint256 nonce,uint64 deadline", 3n, "refuseArtistBinding", "bindingRefusalDigest", "(uint256 collectionId,uint64 generation,bytes32 bindingHash,bytes32 reasonHash,string reasonURI)"],
  saleConsent: ["StreamArtistSaleConsent", "address core,address saleAdapter,uint256 collectionId,bytes32 saleId,bytes32 saleConfigHash,uint256 nonce,uint64 deadline", 16n, "recordSaleConsent", "saleConsentDigest", "(uint256 collectionId,address saleAdapter,bytes32 saleId,bytes32 saleConfigHash)"],
  royaltyFreeze: ["StreamArtistRoyaltyFreeze", "address core,address resolver,uint256 collectionId,bytes32 revenueClass,bytes32 expectedAssignmentHash,uint256 nonce,uint64 deadline", 20n, "authorizeArtistRoyaltyFreeze", "royaltyFreezeDigest", "(address resolver,uint256 collectionId,bytes32 revenueClass,bytes32 expectedAssignmentHash)"],
  contentFreeze: ["StreamArtistContentFreeze", "address core,address metadataContract,uint256 collectionId,bytes32[] lockClasses,bytes32 expectedStateHash,uint256 nonce,uint64 deadline", 21n, "authorizeArtistContentFreeze", "contentFreezeDigest", "(uint256 collectionId,address metadataContract,bytes32[] lockClasses,bytes32 expectedStateHash)"],
  authorizationRevocation: ["StreamArtistAuthorizationRevocation", "bytes32 artistId,bytes32 revokedDigest,uint256 revokedNonce,uint256 nonce,uint64 deadline", 54n, "revokeArtistAuthorization", "authorizationRevocationDigest", "(bytes32 artistId,bytes32 revokedDigest,uint256 revokedNonce)"],
} as const;
const authorization = "(uint256 nonce,uint64 time,bytes signature)";
/** Original principal write and getter variants for operations 3, 16, 20, 21 and 54. */
export const CURRENT_ARTIST_OPERATION_ABI: readonly string[] = Object.freeze(Object.values(schemes).flatMap(([, , , method, getter, tuple]) => [
  `function ${method}(${tuple},${authorization}) returns (bytes32)`,
  `function ${getter}(${tuple},${authorization}) view returns (bytes32)`,
]));
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
  const payload = buildSigningPayload(chainId, address(registry, "Registry"), "6529StreamArtistRegistry", scheme.primaryType,
    scheme.fields, message, kind === "contentFreeze" ? { lockClasses: { minimum: 1, maximum: 16 } } : {});
  const m = payload.message as unknown as Record<string, unknown>;
  for (const field of scheme.fields) {
    if (field.type === "address") address(m[field.name], field.name);
    if (field.type === "bytes32" && field.name !== "revokedDigest") nonzeroHash(m[field.name], field.name);
  }
  if ("collectionId" in m && (m.collectionId as bigint) === 0n) throw new Error("collectionId must be positive");
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
  exact(input.details, input.kind === "bindingRefusal" ? ["reasonURI"] : [], "Artist operation details");
  let details: CurrentArtistOperationDetails[CurrentArtistOperationKind] = Object.freeze({});
  if (input.kind === "bindingRefusal") {
    const reasonURI = (input.details as CurrentArtistOperationDetails["bindingRefusal"]).reasonURI;
    if (typeof reasonURI !== "string") throw new Error("reasonURI must be text");
    // This API accepts Unicode text. Solidity strings can also hold arbitrary non-UTF-8 bytes.
    for (const character of reasonURI) {
      const point = character.codePointAt(0)!;
      if (point >= 0xd800 && point <= 0xdfff) throw new Error("reasonURI must contain valid Unicode scalars");
    }
    if (toUtf8Bytes(reasonURI).length > 2048) throw new Error("reasonURI must be at most 2048 UTF-8 bytes");
    details = Object.freeze({ reasonURI });
  }
  if (input.kind === "authorizationRevocation" && (payload.message as CurrentArtistAuthorizationRevocation).artistId.toLowerCase() !== artistId) throw new Error("Revocation artistId differs from the authority/replay locator");
  return Object.freeze({ kind: input.kind, chainId: input.chainId, registry: payload.domain.verifyingContract as Address,
    caller, signer, artistId, mode: input.mode, signature, message: payload.message, details }) as CurrentArtistOperationRequest<K>;
}

/** No transaction or authorization is performed; both calls target the actual signing facade. */
export function prepareCurrentArtistAction<K extends CurrentArtistOperationKind>(input: CurrentArtistOperationRequest<K>): PreparedCurrentArtistAction<K> {
  const request = normalizeCurrentArtistOperationRequest(input), scheme = selected(request.kind);
  const payload = currentArtistOperationTypedData(request.kind, request.chainId, request.registry, request.message);
  const m = payload.message as unknown as Record<string, unknown>;
  let terms: unknown[];
  switch (request.kind) {
    case "bindingRefusal": terms = [m.collectionId, m.bindingGeneration, m.bindingHash, m.reasonHash, (request.details as CurrentArtistOperationDetails["bindingRefusal"]).reasonURI]; break;
    case "saleConsent": terms = [m.collectionId, m.saleAdapter, m.saleId, m.saleConfigHash]; break;
    case "royaltyFreeze": terms = [m.resolver, m.collectionId, m.revenueClass, m.expectedAssignmentHash]; break;
    case "contentFreeze": terms = [m.collectionId, m.metadataContract, m.lockClasses, m.expectedStateHash]; break;
    case "authorizationRevocation": terms = [m.artistId, m.revokedDigest, m.revokedNonce]; break;
    default: throw new Error("Unknown current Artist operation kind");
  }
  const call = (method: string, signature: Hex): UnsignedCall => Object.freeze({ to: request.registry, value: 0n,
    data: operations.encodeFunctionData(method, [terms, [m.nonce, m.deadline, signature]]) as Hex });
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
