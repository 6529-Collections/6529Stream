// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./PreservationReferenceFixture.sol";
import {
    ConservationSelectionCoordinatorBoundary,
    ConservationSelectionOwnerBoundary
} from "../metadata/StreamConservationSelectionFixture.sol";
import {
    StreamWorkRecordSelection
} from "../../../smart-contracts/domains/metadata/StreamWorkRecordSelection.sol";
import {
    StreamRightsRecordSelection
} from "../../../smart-contracts/domains/metadata/StreamRightsRecordSelection.sol";
import {
    StreamConservationRecordSelection
} from "../../../smart-contracts/domains/metadata/StreamConservationRecordSelection.sol";
import {
    StreamRenderCriticalInventory
} from "../../../smart-contracts/domains/preservation/StreamRenderCriticalInventory.sol";
import {
    StreamArtistArchiveV2
} from "../../../smart-contracts/domains/artist/StreamArtistArchiveV2.sol";
import {
    IStreamWorkRecordSelection
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamWorkRecordSelection.sol";
import {
    IStreamConservationRecordSelection
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamConservationRecordSelection.sol";
import {
    StreamWorkRecordTypes
} from "../../../smart-contracts/interfaces/stream/metadata/StreamWorkRecordTypes.sol";
import {
    StreamRightsRecordTypes
} from "../../../smart-contracts/interfaces/stream/metadata/StreamRightsRecordTypes.sol";
import {
    StreamConservationRecordTypes
} from "../../../smart-contracts/interfaces/stream/metadata/StreamConservationRecordTypes.sol";
import {
    StreamWorkRecordDefinitions
} from "../../../smart-contracts/domains/records/StreamWorkRecordDefinitions.sol";
import {
    StreamRightsRecordDefinitions
} from "../../../smart-contracts/domains/records/StreamRightsRecordDefinitions.sol";
import {
    StreamConservationDefinitions
} from "../../../smart-contracts/domains/records/StreamConservationDefinitions.sol";
import {
    StreamWorkRecordJson
} from "../../../smart-contracts/domains/records/StreamWorkRecordJson.sol";
import {
    StreamRightsRecordJson
} from "../../../smart-contracts/domains/records/StreamRightsRecordJson.sol";
import {
    StreamArtistIntentWaiverJson
} from "../../../smart-contracts/domains/records/StreamArtistIntentWaiverJson.sol";
import {
    IStreamArtistContentRecordsOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistContentOwner.sol";
import {
    IStreamArtistRecordPublicationOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistRecordPublicationOwner.sol";
import {
    StreamArtistContentTypes
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistContentTypes.sol";
import { StreamArtistHashes } from "../../../smart-contracts/domains/artist/StreamArtistHashes.sol";
import {
    StreamArtistContentHashes
} from "../../../smart-contracts/domains/artist/StreamArtistContentHashes.sol";
import {
    StreamArtistOnboardingTypes as Art
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistRecordPublicationTypes as Pub
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecordPublicationTypes.sol";
import {
    StreamArtistRotationTypes as Rotation
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRotationTypes.sol";
import {
    StreamPreservationArtistBundleReads as ArtistBundle
} from "../../../smart-contracts/domains/preservation/StreamPreservationArtistBundleReads.sol";
import {
    StreamRenderCriticalSourceTypes as SourcesT
} from "../../../smart-contracts/interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamPreservationInventoryTypes as InventoryT
} from "../../../smart-contracts/interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";

contract PreservationContentOwnerBoundary {
    mapping(bytes32 => IStreamArtistContentRecordsOwner.ConsentRecord) private records;

    function save(IStreamArtistContentRecordsOwner.ConsentRecord memory r) external {
        records[r.recordHash] = r;
    }

    function contentConsentRecord(bytes32 id)
        external
        view
        returns (IStreamArtistContentRecordsOwner.ConsentRecord memory)
    {
        return records[id];
    }
}

/// @dev Actual all-eight producer graph, schema/store/original Metadata receipts, selectors,
/// Snapshot, Reference and ArchiveV2. Core/artist owners/Executor/native seed and network
/// observations remain typed boundaries. Archive append authorization is actual, while the
/// explicit Coordinator fixture supplies the original op17/op24 semantic owner observations.
abstract contract PreservationActualInventoryFixture is PreservationReferenceFixture {
    ConservationSelectionCoordinatorBoundary internal artistCoordinator;
    ConservationSelectionOwnerBoundary internal bindingOwner;
    ConservationSelectionOwnerBoundary internal identityOwner;
    ConservationSelectionOwnerBoundary internal attributionOwner;
    PreservationContentOwnerBoundary internal contentOwner;
    StreamArtistArchiveV2 internal artistArchive;
    StreamWorkRecordSelection internal workSelector;
    StreamRightsRecordSelection internal rightsSelector;
    StreamConservationRecordSelection internal conservationSelector;
    StreamRenderCriticalInventory internal renderInventory;
    SourcesT.Dependencies internal inventoryDependencies;
    Art.Binding internal originalBinding;
    Art.SuiteConfiguration internal originalSuite;
    StreamWorkRecordTypes.Description internal selectedWork;
    StreamRightsRecordTypes.Statement internal selectedRights;
    StreamConservationRecordTypes.IntentWaiver internal selectedWaiver;
    uint256 internal originalNonce;
    bytes32 internal workRecord;
    bytes32 internal rightsRecord;
    bytes32 internal waiverRecord;

    function setUp() public virtual override {
        super.setUp();
        _descriptiveDefinitions();
        _admitInventoryType(keccak256("WORK_DESCRIPTION"), StreamRecordFamilies.CURATOR, 0x010a);
        _admitInventoryType(keccak256("RIGHTS_STATEMENT"), StreamRecordFamilies.RIGHTS, 0x0180);
        _admitInventoryType(keccak256("ARTIST_INTENT"), StreamRecordFamilies.ARTIST, 2);
        _admitInventoryType(keccak256("ARTIST_INTENT_WAIVER"), StreamRecordFamilies.ARTIST, 2);
        _admitInventoryType(keccak256("ARTIST_STATEMENT"), StreamRecordFamilies.ARTIST, 2);
        _inventoryGrant(StreamRecordFamilies.RIGHTS, 7);
        workSelector =
            new StreamWorkRecordSelection(address(core), address(metadata), address(schemas));
        rightsSelector =
            new StreamRightsRecordSelection(address(core), address(metadata), address(schemas));
        conservationSelector = new StreamConservationRecordSelection(
            address(core), address(metadata), address(schemas)
        );
        _selectDescriptions();
        _selectConservation();
        _referencePublish(address(this));
        inventoryDependencies.targets = [
            address(core),
            address(metadata),
            address(schemas),
            address(store),
            address(router),
            address(snapshots),
            address(referenceHost),
            address(workSelector),
            address(rightsSelector),
            address(conservationSelector),
            artifactTarget,
            address(archiveHost)
        ];
        for (uint256 i; i < 12; ++i) {
            inventoryDependencies.codeHashes[i] = inventoryDependencies.targets[i].codehash;
        }
        inventoryDependencies.artistTargets = [
            address(artist),
            address(artistCoordinator),
            address(identityOwner),
            address(attributionOwner),
            address(artistArchive)
        ];
        for (uint256 i; i < 5; ++i) {
            inventoryDependencies.artistCodeHashes[i] =
            inventoryDependencies.artistTargets[i].codehash;
        }
        inventoryDependencies.artistContentOwner = address(contentOwner);
        inventoryDependencies.artistContentOwnerCodeHash = address(contentOwner).codehash;
        inventoryDependencies.chainId = block.chainid;
        inventoryDependencies.readGas = 500000;
        inventoryDependencies.sourceGas = 4000000;
        inventoryDependencies.selectionGas = 4000000;
        inventoryDependencies.snapshotGas = 6000000;
        // The publisher decodes the complete retained reference before it forwards
        // the independent 6M Snapshot validation cap; 8M cannot cover both stages.
        inventoryDependencies.referenceGas = 12000000;
        renderInventory = new StreamRenderCriticalInventory(inventoryDependencies);
    }

    function _artistOwnerContext() internal {
        artistCoordinator = new ConservationSelectionCoordinatorBoundary();
        bindingOwner = new ConservationSelectionOwnerBoundary();
        identityOwner = new ConservationSelectionOwnerBoundary();
        attributionOwner = new ConservationSelectionOwnerBoundary();
        contentOwner = new PreservationContentOwnerBoundary();
        artistArchive = new StreamArtistArchiveV2(address(artist), address(artistCoordinator));
        bindingOwner.configure(address(core), address(artist), address(artistCoordinator));
        identityOwner.configure(address(core), address(artist), address(artistCoordinator));
        attributionOwner.configure(address(core), address(artist), address(artistCoordinator));
        originalBinding = Art.Binding(
            keccak256("artist"),
            address(0xA11CE),
            keccak256("identity"),
            keccak256("binding"),
            1,
            1,
            0,
            0,
            address(this),
            true
        );
        // Root's locked original presentation retains this nominee and identity. The
        // semantic current-authority fixture below is a different key; no actual key
        // rotation transaction is claimed by this typed owner boundary.
        bindingOwner.setBinding(originalBinding, 2);
        attributionOwner.setBinding(originalBinding, 2);
        identityOwner.setIdentity(address(this), 1, 1, originalBinding.identityRecordHash);
        originalSuite.registry = address(artist);
        originalSuite.core = address(core);
        originalSuite.metadata = address(router);
        originalSuite.mintManager = address(this);
        originalSuite.archive = address(artistArchive);
        originalSuite.owners[0] = address(bindingOwner);
        originalSuite.owners[2] = address(identityOwner);
        originalSuite.owners[4] = address(attributionOwner);
        originalSuite.owners[6] = address(contentOwner);
        artistCoordinator.setSuite(originalSuite);
        cheat.mockCall(
            address(artist),
            abi.encodeWithSignature("operationCoordinator()"),
            abi.encode(address(artistCoordinator))
        );
        cheat.mockCall(
            address(artistCoordinator),
            abi.encodeWithSignature("configurationHash()"),
            abi.encode(keccak256(abi.encode(originalSuite)))
        );
    }

    function _root() internal virtual override {
        _artistOwnerContext();
        bytes32 cp = checkpoint.beginCollectionCheckpoint(1);
        IStreamOnchainContentCheckpoint.TokenPayload[] memory payloads =
            new IStreamOnchainContentCheckpoint.TokenPayload[](2);
        for (uint256 i; i < 2; ++i) {
            payloads[i] = _originalTokenPayload(i + 1);
        }
        checkpoint.appendCheckpointTokens(cp, payloads);
        IStreamOnchainContentCheckpoint.Plan memory plan = checkpoint.requireCurrentCheckpoint(cp);
        StreamTokenContentLeaf[] memory rows = new StreamTokenContentLeaf[](2);
        rows[0] = checkpoint.checkpointLeaf(cp, 0);
        rows[1] = checkpoint.checkpointLeaf(cp, 1);
        bytes memory raw = abi.encode(
            StreamContentRootSchemas.LEAF_SCHEMA,
            block.chainid,
            address(core),
            address(checkpoint),
            cp,
            uint256(1),
            plan.contentRoot,
            plan.tokenCount,
            rows
        );
        (bytes32 artifact, bytes32 coverage) = _coverOriginalLeaf(raw);
        bytes32 lp = leaves.beginManifest(cp, artifact, coverage, keccak256("artist"));
        bytes32 lm = leaves.verifyNextLeaves(lp, 2);
        IStreamContentRootPublication.Publication memory p =
            IStreamContentRootPublication.Publication(1, 0, lm, "ipfs://actual-leaf-manifest");
        _rootAuthorization(p);
        rootRecord = router.publishVerifiedTokenContentRoot(p);
    }

    function _coverOriginalLeaf(bytes memory raw) internal virtual returns (bytes32, bytes32) {
        (, address pointer) = store.publishChunk(raw);
        archive.configure(raw, pointer);
        return (keccak256("artifact"), keccak256("coverage"));
    }

    function _rootAuthorization(IStreamContentRootPublication.Publication memory publication)
        private
    {
        bytes32 state = router.previewContentRootPublication(publication, address(this));
        Art.Authorization memory auth =
            Art.Authorization(++originalNonce, uint64(block.timestamp + 1000), "");
        StreamArtistContentTypes.Consent memory consent =
            StreamArtistContentTypes.Consent(1, address(router), keccak256("CONTENT_ROOT"), state);
        StreamArtistHashes.Environment memory env = _artistEnvironment();
        Art.SignerApproval memory approval = Art.SignerApproval(
            address(this), StreamArtistContentHashes.consentDigest(env, consent, auth), true
        );
        bytes32 hash = StreamArtistContentHashes.consentRecord(
            env,
            consent,
            originalBinding.artistId,
            address(this),
            1,
            auth.nonce,
            uint64(block.timestamp)
        );
        contentOwner.save(
            IStreamArtistContentRecordsOwner.ConsentRecord(
                hash, originalBinding.artistId, 1, consent, 1
            )
        );
        _archiveOriginal(
            17,
            hash,
            abi.encode(
                originalBinding, consent, auth, approval, keccak256("original pre-content state")
            )
        );
        artist.approve(state, hash);
    }

    function _archiveOriginal(uint16 op, bytes32 record, bytes memory payload) private {
        Art.Snapshot[7] memory before_;
        Art.Snapshot[7] memory after_;
        bytes memory raw = abi.encode(
            uint16(1),
            keccak256(abi.encode(originalSuite)),
            op,
            address(this),
            record,
            before_,
            after_,
            payload
        );
        bytes32 id = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"),
                block.chainid,
                address(artist),
                address(artistCoordinator),
                op,
                address(this),
                record
            )
        );
        vm.prank(address(artistCoordinator));
        artistArchive.appendArtistEvidenceV2(id, 1, raw);
    }

    function _artistEnvironment() private view returns (StreamArtistHashes.Environment memory) {
        return StreamArtistHashes.Environment(
            block.chainid, address(artist), address(core), address(this)
        );
    }

    function _descriptiveDefinitions() private {
        string[14] memory names = [
            "STREAM_WORK_DESCRIPTION_V1",
            "STREAM_WORK_DESCRIPTION_JSON_PROFILE_V1",
            "STREAM_WORK_FORMAT_CATALOG_V1",
            "STREAM_WORK_FORMAT_CATALOG_JSON_PROFILE_V1",
            "STREAM_RIGHTS_V1",
            "STREAM_RIGHTS_JSON_PROFILE_V1",
            "STREAM_ARTIST_INTENT_V1",
            "STREAM_ARTIST_INTENT_JSON_PROFILE_V1",
            "STREAM_ARTIST_INTENT_WAIVER_V1",
            "STREAM_ARTIST_INTENT_WAIVER_JSON_PROFILE_V1",
            "STREAM_ARTIST_INTERVIEW_V1",
            "STREAM_ARTIST_INTERVIEW_JSON_PROFILE_V1",
            "STREAM_CONSERVATION_FORMAT_CATALOG_V1",
            "STREAM_CONSERVATION_FORMAT_CATALOG_JSON_PROFILE_V1"
        ];
        for (uint256 i; i < names.length; ++i) {
            _snapshotDocument(
                names[i],
                i % 2 == 0
                    ? IStreamSchemaRegistry.DocumentKind.SCHEMA
                    : IStreamSchemaRegistry.DocumentKind.CATALOG,
                bytes(vm.readFile(string.concat("schemas/records/", names[i], ".json")))
            );
        }
    }

    function _admitInventoryType(bytes32 kind, bytes32 family, uint16 mask) private {
        (bytes32 s, bytes32 o, bytes32 n) = metadata.recordTypeTransition(kind, family, mask);
        executor.execute(
            address(metadata),
            abi.encodeCall(metadata.admitRecordType, (kind, family, mask)),
            s,
            o,
            n
        );
    }

    function _inventoryGrant(bytes32 family, uint8 cls) private {
        (bytes32 s, bytes32 o, bytes32 n) =
            metadata.familyWriterTransition(1, family, cls, address(this), true);
        executor.execute(
            address(metadata),
            abi.encodeCall(metadata.setFamilyWriter, (1, family, cls, address(this), true)),
            s,
            o,
            n
        );
    }

    function _originalRecord(bytes32 kind, bytes32 schema, bytes memory payload)
        private
        view
        returns (IStreamPreservationRecords.CollectionRecord memory r)
    {
        r.recordType = kind;
        r.subjectId = _subject();
        r.schemaId = schema;
        r.effectiveAt = 1;
        r.uri = "ipfs://original-preservation-record";
        r.contentHash = IStreamPreservationRecords.HashRef(
            1, abi.encodePacked(keccak256(payload)), keccak256("RFC8785_JCS")
        );
    }

    function _selectDescriptions() private {
        selectedWork.subjectId = _subject();
        selectedWork.profileHash = StreamWorkRecordDefinitions.PROFILE_HASH;
        selectedWork.full.title = "Actual native preservation work";
        selectedWork.full.creator.kind = StreamWorkRecordTypes.CreatorKind.ARTIST;
        selectedWork.full.creator.artistId = originalBinding.artistId;
        selectedWork.full.creator.bindingGeneration = originalBinding.generation;
        selectedWork.full.creator.bindingHash = originalBinding.bindingHash;
        selectedWork.full.creation.start = 20240229;
        selectedWork.full.medium = "Generative instructions";
        selectedWork.full.measurements.kind =
        StreamWorkRecordTypes.MeasurementKind.DIMENSIONLESS_GENERATIVE;
        selectedWork.full.creditLine = "Original record";
        bytes memory raw = StreamWorkRecordJson.serialize(selectedWork);
        IStreamPreservationRecords.CollectionRecord memory r = _originalRecord(
            keccak256("WORK_DESCRIPTION"), StreamWorkRecordDefinitions.SCHEMA_ID, raw
        );
        workRecord = metadata.recordCollectionRecordWithPayload(1, r, raw);
        workSelector.selectCurrent(
            1, _subject(), workRecord, 0, 0, IStreamWorkRecordSelection.Witness(r, selectedWork)
        );
        selectedRights.subjectId = _subject();
        selectedRights.profileHash = StreamRightsRecordDefinitions.PROFILE_HASH;
        selectedRights.licensor.kind = StreamRightsRecordTypes.LicensorKind.ACCOUNT;
        selectedRights.licensor.account = address(this);
        selectedRights.startDate = 20240229;
        selectedRights.openEnd = true;
        raw = StreamRightsRecordJson.serialize(selectedRights);
        r = _originalRecord(
            keccak256("RIGHTS_STATEMENT"), StreamRightsRecordDefinitions.SCHEMA_ID, raw
        );
        rightsRecord = metadata.recordCollectionRecordWithPayload(1, r, raw);
        rightsSelector.selectCurrent(1, _subject(), rightsRecord, 0, 0, selectedRights);
    }

    function _selectedReference(string memory uri)
        private
        pure
        returns (StreamConservationRecordTypes.Reference memory r)
    {
        r.algorithm = 1;
        r.canonicalizationId = keccak256("RAW_BYTES");
        r.digest = abi.encodePacked(keccak256(bytes(uri)));
        r.uri = uri;
    }

    function _selectConservation() private {
        selectedWaiver.subjectId = _subject();
        selectedWaiver.profileHash = StreamConservationDefinitions.WAIVER_PROFILE_HASH;
        selectedWaiver.artist = StreamConservationRecordTypes.ArtistClaim(
            originalBinding.artistId,
            1,
            originalBinding.bindingHash,
            StreamConservationRecordTypes.StatementOrigin.ARTIST_INTENT
        );
        selectedWaiver.waiverStatement = _selectedReference("ipfs://explicit-intent-waiver");
        selectedWaiver.interview.status = StreamConservationRecordTypes.InterviewStatus.WAIVED;
        selectedWaiver.interview.waiverStatement =
            _selectedReference("ipfs://independent-interview-waiver");
        bytes memory raw = StreamArtistIntentWaiverJson.serialize(selectedWaiver);
        IStreamPreservationRecords.CollectionRecord memory r = _originalRecord(
            keccak256("ARTIST_INTENT_WAIVER"), StreamConservationDefinitions.WAIVER_SCHEMA_ID, raw
        );
        waiverRecord = _publishOriginalArtist(r, raw);
        IStreamConservationRecordSelection.WaiverWitness memory witness;
        witness.original = r;
        witness.waiver = selectedWaiver;
        conservationSelector.adoptWaiver(1, _subject(), waiverRecord, 0, 0, witness);
    }

    function _publishOriginalArtist(
        IStreamPreservationRecords.CollectionRecord memory r,
        bytes memory raw
    ) private returns (bytes32) {
        Pub.Publication memory p;
        p.metadataHost = address(metadata);
        p.recorder = address(this);
        p.collectionId = 1;
        p.subjectId = _subject();
        p.recordType = r.recordType;
        p.schemaId = r.schemaId;
        p.canonicalizationId = r.contentHash.canonicalizationId;
        p.payloadAlgorithm = 1;
        p.payloadHash = keccak256(raw);
        p.uriHash = keccak256(bytes(r.uri));
        p.effectiveAt = r.effectiveAt;
        p.candidateRecordHash = metadata.deriveCollectionRecordHashFor(address(this), 1, r);
        bytes memory statement = abi.encode(uint16(1), p);
        Art.Attestation memory attestation = Art.Attestation(
            1,
            7,
            _subject(),
            p.candidateRecordHash,
            keccak256("6529STREAM_ARTIST_RECORD_PUBLICATION_V1"),
            keccak256(statement),
            "ipfs://original-publication"
        );
        Art.Authorization memory auth =
            Art.Authorization(++originalNonce, uint64(block.timestamp), "");
        Art.SignerApproval memory approval = Art.SignerApproval(
            address(this),
            StreamArtistHashes.attestationDigest(_artistEnvironment(), attestation, auth),
            true
        );
        bytes32 authorization = StreamArtistHashes.attestationRecordForAuthority(
            _artistEnvironment(),
            attestation,
            originalBinding.artistId,
            address(this),
            1,
            auth.nonce,
            auth.time
        );
        Pub.Evidence memory evidence = Pub.Evidence(
            authorization,
            originalBinding.artistId,
            originalBinding.bindingHash,
            1,
            address(this),
            1,
            64,
            uint64(block.timestamp),
            keccak256(abi.encode(p))
        );
        attributionOwner.savePublication(
            IStreamArtistRecordPublicationOwner.Record(p, evidence, address(metadata).codehash)
        );
        cheat.mockCall(
            address(artist),
            abi.encodeWithSignature(
                "requireRecordPublication(bytes32,(address,address,uint256,bytes32,bytes32,bytes32,bytes32,uint16,bytes32,bytes32,uint64,bytes32))",
                authorization,
                p
            ),
            abi.encode(evidence)
        );
        _archiveOriginal(
            24,
            authorization,
            abi.encode(
                originalBinding,
                attestation,
                auth,
                statement,
                approval,
                auth,
                Rotation.AuthorityFact(originalBinding.artistId, address(this), 1, 1),
                p,
                address(metadata).codehash
            )
        );
        return
            metadata.recordArtistCollectionRecordWithPayload(
                address(this), 1, r, raw, authorization
            );
    }

    function _originalTokenPayload(uint256 id)
        internal
        view
        returns (IStreamOnchainContentCheckpoint.TokenPayload memory p)
    {
        p.tokenId = id;
        p.image = imageBytes;
        p.animation = abi.encodePacked(
            "<html><head></head><body><script>const tokenId=",
            Strings.toString(id),
            ";const tokenHash='",
            Strings.toHexString(uint256(77), 32),
            "';const tokenDataBase64='AP8=';",
            router.collectionServingSource(1).script,
            "</script></body></html>"
        );
    }
}
