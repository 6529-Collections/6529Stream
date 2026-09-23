// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamPreservationTokenProducerProfilesV1 as Producers
} from "../../interfaces/stream/finality/StreamPreservationTokenProducerProfilesV1.sol";
import {
    StreamPreservationPolicySnapshotDefinitionsV1 as C1
} from "./StreamPreservationPolicySnapshotDefinitionsV1.sol";
import {
    StreamPreservationPolicySnapshotDefinitionsV2 as C2
} from "./StreamPreservationPolicySnapshotDefinitionsV2.sol";
import {
    StreamScopedPreservationPolicySnapshotDefinitionsV1 as S1
} from "./StreamScopedPreservationPolicySnapshotDefinitionsV1.sol";
import {
    StreamScopedPreservationPolicySnapshotDefinitionsV2 as S2
} from "./StreamScopedPreservationPolicySnapshotDefinitionsV2.sol";

/// @notice Closed constructor-selected snapshot families. Original entrypoints always select V1.
library StreamPreservationPolicySnapshotFamiliesV2 {
    error InvalidSnapshotFamily();

    function version2(bytes32 family) internal pure returns (bool) {
        if (family == Producers.ORIGINAL_PROFILE) return false;
        if (family == Producers.FAMILY_PROFILE) return true;
        revert InvalidSnapshotFamily();
    }

    function profile(bytes32 family, bool scoped) internal pure returns (bytes32) {
        bool v2 = version2(family);
        if (scoped) {
            return v2
                ? keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_V2")
                : keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_V1");
        }
        return v2
            ? keccak256("6529STREAM_PRESERVATION_POLICY_SNAPSHOT_V2")
            : keccak256("6529STREAM_PRESERVATION_POLICY_SNAPSHOT_V1");
    }

    function recordDomain(bytes32 family, bool scoped) internal pure returns (bytes32) {
        bool v2 = version2(family);
        if (scoped) {
            return v2
                ? keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_RECORD_V2")
                : keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_RECORD_V1");
        }
        return v2
            ? keccak256("6529STREAM_PRESERVATION_POLICY_SNAPSHOT_RECORD_V2")
            : keccak256("6529STREAM_PRESERVATION_POLICY_SNAPSHOT_RECORD_V1");
    }

    function chainDomain(bytes32 family, bool scoped) internal pure returns (bytes32) {
        bool v2 = version2(family);
        if (scoped) {
            return v2
                ? keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_CHAIN_V2")
                : keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_CHAIN_V1");
        }
        return v2
            ? keccak256("6529STREAM_PRESERVATION_POLICY_SNAPSHOT_CHAIN_V2")
            : keccak256("6529STREAM_PRESERVATION_POLICY_SNAPSHOT_CHAIN_V1");
    }

    function lockDomain(bytes32 family, bool scoped) internal pure returns (bytes32) {
        bool v2 = version2(family);
        if (scoped) {
            return v2
                ? keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_LOCK_V2")
                : keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_LOCK_V1");
        }
        return v2
            ? keccak256("6529STREAM_PRESERVATION_POLICY_SNAPSHOT_LOCK_V2")
            : keccak256("6529STREAM_PRESERVATION_POLICY_SNAPSHOT_LOCK_V1");
    }

    function payloadDomain(bytes32 family, bool scoped) internal pure returns (bytes32) {
        bool v2 = version2(family);
        if (scoped) {
            return v2
                ? keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_PAYLOAD_V2")
                : keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_PAYLOAD_V1");
        }
        return v2
            ? keccak256("6529STREAM_PRESERVATION_POLICY_SNAPSHOT_PAYLOAD_V2")
            : keccak256("6529STREAM_PRESERVATION_POLICY_SNAPSHOT_PAYLOAD_V1");
    }

    function sourcesDomain(bytes32 family, bool scoped) internal pure returns (bytes32) {
        bool v2 = version2(family);
        if (scoped) {
            return v2
                ? keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_SOURCES_V2")
                : keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_SOURCES_V1");
        }
        return v2
            ? keccak256("6529STREAM_PRESERVATION_POLICY_SNAPSHOT_SOURCES_V2")
            : keccak256("6529STREAM_PRESERVATION_POLICY_SNAPSHOT_SOURCES_V1");
    }

    function inputDomain(bytes32 family, bool scoped) internal pure returns (bytes32) {
        bool v2 = version2(family);
        if (scoped) {
            return v2
                ? keccak256("6529STREAM_FINALITY_SCOPED_PRESERVATION_POLICY_SNAPSHOT_INPUT_V2")
                : keccak256("6529STREAM_FINALITY_SCOPED_PRESERVATION_POLICY_SNAPSHOT_INPUT_V1");
        }
        return v2
            ? keccak256("6529STREAM_FINALITY_PRESERVATION_POLICY_SNAPSHOT_INPUT_V2")
            : keccak256("6529STREAM_FINALITY_PRESERVATION_POLICY_SNAPSHOT_INPUT_V1");
    }

    function finalityLockDomain(bytes32 family, bool scoped) internal pure returns (bytes32) {
        bool v2 = version2(family);
        if (scoped) {
            return v2
                ? keccak256("6529STREAM_FINALITY_SCOPED_PRESERVATION_POLICY_SNAPSHOT_LOCK_V2")
                : keccak256("6529STREAM_FINALITY_SCOPED_PRESERVATION_POLICY_SNAPSHOT_LOCK_V1");
        }
        return v2
            ? keccak256("6529STREAM_FINALITY_PRESERVATION_POLICY_SNAPSHOT_LOCK_V2")
            : keccak256("6529STREAM_FINALITY_PRESERVATION_POLICY_SNAPSHOT_LOCK_V1");
    }

    function ids(bytes32 family, bool scoped) internal pure returns (bytes32[3] memory) {
        bool v2 = version2(family);
        if (scoped && v2) return [S2.SCHEMA_ID, S2.PROFILE_ID, S2.CANON_ID];
        if (scoped) return [S1.SCHEMA_ID, S1.PROFILE_ID, S1.CANON_ID];
        if (v2) return [C2.SCHEMA_ID, C2.PROFILE_ID, C2.CANON_ID];
        return [C1.SCHEMA_ID, C1.PROFILE_ID, C1.CANON_ID];
    }

    function hashes(bytes32 family, bool scoped) internal pure returns (bytes32[3] memory) {
        bool v2 = version2(family);
        if (scoped && v2) return [S2.SCHEMA_HASH, S2.PROFILE_HASH, S2.CANON_HASH];
        if (scoped) return [S1.SCHEMA_HASH, S1.PROFILE_HASH, S1.CANON_HASH];
        if (v2) return [C2.SCHEMA_HASH, C2.PROFILE_HASH, C2.CANON_HASH];
        return [C1.SCHEMA_HASH, C1.PROFILE_HASH, C1.CANON_HASH];
    }

    function lengths(bytes32 family, bool scoped) internal pure returns (uint256[3] memory) {
        bool v2 = version2(family);
        if (scoped && v2) return [S2.SCHEMA_BYTES, S2.PROFILE_BYTES, S2.CANON_BYTES];
        if (scoped) return [S1.SCHEMA_BYTES, S1.PROFILE_BYTES, S1.CANON_BYTES];
        if (v2) return [C2.SCHEMA_BYTES, C2.PROFILE_BYTES, C2.CANON_BYTES];
        return [C1.SCHEMA_BYTES, C1.PROFILE_BYTES, C1.CANON_BYTES];
    }
}
