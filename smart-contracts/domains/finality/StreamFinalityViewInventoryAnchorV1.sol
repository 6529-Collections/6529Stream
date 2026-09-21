// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamFinalityNativeProviderReads as Native
} from "./StreamFinalityNativeProviderReads.sol";
import {
    StreamRenderCriticalSourceTypes as S
} from "../../interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamCurrentAuthorityInventoryTypes as D
} from "../../interfaces/stream/preservation/StreamCurrentAuthorityInventoryTypes.sol";
import {
    StreamArtistArchiveOriginTypes as O
} from "../../interfaces/stream/preservation/StreamArtistArchiveOriginTypes.sol";
import {
    StreamArtistCurrentAuthorityTypes as C
} from "../../interfaces/stream/artist/StreamArtistCurrentAuthorityTypes.sol";
import {
    IStreamArtistArchiveOriginInventory as OriginInventory
} from "../../interfaces/stream/preservation/IStreamArtistArchiveOriginInventory.sol";
import {
    IStreamCurrentAuthorityInventory as Inventory
} from "../../interfaces/stream/preservation/IStreamCurrentAuthorityInventory.sol";
import {
    IStreamArtistCurrentAuthorityResolver as Resolver
} from "../../interfaces/stream/preservation/IStreamArtistCurrentAuthorityResolver.sol";
import {
    StreamPreservationInventoryIO as IO
} from "../preservation/StreamPreservationInventoryIO.sol";
import { IERC165 } from "../../vendor/openzeppelin/IERC165.sol";

/// @notice Authenticates the original immutable inventory anchor, not current Artist selection.
/// @dev Only two closed commitment grammars: original raw Dependencies, or the actual current-
/// authority inventory's complete profile/Dependencies/origin/authority commitment. An invalid
/// authority branch cannot fall back. No currentSelection, current evidence, or historical writes.
library StreamFinalityViewInventoryAnchorV1 {
    error InvalidViewInventoryAnchor(address target);

    function matches(Native.Config memory original, S.Dependencies memory d)
        public
        view
        returns (bool)
    {
        // Exact old branch and error order: callers still validate chain, canonical bytes and
        // the original full role mapping. No additional external query on a matching raw hash.
        if (keccak256(abi.encode(d)) == original.inventoryDependencyHash) return true;
        address inv = original.targets[18];
        IO.pin(inv, original.codeHashes[18]);
        if (
            IO.word(inv, abi.encodeCall(OriginInventory.originProfile, ()), original.readGas)
                != D.INVENTORY_PROFILE
        ) {
            revert InvalidViewInventoryAnchor(inv);
        }
        bytes memory raw =
            IO.fixedRead(inv, abi.encodeCall(Inventory.originalAnchor, ()), 1344, original.readGas);
        IO.canonical(inv, raw, abi.encode(d));
        raw = IO.fixedRead(
            inv, abi.encodeCall(OriginInventory.originDependencies, ()), 128, original.readGas
        );
        O.Dependencies memory origin = abi.decode(raw, (O.Dependencies));
        IO.canonical(inv, raw, abi.encode(origin));
        raw = IO.fixedRead(
            inv, abi.encodeCall(Inventory.authorityDependencies, ()), 96, original.readGas
        );
        D.Dependencies memory authority = abi.decode(raw, (D.Dependencies));
        IO.canonical(inv, raw, abi.encode(authority));
        if (
            origin.profile != O.PROFILE || origin.originGas < 50000
                || origin.originGas > type(uint64).max || authority.resolverGas < 50000
                || authority.resolverGas > type(uint64).max
                || D.dependencyHash(D.INVENTORY_PROFILE, d, origin, authority)
                    != original.inventoryDependencyHash
                || IO.word(inv, abi.encodeWithSignature("dependencyHash()"), original.readGas)
                    != original.inventoryDependencyHash
        ) {
            revert InvalidViewInventoryAnchor(inv);
        }
        // The original Origin worker exposes no ERC165/profile getter: its actual capability is
        // this immutable O.PROFILE + fixed runtime + finite typed read budget, as in its producer.
        IO.pin(origin.worker, origin.workerCodeHash);
        IO.pin(authority.resolver, authority.resolverCodeHash);
        address resolver = authority.resolver;
        if (
            IO.word(
                        resolver,
                        abi.encodeCall(IERC165.supportsInterface, (bytes4(0x01ffc9a7))),
                        original.readGas
                    ) != bytes32(uint256(1))
                || IO.word(
                        resolver,
                        abi.encodeCall(IERC165.supportsInterface, (type(Resolver).interfaceId)),
                        original.readGas
                    ) != bytes32(uint256(1))
                || IO.word(
                        resolver,
                        abi.encodeCall(IERC165.supportsInterface, (bytes4(0xffffffff))),
                        original.readGas
                    ) != 0
                || IO.word(
                        resolver,
                        abi.encodeCall(Resolver.currentAuthorityProfile, ()),
                        original.readGas
                    ) != C.PROFILE
        ) {
            revert InvalidViewInventoryAnchor(resolver);
        }
        raw = IO.fixedRead(resolver, abi.encodeCall(Resolver.anchors, ()), 416, original.readGas);
        C.Anchors memory anchors = abi.decode(raw, (C.Anchors));
        IO.canonical(resolver, raw, abi.encode(anchors));
        if (
            anchors.chainId != original.chainId || original.chainId != block.chainid
                || anchors.readGas < 50000 || anchors.readGas > type(uint64).max
                || anchors.finalityRegistry != original.targets[12]
        ) revert InvalidViewInventoryAnchor(resolver);
        address[5] memory targets = [
            original.targets[0],
            original.targets[1],
            original.targets[2],
            original.targets[11],
            address(this)
        ];
        bytes32[5] memory hashes = [
            original.codeHashes[0],
            original.codeHashes[1],
            original.codeHashes[2],
            original.codeHashes[11],
            address(this).codehash
        ];
        for (uint256 i; i < 5; ++i) {
            if (anchors.targets[i] != targets[i] || anchors.codeHashes[i] != hashes[i]) {
                revert InvalidViewInventoryAnchor(resolver);
            }
            IO.pin(targets[i], hashes[i]);
        }
        return true;
    }
}
