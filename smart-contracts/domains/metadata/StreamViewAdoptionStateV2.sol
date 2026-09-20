// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamViewAdoptionTypes as V
} from "../../interfaces/stream/metadata/StreamViewAdoptionTypes.sol";
import { StreamViewPolicyTypesV2 as T } from "./StreamViewPolicyTypesV2.sol";
import { StreamViewAdoptionState as Original } from "./StreamViewAdoptionState.sol";
import { StreamViewPayloadBytes as Bytes } from "./StreamViewPayloadBytes.sol";
import { StreamSchemaDocumentStore as Store } from "./StreamSchemaDocumentStore.sol";

/// @notice Closed V2 writes into the original single VIEW head/history/aggregate namespace.
/// @dev Only the original Router's authorized worker reaches commit. No separate consent book.
library StreamViewAdoptionStateV2 {
    function profile(bytes32 key) internal view returns (bytes32 tag) {
        Original.State storage s = Original.state();
        if (s.records[key].pointer == address(0)) revert V.UnknownViewAdoption(key);
        tag = s.profiles[key];
        if (tag != 0 && tag != T.PROFILE) revert V.InvalidViewAdoption();
    }

    function next(address core, V.Record memory r) internal view returns (V.Aggregate memory a) {
        bytes32 key = Original.subject(core, r.input.scope);
        Original.State storage s = Original.state();
        bytes32 old = s.heads[key];
        if (old != r.input.expectedPrevious) {
            revert V.ViewAdoptionLineage(r.input.expectedPrevious, old);
        }
        if (r.source.renderer.contextVersion != T.CONTEXT) revert V.InvalidViewAdoption();
        a = s.aggregates[r.input.scope.collectionId];
        bytes32 prepared = keccak256(
            abi.encode(
                keccak256("6529STREAM_POLICY_VIEW_PREPARED_STATE_V2"),
                T.PROFILE,
                r.input,
                r.sourceHash,
                r.actor,
                r.authorizationClass,
                r.grantCollectionId,
                r.grantRevision
            )
        );
        a.revision += 1;
        a.transitionChain = keccak256(
            abi.encode(
                keccak256("6529STREAM_POLICY_VIEW_AGGREGATE_V2"),
                T.PROFILE,
                block.chainid,
                address(this),
                core,
                r.input.scope.collectionId,
                a.transitionChain,
                a.revision,
                key,
                old,
                prepared
            )
        );
    }

    function commit(address core, V.Record memory r, bytes32 consent)
        internal
        returns (bytes32 hash)
    {
        if (
            consent == 0 || block.timestamp == 0 || block.timestamp > type(uint64).max
                || r.recordHash != 0
        ) revert V.InvalidViewAdoption();
        Original.State storage s = Original.state();
        bytes32 key = Original.subject(core, r.input.scope);
        r.aggregate = next(core, r);
        r.revision = r.input.expectedPrevious == 0
            ? 1
            : Original.previousRevision(core, r.input.expectedPrevious) + 1;
        r.artistConsent = consent;
        r.adoptedAt = uint64(block.timestamp);
        hash = keccak256(
            abi.encode(
                keccak256("6529STREAM_POLICY_VIEW_ADOPTION_RECORD_V2"),
                T.PROFILE,
                block.chainid,
                address(this),
                core,
                r
            )
        );
        if (s.records[hash].pointer != address(0) || s.profiles[hash] != 0) {
            revert V.InvalidViewAdoption();
        }
        r.recordHash = hash;
        bytes memory raw = abi.encode(r);
        if (raw.length == 0 || raw.length > 8192) revert V.InvalidViewAdoption();
        bytes32 digest = keccak256(raw);
        (bytes32 actual, address pointer) = Store(r.source.route.store).publishChunk(raw);
        if (actual != digest) revert V.ViewAdoptionChunk(pointer);
        Bytes.verify(pointer, digest, raw.length);
        s.records[hash] = Original.Carrier(pointer, digest, uint32(raw.length));
        s.profiles[hash] = T.PROFILE;
        s.heads[key] = hash;
        s.aggregates[r.input.scope.collectionId] = r.aggregate;
    }
}
