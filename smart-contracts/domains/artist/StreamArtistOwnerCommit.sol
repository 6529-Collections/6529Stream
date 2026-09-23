// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Fixed original owner accumulator over its exact declared storage prefix.
/// @dev The host supplies its immutable binding. No external caller selects a storage slot.
library StreamArtistOwnerCommit {
    struct Prefix {
        uint64 revision;
        uint64 recordSequence;
        bytes32 stateRoot;
        bytes32 recordChainTip;
    }

    struct Environment {
        uint256 chainId;
        address registry;
        address coordinator;
        address archive;
        bytes32 domain;
    }

    /// @notice Pure original nine-word replay-key preimage; no replay storage or mutation.
    function replayKey(Environment memory e, address owner, bytes32 surface, bytes32 scope)
        public
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"),
                e.chainId,
                e.registry,
                e.coordinator,
                e.archive,
                owner,
                e.domain,
                surface,
                scope
            )
        );
    }

    struct Preimage {
        bytes32 tag;
        uint256 chainId;
        address registry;
        address coordinator;
        address archive;
        address owner;
        bytes32 domain;
        uint64 previousRevision;
        uint64 nextRevision;
        bytes32 previousState;
        bytes32 action;
        bytes32 nextState;
        bytes32 replayDelta;
        bytes32 recordDelta;
    }

    function _next(
        Prefix storage s,
        Environment memory e,
        uint16 operation,
        address actor,
        bytes32 action,
        bytes32 nextState,
        bytes32 replayDelta,
        bytes32 recordDelta
    ) private view returns (uint64 nextRevision, bytes32 root) {
        nextRevision = s.revision + 1;
        Preimage memory p;
        p.tag = keccak256("6529STREAM_ARTIST_OWNER_STATE_TRANSITION_V2");
        p.chainId = e.chainId;
        p.registry = e.registry;
        p.coordinator = e.coordinator;
        p.archive = e.archive;
        p.owner = address(this);
        p.domain = e.domain;
        p.previousRevision = s.revision;
        p.nextRevision = nextRevision;
        p.previousState = s.stateRoot;
        p.action = keccak256(abi.encode(operation, actor, action));
        p.nextState = nextState;
        p.replayDelta = replayDelta;
        p.recordDelta = recordDelta;
        root = keccak256(abi.encode(p));
    }

    function commit(
        Prefix storage s,
        Environment memory e,
        uint16 operation,
        address actor,
        bytes32 action,
        bytes32 nextState,
        bytes32 replayDelta,
        bytes32 record
    ) public {
        (uint64 nextRevision, bytes32 root) = _next(
            s, e, operation, actor, action, nextState, replayDelta, keccak256(abi.encode(record))
        );
        s.stateRoot = root;
        if (record != bytes32(0)) {
            uint64 nextSequence = s.recordSequence + 1;
            s.recordChainTip = keccak256(
                abi.encode(
                    keccak256("6529STREAM_ARTIST_OWNER_RECORD_TRANSITION_V2"),
                    e.chainId,
                    e.registry,
                    e.coordinator,
                    e.archive,
                    address(this),
                    e.domain,
                    s.recordSequence,
                    nextSequence,
                    s.recordChainTip,
                    record
                )
            );
            s.recordSequence = nextSequence;
        }
        s.revision = nextRevision;
    }

    function commitBatch(
        Prefix storage s,
        Environment memory e,
        uint16 operation,
        address actor,
        bytes32 action,
        bytes32 nextState,
        bytes32 replayDelta,
        bytes32 recordDelta,
        uint64 nextSequence,
        bytes32 nextTip
    ) public {
        (uint64 nextRevision, bytes32 root) =
            _next(s, e, operation, actor, action, nextState, replayDelta, recordDelta);
        s.stateRoot = root;
        s.recordSequence = nextSequence;
        s.recordChainTip = nextTip;
        s.revision = nextRevision;
    }
}
