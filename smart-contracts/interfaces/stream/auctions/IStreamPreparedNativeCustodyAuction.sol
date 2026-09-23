// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IStreamNativeCustodyAuction } from "./IStreamNativeCustodyAuction.sol";
import { IStreamNativeEnglishAuction } from "./IStreamNativeEnglishAuction.sol";

/// @notice Explicit prepared acquisition authority, separate from the original single-step domain.
interface IStreamPreparedNativeCustodyAuction {
    event NativeAuctionPreparedCustodyBound(
        uint16 schemaVersion,
        bytes32 indexed auctionId,
        uint256 indexed tokenId,
        bytes32 indexed operationRoot,
        bytes32 operationId,
        bytes32 authorizationDigest
    );

    function preparedCustodyAcquisitionDigest(
        IStreamNativeCustodyAuction.Acquisition calldata authorization
    ) external view returns (bytes32);
    function registerPreparedCustodyAuction(
        IStreamNativeEnglishAuction.Configuration calldata config,
        IStreamNativeCustodyAuction.Acquisition calldata authorization,
        bytes calldata tokenData,
        bytes calldata platformSignature,
        bytes calldata artistSignature
    ) external payable returns (bytes32 auctionId);
}
