// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../metadata/StreamContentRootComposition.t.sol";
import "../../../smart-contracts/domains/finality/StreamFinalityContentReads.sol";

/// @dev Fixed deployment binding boundary, not the unfinished ten-reference provider.
contract FinalityContentConsumerBoundary {
    StreamFinalityContentReads.Dependencies private d;

    constructor(address[10] memory targets, uint256 cap) {
        d.targets = targets;
        for (uint256 i; i < 10; ++i) {
            d.codeHashes[i] = targets[i].codehash;
        }
        d.chainId = block.chainid;
        d.readGas = cap;
    }

    function requireCurrentCollection(uint256 cid)
        external
        view
        returns (StreamFinalityContentEvidence memory)
    {
        return StreamFinalityContentReads.requireCurrentCollection(d, cid);
    }
}

interface FinalityContentVm {
    function mockCall(address, bytes calldata, bytes calldata) external;
    function clearMockedCalls() external;
    function chainId(uint256) external;
    function etch(address, bytes calldata) external;
}

/// @notice Real root/checkpoint/inventory/leaf/archival/schema composition with explicit
///      Core, Executor, artist, provider and archive-receipt boundaries retained from the fixture.
contract StreamFinalityContentReadsTest is ContentRootCompositionFixture {
    FinalityContentVm private constant cvm =
        FinalityContentVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    FinalityContentConsumerBoundary private consumer;
    bytes32 private rootHash;

    function setUp() public override {
        super.setUp();
        consumer = new FinalityContentConsumerBoundary(_targets(), 5_000_000);
        IStreamContentRootPublication.Publication memory p = _publication();
        p.verifiedManifestRecordHash = verified;
        _approve(p, address(this), keccak256("content-evidence-consent"));
        rootHash = router.publishVerifiedTokenContentRoot(p);
    }

    function _targets() private view returns (address[10] memory) {
        return [
            address(core),
            address(artist),
            address(router),
            address(finality),
            provider,
            address(metadata),
            address(schemas),
            address(verifier),
            address(checkpoint),
            address(artifacts)
        ];
    }

    function testContentEvidenceJoinsActualPublishedRootAndCompletePreservedBytes() public view {
        StreamFinalityContentEvidence memory e = consumer.requireCurrentCollection(1);
        IStreamContentLeafManifest.Manifest memory m =
            verifier.requireCurrentManifest(verified, keccak256("artist"));
        IStreamOnchainContentCheckpoint.Plan memory p =
            checkpoint.requireCurrentCheckpoint(checkpointHash);
        require(
            e.rootRecordHash == rootHash && e.verifiedManifestRecordHash == verified,
            "authoritative records"
        );
        require(
            e.checkpointHash == checkpointHash && e.contentRoot == p.contentRoot
                && e.manifestHash == m.manifestHash && e.leafCount == p.tokenCount,
            "current complete contents"
        );
        require(
            e.leafArtifactHash == m.artifactHash && e.leafCoverageHash == m.coverageHash,
            "leaf-only coverage"
        );
        require(
            e.inventoryHash == p.inventoryHash && e.servingStateHash == p.servingStateHash,
            "actual sources"
        );
        require(
            e.artistId == artist.artistId() && e.bindingGeneration == artist.generation()
                && e.bindingHash == artist.bindingHash(),
            "original accepted binding"
        );
    }

    function testContentEvidenceRemainsCurrentAcrossCoreFreeze() public {
        bytes32 beforeHash = keccak256(abi.encode(consumer.requireCurrentCollection(1)));
        core.setFrozen(true);
        require(
            keccak256(abi.encode(consumer.requireCurrentCollection(1))) == beforeHash,
            "freeze cannot rewrite content"
        );
    }

    function testContentEvidenceRejectsMissingHead() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamFinalityContentReads.ContentEvidenceMissing.selector, uint256(2)
            )
        );
        consumer.requireCurrentCollection(2);
    }

    function testContentEvidenceRejectsChangedArtistBindingAndKeepsHistoricalRecord() public {
        artist.changeGeneration();
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamFinalityContentReads.ContentEvidenceArtistChanged.selector, uint256(1)
            )
        );
        consumer.requireCurrentCollection(1);
        require(
            router.contentRootRecord(rootHash).bindingGeneration == 1,
            "original historical authority"
        );
    }

    function testContentEvidenceRejectsNewUnindexedMint() public {
        core.setMinted(2);
        vm.expectRevert();
        consumer.requireCurrentCollection(1);
        require(router.collectionContentRootHead(1) == rootHash, "history retained");
    }

    function testContentEvidenceRejectsExpiredActualArchiveEpoch() public {
        archive.advanceEpoch();
        vm.expectRevert();
        consumer.requireCurrentCollection(1);
        require(router.contentRootRecord(rootHash).contentRoot != 0, "not an eligibility read");
    }

    function testContentEvidenceRejectsChangedSelectedMetadata() public {
        core.setPointer(keccak256("COLLECTION_METADATA"), address(artist));
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamFinalityContentReads.ContentEvidenceDependency.selector, address(metadata)
            )
        );
        consumer.requireCurrentCollection(1);
    }

    function testContentEvidenceRejectsOriginalRuntimeSubstitution() public {
        cvm.etch(provider, hex"00");
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamFinalityContentReads.ContentEvidenceDependency.selector, provider
            )
        );
        consumer.requireCurrentCollection(1);
    }

    function testContentEvidenceRejectsCrossChainReplay() public {
        cvm.chainId(block.chainid + 1);
        vm.expectRevert(
            abi.encodeWithSelector(StreamFinalityContentReads.ContentEvidenceConfiguration.selector)
        );
        consumer.requireCurrentCollection(1);
    }

    function testContentEvidenceRejectsMalformedAuthoritativeRecord() public {
        IStreamContentRootPublication.Record memory r = router.contentRootRecord(rootHash);
        r.contentRoot = keccak256("substituted root");
        cvm.mockCall(
            address(router),
            abi.encodeCall(IStreamContentRootPublication.contentRootRecord, (rootHash)),
            abi.encode(r)
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamFinalityContentReads.ContentEvidenceMismatch.selector, rootHash
            )
        );
        consumer.requireCurrentCollection(1);
    }

    function testContentEvidenceRejectsGetterDisagreement() public {
        cvm.mockCall(
            address(router),
            abi.encodeWithSelector(IStreamContentRootPublication.tokenContentRoot.selector),
            abi.encode(keccak256("different"), uint64(1), StreamContentRootSchemas.LEAF_SCHEMA)
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamFinalityContentReads.ContentEvidenceMismatch.selector, rootHash
            )
        );
        consumer.requireCurrentCollection(1);
    }

    function testContentEvidenceRejectsSchemaDeprecationWithoutErasingHistory() public {
        IStreamSchemaRegistry.DocumentView memory s =
            schemas.document(StreamContentRootSchemas.LEAF_SCHEMA);
        s.status = IStreamSchemaRegistry.DocumentStatus.DEPRECATED;
        cvm.mockCall(
            address(schemas),
            abi.encodeCall(IStreamSchemaRegistry.document, (StreamContentRootSchemas.LEAF_SCHEMA)),
            abi.encode(s)
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamFinalityContentReads.ContentEvidenceSchema.selector,
                StreamContentRootSchemas.LEAF_SCHEMA
            )
        );
        consumer.requireCurrentCollection(1);
        require(
            router.contentRootRecord(rootHash).manifestHash != 0,
            "historical interpretation remains stored"
        );
    }

    function testContentEvidenceInsufficientNestedCapDoesNotBecomeSuccess() public {
        FinalityContentConsumerBoundary tooSmall =
            new FinalityContentConsumerBoundary(_targets(), 2_000_000);
        vm.expectRevert();
        tooSmall.requireCurrentCollection(1);
        consumer.requireCurrentCollection(1);
    }

    function testContentEvidenceActualThresholdSafeRead() public {
        uint256[] memory keys = new uint256[](2);
        keys[0] = 0xA11CE;
        keys[1] = 0xB0B;
        OfficialSafe safe =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 9927);
        require(
            executeSafe(
                safe,
                keys,
                address(consumer),
                0,
                abi.encodeCall(consumer.requireCurrentCollection, (uint256(1))),
                0
            ),
            "Safe current content read"
        );
    }

    function testFuzzContentEvidenceRejectsChangedImmutableRouteIndex(uint8 slot) public {
        uint256 index = uint256(slot) % 10;
        address[10] memory targets = _targets();
        address target = targets[index];
        cvm.etch(target, hex"00");
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamFinalityContentReads.ContentEvidenceDependency.selector, target
            )
        );
        consumer.requireCurrentCollection(1);
    }
}
