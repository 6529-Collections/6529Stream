// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistPersonhoodTypes as P
} from "../../interfaces/stream/artist/IStreamArtistPersonhoodEvidence.sol";
import { StreamRecordJson as JSON } from "../records/StreamRecordJson.sol";
import "./StreamArtistPersonhoodDefinitions.sol";

/// @notice Closed fixed-key JSON interpretation of the original native evidence schema.
/// @dev No existing schema bytes, signed statement, record hash or authority are rewritten.
library StreamArtistPersonhoodJSON {
    function encode(P.Reference memory p) public pure returns (bytes memory) {
        if (!_valid(p)) revert P.InvalidPersonhoodReference();
        return bytes(
            string.concat(
                '{"artistId":',
                JSON.hexValue(p.artistId),
                ',"artistRegistry":',
                JSON.account(p.artistRegistry),
                ',"notarizationHost":',
                JSON.account(p.notarizationHost),
                ',"notarizationRecordHash":',
                JSON.hexValue(p.notarizationRecordHash),
                ',"notarizationRuntimeHash":',
                JSON.hexValue(p.notarizationRuntimeHash),
                ',"operativeIdentityRecordHash":',
                JSON.hexValue(p.operativeIdentityRecordHash),
                ',"profileHash":',
                JSON.hexValue(p.profileHash),
                ',"version":1}'
            )
        );
    }

    function decode(bytes memory raw) public pure returns (P.Reference memory p) {
        bool valid;
        (valid, p) = tryDecode(raw);
        if (!valid) revert P.InvalidPersonhoodReference();
    }

    /// @notice Legacy opaque statements remain readable as unresolved evidence.
    function tryDecode(bytes memory raw) public pure returns (bool valid, P.Reference memory p) {
        // Offsets are generated from the literal fixed-key shape; re-encoding checks every byte.
        if (raw.length != 590) return (false, p);
        uint256[7] memory offsets = [uint256(15), 101, 165, 235, 330, 429, 512];
        for (uint256 field; field < 7; ++field) {
            uint256 length = field == 1 || field == 2 ? 40 : 64;
            for (uint256 i; i < length; ++i) {
                uint8 digit = uint8(raw[offsets[field] + i]);
                if (!((digit >= 48 && digit <= 57) || (digit >= 97 && digit <= 102))) {
                    return (false, p);
                }
            }
        }
        p.version = 1;
        p.artistId = bytes32(_hex(raw, 15, 32));
        p.artistRegistry = address(uint160(_hex(raw, 101, 20)));
        p.notarizationHost = address(uint160(_hex(raw, 165, 20)));
        p.notarizationRecordHash = bytes32(_hex(raw, 235, 32));
        p.notarizationRuntimeHash = bytes32(_hex(raw, 330, 32));
        p.operativeIdentityRecordHash = bytes32(_hex(raw, 429, 32));
        p.profileHash = bytes32(_hex(raw, 512, 32));
        valid = _valid(p);
        if (valid) valid = keccak256(raw) == keccak256(encode(p));
    }

    function _valid(P.Reference memory p) private pure returns (bool) {
        return p.version == 1 && p.profileHash == StreamArtistPersonhoodDefinitions.PROFILE_HASH
            && p.artistRegistry != address(0) && p.artistId != 0
            && p.operativeIdentityRecordHash != 0 && p.notarizationHost != address(0)
            && p.notarizationRuntimeHash != 0 && p.notarizationRecordHash != 0;
    }

    function _hex(bytes memory raw, uint256 offset, uint256 length)
        private
        pure
        returns (uint256 value)
    {
        for (uint256 i; i < length * 2; ++i) {
            uint8 digit = uint8(raw[offset + i]);
            if (digit >= 48 && digit <= 57) digit -= 48;
            else if (digit >= 97 && digit <= 102) digit -= 87;
            else revert P.InvalidPersonhoodReference();
            value = (value << 4) | digit;
        }
    }
}
