// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamPrimarySettlementRights.sol";
import "../../interfaces/stream/revenue/IStreamPrimarySaleSettlement.sol";
import "../../interfaces/stream/revenue/IStreamRevenueEscrow.sol";
import "../../interfaces/standards/IERC20.sol";

/// @notice Fixed linked ERC20 route; preserves exact failed-CALL-only fallback and transfer accounting.
/// @dev Copied from the recorder/context without changing contract20 or its allowance boundary.
library StreamPrimaryTokenRouting {
    bytes32 private constant _CLASS = keccak256("PRIMARY_SALE");

    struct Context {
        StreamPrimarySettlementRights.Context rights;
        IStreamRevenueEscrow escrow;
        bytes32 escrowHash;
    }
    error InvalidSettlementContext(address target);
    error InsufficientSettlementCallGas(uint256 requiredCap);
    error SettlementReadFailed(address target, bytes4 selector);
    error SettlementTokenCallFailed(address target, bytes4 selector);
    error SettlementAmountMismatch(address asset);
    error PrimarySettlementEscrowMismatch();

    function route(
        Context memory x,
        StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c,
        StreamSaleTemplate.Selection memory rights,
        uint256 cap
    ) public returns (bool escrowed) {
        StreamPrimarySettlementRights.requireWallet(x.rights, rights);
        if (
            rights.wallet.code.length != 0
                && _transfer(c.asset, rights.wallet, c.sale.amount, cap, true)
        ) return false;
        if (address(x.escrow).codehash != x.escrowHash) {
            revert InvalidSettlementContext(address(x.escrow));
        }
        uint256 beforeEscrow = _balance(c.asset, address(x.escrow), cap);
        uint256 beforeWallet = _balance(c.asset, rights.wallet, cap);
        uint256 owed = x.escrow.escrowOwed(_CLASS, rights.profileId, rights.wallet, c.asset);
        if (_allowance(c.asset, address(this), address(x.escrow), cap) != 0) {
            revert PrimarySettlementEscrowMismatch();
        }
        _tokenCall(
            c.asset, abi.encodeCall(IERC20.approve, (address(x.escrow), c.sale.amount)), cap, false
        );
        if (_allowance(c.asset, address(this), address(x.escrow), cap) != c.sale.amount) {
            revert PrimarySettlementEscrowMismatch();
        }
        x.escrow
            .creditERC20(
                _CLASS,
                rights.profileId,
                rights.wallet,
                c.asset,
                c.sale.amount,
                rights.templateId != 0
            );
        if (
            _allowance(c.asset, address(this), address(x.escrow), cap) != 0
                || _balance(c.asset, address(x.escrow), cap) != beforeEscrow + c.sale.amount
                || _balance(c.asset, rights.wallet, cap) != beforeWallet
                || x.escrow.escrowOwed(_CLASS, rights.profileId, rights.wallet, c.asset)
                    != owed + c.sale.amount
        ) {
            revert PrimarySettlementEscrowMismatch();
        }
        return true;
    }

    function _admitGas(uint256 cap) private view {
        uint256 available = gasleft();
        if (cap > available || available - cap < cap / 63 + (cap % 63 == 0 ? 0 : 1) + 40_000) {
            revert InsufficientSettlementCallGas(cap);
        }
    }

    /// @dev Callers admit bounded gas first, or use the exact-code infrastructure exception.
    function _read(address target, bytes memory data, uint256 cap)
        private
        view
        returns (uint256 word)
    {
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(data, 32), mload(data), 0, 32)
            size := returndatasize()
            word := mload(0)
        }
        if (!ok || size != 32) revert SettlementReadFailed(target, bytes4(data));
    }

    function _tokenRead(address asset, bytes memory data, uint256 cap)
        private
        view
        returns (uint256)
    {
        _admitGas(cap);
        return _read(asset, data, cap);
    }

    function _balance(address asset, address account, uint256 cap) private view returns (uint256) {
        return _tokenRead(asset, abi.encodeCall(IERC20.balanceOf, (account)), cap);
    }

    function _allowance(address asset, address owner, address spender, uint256 cap)
        private
        view
        returns (uint256)
    {
        return _tokenRead(asset, abi.encodeCall(IERC20.allowance, (owner, spender)), cap);
    }

    function _tokenCall(address asset, bytes memory data, uint256 cap, bool allowFailedCall)
        private
        returns (bool)
    {
        _admitGas(cap);
        bool ok;
        uint256 size;
        uint256 word;
        assembly ("memory-safe") {
            ok := call(cap, asset, 0, add(data, 32), mload(data), 0, 32)
            size := returndatasize()
            word := mload(0)
        }
        if (!ok && allowFailedCall) return false;
        if (!ok || size != 32 || word != 1) revert SettlementTokenCallFailed(asset, bytes4(data));
        return true;
    }

    function _transfer(address asset, address to, uint256 amount, uint256 cap, bool allowFailedCall)
        private
        returns (bool)
    {
        uint256 beforeSelf = _balance(asset, address(this), cap);
        uint256 beforeTo = _balance(asset, to, cap);
        if (beforeSelf < amount || to == address(this)) revert SettlementAmountMismatch(asset);
        bool ok =
            _tokenCall(asset, abi.encodeCall(IERC20.transfer, (to, amount)), cap, allowFailedCall);
        if (!ok) return false;
        if (
            _balance(asset, address(this), cap) != beforeSelf - amount
                || _balance(asset, to, cap) != beforeTo + amount
        ) {
            revert SettlementAmountMismatch(asset);
        }
        return true;
    }
}
