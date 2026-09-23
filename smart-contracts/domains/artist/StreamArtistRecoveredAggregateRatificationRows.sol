// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredMultipleGenerationTypes as G
} from "./StreamArtistRecoveredMultipleGenerationTypes.sol";
import {
    StreamArtistRecoveredHydrationCodec as Envelope
} from "./StreamArtistRecoveredHydrationCodec.sol";
import {
    StreamArtistAggregateConsentSupplementTypes as Supplement
} from "./StreamArtistAggregateConsentSupplementTypes.sol";

/// @notice Additive original52 rows beside the unchanged generation-aware Consent transport.
/// @dev Collections without ratifications retain their exact previous G.Consents encoding.
/// The enclosing profile still authenticates every binding and the complete owner journal.
library StreamArtistRecoveredAggregateRatificationRows {
    bytes32 internal constant SCHEMA = Supplement.SCHEMA;

    function encode(G.Consents memory original, T.RatificationRecord[] memory ratifications)
        public
        pure
        returns (bytes memory)
    {
        return encodeSupplement(Supplement.Bundle(original, ratifications, new bytes(0)));
    }

    /// @notice Canonical shared transport only; each admitted family has its own fixed proof.
    function encodeSupplement(Supplement.Bundle memory supplement)
        public
        pure
        returns (bytes memory)
    {
        if (supplement.ratifications.length > 128) _invalid();
        if (supplement.ratifications.length == 0 && supplement.sanctionInventory.length == 0) {
            return abi.encode(supplement.original);
        }
        return abi.encode(SCHEMA, Supplement.VERSION, supplement);
    }

    function decodeRows(bytes[] memory rows, bool required)
        public
        pure
        returns (G.Consents[] memory original, T.RatificationRecord[][] memory ratifications)
    {
        if (rows.length == 0 || rows.length > 128) _invalid();
        original = new G.Consents[](rows.length);
        ratifications = new T.RatificationRecord[][](rows.length);
        bool found;
        for (uint256 i; i < rows.length; ++i) {
            (original[i], ratifications[i]) = decode(rows[i]);
            if (ratifications[i].length != 0) found = true;
        }
        if (found != required) _invalid();
    }

    function decodeOwnerRows(bytes[] memory rows, bytes memory outer)
        public
        pure
        returns (G.Consents[] memory original, T.RatificationRecord[][] memory ratifications)
    {
        RH.Envelope memory e = Envelope.decode(outer, 6);
        return decodeRows(rows, (e.header.requiredFeatures & RH.RATIFICATIONS) != 0);
    }

    function decode(bytes memory raw)
        public
        pure
        returns (G.Consents memory original, T.RatificationRecord[] memory ratifications)
    {
        Supplement.Bundle memory supplement = decodeSupplement(raw);
        // This fixed entry admits original52 only. The shared transport does not authorize
        // another family's bytes or let an importer silently ignore that family.
        if (supplement.sanctionInventory.length != 0) _invalid();
        return (supplement.original, supplement.ratifications);
    }

    /// @notice Canonical transport for the shared carrier; no semantic family is validated here.
    /// @dev Future sanction callers must prove canonical H.Inventory and the global original
    /// catalogue once before import. Existing ratification callers reject nonempty sanction bytes.
    function decodeSupplement(bytes memory raw)
        public
        pure
        returns (Supplement.Bundle memory supplement)
    {
        bytes32 tag;
        if (raw.length >= 32) {
            assembly ("memory-safe") { tag := mload(add(raw, 0x20)) }
        }
        if (tag != SCHEMA) {
            supplement.original = abi.decode(raw, (G.Consents));
            if (keccak256(raw) != keccak256(abi.encode(supplement.original))) _invalid();
            supplement.ratifications = new T.RatificationRecord[](0);
            supplement.sanctionInventory = new bytes(0);
            return supplement;
        }
        uint16 version;
        (tag, version, supplement) = abi.decode(raw, (bytes32, uint16, Supplement.Bundle));
        if (
            version != Supplement.VERSION || supplement.ratifications.length > 128
                || (supplement.ratifications.length == 0
                    && supplement.sanctionInventory.length == 0)
                || keccak256(raw) != keccak256(abi.encode(tag, version, supplement))
        ) _invalid();
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
