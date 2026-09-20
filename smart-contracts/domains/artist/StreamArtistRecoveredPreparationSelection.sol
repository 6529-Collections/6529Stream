// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    IStreamArtistBindingOwner as Binding
} from "../../interfaces/stream/artist/IStreamArtistBindingOwner.sol";

/// @notice Original complete-history profile selection after attestation collection.
/// @dev Expired, revoked and unused grants still select the delegated composition.
library StreamArtistRecoveredPreparationSelection {
    function flags(
        address bindingOwner,
        uint256 collectionId,
        bool hasIdentityDelegations,
        RH.JournalEntry[] calldata consentJournal
    ) public view returns (uint8 consentMode, bool hasDelegation, bool hasContent) {
        consentMode = Binding(bindingOwner).binding(collectionId).consentMode;
        hasDelegation = hasIdentityDelegations || consentMode == 2;
        for (uint256 i; i < consentJournal.length; ++i) {
            uint16 op = consentJournal[i].receipt.operation;
            if (op == 16) hasDelegation = true;
            if (op == 17 || op == 20 || op == 21) hasContent = true;
        }
    }
}
