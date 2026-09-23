// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistRecoveredContentConsentHydration as Original
} from "./StreamArtistRecoveredContentConsentHydration.sol";
import {
    StreamArtistRecoveredContentConsentReads as Reads
} from "./StreamArtistRecoveredContentConsentReads.sol";
import {
    StreamArtistRecoveredGenerationBaseValidation as Validation
} from "./StreamArtistRecoveredGenerationBaseValidation.sol";

import {
    StreamArtistRecoveredContentConsentValidation as ContentValidation
} from "./StreamArtistRecoveredContentConsentValidation.sol";

import {
    StreamArtistRecoveredBindingGenerations as Generations
} from "./StreamArtistRecoveredBindingGenerations.sol";

/// @notice Explicit generation plus original grant/mode2 consent composition.
/// @dev Owner6 retains its original Bundle. The separate tagged header binds the authenticated
/// final generation and consent mode; full Identity/grant joins occur before any owner import.
library StreamArtistRecoveredGenerationDelegatedConsents {
    bytes32 internal constant SCHEMA =
        keccak256("6529STREAM_ARTIST_RECOVERED_GENERATION_DELEGATED_CONSENTS_V1");

    function tagged(bytes memory raw) internal pure returns (bool) {
        return raw.length >= 32 && abi.decode(raw, (bytes32)) == SCHEMA;
    }

    function collect(
        address source,
        AH.Query memory q,
        RH.OwnerProvenance memory p,
        T.EconomicsConsent[] memory economics,
        T.RoyaltyFreeze[] memory royalties,
        uint64 generation,
        uint8 mode
    ) public view returns (bytes memory raw) {
        Original.Bundle memory b =
            Reads.collectRowsAt(source, q, p, economics, royalties, generation);
        raw = encode(b, q, p, generation, mode);
        Reads.requireHeadsAt(source, b, generation);
    }

    function encode(
        Original.Bundle memory b,
        AH.Query memory q,
        RH.OwnerProvenance memory p,
        uint64 generation,
        uint8 mode
    ) public pure returns (bytes memory) {
        validate(b, q, p, generation, mode);
        return abi.encode(SCHEMA, RH.VERSION, generation, mode, b);
    }

    function decode(AH.Query memory q, RH.OwnerProvenance memory p, bytes memory raw)
        public
        pure
        returns (Original.Bundle memory b, uint64 generation, uint8 mode)
    {
        bytes32 tag;
        uint16 version;
        (tag, version, generation, mode, b) =
            abi.decode(raw, (bytes32, uint16, uint64, uint8, Original.Bundle));
        if (
            tag != SCHEMA || version != RH.VERSION
                || keccak256(raw) != keccak256(abi.encode(tag, version, generation, mode, b))
        ) _invalid();
        validate(b, q, p, generation, mode);
    }

    /// @notice Same complete generation/consent join before the fixed Identity facts call.
    function requireBinding(
        AH.Query memory query,
        RH.OwnerProvenance memory provenance,
        bytes memory consent,
        bytes memory rawGenerations
    ) public pure returns (uint8 mode) {
        Generations.Bundle memory bindings = abi.decode(rawGenerations, (Generations.Bundle));
        uint64 generation;
        (, generation, mode) = decode(query, provenance, consent);
        if (
            generation != bindings.current.generation || mode != bindings.current.consentMode
                || bindings.current.bindingHash != query.bindingHash || !bindings.current.accepted
        ) {
            revert RH.InvalidRecoveredHydrationProfile();
        }
    }

    function validate(
        Original.Bundle memory b,
        AH.Query memory q,
        RH.OwnerProvenance memory p,
        uint64 generation,
        uint8 mode
    ) public pure {
        if (mode != 1 && mode != 2) _invalid();
        if (b.consents.length + b.royalties.length + b.freezes.length == 0) {
            Validation.validateWithGrants(b.original, q, p, generation);
        } else {
            ContentValidation.validateAt(b, q, p, generation);
        }
        // These original capabilities require the original mode2 acceptance. No current
        // grant is substituted for the recorded historical grant association.
        if (mode == 1) {
            for (uint256 i; i < b.original.policies.length; ++i) {
                if (b.original.policies[i].grant != 0) _invalid();
            }
            for (uint256 i; i < b.original.sales.length; ++i) {
                if (b.original.sales[i].grant != 0) _invalid();
            }
        }
        for (uint256 i; i < b.consents.length; ++i) {
            if (b.consents[i].terms.familyId == keccak256("6529STREAM_ENTROPY_CONFIGURATION_V1")) {
                _invalid();
            }
        }
    }

    function hasContent(Original.Bundle memory b) internal pure returns (bool) {
        return b.consents.length + b.royalties.length + b.freezes.length != 0;
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
