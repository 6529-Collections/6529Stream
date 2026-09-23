import { AbiCoder, Interface, ZeroAddress, ZeroHash, getAddress, id, isHexString, keccak256, toUtf8Bytes } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import type { UnsignedCall } from "./binding.js";
import type { SigningPayload } from "./signing.js";
import { buildSigningPayload } from "./signing-payload.js";
import { currentArtistTypedData, type CurrentArtistPolicyConsent, type CurrentArtistEconomicsConsent, type CurrentArtistAttestation } from "./current-artist.js";

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
export type CurrentArtistDelegatedEconomicsConsent = CurrentArtistEconomicsConsent;
export type CurrentArtistDelegatedRoyaltyFreeze = CurrentArtistRoyaltyFreeze;
export type CurrentArtistDelegatedAttestation = CurrentArtistAttestation;
/** Original unsigned subject locator. It never extends the Attestation signed schema. */
export interface CurrentArtistAttestationSubject {
  readonly scopeType: bigint; readonly tokenId: bigint; readonly scopeId: Hex; readonly resolver: Address;
}
/** Original fixed candidate. Its actual resolver preview must match the signed assignmentHash. */
export interface CurrentArtistFixedEconomicsCandidate {
  readonly profileHash: Hex; readonly policyHash: Hex; readonly royaltyBps: bigint; readonly frozen: boolean;
}
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
  delegatedEconomicsConsent: CurrentArtistDelegatedEconomicsConsent;
  delegatedProspectiveEconomicsConsent: CurrentArtistDelegatedEconomicsConsent;
  delegatedRoyaltyFreeze: CurrentArtistDelegatedRoyaltyFreeze;
  delegatedAttestation: CurrentArtistDelegatedAttestation;
  delegatedScopedAttestation: CurrentArtistDelegatedAttestation;
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
  /** Collection and grant are supplemental original calldata, outside the economics signature. */
  delegatedEconomicsConsent: { readonly collectionId: bigint; readonly grant: Hex };
  delegatedProspectiveEconomicsConsent: { readonly collectionId: bigint; readonly grant: Hex; readonly candidate: CurrentArtistFixedEconomicsCandidate };
  delegatedRoyaltyFreeze: { readonly grant: Hex };
  /** Raw statement and URI must match their original signed hashes. */
  delegatedAttestation: { readonly grant: Hex; readonly statementURI: string; readonly statement: Hex };
  delegatedScopedAttestation: { readonly grant: Hex; readonly statementURI: string; readonly statement: Hex; readonly subject: CurrentArtistAttestationSubject };
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
const economicsSigning = ["StreamArtistEconomicsConsent", "address core,address resolver,bytes32 revenueClass,uint8 scope,uint256 scopeId,bytes32 assignmentHash,uint256 nonce,uint64 deadline"] as const;
const economicsTerms = "(uint256 collectionId,address resolver,bytes32 revenueClass,uint8 scope,uint256 scopeId,bytes32 assignmentHash)";
const royaltySigning = ["StreamArtistRoyaltyFreeze", "address core,address resolver,uint256 collectionId,bytes32 revenueClass,bytes32 expectedAssignmentHash,uint256 nonce,uint64 deadline"] as const;
const royaltyTerms = "(address resolver,uint256 collectionId,bytes32 revenueClass,bytes32 expectedAssignmentHash)";
const candidateTuple = "(bytes32 profileHash,bytes32 policyHash,uint16 royaltyBps,bool frozen)";
const attestationSigning = ["StreamArtistAttestation", "address core,uint256 collectionId,uint8 subjectKind,bytes32 subjectId,bytes32 subjectStateHash,bytes32 schemaId,bytes32 statementHash,bytes32 statementURIHash,uint256 nonce,uint64 signedAt"] as const;
const attestationTerms = "(uint256 collectionId,uint8 subjectKind,bytes32 subjectId,bytes32 subjectStateHash,bytes32 schemaId,bytes32 statementHash,string statementURI)";
export const CURRENT_ARTIST_ATTESTATION_SUBJECT_TUPLE = "(uint8 scopeType,uint256 tokenId,bytes32 scopeId,address resolver)" as const;
/** Canonical abi.encode(uint16(1), Publication) is the original 416-byte statement for kinds 7/8. */
export const CURRENT_ARTIST_ATTESTATION_PUBLICATION_TUPLE = "(address metadataHost,address recorder,uint256 collectionId,bytes32 subjectId,bytes32 recordType,bytes32 schemaId,bytes32 canonicalizationId,uint16 payloadAlgorithm,bytes32 payloadHash,bytes32 uriHash,uint64 effectiveAt,bytes32 candidateRecordHash)" as const;
const schemes = {
  bindingRefusal: ["StreamArtistBindingRefusal", "address core,uint256 collectionId,uint64 bindingGeneration,bytes32 bindingHash,bytes32 reasonHash,uint256 nonce,uint64 deadline", 3n, "refuseArtistBinding", "bindingRefusalDigest", "(uint256 collectionId,uint64 generation,bytes32 bindingHash,bytes32 reasonHash,string reasonURI)"],
  saleConsent: [...saleSigning, 16n, "recordSaleConsent", "saleConsentDigest", saleTerms],
  royaltyFreeze: [...royaltySigning, 20n, "authorizeArtistRoyaltyFreeze", "royaltyFreezeDigest", royaltyTerms],
  contentFreeze: ["StreamArtistContentFreeze", "address core,address metadataContract,uint256 collectionId,bytes32[] lockClasses,bytes32 expectedStateHash,uint256 nonce,uint64 deadline", 21n, "authorizeArtistContentFreeze", "contentFreezeDigest", "(uint256 collectionId,address metadataContract,bytes32[] lockClasses,bytes32 expectedStateHash)"],
  authorizationRevocation: ["StreamArtistAuthorizationRevocation", "bytes32 artistId,bytes32 revokedDigest,uint256 revokedNonce,uint256 nonce,uint64 deadline", 54n, "revokeArtistAuthorization", "authorizationRevocationDigest", "(bytes32 artistId,bytes32 revokedDigest,uint256 revokedNonce)"],
  identityRevision: ["StreamArtistIdentityRevision", "bytes32 artistId,bytes32 previousRecordHash,bytes32 revisedRecordHash,uint256 nonce,uint64 signedAt", 25n, "recordIdentityRevision", "identityRevisionDigest", "(bytes32 artistId,bytes32 previousRecordHash,bytes32 revisedRecordHash,string identityRecordURI)"],
  delegationGrant: ["StreamArtistDelegation", "address core,address delegate,uint256 collectionId,uint32 capabilities,uint64 notBefore,uint64 expiresAt,uint64 maxUses,bytes32 constraintsHash,uint256 nonce", 26n, "grantArtistDelegation", "delegationGrantDigest", "(bytes32 artistId,address delegate,uint256 collectionId,uint32 capabilities,uint64 notBefore,uint64 expiresAt,uint64 maxUses,bytes32 constraintsHash)"],
  delegationRevocation: ["StreamArtistDelegationRevocation", "bytes32 artistId,address delegate,bytes32 delegationRecordHash,bytes32 reasonHash,uint256 nonce,uint64 deadline", 27n, "revokeArtistDelegation", "delegationRevocationDigest", "(bytes32 artistId,address delegate,bytes32 delegationRecordHash,bytes32 reasonHash)"],
  delegatedPolicyConsent: ["StreamArtistPolicyConsent", "address core,address mintManager,uint256 collectionId,bytes32 phaseId,bytes32 policyHash,uint256 nonce,uint64 deadline", 14n, "recordDelegatedPolicyConsent", "policyConsentDigest", "(uint256 collectionId,bytes32 phaseId,bytes32 policyHash)"],
  delegatedSaleConsent: [...saleSigning, 16n, "recordDelegatedSaleConsent", "saleConsentDigest", saleTerms],
  delegatedEconomicsConsent: [...economicsSigning, 15n, "recordDelegatedEconomicsConsent", "economicsConsentDigest", economicsTerms],
  delegatedProspectiveEconomicsConsent: [...economicsSigning, 15n, "recordDelegatedProspectiveEconomicsConsent", "economicsConsentDigest", economicsTerms],
  delegatedRoyaltyFreeze: [...royaltySigning, 20n, "authorizeDelegatedRoyaltyFreeze", "royaltyFreezeDigest", royaltyTerms],
  delegatedAttestation: [...attestationSigning, 24n, "recordDelegatedArtistAttestation", "attestationDigest", attestationTerms],
  delegatedScopedAttestation: [...attestationSigning, 24n, "recordDelegatedArtistScopedAttestation", "attestationDigest", attestationTerms],
} as const;
const authorization = "(uint256 nonce,uint64 time,bytes signature)";
const delegatedMethods = new Set<string>(["recordDelegatedPolicyConsent", "recordDelegatedSaleConsent", "recordDelegatedEconomicsConsent", "recordDelegatedProspectiveEconomicsConsent", "authorizeDelegatedRoyaltyFreeze", "recordDelegatedArtistAttestation", "recordDelegatedArtistScopedAttestation"]);
const attestationMethods = new Set<string>(["recordDelegatedArtistAttestation", "recordDelegatedArtistScopedAttestation"]);
/** Original Artist write/getter variants, with each supported delegated transport kept explicit. */
export const CURRENT_ARTIST_OPERATION_ABI: readonly string[] = Object.freeze([...new Set(Object.values(schemes).flatMap(([, , , method, getter, tuple]) => [
  `function ${method}(${tuple},${method === "recordDelegatedProspectiveEconomicsConsent" ? `${candidateTuple},` : method === "recordDelegatedArtistScopedAttestation" ? `${CURRENT_ARTIST_ATTESTATION_SUBJECT_TUPLE},` : ""}${delegatedMethods.has(method) ? "bytes32 grant," : ""}${authorization}${method === "recordIdentityRevision" ? ",bytes document,string displayName" : attestationMethods.has(method) ? ",bytes statement" : ""}) returns (bytes32)`,
  `function ${getter}(${tuple},${authorization}) view returns (bytes32)`,
]))]);
const operations = new Interface(CURRENT_ARTIST_OPERATION_ABI);
const coder = AbiCoder.defaultAbiCoder();
const royaltyClass = id("ROYALTY_ERC2981");
const publicationSchema = id("6529STREAM_ARTIST_RECORD_PUBLICATION_V1");
const deploymentSchema = id("6529STREAM_ARTIST_DEPLOYMENT_ATTESTATION_V1");
const personhoodSchemas = [id("6529STREAM_ARTIST_PERSONHOOD_WAIVER_V1"), id("6529STREAM_ARTIST_PERSONHOOD_EVIDENCE_V1")];
function isAttestation(kind: CurrentArtistOperationKind): boolean {
  return kind === "delegatedAttestation" || kind === "delegatedScopedAttestation";
}

function exact(input: unknown, keys: readonly string[], label: string): asserts input is Record<string, unknown> {
  if (!input || typeof input !== "object" || Array.isArray(input)) throw new Error(`${label} must be an object`);
  const own = Reflect.ownKeys(input);
  if (own.length !== keys.length || own.some(key => typeof key !== "string" || !keys.includes(key))) throw new Error(`${label} has unexpected fields`);
}
function address(input: unknown, label: string, allowZero = false): Address {
  if (typeof input !== "string") throw new Error(`${label} must be an address`);
  const result = getAddress(input) as Address;
  if (result === ZeroAddress && !allowZero) throw new Error(`${label} must be nonzero`);
  return result;
}
function nonzeroHash(input: unknown, label: string): Hex {
  if (typeof input !== "string" || !isHexString(input, 32) || input.toLowerCase() === ZeroHash) throw new Error(`${label} must be nonzero bytes32`);
  return input.toLowerCase() as Hex;
}
function uint(input: unknown, bits: number, label: string): bigint {
  if (typeof input !== "bigint" || input < 0n || input >= 1n << BigInt(bits)) throw new Error(`${label} must be uint${bits} bigint`);
  return input;
}
function bytes32(input: unknown, label: string): Hex {
  if (typeof input !== "string" || !isHexString(input, 32)) throw new Error(`${label} must be bytes32`);
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
    : kind === "delegatedEconomicsConsent" || kind === "delegatedProspectiveEconomicsConsent"
      ? currentArtistTypedData("artistEconomicsConsent", chainId, facade, message as CurrentArtistEconomicsConsent)
    : isAttestation(kind)
      ? currentArtistTypedData("artistAttestation", chainId, facade, message as CurrentArtistAttestation)
    : buildSigningPayload(chainId, facade, "6529StreamArtistRegistry", scheme.primaryType,
      scheme.fields, message, kind === "contentFreeze" ? { lockClasses: { minimum: 1, maximum: 16 } } : {})) as SigningPayload<CurrentArtistOperationMessages[K]>;
  const m = payload.message as unknown as Record<string, unknown>;
  for (const field of scheme.fields) {
    if (field.type === "address") address(m[field.name], field.name);
    const zeroAllowed = field.name === "revokedDigest" || (kind === "delegationGrant" && field.name === "constraintsHash")
      || (kind === "delegationRevocation" && field.name === "reasonHash")
      || (kind === "delegatedProspectiveEconomicsConsent" && field.name === "assignmentHash")
      || (isAttestation(kind) && m.subjectKind === 8n && field.name === "subjectStateHash");
    if (field.type === "bytes32" && !zeroAllowed) nonzeroHash(m[field.name], field.name);
  }
  if (kind !== "delegationGrant" && "collectionId" in m && (m.collectionId as bigint) === 0n) throw new Error("collectionId must be positive");
  if (kind === "bindingRefusal" && m.bindingGeneration === 0n) throw new Error("bindingGeneration must be positive");
  if ((kind === "royaltyFreeze" || kind === "delegatedRoyaltyFreeze") && String(m.revenueClass).toLowerCase() !== royaltyClass) throw new Error("Royalty freeze requires ROYALTY_ERC2981");
  if (kind === "delegatedEconomicsConsent" || kind === "delegatedProspectiveEconomicsConsent") {
    if ((m.scope as bigint) > 2n || (m.scope === 0n ? m.scopeId !== 0n : m.scopeId === 0n)) throw new Error("Invalid economics scope coordinates");
    if (kind === "delegatedProspectiveEconomicsConsent" && m.scope === 0n) throw new Error("Prospective fixed economics requires collection or token scope");
  }
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
  if (isAttestation(kind)) {
    if (m.subjectKind === 0n || (m.subjectKind as bigint) > 10n) throw new Error("Unsupported original attestation subject kind");
    if (kind === "delegatedScopedAttestation" && m.subjectKind !== 4n && m.subjectKind !== 6n) throw new Error("Scoped attestation requires finality or economics subject");
    if ((m.subjectKind === 7n || m.subjectKind === 8n) && m.schemaId !== publicationSchema) throw new Error("Publication attestation requires the original envelope schema");
    if (m.subjectKind === 8n && m.subjectStateHash !== ZeroHash) throw new Error("Kind 8 publication requires zero subjectStateHash");
    if (m.subjectKind === 9n && (m.schemaId !== deploymentSchema || BigInt(m.subjectId as Hex) !== BigInt(m.core as Address))) throw new Error("Invalid deployment attestation subject");
    if (m.subjectKind === 10n && !personhoodSchemas.includes(m.schemaId as Hex)) throw new Error("Only original personhood schemas are supported; C2PA credentials are deferred");
    if ((m.subjectKind === 2n || m.subjectKind === 3n || (m.subjectKind === 4n && kind === "delegatedAttestation"))
      && BigInt(m.subjectId as Hex) !== m.collectionId) throw new Error("Attestation subjectId must equal the collection coordinate");
    if (m.subjectKind === 6n && kind === "delegatedAttestation" && BigInt(m.subjectId as Hex) >= 1n << 160n) throw new Error("Unscoped economics subjectId must be a padded resolver address");
  }
  return payload;
}

function attestationSubject(input: CurrentArtistAttestationSubject, message: CurrentArtistAttestation): CurrentArtistAttestationSubject {
  exact(input, ["scopeType", "tokenId", "scopeId", "resolver"], "Attestation subject");
  const subject = Object.freeze({ scopeType: uint(input.scopeType, 8, "scopeType"), tokenId: uint(input.tokenId, 256, "tokenId"),
    scopeId: bytes32(input.scopeId, "scopeId"), resolver: address(input.resolver, "subject resolver", message.subjectKind === 4n) });
  if (message.subjectKind === 4n) {
    if (subject.resolver !== ZeroAddress || subject.scopeType > 4n
      || (subject.scopeType === 0n && (subject.tokenId !== 0n || subject.scopeId !== ZeroHash))
      || (subject.scopeType === 1n && (subject.tokenId === 0n || subject.scopeId !== ZeroHash))
      || (subject.scopeType >= 2n && (subject.tokenId !== 0n || subject.scopeId === ZeroHash))) throw new Error("Invalid finality subject coordinates");
    const subjectId = keccak256(coder.encode(["bytes32", "(uint8,uint256,uint256,bytes32)"],
      [id("6529STREAM_ARTIST_FINALITY_ATTESTATION_SUBJECT_V1"), [subject.scopeType, message.collectionId, subject.tokenId, subject.scopeId]]));
    if (subjectId !== message.subjectId) throw new Error("Scoped finality subjectId differs from original scope hash");
  } else if (subject.scopeType > 2n || subject.tokenId !== 0n
    || (subject.scopeType === 0n && subject.scopeId !== ZeroHash)
    || (subject.scopeType === 1n && BigInt(subject.scopeId) !== message.collectionId)
    || (subject.scopeType === 2n && subject.scopeId === ZeroHash)) throw new Error("Invalid economics subject coordinates");
  // Economics IDs also bind the selected resolver's live revenue class, established by the original subject read.
  return subject;
}

function publicationStatement(message: CurrentArtistAttestation, statement: Hex, signer: Address): void {
  if ((statement.length - 2) / 2 !== 416) throw new Error("Publication statement must be the original 416-byte envelope");
  const types = ["uint16", CURRENT_ARTIST_ATTESTATION_PUBLICATION_TUPLE];
  const [version, p] = coder.decode(types, statement);
  if (version !== 1n || coder.encode(types, [version, p]) !== statement) throw new Error("Noncanonical publication statement");
  if (p.metadataHost === ZeroAddress || p.recorder !== signer || p.collectionId !== message.collectionId || p.subjectId !== message.subjectId
    || p.schemaId === ZeroHash || p.canonicalizationId === ZeroHash || p.payloadAlgorithm !== 1n || p.payloadHash === ZeroHash
    || p.candidateRecordHash === ZeroHash || p.uriHash !== message.statementURIHash) throw new Error("Publication fields differ from the original attestation");
  const intent = (p.recordType === id("ARTIST_INTENT") && p.schemaId === id("STREAM_ARTIST_INTENT_V1"))
    || (p.recordType === id("ARTIST_INTENT_WAIVER") && p.schemaId === id("STREAM_ARTIST_INTENT_WAIVER_V1"));
  const statementFamily = (p.recordType === id("ARTIST_SEMANTIC_ASSERTION") && p.schemaId === id("STREAM_SEMANTIC_ASSERTION_V1"))
    || (p.recordType === id("WORK_DESCRIPTION") && p.schemaId === id("STREAM_WORK_DESCRIPTION_V1"))
    || (p.recordType === id("ARTIST_STATEMENT") && p.schemaId !== id("STREAM_ARTIST_INTENT_V1") && p.schemaId !== id("STREAM_ARTIST_INTENT_WAIVER_V1"));
  if (intent ? message.subjectKind !== 7n || message.subjectStateHash !== p.candidateRecordHash
    : !statementFamily || message.subjectKind !== 8n || message.subjectStateHash !== ZeroHash) throw new Error("Unsupported publication family or subject state");
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
      : input.kind === "delegatedAttestation" ? ["grant", "statementURI", "statement"]
        : input.kind === "delegatedScopedAttestation" ? ["grant", "statementURI", "statement", "subject"]
      : input.kind === "delegatedEconomicsConsent" ? ["collectionId", "grant"]
        : input.kind === "delegatedProspectiveEconomicsConsent" ? ["collectionId", "grant", "candidate"]
          : input.kind === "delegatedPolicyConsent" || input.kind === "delegatedSaleConsent" || input.kind === "delegatedRoyaltyFreeze" ? ["grant"] : [], "Artist operation details");
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
  if (input.kind === "delegatedPolicyConsent" || input.kind === "delegatedSaleConsent" || input.kind === "delegatedRoyaltyFreeze") {
    details = Object.freeze({ grant: nonzeroHash((input.details as CurrentArtistOperationDetails["delegatedPolicyConsent"]).grant, "grant") });
  }
  if (input.kind === "delegatedEconomicsConsent" || input.kind === "delegatedProspectiveEconomicsConsent") {
    const original = input.details as CurrentArtistOperationDetails["delegatedProspectiveEconomicsConsent"];
    const collectionId = uint(original.collectionId, 256, "collectionId"), grant = nonzeroHash(original.grant, "grant");
    const m = payload.message as CurrentArtistEconomicsConsent;
    if (collectionId === 0n || (m.scope === 1n && m.scopeId !== collectionId)) throw new Error("Economics collection context differs from its scope");
    if (input.kind === "delegatedEconomicsConsent") details = Object.freeze({ collectionId, grant });
    else {
      exact(original.candidate, ["profileHash", "policyHash", "royaltyBps", "frozen"], "Fixed economics candidate");
      const candidate = Object.freeze({ profileHash: bytes32(original.candidate.profileHash, "profileHash"), policyHash: bytes32(original.candidate.policyHash, "policyHash"),
        royaltyBps: uint(original.candidate.royaltyBps, 16, "royaltyBps"), frozen: original.candidate.frozen });
      if (typeof candidate.frozen !== "boolean" || candidate.policyHash !== ZeroHash || candidate.royaltyBps > 1000n
        || (candidate.royaltyBps !== 0n && candidate.profileHash === ZeroHash)) throw new Error("Unsupported fixed economics candidate");
      if (m.assignmentHash === ZeroHash && (candidate.profileHash !== ZeroHash || candidate.royaltyBps !== 0n || candidate.frozen)) throw new Error("Prospective clear requires the original zero candidate");
      // Resolver selection, primary/royalty-specific terms, profile payout and the exact assignment
      // preimage are established by the original live preview, not a guessed local resolver role.
      details = Object.freeze({ collectionId, grant, candidate });
    }
  }
  if (isAttestation(input.kind)) {
    const original = input.details as CurrentArtistOperationDetails["delegatedScopedAttestation"];
    const m = payload.message as CurrentArtistAttestation;
    const grant = nonzeroHash(original.grant, "grant"), statementURI = text(original.statementURI, "statementURI", 0, 2048);
    if (typeof original.statement !== "string" || !isHexString(original.statement, true)
      || original.statement.length < 4 || original.statement.length > 2 + 8192 * 2) throw new Error("Statement must contain 1..8192 bytes");
    const statement = original.statement.toLowerCase() as Hex;
    if (keccak256(statement) !== m.statementHash || keccak256(toUtf8Bytes(statementURI)) !== m.statementURIHash) throw new Error("Statement or URI differs from its original signed hash");
    if (!direct && m.signedAt === 0n) throw new Error("Signed attestation requires positive signedAt");
    if (m.subjectKind === 10n && m.subjectId !== artistId) throw new Error("Personhood subject differs from the Artist locator");
    if (m.subjectKind === 7n || m.subjectKind === 8n) publicationStatement(m, statement, signer);
    details = input.kind === "delegatedScopedAttestation"
      ? Object.freeze({ grant, statementURI, statement, subject: attestationSubject(original.subject, m) })
      : Object.freeze({ grant, statementURI, statement });
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
    case "royaltyFreeze":
    case "delegatedRoyaltyFreeze": terms = [m.resolver, m.collectionId, m.revenueClass, m.expectedAssignmentHash]; break;
    case "contentFreeze": terms = [m.collectionId, m.metadataContract, m.lockClasses, m.expectedStateHash]; break;
    case "authorizationRevocation": terms = [m.artistId, m.revokedDigest, m.revokedNonce]; break;
    case "identityRevision": terms = [m.artistId, m.previousRecordHash, m.revisedRecordHash, (request.details as CurrentArtistOperationDetails["identityRevision"]).identityRecordURI]; break;
    case "delegationGrant": terms = [request.artistId, m.delegate, m.collectionId, m.capabilities, m.notBefore, m.expiresAt, m.maxUses, m.constraintsHash]; break;
    case "delegationRevocation": terms = [m.artistId, m.delegate, m.delegationRecordHash, m.reasonHash]; break;
    case "delegatedPolicyConsent": terms = [m.collectionId, m.phaseId, m.policyHash]; break;
    case "delegatedEconomicsConsent":
    case "delegatedProspectiveEconomicsConsent": terms = [(request.details as CurrentArtistOperationDetails["delegatedEconomicsConsent"]).collectionId, m.resolver, m.revenueClass, m.scope, m.scopeId, m.assignmentHash]; break;
    case "delegatedAttestation":
    case "delegatedScopedAttestation": terms = [m.collectionId, m.subjectKind, m.subjectId, m.subjectStateHash, m.schemaId, m.statementHash,
      (request.details as CurrentArtistOperationDetails["delegatedAttestation"]).statementURI]; break;
    default: throw new Error("Unknown current Artist operation kind");
  }
  const time = request.kind === "delegationGrant" ? 0n : request.kind === "identityRevision" || isAttestation(request.kind) ? m.signedAt : m.deadline;
  const call = (method: string, signature: Hex): UnsignedCall => {
    const args: unknown[] = [terms, [m.nonce, time, signature]];
    if (delegatedMethods.has(method) && method === scheme.method) {
      args.splice(1, 0, (request.details as CurrentArtistOperationDetails["delegatedPolicyConsent"]).grant);
    }
    if (request.kind === "delegatedProspectiveEconomicsConsent" && method === scheme.method) {
      args.splice(1, 0, (request.details as CurrentArtistOperationDetails["delegatedProspectiveEconomicsConsent"]).candidate);
    }
    if (request.kind === "delegatedScopedAttestation" && method === scheme.method) {
      args.splice(1, 0, (request.details as CurrentArtistOperationDetails["delegatedScopedAttestation"]).subject);
    }
    if (isAttestation(request.kind) && method === scheme.method) {
      args.push((request.details as CurrentArtistOperationDetails["delegatedAttestation"]).statement);
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
