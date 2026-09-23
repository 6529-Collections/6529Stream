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
    StreamArtistRecoveredPlatformValidation as Validation
} from "./StreamArtistRecoveredPlatformValidation.sol";
import {
    StreamArtistRecoveredPlatformParts as Parts
} from "./StreamArtistRecoveredPlatformParts.sol";
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

library StreamArtistRecoveredHistoryRecordAuthoritySource {
    function collect(T.SuiteConfiguration memory source, AH.Query memory q, RH.Provenance memory p)
        public
        view
        returns (bytes[4] memory parts)
    {
        P.Bundle memory b;
        b.bindings = Binding.collect(source.owners[0], q, RH.ownerProvenance(p, 0));
        Acceptance.collect(source.owners[3], q, RH.ownerProvenance(p, 3), b.bindings.bindings);
        b.platform = Source.collect(source.owners[4], q, p);
        b.original = Disputes.collectWithRecords(source.owners[4], q, p, b.bindings);
        if (Sanctions.selected(p)) {
            b.sanctions = SanctionRows.collect(source.owners[6], q, p, b.bindings.bindings);
        }
        return [
            abi.encode(b.original),
            abi.encode(b.sanctions),
            abi.encode(b.platform),
            abi.encode(b.bindings)
        ];
    }
}
