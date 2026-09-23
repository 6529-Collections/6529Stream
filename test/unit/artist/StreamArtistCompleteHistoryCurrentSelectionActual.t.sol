// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./ArtistPrimaryCollaboratorFixture.sol";
import {
    StreamArtistCompleteHistoryCurrent as CHCurrent
} from "../../../smart-contracts/domains/artist/StreamArtistCompleteHistoryCurrent.sol";

/// @notice The whole-family recheck preserves the original nonselected PC commit path.
/// @dev This is an actual old-profile routing regression, not complete-history apply evidence.
contract StreamArtistCompleteHistoryCurrentSelectionActualTest is ArtistPrimaryCollaboratorFixture {
    function testCompleteCurrentDeclinesOriginalPCBeforeInspectingOtherPreparedFields() external {
        _pcSource(0);
        Successor memory next = _multiCutover();
        (, Commit.Prepared memory original) = _pcPrepare(next);
        require(!CHCurrent.recheck(original), "original PC remains nonselected");

        // A nonselected worker must not invoke any complete-history-only source or row proof.
        // Keep the authentic original owner0 envelope and leave every other prepared field empty.
        Commit.Prepared memory onlyOriginalOwner;
        onlyOriginalOwner.data[0].typedState = original.data[0].typedState;
        require(!CHCurrent.recheck(onlyOriginalOwner), "nonselected route read unrelated fields");
    }
}
