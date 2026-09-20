// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamMintSaleAllowlist.sol";
import "./StreamImmediateSaleReveal.sol";
import "../../interfaces/stream/mint/IStreamUniversalAllowlistPriceSale.sol";

/// @notice Fixed profile codec and same-leaf price proof. No signing or settlement authority.
library StreamUniversalAllowlistPrice {
    bytes32 internal constant PROFILE = keccak256("6529STREAM_UNIVERSAL_ALLOWLIST_EXECUTION_V1");
    function isProfile(bytes calldata data) internal pure returns (bool result) {
        bytes32 tag;
        if (data.length < 32) return false;
        assembly ("memory-safe") { tag := calldataload(data.offset) }
        return tag == PROFILE;
    }
    function encode(IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory e, uint256 amount, bytes memory resolverData) public pure returns (bytes memory) {
        return abi.encode(PROFILE, e, amount, resolverData);
    }
    function decode(bytes calldata data) public pure returns (IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData memory e, uint256 amount, bytes memory resolverData) {
        bytes32 tag;
        (tag,e,amount,resolverData) = abi.decode(data,(bytes32,IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData,uint256,bytes));
        if (tag != PROFILE || keccak256(data) != keccak256(abi.encode(tag,e,amount,resolverData))) revert IStreamUniversalAllowlistPriceSale.InvalidUniversalPriceProfile();
    }
    function price(address manager, IStreamUniversalFixedPriceSaleAdapter.SaleConfig memory config, IStreamUniversalAllowlistPriceSale.AllowlistPricePolicy memory policy, IStreamUniversalFixedPriceSaleAdapter.SaleAuthorization memory a, bytes memory resolverData) public view returns (uint256 amount) {
        if (policy.priceCounterId == 0) revert IStreamUniversalAllowlistPriceSale.InvalidUniversalPriceProfile();
        (bool overridden,uint256 value) = StreamMintSaleAllowlist.price(manager,config.collectionId,config.phaseId,a.payer,a.recipient,resolverData,policy.priceCounterId);
        amount = overridden ? value : config.price;
        if (amount == 0 && !policy.allowFree) revert IStreamUniversalAllowlistPriceSale.SalePriceOverrideZeroUndeclared(a.saleId);
    }
    function quote(address core, uint256 collectionId) public view returns (IStreamImmediateSaleReveal.RevealQuote memory q) {
        q = StreamImmediateSaleReveal.quote(core,collectionId);
    }
}
