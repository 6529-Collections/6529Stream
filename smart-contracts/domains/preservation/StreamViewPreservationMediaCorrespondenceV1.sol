// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamPreservationInventoryTypes as T
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import { StreamPreservationInventoryItems as Items } from "./StreamPreservationInventoryItems.sol";

/// @notice Only a canonical raw IPFS CID authenticates the referenced complete file digest here.
/// @dev DAG-PB digests and Arweave transaction IDs are not file digests. HTTPS needs a separate
/// authorized observation profile. Original VIEW admission does not admit inline data URIs.
library StreamViewPreservationMediaCorrespondenceV1 {
    error UnsupportedViewMediaURI(bytes32 uriHash);

    function item(address source, bytes32 record, string memory uri)
        public
        pure
        returns (T.Item memory row)
    {
        bytes memory raw = bytes(uri);
        if (raw.length == 0) {
            return Items.absent(keccak256("VIEW_OPTIONAL_IMAGE"), source, record, 0);
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
