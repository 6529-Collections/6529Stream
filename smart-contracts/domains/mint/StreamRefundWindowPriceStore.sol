// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    IStreamNativeAllowlistRefundWindowSale as A
} from "../../interfaces/stream/mint/IStreamNativeAllowlistRefundWindowSale.sol";

/// @notice Immutable sale price policies and captured purchase prices/proofs in host storage.
/// @dev Separate namespace preserves the complete inherited refund book layout. Only the
///      authenticated, reentrancy-guarded consumer's linked workers can reach these mutations.
library StreamRefundWindowPriceStore {
    bytes32 private constant SLOT = keccak256("6529STREAM_REFUND_WINDOW_PRICE_STORE_V1");

    struct PurchasePrice {
        bool captured;
        uint256 chargedPrice;
        bytes32 proofHash;
        bytes resolverData;
    }

    struct State {
        mapping(bytes32 => A.AllowlistPricePolicy) policies;
        mapping(bytes32 => PurchasePrice) purchases;
    }

    function _state() private pure returns (State storage s) {
        bytes32 slot = SLOT;
        assembly ("memory-safe") { s.slot := slot }
    }

    function policy(bytes32 saleId) internal view returns (A.AllowlistPricePolicy memory) {
        return _state().policies[saleId];
    }

    function setPolicy(bytes32 saleId, A.AllowlistPricePolicy memory value) internal {
        State storage s = _state();
        if (saleId == 0 || value.counterId == 0 || s.policies[saleId].counterId != 0) {
            revert A.InvalidAllowlistRefundPolicy();
        }
        s.policies[saleId] = value;
    }

    function capture(bytes32 purchaseId, uint256 amount, bytes memory proofData) internal {
        PurchasePrice storage p = _state().purchases[purchaseId];
        if (purchaseId == 0 || p.captured || proofData.length == 0) {
            revert A.InvalidAllowlistRefundPolicy();
        }
        p.captured = true;
        p.chargedPrice = amount;
        p.proofHash = keccak256(proofData);
        p.resolverData = proofData;
    }

    function facts(bytes32 purchaseId) internal view returns (bool, uint256, bytes32) {
        PurchasePrice storage p = _state().purchases[purchaseId];
        return (p.captured, p.chargedPrice, p.proofHash);
    }

    function resolverData(bytes32 purchaseId) internal view returns (bytes memory) {
        return _state().purchases[purchaseId].resolverData;
    }

    function chargedPrice(bytes32 purchaseId, uint256 ordinaryPrice)
        internal
        view
        returns (uint256)
    {
        PurchasePrice storage p = _state().purchases[purchaseId];
        return p.captured ? p.chargedPrice : ordinaryPrice;
    }
}
