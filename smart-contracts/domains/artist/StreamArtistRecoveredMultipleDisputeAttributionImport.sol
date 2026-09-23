// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredMultipleDisputeAttributionRecords as Storage
} from "./StreamArtistRecoveredMultipleDisputeAttributionRecords.sol";
import {
    StreamArtistRecoveredMultipleDisputeStorage as DisputeStorage
} from "./StreamArtistRecoveredMultipleDisputeStorage.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import { StreamArtistAttributionStateTypes as AS } from "./StreamArtistAttributionStateTypes.sol";
import {
    StreamArtistRecoveredMultipleDisputeCodec as Codec
} from "./StreamArtistRecoveredMultipleDisputeCodec.sol";
import {
    StreamArtistRecoveredMultipleDisputeAttributionDecode as Decode
} from "./StreamArtistRecoveredMultipleDisputeAttributionDecode.sol";
import {
    StreamArtistRecoveredMultipleDisputeAttributionProof as Proof
} from "./StreamArtistRecoveredMultipleDisputeAttributionProof.sol";

/// @notice One guarded owner4 apply; all collections and credential heads are checked before writes.

library StreamArtistRecoveredMultipleDisputeAttributionImport {
    error InvalidRecoveredHydrationProfile();

    struct Context {
        Decode.Result decoded;
        Proof.Result proof;
        bytes32[][] bindingHashes;
    }

    function applyState(AS.State storage s, AH.Query memory anchor, bytes memory outer)
        public
        returns (bool)
    {
        if (!Codec.selected(outer, 4)) return false;
        Context memory c;
        (c.decoded.scope, c.decoded.provenance, c.decoded.inventory) =
            Decode.prepare(anchor, outer);
        c.proof = Decode.validate(c.decoded.scope, c.decoded.provenance, c.decoded.inventory);
        DisputeStorage.check(c.proof.histories);
        Storage.check(s, c.proof.all);
        DisputeStorage.install(c.proof.histories);
        c.bindingHashes = Decode.bindingHashes(c.decoded.inventory);
        Storage.install(
            s, Storage.Context(c.decoded.scope, c.decoded.provenance, c.bindingHashes, c.proof.all)
        );
        return true;
    }
}
