// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamPreservationTokenProducerProfilesV1 as P
} from "../../interfaces/stream/finality/StreamPreservationTokenProducerProfilesV1.sol";
import {
    StreamPreservationPolicyReferenceDefinitionsV1 as C1
} from "../records/StreamPreservationPolicyReferenceDefinitionsV1.sol";
import {
    StreamPreservationPolicyReferenceDefinitionsV2 as C2
} from "../records/StreamPreservationPolicyReferenceDefinitionsV2.sol";
import {
    StreamScopedPreservationPolicyReferenceDefinitionsV1 as S1
} from "../records/StreamScopedPreservationPolicyReferenceDefinitionsV1.sol";
import {
    StreamScopedPreservationPolicyReferenceDefinitionsV2 as S2
} from "../records/StreamScopedPreservationPolicyReferenceDefinitionsV2.sol";

/// @notice Closed reference interpretation selected by a host constructor or authenticated consumer.
/// @dev The family marker is not a per-token producer profile and never grants source authority.
library StreamPreservationPolicyReferenceFamiliesV2 {
    struct Definition {
        bytes32 schemaId;
        bytes32 profileId;
        bytes32 canonId;
        bytes32 schemaHash;
        bytes32 profileHash;
        bytes32 canonHash;
        uint32 schemaBytes;
        uint32 profileBytes;
        uint32 canonBytes;
    }
    error InvalidPreservationReferenceFamily();

    function isV2(bytes32 family) internal pure returns (bool) {
        if (family != P.ORIGINAL_PROFILE && family != P.FAMILY_PROFILE) {
            revert InvalidPreservationReferenceFamily();
        }
        return family == P.FAMILY_PROFILE;
    }

    function definition(bytes32 family, bool scoped) internal pure returns (Definition memory) {
        if (isV2(family)) {
            if (scoped) {
                return Definition(
                    S2.SCHEMA_ID,
                    S2.PROFILE_ID,
                    S2.CANON_ID,
                    S2.SCHEMA_HASH,
                    S2.PROFILE_HASH,
                    S2.CANON_HASH,
                    S2.SCHEMA_BYTES,
                    S2.PROFILE_BYTES,
                    S2.CANON_BYTES
                );
            }
            return Definition(
                C2.SCHEMA_ID,
                C2.PROFILE_ID,
                C2.CANON_ID,
                C2.SCHEMA_HASH,
                C2.PROFILE_HASH,
                C2.CANON_HASH,
                C2.SCHEMA_BYTES,
                C2.PROFILE_BYTES,
                C2.CANON_BYTES
            );
        }
        if (scoped) {
            return Definition(
                S1.SCHEMA_ID,
                S1.PROFILE_ID,
                S1.CANON_ID,
                S1.SCHEMA_HASH,
                S1.PROFILE_HASH,
                S1.CANON_HASH,
                S1.SCHEMA_BYTES,
                S1.PROFILE_BYTES,
                S1.CANON_BYTES
            );
        }
        return Definition(
            C1.SCHEMA_ID,
            C1.PROFILE_ID,
            C1.CANON_ID,
            C1.SCHEMA_HASH,
            C1.PROFILE_HASH,
            C1.CANON_HASH,
            C1.SCHEMA_BYTES,
            C1.PROFILE_BYTES,
            C1.CANON_BYTES
        );
    }

    function profile(bytes32 family, bool scoped) internal pure returns (bytes32) {
        if (isV2(family)) {
            return scoped
                ? keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_REFERENCE_V2")
                : keccak256("6529STREAM_PRESERVATION_POLICY_REFERENCE_V2");
        }
        return scoped
            ? keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_REFERENCE_V1")
            : keccak256("6529STREAM_PRESERVATION_POLICY_REFERENCE_V1");
    }

    function moduleVersion(bytes32 family, bool scoped) internal pure returns (bytes32) {
        if (isV2(family)) {
            return scoped
                ? keccak256("STREAM_SCOPED_PRESERVATION_POLICY_REFERENCE_RENDER_IMPLEMENTATION_V2")
                : keccak256("STREAM_PRESERVATION_POLICY_REFERENCE_RENDER_IMPLEMENTATION_V2");
        }
        return scoped
            ? keccak256("STREAM_SCOPED_PRESERVATION_POLICY_REFERENCE_RENDER_IMPLEMENTATION_V1")
            : keccak256("STREAM_PRESERVATION_POLICY_REFERENCE_RENDER_IMPLEMENTATION_V1");
    }

    function payloadDomain(bytes32 family, bool scoped) internal pure returns (bytes32) {
        if (isV2(family)) {
            return scoped
                ? keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_REFERENCE_PAYLOAD_V2")
                : keccak256("6529STREAM_PRESERVATION_POLICY_REFERENCE_PAYLOAD_V2");
        }
        return scoped
            ? keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_REFERENCE_PAYLOAD_V1")
            : keccak256("6529STREAM_PRESERVATION_POLICY_REFERENCE_PAYLOAD_V1");
    }

    function sourceDomain(bytes32 family, bool scoped) internal pure returns (bytes32) {
        if (isV2(family)) {
            return scoped
                ? keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_REFERENCE_SOURCES_V2")
                : keccak256("6529STREAM_PRESERVATION_POLICY_REFERENCE_SOURCES_V2");
        }
        return scoped
            ? keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_REFERENCE_SOURCES_V1")
            : keccak256("6529STREAM_PRESERVATION_POLICY_REFERENCE_SOURCES_V1");
    }

    function recordDomain(bytes32 family, bool scoped) internal pure returns (bytes32) {
        if (isV2(family)) {
            return scoped
                ? keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_REFERENCE_RECORD_V2")
                : keccak256("6529STREAM_PRESERVATION_POLICY_REFERENCE_RECORD_V2");
        }
        return scoped
            ? keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_REFERENCE_RECORD_V1")
            : keccak256("6529STREAM_PRESERVATION_POLICY_REFERENCE_RECORD_V1");
    }

    function chainDomain(bytes32 family, bool scoped) internal pure returns (bytes32) {
        if (isV2(family)) {
            return scoped
                ? keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_REFERENCE_CHAIN_V2")
                : keccak256("6529STREAM_PRESERVATION_POLICY_REFERENCE_CHAIN_V2");
        }
        return scoped
            ? keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_REFERENCE_CHAIN_V1")
            : keccak256("6529STREAM_PRESERVATION_POLICY_REFERENCE_CHAIN_V1");
    }

    function lockDomain(bytes32 family, bool scoped) internal pure returns (bytes32) {
        if (isV2(family)) {
            return scoped
                ? keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_REFERENCE_LOCK_SCOPE_V2")
                : keccak256("6529STREAM_PRESERVATION_POLICY_REFERENCE_LOCK_SCOPE_V2");
        }
        return scoped
            ? keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_REFERENCE_LOCK_SCOPE_V1")
            : keccak256("6529STREAM_PRESERVATION_POLICY_REFERENCE_LOCK_SCOPE_V1");
    }

    function componentDomain(bytes32 family, bool scoped) internal pure returns (bytes32) {
        if (isV2(family)) {
            return scoped
                ? keccak256("6529STREAM_LOCKED_SCOPED_PRESERVATION_POLICY_REFERENCE_COMPONENT_V2")
                : keccak256("6529STREAM_LOCKED_PRESERVATION_POLICY_REFERENCE_COMPONENT_V2");
        }
        return scoped
            ? keccak256("6529STREAM_LOCKED_SCOPED_PRESERVATION_POLICY_REFERENCE_COMPONENT_V1")
            : keccak256("6529STREAM_LOCKED_PRESERVATION_POLICY_REFERENCE_COMPONENT_V1");
    }
}
