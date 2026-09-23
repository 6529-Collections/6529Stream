// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistPrimaryCollaboratorEncodingContext as Domain
} from "./StreamArtistPrimaryCollaboratorEncodingContext.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistRecoveredAggregateRatificationRows as Ratifications
} from "./StreamArtistRecoveredAggregateRatificationRows.sol";
import {
    StreamArtistPrimaryCollaboratorComposition as Composition
} from "./StreamArtistPrimaryCollaboratorComposition.sol";
import {
    StreamArtistRecoveredMultipleGenerationTypes as G
} from "./StreamArtistRecoveredMultipleGenerationTypes.sol";
import {
    StreamArtistRecoveredAcceptedGenerationTypes as A
} from "./StreamArtistRecoveredAcceptedGenerationTypes.sol";
import {
    StreamArtistRecoveredAttestationHydration as Records
} from "./StreamArtistRecoveredAttestationHydration.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";

import {
    StreamArtistPrimaryCollaboratorTypes as PC
} from "./StreamArtistPrimaryCollaboratorTypes.sol";

/// @notice Original aggregate row encoding and feature calculation after all conservation checks.
/// @dev This pure linked worker receives the complete already-validated rows. The
/// original Composition.Result nominal tuple and feature/encoding order are retained.
library StreamArtistPrimaryCollaboratorEncoding {
    struct Context {
        uint256 collectionCount;
        uint256 features;
        PC.Proof proof;
        A.AcceptanceBundle[] accepted;
        G.Consents[] consents;
        bytes[] attestations;
        A.AttributionBundle[] history;
    }

    /// @dev Complete canonical Context encoding from the fixed Family worker. This
    /// returns the same full Result bytes without caller-side nested tuple decoding.
    function encoded(bytes calldata raw) public pure returns (bytes memory) {
        if (raw.length < 256 || raw.length % 32 != 0) assembly ("memory-safe") { revert(0, 0) }
        uint256 at;
        assembly ("memory-safe") { at := calldataload(raw.offset) }
        if (at != 32) assembly ("memory-safe") { revert(0, 0) }
        Context calldata c;
        assembly ("memory-safe") { c := add(raw.offset, 32) }
        return abi.encode(_plain(c));
    }

    function encodedRatified(bytes calldata raw, T.RatificationRecord[][] memory ratifications)
        public
        pure
        returns (bytes memory)
    {
        if (raw.length < 256 || raw.length % 32 != 0) assembly ("memory-safe") { revert(0, 0) }
        uint256 at;
        assembly ("memory-safe") { at := calldataload(raw.offset) }
        if (at != 32) assembly ("memory-safe") { revert(0, 0) }
        Context calldata c;
        assembly ("memory-safe") { c := add(raw.offset, 32) }
        return abi.encode(_encode(c, ratifications));
    }

    /// @dev External entry only: validate the complete original eager tuple before any phase.
    function encode(Context calldata c) public pure returns (Composition.Result memory result) {
        Domain.requireValid(msg.data[4:]);
        return _plain(c);
    }

    function _plain(Context calldata c) private pure returns (Composition.Result memory) {
        T.RatificationRecord[][] memory empty = new T.RatificationRecord[][](c.collectionCount);
        for (uint256 i; i < empty.length; ++i) {
            empty[i] = new T.RatificationRecord[](0);
        }
        return _encode(c, empty);
    }

    /// @dev External entry only; ratifications keeps its complete original memory decoder.
    function encodeRatified(Context calldata c, T.RatificationRecord[][] memory ratifications)
        public
        pure
        returns (Composition.Result memory result)
    {
        Domain.requireValid(msg.data[4:]);
        return _encode(c, ratifications);
    }

    function _encode(Context calldata c, T.RatificationRecord[][] memory ratifications)
        private
        pure
        returns (Composition.Result memory result)
    {
        if (ratifications.length != c.collectionCount) {
            revert RH.InvalidRecoveredHydrationProfile();
        }
        uint256 n = c.collectionCount;
        result.bindings = new bytes[](n);
        result.accepted = new bytes[](n);
        result.consents = new bytes[](n);
        result.attribution = new bytes[](n);
        result.features = c.features | PC.FEATURE | RH.BINDING_GENERATIONS;
        for (uint256 k; k < n; ++k) {
            result.bindings[k] = abi.encode(c.proof.bindings.bindings[k]);
            result.accepted[k] = abi.encode(c.accepted[k]);
            result.consents[k] = Ratifications.encode(c.consents[k], ratifications[k]);
            if (ratifications[k].length != 0) result.features |= RH.RATIFICATIONS;
            Records.Bundle memory records = abi.decode(c.attestations[k], (Records.Bundle));
            result.attribution[k] = abi.encode(G.Attribution(c.history[k], records));
            if (records.records.length != 0) {
                result.features |= RH.ATTESTATIONS | RH.HISTORY_RECORDS;
            }
            if (c.history[k].revocations.length != 0) {
                result.features |= RH.ACCEPTED_GENERATIONS | RH.DISPUTE_HISTORY;
            }
            if (c.consents[k].rows.original.economics.length != 0) {
                result.features |= RH.DIRECT_ECONOMICS;
            }
            if (c.consents[k].rows.original.sales.length != 0) {
                result.features |= RH.DELEGATED_CONSENT;
            }
            if (
                c.consents[k].rows.consents.length + c.consents[k].rows.royalties.length
                        + c.consents[k].rows.freezes.length != 0
            ) result.features |= RH.CONTENT_CONSENTS | RH.HISTORY_CONTENT;
            for (uint256 g; g < c.proof.bindings.bindings[k].corrections.length; ++g) {
                if (c.proof.bindings.bindings[k].corrections[g].recordHash != 0) {
                    result.features |= RH.BINDING_CORRECTIONS;
                }
                if (c.consents[k].bindings[g].consentMode == 2) {
                    result.features |= RH.DELEGATED_CONSENT;
                }
            }
        }
        result.inventory = abi.encode(c.proof);
        result.accounts = c.proof.accounts;
        result.generations = abi.encode(c.proof.bindings.generations);
    }
}
