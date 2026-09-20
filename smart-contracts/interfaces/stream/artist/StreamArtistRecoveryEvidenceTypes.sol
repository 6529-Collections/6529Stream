// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistGuardianAppealTypes as Appeal } from "./StreamArtistGuardianAppealTypes.sol";
import {
    StreamArtistIdentityRecoveryOperationTypes as Recovery
} from "./StreamArtistIdentityRecoveryOperationTypes.sol";

/// @notice Additive adjudication evidence; original recovery and appeal encodings are unchanged.
library StreamArtistRecoveryEvidenceTypes {
    /// @dev Bounded publication profile, not a limit on an artist's actual vesting ancestry.
    uint256 internal constant MAX_DECLARED_VESTINGS = 64;
    uint256 internal constant MAX_SUPERSESSIONS = 64;
    uint256 internal constant MAX_FINDING_PARTIES = 8;

    enum VestingBasis {
        NO_CONTESTED_VESTING,
        DECLARED_VESTINGS
    }

    struct VestingReference {
        bytes32 transitionRecordHash;
        bytes32 vestingCommitment;
    }

    struct ResolutionManifest {
        bytes32 artistId;
        uint64 ownerRevision;
        bytes32 causeHash;
        bytes32 resolutionHash;
        bytes32 executedHead;
        VestingBasis basis;
        bytes32 requestCommitment;
        bytes32 resolutionEvidenceHash;
        // Original execution order, oldest first; never lexicographic hash order.
        VestingReference[] contestedVestings;
        bytes32[] supersededRecordHashes;
    }

    struct AppealDocumentV2 {
        bytes32 resolutionManifestHash;
        bytes32 hostileFindingsHash;
        Appeal.Finding[] findings;
    }

    struct EvidenceStateV2 {
        bytes32 manifestHash;
        bytes32 basisCommitment;
        bytes32 selectionCommitment;
        bytes32 requiredRole;
        uint64 preparedFromOwnerRevision;
        bytes32 associationHash;
    }

    error InvalidRecoveryManifest(bytes32 manifestHash);
    error InvalidRecoveryAppealEvidence(bytes32 documentHash);
    error RecoveryEvidenceDependencyChanged(address target);

    /// @dev Omits only Request.evidenceHash, which may reference the resulting appeal document.
    function requestCommitment(Recovery.Request memory request) internal pure returns (bytes32) {
        return Appeal.requestCommitment(request);
    }

    function manifestHash(
        uint256 chainId,
        address registry,
        address owner,
        bytes32 ownerCodeHash,
        address coordinator,
        address archive,
        address core,
        address manager,
        ResolutionManifest memory manifest
    ) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_RECOVERY_RESOLUTION_MANIFEST_V1"),
                uint16(1),
                chainId,
                registry,
                owner,
                ownerCodeHash,
                coordinator,
                archive,
                core,
                manager,
                manifest
            )
        );
    }

    function appealHash(
        uint256 chainId,
        address registry,
        address owner,
        AppealDocumentV2 memory document
    ) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_HOSTILE_GUARDIAN_EVIDENCE_V2"),
                uint16(2),
                chainId,
                registry,
                owner,
                document
            )
        );
    }
}
