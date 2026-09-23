// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamViewRetrievalWitnessTypesV1 as W
} from "../../interfaces/stream/preservation/StreamViewRetrievalWitnessTypesV1.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import { StreamViewRetrievalCodecV1 as Codec } from "./StreamViewRetrievalCodecV1.sol";
import {
    StreamViewPreservationMediaCorrespondenceV1 as Original
} from "./StreamViewPreservationMediaCorrespondenceV1.sol";

/// @notice Original absent/raw-CID/exact-locator rows plus closed, complete-source retrieval obligations.
library StreamViewRetrievalObligationV1 {
    function item(W.Source memory s) public pure returns (T.Item memory row) {
        bytes memory u = bytes(s.requestedURI);
        if (u.length == 0 || (u.length >= 7 && bytes7(u) == bytes7("ipfs://"))) {
            return Original.item(s.declaration, s.declarationRecord, s.requestedURI);
        }
        (uint8 kind,) = Codec.uri(s.requestedURI);
        if (kind == 2 || (kind == 1 && _institutional(u))) {
            return Original.item(s.declaration, s.declarationRecord, s.requestedURI);
        }
        row.kind = T.Kind.EXTERNAL_REFERENCE;
        row.role = W.ROLE;
        row.source = s.router;
        row.sourceRecord = s.adoptionRecord;
        row.canonicalizationId = keccak256("RAW_BYTES");
        row.uri = s.requestedURI;
        row.provenanceHash = Codec.sourceKey(s);
        // No digest or size is invented. Only the fixed witness reader may materialize this obligation.
    }

    /// @dev Boolean spelling of the original Archive identifier grammar; original row construction
    /// and original parser remain unchanged. Other valid HTTPS locators require signed retrieval.
    function _institutional(bytes memory raw) private pure returns (bool) {
        if (raw.length < 10 || raw.length > 2048 || bytes8(raw) != bytes8("https://")) return false;
        uint256 hostEnd = raw.length;
        for (uint256 i = 8; i < raw.length; ++i) {
            bytes1 c = raw[i];
            if (c <= 0x20 || c >= 0x7f || c == "@" || c == "#" || c == "\\" || c == "%") return false;
            if (hostEnd == raw.length && c == "/") hostEnd = i;
        }
        if (hostEnd == 8 || hostEnd == raw.length || hostEnd + 1 == raw.length || hostEnd - 8 > 253)
        {
            return false;
        }
        uint256 labelStart = 8;
        for (uint256 i = 8; i <= hostEnd; ++i) {
            if (i == hostEnd || raw[i] == ".") {
                if (
                    i == labelStart || i - labelStart > 63 || raw[labelStart] == "-"
                        || raw[i - 1] == "-"
                ) {
                    return false;
                }
                labelStart = i + 1;
                continue;
            }
            bytes1 c = raw[i];
            if (!((c >= "a" && c <= "z") || (c >= "0" && c <= "9") || c == "-")) return false;
        }
        return true;
    }
}
