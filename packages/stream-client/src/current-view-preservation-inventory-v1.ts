import { AbiCoder, Interface, ParamType, ZeroAddress, ZeroHash, getAddress, id, isHexString, keccak256, toUtf8Bytes, hexlify } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import type { UnsignedCall } from "./binding.js";
import * as original from "./current-scoped-policy-inventory-v2.js";
import * as retrieval from "./current-view-retrieval-v1.js";

/** Original ABI157. Supplied values do not prove live source or archive authority. */
export const CURRENT_VIEW_PRESERVATION_INVENTORY_V1_SOURCE = "a2973d360f6ab18881c04d58193f855704ec56d3";
/** Client allocation ceilings, not protocol item-count limits. */
export const CURRENT_VIEW_PRESERVATION_INVENTORY_V1_MAX_BYTES = 2097152;
export const CURRENT_VIEW_PRESERVATION_INVENTORY_V1_MAX_ROWS = 8192;
/** Retained multi-segment history has its own aggregate client budget. */
export const CURRENT_VIEW_PRESERVATION_INVENTORY_V1_MAX_HISTORY_BYTES = 16777216;
export interface CurrentViewPreservationInventoryV1Coordinates {
  readonly chainId: bigint;
  readonly core: Address;
  readonly inventory: Address;
}

export interface CurrentViewPreservationInventoryV1Dependencies {
  readonly targets: readonly [Address, Address, Address, Address, Address, Address, Address, Address, Address, Address, Address, Address];
  readonly codeHashes: readonly [Hex, Hex, Hex, Hex, Hex, Hex, Hex, Hex, Hex, Hex, Hex, Hex];
  readonly artistTargets: readonly [Address, Address, Address, Address, Address];
  readonly artistCodeHashes: readonly [Hex, Hex, Hex, Hex, Hex];
  readonly artistContentOwner: Address;
  readonly artistContentOwnerCodeHash: Hex;
  readonly chainId: bigint;
  readonly readGas: bigint;
  readonly sourceGas: bigint;
  readonly selectionGas: bigint;
  readonly snapshotGas: bigint;
  readonly referenceGas: bigint;
}

export interface CurrentViewPreservationInventoryV1Evidence {
  readonly scope: CurrentViewPreservationInventoryV1Scope;
  readonly inventory: CurrentViewPreservationInventoryV1OriginalEvidence;
}

export interface CurrentViewPreservationInventoryV1Scope {
  readonly scopeType: bigint;
  readonly collectionId: bigint;
  readonly tokenId: bigint;
  readonly scopeId: Hex;
}

export interface CurrentViewPreservationInventoryV1OriginalEvidence {
  readonly planId: Hex;
  readonly collectionId: bigint;
  readonly scopeSubject: Hex;
  readonly artistId: Hex;
  readonly originals: CurrentViewPreservationInventoryV1OriginalInputs;
  readonly sourceContextHash: Hex;
  readonly tokenInventoryHash: Hex;
  readonly tokenCount: bigint;
  readonly segmentCount: bigint;
  readonly itemCount: bigint;
  readonly segmentChainHash: Hex;
  readonly renderCriticalEvidenceHash: Hex;
}

export interface CurrentViewPreservationInventoryV1OriginalInputs {
  readonly rootRecordHash: Hex;
  readonly snapshotRecordHash: Hex;
  readonly referenceRenderRecordHash: Hex;
  readonly intentRecordHash: Hex;
  readonly intentWaiverRecordHash: Hex;
  readonly interviewEvidenceHash: Hex;
  readonly rightsStatementRecordHash: Hex;
  readonly workDescriptionRecordHash: Hex;
}

export interface CurrentViewPreservationInventoryV1Segment {
  readonly key: Hex;
  readonly itemCount: bigint;
  readonly firstLink: Hex;
  readonly sourceWitnessHash: Hex;
}

export interface CurrentViewPreservationInventoryV1Item {
  readonly kind: bigint;
  readonly role: Hex;
  readonly source: Address;
  readonly sourceRecord: Hex;
  readonly sourceIndex: bigint;
  readonly algorithm: bigint;
  readonly canonicalizationId: Hex;
  readonly digest: Hex;
  readonly uri: string;
  readonly byteSize: bigint;
  readonly schemaId: Hex;
  readonly formatId: Hex;
  readonly catalogId: Hex;
  readonly catalogHash: Hex;
  readonly objectHash: Hex;
  readonly originalCoverageHash: Hex;
  readonly provenanceHash: Hex;
}

export interface CurrentViewPreservationInventoryV1Intent {
  readonly subjectId: Hex;
  readonly profileHash: Hex;
  readonly predecessor: Hex;
  readonly artist: CurrentViewPreservationInventoryV1ConservationArtistClaim;
  readonly display: CurrentViewPreservationInventoryV1ConservationDisplay;
  readonly variabilityTolerances: CurrentViewPreservationInventoryV1ConservationReference;
  readonly dependencyAging: CurrentViewPreservationInventoryV1ConservationReference;
  readonly significantProperties: CurrentViewPreservationInventoryV1ConservationReference;
  readonly interview: CurrentViewPreservationInventoryV1ConservationInterviewEntry;
}

export interface CurrentViewPreservationInventoryV1ConservationArtistClaim {
  readonly artistId: Hex;
  readonly bindingGeneration: bigint;
  readonly bindingHash: Hex;
  readonly origin: bigint;
}

export interface CurrentViewPreservationInventoryV1ConservationDisplay {
  readonly scale: CurrentViewPreservationInventoryV1ConservationReference;
  readonly timing: CurrentViewPreservationInventoryV1ConservationReference;
  readonly color: CurrentViewPreservationInventoryV1ConservationReference;
  readonly interaction: CurrentViewPreservationInventoryV1ConservationReference;
  readonly motion: CurrentViewPreservationInventoryV1ConservationReference;
  readonly frameRate: CurrentViewPreservationInventoryV1ConservationReference;
}

export interface CurrentViewPreservationInventoryV1ConservationReference {
  readonly algorithm: bigint;
  readonly canonicalizationId: Hex;
  readonly digest: Hex;
  readonly uri: string;
}

export interface CurrentViewPreservationInventoryV1ConservationInterviewEntry {
  readonly status: bigint;
  readonly record: CurrentViewPreservationInventoryV1ConservationInterviewRecord;
  readonly waiverStatement: CurrentViewPreservationInventoryV1ConservationReference;
}

export interface CurrentViewPreservationInventoryV1ConservationInterviewRecord {
  readonly chainId: bigint;
  readonly core: Address;
  readonly host: Address;
  readonly recordHash: Hex;
  readonly schemaId: Hex;
  readonly profileHash: Hex;
  readonly payload: CurrentViewPreservationInventoryV1ConservationReference;
}

export interface CurrentViewPreservationInventoryV1IntentWaiver {
  readonly subjectId: Hex;
  readonly profileHash: Hex;
  readonly predecessor: Hex;
  readonly artist: CurrentViewPreservationInventoryV1ConservationArtistClaim;
  readonly waiverStatement: CurrentViewPreservationInventoryV1ConservationReference;
  readonly interview: CurrentViewPreservationInventoryV1ConservationInterviewEntry;
}

export interface CurrentViewPreservationInventoryV1Interview {
  readonly subjectId: Hex;
  readonly profileHash: Hex;
  readonly predecessor: Hex;
  readonly instrument: CurrentViewPreservationInventoryV1ConservationInstrument;
  readonly participants: readonly CurrentViewPreservationInventoryV1ConservationParticipant[];
  readonly interviewDate: bigint;
  readonly languages: readonly string[];
  readonly transcript: CurrentViewPreservationInventoryV1ConservationPayload;
  readonly captures: readonly CurrentViewPreservationInventoryV1ConservationCapture[];
}

export interface CurrentViewPreservationInventoryV1ConservationInstrument {
  readonly kind: bigint;
  readonly name: string;
  readonly document: CurrentViewPreservationInventoryV1ConservationReference;
}

export interface CurrentViewPreservationInventoryV1ConservationParticipant {
  readonly role: bigint;
  readonly otherRole: string;
  readonly identity: CurrentViewPreservationInventoryV1ConservationReference;
}

export interface CurrentViewPreservationInventoryV1ConservationPayload {
  readonly content: CurrentViewPreservationInventoryV1ConservationReference;
  readonly format: CurrentViewPreservationInventoryV1ConservationFormat;
}

export interface CurrentViewPreservationInventoryV1ConservationFormat {
  readonly kind: bigint;
  readonly formatId: Hex;
  readonly puid: string;
  readonly catalog: CurrentViewPreservationInventoryV1ConservationCatalog;
}

export interface CurrentViewPreservationInventoryV1ConservationCatalog {
  readonly name: string;
  readonly entries: readonly CurrentViewPreservationInventoryV1ConservationCatalogEntry[];
  readonly selectedEntryId: Hex;
}

export interface CurrentViewPreservationInventoryV1ConservationCatalogEntry {
  readonly entryId: Hex;
  readonly kind: bigint;
  readonly puid: string;
  readonly specification: CurrentViewPreservationInventoryV1ConservationReference;
}

export interface CurrentViewPreservationInventoryV1ConservationCapture {
  readonly kind: bigint;
  readonly payload: CurrentViewPreservationInventoryV1ConservationPayload;
}

export interface CurrentViewPreservationInventoryV1Statement {
  readonly subjectId: Hex;
  readonly profileHash: Hex;
  readonly basis: bigint;
  readonly licensor: CurrentViewPreservationInventoryV1RightsLicensor;
  readonly grants: CurrentViewPreservationInventoryV1RightsGrants;
  readonly startDate: bigint;
  readonly endDate: bigint;
  readonly openEnd: boolean;
  readonly instrument: CurrentViewPreservationInventoryV1RightsDocument;
  readonly hasAiTrainingPermission: boolean;
  readonly aiTrainingPermission: bigint;
  readonly predecessor: Hex;
}

export interface CurrentViewPreservationInventoryV1RightsLicensor {
  readonly kind: bigint;
  readonly artistId: Hex;
  readonly name: string;
  readonly account: Address;
  readonly instrumentDigest: Hex;
}

export interface CurrentViewPreservationInventoryV1RightsGrants {
  readonly aiTraining: CurrentViewPreservationInventoryV1RightsGrant;
  readonly derivative: CurrentViewPreservationInventoryV1RightsGrant;
  readonly exhibition: CurrentViewPreservationInventoryV1RightsGrant;
  readonly print: CurrentViewPreservationInventoryV1RightsGrant;
  readonly publication: CurrentViewPreservationInventoryV1RightsGrant;
  readonly reproduction: CurrentViewPreservationInventoryV1RightsGrant;
}

export interface CurrentViewPreservationInventoryV1RightsGrant {
  readonly status: bigint;
  readonly conditions: CurrentViewPreservationInventoryV1RightsConditions;
  readonly extension: string;
}

export interface CurrentViewPreservationInventoryV1RightsConditions {
  readonly kind: bigint;
  readonly text: string;
  readonly document: CurrentViewPreservationInventoryV1RightsDocument;
}

export interface CurrentViewPreservationInventoryV1RightsDocument {
  readonly exists: boolean;
  readonly uri: string;
  readonly digest: Hex;
}

export interface CurrentViewPreservationInventoryV1RootAggregate {
  readonly revision: bigint;
  readonly transitionChain: Hex;
}

export interface CurrentViewPreservationInventoryV1Description {
  readonly subjectId: Hex;
  readonly profileHash: Hex;
  readonly predecessor: Hex;
  readonly form: bigint;
  readonly full: CurrentViewPreservationInventoryV1WorkFullDescription;
  readonly absence: CurrentViewPreservationInventoryV1WorkAbsence;
}

export interface CurrentViewPreservationInventoryV1WorkFullDescription {
  readonly title: string;
  readonly creator: CurrentViewPreservationInventoryV1WorkCreator;
  readonly creation: CurrentViewPreservationInventoryV1WorkCreation;
  readonly medium: string;
  readonly format: CurrentViewPreservationInventoryV1WorkFormat;
  readonly measurements: CurrentViewPreservationInventoryV1WorkMeasurements;
  readonly edition: CurrentViewPreservationInventoryV1WorkEdition;
  readonly creditLine: string;
  readonly hasInscription: boolean;
  readonly inscription: string;
  readonly alternateTitles: readonly string[];
  readonly languageVariants: readonly CurrentViewPreservationInventoryV1WorkLanguageVariant[];
  readonly authorityReferences: readonly CurrentViewPreservationInventoryV1WorkAuthorityReference[];
}

export interface CurrentViewPreservationInventoryV1WorkCreator {
  readonly kind: bigint;
  readonly artistId: Hex;
  readonly bindingGeneration: bigint;
  readonly bindingHash: Hex;
  readonly name: string;
}

export interface CurrentViewPreservationInventoryV1WorkCreation {
  readonly kind: bigint;
  readonly start: bigint;
  readonly end: bigint;
}

export interface CurrentViewPreservationInventoryV1WorkFormat {
  readonly kind: bigint;
  readonly formatId: Hex;
  readonly puid: string;
  readonly catalog: CurrentViewPreservationInventoryV1WorkCatalog;
}

export interface CurrentViewPreservationInventoryV1WorkCatalog {
  readonly name: string;
  readonly entries: readonly CurrentViewPreservationInventoryV1WorkCatalogEntry[];
  readonly selectedEntryId: Hex;
}

export interface CurrentViewPreservationInventoryV1WorkCatalogEntry {
  readonly entryId: Hex;
  readonly kind: bigint;
  readonly puid: string;
  readonly specification: CurrentViewPreservationInventoryV1WorkSpecification;
}

export interface CurrentViewPreservationInventoryV1WorkSpecification {
  readonly uri: string;
  readonly digest: Hex;
}

export interface CurrentViewPreservationInventoryV1WorkMeasurements {
  readonly kind: bigint;
  readonly hasPixels: boolean;
  readonly width: bigint;
  readonly height: bigint;
  readonly hasAspectRatio: boolean;
  readonly aspectRatio: CurrentViewPreservationInventoryV1WorkRational;
  readonly hasDuration: boolean;
  readonly durationSeconds: CurrentViewPreservationInventoryV1WorkRational;
}

export interface CurrentViewPreservationInventoryV1WorkRational {
  readonly numerator: bigint;
  readonly denominator: bigint;
}

export interface CurrentViewPreservationInventoryV1WorkEdition {
  readonly kind: bigint;
  readonly number: bigint;
  readonly total: bigint;
  readonly statement: string;
}

export interface CurrentViewPreservationInventoryV1WorkLanguageVariant {
  readonly field: bigint;
  readonly alternateTitleIndex: bigint;
  readonly language: string;
  readonly value: string;
}

export interface CurrentViewPreservationInventoryV1WorkAuthorityReference {
  readonly role: bigint;
  readonly authority: bigint;
  readonly identifier: string;
}

export interface CurrentViewPreservationInventoryV1WorkAbsence {
  readonly reason: string;
  readonly date: bigint;
}

export interface CurrentViewPreservationInventoryV1Plan {
  readonly scope: CurrentViewPreservationInventoryV1Scope;
  readonly progress: CurrentViewPreservationInventoryV1Progress;
  readonly nativeCursor: bigint;
  readonly nativeCount: bigint;
  readonly referenceCursor: bigint;
  readonly referenceCount: bigint;
}

export interface CurrentViewPreservationInventoryV1Progress {
  readonly collectionId: bigint;
  readonly subject: Hex;
  readonly artistId: Hex;
  readonly sourceContextHash: Hex;
  readonly tokenCount: bigint;
  readonly nextToken: bigint;
  readonly segmentCount: bigint;
  readonly itemCount: bigint;
  readonly segmentChainHash: Hex;
  readonly completedStages: bigint;
  readonly renderCriticalEvidenceHash: Hex;
}

export interface CurrentViewPreservationInventoryV1Context {
  readonly scope: CurrentViewPreservationInventoryV1Scope;
  readonly subject: Hex;
  readonly artistId: Hex;
  readonly snapshot: CurrentViewPreservationInventoryV1SnapshotReceipt;
  readonly referenceRender: CurrentViewPreservationInventoryV1ReferenceReceipt;
  readonly descriptions: CurrentViewPreservationInventoryV1DescriptionEvidence;
  readonly conservation: CurrentViewPreservationInventoryV1ConservationSelection;
  readonly interviewEvidenceHash: Hex;
  readonly nativeHash: Hex;
  readonly rootRecordHash: Hex;
  readonly tokenInventoryHash: Hex;
  readonly checkpointHash: Hex;
  readonly outputManifestRecord: Hex;
  readonly adoptionRecord: Hex;
  readonly viewId: Hex;
  readonly payloadHash: Hex;
  readonly sourceContextHash: Hex;
  readonly policyChainHash: Hex;
  readonly outputRoot: Hex;
  readonly manifestIndexHash: Hex;
  readonly tokenCount: bigint;
}

export interface CurrentViewPreservationInventoryV1SnapshotReceipt {
  readonly recordHash: Hex;
  readonly scopeSubject: Hex;
  readonly predecessor: Hex;
  readonly revision: bigint;
  readonly chainHash: Hex;
  readonly manifestHash: Hex;
  readonly manifestBytes: bigint;
  readonly sourceHash: Hex;
  readonly publisher: Address;
  readonly authorizationClass: bigint;
  readonly grantRevision: bigint;
  readonly displayAuthorizationClass: bigint;
  readonly displayGrantRevision: bigint;
  readonly recordedAt: bigint;
  readonly schemaHash: Hex;
  readonly profileHash: Hex;
  readonly canonicalizationHash: Hex;
}

export interface CurrentViewPreservationInventoryV1ReferenceReceipt {
  readonly scopeSubject: Hex;
  readonly observation: CurrentViewPreservationInventoryV1ReferenceObservation;
}

export interface CurrentViewPreservationInventoryV1ReferenceObservation {
  readonly recordHash: Hex;
  readonly recordChainHash: Hex;
  readonly collectionId: bigint;
  readonly referenceId: Hex;
  readonly predecessor: Hex;
  readonly revision: bigint;
  readonly payloadHash: Hex;
  readonly payloadBytes: bigint;
  readonly sourcesHash: Hex;
  readonly snapshotRecordHash: Hex;
  readonly snapshotRevision: bigint;
  readonly recorder: Address;
  readonly authorizationClass: bigint;
  readonly grantRevision: bigint;
  readonly effectiveAt: bigint;
  readonly recordedAt: bigint;
  readonly reasonHash: Hex;
  readonly schemaHash: Hex;
  readonly profileHash: Hex;
  readonly canonicalizationHash: Hex;
}

export interface CurrentViewPreservationInventoryV1DescriptionEvidence {
  readonly scopeSubject: Hex;
  readonly workDescriptionRecordHash: Hex;
  readonly rightsStatementRecordHash: Hex;
  readonly workPayloadHash: Hex;
  readonly rightsPayloadHash: Hex;
  readonly workSelectionHash: Hex;
  readonly rightsSelectionHash: Hex;
  readonly workRevision: bigint;
  readonly rightsRevision: bigint;
}

export interface CurrentViewPreservationInventoryV1ConservationSelection {
  readonly record: CurrentViewPreservationInventoryV1ConservationRecordEvidence;
  readonly association: CurrentViewPreservationInventoryV1ConservationAssociation;
  readonly origin: bigint;
  readonly interviewStatus: bigint;
  readonly interview: CurrentViewPreservationInventoryV1ConservationRecordEvidence;
  readonly interviewArchiveReferenceHash: Hex;
  readonly interviewPayloadCorrespondence: bigint;
  readonly predecessor: Hex;
  readonly submitter: Address;
  readonly revision: bigint;
  readonly selectedAt: bigint;
  readonly catalogsHash: Hex;
  readonly selectionHash: Hex;
}

export interface CurrentViewPreservationInventoryV1ConservationRecordEvidence {
  readonly recordHash: Hex;
  readonly kind: bigint;
  readonly payloadHash: Hex;
  readonly recorder: Address;
  readonly recordedAt: bigint;
  readonly recordIndex: bigint;
  readonly recordChainHash: Hex;
  readonly receiptHash: Hex;
  readonly publication: CurrentViewPreservationInventoryV1PublicationEvidence;
  readonly publicationEvidenceHash: Hex;
}

export interface CurrentViewPreservationInventoryV1PublicationEvidence {
  readonly attestationRecordHash: Hex;
  readonly artistId: Hex;
  readonly bindingHash: Hex;
  readonly bindingGeneration: bigint;
  readonly signer: Address;
  readonly authorityClass: bigint;
  readonly requiredCapability: bigint;
  readonly signedAt: bigint;
  readonly publicationHash: Hex;
}

export interface CurrentViewPreservationInventoryV1ConservationAssociation {
  readonly artistId: Hex;
  readonly bindingHash: Hex;
  readonly generation: bigint;
  readonly identityRecordHash: Hex;
}

export interface CurrentViewPreservationInventoryV1TokenProgress {
  readonly phase: bigint;
  readonly row: bigint;
  readonly count: bigint;
}

export const CURRENT_VIEW_PRESERVATION_INVENTORY_V1_DEPENDENCIES_TUPLE = "(address[12] targets, bytes32[12] codeHashes, address[5] artistTargets, bytes32[5] artistCodeHashes, address artistContentOwner, bytes32 artistContentOwnerCodeHash, uint256 chainId, uint256 readGas, uint256 sourceGas, uint256 selectionGas, uint256 snapshotGas, uint256 referenceGas)";
export const CURRENT_VIEW_PRESERVATION_INVENTORY_V1_EVIDENCE_TUPLE = "((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, (bytes32 planId, uint256 collectionId, bytes32 scopeSubject, bytes32 artistId, (bytes32 rootRecordHash, bytes32 snapshotRecordHash, bytes32 referenceRenderRecordHash, bytes32 intentRecordHash, bytes32 intentWaiverRecordHash, bytes32 interviewEvidenceHash, bytes32 rightsStatementRecordHash, bytes32 workDescriptionRecordHash) originals, bytes32 sourceContextHash, bytes32 tokenInventoryHash, uint64 tokenCount, uint64 segmentCount, uint64 itemCount, bytes32 segmentChainHash, bytes32 renderCriticalEvidenceHash) inventory)";
export const CURRENT_VIEW_PRESERVATION_INVENTORY_V1_SCOPE_TUPLE = "(uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId)";
export const CURRENT_VIEW_PRESERVATION_INVENTORY_V1_ORIGINAL_EVIDENCE_TUPLE = "(bytes32 planId, uint256 collectionId, bytes32 scopeSubject, bytes32 artistId, (bytes32 rootRecordHash, bytes32 snapshotRecordHash, bytes32 referenceRenderRecordHash, bytes32 intentRecordHash, bytes32 intentWaiverRecordHash, bytes32 interviewEvidenceHash, bytes32 rightsStatementRecordHash, bytes32 workDescriptionRecordHash) originals, bytes32 sourceContextHash, bytes32 tokenInventoryHash, uint64 tokenCount, uint64 segmentCount, uint64 itemCount, bytes32 segmentChainHash, bytes32 renderCriticalEvidenceHash)";
export const CURRENT_VIEW_PRESERVATION_INVENTORY_V1_ORIGINAL_INPUTS_TUPLE = "(bytes32 rootRecordHash, bytes32 snapshotRecordHash, bytes32 referenceRenderRecordHash, bytes32 intentRecordHash, bytes32 intentWaiverRecordHash, bytes32 interviewEvidenceHash, bytes32 rightsStatementRecordHash, bytes32 workDescriptionRecordHash)";
export const CURRENT_VIEW_PRESERVATION_INVENTORY_V1_SEGMENT_TUPLE = "(bytes32 key, uint64 itemCount, bytes32 firstLink, bytes32 sourceWitnessHash)";
export const CURRENT_VIEW_PRESERVATION_INVENTORY_V1_ITEM_TUPLE = "(uint8 kind, bytes32 role, address source, bytes32 sourceRecord, uint256 sourceIndex, uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri, uint64 byteSize, bytes32 schemaId, bytes32 formatId, bytes32 catalogId, bytes32 catalogHash, bytes32 objectHash, bytes32 originalCoverageHash, bytes32 provenanceHash)";
export const CURRENT_VIEW_PRESERVATION_INVENTORY_V1_INTENT_TUPLE = "(bytes32 subjectId, bytes32 profileHash, bytes32 predecessor, (bytes32 artistId, uint64 bindingGeneration, bytes32 bindingHash, uint8 origin) artist, ((uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) scale, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) timing, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) color, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) interaction, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) motion, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) frameRate) display, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) variabilityTolerances, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) dependencyAging, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) significantProperties, (uint8 status, (uint256 chainId, address core, address host, bytes32 recordHash, bytes32 schemaId, bytes32 profileHash, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) payload) record, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) waiverStatement) interview)";
export const CURRENT_VIEW_PRESERVATION_INVENTORY_V1_CONSERVATION_ARTIST_CLAIM_TUPLE = "(bytes32 artistId, uint64 bindingGeneration, bytes32 bindingHash, uint8 origin)";
export const CURRENT_VIEW_PRESERVATION_INVENTORY_V1_CONSERVATION_DISPLAY_TUPLE = "((uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) scale, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) timing, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) color, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) interaction, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) motion, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) frameRate)";
export const CURRENT_VIEW_PRESERVATION_INVENTORY_V1_CONSERVATION_REFERENCE_TUPLE = "(uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri)";
export const CURRENT_VIEW_PRESERVATION_INVENTORY_V1_CONSERVATION_INTERVIEW_ENTRY_TUPLE = "(uint8 status, (uint256 chainId, address core, address host, bytes32 recordHash, bytes32 schemaId, bytes32 profileHash, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) payload) record, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) waiverStatement)";
export const CURRENT_VIEW_PRESERVATION_INVENTORY_V1_CONSERVATION_INTERVIEW_RECORD_TUPLE = "(uint256 chainId, address core, address host, bytes32 recordHash, bytes32 schemaId, bytes32 profileHash, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) payload)";
export const CURRENT_VIEW_PRESERVATION_INVENTORY_V1_INTENT_WAIVER_TUPLE = "(bytes32 subjectId, bytes32 profileHash, bytes32 predecessor, (bytes32 artistId, uint64 bindingGeneration, bytes32 bindingHash, uint8 origin) artist, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) waiverStatement, (uint8 status, (uint256 chainId, address core, address host, bytes32 recordHash, bytes32 schemaId, bytes32 profileHash, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) payload) record, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) waiverStatement) interview)";
export const CURRENT_VIEW_PRESERVATION_INVENTORY_V1_INTERVIEW_TUPLE = "(bytes32 subjectId, bytes32 profileHash, bytes32 predecessor, (uint8 kind, string name, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) document) instrument, (uint8 role, string otherRole, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) identity)[] participants, uint32 interviewDate, string[] languages, ((uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) content, (uint8 kind, bytes32 formatId, string puid, (string name, (bytes32 entryId, uint8 kind, string puid, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) specification)[] entries, bytes32 selectedEntryId) catalog) format) transcript, (uint8 kind, ((uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) content, (uint8 kind, bytes32 formatId, string puid, (string name, (bytes32 entryId, uint8 kind, string puid, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) specification)[] entries, bytes32 selectedEntryId) catalog) format) payload)[] captures)";
export const CURRENT_VIEW_PRESERVATION_INVENTORY_V1_CONSERVATION_INSTRUMENT_TUPLE = "(uint8 kind, string name, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) document)";
export const CURRENT_VIEW_PRESERVATION_INVENTORY_V1_CONSERVATION_PARTICIPANT_TUPLE = "(uint8 role, string otherRole, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) identity)";
export const CURRENT_VIEW_PRESERVATION_INVENTORY_V1_CONSERVATION_PAYLOAD_TUPLE = "((uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) content, (uint8 kind, bytes32 formatId, string puid, (string name, (bytes32 entryId, uint8 kind, string puid, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) specification)[] entries, bytes32 selectedEntryId) catalog) format)";
export const CURRENT_VIEW_PRESERVATION_INVENTORY_V1_CONSERVATION_FORMAT_TUPLE = "(uint8 kind, bytes32 formatId, string puid, (string name, (bytes32 entryId, uint8 kind, string puid, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) specification)[] entries, bytes32 selectedEntryId) catalog)";
export const CURRENT_VIEW_PRESERVATION_INVENTORY_V1_CONSERVATION_CATALOG_TUPLE = "(string name, (bytes32 entryId, uint8 kind, string puid, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) specification)[] entries, bytes32 selectedEntryId)";
export const CURRENT_VIEW_PRESERVATION_INVENTORY_V1_CONSERVATION_CATALOG_ENTRY_TUPLE = "(bytes32 entryId, uint8 kind, string puid, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) specification)";
export const CURRENT_VIEW_PRESERVATION_INVENTORY_V1_CONSERVATION_CAPTURE_TUPLE = "(uint8 kind, ((uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) content, (uint8 kind, bytes32 formatId, string puid, (string name, (bytes32 entryId, uint8 kind, string puid, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) specification)[] entries, bytes32 selectedEntryId) catalog) format) payload)";
export const CURRENT_VIEW_PRESERVATION_INVENTORY_V1_STATEMENT_TUPLE = "(bytes32 subjectId, bytes32 profileHash, uint8 basis, (uint8 kind, bytes32 artistId, string name, address account, bytes32 instrumentDigest) licensor, ((uint8 status, (uint8 kind, string text, (bool exists, string uri, bytes32 digest) document) conditions, string extension) aiTraining, (uint8 status, (uint8 kind, string text, (bool exists, string uri, bytes32 digest) document) conditions, string extension) derivative, (uint8 status, (uint8 kind, string text, (bool exists, string uri, bytes32 digest) document) conditions, string extension) exhibition, (uint8 status, (uint8 kind, string text, (bool exists, string uri, bytes32 digest) document) conditions, string extension) print, (uint8 status, (uint8 kind, string text, (bool exists, string uri, bytes32 digest) document) conditions, string extension) publication, (uint8 status, (uint8 kind, string text, (bool exists, string uri, bytes32 digest) document) conditions, string extension) reproduction) grants, uint32 startDate, uint32 endDate, bool openEnd, (bool exists, string uri, bytes32 digest) instrument, bool hasAiTrainingPermission, uint8 aiTrainingPermission, bytes32 predecessor)";
export const CURRENT_VIEW_PRESERVATION_INVENTORY_V1_RIGHTS_LICENSOR_TUPLE = "(uint8 kind, bytes32 artistId, string name, address account, bytes32 instrumentDigest)";
export const CURRENT_VIEW_PRESERVATION_INVENTORY_V1_RIGHTS_GRANTS_TUPLE = "((uint8 status, (uint8 kind, string text, (bool exists, string uri, bytes32 digest) document) conditions, string extension) aiTraining, (uint8 status, (uint8 kind, string text, (bool exists, string uri, bytes32 digest) document) conditions, string extension) derivative, (uint8 status, (uint8 kind, string text, (bool exists, string uri, bytes32 digest) document) conditions, string extension) exhibition, (uint8 status, (uint8 kind, string text, (bool exists, string uri, bytes32 digest) document) conditions, string extension) print, (uint8 status, (uint8 kind, string text, (bool exists, string uri, bytes32 digest) document) conditions, string extension) publication, (uint8 status, (uint8 kind, string text, (bool exists, string uri, bytes32 digest) document) conditions, string extension) reproduction)";
export const CURRENT_VIEW_PRESERVATION_INVENTORY_V1_RIGHTS_GRANT_TUPLE = "(uint8 status, (uint8 kind, string text, (bool exists, string uri, bytes32 digest) document) conditions, string extension)";
export const CURRENT_VIEW_PRESERVATION_INVENTORY_V1_RIGHTS_CONDITIONS_TUPLE = "(uint8 kind, string text, (bool exists, string uri, bytes32 digest) document)";
export const CURRENT_VIEW_PRESERVATION_INVENTORY_V1_RIGHTS_DOCUMENT_TUPLE = "(bool exists, string uri, bytes32 digest)";
export const CURRENT_VIEW_PRESERVATION_INVENTORY_V1_ROOT_AGGREGATE_TUPLE = "(uint64 revision, bytes32 transitionChain)";
export const CURRENT_VIEW_PRESERVATION_INVENTORY_V1_DESCRIPTION_TUPLE = "(bytes32 subjectId, bytes32 profileHash, bytes32 predecessor, uint8 form, (string title, (uint8 kind, bytes32 artistId, uint64 bindingGeneration, bytes32 bindingHash, string name) creator, (uint8 kind, uint32 start, uint32 end) creation, string medium, (uint8 kind, bytes32 formatId, string puid, (string name, (bytes32 entryId, uint8 kind, string puid, (string uri, bytes32 digest) specification)[] entries, bytes32 selectedEntryId) catalog) format, (uint8 kind, bool hasPixels, uint256 width, uint256 height, bool hasAspectRatio, (uint256 numerator, uint256 denominator) aspectRatio, bool hasDuration, (uint256 numerator, uint256 denominator) durationSeconds) measurements, (uint8 kind, uint256 number, uint256 total, string statement) edition, string creditLine, bool hasInscription, string inscription, string[] alternateTitles, (uint8 field, uint8 alternateTitleIndex, string language, string value)[] languageVariants, (uint8 role, uint8 authority, string identifier)[] authorityReferences) full, (string reason, uint32 date) absence)";
export const CURRENT_VIEW_PRESERVATION_INVENTORY_V1_WORK_FULL_DESCRIPTION_TUPLE = "(string title, (uint8 kind, bytes32 artistId, uint64 bindingGeneration, bytes32 bindingHash, string name) creator, (uint8 kind, uint32 start, uint32 end) creation, string medium, (uint8 kind, bytes32 formatId, string puid, (string name, (bytes32 entryId, uint8 kind, string puid, (string uri, bytes32 digest) specification)[] entries, bytes32 selectedEntryId) catalog) format, (uint8 kind, bool hasPixels, uint256 width, uint256 height, bool hasAspectRatio, (uint256 numerator, uint256 denominator) aspectRatio, bool hasDuration, (uint256 numerator, uint256 denominator) durationSeconds) measurements, (uint8 kind, uint256 number, uint256 total, string statement) edition, string creditLine, bool hasInscription, string inscription, string[] alternateTitles, (uint8 field, uint8 alternateTitleIndex, string language, string value)[] languageVariants, (uint8 role, uint8 authority, string identifier)[] authorityReferences)";
export const CURRENT_VIEW_PRESERVATION_INVENTORY_V1_WORK_CREATOR_TUPLE = "(uint8 kind, bytes32 artistId, uint64 bindingGeneration, bytes32 bindingHash, string name)";
export const CURRENT_VIEW_PRESERVATION_INVENTORY_V1_WORK_CREATION_TUPLE = "(uint8 kind, uint32 start, uint32 end)";
export const CURRENT_VIEW_PRESERVATION_INVENTORY_V1_WORK_FORMAT_TUPLE = "(uint8 kind, bytes32 formatId, string puid, (string name, (bytes32 entryId, uint8 kind, string puid, (string uri, bytes32 digest) specification)[] entries, bytes32 selectedEntryId) catalog)";
export const CURRENT_VIEW_PRESERVATION_INVENTORY_V1_WORK_CATALOG_TUPLE = "(string name, (bytes32 entryId, uint8 kind, string puid, (string uri, bytes32 digest) specification)[] entries, bytes32 selectedEntryId)";
export const CURRENT_VIEW_PRESERVATION_INVENTORY_V1_WORK_CATALOG_ENTRY_TUPLE = "(bytes32 entryId, uint8 kind, string puid, (string uri, bytes32 digest) specification)";
export const CURRENT_VIEW_PRESERVATION_INVENTORY_V1_WORK_SPECIFICATION_TUPLE = "(string uri, bytes32 digest)";
export const CURRENT_VIEW_PRESERVATION_INVENTORY_V1_WORK_MEASUREMENTS_TUPLE = "(uint8 kind, bool hasPixels, uint256 width, uint256 height, bool hasAspectRatio, (uint256 numerator, uint256 denominator) aspectRatio, bool hasDuration, (uint256 numerator, uint256 denominator) durationSeconds)";
export const CURRENT_VIEW_PRESERVATION_INVENTORY_V1_WORK_RATIONAL_TUPLE = "(uint256 numerator, uint256 denominator)";
export const CURRENT_VIEW_PRESERVATION_INVENTORY_V1_WORK_EDITION_TUPLE = "(uint8 kind, uint256 number, uint256 total, string statement)";
export const CURRENT_VIEW_PRESERVATION_INVENTORY_V1_WORK_LANGUAGE_VARIANT_TUPLE = "(uint8 field, uint8 alternateTitleIndex, string language, string value)";
export const CURRENT_VIEW_PRESERVATION_INVENTORY_V1_WORK_AUTHORITY_REFERENCE_TUPLE = "(uint8 role, uint8 authority, string identifier)";
export const CURRENT_VIEW_PRESERVATION_INVENTORY_V1_WORK_ABSENCE_TUPLE = "(string reason, uint32 date)";
export const CURRENT_VIEW_PRESERVATION_INVENTORY_V1_PLAN_TUPLE = "((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, (uint256 collectionId, bytes32 subject, bytes32 artistId, bytes32 sourceContextHash, uint64 tokenCount, uint64 nextToken, uint64 segmentCount, uint64 itemCount, bytes32 segmentChainHash, uint16 completedStages, bytes32 renderCriticalEvidenceHash) progress, uint64 nativeCursor, uint64 nativeCount, uint64 referenceCursor, uint64 referenceCount)";
export const CURRENT_VIEW_PRESERVATION_INVENTORY_V1_PROGRESS_TUPLE = "(uint256 collectionId, bytes32 subject, bytes32 artistId, bytes32 sourceContextHash, uint64 tokenCount, uint64 nextToken, uint64 segmentCount, uint64 itemCount, bytes32 segmentChainHash, uint16 completedStages, bytes32 renderCriticalEvidenceHash)";
export const CURRENT_VIEW_PRESERVATION_INVENTORY_V1_CONTEXT_TUPLE = "((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, bytes32 subject, bytes32 artistId, (bytes32 recordHash, bytes32 scopeSubject, bytes32 predecessor, uint64 revision, bytes32 chainHash, bytes32 manifestHash, uint32 manifestBytes, bytes32 sourceHash, address publisher, uint8 authorizationClass, uint64 grantRevision, uint8 displayAuthorizationClass, uint64 displayGrantRevision, uint64 recordedAt, bytes32 schemaHash, bytes32 profileHash, bytes32 canonicalizationHash) snapshot, (bytes32 scopeSubject, (bytes32 recordHash, bytes32 recordChainHash, uint256 collectionId, bytes32 referenceId, bytes32 predecessor, uint64 revision, bytes32 payloadHash, uint32 payloadBytes, bytes32 sourcesHash, bytes32 snapshotRecordHash, uint64 snapshotRevision, address recorder, uint8 authorizationClass, uint64 grantRevision, uint64 effectiveAt, uint64 recordedAt, bytes32 reasonHash, bytes32 schemaHash, bytes32 profileHash, bytes32 canonicalizationHash) observation) referenceRender, (bytes32 scopeSubject, bytes32 workDescriptionRecordHash, bytes32 rightsStatementRecordHash, bytes32 workPayloadHash, bytes32 rightsPayloadHash, bytes32 workSelectionHash, bytes32 rightsSelectionHash, uint64 workRevision, uint64 rightsRevision) descriptions, ((bytes32 recordHash, uint8 kind, bytes32 payloadHash, address recorder, uint64 recordedAt, uint64 recordIndex, bytes32 recordChainHash, bytes32 receiptHash, (bytes32 attestationRecordHash, bytes32 artistId, bytes32 bindingHash, uint64 bindingGeneration, address signer, uint8 authorityClass, uint32 requiredCapability, uint64 signedAt, bytes32 publicationHash) publication, bytes32 publicationEvidenceHash) record, (bytes32 artistId, bytes32 bindingHash, uint64 generation, bytes32 identityRecordHash) association, uint8 origin, uint8 interviewStatus, (bytes32 recordHash, uint8 kind, bytes32 payloadHash, address recorder, uint64 recordedAt, uint64 recordIndex, bytes32 recordChainHash, bytes32 receiptHash, (bytes32 attestationRecordHash, bytes32 artistId, bytes32 bindingHash, uint64 bindingGeneration, address signer, uint8 authorityClass, uint32 requiredCapability, uint64 signedAt, bytes32 publicationHash) publication, bytes32 publicationEvidenceHash) interview, bytes32 interviewArchiveReferenceHash, uint8 interviewPayloadCorrespondence, bytes32 predecessor, address submitter, uint64 revision, uint64 selectedAt, bytes32 catalogsHash, bytes32 selectionHash) conservation, bytes32 interviewEvidenceHash, bytes32 nativeHash, bytes32 rootRecordHash, bytes32 tokenInventoryHash, bytes32 checkpointHash, bytes32 outputManifestRecord, bytes32 adoptionRecord, bytes32 viewId, bytes32 payloadHash, bytes32 sourceContextHash, bytes32 policyChainHash, bytes32 outputRoot, bytes32 manifestIndexHash, uint64 tokenCount)";
export const CURRENT_VIEW_PRESERVATION_INVENTORY_V1_SNAPSHOT_RECEIPT_TUPLE = "(bytes32 recordHash, bytes32 scopeSubject, bytes32 predecessor, uint64 revision, bytes32 chainHash, bytes32 manifestHash, uint32 manifestBytes, bytes32 sourceHash, address publisher, uint8 authorizationClass, uint64 grantRevision, uint8 displayAuthorizationClass, uint64 displayGrantRevision, uint64 recordedAt, bytes32 schemaHash, bytes32 profileHash, bytes32 canonicalizationHash)";
export const CURRENT_VIEW_PRESERVATION_INVENTORY_V1_REFERENCE_RECEIPT_TUPLE = "(bytes32 scopeSubject, (bytes32 recordHash, bytes32 recordChainHash, uint256 collectionId, bytes32 referenceId, bytes32 predecessor, uint64 revision, bytes32 payloadHash, uint32 payloadBytes, bytes32 sourcesHash, bytes32 snapshotRecordHash, uint64 snapshotRevision, address recorder, uint8 authorizationClass, uint64 grantRevision, uint64 effectiveAt, uint64 recordedAt, bytes32 reasonHash, bytes32 schemaHash, bytes32 profileHash, bytes32 canonicalizationHash) observation)";
export const CURRENT_VIEW_PRESERVATION_INVENTORY_V1_REFERENCE_OBSERVATION_TUPLE = "(bytes32 recordHash, bytes32 recordChainHash, uint256 collectionId, bytes32 referenceId, bytes32 predecessor, uint64 revision, bytes32 payloadHash, uint32 payloadBytes, bytes32 sourcesHash, bytes32 snapshotRecordHash, uint64 snapshotRevision, address recorder, uint8 authorizationClass, uint64 grantRevision, uint64 effectiveAt, uint64 recordedAt, bytes32 reasonHash, bytes32 schemaHash, bytes32 profileHash, bytes32 canonicalizationHash)";
export const CURRENT_VIEW_PRESERVATION_INVENTORY_V1_DESCRIPTION_EVIDENCE_TUPLE = "(bytes32 scopeSubject, bytes32 workDescriptionRecordHash, bytes32 rightsStatementRecordHash, bytes32 workPayloadHash, bytes32 rightsPayloadHash, bytes32 workSelectionHash, bytes32 rightsSelectionHash, uint64 workRevision, uint64 rightsRevision)";
export const CURRENT_VIEW_PRESERVATION_INVENTORY_V1_CONSERVATION_SELECTION_TUPLE = "((bytes32 recordHash, uint8 kind, bytes32 payloadHash, address recorder, uint64 recordedAt, uint64 recordIndex, bytes32 recordChainHash, bytes32 receiptHash, (bytes32 attestationRecordHash, bytes32 artistId, bytes32 bindingHash, uint64 bindingGeneration, address signer, uint8 authorityClass, uint32 requiredCapability, uint64 signedAt, bytes32 publicationHash) publication, bytes32 publicationEvidenceHash) record, (bytes32 artistId, bytes32 bindingHash, uint64 generation, bytes32 identityRecordHash) association, uint8 origin, uint8 interviewStatus, (bytes32 recordHash, uint8 kind, bytes32 payloadHash, address recorder, uint64 recordedAt, uint64 recordIndex, bytes32 recordChainHash, bytes32 receiptHash, (bytes32 attestationRecordHash, bytes32 artistId, bytes32 bindingHash, uint64 bindingGeneration, address signer, uint8 authorityClass, uint32 requiredCapability, uint64 signedAt, bytes32 publicationHash) publication, bytes32 publicationEvidenceHash) interview, bytes32 interviewArchiveReferenceHash, uint8 interviewPayloadCorrespondence, bytes32 predecessor, address submitter, uint64 revision, uint64 selectedAt, bytes32 catalogsHash, bytes32 selectionHash)";
export const CURRENT_VIEW_PRESERVATION_INVENTORY_V1_CONSERVATION_RECORD_EVIDENCE_TUPLE = "(bytes32 recordHash, uint8 kind, bytes32 payloadHash, address recorder, uint64 recordedAt, uint64 recordIndex, bytes32 recordChainHash, bytes32 receiptHash, (bytes32 attestationRecordHash, bytes32 artistId, bytes32 bindingHash, uint64 bindingGeneration, address signer, uint8 authorityClass, uint32 requiredCapability, uint64 signedAt, bytes32 publicationHash) publication, bytes32 publicationEvidenceHash)";
export const CURRENT_VIEW_PRESERVATION_INVENTORY_V1_PUBLICATION_EVIDENCE_TUPLE = "(bytes32 attestationRecordHash, bytes32 artistId, bytes32 bindingHash, uint64 bindingGeneration, address signer, uint8 authorityClass, uint32 requiredCapability, uint64 signedAt, bytes32 publicationHash)";
export const CURRENT_VIEW_PRESERVATION_INVENTORY_V1_CONSERVATION_ASSOCIATION_TUPLE = "(bytes32 artistId, bytes32 bindingHash, uint64 generation, bytes32 identityRecordHash)";
export const CURRENT_VIEW_PRESERVATION_INVENTORY_V1_TOKEN_PROGRESS_TUPLE = "(uint8 phase, uint64 row, uint64 count)";

export const CURRENT_VIEW_PRESERVATION_INVENTORY_V1_ABI = Object.freeze([
  "error InvalidInventorySegment()",
  "error InventoryIncomplete()",
  "error InventorySourceChanged()",
  "event ViewPreservationInventoryCompleted(uint16 schemaVersion, bytes32 indexed id, bytes32 indexed evidenceHash, ((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, (bytes32 planId, uint256 collectionId, bytes32 scopeSubject, bytes32 artistId, (bytes32 rootRecordHash, bytes32 snapshotRecordHash, bytes32 referenceRenderRecordHash, bytes32 intentRecordHash, bytes32 intentWaiverRecordHash, bytes32 interviewEvidenceHash, bytes32 rightsStatementRecordHash, bytes32 workDescriptionRecordHash) originals, bytes32 sourceContextHash, bytes32 tokenInventoryHash, uint64 tokenCount, uint64 segmentCount, uint64 itemCount, bytes32 segmentChainHash, bytes32 renderCriticalEvidenceHash) inventory) evidence)",
  "event ViewPreservationInventorySegmentRecorded(uint16 schemaVersion, bytes32 indexed id, uint64 indexed index, (bytes32 key, uint64 itemCount, bytes32 firstLink, bytes32 sourceWitnessHash) segment, (uint8 kind, bytes32 role, address source, bytes32 sourceRecord, uint256 sourceIndex, uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri, uint64 byteSize, bytes32 schemaId, bytes32 formatId, bytes32 catalogId, bytes32 catalogHash, bytes32 objectHash, bytes32 originalCoverageHash, bytes32 provenanceHash)[] items)",
  "event ViewPreservationInventoryStarted(uint16 schemaVersion, bytes32 indexed id, (uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, bytes32 contextHash)",
  "function appendArtwork(bytes32 id)",
  "function appendDefinition(bytes32 id)",
  "function appendIntent(bytes32, (bytes32 subjectId, bytes32 profileHash, bytes32 predecessor, (bytes32 artistId, uint64 bindingGeneration, bytes32 bindingHash, uint8 origin) artist, ((uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) scale, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) timing, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) color, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) interaction, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) motion, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) frameRate) display, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) variabilityTolerances, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) dependencyAging, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) significantProperties, (uint8 status, (uint256 chainId, address core, address host, bytes32 recordHash, bytes32 schemaId, bytes32 profileHash, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) payload) record, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) waiverStatement) interview), address)",
  "function appendIntentWaiver(bytes32, (bytes32 subjectId, bytes32 profileHash, bytes32 predecessor, (bytes32 artistId, uint64 bindingGeneration, bytes32 bindingHash, uint8 origin) artist, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) waiverStatement, (uint8 status, (uint256 chainId, address core, address host, bytes32 recordHash, bytes32 schemaId, bytes32 profileHash, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) payload) record, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) waiverStatement) interview), address)",
  "function appendInterview(bytes32, (bytes32 subjectId, bytes32 profileHash, bytes32 predecessor, (uint8 kind, string name, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) document) instrument, (uint8 role, string otherRole, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) identity)[] participants, uint32 interviewDate, string[] languages, ((uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) content, (uint8 kind, bytes32 formatId, string puid, (string name, (bytes32 entryId, uint8 kind, string puid, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) specification)[] entries, bytes32 selectedEntryId) catalog) format) transcript, (uint8 kind, ((uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) content, (uint8 kind, bytes32 formatId, string puid, (string name, (bytes32 entryId, uint8 kind, string puid, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) specification)[] entries, bytes32 selectedEntryId) catalog) format) payload)[] captures), address)",
  "function appendInterviewWaiver(bytes32 id)",
  "function appendNative(bytes32 id, uint64 maximum)",
  "function appendPreservationAdmission(bytes32 id)",
  "function appendReference(bytes32 id, uint64 maximum)",
  "function appendRenderer(bytes32 id)",
  "function appendRights(bytes32, (bytes32 subjectId, bytes32 profileHash, uint8 basis, (uint8 kind, bytes32 artistId, string name, address account, bytes32 instrumentDigest) licensor, ((uint8 status, (uint8 kind, string text, (bool exists, string uri, bytes32 digest) document) conditions, string extension) aiTraining, (uint8 status, (uint8 kind, string text, (bool exists, string uri, bytes32 digest) document) conditions, string extension) derivative, (uint8 status, (uint8 kind, string text, (bool exists, string uri, bytes32 digest) document) conditions, string extension) exhibition, (uint8 status, (uint8 kind, string text, (bool exists, string uri, bytes32 digest) document) conditions, string extension) print, (uint8 status, (uint8 kind, string text, (bool exists, string uri, bytes32 digest) document) conditions, string extension) publication, (uint8 status, (uint8 kind, string text, (bool exists, string uri, bytes32 digest) document) conditions, string extension) reproduction) grants, uint32 startDate, uint32 endDate, bool openEnd, (bool exists, string uri, bytes32 digest) instrument, bool hasAiTrainingPermission, uint8 aiTrainingPermission, bytes32 predecessor))",
  "function appendRootAuthorization(bytes32 id, address actor, uint64 observedAt, (uint64 revision, bytes32 transitionChain) originalAggregate, bytes32 originalLegacyFamilyHash)",
  "function appendTokenOutput(bytes32 id)",
  "function appendWork(bytes32, (bytes32 subjectId, bytes32 profileHash, bytes32 predecessor, uint8 form, (string title, (uint8 kind, bytes32 artistId, uint64 bindingGeneration, bytes32 bindingHash, string name) creator, (uint8 kind, uint32 start, uint32 end) creation, string medium, (uint8 kind, bytes32 formatId, string puid, (string name, (bytes32 entryId, uint8 kind, string puid, (string uri, bytes32 digest) specification)[] entries, bytes32 selectedEntryId) catalog) format, (uint8 kind, bool hasPixels, uint256 width, uint256 height, bool hasAspectRatio, (uint256 numerator, uint256 denominator) aspectRatio, bool hasDuration, (uint256 numerator, uint256 denominator) durationSeconds) measurements, (uint8 kind, uint256 number, uint256 total, string statement) edition, string creditLine, bool hasInscription, string inscription, string[] alternateTitles, (uint8 field, uint8 alternateTitleIndex, string language, string value)[] languageVariants, (uint8 role, uint8 authority, string identifier)[] authorityReferences) full, (string reason, uint32 date) absence), address)",
  "function artifactCoverage() view returns (address)",
  "function beginInventory((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope) returns (bytes32 id)",
  "function core() view returns (address)",
  "function dependencies() view returns ((address[12] targets, bytes32[12] codeHashes, address[5] artistTargets, bytes32[5] artistCodeHashes, address artistContentOwner, bytes32 artistContentOwnerCodeHash, uint256 chainId, uint256 readGas, uint256 sourceGas, uint256 selectionGas, uint256 snapshotGas, uint256 referenceGas))",
  "function dependencyHash() view returns (bytes32)",
  "function externalCoverage() view returns (address)",
  "function inventoryEvidence(bytes32 id) view returns (((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, (bytes32 planId, uint256 collectionId, bytes32 scopeSubject, bytes32 artistId, (bytes32 rootRecordHash, bytes32 snapshotRecordHash, bytes32 referenceRenderRecordHash, bytes32 intentRecordHash, bytes32 intentWaiverRecordHash, bytes32 interviewEvidenceHash, bytes32 rightsStatementRecordHash, bytes32 workDescriptionRecordHash) originals, bytes32 sourceContextHash, bytes32 tokenInventoryHash, uint64 tokenCount, uint64 segmentCount, uint64 itemCount, bytes32 segmentChainHash, bytes32 renderCriticalEvidenceHash) inventory) e)",
  "function inventoryProfile() pure returns (bytes32)",
  "function inventorySegment(bytes32 id, uint64 index) view returns ((bytes32 key, uint64 itemCount, bytes32 firstLink, bytes32 sourceWitnessHash))",
  "function metadataHost() view returns (address)",
  "function metadataRouter() view returns (address)",
  "function plan(bytes32 id) view returns (((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, (uint256 collectionId, bytes32 subject, bytes32 artistId, bytes32 sourceContextHash, uint64 tokenCount, uint64 nextToken, uint64 segmentCount, uint64 itemCount, bytes32 segmentChainHash, uint16 completedStages, bytes32 renderCriticalEvidenceHash) progress, uint64 nativeCursor, uint64 nativeCount, uint64 referenceCursor, uint64 referenceCount))",
  "function referencePublisher() view returns (address)",
  "function requireCurrent((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope) view returns (((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, (bytes32 planId, uint256 collectionId, bytes32 scopeSubject, bytes32 artistId, (bytes32 rootRecordHash, bytes32 snapshotRecordHash, bytes32 referenceRenderRecordHash, bytes32 intentRecordHash, bytes32 intentWaiverRecordHash, bytes32 interviewEvidenceHash, bytes32 rightsStatementRecordHash, bytes32 workDescriptionRecordHash) originals, bytes32 sourceContextHash, bytes32 tokenInventoryHash, uint64 tokenCount, uint64 segmentCount, uint64 itemCount, bytes32 segmentChainHash, bytes32 renderCriticalEvidenceHash) inventory) e)",
  "function requireFullDefinitionBytes(bytes32 id) view",
  "function retrievalWitnessBinding() view returns (address, bytes32)",
  "function sealInventory(bytes32 id) returns (((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, (bytes32 planId, uint256 collectionId, bytes32 scopeSubject, bytes32 artistId, (bytes32 rootRecordHash, bytes32 snapshotRecordHash, bytes32 referenceRenderRecordHash, bytes32 intentRecordHash, bytes32 intentWaiverRecordHash, bytes32 interviewEvidenceHash, bytes32 rightsStatementRecordHash, bytes32 workDescriptionRecordHash) originals, bytes32 sourceContextHash, bytes32 tokenInventoryHash, uint64 tokenCount, uint64 segmentCount, uint64 itemCount, bytes32 segmentChainHash, bytes32 renderCriticalEvidenceHash) inventory) evidence)",
  "function snapshots() view returns (address)",
  "function sourceContext(bytes32 id) view returns (((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, bytes32 subject, bytes32 artistId, (bytes32 recordHash, bytes32 scopeSubject, bytes32 predecessor, uint64 revision, bytes32 chainHash, bytes32 manifestHash, uint32 manifestBytes, bytes32 sourceHash, address publisher, uint8 authorizationClass, uint64 grantRevision, uint8 displayAuthorizationClass, uint64 displayGrantRevision, uint64 recordedAt, bytes32 schemaHash, bytes32 profileHash, bytes32 canonicalizationHash) snapshot, (bytes32 scopeSubject, (bytes32 recordHash, bytes32 recordChainHash, uint256 collectionId, bytes32 referenceId, bytes32 predecessor, uint64 revision, bytes32 payloadHash, uint32 payloadBytes, bytes32 sourcesHash, bytes32 snapshotRecordHash, uint64 snapshotRevision, address recorder, uint8 authorizationClass, uint64 grantRevision, uint64 effectiveAt, uint64 recordedAt, bytes32 reasonHash, bytes32 schemaHash, bytes32 profileHash, bytes32 canonicalizationHash) observation) referenceRender, (bytes32 scopeSubject, bytes32 workDescriptionRecordHash, bytes32 rightsStatementRecordHash, bytes32 workPayloadHash, bytes32 rightsPayloadHash, bytes32 workSelectionHash, bytes32 rightsSelectionHash, uint64 workRevision, uint64 rightsRevision) descriptions, ((bytes32 recordHash, uint8 kind, bytes32 payloadHash, address recorder, uint64 recordedAt, uint64 recordIndex, bytes32 recordChainHash, bytes32 receiptHash, (bytes32 attestationRecordHash, bytes32 artistId, bytes32 bindingHash, uint64 bindingGeneration, address signer, uint8 authorityClass, uint32 requiredCapability, uint64 signedAt, bytes32 publicationHash) publication, bytes32 publicationEvidenceHash) record, (bytes32 artistId, bytes32 bindingHash, uint64 generation, bytes32 identityRecordHash) association, uint8 origin, uint8 interviewStatus, (bytes32 recordHash, uint8 kind, bytes32 payloadHash, address recorder, uint64 recordedAt, uint64 recordIndex, bytes32 recordChainHash, bytes32 receiptHash, (bytes32 attestationRecordHash, bytes32 artistId, bytes32 bindingHash, uint64 bindingGeneration, address signer, uint8 authorityClass, uint32 requiredCapability, uint64 signedAt, bytes32 publicationHash) publication, bytes32 publicationEvidenceHash) interview, bytes32 interviewArchiveReferenceHash, uint8 interviewPayloadCorrespondence, bytes32 predecessor, address submitter, uint64 revision, uint64 selectedAt, bytes32 catalogsHash, bytes32 selectionHash) conservation, bytes32 interviewEvidenceHash, bytes32 nativeHash, bytes32 rootRecordHash, bytes32 tokenInventoryHash, bytes32 checkpointHash, bytes32 outputManifestRecord, bytes32 adoptionRecord, bytes32 viewId, bytes32 payloadHash, bytes32 sourceContextHash, bytes32 policyChainHash, bytes32 outputRoot, bytes32 manifestIndexHash, uint64 tokenCount))",
  "function supportsInterface(bytes4 id) pure returns (bool)",
  "function tokenProgress(bytes32 id) view returns ((uint8 phase, uint64 row, uint64 count))",
] as const);
export function currentViewPreservationInventoryV1Interface(): Interface {
  return new Interface(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_ABI);
}

export function normalizeCurrentViewPreservationInventoryV1Dependencies(value: CurrentViewPreservationInventoryV1Dependencies): CurrentViewPreservationInventoryV1Dependencies {
  return normalize(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_DEPENDENCIES_TUPLE, value);
}
export function encodeCurrentViewPreservationInventoryV1Dependencies(value: CurrentViewPreservationInventoryV1Dependencies): Hex {
  return encode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_DEPENDENCIES_TUPLE, value);
}
export function decodeCurrentViewPreservationInventoryV1Dependencies(value: Hex): CurrentViewPreservationInventoryV1Dependencies {
  return decode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_DEPENDENCIES_TUPLE, value);
}

export function normalizeCurrentViewPreservationInventoryV1Evidence(value: CurrentViewPreservationInventoryV1Evidence): CurrentViewPreservationInventoryV1Evidence {
  return normalize(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_EVIDENCE_TUPLE, value);
}
export function encodeCurrentViewPreservationInventoryV1Evidence(value: CurrentViewPreservationInventoryV1Evidence): Hex {
  return encode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_EVIDENCE_TUPLE, value);
}
export function decodeCurrentViewPreservationInventoryV1Evidence(value: Hex): CurrentViewPreservationInventoryV1Evidence {
  return decode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_EVIDENCE_TUPLE, value);
}

export function normalizeCurrentViewPreservationInventoryV1Scope(value: CurrentViewPreservationInventoryV1Scope): CurrentViewPreservationInventoryV1Scope {
  return normalize(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_SCOPE_TUPLE, value);
}
export function encodeCurrentViewPreservationInventoryV1Scope(value: CurrentViewPreservationInventoryV1Scope): Hex {
  return encode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_SCOPE_TUPLE, value);
}
export function decodeCurrentViewPreservationInventoryV1Scope(value: Hex): CurrentViewPreservationInventoryV1Scope {
  return decode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_SCOPE_TUPLE, value);
}

export function normalizeCurrentViewPreservationInventoryV1OriginalEvidence(value: CurrentViewPreservationInventoryV1OriginalEvidence): CurrentViewPreservationInventoryV1OriginalEvidence {
  return normalize(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_ORIGINAL_EVIDENCE_TUPLE, value);
}
export function encodeCurrentViewPreservationInventoryV1OriginalEvidence(value: CurrentViewPreservationInventoryV1OriginalEvidence): Hex {
  return encode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_ORIGINAL_EVIDENCE_TUPLE, value);
}
export function decodeCurrentViewPreservationInventoryV1OriginalEvidence(value: Hex): CurrentViewPreservationInventoryV1OriginalEvidence {
  return decode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_ORIGINAL_EVIDENCE_TUPLE, value);
}

export function normalizeCurrentViewPreservationInventoryV1OriginalInputs(value: CurrentViewPreservationInventoryV1OriginalInputs): CurrentViewPreservationInventoryV1OriginalInputs {
  return normalize(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_ORIGINAL_INPUTS_TUPLE, value);
}
export function encodeCurrentViewPreservationInventoryV1OriginalInputs(value: CurrentViewPreservationInventoryV1OriginalInputs): Hex {
  return encode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_ORIGINAL_INPUTS_TUPLE, value);
}
export function decodeCurrentViewPreservationInventoryV1OriginalInputs(value: Hex): CurrentViewPreservationInventoryV1OriginalInputs {
  return decode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_ORIGINAL_INPUTS_TUPLE, value);
}

export function normalizeCurrentViewPreservationInventoryV1Segment(value: CurrentViewPreservationInventoryV1Segment): CurrentViewPreservationInventoryV1Segment {
  return normalize(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_SEGMENT_TUPLE, value);
}
export function encodeCurrentViewPreservationInventoryV1Segment(value: CurrentViewPreservationInventoryV1Segment): Hex {
  return encode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_SEGMENT_TUPLE, value);
}
export function decodeCurrentViewPreservationInventoryV1Segment(value: Hex): CurrentViewPreservationInventoryV1Segment {
  return decode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_SEGMENT_TUPLE, value);
}

export function normalizeCurrentViewPreservationInventoryV1Item(value: CurrentViewPreservationInventoryV1Item): CurrentViewPreservationInventoryV1Item {
  return normalize(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_ITEM_TUPLE, value);
}
export function encodeCurrentViewPreservationInventoryV1Item(value: CurrentViewPreservationInventoryV1Item): Hex {
  return encode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_ITEM_TUPLE, value);
}
export function decodeCurrentViewPreservationInventoryV1Item(value: Hex): CurrentViewPreservationInventoryV1Item {
  return decode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_ITEM_TUPLE, value);
}

export function normalizeCurrentViewPreservationInventoryV1Intent(value: CurrentViewPreservationInventoryV1Intent): CurrentViewPreservationInventoryV1Intent {
  return normalize(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_INTENT_TUPLE, value);
}
export function encodeCurrentViewPreservationInventoryV1Intent(value: CurrentViewPreservationInventoryV1Intent): Hex {
  return encode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_INTENT_TUPLE, value);
}
export function decodeCurrentViewPreservationInventoryV1Intent(value: Hex): CurrentViewPreservationInventoryV1Intent {
  return decode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_INTENT_TUPLE, value);
}

export function normalizeCurrentViewPreservationInventoryV1ConservationArtistClaim(value: CurrentViewPreservationInventoryV1ConservationArtistClaim): CurrentViewPreservationInventoryV1ConservationArtistClaim {
  return normalize(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_CONSERVATION_ARTIST_CLAIM_TUPLE, value);
}
export function encodeCurrentViewPreservationInventoryV1ConservationArtistClaim(value: CurrentViewPreservationInventoryV1ConservationArtistClaim): Hex {
  return encode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_CONSERVATION_ARTIST_CLAIM_TUPLE, value);
}
export function decodeCurrentViewPreservationInventoryV1ConservationArtistClaim(value: Hex): CurrentViewPreservationInventoryV1ConservationArtistClaim {
  return decode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_CONSERVATION_ARTIST_CLAIM_TUPLE, value);
}

export function normalizeCurrentViewPreservationInventoryV1ConservationDisplay(value: CurrentViewPreservationInventoryV1ConservationDisplay): CurrentViewPreservationInventoryV1ConservationDisplay {
  return normalize(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_CONSERVATION_DISPLAY_TUPLE, value);
}
export function encodeCurrentViewPreservationInventoryV1ConservationDisplay(value: CurrentViewPreservationInventoryV1ConservationDisplay): Hex {
  return encode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_CONSERVATION_DISPLAY_TUPLE, value);
}
export function decodeCurrentViewPreservationInventoryV1ConservationDisplay(value: Hex): CurrentViewPreservationInventoryV1ConservationDisplay {
  return decode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_CONSERVATION_DISPLAY_TUPLE, value);
}

export function normalizeCurrentViewPreservationInventoryV1ConservationReference(value: CurrentViewPreservationInventoryV1ConservationReference): CurrentViewPreservationInventoryV1ConservationReference {
  return normalize(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_CONSERVATION_REFERENCE_TUPLE, value);
}
export function encodeCurrentViewPreservationInventoryV1ConservationReference(value: CurrentViewPreservationInventoryV1ConservationReference): Hex {
  return encode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_CONSERVATION_REFERENCE_TUPLE, value);
}
export function decodeCurrentViewPreservationInventoryV1ConservationReference(value: Hex): CurrentViewPreservationInventoryV1ConservationReference {
  return decode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_CONSERVATION_REFERENCE_TUPLE, value);
}

export function normalizeCurrentViewPreservationInventoryV1ConservationInterviewEntry(value: CurrentViewPreservationInventoryV1ConservationInterviewEntry): CurrentViewPreservationInventoryV1ConservationInterviewEntry {
  return normalize(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_CONSERVATION_INTERVIEW_ENTRY_TUPLE, value);
}
export function encodeCurrentViewPreservationInventoryV1ConservationInterviewEntry(value: CurrentViewPreservationInventoryV1ConservationInterviewEntry): Hex {
  return encode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_CONSERVATION_INTERVIEW_ENTRY_TUPLE, value);
}
export function decodeCurrentViewPreservationInventoryV1ConservationInterviewEntry(value: Hex): CurrentViewPreservationInventoryV1ConservationInterviewEntry {
  return decode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_CONSERVATION_INTERVIEW_ENTRY_TUPLE, value);
}

export function normalizeCurrentViewPreservationInventoryV1ConservationInterviewRecord(value: CurrentViewPreservationInventoryV1ConservationInterviewRecord): CurrentViewPreservationInventoryV1ConservationInterviewRecord {
  return normalize(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_CONSERVATION_INTERVIEW_RECORD_TUPLE, value);
}
export function encodeCurrentViewPreservationInventoryV1ConservationInterviewRecord(value: CurrentViewPreservationInventoryV1ConservationInterviewRecord): Hex {
  return encode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_CONSERVATION_INTERVIEW_RECORD_TUPLE, value);
}
export function decodeCurrentViewPreservationInventoryV1ConservationInterviewRecord(value: Hex): CurrentViewPreservationInventoryV1ConservationInterviewRecord {
  return decode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_CONSERVATION_INTERVIEW_RECORD_TUPLE, value);
}

export function normalizeCurrentViewPreservationInventoryV1IntentWaiver(value: CurrentViewPreservationInventoryV1IntentWaiver): CurrentViewPreservationInventoryV1IntentWaiver {
  return normalize(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_INTENT_WAIVER_TUPLE, value);
}
export function encodeCurrentViewPreservationInventoryV1IntentWaiver(value: CurrentViewPreservationInventoryV1IntentWaiver): Hex {
  return encode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_INTENT_WAIVER_TUPLE, value);
}
export function decodeCurrentViewPreservationInventoryV1IntentWaiver(value: Hex): CurrentViewPreservationInventoryV1IntentWaiver {
  return decode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_INTENT_WAIVER_TUPLE, value);
}

export function normalizeCurrentViewPreservationInventoryV1Interview(value: CurrentViewPreservationInventoryV1Interview): CurrentViewPreservationInventoryV1Interview {
  return normalize(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_INTERVIEW_TUPLE, value);
}
export function encodeCurrentViewPreservationInventoryV1Interview(value: CurrentViewPreservationInventoryV1Interview): Hex {
  return encode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_INTERVIEW_TUPLE, value);
}
export function decodeCurrentViewPreservationInventoryV1Interview(value: Hex): CurrentViewPreservationInventoryV1Interview {
  return decode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_INTERVIEW_TUPLE, value);
}

export function normalizeCurrentViewPreservationInventoryV1ConservationInstrument(value: CurrentViewPreservationInventoryV1ConservationInstrument): CurrentViewPreservationInventoryV1ConservationInstrument {
  return normalize(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_CONSERVATION_INSTRUMENT_TUPLE, value);
}
export function encodeCurrentViewPreservationInventoryV1ConservationInstrument(value: CurrentViewPreservationInventoryV1ConservationInstrument): Hex {
  return encode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_CONSERVATION_INSTRUMENT_TUPLE, value);
}
export function decodeCurrentViewPreservationInventoryV1ConservationInstrument(value: Hex): CurrentViewPreservationInventoryV1ConservationInstrument {
  return decode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_CONSERVATION_INSTRUMENT_TUPLE, value);
}

export function normalizeCurrentViewPreservationInventoryV1ConservationParticipant(value: CurrentViewPreservationInventoryV1ConservationParticipant): CurrentViewPreservationInventoryV1ConservationParticipant {
  return normalize(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_CONSERVATION_PARTICIPANT_TUPLE, value);
}
export function encodeCurrentViewPreservationInventoryV1ConservationParticipant(value: CurrentViewPreservationInventoryV1ConservationParticipant): Hex {
  return encode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_CONSERVATION_PARTICIPANT_TUPLE, value);
}
export function decodeCurrentViewPreservationInventoryV1ConservationParticipant(value: Hex): CurrentViewPreservationInventoryV1ConservationParticipant {
  return decode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_CONSERVATION_PARTICIPANT_TUPLE, value);
}

export function normalizeCurrentViewPreservationInventoryV1ConservationPayload(value: CurrentViewPreservationInventoryV1ConservationPayload): CurrentViewPreservationInventoryV1ConservationPayload {
  return normalize(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_CONSERVATION_PAYLOAD_TUPLE, value);
}
export function encodeCurrentViewPreservationInventoryV1ConservationPayload(value: CurrentViewPreservationInventoryV1ConservationPayload): Hex {
  return encode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_CONSERVATION_PAYLOAD_TUPLE, value);
}
export function decodeCurrentViewPreservationInventoryV1ConservationPayload(value: Hex): CurrentViewPreservationInventoryV1ConservationPayload {
  return decode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_CONSERVATION_PAYLOAD_TUPLE, value);
}

export function normalizeCurrentViewPreservationInventoryV1ConservationFormat(value: CurrentViewPreservationInventoryV1ConservationFormat): CurrentViewPreservationInventoryV1ConservationFormat {
  return normalize(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_CONSERVATION_FORMAT_TUPLE, value);
}
export function encodeCurrentViewPreservationInventoryV1ConservationFormat(value: CurrentViewPreservationInventoryV1ConservationFormat): Hex {
  return encode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_CONSERVATION_FORMAT_TUPLE, value);
}
export function decodeCurrentViewPreservationInventoryV1ConservationFormat(value: Hex): CurrentViewPreservationInventoryV1ConservationFormat {
  return decode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_CONSERVATION_FORMAT_TUPLE, value);
}

export function normalizeCurrentViewPreservationInventoryV1ConservationCatalog(value: CurrentViewPreservationInventoryV1ConservationCatalog): CurrentViewPreservationInventoryV1ConservationCatalog {
  return normalize(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_CONSERVATION_CATALOG_TUPLE, value);
}
export function encodeCurrentViewPreservationInventoryV1ConservationCatalog(value: CurrentViewPreservationInventoryV1ConservationCatalog): Hex {
  return encode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_CONSERVATION_CATALOG_TUPLE, value);
}
export function decodeCurrentViewPreservationInventoryV1ConservationCatalog(value: Hex): CurrentViewPreservationInventoryV1ConservationCatalog {
  return decode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_CONSERVATION_CATALOG_TUPLE, value);
}

export function normalizeCurrentViewPreservationInventoryV1ConservationCatalogEntry(value: CurrentViewPreservationInventoryV1ConservationCatalogEntry): CurrentViewPreservationInventoryV1ConservationCatalogEntry {
  return normalize(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_CONSERVATION_CATALOG_ENTRY_TUPLE, value);
}
export function encodeCurrentViewPreservationInventoryV1ConservationCatalogEntry(value: CurrentViewPreservationInventoryV1ConservationCatalogEntry): Hex {
  return encode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_CONSERVATION_CATALOG_ENTRY_TUPLE, value);
}
export function decodeCurrentViewPreservationInventoryV1ConservationCatalogEntry(value: Hex): CurrentViewPreservationInventoryV1ConservationCatalogEntry {
  return decode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_CONSERVATION_CATALOG_ENTRY_TUPLE, value);
}

export function normalizeCurrentViewPreservationInventoryV1ConservationCapture(value: CurrentViewPreservationInventoryV1ConservationCapture): CurrentViewPreservationInventoryV1ConservationCapture {
  return normalize(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_CONSERVATION_CAPTURE_TUPLE, value);
}
export function encodeCurrentViewPreservationInventoryV1ConservationCapture(value: CurrentViewPreservationInventoryV1ConservationCapture): Hex {
  return encode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_CONSERVATION_CAPTURE_TUPLE, value);
}
export function decodeCurrentViewPreservationInventoryV1ConservationCapture(value: Hex): CurrentViewPreservationInventoryV1ConservationCapture {
  return decode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_CONSERVATION_CAPTURE_TUPLE, value);
}

export function normalizeCurrentViewPreservationInventoryV1Statement(value: CurrentViewPreservationInventoryV1Statement): CurrentViewPreservationInventoryV1Statement {
  return normalize(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_STATEMENT_TUPLE, value);
}
export function encodeCurrentViewPreservationInventoryV1Statement(value: CurrentViewPreservationInventoryV1Statement): Hex {
  return encode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_STATEMENT_TUPLE, value);
}
export function decodeCurrentViewPreservationInventoryV1Statement(value: Hex): CurrentViewPreservationInventoryV1Statement {
  return decode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_STATEMENT_TUPLE, value);
}

export function normalizeCurrentViewPreservationInventoryV1RightsLicensor(value: CurrentViewPreservationInventoryV1RightsLicensor): CurrentViewPreservationInventoryV1RightsLicensor {
  return normalize(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_RIGHTS_LICENSOR_TUPLE, value);
}
export function encodeCurrentViewPreservationInventoryV1RightsLicensor(value: CurrentViewPreservationInventoryV1RightsLicensor): Hex {
  return encode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_RIGHTS_LICENSOR_TUPLE, value);
}
export function decodeCurrentViewPreservationInventoryV1RightsLicensor(value: Hex): CurrentViewPreservationInventoryV1RightsLicensor {
  return decode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_RIGHTS_LICENSOR_TUPLE, value);
}

export function normalizeCurrentViewPreservationInventoryV1RightsGrants(value: CurrentViewPreservationInventoryV1RightsGrants): CurrentViewPreservationInventoryV1RightsGrants {
  return normalize(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_RIGHTS_GRANTS_TUPLE, value);
}
export function encodeCurrentViewPreservationInventoryV1RightsGrants(value: CurrentViewPreservationInventoryV1RightsGrants): Hex {
  return encode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_RIGHTS_GRANTS_TUPLE, value);
}
export function decodeCurrentViewPreservationInventoryV1RightsGrants(value: Hex): CurrentViewPreservationInventoryV1RightsGrants {
  return decode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_RIGHTS_GRANTS_TUPLE, value);
}

export function normalizeCurrentViewPreservationInventoryV1RightsGrant(value: CurrentViewPreservationInventoryV1RightsGrant): CurrentViewPreservationInventoryV1RightsGrant {
  return normalize(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_RIGHTS_GRANT_TUPLE, value);
}
export function encodeCurrentViewPreservationInventoryV1RightsGrant(value: CurrentViewPreservationInventoryV1RightsGrant): Hex {
  return encode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_RIGHTS_GRANT_TUPLE, value);
}
export function decodeCurrentViewPreservationInventoryV1RightsGrant(value: Hex): CurrentViewPreservationInventoryV1RightsGrant {
  return decode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_RIGHTS_GRANT_TUPLE, value);
}

export function normalizeCurrentViewPreservationInventoryV1RightsConditions(value: CurrentViewPreservationInventoryV1RightsConditions): CurrentViewPreservationInventoryV1RightsConditions {
  return normalize(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_RIGHTS_CONDITIONS_TUPLE, value);
}
export function encodeCurrentViewPreservationInventoryV1RightsConditions(value: CurrentViewPreservationInventoryV1RightsConditions): Hex {
  return encode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_RIGHTS_CONDITIONS_TUPLE, value);
}
export function decodeCurrentViewPreservationInventoryV1RightsConditions(value: Hex): CurrentViewPreservationInventoryV1RightsConditions {
  return decode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_RIGHTS_CONDITIONS_TUPLE, value);
}

export function normalizeCurrentViewPreservationInventoryV1RightsDocument(value: CurrentViewPreservationInventoryV1RightsDocument): CurrentViewPreservationInventoryV1RightsDocument {
  return normalize(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_RIGHTS_DOCUMENT_TUPLE, value);
}
export function encodeCurrentViewPreservationInventoryV1RightsDocument(value: CurrentViewPreservationInventoryV1RightsDocument): Hex {
  return encode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_RIGHTS_DOCUMENT_TUPLE, value);
}
export function decodeCurrentViewPreservationInventoryV1RightsDocument(value: Hex): CurrentViewPreservationInventoryV1RightsDocument {
  return decode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_RIGHTS_DOCUMENT_TUPLE, value);
}

export function normalizeCurrentViewPreservationInventoryV1RootAggregate(value: CurrentViewPreservationInventoryV1RootAggregate): CurrentViewPreservationInventoryV1RootAggregate {
  return normalize(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_ROOT_AGGREGATE_TUPLE, value);
}
export function encodeCurrentViewPreservationInventoryV1RootAggregate(value: CurrentViewPreservationInventoryV1RootAggregate): Hex {
  return encode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_ROOT_AGGREGATE_TUPLE, value);
}
export function decodeCurrentViewPreservationInventoryV1RootAggregate(value: Hex): CurrentViewPreservationInventoryV1RootAggregate {
  return decode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_ROOT_AGGREGATE_TUPLE, value);
}

export function normalizeCurrentViewPreservationInventoryV1Description(value: CurrentViewPreservationInventoryV1Description): CurrentViewPreservationInventoryV1Description {
  return normalize(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_DESCRIPTION_TUPLE, value);
}
export function encodeCurrentViewPreservationInventoryV1Description(value: CurrentViewPreservationInventoryV1Description): Hex {
  return encode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_DESCRIPTION_TUPLE, value);
}
export function decodeCurrentViewPreservationInventoryV1Description(value: Hex): CurrentViewPreservationInventoryV1Description {
  return decode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_DESCRIPTION_TUPLE, value);
}

export function normalizeCurrentViewPreservationInventoryV1WorkFullDescription(value: CurrentViewPreservationInventoryV1WorkFullDescription): CurrentViewPreservationInventoryV1WorkFullDescription {
  return normalize(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_WORK_FULL_DESCRIPTION_TUPLE, value);
}
export function encodeCurrentViewPreservationInventoryV1WorkFullDescription(value: CurrentViewPreservationInventoryV1WorkFullDescription): Hex {
  return encode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_WORK_FULL_DESCRIPTION_TUPLE, value);
}
export function decodeCurrentViewPreservationInventoryV1WorkFullDescription(value: Hex): CurrentViewPreservationInventoryV1WorkFullDescription {
  return decode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_WORK_FULL_DESCRIPTION_TUPLE, value);
}

export function normalizeCurrentViewPreservationInventoryV1WorkCreator(value: CurrentViewPreservationInventoryV1WorkCreator): CurrentViewPreservationInventoryV1WorkCreator {
  return normalize(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_WORK_CREATOR_TUPLE, value);
}
export function encodeCurrentViewPreservationInventoryV1WorkCreator(value: CurrentViewPreservationInventoryV1WorkCreator): Hex {
  return encode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_WORK_CREATOR_TUPLE, value);
}
export function decodeCurrentViewPreservationInventoryV1WorkCreator(value: Hex): CurrentViewPreservationInventoryV1WorkCreator {
  return decode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_WORK_CREATOR_TUPLE, value);
}

export function normalizeCurrentViewPreservationInventoryV1WorkCreation(value: CurrentViewPreservationInventoryV1WorkCreation): CurrentViewPreservationInventoryV1WorkCreation {
  return normalize(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_WORK_CREATION_TUPLE, value);
}
export function encodeCurrentViewPreservationInventoryV1WorkCreation(value: CurrentViewPreservationInventoryV1WorkCreation): Hex {
  return encode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_WORK_CREATION_TUPLE, value);
}
export function decodeCurrentViewPreservationInventoryV1WorkCreation(value: Hex): CurrentViewPreservationInventoryV1WorkCreation {
  return decode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_WORK_CREATION_TUPLE, value);
}

export function normalizeCurrentViewPreservationInventoryV1WorkFormat(value: CurrentViewPreservationInventoryV1WorkFormat): CurrentViewPreservationInventoryV1WorkFormat {
  return normalize(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_WORK_FORMAT_TUPLE, value);
}
export function encodeCurrentViewPreservationInventoryV1WorkFormat(value: CurrentViewPreservationInventoryV1WorkFormat): Hex {
  return encode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_WORK_FORMAT_TUPLE, value);
}
export function decodeCurrentViewPreservationInventoryV1WorkFormat(value: Hex): CurrentViewPreservationInventoryV1WorkFormat {
  return decode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_WORK_FORMAT_TUPLE, value);
}

export function normalizeCurrentViewPreservationInventoryV1WorkCatalog(value: CurrentViewPreservationInventoryV1WorkCatalog): CurrentViewPreservationInventoryV1WorkCatalog {
  return normalize(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_WORK_CATALOG_TUPLE, value);
}
export function encodeCurrentViewPreservationInventoryV1WorkCatalog(value: CurrentViewPreservationInventoryV1WorkCatalog): Hex {
  return encode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_WORK_CATALOG_TUPLE, value);
}
export function decodeCurrentViewPreservationInventoryV1WorkCatalog(value: Hex): CurrentViewPreservationInventoryV1WorkCatalog {
  return decode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_WORK_CATALOG_TUPLE, value);
}

export function normalizeCurrentViewPreservationInventoryV1WorkCatalogEntry(value: CurrentViewPreservationInventoryV1WorkCatalogEntry): CurrentViewPreservationInventoryV1WorkCatalogEntry {
  return normalize(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_WORK_CATALOG_ENTRY_TUPLE, value);
}
export function encodeCurrentViewPreservationInventoryV1WorkCatalogEntry(value: CurrentViewPreservationInventoryV1WorkCatalogEntry): Hex {
  return encode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_WORK_CATALOG_ENTRY_TUPLE, value);
}
export function decodeCurrentViewPreservationInventoryV1WorkCatalogEntry(value: Hex): CurrentViewPreservationInventoryV1WorkCatalogEntry {
  return decode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_WORK_CATALOG_ENTRY_TUPLE, value);
}

export function normalizeCurrentViewPreservationInventoryV1WorkSpecification(value: CurrentViewPreservationInventoryV1WorkSpecification): CurrentViewPreservationInventoryV1WorkSpecification {
  return normalize(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_WORK_SPECIFICATION_TUPLE, value);
}
export function encodeCurrentViewPreservationInventoryV1WorkSpecification(value: CurrentViewPreservationInventoryV1WorkSpecification): Hex {
  return encode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_WORK_SPECIFICATION_TUPLE, value);
}
export function decodeCurrentViewPreservationInventoryV1WorkSpecification(value: Hex): CurrentViewPreservationInventoryV1WorkSpecification {
  return decode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_WORK_SPECIFICATION_TUPLE, value);
}

export function normalizeCurrentViewPreservationInventoryV1WorkMeasurements(value: CurrentViewPreservationInventoryV1WorkMeasurements): CurrentViewPreservationInventoryV1WorkMeasurements {
  return normalize(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_WORK_MEASUREMENTS_TUPLE, value);
}
export function encodeCurrentViewPreservationInventoryV1WorkMeasurements(value: CurrentViewPreservationInventoryV1WorkMeasurements): Hex {
  return encode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_WORK_MEASUREMENTS_TUPLE, value);
}
export function decodeCurrentViewPreservationInventoryV1WorkMeasurements(value: Hex): CurrentViewPreservationInventoryV1WorkMeasurements {
  return decode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_WORK_MEASUREMENTS_TUPLE, value);
}

export function normalizeCurrentViewPreservationInventoryV1WorkRational(value: CurrentViewPreservationInventoryV1WorkRational): CurrentViewPreservationInventoryV1WorkRational {
  return normalize(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_WORK_RATIONAL_TUPLE, value);
}
export function encodeCurrentViewPreservationInventoryV1WorkRational(value: CurrentViewPreservationInventoryV1WorkRational): Hex {
  return encode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_WORK_RATIONAL_TUPLE, value);
}
export function decodeCurrentViewPreservationInventoryV1WorkRational(value: Hex): CurrentViewPreservationInventoryV1WorkRational {
  return decode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_WORK_RATIONAL_TUPLE, value);
}

export function normalizeCurrentViewPreservationInventoryV1WorkEdition(value: CurrentViewPreservationInventoryV1WorkEdition): CurrentViewPreservationInventoryV1WorkEdition {
  return normalize(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_WORK_EDITION_TUPLE, value);
}
export function encodeCurrentViewPreservationInventoryV1WorkEdition(value: CurrentViewPreservationInventoryV1WorkEdition): Hex {
  return encode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_WORK_EDITION_TUPLE, value);
}
export function decodeCurrentViewPreservationInventoryV1WorkEdition(value: Hex): CurrentViewPreservationInventoryV1WorkEdition {
  return decode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_WORK_EDITION_TUPLE, value);
}

export function normalizeCurrentViewPreservationInventoryV1WorkLanguageVariant(value: CurrentViewPreservationInventoryV1WorkLanguageVariant): CurrentViewPreservationInventoryV1WorkLanguageVariant {
  return normalize(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_WORK_LANGUAGE_VARIANT_TUPLE, value);
}
export function encodeCurrentViewPreservationInventoryV1WorkLanguageVariant(value: CurrentViewPreservationInventoryV1WorkLanguageVariant): Hex {
  return encode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_WORK_LANGUAGE_VARIANT_TUPLE, value);
}
export function decodeCurrentViewPreservationInventoryV1WorkLanguageVariant(value: Hex): CurrentViewPreservationInventoryV1WorkLanguageVariant {
  return decode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_WORK_LANGUAGE_VARIANT_TUPLE, value);
}

export function normalizeCurrentViewPreservationInventoryV1WorkAuthorityReference(value: CurrentViewPreservationInventoryV1WorkAuthorityReference): CurrentViewPreservationInventoryV1WorkAuthorityReference {
  return normalize(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_WORK_AUTHORITY_REFERENCE_TUPLE, value);
}
export function encodeCurrentViewPreservationInventoryV1WorkAuthorityReference(value: CurrentViewPreservationInventoryV1WorkAuthorityReference): Hex {
  return encode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_WORK_AUTHORITY_REFERENCE_TUPLE, value);
}
export function decodeCurrentViewPreservationInventoryV1WorkAuthorityReference(value: Hex): CurrentViewPreservationInventoryV1WorkAuthorityReference {
  return decode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_WORK_AUTHORITY_REFERENCE_TUPLE, value);
}

export function normalizeCurrentViewPreservationInventoryV1WorkAbsence(value: CurrentViewPreservationInventoryV1WorkAbsence): CurrentViewPreservationInventoryV1WorkAbsence {
  return normalize(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_WORK_ABSENCE_TUPLE, value);
}
export function encodeCurrentViewPreservationInventoryV1WorkAbsence(value: CurrentViewPreservationInventoryV1WorkAbsence): Hex {
  return encode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_WORK_ABSENCE_TUPLE, value);
}
export function decodeCurrentViewPreservationInventoryV1WorkAbsence(value: Hex): CurrentViewPreservationInventoryV1WorkAbsence {
  return decode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_WORK_ABSENCE_TUPLE, value);
}

export function normalizeCurrentViewPreservationInventoryV1Plan(value: CurrentViewPreservationInventoryV1Plan): CurrentViewPreservationInventoryV1Plan {
  return normalize(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_PLAN_TUPLE, value);
}
export function encodeCurrentViewPreservationInventoryV1Plan(value: CurrentViewPreservationInventoryV1Plan): Hex {
  return encode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_PLAN_TUPLE, value);
}
export function decodeCurrentViewPreservationInventoryV1Plan(value: Hex): CurrentViewPreservationInventoryV1Plan {
  return decode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_PLAN_TUPLE, value);
}

export function normalizeCurrentViewPreservationInventoryV1Progress(value: CurrentViewPreservationInventoryV1Progress): CurrentViewPreservationInventoryV1Progress {
  return normalize(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_PROGRESS_TUPLE, value);
}
export function encodeCurrentViewPreservationInventoryV1Progress(value: CurrentViewPreservationInventoryV1Progress): Hex {
  return encode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_PROGRESS_TUPLE, value);
}
export function decodeCurrentViewPreservationInventoryV1Progress(value: Hex): CurrentViewPreservationInventoryV1Progress {
  return decode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_PROGRESS_TUPLE, value);
}

export function normalizeCurrentViewPreservationInventoryV1Context(value: CurrentViewPreservationInventoryV1Context): CurrentViewPreservationInventoryV1Context {
  return normalize(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_CONTEXT_TUPLE, value);
}
export function encodeCurrentViewPreservationInventoryV1Context(value: CurrentViewPreservationInventoryV1Context): Hex {
  return encode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_CONTEXT_TUPLE, value);
}
export function decodeCurrentViewPreservationInventoryV1Context(value: Hex): CurrentViewPreservationInventoryV1Context {
  return decode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_CONTEXT_TUPLE, value);
}

export function normalizeCurrentViewPreservationInventoryV1SnapshotReceipt(value: CurrentViewPreservationInventoryV1SnapshotReceipt): CurrentViewPreservationInventoryV1SnapshotReceipt {
  return normalize(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_SNAPSHOT_RECEIPT_TUPLE, value);
}
export function encodeCurrentViewPreservationInventoryV1SnapshotReceipt(value: CurrentViewPreservationInventoryV1SnapshotReceipt): Hex {
  return encode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_SNAPSHOT_RECEIPT_TUPLE, value);
}
export function decodeCurrentViewPreservationInventoryV1SnapshotReceipt(value: Hex): CurrentViewPreservationInventoryV1SnapshotReceipt {
  return decode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_SNAPSHOT_RECEIPT_TUPLE, value);
}

export function normalizeCurrentViewPreservationInventoryV1ReferenceReceipt(value: CurrentViewPreservationInventoryV1ReferenceReceipt): CurrentViewPreservationInventoryV1ReferenceReceipt {
  return normalize(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_REFERENCE_RECEIPT_TUPLE, value);
}
export function encodeCurrentViewPreservationInventoryV1ReferenceReceipt(value: CurrentViewPreservationInventoryV1ReferenceReceipt): Hex {
  return encode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_REFERENCE_RECEIPT_TUPLE, value);
}
export function decodeCurrentViewPreservationInventoryV1ReferenceReceipt(value: Hex): CurrentViewPreservationInventoryV1ReferenceReceipt {
  return decode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_REFERENCE_RECEIPT_TUPLE, value);
}

export function normalizeCurrentViewPreservationInventoryV1ReferenceObservation(value: CurrentViewPreservationInventoryV1ReferenceObservation): CurrentViewPreservationInventoryV1ReferenceObservation {
  return normalize(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_REFERENCE_OBSERVATION_TUPLE, value);
}
export function encodeCurrentViewPreservationInventoryV1ReferenceObservation(value: CurrentViewPreservationInventoryV1ReferenceObservation): Hex {
  return encode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_REFERENCE_OBSERVATION_TUPLE, value);
}
export function decodeCurrentViewPreservationInventoryV1ReferenceObservation(value: Hex): CurrentViewPreservationInventoryV1ReferenceObservation {
  return decode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_REFERENCE_OBSERVATION_TUPLE, value);
}

export function normalizeCurrentViewPreservationInventoryV1DescriptionEvidence(value: CurrentViewPreservationInventoryV1DescriptionEvidence): CurrentViewPreservationInventoryV1DescriptionEvidence {
  return normalize(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_DESCRIPTION_EVIDENCE_TUPLE, value);
}
export function encodeCurrentViewPreservationInventoryV1DescriptionEvidence(value: CurrentViewPreservationInventoryV1DescriptionEvidence): Hex {
  return encode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_DESCRIPTION_EVIDENCE_TUPLE, value);
}
export function decodeCurrentViewPreservationInventoryV1DescriptionEvidence(value: Hex): CurrentViewPreservationInventoryV1DescriptionEvidence {
  return decode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_DESCRIPTION_EVIDENCE_TUPLE, value);
}

export function normalizeCurrentViewPreservationInventoryV1ConservationSelection(value: CurrentViewPreservationInventoryV1ConservationSelection): CurrentViewPreservationInventoryV1ConservationSelection {
  return normalize(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_CONSERVATION_SELECTION_TUPLE, value);
}
export function encodeCurrentViewPreservationInventoryV1ConservationSelection(value: CurrentViewPreservationInventoryV1ConservationSelection): Hex {
  return encode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_CONSERVATION_SELECTION_TUPLE, value);
}
export function decodeCurrentViewPreservationInventoryV1ConservationSelection(value: Hex): CurrentViewPreservationInventoryV1ConservationSelection {
  return decode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_CONSERVATION_SELECTION_TUPLE, value);
}

export function normalizeCurrentViewPreservationInventoryV1ConservationRecordEvidence(value: CurrentViewPreservationInventoryV1ConservationRecordEvidence): CurrentViewPreservationInventoryV1ConservationRecordEvidence {
  return normalize(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_CONSERVATION_RECORD_EVIDENCE_TUPLE, value);
}
export function encodeCurrentViewPreservationInventoryV1ConservationRecordEvidence(value: CurrentViewPreservationInventoryV1ConservationRecordEvidence): Hex {
  return encode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_CONSERVATION_RECORD_EVIDENCE_TUPLE, value);
}
export function decodeCurrentViewPreservationInventoryV1ConservationRecordEvidence(value: Hex): CurrentViewPreservationInventoryV1ConservationRecordEvidence {
  return decode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_CONSERVATION_RECORD_EVIDENCE_TUPLE, value);
}

export function normalizeCurrentViewPreservationInventoryV1PublicationEvidence(value: CurrentViewPreservationInventoryV1PublicationEvidence): CurrentViewPreservationInventoryV1PublicationEvidence {
  return normalize(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_PUBLICATION_EVIDENCE_TUPLE, value);
}
export function encodeCurrentViewPreservationInventoryV1PublicationEvidence(value: CurrentViewPreservationInventoryV1PublicationEvidence): Hex {
  return encode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_PUBLICATION_EVIDENCE_TUPLE, value);
}
export function decodeCurrentViewPreservationInventoryV1PublicationEvidence(value: Hex): CurrentViewPreservationInventoryV1PublicationEvidence {
  return decode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_PUBLICATION_EVIDENCE_TUPLE, value);
}

export function normalizeCurrentViewPreservationInventoryV1ConservationAssociation(value: CurrentViewPreservationInventoryV1ConservationAssociation): CurrentViewPreservationInventoryV1ConservationAssociation {
  return normalize(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_CONSERVATION_ASSOCIATION_TUPLE, value);
}
export function encodeCurrentViewPreservationInventoryV1ConservationAssociation(value: CurrentViewPreservationInventoryV1ConservationAssociation): Hex {
  return encode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_CONSERVATION_ASSOCIATION_TUPLE, value);
}
export function decodeCurrentViewPreservationInventoryV1ConservationAssociation(value: Hex): CurrentViewPreservationInventoryV1ConservationAssociation {
  return decode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_CONSERVATION_ASSOCIATION_TUPLE, value);
}

export function normalizeCurrentViewPreservationInventoryV1TokenProgress(value: CurrentViewPreservationInventoryV1TokenProgress): CurrentViewPreservationInventoryV1TokenProgress {
  return normalize(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_TOKEN_PROGRESS_TUPLE, value);
}
export function encodeCurrentViewPreservationInventoryV1TokenProgress(value: CurrentViewPreservationInventoryV1TokenProgress): Hex {
  return encode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_TOKEN_PROGRESS_TUPLE, value);
}
export function decodeCurrentViewPreservationInventoryV1TokenProgress(value: Hex): CurrentViewPreservationInventoryV1TokenProgress {
  return decode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_TOKEN_PROGRESS_TUPLE, value);
}

const coder = AbiCoder.defaultAbiCoder();
const Z = ZeroHash as Hex;
function exact(value: unknown, keys: readonly string[]): asserts value is Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)
    || Reflect.ownKeys(value).length !== keys.length
    || keys.some(k => !Object.prototype.hasOwnProperty.call(value, k))) throw Error("Invalid exact shape");
}
function uint(value: unknown, bits = 256): bigint {
  if (typeof value !== "bigint" || value < 0n || value >= 1n << BigInt(bits)) throw Error(`Invalid uint${bits}`);
  return value;
}
function address(value: unknown, required = false): Address {
  if (typeof value !== "string" || !isHexString(value, 20)) throw Error("Invalid address");
  const result = getAddress(value) as Address;
  if (required && result === ZeroAddress) throw Error("Zero address");
  return result;
}
function bytes(value: unknown, length?: number, maximum = CURRENT_VIEW_PRESERVATION_INVENTORY_V1_MAX_BYTES): Hex {
  if (typeof value !== "string" || !isHexString(value, length ?? true)
    || (value.length - 2) / 2 > maximum) throw Error("Invalid bytes or allocation bound");
  return value.toLowerCase() as Hex;
}
function nonzero(value: unknown): Hex {
  const result = bytes(value, 32);
  if (result === Z) throw Error("Zero commitment");
  return result;
}
function list(value: unknown, maximum = CURRENT_VIEW_PRESERVATION_INVENTORY_V1_MAX_ROWS): readonly unknown[] {
  if (!Array.isArray(value) || value.length > maximum || Reflect.ownKeys(value).length !== value.length + 1
    || Array.from({ length: value.length }, (_, i) => i).some(i => !Object.prototype.hasOwnProperty.call(value, i))) throw Error("Invalid dense array");
  return value;
}
function utf8(value: unknown): Uint8Array {
  if (typeof value !== "string" || value.length > CURRENT_VIEW_PRESERVATION_INVENTORY_V1_MAX_BYTES) throw Error("Invalid string");
  for (let i = 0; i < value.length; ++i) {
    const code = value.charCodeAt(i);
    if (code >= 0xdc00 && code <= 0xdfff) throw Error("Invalid Unicode scalar");
    if (code >= 0xd800 && code <= 0xdbff) {
      const next = value.charCodeAt(++i);
      if (!(next >= 0xdc00 && next <= 0xdfff)) throw Error("Invalid Unicode scalar");
    }
  }
  return toUtf8Bytes(value);
}
const enumFields: Readonly<Record<string, Readonly<Record<string, number>>>> = {
  "(uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId)": {
    "scopeType": 4
  },
  "(uint8 kind, bytes32 role, address source, bytes32 sourceRecord, uint256 sourceIndex, uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri, uint64 byteSize, bytes32 schemaId, bytes32 formatId, bytes32 catalogId, bytes32 catalogHash, bytes32 objectHash, bytes32 originalCoverageHash, bytes32 provenanceHash)": {
    "kind": 11
  },
  "(bytes32 artistId, uint64 bindingGeneration, bytes32 bindingHash, uint8 origin)": {
    "origin": 1
  },
  "(uint8 status, (uint256 chainId, address core, address host, bytes32 recordHash, bytes32 schemaId, bytes32 profileHash, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) payload) record, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) waiverStatement)": {
    "status": 1
  },
  "(uint8 kind, string name, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) document)": {
    "kind": 1
  },
  "(uint8 role, string otherRole, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) identity)": {
    "role": 2
  },
  "(bytes32 entryId, uint8 kind, string puid, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) specification)": {
    "kind": 1
  },
  "(uint8 kind, bytes32 formatId, string puid, (string name, (bytes32 entryId, uint8 kind, string puid, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) specification)[] entries, bytes32 selectedEntryId) catalog)": {
    "kind": 1
  },
  "(uint8 kind, ((uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) content, (uint8 kind, bytes32 formatId, string puid, (string name, (bytes32 entryId, uint8 kind, string puid, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) specification)[] entries, bytes32 selectedEntryId) catalog) format) payload)": {
    "kind": 1
  },
  "(uint8 kind, bytes32 artistId, string name, address account, bytes32 instrumentDigest)": {
    "kind": 3
  },
  "(uint8 kind, string text, (bool exists, string uri, bytes32 digest) document)": {
    "kind": 2
  },
  "(uint8 status, (uint8 kind, string text, (bool exists, string uri, bytes32 digest) document) conditions, string extension)": {
    "status": 3
  },
  "(bytes32 subjectId, bytes32 profileHash, uint8 basis, (uint8 kind, bytes32 artistId, string name, address account, bytes32 instrumentDigest) licensor, ((uint8 status, (uint8 kind, string text, (bool exists, string uri, bytes32 digest) document) conditions, string extension) aiTraining, (uint8 status, (uint8 kind, string text, (bool exists, string uri, bytes32 digest) document) conditions, string extension) derivative, (uint8 status, (uint8 kind, string text, (bool exists, string uri, bytes32 digest) document) conditions, string extension) exhibition, (uint8 status, (uint8 kind, string text, (bool exists, string uri, bytes32 digest) document) conditions, string extension) print, (uint8 status, (uint8 kind, string text, (bool exists, string uri, bytes32 digest) document) conditions, string extension) publication, (uint8 status, (uint8 kind, string text, (bool exists, string uri, bytes32 digest) document) conditions, string extension) reproduction) grants, uint32 startDate, uint32 endDate, bool openEnd, (bool exists, string uri, bytes32 digest) instrument, bool hasAiTrainingPermission, uint8 aiTrainingPermission, bytes32 predecessor)": {
    "basis": 5,
    "aiTrainingPermission": 3
  },
  "(uint8 kind, bytes32 artistId, uint64 bindingGeneration, bytes32 bindingHash, string name)": {
    "kind": 1
  },
  "(uint8 kind, uint32 start, uint32 end)": {
    "kind": 1
  },
  "(bytes32 entryId, uint8 kind, string puid, (string uri, bytes32 digest) specification)": {
    "kind": 1
  },
  "(uint8 kind, bytes32 formatId, string puid, (string name, (bytes32 entryId, uint8 kind, string puid, (string uri, bytes32 digest) specification)[] entries, bytes32 selectedEntryId) catalog)": {
    "kind": 2
  },
  "(uint8 kind, bool hasPixels, uint256 width, uint256 height, bool hasAspectRatio, (uint256 numerator, uint256 denominator) aspectRatio, bool hasDuration, (uint256 numerator, uint256 denominator) durationSeconds)": {
    "kind": 1
  },
  "(uint8 kind, uint256 number, uint256 total, string statement)": {
    "kind": 2
  },
  "(uint8 field, uint8 alternateTitleIndex, string language, string value)": {
    "field": 5
  },
  "(uint8 role, uint8 authority, string identifier)": {
    "role": 2,
    "authority": 3
  },
  "(bytes32 subjectId, bytes32 profileHash, bytes32 predecessor, uint8 form, (string title, (uint8 kind, bytes32 artistId, uint64 bindingGeneration, bytes32 bindingHash, string name) creator, (uint8 kind, uint32 start, uint32 end) creation, string medium, (uint8 kind, bytes32 formatId, string puid, (string name, (bytes32 entryId, uint8 kind, string puid, (string uri, bytes32 digest) specification)[] entries, bytes32 selectedEntryId) catalog) format, (uint8 kind, bool hasPixels, uint256 width, uint256 height, bool hasAspectRatio, (uint256 numerator, uint256 denominator) aspectRatio, bool hasDuration, (uint256 numerator, uint256 denominator) durationSeconds) measurements, (uint8 kind, uint256 number, uint256 total, string statement) edition, string creditLine, bool hasInscription, string inscription, string[] alternateTitles, (uint8 field, uint8 alternateTitleIndex, string language, string value)[] languageVariants, (uint8 role, uint8 authority, string identifier)[] authorityReferences) full, (string reason, uint32 date) absence)": {
    "form": 1
  },
  "(bytes32 recordHash, uint8 kind, bytes32 payloadHash, address recorder, uint64 recordedAt, uint64 recordIndex, bytes32 recordChainHash, bytes32 receiptHash, (bytes32 attestationRecordHash, bytes32 artistId, bytes32 bindingHash, uint64 bindingGeneration, address signer, uint8 authorityClass, uint32 requiredCapability, uint64 signedAt, bytes32 publicationHash) publication, bytes32 publicationEvidenceHash)": {
    "kind": 2
  },
  "((bytes32 recordHash, uint8 kind, bytes32 payloadHash, address recorder, uint64 recordedAt, uint64 recordIndex, bytes32 recordChainHash, bytes32 receiptHash, (bytes32 attestationRecordHash, bytes32 artistId, bytes32 bindingHash, uint64 bindingGeneration, address signer, uint8 authorityClass, uint32 requiredCapability, uint64 signedAt, bytes32 publicationHash) publication, bytes32 publicationEvidenceHash) record, (bytes32 artistId, bytes32 bindingHash, uint64 generation, bytes32 identityRecordHash) association, uint8 origin, uint8 interviewStatus, (bytes32 recordHash, uint8 kind, bytes32 payloadHash, address recorder, uint64 recordedAt, uint64 recordIndex, bytes32 recordChainHash, bytes32 receiptHash, (bytes32 attestationRecordHash, bytes32 artistId, bytes32 bindingHash, uint64 bindingGeneration, address signer, uint8 authorityClass, uint32 requiredCapability, uint64 signedAt, bytes32 publicationHash) publication, bytes32 publicationEvidenceHash) interview, bytes32 interviewArchiveReferenceHash, uint8 interviewPayloadCorrespondence, bytes32 predecessor, address submitter, uint64 revision, uint64 selectedAt, bytes32 catalogsHash, bytes32 selectionHash)": {
    "origin": 1,
    "interviewStatus": 1,
    "interviewPayloadCorrespondence": 2
  }
};
function valueOf(t: ParamType, value: unknown, decoded: boolean, enumMaximum?: number): unknown {
  if (t.baseType === "array") {
    const rows = list(decoded ? Array.from(value as readonly unknown[]) : value);
    if (t.arrayLength !== -1 && rows.length !== t.arrayLength) throw Error("Invalid fixed array");
    return Object.freeze(rows.map(x => valueOf(t.arrayChildren!, x, decoded)));
  }
  if (t.type === "bool") { if (typeof value !== "boolean") throw Error("Invalid bool"); return value; }
  if (t.baseType === "tuple") {
    if (!decoded) exact(value, t.components!.map(c => c.name));
    const tupleKey = ParamType.from({ type: "tuple", components: t.components!.map(c => JSON.parse(c.format("json"))) }).format("full");
    const result = Object.fromEntries(t.components!.map((c, i) => [c.name,
      valueOf(c, decoded ? (value as readonly unknown[])[i] : (value as Record<string, unknown>)[c.name], decoded, enumFields[tupleKey]?.[c.name])]));
    if ("scopeType" in result && (result.scopeType as bigint) > 4n) throw Error("Invalid original scope enum");
    return Object.freeze(result);
  }
  if (t.type.startsWith("uint")) {
    const result = uint(value, Number(t.type.slice(4)));
    if (enumMaximum !== undefined && result > BigInt(enumMaximum)) throw Error("Unknown original enum");
    return result;
  }
  if (t.type === "address") return address(value);
  if (t.type === "string") {
    if (utf8(value).length > CURRENT_VIEW_PRESERVATION_INVENTORY_V1_MAX_BYTES) throw Error("Invalid UTF-8 string bound");
    return value;
  }
  if (t.type.startsWith("bytes")) return bytes(value, t.type === "bytes" ? undefined : Number(t.type.slice(5)));
  throw Error("Unsupported original ABI type");
}
function normalize<T>(tuple: string, value: unknown, decoded = false): T {
  const p = ParamType.from(tuple);
  if (preflight(p, value, decoded) + (isDynamic(p) ? 32 : 0) > CURRENT_VIEW_PRESERVATION_INVENTORY_V1_MAX_BYTES) throw Error("ABI allocation bound");
  const result = valueOf(p, value, decoded) as T;
  if (encodedSize(p, result) + (isDynamic(p) ? 32 : 0) > CURRENT_VIEW_PRESERVATION_INVENTORY_V1_MAX_BYTES) throw Error("ABI allocation bound");
  return result;
}
function encode(tuple: string, value: unknown): Hex {
  return bytes(coder.encode([tuple], [normalize(tuple, value)]));
}
function decode<T>(tuple: string, value: Hex): T {
  const raw = bytes(value);
  const result = normalize<T>(tuple, coder.decode([tuple], raw)[0], true);
  if (encode(tuple, result) !== raw) throw Error("Noncanonical original ABI");
  return result;
}
function hash(types: readonly string[], values: readonly unknown[]): Hex {
  return keccak256(coder.encode(types, values)) as Hex;
}
function same(actual: unknown, expected: unknown, label: string): void {
  if (actual !== expected) throw Error(`${label} mismatch`);
}
function equalTuple(tuple: string, actual: unknown, expected: unknown, label: string): void {
  same(encode(tuple, actual), encode(tuple, expected), label);
}
function isDynamic(p: ParamType): boolean {
  return p.type === "bytes" || p.type === "string"
    || (p.baseType === "array" && (p.arrayLength === -1 || isDynamic(p.arrayChildren!)))
    || (p.baseType === "tuple" && p.components!.some(isDynamic));
}
function encodedSize(p: ParamType, value: unknown): number {
  let size: number;
  if (p.baseType === "array") {
    size = (p.arrayLength === -1 ? 32 : 0) + (value as readonly unknown[]).reduce<number>((sum, v) =>
      sum + (isDynamic(p.arrayChildren!) ? 32 : 0) + encodedSize(p.arrayChildren!, v), 0);
  } else if (p.baseType === "tuple") {
    size = p.components!.reduce((sum, c) => sum + (isDynamic(c) ? 32 : 0)
      + encodedSize(c, (value as Record<string, unknown>)[c.name]), 0);
  } else if (p.type === "bytes" || p.type === "string") {
    const n = p.type === "bytes" ? ((value as string).length - 2) / 2 : utf8(value).length;
    size = 32 + Math.ceil(n / 32) * 32;
  } else size = 32;
  if (size > 2097152) throw Error("ABI allocation bound");
  return size;
}
/** Traverses caller values before copying arrays, objects or UTF-8 buffers. */
function preflight(p: ParamType, value: unknown, decoded: boolean, budget = { nodes: 0 }): number {
  if (++budget.nodes > 65536) throw Error("Client structure bound");
  let total = 0;
  const add = (n: number): void => {
    total += n;
    if (total > 2097152) throw Error("ABI allocation bound");
  };
  if (p.baseType === "array") {
    if (!Array.isArray(value) || value.length > 8192
      || (p.arrayLength !== -1 && value.length !== p.arrayLength)) throw Error("Invalid array bound");
    if (!decoded) list(value);
    if (p.arrayLength === -1) add(32);
    for (let i = 0; i < value.length; ++i) {
      if (isDynamic(p.arrayChildren!)) add(32);
      add(preflight(p.arrayChildren!, value[i], decoded, budget));
    }
  } else if (p.baseType === "tuple") {
    if (!decoded) exact(value, p.components!.map(c => c.name));
    for (let i = 0; i < p.components!.length; ++i) {
      const c = p.components![i]!;
      if (isDynamic(c)) add(32);
      add(preflight(c, decoded ? (value as readonly unknown[])[i]
        : (value as Record<string, unknown>)[c.name], decoded, budget));
    }
  } else if (p.type === "bytes" || p.type === "string") {
    let length = 0;
    if (p.type === "bytes") length = (bytes(value).length - 2) / 2;
    else {
      if (typeof value !== "string" || value.length > 2097152) throw Error("Invalid string bound");
      for (let i = 0; i < value.length; ++i) {
        const code = value.charCodeAt(i);
        if (code >= 0xdc00 && code <= 0xdfff) throw Error("Invalid Unicode scalar");
        if (code >= 0xd800 && code <= 0xdbff) {
          const low = value.charCodeAt(++i);
          if (!(low >= 0xdc00 && low <= 0xdfff)) throw Error("Invalid Unicode scalar");
          length += 4;
        } else length += code < 128 ? 1 : code < 2048 ? 2 : 3;
        if (length > 2097152) throw Error("UTF-8 allocation bound");
      }
    }
    add(32 + Math.ceil(length / 32) * 32);
  } else add(32);
  return total;
}

export const CURRENT_VIEW_PRESERVATION_INVENTORY_V1_PROFILE = id("6529STREAM_VIEW_PRESERVATION_RENDER_CRITICAL_RETRIEVAL_V1") as Hex;
export const CURRENT_VIEW_PRESERVATION_INVENTORY_V1_RETRIEVAL_ROLE = id("VIEW_ATTRIBUTED_RETRIEVAL_IMAGE") as Hex;
export const CURRENT_VIEW_PRESERVATION_INVENTORY_V1_LOCATOR_ROLE = id("VIEW_ARCHIVE_LOCATOR_IMAGE") as Hex;

export function normalizeCurrentViewPreservationInventoryV1Coordinates(
  value: CurrentViewPreservationInventoryV1Coordinates,
): CurrentViewPreservationInventoryV1Coordinates {
  exact(value, ["chainId", "core", "inventory"]);
  if (uint(value.chainId) === 0n) throw Error("Zero chain");
  return Object.freeze({ chainId: value.chainId, core: address(value.core, true), inventory: address(value.inventory, true) });
}

export function validateCurrentViewPreservationInventoryV1Scope(
  value: CurrentViewPreservationInventoryV1Scope,
): CurrentViewPreservationInventoryV1Scope {
  const scope = normalizeCurrentViewPreservationInventoryV1Scope(value);
  if (scope.scopeType !== 4n || scope.collectionId === 0n || scope.tokenId !== 0n || scope.scopeId === Z) {
    throw Error("Expected complete VIEW scope");
  }
  return scope;
}

export function currentViewPreservationInventoryV1ScopeSubject(
  coordinates: CurrentViewPreservationInventoryV1Coordinates,
  value: CurrentViewPreservationInventoryV1Scope,
): Hex {
  const c = normalizeCurrentViewPreservationInventoryV1Coordinates(coordinates);
  const s = validateCurrentViewPreservationInventoryV1Scope(value);
  return hash(["bytes32", "uint256", "address", "uint256", "uint8", "bytes32"],
    [id("6529STREAM_SUBJECT_SCOPE_V1"), c.chainId, c.core, s.collectionId, s.scopeType, s.scopeId]);
}

export function currentViewPreservationInventoryV1DependencyHash(value: CurrentViewPreservationInventoryV1Dependencies): Hex {
  return keccak256(encodeCurrentViewPreservationInventoryV1Dependencies(value)) as Hex;
}

/** Constructor predicates on supplied values; no runtime or companion capability is asserted. */
export function validateCurrentViewPreservationInventoryV1Dependencies(
  coordinates: CurrentViewPreservationInventoryV1Coordinates,
  value: CurrentViewPreservationInventoryV1Dependencies,
): CurrentViewPreservationInventoryV1Dependencies {
  const c = normalizeCurrentViewPreservationInventoryV1Coordinates(coordinates);
  const d = normalizeCurrentViewPreservationInventoryV1Dependencies(value);
  same(d.chainId, c.chainId, "Chain");
  same(d.targets[0], c.core, "Core");
  if (d.readGas < 50000n || [d.sourceGas, d.selectionGas, d.snapshotGas, d.referenceGas].some(g => g < d.readGas)) {
    throw Error("Invalid original gas ordering");
  }
  [...d.targets, ...d.artistTargets, d.artistContentOwner].forEach(a => address(a, true));
  [...d.codeHashes, ...d.artistCodeHashes, d.artistContentOwnerCodeHash].forEach(nonzero);
  return d;
}

export function currentViewPreservationInventoryV1ContextHash(value: CurrentViewPreservationInventoryV1Context): Hex {
  return keccak256(encodeCurrentViewPreservationInventoryV1Context(value)) as Hex;
}

/** Only joins available immutable context fields; full Sources.current remains an original call. */
export function validateCurrentViewPreservationInventoryV1Context(
  coordinates: CurrentViewPreservationInventoryV1Coordinates,
  value: CurrentViewPreservationInventoryV1Context,
): CurrentViewPreservationInventoryV1Context {
  const c = normalizeCurrentViewPreservationInventoryV1Coordinates(coordinates);
  const v = normalizeCurrentViewPreservationInventoryV1Context(value);
  const subject = currentViewPreservationInventoryV1ScopeSubject(c, v.scope);
  for (const actual of [v.subject, v.snapshot.scopeSubject, v.referenceRender.scopeSubject, v.descriptions.scopeSubject]) {
    same(actual, subject, "Full VIEW subject");
  }
  same(v.referenceRender.observation.collectionId, v.scope.collectionId, "Reference collection");
  same(v.referenceRender.observation.snapshotRecordHash, v.snapshot.recordHash, "Snapshot record");
  same(v.referenceRender.observation.snapshotRevision, v.snapshot.revision, "Snapshot revision");
  same(v.artistId, v.conservation.association.artistId, "Artist");
  if (v.tokenCount === 0n) throw Error("Empty token inventory");
  [v.artistId, v.nativeHash, v.rootRecordHash, v.tokenInventoryHash, v.checkpointHash,
    v.outputManifestRecord, v.adoptionRecord, v.viewId, v.payloadHash, v.sourceContextHash,
    v.outputRoot, v.manifestIndexHash, v.snapshot.recordHash, v.referenceRender.observation.recordHash].forEach(nonzero);
  return v;
}

export function currentViewPreservationInventoryV1PlanId(
  coordinates: CurrentViewPreservationInventoryV1Coordinates,
  dependencyHash: Hex,
  context: CurrentViewPreservationInventoryV1Context,
): Hex {
  const c = normalizeCurrentViewPreservationInventoryV1Coordinates(coordinates);
  return hash(["bytes32", "uint256", "address", "bytes32", CURRENT_VIEW_PRESERVATION_INVENTORY_V1_CONTEXT_TUPLE],
    [id("6529STREAM_VIEW_PRESERVATION_RENDER_CRITICAL_PLAN_V1"), c.chainId, c.inventory,
      bytes(dependencyHash, 32), normalizeCurrentViewPreservationInventoryV1Context(context)]);
}

export function currentViewPreservationInventoryV1SegmentKey(plan: Hex, index: bigint): Hex {
  return hash(["bytes32", "bytes32", "uint64"],
    [id("6529STREAM_VIEW_PRESERVATION_RENDER_CRITICAL_SEGMENT_V1"), bytes(plan, 32), uint(index, 64)]);
}
/** These four original chain functions are byte-identical across the preserved profiles. */
export function currentViewPreservationInventoryV1ItemHash(item: CurrentViewPreservationInventoryV1Item): Hex {
  return original.scopedPolicyInventoryV2ItemHash(normalizeCurrentViewPreservationInventoryV1Item(item));
}
export function currentViewPreservationInventoryV1Link(
  key: Hex, count: bigint, index: bigint, item: CurrentViewPreservationInventoryV1Item, next: Hex,
): Hex {
  return original.scopedPolicyInventoryV2Link(key, count, index, normalizeCurrentViewPreservationInventoryV1Item(item), next);
}
export function currentViewPreservationInventoryV1Segment(
  key: Hex, witness: Hex, items: readonly CurrentViewPreservationInventoryV1Item[],
): CurrentViewPreservationInventoryV1Segment {
  list(items);
  const tuple = ParamType.from(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_ITEM_TUPLE + "[]");
  if (preflight(tuple, items, false) + 32 > CURRENT_VIEW_PRESERVATION_INVENTORY_V1_MAX_BYTES) throw Error("Segment allocation bound");
  return original.scopedPolicyInventoryV2Segment(key, witness, items.map(normalizeCurrentViewPreservationInventoryV1Item));
}
export function currentViewPreservationInventoryV1AppendSegment(
  previous: Hex, index: bigint, segment: CurrentViewPreservationInventoryV1Segment,
): Hex {
  return original.scopedPolicyInventoryV2AppendSegment(previous, index, normalizeCurrentViewPreservationInventoryV1Segment(segment));
}
export const currentViewPreservationInventoryV1CursorWitness = original.scopedPolicyInventoryV2CursorWitness;

export function currentViewPreservationInventoryV1TokenWitness(
  context: CurrentViewPreservationInventoryV1Context, stage: bigint, index: bigint, count: bigint,
): Hex {
  const c = normalizeCurrentViewPreservationInventoryV1Context(context);
  return hash(["bytes32", "bytes32", "bytes32", "bytes32", "uint16", "uint64", "uint64"],
    [id("6529STREAM_VIEW_PRESERVATION_OUTPUT_INVENTORY_SOURCE_V1"), c.adoptionRecord, c.checkpointHash,
      c.sourceContextHash, uint(stage, 16), uint(index, 64), uint(count, 64)]);
}

export function currentViewPreservationInventoryV1EvidenceHash(
  coordinates: CurrentViewPreservationInventoryV1Coordinates, dependencyHash: Hex,
  value: CurrentViewPreservationInventoryV1Evidence,
): Hex {
  const c = normalizeCurrentViewPreservationInventoryV1Coordinates(coordinates);
  const e = normalizeCurrentViewPreservationInventoryV1Evidence(value);
  return hash(["bytes32", "uint256", "address", "bytes32", CURRENT_VIEW_PRESERVATION_INVENTORY_V1_EVIDENCE_TUPLE],
    [id("6529STREAM_VIEW_PRESERVATION_RENDER_CRITICAL_EVIDENCE_V1"), c.chainId, c.inventory,
      bytes(dependencyHash, 32), { ...e, inventory: { ...e.inventory, renderCriticalEvidenceHash: Z } }]);
}

export function validateCurrentViewPreservationInventoryV1Evidence(
  coordinates: CurrentViewPreservationInventoryV1Coordinates, dependencyHash: Hex,
  value: CurrentViewPreservationInventoryV1Evidence,
): CurrentViewPreservationInventoryV1Evidence {
  const e = normalizeCurrentViewPreservationInventoryV1Evidence(value), p = e.inventory;
  same(p.collectionId, e.scope.collectionId, "Collection");
  same(p.scopeSubject, currentViewPreservationInventoryV1ScopeSubject(coordinates, e.scope), "Scope subject");
  [dependencyHash, p.planId, p.artistId, p.sourceContextHash, p.tokenInventoryHash, p.segmentChainHash].forEach(nonzero);
  if (p.tokenCount === 0n || p.segmentCount === 0n || p.itemCount === 0n) throw Error("Incomplete inventory");
  same(p.renderCriticalEvidenceHash, currentViewPreservationInventoryV1EvidenceHash(coordinates, dependencyHash, e), "Evidence hash");
  return e;
}

/** Builds the original projection from supplied context/progress. It does not admit or seal a plan. */
export function currentViewPreservationInventoryV1Evidence(
  coordinates: CurrentViewPreservationInventoryV1Coordinates, dependencyHash: Hex,
  value: CurrentViewPreservationInventoryV1Context, progress: CurrentViewPreservationInventoryV1Progress,
): CurrentViewPreservationInventoryV1Evidence {
  const c = normalizeCurrentViewPreservationInventoryV1Context(value);
  const p = normalizeCurrentViewPreservationInventoryV1Progress(progress);
  const e: CurrentViewPreservationInventoryV1Evidence = {
    scope: c.scope,
    inventory: {
      planId: currentViewPreservationInventoryV1PlanId(coordinates, dependencyHash, c),
      collectionId: c.scope.collectionId, scopeSubject: c.subject, artistId: c.artistId,
      originals: {
        rootRecordHash: c.rootRecordHash, snapshotRecordHash: c.snapshot.recordHash,
        referenceRenderRecordHash: c.referenceRender.observation.recordHash,
        intentRecordHash: c.conservation.record.kind === 0n ? c.conservation.record.recordHash : Z,
        intentWaiverRecordHash: c.conservation.record.kind === 1n ? c.conservation.record.recordHash : Z,
        interviewEvidenceHash: c.interviewEvidenceHash,
        rightsStatementRecordHash: c.descriptions.rightsStatementRecordHash,
        workDescriptionRecordHash: c.descriptions.workDescriptionRecordHash,
      },
      sourceContextHash: p.sourceContextHash, tokenInventoryHash: c.tokenInventoryHash,
      tokenCount: c.tokenCount, segmentCount: p.segmentCount, itemCount: p.itemCount,
      segmentChainHash: p.segmentChainHash, renderCriticalEvidenceHash: Z,
    },
  };
  return normalizeCurrentViewPreservationInventoryV1Evidence({
    ...e, inventory: { ...e.inventory, renderCriticalEvidenceHash: currentViewPreservationInventoryV1EvidenceHash(coordinates, dependencyHash, e) },
  });
}

function institutional(uri: string): boolean {
  const raw = utf8(uri);
  if (raw.length < 10 || raw.length > 2048 || !uri.startsWith("https://")) return false;
  let end = raw.length;
  for (let i = 8; i < raw.length; ++i) {
    const c = raw[i]!;
    if (c <= 32 || c >= 127 || c === 64 || c === 35 || c === 92 || c === 37) return false;
    if (end === raw.length && c === 47) end = i;
  }
  if (end === 8 || end === raw.length || end + 1 === raw.length || end - 8 > 253) return false;
  return uri.slice(8, end).split(".").every(label =>
    label.length >= 1 && label.length <= 63 && /^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$/.test(label));
}

/** The exact source-derived image obligation; it does not fetch bytes or admit a witness. */
export function currentViewPreservationInventoryV1Obligation(
  value: retrieval.CurrentViewRetrievalV1Source,
): CurrentViewPreservationInventoryV1Item {
  const s = retrieval.normalizeCurrentViewRetrievalV1Source(value);
  const uri = s.requestedURI;
  if (utf8(uri).length > 2048) throw Error("URI bound");
  const row: CurrentViewPreservationInventoryV1Item = {
    kind: 4n, role: Z, source: s.declaration, sourceRecord: s.declarationRecord,
    sourceIndex: 0n, algorithm: 0n, canonicalizationId: id("RAW_BYTES") as Hex,
    digest: "0x", uri, byteSize: 0n, schemaId: Z, formatId: Z, catalogId: Z,
    catalogHash: Z, objectHash: Z, originalCoverageHash: Z, provenanceHash: Z,
  };
  if (uri.length === 0) {
    return normalizeCurrentViewPreservationInventoryV1Item({
      ...row, kind: 7n, role: id("VIEW_OPTIONAL_IMAGE") as Hex, canonicalizationId: Z,
    });
  }
  if (uri.startsWith("ipfs://")) {
    if (uri.length !== 66 || !uri.startsWith("ipfs://b")) throw Error("Unsupported raw CID");
    let accumulator = 0, bits = 0;
    const decoded: number[] = [];
    for (const c of uri.slice(8)) {
      const v = "abcdefghijklmnopqrstuvwxyz234567".indexOf(c);
      if (v < 0) throw Error("Unsupported raw CID");
      accumulator = (accumulator << 5) | v;
      bits += 5;
      if (bits >= 8) {
        bits -= 8;
        decoded.push((accumulator >>> bits) & 255);
        accumulator &= (1 << bits) - 1;
      }
    }
    if (decoded.length !== 36 || bits !== 2 || accumulator !== 0
      || decoded[0] !== 1 || decoded[1] !== 85 || decoded[2] !== 18 || decoded[3] !== 32) throw Error("Unsupported raw CID");
    const digest = nonzero(hexlify(new Uint8Array(decoded.slice(4))));
    return normalizeCurrentViewPreservationInventoryV1Item({
      ...row, role: id("VIEW_CONTENT_ADDRESSED_IMAGE") as Hex, algorithm: 2n, digest,
    });
  }
  const parsed = retrieval.currentViewRetrievalV1URI(uri);
  if (parsed.kind === 2n || (parsed.kind === 1n && institutional(uri))) {
    return normalizeCurrentViewPreservationInventoryV1Item({
      ...row, role: CURRENT_VIEW_PRESERVATION_INVENTORY_V1_LOCATOR_ROLE,
      provenanceHash: hash(["bytes32", "address", "bytes32", "string"],
        [id("6529STREAM_VIEW_ARCHIVE_LOCATOR_OBLIGATION_V1"), s.declaration, s.declarationRecord, uri]),
    });
  }
  return normalizeCurrentViewPreservationInventoryV1Item({
    ...row, role: CURRENT_VIEW_PRESERVATION_INVENTORY_V1_RETRIEVAL_ROLE,
    source: s.router, sourceRecord: s.adoptionRecord,
    provenanceHash: retrieval.currentViewRetrievalV1SourceKey(s),
  });
}

/** Historical rows, segments and commitments only. Original row production is not reconstructed. */
export function authenticateCurrentViewPreservationInventoryV1History(
  coordinates: CurrentViewPreservationInventoryV1Coordinates,
  dependencies: CurrentViewPreservationInventoryV1Dependencies,
  context: CurrentViewPreservationInventoryV1Context,
  plan: CurrentViewPreservationInventoryV1Plan,
  evidence: CurrentViewPreservationInventoryV1Evidence,
  segments: readonly Readonly<{ segment: CurrentViewPreservationInventoryV1Segment; items: readonly CurrentViewPreservationInventoryV1Item[] }>[],
): Readonly<{ evidence: CurrentViewPreservationInventoryV1Evidence; current: false; itemProductionIndependentlyReconstructed: false }> {
  validateCurrentViewPreservationInventoryV1Segments(segments);
  const c = normalizeCurrentViewPreservationInventoryV1Coordinates(coordinates);
  const d = validateCurrentViewPreservationInventoryV1Dependencies(c, dependencies);
  const ctx = validateCurrentViewPreservationInventoryV1Context(c, context);
  const p = normalizeCurrentViewPreservationInventoryV1Plan(plan);
  const dependency = currentViewPreservationInventoryV1DependencyHash(d);
  const e = validateCurrentViewPreservationInventoryV1Evidence(c, dependency, evidence);
  equalTuple(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_SCOPE_TUPLE, p.scope, ctx.scope, "Plan scope");
  equalTuple(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_SCOPE_TUPLE, e.scope, ctx.scope, "Evidence scope");
  same(p.progress.collectionId, ctx.scope.collectionId, "Plan collection");
  same(p.progress.subject, ctx.subject, "Plan subject");
  same(p.progress.artistId, ctx.artistId, "Plan artist");
  same(p.progress.tokenCount, ctx.tokenCount, "Plan count");
  same(p.progress.sourceContextHash, currentViewPreservationInventoryV1ContextHash(ctx), "Context hash");
  same(p.progress.completedStages, 11n, "Completed stages");
  if (p.nativeCount === 0n || p.referenceCount === 0n
    || p.nativeCursor !== p.nativeCount || p.referenceCursor !== p.referenceCount) throw Error("Unfinished source page cursors");
  same(p.progress.nextToken, ctx.tokenCount, "Token progress");
  same(p.progress.renderCriticalEvidenceHash, e.inventory.renderCriticalEvidenceHash, "Sealed evidence");
  equalTuple(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_EVIDENCE_TUPLE, e,
    currentViewPreservationInventoryV1Evidence(c, dependency, ctx, p.progress), "Evidence projection");
  list(segments);
  same(BigInt(segments.length), p.progress.segmentCount, "Segment count");
  let chain = Z, count = 0n;
  segments.forEach((row, i) => {
    exact(row, ["segment", "items"]);
    const segment = normalizeCurrentViewPreservationInventoryV1Segment(row.segment);
    same(segment.key, currentViewPreservationInventoryV1SegmentKey(e.inventory.planId, BigInt(i)), "Segment key");
    equalTuple(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_SEGMENT_TUPLE, segment,
      currentViewPreservationInventoryV1Segment(segment.key, segment.sourceWitnessHash, row.items), "Segment rows");
    chain = currentViewPreservationInventoryV1AppendSegment(chain, BigInt(i), segment);
    count = uint(count + segment.itemCount, 64);
  });
  same(chain, p.progress.segmentChainHash, "Segment chain");
  same(count, p.progress.itemCount, "Item count");
  return Object.freeze({ evidence: e, current: false, itemProductionIndependentlyReconstructed: false });
}

/** Preflights aggregate retained history without copying caller rows or string buffers. */
export function validateCurrentViewPreservationInventoryV1Segments(
  segments: readonly Readonly<{ segment: CurrentViewPreservationInventoryV1Segment; items: readonly CurrentViewPreservationInventoryV1Item[] }>[],
): void {
  list(segments);
  const tuple = ParamType.from(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_ITEM_TUPLE + "[]");
  let bytesTotal = 0, rowsTotal = 0;
  for (const part of segments) {
    exact(part, ["segment", "items"]);
    list(part.items);
    rowsTotal += part.items.length;
    bytesTotal += 160 + preflight(tuple, part.items, false) + 32;
    if (rowsTotal > CURRENT_VIEW_PRESERVATION_INVENTORY_V1_MAX_ROWS
      || bytesTotal > CURRENT_VIEW_PRESERVATION_INVENTORY_V1_MAX_HISTORY_BYTES) throw Error("History allocation bound");
  }
}

export type CurrentViewPreservationInventoryV1Request =
  | Readonly<{ method: "appendArtwork"; id: Hex; }>
  | Readonly<{ method: "appendDefinition"; id: Hex; }>
  | Readonly<{ method: "appendIntent"; id: Hex; witness: CurrentViewPreservationInventoryV1Intent; originalActor: Address; }>
  | Readonly<{ method: "appendIntentWaiver"; id: Hex; witness: CurrentViewPreservationInventoryV1IntentWaiver; originalActor: Address; }>
  | Readonly<{ method: "appendInterview"; id: Hex; witness: CurrentViewPreservationInventoryV1Interview; originalActor: Address; }>
  | Readonly<{ method: "appendInterviewWaiver"; id: Hex; }>
  | Readonly<{ method: "appendNative"; id: Hex; maximum: bigint; }>
  | Readonly<{ method: "appendPreservationAdmission"; id: Hex; }>
  | Readonly<{ method: "appendReference"; id: Hex; maximum: bigint; }>
  | Readonly<{ method: "appendRenderer"; id: Hex; }>
  | Readonly<{ method: "appendRights"; id: Hex; witness: CurrentViewPreservationInventoryV1Statement; }>
  | Readonly<{ method: "appendRootAuthorization"; id: Hex; actor: Address; observedAt: bigint; originalAggregate: CurrentViewPreservationInventoryV1RootAggregate; originalLegacyFamilyHash: Hex; }>
  | Readonly<{ method: "appendTokenOutput"; id: Hex; }>
  | Readonly<{ method: "appendWork"; id: Hex; witness: CurrentViewPreservationInventoryV1Description; originalActor: Address; }>
  | Readonly<{ method: "beginInventory"; scope: CurrentViewPreservationInventoryV1Scope; }>
  | Readonly<{ method: "sealInventory"; id: Hex; }>;
const writeFields = Object.freeze({
  "appendArtwork": [
    "id"
  ],
  "appendDefinition": [
    "id"
  ],
  "appendIntent": [
    "id",
    "witness",
    "originalActor"
  ],
  "appendIntentWaiver": [
    "id",
    "witness",
    "originalActor"
  ],
  "appendInterview": [
    "id",
    "witness",
    "originalActor"
  ],
  "appendInterviewWaiver": [
    "id"
  ],
  "appendNative": [
    "id",
    "maximum"
  ],
  "appendPreservationAdmission": [
    "id"
  ],
  "appendReference": [
    "id",
    "maximum"
  ],
  "appendRenderer": [
    "id"
  ],
  "appendRights": [
    "id",
    "witness"
  ],
  "appendRootAuthorization": [
    "id",
    "actor",
    "observedAt",
    "originalAggregate",
    "originalLegacyFamilyHash"
  ],
  "appendTokenOutput": [
    "id"
  ],
  "appendWork": [
    "id",
    "witness",
    "originalActor"
  ],
  "beginInventory": [
    "scope"
  ],
  "sealInventory": [
    "id"
  ]
});

export type CurrentViewPreservationInventoryV1ReadRequest =
  | Readonly<{ method: "artifactCoverage";  }>
  | Readonly<{ method: "core";  }>
  | Readonly<{ method: "dependencies";  }>
  | Readonly<{ method: "dependencyHash";  }>
  | Readonly<{ method: "externalCoverage";  }>
  | Readonly<{ method: "inventoryEvidence"; id: Hex; }>
  | Readonly<{ method: "inventoryProfile";  }>
  | Readonly<{ method: "inventorySegment"; id: Hex; index: bigint; }>
  | Readonly<{ method: "metadataHost";  }>
  | Readonly<{ method: "metadataRouter";  }>
  | Readonly<{ method: "plan"; id: Hex; }>
  | Readonly<{ method: "referencePublisher";  }>
  | Readonly<{ method: "requireCurrent"; scope: CurrentViewPreservationInventoryV1Scope; }>
  | Readonly<{ method: "requireFullDefinitionBytes"; id: Hex; }>
  | Readonly<{ method: "retrievalWitnessBinding";  }>
  | Readonly<{ method: "snapshots";  }>
  | Readonly<{ method: "sourceContext"; id: Hex; }>
  | Readonly<{ method: "supportsInterface"; id: Hex; }>
  | Readonly<{ method: "tokenProgress"; id: Hex; }>;
const readFields = Object.freeze({
  "artifactCoverage": [],
  "core": [],
  "dependencies": [],
  "dependencyHash": [],
  "externalCoverage": [],
  "inventoryEvidence": [
    "id"
  ],
  "inventoryProfile": [],
  "inventorySegment": [
    "id",
    "index"
  ],
  "metadataHost": [],
  "metadataRouter": [],
  "plan": [
    "id"
  ],
  "referencePublisher": [],
  "requireCurrent": [
    "scope"
  ],
  "requireFullDefinitionBytes": [
    "id"
  ],
  "retrievalWitnessBinding": [],
  "snapshots": [],
  "sourceContext": [
    "id"
  ],
  "supportsInterface": [
    "id"
  ],
  "tokenProgress": [
    "id"
  ]
});

function requestValue<T extends { readonly method: string }>(value: T, fields: Readonly<Record<string, readonly string[]>>): T {
  if (!value || typeof value !== "object" || !Object.prototype.hasOwnProperty.call(fields, value.method)) throw Error("Unsupported original method");
  const names = fields[value.method]!;
  exact(value, ["method", ...names]);
  const fragment = currentViewPreservationInventoryV1Interface().getFunction(value.method)!;
  const tuple = ParamType.from({ type: "tuple", components: fragment.inputs.map((p, i) => ({ ...JSON.parse(p.format("json")), name: names[i] })) });
  const supplied = Object.fromEntries(names.map(n => [n, (value as unknown as Record<string, unknown>)[n]]));
  const normalized = normalize<Record<string, unknown>>(tuple.format("full"), supplied);
  if (encodedSize(tuple, normalized) + 4 > CURRENT_VIEW_PRESERVATION_INVENTORY_V1_MAX_BYTES) throw Error("Whole calldata bound");
  return Object.freeze({ method: value.method, ...normalized }) as T;
}

export function normalizeCurrentViewPreservationInventoryV1Request(value: CurrentViewPreservationInventoryV1Request): CurrentViewPreservationInventoryV1Request {
  const r = requestValue(value, writeFields);
  if (r.method === "beginInventory") validateCurrentViewPreservationInventoryV1Scope(r.scope);
  else nonzero(r.id);
  if ((r.method === "appendNative" || r.method === "appendReference") && (r.maximum === 0n || r.maximum > 64n)) throw Error("Maximum must be 1..64");
  if (r.method === "appendRootAuthorization") {
    address(r.actor, true);
    nonzero(r.originalLegacyFamilyHash);
    nonzero(r.originalAggregate.transitionChain);
    if (r.observedAt === 0n || r.originalAggregate.revision === 0n) throw Error("Invalid original root witness");
  }
  if (r.method === "appendIntent" || r.method === "appendIntentWaiver" || r.method === "appendInterview") address(r.originalActor, true);
  return r;
}

export interface CurrentViewPreservationInventoryV1Call {
  readonly coordinates: CurrentViewPreservationInventoryV1Coordinates;
  readonly caller: Address;
  readonly request: CurrentViewPreservationInventoryV1Request;
  readonly call: UnsignedCall;
}
export function prepareCurrentViewPreservationInventoryV1Call(coordinates: CurrentViewPreservationInventoryV1Coordinates, caller: Address, request: CurrentViewPreservationInventoryV1Request): CurrentViewPreservationInventoryV1Call {
  const c = normalizeCurrentViewPreservationInventoryV1Coordinates(coordinates), r = normalizeCurrentViewPreservationInventoryV1Request(request);
  const fields = writeFields[r.method] as readonly string[];
  const data = bytes(currentViewPreservationInventoryV1Interface().encodeFunctionData(r.method, fields.map(k => (r as unknown as Record<string, unknown>)[k])));
  return Object.freeze({ coordinates: c, caller: address(caller, true), request: r, call: Object.freeze({ to: c.inventory, data, value: 0n }) });
}
export const currentViewPreservationInventoryV1Call = prepareCurrentViewPreservationInventoryV1Call;
export function normalizeCurrentViewPreservationInventoryV1Call(value: CurrentViewPreservationInventoryV1Call): CurrentViewPreservationInventoryV1Call {
  exact(value, ["coordinates", "caller", "request", "call"]);
  exact(value.call, ["to", "data", "value"]);
  const r = prepareCurrentViewPreservationInventoryV1Call(value.coordinates, value.caller, value.request);
  same(address(value.call.to), r.call.to, "Call target");
  same(bytes(value.call.data), r.call.data, "Call data");
  same(uint(value.call.value), 0n, "Call value");
  return r;
}
export interface CurrentViewPreservationInventoryV1Read {
  readonly coordinates: CurrentViewPreservationInventoryV1Coordinates;
  readonly request: CurrentViewPreservationInventoryV1ReadRequest;
  readonly call: UnsignedCall;
}
export function prepareCurrentViewPreservationInventoryV1Read(coordinates: CurrentViewPreservationInventoryV1Coordinates, request: CurrentViewPreservationInventoryV1ReadRequest): CurrentViewPreservationInventoryV1Read {
  const c = normalizeCurrentViewPreservationInventoryV1Coordinates(coordinates), r = requestValue(request, readFields);
  const fields = readFields[r.method] as readonly string[];
  return Object.freeze({ coordinates: c, request: r, call: Object.freeze({ to: c.inventory, value: 0n, data: bytes(currentViewPreservationInventoryV1Interface().encodeFunctionData(r.method, fields.map(k => (r as unknown as Record<string, unknown>)[k]))) }) });
}
export const currentViewPreservationInventoryV1Read = prepareCurrentViewPreservationInventoryV1Read;
export function normalizeCurrentViewPreservationInventoryV1Read(value: CurrentViewPreservationInventoryV1Read): CurrentViewPreservationInventoryV1Read {
  exact(value, ["coordinates", "request", "call"]);
  exact(value.call, ["to", "data", "value"]);
  const r = prepareCurrentViewPreservationInventoryV1Read(value.coordinates, value.request);
  same(address(value.call.to), r.call.to, "Read target");
  same(bytes(value.call.data), r.call.data, "Read data");
  same(uint(value.call.value), 0n, "Read value");
  return r;
}

export interface CurrentViewPreservationInventoryV1Definition {
  readonly index: bigint;
  readonly name: string;
  readonly id: Hex;
  readonly hash: Hex;
}
export const CURRENT_VIEW_PRESERVATION_INVENTORY_V1_DEFINITIONS: readonly CurrentViewPreservationInventoryV1Definition[] = Object.freeze([
  Object.freeze({ index: 0n, name: "STREAM_WORK_DESCRIPTION_V1", id: "0x5bb3543c4c007f4396474b74ec81dd8bca13028b6d945020e4b48ff236b26a3c" as Hex,
    hash: "0xc534a4212c652d620942266ff32d8699bcc40492aa9a323e0f5b711bbc5bba88" as Hex }),
  Object.freeze({ index: 1n, name: "STREAM_WORK_DESCRIPTION_JSON_PROFILE_V1", id: "0x5cbe99f46b06fb16351501c9c1c69f98912cf8534a5ee647d0312ef1de7ebaa0" as Hex,
    hash: "0x1c5e8281a5c12e06b334020bc158dc101dd33baaa449feeb8f504e20bd910353" as Hex }),
  Object.freeze({ index: 2n, name: "STREAM_WORK_FORMAT_CATALOG_V1", id: "0x613d837a313512b0f404a66b152b282d5f309c97bf3d6c4dc98aff573a3fa4cc" as Hex,
    hash: "0xa2c03300254919dad0436cffd743bc869665f06434123b92ae48c5ff98a284ed" as Hex }),
  Object.freeze({ index: 3n, name: "STREAM_WORK_FORMAT_CATALOG_JSON_PROFILE_V1", id: "0x32861d4583bc08f7afbeb7e4e376e3d22dcfc5ebf25ac0e7c8c045c2cfacbbb9" as Hex,
    hash: "0x03799bc44aab386d3032a5859e6e7b7f6558bdb279f0e9906d3af535274a6514" as Hex }),
  Object.freeze({ index: 4n, name: "STREAM_RIGHTS_V1", id: "0xdfdea1c86219c12e182b4023d399be35bd5602461ef1dc727784c18d7742b967" as Hex,
    hash: "0xccb6e9813b29689628095bd2eaaf2b62bdbdfd7e971d14784a9dc419688a33e8" as Hex }),
  Object.freeze({ index: 5n, name: "STREAM_RIGHTS_JSON_PROFILE_V1", id: "0x2d4a7482b51b8267e36531e068971cd09ccdcb230d5945f2899812bc57183120" as Hex,
    hash: "0x15df3f552f58b0a0e8ba75bc4679d6ef3c3c1034fd065646a518bb63edb27174" as Hex }),
  Object.freeze({ index: 6n, name: "STREAM_ARTIST_INTENT_V1", id: "0x2f2a18b3a8b160296c5ef1b1b3385dcaa88d07c066a663d8561771400e666802" as Hex,
    hash: "0x733ff58eb9521aedd7d74c0b53620306095720e5688cbe5b7d94228665f9a009" as Hex }),
  Object.freeze({ index: 7n, name: "STREAM_ARTIST_INTENT_JSON_PROFILE_V1", id: "0xc1faa012c451d83b645154b1d5c6bedd3123e2f2fe8c49807501f32f1747e458" as Hex,
    hash: "0x1522f0f9498ac4a0f652ff201b0681a3711234a15189713cf5e71f71ba53c9c6" as Hex }),
  Object.freeze({ index: 8n, name: "STREAM_ARTIST_INTENT_WAIVER_V1", id: "0x9e029e12429716112002c57124a77e9da820c0baaef00eb3ca5298afb24c0130" as Hex,
    hash: "0xbd017f973eb0c21bc4c1e57bebafd7e48774e8dc91b2424a14597b96a5edfc93" as Hex }),
  Object.freeze({ index: 9n, name: "STREAM_ARTIST_INTENT_WAIVER_JSON_PROFILE_V1", id: "0x3f91b8592bb904265b23cb522d0f799dc098cfd0eef0fdee7cdaa4ae977ce388" as Hex,
    hash: "0xdce44685b162b745cde2e4611d571612c3dc40ab890bedc73436bcd2408f41e1" as Hex }),
  Object.freeze({ index: 10n, name: "STREAM_ARTIST_INTERVIEW_V1", id: "0x12d539ad0aa5da43e241ab876b93cd215e2f2fa9be43f4c6ad3e49a109a45273" as Hex,
    hash: "0x826e7082f5ddcdb972c22411bca7adfd71b7feac7980eaabeb5dc5ec79eb3963" as Hex }),
  Object.freeze({ index: 11n, name: "STREAM_ARTIST_INTERVIEW_JSON_PROFILE_V1", id: "0xe3bda9449d86cbbc77bcd7db0558cfc5e1b0d89c2d922af24b196649df20c7ac" as Hex,
    hash: "0x1533a5140b53a7b0bc3f76524cb01d44c62391c8db570cbdff11fbc9dea6e9cf" as Hex }),
  Object.freeze({ index: 12n, name: "STREAM_CONSERVATION_FORMAT_CATALOG_V1", id: "0xdf4e0a436dfb61d24da9e0af8fd645c99bc907d3ea94e3e34df97db4dd61a177" as Hex,
    hash: "0xb751512d8420de5e72907298460560aa25e274617b9ff25607bf80f1ffa982df" as Hex }),
  Object.freeze({ index: 13n, name: "STREAM_CONSERVATION_FORMAT_CATALOG_JSON_PROFILE_V1", id: "0xf69254cd34854f7c450782b73e5736d7bf0f53418bb7e5e9452ce2267e36c2e6" as Hex,
    hash: "0x5e3712a9d1b640532be098b10855d013323bd7a852cf3b548dfff9babbdb7b3c" as Hex }),
  Object.freeze({ index: 14n, name: "STREAM_RENDERER_CLASS_DECLARATION_V1", id: "0xc2655e28d5193e43fea2e4fdbf2013a87bc9d3d7fc84bfd0f1cdce5376ebdee9" as Hex,
    hash: "0xce9047a5c3bc8ab8aa1b9a5f1cd77a1902725799750654135be9b6f942811bc1" as Hex }),
  Object.freeze({ index: 15n, name: "STREAM_RENDERER_CLASS_DECLARATION_JSON_PROFILE_V1", id: "0x7c055c284160a542f26ef3a52f9f3f515efcf0ca282511f79b654a448506c302" as Hex,
    hash: "0xbec0b224d0e79c1c8d775742321a8f0efb7caaa551ffbd5f758606517a8ad530" as Hex }),
  Object.freeze({ index: 16n, name: "STREAM_REFERENCE_NATIVE_ENVIRONMENT_V1", id: "0xd11f79240dccf3372049d888c61682678bf90a81444b0d3a44e4ba130026de5f" as Hex,
    hash: "0xe09ea65b22dccf9a9528b0ec4c940a831be48a060f0a095157a65aff5b290b90" as Hex }),
  Object.freeze({ index: 17n, name: "STREAM_REFERENCE_PNG_OBJECT_V1", id: "0x2669cdd31c4be774315ad6502522200c9fdd24db4934ea7ec77e081547b10db9" as Hex,
    hash: "0x06dacccbad9218d04f77cbfdd597dfa61e2cab5b58c0fb8f5a1344ce301cb489" as Hex }),
  Object.freeze({ index: 18n, name: "STREAM_REFERENCE_RUNTIME_ZIP_OBJECT_V1", id: "0xc4346603cc517f600a467cc2184e5b94ad7eee5d1d16f8ac4e818770a27e926b" as Hex,
    hash: "0xb3cedd289be34a31fcd20d1941c86e28f31723e4c61f11ddf87894cda4903cac" as Hex }),
  Object.freeze({ index: 19n, name: "STREAM_REFERENCE_NATIVE_FORMATS_V1", id: "0x786032a9ce8e89de0e2f6074c852bee6e3800f5b726395590aca2b6256066adb" as Hex,
    hash: "0x91a426d25d6e00c056cea336611731171bfe84e1b90bf10f7e2e0d0edc6d8c03" as Hex }),
  Object.freeze({ index: 20n, name: "RAW_BYTES", id: "0x220c6deb539ee172cf673a6dd0935cb8f841290a9368519d83add4dbedf24d1f" as Hex,
    hash: "0xcd8112d80b623f930f1df6570b5072d622f9a2aec52ae3cfbecad3f0b65c16e9" as Hex }),
  Object.freeze({ index: 21n, name: "STREAM_VIEW_PRESERVATION_SNAPSHOT_ABI_V1", id: "0x631e1b96d4d53cc6aa52e22aafe4b430c1989ed2e357e43638d71923c4d2b2cf" as Hex,
    hash: "0x93318b938a22ba634ffc52b9f726deefd427b96a849d86bf6ed18c6827561b2e" as Hex }),
  Object.freeze({ index: 22n, name: "STREAM_VIEW_PRESERVATION_SNAPSHOT_PROFILE_V1", id: "0xe763995259b14dbd6a6a47a21df61aedbe0b3ee4b77469736a8aa4048b8428bb" as Hex,
    hash: "0x2ca42835d28a332a6607518127b566a8ce427f955fb08f7650c00180e15969f4" as Hex }),
  Object.freeze({ index: 23n, name: "STREAM_ABI_VIEW_PRESERVATION_SNAPSHOT_V1", id: "0x3629e35f8b4e7adc970ab18501193757c3f21d0e2140995d961fc0bef5269d39" as Hex,
    hash: "0xa749d9fc1982426d543e3efb2fdf7782fb2cf2a5f4ce723c3b1848f094efc032" as Hex }),
  Object.freeze({ index: 24n, name: "STREAM_VIEW_PRESERVATION_REFERENCE_RENDER_ABI_V1", id: "0x85421a7121fb92dce4b30e5934daf41504e01a38c5108df572713445c3646192" as Hex,
    hash: "0x02f129343fa85335c68732f44a41361ac0891401de7fb6a2037c42c2bba212a2" as Hex }),
  Object.freeze({ index: 25n, name: "STREAM_VIEW_PRESERVATION_REFERENCE_RENDER_PROFILE_V1", id: "0x8b9f7b3a1999b01b4538e4a69a6807f1f3e204edab0f6b964cb9dfcf4db69cce" as Hex,
    hash: "0x7d57b0f7d128ad476120e43445c6361a80089baa1205b75d776bdcadad5ed684" as Hex }),
  Object.freeze({ index: 26n, name: "STREAM_VIEW_PRESERVATION_REFERENCE_CANON_V1", id: "0x258d5e63302ae6150e1f08764f0c0b2dcd6a40ae9cd80727a5360af0f61171e6" as Hex,
    hash: "0x63cdb25fc76dd8d9cbbdd8be7f1444c092b0bf96f6a0199a7bee20abe2107491" as Hex }),
  Object.freeze({ index: 27n, name: "STREAM_VIEW_PRESERVATION_CONTENT_ROOT_V1", id: "0x29bd857643b778b590d1415178940c8e925a40a33657441572b92ddd96d64642" as Hex,
    hash: "0x71b098d934ddbb3cabec5596e8062caafe5ae9dfed667070ec1de6756bf52d3e" as Hex }),
  Object.freeze({ index: 28n, name: "STREAM_ABI_VIEW_PRESERVATION_CONTENT_ROOT_V1", id: "0x1aa9343f6326c236963dbf37f61f8d2dde24968263249e13d50d75350b93ed7f" as Hex,
    hash: "0x4f00c5f5b949500583ddd0e68c30ed863c4496e76dca14b44c963c443eca8103" as Hex }),
  Object.freeze({ index: 29n, name: "STREAM_VIEW_PRESERVATION_OUTPUT_PART_V1", id: "0x3c1223a3c67a98a4eb2577700aaf0b96fba93e55993f7b0fa95270d4d7a0e87c" as Hex,
    hash: "0x99e71f8f7615bfe10f244cf08cfd01ce450148cf1c482fc6fb3a965e703ebc2b" as Hex }),
  Object.freeze({ index: 30n, name: "STREAM_ABI_VIEW_PRESERVATION_OUTPUT_PART_V1", id: "0xa86fe4d9e6ebc1f1e09572b85ffbeb5579760e2476f7b16479f7e6734e30862a" as Hex,
    hash: "0x55db652a0ab87f2c1fbfb56b3c7c47629105ab91e3f8449028650bf4a4b0a6c0" as Hex }),
  Object.freeze({ index: 31n, name: "STREAM_VIEW_PRESERVATION_OUTPUT_MANIFEST_V1", id: "0x44d5b532fa71f36e5a7a08b18b8af952c8344fa4c8cd484d76b1f8ab59d5c3b3" as Hex,
    hash: "0x78ee014515c43ffd1568897a4cdd0ef1a5d146340638c74298baf2e8770876e9" as Hex }),
  Object.freeze({ index: 32n, name: "STREAM_ABI_VIEW_PRESERVATION_OUTPUT_MANIFEST_V1", id: "0xd164c0cc15203df446c166b8f8109ca8a53175bdd6ea4ba89596fb138c18e5e3" as Hex,
    hash: "0x3835b590133a51d6fe8afc9749b554b102299b34fd1bddefb67a264488e1206b" as Hex }),
  Object.freeze({ index: 33n, name: "STREAM_VIEW_PRESERVATION_CONTENT_LEAF_V1", id: "0x0017535497a4e6bf7468de61b6591921dee69dea8d944496a9e3c076f0dac428" as Hex,
    hash: "0x81bd11baf81e7344da2dc6c523588d658e51632b0fa5304ec8c31d8ec7673f66" as Hex }),
  Object.freeze({ index: 34n, name: "STREAM_STATIC_POLICY_VIEW_PAYLOAD_V2", id: "0x93d14b631445aeb017cf354a5a171cb920731a410f356d06d50b606554cbb1cd" as Hex,
    hash: "0x2f87791e7154db1a8a459acbdd53e7cd59865b34abc75f0154a38ceb9e0d3a8f" as Hex }),
  Object.freeze({ index: 35n, name: "STREAM_COLLECTION_VIEW_MANIFEST_ABI_V1", id: "0x8a476c6e8e3ff9f8895be858f322bdf80d34514668dc59ad7c782f0ed7ed7a17" as Hex,
    hash: "0x53bd96d96eac71cbbfab3b713dfc8c40450ae5164d431d18de07178e5ca641d2" as Hex }),
]);
export function currentViewPreservationInventoryV1Definition(index: bigint): CurrentViewPreservationInventoryV1Definition {
  if (uint(index, 64) >= 36n) throw Error("Definition index");
  return CURRENT_VIEW_PRESERVATION_INVENTORY_V1_DEFINITIONS[Number(index)]!;
}

export interface CurrentViewPreservationInventoryV1SnapshotDependencies {
  readonly targets: readonly [Address, Address, Address, Address, Address, Address, Address, Address, Address, Address];
  readonly codeHashes: readonly [Hex, Hex, Hex, Hex, Hex, Hex, Hex, Hex, Hex, Hex];
  readonly chainId: bigint;
  readonly readGas: bigint;
  readonly sourceGas: bigint;
  readonly inventoryGas: bigint;
}
export const CURRENT_VIEW_PRESERVATION_INVENTORY_V1_SNAPSHOT_DEPENDENCIES_TUPLE = "(address[10] targets,bytes32[10] codeHashes,uint256 chainId,uint256 readGas,uint256 sourceGas,uint256 inventoryGas)";
export function normalizeCurrentViewPreservationInventoryV1SnapshotDependencies(value: CurrentViewPreservationInventoryV1SnapshotDependencies): CurrentViewPreservationInventoryV1SnapshotDependencies {
  return normalize(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_SNAPSHOT_DEPENDENCIES_TUPLE, value);
}
export function encodeCurrentViewPreservationInventoryV1SnapshotDependencies(value: CurrentViewPreservationInventoryV1SnapshotDependencies): Hex {
  return encode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_SNAPSHOT_DEPENDENCIES_TUPLE, value);
}
export function decodeCurrentViewPreservationInventoryV1SnapshotDependencies(value: Hex): CurrentViewPreservationInventoryV1SnapshotDependencies {
  return decode(CURRENT_VIEW_PRESERVATION_INVENTORY_V1_SNAPSHOT_DEPENDENCIES_TUPLE, value);
}

/** Immutable named roster joins only. Callers must independently pin each runtime/capability. */
export function validateCurrentViewPreservationInventoryV1RetrievalBinding(
  dependencies: CurrentViewPreservationInventoryV1Dependencies,
  configuration: retrieval.CurrentViewRetrievalV1Configuration,
  snapshot: CurrentViewPreservationInventoryV1SnapshotDependencies,
): Readonly<{ configurationHash: Hex; runtimeVerified: false }> {
  const d = normalizeCurrentViewPreservationInventoryV1Dependencies(dependencies);
  const c = retrieval.normalizeCurrentViewRetrievalV1Configuration(configuration);
  const s = normalizeCurrentViewPreservationInventoryV1SnapshotDependencies(snapshot);
  same(c.chainId, d.chainId, "Companion chain");
  same(s.chainId, d.chainId, "Snapshot chain");
  for (const [i, target, codeHash] of [[0, c.core, c.coreCodeHash], [4, c.router, c.routerCodeHash], [11, c.archive, c.archiveCodeHash]] as const) {
    same(d.targets[i], target, "Companion target");
    same(d.codeHashes[i], codeHash, "Companion runtime");
  }
  for (const i of [0, 4] as const) {
    same(s.targets[i], d.targets[i], "Snapshot target");
    same(s.codeHashes[i], d.codeHashes[i], "Snapshot runtime");
  }
  same(s.targets[6], c.checkpoint, "Checkpoint");
  same(s.codeHashes[6], c.checkpointCodeHash, "Checkpoint runtime");
  return Object.freeze({ configurationHash: retrieval.currentViewRetrievalV1ConfigurationHash(c), runtimeVerified: false });
}

/** State predicates only; this does not replace State.stage's fresh Sources.current call. */
export function validateCurrentViewPreservationInventoryV1Stage(
  request: CurrentViewPreservationInventoryV1Request,
  plan: CurrentViewPreservationInventoryV1Plan,
  tokenProgress: CurrentViewPreservationInventoryV1TokenProgress,
): void {
  const r = normalizeCurrentViewPreservationInventoryV1Request(request);
  const p = normalizeCurrentViewPreservationInventoryV1Plan(plan);
  const t = normalizeCurrentViewPreservationInventoryV1TokenProgress(tokenProgress);
  if (r.method === "beginInventory") return;
  const stages: Readonly<Record<Exclude<CurrentViewPreservationInventoryV1Request["method"], "beginInventory">, bigint>> = {
    appendNative: 0n, appendReference: 1n, appendWork: 2n, appendRights: 3n,
    appendIntent: 4n, appendIntentWaiver: 4n, appendInterview: 5n, appendInterviewWaiver: 5n,
    appendRootAuthorization: 6n, appendDefinition: 7n, appendArtwork: 8n, appendRenderer: 9n,
    appendPreservationAdmission: 10n, appendTokenOutput: 11n, sealInventory: 11n,
  };
  if (p.progress.collectionId === 0n || p.progress.renderCriticalEvidenceHash !== Z
    || p.progress.completedStages !== stages[r.method]) throw Error("Incomplete or wrong inventory stage");
  if (r.method === "sealInventory" && (p.progress.nextToken !== p.progress.tokenCount
    || t.phase !== 0n || t.row !== 0n || t.count !== 0n)) throw Error("Unfinished token progress");
}

export function validateCurrentViewPreservationInventoryV1WorkActor(actor: Address, attestationRecordHash: Hex): Address {
  const a = address(actor), record = bytes(attestationRecordHash, 32);
  if ((record === Z) !== (a === ZeroAddress)) throw Error("Original Work actor branch");
  return a;
}

export const CURRENT_VIEW_PRESERVATION_INVENTORY_V1_INTERFACE_ID = "0xb8957a7d" as Hex;
