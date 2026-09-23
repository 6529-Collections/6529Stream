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
    StreamArtistPlatformCorrectionLineageTypes as PL
} from "../../interfaces/stream/artist/IStreamArtistPlatformCorrectionLineage.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistBindingLifecycleTypes as L
} from "../../interfaces/stream/artist/StreamArtistBindingLifecycleTypes.sol";
import {
    StreamArtistRotationTypes as R
} from "../../interfaces/stream/artist/StreamArtistRotationTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredSanctionHistoryTypes as H
} from "./StreamArtistRecoveredSanctionHistoryTypes.sol";
import {
    StreamArtistCurrentAuthorityFacts as Authority
} from "./StreamArtistCurrentAuthorityFacts.sol";
import { StreamArtistHashes as Hashes } from "./StreamArtistHashes.sol";
import {
    IStreamArtistAcceptanceOwner as Acceptance
} from "../../interfaces/stream/artist/IStreamArtistAcceptanceOwner.sol";
import { StreamArtistAttributionStateTypes as AS } from "./StreamArtistAttributionStateTypes.sol";

import {
    StreamArtistRecoveredPlatformCompletionProofKernel as Kernel
} from "./StreamArtistRecoveredPlatformCompletionProofKernel.sol";

/// @notice Exact original zero-native op2/3/4 Attribution commits and retained continuation acceptance.
library StreamArtistRecoveredPlatformCompletionProof {
    // Retain the original ABI error entries for errors bubbled by the fixed kernel.
    error InvalidRecoveredHydrationProfile();
    error InvalidRecord();

    function advance(
        P.Platform memory platform,
        CB.Bundle memory bindings,
        A.Generation[] memory generations,
        P.Cursor memory cursor,
        RH.OwnerProvenance memory p,
        uint256 era,
        H.Envelope memory e
    ) public view returns (P.Cursor memory) {
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
    ) public view returns (P.Cursor memory) {
        return Kernel.advance(platform, bindings, generations, cursor, p, era, e, true);
    }
}
