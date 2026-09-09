// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../smart-contracts/integrations/chainlink/IVRFCoordinatorV2Plus.sol";

interface MockVRFV25Consumer {
    function rawFulfillRandomWords(uint256 requestId, uint256[] calldata words) external;
}

/// @notice Local-only replacement for the external Chainlink service, preserving its ABI/gas cap.
contract MockVRFCoordinatorV2Plus is IVRFCoordinatorV2Plus {
    uint256 public nextRequestId = 1;
    RandomWordsRequest private _lastRequest;
    mapping(uint256 => address) public consumers;
    mapping(uint256 => uint32) public submittedCallbackGas;

    function requestRandomWords(RandomWordsRequest calldata request) external returns (uint256 id) {
        require(request.numWords == 1, "single VRF word");
        require(request.extraArgs.length == 36, "v2.5 extraArgs length");
        require(bytes4(request.extraArgs[:4]) == 0x92fd1338, "v2.5 extraArgs tag");
        abi.decode(request.extraArgs[4:], (bool));
        id = nextRequestId++;
        _lastRequest = request;
        consumers[id] = msg.sender;
        submittedCallbackGas[id] = request.callbackGasLimit;
    }

    function lastRequest() external view returns (RandomWordsRequest memory) {
        return _lastRequest;
    }

    function setNextRequestId(uint256 id) external {
        nextRequestId = id;
    }

    function fulfill(uint256 id, uint256 word) external returns (bool success, uint256 gasUsed) {
        uint256[] memory words = new uint256[](1);
        words[0] = word;
        return _fulfill(consumers[id], id, words, submittedCallbackGas[id]);
    }

    function fulfillTo(address consumer, uint256 id, uint256[] memory words, uint32 callbackGas)
        external
        returns (bool success, uint256 gasUsed)
    {
        return _fulfill(consumer, id, words, callbackGas);
    }

    function _fulfill(address consumer, uint256 id, uint256[] memory words, uint32 callbackGas)
        private
        returns (bool success, uint256 gasUsed)
    {
        bytes memory data = abi.encodeCall(MockVRFV25Consumer.rawFulfillRandomWords, (id, words));
        uint256 start = gasleft();
        (success,) = consumer.call{ gas: callbackGas }(data);
        gasUsed = start - gasleft();
    }
}
