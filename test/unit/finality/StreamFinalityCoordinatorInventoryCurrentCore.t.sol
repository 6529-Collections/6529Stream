// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../helpers/ScopeMembershipCoreFixture.sol";
import "../../../smart-contracts/domains/finality/StreamFinalityCoordinatorInventory.sol";

/// @dev Core really invokes this source. Entropy authorization/policy/output are explicit boundaries.
contract InventoryReplacementEntropyBoundary {
    address public immutable core;
    uint256 public callbacks;

    constructor(address c) {
        core = c;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == 0x01ffc9a7 || id == type(IStreamEntropyCoordinator).interfaceId;
    }

    function onTokenMinted(uint256 cid, uint256 id, address recipient, bytes32 commitment)
        external
    {
        require(
            msg.sender == core && cid != 0 && id != 0 && recipient == address(0xbeef)
                && commitment != 0
        );
        ++callbacks;
    }
}

/// @notice Actual Core/Executor/Safe/module registry and actual published scope membership.
contract StreamFinalityCoordinatorInventoryCurrentCoreTest is ScopeMembershipCoreFixture {
    function _replace() private returns (InventoryReplacementEntropyBoundary next) {
        next = new InventoryReplacementEntropyBoundary(address(configuration.core));
        StreamModuleRegistration[] memory entries = new StreamModuleRegistration[](1);
        entries[0] = StreamModuleRegistration(
            address(next),
            keccak256("ENTROPY_COORDINATOR"),
            keccak256("inventory replacement entropy boundary"),
            type(IStreamEntropyCoordinator).interfaceId,
            500000,
            address(next).codehash,
            configuration.deploymentHash,
            keccak256("inventory replacement manifest"),
            "ipfs://inventory/replacement"
        );
        (GovernanceCall[] memory reg, bytes[] memory data) =
            StreamCurrentStackPlan.registrationCalls(configuration.registry, entries);
        _runBatch(1, reg, data);
        bytes32[] memory kinds = new bytes32[](1);
        kinds[0] = keccak256("ENTROPY_COORDINATOR");
        (GovernanceCall[] memory pointers, bytes[] memory pointerData) = StreamCurrentStackPlan.pointerCalls(
            configuration.core, configuration.registry, kinds, entries
        );
        GovernanceCall[] memory calls = new GovernanceCall[](2);
        bytes[] memory payloads = new bytes[](2);
        calls[0] = pointers[0];
        payloads[0] = pointerData[0];
        StreamSystemManifest.ModuleAddresses memory modules =
        StreamGenesisManifestPlan.readAggregate(configuration.manifest).modules;
        modules.entropyCoordinator = address(next);
        (calls[1], payloads[1]) =
            _publication(modules, keccak256("inventory governed coordinator replacement"));
        _runBatch(3, calls, payloads);
    }

    function testActualCoreRetainsOriginalsAcrossGovernedReplacementAndBurn() public {
        _initializeScope();
        uint256[] memory ids = new uint256[](3);
        ids[0] = scopeManager.mint(address(configuration.core), 1, address(0xbeef));
        InventoryReplacementEntropyBoundary next = _replace();
        ids[1] = scopeManager.mint(address(configuration.core), 1, address(0xbeef));
        ids[2] = scopeManager.mint(address(configuration.core), 1, address(0xbeef));
        require(configuration.core.coordinatorAtMint(ids[0]) == address(scopeEntropy));
        require(
            configuration.core.coordinatorAtMint(ids[1]) == address(next) && next.callbacks() == 2
        );
        scopeInventory.appendCollectionTokens(1, ids);
        StreamFinalityCoordinatorInventory host = new StreamFinalityCoordinatorInventory(
            address(configuration.core), address(scopeMembership), 100000, 2000000
        );
        StreamFinalityScope memory collection =
            StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0);
        bytes32 plan = host.beginInventory(collection);
        host.appendInventory(plan, 1);
        vm.prank(address(0xbeef));
        configuration.core.burn(ids[0]);
        host.appendInventory(plan, 256);
        require(host.requireCompleteInventory(plan).coordinatorCount == 2);
        require(host.coordinatorAt(plan, 0).coordinator == address(scopeEntropy));
        require(host.coordinatorAt(plan, 1).coordinator == address(next));
        require(host.requireCoordinator(plan, 0).indexedCodeHash == address(scopeEntropy).codehash);
        require(configuration.core.tokenLifecycle(ids[0]) == 3);
        require(address(host).code.length <= 24576);
    }

    function testActualPublishedSubsetRetainsOldAndNewSourcesAfterLaterParentMint() public {
        _initializeScope();
        uint256[] memory ids = new uint256[](2);
        ids[0] = scopeManager.mint(address(configuration.core), 1, address(0xbeef));
        InventoryReplacementEntropyBoundary next = _replace();
        ids[1] = scopeManager.mint(address(configuration.core), 1, address(0xbeef));
        scopeInventory.appendCollectionTokens(1, ids);
        StreamFinalityCoordinatorInventory host = new StreamFinalityCoordinatorInventory(
            address(configuration.core), address(scopeMembership), 100000, 2000000
        );
        bytes32[] memory plans = new bytes32[](3);
        for (uint8 family = 2; family <= 4; ++family) {
            (, StreamFinalityScope memory scope) =
                _scopePublish(family, ids, "ipfs://inventory/actual-family");
            scopeMembership.continueScopeMembership(scope, 1);
            plans[family - 2] = host.beginInventory(scope);
            host.appendInventory(plans[family - 2], 256);
        }
        uint256 later = scopeManager.mint(address(configuration.core), 1, address(0xbeef));
        require(later != ids[1] && configuration.core.collectionMintedEver(1) == 3);
        for (uint256 i; i < 3; ++i) {
            require(host.requireCompleteInventory(plans[i]).tokenCount == 2);
            require(host.coordinatorAt(plans[i], 0).coordinator == address(scopeEntropy));
            require(host.requireCoordinator(plans[i], 1).coordinator == address(next));
        }
        StreamFinalityScope memory token =
            StreamFinalityScope(StreamFinalityScopeType.TOKEN, 1, ids[0], 0);
        bytes32 one = host.beginInventory(token);
        host.appendInventory(one, 1);
        require(host.requireCompleteInventory(one).coordinatorCount == 1);
        require(host.coordinatorAt(one, 0).coordinator == address(scopeEntropy));
    }
}
