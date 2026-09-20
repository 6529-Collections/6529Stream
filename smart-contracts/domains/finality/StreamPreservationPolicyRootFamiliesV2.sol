// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamPreservationPolicyContentRootSchemasV1 as CollectionV1
} from "./StreamPreservationPolicyContentRootSchemasV1.sol";
import {
    StreamPreservationPolicyContentRootSchemasV2 as CollectionV2
} from "./StreamPreservationPolicyContentRootSchemasV2.sol";
import {
    StreamScopedPreservationPolicyContentRootSchemasV1 as ScopedV1
} from "./StreamScopedPreservationPolicyContentRootSchemasV1.sol";
import {
    StreamScopedPreservationPolicyContentRootSchemasV2 as ScopedV2
} from "./StreamScopedPreservationPolicyContentRootSchemasV2.sol";
import {
    StreamPreservationPolicyOutputSchemasV1 as OutputV1
} from "./StreamPreservationPolicyOutputSchemasV1.sol";
import {
    StreamPreservationPolicyOutputSchemasV2 as OutputV2
} from "./StreamPreservationPolicyOutputSchemasV2.sol";

/// @notice Closed root definitions selected by an authenticated preservation family.
/// @dev Selection is not authority: callers must first bind the actual factory, producer and saved
/// plan/manifest. Both families retain the original six-field leaf and original op17 consent store.
library StreamPreservationPolicyRootFamiliesV2 {
    bytes32 internal constant V1 = keccak256("6529STREAM_PRESERVATION_RENDER_V1");
    bytes32 internal constant V2 = keccak256("6529STREAM_TOKEN_PRESERVATION_FAMILY_V2");
    error InvalidPreservationRootFamily();

    function valid(bytes32 family) internal pure returns (bool) {
        return family == V1 || family == V2;
    }

    function _new(bytes32 family) private pure returns (bool) {
        if (!valid(family)) revert InvalidPreservationRootFamily();
        return family == V2;
    }

    function profile(bytes32 family, bool scoped) internal pure returns (bytes32) {
        if (_new(family)) return scoped ? ScopedV2.PROFILE : CollectionV2.PROFILE;
        return scoped ? ScopedV1.PROFILE : CollectionV1.PROFILE;
    }

    function checkpointProfile(bytes32 family, bool scoped) internal pure returns (bytes32) {
        if (_new(family)) {
            return scoped
                ? keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_CONTENT_CHECKPOINT_V2")
                : keccak256("6529STREAM_PRESERVATION_POLICY_CONTENT_CHECKPOINT_V2");
        }
        return scoped
            ? keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_CONTENT_V1")
            : keccak256("6529STREAM_PRESERVATION_POLICY_CONTENT_V1");
    }

    function outputProfile(bytes32 family, bool scoped) internal pure returns (bytes32) {
        return _new(family)
            ? keccak256("6529STREAM_PRESERVATION_POLICY_OUTPUT_MANIFEST_V2")
            : checkpointProfile(family, scoped);
    }

    function recordDomain(bytes32 family, bool scoped) internal pure returns (bytes32) {
        if (_new(family)) {
            return scoped
                ? keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_CONTENT_ROOT_RECORD_V2")
                : keccak256("6529STREAM_PRESERVATION_POLICY_CONTENT_ROOT_RECORD_V2");
        }
        return scoped
            ? keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_CONTENT_ROOT_RECORD_V1")
            : keccak256("6529STREAM_PRESERVATION_POLICY_CONTENT_ROOT_RECORD_V1");
    }

    function stateDomain(bytes32 family, bool scoped) internal pure returns (bytes32) {
        if (_new(family)) {
            return scoped
                ? keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_CONTENT_ROOT_STATE_V2")
                : keccak256("6529STREAM_PRESERVATION_POLICY_CONTENT_ROOT_STATE_V2");
        }
        return scoped
            ? keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_CONTENT_ROOT_STATE_V1")
            : keccak256("6529STREAM_PRESERVATION_POLICY_CONTENT_ROOT_STATE_V1");
    }

    function routeDomain(bytes32 family, bool scoped) internal pure returns (bytes32) {
        if (_new(family)) {
            return scoped
                ? keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_CONTENT_ROOT_ROUTE_V2")
                : keccak256("6529STREAM_PRESERVATION_POLICY_CONTENT_ROOT_ROUTE_V2");
        }
        return scoped
            ? keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_CONTENT_ROOT_ROUTE_V1")
            : keccak256("6529STREAM_PRESERVATION_POLICY_CONTENT_ROOT_ROUTE_V1");
    }

    function ids(bytes32 family, bool scoped) internal pure returns (bytes32[5] memory result) {
        if (_new(family)) {
            return [
                OutputV2.SCHEMA,
                OutputV2.CANON,
                OutputV1.LEAF_SCHEMA,
                scoped ? ScopedV2.ROOT_SCHEMA : CollectionV2.ROOT_SCHEMA,
                scoped ? ScopedV2.ROOT_CANON : CollectionV2.ROOT_CANON
            ];
        }
        return [
            OutputV1.SCHEMA,
            OutputV1.CANON,
            OutputV1.LEAF_SCHEMA,
            scoped ? ScopedV1.ROOT_SCHEMA : CollectionV1.ROOT_SCHEMA,
            scoped ? ScopedV1.ROOT_CANON : CollectionV1.ROOT_CANON
        ];
    }

    function document(bytes32 family, bool scoped, bytes32 id) public pure returns (bytes memory) {
        if (_new(family)) return scoped ? ScopedV2.document(id) : CollectionV2.document(id);
        return scoped ? ScopedV1.document(id) : CollectionV1.document(id);
    }

    function definitionHash(bytes32 family, bool scoped, bytes32 id) public pure returns (bytes32) {
        return keccak256(document(family, scoped, id));
    }
}
