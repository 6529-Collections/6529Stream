// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/revenue/StreamPrimarySettlementTypes.sol";

import "../../interfaces/stream/revenue/IStreamPinnedPermit2.sol";

/// @notice Linked implementation of the exact EIP-2612 and pinned Permit2 operations.
/// @dev Delegatecall preserves contract20 as spender/destination. The calling adapter checks
///      its active funding latch and live permit-policy/code/chain binding before entering.
///      No storage, approvals, owner, arbitrary selector or independent payer authorization.
library StreamPermitExecution {
    error PermitAuthorizationFailed();
    error InsufficientSettlementCallGas(uint256 cap);
    error SettlementReadFailed(address target, bytes4 selector);

    function permitEIP2612(
        address payer,
        address asset,
        uint256 amount,
        StreamPrimarySettlementTypes.EIP2612PermitAuthorization memory p,
        uint256 cap
    ) public {
        bytes memory nonceQuery = abi.encodeWithSignature("nonces(address)", payer);
        uint256 nonce = _read(asset, nonceQuery, cap);
        bytes memory data = abi.encodeWithSignature(
            "permit(address,address,uint256,uint256,uint8,bytes32,bytes32)",
            payer,
            address(this),
            amount,
            p.deadline,
            p.v,
            p.r,
            p.s
        );
        _call(asset, data, cap);
        if (
            _read(
                        asset,
                        abi.encodeWithSignature("allowance(address,address)", payer, address(this)),
                        cap
                    ) != amount || _read(asset, nonceQuery, cap) != nonce + 1
        ) revert PermitAuthorizationFailed();
    }

    function pull(
        address payer,
        address asset,
        uint256 amount,
        address permit2,
        uint8 allowanceMode,
        StreamPrimarySettlementTypes.Permit2TransferAuthorization memory p,
        uint256 cap
    ) public {
        bytes memory nonceQuery =
            abi.encodeCall(IStreamPinnedPermit2.nonceBitmap, (payer, p.nonce >> 8));
        uint256 bitmap = _read(permit2, nonceQuery, cap);
        uint256 bit = uint256(1) << (p.nonce & 255);
        bytes memory allowanceQuery =
            abi.encodeWithSignature("allowance(address,address)", payer, permit2);
        uint256 approval = _read(asset, allowanceQuery, cap);
        if (bitmap & bit != 0 || approval < amount) revert PermitAuthorizationFailed();
        _call(permit2, _permit2Data(payer, asset, amount, p), cap);
        uint256 expectedApproval =
            approval == type(uint256).max && allowanceMode == 2 ? approval : approval - amount;
        if (
            _read(permit2, nonceQuery, cap) != (bitmap | bit)
                || _read(asset, allowanceQuery, cap) != expectedApproval
        ) revert PermitAuthorizationFailed();
    }

    function _permit2Data(
        address payer,
        address asset,
        uint256 amount,
        StreamPrimarySettlementTypes.Permit2TransferAuthorization memory p
    ) private view returns (bytes memory) {
        IStreamPinnedPermit2.PermitTransferFrom memory permit =
            IStreamPinnedPermit2.PermitTransferFrom(
                IStreamPinnedPermit2.TokenPermissions(asset, amount), p.nonce, p.deadline
            );
        IStreamPinnedPermit2.SignatureTransferDetails memory details =
            IStreamPinnedPermit2.SignatureTransferDetails(address(this), amount);
        return abi.encodeCall(
            IStreamPinnedPermit2.permitTransferFrom, (permit, details, payer, p.signature)
        );
    }

    function _call(address target, bytes memory data, uint256 cap) private {
        _admitGas(cap);
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := call(cap, target, 0, add(data, 32), mload(data), 0, 0)
            size := returndatasize()
        }
        if (!ok || size != 0) revert PermitAuthorizationFailed();
    }

    function _read(address target, bytes memory data, uint256 cap)
        private
        view
        returns (uint256 word)
    {
        _admitGas(cap);
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(data, 32), mload(data), 0, 32)
            size := returndatasize()
            word := mload(0)
        }
        if (!ok || size != 32) revert SettlementReadFailed(target, bytes4(data));
    }

    function _admitGas(uint256 cap) private view {
        uint256 available = gasleft();
        if (cap > available || available - cap < cap / 63 + (cap % 63 == 0 ? 0 : 1) + 40_000) {
            revert InsufficientSettlementCallGas(cap);
        }
    }
}
