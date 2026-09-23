// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    IStreamArtistAuthorityCheckpoint as CP
} from "../../interfaces/stream/artist/IStreamArtistAuthorityCheckpoint.sol";
import { IStreamArtistOwner } from "../../interfaces/stream/artist/IStreamArtistOwner.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistRecoveredHydrationProvenance as Provenance
} from "./StreamArtistRecoveredHydrationProvenance.sol";

/// @notice Complete current guard/nonce collection against the fixed source's original checkpoint.
/// @dev Logical replay preimages are witnesses only; every key and value comes from the actual
/// producer. Historical aliases are retained separately in authenticated cumulative provenance.
library StreamArtistRecoveredHydrationGuards {
    function collect(RH.Provenance memory provenance, uint8 ownerIndex, AH.Origin[] memory origins)
        public
        view
        returns (AH.OwnerData memory guards, RH.NonceInventory[] memory nonces)
    {
        if (ownerIndex >= 7 || provenance.eras.length == 0) {
            revert RH.InvalidRecoveredHydrationProvenance();
        }
        uint256 last = provenance.eras.length - 1;
        RH.OriginEnvironment memory source = provenance.origins[last];
        CP.Checkpoint memory expected = provenance.eras[last].checkpoints[ownerIndex];
        address owner = source.owners[ownerIndex];
        if (
            origins.length != expected.replayCount || origins.length > RH.MAX_REPLAY_ALIASES
                || expected.schema != RH.CHECKPOINT
                || keccak256(abi.encode(CP(owner).authorityCheckpoint()))
                    != keccak256(abi.encode(expected))
        ) revert RH.InvalidRecoveredHydrationProvenance();
        guards.origins = origins;
        guards.sourceKeys = new bytes32[](origins.length);
        guards.cells = new T.ReplayCell[](origins.length);
        bytes32 sourceOrigin = RH.originHash(source);
        for (uint256 i; i < origins.length; ++i) {
            (bytes32 key, T.ReplayCell memory cell) = CP(owner).authorityReplayAt(i);
            if (
                key != replayKey(source, ownerIndex, origins[i]) || cell.status == 0
                    || keccak256(abi.encode(IStreamArtistOwner(owner).replayCell(key)))
                        != keccak256(abi.encode(cell))
            ) revert RH.InvalidRecoveredHydrationProvenance();
            bool found;
            for (uint256 j; j < provenance.aliases[ownerIndex].length; ++j) {
                RH.ReplayAlias memory alias_ = provenance.aliases[ownerIndex][j];
                if (alias_.originalKey != key) continue;
                if (
                    found || alias_.originHash != sourceOrigin
                        || alias_.surface != origins[i].surface || alias_.scope != origins[i].scope
                        || alias_.ownerIndex != ownerIndex
                        || keccak256(abi.encode(alias_.cell)) != keccak256(abi.encode(cell))
                ) revert RH.InvalidRecoveredHydrationProvenance();
                found = true;
            }
            if (!found) revert RH.InvalidRecoveredHydrationProvenance();
            guards.sourceKeys[i] = key;
            guards.cells[i] = cell;
        }
        nonces = collectNonces(owner, expected);
    }

    function collectNonces(address owner, CP.Checkpoint memory expected)
        public
        view
        returns (RH.NonceInventory[] memory result)
    {
        if (expected.nonceIndexCount > RH.MAX_NONCE_INDICES) {
            revert RH.InvalidRecoveredHydrationProvenance();
        }
        result = new RH.NonceInventory[](expected.nonceIndexCount);
        for (uint256 i; i < result.length; ++i) {
            result[i].index = CP(owner).authorityNonceIndexAt(i);
            CP.NonceIndex memory index = result[i].index;
            if (
                index.kind == 0 || index.kind > 5 || index.key == 0 || index.prefixCount == 0
                    || index.prefixCount > RH.MAX_NONCE_PREFIXES
            ) revert RH.InvalidRecoveredHydrationProvenance();
            result[i].words = new AH.NonceWord[](index.prefixCount);
            for (uint256 j; j < index.prefixCount; ++j) {
                AH.NonceWord memory word;
                (word.prefix, word.words, word.exhausted) =
                    CP(owner).authorityNonceWordAt(index.kind, index.key, j);
                result[i].words[j] = word;
            }
        }
        // Includes exhausted trees and every indexed nonce kind. No new availability is inferred.
        Provenance.validateNonces(owner, expected, result);
    }

    function replayKey(
        RH.OriginEnvironment memory source,
        uint8 ownerIndex,
        AH.Origin memory origin
    ) public pure returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"),
                source.chainId,
                source.registry,
                source.coordinator,
                source.archive,
                source.owners[ownerIndex],
                RH.ownerDomain(ownerIndex),
                origin.surface,
                origin.scope
            )
        );
    }
}
