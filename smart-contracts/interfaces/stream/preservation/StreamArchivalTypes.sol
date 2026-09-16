// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Versioned facts for the bounded public-payload archival verification profile.
/// @dev Network checkpoints are quorum attestations, not native consensus proofs.
library StreamArchivalTypes {
    struct Envelope {
        bytes32 artistId;
        bytes32 evidenceHash;
        bytes32 schemaId;
        bytes32 canonicalizationId;
        uint16 digestAlgorithm;
        bytes32 payloadDigest;
        uint64 byteSize;
        uint8 visibility;
        bytes32 custodyPolicyHash;
    }

    struct Family {
        bytes32 familyId;
        bytes32 networkId;
        bytes32 protocolLineage;
        bytes32 addressingLineage;
        bytes32 custodianId;
        bytes32 fundingDependency;
        bytes32 retrievalDependency;
        bytes32 jurisdiction;
        uint8 economics;
        address storingAgent;
        bytes32 verifierProfileHash;
    }

    struct Observer {
        address account;
        bytes32 organizationId;
    }

    struct ObserverProof {
        address account;
        bytes signature;
    }

    struct Checkpoint {
        bytes32 networkId;
        bytes blockHash;
        uint64 blockHeight;
        bytes32 transactionRoot;
        uint256 blockDataSize;
        bytes32 transactionId;
        bytes32 dataRoot;
        uint64 dataSize;
        uint256 transactionStart;
        uint256 transactionEnd;
        uint64 observedAt;
        bytes32 configurationHash;
    }

    struct CheckpointFacts {
        bytes32 networkId;
        bytes32 transactionId;
        bytes32 dataRoot;
        bytes32 payloadDigest;
        bytes32 contentHash;
        uint64 dataSize;
        bytes32 configurationHash;
    }

    struct CheckpointRecord {
        bytes32 recordHash;
        Checkpoint checkpoint;
        bytes32 payloadDigest;
        bytes32 contentHash;
        bytes transactionPath;
        bytes dataPath;
        ObserverProof[] certificate;
        uint64 recordedAt;
    }

    /// @dev Independent possession facts are hashed before ReceiptTerms is signed.
    ///      Neither its signature nor a later fixity record enters this preimage.
    struct Possession {
        bytes32 envelopeHash;
        bytes32 familyRecordHash;
        bytes32 storageIdentifierHash;
        address writer;
        uint64 observedAt;
    }

    struct ReceiptTerms {
        bytes32 envelopeHash;
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

    struct FixityTerms {
        bytes32 receiptRecordHash;
        bytes32 envelopeHash;
        bytes32 familyRecordHash;
        bytes32 expectedDigest;
        bytes32 observedDigest;
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

    struct CoverageFacts {
        bytes32 coverageRecordHash;
        bytes32 envelopeHash;
        bytes32 artistId;
        bytes32 evidenceHash;
        bytes32 firstFamilyRecordHash;
        bytes32 secondFamilyRecordHash;
        bytes32 firstReceiptRecordHash;
        bytes32 secondReceiptRecordHash;
        bytes32 firstFixityRecordHash;
        bytes32 secondFixityRecordHash;
        bytes32 checkpointRecordHash;
        bytes32 profileHash;
    }

    error InvalidArchivalConfiguration();
    error InvalidCheckpoint();
    error InvalidNativeInclusion();
    error InvalidArchivalSignature(address signer);
    error ArchivalParentGas(uint256 available, uint256 required);
    error ArchivalRecordExists(bytes32 recordHash);
    error ArchivalRecordUnavailable(bytes32 recordHash);
    error InvalidArchivalEnvelope();
    error InvalidArchivalFamily();
    error InvalidArchivalReceipt();
    error InvalidArchivalFixity();
    error InvalidArchivalCoverage();
    error ArchivalReplay(bytes32 replayKey);
    error ArchivalUnauthorized(address actor);
    error ArchivalComponentChanged(address component);
}
