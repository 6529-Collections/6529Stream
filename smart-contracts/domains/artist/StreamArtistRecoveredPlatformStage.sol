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
    StreamArtistRecoveredPlatformCollection as Collection
} from "./StreamArtistRecoveredPlatformCollection.sol";
import {
    StreamArtistRecoveredPlatformParts as Parts
} from "./StreamArtistRecoveredPlatformParts.sol";
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
library StreamArtistRecoveredPlatformStage {
    /// @notice Exact adjacent source selections in their original order, without two host encoders.
    function select(T.SuiteConfiguration memory source, AH.Query memory q, RH.Provenance memory p)
        public
        view
        returns (uint8 route, bool sanctioned, bool platformHistory)
    {
        (route, sanctioned) = HistorySelection.select(source, q, p);
        platformHistory = Collection.selected(p);
    }

    function collect(
        T.SuiteConfiguration memory source,
        AH.Query memory q,
        RH.Provenance memory p,
        bytes memory identity,
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
        bytes memory raw = Collection.collect(source, q, p);
        bytes[4] memory parts = Parts.members(raw);
        D.Bundle memory attribution = abi.decode(parts[0], (D.Bundle));
        H.Inventory memory sanctions = abi.decode(parts[1], (H.Inventory));
        CB.Bundle memory binding = abi.decode(parts[3], (CB.Bundle));
        bool content;
        for (uint256 i; i < p.journals[6].length; ++i) {
            uint16 op = p.journals[6][i].receipt.operation;
            if (op == 17 || op == 20 || op == 21 || op == 52) content = true;
        }
        features = RH.DISPUTE_HISTORY | RH.HISTORY_PLATFORM;
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
            facts = address(ContentFacts);
            call_ = bytes.concat(
                ContentFacts.validate.selector,
                Tuple.two(
                    identity,
                    abi.encode(ContentFacts.Context(binding.bindings, attribution, consent, q, p))
                )
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
            facts = address(SanctionFacts);
            call_ = bytes.concat(
                SanctionFacts.validate.selector,
                Tuple.two(
                    identity,
                    abi.encode(
                        SanctionFacts.Context(
                            binding.bindings, attribution, c.base, q, p, sanctions
                        )
                    )
                )
            );
        } else {
            if (royalties.length != 0) revert T.UnsupportedProfile();
            Base.Bundle memory c = Base.collect(
                source.owners[6], q, RH.ownerProvenance(p, 6), economics, binding.bindings
            );
            consent = Base.encode(c, q, RH.ownerProvenance(p, 6));
            facts = address(BaseFacts);
            call_ = bytes.concat(
                BaseFacts.validate.selector,
                Tuple.two(
                    identity, abi.encode(BaseFacts.Context(binding.bindings, attribution, c, q, p))
                )
            );
        }
        if (facts.code.length == 0) assembly ("memory-safe") { revert(0, 0) }
        (bool ok, bytes memory out) = facts.staticcall(call_);
        Tuple.result(ok, out);
        if (sanctions.sanctions.length != 0) {
            SanctionCatalogue.requireCurrent(p, sanctions.catalogues, sanctions.operations);
        }
        Current.requireCurrent(p, raw);
        return (
            abi.encode(binding.bindings),
            consent,
            binding.bindings.current.consentMode,
            binding.bindings.rows.length > 1,
            features
        );
    }
}
