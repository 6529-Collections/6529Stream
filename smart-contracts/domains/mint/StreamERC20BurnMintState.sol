// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamERC20BurnMintSupport.sol";

/// @notice Original sale replay and the single transaction-local burn continuation, owned by the carrier.
library StreamERC20BurnMintState {
    struct Continuation {
        address gate;
        bytes32 executionHash;
        bytes32 executionId;
        bytes32 candidateHash;
        bytes32 resultHash;
        uint8 mode;
        bool paidExecution;
    }

    struct State {
        uint256 nextSaleNonce;
        bool paused;
        mapping(bytes32 => U.SaleRecord) sales;
        mapping(address => mapping(bytes32 => bool)) authorizationUsed;
        mapping(bytes32 => mapping(uint256 => bytes32)) executionIdByNonce;
        mapping(bytes32 => uint8) executionStatus;
        mapping(bytes32 => StreamERC20BurnMintSupport.GateBinding) saleBurnGate;
        Continuation active;
    }
}
