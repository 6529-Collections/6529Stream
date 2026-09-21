// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    IStreamArtistBindingOwner as Binding
} from "../../interfaces/stream/artist/IStreamArtistBindingOwner.sol";

/// @notice Fixed read-only feature selection over the four original admitted projections.
library StreamArtistRecoveredMultipleConsentSelection {
    function required(
        T.SuiteConfiguration memory source,
        AH.Query[] memory collections,
        RH.JournalEntry[] memory identity,
        RH.JournalEntry[] memory consents
    ) public view returns (bool) {
        for (uint256 i; i < identity.length; ++i) {
            uint16 op = identity[i].receipt.operation;
            if (op == 26 || op == 27) return true;
        }
        for (uint256 i; i < consents.length; ++i) {
            if (consents[i].receipt.operation != 14) return true;
        }
        for (uint256 i; i < collections.length; ++i) {
            if (Binding(source.owners[0]).binding(collections[i].collectionId).consentMode == 2) {
                return true;
            }
        }
        return false;
    }
}
