// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistRecoveredPlatformTypes as P } from "./StreamArtistRecoveredPlatformTypes.sol";
import {
    StreamArtistRecoveredPlatformSource as Source
} from "./StreamArtistRecoveredPlatformSource.sol";
import {
    StreamArtistRecoveredPlatformDisputeSource as Disputes
} from "./StreamArtistRecoveredPlatformDisputeSource.sol";
import {
    StreamArtistRecoveredPlatformBindingHydration as Binding
} from "./StreamArtistRecoveredPlatformBindingHydration.sol";
import {
    StreamArtistRecoveredHistoryRecordValidation as Validation
} from "./StreamArtistRecoveredHistoryRecordValidation.sol";
import {
    StreamArtistRecoveredHistoryRecordParts as Parts
} from "./StreamArtistRecoveredHistoryRecordParts.sol";
import {
    StreamArtistRecoveredDisputeAcceptanceHistory as Acceptance
} from "./StreamArtistRecoveredDisputeAcceptanceHistory.sol";
import {
    StreamArtistRecoveredSanctionStage as Sanctions
} from "./StreamArtistRecoveredSanctionStage.sol";
import {
    StreamArtistRecoveredSanctionRows as SanctionRows
} from "./StreamArtistRecoveredSanctionRows.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";

import {
    StreamArtistRecoveredHistoryRecordTypes as R
} from "./StreamArtistRecoveredHistoryRecordTypes.sol";
import {
    StreamArtistRecoveredHistoryRecordCollection as Records
} from "./StreamArtistRecoveredHistoryRecordCollection.sol";
import {
    StreamArtistRecoveredHistoryRecordHeads as Heads
} from "./StreamArtistRecoveredHistoryRecordHeads.sol";
import {
    StreamArtistReadinessHydrationTypes as ReadinessH
} from "../../interfaces/stream/artist/IStreamArtistReadinessAuthorityHydration.sol";
import {
    StreamArtistRecoveredHistoryRecordAuthoritySource as Authority
} from "./StreamArtistRecoveredHistoryRecordAuthoritySource.sol";
import {
    StreamArtistRecoveredAttestationHydration as Original
} from "./StreamArtistRecoveredAttestationHydration.sol";

library StreamArtistRecoveredHistoryRecordSource {
    function collect(
        T.SuiteConfiguration memory source,
        AH.Query memory q,
        RH.Provenance memory p,
        bytes memory inputs
    ) public view returns (bytes memory raw) {
        bytes[4] memory authority = Authority.collect(source, q, p);
        Original.Bundle memory records = Records.collect(
            source.owners[4],
            q,
            RH.ownerProvenance(p, 4),
            abi.decode(inputs, (ReadinessH.AttestationInput[]))
        );
        bytes[5] memory members =
            [authority[0], authority[1], authority[2], authority[3], abi.encode(records)];
        raw = abi.encode(R.ATTRIBUTION, RH.VERSION, members);
        RH.Point[] memory points = Validation.validateEncoded(raw, q, RH.ownerProvenance(p, 4));
        Heads.requireSourceEncoded(source.owners[4], raw, RH.ownerProvenance(p, 4), points);
    }
}
