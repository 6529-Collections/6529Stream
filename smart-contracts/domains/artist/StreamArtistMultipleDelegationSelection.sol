// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistDelegationTypes as D
} from "../../interfaces/stream/artist/StreamArtistDelegationTypes.sol";
import {
    StreamArtistHistoryTypes as H
} from "../../interfaces/stream/artist/IStreamArtistHistory.sol";
import {
    StreamArtistMultipleHydrationTypes as MH
} from "../../interfaces/stream/artist/IStreamArtistMultipleAuthorityHydration.sol";
import "./StreamArtistMultipleDelegationSource.sol";
import "./StreamArtistHydrationCommit.sol";
import "../../interfaces/stream/artist/IStreamArtistBindingOwner.sol";

library StreamArtistMultipleDelegationSelection {
    event MultipleArtistAuthorityHydrated(
        address indexed predecessor,
        bytes32 indexed commitment,
        bytes32[] artistIds,
        uint256[] collectionIds
    );

    /// @dev Called only after the existing exact predecessor/suite admission. No catch-and-fallback.
    function required(T.SuiteConfiguration memory s) public view returns (bool) {
        uint256 count = IStreamArtistNativeReceipts(s.owners[2]).artistNativeReceiptCount();
        if (count > 128) revert T.UnsupportedProfile();
        for (uint256 i; i < count; ++i) {
            uint16 op = IStreamArtistNativeReceipts(s.owners[2]).artistNativeReceiptAt(i).operation;
            if (op == 25 || op == 26 || op == 27) return true;
        }
        count = IStreamArtistNativeReceipts(s.owners[6]).artistNativeReceiptCount();
        if (count > 128) revert T.UnsupportedProfile();
        for (uint256 i; i < count; ++i) {
            if (IStreamArtistNativeReceipts(s.owners[6]).artistNativeReceiptAt(i).operation == 16) {
                return true;
            }
        }
        count = IStreamArtistNativeReceipts(s.owners[0]).artistNativeReceiptCount();
        if (count > 128) revert T.UnsupportedProfile();
        for (uint256 i; i < count; ++i) {
            H.Receipt memory r = IStreamArtistNativeReceipts(s.owners[0]).artistNativeReceiptAt(i);
            if (IStreamArtistBindingOwner(s.owners[0]).binding(r.collectionId).consentMode == 2) {
                return true;
            }
        }
        return false;
    }

    function hydrate(
        D.CoordinatorContext memory x,
        address actor,
        MH.Request memory p,
        T.SuiteConfiguration memory s,
        address prior,
        address coordinator
    ) public returns (bytes32 value) {
        StreamArtistHydrationPrepared.Bundle memory h =
            StreamArtistMultipleDelegationSource.prepare(x, p, s, prior, coordinator);
        AH.Request memory base;
        base.artistId = h.q.artistId;
        base.collectionId = h.q.collectionId;
        base.policies = h.q.policies;
        base.expectedSource = p.expectedSource;
        base.replayOrigins = p.replayOrigins;
        value = StreamArtistHydrationCommit.execute(x, actor, base, h);
        uint256[] memory ids = new uint256[](p.collections.length);
        for (uint256 i; i < ids.length; ++i) {
            ids[i] = p.collections[i].collectionId;
        }
        emit MultipleArtistAuthorityHydrated(prior, value, p.artistIds, ids);
    }
}
