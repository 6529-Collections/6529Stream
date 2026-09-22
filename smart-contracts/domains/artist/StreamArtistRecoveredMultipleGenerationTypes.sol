// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredAcceptedGenerationTypes as A
} from "./StreamArtistRecoveredAcceptedGenerationTypes.sol";
import {
    StreamArtistRecoveredBindingCorrectionTypes as CB
} from "./StreamArtistRecoveredBindingCorrectionTypes.sol";
import {
    StreamArtistRecoveredAttestationHydration as Records
} from "./StreamArtistRecoveredAttestationHydration.sol";
import {
    StreamArtistRecoveredContentConsentHydration as Content
} from "./StreamArtistRecoveredContentConsentHydration.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import { StreamArtistRecoveredPlatformTypes as P } from "./StreamArtistRecoveredPlatformTypes.sol";
import {
    StreamArtistRecoveredSanctionHistoryTypes as H
} from "./StreamArtistRecoveredSanctionHistoryTypes.sol";

/// @notice Closed same-Artist PRIMARY_ONLY generation history over a complete recovered graph.
/// @dev Original nominal rows retain their domains. New aggregate clocks never renumber
/// a per-collection subsequence or treat another owner's revision as a local coordinate.
library StreamArtistRecoveredMultipleGenerationTypes {
    bytes32 internal constant SCHEMA =
        keccak256("6529STREAM_ARTIST_RECOVERED_MULTIPLE_GENERATIONS_V1");
    uint16 internal constant VERSION = 1;
    uint256 internal constant FEATURE = 2097152;
    uint256 internal constant ALLOWED = 2293759;

    struct Attribution {
        A.AttributionBundle history;
        Records.Bundle records;
    }

    struct Consents {
        Content.Bundle rows;
        T.Binding[] bindings;
    }

    struct Inventory {
        P.Catalogue[] catalogues;
        H.OperationEvidence[] operations;
        CB.Bundle[] bindings;
        A.Generation[][] generations;
    }

    struct Timeline {
        RH.Point[] proposals;
        RH.Point[] completions;
        RH.Point[] attributionProposals;
        RH.Point[] attributionCompletions;
    }
}
