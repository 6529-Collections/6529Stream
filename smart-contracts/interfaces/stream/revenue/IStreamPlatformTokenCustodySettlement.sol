// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamPlatformTokenCustodyTypes.sol";
import "./StreamNativeCustodySettlementTypes.sol";
import "./StreamPreparedNativeRightsTypes.sol";

interface IStreamPlatformTokenCustodySettlement {
    event PlatformTokenCustodyRevenueRecorded(
        uint16 schemaVersion,
        bytes32 indexed settlementKey,
        bytes32 indexed saleKey,
        bytes32 indexed factsHash,
        StreamPlatformTokenCustodyTypes.Activation activation,
        StreamPreparedNativeRightsTypes.OriginalPolicy original,
        StreamNativeCustodySettlementTypes.Facts facts,
        bytes32 beneficiaryHash,
        StreamPrimarySettlementTypes.PrimarySettlementResult result
    );
    function isStreamPlatformTokenCustodySettlement() external pure returns (bool);
    function settlePlatformTokenCustodyPrimarySale(bytes32 auctionId)
        external
        payable
        returns (StreamPrimarySettlementTypes.PrimarySettlementResult memory);
}
