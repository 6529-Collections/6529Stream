// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredMultipleDisputeCurrent as Disputes
} from "./StreamArtistRecoveredMultipleDisputeCurrent.sol";
import {
    StreamArtistExtendedHydrationFeatures as XF
} from "../../interfaces/stream/artist/StreamArtistExtendedHydrationFeatures.sol";
import { StreamArtistRecoveredMultipleGenerationCurrent as Generations } from "./StreamArtistRecoveredMultipleGenerationCurrent.sol";
import {
    StreamArtistRecoveredPlatformCurrent as Current
} from "./StreamArtistRecoveredPlatformCurrent.sol";
import {
    StreamArtistRecoveredHistoryRecordValidation as Validation
} from "./StreamArtistRecoveredHistoryRecordValidation.sol";
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
    StreamArtistRecoveredHistoryRecordParts as Parts
} from "./StreamArtistRecoveredHistoryRecordParts.sol";
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

import {
    StreamArtistRecoveredHistoryRecordTypes as R
} from "./StreamArtistRecoveredHistoryRecordTypes.sol";
import {
    StreamArtistRecoveredAttestationHydration as Attest
} from "./StreamArtistRecoveredAttestationHydration.sol";
import {
    StreamArtistRecoveredPlatformRouting as Original
} from "./StreamArtistRecoveredPlatformRouting.sol";
import {
    StreamArtistRecoveredHistoryRecordCurrent as RecordCurrent
} from "./StreamArtistRecoveredHistoryRecordCurrent.sol";

library StreamArtistRecoveredHistoryRecordRouting {
    function ownerState(
        T.SuiteConfiguration memory source,
        AH.Query memory q,
        RH.Provenance memory p,
        bytes memory complete,
        uint8 ownerIndex
    ) public view returns (bytes memory) {
        bytes[5] memory parts = Parts.members(complete);
        if (ownerIndex == 0) {
            CB.Bundle memory fresh = Binding.collect(source.owners[0], q, RH.ownerProvenance(p, 0));
            if (keccak256(parts[3]) != keccak256(abi.encode(fresh))) _invalid();
            return abi.encode(R.BINDING, RH.VERSION, fresh);
        }
        CB.Bundle memory b = abi.decode(parts[3], (CB.Bundle));
        if (ownerIndex == 3) {
            return Acceptance.encode(
                Acceptance.collect(source.owners[3], q, RH.ownerProvenance(p, 3), b.bindings),
                q,
                RH.ownerProvenance(p, 3)
            );
        }
        if (ownerIndex == 4) {
            Validation.validateEncoded(complete, q, RH.ownerProvenance(p, 4));
            RecordCurrent.requireCurrent(p, complete);
            return complete;
        }
        _invalid();
    }

    function requireCurrent(RH.Provenance memory p, AH.Query memory q, bytes memory outer)
        public
        view
    {
        (RH.ExportHeader memory h, Payload.Payload memory payload) = Payload.decode(outer, 4);
        if ((h.requiredFeatures & XF.MULTIPLE_DISPUTE_HISTORY) != 0) {
            Disputes.requireCurrent(p, q, outer);
            return;
        }
        if ((h.requiredFeatures & XF.MULTIPLE_GENERATIONS) != 0) {
            Generations.requireCurrent(p,q,outer);
            return;
        }
        if ((h.requiredFeatures & RH.HISTORY_RECORDS) == 0) {
            Original.requireCurrent(p, q, outer);
            return;
        }
        Validation.validateEncoded(payload.semanticState, q, payload.provenance);
        RecordCurrent.requireCurrent(p, payload.semanticState);
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
