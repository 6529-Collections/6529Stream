// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./IStreamPrivateSaleAdapter.sol";

/// @notice Native secondary CUSTODY_INVENTORY_FIXED_PRICE (14), never primary inventory.
/// @dev Current owner/lifecycle checks do not prove prior collector delivery. The configured
///      declaration additionally remains subject to the original transfer-history conformance gate.
interface IStreamNativeInventorySale {
    struct Config {
        uint256 collectionId;
        address consignor;
        uint256 unitPrice;
        uint64 startTime;
        uint64 deadline;
        uint32 perBuyerCap;
        bytes32 signerEvidenceHash;
        uint64 signerRevision;
        address signerAuthority;
        bool secondaryConsignment;
        bytes32 expectedPrimaryPolicyHash;
    }

    /// @dev status: 0 absent, 1 collecting custody, 2 open, 4 cancelled, 5 expired.
    struct Inventory {
        Config config;
        bytes32 configHash;
        bytes32 inventoryHash;
        uint256 saleNonce;
        uint64 createdAt;
        uint64 registryRevision;
        uint8 status;
        uint256[] tokenIds;
    }
    event InventoryConfigured(
        uint16 schemaVersion,
        bytes32 indexed saleId,
        bytes32 indexed inventoryHash,
        address indexed consignor,
        bytes32 configHash,
        uint256[] tokenIds
    );
    event InventoryOpened(uint16 schemaVersion, bytes32 indexed saleId);
    event InventoryPurchased(
        uint16 schemaVersion,
        bytes32 indexed saleId,
        uint256 indexed tokenId,
        address indexed buyer,
        uint256 price
    );
    error InvalidInventory();
    error InventoryTokenUnavailable(bytes32 saleId, uint256 tokenId);
    error InventoryBuyerCap(bytes32 saleId, address buyer);
    function registerInventory(Config calldata config, uint256[] calldata tokenIds)
        external
        returns (bytes32);
    function inventoryDetails(bytes32 saleId) external view returns (Inventory memory);
    function inventoryToken(bytes32 saleId, uint256 tokenId)
        external
        view
        returns (IStreamPrivateSaleAdapter.Sale memory);
    function inventoryBuyerPurchases(bytes32 saleId, address buyer) external view returns (uint256);
    function depositInventoryCustody(
        bytes32 saleId,
        StreamPrivateSaleTypes.SaleCustodyGrant calldata grant,
        uint8 ownerKind,
        bytes calldata signature
    ) external;
    function openInventory(bytes32 saleId) external;
    function purchaseInventory(bytes32 saleId, uint256 tokenId, bytes32 expectedConfigHash)
        external
        payable;
    function inventoryRoyaltyQuote(bytes32 saleId, uint256 tokenId)
        external
        view
        returns (
            address receiver,
            uint256 amount,
            bool secondaryConsignment,
            bool externalRoyaltiesDisclosureOnly
        );
    function claimInventoryNft(bytes32 saleId, uint256 tokenId, address receiver)
        external
        returns (bool);
    function retryInventoryNft(bytes32 saleId, uint256 tokenId) external returns (bool);
    /// @notice Pays only this sale's pending royalty bucket to this exact receiver, across its items.
    function retryInventoryRoyalty(bytes32 saleId, address receiver) external returns (bool);
}
