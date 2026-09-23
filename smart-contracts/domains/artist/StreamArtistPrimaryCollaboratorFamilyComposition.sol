// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredSanctionHistoryTypes as H
} from "./StreamArtistRecoveredSanctionHistoryTypes.sol";
import {
    StreamArtistRecoveredMultipleGenerationConsentCollection as ConsentCollection
} from "./StreamArtistRecoveredMultipleGenerationConsentCollection.sol";
import {
    StreamArtistPrimaryCollaboratorEncoding as Encoding
} from "./StreamArtistPrimaryCollaboratorEncoding.sol";
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
    StreamArtistPrimaryCollaboratorIdentityFacts as IdentityFacts
} from "./StreamArtistPrimaryCollaboratorIdentityFacts.sol";
import {
    StreamArtistRecoveredMultipleGenerationConservation as Conservation
} from "./StreamArtistRecoveredMultipleGenerationConservation.sol";

import {
    StreamArtistPrimaryCollaboratorComposition as Composition
} from "./StreamArtistPrimaryCollaboratorComposition.sol";

import {
    StreamArtistPrimaryCollaboratorTypes as PC
} from "./StreamArtistPrimaryCollaboratorTypes.sol";
import {
    StreamArtistPrimaryCollaboratorSourceProof as Source
} from "./StreamArtistPrimaryCollaboratorSourceProof.sol";

import {
    StreamArtistPrimaryCollaboratorFamilyValidation as FamilyValidation
} from "./StreamArtistPrimaryCollaboratorFamilyValidation.sol";

import {
    StreamArtistPrimaryCollaboratorFamilyCollection as FamilyCollection
} from "./StreamArtistPrimaryCollaboratorFamilyCollection.sol";
import {
    StreamArtistPrimaryCollaboratorFamilyFinish as FamilyFinish
} from "./StreamArtistPrimaryCollaboratorFamilyFinish.sol";

import {
    StreamArtistPrimaryCollaboratorPipelineCanonical as Canonical
} from "./StreamArtistPrimaryCollaboratorPipelineCanonical.sol";

/// @notice Original consent/attestation families, identity and global conservation followed by encoding.
/// @dev Complete original graph and chronology are supplied after the unchanged source prelude.
library StreamArtistPrimaryCollaboratorFamilyComposition {
    error InvalidRecoveredHydrationProfile();

    struct Context {
        Composition.Context source;
        PC.Proof proof;
        Source.Result observed;
        A.AttributionBundle[] history;
    }

    /// @dev External library entry only; all original phases precede terminal return.
    function collect(Context calldata c) public view returns (Composition.Result memory result) {
        H.Inventory memory empty;
        bytes memory raw = _run(Canonical.family(msg.data[4:]), abi.encode(empty));
        assembly ("memory-safe") { return(add(raw, 32), mload(raw)) }
    }

    function collect(Context calldata c, H.Inventory calldata sanctions)
        public
        view
        returns (Composition.Result memory result)
    {
        (bytes memory context, bytes memory history) = Canonical.supplemented(msg.data[4:]);
        bytes memory raw = _run(context, history);
        assembly ("memory-safe") { return(add(raw, 32), mload(raw)) }
    }

    function encoded(bytes calldata raw) public view returns (bytes memory) {
        H.Inventory memory empty;
        return _run(Canonical.family(raw), abi.encode(empty));
    }

    function encodedSupplemented(bytes calldata raw) public view returns (bytes memory) {
        (bytes memory context, bytes memory history) = Canonical.supplemented(raw);
        return _run(context, history);
    }

    function _run(bytes memory context, bytes memory history) private view returns (bytes memory) {
        bytes memory prepared = FamilyCollection.collect(context, history);
        return FamilyFinish.finish(context, prepared, history);
    }
}
