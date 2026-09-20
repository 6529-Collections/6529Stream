// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamBundleArchiveTypes as B
} from "../../interfaces/stream/preservation/StreamBundleArchiveTypes.sol";
import {
    StreamArtistArchiveOriginTypes as O
} from "../../interfaces/stream/preservation/StreamArtistArchiveOriginTypes.sol";
import {
    StreamCurrentAuthorityInventoryTypes as D
} from "../../interfaces/stream/preservation/StreamCurrentAuthorityInventoryTypes.sol";
import {
    StreamRenderCriticalSourceTypes as S
} from "../../interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    IStreamCurrentAuthorityInventory as Inventory
} from "../../interfaces/stream/preservation/IStreamCurrentAuthorityInventory.sol";
import { StreamPreservationInventoryIO as IO } from "./StreamPreservationInventoryIO.sol";
import {
    StreamMultiOriginBundleArchiveReads as Origins
} from "./StreamMultiOriginBundleArchiveReads.sol";
import {
    StreamCurrentAuthorityInventorySelection as Selection
} from "./StreamCurrentAuthorityInventorySelection.sol";

/// @notice Joins the sealed plan's immutable capture with its fixed resolver and fresh selection.
/// @dev Per-item archival proofs and STOP aggregate semantics remain in the original readers.
library StreamCurrentAuthorityBundleArchiveEnvironment {
    function coverageProfile(bytes32 profile) internal pure returns (bytes32) {
        if (profile == D.INVENTORY_PROFILE || profile == D.POLICY_INVENTORY_PROFILE) {
            return keccak256("6529STREAM_CURRENT_AUTHORITY_BUNDLE_IMMUTABLE_STOP_AGGREGATE_V1");
        }
        if (profile == D.SCOPED_INVENTORY_PROFILE || profile == D.SCOPED_POLICY_INVENTORY_PROFILE) {
            return
                keccak256("6529STREAM_CURRENT_AUTHORITY_SCOPED_BUNDLE_IMMUTABLE_STOP_AGGREGATE_V1");
        }
        revert O.InvalidArchiveOrigin();
    }

    function capture(
        B.Dependencies memory b,
        O.Dependencies memory o,
        D.Dependencies memory a,
        bytes32 profile,
        bytes32 id
    ) public view returns (D.Capture memory result) {
        coverageProfile(profile);
        Origins.configuration(b, o, profile);
        address inventory = b.targets[2];
        bytes memory raw =
            IO.fixedRead(inventory, abi.encodeCall(Inventory.originalAnchor, ()), 1344, b.readGas);
        S.Dependencies memory anchor = abi.decode(raw, (S.Dependencies));
        IO.canonical(inventory, raw, abi.encode(anchor));
        bytes memory legacy =
            IO.fixedRead(inventory, abi.encodeWithSignature("dependencies()"), 1344, b.readGas);
        IO.canonical(inventory, legacy, raw);
        uint256[4] memory indexes = [uint256(0), 1, 10, 11];
        uint256[4] memory bundleIndexes = [uint256(0), 1, 3, 4];
        for (uint256 i; i < 4; ++i) {
            if (
                anchor.targets[indexes[i]] != b.targets[bundleIndexes[i]]
                    || anchor.codeHashes[indexes[i]] != b.codeHashes[bundleIndexes[i]]
            ) revert O.InvalidArchiveOrigin();
        }
        if (
            anchor.chainId != b.chainId || anchor.artistTargets[4] != b.targets[5]
                || anchor.artistCodeHashes[4] != b.codeHashes[5] || id == 0
        ) revert O.InvalidArchiveOrigin();
        raw = IO.fixedRead(
            inventory, abi.encodeCall(Inventory.authorityDependencies, ()), 96, b.readGas
        );
        IO.canonical(inventory, raw, abi.encode(a));
        if (
            IO.word(inventory, abi.encodeWithSignature("dependencyHash()"), b.readGas)
                != D.dependencyHash(profile, anchor, o, a)
        ) revert O.InvalidArchiveOrigin();
        raw = IO.fixedRead(
            inventory, abi.encodeCall(Inventory.authoritySelection, (id)), 2176, b.readGas
        );
        result = abi.decode(raw, (D.Capture));
        IO.canonical(inventory, raw, abi.encode(result));
        D.Capture memory fresh = Selection.resolve(Selection.Config(anchor, a));
        if (keccak256(raw) != keccak256(abi.encode(fresh))) revert O.InvalidArchiveOrigin();
    }

    function environment(
        B.Dependencies memory b,
        O.Dependencies memory o,
        D.Dependencies memory a,
        bytes32 profile,
        bytes32 id
    ) public view returns (bytes32) {
        D.Capture memory captured = capture(b, o, a, profile, id);
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_CURRENT_AUTHORITY_BUNDLE_ENVIRONMENT_V1"),
                Origins.environment(b, o, profile, id),
                a,
                captured
            )
        );
    }
}
