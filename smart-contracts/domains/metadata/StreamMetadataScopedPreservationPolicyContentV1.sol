// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamScopedContentRootPublication as R
} from "../../interfaces/stream/metadata/IStreamScopedContentRootPublication.sol";
import {
    IStreamScopedPreservationPolicyContentRootPublicationV1 as V
} from "../../interfaces/stream/metadata/IStreamScopedPreservationPolicyContentRootPublicationV1.sol";
import { StreamMetadataScopedContentState as State } from "./StreamMetadataScopedContentState.sol";
import {
    StreamMetadataScopedPreservationPolicyContentStateV1 as Companion
} from "./StreamMetadataScopedPreservationPolicyContentStateV1.sol";
import {
    StreamMetadataScopedPreservationPolicyContentSourceV1 as Source
} from "./StreamMetadataScopedPreservationPolicyContentSourceV1.sol";
import { StreamMetadataRouterContent as Content } from "./StreamMetadataRouterContent.sol";
import { StreamMetadataContentRoot } from "./StreamMetadataContentRoot.sol";
import {
    StreamScopedPreservationPolicyContentRootSchemasV1 as Schemas
} from "../finality/StreamScopedPreservationPolicyContentRootSchemasV1.sol";

/// @notice Preservation interpretation over the original scoped history and CONTENT_ROOT authority.
library StreamMetadataScopedPreservationPolicyContentV1 {
    bytes32 private constant FAMILY = keccak256("CONTENT_ROOT");
    event ScopedContentRootPublished(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        bytes32 indexed scopeSubject,
        bytes32 indexed recordHash,
        R.Record record,
        R.Aggregate collectionAggregate
    );
    event ScopedPreservationPolicyContentRootBindingPublished(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        bytes32 indexed scopeSubject,
        bytes32 indexed recordHash,
        V.Binding binding
    );

    function preview(
        State.State storage state,
        Content.Layout memory l,
        Content.Context memory c,
        R.Publication memory p,
        address publisher
    ) public view returns (bytes32) {
        (R.Record memory prepared,) = Source.prepare(Source.Context(c.core, c.artist), p, publisher);
        return _nextFamily(state, l, c, prepared);
    }

    function publish(
        State.State storage state,
        Content.Layout memory l,
        Content.Context memory c,
        R.Publication memory p
    ) public returns (bytes32 hash) {
        Source.Context memory ctx = Source.Context(c.core, c.artist);
        (R.Record memory prepared, V.Binding memory binding) = Source.prepare(ctx, p, msg.sender);
        bytes32 nextFamily = _nextFamily(state, l, c, prepared);
        (bytes32 consent, bytes32 ratification) =
            Content.authorize(l, c, p.scope.collectionId, FAMILY, nextFamily);
        (R.Record memory current, V.Binding memory currentBinding) =
            Source.prepare(ctx, p, msg.sender);
        if (
            keccak256(abi.encode(current, currentBinding))
                    != keccak256(abi.encode(prepared, binding))
                || _nextFamily(state, l, c, current) != nextFamily
        ) revert R.InvalidScopedContentRoot();
        hash = _commit(state, c.core, prepared, binding, consent);
        Content.recordApplication(l, c, p.scope.collectionId, FAMILY, consent, ratification);
    }

    function readBinding(bytes32 hash) public view returns (V.Binding memory result) {
        result = Companion.state().bindings[hash];
        if (result.profileId != 0 && result.profileId != Schemas.PROFILE) {
            revert R.InvalidScopedContentRoot();
        }
    }

    function _commit(
        State.State storage state,
        address core,
        R.Record memory record,
        V.Binding memory binding,
        bytes32 consent
    ) private returns (bytes32 hash) {
        if (
            consent == 0 || record.publisher == address(0) || record.artistConsent != 0
                || record.publishedAt != 0 || block.timestamp == 0
                || block.timestamp > type(uint64).max || binding.profileId != Schemas.PROFILE
        ) revert R.InvalidScopedContentRoot();
        R.Aggregate memory aggregate = State.next(state, core, record);
        record.artistConsent = consent;
        record.publishedAt = uint64(block.timestamp);
        hash = keccak256(
            abi.encode(
                keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_CONTENT_ROOT_RECORD_V1"),
                block.chainid,
                address(this),
                core,
                record,
                binding,
                aggregate
            )
        );
        Companion.State storage companion = Companion.state();
        if (state.records[hash].publisher != address(0) || companion.bindings[hash].profileId != 0)
        {
            revert R.InvalidScopedContentRoot();
        }
        bytes32 id = State.subject(core, record.publication.scope);
        state.records[hash] = record;
        state.heads[id] = hash;
        state.aggregates[record.publication.scope.collectionId] = aggregate;
        companion.bindings[hash] = binding;
        emit ScopedContentRootPublished(
            3, record.publication.scope.collectionId, id, hash, record, aggregate
        );
        emit ScopedPreservationPolicyContentRootBindingPublished(
            1, record.publication.scope.collectionId, id, hash, binding
        );
    }

    function _nextFamily(
        State.State storage state,
        Content.Layout memory l,
        Content.Context memory c,
        R.Record memory prepared
    ) private view returns (bytes32) {
        uint256 cid = prepared.publication.scope.collectionId;
        return State.family(
            c.core,
            cid,
            StreamMetadataContentRoot.familyState(_legacy(l), c.core, cid),
            State.next(state, c.core, prepared)
        );
    }

    function _legacy(Content.Layout memory l)
        private
        pure
        returns (StreamMetadataContentRoot.State storage value)
    {
        uint256 slot = l._contentRoots;
        assembly ("memory-safe") { value.slot := slot }
    }
}
