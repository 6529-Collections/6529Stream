// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamPreservationInventoryTypes as T
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";

/// @notice Closed byte-correspondence vocabulary for native compiler-ABI inventory payloads.
/// @dev The fixed inventory producer authenticates the original publication's schema/profile/
/// canonicalization documents and commits each complete item into its ordered segment. This
/// matcher does not establish that authority, decode a publication, or confer archive coverage.
/// Item has no separate profile field: each pair below belongs to the exact original profile
/// checked by its producer. Never accept a canonicalization ID independently of role and schema.
library StreamInventoryAbiCorrespondence {
    function supported(T.Item memory item) internal pure returns (bool) {
        // The original Artist intent retains this HashRef without a declared size/schema.
        // CURATED assessment binds it to abi.encode(properties), using Keccak or SHA-256.
        // It remains an external-reference obligation, separately from the complete native row.
        if (item.kind == T.Kind.EXTERNAL_REFERENCE) {
            return item.role == keccak256("SIGNIFICANT_PROPERTIES") && item.sourceIndex == 8
                && item.schemaId == 0 && item.byteSize == 0
                && item.canonicalizationId == keccak256("STREAM_SOLIDITY_ABI_V1")
                && (item.algorithm == 1 || item.algorithm == 2);
        }
        if (item.algorithm != 1 || item.byteSize == 0) return false;
        bytes32 role = item.role;
        bytes32 schema = item.schemaId;
        bytes32 canon = item.canonicalizationId;
        if (item.kind == T.Kind.NATIVE_BYTES) {
            // StreamReferenceModeInventory / StreamReferenceMetricInventory authenticate
            // these complete native ABI values under their respective original profiles.
            return canon == keccak256("STREAM_SOLIDITY_ABI_V1")
                && ((role == keccak256("COMPLETE_SIGNIFICANT_PROPERTIES")
                        && schema == keccak256("STREAM_REFERENCE_SIGNIFICANT_PROPERTIES_ABI_V1"))
                    || (role == keccak256("METRIC_SUPPLEMENT_PAYLOAD")
                        && schema == keccak256("STREAM_REFERENCE_METRIC_SUPPLEMENT_ABI_V1")));
        }
        if (item.kind != T.Kind.ORIGINAL_PAYLOAD) return false;
        if (canon == keccak256("STREAM_SOLIDITY_ABI_V1")) {
            return (role == keccak256("REFERENCE_MANIFEST")
                    && schema == keccak256("STREAM_REFERENCE_MODE_ABI_V1"))
                || (role == keccak256("CURATED_CONDITION_ORIGINAL_PAYLOAD")
                    && schema == keccak256("STREAM_REFERENCE_CURATED_CONDITION_ABI_V1"))
                || (role == keccak256("SCOPED_SNAPSHOT_MANIFEST")
                    && schema == keccak256("STREAM_SCOPED_STATIC_SNAPSHOT_ABI_V1"))
                || (role == keccak256("SCOPED_REFERENCE_MANIFEST")
                    && schema == keccak256("STREAM_SCOPED_REFERENCE_RENDER_ABI_V1"));
        }
        if (role == keccak256("POLICY_SNAPSHOT_MANIFEST_V2")) {
            return (schema == keccak256("STREAM_POLICY_COLLECTION_SNAPSHOT_ABI_V2")
                    && canon == keccak256("STREAM_ABI_POLICY_COLLECTION_SNAPSHOT_V2"))
                || (schema == keccak256("STREAM_PRESERVATION_POLICY_COLLECTION_SNAPSHOT_ABI_V1")
                    && canon == keccak256("STREAM_ABI_PRESERVATION_POLICY_COLLECTION_SNAPSHOT_V1"))
                || (schema == keccak256("STREAM_PRESERVATION_POLICY_COLLECTION_SNAPSHOT_ABI_V2")
                    && canon == keccak256("STREAM_ABI_PRESERVATION_POLICY_COLLECTION_SNAPSHOT_V2"));
        }
        if (role == keccak256("REFERENCE_MANIFEST")) {
            return (schema == keccak256("STREAM_POLICY_COLLECTION_REFERENCE_ABI_V2")
                    && canon == keccak256("STREAM_ABI_POLICY_COLLECTION_REFERENCE_V2"))
                || (schema == keccak256("STREAM_PRESERVATION_POLICY_COLLECTION_REFERENCE_ABI_V1")
                    && canon == keccak256("STREAM_ABI_PRESERVATION_POLICY_COLLECTION_REFERENCE_V1"))
                || (schema == keccak256("STREAM_PRESERVATION_POLICY_COLLECTION_REFERENCE_ABI_V2")
                    && canon == keccak256("STREAM_ABI_PRESERVATION_POLICY_COLLECTION_REFERENCE_V2"));
        }
        if (role == keccak256("SCOPED_POLICY_SNAPSHOT_MANIFEST_V2")) {
            return (schema == keccak256("STREAM_SCOPED_POLICY_SNAPSHOT_ABI_V2")
                    && canon == keccak256("STREAM_ABI_SCOPED_POLICY_SNAPSHOT_V2"))
                || (schema == keccak256("STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_ABI_V1")
                    && canon == keccak256("STREAM_ABI_SCOPED_PRESERVATION_POLICY_SNAPSHOT_V1"))
                || (schema == keccak256("STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_ABI_V2")
                    && canon == keccak256("STREAM_ABI_SCOPED_PRESERVATION_POLICY_SNAPSHOT_V2"));
        }
        return (role == keccak256("SCOPED_POLICY_REFERENCE_MANIFEST")
                && schema == keccak256("STREAM_SCOPED_POLICY_REFERENCE_ABI_V2")
                && canon == keccak256("STREAM_ABI_SCOPED_POLICY_REFERENCE_V2"))
            || (role == keccak256("SCOPED_PRESERVATION_POLICY_REFERENCE_MANIFEST")
                && schema == keccak256("STREAM_SCOPED_PRESERVATION_POLICY_REFERENCE_ABI_V1")
                && canon == keccak256("STREAM_ABI_SCOPED_PRESERVATION_POLICY_REFERENCE_V1"))
            || (role == keccak256("SCOPED_PRESERVATION_POLICY_REFERENCE_MANIFEST")
                && schema == keccak256("STREAM_SCOPED_PRESERVATION_POLICY_REFERENCE_ABI_V2")
                && canon == keccak256("STREAM_ABI_SCOPED_PRESERVATION_POLICY_REFERENCE_V2"));
    }
}
