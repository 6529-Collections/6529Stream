// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamPrivateSaleTypes.sol";
import "../../../vendor/openzeppelin/IERC165.sol";

/// @notice Native, buyer-bound secondary custody sales. No primary revenue or mint authority.
interface IStreamPrivateSaleAdapter is IERC165 {
    struct Signature {
        address authorizer;
        uint8 kind;
        bytes signature;
    }

    struct CollectionSigner {
        bytes32 evidenceHash;
        uint64 revision;
        bool enabled;
        address authority;
    }

    struct SaleConfig {
        uint8 saleKind;
        uint256 collectionId;
        uint256 tokenId;
        address consignor;
        address buyer;
        uint256 price;
        uint64 startTime;
        uint64 deadline;
        bytes32 offerDigest;
        bytes32 signerEvidenceHash;
        uint64 signerRevision;
        address signerAuthority;
        bool secondaryConsignment;
        bytes32 expectedPrimaryPolicyHash;
    }

    /// @dev status: 0 absent, 1 configured, 2 custody, 3 sold, 4 cancelled, 5 expired.
    ///      nftClaim: 0 none, 1 buyer, 2 original consignor. Neither is another sale.
    struct Sale {
        SaleConfig config;
        bytes32 configHash;
        uint256 saleNonce;
        uint64 createdAt;
        uint64 registryRevision;
        uint8 status;
        uint8 nftClaim;
        bytes32 custodyGrantDigest;
        bytes32 authorizationDigest;
        address royaltyReceiver;
        uint256 royaltyAmount;
    }

    struct Credits {
        uint256 excess;
        uint256 consignorProceeds;
        uint256 royalty;
    }

    event CollectionSaleSignerConfigured(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        address indexed signer,
        bytes32 evidenceHash,
        uint64 revision,
        bool enabled,
        address authority
    );
    event SaleConfigured(
        uint16 schemaVersion,
        bytes32 indexed saleId,
        uint256 indexed collectionId,
        bytes32 indexed phaseId,
        uint8 saleKind,
        address asset,
        bytes32 saleConfigHash,
        bytes32 expectedPrimaryPolicyHash,
        uint8 primaryPolicyMode
    );
    event PrivateSaleExecuted(
        uint16 schemaVersion,
        bytes32 indexed saleId,
        address indexed buyer,
        uint256 tokenId,
        uint256 price,
        address asset
    );
    event OfferAccepted(
        uint16 schemaVersion,
        bytes32 indexed saleId,
        address indexed buyer,
        bytes32 offerDigest,
        uint256 price,
        address asset
    );
    event SaleCustodyDeposited(
        uint16 schemaVersion, bytes32 indexed saleId, uint256 indexed tokenId, address indexed owner
    );
    event SaleCustodyReleased(
        uint16 schemaVersion,
        bytes32 indexed saleId,
        uint256 indexed tokenId,
        address receiver,
        bytes32 reasonHash
    );
    event SaleCustodyGrantRevoked(
        uint16 schemaVersion, bytes32 indexed grantDigest, address indexed owner
    );
    event ConsignmentSettled(
        uint16 schemaVersion,
        bytes32 indexed saleId,
        uint256 indexed tokenId,
        address indexed buyer,
        uint256 price,
        uint256 royaltyAmount,
        address royaltyReceiver,
        address consignor
    );
    event SaleAuthorizationConsumed(
        uint16 schemaVersion, bytes32 indexed saleId, bytes32 indexed digest, address authorizer
    );
    event SaleOfferRevoked(
        uint16 schemaVersion, bytes32 indexed offerDigest, address indexed buyer
    );
    event SaleAuthorizationRevoked(
        uint16 schemaVersion, bytes32 indexed saleId, bytes32 indexed digest, address authorizer
    );
    event SaleStatusChanged(
        uint16 schemaVersion,
        bytes32 indexed saleId,
        uint8 previousStatus,
        uint8 newStatus,
        bytes32 reasonHash
    );
    event AdapterPaused(uint16 schemaVersion, address indexed guardian, bytes32 reasonHash);
    event AdapterUnpaused(uint16 schemaVersion, address indexed unpauser, bytes32 reasonHash);
    event SalePaused(
        uint16 schemaVersion, bytes32 indexed saleId, address indexed guardian, bytes32 reasonHash
    );
    event SaleUnpaused(
        uint16 schemaVersion, bytes32 indexed saleId, address indexed unpauser, bytes32 reasonHash
    );
    event PrivateSaleCreditClaimed(
        uint16 schemaVersion,
        bytes32 indexed saleId,
        address indexed account,
        address indexed receiver,
        address asset,
        uint256 amount
    );
    event ConsignmentRoyaltyDelivery(
        uint16 schemaVersion,
        bytes32 indexed saleId,
        address indexed receiver,
        uint256 amount,
        bool delivered
    );
    event PrivateSaleNftDelivery(
        uint16 schemaVersion,
        bytes32 indexed saleId,
        uint256 indexed tokenId,
        address indexed receiver,
        bool delivered
    );

    error InvalidPrivateSale();
    error PrivateSaleUnavailable(bytes32 saleId);
    error PrivateSaleNotBuyer(address caller);
    error PrivateSalePaymentTooSmall(uint256 required, uint256 supplied);
    error PrivateSaleAuthorityInvalid(address authorizer);
    error PrivateSaleDigestConsumed(bytes32 digest);
    error CustodyGrantInvalid();
    error PrivateSaleTokenInvalid(uint256 tokenId);
    error PrivateSaleRoyaltyInvalid(uint256 tokenId);
    error PrivateSaleReadFailed(address target);
    error PrivateSaleModuleNotAdmitted();
    error PrivateSaleInsufficientGas(uint256 required, uint256 available);
    error PrivateSaleBalanceMismatch();
    error PrivateSaleClaimUnavailable();
    error PrivateSaleClaimFailed();
    error PrivateSaleRoleNotAuthorized(bytes32 role, address caller);
    error PrivateSalePaused(bytes32 saleId);

    function core() external view returns (address);
    function streamModuleType() external pure returns (bytes32);
    function streamModuleInterfaceId() external pure returns (bytes4);
    function custodySaleLifecycle(bytes32 saleId) external view returns (uint64, uint64);
    function saleRecord(bytes32 saleId)
        external
        view
        returns (uint8, uint256, bytes32, address, bytes32, bytes32, uint8, uint8);
    function saleDetails(bytes32 saleId) external view returns (Sale memory);
    function royaltyQuote(bytes32 saleId)
        external
        view
        returns (
            address receiver,
            uint256 amount,
            bool secondaryConsignment,
            bool externalRoyaltiesDisclosureOnly
        );
    function refundableBalance(bytes32 saleId, address account) external view returns (uint256);
    function creditBreakdown(bytes32 saleId, address account) external view returns (Credits memory);
    function claimRefund(bytes32 saleId, address to) external;
}
