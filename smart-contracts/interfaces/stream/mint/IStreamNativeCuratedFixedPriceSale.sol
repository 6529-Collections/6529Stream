// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamNativeCuratedSaleTypes } from "./StreamNativeCuratedSaleTypes.sol";
import { IStreamNativeCuratedCommitments } from "./IStreamNativeCuratedCommitments.sol";
import { IStreamNativeRefundDelegatedClaims } from "./IStreamNativeRefundDelegatedClaims.sol";

interface IStreamNativeCuratedFixedPriceSale {
    function fixedConfigurationHash(StreamNativeCuratedSaleTypes.FixedConfiguration calldata config)
        external
        view
        returns (bytes32);
    function registerCuratedFixedSale(
        StreamNativeCuratedSaleTypes.FixedConfiguration calldata config
    ) external returns (bytes32 saleId);
    function fixedSaleConfiguration(bytes32 saleId)
        external
        view
        returns (StreamNativeCuratedSaleTypes.FixedConfiguration memory);
    function purchaseSelectedContent(
        bytes32 saleId,
        StreamNativeCuratedSaleTypes.Selection calldata selection
    ) external payable returns (StreamNativeCuratedSaleTypes.ExecutionRecord memory);
    function commitSelection(bytes32 saleId, bytes32 selectionCommitment, uint256 purchaseNonce)
        external
        payable
        returns (bytes32 purchaseId);
    function revealSelection(
        bytes32 saleId,
        StreamNativeCuratedSaleTypes.Selection calldata selection,
        bytes32 salt
    ) external payable returns (StreamNativeCuratedSaleTypes.ExecutionRecord memory);
    function selectionCommitment(bytes32 saleId, address buyer, bytes32 contentLeaf, bytes32 salt)
        external
        view
        returns (bytes32);
    function selectionDeposit(bytes32 saleId, address buyer, bytes32 commitment)
        external
        view
        returns (
            IStreamNativeCuratedCommitments.CommitRecord memory,
            bytes32 purchaseId,
            uint256 purchaseNonce
        );
    function unlockSelectionRefund(bytes32 saleId, address buyer, bytes32 commitment)
        external
        returns (uint256 amount);
    function unlockSelectionRefundForReason(
        bytes32 saleId,
        address buyer,
        bytes32 commitment,
        StreamNativeCuratedSaleTypes.Selection calldata selection,
        bytes32 salt,
        uint8 reason
    ) external returns (uint256 amount);
    function claimSelectionRefund(bytes32 saleId, address payable recipient)
        external
        returns (uint256 amount);
    function claimSelectionRefundDelegated(
        bytes32 saleId,
        address buyer,
        IStreamNativeRefundDelegatedClaims.DelegationWitness calldata witness
    ) external returns (uint256 amount);
    function selectionRefundCredit(bytes32 saleId, address buyer) external view returns (uint256);
    function selectionLiabilities()
        external
        view
        returns (uint256 pending, uint256 refunds, uint256 total);
}
