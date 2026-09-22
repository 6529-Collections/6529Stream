// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistPrimaryCollaboratorOwners as Owners
} from "./StreamArtistPrimaryCollaboratorOwners.sol";
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
    StreamArtistPrimaryCollaboratorIdentitySource as Identity
} from "./StreamArtistPrimaryCollaboratorIdentitySource.sol";
import {
    StreamArtistRecoveredMultipleConsentNonces as Nonces
} from "./StreamArtistRecoveredMultipleConsentNonces.sol";
import {
    StreamArtistPrimaryCollaboratorCodec as Codec
} from "./StreamArtistPrimaryCollaboratorCodec.sol";
import {
    StreamArtistRecoveredMultipleConsentCollectionSource as Collections
} from "./StreamArtistRecoveredMultipleConsentCollectionSource.sol";
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

import {
    StreamArtistRecoveredMultipleGenerationWitnesses as Witnesses
} from "./StreamArtistRecoveredMultipleGenerationWitnesses.sol";
import {
    StreamArtistRecoveredMultipleConsentReads as Reads
} from "./StreamArtistRecoveredMultipleConsentReads.sol";
import {
    StreamArtistRecoveredMultipleConsentValidation as Validation
} from "./StreamArtistRecoveredMultipleConsentValidation.sol";
import {
    StreamArtistRecoveredMultipleConsentFacts as Facts
} from "./StreamArtistRecoveredMultipleConsentFacts.sol";
import {
    StreamArtistRecoveredContentConsentHydration as ContentH
} from "./StreamArtistRecoveredContentConsentHydration.sol";
import {
    StreamArtistRecoveredSimpleHydrationTypes as S
} from "../../interfaces/stream/artist/StreamArtistRecoveredSimpleHydrationTypes.sol";
import {
    IStreamArtistBindingOwner as Binding
} from "../../interfaces/stream/artist/IStreamArtistBindingOwner.sol";

import {
    StreamArtistPrimaryCollaboratorComposition as Composition
} from "./StreamArtistPrimaryCollaboratorComposition.sol";

import {
    StreamArtistRecoveredMultipleObservations as Observations
} from "./StreamArtistRecoveredMultipleObservations.sol";

import {
    StreamArtistRecoveredMultipleGenerationTypes as G
} from "./StreamArtistRecoveredMultipleGenerationTypes.sol";

import {
    StreamArtistPrimaryCollaboratorTypes as PC
} from "./StreamArtistPrimaryCollaboratorTypes.sol";
import {
    StreamArtistPrimaryCollaboratorAdmission as NewAdmission
} from "./StreamArtistPrimaryCollaboratorAdmission.sol";

/// @notice Fixed original per-principal identity, payout and evidence collection phase.
/// @dev Runs after the original witness collection and before family composition.
library StreamArtistPrimaryCollaboratorPreparationPrincipals {
    struct Result {
        bytes[] identities;
        bytes[] payouts;
        TM.Checkpoint timing;
        External.Snapshot externalGuards;
        uint256 features;
    }

    /// @dev Canonical complete Result transport; fixed caller decodes the same nominal tuple.
    function collectEncoded(Admission.Certificate memory c) public view returns (bytes memory) {
        return abi.encode(collect(c));
    }

    function collect(Admission.Certificate memory c) public view returns (Result memory result) {
        result.identities = new bytes[](c.artists.length);
        result.payouts = new bytes[](c.artists.length);
        External.Snapshot[] memory observations = new External.Snapshot[](c.artists.length);
        result.features = PC.FEATURE | RH.BINDING_GENERATIONS;
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
            result.identities[i] = Tuple.result(ok, raw);
            Tuple.requireSingle(result.identities[i]);
            bool continuations;
            (raw, continuations) =
                Payout.collect(c.source.owners[5], c.artists[i].artistId, c.provenance);
            result.payouts[i] = Payout.encode(raw, c.provenance);
            TM.Checkpoint memory timing;
            uint256 selected;
            bool delegated;
            (observations[i], timing, selected, delegated) = Evidence.collect(
                result.identities[i], c.provenance, c.source.owners[2], continuations
            );
            if (i != 0 && keccak256(abi.encode(timing)) != keccak256(abi.encode(result.timing))) {
                revert T.UnsupportedProfile();
            }
            result.timing = timing;
            result.features |= selected;
            if (delegated) result.features |= RH.DELEGATED_CONSENT;
        }
        result.externalGuards = Observations.collect(observations);
    }
}
