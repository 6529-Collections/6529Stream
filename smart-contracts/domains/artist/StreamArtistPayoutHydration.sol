// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistNativeReceipts.sol";
import "../../interfaces/stream/artist/IStreamArtistPayoutAuthorityHydration.sol";
import "../../interfaces/stream/artist/IStreamArtistPayoutTransitionOwner.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistPayoutHydrationTypes as PH
} from "../../interfaces/stream/artist/IStreamArtistPayoutAuthorityHydration.sol";

/// @dev Fixed typed state bridge. No signature re-verification or current-authority invention.
library StreamArtistPayoutHydration {
    function exportState(
        mapping(bytes32 => T.Payout) storage stable,
        mapping(bytes32 => T.PayoutDesignation) storage records,
        mapping(bytes32 => T.Payout) storage pending,
        mapping(bytes32 => R.ProvisionalAssociation) storage associations,
        mapping(bytes32 => bytes32) storage abandoned,
        bytes32 artistId
    ) public view returns (bytes memory) {
        uint256 count = StreamArtistNativeReceipts.count();
        if (count == 0) return bytes("");
        if (
            count > 128 || pending[artistId].recordHash != 0
                || pending[artistId].account != address(0)
        ) {
            revert T.UnsupportedProfile();
        }
        PH.Bundle memory p;
        p.current = stable[artistId];
        p.records = new PH.Row[](count);
        bytes32 prior;
        address last;
        for (uint256 j; j < count; ++j) {
            H.Receipt memory r = StreamArtistNativeReceipts.at(j);
            T.PayoutDesignation memory terms = records[r.recordHash];
            R.ProvisionalAssociation memory a = associations[r.recordHash];
            if (
                r.operation != 18 || r.artistId != artistId || r.collectionId != 0
                    || r.recordHash == 0 || terms.artistId != artistId
                    || terms.payoutAccount == address(0) || terms.payoutAccount == last
                    || terms.previousDesignationRecordHash != prior || a.transitionRecordHash != 0
                    || a.windowEndsAt != 0 || abandoned[r.recordHash] != 0
            ) revert T.UnsupportedProfile();
            p.records[j] = PH.Row(r.recordHash, terms);
            prior = r.recordHash;
            last = terms.payoutAccount;
        }
        if (p.current.recordHash != prior || p.current.account != last) revert T.InvalidRecord();
        return abi.encode(p);
    }

    function importState(
        mapping(bytes32 => T.Payout) storage stable,
        mapping(bytes32 => T.PayoutDesignation) storage records,
        bytes32 artistId,
        bytes memory raw
    ) public {
        if (raw.length == 0) return;
        PH.Bundle memory p = abi.decode(raw, (PH.Bundle));
        if (
            stable[artistId].recordHash != 0 || stable[artistId].account != address(0)
                || p.records.length == 0
        ) revert T.InvalidRecord();
        bytes32 prior;
        address last;
        for (uint256 j; j < p.records.length; ++j) {
            PH.Row memory r = p.records[j];
            if (
                records[r.recordHash].artistId != 0 || r.recordHash == 0
                    || r.terms.artistId != artistId
                    || r.terms.previousDesignationRecordHash != prior
                    || r.terms.payoutAccount == address(0) || r.terms.payoutAccount == last
            ) revert T.InvalidRecord();
            records[r.recordHash] = r.terms;
            prior = r.recordHash;
            last = r.terms.payoutAccount;
        }
        if (p.current.recordHash != prior || p.current.account != last) revert T.InvalidRecord();
        stable[artistId] = p.current;
    }
}
