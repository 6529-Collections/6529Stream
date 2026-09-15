// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IStreamNativeEnglishAuction.sol";
import "../revenue/IStreamPreparedNativeRightsSaleBinding.sol";

interface IStreamNativeRightsAuction is IStreamPreparedNativeRightsSaleBinding {
    event NativeAuctionRightsBound(
        bytes32 indexed auctionId,
        bytes32 indexed saleId,
        uint8 mode,
        bytes32 originalAssignmentHash,
        bytes32 originalTemplateId
    );

    function rightsConfigurationHash(
        IStreamNativeEnglishAuction.Configuration calldata config,
        StreamPreparedNativeRightsTypes.OriginalPolicy calldata original
    ) external view returns (bytes32);

    function registerRightsAuction(
        IStreamNativeEnglishAuction.Configuration calldata config,
        StreamPreparedNativeRightsTypes.OriginalPolicy calldata original,
        bytes calldata tokenData,
        IStreamNativeEnglishAuction.CreationAuthorization calldata authorization,
        bytes calldata platformSignature,
        bytes calldata artistSignature
    ) external returns (bytes32 auctionId);

    function originalAuctionRights(bytes32 auctionId)
        external
        view
        returns (StreamPreparedNativeRightsTypes.OriginalPolicy memory);
}
