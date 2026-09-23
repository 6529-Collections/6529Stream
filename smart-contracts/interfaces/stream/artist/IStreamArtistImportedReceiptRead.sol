// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredHydrationTypes as RH
} from "./StreamArtistRecoveredHydrationTypes.sol";

/// @notice One authenticated original occurrence in this owner's immutable recovered prefix.
/// @dev The exact static result is 320 bytes. Missing imported membership never implies
/// local production. Original producers need only their existing native receipt reads.
interface IStreamArtistImportedReceiptRead {
    function recoveredHydrationImportedReceiptAt(uint256 index)
        external
        view
        returns (RH.JournalEntry memory entry, bytes32 importCommitment, uint64 importedAtRevision);
}
