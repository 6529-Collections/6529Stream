// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Bounded whole-object bytes and ordered current archival coverage.
library StreamFinalityArtifactTypes {
    /// @dev Schema semantics belong to the authoritative consumer. This object proves bytes and coverage.
    struct Artifact {
        bytes32 artistId;
        bytes32 schemaId;
        bytes32 canonicalizationId;
        uint16 hashAlgorithm;
        bytes32 contentHash;
        uint64 byteLength;
        bytes32[] chunkHashes;
        uint32[] chunkLengths;
    }

    struct Plan {
        bytes32 artifactHash;
        bytes32 firstFamilyRecordHash;
        bytes32 secondFamilyRecordHash;
        bytes32 environmentHash;
        uint64 validationEpoch;
        uint32 nextIndex;
        bytes32 evidenceChainHash;
        bytes32 completionHash;
    }

    /// @notice Immutable original whole-object identity and coverage evidence.
    /// @dev validationEpoch/evidenceChainHash describe the original completion, not the current cache.
    struct Coverage {
        bytes32 completionHash;
        bytes32 artifactHash;
        bytes32 artistId;
        bytes32 schemaId;
        bytes32 canonicalizationId;
        bytes32 contentHash;
        uint64 byteLength;
        uint32 chunkCount;
        bytes32 firstFamilyRecordHash;
        bytes32 secondFamilyRecordHash;
        uint64 validationEpoch;
        bytes32 evidenceChainHash;
    }

    /// @notice Ordered current revalidation of an immutable original completion.
    struct Validation {
        bytes32 completionHash;
        bytes32 environmentHash;
        uint64 validationEpoch;
        uint32 nextIndex;
        bytes32 evidenceChainHash;
        bytes32 validationRecordHash;
    }
}
