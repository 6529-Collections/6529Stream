// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamTerminalEntropySourceSet.t.sol";
import "../../../smart-contracts/interfaces/stream/finality/IStreamFinalityCurrentComponentRoutes.sol";
import {
    StreamFinalityEntropyPolicySourceFactoryV2 as Factory
} from "../../../smart-contracts/domains/finality/StreamFinalityEntropyPolicySourceFactoryV2.sol";

/// @notice Actual mixed original Coordinators, complete inventories, V2 factory and immutable sets.
/// @dev Inherited Core/Artist/governance/provider boundaries remain explicit. This is not a selected
/// combined-provider ceremony, transaction-cap acceptance or a terminal rendered-output proof.
contract StreamFinalityEntropyPolicySourceFactoryV2Test is
    StreamFinalityCoordinatorPolicyReadsTest
{
    bytes32 private constant FAMILY = keccak256("6529STREAM_ENTROPY_CONFIGURATION_V1");

    function testFactoryOutputBindsConstructorInventoryAndActualCurrentRoute() public {
        Fixture memory f = _factorySources();
        V2.Dependencies memory d = _v2(f);
        Factory factory = new Factory(d);
        require(
            factory.core() == address(core) && factory.metadataHost() == address(metadata)
                && factory.scopeMembershipHost() == address(membership)
                && factory.coordinatorInventory() == address(f.sources)
        );
        require(
            factory.policyFactoryProfile()
                    == keccak256("6529STREAM_ENTROPY_POLICY_SOURCE_FACTORY_V2")
                && keccak256(abi.encode(factory.dependencies())) == keccak256(abi.encode(d))
        );
        require(factory.currentInventoryPlan(_scope()) == f.plan);
        address created = factory.prepareSourceSet(_scope());
        require(factory.prepareSourceSet(_scope()) == created, "idempotent actual inventory plan");
        (address saved, bytes32 runtime) = factory.sourceSetForPlan(f.plan);
        require(saved == created && runtime == created.codehash);
        SourceSet source = SourceSet(created);
        require(
            source.factory() == address(factory) && source.core() == address(core)
                && source.inventoryPlan() == f.plan && source.sourceCount() == 2
        );
        StreamFinalityCurrentComponentRoute memory route = factory.requireCurrentRoute(_scope());
        StreamFinalityComponentExpectation memory component =
            factory.requireCurrentComponent(_scope());
        require(
            route.component == created && route.codeHash == created.codehash
                && component.component == created
                && component.dataHash == source.finalityState(1).dataHash
        );
        Interface.TokenReadiness memory terminal = source.tokenEntropyReadiness(f.ids[0]);
        require(terminal.terminal && terminal.seed == 0 && !terminal.finalized);
        require(!source.supportsInterface(type(Legacy).interfaceId), "no V1 seed-ready alias");
    }

    function testMissingPreparedSetCannotBecomeCurrentThroughDiscovery() public {
        Fixture memory f = _factorySources();
        Factory factory = new Factory(_v2(f));
        vm.expectRevert();
        factory.requireCurrentRoute(_scope());
        vm.expectRevert();
        factory.requireCurrentComponent(_scope());
        (address set, bytes32 code) = factory.sourceSetForPlan(f.plan);
        require(set == address(0) && code == 0);
        factory.prepareSourceSet(_scope());
        factory.requireCurrentRoute(_scope());
    }

    function testMismatchedImmutableFactoryAndRuntimeRefuseThenExactRestore() public {
        Fixture memory f = _factorySources();
        Factory factory = new Factory(_v2(f));
        address set = factory.prepareSourceSet(_scope());
        cheat.mockCall(set, abi.encodeCall(Interface.factory, ()), abi.encode(address(this)));
        vm.expectRevert();
        factory.requireCurrentRoute(_scope());
        cheat.mockCall(set, abi.encodeCall(Interface.factory, ()), abi.encode(address(factory)));
        factory.requireCurrentRoute(_scope());
        bytes memory original = set.code;
        vm.etch(set, hex"00");
        vm.expectRevert();
        factory.requireCurrentComponent(_scope());
        vm.etch(set, original);
        factory.requireCurrentComponent(_scope());
    }

    function testChangedCompleteNativePolicyCannotReuseAcceptedSet() public {
        Fixture memory f = _factorySources();
        Factory factory = new Factory(_v2(f));
        address set = factory.prepareSourceSet(_scope());
        TerminalPolicy.PolicyRecord memory p =
            TerminalPolicy(address(f.first)).collectionEntropyPolicy(1);
        bytes memory original = abi.encode(p);
        p.lastActionId = keccak256("foreign original action");
        cheat.mockCall(
            address(f.first),
            abi.encodeCall(TerminalPolicy.collectionEntropyPolicy, (uint256(1))),
            abi.encode(p)
        );
        vm.expectRevert();
        factory.requireCurrentRoute(_scope());
        vm.expectRevert();
        factory.prepareSourceSet(_scope());
        (address retained,) = factory.sourceSetForPlan(f.plan);
        require(retained == set, "immutable history not erased");
        cheat.mockCall(
            address(f.first),
            abi.encodeCall(TerminalPolicy.collectionEntropyPolicy, (uint256(1))),
            original
        );
        require(factory.prepareSourceSet(_scope()) == set);
    }

    function testExpandedMembershipNeedsNewCompleteInventoryBeforeRoute() public {
        Fixture memory f = _factorySources();
        Factory factory = new Factory(_v2(f));
        address original = factory.prepareSourceSet(_scope());
        core.setToken(9, 1, 3, 2);
        uint256[] memory one = new uint256[](1);
        one[0] = 9;
        inventory.appendCollectionTokens(1, one);
        vm.expectRevert();
        factory.requireCurrentRoute(_scope());
        vm.expectRevert();
        factory.prepareSourceSet(_scope());
        (address retained, bytes32 code) = factory.sourceSetForPlan(f.plan);
        require(retained == original && code == original.codehash);
    }

    function testFactoryConstructorPinsAndCollectionOnlyScopeAreClosed() public {
        Fixture memory f = _factorySources();
        V2.Dependencies memory d = _v2(f);
        d.codeHashes[3] ^= bytes32(uint256(1));
        vm.expectRevert();
        new Factory(d);
        d = _v2(f);
        Factory factory = new Factory(d);
        StreamFinalityScope memory other = _scope();
        other.scopeType = StreamFinalityScopeType.TOKEN;
        other.tokenId = f.ids[0];
        vm.expectRevert();
        factory.prepareSourceSet(other);
        factory.prepareSourceSet(_scope());
    }

    function _factorySources() private returns (Fixture memory f) {
        f.first = _native(false);
        core.setPointer(keccak256("ENTROPY_COORDINATOR"), address(f.first));
        EntropyCollectionPolicyArtistFixture explicitArtist =
            new EntropyCollectionPolicyArtistFixture(address(core));
        core.setPointer(keccak256("ARTIST_REGISTRY"), address(explicitArtist));
        TerminalPolicy.PolicyInput memory input;
        input.renderRequirement = TerminalPolicy.RenderRequirement.NOT_REQUIRED;
        (bytes32 scope, bytes32 oldHash, bytes32 newHash, bytes32 content) =
            TerminalPolicy(address(f.first)).collectionEntropyPolicyTransition(1, input);
        explicitArtist.approve(
            1, address(f.first), FAMILY, content, keccak256("actual recorded consent fixture")
        );
        this.setCurrentAction(
            true, keccak256("policy configure fixture"), 1, scope, oldHash, newHash
        );
        TerminalPolicy(address(f.first)).configureCollectionEntropyPolicy(1, input);
        this.setCurrentAction(false, 0, 0, 0, 0, 0);
        // The actual token hooks below freeze both policies; no unrelated scope is needed.
        f.second = _native(false);
        f.sources = new StreamFinalityCoordinatorInventory(
            address(core), address(membership), 100000, 2000000
        );
        f.reader = new FixedCoordinatorPolicyConsumer(_dependencies(f.sources));
        f.ids = _tokens(2);
        _index(f.ids, 0, 2);
        for (uint256 i; i < 2; ++i) {
            StreamEntropyCoordinator chosen = i == 0 ? f.first : f.second;
            core.setPointer(keccak256("ENTROPY_COORDINATOR"), address(chosen));
            cheat.mockCall(
                address(core),
                abi.encodeCall(IStreamCoreIdentity.coordinatorAtMint, (f.ids[i])),
                abi.encode(address(chosen))
            );
            vm.prank(address(core));
            chosen.onTokenMinted(
                1, f.ids[i], address(this), keccak256(abi.encode("terminal mixture", i))
            );
        }
        f.plan = f.sources.beginInventory(_scope());
        f.sources.appendInventory(f.plan, 256);
    }

    function _v2(Fixture memory f) private view returns (V2.Dependencies memory d) {
        StreamFinalityCoordinatorPolicyReads.Dependencies memory old = _dependencies(f.sources);
        d.targets = old.targets;
        d.codeHashes = old.codeHashes;
        d.chainId = old.chainId;
        d.readGas = old.readGas;
        d.inventoryGas = old.inventoryGas;
    }
}
