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
    StreamArtistRecoveredContentConsentHydration as ContentH
} from "./StreamArtistRecoveredContentConsentHydration.sol";
import {
    StreamArtistRecoveredHydrationOwnerPayload as Payload
} from "./StreamArtistRecoveredHydrationOwnerPayload.sol";
import {
    StreamArtistRecoveredRatificationValidation as Validation
} from "./StreamArtistRecoveredRatificationValidation.sol";
import {
    StreamArtistRecoveredRatificationReads as Reads
} from "./StreamArtistRecoveredRatificationReads.sol";

/// @notice Explicit complete original52 plus supported consent history codec.
/// @dev Original nominal content and generation bundles/encodings remain unchanged.
library StreamArtistRecoveredRatificationHydration {
    bytes32 internal constant SCHEMA =
        keccak256("6529STREAM_ARTIST_RECOVERED_RATIFICATION_CONSENTS_V1");

    struct Bundle {
        ContentH.Bundle consent;
        T.RatificationRecord[] ratifications;
    }

    function tagged(bytes memory raw) internal pure returns (bool) {
        return raw.length >= 32 && abi.decode(raw, (bytes32)) == SCHEMA;
    }

    function selected(bytes memory outer) public pure returns (bool) {
        (RH.ExportHeader memory h, Payload.Payload memory p) = Payload.decode(outer, 6);
        bool feature = (h.requiredFeatures & RH.RATIFICATIONS) != 0;
        if (feature != tagged(p.semanticState)) revert RH.InvalidRecoveredHydrationProfile();
        return feature;
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
        Bundle memory b = Reads.collect(source, q, p, economics, royalties, generation);
        raw = encode(b, q, p, generation, mode);
        Reads.requireAllHeads(source, b, generation);
    }

    function encode(
        Bundle memory b,
        AH.Query memory q,
        RH.OwnerProvenance memory p,
        uint64 generation,
        uint8 mode
    ) public pure returns (bytes memory) {
        Validation.validate(b, q, p, generation, mode);
        return abi.encode(SCHEMA, RH.VERSION, generation, mode, b);
    }

    function decode(AH.Query memory q, RH.OwnerProvenance memory p, bytes memory raw)
        public
        pure
        returns (Bundle memory b, uint64 generation, uint8 mode)
    {
        bytes32 tag;
        uint16 version;
        (tag, version, generation, mode, b) = abi.decode(
            raw, (bytes32, uint16, uint64, uint8, Bundle)
        );
        if (
            tag != SCHEMA || version != RH.VERSION
                || keccak256(raw) != keccak256(abi.encode(tag, version, generation, mode, b))
        ) revert RH.InvalidRecoveredHydrationProfile();
        Validation.validate(b, q, p, generation, mode);
    }

    function hasContent(Bundle memory b) internal pure returns (bool) {
        return b.consent.consents.length + b.consent.royalties.length + b.consent.freezes.length
            != 0;
    }

    /// @dev Called only from the original fixed owner60 import, after the same complete decoder
    /// and original consent writes. Any failure rolls back all seven owners and their Archive.
    function importRecords(
        mapping(uint256 => T.RatificationRecord) storage current,
        mapping(bytes32 => T.RatificationRecord) storage records,
        AH.Query memory q,
        bytes memory outer
    ) public {
        (RH.ExportHeader memory h, Payload.Payload memory p) = Payload.decode(outer, 6);
        if ((h.requiredFeatures & RH.RATIFICATIONS) == 0 || p.nonces.length != 0) {
            revert RH.InvalidRecoveredHydrationProfile();
        }
        (Bundle memory b,,) = decode(q, p.provenance, p.semanticState);
        T.RatificationRecord memory empty;
        if (keccak256(abi.encode(current[q.collectionId])) != keccak256(abi.encode(empty))) {
            revert RH.InvalidRecoveredHydrationProfile();
        }
        for (uint256 i; i < b.ratifications.length; ++i) {
            if (
                keccak256(abi.encode(records[b.ratifications[i].recordHash]))
                    != keccak256(abi.encode(empty))
            ) revert RH.InvalidRecoveredHydrationProfile();
        }
        for (uint256 i; i < b.ratifications.length; ++i) {
            T.RatificationRecord memory r = b.ratifications[i];
            records[r.recordHash] = r;
            current[q.collectionId] = r;
        }
    }
}
