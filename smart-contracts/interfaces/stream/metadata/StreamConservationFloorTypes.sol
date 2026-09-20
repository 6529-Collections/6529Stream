// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Fixed-width native evidence and immutable first-sale receipts.
library StreamConservationFloorTypes {
    struct SaleContext {
        uint256 collectionId;
        uint256 tokenId;
        address saleAdapter;
        bytes32 saleId;
        bytes32 operationRoot;
        bytes32 operationId;
        bytes32 boundPolicyHash;
    }

    /// @dev Exactly one intent/waiver for Artist works; all Artist fields zero for platform works.
    /// Documentary personhood evidence must come from the actual admitted native producer.
    struct CollectionFacts {
        bytes32 artistId;
        bytes32 identityRecordHash;
        bytes32 intentRecordHash;
        bytes32 intentWaiverRecordHash;
        bytes32 interviewEvidenceHash;
        bytes32 rightsRecordHash;
        bytes32 personhoodEvidenceHash;
        bool platformWorks;
    }

    /// @dev Producer derives complete scope/content facts from the actual sale, never a release label.
    /// Empty media is an explicit nonzero canonical empty-inventory hash. A nonscript scope has
    /// zero scriptSourceHash. scopeSubject/membershipHash identify actual or authenticated prospective scope.
    struct ReleaseContext {
        bytes32 scopeSubject;
        bytes32 membershipHash;
        bytes32 mediaInventoryHash;
        bytes32 scriptSourceHash;
        bytes32 sourceContextHash;
        bool scriptWork;
    }

    struct ReleaseFacts {
        bytes32 sourceContextHash;
        bytes32 mediaEvidenceHash;
        bytes32 referenceEvidenceHash;
    }

    struct Source {
        address metadata;
        bytes32 metadataCodeHash;
        address provider;
        bytes32 providerCodeHash;
        bytes32 configurationHash;
        uint64 predecessor;
        uint64 admittedAt;
        bytes32 actionId;
    }

    struct FirstSaleReceipt {
        bytes32 receiptHash;
        uint256 collectionId;
        bytes32 effectiveTier;
        address recorder;
        bytes32 settlementKey;
        uint64 recordedAt;
        uint64 sourceId;
        bytes32 sourceSetHash;
        CollectionFacts facts;
    }

    struct ReleaseFloorReceipt {
        bytes32 receiptHash;
        bytes32 releaseKey;
        uint256 collectionId;
        bytes32 effectiveTier;
        address recorder;
        bytes32 settlementKey;
        uint64 recordedAt;
        uint64 sourceId;
        bytes32 sourceSetHash;
        ReleaseContext context;
        ReleaseFacts facts;
    }

    struct SettlementReceipt {
        bytes32 receiptHash;
        address recorder;
        bytes32 recorderCodeHash;
        bytes32 settlementKey;
        bytes32 candidatePayloadHash;
        bytes32 candidateCommitment;
        bytes32 resultHash;
        uint256 collectionId;
        uint256 tokenId;
        bytes32 effectiveTier;
        bytes32 firstSaleReceiptHash;
        bytes32 releaseReceiptHash;
        uint64 recordedAt;
    }
}
