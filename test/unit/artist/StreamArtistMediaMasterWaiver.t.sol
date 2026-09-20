// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./ArtistPublicationHydrationFixture.sol";
import "../../../smart-contracts/domains/metadata/StreamMediaMasterSelection.sol";

/// @dev Explicit governance boundary for the real Schema Registry and Metadata hosts.
/// It does not issue Artist attestations, publication permits, or master selections.
contract ArtistMasterWaiverGovernanceBoundary {
    address private immutable _root;
    bytes32 private immutable _rootHash;
    bool private _executing;
    bytes32 private _scope;
    bytes32 private _old;
    bytes32 private _next;

    constructor() {
        _root = msg.sender;
        _rootHash = msg.sender.codehash;
    }

    function isStreamGovernedParameterAuthority() external pure returns (bool) {
        return true;
    }

    function governanceRootState() external view returns (address, bytes32, uint64) {
        return (_root, _rootHash, 1);
    }

    function currentAction()
        external
        view
        returns (bool, bytes32, uint8, bytes32, bytes32, bytes32)
    {
        return (
            _executing,
            _executing ? keccak256("master waiver initialization") : bytes32(0),
            _executing ? 1 : 0,
            _scope,
            _old,
            _next
        );
    }

    function governanceAction(bytes32) external view returns (GovernanceAction memory a) {
        a.status = GovernanceActionStatus.EXECUTED;
        a.actionClass = 1;
        a.proposer = _root;
    }

    function execute(
        address target,
        bytes memory data,
        bytes32 scope,
        bytes32 oldHash,
        bytes32 nextHash
    ) external {
        require(msg.sender == _root, "fixture authority");
        _executing = true;
        _scope = scope;
        _old = oldHash;
        _next = nextHash;
        (bool ok, bytes memory reason) = target.call(data);
        if (!ok) assembly ("memory-safe") { revert(add(reason, 32), mload(reason)) }
        _executing = false;
        _scope = 0;
        _old = 0;
        _next = 0;
    }
}

/// @dev Constructor identity only. Every archive proof call fails: waiver success cannot use one.
contract ArtistMasterWaiverUnavailableArchiveBoundary {
    address public immutable core;
    address public immutable governanceAuthority;

    constructor(address core_, address executor_) {
        core = core_;
        governanceAuthority = executor_;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == type(IStreamExternalArtifactCoverage).interfaceId || id == 0x01ffc9a7;
    }

    fallback() external {
        revert("archive proof deliberately unavailable");
    }
}

/// @notice Actual original Artist op24/Safe signature, seven owners, Coordinator, Archive,
/// Metadata/Schema/Store, native stored media manifest and master-waiver selector.
/// @dev Core/governance and the existing suite Router remain typed boundaries. Only the Router's
/// serving-source/profile/manifest-selection replies are supplied by this fixture. No Artist
/// publication, statement, signature, consumption, Metadata receipt or payload read is mocked.
/// This exercises existing canonical Artist onboarding; it creates no documentary personhood proof.
contract StreamArtistMediaMasterWaiverTest is ArtistPublicationHydrationFixture {
    struct JoinedWaiver {
        ArtistMasterWaiverGovernanceBoundary governance;
        StreamSchemaRegistry schemas;
        StreamSchemaDocumentStore store;
        StreamCollectionMetadataV1 host;
        StreamMediaMasterSelection masters;
        ArtistMasterWaiverUnavailableArchiveBoundary unavailableArchive;
        StreamMediaMasterTypes.Waiver waiver;
        IStreamPreservationRecords.CollectionRecord original;
        P.Publication publication;
        bytes payload;
        bytes statement;
        bytes32 authorization;
        bytes32 manifest;
        bytes32 subject;
    }

    bytes32 private constant DISPLAY = keccak256("actual selected image payload");

    function _joinedMasterWaiver(bool secondSlot) private returns (JoinedWaiver memory j) {
        actualSaleRegistryFixture = true;
        setUp();
        _compactSource();
        _economicHistory();
        _recordRatification();
        j.governance = new ArtistMasterWaiverGovernanceBoundary();
        j.schemas = new StreamSchemaRegistry(address(j.governance));
        j.store = StreamSchemaDocumentStore(j.schemas.chunkStore());
        _register(
            j,
            "RAW_BYTES",
            IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
            bytes(j.schemas.RAW_BYTES_DEFINITION())
        );
        _register(
            j,
            "RFC8785_JCS",
            IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
            bytes(vm.readFile("schemas/museum/account-profile/RFC8785_JCS.json"))
        );
        _register(
            j,
            "STREAM_MASTER_WAIVER_V1",
            IStreamSchemaRegistry.DocumentKind.SCHEMA,
            bytes(vm.readFile("schemas/records/STREAM_MASTER_WAIVER_V1.json"))
        );
        _register(
            j,
            "STREAM_MEDIA_MASTER_SELECTED_SLOTS_PROFILE_V1",
            IStreamSchemaRegistry.DocumentKind.CATALOG,
            bytes(vm.readFile("schemas/records/STREAM_MEDIA_MASTER_SELECTED_SLOTS_PROFILE_V1.json"))
        );
        StreamCollectionMetadataV1.Configuration memory config;
        config.core = address(core);
        config.executor = address(j.governance);
        config.schemas = address(j.schemas);
        config.artistRegistry = address(ingress);
        config.deploymentManifestHash = keccak256("actual Artist master waiver join deployment");
        config.manifestHash = keccak256("actual Artist master waiver join manifest");
        config.manifestURI = "urn:artist-master-waiver-join";
        config.dependencyReadGas = IStreamGasParameterHost.GasParameterConfig(
            "METADATA_DEPENDENCY_READ_GAS", 150000, 100000, 2
        );
        config.artistReadGas = IStreamGasParameterHost.GasParameterConfig(
            "METADATA_ARTIST_READ_GAS", 2000000, 1000000, 2
        );
        j.host = new StreamCollectionMetadataV1(config);
        _saleRegister(
            saleModules,
            factory.governanceAuthority(),
            address(j.host),
            keccak256("COLLECTION_METADATA"),
            type(IStreamCollectionMetadataV1).interfaceId
        );
        core.set(keccak256("COLLECTION_METADATA"), address(j.host), false);
        (bytes32 scope, bytes32 oldHash, bytes32 nextHash) = j.host
            .recordTypeTransition(keccak256("ARTIST_STATEMENT"), StreamRecordFamilies.ARTIST, 2);
        j.governance
            .execute(
                address(j.host),
                abi.encodeCall(
                    j.host.admitRecordType,
                    (keccak256("ARTIST_STATEMENT"), StreamRecordFamilies.ARTIST, uint16(2))
                ),
                scope,
                oldHash,
                nextHash
            );
        j.subject = StreamMetadataSubjects.scopeSubject(
            block.chainid,
            address(core),
            StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0)
        );
        j.manifest = _selectedMedia(j.host, DISPLAY, secondSlot);
        j.unavailableArchive =
            new ArtistMasterWaiverUnavailableArchiveBoundary(address(core), address(j.governance));
        j.masters = new StreamMediaMasterSelection(
            address(core),
            address(j.host),
            address(j.schemas),
            address(j.unavailableArchive),
            address(j.governance),
            IStreamGasParameterHost.GasParameterConfig(
                "MEDIA_MASTER_MANIFEST_READ_GAS", 1000000, 500000, 2
            ),
            IStreamGasParameterHost.GasParameterConfig(
                "MEDIA_MASTER_COVERAGE_READ_GAS", 1000000, 500000, 2
            )
        );
        j.waiver = _waiver(j);
        j.payload = StreamMasterWaiverJson.waiver(j.waiver);
        (bytes32 payloadHash,) = j.store.publishChunk(j.payload);
        j.original.recordType = keccak256("ARTIST_STATEMENT");
        j.original.subjectId = j.subject;
        j.original.schemaId = keccak256("STREAM_MASTER_WAIVER_V1");
        j.original.contentHash = IStreamPreservationRecords.HashRef(
            1, abi.encode(payloadHash), keccak256("RFC8785_JCS")
        );
        j.original.uri = "ipfs://original-artist-master-waiver";
        j.original.effectiveAt = uint64(block.timestamp);
        j.publication = P.Publication(
            address(j.host),
            address(artist),
            1,
            j.subject,
            j.original.recordType,
            j.original.schemaId,
            keccak256("RFC8785_JCS"),
            1,
            payloadHash,
            keccak256(bytes(j.original.uri)),
            j.original.effectiveAt,
            j.host.deriveCollectionRecordHashFor(address(artist), 1, j.original)
        );
        require(
            j.publication.candidateRecordHash == _canonicalRecordHash(j.original, j.publication),
            "independent original Metadata record preimage"
        );
        T.Attestation memory attestation;
        (attestation, j.statement) = _canonicalAttestation(j.publication, j.original.uri);
        j.authorization = _recordPublication(j.publication, attestation, j.statement);
    }

    function _register(
        JoinedWaiver memory j,
        string memory name,
        IStreamSchemaRegistry.DocumentKind kind,
        bytes memory payload
    ) private {
        require(payload.length <= 8192, "one complete original document");
        (bytes32 hash,) = j.store.publishChunk(payload);
        bytes32[] memory chunks = new bytes32[](1);
        chunks[0] = hash;
        IStreamSchemaRegistry.DocumentSpec memory spec = IStreamSchemaRegistry.DocumentSpec(
            name, kind, hash, keccak256("RAW_BYTES"), 0, "", uint32(payload.length)
        );
        (bytes32 scope, bytes32 oldHash, bytes32 nextHash) =
            j.schemas.registrationTransition(spec, chunks);
        j.governance
            .execute(
                address(j.schemas),
                abi.encodeCall(j.schemas.registerDocument, (spec, chunks)),
                scope,
                oldHash,
                nextHash
            );
    }

    function _selectedMedia(StreamCollectionMetadataV1 host, bytes32 display, bool secondSlot)
        private
        returns (bytes32 manifest)
    {
        // Keep the original suite Router selected: the actual Artist Coordinator pins this host.
        require(suite.metadata == address(metadata), "original typed suite Router");
        IStreamMetadataServingFacts.ServingSource memory source;
        source.imageURI = "ar://artist-master-waiver-display";
        avm.mockCall(
            address(metadata),
            abi.encodeWithSignature("renderingProfile()"),
            abi.encode(
                keccak256("6529STREAM_ROUTER_STABLE_PRESENTATION_V1"),
                keccak256("6529STREAM_METADATA_TOKEN_RENDER_CONTEXT_V1"),
                keccak256("6529STREAM_METADATA_RENDER_NO_EXTERNAL_READS_V1")
            )
        );
        avm.mockCall(
            address(metadata),
            abi.encodeCall(IStreamMetadataServingFacts.collectionServingSource, (uint256(1))),
            abi.encode(source)
        );
        StreamCollectionManifestTypes.MediaManifest memory value;
        value.imageSourceType = StreamCollectionManifestTypes.PayloadSourceType.ARWEAVE;
        value.imageURI = source.imageURI;
        value.imageHash = display;
        value.imageMimeType = "image/tiff";
        if (secondSlot) {
            value.contentSourceType = StreamCollectionManifestTypes.PayloadSourceType.ARWEAVE;
            value.contentURI = "ar://artist-master-waiver-second-display";
            value.contentHash = keccak256("other occupied payload");
            value.contentMimeType = "video/mp4";
        }
        // Typed Router call boundary; Metadata itself validates, stores and later rereads this manifest.
        vm.prank(address(metadata));
        manifest = host.storeMediaManifest(1, value);
        avm.mockCall(
            address(metadata),
            abi.encodeCall(
                IStreamMetadataManifestSelection.selectedCollectionManifest, (uint256(1), uint8(3))
            ),
            abi.encode(
                StreamCollectionManifestTypes.Selection(
                    address(host), address(host).codehash, manifest
                )
            )
        );
        require(
            host.mediaManifestHash(1) == manifest
                && keccak256(abi.encode(host.mediaManifest(1))) == keccak256(abi.encode(value)),
            "actual stored and selected native manifest"
        );
    }

    function _waiver(JoinedWaiver memory j)
        private
        view
        returns (StreamMediaMasterTypes.Waiver memory w)
    {
        T.Binding memory binding_ = IStreamArtistBindingOwner(suite.owners[0]).binding(1);
        w.subjectId = j.subject;
        w.scopeSubjectId = j.subject;
        w.artist = StreamMediaMasterTypes.Artist(
            binding_.artistId, binding_.generation, binding_.bindingHash
        );
        w.reason = "The original artist waives a separate preservation master for this image slot.";
        w.waiverStatement = StreamConservationRecordTypes.Reference(
            1,
            keccak256("RAW_BYTES"),
            abi.encode(keccak256("original signed waiver statement")),
            "ipfs://signed-master-waiver-statement"
        );
        w.mediaObjects = new StreamMediaMasterTypes.WaivedObject[](1);
        w.mediaObjects[0].objectId = j.masters.mediaObjectId(1, j.subject, j.manifest, 1, DISPLAY);
        w.mediaObjects[0].mediaClass = StreamMediaMasterTypes.MediaClass.STILL_IMAGE;
        w.mediaObjects[0].masterRoles = new StreamMediaMasterTypes.Role[](1);
        w.mediaObjects[0].masterRoles[0] = StreamMediaMasterTypes.Role.SOURCE_MASTER;
    }

    function _publish(JoinedWaiver memory j) private {
        require(
            this.executeTargetSafe(address(j.host), _publicationCall(j, j.payload)),
            "actual original Artist Safe publishes original waiver bytes"
        );
    }

    function _publicationCall(JoinedWaiver memory j, bytes memory payload)
        private
        view
        returns (bytes memory)
    {
        return abi.encodeCall(
            j.host.recordArtistCollectionRecordWithPayload,
            (address(artist), uint256(1), j.original, payload, j.authorization)
        );
    }

    function _selectionCall(JoinedWaiver memory j, uint8 slot) private pure returns (bytes memory) {
        return abi.encodeCall(
            j.masters.adoptWaiver,
            (
                uint256(1),
                slot,
                j.manifest,
                j.publication.candidateRecordHash,
                uint64(0),
                j.original,
                j.waiver
            )
        );
    }

    function _assertOriginal(JoinedWaiver memory j) private view {
        IStreamArtistRecordPublicationOwner.Record memory publication = IStreamArtistRecordPublicationOwner(
                suite.owners[4]
            ).publicationAttestation(j.authorization);
        T.AttestationRecord memory attestation =
            IStreamArtistAttributionOwner(suite.owners[4]).attestationRecord(j.authorization);
        bytes memory statement = IStreamArtistAttributionOwner(suite.owners[4])
            .statementBytes(attestation.statementHash);
        bytes memory signatures =
            IStreamArtistIdentityOwner(suite.owners[2]).signatureBundle(j.authorization);
        require(
            keccak256(abi.encode(publication.publication)) == keccak256(abi.encode(j.publication))
                && publication.evidence.attestationRecordHash == j.authorization
                && publication.evidence.signer == address(artist)
                && publication.evidence.authorityClass == 1
                && publication.evidence.requiredCapability == 1
                && publication.evidence.artistId == artistId,
            "genuine original Artist op24 approval and capability"
        );
        require(
            attestation.recordHash == j.authorization && attestation.subjectStateHash == 0
                && attestation.schemaId == keccak256("6529STREAM_ARTIST_RECORD_PUBLICATION_V1")
                && attestation.statementHash == keccak256(j.statement) && statement.length == 416
                && keccak256(statement) == keccak256(j.statement) && signatures.length != 0
                && keccak256(signatures) == keccak256(publicationAuthorizations[0].signature),
            "original full statement and actual threshold-signature bytes"
        );
        (
            IStreamPreservationRecords.CollectionRecord memory record,
            IStreamCollectionMetadataV1.RecordReceipt memory receipt
        ) = j.host.collectionRecord(j.publication.candidateRecordHash);
        (, bytes memory payload) = j.host.recordPayload(j.publication.candidateRecordHash);
        require(
            keccak256(abi.encode(record)) == keccak256(abi.encode(j.original))
                && keccak256(payload) == keccak256(j.payload)
                && receipt.artistAuthorization == j.authorization
                && receipt.recorder == address(artist) && receipt.authorizationClass == 1
                && receipt.schemaDefinitionHash == StreamMediaMasterDefinitions.WAIVER_SCHEMA_HASH
                && receipt.canonicalizationDefinitionHash == StreamWorkRecordDefinitions.CANON_HASH
                && j.host.consumedArtistAuthorization(j.authorization),
            "exact original Metadata receipt, full bytes and consumed authorization"
        );
    }

    function testActualArtistMasterWaiverOp24PublicationAndSelection() external {
        JoinedWaiver memory j = _joinedMasterWaiver(false);
        _publish(j);
        _assertOriginal(j);
        vm.prank(address(0xBEEF));
        StreamMediaMasterTypes.Selection memory selected = j.masters
            .adoptWaiver(
                1, 1, j.manifest, j.publication.candidateRecordHash, 0, j.original, j.waiver
            );
        require(
            selected.status == StreamMediaMasterTypes.Status.WAIVED && selected.revision == 1
                && selected.original.recorder == address(artist)
                && selected.original.recordHash == j.publication.candidateRecordHash
                && selected.original.publication.attestationRecordHash == j.authorization
                && selected.original.publication.requiredCapability == 1
                && selected.coverageHash == 0 && selected.masterObjectHash == 0
                && selected.association.artistId == artistId,
            "actual original Artist waiver materialized by unrelated relayer"
        );
        require(
            j.masters.requireCollectionMasters(1, j.subject) != 0,
            "complete one-slot waiver succeeds while every archive proof call reverts"
        );
        bytes32 expected = selected.selectionHash;
        selected.selectionHash = 0;
        require(
            expected
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_MEDIA_MASTER_SELECTION_V1"),
                        block.chainid,
                        address(j.masters),
                        address(core),
                        address(j.host),
                        address(j.schemas),
                        address(j.unavailableArchive),
                        StreamMediaMasterDefinitions.PROFILE_HASH,
                        uint256(1),
                        selected
                    )
                ),
            "independent complete selection commitment"
        );
    }

    function testActualArtistMasterWaiverWrongPayloadPreservesPermitAndSafeNonceForRetry()
        external
    {
        JoinedWaiver memory j = _joinedMasterWaiver(false);
        uint256 nonce = artist.nonce();
        bytes memory wrong = bytes.concat(j.payload, bytes(" "));
        bytes memory failedCall = _publicationCall(j, wrong);
        vm.expectRevert(bytes("GS013"));
        this.executeTargetSafe(address(j.host), failedCall);
        require(
            artist.nonce() == nonce && !j.host.consumedArtistAuthorization(j.authorization)
                && j.masters.currentMaster(1, j.subject, 1).revision == 0,
            "changed original payload rolls back Safe nonce, authorization and selection"
        );
        _publish(j);
        require(artist.nonce() == nonce + 1, "only exact publication advances Safe nonce");
        _assertOriginal(j);
        j.masters
            .adoptWaiver(
                1, 1, j.manifest, j.publication.candidateRecordHash, 0, j.original, j.waiver
            );
        require(
            j.masters.requireCollectionMasters(1, j.subject) != 0, "same genuine approval retries"
        );
    }

    function testActualArtistMasterWaiverWrongSlotAndChangedManifestPreserveSafeSelectionRetry()
        external
    {
        JoinedWaiver memory j = _joinedMasterWaiver(true);
        _publish(j);
        uint256 nonce = artist.nonce();
        bytes memory wrongSlot = _selectionCall(j, 3);
        vm.expectRevert(bytes("GS013"));
        this.executeTargetSafe(address(j.masters), wrongSlot);
        require(
            artist.nonce() == nonce && j.masters.currentMaster(1, j.subject, 3).revision == 0,
            "original waiver for image cannot authorize other occupied content slot"
        );
        bytes memory exactSelection = _selectionCall(j, 1);
        require(
            _selectedMedia(j.host, keccak256("changed current image"), true) != j.manifest,
            "different actual selected manifest"
        );
        vm.expectRevert(bytes("GS013"));
        this.executeTargetSafe(address(j.masters), exactSelection);
        require(
            artist.nonce() == nonce && j.masters.currentMaster(1, j.subject, 1).revision == 0
                && j.host.consumedArtistAuthorization(j.authorization),
            "current-manifest failure leaves selection and Safe nonce unchanged, original retained"
        );
        require(
            _selectedMedia(j.host, DISPLAY, true) == j.manifest, "restore exact native original"
        );
        require(
            this.executeTargetSafe(address(j.masters), exactSelection),
            "identical Safe selection retry"
        );
        require(
            artist.nonce() == nonce + 1 && j.masters.currentMaster(1, j.subject, 1).revision == 1
                && j.masters.currentMaster(1, j.subject, 3).revision == 0,
            "only original image slot selected; other occupied slot remains unsatisfied"
        );
        _assertOriginal(j);
    }
}
