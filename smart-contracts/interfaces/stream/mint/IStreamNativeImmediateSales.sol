// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../standards/IERC5267.sol";
import "../artist/IStreamArtistSaleFacts.sol";
import "./IStreamImmediateSaleReveal.sol";
import "./IStreamPrivateSaleAdapter.sol";
import "../revenue/StreamNativeSettlementTypes.sol";

/// @notice Canonical Sales-v1 and unsigned public native fixed/open singleton purchases.
/// @dev Only strict collection PROFILE/static TEMPLATE, ungated single-step minting is admitted.
interface IStreamNativeImmediateSales is
    IERC5267,
    IStreamArtistSaleFacts,
    IStreamImmediateSaleReveal
{
    struct SignerBinding {
        address authorizer;
        uint8 kind;
        bytes32 evidenceHash;
        uint64 revision;
        address installingAuthority;
    }

    struct Configuration {
        uint256 collectionId;
        bytes32 phaseId;
        uint8 saleKind; // FIXED_PRICE=0, OPEN_EDITION=1.
        uint8 authorityMode; // SIGNED=1, PUBLIC=2.
        uint256 unitPrice;
        uint64 startsAt;
        uint64 endsAt;
        bool manualClose;
        uint64 saleSupplyLimit; // Positive for fixed, zero for open edition.
        bytes32 mintPolicyHash;
        bytes32 expectedPrimaryPolicyHash;
        uint8 primaryPolicyMode; // STRICT_MATCH=0 only.
        bytes32 priceCounterId;
        SignerBinding signer;
    }

    struct Purchase {
        bytes32 saleId;
        address payer;
        address executor;
        address initialRecipient;
        address beneficiary;
        bytes tokenData;
        bytes32 mintCommitment;
        bytes resolverData;
        uint256 executionNonce;
    }

    struct Record {
        Configuration config;
        bytes32 configHash;
        uint256 saleNonce;
        uint64 soldQuantity;
        bool closed;
        StreamNativeSettlementTypes.SaleLifecycleBinding lifecycle;
        bytes32 artistId;
        uint64 artistGeneration;
        bytes32 artistBindingHash;
    }

    struct Receipt {
        bytes32 saleId;
        bytes32 executionId;
        bytes32 authorizationId;
        bytes32 saleAuthorizationDigest;
        bytes32 operationRoot;
        bytes32 operationId;
        uint256 tokenId;
        bytes32 settlementKey;
        uint256 chargedAmount;
        uint256 revealFee;
        uint256 revealCredit;
    }

    error InvalidImmediateSale();
    error ImmediateSaleUnavailable(bytes32 saleId);
    error ImmediateSaleSignerUnavailable(address authorizer, uint8 kind);
    error ImmediateSaleSignatureInvalid(address authorizer);
    error ImmediateSaleNonceInvalid(uint256 expected, uint256 supplied);
    error ImmediateSaleResultMismatch();
    error ImmediateSaleValueInvalid(uint256 supplied, uint256 price);
    event ImmediateSaleRegistered(
        bytes32 indexed saleId, bytes32 indexed configHash, uint256 saleNonce, Configuration config
    );
    event ImmediateSaleClosed(bytes32 indexed saleId, uint64 soldQuantity);
    event ImmediateSaleSignerConfigured(
        uint256 indexed collectionId,
        address indexed signer,
        uint8 kind,
        SignerBinding binding,
        bool enabled
    );
    event ImmediateSaleExecution(
        bytes32 indexed saleId,
        bytes32 indexed executionId,
        bytes32 indexed operationRoot,
        uint8 status,
        Receipt receipt
    );
    event ImmediateSalePause(
        bytes32 indexed saleId, bool paused, address actor, bytes32 reasonHash
    );
    event ImmediateSaleContestSynced(uint256 indexed collectionId, uint8 contest, bool stopped);

    function registerSale(Configuration calldata config) external returns (bytes32 saleId);
    function saleIdFor(uint256 collectionId, bytes32 phaseId, uint256 saleNonce)
        external
        view
        returns (bytes32);
    function saleConfigurationHash(Configuration calldata config) external view returns (bytes32);
    function saleRecord(bytes32 saleId) external view returns (Record memory);
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
        returns (SignerBinding memory binding, bool enabled);
    function authorizationDigest(StreamPrivateSaleTypes.SaleAuthorization calldata authorization)
        external
        view
        returns (bytes32);
    function previewSignedPurchase(
        Purchase calldata purchase,
        StreamPrivateSaleTypes.SaleAuthorization calldata authorization,
        IStreamPrivateSaleAdapter.Signature calldata signature
    ) external view returns (StreamNativeSettlementTypes.NativeSettlementCandidate memory);
    function previewPublicPurchase(Purchase calldata purchase)
        external
        view
        returns (
            StreamNativeSettlementTypes.NativeSettlementCandidate memory candidate,
            bytes32 managerAuthorizationId
        );
    function purchaseSigned(
        Purchase calldata purchase,
        StreamPrivateSaleTypes.SaleAuthorization calldata authorization,
        IStreamPrivateSaleAdapter.Signature calldata signature
    ) external payable returns (Receipt memory);
    function purchasePublic(Purchase calldata purchase) external payable returns (Receipt memory);
    function executionReceipt(bytes32 executionId) external view returns (Receipt memory);
    function executionStatus(bytes32 executionId) external view returns (uint8);
}
