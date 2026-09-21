// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistRecoveredPlatformTypes as P } from "./StreamArtistRecoveredPlatformTypes.sol";
import {
    StreamArtistRecoveredPlatformPayload as Payload
} from "./StreamArtistRecoveredPlatformPayload.sol";
import {
    StreamArtistRecoveredPlatformTransitionProof as Transition
} from "./StreamArtistRecoveredPlatformTransitionProof.sol";
import {
    StreamArtistRecoveredBindingCorrectionTypes as CB
} from "./StreamArtistRecoveredBindingCorrectionTypes.sol";
import {
    StreamArtistRecoveredAcceptedGenerationTypes as A
} from "./StreamArtistRecoveredAcceptedGenerationTypes.sol";
import {
    StreamArtistPlatformCorrectionState as State
} from "./StreamArtistPlatformCorrectionState.sol";
import {
    StreamArtistPlatformCorrectionLineageTypes as PL
} from "../../interfaces/stream/artist/IStreamArtistPlatformCorrectionLineage.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredSanctionHistoryTypes as H
} from "./StreamArtistRecoveredSanctionHistoryTypes.sol";

import {
    StreamArtistRecoveredPlatformProposalProofKernel as Kernel
} from "./StreamArtistRecoveredPlatformProposalProofKernel.sol";

/// @notice Original op1 consumes the one-shot correction or appends one exact fresh continuation.
library StreamArtistRecoveredPlatformProposalProof {
    // Retain the original ABI error entries for errors bubbled by the fixed kernel.
    error InvalidRecoveredHydrationProfile();
    error InvalidPlatformContinuation(uint256 collectionId);

    function advance(
        P.Platform memory platform,
        CB.Bundle memory bindings,
        A.Generation[] memory generations,
        P.Cursor memory cursor,
        RH.OwnerProvenance memory p,
        uint256 era,
        H.Envelope memory e
    ) public pure returns (P.Cursor memory) {
        return Kernel.advance(platform, bindings, generations, cursor, p, era, e, false);
    }

    function advanceWithRecords(
        P.Platform memory platform,
        CB.Bundle memory bindings,
        A.Generation[] memory generations,
        P.Cursor memory cursor,
        RH.OwnerProvenance memory p,
        uint256 era,
        H.Envelope memory e
    ) public pure returns (P.Cursor memory) {
        return Kernel.advance(platform, bindings, generations, cursor, p, era, e, true);
    }
}
