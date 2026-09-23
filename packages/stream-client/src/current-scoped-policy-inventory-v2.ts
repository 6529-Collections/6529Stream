import { AbiCoder, Interface, ParamType, ZeroAddress, ZeroHash, getAddress, id, isHexString, keccak256, toUtf8Bytes } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import type { UnsignedCall } from "./binding.js";
import * as graph from "./current-scoped-policy-graph-v2.js";
import * as snapshot from "./current-scoped-policy-publication-v2.js";
import * as reference from "./current-scoped-policy-reference-v2.js";
import * as root from "./current-scoped-policy-root-v2.js";

/** Original ABI129. Supplied witnesses do not prove source authority or archive coverage. */
export const SCOPED_POLICY_INVENTORY_V2_SOURCE = "896899f7ca4130f86e066587f780a3b1f755a25d";
export const SCOPED_POLICY_INVENTORY_V2_PROFILE = id("6529STREAM_SCOPED_POLICY_RENDER_CRITICAL_V2") as Hex;
/** Client allocation bounds; the original typed catalogs have no blanket row cap. */
export const SCOPED_POLICY_INVENTORY_V2_MAX_BYTES = 2097152;
export const SCOPED_POLICY_INVENTORY_V2_MAX_ROWS = 8192;

export interface ScopedPolicyInventoryV2Coordinates {
  readonly chainId: bigint;
  readonly core: Address;
  readonly inventory: Address;
}

export type ScopedPolicyInventoryV2Dependencies = graph.ScopedPolicyGraphV2InventoryDependencies;
export interface ScopedPolicyInventoryV2Item {
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

export interface ScopedPolicyInventoryV2Segment {
  readonly key: Hex;
  readonly itemCount: bigint;
  readonly firstLink: Hex;
  readonly sourceWitnessHash: Hex;
}

export interface ScopedPolicyInventoryV2Plan {
  readonly scope: ScopedPolicyInventoryV2Scope;
  readonly progress: ScopedPolicyInventoryV2Progress;
  readonly nativeCursor: bigint;
  readonly nativeCount: bigint;
  readonly referenceCursor: bigint;
  readonly referenceCount: bigint;
}

export type ScopedPolicyInventoryV2Scope = graph.ScopedPolicyGraphV2Scope;
export interface ScopedPolicyInventoryV2Progress {
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

export interface ScopedPolicyInventoryV2TokenProgress {
  readonly phase: bigint;
  readonly row: bigint;
  readonly count: bigint;
}

export interface ScopedPolicyInventoryV2Evidence {
  readonly scope: ScopedPolicyInventoryV2Scope;
  readonly inventory: ScopedPolicyInventoryV2OriginalEvidence;
}

export interface ScopedPolicyInventoryV2OriginalEvidence {
  readonly planId: Hex;
  readonly collectionId: bigint;
  readonly scopeSubject: Hex;
  readonly artistId: Hex;
  readonly originals: ScopedPolicyInventoryV2OriginalInputs;
  readonly sourceContextHash: Hex;
  readonly tokenInventoryHash: Hex;
  readonly tokenCount: bigint;
  readonly segmentCount: bigint;
  readonly itemCount: bigint;
  readonly segmentChainHash: Hex;
  readonly renderCriticalEvidenceHash: Hex;
}

export interface ScopedPolicyInventoryV2OriginalInputs {
  readonly rootRecordHash: Hex;
  readonly snapshotRecordHash: Hex;
  readonly referenceRenderRecordHash: Hex;
  readonly intentRecordHash: Hex;
  readonly intentWaiverRecordHash: Hex;
  readonly interviewEvidenceHash: Hex;
  readonly rightsStatementRecordHash: Hex;
  readonly workDescriptionRecordHash: Hex;
}

export interface ScopedPolicyInventoryV2Context {
  readonly scope: ScopedPolicyInventoryV2Scope;
  readonly subject: Hex;
  readonly artistId: Hex;
  readonly snapshot: ScopedPolicyInventoryV2SnapshotReceipt;
  readonly snapshotSource: ScopedPolicyInventoryV2SnapshotSource;
  readonly referenceRender: ScopedPolicyInventoryV2ReferenceReceipt;
  readonly descriptions: ScopedPolicyInventoryV2DescriptionEvidence;
  readonly conservation: ScopedPolicyInventoryV2ConservationSelection;
  readonly interviewEvidenceHash: Hex;
  readonly nativeHash: Hex;
  readonly rootRecordHash: Hex;
  readonly tokenInventoryHash: Hex;
  readonly checkpointHash: Hex;
  readonly outputManifestRecord: Hex;
  readonly selectionId: Hex;
  readonly selectionHash: Hex;
  readonly tokenCount: bigint;
}

export type ScopedPolicyInventoryV2SnapshotReceipt = snapshot.ScopedPolicyPublicationV2Receipt;
export type ScopedPolicyInventoryV2SnapshotSource = snapshot.ScopedPolicyPublicationV2Source;
export type ScopedPolicyInventoryV2ReferenceReceipt = reference.ScopedPolicyReferenceV2Receipt;
export interface ScopedPolicyInventoryV2DescriptionEvidence {
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

export interface ScopedPolicyInventoryV2ConservationSelection {
  readonly record: ScopedPolicyInventoryV2ConservationRecordEvidence;
  readonly association: ScopedPolicyInventoryV2ConservationAssociation;
  readonly origin: bigint;
  readonly interviewStatus: bigint;
  readonly interview: ScopedPolicyInventoryV2ConservationRecordEvidence;
  readonly interviewArchiveReferenceHash: Hex;
  readonly interviewPayloadCorrespondence: bigint;
  readonly predecessor: Hex;
  readonly submitter: Address;
  readonly revision: bigint;
  readonly selectedAt: bigint;
  readonly catalogsHash: Hex;
  readonly selectionHash: Hex;
}

export interface ScopedPolicyInventoryV2ConservationRecordEvidence {
  readonly recordHash: Hex;
  readonly kind: bigint;
  readonly payloadHash: Hex;
  readonly recorder: Address;
  readonly recordedAt: bigint;
  readonly recordIndex: bigint;
  readonly recordChainHash: Hex;
  readonly receiptHash: Hex;
  readonly publication: ScopedPolicyInventoryV2PublicationEvidence;
  readonly publicationEvidenceHash: Hex;
}

export interface ScopedPolicyInventoryV2PublicationEvidence {
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

export interface ScopedPolicyInventoryV2ConservationAssociation {
  readonly artistId: Hex;
  readonly bindingHash: Hex;
  readonly generation: bigint;
  readonly identityRecordHash: Hex;
}

export interface ScopedPolicyInventoryV2Work {
  readonly subjectId: Hex;
  readonly profileHash: Hex;
  readonly predecessor: Hex;
  readonly form: bigint;
  readonly full: ScopedPolicyInventoryV2WorkFullDescription;
  readonly absence: ScopedPolicyInventoryV2WorkAbsence;
}

export interface ScopedPolicyInventoryV2WorkFullDescription {
  readonly title: string;
  readonly creator: ScopedPolicyInventoryV2WorkCreator;
  readonly creation: ScopedPolicyInventoryV2WorkCreation;
  readonly medium: string;
  readonly format: ScopedPolicyInventoryV2WorkFormat;
  readonly measurements: ScopedPolicyInventoryV2WorkMeasurements;
  readonly edition: ScopedPolicyInventoryV2WorkEdition;
  readonly creditLine: string;
  readonly hasInscription: boolean;
  readonly inscription: string;
  readonly alternateTitles: readonly string[];
  readonly languageVariants: readonly ScopedPolicyInventoryV2WorkLanguageVariant[];
  readonly authorityReferences: readonly ScopedPolicyInventoryV2WorkAuthorityReference[];
}

export interface ScopedPolicyInventoryV2WorkCreator {
  readonly kind: bigint;
  readonly artistId: Hex;
  readonly bindingGeneration: bigint;
  readonly bindingHash: Hex;
  readonly name: string;
}

export interface ScopedPolicyInventoryV2WorkCreation {
  readonly kind: bigint;
  readonly start: bigint;
  readonly end: bigint;
}

export interface ScopedPolicyInventoryV2WorkFormat {
  readonly kind: bigint;
  readonly formatId: Hex;
  readonly puid: string;
  readonly catalog: ScopedPolicyInventoryV2WorkCatalog;
}

export interface ScopedPolicyInventoryV2WorkCatalog {
  readonly name: string;
  readonly entries: readonly ScopedPolicyInventoryV2WorkCatalogEntry[];
  readonly selectedEntryId: Hex;
}

export interface ScopedPolicyInventoryV2WorkCatalogEntry {
  readonly entryId: Hex;
  readonly kind: bigint;
  readonly puid: string;
  readonly specification: ScopedPolicyInventoryV2WorkSpecification;
}

export interface ScopedPolicyInventoryV2WorkSpecification {
  readonly uri: string;
  readonly digest: Hex;
}

export interface ScopedPolicyInventoryV2WorkMeasurements {
  readonly kind: bigint;
  readonly hasPixels: boolean;
  readonly width: bigint;
  readonly height: bigint;
  readonly hasAspectRatio: boolean;
  readonly aspectRatio: ScopedPolicyInventoryV2WorkRational;
  readonly hasDuration: boolean;
  readonly durationSeconds: ScopedPolicyInventoryV2WorkRational;
}

export interface ScopedPolicyInventoryV2WorkRational {
  readonly numerator: bigint;
  readonly denominator: bigint;
}

export interface ScopedPolicyInventoryV2WorkEdition {
  readonly kind: bigint;
  readonly number: bigint;
  readonly total: bigint;
  readonly statement: string;
}

export interface ScopedPolicyInventoryV2WorkLanguageVariant {
  readonly field: bigint;
  readonly alternateTitleIndex: bigint;
  readonly language: string;
  readonly value: string;
}

export interface ScopedPolicyInventoryV2WorkAuthorityReference {
  readonly role: bigint;
  readonly authority: bigint;
  readonly identifier: string;
}

export interface ScopedPolicyInventoryV2WorkAbsence {
  readonly reason: string;
  readonly date: bigint;
}

export interface ScopedPolicyInventoryV2Rights {
  readonly subjectId: Hex;
  readonly profileHash: Hex;
  readonly basis: bigint;
  readonly licensor: ScopedPolicyInventoryV2RightsLicensor;
  readonly grants: ScopedPolicyInventoryV2RightsGrants;
  readonly startDate: bigint;
  readonly endDate: bigint;
  readonly openEnd: boolean;
  readonly instrument: ScopedPolicyInventoryV2RightsDocument;
  readonly hasAiTrainingPermission: boolean;
  readonly aiTrainingPermission: bigint;
  readonly predecessor: Hex;
}

export interface ScopedPolicyInventoryV2RightsLicensor {
  readonly kind: bigint;
  readonly artistId: Hex;
  readonly name: string;
  readonly account: Address;
  readonly instrumentDigest: Hex;
}

export interface ScopedPolicyInventoryV2RightsGrants {
  readonly aiTraining: ScopedPolicyInventoryV2RightsGrant;
  readonly derivative: ScopedPolicyInventoryV2RightsGrant;
  readonly exhibition: ScopedPolicyInventoryV2RightsGrant;
  readonly print: ScopedPolicyInventoryV2RightsGrant;
  readonly publication: ScopedPolicyInventoryV2RightsGrant;
  readonly reproduction: ScopedPolicyInventoryV2RightsGrant;
}

export interface ScopedPolicyInventoryV2RightsGrant {
  readonly status: bigint;
  readonly conditions: ScopedPolicyInventoryV2RightsConditions;
  readonly extension: string;
}

export interface ScopedPolicyInventoryV2RightsConditions {
  readonly kind: bigint;
  readonly text: string;
  readonly document: ScopedPolicyInventoryV2RightsDocument;
}

export interface ScopedPolicyInventoryV2RightsDocument {
  readonly exists: boolean;
  readonly uri: string;
  readonly digest: Hex;
}

export interface ScopedPolicyInventoryV2Intent {
  readonly subjectId: Hex;
  readonly profileHash: Hex;
  readonly predecessor: Hex;
  readonly artist: ScopedPolicyInventoryV2ConservationArtistClaim;
  readonly display: ScopedPolicyInventoryV2ConservationDisplay;
  readonly variabilityTolerances: ScopedPolicyInventoryV2ConservationReference;
  readonly dependencyAging: ScopedPolicyInventoryV2ConservationReference;
  readonly significantProperties: ScopedPolicyInventoryV2ConservationReference;
  readonly interview: ScopedPolicyInventoryV2ConservationInterviewEntry;
}

export interface ScopedPolicyInventoryV2ConservationArtistClaim {
  readonly artistId: Hex;
  readonly bindingGeneration: bigint;
  readonly bindingHash: Hex;
  readonly origin: bigint;
}

export interface ScopedPolicyInventoryV2ConservationDisplay {
  readonly scale: ScopedPolicyInventoryV2ConservationReference;
  readonly timing: ScopedPolicyInventoryV2ConservationReference;
  readonly color: ScopedPolicyInventoryV2ConservationReference;
  readonly interaction: ScopedPolicyInventoryV2ConservationReference;
  readonly motion: ScopedPolicyInventoryV2ConservationReference;
  readonly frameRate: ScopedPolicyInventoryV2ConservationReference;
}

export interface ScopedPolicyInventoryV2ConservationReference {
  readonly algorithm: bigint;
  readonly canonicalizationId: Hex;
  readonly digest: Hex;
  readonly uri: string;
}

export interface ScopedPolicyInventoryV2ConservationInterviewEntry {
  readonly status: bigint;
  readonly record: ScopedPolicyInventoryV2ConservationInterviewRecord;
  readonly waiverStatement: ScopedPolicyInventoryV2ConservationReference;
}

export interface ScopedPolicyInventoryV2ConservationInterviewRecord {
  readonly chainId: bigint;
  readonly core: Address;
  readonly host: Address;
  readonly recordHash: Hex;
  readonly schemaId: Hex;
  readonly profileHash: Hex;
  readonly payload: ScopedPolicyInventoryV2ConservationReference;
}

export interface ScopedPolicyInventoryV2IntentWaiver {
  readonly subjectId: Hex;
  readonly profileHash: Hex;
  readonly predecessor: Hex;
  readonly artist: ScopedPolicyInventoryV2ConservationArtistClaim;
  readonly waiverStatement: ScopedPolicyInventoryV2ConservationReference;
  readonly interview: ScopedPolicyInventoryV2ConservationInterviewEntry;
}

export interface ScopedPolicyInventoryV2Interview {
  readonly subjectId: Hex;
  readonly profileHash: Hex;
  readonly predecessor: Hex;
  readonly instrument: ScopedPolicyInventoryV2ConservationInstrument;
  readonly participants: readonly ScopedPolicyInventoryV2ConservationParticipant[];
  readonly interviewDate: bigint;
  readonly languages: readonly string[];
  readonly transcript: ScopedPolicyInventoryV2ConservationPayload;
  readonly captures: readonly ScopedPolicyInventoryV2ConservationCapture[];
}

export interface ScopedPolicyInventoryV2ConservationInstrument {
  readonly kind: bigint;
  readonly name: string;
  readonly document: ScopedPolicyInventoryV2ConservationReference;
}

export interface ScopedPolicyInventoryV2ConservationParticipant {
  readonly role: bigint;
  readonly otherRole: string;
  readonly identity: ScopedPolicyInventoryV2ConservationReference;
}

export interface ScopedPolicyInventoryV2ConservationPayload {
  readonly content: ScopedPolicyInventoryV2ConservationReference;
  readonly format: ScopedPolicyInventoryV2ConservationFormat;
}

export interface ScopedPolicyInventoryV2ConservationFormat {
  readonly kind: bigint;
  readonly formatId: Hex;
  readonly puid: string;
  readonly catalog: ScopedPolicyInventoryV2ConservationCatalog;
}

export interface ScopedPolicyInventoryV2ConservationCatalog {
  readonly name: string;
  readonly entries: readonly ScopedPolicyInventoryV2ConservationCatalogEntry[];
  readonly selectedEntryId: Hex;
}

export interface ScopedPolicyInventoryV2ConservationCatalogEntry {
  readonly entryId: Hex;
  readonly kind: bigint;
  readonly puid: string;
  readonly specification: ScopedPolicyInventoryV2ConservationReference;
}

export interface ScopedPolicyInventoryV2ConservationCapture {
  readonly kind: bigint;
  readonly payload: ScopedPolicyInventoryV2ConservationPayload;
}

export type ScopedPolicyInventoryV2Payload = snapshot.ScopedPolicyPublicationV2Payload;
export interface ScopedPolicyInventoryV2DocumentFacts {
  readonly exists: boolean;
  readonly kind: bigint;
  readonly status: bigint;
  readonly contentHash: Hex;
  readonly canonicalizationId: Hex;
  readonly supersedesId: Hex;
  readonly totalBytes: bigint;
  readonly chunkCount: bigint;
  readonly declarationHash: Hex;
}

export type ScopedPolicyInventoryV2Aggregate = root.ScopedPolicyRootV2Aggregate;
export const SCOPED_POLICY_INVENTORY_V2_DEPENDENCIES_TUPLE = graph.SCOPED_POLICY_GRAPH_V2_INVENTORY_DEPENDENCIES_TUPLE;
export const SCOPED_POLICY_INVENTORY_V2_ITEM_TUPLE = "(uint8 kind, bytes32 role, address source, bytes32 sourceRecord, uint256 sourceIndex, uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri, uint64 byteSize, bytes32 schemaId, bytes32 formatId, bytes32 catalogId, bytes32 catalogHash, bytes32 objectHash, bytes32 originalCoverageHash, bytes32 provenanceHash)";
export const SCOPED_POLICY_INVENTORY_V2_SEGMENT_TUPLE = "(bytes32 key, uint64 itemCount, bytes32 firstLink, bytes32 sourceWitnessHash)";
export const SCOPED_POLICY_INVENTORY_V2_PLAN_TUPLE = "((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, (uint256 collectionId, bytes32 subject, bytes32 artistId, bytes32 sourceContextHash, uint64 tokenCount, uint64 nextToken, uint64 segmentCount, uint64 itemCount, bytes32 segmentChainHash, uint16 completedStages, bytes32 renderCriticalEvidenceHash) progress, uint64 nativeCursor, uint64 nativeCount, uint64 referenceCursor, uint64 referenceCount)";
export const SCOPED_POLICY_INVENTORY_V2_PROGRESS_TUPLE = "(uint256 collectionId, bytes32 subject, bytes32 artistId, bytes32 sourceContextHash, uint64 tokenCount, uint64 nextToken, uint64 segmentCount, uint64 itemCount, bytes32 segmentChainHash, uint16 completedStages, bytes32 renderCriticalEvidenceHash)";
export const SCOPED_POLICY_INVENTORY_V2_TOKEN_PROGRESS_TUPLE = "(uint8 phase, uint64 row, uint64 count)";
export const SCOPED_POLICY_INVENTORY_V2_EVIDENCE_TUPLE = "((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, (bytes32 planId, uint256 collectionId, bytes32 scopeSubject, bytes32 artistId, (bytes32 rootRecordHash, bytes32 snapshotRecordHash, bytes32 referenceRenderRecordHash, bytes32 intentRecordHash, bytes32 intentWaiverRecordHash, bytes32 interviewEvidenceHash, bytes32 rightsStatementRecordHash, bytes32 workDescriptionRecordHash) originals, bytes32 sourceContextHash, bytes32 tokenInventoryHash, uint64 tokenCount, uint64 segmentCount, uint64 itemCount, bytes32 segmentChainHash, bytes32 renderCriticalEvidenceHash) inventory)";
export const SCOPED_POLICY_INVENTORY_V2_ORIGINAL_EVIDENCE_TUPLE = "(bytes32 planId, uint256 collectionId, bytes32 scopeSubject, bytes32 artistId, (bytes32 rootRecordHash, bytes32 snapshotRecordHash, bytes32 referenceRenderRecordHash, bytes32 intentRecordHash, bytes32 intentWaiverRecordHash, bytes32 interviewEvidenceHash, bytes32 rightsStatementRecordHash, bytes32 workDescriptionRecordHash) originals, bytes32 sourceContextHash, bytes32 tokenInventoryHash, uint64 tokenCount, uint64 segmentCount, uint64 itemCount, bytes32 segmentChainHash, bytes32 renderCriticalEvidenceHash)";
export const SCOPED_POLICY_INVENTORY_V2_ORIGINAL_INPUTS_TUPLE = "(bytes32 rootRecordHash, bytes32 snapshotRecordHash, bytes32 referenceRenderRecordHash, bytes32 intentRecordHash, bytes32 intentWaiverRecordHash, bytes32 interviewEvidenceHash, bytes32 rightsStatementRecordHash, bytes32 workDescriptionRecordHash)";
export const SCOPED_POLICY_INVENTORY_V2_CONTEXT_TUPLE = "((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, bytes32 subject, bytes32 artistId, (bytes32 recordHash, bytes32 scopeSubject, bytes32 predecessor, uint64 revision, bytes32 chainHash, bytes32 manifestHash, uint32 manifestBytes, bytes32 sourceHash, address publisher, uint8 authorizationClass, uint64 grantRevision, uint8 displayAuthorizationClass, uint64 displayGrantRevision, uint64 recordedAt, bytes32 schemaHash, bytes32 profileHash, bytes32 canonicalizationHash) snapshot, ((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, (bytes32 scopeSubject, bytes32 scopeManifestHash, bytes32 sourceRecordHash, uint256 tokenCount, bytes32 tokenListHash, bytes32 membershipHash, uint256 inventoryCount, bytes32 inventoryPrefixHash) membership, (bool locked, address registry, bytes32 registryCodeHash, bytes32 artistId, uint64 bindingGeneration, bytes32 bindingHash, address nominatedArtist, bytes32 identityRecordHash, bytes32 acceptanceRecordHash, uint64 acceptedAt, uint64 lockedAt, bytes32 snapshotHash) artist, ((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, bytes32 membershipHash, bytes32 collectionStateHash, uint64 tokenCount, uint64 nextIndex, bytes32 selectionRoot) selection, (bytes32 selectionId, bytes32 selectionHash, bytes32 inventoryHash, bytes32 policyChainHash, (uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, uint64 tokenCount, uint64 nextIndex, bytes32 leafChainHash, bytes32 contentRoot, bytes32 outputRoot) content, (bytes32 checkpointHash, bytes32 checkpointStateHash, address entropySourceSet, bytes32 inventoryHash, bytes32 policyChainHash, bytes32 artifactHash, bytes32 coverageHash, bytes32 artistId, bytes32 contentRoot, bytes32 outputRoot, bytes32 manifestHash, (uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, uint64 tokenCount, uint64 byteLength) outputs, address sourceFactory, bytes32 sourceFactoryCodeHash, bytes32 factoryDependenciesHash, (bytes32 planId, bytes32 inventoryHash, bytes32 policyChainHash, uint256 policyCount, bool allFrozen, (address coordinator, bytes32 indexedCodeHash, uint256 firstTokenIndex, bool frozen, bytes32 moduleVersion, bytes32 moduleManifestHash, bytes32 moduleSchemaHash, bytes32 deploymentManifestHash, bytes32 policyHash, address provider, uint32 epoch, bytes32 salt, bytes32 componentDataHash, bool explicitPolicy, (bool configured, bool explicitPolicy, bool frozen, uint8 mode, uint8 securityClass, uint8 renderRequirement, uint64 revision, uint32 providerEpoch, bytes32 policyHash, bytes32 contentStateHash, bytes32 lastActionId, bytes32 artistConsentRecord) collectionPolicy)[] policies) entropy) snapshotSource, (bytes32 scopeSubject, (bytes32 recordHash, bytes32 recordChainHash, uint256 collectionId, bytes32 referenceId, bytes32 predecessor, uint64 revision, bytes32 payloadHash, uint32 payloadBytes, bytes32 sourcesHash, bytes32 snapshotRecordHash, uint64 snapshotRevision, address recorder, uint8 authorizationClass, uint64 grantRevision, uint64 effectiveAt, uint64 recordedAt, bytes32 reasonHash, bytes32 schemaHash, bytes32 profileHash, bytes32 canonicalizationHash) observation) referenceRender, (bytes32 scopeSubject, bytes32 workDescriptionRecordHash, bytes32 rightsStatementRecordHash, bytes32 workPayloadHash, bytes32 rightsPayloadHash, bytes32 workSelectionHash, bytes32 rightsSelectionHash, uint64 workRevision, uint64 rightsRevision) descriptions, ((bytes32 recordHash, uint8 kind, bytes32 payloadHash, address recorder, uint64 recordedAt, uint64 recordIndex, bytes32 recordChainHash, bytes32 receiptHash, (bytes32 attestationRecordHash, bytes32 artistId, bytes32 bindingHash, uint64 bindingGeneration, address signer, uint8 authorityClass, uint32 requiredCapability, uint64 signedAt, bytes32 publicationHash) publication, bytes32 publicationEvidenceHash) record, (bytes32 artistId, bytes32 bindingHash, uint64 generation, bytes32 identityRecordHash) association, uint8 origin, uint8 interviewStatus, (bytes32 recordHash, uint8 kind, bytes32 payloadHash, address recorder, uint64 recordedAt, uint64 recordIndex, bytes32 recordChainHash, bytes32 receiptHash, (bytes32 attestationRecordHash, bytes32 artistId, bytes32 bindingHash, uint64 bindingGeneration, address signer, uint8 authorityClass, uint32 requiredCapability, uint64 signedAt, bytes32 publicationHash) publication, bytes32 publicationEvidenceHash) interview, bytes32 interviewArchiveReferenceHash, uint8 interviewPayloadCorrespondence, bytes32 predecessor, address submitter, uint64 revision, uint64 selectedAt, bytes32 catalogsHash, bytes32 selectionHash) conservation, bytes32 interviewEvidenceHash, bytes32 nativeHash, bytes32 rootRecordHash, bytes32 tokenInventoryHash, bytes32 checkpointHash, bytes32 outputManifestRecord, bytes32 selectionId, bytes32 selectionHash, uint64 tokenCount)";
export const SCOPED_POLICY_INVENTORY_V2_WORK_TUPLE = "(bytes32 subjectId, bytes32 profileHash, bytes32 predecessor, uint8 form, (string title, (uint8 kind, bytes32 artistId, uint64 bindingGeneration, bytes32 bindingHash, string name) creator, (uint8 kind, uint32 start, uint32 end) creation, string medium, (uint8 kind, bytes32 formatId, string puid, (string name, (bytes32 entryId, uint8 kind, string puid, (string uri, bytes32 digest) specification)[] entries, bytes32 selectedEntryId) catalog) format, (uint8 kind, bool hasPixels, uint256 width, uint256 height, bool hasAspectRatio, (uint256 numerator, uint256 denominator) aspectRatio, bool hasDuration, (uint256 numerator, uint256 denominator) durationSeconds) measurements, (uint8 kind, uint256 number, uint256 total, string statement) edition, string creditLine, bool hasInscription, string inscription, string[] alternateTitles, (uint8 field, uint8 alternateTitleIndex, string language, string value)[] languageVariants, (uint8 role, uint8 authority, string identifier)[] authorityReferences) full, (string reason, uint32 date) absence)";
export const SCOPED_POLICY_INVENTORY_V2_RIGHTS_TUPLE = "(bytes32 subjectId, bytes32 profileHash, uint8 basis, (uint8 kind, bytes32 artistId, string name, address account, bytes32 instrumentDigest) licensor, ((uint8 status, (uint8 kind, string text, (bool exists, string uri, bytes32 digest) document) conditions, string extension) aiTraining, (uint8 status, (uint8 kind, string text, (bool exists, string uri, bytes32 digest) document) conditions, string extension) derivative, (uint8 status, (uint8 kind, string text, (bool exists, string uri, bytes32 digest) document) conditions, string extension) exhibition, (uint8 status, (uint8 kind, string text, (bool exists, string uri, bytes32 digest) document) conditions, string extension) print, (uint8 status, (uint8 kind, string text, (bool exists, string uri, bytes32 digest) document) conditions, string extension) publication, (uint8 status, (uint8 kind, string text, (bool exists, string uri, bytes32 digest) document) conditions, string extension) reproduction) grants, uint32 startDate, uint32 endDate, bool openEnd, (bool exists, string uri, bytes32 digest) instrument, bool hasAiTrainingPermission, uint8 aiTrainingPermission, bytes32 predecessor)";
export const SCOPED_POLICY_INVENTORY_V2_INTENT_TUPLE = "(bytes32 subjectId, bytes32 profileHash, bytes32 predecessor, (bytes32 artistId, uint64 bindingGeneration, bytes32 bindingHash, uint8 origin) artist, ((uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) scale, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) timing, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) color, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) interaction, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) motion, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) frameRate) display, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) variabilityTolerances, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) dependencyAging, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) significantProperties, (uint8 status, (uint256 chainId, address core, address host, bytes32 recordHash, bytes32 schemaId, bytes32 profileHash, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) payload) record, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) waiverStatement) interview)";
export const SCOPED_POLICY_INVENTORY_V2_INTENT_WAIVER_TUPLE = "(bytes32 subjectId, bytes32 profileHash, bytes32 predecessor, (bytes32 artistId, uint64 bindingGeneration, bytes32 bindingHash, uint8 origin) artist, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) waiverStatement, (uint8 status, (uint256 chainId, address core, address host, bytes32 recordHash, bytes32 schemaId, bytes32 profileHash, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) payload) record, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) waiverStatement) interview)";
export const SCOPED_POLICY_INVENTORY_V2_INTERVIEW_TUPLE = "(bytes32 subjectId, bytes32 profileHash, bytes32 predecessor, (uint8 kind, string name, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) document) instrument, (uint8 role, string otherRole, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) identity)[] participants, uint32 interviewDate, string[] languages, ((uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) content, (uint8 kind, bytes32 formatId, string puid, (string name, (bytes32 entryId, uint8 kind, string puid, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) specification)[] entries, bytes32 selectedEntryId) catalog) format) transcript, (uint8 kind, ((uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) content, (uint8 kind, bytes32 formatId, string puid, (string name, (bytes32 entryId, uint8 kind, string puid, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) specification)[] entries, bytes32 selectedEntryId) catalog) format) payload)[] captures)";
export const SCOPED_POLICY_INVENTORY_V2_PAYLOAD_TUPLE = snapshot.SCOPED_POLICY_PUBLICATION_V2_PAYLOAD_TUPLE;
export const SCOPED_POLICY_INVENTORY_V2_DOCUMENT_FACTS_TUPLE = "(bool exists, uint8 kind, uint8 status, bytes32 contentHash, bytes32 canonicalizationId, bytes32 supersedesId, uint32 totalBytes, uint256 chunkCount, bytes32 declarationHash)";
export const SCOPED_POLICY_INVENTORY_V2_SCOPE_TUPLE = graph.SCOPED_POLICY_GRAPH_V2_SCOPE_TUPLE;
export const SCOPED_POLICY_INVENTORY_V2_AGGREGATE_TUPLE = root.SCOPED_POLICY_ROOT_V2_AGGREGATE_TUPLE;

const enumFields: Readonly<Record<string, Readonly<Record<string, number>>>> = {
  "(uint8 kind, bytes32 role, address source, bytes32 sourceRecord, uint256 sourceIndex, uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri, uint64 byteSize, bytes32 schemaId, bytes32 formatId, bytes32 catalogId, bytes32 catalogHash, bytes32 objectHash, bytes32 originalCoverageHash, bytes32 provenanceHash)": {
    "kind": 11
  },
  "(uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId)": {
    "scopeType": 4
  },
  "(bytes32 recordHash, uint8 kind, bytes32 payloadHash, address recorder, uint64 recordedAt, uint64 recordIndex, bytes32 recordChainHash, bytes32 receiptHash, (bytes32 attestationRecordHash, bytes32 artistId, bytes32 bindingHash, uint64 bindingGeneration, address signer, uint8 authorityClass, uint32 requiredCapability, uint64 signedAt, bytes32 publicationHash) publication, bytes32 publicationEvidenceHash)": {
    "kind": 2
  },
  "((bytes32 recordHash, uint8 kind, bytes32 payloadHash, address recorder, uint64 recordedAt, uint64 recordIndex, bytes32 recordChainHash, bytes32 receiptHash, (bytes32 attestationRecordHash, bytes32 artistId, bytes32 bindingHash, uint64 bindingGeneration, address signer, uint8 authorityClass, uint32 requiredCapability, uint64 signedAt, bytes32 publicationHash) publication, bytes32 publicationEvidenceHash) record, (bytes32 artistId, bytes32 bindingHash, uint64 generation, bytes32 identityRecordHash) association, uint8 origin, uint8 interviewStatus, (bytes32 recordHash, uint8 kind, bytes32 payloadHash, address recorder, uint64 recordedAt, uint64 recordIndex, bytes32 recordChainHash, bytes32 receiptHash, (bytes32 attestationRecordHash, bytes32 artistId, bytes32 bindingHash, uint64 bindingGeneration, address signer, uint8 authorityClass, uint32 requiredCapability, uint64 signedAt, bytes32 publicationHash) publication, bytes32 publicationEvidenceHash) interview, bytes32 interviewArchiveReferenceHash, uint8 interviewPayloadCorrespondence, bytes32 predecessor, address submitter, uint64 revision, uint64 selectedAt, bytes32 catalogsHash, bytes32 selectionHash)": {
    "origin": 1,
    "interviewStatus": 1,
    "interviewPayloadCorrespondence": 2
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
  "(bool exists, uint8 kind, uint8 status, bytes32 contentHash, bytes32 canonicalizationId, bytes32 supersedesId, uint32 totalBytes, uint256 chunkCount, bytes32 declarationHash)": {
    "kind": 3,
    "status": 2
  }
};

export const SCOPED_POLICY_INVENTORY_V2_ABI = Object.freeze([
  "error InvalidInventorySegment()",
  "error InventoryIncomplete()",
  "error InventorySourceChanged()",
  "event ScopedInventoryCompleted(uint16 schemaVersion, bytes32 indexed id, bytes32 indexed evidenceHash, ((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, (bytes32 planId, uint256 collectionId, bytes32 scopeSubject, bytes32 artistId, (bytes32 rootRecordHash, bytes32 snapshotRecordHash, bytes32 referenceRenderRecordHash, bytes32 intentRecordHash, bytes32 intentWaiverRecordHash, bytes32 interviewEvidenceHash, bytes32 rightsStatementRecordHash, bytes32 workDescriptionRecordHash) originals, bytes32 sourceContextHash, bytes32 tokenInventoryHash, uint64 tokenCount, uint64 segmentCount, uint64 itemCount, bytes32 segmentChainHash, bytes32 renderCriticalEvidenceHash) inventory) evidence)",
  "event ScopedInventorySegmentRecorded(uint16 schemaVersion, bytes32 indexed id, uint64 indexed index, (bytes32 key, uint64 itemCount, bytes32 firstLink, bytes32 sourceWitnessHash) segment, (uint8 kind, bytes32 role, address source, bytes32 sourceRecord, uint256 sourceIndex, uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri, uint64 byteSize, bytes32 schemaId, bytes32 formatId, bytes32 catalogId, bytes32 catalogHash, bytes32 objectHash, bytes32 originalCoverageHash, bytes32 provenanceHash)[] items)",
  "event ScopedInventoryStarted(uint16 schemaVersion, bytes32 indexed id, (uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, bytes32 contextHash)",
  "function appendDefinition(bytes32 id)",
  "function appendIntent(bytes32, (bytes32 subjectId, bytes32 profileHash, bytes32 predecessor, (bytes32 artistId, uint64 bindingGeneration, bytes32 bindingHash, uint8 origin) artist, ((uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) scale, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) timing, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) color, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) interaction, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) motion, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) frameRate) display, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) variabilityTolerances, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) dependencyAging, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) significantProperties, (uint8 status, (uint256 chainId, address core, address host, bytes32 recordHash, bytes32 schemaId, bytes32 profileHash, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) payload) record, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) waiverStatement) interview), address)",
  "function appendIntentWaiver(bytes32, (bytes32 subjectId, bytes32 profileHash, bytes32 predecessor, (bytes32 artistId, uint64 bindingGeneration, bytes32 bindingHash, uint8 origin) artist, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) waiverStatement, (uint8 status, (uint256 chainId, address core, address host, bytes32 recordHash, bytes32 schemaId, bytes32 profileHash, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) payload) record, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) waiverStatement) interview), address)",
  "function appendInterview(bytes32, (bytes32 subjectId, bytes32 profileHash, bytes32 predecessor, (uint8 kind, string name, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) document) instrument, (uint8 role, string otherRole, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) identity)[] participants, uint32 interviewDate, string[] languages, ((uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) content, (uint8 kind, bytes32 formatId, string puid, (string name, (bytes32 entryId, uint8 kind, string puid, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) specification)[] entries, bytes32 selectedEntryId) catalog) format) transcript, (uint8 kind, ((uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) content, (uint8 kind, bytes32 formatId, string puid, (string name, (bytes32 entryId, uint8 kind, string puid, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) specification)[] entries, bytes32 selectedEntryId) catalog) format) payload)[] captures), address)",
  "function appendInterviewWaiver(bytes32 id)",
  "function appendNative(bytes32 id, uint64 maximum)",
  "function appendReference(bytes32 id, uint64 maximum)",
  "function appendRights(bytes32, (bytes32 subjectId, bytes32 profileHash, uint8 basis, (uint8 kind, bytes32 artistId, string name, address account, bytes32 instrumentDigest) licensor, ((uint8 status, (uint8 kind, string text, (bool exists, string uri, bytes32 digest) document) conditions, string extension) aiTraining, (uint8 status, (uint8 kind, string text, (bool exists, string uri, bytes32 digest) document) conditions, string extension) derivative, (uint8 status, (uint8 kind, string text, (bool exists, string uri, bytes32 digest) document) conditions, string extension) exhibition, (uint8 status, (uint8 kind, string text, (bool exists, string uri, bytes32 digest) document) conditions, string extension) print, (uint8 status, (uint8 kind, string text, (bool exists, string uri, bytes32 digest) document) conditions, string extension) publication, (uint8 status, (uint8 kind, string text, (bool exists, string uri, bytes32 digest) document) conditions, string extension) reproduction) grants, uint32 startDate, uint32 endDate, bool openEnd, (bool exists, string uri, bytes32 digest) instrument, bool hasAiTrainingPermission, uint8 aiTrainingPermission, bytes32 predecessor))",
  "function appendRootAuthorization(bytes32 id, address actor, uint64 observedAt, (uint64 revision, bytes32 transitionChain) originalAggregate, bytes32 originalLegacyFamilyHash)",
  "function appendTokenCitation(bytes32 id)",
  "function appendTokenLibrary(bytes32 id)",
  "function appendTokenOutput(bytes32 id, (uint256 tokenId, bytes image, bytes animation) payload)",
  "function appendTokenRenderer(bytes32 id)",
  "function appendTokenScript(bytes32 id)",
  "function appendWork(bytes32, (bytes32 subjectId, bytes32 profileHash, bytes32 predecessor, uint8 form, (string title, (uint8 kind, bytes32 artistId, uint64 bindingGeneration, bytes32 bindingHash, string name) creator, (uint8 kind, uint32 start, uint32 end) creation, string medium, (uint8 kind, bytes32 formatId, string puid, (string name, (bytes32 entryId, uint8 kind, string puid, (string uri, bytes32 digest) specification)[] entries, bytes32 selectedEntryId) catalog) format, (uint8 kind, bool hasPixels, uint256 width, uint256 height, bool hasAspectRatio, (uint256 numerator, uint256 denominator) aspectRatio, bool hasDuration, (uint256 numerator, uint256 denominator) durationSeconds) measurements, (uint8 kind, uint256 number, uint256 total, string statement) edition, string creditLine, bool hasInscription, string inscription, string[] alternateTitles, (uint8 field, uint8 alternateTitleIndex, string language, string value)[] languageVariants, (uint8 role, uint8 authority, string identifier)[] authorityReferences) full, (string reason, uint32 date) absence), address)",
  "function artifactCoverage() view returns (address)",
  "function beginInventory((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope) returns (bytes32 id)",
  "function core() view returns (address)",
  "function dependencies() view returns ((address[12] targets, bytes32[12] codeHashes, address[5] artistTargets, bytes32[5] artistCodeHashes, address artistContentOwner, bytes32 artistContentOwnerCodeHash, uint256 chainId, uint256 readGas, uint256 sourceGas, uint256 selectionGas, uint256 snapshotGas, uint256 referenceGas))",
  "function dependencyHash() view returns (bytes32)",
  "function externalCoverage() view returns (address)",
  "function inventoryEvidence(bytes32 id) view returns (((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, (bytes32 planId, uint256 collectionId, bytes32 scopeSubject, bytes32 artistId, (bytes32 rootRecordHash, bytes32 snapshotRecordHash, bytes32 referenceRenderRecordHash, bytes32 intentRecordHash, bytes32 intentWaiverRecordHash, bytes32 interviewEvidenceHash, bytes32 rightsStatementRecordHash, bytes32 workDescriptionRecordHash) originals, bytes32 sourceContextHash, bytes32 tokenInventoryHash, uint64 tokenCount, uint64 segmentCount, uint64 itemCount, bytes32 segmentChainHash, bytes32 renderCriticalEvidenceHash) inventory) e)",
  "function inventorySegment(bytes32 id, uint64 index) view returns ((bytes32 key, uint64 itemCount, bytes32 firstLink, bytes32 sourceWitnessHash))",
  "function metadataHost() view returns (address)",
  "function metadataRouter() view returns (address)",
  "function plan(bytes32 id) view returns (((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, (uint256 collectionId, bytes32 subject, bytes32 artistId, bytes32 sourceContextHash, uint64 tokenCount, uint64 nextToken, uint64 segmentCount, uint64 itemCount, bytes32 segmentChainHash, uint16 completedStages, bytes32 renderCriticalEvidenceHash) progress, uint64 nativeCursor, uint64 nativeCount, uint64 referenceCursor, uint64 referenceCount))",
  "function referencePublisher() view returns (address)",
  "function requireCurrent((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope) view returns (((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, (bytes32 planId, uint256 collectionId, bytes32 scopeSubject, bytes32 artistId, (bytes32 rootRecordHash, bytes32 snapshotRecordHash, bytes32 referenceRenderRecordHash, bytes32 intentRecordHash, bytes32 intentWaiverRecordHash, bytes32 interviewEvidenceHash, bytes32 rightsStatementRecordHash, bytes32 workDescriptionRecordHash) originals, bytes32 sourceContextHash, bytes32 tokenInventoryHash, uint64 tokenCount, uint64 segmentCount, uint64 itemCount, bytes32 segmentChainHash, bytes32 renderCriticalEvidenceHash) inventory) e)",
  "function requireFullDefinitionBytes(bytes32 id) view",
  "function scopedPolicyInventoryProfile() pure returns (bytes32)",
  "function sealInventory(bytes32 id) returns (((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, (bytes32 planId, uint256 collectionId, bytes32 scopeSubject, bytes32 artistId, (bytes32 rootRecordHash, bytes32 snapshotRecordHash, bytes32 referenceRenderRecordHash, bytes32 intentRecordHash, bytes32 intentWaiverRecordHash, bytes32 interviewEvidenceHash, bytes32 rightsStatementRecordHash, bytes32 workDescriptionRecordHash) originals, bytes32 sourceContextHash, bytes32 tokenInventoryHash, uint64 tokenCount, uint64 segmentCount, uint64 itemCount, bytes32 segmentChainHash, bytes32 renderCriticalEvidenceHash) inventory) evidence)",
  "function snapshots() view returns (address)",
  "function sourceContext(bytes32 id) view returns (((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, bytes32 subject, bytes32 artistId, (bytes32 recordHash, bytes32 scopeSubject, bytes32 predecessor, uint64 revision, bytes32 chainHash, bytes32 manifestHash, uint32 manifestBytes, bytes32 sourceHash, address publisher, uint8 authorizationClass, uint64 grantRevision, uint8 displayAuthorizationClass, uint64 displayGrantRevision, uint64 recordedAt, bytes32 schemaHash, bytes32 profileHash, bytes32 canonicalizationHash) snapshot, ((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, (bytes32 scopeSubject, bytes32 scopeManifestHash, bytes32 sourceRecordHash, uint256 tokenCount, bytes32 tokenListHash, bytes32 membershipHash, uint256 inventoryCount, bytes32 inventoryPrefixHash) membership, (bool locked, address registry, bytes32 registryCodeHash, bytes32 artistId, uint64 bindingGeneration, bytes32 bindingHash, address nominatedArtist, bytes32 identityRecordHash, bytes32 acceptanceRecordHash, uint64 acceptedAt, uint64 lockedAt, bytes32 snapshotHash) artist, ((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, bytes32 membershipHash, bytes32 collectionStateHash, uint64 tokenCount, uint64 nextIndex, bytes32 selectionRoot) selection, (bytes32 selectionId, bytes32 selectionHash, bytes32 inventoryHash, bytes32 policyChainHash, (uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, uint64 tokenCount, uint64 nextIndex, bytes32 leafChainHash, bytes32 contentRoot, bytes32 outputRoot) content, (bytes32 checkpointHash, bytes32 checkpointStateHash, address entropySourceSet, bytes32 inventoryHash, bytes32 policyChainHash, bytes32 artifactHash, bytes32 coverageHash, bytes32 artistId, bytes32 contentRoot, bytes32 outputRoot, bytes32 manifestHash, (uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, uint64 tokenCount, uint64 byteLength) outputs, address sourceFactory, bytes32 sourceFactoryCodeHash, bytes32 factoryDependenciesHash, (bytes32 planId, bytes32 inventoryHash, bytes32 policyChainHash, uint256 policyCount, bool allFrozen, (address coordinator, bytes32 indexedCodeHash, uint256 firstTokenIndex, bool frozen, bytes32 moduleVersion, bytes32 moduleManifestHash, bytes32 moduleSchemaHash, bytes32 deploymentManifestHash, bytes32 policyHash, address provider, uint32 epoch, bytes32 salt, bytes32 componentDataHash, bool explicitPolicy, (bool configured, bool explicitPolicy, bool frozen, uint8 mode, uint8 securityClass, uint8 renderRequirement, uint64 revision, uint32 providerEpoch, bytes32 policyHash, bytes32 contentStateHash, bytes32 lastActionId, bytes32 artistConsentRecord) collectionPolicy)[] policies) entropy) snapshotSource, (bytes32 scopeSubject, (bytes32 recordHash, bytes32 recordChainHash, uint256 collectionId, bytes32 referenceId, bytes32 predecessor, uint64 revision, bytes32 payloadHash, uint32 payloadBytes, bytes32 sourcesHash, bytes32 snapshotRecordHash, uint64 snapshotRevision, address recorder, uint8 authorizationClass, uint64 grantRevision, uint64 effectiveAt, uint64 recordedAt, bytes32 reasonHash, bytes32 schemaHash, bytes32 profileHash, bytes32 canonicalizationHash) observation) referenceRender, (bytes32 scopeSubject, bytes32 workDescriptionRecordHash, bytes32 rightsStatementRecordHash, bytes32 workPayloadHash, bytes32 rightsPayloadHash, bytes32 workSelectionHash, bytes32 rightsSelectionHash, uint64 workRevision, uint64 rightsRevision) descriptions, ((bytes32 recordHash, uint8 kind, bytes32 payloadHash, address recorder, uint64 recordedAt, uint64 recordIndex, bytes32 recordChainHash, bytes32 receiptHash, (bytes32 attestationRecordHash, bytes32 artistId, bytes32 bindingHash, uint64 bindingGeneration, address signer, uint8 authorityClass, uint32 requiredCapability, uint64 signedAt, bytes32 publicationHash) publication, bytes32 publicationEvidenceHash) record, (bytes32 artistId, bytes32 bindingHash, uint64 generation, bytes32 identityRecordHash) association, uint8 origin, uint8 interviewStatus, (bytes32 recordHash, uint8 kind, bytes32 payloadHash, address recorder, uint64 recordedAt, uint64 recordIndex, bytes32 recordChainHash, bytes32 receiptHash, (bytes32 attestationRecordHash, bytes32 artistId, bytes32 bindingHash, uint64 bindingGeneration, address signer, uint8 authorityClass, uint32 requiredCapability, uint64 signedAt, bytes32 publicationHash) publication, bytes32 publicationEvidenceHash) interview, bytes32 interviewArchiveReferenceHash, uint8 interviewPayloadCorrespondence, bytes32 predecessor, address submitter, uint64 revision, uint64 selectedAt, bytes32 catalogsHash, bytes32 selectionHash) conservation, bytes32 interviewEvidenceHash, bytes32 nativeHash, bytes32 rootRecordHash, bytes32 tokenInventoryHash, bytes32 checkpointHash, bytes32 outputManifestRecord, bytes32 selectionId, bytes32 selectionHash, uint64 tokenCount))",
  "function supportsInterface(bytes4 id) pure returns (bool)",
  "function tokenProgress(bytes32 id) view returns ((uint8 phase, uint64 row, uint64 count))",
]);

const coder = AbiCoder.defaultAbiCoder();
const ZERO = ZeroHash as Hex;
const inventoryInterface = new Interface(SCOPED_POLICY_INVENTORY_V2_ABI);

function exact(value: unknown, keys: readonly string[], label: string): asserts value is Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)
    || Reflect.ownKeys(value).length !== keys.length || keys.some(key => !Object.hasOwn(value, key))) {
    throw Error(`${label}: missing or unknown fields`);
  }
}

function uint(value: unknown, bits = 256): bigint {
  if (typeof value !== "bigint" || value < 0n || value >= 1n << BigInt(bits)) throw Error(`Expected uint${bits} bigint`);
  return value;
}

function address(value: unknown, required = false): Address {
  if (typeof value !== "string") throw Error("Expected address");
  const result = getAddress(value) as Address;
  if (required && result === ZeroAddress) throw Error("Expected nonzero address");
  return result;
}

function bytes(value: unknown, fixed?: number): Hex {
  if (typeof value !== "string" || !isHexString(value, fixed ?? true)
    || (value.length - 2) / 2 > SCOPED_POLICY_INVENTORY_V2_MAX_BYTES) throw Error("Malformed or oversized bytes");
  return value.toLowerCase() as Hex;
}

function nonzero(value: unknown): Hex {
  const result = bytes(value, 32);
  if (result === ZERO) throw Error("Expected nonzero commitment");
  return result;
}

function list(value: unknown, fixed?: number): readonly unknown[] {
  if (!Array.isArray(value) || value.length > SCOPED_POLICY_INVENTORY_V2_MAX_ROWS
    || (fixed !== undefined && value.length !== fixed)
    || Reflect.ownKeys(value).length !== value.length + 1
    || Array.from({ length: value.length }, (_, i) => i).some(i => !Object.hasOwn(value, i))) {
    throw Error("Expected dense bounded array");
  }
  return value;
}

function valueOf(type: ParamType, value: unknown, decoded = false, enumMaximum?: number): unknown {
  if (type.baseType === "tuple") {
    if (!decoded) exact(value, type.components!.map(field => field.name), "Tuple");
    const enums = enumFields[ParamType.from({
      type: "tuple", components: type.components!.map(field => JSON.parse(field.format("json"))),
    }).format("full")];
    return Object.freeze(Object.fromEntries(type.components!.map((field, i) => [field.name,
      valueOf(field, decoded ? (value as readonly unknown[])[i] : (value as Record<string, unknown>)[field.name],
        decoded, enums?.[field.name])])));
  }
  if (type.baseType === "array") {
    const rows = list(decoded ? Array.from(value as readonly unknown[]) : value,
      type.arrayLength! < 0 ? undefined : type.arrayLength!);
    return Object.freeze(rows.map(row => valueOf(type.arrayChildren!, row, decoded, enumMaximum)));
  }
  if (type.type.startsWith("uint")) {
    const result = uint(value, Number(type.type.slice(4)));
    if (enumMaximum !== undefined && result > BigInt(enumMaximum)) throw Error("Unknown original enum value");
    return result;
  }
  if (type.type === "address") return address(value);
  if (type.type.startsWith("bytes")) return bytes(value, type.type === "bytes" ? undefined : Number(type.type.slice(5)));
  if (type.type === "string") {
    if (typeof value !== "string" || /[\uD800-\uDBFF](?![\uDC00-\uDFFF])|(?<![\uD800-\uDBFF])[\uDC00-\uDFFF]/u.test(value)
      || toUtf8Bytes(value).length > SCOPED_POLICY_INVENTORY_V2_MAX_BYTES) throw Error("Invalid UTF8 text or bound");
    return value;
  }
  if (type.type === "bool" && typeof value === "boolean") return value;
  throw Error(`Invalid ABI value ${type.type}`);
}

function normalized<T>(tuple: string, value: unknown): T {
  return valueOf(ParamType.from(tuple), value) as T;
}

function encode(tuple: string, value: unknown): Hex {
  return bytes(coder.encode([tuple], [normalized(tuple, value)]));
}

function decode<T>(tuple: string, value: Hex): T {
  const raw = bytes(value);
  const result = valueOf(ParamType.from(tuple), coder.decode([tuple], raw)[0], true) as T;
  if (encode(tuple, result) !== raw) throw Error("Noncanonical ABI encoding");
  return result;
}

function hash(types: readonly string[], values: readonly unknown[]): Hex {
  return keccak256(coder.encode(types, values)) as Hex;
}

function stable(value: unknown): string {
  return JSON.stringify(value, (_, v: unknown) => typeof v === "bigint" ? { uint: v.toString() }
    : v && typeof v === "object" && !Array.isArray(v)
      ? Object.fromEntries(Object.entries(v).sort(([a], [b]) => a.localeCompare(b))) : v);
}

export function scopedPolicyInventoryV2Interface(): Interface {
  return new Interface(SCOPED_POLICY_INVENTORY_V2_ABI);
}

export function normalizeScopedPolicyInventoryV2Coordinates(value: ScopedPolicyInventoryV2Coordinates): ScopedPolicyInventoryV2Coordinates {
  exact(value, ["chainId", "core", "inventory"], "Inventory coordinates");
  return Object.freeze({ chainId: uint(value.chainId), core: address(value.core, true), inventory: address(value.inventory, true) });
}

export const validateScopedPolicyInventoryV2Scope = graph.validateScopedPolicyGraphV2Scope;

export function scopedPolicyInventoryV2DependencyHash(value: ScopedPolicyInventoryV2Dependencies): Hex {
  return keccak256(encodeScopedPolicyInventoryV2Dependencies(value)) as Hex;
}

export function validateScopedPolicyInventoryV2Dependencies(
  coordinates: ScopedPolicyInventoryV2Coordinates,
  value: ScopedPolicyInventoryV2Dependencies,
): ScopedPolicyInventoryV2Dependencies {
  const c = normalizeScopedPolicyInventoryV2Coordinates(coordinates);
  const d = normalizeScopedPolicyInventoryV2Dependencies(value);
  if (d.chainId !== c.chainId || d.targets[0] !== c.core || d.readGas < 50000n
    || [d.sourceGas, d.selectionGas, d.snapshotGas, d.referenceGas].some(gas => gas < d.readGas)) {
    throw Error("Inventory dependency coordinates or gas floors differ");
  }
  [...d.targets, ...d.artistTargets, d.artistContentOwner].forEach(value => address(value, true));
  [...d.codeHashes, ...d.artistCodeHashes, d.artistContentOwnerCodeHash].forEach(nonzero);
  return d;
}

/** Supplied immutable associations only. Original current() and source producers remain authoritative. */
export function validateScopedPolicyInventoryV2Context(
  coordinates: ScopedPolicyInventoryV2Coordinates,
  value: ScopedPolicyInventoryV2Context,
): ScopedPolicyInventoryV2Context {
  const c = normalizeScopedPolicyInventoryV2Coordinates(coordinates);
  const x = normalizeScopedPolicyInventoryV2Context(value);
  const scope = validateScopedPolicyInventoryV2Scope(x.scope);
  const subject = graph.scopedPolicyGraphV2ScopeSubject(c.chainId, c.core, scope);
  const source = x.snapshotSource;
  const sameScope = (value: ScopedPolicyInventoryV2Scope) => encode(SCOPED_POLICY_INVENTORY_V2_SCOPE_TUPLE, value)
    === encode(SCOPED_POLICY_INVENTORY_V2_SCOPE_TUPLE, scope);
  if ([x.subject, x.snapshot.scopeSubject, x.referenceRender.scopeSubject,
    source.membership.scopeSubject, x.descriptions.scopeSubject].some(value => value !== subject)
    || [source.scope, source.selection.scope, source.content.scope, source.outputs.scope].some(value => !sameScope(value))
    || x.referenceRender.observation.collectionId !== scope.collectionId
    || x.snapshot.recordHash !== x.referenceRender.observation.snapshotRecordHash
    || x.snapshot.revision !== x.referenceRender.observation.snapshotRevision
    || x.artistId !== source.artist.artistId || x.artistId !== x.conservation.association.artistId
    || source.artist.bindingGeneration !== x.conservation.association.generation
    || source.artist.bindingHash !== x.conservation.association.bindingHash
    || source.artist.identityRecordHash !== x.conservation.association.identityRecordHash
    || x.nativeHash !== keccak256(snapshot.encodeScopedPolicyPublicationV2Source(source))
    || x.tokenInventoryHash !== source.membership.membershipHash
    || x.checkpointHash !== source.outputs.checkpointHash
    || x.selectionId !== source.content.selectionId || x.selectionHash !== source.content.selectionHash
    || x.tokenCount === 0n
    || [source.membership.tokenCount, source.content.tokenCount, source.selection.tokenCount, source.outputs.tokenCount]
      .some(value => value !== x.tokenCount)) throw Error("Inventory context associations differ");
  [x.artistId, x.rootRecordHash, x.snapshot.recordHash, x.referenceRender.observation.recordHash,
    x.outputManifestRecord, x.tokenInventoryHash, x.checkpointHash, x.selectionId, x.selectionHash].forEach(nonzero);
  return x;
}

export function scopedPolicyInventoryV2ContextHash(value: ScopedPolicyInventoryV2Context): Hex {
  return keccak256(encodeScopedPolicyInventoryV2Context(value)) as Hex;
}

export function scopedPolicyInventoryV2PlanId(
  coordinates: ScopedPolicyInventoryV2Coordinates,
  dependencyHash: Hex,
  context: ScopedPolicyInventoryV2Context,
): Hex {
  const c = normalizeScopedPolicyInventoryV2Coordinates(coordinates);
  return hash(["bytes32", "uint256", "address", "bytes32", SCOPED_POLICY_INVENTORY_V2_CONTEXT_TUPLE],
    [id("6529STREAM_SCOPED_POLICY_RENDER_CRITICAL_PLAN_V2"), c.chainId, c.inventory,
      bytes(dependencyHash, 32), normalizeScopedPolicyInventoryV2Context(context)]);
}

export function scopedPolicyInventoryV2ItemHash(item: ScopedPolicyInventoryV2Item): Hex {
  return hash(["bytes32", SCOPED_POLICY_INVENTORY_V2_ITEM_TUPLE],
    [id("6529STREAM_PRESERVATION_ITEM_V1"), normalizeScopedPolicyInventoryV2Item(item)]);
}

export function scopedPolicyInventoryV2Link(
  key: Hex, count: bigint, index: bigint, item: ScopedPolicyInventoryV2Item, next: Hex,
): Hex {
  const k = nonzero(key), n = uint(count, 64), at = uint(index, 64), tail = bytes(next, 32);
  if (n === 0n || at >= n || (at + 1n === n) !== (tail === ZERO)) throw Error("Invalid finite inventory link");
  return hash(["bytes32", "bytes32", "uint64", "uint64", "bytes32", "bytes32"],
    [id("6529STREAM_PRESERVATION_ITEM_LINK_V1"), k, n, at, scopedPolicyInventoryV2ItemHash(item), tail]);
}

export function scopedPolicyInventoryV2SegmentKey(planId: Hex, index: bigint): Hex {
  return hash(["bytes32", "bytes32", "uint64"],
    [id("6529STREAM_SCOPED_POLICY_RENDER_CRITICAL_SEGMENT_V2"), bytes(planId, 32), uint(index, 64)]);
}

export function scopedPolicyInventoryV2Segment(
  key: Hex, witnessHash: Hex, items: readonly ScopedPolicyInventoryV2Item[],
): ScopedPolicyInventoryV2Segment {
  const k = nonzero(key), witness = nonzero(witnessHash);
  const rows = list(items).map(value => normalizeScopedPolicyInventoryV2Item(value as ScopedPolicyInventoryV2Item));
  const count = BigInt(rows.length);
  let next = ZERO;
  for (let i = rows.length - 1; i >= 0; --i) next = scopedPolicyInventoryV2Link(k, count, BigInt(i), rows[i]!, next);
  return Object.freeze({ key: k, itemCount: count, firstLink: next, sourceWitnessHash: witness });
}

export function validateScopedPolicyInventoryV2Segment(value: ScopedPolicyInventoryV2Segment): ScopedPolicyInventoryV2Segment {
  const s = normalizeScopedPolicyInventoryV2Segment(value);
  nonzero(s.key); nonzero(s.sourceWitnessHash);
  if ((s.itemCount === 0n) !== (s.firstLink === ZERO)) throw Error("Invalid segment terminator");
  return s;
}

export function scopedPolicyInventoryV2AppendSegment(
  previous: Hex, index: bigint, segment: ScopedPolicyInventoryV2Segment,
): Hex {
  return hash(["bytes32", "bytes32", "uint64", SCOPED_POLICY_INVENTORY_V2_SEGMENT_TUPLE],
    [id("6529STREAM_PRESERVATION_SEGMENT_V1"), bytes(previous, 32), uint(index, 64), validateScopedPolicyInventoryV2Segment(segment)]);
}

export function scopedPolicyInventoryV2EvidenceHash(
  coordinates: ScopedPolicyInventoryV2Coordinates,
  dependencyHash: Hex,
  evidence: ScopedPolicyInventoryV2Evidence,
): Hex {
  const c = normalizeScopedPolicyInventoryV2Coordinates(coordinates);
  const e = normalizeScopedPolicyInventoryV2Evidence(evidence);
  return hash(["bytes32", "uint256", "address", "bytes32", SCOPED_POLICY_INVENTORY_V2_EVIDENCE_TUPLE],
    [id("6529STREAM_SCOPED_POLICY_RENDER_CRITICAL_EVIDENCE_V2"), c.chainId, c.inventory,
      bytes(dependencyHash, 32), { ...e, inventory: { ...e.inventory, renderCriticalEvidenceHash: ZERO } }]);
}

export function validateScopedPolicyInventoryV2Evidence(
  coordinates: ScopedPolicyInventoryV2Coordinates,
  dependencyHash: Hex,
  evidence: ScopedPolicyInventoryV2Evidence,
): ScopedPolicyInventoryV2Evidence {
  const c = normalizeScopedPolicyInventoryV2Coordinates(coordinates);
  const e = normalizeScopedPolicyInventoryV2Evidence(evidence);
  const scope = validateScopedPolicyInventoryV2Scope(e.scope);
  const p = e.inventory;
  [dependencyHash, p.planId, p.artistId, p.scopeSubject, p.sourceContextHash, p.tokenInventoryHash, p.segmentChainHash].forEach(nonzero);
  if (p.collectionId !== scope.collectionId
    || p.scopeSubject !== graph.scopedPolicyGraphV2ScopeSubject(c.chainId, c.core, scope)
    || p.tokenCount === 0n || p.segmentCount === 0n || p.itemCount === 0n
    || p.renderCriticalEvidenceHash !== scopedPolicyInventoryV2EvidenceHash(c, dependencyHash, e)) {
    throw Error("Inventory evidence associations or commitment differ");
  }
  return e;
}

export function scopedPolicyInventoryV2TokenWitness(
  checkpointHash: Hex, selectionHash: Hex, ordinal: bigint, phase: bigint, row: bigint, count: bigint,
): Hex {
  return hash(["bytes32", "bytes32", "bytes32", "uint64", "uint8", "uint64", "uint64"],
    [id("6529STREAM_SCOPED_POLICY_TOKEN_INVENTORY_SOURCE_V2"), bytes(checkpointHash, 32), bytes(selectionHash, 32),
      uint(ordinal, 64), uint(phase, 8), uint(row, 64), uint(count, 64)]);
}

export function scopedPolicyInventoryV2CursorWitness(contextHash: Hex, cursor: bigint, count: bigint): Hex {
  return hash(["bytes32", "uint64", "uint64"], [bytes(contextHash, 32), uint(cursor, 64), uint(count, 64)]);
}

export function normalizeScopedPolicyInventoryV2Dependencies(value: ScopedPolicyInventoryV2Dependencies): ScopedPolicyInventoryV2Dependencies {
  return normalized(SCOPED_POLICY_INVENTORY_V2_DEPENDENCIES_TUPLE, value);
}
export function encodeScopedPolicyInventoryV2Dependencies(value: ScopedPolicyInventoryV2Dependencies): Hex {
  return encode(SCOPED_POLICY_INVENTORY_V2_DEPENDENCIES_TUPLE, value);
}
export function decodeScopedPolicyInventoryV2Dependencies(value: Hex): ScopedPolicyInventoryV2Dependencies {
  return decode(SCOPED_POLICY_INVENTORY_V2_DEPENDENCIES_TUPLE, value);
}

export function normalizeScopedPolicyInventoryV2Item(value: ScopedPolicyInventoryV2Item): ScopedPolicyInventoryV2Item {
  return normalized(SCOPED_POLICY_INVENTORY_V2_ITEM_TUPLE, value);
}
export function encodeScopedPolicyInventoryV2Item(value: ScopedPolicyInventoryV2Item): Hex {
  return encode(SCOPED_POLICY_INVENTORY_V2_ITEM_TUPLE, value);
}
export function decodeScopedPolicyInventoryV2Item(value: Hex): ScopedPolicyInventoryV2Item {
  return decode(SCOPED_POLICY_INVENTORY_V2_ITEM_TUPLE, value);
}

export function normalizeScopedPolicyInventoryV2Segment(value: ScopedPolicyInventoryV2Segment): ScopedPolicyInventoryV2Segment {
  return normalized(SCOPED_POLICY_INVENTORY_V2_SEGMENT_TUPLE, value);
}
export function encodeScopedPolicyInventoryV2Segment(value: ScopedPolicyInventoryV2Segment): Hex {
  return encode(SCOPED_POLICY_INVENTORY_V2_SEGMENT_TUPLE, value);
}
export function decodeScopedPolicyInventoryV2Segment(value: Hex): ScopedPolicyInventoryV2Segment {
  return decode(SCOPED_POLICY_INVENTORY_V2_SEGMENT_TUPLE, value);
}

export function normalizeScopedPolicyInventoryV2Progress(value: ScopedPolicyInventoryV2Progress): ScopedPolicyInventoryV2Progress {
  return normalized(SCOPED_POLICY_INVENTORY_V2_PROGRESS_TUPLE, value);
}
export function encodeScopedPolicyInventoryV2Progress(value: ScopedPolicyInventoryV2Progress): Hex {
  return encode(SCOPED_POLICY_INVENTORY_V2_PROGRESS_TUPLE, value);
}
export function decodeScopedPolicyInventoryV2Progress(value: Hex): ScopedPolicyInventoryV2Progress {
  return decode(SCOPED_POLICY_INVENTORY_V2_PROGRESS_TUPLE, value);
}

export function normalizeScopedPolicyInventoryV2Plan(value: ScopedPolicyInventoryV2Plan): ScopedPolicyInventoryV2Plan {
  return normalized(SCOPED_POLICY_INVENTORY_V2_PLAN_TUPLE, value);
}
export function encodeScopedPolicyInventoryV2Plan(value: ScopedPolicyInventoryV2Plan): Hex {
  return encode(SCOPED_POLICY_INVENTORY_V2_PLAN_TUPLE, value);
}
export function decodeScopedPolicyInventoryV2Plan(value: Hex): ScopedPolicyInventoryV2Plan {
  return decode(SCOPED_POLICY_INVENTORY_V2_PLAN_TUPLE, value);
}

export function normalizeScopedPolicyInventoryV2TokenProgress(value: ScopedPolicyInventoryV2TokenProgress): ScopedPolicyInventoryV2TokenProgress {
  return normalized(SCOPED_POLICY_INVENTORY_V2_TOKEN_PROGRESS_TUPLE, value);
}
export function encodeScopedPolicyInventoryV2TokenProgress(value: ScopedPolicyInventoryV2TokenProgress): Hex {
  return encode(SCOPED_POLICY_INVENTORY_V2_TOKEN_PROGRESS_TUPLE, value);
}
export function decodeScopedPolicyInventoryV2TokenProgress(value: Hex): ScopedPolicyInventoryV2TokenProgress {
  return decode(SCOPED_POLICY_INVENTORY_V2_TOKEN_PROGRESS_TUPLE, value);
}

export function normalizeScopedPolicyInventoryV2OriginalInputs(value: ScopedPolicyInventoryV2OriginalInputs): ScopedPolicyInventoryV2OriginalInputs {
  return normalized(SCOPED_POLICY_INVENTORY_V2_ORIGINAL_INPUTS_TUPLE, value);
}
export function encodeScopedPolicyInventoryV2OriginalInputs(value: ScopedPolicyInventoryV2OriginalInputs): Hex {
  return encode(SCOPED_POLICY_INVENTORY_V2_ORIGINAL_INPUTS_TUPLE, value);
}
export function decodeScopedPolicyInventoryV2OriginalInputs(value: Hex): ScopedPolicyInventoryV2OriginalInputs {
  return decode(SCOPED_POLICY_INVENTORY_V2_ORIGINAL_INPUTS_TUPLE, value);
}

export function normalizeScopedPolicyInventoryV2OriginalEvidence(value: ScopedPolicyInventoryV2OriginalEvidence): ScopedPolicyInventoryV2OriginalEvidence {
  return normalized(SCOPED_POLICY_INVENTORY_V2_ORIGINAL_EVIDENCE_TUPLE, value);
}
export function encodeScopedPolicyInventoryV2OriginalEvidence(value: ScopedPolicyInventoryV2OriginalEvidence): Hex {
  return encode(SCOPED_POLICY_INVENTORY_V2_ORIGINAL_EVIDENCE_TUPLE, value);
}
export function decodeScopedPolicyInventoryV2OriginalEvidence(value: Hex): ScopedPolicyInventoryV2OriginalEvidence {
  return decode(SCOPED_POLICY_INVENTORY_V2_ORIGINAL_EVIDENCE_TUPLE, value);
}

export function normalizeScopedPolicyInventoryV2Evidence(value: ScopedPolicyInventoryV2Evidence): ScopedPolicyInventoryV2Evidence {
  return normalized(SCOPED_POLICY_INVENTORY_V2_EVIDENCE_TUPLE, value);
}
export function encodeScopedPolicyInventoryV2Evidence(value: ScopedPolicyInventoryV2Evidence): Hex {
  return encode(SCOPED_POLICY_INVENTORY_V2_EVIDENCE_TUPLE, value);
}
export function decodeScopedPolicyInventoryV2Evidence(value: Hex): ScopedPolicyInventoryV2Evidence {
  return decode(SCOPED_POLICY_INVENTORY_V2_EVIDENCE_TUPLE, value);
}

export function normalizeScopedPolicyInventoryV2Context(value: ScopedPolicyInventoryV2Context): ScopedPolicyInventoryV2Context {
  return normalized(SCOPED_POLICY_INVENTORY_V2_CONTEXT_TUPLE, value);
}
export function encodeScopedPolicyInventoryV2Context(value: ScopedPolicyInventoryV2Context): Hex {
  return encode(SCOPED_POLICY_INVENTORY_V2_CONTEXT_TUPLE, value);
}
export function decodeScopedPolicyInventoryV2Context(value: Hex): ScopedPolicyInventoryV2Context {
  return decode(SCOPED_POLICY_INVENTORY_V2_CONTEXT_TUPLE, value);
}

export function normalizeScopedPolicyInventoryV2Work(value: ScopedPolicyInventoryV2Work): ScopedPolicyInventoryV2Work {
  return normalized(SCOPED_POLICY_INVENTORY_V2_WORK_TUPLE, value);
}
export function encodeScopedPolicyInventoryV2Work(value: ScopedPolicyInventoryV2Work): Hex {
  return encode(SCOPED_POLICY_INVENTORY_V2_WORK_TUPLE, value);
}
export function decodeScopedPolicyInventoryV2Work(value: Hex): ScopedPolicyInventoryV2Work {
  return decode(SCOPED_POLICY_INVENTORY_V2_WORK_TUPLE, value);
}

export function normalizeScopedPolicyInventoryV2Rights(value: ScopedPolicyInventoryV2Rights): ScopedPolicyInventoryV2Rights {
  return normalized(SCOPED_POLICY_INVENTORY_V2_RIGHTS_TUPLE, value);
}
export function encodeScopedPolicyInventoryV2Rights(value: ScopedPolicyInventoryV2Rights): Hex {
  return encode(SCOPED_POLICY_INVENTORY_V2_RIGHTS_TUPLE, value);
}
export function decodeScopedPolicyInventoryV2Rights(value: Hex): ScopedPolicyInventoryV2Rights {
  return decode(SCOPED_POLICY_INVENTORY_V2_RIGHTS_TUPLE, value);
}

export function normalizeScopedPolicyInventoryV2Intent(value: ScopedPolicyInventoryV2Intent): ScopedPolicyInventoryV2Intent {
  return normalized(SCOPED_POLICY_INVENTORY_V2_INTENT_TUPLE, value);
}
export function encodeScopedPolicyInventoryV2Intent(value: ScopedPolicyInventoryV2Intent): Hex {
  return encode(SCOPED_POLICY_INVENTORY_V2_INTENT_TUPLE, value);
}
export function decodeScopedPolicyInventoryV2Intent(value: Hex): ScopedPolicyInventoryV2Intent {
  return decode(SCOPED_POLICY_INVENTORY_V2_INTENT_TUPLE, value);
}

export function normalizeScopedPolicyInventoryV2IntentWaiver(value: ScopedPolicyInventoryV2IntentWaiver): ScopedPolicyInventoryV2IntentWaiver {
  return normalized(SCOPED_POLICY_INVENTORY_V2_INTENT_WAIVER_TUPLE, value);
}
export function encodeScopedPolicyInventoryV2IntentWaiver(value: ScopedPolicyInventoryV2IntentWaiver): Hex {
  return encode(SCOPED_POLICY_INVENTORY_V2_INTENT_WAIVER_TUPLE, value);
}
export function decodeScopedPolicyInventoryV2IntentWaiver(value: Hex): ScopedPolicyInventoryV2IntentWaiver {
  return decode(SCOPED_POLICY_INVENTORY_V2_INTENT_WAIVER_TUPLE, value);
}

export function normalizeScopedPolicyInventoryV2Interview(value: ScopedPolicyInventoryV2Interview): ScopedPolicyInventoryV2Interview {
  return normalized(SCOPED_POLICY_INVENTORY_V2_INTERVIEW_TUPLE, value);
}
export function encodeScopedPolicyInventoryV2Interview(value: ScopedPolicyInventoryV2Interview): Hex {
  return encode(SCOPED_POLICY_INVENTORY_V2_INTERVIEW_TUPLE, value);
}
export function decodeScopedPolicyInventoryV2Interview(value: Hex): ScopedPolicyInventoryV2Interview {
  return decode(SCOPED_POLICY_INVENTORY_V2_INTERVIEW_TUPLE, value);
}

export function normalizeScopedPolicyInventoryV2Payload(value: ScopedPolicyInventoryV2Payload): ScopedPolicyInventoryV2Payload {
  return normalized(SCOPED_POLICY_INVENTORY_V2_PAYLOAD_TUPLE, value);
}
export function encodeScopedPolicyInventoryV2Payload(value: ScopedPolicyInventoryV2Payload): Hex {
  return encode(SCOPED_POLICY_INVENTORY_V2_PAYLOAD_TUPLE, value);
}
export function decodeScopedPolicyInventoryV2Payload(value: Hex): ScopedPolicyInventoryV2Payload {
  return decode(SCOPED_POLICY_INVENTORY_V2_PAYLOAD_TUPLE, value);
}

export function normalizeScopedPolicyInventoryV2DocumentFacts(value: ScopedPolicyInventoryV2DocumentFacts): ScopedPolicyInventoryV2DocumentFacts {
  return normalized(SCOPED_POLICY_INVENTORY_V2_DOCUMENT_FACTS_TUPLE, value);
}
export function encodeScopedPolicyInventoryV2DocumentFacts(value: ScopedPolicyInventoryV2DocumentFacts): Hex {
  return encode(SCOPED_POLICY_INVENTORY_V2_DOCUMENT_FACTS_TUPLE, value);
}
export function decodeScopedPolicyInventoryV2DocumentFacts(value: Hex): ScopedPolicyInventoryV2DocumentFacts {
  return decode(SCOPED_POLICY_INVENTORY_V2_DOCUMENT_FACTS_TUPLE, value);
}

export interface ScopedPolicyInventoryV2Definition {
  readonly index: bigint;
  readonly name: string;
  readonly id: Hex;
  readonly contentHash: Hex;
  readonly byteLength: bigint;
  readonly sourcePath: string;
  readonly documentPath: string | null;
  readonly literal: Hex | null;
}

/** Exact ordered native definitions. Document bytes are never reformatted or newline-normalized. */
export const SCOPED_POLICY_INVENTORY_V2_DEFINITIONS: readonly ScopedPolicyInventoryV2Definition[] = Object.freeze([
  Object.freeze({
    index: 0n, name: "STREAM_WORK_DESCRIPTION_V1",
    id: "0x5bb3543c4c007f4396474b74ec81dd8bca13028b6d945020e4b48ff236b26a3c" as Hex,
    contentHash: "0xc534a4212c652d620942266ff32d8699bcc40492aa9a323e0f5b711bbc5bba88" as Hex, byteLength: 11481n,
    sourcePath: "smart-contracts/domains/records/StreamWorkRecordDefinitions.sol",
    documentPath: "schemas/records/STREAM_WORK_DESCRIPTION_V1.json",
    literal: null,
  }),
  Object.freeze({
    index: 1n, name: "STREAM_WORK_DESCRIPTION_JSON_PROFILE_V1",
    id: "0x5cbe99f46b06fb16351501c9c1c69f98912cf8534a5ee647d0312ef1de7ebaa0" as Hex,
    contentHash: "0x1c5e8281a5c12e06b334020bc158dc101dd33baaa449feeb8f504e20bd910353" as Hex, byteLength: 2350n,
    sourcePath: "smart-contracts/domains/records/StreamWorkRecordDefinitions.sol",
    documentPath: "schemas/records/STREAM_WORK_DESCRIPTION_JSON_PROFILE_V1.json",
    literal: null,
  }),
  Object.freeze({
    index: 2n, name: "STREAM_WORK_FORMAT_CATALOG_V1",
    id: "0x613d837a313512b0f404a66b152b282d5f309c97bf3d6c4dc98aff573a3fa4cc" as Hex,
    contentHash: "0xa2c03300254919dad0436cffd743bc869665f06434123b92ae48c5ff98a284ed" as Hex, byteLength: 1720n,
    sourcePath: "smart-contracts/domains/records/StreamWorkRecordDefinitions.sol",
    documentPath: "schemas/records/STREAM_WORK_FORMAT_CATALOG_V1.json",
    literal: null,
  }),
  Object.freeze({
    index: 3n, name: "STREAM_WORK_FORMAT_CATALOG_JSON_PROFILE_V1",
    id: "0x32861d4583bc08f7afbeb7e4e376e3d22dcfc5ebf25ac0e7c8c045c2cfacbbb9" as Hex,
    contentHash: "0x03799bc44aab386d3032a5859e6e7b7f6558bdb279f0e9906d3af535274a6514" as Hex, byteLength: 957n,
    sourcePath: "smart-contracts/domains/records/StreamWorkRecordDefinitions.sol",
    documentPath: "schemas/records/STREAM_WORK_FORMAT_CATALOG_JSON_PROFILE_V1.json",
    literal: null,
  }),
  Object.freeze({
    index: 4n, name: "STREAM_RIGHTS_V1",
    id: "0xdfdea1c86219c12e182b4023d399be35bd5602461ef1dc727784c18d7742b967" as Hex,
    contentHash: "0xccb6e9813b29689628095bd2eaaf2b62bdbdfd7e971d14784a9dc419688a33e8" as Hex, byteLength: 14613n,
    sourcePath: "smart-contracts/domains/records/StreamRightsRecordDefinitions.sol",
    documentPath: "schemas/records/STREAM_RIGHTS_V1.json",
    literal: null,
  }),
  Object.freeze({
    index: 5n, name: "STREAM_RIGHTS_JSON_PROFILE_V1",
    id: "0x2d4a7482b51b8267e36531e068971cd09ccdcb230d5945f2899812bc57183120" as Hex,
    contentHash: "0x15df3f552f58b0a0e8ba75bc4679d6ef3c3c1034fd065646a518bb63edb27174" as Hex, byteLength: 1335n,
    sourcePath: "smart-contracts/domains/records/StreamRightsRecordDefinitions.sol",
    documentPath: "schemas/records/STREAM_RIGHTS_JSON_PROFILE_V1.json",
    literal: null,
  }),
  Object.freeze({
    index: 6n, name: "STREAM_ARTIST_INTENT_V1",
    id: "0x2f2a18b3a8b160296c5ef1b1b3385dcaa88d07c066a663d8561771400e666802" as Hex,
    contentHash: "0x733ff58eb9521aedd7d74c0b53620306095720e5688cbe5b7d94228665f9a009" as Hex, byteLength: 10223n,
    sourcePath: "smart-contracts/domains/records/StreamConservationDefinitions.sol",
    documentPath: "schemas/records/STREAM_ARTIST_INTENT_V1.json",
    literal: null,
  }),
  Object.freeze({
    index: 7n, name: "STREAM_ARTIST_INTENT_JSON_PROFILE_V1",
    id: "0xc1faa012c451d83b645154b1d5c6bedd3123e2f2fe8c49807501f32f1747e458" as Hex,
    contentHash: "0x1522f0f9498ac4a0f652ff201b0681a3711234a15189713cf5e71f71ba53c9c6" as Hex, byteLength: 3814n,
    sourcePath: "smart-contracts/domains/records/StreamConservationDefinitions.sol",
    documentPath: "schemas/records/STREAM_ARTIST_INTENT_JSON_PROFILE_V1.json",
    literal: null,
  }),
  Object.freeze({
    index: 8n, name: "STREAM_ARTIST_INTENT_WAIVER_V1",
    id: "0x9e029e12429716112002c57124a77e9da820c0baaef00eb3ca5298afb24c0130" as Hex,
    contentHash: "0xbd017f973eb0c21bc4c1e57bebafd7e48774e8dc91b2424a14597b96a5edfc93" as Hex, byteLength: 4927n,
    sourcePath: "smart-contracts/domains/records/StreamConservationDefinitions.sol",
    documentPath: "schemas/records/STREAM_ARTIST_INTENT_WAIVER_V1.json",
    literal: null,
  }),
  Object.freeze({
    index: 9n, name: "STREAM_ARTIST_INTENT_WAIVER_JSON_PROFILE_V1",
    id: "0x3f91b8592bb904265b23cb522d0f799dc098cfd0eef0fdee7cdaa4ae977ce388" as Hex,
    contentHash: "0xdce44685b162b745cde2e4611d571612c3dc40ab890bedc73436bcd2408f41e1" as Hex, byteLength: 3828n,
    sourcePath: "smart-contracts/domains/records/StreamConservationDefinitions.sol",
    documentPath: "schemas/records/STREAM_ARTIST_INTENT_WAIVER_JSON_PROFILE_V1.json",
    literal: null,
  }),
  Object.freeze({
    index: 10n, name: "STREAM_ARTIST_INTERVIEW_V1",
    id: "0x12d539ad0aa5da43e241ab876b93cd215e2f2fa9be43f4c6ad3e49a109a45273" as Hex,
    contentHash: "0x826e7082f5ddcdb972c22411bca7adfd71b7feac7980eaabeb5dc5ec79eb3963" as Hex, byteLength: 11052n,
    sourcePath: "smart-contracts/domains/records/StreamConservationDefinitions.sol",
    documentPath: "schemas/records/STREAM_ARTIST_INTERVIEW_V1.json",
    literal: null,
  }),
  Object.freeze({
    index: 11n, name: "STREAM_ARTIST_INTERVIEW_JSON_PROFILE_V1",
    id: "0xe3bda9449d86cbbc77bcd7db0558cfc5e1b0d89c2d922af24b196649df20c7ac" as Hex,
    contentHash: "0x1533a5140b53a7b0bc3f76524cb01d44c62391c8db570cbdff11fbc9dea6e9cf" as Hex, byteLength: 3820n,
    sourcePath: "smart-contracts/domains/records/StreamConservationDefinitions.sol",
    documentPath: "schemas/records/STREAM_ARTIST_INTERVIEW_JSON_PROFILE_V1.json",
    literal: null,
  }),
  Object.freeze({
    index: 12n, name: "STREAM_CONSERVATION_FORMAT_CATALOG_V1",
    id: "0xdf4e0a436dfb61d24da9e0af8fd645c99bc907d3ea94e3e34df97db4dd61a177" as Hex,
    contentHash: "0xb751512d8420de5e72907298460560aa25e274617b9ff25607bf80f1ffa982df" as Hex, byteLength: 2059n,
    sourcePath: "smart-contracts/domains/records/StreamConservationDefinitions.sol",
    documentPath: "schemas/records/STREAM_CONSERVATION_FORMAT_CATALOG_V1.json",
    literal: null,
  }),
  Object.freeze({
    index: 13n, name: "STREAM_CONSERVATION_FORMAT_CATALOG_JSON_PROFILE_V1",
    id: "0xf69254cd34854f7c450782b73e5736d7bf0f53418bb7e5e9452ce2267e36c2e6" as Hex,
    contentHash: "0x5e3712a9d1b640532be098b10855d013323bd7a852cf3b548dfff9babbdb7b3c" as Hex, byteLength: 3842n,
    sourcePath: "smart-contracts/domains/records/StreamConservationDefinitions.sol",
    documentPath: "schemas/records/STREAM_CONSERVATION_FORMAT_CATALOG_JSON_PROFILE_V1.json",
    literal: null,
  }),
  Object.freeze({
    index: 14n, name: "STREAM_REFERENCE_NATIVE_ENVIRONMENT_V1",
    id: "0xd11f79240dccf3372049d888c61682678bf90a81444b0d3a44e4ba130026de5f" as Hex,
    contentHash: "0xe09ea65b22dccf9a9528b0ec4c940a831be48a060f0a095157a65aff5b290b90" as Hex, byteLength: 2236n,
    sourcePath: "smart-contracts/domains/records/StreamReferenceRenderDefinitions.sol",
    documentPath: "schemas/records/STREAM_REFERENCE_NATIVE_ENVIRONMENT_V1.json",
    literal: null,
  }),
  Object.freeze({
    index: 15n, name: "STREAM_REFERENCE_PNG_OBJECT_V1",
    id: "0x2669cdd31c4be774315ad6502522200c9fdd24db4934ea7ec77e081547b10db9" as Hex,
    contentHash: "0x06dacccbad9218d04f77cbfdd597dfa61e2cab5b58c0fb8f5a1344ce301cb489" as Hex, byteLength: 286n,
    sourcePath: "smart-contracts/domains/records/StreamReferenceRenderDefinitions.sol",
    documentPath: "schemas/records/STREAM_REFERENCE_PNG_OBJECT_V1.json",
    literal: null,
  }),
  Object.freeze({
    index: 16n, name: "STREAM_REFERENCE_RUNTIME_ZIP_OBJECT_V1",
    id: "0xc4346603cc517f600a467cc2184e5b94ad7eee5d1d16f8ac4e818770a27e926b" as Hex,
    contentHash: "0xb3cedd289be34a31fcd20d1941c86e28f31723e4c61f11ddf87894cda4903cac" as Hex, byteLength: 351n,
    sourcePath: "smart-contracts/domains/records/StreamReferenceRenderDefinitions.sol",
    documentPath: "schemas/records/STREAM_REFERENCE_RUNTIME_ZIP_OBJECT_V1.json",
    literal: null,
  }),
  Object.freeze({
    index: 17n, name: "STREAM_REFERENCE_NATIVE_FORMATS_V1",
    id: "0x786032a9ce8e89de0e2f6074c852bee6e3800f5b726395590aca2b6256066adb" as Hex,
    contentHash: "0x91a426d25d6e00c056cea336611731171bfe84e1b90bf10f7e2e0d0edc6d8c03" as Hex, byteLength: 422n,
    sourcePath: "smart-contracts/domains/records/StreamReferenceRenderDefinitions.sol",
    documentPath: "schemas/records/STREAM_REFERENCE_NATIVE_FORMATS_V1.json",
    literal: null,
  }),
  Object.freeze({
    index: 18n, name: "RFC8785_JCS",
    id: "0x886c7c89c308c459ca8a626e0ef36a5ea9f4c7a7b56aaf86c71a2ddf3b4f9044" as Hex,
    contentHash: "0xbc33af15c6b6374052871a5fdfa255f900f56fa594f650b2d0814c681fdb35a9" as Hex, byteLength: 362n,
    sourcePath: "smart-contracts/domains/records/StreamSnapshotDefinitions.sol",
    documentPath: "schemas/museum/account-profile/RFC8785_JCS.json",
    literal: null,
  }),
  Object.freeze({
    index: 19n, name: "RAW_BYTES",
    id: "0x220c6deb539ee172cf673a6dd0935cb8f841290a9368519d83add4dbedf24d1f" as Hex,
    contentHash: "0xcd8112d80b623f930f1df6570b5072d622f9a2aec52ae3cfbecad3f0b65c16e9" as Hex, byteLength: 78n,
    sourcePath: "smart-contracts/domains/preservation/StreamPreservationDocumentReads.sol",
    documentPath: "schemas/museum/genesis/RAW_BYTES.json",
    literal: null,
  }),
  Object.freeze({
    index: 20n, name: "STREAM_SCOPED_POLICY_SNAPSHOT_ABI_V2",
    id: "0xe3fcfa2cd1a1185ea82858dd234e5f45563509758a44aa1b589b286c044e717b" as Hex,
    contentHash: "0xf2033babe894d0d330b7199fd63eb59f57e1314db0ae56df25b114c95eb43f16" as Hex, byteLength: 3617n,
    sourcePath: "smart-contracts/domains/records/StreamScopedPolicySnapshotDefinitionsV2.sol",
    documentPath: "docs/schemas/preservation/scoped-policy-snapshot-v2.schema.json",
    literal: null,
  }),
  Object.freeze({
    index: 21n, name: "STREAM_SCOPED_POLICY_SNAPSHOT_PROFILE_V2",
    id: "0xf4d59e16e20e4a5ba8ae6f0ebf033680f03cfba822b4a30c94f455c3aedbfd7d" as Hex,
    contentHash: "0x2a9edb22fe6d8eb7105c2964dbcea97284c317242a3ee0c544dc04e6c3a4870b" as Hex, byteLength: 1350n,
    sourcePath: "smart-contracts/domains/records/StreamScopedPolicySnapshotDefinitionsV2.sol",
    documentPath: "docs/schemas/preservation/scoped-policy-snapshot-v2.profile.json",
    literal: null,
  }),
  Object.freeze({
    index: 22n, name: "STREAM_ABI_SCOPED_POLICY_SNAPSHOT_V2",
    id: "0x313d415a7b173ce1a0eeb75daa360b45606ae6f73b6a28d76db5bf372d50827b" as Hex,
    contentHash: "0xef2fb02d8cfc42671a863fdf6d4b6d5e2ffa03f053ff9019898ec0711af289a0" as Hex, byteLength: 970n,
    sourcePath: "smart-contracts/domains/records/StreamScopedPolicySnapshotDefinitionsV2.sol",
    documentPath: "docs/schemas/preservation/scoped-policy-snapshot-v2.abi.json",
    literal: null,
  }),
  Object.freeze({
    index: 23n, name: "STREAM_SCOPED_POLICY_REFERENCE_ABI_V2",
    id: "0x1172141f532a803ff39726033a71168100cef2aef58e28b09a504b5e62d85dbb" as Hex,
    contentHash: "0x66d9b03f9b6c4aa37c55df3f47a5d21a964a419bd93a83130bbf0487a0a26715" as Hex, byteLength: 26018n,
    sourcePath: "smart-contracts/domains/records/StreamScopedPolicyReferenceDefinitionsV2.sol",
    documentPath: "docs/schemas/preservation/scoped-policy-reference-v2.schema.json",
    literal: null,
  }),
  Object.freeze({
    index: 24n, name: "STREAM_SCOPED_POLICY_REFERENCE_PROFILE_V2",
    id: "0x67fc77721c9b674df2d5e6a8eca998b8ce3d812cf8f7daff852e7a6ab0895c5d" as Hex,
    contentHash: "0x4351690bd9597070d7de6a17071c7103d46a52efc757954a567fe542ecb64a47" as Hex, byteLength: 2114n,
    sourcePath: "smart-contracts/domains/records/StreamScopedPolicyReferenceDefinitionsV2.sol",
    documentPath: "docs/schemas/preservation/scoped-policy-reference-v2.profile.json",
    literal: null,
  }),
  Object.freeze({
    index: 25n, name: "STREAM_ABI_SCOPED_POLICY_REFERENCE_V2",
    id: "0x44d13bb82069bbe10d15083d7de068022878bf8c84b9dda32be6cb97e66ee220" as Hex,
    contentHash: "0xfd2a277aa777a57d09d19665f0c73a2a9ace95f4fa3c3b9b8340917e53c79028" as Hex, byteLength: 1412n,
    sourcePath: "smart-contracts/domains/records/StreamScopedPolicyReferenceDefinitionsV2.sol",
    documentPath: "docs/schemas/preservation/scoped-policy-reference-v2.abi.json",
    literal: null,
  }),
  Object.freeze({
    index: 26n, name: "STREAM_SCOPED_POLICY_OUTPUT_MANIFEST_V2",
    id: "0xe2a82022a01a70ae2fa0dbdf342b007e948063f1dcbf86ca105c955a93824c88" as Hex,
    contentHash: "0x3da02284034c97434d39902a7be1caa63634ef047d86a2f5c228820ab037e7af" as Hex, byteLength: 1608n,
    sourcePath: "smart-contracts/domains/finality/StreamScopedPolicyOutputSchemasV2.sol",
    documentPath: null,
    literal: "0x7b226e616d65223a2253545245414d5f53434f5045445f504f4c4943595f4f55545055545f4d414e49464553545f5632222c2276657273696f6e223a322c2270726f66696c65223a223635323953545245414d5f53434f5045445f504f4c4943595f43555252454e545f46554c4c5f434f4e54454e545f5632222c22666f726d6174223a22536f6c696469747920414249222c2273636f7065223a22457861637420636f6d706c65746520544f4b454e2f52454c454153452f534541534f4e20636865636b706f696e743b20434f4c4c454354494f4e2c5649455720616e64206e6f6e2d4f4e434841494e206d6f6465732072656675736564222c22726f7773223a224576657279204953747265616d53636f706564506f6c696379436f6e74656e74436865636b706f696e7456322e4f757470757420696e20657861637420617574686f726974617469766520636865636b706f696e74206f72646572222c226669656c6473223a5b2253747265616d546f6b656e436f6e74656e744c6561662875696e7432353620746f6b656e49642c62797465733332206d65746164617461486173682c6279746573333220696d616765486173682c6279746573333220616e696d6174696f6e486173682c6279746573333220636f6e74656e74486173682c6279746573333220746f6b656e446174614861736829222c22627974657333322073656c656374696f6e526f7748617368222c226279746573333220736f75726365466163747348617368222c22627974657333322068746d6c48617368222c22546f6b656e52656164696e657373286164647265737320636f6f7264696e61746f722c6279746573333220636f6f7264696e61746f72436f6465486173682c6279746573333220706f6c696379486173682c75696e7438207374617475732c75696e7438206d6f64652c75696e7438207365637572697479436c6173732c75696e74382072656e646572526571756972656d656e742c626f6f6c207465726d696e616c2c626f6f6c2066696e616c697a65642c62797465733332207365656429222c2262797465733332207465726d696e616c41646d697373696f6e48617368225d2c22656e74726f7079223a224f726967696e616c20636f6f7264696e61746f7241744d696e7420616e6420636f6d706c6574652066726f7a656e20706f6c6963792d73657420686173683b207465726d696e616c2044495341424c454420616e64204153594e43204e4f545f5245515549524544207265717569726520696e646570656e64656e746c792061646d6974746564207465726d696e616c205354415449432070726f66696c652077697468207a65726f207365656420616e642066696e616c697a65643d66616c73653b2066696e616c697a656420726f777320726571756972652061637475616c207374617475733520616e64206578616374206f726967696e616c2073656564222c22636f6d6d69746d656e7473223a224f726967696e616c20434d43207369782d6669656c6420636f6e74656e74207472656520706c75732064697374696e6374205632206f726465726564206f757470757420636861696e20616e642066756c6c20706f6c6963792f696e76656e746f727920636f6d6d69746d656e7473222c22707265736572766174696f6e223a224f75747075742068617368657320616e6420736f7572636520636f6d6d69746d656e7473206f6e6c793b20636f6d706c657465204a534f4e2c48544d4c2c696d61676520616e6420746f6b656e4461746120627974657320726571756972652073657061726174652070726573657276656420617274696661637473222c22617574686f72697479223a2243757272656e74206172636869766520636f76657261676520616e6420636865636b706f696e7420636f6d7075746174696f6e206172652065766964656e6365206f6e6c793b206e6f204172746973742c7075626c69636174696f6e206f722066696e616c69747920617574686f72697479222c2263757272656e74223a224576657279207265616420726576616c69646174657320636f6d706c65746520736f7572636520706f6c6963792073657420616e642072656e6465727320616c6c207072696f72206f757470757420726f77733b20696d6d757461626c6520686973746f72792072656d61696e73207265616461626c65227d" as Hex,
  }),
  Object.freeze({
    index: 27n, name: "STREAM_ABI_SCOPED_POLICY_OUTPUT_MANIFEST_V2",
    id: "0x945243dde0d39729458fbc1baa93dbb5d2390831799f9313d1748a4ca7f4e06a" as Hex,
    contentHash: "0x800a07f2b4e3828dbaf086aaa07ef87d3beca398fded9d48dcdfe9a98819fcaa" as Hex, byteLength: 1062n,
    sourcePath: "smart-contracts/domains/finality/StreamScopedPolicyOutputSchemasV2.sol",
    documentPath: null,
    literal: "0x7b226e616d65223a2253545245414d5f4142495f53434f5045445f504f4c4943595f4f55545055545f4d414e49464553545f5632222c2276657273696f6e223a322c22656e636f64696e67223a226162692e656e636f6465286279746573333220736368656d6149642c75696e7432353620636861696e49642c6164647265737320636f72652c6164647265737320636865636b706f696e742c6279746573333220636865636b706f696e74486173682c6279746573333220636865636b706f696e745374617465486173682c6164647265737320656e74726f7079536f757263655365742c6279746573333220696e76656e746f7279486173682c6279746573333220706f6c696379436861696e486173682c53747265616d46696e616c69747953636f70652073636f70652c6279746573333220636f6e74656e74526f6f742c62797465733332206f7574707574526f6f742c75696e74363420746f6b656e436f756e742c4953747265616d53636f706564506f6c696379436f6e74656e74436865636b706f696e7456322e4f75747075745b5d20726f777329222c22736368656d614964223a226b656363616b3235362853545245414d5f53434f5045445f504f4c4943595f4f55545055545f4d414e49464553545f563229222c22636865636b706f696e74537461746548617368223a226b656363616b323536286162692e656e636f646528636f6d706c65746520563220636865636b706f696e7420506c616e2929222c2273636f7065223a2275696e74382073636f7065547970652c75696e7432353620636f6c6c656374696f6e49642c75696e7432353620746f6b656e49642c627974657333322073636f70654964222c22686561644279746573223a3534342c2261727261794f6666736574223a3534342c226865616465724279746573496e636c7564696e674172726179436f756e74223a3537362c22726f774279746573223a3634302c226c656e677468223a223537362b3634302a746f6b656e436f756e74222c226172726179436f756e74223a2245786163746c7920706f73697469766520746f6b656e436f756e74222c22776f726473223a2233322d62797465206269672d656e6469616e3b2061646472657373657320616e64206e6172726f7720756e7369676e656420696e746567657273207a65726f2d657874656e6465643b20626f6f6c65616e732065786163746c79306f7231222c22747261696c696e674279746573223a22466f7262696464656e222c22616c7465726e6174654f666673657473223a22466f7262696464656e222c22726f774f72646572223a224578616374206f726967696e616c20636865636b706f696e74206f72646572222c2268617368223a224b656363616b2d323536206f6620636f6d706c657465206578616374206d616e69666573742062797465733b206e6f74204a4353227d" as Hex,
  }),
  Object.freeze({
    index: 28n, name: "STREAM_SCOPED_POLICY_TOKEN_CONTENT_LEAF_V2",
    id: "0xa018c7440d8bbf329bb1d4ed176bf4becdb1ed112884eea53f22b48864fca0b4" as Hex,
    contentHash: "0xb6cca3a753fb9cb049d4a401442a41ac58dce6738dae7921c7c77da29fcb1fbd" as Hex, byteLength: 816n,
    sourcePath: "smart-contracts/domains/finality/StreamScopedPolicyOutputSchemasV2.sol",
    documentPath: null,
    literal: "0x7b226e616d65223a2253545245414d5f53434f5045445f504f4c4943595f544f4b454e5f434f4e54454e545f4c4541465f5632222c2276657273696f6e223a322c226669656c6473223a5b2275696e7432353620746f6b656e4964222c2262797465733332206d6574616461746148617368222c226279746573333220696d61676548617368222c226279746573333220616e696d6174696f6e48617368222c226279746573333220636f6e74656e7448617368222c226279746573333220746f6b656e4461746148617368225d2c22656e636f64696e67223a224f726967696e616c20434d43206f726465726564207369782d6669656c6420636f6e74656e74206c6561662f747265653b206e6f20707265696d616765206368616e6765222c226d65746164617461223a2245786163742063757272656e742066756c6c20526f7574657220746f6b656e4a534f4e2062797465732c206e6f7420686973746f726963616c20636f6d70616374204a534f4e222c22616e696d6174696f6e223a2245786163742063757272656e7420746f6b656e48544d4c2062797465733b206e6f6e656d707479222c22696d616765223a224578616374206465636f6465642061646d697474656420696e6c696e652062797465733b207a65726f206f6e6c7920696620616273656e74222c22636f6e74656e74223a224e6f20736570617261746520636f6e74656e7420617373657420696e20746869732066696e6974652070726f66696c653b207a65726f222c22656e74726f7079223a22547275746866756c207465726d696e616c206f722066696e616c697a6564206f726967696e616c2d736f757263652073746174652061757468656e746963617465642062792064697374696e6374205632206f7574707574206d616e69666573743b207465726d696e616c206973206e65766572206120666162726963617465642066696e616c697a65642073656564222c22617574686f72697479223a224c656166206861736820616c6f6e65206973206e6f7420726f6f742061646f7074696f6e2c41727469737420636f6e73656e742c736e617073686f74206f722066696e616c69747920616363657074616e6365227d" as Hex,
  }),
  Object.freeze({
    index: 29n, name: "STREAM_SCOPED_POLICY_CONTENT_ROOT_RECORD_V2",
    id: "0x118a2f839943359964b297af8e4aea8721daf5cf6b74ebe401e011c207fe7f5b" as Hex,
    contentHash: "0x08c8b24b7d562d1bc02006689159be8dd018d43256514068a9a31bbb78e26c28" as Hex, byteLength: 1856n,
    sourcePath: "smart-contracts/domains/finality/StreamScopedPolicyContentRootSchemasV2.sol",
    documentPath: null,
    literal: "0x7b226e616d65223a2253545245414d5f53434f5045445f504f4c4943595f434f4e54454e545f524f4f545f5245434f52445f5632222c2276657273696f6e223a322c2270726f66696c65223a223635323953545245414d5f53434f5045445f504f4c4943595f434f4e54454e545f524f4f545f5632222c227265636f7264223a224953747265616d53636f706564436f6e74656e74526f6f745075626c69636174696f6e2e5265636f726420706c7573204953747265616d53636f706564506f6c696379436f6e74656e74526f6f745075626c69636174696f6e56322e42696e64696e6720616e6420686973746f726963616c20416767726567617465222c2273636f7065223a22457861637420544f4b454e2c52454c45415345206f7220534541534f4e3b20434f4c4c454354494f4e20616e6420564945572072656675736564222c22736f75726365223a2243757272656e7420726f6f742d667265652073636f7065642d706f6c69637920563220736e617073686f742c636f6d706c65746520617574686f7269746174697665206d656d626572736869702c61637475616c20736f7572636520666163746f727920616e6420706c616e2c72756e74696d652d70696e6e65642066756c6c206f726967696e616c2066726f7a656e20706f6c69636965732c73656c656374696f6e2c636865636b706f696e7420616e6420636f7665726564206f7574707574206d616e6966657374222c2262696e64696e674669656c6473223a5b22627974657333322070726f66696c654964222c2261646472657373206f75747075744d616e6966657374222c2262797465733332206f75747075744d616e6966657374436f646548617368222c226164647265737320636865636b706f696e74222c226279746573333220636865636b706f696e74436f646548617368222c226279746573333220636865636b706f696e7448617368222c226279746573333220636865636b706f696e74537461746548617368222c226164647265737320656e74726f7079536f75726365536574222c226279746573333220656e74726f7079536f75726365536574436f646548617368222c226279746573333220696e76656e746f727948617368222c226279746573333220706f6c696379436861696e48617368222c2262797465733332206f7574707574526f6f74222c2262797465733332206f7574707574536368656d6148617368222c2262797465733332206f757470757443616e6f6e6963616c697a6174696f6e48617368222c2262797465733332206c656166536368656d6148617368222c226279746573333220726f6f74536368656d6148617368222c226279746573333220726f6f7443616e6f6e6963616c697a6174696f6e48617368222c226164647265737320736f75726365466163746f7279222c226279746573333220736f75726365466163746f7279436f646548617368222c226279746573333220666163746f7279446570656e64656e6369657348617368222c226279746573333220736e617073686f74536368656d6148617368222c226279746573333220736e617073686f7450726f66696c6548617368222c226279746573333220736e617073686f7443616e6f6e6963616c697a6174696f6e48617368225d2c22617574686f72697479223a224f726967696e616c204d6574616461746120534e415053484f5420636c6173733720636f6c6c656374696f6e206f7220636c6173733820676c6f62616c206772616e742c657861637420417274697374206f7065726174696f6e313720434f4e54454e545f524f4f5420636f6e73656e7420616e64206f726967696e616c207265706c61792f65766f6c7574696f6e207374617465222c226c696e65616765223a224f6e65206f726967696e616c2073636f706564206865616420616e6420636f6c6c656374696f6e20616767726567617465206163726f737320563120616e642056323b206578616374207072656465636573736f72207265717569726564222c22656e74726f7079223a225465726d696e616c2044495341424c4544206f72204153594e43204e4f545f52455155495245442072656d61696e73207a65726f207365656420616e642066696e616c697a65643d66616c73653b2066696e616c697a656420726f77732072657461696e2061637475616c206f726967696e616c207374617475733520616e642073656564222c22736368656d6173223a22457861637420414354495645205241575f4259544553206f75747075742c6c6561662c726f6f7420616e6420736e617073686f7420646566696e6974696f6e73222c22726574656e74696f6e223a22536368656d613220726f6f74206576656e742072657461696e7320686973746f726963616c206167677265676174653b20636f6d70616e696f6e206576656e742072657461696e732062696e64696e673b2063757272656e74206167677265676174652063616e6e6f742061757468656e74696361746520686973746f726963616c20636f6e73656e74227d" as Hex,
  }),
  Object.freeze({
    index: 30n, name: "STREAM_ABI_SCOPED_POLICY_CONTENT_ROOT_RECORD_V2",
    id: "0x688c95666784c4559043cc46ed45fbb58c0e74ae8dfaa987b5da7a7602cafa13" as Hex,
    contentHash: "0x63eb48213fc4a7a2f90cdfe576c86f2d26785f5637f11906dcdd1877c9948143" as Hex, byteLength: 1373n,
    sourcePath: "smart-contracts/domains/finality/StreamScopedPolicyContentRootSchemasV2.sol",
    documentPath: null,
    literal: "0x7b226e616d65223a2253545245414d5f4142495f53434f5045445f504f4c4943595f434f4e54454e545f524f4f545f5245434f52445f5632222c2276657273696f6e223a322c22656e636f64696e67223a226162692e656e636f6465284953747265616d53636f706564436f6e74656e74526f6f745075626c69636174696f6e2e5265636f72642c4953747265616d53636f706564506f6c696379436f6e74656e74526f6f745075626c69636174696f6e56322e42696e64696e672c4953747265616d53636f706564436f6e74656e74526f6f745075626c69636174696f6e2e41676772656761746529222c22737461746548617368223a226b656363616b323536286162692e656e636f6465286b656363616b323536283635323953545245414d5f53434f5045445f504f4c4943595f434f4e54454e545f524f4f545f53544154455f5632292c636861696e49642c726f757465722c636f72652c7265636f726457697468537461746548617368436f6e73656e74416e645075626c697368656441745a65726f2c62696e64696e672929222c227265636f726448617368223a226b656363616b323536286162692e656e636f6465286b656363616b323536283635323953545245414d5f53434f5045445f504f4c4943595f434f4e54454e545f524f4f545f5245434f52445f5632292c636861696e49642c726f757465722c636f72652c636f6d706c657465645265636f72642c62696e64696e672c686973746f726963616c4167677265676174652929222c227369676e656446616d696c79223a224f726967696e616c203635323953545245414d5f434f4e54454e545f524f4f545f46414d494c595f574954485f53434f5045535f5631207772617073206f726967696e616c206c65676163792066616d696c79207769746820686973746f726963616c206167677265676174653b20696e646976696475616c20737461746548617368206973206e6f74207369676e65642066616d696c79222c22616767726567617465223a224f726967696e616c203635323953545245414d5f53434f5045445f434f4e54454e545f524f4f545f415050454e445f5631207472616e736974696f6e20707265696d61676520756e6368616e676564222c22726f75746548617368223a226b656363616b323536286162692e656e636f6465286b656363616b323536283635323953545245414d5f53434f5045445f504f4c4943595f434f4e54454e545f524f4f545f524f5554455f5632292c636861696e49642c6f726465726564536978546172676574732c6f72646572656453697852756e74696d654861736865732c6d657461646174612c6d6574616461746152756e74696d65486173682c73636f70652929222c2274617267657473223a22636f72652c6172746973742c726f757465722c73656c656374656446696e616c6974792c73656c656374656450726f76696465722c73636f706553656c6563746564536e617073686f74222c22737472696e6773223a2245786163742076616c696461746564205554462d38205552492062797465733b206e6f206e6f726d616c697a6174696f6e222c2263616e6f6e6963616c223a22536f6c696469747920414249206f6e6c793b20616c7465726e617465206f6666736574732c747261696c696e6720627974657320616e64206e6f6e63616e6f6e6963616c20776f72647320666f7262696464656e222c22686973746f7279223a225631207265636f726420616e6420736e617073686f742062797465732072657461696e207468656972206f726967696e616c20696e746572707265746174696f6e3b205632206e6576657220656e7465727320563120736e617073686f74206465636f64657273227d" as Hex,
  }),
]);

/** Own declared selectors; inherited IERC165 selector is excluded. */
export const SCOPED_POLICY_INVENTORY_V2_INTERFACE_ID = "0x65b019c6" as Hex;

export function scopedPolicyInventoryV2Definition(index: bigint): ScopedPolicyInventoryV2Definition {
  const i = uint(index, 64);
  if (i >= 31n) throw Error("Definition index is outside the original ordered 31");
  return SCOPED_POLICY_INVENTORY_V2_DEFINITIONS[Number(i)]!;
}

/** Full supplied chunks and facts, not a claim that any Schema/Store read occurred. */
export function validateScopedPolicyInventoryV2Document(
  definitionIndex: bigint,
  value: ScopedPolicyInventoryV2DocumentFacts,
  chunks: readonly Hex[],
): Readonly<{ facts: ScopedPolicyInventoryV2DocumentFacts; content: Hex; factsHash: Hex }> {
  const definition = scopedPolicyInventoryV2Definition(definitionIndex);
  const facts = normalizeScopedPolicyInventoryV2DocumentFacts(value);
  const parts = list(chunks).map(value => bytes(value));
  if (!facts.exists || facts.status !== 0n || facts.contentHash !== definition.contentHash
    || facts.totalBytes !== definition.byteLength || facts.chunkCount === 0n || facts.chunkCount > 64n
    || BigInt(parts.length) !== facts.chunkCount
    || parts.some(part => part.length <= 2 || (part.length - 2) / 2 > 8192)) throw Error("Invalid fixed document facts/chunks");
  const content = bytes(`0x${parts.map(part => part.slice(2)).join("")}`);
  if (BigInt((content.length - 2) / 2) !== facts.totalBytes || keccak256(content) !== facts.contentHash) {
    throw Error("Fixed document bytes differ");
  }
  return Object.freeze({ facts, content, factsHash: keccak256(encodeScopedPolicyInventoryV2DocumentFacts(facts)) as Hex });
}

export type ScopedPolicyInventoryV2Request =
  | { readonly kind: "beginInventory"; readonly scope: ScopedPolicyInventoryV2Scope }
  | { readonly kind: "appendNative" | "appendReference"; readonly id: Hex; readonly maximum: bigint }
  | { readonly kind: "appendWork"; readonly id: Hex; readonly witness: ScopedPolicyInventoryV2Work; readonly originalActor: Address }
  | { readonly kind: "appendRights"; readonly id: Hex; readonly witness: ScopedPolicyInventoryV2Rights }
  | { readonly kind: "appendIntent"; readonly id: Hex; readonly witness: ScopedPolicyInventoryV2Intent; readonly originalActor: Address }
  | { readonly kind: "appendIntentWaiver"; readonly id: Hex; readonly witness: ScopedPolicyInventoryV2IntentWaiver; readonly originalActor: Address }
  | { readonly kind: "appendInterview"; readonly id: Hex; readonly witness: ScopedPolicyInventoryV2Interview; readonly originalActor: Address }
  | {
    readonly kind: "appendRootAuthorization";
    readonly id: Hex;
    readonly actor: Address;
    readonly observedAt: bigint;
    readonly originalAggregate: ScopedPolicyInventoryV2Aggregate;
    readonly originalLegacyFamilyHash: Hex;
  }
  | { readonly kind: "appendTokenOutput"; readonly id: Hex; readonly payload: ScopedPolicyInventoryV2Payload }
  | {
    readonly kind: "appendInterviewWaiver" | "appendDefinition" | "appendTokenScript"
      | "appendTokenLibrary" | "appendTokenRenderer" | "appendTokenCitation" | "sealInventory";
    readonly id: Hex;
  };

export interface ScopedPolicyInventoryV2Call {
  readonly coordinates: ScopedPolicyInventoryV2Coordinates;
  readonly caller: Address;
  readonly request: ScopedPolicyInventoryV2Request;
  readonly call: UnsignedCall;
  readonly factsVerified: false;
}

export function normalizeScopedPolicyInventoryV2Request(value: ScopedPolicyInventoryV2Request): ScopedPolicyInventoryV2Request {
  switch (value?.kind) {
    case "beginInventory":
      exact(value, ["kind", "scope"], "Begin inventory");
      return Object.freeze({ kind: value.kind, scope: validateScopedPolicyInventoryV2Scope(value.scope) });
    case "appendNative": case "appendReference": {
      exact(value, ["kind", "id", "maximum"], "Bounded append");
      const maximum = uint(value.maximum, 64);
      if (maximum < 1n || maximum > 64n) throw Error("Original append maximum is 1..64");
      return Object.freeze({ kind: value.kind, id: nonzero(value.id), maximum });
    }
    case "appendWork": case "appendIntent": case "appendIntentWaiver": case "appendInterview": {
      exact(value, ["kind", "id", "witness", "originalActor"], "Original typed witness");
      // Original legacy Work selections require actor zero when no op24 publication exists.
      const common = { id: nonzero(value.id), originalActor: address(value.originalActor, value.kind !== "appendWork") };
      switch (value.kind) {
        case "appendWork": return Object.freeze({ ...common, kind: value.kind, witness: normalizeScopedPolicyInventoryV2Work(value.witness) });
        case "appendIntent": return Object.freeze({ ...common, kind: value.kind, witness: normalizeScopedPolicyInventoryV2Intent(value.witness) });
        case "appendIntentWaiver": return Object.freeze({ ...common, kind: value.kind, witness: normalizeScopedPolicyInventoryV2IntentWaiver(value.witness) });
        case "appendInterview": return Object.freeze({ ...common, kind: value.kind, witness: normalizeScopedPolicyInventoryV2Interview(value.witness) });
      }
    }
    case "appendRights":
      exact(value, ["kind", "id", "witness"], "Rights witness");
      return Object.freeze({ kind: value.kind, id: nonzero(value.id), witness: normalizeScopedPolicyInventoryV2Rights(value.witness) });
    case "appendRootAuthorization": {
      exact(value, ["kind", "id", "actor", "observedAt", "originalAggregate", "originalLegacyFamilyHash"], "Root authorization witness");
      const observedAt = uint(value.observedAt, 64);
      if (observedAt === 0n) throw Error("Original observedAt must be positive");
      return Object.freeze({ kind: value.kind, id: nonzero(value.id), actor: address(value.actor, true), observedAt,
        originalAggregate: root.normalizeScopedPolicyRootV2Aggregate(value.originalAggregate),
        originalLegacyFamilyHash: bytes(value.originalLegacyFamilyHash, 32) });
    }
    case "appendTokenOutput":
      exact(value, ["kind", "id", "payload"], "Token output witness");
      return Object.freeze({ kind: value.kind, id: nonzero(value.id), payload: normalizeScopedPolicyInventoryV2Payload(value.payload) });
    case "appendInterviewWaiver": case "appendDefinition": case "appendTokenScript": case "appendTokenLibrary":
    case "appendTokenRenderer": case "appendTokenCitation": case "sealInventory":
      exact(value, ["kind", "id"], "Inventory step");
      return Object.freeze({ kind: value.kind, id: nonzero(value.id) });
    default: throw Error("Unknown original inventory write kind");
  }
}

function argumentsFor(request: ScopedPolicyInventoryV2Request): readonly unknown[] {
  switch (request.kind) {
    case "beginInventory": return [request.scope];
    case "appendNative": case "appendReference": return [request.id, request.maximum];
    case "appendWork": case "appendIntent": case "appendIntentWaiver": case "appendInterview":
      return [request.id, request.witness, request.originalActor];
    case "appendRights": return [request.id, request.witness];
    case "appendRootAuthorization": return [request.id, request.actor, request.observedAt, request.originalAggregate, request.originalLegacyFamilyHash];
    case "appendTokenOutput": return [request.id, request.payload];
    default: return [request.id];
  }
}

/** Permissionless original CALL0; the actual producers validate typed witnesses and current sources. */
export function prepareScopedPolicyInventoryV2Call(
  coordinates: ScopedPolicyInventoryV2Coordinates,
  caller: Address,
  request: ScopedPolicyInventoryV2Request,
): ScopedPolicyInventoryV2Call {
  const c = normalizeScopedPolicyInventoryV2Coordinates(coordinates);
  const q = normalizeScopedPolicyInventoryV2Request(request);
  return Object.freeze({ coordinates: c, caller: address(caller, true), request: q, factsVerified: false,
    call: Object.freeze({ to: c.inventory, value: 0n, data: bytes(inventoryInterface.encodeFunctionData(q.kind, argumentsFor(q))) }) });
}

export function normalizeScopedPolicyInventoryV2Call(value: ScopedPolicyInventoryV2Call): ScopedPolicyInventoryV2Call {
  exact(value, ["coordinates", "caller", "request", "call", "factsVerified"], "Inventory call");
  exact(value.call, ["to", "value", "data"], "CALL");
  const rebuilt = prepareScopedPolicyInventoryV2Call(value.coordinates, value.caller, value.request);
  if (stable(value) !== stable(rebuilt)) throw Error("Inventory call differs from reconstruction");
  return rebuilt;
}

/** Stage checks do not reconstruct the private definition cursor or prove source currentness. */
export function validateScopedPolicyInventoryV2Stage(
  plan: ScopedPolicyInventoryV2Plan,
  tokenProgress: ScopedPolicyInventoryV2TokenProgress,
  request: ScopedPolicyInventoryV2Request,
): ScopedPolicyInventoryV2Plan {
  const p = normalizeScopedPolicyInventoryV2Plan(plan);
  const t = normalizeScopedPolicyInventoryV2TokenProgress(tokenProgress);
  const q = normalizeScopedPolicyInventoryV2Request(request);
  if (q.kind === "beginInventory") return p;
  const stages: Readonly<Record<Exclude<ScopedPolicyInventoryV2Request["kind"], "beginInventory">, bigint>> = {
    appendNative: 0n, appendReference: 1n, appendWork: 2n, appendRights: 3n,
    appendIntent: 4n, appendIntentWaiver: 4n, appendInterview: 5n, appendInterviewWaiver: 5n,
    appendRootAuthorization: 6n, appendDefinition: 7n, appendTokenOutput: 8n,
    appendTokenScript: 8n, appendTokenLibrary: 8n, appendTokenRenderer: 8n, appendTokenCitation: 8n, sealInventory: 8n,
  };
  if (p.progress.collectionId === 0n || p.progress.renderCriticalEvidenceHash !== ZERO
    || p.progress.completedStages !== stages[q.kind]) throw Error("Original inventory stage is not ready");
  const phases: Partial<Record<ScopedPolicyInventoryV2Request["kind"], bigint>> = {
    appendTokenOutput: 0n, appendTokenScript: 1n, appendTokenLibrary: 2n, appendTokenRenderer: 3n, appendTokenCitation: 4n,
  };
  const phase = phases[q.kind];
  if (phase !== undefined && (t.phase !== phase || p.progress.nextToken >= p.progress.tokenCount)) {
    throw Error("Original token phase is not ready");
  }
  if (q.kind === "sealInventory" && (p.progress.nextToken !== p.progress.tokenCount
    || t.phase !== 0n || t.row !== 0n || t.count !== 0n)) throw Error("Inventory token closure is incomplete");
  return p;
}

/** The frozen inventory reader rejects empty relayed op17/op24 proofs, even where original creation admitted ERC1271-empty. */
export function validateScopedPolicyInventoryV2OriginalAuthorization(
  actor: Address, signer: Address, direct: boolean, signature: Hex,
): void {
  const a = address(actor, true), s = address(signer, true), proof = bytes(signature);
  if (typeof direct !== "boolean" || (proof.length - 2) / 2 > 4096
    || (direct ? a !== s || proof !== "0x" : proof === "0x")) throw Error("Unsupported original retained authorization form");
}

/** The actual retained Work selection determines whether an original op24 actor is applicable. */
export function validateScopedPolicyInventoryV2WorkActor(actor: Address, attestationRecordHash: Hex): Address {
  const a = address(actor), record = bytes(attestationRecordHash, 32);
  if (record === ZERO ? a !== ZeroAddress : a === ZeroAddress) throw Error("Actor differs from the retained Work publication branch");
  return a;
}

export type ScopedPolicyInventoryV2ReadRequest =
  | { readonly kind: "core" | "metadataHost" | "metadataRouter" | "snapshots" | "referencePublisher"
      | "artifactCoverage" | "externalCoverage" | "dependencies" | "dependencyHash" | "scopedPolicyInventoryProfile" }
  | { readonly kind: "supportsInterface"; readonly interfaceId: Hex }
  | { readonly kind: "plan" | "sourceContext" | "inventoryEvidence" | "tokenProgress" | "requireFullDefinitionBytes"; readonly id: Hex }
  | { readonly kind: "inventorySegment"; readonly id: Hex; readonly index: bigint }
  | { readonly kind: "requireCurrent"; readonly scope: ScopedPolicyInventoryV2Scope };

export interface ScopedPolicyInventoryV2Read {
  readonly coordinates: ScopedPolicyInventoryV2Coordinates;
  readonly caller: Address;
  readonly request: ScopedPolicyInventoryV2ReadRequest;
  readonly call: UnsignedCall;
  readonly factsVerified: false;
}

export function prepareScopedPolicyInventoryV2Read(
  coordinates: ScopedPolicyInventoryV2Coordinates,
  caller: Address,
  request: ScopedPolicyInventoryV2ReadRequest,
): ScopedPolicyInventoryV2Read {
  const c = normalizeScopedPolicyInventoryV2Coordinates(coordinates);
  let q: ScopedPolicyInventoryV2ReadRequest, args: readonly unknown[];
  switch (request?.kind) {
    case "core": case "metadataHost": case "metadataRouter": case "snapshots": case "referencePublisher":
    case "artifactCoverage": case "externalCoverage": case "dependencies": case "dependencyHash": case "scopedPolicyInventoryProfile":
      exact(request, ["kind"], "Inventory getter"); q = Object.freeze({ kind: request.kind }); args = []; break;
    case "supportsInterface":
      exact(request, ["kind", "interfaceId"], "Interface getter");
      q = Object.freeze({ kind: request.kind, interfaceId: bytes(request.interfaceId, 4) }); args = [q.interfaceId]; break;
    case "plan": case "sourceContext": case "inventoryEvidence": case "tokenProgress": case "requireFullDefinitionBytes":
      exact(request, ["kind", "id"], "Inventory retained getter");
      q = Object.freeze({ kind: request.kind, id: bytes(request.id, 32) }); args = [q.id]; break;
    case "inventorySegment":
      exact(request, ["kind", "id", "index"], "Segment getter");
      q = Object.freeze({ kind: request.kind, id: bytes(request.id, 32), index: uint(request.index, 64) }); args = [q.id, q.index]; break;
    case "requireCurrent":
      exact(request, ["kind", "scope"], "Current inventory getter");
      q = Object.freeze({ kind: request.kind, scope: validateScopedPolicyInventoryV2Scope(request.scope) }); args = [q.scope]; break;
    default: throw Error("Unknown original inventory read kind");
  }
  return Object.freeze({ coordinates: c, caller: address(caller), request: q, factsVerified: false,
    call: Object.freeze({ to: c.inventory, value: 0n, data: bytes(inventoryInterface.encodeFunctionData(q.kind, args)) }) });
}

export function normalizeScopedPolicyInventoryV2Read(value: ScopedPolicyInventoryV2Read): ScopedPolicyInventoryV2Read {
  exact(value, ["coordinates", "caller", "request", "call", "factsVerified"], "Inventory read");
  exact(value.call, ["to", "value", "data"], "Read CALL");
  const rebuilt = prepareScopedPolicyInventoryV2Read(value.coordinates, value.caller, value.request);
  if (stable(value) !== stable(rebuilt)) throw Error("Inventory read differs from reconstruction");
  return rebuilt;
}
