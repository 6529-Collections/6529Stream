// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    IStreamRecordSelectionLock as L
} from "../../interfaces/stream/metadata/IStreamRecordSelectionLock.sol";
import "../../interfaces/stream/governance/IStreamGovernanceReads.sol";
import "../../interfaces/stream/modules/IStreamModuleRegistry.sol";
import "../../vendor/openzeppelin/IERC165.sol";

/// @notice Exact terminal-governance seal behind each selector's original current-head checks.
/// @dev Linked calls preserve the selector's storage, caller and address domain. The host supplies
/// immutable dependencies and its actual selected head; this library grants no outside authority.
library StreamRecordSelectionLocks {
    struct Environment {
        address core;
        address metadata;
        bytes32 coreCodeHash;
        bytes32 metadataCodeHash;
        uint256 chainId;
        uint256 readGas;
        bytes32 family;
    }

    struct Head {
        uint256 collectionId;
        bytes32 subjectId;
        bytes32 recordHash;
        uint64 revision;
        bytes32 selectionHash;
    }

    struct Pointer {
        address target;
        bytes32 codeHash;
        bool frozen;
        bytes32 moduleType;
        bytes4 interfaceId;
        address registry;
        uint8 registryStatus;
        bytes32 moduleManifestHash;
        bytes32 deploymentManifestHash;
        uint64 revision;
    }

    event RecordSelectionLockedPermanently(
        uint256 indexed collectionId,
        bytes32 indexed subjectId,
        bytes32 indexed recordHash,
        L.SelectionLock seal
    );

    function context(Environment memory e, Head memory h)
        public
        view
        returns (L.SelectionLock memory item)
    {
        if (
            h.collectionId == 0 || h.subjectId == 0 || h.recordHash == 0 || h.revision == 0
                || h.selectionHash == 0
        ) revert L.RecordSelectionLockConflict(h.collectionId, h.subjectId);
        if (
            block.chainid != e.chainId || e.core.code.length == 0
                || e.core.codehash != e.coreCodeHash || e.metadata.code.length == 0
                || e.metadata.codehash != e.metadataCodeHash || e.readGas == 0
                || e.readGas > type(uint64).max
        ) revert L.RecordSelectionLockDependencyChanged(e.metadata);
        item.locked = true;
        item.recordHash = h.recordHash;
        item.revision = h.revision;
        item.selectionHash = h.selectionHash;
        item.executor =
            _address(e.metadata, abi.encodeWithSignature("governanceAuthority()"), e.readGas);
        item.executorCodeHash = abi.decode(
            _fixed(e.metadata, abi.encodeWithSignature("executorCodeHash()"), 32, e.readGas),
            (bytes32)
        );
        if (item.executor.code.length == 0 || item.executor.codehash != item.executorCodeHash) {
            revert L.RecordSelectionLockDependencyChanged(item.executor);
        }
        bytes memory pointerBytes = _fixed(
            e.core,
            abi.encodeWithSignature("getSatellitePointer(bytes32)", keccak256("MODULE_REGISTRY")),
            320,
            e.readGas
        );
        Pointer memory pointer = abi.decode(pointerBytes, (Pointer));
        if (
            pointer.target.code.length == 0 || pointer.target.codehash != pointer.codeHash
                || pointer.moduleType != keccak256("MODULE_REGISTRY")
                || pointer.interfaceId != type(IStreamModuleRegistry).interfaceId
                || pointer.registry == address(0) || pointer.registryStatus != 1
                || pointer.moduleManifestHash == 0 || pointer.deploymentManifestHash == 0
                || pointer.revision == 0
                || !abi.decode(
                    _fixed(
                        pointer.target,
                        abi.encodeCall(
                            IERC165.supportsInterface, (type(IStreamModuleRegistry).interfaceId)
                        ),
                        32,
                        e.readGas
                    ),
                    (bool)
                )
                || _address(
                        pointer.target, abi.encodeWithSignature("governanceExecutor()"), e.readGas
                    ) != item.executor
        ) revert L.RecordSelectionLockDependencyChanged(pointer.target);
        item.moduleRegistry = pointer.target;
        item.moduleRegistryCodeHash = pointer.codeHash;
        item.modulePointerHash = keccak256(pointerBytes);
        (item.governanceRoot, item.governanceRootCodeHash, item.governanceRootRevision) = abi.decode(
            _fixed(
                item.executor,
                abi.encodeCall(IStreamGovernanceReads.governanceRootState, ()),
                96,
                e.readGas
            ),
            (address, bytes32, uint64)
        );
        if (
            item.governanceRoot == address(0) || item.governanceRootRevision == 0
                || item.governanceRoot.codehash != item.governanceRootCodeHash
                || _address(item.executor, abi.encodeWithSignature("owner()"), e.readGas)
                    != item.governanceRoot
        ) revert L.RecordSelectionLockAuthorityRequired();
        item.scopeHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_RECORD_SELECTION_LOCK_SCOPE_V1"),
                e.chainId,
                address(this),
                e.core,
                e.metadata,
                e.family,
                h.collectionId,
                h.subjectId,
                item.executor,
                item.executorCodeHash,
                item.modulePointerHash,
                item.governanceRoot,
                item.governanceRootCodeHash,
                item.governanceRootRevision
            )
        );
        item.oldValueHash = keccak256(
            abi.encode(keccak256("6529STREAM_RECORD_SELECTION_LOCK_STATE_V1"), false, h)
        );
        item.newValueHash = keccak256(
            abi.encode(keccak256("6529STREAM_RECORD_SELECTION_LOCK_STATE_V1"), true, h)
        );
    }

    function lock(
        mapping(bytes32 => L.SelectionLock) storage seals,
        Environment memory e,
        Head memory h
    ) public {
        bytes32 key = keccak256(abi.encode(h.collectionId, h.subjectId));
        if (seals[key].locked) revert L.RecordSelectionLocked(h.collectionId, h.subjectId);
        L.SelectionLock memory item = context(e, h);
        if (
            msg.sender != item.executor || block.timestamp == 0
                || block.timestamp > type(uint64).max
        ) {
            revert L.RecordSelectionLockAuthorityRequired();
        }
        (
            bool active,
            bytes32 actionId,
            uint8 actionClass,
            bytes32 scope,
            bytes32 oldHash,
            bytes32 newHash
        ) = abi.decode(
            _fixed(
                item.executor,
                abi.encodeCall(IStreamGovernanceReads.currentAction, ()),
                192,
                e.readGas
            ),
            (bool, bytes32, uint8, bytes32, bytes32, bytes32)
        );
        if (
            !active || actionId == 0 || actionClass != 2 || scope != item.scopeHash
                || oldHash != item.oldValueHash || newHash != item.newValueHash
        ) {
            revert L.RecordSelectionLockAuthorityRequired();
        }
        _storedAction(item.executor, e.readGas, actionId, item.governanceRoot);
        item.actionId = actionId;
        item.lockedAt = uint64(block.timestamp);
        item.lockHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_RECORD_SELECTION_LOCK_RECORD_V1"),
                e.chainId,
                address(this),
                e.core,
                e.metadata,
                e.family,
                h.collectionId,
                h.subjectId,
                item
            )
        );
        seals[key] = item;
        emit RecordSelectionLockedPermanently(h.collectionId, h.subjectId, h.recordHash, item);
    }

    function _storedAction(address executor, uint256 cap, bytes32 actionId, address root)
        private
        view
    {
        (bytes memory header, uint256 size) = _read(
            executor, abi.encodeCall(IStreamGovernanceReads.governanceAction, (actionId)), 640, cap
        );
        uint256 uriLength = _word(header, 19);
        if (
            size < 640 || _word(header, 0) != 32 || _word(header, 17) != 576
                || uriLength > size - 640 || size % 32 != 0 || size - 640 - uriLength > 31
                || _word(header, 1) != uint256(GovernanceActionStatus.EXECUTED)
                || _word(header, 2) != 2 || _word(header, 12) != uint160(root)
        ) {
            revert L.RecordSelectionLockAuthorityRequired();
        }
    }

    function _address(address target, bytes memory input, uint256 cap)
        private
        view
        returns (address)
    {
        return abi.decode(_fixed(target, input, 32, cap), (address));
    }

    function _word(bytes memory data, uint256 index) private pure returns (uint256 word) {
        assembly ("memory-safe") { word := mload(add(add(data, 32), mul(index, 32))) }
    }

    function _fixed(address target, bytes memory input, uint256 length, uint256 cap)
        private
        view
        returns (bytes memory data)
    {
        uint256 size;
        (data, size) = _read(target, input, length, cap);
        if (size != length) revert L.RecordSelectionLockReadFailed(target);
    }

    function _read(address target, bytes memory input, uint256 length, uint256 cap)
        private
        view
        returns (bytes memory data, uint256 size)
    {
        data = new bytes(length);
        if (gasleft() <= cap + cap / 63 + 10000) revert L.RecordSelectionLockReadFailed(target);
        bool ok;
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(input, 32), mload(input), add(data, 32), length)
            size := returndatasize()
        }
        if (!ok || size < length) revert L.RecordSelectionLockReadFailed(target);
    }
}
