// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistAttributionDisputeTypes as AD
} from "../../interfaces/stream/artist/IStreamArtistAttributionDisputes.sol";
import {
    StreamArtistDisputeWithdrawalTypes as W
} from "../../interfaces/stream/artist/IStreamArtistDisputeWithdrawal.sol";
import {
    StreamArtistRepudiationTypes as RP
} from "../../interfaces/stream/artist/IStreamArtistAttributionRepudiation.sol";
import {
    StreamArtistRecoveredAcceptedGenerationTypes as A
} from "./StreamArtistRecoveredAcceptedGenerationTypes.sol";
import { StreamArtistAttributionStateTypes as AS } from "./StreamArtistAttributionStateTypes.sol";

/// @notice Complete original dispute and repudiation maps, separately tagged from old codecs.
library StreamArtistRecoveredDisputeHistoryTypes {
    bytes32 internal constant ATTRIBUTION =
        keccak256("6529STREAM_ARTIST_RECOVERED_DISPUTE_HISTORY_V1");
    bytes32 internal constant BINDING =
        keccak256("6529STREAM_ARTIST_RECOVERED_DISPUTE_BINDINGS_V1");
    bytes32 internal constant ACCEPTANCE =
        keccak256("6529STREAM_ARTIST_RECOVERED_DISPUTE_ACCEPTANCES_V1");

    struct DisputeRow {
        RH.Point point;
        AD.Record record;
        W.Outcome withdrawal;
    }

    struct ResolutionRow {
        RH.Point point;
        AD.Resolution record;
    }

    struct RepudiationRow {
        RH.Point point;
        RP.Record record;
        RP.Terminal terminal;
        RH.Point terminalPoint;
    }

    struct Bundle {
        bytes32 provenance;
        bytes32 artistId;
        uint256 collectionId;
        bytes32 bindingHash;
        AS.Attribution current;
        A.Generation[] generations;
        AD.Head[] heads;
        DisputeRow[] disputes;
        ResolutionRow[] resolutions;
        RepudiationRow[] repudiations;
        bytes32 pending;
    }

    struct Guard {
        bytes32 surface;
        bytes32 scope;
        bytes32 commitment;
        RH.Point point;
    }
    bytes32 internal constant OPEN = keccak256("attribution_lifecycle.replay.dispute_key");
    bytes32 internal constant COUNTER =
        keccak256("attribution_lifecycle.replay.counter_statement_key");
    bytes32 internal constant RESOLVE =
        keccak256("attribution_lifecycle.replay.dispute_resolution_key");
    bytes32 internal constant GOVERNANCE =
        keccak256("attribution_lifecycle.replay.governance_action");
    bytes32 internal constant WITHDRAW =
        keccak256("attribution_lifecycle.replay.dispute_withdrawal_key");
    bytes32 internal constant STAGE = keccak256("attribution_lifecycle.replay.repudiation_key");
    bytes32 internal constant VETO = keccak256("attribution_lifecycle.replay.repudiation_veto_key");
    bytes32 internal constant CANCEL =
        keccak256("attribution_lifecycle.replay.repudiation_cancellation_key");
    bytes32 internal constant EXECUTE =
        keccak256("attribution_lifecycle.replay.repudiation_execution_key");

    function terminalSurface(uint8 phase) internal pure returns (bytes32) {
        if (phase == 2) return VETO;
        if (phase == 3) return CANCEL;
        if (phase == 4) return EXECUTE;
        revert RH.InvalidRecoveredHydrationProfile();
    }

    function samePoint(RH.Point memory a, RH.Point memory b) internal pure returns (bool) {
        return keccak256(abi.encode(a)) == keccak256(abi.encode(b));
    }
}
