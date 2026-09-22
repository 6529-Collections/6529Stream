// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistUnboundPlatformOwners as Owners
} from "./StreamArtistUnboundPlatformOwners.sol";
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
    StreamArtistRecoveredHydrationCommit as Commit
} from "./StreamArtistRecoveredHydrationCommit.sol";
import {
    StreamArtistRecoveredHydrationAdmission as Admission
} from "./StreamArtistRecoveredHydrationAdmission.sol";
import {
    StreamArtistRecoveredMultipleIdentitySource as Identity
} from "./StreamArtistRecoveredMultipleIdentitySource.sol";

import { StreamArtistUnboundPlatformCodec as Codec } from "./StreamArtistUnboundPlatformCodec.sol";

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
    StreamArtistRecoveredMultipleObservations as Observations
} from "./StreamArtistRecoveredMultipleObservations.sol";

import {
    StreamArtistUnboundPlatformAdmission as UnboundAdmission
} from "./StreamArtistUnboundPlatformAdmission.sol";
import {
    StreamArtistUnboundPlatformEmptyIdentity as Empty
} from "./StreamArtistUnboundPlatformEmptyIdentity.sol";
import { StreamArtistUnboundPlatformTypes as U } from "./StreamArtistUnboundPlatformTypes.sol";

/// @notice One complete source admission, per-subject semantics, and one complete payload per owner.
library StreamArtistUnboundPlatformPreparation {
    function encode(
        T.SuiteConfiguration memory destination,
        RH.Request memory request,
        T.RoyaltyFreeze[] memory royalties,
        bool requireInventory
    ) public view returns (bytes memory) {
        Commit.Prepared memory prepared;
        if (royalties.length != 0 || request.records.witnesses.length != 0) {
            revert T.UnsupportedProfile();
        }
        prepared.admission = UnboundAdmission.collect(destination, request);
        Admission.Certificate memory c = prepared.admission;
        M.State memory scope;
        scope.artists = c.artists;
        scope.collections = c.collections;
        if (c.artists.length != 0) {
            Identity.preparationOwners(
                c.source.owners[2], scope, RH.ownerProvenance(c.provenance, 2)
            );
        }
        prepared.query = Codec.anchorQuery(scope);
        bytes[] memory identities = new bytes[](c.artists.length == 0 ? 1 : c.artists.length);
        bytes[] memory payouts = new bytes[](c.artists.length);
        External.Snapshot[] memory observations = new External.Snapshot[](c.artists.length);
        uint256 features = U.FEATURE;
        if (c.provenance.eras.length > 1) features |= RH.REPEATED_IMPORT;
        if (c.artists.length == 0) {
            (identities[0], prepared.timing) = Empty.collect(
                c.source.owners[2], RH.ownerProvenance(c.provenance, 2), c.collections
            );
            prepared.externalGuards.schema = U.TAG;
            prepared.externalGuards.provenanceCommitment = RH.provenanceHash(c.provenance);
        }
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
            identities[i] = Tuple.result(ok, raw);
            Tuple.requireSingle(identities[i]);
            bool continuations;
            (raw, continuations) =
                Payout.collect(c.source.owners[5], c.artists[i].artistId, c.provenance);
            payouts[i] = Payout.encode(raw, c.provenance);
            TM.Checkpoint memory timing;
            uint256 selected;
            bool delegated;
            (observations[i], timing, selected, delegated) =
                Evidence.collect(identities[i], c.provenance, c.source.owners[2], continuations);
            if (
                delegated
                    || (i != 0
                        && keccak256(abi.encode(timing)) != keccak256(abi.encode(prepared.timing)))
            ) revert T.UnsupportedProfile();
            prepared.timing = timing;
            features |= selected;
        }
        if ((features & ~(RH.FIRST_GRAPH_FEATURES | U.FEATURE)) != 0) {
            revert T.UnsupportedProfile();
        }
        if (c.artists.length != 0) prepared.externalGuards = Observations.collect(observations);
        Owners.Context memory context;
        context.prepared = prepared;
        context.destination = destination;
        context.expected = request.expectedCapabilities;
        context.replayOrigins = request.records.authority.replayOrigins;
        context.identities = identities;
        context.payouts = payouts;
        context.features = features;
        return Owners.encode(context, requireInventory, request.expectedSemanticInventory);
    }
}
