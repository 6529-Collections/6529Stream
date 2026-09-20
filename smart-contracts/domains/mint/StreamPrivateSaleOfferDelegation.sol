// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamPrivateSaleSupport.sol";
import { StreamNativeAuctionDelegation as D } from "../auctions/StreamNativeAuctionDelegation.sol";

/// @notice Retained secondary-offer declaration under the original consignment lifecycle.
/// @dev Runs only in the actual private-sale host context, including after custody and delivery
/// callbacks. It grants neither buyer execution/payment authority nor the owner's custody grant.
library StreamPrivateSaleOfferDelegation {
    function requireRetained(
        StreamPrivateSaleSupport.Context memory context,
        D.Configuration memory c,
        bytes32 saleId,
        uint256 cap
    ) public view {
        if (
            c.core != context.core || c.moduleRegistry != context.registry
                || c.moduleRegistryCodeHash != context.registryCodeHash
        ) revert D.DelegationConfigurationInvalid();
        D.validateConfiguration(c);
        (uint64 createdAt, uint64 revision) = _lifecycle(saleId);
        StreamPrivateSaleSupport.requireAdmission(context, createdAt, revision);
        _manifest(c, cap);
    }

    function _lifecycle(bytes32 saleId) private view returns (uint64, uint64) {
        bytes memory data = abi.encodeCall(P.custodySaleLifecycle, (saleId));
        uint256[2] memory words;
        bool ok;
        uint256 size;
        address host = address(this);
        // Exact self read from the same guarded carrier that supplied the original sale ID.
        assembly ("memory-safe") {
            ok := staticcall(gas(), host, add(data, 32), mload(data), words, 64)
            size := returndatasize()
        }
        // Zero is the original requireAdmission new-registration sentinel, never retained proof.
        if (
            !ok || size != 64 || words[0] == 0 || words[0] > type(uint64).max || words[1] == 0
                || words[1] > type(uint64).max
        ) {
            revert P.PrivateSaleModuleNotAdmitted();
        }
        return (uint64(words[0]), uint64(words[1]));
    }

    function _manifest(D.Configuration memory c, uint256 cap) private view {
        bytes memory input = abi.encodeCall(IStreamModuleRegistry.moduleRecord, (address(this)));
        uint256[14] memory words;
        bool ok;
        uint256 size;
        address target = c.moduleRegistry;
        uint256 available = gasleft();
        if (
            cap == 0 || cap > available
                || available - cap < cap / 63 + (cap % 63 == 0 ? 0 : 1) + 30000
        ) {
            revert D.DelegationReadGas(available, cap);
        }
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(input, 32), mload(input), words, 448)
            size := returndatasize()
        }
        if (!ok) revert D.DelegationReadFailed(target);
        if (
            size < 448 || words[0] != 32 || words[1] > 3 || words[5] > type(uint32).max
                || words[9] != 384 || words[10] > type(uint64).max || words[11] > type(uint64).max
                || words[12] > type(uint64).max || words[13] > size - 448
                || size - 448 != ((words[13] + 31) / 32) * 32
        ) {
            revert D.DelegationReadMalformed(target, size);
        }
        if (
            (words[1] != 1 && words[1] != 2) || bytes32(words[6]) != address(this).codehash
                || words[7] == 0 || bytes32(words[8]) != keccak256(D.manifestBytes(c))
                || words[10] == 0 || words[10] > block.timestamp || words[11] < words[10]
                || words[11] > block.timestamp || words[12] == 0
        ) {
            revert D.DelegationManifestMismatch();
        }
    }
}
