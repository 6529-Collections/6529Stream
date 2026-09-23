// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredDisputeHistoryTypes as D
} from "./StreamArtistRecoveredDisputeHistoryTypes.sol";
import {
    StreamArtistRecoveredAcceptedGenerationTypes as A
} from "./StreamArtistRecoveredAcceptedGenerationTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
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
    StreamArtistRecoveredHydrationProvenance as P
} from "./StreamArtistRecoveredHydrationProvenance.sol";
import {
    StreamArtistRecoveredHydrationChronology as Clock
} from "./StreamArtistRecoveredHydrationChronology.sol";
import { StreamArtistDisputeHashes as H } from "./StreamArtistDisputeHashes.sol";
import { StreamArtistRepudiationHashes as RHash } from "./StreamArtistRepudiationHashes.sol";
import { StreamArtistHashes as Hashes } from "./StreamArtistHashes.sol";

import {
    StreamArtistRecoveredPlatformTypes as Platform
} from "./StreamArtistRecoveredPlatformTypes.sol";

import {
    StreamArtistRecoveredPlatformDisputeRowsKernel as Kernel
} from "./StreamArtistRecoveredPlatformDisputeRowsKernel.sol";

/// @notice Original dispute rows beside the separately authenticated complete Platform rows.
library StreamArtistRecoveredPlatformDisputeRows {
    // Retain the original ABI error entries for errors bubbled by the fixed kernel.
    error InvalidRecoveredHydrationProfile();

    function validate(
        D.Bundle memory b,
        AH.Query memory q,
        RH.OwnerProvenance memory p,
        Platform.Platform memory platform
    ) public pure {
        Kernel.validate(b, q, p, true, Platform.nativeCount(platform), 0);
    }

    function validateWithRecords(
        D.Bundle memory b,
        AH.Query memory q,
        RH.OwnerProvenance memory p,
        Platform.Platform memory platform
    ) public pure {
        uint256 count;
        for (uint256 i; i < p.journal.length; ++i) {
            if (p.journal[i].receipt.operation == 24) ++count;
        }
        Kernel.validate(b, q, p, true, Platform.nativeCount(platform), count);
    }
}
