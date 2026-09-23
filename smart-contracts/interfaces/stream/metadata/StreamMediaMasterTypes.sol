// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamConservationRecordTypes.sol";
import "./IStreamConservationRecordSelection.sol";

/// @notice Original artist declarations for bounded selected media, separate from archive proofs.
library StreamMediaMasterTypes {
    enum Role { SOURCE_MASTER, PRINT_MASTER }
    enum MediaClass { STILL_IMAGE, PRINT_DESTINED, AUDIO, VIDEO, INTERACTIVE_CAPTURE }
    enum Status { ABSENT, PRESENT, WAIVED }

    struct Artist {
        bytes32 artistId;
        uint64 bindingGeneration;
        bytes32 bindingHash;
    }

    struct WaivedObject {
        bytes32 objectId;
        MediaClass mediaClass;
        Role[] masterRoles;
    }

    /// @dev Exact STREAM_MASTER_WAIVER_V1 JSON, with no extra profile field.
    struct Waiver {
        bytes32 subjectId;
        Artist artist;
        bytes32 scopeSubjectId;
        WaivedObject[] mediaObjects;
        StreamConservationRecordTypes.Reference waiverStatement;
        string reason;
        bytes32 predecessor;
    }

    struct Master {
        bytes32 subjectId;
        bytes32 selectedMediaManifestHash;
        uint8 mediaSlot;
        bytes32 displayHash;
        Role masterRole;
        bytes32 masterObjectHash;
        bytes32 coverageHash;
        bytes32 predecessor;
    }

    struct RecordEvidence {
        bytes32 recordHash;
        bytes32 payloadHash;
        address recorder;
        uint8 authorizationClass;
        uint64 recordedAt;
        uint64 recordIndex;
        bytes32 recordChainHash;
        bytes32 receiptHash;
        StreamArtistRecordPublicationTypes.Evidence publication;
        bytes32 publicationEvidenceHash;
    }

    struct Selection {
        Status status;
        bytes32 subjectId;
        bytes32 manifestHash;
        uint8 mediaSlot;
        bytes32 displayHash;
        bytes32 objectId;
        RecordEvidence original;
        IStreamConservationRecordSelection.Association association;
        bytes32 masterObjectHash;
        bytes32 coverageHash;
        Role masterRole;
        bytes32 predecessor;
        uint64 revision;
        bytes32 selectionHash;
    }

    error InvalidMasterWitness();
    error MasterSelectionConflict();
    error MasterCoverageUnavailable();
    error UnsupportedMediaDenominator();
    error PlatformMasterUnavailable();
}
