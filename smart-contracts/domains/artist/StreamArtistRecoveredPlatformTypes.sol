// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistPlatformTypes as PW
} from "../../interfaces/stream/artist/StreamArtistPlatformTypes.sol";
import {
    StreamArtistPlatformCorrectionLineageTypes as PL
} from "../../interfaces/stream/artist/IStreamArtistPlatformCorrectionLineage.sol";
import {
    StreamArtistAttributionClaimTypes as AC
} from "../../interfaces/stream/artist/IStreamArtistAttributionClaims.sol";
import {
    StreamArtistRecoveredDisputeHistoryTypes as D
} from "./StreamArtistRecoveredDisputeHistoryTypes.sol";
import {
    StreamArtistRecoveredSanctionHistoryTypes as H
} from "./StreamArtistRecoveredSanctionHistoryTypes.sol";
import {
    StreamArtistRecoveredBindingCorrectionTypes as CB
} from "./StreamArtistRecoveredBindingCorrectionTypes.sol";

/// @notice Original collection-only Platform history, separate from any inferred Artist association.
library StreamArtistRecoveredPlatformTypes {
    bytes32 internal constant ATTRIBUTION =
        keccak256("6529STREAM_ARTIST_RECOVERED_PLATFORM_HISTORY_V1");
    bytes32 internal constant BINDING =
        keccak256("6529STREAM_ARTIST_RECOVERED_PLATFORM_BINDINGS_V1");
    uint256 internal constant MAX_ROWS = 128;

    struct Catalogue {
        bytes32 originHash;
        bytes32 archiveCodeHash;
        bytes32 configurationHash;
        uint256 count;
        bytes32 rowsHash;
        uint64[7] lower;
        uint64[7] upper;
    }

    struct ClaimRow {
        RH.Point point;
        PW.Claim record;
    }

    struct ContestRow {
        RH.Point point;
        PW.Contest record;
    }

    struct AttributionClaimRow {
        RH.Point point;
        AC.Claim record;
    }

    struct ContinuationRow {
        PL.Record record;
        PL.Acceptance acceptance;
    }

    struct Platform {
        bytes32 provenance;
        uint256 collectionId;
        PW.State state;
        RH.Point declarationPoint;
        RH.Point correctionPoint;
        ClaimRow[] claims;
        ContestRow[] contests;
        AttributionClaimRow[] allegations;
        uint256 allegationCount;
        bytes32 latestAllegation;
        bytes32 latestDisplayClaim;
        PL.Status status;
        ContinuationRow[] continuations;
        Catalogue[] catalogues;
        H.OperationEvidence[] operations;
    }

    struct Bundle {
        D.Bundle original;
        H.Inventory sanctions;
        Platform platform;
        CB.Bundle bindings;
    }

    struct Cursor {
        PW.State state;
        PL.Status status;
        uint256 generation;
        uint256 continuations;
        bool completed;
    }

    function nativeOperation(uint16 op) internal pure returns (bool) {
        return op == 8 || op == 9 || op == 10 || op == 11 || op == 53;
    }

    function archivedOperation(uint256 op) internal pure returns (bool) {
        return op == 1 || op == 2 || op == 3 || op == 4 || op == 8 || op == 9 || op == 10
            || op == 11 || op == 53;
    }

    function nativeCount(Platform memory p) internal pure returns (uint256) {
        return (p.state.declaration.recordHash == 0 ? 0 : 1)
            + (p.state.correction.recordHash == 0 ? 0 : 1) + p.claims.length + p.contests.length
            + p.allegations.length;
    }
}
