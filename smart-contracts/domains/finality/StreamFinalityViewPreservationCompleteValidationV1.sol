// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamFinalityViewInventoryAnchorV1 as Anchor
} from "./StreamFinalityViewInventoryAnchorV1.sol";
import {
    StreamFinalityNativeProviderReads as Native
} from "./StreamFinalityNativeProviderReads.sol";
import {
    StreamFinalityViewPreservationBindingTypesV1 as Basic
} from "../../interfaces/stream/finality/StreamFinalityViewPreservationBindingTypesV1.sol";
import {
    StreamFinalityViewPreservationCompleteBindingTypesV1 as Complete
} from "../../interfaces/stream/finality/StreamFinalityViewPreservationCompleteBindingTypesV1.sol";
import {
    IStreamViewPreservationFinalitySourcesV1 as Sources
} from "../../interfaces/stream/finality/IStreamViewPreservationFinalitySourcesV1.sol";
import {
    StreamRenderCriticalSourceTypes as Inventory
} from "../../interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamFinalityViewPreservationSourceSelectionV1 as Selection
} from "./StreamFinalityViewPreservationSourceSelectionV1.sol";
import { StreamFinalityBoundedReads as Reads } from "./StreamFinalityBoundedReads.sol";
import {
    StreamFinalityViewPreservationValidationV1 as BasicValidation
} from "./StreamFinalityViewPreservationValidationV1.sol";

/// @notice Derives complete VIEW source expectations from the authenticated original provider.
/// @dev No caller-supplied inventory roster, current publication or root is an admission fact.
library StreamFinalityViewPreservationCompleteValidationV1 {
    function read(
        Native.Config memory original,
        Basic.Receipt memory basic,
        Sources.Selection memory selected
    ) public view returns (Sources.Receipt memory r) {
        r.selection = selected;
        (r.referenceDependenciesHash, r.inventoryDependenciesHash, r.bundleDependenciesHash) =
            Selection.requireBindings(
                selected, _expected(original, basic, selected), original.readGas
            );
    }

    /// @dev Reference read budgets are governed. Validate today's complete fixed identities and
    /// reciprocity without equating today's dependency hashes with the initial admission hashes.
    /// This does not read current snapshots, roots, inventories, archive coverage or finality.
    function requireBindings(
        Native.Config memory original,
        Basic.Receipt memory basic,
        Sources.Selection memory selected
    ) public view {
        Selection.requireBindings(selected, _expected(original, basic, selected), original.readGas);
    }

    function _expected(
        Native.Config memory original,
        Basic.Receipt memory basic,
        Sources.Selection memory selected
    ) private view returns (Selection.Expected memory e) {
        BasicValidation.pin(original.targets[18], original.codeHashes[18]);
        bytes memory raw = Reads.read(
            original.targets[18], abi.encodeWithSignature("dependencies()"), 1344, original.readGas
        );
        Inventory.Dependencies memory d = abi.decode(raw, (Inventory.Dependencies));
        if (
            original.chainId != block.chainid || d.chainId != original.chainId
                || keccak256(raw) != keccak256(abi.encode(d)) || !Anchor.matches(original, d)
                || d.artistTargets[0] != original.targets[11]
                || d.artistCodeHashes[0] != original.codeHashes[11]
        ) revert Complete.InvalidViewPreservationCompleteBinding();
        // This is the exact original NativeProviderReads inventory-to-provider roster.
        uint256[12] memory index = [uint256(0), 1, 4, 5, 2, 8, 9, 15, 16, 17, 20, 21];
        for (uint256 i; i < index.length; ++i) {
            if (
                d.targets[i] != original.targets[index[i]]
                    || d.codeHashes[i] != original.codeHashes[index[i]]
            ) revert Complete.InvalidViewPreservationCompleteBinding();
        }
        e.targets = d.targets;
        e.codeHashes = d.codeHashes;
        e.artistTargets = d.artistTargets;
        e.artistCodeHashes = d.artistCodeHashes;
        e.artistContentOwner = d.artistContentOwner;
        e.artistContentOwnerCodeHash = d.artistContentOwnerCodeHash;
        e.chainId = d.chainId;
        e.targets[5] = basic.configuration.snapshotHost;
        e.codeHashes[5] = basic.configuration.snapshotCodeHash;
        e.targets[6] = selected.referencePublication;
        e.codeHashes[6] = selected.referencePublicationCodeHash;
        e.targets[10] = basic.dependencies.targets[8];
        e.codeHashes[10] = basic.dependencies.codeHashes[8];
    }
}
