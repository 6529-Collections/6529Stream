// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    IStreamArtistHistory as History
} from "../../interfaces/stream/artist/IStreamArtistHistory.sol";
import {
    IStreamArtistIngressBinding as Ingress
} from "../../interfaces/stream/artist/IStreamArtistIngressBinding.sol";
import {
    IStreamArtistAuthorityHydrationCoordinator as Coordinator
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    IStreamArtistRecoveredHydrationOwner as Owner
} from "../../interfaces/stream/artist/IStreamArtistRecoveredHydration.sol";
import { IStreamArtistOwner } from "../../interfaces/stream/artist/IStreamArtistOwner.sol";
import {
    IStreamArtistBindingOwner as Binding
} from "../../interfaces/stream/artist/IStreamArtistBindingOwner.sol";
import {
    IStreamArtistCollaboratorBindingOwner as Terms
} from "../../interfaces/stream/artist/IStreamArtistCollaboratorBindingOwner.sol";

/// @notice Selection from the actual predecessor, before complete profile admission.
/// @dev This is not source admission. The chosen worker independently proves cutover,
/// every source dependency, all seven journals and the full original request. Empty
/// old graphs retain the original path; requested capabilities never select a profile.
library StreamArtistPrimaryCollaboratorSelection {
    function required(T.SuiteConfiguration memory destination, RH.Request memory request)
        public
        view
        returns (bool)
    {
        History history = History(destination.owners[2]);
        if (history.importedHistoryBindingCount() != 1) return false;
        (address prior,,,) = history.importedHistoryBinding(0);
        T.SuiteConfiguration memory source =
            Coordinator(Ingress(prior).operationCoordinator()).authorityHydrationSuite();
        (RH.OwnerProvenance memory prefix,, uint64 importedAt) =
            Owner(source.owners[1]).recoveredHydrationImportedPrefix();
        if (IStreamArtistOwner(source.owners[1]).ownerStateSnapshotV2().revision > importedAt) {
            return true;
        }
        for (uint256 i; i < prefix.eras.length; ++i) {
            if (prefix.eras[i].checkpoint.ownerState.revision > prefix.eras[i].lowerRevision) {
                return true;
            }
        }
        if (request.records.authority.collections.length > 128) {
            revert RH.InvalidRecoveredHydrationProfile();
        }
        for (uint256 k; k < request.records.authority.collections.length; ++k) {
            uint256 cid = request.records.authority.collections[k].collectionId;
            uint256 count = Binding(source.owners[0]).binding(cid).generation;
            if (count > 128) revert RH.InvalidRecoveredHydrationProfile();
            for (uint256 i; i < count; ++i) {
                if (Terms(source.owners[0]).bindingTerms(cid, uint64(i + 1)).count != 0) {
                    return true;
                }
            }
        }
        return false;
    }
}
