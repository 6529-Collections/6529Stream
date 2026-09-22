// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    IStreamArtistAttributionDisputesOwner as DisputeOwner,
    StreamArtistAttributionDisputeTypes as AD
} from "../../interfaces/stream/artist/IStreamArtistAttributionDisputes.sol";
import {
    IStreamArtistAttributionOwner as AttributionOwner
} from "../../interfaces/stream/artist/IStreamArtistAttributionOwner.sol";
import {
    StreamArtistRecoveredMultipleDisputeOwners as Owners
} from "./StreamArtistRecoveredMultipleDisputeOwners.sol";
import {
    StreamArtistRecoveredMultipleTypes as M
} from "../../interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistRecoveredTimingTypes as TM
} from "../../interfaces/stream/artist/StreamArtistRecoveredTimingTypes.sol";
import {
    StreamArtistRecoveredHydrationAdmission as Admission
} from "./StreamArtistRecoveredHydrationAdmission.sol";
import {
    StreamArtistRecoveredMultipleConsentIdentitySource as Identity
} from "./StreamArtistRecoveredMultipleConsentIdentitySource.sol";
import {
    StreamArtistRecoveredMultipleDisputeCodec as Codec
} from "./StreamArtistRecoveredMultipleDisputeCodec.sol";
import {
    StreamArtistRecoveredPreparationPayout as Payout
} from "./StreamArtistRecoveredPreparationPayout.sol";
import {
    StreamArtistRecoveredPreparationEvidence as Evidence
} from "./StreamArtistRecoveredPreparationEvidence.sol";
import {
    StreamArtistRecoveredExternalGuards as External
} from "./StreamArtistRecoveredExternalGuards.sol";
import {
    StreamArtistRecoveredPreparationTuple as Tuple
} from "./StreamArtistRecoveredPreparationTuple.sol";
import {
    StreamArtistRecoveredMultipleDisputeWitnesses as Witnesses
} from "./StreamArtistRecoveredMultipleDisputeWitnesses.sol";
import {
    IStreamArtistBindingOwner as Binding
} from "../../interfaces/stream/artist/IStreamArtistBindingOwner.sol";
import {
    StreamArtistRecoveredMultipleDisputeComposition as Composition
} from "./StreamArtistRecoveredMultipleDisputeComposition.sol";
import {
    StreamArtistRecoveredMultipleObservations as Observations
} from "./StreamArtistRecoveredMultipleObservations.sol";
import {
    StreamArtistRecoveredMultipleDisputeTypes as MD
} from "./StreamArtistRecoveredMultipleDisputeTypes.sol";

/// @notice Distinct complete aggregate composition for original Consent14/15/16/17/20/21 and grants.

library StreamArtistRecoveredMultipleDisputePreparation {
    struct Context {
        T.SuiteConfiguration destination;
        RH.Request request;
        T.RoyaltyFreeze[] royalties;
        bool requireInventory;
        Admission.Certificate admission;
    }

    function required(T.SuiteConfiguration memory source, RH.Provenance memory p)
        public
        view
        returns (bool)
    {
        for (uint256 i; i < p.journals[4].length; ++i) {
            RH.JournalEntry memory j = p.journals[4][i];
            if (j.receipt.operation == 24) continue;
            if (j.receipt.operation == 45 || j.receipt.operation == 47 || j.receipt.operation == 61)
            {
                return true;
            }
            if (j.receipt.operation != 44) continue;
            AD.Record memory r =
                DisputeOwner(source.owners[4]).attributionDisputeRecord(j.receipt.recordHash);
            (, uint64 current) =
                AttributionOwner(source.owners[4]).attributionState(j.receipt.collectionId);
            if (
                r.authorityClass != 0 || r.previousRecordHash != 0
                    || r.terms.bindingGeneration == current
                    || !Binding(source.owners[0])
                    .bindingAt(j.receipt.collectionId, r.terms.bindingGeneration)
                    .accepted
            ) return true;
        }
        return false;
    }

    /// @dev The caller passes the one complete admission; this entry never recollects source history.
    function encodeAdmitted(Context memory input) public view returns (bytes memory) {
        Owners.Context memory context;
        context.prepared.admission = input.admission;
        Admission.Certificate memory c = context.prepared.admission;
        M.State memory scope;
        scope.artists = c.artists;
        scope.collections = c.collections;
        Identity.preparationOwners(c.source.owners[2], scope, RH.ownerProvenance(c.provenance, 2));
        context.prepared.query = Codec.anchorQuery(scope);
        Witnesses.Plan memory witnesses = Witnesses.collectRatified(
            c.source, c.provenance, scope, input.request.records.witnesses, input.royalties
        );
        context.identities = new bytes[](c.artists.length);
        context.payouts = new bytes[](c.artists.length);
        External.Snapshot[] memory observations = new External.Snapshot[](c.artists.length);
        context.features = MD.FEATURE | RH.DISPUTE_HISTORY;
        for (uint256 i; i < c.artists.length; ++i) {
            (bool ok, bytes memory raw) = address(Identity)
                .staticcall(
                    abi.encodeWithSelector(
                        Identity.collect.selector,
                        c.source.owners[2],
                        c.artists[i],
                        RH.ownerProvenance(c.provenance, 2)
                    )
                );
            context.identities[i] = Tuple.result(ok, raw);
            Tuple.requireSingle(context.identities[i]);
            bool continuations;
            (raw, continuations) =
                Payout.collect(c.source.owners[5], c.artists[i].artistId, c.provenance);
            context.payouts[i] = Payout.encode(raw, c.provenance);
            TM.Checkpoint memory timing;
            uint256 selected;
            bool delegated;
            (observations[i], timing, selected, delegated) = Evidence.collect(
                context.identities[i], c.provenance, c.source.owners[2], continuations
            );
            if (
                i != 0
                    && keccak256(abi.encode(timing))
                        != keccak256(abi.encode(context.prepared.timing))
            ) revert T.UnsupportedProfile();
            context.prepared.timing = timing;
            context.features |= selected;
            if (delegated) context.features |= RH.DELEGATED_CONSENT;
        }
        context.prepared.externalGuards = Observations.collect(observations);
        Composition.Context memory phase;
        phase.source = c.source;
        phase.provenance = c.provenance;
        phase.scope = scope;
        phase.identities = context.identities;
        phase.economics = witnesses.economics;
        phase.freezes = witnesses.freezes;
        phase.attestations = witnesses.attestations;
        phase.features = context.features;
        Composition.Result memory result = Composition.collect(phase);
        context.bindings = result.bindings;
        context.consents = result.consents;
        context.features = result.features;
        context.attribution = result.attribution;
        context.accepted = result.accepted;
        context.inventory = result.inventory;
        context.generations = result.generations;
        if ((context.features & ~MD.ALLOWED) != 0) revert T.UnsupportedProfile();
        context.destination = input.destination;
        context.expected = input.request.expectedCapabilities;
        context.replayOrigins = input.request.records.authority.replayOrigins;
        return
            Owners.encode(context, input.requireInventory, input.request.expectedSemanticInventory);
    }
}
