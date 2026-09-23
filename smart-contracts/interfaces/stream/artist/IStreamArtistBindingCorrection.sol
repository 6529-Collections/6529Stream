// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistOnboardingTypes as T } from "./StreamArtistOnboardingTypes.sol";
import {
    StreamArtistIdentityContestTypes as Contest
} from "./StreamArtistIdentityContestTypes.sol";

/// @notice Additive original-op1 correction; original proposal/acceptance signing bytes stay unchanged.
library StreamArtistBindingCorrectionTypes {
    // Cause1 refusal,2 withdrawal,3 executed artist repudiation,4 arbiter revocation.
    struct Approval {
        T.Binding previous;
        uint8 cause;
        bytes32 causeRecord;
        bytes causeData;
        bytes32 proposalHash;
        bytes32 proposedArtistId;
        uint256 registrationNonce;
        Contest.GovernanceWitness governance;
        uint64 approvedAt;
    }

    struct Context {
        bytes32 scopeHash;
        bytes32 oldValueHash;
        bytes32 newValueHash;
    }
    bytes32 internal constant DETAIL =
        keccak256("6529STREAM_ARTIST_BINDING_CORRECTION_EVIDENCE_V1");
    error InvalidBindingCorrection(uint256 collectionId);
    event ArtistBindingCorrectionApproved(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        bytes32 indexed bindingHash,
        bytes32 indexed approvalHash,
        uint64 previousGeneration,
        bytes32 previousBindingHash,
        uint8 cause,
        bytes32 causeRecord,
        bytes32 governanceActionId
    );
}

interface IStreamArtistBindingCorrection {
    function proposeArtistBindingAfterRevocation(
        uint256 collectionId,
        T.BindingProposal calldata proposal,
        bytes calldata document,
        string calldata displayName,
        bytes32 repudiationRecord
    ) external returns (bytes32 artistId, bytes32 bindingHash);
}

interface IStreamArtistBindingCorrectionCoordinator {
    function coordinateProposeArtistBindingAfterRevocation(
        address actor,
        uint256 collectionId,
        T.BindingProposal calldata proposal,
        bytes calldata document,
        string calldata displayName,
        bytes32 repudiationRecord
    ) external returns (bytes32 artistId, bytes32 bindingHash);
}

interface IStreamArtistBindingCorrectionOwner {
    function proposeAfterRevocation(
        T.ActionContext calldata context,
        uint256 collectionId,
        bytes32 artistId,
        T.BindingProposal calldata proposal,
        StreamArtistBindingCorrectionTypes.Approval calldata approval
    ) external returns (T.Binding memory);
    function bindingCorrection(bytes32 bindingHash)
        external
        view
        returns (StreamArtistBindingCorrectionTypes.Approval memory approval, bytes32 approvalHash);
}
