// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistAuthorityCheckpoint.sol";
import "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";

/// @dev Fixed delegate worker over the original owner's replay map; separate one-time marker.
library StreamArtistHydrationGuards {
    bytes32 private constant SLOT = keccak256("6529STREAM_ARTIST_AUTHORITY_HYDRATION_STORAGE_V1");

    struct State {
        bytes32 commitment;
        mapping(bytes32 => T.ReplayCell) sourceCells;
    }

    function state() private pure returns (State storage s) {
        bytes32 slot = SLOT;
        assembly ("memory-safe") { s.slot := slot }
    }

    function commitment() public view returns (bytes32) {
        return state().commitment;
    }

    /// @dev Direct STATIC read of the same original one-use completion marker.
    function commitmentInline() internal view returns (bytes32) {
        return state().commitment;
    }

    function sourceCell(bytes32 key) public view returns (T.ReplayCell memory) {
        return state().sourceCells[key];
    }

    function applyGuards(
        mapping(bytes32 => T.ReplayCell) storage replay,
        AH.OwnerData memory p,
        address registry,
        address coordinator,
        address archive,
        bytes32 domain,
        bytes32 value
    ) public returns (bytes32 delta) {
        if (
            value == 0 || state().commitment != 0 || p.origins.length != p.cells.length
                || p.sourceKeys.length != p.cells.length
        ) revert T.InvalidRecord();
        for (uint256 j; j < p.origins.length; ++j) {
            bytes32 key = keccak256(
                abi.encode(
                    keccak256("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"),
                    block.chainid,
                    registry,
                    coordinator,
                    archive,
                    address(this),
                    domain,
                    p.origins[j].surface,
                    p.origins[j].scope
                )
            );
            if (
                p.cells[j].status == 0 || p.sourceKeys[j] == 0
                    || state().sourceCells[p.sourceKeys[j]].status != 0
            ) revert T.InvalidRecord();
            state().sourceCells[p.sourceKeys[j]] = p.cells[j];
            // The predecessor's instance-local terminal latch is preserved historically.
            // It must not pre-consume this different registry's future operation57 latch.
            if (
                p.origins[j].surface == keccak256("identity_authority.replay.one_way_cutover_latch")
            ) {
                if (domain != keccak256("domain:identity_authority") || p.origins[j].scope != 0) {
                    revert T.InvalidRecord();
                }
                delta = keccak256(abi.encode(delta, p.sourceKeys[j], p.cells[j]));
                continue;
            }
            if (replay[key].status != 0) revert T.Replay(key);
            replay[key] = p.cells[j];
            StreamArtistAuthorityCheckpoint.noteReplay(key, replay[key]);
            delta = keccak256(abi.encode(delta, key, p.cells[j]));
        }
        state().commitment = value;
    }
}
