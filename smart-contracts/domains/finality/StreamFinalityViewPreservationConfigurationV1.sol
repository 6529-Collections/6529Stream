// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamFinalityViewInventoryAnchorV1 as Anchor
} from "./StreamFinalityViewInventoryAnchorV1.sol";
import "../../interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import "../../interfaces/stream/finality/StreamFinalityEvidenceTypes.sol";

import {
    StreamFinalityNativeProviderReads as Native
} from "./StreamFinalityNativeProviderReads.sol";
import {
    StreamFinalityViewPreservationSourceSelectionV1 as Selection
} from "./StreamFinalityViewPreservationSourceSelectionV1.sol";
import {
    IStreamViewPreservationFinalitySourcesV1 as Sources
} from "../../interfaces/stream/finality/IStreamViewPreservationFinalitySourcesV1.sol";
import {
    IStreamViewPreservationEvidenceBindingV1 as SnapshotBinding
} from "../../interfaces/stream/finality/IStreamViewPreservationEvidenceBindingV1.sol";
import {
    IStreamViewPolicySourceBindingV2 as FactoryBinding
} from "../../interfaces/stream/finality/IStreamViewPolicySourceBindingV2.sol";
import {
    IStreamFinalityProfileSources as Profiles
} from "../../interfaces/stream/finality/IStreamFinalityProfileSources.sol";
import {
    StreamRenderCriticalSourceTypes as Inventory
} from "../../interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamViewPreservationSnapshotTypesV1 as Snapshot
} from "../../interfaces/stream/metadata/StreamViewPreservationSnapshotTypesV1.sol";
import {
    StreamFinalityViewPreservationSnapshotReadsV1 as Snapshots
} from "./StreamFinalityViewPreservationSnapshotReadsV1.sol";
import {
    StreamPreservationInventoryIO as IO
} from "../preservation/StreamPreservationInventoryIO.sol";
import { StreamMetadataSubjects } from "../metadata/StreamMetadataSubjects.sol";

/// @notice Closed, same-provider VIEW selection. This proves identities, never current evidence.
/// @dev Only the host's original constructor-owned Config enters this fixed worker. Operative
/// complete-source selection repeats its governed reciprocity checks; initial gas hashes remain
/// historical receipt fields and are not substituted for current dependency validation.
library StreamFinalityViewPreservationConfigurationV1 {
    bytes32 internal constant PROFILE = keccak256("6529STREAM_VIEW_PRESERVATION_FINALITY_V1");

    struct Context {
        Native.Config effective;
        Inventory.Dependencies inventory;
        Sources.Receipt receipt;
        Snapshots.Dependencies snapshots;
    }
    error InvalidViewFinalityConfiguration();

    function resolve(Native.Config memory original) public view returns (Context memory x) {
        if (
            original.chainId != block.chainid || original.readGas < 50000
                || original.componentSourceGas < original.readGas
                || original.sourceGas
                    <= original.componentSourceGas + original.componentSourceGas / 63 + 100000
        ) {
            revert InvalidViewFinalityConfiguration();
        }
        for (uint256 i; i < 22; ++i) {
            IO.pin(original.targets[i], original.codeHashes[i]);
        }
        bytes memory raw = IO.fixedRead(
            original.targets[18], abi.encodeWithSignature("dependencies()"), 1344, original.readGas
        );
        Inventory.Dependencies memory prior = abi.decode(raw, (Inventory.Dependencies));
        IO.canonical(original.targets[18], raw, abi.encode(prior));
        if (
            !Anchor.matches(original, prior) || prior.chainId != original.chainId
                || prior.artistTargets[0] != original.targets[11]
                || prior.artistCodeHashes[0] != original.codeHashes[11]
        ) {
            revert InvalidViewFinalityConfiguration();
        }
        uint256[12] memory roles = [uint256(0), 1, 4, 5, 2, 8, 9, 15, 16, 17, 20, 21];
        for (uint256 i; i < 12; ++i) {
            if (
                prior.targets[i] != original.targets[roles[i]]
                    || prior.codeHashes[i] != original.codeHashes[roles[i]]
            ) {
                revert InvalidViewFinalityConfiguration();
            }
        }
        raw = IO.fixedRead(
            address(this), abi.encodeCall(Sources.viewFinalitySources, ()), 192, original.sourceGas
        );
        Sources.Selection memory selected = abi.decode(raw, (Sources.Selection));
        IO.canonical(address(this), raw, abi.encode(selected));
        raw = IO.fixedRead(
            address(this),
            abi.encodeCall(Sources.viewFinalitySourcesReceipt, ()),
            416,
            original.readGas
        );
        x.receipt = abi.decode(raw, (Sources.Receipt));
        IO.canonical(address(this), raw, abi.encode(x.receipt));
        if (
            keccak256(abi.encode(selected)) != keccak256(abi.encode(x.receipt.selection))
                || x.receipt.basicBindingRecordHash == 0 || x.receipt.actionId == 0
                || x.receipt.boundAt == 0 || x.receipt.boundAt > block.timestamp
                || x.receipt.referenceDependenciesHash == 0
                || x.receipt.inventoryDependenciesHash == 0 || x.receipt.bundleDependenciesHash == 0
                || x.receipt.recordHash
                    != keccak256(
                        abi.encode(
                            keccak256("6529STREAM_FINALITY_VIEW_PRESERVATION_COMPLETE_RECEIPT_V1"),
                            original.chainId,
                            address(this),
                            selected,
                            x.receipt.referenceDependenciesHash,
                            x.receipt.inventoryDependenciesHash,
                            x.receipt.bundleDependenciesHash,
                            x.receipt.basicBindingRecordHash,
                            x.receipt.actionId,
                            x.receipt.boundAt
                        )
                    )
        ) {
            revert InvalidViewFinalityConfiguration();
        }
        x.effective = abi.decode(abi.encode(original), (Native.Config));
        x.effective.targets[8] = _address(
            abi.encodeCall(SnapshotBinding.viewPreservationSnapshotHost, ()), original.sourceGas
        );
        x.effective.codeHashes[8] = _word(
            abi.encodeCall(SnapshotBinding.viewPreservationSnapshotCodeHash, ()), original.sourceGas
        );
        uint256 validationGas = uint256(
            _word(
                abi.encodeCall(SnapshotBinding.viewPreservationSnapshotValidationGas, ()),
                original.sourceGas
            )
        );
        if (validationGas < original.readGas || validationGas > 16777216) {
            revert InvalidViewFinalityConfiguration();
        }
        x.effective.targets[9] = selected.referencePublication;
        x.effective.codeHashes[9] = selected.referencePublicationCodeHash;
        x.effective.targets[18] = selected.renderCriticalInventory;
        x.effective.codeHashes[18] = selected.renderCriticalInventoryCodeHash;
        x.effective.targets[19] = selected.bundleArchiveCoverage;
        x.effective.codeHashes[19] = selected.bundleArchiveCoverageCodeHash;
        x.effective.targets[10] =
            _address(abi.encodeCall(FactoryBinding.viewPolicySourceFactoryV2, ()), original.readGas);
        x.effective.codeHashes[10] = _word(
            abi.encodeCall(FactoryBinding.viewPolicySourceFactoryV2CodeHash, ()), original.readGas
        );
        IO.pin(x.effective.targets[10], x.effective.codeHashes[10]);
        Selection.Expected memory expected;
        expected.targets = prior.targets;
        expected.codeHashes = prior.codeHashes;
        expected.targets[5] = x.effective.targets[8];
        expected.codeHashes[5] = x.effective.codeHashes[8];
        expected.targets[6] = selected.referencePublication;
        expected.codeHashes[6] = selected.referencePublicationCodeHash;
        expected.artistTargets = prior.artistTargets;
        expected.artistCodeHashes = prior.artistCodeHashes;
        expected.artistContentOwner = prior.artistContentOwner;
        expected.artistContentOwnerCodeHash = prior.artistContentOwnerCodeHash;
        expected.chainId = original.chainId;
        (, bytes32 inventoryHash,) = Selection.requireBindings(selected, expected, original.readGas);
        raw = IO.fixedRead(
            selected.renderCriticalInventory,
            abi.encodeWithSignature("dependencies()"),
            1344,
            original.readGas
        );
        x.inventory = abi.decode(raw, (Inventory.Dependencies));
        IO.canonical(selected.renderCriticalInventory, raw, abi.encode(x.inventory));
        if (keccak256(raw) != inventoryHash) revert InvalidViewFinalityConfiguration();
        x.effective.inventoryDependencyHash = inventoryHash;
        x.snapshots = Snapshots.Dependencies(
            original.targets[0],
            original.targets[1],
            x.effective.targets[8],
            original.codeHashes[0],
            original.codeHashes[1],
            x.effective.codeHashes[8],
            original.chainId,
            original.readGas,
            validationGas
        );
        _self(original.targets[12], "scopeEvidenceProvider()", original.readGas);
        _self(original.targets[13], "scopeEvidenceProvider()", original.readGas);
        _self(original.targets[14], "evidenceProvider()", original.readGas);
    }

    function catalogue(Native.Config memory c, StreamFinalityScope memory scope)
        public
        view
        returns (Profiles.Sources memory p)
    {
        requireScope(c, scope);
        Context memory x = resolve(c);
        p.scope = scope;
        p.profile = Profiles.Profile(
            PROFILE,
            x.effective.targets[9],
            x.effective.codeHashes[9],
            x.effective.targets[8],
            x.effective.codeHashes[8],
            x.effective.targets[10],
            x.effective.codeHashes[10],
            keccak256(
                abi.encode(
                    PROFILE,
                    c.chainId,
                    address(this),
                    keccak256(abi.encode(c)),
                    x.receipt.recordHash
                )
            )
        );
    }

    function requireScope(Native.Config memory c, StreamFinalityScope memory scope) internal pure {
        if (scope.scopeType != StreamFinalityScopeType.VIEW) {
            revert InvalidViewFinalityConfiguration();
        }
        StreamMetadataSubjects.scopeSubject(c.chainId, c.targets[0], scope);
    }

    function _word(bytes memory input, uint256 cap) private view returns (bytes32) {
        return abi.decode(IO.fixedRead(address(this), input, 32, cap), (bytes32));
    }

    function _address(bytes memory input, uint256 cap) private view returns (address) {
        uint256 word = uint256(_word(input, cap));
        if (word > type(uint160).max || word == 0) revert InvalidViewFinalityConfiguration();
        return address(uint160(word));
    }

    function _self(address host, string memory selector, uint256 cap) private view {
        if (
            abi.decode(IO.fixedRead(host, abi.encodeWithSignature(selector), 32, cap), (uint256))
                != uint256(uint160(address(this)))
        ) {
            revert InvalidViewFinalityConfiguration();
        }
    }
}
