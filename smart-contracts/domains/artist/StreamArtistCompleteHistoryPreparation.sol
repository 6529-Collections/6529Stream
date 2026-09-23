// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistCompleteHistoryAdmission as Admission
} from "./StreamArtistCompleteHistoryAdmission.sol";
import { StreamArtistCompleteHistoryCodec as Codec } from "./StreamArtistCompleteHistoryCodec.sol";
import {
    StreamArtistCompleteHistoryPreparationPrincipals as Principals
} from "./StreamArtistCompleteHistoryPreparationPrincipals.sol";
import {
    StreamArtistCompleteHistoryWitnesses as Witnesses
} from "./StreamArtistCompleteHistoryWitnesses.sol";
import {
    StreamArtistCompleteHistoryComposition as Composition
} from "./StreamArtistCompleteHistoryComposition.sol";
import {
    StreamArtistCompleteHistoryOwners as Owners
} from "./StreamArtistCompleteHistoryOwners.sol";
import { StreamArtistCompleteHistoryTypes as CT } from "./StreamArtistCompleteHistoryTypes.sol";
import {
    StreamArtistRecoveredHydrationAdmission as OriginalAdmission
} from "./StreamArtistRecoveredHydrationAdmission.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredMultipleTypes as M
} from "../../interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

/// @notice One fixed admission and complete original-source composition before seven-owner encoding.
/// @dev This profile remains unavailable until the shared dispatcher and all seven owners
/// explicitly advertise its capability. Existing preparation routes are unchanged.
library StreamArtistCompleteHistoryPreparation {
    struct Context {
        T.SuiteConfiguration destination;
        RH.Request request;
        T.RoyaltyFreeze[] royalties;
        bool requireInventory;
        OriginalAdmission.Certificate admission;
    }

    function encode(
        T.SuiteConfiguration memory destination,
        RH.Request memory request,
        T.RoyaltyFreeze[] memory royalties,
        bool requireInventory
    ) public view returns (bytes memory) {
        return encodeAdmitted(
            Context(
                destination,
                request,
                royalties,
                requireInventory,
                Admission.collect(destination, request)
            )
        );
    }

    /// @dev The caller supplies the freshly completed CompleteHistoryAdmission certificate.
    function encodeAdmitted(Context memory input) public view returns (bytes memory) {
        Owners.Context memory context;
        context.prepared.admission = input.admission;
        M.State memory scope;
        scope.artists = input.admission.artists;
        scope.collections = input.admission.collections;
        context.prepared.query = Codec.anchorQuery(scope);
        Principals.Result memory principal = Principals.collect(input.admission);
        context.principals = principal.principals;
        context.prepared.timing = principal.timing;
        context.prepared.externalGuards = principal.externalGuards;
        Witnesses.Plan memory witnesses = Witnesses.collect(
            input.admission.source,
            input.admission.provenance,
            scope,
            input.request.records.witnesses,
            input.royalties
        );
        Composition.Result memory result = Composition.collect(
            Composition.Context(
                input.admission, principal.principals, witnesses, principal.features
            )
        );
        context.inventory = result.inventory;
        context.bindings = result.bindings;
        context.accepted = result.accepted;
        context.consents = result.consents;
        context.attribution = result.attribution;
        context.features = result.features;
        if ((context.features & ~CT.ALLOWED) != 0) revert T.UnsupportedProfile();
        context.destination = input.destination;
        context.expected = input.request.expectedCapabilities;
        context.replayOrigins = input.request.records.authority.replayOrigins;
        return
            Owners.encode(context, input.requireInventory, input.request.expectedSemanticInventory);
    }
}
