// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
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
    StreamArtistPrimaryCollaboratorCallFrames as FrameArgs
} from "./StreamArtistPrimaryCollaboratorCallFrames.sol";
import {
    StreamArtistPrimaryCollaboratorFamilyComposition as Family
} from "./StreamArtistPrimaryCollaboratorFamilyComposition.sol";
import {
    StreamArtistPrimaryCollaboratorFamilyCollection as Collection
} from "./StreamArtistPrimaryCollaboratorFamilyCollection.sol";

/// @notice Exact full original encoding following all source and conservation checks.
library StreamArtistPrimaryCollaboratorFamilyEncoding {
    function encoded(bytes calldata raw, bytes calldata rows) public pure returns (bytes memory) {
        Family.Context calldata c = FrameArgs.family(raw);
        Collection.Result memory observed = abi.decode(rows, (Collection.Result));
        G.Consents[] memory consents = observed.consents;
        bytes[] memory attestations = observed.attestations;
        bytes[5] memory fields;
        fields[0] = abi.encode(c.proof);
        fields[1] = abi.encode(c.proof.accepted);
        fields[2] = abi.encode(consents);
        fields[3] = abi.encode(attestations);
        fields[4] = abi.encode(c.history);
        return Encoding.encodedRatified(
            _encoding(c.source.scope.collections.length, c.source.features, fields),
            observed.ratifications
        );
    }

    function _encoding(uint256 count, uint256 features, bytes[5] memory fields)
        private
        pure
        returns (bytes memory out)
    {
        uint256 length = 256;
        for (uint256 i; i < 5; ++i) {
            length += fields[i].length - 32;
        }
        out = new bytes(length);
        assembly ("memory-safe") {
            mstore(add(out, 32), 32)
            mstore(add(out, 64), count)
            mstore(add(out, 96), features)
        }
        uint256 tail = 224;
        for (uint256 i; i < 5; ++i) {
            bytes memory field = fields[i];
            assembly ("memory-safe") { mstore(add(add(out, 128), mul(i, 32)), tail) }
            for (uint256 at = 32; at < field.length; at += 32) {
                assembly ("memory-safe") {
                    mstore(add(add(out, 64), tail), mload(add(add(field, 32), at)))
                }
                tail += 32;
            }
        }
    }
}
