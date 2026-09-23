// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../records/StreamSnapshotManifestBytes.sol";
import "../records/StreamReferenceEnvironmentJson.sol";

/// @notice Permissionless preparation of exact immutable file-inventory JSON.
/// @dev Preparation grants no writer/source/archive authority and creates no reference head.
library StreamReferenceRenderPreparation {
    event ReferenceEnvironmentPrepared(
        uint16 schemaVersion, bytes32 indexed environmentId, bytes32 contentHash, uint32 byteLength
    );

    function inventoryId(StreamReferenceRenderTypes.PackageFile[] memory rows, bool relative)
        public
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_REFERENCE_FILE_INVENTORY_V1"),
                block.chainid,
                address(this),
                relative,
                rows
            )
        );
    }

    function prepare(
        mapping(bytes32 => StreamSnapshotManifestBytes.Manifest) storage inventories,
        address store,
        bytes32 storeCodeHash,
        StreamReferenceRenderTypes.PackageFile[] memory rows,
        bool relative
    ) public returns (bytes32 id) {
        if (store.code.length == 0 || store.codehash != storeCodeHash) {
            revert StreamReferenceRenderTypes.ReferenceDependency(store);
        }
        id = inventoryId(rows, relative);
        if (inventories[id].contentHash != 0) {
            StreamSnapshotManifestBytes.requireIntact(inventories[id]);
            return id;
        }
        bytes memory raw = bytes(StreamReferenceEnvironmentJson.files(rows, relative));
        StreamSnapshotManifestBytes.retain(inventories[id], store, raw);
    }

    function environment(
        mapping(bytes32 => StreamSnapshotManifestBytes.Manifest) storage inventories,
        StreamReferenceRenderTypes.Environment memory e
    ) public view returns (bytes memory) {
        bytes32 id = environmentIdInternal(e);
        if (inventories[id].contentHash != 0) {
            return StreamSnapshotManifestBytes.read(inventories[id]);
        }
        return _environment(inventories, e);
    }

    function prepareEnvironment(
        mapping(bytes32 => StreamSnapshotManifestBytes.Manifest) storage inventories,
        address store,
        bytes32 storeCodeHash,
        bytes calldata original
    ) public returns (bytes32 id) {
        if (store.code.length == 0 || store.codehash != storeCodeHash) {
            revert StreamReferenceRenderTypes.ReferenceDependency(store);
        }
        StreamReferenceRenderTypes.Environment memory e =
            abi.decode(original[4:], (StreamReferenceRenderTypes.Environment));
        id = environmentIdInternal(e);
        if (inventories[id].contentHash != 0) {
            StreamSnapshotManifestBytes.requireIntact(inventories[id]);
            return id;
        }
        bytes memory raw = _environment(inventories, e);
        if (keccak256(raw) != e.manifestHash || raw.length != e.manifestBytes) {
            revert StreamReferenceRenderTypes.InvalidReferenceRender();
        }
        bytes32 hash = StreamSnapshotManifestBytes.retain(inventories[id], store, raw);
        emit ReferenceEnvironmentPrepared(1, id, hash, uint32(raw.length));
    }

    /// @dev This cache authenticates only the original deterministic serialization of this
    /// complete typed input. No source, writer, dependency, currentness or finality fact is cached.
    /// The compiler-declared map's existing producers never replace a retained entry.
    function environmentIdInternal(StreamReferenceRenderTypes.Environment memory e)
        internal
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_REFERENCE_ENVIRONMENT_PREPARATION_V1"),
                block.chainid,
                address(this),
                e
            )
        );
    }

    function _environment(
        mapping(bytes32 => StreamSnapshotManifestBytes.Manifest) storage inventories,
        StreamReferenceRenderTypes.Environment memory e
    ) private view returns (bytes memory) {
        bytes memory packageJSON =
            StreamSnapshotManifestBytes.read(inventories[inventoryId(e.packageFiles, true)]);
        bytes memory platformJSON = StreamSnapshotManifestBytes.read(
            inventories[inventoryId(e.platformPrerequisites, false)]
        );
        return StreamReferenceEnvironmentJson.manifestWithAuthenticatedFilesInternal(
            e, packageJSON, platformJSON
        );
    }
}
