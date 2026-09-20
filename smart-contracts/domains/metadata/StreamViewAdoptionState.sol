// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import "../../interfaces/stream/finality/StreamScopeMembershipTypes.sol";
import {
    StreamViewAdoptionTypes as V
} from "../../interfaces/stream/metadata/StreamViewAdoptionTypes.sol";
import { StreamViewPolicyTypesV2 as Policy } from "./StreamViewPolicyTypesV2.sol";
import { StreamMetadataSubjects as Subjects } from "./StreamMetadataSubjects.sol";
import { StreamViewPayloadBytes as Bytes } from "./StreamViewPayloadBytes.sol";
import { StreamSchemaDocumentStore as Store } from "./StreamSchemaDocumentStore.sol";

/// @notice New typed namespace only; original Router roots and default output remain unchanged.
library StreamViewAdoptionState {
    bytes32 private constant SLOT = keccak256("6529STREAM_ROUTER_VIEW_ADOPTION_STORAGE_V1");

    struct Carrier {
        address pointer;
        bytes32 hash;
        uint32 size;
    }

    struct State {
        mapping(bytes32 => bytes32) heads;
        mapping(bytes32 => Carrier) records;
        mapping(uint256 => V.Aggregate) aggregates;
        mapping(bytes32 => bytes32) profiles; // Appended: zero is existing V1; closed nonzero V2 tag.
    }

    function state() internal pure returns (State storage s) {
        bytes32 slot = SLOT;
        assembly ("memory-safe") { s.slot := slot }
    }

    function subject(address core, StreamFinalityScope memory scope)
        internal
        view
        returns (bytes32)
    {
        if (scope.scopeType != StreamFinalityScopeType.VIEW) {
            revert V.InvalidViewAdoption();
        }
        return Subjects.scopeSubject(block.chainid, core, scope);
    }

    function wrap(address core, uint256 cid, bytes32 legacy, V.Aggregate memory a)
        internal
        view
        returns (bytes32)
    {
        if (a.revision == 0) {
            if (a.transitionChain != 0) revert V.InvalidViewAdoption();
            return legacy;
        }
        if (a.transitionChain == 0) revert V.InvalidViewAdoption();
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_RENDERER_CONFIG_WITH_VIEWS_V1"),
                block.chainid,
                address(this),
                core,
                cid,
                legacy,
                a
            )
        );
    }

    function next(address core, V.Record memory r) internal view returns (V.Aggregate memory a) {
        bytes32 key = subject(core, r.input.scope);
        State storage s = state();
        bytes32 old = s.heads[key];
        if (old != r.input.expectedPrevious) {
            revert V.ViewAdoptionLineage(r.input.expectedPrevious, old);
        }
        a = s.aggregates[r.input.scope.collectionId];
        bytes32 prepared = keccak256(
            abi.encode(
                keccak256("6529STREAM_VIEW_PREPARED_STATE_V1"),
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
                keccak256("6529STREAM_VIEW_AGGREGATE_V1"),
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
        if (consent == 0 || block.timestamp == 0 || block.timestamp > type(uint64).max) {
            revert V.InvalidViewAdoption();
        }
        State storage s = state();
        bytes32 key = subject(core, r.input.scope);
        r.aggregate = next(core, r);
        r.revision = r.input.expectedPrevious == 0
            ? 1
            : previousRevision(core, r.input.expectedPrevious) + 1;
        r.artistConsent = consent;
        r.adoptedAt = uint64(block.timestamp);
        hash = keccak256(
            abi.encode(
                keccak256("6529STREAM_VIEW_ADOPTION_RECORD_V1"),
                block.chainid,
                address(this),
                core,
                r
            )
        );
        if (s.records[hash].pointer != address(0)) revert V.InvalidViewAdoption();
        r.recordHash = hash;
        bytes memory raw = abi.encode(r);
        if (raw.length == 0 || raw.length > 8192) revert V.InvalidViewAdoption();
        bytes32 digest = keccak256(raw);
        (bytes32 actual, address pointer) = Store(r.source.route.store).publishChunk(raw);
        if (actual != digest) revert V.ViewAdoptionChunk(pointer);
        Bytes.verify(pointer, digest, raw.length);
        s.records[hash] = Carrier(pointer, digest, uint32(raw.length));
        s.heads[key] = hash;
        s.aggregates[r.input.scope.collectionId] = r.aggregate;
    }

    /// @dev Authenticate the same canonical outer revision across both closed histories.
    /// Payload bytes and entropy semantics are never decoded as another profile here.
    function previousRevision(address core, bytes32 key) internal view returns (uint64) {
        bytes memory raw = encoded(key);
        V.Record memory r = abi.decode(raw, (V.Record));
        bytes32 tag = state().profiles[key];
        if (
            keccak256(raw) != keccak256(abi.encode(r)) || r.recordHash != key || r.revision == 0
                || (tag != 0 && tag != Policy.PROFILE)
        ) revert V.InvalidViewAdoption();
        r.recordHash = 0;
        bytes32 expected = tag == 0
            ? keccak256(
                abi.encode(
                    keccak256("6529STREAM_VIEW_ADOPTION_RECORD_V1"),
                    block.chainid,
                    address(this),
                    core,
                    r
                )
            )
            : keccak256(
                abi.encode(
                    keccak256("6529STREAM_POLICY_VIEW_ADOPTION_RECORD_V2"),
                    Policy.PROFILE,
                    block.chainid,
                    address(this),
                    core,
                    r
                )
            );
        if (expected != key) revert V.InvalidViewAdoption();
        return r.revision;
    }

    function encoded(bytes32 hash) internal view returns (bytes memory raw) {
        Carrier storage c = state().records[hash];
        if (c.pointer == address(0)) revert V.UnknownViewAdoption(hash);
        address pointer = c.pointer;
        Bytes.verify(pointer, c.hash, c.size);
        raw = new bytes(c.size);
        assembly ("memory-safe") { extcodecopy(pointer, add(raw, 32), 1, mload(raw)) }
    }
}
