import { AbiCoder, Interface, ParamType, id, keccak256 } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import * as inv from "./current-authority-preservation-inventory-v1.js";
import * as io from "./current-scoped-policy-inventory-archive-workflow-internal.js";
import type { TokenPreservationSnapshotV2CollectionSource, TokenPreservationSnapshotV2ScopedSource } from "./current-token-preservation-snapshot-v2.js";

type Kind = "collection" | "scoped";
type WorkerMethod = io.WorkerMethod & { readonly contract: string; readonly method: string };
// ABI146 compiler nominal selectors are kept separately from structural value encodings.
// Only reviewed public memory-only pure/view library entries are called. Solidity enum
// values use their source-authenticated uint8 encoding; no nominal wallet ABI is invented.
const workerTypes = {
  t0: "((address[12] targets, bytes32[12] codeHashes, address[5] artistTargets, bytes32[5] artistCodeHashes, address artistContentOwner, bytes32 artistContentOwnerCodeHash, uint256 chainId, uint256 readGas, uint256 sourceGas, uint256 selectionGas, uint256 snapshotGas, uint256 referenceGas) originalAnchor, (address resolver, bytes32 resolverCodeHash, uint256 resolverGas) authority)",
  t1: "((address[12] targets, bytes32[12] codeHashes, address[5] artistTargets, bytes32[5] artistCodeHashes, address artistContentOwner, bytes32 artistContentOwnerCodeHash, uint256 chainId, uint256 readGas, uint256 sourceGas, uint256 selectionGas, uint256 snapshotGas, uint256 referenceGas) dependencies, (((uint256 chainId, address registry, address coordinator, address archive, address[7] owners, bytes32[7] ownerCodeHashes, address core, address manager, bytes32 suiteConfigurationHash) environment, bytes32 registryCodeHash, bytes32 coordinatorCodeHash, bytes32 archiveCodeHash) origin, bytes32 completion, bytes32 selectionHash) selection)",
  t2: "(address[12] targets, bytes32[12] codeHashes, address[5] artistTargets, bytes32[5] artistCodeHashes, address artistContentOwner, bytes32 artistContentOwnerCodeHash, uint256 chainId, uint256 readGas, uint256 sourceGas, uint256 selectionGas, uint256 snapshotGas, uint256 referenceGas)",
  t3: "(address worker, bytes32 workerCodeHash, uint256 originGas, bytes32 profile)",
  t4: "((uint256 collectionId, bytes32 subject, bytes32 artistId, (bytes32 recordHash, uint256 collectionId, bytes32 snapshotId, bytes32 predecessor, uint64 revision, bytes32 recordChainHash, bytes32 manifestHash, uint32 manifestBytes, bytes32 sourceHash, bytes32 inventoryPlan, address publisher, uint8 authorizationClass, uint64 grantRevision, uint8 displayAuthorizationClass, uint64 displayGrantRevision, uint64 effectiveAt, uint64 recordedAt, bytes32 reasonHash, bytes32 schemaDefinitionHash, bytes32 profileDefinitionHash, bytes32 canonicalizationDefinitionHash) snapshot, (bytes32 recordHash, bytes32 recordChainHash, uint256 collectionId, bytes32 referenceId, bytes32 predecessor, uint64 revision, bytes32 payloadHash, uint32 payloadBytes, bytes32 sourcesHash, bytes32 snapshotRecordHash, uint64 snapshotRevision, address recorder, uint8 authorizationClass, uint64 grantRevision, uint64 effectiveAt, uint64 recordedAt, bytes32 reasonHash, bytes32 schemaHash, bytes32 profileHash, bytes32 canonicalizationHash) referenceRender, (bytes32 scopeSubject, bytes32 workDescriptionRecordHash, bytes32 rightsStatementRecordHash, bytes32 workPayloadHash, bytes32 rightsPayloadHash, bytes32 workSelectionHash, bytes32 rightsSelectionHash, uint64 workRevision, uint64 rightsRevision) descriptions, ((bytes32 recordHash, uint8 kind, bytes32 payloadHash, address recorder, uint64 recordedAt, uint64 recordIndex, bytes32 recordChainHash, bytes32 receiptHash, (bytes32 attestationRecordHash, bytes32 artistId, bytes32 bindingHash, uint64 bindingGeneration, address signer, uint8 authorityClass, uint32 requiredCapability, uint64 signedAt, bytes32 publicationHash) publication, bytes32 publicationEvidenceHash) record, (bytes32 artistId, bytes32 bindingHash, uint64 generation, bytes32 identityRecordHash) association, uint8 origin, uint8 interviewStatus, (bytes32 recordHash, uint8 kind, bytes32 payloadHash, address recorder, uint64 recordedAt, uint64 recordIndex, bytes32 recordChainHash, bytes32 receiptHash, (bytes32 attestationRecordHash, bytes32 artistId, bytes32 bindingHash, uint64 bindingGeneration, address signer, uint8 authorityClass, uint32 requiredCapability, uint64 signedAt, bytes32 publicationHash) publication, bytes32 publicationEvidenceHash) interview, bytes32 interviewArchiveReferenceHash, uint8 interviewPayloadCorrespondence, bytes32 predecessor, address submitter, uint64 revision, uint64 selectedAt, bytes32 catalogsHash, bytes32 selectionHash) conservation, bytes32 interviewEvidenceHash, bytes32 nativeHash, bytes32 rootRecordHash, bytes32 tokenInventoryHash, bytes32 checkpointHash, uint64 tokenCount) records, (bytes32 recordHash, bytes32 scopeSubject, bytes32 predecessor, uint64 revision, bytes32 chainHash, bytes32 manifestHash, uint32 manifestBytes, bytes32 sourceHash, address publisher, uint8 authorizationClass, uint64 grantRevision, uint8 displayAuthorizationClass, uint64 displayGrantRevision, uint64 recordedAt, bytes32 schemaHash, bytes32 profileHash, bytes32 canonicalizationHash) snapshot, (bytes32 scopeSubject, (bytes32 recordHash, bytes32 recordChainHash, uint256 collectionId, bytes32 referenceId, bytes32 predecessor, uint64 revision, bytes32 payloadHash, uint32 payloadBytes, bytes32 sourcesHash, bytes32 snapshotRecordHash, uint64 snapshotRevision, address recorder, uint8 authorizationClass, uint64 grantRevision, uint64 effectiveAt, uint64 recordedAt, bytes32 reasonHash, bytes32 schemaHash, bytes32 profileHash, bytes32 canonicalizationHash) observation) referenceRender, ((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, (bytes32 scopeSubject, bytes32 scopeManifestHash, bytes32 sourceRecordHash, uint256 tokenCount, bytes32 tokenListHash, bytes32 membershipHash, uint256 inventoryCount, bytes32 inventoryPrefixHash) membership, (bool locked, address registry, bytes32 registryCodeHash, bytes32 artistId, uint64 bindingGeneration, bytes32 bindingHash, address nominatedArtist, bytes32 identityRecordHash, bytes32 acceptanceRecordHash, uint64 acceptedAt, uint64 lockedAt, bytes32 snapshotHash) artist, ((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, bytes32 membershipHash, bytes32 collectionStateHash, uint64 tokenCount, uint64 nextIndex, bytes32 selectionRoot) selection, (bytes32 selectionId, bytes32 selectionHash, bytes32 inventoryHash, bytes32 policyChainHash, (uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, uint64 tokenCount, uint64 nextIndex, bytes32 leafChainHash, bytes32 contentRoot, bytes32 outputRoot, bytes32 preservationProfile) content, (bytes32 checkpointHash, bytes32 checkpointStateHash, address entropySourceSet, bytes32 inventoryHash, bytes32 policyChainHash, address metadataRouter, bytes32 preservationProfile, bytes32 artifactHash, bytes32 coverageHash, bytes32 artistId, bytes32 contentRoot, bytes32 outputRoot, bytes32 manifestHash, (uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, uint64 tokenCount, uint64 byteLength) outputs, ((uint256 collectionId, bytes32 expectedPredecessor, bytes32 verifiedManifestRecordHash, string manifestURI) publication, bytes32 contentRoot, uint64 leafCount, bytes32 manifestHash, bytes32 artistId, uint64 bindingGeneration, bytes32 bindingHash, address publisher, uint8 authorizationClass, uint64 grantRevision, bytes32 routeHash, bytes32 stateHash, bytes32 artistConsent, uint64 publishedAt) root, (bytes32 profileId, address outputManifest, bytes32 outputManifestCodeHash, address checkpoint, bytes32 checkpointCodeHash, bytes32 checkpointHash, bytes32 checkpointStateHash, address entropySourceSet, bytes32 entropySourceSetCodeHash, bytes32 inventoryHash, bytes32 policyChainHash, bytes32 outputRoot, bytes32 outputSchemaHash, bytes32 outputCanonicalizationHash, bytes32 leafSchemaHash, bytes32 rootSchemaHash, bytes32 rootCanonicalizationHash, address metadataRouter, bytes32 preservationOutputProfile) rootBinding, (bytes32 planId, bytes32 inventoryHash, bytes32 policyChainHash, uint256 policyCount, bool allFrozen, (address coordinator, bytes32 indexedCodeHash, uint256 firstTokenIndex, bool frozen, bytes32 moduleVersion, bytes32 moduleManifestHash, bytes32 moduleSchemaHash, bytes32 deploymentManifestHash, bytes32 policyHash, address provider, uint32 epoch, bytes32 salt, bytes32 componentDataHash, bool explicitPolicy, (bool configured, bool explicitPolicy, bool frozen, uint8 mode, uint8 securityClass, uint8 renderRequirement, uint64 revision, uint32 providerEpoch, bytes32 policyHash, bytes32 contentStateHash, bytes32 lastActionId, bytes32 artistConsentRecord) collectionPolicy)[] policies) entropy) source, bytes32 referenceSourceHash)",
  t5: "((uint256 chainId, address registry, address coordinator, address archive, address[7] owners, bytes32[7] ownerCodeHashes, address core, address manager, bytes32 suiteConfigurationHash) environment, bytes32 registryCodeHash, bytes32 coordinatorCodeHash, bytes32 archiveCodeHash)",
  t6: "(uint8 kind, bytes32 role, address source, bytes32 sourceRecord, uint256 sourceIndex, uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri, uint64 byteSize, bytes32 schemaId, bytes32 formatId, bytes32 catalogId, bytes32 catalogHash, bytes32 objectHash, bytes32 originalCoverageHash, bytes32 provenanceHash)[]",
  t7: "(bytes32 subjectId, bytes32 profileHash, bytes32 predecessor, uint8 form, (string title, (uint8 kind, bytes32 artistId, uint64 bindingGeneration, bytes32 bindingHash, string name) creator, (uint8 kind, uint32 start, uint32 end) creation, string medium, (uint8 kind, bytes32 formatId, string puid, (string name, (bytes32 entryId, uint8 kind, string puid, (string uri, bytes32 digest) specification)[] entries, bytes32 selectedEntryId) catalog) format, (uint8 kind, bool hasPixels, uint256 width, uint256 height, bool hasAspectRatio, (uint256 numerator, uint256 denominator) aspectRatio, bool hasDuration, (uint256 numerator, uint256 denominator) durationSeconds) measurements, (uint8 kind, uint256 number, uint256 total, string statement) edition, string creditLine, bool hasInscription, string inscription, string[] alternateTitles, (uint8 field, uint8 alternateTitleIndex, string language, string value)[] languageVariants, (uint8 role, uint8 authority, string identifier)[] authorityReferences) full, (string reason, uint32 date) absence)",
  t8: "(bytes32 subjectId, bytes32 profileHash, uint8 basis, (uint8 kind, bytes32 artistId, string name, address account, bytes32 instrumentDigest) licensor, ((uint8 status, (uint8 kind, string text, (bool exists, string uri, bytes32 digest) document) conditions, string extension) aiTraining, (uint8 status, (uint8 kind, string text, (bool exists, string uri, bytes32 digest) document) conditions, string extension) derivative, (uint8 status, (uint8 kind, string text, (bool exists, string uri, bytes32 digest) document) conditions, string extension) exhibition, (uint8 status, (uint8 kind, string text, (bool exists, string uri, bytes32 digest) document) conditions, string extension) print, (uint8 status, (uint8 kind, string text, (bool exists, string uri, bytes32 digest) document) conditions, string extension) publication, (uint8 status, (uint8 kind, string text, (bool exists, string uri, bytes32 digest) document) conditions, string extension) reproduction) grants, uint32 startDate, uint32 endDate, bool openEnd, (bool exists, string uri, bytes32 digest) instrument, bool hasAiTrainingPermission, uint8 aiTrainingPermission, bytes32 predecessor)",
  t9: "(bytes32 subjectId, bytes32 profileHash, bytes32 predecessor, (bytes32 artistId, uint64 bindingGeneration, bytes32 bindingHash, uint8 origin) artist, ((uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) scale, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) timing, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) color, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) interaction, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) motion, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) frameRate) display, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) variabilityTolerances, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) dependencyAging, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) significantProperties, (uint8 status, (uint256 chainId, address core, address host, bytes32 recordHash, bytes32 schemaId, bytes32 profileHash, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) payload) record, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) waiverStatement) interview)",
  t10: "(bytes32 subjectId, bytes32 profileHash, bytes32 predecessor, (bytes32 artistId, uint64 bindingGeneration, bytes32 bindingHash, uint8 origin) artist, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) waiverStatement, (uint8 status, (uint256 chainId, address core, address host, bytes32 recordHash, bytes32 schemaId, bytes32 profileHash, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) payload) record, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) waiverStatement) interview)",
  t11: "(bytes32 subjectId, bytes32 profileHash, bytes32 predecessor, (uint8 kind, string name, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) document) instrument, (uint8 role, string otherRole, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) identity)[] participants, uint32 interviewDate, string[] languages, ((uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) content, (uint8 kind, bytes32 formatId, string puid, (string name, (bytes32 entryId, uint8 kind, string puid, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) specification)[] entries, bytes32 selectedEntryId) catalog) format) transcript, (uint8 kind, ((uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) content, (uint8 kind, bytes32 formatId, string puid, (string name, (bytes32 entryId, uint8 kind, string puid, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) specification)[] entries, bytes32 selectedEntryId) catalog) format) payload)[] captures)",
  t12: "(uint256 collectionId, bytes32 subject, bytes32 artistId, (bytes32 recordHash, uint256 collectionId, bytes32 snapshotId, bytes32 predecessor, uint64 revision, bytes32 recordChainHash, bytes32 manifestHash, uint32 manifestBytes, bytes32 sourceHash, bytes32 inventoryPlan, address publisher, uint8 authorizationClass, uint64 grantRevision, uint8 displayAuthorizationClass, uint64 displayGrantRevision, uint64 effectiveAt, uint64 recordedAt, bytes32 reasonHash, bytes32 schemaDefinitionHash, bytes32 profileDefinitionHash, bytes32 canonicalizationDefinitionHash) snapshot, (bytes32 recordHash, bytes32 recordChainHash, uint256 collectionId, bytes32 referenceId, bytes32 predecessor, uint64 revision, bytes32 payloadHash, uint32 payloadBytes, bytes32 sourcesHash, bytes32 snapshotRecordHash, uint64 snapshotRevision, address recorder, uint8 authorizationClass, uint64 grantRevision, uint64 effectiveAt, uint64 recordedAt, bytes32 reasonHash, bytes32 schemaHash, bytes32 profileHash, bytes32 canonicalizationHash) referenceRender, (bytes32 scopeSubject, bytes32 workDescriptionRecordHash, bytes32 rightsStatementRecordHash, bytes32 workPayloadHash, bytes32 rightsPayloadHash, bytes32 workSelectionHash, bytes32 rightsSelectionHash, uint64 workRevision, uint64 rightsRevision) descriptions, ((bytes32 recordHash, uint8 kind, bytes32 payloadHash, address recorder, uint64 recordedAt, uint64 recordIndex, bytes32 recordChainHash, bytes32 receiptHash, (bytes32 attestationRecordHash, bytes32 artistId, bytes32 bindingHash, uint64 bindingGeneration, address signer, uint8 authorityClass, uint32 requiredCapability, uint64 signedAt, bytes32 publicationHash) publication, bytes32 publicationEvidenceHash) record, (bytes32 artistId, bytes32 bindingHash, uint64 generation, bytes32 identityRecordHash) association, uint8 origin, uint8 interviewStatus, (bytes32 recordHash, uint8 kind, bytes32 payloadHash, address recorder, uint64 recordedAt, uint64 recordIndex, bytes32 recordChainHash, bytes32 receiptHash, (bytes32 attestationRecordHash, bytes32 artistId, bytes32 bindingHash, uint64 bindingGeneration, address signer, uint8 authorityClass, uint32 requiredCapability, uint64 signedAt, bytes32 publicationHash) publication, bytes32 publicationEvidenceHash) interview, bytes32 interviewArchiveReferenceHash, uint8 interviewPayloadCorrespondence, bytes32 predecessor, address submitter, uint64 revision, uint64 selectedAt, bytes32 catalogsHash, bytes32 selectionHash) conservation, bytes32 interviewEvidenceHash, bytes32 nativeHash, bytes32 rootRecordHash, bytes32 tokenInventoryHash, bytes32 checkpointHash, uint64 tokenCount)",
  t13: "(uint8 kind, bytes32 role, address source, bytes32 sourceRecord, uint256 sourceIndex, uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri, uint64 byteSize, bytes32 schemaId, bytes32 formatId, bytes32 catalogId, bytes32 catalogHash, bytes32 objectHash, bytes32 originalCoverageHash, bytes32 provenanceHash)",
  t14: "(uint64 revision, bytes32 transitionChain)",
  t15: "(uint8 lane, uint256 index)",
  t16: "(((uint256 chainId, address registry, address coordinator, address archive, address[7] owners, bytes32[7] ownerCodeHashes, address core, address manager, bytes32 suiteConfigurationHash) environment, bytes32 registryCodeHash, bytes32 coordinatorCodeHash, bytes32 archiveCodeHash) producer, (((bytes32 environmentHash, uint8 ownerIndex, uint64 ownerRevision) point, uint256 nativeIndex) position, (uint16 operation, bytes32 artistId, uint256 collectionId, bytes32 recordHash) receipt) occurrence, bytes32 importCommitment, uint64 importedAtRevision, address actor, bytes32 semanticRecordHash, bytes32 role, bytes32 sourceContextHash)",
  t17: "(uint256 tokenId, address producer, bytes image, bytes animation)",
  t18: "((uint256 tokenId, bytes32 configRecordHash, bytes32 configHash, bytes32 sourceSnapshotHash, bytes32 rawSourceHash, (address registry, bytes32 registryCodeHash, bytes32 versionKey, address renderer, bytes32 rendererCodeHash, bytes32 rendererId, bytes32 rendererVersion, bytes32 contextVersion, bytes32 schemaHash, bytes32 readSetHash, bytes32 registrationHash) selection, address[6] sources, bytes32[6] sourceCodeHashes) selection, ((uint256 tokenId, bytes32 metadataHash, bytes32 imageHash, bytes32 animationHash, bytes32 contentHash, bytes32 tokenDataHash) leaf, bytes32 selectionRowHash, bytes32 sourceFactsHash, bytes32 htmlHash, (address coordinator, bytes32 coordinatorCodeHash, bytes32 policyHash, uint8 status, uint8 mode, uint8 securityClass, uint8 renderRequirement, bool terminal, bool finalized, bytes32 seed) entropy, bytes32 terminalAdmissionHash, (address producer, bytes32 producerCodeHash, bytes32 profile, address core, address metadataRouter, address liveRenderer, bytes32 liveRendererCodeHash, address attribution, bytes32 attributionCodeHash) preservation, (address registry, bytes32 registryCodeHash, bytes32 versionKey, bytes32 registrationHash, bytes32 readSetHash, bytes32 analysisHash, bytes32 goldenHash) preservationAdmission) output, bytes identity, bytes entropy, bytes config, bytes source)",
  t19: "(bytes32 selectionId, bytes32 selectionHash, bytes32 inventoryHash, bytes32 policyChainHash, (uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, uint64 tokenCount, uint64 nextIndex, bytes32 leafChainHash, bytes32 contentRoot, bytes32 outputRoot, bytes32 preservationProfile)",
  t20: "(uint256 tokenId, bytes32 configRecordHash, bytes32 configHash, bytes32 sourceSnapshotHash, bytes32 rawSourceHash, (address registry, bytes32 registryCodeHash, bytes32 versionKey, address renderer, bytes32 rendererCodeHash, bytes32 rendererId, bytes32 rendererVersion, bytes32 contextVersion, bytes32 schemaHash, bytes32 readSetHash, bytes32 registrationHash) selection, address[6] sources, bytes32[6] sourceCodeHashes)",
  t21: "((uint256 tokenId, bytes32 metadataHash, bytes32 imageHash, bytes32 animationHash, bytes32 contentHash, bytes32 tokenDataHash) leaf, bytes32 selectionRowHash, bytes32 sourceFactsHash, bytes32 htmlHash, (address coordinator, bytes32 coordinatorCodeHash, bytes32 policyHash, uint8 status, uint8 mode, uint8 securityClass, uint8 renderRequirement, bool terminal, bool finalized, bytes32 seed) entropy, bytes32 terminalAdmissionHash, (address producer, bytes32 producerCodeHash, bytes32 profile, address core, address metadataRouter, address liveRenderer, bytes32 liveRendererCodeHash, address attribution, bytes32 attributionCodeHash) preservation, (address registry, bytes32 registryCodeHash, bytes32 versionKey, bytes32 registrationHash, bytes32 readSetHash, bytes32 analysisHash, bytes32 goldenHash) preservationAdmission)",
  t22: "(uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId)",
  t23: "((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, bytes32 subject, bytes32 artistId, (bytes32 recordHash, bytes32 scopeSubject, bytes32 predecessor, uint64 revision, bytes32 chainHash, bytes32 manifestHash, uint32 manifestBytes, bytes32 sourceHash, address publisher, uint8 authorizationClass, uint64 grantRevision, uint8 displayAuthorizationClass, uint64 displayGrantRevision, uint64 recordedAt, bytes32 schemaHash, bytes32 profileHash, bytes32 canonicalizationHash) snapshot, ((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, (bytes32 scopeSubject, bytes32 scopeManifestHash, bytes32 sourceRecordHash, uint256 tokenCount, bytes32 tokenListHash, bytes32 membershipHash, uint256 inventoryCount, bytes32 inventoryPrefixHash) membership, (bool locked, address registry, bytes32 registryCodeHash, bytes32 artistId, uint64 bindingGeneration, bytes32 bindingHash, address nominatedArtist, bytes32 identityRecordHash, bytes32 acceptanceRecordHash, uint64 acceptedAt, uint64 lockedAt, bytes32 snapshotHash) artist, ((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, bytes32 membershipHash, bytes32 collectionStateHash, uint64 tokenCount, uint64 nextIndex, bytes32 selectionRoot) selection, (bytes32 selectionId, bytes32 selectionHash, bytes32 inventoryHash, bytes32 policyChainHash, (uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, uint64 tokenCount, uint64 nextIndex, bytes32 leafChainHash, bytes32 contentRoot, bytes32 outputRoot, bytes32 preservationProfile) content, (bytes32 checkpointHash, bytes32 checkpointStateHash, address entropySourceSet, bytes32 inventoryHash, bytes32 policyChainHash, address metadataRouter, bytes32 preservationProfile, bytes32 artifactHash, bytes32 coverageHash, bytes32 artistId, bytes32 contentRoot, bytes32 outputRoot, bytes32 manifestHash, (uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, uint64 tokenCount, uint64 byteLength) outputs, address sourceFactory, bytes32 sourceFactoryCodeHash, bytes32 factoryDependenciesHash, (bytes32 planId, bytes32 inventoryHash, bytes32 policyChainHash, uint256 policyCount, bool allFrozen, (address coordinator, bytes32 indexedCodeHash, uint256 firstTokenIndex, bool frozen, bytes32 moduleVersion, bytes32 moduleManifestHash, bytes32 moduleSchemaHash, bytes32 deploymentManifestHash, bytes32 policyHash, address provider, uint32 epoch, bytes32 salt, bytes32 componentDataHash, bool explicitPolicy, (bool configured, bool explicitPolicy, bool frozen, uint8 mode, uint8 securityClass, uint8 renderRequirement, uint64 revision, uint32 providerEpoch, bytes32 policyHash, bytes32 contentStateHash, bytes32 lastActionId, bytes32 artistConsentRecord) collectionPolicy)[] policies) entropy) snapshotSource, (bytes32 scopeSubject, (bytes32 recordHash, bytes32 recordChainHash, uint256 collectionId, bytes32 referenceId, bytes32 predecessor, uint64 revision, bytes32 payloadHash, uint32 payloadBytes, bytes32 sourcesHash, bytes32 snapshotRecordHash, uint64 snapshotRevision, address recorder, uint8 authorizationClass, uint64 grantRevision, uint64 effectiveAt, uint64 recordedAt, bytes32 reasonHash, bytes32 schemaHash, bytes32 profileHash, bytes32 canonicalizationHash) observation) referenceRender, (bytes32 scopeSubject, bytes32 workDescriptionRecordHash, bytes32 rightsStatementRecordHash, bytes32 workPayloadHash, bytes32 rightsPayloadHash, bytes32 workSelectionHash, bytes32 rightsSelectionHash, uint64 workRevision, uint64 rightsRevision) descriptions, ((bytes32 recordHash, uint8 kind, bytes32 payloadHash, address recorder, uint64 recordedAt, uint64 recordIndex, bytes32 recordChainHash, bytes32 receiptHash, (bytes32 attestationRecordHash, bytes32 artistId, bytes32 bindingHash, uint64 bindingGeneration, address signer, uint8 authorityClass, uint32 requiredCapability, uint64 signedAt, bytes32 publicationHash) publication, bytes32 publicationEvidenceHash) record, (bytes32 artistId, bytes32 bindingHash, uint64 generation, bytes32 identityRecordHash) association, uint8 origin, uint8 interviewStatus, (bytes32 recordHash, uint8 kind, bytes32 payloadHash, address recorder, uint64 recordedAt, uint64 recordIndex, bytes32 recordChainHash, bytes32 receiptHash, (bytes32 attestationRecordHash, bytes32 artistId, bytes32 bindingHash, uint64 bindingGeneration, address signer, uint8 authorityClass, uint32 requiredCapability, uint64 signedAt, bytes32 publicationHash) publication, bytes32 publicationEvidenceHash) interview, bytes32 interviewArchiveReferenceHash, uint8 interviewPayloadCorrespondence, bytes32 predecessor, address submitter, uint64 revision, uint64 selectedAt, bytes32 catalogsHash, bytes32 selectionHash) conservation, bytes32 interviewEvidenceHash, bytes32 nativeHash, bytes32 rootRecordHash, bytes32 tokenInventoryHash, bytes32 checkpointHash, bytes32 outputManifestRecord, bytes32 selectionId, bytes32 selectionHash, uint64 tokenCount)",
  t24: "((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, bytes32 subject, bytes32 artistId, (bytes32 recordHash, bytes32 scopeSubject, bytes32 predecessor, uint64 revision, bytes32 chainHash, bytes32 manifestHash, uint32 manifestBytes, bytes32 sourceHash, address publisher, uint8 authorizationClass, uint64 grantRevision, uint8 displayAuthorizationClass, uint64 displayGrantRevision, uint64 recordedAt, bytes32 schemaHash, bytes32 profileHash, bytes32 canonicalizationHash) snapshot, (bytes32 scopeSubject, (bytes32 recordHash, bytes32 recordChainHash, uint256 collectionId, bytes32 referenceId, bytes32 predecessor, uint64 revision, bytes32 payloadHash, uint32 payloadBytes, bytes32 sourcesHash, bytes32 snapshotRecordHash, uint64 snapshotRevision, address recorder, uint8 authorizationClass, uint64 grantRevision, uint64 effectiveAt, uint64 recordedAt, bytes32 reasonHash, bytes32 schemaHash, bytes32 profileHash, bytes32 canonicalizationHash) observation) referenceRender)",
  t25: "((uint256 tokenId, bytes32 configRecordHash, bytes32 configHash, bytes32 sourceSnapshotHash, bytes32 rawSourceHash, (address registry, bytes32 registryCodeHash, bytes32 versionKey, address renderer, bytes32 rendererCodeHash, bytes32 rendererId, bytes32 rendererVersion, bytes32 contextVersion, bytes32 schemaHash, bytes32 readSetHash, bytes32 registrationHash) selection, address[6] sources, bytes32[6] sourceCodeHashes) selection, ((uint256 tokenId, bytes32 metadataHash, bytes32 imageHash, bytes32 animationHash, bytes32 contentHash, bytes32 tokenDataHash) leaf, bytes32 selectionRowHash, bytes32 sourceFactsHash, bytes32 htmlHash, (address coordinator, bytes32 coordinatorCodeHash, bytes32 policyHash, uint8 status, uint8 mode, uint8 securityClass, uint8 renderRequirement, bool terminal, bool finalized, bytes32 seed) entropy, bytes32 terminalAdmissionHash, (address producer, bytes32 producerCodeHash, bytes32 profile, address core, address metadataRouter, address liveRenderer, bytes32 liveRendererCodeHash, address attribution, bytes32 attributionCodeHash) preservation, (address registry, bytes32 registryCodeHash, bytes32 versionKey, bytes32 registrationHash, bytes32 readSetHash, bytes32 analysisHash, bytes32 goldenHash) preservationAdmission) output, bytes identity, bytes entropy, bytes config, bytes source, address readiness, bytes terminalAdmission)",
} as const;
const workers = {
  collection: {
    authority: { contract: "StreamCurrentAuthorityInventorySelection", method: "resolve", selector: '0x44bae46e', inputs: [workerTypes.t0], outputs: [workerTypes.t1] },
    source: { contract: "StreamCurrentAuthorityPreservationPolicyRenderCriticalSourceReadsV1", method: "current", selector: '0x8a0648a7', inputs: [workerTypes.t2, workerTypes.t3, "uint256"], outputs: [workerTypes.t4, workerTypes.t5, workerTypes.t5, "bytes32"] },
    native: { contract: "StreamPreservationPolicyRenderCriticalNativeReadsV1", method: "items", selector: '0xb0dbe1d3', inputs: [workerTypes.t2, workerTypes.t4, "bytes32"], outputs: [workerTypes.t6] },
    reference: { contract: "StreamPreservationPolicyReferenceInventoryReadsV1", method: "items", selector: '0xb0dbe1d3', inputs: [workerTypes.t2, workerTypes.t4, "bytes32"], outputs: [workerTypes.t6] },
    work: { contract: "StreamPreservationTypedReferences", method: "work", selector: '0x060a99b4', inputs: ["address", "bytes32", "bytes32", workerTypes.t7], outputs: [workerTypes.t6] },
    rights: { contract: "StreamPreservationTypedReferences", method: "rights", selector: '0x64955529', inputs: ["address", "bytes32", "bytes32", workerTypes.t8], outputs: [workerTypes.t6] },
    intent: { contract: "StreamPreservationTypedReferences", method: "intent", selector: '0xeecd0bbf', inputs: ["address", "bytes32", "bytes32", workerTypes.t9], outputs: [workerTypes.t6] },
    waiver: { contract: "StreamPreservationTypedReferences", method: "waiver", selector: '0x80476513', inputs: ["address", "bytes32", "bytes32", workerTypes.t10], outputs: [workerTypes.t6] },
    interview: { contract: "StreamPreservationTypedReferences", method: "interview", selector: '0x862d2f0b', inputs: ["address", "bytes32", "bytes32", workerTypes.t11], outputs: [workerTypes.t6] },
    originals: { contract: "StreamPreservationOriginalReads", method: "items", selector: '0xd8098a23', inputs: [workerTypes.t2, workerTypes.t12, "bytes32", "bytes32"], outputs: [workerTypes.t6] },
    document: { contract: "StreamPreservationDocumentReads", method: "item", selector: '0x4be60838', inputs: [workerTypes.t2, "bytes32", "bytes32"], outputs: [workerTypes.t13] },
    documentFacts: { contract: "StreamPreservationDocumentReads", method: "currentFactsHash", selector: '0x58ec0344', inputs: [workerTypes.t2, "bytes32"], outputs: ["bytes32"] },
    catalogs: { contract: "StreamPreservationDocumentReads", method: "authenticateCatalogs", selector: '0x0934be3b', inputs: [workerTypes.t2, workerTypes.t6], outputs: [] },
    root: { contract: "StreamMultiOriginPreservationPolicyRootAuthorizationV1", method: "contentItem", selector: '0x7a6a5aad', inputs: [workerTypes.t2, workerTypes.t4, "address", "uint64", workerTypes.t14, "bytes32", workerTypes.t15], outputs: [workerTypes.t13, workerTypes.t16] },
    token: { contract: "StreamPreservationPolicyRenderCriticalTokenReadsV1", method: "tokenItems", selector: '0xd8efd7e9', inputs: [workerTypes.t2, workerTypes.t4, "uint64", workerTypes.t17], outputs: [workerTypes.t6] },
    tokenSource: { contract: "StreamPreservationPolicyRenderCriticalTokenReadsV1", method: "sourceAt", selector: '0x6d9762b7', inputs: [workerTypes.t2, workerTypes.t4, "uint64"], outputs: ["uint256", workerTypes.t18] },
    script: { contract: "StreamPreservationPolicyRenderCriticalScriptReadsV1", method: "items", selector: '0xb3a399ba', inputs: [workerTypes.t2, workerTypes.t4, "uint64", "bool"], outputs: [workerTypes.t6] },
    renderer: { contract: "StreamPreservationPolicyRenderCriticalRendererReadsV1", method: "item", selector: '0xddf40379', inputs: [workerTypes.t2, workerTypes.t4, "uint64", "uint64"], outputs: [workerTypes.t13, "uint64"] },
    preservation: { contract: "StreamPreservationPolicyAdmissionInventoryV1", method: "itemForPlan", selector: '0x7fb82873', inputs: [workerTypes.t2, workerTypes.t19, workerTypes.t20, workerTypes.t21, "uint64"], outputs: [workerTypes.t13, "uint64"] },
    profile: { contract: "StreamPreservationPolicyRenderCriticalProfileReadsV1", method: "item", selector: '0xddf40379', inputs: [workerTypes.t2, workerTypes.t4, "uint64", "uint64"], outputs: [workerTypes.t13, "uint64"] },
    definition: { contract: "StreamPreservationPolicyRenderCriticalDefinitionStagesV1", method: "definition", selector: '0x288a250e', inputs: ["uint64", "bytes32"], outputs: ["bytes32", "bytes32"] },
  },
  scoped: {
    authority: { contract: "StreamCurrentAuthorityInventorySelection", method: "resolve", selector: '0x44bae46e', inputs: [workerTypes.t0], outputs: [workerTypes.t1] },
    source: { contract: "StreamCurrentAuthorityScopedPreservationPolicyRenderCriticalSourceReadsV1", method: "current", selector: '0xb158314b', inputs: [workerTypes.t2, workerTypes.t3, workerTypes.t22], outputs: [workerTypes.t23, workerTypes.t5, workerTypes.t5, "bytes32"] },
    native: { contract: "StreamScopedPreservationPolicyRenderCriticalNativeReadsV1", method: "items", selector: '0x51e70d07', inputs: [workerTypes.t2, workerTypes.t23, "uint64", "uint64", "bytes32"], outputs: [workerTypes.t6, "uint64"] },
    reference: { contract: "StreamScopedPreservationPolicyReferenceInventoryReadsV1", method: "items", selector: '0xd0471050', inputs: [workerTypes.t2, workerTypes.t24, "uint64", "uint64", "bytes32"], outputs: [workerTypes.t6, "uint64"] },
    work: { contract: "StreamPreservationTypedReferences", method: "work", selector: '0x060a99b4', inputs: ["address", "bytes32", "bytes32", workerTypes.t7], outputs: [workerTypes.t6] },
    rights: { contract: "StreamPreservationTypedReferences", method: "rights", selector: '0x64955529', inputs: ["address", "bytes32", "bytes32", workerTypes.t8], outputs: [workerTypes.t6] },
    intent: { contract: "StreamPreservationTypedReferences", method: "intent", selector: '0xeecd0bbf', inputs: ["address", "bytes32", "bytes32", workerTypes.t9], outputs: [workerTypes.t6] },
    waiver: { contract: "StreamPreservationTypedReferences", method: "waiver", selector: '0x80476513', inputs: ["address", "bytes32", "bytes32", workerTypes.t10], outputs: [workerTypes.t6] },
    interview: { contract: "StreamPreservationTypedReferences", method: "interview", selector: '0x862d2f0b', inputs: ["address", "bytes32", "bytes32", workerTypes.t11], outputs: [workerTypes.t6] },
    originals: { contract: "StreamPreservationOriginalReads", method: "items", selector: '0xd8098a23', inputs: [workerTypes.t2, workerTypes.t12, "bytes32", "bytes32"], outputs: [workerTypes.t6] },
    document: { contract: "StreamPreservationDocumentReads", method: "item", selector: '0x4be60838', inputs: [workerTypes.t2, "bytes32", "bytes32"], outputs: [workerTypes.t13] },
    documentFacts: { contract: "StreamPreservationDocumentReads", method: "currentFactsHash", selector: '0x58ec0344', inputs: [workerTypes.t2, "bytes32"], outputs: ["bytes32"] },
    catalogs: { contract: "StreamPreservationDocumentReads", method: "authenticateCatalogs", selector: '0x0934be3b', inputs: [workerTypes.t2, workerTypes.t6], outputs: [] },
    root: { contract: "StreamMultiOriginScopedPreservationPolicyRootAuthorizationV1", method: "contentItem", selector: '0xa169ede0', inputs: [workerTypes.t2, workerTypes.t23, "address", "uint64", workerTypes.t14, "bytes32", "bytes32", workerTypes.t15], outputs: [workerTypes.t13, workerTypes.t16] },
    token: { contract: "StreamScopedPreservationPolicyRenderCriticalTokenReadsV1", method: "tokenItems", selector: '0x9ea2bacf', inputs: [workerTypes.t2, workerTypes.t23, "uint64", workerTypes.t17], outputs: [workerTypes.t6] },
    tokenSource: { contract: "StreamScopedPreservationPolicyRenderCriticalTokenReadsV1", method: "sourceAt", selector: '0x130a9f0b', inputs: [workerTypes.t2, workerTypes.t23, "uint64"], outputs: ["uint256", workerTypes.t25] },
    script: { contract: "StreamScopedPreservationPolicyRenderCriticalScriptReadsV1", method: "items", selector: '0x4f177018', inputs: [workerTypes.t2, workerTypes.t23, "uint64", "bool"], outputs: [workerTypes.t6] },
    renderer: { contract: "StreamScopedPreservationPolicyRenderCriticalRendererReadsV1", method: "item", selector: '0x566f7902', inputs: [workerTypes.t2, workerTypes.t23, "uint64", "uint64"], outputs: [workerTypes.t13, "uint64"] },
    preservation: { contract: "StreamPreservationPolicyAdmissionInventoryV1", method: "itemForPlan", selector: '0x7fb82873', inputs: [workerTypes.t2, workerTypes.t19, workerTypes.t20, workerTypes.t21, "uint64"], outputs: [workerTypes.t13, "uint64"] },
    profile: { contract: "StreamScopedPreservationPolicyRenderCriticalCitationReadsV1", method: "item", selector: '0x566f7902', inputs: [workerTypes.t2, workerTypes.t23, "uint64", "uint64"], outputs: [workerTypes.t13, "uint64"] },
    definition: { contract: "StreamScopedPreservationPolicyRenderCriticalDefinitionsV1", method: "definition", selector: '0x288a250e', inputs: ["uint64", "bytes32"], outputs: ["bytes32", "bytes32"] },
  },
} as const satisfies Record<Kind, Record<string, WorkerMethod>>;
const originAbi = new Interface([
  "function publicationItem((address[12] targets, bytes32[12] codeHashes, address[5] artistTargets, bytes32[5] artistCodeHashes, address artistContentOwner, bytes32 artistContentOwnerCodeHash, uint256 chainId, uint256 readGas, uint256 sourceGas, uint256 selectionGas, uint256 snapshotGas, uint256 referenceGas) d, (bytes32 attestationRecordHash, bytes32 artistId, bytes32 bindingHash, uint64 bindingGeneration, address signer, uint8 authorityClass, uint32 requiredCapability, uint64 signedAt, bytes32 publicationHash) expected, bytes32 originalRecord, address actor, bytes32 sourceContextHash, (uint8 lane, uint256 index) witness) view returns ((uint8 kind, bytes32 role, address source, bytes32 sourceRecord, uint256 sourceIndex, uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri, uint64 byteSize, bytes32 schemaId, bytes32 formatId, bytes32 catalogId, bytes32 catalogHash, bytes32 objectHash, bytes32 originalCoverageHash, bytes32 provenanceHash) item, (((uint256 chainId, address registry, address coordinator, address archive, address[7] owners, bytes32[7] ownerCodeHashes, address core, address manager, bytes32 suiteConfigurationHash) environment, bytes32 registryCodeHash, bytes32 coordinatorCodeHash, bytes32 archiveCodeHash) producer, (((bytes32 environmentHash, uint8 ownerIndex, uint64 ownerRevision) point, uint256 nativeIndex) position, (uint16 operation, bytes32 artistId, uint256 collectionId, bytes32 recordHash) receipt) occurrence, bytes32 importCommitment, uint64 importedAtRevision, address actor, bytes32 semanticRecordHash, bytes32 role, bytes32 sourceContextHash) original)",
]);
const resolverAbi = new Interface([
  "function anchors() view returns ((address[5] targets, bytes32[5] codeHashes, address finalityRegistry, uint256 chainId, uint256 readGas))",
  "function currentAuthorityProfile() view returns (bytes32)",
  "function currentSelection() view returns ((((uint256 chainId, address registry, address coordinator, address archive, address[7] owners, bytes32[7] ownerCodeHashes, address core, address manager, bytes32 suiteConfigurationHash) environment, bytes32 registryCodeHash, bytes32 coordinatorCodeHash, bytes32 archiveCodeHash) origin, bytes32 completion, bytes32 selectionHash))",
]);
const recordAuthorityAbi = new Interface([
  "function currentArtistContext() view returns (address[5] targets, bytes32[5] codeHashes)",
  "function currentAuthorityProfile() pure returns (bytes32)",
  "function supportsInterface(bytes4 interfaceId) view returns (bool)",
]);
const workAbi = new Interface([
  "function workSelectionAt(uint256 collectionId, bytes32 subjectId, uint64 revision) view returns ((bytes32 recordHash, bytes32 predecessor, bytes32 payloadHash, address submitter, uint8 mode, uint256 grantScope, uint64 grantRevision, uint64 revision, uint64 recordIndex, bytes32 recordChainHash, uint64 selectedAt, uint8 selectorAuthorizationClass, address recorder, uint8 recorderAuthorizationClass, uint8 form, uint8 creatorKind, (bytes32 artistId, bytes32 bindingHash, uint64 generation, bytes32 identityRecordHash) creatorAssociation, (bytes32 attestationRecordHash, bytes32 artistId, bytes32 bindingHash, uint64 bindingGeneration, address signer, uint8 authorityClass, uint32 requiredCapability, uint64 signedAt, bytes32 publicationHash) artistPublication, bytes32 artistPublicationEvidenceHash, bytes32 catalogId, bytes32 catalogHash, bytes32 selectionHash))",
]);

type Dependencies = inv.CurrentAuthorityPreservationInventoryV1Dependencies;
type Context = inv.CurrentAuthorityPreservationInventoryV1Context;
type Plan = inv.CurrentAuthorityPreservationInventoryV1Plan;
type Progress = inv.CurrentAuthorityPreservationInventoryV1Progress;
type Origin = inv.CurrentAuthorityPreservationInventoryV1Origin;
type RecordOrigin = inv.CurrentAuthorityPreservationInventoryV1RecordOrigin;
type Item = inv.CurrentAuthorityPreservationInventoryV1Item;
type Evidence = inv.CurrentAuthorityPreservationInventoryV1Evidence;
type Mutable<T> = T extends readonly (infer V)[] ? Mutable<V>[] : T extends object ? { -readonly [K in keyof T]: Mutable<T[K]> } : T;
const coder = AbiCoder.defaultAbiCoder();
const FAMILY = inv.CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_FAMILY;
const MAX_SEGMENTS = 16_384;
const MAX_ITEMS = 16_384;
const MAX_ORIGINS = 17;
const ZERO_TOKEN = { phase: 0n, row: 0n, count: 0n } as const;
const workerRoles = ["authority", "source", "native", "reference", "typedReferences", "originals", "documents", "root", "token", "script", "renderer", "profile", "preservation", "definitions"] as const;
type Role = typeof workerRoles[number];
export type CurrentAuthorityPreservationInventoryV1CodePin = io.CodePin;
export type CurrentAuthorityPreservationInventoryV1Block = io.Block;
export type CurrentAuthorityPreservationInventoryV1ReceiptOptions = io.ReceiptOptions;
export type CurrentAuthorityPreservationInventoryV1ReadWorkers = Readonly<Record<Role, io.CodePin>>;
/** Reviewed actual deployed library addresses, including their complete linked closure. */
export interface CurrentAuthorityPreservationInventoryV1Deployment {
  readonly chainId: bigint;
  readonly core: Address;
  readonly scopeKind: Kind;
  readonly inventory: io.CodePin;
  readonly workers: CurrentAuthorityPreservationInventoryV1ReadWorkers;
  readonly linkedDependencies: readonly io.CodePin[];
}
/** Local getters only. No current resolver, source, origin runtime, or document admission. */
export interface CurrentAuthorityPreservationInventoryV1HistoryDeployment {
  readonly chainId: bigint;
  readonly core: Address;
  readonly scopeKind: Kind;
  readonly inventory: io.CodePin;
}
export interface CurrentAuthorityPreservationInventoryV1SegmentLocator {
  readonly transactionHash: Hex;
  readonly logIndex: number;
}
export interface CurrentAuthorityPreservationInventoryV1SegmentObservation {
  readonly locator: CurrentAuthorityPreservationInventoryV1SegmentLocator;
  readonly recorded: io.Block;
  readonly planId: Hex;
  readonly index: bigint;
  readonly segment: inv.CurrentAuthorityPreservationInventoryV1Segment;
  readonly items: readonly Item[];
}
export interface CurrentAuthorityPreservationInventoryV1OriginState {
  readonly origins: readonly Origin[];
  readonly runtimeCursor: bigint;
  readonly setHash: Hex;
  readonly records: readonly Readonly<{ itemHash: Hex; original: RecordOrigin }>[];
}
export interface CurrentAuthorityPreservationInventoryV1DocumentPin {
  readonly id: Hex;
  readonly factsHash: Hex;
}
export interface CurrentAuthorityPreservationInventoryV1Stage {
  readonly planId: Hex;
  readonly originalAnchor: Dependencies;
  readonly originDependencies: inv.CurrentAuthorityPreservationInventoryV1OriginDependencies;
  readonly authorityDependencies: inv.CurrentAuthorityPreservationInventoryV1AuthorityDependencies;
  readonly authorityAnchors: inv.CurrentAuthorityPreservationInventoryV1AuthorityAnchors;
  readonly dependencyHash: Hex;
  readonly selection: inv.CurrentAuthorityPreservationInventoryV1Capture;
  readonly context: Context;
  readonly lineageHash: Hex;
  readonly before: Plan;
  readonly after: Plan;
  readonly tokenBefore: inv.CurrentAuthorityPreservationInventoryV1TokenProgress;
  readonly tokenAfter: inv.CurrentAuthorityPreservationInventoryV1TokenProgress;
  readonly originsBefore: CurrentAuthorityPreservationInventoryV1OriginState;
  readonly originsAfter: CurrentAuthorityPreservationInventoryV1OriginState;
  readonly segments: readonly CurrentAuthorityPreservationInventoryV1SegmentObservation[];
  readonly documents: readonly CurrentAuthorityPreservationInventoryV1DocumentPin[];
  readonly appended: Readonly<{ segment: inv.CurrentAuthorityPreservationInventoryV1Segment; items: readonly Item[] }> | null;
  readonly evidence: Evidence | null;
  readonly existing: boolean;
}
export interface CurrentAuthorityPreservationInventoryV1WorkflowCapture {
  readonly deployment: CurrentAuthorityPreservationInventoryV1Deployment;
  readonly prepared: inv.CurrentAuthorityPreservationInventoryV1Call;
  readonly observed: io.Block;
  readonly gasLimit: bigint;
  readonly stage: CurrentAuthorityPreservationInventoryV1Stage;
  readonly captureHash: Hex;
}
function historicalDeployment(v: CurrentAuthorityPreservationInventoryV1HistoryDeployment): CurrentAuthorityPreservationInventoryV1HistoryDeployment {
  io.keys(v, ["chainId", "core", "scopeKind", "inventory"]);
  if (v.scopeKind !== "collection" && v.scopeKind !== "scoped") throw Error("Unsupported inventory family");
  return io.freeze({ chainId: io.uint(v.chainId), core: io.address(v.core), scopeKind: v.scopeKind, inventory: io.codePin(v.inventory) });
}
function deployment(v: CurrentAuthorityPreservationInventoryV1Deployment): CurrentAuthorityPreservationInventoryV1Deployment {
  io.keys(v, ["chainId", "core", "scopeKind", "inventory", "workers", "linkedDependencies"]);
  io.keys(v.workers, workerRoles);
  const base = historicalDeployment({ chainId: v.chainId, core: v.core, scopeKind: v.scopeKind, inventory: v.inventory });
  return io.freeze({ ...base, workers: Object.fromEntries(workerRoles.map(key => [key, io.codePin(v.workers[key])])) as CurrentAuthorityPreservationInventoryV1ReadWorkers,
    linkedDependencies: io.pinList(v.linkedDependencies) });
}
function hd(d: CurrentAuthorityPreservationInventoryV1HistoryDeployment) { return { chainId: d.chainId, core: d.core, scopeKind: d.scopeKind, inventory: d.inventory }; }
function coordinates(d: CurrentAuthorityPreservationInventoryV1HistoryDeployment): inv.CurrentAuthorityPreservationInventoryV1Coordinates {
  return { chainId: d.chainId, core: d.core, scopeKind: d.scopeKind, inventory: d.inventory.address };
}
const host = (kind: Kind) => inv.currentAuthorityPreservationInventoryV1Interface(kind);
const profile = (kind: Kind) => kind === "collection" ? inv.CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_COLLECTION_PROFILE : inv.CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_SCOPED_PROFILE;
function progress(plan: Plan): Progress { return "progress" in plan ? plan.progress : plan; }
function common(c: Context) { return "records" in c ? c.records : c; }
function source(c: Context): TokenPreservationSnapshotV2CollectionSource | TokenPreservationSnapshotV2ScopedSource { return "records" in c ? c.source : c.snapshotSource; }
function scopeOf(c: Context) { return "records" in c ? c.source.scope : c.scope; }
function content(c: Context) { return source(c).content; }
function contextHash(kind: Kind, c: Context) { return keccak256(inv.encodeCurrentAuthorityPreservationInventoryV1Context(kind, c)) as Hex; }
function zero(type: ParamType): unknown {
  if (type.baseType === "array") return type.arrayLength === -1 ? [] : Array.from({ length: type.arrayLength! }, () => zero(type.arrayChildren!));
  if (type.baseType === "tuple") return Object.fromEntries(type.components!.map(v => [v.name, zero(v)]));
  if (type.type === "address") return io.ZERO_ADDRESS;
  if (type.type === "bool") return false;
  if (type.type === "string") return "";
  if (type.type === "bytes") return "0x";
  if (type.type.startsWith("bytes")) return `0x${"00".repeat(Number(type.type.slice(5)))}`;
  return 0n;
}
function emptyPlan(kind: Kind): Plan {
  return inv.normalizeCurrentAuthorityPreservationInventoryV1Plan(kind, zero(ParamType.from(kind === "collection"
    ? inv.CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_COLLECTION_PLAN_TUPLE : inv.CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_SCOPED_PLAN_TUPLE)) as Plan);
}
function locators(v: readonly CurrentAuthorityPreservationInventoryV1SegmentLocator[]) {
  if (!Array.isArray(v) || v.length > MAX_SEGMENTS) throw Error("Segment locator client allocation limit exceeded");
  const result = v.map(row => { io.keys(row, ["transactionHash", "logIndex"]); return { transactionHash: io.hash(row.transactionHash), logIndex: io.number(row.logIndex) }; });
  if (new Set(result.map(row => `${row.transactionHash}:${row.logIndex}`)).size !== result.length) throw Error("Duplicate segment locator");
  return io.freeze(result);
}
async function read<T>(p: io.Reader, d: CurrentAuthorityPreservationInventoryV1HistoryDeployment, name: string, args: readonly unknown[], tag: number, cap?: bigint) {
  return io.read<T>(p, d.inventory.address, host(d.scopeKind), name, args, tag, undefined, cap);
}
async function computation(p: io.Reader, d: CurrentAuthorityPreservationInventoryV1Deployment, role: Role,
  method: keyof typeof workers.collection, args: readonly unknown[], tag: number, cap: bigint) {
  return io.worker(p, d.workers[role], workers[d.scopeKind][method], args, tag, cap);
}
function dependencyPins(d: Dependencies): readonly io.CodePin[] { return [...d.targets.map((address, i) => ({ address, codeHash: d.codeHashes[i]! })),
  ...d.artistTargets.map((address, i) => ({ address, codeHash: d.artistCodeHashes[i]! })), { address: d.artistContentOwner, codeHash: d.artistContentOwnerCodeHash }]; }
function originPins(o: Origin): readonly io.CodePin[] { return [{ address: o.environment.registry, codeHash: o.registryCodeHash },
  { address: o.environment.coordinator, codeHash: o.coordinatorCodeHash }, { address: o.environment.archive, codeHash: o.archiveCodeHash },
  ...o.environment.owners.map((address, i) => ({ address, codeHash: o.environment.ownerCodeHashes[i]! }))]; }
async function bindings(p: io.Reader, d: CurrentAuthorityPreservationInventoryV1HistoryDeployment, tag: number) {
  await io.runtime(p, d.inventory, tag);
  const originalAnchor = inv.normalizeCurrentAuthorityPreservationInventoryV1Dependencies(await read(p, d, "dependencies", [], tag));
  io.equal(await read(p, d, "originalAnchor", [], tag), originalAnchor, "Original dependency anchor differs");
  if (originalAnchor.chainId !== d.chainId || originalAnchor.targets[0] !== d.core) throw Error("Inventory deployment identity differs");
  const originDependencies = inv.normalizeCurrentAuthorityPreservationInventoryV1OriginDependencies(await read(p, d, "originDependencies", [], tag));
  const authorityDependencies = inv.normalizeCurrentAuthorityPreservationInventoryV1AuthorityDependencies(await read(p, d, "authorityDependencies", [], tag));
  const dependencyHash = inv.currentAuthorityPreservationInventoryV1DependencyHash(d.scopeKind, originalAnchor, originDependencies, authorityDependencies);
  io.equal(await read(p, d, "dependencyHash", [], tag), dependencyHash, "Dependency hash differs");
  io.equal(await read(p, d, d.scopeKind === "collection" ? "preservationPolicyInventoryProfile" : "scopedPreservationPolicyInventoryProfile", [], tag), profile(d.scopeKind), "Wrong current-authority inventory profile");
  io.equal(await read(p, d, "originProfile", [], tag), profile(d.scopeKind), "Wrong origin inventory profile");
  for (const [name, slot] of [["core", 0], ["metadataHost", 1], ["metadataRouter", 4], ["snapshots", 5], ["referencePublisher", 6], ["artifactCoverage", 10], ["externalCoverage", 11]] as const) {
    io.equal(await read(p, d, name, [], tag), originalAnchor.targets[slot], "Named immutable dependency differs");
  }
  return { originalAnchor, originDependencies, authorityDependencies, dependencyHash };
}
async function liveBindings(p: io.Reader, d: CurrentAuthorityPreservationInventoryV1Deployment, tag: number, cap: bigint) {
  const b = await bindings(p, d, tag);
  const ad = b.authorityDependencies;
  const od = b.originDependencies;
  if (b.originalAnchor.readGas < 50_000n || [b.originalAnchor.sourceGas, b.originalAnchor.selectionGas, b.originalAnchor.snapshotGas, b.originalAnchor.referenceGas].some(g => g < b.originalAnchor.readGas)
    || ad.resolverGas < 50_000n || ad.resolverGas >= 1n << 64n || od.originGas < 50_000n || od.originGas >= 1n << 64n || od.profile !== inv.CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_ORIGIN_PROFILE) throw Error("Invalid original read budgets/profile");
  await io.runtimes(p, [...dependencyPins(b.originalAnchor), { address: ad.resolver, codeHash: ad.resolverCodeHash },
    { address: od.worker, codeHash: od.workerCodeHash }, ...workerRoles.map(role => d.workers[role]), ...d.linkedDependencies], tag);
  const authorityAnchors = inv.normalizeCurrentAuthorityPreservationInventoryV1AuthorityAnchors(await io.read(p, ad.resolver, resolverAbi, "anchors", [], tag, undefined, ad.resolverGas));
  io.equal(await io.read(p, ad.resolver, resolverAbi, "currentAuthorityProfile", [], tag, undefined, ad.resolverGas), inv.CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_AUTHORITY_PROFILE, "Wrong resolver profile");
  const selection = inv.normalizeCurrentAuthorityPreservationInventoryV1Capture((await computation(p, d, "authority", "authority", [{ originalAnchor: b.originalAnchor, authority: ad }], tag, cap))[0] as inv.CurrentAuthorityPreservationInventoryV1Capture);
  io.equal(selection.selection, inv.normalizeCurrentAuthorityPreservationInventoryV1Selection(await io.read(p, ad.resolver, resolverAbi, "currentSelection", [], tag, undefined, ad.resolverGas)), "Worker selection differs from actual resolver");
  io.equal(selection.selection.selectionHash, inv.currentAuthorityPreservationInventoryV1SelectionHash(authorityAnchors, selection.selection.origin, selection.selection.completion), "Current selection commitment differs");
  io.equal(selection.dependencies, inv.currentAuthorityPreservationInventoryV1CaptureDependencies(b.originalAnchor, selection.selection), "Captured Artist substitutions differ");
  inv.validateCurrentAuthorityPreservationInventoryV1Capture(b.originalAnchor, authorityAnchors, selection);
  await io.runtimes(p, dependencyPins(selection.dependencies), tag);
  await io.runtimes(p, originPins(selection.selection.origin), tag);
  return { ...b, authorityAnchors, selection };
}
function rows(value: unknown): readonly Item[] {
  if (!Array.isArray(value) || value.length > MAX_ITEMS) throw Error("Item client allocation limit exceeded");
  return value.map(inv.normalizeCurrentAuthorityPreservationInventoryV1Item);
}
function lineage(deps: Dependencies, c: Context, current: Origin, presented: Origin): Hex {
  return inv.currentAuthorityPreservationInventoryV1LineageHash(deps, scopeOf(c).collectionId, source(c).artist,
    common(c).conservation.association, current, presented);
}
function deduplicateOrigins(input: readonly Origin[]): readonly Origin[] {
  const result: Origin[] = [];
  for (const o of input) {
    const key = inv.currentAuthorityPreservationInventoryV1OriginEnvironmentHash(o.environment);
    const prior = result.find(row => inv.currentAuthorityPreservationInventoryV1OriginEnvironmentHash(row.environment) === key);
    if (prior) io.equal(o, prior, "Conflicting pins for the same origin environment");
    else result.push(o);
  }
  if (!result.length || result.length > MAX_ORIGINS) throw Error("Origin count exceeds original bound");
  return result;
}

function eventName(kind: Kind, suffix: "Started" | "SegmentRecorded" | "Completed") { return `${kind === "scoped" ? "Scoped" : ""}Inventory${suffix}`; }
export async function inspectCurrentAuthorityPreservationInventoryV1Segment(
  p: io.ReceiptReader, inputDeployment: CurrentAuthorityPreservationInventoryV1HistoryDeployment,
  inputLocator: CurrentAuthorityPreservationInventoryV1SegmentLocator, options: { readonly blockTag: number }
): Promise<CurrentAuthorityPreservationInventoryV1SegmentObservation> {
  const d = historicalDeployment(inputDeployment);
  const locator = locators([inputLocator])[0]!;
  io.keys(options, ["blockTag"]);
  const tag = io.number(options.blockTag);
  const observed = await io.chain(p, d.chainId, tag);
  await io.runtime(p, d.inventory, tag);
  const tx = await io.mined(p, d.chainId, locator.transactionHash);
  if (tx.observed.blockNumber > tag) throw Error("Segment is later than history block");
  await io.runtime(p, d.inventory, tx.observed.blockNumber);
  const events = io.events(tx.logs, d.inventory.address, host(d.scopeKind), eventName(d.scopeKind, "SegmentRecorded")).filter(e => e.index === locator.logIndex);
  if (events.length !== 1) throw Error("Missing exact segment event");
  const event = events[0]!.fields;
  if (d.scopeKind === "scoped" && event.schemaVersion !== 1n) throw Error("Wrong scoped inventory schema");
  const planId = io.hash(d.scopeKind === "scoped" ? event.id : event.planId);
  const index = io.uint(event.index, 64);
  const segment = inv.normalizeCurrentAuthorityPreservationInventoryV1Segment(event.segment as inv.CurrentAuthorityPreservationInventoryV1Segment);
  const items = rows(event.items);
  io.equal(segment, inv.currentAuthorityPreservationInventoryV1Segment(inv.currentAuthorityPreservationInventoryV1SegmentKey(d.scopeKind, planId, index), segment.sourceWitnessHash, items), "Event Item chain differs");
  io.equal(await read(p, d, "inventorySegment", [planId, index], tag), segment, "Event segment differs from local retained row");
  await io.unchanged(p, observed);
  return io.freeze({ locator, recorded: tx.observed, planId, index, segment, items });
}
async function segmentHistory(p: io.ReceiptReader, d: CurrentAuthorityPreservationInventoryV1HistoryDeployment, planId: Hex, plan: Plan,
  input: readonly CurrentAuthorityPreservationInventoryV1SegmentLocator[], tag: number) {
  const saved = progress(plan);
  if (saved.segmentCount > BigInt(MAX_SEGMENTS) || input.length !== Number(saved.segmentCount)) throw Error("Complete ordered segment locators required within client allocation limit");
  const result: CurrentAuthorityPreservationInventoryV1SegmentObservation[] = [];
  let chain = io.ZERO, total = 0n;
  for (let i = 0; i < input.length; i++) {
    const row = await inspectCurrentAuthorityPreservationInventoryV1Segment(p, hd(d), input[i]!, { blockTag: tag });
    if (row.planId !== planId || row.index !== BigInt(i)) throw Error("Segment plan/order differs");
    const previous = result.at(-1);
    if (previous && (row.recorded.blockNumber < previous.recorded.blockNumber || (row.recorded.blockNumber === previous.recorded.blockNumber && row.locator.logIndex <= previous.locator.logIndex))) throw Error("Segment chronology differs");
    result.push(row);
    chain = inv.currentAuthorityPreservationInventoryV1AppendSegment(chain, row.index, row.segment);
    total += row.segment.itemCount;
    if (total > BigInt(MAX_ITEMS)) throw Error("Total Item client allocation limit exceeded");
  }
  io.equal(chain, saved.segmentChainHash, "Retained segment chain differs");
  io.equal(total, saved.itemCount, "Retained item count differs");
  return result;
}
const publicationRole = id("ORIGINAL_ARTIST_PUBLICATION_AUTHORIZATION") as Hex;
const rootRole = (kind: Kind) => id(kind === "collection" ? "ORIGINAL_PRESERVATION_POLICY_CONTENT_ROOT_AUTHORIZATION_V1" : "ORIGINAL_SCOPED_PRESERVATION_POLICY_CONTENT_ROOT_AUTHORIZATION_V1") as Hex;
function isOriginItem(kind: Kind, item: Item) { return item.role === publicationRole || item.role === rootRole(kind); }
function validateOriginItem(d: CurrentAuthorityPreservationInventoryV1HistoryDeployment, context: Context, sourceContextHash: Hex, item: Item, original: RecordOrigin) {
  const e = original.producer.environment;
  if (e.chainId !== d.chainId || e.core !== d.core || original.sourceContextHash !== sourceContextHash
    || original.actor === io.ZERO_ADDRESS || original.semanticRecordHash === io.ZERO || original.occurrence.receipt.recordHash === io.ZERO
    || original.occurrence.receipt.collectionId !== scopeOf(context).collectionId || original.occurrence.receipt.artistId !== common(context).artistId
    || original.occurrence.position.point.environmentHash !== inv.currentAuthorityPreservationInventoryV1OriginEnvironmentHash(e)
    || original.role !== item.role || item.kind !== 6n || item.source !== e.archive || item.sourceIndex !== 1n
    || item.sourceRecord !== inv.currentAuthorityPreservationInventoryV1EvidenceId(original) || item.provenanceHash === io.ZERO) throw Error("Retained Artist origin/item join differs");
  io.hash(original.producer.registryCodeHash); io.hash(original.producer.coordinatorCodeHash); io.hash(original.producer.archiveCodeHash);
  if (item.role === publicationRole ? original.occurrence.receipt.operation !== 24n : original.occurrence.receipt.operation !== 17n) throw Error("Wrong original Artist operation");
}
async function originState(p: io.Reader, d: CurrentAuthorityPreservationInventoryV1HistoryDeployment, planId: Hex, c: Context,
  plan: Plan, segments: readonly CurrentAuthorityPreservationInventoryV1SegmentObservation[], selection: inv.CurrentAuthorityPreservationInventoryV1Capture, tag: number): Promise<CurrentAuthorityPreservationInventoryV1OriginState> {
  const n = io.uint(await read(p, d, "originCount", [planId], tag));
  if (n > BigInt(MAX_ORIGINS)) throw Error("Origin count exceeds source bound");
  const origins: Origin[] = [];
  for (let i = 0n; i < n; i++) origins.push(inv.normalizeCurrentAuthorityPreservationInventoryV1Origin(await read(p, d, "originAt", [planId, i], tag)));
  const runtimeCursor = io.uint(await read(p, d, "originRuntimeCursor", [planId], tag));
  const setHash = io.hash(await read(p, d, "originSetHash", [planId], tag), true);
  const records: { itemHash: Hex; original: RecordOrigin }[] = [];
  if (progress(plan).collectionId === 0n) {
    if (n !== 0n || runtimeCursor !== 0n || setHash !== io.ZERO) throw Error("Nondefault absent origin state");
    return { origins, runtimeCursor, setHash, records };
  }
  if (!origins.length || runtimeCursor > n) throw Error("Invalid retained origin cursor/count");
  io.equal(origins[0], selection.selection.origin, "First origin differs from retained authority");
  const art = source(c).artist;
  const presented = origins.find(o => o.environment.registry === art.registry && o.registryCodeHash === art.registryCodeHash);
  if (!presented) throw Error("Locked presentation origin missing");
  const expected = [...deduplicateOrigins([selection.selection.origin, presented])];
  for (const item of segments.flatMap(s => s.items).filter(item => isOriginItem(d.scopeKind, item))) {
    const itemHash = inv.currentAuthorityPreservationInventoryV1ItemHash(item);
    const original = inv.normalizeCurrentAuthorityPreservationInventoryV1RecordOrigin(await read(p, d, "artistArchiveOrigin", [planId, itemHash], tag));
    validateOriginItem(d, c, progress(plan).sourceContextHash, item, original);
    const previous = records.find(r => r.itemHash === itemHash);
    if (previous) io.equal(previous.original, original, "Repeated original record conflicts");
    else records.push({ itemHash, original });
    expected.splice(0, expected.length, ...deduplicateOrigins([...expected, original.producer]));
  }
  io.equal(origins, expected, "Origin table order/admission differs from retained Item records");
  const runtimeSegments = segments.filter(s => s.items[0]?.role === id("ARTIST_ORIGIN_REGISTRY_RUNTIME"));
  if (runtimeSegments.length !== Number(runtimeCursor)) throw Error("Origin runtime cursor differs from event segments");
  for (let i = 0; i < runtimeSegments.length; i++) io.equal(runtimeSegments[i]!.items, runtimeItems(origins[i]!, BigInt(i), runtimeSegments[i]!.items.map(row => row.byteSize)), "Origin runtime rows differ");
  const completed = progress(plan).renderCriticalEvidenceHash !== io.ZERO;
  if (completed) {
    if (runtimeCursor !== n) throw Error("Incomplete origin runtime materialization");
    io.equal(setHash, inv.currentAuthorityPreservationInventoryV1OriginSetHash(origins), "Sealed origin root differs");
  } else if (setHash !== io.ZERO) throw Error("Unsealed plan has a sealed origin root");
  return { origins, runtimeCursor, setHash, records };
}
function emptyItem(): Item { return zero(ParamType.from(inv.CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_ITEM_TUPLE)) as Item; }
function runtimeItems(o: Origin, index: bigint, sizes: readonly bigint[]): readonly Item[] {
  const original = inv.currentAuthorityPreservationInventoryV1OriginEnvironmentHash(o.environment);
  const witness = inv.currentAuthorityPreservationInventoryV1OriginPinHash(o);
  const pins = originPins(o);
  if (sizes.length !== 10 || sizes.some(size => size === 0n || size > BigInt(io.MAX_RUNTIME))) throw Error("Origin runtime length differs");
  return pins.map((pin, i) => inv.normalizeCurrentAuthorityPreservationInventoryV1Item({ ...emptyItem(), kind: 1n,
    role: id(i === 0 ? "ARTIST_ORIGIN_REGISTRY_RUNTIME" : i === 1 ? "ARTIST_ORIGIN_COORDINATOR_RUNTIME" : i === 2 ? "ARTIST_ORIGIN_ARCHIVE_RUNTIME" : "ARTIST_ORIGIN_OWNER_RUNTIME") as Hex,
    source: pin.address, sourceRecord: original, sourceIndex: i < 3 ? index : BigInt(i - 3), algorithm: 1n,
    canonicalizationId: id("RAW_BYTES") as Hex, digest: pin.codeHash, byteSize: sizes[i]!, provenanceHash: witness }));
}
function retainedJoins(d: CurrentAuthorityPreservationInventoryV1HistoryDeployment, originalAnchor: Dependencies, planId: Hex,
  plan: Plan, c: Context, selected: inv.CurrentAuthorityPreservationInventoryV1Capture, state: CurrentAuthorityPreservationInventoryV1OriginState, dependencyHash: Hex) {
  inv.validateCurrentAuthorityPreservationInventoryV1Context(coordinates(d), c);
  const s = source(c), co = common(c), scope = scopeOf(c), saved = progress(plan);
  io.equal(selected.dependencies, inv.currentAuthorityPreservationInventoryV1CaptureDependencies(originalAnchor, selected.selection), "Retained captured dependencies differ");
  if (s.content.preservationProfile !== FAMILY || s.outputs.preservationProfile !== FAMILY || co.tokenCount === 0n
    || s.membership.tokenCount !== co.tokenCount || s.content.tokenCount !== co.tokenCount || s.selection.tokenCount !== co.tokenCount
    || s.outputs.tokenCount !== co.tokenCount || scope.collectionId !== saved.collectionId || saved.subject !== co.subject
    || saved.artistId !== co.artistId || saved.tokenCount !== co.tokenCount || saved.nextToken > saved.tokenCount
    || s.artist.artistId !== co.artistId || co.conservation.association.artistId !== co.artistId) throw Error("Retained complete V2 source joins differ");
  if (d.scopeKind === "collection" ? scope.scopeType !== 0n : ![1n, 2n, 3n].includes(scope.scopeType)) throw Error("Unsupported retained scope");
  if ("scope" in plan) io.equal(plan.scope, scope, "Retained full scope differs");
  io.equal(s.scope, scope, "Snapshot source full scope differs");
  io.equal({ artistId: s.artist.artistId, generation: s.artist.bindingGeneration, bindingHash: s.artist.bindingHash, identityRecordHash: s.artist.identityRecordHash }, co.conservation.association, "Locked Artist association differs");
  io.equal(s.content.scope, scope, "Content full scope differs"); io.equal(s.outputs.scope, scope, "Output full scope differs"); io.equal(s.selection.scope, scope, "Selection full scope differs");
  if (scope.scopeType === 1n && co.tokenCount !== 1n) throw Error("TOKEN membership must contain one token");
  const art = s.artist;
  const presented = state.origins.find(o => o.environment.registry === art.registry && o.registryCodeHash === art.registryCodeHash);
  if (!presented) throw Error("Presentation origin missing");
  const line = lineage(selected.dependencies, c, selected.selection.origin, presented);
  const hash = inv.currentAuthorityPreservationInventoryV1ContextHash(selected, contextHash(d.scopeKind, c), line);
  io.equal(saved.sourceContextHash, hash, "Retained context/lineage commitment differs");
  io.equal(inv.currentAuthorityPreservationInventoryV1PlanId(coordinates(d), dependencyHash, hash), planId, "Retained plan identity differs");
  return line;
}
function completedEvidence(d: CurrentAuthorityPreservationInventoryV1HistoryDeployment, depHash: Hex, selected: inv.CurrentAuthorityPreservationInventoryV1Capture,
  planId: Hex, c: Context, plan: Plan, origins: readonly Origin[]): Evidence {
  const co = common(c), saved = progress(plan);
  const inventory: inv.CurrentAuthorityPreservationInventoryV1CollectionEvidence = {
    planId, collectionId: scopeOf(c).collectionId, scopeSubject: co.subject, artistId: co.artistId,
    originals: { rootRecordHash: co.rootRecordHash, snapshotRecordHash: c.snapshot.recordHash, referenceRenderRecordHash: c.referenceRender.observation.recordHash,
      intentRecordHash: co.conservation.record.kind === 1n ? co.conservation.record.recordHash : io.ZERO,
      intentWaiverRecordHash: co.conservation.record.kind === 2n ? co.conservation.record.recordHash : io.ZERO,
      interviewEvidenceHash: co.interviewEvidenceHash, rightsStatementRecordHash: co.descriptions.rightsStatementRecordHash, workDescriptionRecordHash: co.descriptions.workDescriptionRecordHash },
    sourceContextHash: saved.sourceContextHash, tokenInventoryHash: co.tokenInventoryHash, tokenCount: co.tokenCount,
    segmentCount: saved.segmentCount, itemCount: saved.itemCount, segmentChainHash: saved.segmentChainHash, renderCriticalEvidenceHash: io.ZERO
  };
  const value: Evidence = d.scopeKind === "collection" ? inventory : { scope: scopeOf(c), inventory };
  const hash = inv.currentAuthorityPreservationInventoryV1EvidenceHash(coordinates(d), depHash, selected.selection.selectionHash, value,
    inv.currentAuthorityPreservationInventoryV1OriginSetHash(origins), BigInt(origins.length));
  return inv.normalizeCurrentAuthorityPreservationInventoryV1Evidence(d.scopeKind, d.scopeKind === "collection" ? { ...inventory, renderCriticalEvidenceHash: hash }
    : { scope: scopeOf(c), inventory: { ...inventory, renderCriticalEvidenceHash: hash } });
}
function evidenceHash(value: Evidence) { return "inventory" in value ? value.inventory.renderCriticalEvidenceHash : value.renderCriticalEvidenceHash; }
function definitionStart(plan: Plan, segments: readonly CurrentAuthorityPreservationInventoryV1SegmentObservation[]): number {
  if (!("progress" in plan)) return 7;
  let i = 0;
  for (const count of [plan.nativeCount, plan.referenceCount]) {
    let total = 0n;
    while (total < count && i < segments.length) total += segments[i++]!.segment.itemCount;
    if (count === 0n || total !== count) throw Error("Native/reference page partition differs");
  }
  return i + 5;
}

function originalContext(c: Context) {
  if ("records" in c) return c.records;
  return { ...zero(ParamType.from(workers.scoped.originals.inputs[1])) as Record<string, unknown>, collectionId: c.scope.collectionId, subject: c.subject };
}
function relabelNative(items: readonly Item[]): readonly Item[] {
  return items.map(item => {
    if (item.kind !== 1n) return item;
    const named = [["ORIGINAL_ARTIST_DEPENDENCY_RUNTIME", "CURRENT_ARTIST_DEPENDENCY_RUNTIME"],
      ["ORIGINAL_ARTIST_CONTENT_OWNER_RUNTIME", "CURRENT_ARTIST_CONTENT_OWNER_RUNTIME"], ["ORIGINAL_ARTIST_CONTENT_OWNER", "CURRENT_ARTIST_CONTENT_OWNER"]] as const;
    for (const [old, next] of named) if (item.role === id(old)) return { ...item, role: id(next) as Hex };
    for (let i = 0; i < 5; i++) if (item.role === keccak256(coder.encode(["string", "uint256"], ["ORIGINAL_ARTIST_DEPENDENCY_V2", i]))) {
      return { ...item, role: keccak256(coder.encode(["string", "uint256"], ["CURRENT_ARTIST_DEPENDENCY_V2", i])) as Hex };
    }
    return item;
  });
}
async function documentChecks(p: io.Reader, d: CurrentAuthorityPreservationInventoryV1Deployment, deps: Dependencies,
  items: readonly Item[], tag: number, cap: bigint): Promise<readonly CurrentAuthorityPreservationInventoryV1DocumentPin[]> {
  const pins: CurrentAuthorityPreservationInventoryV1DocumentPin[] = [];
  for (const item of items) {
    if (item.kind !== 3n) continue;
    const actual = inv.normalizeCurrentAuthorityPreservationInventoryV1Item((await computation(p, d, "documents", "document", [deps, item.catalogId, item.catalogHash], tag, cap))[0] as Item);
    if (actual.kind !== 3n || actual.catalogId !== item.catalogId || actual.catalogHash !== item.catalogHash || actual.byteSize !== item.byteSize || actual.digest !== item.digest) throw Error("Complete document bytes differ");
    io.hash(actual.provenanceHash);
    const prior = pins.find(row => row.id === item.catalogId);
    if (prior) io.equal(prior.factsHash, actual.provenanceHash, "Repeated document facts differ");
    else pins.push({ id: item.catalogId, factsHash: actual.provenanceHash });
  }
  return pins;
}
async function predictedStage(p: io.ReceiptReader, d: CurrentAuthorityPreservationInventoryV1Deployment,
  prepared: inv.CurrentAuthorityPreservationInventoryV1Call, bound: Awaited<ReturnType<typeof liveBindings>>, c: Context, line: Hex,
  planId: Hex, before: Plan, tokenBefore: inv.CurrentAuthorityPreservationInventoryV1TokenProgress,
  originsBefore: CurrentAuthorityPreservationInventoryV1OriginState, initialOrigins: readonly Origin[],
  segments: readonly CurrentAuthorityPreservationInventoryV1SegmentObservation[], tag: number, cap: bigint): Promise<CurrentAuthorityPreservationInventoryV1Stage> {
  const q = prepared.request;
  const after = structuredClone(before) as Mutable<Plan>;
  const aft = ("progress" in after ? after.progress : after) as Mutable<Progress>;
  const saved = progress(before), co = common(c), deps = bound.selection.dependencies;
  const tokenAfter = structuredClone(tokenBefore) as Mutable<typeof tokenBefore>;
  const originsAfter: { origins: Origin[]; runtimeCursor: bigint; setHash: Hex; records: { itemHash: Hex; original: RecordOrigin }[] } = {
    origins: [...originsBefore.origins], runtimeCursor: originsBefore.runtimeCursor, setHash: originsBefore.setHash, records: [...originsBefore.records]
  };
  const existing = saved.collectionId !== 0n;
  let appended: CurrentAuthorityPreservationInventoryV1Stage["appended"] = null;
  let evidence: Evidence | null = null;
  let documents: readonly CurrentAuthorityPreservationInventoryV1DocumentPin[] = [];
  const result = () => io.freeze({ ...bound, planId, context: c, lineageHash: line, before, after: inv.normalizeCurrentAuthorityPreservationInventoryV1Plan(d.scopeKind, after),
    tokenBefore, tokenAfter: inv.normalizeCurrentAuthorityPreservationInventoryV1TokenProgress(tokenAfter), originsBefore, originsAfter,
    segments, documents, appended, evidence, existing });
  if (q.kind === "beginInventory") {
    if (!existing) {
      Object.assign(aft, { collectionId: scopeOf(c).collectionId, subject: co.subject, artistId: co.artistId,
        sourceContextHash: inv.currentAuthorityPreservationInventoryV1ContextHash(bound.selection, contextHash(d.scopeKind, c), line), tokenCount: co.tokenCount });
      if ("scope" in after) after.scope = structuredClone(scopeOf(c));
      originsAfter.origins = [...initialOrigins];
    }
    return result();
  }
  if (!existing || saved.renderCriticalEvidenceHash !== io.ZERO) throw Error("Inventory missing or already sealed");
  const expectedStage = q.kind === "appendNative" ? 0n : q.kind === "appendReference" ? 1n : q.kind === "appendWork" ? 2n : q.kind === "appendRights" ? 3n
    : q.kind === "appendIntent" || q.kind === "appendIntentWaiver" ? 4n : q.kind === "appendInterview" || q.kind === "appendInterviewWaiver" ? 5n
      : q.kind === "appendRootAuthorization" ? 6n : q.kind === "appendDefinition" ? 7n : 8n;
  if (saved.completedStages !== expectedStage) throw Error("Wrong inventory stage");
  let items: readonly Item[] = [], witness = io.ZERO;
  const remember = async (item: Item, original: RecordOrigin, actor: Address, expectedReceipt: Hex) => {
    validateOriginItem(d, c, saved.sourceContextHash, item, original);
    if (original.actor !== actor || (expectedReceipt !== io.ZERO && original.occurrence.receipt.recordHash !== expectedReceipt) || originsAfter.runtimeCursor !== 0n || originsAfter.setHash !== io.ZERO) throw Error("Original actor/receipt or origin admission phase differs");
    await io.runtimes(p, originPins(original.producer), tag);
    originsAfter.origins = [...deduplicateOrigins([...originsAfter.origins, original.producer])];
    const itemHash = inv.currentAuthorityPreservationInventoryV1ItemHash(item);
    const old = originsAfter.records.find(row => row.itemHash === itemHash);
    if (old) io.equal(old.original, original, "Repeated record origin differs");
    else originsAfter.records.push({ itemHash, original: structuredClone(original) });
  };
  const artistRow = async (publication: ReturnType<typeof common>["conservation"]["record"]["publication"], recordHash: Hex,
    actor: Address, receipt: inv.CurrentAuthorityPreservationInventoryV1ReceiptWitness) => {
    if (actor === io.ZERO_ADDRESS) throw Error("Attested publication requires original actor");
    const r = await io.rpc(p, bound.originDependencies.worker, originAbi, "publicationItem", [deps, publication, recordHash, actor, saved.sourceContextHash, receipt], tag, undefined, bound.originDependencies.originGas);
    const item = inv.normalizeCurrentAuthorityPreservationInventoryV1Item(r[0] as Item);
    const original = inv.normalizeCurrentAuthorityPreservationInventoryV1RecordOrigin(r[1] as RecordOrigin);
    await remember(item, original, actor, publication.attestationRecordHash);
    return item;
  };
  const originalRows = async (record: Hex, payload: Hex) => rows((await computation(p, d, "originals", "originals", [deps, originalContext(c), record, payload], tag, cap))[0]);
  const typed = async (method: "work" | "rights" | "intent" | "waiver" | "interview", record: Hex, payload: Hex, value: unknown) => rows((await computation(p, d, "typedReferences", method, [deps.targets[1], record, payload, value], tag, cap))[0]);
  if (q.kind === "appendNative" || q.kind === "appendReference") {
    const native = q.kind === "appendNative";
    const arg = native || d.scopeKind === "collection" ? c : { scope: scopeOf(c), subject: co.subject, artistId: co.artistId, snapshot: c.snapshot, referenceRender: c.referenceRender };
    if ("progress" in before && "progress" in after && "maxChunks" in q) {
      const cursor = native ? before.nativeCursor : before.referenceCursor;
      const r = await computation(p, d, native ? "native" : "reference", native ? "native" : "reference", [deps, arg, cursor, q.maxChunks, FAMILY], tag, cap);
      items = rows(r[0]);
      const total = io.uint(r[1], 64);
      if (total > BigInt(MAX_ITEMS) || cursor >= total || items.length === 0 || BigInt(items.length) !== (total - cursor < q.maxChunks ? total - cursor : q.maxChunks)
        || (cursor !== 0n && total !== (native ? before.nativeCount : before.referenceCount))) throw Error("Page cursor/count differs");
      witness = keccak256(coder.encode(["bytes32", "uint64", "uint64"], [saved.sourceContextHash, cursor, total])) as Hex;
      if (native) { after.nativeCount = total; after.nativeCursor = cursor + BigInt(items.length); }
      else { after.referenceCount = total; after.referenceCursor = cursor + BigInt(items.length); }
      if (cursor + BigInt(items.length) === total) aft.completedStages++;
    } else {
      items = rows((await computation(p, d, native ? "native" : "reference", native ? "native" : "reference", [deps, arg, FAMILY], tag, cap))[0]);
      witness = native ? saved.sourceContextHash : c.referenceRender.observation.recordHash;
      aft.completedStages++;
    }
    if (native) items = relabelNative(items);
  } else if (q.kind === "appendWork") {
    const refs = await typed("work", co.descriptions.workDescriptionRecordHash, co.descriptions.workPayloadHash, q.witness);
    await computation(p, d, "documents", "catalogs", [deps, refs], tag, cap);
    const originals = [...await originalRows(co.descriptions.workDescriptionRecordHash, co.descriptions.workPayloadHash)];
    const selected = await io.read<{ recordHash: Hex; selectionHash: Hex; artistPublication: ReturnType<typeof common>["conservation"]["record"]["publication"] }>(p, deps.targets[7], workAbi, "workSelectionAt", [scopeOf(c).collectionId, co.subject, co.descriptions.workRevision], tag, undefined, deps.readGas);
    if (selected.recordHash !== co.descriptions.workDescriptionRecordHash || selected.selectionHash !== co.descriptions.workSelectionHash) throw Error("Actual Work selection differs");
    if (selected.artistPublication.attestationRecordHash !== io.ZERO) originals.push(await artistRow(selected.artistPublication, selected.recordHash, q.originalActor, q.receipt));
    else if (q.originalActor !== io.ZERO_ADDRESS || q.receipt.lane !== 0n || q.receipt.index !== 0n) throw Error("Unattested Work requires zero actor and native zero witness");
    items = [...originals, ...refs]; witness = co.descriptions.workSelectionHash; aft.completedStages = 3n;
  } else if (q.kind === "appendRights") {
    items = [...await originalRows(co.descriptions.rightsStatementRecordHash, co.descriptions.rightsPayloadHash), ...await typed("rights", co.descriptions.rightsStatementRecordHash, co.descriptions.rightsPayloadHash, q.witness)];
    witness = co.descriptions.rightsSelectionHash; aft.completedStages = 4n;
  } else if (q.kind === "appendIntent" || q.kind === "appendIntentWaiver" || q.kind === "appendInterview") {
    const interview = q.kind === "appendInterview", record = interview ? co.conservation.interview : co.conservation.record;
    if ((interview && co.conservation.interviewStatus !== 0n) || (!interview && record.kind !== (q.kind === "appendIntent" ? 1n : 2n))) throw Error("Wrong selected conservation branch");
    const refs = await typed(interview ? "interview" : q.kind === "appendIntent" ? "intent" : "waiver", record.recordHash, record.payloadHash, q.witness);
    if (interview) await computation(p, d, "documents", "catalogs", [deps, refs], tag, cap);
    items = [...await originalRows(record.recordHash, record.payloadHash), await artistRow(record.publication, record.recordHash, q.originalActor, q.receipt), ...refs];
    witness = interview ? co.interviewEvidenceHash : co.conservation.selectionHash; aft.completedStages = interview ? 6n : 5n;
  } else if (q.kind === "appendInterviewWaiver") {
    if (co.conservation.interviewStatus !== 1n || co.conservation.interview.recordHash !== io.ZERO) throw Error("Interview is not explicitly waived");
    items = [{ ...emptyItem(), kind: 7n, role: id("INTERVIEW_ORIGINAL_EXPLICITLY_WAIVED") as Hex, source: deps.targets[1], sourceRecord: co.conservation.record.recordHash, provenanceHash: co.interviewEvidenceHash }];
    witness = co.interviewEvidenceHash; aft.completedStages = 6n;
  } else if (q.kind === "appendRootAuthorization") {
    const args = [deps, c, q.originalActor, q.observedAt, q.aggregate, ...("originalLegacyFamilyHash" in q ? [q.originalLegacyFamilyHash] : []), saved.sourceContextHash, q.receipt];
    const r = await computation(p, d, "root", "root", args, tag, cap);
    const item = inv.normalizeCurrentAuthorityPreservationInventoryV1Item(r[0] as Item);
    const original = inv.normalizeCurrentAuthorityPreservationInventoryV1RecordOrigin(r[1] as RecordOrigin);
    if (item.role !== rootRole(d.scopeKind)) throw Error("Wrong root authorization role");
    await remember(item, original, q.originalActor, io.ZERO);
    items = [item]; witness = co.rootRecordHash; aft.completedStages = 7n;
  } else if (q.kind === "appendDefinition") {
    const start = definitionStart(before, segments), index = segments.length - start;
    if (index < 0 || index >= 31 || segments[start - 1]?.segment.sourceWitnessHash !== co.rootRecordHash) throw Error("Definition stage partition differs");
    const [documentId, expectedHash] = await computation(p, d, "definitions", "definition", [BigInt(index), FAMILY], tag, cap);
    const known = inv.currentAuthorityPreservationInventoryV1Definition(d.scopeKind, BigInt(index));
    io.equal(documentId, known.id, "Fixed definition ID differs"); io.equal(expectedHash, known.hash, "Fixed definition hash differs");
    items = [inv.normalizeCurrentAuthorityPreservationInventoryV1Item((await computation(p, d, "documents", "document", [deps, documentId, expectedHash], tag, cap))[0] as Item)];
    if (items[0]!.kind !== 3n || items[0]!.catalogId !== documentId || items[0]!.catalogHash !== expectedHash) throw Error("Definition item identity differs");
    witness = keccak256(coder.encode(["bytes32", inv.CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_ITEM_TUPLE], [documentId, items[0]])) as Hex;
    if (index === 30) aft.completedStages = 8n;
  } else if (q.kind === "appendOriginRuntime" || q.kind === "sealInventory") {
    if (saved.nextToken !== saved.tokenCount || tokenBefore.phase !== 0n || tokenBefore.row !== 0n || tokenBefore.count !== 0n) throw Error("Token materialization incomplete");
    if (q.kind === "sealInventory") {
      if (originsBefore.runtimeCursor !== BigInt(originsBefore.origins.length)) throw Error("Origin runtime materialization incomplete");
      await io.runtimes(p, originsBefore.origins.flatMap(originPins), tag);
      originsAfter.setHash = inv.currentAuthorityPreservationInventoryV1OriginSetHash(originsBefore.origins);
      evidence = completedEvidence(d, bound.dependencyHash, bound.selection, planId, c, before, originsBefore.origins);
      aft.renderCriticalEvidenceHash = evidenceHash(evidence);
      return result();
    }
    if (originsBefore.runtimeCursor >= BigInt(originsBefore.origins.length)) throw Error("Origin runtime cursor exhausted");
    const origin = originsBefore.origins[Number(originsBefore.runtimeCursor)]!;
    const sizes: bigint[] = [];
    for (const pin of originPins(origin)) { await io.runtime(p, pin, tag); sizes.push(BigInt((io.bytes(await p.getCode(pin.address, tag), io.MAX_RUNTIME).length - 2) / 2)); }
    items = runtimeItems(origin, originsBefore.runtimeCursor, sizes);
    witness = inv.currentAuthorityPreservationInventoryV1OriginPinHash(origin);
    originsAfter.runtimeCursor++;
  } else {
    const ordinal = saved.nextToken, phase = tokenBefore.phase;
    if (ordinal >= saved.tokenCount) throw Error("Token cursor exhausted");
    const output = q.kind === "appendToken" || q.kind === "appendTokenOutput";
    const script = q.kind === "appendScript" || q.kind === "appendTokenScript";
    const library = q.kind === "appendLibrary" || q.kind === "appendTokenLibrary";
    const renderer = q.kind === "appendRenderer" || q.kind === "appendTokenRenderer";
    const preservation = q.kind === "appendTokenPreservation";
    const expectedPhase = output ? 0n : script ? 1n : library ? 2n : renderer ? 3n : preservation ? 5n : 4n;
    if (phase !== expectedPhase) throw Error("Wrong token phase");
    let row = 0n, count = 0n;
    if (output && "payload" in q) {
      items = rows((await computation(p, d, "token", "token", [deps, c, ordinal, q.payload], tag, cap))[0]);
      count = d.scopeKind === "collection" ? 0n : BigInt(items.length); tokenAfter.phase = 1n;
    } else if (script || library) {
      items = rows((await computation(p, d, "script", "script", [deps, c, ordinal, library], tag, cap))[0]);
      count = d.scopeKind === "collection" ? 0n : BigInt(items.length); tokenAfter.phase++;
    } else {
      row = tokenBefore.row;
      let r: readonly unknown[];
      if (preservation) {
        const original = (await computation(p, d, "token", "tokenSource", [deps, c, ordinal], tag, cap))[1] as { selection: unknown; output: unknown };
        r = await computation(p, d, "preservation", "preservation", [deps, content(c), original.selection, original.output, row], tag, cap);
      } else r = await computation(p, d, renderer ? "renderer" : "profile", renderer ? "renderer" : "profile", [deps, c, ordinal, row], tag, cap);
      items = [inv.normalizeCurrentAuthorityPreservationInventoryV1Item(r[0] as Item)]; count = io.uint(r[1], 64);
      if (count === 0n || count > BigInt(MAX_ITEMS) || row >= count || (row !== 0n && tokenBefore.count !== count)) throw Error("Token row count differs");
      tokenAfter.count = count; tokenAfter.row++;
      if (tokenAfter.row === count) { tokenAfter.row = 0n; tokenAfter.count = 0n; if (phase === 5n) { tokenAfter.phase = 0n; aft.nextToken++; } else tokenAfter.phase++; }
    }
    witness = keccak256(coder.encode(["bytes32", "bytes32", "bytes32", "uint64", "uint8", "uint64", "uint64"], [id(d.scopeKind === "collection" ? "6529STREAM_PRESERVATION_POLICY_TOKEN_STAGE_V1" : "6529STREAM_SCOPED_PRESERVATION_POLICY_TOKEN_INVENTORY_SOURCE_V1"), co.checkpointHash, content(c).selectionHash, ordinal, phase, row, count])) as Hex;
  }
  if (items.length === 0) throw Error("Concrete inventory producer returned an empty segment");
  if (d.scopeKind === "collection") documents = await documentChecks(p, d, deps, items, tag, cap);
  else if (expectedStage === 7n || (expectedStage === 8n && tokenBefore.phase >= 3n && q.kind !== "appendOriginRuntime")) {
    documents = items.filter(item => item.kind === 3n).map(item => ({ id: io.hash(item.catalogId), factsHash: io.hash(item.provenanceHash) }));
  }
  const segment = inv.currentAuthorityPreservationInventoryV1Segment(inv.currentAuthorityPreservationInventoryV1SegmentKey(d.scopeKind, planId, saved.segmentCount), witness, items);
  appended = { segment, items };
  aft.segmentChainHash = inv.currentAuthorityPreservationInventoryV1AppendSegment(saved.segmentChainHash, saved.segmentCount, segment);
  aft.segmentCount++; aft.itemCount += BigInt(items.length);
  if (aft.itemCount > BigInt(MAX_ITEMS)) throw Error("Total Item client allocation limit exceeded");
  return result();
}

async function originalCall(p: io.Reader, d: CurrentAuthorityPreservationInventoryV1Deployment, prepared: inv.CurrentAuthorityPreservationInventoryV1Call,
  stage: CurrentAuthorityPreservationInventoryV1Stage, tag: number, cap: bigint): Promise<Hex> {
  const raw = io.bytes(await p.call({ ...prepared.call, from: prepared.caller, blockTag: tag, gasLimit: cap }));
  const iface = host(d.scopeKind), method = prepared.request.kind;
  const parsed = iface.decodeFunctionResult(method, raw);
  if (!io.same(iface.encodeFunctionResult(method, parsed), raw)) throw Error("Noncanonical original call result");
  if (method === "beginInventory") io.equal(parsed[0], stage.planId, "Original host plan differs");
  if (method === "sealInventory") io.equal(inv.decodeCurrentAuthorityPreservationInventoryV1Evidence(d.scopeKind, raw), stage.evidence, "Original sealed evidence differs");
  return raw;
}
export async function captureCurrentAuthorityPreservationInventoryV1(
  p: io.ReceiptReader, inputDeployment: CurrentAuthorityPreservationInventoryV1Deployment, inputCaller: Address,
  inputRequest: inv.CurrentAuthorityPreservationInventoryV1Request,
  options: { readonly blockTag: number; readonly gasLimit: bigint; readonly segments: readonly CurrentAuthorityPreservationInventoryV1SegmentLocator[] }
): Promise<CurrentAuthorityPreservationInventoryV1WorkflowCapture> {
  const d = deployment(inputDeployment);
  const prepared = inv.prepareCurrentAuthorityPreservationInventoryV1Call(coordinates(d), io.address(inputCaller), inputRequest);
  io.keys(options, ["blockTag", "gasLimit", "segments"]);
  const tag = io.number(options.blockTag), cap = io.gas(options.gasLimit), savedLocators = locators(options.segments);
  const observed = await io.chain(p, d.chainId, tag);
  const bound = await liveBindings(p, d, tag, cap);
  const q = prepared.request;
  let scope: inv.CurrentAuthorityPreservationInventoryV1Scope;
  if (q.kind === "beginInventory") scope = "scope" in q ? q.scope : { scopeType: 0n, collectionId: q.collectionId, tokenId: 0n, scopeId: io.ZERO };
  else {
    const old = inv.normalizeCurrentAuthorityPreservationInventoryV1Plan(d.scopeKind, await read(p, d, "plan", [q.planId], tag));
    if (progress(old).collectionId === 0n) throw Error("Unknown inventory plan");
    scope = "scope" in old ? old.scope : { scopeType: 0n, collectionId: old.collectionId, tokenId: 0n, scopeId: io.ZERO };
  }
  const sourceResult = await computation(p, d, "source", "source", [bound.selection.dependencies, bound.originDependencies, d.scopeKind === "collection" ? scope.collectionId : scope], tag, cap);
  const context = inv.normalizeCurrentAuthorityPreservationInventoryV1Context(d.scopeKind, sourceResult[0] as Context);
  const current = inv.normalizeCurrentAuthorityPreservationInventoryV1Origin(sourceResult[1] as Origin);
  const presented = inv.normalizeCurrentAuthorityPreservationInventoryV1Origin(sourceResult[2] as Origin);
  const line = io.hash(sourceResult[3]);
  io.equal(current, bound.selection.selection.origin, "Source current origin differs from resolver selection");
  io.equal(scopeOf(context), scope, "Current source full scope differs");
  io.equal(line, lineage(bound.selection.dependencies, context, current, presented), "Source lineage hash differs");
  const initialOrigins = deduplicateOrigins([current, presented]);
  await io.runtimes(p, initialOrigins.flatMap(originPins), tag);
  const sourceHash = inv.currentAuthorityPreservationInventoryV1ContextHash(bound.selection, contextHash(d.scopeKind, context), line);
  const planId = inv.currentAuthorityPreservationInventoryV1PlanId(coordinates(d), bound.dependencyHash, sourceHash);
  if (q.kind !== "beginInventory" && q.planId !== planId) throw Error("Retained inventory source/authority is stale");
  // Actual permissionless begin is the current plan authority; no current-plan getter is invented.
  io.equal(await io.read(p, d.inventory.address, host(d.scopeKind), "beginInventory", [d.scopeKind === "collection" ? scope.collectionId : scope], tag, prepared.caller, cap), planId, "Original current plan differs");
  const before = inv.normalizeCurrentAuthorityPreservationInventoryV1Plan(d.scopeKind, await read(p, d, "plan", [planId], tag));
  const tokenBefore = inv.normalizeCurrentAuthorityPreservationInventoryV1TokenProgress(await read(p, d, "tokenProgress", [planId], tag));
  const segments = await segmentHistory(p, hd(d), planId, before, savedLocators, tag);
  const originsBefore = await originState(p, hd(d), planId, context, before, segments, bound.selection, tag);
  if (progress(before).collectionId === 0n) {
    io.equal(before, emptyPlan(d.scopeKind), "Nondefault missing plan"); io.equal(tokenBefore, ZERO_TOKEN, "Nondefault missing token cursor");
    const hypothetical = structuredClone(before) as Mutable<Plan>;
    const hp = "progress" in hypothetical ? hypothetical.progress : hypothetical;
    Object.assign(hp, { collectionId: scope.collectionId, subject: common(context).subject, artistId: common(context).artistId, sourceContextHash: sourceHash, tokenCount: common(context).tokenCount });
    if ("scope" in hypothetical) hypothetical.scope = structuredClone(scope);
    retainedJoins(d, bound.originalAnchor, planId, hypothetical, context, bound.selection, { origins: initialOrigins, runtimeCursor: 0n, setHash: io.ZERO, records: [] }, bound.dependencyHash);
  } else {
    io.equal(await read(p, d, "sourceContext", [planId], tag), context, "Stored source differs from current full context");
    io.equal(await read(p, d, "authoritySelection", [planId], tag), bound.selection, "Stored authority selection differs");
    retainedJoins(d, bound.originalAnchor, planId, before, context, bound.selection, originsBefore, bound.dependencyHash);
  }
  const stage = await predictedStage(p, d, prepared, bound, context, line, planId, before, tokenBefore, originsBefore, initialOrigins, segments, tag, cap);
  // This also checks private saved document facts at seal and exact original JSON/Archive predicates.
  // Independent worker success never substitutes for the complete host call or its nested gas budget.
  await originalCall(p, d, prepared, stage, tag, cap);
  await io.unchanged(p, observed);
  const value = { deployment: d, prepared, observed, gasLimit: cap, stage };
  return io.freeze({ ...value, captureHash: io.fingerprint(value) });
}
function snapshotCapture(input: CurrentAuthorityPreservationInventoryV1WorkflowCapture): CurrentAuthorityPreservationInventoryV1WorkflowCapture {
  io.keys(input, ["deployment", "prepared", "observed", "gasLimit", "stage", "captureHash"]);
  const value = structuredClone(input), { captureHash, ...body } = value;
  io.equal(io.hash(captureHash), io.fingerprint(body), "Capture fingerprint differs");
  const d = deployment(value.deployment), prepared = inv.normalizeCurrentAuthorityPreservationInventoryV1Call(value.prepared);
  io.equal(prepared.coordinates, coordinates(d), "Saved call/deployment differs");
  io.gas(value.gasLimit); io.number(value.observed.blockNumber); io.hash(value.observed.blockHash); io.uint(value.observed.timestamp);
  return io.freeze({ ...value, deployment: d, prepared });
}
function comparable(v: CurrentAuthorityPreservationInventoryV1WorkflowCapture) { return { deployment: v.deployment, prepared: v.prepared, gasLimit: v.gasLimit, stage: v.stage }; }
async function revalidate(p: io.ReceiptReader, saved: CurrentAuthorityPreservationInventoryV1WorkflowCapture, tag: number) {
  await io.unchanged(p, saved.observed);
  if (tag < saved.observed.blockNumber) throw Error("Observation predates saved capture");
  const current = await captureCurrentAuthorityPreservationInventoryV1(p, saved.deployment, saved.prepared.caller, saved.prepared.request,
    { blockTag: tag, gasLimit: saved.gasLimit, segments: saved.stage.segments.map(s => s.locator) });
  io.equal(comparable(current), comparable(saved), "Saved source/progress changed; recapture");
  return current;
}
export async function simulateCurrentAuthorityPreservationInventoryV1(p: io.ReceiptReader, input: CurrentAuthorityPreservationInventoryV1WorkflowCapture,
  options: { readonly blockTag: number; readonly gasLimit: bigint }) {
  const saved = snapshotCapture(input); io.keys(options, ["blockTag", "gasLimit"]);
  const tag = io.number(options.blockTag), cap = io.gas(options.gasLimit);
  await revalidate(p, saved, saved.observed.blockNumber);
  const current = await revalidate(p, saved, tag);
  const result = await originalCall(p, current.deployment, current.prepared, current.stage, tag, cap);
  await io.unchanged(p, current.observed);
  return io.freeze({ capture: current, result, originalCallSucceeded: true as const, stateChangesPersisted: false as const, gasLimit: cap });
}
export async function inspectCurrentAuthorityPreservationInventoryV1History(p: io.ReceiptReader,
  inputDeployment: CurrentAuthorityPreservationInventoryV1HistoryDeployment, inputId: Hex,
  options: { readonly blockTag: number; readonly segments: readonly CurrentAuthorityPreservationInventoryV1SegmentLocator[] }) {
  const d = historicalDeployment(inputDeployment), planId = io.hash(inputId);
  io.keys(options, ["blockTag", "segments"]); const tag = io.number(options.blockTag), retained = locators(options.segments);
  const observed = await io.chain(p, d.chainId, tag), bound = await bindings(p, d, tag);
  const plan = inv.normalizeCurrentAuthorityPreservationInventoryV1Plan(d.scopeKind, await read(p, d, "plan", [planId], tag));
  if (progress(plan).collectionId === 0n) throw Error("Unknown inventory plan");
  const context = inv.normalizeCurrentAuthorityPreservationInventoryV1Context(d.scopeKind, await read(p, d, "sourceContext", [planId], tag));
  const selected = inv.normalizeCurrentAuthorityPreservationInventoryV1Capture(await read(p, d, "authoritySelection", [planId], tag));
  const tokenProgress = inv.normalizeCurrentAuthorityPreservationInventoryV1TokenProgress(await read(p, d, "tokenProgress", [planId], tag));
  const segments = await segmentHistory(p, d, planId, plan, retained, tag);
  const origins = await originState(p, d, planId, context, plan, segments, selected, tag);
  const lineageHash = retainedJoins(d, bound.originalAnchor, planId, plan, context, selected, origins, bound.dependencyHash);
  let evidence: Evidence | null = null;
  if (progress(plan).renderCriticalEvidenceHash !== io.ZERO) {
    evidence = inv.normalizeCurrentAuthorityPreservationInventoryV1Evidence(d.scopeKind, await read(p, d, "inventoryEvidence", [planId], tag));
    io.equal(evidence, completedEvidence(d, bound.dependencyHash, selected, planId, context, plan, origins.origins), "Retained evidence differs");
    if (progress(plan).completedStages !== 8n || progress(plan).nextToken !== progress(plan).tokenCount) throw Error("Sealed progress incomplete");
    io.equal(tokenProgress, ZERO_TOKEN, "Sealed token cursor differs");
    io.equal(progress(plan).renderCriticalEvidenceHash, evidenceHash(evidence), "Plan/evidence commitment differs");
  }
  await io.unchanged(p, observed);
  return io.freeze({ observed, planId, ...bound, plan, context, selection: selected, lineageHash, tokenProgress, segments, origins, evidence,
    currentAuthorityChecked: false as const, currentSourceChecked: false as const, selectionCommitmentRecomputed: false as const,
    privateCatalogFactsIndependentlyReconstructed: false as const });
}
export async function inspectCurrentAuthorityPreservationInventoryV1Current(p: io.ReceiptReader,
  inputDeployment: CurrentAuthorityPreservationInventoryV1Deployment, inputScope: inv.CurrentAuthorityPreservationInventoryV1Scope,
  options: { readonly blockTag: number; readonly gasLimit: bigint; readonly segments: readonly CurrentAuthorityPreservationInventoryV1SegmentLocator[]; readonly fullDefinitionBytes?: boolean }) {
  const d = deployment(inputDeployment), scope = inv.normalizeCurrentAuthorityPreservationInventoryV1Scope(inputScope);
  io.keys(options, ["blockTag", "gasLimit", "segments"], ["fullDefinitionBytes"]);
  const tag = io.number(options.blockTag), cap = io.gas(options.gasLimit), retained = locators(options.segments);
  if (options.fullDefinitionBytes !== undefined && typeof options.fullDefinitionBytes !== "boolean") throw Error("Expected full definition flag");
  const full = options.fullDefinitionBytes === true;
  const request = d.scopeKind === "collection" ? { kind: "beginInventory" as const, collectionId: scope.collectionId } : { kind: "beginInventory" as const, scope };
  const capture = await captureCurrentAuthorityPreservationInventoryV1(p, d, d.inventory.address, request, { blockTag: tag, gasLimit: cap, segments: retained });
  io.equal(scopeOf(capture.stage.context), scope, "Current scope differs");
  const evidence = inv.normalizeCurrentAuthorityPreservationInventoryV1Evidence(d.scopeKind, await read(p, d, "requireCurrent", [d.scopeKind === "collection" ? scope.collectionId : scope], tag, cap));
  io.equal(evidence, completedEvidence(d, capture.stage.dependencyHash, capture.stage.selection, capture.stage.planId, capture.stage.context, capture.stage.before, capture.stage.originsBefore.origins), "Original current evidence differs");
  if (evidenceHash(evidence) !== progress(capture.stage.before).renderCriticalEvidenceHash) throw Error("Current inventory incomplete");
  await io.runtimes(p, capture.stage.originsBefore.origins.flatMap(originPins), tag);
  if (full) await io.rpc(p, d.inventory.address, host(d.scopeKind), "requireFullDefinitionBytes", [capture.stage.planId], tag, undefined, cap);
  await io.unchanged(p, capture.observed);
  return io.freeze({ capture, evidence, currentAuthorityChecked: true as const, currentSourceChecked: true as const,
    originRuntimesChecked: true as const, fullDefinitionBytesChecked: full, privateCatalogFactsIndependentlyReconstructed: false as const });
}

export async function reconcileCurrentAuthorityPreservationInventoryV1Receipt(p: io.ReceiptReader,
  input: CurrentAuthorityPreservationInventoryV1WorkflowCapture, inputHash: Hex, options: CurrentAuthorityPreservationInventoryV1ReceiptOptions) {
  const saved = snapshotCapture(input);
  const tx = await io.transport(p, { chainId: saved.deployment.chainId, caller: saved.prepared.caller, call: saved.prepared.call, observed: saved.observed }, io.hash(inputHash), options);
  await revalidate(p, saved, saved.observed.blockNumber);
  const prior = await revalidate(p, saved, tx.observed.blockNumber - 1), d = prior.deployment, stage = prior.stage, tag = tx.observed.blockNumber;
  const art = source(stage.context).artist;
  const presented = stage.originsAfter.origins.find(o => o.environment.registry === art.registry && o.registryCodeHash === art.registryCodeHash)!;
  const usedOrigins = prior.prepared.request.kind === "sealInventory" ? stage.originsAfter.origins : deduplicateOrigins([
    stage.selection.selection.origin, presented,
    ...stage.originsAfter.records.filter(row => !stage.originsBefore.records.some(old => old.itemHash === row.itemHash)).map(row => row.original.producer),
    ...(prior.prepared.request.kind === "appendOriginRuntime" ? [stage.originsBefore.origins[Number(stage.originsBefore.runtimeCursor)]!] : [])
  ]);
  await io.runtimes(p, [d.inventory, ...workerRoles.map(role => d.workers[role]), ...d.linkedDependencies,
    ...dependencyPins(stage.originalAnchor), ...dependencyPins(stage.selection.dependencies), ...usedOrigins.flatMap(originPins),
    { address: stage.originDependencies.worker, codeHash: stage.originDependencies.workerCodeHash },
    { address: stage.authorityDependencies.resolver, codeHash: stage.authorityDependencies.resolverCodeHash }], tag);
  io.equal(await read(p, d, "plan", [stage.planId], tag), stage.after, "End-block progress differs; same-block changes are not attributed");
  io.equal(await read(p, d, "tokenProgress", [stage.planId], tag), stage.tokenAfter, "End-block token cursor differs");
  io.equal(await read(p, d, "sourceContext", [stage.planId], tag), stage.context, "Retained complete context differs");
  io.equal(await read(p, d, "authoritySelection", [stage.planId], tag), stage.selection, "Retained authority capture differs");
  io.equal(await read(p, d, "originCount", [stage.planId], tag), BigInt(stage.originsAfter.origins.length), "End-block origin count differs");
  io.equal(await read(p, d, "originRuntimeCursor", [stage.planId], tag), stage.originsAfter.runtimeCursor, "End-block origin runtime cursor differs");
  io.equal(await read(p, d, "originSetHash", [stage.planId], tag), stage.originsAfter.setHash, "End-block origin root differs");
  for (let i = 0; i < stage.originsAfter.origins.length; i++) io.equal(await read(p, d, "originAt", [stage.planId, i], tag), stage.originsAfter.origins[i], "Retained origin differs");
  for (const row of stage.originsAfter.records) io.equal(await read(p, d, "artistArchiveOrigin", [stage.planId, row.itemHash], tag), row.original, "Retained original occurrence differs");
  const iface = host(d.scopeKind), started = eventName(d.scopeKind, "Started"), recorded = eventName(d.scopeKind, "SegmentRecorded"), completed = eventName(d.scopeKind, "Completed");
  const starts = io.events(tx.logs, d.inventory.address, iface, started), appends = io.events(tx.logs, d.inventory.address, iface, recorded), completes = io.events(tx.logs, d.inventory.address, iface, completed);
  const schema = d.scopeKind === "scoped" ? [1n] : [];
  let segmentLocator: CurrentAuthorityPreservationInventoryV1SegmentLocator | null = null;
  if (prior.prepared.request.kind === "beginInventory") {
    if (appends.length || completes.length || starts.length !== (stage.existing ? 0 : 1)) throw Error("Unexpected begin events");
    if (!stage.existing) io.one(tx.logs, d.inventory.address, iface, started, [...schema, stage.planId, d.scopeKind === "collection" ? scopeOf(stage.context).collectionId : scopeOf(stage.context), progress(stage.after).sourceContextHash]);
  } else if (prior.prepared.request.kind === "sealInventory") {
    if (starts.length || appends.length) throw Error("Unexpected seal events");
    io.one(tx.logs, d.inventory.address, iface, completed, [...schema, stage.planId, evidenceHash(stage.evidence!), stage.evidence]);
    io.equal(await read(p, d, "inventoryEvidence", [stage.planId], tag), stage.evidence, "Retained completed evidence differs");
  } else {
    if (starts.length || completes.length || stage.appended === null) throw Error("Unexpected append events");
    const event = io.one(tx.logs, d.inventory.address, iface, recorded, [...schema, stage.planId, progress(stage.before).segmentCount, stage.appended.segment, stage.appended.items]);
    io.equal(await read(p, d, "inventorySegment", [stage.planId, progress(stage.before).segmentCount], tag), stage.appended.segment, "Retained appended segment differs");
    segmentLocator = { transactionHash: tx.transactionHash, logIndex: event.index };
  }
  io.finish(tx.logs, [d.inventory.address], tx.safeIndex);
  await io.unchanged(p, tx.observed);
  return io.freeze({ observed: tx.observed, transactionHash: tx.transactionHash, planId: stage.planId, plan: stage.after,
    tokenProgress: stage.tokenAfter, origins: stage.originsAfter, appended: stage.appended, segmentLocator, evidence: stage.evidence,
    precedingAndEndBlockAttribution: true as const, currentAfterReceipt: false as const, privateCatalogFactsIndependentlyReconstructed: false as const });
}
export async function observeCurrentAuthorityPreservationInventoryV1Refusal(p: io.ReceiptReader,
  input: CurrentAuthorityPreservationInventoryV1WorkflowCapture, options: { readonly blockTag: number; readonly gasLimit: bigint }) {
  const saved = snapshotCapture(input); io.keys(options, ["blockTag", "gasLimit"]);
  const tag = io.number(options.blockTag), cap = io.gas(options.gasLimit);
  await revalidate(p, saved, saved.observed.blockNumber);
  if (tag < saved.observed.blockNumber) throw Error("Refusal predates capture");
  const observed = await io.chain(p, saved.deployment.chainId, tag), d = saved.deployment, planId = saved.stage.planId;
  await io.runtime(p, d.inventory, tag);
  const local = async () => ({ plan: await read(p, d, "plan", [planId], tag), token: await read(p, d, "tokenProgress", [planId], tag),
    originCount: await read(p, d, "originCount", [planId], tag), originCursor: await read(p, d, "originRuntimeCursor", [planId], tag), originSetHash: await read(p, d, "originSetHash", [planId], tag) });
  const before = await local(); let error: unknown;
  try { await p.call({ ...saved.prepared.call, from: saved.prepared.caller, blockTag: tag, gasLimit: cap }); } catch (failure) { error = failure; }
  if (error === undefined) throw Error("Original call did not refuse");
  const after = await local(); await io.unchanged(p, observed);
  return { observed, error, outcome: (error as { code?: string })?.code === "CALL_EXCEPTION" ? "execution-reverted" as const : "rpc-failed" as const,
    retainedStateUnchanged: io.stable(before) === io.stable(after), rollbackProven: false as const };
}
