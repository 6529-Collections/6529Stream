// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredPreparationTuple as Tuple
} from "./StreamArtistRecoveredPreparationTuple.sol";
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
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";
import {
    StreamArtistRecoveredBindingCorrectionTypes as CB
} from "./StreamArtistRecoveredBindingCorrectionTypes.sol";
import {
    StreamArtistRecoveredDisputeBindingHydration as Binding
} from "./StreamArtistRecoveredDisputeBindingHydration.sol";
import {
    StreamArtistRecoveredDisputeAcceptanceHistory as Acceptance
} from "./StreamArtistRecoveredDisputeAcceptanceHistory.sol";
import {
    StreamArtistRecoveredDisputeHistoryCollection as Collection
} from "./StreamArtistRecoveredDisputeHistoryCollection.sol";
import {
    StreamArtistRecoveredDisputeHistoryValidation as Validation
} from "./StreamArtistRecoveredDisputeHistoryValidation.sol";
import {
    StreamArtistRecoveredDisputeHistoryTypes as D
} from "./StreamArtistRecoveredDisputeHistoryTypes.sol";
import {
    StreamArtistRecoveredDisputeConsentHistory as Consent
} from "./StreamArtistRecoveredDisputeConsentHistory.sol";
import {
    StreamArtistRecoveredDisputeCompositionFacts as Facts
} from "./StreamArtistRecoveredDisputeCompositionFacts.sol";

/// @notice Closed complete history join, before the unchanged seven-owner import/Archive commit.
library StreamArtistRecoveredDisputeStage {
    function collect(
        T.SuiteConfiguration memory source,
        AH.Query memory q,
        RH.Provenance memory p,
        bytes memory identity,
        T.EconomicsConsent[] memory economics,
        uint256 royalties
    )
        public
        view
        returns (bytes memory generations, bytes memory consent, uint8 mode, bool multiple)
    {
        if (royalties != 0) revert T.UnsupportedProfile();
        CB.Bundle memory b = Binding.collect(source.owners[0], q, RH.ownerProvenance(p, 0));
        Acceptance.collect(source.owners[3], q, RH.ownerProvenance(p, 3), b.bindings);
        D.Bundle memory attribution = Collection.collect(source.owners[4], q, p, b);
        Consent.Bundle memory c =
            Consent.collect(source.owners[6], q, RH.ownerProvenance(p, 6), economics, b.bindings);
        // The original giant Identity transport is already a canonical single-tuple encoding.
        // Retain it byte-for-byte and let the fixed worker decode calldata; no memory roundtrip.
        if (address(Facts).code.length == 0) assembly ("memory-safe") { revert(0, 0) }
        (bool ok, bytes memory out) = address(Facts)
            .staticcall(
                bytes.concat(
                    Facts.validate.selector,
                    Tuple.two(identity, abi.encode(Facts.Context(b.bindings, attribution, c, q, p)))
                )
            );
        Tuple.result(ok, out);
        return (
            abi.encode(b.bindings),
            Consent.encode(c, q, RH.ownerProvenance(p, 6)),
            b.bindings.current.consentMode,
            b.bindings.rows.length > 1
        );
    }

    function ownerState(
        T.SuiteConfiguration memory source,
        AH.Query memory q,
        RH.Provenance memory p,
        bytes memory raw,
        uint8 ownerIndex
    ) public view returns (bytes memory) {
        CB.Bundle memory b = Binding.collect(source.owners[0], q, RH.ownerProvenance(p, 0));
        if (keccak256(raw) != keccak256(abi.encode(b.bindings))) {
            revert RH.InvalidRecoveredHydrationProfile();
        }
        if (ownerIndex == 0) {
            return Binding.encodeCollected(source.owners[0], raw, q, RH.ownerProvenance(p, 0));
        }
        if (ownerIndex == 3) {
            return Acceptance.encode(
                Acceptance.collect(source.owners[3], q, RH.ownerProvenance(p, 3), b.bindings),
                q,
                RH.ownerProvenance(p, 3)
            );
        }
        if (ownerIndex == 4) {
            return
                Validation.encode(
                    Collection.collect(source.owners[4], q, p, b), q, RH.ownerProvenance(p, 4)
                );
        }
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
