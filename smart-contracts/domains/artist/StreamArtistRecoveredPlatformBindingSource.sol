// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredAcceptedGenerationTypes as A
} from "./StreamArtistRecoveredAcceptedGenerationTypes.sol";
import {
    StreamArtistRecoveredBindingCorrectionTypes as CB
} from "./StreamArtistRecoveredBindingCorrectionTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    IStreamArtistBindingOwner as Binding
} from "../../interfaces/stream/artist/IStreamArtistBindingOwner.sol";
import {
    IStreamArtistCollaboratorBindingOwner as Terms
} from "../../interfaces/stream/artist/IStreamArtistCollaboratorBindingOwner.sol";
import {
    IStreamArtistBindingLifecycle as Lifecycle
} from "../../interfaces/stream/artist/IStreamArtistBindingLifecycle.sol";
import {
    IStreamArtistBindingCorrectionOwner as Corrections,
    StreamArtistBindingCorrectionTypes as BC
} from "../../interfaces/stream/artist/IStreamArtistBindingCorrection.sol";

/// @notice The fixed Attribution importer also binds the supplied full binding rows to the same source suite.
/// @dev This is an exact historical-map comparison, not authorization against a new current principal.
library StreamArtistRecoveredPlatformBindingSource {
    function requireMatches(
        CB.Bundle memory b,
        A.Generation[] memory generations,
        uint256 collectionId,
        AH.Query memory q,
        RH.OwnerProvenance memory p
    ) public view {
        RH.OriginEnvironment memory o = p.origins[p.origins.length - 1];
        address source = o.owners[0];
        if (
            source.code.length == 0 || source.codehash != o.ownerCodeHashes[0]
                || b.bindings.artistId != q.artistId || b.bindings.collectionId != q.collectionId
                || b.bindings.bindingHash != q.bindingHash || b.bindings.rows.length == 0
                || b.bindings.rows.length > 128 || b.corrections.length != b.bindings.rows.length
                || b.bindings.current.generation != b.bindings.rows.length
                || !b.bindings.current.accepted || b.bindings.current.bindingHash != q.bindingHash
                || keccak256(abi.encode(b.bindings.current))
                    != keccak256(abi.encode(Binding(source).binding(q.collectionId)))
        ) _invalid();
        for (uint256 i; i < b.bindings.rows.length; ++i) {
            uint64 g = uint64(i + 1);
            if (
                keccak256(abi.encode(b.bindings.rows[i].item))
                        != keccak256(abi.encode(Binding(source).bindingAt(q.collectionId, g)))
                    || keccak256(abi.encode(b.bindings.rows[i].terms))
                        != keccak256(abi.encode(Terms(source).bindingTerms(q.collectionId, g)))
                    || keccak256(abi.encode(b.bindings.rows[i].terminal))
                        != keccak256(
                            abi.encode(Lifecycle(source).bindingTermination(q.collectionId, g))
                        )
            ) {
                _invalid();
            }
            (BC.Approval memory approval, bytes32 hash) =
                Corrections(source).bindingCorrection(b.bindings.rows[i].item.bindingHash);
            if (
                hash != b.corrections[i].recordHash
                    || keccak256(abi.encode(approval))
                        != keccak256(abi.encode(b.corrections[i].approval))
            ) _invalid();
        }
        if (generations.length != b.bindings.rows.length || collectionId != q.collectionId) {
            _invalid();
        }
        for (uint256 i; i < generations.length; ++i) {
            if (
                generations[i].bindingHash != b.bindings.rows[i].item.bindingHash
                    || generations[i].generation != b.bindings.rows[i].item.generation
                    || generations[i].accepted != b.bindings.rows[i].item.accepted
            ) {
                _invalid();
            }
        }
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
