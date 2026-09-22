// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredPayoutTypes as P
} from "../../interfaces/stream/artist/StreamArtistRecoveredPayoutTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistRotationTypes as R
} from "../../interfaces/stream/artist/StreamArtistRotationTypes.sol";

import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";

import {
    StreamArtistRecoveredHydrationOwnerPayload as Payload
} from "./StreamArtistRecoveredHydrationOwnerPayload.sol";
import {
    StreamArtistRecoveredHydrationState as Imported
} from "./StreamArtistRecoveredHydrationState.sol";
import {
    StreamArtistRecoveredPayoutHydration as Codec
} from "./StreamArtistRecoveredPayoutHydration.sol";
import {
    StreamArtistRecoveredPayoutImport as Import
} from "./StreamArtistRecoveredPayoutImport.sol";
import { StreamArtistPayoutRecoveryState as Recovery } from "./StreamArtistPayoutRecoveryState.sol";

import {
    StreamArtistUnboundPlatformCodec as Aggregate
} from "./StreamArtistUnboundPlatformCodec.sol";
import {
    StreamArtistRecoveredMultipleTypes as M
} from "../../interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";

import {
    StreamArtistUnboundPlatformCollectionRows as Rows
} from "./StreamArtistUnboundPlatformCollectionRows.sol";

/// @notice Whole-owner payload with each original typed Payout import in canonical Artist order.
library StreamArtistUnboundPlatformPayoutImport {
    bytes32 internal constant CONTINUATION =
        keccak256("payout_lifecycle.hydration.continuation_v3");

    function importState(uint256[6] memory roots, AH.Query memory query, bytes memory raw) public {
        (M.State memory s, Payload.Payload memory payload) = Aggregate.outer(5, query, raw);
        if (s.artists.length == 0) Rows.empty(payload.provenance, 5);
        for (uint256 row; row < s.rows.length; ++row) {
            P.Bundle memory bundle = Codec.decodeLocal(s.rows[row], payload.provenance);
            Import.importState(
                _payouts(roots[0]),
                _records(roots[1]),
                _payouts(roots[2]),
                _associations(roots[3]),
                _hashes(roots[4]),
                _recovery(roots[5]),
                s.artists[row].artistId,
                s.rows[row],
                payload.provenance
            );
            bytes32 nativeKind = keccak256(
                abi.encode(keccak256("6529STREAM_ARTIST_RECOVERED_NATIVE_RECORD_V1"), uint16(18))
            );
            for (uint256 i; i < bundle.records.length; ++i) {
                Imported.installArtifact(
                    nativeKind,
                    bundle.records[i].original.recordHash,
                    bundle.records[i].position.point
                );
            }
            for (uint256 i; i < bundle.continuations.length; ++i) {
                Imported.installArtifact(
                    CONTINUATION,
                    bundle.continuations[i].continuation.continuationHash,
                    bundle.continuations[i].point
                );
            }
        }
    }

    function _payouts(uint256 root) private pure returns (mapping(bytes32 => T.Payout) storage s) {
        assembly ("memory-safe") { s.slot := root }
    }

    function _records(uint256 root)
        private
        pure
        returns (mapping(bytes32 => T.PayoutDesignation) storage s)
    {
        assembly ("memory-safe") { s.slot := root }
    }

    function _associations(uint256 root)
        private
        pure
        returns (mapping(bytes32 => R.ProvisionalAssociation) storage s)
    {
        assembly ("memory-safe") { s.slot := root }
    }

    function _hashes(uint256 root) private pure returns (mapping(bytes32 => bytes32) storage s) {
        assembly ("memory-safe") { s.slot := root }
    }

    function _recovery(uint256 root) private pure returns (Recovery.State storage s) {
        assembly ("memory-safe") { s.slot := root }
    }
}
