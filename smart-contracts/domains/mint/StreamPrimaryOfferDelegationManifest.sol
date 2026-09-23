// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamNativeAuctionDelegation as D } from "../auctions/StreamNativeAuctionDelegation.sol";
import "../revenue/StreamPreparedNativeSettlementAdmission.sol";
import "../revenue/StreamSettlementAdmission.sol";

/// @notice Original primary-offer lifecycle and compact live NFTDelegation declaration.
/// @dev Explicit house identity works from the carrier, Manager or selected gate. These typed
/// retained checks never admit new sales or bids; their original ACTIVE-only helper is unchanged.
library StreamPrimaryOfferDelegationManifest {
    function requireNative(D.Configuration memory c, address house, bytes32 saleId, uint256 cap)
        public
        view
    {
        D.validateConfiguration(c);
        StreamPreparedNativeSettlementAdmission.requireAdmission(c.moduleRegistry, house, saleId);
        _requireManifest(c, house, cap);
    }

    function requireERC20(D.Configuration memory c, address house, bytes32 saleId, uint256 cap)
        public
        view
    {
        D.validateConfiguration(c);
        StreamSettlementAdmission.requireStoredAdmission(c.moduleRegistry, house, saleId);
        _requireManifest(c, house, cap);
    }

    function _requireManifest(D.Configuration memory c, address house, uint256 cap) private view {
        bytes memory input = abi.encodeCall(IStreamModuleRegistry.moduleRecord, (house));
        uint256[14] memory words;
        bool ok;
        uint256 size;
        address target = c.moduleRegistry;
        uint256 available = gasleft();
        if (
            cap == 0 || cap > available
                || available - cap < cap / 63 + (cap % 63 == 0 ? 0 : 1) + 30000
        ) revert D.DelegationReadGas(available, cap);
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
        ) revert D.DelegationReadMalformed(target, size);
        bytes32 manifest = keccak256(
            abi.encode(
                keccak256("6529STREAM_NATIVE_AUCTION_NFTDELEGATION_MANIFEST_V1"),
                c.chainId,
                house,
                c.baseManifestHash,
                c.core,
                c.delegateRegistry,
                c.delegateRegistryCodeHash,
                c.delegationUsecase
            )
        );
        if (
            (words[1] != 1 && words[1] != 2) || bytes32(words[6]) != house.codehash || words[7] == 0
                || bytes32(words[8]) != manifest || words[10] == 0 || words[10] > block.timestamp
                || words[11] < words[10] || words[11] > block.timestamp || words[12] == 0
        ) revert D.DelegationManifestMismatch();
    }
}
