// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../smart-contracts/domains/metadata/StreamMetadataRouter.sol";
import "../../regression/legacy/helpers/CharacterizationTestBase.sol";
import "../../helpers/OfficialSafeFixture.sol";
import "../../helpers/MetadataRecoveryServingBoundaries.sol";

contract PresentationCoreBoundary {
    mapping(bytes32 => StreamMetadataRecoveryRoutes.Pointer) private recoveryPointers;

    function setRecoveryPointer(bytes32 key, StreamMetadataRecoveryRoutes.Pointer calldata value)
        external
    {
        recoveryPointers[key] = value;
    }
    address public selected;
    address public entropy;
    bool public frozen;
    uint8 public lifecycle = 2;
    uint256 public minted;
    bytes32 public overrideCodeHash;

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == 0x80ac58cd;
    }

    function collectionExists(uint256 id) external pure returns (bool) {
        return id == 1;
    }

    function collectionFreezeStatus(uint256) external view returns (bool) {
        return frozen;
    }

    function collectionMintedEver(uint256) external view returns (uint256) {
        return minted;
    }

    function configure(address a, address e) external {
        selected = a;
        entropy = e;
    }

    function setFrozen(bool value) external {
        frozen = value;
    }

    function setLifecycle(uint8 value) external {
        lifecycle = value;
    }

    function setMinted(uint256 value) external {
        minted = value;
    }

    function setCodeHash(bytes32 value) external {
        overrideCodeHash = value;
    }

    function getSatellitePointer(bytes32 key)
        external
        view
        returns (address, bytes32, bool, bytes32, bytes4, address, uint8, bytes32, bytes32, uint64)
    {
        if (key != keccak256("ARTIST_REGISTRY")) {
            bytes memory raw = abi.encode(recoveryPointers[key]);
            assembly ("memory-safe") { return(add(raw, 32), mload(raw)) }
        }
        return (
            selected,
            overrideCodeHash == 0 ? selected.codehash : overrideCodeHash,
            false,
            0,
            0,
            address(0),
            1,
            0,
            0,
            1
        );
    }

    function tokenCollectionIdentity(uint256 id)
        external
        view
        returns (bool, uint256, uint256, bool)
    {
        return (id == 91, id == 91 ? 1 : 0, id == 91 ? 7 : 0, lifecycle == 3);
    }

    function tokenLifecycle(uint256) external view returns (uint8) {
        return lifecycle;
    }

    function coordinatorAtMint(uint256) external view returns (address) {
        return entropy;
    }

    function tokenData(uint256) external pure returns (bytes memory) {
        return hex"00ff6529";
    }
}

contract PresentationEntropyBoundary {
    bool public finalized = true;

    function setFinalized(bool value) external {
        finalized = value;
    }

    function tokenSeed(uint256) external view returns (bytes32, bool) {
        return (keccak256("seed"), finalized);
    }

    function tokenEntropyStatus(uint256) external view returns (StreamEntropyStatus) {
        return finalized ? StreamEntropyStatus.FINALIZED : StreamEntropyStatus.REQUESTED;
    }
}

contract PresentationArtistBoundary {
    address public immutable finalityRegistry;
    bytes32 public immutable finalityRegistryCodeHash;
    address public immutable core;
    uint8 public state = 2;
    uint8 public status = 1;
    uint8 public fault;
    address public authority = address(0xA11CE);
    bytes32 public consent;

    constructor(address c) {
        core = c;
        finalityRegistry =
            address(new MetadataRecoveryOriginalBoundary(c, address(this), msg.sender));
        finalityRegistryCodeHash = finalityRegistry.codehash;
    }

    function set(uint8 s, uint8 a, address who) external {
        state = s;
        status = a;
        authority = who;
    }

    function setFault(uint8 f) external {
        fault = f;
    }

    function setConsent(bytes32 c) external {
        consent = c;
    }

    function supportsInterface(bytes4 id) external view returns (bool) {
        return id == type(IStreamArtistAttribution).interfaceId
            || id == type(IStreamArtistContentRatification).interfaceId || id == 0x01ffc9a7
            || (id == type(IStreamArtistAttributionState).interfaceId && fault != 1);
    }

    function collectionArtistState(uint256)
        external
        view
        returns (uint8, uint64, bytes32, uint8, bytes32)
    {
        if (fault == 2) assembly ("memory-safe") { return(0, 31) }
        return (state, 4, keccak256("artist"), status, keccak256("binding"));
    }

    function attribution(uint256)
        external
        view
        returns (IStreamCollectionArtistRegistry.Attribution memory a)
    {
        return IStreamCollectionArtistRegistry.Attribution(
            address(0xA11CE),
            authority,
            keccak256("identity"),
            keccak256("binding"),
            fault == 4 ? bytes32(0) : keccak256("acceptance"),
            fault == 3 ? 5 : 4,
            0
        );
    }

    function firstReleaseRatification(uint256) external pure returns (bool, bytes32, bytes32) {
        return (false, 0, 0);
    }

    function contentConsentEvidence(uint256, bytes32, bytes32) external view returns (bytes32) {
        require(consent != 0, "missing consent");
        return consent;
    }
}

/// @notice Real router/linked renderer with explicit Core, artist, and entropy read boundaries.
contract StreamMetadataServingTest is CharacterizationTestBase, OfficialSafeFixture {
    PresentationCoreBoundary private core;
    PresentationArtistBoundary private artist;
    PresentationEntropyBoundary private entropy;
    StreamMetadataRouter private router;

    function setUp() public {
        vm.warp(1000);
        core = new PresentationCoreBoundary();
        artist = new PresentationArtistBoundary(address(core));
        entropy = new PresentationEntropyBoundary();
        core.configure(address(artist), address(entropy));
        router = _router(address(this));
        router.setCollectionMetadata(
            1, "Name", "Description", "ipfs://image", "https://example.test/"
        );
    }

    function _router(address authority) private returns (StreamMetadataRouter) {
        return new StreamMetadataRouter(
            address(core),
            authority,
            keccak256("deployment"),
            "urn:router",
            keccak256("manifest"),
            IStreamArtistAttribution(address(artist))
        );
    }

    function testSavedOriginalAnchorSurvivesFacadeLossAndCurrentPointerReplacement() public {
        router.lockArtistIdentity(1);
        (address original, bytes32 codeHash) = router.originalFinalityAnchor(1);
        require(
            original == artist.finalityRegistry() && codeHash == original.codehash,
            "exact fixed facade binding"
        );
        bytes32 json = keccak256(bytes(router.tokenMetadataJSON(address(core), 91)));
        bytes32 collection = keccak256(bytes(router.contractURIForCollection(address(core), 1)));
        StreamMetadataRecoveryRoutes.Pointer memory pointer;
        pointer.target = original;
        pointer.codeHash = original.codehash;
        pointer.revision = 1;
        core.setRecoveryPointer(keccak256("ARTWORK_FINALITY_REGISTRY"), pointer);
        MetadataRecoveryOriginalBoundary replacement =
            new MetadataRecoveryOriginalBoundary(address(core), address(artist), address(this));
        pointer.target = address(replacement);
        pointer.codeHash = address(replacement).codehash;
        pointer.revision = 2;
        core.setRecoveryPointer(keccak256("ARTWORK_FINALITY_REGISTRY"), pointer);
        vm.etch(address(artist), hex"00");
        core.setLifecycle(3);
        require(
            keccak256(bytes(router.historicalTokenMetadataJSON(address(core), 91))) == json,
            "saved burned rendering"
        );
        require(
            keccak256(bytes(router.contractURIForCollection(address(core), 1))) == collection,
            "saved collection rendering"
        );
        (address afterAddress, bytes32 afterCode) = router.originalFinalityAnchor(1);
        require(afterAddress == original && afterCode == codeHash, "snapshot never rebinds");
    }

    function testLockedMissingOrPartialAnchorCannotConcealFinalizedHistory() public {
        router.lockArtistIdentity(1);
        (address original, bytes32 codeHash) = router.originalFinalityAnchor(1);
        MetadataRecoveryOriginalBoundary(original).setCount(1);
        // Slot 12 is the single appended mapping, independently checked against compiler layout.
        bytes32 first = keccak256(abi.encode(uint256(1), uint256(12)));
        bytes32 second = bytes32(uint256(first) + 1);
        require(
            vm.load(address(router), first) == bytes32(uint256(uint160(original)))
                && vm.load(address(router), second) == codeHash,
            "exact corruption target"
        );
        for (uint256 i; i < 3; ++i) {
            vm.store(
                address(router), first, i == 1 ? bytes32(uint256(uint160(original))) : bytes32(0)
            );
            vm.store(address(router), second, i == 0 ? codeHash : bytes32(0));
            vm.expectRevert();
            router.tokenMetadataJSON(address(core), 91);
            vm.expectRevert();
            router.contractURIForCollection(address(core), 1);
        }
        vm.store(address(router), first, bytes32(uint256(uint160(original))));
        vm.store(address(router), second, codeHash);
        // Complete saved history still requires its companion; restoring bytes is no bypass.
        vm.expectRevert();
        router.tokenMetadataJSON(address(core), 91);
        MetadataRecoveryOriginalBoundary(original).setCount(0);
        require(
            bytes(router.tokenMetadataJSON(address(core), 91)).length != 0, "exact healthy restore"
        );
    }

    function testUnlockedUnexpectedAnchorAndLostFacadeRejectWithoutLocalFallback() public {
        address original = artist.finalityRegistry();
        bytes32 first = keccak256(abi.encode(uint256(1), uint256(12)));
        vm.store(address(router), first, bytes32(uint256(uint160(original))));
        vm.expectRevert();
        router.tokenMetadataJSON(address(core), 91);
        vm.expectRevert();
        router.lockArtistIdentity(1);
        require(!router.artistPresentation(1).locked, "unexpected anchor cannot be adopted");
        vm.store(address(router), first, bytes32(0));
        MetadataRecoveryOriginalBoundary(original).setCount(1);
        bytes memory facadeCode = address(artist).code;
        vm.etch(address(artist), hex"00");
        vm.expectRevert();
        router.tokenMetadataJSON(address(core), 91);
        vm.etch(address(artist), facadeCode);
        vm.expectRevert();
        router.tokenMetadataJSON(address(core), 91);
        MetadataRecoveryOriginalBoundary(original).setCount(0);
        require(
            bytes(router.tokenMetadataJSON(address(core), 91)).length != 0,
            "live fixed facade healthy restore"
        );
    }

    function testLockOriginalCoreAndRuntimeValidationRollsBackBeforeSnapshotEvents() public {
        address original = artist.finalityRegistry();
        bytes memory code = original.code;
        vm.etch(original, hex"00");
        vm.recordLogs();
        vm.expectRevert();
        router.lockArtistIdentity(1);
        require(
            vm.getRecordedLogs().length == 0 && !router.artistPresentation(1).locked,
            "runtime failure before logs/storage"
        );
        (address a, bytes32 h) = router.originalFinalityAnchor(1);
        require(a == address(0) && h == 0, "no partial anchor");
        vm.etch(original, code);
        bytes32 oldCore = vm.load(original, bytes32(0));
        require(oldCore == bytes32(uint256(uint160(address(core)))), "actual fixture Core root");
        vm.store(original, bytes32(0), bytes32(uint256(uint160(address(artist)))));
        vm.recordLogs();
        vm.expectRevert();
        router.lockArtistIdentity(1);
        require(
            vm.getRecordedLogs().length == 0 && !router.artistPresentation(1).locked,
            "reciprocal failure rollback"
        );
        vm.store(original, bytes32(0), oldCore);
        require(router.lockArtistIdentity(1) != 0, "same authorized lock restores");
    }

    function testSavedOriginalRuntimeLossIsUnreadableRatherThanUnfinalized() public {
        router.lockArtistIdentity(1);
        (address original,) = router.originalFinalityAnchor(1);
        bytes32 json = keccak256(bytes(router.tokenMetadataJSON(address(core), 91)));
        bytes memory code = original.code;
        vm.etch(original, hex"00");
        vm.expectRevert();
        router.tokenMetadataJSON(address(core), 91);
        vm.expectRevert();
        router.contractURIForCollection(address(core), 1);
        vm.etch(original, code);
        require(
            keccak256(bytes(router.tokenMetadataJSON(address(core), 91))) == json,
            "original code exact restore"
        );
    }

    function testExactIdentitySnapshotHashAndOperatorEventsRemainStableAcrossLiveStateChanges()
        public
    {
        bytes32 beforeJSON = keccak256(bytes(router.tokenMetadataJSON(address(core), 91)));
        vm.recordLogs();
        bytes32 hash = router.lockArtistIdentity(1);
        IStreamMetadataServingFacts.ArtistPresentation memory p = router.artistPresentation(1);
        require(
            hash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ROUTER_ARTIST_PRESENTATION_V1"),
                        block.chainid,
                        address(core),
                        address(router),
                        uint256(1),
                        address(artist),
                        address(artist).codehash,
                        keccak256("artist"),
                        uint64(4),
                        keccak256("binding"),
                        address(0xA11CE),
                        keccak256("identity"),
                        keccak256("acceptance"),
                        uint64(0),
                        uint64(1000)
                    )
                ),
            "independent named snapshot preimage"
        );
        require(
            p.locked && p.snapshotHash == hash && p.nominatedArtist == address(0xA11CE),
            "exact saved binding"
        );
        Vm.Log[] memory logs = vm.getRecordedLogs();
        require(logs.length == 2, "exact lock events");
        require(
            logs[0].emitter == address(router) && logs[0].topics.length == 3
                && logs[0].topics[0]
                    == keccak256(
                        "CollectionMetadataLocked(uint256,bytes32,address,uint8,bytes32,uint16)"
                    ) && logs[0].topics[1] == bytes32(uint256(1))
                && logs[0].topics[2] == keccak256("ARTIST_IDENTITY")
                && keccak256(logs[0].data)
                    == keccak256(abi.encode(address(this), uint8(0), bytes32(0), uint16(1))),
            "operator lock event"
        );
        require(
            logs[1].topics.length == 3 && logs[1].topics[1] == bytes32(uint256(1))
                && logs[1].topics[2] == hash
                && keccak256(logs[1].data) == keccak256(abi.encode(p, uint16(1))),
            "exact full snapshot event"
        );
        for (uint8 state = 2; state <= 5; ++state) {
            artist.set(state, 4, address(0xB0B));
            require(
                keccak256(bytes(router.tokenMetadataJSON(address(core), 91))) == beforeJSON,
                "stable historical presentation"
            );
            IStreamMetadataServingFacts.LiveArtistStatus memory live =
                router.collectionLiveArtistStatus(1);
            require(
                live.attributionState == state && live.authorityStatus == 4
                    && live.currentAuthority == address(0xB0B),
                "truthful separate live state"
            );
        }
        require(
            keccak256(abi.encode(router.artistPresentation(1))) == keccak256(abi.encode(p)),
            "never rewrite snapshot"
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamMetadataRouter.PresentationAlreadyLocked.selector,
                1,
                keccak256("ARTIST_IDENTITY")
            )
        );
        router.lockArtistIdentity(1);
    }

    function testUnacceptedDisputedRevokedAndMismatchedEvidenceRejectThenIdenticalLockWorks()
        public
    {
        uint8[4] memory states = [uint8(0), 1, 4, 5];
        for (uint256 i; i < states.length; ++i) {
            artist.set(states[i], 1, address(0xA11CE));
            vm.expectRevert(
                abi.encodeWithSelector(
                    StreamMetadataArtistPresentation.InvalidPresentationAssociation.selector, 1
                )
            );
            router.lockArtistIdentity(1);
            require(!router.artistPresentation(1).locked, "failed lock unchanged");
        }
        artist.set(3, 3, address(0xB0B));
        for (uint8 fault = 1; fault <= 4; ++fault) {
            artist.setFault(fault);
            vm.expectRevert();
            router.lockArtistIdentity(1);
            require(!router.artistPresentation(1).locked, "failed facts unchanged");
        }
        artist.setFault(0);
        require(
            router.lockArtistIdentity(1) != 0,
            "sanctioned actual association with successor allowed"
        );
    }

    function testSelectedFacadeCodeAndAuthorityAreRequiredButLocksRemainAvailableAfterCoreFreeze()
        public
    {
        vm.prank(address(0xBAD));
        vm.expectRevert(
            abi.encodeWithSelector(StreamMetadataRouter.Unauthorized.selector, address(0xBAD))
        );
        router.lockArtistIdentity(1);
        core.setCodeHash(keccak256("wrong code"));
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamMetadataArtistPresentation.InvalidPresentationRegistry.selector,
                address(artist)
            )
        );
        router.lockArtistIdentity(1);
        core.setCodeHash(0);
        core.setFrozen(true);
        require(
            !router.collectionServingFacts(1).artistIdentityLocked
                && !router.collectionServingFacts(1).displayMetadataLocked,
            "freeze implies no locks"
        );
        router.lockArtistIdentity(1);
        router.lockDisplayMetadata(1);
        require(
            router.collectionServingFacts(1).artistIdentityLocked
                && router.collectionServingFacts(1).displayMetadataLocked,
            "explicit locks after freeze"
        );
    }

    function testDisplayLockPreservesIndependentMediaConsentAndExactSourceBytes() public {
        router.lockDisplayMetadata(1);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamMetadataRouter.ArtistContentLocked.selector, 1, keccak256("DISPLAY_METADATA")
            )
        );
        router.setCollectionMetadata(
            1, "changed", "Description", "ipfs://image", "https://example.test/"
        );
        core.setMinted(1);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamMetadataRouter.ArtistContentAuthorizationRequired.selector, 1
            )
        );
        router.setCollectionMetadata(
            1, "Name", "Description", "ipfs://changed", "https://example.test/"
        );
        artist.setConsent(keccak256("approved media"));
        router.setCollectionMetadata(
            1, "Name", "Description", "ipfs://changed", "https://example.test/"
        );
        IStreamMetadataServingFacts.ServingSource memory s = router.collectionServingSource(1);
        require(
            keccak256(abi.encode(s.name, s.description, s.imageURI, s.animationBaseURI, s.script))
                == keccak256(
                    abi.encode("Name", "Description", "ipfs://changed", "https://example.test/", "")
                ),
            "original exact fields"
        );
        IStreamMetadataServingFacts.ServingFacts memory f = router.collectionServingFacts(1);
        require(
            f.displayMetadataLocked && !f.mediaLocked && f.mode == keccak256("OFFCHAIN")
                && f.scriptBytes == 0,
            "separate actual locks and mode"
        );
    }

    function testActualScriptModeSourceRendererAndHistoricalBurnedRenderParity() public {
        string memory script = "document.body.textContent='</script>';";
        router.setCollectionScript(1, script);
        router.lockArtistIdentity(1);
        router.lockDisplayMetadata(1);
        IStreamMetadataServingFacts.ServingFacts memory f = router.collectionServingFacts(1);
        require(
            f.configured && f.mode == keccak256("ONCHAIN")
                && f.scriptHash == keccak256(bytes(script)) && f.scriptBytes == bytes(script).length
                && f.renderer == address(StreamMetadataTokenRenderer)
                && f.rendererCodeHash == address(StreamMetadataTokenRenderer).codehash
                && f.dependenciesLocked && !f.scriptLocked
                && f.imageURIHash == keccak256("ipfs://image")
                && f.animationBaseURIHash == keccak256("https://example.test/"),
            "actual serving descriptor"
        );
        require(
            keccak256(bytes(router.collectionServingSource(1).script)) == keccak256(bytes(script)),
            "raw script preserved before escaping"
        );
        bytes32 rendered = keccak256(bytes(router.tokenMetadataJSON(address(core), 91)));
        require(
            keccak256(bytes(router.historicalTokenMetadataJSON(address(core), 91))) == rendered,
            "same live public JSON"
        );
        core.setLifecycle(3);
        vm.etch(address(artist), hex"00");
        require(
            keccak256(bytes(router.historicalTokenMetadataJSON(address(core), 91))) == rendered,
            "burned historical JSON without artist provider"
        );
        vm.expectRevert(abi.encodeWithSelector(StreamMetadataRouter.InvalidToken.selector, 91));
        router.tokenURI(address(core), 91);
        vm.expectRevert();
        router.collectionLiveArtistStatus(1);
    }

    function testPreparedUnknownAndPendingEntropyCannotProduceFinalHistoricalRender() public {
        vm.expectRevert(abi.encodeWithSelector(StreamMetadataRouter.InvalidToken.selector, 90));
        router.historicalTokenMetadataJSON(address(core), 90);
        core.setLifecycle(1);
        vm.expectRevert(abi.encodeWithSelector(StreamMetadataRouter.InvalidToken.selector, 91));
        router.historicalTokenMetadataJSON(address(core), 91);
        core.setLifecycle(2);
        entropy.setFinalized(false);
        vm.expectRevert(
            abi.encodeWithSelector(StreamMetadataRouter.TokenEntropyNotFinalized.selector, 91)
        );
        router.historicalTokenMetadataJSON(address(core), 91);
        require(
            bytes(router.tokenMetadataJSON(address(core), 91)).length != 0,
            "ordinary pending serving remains"
        );
        entropy.setFinalized(true);
        require(
            bytes(router.historicalTokenMetadataJSON(address(core), 91)).length != 0,
            "identical healthy token"
        );
    }

    function testPublicJSONAndDataURIUseIndependentExactGoldenBytes() public {
        router.lockArtistIdentity(1);
        string memory expected =
            '{"name":"Name #7","description":"Description","image":"ipfs://image","metadata_schema_version":"6529stream-v1","metadata_state":"final","token_id":91,"collection_id":1,"collection_serial":7,"hash":"0x66a80b61b29ec044d14c4c8c613e762ba1fb8eeb0c454d1ee00ed6dedaa5b5c5","token_data_base64":"AP9lKQ==","attributes":[],"artist":"0x00000000000000000000000000000000000a11ce","artist_identity_hash":"0x5e0eb9eddf3ac94ebc81731c09097e44d4202ba2ceec0a6936e8e88b2786aaa3","artist_acceptance_hash":"0x75d3033f7e9d1f0bd9d5c105f5569ce13edb3f1789a0856f8bbe82961ea1aac9","animation_url":"https://example.test/91"}';
        require(
            keccak256(bytes(router.tokenMetadataJSON(address(core), 91)))
                == keccak256(bytes(expected)),
            "literal served JSON golden"
        );
        require(
            keccak256(bytes(router.tokenURI(address(core), 91)))
                == keccak256(
                    bytes(
                        "data:application/json;base64,eyJuYW1lIjoiTmFtZSAjNyIsImRlc2NyaXB0aW9uIjoiRGVzY3JpcHRpb24iLCJpbWFnZSI6ImlwZnM6Ly9pbWFnZSIsIm1ldGFkYXRhX3NjaGVtYV92ZXJzaW9uIjoiNjUyOXN0cmVhbS12MSIsIm1ldGFkYXRhX3N0YXRlIjoiZmluYWwiLCJ0b2tlbl9pZCI6OTEsImNvbGxlY3Rpb25faWQiOjEsImNvbGxlY3Rpb25fc2VyaWFsIjo3LCJoYXNoIjoiMHg2NmE4MGI2MWIyOWVjMDQ0ZDE0YzRjOGM2MTNlNzYyYmExZmI4ZWViMGM0NTRkMWVlMDBlZDZkZWRhYTViNWM1IiwidG9rZW5fZGF0YV9iYXNlNjQiOiJBUDlsS1E9PSIsImF0dHJpYnV0ZXMiOltdLCJhcnRpc3QiOiIweDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwYTExY2UiLCJhcnRpc3RfaWRlbnRpdHlfaGFzaCI6IjB4NWUwZWI5ZWRkZjNhYzk0ZWJjODE3MzFjMDkwOTdlNDRkNDIwMmJhMmNlZWMwYTY5MzZlOGU4OGIyNzg2YWFhMyIsImFydGlzdF9hY2NlcHRhbmNlX2hhc2giOiIweDc1ZDMwMzNmN2U5ZDFmMGJkOWQ1YzEwNWY1NTY5Y2UxM2VkYjNmMTc4OWEwODU2ZjhiYmU4Mjk2MWVhMWFhYzkiLCJhbmltYXRpb25fdXJsIjoiaHR0cHM6Ly9leGFtcGxlLnRlc3QvOTEifQ=="
                    )
                ),
            "independent base64 data URI golden"
        );
    }

    function testOnchainPublicJSONMatchesIndependentEscapedHTMLGolden() public {
        router.setCollectionScript(1, "document.body.textContent='</script>';");
        router.lockArtistIdentity(1);
        require(
            keccak256(bytes(router.tokenMetadataJSON(address(core), 91)))
                == keccak256(
                    bytes(
                        '{"name":"Name #7","description":"Description","image":"ipfs://image","metadata_schema_version":"6529stream-v1","metadata_state":"final","token_id":91,"collection_id":1,"collection_serial":7,"hash":"0x66a80b61b29ec044d14c4c8c613e762ba1fb8eeb0c454d1ee00ed6dedaa5b5c5","token_data_location":"animation_url:tokenDataBase64","attributes":[],"artist":"0x00000000000000000000000000000000000a11ce","artist_identity_hash":"0x5e0eb9eddf3ac94ebc81731c09097e44d4202ba2ceec0a6936e8e88b2786aaa3","artist_acceptance_hash":"0x75d3033f7e9d1f0bd9d5c105f5569ce13edb3f1789a0856f8bbe82961ea1aac9","animation_url":"data:text/html;base64,PGh0bWw+PGhlYWQ+PC9oZWFkPjxib2R5PjxzY3JpcHQ+Y29uc3QgdG9rZW5JZD05MTtjb25zdCB0b2tlbkhhc2g9JzB4NjZhODBiNjFiMjllYzA0NGQxNGM0YzhjNjEzZTc2MmJhMWZiOGVlYjBjNDU0ZDFlZTAwZWQ2ZGVkYWE1YjVjNSc7Y29uc3QgdG9rZW5EYXRhQmFzZTY0PSdBUDlsS1E9PSc7ZG9jdW1lbnQuYm9keS50ZXh0Q29udGVudD0nPFwvc2NyaXB0Pic7PC9zY3JpcHQ+PC9ib2R5PjwvaHRtbD4="}'
                    )
                ),
            "independent exact HTML/base64/JSON golden"
        );
    }

    function testPureSerializerPreservesFullWidthUint256WithoutJCSCoercion() public {
        StreamMetadataRenderTypes.Token memory token = StreamMetadataRenderTypes.Token(
            type(uint256).max,
            type(uint256).max,
            type(uint256).max,
            bytes32(type(uint256).max),
            false,
            "pending",
            hex"00ff",
            true
        );
        IStreamMetadataServingFacts.ServingSource memory source =
            IStreamMetadataServingFacts.ServingSource("Wide", "D", "", "", "");
        string memory actual = StreamMetadataTokenRenderer.render(token, source, "");
        require(
            keccak256(bytes(actual))
                == keccak256(
                    bytes(
                        '{"name":"Wide #115792089237316195423570985008687907853269984665640564039457584007913129639935","description":"D","image":"","metadata_schema_version":"6529stream-v1","metadata_state":"pending","token_id":115792089237316195423570985008687907853269984665640564039457584007913129639935,"collection_id":115792089237316195423570985008687907853269984665640564039457584007913129639935,"collection_serial":115792089237316195423570985008687907853269984665640564039457584007913129639935,"hash":"0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff","token_data_base64":"AP8=","attributes":[]}'
                    )
                ),
            "all three uint256 values exact decimal golden"
        );
    }

    function testActualSafeLocksAndServingReadsOwnerCannotBypassSafe() public {
        uint256[] memory keys = new uint256[](2);
        keys[0] = 0x571;
        keys[1] = 0x572;
        OfficialSafe safe =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 717);
        StreamMetadataRouter target = _router(address(safe));
        require(
            executeSafe(
                safe,
                keys,
                address(target),
                0,
                abi.encodeCall(target.setCollectionMetadata, (1, "N", "D", "ipfs://image", "")),
                0
            ),
            "Safe configure"
        );
        address owner = vm.addr(keys[0]);
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(StreamMetadataRouter.Unauthorized.selector, owner));
        target.lockArtistIdentity(1);
        require(
            executeSafe(
                safe, keys, address(target), 0, abi.encodeCall(target.lockArtistIdentity, (1)), 0
            ),
            "Safe identity lock"
        );
        require(
            executeSafe(
                safe, keys, address(target), 0, abi.encodeCall(target.lockDisplayMetadata, (1)), 0
            ),
            "Safe display lock"
        );
        bytes[] memory calls = new bytes[](9);
        calls[0] = abi.encodeCall(target.artistPresentation, (1));
        calls[1] = abi.encodeCall(target.collectionServingFacts, (1));
        calls[2] = abi.encodeCall(target.collectionServingSource, (1));
        calls[3] = abi.encodeCall(target.collectionLiveArtistStatus, (1));
        calls[4] = abi.encodeCall(target.historicalTokenMetadataJSON, (address(core), 91));
        calls[5] = abi.encodeCall(target.tokenURI, (address(core), 91));
        calls[6] = abi.encodeCall(target.LOCK_ARTIST_IDENTITY, ());
        calls[7] = abi.encodeCall(target.LOCK_DISPLAY_METADATA, ());
        calls[8] = abi.encodeCall(target.PRESENTATION_PROFILE, ());
        for (uint256 i; i < calls.length; ++i) {
            vm.prank(address(safe));
            (bool ok, bytes memory result) = address(target).staticcall(calls[i]);
            require(ok && result.length != 0, "Safe-address exact read result");
            require(
                executeSafe(safe, keys, address(target), 0, calls[i], 0),
                "actual threshold Safe reads"
            );
        }
        require(
            target.supportsInterface(type(IStreamMetadataServingFacts).interfaceId),
            "typed capability"
        );
    }
}
