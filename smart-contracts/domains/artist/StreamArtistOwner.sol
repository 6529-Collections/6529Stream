// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistOwnerCheck } from "./StreamArtistOwnerCheck.sol";
import { StreamArtistRecoveredOwnerReads } from "./StreamArtistRecoveredOwnerReads.sol";
import {
    StreamArtistRecoveredHydrationTypes
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import { StreamArtistOwnerCommit } from "./StreamArtistOwnerCommit.sol";
import "./StreamArtistHydrationGuards.sol";
import { StreamArtistOwnerHydration } from "./StreamArtistOwnerHydration.sol";
import "./StreamArtistAuthorityCheckpoint.sol";
import {
    IStreamArtistAuthorityCheckpoint
} from "../../interfaces/stream/artist/IStreamArtistAuthorityCheckpoint.sol";

import "../../interfaces/stream/artist/IStreamArtistOwner.sol";
import "./StreamArtistHashes.sol";
import "./StreamArtistNativeReceipts.sol";
import {
    StreamArtistIdentityRecoveryReceipts as RecoveryReceipts
} from "./StreamArtistIdentityRecoveryReceipts.sol";
import {
    StreamArtistIdentityRecoveryTypes as RecoveryRecord
} from "../../interfaces/stream/artist/StreamArtistIdentityRecoveryTypes.sol";

/// @notice Common immutable binding, replay and history accumulator for artist owners.
/// @dev No owner may call another owner. The coordinator snapshots cross-domain facts
///      before mutations. Only typed concrete owner methods can advance this prefix.
abstract contract StreamArtistOwner is IStreamArtistOwner {
    // Retain original public ABI errors after moving the exact predicate to its fixed worker.
    error Unauthorized(address caller);
    error InvalidOperation(uint16 operationId);
    error StaleOwnerSnapshot(bytes32 domainId);

    /// @dev All fields are static, preserving the original fourteen-word abi.encode preimage.
    struct StateTransitionPreimage {
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
        StreamArtistAuthorityCheckpoint.initialize();
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

    function authorityCheckpoint()
        external
        view
        returns (IStreamArtistAuthorityCheckpoint.Checkpoint memory result)
    {
        result = StreamArtistAuthorityCheckpoint.checkpoint();
        result.ownerState = ownerStateSnapshotV2();
    }

    function authorityReplayAt(uint256 index)
        external
        view
        returns (bytes32 key, StreamArtistOnboardingTypes.ReplayCell memory cell)
    {
        key = StreamArtistAuthorityCheckpoint.replayKeyAt(index);
        cell = _replay[key];
    }

    function authorityNonceIndexAt(uint256 index)
        external
        view
        returns (IStreamArtistAuthorityCheckpoint.NonceIndex memory)
    {
        return StreamArtistAuthorityCheckpoint.nonceIndexAt(index);
    }

    function authorityNonceWordAt(uint8, bytes32, uint256)
        external
        view
        virtual
        returns (uint256, uint256[32] memory, bool)
    {
        revert StreamArtistAuthorityCheckpoint.InvalidAuthorityCheckpoint();
    }

    function importedAuthorityReplayCell(bytes32 key)
        external
        view
        returns (StreamArtistOnboardingTypes.ReplayCell memory)
    {
        return StreamArtistHydrationGuards.sourceCell(key);
    }

    function authorityHydrationCommitment() external view returns (bytes32) {
        return StreamArtistHydrationGuards.commitment();
    }

    function recoveredAuthorityHydrationCapability()
        external
        view
        returns (StreamArtistRecoveredHydrationTypes.Capability calldata)
    {
        _forwardRecoveredRead();
    }

    function recoveredHydrationImportedPrefix()
        external
        view
        returns (StreamArtistRecoveredHydrationTypes.OwnerProvenance calldata, bytes32, uint64)
    {
        _forwardRecoveredRead();
    }

    function recoveredHydrationReplayPoint(bytes32)
        external
        view
        returns (StreamArtistRecoveredHydrationTypes.Point memory)
    {
        _forwardRecoveredRead();
    }

    function recoveredHydrationOrigin(bytes32)
        external
        view
        returns (StreamArtistRecoveredHydrationTypes.OriginEnvironment calldata)
    {
        _forwardRecoveredRead();
    }

    function recoveredHydrationAuxiliaryPoint(bytes32, bytes32)
        external
        view
        virtual
        returns (StreamArtistRecoveredHydrationTypes.Point memory)
    {
        _forwardRecoveredRead();
    }

    function recoveredAuthorityHydrationState(
        AH.Query calldata,
        StreamArtistRecoveredHydrationTypes.OwnerProvenance calldata
    ) external view virtual returns (bytes memory) {
        revert StreamArtistOnboardingTypes.UnsupportedProfile();
    }

    /// @dev A concrete owner advertises supported features only after its typed importer/exporter is joined.
    function _recoveredHydrationFeatures() internal pure virtual returns (uint256) {
        return 0;
    }

    function _forwardRecoveredRead() private view {
        bytes memory result = StreamArtistRecoveredOwnerReads.read(
            _replay,
            StreamArtistOwnerHydration.Binding(
                artistRegistry, operationCoordinator, archiveV2, domainId
            ),
            _recoveredHydrationFeatures(),
            msg.data
        );
        assembly ("memory-safe") { return(add(result, 32), mload(result)) }
    }

    function authorityHydrationState(AH.Query calldata)
        external
        view
        virtual
        returns (bytes memory)
    {
        return bytes("");
    }

    function applyArtistAuthorityHydration(
        StreamArtistOnboardingTypes.ActionContext calldata c,
        AH.Query calldata q,
        AH.OwnerData calldata p,
        bytes32 value
    ) external {
        _check(c, 60);
        if (StreamArtistNativeReceipts.count() != 0) {
            revert StreamArtistOnboardingTypes.InvalidRecord();
        }
        (bytes32 delta, bytes32 nextState) = StreamArtistOwnerHydration.applyEncoded(
            _replay,
            StreamArtistOwnerHydration.Binding(
                artistRegistry, operationCoordinator, archiveV2, domainId
            ),
            msg.data
        );
        _hydrateAuthority(q, p);
        _commit(c, value, nextState, delta, bytes32(0));
    }

    function _hydrateAuthority(AH.Query calldata, AH.OwnerData calldata p) internal virtual {
        if (p.typedState.length != 0 || p.nonces.length != 0) {
            revert StreamArtistOnboardingTypes.InvalidRecord();
        }
    }

    function ownerStateSnapshotV2()
        public
        view
        virtual
        returns (StreamArtistOnboardingTypes.Snapshot memory)
    {
        return StreamArtistOnboardingTypes.Snapshot(
            domainId, _revision, _stateRoot, _recordChainTip
        );
    }

    function replayCell(bytes32 key)
        public
        view
        virtual
        returns (StreamArtistOnboardingTypes.ReplayCell memory)
    {
        return _replay[key];
    }

    function _check(StreamArtistOnboardingTypes.ActionContext calldata context, uint16 operation)
        internal
        view
    {
        StreamArtistOwnerCheck.check(
            _commitPrefix(), operationCoordinator, domainId, context, operation
        );
    }

    function _replayKey(bytes32 surface, bytes32 scope) internal view returns (bytes32) {
        return StreamArtistOwnerCommit.replayKey(
            _commitEnvironment(), address(this), surface, scope
        );
    }

    function _consume(bytes32 surface, bytes32 scope, bytes32 commitment)
        internal
        returns (bytes32 key)
    {
        key = _replayKey(surface, scope);
        if (_replay[key].status != 0) revert StreamArtistOnboardingTypes.Replay(key);
        _replay[key] = StreamArtistOnboardingTypes.ReplayCell(commitment, _revision + 1, 1, 2);
        StreamArtistAuthorityCheckpoint.noteReplay(key, _replay[key]);
    }

    function _commit(
        StreamArtistOnboardingTypes.ActionContext calldata context,
        bytes32 action,
        bytes32 nextState,
        bytes32 replayDelta,
        bytes32 record
    ) internal {
        StreamArtistOwnerCommit.commit(
            _commitPrefix(),
            _commitEnvironment(),
            context.operationId,
            context.actor,
            action,
            nextState,
            replayDelta,
            record
        );
    }

    /// @dev Additive operation35 path only. Existing one-record commits retain their old history.
    ///      The concrete Identity owner supplies appended receipt storage and admitted typed facts.
    function _commitIdentityRecovery(
        RecoveryReceipts.State storage receipts,
        StreamArtistOnboardingTypes.ActionContext calldata context,
        bytes32 action,
        bytes32 nextState,
        bytes32 replayDelta,
        RecoveryRecord.RecordFields memory fields,
        bytes32[] memory sortedRecords
    ) internal returns (RecoveryReceipts.Pair memory pair) {
        _check(context, 35);
        RecoveryReceipts.Environment memory e;
        e.chainId = deploymentChainId;
        e.registry = artistRegistry;
        e.coordinator = operationCoordinator;
        e.archive = archiveV2;
        e.owner = address(this);
        e.domain = domainId;
        e.revision = _revision;
        e.sequence = _recordSequence;
        e.tip = _recordChainTip;
        e.actor = context.actor;
        pair = RecoveryReceipts.append(receipts, e, fields, sortedRecords);
        // This paired path appends before the one original commitBatch. Ordinary writers
        // append after _commit and therefore use the already advanced local revision.
        StreamArtistNativeReceipts.record(35, pair.primaryHash, fields.artistId, 0, _revision + 1);
        StreamArtistNativeReceipts.record(35, pair.secondaryHash, fields.artistId, 0, _revision + 1);
        StreamArtistOwnerCommit.commitBatch(
            _commitPrefix(),
            _commitEnvironment(),
            context.operationId,
            context.actor,
            action,
            nextState,
            replayDelta,
            pair.recordDelta,
            pair.nextSequence,
            pair.nextTip
        );
    }

    /// @dev These four original declarations form the unchanged owner storage prefix.
    function _commitPrefix() private pure returns (StreamArtistOwnerCommit.Prefix storage s) {
        assembly ("memory-safe") { s.slot := _revision.slot }
    }

    function _commitEnvironment()
        private
        view
        returns (StreamArtistOwnerCommit.Environment memory)
    {
        return StreamArtistOwnerCommit.Environment(
            deploymentChainId, artistRegistry, operationCoordinator, archiveV2, domainId
        );
    }

    function _now() internal view returns (uint64) {
        if (block.timestamp > type(uint64).max) revert StreamArtistOnboardingTypes.InvalidRecord();
        return uint64(block.timestamp);
    }

    function _environment() internal view returns (StreamArtistHashes.Environment memory) {
        return StreamArtistHashes.Environment(deploymentChainId, artistRegistry, core, mintManager);
    }

    function artistNativeReceiptCount() external view returns (uint256) {
        return StreamArtistNativeReceipts.count();
    }

    function artistNativeReceiptAt(uint256 index) external view returns (H.Receipt memory) {
        return StreamArtistNativeReceipts.at(index);
    }

    function artistNativeReceiptRevisionAt(uint256 index) external view returns (uint64) {
        return StreamArtistNativeReceipts.revisionAt(index);
    }

    function _native(uint16 op, bytes32 record, bytes32 artistId, uint256 collectionId) internal {
        StreamArtistNativeReceipts.record(op, record, artistId, collectionId, _revision);
    }
}
