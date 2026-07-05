// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../smart-contracts/IStreamArtworkFinalityRegistry.sol";
import "../smart-contracts/StreamArtworkFinalityTypes.sol";
import "./helpers/Assertions.sol";
import "./helpers/FinalityMocks.sol";
import "./helpers/FinalityTestBase.sol";

/// @notice Mandatory-component-floor and snapshot-manifest-gate coverage
///         ([LTA-FINALITY] requirement 1/6, MRR-FINALITY rules 6-9, [CMC-FINALITY-INPUTS]
///         rules 3 and 5). These gates are enforced onchain independent of the optional
///         discovery module, which is address(0) at genesis.
contract StreamArtworkFinalityComponentFloorTest is FinalityTestBase {
    using Assertions for bool;
    using Assertions for bytes32;
    using Assertions for uint256;
    using Assertions for address;

    /// @dev Removes the single entry of `componentType` from a fixture's sorted component list,
    ///      leaving every other mandatory type in place so the floor check reverts on exactly
    ///      the removed type.
    function _withoutComponent(Fixture memory fixture, bytes32 componentType)
        private
        pure
        returns (StreamFinalityComponentExpectation[] memory out)
    {
        out = new StreamFinalityComponentExpectation[](fixture.components.length - 1);
        uint256 cursor = 0;
        for (uint256 i = 0; i < fixture.components.length; i++) {
            if (fixture.components[i].componentType != componentType) {
                out[cursor] = fixture.components[i];
                cursor++;
            }
        }
    }

    function _expectMissing(Fixture memory fixture, bytes32 componentType) private {
        StreamFinalityComponentExpectation[] memory without =
            _withoutComponent(fixture, componentType);
        vm.prank(finalityAdmin);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamArtworkFinalityRegistry.FinalityMissingRequiredComponent.selector,
                componentType
            )
        );
        registry.finalizeCollectionArtwork(
            COLLECTION_ID, without, fixture.expectedFinalityRecordHash, fixture.manifest
        );
    }

    // ------------------------------------------------------------------
    // FIX 1: base-floor mandatory set (every metadata mode)
    // ------------------------------------------------------------------

    function testBaseFloorEachMandatoryTypeOmittedReverts() public {
        Fixture memory fixture = _buildFixture(_collectionScope(COLLECTION_ID), true);
        _scheduleAndOpen(fixture);

        _expectMissing(fixture, StreamFinalityDomains.COMPONENT_COLLECTION_METADATA);
        _expectMissing(fixture, StreamFinalityDomains.COMPONENT_METADATA_ROUTER);
        _expectMissing(fixture, StreamFinalityDomains.COMPONENT_RENDERER);
        _expectMissing(fixture, StreamFinalityDomains.COMPONENT_RENDER_CONTEXT);
        _expectMissing(fixture, StreamFinalityDomains.COMPONENT_MEDIA_MANIFEST);
        _expectMissing(fixture, StreamFinalityDomains.COMPONENT_ENTROPY_COORDINATOR);

        // The full base set (6 mandatory + 1 sanction) succeeds.
        _finalizeFixtureCall(fixture);
        registry.collectionFinalityRecord(COLLECTION_ID).finalized.assertTrue("full set finalized");
    }

    function testBaseFloorHoldsAtGenesisWithoutDiscovery() public {
        // The registry under test is constructed with finalityDiscovery == address(0), so this
        // proves the floor is enforced with no discovery module bound (the FIX 1 gap).
        registry.finalityDiscovery().assertEq(address(0), "discovery unbound");
        Fixture memory fixture = _buildFixture(_collectionScope(COLLECTION_ID), true);
        _scheduleAndOpen(fixture);
        _expectMissing(fixture, StreamFinalityDomains.COMPONENT_RENDERER);
    }

    function testOffchainDoesNotRequireScriptComponents() public {
        // An OFFCHAIN collection finalizes with only the base six + sanction; no SCRIPT_SOURCE,
        // DEPENDENCY_SOURCE, or REFERENCE_RENDER required.
        Fixture memory fixture = _buildFixture(_collectionScope(COLLECTION_ID), true);
        for (uint256 i = 0; i < fixture.components.length; i++) {
            bytes32 t = fixture.components[i].componentType;
            (t != StreamFinalityDomains.COMPONENT_SCRIPT_SOURCE).assertTrue("no script source");
            (t != StreamFinalityDomains.COMPONENT_REFERENCE_RENDER).assertTrue("no ref render");
        }
        _executeFixture(fixture);
        registry.collectionFinalityRecord(COLLECTION_ID).finalized.assertTrue("offchain finalized");
    }

    // ------------------------------------------------------------------
    // FIX 1: script-work floor (ONCHAIN / HYBRID add three types)
    // ------------------------------------------------------------------

    function testOnchainRequiresScriptComponents() public {
        Fixture memory fixture = _buildFixture(
            _collectionScope(COLLECTION_ID),
            true,
            StreamFinalityDomains.METADATA_MODE_ONCHAIN,
            false
        );
        _scheduleAndOpen(fixture);
        _expectMissing(fixture, StreamFinalityDomains.COMPONENT_SCRIPT_SOURCE);
        _expectMissing(fixture, StreamFinalityDomains.COMPONENT_DEPENDENCY_SOURCE);
        _expectMissing(fixture, StreamFinalityDomains.COMPONENT_REFERENCE_RENDER);
        // The full script-work set (9 mandatory + 1 sanction) succeeds.
        _finalizeFixtureCall(fixture);
        registry.collectionFinalityRecord(COLLECTION_ID).finalized.assertTrue("onchain finalized");
    }

    function testHybridRequiresScriptComponents() public {
        Fixture memory fixture = _buildFixture(
            _collectionScope(COLLECTION_ID), true, StreamFinalityDomains.METADATA_MODE_HYBRID, false
        );
        _scheduleAndOpen(fixture);
        _expectMissing(fixture, StreamFinalityDomains.COMPONENT_SCRIPT_SOURCE);
        _finalizeFixtureCall(fixture);
        registry.collectionFinalityRecord(COLLECTION_ID).finalized.assertTrue("hybrid finalized");
    }

    function testScopedFinalityAppliesTheFloor() public {
        // The floor applies to scoped finality as well; a TOKEN scope missing RENDERER reverts.
        StreamFinalityScope memory scope = _tokenScope(COLLECTION_ID, 12);
        Fixture memory fixture = _buildFixture(scope, true);
        StreamFinalityComponentExpectation[] memory without =
            _withoutComponent(fixture, StreamFinalityDomains.COMPONENT_RENDERER);
        _scheduleAndOpen(fixture);
        vm.prank(finalityAdmin);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamArtworkFinalityRegistry.FinalityMissingRequiredComponent.selector,
                StreamFinalityDomains.COMPONENT_RENDERER
            )
        );
        registry.finalizeArtworkScope(
            scope, without, fixture.expectedFinalityRecordHash, fixture.manifest
        );
    }

    // ------------------------------------------------------------------
    // Discovery still layered on top of the floor when bound
    // ------------------------------------------------------------------

    function testDiscoveryExactMatchStillEnforcedOnTopOfFloor() public {
        MockFinalityDiscovery discovery = new MockFinalityDiscovery();
        registry = new StreamArtworkFinalityRegistry(
            address(coreMock),
            address(metadataMock),
            address(sanctionMock),
            address(authority),
            address(discovery)
        );
        previewer = new StreamArtworkFinalityPreview(registry);

        Fixture memory fixture = _buildFixture(_collectionScope(COLLECTION_ID), true);
        uint256 total = fixture.components.length;
        _scheduleAndOpen(fixture);

        // Floor satisfied, but discovery disagrees on the exact set: still blocks.
        discovery.setCollectionDiscovery(COLLECTION_ID, total, keccak256("router set"));
        vm.prank(finalityAdmin);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamArtworkFinalityRegistry.FinalityDiscoveryHashMismatch.selector,
                keccak256("router set"),
                fixture.componentsHash
            )
        );
        registry.finalizeCollectionArtwork(
            COLLECTION_ID, fixture.components, fixture.expectedFinalityRecordHash, fixture.manifest
        );

        // Exact discovery agreement passes.
        discovery.setCollectionDiscovery(COLLECTION_ID, total, fixture.componentsHash);
        _finalizeFixtureCall(fixture);
        registry.collectionFinalityRecord(COLLECTION_ID).finalized.assertTrue("finalized");
    }

    // ------------------------------------------------------------------
    // FIX 3: onchain/hybrid snapshot-manifest gate ([CMC-FINALITY-INPUTS] rule 3)
    // ------------------------------------------------------------------

    function testOnchainWithoutSnapshotManifestReverts() public {
        Fixture memory fixture = _buildFixture(
            _collectionScope(COLLECTION_ID),
            true,
            StreamFinalityDomains.METADATA_MODE_ONCHAIN,
            false
        );
        // Clear the assembled-snapshot-manifest hash the fixture recorded.
        metadataMock.setSnapshotHash(COLLECTION_ID, bytes32(0));
        _scheduleAndOpen(fixture);
        vm.prank(finalityAdmin);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamArtworkFinalityRegistry.FinalitySnapshotManifestMissing.selector,
                COLLECTION_ID,
                StreamFinalityDomains.METADATA_MODE_ONCHAIN
            )
        );
        registry.finalizeCollectionArtwork(
            COLLECTION_ID, fixture.components, fixture.expectedFinalityRecordHash, fixture.manifest
        );

        // Preview reports the gate without reverting (snapshot folds into coreGatesSatisfied).
        StreamFinalityPreview memory p = previewer.previewCollectionFinality(
            COLLECTION_ID, fixture.components, fixture.manifest
        );
        p.coreGatesSatisfied.assertFalse("preview snapshot gate red");
        p.wouldExecute.assertFalse("preview would not execute");

        // Recording the snapshot manifest unblocks.
        metadataMock.setSnapshotHash(COLLECTION_ID, keccak256("assembled-snapshot"));
        _finalizeFixtureCall(fixture);
        registry.collectionFinalityRecord(COLLECTION_ID).finalized.assertTrue("onchain finalized");
    }

    function testHybridWithoutSnapshotManifestReverts() public {
        Fixture memory fixture = _buildFixture(
            _collectionScope(COLLECTION_ID), true, StreamFinalityDomains.METADATA_MODE_HYBRID, false
        );
        metadataMock.setSnapshotHash(COLLECTION_ID, bytes32(0));
        _scheduleAndOpen(fixture);
        vm.prank(finalityAdmin);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamArtworkFinalityRegistry.FinalitySnapshotManifestMissing.selector,
                COLLECTION_ID,
                StreamFinalityDomains.METADATA_MODE_HYBRID
            )
        );
        registry.finalizeCollectionArtwork(
            COLLECTION_ID, fixture.components, fixture.expectedFinalityRecordHash, fixture.manifest
        );
    }

    function testOffchainUnaffectedBySnapshotGate() public {
        // OFFCHAIN never records a snapshot manifest and must finalize without one.
        Fixture memory fixture = _buildFixture(_collectionScope(COLLECTION_ID), true);
        metadataMock.latestCollectionSnapshotHash(COLLECTION_ID)
            .assertEq(bytes32(0), "no snapshot for OFFCHAIN");
        _executeFixture(fixture);
        registry.collectionFinalityRecord(COLLECTION_ID).finalized
            .assertTrue("offchain finalized without snapshot manifest");
    }
}
