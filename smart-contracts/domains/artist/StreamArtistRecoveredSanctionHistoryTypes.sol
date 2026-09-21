// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistSanctionTypes as S
} from "../../interfaces/stream/artist/StreamArtistSanctionTypes.sol";
import {
    StreamArtistSanctionConfirmationTypes as C
} from "../../interfaces/stream/artist/StreamArtistSanctionConfirmationTypes.sol";
import {
    StreamArtistRecoveredDisputeHistoryTypes as D
} from "./StreamArtistRecoveredDisputeHistoryTypes.sol";
import {
    StreamFinalityComponentExpectation
} from "../../interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import {
    StreamFinalityExecutionWitness
} from "../../interfaces/stream/finality/StreamFinalityGovernanceTypes.sol";
import {
    StreamFinalitySanctionArchiveWitness
} from "../../interfaces/stream/finality/StreamFinalitySanctionArchiveTypes.sol";
import {
    StreamArtistSanctionRequestTypes as Q
} from "../../interfaces/stream/artist/StreamArtistSanctionRequestTypes.sol";
import {
    StreamArtistRotationTypes as R
} from "../../interfaces/stream/artist/StreamArtistRotationTypes.sol";
import {
    IStreamArtistSanctionArchiveFacts
} from "../../interfaces/stream/artist/IStreamArtistSanctionOwner.sol";

/// @notice Additive op12/op13 history transport; original records and codecs remain unchanged.
library StreamArtistRecoveredSanctionHistoryTypes {
    bytes32 internal constant ATTRIBUTION =
        keccak256("6529STREAM_ARTIST_RECOVERED_SANCTION_ATTRIBUTION_V1");
    bytes32 internal constant CONSENT =
        keccak256("6529STREAM_ARTIST_RECOVERED_SANCTION_CONSENT_V1");
    bytes32 internal constant OPERATION_EVIDENCE = keccak256("ARTIST_OPERATION_EVIDENCE");
    bytes32 internal constant SANCTION = keccak256("consent_finality.replay.sanction_uniqueness");
    bytes32 internal constant CONFIRMATION =
        keccak256("consent_finality.replay.sanction_finalization_transition_key");

    // Finite collector limits, not restrictions on validity of the original lifetime history.
    uint256 internal constant MAX_CATALOGUE_ROWS = 16384;
    uint256 internal constant MAX_OPERATION_BYTES = 64 * 1024 * 1024;
    uint256 internal constant MAX_CONFIRMATIONS = 128;

    struct Catalogue {
        bytes32 originHash;
        bytes32 archiveCodeHash;
        bytes32 configurationHash;
        uint256 count;
        bytes32 rowsHash;
        uint64 attributionLower;
        uint64 attributionUpper;
        uint64 consentLower;
        uint64 consentUpper;
    }

    struct Evidence {
        uint256 catalogueIndex;
        address pointer;
        bytes32 payloadHash;
        bytes32 evidenceId;
    }

    struct OperationEvidence {
        bytes32 originHash;
        uint16 operation;
        Evidence evidence;
    }

    /// @dev Exact original outer abi.encode fields. Its standalone tuple has no leading offset.
    struct Envelope {
        uint16 version;
        bytes32 configurationHash;
        uint16 operation;
        address actor;
        bytes32 value;
        T.Snapshot[7] before_;
        T.Snapshot[7] after_;
        bytes payload;
    }

    /// @dev Exact original op13 payload fields, including both original retained witnesses.
    struct ConfirmationPayload {
        T.Binding binding_;
        C.Transition transition;
        S.Record sanction;
        address finalityRegistry;
        bytes32 finalityCodeHash;
        C.FinalityRecordEvidence finalityRecord;
        StreamFinalityComponentExpectation[] components;
        StreamFinalityExecutionWitness executionWitness;
        StreamFinalitySanctionArchiveWitness archiveWitness;
        bytes32 rawReadHash;
        bytes32 replayKey;
    }

    struct SanctionPayload {
        T.Binding binding_;
        Q.Request request;
        T.Authorization authorization;
        T.SignerApproval approval;
        R.AuthorityFact authority;
        S.Record record;
        Q.Prepared prepared;
    }

    struct SanctionRow {
        RH.Point point;
        S.Record record;
        bytes archiveBytes;
        IStreamArtistSanctionArchiveFacts.Facts archiveFacts;
        Evidence evidence;
    }

    struct ConfirmationRow {
        RH.Point attributionPoint;
        RH.Point consentPoint;
        Evidence evidence;
        C.Transition transition;
    }

    struct AttributionBundle {
        D.Bundle original;
        Inventory history;
    }

    struct Inventory {
        Catalogue[] catalogues;
        OperationEvidence[] operations;
        SanctionRow[] sanctions;
        ConfirmationRow[] confirmations;
    }
}
