// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/revenue/StreamDirectPrimarySaleTypes.sol";

/// @notice Domain-separated identities for original DIRECT receipts, without universal aliases.
library StreamDirectPrimarySaleHash {
    bytes32 private constant KEY_DOMAIN = keccak256("6529STREAM_DIRECT_PRIMARY_SALE_KEY_V1");
    bytes32 private constant RECEIPT_DOMAIN =
        keccak256("6529STREAM_DIRECT_PRIMARY_SALE_RECEIPT_V1");

    function settlementKey(
        StreamDirectPrimarySaleTypes.Bindings memory bindings,
        address adapter,
        bytes32 authorizationId
    ) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                KEY_DOMAIN,
                bindings.deploymentChainId,
                bindings.core,
                adapter,
                bindings.productKind,
                authorizationId
            )
        );
    }

    function receiptHash(
        StreamDirectPrimarySaleTypes.Bindings memory bindings,
        address adapter,
        bytes32 authorizationId,
        StreamDirectPrimarySaleTypes.Receipt memory receipt
    ) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                RECEIPT_DOMAIN,
                bindings.deploymentChainId,
                bindings.core,
                adapter,
                bindings.productKind,
                authorizationId,
                receipt
            )
        );
    }
}
