// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamCurrentGovernanceStagePlan.t.sol";
import "../../script/current/StreamGovernanceCatalogStagePlan.sol";

/// @dev A deployed selector-bearing target for catalog capacity tests, not a Stream product.
contract StageCatalogTarget {
    function touch() external pure returns (uint256) { return 1; }
}

/// @notice Real catalog/manifest boundary for65 rows and exact completed-prefix observation.
contract StreamCurrentCatalogStagePlanTest is StreamCurrentGovernanceStagePlanTest {
    function testCatalogStage64Then1RequiresObservedExecutionAndFreshManifest() public {
        _initialize();
        StreamGovernanceCatalogStagePlan.Inventory memory saved =
            StreamGovernanceCatalogStagePlan.inventory(configuration.executor, _rows());
        bytes32 savedHash = StreamGovernanceCatalogStagePlan.inventoryHash(saved);
        (GenesisBatch memory first, uint256 next) = this.catalogBatch(saved, savedHash, 0);
        require(next == 64, "first chunk exact bound");
        vm.expectRevert(abi.encodeWithSelector(StreamGovernanceCatalogStagePlan.CatalogPrefixNotObserved.selector));
        this.catalogBatch(saved, savedHash, 64);
        StreamGovernanceStagePlan.Plan memory firstPlan = _build(keccak256("CATALOG_CHUNK_1"), first);
        bytes32 firstId = _schedule(firstPlan);
        vm.warp(firstPlan.notBefore);
        require(this.executeSaved(firstPlan, firstId), "first catalog chunk executes");
        (, , uint256 count, uint64 revision) = configuration.executor.governanceActionPolicyState();
        require(count == saved.baseEntryCount + 64 && revision == saved.baseRevision + 1, "first exact state");
        (GenesisBatch memory second, uint256 done) = this.catalogBatch(saved, savedHash, 64);
        require(done == 65, "one remaining row");
        StreamGovernanceStagePlan.Plan memory secondPlan = _build(keccak256("CATALOG_CHUNK_2"), second);
        require(secondPlan.catalogHash != firstPlan.catalogHash, "new observed catalog");
        bytes32 secondId = _schedule(secondPlan);
        vm.warp(secondPlan.notBefore);
        require(this.executeSaved(secondPlan, secondId), "second fresh catalog chunk executes");
        (, , count, revision) = configuration.executor.governanceActionPolicyState();
        require(count == saved.baseEntryCount + 65 && revision == saved.baseRevision + 2, "all rows retained");
        require(configuration.manifest.streamSystemManifestPointerCount() == 3, "foundation and two exact publications");
        require(!this.executeSaved(firstPlan, firstId), "older completed chunk resumes after next epoch");
    }

    function testCatalogInventoryTamperingAndUnalignedCursorCannotSelectAnotherChunk() public {
        _initialize();
        StreamGovernanceCatalogStagePlan.Inventory memory saved =
            StreamGovernanceCatalogStagePlan.inventory(configuration.executor, _rows());
        bytes32 savedHash = StreamGovernanceCatalogStagePlan.inventoryHash(saved);
        vm.expectRevert(abi.encodeWithSelector(StreamGovernanceCatalogStagePlan.InvalidCatalogInventory.selector));
        this.catalogBatch(saved, savedHash, 1);
        saved.additions[64].targetProfileHash = keccak256("substituted admission");
        vm.expectRevert(abi.encodeWithSelector(StreamGovernanceCatalogStagePlan.InvalidCatalogInventory.selector));
        this.catalogBatch(saved, savedHash, 0);
        (, , uint256 count, uint64 revision) = configuration.executor.governanceActionPolicyState();
        require(count == saved.baseEntryCount && revision == saved.baseRevision, "no catalog mutation");
    }

    function catalogBatch(StreamGovernanceCatalogStagePlan.Inventory memory saved, bytes32 savedHash, uint256 cursor)
        external returns (GenesisBatch memory batch, uint256 next)
    {
        StreamSystemManifest.AggregateState memory current = StreamGenesisManifestPlan.readAggregate(configuration.manifest);
        (address payload, bytes32 hash) = StreamGenesisManifestPlan.writePayload(
            cursor == 0 ? bytes("{\"purpose\":\"first catalog chunk\"}") : bytes("{\"purpose\":\"second catalog chunk\"}")
        );
        StreamSystemManifestUpdate memory update = StreamSystemManifestUpdate(
            hash, "urn:stream:fixture:catalog-chunks", current.discovery.eventCatalogHash,
            current.discovery.compatibilityMatrixHash, current.discovery.numericIdCatalogHash,
            current.discovery.schemaCatalogHash, current.discovery.canonicalizationCatalogHash,
            current.discovery.specBundleHash, current.discovery.reconstructionClientHash
        );
        return StreamGovernanceCatalogStagePlan.nextBatch(saved, savedHash, cursor, configuration.manifest, payload, update);
    }

    function testCatalogRejectsMalformedTailBeforeAnyAdmission() public {
        _initialize();
        GovernanceActionPolicyEntry[] memory rows = _rows();
        (, bytes32 catalog, uint256 count, uint64 revision) = configuration.executor.governanceActionPolicyState();
        // Changing a non-key field preserves ordering and the first 64 valid rows.
        rows[64].targetProfileHash = bytes32(0);
        vm.expectRevert(abi.encodeWithSelector(IStreamGovernanceExecutor.InvalidGovernanceActionPolicyEntry.selector, 64));
        this.bindInventory(rows);
        (, bytes32 observedCatalog, uint256 observedCount, uint64 observedRevision) = configuration.executor.governanceActionPolicyState();
        require(observedCatalog == catalog && observedCount == count && observedRevision == revision, "no partial catalog");
        require(configuration.manifest.streamSystemManifestPointerCount() == 1, "no partial publication");
    }

    function testCatalogRejectsDelegatedTargetBeforeAnyAdmission() public {
        _initialize();
        GovernanceActionPolicyEntry[] memory rows = _rows();
        address delegated = rows[64].target;
        vm.etch(delegated, abi.encodePacked(hex"ef0100", address(0x6529)));
        rows[64].targetCodeHash = delegated.codehash;
        vm.expectRevert(abi.encodeWithSelector(StreamGovernanceCatalogStagePlan.InvalidCatalogInventory.selector));
        this.bindInventory(rows);
        require(configuration.manifest.streamSystemManifestPointerCount() == 1, "no partial publication");
    }

    function bindInventory(GovernanceActionPolicyEntry[] memory rows) external view
        returns (StreamGovernanceCatalogStagePlan.Inventory memory)
    {
        return StreamGovernanceCatalogStagePlan.inventory(configuration.executor, rows);
    }

    function _rows() private returns (GovernanceActionPolicyEntry[] memory rows) {
        rows = new GovernanceActionPolicyEntry[](65);
        for (uint256 i; i < rows.length; ++i) {
            address target = address(new StageCatalogTarget());
            rows[i] = GovernanceActionPolicyEntry(
                1, target, StageCatalogTarget.touch.selector, target.codehash,
                keccak256(abi.encode(configuration.deploymentHash, target)), 1, 0, 0, bytes32(0)
            );
        }
        for (uint256 i = 1; i < rows.length; ++i) {
            for (uint256 j = i; j > 0 && _key(rows[j - 1]) > _key(rows[j]); --j) {
                (rows[j - 1], rows[j]) = (rows[j], rows[j - 1]);
            }
        }
    }

    function _key(GovernanceActionPolicyEntry memory row) private pure returns (bytes32) {
        return keccak256(abi.encode(row.actionClass, row.target, row.selector));
    }
}
