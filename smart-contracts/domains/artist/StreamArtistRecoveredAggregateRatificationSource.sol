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
    IStreamArtistConsentOwner as Consent
} from "../../interfaces/stream/artist/IStreamArtistConsentOwner.sol";
import {
    IStreamArtistDelegatedConsentOwner as Delegated
} from "../../interfaces/stream/artist/IStreamArtistDelegatedConsentOwner.sol";
import {
    StreamArtistRecoveredHydrationProvenance as Provenance
} from "./StreamArtistRecoveredHydrationProvenance.sol";

/// @notice Original operation52 rows and current heads over one complete owner6 certificate.
/// @dev Other operation families, whole-owner journal/replay validation and Identity facts
/// remain with the enclosing aggregate. No filtered or renumbered provenance is constructed.
library StreamArtistRecoveredAggregateRatificationSource {
    uint256 private constant MAX_ROWS = 128;

    function collect(address source, AH.Query[] memory queries, RH.OwnerProvenance memory p)
        public
        view
        returns (T.RatificationRecord[][] memory rows)
    {
        Provenance.validateOwnerSource(p, 6, source);
        _queries(queries);
        uint256[] memory counts = new uint256[](queries.length);
        for (uint256 i; i < p.journal.length; ++i) {
            RH.JournalEntry memory n = p.journal[i];
            if (n.receipt.operation != 52) continue;
            uint256 k = _collection(queries, n.receipt.artistId, n.receipt.collectionId);
            if (++counts[k] > MAX_ROWS) revert T.UnsupportedProfile();
        }
        rows = new T.RatificationRecord[][](queries.length);
        for (uint256 k; k < queries.length; ++k) {
            rows[k] = new T.RatificationRecord[](counts[k]);
            counts[k] = 0;
        }
        for (uint256 i; i < p.journal.length; ++i) {
            RH.JournalEntry memory n = p.journal[i];
            if (n.receipt.operation != 52) continue;
            uint256 k = _collection(queries, n.receipt.artistId, n.receipt.collectionId);
            bytes32 hash = n.receipt.recordHash;
            T.RatificationRecord memory r = Consent(source).ratificationRecord(hash);
            if (
                hash == 0 || r.recordHash != hash || r.contentStateHash == 0
                    || r.metadataContract == address(0)
                    || Delegated(source).recordDelegation(hash) != 0
            ) _invalid();
            rows[k][counts[k]++] = r;
        }
        requireHeads(source, queries, rows);
    }

    /// @notice Recheck each collection's actual latest row, including a genuinely empty head.
    function requireHeads(
        address source,
        AH.Query[] memory queries,
        T.RatificationRecord[][] memory rows
    ) public view {
        _queries(queries);
        if (rows.length != queries.length) _invalid();
        for (uint256 k; k < queries.length; ++k) {
            if (rows[k].length > MAX_ROWS) revert T.UnsupportedProfile();
            T.RatificationRecord memory expected;
            if (rows[k].length != 0) expected = rows[k][rows[k].length - 1];
            if (
                keccak256(
                        abi.encode(
                            Consent(source).firstReleaseRatification(queries[k].collectionId)
                        )
                    ) != keccak256(abi.encode(expected))
            ) _invalid();
        }
    }

    function _queries(AH.Query[] memory queries) private pure {
        if (queries.length == 0 || queries.length > MAX_ROWS) _invalid();
        for (uint256 k; k < queries.length; ++k) {
            if (
                queries[k].artistId == 0 || queries[k].collectionId == 0
                    || queries[k].bindingHash == 0
            ) _invalid();
            for (uint256 j; j < k; ++j) {
                if (queries[j].collectionId == queries[k].collectionId) _invalid();
            }
        }
    }

    function _collection(AH.Query[] memory queries, bytes32 artistId, uint256 collectionId)
        private
        pure
        returns (uint256)
    {
        for (uint256 k; k < queries.length; ++k) {
            if (queries[k].collectionId != collectionId) continue;
            if (queries[k].artistId != artistId) _invalid();
            return k;
        }
        _invalid();
        return 0;
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
