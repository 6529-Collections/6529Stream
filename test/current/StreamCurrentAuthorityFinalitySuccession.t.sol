// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/StreamCurrentAuthorityMigrationRecipe.sol";

/// @notice Actual original deployment, repeated authority succession and canonical finalization.
/// @dev Source-authored integration cases; native runtime/gas validation is a separate gate.
contract StreamCurrentAuthorityFinalitySuccessionTest is StreamCurrentAuthorityMigrationRecipe {
    function testActualOriginalAuthorityProfileFinalizesAndConfirms() public {
        _authorityPrepareOriginalPreservation();
        _finishCurrentCeremony();
        require(authorityEra == 0, "original current authority");
    }

    function testActualPreservedOriginalFinalitySanctionsHydratedBAndConfirms() public {
        _authorityPrepareOriginalPreservation();
        _authorityMigrateNext();
        _finishCurrentCeremony();
        require(
            authorityEra == 1 && authorityRegistries[1] == address(assemblyArtists),
            "actual hydrated B sanctions preserved original Finality"
        );
    }

    function testActualAtoBtoUnpredictedCStalesPlansPreservesHistoryAndFinalizes() public {
        _authorityPrepareOriginalPreservation();
        _assemblyMaterializeInventory();
        bytes32 sealedA = assemblyRenderInventoryPlan;
        bytes32 historicalA = keccak256(abi.encode(assemblyInventory.inventoryEvidence(sealedA)));
        bytes32 selectionA = assemblyInventory.authoritySelection(sealedA).selection.selectionHash;
        _authorityMigrateNext();
        require(
            keccak256(abi.encode(assemblyInventory.inventoryEvidence(sealedA))) == historicalA,
            "sealed A evidence is still available after actual B cutover"
        );
        _rejectStaleFullRead(sealedA);
        bytes32 stagedB = assemblyInventory.beginInventory(1);
        assemblyInventory.appendNative(stagedB);
        bytes32 historicalB = _historicalPlanHash(stagedB);
        bytes32 selectionB = assemblyInventory.authoritySelection(stagedB).selection.selectionHash;
        require(selectionB != selectionA, "B captures distinct actual current authority");
        address b = address(assemblyArtists);
        require(authorityRegistries[2] == address(0), "C was not configured before B completion");

        _authorityMigrateNext();
        require(
            authorityEra == 2 && address(assemblyArtists) != b
                && assemblyAuthorityResolver.currentSelection().origin.environment.registry
                    == address(assemblyArtists),
            "later allocated C becomes genuinely current after atomic import"
        );
        (bool ok, bytes memory data) = address(assemblyInventory)
            .call(abi.encodeCall(assemblyInventory.appendReference, (stagedB)));
        require(
            !ok
                && keccak256(data)
                    == keccak256(abi.encodeWithSelector(CA.CurrentAuthorityChanged.selector)),
            "next genuine B stage rejects exact authority change"
        );
        require(
            _historicalPlanHash(stagedB) == historicalB,
            "failed stale append changes no B context capture cursor or segment"
        );
        require(
            keccak256(abi.encode(assemblyInventory.inventoryEvidence(sealedA))) == historicalA,
            "same original sealed A evidence remains readable through C"
        );
        _rejectStaleFullRead(sealedA);
        _finishCurrentCeremony();
        require(
            assemblyRenderInventoryPlan != sealedA && assemblyRenderInventoryPlan != stagedB
                && assemblyInventory.authoritySelection(assemblyRenderInventoryPlan).selection
                        .selectionHash != selectionB,
            "fresh C plan captures C and archives original provenance"
        );
        require(
            assemblyInventory.originCount(assemblyRenderInventoryPlan) == 3,
            "actual inventory contains original A imported B and current C runtime origins"
        );
    }

    function _finishCurrentCeremony() private {
        _authorityRequireOriginals();
        _authorityRequireRoute();
        AssemblyInventory.Item[][] memory rows = _assemblyMaterializeInventory();
        _assemblyCoverCompleteBundle(rows);
        _assemblyCloseAndFreezeCore();
        _assemblyPerformSanctionAndFinality();
        _assemblyConfirmSanctionFinalized();
        require(
            assemblySanctionRecord != 0 && assemblyFinalityRecord != 0
                && assemblyFinality.collectionFinalityRecord(1).finalized,
            "actual Safe sanction class2 finalization and permissionless confirmation"
        );
        _authorityRequireOriginals();
        _authorityRequireRoute();
    }

    function _rejectStaleFullRead(bytes32 id) private view {
        (bool ok, bytes memory data) = address(assemblyInventory)
            .staticcall(abi.encodeCall(assemblyInventory.requireFullDefinitionBytes, (id)));
        require(
            !ok
                && keccak256(data)
                    == keccak256(abi.encodeWithSelector(CA.CurrentAuthorityChanged.selector)),
            "completed historical plan refuses current eligibility after cutover"
        );
    }

    function _historicalPlanHash(bytes32 id) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                assemblyInventory.plan(id),
                assemblyInventory.sourceContext(id),
                assemblyInventory.authoritySelection(id),
                assemblyInventory.inventorySegment(id, 0),
                assemblyInventory.originRuntimeCursor(id),
                assemblyInventory.originCount(id)
            )
        );
    }
}
