// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    IStreamCollectionAttestations as A
} from "../../interfaces/stream/metadata/IStreamCollectionAttestations.sol";
import "../../interfaces/stream/metadata/IStreamSchemaRegistry.sol";
import "../../interfaces/stream/core/IStreamCoreCollectionView.sol";
import "../../interfaces/stream/core/IStreamCoreIdentity.sol";

/// @notice Bounded immutable-definition and subject reads; no governance or interpretation gate.
library StreamIndependentReads {
    bytes32 private constant COLLECTION =
        0x3a882a22dad9915c9193738f63216234155080ed4c4fc9bfae446e90f1df6e16;
    bytes32 private constant TOKEN =
        0x1e576f27850d12bc1ec9255ca277dbecfbc84fb3a9a34c474640dfca89811d7e;
    bytes32 private constant MEDIA =
        0x030f2701e9035fcb711b3acc44ec0bf14b4f4e344e231cdaadce7d14e590994b;

    function subject(address core, A.Subject calldata s) internal view returns (bytes32) {
        if (s.kind == A.SubjectKind.COLLECTION) {
            if (s.tokenId != 0 || s.objectId != 0) revert A.InvalidIndependentSubject();
            return keccak256(abi.encode(COLLECTION, block.chainid, core, s.collectionId));
        }
        if (s.collectionId == 0) revert A.InvalidIndependentSubject();
        if (s.kind == A.SubjectKind.TOKEN) {
            if (s.tokenId == 0 || s.objectId != 0) revert A.InvalidIndependentSubject();
            return keccak256(abi.encode(TOKEN, block.chainid, core, s.tokenId));
        }
        if (s.tokenId != 0 || s.objectId == 0) revert A.InvalidIndependentSubject();
        return keccak256(abi.encode(MEDIA, block.chainid, core, s.collectionId, s.objectId));
    }

    function requireSubject(address core, bytes32 codeHash, A.Subject calldata s, uint256 cap)
        public
        view
    {
        if (s.collectionId == 0) return; // Only the shaped deployment COLLECTION subject reaches here.
        requireCode(core, codeHash);
        if (!abi.decode(
                read(
                    core,
                    abi.encodeCall(IStreamCoreCollectionView.collectionExists, (s.collectionId)),
                    32,
                    cap
                ),
                (bool)
            )) {
            revert A.InvalidIndependentSubject();
        }
        if (s.kind == A.SubjectKind.TOKEN) {
            (bool exists, uint256 collectionId,, bool burned) = abi.decode(
                read(
                    core,
                    abi.encodeCall(IStreamCoreIdentity.tokenCollectionIdentity, (s.tokenId)),
                    128,
                    cap
                ),
                (bool, uint256, uint256, bool)
            );
            uint8 lifecycle = abi.decode(
                read(
                    core, abi.encodeCall(IStreamCoreIdentity.tokenLifecycle, (s.tokenId)), 32, cap
                ),
                (uint8)
            );
            if (
                !exists || collectionId != s.collectionId || (lifecycle != 2 && lifecycle != 3)
                    || burned != (lifecycle == 3)
            ) revert A.InvalidIndependentSubject();
        }
    }

    /// @dev Immutable definitions remain valid evidence at DEPRECATED/ARCHIVED status.
    function definition(
        address registry,
        bytes32 id,
        IStreamSchemaRegistry.DocumentKind kind,
        uint256 cap
    ) public view returns (bytes32) {
        bytes memory input = abi.encodeCall(IStreamSchemaRegistry.document, (id));
        bytes memory output = bounded(registry, input, 8192, cap);
        IStreamSchemaRegistry.DocumentView memory d =
            abi.decode(output, (IStreamSchemaRegistry.DocumentView));
        if (!d.exists || d.specification.kind != kind || d.specification.contentHash == 0) {
            revert A.IndependentDefinitionUnavailable(id);
        }
        return d.specification.contentHash;
    }

    function requireCode(address target, bytes32 hash) internal view {
        if (target.code.length == 0 || target.codehash != hash) {
            revert A.IndependentDependencyChanged(target);
        }
    }

    function read(address target, bytes memory input, uint256 size, uint256 cap)
        private
        view
        returns (bytes memory output)
    {
        output = bounded(target, input, size, cap);
        if (output.length != size) revert A.IndependentReadFailed(target);
    }

    function bounded(address target, bytes memory input, uint256 maximum, uint256 cap)
        private
        view
        returns (bytes memory output)
    {
        output = new bytes(maximum);
        uint256 available = gasleft();
        if (
            cap > type(uint256).max / 64 || available <= 10000
                || (available - 10000) / 64 * 63 < cap
        ) {
            revert A.IndependentParentGas(available, cap);
        }
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(input, 32), mload(input), add(output, 32), maximum)
            size := returndatasize()
        }
        if (!ok || size > maximum) revert A.IndependentReadFailed(target);
        assembly ("memory-safe") { mstore(output, size) }
    }
}
