// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/core/IStreamCorePointers.sol";
import "../../interfaces/stream/modules/IStreamModuleRegistry.sol";
import "../../interfaces/stream/revenue/IStreamERC20PrimarySettlementAdapter.sol";
import "../../interfaces/stream/revenue/IStreamERC20SaleExecution.sol";
import "../../interfaces/stream/revenue/IStreamSaleLifecycleBinding.sol";

/// @notice Canonical registry admission and immutable creation binding, repeated by 9 and 20.
/// @dev Only exact-code trusted infrastructure gets available-gas fixed-buffer reads.
///      No external returndata is allocated or bubbled. See ADR 0019 implementation addendum.
library StreamSettlementAdmission {
    bytes32 internal constant VERSION = keccak256("6529STREAM_UNIVERSAL_SETTLEMENT_V1");
    bytes32 internal constant SALE_ROLE = keccak256("FIXED_PRICE_SALE_ADAPTER");
    bytes32 internal constant PAYMENT_ROLE = keccak256("ERC20_PRIMARY_SETTLEMENT_ADAPTER");
    bytes32 private constant _REGISTRY_ROLE = keccak256("MODULE_REGISTRY");

    struct ModuleFacts {
        uint8 status;
        uint64 registeredAt;
        uint64 statusUpdatedAt;
        uint64 revision;
    }

    error SettlementBindingInvalid(address target);
    error SettlementModuleReadFailed(address module);
    error SettlementModuleReadMalformed(address module, uint256 length);
    error SettlementModuleNotAdmitted(address module);
    error SaleLifecycleReadFailed(address saleAdapter);
    error SaleLifecycleReadMalformed(address saleAdapter, uint256 length);
    error SaleLifecycleMismatch(address saleAdapter, bytes32 saleId);

    function isContract(address target) internal view returns (bool) {
        uint256 size = target.code.length;
        if (size == 0) return false;
        if (size != 23) return true;
        uint256 prefix;
        assembly ("memory-safe") {
            extcodecopy(target, 0, 0, 3)
            prefix := shr(232, mload(0))
        }
        return prefix != 0xef0100;
    }

    function requireRegistry(
        address core,
        bytes32 coreCodeHash,
        address registry,
        bytes32 registryCodeHash
    ) internal view {
        if (!isContract(core) || core.codehash != coreCodeHash) {
            revert SettlementBindingInvalid(core);
        }
        if (!isContract(registry) || registry.codehash != registryCodeHash) {
            revert SettlementBindingInvalid(registry);
        }
        bytes memory data =
            abi.encodeCall(IStreamCorePointers.getSatellitePointer, (_REGISTRY_ROLE));
        uint256[10] memory words;
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(gas(), core, add(data, 32), mload(data), words, 320)
            size := returndatasize()
        }
        if (
            !ok || size != 320 || words[0] != uint256(uint160(registry))
                || bytes32(words[1]) != registryCodeHash || words[2] > 1
                || bytes32(words[3]) != _REGISTRY_ROLE
                || words[4] != uint256(uint32(type(IStreamModuleRegistry).interfaceId)) << 224
                || words[5] != uint256(uint160(registry)) || words[6] != 1 || words[7] == 0
                || words[8] == 0 || words[9] == 0 || words[9] > type(uint64).max
        ) revert SettlementBindingInvalid(core);
    }

    /// @notice Captured only by the registered sale adapter when creating a new sale program.
    function capture(address registry, address saleAdapter, address paymentAdapter)
        internal
        view
        returns (StreamPrimarySettlementTypes.SaleLifecycleBinding memory binding)
    {
        ModuleFacts memory sale = _record(
            registry, saleAdapter, SALE_ROLE, type(IStreamERC20SaleExecution).interfaceId
        );
        ModuleFacts memory payment = _record(
            registry,
            paymentAdapter,
            PAYMENT_ROLE,
            type(IStreamERC20PrimarySettlementAdapter).interfaceId
        );
        if (sale.status != 1) revert SettlementModuleNotAdmitted(saleAdapter);
        if (payment.status != 1) revert SettlementModuleNotAdmitted(paymentAdapter);
        if (block.timestamp == 0 || block.timestamp > type(uint64).max) {
            revert SaleLifecycleMismatch(saleAdapter, bytes32(0));
        }
        return StreamPrimarySettlementTypes.SaleLifecycleBinding(
            paymentAdapter, uint64(block.timestamp), sale.revision, payment.revision
        );
    }

    function requireAdmission(
        address registry,
        address paymentAdapter,
        StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c
    ) internal view {
        ModuleFacts memory sale =
            _record(registry, c.saleAdapter, SALE_ROLE, type(IStreamERC20SaleExecution).interfaceId);
        ModuleFacts memory payment = _record(
            registry,
            paymentAdapter,
            PAYMENT_ROLE,
            type(IStreamERC20PrimarySettlementAdapter).interfaceId
        );
        StreamPrimarySettlementTypes.SaleLifecycleBinding memory stored =
            _lifecycle(c.saleAdapter, c.sale.settlementId);
        if (
            keccak256(abi.encode(stored)) != keccak256(abi.encode(c.lifecycleBinding))
                || stored.paymentAdapter != paymentAdapter || stored.saleCreatedAt == 0
                || stored.saleCreatedAt > block.timestamp
        ) revert SaleLifecycleMismatch(c.saleAdapter, c.sale.settlementId);
        _requireLifecycle(
            sale, c.saleAdapter, stored.saleCreatedAt, stored.saleAdapterRegistryRevision
        );
        _requireLifecycle(
            payment, paymentAdapter, stored.saleCreatedAt, stored.paymentAdapterRegistryRevision
        );
    }

    function _requireLifecycle(
        ModuleFacts memory facts,
        address module,
        uint64 created,
        uint64 revision
    ) private pure {
        if (
            revision == 0 || revision > facts.revision || created < facts.registeredAt
                || (facts.status == 2
                    && (created >= facts.statusUpdatedAt || revision >= facts.revision))
        ) revert SettlementModuleNotAdmitted(module);
    }

    function _record(address registry, address module, bytes32 role, bytes4 interfaceId)
        private
        view
        returns (ModuleFacts memory facts)
    {
        if (!isContract(module)) revert SettlementModuleNotAdmitted(module);
        bytes memory data = abi.encodeCall(IStreamModuleRegistry.moduleRecord, (module));
        // Dynamic struct return: outer offset; twelve-word head; URI byte length.
        uint256[14] memory words;
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(gas(), registry, add(data, 32), mload(data), words, 448)
            size := returndatasize()
        }
        if (!ok) revert SettlementModuleReadFailed(module);
        if (
            size < 448 || words[0] != 32 || words[1] > 3 || words[5] > type(uint32).max
                || words[9] != 384 || words[10] > type(uint64).max || words[11] > type(uint64).max
                || words[12] > type(uint64).max || words[13] > size - 448
                || size - 448 != ((words[13] + 31) / 32) * 32
        ) revert SettlementModuleReadMalformed(module, size);
        if (
            (words[1] != 1 && words[1] != 2) || bytes32(words[2]) != role
                || bytes32(words[3]) != VERSION || words[4] != uint256(uint32(interfaceId)) << 224
                || bytes32(words[6]) != module.codehash || words[7] == 0 || words[8] == 0
                || words[10] == 0 || words[10] > block.timestamp || words[11] < words[10]
                || words[11] > block.timestamp || words[12] == 0
        ) revert SettlementModuleNotAdmitted(module);
        // Match canonical registry live eligibility's exact-code ERC165 policy, including
        // its available-gas probes; DEPRECATED cannot use isModuleEligible's ACTIVE-only path.
        if (
            !_interface(module, 0x01ffc9a7, true) || !_interface(module, 0xffffffff, false)
                || !_interface(module, interfaceId, true)
        ) {
            revert SettlementModuleNotAdmitted(module);
        }
        facts =
            ModuleFacts(uint8(words[1]), uint64(words[10]), uint64(words[11]), uint64(words[12]));
    }

    function _interface(address target, bytes4 id, bool expected) private view returns (bool) {
        bytes memory data = abi.encodeWithSelector(bytes4(0x01ffc9a7), id);
        bool ok;
        uint256 size;
        uint256 word;
        assembly ("memory-safe") {
            ok := staticcall(gas(), target, add(data, 32), mload(data), 0, 32)
            size := returndatasize()
            word := mload(0)
        }
        return ok && size == 32 && word == (expected ? 1 : 0);
    }

    function _lifecycle(address saleAdapter, bytes32 saleId)
        private
        view
        returns (StreamPrimarySettlementTypes.SaleLifecycleBinding memory binding)
    {
        bytes memory data =
            abi.encodeCall(IStreamSaleLifecycleBinding.saleLifecycleBinding, (saleId));
        uint256[4] memory words;
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(gas(), saleAdapter, add(data, 32), mload(data), words, 128)
            size := returndatasize()
        }
        if (!ok) revert SaleLifecycleReadFailed(saleAdapter);
        if (
            size != 128 || words[0] > type(uint160).max || words[1] > type(uint64).max
                || words[2] > type(uint64).max || words[3] > type(uint64).max
        ) revert SaleLifecycleReadMalformed(saleAdapter, size);
        return StreamPrimarySettlementTypes.SaleLifecycleBinding(
            address(uint160(words[0])), uint64(words[1]), uint64(words[2]), uint64(words[3])
        );
    }
}
