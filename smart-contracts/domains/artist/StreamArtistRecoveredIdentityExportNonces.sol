// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";

import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    IStreamArtistAuthorityCheckpoint as CP
} from "../../interfaces/stream/artist/IStreamArtistAuthorityCheckpoint.sol";

import {
    StreamArtistRecoveredIdentityHydrationState as X
} from "./StreamArtistRecoveredIdentityHydrationState.sol";

import {
    StreamArtistRecoveredIdentitySourceFrame as Frame
} from "./StreamArtistRecoveredIdentitySourceFrame.sol";

/// @notice Fixed Identity export stage in the original owner storage context.
library StreamArtistRecoveredIdentityExportNonces {
    function collect(uint256[17] memory r, bytes calldata canonical)
        public
        view
        returns (bytes memory)
    {
        IH.Bundle calldata b = Frame.bundle(canonical);
        CP owner = CP(address(this));
        uint256 all = owner.authorityCheckpoint().nonceIndexCount;
        if (all > RH.MAX_NONCE_INDICES) revert IH.InvalidRecoveredIdentity(b.artistId);
        IH.NonceLane[] memory rows = new IH.NonceLane[](all);
        uint256 count;
        for (uint256 i; i < all; ++i) {
            CP.NonceIndex memory index = owner.authorityNonceIndexAt(i);
            if (!_lane(b, index.kind, index.key)) continue;
            if (index.prefixCount == 0 || index.prefixCount > RH.MAX_NONCE_PREFIXES) {
                revert IH.InvalidRecoveredIdentity(index.key);
            }
            IH.NonceLane memory row;
            row.kind = index.kind;
            row.key = index.key;
            if (index.kind == 1) row.hint = b.identity.nonceHint;
            else if (index.kind == 2) row.hint = X.delegations(r).hints[index.key];
            else if (index.kind == 4) row.hint = X.rotations(r).acceptanceHint[index.key];
            else row.hint = X.estate(r).nonceHints[index.key];
            row.words = new AH.NonceWord[](index.prefixCount);
            for (uint256 j; j < index.prefixCount; ++j) {
                (row.words[j].prefix, row.words[j].words, row.words[j].exhausted) =
                    owner.authorityNonceWordAt(index.kind, index.key, j);
            }
            rows[count++] = row;
        }
        assembly ("memory-safe") { mstore(rows, count) }
        return abi.encode(rows);
    }

    function _lane(IH.Bundle calldata b, uint8 kind, bytes32 key) private pure returns (bool) {
        if (kind == 1) return key == b.artistId;
        if (kind == 2) {
            for (uint256 i; i < b.delegations.length; ++i) {
                if (
                    key
                        == keccak256(
                            abi.encode(
                                keccak256("6529STREAM_ARTIST_DELEGATE_NONCE_LANE_V1"),
                                b.artistId,
                                b.delegations[i].record.grant.delegate
                            )
                        )
                ) {
                    return true;
                }
            }
        }
        if (kind == 4) {
            for (uint256 i; i < b.rotations.length; ++i) {
                if (
                    key
                        == keccak256(
                            abi.encode(
                                keccak256("rotation_acceptance"),
                                b.artistId,
                                b.rotations[i].record.terms.newAddress
                            )
                        )
                ) return true;
            }
            for (uint256 i; i < b.recoveries.length; ++i) {
                if (
                    key
                        == keccak256(
                            abi.encode(
                                keccak256("rotation_acceptance"),
                                b.artistId,
                                b.recoveries[i].record.terms.newAddress
                            )
                        )
                ) return true;
            }
        }
        if (kind == 5) {
            for (uint256 i; i < b.estates.length; ++i) {
                if (
                    key
                        == keccak256(
                            abi.encode(
                                "estate_activation",
                                b.artistId,
                                b.estates[i].request.terms.successor
                            )
                        )
                ) return true;
            }
        }
        return false;
    }
}
