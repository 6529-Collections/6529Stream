// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Typed collaborator registration, immutable proposal terms and accepted identity joins.
library StreamArtistCollaboratorTypes {
    struct IdentityProposal {
        address account;
        bytes32 identityRecordHash;
        string identityRecordURI;
        bytes32 reasonHash;
        string reasonURI;
    }

    struct IdentityProposalState {
        IdentityProposal proposal;
        address proposer;
        bytes32 proposalHash;
        bytes32 acceptedArtistId;
    }

    struct BindingAcceptance {
        uint256 collectionId;
        uint64 generation;
        bytes32 bindingHash;
        address account;
        bytes32 role;
        bytes32 shareLabelId;
    }

    struct BindingTerms {
        bytes32 collaboratorSetHash;
        bytes32 capabilityPolicySetHash;
        uint8 mode;
        uint32 threshold;
        uint32 count;
    }

    struct Join {
        bytes32 artistId;
        bytes32 acceptanceRecordHash;
    }

    struct Row {
        address account;
        bytes32 role;
        bytes32 shareLabelId;
        bytes32 collaboratorArtistId;
        bytes32 acceptanceRecordHash;
        bool accepted;
    }
}
