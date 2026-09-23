// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamViewPreservationContentRootV1 as B
} from "../../interfaces/stream/metadata/IStreamViewPreservationContentRootV1.sol";
import {
    IStreamScopedContentRootPublication as R
} from "../../interfaces/stream/metadata/IStreamScopedContentRootPublication.sol";
import { StreamMetadataScopedContentState as State } from "./StreamMetadataScopedContentState.sol";
import {
    StreamViewPreservationContentDefinitionsV1 as Definitions
} from "../records/StreamViewPreservationContentDefinitionsV1.sol";

/// @notice Immutable binding attached to the original Router record; never a second head/book.
library StreamMetadataViewPreservationContentStateV1 {
    struct Saved {
        B.Binding binding;
        R.Aggregate aggregate;
    }

    struct Layout {
        mapping(bytes32 => Saved) records;
    }

    function layout() private pure returns (Layout storage s) {
        bytes32 slot = keccak256("6529STREAM_ROUTER_VIEW_PRESERVATION_CONTENT_BINDINGS_V1");
        assembly ("memory-safe") { s.slot := slot }
    }

    function retain(State.State storage state, address core, bytes32 hash, B.Binding memory binding)
        internal
    {
        if (
            layout().records[hash].binding.profileId != 0
                || binding.profileId != Definitions.PROFILE
        ) {
            revert R.InvalidScopedContentRoot();
        }
        R.Record memory record = state.records[hash];
        R.Aggregate memory aggregate = state.aggregates[record.publication.scope.collectionId];
        _check(core, hash, record, binding, aggregate);
        layout().records[hash] = Saved(binding, aggregate);
    }

    function binding(State.State storage state, address core, bytes32 hash)
        internal
        view
        returns (B.Binding memory b)
    {
        Saved storage saved = layout().records[hash];
        b = saved.binding;
        if (b.profileId == 0) return b;
        _check(core, hash, state.records[hash], b, saved.aggregate);
    }

    function requireBinding(State.State storage state, address core, bytes32 hash)
        internal
        view
        returns (B.Binding memory b)
    {
        b = binding(state, core, hash);
        if (b.profileId != Definitions.PROFILE) revert R.InvalidScopedContentRoot();
    }

    function _check(
        address core,
        bytes32 hash,
        R.Record memory r,
        B.Binding memory b,
        R.Aggregate memory aggregate
    ) private view {
        State.viewSubject(core, r.publication.scope);
        if (
            hash == 0 || b.profileId != Definitions.PROFILE || r.publisher == address(0)
                || r.artistConsent == 0 || r.publishedAt == 0 || aggregate.revision == 0
                || aggregate.transitionChain == 0
                || keccak256(
                        abi.encode(
                            keccak256("6529STREAM_SCOPED_CONTENT_ROOT_RECORD_V1"),
                            block.chainid,
                            address(this),
                            core,
                            r,
                            aggregate
                        )
                    ) != hash
        ) revert R.InvalidScopedContentRoot();
        bytes32 stateHash = r.stateHash;
        r.stateHash = 0;
        r.artistConsent = 0;
        r.publishedAt = 0;
        if (
            keccak256(
                    abi.encode(
                        keccak256("6529STREAM_VIEW_PRESERVATION_CONTENT_ROOT_STATE_V1"),
                        block.chainid,
                        address(this),
                        core,
                        r,
                        b
                    )
                ) != stateHash
        ) revert R.InvalidScopedContentRoot();
    }
}
