// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IERC5267 } from "../../standards/IERC5267.sol";
import { IStreamArtistSaleFacts } from "../artist/IStreamArtistSaleFacts.sol";
import { IStreamImmediateSaleReveal } from "./IStreamImmediateSaleReveal.sol";
import { IStreamNativeImmediateSales } from "./IStreamNativeImmediateSales.sol";
import { IStreamPrivateSaleAdapter } from "./IStreamPrivateSaleAdapter.sol";
import { StreamPrivateSaleTypes } from "./StreamPrivateSaleTypes.sol";
import { StreamNativeSettlementTypes } from "../revenue/StreamNativeSettlementTypes.sol";

/// @notice Canonical native zero-price claims and bounded pay-what-you-want singleton sales.
interface IStreamNativeClaimSales is IERC5267, IStreamArtistSaleFacts, IStreamImmediateSaleReveal {
    struct Configuration {
        IStreamNativeImmediateSales.Configuration sale;
        uint256 maxUnitPrice;
    }

    struct Purchase {
        IStreamNativeImmediateSales.Purchase mint;
        uint256 chosenUnitPrice;
    }

    struct Record {
        IStreamNativeImmediateSales.Record sale;
        uint256 maxUnitPrice;
    }

    error InvalidClaimSale();
    error ClaimPriceInvalid(uint256 chosen, uint256 minimum, uint256 maximum);
    event ClaimSaleRegistered(
        bytes32 indexed saleId, bytes32 indexed configHash, uint256 saleNonce, Configuration config
    );
    event ClaimSaleExecution(
        bytes32 indexed saleId,
        bytes32 indexed executionId,
        bytes32 indexed operationRoot,
        uint8 status,
        IStreamNativeImmediateSales.Receipt receipt
    );
    event FreeClaimExecuted(
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
    /// @dev The native candidate binds the mint preview; chosen zero never enters the recorder.
    function previewSignedPurchase(
        Purchase calldata purchase,
        StreamPrivateSaleTypes.SaleAuthorization calldata authorization,
        IStreamPrivateSaleAdapter.Signature calldata proof
    ) external view returns (StreamNativeSettlementTypes.NativeSettlementCandidate memory);
    function previewPublicPurchase(Purchase calldata purchase)
        external
        view
        returns (
            StreamNativeSettlementTypes.NativeSettlementCandidate memory,
            bytes32 authorizationId
        );
    function purchaseSigned(
        Purchase calldata purchase,
        StreamPrivateSaleTypes.SaleAuthorization calldata authorization,
        IStreamPrivateSaleAdapter.Signature calldata proof
    ) external payable returns (IStreamNativeImmediateSales.Receipt memory);
    function purchasePublic(Purchase calldata purchase)
        external
        payable
        returns (IStreamNativeImmediateSales.Receipt memory);
    function executionReceipt(bytes32 executionId)
        external
        view
        returns (IStreamNativeImmediateSales.Receipt memory);
    function executionStatus(bytes32 executionId) external view returns (uint8);
}
