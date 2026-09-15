// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamNativeCustodySettlementTypes.sol";
import "./StreamPreparedNativeRightsTypes.sol";

interface IStreamPlatformCustodyPrimarySettlement {
    event PlatformCustodyRevenueRecorded(
        uint16 schemaVersion,
        bytes32 indexed settlementKey,
        bytes32 indexed saleKey,
        bytes32 indexed factsHash,
        bytes32 declarationHash,
        StreamPreparedNativeRightsTypes.OriginalPolicy original,
        StreamNativeCustodySettlementTypes.Facts facts,
        bytes32 beneficiaryHash,
        StreamPrimarySettlementTypes.PrimarySettlementResult result
    );
    function isStreamPlatformCustodyPrimarySettlement() external pure returns (bool);
    function settlePlatformCustodyPrimarySale(bytes32 auctionId)
        external
        payable
        returns (StreamPrimarySettlementTypes.PrimarySettlementResult memory);
}
