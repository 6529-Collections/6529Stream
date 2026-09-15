// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistReadinessHydrationFacts.sol";
import "../../interfaces/stream/artist/IStreamArtistPublicationAuthorityHydration.sol";
import {
    StreamArtistReadinessHydrationTypes as RH
} from "../../interfaces/stream/artist/IStreamArtistReadinessAuthorityHydration.sol";
import "./StreamArtistEconomicsHydration.sol";
import {
    StreamArtistEconomicsHydrationTypes as EH
} from "../../interfaces/stream/artist/IStreamArtistEconomicsAuthorityHydration.sol";
import "../../interfaces/stream/artist/IStreamArtistConsentOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistPayoutTransitionOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistPayoutOwner.sol";
import {
    StreamArtistRotationTypes as HydrationRotation
} from "../../interfaces/stream/artist/StreamArtistRotationTypes.sol";
import "../../interfaces/stream/artist/IStreamArtistPayoutAuthorityHydration.sol";
import {
    StreamArtistPayoutHydrationTypes as PH
} from "../../interfaces/stream/artist/IStreamArtistPayoutAuthorityHydration.sol";
import "./StreamArtistHistoryOperations.sol";
import "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import "../../interfaces/stream/artist/IStreamArtistIngressBinding.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    IStreamArtistAuthorityCheckpoint as CP
} from "../../interfaces/stream/artist/IStreamArtistAuthorityCheckpoint.sol";

import "./StreamArtistHydrationPrepared.sol";
import "./StreamArtistHydrationSourceGuards.sol";
import "../../interfaces/stream/artist/IStreamArtistEntropyFindingHydration.sol";
import {
    StreamArtistEntropyFindingHydrationTypes as FH
} from "../../interfaces/stream/artist/IStreamArtistEntropyFindingHydration.sol";

/// @notice Fixed final typed reads in original seven-owner order; all guard checks remain.
library StreamArtistHydrationSourceState {
    function collect(
        T.SuiteConfiguration memory source,
        address sourceCoordinator,
        AH.Request memory p,
        AH.Query memory q,
        T.EconomicsConsent[] memory economics,
        RH.AttestationInput[] memory attestations,
        bool publications,
        bool findings
    ) public view returns (AH.OwnerData[7] memory data) {
        bool readiness = attestations.length != 0;
        for (uint256 i; i < 7; ++i) {
            data[i] = StreamArtistHydrationSourceGuards._guards(source, sourceCoordinator, i, p);
            data[i].typedState = findings && i == 2
                ? IStreamArtistEntropyFindingHydrationOwner(source.owners[i])
                    .authorityEntropyFindingHydrationState(q)
                : publications && i == 4
                    ? IStreamArtistPublicationHydrationOwner(source.owners[i])
                        .authorityPublicationHydrationState(q, attestations)
                    : readiness && i == 4
                        ? IStreamArtistReadinessAttributionOwner(source.owners[i])
                            .authorityAttestationHydrationState(q, attestations)
                        : readiness && i == 6
                            ? IStreamArtistReadinessConsentOwner(source.owners[i])
                                .authorityReadinessHydrationState(q, economics)
                            : i == 6 && economics.length != 0
                                ? IStreamArtistEconomicsAuthorityHydrationOwner(source.owners[i])
                                    .authorityEconomicsHydrationState(q, economics)
                                : IStreamArtistAuthorityHydrationOwner(source.owners[i])
                                    .authorityHydrationState(q);
        }
    }
}
