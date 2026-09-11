// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/artist/IStreamArtistOwner.sol";
import "./StreamArtistHashes.sol";

/// @notice Common immutable binding, replay and history accumulator for artist owners.
/// @dev No owner may call another owner. The coordinator snapshots cross-domain facts
///      before mutations. Only typed concrete owner methods can advance this prefix.
abstract contract StreamArtistOwner is IStreamArtistOwner {
    uint64 internal _revision;
    uint64 internal _recordSequence;
    bytes32 internal _stateRoot;
    bytes32 internal _recordChainTip;
    mapping(bytes32 => StreamArtistOnboardingTypes.ReplayCell) internal _replay;

    address public immutable artistRegistry;
    address public immutable operationCoordinator;
    address public immutable archiveV2;
    uint256 public immutable deploymentChainId;
    bytes32 public immutable domainId;
    address public immutable core;
    address public immutable mintManager;

    constructor(
        address registry_,
        address coordinator_,
        address archive_,
        bytes32 domain_,
        address core_,
        address manager_
    ) {
        if (
            registry_ == address(0) || coordinator_ == address(0) || archive_ == address(0)
                || registry_ == coordinator_ || registry_ == archive_ || coordinator_ == archive_
                || registry_ == address(this) || coordinator_ == address(this)
                || archive_ == address(this) || domain_ == bytes32(0) || core_ == address(0)
                || manager_ == address(0) || core_ == manager_
        ) revert StreamArtistOnboardingTypes.InvalidBinding();
        artistRegistry = registry_;
        operationCoordinator = coordinator_;
        archiveV2 = archive_;
        deploymentChainId = block.chainid;
        domainId = domain_;
        core = core_;
        mintManager = manager_;
        _stateRoot = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_OWNER_STATE_GENESIS_V2"),
                block.chainid,
                registry_,
                coordinator_,
                archive_,
                address(this),
                domain_
            )
        );
        _recordChainTip = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_OWNER_RECORD_GENESIS_V2"),
                block.chainid,
                registry_,
                coordinator_,
                archive_,
                address(this),
                domain_
            )
        );
    }

    function ownerStateSnapshotV2()
        public
        view
        returns (StreamArtistOnboardingTypes.Snapshot memory)
    {
        return
            StreamArtistOnboardingTypes.Snapshot(domainId, _revision, _stateRoot, _recordChainTip);
    }

    function replayCell(bytes32 key)
        external
        view
        returns (StreamArtistOnboardingTypes.ReplayCell memory)
    {
        return _replay[key];
    }

    function _check(StreamArtistOnboardingTypes.ActionContext calldata context, uint16 operation)
        internal
        view
    {
        if (msg.sender != operationCoordinator) {
            revert StreamArtistOnboardingTypes.Unauthorized(msg.sender);
        }
        if (context.actor == address(0)) {
            revert StreamArtistOnboardingTypes.Unauthorized(context.actor);
        }
        if (context.operationId != operation) {
            revert StreamArtistOnboardingTypes.InvalidOperation(context.operationId);
        }
        StreamArtistOnboardingTypes.Snapshot calldata prior = context.expected;
        if (
            prior.domainId != domainId || prior.revision != _revision
                || prior.stateRoot != _stateRoot || prior.recordChainTip != _recordChainTip
        ) revert StreamArtistOnboardingTypes.StaleOwnerSnapshot(domainId);
    }

    function _replayKey(bytes32 surface, bytes32 scope) internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"),
                deploymentChainId,
                artistRegistry,
                operationCoordinator,
                archiveV2,
                address(this),
                domainId,
                surface,
                scope
            )
        );
    }

    function _consume(bytes32 surface, bytes32 scope, bytes32 commitment)
        internal
        returns (bytes32 key)
    {
        key = _replayKey(surface, scope);
        if (_replay[key].status != 0) revert StreamArtistOnboardingTypes.Replay(key);
        _replay[key] = StreamArtistOnboardingTypes.ReplayCell(commitment, _revision + 1, 1, 2);
    }

    function _commit(
        StreamArtistOnboardingTypes.ActionContext calldata context,
        bytes32 action,
        bytes32 nextState,
        bytes32 replayDelta,
        bytes32 record
    ) internal {
        uint64 nextRevision = _revision + 1;
        bytes32 recordDelta = keccak256(abi.encode(record));
        _stateRoot = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_OWNER_STATE_TRANSITION_V2"),
                deploymentChainId,
                artistRegistry,
                operationCoordinator,
                archiveV2,
                address(this),
                domainId,
                _revision,
                nextRevision,
                _stateRoot,
                keccak256(abi.encode(context.operationId, context.actor, action)),
                nextState,
                replayDelta,
                recordDelta
            )
        );
        if (record != bytes32(0)) {
            uint64 nextSequence = _recordSequence + 1;
            _recordChainTip = keccak256(
                abi.encode(
                    keccak256("6529STREAM_ARTIST_OWNER_RECORD_TRANSITION_V2"),
                    deploymentChainId,
                    artistRegistry,
                    operationCoordinator,
                    archiveV2,
                    address(this),
                    domainId,
                    _recordSequence,
                    nextSequence,
                    _recordChainTip,
                    record
                )
            );
            _recordSequence = nextSequence;
        }
        _revision = nextRevision;
    }

    function _now() internal view returns (uint64) {
        if (block.timestamp > type(uint64).max) revert StreamArtistOnboardingTypes.InvalidRecord();
        return uint64(block.timestamp);
    }

    function _environment() internal view returns (StreamArtistHashes.Environment memory) {
        return StreamArtistHashes.Environment(deploymentChainId, artistRegistry, core, mintManager);
    }
}
