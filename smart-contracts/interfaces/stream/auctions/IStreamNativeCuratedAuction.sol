// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./IStreamNativeEnglishAuction.sol";
import "../mint/StreamPreparedNativeContentTypes.sol";

/// @notice Original published content-leaf extension; token IDs remain sequential Core allocations.
interface IStreamNativeCuratedAuction {
    function nextCuratedSaleId(uint256 collectionId, bytes32 phaseId)
        external
        view
        returns (uint256 saleNonce, bytes32 saleId);
    function registerCuratedAuction(
        IStreamNativeEnglishAuction.Configuration calldata config,
        bytes calldata tokenData,
        StreamPreparedNativeContentTypes.Selection calldata selection,
        uint256 expectedSaleNonce,
        IStreamNativeEnglishAuction.CreationAuthorization calldata authorization,
        bytes calldata platformSignature,
        bytes calldata artistSignature
    ) external returns (bytes32 auctionId);
    function curatedSelection(bytes32 auctionId)
        external
        view
        returns (StreamPreparedNativeContentTypes.Selection memory);
}
