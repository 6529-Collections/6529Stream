import { AbiCoder, Interface, ParamType, id, keccak256 } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import * as inv from "./current-scoped-policy-inventory-v2.js";
import * as io from "./current-scoped-policy-inventory-archive-workflow-internal.js";

// ABI129 compiler nominal selectors. Only independent public pure/view computations are called.
// Structural value tuples are separate from the nominal function selector. Enum values are uint8
// as witnessed by the same frozen ordinary host interfaces and original enum declarations.
const workers = {
  sourceCurrent: {
    selector: "0x3a26afec",
    inputs: ["(address[12] targets, bytes32[12] codeHashes, address[5] artistTargets, bytes32[5] artistCodeHashes, address artistContentOwner, bytes32 artistContentOwnerCodeHash, uint256 chainId, uint256 readGas, uint256 sourceGas, uint256 selectionGas, uint256 snapshotGas, uint256 referenceGas)","(uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId)"],
    outputs: ["((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, bytes32 subject, bytes32 artistId, (bytes32 recordHash, bytes32 scopeSubject, bytes32 predecessor, uint64 revision, bytes32 chainHash, bytes32 manifestHash, uint32 manifestBytes, bytes32 sourceHash, address publisher, uint8 authorizationClass, uint64 grantRevision, uint8 displayAuthorizationClass, uint64 displayGrantRevision, uint64 recordedAt, bytes32 schemaHash, bytes32 profileHash, bytes32 canonicalizationHash) snapshot, ((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, (bytes32 scopeSubject, bytes32 scopeManifestHash, bytes32 sourceRecordHash, uint256 tokenCount, bytes32 tokenListHash, bytes32 membershipHash, uint256 inventoryCount, bytes32 inventoryPrefixHash) membership, (bool locked, address registry, bytes32 registryCodeHash, bytes32 artistId, uint64 bindingGeneration, bytes32 bindingHash, address nominatedArtist, bytes32 identityRecordHash, bytes32 acceptanceRecordHash, uint64 acceptedAt, uint64 lockedAt, bytes32 snapshotHash) artist, ((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, bytes32 membershipHash, bytes32 collectionStateHash, uint64 tokenCount, uint64 nextIndex, bytes32 selectionRoot) selection, (bytes32 selectionId, bytes32 selectionHash, bytes32 inventoryHash, bytes32 policyChainHash, (uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, uint64 tokenCount, uint64 nextIndex, bytes32 leafChainHash, bytes32 contentRoot, bytes32 outputRoot) content, (bytes32 checkpointHash, bytes32 checkpointStateHash, address entropySourceSet, bytes32 inventoryHash, bytes32 policyChainHash, bytes32 artifactHash, bytes32 coverageHash, bytes32 artistId, bytes32 contentRoot, bytes32 outputRoot, bytes32 manifestHash, (uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, uint64 tokenCount, uint64 byteLength) outputs, address sourceFactory, bytes32 sourceFactoryCodeHash, bytes32 factoryDependenciesHash, (bytes32 planId, bytes32 inventoryHash, bytes32 policyChainHash, uint256 policyCount, bool allFrozen, (address coordinator, bytes32 indexedCodeHash, uint256 firstTokenIndex, bool frozen, bytes32 moduleVersion, bytes32 moduleManifestHash, bytes32 moduleSchemaHash, bytes32 deploymentManifestHash, bytes32 policyHash, address provider, uint32 epoch, bytes32 salt, bytes32 componentDataHash, bool explicitPolicy, (bool configured, bool explicitPolicy, bool frozen, uint8 mode, uint8 securityClass, uint8 renderRequirement, uint64 revision, uint32 providerEpoch, bytes32 policyHash, bytes32 contentStateHash, bytes32 lastActionId, bytes32 artistConsentRecord) collectionPolicy)[] policies) entropy) snapshotSource, (bytes32 scopeSubject, (bytes32 recordHash, bytes32 recordChainHash, uint256 collectionId, bytes32 referenceId, bytes32 predecessor, uint64 revision, bytes32 payloadHash, uint32 payloadBytes, bytes32 sourcesHash, bytes32 snapshotRecordHash, uint64 snapshotRevision, address recorder, uint8 authorizationClass, uint64 grantRevision, uint64 effectiveAt, uint64 recordedAt, bytes32 reasonHash, bytes32 schemaHash, bytes32 profileHash, bytes32 canonicalizationHash) observation) referenceRender, (bytes32 scopeSubject, bytes32 workDescriptionRecordHash, bytes32 rightsStatementRecordHash, bytes32 workPayloadHash, bytes32 rightsPayloadHash, bytes32 workSelectionHash, bytes32 rightsSelectionHash, uint64 workRevision, uint64 rightsRevision) descriptions, ((bytes32 recordHash, uint8 kind, bytes32 payloadHash, address recorder, uint64 recordedAt, uint64 recordIndex, bytes32 recordChainHash, bytes32 receiptHash, (bytes32 attestationRecordHash, bytes32 artistId, bytes32 bindingHash, uint64 bindingGeneration, address signer, uint8 authorityClass, uint32 requiredCapability, uint64 signedAt, bytes32 publicationHash) publication, bytes32 publicationEvidenceHash) record, (bytes32 artistId, bytes32 bindingHash, uint64 generation, bytes32 identityRecordHash) association, uint8 origin, uint8 interviewStatus, (bytes32 recordHash, uint8 kind, bytes32 payloadHash, address recorder, uint64 recordedAt, uint64 recordIndex, bytes32 recordChainHash, bytes32 receiptHash, (bytes32 attestationRecordHash, bytes32 artistId, bytes32 bindingHash, uint64 bindingGeneration, address signer, uint8 authorityClass, uint32 requiredCapability, uint64 signedAt, bytes32 publicationHash) publication, bytes32 publicationEvidenceHash) interview, bytes32 interviewArchiveReferenceHash, uint8 interviewPayloadCorrespondence, bytes32 predecessor, address submitter, uint64 revision, uint64 selectedAt, bytes32 catalogsHash, bytes32 selectionHash) conservation, bytes32 interviewEvidenceHash, bytes32 nativeHash, bytes32 rootRecordHash, bytes32 tokenInventoryHash, bytes32 checkpointHash, bytes32 outputManifestRecord, bytes32 selectionId, bytes32 selectionHash, uint64 tokenCount)"]
  },
  sourceReference: {
    selector: "0xc935430c",
    inputs: ["(address[12] targets, bytes32[12] codeHashes, address[5] artistTargets, bytes32[5] artistCodeHashes, address artistContentOwner, bytes32 artistContentOwnerCodeHash, uint256 chainId, uint256 readGas, uint256 sourceGas, uint256 selectionGas, uint256 snapshotGas, uint256 referenceGas)"],
    outputs: ["(address[7] targets, bytes32[7] codeHashes, uint256 chainId, uint256 readGas, uint256 sourceGas, uint256 snapshotGas, uint256 archiveGas)"]
  },
  sourceSnapshot: {
    selector: "0x3580ef6e",
    inputs: ["(address[12] targets, bytes32[12] codeHashes, address[5] artistTargets, bytes32[5] artistCodeHashes, address artistContentOwner, bytes32 artistContentOwnerCodeHash, uint256 chainId, uint256 readGas, uint256 sourceGas, uint256 selectionGas, uint256 snapshotGas, uint256 referenceGas)"],
    outputs: ["(address[11] targets, bytes32[11] codeHashes, uint256 chainId, uint256 readGas, uint256 sourceGas, uint256 inventoryGas)"]
  },
  nativeItems: {
    selector: "0xf8ae3fd7",
    inputs: ["(address[12] targets, bytes32[12] codeHashes, address[5] artistTargets, bytes32[5] artistCodeHashes, address artistContentOwner, bytes32 artistContentOwnerCodeHash, uint256 chainId, uint256 readGas, uint256 sourceGas, uint256 selectionGas, uint256 snapshotGas, uint256 referenceGas)","((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, bytes32 subject, bytes32 artistId, (bytes32 recordHash, bytes32 scopeSubject, bytes32 predecessor, uint64 revision, bytes32 chainHash, bytes32 manifestHash, uint32 manifestBytes, bytes32 sourceHash, address publisher, uint8 authorizationClass, uint64 grantRevision, uint8 displayAuthorizationClass, uint64 displayGrantRevision, uint64 recordedAt, bytes32 schemaHash, bytes32 profileHash, bytes32 canonicalizationHash) snapshot, ((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, (bytes32 scopeSubject, bytes32 scopeManifestHash, bytes32 sourceRecordHash, uint256 tokenCount, bytes32 tokenListHash, bytes32 membershipHash, uint256 inventoryCount, bytes32 inventoryPrefixHash) membership, (bool locked, address registry, bytes32 registryCodeHash, bytes32 artistId, uint64 bindingGeneration, bytes32 bindingHash, address nominatedArtist, bytes32 identityRecordHash, bytes32 acceptanceRecordHash, uint64 acceptedAt, uint64 lockedAt, bytes32 snapshotHash) artist, ((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, bytes32 membershipHash, bytes32 collectionStateHash, uint64 tokenCount, uint64 nextIndex, bytes32 selectionRoot) selection, (bytes32 selectionId, bytes32 selectionHash, bytes32 inventoryHash, bytes32 policyChainHash, (uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, uint64 tokenCount, uint64 nextIndex, bytes32 leafChainHash, bytes32 contentRoot, bytes32 outputRoot) content, (bytes32 checkpointHash, bytes32 checkpointStateHash, address entropySourceSet, bytes32 inventoryHash, bytes32 policyChainHash, bytes32 artifactHash, bytes32 coverageHash, bytes32 artistId, bytes32 contentRoot, bytes32 outputRoot, bytes32 manifestHash, (uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, uint64 tokenCount, uint64 byteLength) outputs, address sourceFactory, bytes32 sourceFactoryCodeHash, bytes32 factoryDependenciesHash, (bytes32 planId, bytes32 inventoryHash, bytes32 policyChainHash, uint256 policyCount, bool allFrozen, (address coordinator, bytes32 indexedCodeHash, uint256 firstTokenIndex, bool frozen, bytes32 moduleVersion, bytes32 moduleManifestHash, bytes32 moduleSchemaHash, bytes32 deploymentManifestHash, bytes32 policyHash, address provider, uint32 epoch, bytes32 salt, bytes32 componentDataHash, bool explicitPolicy, (bool configured, bool explicitPolicy, bool frozen, uint8 mode, uint8 securityClass, uint8 renderRequirement, uint64 revision, uint32 providerEpoch, bytes32 policyHash, bytes32 contentStateHash, bytes32 lastActionId, bytes32 artistConsentRecord) collectionPolicy)[] policies) entropy) snapshotSource, (bytes32 scopeSubject, (bytes32 recordHash, bytes32 recordChainHash, uint256 collectionId, bytes32 referenceId, bytes32 predecessor, uint64 revision, bytes32 payloadHash, uint32 payloadBytes, bytes32 sourcesHash, bytes32 snapshotRecordHash, uint64 snapshotRevision, address recorder, uint8 authorizationClass, uint64 grantRevision, uint64 effectiveAt, uint64 recordedAt, bytes32 reasonHash, bytes32 schemaHash, bytes32 profileHash, bytes32 canonicalizationHash) observation) referenceRender, (bytes32 scopeSubject, bytes32 workDescriptionRecordHash, bytes32 rightsStatementRecordHash, bytes32 workPayloadHash, bytes32 rightsPayloadHash, bytes32 workSelectionHash, bytes32 rightsSelectionHash, uint64 workRevision, uint64 rightsRevision) descriptions, ((bytes32 recordHash, uint8 kind, bytes32 payloadHash, address recorder, uint64 recordedAt, uint64 recordIndex, bytes32 recordChainHash, bytes32 receiptHash, (bytes32 attestationRecordHash, bytes32 artistId, bytes32 bindingHash, uint64 bindingGeneration, address signer, uint8 authorityClass, uint32 requiredCapability, uint64 signedAt, bytes32 publicationHash) publication, bytes32 publicationEvidenceHash) record, (bytes32 artistId, bytes32 bindingHash, uint64 generation, bytes32 identityRecordHash) association, uint8 origin, uint8 interviewStatus, (bytes32 recordHash, uint8 kind, bytes32 payloadHash, address recorder, uint64 recordedAt, uint64 recordIndex, bytes32 recordChainHash, bytes32 receiptHash, (bytes32 attestationRecordHash, bytes32 artistId, bytes32 bindingHash, uint64 bindingGeneration, address signer, uint8 authorityClass, uint32 requiredCapability, uint64 signedAt, bytes32 publicationHash) publication, bytes32 publicationEvidenceHash) interview, bytes32 interviewArchiveReferenceHash, uint8 interviewPayloadCorrespondence, bytes32 predecessor, address submitter, uint64 revision, uint64 selectedAt, bytes32 catalogsHash, bytes32 selectionHash) conservation, bytes32 interviewEvidenceHash, bytes32 nativeHash, bytes32 rootRecordHash, bytes32 tokenInventoryHash, bytes32 checkpointHash, bytes32 outputManifestRecord, bytes32 selectionId, bytes32 selectionHash, uint64 tokenCount)","uint64","uint64"],
    outputs: ["(uint8 kind, bytes32 role, address source, bytes32 sourceRecord, uint256 sourceIndex, uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri, uint64 byteSize, bytes32 schemaId, bytes32 formatId, bytes32 catalogId, bytes32 catalogHash, bytes32 objectHash, bytes32 originalCoverageHash, bytes32 provenanceHash)[]","uint64"]
  },
  referenceItems: {
    selector: "0xfb35365e",
    inputs: ["(address[12] targets, bytes32[12] codeHashes, address[5] artistTargets, bytes32[5] artistCodeHashes, address artistContentOwner, bytes32 artistContentOwnerCodeHash, uint256 chainId, uint256 readGas, uint256 sourceGas, uint256 selectionGas, uint256 snapshotGas, uint256 referenceGas)","((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, bytes32 subject, bytes32 artistId, (bytes32 recordHash, bytes32 scopeSubject, bytes32 predecessor, uint64 revision, bytes32 chainHash, bytes32 manifestHash, uint32 manifestBytes, bytes32 sourceHash, address publisher, uint8 authorizationClass, uint64 grantRevision, uint8 displayAuthorizationClass, uint64 displayGrantRevision, uint64 recordedAt, bytes32 schemaHash, bytes32 profileHash, bytes32 canonicalizationHash) snapshot, (bytes32 scopeSubject, (bytes32 recordHash, bytes32 recordChainHash, uint256 collectionId, bytes32 referenceId, bytes32 predecessor, uint64 revision, bytes32 payloadHash, uint32 payloadBytes, bytes32 sourcesHash, bytes32 snapshotRecordHash, uint64 snapshotRevision, address recorder, uint8 authorizationClass, uint64 grantRevision, uint64 effectiveAt, uint64 recordedAt, bytes32 reasonHash, bytes32 schemaHash, bytes32 profileHash, bytes32 canonicalizationHash) observation) referenceRender)","uint64","uint64"],
    outputs: ["(uint8 kind, bytes32 role, address source, bytes32 sourceRecord, uint256 sourceIndex, uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri, uint64 byteSize, bytes32 schemaId, bytes32 formatId, bytes32 catalogId, bytes32 catalogHash, bytes32 objectHash, bytes32 originalCoverageHash, bytes32 provenanceHash)[]","uint64"]
  },
  work: {
    selector: "0x060a99b4",
    inputs: ["address","bytes32","bytes32","(bytes32 subjectId, bytes32 profileHash, bytes32 predecessor, uint8 form, (string title, (uint8 kind, bytes32 artistId, uint64 bindingGeneration, bytes32 bindingHash, string name) creator, (uint8 kind, uint32 start, uint32 end) creation, string medium, (uint8 kind, bytes32 formatId, string puid, (string name, (bytes32 entryId, uint8 kind, string puid, (string uri, bytes32 digest) specification)[] entries, bytes32 selectedEntryId) catalog) format, (uint8 kind, bool hasPixels, uint256 width, uint256 height, bool hasAspectRatio, (uint256 numerator, uint256 denominator) aspectRatio, bool hasDuration, (uint256 numerator, uint256 denominator) durationSeconds) measurements, (uint8 kind, uint256 number, uint256 total, string statement) edition, string creditLine, bool hasInscription, string inscription, string[] alternateTitles, (uint8 field, uint8 alternateTitleIndex, string language, string value)[] languageVariants, (uint8 role, uint8 authority, string identifier)[] authorityReferences) full, (string reason, uint32 date) absence)"],
    outputs: ["(uint8 kind, bytes32 role, address source, bytes32 sourceRecord, uint256 sourceIndex, uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri, uint64 byteSize, bytes32 schemaId, bytes32 formatId, bytes32 catalogId, bytes32 catalogHash, bytes32 objectHash, bytes32 originalCoverageHash, bytes32 provenanceHash)[]"]
  },
  rights: {
    selector: "0x64955529",
    inputs: ["address","bytes32","bytes32","(bytes32 subjectId, bytes32 profileHash, uint8 basis, (uint8 kind, bytes32 artistId, string name, address account, bytes32 instrumentDigest) licensor, ((uint8 status, (uint8 kind, string text, (bool exists, string uri, bytes32 digest) document) conditions, string extension) aiTraining, (uint8 status, (uint8 kind, string text, (bool exists, string uri, bytes32 digest) document) conditions, string extension) derivative, (uint8 status, (uint8 kind, string text, (bool exists, string uri, bytes32 digest) document) conditions, string extension) exhibition, (uint8 status, (uint8 kind, string text, (bool exists, string uri, bytes32 digest) document) conditions, string extension) print, (uint8 status, (uint8 kind, string text, (bool exists, string uri, bytes32 digest) document) conditions, string extension) publication, (uint8 status, (uint8 kind, string text, (bool exists, string uri, bytes32 digest) document) conditions, string extension) reproduction) grants, uint32 startDate, uint32 endDate, bool openEnd, (bool exists, string uri, bytes32 digest) instrument, bool hasAiTrainingPermission, uint8 aiTrainingPermission, bytes32 predecessor)"],
    outputs: ["(uint8 kind, bytes32 role, address source, bytes32 sourceRecord, uint256 sourceIndex, uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri, uint64 byteSize, bytes32 schemaId, bytes32 formatId, bytes32 catalogId, bytes32 catalogHash, bytes32 objectHash, bytes32 originalCoverageHash, bytes32 provenanceHash)[]"]
  },
  intent: {
    selector: "0xeecd0bbf",
    inputs: ["address","bytes32","bytes32","(bytes32 subjectId, bytes32 profileHash, bytes32 predecessor, (bytes32 artistId, uint64 bindingGeneration, bytes32 bindingHash, uint8 origin) artist, ((uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) scale, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) timing, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) color, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) interaction, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) motion, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) frameRate) display, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) variabilityTolerances, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) dependencyAging, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) significantProperties, (uint8 status, (uint256 chainId, address core, address host, bytes32 recordHash, bytes32 schemaId, bytes32 profileHash, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) payload) record, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) waiverStatement) interview)"],
    outputs: ["(uint8 kind, bytes32 role, address source, bytes32 sourceRecord, uint256 sourceIndex, uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri, uint64 byteSize, bytes32 schemaId, bytes32 formatId, bytes32 catalogId, bytes32 catalogHash, bytes32 objectHash, bytes32 originalCoverageHash, bytes32 provenanceHash)[]"]
  },
  waiver: {
    selector: "0x80476513",
    inputs: ["address","bytes32","bytes32","(bytes32 subjectId, bytes32 profileHash, bytes32 predecessor, (bytes32 artistId, uint64 bindingGeneration, bytes32 bindingHash, uint8 origin) artist, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) waiverStatement, (uint8 status, (uint256 chainId, address core, address host, bytes32 recordHash, bytes32 schemaId, bytes32 profileHash, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) payload) record, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) waiverStatement) interview)"],
    outputs: ["(uint8 kind, bytes32 role, address source, bytes32 sourceRecord, uint256 sourceIndex, uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri, uint64 byteSize, bytes32 schemaId, bytes32 formatId, bytes32 catalogId, bytes32 catalogHash, bytes32 objectHash, bytes32 originalCoverageHash, bytes32 provenanceHash)[]"]
  },
  interview: {
    selector: "0x862d2f0b",
    inputs: ["address","bytes32","bytes32","(bytes32 subjectId, bytes32 profileHash, bytes32 predecessor, (uint8 kind, string name, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) document) instrument, (uint8 role, string otherRole, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) identity)[] participants, uint32 interviewDate, string[] languages, ((uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) content, (uint8 kind, bytes32 formatId, string puid, (string name, (bytes32 entryId, uint8 kind, string puid, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) specification)[] entries, bytes32 selectedEntryId) catalog) format) transcript, (uint8 kind, ((uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) content, (uint8 kind, bytes32 formatId, string puid, (string name, (bytes32 entryId, uint8 kind, string puid, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) specification)[] entries, bytes32 selectedEntryId) catalog) format) payload)[] captures)"],
    outputs: ["(uint8 kind, bytes32 role, address source, bytes32 sourceRecord, uint256 sourceIndex, uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri, uint64 byteSize, bytes32 schemaId, bytes32 formatId, bytes32 catalogId, bytes32 catalogHash, bytes32 objectHash, bytes32 originalCoverageHash, bytes32 provenanceHash)[]"]
  },
  originals: {
    selector: "0xd8098a23",
    inputs: ["(address[12] targets, bytes32[12] codeHashes, address[5] artistTargets, bytes32[5] artistCodeHashes, address artistContentOwner, bytes32 artistContentOwnerCodeHash, uint256 chainId, uint256 readGas, uint256 sourceGas, uint256 selectionGas, uint256 snapshotGas, uint256 referenceGas)","(uint256 collectionId, bytes32 subject, bytes32 artistId, (bytes32 recordHash, uint256 collectionId, bytes32 snapshotId, bytes32 predecessor, uint64 revision, bytes32 recordChainHash, bytes32 manifestHash, uint32 manifestBytes, bytes32 sourceHash, bytes32 inventoryPlan, address publisher, uint8 authorizationClass, uint64 grantRevision, uint8 displayAuthorizationClass, uint64 displayGrantRevision, uint64 effectiveAt, uint64 recordedAt, bytes32 reasonHash, bytes32 schemaDefinitionHash, bytes32 profileDefinitionHash, bytes32 canonicalizationDefinitionHash) snapshot, (bytes32 recordHash, bytes32 recordChainHash, uint256 collectionId, bytes32 referenceId, bytes32 predecessor, uint64 revision, bytes32 payloadHash, uint32 payloadBytes, bytes32 sourcesHash, bytes32 snapshotRecordHash, uint64 snapshotRevision, address recorder, uint8 authorizationClass, uint64 grantRevision, uint64 effectiveAt, uint64 recordedAt, bytes32 reasonHash, bytes32 schemaHash, bytes32 profileHash, bytes32 canonicalizationHash) referenceRender, (bytes32 scopeSubject, bytes32 workDescriptionRecordHash, bytes32 rightsStatementRecordHash, bytes32 workPayloadHash, bytes32 rightsPayloadHash, bytes32 workSelectionHash, bytes32 rightsSelectionHash, uint64 workRevision, uint64 rightsRevision) descriptions, ((bytes32 recordHash, uint8 kind, bytes32 payloadHash, address recorder, uint64 recordedAt, uint64 recordIndex, bytes32 recordChainHash, bytes32 receiptHash, (bytes32 attestationRecordHash, bytes32 artistId, bytes32 bindingHash, uint64 bindingGeneration, address signer, uint8 authorityClass, uint32 requiredCapability, uint64 signedAt, bytes32 publicationHash) publication, bytes32 publicationEvidenceHash) record, (bytes32 artistId, bytes32 bindingHash, uint64 generation, bytes32 identityRecordHash) association, uint8 origin, uint8 interviewStatus, (bytes32 recordHash, uint8 kind, bytes32 payloadHash, address recorder, uint64 recordedAt, uint64 recordIndex, bytes32 recordChainHash, bytes32 receiptHash, (bytes32 attestationRecordHash, bytes32 artistId, bytes32 bindingHash, uint64 bindingGeneration, address signer, uint8 authorityClass, uint32 requiredCapability, uint64 signedAt, bytes32 publicationHash) publication, bytes32 publicationEvidenceHash) interview, bytes32 interviewArchiveReferenceHash, uint8 interviewPayloadCorrespondence, bytes32 predecessor, address submitter, uint64 revision, uint64 selectedAt, bytes32 catalogsHash, bytes32 selectionHash) conservation, bytes32 interviewEvidenceHash, bytes32 nativeHash, bytes32 rootRecordHash, bytes32 tokenInventoryHash, bytes32 checkpointHash, uint64 tokenCount)","bytes32","bytes32"],
    outputs: ["(uint8 kind, bytes32 role, address source, bytes32 sourceRecord, uint256 sourceIndex, uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri, uint64 byteSize, bytes32 schemaId, bytes32 formatId, bytes32 catalogId, bytes32 catalogHash, bytes32 objectHash, bytes32 originalCoverageHash, bytes32 provenanceHash)[]"]
  },
  artist: {
    selector: "0xbe16ce6d",
    inputs: ["(address[12] targets, bytes32[12] codeHashes, address[5] artistTargets, bytes32[5] artistCodeHashes, address artistContentOwner, bytes32 artistContentOwnerCodeHash, uint256 chainId, uint256 readGas, uint256 sourceGas, uint256 selectionGas, uint256 snapshotGas, uint256 referenceGas)","(bytes32 attestationRecordHash, bytes32 artistId, bytes32 bindingHash, uint64 bindingGeneration, address signer, uint8 authorityClass, uint32 requiredCapability, uint64 signedAt, bytes32 publicationHash)","bytes32","address"],
    outputs: ["(uint8 kind, bytes32 role, address source, bytes32 sourceRecord, uint256 sourceIndex, uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri, uint64 byteSize, bytes32 schemaId, bytes32 formatId, bytes32 catalogId, bytes32 catalogHash, bytes32 objectHash, bytes32 originalCoverageHash, bytes32 provenanceHash)"]
  },
  document: {
    selector: "0x4be60838",
    inputs: ["(address[12] targets, bytes32[12] codeHashes, address[5] artistTargets, bytes32[5] artistCodeHashes, address artistContentOwner, bytes32 artistContentOwnerCodeHash, uint256 chainId, uint256 readGas, uint256 sourceGas, uint256 selectionGas, uint256 snapshotGas, uint256 referenceGas)","bytes32","bytes32"],
    outputs: ["(uint8 kind, bytes32 role, address source, bytes32 sourceRecord, uint256 sourceIndex, uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri, uint64 byteSize, bytes32 schemaId, bytes32 formatId, bytes32 catalogId, bytes32 catalogHash, bytes32 objectHash, bytes32 originalCoverageHash, bytes32 provenanceHash)"]
  },
  catalogs: {
    selector: "0x0934be3b",
    inputs: ["(address[12] targets, bytes32[12] codeHashes, address[5] artistTargets, bytes32[5] artistCodeHashes, address artistContentOwner, bytes32 artistContentOwnerCodeHash, uint256 chainId, uint256 readGas, uint256 sourceGas, uint256 selectionGas, uint256 snapshotGas, uint256 referenceGas)","(uint8 kind, bytes32 role, address source, bytes32 sourceRecord, uint256 sourceIndex, uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri, uint64 byteSize, bytes32 schemaId, bytes32 formatId, bytes32 catalogId, bytes32 catalogHash, bytes32 objectHash, bytes32 originalCoverageHash, bytes32 provenanceHash)[]"],
    outputs: []
  },
  documentFacts: {
    selector: "0x58ec0344",
    inputs: ["(address[12] targets, bytes32[12] codeHashes, address[5] artistTargets, bytes32[5] artistCodeHashes, address artistContentOwner, bytes32 artistContentOwnerCodeHash, uint256 chainId, uint256 readGas, uint256 sourceGas, uint256 selectionGas, uint256 snapshotGas, uint256 referenceGas)","bytes32"],
    outputs: ["bytes32"]
  },
  root: {
    selector: "0x02b6428c",
    inputs: ["(address[12] targets, bytes32[12] codeHashes, address[5] artistTargets, bytes32[5] artistCodeHashes, address artistContentOwner, bytes32 artistContentOwnerCodeHash, uint256 chainId, uint256 readGas, uint256 sourceGas, uint256 selectionGas, uint256 snapshotGas, uint256 referenceGas)","((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, bytes32 subject, bytes32 artistId, (bytes32 recordHash, bytes32 scopeSubject, bytes32 predecessor, uint64 revision, bytes32 chainHash, bytes32 manifestHash, uint32 manifestBytes, bytes32 sourceHash, address publisher, uint8 authorizationClass, uint64 grantRevision, uint8 displayAuthorizationClass, uint64 displayGrantRevision, uint64 recordedAt, bytes32 schemaHash, bytes32 profileHash, bytes32 canonicalizationHash) snapshot, ((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, (bytes32 scopeSubject, bytes32 scopeManifestHash, bytes32 sourceRecordHash, uint256 tokenCount, bytes32 tokenListHash, bytes32 membershipHash, uint256 inventoryCount, bytes32 inventoryPrefixHash) membership, (bool locked, address registry, bytes32 registryCodeHash, bytes32 artistId, uint64 bindingGeneration, bytes32 bindingHash, address nominatedArtist, bytes32 identityRecordHash, bytes32 acceptanceRecordHash, uint64 acceptedAt, uint64 lockedAt, bytes32 snapshotHash) artist, ((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, bytes32 membershipHash, bytes32 collectionStateHash, uint64 tokenCount, uint64 nextIndex, bytes32 selectionRoot) selection, (bytes32 selectionId, bytes32 selectionHash, bytes32 inventoryHash, bytes32 policyChainHash, (uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, uint64 tokenCount, uint64 nextIndex, bytes32 leafChainHash, bytes32 contentRoot, bytes32 outputRoot) content, (bytes32 checkpointHash, bytes32 checkpointStateHash, address entropySourceSet, bytes32 inventoryHash, bytes32 policyChainHash, bytes32 artifactHash, bytes32 coverageHash, bytes32 artistId, bytes32 contentRoot, bytes32 outputRoot, bytes32 manifestHash, (uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, uint64 tokenCount, uint64 byteLength) outputs, address sourceFactory, bytes32 sourceFactoryCodeHash, bytes32 factoryDependenciesHash, (bytes32 planId, bytes32 inventoryHash, bytes32 policyChainHash, uint256 policyCount, bool allFrozen, (address coordinator, bytes32 indexedCodeHash, uint256 firstTokenIndex, bool frozen, bytes32 moduleVersion, bytes32 moduleManifestHash, bytes32 moduleSchemaHash, bytes32 deploymentManifestHash, bytes32 policyHash, address provider, uint32 epoch, bytes32 salt, bytes32 componentDataHash, bool explicitPolicy, (bool configured, bool explicitPolicy, bool frozen, uint8 mode, uint8 securityClass, uint8 renderRequirement, uint64 revision, uint32 providerEpoch, bytes32 policyHash, bytes32 contentStateHash, bytes32 lastActionId, bytes32 artistConsentRecord) collectionPolicy)[] policies) entropy) snapshotSource, (bytes32 scopeSubject, (bytes32 recordHash, bytes32 recordChainHash, uint256 collectionId, bytes32 referenceId, bytes32 predecessor, uint64 revision, bytes32 payloadHash, uint32 payloadBytes, bytes32 sourcesHash, bytes32 snapshotRecordHash, uint64 snapshotRevision, address recorder, uint8 authorizationClass, uint64 grantRevision, uint64 effectiveAt, uint64 recordedAt, bytes32 reasonHash, bytes32 schemaHash, bytes32 profileHash, bytes32 canonicalizationHash) observation) referenceRender, (bytes32 scopeSubject, bytes32 workDescriptionRecordHash, bytes32 rightsStatementRecordHash, bytes32 workPayloadHash, bytes32 rightsPayloadHash, bytes32 workSelectionHash, bytes32 rightsSelectionHash, uint64 workRevision, uint64 rightsRevision) descriptions, ((bytes32 recordHash, uint8 kind, bytes32 payloadHash, address recorder, uint64 recordedAt, uint64 recordIndex, bytes32 recordChainHash, bytes32 receiptHash, (bytes32 attestationRecordHash, bytes32 artistId, bytes32 bindingHash, uint64 bindingGeneration, address signer, uint8 authorityClass, uint32 requiredCapability, uint64 signedAt, bytes32 publicationHash) publication, bytes32 publicationEvidenceHash) record, (bytes32 artistId, bytes32 bindingHash, uint64 generation, bytes32 identityRecordHash) association, uint8 origin, uint8 interviewStatus, (bytes32 recordHash, uint8 kind, bytes32 payloadHash, address recorder, uint64 recordedAt, uint64 recordIndex, bytes32 recordChainHash, bytes32 receiptHash, (bytes32 attestationRecordHash, bytes32 artistId, bytes32 bindingHash, uint64 bindingGeneration, address signer, uint8 authorityClass, uint32 requiredCapability, uint64 signedAt, bytes32 publicationHash) publication, bytes32 publicationEvidenceHash) interview, bytes32 interviewArchiveReferenceHash, uint8 interviewPayloadCorrespondence, bytes32 predecessor, address submitter, uint64 revision, uint64 selectedAt, bytes32 catalogsHash, bytes32 selectionHash) conservation, bytes32 interviewEvidenceHash, bytes32 nativeHash, bytes32 rootRecordHash, bytes32 tokenInventoryHash, bytes32 checkpointHash, bytes32 outputManifestRecord, bytes32 selectionId, bytes32 selectionHash, uint64 tokenCount)","address","uint64","(uint64 revision, bytes32 transitionChain)","bytes32"],
    outputs: ["(uint8 kind, bytes32 role, address source, bytes32 sourceRecord, uint256 sourceIndex, uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri, uint64 byteSize, bytes32 schemaId, bytes32 formatId, bytes32 catalogId, bytes32 catalogHash, bytes32 objectHash, bytes32 originalCoverageHash, bytes32 provenanceHash)"]
  },
  token: {
    selector: "0x590a8dae",
    inputs: ["(address[12] targets, bytes32[12] codeHashes, address[5] artistTargets, bytes32[5] artistCodeHashes, address artistContentOwner, bytes32 artistContentOwnerCodeHash, uint256 chainId, uint256 readGas, uint256 sourceGas, uint256 selectionGas, uint256 snapshotGas, uint256 referenceGas)","((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, bytes32 subject, bytes32 artistId, (bytes32 recordHash, bytes32 scopeSubject, bytes32 predecessor, uint64 revision, bytes32 chainHash, bytes32 manifestHash, uint32 manifestBytes, bytes32 sourceHash, address publisher, uint8 authorizationClass, uint64 grantRevision, uint8 displayAuthorizationClass, uint64 displayGrantRevision, uint64 recordedAt, bytes32 schemaHash, bytes32 profileHash, bytes32 canonicalizationHash) snapshot, ((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, (bytes32 scopeSubject, bytes32 scopeManifestHash, bytes32 sourceRecordHash, uint256 tokenCount, bytes32 tokenListHash, bytes32 membershipHash, uint256 inventoryCount, bytes32 inventoryPrefixHash) membership, (bool locked, address registry, bytes32 registryCodeHash, bytes32 artistId, uint64 bindingGeneration, bytes32 bindingHash, address nominatedArtist, bytes32 identityRecordHash, bytes32 acceptanceRecordHash, uint64 acceptedAt, uint64 lockedAt, bytes32 snapshotHash) artist, ((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, bytes32 membershipHash, bytes32 collectionStateHash, uint64 tokenCount, uint64 nextIndex, bytes32 selectionRoot) selection, (bytes32 selectionId, bytes32 selectionHash, bytes32 inventoryHash, bytes32 policyChainHash, (uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, uint64 tokenCount, uint64 nextIndex, bytes32 leafChainHash, bytes32 contentRoot, bytes32 outputRoot) content, (bytes32 checkpointHash, bytes32 checkpointStateHash, address entropySourceSet, bytes32 inventoryHash, bytes32 policyChainHash, bytes32 artifactHash, bytes32 coverageHash, bytes32 artistId, bytes32 contentRoot, bytes32 outputRoot, bytes32 manifestHash, (uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, uint64 tokenCount, uint64 byteLength) outputs, address sourceFactory, bytes32 sourceFactoryCodeHash, bytes32 factoryDependenciesHash, (bytes32 planId, bytes32 inventoryHash, bytes32 policyChainHash, uint256 policyCount, bool allFrozen, (address coordinator, bytes32 indexedCodeHash, uint256 firstTokenIndex, bool frozen, bytes32 moduleVersion, bytes32 moduleManifestHash, bytes32 moduleSchemaHash, bytes32 deploymentManifestHash, bytes32 policyHash, address provider, uint32 epoch, bytes32 salt, bytes32 componentDataHash, bool explicitPolicy, (bool configured, bool explicitPolicy, bool frozen, uint8 mode, uint8 securityClass, uint8 renderRequirement, uint64 revision, uint32 providerEpoch, bytes32 policyHash, bytes32 contentStateHash, bytes32 lastActionId, bytes32 artistConsentRecord) collectionPolicy)[] policies) entropy) snapshotSource, (bytes32 scopeSubject, (bytes32 recordHash, bytes32 recordChainHash, uint256 collectionId, bytes32 referenceId, bytes32 predecessor, uint64 revision, bytes32 payloadHash, uint32 payloadBytes, bytes32 sourcesHash, bytes32 snapshotRecordHash, uint64 snapshotRevision, address recorder, uint8 authorizationClass, uint64 grantRevision, uint64 effectiveAt, uint64 recordedAt, bytes32 reasonHash, bytes32 schemaHash, bytes32 profileHash, bytes32 canonicalizationHash) observation) referenceRender, (bytes32 scopeSubject, bytes32 workDescriptionRecordHash, bytes32 rightsStatementRecordHash, bytes32 workPayloadHash, bytes32 rightsPayloadHash, bytes32 workSelectionHash, bytes32 rightsSelectionHash, uint64 workRevision, uint64 rightsRevision) descriptions, ((bytes32 recordHash, uint8 kind, bytes32 payloadHash, address recorder, uint64 recordedAt, uint64 recordIndex, bytes32 recordChainHash, bytes32 receiptHash, (bytes32 attestationRecordHash, bytes32 artistId, bytes32 bindingHash, uint64 bindingGeneration, address signer, uint8 authorityClass, uint32 requiredCapability, uint64 signedAt, bytes32 publicationHash) publication, bytes32 publicationEvidenceHash) record, (bytes32 artistId, bytes32 bindingHash, uint64 generation, bytes32 identityRecordHash) association, uint8 origin, uint8 interviewStatus, (bytes32 recordHash, uint8 kind, bytes32 payloadHash, address recorder, uint64 recordedAt, uint64 recordIndex, bytes32 recordChainHash, bytes32 receiptHash, (bytes32 attestationRecordHash, bytes32 artistId, bytes32 bindingHash, uint64 bindingGeneration, address signer, uint8 authorityClass, uint32 requiredCapability, uint64 signedAt, bytes32 publicationHash) publication, bytes32 publicationEvidenceHash) interview, bytes32 interviewArchiveReferenceHash, uint8 interviewPayloadCorrespondence, bytes32 predecessor, address submitter, uint64 revision, uint64 selectedAt, bytes32 catalogsHash, bytes32 selectionHash) conservation, bytes32 interviewEvidenceHash, bytes32 nativeHash, bytes32 rootRecordHash, bytes32 tokenInventoryHash, bytes32 checkpointHash, bytes32 outputManifestRecord, bytes32 selectionId, bytes32 selectionHash, uint64 tokenCount)","uint64","(uint256 tokenId, bytes image, bytes animation)"],
    outputs: ["(uint8 kind, bytes32 role, address source, bytes32 sourceRecord, uint256 sourceIndex, uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri, uint64 byteSize, bytes32 schemaId, bytes32 formatId, bytes32 catalogId, bytes32 catalogHash, bytes32 objectHash, bytes32 originalCoverageHash, bytes32 provenanceHash)[]"]
  },
  script: {
    selector: "0x0c72da4d",
    inputs: ["(address[12] targets, bytes32[12] codeHashes, address[5] artistTargets, bytes32[5] artistCodeHashes, address artistContentOwner, bytes32 artistContentOwnerCodeHash, uint256 chainId, uint256 readGas, uint256 sourceGas, uint256 selectionGas, uint256 snapshotGas, uint256 referenceGas)","((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, bytes32 subject, bytes32 artistId, (bytes32 recordHash, bytes32 scopeSubject, bytes32 predecessor, uint64 revision, bytes32 chainHash, bytes32 manifestHash, uint32 manifestBytes, bytes32 sourceHash, address publisher, uint8 authorizationClass, uint64 grantRevision, uint8 displayAuthorizationClass, uint64 displayGrantRevision, uint64 recordedAt, bytes32 schemaHash, bytes32 profileHash, bytes32 canonicalizationHash) snapshot, ((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, (bytes32 scopeSubject, bytes32 scopeManifestHash, bytes32 sourceRecordHash, uint256 tokenCount, bytes32 tokenListHash, bytes32 membershipHash, uint256 inventoryCount, bytes32 inventoryPrefixHash) membership, (bool locked, address registry, bytes32 registryCodeHash, bytes32 artistId, uint64 bindingGeneration, bytes32 bindingHash, address nominatedArtist, bytes32 identityRecordHash, bytes32 acceptanceRecordHash, uint64 acceptedAt, uint64 lockedAt, bytes32 snapshotHash) artist, ((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, bytes32 membershipHash, bytes32 collectionStateHash, uint64 tokenCount, uint64 nextIndex, bytes32 selectionRoot) selection, (bytes32 selectionId, bytes32 selectionHash, bytes32 inventoryHash, bytes32 policyChainHash, (uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, uint64 tokenCount, uint64 nextIndex, bytes32 leafChainHash, bytes32 contentRoot, bytes32 outputRoot) content, (bytes32 checkpointHash, bytes32 checkpointStateHash, address entropySourceSet, bytes32 inventoryHash, bytes32 policyChainHash, bytes32 artifactHash, bytes32 coverageHash, bytes32 artistId, bytes32 contentRoot, bytes32 outputRoot, bytes32 manifestHash, (uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, uint64 tokenCount, uint64 byteLength) outputs, address sourceFactory, bytes32 sourceFactoryCodeHash, bytes32 factoryDependenciesHash, (bytes32 planId, bytes32 inventoryHash, bytes32 policyChainHash, uint256 policyCount, bool allFrozen, (address coordinator, bytes32 indexedCodeHash, uint256 firstTokenIndex, bool frozen, bytes32 moduleVersion, bytes32 moduleManifestHash, bytes32 moduleSchemaHash, bytes32 deploymentManifestHash, bytes32 policyHash, address provider, uint32 epoch, bytes32 salt, bytes32 componentDataHash, bool explicitPolicy, (bool configured, bool explicitPolicy, bool frozen, uint8 mode, uint8 securityClass, uint8 renderRequirement, uint64 revision, uint32 providerEpoch, bytes32 policyHash, bytes32 contentStateHash, bytes32 lastActionId, bytes32 artistConsentRecord) collectionPolicy)[] policies) entropy) snapshotSource, (bytes32 scopeSubject, (bytes32 recordHash, bytes32 recordChainHash, uint256 collectionId, bytes32 referenceId, bytes32 predecessor, uint64 revision, bytes32 payloadHash, uint32 payloadBytes, bytes32 sourcesHash, bytes32 snapshotRecordHash, uint64 snapshotRevision, address recorder, uint8 authorizationClass, uint64 grantRevision, uint64 effectiveAt, uint64 recordedAt, bytes32 reasonHash, bytes32 schemaHash, bytes32 profileHash, bytes32 canonicalizationHash) observation) referenceRender, (bytes32 scopeSubject, bytes32 workDescriptionRecordHash, bytes32 rightsStatementRecordHash, bytes32 workPayloadHash, bytes32 rightsPayloadHash, bytes32 workSelectionHash, bytes32 rightsSelectionHash, uint64 workRevision, uint64 rightsRevision) descriptions, ((bytes32 recordHash, uint8 kind, bytes32 payloadHash, address recorder, uint64 recordedAt, uint64 recordIndex, bytes32 recordChainHash, bytes32 receiptHash, (bytes32 attestationRecordHash, bytes32 artistId, bytes32 bindingHash, uint64 bindingGeneration, address signer, uint8 authorityClass, uint32 requiredCapability, uint64 signedAt, bytes32 publicationHash) publication, bytes32 publicationEvidenceHash) record, (bytes32 artistId, bytes32 bindingHash, uint64 generation, bytes32 identityRecordHash) association, uint8 origin, uint8 interviewStatus, (bytes32 recordHash, uint8 kind, bytes32 payloadHash, address recorder, uint64 recordedAt, uint64 recordIndex, bytes32 recordChainHash, bytes32 receiptHash, (bytes32 attestationRecordHash, bytes32 artistId, bytes32 bindingHash, uint64 bindingGeneration, address signer, uint8 authorityClass, uint32 requiredCapability, uint64 signedAt, bytes32 publicationHash) publication, bytes32 publicationEvidenceHash) interview, bytes32 interviewArchiveReferenceHash, uint8 interviewPayloadCorrespondence, bytes32 predecessor, address submitter, uint64 revision, uint64 selectedAt, bytes32 catalogsHash, bytes32 selectionHash) conservation, bytes32 interviewEvidenceHash, bytes32 nativeHash, bytes32 rootRecordHash, bytes32 tokenInventoryHash, bytes32 checkpointHash, bytes32 outputManifestRecord, bytes32 selectionId, bytes32 selectionHash, uint64 tokenCount)","uint64","bool"],
    outputs: ["(uint8 kind, bytes32 role, address source, bytes32 sourceRecord, uint256 sourceIndex, uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri, uint64 byteSize, bytes32 schemaId, bytes32 formatId, bytes32 catalogId, bytes32 catalogHash, bytes32 objectHash, bytes32 originalCoverageHash, bytes32 provenanceHash)[]"]
  },
  renderer: {
    selector: "0xf043d621",
    inputs: ["(address[12] targets, bytes32[12] codeHashes, address[5] artistTargets, bytes32[5] artistCodeHashes, address artistContentOwner, bytes32 artistContentOwnerCodeHash, uint256 chainId, uint256 readGas, uint256 sourceGas, uint256 selectionGas, uint256 snapshotGas, uint256 referenceGas)","((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, bytes32 subject, bytes32 artistId, (bytes32 recordHash, bytes32 scopeSubject, bytes32 predecessor, uint64 revision, bytes32 chainHash, bytes32 manifestHash, uint32 manifestBytes, bytes32 sourceHash, address publisher, uint8 authorizationClass, uint64 grantRevision, uint8 displayAuthorizationClass, uint64 displayGrantRevision, uint64 recordedAt, bytes32 schemaHash, bytes32 profileHash, bytes32 canonicalizationHash) snapshot, ((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, (bytes32 scopeSubject, bytes32 scopeManifestHash, bytes32 sourceRecordHash, uint256 tokenCount, bytes32 tokenListHash, bytes32 membershipHash, uint256 inventoryCount, bytes32 inventoryPrefixHash) membership, (bool locked, address registry, bytes32 registryCodeHash, bytes32 artistId, uint64 bindingGeneration, bytes32 bindingHash, address nominatedArtist, bytes32 identityRecordHash, bytes32 acceptanceRecordHash, uint64 acceptedAt, uint64 lockedAt, bytes32 snapshotHash) artist, ((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, bytes32 membershipHash, bytes32 collectionStateHash, uint64 tokenCount, uint64 nextIndex, bytes32 selectionRoot) selection, (bytes32 selectionId, bytes32 selectionHash, bytes32 inventoryHash, bytes32 policyChainHash, (uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, uint64 tokenCount, uint64 nextIndex, bytes32 leafChainHash, bytes32 contentRoot, bytes32 outputRoot) content, (bytes32 checkpointHash, bytes32 checkpointStateHash, address entropySourceSet, bytes32 inventoryHash, bytes32 policyChainHash, bytes32 artifactHash, bytes32 coverageHash, bytes32 artistId, bytes32 contentRoot, bytes32 outputRoot, bytes32 manifestHash, (uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, uint64 tokenCount, uint64 byteLength) outputs, address sourceFactory, bytes32 sourceFactoryCodeHash, bytes32 factoryDependenciesHash, (bytes32 planId, bytes32 inventoryHash, bytes32 policyChainHash, uint256 policyCount, bool allFrozen, (address coordinator, bytes32 indexedCodeHash, uint256 firstTokenIndex, bool frozen, bytes32 moduleVersion, bytes32 moduleManifestHash, bytes32 moduleSchemaHash, bytes32 deploymentManifestHash, bytes32 policyHash, address provider, uint32 epoch, bytes32 salt, bytes32 componentDataHash, bool explicitPolicy, (bool configured, bool explicitPolicy, bool frozen, uint8 mode, uint8 securityClass, uint8 renderRequirement, uint64 revision, uint32 providerEpoch, bytes32 policyHash, bytes32 contentStateHash, bytes32 lastActionId, bytes32 artistConsentRecord) collectionPolicy)[] policies) entropy) snapshotSource, (bytes32 scopeSubject, (bytes32 recordHash, bytes32 recordChainHash, uint256 collectionId, bytes32 referenceId, bytes32 predecessor, uint64 revision, bytes32 payloadHash, uint32 payloadBytes, bytes32 sourcesHash, bytes32 snapshotRecordHash, uint64 snapshotRevision, address recorder, uint8 authorizationClass, uint64 grantRevision, uint64 effectiveAt, uint64 recordedAt, bytes32 reasonHash, bytes32 schemaHash, bytes32 profileHash, bytes32 canonicalizationHash) observation) referenceRender, (bytes32 scopeSubject, bytes32 workDescriptionRecordHash, bytes32 rightsStatementRecordHash, bytes32 workPayloadHash, bytes32 rightsPayloadHash, bytes32 workSelectionHash, bytes32 rightsSelectionHash, uint64 workRevision, uint64 rightsRevision) descriptions, ((bytes32 recordHash, uint8 kind, bytes32 payloadHash, address recorder, uint64 recordedAt, uint64 recordIndex, bytes32 recordChainHash, bytes32 receiptHash, (bytes32 attestationRecordHash, bytes32 artistId, bytes32 bindingHash, uint64 bindingGeneration, address signer, uint8 authorityClass, uint32 requiredCapability, uint64 signedAt, bytes32 publicationHash) publication, bytes32 publicationEvidenceHash) record, (bytes32 artistId, bytes32 bindingHash, uint64 generation, bytes32 identityRecordHash) association, uint8 origin, uint8 interviewStatus, (bytes32 recordHash, uint8 kind, bytes32 payloadHash, address recorder, uint64 recordedAt, uint64 recordIndex, bytes32 recordChainHash, bytes32 receiptHash, (bytes32 attestationRecordHash, bytes32 artistId, bytes32 bindingHash, uint64 bindingGeneration, address signer, uint8 authorityClass, uint32 requiredCapability, uint64 signedAt, bytes32 publicationHash) publication, bytes32 publicationEvidenceHash) interview, bytes32 interviewArchiveReferenceHash, uint8 interviewPayloadCorrespondence, bytes32 predecessor, address submitter, uint64 revision, uint64 selectedAt, bytes32 catalogsHash, bytes32 selectionHash) conservation, bytes32 interviewEvidenceHash, bytes32 nativeHash, bytes32 rootRecordHash, bytes32 tokenInventoryHash, bytes32 checkpointHash, bytes32 outputManifestRecord, bytes32 selectionId, bytes32 selectionHash, uint64 tokenCount)","uint64","uint64"],
    outputs: ["(uint8 kind, bytes32 role, address source, bytes32 sourceRecord, uint256 sourceIndex, uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri, uint64 byteSize, bytes32 schemaId, bytes32 formatId, bytes32 catalogId, bytes32 catalogHash, bytes32 objectHash, bytes32 originalCoverageHash, bytes32 provenanceHash)","uint64"]
  },
  citation: {
    selector: "0xf043d621",
    inputs: ["(address[12] targets, bytes32[12] codeHashes, address[5] artistTargets, bytes32[5] artistCodeHashes, address artistContentOwner, bytes32 artistContentOwnerCodeHash, uint256 chainId, uint256 readGas, uint256 sourceGas, uint256 selectionGas, uint256 snapshotGas, uint256 referenceGas)","((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, bytes32 subject, bytes32 artistId, (bytes32 recordHash, bytes32 scopeSubject, bytes32 predecessor, uint64 revision, bytes32 chainHash, bytes32 manifestHash, uint32 manifestBytes, bytes32 sourceHash, address publisher, uint8 authorizationClass, uint64 grantRevision, uint8 displayAuthorizationClass, uint64 displayGrantRevision, uint64 recordedAt, bytes32 schemaHash, bytes32 profileHash, bytes32 canonicalizationHash) snapshot, ((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, (bytes32 scopeSubject, bytes32 scopeManifestHash, bytes32 sourceRecordHash, uint256 tokenCount, bytes32 tokenListHash, bytes32 membershipHash, uint256 inventoryCount, bytes32 inventoryPrefixHash) membership, (bool locked, address registry, bytes32 registryCodeHash, bytes32 artistId, uint64 bindingGeneration, bytes32 bindingHash, address nominatedArtist, bytes32 identityRecordHash, bytes32 acceptanceRecordHash, uint64 acceptedAt, uint64 lockedAt, bytes32 snapshotHash) artist, ((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, bytes32 membershipHash, bytes32 collectionStateHash, uint64 tokenCount, uint64 nextIndex, bytes32 selectionRoot) selection, (bytes32 selectionId, bytes32 selectionHash, bytes32 inventoryHash, bytes32 policyChainHash, (uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, uint64 tokenCount, uint64 nextIndex, bytes32 leafChainHash, bytes32 contentRoot, bytes32 outputRoot) content, (bytes32 checkpointHash, bytes32 checkpointStateHash, address entropySourceSet, bytes32 inventoryHash, bytes32 policyChainHash, bytes32 artifactHash, bytes32 coverageHash, bytes32 artistId, bytes32 contentRoot, bytes32 outputRoot, bytes32 manifestHash, (uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, uint64 tokenCount, uint64 byteLength) outputs, address sourceFactory, bytes32 sourceFactoryCodeHash, bytes32 factoryDependenciesHash, (bytes32 planId, bytes32 inventoryHash, bytes32 policyChainHash, uint256 policyCount, bool allFrozen, (address coordinator, bytes32 indexedCodeHash, uint256 firstTokenIndex, bool frozen, bytes32 moduleVersion, bytes32 moduleManifestHash, bytes32 moduleSchemaHash, bytes32 deploymentManifestHash, bytes32 policyHash, address provider, uint32 epoch, bytes32 salt, bytes32 componentDataHash, bool explicitPolicy, (bool configured, bool explicitPolicy, bool frozen, uint8 mode, uint8 securityClass, uint8 renderRequirement, uint64 revision, uint32 providerEpoch, bytes32 policyHash, bytes32 contentStateHash, bytes32 lastActionId, bytes32 artistConsentRecord) collectionPolicy)[] policies) entropy) snapshotSource, (bytes32 scopeSubject, (bytes32 recordHash, bytes32 recordChainHash, uint256 collectionId, bytes32 referenceId, bytes32 predecessor, uint64 revision, bytes32 payloadHash, uint32 payloadBytes, bytes32 sourcesHash, bytes32 snapshotRecordHash, uint64 snapshotRevision, address recorder, uint8 authorizationClass, uint64 grantRevision, uint64 effectiveAt, uint64 recordedAt, bytes32 reasonHash, bytes32 schemaHash, bytes32 profileHash, bytes32 canonicalizationHash) observation) referenceRender, (bytes32 scopeSubject, bytes32 workDescriptionRecordHash, bytes32 rightsStatementRecordHash, bytes32 workPayloadHash, bytes32 rightsPayloadHash, bytes32 workSelectionHash, bytes32 rightsSelectionHash, uint64 workRevision, uint64 rightsRevision) descriptions, ((bytes32 recordHash, uint8 kind, bytes32 payloadHash, address recorder, uint64 recordedAt, uint64 recordIndex, bytes32 recordChainHash, bytes32 receiptHash, (bytes32 attestationRecordHash, bytes32 artistId, bytes32 bindingHash, uint64 bindingGeneration, address signer, uint8 authorityClass, uint32 requiredCapability, uint64 signedAt, bytes32 publicationHash) publication, bytes32 publicationEvidenceHash) record, (bytes32 artistId, bytes32 bindingHash, uint64 generation, bytes32 identityRecordHash) association, uint8 origin, uint8 interviewStatus, (bytes32 recordHash, uint8 kind, bytes32 payloadHash, address recorder, uint64 recordedAt, uint64 recordIndex, bytes32 recordChainHash, bytes32 receiptHash, (bytes32 attestationRecordHash, bytes32 artistId, bytes32 bindingHash, uint64 bindingGeneration, address signer, uint8 authorityClass, uint32 requiredCapability, uint64 signedAt, bytes32 publicationHash) publication, bytes32 publicationEvidenceHash) interview, bytes32 interviewArchiveReferenceHash, uint8 interviewPayloadCorrespondence, bytes32 predecessor, address submitter, uint64 revision, uint64 selectedAt, bytes32 catalogsHash, bytes32 selectionHash) conservation, bytes32 interviewEvidenceHash, bytes32 nativeHash, bytes32 rootRecordHash, bytes32 tokenInventoryHash, bytes32 checkpointHash, bytes32 outputManifestRecord, bytes32 selectionId, bytes32 selectionHash, uint64 tokenCount)","uint64","uint64"],
    outputs: ["(uint8 kind, bytes32 role, address source, bytes32 sourceRecord, uint256 sourceIndex, uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri, uint64 byteSize, bytes32 schemaId, bytes32 formatId, bytes32 catalogId, bytes32 catalogHash, bytes32 objectHash, bytes32 originalCoverageHash, bytes32 provenanceHash)","uint64"]
  },
} as const satisfies Record<string, io.WorkerMethod>;

export type ScopedPolicyInventoryV2CodePin = io.CodePin;
export type ScopedPolicyInventoryV2Block = io.Block;
export type ScopedPolicyInventoryV2ReceiptOptions = io.ReceiptOptions;
export interface ScopedPolicyInventoryV2SegmentLocator {
  readonly transactionHash: Hex;
  readonly logIndex: number;
}
export interface ScopedPolicyInventoryV2ReadWorkers {
  readonly source: io.CodePin;
  readonly native: io.CodePin;
  readonly reference: io.CodePin;
  readonly typedReferences: io.CodePin;
  readonly originals: io.CodePin;
  readonly artist: io.CodePin;
  readonly documents: io.CodePin;
  readonly root: io.CodePin;
  readonly token: io.CodePin;
  readonly script: io.CodePin;
  readonly renderer: io.CodePin;
  readonly citation: io.CodePin;
}
/** Worker/link pins must come from reviewed deployment metadata for the frozen source. */
export interface ScopedPolicyInventoryV2Deployment {
  readonly chainId: bigint;
  readonly core: Address;
  readonly inventory: io.CodePin;
  readonly workers: ScopedPolicyInventoryV2ReadWorkers;
  readonly linkedDependencies: readonly io.CodePin[];
}
export interface ScopedPolicyInventoryV2HistoryDeployment {
  readonly chainId: bigint;
  readonly core: Address;
  readonly inventory: io.CodePin;
}
export interface ScopedPolicyInventoryV2SegmentObservation {
  readonly locator: ScopedPolicyInventoryV2SegmentLocator;
  readonly recorded: io.Block;
  readonly planId: Hex;
  readonly index: bigint;
  readonly segment: inv.ScopedPolicyInventoryV2Segment;
  readonly items: readonly inv.ScopedPolicyInventoryV2Item[];
}
export interface ScopedPolicyInventoryV2Stage {
  readonly planId: Hex;
  readonly dependencies: inv.ScopedPolicyInventoryV2Dependencies;
  readonly dependencyHash: Hex;
  readonly context: inv.ScopedPolicyInventoryV2Context;
  readonly before: inv.ScopedPolicyInventoryV2Plan;
  readonly tokenBefore: inv.ScopedPolicyInventoryV2TokenProgress;
  readonly after: inv.ScopedPolicyInventoryV2Plan;
  readonly tokenAfter: inv.ScopedPolicyInventoryV2TokenProgress;
  readonly segments: readonly ScopedPolicyInventoryV2SegmentObservation[];
  readonly appended: Readonly<{
    segment: inv.ScopedPolicyInventoryV2Segment;
    items: readonly inv.ScopedPolicyInventoryV2Item[];
  }> | null;
  readonly evidence: inv.ScopedPolicyInventoryV2Evidence | null;
  readonly existing: boolean;
}
export interface ScopedPolicyInventoryV2WorkflowCapture {
  readonly deployment: ScopedPolicyInventoryV2Deployment;
  readonly prepared: inv.ScopedPolicyInventoryV2Call;
  readonly observed: io.Block;
  readonly gasLimit: bigint;
  readonly stage: ScopedPolicyInventoryV2Stage;
  readonly captureHash: Hex;
}
const workerRoles = ["source", "native", "reference", "typedReferences", "originals", "artist",
  "documents", "root", "token", "script", "renderer", "citation"] as const;
const zeroToken = { phase: 0n, row: 0n, count: 0n } as const;
const coder = AbiCoder.defaultAbiCoder();
const host = () => inv.scopedPolicyInventoryV2Interface();
const MAX_SEGMENTS = 16_384;
const workAbi = new Interface([
  "function workSelectionAt(uint256 collectionId, bytes32 subjectId, uint64 revision) view returns ((bytes32 recordHash, bytes32 predecessor, bytes32 payloadHash, address submitter, uint8 mode, uint256 grantScope, uint64 grantRevision, uint64 revision, uint64 recordIndex, bytes32 recordChainHash, uint64 selectedAt, uint8 selectorAuthorizationClass, address recorder, uint8 recorderAuthorizationClass, uint8 form, uint8 creatorKind, (bytes32 artistId, bytes32 bindingHash, uint64 generation, bytes32 identityRecordHash) creatorAssociation, (bytes32 attestationRecordHash, bytes32 artistId, bytes32 bindingHash, uint64 bindingGeneration, address signer, uint8 authorityClass, uint32 requiredCapability, uint64 signedAt, bytes32 publicationHash) artistPublication, bytes32 artistPublicationEvidenceHash, bytes32 catalogId, bytes32 catalogHash, bytes32 selectionHash))"
]);

function deployment(input: ScopedPolicyInventoryV2Deployment): ScopedPolicyInventoryV2Deployment {
  io.keys(input, ["chainId", "core", "inventory", "workers", "linkedDependencies"]);
  io.keys(input.workers, workerRoles);
  return io.freeze({ chainId: io.uint(input.chainId), core: io.address(input.core), inventory: io.codePin(input.inventory),
    workers: Object.fromEntries(workerRoles.map(key => [key, io.codePin(input.workers[key])])) as unknown as ScopedPolicyInventoryV2ReadWorkers,
    linkedDependencies: io.pinList(input.linkedDependencies) });
}
function historicalDeployment(input: ScopedPolicyInventoryV2HistoryDeployment): ScopedPolicyInventoryV2HistoryDeployment {
  io.keys(input, ["chainId", "core", "inventory"]);
  return io.freeze({ chainId: io.uint(input.chainId), core: io.address(input.core), inventory: io.codePin(input.inventory) });
}
function coordinates(d: ScopedPolicyInventoryV2HistoryDeployment): inv.ScopedPolicyInventoryV2Coordinates {
  return { chainId: d.chainId, core: d.core, inventory: d.inventory.address };
}
function locators(input: readonly ScopedPolicyInventoryV2SegmentLocator[]): readonly ScopedPolicyInventoryV2SegmentLocator[] {
  if (!Array.isArray(input) || input.length > MAX_SEGMENTS) throw Error("Segment locator limit exceeded");
  const result = input.map(value => {
    io.keys(value, ["transactionHash", "logIndex"]);
    return { transactionHash: io.hash(value.transactionHash), logIndex: io.number(value.logIndex) };
  });
  if (new Set(result.map(value => `${value.transactionHash}:${value.logIndex}`)).size !== result.length) {
    throw Error("Duplicate segment locator");
  }
  return io.freeze(result);
}
async function read<T>(p: io.Reader, d: ScopedPolicyInventoryV2HistoryDeployment, method: string, args: readonly unknown[], tag: number) {
  return io.read<T>(p, d.inventory.address, host(), method, args, tag);
}
async function computation(
  p: io.Reader, d: ScopedPolicyInventoryV2Deployment, role: keyof ScopedPolicyInventoryV2ReadWorkers,
  method: keyof typeof workers, args: readonly unknown[], tag: number, cap: bigint
) {
  return io.worker(p, d.workers[role], workers[method], args, tag, cap);
}
async function bindings(p: io.Reader, d: ScopedPolicyInventoryV2HistoryDeployment, tag: number) {
  await io.runtime(p, d.inventory, tag);
  const deps = inv.normalizeScopedPolicyInventoryV2Dependencies(await read(p, d, "dependencies", [], tag));
  if (deps.chainId !== d.chainId || !io.same(deps.targets[0], d.core)) throw Error("Inventory deployment binding differs");
  const dependencyHash = inv.scopedPolicyInventoryV2DependencyHash(deps);
  io.equal(await read(p, d, "dependencyHash", [], tag), dependencyHash, "Inventory dependency hash differs");
  io.equal(await read(p, d, "scopedPolicyInventoryProfile", [], tag), inv.SCOPED_POLICY_INVENTORY_V2_PROFILE, "Wrong inventory profile");
  io.equal(await read(p, d, "supportsInterface", [inv.SCOPED_POLICY_INVENTORY_V2_INTERFACE_ID], tag), true, "Missing original inventory capability");
  const names = [["core", 0], ["metadataHost", 1], ["metadataRouter", 4], ["snapshots", 5],
    ["referencePublisher", 6], ["artifactCoverage", 10], ["externalCoverage", 11]] as const;
  for (const [name, slot] of names) io.equal(await read(p, d, name, [], tag), deps.targets[slot], "Named inventory dependency differs");
  return { deps, dependencyHash };
}
async function sourceBindings(p: io.Reader, d: ScopedPolicyInventoryV2Deployment, tag: number) {
  const bound = await bindings(p, d, tag);
  const deps = bound.deps;
  await io.runtimes(p, [...deps.targets.map((address, i) => ({ address, codeHash: deps.codeHashes[i]! })),
    ...deps.artistTargets.map((address, i) => ({ address, codeHash: deps.artistCodeHashes[i]! })),
    { address: deps.artistContentOwner, codeHash: deps.artistContentOwnerCodeHash },
    ...workerRoles.map(role => d.workers[role]), ...d.linkedDependencies], tag);
  return bound;
}

/** Authentic local Item history. It does not reauthorize today's source or archival state. */
export async function inspectScopedPolicyInventoryV2Segment(
  p: io.ReceiptReader,
  inputDeployment: ScopedPolicyInventoryV2HistoryDeployment,
  inputLocator: ScopedPolicyInventoryV2SegmentLocator,
  options: { readonly blockTag: number }
): Promise<ScopedPolicyInventoryV2SegmentObservation> {
  const d = historicalDeployment(inputDeployment);
  const locator = locators([inputLocator])[0]!;
  io.keys(options, ["blockTag"]);
  const tag = io.number(options.blockTag);
  const observed = await io.chain(p, d.chainId, tag);
  await bindings(p, d, tag);
  const tx = await io.mined(p, d.chainId, locator.transactionHash);
  if (tx.observed.blockNumber > tag) throw Error("Segment event is later than selected history block");
  await io.runtime(p, d.inventory, tx.observed.blockNumber);
  const matches = io.events(tx.logs, d.inventory.address, host(), "ScopedInventorySegmentRecorded")
    .filter(event => event.index === locator.logIndex);
  if (matches.length !== 1) throw Error("Missing exact inventory segment event");
  const event = matches[0]!.fields;
  if (event.schemaVersion !== 2n) throw Error("Wrong inventory segment schema");
  const planId = io.hash(event.id);
  const index = io.uint(event.index, 64);
  const segment = inv.normalizeScopedPolicyInventoryV2Segment(event.segment as inv.ScopedPolicyInventoryV2Segment);
  const rawRows = event.items;
  if (!Array.isArray(rawRows) || rawRows.length > io.MAX_ROWS) throw Error("Inventory row limit exceeded");
  const items = rawRows.map(inv.normalizeScopedPolicyInventoryV2Item);
  const expected = inv.scopedPolicyInventoryV2Segment(inv.scopedPolicyInventoryV2SegmentKey(planId, index), segment.sourceWitnessHash, items);
  io.equal(segment, expected, "Event Item chain differs");
  io.equal(inv.normalizeScopedPolicyInventoryV2Segment(await read(p, d, "inventorySegment", [planId, index], tag)), segment,
    "Event segment differs from retained inventory");
  await io.unchanged(p, observed);
  return io.freeze({ locator, recorded: tx.observed, planId, index, segment, items });
}

async function segmentHistory(
  p: io.ReceiptReader, d: ScopedPolicyInventoryV2HistoryDeployment, planId: Hex,
  plan: inv.ScopedPolicyInventoryV2Plan, input: readonly ScopedPolicyInventoryV2SegmentLocator[], tag: number
) {
  if (plan.progress.segmentCount > BigInt(MAX_SEGMENTS) || input.length !== Number(plan.progress.segmentCount)) {
    throw Error("Complete prior segment locators are required");
  }
  let chain = io.ZERO;
  let itemCount = 0n;
  const result: ScopedPolicyInventoryV2SegmentObservation[] = [];
  for (let index = 0; index < input.length; index++) {
    const row = await inspectScopedPolicyInventoryV2Segment(p, d, input[index]!, { blockTag: tag });
    if (row.planId !== planId || row.index !== BigInt(index)) throw Error("Segment identity/order differs");
    if (result.length && (row.recorded.blockNumber < result[result.length - 1]!.recorded.blockNumber
      || (row.recorded.blockNumber === result[result.length - 1]!.recorded.blockNumber
        && row.locator.logIndex <= result[result.length - 1]!.locator.logIndex))) throw Error("Segment chronology differs");
    result.push(row);
    chain = inv.scopedPolicyInventoryV2AppendSegment(chain, row.index, row.segment);
    itemCount += row.segment.itemCount;
    if (itemCount > BigInt(io.MAX_ROWS)) throw Error("Complete inventory client row limit exceeded");
  }
  io.equal(chain, plan.progress.segmentChainHash, "Retained segment chain differs");
  io.equal(itemCount, plan.progress.itemCount, "Retained item count differs");
  return io.freeze(result);
}
function definitionStart(plan: inv.ScopedPolicyInventoryV2Plan, segments: readonly ScopedPolicyInventoryV2SegmentObservation[]): number {
  let cursor = 0;
  for (const count of [plan.nativeCount, plan.referenceCount]) {
    let total = 0n;
    while (total < count && cursor < segments.length) total += segments[cursor++]!.segment.itemCount;
    if (count === 0n || total !== count) throw Error("Native/reference segment partition differs");
  }
  return cursor + 5; // WORK, RIGHTS, parent, interview, root authorization.
}
function zero(type: ParamType): unknown {
  if (type.baseType === "array") return type.arrayLength === -1 ? [] : Array.from({ length: type.arrayLength! }, () => zero(type.arrayChildren!));
  if (type.baseType === "tuple") return Object.fromEntries(type.components!.map(p => [p.name, zero(p)]));
  if (type.type === "address") return io.ZERO_ADDRESS;
  if (type.type === "bool") return false;
  if (type.type === "string") return "";
  if (type.type === "bytes") return "0x";
  if (type.type.startsWith("bytes")) return `0x${"00".repeat(Number(type.type.slice(5)))}`;
  return 0n;
}
function originalContext(c: inv.ScopedPolicyInventoryV2Context) {
  const empty = zero(ParamType.from(workers.originals.inputs[1]!)) as Record<string, unknown>;
  return { ...empty, collectionId: c.scope.collectionId, subject: c.subject };
}
function rows(value: unknown): readonly inv.ScopedPolicyInventoryV2Item[] {
  if (!Array.isArray(value) || value.length > io.MAX_ROWS) throw Error("Inventory row limit exceeded");
  return value.map(inv.normalizeScopedPolicyInventoryV2Item);
}

type Mutable<T> = T extends readonly (infer V)[] ? Mutable<V>[] : T extends object ? { -readonly [K in keyof T]: Mutable<T[K]> } : T;
function evidence(
  d: ScopedPolicyInventoryV2HistoryDeployment, dependencyHash: Hex, planId: Hex,
  c: inv.ScopedPolicyInventoryV2Context, plan: inv.ScopedPolicyInventoryV2Plan
): inv.ScopedPolicyInventoryV2Evidence {
  const result = {
    scope: c.scope,
    inventory: {
      planId, collectionId: c.scope.collectionId, scopeSubject: c.subject, artistId: c.artistId,
      originals: {
        rootRecordHash: c.rootRecordHash, snapshotRecordHash: c.snapshot.recordHash,
        referenceRenderRecordHash: c.referenceRender.observation.recordHash,
        intentRecordHash: c.conservation.record.kind === 1n ? c.conservation.record.recordHash : io.ZERO,
        intentWaiverRecordHash: c.conservation.record.kind === 2n ? c.conservation.record.recordHash : io.ZERO,
        interviewEvidenceHash: c.interviewEvidenceHash,
        rightsStatementRecordHash: c.descriptions.rightsStatementRecordHash,
        workDescriptionRecordHash: c.descriptions.workDescriptionRecordHash
      },
      sourceContextHash: plan.progress.sourceContextHash, tokenInventoryHash: c.tokenInventoryHash,
      tokenCount: c.tokenCount, segmentCount: plan.progress.segmentCount, itemCount: plan.progress.itemCount,
      segmentChainHash: plan.progress.segmentChainHash, renderCriticalEvidenceHash: io.ZERO
    }
  };
  return inv.normalizeScopedPolicyInventoryV2Evidence({ ...result, inventory: { ...result.inventory,
    renderCriticalEvidenceHash: inv.scopedPolicyInventoryV2EvidenceHash(coordinates(d), dependencyHash, result) } });
}

async function documentPins(
  p: io.Reader, d: ScopedPolicyInventoryV2Deployment, deps: inv.ScopedPolicyInventoryV2Dependencies,
  c: inv.ScopedPolicyInventoryV2Context, plan: inv.ScopedPolicyInventoryV2Plan,
  segments: readonly ScopedPolicyInventoryV2SegmentObservation[], tag: number, cap: bigint
) {
  const first = definitionStart(plan, segments);
  if (segments[first - 1]?.segment.sourceWitnessHash !== c.rootRecordHash || segments.length < first + 31) {
    throw Error("Incomplete original definition stage");
  }
  const selected = new Map<Hex, Hex>();
  for (let i = 0; i < 31; i++) {
    const definition = inv.scopedPolicyInventoryV2Definition(BigInt(i));
    const segment = segments[first + i]!;
    const item = segment.items[0];
    if (segment.items.length !== 1 || !item || item.kind !== 3n || item.catalogId !== definition.id
      || item.catalogHash !== definition.contentHash || item.byteSize !== definition.byteLength) {
      throw Error("Fixed definition identity/order differs");
    }
    selected.set(item.catalogId, item.provenanceHash);
  }
  // Only original token renderer/citation documents join the producer's dynamic pin inventory.
  for (const segment of segments.slice(first + 31)) for (const item of segment.items) {
    if (item.kind !== 3n) continue;
    io.hash(item.catalogId);
    io.hash(item.provenanceHash);
    const previous = selected.get(item.catalogId);
    if (previous !== undefined && previous !== item.provenanceHash) throw Error("Conflicting repeated document facts");
    selected.set(item.catalogId, item.provenanceHash);
  }
  for (const [documentId, expected] of selected) {
    const [actual] = await computation(p, d, "documents", "documentFacts", [deps, documentId], tag, cap);
    io.equal(actual, expected, "Retained interpretation document changed");
  }
}

async function predictedStage(
  p: io.ReceiptReader, d: ScopedPolicyInventoryV2Deployment, prepared: inv.ScopedPolicyInventoryV2Call,
  deps: inv.ScopedPolicyInventoryV2Dependencies, dependencyHash: Hex, c: inv.ScopedPolicyInventoryV2Context,
  planId: Hex, before: inv.ScopedPolicyInventoryV2Plan, tokenBefore: inv.ScopedPolicyInventoryV2TokenProgress,
  segments: readonly ScopedPolicyInventoryV2SegmentObservation[], tag: number, cap: bigint
): Promise<ScopedPolicyInventoryV2Stage> {
  const q = prepared.request;
  const after = structuredClone(before) as Mutable<inv.ScopedPolicyInventoryV2Plan>;
  const tokenAfter = structuredClone(tokenBefore) as Mutable<inv.ScopedPolicyInventoryV2TokenProgress>;
  const existing = before.progress.collectionId !== 0n;
  let appended: ScopedPolicyInventoryV2Stage["appended"] = null;
  let completed: ScopedPolicyInventoryV2Stage["evidence"] = null;
  const base = () => ({ planId, dependencies: deps, dependencyHash, context: c, before, tokenBefore,
    after: inv.normalizeScopedPolicyInventoryV2Plan(after), tokenAfter: inv.normalizeScopedPolicyInventoryV2TokenProgress(tokenAfter),
    segments, appended, evidence: completed, existing });
  if (q.kind === "beginInventory") {
    if (!existing) {
      Object.assign(after, { scope: c.scope, progress: { ...after.progress, collectionId: c.scope.collectionId,
        subject: c.subject, artistId: c.artistId, sourceContextHash: inv.scopedPolicyInventoryV2ContextHash(c), tokenCount: c.tokenCount } });
    }
    return base();
  }
  if (!existing || before.progress.renderCriticalEvidenceHash !== io.ZERO) throw Error("Inventory is missing or completed");
  inv.validateScopedPolicyInventoryV2Stage(before, tokenBefore, q);
  let items: readonly inv.ScopedPolicyInventoryV2Item[] = [];
  let witnessHash = io.ZERO;
  const originalRows = async (recordHash: Hex, payloadHash: Hex) => rows((await computation(p, d, "originals", "originals",
    [deps, originalContext(c), recordHash, payloadHash], tag, cap))[0]);
  const artistRow = async (publication: inv.ScopedPolicyInventoryV2PublicationEvidence, recordHash: Hex, actor: Address) =>
    inv.normalizeScopedPolicyInventoryV2Item((await computation(p, d, "artist", "artist", [deps, publication, recordHash, actor], tag, cap))[0] as inv.ScopedPolicyInventoryV2Item);
  const typedRows = async (method: "work" | "rights" | "intent" | "waiver" | "interview", recordHash: Hex, payloadHash: Hex, witness: unknown) =>
    rows((await computation(p, d, "typedReferences", method, [deps.targets[1], recordHash, payloadHash, witness], tag, cap))[0]);
  if (q.kind === "appendNative" || q.kind === "appendReference") {
    const native = q.kind === "appendNative";
    const cursor = native ? before.nativeCursor : before.referenceCursor;
    const argument = native ? c : { scope: c.scope, subject: c.subject, artistId: c.artistId, snapshot: c.snapshot, referenceRender: c.referenceRender };
    const result = await computation(p, d, native ? "native" : "reference", native ? "nativeItems" : "referenceItems",
      [deps, argument, cursor, q.maximum], tag, cap);
    items = rows(result[0]);
    const total = io.uint(result[1], 64);
    const savedCount = native ? before.nativeCount : before.referenceCount;
    if (total > BigInt(io.MAX_ROWS) || cursor >= total || items.length === 0
      || BigInt(items.length) !== (total - cursor < q.maximum ? total - cursor : q.maximum)
      || (cursor !== 0n && total !== savedCount)) throw Error("Original page length/count differs");
    witnessHash = keccak256(coder.encode(["bytes32", "uint64", "uint64"], [before.progress.sourceContextHash, cursor, total])) as Hex;
    if (native) { after.nativeCount = total; after.nativeCursor = cursor + BigInt(items.length); }
    else { after.referenceCount = total; after.referenceCursor = cursor + BigInt(items.length); }
    if (cursor + BigInt(items.length) === total) after.progress.completedStages++;
  } else if (q.kind === "appendWork") {
    const refs = await typedRows("work", c.descriptions.workDescriptionRecordHash, c.descriptions.workPayloadHash, q.witness);
    await computation(p, d, "documents", "catalogs", [deps, refs], tag, cap);
    const original = [...await originalRows(c.descriptions.workDescriptionRecordHash, c.descriptions.workPayloadHash)];
    const selected = await io.read<{ recordHash: Hex; selectionHash: Hex; artistPublication: inv.ScopedPolicyInventoryV2PublicationEvidence }>(
      p, deps.targets[7], workAbi, "workSelectionAt", [c.scope.collectionId, c.subject, c.descriptions.workRevision], tag, undefined, deps.readGas);
    if (selected.recordHash !== c.descriptions.workDescriptionRecordHash || selected.selectionHash !== c.descriptions.workSelectionHash) {
      throw Error("Original WORK selection differs");
    }
    if (selected.artistPublication.attestationRecordHash !== io.ZERO) original.push(await artistRow(selected.artistPublication, selected.recordHash, q.originalActor));
    else if (q.originalActor !== io.ZERO_ADDRESS) throw Error("Unexpected original WORK actor");
    items = [...original, ...refs];
    witnessHash = c.descriptions.workSelectionHash;
    after.progress.completedStages = 3n;
  } else if (q.kind === "appendRights") {
    items = [...await originalRows(c.descriptions.rightsStatementRecordHash, c.descriptions.rightsPayloadHash),
      ...await typedRows("rights", c.descriptions.rightsStatementRecordHash, c.descriptions.rightsPayloadHash, q.witness)];
    witnessHash = c.descriptions.rightsSelectionHash;
    after.progress.completedStages = 4n;
  } else if (q.kind === "appendIntent" || q.kind === "appendIntentWaiver" || q.kind === "appendInterview") {
    const interview = q.kind === "appendInterview";
    const record = interview ? c.conservation.interview : c.conservation.record;
    if ((interview && c.conservation.interviewStatus !== 0n)
      || (!interview && record.kind !== (q.kind === "appendIntent" ? 1n : 2n))) throw Error("Selected conservation branch differs");
    const refs = await typedRows(interview ? "interview" : q.kind === "appendIntent" ? "intent" : "waiver", record.recordHash, record.payloadHash, q.witness);
    if (interview) await computation(p, d, "documents", "catalogs", [deps, refs], tag, cap);
    items = [...await originalRows(record.recordHash, record.payloadHash), await artistRow(record.publication, record.recordHash, q.originalActor), ...refs];
    witnessHash = interview ? c.interviewEvidenceHash : c.conservation.selectionHash;
    after.progress.completedStages = interview ? 6n : 5n;
  } else if (q.kind === "appendInterviewWaiver") {
    if (c.conservation.interviewStatus !== 1n || c.conservation.interview.recordHash !== io.ZERO) throw Error("Interview is not explicitly waived");
    items = [inv.normalizeScopedPolicyInventoryV2Item({
      ...zero(ParamType.from(inv.SCOPED_POLICY_INVENTORY_V2_ITEM_TUPLE)) as inv.ScopedPolicyInventoryV2Item,
      kind: 7n, role: id("INTERVIEW_ORIGINAL_EXPLICITLY_WAIVED") as Hex, source: deps.targets[1],
      sourceRecord: c.conservation.record.recordHash, provenanceHash: c.interviewEvidenceHash
    })];
    witnessHash = c.interviewEvidenceHash;
    after.progress.completedStages = 6n;
  } else if (q.kind === "appendRootAuthorization") {
    items = [inv.normalizeScopedPolicyInventoryV2Item((await computation(p, d, "root", "root",
      [deps, c, q.actor, q.observedAt, q.originalAggregate, q.originalLegacyFamilyHash], tag, cap))[0] as inv.ScopedPolicyInventoryV2Item)];
    witnessHash = c.rootRecordHash;
    after.progress.completedStages = 7n;
  } else if (q.kind === "appendDefinition") {
    const first = definitionStart(before, segments);
    if (segments[first - 1]?.segment.sourceWitnessHash !== c.rootRecordHash) throw Error("Original root segment missing");
    const index = segments.length - first;
    const definition = inv.scopedPolicyInventoryV2Definition(BigInt(index));
    items = [inv.normalizeScopedPolicyInventoryV2Item((await computation(p, d, "documents", "document",
      [deps, definition.id, definition.contentHash], tag, cap))[0] as inv.ScopedPolicyInventoryV2Item)];
    const item = items[0]!;
    if (item.kind !== 3n || item.catalogId !== definition.id || item.catalogHash !== definition.contentHash
      || item.byteSize !== definition.byteLength) throw Error("Original definition bytes differ");
    witnessHash = keccak256(coder.encode(["bytes32", inv.SCOPED_POLICY_INVENTORY_V2_ITEM_TUPLE], [definition.id, item])) as Hex;
    if (index === 30) after.progress.completedStages = 8n;
  } else if (q.kind === "sealInventory") {
    await documentPins(p, d, deps, c, before, segments, tag, cap);
    completed = evidence(d, dependencyHash, planId, c, before);
    after.progress.renderCriticalEvidenceHash = completed.inventory.renderCriticalEvidenceHash;
    return base();
  } else {
    const ordinal = before.progress.nextToken;
    const phase = tokenBefore.phase;
    let row = 0n;
    let count: bigint;
    if (q.kind === "appendTokenOutput") {
      items = rows((await computation(p, d, "token", "token", [deps, c, ordinal, q.payload], tag, cap))[0]);
      count = BigInt(items.length);
      tokenAfter.phase = 1n;
    } else if (q.kind === "appendTokenScript" || q.kind === "appendTokenLibrary") {
      items = rows((await computation(p, d, "script", "script", [deps, c, ordinal, q.kind === "appendTokenLibrary"], tag, cap))[0]);
      count = BigInt(items.length);
      tokenAfter.phase++;
    } else {
      row = tokenBefore.row;
      const kind = q.kind === "appendTokenRenderer" ? "renderer" : "citation";
      const result = await computation(p, d, kind, kind, [deps, c, ordinal, row], tag, cap);
      items = [inv.normalizeScopedPolicyInventoryV2Item(result[0] as inv.ScopedPolicyInventoryV2Item)];
      count = io.uint(result[1], 64);
      if (count === 0n || count > 256n || row >= count || (row !== 0n && tokenBefore.count !== count)) throw Error("Original token row count differs");
      tokenAfter.count = count;
      tokenAfter.row++;
      if (tokenAfter.row === count) {
        tokenAfter.row = 0n;
        tokenAfter.count = 0n;
        if (phase === 4n) { tokenAfter.phase = 0n; after.progress.nextToken++; }
        else tokenAfter.phase++;
      }
      if (items[0]!.kind === 3n) {
        const item = items[0]!;
        io.hash(item.catalogId);
        io.hash(item.provenanceHash);
        const first = definitionStart(before, segments) + 31;
        for (const old of segments.slice(first).flatMap(value => value.items)) {
          if (old.kind === 3n && old.catalogId === item.catalogId && old.provenanceHash !== item.provenanceHash) {
            throw Error("Repeated renderer document facts changed");
          }
        }
      }
    }
    witnessHash = keccak256(coder.encode(["bytes32", "bytes32", "bytes32", "uint64", "uint8", "uint64", "uint64"],
      [id("6529STREAM_SCOPED_POLICY_TOKEN_INVENTORY_SOURCE_V2"), c.checkpointHash, c.selectionHash, ordinal, phase, row, count])) as Hex;
  }
  const segment = inv.scopedPolicyInventoryV2Segment(inv.scopedPolicyInventoryV2SegmentKey(planId, before.progress.segmentCount), witnessHash, items);
  appended = { segment, items };
  after.progress.segmentChainHash = inv.scopedPolicyInventoryV2AppendSegment(before.progress.segmentChainHash, before.progress.segmentCount, segment);
  after.progress.segmentCount++;
  after.progress.itemCount += BigInt(items.length);
  if (after.progress.itemCount > BigInt(io.MAX_ROWS)) throw Error("Complete inventory client row limit exceeded");
  return base();
}

export async function captureScopedPolicyInventoryV2(
  p: io.ReceiptReader,
  inputDeployment: ScopedPolicyInventoryV2Deployment,
  inputCaller: Address,
  request: inv.ScopedPolicyInventoryV2Request,
  options: {
    readonly blockTag: number;
    readonly gasLimit: bigint;
    readonly segments: readonly ScopedPolicyInventoryV2SegmentLocator[];
  }
): Promise<ScopedPolicyInventoryV2WorkflowCapture> {
  const d = deployment(inputDeployment);
  const prepared = inv.prepareScopedPolicyInventoryV2Call(coordinates(d), io.address(inputCaller), request);
  io.keys(options, ["blockTag", "gasLimit", "segments"]);
  const tag = io.number(options.blockTag);
  const cap = io.gas(options.gasLimit);
  const retained = locators(options.segments);
  const observed = await io.chain(p, d.chainId, tag);
  const { deps, dependencyHash } = await sourceBindings(p, d, tag);
  const q = prepared.request;
  let scope: inv.ScopedPolicyInventoryV2Scope;
  if (q.kind === "beginInventory") scope = q.scope;
  else {
    const saved = inv.normalizeScopedPolicyInventoryV2Plan(await read(p, d, "plan", [q.id], tag));
    if (saved.progress.collectionId === 0n) throw Error("Unknown inventory plan");
    scope = saved.scope;
  }
  const c = inv.validateScopedPolicyInventoryV2Context(coordinates(d),
    (await computation(p, d, "source", "sourceCurrent", [deps, scope], tag, cap))[0] as inv.ScopedPolicyInventoryV2Context);
  io.equal(c.scope, scope, "Current source full scope differs");
  const planId = inv.scopedPolicyInventoryV2PlanId(coordinates(d), dependencyHash, c);
  if (q.kind !== "beginInventory" && q.id !== planId) throw Error("Retained inventory source is stale");
  // This is the actual permissionless host call, not a fabricated current-plan getter.
  const actualId = await io.read<Hex>(p, d.inventory.address, host(), "beginInventory", [scope], tag, prepared.caller, cap);
  io.equal(actualId, planId, "Original host current plan differs from reconstructed source");
  const before = inv.normalizeScopedPolicyInventoryV2Plan(await read(p, d, "plan", [planId], tag));
  const tokenBefore = inv.normalizeScopedPolicyInventoryV2TokenProgress(await read(p, d, "tokenProgress", [planId], tag));
  if (before.progress.collectionId === 0n) {
    io.equal(before, zero(ParamType.from(inv.SCOPED_POLICY_INVENTORY_V2_PLAN_TUPLE)), "Nondefault missing plan");
    io.equal(tokenBefore, zeroToken, "Nondefault missing token progress");
  } else {
    io.equal(before.scope, scope, "Retained plan scope differs");
    io.equal(inv.normalizeScopedPolicyInventoryV2Context(await read(p, d, "sourceContext", [planId], tag)), c,
      "Retained context differs from current complete source");
    if (before.progress.collectionId !== scope.collectionId || before.progress.subject !== c.subject
      || before.progress.artistId !== c.artistId || before.progress.tokenCount !== c.tokenCount
      || before.progress.sourceContextHash !== inv.scopedPolicyInventoryV2ContextHash(c)) throw Error("Retained plan source fields differ");
  }
  const hd = { chainId: d.chainId, core: d.core, inventory: d.inventory };
  const segments = await segmentHistory(p, hd, planId, before, retained, tag);
  const stage = await predictedStage(p, d, prepared, deps, dependencyHash, c, planId, before, tokenBefore, segments, tag, cap);
  await io.unchanged(p, observed);
  const result = { deployment: d, prepared, observed, gasLimit: cap, stage };
  return io.freeze({ ...result, captureHash: io.fingerprint(result) });
}
function savedCapture(input: ScopedPolicyInventoryV2WorkflowCapture): ScopedPolicyInventoryV2WorkflowCapture {
  io.keys(input, ["deployment", "prepared", "observed", "gasLimit", "stage", "captureHash"]);
  const cloned = structuredClone(input);
  const { captureHash, ...body } = cloned;
  io.equal(io.fingerprint(body), io.hash(captureHash), "Capture fingerprint differs");
  const d = deployment(body.deployment);
  const prepared = inv.normalizeScopedPolicyInventoryV2Call(body.prepared);
  io.equal(prepared.coordinates, coordinates(d), "Capture deployment/call differs");
  io.gas(body.gasLimit);
  io.number(body.observed.blockNumber);
  io.hash(body.observed.blockHash);
  io.uint(body.observed.timestamp);
  return io.freeze({ ...cloned, deployment: d, prepared });
}
function comparable(capture: ScopedPolicyInventoryV2WorkflowCapture) {
  return { deployment: capture.deployment, prepared: capture.prepared, gasLimit: capture.gasLimit, stage: capture.stage };
}
async function revalidate(p: io.ReceiptReader, saved: ScopedPolicyInventoryV2WorkflowCapture, tag: number) {
  await io.unchanged(p, saved.observed);
  if (tag < saved.observed.blockNumber) throw Error("Observation predates capture");
  const result = await captureScopedPolicyInventoryV2(p, saved.deployment, saved.prepared.caller, saved.prepared.request,
    { blockTag: tag, gasLimit: saved.gasLimit, segments: saved.stage.segments.map(segment => segment.locator) });
  io.equal(comparable(result), comparable(saved));
  return result;
}

export async function simulateScopedPolicyInventoryV2(
  p: io.ReceiptReader,
  input: ScopedPolicyInventoryV2WorkflowCapture,
  options: { readonly blockTag: number; readonly gasLimit: bigint }
) {
  const saved = savedCapture(input);
  io.keys(options, ["blockTag", "gasLimit"]);
  const tag = io.number(options.blockTag);
  const cap = io.gas(options.gasLimit);
  await revalidate(p, saved, saved.observed.blockNumber);
  const current = await revalidate(p, saved, tag);
  const raw = io.bytes(await p.call({ ...current.prepared.call, from: current.prepared.caller, blockTag: tag, gasLimit: cap }));
  const kind = current.prepared.request.kind;
  const values = host().decodeFunctionResult(kind, raw);
  if (!io.same(host().encodeFunctionResult(kind, values), raw)) throw Error("Noncanonical original call result");
  if (kind === "beginInventory") io.equal(values[0], current.stage.planId, "Simulated plan differs");
  if (kind === "sealInventory") io.equal(inv.decodeScopedPolicyInventoryV2Evidence(raw), current.stage.evidence, "Simulated evidence differs");
  await io.unchanged(p, current.observed);
  return io.freeze({ capture: current, result: raw, originalCallSucceeded: true as const, gasLimit: cap,
    stateChangesPersisted: false as const });
}

export async function inspectScopedPolicyInventoryV2History(
  p: io.ReceiptReader,
  inputDeployment: ScopedPolicyInventoryV2HistoryDeployment,
  inputId: Hex,
  options: { readonly blockTag: number; readonly segments: readonly ScopedPolicyInventoryV2SegmentLocator[] }
) {
  const d = historicalDeployment(inputDeployment);
  const planId = io.hash(inputId);
  io.keys(options, ["blockTag", "segments"]);
  const tag = io.number(options.blockTag);
  const retained = locators(options.segments);
  const observed = await io.chain(p, d.chainId, tag);
  const { dependencyHash } = await bindings(p, d, tag);
  const plan = inv.normalizeScopedPolicyInventoryV2Plan(await read(p, d, "plan", [planId], tag));
  if (plan.progress.collectionId === 0n) throw Error("Unknown inventory plan");
  const context = inv.validateScopedPolicyInventoryV2Context(coordinates(d), await read(p, d, "sourceContext", [planId], tag));
  io.equal(inv.scopedPolicyInventoryV2PlanId(coordinates(d), dependencyHash, context), planId, "Retained context identity differs");
  io.equal(context.scope, plan.scope, "Retained full scope differs");
  if (plan.progress.sourceContextHash !== inv.scopedPolicyInventoryV2ContextHash(context)
    || plan.progress.collectionId !== context.scope.collectionId || plan.progress.subject !== context.subject
    || plan.progress.artistId !== context.artistId || plan.progress.tokenCount !== context.tokenCount) throw Error("Retained plan context differs");
  const tokenProgress = inv.normalizeScopedPolicyInventoryV2TokenProgress(await read(p, d, "tokenProgress", [planId], tag));
  const segments = await segmentHistory(p, d, planId, plan, retained, tag);
  let completed: inv.ScopedPolicyInventoryV2Evidence | null = null;
  if (plan.progress.renderCriticalEvidenceHash !== io.ZERO) {
    completed = inv.validateScopedPolicyInventoryV2Evidence(coordinates(d), dependencyHash, await read(p, d, "inventoryEvidence", [planId], tag));
    io.equal(completed, evidence(d, dependencyHash, planId, context, plan), "Retained evidence differs from complete plan");
    if (plan.progress.completedStages !== 8n || plan.progress.nextToken !== context.tokenCount) throw Error("Incomplete completed inventory");
    io.equal(tokenProgress, zeroToken, "Completed token cursor differs");
  }
  await io.unchanged(p, observed);
  return io.freeze({ observed, planId, plan, context, tokenProgress, segments, evidence: completed,
    currentSourceChecked: false as const });
}

export async function inspectScopedPolicyInventoryV2Current(
  p: io.ReceiptReader,
  inputDeployment: ScopedPolicyInventoryV2Deployment,
  scope: inv.ScopedPolicyInventoryV2Scope,
  options: { readonly blockTag: number; readonly gasLimit: bigint; readonly segments: readonly ScopedPolicyInventoryV2SegmentLocator[]; readonly fullDefinitionBytes?: boolean }
) {
  io.keys(options, ["blockTag", "gasLimit", "segments"], ["fullDefinitionBytes"]);
  if (options.fullDefinitionBytes !== undefined && typeof options.fullDefinitionBytes !== "boolean") throw Error("Expected diagnostic flag");
  const full = options.fullDefinitionBytes === true;
  const tag = io.number(options.blockTag);
  const cap = io.gas(options.gasLimit);
  const capture = await captureScopedPolicyInventoryV2(p, inputDeployment, inputDeployment.inventory.address,
    { kind: "beginInventory", scope }, { blockTag: tag, gasLimit: cap, segments: options.segments });
  const d = capture.deployment;
  const result = inv.validateScopedPolicyInventoryV2Evidence(coordinates(d), capture.stage.dependencyHash,
    await io.read(p, d.inventory.address, host(), "requireCurrent", [capture.stage.context.scope], tag, undefined, capture.gasLimit));
  io.equal(result, evidence(d, capture.stage.dependencyHash, capture.stage.planId, capture.stage.context, capture.stage.before), "Current evidence differs");
  if (capture.stage.before.progress.renderCriticalEvidenceHash !== result.inventory.renderCriticalEvidenceHash) throw Error("Current inventory incomplete");
  await documentPins(p, d, capture.stage.dependencies, capture.stage.context, capture.stage.before, capture.stage.segments, tag, capture.gasLimit);
  if (full) await io.rpc(p, d.inventory.address, host(), "requireFullDefinitionBytes", [capture.stage.planId], tag, undefined, capture.gasLimit);
  await io.unchanged(p, capture.observed);
  return io.freeze({ capture, evidence: result, currentSourceChecked: true as const, fullDefinitionBytesChecked: full });
}

export async function reconcileScopedPolicyInventoryV2Receipt(
  p: io.ReceiptReader,
  input: ScopedPolicyInventoryV2WorkflowCapture,
  inputHash: Hex,
  options: ScopedPolicyInventoryV2ReceiptOptions
) {
  const saved = savedCapture(input);
  const tx = await io.transport(p, { chainId: saved.deployment.chainId, caller: saved.prepared.caller,
    call: saved.prepared.call, observed: saved.observed }, io.hash(inputHash), options);
  await revalidate(p, saved, saved.observed.blockNumber);
  const prior = await revalidate(p, saved, tx.observed.blockNumber - 1);
  const d = prior.deployment;
  const tag = tx.observed.blockNumber;
  await io.runtime(p, d.inventory, tag);
  const stage = prior.stage;
  await io.runtimes(p, [...workerRoles.map(role => d.workers[role]), ...d.linkedDependencies], tag);
  io.equal(inv.normalizeScopedPolicyInventoryV2Plan(await read(p, d, "plan", [stage.planId], tag)), stage.after,
    "Receipt end-block progress differs; concurrent progress is not attributed");
  io.equal(inv.normalizeScopedPolicyInventoryV2TokenProgress(await read(p, d, "tokenProgress", [stage.planId], tag)), stage.tokenAfter,
    "Receipt end-block token cursor differs");
  io.equal(inv.normalizeScopedPolicyInventoryV2Context(await read(p, d, "sourceContext", [stage.planId], tag)), stage.context,
    "Receipt retained source context differs");
  const starts = io.events(tx.logs, d.inventory.address, host(), "ScopedInventoryStarted");
  const appends = io.events(tx.logs, d.inventory.address, host(), "ScopedInventorySegmentRecorded");
  const completes = io.events(tx.logs, d.inventory.address, host(), "ScopedInventoryCompleted");
  const kind = prior.prepared.request.kind;
  let locator: ScopedPolicyInventoryV2SegmentLocator | null = null;
  if (kind === "beginInventory") {
    if (appends.length || completes.length || starts.length !== (stage.existing ? 0 : 1)) throw Error("Unexpected inventory begin events");
    if (!stage.existing) io.one(tx.logs, d.inventory.address, host(), "ScopedInventoryStarted",
      [2n, stage.planId, stage.context.scope, stage.after.progress.sourceContextHash]);
  } else if (kind === "sealInventory") {
    if (starts.length || appends.length) throw Error("Unexpected inventory seal events");
    io.one(tx.logs, d.inventory.address, host(), "ScopedInventoryCompleted", [2n, stage.planId,
      stage.evidence!.inventory.renderCriticalEvidenceHash, stage.evidence]);
    io.equal(inv.normalizeScopedPolicyInventoryV2Evidence(await read(p, d, "inventoryEvidence", [stage.planId], tag)), stage.evidence,
      "Retained completion differs");
  } else {
    if (starts.length || completes.length) throw Error("Unexpected inventory append events");
    const event = io.one(tx.logs, d.inventory.address, host(), "ScopedInventorySegmentRecorded",
      [2n, stage.planId, stage.before.progress.segmentCount, stage.appended!.segment, stage.appended!.items]);
    io.equal(inv.normalizeScopedPolicyInventoryV2Segment(await read(p, d, "inventorySegment", [stage.planId, stage.before.progress.segmentCount], tag)),
      stage.appended!.segment, "Retained appended segment differs");
    locator = { transactionHash: tx.transactionHash, logIndex: event.index };
  }
  io.finish(tx.logs, [d.inventory.address], tx.safeIndex);
  await io.unchanged(p, tx.observed);
  return io.freeze({ observed: tx.observed, transactionHash: tx.transactionHash, planId: stage.planId,
    plan: stage.after, tokenProgress: stage.tokenAfter, appended: stage.appended, segmentLocator: locator,
    evidence: stage.evidence, precedingAndEndBlockAttribution: true as const, currentAfterReceipt: false as const });
}

export async function observeScopedPolicyInventoryV2Refusal(
  p: io.ReceiptReader,
  input: ScopedPolicyInventoryV2WorkflowCapture,
  options: { readonly blockTag: number; readonly gasLimit: bigint }
) {
  const saved = savedCapture(input);
  io.keys(options, ["blockTag", "gasLimit"]);
  const tag = io.number(options.blockTag);
  const cap = io.gas(options.gasLimit);
  await revalidate(p, saved, saved.observed.blockNumber);
  if (tag < saved.observed.blockNumber) throw Error("Refusal predates capture");
  const observed = await io.chain(p, saved.deployment.chainId, tag);
  await io.runtime(p, saved.deployment.inventory, tag);
  const local = async () => ({ plan: await read(p, saved.deployment, "plan", [saved.stage.planId], tag),
    token: await read(p, saved.deployment, "tokenProgress", [saved.stage.planId], tag) });
  const before = await local();
  let error: unknown;
  try { await p.call({ ...saved.prepared.call, from: saved.prepared.caller, blockTag: tag, gasLimit: cap }); }
  catch (failure) { error = failure; }
  if (error === undefined) throw Error("Original call did not refuse");
  const after = await local();
  await io.unchanged(p, observed);
  return { observed, error, outcome: (error as { code?: string })?.code === "CALL_EXCEPTION" ? "execution-reverted" as const : "rpc-failed" as const,
    retainedStateUnchanged: io.stable(before) === io.stable(after), rollbackProven: false as const };
}
