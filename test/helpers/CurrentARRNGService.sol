// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../smart-contracts/domains/entropy/StreamEntropyProviderARRNG.sol";

/// @dev Only the external ARRNG service is simulated. Its custody and callback actors are Safes.
contract CurrentARRNGService {
    address public owner;
    address public immutable oracleAddress;
    uint64 public arrngRequestId;
    uint128 public constant minimumNativeToken = 100;
    mapping(uint256 => address) public requestAdapter;

    constructor(address owner_, address oracle_) {
        owner = owner_;
        oracleAddress = oracle_;
    }

    function transferOwnership(address next) external {
        require(msg.sender == owner && next != address(0), "upstream owner");
        owner = next;
    }

    function requestRandomWords(uint256 count, address refund)
        external
        payable
        returns (uint256 id)
    {
        require(
            count == 1 && refund == msg.sender && msg.value >= minimumNativeToken, "ARRNG request"
        );
        id = ++arrngRequestId;
        requestAdapter[id] = msg.sender;
        (bool ok,) = oracleAddress.call{ value: msg.value }("");
        require(ok, "oracle fee");
    }

    function deliver(uint256 id, uint256 word, uint256 refund) external {
        require(msg.sender == oracleAddress, "upstream oracle");
        uint256[] memory words = new uint256[](1);
        words[0] = word;
        IStreamEntropyProviderARRNG(requestAdapter[id]).receiveRandomness{ value: refund }(
            id, words
        );
    }
}
