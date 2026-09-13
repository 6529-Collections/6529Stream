// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamFinalityCoordinatorPolicyReads.t.sol";
import "../../../smart-contracts/domains/finality/StreamFinalityEntropySourceFactory.sol";
import "../../../smart-contracts/domains/finality/StreamFinalityEntropyServing.sol";

contract EntropyServingHarness {
    function read(address adapter, address host, uint256 id) external view returns (bytes32, bool) {
        return StreamFinalityEntropyServing.read(adapter, host, id);
    }
}

contract LegacyEntropyAdapterBoundary {
    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == 0x01ffc9a7;
    }
}

/// @notice Inherits all16 policy regressions. New cases use actual native policy and fulfillment,
/// actual Metadata/Schema/Store and scope/source inventories; Core/governance/oracle are fixtures.
contract StreamFinalityEntropySourceSetTest is StreamFinalityCoordinatorPolicyReadsTest {
    event log_named_uint(string key, uint256 value);

    function _factory(Fixture memory f) private returns (StreamFinalityEntropySourceFactory) {
        address registry = core.selected(keccak256("MODULE_REGISTRY"));
        StreamMetadataRecoveryRoutes.Pointer memory pointer = StreamMetadataRecoveryRoutes.Pointer(
            address(metadata),
            address(metadata).codehash,
            false,
            keccak256("COLLECTION_METADATA"),
            type(IStreamCollectionMetadataV1).interfaceId,
            registry,
            1,
            bytes32(uint256(1)),
            bytes32(uint256(2)),
            1
        );
        cheat.mockCall(
            address(core),
            abi.encodeWithSignature(
                "getSatellitePointer(bytes32)", keccak256("COLLECTION_METADATA")
            ),
            abi.encode(pointer)
        );
        return new StreamFinalityEntropySourceFactory(_dependencies(f.sources));
    }

    function _prepare(Fixture memory f) private returns (StreamFinalityEntropySourceSet a) {
        a = StreamFinalityEntropySourceSet(_factory(f).prepareSourceSet(_scope()));
    }

    function _finalize(StreamEntropyCoordinator n, uint256 token, bytes32 raw)
        private
        returns (bytes32 seed)
    {
        vm.prank(address(core));
        n.onTokenMinted(1, token, address(this), keccak256(abi.encode("mint", token)));
        (, uint256 requestId) = n.requestEntropy(token);
        (,, address provider,,) = n.entropyPolicyFrozen(1);
        require(MockStreamEntropyProvider(provider).fulfill(requestId, raw) == 0);
        bool done;
        (seed, done) = n.tokenSeed(token);
        require(done);
    }

    function testSourceSetHasOneRouteAndCompleteIndependentNativeEvidence() public {
        Fixture memory f = _setup(3, true);
        StreamFinalityEntropySourceFactory factory = _factory(f);
        require(factory.currentInventoryPlan(_scope()) == f.plan);
        address first = factory.prepareSourceSet(_scope());
        require(factory.prepareSourceSet(_scope()) == first);
        StreamFinalityEntropySourceSet a = StreamFinalityEntropySourceSet(first);
        require(a.factory() == address(factory) && a.sourceCount() == 2 && a.host() == first);
        require(!a.supportsInterface(type(IStreamEntropyCoordinator).interfaceId));
        for (uint256 i; i < 2; ++i) {
            require(
                keccak256(abi.encode(a.sourcePolicyAt(i)))
                    == keccak256(abi.encode(f.reader.read(_scope(), f.plan).policies[i]))
            );
        }
        StreamFinalityComponentExpectation memory c = factory.requireCurrentComponent(_scope());
        require(
            c.component == first && c.componentType == keccak256("ENTROPY_COORDINATOR")
                && c.dataHash != 0
        );
        StreamFinalityComponentState memory state = a.finalityState(1);
        require(state.frozen && state.dataHash == c.dataHash && state.codeHash == first.codehash);
    }

    function testActualNativeSeedsDispatchByOriginalSourceAfterPointerReplacement() public {
        Fixture memory f = _setup(2, true);
        bytes32 one = _finalize(f.first, f.ids[0], keccak256("one"));
        bytes32 two = _finalize(f.second, f.ids[1], keccak256("two"));
        require(one != two);
        StreamFinalityEntropySourceSet a = _prepare(f);
        core.setPointer(keccak256("ENTROPY_COORDINATOR"), address(f.second));
        (bytes32 got, bool done) = a.tokenSeedForFinality(f.ids[0]);
        require(done && got == one);
        (got, done) = a.tokenSeedForFinality(f.ids[1]);
        require(done && got == two);
        EntropyServingHarness harness = new EntropyServingHarness();
        (got, done) = harness.read(address(a), address(a), f.ids[0]);
        require(done && got == one);
        (got, done) = harness.read(address(a), address(a), f.ids[1]);
        require(done && got == two);
    }

    function testPendingNativeOutputDoesNotBecomeFinalAndLegacyServingRemains() public {
        Fixture memory f = _setup(1, true);
        StreamFinalityEntropySourceSet a = _prepare(f);
        (bytes32 seed, bool done) = a.tokenSeedForFinality(f.ids[0]);
        require(!done && seed == 0);
        EntropyServingHarness harness = new EntropyServingHarness();
        (seed, done) =
            harness.read(address(new LegacyEntropyAdapterBoundary()), address(f.first), f.ids[0]);
        require(!done && seed == 0);
        bytes32 expected = _finalize(f.first, f.ids[0], keccak256("legacy"));
        (seed, done) =
            harness.read(address(new LegacyEntropyAdapterBoundary()), address(f.first), f.ids[0]);
        require(done && seed == expected);
    }

    function testBurnedMemberRetainsItsActualNativeSeed() public {
        Fixture memory f = _setup(1, true);
        bytes32 expected = _finalize(f.first, f.ids[0], keccak256("burn"));
        StreamFinalityEntropySourceSet a = _prepare(f);
        core.setToken(f.ids[0], 1, 1, 3);
        (bytes32 seed, bool done) = a.tokenSeedForFinality(f.ids[0]);
        require(done && seed == expected);
        require(a.finalityState(1).frozen);
    }

    function testLaterSameCoordinatorTokenExcludedFromRetainedCollectionPrefix() public {
        Fixture memory f = _setup(1, true);
        StreamFinalityEntropySourceSet a = _prepare(f);
        bytes32 beforeHash = a.finalityState(1).dataHash;
        core.setToken(6, 1, 2, 2);
        cheat.mockCall(
            address(core),
            abi.encodeCall(IStreamCoreIdentity.coordinatorAtMint, (6)),
            abi.encode(address(f.first))
        );
        uint256[] memory next = new uint256[](1);
        next[0] = 6;
        _index(next, 0, 1);
        vm.expectRevert();
        a.tokenSeedForFinality(6);
        // Current preparation is stale; historical retained evidence remains inspectable.
        vm.expectRevert();
        a.requireCurrentSourceSet();
        require(a.finalityState(1).dataHash == beforeHash);
        a.tokenSeedForFinality(f.ids[0]);
    }

    function testUnpreparedAndUnlockedSourceSetsRejectUntilRealInventoryReady() public {
        Fixture memory f = _setup(2, false);
        StreamFinalityEntropySourceFactory factory = _factory(f);
        vm.expectRevert();
        factory.requireCurrentComponent(_scope());
        vm.expectRevert();
        factory.prepareSourceSet(_scope());
        (address absent,) = factory.sourceSetForPlan(f.plan);
        require(absent == address(0));
        f.second.registerEntropyScope(1, 1, keccak256("nowlocked"));
        require(factory.prepareSourceSet(_scope()) != address(0));
    }

    function testEmptySourceSetCannotBePrepared() public {
        Fixture memory f = _setup(0, true);
        StreamFinalityEntropySourceFactory factory = _factory(f);
        vm.expectRevert();
        factory.prepareSourceSet(_scope());
    }

    function testEachOriginalLivePolicyAndCodeRemainRequired() public {
        Fixture memory f = _setup(2, true);
        StreamFinalityEntropySourceSet a = _prepare(f);
        vm.etch(address(f.second), hex"60006000f3");
        vm.expectRevert();
        a.finalityState(1);
        vm.expectRevert();
        a.tokenSeedForFinality(f.ids[1]);
        require(a.sourcePolicyAt(1).coordinator == address(f.second));
    }

    function testWrongScopeAndTokenAssociationReject() public {
        Fixture memory f = _setup(2, true);
        StreamFinalityEntropySourceSet a = _prepare(f);
        vm.expectRevert();
        a.finalityState(2);
        vm.expectRevert();
        a.finalityStateForScope(StreamFinalityScope(StreamFinalityScopeType.TOKEN, 1, f.ids[0], 0));
        core.setToken(f.ids[0], 2, 1, 2);
        vm.expectRevert();
        a.tokenSeedForFinality(f.ids[0]);
        core.setToken(f.ids[0], 1, 2, 2);
        vm.expectRevert();
        a.tokenSeedForFinality(f.ids[0]);
    }

    function testTokenAndAllPublishedFamilyScopesKeepExactMembership() public {
        Fixture memory f = _setup(3, true);
        StreamFinalityEntropySourceFactory factory = _factory(f);
        for (uint8 kind = 1; kind <= 4; ++kind) {
            StreamFinalityScope memory scope;
            if (kind == 1) {
                scope = StreamFinalityScope(StreamFinalityScopeType.TOKEN, 1, f.ids[0], 0);
            } else {
                uint256[] memory ids = new uint256[](2);
                ids[0] = f.ids[0];
                ids[1] = f.ids[2];
                bytes32 record = _publish(_manifest(kind, ids), "ipfs://source-subset");
                scope = membership.beginScopeMembership(record);
                membership.continueScopeMembership(scope, 1);
            }
            bytes32 plan = f.sources.beginInventory(scope);
            f.sources.appendInventory(plan, 256);
            StreamFinalityEntropySourceSet a =
                StreamFinalityEntropySourceSet(factory.prepareSourceSet(scope));
            require(a.finalityStateForScope(scope).frozen && a.sourceCount() == 1);
            a.tokenSeedForFinality(f.ids[0]);
            EntropyServingHarness harness = new EntropyServingHarness();
            harness.read(address(a), address(a), f.ids[0]);
            vm.expectRevert();
            harness.read(address(a), address(a), f.ids[1]);
            vm.expectRevert();
            a.tokenSeedForFinality(f.ids[1]);
        }
    }

    function testSourceSetSeedRejectsUnregisteredSourceAndMalformedReplies() public {
        Fixture memory f = _setup(1, true);
        StreamFinalityEntropySourceSet a = _prepare(f);
        cheat.mockCall(
            address(f.first),
            abi.encodeWithSignature("tokenSeed(uint256)", f.ids[0]),
            abi.encode(bytes32(0), uint256(2))
        );
        vm.expectRevert();
        a.tokenSeedForFinality(f.ids[0]);
        cheat.mockCall(
            address(core),
            abi.encodeCall(IStreamCoreIdentity.coordinatorAtMint, (f.ids[0])),
            abi.encode(address(f.second))
        );
        vm.expectRevert();
        a.tokenSeedForFinality(f.ids[0]);
    }

    function testPreparedFactoryRuntimeAndChainPinsCannotBeSubstituted() public {
        Fixture memory f = _setup(1, true);
        StreamFinalityEntropySourceFactory factory = _factory(f);
        address set = factory.prepareSourceSet(_scope());
        vm.etch(set, hex"60006000f3");
        vm.expectRevert();
        factory.requireCurrentComponent(_scope());
        vm.expectRevert();
        factory.prepareSourceSet(_scope());
        vm.chainId(block.chainid + 1);
        vm.expectRevert();
        factory.currentInventoryPlan(_scope());
    }

    function testSafePreparesSourceSetAndInvokesEveryNewOperativeRead() public {
        Fixture memory f = _setup(2, true);
        StreamFinalityEntropySourceFactory factory = _factory(f);
        uint256[] memory keys = new uint256[](2);
        keys[0] = 87901;
        keys[1] = 87902;
        OfficialSafe safe =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 87903);
        require(
            executeSafe(
                safe,
                keys,
                address(factory),
                0,
                abi.encodeCall(factory.prepareSourceSet, (_scope())),
                0
            )
        );
        (address set,) = factory.sourceSetForPlan(f.plan);
        require(set != address(0));
        require(
            executeSafe(
                safe,
                keys,
                address(factory),
                0,
                abi.encodeCall(factory.requireCurrentComponent, (_scope())),
                0
            )
        );
        require(
            executeSafe(
                safe,
                keys,
                set,
                0,
                abi.encodeCall(IStreamFinalityEntropySourceSet.requireCurrentSourceSet, ()),
                0
            )
        );
        require(
            executeSafe(
                safe,
                keys,
                set,
                0,
                abi.encodeCall(IStreamArtworkFinalityComponent.finalityState, (1)),
                0
            )
        );
        require(
            executeSafe(
                safe,
                keys,
                set,
                0,
                abi.encodeCall(IStreamFinalityEntropySourceSet.tokenSeedForFinality, (f.ids[0])),
                0
            )
        );
        require(
            executeSafe(
                safe,
                keys,
                set,
                0,
                abi.encodeCall(IStreamFinalityEntropySourceSet.sourcePolicyAt, (1)),
                0
            )
        );
    }

    function testColdTypedServingAllScopesAndLowParentGasRetry() public {
        Fixture memory f = _setup(3, true);
        StreamFinalityEntropySourceFactory factory = _factory(f);
        for (uint8 kind; kind <= 4; ++kind) {
            StreamFinalityScope memory scope;
            if (kind == 0) {
                scope = _scope();
            } else if (kind == 1) {
                scope = StreamFinalityScope(StreamFinalityScopeType.TOKEN, 1, f.ids[0], 0);
            } else {
                uint256[] memory ids = new uint256[](2);
                ids[0] = f.ids[0];
                ids[1] = f.ids[2];
                scope = membership.beginScopeMembership(
                    _publish(_manifest(kind, ids), "ipfs://gas-subset")
                );
                membership.continueScopeMembership(scope, 1);
            }
            bytes32 plan = f.sources.beginInventory(scope);
            if (kind != 0) f.sources.appendInventory(plan, 256);
            StreamFinalityEntropySourceSet a =
                StreamFinalityEntropySourceSet(factory.prepareSourceSet(scope));
            EntropyServingHarness h = new EntropyServingHarness();
            bytes memory input = abi.encodeCall(h.read, (address(a), address(a), f.ids[0]));
            (bool low,) = address(h).staticcall{ gas: 1000000 }(input);
            require(!low, "outer cap precheck");
            address[11] memory cold = [
                address(core),
                address(metadata),
                address(membership),
                address(f.sources),
                address(inventory),
                address(f.first),
                address(f.second),
                address(a),
                address(h),
                address(StreamFinalityCoordinatorPolicyReads),
                address(StreamFinalityEntropyServing)
            ];
            for (uint256 i; i < cold.length; ++i) {
                safeVm.cool(cold[i]);
            }
            uint256 beforeGas = gasleft();
            (bool ok, bytes memory raw) = address(h).staticcall{ gas: 8000000 }(input);
            uint256 used = beforeGas - gasleft();
            require(ok, "cold actual typed scope dispatch");
            (, bool finalized) = abi.decode(raw, (bytes32, bool));
            require(!finalized);
            emit log_named_uint(
                kind == 0
                    ? "collection typed serving gas"
                    : kind == 1
                        ? "token typed serving gas"
                        : kind == 2
                            ? "release typed serving gas"
                            : kind == 3 ? "season typed serving gas" : "view typed serving gas",
                used
            );
        }
    }

    function testFuzzNativeDispatchPreservesExactSourceSeed(bytes32 raw) public {
        Fixture memory f = _setup(2, true);
        bytes32 expected = _finalize(f.first, f.ids[0], raw);
        StreamFinalityEntropySourceSet a = _prepare(f);
        (bytes32 seed, bool done) = a.tokenSeedForFinality(f.ids[0]);
        require(done && seed == expected);
    }
}
