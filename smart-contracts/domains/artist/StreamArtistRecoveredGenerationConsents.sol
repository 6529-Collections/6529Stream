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
    StreamArtistRecoveredContentConsentValidation as Validation
} from "./StreamArtistRecoveredContentConsentValidation.sol";

/// @notice Explicit complete direct-consent codec for a final accepted pending generation.
/// @dev Old Bundle and old schema remain unchanged. The generation is authenticated against
/// complete owner0 history before preparation and bound into this canonical owner6 payload.
library StreamArtistRecoveredGenerationConsents {
    bytes32 internal constant SCHEMA =
        keccak256("6529STREAM_ARTIST_RECOVERED_GENERATION_CONTENT_CONSENTS_V1");

    function tagged(bytes memory raw) internal pure returns (bool) {
        return raw.length >= 32 && abi.decode(raw, (bytes32)) == SCHEMA;
    }

    function collect(
        address source,
        AH.Query memory q,
        RH.OwnerProvenance memory p,
        T.EconomicsConsent[] memory economics,
        T.RoyaltyFreeze[] memory royalties,
        uint64 generation
    ) public view returns (Original.Bundle memory b) {
        b = Reads.collectRowsAt(source, q, p, economics, royalties, generation);
        validate(b, q, p, generation);
        Reads.requireHeadsAt(source, b, generation);
    }

    function encode(
        Original.Bundle memory b,
        AH.Query memory q,
        RH.OwnerProvenance memory p,
        uint64 generation
    ) public pure returns (bytes memory) {
        validate(b, q, p, generation);
        return abi.encode(SCHEMA, RH.VERSION, generation, b);
    }

    function decode(AH.Query memory q, RH.OwnerProvenance memory p, bytes memory raw)
        public
        pure
        returns (Original.Bundle memory b, uint64 generation)
    {
        bytes32 tag;
        uint16 version;
        (tag, version, generation, b) = abi.decode(raw, (bytes32, uint16, uint64, Original.Bundle));
        if (
            tag != SCHEMA || version != RH.VERSION
                || keccak256(raw) != keccak256(abi.encode(tag, version, generation, b))
        ) _invalid();
        validate(b, q, p, generation);
    }

    function validate(
        Original.Bundle memory b,
        AH.Query memory q,
        RH.OwnerProvenance memory p,
        uint64 generation
    ) public pure {
        Validation.validateAt(b, q, p, generation);
        for (uint256 i; i < b.original.policies.length; ++i) {
            if (b.original.policies[i].grant != 0) _invalid();
        }
        for (uint256 i; i < b.original.economics.length; ++i) {
            if (b.original.economics[i].grant != 0) _invalid();
        }
        for (uint256 i; i < b.original.sales.length; ++i) {
            if (b.original.sales[i].grant != 0) _invalid();
        }
        for (uint256 i; i < b.royalties.length; ++i) {
            if (b.royalties[i].grant != 0) _invalid();
        }
        // This slice retains original V1 content authorizations. The new entropy policy
        // family and a Router's separate VIEW-V2 carrier/tag are not inferred from an op17.
        for (uint256 i; i < b.consents.length; ++i) {
            if (b.consents[i].terms.familyId == keccak256("6529STREAM_ENTROPY_CONFIGURATION_V1")) {
                _invalid();
            }
        }
    }

    function generation(Original.Bundle memory b) internal pure returns (uint64) {
        if (b.consents.length != 0) return b.consents[0].bindingGeneration;
        if (b.royalties.length != 0) return b.royalties[0].item.bindingGeneration;
        if (b.freezes.length != 0) return b.freezes[0].bindingGeneration;
        _invalid();
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
