// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamNativePrimaryOfferTypes.sol";
import "../../standards/IERC5267.sol";

/// @notice Native atomic primary OFFER_SALE, with the permanent original Sales signing domain.
interface IStreamNativePrimaryOfferSale is IERC5267 {
    function registerPrimaryOffer(
        StreamNativePrimaryOfferTypes.Configuration calldata config,
        bytes32[] calldata proof
    ) external returns (bytes32 saleId);
    function primaryOfferConfiguration(bytes32 saleId)
        external
        view
        returns (StreamNativePrimaryOfferTypes.Configuration memory);
    function primaryOfferConfigurationHash(
        StreamNativePrimaryOfferTypes.Configuration calldata config
    ) external view returns (bytes32);
    function acceptPrimaryOffer(StreamNativePrimaryOfferTypes.Acceptance calldata acceptance)
        external
        payable
        returns (StreamNativeCuratedSaleTypes.ExecutionRecord memory);
    function primaryOfferAuthorizationBinding(bytes32 saleId)
        external
        view
        returns (uint256, bytes32, address, uint8, bytes32);
    function revokeAuthorization(
        StreamPrivateSaleTypes.SaleAuthorization calldata authorization,
        IStreamPrivateSaleAdapter.Signature calldata proof
    ) external;
    function digestConsumed(bytes32 digest) external view returns (bool);
    function digestRevoked(bytes32 digest) external view returns (bool);
}
