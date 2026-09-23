// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredSanctionStage as SanctionSelection
} from "./StreamArtistRecoveredSanctionStage.sol";
import {
    StreamArtistRecoveredAggregateSanctionRows as SanctionRows
} from "./StreamArtistRecoveredAggregateSanctionRows.sol";
import {
    StreamArtistRecoveredSanctionHistoryTypes as H
} from "./StreamArtistRecoveredSanctionHistoryTypes.sol";
import {
    StreamArtistPrimaryCollaboratorFamilyComposition as Families
} from "./StreamArtistPrimaryCollaboratorFamilyComposition.sol";
import {
    StreamArtistRecoveredMultipleGenerationConsentCollection as ConsentCollection
} from "./StreamArtistRecoveredMultipleGenerationConsentCollection.sol";
import {
    StreamArtistRecoveredMultipleGenerationEncoding as Encoding
} from "./StreamArtistRecoveredMultipleGenerationEncoding.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredMultipleTypes as M
} from "../../interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";
import {
    StreamArtistRecoveredMultipleGenerationTypes as G
} from "./StreamArtistRecoveredMultipleGenerationTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistReadinessHydrationTypes as ReadinessH
} from "../../interfaces/stream/artist/IStreamArtistReadinessAuthorityHydration.sol";
import {
    StreamArtistRecoveredAcceptedGenerationTypes as A
} from "./StreamArtistRecoveredAcceptedGenerationTypes.sol";
import {
    StreamArtistRecoveredAttestationHydration as Records
} from "./StreamArtistRecoveredAttestationHydration.sol";
import {
    StreamArtistRecoveredMultipleGenerationBindingSource as Bindings
} from "./StreamArtistRecoveredMultipleGenerationBindingSource.sol";
import {
    StreamArtistRecoveredMultipleGenerationBindingProof as BindingProof
} from "./StreamArtistRecoveredMultipleGenerationBindingProof.sol";
import {
    StreamArtistRecoveredMultipleGenerationClocks as Clocks
} from "./StreamArtistRecoveredMultipleGenerationClocks.sol";
import {
    StreamArtistRecoveredMultipleGenerationAcceptance as Acceptance
} from "./StreamArtistRecoveredMultipleGenerationAcceptance.sol";
import {
    StreamArtistRecoveredMultipleGenerationRevocations as Revocations
} from "./StreamArtistRecoveredMultipleGenerationRevocations.sol";
import {
    StreamArtistRecoveredMultipleGenerationConsentSource as Reads
} from "./StreamArtistRecoveredMultipleGenerationConsentSource.sol";
import {
    StreamArtistRecoveredMultipleGenerationConsentValidation as Validation
} from "./StreamArtistRecoveredMultipleGenerationConsentValidation.sol";
import {
    StreamArtistRecoveredMultipleGenerationAttestationQueries as Queries
} from "./StreamArtistRecoveredMultipleGenerationAttestationQueries.sol";
import {
    StreamArtistRecoveredMultipleGenerationAttestationSource as Attestations
} from "./StreamArtistRecoveredMultipleGenerationAttestationSource.sol";
import {
    StreamArtistRecoveredMultipleGenerationIdentityFacts as IdentityFacts
} from "./StreamArtistRecoveredMultipleGenerationIdentityFacts.sol";
import {
    StreamArtistRecoveredMultipleGenerationConservation as Conservation
} from "./StreamArtistRecoveredMultipleGenerationConservation.sol";

import {
    StreamArtistPrimaryCollaboratorTypes as PC
} from "./StreamArtistPrimaryCollaboratorTypes.sol";
import {
    StreamArtistPrimaryCollaboratorSourceProof as Source
} from "./StreamArtistPrimaryCollaboratorSourceProof.sol";
import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";

import {
    StreamArtistPrimaryCollaboratorCallFrames as FrameArgs
} from "./StreamArtistPrimaryCollaboratorCallFrames.sol";
import {
    StreamArtistPrimaryCollaboratorSourceCollection as Collection
} from "./StreamArtistPrimaryCollaboratorSourceCollection.sol";
import {
    StreamArtistPrimaryCollaboratorComposition as Composition
} from "./StreamArtistPrimaryCollaboratorComposition.sol";

/// @notice Complete original source collection and revocation history before all family phases.
library StreamArtistPrimaryCollaboratorCompositionSource {
    function prepare(bytes calldata raw) public view returns (bytes memory) {
        Composition.Context calldata x = FrameArgs.composition(raw);
        (bytes memory proof, bytes memory source) = Collection.encoded(x.scope, x.provenance);
        Source.Result memory observed = abi.decode(source, (Source.Result));
        H.Inventory memory sanctions;
        if (SanctionSelection.selected(x.provenance)) {
            sanctions = SanctionRows.collect(
                x.source.owners[6], x.scope.collections, x.provenance, observed.generations.bindings
            );
        }
        A.AttributionBundle[] memory history = Revocations.collect(
            x.source.owners[4],
            x.scope,
            RH.ownerProvenance(x.provenance, 4),
            observed.generations,
            observed.clocks.clocks,
            sanctions.confirmations
        );
        bytes[] memory fields = new bytes[](4);
        fields[0] = raw;
        fields[1] = proof;
        fields[2] = source;
        fields[3] = abi.encode(history);
        bytes[] memory args = new bytes[](2);
        args[0] = FrameArgs.join(fields, true);
        args[1] = abi.encode(sanctions);
        return FrameArgs.join(args, false);
    }
}
