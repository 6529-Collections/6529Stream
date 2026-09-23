// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../helpers/ScopeMembershipPublicationFixture.sol";
import "../../helpers/OfficialSafeFixture.sol";
import "../../../smart-contracts/domains/finality/StreamFinalityCoordinatorInventory.sol";

interface CoordinatorInventoryVm {
    function mockCall(address target, bytes calldata input, bytes calldata output) external;
}

/// @dev Runtime identity only; entropy policy and seed production are separate evidence.
contract CoordinatorInventorySourceBoundary {
    function marker() external pure returns (uint256) {
        return 1;
    }
}

/// @notice Actual published membership/Metadata/Schema/Store/Inventory; explicit Core and Executor boundaries.
contract StreamFinalityCoordinatorInventoryTest is
    ScopeMembershipPublicationFixture,
    OfficialSafeFixture
{
    function _newInventory() private returns (StreamFinalityCoordinatorInventory) {
        return new StreamFinalityCoordinatorInventory(
            address(core), address(membership), 100000, 2000000
        );
    }

    function _collection() private pure returns (StreamFinalityScope memory) {
        return StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0);
    }

    function _original(uint256 id, address target) private {
        CoordinatorInventoryVm(address(vm))
            .mockCall(
                address(core),
                abi.encodeCall(IStreamCoreIdentity.coordinatorAtMint, (id)),
                abi.encode(target)
            );
    }

    function _setup(uint256 count)
        private
        returns (
            StreamFinalityCoordinatorInventory host,
            uint256[] memory ids,
            address a,
            address b
        )
    {
        host = _newInventory();
        ids = _tokens(count);
        _index(ids, 0, count);
        a = address(new CoordinatorInventorySourceBoundary());
        b = address(new CoordinatorInventorySourceBoundary());
        for (uint256 i; i < count; ++i) {
            _original(ids[i], i % 2 == 0 ? a : b);
        }
    }

    function testMixedOriginalsDeduplicateInFirstOccurrenceOrderAndKeepBurns() public {
        (StreamFinalityCoordinatorInventory host, uint256[] memory ids, address a, address b) =
            _setup(3);
        core.setPointer(keccak256("ENTROPY_COORDINATOR"), b);
        core.setToken(ids[0], 1, 1, 3);
        bytes32 plan = host.beginInventory(_collection());
        vm.recordLogs();
        host.appendInventory(plan, 1);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        require(logs.length == 2 && logs[0].emitter == address(host));
        require(
            logs[0].topics[0]
                == keccak256("OriginalCoordinatorIndexed(bytes32,uint256,address,bytes32,uint256)")
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamFinalityCoordinatorInventory.InventoryIncomplete.selector, plan
            )
        );
        host.requireCompleteInventory(plan);
        host.appendInventory(plan, 2);
        IStreamFinalityCoordinatorInventory.Progress memory f = host.requireCompleteInventory(plan);
        require(
            f.processedTokens == 3 && f.coordinatorCount == 2 && f.complete && f.commitment != 0
        );
        IStreamFinalityCoordinatorInventory.Coordinator memory first =
            host.requireCoordinator(plan, 0);
        require(
            first.coordinator == a && first.firstTokenIndex == 0
                && first.indexedCodeHash == a.codehash
        );
        require(
            host.coordinatorAt(plan, 1).coordinator == b
                && host.coordinatorAt(plan, 1).firstTokenIndex == 1
        );
        require(host.beginInventory(_collection()) == plan);
    }

    function testBatchFailureRollsBackEarlierNewCoordinatorAndRetries() public {
        (StreamFinalityCoordinatorInventory host, uint256[] memory ids, address a, address b) =
            _setup(2);
        bytes32 plan = host.beginInventory(_collection());
        bytes32 before = keccak256(abi.encode(host.inventoryProgress(plan)));
        _original(ids[1], address(0));
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamFinalityCoordinatorInventory.InventoryDependency.selector, address(0)
            )
        );
        host.appendInventory(plan, 2);
        require(keccak256(abi.encode(host.inventoryProgress(plan))) == before);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamFinalityCoordinatorInventory.InventoryIndex.selector, uint256(0)
            )
        );
        host.coordinatorAt(plan, 0);
        _original(ids[1], b);
        host.appendInventory(plan, 2);
        require(
            host.requireCompleteInventory(plan).coordinatorCount == 2
                && host.coordinatorAt(plan, 0).coordinator == a
        );
    }

    function testLaterMintInvalidatesCurrentPlanButPreservesHistoryAndMakesNewPlan() public {
        (StreamFinalityCoordinatorInventory host,,, address b) = _setup(1);
        bytes32 plan = host.beginInventory(_collection());
        host.appendInventory(plan, 1);
        bytes32 historical = keccak256(abi.encode(host.inventoryProgress(plan)));
        core.setToken(6, 1, 2, 2);
        _original(6, b);
        uint256[] memory one = new uint256[](1);
        one[0] = 6;
        inventory.appendCollectionTokens(1, one);
        vm.expectRevert(
            abi.encodeWithSelector(StreamFinalityCoordinatorInventory.InventoryStale.selector, plan)
        );
        host.requireCompleteInventory(plan);
        require(keccak256(abi.encode(host.inventoryProgress(plan))) == historical);
        bytes32 next = host.beginInventory(_collection());
        require(next != plan && host.inventoryProgress(next).processedTokens == 0);
        host.appendInventory(next, 256);
        require(host.requireCompleteInventory(next).tokenCount == 2);
    }

    function testAllPublishedFamiliesKeepExactSubsetAfterParentMint() public {
        (StreamFinalityCoordinatorInventory host, uint256[] memory ids,, address b) = _setup(2);
        for (uint8 family = 2; family <= 4; ++family) {
            bytes32 record = _publish(_manifest(family, ids), "ipfs://coordinator-subset");
            StreamFinalityScope memory scope = membership.beginScopeMembership(record);
            membership.continueScopeMembership(scope, 1);
            bytes32 plan = host.beginInventory(scope);
            host.appendInventory(plan, 256);
            require(host.requireCompleteInventory(plan).tokenCount == 2);
            core.setToken(9, 1, 3, 2);
            _original(9, b);
            require(host.requireCompleteInventory(plan).tokenCount == 2);
            (StreamFinalityScope memory stored, StreamScopeMembershipFacts memory facts) =
                host.inventoryScope(plan);
            require(stored.scopeId == scope.scopeId && facts.sourceRecordHash == record);
        }
    }

    function testEntryRuntimeChangeRejectsLiveReadWithoutErasingHistory() public {
        (StreamFinalityCoordinatorInventory host,, address a,) = _setup(1);
        bytes32 plan = host.beginInventory(_collection());
        host.appendInventory(plan, 1);
        bytes32 captured = host.coordinatorAt(plan, 0).indexedCodeHash;
        vm.etch(a, hex"60006000f3");
        require(host.requireCompleteInventory(plan).complete);
        require(host.coordinatorAt(plan, 0).indexedCodeHash == captured);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamFinalityCoordinatorInventory.InventoryDependency.selector, a
            )
        );
        host.requireCoordinator(plan, 0);
    }

    function testRepeatedSourceCannotReplaceItsIndexedRuntime() public {
        (StreamFinalityCoordinatorInventory host, uint256[] memory ids, address a,) = _setup(2);
        _original(ids[1], a);
        bytes32 plan = host.beginInventory(_collection());
        host.appendInventory(plan, 1);
        vm.etch(a, hex"60006000f3");
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamFinalityCoordinatorInventory.InventoryDependency.selector, a
            )
        );
        host.appendInventory(plan, 1);
        require(host.inventoryProgress(plan).processedTokens == 1);
    }

    function testPreparedForeignAndNoncanonicalLifecycleRejectAfterMembershipAdmission() public {
        (StreamFinalityCoordinatorInventory host, uint256[] memory ids,,) = _setup(1);
        bytes32 plan = host.beginInventory(_collection());
        for (uint8 fault = 1; fault <= 3; ++fault) {
            CoordinatorInventoryVm(address(vm))
                .mockCall(
                    address(core),
                    abi.encodeCall(IStreamCoreIdentity.tokenCollectionIdentity, (ids[0])),
                    abi.encode(
                        uint256(1),
                        fault == 2 ? uint256(2) : uint256(1),
                        uint256(1),
                        fault == 3 ? uint256(2) : uint256(0)
                    )
                );
            CoordinatorInventoryVm(address(vm))
                .mockCall(
                    address(core),
                    abi.encodeCall(IStreamCoreIdentity.tokenLifecycle, (ids[0])),
                    abi.encode(fault == 1 ? uint256(1) : uint256(2))
                );
            vm.expectRevert(
                abi.encodeWithSelector(
                    StreamFinalityCoordinatorInventory.InventoryToken.selector, ids[0]
                )
            );
            host.appendInventory(plan, 1);
            require(host.inventoryProgress(plan).processedTokens == 0);
        }
    }

    function testEverySavedMembershipWordIsCompared() public {
        (StreamFinalityCoordinatorInventory host,,,) = _setup(1);
        bytes32 plan = host.beginInventory(_collection());
        host.appendInventory(plan, 1);
        bytes memory original = abi.encode(membership.requireScopeMembership(_collection()));
        for (uint256 word = 1; word < 8; ++word) {
            bytes memory changed = abi.encode(membership.requireScopeMembership(_collection()));
            // Restore the original before the next independent mutation.
            changed = bytes.concat(original);
            assembly ("memory-safe") {
                let at := add(add(changed, 32), mul(word, 32))
                mstore(at, xor(mload(at), 1))
            }
            CoordinatorInventoryVm(address(vm))
                .mockCall(
                    address(membership),
                    abi.encodeCall(
                        IStreamFinalityScopeMembership.requireScopeMembership, (_collection())
                    ),
                    changed
                );
            vm.expectRevert(
                abi.encodeWithSelector(
                    StreamFinalityCoordinatorInventory.InventoryStale.selector, plan
                )
            );
            host.requireCompleteInventory(plan);
            CoordinatorInventoryVm(address(vm))
                .mockCall(
                    address(membership),
                    abi.encodeCall(
                        IStreamFinalityScopeMembership.requireScopeMembership, (_collection())
                    ),
                    original
                );
        }
    }

    function testEmptyScopeIsCompleteEmptyInventoryNotEntropyReadiness() public {
        StreamFinalityCoordinatorInventory host = _newInventory();
        bytes32 plan = host.beginInventory(_collection());
        IStreamFinalityCoordinatorInventory.Progress memory p = host.requireCompleteInventory(plan);
        require(p.complete && p.tokenCount == 0 && p.coordinatorCount == 0 && p.commitment != 0);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamFinalityCoordinatorInventory.InventoryIndex.selector, uint256(0)
            )
        );
        host.requireCoordinator(plan, 0);
    }

    function testUnknownBatchAndDependencyFailureLeaveNoProgress() public {
        (StreamFinalityCoordinatorInventory host,,,) = _setup(1);
        require(!host.inventoryProgress(bytes32(uint256(77))).exists);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamFinalityCoordinatorInventory.InventoryUnknown.selector, bytes32(uint256(77))
            )
        );
        host.appendInventory(bytes32(uint256(77)), 1);
        bytes32 plan = host.beginInventory(_collection());
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamFinalityCoordinatorInventory.InventoryBatch.selector, uint256(0)
            )
        );
        host.appendInventory(plan, 0);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamFinalityCoordinatorInventory.InventoryBatch.selector, uint256(257)
            )
        );
        host.appendInventory(plan, 257);
        vm.etch(address(membership), hex"60006000f3");
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamFinalityCoordinatorInventory.InventoryDependency.selector, address(membership)
            )
        );
        host.appendInventory(plan, 1);
        require(host.inventoryProgress(plan).processedTokens == 0);
    }

    function testChainAndMalformedScopeRejectButHistoricalReadsRemain() public {
        (StreamFinalityCoordinatorInventory host, uint256[] memory ids,,) = _setup(1);
        StreamFinalityScope memory token =
            StreamFinalityScope(StreamFinalityScopeType.TOKEN, 1, ids[0], 0);
        bytes32 plan = host.beginInventory(token);
        host.appendInventory(plan, 1);
        token.collectionId = 2;
        vm.expectRevert();
        host.beginInventory(token);
        vm.chainId(block.chainid + 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamFinalityCoordinatorInventory.InventoryConfiguration.selector
            )
        );
        host.requireCompleteInventory(plan);
        require(host.inventoryProgress(plan).complete);
    }

    function testOversizedCoreResponseRejectedWithoutCopyingIt() public {
        (StreamFinalityCoordinatorInventory host, uint256[] memory ids, address a,) = _setup(1);
        bytes32 plan = host.beginInventory(_collection());
        CoordinatorInventoryVm(address(vm))
            .mockCall(
                address(core),
                abi.encodeCall(IStreamCoreIdentity.coordinatorAtMint, (ids[0])),
                abi.encode(a, uint256(99))
            );
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamFinalityCoordinatorInventory.InventoryRead.selector,
                address(core),
                IStreamCoreIdentity.coordinatorAtMint.selector
            )
        );
        host.appendInventory(plan, 1);
        require(host.inventoryProgress(plan).processedTokens == 0);
    }

    function testMaximumBatchTraversesAllTokens() public {
        (StreamFinalityCoordinatorInventory host,,,) = _setup(256);
        bytes32 plan = host.beginInventory(_collection());
        host.appendInventory(plan, 256);
        require(host.requireCompleteInventory(plan).processedTokens == 256);
    }

    function testFuzzCompleteCommitmentAndBatchIndependence(uint8 rawCount, uint8 rawStep) public {
        uint256 count = uint256(rawCount % 16) + 1;
        uint256 step = uint256(rawStep % 8) + 1;
        (StreamFinalityCoordinatorInventory host, uint256[] memory ids, address a, address b) =
            _setup(count);
        bytes32 plan = host.beginInventory(_collection());
        while (!host.inventoryProgress(plan).complete) host.appendInventory(plan, step);
        bytes32 chain =
            keccak256(abi.encode(keccak256("6529STREAM_COORDINATOR_TOKEN_CHAIN_V1"), plan));
        for (uint256 i; i < count; ++i) {
            chain = keccak256(
                abi.encode(
                    keccak256("6529STREAM_COORDINATOR_TOKEN_APPEND_V1"),
                    chain,
                    i,
                    ids[i],
                    i % 2 == 0 ? a : b,
                    i % 2
                )
            );
        }
        bytes32 sources =
            keccak256(abi.encode(keccak256("6529STREAM_COORDINATOR_SOURCE_CHAIN_V1"), plan));
        for (uint256 i; i < (count == 1 ? 1 : 2); ++i) {
            address source = i == 0 ? a : b;
            sources = keccak256(
                abi.encode(
                    keccak256("6529STREAM_COORDINATOR_SOURCE_APPEND_V1"),
                    sources,
                    i,
                    source,
                    source.codehash,
                    i
                )
            );
        }
        IStreamFinalityCoordinatorInventory.Progress memory p = host.requireCompleteInventory(plan);
        require(p.tokenChain == chain && p.coordinatorChain == sources);
        require(
            p.commitment
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_COORDINATOR_INVENTORY_COMPLETE_V1"),
                        plan,
                        count,
                        p.coordinatorCount,
                        chain,
                        sources
                    )
                )
        );
    }

    function testThresholdSafeAllOperativeSelectorsAndReadPaths() public {
        (StreamFinalityCoordinatorInventory host,,,) = _setup(1);
        uint256[] memory keys = new uint256[](2);
        keys[0] = 765001;
        keys[1] = 765002;
        OfficialSafe safe =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 865001);
        require(
            executeSafe(
                safe,
                keys,
                address(host),
                0,
                abi.encodeCall(host.beginInventory, (_collection())),
                0
            )
        );
        bytes32 plan = host.beginInventory(_collection());
        require(
            executeSafe(
                safe, keys, address(host), 0, abi.encodeCall(host.appendInventory, (plan, 1)), 0
            )
        );
        require(
            executeSafe(
                safe, keys, address(host), 0, abi.encodeCall(host.inventoryProgress, (plan)), 0
            )
        );
        require(
            executeSafe(
                safe, keys, address(host), 0, abi.encodeCall(host.inventoryScope, (plan)), 0
            )
        );
        require(
            executeSafe(
                safe, keys, address(host), 0, abi.encodeCall(host.coordinatorAt, (plan, 0)), 0
            )
        );
        require(
            executeSafe(
                safe,
                keys,
                address(host),
                0,
                abi.encodeCall(host.requireCompleteInventory, (plan)),
                0
            )
        );
        require(
            executeSafe(
                safe, keys, address(host), 0, abi.encodeCall(host.requireCoordinator, (plan, 0)), 0
            )
        );
        require(safe.nonce() == 7 && host.requireCompleteInventory(plan).complete);
    }

    function testLowParentGasRollbackAndRetry() public {
        (StreamFinalityCoordinatorInventory host,,,) = _setup(1);
        bytes32 plan = host.beginInventory(_collection());
        bytes32 before = keccak256(abi.encode(host.inventoryProgress(plan)));
        (bool ok, bytes memory result) =
            address(host).call{ gas: 1000000 }(abi.encodeCall(host.appendInventory, (plan, 1)));
        require(!ok && result.length == 36);
        bytes4 selector;
        assembly ("memory-safe") { selector := mload(add(result, 32)) }
        require(selector == StreamFinalityCoordinatorInventory.InventoryParentGas.selector);
        require(keccak256(abi.encode(host.inventoryProgress(plan))) == before);
        host.appendInventory(plan, 1);
        require(host.requireCompleteInventory(plan).complete);
    }

    function testThresholdSafeBindingGettersAndInterface() public {
        StreamFinalityCoordinatorInventory host = _newInventory();
        uint256[] memory keys = new uint256[](2);
        keys[0] = 765101;
        keys[1] = 765102;
        OfficialSafe safe =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 865101);
        bytes4[8] memory getters = [
            bytes4(keccak256("core()")),
            bytes4(keccak256("scopeMembershipHost()")),
            bytes4(keccak256("coreCodeHash()")),
            bytes4(keccak256("scopeMembershipCodeHash()")),
            bytes4(keccak256("deploymentChainId()")),
            bytes4(keccak256("readGas()")),
            bytes4(keccak256("membershipGas()")),
            bytes4(keccak256("MAX_BATCH()"))
        ];
        for (uint256 i; i < getters.length; ++i) {
            require(
                executeSafe(safe, keys, address(host), 0, abi.encodeWithSelector(getters[i]), 0)
            );
        }
        require(
            executeSafe(
                safe,
                keys,
                address(host),
                0,
                abi.encodeCall(
                    host.supportsInterface, (type(IStreamFinalityCoordinatorInventory).interfaceId)
                ),
                0
            )
        );
        require(
            safe.nonce() == 9 && host.core() == address(core)
                && host.scopeMembershipHost() == address(membership)
        );
        require(
            host.coreCodeHash() == address(core).codehash
                && host.scopeMembershipCodeHash() == address(membership).codehash
        );
        require(
            host.deploymentChainId() == block.chainid && host.readGas() == 100000
                && host.membershipGas() == 2000000 && host.MAX_BATCH() == 256
        );
        require(
            host.supportsInterface(type(IStreamFinalityCoordinatorInventory).interfaceId)
                && host.supportsInterface(type(IERC165).interfaceId)
        );
        require(!host.supportsInterface(0xffffffff));
    }
}
