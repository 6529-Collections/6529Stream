// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamViewPreservationFinalitySourcesV1 as Selection
} from "../../interfaces/stream/finality/IStreamViewPreservationFinalitySourcesV1.sol";
import {
    IStreamViewPreservationReferencePublicationV1 as Reference
} from "../../interfaces/stream/preservation/IStreamViewPreservationReferencePublicationV1.sol";
import {
    IStreamViewPreservationRenderCriticalInventoryV1 as Inventory
} from "../../interfaces/stream/preservation/IStreamViewPreservationRenderCriticalInventoryV1.sol";
import {
    IStreamViewPreservationBundleArchiveCoverageV1 as Bundle
} from "../../interfaces/stream/preservation/IStreamViewPreservationBundleArchiveCoverageV1.sol";
import {
    StreamViewPreservationReferenceTypesV1 as R
} from "../../interfaces/stream/preservation/StreamViewPreservationReferenceTypesV1.sol";
import {
    StreamRenderCriticalSourceTypes as I
} from "../../interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamBundleArchiveTypes as B
} from "../../interfaces/stream/preservation/StreamBundleArchiveTypes.sol";
import {
    StreamViewPreservationRenderCriticalTypesV1 as V
} from "../../interfaces/stream/preservation/StreamViewPreservationRenderCriticalTypesV1.sol";
import {
    StreamViewPreservationReferenceDefinitionsV1 as Definitions
} from "../records/StreamViewPreservationReferenceDefinitionsV1.sol";
import {
    IStreamArtworkScopedFinalityComponent
} from "../../interfaces/stream/finality/IStreamArtworkFinalityComponents.sol";
import {
    StreamPreservationInventoryIO as IO
} from "../preservation/StreamPreservationInventoryIO.sol";

/// @notice Fixed constructor/source reciprocity checks for the once-only complete VIEW binding.
/// @dev The governing host constructs Expected exclusively from its original pinned configurations
/// and authenticated basic snapshot binding. This helper confers no authority and reads no current
/// root, publication, inventory, archive evidence or finality state. Hashes retain initial gas values.
library StreamFinalityViewPreservationSourceSelectionV1 {
    struct Expected {
        address[12] targets;
        bytes32[12] codeHashes;
        address[5] artistTargets;
        bytes32[5] artistCodeHashes;
        address artistContentOwner;
        bytes32 artistContentOwnerCodeHash;
        uint256 chainId;
    }
    error InvalidViewFinalitySourceSelection();

    function requireBindings(
        Selection.Selection memory selected,
        Expected memory e,
        uint256 readGas
    )
        public
        view
        returns (
            bytes32 referenceDependenciesHash,
            bytes32 inventoryDependenciesHash,
            bytes32 bundleDependenciesHash
        )
    {
        if (
            e.chainId != block.chainid || readGas < 50000 || readGas > 16777216
                || selected.referencePublication != e.targets[6]
                || selected.referencePublicationCodeHash != e.codeHashes[6]
        ) _fail();
        for (uint256 i; i < 12; ++i) {
            IO.pin(e.targets[i], e.codeHashes[i]);
        }
        for (uint256 i; i < 5; ++i) {
            IO.pin(e.artistTargets[i], e.artistCodeHashes[i]);
        }
        IO.pin(e.artistContentOwner, e.artistContentOwnerCodeHash);
        IO.pin(selected.renderCriticalInventory, selected.renderCriticalInventoryCodeHash);
        IO.pin(selected.bundleArchiveCoverage, selected.bundleArchiveCoverageCodeHash);
        _supports(selected.referencePublication, type(Reference).interfaceId, readGas);
        _supports(
            selected.referencePublication,
            type(IStreamArtworkScopedFinalityComponent).interfaceId,
            readGas
        );
        _supports(selected.renderCriticalInventory, type(Inventory).interfaceId, readGas);
        _supports(selected.bundleArchiveCoverage, type(Bundle).interfaceId, readGas);
        referenceDependenciesHash = _reference(selected.referencePublication, e, readGas);
        inventoryDependenciesHash = _inventory(selected.renderCriticalInventory, e, readGas);
        bundleDependenciesHash = _bundle(selected, e, readGas);
    }

    function _reference(address target, Expected memory e, uint256 cap)
        private
        view
        returns (bytes32 hash)
    {
        bytes memory raw =
            IO.fixedRead(target, abi.encodeCall(Reference.dependencies, ()), 608, cap);
        R.Dependencies memory d = abi.decode(raw, (R.Dependencies));
        IO.canonical(target, raw, abi.encode(d));
        if (
            d.chainId != e.chainId || d.readGas < 50000 || d.sourceGas < d.readGas
                || d.snapshotGas < d.sourceGas || d.archiveGas < d.readGas
        ) _fail();
        uint256[7] memory roles = [uint256(0), 1, 2, 3, 4, 5, 11];
        for (uint256 i; i < 7; ++i) {
            if (d.targets[i] != e.targets[roles[i]] || d.codeHashes[i] != e.codeHashes[roles[i]]) {
                _fail();
            }
        }
        _address(target, "core()", e.targets[0], cap);
        _address(target, "metadataHost()", e.targets[1], cap);
        _address(target, "metadataRouter()", e.targets[4], cap);
        _address(target, "snapshots()", e.targets[5], cap);
        _address(target, "archiveCoverage()", e.targets[11], cap);
        if (
            uint256(_word(target, "deploymentChainId()", cap)) != e.chainId
                || _word(target, "streamModuleType()", cap) != keccak256("REFERENCE_RENDER")
                || _word(target, "streamModuleVersion()", cap)
                    != keccak256("STREAM_VIEW_PRESERVATION_REFERENCE_RENDER_IMPLEMENTATION_V1")
                || _word(target, "streamModuleSchemaHash()", cap) != Definitions.SCHEMA_HASH
        ) _fail();
        raw = IO.read(target, abi.encodeWithSignature("streamModuleManifest()"), 8192, cap);
        (string memory uri, bytes32 profile) = abi.decode(raw, (string, bytes32));
        IO.canonical(target, raw, abi.encode(uri, profile));
        if (profile != Definitions.PROFILE_HASH) _fail();
        return keccak256(abi.encode(d));
    }

    function _inventory(address target, Expected memory e, uint256 cap)
        private
        view
        returns (bytes32 hash)
    {
        bytes memory raw =
            IO.fixedRead(target, abi.encodeCall(Inventory.dependencies, ()), 1344, cap);
        I.Dependencies memory d = abi.decode(raw, (I.Dependencies));
        IO.canonical(target, raw, abi.encode(d));
        if (
            d.chainId != e.chainId || d.readGas < 50000 || d.sourceGas < d.readGas
                || d.selectionGas < d.readGas || d.snapshotGas < d.readGas
                || d.referenceGas < d.readGas || d.artistContentOwner != e.artistContentOwner
                || d.artistContentOwnerCodeHash != e.artistContentOwnerCodeHash
        ) _fail();
        for (uint256 i; i < 12; ++i) {
            if (d.targets[i] != e.targets[i] || d.codeHashes[i] != e.codeHashes[i]) _fail();
        }
        for (uint256 i; i < 5; ++i) {
            if (
                d.artistTargets[i] != e.artistTargets[i]
                    || d.artistCodeHashes[i] != e.artistCodeHashes[i]
            ) _fail();
        }
        hash = keccak256(abi.encode(d));
        if (
            _word(target, "dependencyHash()", cap) != hash
                || _word(target, "inventoryProfile()", cap) != V.PROFILE
        ) _fail();
        _address(target, "core()", e.targets[0], cap);
        _address(target, "metadataHost()", e.targets[1], cap);
        _address(target, "metadataRouter()", e.targets[4], cap);
        _address(target, "snapshots()", e.targets[5], cap);
        _address(target, "referencePublisher()", e.targets[6], cap);
        _address(target, "artifactCoverage()", e.targets[10], cap);
        _address(target, "externalCoverage()", e.targets[11], cap);
    }

    function _bundle(Selection.Selection memory s, Expected memory e, uint256 cap)
        private
        view
        returns (bytes32 hash)
    {
        address target = s.bundleArchiveCoverage;
        bytes memory raw = IO.fixedRead(target, abi.encodeWithSignature("dependencies()"), 480, cap);
        B.Dependencies memory d = abi.decode(raw, (B.Dependencies));
        IO.canonical(target, raw, abi.encode(d));
        if (d.chainId != e.chainId || d.readGas < 50000 || d.archiveGas < d.readGas) _fail();
        address[6] memory targets = [
            e.targets[0],
            e.targets[1],
            s.renderCriticalInventory,
            e.targets[10],
            e.targets[11],
            e.artistTargets[4]
        ];
        bytes32[6] memory hashes = [
            e.codeHashes[0],
            e.codeHashes[1],
            s.renderCriticalInventoryCodeHash,
            e.codeHashes[10],
            e.codeHashes[11],
            e.artistCodeHashes[4]
        ];
        for (uint256 i; i < 6; ++i) {
            if (d.targets[i] != targets[i] || d.codeHashes[i] != hashes[i]) _fail();
        }
        hash = keccak256(abi.encode(d));
        if (
            _word(target, "dependencyHash()", cap) != hash
                || _word(target, "bundleProfile()", cap)
                    != keccak256("6529STREAM_VIEW_PRESERVATION_BUNDLE_IMMUTABLE_STOP_AGGREGATE_V1")
                || uint256(_word(target, "deploymentChainId()", cap)) != e.chainId
                || _word(target, "coreCodeHash()", cap) != e.codeHashes[0]
                || _word(target, "metadataCodeHash()", cap) != e.codeHashes[1]
                || _word(target, "inventoryCodeHash()", cap) != s.renderCriticalInventoryCodeHash
        ) _fail();
        _address(target, "core()", e.targets[0], cap);
        _address(target, "metadataHost()", e.targets[1], cap);
        _address(target, "renderCriticalInventory()", s.renderCriticalInventory, cap);
        _address(target, "artifactCoverage()", e.targets[10], cap);
        _address(target, "externalCoverage()", e.targets[11], cap);
    }

    function _supports(address target, bytes4 id, uint256 cap) private view {
        if (
            IO.word(target, abi.encodeWithSignature("supportsInterface(bytes4)", id), cap)
                != bytes32(uint256(1))
        ) _fail();
    }

    function _address(address target, string memory selector, address expected, uint256 cap)
        private
        view
    {
        if (IO.addressWord(target, abi.encodeWithSignature(selector), cap) != expected) {
            _fail();
        }
    }

    function _word(address target, string memory selector, uint256 cap)
        private
        view
        returns (bytes32)
    {
        return IO.word(target, abi.encodeWithSignature(selector), cap);
    }

    function _fail() private pure {
        revert InvalidViewFinalitySourceSelection();
    }
}
