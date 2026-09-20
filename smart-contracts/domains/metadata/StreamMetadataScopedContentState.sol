// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamScopedContentRootPublication as R
} from "../../interfaces/stream/metadata/IStreamScopedContentRootPublication.sol";
import "./StreamMetadataSubjects.sol";

/// @notice Constant-cost scope-head transitions in one appended compiler-owned Router state.
/// @dev No new authorization book. The original Router consumes op17 before calling commit,
/// and retains its original post-write ratification/evolution accounting.
library StreamMetadataScopedContentState {
    struct State {
        mapping(bytes32 => bytes32) heads;
        mapping(bytes32 => R.Record) records;
        mapping(uint256 => R.Aggregate) aggregates;
    }
    event ScopedContentRootPublished(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        bytes32 indexed scopeSubject,
        bytes32 indexed recordHash,
        R.Record record,
        R.Aggregate collectionAggregate
    );

    function subject(address core, StreamFinalityScope memory scope)
        internal
        view
        returns (bytes32)
    {
        if (
            scope.scopeType != StreamFinalityScopeType.TOKEN
                && scope.scopeType != StreamFinalityScopeType.RELEASE
                && scope.scopeType != StreamFinalityScopeType.SEASON
        ) revert R.InvalidScopedContentRoot();
        return StreamMetadataSubjects.scopeSubject(block.chainid, core, scope);
    }

    function next(State storage state, address core, R.Record memory record)
        internal
        view
        returns (R.Aggregate memory result)
    {
        bytes32 id = subject(core, record.publication.scope);
        bytes32 oldHead = state.heads[id];
        if (record.publication.expectedPredecessor != oldHead) {
            revert R.ScopedContentRootLineage(record.publication.expectedPredecessor, oldHead);
        }
        if (record.stateHash == 0) revert R.InvalidScopedContentRoot();
        R.Aggregate memory prior = state.aggregates[record.publication.scope.collectionId];
        if (prior.revision == type(uint64).max) revert R.InvalidScopedContentRoot();
        result.revision = prior.revision + 1;
        result.transitionChain = keccak256(
            abi.encode(
                keccak256("6529STREAM_SCOPED_CONTENT_ROOT_APPEND_V1"),
                block.chainid,
                address(this),
                core,
                record.publication.scope.collectionId,
                prior.transitionChain,
                result.revision,
                id,
                oldHead,
                record.stateHash
            )
        );
    }

    function family(
        address core,
        uint256 collectionId,
        bytes32 legacy,
        R.Aggregate memory aggregate
    ) public view returns (bytes32) {
        if (aggregate.revision == 0) return legacy;
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_CONTENT_ROOT_FAMILY_WITH_SCOPES_V1"),
                block.chainid,
                address(this),
                core,
                collectionId,
                legacy,
                aggregate
            )
        );
    }

    function serving(
        address core,
        uint256 collectionId,
        bytes32 original,
        R.Aggregate memory aggregate
    ) public view returns (bytes32) {
        if (aggregate.revision == 0) return original;
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ROUTER_CONTENT_WITH_SCOPED_ROOTS_V1"),
                block.chainid,
                address(this),
                core,
                collectionId,
                original,
                aggregate
            )
        );
    }

    function familyCurrent(address core, uint256 collectionId, bytes32 legacy)
        public
        view
        returns (bytes32)
    {
        return family(core, collectionId, legacy, _aggregate(collectionId));
    }

    function servingCurrent(address core, uint256 collectionId, bytes32 original)
        public
        view
        returns (bytes32)
    {
        return serving(core, collectionId, original, _aggregate(collectionId));
    }

    /// @dev The delegate host's getter is exactly two compiler-owned storage reads. It makes
    /// no dependency call and does not recurse into this worker. Never accepts another host.
    function _aggregate(uint256 collectionId) private view returns (R.Aggregate memory result) {
        bytes memory input = abi.encodeCall(R.scopedContentRootAggregate, (collectionId));
        bytes memory out = new bytes(64);
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(50000, address(), add(input, 32), mload(input), add(out, 32), 64)
            size := returndatasize()
        }
        if (!ok || size != 64) {
            revert R.ScopedContentRootRead(address(this), R.scopedContentRootAggregate.selector);
        }
        result = abi.decode(out, (R.Aggregate));
    }

    function commit(State storage state, address core, R.Record memory record, bytes32 consent)
        public
        returns (bytes32 hash)
    {
        if (
            consent == 0 || record.publisher == address(0) || record.artistConsent != 0
                || record.publishedAt != 0 || block.timestamp == 0
                || block.timestamp > type(uint64).max
        ) {
            revert R.InvalidScopedContentRoot();
        }
        R.Aggregate memory aggregate = next(state, core, record);
        record.artistConsent = consent;
        record.publishedAt = uint64(block.timestamp);
        hash = keccak256(
            abi.encode(
                keccak256("6529STREAM_SCOPED_CONTENT_ROOT_RECORD_V1"),
                block.chainid,
                address(this),
                core,
                record,
                aggregate
            )
        );
        if (state.records[hash].publisher != address(0)) revert R.InvalidScopedContentRoot();
        bytes32 id = subject(core, record.publication.scope);
        state.records[hash] = record;
        state.heads[id] = hash;
        state.aggregates[record.publication.scope.collectionId] = aggregate;
        emit ScopedContentRootPublished(
            1, record.publication.scope.collectionId, id, hash, record, aggregate
        );
    }
}
