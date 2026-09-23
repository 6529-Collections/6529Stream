// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IStreamNativeImmediateSales as S } from
    "../../smart-contracts/interfaces/stream/mint/IStreamNativeImmediateSales.sol";
import { IStreamNativeDutchSales as D } from
    "../../smart-contracts/interfaces/stream/mint/IStreamNativeDutchSales.sol";
import { IStreamMintManager as M } from
    "../../smart-contracts/interfaces/stream/mint/IStreamMintManager.sol";

/// @dev Exact state-diff wire types from Foundry v1.7.1, including both nonce words:
/// https://github.com/foundry-rs/foundry/blob/v1.7.1/crates/cheatcodes/spec/src/vm.rs
/// Unsupported cheatcodes or a different return ABI revert; no approximate fallback exists.
interface ActualColdExportVm {
    enum AccountAccessKind {
        Call, DelegateCall, CallCode, StaticCall, Create, SelfDestruct, Resume,
        Balance, Extcodesize, Extcodehash, Extcodecopy
    }
    struct ChainInfo { uint256 forkId; uint256 chainId; }
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
    function startStateDiffRecording() external;
    function stopAndReturnStateDiff() external returns (AccountAccess[] memory);
    function snapshotState() external returns (uint256);
    function revertToState(uint256 snapshotId) external returns (bool);
    function getNonce(address account) external view returns (uint64);
    function load(address account, bytes32 slot) external view returns (bytes32);
    function prank(address sender, address origin) external;
    function envString(string calldata name) external returns (string memory);
    function dumpState(string calldata path) external;
    function writeFileBinary(string calldata path, bytes calldata contents) external;
}

/// @notice Discovery and checkpoint export only; this is never a measured purchase driver.
/// @dev Every original journal value is observed after reverting the successful discovery.
/// All deduplication uses memory. No storage/code/balance/nonce is synthesized for export.
abstract contract ActualColdPurchaseExportSupport {
    ActualColdExportVm private constant coldVm =
        ActualColdExportVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    struct Account {
        address account;
        uint256 balance;
        uint64 nonce;
        bytes code;
        bytes32 codeHash;
    }
    struct Slot { address account; bytes32 slot; bytes32 value; }
    struct Probe { uint8 roleIndex; bytes callData; bytes result; }

    function _coldSetup() internal virtual;
    function _coldRoles() internal view virtual returns (address[13] memory);
    function _coldRequest() internal view virtual returns (S.Purchase memory);
    function _coldAssert(S.Purchase memory p, S.Receipt memory r) internal view virtual;
    function _coldReleaseKey() internal view virtual returns (bytes32);
    function _coldValue() internal view virtual returns (uint256) { return 1000; }
    function _coldExtraProbes(address[13] memory, S.Purchase memory, S.Receipt memory)
        internal view virtual returns (Probe[] memory empty) { return new Probe[](0); }
    function _coldAfterDiscovery(string memory, S.Purchase memory, S.Receipt memory)
        internal virtual { }


    function _exportCold(string memory label) internal {
        coldVm.startStateDiffRecording();
        _coldSetup();
        ActualColdExportVm.AccountAccess[] memory setup = coldVm.stopAndReturnStateDiff();
        require(setup.length != 0, "setup access recording required");
        address[13] memory roles = _coldRoles();
        S.Purchase memory purchase = _coldRequest();
        uint256 snapshot = coldVm.snapshotState();

        coldVm.startStateDiffRecording();
        // The actual cold transaction is sent by the buyer. The original call data,
        // production instances, value and inherited purchase assertions are retained.
        coldVm.prank(roles[0], roles[0]);
        S.Receipt memory receipt = D(roles[1]).purchasePublic{ value: _coldValue() }(purchase);
        _coldAssert(purchase, receipt);
        Probe[] memory post = _postProbes(roles, purchase, receipt, _coldReleaseKey());
        _coldAfterDiscovery(label, purchase, receipt);
        ActualColdExportVm.AccountAccess[] memory discovered = coldVm.stopAndReturnStateDiff();
        require(discovered.length != 0, "purchase access recording required");
        require(coldVm.revertToState(snapshot), "restore original checkpoint");

        coldVm.startStateDiffRecording();
        Probe[] memory pre = _repeatProbes(roles, post);
        ActualColdExportVm.AccountAccess[] memory preReads = coldVm.stopAndReturnStateDiff();
        _assertAccounting(pre, post);
        ActualColdExportVm.AccountAccess[][] memory accesses =
            new ActualColdExportVm.AccountAccess[][](3);
        accesses[0] = setup;
        accesses[1] = discovered;
        accesses[2] = preReads;
        (Account[] memory accounts, Slot[] memory slots) = _observeCheckpoint(roles, accesses);

        string memory prefix = string.concat(coldVm.envString("COLLECTOR_ACTUAL_EXPORT_DIR"), "/", label);
        coldVm.writeFileBinary(string.concat(prefix, "-transaction.abi"), abi.encode(
            uint256(1), block.chainid, block.number, block.timestamp, roles,
            purchase.saleId, _coldValue(), abi.encodeCall(D.purchasePublic, (purchase))
        ));
        // Raw checkpoint v1: version, chainId, number, timestamp, Account[], Slot[], pre[], post[].
        // Account includes observed codeHash: an all-zero tuple alone does not prove absence.
        coldVm.writeFileBinary(string.concat(prefix, "-checkpoint.abi"), abi.encode(
            uint256(1), block.chainid, block.number, block.timestamp, accounts, slots, pre, post
        ));
        coldVm.writeFileBinary(string.concat(prefix, "-accesses.abi"), abi.encode(setup, discovered, preReads));
        _exportEnvironment(prefix);
        // Observations above populate the live journal through real reads. The untouched
        // Foundry serializer writes it; no generated allocation entries are supplied here.
        coldVm.dumpState(string.concat(prefix, "-alloc.json"));
    }

    function _postProbes(
        address[13] memory a, S.Purchase memory p, S.Receipt memory r, bytes32 releaseKey
    ) private view returns (Probe[] memory probes) {
        bytes32 phase = D(a[1]).saleRecord(p.saleId).sale.config.phaseId;
        bytes32 counter = keccak256("canonical deployment supply counter");
        bytes32 subject = M(a[3]).previewSubjectKey(
            M.CounterKeyMode.CONSTANT, 1, phase, counter, a[0], a[0], a[1], address(0), bytes32(0)
        );
        // Original Manager resolves the actual counter definition/scope before Ledger key derivation.
        bytes32 counterKey = M(a[3]).previewCounterValueKey(1, phase, counter, subject);
        Probe[] memory extra = _coldExtraProbes(a, p, r);
        probes = new Probe[](27 + extra.length);
        probes[0] = _probe(a, 1, abi.encodeWithSignature("saleRecord(bytes32)", p.saleId));
        probes[1] = _probe(a, 2, abi.encodeWithSignature("collectionMintedEver(uint256)", uint256(1)));
        probes[2] = _probe(a, 3, abi.encodeWithSignature("nextOperationNonce()"));
        probes[3] = _probe(a, 4, abi.encodeWithSignature("counterValue(bytes32)", counterKey));
        probes[4] = _probe(a, 5, abi.encodeWithSignature("totalOfficialSettled(address)", address(0)));
        probes[5] = _probe(a, 6, abi.encodeWithSignature("collectionArtistAuthority(uint256)", uint256(1)));
        probes[6] = _probe(a, 7, abi.encodeWithSignature("core()"));
        probes[7] = _probe(a, 8, abi.encodeWithSignature("firstSale(uint256)", uint256(1)));
        probes[8] = _probe(a, 9, abi.encodeWithSignature("minimumDelay(uint8)", uint8(1)));
        probes[9] = _probe(a, 10, abi.encodeWithSignature("governanceExecutor()"));
        probes[10] = _probe(a, 11, abi.encodeWithSignature("core()"));
        probes[11] = _probe(a, 12, abi.encodeWithSignature("getThreshold()"));
        probes[12] = _probe(a, 1, abi.encodeWithSignature("nextExecutionNonce(bytes32,address)", p.saleId, a[0]));
        probes[13] = _probe(a, 1, abi.encodeWithSignature("executionReceipt(bytes32)", r.executionId));
        probes[14] = _probe(a, 1, abi.encodeWithSignature("executionStatus(bytes32)", r.executionId));
        probes[15] = _probe(a, 5, abi.encodeWithSignature("settlementConsumed(bytes32)", r.settlementKey));
        probes[16] = _probe(a, 5, abi.encodeWithSignature("settlementResult(bytes32)", r.settlementKey));
        probes[17] = _probe(a, 8, abi.encodeWithSignature("settlementReceipt(bytes32)", r.settlementKey));
        probes[18] = _probe(a, 2, abi.encodeWithSignature("tokenCollectionIdentity(uint256)", r.tokenId));
        probes[19] = _probe(a, 2, abi.encodeWithSignature("coordinatorAtMint(uint256)", r.tokenId));
        probes[20] = _probe(a, 2, abi.encodeWithSignature("tokenData(uint256)", r.tokenId));
        probes[21] = _probe(a, 2, abi.encodeWithSignature("lastAllocatedTokenId()"));
        probes[22] = _probe(a, 2, abi.encodeWithSignature("collectionNextSerial(uint256)", uint256(1)));
        probes[23] = _probe(a, 3, abi.encodeWithSignature("isOperationRootUsed(bytes32)", r.operationRoot));
        probes[24] = _probe(a, 8, abi.encodeWithSignature("releaseFloorReceipt(bytes32)", releaseKey));
        probes[25] = _probe(a, 3, abi.encodeCall(M.previewSubjectKey, (
            M.CounterKeyMode.CONSTANT, uint256(1), phase, counter,
            a[0], a[0], a[1], address(0), bytes32(0)
        )));
        probes[26] = _probe(a, 3, abi.encodeCall(M.previewCounterValueKey, (uint256(1), phase, counter, subject)));
        require(abi.decode(probes[25].result, (bytes32)) == subject
            && abi.decode(probes[26].result, (bytes32)) == counterKey, "exact counter key probes");
        for (uint256 i; i < extra.length; ++i) probes[27 + i] = extra[i];
    }

    function _probe(address[13] memory roles, uint8 role, bytes memory data)
        internal view returns (Probe memory)
    {
        require(role != 0 && role < roles.length && roles[role].code.length != 0, "real probe role");
        (bool ok, bytes memory result) = roles[role].staticcall(data);
        require(ok && result.length != 0, "checkpoint getter failed");
        return Probe(role, data, result);
    }

    function _repeatProbes(address[13] memory roles, Probe[] memory post)
        private view returns (Probe[] memory pre)
    {
        pre = new Probe[](post.length);
        for (uint256 i; i < post.length; ++i) {
            pre[i] = _probe(roles, post[i].roleIndex, post[i].callData);
        }
    }

    function _word(Probe memory p) private pure returns (uint256) {
        require(p.result.length == 32, "exact accounting result");
        return abi.decode(p.result, (uint256));
    }

    function _assertAccounting(Probe[] memory pre, Probe[] memory post) private pure {
        require(_word(pre[1]) == 0 && _word(post[1]) == 1, "collection count 0 to 1");
        require(_word(post[2]) == _word(pre[2]) + 1, "Manager nonce once");
        require(_word(pre[3]) == 0 && _word(post[3]) == 1, "actual Ledger counter 0 to 1");
        require(_word(pre[12]) == 1 && _word(post[12]) == 2, "Dutch nonce 1 to 2");
        require(_word(pre[25]) == _word(post[25]) && _word(pre[26]) == _word(post[26]),
            "counter identity unchanged across purchase");
    }

    function _observeCheckpoint(
        address[13] memory roles, ActualColdExportVm.AccountAccess[][] memory batches
    ) private view returns (Account[] memory accounts, Slot[] memory slots) {
        uint256 maxAccounts = 18;
        uint256 maxSlots;
        for (uint256 i; i < batches.length; ++i) {
            for (uint256 j; j < batches[i].length; ++j) {
                ActualColdExportVm.AccountAccess memory access = batches[i][j];
                require(access.chainInfo.forkId == 0 && access.chainInfo.chainId == block.chainid,
                    "local single-chain access only");
                maxAccounts += 2 + access.storageAccesses.length;
                maxSlots += access.storageAccesses.length;
            }
        }
        accounts = new Account[](maxAccounts);
        slots = new Slot[](maxSlots);
        uint256[] memory accountIndex = new uint256[](_tableSize(maxAccounts));
        uint256[] memory slotIndex = new uint256[](_tableSize(maxSlots));
        uint256 accountCount;
        uint256 slotCount;
        for (uint256 i; i < roles.length; ++i) {
            accountCount = _observeAccount(roles[i], accounts, accountIndex, accountCount);
        }
        accountCount = _observeAccount(address(this), accounts, accountIndex, accountCount);
        accountCount = _observeAccount(msg.sender, accounts, accountIndex, accountCount);
        accountCount = _observeAccount(tx.origin, accounts, accountIndex, accountCount);
        accountCount = _observeAccount(block.coinbase, accounts, accountIndex, accountCount);
        accountCount = _observeAccount(address(coldVm), accounts, accountIndex, accountCount);
        for (uint256 i; i < batches.length; ++i) {
            for (uint256 j; j < batches[i].length; ++j) {
                ActualColdExportVm.AccountAccess memory access = batches[i][j];
                accountCount = _observeAccount(access.account, accounts, accountIndex, accountCount);
                accountCount = _observeAccount(access.accessor, accounts, accountIndex, accountCount);
                // Keep reads, writes and reverted accesses. Storage owner can differ from callee.
                for (uint256 k; k < access.storageAccesses.length; ++k) {
                    ActualColdExportVm.StorageAccess memory item = access.storageAccesses[k];
                    accountCount = _observeAccount(item.account, accounts, accountIndex, accountCount);
                    slotCount = _observeSlot(item.account, item.slot, slots, slotIndex, slotCount);
                }
            }
        }
        assembly ("memory-safe") { mstore(accounts, accountCount) mstore(slots, slotCount) }
    }

    function _tableSize(uint256 maximum) private pure returns (uint256 size) {
        size = 2;
        while (size < maximum * 2) size *= 2;
    }

    function _observeAccount(address account, Account[] memory rows, uint256[] memory index, uint256 count)
        private view returns (uint256)
    {
        uint256 bucket = uint256(keccak256(abi.encode(account))) & (index.length - 1);
        while (index[bucket] != 0) {
            if (rows[index[bucket] - 1].account == account) return count;
            bucket = (bucket + 1) & (index.length - 1);
        }
        rows[count] = Account(account, account.balance, coldVm.getNonce(account), account.code, account.codehash);
        index[bucket] = count + 1;
        return count + 1;
    }

    function _observeSlot(address account, bytes32 slot, Slot[] memory rows, uint256[] memory index, uint256 count)
        private view returns (uint256)
    {
        uint256 bucket = uint256(keccak256(abi.encode(account, slot))) & (index.length - 1);
        while (index[bucket] != 0) {
            Slot memory previous = rows[index[bucket] - 1];
            if (previous.account == account && previous.slot == slot) return count;
            bucket = (bucket + 1) & (index.length - 1);
        }
        rows[count] = Slot(account, slot, coldVm.load(account, slot));
        index[bucket] = count + 1;
        return count + 1;
    }

    function _exportEnvironment(string memory prefix) private {
        bytes32[256] memory previousHashes;
        for (uint256 i; i < previousHashes.length && i < block.number; ++i) {
            previousHashes[i] = blockhash(block.number - i - 1);
        }
        // Complete Paris block reads. Last origin is the OUTER test origin; discovery
        // explicitly pranks purchase sender+origin to transaction inventory's buyer.
        // The RPC consumer must reject any environment opcode it cannot replay exactly.
        coldVm.writeFileBinary(string.concat(prefix, "-environment.abi"), abi.encode(
            uint256(1), block.chainid, block.number, block.timestamp, block.basefee,
            block.gaslimit, block.coinbase, block.prevrandao, tx.gasprice, tx.origin, previousHashes
        ));
    }
}
