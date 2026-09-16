// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamReferenceMetricTypes as T } from "./StreamReferenceMetricTypes.sol";

/// @notice Once-only supplement to an original mode reference, under its actual writer authority.
interface IStreamReferenceMetricSupplement {
    function publishMetricSupplement(bytes32 referenceRecordHash, T.Supplement calldata supplement)
        external
        returns (bytes32 supplementHash);
    function metricSupplement(bytes32 referenceRecordHash)
        external
        view
        returns (bytes memory canonical, T.Receipt memory receipt);
    function requireMetricSupplement(bytes32 referenceRecordHash)
        external
        view
        returns (T.Receipt memory receipt);
    event ReferenceMetricSupplementPublished(
        uint16 schemaVersion,
        bytes32 indexed referenceRecordHash,
        bytes32 indexed supplementHash,
        T.Receipt receipt
    );
}
