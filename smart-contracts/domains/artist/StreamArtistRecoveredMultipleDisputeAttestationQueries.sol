// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredMultipleTypes as M
} from "../../interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistRecoveredMultipleDisputeTypes as MD
} from "./StreamArtistRecoveredMultipleDisputeTypes.sol";

/// @notice Original owner4 occurrences projected onto the complete admitted collection graph.
/// @dev Calldata-to-memory copies retain every Artist record and policy without aliasing the
/// admission certificate. Only collection record arrays change; owner provenance stays whole.

library StreamArtistRecoveredMultipleDisputeAttestationQueries {
    function project(M.State calldata s, RH.OwnerProvenance calldata p)
        public
        pure
        returns (M.State memory r)
    {
        if (p.journal.length > RH.MAX_JOURNAL_ENTRIES) _invalid();
        r.artists = new AH.Query[](s.artists.length);
        r.collections = new AH.Query[](s.collections.length);
        r.rows = new bytes[](s.rows.length);
        for (uint256 a; a < s.artists.length; ++a) {
            r.artists[a] = s.artists[a];
        }
        for (uint256 k; k < s.collections.length; ++k) {
            r.collections[k] = s.collections[k];
        }
        for (uint256 k; k < s.rows.length; ++k) {
            r.rows[k] = s.rows[k];
        }
        uint256[] memory counts = new uint256[](s.collections.length);
        uint256[] memory selected = new uint256[](p.journal.length);
        for (uint256 i; i < p.journal.length; ++i) {
            RH.JournalEntry calldata e = p.journal[i];
            if (MD.nativeDispute(e.receipt.operation)) continue;
            if (e.receipt.operation != 24 || e.receipt.recordHash == bytes32(0)) _invalid();
            for (uint256 j; j < i; ++j) {
                if (p.journal[j].receipt.recordHash == e.receipt.recordHash) _invalid();
            }
            uint256 artists;
            for (uint256 a; a < s.artists.length; ++a) {
                if (s.artists[a].artistId == e.receipt.artistId) ++artists;
            }
            if (artists != 1) _invalid();
            uint256 matches;
            for (uint256 k; k < s.collections.length; ++k) {
                AH.Query calldata q = s.collections[k];
                if (q.collectionId != e.receipt.collectionId) continue;
                if (q.artistId != e.receipt.artistId) _invalid();
                ++matches;
                selected[i] = k;
            }
            if (matches != 1) _invalid();
            ++counts[selected[i]];
        }
        for (uint256 k; k < s.collections.length; ++k) {
            r.collections[k].records = new bytes32[](counts[k]);
            counts[k] = 0;
        }
        for (uint256 i; i < p.journal.length; ++i) {
            if (MD.nativeDispute(p.journal[i].receipt.operation)) continue;
            uint256 k = selected[i];
            r.collections[k].records[counts[k]++] = p.journal[i].receipt.recordHash;
        }
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
