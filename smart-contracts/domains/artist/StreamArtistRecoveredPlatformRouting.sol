// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredPlatformCurrent as Current
} from "./StreamArtistRecoveredPlatformCurrent.sol";
import {
    StreamArtistRecoveredPlatformValidation as Validation
} from "./StreamArtistRecoveredPlatformValidation.sol";
import {
    StreamArtistRecoveredBindingCorrectionTypes as CB
} from "./StreamArtistRecoveredBindingCorrectionTypes.sol";
import { StreamArtistRecoveredPlatformTypes as P } from "./StreamArtistRecoveredPlatformTypes.sol";
import {
    StreamArtistRecoveredPlatformCollection as Collection
} from "./StreamArtistRecoveredPlatformCollection.sol";
import {
    StreamArtistRecoveredPlatformBindingHydration as Binding
} from "./StreamArtistRecoveredPlatformBindingHydration.sol";
import {
    StreamArtistRecoveredPlatformCodec as Codec
} from "./StreamArtistRecoveredPlatformCodec.sol";
import {
    StreamArtistRecoveredPlatformParts as Parts
} from "./StreamArtistRecoveredPlatformParts.sol";
import {
    StreamArtistRecoveredPlatformCatalogue as Catalogue
} from "./StreamArtistRecoveredPlatformCatalogue.sol";
import {
    StreamArtistRecoveredDisputeAcceptanceHistory as Acceptance
} from "./StreamArtistRecoveredDisputeAcceptanceHistory.sol";
import {
    StreamArtistRecoveredHydrationOwnerPayload as Payload
} from "./StreamArtistRecoveredHydrationOwnerPayload.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";

library StreamArtistRecoveredPlatformRouting {
    function ownerState(
        T.SuiteConfiguration memory source,
        AH.Query memory q,
        RH.Provenance memory p,
        bytes memory raw,
        uint8 ownerIndex
    ) public view returns (bytes memory) {
        if (ownerIndex == 0) {
            return Binding.encodeCollected(source.owners[0], raw, q, RH.ownerProvenance(p, 0));
        }
        bytes memory collected = Collection.collect(source, q, p);
        bytes[4] memory parts = Parts.members(collected);
        CB.Bundle memory b = abi.decode(parts[3], (CB.Bundle));
        if (keccak256(raw) != keccak256(abi.encode(b.bindings))) _invalid();
        if (ownerIndex == 3) {
            return Acceptance.encode(
                Acceptance.collect(source.owners[3], q, RH.ownerProvenance(p, 3), b.bindings),
                q,
                RH.ownerProvenance(p, 3)
            );
        }
        if (ownerIndex == 4) return collected;
        _invalid();
    }

    function requireCurrent(RH.Provenance memory p, AH.Query memory q, bytes memory outer)
        public
        view
    {
        (RH.ExportHeader memory h, Payload.Payload memory payload) = Payload.decode(outer, 4);
        if ((h.requiredFeatures & RH.HISTORY_PLATFORM) == 0) return;
        Validation.validateEncoded(payload.semanticState, q, payload.provenance);
        Current.requireCurrent(p, payload.semanticState);
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
