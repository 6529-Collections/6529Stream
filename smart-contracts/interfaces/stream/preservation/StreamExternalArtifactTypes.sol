// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArchivalTypes as A } from "./StreamArchivalTypes.sol";

/// @notice Full external-object commitments and attributed preservation evidence.
/// @dev Flat hashes are full-retrieval fixity observations; native inclusion proves its
///      separately identified Arweave data root, under the named quorum checkpoint model.
library StreamExternalArtifactTypes {
    struct ObjectIdentity {
        bytes32 artistId;
        bytes32 schemaId;
        bytes32 canonicalizationId;
        bytes32 contentHash;
        bytes32 sha256Digest;
        bytes32 arweaveDataRoot;
        uint64 byteSize;
        bytes32 formatId;
        bytes32 formatCatalogId;
        bytes32 formatCatalogHash;
    }

    struct NativeFacts {
        bytes32 recordHash;
        bytes32 networkId;
        bytes32 transactionId;
        bytes32 dataRoot;
        uint64 dataSize;
        bytes32 configurationHash;
        bytes32 firstChunkDigest;
        bytes32 lastChunkDigest;
    }

    struct NativeRecord {
        bytes32 recordHash;
        A.Checkpoint checkpoint;
        bytes32 firstChunkDigest;
        bytes32 lastChunkDigest;
        bytes transactionPath;
        bytes firstDataPath;
        bytes lastDataPath;
        A.ObserverProof[] certificate;
        uint64 recordedAt;
    }

    struct Receipt {
        bytes32 objectHash;
        bytes32 familyRecordHash;
        bytes32 storageIdentifierHash;
        bytes32 evidenceClass;
        bytes32 proofProfileHash;
        bytes32 proofRecordHash;
        address writer;
        uint64 observedAt;
        uint256 nonce;
        uint64 deadline;
    }

    /// @dev Every expected/observed commitment is signed, including on failure.
    struct Fixity {
        bytes32 receiptHash;
        bytes32 objectHash;
        bytes32 familyRecordHash;
        bytes32 storageIdentifierHash;
        bytes32 profileHash;
        bytes32 expectedSha256;
        bytes32 observedSha256;
        bytes32 expectedKeccak256;
        bytes32 observedKeccak256;
        bytes32 expectedArweaveRoot;
        bytes32 observedArweaveRoot;
        uint64 expectedSize;
        uint64 observedSize;
        uint64 checkedAt;
        uint8 outcome;
        bytes32 reportHash;
        bytes32 previousFixityHash;
        bytes32 repairReportHash;
        address verifier;
        uint256 nonce;
        uint64 deadline;
    }

    /// @notice Unsaved present liveness for two exact original receipts; never a recorded coverage.
    /// @dev Later passing fixity may change these two fixity hashes without changing the originals.
    struct CurrentPair {
        bytes32 objectHash;
        bytes32 artistId;
        bytes32 contentHash;
        bytes32 sha256Digest;
        bytes32 arweaveDataRoot;
        uint64 byteSize;
        bytes32 firstFamilyRecordHash;
        bytes32 secondFamilyRecordHash;
        bytes32 firstReceiptHash;
        bytes32 secondReceiptHash;
        bytes32 firstFixityHash;
        bytes32 secondFixityHash;
        bytes32 checkpointHash;
        bytes32 profileHash;
    }

    struct Coverage {
        bytes32 coverageHash;
        bytes32 objectHash;
        bytes32 artistId;
        bytes32 contentHash;
        bytes32 sha256Digest;
        bytes32 arweaveDataRoot;
        uint64 byteSize;
        bytes32 firstFamilyRecordHash;
        bytes32 secondFamilyRecordHash;
        bytes32 firstReceiptHash;
        bytes32 secondReceiptHash;
        bytes32 firstFixityHash;
        bytes32 secondFixityHash;
        bytes32 checkpointHash;
        bytes32 profileHash;
    }
}
