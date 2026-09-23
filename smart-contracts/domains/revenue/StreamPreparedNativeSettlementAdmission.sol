// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamSettlementAdmission.sol";
import "../../interfaces/stream/revenue/IStreamPreparedNativeSaleBinding.sol";
import "../../interfaces/stream/revenue/IStreamPreparedNativePrimarySaleSettlement.sol";

/// @notice Separate registered prepared-sale role with immutable original-sale lifecycle admission.
/// @dev Retains existing native reader shape and lifecycle predicates under a distinct role/interface.
library StreamPreparedNativeSettlementAdmission {
    bytes32 private constant VERSION = keccak256("6529STREAM_PREPARED_NATIVE_SETTLEMENT_V1");
    bytes32 private constant ROLE = keccak256("NATIVE_PREPARED_SALE_ADAPTER");
    bytes32 private constant RECORDER_ROLE = keccak256("PRIMARY_SALE_SETTLEMENT");

    struct ModuleFacts {
        uint8 status;
        uint64 registeredAt;
        uint64 statusUpdatedAt;
        uint64 revision;
    }
    error SettlementModuleReadFailed(address module);
    error SettlementModuleReadMalformed(address module, uint256 length);
    error SettlementModuleNotAdmitted(address module);
    error SaleLifecycleReadFailed(address module);
    error SaleLifecycleReadMalformed(address module, uint256 length);
    error SaleLifecycleMismatch(address module, bytes32 saleId);

    function requireModule(address registry, address sale) public view {
        _record(registry, sale, ROLE, type(IStreamPreparedNativeSaleBinding).interfaceId);
    }

    function captureRecorder(address registry, address recorder)
        public
        view
        returns (uint64 boundAt, uint64 revision)
    {
        ModuleFacts memory facts = _record(
            registry,
            recorder,
            RECORDER_ROLE,
            type(IStreamPreparedNativePrimarySaleSettlement).interfaceId
        );
        if (facts.status != 1 || block.timestamp == 0 || block.timestamp > type(uint64).max) {
            revert SettlementModuleNotAdmitted(recorder);
        }
        return (uint64(block.timestamp), facts.revision);
    }

    function requireRecorder(address registry, address recorder, uint64 boundAt, uint64 revision)
        public
        view
    {
        ModuleFacts memory facts = _record(
            registry,
            recorder,
            RECORDER_ROLE,
            type(IStreamPreparedNativePrimarySaleSettlement).interfaceId
        );
        if (boundAt == 0 || boundAt > block.timestamp) {
            revert SettlementModuleNotAdmitted(recorder);
        }
        _requireLifecycle(facts, recorder, boundAt, revision);
    }

    function capture(address registry, address sale)
        public
        view
        returns (StreamNativeSettlementTypes.SaleLifecycleBinding memory)
    {
        ModuleFacts memory facts =
            _record(registry, sale, ROLE, type(IStreamPreparedNativeSaleBinding).interfaceId);
        if (facts.status != 1) revert SettlementModuleNotAdmitted(sale);
        if (block.timestamp == 0 || block.timestamp > type(uint64).max) {
            revert SaleLifecycleMismatch(sale, 0);
        }
        return
            StreamNativeSettlementTypes.SaleLifecycleBinding(
                uint64(block.timestamp), facts.revision
            );
    }

    function requireAdmission(address registry, address sale, bytes32 saleId)
        public
        view
        returns (StreamNativeSettlementTypes.SaleLifecycleBinding memory lifecycle)
    {
        ModuleFacts memory facts =
            _record(registry, sale, ROLE, type(IStreamPreparedNativeSaleBinding).interfaceId);
        bytes memory data = abi.encodeCall(
            IStreamPreparedNativeSaleBinding.preparedNativeSaleLifecycle, (saleId)
        );
        uint256[2] memory words;
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(gas(), sale, add(data, 32), mload(data), words, 64)
            size := returndatasize()
        }
        if (!ok) revert SaleLifecycleReadFailed(sale);
        if (size != 64 || words[0] > type(uint64).max || words[1] > type(uint64).max) {
            revert SaleLifecycleReadMalformed(sale, size);
        }
        if (words[0] == 0 || words[0] > block.timestamp) {
            revert SaleLifecycleMismatch(sale, saleId);
        }
        _requireLifecycle(facts, sale, uint64(words[0]), uint64(words[1]));
        lifecycle =
            StreamNativeSettlementTypes.SaleLifecycleBinding(uint64(words[0]), uint64(words[1]));
    }

    function isContract(address target) private view returns (bool) {
        return StreamSettlementAdmission.isContract(target);
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
}
