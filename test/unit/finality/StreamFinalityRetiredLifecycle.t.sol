// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../smart-contracts/domains/finality/StreamArtworkFinalityPreview.sol";
import "../../helpers/FinalityCanonicalReadFixture.sol";
import "../../regression/legacy/helpers/CharacterizationTestBase.sol";

contract StreamFinalityRetiredLifecycleTest is CharacterizationTestBase {
    function testCurrentRegistryRejectsAllFiveRetiredLocalLifecycleSelectors() public {
        StreamArtworkFinalityRegistry registry = new FinalityCanonicalReadFixture().deploy();
        StreamFinalityScope memory scope =
            StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 7, 0, bytes32(0));
        bytes memory expected = abi.encodeWithSelector(
            IStreamCanonicalArtworkFinality.FinalityLocalLifecycleRetired.selector
        );
        vm.expectRevert(expected);
        registry.scheduleArtworkTerminalFreeze(scope, keccak256("record"), 1000, 2000);
        vm.expectRevert(expected);
        registry.vetoArtworkTerminalFreeze(scope, keccak256("reason"));
        vm.expectRevert(expected);
        registry.cancelArtworkTerminalFreeze(scope, keccak256("reason"));
        vm.expectRevert(expected);
        registry.materializeExpiredArtworkTerminalFreeze(scope);
        vm.expectRevert(expected);
        registry.artworkTerminalFreezeAction(scope);
        require(!registry.artworkScopeFinalityRecord(scope).finalized, "no synthetic record");
    }

    function testCurrentPreviewPreservesBindingsAndExplicitlyRejectsOldReadinessTuple() public {
        StreamArtworkFinalityRegistry registry = new FinalityCanonicalReadFixture().deploy();
        StreamArtworkFinalityPreview preview = new StreamArtworkFinalityPreview(registry);
        require(address(preview.registry()) == address(registry), "registry");
        require(address(preview.coreReads()) == registry.core(), "core");
        require(
            address(preview.coreFinalityAdapter()) == address(registry.coreFinalityAdapter()),
            "adapter"
        );
        require(address(preview.metadataReads()) == address(registry.metadataReads()), "metadata");
        require(address(preview.sanctionReads()) == address(registry.sanctionReads()), "sanction");
        require(
            address(preview.governanceAuthority()) == registry.governanceAuthority(), "Executor"
        );
        require(preview.finalityDiscovery() == registry.finalityDiscovery(), "discovery");
        StreamFinalityComponentExpectation[] memory entries =
            new StreamFinalityComponentExpectation[](0);
        StreamFinalityManifestRef memory manifest;
        bytes memory expected = abi.encodeWithSelector(
            StreamArtworkFinalityPreview.FinalityPreviewLegacyLifecycleRetired.selector
        );
        vm.expectRevert(expected);
        preview.previewCollectionFinality(7, entries, manifest);
        vm.expectRevert(expected);
        preview.previewArtworkScopeFinality(
            StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 7, 0, bytes32(0)),
            entries,
            manifest
        );
        vm.expectRevert(
            abi.encodeWithSelector(StreamArtworkFinalityPreview.FinalityPreviewZeroAddress.selector)
        );
        new StreamArtworkFinalityPreview(StreamArtworkFinalityRegistry(address(0)));
    }
}
