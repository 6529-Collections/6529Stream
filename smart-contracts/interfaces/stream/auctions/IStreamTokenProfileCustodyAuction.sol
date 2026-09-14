// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IStreamNativeEnglishAuction.sol";
import "../revenue/StreamTokenProfileCustodyTypes.sol";

/// @notice Explicit ALLOW_CURRENT token-PROFILE custody rights; original acquisition is retained.
interface IStreamTokenProfileCustodyAuction {
    error InvalidTokenProfileCustody();
    error TokenProfileCustodyEntryRequired(bytes32 auctionId);

    event TokenProfileCustodyActivated(
        uint16 schemaVersion,
        bytes32 indexed auctionId,
        uint256 indexed tokenId,
        bytes32 indexed authorizationDigest,
        StreamTokenProfileCustodyTypes.Activation activation
    );

    function tokenProfileCustodyDigest(
        StreamTokenProfileCustodyTypes.Authorization calldata authorization
    ) external view returns (bytes32);
    function activateTokenProfileCustody(
        StreamTokenProfileCustodyTypes.Authorization calldata authorization,
        bytes calldata platformSignature,
        bytes calldata artistSignature
    ) external;
    function tokenProfileCustodyActivation(bytes32 auctionId)
        external
        view
        returns (StreamTokenProfileCustodyTypes.Activation memory);
    function tokenProfileCustodyConfigurationHash(bytes32 auctionId) external view returns (bytes32);
    function tokenProfileCustodyNonceUsed(address artist, bytes32 nonce)
        external
        view
        returns (bool);
    function bidTokenProfileCustody(bytes32 auctionId, address deliverTo) external payable;
    function bidSignedTokenProfileCustody(
        IStreamNativeEnglishAuction.BidAuthorization calldata authorization,
        bytes calldata signature
    ) external payable;
    function settleTokenProfileCustody(bytes32 auctionId)
        external
        returns (uint256 tokenId, bytes32 settlementKey);
}
