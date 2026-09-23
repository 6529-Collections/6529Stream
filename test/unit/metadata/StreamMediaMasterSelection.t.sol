// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamConservationSelectionFixture.sol";
import "../../../smart-contracts/domains/metadata/StreamMediaMasterSelection.sol";

/// @dev Typed archive boundary only. Native checkpoint/signature/fixity tests live in preservation/.
contract MediaMasterArchiveBoundary {
    address public core;
    address public governanceAuthority;
    StreamExternalArtifactTypes.ObjectIdentity private object;
    StreamExternalArtifactTypes.Coverage private proof;
    bool private unavailable;

    constructor(address c, address executor) { core = c; governanceAuthority = executor; }
    function supportsInterface(bytes4) external pure returns (bool) { return true; }
    function set(StreamExternalArtifactTypes.ObjectIdentity memory o,
        StreamExternalArtifactTypes.Coverage memory p) external { object = o; proof = p; }
    function fail(bool value) external { unavailable = value; }
    function objectIdentity(bytes32) external view returns (StreamExternalArtifactTypes.ObjectIdentity memory) { return object; }
    function requireCoverage(bytes32 hash, bytes32 artistId, bytes32 objectHash)
        external view returns (StreamExternalArtifactTypes.Coverage memory)
    {
        require(!unavailable && hash == proof.coverageHash && artistId == proof.artistId
            && objectHash == proof.objectHash, "typed archive coverage unavailable");
        return proof;
    }
}

/// @dev Actual Metadata/Schema/Store/selector; typed selected manifests, Artist and archive boundaries.
contract StreamMediaMasterSelectionTest is ConservationSelectionFixture {
    StreamMediaMasterSelection private masters;
    MediaMasterArchiveBoundary private archive;
    bytes32 private constant MANIFEST = keccak256("selected kind3 manifest");
    bytes32 private constant DISPLAY = keccak256("display bytes");
    bytes32 private constant MASTER_OBJECT = keccak256("native master identity");
    bytes32 private constant COVERAGE = keccak256("native recorded coverage");
    bytes32 private constant MEDIA = keccak256("MEDIA_RELATIONSHIP");

    modifier masterReady() { _prepare(); _bound(); _prepareMasters(); _; }

    function _prepareMasters() private {
        _registerDocument("STREAM_MASTER_WAIVER_V1", IStreamSchemaRegistry.DocumentKind.SCHEMA,
            bytes(vm.readFile("schemas/records/STREAM_MASTER_WAIVER_V1.json")), schemas.RAW_BYTES());
        _registerDocument("STREAM_MEDIA_MASTER_ASSOCIATION_V1", IStreamSchemaRegistry.DocumentKind.SCHEMA,
            bytes(vm.readFile("schemas/records/STREAM_MEDIA_MASTER_ASSOCIATION_V1.json")), schemas.RAW_BYTES());
        _registerDocument("STREAM_MEDIA_MASTER_SELECTED_SLOTS_PROFILE_V1", IStreamSchemaRegistry.DocumentKind.CATALOG,
            bytes(vm.readFile("schemas/records/STREAM_MEDIA_MASTER_SELECTED_SLOTS_PROFILE_V1.json")), schemas.RAW_BYTES());
        _admit(MEDIA, StreamRecordFamilies.MEDIA, uint16((1 << 6) | (1 << 7)));
        _grant(1, StreamRecordFamilies.MEDIA, 7, address(this), true);
        archive = new MediaMasterArchiveBoundary(address(core), address(executor));
        masters = new StreamMediaMasterSelection(address(core), address(metadata), address(schemas),
            address(archive), address(executor), IStreamGasParameterHost.GasParameterConfig(
                "MEDIA_MASTER_MANIFEST_READ_GAS", 1000000, 500000, 2), IStreamGasParameterHost.GasParameterConfig(
                "MEDIA_MASTER_COVERAGE_READ_GAS", 1000000, 500000, 2));
        _media(MANIFEST, DISPLAY, false, false);
        _coverage(keccak256("distinct full master bytes"));
    }

    function _media(bytes32 manifest, bytes32 display, bool alternates, bool second) private {
        StreamCollectionManifestTypes.MediaManifest memory m;
        m.imageSourceType = StreamCollectionManifestTypes.PayloadSourceType.ARWEAVE;
        m.imageURI = "ar://display";
        m.imageHash = display;
        m.imageMimeType = "image/tiff";
        if (alternates) { m.alternatesURI = "ipfs://opaque"; m.alternatesHash = keccak256("opaque"); }
        if (second) {
            m.contentSourceType = StreamCollectionManifestTypes.PayloadSourceType.ARWEAVE;
            m.contentURI = "ar://second";
            m.contentHash = keccak256("second display");
            m.contentMimeType = "video/mp4";
        }
        cvm.mockCall(address(metadata), abi.encodeCall(IStreamCollectionManifestReads.mediaManifestHash,
            (uint256(1))), abi.encode(manifest));
        cvm.mockCall(address(metadata), abi.encodeCall(IStreamCollectionManifestReads.mediaManifest,
            (uint256(1))), abi.encode(m));
        // This fixture isolates the producer's denominator checks; it does not claim real Router selection.
        core.setPointer(keccak256("METADATA_ROUTER"), address(archive));
        IStreamMetadataServingFacts.ServingSource memory source;
        source.imageURI = "ar://display";
        cvm.mockCall(address(archive), abi.encodeCall(IStreamMetadataServingFacts.collectionServingSource,
            (uint256(1))), abi.encode(source));
    }

    function _coverage(bytes32 masterHash) private {
        StreamExternalArtifactTypes.ObjectIdentity memory o;
        o.artistId = ARTIST_ID; o.contentHash = masterHash;
        o.sha256Digest = keccak256("sha256 observation");
        o.arweaveDataRoot = keccak256("native arweave data root"); o.byteSize = 30000000;
        StreamExternalArtifactTypes.Coverage memory c;
        c.coverageHash = COVERAGE; c.objectHash = MASTER_OBJECT; c.artistId = o.artistId;
        c.contentHash = o.contentHash; c.sha256Digest = o.sha256Digest;
        c.arweaveDataRoot = o.arweaveDataRoot; c.byteSize = o.byteSize;
        c.profileHash = keccak256("STREAM_EXTERNAL_ARTIFACT_COVERAGE_V1");
        archive.set(o, c);
    }

    function _master() private view returns (StreamMediaMasterTypes.Master memory w) {
        w.subjectId = subject; w.selectedMediaManifestHash = MANIFEST; w.mediaSlot = 1;
        w.displayHash = DISPLAY; w.masterObjectHash = MASTER_OBJECT; w.coverageHash = COVERAGE;
    }

    function _publishMaster(StreamMediaMasterTypes.Master memory w) private returns (bytes32 h) {
        bytes memory payload = StreamMasterWaiverJson.master(w);
        IStreamPreservationRecords.CollectionRecord memory r = _record(MEDIA, payload);
        r.schemaId = StreamMediaMasterDefinitions.MASTER_SCHEMA_ID;
        r.contentHash.canonicalizationId = StreamWorkRecordDefinitions.CANON_ID;
        h = metadata.recordCollectionRecordWithPayload(1, r, payload);
        originals[h] = r;
    }

    function testActualOriginalMasterReceiptAndFreshCoverage() public masterReady {
        StreamMediaMasterTypes.Master memory w = _master();
        bytes32 h = _publishMaster(w);
        vm.prank(RELAYER);
        StreamMediaMasterTypes.Selection memory s = masters.adoptMaster(1, h, 0, originals[h], w);
        (, IStreamCollectionMetadataV1.RecordReceipt memory r) = metadata.collectionRecord(h);
        require(s.original.receiptHash == keccak256(abi.encode(r)) && s.original.authorizationClass == 7
            && s.original.recorder == address(this) && s.original.publicationEvidenceHash == 0,
            "actual media authority; no invented artist signature");
        require(s.status == StreamMediaMasterTypes.Status.PRESENT && s.revision == 1,
            "original master association selected");
        require(masters.requireCollectionMasters(1, subject) != 0, "bounded complete current floor");
    }

    function testDisplayDerivativeNeverFillsMasterAndRollback() public masterReady {
        StreamMediaMasterTypes.Master memory w = _master(); bytes32 h = _publishMaster(w);
        _coverage(DISPLAY);
        vm.expectRevert(abi.encodeWithSelector(StreamMediaMasterTypes.MasterCoverageUnavailable.selector));
        masters.adoptMaster(1, h, 0, originals[h], w);
        require(masters.currentMaster(1, subject, 1).revision == 0, "failed proof did not select");
        _coverage(keccak256("different bytes"));
        masters.adoptMaster(1, h, 0, originals[h], w);
        require(masters.currentMaster(1, subject, 1).revision == 1, "same original can retry");
    }

    function testManifestAndEveryOccupiedSlotRechecked() public masterReady {
        StreamMediaMasterTypes.Master memory w = _master(); bytes32 h = _publishMaster(w);
        masters.adoptMaster(1, h, 0, originals[h], w);
        _media(keccak256("new manifest"), DISPLAY, false, false);
        vm.expectRevert(abi.encodeWithSelector(StreamMediaMasterTypes.MasterSelectionConflict.selector));
        masters.requireCollectionMasters(1, subject);
        _media(MANIFEST, DISPLAY, false, true);
        vm.expectRevert(abi.encodeWithSelector(StreamMediaMasterTypes.MasterSelectionConflict.selector));
        masters.requireCollectionMasters(1, subject);
    }

    function testOpaqueAlternatesAndMissingDigestRemainUnavailable() public masterReady {
        _media(MANIFEST, DISPLAY, true, false);
        vm.expectRevert(abi.encodeWithSelector(StreamMediaMasterTypes.UnsupportedMediaDenominator.selector));
        masters.requireCollectionMasters(1, subject);
        _media(MANIFEST, 0, false, false);
        vm.expectRevert(abi.encodeWithSelector(StreamMediaMasterTypes.UnsupportedMediaDenominator.selector));
        masters.requireCollectionMasters(1, subject);
    }

    function testContextBeforeMasterAndGenuinelyEmptyDenominator() public masterReady {
        (bytes32 actualSubject, bytes32 manifest, bytes32 inventory, uint8 mask) = masters.collectionMediaContext(1);
        require(actualSubject == subject && manifest == MANIFEST && inventory != 0 && mask == 1,
            "denominator independent of unfinished master selection");
        StreamCollectionManifestTypes.MediaManifest memory empty;
        IStreamMetadataServingFacts.ServingSource memory source;
        cvm.mockCall(address(metadata), abi.encodeCall(IStreamCollectionManifestReads.mediaManifest,
            (uint256(1))), abi.encode(empty));
        cvm.mockCall(address(archive), abi.encodeCall(IStreamMetadataServingFacts.collectionServingSource,
            (uint256(1))), abi.encode(source));
        (,,bytes32 emptyHash, uint8 emptyMask) = masters.collectionMediaContext(1);
        require(emptyMask == 0 && emptyHash != 0 && emptyHash != inventory, "canonical empty is explicit");
        require(masters.requireCollectionMasters(1, subject) != 0, "no nonexistent occupied slot");
        cvm.mockCall(address(metadata), abi.encodeCall(IStreamCollectionManifestReads.mediaManifestHash,
            (uint256(1))), abi.encode(bytes32(0)));
        vm.expectRevert(abi.encodeWithSelector(StreamMediaMasterTypes.UnsupportedMediaDenominator.selector));
        masters.collectionMediaContext(1);
    }

    function testTokenAnimationRecipeCannotDisappearIntoEmptySlot() public masterReady {
        IStreamMetadataServingFacts.ServingSource memory source;
        source.imageURI = "ar://display"; source.animationBaseURI = "https://render.example/token/";
        cvm.mockCall(address(archive), abi.encodeCall(IStreamMetadataServingFacts.collectionServingSource,
            (uint256(1))), abi.encode(source));
        vm.expectRevert(abi.encodeWithSelector(StreamMediaMasterTypes.UnsupportedMediaDenominator.selector));
        masters.collectionMediaContext(1);
    }

    function testLaterArchiveFailureBlocksPreviouslySelectedMaster() public masterReady {
        StreamMediaMasterTypes.Master memory w = _master(); bytes32 h = _publishMaster(w);
        masters.adoptMaster(1, h, 0, originals[h], w);
        archive.fail(true);
        vm.expectRevert(abi.encodeWithSelector(StreamMediaMasterTypes.MasterCoverageUnavailable.selector));
        masters.requireCollectionMasters(1, subject);
        require(masters.currentMaster(1, subject, 1).original.recordHash == h, "original retained");
    }

    function testExactLineageRetainsPriorAndRejectsReplay() public masterReady {
        StreamMediaMasterTypes.Master memory w = _master(); bytes32 first = _publishMaster(w);
        masters.adoptMaster(1, first, 0, originals[first], w);
        vm.expectRevert(abi.encodeWithSelector(StreamMediaMasterTypes.MasterSelectionConflict.selector));
        masters.adoptMaster(1, first, 1, originals[first], w);
        w.predecessor = first;
        bytes32 second = _publishMaster(w);
        masters.adoptMaster(1, second, 1, originals[second], w);
        require(masters.masterSelectionAt(1, subject, 1, 1).original.recordHash == first
            && masters.currentMaster(1, subject, 1).original.recordHash == second, "retained exact lineage");
    }

    function testFuzzWaiverObjectScopeBindsManifestAndDisplay(bytes32 manifest, bytes32 display)
        public masterReady
    {
        if (manifest == 0 || display == 0 || manifest == MANIFEST || display == DISPLAY) return;
        bytes32 original = masters.mediaObjectId(1, subject, MANIFEST, 1, DISPLAY);
        require(original != masters.mediaObjectId(1, subject, manifest, 1, DISPLAY), "manifest scope");
        require(original != masters.mediaObjectId(1, subject, MANIFEST, 1, display), "payload scope");
        require(original != masters.mediaObjectId(1, subject, MANIFEST, 2, DISPLAY), "slot scope");
    }

    function _masterWaiver() private view returns (StreamMediaMasterTypes.Waiver memory w) {
        w.subjectId = subject; w.scopeSubjectId = subject;
        w.artist = StreamMediaMasterTypes.Artist(ARTIST_ID, 1, BINDING);
        w.reason = "No separate master exists; original artist expressly waives this slot.";
        w.waiverStatement = _ref("ipfs://original-master-waiver");
        w.mediaObjects = new StreamMediaMasterTypes.WaivedObject[](1);
        w.mediaObjects[0].objectId = masters.mediaObjectId(1, subject, MANIFEST, 1, DISPLAY);
        w.mediaObjects[0].mediaClass = StreamMediaMasterTypes.MediaClass.STILL_IMAGE;
        w.mediaObjects[0].masterRoles = new StreamMediaMasterTypes.Role[](1);
    }

    function _publishMasterWaiver(StreamMediaMasterTypes.Waiver memory w, uint8 authority)
        private returns (bytes32 h)
    {
        bytes memory payload = StreamMasterWaiverJson.waiver(w);
        IStreamPreservationRecords.CollectionRecord memory r = _record(INTERVIEW, payload);
        r.schemaId = StreamMediaMasterDefinitions.WAIVER_SCHEMA_ID;
        r.contentHash.canonicalizationId = StreamWorkRecordDefinitions.CANON_ID;
        address signer = authority == 1 ? ORIGINAL : ESTATE;
        facade.setSigner(signer);
        P.Publication memory p = _publication(signer, r);
        bytes32 authorization = keccak256(abi.encode("typed executed original waiver op24", p));
        attributionOwner.savePublication(IStreamArtistRecordPublicationOwner.Record(p,
            P.Evidence(authorization, ARTIST_ID, BINDING, 1, signer, authority, 1,
                uint64(block.timestamp), keccak256(abi.encode(p))), address(metadata).codehash));
        h = metadata.recordArtistCollectionRecordWithPayload(signer, 1, r, payload, authorization);
        originals[h] = r;
    }

    /// @dev Requires the reviewed additive exact MASTER_WAIVER Metadata publication admission join.
    function testOriginalArtistWaiverScopeAndNoArchiveSubstitution() public masterReady {
        StreamMediaMasterTypes.Waiver memory w = _masterWaiver();
        bytes32 h = _publishMasterWaiver(w, 1);
        archive.fail(true); // A genuine waiver skips only this preservation-master slot.
        vm.prank(RELAYER);
        StreamMediaMasterTypes.Selection memory s = masters.adoptWaiver(1, 1, MANIFEST, h, 0, originals[h], w);
        require(s.original.publication.authorityClass == 1 && s.original.publication.requiredCapability == 1
            && s.original.recorder == ORIGINAL && s.coverageHash == 0
            && s.status == StreamMediaMasterTypes.Status.WAIVED, "original waiver, no fabricated coverage");
        require(masters.requireCollectionMasters(1, subject) != 0, "authenticated exact waiver floor");
        _media(keccak256("changed manifest"), DISPLAY, false, false);
        vm.expectRevert(abi.encodeWithSelector(StreamMediaMasterTypes.MasterSelectionConflict.selector));
        masters.requireCollectionMasters(1, subject);
        vm.expectRevert(abi.encodeWithSelector(StreamMediaMasterTypes.InvalidMasterWitness.selector));
        masters.adoptWaiver(1, 1, keccak256("changed manifest"), h, 1, originals[h], w);
    }

    function testEstatePublicationCannotBecomeArtistMasterWaiver() public masterReady {
        StreamMediaMasterTypes.Waiver memory w = _masterWaiver();
        bytes32 h = _publishMasterWaiver(w, 3);
        vm.expectRevert(abi.encodeWithSelector(IStreamConservationRecordSelection.InvalidConservationRecord.selector, h));
        masters.adoptWaiver(1, 1, MANIFEST, h, 0, originals[h], w);
        require(masters.currentMaster(1, subject, 1).revision == 0, "no authority substitution");
    }

    function testPlatformCannotWaiveOrUseArtistBoundArchiveProof() public masterReady {
        T.Binding memory empty;
        bindingOwner.setBinding(empty, 0); attributionOwner.setBinding(empty, 0);
        StreamMediaMasterTypes.Master memory w = _master(); bytes32 h = _publishMaster(w);
        vm.expectRevert(abi.encodeWithSelector(StreamMediaMasterTypes.PlatformMasterUnavailable.selector));
        masters.adoptMaster(1, h, 0, originals[h], w);
        StreamMediaMasterTypes.Waiver memory waiver = _masterWaiver();
        vm.expectRevert(abi.encodeWithSelector(StreamMediaMasterTypes.PlatformMasterUnavailable.selector));
        masters.adoptWaiver(1, 1, MANIFEST, bytes32(uint256(123)), 0, originals[h], waiver);
    }

    function testRealSafeMediaRecordSelectionFailureRollsBackAndRetries() public masterReady {
        uint256[] memory keys = new uint256[](2); keys[0] = 331; keys[1] = 442;
        OfficialSafe account = createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 9);
        _grant(1, StreamRecordFamilies.MEDIA, 6, address(account), true);
        StreamMediaMasterTypes.Master memory w = _master();
        bytes memory payload = StreamMasterWaiverJson.master(w);
        IStreamPreservationRecords.CollectionRecord memory r = _record(MEDIA, payload);
        r.schemaId = StreamMediaMasterDefinitions.MASTER_SCHEMA_ID;
        r.contentHash.canonicalizationId = StreamWorkRecordDefinitions.CANON_ID;
        bytes32 h = metadata.deriveCollectionRecordHashFor(address(account), 1, r);
        require(executeSafe(account, keys, address(metadata), 0,
            abi.encodeCall(metadata.recordCollectionRecordWithPayload, (uint256(1), r, payload)), 0), "Safe original publication");
        uint256 nonce = account.nonce();
        bytes memory selection =
            abi.encodeCall(masters.adoptMaster, (uint256(1), h, uint64(0), r, w));
        bytes memory signatures = safeThresholdSignature(keys, account.getTransactionHash(
            address(masters), 0, selection, 0, 0, 0, 0, address(0), address(0), nonce
        ));
        archive.fail(true);
        // Sign before the expectation: executeSafe reads nonce/hash before its execution call.
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        account.execTransaction(
            address(masters), 0, selection, 0, 0, 0, 0, address(0), payable(address(0)), signatures
        );
        require(account.nonce() == nonce && masters.currentMaster(1, subject, 1).revision == 0,
            "Safe transaction nonce and selection rolled back");
        archive.fail(false);
        require(account.execTransaction(
            address(masters), 0, selection, 0, 0, 0, 0, address(0), payable(address(0)), signatures
        ), "Safe exact retry");
        require(masters.currentMaster(1, subject, 1).original.recorder == address(account)
            && masters.currentMaster(1, subject, 1).original.authorizationClass == 6,
            "original Safe archivist authority retained");
    }
}
