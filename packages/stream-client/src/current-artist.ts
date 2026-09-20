import { Interface, isHexString, keccak256, toUtf8Bytes, type Provider, type BlockTag } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import type { UnsignedCall } from "./binding.js";
import type { SigningPayload } from "./signing.js";
import { buildSigningPayload } from "./signing-payload.js";

interface DeadlineAuthorization { readonly nonce: bigint; readonly deadline: bigint }
interface DatedAuthorization { readonly nonce: bigint; readonly signedAt: bigint }
export interface CurrentArtistAcceptance extends DeadlineAuthorization {
  readonly core: Address; readonly collectionId: bigint; readonly bindingGeneration: bigint;
  readonly bindingHash: Hex; readonly identityRecordHash: Hex;
}
export interface CurrentArtistPolicyConsent extends DeadlineAuthorization {
  readonly core: Address; readonly mintManager: Address; readonly collectionId: bigint;
  readonly phaseId: Hex; readonly policyHash: Hex;
}
export interface CurrentArtistEconomicsConsent extends DeadlineAuthorization {
  readonly core: Address; readonly resolver: Address; readonly revenueClass: Hex;
  readonly scope: bigint; readonly scopeId: bigint; readonly assignmentHash: Hex;
}
export interface CurrentArtistPayoutDesignation extends DatedAuthorization {
  readonly artistId: Hex; readonly payoutAccount: Address; readonly previousDesignationRecordHash: Hex;
}
export interface CurrentArtistAttestation extends DatedAuthorization {
  readonly core: Address; readonly collectionId: bigint; readonly subjectKind: bigint;
  readonly subjectId: Hex; readonly subjectStateHash: Hex; readonly schemaId: Hex;
  readonly statementHash: Hex; readonly statementURIHash: Hex;
}
export interface CurrentArtistContentRatification extends DeadlineAuthorization {
  readonly core: Address; readonly metadataContract: Address; readonly collectionId: bigint; readonly contentStateHash: Hex;
}
export interface CurrentCollaboratorIdentityAcceptance extends DeadlineAuthorization {
  readonly account: Address; readonly identityRecordHash: Hex;
}
export interface CurrentCollaboratorAcceptance extends DeadlineAuthorization {
  readonly core: Address; readonly collectionId: bigint; readonly bindingGeneration: bigint;
  readonly bindingHash: Hex; readonly collaborator: Address; readonly role: Hex; readonly shareLabelId: Hex;
}
export interface CurrentArtistSigningMessages {
  artistAcceptance: CurrentArtistAcceptance;
  artistPolicyConsent: CurrentArtistPolicyConsent;
  artistEconomicsConsent: CurrentArtistEconomicsConsent;
  artistPayoutDesignation: CurrentArtistPayoutDesignation;
  artistAttestation: CurrentArtistAttestation;
  artistContentRatification: CurrentArtistContentRatification;
  collaboratorIdentityAcceptance: CurrentCollaboratorIdentityAcceptance;
  collaboratorAcceptance: CurrentCollaboratorAcceptance;
}
export type CurrentArtistSigningKind = keyof CurrentArtistSigningMessages;

const schemes = {
  artistAcceptance: ["StreamArtistAcceptance", "address core,uint256 collectionId,uint64 bindingGeneration,bytes32 bindingHash,bytes32 identityRecordHash,uint256 nonce,uint64 deadline"],
  artistPolicyConsent: ["StreamArtistPolicyConsent", "address core,address mintManager,uint256 collectionId,bytes32 phaseId,bytes32 policyHash,uint256 nonce,uint64 deadline"],
  artistEconomicsConsent: ["StreamArtistEconomicsConsent", "address core,address resolver,bytes32 revenueClass,uint8 scope,uint256 scopeId,bytes32 assignmentHash,uint256 nonce,uint64 deadline"],
  artistPayoutDesignation: ["StreamArtistPayoutDesignation", "bytes32 artistId,address payoutAccount,bytes32 previousDesignationRecordHash,uint256 nonce,uint64 signedAt"],
  artistAttestation: ["StreamArtistAttestation", "address core,uint256 collectionId,uint8 subjectKind,bytes32 subjectId,bytes32 subjectStateHash,bytes32 schemaId,bytes32 statementHash,bytes32 statementURIHash,uint256 nonce,uint64 signedAt"],
  artistContentRatification: ["StreamArtistContentRatification", "address core,address metadataContract,uint256 collectionId,bytes32 contentStateHash,uint256 nonce,uint64 deadline"],
  collaboratorIdentityAcceptance: ["StreamCollaboratorIdentityAcceptance", "address account,bytes32 identityRecordHash,uint256 nonce,uint64 deadline"],
  collaboratorAcceptance: ["StreamCollaboratorAcceptance", "address core,uint256 collectionId,uint64 bindingGeneration,bytes32 bindingHash,address collaborator,bytes32 role,bytes32 shareLabelId,uint256 nonce,uint64 deadline"],
} as const;

function scheme(kind: CurrentArtistSigningKind) {
  if (typeof kind !== "string" || !Object.hasOwn(schemes, kind)) throw new Error("Unknown current Artist signing kind");
  const [primaryType, declaration] = schemes[kind];
  return { primaryType, fields: declaration.split(",").map(field => {
    const [type, name] = field.split(" "); return { type: type!, name: name! };
  }) };
}

/** The verifying contract is the current onboarding facade, never an owner/coordinator or RC1 registry. */
export function currentArtistTypedData<K extends CurrentArtistSigningKind>(kind: K, chainId: bigint, registry: Address, message: CurrentArtistSigningMessages[K]): SigningPayload<CurrentArtistSigningMessages[K]> {
  const selected = scheme(kind);
  return buildSigningPayload(chainId, registry, "6529StreamArtistRegistry", selected.primaryType, selected.fields, message);
}

/** Explicit current Artist JSON; integer fields must be canonical decimal strings. */
export function currentArtistTypedDataFromJSON(input: unknown): SigningPayload<CurrentArtistSigningMessages[CurrentArtistSigningKind]> {
  if (!input || typeof input !== "object" || Array.isArray(input)) throw new Error("Expected current Artist signing request");
  const request = input as Record<string, unknown>;
  if (Object.keys(request).sort().join(",") !== "chainId,kind,message,verifyingContract") throw new Error("Expected kind, chainId, verifyingContract and message only");
  const kind = request.kind as CurrentArtistSigningKind, selected = scheme(kind);
  if (typeof request.chainId !== "string" || !/^[1-9][0-9]*$/.test(request.chainId)) throw new Error("chainId must be a positive decimal string");
  if (!request.message || typeof request.message !== "object" || Array.isArray(request.message)) throw new Error("message must be an object");
  const message = { ...request.message } as Record<string, unknown>;
  for (const field of selected.fields) if (field.type.startsWith("uint")) {
    const value = message[field.name];
    if (typeof value !== "string" || !/^(0|[1-9][0-9]*)$/.test(value)) throw new Error(field.name + " must be a decimal string");
    message[field.name] = BigInt(value);
  }
  return currentArtistTypedData(kind, BigInt(request.chainId), request.verifyingContract as Address,
    message as unknown as CurrentArtistSigningMessages[CurrentArtistSigningKind]);
}

interface SignatureSubmission { readonly signature: Hex }
export interface CurrentArtistSubmissions {
  artistAcceptance: SignatureSubmission;
  artistPolicyConsent: SignatureSubmission;
  /** collectionId is a separately admitted context; the permanent economics signature does not contain it. */
  artistEconomicsConsent: SignatureSubmission & { readonly collectionId: bigint };
  artistPayoutDesignation: SignatureSubmission;
  artistAttestation: SignatureSubmission & { readonly statementURI: string; readonly statement: Hex };
  artistContentRatification: SignatureSubmission;
  collaboratorIdentityAcceptance: SignatureSubmission & { readonly document: Hex; readonly displayName: string };
  collaboratorAcceptance: SignatureSubmission;
}
export interface PreparedCurrentArtistOperation<T extends object> {
  readonly payload: SigningPayload<T>;
  readonly call: UnsignedCall;
  readonly digestCall: UnsignedCall;
  readonly method: string;
  readonly digestMethod: string;
}

const authorization = "(uint256 nonce,uint64 time,bytes signature)";
const economics = "(uint256 collectionId,address resolver,bytes32 revenueClass,uint8 scope,uint256 scopeId,bytes32 assignmentHash)";
const payout = "(bytes32 artistId,address payoutAccount,bytes32 previousDesignationRecordHash)";
const attestation = "(uint256 collectionId,uint8 subjectKind,bytes32 subjectId,bytes32 subjectStateHash,bytes32 schemaId,bytes32 statementHash,string statementURI)";
const ratification = "(uint256 collectionId,address metadataContract,bytes32 contentStateHash)";
const policy = "(uint256 collectionId,bytes32 phaseId,bytes32 policyHash)";
const collaborator = "(uint256 collectionId,uint64 generation,bytes32 bindingHash,address account,bytes32 role,bytes32 shareLabelId)";
const operations = new Interface([
  "function contentConsentDigest((uint256 collectionId,address metadataContract,bytes32 familyId,bytes32 newStateHash),(uint256 nonce,uint64 time,bytes signature)) view returns (bytes32)",
  "function acceptArtistBinding(uint256," + authorization + ") returns (bytes32)",
  "function acceptanceDigest(uint256," + authorization + ") view returns (bytes32)",
  ...[["recordPolicyConsent", "policyConsentDigest", policy], ["recordEconomicsConsent", "economicsConsentDigest", economics],
    ["recordPayoutDesignation", "payoutDesignationDigest", payout], ["recordContentRatification", "contentRatificationDigest", ratification],
    ["acceptCollaborator", "collaboratorAcceptanceDigest", collaborator]].flatMap(([method, getter, tuple]) => [
      "function " + method + "(" + tuple + "," + authorization + ") returns (bytes32)",
      "function " + getter + "(" + tuple + "," + authorization + ") view returns (bytes32)",
    ]),
  "function recordArtistAttestation(" + attestation + "," + authorization + ",bytes) returns (bytes32)",
  "function attestationDigest(" + attestation + "," + authorization + ") view returns (bytes32)",
  "function acceptCollaboratorIdentity(address,bytes32," + authorization + ",bytes,string) returns (bytes32)",
  "function collaboratorIdentityDigest(address,bytes32," + authorization + ") view returns (bytes32)",
]);

/**
 * Prepare an unsigned transaction and the exact read-only digest call before wallet submission.
 * Empty proof selects direct execution only when the actual caller is the authority; this pure helper does not know the caller.
 * Nonempty signatures remain opaque ERC-1271/EOA bytes. No nonce reservation or transaction is performed.
 */
export function prepareCurrentArtistOperation<K extends CurrentArtistSigningKind>(
  kind: K, chainId: bigint, registry: Address, message: CurrentArtistSigningMessages[K], submission: CurrentArtistSubmissions[K],
): PreparedCurrentArtistOperation<CurrentArtistSigningMessages[K]> {
  const payload = currentArtistTypedData(kind, chainId, registry, message);
  const m = payload.message as unknown as Record<string, unknown>;
  if (!submission || typeof submission !== "object" || Array.isArray(submission)) throw new Error("Expected submission details");
  if (typeof submission.signature !== "string" || !isHexString(submission.signature, true)) throw new Error("signature must contain complete hex bytes");
  const s = submission as unknown as Record<string, unknown>;
  const time = m.deadline ?? m.signedAt;
  if (submission.signature !== "0x" && m.signedAt === 0n) throw new Error("Signed payout/attestation requires an explicit signedAt timestamp");
  const auth = [m.nonce, time, submission.signature], unsignedAuth = [m.nonce, time, "0x"];
  let method: string, getter: string, args: unknown[], digestArgs: unknown[];
  switch (kind) {
    case "artistAcceptance":
      method = "acceptArtistBinding"; getter = "acceptanceDigest";
      args = [m.collectionId, auth]; digestArgs = [m.collectionId, unsignedAuth]; break;
    case "artistPolicyConsent": {
      method = "recordPolicyConsent"; getter = "policyConsentDigest";
      const p = [m.collectionId, m.phaseId, m.policyHash]; args = [p, auth]; digestArgs = [p, unsignedAuth]; break;
    }
    case "artistEconomicsConsent": {
      if (typeof s.collectionId !== "bigint" || s.collectionId <= 0n || s.collectionId >= 1n << 256n) throw new Error("collectionId must be a positive uint256 bigint");
      method = "recordEconomicsConsent"; getter = "economicsConsentDigest";
      const p = [s.collectionId, m.resolver, m.revenueClass, m.scope, m.scopeId, m.assignmentHash];
      args = [p, auth]; digestArgs = [p, unsignedAuth]; break;
    }
    case "artistPayoutDesignation": {
      method = "recordPayoutDesignation"; getter = "payoutDesignationDigest";
      const p = [m.artistId, m.payoutAccount, m.previousDesignationRecordHash]; args = [p, auth]; digestArgs = [p, unsignedAuth]; break;
    }
    case "artistAttestation": {
      if (typeof s.statementURI !== "string" || keccak256(toUtf8Bytes(s.statementURI)).toLowerCase() !== String(m.statementURIHash).toLowerCase()) throw new Error("statement URI differs from signed hash");
      if (typeof s.statement !== "string" || !isHexString(s.statement, true) || keccak256(s.statement).toLowerCase() !== String(m.statementHash).toLowerCase()) throw new Error("statement bytes differ from signed hash");
      method = "recordArtistAttestation"; getter = "attestationDigest";
      const p = [m.collectionId, m.subjectKind, m.subjectId, m.subjectStateHash, m.schemaId, m.statementHash, s.statementURI];
      args = [p, auth, s.statement]; digestArgs = [p, unsignedAuth]; break;
    }
    case "artistContentRatification": {
      method = "recordContentRatification"; getter = "contentRatificationDigest";
      const p = [m.collectionId, m.metadataContract, m.contentStateHash]; args = [p, auth]; digestArgs = [p, unsignedAuth]; break;
    }
    case "collaboratorIdentityAcceptance":
      if (typeof s.document !== "string" || !isHexString(s.document, true) || keccak256(s.document).toLowerCase() !== String(m.identityRecordHash).toLowerCase()) throw new Error("identity document differs from signed hash");
      if (typeof s.displayName !== "string") throw new Error("displayName must be a string");
      method = "acceptCollaboratorIdentity"; getter = "collaboratorIdentityDigest";
      args = [m.account, m.identityRecordHash, auth, s.document, s.displayName];
      digestArgs = [m.account, m.identityRecordHash, unsignedAuth]; break;
    case "collaboratorAcceptance": {
      method = "acceptCollaborator"; getter = "collaboratorAcceptanceDigest";
      const p = [m.collectionId, m.bindingGeneration, m.bindingHash, m.collaborator, m.role, m.shareLabelId];
      args = [p, auth]; digestArgs = [p, unsignedAuth]; break;
    }
    default: throw new Error("Unknown current Artist signing kind");
  }
  const to = payload.domain.verifyingContract as Address;
  return Object.freeze({ payload, method, digestMethod: getter,
    call: Object.freeze({ to, data: operations.encodeFunctionData(method, args) as Hex, value: 0n }),
    digestCall: Object.freeze({ to, data: operations.encodeFunctionData(getter, digestArgs) as Hex, value: 0n }),
  });
}

/** Check the actual facade getter before signing; this does not establish nonce/authority or mint eligibility. */
export async function assertCurrentArtistDigest<T extends object>(
  provider: Pick<Provider, "getNetwork" | "call">, prepared: PreparedCurrentArtistOperation<T>, options: { blockTag?: BlockTag } = {},
): Promise<void> {
  const network = await provider.getNetwork();
  if (network.chainId !== BigInt(prepared.payload.domain.chainId ?? 0)) throw new Error("RPC chain differs from the Artist signing domain");
  const raw = await provider.call({ ...prepared.digestCall, ...(options.blockTag === undefined ? {} : { blockTag: options.blockTag }) });
  const [actual] = operations.decodeFunctionResult(prepared.digestMethod, raw);
  if (actual.toLowerCase() !== prepared.payload.digest.toLowerCase()) throw new Error("Current Artist getter differs from the signing payload");
}
