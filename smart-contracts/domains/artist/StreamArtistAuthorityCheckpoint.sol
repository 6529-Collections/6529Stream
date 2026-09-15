// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamArtistAuthorityCheckpoint as GuardCheckpointAPI
} from "../../interfaces/stream/artist/IStreamArtistAuthorityCheckpoint.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

/// @notice Auxiliary typed inventory over actual successful owner mutations.
/// @dev Does not change original replay keys/cells, nonce indexes, deltas or authority decisions.
library StreamArtistAuthorityCheckpoint {
    bytes32 private constant SLOT = keccak256("6529STREAM_ARTIST_AUTHORITY_CHECKPOINT_STORAGE_V1");
    bytes32 private constant SCHEMA = keccak256("6529STREAM_ARTIST_GUARD_CHECKPOINT_V1");

    struct Index {
        uint8 kind;
        bytes32 key;
        uint256[] prefixes;
        mapping(uint256 => bool) seen;
    }

    struct State {
        bytes32 schema;
        bytes32 replayRoot;
        bytes32 nonceRoot;
        bytes32[] replayKeys;
        mapping(bytes32 => bool) replaySeen;
        bytes32[] nonceKeys;
        mapping(bytes32 => Index) indexes;
    }
    error InvalidAuthorityCheckpoint();

    function state() private pure returns (State storage s) {
        bytes32 slot = SLOT;
        assembly ("memory-safe") { s.slot := slot }
    }

    function initialize() public {
        State storage s = state();
        if (s.schema != 0 || s.replayKeys.length != 0 || s.nonceKeys.length != 0) {
            revert InvalidAuthorityCheckpoint();
        }
        s.schema = SCHEMA;
    }

    function noteReplay(bytes32 key, T.ReplayCell memory cell) public {
        if (key == 0 || cell.status == 0) revert InvalidAuthorityCheckpoint();
        State storage s = state();
        if (!s.replaySeen[key]) {
            s.replaySeen[key] = true;
            s.replayKeys.push(key);
        }
        s.replayRoot = keccak256(abi.encode(SCHEMA, s.replayRoot, key, cell));
    }

    function noteNonce(uint8 kind, bytes32 key, uint256 prefix, bytes32 originalDelta) public {
        if (kind == 0 || kind > 5 || key == 0 || originalDelta == 0) revert InvalidAuthorityCheckpoint();
        State storage s = state();
        bytes32 id = keccak256(abi.encode(kind, key));
        Index storage n = s.indexes[id];
        if (n.kind == 0) {
            n.kind = kind;
            n.key = key;
            s.nonceKeys.push(id);
        }
        if (!n.seen[prefix]) {
            n.seen[prefix] = true;
            n.prefixes.push(prefix);
        }
        s.nonceRoot = keccak256(abi.encode(SCHEMA, s.nonceRoot, kind, key, prefix, originalDelta));
    }

    function checkpoint() public view returns (GuardCheckpointAPI.Checkpoint memory c) {
        State storage s = state();
        c.schema = s.schema;
        c.replayRoot = s.replayRoot;
        c.replayCount = s.replayKeys.length;
        c.nonceRoot = s.nonceRoot;
        c.nonceIndexCount = s.nonceKeys.length;
    }

    function replayKeyAt(uint256 index) public view returns (bytes32) {
        return state().replayKeys[index];
    }

    function nonceIndexAt(uint256 index)
        public
        view
        returns (GuardCheckpointAPI.NonceIndex memory result)
    {
        State storage s = state();
        Index storage n = s.indexes[s.nonceKeys[index]];
        return GuardCheckpointAPI.NonceIndex(n.kind, n.key, n.prefixes.length);
    }

    function noncePrefixAt(uint8 kind, bytes32 key, uint256 index) public view returns (uint256) {
        Index storage n = state().indexes[keccak256(abi.encode(kind, key))];
        if (n.kind != kind || n.key != key) revert InvalidAuthorityCheckpoint();
        return n.prefixes[index];
    }
}
