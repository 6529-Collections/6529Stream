// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistSanctionState.sol";
import "../../interfaces/stream/artist/IStreamArtistSanctionConfirmation.sol";

/// @notice Confirmation replay in the Consent owner's existing storage; no new primary record.
library StreamArtistSanctionConfirmationState {
    function consumeEncoded(
        StreamArtistSanctionState.State storage state,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistConsentState.Context memory o,
        bytes calldata callData
    ) public returns (StreamArtistConsentState.Mutation memory m, bytes32 replayKey) {
        if (
            bytes4(callData)
                != IStreamArtistConsentConfirmationOwner.consumeSanctionFinalization.selector
        ) {
            revert Confirmation.InvalidSanctionConfirmation();
        }
        (, T.Binding memory b, Confirmation.Transition memory p) =
            abi.decode(callData[4:], (T.ActionContext, T.Binding, Confirmation.Transition));
        S.Record storage r = state.records[p.sanctionRecordHash];
        if (
            !b.accepted || b.artistId == 0 || b.bindingHash == 0 || p.collectionId == 0
                || p.artistId != b.artistId || p.bindingGeneration != b.generation
                || p.priorAttributionState != 2 || p.finalityRecordHash == 0
                || r.recordHash != p.sanctionRecordHash || r.recordHash == 0
                || r.artistId != b.artistId || r.bindingGeneration != b.generation
                || r.bindingHash != b.bindingHash || r.terms.scopeType != 0
                || r.terms.collectionId != p.collectionId || r.terms.tokenId != 0
                || r.terms.scopeId != 0
        ) revert Confirmation.InvalidSanctionConfirmation();
        replayKey = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"),
                o.environment.chainId,
                o.environment.registry,
                o.coordinator,
                o.archive,
                address(this),
                o.domain,
                keccak256("consent_finality.replay.sanction_finalization_transition_key"),
                Confirmation.scope(p)
            )
        );
        if (replay[replayKey].status != 0) revert T.Replay(replayKey);
        replay[replayKey] = T.ReplayCell(p.sanctionRecordHash, o.revision + 1, 1, 2);
        m.action = keccak256(abi.encode(b, p));
        m.state = keccak256(abi.encode(p, replayKey));
        m.replay = keccak256(abi.encode(replayKey, p.sanctionRecordHash));
    }
}
