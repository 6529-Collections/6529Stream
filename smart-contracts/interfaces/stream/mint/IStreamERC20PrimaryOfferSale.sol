// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamERC20PrimaryOfferTypes.sol";
import "../../standards/IERC5267.sol";

/// @notice Original Sales signatures; all token funding enters the separate contract20 verifier.
interface IStreamERC20PrimaryOfferSale is IERC5267 {
    function registerPrimaryOffer(
        StreamERC20PrimaryOfferTypes.Configuration calldata config,
        bytes32[] calldata proof
    ) external returns (bytes32 saleId);
    function primaryOfferConfiguration(bytes32 saleId)
        external
        view
        returns (StreamERC20PrimaryOfferTypes.Configuration memory);
    function primaryOfferConfigurationHash(
        StreamERC20PrimaryOfferTypes.Configuration calldata config
    ) external view returns (bytes32);
    function previewExecution(StreamERC20PrimaryOfferTypes.Acceptance calldata acceptance)
        external
        view
        returns (StreamPrimarySettlementTypes.ERC20SettlementCandidate memory);
    function revokeAuthorization(
        StreamPrivateSaleTypes.SaleAuthorization calldata authorization,
        IStreamPrivateSaleAdapter.Signature calldata proof
    ) external;
    function digestConsumed(bytes32 digest) external view returns (bool);
    function digestRevoked(bytes32 digest) external view returns (bool);
}
