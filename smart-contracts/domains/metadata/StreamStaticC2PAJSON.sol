// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamC2PAReconciliation as C
} from "../../interfaces/stream/metadata/IStreamC2PAReconciliation.sol";
import { Strings } from "../../vendor/openzeppelin/Strings.sol";
import {
    IStreamC2PAConflicts as F
} from "../../interfaces/stream/metadata/IStreamC2PAConflicts.sol";

/// @notice Closed typed fields only; no supplied report text enters JSON.
library StreamStaticC2PAJSON {
    using Strings for uint256;

    function fields(C.Display memory d, bytes32 subject, bool unavailable)
        internal
        pure
        returns (bytes memory)
    {
        if (d.recordHash == 0 && !unavailable) return "";
        uint8 divergence = !d.current
            ? 2
            : d.authorship == C.AuthorshipStatus.DIVERGENT
                ? 1
                : d.authorship == C.AuthorshipStatus.CONSISTENT ? 0 : 2;
        return _fields(d, subject, unavailable, divergence);
    }

    function withConflicts(
        C.Display memory d,
        bytes32 subject,
        bool unavailable,
        F.Standing memory token,
        F.Standing memory collection,
        bool conflictUnavailable
    ) internal pure returns (bytes memory) {
        if (
            d.recordHash == 0 && !unavailable && !conflictUnavailable && token.revision == 0
                && collection.revision == 0
        ) return "";
        bool standing = token.unresolvedCount != 0 || collection.unresolvedCount != 0;
        uint8 divergence = standing ? 1 : conflictUnavailable ? 2 : 0;
        // A positive current report remains adverse even when the independent conflict read fails.
        if (conflictUnavailable && d.current && d.authorship == C.AuthorshipStatus.DIVERGENT) {
            divergence = 1;
        }
        return abi.encodePacked(
            _fields(d, subject, unavailable, divergence),
            ',"c2pa_conflict_read_unavailable":',
            conflictUnavailable ? "true" : "false",
            ',"c2pa_conflict_state":"',
            conflictUnavailable
                ? "unavailable"
                : standing
                    ? "standing"
                    : token.revision != 0 || collection.revision != 0 ? "acknowledged" : "none",
            '"',
            _conflictFields("token", token),
            _conflictFields("collection", collection)
        );
    }

    function _conflictFields(string memory scope, F.Standing memory v)
        private
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            ',"c2pa_',
            scope,
            '_conflict":"',
            uint256(v.conflictId).toHexString(32),
            '","c2pa_',
            scope,
            '_divergence_record":"',
            uint256(v.recordHash).toHexString(32),
            '","c2pa_',
            scope,
            '_conflict_chain":"',
            uint256(v.chainHash).toHexString(32),
            '","c2pa_',
            scope,
            '_unresolved_count":"',
            uint256(v.unresolvedCount).toString(),
            '"'
        );
    }

    function _fields(C.Display memory d, bytes32 subject, bool unavailable, uint8 divergence)
        private
        pure
        returns (bytes memory)
    {
        if (!d.current) {
            d.validation = C.ValidationStatus.UNEVALUATED;
            d.authorship = C.AuthorshipStatus.UNEVALUATED;
        }
        return abi.encodePacked(
            ',"c2pa_validation_status":"',
            d.validation == C.ValidationStatus.VALID
                ? "valid"
                : d.validation == C.ValidationStatus.INVALID ? "invalid" : "unevaluated",
            '","c2pa_authorship_status":"',
            d.authorship == C.AuthorshipStatus.CONSISTENT
                ? "consistent"
                : d.authorship == C.AuthorshipStatus.DIVERGENT ? "divergent" : "unevaluated",
            '","c2pa_attribution_divergence":',
            divergence == 1 ? "true" : divergence == 0 ? "false" : "null",
            ',"c2pa_basis":"selected_verifier_report","c2pa_report_current":',
            d.current ? "true" : "false",
            ',"c2pa_read_unavailable":',
            unavailable ? "true" : "false",
            ',"c2pa_record":"',
            uint256(d.recordHash).toHexString(32),
            '","c2pa_subject":"',
            uint256(subject).toHexString(32),
            '"'
        );
    }
}
