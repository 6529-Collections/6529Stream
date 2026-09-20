// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./CurrentDocumentaryRecordsFixture.sol";
import "../../smart-contracts/domains/metadata/StreamMediaMasterSelection.sol";
import "../../smart-contracts/domains/records/StreamMasterWaiverJson.sol";
import {
    IStreamArtistContentAuthority
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistContentAuthority.sol";
import {
    StreamArtistContentTypes
} from "../../smart-contracts/interfaces/stream/artist/StreamArtistContentTypes.sol";
import "../../smart-contracts/vendor/openzeppelin/Strings.sol";

/// @notice Occupied original media with actual Metadata, Artist, master selection and archive hosts.
/// @dev Complete tiny PPM display/master bytes are deterministic local artifacts. Real production
/// checkpoint, receipt, fixity and coverage checks use local test signers; this is not a public
/// Arweave upload, external retrieval, or independent institutional preservation claim.
abstract contract CurrentDocumentaryMediaFixture is CurrentDocumentaryRecordsFixture {
    using Strings for uint256;

    uint256 private constant MEDIA_ENDOWED_KEY = 0xD0C101;
    uint256 private constant MEDIA_INSTITUTION_KEY = 0xD0C102;
    uint256 private constant MEDIA_FIXITY_KEY = 0xD0C103;
    bytes32 private constant MEDIA_FAMILY = keccak256("MEDIA_MANIFEST");
    bytes32 private constant SCRIPT_FAMILY = keccak256("SCRIPT");
    bytes32 private constant MEDIA_RECORD = keccak256("MEDIA_RELATIONSHIP");

    struct DocumentaryMediaVariant {
        bytes32 manifestHash;
        bytes32 displayHash;
        bytes32 inventoryHash;
        bytes32 masterObjectHash;
        bytes32 checkpointHash;
        bytes32 firstReceipt;
        bytes32 secondReceipt;
        bytes32 coverageHash;
        bytes32 associationRecordHash;
        bytes32 selectionHash;
        bytes32 mediaEvidenceHash;
    }

    StreamMediaMasterSelection internal documentaryMasters;
    bytes32 internal documentaryMediaSubject;
    bytes32 internal documentaryMediaManifestHash;
    bytes32 internal documentaryMediaInventoryHash;
    bytes32 internal documentaryMediaEvidenceHash;
    bytes32 internal documentaryMasterRecordHash;
    bytes32 internal documentaryMasterObjectHash;
    bytes32 internal documentaryMasterCoverageHash;
    mapping(uint256 => DocumentaryMediaVariant) internal documentaryMediaVariants;
    bytes32 private documentaryEndowedFamily;
    bytes32 private documentaryInstitutionFamily;
    bytes32 private documentaryObjectSchema;
    bytes32 private documentaryFormatCatalog;
    bytes32 private documentaryFormatCatalogHash;
    uint256 private currentDocumentaryVariant;
    bool private hasDocumentaryVariant;

    function _additionalOperatingPolicies()
        internal
        view
        virtual
        override
        returns (GovernanceActionPolicyEntry[] memory)
    {
        GovernanceActionPolicyEntry[] memory rows = super._additionalOperatingPolicies();
        // The current graph deploys ExternalArtifactCoverage before the first product catalog.
        require(
            address(assemblyExternal).code.length != 0, "actual original archive before catalog"
        );
        GovernanceActionPolicyEntry[] memory additions = new GovernanceActionPolicyEntry[](1);
        additions[0] =
            _documentaryPolicy(address(assemblyExternal), assemblyExternal.admitFamily.selector);
        return _appendDocumentaryPolicies(rows, additions);
    }

    /// @dev Parent invokes this after full current stack/Safe/base definitions, before first sale.
    function _deployDocumentaryMedia() internal {
        require(address(documentaryMasters) == address(0), "one documentary master selector");
        _documentaryDocument(
            "STREAM_MEDIA_MASTER_ASSOCIATION_V1",
            IStreamSchemaRegistry.DocumentKind.SCHEMA,
            bytes(vm.readFile("schemas/records/STREAM_MEDIA_MASTER_ASSOCIATION_V1.json"))
        );
        _documentaryDocument(
            "STREAM_MEDIA_MASTER_SELECTED_SLOTS_PROFILE_V1",
            IStreamSchemaRegistry.DocumentKind.CATALOG,
            bytes(vm.readFile("schemas/records/STREAM_MEDIA_MASTER_SELECTED_SLOTS_PROFILE_V1.json"))
        );
        // These declarations describe this fixture's actual PPM bytes. The master consumer does
        // not validate external format declarations, and this fixture does not claim otherwise.
        documentaryObjectSchema = _documentaryDocument(
            "FIXTURE_DOCUMENTARY_PPM_OBJECT_V1",
            IStreamSchemaRegistry.DocumentKind.SCHEMA,
            bytes(
                '{"description":"Complete local P3 PPM image bytes; test format declaration","version":1}'
            )
        );
        bytes memory formats = bytes(
            '{"formats":[{"formatId":"PPM_P3","mimeType":"image/x-portable-pixmap"}],"version":1}'
        );
        documentaryFormatCatalogHash = keccak256(formats);
        documentaryFormatCatalog = _documentaryDocument(
            "FIXTURE_DOCUMENTARY_PPM_FORMATS_V1",
            IStreamSchemaRegistry.DocumentKind.CATALOG,
            formats
        );
        _documentaryAdmitRecordType(MEDIA_RECORD, StreamRecordFamilies.MEDIA, uint16(1 << 7));
        _documentaryGrantWriter(StreamRecordFamilies.MEDIA, address(this));
        documentaryMasters = StreamMediaMasterSelection(
            _artistArtifactCreate(
                "smart-contracts/domains/metadata/StreamMediaMasterSelection.sol:StreamMediaMasterSelection",
                abi.encode(
                    address(core),
                    address(assemblyMetadata),
                    address(assemblySchemas),
                    address(assemblyExternal),
                    address(executor),
                    IStreamGasParameterHost.GasParameterConfig(
                        "MEDIA_MASTER_MANIFEST_READ_GAS", 500_000, 500_000, 2
                    ),
                    IStreamGasParameterHost.GasParameterConfig(
                        "MEDIA_MASTER_COVERAGE_READ_GAS", 800_000, 500_000, 2
                    )
                )
            )
        );
        _assertDeployableProductionInstance(address(documentaryMasters));
        documentaryEndowedFamily = _admitDocumentaryArchiveFamily(true);
        documentaryInstitutionFamily = _admitDocumentaryArchiveFamily(false);
        _setRole(keccak256("ROLE_FIXITY_OPERATOR"), vm.addr(MEDIA_FIXITY_KEY), true);
        // Existing onboarding ratified the original script. Removing it is a new, exact Artist
        // consent and real governed Router write, not a fabricated OFFCHAIN serving response.
        bytes32 state = router.previewArtistScriptState(1, "");
        _consentDocumentaryRouter(SCRIPT_FAMILY, state);
        _governDocumentaryRouter(
            SCRIPT_FAMILY, state, abi.encodeCall(router.setCollectionScript, (1, ""))
        );
    }

    /// @notice Select an occupied image release; optionally complete its actual archived master.
    /// @dev Calling the same variant with true after false fills missing evidence without changing
    /// the selected manifest, content consent, or pending signed commerce transaction.
    function _publishDocumentaryMedia(uint256 variant, bool withMaster) internal {
        require(address(documentaryMasters) != address(0) && variant < 256, "bounded media variant");
        DocumentaryMediaVariant storage saved = documentaryMediaVariants[variant];
        if (!hasDocumentaryVariant || currentDocumentaryVariant != variant) {
            require(saved.manifestHash == 0, "new variant or current exact retry");
            string memory image =
                string.concat("ipfs://local-documentary-display-", variant.toString(), ".ppm");
            bytes32 state = router.previewArtistMediaState(1, image, "");
            _consentDocumentaryRouter(MEDIA_FAMILY, state);
            _governDocumentaryRouter(
                MEDIA_FAMILY,
                state,
                abi.encodeCall(
                    router.setCollectionMetadata,
                    (1, "Documentary image", "Complete local occupied-media fixture", image, "")
                )
            );
            StreamCollectionManifestTypes.MediaManifest memory media;
            media.imageSourceType = StreamCollectionManifestTypes.PayloadSourceType.IPFS;
            media.imageURI = image;
            media.imageHash = keccak256(_documentaryDisplayBytes(variant));
            media.imageMimeType = "image/x-portable-pixmap";
            state = router.previewArtistMediaManifestState(1, media);
            _consentDocumentaryRouter(MEDIA_FAMILY, state);
            _governDocumentaryRouter(
                MEDIA_FAMILY, state, abi.encodeCall(router.setCollectionMediaManifest, (1, media))
            );
            uint8 occupied;
            (documentaryMediaSubject, saved.manifestHash, saved.inventoryHash, occupied) =
                documentaryMasters.collectionMediaContext(1);
            require(
                occupied == 1 && saved.manifestHash != 0 && saved.inventoryHash != 0
                    && saved.inventoryHash
                        == keccak256(
                            abi.encode(keccak256("6529STREAM_MEDIA_MASTER_INVENTORY_V1"), media)
                        ) && saved.manifestHash == assemblyMetadata.mediaManifestHash(1)
                    && keccak256(abi.encode(assemblyMetadata.mediaManifest(1)))
                        == keccak256(abi.encode(media)),
                "actual selected occupied image and canonical full inventory"
            );
            saved.displayHash = media.imageHash;
            currentDocumentaryVariant = variant;
            hasDocumentaryVariant = true;
        }
        documentaryMediaManifestHash = saved.manifestHash;
        documentaryMediaInventoryHash = saved.inventoryHash;
        documentaryMasterRecordHash = saved.associationRecordHash;
        documentaryMasterObjectHash = saved.masterObjectHash;
        documentaryMasterCoverageHash = saved.coverageHash;
        documentaryMediaEvidenceHash = saved.mediaEvidenceHash;
        if (withMaster) _completeDocumentaryMaster();
    }

    /// @notice Supply only the current release's missing archive/master evidence, for exact retry.
    function _completeDocumentaryMaster() internal {
        require(hasDocumentaryVariant, "selected documentary release");
        DocumentaryMediaVariant storage saved = documentaryMediaVariants[currentDocumentaryVariant];
        bytes32 serving = keccak256(
            abi.encode(router.collectionServingFacts(1), router.collectionServingSource(1))
        );
        bytes32 manifest = assemblyMetadata.mediaManifestHash(1);
        if (saved.associationRecordHash == 0) {
            _completeDocumentaryMaster(currentDocumentaryVariant);
        }
        saved.mediaEvidenceHash =
            documentaryMasters.requireCollectionMasters(1, documentaryMediaSubject);
        require(
            saved.mediaEvidenceHash != 0
                && saved.mediaEvidenceHash == _documentaryExpectedMediaEvidence(saved),
            "exact occupied slot, original selection and complete archive evidence"
        );
        require(
            manifest == assemblyMetadata.mediaManifestHash(1) && manifest == saved.manifestHash
                && serving
                    == keccak256(
                        abi.encode(
                            router.collectionServingFacts(1), router.collectionServingSource(1)
                        )
                    ),
            "archive repair preserves exact original serving and manifest"
        );
        documentaryMasterRecordHash = saved.associationRecordHash;
        documentaryMasterObjectHash = saved.masterObjectHash;
        documentaryMasterCoverageHash = saved.coverageHash;
        documentaryMediaEvidenceHash = saved.mediaEvidenceHash;
    }

    function _documentaryExpectedMediaEvidence(DocumentaryMediaVariant storage saved)
        private
        view
        returns (bytes32)
    {
        StreamMediaMasterTypes.Selection memory selected =
            documentaryMasters.currentMaster(1, documentaryMediaSubject, 1);
        StreamExternalArtifactTypes.ObjectIdentity memory object =
            assemblyExternal.objectIdentity(saved.masterObjectHash);
        StreamExternalArtifactTypes.Coverage memory coverage =
            assemblyExternal.coverage(saved.coverageHash);
        bytes32[3] memory slots = [saved.displayHash, bytes32(0), bytes32(0)];
        bytes32 initial = keccak256(
            abi.encode(
                documentaryMasters.profileHash(),
                block.chainid,
                address(documentaryMasters),
                address(core),
                address(assemblyMetadata),
                address(assemblyExternal),
                uint256(1),
                documentaryMediaSubject,
                saved.manifestHash,
                saved.inventoryHash,
                slots,
                selected.association
            )
        );
        return keccak256(
            abi.encode(
                initial, uint8(1), saved.selectionHash, keccak256(abi.encode(object, coverage))
            )
        );
    }

    function _consentDocumentaryRouter(bytes32 family, bytes32 nextState) private {
        StreamArtistContentTypes.Consent memory p =
            StreamArtistContentTypes.Consent(1, address(router), family, nextState);
        T.Authorization memory a = _artistAuthorization(false);
        IStreamArtistContentAuthority authority = IStreamArtistContentAuthority(address(artists));
        a.signature = _artistProof(authority.contentConsentDigest(p, a));
        require(authority.recordContentConsent(p, a) != 0, "original Artist exact content consent");
    }

    function _governDocumentaryRouter(bytes32 family, bytes32 nextState, bytes memory data)
        private
    {
        (bool supported, bytes32 previous) = router.artistContentFamilyState(1, family);
        require(supported, "original Router family");
        _documentaryGovern(
            address(router),
            data,
            keccak256(
                abi.encode(
                    "documentary original Router content",
                    block.chainid,
                    address(router),
                    uint256(1),
                    family
                )
            ),
            previous,
            nextState
        );
    }

    function _admitDocumentaryArchiveFamily(bool endowed) private returns (bytes32 hash) {
        string memory name = endowed ? "documentary-endowed" : "documentary-institution";
        bytes memory side = bytes(endowed ? "endowed" : "institution");
        StreamArchivalTypes.Family memory f = StreamArchivalTypes.Family(
            keccak256(bytes(name)),
            endowed ? assemblyObjectVerifier.networkId() : keccak256("LOCAL_INSTITUTIONAL_ARCHIVE"),
            keccak256(bytes.concat(side, "-protocol")),
            keccak256(bytes.concat(side, "-addressing")),
            keccak256(bytes.concat(side, "-custodian")),
            keccak256(bytes.concat(side, "-funding")),
            keccak256(bytes.concat(side, "-retrieval")),
            keccak256("LOCAL_TEST_JURISDICTION"),
            endowed ? 1 : 2,
            vm.addr(endowed ? MEDIA_ENDOWED_KEY : MEDIA_INSTITUTION_KEY),
            endowed ? assemblyObjectVerifier.profileHash() : assemblyExternal.POSSESSION_PROFILE()
        );
        bytes32 scope;
        bytes32 previous;
        bytes32 next;
        (hash, scope, previous, next) = assemblyExternal.familyRegistrationContext(name, f);
        _documentaryGovern(
            address(assemblyExternal),
            abi.encodeCall(assemblyExternal.admitFamily, (name, f)),
            scope,
            previous,
            next
        );
        (, uint8 status, uint64 revision) = assemblyExternal.family(hash);
        require(status == 1 && revision == 1, "genuine governed independent archive family");
    }

    function _completeDocumentaryMaster(uint256 variant) private {
        DocumentaryMediaVariant storage saved = documentaryMediaVariants[variant];
        bytes memory masterBytes = _documentaryMasterBytes(variant);
        StreamExternalArtifactTypes.ObjectIdentity memory object;
        object.artistId = fixtureArtistId;
        object.schemaId = documentaryObjectSchema;
        object.canonicalizationId = keccak256("RAW_BYTES");
        object.contentHash = keccak256(masterBytes);
        object.sha256Digest = sha256(masterBytes);
        object.byteSize = uint64(masterBytes.length);
        object.arweaveDataRoot = _documentaryNativeLeaf(object.sha256Digest, masterBytes.length);
        object.formatId = keccak256("PPM_P3");
        object.formatCatalogId = documentaryFormatCatalog;
        object.formatCatalogHash = documentaryFormatCatalogHash;
        require(
            object.contentHash != saved.displayHash,
            "full master is distinct from display derivative"
        );
        saved.masterObjectHash = assemblyExternal.recordObject(object);
        bytes32 transactionId;
        (saved.checkpointHash, transactionId) = _documentaryCheckpoint(variant, object);
        saved.firstReceipt = _documentaryArchiveReceipt(
            variant, true, saved.masterObjectHash, saved.checkpointHash, transactionId
        );
        saved.secondReceipt = _documentaryArchiveReceipt(
            variant, false, saved.masterObjectHash, saved.checkpointHash, transactionId
        );
        _documentaryFixity(saved.firstReceipt, object);
        _documentaryFixity(saved.secondReceipt, object);
        saved.coverageHash =
            assemblyExternal.recordCoverage(saved.firstReceipt, saved.secondReceipt);
        require(
            assemblyExternal.requireCoverage(
                saved.coverageHash, fixtureArtistId, saved.masterObjectHash
            )
            .coverageHash == saved.coverageHash,
            "actual exact-object dual archive coverage"
        );

        StreamMediaMasterTypes.Selection memory prior =
            documentaryMasters.currentMaster(1, documentaryMediaSubject, 1);
        StreamMediaMasterTypes.Master memory witness = StreamMediaMasterTypes.Master(
            documentaryMediaSubject,
            saved.manifestHash,
            1,
            saved.displayHash,
            StreamMediaMasterTypes.Role.SOURCE_MASTER,
            saved.masterObjectHash,
            saved.coverageHash,
            prior.original.recordHash
        );
        bytes memory payload = StreamMasterWaiverJson.master(witness);
        IStreamPreservationRecords.CollectionRecord memory record;
        record.recordType = MEDIA_RECORD;
        record.subjectId = documentaryMediaSubject;
        record.contentHash = IStreamPreservationRecords.HashRef(
            1, abi.encodePacked(keccak256(payload)), StreamWorkRecordDefinitions.CANON_ID
        );
        record.uri =
            string.concat("ipfs://local-documentary-master-association-", variant.toString());
        record.schemaId = StreamMediaMasterDefinitions.MASTER_SCHEMA_ID;
        record.effectiveAt = uint64(block.timestamp);
        saved.associationRecordHash =
            assemblyMetadata.recordCollectionRecordWithPayload(1, record, payload);
        StreamMediaMasterTypes.Selection memory selected = documentaryMasters.adoptMaster(
            1, saved.associationRecordHash, prior.revision, record, witness
        );
        require(
            selected.status == StreamMediaMasterTypes.Status.PRESENT
                && selected.original.authorizationClass == 7
                && selected.original.recorder == address(this)
                && selected.original.publicationEvidenceHash == 0
                && selected.association.artistId == fixtureArtistId
                && selected.coverageHash == saved.coverageHash
                && selected.manifestHash == saved.manifestHash
                && selected.displayHash == saved.displayHash,
            "actual class7 association and original archive master selected"
        );
        saved.selectionHash = selected.selectionHash;
    }

    function _documentaryCheckpoint(
        uint256 variant,
        StreamExternalArtifactTypes.ObjectIdentity memory object
    ) private returns (bytes32 hash, bytes32 transactionId) {
        StreamArchivalTypes.Checkpoint memory c;
        c.networkId = assemblyObjectVerifier.networkId();
        c.configurationHash = assemblyObjectVerifier.configurationHash();
        c.blockHash = new bytes(48);
        c.blockHash[0] = 0x65;
        c.blockHash[1] = bytes1(uint8(variant));
        c.blockHeight = uint64(variant + 1);
        transactionId = keccak256(
            abi.encode(
                "LOCAL QUORUM FIXTURE: complete documentary master", variant, object.contentHash
            )
        );
        c.transactionId = transactionId;
        c.dataRoot = object.arweaveDataRoot;
        c.dataSize = object.byteSize;
        c.transactionRoot = _documentaryNativeLeaf(c.dataRoot, c.dataSize);
        c.transactionEnd = c.dataSize;
        c.blockDataSize = c.dataSize;
        c.observedAt = uint64(block.timestamp);
        bytes32 digest = assemblyObjectVerifier.checkpointDigest(c);
        StreamArchivalTypes.ObserverProof[] memory certificate =
            new StreamArchivalTypes.ObserverProof[](2);
        certificate[0] = StreamArchivalTypes.ObserverProof(
            vm.addr(ARCHIVAL_OBSERVER_ONE), _documentaryMediaSign(ARCHIVAL_OBSERVER_ONE, digest)
        );
        certificate[1] = StreamArchivalTypes.ObserverProof(
            vm.addr(ARCHIVAL_OBSERVER_TWO), _documentaryMediaSign(ARCHIVAL_OBSERVER_TWO, digest)
        );
        if (certificate[0].account > certificate[1].account) {
            (certificate[0], certificate[1]) = (certificate[1], certificate[0]);
        }
        bytes memory dataPath = abi.encode(object.sha256Digest, uint256(object.byteSize));
        hash = assemblyObjectVerifier.recordCheckpoint(
            c, abi.encode(c.dataRoot, uint256(c.dataSize)), dataPath, dataPath, certificate
        );
        StreamExternalArtifactTypes.NativeFacts memory facts =
            assemblyObjectVerifier.checkpointFacts(hash);
        require(
            facts.firstChunkDigest == object.sha256Digest
                && facts.lastChunkDigest == object.sha256Digest,
            "complete one-leaf original object"
        );
    }

    function _documentaryArchiveReceipt(
        uint256 variant,
        bool endowed,
        bytes32 objectHash,
        bytes32 checkpointHash,
        bytes32 transactionId
    ) private returns (bytes32) {
        bytes memory locator = endowed
            ? abi.encodePacked(transactionId)
            : bytes(
                string.concat(
                    "https://local-institution.example.invalid/documentary/",
                    variant.toString(),
                    ".ppm"
                )
            );
        uint256 key = endowed ? MEDIA_ENDOWED_KEY : MEDIA_INSTITUTION_KEY;
        StreamExternalArtifactTypes.Receipt memory r = StreamExternalArtifactTypes.Receipt(
            objectHash,
            endowed ? documentaryEndowedFamily : documentaryInstitutionFamily,
            keccak256(locator),
            endowed ? keccak256("CONTENT_ADDRESSED_INCLUSION") : keccak256("ATTESTED_POSSESSION"),
            endowed ? assemblyObjectVerifier.profileHash() : assemblyExternal.POSSESSION_PROFILE(),
            endowed ? checkpointHash : bytes32(0),
            vm.addr(key),
            uint64(block.timestamp),
            variant,
            uint64(block.timestamp + 1 days)
        );
        if (!endowed) r.proofRecordHash = assemblyExternal.possessionHash(r);
        return assemblyExternal.recordReceipt(
            r, locator, _documentaryMediaSign(key, assemblyExternal.receiptDigest(r))
        );
    }

    function _documentaryFixity(
        bytes32 receiptHash,
        StreamExternalArtifactTypes.ObjectIdentity memory object
    ) private {
        (StreamExternalArtifactTypes.Receipt memory original,,) =
            assemblyExternal.receipt(receiptHash);
        StreamExternalArtifactTypes.Fixity memory f;
        f.receiptHash = receiptHash;
        f.objectHash = original.objectHash;
        f.familyRecordHash = original.familyRecordHash;
        f.storageIdentifierHash = original.storageIdentifierHash;
        f.profileHash = assemblyExternal.FIXITY_PROFILE();
        f.expectedSha256 = object.sha256Digest;
        f.observedSha256 = object.sha256Digest;
        f.expectedKeccak256 = object.contentHash;
        f.observedKeccak256 = object.contentHash;
        f.expectedArweaveRoot = object.arweaveDataRoot;
        f.observedArweaveRoot = object.arweaveDataRoot;
        f.expectedSize = object.byteSize;
        f.observedSize = object.byteSize;
        f.checkedAt = uint64(block.timestamp);
        f.outcome = 1;
        f.reportHash = keccak256(abi.encode("complete local PPM full-byte fixity", object));
        f.verifier = vm.addr(MEDIA_FIXITY_KEY);
        f.deadline = uint64(block.timestamp + 1 days);
        assemblyExternal.recordFixity(
            f, _documentaryMediaSign(MEDIA_FIXITY_KEY, assemblyExternal.fixityDigest(f))
        );
    }

    function _documentaryDisplayBytes(uint256 variant) internal pure returns (bytes memory) {
        return bytes(string.concat("P3\n1 1\n255\n", variant.toString(), " 0 0\n"));
    }

    function _documentaryMasterBytes(uint256 variant) internal pure returns (bytes memory) {
        return bytes(
            string.concat(
                "P3\n2 2\n255\n", variant.toString(), " 0 0\n0 255 0\n0 0 255\n255 255 255\n"
            )
        );
    }

    function _documentaryNativeLeaf(bytes32 data, uint256 end) private pure returns (bytes32) {
        return sha256(abi.encodePacked(sha256(abi.encodePacked(data)), sha256(abi.encode(end))));
    }

    function _documentaryMediaSign(uint256 key, bytes32 digest) private returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, digest);
        return abi.encodePacked(r, s, v);
    }
}
