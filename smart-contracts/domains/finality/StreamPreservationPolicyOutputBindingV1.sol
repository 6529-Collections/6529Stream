// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamPreservationPolicyOutputTypesV1 as P
} from "../../interfaces/stream/finality/StreamPreservationPolicyOutputTypesV1.sol";
import {
    IStreamStaticSelectionCheckpoint as S
} from "../../interfaces/stream/finality/IStreamStaticSelectionCheckpoint.sol";

/// @notice Strict identity join for an independently admitted preservation producer.
/// @dev This validates identity only. Every consumer must also require the separately governed
/// preservation source/read admission for each original selected version before observing output.
library StreamPreservationPolicyOutputBindingV1 {
    bytes32 internal constant DOMAIN = keccak256("6529STREAM_PRESERVATION_OUTPUT_BINDING_V1");

    function current(
        address producer,
        bytes32 expectedProfile,
        address core,
        address router,
        uint256 cap
    ) internal view returns (P.Binding memory b) {
        if (expectedProfile == 0 || core.code.length == 0 || router.code.length == 0) {
            revert P.InvalidPreservationBinding();
        }
        b.producer = producer;
        b.producerCodeHash = producer.codehash;
        b.profile = abi.decode(
            _read(producer, abi.encodeWithSignature("preservationProfile()"), 32, cap), (bytes32)
        );
        if (b.profile != expectedProfile) revert P.InvalidPreservationBinding();
        bytes memory raw =
            _read(producer, abi.encodeWithSignature("preservationBinding()"), 192, cap);
        (
            b.core,
            b.metadataRouter,
            b.liveRenderer,
            b.liveRendererCodeHash,
            b.attribution,
            b.attributionCodeHash
        ) = abi.decode(raw, (address, address, address, bytes32, address, bytes32));
        if (
            keccak256(raw)
                    != keccak256(
                        abi.encode(
                            b.core,
                            b.metadataRouter,
                            b.liveRenderer,
                            b.liveRendererCodeHash,
                            b.attribution,
                            b.attributionCodeHash
                        )
                    ) || b.core != core || b.metadataRouter != router
        ) {
            revert P.InvalidPreservationBinding();
        }
        _pin(b.liveRenderer, b.liveRendererCodeHash);
        _pin(b.attribution, b.attributionCodeHash);
    }

    function requireCurrent(P.Binding memory expected, S.TokenSelection memory row, uint256 cap)
        internal
        view
    {
        _pin(expected.producer, expected.producerCodeHash);
        P.Binding memory observed = current(
            expected.producer, expected.profile, expected.core, expected.metadataRouter, cap
        );
        if (
            hash(observed) != hash(expected) || row.selection.renderer != expected.liveRenderer
                || row.selection.rendererCodeHash != expected.liveRendererCodeHash
                || row.sources[0] != expected.core || row.sources[1] != expected.metadataRouter
        ) {
            revert P.InvalidPreservationBinding();
        }
        _pin(row.sources[0], row.sourceCodeHashes[0]);
        _pin(row.sources[1], row.sourceCodeHashes[1]);
    }

    function hash(P.Binding memory b) internal pure returns (bytes32) {
        return keccak256(abi.encode(DOMAIN, b));
    }

    function _pin(address target, bytes32 codeHash) private view {
        if (target.code.length == 0 || codeHash == 0 || target.codehash != codeHash) {
            revert P.PreservationDependencyChanged(target);
        }
    }

    function _read(address target, bytes memory input, uint256 length, uint256 cap)
        private
        view
        returns (bytes memory output)
    {
        // Warm the target before measuring parent headroom. Never clamp a dependency budget.
        if (target.code.length == 0 || cap == 0) {
            revert P.PreservationReadFailed(target, bytes4(input));
        }
        if (cap > type(uint256).max / 2) {
            revert P.PreservationParentGas(gasleft(), type(uint256).max);
        }
        uint256 required = cap + cap / 63 + 100000;
        uint256 available = gasleft();
        if (available <= required) revert P.PreservationParentGas(available, required);
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(input, 32), mload(input), 0, 0)
            size := returndatasize()
        }
        if (!ok || size != length) revert P.PreservationReadFailed(target, bytes4(input));
        output = new bytes(length);
        assembly ("memory-safe") { returndatacopy(add(output, 32), 0, length) }
    }
}
