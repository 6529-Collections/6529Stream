// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistCollaboratorTypes as C
} from "../../interfaces/stream/artist/StreamArtistCollaboratorTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import { StreamArtistRecoveredPlatformTypes as P } from "./StreamArtistRecoveredPlatformTypes.sol";
import {
    StreamArtistRecoveredSanctionHistoryTypes as H
} from "./StreamArtistRecoveredSanctionHistoryTypes.sol";

import {
    StreamArtistRecoveredBindingCorrectionTypes as CB
} from "./StreamArtistRecoveredBindingCorrectionTypes.sol";
import {
    StreamArtistRecoveredAcceptedGenerationTypes as A
} from "./StreamArtistRecoveredAcceptedGenerationTypes.sol";

import {
    StreamArtistRecoveredPlatformPayload as Payload
} from "./StreamArtistRecoveredPlatformPayload.sol";
import {
    StreamArtistRotationTypes as R
} from "../../interfaces/stream/artist/StreamArtistRotationTypes.sol";

import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";
import {
    StreamArtistRecoveredMultipleGenerationTypes as G
} from "./StreamArtistRecoveredMultipleGenerationTypes.sol";

/// @notice Original PRIMARY_ONLY collaborator facts; never a collaborator policy authorization.
library StreamArtistPrimaryCollaboratorTypes {
    bytes32 internal constant SCHEMA =
        keccak256("6529STREAM_ARTIST_PRIMARY_COLLABORATOR_HYDRATION_V1");
    uint16 internal constant VERSION = 1;
    uint256 internal constant FEATURE = 8388608;

    uint256 internal constant ALLOWED = (G.ALLOWED & ~G.FEATURE) | FEATURE;

    // All seven original slices are present. Each owner also checks its exact local header.
    struct Proof {
        RH.Provenance provenance;
        BindingInventory bindings;
        Inventory archive;
        A.AcceptanceBundle[] accepted;
        IH.NonceLane[] accounts;
    }

    struct IdentityAcceptance {
        C.IdentityProposalState proposal;
        T.Authorization authorization;
        T.SignerApproval approval;
        bytes document;
        string displayName;
        uint256 allocationNonce;
    }

    struct BindingAcceptance {
        T.Binding binding_;
        C.BindingAcceptance acceptance;
        bytes32 artistId;
        T.Authorization authorization;
        T.SignerApproval approval;
        C.BindingTerms terms;
        uint32 priorCount;
        uint32 count;
        bytes32 primaryRecord;
        bool complete;
    }

    struct Proposal {
        C.IdentityProposalState state;
        RH.Point proposedAt;
        RH.Point completedAt;
        uint256 proposalOperation;
        // Plus one so zero identifies a still-pending original proposal.
        uint256 identityOperationPlusOne;
    }

    struct AcceptedRow {
        C.BindingAcceptance acceptance;
        C.Join join;
        RH.Point recordedAt;
        uint256 operationIndex;
    }

    struct PrimaryAcceptance {
        Payload.Acceptance acceptance;
        R.AuthorityFact authority;
        bool expectedBinding;
        uint32 required;
        uint32 accepted;
        bool complete;
    }

    /// @dev All original op2 occurrences survive. Only the final source map retains a timestamp.
    struct PrimaryReceipt {
        uint256 collectionId;
        uint64 generation;
        bytes32 bindingHash;
        bytes32 recordHash;
        RH.Point point;
        uint256 operationIndex;
    }

    struct BindingInventory {
        CB.Bundle[] bindings;
        A.Generation[][] generations;
        T.CollaboratorRecord[][][] collaborators;
    }

    struct Inventory {
        P.Catalogue[] catalogues;
        H.OperationEvidence[] operations;
        Proposal[] proposals;
        AcceptedRow[] accepted;
    }
}
