// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";
import {
    StreamArtistRecoveredMultipleTypes as M
} from "../../interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistRecoveredIdentitySourceFrame as Frame
} from "./StreamArtistRecoveredIdentitySourceFrame.sol";
import {
    StreamArtistRecoveredHydrationChronology as Chronology
} from "./StreamArtistRecoveredHydrationChronology.sol";

/// @notice Complete aggregate operation52 occurrence, subject and original signature joins.
/// @dev The caller authenticates complete canonical Identity frames, provenance, nonce/replay
/// inventories and source records. The original three-word record contains no generation,
/// signer, nonce or timestamp preimage; none is reconstructed from current authority here.
library StreamArtistRecoveredAggregateRatificationFacts {
    uint256 private constant MAX_ROWS = 128;

    function validate(
        bytes[] calldata identities,
        M.State calldata scope,
        RH.Provenance calldata p,
        T.RatificationRecord[][] calldata rows
    ) public pure {
        if (
            identities.length == 0 || identities.length > MAX_ROWS
                || identities.length != scope.artists.length || scope.collections.length == 0
                || scope.collections.length > MAX_ROWS || rows.length != scope.collections.length
        ) _invalid();
        for (uint256 a; a < identities.length; ++a) {
            IH.Bundle calldata identity = Frame.bundle(identities[a]);
            if (identity.artistId == 0 || identity.artistId != scope.artists[a].artistId) {
                _invalid();
            }
            for (uint256 j; j < a; ++j) {
                if (scope.artists[j].artistId == identity.artistId) _invalid();
            }
        }
        uint256[] memory artists = new uint256[](rows.length);
        uint256[] memory counts = new uint256[](rows.length);
        for (uint256 k; k < rows.length; ++k) {
            if (
                scope.collections[k].artistId == 0 || scope.collections[k].collectionId == 0
                    || scope.collections[k].bindingHash == 0 || rows[k].length > MAX_ROWS
            ) _invalid();
            for (uint256 j; j < k; ++j) {
                if (scope.collections[j].collectionId == scope.collections[k].collectionId) {
                    _invalid();
                }
            }
            artists[k] = _artist(scope, scope.collections[k].artistId);
            for (uint256 j; j < rows[k].length; ++j) {
                T.RatificationRecord calldata r = rows[k][j];
                if (
                    r.recordHash == 0 || r.contentStateHash == 0 || r.metadataContract == address(0)
                ) {
                    _invalid();
                }
            }
        }
        for (uint256 i; i < p.journals[6].length; ++i) {
            RH.JournalEntry calldata n = p.journals[6][i];
            if (n.receipt.operation != 52) continue;
            uint256 k = _collection(scope, n.receipt.artistId, n.receipt.collectionId);
            if (
                n.receipt.recordHash == 0 || n.position.point.ownerIndex != 6
                    || counts[k] >= rows[k].length
                    || rows[k][counts[k]++].recordHash != n.receipt.recordHash
            ) _invalid();
            for (uint256 j; j < i; ++j) {
                if (p.journals[6][j].receipt.recordHash == n.receipt.recordHash) _invalid();
            }
            Chronology.validatePoint(p, n.position.point);
            IH.Bundle calldata identity = Frame.bundle(identities[artists[k]]);
            _signature(identity.signatures, n.receipt.recordHash);
        }
        for (uint256 k; k < rows.length; ++k) {
            if (counts[k] != rows[k].length) _invalid();
        }
    }

    function _artist(M.State calldata scope, bytes32 artistId) private pure returns (uint256) {
        for (uint256 a; a < scope.artists.length; ++a) {
            if (scope.artists[a].artistId == artistId) return a;
        }
        _invalid();
        return 0;
    }

    function _collection(M.State calldata scope, bytes32 artistId, uint256 collectionId)
        private
        pure
        returns (uint256)
    {
        for (uint256 k; k < scope.collections.length; ++k) {
            if (scope.collections[k].collectionId != collectionId) continue;
            if (scope.collections[k].artistId != artistId) _invalid();
            return k;
        }
        _invalid();
        return 0;
    }

    function _signature(IH.SignatureRow[] calldata signatures, bytes32 record) private pure {
        bool found;
        for (uint256 i; i < signatures.length; ++i) {
            if (signatures[i].recordHash != record) continue;
            if (found || signatures[i].signature.length > 4096) _invalid();
            found = true;
        }
        // Empty direct/Safe evidence remains valid; source bytes were authenticated earlier.
        if (!found) _invalid();
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
