// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamPreparedNativeRightsTypes.sol";
import "./StreamPrimarySettlementTypes.sol";

interface IStreamPreparedNativeRightsPrimarySettlement {
    error InvalidPreparedNativeRights();
    error UnsupportedPreparedNativeRightsMode();

    event PreparedNativeRightsRevenueRecorded(
        bytes32 indexed settlementKey,
        bytes32 indexed saleKey,
        bytes32 indexed factsHash,
        StreamPreparedNativeRightsTypes.Facts facts,
        StreamPreparedNativeRightsTypes.Intent intent,
        bytes32 currentPrimaryPolicyHash
    );

    function settlePreparedNativeRightsSale(
        StreamPreparedNativeRightsTypes.Facts calldata facts,
        StreamPreparedNativeRightsTypes.Intent calldata intent
    ) external payable returns (StreamPrimarySettlementTypes.PrimarySettlementResult memory);

    function preparedNativeRightsFactsHash(bytes32 settlementKey) external view returns (bytes32);
}
