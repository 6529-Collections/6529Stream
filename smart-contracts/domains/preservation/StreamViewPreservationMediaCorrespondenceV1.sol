// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamPreservationInventoryTypes as T
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import { StreamPreservationInventoryItems as Items } from "./StreamPreservationInventoryItems.sol";

/// @notice Closed VIEW image obligations: raw CID digest or exact attributed Archive locator.
/// @dev HTTPS and Arweave transaction identifiers are not file digests. Their rows contain no
/// digest or size until the fixed VIEW Archive reader authenticates the same original receipt pair.
/// Inline data, arbitrary origin-to-mirror correspondence and Arweave subpaths are not supported.
library StreamViewPreservationMediaCorrespondenceV1 {
    error UnsupportedViewMediaURI(bytes32 uriHash);
    bytes32 internal constant LOCATOR_ROLE = keccak256("VIEW_ARCHIVE_LOCATOR_IMAGE");
    bytes32 internal constant LOCATOR_DOMAIN =
        keccak256("6529STREAM_VIEW_ARCHIVE_LOCATOR_OBLIGATION_V1");

    function item(address source, bytes32 record, string memory uri)
        public
        pure
        returns (T.Item memory row)
    {
        bytes memory raw = bytes(uri);
        if (raw.length == 0) {
            return Items.absent(keccak256("VIEW_OPTIONAL_IMAGE"), source, record, 0);
        }
        if (
            (raw.length >= 8 && bytes8(raw) == bytes8("https://"))
                || (raw.length >= 5 && bytes5(raw) == bytes5("ar://"))
        ) {
            locator(uri);
            row.kind = T.Kind.EXTERNAL_REFERENCE;
            row.role = LOCATOR_ROLE;
            row.source = source;
            row.sourceRecord = record;
            row.canonicalizationId = keccak256("RAW_BYTES");
            row.uri = uri;
            row.provenanceHash = keccak256(abi.encode(LOCATOR_DOMAIN, source, record, uri));
            // algorithm/digest/size stay zero: the exact signed locator is an obligation,
            // not a cryptographic assertion about the file bytes.
            return row;
        }
        bytes32 digest = rawIPFSDigest(uri);
        row.kind = T.Kind.EXTERNAL_REFERENCE;
        row.role = keccak256("VIEW_CONTENT_ADDRESSED_IMAGE");
        row.source = source;
        row.sourceRecord = record;
        row.algorithm = 2;
        row.canonicalizationId = keccak256("RAW_BYTES");
        row.digest = abi.encodePacked(digest);
        row.uri = uri;
        // The CID authenticates the byte digest, not the byte length or availability.
        // Original Bundle coverage supplies a nonzero full length and current archive pair.
    }

    /// @return kind 1 for exact institutional HTTPS, 2 for a canonical 32-byte transaction ID.
    function locator(string memory uri) internal pure returns (uint8 kind, bytes32 transactionId) {
        bytes memory raw = bytes(uri);
        if (raw.length >= 8 && bytes8(raw) == bytes8("https://")) {
            _institutionalIdentifier(raw);
            return (1, 0);
        }
        if (raw.length != 48 || bytes5(raw) != bytes5("ar://")) {
            revert UnsupportedViewMediaURI(keccak256(raw));
        }
        uint256 accumulator;
        uint256 bits;
        uint256 count;
        uint256 decoded;
        for (uint256 i = 5; i < raw.length; ++i) {
            uint8 c = uint8(raw[i]);
            uint256 digit;
            if (c >= 65 && c <= 90) digit = c - 65;
            else if (c >= 97 && c <= 122) digit = c - 71;
            else if (c >= 48 && c <= 57) digit = c + 4;
            else if (c == 45) digit = 62;
            else if (c == 95) digit = 63;
            else revert UnsupportedViewMediaURI(keccak256(raw));
            accumulator = (accumulator << 6) | digit;
            bits += 6;
            if (bits >= 8) {
                bits -= 8;
                decoded = (decoded << 8) | uint8(accumulator >> bits);
                accumulator &= (uint256(1) << bits) - 1;
                ++count;
            }
        }
        if (count != 32 || bits != 2 || accumulator != 0 || decoded == 0) {
            revert UnsupportedViewMediaURI(keccak256(raw));
        }
        return (2, bytes32(decoded));
    }

    // Exactly the original Archive institutional locator grammar, with this profile's error.
    function _institutionalIdentifier(bytes memory raw) private pure {
        if (raw.length < 10 || raw.length > 2048 || bytes8(raw) != bytes8("https://")) {
            revert UnsupportedViewMediaURI(keccak256(raw));
        }
        uint256 hostEnd = raw.length;
        for (uint256 i = 8; i < raw.length; ++i) {
            bytes1 c = raw[i];
            if (c <= 0x20 || c >= 0x7f || c == "@" || c == "#" || c == "\\" || c == "%") {
                revert UnsupportedViewMediaURI(keccak256(raw));
            }
            if (hostEnd == raw.length && c == "/") hostEnd = i;
        }
        if (hostEnd == 8 || hostEnd == raw.length || hostEnd + 1 == raw.length || hostEnd - 8 > 253)
        revert UnsupportedViewMediaURI(keccak256(raw));
        uint256 labelStart = 8;
        for (uint256 i = 8; i <= hostEnd; ++i) {
            if (i == hostEnd || raw[i] == ".") {
                if (
                    i == labelStart || i - labelStart > 63 || raw[labelStart] == "-"
                        || raw[i - 1] == "-"
                ) revert UnsupportedViewMediaURI(keccak256(raw));
                labelStart = i + 1;
                continue;
            }
            bytes1 c = raw[i];
            if (!((c >= "a" && c <= "z") || (c >= "0" && c <= "9") || c == "-")) {
                revert UnsupportedViewMediaURI(keccak256(raw));
            }
        }
    }

    function rawIPFSDigest(string memory uri) internal pure returns (bytes32 result) {
        bytes memory s = bytes(uri);
        if (s.length != 66) revert UnsupportedViewMediaURI(keccak256(s));
        bytes memory prefix = bytes("ipfs://b");
        for (uint256 i; i < 8; ++i) {
            if (s[i] != prefix[i]) revert UnsupportedViewMediaURI(keccak256(s));
        }
        bytes memory decoded = new bytes(36);
        uint256 accumulator;
        uint256 bits;
        uint256 cursor;
        for (uint256 i = 8; i < s.length; ++i) {
            uint8 v = uint8(s[i]);
            uint256 digit;
            if (v >= 97 && v <= 122) digit = v - 97;
            else if (v >= 50 && v <= 55) digit = v - 24;
            else revert UnsupportedViewMediaURI(keccak256(s));
            accumulator = (accumulator << 5) | digit;
            bits += 5;
            if (bits >= 8) {
                bits -= 8;
                if (cursor >= 36) revert UnsupportedViewMediaURI(keccak256(s));
                decoded[cursor++] = bytes1(uint8(accumulator >> bits));
                accumulator &= (uint256(1) << bits) - 1;
            }
        }
        if (
            cursor != 36 || bits != 2 || accumulator != 0 || decoded[0] != 0x01
                || decoded[1] != 0x55 || decoded[2] != 0x12 || decoded[3] != 0x20
        ) revert UnsupportedViewMediaURI(keccak256(s));
        assembly ("memory-safe") { result := mload(add(decoded, 36)) }
        if (result == 0) revert UnsupportedViewMediaURI(keccak256(s));
    }
}
