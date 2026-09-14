// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IStreamNativeEnglishAuction.sol";
import "../revenue/StreamCustodyRightsTypes.sol";

/// @notice Explicit ALLOW_CURRENT custody rights; original acquisition is retained.
interface IStreamCustodyRightsAuction {
    error InvalidCustodyRights();
    error CustodyRightsEntryRequired(bytes32 auctionId);

    event CustodyRightsActivated(
        uint16 schemaVersion,
        bytes32 indexed auctionId,
        uint256 indexed tokenId,
        bytes32 indexed authorizationDigest,
        StreamCustodyRightsTypes.Activation activation
    );

    function custodyRightsDigest(StreamCustodyRightsTypes.Authorization calldata authorization)
        external
        view
        returns (bytes32);
    function activateCustodyRights(
        StreamCustodyRightsTypes.Authorization calldata authorization,
        bytes calldata platformSignature,
        bytes calldata artistSignature
    ) external;
    function custodyRightsActivation(bytes32 auctionId)
        external
        view
        returns (StreamCustodyRightsTypes.Activation memory);
    function custodyRightsConfigurationHash(bytes32 auctionId) external view returns (bytes32);
    function custodyRightsNonceUsed(address artist, bytes32 nonce) external view returns (bool);
    function bidCustodyRights(bytes32 auctionId, address deliverTo) external payable;
    function bidSignedCustodyRights(
        IStreamNativeEnglishAuction.BidAuthorization calldata authorization,
        bytes calldata signature
    ) external payable;
    function settleCustodyRights(bytes32 auctionId)
        external
        returns (uint256 tokenId, bytes32 settlementKey);
}
