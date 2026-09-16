// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    IStreamImmediateSaleReveal as R
} from "../../interfaces/stream/mint/IStreamImmediateSaleReveal.sol";
import {
    IStreamNativeSaleCredits as C
} from "../../interfaces/stream/mint/IStreamNativeSaleCredits.sol";
import { StreamImmediateSaleReveal } from "./StreamImmediateSaleReveal.sol";

/// @notice Free burn program reveal allowances and perpetual caller-owned credits.
/// @dev The guarded gate supplies this appended book and immutable Core. No live admission
///      dependency is consulted when an earned credit is read or claimed.
library StreamBurnMintCredits {
    struct State {
        mapping(bytes32 => uint256) targetByProgram;
        mapping(bytes32 => mapping(address => uint256)) refunds;
        mapping(bytes32 => mapping(address => bool)) seen;
        bytes32[] programs;
        address[] accounts;
        uint256 liability;
    }

    event SalePaymentExcessCredited(
        uint16 schemaVersion, bytes32 indexed saleId, address indexed payer, uint256 amount
    );
    event NativeSaleCreditAccountIndexed(
        uint16 schemaVersion, uint256 indexed index, bytes32 indexed saleId, address indexed account
    );
    event SaleRefundClaimed(
        uint16 schemaVersion,
        bytes32 indexed saleId,
        address indexed payer,
        address indexed recipient,
        uint256 amount
    );

    function credit(State storage s, bytes32 program, address funder, uint256 excess) external {
        if (excess == 0) return;
        if (program == 0 || funder == address(0) || s.targetByProgram[program] == 0) {
            revert R.SaleRevealAccountingMismatch();
        }
        if (!s.seen[program][funder]) {
            s.seen[program][funder] = true;
            s.programs.push(program);
            s.accounts.push(funder);
            emit NativeSaleCreditAccountIndexed(1, s.accounts.length - 1, program, funder);
        }
        s.refunds[program][funder] += excess;
        s.liability += excess;
        if (address(this).balance < s.liability) revert R.SaleRevealAccountingMismatch();
        emit SalePaymentExcessCredited(1, program, funder, excess);
    }

    function claim(State storage s, bytes32 program, address account, address recipient) external {
        uint256 amount = s.refunds[program][account];
        if (amount == 0) revert R.SaleRefundEmpty(program, account);
        if (recipient == address(0) || recipient == address(this)) {
            revert R.SaleRefundTransferFailed(recipient);
        }
        uint256 beforeBalance = address(this).balance;
        if (beforeBalance < s.liability) revert R.SaleRevealAccountingMismatch();
        s.refunds[program][account] = 0;
        s.liability -= amount;
        bool ok;
        assembly ("memory-safe") { ok := call(gas(), recipient, amount, 0, 0, 0, 0) }
        if (!ok) revert R.SaleRefundTransferFailed(recipient);
        if (address(this).balance < beforeBalance - amount || address(this).balance < s.liability) {
            revert R.SaleRevealAccountingMismatch();
        }
        emit SaleRefundClaimed(1, program, account, recipient, amount);
    }

    function read(State storage s, address core, bytes calldata data)
        external
        view
        returns (bytes memory)
    {
        bytes4 selector = bytes4(data[:4]);
        if (selector == R.refundLiability.selector) return abi.encode(s.liability);
        if (selector == R.refundAccountCount.selector) return abi.encode(s.accounts.length);
        if (selector == R.refundAccountAt.selector) {
            uint256 index = abi.decode(data[4:], (uint256));
            return abi.encode(s.programs[index], s.accounts[index]);
        }
        if (selector == R.refundableBalance.selector) {
            (bytes32 program, address account) = abi.decode(data[4:], (bytes32, address));
            return abi.encode(s.refunds[program][account]);
        }
        if (selector == R.saleRevealQuote.selector) {
            bytes32 program = abi.decode(data[4:], (bytes32));
            uint256 target = s.targetByProgram[program];
            if (target == 0) revert R.SaleRevealDependencyInvalid(address(this));
            return abi.encode(StreamImmediateSaleReveal.quote(core, target));
        }
        if (selector == C.nativeSaleCreditState.selector) {
            return abi.encode(C.CreditState(s.accounts.length, s.liability, address(this).balance));
        }
        if (selector == C.nativeSaleCreditPage.selector) {
            (uint256 index, uint256 cursor, uint256 limit) =
                abi.decode(data[4:], (uint256, uint256, uint256));
            if (index >= s.accounts.length || cursor != 0 || limit == 0 || limit > 64) {
                revert C.NativeSaleCreditPageInvalid();
            }
            bytes32 program = s.programs[index];
            address account = s.accounts[index];
            uint256 owed = s.refunds[program][account];
            return abi.encode(C.CreditPage(program, account, owed, owed, 0));
        }
        revert C.NativeSaleCreditPageInvalid();
    }
}
