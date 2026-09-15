// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/revenue/IStreamClaimRouter.sol";
import "../../interfaces/stream/revenue/IStreamSplitWallet.sol";

/// @notice Permissionless, noncustodial split-wallet claim aggregation.
/// @dev No storage, owner, approvals, receive or fallback function. Wallets enforce entitlement
/// and payment accounting. Reentry cannot redirect a release or spend router funds or approvals.
contract StreamClaimRouter is IStreamClaimRouter {
    uint256 private constant _MAX_REASON_BYTES = 256;

    /// @inheritdoc IStreamClaimRouter
    function claimMany(ClaimCall[] calldata claims, bool continueOnFailure)
        external
        override
        returns (uint256[] memory releasedAmounts)
    {
        return _claim(claims, continueOnFailure, false);
    }

    /// @inheritdoc IStreamClaimRouter
    function syncAndClaimMany(ClaimCall[] calldata claims, bool continueOnFailure)
        external
        override
        returns (uint256[] memory releasedAmounts)
    {
        return _claim(claims, continueOnFailure, true);
    }

    function _claim(ClaimCall[] calldata claims, bool keepGoing, bool sync)
        private
        returns (uint256[] memory amounts)
    {
        amounts = new uint256[](claims.length);
        for (uint256 i; i < claims.length; ++i) {
            ClaimCall calldata item = claims[i];
            // Recompute from the remaining work so skipped releases do not retain a gas share.
            uint256 remaining = (claims.length - i) * (sync ? 2 : 1);
            if (sync) {
                (bool synced,) = _invoke(
                    item,
                    i,
                    IStreamSplitWallet.syncAsset.selector,
                    abi.encodeCall(IStreamSplitWallet.syncAsset, (item.asset)),
                    keepGoing,
                    remaining
                );
                if (!synced) continue;
                --remaining;
            }
            (, amounts[i]) = _invoke(
                item,
                i,
                IStreamSplitWallet.release.selector,
                abi.encodeCall(
                    IStreamSplitWallet.release, (item.asset, item.account, payable(item.account))
                ),
                keepGoing,
                remaining
            );
        }
    }

    function _invoke(
        ClaimCall calldata item,
        uint256 index,
        bytes4 operation,
        bytes memory input,
        bool keepGoing,
        uint256 remaining
    ) private returns (bool valid, uint256 amount) {
        bool success;
        uint256 size;
        bytes memory reason;
        if (item.wallet.code.length == 0) {
            reason = abi.encodeWithSelector(ClaimTargetHasNoCode.selector, item.wallet);
        } else {
            // Continue mode shares current gas across remaining external calls plus one router
            // share. There is no fixed stipend. An underfunded whole transaction can still fail.
            uint256 callGas = keepGoing ? gasleft() / (remaining + 1) : gasleft();
            address wallet = item.wallet;
            assembly ("memory-safe") {
                // Copy at most one word, even if the callee returns a large successful payload.
                success := call(callGas, wallet, 0, add(input, 32), mload(input), 0, 32)
                size := returndatasize()
                amount := mload(0)
            }
            if (success && size == 32) return (true, amount);
            if (success) {
                reason = abi.encodeWithSelector(InvalidClaimReturnData.selector, size);
            } else {
                uint256 length = size > _MAX_REASON_BYTES ? _MAX_REASON_BYTES : size;
                reason = new bytes(length);
                assembly ("memory-safe") {
                    returndatacopy(add(reason, 32), 0, length)
                }
            }
        }
        if (!keepGoing) revert ClaimCallFailed(index, item.wallet, operation, size, reason);
        emit ClaimFailed(item.wallet, item.asset, item.account, 1, index, operation, size, reason);
        return (false, 0);
    }
}
