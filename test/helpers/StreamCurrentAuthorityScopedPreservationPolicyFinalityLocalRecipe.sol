// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamCurrentAuthorityScopedPreservationPolicyLocalRecipe
} from "./StreamCurrentAuthorityScopedPreservationPolicyLocalRecipe.sol";
import {
    StreamCurrentAuthorityScopedPreservationPolicyFinalityFixture
} from "./StreamCurrentAuthorityScopedPreservationPolicyFinalityFixture.sol";

/// @notice Explicit local export/resume recipe ending in genuine scoped sanction/archive/Finality.
/// @dev Use this distinct contract's inherited export/cover entrypoints with fresh observed inputs.
/// The original LocalRecipe remains bundle-only. Runtime, browser and transaction acceptance are
/// pending; authoring these calls is not evidence of an executed ceremony or onchain deployment.
contract StreamCurrentAuthorityScopedPreservationPolicyFinalityLocalRecipe is
    StreamCurrentAuthorityScopedPreservationPolicyLocalRecipe,
    StreamCurrentAuthorityScopedPreservationPolicyFinalityFixture
{
    AuthorityScopedFinality private completedScopedFinality;

    event ScopedPreservationFinalityCompleted(
        uint8 indexed authorityEra,
        bytes32 indexed finalityRecord,
        bytes32 indexed sanctionRecord,
        bytes32 manifestHash,
        bytes32 actionId
    );

    function scopedFinalityEvidence() external view returns (AuthorityScopedFinality memory) {
        require(
            completedScopedFinality.finalityRecord != 0, "actual scoped finality has not completed"
        );
        return completedScopedFinality;
    }

    function _beforeScopedRecipeInventory(
        AuthorityScopedPublication memory,
        AuthorityScopedReference memory
    ) internal override {
        _authorityPrepareScopedFinalityDefinitions();
    }

    function _afterScopedRecipeBundle(
        AuthorityScopedPublication memory publication,
        AuthorityScopedReference memory referenceResult,
        AuthorityScopedInventory memory inventoryResult,
        AuthorityScopedBundle memory bundleResult
    ) internal override {
        require(completedScopedFinality.finalityRecord == 0, "one exact finality per local recipe");
        completedScopedFinality = _authorityFinalizeScopedPreservation(
            publication, referenceResult, inventoryResult, bundleResult
        );
        emit ScopedPreservationFinalityCompleted(
            completedScopedFinality.authorityEra,
            completedScopedFinality.finalityRecord,
            completedScopedFinality.sanctionRecord,
            completedScopedFinality.manifestHash,
            completedScopedFinality.actionId
        );
    }
}
