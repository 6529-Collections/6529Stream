// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamNativeCuratedSaleTypes
} from "../../interfaces/stream/mint/StreamNativeCuratedSaleTypes.sol";

/// @notice Existing SSA sale/purchase identities plus distinct immutable configuration hashes.
library StreamNativeCuratedSaleHash {
    function saleId(uint8 kind, uint256 collection, bytes32 phase, uint256 nonce)
        internal
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_SALE_V1"),
                block.chainid,
                address(this),
                kind,
                collection,
                phase,
                nonce
            )
        );
    }

    function purchaseId(bytes32 sale, address buyer, uint256 nonce)
        internal
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_SALE_PURCHASE_V1"),
                block.chainid,
                address(this),
                sale,
                buyer,
                nonce
            )
        );
    }

    function fixedConfig(StreamNativeCuratedSaleTypes.FixedConfiguration memory config)
        internal
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_NATIVE_CURATED_FIXED_CONFIG_V1"),
                block.chainid,
                address(this),
                config
            )
        );
    }

    function privateConfig(StreamNativeCuratedSaleTypes.PrivateConfiguration memory config)
        internal
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_NATIVE_CURATED_PRIVATE_CONFIG_V1"),
                block.chainid,
                address(this),
                config
            )
        );
    }
}
