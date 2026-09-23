// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistMultipleHydrationTypes as MH
} from "../../interfaces/stream/artist/IStreamArtistMultipleAuthorityHydration.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistMultipleHydrationOperations as Original
} from "./StreamArtistMultipleHydrationOperations.sol";

library StreamArtistUnboundPlatformSelectors {
    function selected(MH.Request memory p) public pure returns (bool) {
        for (uint256 i; i < p.collections.length; ++i) {
            if (p.collections[i].artistId == 0) return true;
        }
        return false;
    }

    function validate(MH.Request memory p) public pure {
        if (
            p.bindingIndex != 0 || p.artistIds.length > 128 || p.collections.length == 0
                || p.collections.length > 128
        ) revert T.UnsupportedProfile();
        if (!selected(p)) revert T.UnsupportedProfile();
        for (uint256 i; i < p.artistIds.length; ++i) {
            if (p.artistIds[i] == 0 || (i != 0 && p.artistIds[i] <= p.artistIds[i - 1])) {
                revert T.InvalidRecord();
            }
            bool present;
            for (uint256 j; j < p.collections.length; ++j) {
                if (p.collections[j].artistId == p.artistIds[i]) present = true;
            }
            if (!present) revert T.InvalidRecord();
        }
        for (uint256 i; i < p.collections.length; ++i) {
            MH.Collection memory c = p.collections[i];
            if (
                c.collectionId == 0
                    || (i != 0 && c.collectionId <= p.collections[i - 1].collectionId)
                    || c.policies.length > 128
            ) revert T.InvalidRecord();
            if (c.artistId == 0) {
                if (c.policies.length != 0) revert T.InvalidRecord();
            } else {
                Original._artist(p.artistIds, c.artistId);
            }
            for (uint256 j; j < c.policies.length; ++j) {
                if (c.policies[j].phaseId == 0 || c.policies[j].policyHash == 0) {
                    revert T.InvalidRecord();
                }
                for (uint256 k; k < j; ++k) {
                    if (
                        c.policies[k].phaseId == c.policies[j].phaseId
                            && c.policies[k].policyHash == c.policies[j].policyHash
                    ) {
                        revert T.InvalidRecord();
                    }
                }
            }
        }
    }
}
