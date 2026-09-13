// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../records/StreamSnapshotManifestBytes.sol";
import "../records/StreamReferenceEnvironmentJson.sol";

/// @notice Permissionless preparation of exact immutable file-inventory JSON.
/// @dev Preparation grants no writer/source/archive authority and creates no reference head.
library StreamReferenceRenderPreparation {
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
