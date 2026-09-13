// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../helpers/ScopeMembershipPublicationFixture.sol";
import "../../helpers/EntropyTimeTestMocks.sol";
import "../../helpers/EntropyFinalityEvidenceFixture.sol";
import "../../helpers/OfficialSafeFixture.sol";
import "../../mocks/MockEntropyRoleRegistry.sol";
import "../../mocks/MockStreamEntropyProvider.sol";
import "../../../smart-contracts/domains/entropy/StreamEntropyCoordinator.sol";
import "../../../smart-contracts/domains/finality/StreamFinalityCoordinatorInventory.sol";
import "../../../smart-contracts/domains/finality/StreamFinalityCoordinatorPolicyReads.sol";

interface CoordinatorPolicyVm {
    function mockCall(address target, bytes calldata input, bytes calldata output) external;
}

contract FixedCoordinatorPolicyConsumer {
    StreamFinalityCoordinatorPolicyReads.Dependencies private dependencies;

    constructor(StreamFinalityCoordinatorPolicyReads.Dependencies memory d) {
        dependencies = d;
    }

    function read(StreamFinalityScope calldata scope, bytes32 plan)
        external
        view
        returns (StreamFinalityCoordinatorPolicyEvidence memory)
    {
        return StreamFinalityCoordinatorPolicyReads.requireCurrent(dependencies, scope, plan);
    }
}

/// @notice Real Metadata/Schema/Store/membership/inventory and two native Coordinators.
/// @dev Core identity and governance are typed fixtures; external randomness is a provider mock.
contract StreamFinalityCoordinatorPolicyReadsTest is
    ScopeMembershipPublicationFixture,
    EntropyTimeAuthorityFixture,
    OfficialSafeFixture
{
    MockEntropyRoleRegistry public roleRegistry;

    struct Fixture {
        StreamFinalityCoordinatorInventory sources;
        FixedCoordinatorPolicyConsumer reader;
        StreamEntropyCoordinator first;
        StreamEntropyCoordinator second;
        uint256[] ids;
        bytes32 plan;
    }
    CoordinatorPolicyVm private constant cheat =
        CoordinatorPolicyVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function _scope() private pure returns (StreamFinalityScope memory) {
        return StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0);
    }

    function _native(bool locked) private returns (StreamEntropyCoordinator n) {
        if (address(roleRegistry) == address(0)) {
            roleRegistry = new MockEntropyRoleRegistry(address(this));
        }
        core.setPointer(
            keccak256("MODULE_REGISTRY"), address(new EntropyFinalityModuleBoundary(address(this)))
        );
        cheat.mockCall(
            address(core),
            abi.encodeWithSignature("collectionFreezeStatus(uint256)", 1),
            abi.encode(false)
        );
        n = new StreamEntropyCoordinator(
            StreamEntropyCoordinator.DeploymentConfig(
                address(core),
                address(this),
                address(roleRegistry),
                EntropyTimeTestConfigs.parameters(),
                keccak256("deployment"),
                "ipfs://native-policy",
                keccak256("native manifest")
            )
        );
        n.configureCollection(
            1, address(new MockStreamEntropyProvider(address(n))), keccak256("salt"), true, 10
        );
        n.configureCollectionRevealPolicy(1, 0, keccak256("ROLE_ENTROPY_REVEAL_OWNER"), 10, 0);
        if (locked) n.registerEntropyScope(1, 1, keccak256("scope"));
    }

    function _dependencies(StreamFinalityCoordinatorInventory sources)
        private
        view
        returns (StreamFinalityCoordinatorPolicyReads.Dependencies memory d)
    {
        d.targets = [address(core), address(metadata), address(membership), address(sources)];
        for (uint256 i; i < 4; ++i) {
            d.codeHashes[i] = d.targets[i].codehash;
        }
        d.chainId = block.chainid;
        d.readGas = 500000;
        d.inventoryGas = 3000000;
    }

    function _setup(uint256 count, bool secondLocked) private returns (Fixture memory f) {
        f.first = _native(true);
        f.second = _native(secondLocked);
        f.sources = new StreamFinalityCoordinatorInventory(
            address(core), address(membership), 100000, 2000000
        );
        f.reader = new FixedCoordinatorPolicyConsumer(_dependencies(f.sources));
        f.ids = _tokens(count);
        _index(f.ids, 0, count);
        for (uint256 i; i < count; ++i) {
            cheat.mockCall(
                address(core),
                abi.encodeCall(IStreamCoreIdentity.coordinatorAtMint, (f.ids[i])),
                abi.encode(i % 2 == 0 ? address(f.first) : address(f.second))
            );
        }
        f.plan = f.sources.beginInventory(_scope());
        if (count != 0) f.sources.appendInventory(f.plan, 256);
    }

    function testEveryOriginalNativePolicyAndIndependentComponentPreimage() public {
        Fixture memory f = _setup(3, true);
        core.setPointer(keccak256("ENTROPY_COORDINATOR"), address(f.second));
        StreamFinalityCoordinatorPolicyEvidence memory e = f.reader.read(_scope(), f.plan);
        require(e.allFrozen && e.policyCount == 2 && e.policies.length == 2);
        require(
            e.policies[0].coordinator == address(f.first)
                && e.policies[1].coordinator == address(f.second)
        );
        require(e.policies[0].firstTokenIndex == 0 && e.policies[1].firstTokenIndex == 1);
        for (uint256 i; i < 2; ++i) {
            StreamFinalityCoordinatorPolicy memory a = e.policies[i];
            (bool frozen, bytes32 hash, address provider, uint32 epoch, bytes32 salt) =
                IStreamEntropyFinalityPolicy(a.coordinator).entropyPolicyFrozen(1);
            require(
                a.frozen == frozen && a.policyHash == hash && a.provider == provider
                    && a.epoch == epoch && a.salt == salt
            );
            require(
                a.componentDataHash
                    == keccak256(
                        abi.encode(
                            keccak256("6529STREAM_ENTROPY_COMPONENT_EVIDENCE_V1"),
                            block.chainid,
                            address(core),
                            a.coordinator,
                            _scope(),
                            hash,
                            provider,
                            epoch,
                            salt
                        )
                    )
            );
        }
        require(e.inventoryHash == f.sources.requireCompleteInventory(f.plan).commitment);
        require(
            f.first.nonterminalTokenCount(1) == 0,
            "scope policy is separate from token seed evidence"
        );
    }

    function testMutableSecondPolicyNeverBecomesAllFrozenAndLockChangesCommitment() public {
        Fixture memory f = _setup(2, false);
        StreamFinalityCoordinatorPolicyEvidence memory before = f.reader.read(_scope(), f.plan);
        require(!before.allFrozen && before.policies[0].frozen && !before.policies[1].frozen);
        f.second.registerEntropyScope(1, 1, keccak256("lock"));
        StreamFinalityCoordinatorPolicyEvidence memory afterLock = f.reader.read(_scope(), f.plan);
        require(afterLock.allFrozen && before.policyChainHash != afterLock.policyChainHash);
        require(
            before.policies[1].componentDataHash == afterLock.policies[1].componentDataHash,
            "lock separate from policy preimage"
        );
    }

    function testEmptyScopeHasNoInventedFrozenPolicy() public {
        Fixture memory f = _setup(0, true);
        StreamFinalityCoordinatorPolicyEvidence memory e = f.reader.read(_scope(), f.plan);
        require(
            e.policyCount == 0 && e.policies.length == 0 && !e.allFrozen && e.inventoryHash != 0
        );
    }

    function testMissingOriginalPolicyRejectedRatherThanUsingCurrentSource() public {
        Fixture memory f = _setup(2, true);
        cheat.mockCall(
            address(f.first),
            abi.encodeCall(IStreamEntropyFinalityPolicy.entropyPolicyFrozen, (1)),
            abi.encode(false, bytes32(0), address(0), uint32(0), bytes32(0))
        );
        vm.expectRevert();
        f.reader.read(_scope(), f.plan);
    }

    function testStaleCollectionInventoryRejected() public {
        Fixture memory f = _setup(1, true);
        core.setToken(6, 1, 2, 2);
        uint256[] memory one = new uint256[](1);
        one[0] = 6;
        inventory.appendCollectionTokens(1, one);
        vm.expectRevert();
        f.reader.read(_scope(), f.plan);
    }

    function testDifferentScopeCannotBorrowPlan() public {
        Fixture memory f = _setup(1, true);
        StreamFinalityScope memory other =
            StreamFinalityScope(StreamFinalityScopeType.TOKEN, 1, f.ids[0], 0);
        vm.expectRevert();
        f.reader.read(other, f.plan);
    }

    function testTokenAndAllPublishedSubsetsUseOnlyTheirOriginalsAndRetainBurns() public {
        Fixture memory f = _setup(2, true);
        core.setToken(f.ids[0], 1, 1, 3);
        for (uint8 kind = 1; kind <= 4; ++kind) {
            StreamFinalityScope memory scope;
            if (kind == 1) {
                scope = StreamFinalityScope(StreamFinalityScopeType.TOKEN, 1, f.ids[0], 0);
            } else {
                uint256[] memory one = new uint256[](1);
                one[0] = f.ids[0];
                bytes32 record = _publish(_manifest(kind, one), "ipfs://policy-scope");
                scope = membership.beginScopeMembership(record);
                membership.continueScopeMembership(scope, 1);
            }
            bytes32 plan = f.sources.beginInventory(scope);
            f.sources.appendInventory(plan, 256);
            StreamFinalityCoordinatorPolicyEvidence memory e = f.reader.read(scope, plan);
            require(
                e.allFrozen && e.policyCount == 1 && e.policies[0].coordinator == address(f.first)
            );
        }
    }

    function testOriginalRuntimeChangeFailsAndHistoricalInventoryRemains() public {
        Fixture memory f = _setup(1, true);
        bytes32 history = keccak256(abi.encode(f.sources.inventoryProgress(f.plan)));
        vm.etch(address(f.first), hex"60006000f3");
        vm.expectRevert();
        f.reader.read(_scope(), f.plan);
        require(history == keccak256(abi.encode(f.sources.inventoryProgress(f.plan))));
    }

    function testMalformedNativeReturnWidthsAndLengthRejected() public {
        Fixture memory f = _setup(1, true);
        bytes memory callData =
            abi.encodeCall(IStreamEntropyFinalityPolicy.entropyPolicyFrozen, (1));
        cheat.mockCall(
            address(f.first),
            callData,
            abi.encode(uint256(2), bytes32(uint256(1)), address(1), uint256(1), bytes32(uint256(2)))
        );
        vm.expectRevert();
        f.reader.read(_scope(), f.plan);
        cheat.mockCall(
            address(f.first),
            callData,
            abi.encode(true, bytes32(uint256(1)), address(1), uint256(1) << 32, bytes32(uint256(2)))
        );
        vm.expectRevert();
        f.reader.read(_scope(), f.plan);
        cheat.mockCall(
            address(f.first),
            callData,
            abi.encode(
                true, bytes32(uint256(1)), address(1), uint32(1), bytes32(uint256(2)), uint256(0)
            )
        );
        vm.expectRevert();
        f.reader.read(_scope(), f.plan);
    }

    function testNativeModuleAndCoreBindingsRejected() public {
        Fixture memory f = _setup(1, true);
        cheat.mockCall(
            address(f.first),
            abi.encodeCall(IStreamModule.streamModuleType, ()),
            abi.encode(keccak256("other"))
        );
        vm.expectRevert();
        f.reader.read(_scope(), f.plan);
        cheat.mockCall(
            address(f.first),
            abi.encodeCall(IStreamModule.streamModuleType, ()),
            abi.encode(keccak256("ENTROPY_COORDINATOR"))
        );
        cheat.mockCall(
            address(f.first), abi.encodeWithSignature("core()"), abi.encode(address(123))
        );
        vm.expectRevert();
        f.reader.read(_scope(), f.plan);
    }

    function testIndexedSourceSubstitutionCannotReconstructSourceChain() public {
        Fixture memory f = _setup(2, true);
        cheat.mockCall(
            address(f.sources),
            abi.encodeCall(IStreamFinalityCoordinatorInventory.requireCoordinator, (f.plan, 0)),
            abi.encode(
                IStreamFinalityCoordinatorInventory.Coordinator(
                    address(f.second), address(f.second).codehash, 0
                )
            )
        );
        vm.expectRevert();
        f.reader.read(_scope(), f.plan);
    }

    function testIncompleteTraversalAndHealthyCompletion() public {
        _setup(2, true);
        StreamFinalityCoordinatorInventory next = new StreamFinalityCoordinatorInventory(
            address(core), address(membership), 100000, 2000000
        );
        FixedCoordinatorPolicyConsumer reader =
            new FixedCoordinatorPolicyConsumer(_dependencies(next));
        bytes32 plan = next.beginInventory(_scope());
        next.appendInventory(plan, 1);
        vm.expectRevert();
        reader.read(_scope(), plan);
        next.appendInventory(plan, 1);
        require(reader.read(_scope(), plan).allFrozen);
    }

    function testChainChangedAndWrongDependencyPinsReject() public {
        Fixture memory f = _setup(1, true);
        StreamFinalityCoordinatorPolicyReads.Dependencies memory d = _dependencies(f.sources);
        d.codeHashes[1] = keccak256("wrong");
        vm.expectRevert();
        StreamFinalityCoordinatorPolicyReads.requireCurrent(d, _scope(), f.plan);
        vm.chainId(block.chainid + 1);
        vm.expectRevert();
        f.reader.read(_scope(), f.plan);
    }

    function testLowParentGasRejectsAndHigherBudgetSucceeds() public {
        Fixture memory f = _setup(2, true);
        (bool ok,) = address(f.reader).staticcall{ gas: 100000 }(
            abi.encodeCall(f.reader.read, (_scope(), f.plan))
        );
        require(!ok);
        require(f.reader.read(_scope(), f.plan).allFrozen);
    }

    function testThresholdSafeConsumerAndLinkedLibraryReads() public {
        Fixture memory f = _setup(2, true);
        uint256[] memory keys = new uint256[](2);
        keys[0] = 99801;
        keys[1] = 99802;
        OfficialSafe safe =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 99803);
        require(
            executeSafe(
                safe,
                keys,
                address(f.reader),
                0,
                abi.encodeCall(f.reader.read, (_scope(), f.plan)),
                0
            )
        );
        require(
            executeSafe(
                safe,
                keys,
                address(StreamFinalityCoordinatorPolicyReads),
                0,
                abi.encodeWithSelector(
                    StreamFinalityCoordinatorPolicyReads.requireCurrent.selector,
                    _dependencies(f.sources),
                    _scope(),
                    f.plan
                ),
                0
            )
        );
        require(f.reader.read(_scope(), f.plan).policyCount == 2);
    }

    function testFuzzSecondOriginalChangePreservesFirstAndChangesCompleteCommitment(bytes32 entropyInput)
        public
    {
        Fixture memory f = _setup(2, false);
        StreamFinalityCoordinatorPolicyEvidence memory before = f.reader.read(_scope(), f.plan);
        f.second
            .configureCollection(
                1, before.policies[1].provider, keccak256(abi.encode(entropyInput)), true, 10
            );
        StreamFinalityCoordinatorPolicyEvidence memory afterChange = f.reader.read(_scope(), f.plan);
        require(
            keccak256(abi.encode(before.policies[0]))
                == keccak256(abi.encode(afterChange.policies[0]))
        );
        require(
            before.inventoryHash == afterChange.inventoryHash
                && before.policyChainHash != afterChange.policyChainHash
        );
    }
}
