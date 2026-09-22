// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredMultipleConsentOwners as Owners
} from "./StreamArtistRecoveredMultipleConsentOwners.sol";
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
    StreamArtistRecoveredMultipleConsentIdentitySource as Identity
} from "./StreamArtistRecoveredMultipleConsentIdentitySource.sol";
import {
    StreamArtistRecoveredMultipleConsentNonces as Nonces
} from "./StreamArtistRecoveredMultipleConsentNonces.sol";
import {
    StreamArtistRecoveredMultipleConsentCodec as Codec
} from "./StreamArtistRecoveredMultipleConsentCodec.sol";
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
    StreamArtistRecoveredMultipleConsentWitnesses as Witnesses
} from "./StreamArtistRecoveredMultipleConsentWitnesses.sol";
import {
    StreamArtistRecoveredMultipleConsentReads as Reads
} from "./StreamArtistRecoveredMultipleConsentReads.sol";
import {
    StreamArtistRecoveredMultipleConsentValidation as Validation
} from "./StreamArtistRecoveredMultipleConsentValidation.sol";
import {
    StreamArtistRecoveredMultipleAttestationConservation as Facts
} from "./StreamArtistRecoveredMultipleAttestationConservation.sol";
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
    StreamArtistReadinessHydrationTypes as ReadinessH
} from "../../interfaces/stream/artist/IStreamArtistReadinessAuthorityHydration.sol";
import {
    StreamArtistRecoveredMultipleAttestationSource as Source
} from "./StreamArtistRecoveredMultipleAttestationSource.sol";
import {
    StreamArtistRecoveredMultipleAttestationClocks as Clocks
} from "./StreamArtistRecoveredMultipleAttestationClocks.sol";
import {
    StreamArtistRecoveredMultipleAttestationQueries as Queries
} from "./StreamArtistRecoveredMultipleAttestationQueries.sol";

/// @notice Fixed collection phase over the same admitted whole-owner certificate.
library StreamArtistRecoveredMultipleAttestationComposition {
    struct Result {
        bytes[] bindings;
        bytes[] consents;
        bytes[] attestations;
        bytes auxiliary;
        uint256 features;
    }

    struct Context {
        T.SuiteConfiguration source;
        RH.Provenance provenance;
        M.State scope;
        bytes[] identities;
        T.EconomicsConsent[][] economics;
        T.RoyaltyFreeze[][] freezes;
        uint256 features;
        ReadinessH.AttestationInput[][] attestations;
    }

    function collect(Context memory context) public view returns (Result memory result) {
        M.State memory scope = context.scope;
        uint256 features = context.features;
        bytes[] memory bindings = Collections.collect(context.source, 0, scope, context.provenance);
        ContentH.Bundle[] memory consents = new ContentH.Bundle[](scope.collections.length);
        bytes[] memory encodedConsents = new bytes[](consents.length);
        for (uint256 i; i < consents.length; ++i) {
            consents[i] = Reads.collectRows(
                context.source.owners[6],
                scope.collections[i],
                RH.ownerProvenance(context.provenance, 6),
                context.economics[i],
                context.freezes[i]
            );
            ContentH.Bundle memory row = consents[i];
            S.Binding memory binding = abi.decode(bindings[i], (S.Binding));
            if (row.original.economics.length != 0) features |= RH.DIRECT_ECONOMICS;
            if (row.original.sales.length != 0 || binding.item.consentMode == 2) {
                features |= RH.DELEGATED_CONSENT;
            }
            if (row.consents.length + row.royalties.length + row.freezes.length != 0) {
                features |= RH.CONTENT_CONSENTS;
            }
            encodedConsents[i] = abi.encode(row);
        }
        Validation.validate(consents, scope.collections, RH.ownerProvenance(context.provenance, 6));
        for (uint256 i; i < consents.length; ++i) {
            Reads.requireHeads(context.source.owners[6], consents[i]);
        }
        bytes[] memory attested = Source.collect(
            context.source.owners[4],
            Queries.project(scope, RH.ownerProvenance(context.provenance, 4)),
            RH.ownerProvenance(context.provenance, 4),
            context.attestations
        );
        bytes memory clocks = Clocks.collect(context.provenance, scope);
        Facts.validate(context.identities, scope, consents, bindings, attested, context.provenance);
        result = Result(bindings, encodedConsents, attested, clocks, features);
    }
}
