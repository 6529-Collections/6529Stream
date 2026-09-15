// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../smart-contracts/interfaces/stream/revenue/IStreamRevenueEscrow.sol";
import "./GovernedParameterTestMocks.sol";

/// @dev Target-side scheduled-execution seam; does not model Executor role or time admission.
contract EscrowCallbackAuthority is MockGovernedParameterAuthority {
    constructor() MockGovernedParameterAuthority(true) { }

    function execute(address target, bytes calldata data) external {
        (bool ok, bytes memory result) = target.call(data);
        if (!ok) assembly ("memory-safe") { revert(add(result, 32), mload(result)) }
    }
}

/// @dev State-controlled hostile ERC20; ordinary credit path is exact before flush faults activate.
contract EscrowFaultToken {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    uint8 public mode;

    function mint(address who, uint256 amount) external {
        balanceOf[who] += amount;
    }

    function configure(uint8 value) external {
        mode = value;
    }

    function approve(address who, uint256 amount) external returns (bool) {
        allowance[msg.sender][who] = amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        uint8 selected = mode;
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            calldatacopy(ptr, calldatasize(), 65536)
            mstore(ptr, 17)
            if eq(selected, 1) { revert(ptr, 65536) }
            if eq(selected, 2) { return(ptr, 65536) }
            if eq(selected, 3) { for { } 1 { } { } }
        }
        return true;
    }
}

/// @dev Deposit fault seam, not an official factory/wallet deployment proof.
contract EscrowDepositWallet {
    address public immutable factory;
    bytes32 public constant profileId = bytes32(uint256(1));
    uint8 public mode;
    uint256 public entryGas;
    IStreamRevenueEscrow public escrow;
    bytes32 public revenueClass;
    bool public sawZero;

    constructor() {
        factory = msg.sender;
    }

    function configure(uint8 value, IStreamRevenueEscrow escrow_, bytes32 class_) external {
        mode = value;
        escrow = escrow_;
        revenueClass = class_;
    }

    receive() external payable {
        entryGas = gasleft();
        sawZero = escrow.escrowOwed(revenueClass, profileId, address(this), address(0)) == 0
            && escrow.totalOwed(address(0)) == 0;
        uint8 selected = mode;
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            calldatacopy(ptr, calldatasize(), 65536)
            mstore(ptr, 17)
            if eq(selected, 1) { revert(ptr, 65536) }
            if eq(selected, 2) { return(ptr, 65536) }
            if eq(selected, 3) { for { } 1 { } { } }
        }
    }
}

contract EscrowDepositFactory {
    address public immutable governanceAuthority;
    address public immutable assetPolicyRegistry;
    EscrowDepositWallet public immutable wallet;

    constructor(address authority, address registry) {
        governanceAuthority = authority;
        assetPolicyRegistry = registry;
        wallet = new EscrowDepositWallet();
    }

    function splitWalletRuntimeCodeHash() external view returns (bytes32) {
        return address(wallet).codehash;
    }

    function splitWalletInitCodeHash() external pure returns (bytes32) {
        return bytes32(uint256(1));
    }

    function gasParameter(bytes32) external pure returns (uint256) {
        return 300_000;
    }

    function profileExists(bytes32 id) external pure returns (bool) {
        return id == bytes32(uint256(1));
    }

    function walletFor(bytes32) external view returns (address) {
        return address(wallet);
    }

    function splitWalletExists(bytes32) external pure returns (bool) {
        return true;
    }
}
