// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @dev Exact relevant ABI from Foundry 1.7.1, commit 4072e48705af9d93e3c0f6e29e93b5e9a40caed8.
interface FoundryAccountStateExportVm {
    enum AccountAccessKind {
        Call,
        DelegateCall,
        CallCode,
        StaticCall,
        Create,
        SelfDestruct,
        Resume,
        Balance,
        Extcodesize,
        Extcodehash,
        Extcodecopy
    }

    struct ChainInfo {
        uint256 forkId;
        uint256 chainId;
    }

    struct StorageAccess {
        address account;
        bytes32 slot;
        bool isWrite;
        bytes32 previousValue;
        bytes32 newValue;
        bool reverted;
    }

    struct AccountAccess {
        ChainInfo chainInfo;
        AccountAccessKind kind;
        address account;
        address accessor;
        bool initialized;
        uint256 oldBalance;
        uint256 newBalance;
        bytes deployedCode;
        uint256 value;
        bytes data;
        bool reverted;
        StorageAccess[] storageAccesses;
        uint64 depth;
        uint64 oldNonce;
        uint64 newNonce;
    }

    function record() external;
    function stopRecord() external;
    function accesses(address account)
        external
        view
        returns (bytes32[] memory reads, bytes32[] memory writes);
    function startStateDiffRecording() external;
    function stopAndReturnStateDiff() external returns (AccountAccess[] memory);
    function load(address account, bytes32 slot) external view returns (bytes32);
    function getNonce(address account) external view returns (uint64);
}

/// @notice Final live account reads for an explicitly bounded, source-reviewed Foundry setup.
/// @dev Recording is discovery, not proof of complete prestate. Call begin before genuine scenario
/// CREATE. Supply native-library/prestate accounts and every permitted VM mutation target/slot.
/// No account state is installed. A caller must independently prove closure and check an actual
/// raw dump through requireDumpParity before accepting a serialized bootstrap. This is test tooling.
/// Read an initial dump for additional seeds before finish; take the parity dump after finish has
/// loaded every discovered account's code and slot. Native-library/prestate closure remains explicit.
library FoundryAccountStateExport {
    FoundryAccountStateExportVm internal constant VM =
        FoundryAccountStateExportVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    struct SlotSeed {
        address account;
        bytes32 slot;
    }

    struct SlotValue {
        bytes32 slot;
        bytes32 value;
    }

    struct Account {
        address account;
        bytes code;
        bytes32 codeHash;
        uint256 balance;
        uint64 nonce;
        SlotValue[] slots;
    }

    struct Snapshot {
        Account[] accounts;
        bytes32 accessHash;
        uint256 accessCount;
        address[] createdAccounts;
    }

    error UnsupportedForkOrChain(uint256 forkId, uint256 chainId);
    error UnsupportedSelfDestruct(address account);
    error MissingDumpAccount(address account);
    error UnknownDumpAccount(address account);
    error DuplicateAccount(address account);
    error DuplicateSlot(address account, bytes32 slot);
    error MissingDumpSlot(address account, bytes32 slot);
    error UnknownDumpSlot(address account, bytes32 slot);
    error DumpAccountMismatch(address account);
    error DumpSlotMismatch(address account, bytes32 slot);
    error InvalidDumpOmission(address account);
    error CreatedAccountOmitted(address account);
    error InvalidAbsentAccount(address account);

    function begin() internal {
        VM.record();
        VM.startStateDiffRecording();
    }

    /// @dev Final values, including reverted-access candidates, are read after recording stops.
    /// getCode/getDeployedCode read artifacts; neither is a live-address runtime read.
    /// The caller owns the fresh/non-forked prestate and must not reset either recorder during setup.
    /// Fork ID zero alone cannot certify that environment; the source/environment manifest must.
    function finish(address[] memory requiredSeedAccounts, SlotSeed[] memory explicitSlotSeeds)
        internal
        returns (Snapshot memory result)
    {
        FoundryAccountStateExportVm.AccountAccess[] memory diff = VM.stopAndReturnStateDiff();
        VM.stopRecord();
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
                revert UnsupportedForkOrChain(a.chainInfo.forkId, a.chainInfo.chainId);
            }
            if (!a.reverted && a.kind == FoundryAccountStateExportVm.AccountAccessKind.SelfDestruct)
            {
                revert UnsupportedSelfDestruct(a.accessor);
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
        result.accounts = new Account[](count);
        for (uint256 i; i < count; ++i) {
            result.accounts[i] = _read(accounts[i], diff, explicitSlotSeeds);
        }
        assembly ("memory-safe") {
            mstore(created, createdCount)
        }
        result.createdAccounts = created;
    }

    /// @dev decodedDump must come from this cut's actual native dump, with parser/source hashes
    /// authenticated by the caller. This compares both directions and never attests closure alone.
    /// Only explicit outer-recorder/default-origin/VM omissions are admitted. Created accounts,
    /// including the genuine scenario, cannot be omitted. Absent accounts remain absent: do not
    /// turn a reverted CREATE candidate with codeHash zero into a new genesis EOA.
    /// tx.origin is used only to recognize an audited native-dump omission, never as authority.
    function requireDumpParity(
        Snapshot memory saved,
        Account[] memory decodedDump,
        address[] memory auditedDumpOmissions
    ) internal view {
        _unique(saved.accounts);
        _unique(decodedDump);
        for (uint256 i; i < auditedDumpOmissions.length; ++i) {
            address a = auditedDumpOmissions[i];
            for (uint256 j; j < i; ++j) {
                if (auditedDumpOmissions[j] == a) revert InvalidDumpOmission(a);
            }
            if (_contains(saved.createdAccounts, a)) revert CreatedAccountOmitted(a);
            if (
                (a != address(this) && a != tx.origin && a != address(VM))
                    || _index(saved.accounts, a) == type(uint256).max
                    || _index(decodedDump, a) != type(uint256).max
            ) revert InvalidDumpOmission(a);
        }
        for (uint256 i; i < decodedDump.length; ++i) {
            Account memory actual = decodedDump[i];
            uint256 index = _index(saved.accounts, actual.account);
            if (index == type(uint256).max) revert UnknownDumpAccount(actual.account);
            _same(saved.accounts[index], actual);
        }
        for (uint256 i; i < saved.accounts.length; ++i) {
            Account memory a = saved.accounts[i];
            if (_index(decodedDump, a.account) != type(uint256).max) continue;
            if (_absent(a)) continue;
            if (!_contains(auditedDumpOmissions, a.account)) revert MissingDumpAccount(a.account);
        }
    }

    function _read(
        address account,
        FoundryAccountStateExportVm.AccountAccess[] memory diff,
        SlotSeed[] memory seeds
    ) private view returns (Account memory a) {
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
        a.slots = new SlotValue[](count);
        for (uint256 i; i < count; ++i) {
            a.slots[i] = SlotValue(keys[i], VM.load(account, keys[i]));
        }
    }

    function _same(Account memory expected, Account memory actual) private pure {
        address a = expected.account;
        if (
            expected.codeHash != actual.codeHash
                || keccak256(expected.code) != keccak256(actual.code)
                || expected.balance != actual.balance || expected.nonce != actual.nonce
        ) revert DumpAccountMismatch(a);
        for (uint256 i; i < actual.slots.length; ++i) {
            uint256 j = _slotIndex(expected.slots, actual.slots[i].slot);
            if (j == type(uint256).max) revert UnknownDumpSlot(a, actual.slots[i].slot);
            if (expected.slots[j].value != actual.slots[i].value) {
                revert DumpSlotMismatch(a, actual.slots[i].slot);
            }
        }
        for (uint256 i; i < expected.slots.length; ++i) {
            if (_slotIndex(actual.slots, expected.slots[i].slot) == type(uint256).max) {
                revert MissingDumpSlot(a, expected.slots[i].slot);
            }
        }
    }

    function _unique(Account[] memory accounts) private pure {
        for (uint256 i; i < accounts.length; ++i) {
            for (uint256 j; j < i; ++j) {
                if (accounts[i].account == accounts[j].account) {
                    revert DuplicateAccount(accounts[i].account);
                }
            }
            for (uint256 j; j < accounts[i].slots.length; ++j) {
                for (uint256 k; k < j; ++k) {
                    if (accounts[i].slots[j].slot == accounts[i].slots[k].slot) {
                        revert DuplicateSlot(accounts[i].account, accounts[i].slots[j].slot);
                    }
                }
            }
        }
    }

    function _absent(Account memory a) private pure returns (bool) {
        if (a.codeHash != 0) return false;
        if (a.code.length != 0 || a.balance != 0 || a.nonce != 0) {
            revert InvalidAbsentAccount(a.account);
        }
        for (uint256 i; i < a.slots.length; ++i) {
            if (a.slots[i].value != 0) revert InvalidAbsentAccount(a.account);
        }
        return true;
    }

    function _index(Account[] memory accounts, address a) private pure returns (uint256) {
        for (uint256 i; i < accounts.length; ++i) {
            if (accounts[i].account == a) return i;
        }
        return type(uint256).max;
    }

    function _slotIndex(SlotValue[] memory slots, bytes32 key) private pure returns (uint256) {
        for (uint256 i; i < slots.length; ++i) {
            if (slots[i].slot == key) return i;
        }
        return type(uint256).max;
    }

    function _contains(address[] memory accounts, address a) private pure returns (bool) {
        for (uint256 i; i < accounts.length; ++i) {
            if (accounts[i] == a) return true;
        }
        return false;
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
