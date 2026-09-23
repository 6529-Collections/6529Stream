// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import {
    IStreamScopedContentRootPublication as R
} from "../../interfaces/stream/metadata/IStreamScopedContentRootPublication.sol";
import { StreamMetadataScopedContentState as State } from "./StreamMetadataScopedContentState.sol";
import {
    StreamMetadataViewPreservationContentSourceV1 as Source
} from "./StreamMetadataViewPreservationContentSourceV1.sol";
import { StreamMetadataRouterContent as Content } from "./StreamMetadataRouterContent.sol";
import { StreamMetadataContentRoot } from "./StreamMetadataContentRoot.sol";
import "../finality/StreamContentRootSchemas.sol";

import {
    IStreamViewPreservationContentRootV1 as B
} from "../../interfaces/stream/metadata/IStreamViewPreservationContentRootV1.sol";
import {
    StreamMetadataViewPreservationContentStateV1 as Saved
} from "./StreamMetadataViewPreservationContentStateV1.sol";
import {
    StreamViewPreservationOutputSchemasV1 as Schemas
} from "../finality/StreamViewPreservationOutputSchemasV1.sol";

/// @notice Fixed original-Router VIEW preservation write transport. Uses the original consent and
/// ratification maps; the only new authority state is the compiler-owned scoped aggregate.
library StreamMetadataViewPreservationContentV1 {
    event ViewPreservationContentRootBindingPublished(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        bytes32 indexed scopeSubject,
        bytes32 indexed recordHash,
        B.Binding binding
    );
    bytes32 private constant FAMILY = keccak256("CONTENT_ROOT");

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
        (R.Record memory prepared, B.Binding memory binding) = Source.prepare(ctx, p, msg.sender);
        bytes32 nextFamily = _nextFamily(state, l, c, prepared);
        (bytes32 consent, bytes32 ratification) =
            Content.authorizeViewContentRoot(l, c, p.scope.collectionId, nextFamily);
        (R.Record memory current, B.Binding memory currentBinding) =
            Source.prepare(ctx, p, msg.sender);
        if (
            keccak256(abi.encode(current, currentBinding))
                    != keccak256(abi.encode(prepared, binding))
                || _nextFamily(state, l, c, current) != nextFamily
        ) revert R.InvalidScopedContentRoot();
        hash = State.commitView(state, c.core, prepared, consent);
        Saved.retain(state, c.core, hash, binding);
        emit ViewPreservationContentRootBindingPublished(
            1, p.scope.collectionId, State.viewSubject(c.core, p.scope), hash, binding
        );
        Content.recordApplication(l, c, p.scope.collectionId, FAMILY, consent, ratification);
    }

    function read(State.State storage state, address core, bytes calldata input)
        public
        view
        returns (bytes memory)
    {
        bytes4 selector = bytes4(input[:4]);
        if (selector == R.scopedContentRootHead.selector) {
            StreamFinalityScope memory scope = abi.decode(input[4:], (StreamFinalityScope));
            bytes32 hash = state.heads[State.viewSubject(core, scope)];
            if (hash != 0) Saved.requireBinding(state, core, hash);
            return abi.encode(hash);
        }
        if (selector == R.scopedContentRootRecord.selector) {
            bytes32 hash = abi.decode(input[4:], (bytes32));
            Saved.requireBinding(state, core, hash);
            R.Record memory record = state.records[hash];
            if (record.publisher == address(0)) revert R.ScopedContentRootUnknown(hash);
            return abi.encode(record);
        }
        if (selector == R.scopedTokenContentRoot.selector) {
            StreamFinalityScope memory scope = abi.decode(input[4:], (StreamFinalityScope));
            bytes32 hash = state.heads[State.viewSubject(core, scope)];
            if (hash != 0) Saved.requireBinding(state, core, hash);
            R.Record memory record = state.records[hash];
            return abi.encode(
                record.contentRoot,
                record.leafCount,
                record.leafCount == 0 ? bytes32(0) : Schemas.LEAF
            );
        }
        revert R.InvalidScopedContentRoot();
    }

    function readBinding(State.State storage state, address core, bytes32 hash)
        public
        view
        returns (B.Binding memory)
    {
        return Saved.binding(state, core, hash);
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
            State.nextView(state, c.core, prepared)
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
