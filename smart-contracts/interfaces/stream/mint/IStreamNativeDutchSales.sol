// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IStreamDutchPriceSchedule } from "./IStreamDutchPriceSchedule.sol";

import { IERC5267 } from "../../standards/IERC5267.sol";
import { IStreamArtistSaleFacts } from "../artist/IStreamArtistSaleFacts.sol";
import { IStreamImmediateSaleReveal } from "./IStreamImmediateSaleReveal.sol";
import { IStreamNativeImmediateSales } from "./IStreamNativeImmediateSales.sol";
import { IStreamPrivateSaleAdapter } from "./IStreamPrivateSaleAdapter.sol";
import { StreamPrivateSaleTypes } from "./StreamPrivateSaleTypes.sol";
import { StreamNativeSettlementTypes } from "../revenue/StreamNativeSettlementTypes.sol";

/// @notice Canonical signed/public native standard Dutch singleton sales.
interface IStreamNativeDutchSales is IERC5267, IStreamArtistSaleFacts, IStreamImmediateSaleReveal {
    struct Configuration {
        IStreamNativeImmediateSales.Configuration sale;
        IStreamDutchPriceSchedule.DutchPriceSchedule schedule;
        bool declaredFree;
    }

    struct Record {
        IStreamNativeImmediateSales.Record sale;
        IStreamDutchPriceSchedule.DutchPriceSchedule schedule;
        bytes32 priceScheduleHash;
        bool declaredFree;
    }

    error InvalidDutchSale();
    error SalePriceOverrideZeroUndeclared(bytes32 saleId);
    error DutchPaymentBelowPrice(uint256 maximum, uint256 required);
    error DutchSignedMaximumBelowPrice(uint256 maximum, uint256 required);
    event DutchSaleRegistered(
        bytes32 indexed saleId, bytes32 indexed configHash, uint256 saleNonce, Configuration config
    );
    event DutchSaleExecution(
        bytes32 indexed saleId,
        bytes32 indexed executionId,
        bytes32 indexed operationRoot,
        uint8 status,
        IStreamNativeImmediateSales.Receipt receipt
    );
    event FreeDutchExecuted(
        bytes32 indexed saleId,
        bytes32 indexed executionId,
        uint256 indexed tokenId,
        bytes32 authorizationId
    );
    event ImmediateSaleClosed(bytes32 indexed saleId, uint64 soldQuantity);
    event ImmediateSaleSignerConfigured(
        uint256 indexed collectionId,
        address indexed signer,
        uint8 kind,
        IStreamNativeImmediateSales.SignerBinding binding,
        bool enabled
    );
    event ImmediateSalePause(
        bytes32 indexed saleId, bool paused, address actor, bytes32 reasonHash
    );
    event ImmediateSaleContestSynced(uint256 indexed collectionId, uint8 contest, bool stopped);

    function registerSale(Configuration calldata configuration) external returns (bytes32 saleId);
    function saleIdFor(uint256 collectionId, bytes32 phaseId, uint256 nonce)
        external
        view
        returns (bytes32);
    function saleConfigurationHash(Configuration calldata configuration)
        external
        view
        returns (bytes32);
    function saleRecord(bytes32 saleId) external view returns (Record memory);
    /// @notice Immutable schedule price at raw block time, before any buyer leaf ceiling.
    function schedulePrice(bytes32 saleId) external view returns (uint256);
    function nextSaleNonce() external view returns (uint256);
    function nextExecutionNonce(bytes32 saleId, address payer) external view returns (uint256);
    function closeSale(bytes32 saleId) external;
    function setGlobalPause(bool paused, bytes32 reasonHash) external;
    function setSalePause(bytes32 saleId, bool paused, bytes32 reasonHash) external;
    function syncCollectionContest(uint256 collectionId) external;
    function configureCollectionSigner(
        uint256 collectionId,
        address signer,
        uint8 kind,
        bytes32 evidenceHash,
        bool enabled
    ) external;
    function collectionSigner(uint256 collectionId, address signer, uint8 kind)
        external
        view
        returns (IStreamNativeImmediateSales.SignerBinding memory, bool);
    function authorizationDigest(StreamPrivateSaleTypes.SaleAuthorization calldata authorization)
        external
        view
        returns (bytes32);
    /// @dev The native candidate binds the mint preview; a declared-free zero never enters the recorder.
    function previewSignedPurchase(
        IStreamNativeImmediateSales.Purchase calldata purchase,
        StreamPrivateSaleTypes.SaleAuthorization calldata authorization,
        IStreamPrivateSaleAdapter.Signature calldata proof
    ) external view returns (StreamNativeSettlementTypes.NativeSettlementCandidate memory);
    function previewPublicPurchase(IStreamNativeImmediateSales.Purchase calldata purchase)
        external
        view
        returns (
            StreamNativeSettlementTypes.NativeSettlementCandidate memory,
            bytes32 authorizationId
        );
    function purchaseSigned(
        IStreamNativeImmediateSales.Purchase calldata purchase,
        StreamPrivateSaleTypes.SaleAuthorization calldata authorization,
        IStreamPrivateSaleAdapter.Signature calldata proof
    ) external payable returns (IStreamNativeImmediateSales.Receipt memory);
    function purchasePublic(IStreamNativeImmediateSales.Purchase calldata purchase)
        external
        payable
        returns (IStreamNativeImmediateSales.Receipt memory);
    function executionReceipt(bytes32 executionId)
        external
        view
        returns (IStreamNativeImmediateSales.Receipt memory);
    function executionStatus(bytes32 executionId) external view returns (uint8);
}
