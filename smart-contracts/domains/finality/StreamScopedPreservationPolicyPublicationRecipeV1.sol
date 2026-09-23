// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamScopedPreservationPolicyPublicationGraphTypesV1 as T
} from "../../interfaces/stream/finality/StreamScopedPreservationPolicyPublicationGraphTypesV1.sol";
import {
    StreamScopedPreservationPolicySnapshotTypesV1 as Snapshot
} from "../../interfaces/stream/metadata/StreamScopedPreservationPolicySnapshotTypesV1.sol";
import {
    StreamScopedPreservationPolicyReferenceTypesV1 as Reference
} from "../../interfaces/stream/preservation/StreamScopedPreservationPolicyReferenceTypesV1.sol";
import {
    StreamRenderCriticalSourceTypes as Inventory
} from "../../interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamBundleArchiveTypes as Bundle
} from "../../interfaces/stream/preservation/StreamBundleArchiveTypes.sol";
import {
    IStreamGasParameterHost as Gas
} from "../../interfaces/stream/parameters/IStreamGasParameterHost.sol";

/// @notice Pure constructor projections shared by fixed deploy workers and graph verification.
library StreamScopedPreservationPolicyPublicationRecipeV1 {
    function validate(T.Recipe memory r) public view {
        Inventory.Dependencies memory d = r.inventory;
        if (
            d.chainId != block.chainid || d.readGas < 50000 || d.sourceGas < d.readGas
                || d.selectionGas < d.readGas || d.snapshotGas < d.readGas
                || d.referenceGas < d.readGas || r.readinessReadGas < 50000
                || r.readinessSourceGas < r.readinessReadGas || r.factorySourceGas < d.readGas
                || r.bundleReadGas < 50000 || r.bundleArchiveGas < r.bundleReadGas
        ) revert T.PublicationRecipeInvalid();
        for (uint256 i; i < 12; ++i) {
            if (i == 5 || i == 6) {
                if (d.targets[i] != address(0) || d.codeHashes[i] != 0) {
                    revert T.PublicationRecipeInvalid();
                }
            } else if (d.targets[i] == address(0) || d.codeHashes[i] == 0) {
                revert T.PublicationRecipeInvalid();
            }
        }
        for (uint256 i; i < 5; ++i) {
            if (d.artistTargets[i] == address(0) || d.artistCodeHashes[i] == 0) {
                revert T.PublicationRecipeInvalid();
            }
        }
        if (d.artistContentOwner == address(0) || d.artistContentOwnerCodeHash == 0) {
            revert T.PublicationRecipeInvalid();
        }
        for (uint256 i; i < 4; ++i) {
            if (r.targets[i] == address(0) || r.codeHashes[i] == 0) {
                revert T.PublicationRecipeInvalid();
            }
        }
        _gas(r.checkpointGas[0], "STATIC_CONTENT_READ_GAS", 2);
        _gas(r.checkpointGas[1], "STATIC_CONTENT_RENDER_GAS", 2);
        _gas(r.outputGas, "STATIC_OUTPUT_MANIFEST_READ_GAS", 2);
        _gas(r.snapshotGas[0], "SCOPED_POLICY_SNAPSHOT_READ_GAS", 2);
        _gas(r.snapshotGas[1], "SCOPED_POLICY_SNAPSHOT_SOURCE_GAS", 2);
        _gas(r.snapshotGas[2], "SCOPED_POLICY_SNAPSHOT_INVENTORY_GAS", 2);
        _gas(r.referenceGas[0], "SCOPED_POLICY_REFERENCE_READ_GAS", 1);
        _gas(r.referenceGas[1], "SCOPED_POLICY_REFERENCE_SOURCE_GAS", 1);
        _gas(r.referenceGas[2], "SCOPED_POLICY_REFERENCE_SNAPSHOT_GAS", 1);
        _gas(r.referenceGas[3], "SCOPED_POLICY_REFERENCE_ARCHIVE_GAS", 1);
        if (
            r.snapshotGas[1].genesisValue < r.snapshotGas[0].genesisValue
                || r.snapshotGas[2].genesisValue < r.snapshotGas[0].genesisValue
                || r.referenceGas[1].genesisValue < r.referenceGas[0].genesisValue
                || r.referenceGas[2].genesisValue < r.referenceGas[1].genesisValue
                || r.referenceGas[3].genesisValue < r.referenceGas[0].genesisValue
        ) revert T.PublicationRecipeInvalid();
    }

    function snapshot(T.Recipe memory r, T.Graph memory g)
        public
        pure
        returns (Snapshot.Dependencies memory d)
    {
        for (uint256 i; i < 5; ++i) {
            d.targets[i] = r.inventory.targets[i];
            d.codeHashes[i] = r.inventory.codeHashes[i];
        }
        d.targets[5] = r.targets[0];
        d.codeHashes[5] = r.codeHashes[0];
        d.targets[6] = r.targets[1];
        d.codeHashes[6] = r.codeHashes[1];
        d.targets[7] = g.children[1];
        d.codeHashes[7] = g.codeHashes[1];
        d.targets[8] = g.children[2];
        d.codeHashes[8] = g.codeHashes[2];
        d.targets[9] = r.inventory.targets[10];
        d.codeHashes[9] = r.inventory.codeHashes[10];
        d.targets[10] = g.sourceSet;
        d.codeHashes[10] = g.sourceSetCodeHash;
        d.chainId = r.inventory.chainId;
        d.readGas = r.snapshotGas[0].genesisValue;
        d.sourceGas = r.snapshotGas[1].genesisValue;
        d.inventoryGas = r.snapshotGas[2].genesisValue;
    }

    function referenceDependencies(T.Recipe memory r, T.Graph memory g)
        public
        pure
        returns (Reference.Dependencies memory d)
    {
        for (uint256 i; i < 5; ++i) {
            d.targets[i] = r.inventory.targets[i];
            d.codeHashes[i] = r.inventory.codeHashes[i];
        }
        d.targets[5] = g.children[3];
        d.codeHashes[5] = g.codeHashes[3];
        d.targets[6] = r.inventory.targets[11];
        d.codeHashes[6] = r.inventory.codeHashes[11];
        d.chainId = r.inventory.chainId;
        d.readGas = r.referenceGas[0].genesisValue;
        d.sourceGas = r.referenceGas[1].genesisValue;
        d.snapshotGas = r.referenceGas[2].genesisValue;
        d.archiveGas = r.referenceGas[3].genesisValue;
    }

    function inventory(T.Recipe memory r, T.Graph memory g)
        public
        pure
        returns (Inventory.Dependencies memory d)
    {
        d = r.inventory;
        d.targets[5] = g.children[3];
        d.codeHashes[5] = g.codeHashes[3];
        d.targets[6] = g.children[4];
        d.codeHashes[6] = g.codeHashes[4];
    }

    function bundle(T.Recipe memory r, T.Graph memory g)
        public
        pure
        returns (Bundle.Dependencies memory d)
    {
        d.targets[0] = r.inventory.targets[0];
        d.codeHashes[0] = r.inventory.codeHashes[0];
        d.targets[1] = r.inventory.targets[1];
        d.codeHashes[1] = r.inventory.codeHashes[1];
        d.targets[2] = g.children[5];
        d.codeHashes[2] = g.codeHashes[5];
        d.targets[3] = r.inventory.targets[10];
        d.codeHashes[3] = r.inventory.codeHashes[10];
        d.targets[4] = r.inventory.targets[11];
        d.codeHashes[4] = r.inventory.codeHashes[11];
        d.targets[5] = r.inventory.artistTargets[4];
        d.codeHashes[5] = r.inventory.artistCodeHashes[4];
        d.chainId = r.inventory.chainId;
        d.readGas = r.bundleReadGas;
        d.archiveGas = r.bundleArchiveGas;
    }

    function _gas(Gas.GasParameterConfig memory g, string memory name, uint8 failureClass)
        private
        pure
    {
        if (
            keccak256(bytes(g.name)) != keccak256(bytes(name)) || g.floor == 0
                || g.genesisValue < g.floor || g.genesisValue < 50000
                || g.genesisValue > type(uint32).max || g.failureClass != failureClass
        ) revert T.PublicationRecipeInvalid();
    }
}
