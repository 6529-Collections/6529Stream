// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamCollectionMetadataV1.t.sol";
import "../../../smart-contracts/interfaces/stream/core/IStreamCoreConservationTier.sol";
import "../../../smart-contracts/interfaces/stream/metadata/IStreamConservationTier.sol";

/// @dev Typed Core boundary only. Actual Core storage, callbacks and governance have separate tests.
/// Completed mint count is independent of allocation and live/burned token state in this fixture.
contract ConservationTierCoreBoundary is MetadataCoreBoundary, IStreamCoreConservationTier {
    mapping(uint256 => uint256) public collectionMintedEver;
    mapping(uint256 => bytes32) public override declaredConservationTier;
    uint256 public writes;
    bool public rejectAfterWrite;

    error CoreRejected();

    function setCompletedCount(uint256 collectionId, uint256 count) external {
        require(count >= collectionMintedEver[collectionId], "completed count never decreases");
        collectionMintedEver[collectionId] = count;
    }

    function setRejectAfterWrite(bool reject) external {
        rejectAfterWrite = reject;
    }

    function recordConservationTier(uint256 collectionId, bytes32 tier) external override {
        if (msg.sender != selected[keccak256("COLLECTION_METADATA")]) {
            revert ConservationTierAuthorityRequired();
        }
        require(collectionId == 1 || collectionId == 2, "unknown collection");
        if (
            tier != keccak256("MUSEUM_GRADE") && tier != keccak256("MUSEUM_GRADE_LITE")
                && tier != keccak256("CONSERVATION_WAIVED")
        ) revert InvalidConservationTier(tier);
        if (declaredConservationTier[collectionId] != 0) {
            revert ConservationTierAlreadyDeclared(collectionId);
        }
        if (collectionMintedEver[collectionId] != 0) {
            revert ConservationTierAfterFirstMint(collectionId);
        }
        declaredConservationTier[collectionId] = tier;
        ++writes;
        // A genuine external-call revert after provisional state tests complete rollback.
        if (rejectAfterWrite) revert CoreRejected();
    }
}

/// @notice Real Metadata facade, governed grants, Schema/Store and upstream Safe execution.
/// @dev Core, Artist and Executor are explicit typed boundaries, not current-stack acceptance.
contract StreamConservationTierTest is CharacterizationTestBase, OfficialSafeFixture {
    bytes32 private constant FAMILY = keccak256("6529STREAM_RECORD_FAMILY_CONSERVATION_V1");
    bytes32 private constant FULL = keccak256("MUSEUM_GRADE");
    bytes32 private constant LITE = keccak256("MUSEUM_GRADE_LITE");
    bytes32 private constant WAIVED = keccak256("CONSERVATION_WAIVED");
    bytes32 private constant EVENT =
        keccak256("CollectionConservationTierDeclared(uint256,bytes32,uint16)");

    ConservationTierCoreBoundary private core;
    MetadataExecutorBoundary private executor;
    MetadataArtistBoundary private artist;
    StreamSchemaRegistry private schemas;
    StreamSchemaDocumentStore private store;
    StreamCollectionMetadataV1 private metadata;

    function setUp() public {
        vm.warp(1000);
        core = new ConservationTierCoreBoundary();
        executor = new MetadataExecutorBoundary();
        artist = new MetadataArtistBoundary(address(core));
        schemas = new StreamSchemaRegistry(address(executor));
        store = StreamSchemaDocumentStore(schemas.chunkStore());
        metadata = _deployMetadata();
        core.setPointer(keccak256("COLLECTION_METADATA"), address(metadata));
        core.setPointer(keccak256("ARTIST_REGISTRY"), address(artist));
    }

    function testDedicatedInterfaceAndActualSchemaStore() public view {
        require(
            metadata.supportsInterface(type(IStreamConservationTier).interfaceId), "tier ABI"
        );
        require(
            metadata.chunkStore() == address(store) && address(store).code.length != 0, "Store"
        );
        _assertTier(metadata, 1, 0, 0);
    }

    function testCollectionClass7DeclaresFullWithExactOriginalEvent() public {
        _grant(metadata, 1, FAMILY, 7, address(this), true);
        _declareAndCheck(metadata, 1, FULL);
    }

    function testCollectionClass7DeclaresLiteBeforeMint() public {
        _grant(metadata, 1, FAMILY, 7, address(this), true);
        _declareAndCheck(metadata, 1, LITE);
        require(core.collectionMintedEver(1) == 0, "explicit lite is not a default");
    }

    function testGlobalClass8DeclaresWaiverAcrossCollections() public {
        _grant(metadata, 0, FAMILY, 8, address(this), true);
        _declareAndCheck(metadata, 1, WAIVED);
        _declareAndCheck(metadata, 2, FULL);
    }

    function testRightsArtistOwnerAndUnrelatedScopeDoNotAuthorize() public {
        _grant(metadata, 0, StreamRecordFamilies.RIGHTS, 8, address(this), true);
        _grant(metadata, 1, StreamRecordFamilies.RIGHTS, 7, address(this), true);
        artist.setSigner(address(this));
        core.setToken(91, address(this), 2);
        _rejectAuthority(address(this), 1);

        _grant(metadata, 2, FAMILY, 7, address(this), true);
        _rejectAuthority(address(this), 1);
        _assertTier(metadata, 1, 0, 0);
        require(core.writes() == 0, "no Core write");
    }

    function testGlobalClass7AndCollectionClass8DoNotAuthorize() public {
        _grant(metadata, 0, FAMILY, 7, address(this), true);
        _grant(metadata, 1, FAMILY, 8, address(this), true);
        _rejectAuthority(address(this), 1);
        _assertTier(metadata, 1, 0, 0);
    }

    function testGrantDoesNotAuthorizeAnotherCallerAndRevocationApplies() public {
        _grant(metadata, 1, FAMILY, 7, address(this), true);
        _rejectAuthority(address(0xb0b), 1);
        _grant(metadata, 1, FAMILY, 7, address(this), false);
        _rejectAuthority(address(this), 1);
        _grant(metadata, 1, FAMILY, 7, address(this), true);
        _declareAndCheck(metadata, 1, FULL);
    }

    function testUnknownAndZeroTierRejectBeforeCoreWrite() public {
        _grant(metadata, 1, FAMILY, 7, address(this), true);
        _rejectUnknown(0);
        _rejectUnknown(keccak256("museum_grade"));
        _rejectUnknown(keccak256("MUSEUM_GRADE "));
        require(core.writes() == 0, "unknown never forwarded");
        _declareAndCheck(metadata, 1, FULL);
    }

    function testSecondDeclarationRejectsSameAndDifferentTier() public {
        _grant(metadata, 1, FAMILY, 7, address(this), true);
        metadata.declareConservationTier(1, FULL);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamCoreConservationTier.ConservationTierAlreadyDeclared.selector, uint256(1)
            )
        );
        metadata.declareConservationTier(1, FULL);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamCoreConservationTier.ConservationTierAlreadyDeclared.selector, uint256(1)
            )
        );
        metadata.declareConservationTier(1, WAIVED);
        _assertTier(metadata, 1, FULL, FULL);
        require(core.writes() == 1, "one original write");
    }

    function testCompletedFirstMintBlocksDeclaration() public {
        _grant(metadata, 1, FAMILY, 7, address(this), true);
        core.setCompletedCount(1, 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamCoreConservationTier.ConservationTierAfterFirstMint.selector, uint256(1)
            )
        );
        metadata.declareConservationTier(1, WAIVED);
        _assertTier(metadata, 1, 0, LITE);
        require(core.writes() == 0, "default has no declaration write");
    }

    function testAllocationDoesNotDefaultOrPreventDeclaration() public {
        core.setToken(1, address(0), 1);
        (bool allocated,,,) = core.tokenCollectionIdentity(1);
        require(allocated && core.tokenLifecycle(1) == 1, "allocation boundary");
        _assertTier(metadata, 1, 0, 0);
        _grant(metadata, 1, FAMILY, 7, address(this), true);
        _declareAndCheck(metadata, 1, WAIVED);
    }

    function testBurnPreservesDefaultAndCannotReopenDeclaration() public {
        core.setToken(1, address(this), 2);
        core.setCompletedCount(1, 1);
        _assertTier(metadata, 1, 0, LITE);
        core.setToken(1, address(0), 3);
        require(
            core.tokenLifecycle(1) == 3 && core.collectionMintedEver(1) == 1, "retained mint"
        );
        _assertTier(metadata, 1, 0, LITE);
        _grant(metadata, 1, FAMILY, 7, address(this), true);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamCoreConservationTier.ConservationTierAfterFirstMint.selector, uint256(1)
            )
        );
        metadata.declareConservationTier(1, FULL);
    }

    function testExplicitWaiverSurvivesCompletedMintAndBurn() public {
        _grant(metadata, 1, FAMILY, 7, address(this), true);
        metadata.declareConservationTier(1, WAIVED);
        core.setToken(1, address(this), 2);
        core.setCompletedCount(1, 1);
        _assertTier(metadata, 1, WAIVED, WAIVED);
        core.setToken(1, address(0), 3);
        _assertTier(metadata, 1, WAIVED, WAIVED);
        require(core.writes() == 1, "completed mint and burn preserve the original declaration");
    }

    function testFacadeReplacementRetainsDeclarationAndRejectsOldWriter() public {
        _grant(metadata, 1, FAMILY, 7, address(this), true);
        _grant(metadata, 2, FAMILY, 7, address(this), true);
        metadata.declareConservationTier(1, WAIVED);
        StreamCollectionMetadataV1 replacement = _deployMetadata();
        core.setPointer(keccak256("COLLECTION_METADATA"), address(replacement));
        _assertTier(replacement, 1, WAIVED, WAIVED);
        // Retired facade reads still resolve the same original Core-owned declaration.
        _assertTier(metadata, 1, WAIVED, WAIVED);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamCoreConservationTier.ConservationTierAuthorityRequired.selector
            )
        );
        metadata.declareConservationTier(2, FULL);
        _assertTier(replacement, 2, 0, 0);
        _grant(replacement, 1, FAMILY, 7, address(this), true);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamCoreConservationTier.ConservationTierAlreadyDeclared.selector, uint256(1)
            )
        );
        replacement.declareConservationTier(1, FULL);
        _grant(replacement, 2, FAMILY, 7, address(this), true);
        _declareAndCheck(replacement, 2, LITE);
    }

    function testFacadeReplacementRetainsCompletedMintDefault() public {
        core.setCompletedCount(1, 8);
        StreamCollectionMetadataV1 replacement = _deployMetadata();
        core.setPointer(keccak256("COLLECTION_METADATA"), address(replacement));
        _assertTier(replacement, 1, 0, LITE);
        _grant(replacement, 1, FAMILY, 7, address(this), true);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamCoreConservationTier.ConservationTierAfterFirstMint.selector, uint256(1)
            )
        );
        replacement.declareConservationTier(1, WAIVED);
    }

    function testCoreRejectionRollsBackProvisionalWriteAndAllowsRetry() public {
        _grant(metadata, 1, FAMILY, 7, address(this), true);
        core.setRejectAfterWrite(true);
        vm.expectRevert(
            abi.encodeWithSelector(ConservationTierCoreBoundary.CoreRejected.selector)
        );
        metadata.declareConservationTier(1, FULL);
        _assertTier(metadata, 1, 0, 0);
        require(core.writes() == 0, "provisional Core effects rolled back");
        (bool enabled, uint64 revision) = metadata.familyWriter(1, FAMILY, 7, address(this));
        require(enabled && revision == 1, "grant retained exactly");
        core.setRejectAfterWrite(false);
        _declareAndCheck(metadata, 1, FULL);
        require(core.writes() == 1, "retry creates one declaration");
    }

    function testUnknownCollectionReadAndWriteReject() public {
        _grant(metadata, 0, FAMILY, 8, address(this), true);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamCollectionMetadataV1.InvalidMetadataRecord.selector)
        );
        metadata.declareConservationTier(0, FULL);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamCollectionMetadataV1.InvalidMetadataRecord.selector)
        );
        metadata.declareConservationTier(3, FULL);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamCollectionMetadataV1.InvalidMetadataRecord.selector)
        );
        metadata.conservationTier(3);
    }

    function testOfficialSafeCollectionAndGlobalAuthority() public {
        (OfficialSafe account, uint256[] memory keys) = _safe();
        _grant(metadata, 1, FAMILY, 7, address(account), true);
        vm.recordLogs();
        this.safeDeclare(account, keys, 1, FULL);
        _assertEvent(vm.getRecordedLogs(), address(metadata), 1, FULL);
        _assertTier(metadata, 1, FULL, FULL);
        _grant(metadata, 0, FAMILY, 8, address(account), true);
        vm.recordLogs();
        this.safeDeclare(account, keys, 2, WAIVED);
        _assertEvent(vm.getRecordedLogs(), address(metadata), 2, WAIVED);
        _assertTier(metadata, 2, WAIVED, WAIVED);
        require(account.nonce() == 2, "two threshold CALLs");
    }

    function testOfficialSafeRightsOnlyRejectsAndNonceRollsBack() public {
        (OfficialSafe account, uint256[] memory keys) = _safe();
        _grant(metadata, 0, StreamRecordFamilies.RIGHTS, 8, address(account), true);
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.safeDeclare(account, keys, 1, FULL);
        require(
            account.nonce() == 0 && core.writes() == 0, "failed Safe transaction rolled back"
        );
        _assertTier(metadata, 1, 0, 0);
        _grant(metadata, 1, FAMILY, 7, address(account), true);
        this.safeDeclare(account, keys, 1, FULL);
        require(account.nonce() == 1, "same Safe can retry after actual grant");
    }

    /// forge-config: default.fuzz.runs = 256
    function testFuzzUnknownTierNeverWrites(bytes32 tier) public {
        if (tier == FULL || tier == LITE || tier == WAIVED) return;
        _grant(metadata, 1, FAMILY, 7, address(this), true);
        _rejectUnknown(tier);
        _assertTier(metadata, 1, 0, 0);
        require(core.writes() == 0, "unknown tier cannot create a default or declaration");
    }

    /// forge-config: default.fuzz.runs = 256
    function testFuzzDefaultDependsOnlyOnCompletedCount(uint256 completed, uint8 lifecycle)
        public
    {
        core.setCompletedCount(1, completed);
        core.setToken(1, address(this), uint8(lifecycle % 4));
        _assertTier(metadata, 1, 0, completed == 0 ? bytes32(0) : LITE);
        require(
            core.declaredConservationTier(1) == 0 && core.writes() == 0, "read never declares"
        );
    }

    function safeDeclare(
        OfficialSafe account,
        uint256[] calldata keys,
        uint256 cid,
        bytes32 tier
    ) external {
        require(
            executeSafe(
                account,
                keys,
                address(metadata),
                0,
                abi.encodeCall(metadata.declareConservationTier, (cid, tier)),
                0
            ),
            "Safe CALL"
        );
    }

    function _safe() private returns (OfficialSafe account, uint256[] memory keys) {
        uint256[] memory owners = new uint256[](3);
        owners[0] = 831;
        owners[1] = 832;
        owners[2] = 833;
        account =
            createOfficialSafe(
            deploySafeComponents("1.4.1"), safeOwnerAddresses(owners), 2, 829
        );
        keys = new uint256[](2);
        keys[0] = owners[0];
        keys[1] = owners[1];
    }

    function _deployMetadata() private returns (StreamCollectionMetadataV1) {
        StreamCollectionMetadataV1.Configuration memory c;
        c.core = address(core);
        c.executor = address(executor);
        c.schemas = address(schemas);
        c.artistRegistry = address(artist);
        c.deploymentManifestHash = bytes32(uint256(1));
        c.manifestHash = bytes32(uint256(2));
        c.manifestURI = "ipfs://conservation-tier-metadata";
        c.dependencyReadGas = IStreamGasParameterHost.GasParameterConfig(
            "METADATA_DEPENDENCY_READ_GAS", 150000, 100000, 2
        );
        c.artistReadGas = IStreamGasParameterHost.GasParameterConfig(
            "METADATA_ARTIST_READ_GAS", 2000000, 1000000, 2
        );
        return new StreamCollectionMetadataV1(c);
    }

    function _grant(
        StreamCollectionMetadataV1 host,
        uint256 cid,
        bytes32 family,
        uint8 authority,
        address account,
        bool enabled
    ) private {
        (bytes32 scope, bytes32 before_, bytes32 after_) =
            host.familyWriterTransition(cid, family, authority, account, enabled);
        executor.execute(
            address(host),
            abi.encodeCall(host.setFamilyWriter, (cid, family, authority, account, enabled)),
            scope,
            before_,
            after_
        );
    }

    function _rejectAuthority(address caller, uint256 cid) private {
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamCollectionMetadataV1.MetadataAuthorityRequired.selector
            )
        );
        vm.prank(caller);
        metadata.declareConservationTier(cid, FULL);
    }

    function _rejectUnknown(bytes32 tier) private {
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamCoreConservationTier.InvalidConservationTier.selector, tier
            )
        );
        metadata.declareConservationTier(1, tier);
    }

    function _declareAndCheck(StreamCollectionMetadataV1 host, uint256 cid, bytes32 tier)
        private
    {
        vm.recordLogs();
        host.declareConservationTier(cid, tier);
        _assertEvent(vm.getRecordedLogs(), address(host), cid, tier);
        _assertTier(host, cid, tier, tier);
        require(core.declaredConservationTier(cid) == tier, "original Core storage");
    }

    function _assertTier(
        StreamCollectionMetadataV1 host,
        uint256 cid,
        bytes32 declared,
        bytes32 effective
    ) private view {
        (bytes32 actualDeclared, bytes32 actualEffective) = host.conservationTier(cid);
        require(actualDeclared == declared && actualEffective == effective, "exact tier read");
    }

    function _assertEvent(Vm.Log[] memory logs, address emitter, uint256 cid, bytes32 tier)
        private
        pure
    {
        uint256 matches;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].topics.length == 0 || logs[i].topics[0] != EVENT) continue;
            require(
                logs[i].emitter == emitter && logs[i].topics.length == 3,
                "original facade emitter"
            );
            require(
                logs[i].topics[1] == bytes32(cid) && logs[i].topics[2] == tier,
                "indexed tier identity"
            );
            require(
                keccak256(logs[i].data) == keccak256(abi.encode(uint16(1))),
                "schema1 exact bytes"
            );
            ++matches;
        }
        require(matches == 1, "one original declaration event");
    }
}
