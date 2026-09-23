// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./IStreamUniversalFixedPriceSaleAdapter.sol";
import "./IStreamImmediateSaleReveal.sol";

/// @notice Dedicated same-leaf, one-token ERC20 fixed-sale capability.
/// @dev Reuses ADR0019 UniversalSaleAuthorization types; does not advertise proofless legacy registration or preview.
interface IStreamUniversalAllowlistPriceSale {
    event UniversalSaleConfigured(
        bytes32 indexed saleId,
        uint256 indexed collectionId,
        bytes32 indexed phaseId,
        uint16 schemaVersion,
        uint256 saleNonce,
        bytes32 configHash,
        address paymentAdapter
    );
    event UniversalSaleCancelled(bytes32 indexed saleId, uint16 schemaVersion);
    event UniversalSalesPaused(uint16 schemaVersion, bool paused);
    event UniversalAuthorizationCancelled(
        address indexed artist, bytes32 indexed nonce, uint16 schemaVersion
    );
    event UniversalSaleExecution(
        bytes32 indexed saleId,
        bytes32 indexed executionId,
        bytes32 indexed operationRoot,
        uint16 schemaVersion,
        uint8 status,
        bytes32 settlementKey,
        uint256 tokenId
    );

    struct AllowlistPricePolicy { bytes32 priceCounterId; bool allowFree; }
    error InvalidUniversalPriceProfile();
    error SalePriceOverrideZeroUndeclared(bytes32 saleId);
    event UniversalAllowlistPriceConfigured(bytes32 indexed saleId, uint16 schemaVersion, bytes32 priceCounterId, bool allowFree);
    event UniversalAllowlistFreeMint(bytes32 indexed saleId, bytes32 indexed executionId, bytes32 indexed operationRoot, uint16 schemaVersion, bytes32 operationId, uint256 tokenId, address payer, address recipient);
    function registerAllowlistSale(IStreamUniversalFixedPriceSaleAdapter.SaleConfig calldata config, AllowlistPricePolicy calldata policy) external returns (bytes32 saleId);
    function allowlistPricePolicy(bytes32 saleId) external view returns (AllowlistPricePolicy memory);
    /// @notice The returned bytes go unchanged to the existing contract20 entry and callback.
    function previewAllowlistExecution(IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData calldata execution, bytes calldata resolverData) external view returns (StreamPrimarySettlementTypes.ERC20SettlementCandidate memory candidate, bytes memory executionData);
    /// @notice Proven declared zero ERC20 tier; msg.value independently funds native reveal.
    /// No payment adapter entry, payment intent consumption or official settlement.
    function executeAllowlistFreeMint(IStreamUniversalFixedPriceSaleAdapter.SaleExecutionData calldata execution, bytes calldata resolverData) external payable returns (uint256 tokenId, bytes32 operationRoot, bytes32 executionId);
    function allowlistRevealQuote(bytes32 saleId) external view returns (IStreamImmediateSaleReveal.RevealQuote memory);
    function saleRecord(bytes32 saleId) external view returns (IStreamUniversalFixedPriceSaleAdapter.SaleRecord memory);
    function saleIdFor(uint256 collectionId,bytes32 phaseId,uint256 saleNonce) external view returns(bytes32);
    function authorizationDigest(IStreamUniversalFixedPriceSaleAdapter.SaleAuthorization calldata authorization) external view returns(bytes32);
    function cancelSale(bytes32 saleId) external;
    function cancelAuthorization(bytes32 nonce) external;
    function setPaused(bool paused) external;
}
