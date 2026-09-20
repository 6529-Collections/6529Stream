// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistRecoveredDelegatedConsentHydration as Delegated
} from "./StreamArtistRecoveredDelegatedConsentHydration.sol";
import {
    StreamArtistRecoveredContentConsentHydration as ContentConsents
} from "./StreamArtistRecoveredContentConsentHydration.sol";

/// @notice Fixed typed stage of recovered-authority preparation.
/// @dev Intermediate bytes are ABI encodings of the named complete bundle, never caller-selected calls.
library StreamArtistRecoveredPreparationConsents {
    function content(
        address source,
        AH.Query memory query,
        RH.OwnerProvenance memory provenance,
        T.EconomicsConsent[] memory economics,
        T.RoyaltyFreeze[] memory royaltyFreezes
    ) public view returns (bytes memory) {
        return abi.encode(
            ContentConsents.collect(source, query, provenance, economics, royaltyFreezes)
        );
    }

    function delegated(
        address source,
        AH.Query memory query,
        RH.OwnerProvenance memory provenance,
        T.EconomicsConsent[] memory economics
    ) public view returns (bytes memory) {
        return abi.encode(Delegated.collect(source, query, provenance, economics));
    }

    function encode(
        bytes memory raw,
        bool hasContent,
        AH.Query memory query,
        RH.OwnerProvenance memory provenance
    ) public pure returns (bytes memory) {
        if (hasContent) {
            return ContentConsents.encode(
                abi.decode(raw, (ContentConsents.Bundle)), query, provenance
            );
        }
        return Delegated.encode(abi.decode(raw, (Delegated.Bundle)), query, provenance);
    }
}
