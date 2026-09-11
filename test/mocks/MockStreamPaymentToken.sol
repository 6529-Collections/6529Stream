// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice ERC-20 payment fixture with explicitly selected nonstandard transfer/read behavior.
contract MockStreamPaymentToken {
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) public allowance;
    uint8 public mode;
    uint8 public failingLeg;
    address public callbackTarget;
    bytes public callbackData;
    bool public callbackSucceeded;
    uint8 public callbackLeg;
    uint256 public transferCalls;

    function mint(address account, uint256 amount) external {
        _balances[account] += amount;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function configure(uint8 mode_, uint8 leg) external {
        mode = mode_;
        failingLeg = leg;
    }

    function configureCallback(address target, bytes calldata data, uint8 leg) external {
        callbackTarget = target;
        callbackData = data;
        callbackLeg = leg;
    }

    function balanceOf(address account) external view returns (uint256) {
        if (mode == 7) revert("unavailable balance");
        if (mode == 8) {
            assembly {
                mstore(0, 1)
                return(0, 31)
            }
        }
        if (mode == 9) {
            assembly {
                mstore(0, 1)
                return(0, 64)
            }
        }
        return _balances[account];
    }

    function rawBalance(address account) external view returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        return _transfer(msg.sender, to, amount, 2);
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 approved = allowance[from][msg.sender];
        require(approved >= amount, "allowance");
        allowance[from][msg.sender] = approved - amount;
        return _transfer(from, to, amount, 1);
    }

    function _transfer(address from, address to, uint256 amount, uint8 leg) private returns (bool) {
        transferCalls++;
        uint8 selected = failingLeg == 0 || failingLeg == leg ? mode : 0;
        if (selected == 1) return false;
        if (selected == 2) return true; // no-op token
        require(_balances[from] >= amount, "balance");
        _balances[from] -= amount;
        _balances[to] += selected == 3 ? amount - 1 : amount;
        if (selected == 4) _balances[from] += 1; // positive sender rebase during transfer
        if (callbackTarget != address(0) && (callbackLeg == 0 || callbackLeg == leg)) {
            (callbackSucceeded,) = callbackTarget.call(callbackData);
        }
        if (selected == 5) assembly { return(0, 0) }
        if (selected == 6) {
            assembly {
                mstore(0, 2)
                return(0, 32)
            }
        }
        return true;
    }
}
