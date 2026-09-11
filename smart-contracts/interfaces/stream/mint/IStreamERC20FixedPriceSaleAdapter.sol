// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../revenue/IStreamPaymentIntentVerifier.sol";
import "./IStreamMintManager.sol";
import "../revenue/IStreamRevenueResolver.sol";
import "../revenue/IStreamSplitFactory.sol";
import "../artist/IStreamArtistAttribution.sol";
import "../../../vendor/openzeppelin/IERC165.sol";
import "./IStreamSaleFunding.sol";

/// @notice Current-stack fixed-price ERC-20 purchases with creator, platform and payer consent.
/// @dev Fixed-profile collection primary assignments; bounded deposit/escrow, no templates or permits.
interface IStreamERC20FixedPriceSaleAdapter is IERC165, IStreamSaleFunding {
    struct SaleConfig {
        uint256 collectionId;
        bytes32 phaseId;
        address asset;
        bytes32 revenueClass;
        uint256 price;
        bytes32 mintPolicyHash;
        bytes32 expectedPrimaryPolicyHash;
        uint64 startsAt;
        uint64 endsAt;
    }

    struct SaleRecord {
        SaleConfig config;
        uint256 saleNonce;
        bytes32 configHash;
        bool cancelled;
    }

    struct SaleAuthorization {
        bytes32 saleId;
        bytes32 saleConfigHash;
        address payer;
        address recipient;
        address artist;
        bytes32 tokenDataHash;
        bytes32 mintCommitment;
        bytes32 nonce;
        uint64 deadline;
        uint64 signerEpoch;
    }

    error InvalidSaleConfiguration();
    error SaleUnavailable(bytes32 saleId);
    error InvalidSaleAuthorization();
    error SaleAuthorizationUsed(address artist, bytes32 nonce);
    error InvalidSaleSignature(address signer);
    error UnsupportedPrimaryAssignment();
    error PrimaryPolicyMismatch(bytes32 expected, bytes32 actual);
    error AssetNotActive(address asset);
    error ERC20TransferFailed(address asset);
    error ERC20BalanceReadFailed(address asset, address account);
    error ERC20AmountMismatch(address asset);
    error SaleMintResultInvalid();

    event SaleConfigured(
        bytes32 indexed saleId,
        uint256 indexed collectionId,
        bytes32 indexed phaseId,
        uint256 saleNonce,
        bytes32 saleConfigHash
    );
    event SaleCancelled(bytes32 indexed saleId);
    event SaleAuthorizationCancelled(address indexed artist, bytes32 indexed nonce);
    event PlatformSignerChanged(address indexed signer, uint64 epoch);
    event SalesPauseChanged(bool paused);
    event ERC20SaleSettled(
        bytes32 indexed saleId,
        bytes32 indexed operationRoot,
        uint256 indexed tokenId,
        bytes32 authorizationId,
        bytes32 authorizationDigest,
        bytes32 profileId,
        address wallet,
        address asset,
        uint256 amount
    );
    event ERC20SaleParticipants(
        bytes32 indexed authorizationId,
        address indexed artist,
        address indexed payer,
        address recipient,
        bytes32 primaryPolicyHash
    );

    /// @notice Mint execution dependency bound to the same Core as the artist registry.
    function mintManager() external view returns (IStreamMintManager);
    /// @notice Immutable primary-assignment resolver; distinct from the royalty resolver.
    function revenueResolver() external view returns (IStreamRevenueResolver);
    /// @notice Factory used to verify the assigned immutable split wallet.
    function splitFactory() external view returns (IStreamSplitFactory);
    /// @notice Shared token admission registry pinned by the split factory.
    function assetPolicyRegistry() external view returns (IStreamAssetPolicyRegistry);
    /// @notice Collection attribution authority bound to the manager's Core.
    function artistRegistry() external view returns (IStreamArtistAttribution);
    /// @notice Current platform signer for commercial sale authorizations.
    function platformSigner() external view returns (address);
    /// @notice Monotonic signer epoch included in every commercial authorization.
    function signerEpoch() external view returns (uint64);
    /// @notice Next never-reused sale program nonce.
    function nextSaleNonce() external view returns (uint256);
    /// @notice Whether all purchases are paused; revocation remains available.
    function paused() external view returns (bool);
    /// @notice Exact successfully settled amounts for one profile and asset; excludes donations.
    function proceeds(bytes32 profileId, address asset) external view returns (uint256);
    /// @notice Exact successfully settled amounts per asset across profiles.
    function totalProceeds(address asset) external view returns (uint256);
    /// @notice Owner governance rotates the platform key and advances the signer epoch.
    function setPlatformSigner(address signer) external;
    /// @notice Owner governance pauses or resumes purchases.
    function setPaused(bool value) external;

    /// @notice Registers immutable commercial terms under the next canonical fixed-price sale ID.
    function registerSale(SaleConfig calldata config) external returns (bytes32 saleId);
    /// @notice Permanently stops new purchases while retaining the original sale record.
    function cancelSale(bytes32 saleId) external;
    /// @notice Reads the full immutable sale terms and cancellation state.
    function saleRecord(bytes32 saleId) external view returns (SaleRecord memory);
    /// @notice Computes the SSA-IDENTITY sale ID with FIXED_PRICE kind 0.
    function saleIdFor(uint256 collectionId, bytes32 phaseId, uint256 saleNonce)
        external
        view
        returns (bytes32);
    /// @notice Returns the canonical PRIMARY_SALE commitment for an explicit collection fixed profile.
    function primaryPolicy(uint256 collectionId, bytes32 revenueClass)
        external
        view
        returns (bytes32 policyHash, bytes32 profileId, address wallet);
    /// @notice Creator/platform digest under the reported PaymentIntentVerifier domain and a distinct type.
    function authorizationDigest(SaleAuthorization calldata authorization)
        external
        view
        returns (bytes32);
    /// @notice Manager authorization identity scoped to this adapter, artist and nonce.
    function authorizationId(address artist, bytes32 nonce) external view returns (bytes32);
    /// @notice Returns whether an artist nonce was used or cancelled.
    function authorizationUsed(address artist, bytes32 nonce) external view returns (bool);
    /// @notice Cancels the caller's artist nonce independently of payer consent.
    function cancelAuthorization(bytes32 nonce) external;
    /// @notice Executes one atomic payment and mint; an empty payer signature only exempts the literal payer caller.
    function buy(
        SaleAuthorization calldata authorization,
        bytes calldata tokenData,
        bytes calldata platformSignature,
        bytes calldata artistSignature,
        IStreamPaymentIntentVerifier.PaymentIntent calldata intent,
        bytes calldata payerSignature
    ) external returns (uint256 tokenId, bytes32 operationRoot);
}
