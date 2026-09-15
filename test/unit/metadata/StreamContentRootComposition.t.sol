// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamContentRootPublication.t.sol";
import "../finality/StreamContentLeafManifest.t.sol";

contract RootEntropyBoundary {
    function tokenSeed(uint256) external pure returns (bytes32, bool) {
        return (keccak256("seed"), true);
    }

    function tokenEntropyStatus(uint256) external pure returns (uint8) {
        return 5;
    }
}

/// @notice Actual rendering, token inventory, checkpoint, archival aggregator, retained bytes and publication.
/// @dev Core membership, governance execution, archival receipts, artist approvals and Finality/provider bindings
///      remain explicit boundaries. This is not execution of a real Finality record.
abstract contract ContentRootCompositionFixture is ContentRootPublicationFixture {
    LeafManifestVm private constant mvm =
        LeafManifestVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    StreamCollectionTokenInventory internal inventory;
    StreamOnchainContentCheckpoint internal checkpoint;
    StreamFinalityArtifactCoverage internal artifacts;
    LeafManifestArchiveBoundary internal archive;
    StreamContentLeafManifest internal verifier;
    bytes32 internal checkpointHash;
    bytes32 internal verified;

    function setUp() public virtual override {
        super.setUp();
        _documents(schemas.RAW_BYTES());
        core.setToken(1, address(this), 2);
        core.setEntropy(address(new RootEntropyBoundary()));
        bytes32[] memory locks = new bytes32[](3);
        locks[0] = keccak256("SCRIPT");
        locks[1] = keccak256("MEDIA_MANIFEST");
        locks[2] = keccak256("BASE_URI");
        for (uint256 i; i < 3; ++i) {
            for (uint256 j = i + 1; j < 3; ++j) {
                if (locks[j] < locks[i]) (locks[i], locks[j]) = (locks[j], locks[i]);
            }
        }
        artist.setFreeze(router.artistContentFreezeState(1), locks);
        router.applyArtistContentFreeze(1, keccak256("freeze"));
        router.lockArtistIdentity(1);
        router.lockDisplayMetadata(1);
        inventory = new StreamCollectionTokenInventory(
            address(core), address(0), _gas("TOKEN_INVENTORY_CORE_READ_GAS", 100_000, 1)
        );
        checkpoint = new StreamOnchainContentCheckpoint(
            address(core),
            address(router),
            address(inventory),
            address(0),
            _gas("CONTENT_CHECKPOINT_READ_GAS", 250_000, 1),
            _gas("CONTENT_CHECKPOINT_RENDER_GAS", 2_000_000, 1)
        );
        archive = new LeafManifestArchiveBoundary(address(core), address(executor));
        address predicted =
            mvm.computeCreateAddress(address(this), uint256(mvm.getNonce(address(this))) + 3);
        artifacts = new StreamFinalityArtifactCoverage(
            address(core),
            address(archive),
            address(schemas),
            address(store),
            predicted,
            address(executor),
            IStreamGasParameterHost.GasParameterConfig(
                "FINALITY_ARTIFACT_DEPENDENCY_READ_GAS", 300_000, 300_000, 2
            )
        );
        verifier = new StreamContentLeafManifest(
            address(core),
            address(checkpoint),
            address(artifacts),
            address(0),
            _gas("CONTENT_LEAF_MANIFEST_READ_GAS", 2_000_000, 2)
        );
        provider = address(
            new RootProviderBoundary(address(metadata), address(schemas), address(verifier))
        );
        finality = new RootFinalityBoundary(
            address(core), address(artist), address(metadata), provider, address(artifacts)
        );
        require(address(finality) == predicted, "fixed artifact binding");
        artist.configure(address(router), address(finality));
        core.setPointer(keccak256("ARTWORK_FINALITY_REGISTRY"), address(finality));
        _preserveActualRoot();
    }

    function _gas(string memory name, uint256 value, uint8 failure)
        private
        pure
        returns (IStreamGasParameterHost.GasParameterConfig memory)
    {
        return IStreamGasParameterHost.GasParameterConfig(name, value, 50_000, failure);
    }

    function _preserveActualRoot() private {
        uint256[] memory tokens = new uint256[](1);
        tokens[0] = 1;
        inventory.appendCollectionTokens(1, tokens);
        checkpointHash = checkpoint.beginCollectionCheckpoint(1);
        IStreamOnchainContentCheckpoint.TokenPayload[] memory payloads =
            new IStreamOnchainContentCheckpoint.TokenPayload[](1);
        bytes memory html = abi.encodePacked(
            "<html><head></head><body><script>const tokenId=1;const tokenHash='",
            Strings.toHexString(uint256(keccak256("seed")), 32),
            "';const tokenDataBase64='",
            Base64.encode(hex"00ff"),
            "';draw();</script></body></html>"
        );
        payloads[0] = IStreamOnchainContentCheckpoint.TokenPayload(1, "", html);
        checkpoint.appendCheckpointTokens(checkpointHash, payloads);
        IStreamOnchainContentCheckpoint.Plan memory cp =
            checkpoint.requireCurrentCheckpoint(checkpointHash);
        StreamTokenContentLeaf[] memory leaves = new StreamTokenContentLeaf[](1);
        leaves[0] = checkpoint.checkpointLeaf(checkpointHash, 0);
        bytes memory raw = abi.encode(
            verifier.SCHEMA_ID(),
            block.chainid,
            address(core),
            address(checkpoint),
            checkpointHash,
            uint256(1),
            cp.contentRoot,
            uint64(1),
            leaves
        );
        (bytes32 artifact, bytes32 coverage) = _archiveBytes(raw);
        bytes32 plan =
            verifier.beginManifest(checkpointHash, artifact, coverage, keccak256("artist"));
        verified = verifier.verifyNextLeaves(plan, 1);
    }

    function _archiveBytes(bytes memory raw) private returns (bytes32 artifact, bytes32 coverage) {
        F.Artifact memory a;
        a.artistId = keccak256("artist");
        a.schemaId = verifier.SCHEMA_ID();
        a.canonicalizationId = verifier.CANONICALIZATION_ID();
        a.hashAlgorithm = 1;
        a.contentHash = keccak256(raw);
        a.byteLength = uint64(raw.length);
        a.chunkHashes = new bytes32[](1);
        a.chunkLengths = new uint32[](1);
        address pointer;
        (a.chunkHashes[0], pointer) = store.publishChunk(raw);
        a.chunkLengths[0] = uint32(raw.length);
        archive.add(a.chunkHashes[0], pointer);
        artifact = artifacts.recordArtifact(a);
        bytes32 plan = artifacts.beginCoverage(
            artifact, keccak256("archive family A"), keccak256("archive family B")
        );
        coverage = artifacts.coverNextChunk(plan, 0, a.chunkHashes[0]);
    }
}

contract StreamContentRootCompositionTest is ContentRootCompositionFixture {
    function testActualVerifiedBytesPublishWithoutInvalidatingTheirCheckpoint() public {
        IStreamContentRootPublication.Publication memory p = _publication();
        p.verifiedManifestRecordHash = verified;
        _approve(p, address(this), keccak256("actual-consent"));
        bytes32 hash = router.publishVerifiedTokenContentRoot(p);
        IStreamContentRootPublication.Record memory r = router.contentRootRecord(hash);
        IStreamContentLeafManifest.Manifest memory m =
            verifier.requireCurrentManifest(verified, keccak256("artist"));
        require(
            r.contentRoot == m.contentRoot && r.manifestHash == m.manifestHash && r.leafCount == 1,
            "actual complete manifest"
        );
        require(
            checkpoint.requireCurrentCheckpoint(checkpointHash).contentRoot == r.contentRoot,
            "checkpoint still current"
        );
    }

    function testNestedSameCapFailsWithoutConsumingConsentAndLargerParentSucceeds() public {
        IStreamContentRootPublication.Publication memory p = _publication();
        p.verifiedManifestRecordHash = verified;
        _approve(p, address(this), keccak256("actual-consent"));
        finality.setReadGas(2_000_000);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamContentRootPublication.ContentRootReadFailed.selector,
                address(verifier),
                IStreamContentLeafManifest.requireCurrentManifest.selector
            )
        );
        router.publishVerifiedTokenContentRoot(p);
        require(
            !router.consumedArtistContentConsent(keccak256("actual-consent"))
                && router.collectionContentRootHead(1) == 0,
            "atomic insufficient parent gas"
        );
        finality.setReadGas(5_000_000);
        router.publishVerifiedTokenContentRoot(p);
        require(
            router.consumedArtistContentConsent(keccak256("actual-consent")), "coherent nested caps"
        );
    }

    function testActualArchiveEpochExpiryRejectsNewPublicationButRetainsHistory() public {
        IStreamContentRootPublication.Publication memory p = _publication();
        p.verifiedManifestRecordHash = verified;
        _approve(p, address(this), keccak256("first"));
        bytes32 first = router.publishVerifiedTokenContentRoot(p);
        p.expectedPredecessor = first;
        _approve(p, address(this), keccak256("second"));
        archive.advanceEpoch();
        vm.expectRevert();
        router.publishVerifiedTokenContentRoot(p);
        require(
            router.collectionContentRootHead(1) == first
                && router.contentRootRecord(first).artistConsent == keccak256("first"),
            "history retained"
        );
        require(!router.consumedArtistContentConsent(keccak256("second")), "no stale admission");
    }

    function testActualPreservedRootCanBePublishedByThresholdSafe() public {
        uint256[] memory keys = new uint256[](2);
        keys[0] = 0xA11CE;
        keys[1] = 0xB0B;
        OfficialSafe safe =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 9921);
        _grant(1, 7, address(safe), true);
        IStreamContentRootPublication.Publication memory p = _publication();
        p.verifiedManifestRecordHash = verified;
        _approve(p, address(safe), keccak256("safe-actual-consent"));
        require(
            executeSafe(
                safe,
                keys,
                address(router),
                0,
                abi.encodeCall(router.publishVerifiedTokenContentRoot, (p)),
                0
            ),
            "Safe publication"
        );
        bytes32 hash = router.collectionContentRootHead(1);
        require(router.contentRootRecord(hash).publisher == address(safe), "actual Safe caller");
        require(
            checkpoint.requireCurrentCheckpoint(checkpointHash).nextIndex == 1,
            "serving remains valid"
        );
    }
}
