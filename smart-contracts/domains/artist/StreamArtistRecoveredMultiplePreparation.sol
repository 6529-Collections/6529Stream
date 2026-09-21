// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredMultipleOwners as Owners
} from "./StreamArtistRecoveredMultipleOwners.sol";
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
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistRecoveredTimingTypes as TM
} from "../../interfaces/stream/artist/StreamArtistRecoveredTimingTypes.sol";
import {
    IStreamArtistRecoveredHydrationOwner as Owner
} from "../../interfaces/stream/artist/IStreamArtistRecoveredHydration.sol";
import {
    StreamArtistRecoveredHydrationCommit as Commit
} from "./StreamArtistRecoveredHydrationCommit.sol";
import {
    StreamArtistRecoveredHydrationAdmission as Admission
} from "./StreamArtistRecoveredHydrationAdmission.sol";
import {
    StreamArtistRecoveredMultipleIdentitySource as Identity
} from "./StreamArtistRecoveredMultipleIdentitySource.sol";
import {
    StreamArtistRecoveredMultipleIdentityNonces as Nonces
} from "./StreamArtistRecoveredMultipleIdentityNonces.sol";
import {
    StreamArtistRecoveredMultipleCodec as Codec
} from "./StreamArtistRecoveredMultipleCodec.sol";
import {
    StreamArtistRecoveredMultipleCollectionRows as Collections
} from "./StreamArtistRecoveredMultipleCollectionRows.sol";
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
    StreamArtistRecoveredHydrationOwnerPayload as Payload
} from "./StreamArtistRecoveredHydrationOwnerPayload.sol";
import {
    StreamArtistRecoveredPayloadHydration as Publications
} from "./StreamArtistRecoveredPayloadHydration.sol";
import {
    StreamArtistRecoveredHydrationGuards as Guards
} from "./StreamArtistRecoveredHydrationGuards.sol";
import {
    StreamArtistRecoveredHydrationCodec as OuterCodec
} from "./StreamArtistRecoveredHydrationCodec.sol";
import {
    StreamArtistRecoveredPreparationSeal as Seal
} from "./StreamArtistRecoveredPreparationSeal.sol";

/// @notice One complete source admission, per-subject semantics, and one complete payload per owner.
library StreamArtistRecoveredMultiplePreparation {
    function encode(
        T.SuiteConfiguration memory destination,
        RH.Request memory request,
        T.RoyaltyFreeze[] memory royalties,
        bool requireInventory
    ) public view returns (bytes memory) {
        if (request.records.witnesses.length != 0 || royalties.length != 0) {
            revert T.UnsupportedProfile();
        }
        Commit.Prepared memory prepared;
        prepared.admission = Admission.collect(destination, request);
        Admission.Certificate memory c = prepared.admission;
        M.State memory scope;
        scope.artists = c.artists;
        scope.collections = c.collections;
        Identity.preparationOwners(c.source.owners[2], scope, RH.ownerProvenance(c.provenance, 2));
        prepared.query = Codec.anchorQuery(scope);
        bytes[] memory identities = new bytes[](c.artists.length);
        bytes[] memory payouts = new bytes[](c.artists.length);
        External.Snapshot[] memory observations = new External.Snapshot[](c.artists.length);
        uint256 features = RH.MULTIPLE_BASE;
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
        if ((features & ~(RH.FIRST_GRAPH_FEATURES | RH.MULTIPLE_BASE)) != 0) {
            revert T.UnsupportedProfile();
        }
        prepared.externalGuards = _merge(observations);
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

    function _merge(External.Snapshot[] memory all)
        private
        pure
        returns (External.Snapshot memory result)
    {
        result.schema = all[0].schema;
        result.provenanceCommitment = all[0].provenanceCommitment;
        result.artistId = all[0].artistId;
        uint256 a;
        uint256 f;
        uint256 e;
        for (uint256 i; i < all.length; ++i) {
            if (
                all[i].schema != result.schema
                    || all[i].provenanceCommitment != result.provenanceCommitment
                    || all[i].artistId == 0
            ) revert RH.InvalidRecoveredHydrationProfile();
            a += all[i].actions.length;
            f += all[i].finality.length;
            e += all[i].entropy.length;
        }
        if (a > RH.MAX_REPLAY_ALIASES || f + e > RH.MAX_JOURNAL_ENTRIES) {
            revert RH.InvalidRecoveredHydrationProfile();
        }
        result.actions = new External.ActionGuard[](a);
        result.finality = new External.FinalityGuard[](f);
        result.entropy = new External.EntropyGuard[](e);
        a = 0;
        f = 0;
        e = 0;
        for (uint256 i; i < all.length; ++i) {
            for (uint256 j; j < all[i].actions.length; ++j) {
                result.actions[a++] = all[i].actions[j];
            }
            for (uint256 j; j < all[i].finality.length; ++j) {
                result.finality[f++] = all[i].finality[j];
            }
            for (uint256 j; j < all[i].entropy.length; ++j) {
                result.entropy[e++] = all[i].entropy[j];
            }
        }
    }
}
