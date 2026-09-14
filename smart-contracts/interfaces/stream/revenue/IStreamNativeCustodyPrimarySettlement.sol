// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamNativeCustodySettlementTypes.sol";
import "./StreamPrimarySettlementTypes.sol";

interface IStreamNativeCustodyPrimarySettlement {
    error InvalidNativeCustodySettlement();
    error NativeCustodyHouseAlreadyBound();

    event CanonicalCustodyHouseBound(
        address indexed house,
        bytes32 indexed codeHash,
        bytes32 indexed actionId,
        StreamNativeCustodySettlementTypes.CanonicalHouse binding
    );
    event NativeCustodyRevenueRecorded(
        bytes32 indexed settlementKey,
        bytes32 indexed saleKey,
        bytes32 indexed factsHash,
        StreamNativeCustodySettlementTypes.Facts facts,
        StreamPrimarySettlementTypes.PrimarySettlementResult result
    );

    function bindCanonicalCustodyHouse(address house) external;
    function canonicalCustodyHouse()
        external
        view
        returns (StreamNativeCustodySettlementTypes.CanonicalHouse memory);
    function custodyHouseTransition(address house)
        external
        view
        returns (bytes32 scope, bytes32 oldState, bytes32 newState);
    function requireCanonicalCustodyHouse(address house) external view;
    function settleNativeCustodyPrimarySale(bytes32 auctionId)
        external
        payable
        returns (StreamPrimarySettlementTypes.PrimarySettlementResult memory);
    function nativeCustodyFactsHash(bytes32 settlementKey) external view returns (bytes32);
}
