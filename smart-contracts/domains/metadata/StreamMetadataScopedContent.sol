// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import {
    IStreamScopedContentRootPublication as R
} from "../../interfaces/stream/metadata/IStreamScopedContentRootPublication.sol";
import { StreamMetadataScopedContentState as State } from "./StreamMetadataScopedContentState.sol";
import {
    StreamMetadataScopedContentSource as Source
} from "./StreamMetadataScopedContentSource.sol";
import { StreamMetadataRouterContent as Content } from "./StreamMetadataRouterContent.sol";
import { StreamMetadataContentRoot } from "./StreamMetadataContentRoot.sol";
import "../finality/StreamContentRootSchemas.sol";
import {
    StreamMetadataScopedPolicyContentStateV2 as PolicyState
} from "./StreamMetadataScopedPolicyContentStateV2.sol";
import {
    StreamScopedPolicyContentRootSchemasV2 as PolicyRootSchemas
} from "../finality/StreamScopedPolicyContentRootSchemasV2.sol";
import {
    StreamScopedPolicyOutputSchemasV2 as PolicyOutputSchemas
} from "../finality/StreamScopedPolicyOutputSchemasV2.sol";

import {
    StreamMetadataScopedPreservationPolicyContentStateV1 as PreservationState
} from "./StreamMetadataScopedPreservationPolicyContentStateV1.sol";
import {
    StreamScopedPreservationPolicyContentRootSchemasV1 as PreservationSchemas
} from "../finality/StreamScopedPreservationPolicyContentRootSchemasV1.sol";
import {
    StreamPreservationPolicyOutputSchemasV1 as PreservationOutput
} from "../finality/StreamPreservationPolicyOutputSchemasV1.sol";

import {
    StreamMetadataViewPreservationContentV1 as ViewPreservation
} from "./StreamMetadataViewPreservationContentV1.sol";

/// @notice Fixed original-Router scoped write transport. Uses the original consent and
/// ratification maps; the only new authority state is the compiler-owned scoped aggregate.
library StreamMetadataScopedContent {
    bytes32 private constant FAMILY = keccak256("CONTENT_ROOT");

    function preview(
        State.State storage state,
        Content.Layout memory l,
        Content.Context memory c,
        R.Publication memory p,
        address publisher
    ) public view returns (bytes32) {
        R.Record memory prepared = Source.prepare(Source.Context(c.core, c.artist), p, publisher);
        return _nextFamily(state, l, c, prepared);
    }

    function publish(
        State.State storage state,
        Content.Layout memory l,
        Content.Context memory c,
        R.Publication memory p
    ) public returns (bytes32 hash) {
        Source.Context memory ctx = Source.Context(c.core, c.artist);
        R.Record memory prepared = Source.prepare(ctx, p, msg.sender);
        bytes32 nextFamily = _nextFamily(state, l, c, prepared);
        (bytes32 consent, bytes32 ratification) =
            Content.authorize(l, c, p.scope.collectionId, FAMILY, nextFamily);
        R.Record memory current = Source.prepare(ctx, p, msg.sender);
        if (
            keccak256(abi.encode(current)) != keccak256(abi.encode(prepared))
                || _nextFamily(state, l, c, current) != nextFamily
        ) revert R.InvalidScopedContentRoot();
        hash = State.commit(state, c.core, prepared, consent);
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
            if (scope.scopeType == StreamFinalityScopeType.VIEW) {
                return ViewPreservation.read(state, core, input);
            }
            bytes32 hash = state.heads[State.subject(core, scope)];
            _policyProfile(state, hash, scope);
            return abi.encode(hash);
        }
        if (selector == R.scopedContentRootRecord.selector) {
            bytes32 hash = abi.decode(input[4:], (bytes32));
            R.Record memory record = state.records[hash];
            if (record.publisher == address(0)) revert R.ScopedContentRootUnknown(hash);
            if (record.publication.scope.scopeType == StreamFinalityScopeType.VIEW) {
                return ViewPreservation.read(state, core, input);
            }
            return abi.encode(record);
        }
        if (selector == R.scopedTokenContentRoot.selector) {
            StreamFinalityScope memory scope = abi.decode(input[4:], (StreamFinalityScope));
            if (scope.scopeType == StreamFinalityScopeType.VIEW) {
                return ViewPreservation.read(state, core, input);
            }
            bytes32 hash = state.heads[State.subject(core, scope)];
            R.Record memory record = state.records[hash];
            bytes32 profile = _policyProfile(state, hash, scope);
            bytes32 schema = profile == PreservationSchemas.PROFILE
                ? PreservationOutput.LEAF_SCHEMA
                : profile == PolicyRootSchemas.PROFILE
                    ? PolicyOutputSchemas.LEAF_SCHEMA
                    : StreamContentRootSchemas.LEAF_SCHEMA;
            return abi.encode(
                record.contentRoot, record.leafCount, record.leafCount == 0 ? bytes32(0) : schema
            );
        }
        revert R.InvalidScopedContentRoot();
    }

    function _policyProfile(
        State.State storage state,
        bytes32 hash,
        StreamFinalityScope memory scope
    ) private view returns (bytes32 profile) {
        profile = PolicyState.state().bindings[hash].profileId;
        bytes32 preservation = PreservationState.state().bindings[hash].profileId;
        if (preservation != 0) {
            if (
                preservation != PreservationSchemas.PROFILE || profile != 0
                    || keccak256(abi.encode(state.records[hash].publication.scope))
                        != keccak256(abi.encode(scope))
            ) revert R.InvalidScopedContentRoot();
            return preservation;
        }
        if (profile == 0) return profile;
        if (
            profile != PolicyRootSchemas.PROFILE
                || keccak256(abi.encode(state.records[hash].publication.scope))
                    != keccak256(abi.encode(scope))
        ) revert R.InvalidScopedContentRoot();
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
