// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistCompleteHistoryAttributionRecords as Records
} from "./StreamArtistCompleteHistoryAttributionRecords.sol";
import {
    StreamArtistCompleteHistoryAttributionProof as Proof
} from "./StreamArtistCompleteHistoryAttributionProof.sol";
import {
    StreamArtistCompleteHistoryDisputeStorage as Disputes
} from "./StreamArtistCompleteHistoryDisputeStorage.sol";
import {
    StreamArtistRecoveredPlatformWrites as Platform
} from "./StreamArtistRecoveredPlatformWrites.sol";
import { StreamArtistCompleteHistoryTypes as CT } from "./StreamArtistCompleteHistoryTypes.sol";
import { StreamArtistCompleteHistoryCodec as Codec } from "./StreamArtistCompleteHistoryCodec.sol";
import {
    StreamArtistCompleteHistoryDecode as Decode
} from "./StreamArtistCompleteHistoryDecode.sol";
import {
    StreamArtistPrimaryCollaboratorClocks as Clocks
} from "./StreamArtistPrimaryCollaboratorClocks.sol";
import { StreamArtistAttributionStateTypes as AS } from "./StreamArtistAttributionStateTypes.sol";
import {
    StreamArtistRecoveredHydrationOwnerPayload as Payload
} from "./StreamArtistRecoveredHydrationOwnerPayload.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistRecoveredMultipleTypes as M
} from "../../interfaces/stream/artist/StreamArtistRecoveredMultipleTypes.sol";

/// @notice All-target owner4 checks, then original Platform/dispute/attestation storage installation.
/// @dev The fixed Coordinator must prove the full seven-owner principal/consent joins before
/// op60. This worker neither selects a source profile nor advertises a capability. Original
/// common op60 code alone owns imported History, replay installation, events and native counts.
library StreamArtistCompleteHistoryAttributionImport {
    struct Context {
        M.State scope;
        Payload.Payload payload;
        CT.Inventory inventory;
        Clocks.Result clocks;
        Proof.Result proof;
    }

    function applyState(AS.State storage s, AH.Query memory anchor, bytes memory outer)
        public
        returns (bool)
    {
        if (!Codec.selected(outer, 4)) return false;
        Context memory c;
        (c.scope, c.payload, c.inventory, c.clocks) = Decode.collect(4, anchor, outer);
        c.proof = Proof.validateAdmitted(c.scope, c.payload.provenance, c.inventory, c.clocks);
        Records.Context memory records = Records.Context(c.scope, c.inventory, c.proof.all);
        Disputes.check(c.proof.histories);
        Records.check(s, records);
        for (uint256 k; k < c.inventory.platforms.length; ++k) {
            Platform.requireEmpty(s, c.inventory.platforms[k]);
        }
        // Every family and every collection has passed its original target checks.
        Disputes.install(c.proof.histories);
        for (uint256 k; k < c.inventory.platforms.length; ++k) {
            Platform.applyState(s, c.inventory.platforms[k]);
        }
        Records.install(s, records);
        return true;
    }
}
