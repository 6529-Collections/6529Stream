// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamSettlementAdmission.sol";
import "../mint/StreamSaleTemplate.sol";
import "../../interfaces/stream/revenue/IStreamRevenueEscrow.sol";
import "../../interfaces/stream/revenue/IStreamSplitFactory.sol";

/// @notice Linked native funding/signature operations with no mutable state or ownership.
/// @dev Delegatecall preserves the actual consumer/recorder. No arbitrary selector is exposed.
library StreamNativeSettlementSupport {
    error NativeSettlementBindingInvalid(address target);
    error NativeSettlementAmountMismatch();
    error NativeSettlementEscrowMismatch();
    error InvalidNativeRights();
    error InsufficientSettlementCallGas(uint256 cap);

    function gasParameter(IStreamSplitFactory factory, bytes32 factoryHash, bytes32 id)
        public
        view
        returns (uint256 cap)
    {
        if (address(factory).codehash != factoryHash) {
            revert NativeSettlementBindingInvalid(address(factory));
        }
        bytes memory data = abi.encodeCall(IStreamGasParameterHost.gasParameter, (id));
        bool ok;
        uint256 size;
        address target = address(factory);
        assembly ("memory-safe") {
            ok := staticcall(gas(), target, add(data, 32), mload(data), 0, 32)
            size := returndatasize()
            cap := mload(0)
        }
        if (!ok || size != 32 || cap == 0 || cap > type(uint64).max) {
            revert NativeSettlementBindingInvalid(target);
        }
    }

    function rights(IStreamRevenueResolver resolver, uint256 collectionId)
        public
        view
        returns (StreamSaleTemplate.Selection memory selected)
    {
        IStreamRevenueResolver.ResolvedPrimaryAssignment memory a =
            resolver.resolvePrimaryAssignment(collectionId, 0, keccak256("PRIMARY_SALE"));
        if (a.assignmentType == 2) return StreamSaleTemplate.preview(resolver, collectionId, a);
        IStreamSplitFactory factory = IStreamSplitFactory(resolver.splitFactory());
        if (
            !a.exists || a.assignmentType != 1 || a.scope != 1 || a.scopeId != collectionId
                || a.templateId != 0 || a.profileId == 0 || a.assignmentHash == 0
                || a.policyHash != 0 || !factory.splitWalletExists(a.profileId)
        ) revert InvalidNativeRights();
        return StreamSaleTemplate.Selection(
            a.profileId,
            factory.walletFor(a.profileId),
            0,
            a.assignmentHash,
            factory.profileEntriesHash(a.profileId)
        );
    }

    function requireCurrent(
        IStreamRevenueResolver resolver,
        uint256 collectionId,
        StreamSaleTemplate.Selection memory selected
    ) public view {
        if (selected.templateId != 0) {
            StreamSaleTemplate.requireCurrent(resolver, collectionId, selected);
        } else if (
            keccak256(abi.encode(rights(resolver, collectionId))) != keccak256(abi.encode(selected))
        ) {
            revert InvalidNativeRights();
        }
        IStreamSplitFactory factory = IStreamSplitFactory(resolver.splitFactory());
        if (
            !factory.profileExists(selected.profileId)
                || factory.walletFor(selected.profileId) != selected.wallet
                || (selected.wallet.code.length == 0 && selected.templateId == 0)
                || (selected.wallet.code.length != 0
                    && (!factory.splitWalletExists(selected.profileId)
                        || selected.wallet.codehash != factory.splitWalletRuntimeCodeHash()))
        ) revert InvalidNativeRights();
    }

    function fundNative(
        IStreamRevenueEscrow escrow,
        bytes32 escrowHash,
        StreamSaleTemplate.Selection memory selected,
        uint256 amount,
        uint256 cap
    ) public returns (bool escrowed) {
        uint256 original = address(this).balance;
        uint256 walletBefore = selected.wallet.balance;
        bool ok;
        uint256 size;
        if (selected.wallet.code.length != 0) {
            _admitGas(cap);
            if (cap < 2300) revert InsufficientSettlementCallGas(cap);
            uint256 forwarded = cap - 2300;
            address wallet = selected.wallet;
            assembly ("memory-safe") {
                ok := call(forwarded, wallet, amount, 0, 0, 0, 0)
                size := returndatasize()
            }
        }
        if (ok) {
            if (
                size != 0 || selected.wallet.balance != walletBefore + amount
                    || address(this).balance != original - amount
            ) revert NativeSettlementAmountMismatch();
            return false;
        }
        if (address(escrow).codehash != escrowHash) {
            revert NativeSettlementBindingInvalid(address(escrow));
        }
        uint256 beforeEscrow = address(escrow).balance;
        uint256 owed = escrow.escrowOwed(
            keccak256("PRIMARY_SALE"), selected.profileId, selected.wallet, address(0)
        );
        escrow.creditNative{ value: amount }(
            keccak256("PRIMARY_SALE"), selected.profileId, selected.wallet, selected.templateId != 0
        );
        if (
            address(this).balance != original - amount || selected.wallet.balance != walletBefore
                || address(escrow).balance != beforeEscrow + amount
                || escrow.escrowOwed(
                        keccak256("PRIMARY_SALE"), selected.profileId, selected.wallet, address(0)
                    ) != owed + amount
        ) revert NativeSettlementEscrowMismatch();
        return true;
    }

    function _admitGas(uint256 cap) private view {
        uint256 available = gasleft();
        if (cap > available || available - cap < cap / 63 + (cap % 63 == 0 ? 0 : 1) + 40000) {
            revert InsufficientSettlementCallGas(cap);
        }
    }

    function validSignature(address signer, bytes32 digest, bytes memory signature, uint256 cap)
        public
        view
        returns (bool)
    {
        if (signer == address(0)) return false;
        if (signer.code.length == 0 || !StreamSettlementAdmission.isContract(signer)) {
            bytes32 r;
            bytes32 s;
            uint8 v;
            if (signature.length == 65) {
                assembly ("memory-safe") {
                    r := mload(add(signature, 32))
                    s := mload(add(signature, 64))
                    v := byte(0, mload(add(signature, 96)))
                }
            } else if (signature.length == 64) {
                bytes32 vs;
                assembly ("memory-safe") {
                    r := mload(add(signature, 32))
                    vs := mload(add(signature, 64))
                }
                s = vs & bytes32(type(uint256).max >> 1);
                v = uint8(uint256(vs) >> 255) + 27;
            }
            if (
                uint256(s) <= 0x7fffffffffffffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a0
                    && (v == 27 || v == 28) && ecrecover(digest, v, r, s) == signer
            ) return true;
            if (signer.code.length == 0) return false;
        }
        bytes memory data = abi.encodeWithSelector(bytes4(0x1626ba7e), digest, signature);
        _admitGas(cap);
        bool ok;
        uint256 size;
        uint256 word;
        assembly ("memory-safe") {
            ok := staticcall(cap, signer, add(data, 32), mload(data), 0, 32)
            size := returndatasize()
            word := mload(0)
        }
        return ok && size == 32 && word == uint256(uint32(0x1626ba7e)) << 224;
    }
}
