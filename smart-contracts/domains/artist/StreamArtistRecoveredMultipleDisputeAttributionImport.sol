// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredAggregateSanctionAttributionTransport as SanctionTransport
} from "./StreamArtistRecoveredAggregateSanctionAttributionTransport.sol";

import {
    StreamArtistRecoveredMultipleDisputeAttributionRecords as Storage
} from "./StreamArtistRecoveredMultipleDisputeAttributionRecords.sol";
import {
    StreamArtistRecoveredMultipleDisputeAttributionProof as Proof
} from "./StreamArtistRecoveredMultipleDisputeAttributionProof.sol";
import {
    StreamArtistRecoveredMultipleGenerationTypes as G
} from "./StreamArtistRecoveredMultipleGenerationTypes.sol";
import {
    StreamArtistRecoveredMultipleDisputeStorage as DisputeStorage
} from "./StreamArtistRecoveredMultipleDisputeStorage.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import { StreamArtistAttributionStateTypes as AS } from "./StreamArtistAttributionStateTypes.sol";
import {
    StreamArtistRecoveredHydrationOwnerPayload as Payload
} from "./StreamArtistRecoveredHydrationOwnerPayload.sol";
import {
    StreamArtistRecoveredMultipleTypes as M
} from "../../interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";
import {
    StreamArtistRecoveredMultipleDisputeCodec as Codec
} from "./StreamArtistRecoveredMultipleDisputeCodec.sol";
import {
    StreamArtistRecoveredHydrationOwnerPayload as OwnerPayload
} from "./StreamArtistRecoveredHydrationOwnerPayload.sol";

/// @notice One guarded owner4 apply; all collections and credential heads are checked before writes.

library StreamArtistRecoveredMultipleDisputeAttributionImport {
    struct Context {
        M.State scope;
        OwnerPayload.Payload payload;
        G.Inventory inventory;
        Proof.Result proof;
        bytes32[][] bindingHashes;
    }

    function applyState(AS.State storage s, AH.Query memory anchor, bytes memory outer)
        public
        returns (bool)
    {
        if (!Codec.selected(outer, 4)) return false;
        Context memory c;
        (c.scope, c.payload) = Codec.outer(4, anchor, outer);
        SanctionTransport.requireFeature(c.scope.rows, outer);
        (, bytes memory auxiliary) =
            Codec.decodeAuxiliary(4, c.payload.semanticState, c.payload.provenance);
        c.inventory = abi.decode(auxiliary, (G.Inventory));
        if (keccak256(auxiliary) != keccak256(abi.encode(c.inventory))) _invalid();
        c.proof = Proof.validate(c.scope, c.payload.provenance, c.inventory);
        DisputeStorage.check(c.proof.histories);
        Storage.check(s, c.proof.all);
        DisputeStorage.install(c.proof.histories);
        c.bindingHashes = new bytes32[][](c.inventory.bindings.length);
        for (uint256 k; k < c.bindingHashes.length; ++k) {
            c.bindingHashes[k] = new bytes32[](c.inventory.bindings[k].bindings.rows.length);
            for (uint256 g; g < c.bindingHashes[k].length; ++g) {
                c.bindingHashes[k][g] = c.inventory.bindings[k].bindings.rows[g].item.bindingHash;
            }
        }
        Storage.install(
            s, Storage.Context(c.scope, c.payload.provenance, c.bindingHashes, c.proof.all)
        );
        return true;
    }

    function _invalid() private pure {
        revert RH.InvalidRecoveredHydrationProfile();
    }
}
