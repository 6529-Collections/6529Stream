// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredSanctionHistoryTypes as H
} from "./StreamArtistRecoveredSanctionHistoryTypes.sol";
import {
    StreamArtistRecoveredMultipleTypes as M
} from "../../interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredHydrationCodec as Envelope
} from "./StreamArtistRecoveredHydrationCodec.sol";

/// @notice Additive owner4 carrier preserving each original G/MD/PC Attribution tuple.
/// @dev The complete global sanction certificate occurs once, beside the first original row.
library StreamArtistRecoveredAggregateSanctionAttributionTransport {
    bytes32 internal constant SCHEMA =
        keccak256("6529STREAM_ARTIST_AGGREGATE_SANCTION_ATTRIBUTION_V1");

    function encode(bytes[] memory rows, H.Inventory memory history)
        public
        pure
        returns (bytes[] memory)
    {
        if (rows.length == 0 || rows.length > 128 || history.sanctions.length == 0) _invalid();
        for (uint256 i; i < rows.length; ++i) {
            if (selected(rows[i])) _invalid();
        }
        rows[0] = abi.encode(SCHEMA, RH.VERSION, rows[0], history);
        return rows;
    }

    function decode(M.State memory scope)
        public
        pure
        returns (M.State memory original, H.Inventory memory history)
    {
        if (scope.rows.length == 0 || scope.rows.length > 128) _invalid();
        original = M.State(scope.artists, scope.collections, new bytes[](scope.rows.length));
        for (uint256 i; i < scope.rows.length; ++i) {
            original.rows[i] = scope.rows[i];
            if (!selected(scope.rows[i])) continue;
            if (i != 0) _invalid();
            bytes32 tag;
            uint16 version;
            bytes memory raw;
            (tag, version, raw, history) =
                abi.decode(scope.rows[i], (bytes32, uint16, bytes, H.Inventory));
            if (
                version != RH.VERSION || history.sanctions.length == 0
                    || history.operations.length == 0 || history.catalogues.length == 0
                    || selected(raw)
                    || keccak256(scope.rows[i]) != keccak256(abi.encode(tag, version, raw, history))
            ) _invalid();
            original.rows[i] = raw;
        }
    }

    function requireFeature(bytes[] memory rows, bytes memory outer) public pure {
        RH.Envelope memory e = Envelope.decode(outer, 4);
        if (
            rows.length == 0
                || selected(rows[0]) != ((e.header.requiredFeatures & RH.SANCTION_HISTORY) != 0)
        ) {
            _invalid();
        }
    }

    function selected(bytes memory raw) internal pure returns (bool) {
        bytes32 tag;
        if (raw.length >= 32) {
            assembly ("memory-safe") { tag := mload(add(raw, 32)) }
        }
        return tag == SCHEMA;
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
