// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistRecoveredPlatformTypes as P } from "./StreamArtistRecoveredPlatformTypes.sol";
import {
    StreamArtistRecoveredPlatformCatalogue as Catalogue
} from "./StreamArtistRecoveredPlatformCatalogue.sol";
import {
    StreamArtistRecoveredPlatformNativeProof as Native
} from "./StreamArtistRecoveredPlatformNativeProof.sol";
import {
    StreamArtistRecoveredPlatformProposalProof as Proposal
} from "./StreamArtistRecoveredPlatformProposalProof.sol";
import {
    StreamArtistRecoveredPlatformCompletionProof as Completion
} from "./StreamArtistRecoveredPlatformCompletionProof.sol";
import {
    StreamArtistRecoveredBindingCorrectionTypes as CB
} from "./StreamArtistRecoveredBindingCorrectionTypes.sol";
import {
    StreamArtistRecoveredAcceptedGenerationTypes as A
} from "./StreamArtistRecoveredAcceptedGenerationTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredSanctionHistoryTypes as H
} from "./StreamArtistRecoveredSanctionHistoryTypes.sol";
import {
    StreamArtistPlatformCorrectionLineageTypes as PL
} from "../../interfaces/stream/artist/IStreamArtistPlatformCorrectionLineage.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

import {
    StreamArtistRecoveredPlatformTimelineKernel as Kernel
} from "./StreamArtistRecoveredPlatformTimelineKernel.sol";

/// @notice Exhaustive original owner4 Archive clocks, without equating revisions from different owners.
library StreamArtistRecoveredPlatformTimeline {
    // Retain the original ABI error entries for errors bubbled by the fixed kernel.
    error InvalidRecoveredHydrationProfile();

    function validate(
        P.Platform memory b,
        CB.Bundle memory bindings,
        A.Generation[] memory generations,
        RH.OwnerProvenance memory p
    ) public view returns (RH.Point[] memory proposals, RH.Point[] memory completions) {
        return Kernel.validate(b, bindings, generations, p, false);
    }

    function validateWithRecords(
        P.Platform memory b,
        CB.Bundle memory bindings,
        A.Generation[] memory generations,
        RH.OwnerProvenance memory p
    ) public view returns (RH.Point[] memory proposals, RH.Point[] memory completions) {
        return Kernel.validate(b, bindings, generations, p, true);
    }
}
