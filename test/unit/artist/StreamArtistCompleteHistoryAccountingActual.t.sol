// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./ArtistCompleteHistoryChronologyFixture.sol";
import {
    StreamArtistCompleteHistoryTypes as AccountingCT
} from "../../../smart-contracts/domains/artist/StreamArtistCompleteHistoryTypes.sol";
import {
    StreamArtistCompleteHistoryAccounting as AccountingCH
} from "../../../smart-contracts/domains/artist/StreamArtistCompleteHistoryAccounting.sol";
import {
    StreamArtistCompleteHistoryDisputeSource as AccountingDisputes
} from "../../../smart-contracts/domains/artist/StreamArtistCompleteHistoryDisputeSource.sol";
import {
    StreamArtistRecoveredDisputeHistoryTypes as AccountingD
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredDisputeHistoryTypes.sol";

/// @notice Original owner writes supply the checkpoint; mutations target only the claimed census.
contract StreamArtistCompleteHistoryAccountingActualTest is ArtistCompleteHistoryChronologyFixture {
    function testCompleteAccountingPendingAndAcceptedSiblingConserveOriginalRevisions() external {
        (
            AccountingCT.Inventory memory inventory,
            PCClocks.Result memory clocks,
            AccountingD.Bundle[] memory histories
        ) = _accounting(0);
        AccountingCH.validate(inventory, clocks, histories);
    }

    function testCompleteAccountingPartialRefusalConservesOriginalTerminalWrite() external {
        (
            AccountingCT.Inventory memory inventory,
            PCClocks.Result memory clocks,
            AccountingD.Bundle[] memory histories
        ) = _accounting(3);
        AccountingCH.validate(inventory, clocks, histories);
    }

    function testCompleteAccountingRejectsTwoWritesClaimingOneOriginalRevision() external {
        (
            AccountingCT.Inventory memory inventory,
            PCClocks.Result memory clocks,
            AccountingD.Bundle[] memory histories
        ) = _accounting(0);
        // Both coordinates remain valid owner4 points and the claimed count is unchanged.
        // Only the disjointness check detects the duplicated original revision here.
        clocks.clocks.collections[0].attributionCompletions[0] =
            clocks.clocks.collections[0].attributionProposals[0];
        avm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        AccountingCH.validate(inventory, clocks, histories);
    }

    function testCompleteAccountingRejectsOmittedWriteEvenWithRecountedBindingTotal() external {
        (
            AccountingCT.Inventory memory inventory,
            PCClocks.Result memory clocks,
            AccountingD.Bundle[] memory histories
        ) = _accounting(0);
        RH.Point memory empty;
        clocks.clocks.collections[0].attributionCompletions[0] = empty;
        --clocks.clocks.counts[0];
        avm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        AccountingCH.validate(inventory, clocks, histories);
    }

    function _accounting(uint8 mode)
        private
        returns (
            AccountingCT.Inventory memory inventory,
            PCClocks.Result memory clocks,
            AccountingD.Bundle[] memory histories
        )
    {
        _pendingSource(mode);
        _multiCutover();
        Observed memory x = _observe();
        inventory.provenance = x.provenance;
        inventory.bindings = x.bindings;
        inventory.archive = x.archive;
        inventory.platforms = x.platforms;
        inventory.accepted = x.accepted;
        clocks = x.clocks;
        histories = AccountingDisputes.collect(
            suite.owners[4], x.scope, x.provenance, x.bindings, x.archive, x.clocks
        );
    }
}
