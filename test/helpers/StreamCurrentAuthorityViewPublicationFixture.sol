// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamViewPreservationCheckpointTypesV1 as VPCheckpoint
} from "../../smart-contracts/interfaces/stream/finality/StreamViewPreservationCheckpointTypesV1.sol";
import {
    StreamViewPreservationManifestTypesV1 as VPManifest
} from "../../smart-contracts/interfaces/stream/finality/StreamViewPreservationManifestTypesV1.sol";
import {
    StreamViewPreservationSnapshotTypesV1 as VPSnapshot
} from "../../smart-contracts/interfaces/stream/metadata/StreamViewPreservationSnapshotTypesV1.sol";
import {
    StreamViewPreservationOutputSchemasV1 as VPOutputDefinitions
} from "../../smart-contracts/domains/finality/StreamViewPreservationOutputSchemasV1.sol";
import {
    StreamViewPreservationSnapshotDefinitionsV1 as VPSnapshotDefinitions
} from "../../smart-contracts/domains/records/StreamViewPreservationSnapshotDefinitionsV1.sol";
import {
    StreamViewPreservationContentDefinitionsV1 as VPRootDefinitions
} from "../../smart-contracts/domains/records/StreamViewPreservationContentDefinitionsV1.sol";
import {
    IStreamScopedContentRootPublication as VPScopedRoot
} from "../../smart-contracts/interfaces/stream/metadata/IStreamScopedContentRootPublication.sol";
import {
    IStreamViewPreservationContentRootV1 as VPRoot
} from "../../smart-contracts/interfaces/stream/metadata/IStreamViewPreservationContentRootV1.sol";
import {
    IStreamViewPreservationRendererV1 as VPServing
} from "../../smart-contracts/interfaces/stream/metadata/IStreamViewPreservationRendererV1.sol";
import {
    StreamArtistContentTypes as VPArtistContent
} from "../../smart-contracts/interfaces/stream/artist/StreamArtistContentTypes.sol";
import {
    StreamOnchainContentBytes
} from "../../smart-contracts/domains/finality/StreamOnchainContentBytes.sol";

import {
    StreamCurrentAuthorityViewAdoptionFixture
} from "./StreamCurrentAuthorityViewAdoptionFixture.sol";
import {
    IStreamPreservationRegistryV1 as VPreservationRegistry
} from "../../smart-contracts/interfaces/stream/metadata/IStreamPreservationRegistryV1.sol";
import {
    IStreamViewPreservationRendererV1 as VPreservation
} from "../../smart-contracts/interfaces/stream/metadata/IStreamViewPreservationRendererV1.sol";
import {
    IStreamRendererRegistry as VRegistry
} from "../../smart-contracts/interfaces/stream/metadata/IStreamRendererRegistry.sol";
import {
    IStreamSchemaRegistry as Schema
} from "../../smart-contracts/interfaces/stream/metadata/IStreamSchemaRegistry.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistContentTypes as AssemblyContent
} from "../../smart-contracts/interfaces/stream/artist/StreamArtistContentTypes.sol";
import {
    StreamFinalityScope
} from "../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import {
    StreamRecordFamilies
} from "../../smart-contracts/domains/records/StreamRecordFamilies.sol";
import { StreamCurrentStackPlan } from "../../script/current/StreamCurrentStackPlan.sol";
import {
    GenesisBatch
} from "../../smart-contracts/interfaces/stream/governance/IStreamGenesisInitializer.sol";
import {
    GovernanceCall
} from "../../smart-contracts/interfaces/stream/governance/StreamGovernanceTypes.sol";
import {
    StreamWorkRecordTypes
} from "../../smart-contracts/interfaces/stream/metadata/StreamWorkRecordTypes.sol";
import {
    StreamRightsRecordTypes
} from "../../smart-contracts/interfaces/stream/metadata/StreamRightsRecordTypes.sol";
import {
    StreamConservationRecordTypes
} from "../../smart-contracts/interfaces/stream/metadata/StreamConservationRecordTypes.sol";
import {
    StreamWorkRecordJson
} from "../../smart-contracts/domains/records/StreamWorkRecordJson.sol";
import {
    StreamRightsRecordJson
} from "../../smart-contracts/domains/records/StreamRightsRecordJson.sol";
import {
    StreamArtistIntentWaiverJson
} from "../../smart-contracts/domains/records/StreamArtistIntentWaiverJson.sol";
import {
    StreamWorkRecordDefinitions
} from "../../smart-contracts/domains/records/StreamWorkRecordDefinitions.sol";
import {
    StreamRightsRecordDefinitions
} from "../../smart-contracts/domains/records/StreamRightsRecordDefinitions.sol";
import {
    StreamConservationDefinitions
} from "../../smart-contracts/domains/records/StreamConservationDefinitions.sol";
import {
    IStreamPreservationRecords
} from "../../smart-contracts/interfaces/stream/preservation/IStreamPreservationRecords.sol";
import {
    IStreamCollectionMetadataV1
} from "../../smart-contracts/interfaces/stream/metadata/IStreamCollectionMetadataV1.sol";
import {
    IStreamWorkRecordSelection
} from "../../smart-contracts/interfaces/stream/metadata/IStreamWorkRecordSelection.sol";
import {
    IStreamConservationRecordSelection
} from "../../smart-contracts/interfaces/stream/metadata/IStreamConservationRecordSelection.sol";
import {
    IStreamRecordSelectionLock
} from "../../smart-contracts/interfaces/stream/metadata/IStreamRecordSelectionLock.sol";
import {
    IStreamArtistBindingOwner
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistBindingOwner.sol";
import {
    IStreamArtistRecordPublicationOwner
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistRecordPublicationOwner.sol";
import {
    StreamMetadataSubjects
} from "../../smart-contracts/domains/metadata/StreamMetadataSubjects.sol";
import {
    IStreamMetadataServingFacts
} from "../../smart-contracts/interfaces/stream/metadata/IStreamMetadataServingFacts.sol";

/// @notice Original-A VIEW records and preservation publication on one current-authority graph.
/// @dev Real Safe/Executor, op24 Work/waiver, granted Rights writer, op17, Registry, Schema,
/// Store, checkpoint, output and snapshot hosts. Archive observations and Registry analyses
/// are labelled fixture evidence; this is not browser, gas, or terminal-Finality acceptance.
abstract contract StreamCurrentAuthorityViewPublicationFixture is
    StreamCurrentAuthorityViewAdoptionFixture
{
    struct AuthorityViewRecords {
        StreamWorkRecordTypes.Description work;
        StreamRightsRecordTypes.Statement rights;
        StreamConservationRecordTypes.IntentWaiver waiver;
        ActualPublication workPublication;
        ActualPublication waiverPublication;
        bytes32 rightsRecord;
        bytes32 descriptionSealAction;
        bytes32 collectionBefore;
    }

    struct AuthorityViewPublication {
        bytes32 checkpoint;
        bytes32 outputManifest;
        bytes32 snapshotRecord;
        VPSnapshot.Receipt snapshotReceipt;
        bytes32 rootRecord;
        bytes32 rootConsent;
        uint256 rootConsentNonce;
        uint64 rootConsentObservedAt;
        AssemblyContent.Consent rootConsentInput;
        VPScopedRoot.Aggregate beforeRootAggregate;
        VPScopedRoot.Aggregate rootAggregate;
        bytes32 legacyFamilyHash;
        bytes32 preservationKey;
        VPreservationRegistry.PreservationRecord preservationRegistration;
    }
    AuthorityViewRecords internal authorityViewRecords;
    AuthorityViewPublication internal authorityViewPublication;
    mapping(uint256 => bytes) internal authorityViewJSON;
    mapping(uint256 => bytes) internal authorityViewHTML;

    function _authorityPublishViewPreservation() internal {
        _authorityRequireViewAdoption();
        require(
            !assemblyCore.collectionFreezeStatus(1) && authorityViewPublication.rootRecord == 0,
            "one original-A VIEW publication before freeze"
        );
        _authorityViewSelectRecords();
        _authorityViewAdmitPreservation();
        _authorityViewPublicationDefinitions();
        _authorityViewCheckpointOutputs();
        _authorityViewPublishSnapshot();
        _authorityViewPublishRoot();
        _authorityRequireViewPublication();
    }

    function _authorityFreezeViewArtwork() internal {
        _authorityRequireViewPublication();
        _authorityLockViewContent();
        _assemblyCloseAndFreezeCore();
        _authorityRequireViewPublication();
    }

    function _authorityViewSelectRecords() internal {
        require(authorityViewRecords.waiverPublication.recordHash == 0, "one VIEW record set");
        authorityViewRecords.collectionBefore = _authorityViewCollectionRecordsHash();
        require(
            assemblyMetadata.registerScopeSubject(authorityViewAdoption.membershipRecord)
                == _authorityViewRecordsSubject(),
            "exact published VIEW subject"
        );
        bytes32 subject = _authorityViewRecordsSubject();
        require(subject != _assemblySubject(), "VIEW never inherits COLLECTION selections");
        authorityViewRecords.work =
            abi.decode(abi.encode(assemblyWorkDescription), (StreamWorkRecordTypes.Description));
        authorityViewRecords.work.subjectId = subject;
        authorityViewRecords.work.full.title = "Current-authority original A alternate VIEW";
        bytes memory raw = StreamWorkRecordJson.serialize(authorityViewRecords.work);
        IStreamPreservationRecords.CollectionRecord memory record = _authorityViewOriginalRecord(
            keccak256("WORK_DESCRIPTION"), StreamWorkRecordDefinitions.SCHEMA_ID, raw
        );
        authorityViewRecords.workPublication = _publishCurrentAuthorityRecord(record, raw);
        assemblyWork.selectCurrent(
            1,
            subject,
            authorityViewRecords.workPublication.recordHash,
            0,
            0,
            IStreamWorkRecordSelection.Witness(record, authorityViewRecords.work)
        );
        authorityViewRecords.rights =
            abi.decode(abi.encode(assemblyRightsStatement), (StreamRightsRecordTypes.Statement));
        authorityViewRecords.rights.subjectId = subject;
        raw = StreamRightsRecordJson.serialize(authorityViewRecords.rights);
        record = _authorityViewOriginalRecord(
            keccak256("RIGHTS_STATEMENT"), StreamRightsRecordDefinitions.SCHEMA_ID, raw
        );
        // RIGHTS_STATEMENT has no op24 publication family. Use the real existing class7 writer.
        authorityViewRecords.rightsRecord =
            assemblyMetadata.recordCollectionRecordWithPayload(1, record, raw);
        _authorityRequireViewRights(record, raw);
        assemblyRights.selectCurrent(
            1, subject, authorityViewRecords.rightsRecord, 0, 0, authorityViewRecords.rights
        );
        authorityViewRecords.waiver = abi.decode(
            abi.encode(assemblyIntentWaiver), (StreamConservationRecordTypes.IntentWaiver)
        );
        authorityViewRecords.waiver.subjectId = subject;
        authorityViewRecords.waiver.waiverStatement =
            _authorityViewStatementReference("urn:fixture:authority-view:intent-waiver");
        authorityViewRecords.waiver.interview.waiverStatement =
            _authorityViewStatementReference("urn:fixture:authority-view:interview-waiver");
        raw = StreamArtistIntentWaiverJson.serialize(authorityViewRecords.waiver);
        record = _authorityViewOriginalRecord(
            keccak256("ARTIST_INTENT_WAIVER"), StreamConservationDefinitions.WAIVER_SCHEMA_ID, raw
        );
        authorityViewRecords.waiverPublication = _publishCurrentAuthorityRecord(record, raw);
        IStreamConservationRecordSelection.WaiverWitness memory witness;
        witness.original = record;
        witness.waiver = authorityViewRecords.waiver;
        assemblyConservation.adoptWaiver(
            1, subject, authorityViewRecords.waiverPublication.recordHash, 0, 0, witness
        );
        _authorityViewSealDescriptions();
        _authorityViewLockIntent();
        require(
            _authorityViewCollectionRecordsHash() == authorityViewRecords.collectionBefore,
            "all original COLLECTION records and selections retained"
        );
    }

    function _authorityRequireViewRights(
        IStreamPreservationRecords.CollectionRecord memory expected,
        bytes memory raw
    ) private view {
        (
            IStreamPreservationRecords.CollectionRecord memory saved,
            IStreamCollectionMetadataV1.RecordReceipt memory receipt
        ) = assemblyMetadata.collectionRecord(authorityViewRecords.rightsRecord);
        (, bytes memory payload) = assemblyMetadata.recordPayload(authorityViewRecords.rightsRecord);
        require(
            keccak256(abi.encode(saved)) == keccak256(abi.encode(expected))
                && keccak256(payload) == keccak256(raw) && receipt.collectionId == 1
                && receipt.recorder == address(this) && receipt.authorizationClass == 7
                && receipt.artistAuthorization == 0
                && assemblyMetadata.recordHashAt(1, expected.recordType, receipt.recordIndex)
                    == authorityViewRecords.rightsRecord,
            "actual granted Rights writer and exact retained payload"
        );
    }

    function _authorityViewRecordsSubject() internal view returns (bytes32) {
        return StreamMetadataSubjects.scopeSubject(
            block.chainid, address(assemblyCore), authorityViewAdoption.scope
        );
    }

    function _authorityViewOriginalRecord(bytes32 kind, bytes32 schema, bytes memory raw)
        private
        view
        returns (IStreamPreservationRecords.CollectionRecord memory record)
    {
        record.recordType = kind;
        record.subjectId = _authorityViewRecordsSubject();
        record.schemaId = schema;
        record.effectiveAt = uint64(block.timestamp);
        record.uri = "https://fixtures.example.invalid/view-preservation/original-record";
        record.contentHash = IStreamPreservationRecords.HashRef(
            1, abi.encodePacked(keccak256(raw)), keccak256("RFC8785_JCS")
        );
    }

    function _authorityViewStatementReference(string memory uri)
        private
        pure
        returns (StreamConservationRecordTypes.Reference memory result)
    {
        result.algorithm = 1;
        result.canonicalizationId = keccak256("RAW_BYTES");
        result.digest = abi.encodePacked(keccak256(bytes(uri)));
        result.uri = uri;
    }

    function _authorityViewSealDescriptions() private {
        IStreamRecordSelectionLock[2] memory selectors = [
            IStreamRecordSelectionLock(address(assemblyWork)),
            IStreamRecordSelectionLock(address(assemblyRights))
        ];
        bytes32[2] memory records =
            [authorityViewRecords.workPublication.recordHash, authorityViewRecords.rightsRecord];
        GenesisBatch memory batch;
        batch.actionClass = 2;
        batch.calls = new GovernanceCall[](2);
        batch.callDatas = new bytes[](2);
        for (uint256 i; i < 2; ++i) {
            (bytes32 scope, bytes32 oldHash, bytes32 newHash) = selectors[i].selectionLockTransition(
                1, _authorityViewRecordsSubject(), records[i], 1
            );
            batch.callDatas[i] = abi.encodeCall(
                selectors[i].lockSelection,
                (1, _authorityViewRecordsSubject(), records[i], uint64(1))
            );
            batch.calls[i] = StreamCurrentStackPlan.call(
                address(selectors[i]), batch.callDatas[i], scope, oldHash, newHash
            );
        }
        _admitAssemblyBatch(batch);
        authorityViewRecords.descriptionSealAction = _assemblyGovernance(
            batch, "https://fixtures.example.invalid/view-preservation/seal-work-rights"
        );
        for (uint256 i; i < 2; ++i) {
            IStreamRecordSelectionLock.SelectionLock memory seal =
                selectors[i].selectionLock(1, _authorityViewRecordsSubject());
            require(
                seal.locked && seal.recordHash == records[i] && seal.revision == 1
                    && seal.actionId == authorityViewRecords.descriptionSealAction
                    && seal.executor == address(assemblyExecutor)
                    && seal.governanceRoot == address(assemblyRoot),
                "actual class2 VIEW selected-head seal"
            );
        }
    }

    function _authorityViewLockIntent() private {
        uint256 safeNonce = assemblyArtist.nonce();
        require(
            executeSafe(
                assemblyArtist,
                assemblyArtistKeys,
                address(assemblyConservation),
                0,
                abi.encodeCall(
                    assemblyConservation.lockArtistIntent,
                    (
                        1,
                        _authorityViewRecordsSubject(),
                        authorityViewRecords.waiverPublication.recordHash,
                        uint64(1)
                    )
                ),
                0
            ),
            "actual Artist Safe locks exact VIEW intent"
        );
        T.Binding memory b = IStreamArtistBindingOwner(assemblySuite.owners[0]).binding(1);
        IStreamConservationRecordSelection.IntentLock memory locked =
            assemblyConservation.intentLock(1, _authorityViewRecordsSubject());
        require(
            assemblyArtist.nonce() == safeNonce + 1 && locked.locked
                && locked.locker == address(assemblyArtist) && locked.artistId == b.artistId
                && locked.identityRecordHash == b.identityRecordHash
                && locked.bindingHash == b.bindingHash && locked.bindingGeneration == b.generation
                && locked.recordHash == authorityViewRecords.waiverPublication.recordHash
                && locked.revision == 1 && locked.lockedAt == block.timestamp,
            "original Artist authority retained in VIEW intent lock"
        );
    }

    function _authorityViewOriginalHash(bytes32 recordHash) internal view returns (bytes32) {
        (
            IStreamPreservationRecords.CollectionRecord memory r,
            IStreamCollectionMetadataV1.RecordReceipt memory receipt
        ) = assemblyMetadata.collectionRecord(recordHash);
        (address pointer, bytes memory raw) = assemblyMetadata.recordPayload(recordHash);
        return keccak256(abi.encode(r, receipt, pointer, raw));
    }

    function _authorityViewCollectionRecordsHash() internal view returns (bytes32) {
        bytes32 originals = keccak256(
            abi.encode(
                _authorityViewOriginalHash(assemblyWorkRecord),
                _authorityViewOriginalHash(assemblyRightsRecord),
                _authorityViewOriginalHash(assemblyWaiverRecord),
                assemblyWorkDescription,
                assemblyRightsStatement,
                assemblyIntentWaiver,
                IStreamArtistRecordPublicationOwner(assemblySuite.owners[4])
                    .publicationAttestation(assemblyWaiverAuthorization),
                assemblyMetadata.consumedArtistAuthorization(assemblyWaiverAuthorization)
            )
        );
        bytes32 subject = _assemblySubject();
        return keccak256(
            abi.encode(
                originals,
                assemblyWork.currentWork(1, subject),
                assemblyRights.currentRights(1, subject),
                IStreamRecordSelectionLock(address(assemblyWork)).selectionLock(1, subject),
                IStreamRecordSelectionLock(address(assemblyRights)).selectionLock(1, subject),
                assemblyConservation.currentConservation(
                    1, subject, StreamConservationRecordTypes.StatementOrigin.ARTIST_INTENT
                ),
                assemblyConservation.intentLock(1, subject)
            )
        );
    }

    function _authorityViewAdmitPreservation() internal {
        require(
            authorityViewAdoption.adoptionRecord != 0
                && authorityViewPublication.preservationKey == 0
        );
        VPreservationRegistry api = VPreservationRegistry(address(authorityViewAdoption.registry));
        VPreservationRegistry.PreservationRegistration memory r;
        r.versionKey = authorityViewAdoption.rendererVersionKey;
        r.binding = VPreservationRegistry.ProducerBinding(
            address(avRenderer),
            address(avRenderer).codehash,
            keccak256("6529STREAM_ADOPTED_POLICY_VIEW_PRESERVATION_V1"),
            address(assemblyCore),
            address(assemblyRouter),
            address(authorityViewAdoption.liveRenderer),
            address(authorityViewAdoption.liveRenderer).codehash,
            address(avAttribution),
            address(avAttribution).codehash
        );
        VRegistry.Read[] memory reads = _authorityViewPreservationReads();
        bytes memory schema = bytes(
            "{\"fixture\":true,\"output\":\"original adopted VIEW JSON/HTML, only sanction projection omitted\"}"
        );
        r.schemaDocument = _authorityViewDocument(
            "AUTHORITY_VIEW_PRESERVATION_SCHEMA_FIXTURE_V1", Schema.DocumentKind.SCHEMA, schema
        );
        r.analysisDocument = _authorityViewDocument(
            "AUTHORITY_VIEW_PRESERVATION_ANALYSIS_FIXTURE_V1",
            Schema.DocumentKind.CATALOG,
            abi.encode(
                VPreservationRegistry.PreservationAnalysis(
                    keccak256("6529STREAM_PRESERVATION_ANALYSIS_ABI_V1"),
                    r.binding,
                    authorityViewAdoption.registry
                    .version(authorityViewAdoption.rendererVersionKey)
                    .registrationHash,
                    keccak256(schema),
                    keccak256(
                        abi.encode(
                            keccak256("6529STREAM_RENDERER_READ_SET_V1"),
                            authorityViewAdoption.registry.targetSetHash(),
                            reads
                        )
                    ),
                    keccak256("SYNTHETIC FIXTURE: no VIEW preservation opcode analysis"),
                    keccak256(
                        "SYNTHETIC FIXTURE: fixed original roster with required preservation sources, not transitive analysis"
                    ),
                    true
                )
            )
        );
        VPreservationRegistry.PreservationGoldenVector[] memory vectors =
            new VPreservationRegistry.PreservationGoldenVector[](8);
        for (uint256 i; i < 2; ++i) {
            uint256 token = authorityViewAdoption.tokens[i];
            (bytes32 jsonRecord, string memory json) =
                avRenderer.preservationViewJSON(authorityViewAdoption.scope, token);
            (bytes32 htmlRecord, string memory html) =
                avRenderer.preservationViewHTML(authorityViewAdoption.scope, token);
            (StreamFinalityScope memory js, string memory oldJSON) = avRenderer.historicalPreservationViewJSON(
                authorityViewAdoption.adoptionRecord, token
            );
            (StreamFinalityScope memory hs, string memory oldHTML) = avRenderer.historicalPreservationViewHTML(
                authorityViewAdoption.adoptionRecord, token
            );
            require(
                jsonRecord == authorityViewAdoption.adoptionRecord
                    && htmlRecord == authorityViewAdoption.adoptionRecord
                    && keccak256(abi.encode(js))
                        == keccak256(abi.encode(authorityViewAdoption.scope))
                    && keccak256(abi.encode(hs)) == keccak256(abi.encode(js))
                    && keccak256(bytes(json)) == keccak256(bytes(oldJSON))
                    && keccak256(bytes(html)) == keccak256(bytes(oldHTML))
            );
            for (uint8 mode = 2; mode <= 5; ++mode) {
                vectors[4 * i + mode - 2] = VPreservationRegistry.PreservationGoldenVector(
                    authorityViewAdoption.scope,
                    token,
                    authorityViewAdoption.adoptionRecord,
                    mode,
                    keccak256(bytes(mode % 2 == 0 ? json : html))
                );
            }
        }
        r.goldenDocument = _authorityViewDocument(
            "AUTHORITY_VIEW_PRESERVATION_GOLDEN_FIXTURE_V1",
            Schema.DocumentKind.CATALOG,
            abi.encode(vectors)
        );
        (bytes32 s, bytes32 a, bytes32 b) = api.preservationTransition(r, reads);
        _assemblyGovernanceCall(
            1, address(api), abi.encodeCall(api.registerPreservation, (r, reads)), s, a, b
        );
        authorityViewPublication.preservationKey =
            api.preservationKey(r.versionKey, r.binding.producer, r.binding.profile);
        authorityViewPublication.preservationRegistration =
            api.preservationRecord(authorityViewPublication.preservationKey);
        require(
            authorityViewPublication.preservationRegistration.registrationHash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_PRESERVATION_REGISTRATION_V1"),
                        block.chainid,
                        address(api),
                        address(assemblySchemas),
                        address(assemblySchemas).codehash,
                        authorityViewAdoption.registry.targetSetHash(),
                        authorityViewAdoption.registry.version(r.versionKey).registrationHash,
                        r,
                        reads
                    )
                ),
            "literal genuine admission"
        );
        (
            VPreservationRegistry.ProducerBinding memory binding,
            VPreservationRegistry.Admission memory admitted
        ) = api.requirePreservation(r.versionKey, r.binding.producer, r.binding.profile);
        require(
            keccak256(abi.encode(binding)) == keccak256(abi.encode(r.binding))
                && admitted.registrationHash
                    == authorityViewPublication.preservationRegistration.registrationHash
                && admitted.registry == address(api)
                && admitted.versionKey == authorityViewAdoption.rendererVersionKey
        );
    }

    function _authorityViewPreservationReads()
        internal
        view
        returns (VRegistry.Read[] memory reads)
    {
        reads = new VRegistry.Read[](authorityViewReads.length + 9);
        uint256 next;
        for (; next < authorityViewReads.length; ++next) {
            reads[next] = authorityViewReads[next];
        }
        VRegistry.Target[] memory targets = _authorityViewTargets();
        for (uint16 i; i < targets.length; ++i) {
            if (targets[i].target == address(avRenderer)) {
                reads[next++] =
                    VRegistry.Read(i, VPreservation.preservationProfile.selector, 32, true);
                reads[next++] = VRegistry.Read(i, VPreservation.configuration.selector, 288, true);
                reads[next++] =
                    VRegistry.Read(i, VPreservation.preservationViewBinding.selector, 192, true);
                reads[next++] =
                    VRegistry.Read(i, VPreservation.preservationViewJSON.selector, 262336, false);
                reads[next++] =
                    VRegistry.Read(i, VPreservation.preservationViewHTML.selector, 262336, false);
                reads[next++] = VRegistry.Read(
                    i, VPreservation.historicalPreservationViewJSON.selector, 262336, false
                );
                reads[next++] = VRegistry.Read(
                    i, VPreservation.historicalPreservationViewHTML.selector, 262336, false
                );
                reads[next++] =
                    VRegistry.Read(i, VPreservation.configurationHash.selector, 32, true);
            } else if (targets[i].target == address(avAttribution)) {
                reads[next++] = VRegistry.Read(
                    i, bytes4(keccak256("preservationAttribution(uint256,uint256)")), 32832, false
                );
            }
        }
        require(next == reads.length);
        for (uint256 i = 1; i < reads.length; ++i) {
            for (
                uint256 j = i;
                j != 0 && _authorityViewReadOrder(reads[j - 1]) > _authorityViewReadOrder(reads[j]);
                --j
            ) {
                (reads[j - 1], reads[j]) = (reads[j], reads[j - 1]);
            }
        }
    }

    function _authorityViewPublicationDefinitions() internal {
        _assemblySetupArchiveAdmissions();
        string[5] memory outputNames = [
            "STREAM_VIEW_PRESERVATION_OUTPUT_PART_V1",
            "STREAM_ABI_VIEW_PRESERVATION_OUTPUT_PART_V1",
            "STREAM_VIEW_PRESERVATION_OUTPUT_MANIFEST_V1",
            "STREAM_ABI_VIEW_PRESERVATION_OUTPUT_MANIFEST_V1",
            "STREAM_VIEW_PRESERVATION_CONTENT_LEAF_V1"
        ];
        for (uint256 i; i < outputNames.length; ++i) {
            bytes32 id = keccak256(bytes(outputNames[i]));
            _assemblyRegisterDocument(
                outputNames[i],
                i == 1 || i == 3
                    ? Schema.DocumentKind.CANONICALIZATION
                    : Schema.DocumentKind.SCHEMA,
                VPOutputDefinitions.document(id),
                assemblySchemas.RAW_BYTES()
            );
        }
        string[5] memory names = [
            "STREAM_VIEW_PRESERVATION_SNAPSHOT_ABI_V1",
            "STREAM_VIEW_PRESERVATION_SNAPSHOT_PROFILE_V1",
            "STREAM_ABI_VIEW_PRESERVATION_SNAPSHOT_V1",
            "STREAM_VIEW_PRESERVATION_CONTENT_ROOT_V1",
            "STREAM_ABI_VIEW_PRESERVATION_CONTENT_ROOT_V1"
        ];
        bytes32[5] memory hashes = [
            VPSnapshotDefinitions.SCHEMA_HASH,
            VPSnapshotDefinitions.PROFILE_HASH,
            VPSnapshotDefinitions.CANON_HASH,
            VPRootDefinitions.SCHEMA_HASH,
            VPRootDefinitions.CANON_HASH
        ];
        uint256[5] memory lengths = [
            VPSnapshotDefinitions.SCHEMA_BYTES,
            VPSnapshotDefinitions.PROFILE_BYTES,
            VPSnapshotDefinitions.CANON_BYTES,
            VPRootDefinitions.SCHEMA_BYTES,
            VPRootDefinitions.CANON_BYTES
        ];
        for (uint256 i; i < names.length; ++i) {
            string memory folder =
                i < 3 ? "view-preservation-snapshot-v1/" : "view-preservation-content-root-v1/";
            string memory suffix = i == 0 || i == 3 ? "schema" : i == 1 ? "profile" : "canon";
            bytes memory raw = bytes(
                assemblyVm.readFile(string.concat("schemas/metadata/", folder, suffix, ".json"))
            );
            require(
                raw.length == lengths[i] && keccak256(raw) == hashes[i],
                "exact VIEW definition source bytes"
            );
            _assemblyRegisterDocument(
                names[i],
                i == 2 || i == 4
                    ? Schema.DocumentKind.CANONICALIZATION
                    : i == 1 ? Schema.DocumentKind.CATALOG : Schema.DocumentKind.SCHEMA,
                raw,
                assemblySchemas.RAW_BYTES()
            );
        }
        _assemblyGrantFamily(StreamRecordFamilies.SNAPSHOT, 7, address(this));
        (bool identity, uint64 revision) =
            assemblyMetadata.familyWriter(1, StreamRecordFamilies.IDENTITY, 7, address(this));
        require(identity && revision != 0, "original display writer grant remains explicit");
    }

    function _authorityViewPreservationBytes(uint256 tokenId, bool html)
        internal
        view
        returns (bytes memory raw)
    {
        bytes memory input = html
            ? abi.encodeCall(VPServing.preservationViewHTML, (authorityViewAdoption.scope, tokenId))
            : abi.encodeCall(VPServing.preservationViewJSON, (authorityViewAdoption.scope, tokenId));
        uint256 cap = avCheckpoint.configuration().servingGas;
        (bool ok, bytes memory result) = address(avRenderer).staticcall{ gas: cap }(input);
        require(ok, "actual VIEW preservation serving within original configured cap");
        (bytes32 adoption, string memory output) = abi.decode(result, (bytes32, string));
        require(
            adoption == authorityViewAdoption.adoptionRecord
                && keccak256(result) == keccak256(abi.encode(adoption, output)),
            "exact current VIEW adoption and canonical output transport"
        );
        raw = bytes(output);
        require(raw.length != 0, "complete VIEW preservation output");
    }

    function _authorityViewCheckpointOutputs() internal {
        (VPCheckpoint.Plan memory p, VPCheckpoint.Output[] memory rows) =
            _authorityViewBuildCheckpoint();
        _authorityViewCoverManifest(p, rows);
    }

    /// @dev Complete original checkpoint construction and all row/root assertions. Exposing this
    /// boundary permits a bounded full-currentness measurement before output/snapshot publication.
    function _authorityViewBuildCheckpoint()
        internal
        returns (VPCheckpoint.Plan memory p, VPCheckpoint.Output[] memory rows)
    {
        authorityViewPublication.checkpoint = avCheckpoint.begin(
            authorityViewAdoption.scope, keccak256("actual current VIEW preservation ceremony")
        );
        for (uint256 i; i < authorityViewAdoption.tokens.length; ++i) {
            uint256 token = authorityViewAdoption.tokens[i];
            bytes memory json = _authorityViewPreservationBytes(token, false);
            bytes memory html = _authorityViewPreservationBytes(token, true);
            require(
                StreamOnchainContentBytes.matchesAnimation(json, html),
                "complete actual VIEW HTML nested in JSON"
            );
            authorityViewJSON[token] = json;
            authorityViewHTML[token] = html;
            avCheckpoint.append(authorityViewPublication.checkpoint, token, json, html);
        }
        avCheckpoint.seal(authorityViewPublication.checkpoint);
        p = avCheckpoint.requireCurrentCheckpoint(authorityViewPublication.checkpoint);
        require(
            p.tokenCount == 2 && p.nextIndex == 2
                && p.adoptionRecord == authorityViewAdoption.adoptionRecord && p.contentRoot != 0
                && p.outputRoot != 0,
            "complete actual VIEW membership and outputs"
        );
        rows = new VPCheckpoint.Output[](2);
        bytes32[2] memory leaves;
        for (uint256 i; i < rows.length; ++i) {
            rows[i] = avCheckpoint.outputAt(authorityViewPublication.checkpoint, i);
            uint256 token = authorityViewAdoption.tokens[i];
            (uint8 status, bytes32 seed, address selectedProvider) =
                assemblyEntropy.staticTokenRenderFacts(token);
            require(
                status == 5 && seed != 0 && selectedProvider == address(assemblyOracle)
                    && rows[i].entropy.coordinator == address(assemblyEntropy)
                    && rows[i].entropy.coordinatorCodeHash == address(assemblyEntropy).codehash
                    && rows[i].entropy.status == status && rows[i].entropy.seed == seed
                    && rows[i].entropy.finalized,
                "VIEW row preserves actual original fulfilled assemblyEntropy"
            );
            require(
                rows[i].index == i && rows[i].tokenId == token
                    && rows[i].jsonHash == keccak256(authorityViewJSON[token])
                    && rows[i].htmlHash == keccak256(authorityViewHTML[token])
                    && rows[i].jsonBytes == authorityViewJSON[token].length
                    && rows[i].htmlBytes == authorityViewHTML[token].length && !rows[i].burned
                    && rows[i].servingKind == 1,
                "full ordered actual VIEW row fields"
            );
            leaves[i] = keccak256(
                abi.encode(
                    keccak256("6529STREAM_VIEW_PRESERVATION_CONTENT_LEAF_V1"),
                    keccak256("6529STREAM_ADOPTED_POLICY_VIEW_PRESERVATION_V1"),
                    block.chainid,
                    address(assemblyCore),
                    authorityViewAdoption.scope,
                    authorityViewAdoption.adoptionRecord,
                    rows[i]
                )
            );
        }
        require(
            p.contentRoot
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_VIEW_PRESERVATION_CONTENT_NODE_V1"),
                        leaves[0],
                        leaves[1]
                    )
                ),
            "independent ordered two-leaf VIEW content root"
        );
    }

    function _authorityViewCoverManifest(
        VPCheckpoint.Plan memory p,
        VPCheckpoint.Output[] memory rows
    ) private {
        VPManifest.Configuration memory c = avOutput.configuration();
        VPManifest.Header memory h = VPManifest.Header(
            authorityViewPublication.checkpoint,
            keccak256(abi.encode(p)),
            authorityViewAdoption.scope,
            p.adoptionRecord,
            p.sourceContextHash,
            p.membershipHash,
            p.policyChainHash,
            p.tokenCount,
            p.outputRoot,
            p.contentRoot
        );
        // Independent literal canonical encoders; the publisher authenticates every byte.
        bytes memory raw = abi.encode(
            VPOutputDefinitions.PART,
            block.chainid,
            address(assemblyCore),
            c.checkpoint,
            c.checkpointConfigurationHash,
            h,
            uint64(0),
            rows
        );
        require(
            raw.length == 672 + 992 * rows.length, "complete final remainder part canonical size"
        );
        (bytes32 artifact, bytes32 coverage) =
            _ocCover(raw, VPOutputDefinitions.PART, VPOutputDefinitions.PART_CANON);
        bytes32 partRecord = avOutput.preparePart(
            authorityViewPublication.checkpoint, 0, artifact, coverage, assemblyArtistId
        );
        VPManifest.Part memory part = avOutput.partRecord(partRecord);
        require(
            part.first == 0 && part.count == 2 && part.firstToken == authorityViewAdoption.tokens[0]
                && part.lastToken == authorityViewAdoption.tokens[1]
                && part.carrier.contentHash == keccak256(raw)
                && part.carrier.byteLength == raw.length,
            "complete covered part retains exact two current outputs"
        );
        VPManifest.Descriptor[] memory descriptors = new VPManifest.Descriptor[](1);
        descriptors[0] = VPManifest.Descriptor(
            partRecord,
            artifact,
            coverage,
            keccak256(raw),
            uint64(raw.length),
            0,
            2,
            authorityViewAdoption.tokens[0],
            authorityViewAdoption.tokens[1]
        );
        raw = abi.encode(
            VPOutputDefinitions.INDEX,
            block.chainid,
            address(assemblyCore),
            c.checkpoint,
            c.checkpointConfigurationHash,
            h,
            assemblyArtistId,
            descriptors
        );
        require(raw.length == 672 + 288 * descriptors.length, "complete VIEW index canonical size");
        (artifact, coverage) =
            _ocCover(raw, VPOutputDefinitions.INDEX, VPOutputDefinitions.INDEX_CANON);
        bytes32 plan = avOutput.beginManifest(
            authorityViewPublication.checkpoint, artifact, coverage, assemblyArtistId
        );
        authorityViewPublication.outputManifest = avOutput.verifyNextPart(plan, partRecord);
        VPManifest.Plan memory output = avOutput.requireCurrentManifest(
            authorityViewPublication.outputManifest, assemblyArtistId
        );
        require(
            authorityViewPublication.outputManifest != 0 && output.nextRow == 2
                && output.nextPart == 1 && output.partCount == 1
                && output.carrier.contentHash == keccak256(raw)
                && output.carrier.byteLength == raw.length
                && output.header.contentRoot == p.contentRoot
                && output.header.outputRoot == p.outputRoot,
            "actual complete archive-covered VIEW index"
        );
    }

    function _authorityViewPublishSnapshot() internal {
        VPSnapshot.Publication memory p = VPSnapshot.Publication(
            authorityViewAdoption.scope,
            keccak256("actual VIEW root-free snapshot"),
            bytes32(0),
            0,
            authorityViewPublication.outputManifest,
            authorityViewAdoption.adoptionRecord,
            bytes32(0),
            "urn:fixture:view-preservation:snapshot",
            uint64(block.timestamp),
            keccak256("actual adopted VIEW original source snapshot")
        );
        bytes memory canonical;
        (p.expectedSourceHash, canonical) = avSnapshot.previewSnapshot(p, address(this));
        _assemblyUpload(canonical);
        authorityViewPublication.snapshotRecord = avSnapshot.publishSnapshot(p);
        authorityViewPublication.snapshotReceipt = avSnapshot.requireCurrent(
            authorityViewAdoption.scope, authorityViewPublication.snapshotRecord, 1
        );
        require(
            authorityViewPublication.snapshotReceipt.recordHash
                    == authorityViewPublication.snapshotRecord
                && authorityViewPublication.snapshotReceipt.manifestHash == keccak256(canonical)
                && authorityViewPublication.snapshotReceipt.manifestBytes == canonical.length
                && authorityViewPublication.snapshotReceipt.authorizationClass == 7
                && authorityViewPublication.snapshotReceipt.displayAuthorizationClass == 7
                && keccak256(avSnapshot.snapshotPayload(authorityViewPublication.snapshotRecord))
                    == keccak256(canonical),
            "actual root-free snapshot bytes and both original grants"
        );
        require(
            VPScopedRoot(address(assemblyRouter)).scopedContentRootHead(authorityViewAdoption.scope)
                == 0,
            "snapshot requires no future content root"
        );
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            avSnapshot.lockTransition(authorityViewAdoption.scope);
        GenesisBatch memory batch;
        batch.actionClass = 2;
        batch.calls = new GovernanceCall[](1);
        batch.callDatas = new bytes[](1);
        batch.callDatas[0] = abi.encodeCall(avSnapshot.lockSnapshot, (authorityViewAdoption.scope));
        batch.calls[0] = StreamCurrentStackPlan.call(
            address(avSnapshot), batch.callDatas[0], scope, oldHash, newHash
        );
        _admitAssemblyBatch(batch);
        bytes32 action = _assemblyGovernance(batch, "urn:fixture:view-preservation:seal-snapshot");
        VPSnapshot.Lock memory saved = avSnapshot.snapshotLock(authorityViewAdoption.scope);
        require(
            saved.recordHash == authorityViewPublication.snapshotRecord && saved.revision == 1
                && saved.actionId == action && saved.lockedAt != 0,
            "actual original class2 snapshot seal"
        );
    }

    function _authorityViewRootPublication()
        internal
        view
        returns (VPScopedRoot.Publication memory)
    {
        return VPScopedRoot.Publication(
            authorityViewAdoption.scope,
            bytes32(0),
            authorityViewPublication.snapshotRecord,
            1,
            "urn:fixture:view-preservation:content-root"
        );
    }

    function _authorityViewPublishRoot() internal {
        authorityViewPublication.beforeRootAggregate =
            VPScopedRoot(address(assemblyRouter)).scopedContentRootAggregate(1);
        VPScopedRoot.Publication memory p = _authorityViewRootPublication();
        require(
            VPScopedRoot(address(assemblyRouter)).scopedContentRootAggregate(1).revision == 0
                && assemblyRouter.collectionContentRootHead(1) == 0,
            "fixture starts with no original or scoped content root"
        );
        (bool supported, bytes32 legacy) =
            assemblyRouter.artistContentFamilyState(1, keccak256("CONTENT_ROOT"));
        require(
            supported
                && legacy
                    == keccak256(
                        abi.encode(
                            keccak256("6529STREAM_EMPTY_CONTENT_ROOT_STATE_V1"),
                            block.chainid,
                            address(assemblyRouter),
                            address(assemblyCore),
                            uint256(1)
                        )
                    ),
            "actual pre-publication legacy family witness"
        );
        authorityViewPublication.legacyFamilyHash = legacy;
        bytes32 state =
            VPRoot(address(assemblyRouter)).previewViewPreservationContentRoot(p, address(this));
        VPArtistContent.Consent memory consent =
            VPArtistContent.Consent(1, address(assemblyRouter), keccak256("CONTENT_ROOT"), state);
        T.Authorization memory authorization = _assemblyAuthorization(false);
        authorization.signature = _assemblyArtistProof(
            assemblyArtists.contentConsentDigest(consent, authorization), authorization.nonce
        );
        authorityViewPublication.rootConsentInput = consent;
        authorityViewPublication.rootConsentNonce = authorization.nonce;
        authorityViewPublication.rootConsentObservedAt = uint64(block.timestamp);
        authorityViewPublication.rootConsent =
            assemblyArtists.recordContentConsent(consent, authorization);
        _authorityContentConsent(consent, authorityViewPublication.rootConsent);
        require(
            authorityViewPublication.rootConsent != authorityViewAdoption.rendererConsent
                && !assemblyRouter.consumedArtistContentConsent(
                    authorityViewPublication.rootConsent
                ),
            "root consent is distinct from adoption consent"
        );
        authorityViewPublication.rootRecord =
            VPRoot(address(assemblyRouter)).publishViewPreservationContentRoot(p);
        VPScopedRoot.Record memory saved = VPScopedRoot(address(assemblyRouter))
            .scopedContentRootRecord(authorityViewPublication.rootRecord);
        authorityViewPublication.rootAggregate =
            VPScopedRoot(address(assemblyRouter)).scopedContentRootAggregate(1);
        require(
            authorityViewPublication.rootAggregate.revision == 1
                && authorityViewPublication.rootRecord
                    == keccak256(
                        abi.encode(
                            keccak256("6529STREAM_SCOPED_CONTENT_ROOT_RECORD_V1"),
                            block.chainid,
                            address(assemblyRouter),
                            address(assemblyCore),
                            saved,
                            authorityViewPublication.rootAggregate
                        )
                    )
                && state
                    == keccak256(
                        abi.encode(
                            keccak256("6529STREAM_CONTENT_ROOT_FAMILY_WITH_SCOPES_V1"),
                            block.chainid,
                            address(assemblyRouter),
                            address(assemblyCore),
                            uint256(1),
                            legacy,
                            authorityViewPublication.rootAggregate
                        )
                    ),
            "exact historical aggregate and signed family preimages for future inventory"
        );
        require(
            saved.artistConsent == authorityViewPublication.rootConsent
                && saved.artistId == assemblyArtistId && saved.publisher == address(this)
                && saved.snapshotHost == address(avSnapshot)
                && saved.snapshotManifestHash
                    == authorityViewPublication.snapshotReceipt.manifestHash
                && saved.snapshotSourceHash == authorityViewPublication.snapshotReceipt.sourceHash
                && saved.publication.snapshotRecordHash == authorityViewPublication.snapshotRecord
                && saved.publication.snapshotRevision == 1
                && assemblyRouter.consumedArtistContentConsent(
                    authorityViewPublication.rootConsent
                ),
            "original op17 root and exact retained source"
        );
        VPRoot.Binding memory b = VPRoot(address(assemblyRouter))
            .viewPreservationContentRootBinding(authorityViewPublication.rootRecord);
        require(
            b.profileId == VPRootDefinitions.PROFILE
                && b.outputProfile == VPCheckpoint.OUTPUT_PROFILE
                && b.adoptionRecord == authorityViewAdoption.adoptionRecord
                && b.checkpoint == address(avCheckpoint)
                && b.checkpointRecord == authorityViewPublication.checkpoint
                && b.outputManifest == address(avOutput)
                && b.outputManifestRecord == authorityViewPublication.outputManifest
                && b.preservationRenderer == address(avRenderer)
                && b.liveRenderer == address(authorityViewAdoption.liveRenderer),
            "exact VIEW content profile and genuine producer joins"
        );
    }

    function _authorityRequireViewPublication() internal view {
        _authorityRequireViewAdoption();
        _authorityRequireViewServing();
        require(
            _authorityViewCollectionRecordsHash() == authorityViewRecords.collectionBefore,
            "original COLLECTION history remains intact"
        );
        VPCheckpoint.Plan memory checkpoint =
            avCheckpoint.requireCurrentCheckpoint(authorityViewPublication.checkpoint);
        VPManifest.Plan memory manifest = avOutput.requireCurrentManifest(
            authorityViewPublication.outputManifest, assemblyArtistId
        );
        VPSnapshot.Receipt memory receipt = avSnapshot.requireCurrent(
            authorityViewAdoption.scope, authorityViewPublication.snapshotRecord, 1
        );
        require(
            keccak256(abi.encode(receipt))
                    == keccak256(abi.encode(authorityViewPublication.snapshotReceipt))
                && manifest.header.contentRoot == checkpoint.contentRoot
                && VPScopedRoot(address(assemblyRouter))
                    .scopedContentRootHead(authorityViewAdoption.scope)
                == authorityViewPublication.rootRecord,
            "same original VIEW source remains current after root"
        );
        for (uint256 i; i < authorityViewAdoption.tokens.length; ++i) {
            uint256 token = authorityViewAdoption.tokens[i];
            require(
                keccak256(_authorityViewPreservationBytes(token, false))
                        == keccak256(authorityViewJSON[token])
                    && keccak256(_authorityViewPreservationBytes(token, true))
                        == keccak256(authorityViewHTML[token]),
                "actual VIEW root does not change preservation bytes"
            );
        }
    }

    function _authorityLockViewContent() private {
        bytes32[] memory classes = new bytes32[](3);
        classes[0] = keccak256("SCRIPT");
        classes[1] = keccak256("MEDIA_MANIFEST");
        classes[2] = keccak256("BASE_URI");
        for (uint256 i; i < classes.length; ++i) {
            for (uint256 j = i + 1; j < classes.length; ++j) {
                if (classes[j] < classes[i]) (classes[i], classes[j]) = (classes[j], classes[i]);
            }
        }
        AssemblyContent.Freeze memory freeze = AssemblyContent.Freeze(
            1, address(assemblyRouter), classes, assemblyRouter.artistContentFreezeState(1)
        );
        T.Authorization memory authorization = _assemblyAuthorization(false);
        authorization.signature = _assemblyArtistProof(
            assemblyArtists.contentFreezeDigest(freeze, authorization), authorization.nonce
        );
        bytes32 originalFreeze = assemblyArtists.authorizeArtistContentFreeze(freeze, authorization);
        _authorityContentFreeze(freeze, originalFreeze);
        assemblyRouter.applyArtistContentFreeze(1, originalFreeze);
        IStreamMetadataServingFacts.ServingFacts memory serving =
            assemblyRouter.collectionServingFacts(1);
        require(
            serving.scriptLocked && serving.mediaLocked && serving.baseURILocked
                && serving.dependenciesLocked && serving.artistIdentityLocked
                && serving.displayMetadataLocked,
            "all original serving locks applied"
        );
    }
}
