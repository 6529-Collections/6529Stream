import { AbiCoder, Interface, ParamType, ZeroAddress, ZeroHash, getAddress, id, keccak256, toUtf8Bytes } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import type { UnsignedCall } from "./binding.js";
import type { SigningPayload } from "./signing.js";
import { buildSigningPayload } from "./signing-payload.js";
export const ARTIST_ATTRIBUTION_SOURCE = "c715354ed57d2ab639f874cc595b272a7631de71";
export const ARTIST_ATTRIBUTION_ABI_SOURCE = "bd4a291e9e159cbbb5079a9a2a418fb151a8c01b";
/** Byte limits on encoding are client bounds; signature/claim URI and Archive payload limits match original source. */
export const ARTIST_ATTRIBUTION_LIMITS = Object.freeze({ signatureBytes: 4096, claimURIBytes: 4096, archiveBytes: 24575, encodedBytes: 65536 });
export const ARTIST_ATTRIBUTION_VALIDATION = Object.freeze({ suppliedFactsOnly: true, signatureExecutionVerified: false, liveAuthorityVerified: false, archiveReadbackVerified: false });

export const ARTIST_ATTRIBUTION_FILING_TUPLE = "tuple(uint256 collectionId,uint64 bindingGeneration,uint8 disputeAction,bytes32 evidenceHash,bytes32 reasonHash)";
export type ArtistAttributionFiling = { readonly collectionId: bigint; readonly bindingGeneration: bigint; readonly disputeAction: bigint; readonly evidenceHash: Hex; readonly reasonHash: Hex; };
export const normalizeArtistAttributionFiling = (value: ArtistAttributionFiling): ArtistAttributionFiling => normalizeTuple(ARTIST_ATTRIBUTION_FILING_TUPLE, value);
export const encodeArtistAttributionFiling = (value: ArtistAttributionFiling): Hex => encodeTuple(ARTIST_ATTRIBUTION_FILING_TUPLE, value);
export const decodeArtistAttributionFiling = (raw: Hex): ArtistAttributionFiling => decodeTuple(ARTIST_ATTRIBUTION_FILING_TUPLE, raw);

export const ARTIST_ATTRIBUTION_STANDING_TUPLE = "tuple(bytes32 artistId,uint64 bindingGeneration,uint32 collaboratorIndex,bytes32 delegation)";
export type ArtistAttributionStanding = { readonly artistId: Hex; readonly bindingGeneration: bigint; readonly collaboratorIndex: bigint; readonly delegation: Hex; };
export const normalizeArtistAttributionStanding = (value: ArtistAttributionStanding): ArtistAttributionStanding => normalizeTuple(ARTIST_ATTRIBUTION_STANDING_TUPLE, value);
export const encodeArtistAttributionStanding = (value: ArtistAttributionStanding): Hex => encodeTuple(ARTIST_ATTRIBUTION_STANDING_TUPLE, value);
export const decodeArtistAttributionStanding = (raw: Hex): ArtistAttributionStanding => decodeTuple(ARTIST_ATTRIBUTION_STANDING_TUPLE, raw);

export const ARTIST_ATTRIBUTION_HEAD_TUPLE = "tuple(bytes32 disputeRecordHash,bytes32 counterStatementRecordHash,bytes32 resolutionActionId,uint8 restoreState,uint8 revocationReason,bool open,bool reopened)";
export type ArtistAttributionHead = { readonly disputeRecordHash: Hex; readonly counterStatementRecordHash: Hex; readonly resolutionActionId: Hex; readonly restoreState: bigint; readonly revocationReason: bigint; readonly open: boolean; readonly reopened: boolean; };
export const normalizeArtistAttributionHead = (value: ArtistAttributionHead): ArtistAttributionHead => normalizeTuple(ARTIST_ATTRIBUTION_HEAD_TUPLE, value);
export const encodeArtistAttributionHead = (value: ArtistAttributionHead): Hex => encodeTuple(ARTIST_ATTRIBUTION_HEAD_TUPLE, value);
export const decodeArtistAttributionHead = (raw: Hex): ArtistAttributionHead => decodeTuple(ARTIST_ATTRIBUTION_HEAD_TUPLE, raw);

export const ARTIST_ATTRIBUTION_RECORD_TUPLE = "tuple(bytes32 recordHash,tuple(uint256 collectionId,uint64 bindingGeneration,uint8 disputeAction,bytes32 evidenceHash,bytes32 reasonHash) terms,address signer,uint8 authorityClass,uint256 nonce,uint64 recordedAt,bytes32 artistId,bytes32 bindingHash,bytes32 disputeRecordHash,bytes32 previousRecordHash,tuple(bytes32 artistId,uint64 bindingGeneration,uint32 collaboratorIndex,bytes32 delegation) standing,bytes32 governanceActionId)";
export type ArtistAttributionRecord = { readonly recordHash: Hex; readonly terms: { readonly collectionId: bigint; readonly bindingGeneration: bigint; readonly disputeAction: bigint; readonly evidenceHash: Hex; readonly reasonHash: Hex; }; readonly signer: Address; readonly authorityClass: bigint; readonly nonce: bigint; readonly recordedAt: bigint; readonly artistId: Hex; readonly bindingHash: Hex; readonly disputeRecordHash: Hex; readonly previousRecordHash: Hex; readonly standing: { readonly artistId: Hex; readonly bindingGeneration: bigint; readonly collaboratorIndex: bigint; readonly delegation: Hex; }; readonly governanceActionId: Hex; };
export const normalizeArtistAttributionRecord = (value: ArtistAttributionRecord): ArtistAttributionRecord => normalizeTuple(ARTIST_ATTRIBUTION_RECORD_TUPLE, value);
export const encodeArtistAttributionRecord = (value: ArtistAttributionRecord): Hex => encodeTuple(ARTIST_ATTRIBUTION_RECORD_TUPLE, value);
export const decodeArtistAttributionRecord = (raw: Hex): ArtistAttributionRecord => decodeTuple(ARTIST_ATTRIBUTION_RECORD_TUPLE, raw);

export const ARTIST_ATTRIBUTION_RESOLUTION_REQUEST_TUPLE = "tuple(uint256 collectionId,uint64 bindingGeneration,bytes32 disputeRecordHash,uint8 resolution,bytes32 evidenceHash,bytes32 reasonHash,bytes32 counterStatementRecordHash)";
export type ArtistAttributionResolutionRequest = { readonly collectionId: bigint; readonly bindingGeneration: bigint; readonly disputeRecordHash: Hex; readonly resolution: bigint; readonly evidenceHash: Hex; readonly reasonHash: Hex; readonly counterStatementRecordHash: Hex; };
export const normalizeArtistAttributionResolutionRequest = (value: ArtistAttributionResolutionRequest): ArtistAttributionResolutionRequest => normalizeTuple(ARTIST_ATTRIBUTION_RESOLUTION_REQUEST_TUPLE, value);
export const encodeArtistAttributionResolutionRequest = (value: ArtistAttributionResolutionRequest): Hex => encodeTuple(ARTIST_ATTRIBUTION_RESOLUTION_REQUEST_TUPLE, value);
export const decodeArtistAttributionResolutionRequest = (raw: Hex): ArtistAttributionResolutionRequest => decodeTuple(ARTIST_ATTRIBUTION_RESOLUTION_REQUEST_TUPLE, raw);

export const ARTIST_ATTRIBUTION_RESOLUTION_TUPLE = "tuple(tuple(uint256 collectionId,uint64 bindingGeneration,bytes32 disputeRecordHash,uint8 resolution,bytes32 evidenceHash,bytes32 reasonHash,bytes32 counterStatementRecordHash) terms,bytes32 actionId,address actor,address proposer,uint8 actionClass,uint8 restoredState,uint64 resolvedAt,bytes32 previousResolutionActionId,bytes32 witnessHash)";
export type ArtistAttributionResolution = { readonly terms: { readonly collectionId: bigint; readonly bindingGeneration: bigint; readonly disputeRecordHash: Hex; readonly resolution: bigint; readonly evidenceHash: Hex; readonly reasonHash: Hex; readonly counterStatementRecordHash: Hex; }; readonly actionId: Hex; readonly actor: Address; readonly proposer: Address; readonly actionClass: bigint; readonly restoredState: bigint; readonly resolvedAt: bigint; readonly previousResolutionActionId: Hex; readonly witnessHash: Hex; };
export const normalizeArtistAttributionResolution = (value: ArtistAttributionResolution): ArtistAttributionResolution => normalizeTuple(ARTIST_ATTRIBUTION_RESOLUTION_TUPLE, value);
export const encodeArtistAttributionResolution = (value: ArtistAttributionResolution): Hex => encodeTuple(ARTIST_ATTRIBUTION_RESOLUTION_TUPLE, value);
export const decodeArtistAttributionResolution = (raw: Hex): ArtistAttributionResolution => decodeTuple(ARTIST_ATTRIBUTION_RESOLUTION_TUPLE, raw);

export const ARTIST_ATTRIBUTION_CONTEXT_TUPLE = "tuple(bytes32 scopeHash,bytes32 oldValueHash,bytes32 newValueHash,uint8 requiredClass,uint8 restoredState)";
export type ArtistAttributionContext = { readonly scopeHash: Hex; readonly oldValueHash: Hex; readonly newValueHash: Hex; readonly requiredClass: bigint; readonly restoredState: bigint; };
export const normalizeArtistAttributionContext = (value: ArtistAttributionContext): ArtistAttributionContext => normalizeTuple(ARTIST_ATTRIBUTION_CONTEXT_TUPLE, value);
export const encodeArtistAttributionContext = (value: ArtistAttributionContext): Hex => encodeTuple(ARTIST_ATTRIBUTION_CONTEXT_TUPLE, value);
export const decodeArtistAttributionContext = (raw: Hex): ArtistAttributionContext => decodeTuple(ARTIST_ATTRIBUTION_CONTEXT_TUPLE, raw);

export const ARTIST_ATTRIBUTION_ADMISSION_TUPLE = "tuple(tuple(bytes32 artistId,address artistAddress,bytes32 identityRecordHash,bytes32 bindingHash,uint64 generation,uint8 consentMode,uint8 saleConsentScope,uint8 registryImmutabilityElection,address proposer,bool accepted) binding_,tuple(bytes32 artistId,uint64 bindingGeneration,uint32 collaboratorIndex,bytes32 delegation) standing,address signer,uint8 authorityClass,uint64 recordedAt,bytes32 digest)";
export type ArtistAttributionAdmission = { readonly binding_: { readonly artistId: Hex; readonly artistAddress: Address; readonly identityRecordHash: Hex; readonly bindingHash: Hex; readonly generation: bigint; readonly consentMode: bigint; readonly saleConsentScope: bigint; readonly registryImmutabilityElection: bigint; readonly proposer: Address; readonly accepted: boolean; }; readonly standing: { readonly artistId: Hex; readonly bindingGeneration: bigint; readonly collaboratorIndex: bigint; readonly delegation: Hex; }; readonly signer: Address; readonly authorityClass: bigint; readonly recordedAt: bigint; readonly digest: Hex; };
export const normalizeArtistAttributionAdmission = (value: ArtistAttributionAdmission): ArtistAttributionAdmission => normalizeTuple(ARTIST_ATTRIBUTION_ADMISSION_TUPLE, value);
export const encodeArtistAttributionAdmission = (value: ArtistAttributionAdmission): Hex => encodeTuple(ARTIST_ATTRIBUTION_ADMISSION_TUPLE, value);
export const decodeArtistAttributionAdmission = (raw: Hex): ArtistAttributionAdmission => decodeTuple(ARTIST_ATTRIBUTION_ADMISSION_TUPLE, raw);

export const ARTIST_ATTRIBUTION_AUTHORIZATION_TUPLE = "tuple(uint256 nonce,uint64 time,bytes signature)";
export type ArtistAttributionAuthorization = { readonly nonce: bigint; readonly time: bigint; readonly signature: Hex; };
export const normalizeArtistAttributionAuthorization = (value: ArtistAttributionAuthorization): ArtistAttributionAuthorization => normalizeTuple(ARTIST_ATTRIBUTION_AUTHORIZATION_TUPLE, value);
export const encodeArtistAttributionAuthorization = (value: ArtistAttributionAuthorization): Hex => encodeTuple(ARTIST_ATTRIBUTION_AUTHORIZATION_TUPLE, value);
export const decodeArtistAttributionAuthorization = (raw: Hex): ArtistAttributionAuthorization => decodeTuple(ARTIST_ATTRIBUTION_AUTHORIZATION_TUPLE, raw);

export const ARTIST_ATTRIBUTION_BINDING_TUPLE = "tuple(bytes32 artistId,address artistAddress,bytes32 identityRecordHash,bytes32 bindingHash,uint64 generation,uint8 consentMode,uint8 saleConsentScope,uint8 registryImmutabilityElection,address proposer,bool accepted)";
export type ArtistAttributionBinding = { readonly artistId: Hex; readonly artistAddress: Address; readonly identityRecordHash: Hex; readonly bindingHash: Hex; readonly generation: bigint; readonly consentMode: bigint; readonly saleConsentScope: bigint; readonly registryImmutabilityElection: bigint; readonly proposer: Address; readonly accepted: boolean; };
export const normalizeArtistAttributionBinding = (value: ArtistAttributionBinding): ArtistAttributionBinding => normalizeTuple(ARTIST_ATTRIBUTION_BINDING_TUPLE, value);
export const encodeArtistAttributionBinding = (value: ArtistAttributionBinding): Hex => encodeTuple(ARTIST_ATTRIBUTION_BINDING_TUPLE, value);
export const decodeArtistAttributionBinding = (raw: Hex): ArtistAttributionBinding => decodeTuple(ARTIST_ATTRIBUTION_BINDING_TUPLE, raw);

export const ARTIST_ATTRIBUTION_SNAPSHOT_TUPLE = "tuple(bytes32 domainId,uint64 revision,bytes32 stateRoot,bytes32 recordChainTip)";
export type ArtistAttributionSnapshot = { readonly domainId: Hex; readonly revision: bigint; readonly stateRoot: Hex; readonly recordChainTip: Hex; };
export const normalizeArtistAttributionSnapshot = (value: ArtistAttributionSnapshot): ArtistAttributionSnapshot => normalizeTuple(ARTIST_ATTRIBUTION_SNAPSHOT_TUPLE, value);
export const encodeArtistAttributionSnapshot = (value: ArtistAttributionSnapshot): Hex => encodeTuple(ARTIST_ATTRIBUTION_SNAPSHOT_TUPLE, value);
export const decodeArtistAttributionSnapshot = (raw: Hex): ArtistAttributionSnapshot => decodeTuple(ARTIST_ATTRIBUTION_SNAPSHOT_TUPLE, raw);

export const ARTIST_ATTRIBUTION_SIGNER_APPROVAL_TUPLE = "tuple(address signer,bytes32 digest,bool direct)";
export type ArtistAttributionSignerApproval = { readonly signer: Address; readonly digest: Hex; readonly direct: boolean; };
export const normalizeArtistAttributionSignerApproval = (value: ArtistAttributionSignerApproval): ArtistAttributionSignerApproval => normalizeTuple(ARTIST_ATTRIBUTION_SIGNER_APPROVAL_TUPLE, value);
export const encodeArtistAttributionSignerApproval = (value: ArtistAttributionSignerApproval): Hex => encodeTuple(ARTIST_ATTRIBUTION_SIGNER_APPROVAL_TUPLE, value);
export const decodeArtistAttributionSignerApproval = (raw: Hex): ArtistAttributionSignerApproval => decodeTuple(ARTIST_ATTRIBUTION_SIGNER_APPROVAL_TUPLE, raw);

export const ARTIST_ATTRIBUTION_CLAIM_TUPLE = "tuple(bytes32 recordHash,uint256 collectionId,address claimant,bytes32 evidenceHash,bytes32 reasonHash,string reasonURI,uint64 filedAt,address proposedArtist,bytes32 previousRecordHash,uint256 index)";
export type ArtistAttributionClaim = { readonly recordHash: Hex; readonly collectionId: bigint; readonly claimant: Address; readonly evidenceHash: Hex; readonly reasonHash: Hex; readonly reasonURI: string; readonly filedAt: bigint; readonly proposedArtist: Address; readonly previousRecordHash: Hex; readonly index: bigint; };
export const normalizeArtistAttributionClaim = (value: ArtistAttributionClaim): ArtistAttributionClaim => normalizeTuple(ARTIST_ATTRIBUTION_CLAIM_TUPLE, value);
export const encodeArtistAttributionClaim = (value: ArtistAttributionClaim): Hex => encodeTuple(ARTIST_ATTRIBUTION_CLAIM_TUPLE, value);
export const decodeArtistAttributionClaim = (raw: Hex): ArtistAttributionClaim => decodeTuple(ARTIST_ATTRIBUTION_CLAIM_TUPLE, raw);

export const ARTIST_ATTRIBUTION_AUTHORITY_HEAD_TUPLE = "tuple(address principal,uint8 authorityClass,bytes32 latestTransition,bytes32 latestContest,bytes32 latestDismissal)";
export type ArtistAttributionAuthorityHead = { readonly principal: Address; readonly authorityClass: bigint; readonly latestTransition: Hex; readonly latestContest: Hex; readonly latestDismissal: Hex; };
export const normalizeArtistAttributionAuthorityHead = (value: ArtistAttributionAuthorityHead): ArtistAttributionAuthorityHead => normalizeTuple(ARTIST_ATTRIBUTION_AUTHORITY_HEAD_TUPLE, value);
export const encodeArtistAttributionAuthorityHead = (value: ArtistAttributionAuthorityHead): Hex => encodeTuple(ARTIST_ATTRIBUTION_AUTHORITY_HEAD_TUPLE, value);
export const decodeArtistAttributionAuthorityHead = (raw: Hex): ArtistAttributionAuthorityHead => decodeTuple(ARTIST_ATTRIBUTION_AUTHORITY_HEAD_TUPLE, raw);

export const ARTIST_ATTRIBUTION_REPUDIATION_RECORD_TUPLE = "tuple(bytes32 recordHash,tuple(uint256 collectionId,uint64 bindingGeneration,uint8 disputeAction,bytes32 evidenceHash,bytes32 reasonHash) terms,bytes32 artistId,address signer,uint8 authorityClass,uint256 nonce,uint64 stagedAt,uint64 executableAt,bytes32 bindingHash,tuple(address principal,uint8 authorityClass,bytes32 latestTransition,bytes32 latestContest,bytes32 latestDismissal) authorityHead,bytes32 capturedGuardianSet,uint64 windowRevision)";
export type ArtistAttributionRepudiationRecord = { readonly recordHash: Hex; readonly terms: { readonly collectionId: bigint; readonly bindingGeneration: bigint; readonly disputeAction: bigint; readonly evidenceHash: Hex; readonly reasonHash: Hex; }; readonly artistId: Hex; readonly signer: Address; readonly authorityClass: bigint; readonly nonce: bigint; readonly stagedAt: bigint; readonly executableAt: bigint; readonly bindingHash: Hex; readonly authorityHead: { readonly principal: Address; readonly authorityClass: bigint; readonly latestTransition: Hex; readonly latestContest: Hex; readonly latestDismissal: Hex; }; readonly capturedGuardianSet: Hex; readonly windowRevision: bigint; };
export const normalizeArtistAttributionRepudiationRecord = (value: ArtistAttributionRepudiationRecord): ArtistAttributionRepudiationRecord => normalizeTuple(ARTIST_ATTRIBUTION_REPUDIATION_RECORD_TUPLE, value);
export const encodeArtistAttributionRepudiationRecord = (value: ArtistAttributionRepudiationRecord): Hex => encodeTuple(ARTIST_ATTRIBUTION_REPUDIATION_RECORD_TUPLE, value);
export const decodeArtistAttributionRepudiationRecord = (raw: Hex): ArtistAttributionRepudiationRecord => decodeTuple(ARTIST_ATTRIBUTION_REPUDIATION_RECORD_TUPLE, raw);

export const ARTIST_ATTRIBUTION_REPUDIATION_ADMISSION_TUPLE = "tuple(tuple(bytes32 artistId,address artistAddress,bytes32 identityRecordHash,bytes32 bindingHash,uint64 generation,uint8 consentMode,uint8 saleConsentScope,uint8 registryImmutabilityElection,address proposer,bool accepted) binding_,tuple(address principal,uint8 authorityClass,bytes32 latestTransition,bytes32 latestContest,bytes32 latestDismissal) authorityHead,bytes32 guardianSet,uint64 stagedAt,uint64 executableAt,uint64 windowRevision)";
export type ArtistAttributionRepudiationAdmission = { readonly binding_: { readonly artistId: Hex; readonly artistAddress: Address; readonly identityRecordHash: Hex; readonly bindingHash: Hex; readonly generation: bigint; readonly consentMode: bigint; readonly saleConsentScope: bigint; readonly registryImmutabilityElection: bigint; readonly proposer: Address; readonly accepted: boolean; }; readonly authorityHead: { readonly principal: Address; readonly authorityClass: bigint; readonly latestTransition: Hex; readonly latestContest: Hex; readonly latestDismissal: Hex; }; readonly guardianSet: Hex; readonly stagedAt: bigint; readonly executableAt: bigint; readonly windowRevision: bigint; };
export const normalizeArtistAttributionRepudiationAdmission = (value: ArtistAttributionRepudiationAdmission): ArtistAttributionRepudiationAdmission => normalizeTuple(ARTIST_ATTRIBUTION_REPUDIATION_ADMISSION_TUPLE, value);
export const encodeArtistAttributionRepudiationAdmission = (value: ArtistAttributionRepudiationAdmission): Hex => encodeTuple(ARTIST_ATTRIBUTION_REPUDIATION_ADMISSION_TUPLE, value);
export const decodeArtistAttributionRepudiationAdmission = (raw: Hex): ArtistAttributionRepudiationAdmission => decodeTuple(ARTIST_ATTRIBUTION_REPUDIATION_ADMISSION_TUPLE, raw);

export const ARTIST_ATTRIBUTION_TERMINAL_TUPLE = "tuple(uint8 phase,address actor,bytes32 reasonHash,uint64 recordedAt)";
export type ArtistAttributionTerminal = { readonly phase: bigint; readonly actor: Address; readonly reasonHash: Hex; readonly recordedAt: bigint; };
export const normalizeArtistAttributionTerminal = (value: ArtistAttributionTerminal): ArtistAttributionTerminal => normalizeTuple(ARTIST_ATTRIBUTION_TERMINAL_TUPLE, value);
export const encodeArtistAttributionTerminal = (value: ArtistAttributionTerminal): Hex => encodeTuple(ARTIST_ATTRIBUTION_TERMINAL_TUPLE, value);
export const decodeArtistAttributionTerminal = (raw: Hex): ArtistAttributionTerminal => decodeTuple(ARTIST_ATTRIBUTION_TERMINAL_TUPLE, raw);

export const ARTIST_ATTRIBUTION_GUARDIAN_PROOF_TUPLE = "tuple(uint256 collectionId,bytes32 repudiationRecordHash,bytes32 capturedGuardianSet,bytes32 currentGuardianSet,address vetoer,bytes32 reasonHash,uint64 vetoedAt)";
export type ArtistAttributionGuardianProof = { readonly collectionId: bigint; readonly repudiationRecordHash: Hex; readonly capturedGuardianSet: Hex; readonly currentGuardianSet: Hex; readonly vetoer: Address; readonly reasonHash: Hex; readonly vetoedAt: bigint; };
export const normalizeArtistAttributionGuardianProof = (value: ArtistAttributionGuardianProof): ArtistAttributionGuardianProof => normalizeTuple(ARTIST_ATTRIBUTION_GUARDIAN_PROOF_TUPLE, value);
export const encodeArtistAttributionGuardianProof = (value: ArtistAttributionGuardianProof): Hex => encodeTuple(ARTIST_ATTRIBUTION_GUARDIAN_PROOF_TUPLE, value);
export const decodeArtistAttributionGuardianProof = (raw: Hex): ArtistAttributionGuardianProof => decodeTuple(ARTIST_ATTRIBUTION_GUARDIAN_PROOF_TUPLE, raw);

export const ARTIST_ATTRIBUTION_WITHDRAWAL_TUPLE = "tuple(bytes32 recordHash,bytes32 counterStatementRecordHash,uint8 restoredState)";
export type ArtistAttributionWithdrawal = { readonly recordHash: Hex; readonly counterStatementRecordHash: Hex; readonly restoredState: bigint; };
export const normalizeArtistAttributionWithdrawal = (value: ArtistAttributionWithdrawal): ArtistAttributionWithdrawal => normalizeTuple(ARTIST_ATTRIBUTION_WITHDRAWAL_TUPLE, value);
export const encodeArtistAttributionWithdrawal = (value: ArtistAttributionWithdrawal): Hex => encodeTuple(ARTIST_ATTRIBUTION_WITHDRAWAL_TUPLE, value);
export const decodeArtistAttributionWithdrawal = (raw: Hex): ArtistAttributionWithdrawal => decodeTuple(ARTIST_ATTRIBUTION_WITHDRAWAL_TUPLE, raw);

export const ARTIST_ATTRIBUTION_CLAIM_EVIDENCE_TUPLE = "tuple(uint16 schemaVersion,uint256 collectionId,address proposedArtist,bytes32 claimRecordHash,bytes32 narrativeHash)";
export type ArtistAttributionClaimEvidence = { readonly schemaVersion: bigint; readonly collectionId: bigint; readonly proposedArtist: Address; readonly claimRecordHash: Hex; readonly narrativeHash: Hex; };
export const normalizeArtistAttributionClaimEvidence = (value: ArtistAttributionClaimEvidence): ArtistAttributionClaimEvidence => normalizeTuple(ARTIST_ATTRIBUTION_CLAIM_EVIDENCE_TUPLE, value);
export const encodeArtistAttributionClaimEvidence = (value: ArtistAttributionClaimEvidence): Hex => encodeTuple(ARTIST_ATTRIBUTION_CLAIM_EVIDENCE_TUPLE, value);
export const decodeArtistAttributionClaimEvidence = (raw: Hex): ArtistAttributionClaimEvidence => decodeTuple(ARTIST_ATTRIBUTION_CLAIM_EVIDENCE_TUPLE, raw);

export const ARTIST_ATTRIBUTION_ARCHIVE_ENVELOPE_TUPLE = "tuple(uint16 version,bytes32 configurationHash,uint16 operation,address actor,bytes32 value,tuple(bytes32 domainId,uint64 revision,bytes32 stateRoot,bytes32 recordChainTip)[7] before_,tuple(bytes32 domainId,uint64 revision,bytes32 stateRoot,bytes32 recordChainTip)[7] after_,bytes payload)";
export type ArtistAttributionArchiveEnvelope = { readonly version: bigint; readonly configurationHash: Hex; readonly operation: bigint; readonly actor: Address; readonly value: Hex; readonly before_: readonly [{ readonly domainId: Hex; readonly revision: bigint; readonly stateRoot: Hex; readonly recordChainTip: Hex; },{ readonly domainId: Hex; readonly revision: bigint; readonly stateRoot: Hex; readonly recordChainTip: Hex; },{ readonly domainId: Hex; readonly revision: bigint; readonly stateRoot: Hex; readonly recordChainTip: Hex; },{ readonly domainId: Hex; readonly revision: bigint; readonly stateRoot: Hex; readonly recordChainTip: Hex; },{ readonly domainId: Hex; readonly revision: bigint; readonly stateRoot: Hex; readonly recordChainTip: Hex; },{ readonly domainId: Hex; readonly revision: bigint; readonly stateRoot: Hex; readonly recordChainTip: Hex; },{ readonly domainId: Hex; readonly revision: bigint; readonly stateRoot: Hex; readonly recordChainTip: Hex; }]; readonly after_: readonly [{ readonly domainId: Hex; readonly revision: bigint; readonly stateRoot: Hex; readonly recordChainTip: Hex; },{ readonly domainId: Hex; readonly revision: bigint; readonly stateRoot: Hex; readonly recordChainTip: Hex; },{ readonly domainId: Hex; readonly revision: bigint; readonly stateRoot: Hex; readonly recordChainTip: Hex; },{ readonly domainId: Hex; readonly revision: bigint; readonly stateRoot: Hex; readonly recordChainTip: Hex; },{ readonly domainId: Hex; readonly revision: bigint; readonly stateRoot: Hex; readonly recordChainTip: Hex; },{ readonly domainId: Hex; readonly revision: bigint; readonly stateRoot: Hex; readonly recordChainTip: Hex; },{ readonly domainId: Hex; readonly revision: bigint; readonly stateRoot: Hex; readonly recordChainTip: Hex; }]; readonly payload: Hex; };
export const normalizeArtistAttributionArchiveEnvelope = (value: ArtistAttributionArchiveEnvelope): ArtistAttributionArchiveEnvelope => normalizeTuple(ARTIST_ATTRIBUTION_ARCHIVE_ENVELOPE_TUPLE, value);

export const ARTIST_ATTRIBUTION_GOVERNANCE_WITNESS_TUPLE = "tuple(bytes32 actionId,address proposer,uint8 actionClass,bytes32 roleMutationHash,uint64 roleRevision,bytes32 scopeHash,bytes32 oldValueHash,bytes32 newValueHash)";
export type ArtistAttributionGovernanceWitness = { readonly actionId: Hex; readonly proposer: Address; readonly actionClass: bigint; readonly roleMutationHash: Hex; readonly roleRevision: bigint; readonly scopeHash: Hex; readonly oldValueHash: Hex; readonly newValueHash: Hex; };
export const normalizeArtistAttributionGovernanceWitness = (value: ArtistAttributionGovernanceWitness): ArtistAttributionGovernanceWitness => normalizeTuple(ARTIST_ATTRIBUTION_GOVERNANCE_WITNESS_TUPLE, value);
export const encodeArtistAttributionGovernanceWitness = (value: ArtistAttributionGovernanceWitness): Hex => encodeTuple(ARTIST_ATTRIBUTION_GOVERNANCE_WITNESS_TUPLE, value);
export const decodeArtistAttributionGovernanceWitness = (raw: Hex): ArtistAttributionGovernanceWitness => decodeTuple(ARTIST_ATTRIBUTION_GOVERNANCE_WITNESS_TUPLE, raw);

export const ARTIST_ATTRIBUTION_EVIDENCE_TUPLE = "tuple(uint16 schemaVersion,uint256 collectionId,uint64 bindingGeneration,bytes32 bindingHash,bytes32 disputeRecordHash,bytes32 narrativeHash)";
export type ArtistAttributionEvidence = { readonly schemaVersion: bigint; readonly collectionId: bigint; readonly bindingGeneration: bigint; readonly bindingHash: Hex; readonly disputeRecordHash: Hex; readonly narrativeHash: Hex; };
export const normalizeArtistAttributionEvidence = (value: ArtistAttributionEvidence): ArtistAttributionEvidence => normalizeTuple(ARTIST_ATTRIBUTION_EVIDENCE_TUPLE, value);
export const encodeArtistAttributionEvidence = (value: ArtistAttributionEvidence): Hex => encodeTuple(ARTIST_ATTRIBUTION_EVIDENCE_TUPLE, value);
export const decodeArtistAttributionEvidence = (raw: Hex): ArtistAttributionEvidence => decodeTuple(ARTIST_ATTRIBUTION_EVIDENCE_TUPLE, raw);

/** Original interface event witnesses; linked libraries emit these at the owner address. */
export const ARTIST_ATTRIBUTION_EVENTS_ABI = [
  "event AttributionClaimFiled(uint16 schemaVersion,uint256 indexed collectionId,address indexed claimant,bytes32 evidenceHash,bytes32 reasonHash,string reasonURI,uint64 filedAt,bytes32 claimRecordHash)",
  "event AttributionCounterStatementRecorded(uint16 schemaVersion,uint256 indexed collectionId,bytes32 indexed disputeRecordHash,address indexed signer,uint64 bindingGeneration,uint8 authorityClass,bytes32 evidenceHash,bytes32 reasonHash,uint256 nonce,uint64 recordedAt,bytes32 counterStatementRecordHash)",
  "event AttributionDisputeOpened(uint16 schemaVersion,uint256 indexed collectionId,address indexed opener,uint64 bindingGeneration,uint8 openerAuthorityClass,bytes32 evidenceHash,bytes32 reasonHash,uint256 nonce,uint64 openedAt,bytes32 disputeRecordHash)",
  "event AttributionDisputeRecordContext(uint16 schemaVersion,uint256 chainId,address registry,bytes32 indexed recordHash,uint8 disputeAction,bytes32 artistId,bytes32 bindingHash,bytes32 disputeRecordHash,bytes32 previousRecordHash,bytes32 authorityArtistId,bytes32 delegation,bytes32 governanceActionId)",
  "event AttributionDisputeResolved(uint16 schemaVersion,uint256 indexed collectionId,bytes32 indexed disputeRecordHash,uint8 resolution,uint8 restoredState,bytes32 evidenceHash,bytes32 reasonHash,bytes32 counterStatementRecordHash,bytes32 governanceActionId)",
  "event AttributionRepudiationCancelled(uint16 schemaVersion,uint256 indexed collectionId,address indexed canceller,bytes32 indexed repudiationRecordHash,uint8 authorityClass)",
  "event AttributionRepudiationContext(uint16 schemaVersion,uint256 chainId,address registry,bytes32 indexed repudiationRecordHash,bytes32 bindingHash,tuple(address principal,uint8 authorityClass,bytes32 latestTransition,bytes32 latestContest,bytes32 latestDismissal) authorityHead,bytes32 capturedGuardianSet,uint64 windowRevision)",
  "event AttributionRepudiationInvalidated(uint16 schemaVersion,uint256 indexed collectionId,bytes32 indexed repudiationRecordHash,bytes32 identityHeadHash,bytes32 disputeRecordHash)",
  "event AttributionRepudiationStaged(uint16 schemaVersion,uint256 indexed collectionId,bytes32 indexed artistId,address indexed signer,uint64 bindingGeneration,uint8 authorityClass,bytes32 evidenceHash,bytes32 reasonHash,uint256 nonce,uint64 stagedAt,uint64 executableAt,bytes32 repudiationRecordHash)",
  "event AttributionRepudiationVetoed(uint16 schemaVersion,uint256 indexed collectionId,address indexed vetoer,bytes32 indexed repudiationRecordHash,bytes32 reasonHash)",
  "event AttributionDisputeWithdrawn(uint16 schemaVersion,uint256 indexed collectionId,bytes32 indexed disputeRecordHash,address indexed signer,uint64 bindingGeneration,uint8 authorityClass,bytes32 evidenceHash,bytes32 reasonHash,uint256 nonce,uint64 recordedAt,bytes32 withdrawalRecordHash,bytes32 counterStatementRecordHash,uint8 restoredState)",
] as const;
export const ARTIST_ATTRIBUTION_REGISTRY_ABI = [
  ...ARTIST_ATTRIBUTION_EVENTS_ABI,
  "error ArtistPayloadCorrupted(bytes32 expectedHash,bytes32 observedHash)",
  "error ArtistPayloadIndexOutOfBounds(uint256 index,uint256 count)",
  "error ArtistPayloadUnavailable(bytes32 payloadHash)",
  "error GasParameterActionAlreadyApplied(bytes32 parameterId,bytes32 actionId)",
  "error GasParameterActionClassMismatch(uint8 expectedClass,uint8 actualClass)",
  "error GasParameterActionContextInvalid()",
  "error GasParameterActionIdZero()",
  "error GasParameterActionNotExecuting()",
  "error GasParameterAlreadyRegistered(bytes32 parameterId)",
  "error GasParameterInvalidAuthority(address authority)",
  "error GasParameterInvalidConfig(bytes32 parameterId)",
  "error GasParameterNewStateHashMismatch(bytes32 expectedHash,bytes32 actualHash)",
  "error GasParameterNotARaise(bytes32 parameterId,uint256 currentValue,uint256 newValue)",
  "error GasParameterNotAuthority(address caller)",
  "error GasParameterOldStateHashMismatch(bytes32 expectedHash,bytes32 actualHash)",
  "error GasParameterRaiseBoundExceeded(bytes32 parameterId,uint256 currentValue,uint256 newValue)",
  "error GasParameterRevisionOverflow(bytes32 parameterId)",
  "error GasParameterScopeHashMismatch(bytes32 expectedHash,bytes32 actualHash)",
  "error GasParameterUnknown(bytes32 parameterId)",
  "error InvalidBinding()",
  "error InvalidExtensionBinding(address child)",
  "error InvalidStewardSanctionGrant(bytes32 artistId)",
  "function activeRepudiationCount(bytes32 artistId) view returns (uint256)",
  "function attribution(uint256 collectionId) view returns (tuple(address nominatedArtist,address artist,bytes32 identityHash,bytes32 nominationHash,bytes32 acceptanceHash,uint64 nominationRevision,uint64 acceptedAt))",
  "function attributionClaimRecord(bytes32 record) view returns (tuple(bytes32 recordHash,uint256 collectionId,address claimant,bytes32 evidenceHash,bytes32 reasonHash,string reasonURI,uint64 filedAt,address proposedArtist,bytes32 previousRecordHash,uint256 index))",
  "function attributionClaims(uint256 id) view returns (uint256,bytes32)",
  "function attributionDispute(uint256 id,uint64 generation) view returns (tuple(bytes32 disputeRecordHash,bytes32 counterStatementRecordHash,bytes32 resolutionActionId,uint8 restoreState,uint8 revocationReason,bool open,bool reopened))",
  "function attributionDisputeDigest(tuple(uint256 collectionId,uint64 bindingGeneration,uint8 disputeAction,bytes32 evidenceHash,bytes32 reasonHash) p,tuple(uint256 nonce,uint64 time,bytes signature) a) view returns (bytes32)",
  "function attributionDisputeOpeningContext(tuple(uint256 collectionId,uint64 bindingGeneration,uint8 disputeAction,bytes32 evidenceHash,bytes32 reasonHash) p) view returns (tuple(bytes32 scopeHash,bytes32 oldValueHash,bytes32 newValueHash,uint8 requiredClass,uint8 restoredState))",
  "function attributionDisputeRecord(bytes32 record) view returns (tuple(bytes32 recordHash,tuple(uint256 collectionId,uint64 bindingGeneration,uint8 disputeAction,bytes32 evidenceHash,bytes32 reasonHash) terms,address signer,uint8 authorityClass,uint256 nonce,uint64 recordedAt,bytes32 artistId,bytes32 bindingHash,bytes32 disputeRecordHash,bytes32 previousRecordHash,tuple(bytes32 artistId,uint64 bindingGeneration,uint32 collaboratorIndex,bytes32 delegation) standing,bytes32 governanceActionId))",
  "function attributionDisputeResolution(bytes32 action) view returns (tuple(tuple(uint256 collectionId,uint64 bindingGeneration,bytes32 disputeRecordHash,uint8 resolution,bytes32 evidenceHash,bytes32 reasonHash,bytes32 counterStatementRecordHash) terms,bytes32 actionId,address actor,address proposer,uint8 actionClass,uint8 restoredState,uint64 resolvedAt,bytes32 previousResolutionActionId,bytes32 witnessHash))",
  "function attributionDisputeResolutionContext(tuple(uint256 collectionId,uint64 bindingGeneration,bytes32 disputeRecordHash,uint8 resolution,bytes32 evidenceHash,bytes32 reasonHash,bytes32 counterStatementRecordHash) p) view returns (tuple(bytes32 scopeHash,bytes32 oldValueHash,bytes32 newValueHash,uint8 requiredClass,uint8 restoredState))",
  "function attributionDisputeWithdrawal(bytes32 opening) view returns (tuple(bytes32 recordHash,bytes32 counterStatementRecordHash,uint8 restoredState))",
  "function attributionRepudiationDigest(tuple(uint256 collectionId,uint64 bindingGeneration,uint8 disputeAction,bytes32 evidenceHash,bytes32 reasonHash) p,tuple(uint256 nonce,uint64 time,bytes signature) a) view returns (bytes32)",
  "function attributionRepudiationRecord(bytes32 hash) view returns (tuple(bytes32 recordHash,tuple(uint256 collectionId,uint64 bindingGeneration,uint8 disputeAction,bytes32 evidenceHash,bytes32 reasonHash) terms,bytes32 artistId,address signer,uint8 authorityClass,uint256 nonce,uint64 stagedAt,uint64 executableAt,bytes32 bindingHash,tuple(address principal,uint8 authorityClass,bytes32 latestTransition,bytes32 latestContest,bytes32 latestDismissal) authorityHead,bytes32 capturedGuardianSet,uint64 windowRevision))",
  "function attributionRepudiationTerminal(bytes32 hash) view returns (tuple(uint8 phase,address actor,bytes32 reasonHash,uint64 recordedAt))",
  "function cancelAttributionRepudiation(uint256 id,bytes32 expected)",
  "function executeAttributionRepudiation(uint256 id,bytes32 expected)",
  "function fileAttributionClaim(uint256 id,bytes32 evidence,bytes32 reason,string uri) returns (bytes32)",
  "function openAttributionDispute(tuple(uint256 collectionId,uint64 bindingGeneration,uint8 disputeAction,bytes32 evidenceHash,bytes32 reasonHash) p,tuple(bytes32 artistId,uint64 bindingGeneration,uint32 collaboratorIndex,bytes32 delegation) standing,tuple(uint256 nonce,uint64 time,bytes signature) a) returns (bytes32)",
  "function pendingRepudiation(uint256 id) view returns (uint64,uint64,bytes32)",
  "function recordCounterStatement(tuple(uint256 collectionId,uint64 bindingGeneration,uint8 disputeAction,bytes32 evidenceHash,bytes32 reasonHash) p,tuple(bytes32 artistId,uint64 bindingGeneration,uint32 collaboratorIndex,bytes32 delegation) standing,tuple(uint256 nonce,uint64 time,bytes signature) a) returns (bytes32)",
  "function resolveAttributionDispute(tuple(uint256 collectionId,uint64 bindingGeneration,bytes32 disputeRecordHash,uint8 resolution,bytes32 evidenceHash,bytes32 reasonHash,bytes32 counterStatementRecordHash) p) returns (bytes32)",
  "function revokeAttribution(tuple(uint256 collectionId,uint64 bindingGeneration,uint8 disputeAction,bytes32 evidenceHash,bytes32 reasonHash) p,tuple(uint256 nonce,uint64 time,bytes signature) a) returns (bytes32)",
  "function vetoAttributionRepudiation(uint256 id,bytes32 expected,bytes32 reason)",
  "function withdrawAttributionDispute(tuple(uint256 collectionId,uint64 bindingGeneration,uint8 disputeAction,bytes32 evidenceHash,bytes32 reasonHash) p,tuple(bytes32 artistId,uint64 bindingGeneration,uint32 collaboratorIndex,bytes32 delegation) standing,tuple(uint256 nonce,uint64 time,bytes signature) a) returns (bytes32)",
] as const;

export const ARTIST_ATTRIBUTION_OWNER_ABI = [
  ...ARTIST_ATTRIBUTION_EVENTS_ABI,
  "error BoundExceeded(uint256 actual,uint256 maximum)",
  "error InvalidAttribution(uint256 collectionId)",
  "error InvalidAuthorityCheckpoint()",
  "error InvalidBinding()",
  "error InvalidOperation(uint16 operationId)",
  "error InvalidPlatformWorks(uint256 collectionId)",
  "error InvalidRecord()",
  "error InvalidRecoveredHydrationProfile()",
  "error InvalidSanctionConfirmation()",
  "error InvalidSignature()",
  "error Replay(bytes32 replayKey)",
  "error StaleOwnerSnapshot(bytes32 domainId)",
  "error Unauthorized(address caller)",
  "error Unauthorized(address caller)",
  "error UnsupportedProfile()",
  "event ArtistAttributionStateChanged(uint16 schemaVersion,uint256 indexed collectionId,uint8 indexed newState,uint64 bindingGeneration,uint8 oldState,address actor,uint8 authorityClass,bytes32 recordHash,bytes32 reasonHash,string reasonURI)",
  "function attributionClaimRecord(bytes32 hash) view returns (tuple(bytes32 recordHash,uint256 collectionId,address claimant,bytes32 evidenceHash,bytes32 reasonHash,string reasonURI,uint64 filedAt,address proposedArtist,bytes32 previousRecordHash,uint256 index))",
  "function attributionClaims(uint256 id) view returns (uint256,bytes32)",
  "function attributionDispute(uint256 id,uint64 generation) view returns (tuple(bytes32 disputeRecordHash,bytes32 counterStatementRecordHash,bytes32 resolutionActionId,uint8 restoreState,uint8 revocationReason,bool open,bool reopened))",
  "function attributionDisputeRecord(bytes32 hash) view returns (tuple(bytes32 recordHash,tuple(uint256 collectionId,uint64 bindingGeneration,uint8 disputeAction,bytes32 evidenceHash,bytes32 reasonHash) terms,address signer,uint8 authorityClass,uint256 nonce,uint64 recordedAt,bytes32 artistId,bytes32 bindingHash,bytes32 disputeRecordHash,bytes32 previousRecordHash,tuple(bytes32 artistId,uint64 bindingGeneration,uint32 collaboratorIndex,bytes32 delegation) standing,bytes32 governanceActionId))",
  "function attributionDisputeResolution(bytes32 action) view returns (tuple(tuple(uint256 collectionId,uint64 bindingGeneration,bytes32 disputeRecordHash,uint8 resolution,bytes32 evidenceHash,bytes32 reasonHash,bytes32 counterStatementRecordHash) terms,bytes32 actionId,address actor,address proposer,uint8 actionClass,uint8 restoredState,uint64 resolvedAt,bytes32 previousResolutionActionId,bytes32 witnessHash))",
  "function attributionDisputeWithdrawal(bytes32 opening) view returns (tuple(bytes32 recordHash,bytes32 counterStatementRecordHash,uint8 restoredState))",
  "function attributionRepudiationRecord(bytes32 hash) view returns (tuple(bytes32 recordHash,tuple(uint256 collectionId,uint64 bindingGeneration,uint8 disputeAction,bytes32 evidenceHash,bytes32 reasonHash) terms,bytes32 artistId,address signer,uint8 authorityClass,uint256 nonce,uint64 stagedAt,uint64 executableAt,bytes32 bindingHash,tuple(address principal,uint8 authorityClass,bytes32 latestTransition,bytes32 latestContest,bytes32 latestDismissal) authorityHead,bytes32 capturedGuardianSet,uint64 windowRevision))",
  "function attributionRepudiationTerminal(bytes32 hash) view returns (tuple(uint8 phase,address actor,bytes32 reasonHash,uint64 recordedAt))",
  "function attributionState(uint256 collectionId) view returns (uint8,uint64)",
  "function rawPendingRepudiation(uint256 id) view returns (bytes32)",
  "function repudiationCount(bytes32 id,bytes32 cohort) view returns (uint256)",
] as const;
const coder = AbiCoder.defaultAbiCoder();
const Z = ZeroHash as Hex;
const types = new Map<string, ParamType>();
function type(tuple: string): ParamType { let p = types.get(tuple); if (!p) { p = ParamType.from(tuple); types.set(tuple, p); } return p; }
function exact(value: unknown, keys: readonly string[]): asserts value is Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value) || ![Object.prototype, null].includes(Object.getPrototypeOf(value))) throw Error("Expected a plain exact object");
  const actual = Reflect.ownKeys(value);
  if (actual.length !== keys.length || actual.some(k => typeof k !== "string" || !keys.includes(k))) throw Error("Unexpected object fields");
  for (const k of keys) { const d = Object.getOwnPropertyDescriptor(value, k); if (!d || !("value" in d)) throw Error("Accessors are unsupported"); }
}
function uint(value: unknown, bits = 256): bigint { if (typeof value !== "bigint" || value < 0n || value >= 1n << BigInt(bits)) throw Error(`Expected uint${bits} bigint`); return value; }
function address(value: unknown, required = false): Address { if (typeof value !== "string") throw Error("Expected address"); const a = getAddress(value) as Address; if (required && a === ZeroAddress) throw Error("Zero address"); return a; }
function hex(value: unknown, bytes?: number, limit: number = ARTIST_ATTRIBUTION_LIMITS.encodedBytes): Hex {
  if (typeof value !== "string" || !/^0x(?:[0-9a-fA-F]{2})*$/.test(value) || (value.length - 2) / 2 > limit || bytes !== undefined && value.length !== 2 + 2 * bytes) throw Error("Invalid bounded bytes");
  return value.toLowerCase() as Hex;
}
function text(value: unknown, limit: number = ARTIST_ATTRIBUTION_LIMITS.claimURIBytes): string {
  if (typeof value !== "string" || value.length > limit) throw Error("Invalid bounded text");
  for (let i = 0; i < value.length; i++) { const c = value.charCodeAt(i); if (c >= 0xd800 && c <= 0xdbff) { const d = value.charCodeAt(++i); if (!(d >= 0xdc00 && d <= 0xdfff)) throw Error("Invalid Unicode scalar"); } else if (c >= 0xdc00 && c <= 0xdfff) throw Error("Invalid Unicode scalar"); }
  if (toUtf8Bytes(value).length > limit) throw Error("Text exceeds UTF8 byte bound"); return value;
}
function value(p: ParamType, input: unknown, budget: { count: number; bytes: number }): unknown {
  if (++budget.count > 4096) throw Error("Tuple allocation limit");
  if (p.baseType === "tuple") { const c = p.components!; exact(input, c.map(x => x.name)); return Object.freeze(Object.fromEntries(c.map(c => [c.name, value(c, input[c.name], budget)]))); }
  if (p.baseType === "array") {
    if (!Array.isArray(input) || p.arrayLength! < 0 || input.length !== p.arrayLength || Reflect.ownKeys(input).length !== input.length + 1) throw Error("Expected a dense fixed array");
    return Object.freeze(Array.from({ length: input.length }, (_, i) => { const d = Object.getOwnPropertyDescriptor(input, String(i)); if (!d || !("value" in d)) throw Error("Array accessor or hole"); return value(p.arrayChildren!, d.value, budget); }));
  }
  if (p.type === "address") return address(input);
  if (p.type === "bool") { if (typeof input !== "boolean") throw Error("Expected boolean"); return input; }
  if (p.type.startsWith("uint")) return uint(input, Number(p.type.slice(4)));
  let result: unknown;
  if (p.type === "string") { result = text(input, ARTIST_ATTRIBUTION_LIMITS.encodedBytes); budget.bytes += toUtf8Bytes(result as string).length; }
  else if (p.type.startsWith("bytes")) { result = hex(input, p.type === "bytes" ? undefined : Number(p.type.slice(5))); budget.bytes += ((result as string).length - 2) / 2; }
  else throw Error("Unsupported original scalar");
  if (budget.bytes > ARTIST_ATTRIBUTION_LIMITS.encodedBytes) throw Error("Cumulative tuple byte limit"); return result;
}
function normalizeTuple<T>(tuple: string, input: T): T { return value(type(tuple), input, { count: 0, bytes: 0 }) as T; }
function plain(p: ParamType, v: unknown): unknown { if (p.baseType === "tuple") return Object.fromEntries(p.components!.map((c, i) => [c.name, plain(c, (v as readonly unknown[])[i])])); if (p.baseType === "array") return (v as readonly unknown[]).map(x => plain(p.arrayChildren!, x)); return v; }
function dynamic(p: ParamType): boolean { return p.type === "bytes" || p.type === "string" || p.baseType === "array" && (p.arrayLength! < 0 || dynamic(p.arrayChildren!)) || p.baseType === "tuple" && p.components!.some(dynamic); }
function staticSize(p: ParamType): number { return dynamic(p) ? 32 : p.baseType === "tuple" ? p.components!.reduce((n, c) => n + staticSize(c), 0) : p.baseType === "array" ? p.arrayLength! * staticSize(p.arrayChildren!) : 32; }
/** Inspect offsets and dynamic byte sizes before asking ethers to allocate decoded values. */
function preflight(ps: readonly ParamType[], input: Hex, limit: number = ARTIST_ATTRIBUTION_LIMITS.encodedBytes): Hex {
  const raw = hex(input, undefined, limit), length = (raw.length - 2) / 2; let nodes = 0, allocated = 0;
  if (!length || length % 32) throw Error("Invalid ABI length");
  const word = (at: number) => { if (!Number.isSafeInteger(at) || at < 0 || at + 32 > length || at % 32) throw Error("Invalid ABI word"); return BigInt(`0x${raw.slice(2 + 2 * at, 66 + 2 * at)}`); };
  const number = (n: bigint) => { if (n > BigInt(limit)) throw Error("ABI allocation bound"); return Number(n); };
  const sequence = (members: readonly ParamType[], start: number) => {
    const head = members.reduce((n, p) => n + staticSize(p), 0); if (start + head > length) throw Error("ABI head exceeds bytes"); let at = start;
    for (const p of members) { if (dynamic(p)) { const offset = number(word(at)); if (offset < head || offset % 32) throw Error("Invalid ABI offset"); visit(p, start + offset); at += 32; } else { visit(p, at); at += staticSize(p); } }
  };
  const visit = (p: ParamType, at: number): void => {
    if (++nodes > 4096) throw Error("ABI allocation count");
    if (p.type === "bytes" || p.type === "string") { const n = number(word(at)); allocated += n; if (allocated > limit || at + 32 + Math.ceil(n / 32) * 32 > length) throw Error("ABI dynamic bytes exceed bound"); }
    else if (p.baseType === "tuple") sequence(p.components!, at);
    else if (p.baseType === "array") { if (p.arrayLength! < 0 || p.arrayLength! > 7) throw Error("Unsupported original array"); sequence(Array.from({ length: p.arrayLength! }, () => p.arrayChildren!), at); }
    else word(at);
  };
  sequence(ps, 0); return raw;
}
function encodeTuple(tuple: string, v: unknown): Hex { return hex(coder.encode([type(tuple)], [normalizeTuple(tuple, v)])); }
function decodeTuple<T>(tuple: string, raw: Hex): T { const p = type(tuple), bytes = preflight([p], raw), v = coder.decode([p], bytes); if (coder.encode([p], v) !== bytes) throw Error("Noncanonical original ABI bytes"); return normalizeTuple(tuple, plain(p, v[0])) as T; }
function hash(ts: readonly string[], vs: readonly unknown[]): Hex { return keccak256(coder.encode(ts, vs)) as Hex; }
function nonzero(v: Hex, label: string): void { if (v === Z) throw Error(`Missing ${label}`); }
export function artistAttributionInterface(host: "registry" | "owner" = "registry"): Interface { if (host !== "registry" && host !== "owner") throw Error("Unknown attribution host"); return new Interface(host === "registry" ? ARTIST_ATTRIBUTION_REGISTRY_ABI : ARTIST_ATTRIBUTION_OWNER_ABI); }

export interface ArtistAttributionCoordinates { readonly chainId: bigint; readonly registry: Address; readonly core: Address; }
export function normalizeArtistAttributionCoordinates(v: ArtistAttributionCoordinates): ArtistAttributionCoordinates { exact(v, ["chainId", "registry", "core"]); const chainId = uint(v.chainId); if (!chainId) throw Error("Zero chainId"); return Object.freeze({ chainId, registry: address(v.registry, true), core: address(v.core, true) }); }
export interface ArtistAttributionMessage { readonly core: Address; readonly collectionId: bigint; readonly bindingGeneration: bigint; readonly disputeAction: bigint; readonly evidenceHash: Hex; readonly reasonHash: Hex; readonly nonce: bigint; readonly deadline: bigint; }
function admittedFiling(v: ArtistAttributionFiling, action?: bigint): ArtistAttributionFiling {
  const p = normalizeArtistAttributionFiling(v); if (!p.collectionId || !p.bindingGeneration || ![1n, 2n, 3n, 4n].includes(p.disputeAction) || action !== undefined && p.disputeAction !== action) throw Error("Invalid attribution filing action/scope");
  nonzero(p.reasonHash, "reason"); if (p.disputeAction !== 4n) nonzero(p.evidenceHash, "evidence"); return p;
}
export function artistAttributionSigningPayload(coordinates: ArtistAttributionCoordinates, filing: ArtistAttributionFiling, authorization: ArtistAttributionAuthorization): SigningPayload<ArtistAttributionMessage> {
  const c = normalizeArtistAttributionCoordinates(coordinates), p = admittedFiling(filing), a = normalizeArtistAttributionAuthorization(authorization);
  hex(a.signature, undefined, ARTIST_ATTRIBUTION_LIMITS.signatureBytes);
  return buildSigningPayload(c.chainId, c.registry, "6529StreamArtistRegistry", "StreamArtistAttributionDispute", [
    { name: "core", type: "address" }, { name: "collectionId", type: "uint256" }, { name: "bindingGeneration", type: "uint64" }, { name: "disputeAction", type: "uint8" },
    { name: "evidenceHash", type: "bytes32" }, { name: "reasonHash", type: "bytes32" }, { name: "nonce", type: "uint256" }, { name: "deadline", type: "uint64" },
  ], { core: c.core, ...p, nonce: a.nonce, deadline: a.time });
}
/** Caller/signature classification only; relayed empty ERC1271 proofs remain possible. Deadline equality is admitted. */
export function validateArtistAttributionAuthorization(caller: Address, signer: Address, value: ArtistAttributionAuthorization, timestamp: bigint): Readonly<{ authorization: ArtistAttributionAuthorization; direct: boolean; signatureExecutionVerified: false }> {
  const actor = address(caller, true), principal = address(signer, true), a = normalizeArtistAttributionAuthorization(value), at = uint(timestamp, 64);
  hex(a.signature, undefined, 4096); const direct = actor === principal && a.signature === "0x";
  if ((!direct && a.time === 0n) || a.time !== 0n && at > a.time) throw Error("Original authorization deadline");
  return Object.freeze({ authorization: a, direct, signatureExecutionVerified: false });
}
export type ArtistAttributionRequest =
  | Readonly<{ kind: "fileAttributionClaim"; collectionId: bigint; evidenceHash: Hex; reasonHash: Hex; reasonURI: string }>
  | Readonly<{ kind: "openAttributionDispute"; mode: "signed" | "governance"; filing: ArtistAttributionFiling; standing: ArtistAttributionStanding; authorization: ArtistAttributionAuthorization }>
  | Readonly<{ kind: "recordCounterStatement"; filing: ArtistAttributionFiling; standing: ArtistAttributionStanding; authorization: ArtistAttributionAuthorization }>
  | Readonly<{ kind: "withdrawAttributionDispute"; filing: ArtistAttributionFiling; standing: ArtistAttributionStanding; authorization: ArtistAttributionAuthorization }>
  | Readonly<{ kind: "revokeAttribution"; filing: ArtistAttributionFiling; authorization: ArtistAttributionAuthorization }>
  | Readonly<{ kind: "resolveAttributionDispute"; resolution: ArtistAttributionResolutionRequest }>
  | Readonly<{ kind: "vetoAttributionRepudiation"; collectionId: bigint; expectedRepudiation: Hex; reasonHash: Hex }>
  | Readonly<{ kind: "cancelAttributionRepudiation"; collectionId: bigint; expectedRepudiation: Hex }>
  | Readonly<{ kind: "executeAttributionRepudiation"; collectionId: bigint; expectedRepudiation: Hex }>;
export type ArtistAttributionKind = ArtistAttributionRequest["kind"];
export const ARTIST_ATTRIBUTION_RECIPES = Object.freeze({
  fileAttributionClaim: Object.freeze({ operationId: 10n, readMask: 0x10n, writeMask: 0x10n }),
  openAttributionDispute: Object.freeze({ operationId: 44n, readMask: 0x15n, writeMask: 0x14n }),
  recordCounterStatement: Object.freeze({ operationId: 45n, readMask: 0x17n, writeMask: 0x14n }),
  resolveAttributionDispute: Object.freeze({ operationId: 46n, readMask: 0x11n, writeMask: 0x10n }),
  revokeAttribution: Object.freeze({ operationId: 47n, readMask: 0x17n, writeMask: 0x14n }),
  vetoAttributionRepudiation: Object.freeze({ operationId: 48n, readMask: 0x14n, writeMask: 0x14n }),
  cancelAttributionRepudiation: Object.freeze({ operationId: 49n, readMask: 0x14n, writeMask: 0x14n }),
  executeAttributionRepudiation: Object.freeze({ operationId: 50n, readMask: 0x15n, writeMask: 0x10n }),
  withdrawAttributionDispute: Object.freeze({ operationId: 61n, readMask: 0x15n, writeMask: 0x14n }),
});
export function normalizeArtistAttributionRequest(input: ArtistAttributionRequest): ArtistAttributionRequest {
  if (!input || typeof input !== "object" || !Object.hasOwn(input, "kind") || !("value" in Object.getOwnPropertyDescriptor(input, "kind")!)) throw Error("Invalid request discriminator");
  const kind = input.kind;
  if (kind === "fileAttributionClaim") { exact(input, ["kind", "collectionId", "evidenceHash", "reasonHash", "reasonURI"]); const collectionId = uint(input.collectionId), evidenceHash = hex(input.evidenceHash, 32), reasonHash = hex(input.reasonHash, 32); if (!collectionId) throw Error("Zero collection"); nonzero(evidenceHash, "evidence"); nonzero(reasonHash, "reason"); return Object.freeze({ kind, collectionId, evidenceHash, reasonHash, reasonURI: text(input.reasonURI) }); }
  if (kind === "openAttributionDispute" || kind === "recordCounterStatement" || kind === "withdrawAttributionDispute" || kind === "revokeAttribution") {
    exact(input, kind === "openAttributionDispute" ? ["kind", "mode", "filing", "standing", "authorization"] : kind === "revokeAttribution" ? ["kind", "filing", "authorization"] : ["kind", "filing", "standing", "authorization"]);
    const filing = admittedFiling(input.filing, kind === "openAttributionDispute" ? 1n : kind === "withdrawAttributionDispute" ? 2n : kind === "recordCounterStatement" ? 3n : 4n), authorization = normalizeArtistAttributionAuthorization(input.authorization); hex(authorization.signature, undefined, 4096);
    if (kind === "revokeAttribution") return Object.freeze({ kind, filing, authorization });
    const standing = normalizeArtistAttributionStanding(input.standing);
    if (kind === "openAttributionDispute" && input.mode === "governance") {
      if (standing.artistId !== Z || standing.bindingGeneration !== 0n || standing.collaboratorIndex !== 0n || standing.delegation !== Z || authorization.nonce !== 0n || authorization.time !== 0n || authorization.signature !== "0x") throw Error("Governed opening requires empty original authorization and standing");
      return Object.freeze({ kind, mode: input.mode, filing, standing, authorization });
    }
    if (kind === "openAttributionDispute" && input.mode !== "signed") throw Error("Unknown opening mode");
    if (standing.artistId === Z || !standing.bindingGeneration) throw Error("Missing signed standing");
    return kind === "openAttributionDispute" ? Object.freeze({ kind, mode: input.mode, filing, standing, authorization }) : Object.freeze({ kind, filing, standing, authorization });
  }
  if (kind === "resolveAttributionDispute") {
    exact(input, ["kind", "resolution"]); const resolution = normalizeArtistAttributionResolutionRequest(input.resolution);
    if (!resolution.collectionId || !resolution.bindingGeneration || ![1n, 2n].includes(resolution.resolution)) throw Error("Invalid resolution");
    nonzero(resolution.disputeRecordHash, "opening"); nonzero(resolution.evidenceHash, "evidence"); nonzero(resolution.reasonHash, "reason"); return Object.freeze({ kind, resolution });
  }
  if (kind === "vetoAttributionRepudiation" || kind === "cancelAttributionRepudiation" || kind === "executeAttributionRepudiation") {
    exact(input, kind === "vetoAttributionRepudiation" ? ["kind", "collectionId", "expectedRepudiation", "reasonHash"] : ["kind", "collectionId", "expectedRepudiation"]);
    const collectionId = uint(input.collectionId), expectedRepudiation = hex(input.expectedRepudiation, 32); if (!collectionId) throw Error("Zero collection"); nonzero(expectedRepudiation, "repudiation");
    if (kind === "vetoAttributionRepudiation") { const reasonHash = hex(input.reasonHash, 32); nonzero(reasonHash, "reason"); return Object.freeze({ kind, collectionId, expectedRepudiation, reasonHash }); }
    return Object.freeze({ kind, collectionId, expectedRepudiation });
  }
  throw Error("Unknown attribution operation");
}
function argumentsFor(r: ArtistAttributionRequest): readonly unknown[] {
  switch (r.kind) {
    case "fileAttributionClaim": return [r.collectionId, r.evidenceHash, r.reasonHash, r.reasonURI];
    case "openAttributionDispute": case "recordCounterStatement": case "withdrawAttributionDispute": return [r.filing, r.standing, r.authorization];
    case "revokeAttribution": return [r.filing, r.authorization];
    case "resolveAttributionDispute": return [r.resolution];
    case "vetoAttributionRepudiation": return [r.collectionId, r.expectedRepudiation, r.reasonHash];
    case "cancelAttributionRepudiation": case "executeAttributionRepudiation": return [r.collectionId, r.expectedRepudiation];
  }
}
export interface ArtistAttributionCall { readonly coordinates: ArtistAttributionCoordinates; readonly caller: Address; readonly request: ArtistAttributionRequest; readonly operationId: bigint; readonly call: UnsignedCall; readonly signingPayload: SigningPayload<ArtistAttributionMessage> | null; readonly requiresGovernance: boolean; readonly factsVerified: false; }
export function prepareArtistAttributionCall(coordinates: ArtistAttributionCoordinates, caller: Address, request: ArtistAttributionRequest): ArtistAttributionCall {
  const c = normalizeArtistAttributionCoordinates(coordinates), actor = address(caller, true), r = normalizeArtistAttributionRequest(request), requiresGovernance = r.kind === "resolveAttributionDispute" || r.kind === "openAttributionDispute" && r.mode === "governance";
  const signingPayload = "filing" in r && !requiresGovernance ? artistAttributionSigningPayload(c, r.filing, r.authorization) : null;
  const data = hex(artistAttributionInterface().encodeFunctionData(r.kind, argumentsFor(r)));
  return Object.freeze({ coordinates: c, caller: actor, request: r, operationId: ARTIST_ATTRIBUTION_RECIPES[r.kind].operationId, call: Object.freeze({ to: c.registry, value: 0n, data }), signingPayload, requiresGovernance, factsVerified: false });
}
export function normalizeArtistAttributionCall(v: ArtistAttributionCall): ArtistAttributionCall {
  exact(v, ["coordinates", "caller", "request", "operationId", "call", "signingPayload", "requiresGovernance", "factsVerified"]); const p = prepareArtistAttributionCall(v.coordinates, v.caller, v.request);
  exact(v.call, ["to", "value", "data"]);
  if (v.call.to !== p.call.to || v.call.value !== 0n || v.call.data !== p.call.data || v.operationId !== p.operationId || v.requiresGovernance !== p.requiresGovernance || v.factsVerified !== false) throw Error("Contradictory prepared attribution call");
  equalExpected(v.signingPayload, p.signingPayload);
  // Return the freshly reconstructed detached schema/domain/message, never caller-owned nested signing data.
  return p;
}
function equalExpected(actual: unknown, expected: unknown): void {
  if (Array.isArray(expected)) {
    if (!Array.isArray(actual) || actual.length !== expected.length || Reflect.ownKeys(actual).length !== actual.length + 1) throw Error("Contradictory signing payload array");
    for (let i = 0; i < expected.length; i++) { const d = Object.getOwnPropertyDescriptor(actual, String(i)); if (!d || !("value" in d)) throw Error("Signing payload array accessor"); equalExpected(d.value, expected[i]); }
  } else if (expected && typeof expected === "object") {
    const keys = Object.keys(expected); exact(actual, keys);
    for (const key of keys) equalExpected(actual[key], (expected as Record<string, unknown>)[key]);
  } else if (actual !== expected) throw Error("Contradictory signing payload");
}

/** Structural preimages retain zero values; admission and historical readback are separate. */
export function artistAttributionClaimRecordHash(coordinates: ArtistAttributionCoordinates, claim: ArtistAttributionClaim): Hex {
  const c = normalizeArtistAttributionCoordinates(coordinates), r = normalizeArtistAttributionClaim(claim);
  return hash(["bytes32", "uint256", "address", "address", "uint256", "address", "bytes32", "bytes32", "uint64"],
    [id("6529STREAM_ARTIST_ATTRIBUTION_CLAIM_RECORD_V1"), c.chainId, c.registry, c.core, r.collectionId, r.claimant, r.evidenceHash, r.reasonHash, r.filedAt]);
}
export function artistAttributionClaimSubjectHash(claim: ArtistAttributionClaim): Hex {
  const r = normalizeArtistAttributionClaim(claim); return hash(["uint256", "address", "bytes32", "bytes32"], [r.collectionId, r.claimant, r.evidenceHash, r.reasonHash]);
}
export function artistAttributionDisputeRecordHash(coordinates: ArtistAttributionCoordinates, record: ArtistAttributionRecord): Hex {
  const c = normalizeArtistAttributionCoordinates(coordinates), r = normalizeArtistAttributionRecord(record), p = r.terms;
  return hash(["bytes32", "uint256", "address", "uint256", "uint64", "uint8", "address", "uint8", "bytes32", "bytes32", "uint256", "uint64"],
    [id("6529STREAM_ARTIST_DISPUTE_RECORD_V1"), c.chainId, c.registry, p.collectionId, p.bindingGeneration, p.disputeAction, r.signer, r.authorityClass, p.evidenceHash, p.reasonHash, r.nonce, r.recordedAt]);
}
export function artistAttributionRepudiationRecordHash(coordinates: ArtistAttributionCoordinates, record: ArtistAttributionRepudiationRecord): Hex {
  const c = normalizeArtistAttributionCoordinates(coordinates), r = normalizeArtistAttributionRepudiationRecord(record), p = r.terms;
  return hash(["bytes32", "uint256", "address", "uint256", "uint64", "bytes32", "address", "uint8", "bytes32", "bytes32", "uint256", "uint64", "uint64"],
    [id("6529STREAM_ARTIST_ATTRIBUTION_REPUDIATION_RECORD_V1"), c.chainId, c.registry, p.collectionId, p.bindingGeneration, r.artistId, r.signer, r.authorityClass, p.evidenceHash, p.reasonHash, r.nonce, r.stagedAt, r.executableAt]);
}
export function artistAttributionAuthorityHeadHash(head: ArtistAttributionAuthorityHead): Hex { return keccak256(encodeArtistAttributionAuthorityHead(head)) as Hex; }
export function artistAttributionGovernanceWitnessHash(witness: ArtistAttributionGovernanceWitness): Hex { return keccak256(encodeArtistAttributionGovernanceWitness(witness)) as Hex; }

/** This authenticates only the fields committed by the native record hash, not every saved field. */
export function authenticateArtistAttributionClaimRecord(coordinates: ArtistAttributionCoordinates, claim: ArtistAttributionClaim): ArtistAttributionClaim {
  const r = normalizeArtistAttributionClaim(claim);
  if (!r.collectionId || r.claimant === ZeroAddress || !r.filedAt || !r.index || r.evidenceHash === Z || r.reasonHash === Z || r.recordHash !== artistAttributionClaimRecordHash(coordinates, r)) throw Error("Invalid known claim record");
  text(r.reasonURI); return r;
}
/** The record hash omits standing, binding and ancestry; the original Archive supplies those joins. */
export function authenticateArtistAttributionDisputeRecord(coordinates: ArtistAttributionCoordinates, record: ArtistAttributionRecord): ArtistAttributionRecord {
  const r = normalizeArtistAttributionRecord(record); admittedFiling(r.terms);
  if (r.terms.disputeAction === 4n || r.signer === ZeroAddress || r.authorityClass > 4n || r.recordHash !== artistAttributionDisputeRecordHash(coordinates, r)) throw Error("Invalid known dispute record");
  return r;
}
export const ARTIST_ATTRIBUTION_REPUDIATION_WINDOW = Object.freeze({ defaultSeconds: 604800n, floorSeconds: 259200n, parameter: id("ARTIST_REPUDIATION_CONTEST_SECONDS") as Hex });
export function artistAttributionExecutableAt(stagedAt: bigint, windowSeconds: bigint): bigint {
  const at = uint(stagedAt, 64), window = uint(windowSeconds, 64); if (!at || window < ARTIST_ATTRIBUTION_REPUDIATION_WINDOW.floorSeconds) throw Error("Invalid repudiation window");
  return uint(at + window, 64);
}
export function authenticateArtistAttributionRepudiationRecord(coordinates: ArtistAttributionCoordinates, record: ArtistAttributionRepudiationRecord): ArtistAttributionRepudiationRecord {
  const r = normalizeArtistAttributionRepudiationRecord(record); admittedFiling(r.terms, 4n);
  if (r.artistId === Z || r.bindingHash === Z || r.signer === ZeroAddress || ![1n, 3n, 4n].includes(r.authorityClass) || r.authorityHead.principal !== r.signer || r.authorityHead.authorityClass !== r.authorityClass || !r.windowRevision || r.executableAt < r.stagedAt || artistAttributionExecutableAt(r.stagedAt, r.executableAt - r.stagedAt) !== r.executableAt || r.recordHash !== artistAttributionRepudiationRecordHash(coordinates, r)) throw Error("Invalid known repudiation record");
  return r;
}
function contextBinding(binding: ArtistAttributionBinding, generation: bigint): ArtistAttributionBinding {
  const b = normalizeArtistAttributionBinding(binding);
  if (!generation || b.generation !== generation || b.artistId === Z || b.bindingHash === Z || ![1n, 2n].includes(b.consentMode)) throw Error("Invalid supplied attribution binding"); return b;
}
/** Original governance preimage from supplied facts. Collection existence and live authority are not established. */
export function artistAttributionOpeningContext(coordinates: ArtistAttributionCoordinates, filing: ArtistAttributionFiling, binding: ArtistAttributionBinding, attributionState: bigint, head: ArtistAttributionHead): ArtistAttributionContext {
  const c = normalizeArtistAttributionCoordinates(coordinates), p = admittedFiling(filing, 1n), b = contextBinding(binding, p.bindingGeneration), state = uint(attributionState, 8), h = normalizeArtistAttributionHead(head);
  if (h.open || ![1n, 2n, 3n, 5n].includes(state) || state === 5n && h.revocationReason !== 4n) throw Error("Invalid supplied opening state");
  const scopeHash = hash(["bytes32", "uint256", "address", "address", "uint256", "uint64"], [id("6529STREAM_ARTIST_DISPUTE_OPEN_SCOPE_V1"), c.chainId, c.registry, c.core, p.collectionId, p.bindingGeneration]);
  const oldValueHash = hash([ARTIST_ATTRIBUTION_BINDING_TUPLE, "uint8", ARTIST_ATTRIBUTION_HEAD_TUPLE], [b, state, h]);
  return Object.freeze({ scopeHash, oldValueHash, newValueHash: hash(["bytes32", "bytes32", ARTIST_ATTRIBUTION_FILING_TUPLE], [scopeHash, oldValueHash, p]), requiredClass: 1n, restoredState: state === 5n ? h.restoreState : state });
}
export function artistAttributionResolutionContext(coordinates: ArtistAttributionCoordinates, resolution: ArtistAttributionResolutionRequest, binding: ArtistAttributionBinding, attributionState: bigint, head: ArtistAttributionHead): ArtistAttributionContext {
  const c = normalizeArtistAttributionCoordinates(coordinates), request = normalizeArtistAttributionRequest({ kind: "resolveAttributionDispute", resolution });
  if (request.kind !== "resolveAttributionDispute") throw Error("Invalid resolution request");
  const p = request.resolution, b = contextBinding(binding, p.bindingGeneration), state = uint(attributionState, 8), h = normalizeArtistAttributionHead(head);
  if (state !== 4n || !h.open || h.disputeRecordHash !== p.disputeRecordHash || h.counterStatementRecordHash !== p.counterStatementRecordHash) throw Error("Invalid supplied resolution state");
  const scopeHash = hash(["bytes32", "uint256", "address", "address", "uint256", "uint64", "bytes32"], [id("6529STREAM_ARTIST_DISPUTE_RESOLUTION_SCOPE_V1"), c.chainId, c.registry, c.core, p.collectionId, p.bindingGeneration, p.disputeRecordHash]);
  const oldValueHash = hash([ARTIST_ATTRIBUTION_BINDING_TUPLE, "uint8", ARTIST_ATTRIBUTION_HEAD_TUPLE], [b, state, h]);
  return Object.freeze({ scopeHash, oldValueHash, newValueHash: hash(["bytes32", "bytes32", ARTIST_ATTRIBUTION_RESOLUTION_REQUEST_TUPLE], [scopeHash, oldValueHash, p]), requiredClass: p.resolution === 2n || h.reopened ? 2n : 1n, restoredState: p.resolution === 2n ? 5n : h.restoreState });
}

/** Canonical documents only; these functions do not publish Store bytes or establish coverage. */
export function validateArtistAttributionClaimEvidence(evidence: ArtistAttributionClaimEvidence, collectionId: bigint): ArtistAttributionClaimEvidence {
  const e = normalizeArtistAttributionClaimEvidence(evidence);
  if (!uint(collectionId) || e.collectionId !== collectionId || e.schemaVersion !== 1n || e.narrativeHash === Z || e.claimRecordHash !== Z) throw Error("Invalid claim evidence"); return e;
}
export function validateArtistAttributionEvidence(evidence: ArtistAttributionEvidence, collectionId: bigint, binding: ArtistAttributionBinding, parent: Hex): ArtistAttributionEvidence {
  const e = normalizeArtistAttributionEvidence(evidence), b = normalizeArtistAttributionBinding(binding);
  if (!uint(collectionId) || e.collectionId !== collectionId || e.schemaVersion !== 1n || e.narrativeHash === Z || e.bindingGeneration !== b.generation || e.bindingHash !== b.bindingHash || e.disputeRecordHash !== hex(parent, 32)) throw Error("Invalid dispute evidence"); return e;
}
export function artistAttributionClaimEvidenceHash(evidence: ArtistAttributionClaimEvidence): Hex { return keccak256(encodeArtistAttributionClaimEvidence(evidence)) as Hex; }
export function artistAttributionEvidenceHash(evidence: ArtistAttributionEvidence): Hex { return keccak256(encodeArtistAttributionEvidence(evidence)) as Hex; }

function encodeFlat(tuple: string, input: unknown, limit: number = ARTIST_ATTRIBUTION_LIMITS.encodedBytes): Hex {
  const p = type(tuple), n = normalizeTuple(tuple, input) as Record<string, unknown>;
  return hex(coder.encode(p.components!, p.components!.map(c => n[c.name])), undefined, limit);
}
function decodeFlat<T>(tuple: string, raw: Hex, limit: number = ARTIST_ATTRIBUTION_LIMITS.encodedBytes): T {
  const p = type(tuple), bytes = preflight(p.components!, raw, limit), v = coder.decode(p.components!, bytes);
  if (coder.encode(p.components!, v) !== bytes) throw Error("Noncanonical original flat ABI bytes");
  return normalizeTuple(tuple, plain(p, v)) as T;
}
/** Original Archive uses eight flat ABI arguments, not an ABI-encoded dynamic struct. */
export function encodeArtistAttributionArchiveEnvelope(envelope: ArtistAttributionArchiveEnvelope): Hex { return encodeFlat(ARTIST_ATTRIBUTION_ARCHIVE_ENVELOPE_TUPLE, envelope, ARTIST_ATTRIBUTION_LIMITS.archiveBytes); }
export function decodeArtistAttributionArchiveEnvelope(raw: Hex): ArtistAttributionArchiveEnvelope { return decodeFlat(ARTIST_ATTRIBUTION_ARCHIVE_ENVELOPE_TUPLE, raw, ARTIST_ATTRIBUTION_LIMITS.archiveBytes); }
export function artistAttributionEvidenceId(coordinates: ArtistAttributionCoordinates, coordinator: Address, operationId: bigint, actor: Address, result: Hex): Hex {
  const c = normalizeArtistAttributionCoordinates(coordinates);
  return hash(["bytes32", "uint256", "address", "address", "uint16", "address", "bytes32"], [id("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"), c.chainId, c.registry, address(coordinator, true), uint(operationId, 16), address(actor, true), hex(result, 32)]);
}
export function artistAttributionArchivePayloadHash(envelope: ArtistAttributionArchiveEnvelope): Hex { return keccak256(encodeArtistAttributionArchiveEnvelope(envelope)) as Hex; }

export type ArtistAttributionArchiveDetail =
  | Readonly<{ operationId: 10n; id: bigint; evidence: Hex; reason: Hex; uri: string; e: ArtistAttributionClaimEvidence; r: ArtistAttributionClaimEvidence; ep: Hex; rp: Hex }>
  | Readonly<{ operationId: 44n; p: ArtistAttributionFiling; standing: ArtistAttributionStanding; a: ArtistAttributionAuthorization; admission: ArtistAttributionAdmission; proof: ArtistAttributionSignerApproval; context: ArtistAttributionContext; g: ArtistAttributionGovernanceWitness; head: ArtistAttributionHead; ep: Hex; rp: Hex }>
  | Readonly<{ operationId: 45n; p: ArtistAttributionFiling; standing: ArtistAttributionStanding; a: ArtistAttributionAuthorization; admission: ArtistAttributionAdmission; proof: ArtistAttributionSignerApproval; context: ArtistAttributionContext; g: ArtistAttributionGovernanceWitness; head: ArtistAttributionHead; ep: Hex; rp: Hex }>
  | Readonly<{ operationId: 61n; p: ArtistAttributionFiling; standing: ArtistAttributionStanding; a: ArtistAttributionAuthorization; admission: ArtistAttributionAdmission; proof: ArtistAttributionSignerApproval; head: ArtistAttributionHead; ep: Hex; rp: Hex }>
  | Readonly<{ operationId: 46n; p: ArtistAttributionResolutionRequest; b: ArtistAttributionBinding; context: ArtistAttributionContext; g: ArtistAttributionGovernanceWitness; ep: Hex; rp: Hex }>
  | Readonly<{ operationId: 47n; p: ArtistAttributionFiling; a: ArtistAttributionAuthorization; admission: ArtistAttributionRepudiationAdmission; proof: ArtistAttributionSignerApproval }>
  | Readonly<{ operationId: 48n; r: ArtistAttributionRepudiationRecord; proof: ArtistAttributionGuardianProof; contest: Hex }>
  | Readonly<{ operationId: 49n; r: ArtistAttributionRepudiationRecord }>
  | Readonly<{ operationId: 50n; r: ArtistAttributionRepudiationRecord }>;
function detailTuple(operationId: bigint): string {
  const f = ARTIST_ATTRIBUTION_FILING_TUPLE, s = ARTIST_ATTRIBUTION_STANDING_TUPLE, a = ARTIST_ATTRIBUTION_AUTHORIZATION_TUPLE, d = ARTIST_ATTRIBUTION_ADMISSION_TUPLE, p = ARTIST_ATTRIBUTION_SIGNER_APPROVAL_TUPLE, h = ARTIST_ATTRIBUTION_HEAD_TUPLE;
  switch (operationId) {
    case 10n: return `tuple(uint256 id,bytes32 evidence,bytes32 reason,string uri,${ARTIST_ATTRIBUTION_CLAIM_EVIDENCE_TUPLE} e,${ARTIST_ATTRIBUTION_CLAIM_EVIDENCE_TUPLE} r,bytes32 ep,bytes32 rp)`;
    case 44n: case 45n: return `tuple(${f} p,${s} standing,${a} a,${d} admission,${p} proof,${ARTIST_ATTRIBUTION_CONTEXT_TUPLE} context,${ARTIST_ATTRIBUTION_GOVERNANCE_WITNESS_TUPLE} g,${h} head,bytes32 ep,bytes32 rp)`;
    case 61n: return `tuple(${f} p,${s} standing,${a} a,${d} admission,${p} proof,${h} head,bytes32 ep,bytes32 rp)`;
    case 46n: return `tuple(${ARTIST_ATTRIBUTION_RESOLUTION_REQUEST_TUPLE} p,${ARTIST_ATTRIBUTION_BINDING_TUPLE} b,${ARTIST_ATTRIBUTION_CONTEXT_TUPLE} context,${ARTIST_ATTRIBUTION_GOVERNANCE_WITNESS_TUPLE} g,bytes32 ep,bytes32 rp)`;
    case 47n: return `tuple(${f} p,${a} a,${ARTIST_ATTRIBUTION_REPUDIATION_ADMISSION_TUPLE} admission,${p} proof)`;
    case 48n: return `tuple(${ARTIST_ATTRIBUTION_REPUDIATION_RECORD_TUPLE} r,${ARTIST_ATTRIBUTION_GUARDIAN_PROOF_TUPLE} proof,bytes32 contest)`;
    case 49n: case 50n: return `tuple(${ARTIST_ATTRIBUTION_REPUDIATION_RECORD_TUPLE} r)`;
    default: throw Error("Unsupported attribution Archive operation");
  }
}
export function normalizeArtistAttributionArchiveDetail(detail: ArtistAttributionArchiveDetail): ArtistAttributionArchiveDetail {
  const descriptor = detail && Object.getOwnPropertyDescriptor(detail, "operationId"); if (!descriptor || !("value" in descriptor)) throw Error("Missing Archive operation");
  const operationId = uint(descriptor.value, 16), tuple = detailTuple(operationId), ps = type(tuple).components!;
  exact(detail, ["operationId", ...ps.map(p => p.name)]);
  const fields = Object.fromEntries(ps.map(p => [p.name, (detail as unknown as Record<string, unknown>)[p.name]]));
  const result = normalizeTuple(tuple, fields); return Object.freeze({ operationId, ...result }) as ArtistAttributionArchiveDetail;
}
export function encodeArtistAttributionArchiveDetail(detail: ArtistAttributionArchiveDetail): Hex {
  const { operationId, ...fields } = normalizeArtistAttributionArchiveDetail(detail); return encodeFlat(detailTuple(operationId), fields, ARTIST_ATTRIBUTION_LIMITS.archiveBytes);
}
export function decodeArtistAttributionArchiveDetail(operationId: bigint, raw: Hex): ArtistAttributionArchiveDetail {
  const op = uint(operationId, 16), fields = decodeFlat<Record<string, unknown>>(detailTuple(op), raw, ARTIST_ATTRIBUTION_LIMITS.archiveBytes);
  return Object.freeze({ operationId: op, ...fields }) as ArtistAttributionArchiveDetail;
}

type ArtistAttributionSharedReadFields = {
  attributionClaims: { readonly collectionId: bigint };
  attributionClaimRecord: { readonly recordHash: Hex };
  attributionDispute: { readonly collectionId: bigint; readonly bindingGeneration: bigint };
  attributionDisputeRecord: { readonly recordHash: Hex };
  attributionDisputeResolution: { readonly actionId: Hex };
  attributionDisputeWithdrawal: { readonly opening: Hex };
  attributionRepudiationRecord: { readonly recordHash: Hex };
  attributionRepudiationTerminal: { readonly recordHash: Hex };
};
type ArtistAttributionRegistryReadFields = ArtistAttributionSharedReadFields & {
  attribution: { readonly collectionId: bigint };
  activeRepudiationCount: { readonly artistId: Hex };
  pendingRepudiation: { readonly collectionId: bigint };
  attributionDisputeDigest: { readonly filing: ArtistAttributionFiling; readonly authorization: ArtistAttributionAuthorization };
  attributionRepudiationDigest: { readonly filing: ArtistAttributionFiling; readonly authorization: ArtistAttributionAuthorization };
  attributionDisputeOpeningContext: { readonly filing: ArtistAttributionFiling };
  attributionDisputeResolutionContext: { readonly resolution: ArtistAttributionResolutionRequest };
};
type ArtistAttributionOwnerReadFields = ArtistAttributionSharedReadFields & {
  attributionState: { readonly collectionId: bigint };
  rawPendingRepudiation: { readonly collectionId: bigint };
  repudiationCount: { readonly artistId: Hex; readonly authorityHeadHash: Hex };
};
export type ArtistAttributionReadRequest =
  { [K in keyof ArtistAttributionRegistryReadFields]: Readonly<{ host: "registry"; kind: K } & ArtistAttributionRegistryReadFields[K]> }[keyof ArtistAttributionRegistryReadFields]
  | { [K in keyof ArtistAttributionOwnerReadFields]: Readonly<{ host: "owner"; kind: K } & ArtistAttributionOwnerReadFields[K]> }[keyof ArtistAttributionOwnerReadFields];
export interface ArtistAttributionRead<R extends ArtistAttributionReadRequest = ArtistAttributionReadRequest> { readonly target: Address; readonly request: R; readonly data: Hex; readonly factsVerified: false; }
/** Read selectors are closed per original host. Unknown records and zero subjects remain valid queries. */
export function prepareArtistAttributionRead<R extends ArtistAttributionReadRequest>(target: Address, request: R): ArtistAttributionRead<R> {
  const to = address(target, true);
  for (const field of ["host", "kind"]) { const d = request && Object.getOwnPropertyDescriptor(request, field); if (!d || !("value" in d)) throw Error("Missing read discriminator"); }
  const { host, kind } = request;
  if (host !== "registry" && host !== "owner") throw Error("Unknown attribution read host");
  const shared = ["attributionClaims", "attributionClaimRecord", "attributionDispute", "attributionDisputeRecord", "attributionDisputeResolution", "attributionDisputeWithdrawal", "attributionRepudiationRecord", "attributionRepudiationTerminal"];
  const exclusive = host === "registry" ? ["attribution", "activeRepudiationCount", "pendingRepudiation", "attributionDisputeDigest", "attributionRepudiationDigest", "attributionDisputeOpeningContext", "attributionDisputeResolutionContext"] : ["attributionState", "rawPendingRepudiation", "repudiationCount"];
  if (![...shared, ...exclusive].includes(kind)) throw Error("Getter is unavailable on this attribution host");
  let fields: Record<string, unknown>, args: readonly unknown[];
  switch (request.kind) {
    case "attributionClaims": case "attribution": case "pendingRepudiation": case "attributionState": case "rawPendingRepudiation":
      exact(request, ["host", "kind", "collectionId"]); fields = { collectionId: uint(request.collectionId) }; args = [fields.collectionId]; break;
    case "attributionClaimRecord": case "attributionDisputeRecord": case "attributionRepudiationRecord": case "attributionRepudiationTerminal":
      exact(request, ["host", "kind", "recordHash"]); fields = { recordHash: hex(request.recordHash, 32) }; args = [fields.recordHash]; break;
    case "attributionDisputeResolution": exact(request, ["host", "kind", "actionId"]); fields = { actionId: hex(request.actionId, 32) }; args = [fields.actionId]; break;
    case "attributionDisputeWithdrawal": exact(request, ["host", "kind", "opening"]); fields = { opening: hex(request.opening, 32) }; args = [fields.opening]; break;
    case "attributionDispute": exact(request, ["host", "kind", "collectionId", "bindingGeneration"]); fields = { collectionId: uint(request.collectionId), bindingGeneration: uint(request.bindingGeneration, 64) }; args = [fields.collectionId, fields.bindingGeneration]; break;
    case "activeRepudiationCount": exact(request, ["host", "kind", "artistId"]); fields = { artistId: hex(request.artistId, 32) }; args = [fields.artistId]; break;
    case "repudiationCount": exact(request, ["host", "kind", "artistId", "authorityHeadHash"]); fields = { artistId: hex(request.artistId, 32), authorityHeadHash: hex(request.authorityHeadHash, 32) }; args = [fields.artistId, fields.authorityHeadHash]; break;
    case "attributionDisputeDigest": case "attributionRepudiationDigest":
      exact(request, ["host", "kind", "filing", "authorization"]); fields = { filing: normalizeArtistAttributionFiling(request.filing), authorization: normalizeArtistAttributionAuthorization(request.authorization) }; args = [fields.filing, fields.authorization]; break;
    case "attributionDisputeOpeningContext": exact(request, ["host", "kind", "filing"]); fields = { filing: normalizeArtistAttributionFiling(request.filing) }; args = [fields.filing]; break;
    case "attributionDisputeResolutionContext": exact(request, ["host", "kind", "resolution"]); fields = { resolution: normalizeArtistAttributionResolutionRequest(request.resolution) }; args = [fields.resolution]; break;
    default: throw Error("Unknown attribution getter");
  }
  const normalized = Object.freeze({ host, kind, ...fields }) as R;
  return Object.freeze({ target: to, request: normalized, data: hex(artistAttributionInterface(host).encodeFunctionData(kind, args)), factsVerified: false });
}
export interface ArtistAttributionReadResults {
  readonly attributionClaims: Readonly<{ count: bigint; latestRecordHash: Hex }>;
  readonly attributionClaimRecord: ArtistAttributionClaim;
  readonly attributionDispute: ArtistAttributionHead;
  readonly attributionDisputeRecord: ArtistAttributionRecord;
  readonly attributionDisputeResolution: ArtistAttributionResolution;
  readonly attributionDisputeWithdrawal: ArtistAttributionWithdrawal;
  readonly attributionRepudiationRecord: ArtistAttributionRepudiationRecord;
  readonly attributionRepudiationTerminal: ArtistAttributionTerminal;
  readonly attribution: Readonly<{ nominatedArtist: Address; artist: Address; identityHash: Hex; nominationHash: Hex; acceptanceHash: Hex; nominationRevision: bigint; acceptedAt: bigint }>;
  readonly activeRepudiationCount: bigint;
  readonly pendingRepudiation: Readonly<{ bindingGeneration: bigint; executableAt: bigint; repudiationRecordHash: Hex }>;
  readonly attributionDisputeDigest: Hex;
  readonly attributionRepudiationDigest: Hex;
  readonly attributionDisputeOpeningContext: ArtistAttributionContext;
  readonly attributionDisputeResolutionContext: ArtistAttributionContext;
  readonly attributionState: Readonly<{ state: bigint; generation: bigint }>;
  readonly rawPendingRepudiation: Hex;
  readonly repudiationCount: bigint;
}
/** Typed canonical decoding, including unknown all-zero history. It does not authenticate the RPC source. */
export function decodeArtistAttributionRead<R extends ArtistAttributionReadRequest>(read: ArtistAttributionRead<R>, raw: Hex): ArtistAttributionReadResults[R["kind"]] {
  exact(read, ["target", "request", "data", "factsVerified"]);
  const expected = prepareArtistAttributionRead(read.target, read.request);
  if (read.data !== expected.data || read.factsVerified !== false) throw Error("Contradictory attribution read");
  const iface = artistAttributionInterface(read.request.host), fragment = iface.getFunction(read.request.kind)!;
  const bytes = preflight(fragment.outputs, raw), decoded = iface.decodeFunctionResult(fragment, bytes);
  if (iface.encodeFunctionResult(fragment, decoded) !== bytes) throw Error("Noncanonical attribution read output");
  const normalized = fragment.outputs.map((p, i) => value(p, plain(p, decoded[i]), { count: 0, bytes: 0 }));
  let result: unknown = normalized[0];
  if (read.request.kind === "attributionClaims") result = Object.freeze({ count: normalized[0], latestRecordHash: normalized[1] });
  else if (read.request.kind === "attributionState") result = Object.freeze({ state: normalized[0], generation: normalized[1] });
  else if (read.request.kind === "pendingRepudiation") result = Object.freeze({ bindingGeneration: normalized[0], executableAt: normalized[1], repudiationRecordHash: normalized[2] });
  return result as ArtistAttributionReadResults[R["kind"]];
}
