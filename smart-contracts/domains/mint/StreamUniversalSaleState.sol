// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../interfaces/stream/mint/IStreamUniversalFixedPriceSaleAdapter.sol";
import "../../vendor/openzeppelin/Ownable.sol";
import "../../vendor/openzeppelin/ReentrancyGuard.sol";
/// @dev Original owner, reentrancy and sale storage prefix, before additive gas/refund state.
abstract contract StreamUniversalSaleState is Ownable, ReentrancyGuard {
    uint256 public nextSaleNonce = 1;
    bool public paused;
    mapping(bytes32 => IStreamUniversalFixedPriceSaleAdapter.SaleRecord) internal _sales;
    mapping(address => mapping(bytes32 => bool)) public authorizationUsed;
    mapping(bytes32 => mapping(uint256 => bytes32)) public executionIdByNonce;
    mapping(bytes32 => uint8) public executionStatus;
}
