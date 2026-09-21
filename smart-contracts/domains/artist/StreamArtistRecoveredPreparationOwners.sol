// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredSanctionRouting as SanctionRouting
} from "./StreamArtistRecoveredSanctionRouting.sol";
import { StreamArtistRecoveredDisputeStage as DisputeStage } from "./StreamArtistRecoveredDisputeStage.sol";
import { StreamArtistRecoveredAcceptedBindingHydration as AcceptedBinding } from "./StreamArtistRecoveredAcceptedBindingHydration.sol";
import { StreamArtistRecoveredAcceptedGenerationStage as AcceptedStage } from "./StreamArtistRecoveredAcceptedGenerationStage.sol";
import {
    StreamArtistRecoveredBindingCorrectionHydration as Corrections
} from "./StreamArtistRecoveredBindingCorrectionHydration.sol";
import {
    StreamArtistRecoveredPayloadHydration as Publications
} from "./StreamArtistRecoveredPayloadHydration.sol";

import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    IStreamArtistRecoveredHydrationOwner as Owner
} from "../../interfaces/stream/artist/IStreamArtistRecoveredHydration.sol";
import {
    StreamArtistRecoveredHydrationOwnerPayload as Payload
} from "./StreamArtistRecoveredHydrationOwnerPayload.sol";
import {
    StreamArtistRecoveredHydrationGuards as Guards
} from "./StreamArtistRecoveredHydrationGuards.sol";
import {
    StreamArtistRecoveredHydrationCodec as Codec
} from "./StreamArtistRecoveredHydrationCodec.sol";
import {
    StreamArtistRecoveredPayoutHydration as Payout
} from "./StreamArtistRecoveredPayoutHydration.sol";
import {
    StreamArtistRecoveredEconomicsHydration as Economics
} from "./StreamArtistRecoveredEconomicsHydration.sol";
import {
    StreamArtistRecoveredPreparationPayout as PayoutStage
} from "./StreamArtistRecoveredPreparationPayout.sol";
import {
    StreamArtistRecoveredPreparationIdentityEncode as IdentityEncode
} from "./StreamArtistRecoveredPreparationIdentityEncode.sol";
import {
    StreamArtistRecoveredPreparationAttestations as AttestationStage
} from "./StreamArtistRecoveredPreparationAttestations.sol";
import {
    StreamArtistRecoveredPreparationConsents as ConsentStage
} from "./StreamArtistRecoveredPreparationConsents.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistRecoveredPreparationGenerations as GenerationStage
} from "./StreamArtistRecoveredPreparationGenerations.sol";

import {
    StreamArtistRecoveredRatificationStage as RatificationStage
} from "./StreamArtistRecoveredRatificationStage.sol";

/// @notice Original ordered seven-owner payload construction after complete source joins.
library StreamArtistRecoveredPreparationOwners {
    struct Context {
        T.SuiteConfiguration source;
        T.SuiteConfiguration destination;
        RH.Provenance provenance;
        AH.Query query;
        RH.Capability[7] expected;
        AH.Origin[][7] replayOrigins;
        uint256 features;
        bytes identity;
        bytes payout;
        bytes attestations;
        bytes consent;
        T.EconomicsConsent[] economics;
        bool hasAttestations;
        bool hasDelegation;
        bool hasContent;
        bytes generations;
        bool hasGenerations;
    }

    function collect(Context memory c) public view returns (AH.OwnerData[7] memory data) {
        for (uint8 i; i < 7; ++i) {
            _capabilities(c.source.owners[i], c.destination.owners[i], i, c.features, c.expected[i]);
            Payload.Payload memory payload;
            payload.provenance = RH.ownerProvenance(c.provenance, i);
            payload.publications = Publications.collect(c.source.owners[i], i);
            (data[i], payload.nonces) = Guards.collect(c.provenance, i, c.replayOrigins[i]);
            if ((i == 0 || i == 3 || i == 4) && (c.features & RH.SANCTION_HISTORY) != 0) {
                payload.semanticState =
                    SanctionRouting.ownerState(c.source, c.query, c.provenance, c.generations, i);
            } else if ((i == 0 || i == 3 || i == 4) && (c.features & RH.DISPUTE_HISTORY) != 0) {
                payload.semanticState = DisputeStage.ownerState(c.source,c.query,c.provenance,c.generations,i);
            } else if (i == 6 && (c.features & RH.DISPUTE_HISTORY) != 0) {
                payload.semanticState = c.consent;
            } else if (i == 0 && (c.features & RH.ACCEPTED_GENERATIONS) != 0) {
                payload.semanticState = AcceptedBinding.encodeCollected(c.source.owners[0], c.generations, c.query, payload.provenance);
            } else if ((i == 3 || i == 4) && (c.features & RH.ACCEPTED_GENERATIONS) != 0) {
                payload.semanticState = AcceptedStage.ownerState(c.source, c.query, c.provenance, c.generations, i);
            } else if (i == 0 && c.hasGenerations) {
                payload.semanticState = (c.features & RH.BINDING_CORRECTIONS) != 0
                    ? Corrections.encodeCollected(
                        c.source.owners[0], c.generations, c.query, payload.provenance
                    )
                    : GenerationStage.encode(c.generations, c.query, payload.provenance);
            } else if (i == 2) {
                payload.semanticState =
                    IdentityEncode.encode(c.identity, payload.provenance, payload.nonces);
            } else if (i == 4 && c.hasAttestations) {
                payload.semanticState =
                    AttestationStage.encode(c.attestations, c.query, payload.provenance);
            } else if (i == 5) {
                // The joined validator binds original Identity35/nonce admission and retained
                // Payout continuations; an owner-local export alone is insufficient here.
                payload.semanticState = PayoutStage.encode(c.payout, c.provenance);
            } else if (i == 6 && (c.features & RH.RATIFICATIONS) != 0) {
                payload.semanticState =
                    RatificationStage.encode(c.consent, c.query, payload.provenance);
            } else if (
                i == 6 && c.hasGenerations && !c.hasContent
                    && (c.hasDelegation || c.economics.length != 0)
            ) {
                payload.semanticState = ConsentStage.encodeGenerationBase(
                    c.consent, c.query, payload.provenance
                );
            } else if (i == 6 && c.hasContent) {
                payload.semanticState =
                    ConsentStage.encode(c.consent, true, c.query, payload.provenance);
            } else if (i == 6 && c.hasDelegation) {
                payload.semanticState =
                    ConsentStage.encode(c.consent, false, c.query, payload.provenance);
            } else if (i == 6 && c.economics.length != 0) {
                payload.semanticState = Economics.encode(
                    Economics.collect(c.source.owners[i], c.query, payload.provenance, c.economics),
                    c.query,
                    payload.provenance
                );
            } else {
                payload.semanticState = Owner(c.source.owners[i])
                    .recoveredAuthorityHydrationState(c.query, payload.provenance);
            }
            data[i].typedState = Payload.encode(i, _header(i, c.features, payload), payload);
        }
    }

    function _capabilities(
        address source,
        address destination,
        uint8 i,
        uint256 features,
        RH.Capability memory expected
    ) private view {
        RH.Capability memory actual = Owner(source).recoveredAuthorityHydrationCapability();
        if (keccak256(abi.encode(actual)) != keccak256(abi.encode(expected))) {
            revert RH.InvalidRecoveredHydrationProfile();
        }
        Codec.requireCapability(actual, i, features);
        Codec.requireCapability(
            Owner(destination).recoveredAuthorityHydrationCapability(), i, features
        );
    }

    function _header(uint8 i, uint256 features, Payload.Payload memory p)
        private
        pure
        returns (RH.ExportHeader memory h)
    {
        RH.OwnerEra memory last = p.provenance.eras[p.provenance.eras.length - 1];
        h = RH.ExportHeader(
            RH.PROFILE,
            RH.VERSION,
            i,
            last.originHash,
            last.priorImportCommitment,
            keccak256(p.semanticState),
            RH.ownerProvenanceHash(p.provenance, i),
            RH.aliasesHash(i, p.provenance.aliases),
            features,
            p.provenance.journal.length,
            p.provenance.aliases.length,
            p.provenance.eras.length
        );
    }
}
