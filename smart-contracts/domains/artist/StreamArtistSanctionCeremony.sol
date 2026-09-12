// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistSanctionTypes as S
} from "../../interfaces/stream/artist/StreamArtistSanctionTypes.sol";
import "../../vendor/openzeppelin/Strings.sol";

/// @notice A bounded typed RFC8785 sanction-ceremony profile, not an arbitrary JSON validator.
/// @dev Full-width integers use canonical decimal strings; scopeType is an exact small JSON number.
///      Hashes/addresses use lowercase fixed-width hex. UTF8 is validated without normalization.
library StreamArtistSanctionCeremony {
    function document(S.Subject memory p, S.Ceremony memory c)
        public
        pure
        returns (bytes memory out)
    {
        if (
            bytes(c.statement).length == 0 || bytes(c.statement).length > 2048
                || bytes(c.signingToolName).length == 0 || bytes(c.signingToolName).length > 128
                || bytes(c.signingToolVersion).length == 0
                || bytes(c.signingToolVersion).length > 128 || c.mediaHashes.length > 16
                || c.referenceRenderHashes.length > 16
                || (c.contentRoot == 0 && c.mediaHashes.length == 0) || p.scopeType > 4
        ) revert S.InvalidSanctionCeremony();
        out = bytes.concat(
            '{"contentRoot":"',
            bytes(_hex(c.contentRoot)),
            '","mediaHashes":',
            _hashes(c.mediaHashes),
            ',"referenceRenderHashes":',
            _hashes(c.referenceRenderHashes),
            ',"sanctionSubject":',
            _subject(p),
            ',"schema":"6529STREAM_ARTIST_SANCTION_CEREMONY_V1","signingTool":{"name":',
            _quote(bytes(c.signingToolName)),
            ',"version":',
            _quote(bytes(c.signingToolVersion)),
            '},"statement":',
            _quote(bytes(c.statement)),
            "}"
        );
        if (out.length > 8192) revert S.InvalidSanctionCeremony();
    }

    function _subject(S.Subject memory p) private pure returns (bytes memory out) {
        out = bytes.concat(
            '{"chainId":"',
            bytes(Strings.toString(p.chainId)),
            '","collectionId":"',
            bytes(Strings.toString(p.collectionId)),
            '","core":"',
            bytes(Strings.toHexString(uint160(p.core), 20)),
            '","coreFactsHash":"',
            bytes(_hex(p.coreFactsHash)),
            '","domain":"',
            bytes(_hex(p.domain))
        );
        out = bytes.concat(
            out,
            '","finalityRegistry":"',
            bytes(Strings.toHexString(uint160(p.finalityRegistry), 20)),
            '","manifestCanonicalizationHash":"',
            bytes(_hex(p.manifestCanonicalizationHash)),
            '","manifestContentHash":"',
            bytes(_hex(p.manifestContentHash)),
            '","manifestSchemaId":"',
            bytes(_hex(p.manifestSchemaId)),
            '","manifestURIHash":"',
            bytes(_hex(p.manifestURIHash))
        );
        return bytes.concat(
            out,
            '","nonSanctionComponentsHash":"',
            bytes(_hex(p.nonSanctionComponentsHash)),
            '","scopeId":"',
            bytes(_hex(p.scopeId)),
            '","scopeType":',
            bytes(Strings.toString(p.scopeType)),
            ',"tokenId":"',
            bytes(Strings.toString(p.tokenId)),
            '"}'
        );
    }

    function _hashes(bytes32[] memory values) private pure returns (bytes memory out) {
        out = "[";
        for (uint256 i; i < values.length; ++i) {
            if (values[i] == 0) revert S.InvalidSanctionCeremony();
            out = bytes.concat(
                out, i == 0 ? bytes("") : bytes(","), '"', bytes(_hex(values[i])), '"'
            );
        }
        return bytes.concat(out, "]");
    }

    function _hex(bytes32 value) private pure returns (string memory) {
        return Strings.toHexString(uint256(value), 32);
    }

    function _quote(bytes memory value) private pure returns (bytes memory out) {
        out = new bytes(value.length * 6 + 2);
        uint256 next = 1;
        out[0] = '"';
        bytes16 hexDigits = "0123456789abcdef";
        for (uint256 i; i < value.length; ++i) {
            uint8 c = uint8(value[i]);
            if (c == 34 || c == 92) {
                out[next++] = bytes1(uint8(92));
                out[next++] = value[i];
            } else if (c < 32) {
                out[next++] = bytes1(uint8(92));
                if (c == 8) {
                    out[next++] = "b";
                } else if (c == 9) {
                    out[next++] = "t";
                } else if (c == 10) {
                    out[next++] = "n";
                } else if (c == 12) {
                    out[next++] = "f";
                } else if (c == 13) {
                    out[next++] = "r";
                } else {
                    out[next++] = "u";
                    out[next++] = "0";
                    out[next++] = "0";
                    out[next++] = hexDigits[c >> 4];
                    out[next++] = hexDigits[c & 15];
                }
            } else if (c < 128) {
                out[next++] = value[i];
            } else {
                uint256 length = c >= 194 && c <= 223
                    ? 2
                    : c >= 224 && c <= 239 ? 3 : c >= 240 && c <= 244 ? 4 : 0;
                if (length == 0 || i + length > value.length) revert S.InvalidSanctionCeremony();
                uint8 second = uint8(value[i + 1]);
                if (
                    (c == 224 && second < 160) || (c == 237 && second >= 160)
                        || (c == 240 && second < 144) || (c == 244 && second >= 144)
                ) revert S.InvalidSanctionCeremony();
                out[next++] = value[i];
                for (uint256 j = 1; j < length; ++j) {
                    uint8 continuation = uint8(value[i + j]);
                    if (continuation < 128 || continuation > 191) {
                        revert S.InvalidSanctionCeremony();
                    }
                    out[next++] = value[i + j];
                }
                i += length - 1;
            }
        }
        out[next++] = '"';
        assembly ("memory-safe") { mstore(out, next) }
    }
}
