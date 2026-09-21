import { AbiCoder, Interface, ParamType, ZeroAddress, ZeroHash, getAddress, id, isHexString, keccak256, toUtf8Bytes } from "ethers";

import type { Address, Hex } from "../generated/contracts.js";

import type { UnsignedCall } from "../binding.js";

import {
  ARTIST_HYDRATION_POLICY_TUPLE,
  ARTIST_HYDRATION_MULTIPLE_REQUEST_TUPLE,
  ARTIST_HYDRATION_CHECKPOINT_TUPLE,
  ARTIST_HYDRATION_NATIVE_RECEIPT_TUPLE,
  ARTIST_HYDRATION_REPLAY_CELL_TUPLE,
  ARTIST_HYDRATION_NONCE_INDEX_TUPLE,
  ARTIST_HYDRATION_NONCE_WORD_TUPLE,
  ARTIST_HYDRATION_SUITE_TUPLE,
  ARTIST_HYDRATION_QUERY_TUPLE,
  ARTIST_HYDRATION_SNAPSHOT_TUPLE,
  ARTIST_HYDRATION_OWNER_DATA_TUPLE
} from "../current-artist-authority-hydration.js";

import type {
  ArtistHydrationSeven, ArtistHydrationOwnerIndex,
  ArtistMultipleHydrationRequest,
  ArtistHydrationCheckpoint,
  ArtistHydrationNativeReceipt,
  ArtistHydrationReplayCell,
  ArtistHydrationNonceIndex,
  ArtistHydrationNonceWord,
  ArtistHydrationSuite,
  ArtistHydrationQuery,
  ArtistHydrationSnapshot,
  ArtistHydrationOwnerData
} from "../current-artist-authority-hydration.js";

export const ARTIST_RECOVERED_HYDRATION_PROFILE = id("6529STREAM_ARTIST_RECOVERED_AUTHORITY_HYDRATION_V1") as Hex;

export const ARTIST_RECOVERED_HYDRATION_SHAPES = Object.freeze({ first: 31n, economics: 63n, delegation: 127n, attestation: 255n });

export const ARTIST_RECOVERED_HYDRATION_PAGE_BYTES = 20_480;

export const ARTIST_RECOVERED_HYDRATION_MAX_BYTES = 2_621_440;

/** Client allocation bound for Prepared ABI responses, including the separate admission certificate. */
export const ARTIST_RECOVERED_HYDRATION_MAX_PREPARED_BYTES = 16 * 1024 * 1024;

export const ARTIST_RECOVERED_HYDRATION_CHECKPOINT_SCHEMA = id("6529STREAM_ARTIST_GUARD_CHECKPOINT_V1") as Hex;

export const ARTIST_RECOVERED_HYDRATION_PAYLOAD_SCHEMA = id("6529STREAM_ARTIST_RECOVERED_OWNER_PAYLOAD_V1") as Hex;

export const ARTIST_RECOVERED_HYDRATION_EVIDENCE_SCHEMA = id("6529STREAM_ARTIST_RECOVERED_HYDRATION_EVIDENCE_V1") as Hex;

export interface ArtistRecoveredHydrationCapability {
  readonly profile: Hex;
  readonly version: bigint;
  readonly ownerIndex: bigint;
  readonly ownerDomain: Hex;
  readonly checkpointSchema: Hex;
  readonly stateSchema: Hex;
  readonly supportedFeatures: bigint;
}

export const ARTIST_RECOVERED_HYDRATION_CAPABILITY_TUPLE = `tuple(bytes32 profile,uint16 version,uint8 ownerIndex,bytes32 ownerDomain,bytes32 checkpointSchema,bytes32 stateSchema,uint256 supportedFeatures)`;

export interface ArtistRecoveredHydrationEconomicsConsent {
  readonly collectionId: bigint;
  readonly resolver: Address;
  readonly revenueClass: Hex;
  readonly scope: bigint;
  readonly scopeId: bigint;
  readonly assignmentHash: Hex;
}

export const ARTIST_RECOVERED_HYDRATION_ECONOMICS_CONSENT_TUPLE = `tuple(uint256 collectionId,address resolver,bytes32 revenueClass,uint8 scope,uint256 scopeId,bytes32 assignmentHash)`;

export interface ArtistRecoveredHydrationAttestation {
  readonly collectionId: bigint;
  readonly subjectKind: bigint;
  readonly subjectId: Hex;
  readonly subjectStateHash: Hex;
  readonly schemaId: Hex;
  readonly statementHash: Hex;
  readonly statementURI: string;
}

export const ARTIST_RECOVERED_HYDRATION_ATTESTATION_TUPLE = `tuple(uint256 collectionId,uint8 subjectKind,bytes32 subjectId,bytes32 subjectStateHash,bytes32 schemaId,bytes32 statementHash,string statementURI)`;

export interface ArtistRecoveredHydrationAttestationInput {
  readonly terms: ArtistRecoveredHydrationAttestation;
  readonly nonce: bigint;
}

export const ARTIST_RECOVERED_HYDRATION_ATTESTATION_INPUT_TUPLE = `tuple(${ARTIST_RECOVERED_HYDRATION_ATTESTATION_TUPLE} terms,uint256 nonce)`;

export interface ArtistRecoveredHydrationCollectionWitness {
  readonly collectionId: bigint;
  readonly economics: readonly ArtistRecoveredHydrationEconomicsConsent[];
  readonly attestations: readonly ArtistRecoveredHydrationAttestationInput[];
}

export const ARTIST_RECOVERED_HYDRATION_COLLECTION_WITNESS_TUPLE = `tuple(uint256 collectionId,${ARTIST_RECOVERED_HYDRATION_ECONOMICS_CONSENT_TUPLE}[] economics,${ARTIST_RECOVERED_HYDRATION_ATTESTATION_INPUT_TUPLE}[] attestations)`;

export interface ArtistRecoveredHydrationRecordsRequest {
  readonly authority: ArtistMultipleHydrationRequest;
  readonly witnesses: readonly ArtistRecoveredHydrationCollectionWitness[];
}

export const ARTIST_RECOVERED_HYDRATION_RECORDS_REQUEST_TUPLE = `tuple(${ARTIST_HYDRATION_MULTIPLE_REQUEST_TUPLE} authority,${ARTIST_RECOVERED_HYDRATION_COLLECTION_WITNESS_TUPLE}[] witnesses)`;

export interface ArtistRecoveredHydrationRequest {
  readonly records: ArtistRecoveredHydrationRecordsRequest;
  readonly expectedCapabilities: ArtistHydrationSeven<ArtistRecoveredHydrationCapability>;
  readonly expectedSourceImportCommitment: Hex;
  readonly expectedSemanticInventory: Hex;
}

export const ARTIST_RECOVERED_HYDRATION_REQUEST_TUPLE = `tuple(${ARTIST_RECOVERED_HYDRATION_RECORDS_REQUEST_TUPLE} records,${ARTIST_RECOVERED_HYDRATION_CAPABILITY_TUPLE}[7] expectedCapabilities,bytes32 expectedSourceImportCommitment,bytes32 expectedSemanticInventory)`;

export interface ArtistRecoveredHydrationExportHeader {
  readonly profile: Hex;
  readonly version: bigint;
  readonly ownerIndex: bigint;
  readonly sourceOrigin: Hex;
  readonly priorImportCommitment: Hex;
  readonly semanticInventory: Hex;
  readonly provenanceCommitment: Hex;
  readonly replayAliasesCommitment: Hex;
  readonly requiredFeatures: bigint;
  readonly semanticRecordCount: bigint;
  readonly replayAliasCount: bigint;
  readonly eraCount: bigint;
}

export const ARTIST_RECOVERED_HYDRATION_EXPORT_HEADER_TUPLE = `tuple(bytes32 profile,uint16 version,uint8 ownerIndex,bytes32 sourceOrigin,bytes32 priorImportCommitment,bytes32 semanticInventory,bytes32 provenanceCommitment,bytes32 replayAliasesCommitment,uint256 requiredFeatures,uint256 semanticRecordCount,uint256 replayAliasCount,uint256 eraCount)`;

export interface ArtistRecoveredHydrationOriginEnvironment {
  readonly chainId: bigint;
  readonly registry: Address;
  readonly coordinator: Address;
  readonly archive: Address;
  readonly owners: ArtistHydrationSeven<Address>;
  readonly ownerCodeHashes: ArtistHydrationSeven<Hex>;
  readonly core: Address;
  readonly manager: Address;
  readonly suiteConfigurationHash: Hex;
}

export const ARTIST_RECOVERED_HYDRATION_ORIGIN_ENVIRONMENT_TUPLE = `tuple(uint256 chainId,address registry,address coordinator,address archive,address[7] owners,bytes32[7] ownerCodeHashes,address core,address manager,bytes32 suiteConfigurationHash)`;

export interface ArtistRecoveredHydrationEra {
  readonly originHash: Hex;
  readonly checkpoints: ArtistHydrationSeven<ArtistHydrationCheckpoint>;
  readonly nativeCounts: ArtistHydrationSeven<bigint>;
  readonly lowerRevisions: ArtistHydrationSeven<bigint>;
  readonly priorImportCommitment: Hex;
}

export const ARTIST_RECOVERED_HYDRATION_ERA_TUPLE = `tuple(bytes32 originHash,${ARTIST_HYDRATION_CHECKPOINT_TUPLE}[7] checkpoints,uint256[7] nativeCounts,uint64[7] lowerRevisions,bytes32 priorImportCommitment)`;

export interface ArtistRecoveredHydrationPoint {
  readonly environmentHash: Hex;
  readonly ownerIndex: bigint;
  readonly ownerRevision: bigint;
}

export const ARTIST_RECOVERED_HYDRATION_POINT_TUPLE = `tuple(bytes32 environmentHash,uint8 ownerIndex,uint64 ownerRevision)`;

export interface ArtistRecoveredHydrationPosition {
  readonly point: ArtistRecoveredHydrationPoint;
  readonly nativeIndex: bigint;
}

export const ARTIST_RECOVERED_HYDRATION_POSITION_TUPLE = `tuple(${ARTIST_RECOVERED_HYDRATION_POINT_TUPLE} point,uint256 nativeIndex)`;

export interface ArtistRecoveredHydrationJournalEntry {
  readonly position: ArtistRecoveredHydrationPosition;
  readonly receipt: ArtistHydrationNativeReceipt;
}

export const ARTIST_RECOVERED_HYDRATION_JOURNAL_ENTRY_TUPLE = `tuple(${ARTIST_RECOVERED_HYDRATION_POSITION_TUPLE} position,${ARTIST_HYDRATION_NATIVE_RECEIPT_TUPLE} receipt)`;

export interface ArtistRecoveredHydrationReplayAlias {
  readonly originHash: Hex;
  readonly ownerIndex: bigint;
  readonly surface: Hex;
  readonly scope: Hex;
  readonly originalKey: Hex;
  readonly cell: ArtistHydrationReplayCell;
  readonly admittedAt: ArtistRecoveredHydrationPoint;
}

export const ARTIST_RECOVERED_HYDRATION_REPLAY_ALIAS_TUPLE = `tuple(bytes32 originHash,uint8 ownerIndex,bytes32 surface,bytes32 scope,bytes32 originalKey,${ARTIST_HYDRATION_REPLAY_CELL_TUPLE} cell,${ARTIST_RECOVERED_HYDRATION_POINT_TUPLE} admittedAt)`;

export interface ArtistRecoveredHydrationProvenance {
  readonly origins: readonly ArtistRecoveredHydrationOriginEnvironment[];
  readonly eras: readonly ArtistRecoveredHydrationEra[];
  readonly journals: ArtistHydrationSeven<readonly ArtistRecoveredHydrationJournalEntry[]>;
  readonly aliases: ArtistHydrationSeven<readonly ArtistRecoveredHydrationReplayAlias[]>;
}

export const ARTIST_RECOVERED_HYDRATION_PROVENANCE_TUPLE = `tuple(${ARTIST_RECOVERED_HYDRATION_ORIGIN_ENVIRONMENT_TUPLE}[] origins,${ARTIST_RECOVERED_HYDRATION_ERA_TUPLE}[] eras,${ARTIST_RECOVERED_HYDRATION_JOURNAL_ENTRY_TUPLE}[][7] journals,${ARTIST_RECOVERED_HYDRATION_REPLAY_ALIAS_TUPLE}[][7] aliases)`;

export interface ArtistRecoveredHydrationOwnerEra {
  readonly originHash: Hex;
  readonly checkpoint: ArtistHydrationCheckpoint;
  readonly nativeCount: bigint;
  readonly lowerRevision: bigint;
  readonly priorImportCommitment: Hex;
}

export const ARTIST_RECOVERED_HYDRATION_OWNER_ERA_TUPLE = `tuple(bytes32 originHash,${ARTIST_HYDRATION_CHECKPOINT_TUPLE} checkpoint,uint256 nativeCount,uint64 lowerRevision,bytes32 priorImportCommitment)`;

export interface ArtistRecoveredHydrationOwnerProvenance {
  readonly origins: readonly ArtistRecoveredHydrationOriginEnvironment[];
  readonly eras: readonly ArtistRecoveredHydrationOwnerEra[];
  readonly journal: readonly ArtistRecoveredHydrationJournalEntry[];
  readonly aliases: readonly ArtistRecoveredHydrationReplayAlias[];
}

export const ARTIST_RECOVERED_HYDRATION_OWNER_PROVENANCE_TUPLE = `tuple(${ARTIST_RECOVERED_HYDRATION_ORIGIN_ENVIRONMENT_TUPLE}[] origins,${ARTIST_RECOVERED_HYDRATION_OWNER_ERA_TUPLE}[] eras,${ARTIST_RECOVERED_HYDRATION_JOURNAL_ENTRY_TUPLE}[] journal,${ARTIST_RECOVERED_HYDRATION_REPLAY_ALIAS_TUPLE}[] aliases)`;

export interface ArtistRecoveredHydrationNonceInventory {
  readonly index: ArtistHydrationNonceIndex;
  readonly words: readonly ArtistHydrationNonceWord[];
}

export const ARTIST_RECOVERED_HYDRATION_NONCE_INVENTORY_TUPLE = `tuple(${ARTIST_HYDRATION_NONCE_INDEX_TUPLE} index,${ARTIST_HYDRATION_NONCE_WORD_TUPLE}[] words)`;

export interface ArtistRecoveredHydrationEnvelope {
  readonly header: ArtistRecoveredHydrationExportHeader;
  readonly payload: Hex;
}

export const ARTIST_RECOVERED_HYDRATION_ENVELOPE_TUPLE = `tuple(${ARTIST_RECOVERED_HYDRATION_EXPORT_HEADER_TUPLE} header,bytes payload)`;

export interface ArtistRecoveredHydrationPublication {
  readonly pointer: Address;
  readonly payloadType: Hex;
  readonly payloadHash: Hex;
}

export const ARTIST_RECOVERED_HYDRATION_PUBLICATION_TUPLE = `tuple(address pointer,bytes32 payloadType,bytes32 payloadHash)`;

export interface ArtistRecoveredHydrationOwnerPayload {
  readonly provenance: ArtistRecoveredHydrationOwnerProvenance;
  readonly nonces: readonly ArtistRecoveredHydrationNonceInventory[];
  readonly semanticState: Hex;
  readonly publications: readonly ArtistRecoveredHydrationPublication[];
}

export const ARTIST_RECOVERED_HYDRATION_OWNER_PAYLOAD_TUPLE = `tuple(${ARTIST_RECOVERED_HYDRATION_OWNER_PROVENANCE_TUPLE} provenance,${ARTIST_RECOVERED_HYDRATION_NONCE_INVENTORY_TUPLE}[] nonces,bytes semanticState,${ARTIST_RECOVERED_HYDRATION_PUBLICATION_TUPLE}[] publications)`;

export interface ArtistRecoveredHydrationTimingConfiguration {
  readonly values: ArtistHydrationSeven<bigint>;
  readonly revisions: readonly [bigint, bigint, bigint, bigint, bigint];
}

export const ARTIST_RECOVERED_HYDRATION_TIMING_CONFIGURATION_TUPLE = `tuple(uint64[7] values,uint64[5] revisions)`;

export interface ArtistRecoveredHydrationTimingInput {
  readonly parameter: Hex;
  readonly actionId: Hex;
  readonly actionKey: Hex;
  readonly oldHash: Hex;
  readonly newHash: Hex;
  readonly oldValue: bigint;
  readonly newValue: bigint;
  readonly floor: bigint;
  readonly oldRevision: bigint;
  readonly newRevision: bigint;
}

export const ARTIST_RECOVERED_HYDRATION_TIMING_INPUT_TUPLE = `tuple(bytes32 parameter,bytes32 actionId,bytes32 actionKey,bytes32 oldHash,bytes32 newHash,uint64 oldValue,uint64 newValue,uint64 floor,uint64 oldRevision,uint64 newRevision)`;

export interface ArtistRecoveredHydrationTimingEntry {
  readonly chainId: bigint;
  readonly owner: Address;
  readonly index: bigint;
  readonly change: ArtistRecoveredHydrationTimingInput;
  readonly previousCommitment: Hex;
  readonly commitment: Hex;
}

export const ARTIST_RECOVERED_HYDRATION_TIMING_ENTRY_TUPLE = `tuple(uint256 chainId,address owner,uint256 index,${ARTIST_RECOVERED_HYDRATION_TIMING_INPUT_TUPLE} change,bytes32 previousCommitment,bytes32 commitment)`;

export interface ArtistRecoveredHydrationTimingCheckpoint {
  readonly schema: Hex;
  readonly version: bigint;
  readonly count: bigint;
  readonly root: Hex;
  readonly configurationHash: Hex;
}

export const ARTIST_RECOVERED_HYDRATION_TIMING_CHECKPOINT_TUPLE = `tuple(bytes32 schema,uint16 version,uint256 count,bytes32 root,bytes32 configurationHash)`;

export interface ArtistRecoveredHydrationTimingBundle {
  readonly configuration: ArtistRecoveredHydrationTimingConfiguration;
  readonly entries: readonly ArtistRecoveredHydrationTimingEntry[];
  readonly checkpoint: ArtistRecoveredHydrationTimingCheckpoint;
}

export const ARTIST_RECOVERED_HYDRATION_TIMING_BUNDLE_TUPLE = `tuple(${ARTIST_RECOVERED_HYDRATION_TIMING_CONFIGURATION_TUPLE} configuration,${ARTIST_RECOVERED_HYDRATION_TIMING_ENTRY_TUPLE}[] entries,${ARTIST_RECOVERED_HYDRATION_TIMING_CHECKPOINT_TUPLE} checkpoint)`;

export interface ArtistRecoveredHydrationActionWitness {
  readonly actionId: Hex;
  readonly callsHash: Hex;
  readonly callIndex: bigint;
  readonly callDataHash: Hex;
  readonly executor: Address;
  readonly executorCodeHash: Hex;
  readonly proposer: Address;
  readonly roleMutationHash: Hex;
  readonly roleRevision: bigint;
  readonly notBefore: bigint;
  readonly expiresAfter: bigint;
  readonly minimumDelay: bigint;
  readonly manifestHash: Hex;
}

export const ARTIST_RECOVERED_HYDRATION_ACTION_WITNESS_TUPLE = `tuple(bytes32 actionId,bytes32 callsHash,uint256 callIndex,bytes32 callDataHash,address executor,bytes32 executorCodeHash,address proposer,bytes32 roleMutationHash,uint64 roleRevision,uint64 notBefore,uint64 expiresAfter,uint64 minimumDelay,bytes32 manifestHash)`;

export interface ArtistRecoveredHydrationActionFacts {
  readonly status: bigint;
  readonly actionClass: bigint;
  readonly callHash: Hex;
  readonly notBefore: bigint;
  readonly expiresAfter: bigint;
}

export const ARTIST_RECOVERED_HYDRATION_ACTION_FACTS_TUPLE = `tuple(uint8 status,uint8 actionClass,bytes32 callHash,uint64 notBefore,uint64 expiresAfter)`;

export interface ArtistRecoveredHydrationActionGuard {
  readonly associationHash: Hex;
  readonly origin: ArtistRecoveredHydrationPoint;
  readonly witness: ArtistRecoveredHydrationActionWitness;
  readonly facts: ArtistRecoveredHydrationActionFacts;
}

export const ARTIST_RECOVERED_HYDRATION_ACTION_GUARD_TUPLE = `tuple(bytes32 associationHash,${ARTIST_RECOVERED_HYDRATION_POINT_TUPLE} origin,${ARTIST_RECOVERED_HYDRATION_ACTION_WITNESS_TUPLE} witness,${ARTIST_RECOVERED_HYDRATION_ACTION_FACTS_TUPLE} facts)`;

export interface ArtistRecoveredHydrationFinalityScope {
  readonly scopeType: bigint;
  readonly collectionId: bigint;
  readonly tokenId: bigint;
  readonly scopeId: Hex;
}

export const ARTIST_RECOVERED_HYDRATION_FINALITY_SCOPE_TUPLE = `tuple(uint8 scopeType,uint256 collectionId,uint256 tokenId,bytes32 scopeId)`;

export interface ArtistRecoveredHydrationFinalityComponent {
  readonly componentType: Hex;
  readonly component: Address;
  readonly interfaceId: Hex;
  readonly codeHash: Hex;
  readonly moduleVersion: Hex;
  readonly manifestHash: Hex;
  readonly dataHash: Hex;
}

export const ARTIST_RECOVERED_HYDRATION_FINALITY_COMPONENT_TUPLE = `tuple(bytes32 componentType,address component,bytes4 interfaceId,bytes32 codeHash,bytes32 moduleVersion,bytes32 manifestHash,bytes32 dataHash)`;

export interface ArtistRecoveredHydrationFinalityManifest {
  readonly uri: string;
  readonly uriHash: Hex;
  readonly contentHash: Hex;
  readonly schemaId: Hex;
  readonly canonicalizationHash: Hex;
}

export const ARTIST_RECOVERED_HYDRATION_FINALITY_MANIFEST_TUPLE = `tuple(string uri,bytes32 uriHash,bytes32 contentHash,bytes32 schemaId,bytes32 canonicalizationHash)`;

export interface ArtistRecoveredHydrationFinalityEvidence {
  readonly artistEvidenceKind: bigint;
  readonly artistEvidenceHash: Hex;
  readonly artistSigner: Address;
  readonly artistId: Hex;
  readonly artistAuthorityClass: bigint;
  readonly artistNoticeEndsAt: bigint;
  readonly ownerEvidenceHash: Hex;
  readonly ownerEvidenceRevision: bigint;
  readonly ownerNoticeEndsAt: bigint;
  readonly ownerAcknowledgementCount: bigint;
  readonly ownerObjectionCount: bigint;
}

export const ARTIST_RECOVERED_HYDRATION_FINALITY_EVIDENCE_TUPLE = `tuple(uint8 artistEvidenceKind,bytes32 artistEvidenceHash,address artistSigner,bytes32 artistId,uint8 artistAuthorityClass,uint64 artistNoticeEndsAt,bytes32 ownerEvidenceHash,uint64 ownerEvidenceRevision,uint64 ownerNoticeEndsAt,uint32 ownerAcknowledgementCount,uint32 ownerObjectionCount)`;

export interface ArtistRecoveredHydrationFinalityRecord {
  readonly executed: boolean;
  readonly recoveryId: Hex;
  readonly scope: ArtistRecoveredHydrationFinalityScope;
  readonly originalFinalityRecordHash: Hex;
  readonly predecessorRecoveryId: Hex;
  readonly generation: bigint;
  readonly oldRouteHash: Hex;
  readonly recoveryRouteHash: Hex;
  readonly artworkBytesChanged: boolean;
  readonly replacementRoute: ArtistRecoveredHydrationFinalityComponent;
  readonly recoveryManifest: ArtistRecoveredHydrationFinalityManifest;
  readonly evidence: ArtistRecoveredHydrationFinalityEvidence;
  readonly reasonHash: Hex;
  readonly reasonURI: string;
  readonly executedAt: bigint;
}

export const ARTIST_RECOVERED_HYDRATION_FINALITY_RECORD_TUPLE = `tuple(bool executed,bytes32 recoveryId,${ARTIST_RECOVERED_HYDRATION_FINALITY_SCOPE_TUPLE} scope,bytes32 originalFinalityRecordHash,bytes32 predecessorRecoveryId,uint64 generation,bytes32 oldRouteHash,bytes32 recoveryRouteHash,bool artworkBytesChanged,${ARTIST_RECOVERED_HYDRATION_FINALITY_COMPONENT_TUPLE} replacementRoute,${ARTIST_RECOVERED_HYDRATION_FINALITY_MANIFEST_TUPLE} recoveryManifest,${ARTIST_RECOVERED_HYDRATION_FINALITY_EVIDENCE_TUPLE} evidence,bytes32 reasonHash,string reasonURI,uint64 executedAt)`;

export interface ArtistRecoveredHydrationFinalityTarget {
  readonly recoveryRegistry: Address;
  readonly recoveryActionId: Hex;
  readonly scope: ArtistRecoveredHydrationFinalityScope;
  readonly originalFinalityRecordHash: Hex;
  readonly recoveryManifestHash: Hex;
}

export const ARTIST_RECOVERED_HYDRATION_FINALITY_TARGET_TUPLE = `tuple(address recoveryRegistry,bytes32 recoveryActionId,${ARTIST_RECOVERED_HYDRATION_FINALITY_SCOPE_TUPLE} scope,bytes32 originalFinalityRecordHash,bytes32 recoveryManifestHash)`;

export interface ArtistRecoveredHydrationFinalityGuard {
  readonly findingRecordHash: Hex;
  readonly origin: ArtistRecoveredHydrationPosition;
  readonly core: Address;
  readonly target: ArtistRecoveredHydrationFinalityTarget;
  readonly registryCodeHash: Hex;
  readonly executor: Address;
  readonly executorCodeHash: Hex;
  readonly action: ArtistRecoveredHydrationActionFacts;
  readonly actionTerminal: boolean;
  readonly record: ArtistRecoveredHydrationFinalityRecord;
}

export const ARTIST_RECOVERED_HYDRATION_FINALITY_GUARD_TUPLE = `tuple(bytes32 findingRecordHash,${ARTIST_RECOVERED_HYDRATION_POSITION_TUPLE} origin,address core,${ARTIST_RECOVERED_HYDRATION_FINALITY_TARGET_TUPLE} target,bytes32 registryCodeHash,address executor,bytes32 executorCodeHash,${ARTIST_RECOVERED_HYDRATION_ACTION_FACTS_TUPLE} action,bool actionTerminal,${ARTIST_RECOVERED_HYDRATION_FINALITY_RECORD_TUPLE} record)`;

export interface ArtistRecoveredHydrationEntropyReceipt {
  readonly previousRequestKey: Hex;
  readonly artistRecordHash: Hex;
  readonly providerEvidenceHash: Hex;
  readonly incidentEvidenceHash: Hex;
  readonly evidenceHash: Hex;
  readonly contentStateHash: Hex;
  readonly journalHead: Hex;
  readonly requestedAtBlock: bigint;
  readonly acceptLateOriginalFulfillment: boolean;
}

export const ARTIST_RECOVERED_HYDRATION_ENTROPY_RECEIPT_TUPLE = `tuple(bytes32 previousRequestKey,bytes32 artistRecordHash,bytes32 providerEvidenceHash,bytes32 incidentEvidenceHash,bytes32 evidenceHash,bytes32 contentStateHash,bytes32 journalHead,uint64 requestedAtBlock,bool acceptLateOriginalFulfillment)`;

export interface ArtistRecoveredHydrationEntropyEvidence {
  readonly findingRecordHash: Hex;
  readonly intentHash: Hex;
  readonly noticeEndsAt: bigint;
}

export const ARTIST_RECOVERED_HYDRATION_ENTROPY_EVIDENCE_TUPLE = `tuple(bytes32 findingRecordHash,bytes32 intentHash,uint64 noticeEndsAt)`;

export interface ArtistRecoveredHydrationEntropyGuard {
  readonly findingRecordHash: Hex;
  readonly origin: ArtistRecoveredHydrationPosition;
  readonly core: Address;
  readonly coordinator: Address;
  readonly coordinatorCodeHash: Hex;
  readonly oldRequestKey: Hex;
  readonly newRequestKey: Hex;
  readonly terminal: boolean;
  readonly receipt: ArtistRecoveredHydrationEntropyReceipt;
  readonly evidence: ArtistRecoveredHydrationEntropyEvidence;
}

export const ARTIST_RECOVERED_HYDRATION_ENTROPY_GUARD_TUPLE = `tuple(bytes32 findingRecordHash,${ARTIST_RECOVERED_HYDRATION_POSITION_TUPLE} origin,address core,address coordinator,bytes32 coordinatorCodeHash,bytes32 oldRequestKey,bytes32 newRequestKey,bool terminal,${ARTIST_RECOVERED_HYDRATION_ENTROPY_RECEIPT_TUPLE} receipt,${ARTIST_RECOVERED_HYDRATION_ENTROPY_EVIDENCE_TUPLE} evidence)`;

export interface ArtistRecoveredHydrationExternalGuards {
  readonly schema: Hex;
  readonly provenanceCommitment: Hex;
  readonly artistId: Hex;
  readonly actions: readonly ArtistRecoveredHydrationActionGuard[];
  readonly finality: readonly ArtistRecoveredHydrationFinalityGuard[];
  readonly entropy: readonly ArtistRecoveredHydrationEntropyGuard[];
}

export const ARTIST_RECOVERED_HYDRATION_EXTERNAL_GUARDS_TUPLE = `tuple(bytes32 schema,bytes32 provenanceCommitment,bytes32 artistId,${ARTIST_RECOVERED_HYDRATION_ACTION_GUARD_TUPLE}[] actions,${ARTIST_RECOVERED_HYDRATION_FINALITY_GUARD_TUPLE}[] finality,${ARTIST_RECOVERED_HYDRATION_ENTROPY_GUARD_TUPLE}[] entropy)`;

export interface ArtistRecoveredHydrationCertificate {
  readonly prior: Address;
  readonly sourceCoordinator: Address;
  readonly source: ArtistHydrationSuite;
  readonly provenance: ArtistRecoveredHydrationProvenance;
  readonly artists: readonly ArtistHydrationQuery[];
  readonly collections: readonly ArtistHydrationQuery[];
  readonly before_: ArtistHydrationSeven<ArtistHydrationSnapshot>;
}

export const ARTIST_RECOVERED_HYDRATION_CERTIFICATE_TUPLE = `tuple(address prior,address sourceCoordinator,${ARTIST_HYDRATION_SUITE_TUPLE} source,${ARTIST_RECOVERED_HYDRATION_PROVENANCE_TUPLE} provenance,${ARTIST_HYDRATION_QUERY_TUPLE}[] artists,${ARTIST_HYDRATION_QUERY_TUPLE}[] collections,${ARTIST_HYDRATION_SNAPSHOT_TUPLE}[7] before_)`;

export interface ArtistRecoveredHydrationPrepared {
  readonly admission: ArtistRecoveredHydrationCertificate;
  readonly query: ArtistHydrationQuery;
  readonly data: ArtistHydrationSeven<ArtistHydrationOwnerData>;
  readonly timing: ArtistRecoveredHydrationTimingCheckpoint;
  readonly externalGuards: ArtistRecoveredHydrationExternalGuards;
}

export const ARTIST_RECOVERED_HYDRATION_PREPARED_TUPLE = `tuple(${ARTIST_RECOVERED_HYDRATION_CERTIFICATE_TUPLE} admission,${ARTIST_HYDRATION_QUERY_TUPLE} query,${ARTIST_HYDRATION_OWNER_DATA_TUPLE}[7] data,${ARTIST_RECOVERED_HYDRATION_TIMING_CHECKPOINT_TUPLE} timing,${ARTIST_RECOVERED_HYDRATION_EXTERNAL_GUARDS_TUPLE} externalGuards)`;

export interface ArtistRecoveredHydrationEvidenceDescriptor {
  readonly schema: Hex;
  readonly payloadHash: Hex;
  readonly payloadLength: bigint;
  readonly pageHashes: readonly Hex[];
}

export const ARTIST_RECOVERED_HYDRATION_EVIDENCE_DESCRIPTOR_TUPLE = `tuple(bytes32 schema,bytes32 payloadHash,uint256 payloadLength,bytes32[] pageHashes)`;

export interface ArtistRecoveredHydrationCoordinates {
  readonly chainId: bigint;
  readonly registry: Address;
  readonly coordinator: Address;
}

export interface ArtistRecoveredHydrationCall {
  readonly registry: Address;
  readonly caller: Address;
  readonly request: ArtistRecoveredHydrationRequest;
  readonly profile: Hex;
  readonly capabilityId: Hex;
  readonly call: UnsignedCall;
  readonly factsVerified: false;
}

export interface ArtistRecoveredHydrationProfileEvidence {
  readonly profile: Hex;
  readonly version: bigint;
  readonly prior: Address;
  readonly sourceCoordinator: Address;
  readonly request: ArtistRecoveredHydrationRequest;
  readonly artists: readonly ArtistHydrationQuery[];
  readonly collections: readonly ArtistHydrationQuery[];
  readonly query: ArtistHydrationQuery;
  readonly data: ArtistHydrationSeven<ArtistHydrationOwnerData>;
  readonly timing: ArtistRecoveredHydrationTimingCheckpoint;
  readonly externalGuards: ArtistRecoveredHydrationExternalGuards;
}

export interface ArtistRecoveredHydrationOperationEvidence {
  readonly schemaVersion: bigint;
  readonly configurationHash: Hex;
  readonly operationId: bigint;
  readonly actor: Address;
  readonly commitment: Hex;
  readonly before: ArtistHydrationSeven<ArtistHydrationSnapshot>;
  readonly after: ArtistHydrationSeven<ArtistHydrationSnapshot>;
  readonly profileData: Hex;
}

export interface ArtistRecoveredHydrationHistoricalCell {
  readonly sourceKey: Hex;
  readonly cell: ArtistHydrationReplayCell;
}

/** Facts come from complete typed source inventories; these flags cannot establish that completeness. */
export interface ArtistRecoveredHydrationFeatureFacts {
  readonly currentAuthorityClass: bigint;
  readonly recoveryAuthorityClasses: readonly bigint[];
  readonly hasAdjudicationV2: boolean;
  readonly hasRewindsV3: boolean;
  readonly eraCount: bigint;
  readonly economicsCount: bigint;
  readonly hasDelegations: boolean;
  readonly bindingConsentMode: bigint;
  readonly saleConsentCount: bigint;
  readonly attestationCount: bigint;
}

/** Private closed profile engine. Public adapters permanently select their frozen feature ceiling. */
export function createArtistRecoveredHydrationCodec(knownFeatures: 255n | 511n | 262175n) {
  if (knownFeatures !== 255n && knownFeatures !== 511n && knownFeatures !== 262175n) throw Error("Unsupported internal recovered profile");
  const multiple = knownFeatures === 262175n;
  const coder = AbiCoder.defaultAbiCoder();
  const schemaTypes = new Map<string, ParamType>();

  // Cache immutable schemas, never supplied values or observations. Keep legacy
  // adapters on their original path and bound even private caller-selected types.
  function schemaType(tuple: string): ParamType {
    if (!multiple || typeof tuple !== "string" || tuple.length > 65_536) return ParamType.from(tuple);
    const existing = schemaTypes.get(tuple);
    if (existing) return existing;
    const parsed = ParamType.from(tuple);
    if (schemaTypes.size < 128) schemaTypes.set(tuple, parsed);
    return parsed;
  }

  const ZERO = ZeroHash as Hex;

  const ownerNames = [
    "binding_lifecycle", "collaborator_lifecycle", "identity_authority",
    "acceptance_lifecycle", "attribution_lifecycle", "payout_lifecycle", "consent_finality",
  ] as const;

  const tagNames = ["BINDING", "COLLABORATOR", "IDENTITY", "ACCEPTANCE", "ATTRIBUTION", "PAYOUT", "CONSENT"] as const;

  function exact(value: unknown, keys: readonly string[]): asserts value is Record<string, unknown> {
    if (!value || typeof value !== "object" || Array.isArray(value)
      || Reflect.ownKeys(value).length !== keys.length
      || Reflect.ownKeys(value).some(key => typeof key !== "string" || !keys.includes(key))) {
      throw Error("Expected exact original fields");
    }
  }

  function list(value: unknown, maximum: number, length?: number): asserts value is readonly unknown[] {
    if (!Array.isArray(value) || value.length > maximum || length !== undefined && value.length !== length
      || Reflect.ownKeys(value).length !== value.length + 1
      || Array.from({ length: value.length }, (_, i) => i).some(i => !Object.hasOwn(value, i))) {
      throw Error("Expected dense bounded original array");
    }
  }

  function uint(value: unknown, width = 256): bigint {
    if (typeof value !== "bigint" || value < 0n || value >= 1n << BigInt(width)) {
      throw Error(`Expected uint${width} bigint`);
    }
    return value;
  }

  function address(value: unknown, required = false): Address {
    if (typeof value !== "string") throw Error("Expected address");
    const result = getAddress(value) as Address;
    if (required && result === ZeroAddress) throw Error("Expected nonzero address");
    return result;
  }

  function bytes(value: unknown, width?: number, maximum = ARTIST_RECOVERED_HYDRATION_MAX_BYTES): Hex {
    if (typeof value !== "string" || !isHexString(value, width ?? true)
      || width === undefined && value.length > maximum * 2 + 2) {
      throw Error("Expected bounded original bytes");
    }
    return value.toLowerCase() as Hex;
  }

  function nonzero(value: Hex): void {
    if (value === ZERO) throw Error("Expected nonzero original commitment");
  }

  function owner(value: ArtistHydrationOwnerIndex): ArtistHydrationOwnerIndex {
    if (!Number.isInteger(value) || value < 0 || value > 6) throw Error("Expected original owner index");
    return value;
  }

  function normalizeValue(type: ParamType, value: unknown): unknown {
    if (type.baseType === "array") {
      list(value, 16_384, type.arrayLength === -1 ? undefined : type.arrayLength!);
      return Object.freeze(value.map(item => normalizeValue(type.arrayChildren!, item)));
    }
    if (type.baseType === "tuple") {
      exact(value, type.components!.map(field => field.name));
      return Object.freeze(Object.fromEntries(type.components!.map(field => [field.name, normalizeValue(field, value[field.name])])));
    }
    if (type.type.startsWith("uint")) return uint(value, Number(type.type.slice(4)));
    if (type.type === "address") return address(value);
    if (type.type === "bool") {
      if (typeof value !== "boolean") throw Error("Expected boolean");
      return value;
    }
    if (type.type === "string") {
      if (typeof value !== "string") throw Error("Expected Unicode text");
      for (const char of value) {
        const code = char.codePointAt(0)!;
        if (code >= 0xd800 && code <= 0xdfff) throw Error("Expected Unicode scalar text");
      }
      if (toUtf8Bytes(value).length > ARTIST_RECOVERED_HYDRATION_MAX_BYTES) throw Error("Text exceeds transport capacity");
      return value;
    }
    return bytes(value, type.type === "bytes" ? undefined : Number(type.type.slice(5)));
  }

  function normalize<T>(tuple: string, value: T): T {
    const type = schemaType(tuple);
    if (multiple) {
      // Closed aggregate profile: budget the entire supplied tree before allocating copies.
      let size = 0;
      let nodes = 0;
      const visit = (t: ParamType, v: unknown, depth: number): void => {
        if (++nodes > 262_144 || depth > 64) throw Error("Recovered aggregate allocation capacity");
        size += 32;
        if (t.baseType === "array") {
          list(v, 16_384, t.arrayLength === -1 ? undefined : t.arrayLength!);
          for (let i = 0; i < v.length; i++) {
            const d = Object.getOwnPropertyDescriptor(v, String(i));
            if (!d || !("value" in d)) throw Error("Expected owned original data");
            visit(t.arrayChildren!, d.value, depth + 1);
          }
        } else if (t.baseType === "tuple") {
          exact(v, t.components!.map(c => c.name));
          for (const c of t.components!) {
            const d = Object.getOwnPropertyDescriptor(v, c.name);
            if (!d || !("value" in d)) throw Error("Expected owned original data");
            visit(c, d.value, depth + 1);
          }
        } else if (t.type === "bytes" || t.type === "string") {
          if (typeof v !== "string") throw Error("Expected original text or bytes");
          size += t.type === "bytes" ? Math.max(0, (v.length - 2) / 2) : v.length * 3;
        }
        if (size > ARTIST_RECOVERED_HYDRATION_MAX_PREPARED_BYTES) throw Error("Recovered aggregate allocation capacity");
      };
      visit(type, value, 0);
    }
    return normalizeValue(type, value) as T;
  }

  function plain(type: ParamType, value: any): unknown {
    if (type.baseType === "array") return Array.from(value, item => plain(type.arrayChildren!, item));
    if (type.baseType === "tuple") return Object.fromEntries(type.components!.map((field, i) => [field.name, plain(field, value[i])]));
    return value;
  }

  function encode(types: readonly string[], values: readonly unknown[]): Hex {
    return bytes(coder.encode(multiple ? types.map(schemaType) : types, values));
  }

  function decode<T>(tuple: string, raw: Hex, maximum = ARTIST_RECOVERED_HYDRATION_MAX_BYTES): T {
    const input = bytes(raw, undefined, maximum);
    const type = schemaType(tuple);
    const types = multiple ? [type] : [tuple];
    const result = normalizeValue(type, plain(type, coder.decode(types, input)[0])) as T;
    if (coder.encode(types, [result]) !== input) throw Error("Noncanonical recovered hydration bytes");
    return result;
  }

  function hash(types: readonly string[], values: readonly unknown[]): Hex {
    return keccak256(coder.encode(multiple ? types.map(schemaType) : types, values)) as Hex;
  }

  function same(type: string, a: unknown, b: unknown): boolean {
    return hash([type], [a]) === hash([type], [b]);
  }

  function artistRecoveredHydrationOwnerDomain(index: ArtistHydrationOwnerIndex): Hex {
    return id(`domain:${ownerNames[owner(index)]}`) as Hex;
  }

  function artistRecoveredHydrationOwnerTag(index: ArtistHydrationOwnerIndex): Hex {
    return id(`6529STREAM_ARTIST_RECOVERED_${tagNames[owner(index)]}_STATE_V1`) as Hex;
  }

  function normalizeArtistRecoveredHydrationCoordinates(
    value: ArtistRecoveredHydrationCoordinates,
  ): ArtistRecoveredHydrationCoordinates {
    exact(value, ["chainId", "registry", "coordinator"]);
    const chainId = uint(value.chainId);
    const registry = address(value.registry, true);
    const coordinator = address(value.coordinator, true);
    if (!chainId || registry === coordinator) throw Error("Invalid deployment coordinates");
    return Object.freeze({ chainId, registry, coordinator });
  }

  function normalizeArtistRecoveredHydrationCapability(
    value: ArtistRecoveredHydrationCapability,
  ): ArtistRecoveredHydrationCapability {
    return normalize(ARTIST_RECOVERED_HYDRATION_CAPABILITY_TUPLE, value);
  }

  /** Source and destination may advertise different supersets of the actual required features. */
  function validateArtistRecoveredHydrationCapability(
    value: ArtistRecoveredHydrationCapability,
    index: ArtistHydrationOwnerIndex,
    requiredFeatures: bigint,
  ): ArtistRecoveredHydrationCapability {
    const c = normalizeArtistRecoveredHydrationCapability(value);
    owner(index);
    uint(requiredFeatures);
    if (c.profile !== ARTIST_RECOVERED_HYDRATION_PROFILE || c.version !== 1n || c.ownerIndex !== BigInt(index)
      || c.ownerDomain !== artistRecoveredHydrationOwnerDomain(index)
      || c.checkpointSchema !== ARTIST_RECOVERED_HYDRATION_CHECKPOINT_SCHEMA
      || c.stateSchema !== artistRecoveredHydrationOwnerTag(index)
      || (requiredFeatures & ~knownFeatures) !== 0n || (requiredFeatures & c.supportedFeatures) !== requiredFeatures) {
      throw Error("Incompatible recovered capability");
    }
    return c;
  }

  /** Draft-only: zero expectedSemanticInventory is admitted solely for the original prepare view. */
  function normalizeArtistRecoveredHydrationRequestDraft(
    value: ArtistRecoveredHydrationRequest,
  ): ArtistRecoveredHydrationRequest {
    const r = normalize(ARTIST_RECOVERED_HYDRATION_REQUEST_TUPLE, value);
    const a = r.records.authority;
    if (multiple) {
      list(a.artistIds, 128); list(a.collections, 128);
      if (a.bindingIndex !== 0n || !a.artistIds.length || !a.collections.length
        || a.artistIds.length === 1 && a.collections.length === 1 || r.records.witnesses.length) {
        throw Error("MULTIPLE_BASE requires a complete plural graph without witness extensions");
      }
      for (let i = 0; i < a.artistIds.length; i++) {
        const artist = a.artistIds[i]!;
        if (artist === ZERO || i > 0 && BigInt(artist) <= BigInt(a.artistIds[i - 1]!)
          || !a.collections.some(c => c.artistId === artist)) throw Error("Invalid multiple Artist selectors");
      }
      let total = 0;
      for (let i = 0; i < a.collections.length; i++) {
        const c = a.collections[i]!;
        if (!c.collectionId || i > 0 && c.collectionId <= a.collections[i - 1]!.collectionId
          || !a.artistIds.includes(c.artistId)) throw Error("Invalid multiple collection selectors");
        list(c.policies, 128); total += c.policies.length;
        const seen = new Set<string>();
        for (const policy of c.policies) {
          nonzero(policy.phaseId); nonzero(policy.policyHash);
          const key = policy.phaseId + policy.policyHash;
          if (seen.has(key)) throw Error("Duplicate policy selector");
          seen.add(key);
        }
      }
      if (total > 128) throw Error("Multiple policy inventory exceeds capacity");
    } else {
      if (a.bindingIndex !== 0n || a.artistIds.length !== 1 || a.collections.length !== 1) {
        throw Error("Recovered profile requires one Artist, one collection, first binding");
      }
      nonzero(a.artistIds[0]!);
      const collection = a.collections[0]!;
      if (!collection.collectionId || collection.artistId !== a.artistIds[0]) throw Error("Invalid recovered collection");
      list(collection.policies, 128);
      const policies = new Set<string>();
      for (const policy of collection.policies) {
        nonzero(policy.phaseId);
        nonzero(policy.policyHash);
        const key = policy.phaseId + policy.policyHash;
        if (policies.has(key)) throw Error("Duplicate policy selector");
        policies.add(key);
      }
    }
    const collection = a.collections[0]!;
    let replayTotal = 0;
    for (let i = 0; i < 7; i++) {
      const index = i as ArtistHydrationOwnerIndex;
      validateArtistRecoveredHydrationCapability(r.expectedCapabilities[index], index, 0n);
      const checkpoint = a.expectedSource[index];
      if (checkpoint.schema !== ARTIST_RECOVERED_HYDRATION_CHECKPOINT_SCHEMA
        || checkpoint.ownerState.domainId !== artistRecoveredHydrationOwnerDomain(index)
        || checkpoint.replayCount > 8192n || checkpoint.nonceIndexCount > 128n) {
        throw Error("Invalid original source checkpoint");
      }
      list(a.replayOrigins[index], 8192, Number(checkpoint.replayCount));
      replayTotal += a.replayOrigins[index].length;
      const seen = new Set<string>();
      for (const origin of a.replayOrigins[index]) {
        const key = origin.surface + origin.scope;
        if (seen.has(key)) throw Error("Duplicate replay origin");
        seen.add(key);
      }
    }
    if (replayTotal > 8192) throw Error("Replay inventory exceeds capacity");
    list(r.records.witnesses, 1);
    for (const witness of r.records.witnesses) {
      if (witness.collectionId !== collection.collectionId || !(witness.economics.length + witness.attestations.length)) {
        throw Error("Invalid or empty witness wrapper");
      }
      list(witness.economics, 128);
      list(witness.attestations, 128);
      if (witness.economics.some(item => item.collectionId !== collection.collectionId)
        || witness.attestations.some(item => item.terms.collectionId !== collection.collectionId)) {
        throw Error("Witness collection mismatch");
      }
    }
    return r;
  }

  function normalizeArtistRecoveredHydrationRequest(
    value: ArtistRecoveredHydrationRequest,
  ): ArtistRecoveredHydrationRequest {
    const r = normalizeArtistRecoveredHydrationRequestDraft(value);
    nonzero(r.expectedSemanticInventory);
    return r;
  }

  function encodeArtistRecoveredHydrationRequest(value: ArtistRecoveredHydrationRequest): Hex {
    return encode([ARTIST_RECOVERED_HYDRATION_REQUEST_TUPLE], [normalizeArtistRecoveredHydrationRequest(value)]);
  }

  function decodeArtistRecoveredHydrationRequest(raw: Hex): ArtistRecoveredHydrationRequest {
    return normalizeArtistRecoveredHydrationRequest(decode(ARTIST_RECOVERED_HYDRATION_REQUEST_TUPLE, raw));
  }

  const CURRENT_ARTIST_RECOVERED_HYDRATION_ABI = Object.freeze([
    `function hydrateRecoveredArtistAuthority(${ARTIST_RECOVERED_HYDRATION_REQUEST_TUPLE} request) returns(bytes32)`,
  ]);

  const registryInterface = new Interface(CURRENT_ARTIST_RECOVERED_HYDRATION_ABI);

  const ARTIST_RECOVERED_HYDRATION_CAPABILITY_ID = registryInterface.getFunction("hydrateRecoveredArtistAuthority")!.selector as Hex;

  function prepareArtistRecoveredHydrationCall(
    registry: Address,
    caller: Address,
    request: ArtistRecoveredHydrationRequest,
  ): ArtistRecoveredHydrationCall {
    const target = address(registry, true);
    const actor = address(caller, true);
    const normalized = normalizeArtistRecoveredHydrationRequest(request);
    return Object.freeze({
      registry: target, caller: actor, request: normalized,
      profile: ARTIST_RECOVERED_HYDRATION_PROFILE,
      capabilityId: ARTIST_RECOVERED_HYDRATION_CAPABILITY_ID,
      call: Object.freeze({ to: target, value: 0n, data: bytes(registryInterface.encodeFunctionData("hydrateRecoveredArtistAuthority", [normalized])) }),
      factsVerified: false,
    });
  }

  function normalizeArtistRecoveredHydrationCall(value: ArtistRecoveredHydrationCall): ArtistRecoveredHydrationCall {
    exact(value, ["registry", "caller", "request", "profile", "capabilityId", "call", "factsVerified"]);
    const rebuilt = prepareArtistRecoveredHydrationCall(value.registry, value.caller, value.request);
    exact(value.call, ["to", "value", "data"]);
    if (value.profile !== rebuilt.profile || value.capabilityId !== rebuilt.capabilityId || value.factsVerified !== false
      || address(value.call.to) !== rebuilt.call.to || value.call.value !== 0n || bytes(value.call.data) !== rebuilt.call.data) {
      throw Error("Recovered call differs from reconstructed request");
    }
    return rebuilt;
  }

  function normalizeArtistRecoveredHydrationOriginEnvironment(
    value: ArtistRecoveredHydrationOriginEnvironment,
  ): ArtistRecoveredHydrationOriginEnvironment {
    return normalize(ARTIST_RECOVERED_HYDRATION_ORIGIN_ENVIRONMENT_TUPLE, value);
  }

  function artistRecoveredHydrationOriginHash(value: ArtistRecoveredHydrationOriginEnvironment): Hex {
    return hash(["bytes32", "uint16", ARTIST_RECOVERED_HYDRATION_ORIGIN_ENVIRONMENT_TUPLE], [
      id("6529STREAM_ARTIST_RECOVERED_HYDRATION_ORIGIN_V1"), 1n,
      normalizeArtistRecoveredHydrationOriginEnvironment(value),
    ]);
  }

  function artistRecoveredHydrationReplayKey(
    environment: ArtistRecoveredHydrationOriginEnvironment,
    index: ArtistHydrationOwnerIndex,
    logical: { readonly surface: Hex; readonly scope: Hex },
  ): Hex {
    const e = normalizeArtistRecoveredHydrationOriginEnvironment(environment);
    exact(logical, ["surface", "scope"]);
    return hash(
      ["bytes32", "uint256", "address", "address", "address", "address", "bytes32", "bytes32", "bytes32"],
      [id("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"), e.chainId, e.registry, e.coordinator, e.archive,
        e.owners[owner(index)], artistRecoveredHydrationOwnerDomain(index), bytes(logical.surface, 32), bytes(logical.scope, 32)],
    );
  }

  function originBase(
    origins: readonly ArtistRecoveredHydrationOriginEnvironment[],
    eras: readonly { readonly originHash: Hex; readonly priorImportCommitment: Hex }[],
  ): void {
    list(origins, 16);
    list(eras, 16, origins.length);
    if (!origins.length) throw Error("Empty original provenance");
    const hashes = new Set<Hex>();
    const registries = new Set<Address>();
    const coordinators = new Set<Address>();
    for (let i = 0; i < origins.length; i++) {
      const e = origins[i]!;
      if (!e.chainId || e.chainId !== origins[0]!.chainId || e.core !== origins[0]!.core || e.manager !== origins[0]!.manager) {
        throw Error("Origin deployment mismatch");
      }
      for (const a of [e.registry, e.coordinator, e.archive, e.core, e.manager]) address(a, true);
      nonzero(e.suiteConfigurationHash);
      const h = artistRecoveredHydrationOriginHash(e);
      if (h !== eras[i]!.originHash || hashes.has(h) || registries.has(e.registry) || coordinators.has(e.coordinator)
        || (i === 0 ? eras[i]!.priorImportCommitment !== ZERO : eras[i]!.priorImportCommitment === ZERO)) {
        throw Error("Invalid or repeated origin era");
      }
      if (new Set(e.owners).size !== 7) throw Error("Owner addresses must be distinct");
      hashes.add(h); registries.add(e.registry); coordinators.add(e.coordinator);
    }
  }

  function ownerEra(
    origin: ArtistRecoveredHydrationOriginEnvironment,
    era: ArtistRecoveredHydrationOwnerEra,
    index: ArtistHydrationOwnerIndex,
    first: boolean,
  ): void {
    address(origin.owners[index], true);
    nonzero(origin.ownerCodeHashes[index]);
    const c = era.checkpoint;
    if (c.schema !== ARTIST_RECOVERED_HYDRATION_CHECKPOINT_SCHEMA
      || c.ownerState.domainId !== artistRecoveredHydrationOwnerDomain(index)
      || era.lowerRevision > c.ownerState.revision
      || (first ? era.lowerRevision !== 0n : era.lowerRevision === 0n)) {
      throw Error("Invalid owner era checkpoint");
    }
    nonzero(c.ownerState.stateRoot);
    nonzero(c.ownerState.recordChainTip);
  }

  function pointRank(
    origins: readonly ArtistRecoveredHydrationOriginEnvironment[],
    eras: readonly ArtistRecoveredHydrationOwnerEra[],
    index: ArtistHydrationOwnerIndex,
    point: ArtistRecoveredHydrationPoint,
  ): number {
    if (point.ownerIndex !== BigInt(index) || !point.ownerRevision || point.environmentHash === ZERO
      || !origins.length || origins.length > 17 || origins.length !== eras.length) {
      throw Error("Invalid chronology point");
    }
    const matches = eras.map((era, i) => era.originHash === point.environmentHash ? i : -1).filter(i => i >= 0);
    if (matches.length !== 1) throw Error("Unknown or ambiguous point origin");
    const i = matches[0]!;
    const e = origins[i]!;
    const c = eras[i]!.checkpoint;
    if (artistRecoveredHydrationOriginHash(e) !== point.environmentHash || e.owners[index] === ZeroAddress
      || e.ownerCodeHashes[index] === ZERO || c.schema !== ARTIST_RECOVERED_HYDRATION_CHECKPOINT_SCHEMA
      || c.ownerState.domainId !== artistRecoveredHydrationOwnerDomain(index) || point.ownerRevision > c.ownerState.revision) {
      throw Error("Point exceeds original owner checkpoint");
    }
    return i;
  }

  function validateOwnerProvenance(
    p: ArtistRecoveredHydrationOwnerProvenance,
    index: ArtistHydrationOwnerIndex,
  ): void {
    owner(index);
    originBase(p.origins, p.eras);
    list(p.journal, 4096);
    list(p.aliases, 8192);
    let cursor = 0;
    for (let i = 0; i < p.eras.length; i++) {
      const era = p.eras[i]!;
      ownerEra(p.origins[i]!, era, index, i === 0);
      if (era.nativeCount > 4096n) throw Error("Native inventory exceeds capacity");
      let previous = era.lowerRevision;
      for (let j = 0; j < Number(era.nativeCount); j++) {
        const entry = p.journal[cursor++];
        if (!entry || entry.position.nativeIndex !== BigInt(j)
          || entry.position.point.environmentHash !== era.originHash
          || entry.position.point.ownerIndex !== BigInt(index)
          || entry.position.point.ownerRevision <= era.lowerRevision
          || entry.position.point.ownerRevision < previous) throw Error("Incomplete original native order");
        pointRank(p.origins, p.eras, index, entry.position.point);
        const r = entry.receipt;
        if (!r.operation || r.operation > 61n || r.operation === 60n
          || r.recordHash === ZERO || r.artistId === ZERO && r.collectionId === 0n) {
          throw Error("Invalid original native receipt");
        }
        previous = entry.position.point.ownerRevision;
      }
    }
    if (cursor !== p.journal.length) throw Error("Trailing native inventory");
    const counts = p.eras.map(() => 0n);
    let previousKey = 0n;
    for (const alias of p.aliases) {
      const keyEra = p.eras.findIndex(era => era.originHash === alias.originHash);
      const mutationEra = pointRank(p.origins, p.eras, index, alias.admittedAt);
      if (keyEra < 0 || mutationEra > keyEra || alias.ownerIndex !== BigInt(index)
        || BigInt(alias.originalKey) <= previousKey || alias.cell.status === 0n
        || alias.cell.touchedRevision !== alias.admittedAt.ownerRevision
        || alias.originalKey !== artistRecoveredHydrationReplayKey(p.origins[keyEra]!, index, { surface: alias.surface, scope: alias.scope })) {
        throw Error("Invalid original replay alias or order");
      }
      previousKey = BigInt(alias.originalKey);
      counts[keyEra] = counts[keyEra]! + 1n;
    }
    if (counts.some((count, i) => count !== p.eras[i]!.checkpoint.replayCount)) throw Error("Incomplete replay aliases");
  }

  function normalizeArtistRecoveredHydrationOwnerProvenance(
    value: ArtistRecoveredHydrationOwnerProvenance,
    index: ArtistHydrationOwnerIndex,
  ): ArtistRecoveredHydrationOwnerProvenance {
    const p = normalize(ARTIST_RECOVERED_HYDRATION_OWNER_PROVENANCE_TUPLE, value);
    validateOwnerProvenance(p, index);
    return p;
  }

  function artistRecoveredHydrationOwnerProvenance(
    value: ArtistRecoveredHydrationProvenance,
    index: ArtistHydrationOwnerIndex,
  ): ArtistRecoveredHydrationOwnerProvenance {
    const p = normalize(ARTIST_RECOVERED_HYDRATION_PROVENANCE_TUPLE, value);
    owner(index);
    return normalizeArtistRecoveredHydrationOwnerProvenance({
      origins: p.origins,
      eras: p.eras.map(era => ({ originHash: era.originHash, checkpoint: era.checkpoints[index], nativeCount: era.nativeCounts[index],
        lowerRevision: era.lowerRevisions[index], priorImportCommitment: era.priorImportCommitment })),
      journal: p.journals[index], aliases: p.aliases[index],
    }, index);
  }

  function normalizeArtistRecoveredHydrationProvenance(
    value: ArtistRecoveredHydrationProvenance,
  ): ArtistRecoveredHydrationProvenance {
    const p = normalize(ARTIST_RECOVERED_HYDRATION_PROVENANCE_TUPLE, value);
    if (p.journals.reduce((n, rows) => n + rows.length, 0) > 4096
      || p.aliases.reduce((n, rows) => n + rows.length, 0) > 8192) throw Error("Total provenance capacity exceeded");
    for (let i = 0; i < 7; i++) artistRecoveredHydrationOwnerProvenance(p, i as ArtistHydrationOwnerIndex);
    return p;
  }

  function artistRecoveredHydrationProvenanceHash(value: ArtistRecoveredHydrationProvenance): Hex {
    return hash(["bytes32", "uint16", ARTIST_RECOVERED_HYDRATION_PROVENANCE_TUPLE], [
      id("6529STREAM_ARTIST_RECOVERED_HYDRATION_PROVENANCE_V1"), 1n, normalizeArtistRecoveredHydrationProvenance(value),
    ]);
  }

  function artistRecoveredHydrationOwnerProvenanceHash(
    value: ArtistRecoveredHydrationOwnerProvenance,
    index: ArtistHydrationOwnerIndex,
  ): Hex {
    return hash(["bytes32", "uint16", "bytes32", ARTIST_RECOVERED_HYDRATION_OWNER_PROVENANCE_TUPLE], [
      id("6529STREAM_ARTIST_RECOVERED_HYDRATION_OWNER_PROVENANCE_V1"), 1n, artistRecoveredHydrationOwnerDomain(index),
      normalizeArtistRecoveredHydrationOwnerProvenance(value, index),
    ]);
  }

  function artistRecoveredHydrationAliasesHash(
    value: readonly ArtistRecoveredHydrationReplayAlias[],
    index: ArtistHydrationOwnerIndex,
  ): Hex {
    list(value, 8192);
    return hash(["bytes32", "uint16", "bytes32", `${ARTIST_RECOVERED_HYDRATION_REPLAY_ALIAS_TUPLE}[]`], [
      id("6529STREAM_ARTIST_RECOVERED_HYDRATION_ALIASES_V1"), 1n, artistRecoveredHydrationOwnerDomain(index),
      normalize(`${ARTIST_RECOVERED_HYDRATION_REPLAY_ALIAS_TUPLE}[]`, value),
    ]);
  }

  /** Chronology is owner-local and follows era order, not incomparable cross-deployment revisions. */
  function compareArtistRecoveredHydrationPoints(
    provenance: ArtistRecoveredHydrationOwnerProvenance,
    a: ArtistRecoveredHydrationPoint,
    b: ArtistRecoveredHydrationPoint,
  ): -1 | 0 | 1 {
    const p = normalize(ARTIST_RECOVERED_HYDRATION_OWNER_PROVENANCE_TUPLE, provenance);
    const left = normalize(ARTIST_RECOVERED_HYDRATION_POINT_TUPLE, a);
    const right = normalize(ARTIST_RECOVERED_HYDRATION_POINT_TUPLE, b);
    if (left.ownerIndex !== right.ownerIndex || left.ownerIndex > 6n) throw Error("Points require the same original owner");
    const index = Number(left.ownerIndex) as ArtistHydrationOwnerIndex;
    const ai = pointRank(p.origins, p.eras, index, left);
    const bi = pointRank(p.origins, p.eras, index, right);
    return ai < bi || ai === bi && left.ownerRevision < right.ownerRevision ? -1
      : ai > bi || ai === bi && left.ownerRevision > right.ownerRevision ? 1 : 0;
  }

  function normalizeArtistRecoveredHydrationNonceInventory(
    value: readonly ArtistRecoveredHydrationNonceInventory[],
    checkpoint: ArtistHydrationCheckpoint,
  ): readonly ArtistRecoveredHydrationNonceInventory[] {
    const c = normalize(ARTIST_HYDRATION_CHECKPOINT_TUPLE, checkpoint);
    const rows = normalize(`${ARTIST_RECOVERED_HYDRATION_NONCE_INVENTORY_TUPLE}[]`, value);
    list(rows, 128, Number(c.nonceIndexCount));
    if (c.schema !== ARTIST_RECOVERED_HYDRATION_CHECKPOINT_SCHEMA) throw Error("Wrong nonce checkpoint schema");
    const keys = new Set<string>();
    for (const row of rows) {
      const { kind, key, prefixCount } = row.index;
      if (kind < 1n || kind > 5n || key === ZERO || prefixCount === 0n || prefixCount > 256n) throw Error("Invalid nonce index");
      const identity = `${kind}:${key}`;
      if (keys.has(identity)) throw Error("Duplicate nonce index");
      keys.add(identity);
      list(row.words, 256, Number(prefixCount));
      const prefixes = new Set<bigint>();
      for (const word of row.words) {
        if (prefixes.has(word.prefix) || word.exhausted !== row.words[0]!.exhausted) throw Error("Invalid nonce prefixes");
        prefixes.add(word.prefix);
      }
    }
    return rows;
  }

  function normalizeArtistRecoveredHydrationPublications(
    value: readonly ArtistRecoveredHydrationPublication[],
    index: ArtistHydrationOwnerIndex,
  ): readonly ArtistRecoveredHydrationPublication[] {
    owner(index);
    const rows = normalize(`${ARTIST_RECOVERED_HYDRATION_PUBLICATION_TUPLE}[]`, value);
    list(rows, 16_384);
    if (![2, 4, 6].includes(index) && rows.length) throw Error("Owner has no original publication catalog");
    const keys = new Set<Hex>();
    for (const row of rows) {
      address(row.pointer, true); nonzero(row.payloadType); nonzero(row.payloadHash);
      const key = hash(["bytes32", "bytes32"], [row.payloadType, row.payloadHash]);
      if (keys.has(key)) throw Error("Duplicate publication content key");
      keys.add(key);
    }
    return rows;
  }

  function normalizeArtistRecoveredHydrationOwnerPayload(
    value: ArtistRecoveredHydrationOwnerPayload,
    index: ArtistHydrationOwnerIndex,
  ): ArtistRecoveredHydrationOwnerPayload {
    const p = normalize(ARTIST_RECOVERED_HYDRATION_OWNER_PAYLOAD_TUPLE, value);
    normalizeArtistRecoveredHydrationOwnerProvenance(p.provenance, index);
    normalizeArtistRecoveredHydrationNonceInventory(p.nonces, p.provenance.eras.at(-1)!.checkpoint);
    normalizeArtistRecoveredHydrationPublications(p.publications, index);
    if (p.semanticState === "0x") throw Error("Empty semantic state");
    return p;
  }

  function validateHeader(
    h: ArtistRecoveredHydrationExportHeader,
    p: ArtistRecoveredHydrationOwnerPayload,
    index: ArtistHydrationOwnerIndex,
  ): void {
    const last = p.provenance.eras.at(-1)!;
    if (h.profile !== ARTIST_RECOVERED_HYDRATION_PROFILE || h.version !== 1n || h.ownerIndex !== BigInt(index)
      || h.sourceOrigin !== last.originHash || h.priorImportCommitment !== last.priorImportCommitment
      || (p.provenance.eras.length === 1 ? h.priorImportCommitment !== ZERO : h.priorImportCommitment === ZERO)
      || h.semanticInventory !== keccak256(p.semanticState)
      || h.provenanceCommitment !== artistRecoveredHydrationOwnerProvenanceHash(p.provenance, index)
      || h.replayAliasesCommitment !== artistRecoveredHydrationAliasesHash(p.provenance.aliases, index)
      || h.semanticRecordCount !== BigInt(p.provenance.journal.length)
      || h.replayAliasCount !== BigInt(p.provenance.aliases.length) || h.eraCount !== BigInt(p.provenance.eras.length)
      || (h.requiredFeatures & ~knownFeatures) !== 0n || multiple && (h.requiredFeatures & 262144n) === 0n || h.eraCount > 1n && (h.requiredFeatures & 16n) === 0n) {
      throw Error("Owner header differs from complete payload");
    }
  }

  function encodeArtistRecoveredHydrationOwnerPayload(
    value: ArtistRecoveredHydrationOwnerPayload,
    index: ArtistHydrationOwnerIndex,
    requiredFeatures: bigint,
  ): Hex {
    const p = normalizeArtistRecoveredHydrationOwnerPayload(value, index);
    const last = p.provenance.eras.at(-1)!;
    const header: ArtistRecoveredHydrationExportHeader = {
      profile: ARTIST_RECOVERED_HYDRATION_PROFILE, version: 1n, ownerIndex: BigInt(index),
      sourceOrigin: last.originHash, priorImportCommitment: last.priorImportCommitment,
      semanticInventory: keccak256(p.semanticState) as Hex,
      provenanceCommitment: artistRecoveredHydrationOwnerProvenanceHash(p.provenance, index),
      replayAliasesCommitment: artistRecoveredHydrationAliasesHash(p.provenance.aliases, index),
      requiredFeatures: uint(requiredFeatures), semanticRecordCount: BigInt(p.provenance.journal.length),
      replayAliasCount: BigInt(p.provenance.aliases.length), eraCount: BigInt(p.provenance.eras.length),
    };
    validateHeader(header, p, index);
    const payload = encode(["bytes32", "uint16", ARTIST_RECOVERED_HYDRATION_OWNER_PAYLOAD_TUPLE], [ARTIST_RECOVERED_HYDRATION_PAYLOAD_SCHEMA, 1n, p]);
    return encode(["bytes32", "uint16", ARTIST_RECOVERED_HYDRATION_ENVELOPE_TUPLE], [artistRecoveredHydrationOwnerTag(index), 1n, { header, payload }]);
  }

  function decodeArtistRecoveredHydrationOwnerPayload(
    raw: Hex,
    index: ArtistHydrationOwnerIndex,
  ): { readonly header: ArtistRecoveredHydrationExportHeader; readonly payload: ArtistRecoveredHydrationOwnerPayload } {
    const input = bytes(raw);
    const outerTypes = ["bytes32", "uint16", ARTIST_RECOVERED_HYDRATION_ENVELOPE_TUPLE];
    const outer = coder.decode(outerTypes, input);
    if (outer[0] !== artistRecoveredHydrationOwnerTag(index) || outer[1] !== 1n || coder.encode(outerTypes, outer) !== input) {
      throw Error("Noncanonical owner envelope");
    }
    const e = normalize(ARTIST_RECOVERED_HYDRATION_ENVELOPE_TUPLE, plain(ParamType.from(ARTIST_RECOVERED_HYDRATION_ENVELOPE_TUPLE), outer[2]) as ArtistRecoveredHydrationEnvelope);
    const innerTypes = ["bytes32", "uint16", ARTIST_RECOVERED_HYDRATION_OWNER_PAYLOAD_TUPLE];
    const inner = coder.decode(innerTypes, bytes(e.payload));
    if (inner[0] !== ARTIST_RECOVERED_HYDRATION_PAYLOAD_SCHEMA || inner[1] !== 1n || coder.encode(innerTypes, inner) !== e.payload) {
      throw Error("Noncanonical owner payload");
    }
    const payload = normalizeArtistRecoveredHydrationOwnerPayload(
      plain(ParamType.from(ARTIST_RECOVERED_HYDRATION_OWNER_PAYLOAD_TUPLE), inner[2]) as ArtistRecoveredHydrationOwnerPayload, index,
    );
    validateHeader(e.header, payload, index);
    return Object.freeze({ header: e.header, payload });
  }

  function normalizeArtistRecoveredHydrationTimingCheckpoint(
    value: ArtistRecoveredHydrationTimingCheckpoint,
  ): ArtistRecoveredHydrationTimingCheckpoint {
    const c = normalize(ARTIST_RECOVERED_HYDRATION_TIMING_CHECKPOINT_TUPLE, value);
    if (c.schema !== id("6529STREAM_ARTIST_RECOVERED_TIMING_INVENTORY_V1") || c.version !== 1n || c.count > 1024n) {
      throw Error("Invalid original timing checkpoint");
    }
    return c;
  }

  function normalizeArtistRecoveredHydrationExternalGuards(
    value: ArtistRecoveredHydrationExternalGuards,
  ): ArtistRecoveredHydrationExternalGuards {
    const s = normalize(ARTIST_RECOVERED_HYDRATION_EXTERNAL_GUARDS_TUPLE, value);
    if (s.schema !== id("6529STREAM_ARTIST_RECOVERED_EXTERNAL_GUARDS_V1") || s.artistId === ZERO || s.provenanceCommitment === ZERO
      || s.actions.length > 8192 || s.finality.length + s.entropy.length > 4096) throw Error("Invalid external guard inventory");
    for (const action of s.actions) {
      if (action.origin.ownerIndex !== 2n || action.facts.status === 0n || action.facts.status > 5n
        || action.facts.actionClass !== 2n || action.facts.callHash !== action.witness.callsHash
        || action.facts.notBefore !== action.witness.notBefore || action.facts.expiresAfter !== action.witness.expiresAfter) {
        throw Error("External action witness mismatch");
      }
    }
    for (const f of s.finality) {
      if (f.origin.point.ownerIndex !== 2n || f.target.scope.scopeType > 4n || f.record.scope.scopeType > 4n
        || f.record.evidence.artistEvidenceKind > 2n || f.action.status > 5n) throw Error("Invalid finality guard enum or owner");
    }
    for (const e of s.entropy) if (e.origin.point.ownerIndex !== 2n) throw Error("Invalid entropy guard owner");
    return s;
  }

  /** Validates complete structural partitions and commitments; opaque semantic states still require the original producer. */
  function normalizeArtistRecoveredHydrationPrepared(
    value: ArtistRecoveredHydrationPrepared,
  ): ArtistRecoveredHydrationPrepared {
    const p = normalize(ARTIST_RECOVERED_HYDRATION_PREPARED_TUPLE, value);
    const c = p.admission;
    const provenance = normalizeArtistRecoveredHydrationProvenance(c.provenance);
    const last = provenance.origins.at(-1)!;
    if (c.prior !== last.registry || c.sourceCoordinator !== last.coordinator
      || c.source.registry !== last.registry || c.source.archive !== last.archive || c.source.core !== last.core
      || c.source.mintManager !== last.manager || !same("address[7]", c.source.owners, last.owners)
      || hash([ARTIST_HYDRATION_SUITE_TUPLE], [c.source]) !== last.suiteConfigurationHash) {
      throw Error("Certificate source suite differs from original origin");
    }
    const artist = c.artists[0]!;
    if (multiple) {
      list(c.artists, 128); list(c.collections, 128);
      if (!c.artists.length || !c.collections.length || c.artists.length === 1 && c.collections.length === 1) {
        throw Error("Incomplete plural recovered graph");
      }
      const registrations = c.artists.map(() => 0);
      const artistRecords: Hex[][] = c.artists.map(() => []);
      const collectionRecords: Hex[][] = c.collections.map(() => []);
      for (let i = 0; i < c.artists.length; i++) {
        const q = c.artists[i]!;
        if (q.artistId === ZERO || q.collectionId !== 0n || q.bindingHash !== ZERO || q.policies.length
          || i > 0 && BigInt(q.artistId) <= BigInt(c.artists[i - 1]!.artistId)
          || !c.collections.some(row => row.artistId === q.artistId)) throw Error("Invalid complete Artist partition");
      }
      let policies = 0;
      for (let i = 0; i < c.collections.length; i++) {
        const q = c.collections[i]!;
        if (!q.collectionId || q.bindingHash === ZERO || i > 0 && q.collectionId <= c.collections[i - 1]!.collectionId
          || !c.artists.some(row => row.artistId === q.artistId)) throw Error("Invalid complete collection partition");
        list(q.policies, 128); policies += q.policies.length;
        const seen = new Set<string>();
        for (const policy of q.policies) {
          nonzero(policy.phaseId); nonzero(policy.policyHash);
          const key = policy.phaseId + policy.policyHash;
          if (seen.has(key)) throw Error("Duplicate policy selector");
          seen.add(key);
        }
      }
      if (policies > 128) throw Error("Multiple policy inventory exceeds capacity");
      const first = c.collections[0]!;
      const anchorArtist = c.artists.find(row => row.artistId === first.artistId)!;
      if (!same(ARTIST_HYDRATION_QUERY_TUPLE, p.query, { ...first, records: anchorArtist.records })) throw Error("Multiple anchor differs from original first collection");
      for (let ownerIndex = 0; ownerIndex < 7; ownerIndex++) {
        for (const entry of provenance.journals[ownerIndex]!) {
          const r = entry.receipt;
          const at = c.artists.findIndex(row => row.artistId === r.artistId);
          const ci = r.collectionId ? c.collections.findIndex(row => row.collectionId === r.collectionId) : -1;
          if (at < 0 || r.collectionId && (ci < 0 || c.collections[ci]!.artistId !== r.artistId)) throw Error("Native occurrence outside multiple graph");
          if (ownerIndex === 2 && r.operation === 1n) {
            if (r.recordHash !== r.artistId || r.collectionId) throw Error("Invalid original registration occurrence");
            registrations[at] = registrations[at]! + 1;
          }
          artistRecords[at]!.push(r.recordHash);
          if (ci >= 0) collectionRecords[ci]!.push(r.recordHash);
        }
      }
      for (let i = 0; i < c.artists.length; i++) if (registrations[i] !== 1
        || !same("bytes32[]", artistRecords[i], c.artists[i]!.records)) throw Error("Incomplete original Artist occurrences");
      for (let i = 0; i < c.collections.length; i++) if (!collectionRecords[i]!.length
        || !same("bytes32[]", collectionRecords[i], c.collections[i]!.records)) throw Error("Incomplete original collection occurrences");
    } else {
      list(c.artists, 1, 1);
      list(c.collections, 1, 1);
      const artist = c.artists[0]!;
      const collection = c.collections[0]!;
      nonzero(artist.artistId);
      if (artist.collectionId !== 0n || artist.bindingHash !== ZERO || artist.policies.length !== 0
        || !collection.collectionId || collection.bindingHash === ZERO || collection.artistId !== artist.artistId
        || p.query.artistId !== artist.artistId || p.query.collectionId !== collection.collectionId
        || p.query.bindingHash !== collection.bindingHash
        || !same(`${ARTIST_HYDRATION_QUERY_TUPLE}`, p.query, { ...collection, records: artist.records })) {
        throw Error("Recovered query partition mismatch");
      }
      const artistRecords: Hex[] = [];
      const collectionRecords: Hex[] = [];
      let registrations = 0;
      for (let i = 0; i < 7; i++) {
        for (const entry of provenance.journals[i]!) {
          const r = entry.receipt;
          if (r.artistId !== artist.artistId || r.collectionId !== 0n && r.collectionId !== collection.collectionId) {
            throw Error("Native occurrence outside selected recovered graph");
          }
          if (i === 2 && r.operation === 1n) {
            if (r.recordHash !== artist.artistId || r.collectionId !== 0n) throw Error("Invalid original registration occurrence");
            registrations++;
          }
          artistRecords.push(r.recordHash);
          if (r.collectionId) collectionRecords.push(r.recordHash);
        }
      }
      if (registrations !== 1 || !collectionRecords.length
        || !same("bytes32[]", artistRecords, artist.records) || !same("bytes32[]", collectionRecords, collection.records)) {
        throw Error("Incomplete original artist/collection occurrence partition");
      }
    }
    normalizeArtistRecoveredHydrationTimingCheckpoint(p.timing);
    normalizeArtistRecoveredHydrationExternalGuards(p.externalGuards);
    if (p.externalGuards.artistId !== artist.artistId || p.externalGuards.provenanceCommitment !== artistRecoveredHydrationProvenanceHash(provenance)) {
      throw Error("External guards belong to another inventory");
    }
    let features: bigint | undefined;
    for (let i = 0; i < 7; i++) {
      const index = i as ArtistHydrationOwnerIndex;
      if (c.before_[index].domainId !== artistRecoveredHydrationOwnerDomain(index)
        || c.before_[index].revision !== (index === 2 ? (multiple ? 1n + BigInt(c.artists.length + c.collections.length) : 3n) : 0n)) {
        throw Error("Destination before snapshot is not the original two-lane admission state");
      }
      const data = p.data[index];
      const decoded = decodeArtistRecoveredHydrationOwnerPayload(data.typedState, index);
      if (!same(ARTIST_RECOVERED_HYDRATION_OWNER_PROVENANCE_TUPLE, decoded.payload.provenance, artistRecoveredHydrationOwnerProvenance(provenance, index))) {
        throw Error("Owner payload provenance is not the complete certificate slice");
      }
      if (features !== undefined && decoded.header.requiredFeatures !== features) throw Error("Owner feature requirements disagree");
      features = decoded.header.requiredFeatures;
      const expected = provenance.eras.at(-1)!.checkpoints[index];
      if (data.nonces.length || data.origins.length !== Number(expected.replayCount)
        || data.sourceKeys.length !== data.origins.length || data.cells.length !== data.origins.length) {
        throw Error("Original guard inventory length mismatch");
      }
      const seen = new Set<Hex>();
      const aliases = new Map(provenance.aliases[index].map(alias => [alias.originalKey, alias]));
      for (let j = 0; j < data.origins.length; j++) {
        const key = artistRecoveredHydrationReplayKey(last, index, data.origins[j]!);
        const alias = aliases.get(key);
        if (seen.has(key) || data.sourceKeys[j] !== key || !alias || alias.originHash !== provenance.eras.at(-1)!.originHash
          || alias.surface !== data.origins[j]!.surface || alias.scope !== data.origins[j]!.scope
          || !same(ARTIST_HYDRATION_REPLAY_CELL_TUPLE, alias.cell, data.cells[j])) {
          throw Error("Guard inventory differs from exact current-origin aliases");
        }
        seen.add(key);
      }
    }
    return p;
  }

  function encodeArtistRecoveredHydrationPrepared(value: ArtistRecoveredHydrationPrepared): Hex {
    return bytes(coder.encode([ARTIST_RECOVERED_HYDRATION_PREPARED_TUPLE], [normalizeArtistRecoveredHydrationPrepared(value)]),
      undefined, ARTIST_RECOVERED_HYDRATION_MAX_PREPARED_BYTES);
  }

  function decodeArtistRecoveredHydrationPrepared(raw: Hex): ArtistRecoveredHydrationPrepared {
    return normalizeArtistRecoveredHydrationPrepared(decode(ARTIST_RECOVERED_HYDRATION_PREPARED_TUPLE, raw,
      ARTIST_RECOVERED_HYDRATION_MAX_PREPARED_BYTES));
  }

  function artistRecoveredHydrationSemanticInventory(value: ArtistRecoveredHydrationPrepared): Hex {
    const p = normalizeArtistRecoveredHydrationPrepared(value);
    return hash([
      "bytes32", "uint16", "bytes32", ARTIST_HYDRATION_QUERY_TUPLE, `${ARTIST_HYDRATION_OWNER_DATA_TUPLE}[7]`,
      ARTIST_RECOVERED_HYDRATION_TIMING_CHECKPOINT_TUPLE, ARTIST_RECOVERED_HYDRATION_EXTERNAL_GUARDS_TUPLE,
    ], [id("6529STREAM_ARTIST_RECOVERED_SEMANTIC_INVENTORY_V1"), 1n,
      artistRecoveredHydrationProvenanceHash(p.admission.provenance), p.query, p.data, p.timing, p.externalGuards]);
  }

  function joinRequest(
    request: ArtistRecoveredHydrationRequest,
    p: ArtistRecoveredHydrationPrepared,
  ): void {
    const a = request.records.authority;
    const c = p.admission;
    const selectorsMatch = multiple
      ? same("bytes32[]", a.artistIds, c.artists.map(row => row.artistId))
        && a.collections.length === c.collections.length && a.collections.every((row, i) => {
          const q = c.collections[i]!;
          return row.artistId === q.artistId && row.collectionId === q.collectionId
            && same(`${ARTIST_HYDRATION_POLICY_TUPLE}[]`, row.policies, q.policies);
        })
      : a.artistIds[0] === p.query.artistId && a.collections[0]!.collectionId === p.query.collectionId
        && same(`${ARTIST_HYDRATION_POLICY_TUPLE}[]`, a.collections[0]!.policies, p.query.policies);
    if (!selectorsMatch
      || !same(`${ARTIST_HYDRATION_CHECKPOINT_TUPLE}[7]`, a.expectedSource, c.provenance.eras.at(-1)!.checkpoints)
      || request.expectedSourceImportCommitment !== c.provenance.eras.at(-1)!.priorImportCommitment
      || request.expectedSemanticInventory !== artistRecoveredHydrationSemanticInventory(p)) {
      throw Error("Final request does not commit the complete certificate");
    }
    const economicsCount = c.provenance.journals[6].filter(entry => entry.receipt.operation === 15n).length;
    const attestationCount = c.provenance.journals[4].filter(entry => entry.receipt.operation === 24n).length;
    const witness = request.records.witnesses[0];
    if (economicsCount + attestationCount === 0 ? request.records.witnesses.length !== 0
      : !witness || witness.economics.length !== economicsCount || witness.attestations.length !== attestationCount) {
      throw Error("Missing or partial original witness family");
    }
    if (witness?.economics.some(item => item.resolver !== c.source.primaryResolver && item.resolver !== c.source.royaltyResolver)) {
      throw Error("Economics witness references another resolver");
    }
    for (let i = 0; i < 7; i++) {
      const index = i as ArtistHydrationOwnerIndex;
      const { header } = decodeArtistRecoveredHydrationOwnerPayload(p.data[index].typedState, index);
      validateArtistRecoveredHydrationCapability(request.expectedCapabilities[index], index, header.requiredFeatures);
      if (!same(`tuple(bytes32 surface,bytes32 scope)[]`, a.replayOrigins[index], p.data[index].origins)) {
        throw Error("Submitted replay preimages differ from original insertion order");
      }
    }
  }

  function artistRecoveredHydrationCommitment(
    coordinates: ArtistRecoveredHydrationCoordinates,
    request: ArtistRecoveredHydrationRequest,
    prepared: ArtistRecoveredHydrationPrepared,
  ): Hex {
    const e = normalizeArtistRecoveredHydrationCoordinates(coordinates);
    const r = normalizeArtistRecoveredHydrationRequest(request);
    const p = normalizeArtistRecoveredHydrationPrepared(prepared);
    joinRequest(r, p);
    if (e.chainId !== p.admission.provenance.origins[0]!.chainId) throw Error("Destination chain mismatch");
    return hash([
      "bytes32", "uint16", "uint256", "address", "address", "address", "address",
      ARTIST_RECOVERED_HYDRATION_REQUEST_TUPLE, `${ARTIST_HYDRATION_QUERY_TUPLE}[]`, `${ARTIST_HYDRATION_QUERY_TUPLE}[]`,
      ARTIST_HYDRATION_QUERY_TUPLE, `${ARTIST_HYDRATION_OWNER_DATA_TUPLE}[7]`,
      ARTIST_RECOVERED_HYDRATION_TIMING_CHECKPOINT_TUPLE, ARTIST_RECOVERED_HYDRATION_EXTERNAL_GUARDS_TUPLE,
      `${ARTIST_HYDRATION_SNAPSHOT_TUPLE}[7]`,
    ], [ARTIST_RECOVERED_HYDRATION_PROFILE, 1n, e.chainId, e.registry, e.coordinator, p.admission.prior, p.admission.sourceCoordinator,
      r, p.admission.artists, p.admission.collections, p.query, p.data, p.timing, p.externalGuards, p.admission.before_]);
  }

  const profileTypes = [
    "bytes32", "uint16", "address", "address", ARTIST_RECOVERED_HYDRATION_REQUEST_TUPLE,
    `${ARTIST_HYDRATION_QUERY_TUPLE}[]`, `${ARTIST_HYDRATION_QUERY_TUPLE}[]`, ARTIST_HYDRATION_QUERY_TUPLE,
    `${ARTIST_HYDRATION_OWNER_DATA_TUPLE}[7]`, ARTIST_RECOVERED_HYDRATION_TIMING_CHECKPOINT_TUPLE,
    ARTIST_RECOVERED_HYDRATION_EXTERNAL_GUARDS_TUPLE,
  ] as const;

  function encodeArtistRecoveredHydrationProfileEvidence(
    request: ArtistRecoveredHydrationRequest,
    prepared: ArtistRecoveredHydrationPrepared,
  ): Hex {
    const r = normalizeArtistRecoveredHydrationRequest(request);
    const p = normalizeArtistRecoveredHydrationPrepared(prepared);
    joinRequest(r, p);
    return encode(profileTypes, [ARTIST_RECOVERED_HYDRATION_PROFILE, 1n, p.admission.prior, p.admission.sourceCoordinator,
      r, p.admission.artists, p.admission.collections, p.query, p.data, p.timing, p.externalGuards]);
  }

  function decodeArtistRecoveredHydrationProfileEvidence(raw: Hex): ArtistRecoveredHydrationProfileEvidence {
    const input = bytes(raw);
    const values = coder.decode(profileTypes, input);
    if (coder.encode(profileTypes, values) !== input || values[0] !== ARTIST_RECOVERED_HYDRATION_PROFILE || values[1] !== 1n) {
      throw Error("Noncanonical recovered profile evidence");
    }
    const normalized = profileTypes.map((type, i) => normalizeValue(ParamType.from(type), plain(ParamType.from(type), values[i])));
    const names = ["profile", "version", "prior", "sourceCoordinator", "request", "artists", "collections", "query", "data", "timing", "externalGuards"];
    return Object.freeze(Object.fromEntries(names.map((name, i) => [name, normalized[i]]))) as unknown as ArtistRecoveredHydrationProfileEvidence;
  }

  /** ABI104 compiler methodIdentifier: public library selectors use original nominal struct names. */
  const ARTIST_RECOVERED_HYDRATION_PREPARE_SELECTOR = "0x72c84763" as Hex;

  const ARTIST_RECOVERED_HYDRATION_PREPARE_ABI = Object.freeze([
    `function prepare(${ARTIST_HYDRATION_SUITE_TUPLE} destination,${ARTIST_RECOVERED_HYDRATION_REQUEST_TUPLE} request) view returns(${ARTIST_RECOVERED_HYDRATION_PREPARED_TUPLE} prepared)`,
  ]);

  function artistRecoveredHydrationPreparationCalldata(
    destination: ArtistHydrationSuite,
    requestDraft: ArtistRecoveredHydrationRequest,
  ): Hex {
    const suite = normalize(ARTIST_HYDRATION_SUITE_TUPLE, destination);
    const request = normalizeArtistRecoveredHydrationRequestDraft(requestDraft);
    const args = encode([ARTIST_HYDRATION_SUITE_TUPLE, ARTIST_RECOVERED_HYDRATION_REQUEST_TUPLE], [suite, request]);
    return bytes(`${ARTIST_RECOVERED_HYDRATION_PREPARE_SELECTOR}${args.slice(2)}`);
  }

  function normalizeArtistRecoveredHydrationEvidenceDescriptor(
    value: ArtistRecoveredHydrationEvidenceDescriptor,
  ): ArtistRecoveredHydrationEvidenceDescriptor {
    const d = normalize(ARTIST_RECOVERED_HYDRATION_EVIDENCE_DESCRIPTOR_TUPLE, value);
    if (d.schema !== ARTIST_RECOVERED_HYDRATION_EVIDENCE_SCHEMA || !d.payloadLength
      || d.payloadLength > BigInt(ARTIST_RECOVERED_HYDRATION_MAX_BYTES)
      || d.pageHashes.length !== Number((d.payloadLength + 20_479n) / 20_480n) || d.pageHashes.length > 128) {
      throw Error("Invalid original evidence descriptor");
    }
    nonzero(d.payloadHash);
    d.pageHashes.forEach(nonzero);
    return d;
  }

  function artistRecoveredHydrationEvidenceDescriptor(payload: Hex): ArtistRecoveredHydrationEvidenceDescriptor {
    const raw = bytes(payload);
    if (raw === "0x") throw Error("Empty evidence payload");
    const pageHashes: Hex[] = [];
    for (let offset = 2; offset < raw.length; offset += ARTIST_RECOVERED_HYDRATION_PAGE_BYTES * 2) {
      pageHashes.push(keccak256(`0x${raw.slice(offset, offset + ARTIST_RECOVERED_HYDRATION_PAGE_BYTES * 2)}`) as Hex);
    }
    return normalizeArtistRecoveredHydrationEvidenceDescriptor({
      schema: ARTIST_RECOVERED_HYDRATION_EVIDENCE_SCHEMA, payloadHash: keccak256(raw) as Hex,
      payloadLength: BigInt((raw.length - 2) / 2), pageHashes,
    });
  }

  function artistRecoveredHydrationEvidencePages(payload: Hex): readonly Hex[] {
    const raw = bytes(payload);
    artistRecoveredHydrationEvidenceDescriptor(raw);
    const pages: Hex[] = [];
    for (let offset = 2; offset < raw.length; offset += ARTIST_RECOVERED_HYDRATION_PAGE_BYTES * 2) {
      pages.push(`0x${raw.slice(offset, offset + ARTIST_RECOVERED_HYDRATION_PAGE_BYTES * 2)}` as Hex);
    }
    return Object.freeze(pages);
  }

  function assembleArtistRecoveredHydrationEvidence(
    descriptor: ArtistRecoveredHydrationEvidenceDescriptor,
    pages: readonly Hex[],
  ): Hex {
    const d = normalizeArtistRecoveredHydrationEvidenceDescriptor(descriptor);
    list(pages, 128, d.pageHashes.length);
    const normalized = pages.map((page, i) => {
      const raw = bytes(page, undefined, ARTIST_RECOVERED_HYDRATION_PAGE_BYTES);
      const length = BigInt((raw.length - 2) / 2);
      const expected = i === pages.length - 1 ? d.payloadLength - BigInt(i * ARTIST_RECOVERED_HYDRATION_PAGE_BYTES) : 20_480n;
      if (length !== expected || keccak256(raw) !== d.pageHashes[i]) throw Error("Original evidence page mismatch");
      return raw.slice(2);
    });
    const payload = bytes(`0x${normalized.join("")}`);
    if (keccak256(payload) !== d.payloadHash) throw Error("Full evidence payload mismatch");
    return payload;
  }

  function artistRecoveredHydrationPageId(
    coordinates: ArtistRecoveredHydrationCoordinates,
    commitment: Hex,
    descriptor: ArtistRecoveredHydrationEvidenceDescriptor,
    index: bigint,
  ): Hex {
    const c = normalizeArtistRecoveredHydrationCoordinates(coordinates);
    const value = bytes(commitment, 32);
    nonzero(value);
    const d = normalizeArtistRecoveredHydrationEvidenceDescriptor(descriptor);
    uint(index);
    if (index >= BigInt(d.pageHashes.length)) throw Error("Page index outside descriptor");
    return hash(["bytes32", "uint256", "address", "address", "bytes32", "bytes32", "uint256", "uint256", "uint256", "bytes32"],
      [ARTIST_RECOVERED_HYDRATION_EVIDENCE_SCHEMA, c.chainId, c.registry, c.coordinator, value,
        d.payloadHash, d.payloadLength, BigInt(d.pageHashes.length), index, d.pageHashes[Number(index)]]);
  }

  function artistRecoveredHydrationEvidenceId(
    coordinates: ArtistRecoveredHydrationCoordinates,
    actor: Address,
    commitment: Hex,
  ): Hex {
    const c = normalizeArtistRecoveredHydrationCoordinates(coordinates);
    const value = bytes(commitment, 32);
    nonzero(value);
    return hash(["bytes32", "uint256", "address", "address", "uint16", "address", "bytes32"],
      [id("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"), c.chainId, c.registry, c.coordinator, 60n, address(actor, true), value]);
  }

  const operationTypes = ["uint16", "bytes32", "uint16", "address", "bytes32",
    `${ARTIST_HYDRATION_SNAPSHOT_TUPLE}[7]`, `${ARTIST_HYDRATION_SNAPSHOT_TUPLE}[7]`, "bytes"] as const;

  function encodeArtistRecoveredHydrationEvidenceCarrier(descriptor: ArtistRecoveredHydrationEvidenceDescriptor): Hex {
    return encode(["bytes32", ARTIST_RECOVERED_HYDRATION_EVIDENCE_DESCRIPTOR_TUPLE],
      [ARTIST_RECOVERED_HYDRATION_PROFILE, normalizeArtistRecoveredHydrationEvidenceDescriptor(descriptor)]);
  }

  function decodeArtistRecoveredHydrationEvidenceCarrier(raw: Hex): ArtistRecoveredHydrationEvidenceDescriptor {
    const input = bytes(raw);
    const types = ["bytes32", ARTIST_RECOVERED_HYDRATION_EVIDENCE_DESCRIPTOR_TUPLE];
    const result = coder.decode(types, input);
    if (result[0] !== ARTIST_RECOVERED_HYDRATION_PROFILE || coder.encode(types, result) !== input) throw Error("Invalid evidence carrier");
    return normalizeArtistRecoveredHydrationEvidenceDescriptor(
      plain(ParamType.from(ARTIST_RECOVERED_HYDRATION_EVIDENCE_DESCRIPTOR_TUPLE), result[1]) as ArtistRecoveredHydrationEvidenceDescriptor,
    );
  }

  function encodeArtistRecoveredHydrationOperationEvidence(
    value: ArtistRecoveredHydrationOperationEvidence,
    maximumBytes = 24_575,
  ): Hex {
    exact(value, ["schemaVersion", "configurationHash", "operationId", "actor", "commitment", "before", "after", "profileData"]);
    if (!Number.isSafeInteger(maximumBytes) || maximumBytes < 1 || maximumBytes > ARTIST_RECOVERED_HYDRATION_MAX_BYTES) throw Error("Invalid Archive byte bound");
    if (value.schemaVersion !== 1n || value.operationId !== 60n) throw Error("Wrong original operation envelope");
    nonzero(bytes(value.configurationHash, 32)); nonzero(bytes(value.commitment, 32)); address(value.actor, true);
    const before = normalize(`${ARTIST_HYDRATION_SNAPSHOT_TUPLE}[7]`, value.before);
    const after = normalize(`${ARTIST_HYDRATION_SNAPSHOT_TUPLE}[7]`, value.after);
    decodeArtistRecoveredHydrationEvidenceCarrier(value.profileData);
    return bytes(coder.encode(operationTypes, [1n, value.configurationHash, 60n, value.actor, value.commitment, before, after, value.profileData]), undefined, maximumBytes);
  }

  function decodeArtistRecoveredHydrationOperationEvidence(
    raw: Hex,
    maximumBytes = 24_575,
  ): ArtistRecoveredHydrationOperationEvidence {
    const input = bytes(raw, undefined, maximumBytes);
    const values = coder.decode(operationTypes, input);
    const names = ["schemaVersion", "configurationHash", "operationId", "actor", "commitment", "before", "after", "profileData"];
    const result = Object.freeze(Object.fromEntries(operationTypes.map((type, i) =>
      [names[i]!, normalizeValue(ParamType.from(type), plain(ParamType.from(type), values[i]))]))) as unknown as ArtistRecoveredHydrationOperationEvidence;
    if (encodeArtistRecoveredHydrationOperationEvidence(result, maximumBytes) !== input) throw Error("Noncanonical Archive operation evidence");
    return result;
  }

  const historicalSurfaces = new Set([
    id("identity_authority.replay.one_way_cutover_latch"),
    id("identity_authority.replay.verified_lane_key"),
    id("identity_authority.replay.import_binding"),
  ]);

  function artistRecoveredHydrationOwnerReplayDelta(
    destination: ArtistRecoveredHydrationOriginEnvironment,
    index: ArtistHydrationOwnerIndex,
    data: ArtistHydrationOwnerData,
    commitment: Hex,
    historicalCells: readonly ArtistRecoveredHydrationHistoricalCell[],
  ): Hex {
    const e = normalizeArtistRecoveredHydrationOriginEnvironment(destination);
    const d = normalize(ARTIST_HYDRATION_OWNER_DATA_TUPLE, data);
    const value = bytes(commitment, 32);
    nonzero(value);
    const { payload } = decodeArtistRecoveredHydrationOwnerPayload(d.typedState, index);
    const source = payload.provenance.origins.at(-1)!;
    if (source.chainId !== e.chainId || source.core !== e.core || source.manager !== e.manager
      || source.registry === e.registry || source.coordinator === e.coordinator || source.owners[index] === e.owners[index]
      || d.nonces.length || d.origins.length !== Number(payload.provenance.eras.at(-1)!.checkpoint.replayCount)
      || d.origins.length !== d.cells.length || d.origins.length !== d.sourceKeys.length) throw Error("Invalid recovered guard application");
    list(historicalCells, 8192);
    const cells = new Map<Hex, ArtistHydrationReplayCell>();
    for (const row of historicalCells) {
      exact(row, ["sourceKey", "cell"]);
      const key = bytes(row.sourceKey, 32);
      if (cells.has(key)) throw Error("Duplicate historical destination cell");
      cells.set(key, normalize(ARTIST_HYDRATION_REPLAY_CELL_TUPLE, row.cell));
    }
    const aliases = new Map(payload.provenance.aliases.map(alias => [alias.originalKey, alias]));
    let activeDelta = ZERO;
    let historicalDelta = ZERO;
    const seen = new Set<Hex>();
    for (let i = 0; i < d.origins.length; i++) {
      const logical = d.origins[i]!;
      const sourceKey = artistRecoveredHydrationReplayKey(source, index, logical);
      const alias = aliases.get(sourceKey);
      if (seen.has(sourceKey) || d.sourceKeys[i] !== sourceKey || !alias
        || alias.originHash !== artistRecoveredHydrationOriginHash(source)
        || !same(ARTIST_HYDRATION_REPLAY_CELL_TUPLE, alias.cell, d.cells[i])) throw Error("Invalid imported replay cell");
      seen.add(sourceKey);
      const key = artistRecoveredHydrationReplayKey(e, index, logical);
      if (index === 2 && historicalSurfaces.has(logical.surface)) {
        const current = cells.get(sourceKey);
        if (!current || (logical.surface === id("identity_authority.replay.one_way_cutover_latch")
          ? logical.scope !== ZERO || current.status !== 0n
          : current.commitment === ZERO || current.kind !== 1n || current.status !== 2n)) throw Error("Missing genuine destination history admission");
        cells.delete(sourceKey);
        historicalDelta = hash(["bytes32", ARTIST_RECOVERED_HYDRATION_REPLAY_ALIAS_TUPLE, "bytes32", ARTIST_HYDRATION_REPLAY_CELL_TUPLE],
          [historicalDelta, alias, key, current]);
      } else {
        activeDelta = hash(["bytes32", "bytes32", ARTIST_HYDRATION_REPLAY_CELL_TUPLE], [activeDelta, key, d.cells[i]]);
      }
    }
    if (cells.size) throw Error("Unused historical destination cells");
    return hash(["bytes32", "uint16", "uint8", "bytes32", "bytes32", "bytes32"],
      [id("6529STREAM_ARTIST_RECOVERED_HYDRATION_GUARDS_V1"), 1n, BigInt(index), value, activeDelta, historicalDelta]);
  }

  function artistRecoveredHydrationOwnerAfter(
    destination: ArtistRecoveredHydrationOriginEnvironment,
    index: ArtistHydrationOwnerIndex,
    before: ArtistHydrationSnapshot,
    query: ArtistHydrationQuery,
    data: ArtistHydrationOwnerData,
    commitment: Hex,
    actor: Address,
    historicalCells: readonly ArtistRecoveredHydrationHistoricalCell[],
  ): ArtistHydrationSnapshot {
    const e = normalizeArtistRecoveredHydrationOriginEnvironment(destination);
    const previous = normalize(ARTIST_HYDRATION_SNAPSHOT_TUPLE, before);
    const q = normalize(ARTIST_HYDRATION_QUERY_TUPLE, query);
    const d = normalize(ARTIST_HYDRATION_OWNER_DATA_TUPLE, data);
    const value = bytes(commitment, 32);
    const sender = address(actor, true);
    if (previous.domainId !== artistRecoveredHydrationOwnerDomain(index) || previous.revision === (1n << 64n) - 1n) throw Error("Invalid destination owner snapshot");
    const nextRevision = previous.revision + 1n;
    const replayDelta = artistRecoveredHydrationOwnerReplayDelta(e, index, d, value, historicalCells);
    const nextState = hash([ARTIST_HYDRATION_QUERY_TUPLE, ARTIST_HYDRATION_OWNER_DATA_TUPLE, "bytes32"], [q, d, value]);
    const root = hash([
      "bytes32", "uint256", "address", "address", "address", "address", "bytes32", "uint64", "uint64",
      "bytes32", "bytes32", "bytes32", "bytes32", "bytes32",
    ], [id("6529STREAM_ARTIST_OWNER_STATE_TRANSITION_V2"), e.chainId, e.registry, e.coordinator, e.archive, e.owners[index],
      previous.domainId, previous.revision, nextRevision, previous.stateRoot,
      hash(["uint16", "address", "bytes32"], [60n, sender, value]), nextState, replayDelta, hash(["bytes32"], [ZERO])]);
    return Object.freeze({ domainId: previous.domainId, revision: nextRevision, stateRoot: root, recordChainTip: previous.recordChainTip });
  }

  function artistRecoveredHydrationRequiredFeatures(value: ArtistRecoveredHydrationFeatureFacts): bigint {
    exact(value, ["currentAuthorityClass", "recoveryAuthorityClasses", "hasAdjudicationV2", "hasRewindsV3", "eraCount",
      "economicsCount", "hasDelegations", "bindingConsentMode", "saleConsentCount", "attestationCount"]);
    list(value.recoveryAuthorityClasses, 4096);
    for (const flag of [value.hasAdjudicationV2, value.hasRewindsV3, value.hasDelegations]) {
      if (typeof flag !== "boolean") throw Error("Expected observed source boolean");
    }
    const eraCount = uint(value.eraCount);
    if (eraCount < 1n || eraCount > 16n || uint(value.economicsCount) > 128n
      || uint(value.attestationCount) > 128n || uint(value.saleConsentCount) > 4096n) throw Error("Feature inventory exceeds profile capacity");
    uint(value.bindingConsentMode, 8);
    let features = 0n;
    for (const authorityClass of [value.currentAuthorityClass, ...value.recoveryAuthorityClasses]) {
      if (authorityClass === 1n) features |= 1n;
      else if (authorityClass === 3n) features |= 2n;
      else throw Error("Only original recovered class1/class3 histories are admitted");
    }
    if (value.hasAdjudicationV2) features |= 4n;
    if (value.hasRewindsV3) features |= 8n;
    if (eraCount > 1n) features |= 16n;
    if (value.economicsCount) features |= 32n;
    if (value.hasDelegations || value.bindingConsentMode === 2n || value.saleConsentCount) features |= 64n;
    if (value.attestationCount) features |= 128n;
    return features;
  }

  return Object.freeze({
    normalizeTuple: normalize,
    decodeTuple: decode,
    boundedBytes: bytes,
    encodeTupleValues: encode,
    exactFields: (value: unknown, keys: readonly string[]): void => { exact(value, keys); },
    boundedArray: (value: unknown, maximum: number, length?: number): void => { list(value, maximum, length); },
    artistRecoveredHydrationOwnerDomain,
    artistRecoveredHydrationOwnerTag,
    normalizeArtistRecoveredHydrationCoordinates,
    normalizeArtistRecoveredHydrationCapability,
    validateArtistRecoveredHydrationCapability,
    normalizeArtistRecoveredHydrationRequestDraft,
    normalizeArtistRecoveredHydrationRequest,
    encodeArtistRecoveredHydrationRequest,
    decodeArtistRecoveredHydrationRequest,
    CURRENT_ARTIST_RECOVERED_HYDRATION_ABI,
    ARTIST_RECOVERED_HYDRATION_CAPABILITY_ID,
    prepareArtistRecoveredHydrationCall,
    normalizeArtistRecoveredHydrationCall,
    normalizeArtistRecoveredHydrationOriginEnvironment,
    artistRecoveredHydrationOriginHash,
    artistRecoveredHydrationReplayKey,
    normalizeArtistRecoveredHydrationOwnerProvenance,
    artistRecoveredHydrationOwnerProvenance,
    normalizeArtistRecoveredHydrationProvenance,
    artistRecoveredHydrationProvenanceHash,
    artistRecoveredHydrationOwnerProvenanceHash,
    artistRecoveredHydrationAliasesHash,
    compareArtistRecoveredHydrationPoints,
    normalizeArtistRecoveredHydrationNonceInventory,
    normalizeArtistRecoveredHydrationPublications,
    normalizeArtistRecoveredHydrationOwnerPayload,
    encodeArtistRecoveredHydrationOwnerPayload,
    decodeArtistRecoveredHydrationOwnerPayload,
    normalizeArtistRecoveredHydrationTimingCheckpoint,
    normalizeArtistRecoveredHydrationExternalGuards,
    normalizeArtistRecoveredHydrationPrepared,
    encodeArtistRecoveredHydrationPrepared,
    decodeArtistRecoveredHydrationPrepared,
    artistRecoveredHydrationSemanticInventory,
    artistRecoveredHydrationCommitment,
    encodeArtistRecoveredHydrationProfileEvidence,
    decodeArtistRecoveredHydrationProfileEvidence,
    ARTIST_RECOVERED_HYDRATION_PREPARE_SELECTOR,
    ARTIST_RECOVERED_HYDRATION_PREPARE_ABI,
    artistRecoveredHydrationPreparationCalldata,
    normalizeArtistRecoveredHydrationEvidenceDescriptor,
    artistRecoveredHydrationEvidenceDescriptor,
    artistRecoveredHydrationEvidencePages,
    assembleArtistRecoveredHydrationEvidence,
    artistRecoveredHydrationPageId,
    artistRecoveredHydrationEvidenceId,
    encodeArtistRecoveredHydrationEvidenceCarrier,
    decodeArtistRecoveredHydrationEvidenceCarrier,
    encodeArtistRecoveredHydrationOperationEvidence,
    decodeArtistRecoveredHydrationOperationEvidence,
    artistRecoveredHydrationOwnerReplayDelta,
    artistRecoveredHydrationOwnerAfter,
    artistRecoveredHydrationRequiredFeatures
  });
}
