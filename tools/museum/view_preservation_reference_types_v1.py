"""Exact df6363 VIEW preservation reference types and original native documents.

Only unchanged neutral layouts/documents are reused. These descriptors do not
validate publication authority, archive liveness, browser execution or a full
preservation inventory. Dynamic arrays are bounded before ABI allocation; the
wire validator must additionally enforce the complete native payload/HTML caps.
"""
from .canonical import keccak256, schema_id
from .chain_abi import Array
from .policy_preservation_types_v2 import (
    PACKAGE_FILE, ENVIRONMENT, CAPTURE, REFERENCE_OBSERVATION as OBSERVATION,
    REFERENCE_RECORD as OBSERVATION_RECEIPT, EXTERNAL_OBJECT as OBJECT,
    EXTERNAL_COVERAGE as COVERAGE, REFERENCE_LOCK as LOCK,
    STREAM_REFERENCE_NATIVE_ENVIRONMENT_V1_BYTES,
    STREAM_REFERENCE_PNG_OBJECT_V1_BYTES,
    STREAM_REFERENCE_RUNTIME_ZIP_OBJECT_V1_BYTES,
    STREAM_REFERENCE_NATIVE_FORMATS_V1_BYTES,
)
from .view_preservation_snapshot_types_v1 import (
    SCOPE, RECEIPT as SNAPSHOT_RECEIPT, SOURCE as SNAPSHOT_SOURCE,
    ROOT_RECORD, ROOT_BINDING,
)
from .view_preservation_output_types_v1 import OUTPUT

SOURCE_REVISION = 'df6363e571dbff8fb61c192b2282733ccb3f1af8'
MAX_PAYLOAD, MAX_HTML, MAX_SAMPLES = 524288, 262144, 2
# Reader availability bounds, not claimed native per-array/history limits.
MAX_FILES, MAX_HISTORY = 4096, 64
DEPENDENCY_ROLES = ('core', 'metadata', 'schemas', 'store', 'router',
                    'viewSnapshot', 'externalCoverage')
DEPENDENCIES = (('address',) * 7, ('bytes32',) * 7,
                'uint256', 'uint256', 'uint256', 'uint256', 'uint256')
PUBLICATION = (SCOPE, OBSERVATION)
RECEIPT = ('bytes32', OBSERVATION_RECEIPT)
SAMPLE = ('uint64', OUTPUT, COVERAGE)
SOURCE = ('bytes32', SNAPSHOT_RECEIPT, SNAPSHOT_SOURCE, 'bytes32',
          ROOT_RECORD, ROOT_BINDING, COVERAGE, Array(SAMPLE, MAX_SAMPLES))
PAYLOAD = ('bytes32', 'uint256', 'address', PUBLICATION, RECEIPT, SOURCE, 'bytes')

DOMAIN_NAMES = {
    'payload': '6529STREAM_VIEW_PRESERVATION_REFERENCE_PAYLOAD_V1',
    'source': '6529STREAM_VIEW_PRESERVATION_REFERENCE_SOURCES_V1',
    'record': '6529STREAM_VIEW_PRESERVATION_REFERENCE_RECORD_V1',
    'chain': '6529STREAM_VIEW_PRESERVATION_REFERENCE_CHAIN_V1',
    'lock': '6529STREAM_VIEW_PRESERVATION_REFERENCE_LOCK_SCOPE_V1',
    'component': '6529STREAM_LOCKED_VIEW_PRESERVATION_REFERENCE_COMPONENT_V1',
}
DOMAIN = {key: schema_id(name) for key, name in DOMAIN_NAMES.items()}
PAYLOAD_DOMAIN, SOURCE_DOMAIN = DOMAIN['payload'], DOMAIN['source']
RECORD_DOMAIN, CHAIN_DOMAIN = DOMAIN['record'], DOMAIN['chain']
LOCK_SCOPE_DOMAIN, COMPONENT_DOMAIN = DOMAIN['lock'], DOMAIN['component']
MODULE_TYPE = schema_id('REFERENCE_RENDER')
MODULE_VERSION = schema_id('STREAM_VIEW_PRESERVATION_REFERENCE_RENDER_IMPLEMENTATION_V1')
RAW_BYTES = schema_id('RAW_BYTES')
GAS_IDS = {name: schema_id('6529STREAM_GGP_VIEW_PRESERVATION_REFERENCE_' + name)
           for name in ('READ_GAS', 'SOURCE_GAS', 'SNAPSHOT_GAS', 'ARCHIVE_GAS')}

# Canonical function signatures retain fixed arrays as arrays, not tuple aliases.
SCOPE_SIGNATURE = '(uint8,uint256,uint256,bytes32)'
PACKAGE_FILE_SIGNATURE = '(string,uint64,bytes32)'
ENVIRONMENT_SIGNATURE = (
    '(bytes32,bytes32,bytes32,uint32,string,string,bytes32,string,string,bytes32,'
    'string,string,' + PACKAGE_FILE_SIGNATURE + '[],' + PACKAGE_FILE_SIGNATURE +
    '[],string,string,string,uint16,uint16,uint8,string,bool,bytes32,string)')
CAPTURE_SIGNATURE = (
    '(uint256,uint256,bytes32,bytes32,uint32,bytes,bytes32,bytes32,bytes32,'
    'bytes32[2],bytes32,uint64)')
OBSERVATION_SIGNATURE = (
    '(uint256,bytes32,bytes32,uint64,bytes32,uint64,bytes32,' + CAPTURE_SIGNATURE +
    '[],' + ENVIRONMENT_SIGNATURE + ',string,uint64,bytes32)')
PUBLICATION_SIGNATURE = '(' + SCOPE_SIGNATURE + ',' + OBSERVATION_SIGNATURE + ')'
OBSERVATION_RECEIPT_SIGNATURE = (
    '(bytes32,bytes32,uint256,bytes32,bytes32,uint64,bytes32,uint32,bytes32,'
    'bytes32,uint64,address,uint8,uint64,uint64,uint64,bytes32,bytes32,bytes32,bytes32)')
RECEIPT_SIGNATURE = '(bytes32,' + OBSERVATION_RECEIPT_SIGNATURE + ')'
LOCK_SIGNATURE = '(bytes32,uint64,bytes32,uint64)'

# Exact directly declared IStreamViewPreservationReferencePublicationV1 surface.
# IERC165's inherited selector is deliberately excluded from its interface ID.
FUNCTIONS = {
    'core': ((), ('address',)),
    'metadataHost': ((), ('address',)),
    'metadataRouter': ((), ('address',)),
    'snapshots': ((), ('address',)),
    'archiveCoverage': ((), ('address',)),
    'dependencies': ((), (DEPENDENCIES,)),
    'prepareFileInventory': ((Array(PACKAGE_FILE, MAX_FILES), 'bool'), ('bytes32',)),
    'preparedFileInventory': (('bytes32',), ('bytes',)),
    'previewReference': ((PUBLICATION, 'address'), ('bytes32', 'bytes')),
    'publishReference': ((PUBLICATION,), ('bytes32',)),
    'currentReference': ((SCOPE,), (RECEIPT,)),
    'referenceRecord': (('bytes32',), (PUBLICATION, RECEIPT)),
    'referencePayload': (('bytes32',), ('bytes',)),
    'referenceSource': (('bytes32',), (SOURCE,)),
    'referenceCount': ((SCOPE,), ('uint256',)),
    'referenceAt': ((SCOPE, 'uint256'), ('bytes32',)),
    'requireCurrent': ((SCOPE, 'bytes32', 'uint64'), (RECEIPT,)),
    'referenceLock': ((SCOPE,), (LOCK,)),
    'lockTransition': ((SCOPE,), ('bytes32', 'bytes32', 'bytes32')),
    'lockReference': ((SCOPE,), ()),
}
SIGNATURES = {
    **{name: name + '()' for name in ('core', 'metadataHost', 'metadataRouter',
                                    'snapshots', 'archiveCoverage', 'dependencies')},
    'prepareFileInventory': 'prepareFileInventory(' + PACKAGE_FILE_SIGNATURE + '[],bool)',
    'preparedFileInventory': 'preparedFileInventory(bytes32)',
    'previewReference': 'previewReference(' + PUBLICATION_SIGNATURE + ',address)',
    'publishReference': 'publishReference(' + PUBLICATION_SIGNATURE + ')',
    **{name: name + '(' + SCOPE_SIGNATURE + ')' for name in
       ('currentReference', 'referenceCount', 'referenceLock', 'lockTransition', 'lockReference')},
    **{name: name + '(bytes32)' for name in
       ('referenceRecord', 'referencePayload', 'referenceSource')},
    'referenceAt': 'referenceAt(' + SCOPE_SIGNATURE + ',uint256)',
    'requireCurrent': 'requireCurrent(' + SCOPE_SIGNATURE + ',bytes32,uint64)',
}
SELECTORS = {name: keccak256(value.encode('ascii'))[:10] for name, value in SIGNATURES.items()}


def _interface_id(names, selectors):
    value = 0
    for name in names:
        value ^= int(selectors[name], 16)
    return '0x' + value.to_bytes(4, 'big').hex()


INTERFACE_ID = _interface_id(FUNCTIONS, SELECTORS)
PREPARATION_SIGNATURES = {
    'prepareFileInventoryPart': 'prepareFileInventoryPart(' + PACKAGE_FILE_SIGNATURE + '[],bool)',
    'prepareFileInventoryFromParts': 'prepareFileInventoryFromParts(' + PACKAGE_FILE_SIGNATURE + '[],bool)',
    'prepareEnvironment': 'prepareEnvironment(' + ENVIRONMENT_SIGNATURE + ')',
}
PREPARATION_SELECTORS = {name: keccak256(value.encode('ascii'))[:10]
                         for name, value in PREPARATION_SIGNATURES.items()}
INVENTORY_PREPARATION_INTERFACE_ID = _interface_id(
    ('prepareFileInventoryPart', 'prepareFileInventoryFromParts'), PREPARATION_SELECTORS)
ENVIRONMENT_PREPARATION_INTERFACE_ID = PREPARATION_SELECTORS['prepareEnvironment']

EVENT_SIGNATURES = {
    'published': 'ViewPreservationReferencePublished(uint16,bytes32,bytes32,bytes32,' + RECEIPT_SIGNATURE + ',string)',
    'locked': 'ViewPreservationReferenceLocked(uint16,bytes32,' + LOCK_SIGNATURE + ')',
    'inventoryPartPrepared': 'ReferenceInventoryPartPrepared(uint16,bytes32,bool,uint16,bytes32,uint32)',
    'inventoryAssembled': 'ReferenceInventoryAssembled(uint16,bytes32,bool,uint256,bytes32,uint32)',
    'environmentPrepared': 'ReferenceEnvironmentPrepared(uint16,bytes32,bytes32,uint32)',
}
EVENTS = {name: schema_id(value) for name, value in EVENT_SIGNATURES.items()}
EVENT_DATA = {'published': ('uint16', RECEIPT, 'string'), 'locked': ('uint16', LOCK),
              'inventoryPartPrepared': ('uint16', 'bool', 'uint16', 'bytes32', 'uint32'),
              'inventoryAssembled': ('uint16', 'bool', 'uint256', 'bytes32', 'uint32'),
              'environmentPrepared': ('uint16', 'bytes32', 'uint32')}
EVENT_INDEXED = {'published': ('scopeSubject', 'referenceId', 'recordHash'),
                 'locked': ('scopeSubject',), 'inventoryPartPrepared': ('partId',),
                 'inventoryAssembled': ('inventoryId',), 'environmentPrepared': ('environmentId',)}
ERROR_SIGNATURES = (
    'InvalidViewPreservationReference()', 'ViewPreservationReferenceDependency(address)',
    'ViewPreservationReferenceAuthority(address)', 'ViewPreservationReferenceLineage(bytes32,bytes32)',
    'ViewPreservationReferenceLocked(bytes32)', 'ViewPreservationReferenceUnknown(bytes32)',
)
ERROR_SELECTORS = {value.split('(')[0]: keccak256(value.encode('ascii'))[:10]
                   for value in ERROR_SIGNATURES}

# The three exact native documents are appended below from immutable git blobs.
SCHEMA_BYTES = b'{"name":"STREAM_VIEW_PRESERVATION_REFERENCE_RENDER_ABI_V1","encoding":"Solidity abi.encode","canonicalization":"STREAM_VIEW_PRESERVATION_REFERENCE_CANON_V1","types":{"Publication":{"components":[{"components":[{"name":"scopeType","type":"uint8"},{"name":"collectionId","type":"uint256"},{"name":"tokenId","type":"uint256"},{"name":"scopeId","type":"bytes32"}],"name":"scope","type":"tuple"},{"components":[{"name":"collectionId","type":"uint256"},{"name":"referenceId","type":"bytes32"},{"name":"expectedHead","type":"bytes32"},{"name":"expectedRevision","type":"uint64"},{"name":"snapshotRecordHash","type":"bytes32"},{"name":"snapshotRevision","type":"uint64"},{"name":"expectedSourcesHash","type":"bytes32"},{"components":[{"name":"tokenId","type":"uint256"},{"name":"collectionSerial","type":"uint256"},{"name":"metadataJSONHash","type":"bytes32"},{"name":"htmlHash","type":"bytes32"},{"name":"htmlBytes","type":"uint32"},{"name":"animationHTML","type":"bytes"},{"name":"objectHash","type":"bytes32"},{"name":"coverageHash","type":"bytes32"},{"name":"sourceSha256","type":"bytes32"},{"name":"repeatCaptureSha256","type":"bytes32[2]"},{"name":"environmentManifestHash","type":"bytes32"},{"name":"capturedAt","type":"uint64"}],"name":"captures","type":"tuple[]"},{"components":[{"name":"objectHash","type":"bytes32"},{"name":"coverageHash","type":"bytes32"},{"name":"manifestHash","type":"bytes32"},{"name":"manifestBytes","type":"uint32"},{"name":"engineName","type":"string"},{"name":"engineVersion","type":"string"},{"name":"engineExecutableSha256","type":"bytes32"},{"name":"toolchainName","type":"string"},{"name":"toolchainVersion","type":"string"},{"name":"toolchainSha256","type":"bytes32"},{"name":"engineExecutablePath","type":"string"},{"name":"toolchainPath","type":"string"},{"components":[{"name":"path","type":"string"},{"name":"byteSize","type":"uint64"},{"name":"sha256Digest","type":"bytes32"}],"name":"packageFiles","type":"tuple[]"},{"components":[{"name":"path","type":"string"},{"name":"byteSize","type":"uint64"},{"name":"sha256Digest","type":"bytes32"}],"name":"platformPrerequisites","type":"tuple[]"},{"name":"operatingSystem","type":"string"},{"name":"operatingSystemVersion","type":"string"},{"name":"architecture","type":"string"},{"name":"viewportWidth","type":"uint16"},{"name":"viewportHeight","type":"uint16"},{"name":"devicePixelRatio","type":"uint8"},{"name":"colorSpace","type":"string"},{"name":"softwareRasterization","type":"bool"},{"name":"captureProfile","type":"bytes32"},{"name":"licenseNote","type":"string"}],"name":"environment","type":"tuple"},{"name":"manifestURI","type":"string"},{"name":"effectiveAt","type":"uint64"},{"name":"reasonHash","type":"bytes32"}],"name":"observation","type":"tuple"}],"name":"p","type":"tuple"},"Receipt":{"components":[{"name":"scopeSubject","type":"bytes32"},{"components":[{"name":"recordHash","type":"bytes32"},{"name":"recordChainHash","type":"bytes32"},{"name":"collectionId","type":"uint256"},{"name":"referenceId","type":"bytes32"},{"name":"predecessor","type":"bytes32"},{"name":"revision","type":"uint64"},{"name":"payloadHash","type":"bytes32"},{"name":"payloadBytes","type":"uint32"},{"name":"sourcesHash","type":"bytes32"},{"name":"snapshotRecordHash","type":"bytes32"},{"name":"snapshotRevision","type":"uint64"},{"name":"recorder","type":"address"},{"name":"authorizationClass","type":"uint8"},{"name":"grantRevision","type":"uint64"},{"name":"effectiveAt","type":"uint64"},{"name":"recordedAt","type":"uint64"},{"name":"reasonHash","type":"bytes32"},{"name":"schemaHash","type":"bytes32"},{"name":"profileHash","type":"bytes32"},{"name":"canonicalizationHash","type":"bytes32"}],"name":"observation","type":"tuple"}],"name":"","type":"tuple"},"SourceFacts":{"components":[{"name":"scopeSubject","type":"bytes32"},{"components":[{"name":"recordHash","type":"bytes32"},{"name":"scopeSubject","type":"bytes32"},{"name":"predecessor","type":"bytes32"},{"name":"revision","type":"uint64"},{"name":"chainHash","type":"bytes32"},{"name":"manifestHash","type":"bytes32"},{"name":"manifestBytes","type":"uint32"},{"name":"sourceHash","type":"bytes32"},{"name":"publisher","type":"address"},{"name":"authorizationClass","type":"uint8"},{"name":"grantRevision","type":"uint64"},{"name":"displayAuthorizationClass","type":"uint8"},{"name":"displayGrantRevision","type":"uint64"},{"name":"recordedAt","type":"uint64"},{"name":"schemaHash","type":"bytes32"},{"name":"profileHash","type":"bytes32"},{"name":"canonicalizationHash","type":"bytes32"}],"name":"snapshot","type":"tuple"},{"components":[{"components":[{"name":"scopeType","type":"uint8"},{"name":"collectionId","type":"uint256"},{"name":"tokenId","type":"uint256"},{"name":"scopeId","type":"bytes32"}],"name":"scope","type":"tuple"},{"components":[{"name":"scopeSubject","type":"bytes32"},{"name":"scopeManifestHash","type":"bytes32"},{"name":"sourceRecordHash","type":"bytes32"},{"name":"tokenCount","type":"uint256"},{"name":"tokenListHash","type":"bytes32"},{"name":"membershipHash","type":"bytes32"},{"name":"inventoryCount","type":"uint256"},{"name":"inventoryPrefixHash","type":"bytes32"}],"name":"membership","type":"tuple"},{"components":[{"name":"locked","type":"bool"},{"name":"registry","type":"address"},{"name":"registryCodeHash","type":"bytes32"},{"name":"artistId","type":"bytes32"},{"name":"bindingGeneration","type":"uint64"},{"name":"bindingHash","type":"bytes32"},{"name":"nominatedArtist","type":"address"},{"name":"identityRecordHash","type":"bytes32"},{"name":"acceptanceRecordHash","type":"bytes32"},{"name":"acceptedAt","type":"uint64"},{"name":"lockedAt","type":"uint64"},{"name":"snapshotHash","type":"bytes32"}],"name":"artist","type":"tuple"},{"components":[{"components":[{"components":[{"components":[{"name":"scopeType","type":"uint8"},{"name":"collectionId","type":"uint256"},{"name":"tokenId","type":"uint256"},{"name":"scopeId","type":"bytes32"}],"name":"scope","type":"tuple"},{"name":"viewId","type":"bytes32"},{"name":"viewRecordHash","type":"bytes32"},{"name":"expectedPrevious","type":"bytes32"},{"name":"rendererRegistry","type":"address"},{"name":"rendererVersionKey","type":"bytes32"},{"name":"expectedSourceHash","type":"bytes32"}],"name":"input","type":"tuple"},{"components":[{"components":[{"name":"core","type":"address"},{"name":"coreCodeHash","type":"bytes32"},{"name":"router","type":"address"},{"name":"routerCodeHash","type":"bytes32"},{"name":"artist","type":"address"},{"name":"artistCodeHash","type":"bytes32"},{"name":"finality","type":"address"},{"name":"finalityCodeHash","type":"bytes32"},{"name":"provider","type":"address"},{"name":"providerCodeHash","type":"bytes32"},{"name":"metadata","type":"address"},{"name":"metadataCodeHash","type":"bytes32"},{"name":"schemas","type":"address"},{"name":"schemasCodeHash","type":"bytes32"},{"name":"store","type":"address"},{"name":"storeCodeHash","type":"bytes32"},{"components":[{"name":"views","type":"address"},{"name":"viewsCodeHash","type":"bytes32"},{"name":"membership","type":"address"},{"name":"membershipCodeHash","type":"bytes32"},{"name":"readGas","type":"uint32"},{"name":"sourceGas","type":"uint32"}],"name":"binding","type":"tuple"}],"name":"route","type":"tuple"},{"components":[{"name":"scopeSubject","type":"bytes32"},{"name":"scopeManifestHash","type":"bytes32"},{"name":"sourceRecordHash","type":"bytes32"},{"name":"tokenCount","type":"uint256"},{"name":"tokenListHash","type":"bytes32"},{"name":"membershipHash","type":"bytes32"},{"name":"inventoryCount","type":"uint256"},{"name":"inventoryPrefixHash","type":"bytes32"}],"name":"membership","type":"tuple"},{"components":[{"name":"registry","type":"address"},{"name":"registryCodeHash","type":"bytes32"},{"name":"versionKey","type":"bytes32"},{"name":"renderer","type":"address"},{"name":"rendererCodeHash","type":"bytes32"},{"name":"rendererId","type":"bytes32"},{"name":"rendererVersion","type":"bytes32"},{"name":"contextVersion","type":"bytes32"},{"name":"schemaHash","type":"bytes32"},{"name":"readSetHash","type":"bytes32"},{"name":"registrationHash","type":"bytes32"}],"name":"renderer","type":"tuple"},{"name":"schemaHash","type":"bytes32"},{"name":"manifestSchemaHash","type":"bytes32"},{"name":"canonicalizationHash","type":"bytes32"},{"name":"manifestPayloadHash","type":"bytes32"},{"name":"viewReceiptHash","type":"bytes32"},{"name":"payloadHash","type":"bytes32"},{"name":"payloadBytes","type":"uint32"},{"name":"payloadPointers","type":"address[5]"},{"name":"payloadChunkHashes","type":"bytes32[5]"}],"name":"source","type":"tuple"},{"name":"sourceHash","type":"bytes32"},{"name":"recordHash","type":"bytes32"},{"name":"revision","type":"uint64"},{"name":"actor","type":"address"},{"name":"authorizationClass","type":"uint8"},{"name":"grantCollectionId","type":"uint256"},{"name":"grantRevision","type":"uint64"},{"name":"artistConsent","type":"bytes32"},{"name":"adoptedAt","type":"uint64"},{"components":[{"name":"revision","type":"uint64"},{"name":"transitionChain","type":"bytes32"}],"name":"aggregate","type":"tuple"}],"name":"adoption","type":"tuple"},{"components":[{"name":"core","type":"address"},{"name":"coreCodeHash","type":"bytes32"},{"name":"factory","type":"address"},{"name":"factoryCodeHash","type":"bytes32"},{"name":"sourceSet","type":"address"},{"name":"sourceSetCodeHash","type":"bytes32"},{"name":"chainId","type":"uint256"},{"components":[{"name":"scopeType","type":"uint8"},{"name":"collectionId","type":"uint256"},{"name":"tokenId","type":"uint256"},{"name":"scopeId","type":"bytes32"}],"name":"scope","type":"tuple"},{"components":[{"name":"scopeSubject","type":"bytes32"},{"name":"scopeManifestHash","type":"bytes32"},{"name":"sourceRecordHash","type":"bytes32"},{"name":"tokenCount","type":"uint256"},{"name":"tokenListHash","type":"bytes32"},{"name":"membershipHash","type":"bytes32"},{"name":"inventoryCount","type":"uint256"},{"name":"inventoryPrefixHash","type":"bytes32"}],"name":"membership","type":"tuple"},{"name":"inventoryPlan","type":"bytes32"},{"name":"inventoryHash","type":"bytes32"},{"name":"policyChainHash","type":"bytes32"},{"name":"policyCount","type":"uint256"}],"name":"policy","type":"tuple"},{"components":[{"name":"core","type":"address"},{"name":"router","type":"address"},{"name":"liveRenderer","type":"address"},{"name":"liveRendererRuntimeHash","type":"bytes32"},{"name":"preservationAttribution","type":"address"},{"name":"preservationAttributionRuntimeHash","type":"bytes32"}],"name":"preservation","type":"tuple"},{"components":[{"name":"registry","type":"address"},{"name":"registryCodeHash","type":"bytes32"},{"name":"versionKey","type":"bytes32"},{"name":"registrationHash","type":"bytes32"},{"name":"readSetHash","type":"bytes32"},{"name":"analysisHash","type":"bytes32"},{"name":"goldenHash","type":"bytes32"}],"name":"admission","type":"tuple"},{"name":"contextHash","type":"bytes32"}],"name":"adoption","type":"tuple"},{"components":[{"components":[{"name":"scopeType","type":"uint8"},{"name":"collectionId","type":"uint256"},{"name":"tokenId","type":"uint256"},{"name":"scopeId","type":"bytes32"}],"name":"scope","type":"tuple"},{"name":"adoptionRecord","type":"bytes32"},{"name":"sourceContextHash","type":"bytes32"},{"name":"membershipHash","type":"bytes32"},{"name":"policyChainHash","type":"bytes32"},{"name":"tokenCount","type":"uint64"},{"name":"nextIndex","type":"uint64"},{"name":"rowChain","type":"bytes32"},{"name":"outputRoot","type":"bytes32"},{"name":"contentRoot","type":"bytes32"}],"name":"checkpoint","type":"tuple"},{"components":[{"components":[{"name":"checkpointId","type":"bytes32"},{"name":"checkpointStateHash","type":"bytes32"},{"components":[{"name":"scopeType","type":"uint8"},{"name":"collectionId","type":"uint256"},{"name":"tokenId","type":"uint256"},{"name":"scopeId","type":"bytes32"}],"name":"scope","type":"tuple"},{"name":"adoptionRecord","type":"bytes32"},{"name":"sourceContextHash","type":"bytes32"},{"name":"membershipHash","type":"bytes32"},{"name":"policyChainHash","type":"bytes32"},{"name":"tokenCount","type":"uint64"},{"name":"outputRoot","type":"bytes32"},{"name":"contentRoot","type":"bytes32"}],"name":"header","type":"tuple"},{"components":[{"name":"artifactHash","type":"bytes32"},{"name":"coverageHash","type":"bytes32"},{"name":"artistId","type":"bytes32"},{"name":"contentHash","type":"bytes32"},{"name":"byteLength","type":"uint64"}],"name":"carrier","type":"tuple"},{"name":"partCount","type":"uint16"},{"name":"nextPart","type":"uint16"},{"name":"nextRow","type":"uint64"},{"name":"previousToken","type":"uint256"},{"name":"partChain","type":"bytes32"},{"name":"recordHash","type":"bytes32"}],"name":"outputs","type":"tuple"},{"components":[{"name":"planId","type":"bytes32"},{"name":"inventoryHash","type":"bytes32"},{"name":"policyChainHash","type":"bytes32"},{"name":"policyCount","type":"uint256"},{"name":"allFrozen","type":"bool"},{"components":[{"name":"coordinator","type":"address"},{"name":"indexedCodeHash","type":"bytes32"},{"name":"firstTokenIndex","type":"uint256"},{"name":"frozen","type":"bool"},{"name":"moduleVersion","type":"bytes32"},{"name":"moduleManifestHash","type":"bytes32"},{"name":"moduleSchemaHash","type":"bytes32"},{"name":"deploymentManifestHash","type":"bytes32"},{"name":"policyHash","type":"bytes32"},{"name":"provider","type":"address"},{"name":"epoch","type":"uint32"},{"name":"salt","type":"bytes32"},{"name":"componentDataHash","type":"bytes32"},{"name":"explicitPolicy","type":"bool"},{"components":[{"name":"configured","type":"bool"},{"name":"explicitPolicy","type":"bool"},{"name":"frozen","type":"bool"},{"name":"mode","type":"uint8"},{"name":"securityClass","type":"uint8"},{"name":"renderRequirement","type":"uint8"},{"name":"revision","type":"uint64"},{"name":"providerEpoch","type":"uint32"},{"name":"policyHash","type":"bytes32"},{"name":"contentStateHash","type":"bytes32"},{"name":"lastActionId","type":"bytes32"},{"name":"artistConsentRecord","type":"bytes32"}],"name":"collectionPolicy","type":"tuple"}],"name":"policies","type":"tuple[]"}],"name":"entropy","type":"tuple"}],"name":"snapshotSource","type":"tuple"},{"name":"contentRootRecordHash","type":"bytes32"},{"components":[{"components":[{"components":[{"name":"scopeType","type":"uint8"},{"name":"collectionId","type":"uint256"},{"name":"tokenId","type":"uint256"},{"name":"scopeId","type":"bytes32"}],"name":"scope","type":"tuple"},{"name":"expectedPredecessor","type":"bytes32"},{"name":"snapshotRecordHash","type":"bytes32"},{"name":"snapshotRevision","type":"uint64"},{"name":"manifestURI","type":"string"}],"name":"publication","type":"tuple"},{"name":"snapshotHost","type":"address"},{"name":"snapshotCodeHash","type":"bytes32"},{"name":"snapshotManifestHash","type":"bytes32"},{"name":"snapshotSourceHash","type":"bytes32"},{"name":"contentRoot","type":"bytes32"},{"name":"leafCount","type":"uint64"},{"name":"outputManifestHash","type":"bytes32"},{"name":"artistId","type":"bytes32"},{"name":"bindingGeneration","type":"uint64"},{"name":"bindingHash","type":"bytes32"},{"name":"publisher","type":"address"},{"name":"authorizationClass","type":"uint8"},{"name":"grantRevision","type":"uint64"},{"name":"routeHash","type":"bytes32"},{"name":"stateHash","type":"bytes32"},{"name":"artistConsent","type":"bytes32"},{"name":"publishedAt","type":"uint64"}],"name":"contentRoot","type":"tuple"},{"components":[{"name":"profileId","type":"bytes32"},{"name":"outputProfile","type":"bytes32"},{"name":"adoptionRecord","type":"bytes32"},{"name":"adoptionProfile","type":"bytes32"},{"name":"membershipHash","type":"bytes32"},{"name":"policyChainHash","type":"bytes32"},{"name":"checkpoint","type":"address"},{"name":"checkpointCodeHash","type":"bytes32"},{"name":"checkpointRecord","type":"bytes32"},{"name":"checkpointStateHash","type":"bytes32"},{"name":"outputManifest","type":"address"},{"name":"outputManifestCodeHash","type":"bytes32"},{"name":"outputManifestRecord","type":"bytes32"},{"name":"manifestIndexHash","type":"bytes32"},{"name":"partChain","type":"bytes32"},{"name":"preservationRenderer","type":"address"},{"name":"preservationRendererCodeHash","type":"bytes32"},{"name":"preservationConfigurationHash","type":"bytes32"},{"name":"liveRenderer","type":"address"},{"name":"liveRendererCodeHash","type":"bytes32"},{"name":"preservationAttribution","type":"address"},{"name":"preservationAttributionCodeHash","type":"bytes32"},{"name":"leafSchemaHash","type":"bytes32"},{"name":"rootSchemaHash","type":"bytes32"},{"name":"rootCanonicalizationHash","type":"bytes32"},{"name":"snapshotSchemaHash","type":"bytes32"},{"name":"snapshotProfileHash","type":"bytes32"},{"name":"snapshotCanonicalizationHash","type":"bytes32"}],"name":"contentBinding","type":"tuple"},{"components":[{"name":"coverageHash","type":"bytes32"},{"name":"objectHash","type":"bytes32"},{"name":"artistId","type":"bytes32"},{"name":"contentHash","type":"bytes32"},{"name":"sha256Digest","type":"bytes32"},{"name":"arweaveDataRoot","type":"bytes32"},{"name":"byteSize","type":"uint64"},{"name":"firstFamilyRecordHash","type":"bytes32"},{"name":"secondFamilyRecordHash","type":"bytes32"},{"name":"firstReceiptHash","type":"bytes32"},{"name":"secondReceiptHash","type":"bytes32"},{"name":"firstFixityHash","type":"bytes32"},{"name":"secondFixityHash","type":"bytes32"},{"name":"checkpointHash","type":"bytes32"},{"name":"profileHash","type":"bytes32"}],"name":"environmentCoverage","type":"tuple"},{"components":[{"name":"membershipIndex","type":"uint64"},{"components":[{"name":"index","type":"uint64"},{"name":"tokenId","type":"uint256"},{"name":"collectionSerial","type":"uint256"},{"name":"lifecycle","type":"uint8"},{"name":"burned","type":"bool"},{"name":"servingKind","type":"uint8"},{"name":"tokenDataHash","type":"bytes32"},{"components":[{"name":"coordinator","type":"address"},{"name":"coordinatorCodeHash","type":"bytes32"},{"name":"policyHash","type":"bytes32"},{"name":"explicitPolicy","type":"bool"},{"components":[{"name":"configured","type":"bool"},{"name":"explicitPolicy","type":"bool"},{"name":"frozen","type":"bool"},{"name":"mode","type":"uint8"},{"name":"securityClass","type":"uint8"},{"name":"renderRequirement","type":"uint8"},{"name":"revision","type":"uint64"},{"name":"providerEpoch","type":"uint32"},{"name":"policyHash","type":"bytes32"},{"name":"contentStateHash","type":"bytes32"},{"name":"lastActionId","type":"bytes32"},{"name":"artistConsentRecord","type":"bytes32"}],"name":"policy","type":"tuple"},{"name":"status","type":"uint8"},{"name":"seed","type":"bytes32"},{"name":"finalized","type":"bool"},{"name":"terminal","type":"bool"}],"name":"entropy","type":"tuple"},{"name":"jsonHash","type":"bytes32"},{"name":"htmlHash","type":"bytes32"},{"name":"jsonBytes","type":"uint32"},{"name":"htmlBytes","type":"uint32"}],"name":"output","type":"tuple"},{"components":[{"name":"coverageHash","type":"bytes32"},{"name":"objectHash","type":"bytes32"},{"name":"artistId","type":"bytes32"},{"name":"contentHash","type":"bytes32"},{"name":"sha256Digest","type":"bytes32"},{"name":"arweaveDataRoot","type":"bytes32"},{"name":"byteSize","type":"uint64"},{"name":"firstFamilyRecordHash","type":"bytes32"},{"name":"secondFamilyRecordHash","type":"bytes32"},{"name":"firstReceiptHash","type":"bytes32"},{"name":"secondReceiptHash","type":"bytes32"},{"name":"firstFixityHash","type":"bytes32"},{"name":"secondFixityHash","type":"bytes32"},{"name":"checkpointHash","type":"bytes32"},{"name":"profileHash","type":"bytes32"}],"name":"captureCoverage","type":"tuple"}],"name":"samples","type":"tuple[]"}],"name":"","type":"tuple"},"Dependencies":{"components":[{"name":"targets","type":"address[7]"},{"name":"codeHashes","type":"bytes32[7]"},{"name":"chainId","type":"uint256"},{"name":"readGas","type":"uint256"},{"name":"sourceGas","type":"uint256"},{"name":"snapshotGas","type":"uint256"},{"name":"archiveGas","type":"uint256"}],"name":"","type":"tuple"}},"payload":["bytes32 domain","uint256 chainId","address actualReferenceHost","Publication normalizedPublication","Receipt normalizedReceipt","SourceFacts authenticatedSource","bytes canonicalEnvironment"],"scope":"VIEW only; scopeId is complete membership and is not declaration viewId","output":"Complete admitted preservation JSON/HTML, excluding only sanction display under ADR0054; original live output is distinct","limits":{"canonicalPayloadBytes":524288,"captureHTMLBytes":262144,"samples":"first and last complete membership ordinal, one if count==1"},"authority":"Original selected Metadata CURATOR collection class3 then global class8; separate class2 lock. No Artist consent is granted by this record."}\n'
PROFILE_BYTES = b'{"name":"STREAM_VIEW_PRESERVATION_REFERENCE_RENDER_PROFILE_V1","schema":"STREAM_VIEW_PRESERVATION_REFERENCE_RENDER_ABI_V1","mode":"BYTE_EXACT","source":"Actual complete current root-free VIEW preservation snapshot, exact current original Router CONTENT_ROOT record and authenticated closed28word binding, full covered checkpoint manifest and all policy rows. A renderer adoption is not CONTENT_ROOT authority.","samples":"Fresh original checkpoint token observer joins every full31word output and exact producer JSON/HTML. Burned uses retained historical identity under still-current full adoption. Terminal statuses1/2 retain zero seed and complete explicit policy; status5 remains independently finalized.","captures":"Original PNG object/current dual archive pair, two identical nonzero repeat SHA256 values, actual HTML SHA256 and exact canonical Environment ZIP/current pair. The curator declares the execution; this is not an on-chain browser execution proof.","environment":"Original complete canonical Environment/package/platform inventory and prepared-file authentication. No sample-as-complete archive claim.","history":"Immutable bytes remain historical after source drift. Current reads rerun all current snapshot/root/archive/output facts; lock is not a shortcut.","deployment":"Stable fixed source graph; no reference currentness at construction and no invented future provider/Artist authority.","bounds":"Original524288 full payload bound remains; no maximum-scope or maximum combined Environment+HTML transaction capacity assertion."}\n'
CANON_BYTES = b'{"name":"STREAM_VIEW_PRESERVATION_REFERENCE_CANON_V1","encoding":"Solidity0.8.19 abi.encode, exact canonical nested offsets, widths, padding and ordered arrays","payloadDomain":"6529STREAM_VIEW_PRESERVATION_REFERENCE_PAYLOAD_V1","sourceDomain":"6529STREAM_VIEW_PRESERVATION_REFERENCE_SOURCES_V1","recordDomain":"6529STREAM_VIEW_PRESERVATION_REFERENCE_RECORD_V1","chainDomain":"6529STREAM_VIEW_PRESERVATION_REFERENCE_CHAIN_V1","publicationNormalization":"Only observation.expectedSourcesHash is zero in payload; original full Publication is separately retained and used in record hash.","receiptNormalization":"Only observation.recordHash, recordChainHash, payloadHash, payloadBytes and recordedAt are zero in payload. sourcesHash is actual current source hash.","environment":"Original canonical Environment bytes remain exact, not JSON re-encoded or source-filtered."}\n'

SCHEMA_NAME = 'STREAM_VIEW_PRESERVATION_REFERENCE_RENDER_ABI_V1'
PROFILE_NAME = 'STREAM_VIEW_PRESERVATION_REFERENCE_RENDER_PROFILE_V1'
CANON_NAME = 'STREAM_VIEW_PRESERVATION_REFERENCE_CANON_V1'
SCHEMA_ID, PROFILE_ID, CANON_ID = map(schema_id, (SCHEMA_NAME, PROFILE_NAME, CANON_NAME))
SCHEMA_HASH, PROFILE_HASH, CANON_HASH = map(keccak256, (SCHEMA_BYTES, PROFILE_BYTES, CANON_BYTES))
DEFINITION_HASHES = (SCHEMA_HASH, PROFILE_HASH, CANON_HASH)
ENVIRONMENT_SCHEMA_ID = schema_id('STREAM_REFERENCE_NATIVE_ENVIRONMENT_V1')
PNG_SCHEMA_ID = schema_id('STREAM_REFERENCE_PNG_OBJECT_V1')
ZIP_SCHEMA_ID = schema_id('STREAM_REFERENCE_RUNTIME_ZIP_OBJECT_V1')
FORMAT_CATALOG_ID = schema_id('STREAM_REFERENCE_NATIVE_FORMATS_V1')
ENVIRONMENT_SCHEMA_HASH = keccak256(STREAM_REFERENCE_NATIVE_ENVIRONMENT_V1_BYTES)
PNG_SCHEMA_HASH = keccak256(STREAM_REFERENCE_PNG_OBJECT_V1_BYTES)
ZIP_SCHEMA_HASH = keccak256(STREAM_REFERENCE_RUNTIME_ZIP_OBJECT_V1_BYTES)
FORMAT_CATALOG_HASH = keccak256(STREAM_REFERENCE_NATIVE_FORMATS_V1_BYTES)


def definitions():
    """Exactly the seven RAW_BYTES documents required by native Records.definitions."""
    rows = ((SCHEMA_NAME, 0, SCHEMA_BYTES), (PROFILE_NAME, 2, PROFILE_BYTES),
            (CANON_NAME, 1, CANON_BYTES),
            ('STREAM_REFERENCE_NATIVE_ENVIRONMENT_V1', 0, STREAM_REFERENCE_NATIVE_ENVIRONMENT_V1_BYTES),
            ('STREAM_REFERENCE_PNG_OBJECT_V1', 0, STREAM_REFERENCE_PNG_OBJECT_V1_BYTES),
            ('STREAM_REFERENCE_RUNTIME_ZIP_OBJECT_V1', 0, STREAM_REFERENCE_RUNTIME_ZIP_OBJECT_V1_BYTES),
            ('STREAM_REFERENCE_NATIVE_FORMATS_V1', 2, STREAM_REFERENCE_NATIVE_FORMATS_V1_BYTES))
    return tuple({'name': name, 'id': schema_id(name), 'kind': kind,
                  'hash': keccak256(raw), 'bytes': raw} for name, kind, raw in rows)
