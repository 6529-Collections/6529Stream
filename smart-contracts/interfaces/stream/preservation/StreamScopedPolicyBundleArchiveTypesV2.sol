// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamFinalityScope } from "../finality/StreamArtworkFinalityTypes.sol";
import {
    StreamPreservationInventoryTypes as Inventory
} from "./StreamPreservationInventoryTypes.sol";

/// @notice Archive evidence for the complete scoped full-policy inventory profile.
/// @dev Original Item, Segment, proof and admission serialization is unchanged. This wrapper
/// is only decoded after the distinct V2 archive capability and profile are authenticated.
library StreamScopedPolicyBundleArchiveTypesV2 {
    bytes32 internal constant PROFILE =
        keccak256("6529STREAM_SCOPED_POLICY_BUNDLE_IMMUTABLE_STOP_AGGREGATE_V2");
    bytes32 internal constant INVENTORY_EVIDENCE_DOMAIN =
        keccak256("6529STREAM_SCOPED_POLICY_RENDER_CRITICAL_EVIDENCE_V2");
    bytes32 internal constant COVERAGE_DOMAIN =
        keccak256("6529STREAM_SCOPED_POLICY_BUNDLE_ARCHIVE_COVERAGE_V2");
    bytes32 internal constant ITEM_DOMAIN =
        keccak256("6529STREAM_SCOPED_POLICY_BUNDLE_COVERED_ITEM_V2");
    bytes32 internal constant REFRESH_DOMAIN =
        keccak256("6529STREAM_SCOPED_POLICY_BUNDLE_REFRESH_V2");
    bytes32 internal constant OBSERVATION_DOMAIN =
        keccak256("6529STREAM_SCOPED_POLICY_BUNDLE_CURRENT_OBSERVATION_V2");

    struct BundleEvidence {
        StreamFinalityScope scope;
        Inventory.BundleEvidence coverage;
    }
}
