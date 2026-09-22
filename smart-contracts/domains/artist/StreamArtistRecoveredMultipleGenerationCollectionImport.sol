// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredMultipleGenerationTypes as G
} from "./StreamArtistRecoveredMultipleGenerationTypes.sol";
import {
    StreamArtistRecoveredAcceptedGenerationTypes as A
} from "./StreamArtistRecoveredAcceptedGenerationTypes.sol";
import {
    StreamArtistRecoveredMultipleGenerationCodec as Codec
} from "./StreamArtistRecoveredMultipleGenerationCodec.sol";
import {
    StreamArtistRecoveredMultipleGenerationAcceptance as Proof
} from "./StreamArtistRecoveredMultipleGenerationAcceptance.sol";
import {
    StreamArtistRecoveredMultipleCollectionRows as Empty
} from "./StreamArtistRecoveredMultipleCollectionRows.sol";
import {
    StreamArtistRecoveredHydrationOwnerPayload as Payload
} from "./StreamArtistRecoveredHydrationOwnerPayload.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredMultipleTypes as M
} from "../../interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";

/// @notice Original acceptance maps and the unchanged empty PRIMARY_ONLY collaborator owner.
library StreamArtistRecoveredMultipleGenerationCollectionImport {
    function acceptances(
        mapping(bytes32 => bytes32) storage records,
        mapping(bytes32 => uint64) storage times,
        AH.Query memory anchor,
        bytes memory outer
    ) public returns (bool) {
        if (!Codec.selected(outer, 3)) return false;
        (M.State memory scope, Payload.Payload memory p) = Codec.outer(3, anchor, outer);
        (, bytes memory raw) = Codec.decodeAuxiliary(3, p.semanticState, p.provenance);
        G.Inventory memory inventory;
        inventory.generations = abi.decode(raw, (A.Generation[][]));
        if (keccak256(raw) != keccak256(abi.encode(inventory.generations))) _invalid();
        A.AcceptanceBundle[] memory all = new A.AcceptanceBundle[](scope.rows.length);
        for (uint256 k; k < all.length; ++k) {
            all[k] = abi.decode(scope.rows[k], (A.AcceptanceBundle));
            if (keccak256(scope.rows[k]) != keccak256(abi.encode(all[k]))) _invalid();
        }
        Proof.validate(all, scope, p.provenance, inventory);
        for (uint256 k; k < all.length; ++k) {
            for (uint256 g; g < all[k].rows.length; ++g) {
                if (
                    records[all[k].rows[g].bindingHash] != 0
                        || times[all[k].rows[g].bindingHash] != 0
                ) _invalid();
            }
        }
        for (uint256 k; k < all.length; ++k) {
            for (uint256 g; g < all[k].rows.length; ++g) {
                records[all[k].rows[g].bindingHash] = all[k].rows[g].recordHash;
                times[all[k].rows[g].bindingHash] = all[k].rows[g].acceptedAt;
            }
        }
        return true;
    }

    function collaborator(AH.Query memory anchor, bytes memory outer) public pure returns (bool) {
        if (!Codec.selected(outer, 1)) return false;
        (M.State memory scope, Payload.Payload memory p) = Codec.outer(1, anchor, outer);
        Empty.validate(1, scope, p.provenance);
        return true;
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
