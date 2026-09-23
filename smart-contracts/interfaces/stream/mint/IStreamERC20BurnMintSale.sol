// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamERC20BurnMintTypes as E, U, S } from "./StreamERC20BurnMintTypes.sol";

/// @notice Positive collection PROFILE/order-one burn sale with zero declared native reveal fee.
/// Original UniversalSaleAuthorization fields/domain and contract20 payer intent remain separate.
interface IStreamERC20BurnMintSale {
    error InvalidUniversalSale();
    error UniversalSaleUnavailable(bytes32 saleId);
    error UniversalAuthorizationUsed(address artist, bytes32 nonce);
    error UniversalExecutionUsed(bytes32 saleId, uint256 executionNonce);
    error UniversalSaleSignatureInvalid(address signer);
    error UniversalCandidateMismatch();
    error UniversalSettlementFailed();
    error UniversalMintResultInvalid();
    error BurnMintNativeFeeUnsupported(uint256 requiredWei);
    error BurnMintContinuationUnavailable();

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
    function registerSale(U.SaleConfig calldata config) external returns (bytes32 saleId);
    function saleRecord(bytes32 saleId) external view returns (U.SaleRecord memory);
    function saleIdFor(uint256 collectionId, bytes32 phaseId, uint256 saleNonce)
        external
        view
        returns (bytes32);
    function authorizationDigest(U.SaleAuthorization calldata authorization)
        external
        view
        returns (bytes32);
    /// @dev Nonpayable simulation temporarily installs a guarded gate proof under a STATICCALL.
    function previewExecution(E.Execution calldata execution)
        external
        returns (S.ERC20SettlementCandidate memory);
    function cancelSale(bytes32 saleId) external;
    function cancelAuthorization(bytes32 nonce) external;
    function setPaused(bool value) external;
}
