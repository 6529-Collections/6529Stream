// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredHistoryContentSelection as HistorySelection
} from "./StreamArtistRecoveredHistoryContentSelection.sol";
import {
    StreamArtistRecoveredPlatformCurrent as Current
} from "./StreamArtistRecoveredPlatformCurrent.sol";
import {
    StreamArtistRecoveredDisputeHistoryTypes as D
} from "./StreamArtistRecoveredDisputeHistoryTypes.sol";
import {
    StreamArtistRecoveredSanctionHistoryTypes as H
} from "./StreamArtistRecoveredSanctionHistoryTypes.sol";
import {
    StreamArtistRecoveredBindingCorrectionTypes as CB
} from "./StreamArtistRecoveredBindingCorrectionTypes.sol";
import { StreamArtistRecoveredPlatformTypes as P } from "./StreamArtistRecoveredPlatformTypes.sol";
import {
    StreamArtistRecoveredHistoryRecordSource as Collection
} from "./StreamArtistRecoveredHistoryRecordSource.sol";
import {
    StreamArtistRecoveredHistoryRecordParts as Parts
} from "./StreamArtistRecoveredHistoryRecordParts.sol";
import {
    StreamArtistRecoveredPlatformCatalogue as Catalogue
} from "./StreamArtistRecoveredPlatformCatalogue.sol";
import {
    StreamArtistRecoveredDisputeConsentHistory as Base
} from "./StreamArtistRecoveredDisputeConsentHistory.sol";
import {
    StreamArtistRecoveredDisputeCompositionFacts as BaseFacts
} from "./StreamArtistRecoveredDisputeCompositionFacts.sol";
import {
    StreamArtistRecoveredSanctionConsentCollection as SanctionConsent
} from "./StreamArtistRecoveredSanctionConsentCollection.sol";
import {
    StreamArtistRecoveredSanctionConsentHistory as SanctionCodec
} from "./StreamArtistRecoveredSanctionConsentHistory.sol";
import {
    StreamArtistRecoveredSanctionCompositionFacts as SanctionFacts
} from "./StreamArtistRecoveredSanctionCompositionFacts.sol";
import {
    StreamArtistRecoveredSanctionCatalogue as SanctionCatalogue
} from "./StreamArtistRecoveredSanctionCatalogue.sol";
import {
    StreamArtistRecoveredHistoryContentCollection as Content
} from "./StreamArtistRecoveredHistoryContentCollection.sol";
import {
    StreamArtistRecoveredHistoryContentFacts as ContentFacts
} from "./StreamArtistRecoveredHistoryContentFacts.sol";
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

/// @notice Complete Platform authority plus the unchanged base/sanction/content consent codecs.
import {
    StreamArtistRecoveredHistoryRecordFacts as Facts
} from "./StreamArtistRecoveredHistoryRecordFacts.sol";
import {
    StreamArtistRecoveredAttestationHydration as Attest
} from "./StreamArtistRecoveredAttestationHydration.sol";
import {
    StreamArtistRecoveredHistoryRecordFactsFrame as Frame
} from "./StreamArtistRecoveredHistoryRecordFactsFrame.sol";
import {
    StreamArtistRecoveredHistoryRecordCurrent as RecordCurrent
} from "./StreamArtistRecoveredHistoryRecordCurrent.sol";
import {
    StreamArtistRecoveredPlatformStage as OriginalPlatformStage
} from "./StreamArtistRecoveredPlatformStage.sol";

library StreamArtistRecoveredHistoryRecordStage {
    function collect(
        T.SuiteConfiguration memory source,
        AH.Query memory q,
        RH.Provenance memory p,
        bytes memory identityAndInputs,
        T.EconomicsConsent[] memory economics,
        T.RoyaltyFreeze[] memory royalties,
        bool sanctioned
    )
        public
        view
        returns (
            bytes memory generations,
            bytes memory consent,
            uint8 mode,
            bool multiple,
            uint256 features
        )
    {
        (bytes memory identity, bytes memory inputs) = abi.decode(identityAndInputs, (bytes, bytes));
        if (keccak256(identityAndInputs) != keccak256(abi.encode(identity, inputs))) {
            revert RH.InvalidRecoveredHydrationProfile();
        }
        // Witnesses.collect returns abi.encode(AttestationInput[]); its exact empty form is
        // two words (offset 32, count 0). A nonempty array is validated by Collection below.
        if (inputs.length == 64) {
            (uint256 offset, uint256 count) = abi.decode(inputs, (uint256, uint256));
            if (offset != 32 || count != 0) revert RH.InvalidRecoveredHydrationProfile();
            return OriginalPlatformStage.collect(
                source, q, p, identity, economics, royalties, sanctioned
            );
        }
        bytes memory raw = Collection.collect(source, q, p, inputs);
        bytes[5] memory parts = Parts.members(raw);
        H.Inventory memory sanctions = abi.decode(parts[1], (H.Inventory));
        CB.Bundle memory binding = abi.decode(parts[3], (CB.Bundle));
        bool content;
        for (uint256 i; i < p.journals[6].length; ++i) {
            uint16 op = p.journals[6][i].receipt.operation;
            if (op == 17 || op == 20 || op == 21 || op == 52) content = true;
        }
        features = RH.DISPUTE_HISTORY | RH.HISTORY_RECORDS | RH.ATTESTATIONS;
        for (uint256 i; i < p.journals[4].length; ++i) {
            if (P.nativeOperation(p.journals[4][i].receipt.operation)) {
                features |= RH.HISTORY_PLATFORM;
            }
        }
        if (sanctioned) features |= RH.SANCTION_HISTORY;
        if (content) features |= RH.HISTORY_CONTENT;
        bytes memory call_;
        address facts;
        if (content) {
            consent = Content.collect(
                source.owners[6],
                q,
                RH.ownerProvenance(p, 6),
                economics,
                royalties,
                binding.bindings,
                sanctions
            );
        } else if (sanctions.sanctions.length != 0) {
            if (royalties.length != 0) revert T.UnsupportedProfile();
            SanctionCodec.Bundle memory c = SanctionConsent.collect(
                source.owners[6],
                q,
                RH.ownerProvenance(p, 6),
                economics,
                binding.bindings,
                sanctions
            );
            consent = SanctionCodec.encode(c, q, RH.ownerProvenance(p, 6));
        } else {
            if (royalties.length != 0) revert T.UnsupportedProfile();
            Base.Bundle memory c = Base.collect(
                source.owners[6], q, RH.ownerProvenance(p, 6), economics, binding.bindings
            );
            consent = Base.encode(c, q, RH.ownerProvenance(p, 6));
        }
        facts = address(Facts);
        call_ = bytes.concat(
            Facts.validate.selector, Tuple.two(identity, Frame.frame(raw, consent, q, p))
        );
        if (facts.code.length == 0) assembly ("memory-safe") { revert(0, 0) }
        (bool ok, bytes memory out) = facts.staticcall(call_);
        Tuple.result(ok, out);
        if (sanctions.sanctions.length != 0) {
            SanctionCatalogue.requireCurrent(p, sanctions.catalogues, sanctions.operations);
        }
        RecordCurrent.requireCurrent(p, raw);
        return (
            raw,
            consent,
            binding.bindings.current.consentMode,
            binding.bindings.rows.length > 1,
            features
        );
    }
}
