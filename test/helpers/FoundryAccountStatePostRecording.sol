// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    FoundryAccountStateExport as Export,
    FoundryAccountStateExportVm
} from "./FoundryAccountStateExport.sol";

/// @notice Fixed post-recording reads and dump comparison for the local account exporter.
/// @dev The Bootstrap decodes and stops both recorders before this linked library is called.
/// DELEGATECALL preserves the original recorder context. The native library account requires
/// independently authenticated prestate admission; this boundary adds no dump omission.
library FoundryAccountStatePostRecording {
    FoundryAccountStateExportVm internal constant VM =
        FoundryAccountStateExportVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function finishCaptured(
        FoundryAccountStateExportVm.AccountAccess[] memory diff,
        address[] memory requiredSeedAccounts,
        Export.SlotSeed[] memory explicitSlotSeeds
    ) public view returns (Export.Snapshot memory result) {
        result.accessHash = keccak256(abi.encode(diff));
        result.accessCount = diff.length;
        uint256 capacity = requiredSeedAccounts.length + explicitSlotSeeds.length + diff.length * 2;
        for (uint256 i; i < diff.length; ++i) {
            capacity += diff[i].storageAccesses.length;
        }
        address[] memory accounts = new address[](capacity);
        address[] memory created = new address[](diff.length);
        uint256 count;
        uint256 createdCount;
        for (uint256 i; i < requiredSeedAccounts.length; ++i) {
            count = _add(accounts, count, requiredSeedAccounts[i]);
        }
        for (uint256 i; i < explicitSlotSeeds.length; ++i) {
            count = _add(accounts, count, explicitSlotSeeds[i].account);
        }
        for (uint256 i; i < diff.length; ++i) {
            FoundryAccountStateExportVm.AccountAccess memory a = diff[i];
            if (a.chainInfo.forkId != 0 || a.chainInfo.chainId != block.chainid) {
                revert Export.UnsupportedForkOrChain(a.chainInfo.forkId, a.chainInfo.chainId);
            }
            if (!a.reverted && a.kind == FoundryAccountStateExportVm.AccountAccessKind.SelfDestruct)
            {
                revert Export.UnsupportedSelfDestruct(a.accessor);
            }
            if (!a.reverted && a.kind == FoundryAccountStateExportVm.AccountAccessKind.Create) {
                createdCount = _add(created, createdCount, a.account);
            }
            count = _add(accounts, count, a.account);
            count = _add(accounts, count, a.accessor);
            for (uint256 j; j < a.storageAccesses.length; ++j) {
                count = _add(accounts, count, a.storageAccesses[j].account);
            }
        }
        result.accounts = new Export.Account[](count);
        for (uint256 i; i < count; ++i) {
            result.accounts[i] = _read(accounts[i], diff, explicitSlotSeeds);
        }
        assembly ("memory-safe") {
            mstore(created, createdCount)
        }
        result.createdAccounts = created;
    }

    function requireDumpParity(
        Export.Snapshot memory saved,
        Export.Account[] memory decodedDump,
        address[] memory auditedDumpOmissions
    ) public view {
        Export.requireDumpParity(saved, decodedDump, auditedDumpOmissions);
    }

    function _read(
        address account,
        FoundryAccountStateExportVm.AccountAccess[] memory diff,
        Export.SlotSeed[] memory seeds
    ) private view returns (Export.Account memory a) {
        (bytes32[] memory reads, bytes32[] memory writes) = VM.accesses(account);
        uint256 capacity = reads.length + writes.length;
        for (uint256 i; i < seeds.length; ++i) {
            if (seeds[i].account == account) ++capacity;
        }
        for (uint256 i; i < diff.length; ++i) {
            for (uint256 j; j < diff[i].storageAccesses.length; ++j) {
                if (diff[i].storageAccesses[j].account == account) ++capacity;
            }
        }
        bytes32[] memory keys = new bytes32[](capacity);
        uint256 count;
        for (uint256 i; i < reads.length; ++i) {
            count = _addSlot(keys, count, reads[i]);
        }
        for (uint256 i; i < writes.length; ++i) {
            count = _addSlot(keys, count, writes[i]);
        }
        for (uint256 i; i < seeds.length; ++i) {
            if (seeds[i].account == account) count = _addSlot(keys, count, seeds[i].slot);
        }
        for (uint256 i; i < diff.length; ++i) {
            for (uint256 j; j < diff[i].storageAccesses.length; ++j) {
                FoundryAccountStateExportVm.StorageAccess memory s = diff[i].storageAccesses[j];
                if (s.account == account) count = _addSlot(keys, count, s.slot);
            }
        }
        a.account = account;
        a.code = account.code;
        a.codeHash = account.codehash;
        a.balance = account.balance;
        a.nonce = VM.getNonce(account);
        a.slots = new Export.SlotValue[](count);
        for (uint256 i; i < count; ++i) {
            a.slots[i] = Export.SlotValue(keys[i], VM.load(account, keys[i]));
        }
    }

    function _add(address[] memory accounts, uint256 count, address a)
        private
        pure
        returns (uint256)
    {
        for (uint256 i; i < count; ++i) {
            if (accounts[i] == a) return count;
        }
        accounts[count] = a;
        return count + 1;
    }

    function _addSlot(bytes32[] memory keys, uint256 count, bytes32 key)
        private
        pure
        returns (uint256)
    {
        for (uint256 i; i < count; ++i) {
            if (keys[i] == key) return count;
        }
        keys[count] = key;
        return count + 1;
    }
}
