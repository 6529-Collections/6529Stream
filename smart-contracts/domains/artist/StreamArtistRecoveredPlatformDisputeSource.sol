// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredPlatformTypes as PLH
} from "./StreamArtistRecoveredPlatformTypes.sol";
import {
    StreamArtistRecoveredDisputeHistoryTypes as D
} from "./StreamArtistRecoveredDisputeHistoryTypes.sol";
import {
    StreamArtistRecoveredDisputeHistoryValidation as Validation
} from "./StreamArtistRecoveredDisputeHistoryValidation.sol";
import {
    StreamArtistRecoveredPlatformBindingValidation as Binding
} from "./StreamArtistRecoveredPlatformBindingValidation.sol";
import {
    StreamArtistRecoveredBindingCorrectionTypes as CB
} from "./StreamArtistRecoveredBindingCorrectionTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    IStreamArtistAttributionOwner as Attribution
} from "../../interfaces/stream/artist/IStreamArtistAttributionOwner.sol";
import {
    IStreamArtistAttributionDisputesOwner as Disputes,
    StreamArtistAttributionDisputeTypes as AD
} from "../../interfaces/stream/artist/IStreamArtistAttributionDisputes.sol";
import {
    IStreamArtistDisputeWithdrawalOwner as Withdrawal
} from "../../interfaces/stream/artist/IStreamArtistDisputeWithdrawal.sol";
import {
    IStreamArtistRepudiationOwner as Repudiation
} from "../../interfaces/stream/artist/IStreamArtistAttributionRepudiation.sol";
import {
    IStreamArtistPlatformOwner as Platform
} from "../../interfaces/stream/artist/IStreamArtistPlatformWorks.sol";
import {
    StreamArtistPlatformTypes as PW
} from "../../interfaces/stream/artist/StreamArtistPlatformTypes.sol";
import {
    StreamArtistRecoveredHydrationProvenance as P
} from "./StreamArtistRecoveredHydrationProvenance.sol";
import {
    StreamArtistRecoveredHydrationChronology as Clock
} from "./StreamArtistRecoveredHydrationChronology.sol";

import {
    StreamArtistRecoveredPlatformDisputeSourceKernel as Kernel
} from "./StreamArtistRecoveredPlatformDisputeSourceKernel.sol";

/// @notice Every key comes from the original native journal or its complete replay inventory.
library StreamArtistRecoveredPlatformDisputeSource {
    // Retain the original ABI error entries for errors bubbled by the fixed kernel.
    error InvalidRecoveredHydrationProfile();
    error InvalidPlatformContinuation(uint256 collectionId);

    function collect(
        address source,
        AH.Query memory q,
        RH.Provenance memory p,
        CB.Bundle memory bindings
    ) public view returns (D.Bundle memory b) {
        return Kernel.collect(source, q, p, bindings, false);
    }

    function collectWithRecords(
        address source,
        AH.Query memory q,
        RH.Provenance memory p,
        CB.Bundle memory bindings
    ) public view returns (D.Bundle memory b) {
        return Kernel.collect(source, q, p, bindings, true);
    }
}
