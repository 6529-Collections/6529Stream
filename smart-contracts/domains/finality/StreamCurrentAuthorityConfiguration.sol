// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamCurrentAuthorityInventory as AuthorityInventory
} from "../../interfaces/stream/preservation/IStreamCurrentAuthorityInventory.sol";
import {
    StreamCurrentAuthorityInventorySelection as Selection
} from "../preservation/StreamCurrentAuthorityInventorySelection.sol";
import {
    StreamCurrentAuthorityBundleArchiveEnvironment as Environment
} from "../preservation/StreamCurrentAuthorityBundleArchiveEnvironment.sol";
import {
    StreamArtistCurrentAuthorityTypes as C
} from "../../interfaces/stream/artist/StreamArtistCurrentAuthorityTypes.sol";
import {
    StreamCurrentAuthorityInventoryTypes as CurrentInventoryTypes
} from "../../interfaces/stream/preservation/StreamCurrentAuthorityInventoryTypes.sol";

import {
    StreamArtistArchiveOriginTypes as O
} from "../../interfaces/stream/preservation/StreamArtistArchiveOriginTypes.sol";
import {
    StreamRenderCriticalSourceTypes as S
} from "../../interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamBundleArchiveTypes as B
} from "../../interfaces/stream/preservation/StreamBundleArchiveTypes.sol";
import {
    IStreamArtistArchiveOriginInventory as Inventory
} from "../../interfaces/stream/preservation/IStreamArtistArchiveOriginInventory.sol";
import { StreamFinalityBoundedReads as Reads } from "./StreamFinalityBoundedReads.sol";

/// @notice Explicit additive inventory and coverage configuration, preserving all source pins.
/// @dev Does not establish current inventory, Archive liveness or selected Finality by itself.
/// Provider statements retain those checks and the original Registry/Discovery/adapter reciprocity.
library StreamCurrentAuthorityConfiguration {
    error InvalidFinalityArchiveConfiguration(address target);

    function read(
        address[22] memory targets,
        bytes32[22] memory hashes,
        uint256 chainId,
        uint256 readGas,
        bytes32 dependencyHash,
        bytes32 inventoryProfile
    ) public view returns (S.Dependencies memory d, O.Dependencies memory od) {
        bytes32 coverageProfile = Environment.coverageProfile(inventoryProfile);
        if (
            chainId != block.chainid || readGas < 50000 || readGas > type(uint64).max
                || dependencyHash == 0
        ) {
            revert InvalidFinalityArchiveConfiguration(targets[18]);
        }
        for (uint256 i; i < 22; ++i) {
            _pin(targets[i], hashes[i]);
        }
        address inventory = targets[18];
        bytes memory raw =
            Reads.read(inventory, abi.encodeWithSignature("dependencies()"), 1344, readGas);
        d = abi.decode(raw, (S.Dependencies));
        _canonical(inventory, raw, abi.encode(d));
        if (
            d.chainId != chainId || d.artistTargets[0] != targets[11]
                || d.artistCodeHashes[0] != hashes[11]
        ) {
            revert InvalidFinalityArchiveConfiguration(inventory);
        }
        uint256[12] memory indexes = [uint256(0), 1, 4, 5, 2, 8, 9, 15, 16, 17, 20, 21];
        for (uint256 i; i < 12; ++i) {
            if (d.targets[i] != targets[indexes[i]] || d.codeHashes[i] != hashes[indexes[i]]) {
                revert InvalidFinalityArchiveConfiguration(inventory);
            }
        }
        for (uint256 i; i < 5; ++i) {
            _pin(d.artistTargets[i], d.artistCodeHashes[i]);
        }
        _pin(d.artistContentOwner, d.artistContentOwnerCodeHash);
        raw = Reads.read(inventory, abi.encodeCall(Inventory.originDependencies, ()), 128, readGas);
        od = abi.decode(raw, (O.Dependencies));
        _canonical(inventory, raw, abi.encode(od));
        raw = Reads.read(
            inventory, abi.encodeCall(AuthorityInventory.originalAnchor, ()), 1344, readGas
        );
        _canonical(inventory, raw, abi.encode(d));
        raw = Reads.read(
            inventory, abi.encodeCall(AuthorityInventory.authorityDependencies, ()), 96, readGas
        );
        CurrentInventoryTypes.Dependencies memory authority =
            abi.decode(raw, (CurrentInventoryTypes.Dependencies));
        _canonical(inventory, raw, abi.encode(authority));
        if (
            od.profile != O.PROFILE || od.originGas < 50000 || od.originGas > type(uint64).max
                || _word(inventory, abi.encodeCall(Inventory.originProfile, ()), readGas)
                    != inventoryProfile
                || CurrentInventoryTypes.dependencyHash(inventoryProfile, d, od, authority)
                    != dependencyHash
                || _word(inventory, abi.encodeWithSignature("dependencyHash()"), readGas)
                    != dependencyHash
        ) {
            revert InvalidFinalityArchiveConfiguration(inventory);
        }
        _pin(od.worker, od.workerCodeHash);
        _bundle(
            targets, hashes, chainId, readGas, d, od, authority, inventoryProfile, coverageProfile
        );
        Selection.Config memory selectionConfig = Selection.Config(d, authority);
        C.Anchors memory anchors = Selection.validate(selectionConfig);
        if (
            anchors.targets[4] != address(this) || anchors.codeHashes[4] != address(this).codehash
                || anchors.finalityRegistry != targets[12]
        ) revert InvalidFinalityArchiveConfiguration(authority.resolver);
        CurrentInventoryTypes.Capture memory current = Selection.resolve(selectionConfig);
        d = current.dependencies;
    }

    function _bundle(
        address[22] memory targets,
        bytes32[22] memory hashes,
        uint256 chainId,
        uint256 readGas,
        S.Dependencies memory d,
        O.Dependencies memory od,
        CurrentInventoryTypes.Dependencies memory authority,
        bytes32 inventoryProfile,
        bytes32 coverageProfile
    ) private view {
        address bundle = targets[19];
        bytes memory raw =
            Reads.read(bundle, abi.encodeWithSignature("dependencies()"), 480, readGas);
        B.Dependencies memory b = abi.decode(raw, (B.Dependencies));
        _canonical(bundle, raw, abi.encode(b));
        uint256[5] memory indexes = [uint256(0), 1, 18, 20, 21];
        for (uint256 i; i < 5; ++i) {
            if (b.targets[i] != targets[indexes[i]] || b.codeHashes[i] != hashes[indexes[i]]) {
                revert InvalidFinalityArchiveConfiguration(bundle);
            }
        }
        if (
            b.chainId != chainId || b.readGas < 50000 || b.archiveGas < b.readGas
                || b.archiveGas > type(uint64).max || b.targets[5] != d.artistTargets[4]
                || b.codeHashes[5] != d.artistCodeHashes[4]
        ) revert InvalidFinalityArchiveConfiguration(bundle);
        raw = Reads.read(bundle, abi.encodeWithSignature("originDependencies()"), 128, readGas);
        O.Dependencies memory bo = abi.decode(raw, (O.Dependencies));
        _canonical(bundle, raw, abi.encode(bo));
        raw = Reads.read(bundle, abi.encodeWithSignature("authorityDependencies()"), 96, readGas);
        _canonical(bundle, raw, abi.encode(authority));
        if (
            keccak256(abi.encode(bo)) != keccak256(abi.encode(od))
                || _word(bundle, abi.encodeWithSignature("originProfile()"), readGas)
                    != coverageProfile
                || _word(bundle, abi.encodeWithSignature("INVENTORY_PROFILE()"), readGas)
                    != inventoryProfile
                || _word(bundle, abi.encodeWithSignature("dependencyHash()"), readGas)
                    != keccak256(abi.encode(coverageProfile, inventoryProfile, b, od, authority))
        ) {
            revert InvalidFinalityArchiveConfiguration(bundle);
        }
    }

    function _word(address target, bytes memory input, uint256 cap) private view returns (bytes32) {
        return abi.decode(Reads.read(target, input, 32, cap), (bytes32));
    }

    function _pin(address target, bytes32 hash) private view {
        if (target.code.length == 0 || hash == 0 || target.codehash != hash) {
            revert InvalidFinalityArchiveConfiguration(target);
        }
    }

    function _canonical(address target, bytes memory raw, bytes memory expected) private pure {
        if (keccak256(raw) != keccak256(expected)) {
            revert InvalidFinalityArchiveConfiguration(target);
        }
    }
}
