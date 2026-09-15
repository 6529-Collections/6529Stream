// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Exact role-qualified objects derived from original finality inputs.
/// @dev Neither an item nor a hash chain establishes source authority or archive coverage.
library StreamPreservationInventoryTypes {
    enum Kind {
        NATIVE_BYTES,
        CONTRACT_RUNTIME,
        ORIGINAL_PAYLOAD,
        REGISTERED_DOCUMENT,
        EXTERNAL_REFERENCE,
        EXTERNAL_OBJECT,
        STATE_BUNDLE,
        ABSENT,
        NATIVE_OS_PREREQUISITE,
        EMPTY_BYTES,
        ONCHAIN_OBJECT,
        EMPTY_PACKAGE_MEMBER
    }

    /// @dev Repeated bytes in different roles remain separate occurrences. Zero byteSize is
    /// unknown only for EXTERNAL_REFERENCE; ABSENT has canonical empty object fields.
    /// sourceRecord identifies the actual original input, never the finality manifest.
    struct Item {
        Kind kind;
        bytes32 role;
        address source;
        bytes32 sourceRecord;
        uint256 sourceIndex;
        uint16 algorithm;
        bytes32 canonicalizationId;
        bytes digest;
        string uri;
        uint64 byteSize;
        bytes32 schemaId;
        bytes32 formatId;
        bytes32 catalogId;
        bytes32 catalogHash;
        bytes32 objectHash;
        bytes32 originalCoverageHash;
        bytes32 provenanceHash;
    }

    /// @notice Authenticated finite segment, consumed from firstLink toward the zero terminator.
    /// @dev index/count/key enter every link, including repeated identical object occurrences.
    struct Segment {
        bytes32 key;
        uint64 itemCount;
        bytes32 firstLink;
        bytes32 sourceWitnessHash;
    }

    struct Plan {
        uint256 collectionId;
        bytes32 subject;
        bytes32 artistId;
        bytes32 sourceContextHash;
        uint64 tokenCount;
        uint64 nextToken;
        uint64 segmentCount;
        uint64 itemCount;
        bytes32 segmentChainHash;
        uint16 completedStages;
        bytes32 renderCriticalEvidenceHash;
    }

    struct OriginalInputs {
        bytes32 rootRecordHash;
        bytes32 snapshotRecordHash;
        bytes32 referenceRenderRecordHash;
        bytes32 intentRecordHash;
        bytes32 intentWaiverRecordHash;
        bytes32 interviewEvidenceHash;
        bytes32 rightsStatementRecordHash;
        bytes32 workDescriptionRecordHash;
    }

    struct Evidence {
        bytes32 planId;
        uint256 collectionId;
        bytes32 scopeSubject;
        bytes32 artistId;
        OriginalInputs originals;
        bytes32 sourceContextHash;
        bytes32 tokenInventoryHash;
        uint64 tokenCount;
        uint64 segmentCount;
        uint64 itemCount;
        bytes32 segmentChainHash;
        bytes32 renderCriticalEvidenceHash;
    }

    struct BundleEvidence {
        bytes32 inventoryPlan;
        bytes32 renderCriticalEvidenceHash;
        uint64 itemCount;
        bytes32 evidenceChainHash;
        bytes32 bundleCoverageHash;
    }

    error InvalidInventoryItem();
    error InvalidInventorySegment();
    error InventorySourceChanged();
    error InventoryIncomplete();
    error InventoryRead(address target);
    error UnsupportedInventoryCorrespondence(uint16 algorithm, bytes32 canonicalizationId);
}
