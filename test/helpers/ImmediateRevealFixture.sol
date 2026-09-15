// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../smart-contracts/interfaces/stream/entropy/IStreamRevealFeeEscrow.sol";

/// @dev Explicit policy/funding/provider boundary. Current-stack tests use the actual coordinator.
contract ImmediateRevealFixture {
    address public immutable core;
    IStreamRevealFeeEscrow.CollectionRevealPolicy private _policy;
    mapping(uint256 => uint256) public revealFeeEscrow;
    uint256 public lastRequestedToken;
    uint256 public requests;
    uint8 public fault;
    address public callback;
    bytes public callbackData;
    bool public callbackSucceeded;
    bytes public callbackReason;

    constructor(address value) {
        core = value;
        _policy = IStreamRevealFeeEscrow.CollectionRevealPolicy(
            true, 1, keccak256("ROLE_ENTROPY_REVEAL_OWNER"), 100, 0
        );
    }

    function collectionRevealPolicy(uint256)
        external
        view
        returns (IStreamRevealFeeEscrow.CollectionRevealPolicy memory)
    {
        return _policy;
    }

    function configure(bool declared, uint8 mode, uint256 fee, uint8 problem) external {
        _policy.declared = declared;
        _policy.requestMode = mode;
        _policy.revealFeePerTokenWei = fee;
        fault = problem;
    }

    function configureCallback(address target, bytes calldata data) external {
        callback = target;
        callbackData = data;
    }

    function fundRevealFeeEscrow(uint256 collectionId) external payable {
        if (fault != 5) revealFeeEscrow[collectionId] += msg.value;
    }

    function requestEntropy(uint256 tokenId) external payable returns (bytes32, uint256) {
        require(msg.value == 0, "fee already in escrow");
        if (fault == 1) revert("provider offline");
        if (fault == 2) assembly ("memory-safe") { revert(mload(0x40), 16384) }
        if (fault == 3) assembly ("memory-safe") { invalid() }
        if (fault == 4) {
            assembly ("memory-safe") {
                mstore(0, 1)
                return(0, 32)
            }
        }
        if (callback != address(0)) {
            (callbackSucceeded, callbackReason) = callback.call(callbackData);
        }
        lastRequestedToken = tokenId;
        ++requests;
        return (keccak256(abi.encode("immediate request", tokenId)), requests);
    }
}
