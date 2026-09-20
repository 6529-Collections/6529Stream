// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { IStreamNativeImmediateSales as S } from "./IStreamNativeImmediateSales.sol";
import "./IStreamDutchPriceSchedule.sol";
import "./IStreamPrivateSaleAdapter.sol";
import "../revenue/IStreamERC20SaleExecution.sol";

/// @notice Standard ERC20 Dutch sales; canonical Sales-v1 signer or payer-executed public mode.
/// @dev The common Configuration has saleKind=3 and unitPrice=0. Each signed authorization
/// supplies its own maximum; a proven leaf replaces that maximum under the original U6 rule.
interface IStreamERC20DutchSale {
    struct Configuration {
        S.Configuration sale;
        address asset;
        address paymentAdapter;
        IStreamDutchPriceSchedule.DutchPriceSchedule schedule;
        bool declaredFree;
    }

    struct Execution {
        S.Purchase purchase;
        StreamPrivateSaleTypes.SaleAuthorization authorization;
        IStreamPrivateSaleAdapter.Signature signature;
    }

    struct Record {
        Configuration config;
        bytes32 configHash;
        bytes32 priceScheduleHash;
        uint256 saleNonce;
        uint64 soldQuantity;
        bool closed;
        StreamPrimarySettlementTypes.SaleLifecycleBinding lifecycle;
        bytes32 artistId;
        uint64 artistGeneration;
        bytes32 artistBindingHash;
    }
    event ERC20DutchSaleRegistered(
        bytes32 indexed saleId,
        bytes32 indexed configHash,
        bytes32 priceScheduleHash,
        uint256 saleNonce,
        Configuration config
    );
    event ERC20DutchExecution(
        bytes32 indexed saleId,
        bytes32 indexed executionId,
        uint8 status,
        uint8 revenueOutcome,
        S.Receipt receipt
    );
    function registerDutchSale(Configuration calldata config) external returns (bytes32 saleId);
    function dutchSaleRecord(bytes32 saleId) external view returns (Record memory);
    function previewDutchExecution(Execution calldata execution)
        external
        view
        returns (
            StreamPrimarySettlementTypes.ERC20SettlementCandidate memory candidate,
            bytes memory executionData
        );
    function currentDutchPrice(bytes32 saleId) external view returns (uint256);
}
