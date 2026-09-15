// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamRevenueEscrow } from "./StreamRevenueEscrow.sol";
import { StreamEscrowRecoveryState as S } from "./StreamEscrowRecoveryState.sol";
import { StreamEscrowRecoveryGovernance as Governance } from "./StreamEscrowRecoveryGovernance.sol";
import { StreamEscrowRecoveryProof as Proof } from "./StreamEscrowRecoveryProof.sol";
import {
    StreamEscrowRecoveryTypes as R
} from "../../interfaces/stream/revenue/StreamEscrowRecoveryTypes.sol";
import {
    IStreamRevenueEscrowRecoveryManifest as M
} from "../../interfaces/stream/revenue/IStreamRevenueEscrowRecoveryManifest.sol";
import {
    IStreamRevenueEscrow as E
} from "../../interfaces/stream/revenue/IStreamRevenueEscrow.sol";
import { IStreamSplitFactory as F } from "../../interfaces/stream/revenue/IStreamSplitFactory.sol";
import { IStreamSplitWallet as W } from "../../interfaces/stream/revenue/IStreamSplitWallet.sol";
import {
    IStreamGasParameterHost as G
} from "../../interfaces/stream/parameters/IStreamGasParameterHost.sol";
import { IERC20 } from "../../interfaces/standards/IERC20.sol";

/// @notice Fixed incident execution over the host's original Credit/totalOwed storage.
/// @dev Host holds the original nonReentrant guard. Every failure restores both ledgers,
///      consent facts, recovery status and any attempted callback/governance mutation.
library StreamEscrowRecoveryExecution {
    bytes32 private constant DEPOSIT_GAS = keccak256("6529STREAM_GGP_WALLET_DEPOSIT_GAS_LIMIT");
    event EscrowRecoveryExecuted(
        uint16 schemaVersion,
        bytes32 indexed recoveryId,
        bytes32 indexed revenueClass,
        bytes32 indexed profileId,
        address oldWallet,
        address successorWallet,
        uint256 movedAmount,
        bytes32 recoveryManifestContentHash,
        bytes32 reasonHash,
        string reasonURI
    );

    function execute(
        mapping(bytes32 => StreamRevenueEscrow.Credit) storage credits,
        mapping(address => uint256) storage totalOwed,
        S.Context memory c,
        bytes32 id
    ) public {
        M.ManifestDocument memory d = Governance.requireExecution(c, id);
        S.Recovery storage item = S.state().recoveries[id];
        R.EscrowRecoveryRecord storage p = item.record;
        StreamRevenueEscrow.Credit storage credit = credits[S.keyHash(d.creditKey)];
        uint256 amount = credit.amount;
        if (amount != p.expectedAmount || credit.factory != p.storedFactory) {
            revert S.InvalidEscrowRecoveryState(id);
        }
        uint256 cap = G(address(this)).gasParameter(DEPOSIT_GAS);
        address asset = p.creditKey.asset;
        uint256 beforeBalance =
            asset == address(0) ? address(this).balance : _balance(asset, address(this), cap);
        if (beforeBalance < totalOwed[asset]) {
            revert E.EscrowInsolvent(asset, beforeBalance, totalOwed[asset]);
        }
        credit.amount = 0;
        totalOwed[asset] -= amount;
        p.status = R.EscrowRecoveryStatus.EXECUTED;

        _deployAndVerify(d, cap);
        if (asset == address(0)) {
            uint256 walletBefore = d.successorWallet.balance;
            _native(d.successorWallet, amount, cap);
            // Forced ETH is surplus. A callback donation does not erase this owed debit
            // or invalidate otherwise authorized recovery.
            if (
                d.successorWallet.balance < walletBefore + amount
                    || address(this).balance < beforeBalance - amount
            ) {
                revert E.EscrowTransferInvariantBroken(asset);
            }
        } else {
            uint256 walletBefore = _balance(asset, d.successorWallet, cap);
            if (
                _callWord(asset, abi.encodeCall(IERC20.transfer, (d.successorWallet, amount)), cap)
                    != 1
            ) {
                revert E.EscrowTransferInvariantBroken(asset);
            }
            if (
                _balance(asset, address(this), cap) != beforeBalance - amount
                    || _balance(asset, d.successorWallet, cap) != walletBefore + amount
            ) {
                revert E.EscrowTransferInvariantBroken(asset);
            }
        }
        Proof.validateAfter(c, d);
        if (d.route == 1) {
            Governance.requireConsents(id, S.state().manifests[p.recoveryManifest.contentHash]);
        }
        if (p.status != R.EscrowRecoveryStatus.EXECUTED || Governance.identifier(p) != id) {
            revert S.InvalidEscrowRecoveryState(id);
        }
        uint256 remainingBalance =
            asset == address(0) ? address(this).balance : _balance(asset, address(this), cap);
        if (remainingBalance < totalOwed[asset]) {
            revert E.EscrowInsolvent(asset, remainingBalance, totalOwed[asset]);
        }
        emit EscrowRecoveryExecuted(
            1,
            id,
            p.creditKey.revenueClass,
            p.creditKey.profileId,
            p.creditKey.wallet,
            p.successorWallet,
            amount,
            p.recoveryManifest.contentHash,
            p.reasonHash,
            p.reasonURI
        );
    }

    function _deployAndVerify(M.ManifestDocument memory d, uint256 cap) private {
        if (d.successorWallet.code.length == 0) {
            uint256 available = gasleft();
            if (available <= 100_000 || cap > (available - 100_000) / 6) {
                revert E.InsufficientEscrowCallGas(cap, available, 100_000);
            }
            uint256 deployGas = gasleft() - (cap * 6 + 100_000);
            deployGas -= deployGas / 64;
            if (
                _callWord(
                        d.successorFactory,
                        abi.encodeCall(F.deployWallet, (d.successorProfileId)),
                        deployGas
                    ) != uint256(uint160(d.successorWallet))
            ) {
                revert E.EscrowWalletMismatch(d.successorProfileId, d.successorWallet);
            }
        }
        if (
            d.successorWallet.codehash != d.successorRuntimeCodeHash
                || Proof.word(
                        d.successorFactory,
                        abi.encodeCall(F.splitWalletExists, (d.successorProfileId)),
                        cap
                    ) != 1
                || Proof.word(d.successorWallet, abi.encodeCall(W.factory, ()), cap)
                    != uint256(uint160(d.successorFactory))
                || bytes32(Proof.word(d.successorWallet, abi.encodeCall(W.profileId, ()), cap))
                    != d.successorProfileId
        ) {
            revert E.EscrowWalletMismatch(d.successorProfileId, d.successorWallet);
        }
    }

    function _balance(address asset, address account, uint256 cap) private view returns (uint256) {
        return Proof.word(asset, abi.encodeCall(IERC20.balanceOf, (account)), cap);
    }

    function _callWord(address target, bytes memory data, uint256 cap)
        private
        returns (uint256 word)
    {
        _gas(cap);
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            ok := call(cap, target, 0, add(data, 32), mload(data), ptr, 32)
            size := returndatasize()
            word := mload(ptr)
        }
        if (!ok || size != 32) _failed(target, bytes4(data), size);
    }

    function _native(address target, uint256 amount, uint256 cap) private {
        _gas(cap);
        if (cap < 2300) revert E.InsufficientEscrowCallGas(cap, gasleft(), 2300);
        uint256 forwarded = cap - 2300;
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := call(forwarded, target, amount, 0, 0, 0, 0)
            size := returndatasize()
        }
        if (!ok) _failed(target, 0, size);
    }

    function _gas(uint256 cap) private view {
        uint256 available = gasleft();
        if (cap > available || available - cap < cap / 63 + (cap % 63 == 0 ? 0 : 1) + 30_000) {
            revert E.InsufficientEscrowCallGas(cap, available, 30_000);
        }
    }

    function _failed(address target, bytes4 selector, uint256 size) private pure {
        uint256 length = size > 256 ? 256 : size;
        bytes memory prefix = new bytes(length);
        assembly ("memory-safe") { returndatacopy(add(prefix, 32), 0, length) }
        revert E.EscrowExternalCallFailed(target, selector, size, prefix);
    }
}
