// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamViewAdoptionState as Views } from "./StreamViewAdoptionState.sol";
import {
    IStreamStaticMetadataRouter as S
} from "../../interfaces/stream/metadata/IStreamStaticMetadataRouter.sol";

/// @notice Append-only configuration records and per-collection recorded default activation.
/// @dev Internal helpers only. Writes are performed by the Router's fixed authorized worker.
library StreamMetadataStaticState {
    bytes32 internal constant FAMILY = keccak256("RENDERER_CONFIG");
    bytes32 private constant SLOT = keccak256("6529STREAM_STATIC_METADATA_CONFIG_STORAGE_V1");
    bytes32 private constant FAMILY_DOMAIN = keccak256("6529STREAM_STATIC_METADATA_FAMILY_V1");
    bytes32 private constant RECORD_DOMAIN =
        keccak256("6529STREAM_STATIC_METADATA_CONFIG_RECORD_V1");

    struct Collection {
        bytes32 activationDefault;
        bytes32 collectionOverride;
        bytes32 overridesHead;
        uint64 revision;
    }

    struct State {
        bytes32 defaultHead;
        uint64 defaultRevision;
        mapping(bytes32 => S.ConfigRecord) records;
        mapping(uint256 => Collection) collections;
        mapping(uint256 => bytes32) tokenOverrides;
        mapping(bytes32 => S.RawSource) frozenSources;
        mapping(bytes32 => S.Authorization) authorizations;
    }

    function state() internal pure returns (State storage s) {
        bytes32 slot = SLOT;
        assembly ("memory-safe") { s.slot := slot }
    }

    function activated(uint256 collectionId) internal view returns (bool) {
        return state().collections[collectionId].activationDefault != 0;
    }

    function family(address core, uint256 collectionId) internal view returns (bytes32) {
        return familyOf(core, collectionId, state().collections[collectionId]);
    }

    function familyOf(address core, uint256 collectionId, Collection memory c)
        internal
        view
        returns (bytes32)
    {
        return Views.wrap(
            core,
            collectionId,
            legacyFamilyOf(core, collectionId, c),
            Views.state().aggregates[collectionId]
        );
    }

    /// @dev Original exact preimage; new VIEW aggregation is separate and revision-zero neutral.
    function legacyFamilyOf(address core, uint256 collectionId, Collection memory c)
        internal
        view
        returns (bytes32)
    {
        return keccak256(abi.encode(FAMILY_DOMAIN, core, address(this), collectionId, c));
    }

    function withContent(address core, uint256 collectionId, bytes32 original)
        internal
        view
        returns (bytes32)
    {
        if (!activated(collectionId)) return original;
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_CONTENT_WITH_STATIC_CONFIG_V1"),
                original,
                family(core, collectionId)
            )
        );
    }

    function recordHash(address core, S.ConfigRecord memory r) internal view returns (bytes32) {
        // recordHash itself must be zero in the canonical preimage; all saved fields are retained.
        if (r.recordHash != 0) revert S.InvalidStaticMetadataConfig();
        return keccak256(abi.encode(RECORD_DOMAIN, core, address(this), r));
    }

    function resolved(uint256 collectionId, uint256 tokenId)
        internal
        view
        returns (S.ConfigRecord memory)
    {
        State storage s = state();
        Collection storage c = s.collections[collectionId];
        if (c.activationDefault == 0) revert S.StaticMetadataNotActivated(collectionId);
        bytes32 key = tokenId == 0 ? bytes32(0) : s.tokenOverrides[tokenId];
        if (key == 0) key = c.collectionOverride;
        if (key == 0) key = c.activationDefault;
        return record(key);
    }

    /// @dev Share the complete storage-to-memory copy across direct configuration reads.
    function record(bytes32 key) internal view returns (S.ConfigRecord memory) {
        return state().records[key];
    }
}
