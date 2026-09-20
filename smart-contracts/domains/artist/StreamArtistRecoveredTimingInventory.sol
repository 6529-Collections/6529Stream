// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistRecoveredTimingTypes as TM
} from "../../interfaces/stream/artist/StreamArtistRecoveredTimingTypes.sol";

/// @notice Complete observer over the five original validated timing writers.
/// @dev note is called after original validation/mutation and changes no original key, hash,
/// event, timing revision, liveness, native journal or semantic-owner mutation counter.
/// The fixed new host initializes this namespace; absence never means an empty history.
library StreamArtistRecoveredTimingInventory {
    bytes32 private constant SLOT = keccak256("6529STREAM_ARTIST_RECOVERED_TIMING_STORAGE_V1");

    struct State {
        bytes32 schema;
        bytes32 root;
        TM.Entry[] entries;
        uint64[5] changes;
        mapping(bytes32 => bool) seen;
    }

    function state() internal pure returns (State storage s) {
        bytes32 slot = SLOT;
        assembly ("memory-safe") { s.slot := slot }
    }

    function initialize() public {
        State storage s = state();
        if (s.schema != 0 || s.root != 0 || s.entries.length != 0) {
            revert TM.RecoveredTimingUnavailable();
        }
        s.schema = TM.SCHEMA;
    }

    function note(TM.Input memory change) public {
        State storage s = state();
        if (s.schema != TM.SCHEMA) revert TM.RecoveredTimingUnavailable();
        (, uint8 group, uint64 floor) = _parameter(change.parameter);
        if (
            change.oldRevision != s.changes[group] + 1
                || change.newRevision != change.oldRevision + 1 || change.floor != floor
                || change.actionId == 0 || change.oldValue == change.newValue
                || change.newValue < floor
                || change.actionKey
                    != keccak256(
                        abi.encode(
                            change.actionId, change.parameter, change.oldHash, change.newHash
                        )
                    )
                || change.oldHash
                    != _stateHash(
                        block.chainid,
                        address(this),
                        change.parameter,
                        change.oldValue,
                        floor,
                        change.oldRevision
                    )
                || change.newHash
                    != _stateHash(
                        block.chainid,
                        address(this),
                        change.parameter,
                        change.newValue,
                        floor,
                        change.newRevision
                    ) || s.seen[change.actionKey]
        ) revert TM.InvalidRecoveredTiming(change.actionKey);
        TM.Entry memory entry =
            TM.Entry(block.chainid, address(this), s.entries.length, change, s.root, bytes32(0));
        entry.commitment = _hash(entry);
        s.entries.push(entry);
        s.root = entry.commitment;
        ++s.changes[group];
        s.seen[change.actionKey] = true;
    }

    function collect(TM.Configuration memory configuration)
        public
        view
        returns (TM.Bundle memory b)
    {
        State storage s = state();
        if (s.schema != TM.SCHEMA || s.entries.length > TM.MAX_ENTRIES) {
            revert TM.RecoveredTimingUnavailable();
        }
        b.configuration = configuration;
        b.entries = s.entries;
        b.checkpoint = TM.Checkpoint(
            TM.SCHEMA, TM.VERSION, b.entries.length, s.root, keccak256(abi.encode(configuration))
        );
        validate(b);
    }

    function checkpoint(TM.Configuration memory configuration)
        public
        view
        returns (TM.Checkpoint memory)
    {
        State storage s = state();
        if (s.schema != TM.SCHEMA || s.entries.length > TM.MAX_ENTRIES) {
            revert TM.RecoveredTimingUnavailable();
        }
        return TM.Checkpoint(
            TM.SCHEMA, TM.VERSION, s.entries.length, s.root, keccak256(abi.encode(configuration))
        );
    }

    function entryAt(uint256 index) public view returns (TM.Entry memory) {
        if (state().schema != TM.SCHEMA) revert TM.RecoveredTimingUnavailable();
        return state().entries[index];
    }

    /// @dev Called by the authenticated fixed operation60 worker before any copied timing maps.
    function install(TM.Bundle memory b) public {
        validate(b);
        State storage s = state();
        if (s.schema != TM.SCHEMA) revert TM.RecoveredTimingUnavailable();
        if (s.entries.length == b.entries.length && s.root == b.checkpoint.root) return;
        if (s.entries.length != 0 || s.root != 0) revert TM.RecoveredTimingUnavailable();
        for (uint256 i; i < b.entries.length; ++i) {
            TM.Entry memory e = b.entries[i];
            (, uint8 group,) = _parameter(e.change.parameter);
            s.entries.push(e);
            ++s.changes[group];
            s.seen[e.change.actionKey] = true;
        }
        s.root = b.checkpoint.root;
    }

    function validate(TM.Bundle memory b) public pure returns (bytes32) {
        if (
            b.entries.length > TM.MAX_ENTRIES || b.checkpoint.schema != TM.SCHEMA
                || b.checkpoint.version != TM.VERSION || b.checkpoint.count != b.entries.length
                || b.checkpoint.configurationHash != keccak256(abi.encode(b.configuration))
        ) revert TM.RecoveredTimingUnavailable();
        uint64[7] memory values =
            [uint64(7 days), 90 days, 180 days, 730 days, 365 days, 90 days, 7 days];
        uint64[5] memory revisions = [uint64(1), 1, 1, 1, 1];
        bytes32 previous;
        for (uint256 i; i < b.entries.length; ++i) {
            TM.Entry memory e = b.entries[i];
            TM.Input memory c = e.change;
            (uint8 parameter, uint8 group, uint64 floor) = _parameter(c.parameter);
            if (
                e.chainId == 0 || e.owner == address(0) || e.index != i
                    || e.previousCommitment != previous || e.commitment != _hash(e)
                    || c.actionId == 0 || c.oldValue != values[parameter]
                    || c.oldRevision != revisions[group] || c.newRevision != c.oldRevision + 1
                    || c.newValue == c.oldValue || c.newValue < floor || c.floor != floor
                    || c.actionKey
                        != keccak256(abi.encode(c.actionId, c.parameter, c.oldHash, c.newHash))
                    || c.oldHash
                        != _stateHash(
                            e.chainId, e.owner, c.parameter, c.oldValue, floor, c.oldRevision
                        )
                    || c.newHash
                        != _stateHash(
                            e.chainId, e.owner, c.parameter, c.newValue, floor, c.newRevision
                        )
            ) revert TM.InvalidRecoveredTiming(c.actionKey);
            for (uint256 j; j < i; ++j) {
                if (b.entries[j].change.actionKey == c.actionKey) {
                    revert TM.InvalidRecoveredTiming(c.actionKey);
                }
            }
            values[parameter] = c.newValue;
            revisions[group] = c.newRevision;
            previous = e.commitment;
        }
        if (previous != b.checkpoint.root) revert TM.RecoveredTimingUnavailable();
        for (uint256 i; i < 7; ++i) {
            uint64 actual = b.configuration.values[i];
            // Original raw zero stores its immutable default, not a fabricated governed write.
            if (actual == 0) actual = _default(i);
            if (actual != values[i]) revert TM.RecoveredTimingUnavailable();
        }
        for (uint256 i; i < 5; ++i) {
            uint64 actual = b.configuration.revisions[i] == 0 ? 1 : b.configuration.revisions[i];
            if (actual != revisions[i]) revert TM.RecoveredTimingUnavailable();
        }
        return keccak256(abi.encode(TM.SCHEMA, TM.VERSION, b));
    }

    function parameter(bytes32 key) public pure returns (uint8 index, uint8 group, uint64 floor) {
        return _parameter(key);
    }

    function _parameter(bytes32 key) private pure returns (uint8, uint8, uint64) {
        if (key == keccak256("ARTIST_ROTATION_CONTEST_SECONDS")) return (0, 0, 72 hours);
        if (key == keccak256("ARTIST_PRIOR_ADDRESS_STANDING_TAIL_SECONDS")) return (1, 0, 30 days);
        if (key == keccak256("ARTIST_ESTATE_ACTIVATION_NOTICE_SECONDS")) return (2, 1, 90 days);
        if (key == keccak256("ARTIST_DORMANCY_MIN_INACTIVITY_SECONDS")) return (3, 2, 365 days);
        if (key == keccak256("ARTIST_DORMANCY_NOTICE_SECONDS")) return (4, 2, 180 days);
        if (key == keccak256("ARTIST_UNAVAILABILITY_RECOVERY_NOTICE_SECONDS")) {
            return (5, 3, 30 days);
        }
        if (key == keccak256("ARTIST_REPUDIATION_CONTEST_SECONDS")) return (6, 4, 3 days);
        revert TM.InvalidRecoveredTiming(key);
    }

    function _default(uint256 i) private pure returns (uint64) {
        if (i == 0 || i == 6) return 7 days;
        if (i == 1 || i == 5) return 90 days;
        if (i == 2) return 180 days;
        if (i == 3) return 730 days;
        return 365 days;
    }

    function _hash(TM.Entry memory e) private pure returns (bytes32) {
        e.commitment = 0;
        return keccak256(abi.encode(TM.SCHEMA, TM.VERSION, e));
    }

    function _stateHash(
        uint256 chainId,
        address owner,
        bytes32 parameter_,
        uint64 value,
        uint64 floor,
        uint64 revision
    ) private pure returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_WINDOW_STATE_V1"),
                chainId,
                owner,
                parameter_,
                value,
                floor,
                revision
            )
        );
    }
}
