// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../vendor/openzeppelin/IERC165.sol";

/// @notice Signed native-ETH sales into the current Core mint path and immutable split wallets.
interface IStreamFixedPriceSaleAdapter is IERC165 {
    struct SaleAuthorization {
        uint256 collectionId;
        bytes32 phaseId;
        address payer;
        address recipient;
        address artist;
        bytes32 profileId;
        bytes32 tokenDataHash;
        bytes32 mintCommitment;
        bytes32 mintPolicyHash;
        uint256 price;
        bytes32 nonce;
        uint64 deadline;
        uint64 signerEpoch;
    }

    error InvalidSaleConfiguration();
    error SalesPaused();
    error InvalidSaleAuthorization();
    error SaleExpired(uint64 deadline);
    error SaleAlreadyConsumed(address artist, bytes32 nonce);
    error InvalidSaleSignature(address signer);
    error IncorrectSaleValue(uint256 expected, uint256 actual);
    error InvalidSplitProfile(bytes32 profileId);
    error SaleDepositFailed(address wallet);
    error SaleMintResultInvalid();

    event NativeSaleSettled(
        bytes32 indexed authorizationId,
        bytes32 indexed operationRoot,
        uint256 indexed tokenId,
        bytes32 authorizationDigest,
        bytes32 profileId,
        address wallet,
        uint256 amount
    );
    event SaleParticipants(
        bytes32 indexed authorizationId,
        uint256 indexed collectionId,
        address indexed artist,
        address payer,
        address recipient
    );
    event SaleAuthorizationCancelled(address indexed artist, bytes32 indexed nonce);
    event SalePlatformSignerChanged(address indexed signer, uint64 epoch);
    event SalesPauseChanged(bool paused);

    function buy(
        SaleAuthorization calldata sale,
        bytes calldata tokenData,
        bytes calldata platformSignature,
        bytes calldata artistSignature
    ) external payable returns (uint256 tokenId, bytes32 operationRoot);

    function authorizationDigest(SaleAuthorization calldata sale) external view returns (bytes32);
    function authorizationId(address artist, bytes32 nonce) external view returns (bytes32);
    function authorizationUsed(address artist, bytes32 nonce) external view returns (bool);
    function cancelAuthorization(bytes32 nonce) external;
}
