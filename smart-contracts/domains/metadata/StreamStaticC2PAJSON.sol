// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamC2PAReconciliation as C
} from "../../interfaces/stream/metadata/IStreamC2PAReconciliation.sol";
import { Strings } from "../../vendor/openzeppelin/Strings.sol";

/// @notice Closed typed fields only; no supplied report text enters JSON.
library StreamStaticC2PAJSON {
    using Strings for uint256;

    function fields(C.Display memory d, bytes32 subject, bool unavailable)
        internal
        pure
        returns (bytes memory)
    {
        if (d.recordHash == 0 && !unavailable) return "";
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
            d.authorship == C.AuthorshipStatus.DIVERGENT
                ? "true"
                : d.authorship == C.AuthorshipStatus.CONSISTENT ? "false" : "null",
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
