// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Minimal VRF v2.5 subscription request ABI. No upstream ownership dependency.
/// @dev ABI source: Chainlink contracts-v1.3.0 VRFV2PlusClient / IVRFCoordinatorV2Plus.
/// https://github.com/smartcontractkit/chainlink/tree/contracts-v1.3.0/contracts/src/v0.8/vrf/dev
interface IVRFCoordinatorV2Plus {
    struct RandomWordsRequest {
        bytes32 keyHash;
        uint256 subId;
        uint16 requestConfirmations;
        uint32 callbackGasLimit;
        uint32 numWords;
        bytes extraArgs;
    }

    function requestRandomWords(RandomWordsRequest calldata request)
        external
        returns (uint256 requestId);
}
