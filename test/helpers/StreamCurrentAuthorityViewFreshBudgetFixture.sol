// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamCurrentAuthorityViewReferenceFixture
} from "./StreamCurrentAuthorityViewReferenceFixture.sol";

/// @notice Separate new-deployment VIEW constructor profile for a bounded composition probe.
/// @dev This is an unmeasured candidate, not accepted gas sizing. All original diagnostic
/// defaults remain in the base fixture. No already-deployed governed parameter is lowered,
/// no parent component allowance is raised, and every full production read remains mandatory.
abstract contract StreamCurrentAuthorityViewFreshBudgetFixture is
    StreamCurrentAuthorityViewReferenceFixture
{
    function _authorityViewConstructionBudgets()
        internal
        pure
        override
        returns (AuthorityViewConstructionBudgets memory b)
    {
        b = super._authorityViewConstructionBudgets();
        // Keep original leaf renderer/attribution and fixed read/inventory/archive allowances.
        // These nested ceilings leave EIP-150 and reader reserve room, not measured execution
        // headroom. Full checkpoint revalidation still rerenders both JSON and HTML for all rows.
        b.checkpointServingGas = 6000000;
        b.outputValidationGas = 7000000;
        b.snapshotSourceGas = 8000000;
        b.boundSnapshotValidationGas = 9000000;
        b.referenceSourceGas = 4000000;
        b.referenceSnapshotGas = 9000000;
    }
}
