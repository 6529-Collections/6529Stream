// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamGovernanceStagePlan.sol";

/// @notice Partition an immutable admission inventory into catalog-sized sequential stages.
/// @dev Every later chunk is prepared only after the prior catalog and manifest tail execute.
///      Registry/role actions scheduled under a prior catalog must execute before extension.
///      The operator must also compare additions with its retained base admission inventory:
///      the Executor exposes an aggregate commitment, not enumerable historical entries.
library StreamGovernanceCatalogStagePlan {
    error InvalidCatalogInventory();
    error CatalogPrefixNotObserved();

    struct Inventory {
        uint256 chainId;
        address executor;
        bytes32 executorCodeHash;
        bytes32 candidateProfileHash;
        bytes32 baseCatalogHash;
        uint256 baseEntryCount;
        uint64 baseRevision;
        GovernanceActionPolicyEntry[] additions;
    }

    function inventoryHash(Inventory memory inventory) internal pure returns (bytes32) {
        return keccak256(abi.encode(inventory));
    }

    /// @notice Bind the complete sorted admission list before its first stage is signed.
    function inventory(StreamGovernanceExecutor executor, GovernanceActionPolicyEntry[] memory rows)
        internal view returns (Inventory memory result)
    {
        result.chainId = block.chainid;
        result.executor = address(executor);
        result.executorCodeHash = address(executor).codehash;
        (result.candidateProfileHash, result.baseCatalogHash, result.baseEntryCount, result.baseRevision) =
            executor.governanceActionPolicyState();
        result.additions = rows;
        _validate(result);
    }

    /// @notice Build the next <=64 rows plus a fresh publication, after observing its prefix.
    /// @dev payload/update must already identify retained bytes. This method creates no blob
    ///      and no schedule. Save its returned batch through StreamGovernanceStagePlan.
    function nextBatch(
        Inventory memory saved,
        bytes32 savedInventoryHash,
        uint256 completedRows,
        StreamSystemManifest manifest,
        address payloadRoot,
        StreamSystemManifestUpdate memory update
    ) internal view returns (GenesisBatch memory batch, uint256 nextCompletedRows) {
        if (savedInventoryHash == bytes32(0) || inventoryHash(saved) != savedInventoryHash) {
            revert InvalidCatalogInventory();
        }
        _validate(saved);
        if (completedRows >= saved.additions.length || completedRows % 64 != 0) {
            revert InvalidCatalogInventory();
        }
        StreamGovernanceExecutor executor = StreamGovernanceExecutor(payable(saved.executor));
        bytes32 expected = saved.baseCatalogHash;
        uint256 expectedCount = saved.baseEntryCount;
        uint64 expectedRevision = saved.baseRevision;
        for (uint256 offset; offset < completedRows; offset += 64) {
            (expected,,,) = StreamGovernanceActionPolicy.extensionTransition(
                saved.executor, saved.candidateProfileHash, expected, expectedCount,
                expectedRevision, _chunk(saved.additions, offset)
            );
            expectedCount += 64;
            expectedRevision += 1;
        }
        (bytes32 candidate, bytes32 catalog, uint256 count, uint64 revision) = executor.governanceActionPolicyState();
        if (candidate != saved.candidateProfileHash || catalog != expected
            || count != expectedCount || revision != expectedRevision) revert CatalogPrefixNotObserved();
        GovernanceActionPolicyEntry[] memory rows = _chunk(saved.additions, completedRows);
        (bytes32 next, bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            StreamGovernanceActionPolicy.extensionTransition(saved.executor, candidate, catalog, count, revision, rows);
        batch.actionClass = 3;
        batch.calls = new GovernanceCall[](2);
        batch.callDatas = new bytes[](2);
        batch.callDatas[0] = abi.encodeCall(executor.extendGovernanceActionPolicy, (revision, catalog, next, rows));
        batch.calls[0] = StreamCurrentStackPlan.call(saved.executor, batch.callDatas[0], scope, oldHash, newHash);
        StreamSystemManifest.AggregateState memory current = StreamGenesisManifestPlan.readAggregate(manifest);
        // Publishing through any foreign manifest is rejected before preparing a root call.
        (bool ok, bytes memory raw) = saved.executor.staticcall(
            abi.encodeCall(IStreamGovernanceExecutor.systemManifestBootstrapState, ())
        );
        if (!ok) revert InvalidCatalogInventory();
        StreamGovernanceManifest.BootstrapStateView memory bootstrap =
            abi.decode(raw, (StreamGovernanceManifest.BootstrapStateView));
        if (!bootstrap.bound || !bootstrap.isSealed || bootstrap.systemManifestSatellite != address(manifest)) {
            revert InvalidCatalogInventory();
        }
        (batch.calls[1], batch.callDatas[1]) = StreamGenesisManifestPlan.publicationCall(manifest, payloadRoot, update, current.modules);
        nextCompletedRows = completedRows + rows.length;
    }

    function _chunk(GovernanceActionPolicyEntry[] memory allRows, uint256 offset)
        private pure returns (GovernanceActionPolicyEntry[] memory rows)
    {
        uint256 count = allRows.length - offset;
        if (count > 64) count = 64;
        rows = new GovernanceActionPolicyEntry[](count);
        for (uint256 i; i < count; ++i) rows[i] = allRows[offset + i];
    }

    function _validate(Inventory memory saved) private view {
        if (saved.chainId != block.chainid || saved.executor.code.length == 0
            || saved.executor.codehash != saved.executorCodeHash || saved.candidateProfileHash == bytes32(0)
            || saved.baseCatalogHash == bytes32(0) || saved.additions.length == 0
            || saved.baseEntryCount > 1024 || saved.additions.length > 1024 - saved.baseEntryCount) {
            revert InvalidCatalogInventory();
        }
        // Validate every row before allowing any first chunk to execute. Hashing an
        // extension alone does not validate a malformed row in a later chunk.
        StreamGovernanceActionPolicy.expectedCatalogHash(
            saved.executor, saved.candidateProfileHash, saved.additions
        );
        for (uint256 i; i < saved.additions.length; ++i) {
            GovernanceActionPolicyEntry memory row = saved.additions[i];
            // This product-admission planner supports deployed contract targets only.
            if (row.target.code.length == 0 || row.target.codehash != row.targetCodeHash
                || _delegatedEOA(row.target)) revert InvalidCatalogInventory();
        }
    }

    function _delegatedEOA(address target) private view returns (bool) {
        bytes memory code = target.code;
        return code.length == 23 && code[0] == 0xef && code[1] == 0x01 && code[2] == 0x00;
    }
}
