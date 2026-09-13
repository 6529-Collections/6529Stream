// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../helpers/ScopeMembershipCoreFixture.sol";
import "../../helpers/EntropyTimeTestMocks.sol";
import "../../mocks/MockStreamEntropyProvider.sol";
import "../../../script/current/StreamRevealActivationPlan.sol";
import "../../../smart-contracts/domains/entropy/StreamEntropyCoordinator.sol";
import "../../../smart-contracts/domains/finality/StreamFinalityEntropySourceFactory.sol";
import "../../../smart-contracts/domains/finality/StreamFinalityCoordinatorInventory.sol";
import "../../../smart-contracts/domains/finality/StreamFinalityEntropyServing.sol";

/// @notice Actual Core, native entropy, Executor, RoleRegistry, module registry, inventories and Safe.
/// @dev The mint manager, artist/original-finality fixture and external randomness service remain
/// explicit boundaries. This does not claim the complete provider/Registry deployment graph.
contract StreamFinalityEntropySourceSetCurrentCoreTest is ScopeMembershipCoreFixture {
    struct NativePair {
        StreamEntropyCoordinator firstNative;
        StreamEntropyCoordinator secondNative;
        MockStreamEntropyProvider firstProvider;
        MockStreamEntropyProvider secondProvider;
        StreamFinalityCoordinatorInventory sources;
        StreamFinalityEntropySourceFactory factory;
        uint256[] ids;
    }

    function _native(bytes32 salt)
        private
        returns (StreamEntropyCoordinator native, MockStreamEntropyProvider provider)
    {
        native = new StreamEntropyCoordinator(
            StreamEntropyCoordinator.DeploymentConfig(
                address(configuration.core),
                address(configuration.executor),
                address(configuration.roles),
                EntropyTimeTestConfigs.parameters(),
                configuration.deploymentHash,
                "urn:stream:test:actual-native-source",
                keccak256(abi.encode("native source", salt))
            )
        );
        provider = new MockStreamEntropyProvider(address(native));
        GovernanceActionPolicyEntry[] memory entries = new GovernanceActionPolicyEntry[](1);
        entries[0] = _entry(1, address(native), native.configureCollection.selector);
        (bytes32 candidate, bytes32 catalog, uint256 count, uint64 revision) =
            configuration.executor.governanceActionPolicyState();
        (bytes32 next, bytes32 s, bytes32 o, bytes32 n) = StreamGovernanceActionPolicy.extensionTransition(
            address(configuration.executor), candidate, catalog, count, revision, entries
        );
        GovernanceCall[] memory calls = new GovernanceCall[](2);
        bytes[] memory data = new bytes[](2);
        data[0] = abi.encodeCall(
            configuration.executor.extendGovernanceActionPolicy, (revision, catalog, next, entries)
        );
        calls[0] = StreamCurrentStackPlan.call(address(configuration.executor), data[0], s, o, n);
        (calls[1], data[1]) = _publication(
            StreamGenesisManifestPlan.readAggregate(configuration.manifest).modules, next
        );
        _runBatch(3, calls, data);
        bytes memory configure = abi.encodeCall(
            native.configureCollection, (1, address(provider), salt, true, uint64(10))
        );
        // This legacy authority-only setter has no target context API. Its actual admitted,
        // delayed Executor call commits the explicit test transition; no Executor impersonation.
        _scopeRun(
            address(native),
            configure,
            keccak256(abi.encode("native config", address(native))),
            keccak256("unconfigured"),
            keccak256(configure)
        );
        require(
            executeSafe(
                governor,
                signers,
                address(native),
                0,
                abi.encodeCall(
                    native.configureCollectionRevealPolicy,
                    (1, 0, keccak256("ROLE_ENTROPY_REVEAL_OWNER"), uint64(10), 0)
                ),
                0
            )
        );
    }

    function _select(StreamEntropyCoordinator native) private {
        (, bytes32 moduleManifest) = native.streamModuleManifest();
        StreamModuleRegistration[] memory entries = new StreamModuleRegistration[](1);
        entries[0] = StreamModuleRegistration(
            address(native),
            native.streamModuleType(),
            native.streamModuleVersion(),
            native.streamModuleInterfaceId(),
            500000,
            address(native).codehash,
            configuration.deploymentHash,
            moduleManifest,
            "urn:stream:test:actual-native-source"
        );
        (GovernanceCall[] memory reg, bytes[] memory regData) =
            StreamCurrentStackPlan.registrationCalls(configuration.registry, entries);
        _runBatch(1, reg, regData);
        bytes32[] memory kinds = new bytes32[](1);
        kinds[0] = keccak256("ENTROPY_COORDINATOR");
        (GovernanceCall[] memory ptrs, bytes[] memory pointerData) = StreamCurrentStackPlan.pointerCalls(
            configuration.core, configuration.registry, kinds, entries
        );
        GovernanceCall[] memory calls = new GovernanceCall[](2);
        bytes[] memory data = new bytes[](2);
        calls[0] = ptrs[0];
        data[0] = pointerData[0];
        StreamSystemManifest.ModuleAddresses memory modules =
        StreamGenesisManifestPlan.readAggregate(configuration.manifest).modules;
        modules.entropyCoordinator = address(native);
        (calls[1], data[1]) =
            _publication(modules, keccak256(abi.encode("select native", address(native))));
        _runBatch(3, calls, data);
    }

    function _pair() private returns (NativePair memory f) {
        _initializeScope();
        StreamArtistActivationPlan.Plan memory grants = StreamRevealActivationPlan.build(
            configuration.roles,
            StreamRevealActivationPlan.Principals(
                address(governor), address(governor), address(governor)
            )
        );
        _runBatch(1, grants.calls, grants.callDatas);
        require(configuration.roles.hasRole(keccak256("ROLE_ENTROPY_ADMIN"), address(governor)));
        (f.firstNative, f.firstProvider) = _native(keccak256("first native salt"));
        (f.secondNative, f.secondProvider) = _native(keccak256("second native salt"));
        f.ids = new uint256[](2);
        _select(f.firstNative);
        f.ids[0] = scopeManager.mint(address(configuration.core), 1, address(0xbeef));
        _select(f.secondNative);
        f.ids[1] = scopeManager.mint(address(configuration.core), 1, address(0xbeef));
        require(configuration.core.coordinatorAtMint(f.ids[0]) == address(f.firstNative));
        require(configuration.core.coordinatorAtMint(f.ids[1]) == address(f.secondNative));
        scopeInventory.appendCollectionTokens(1, f.ids);
        f.sources = new StreamFinalityCoordinatorInventory(
            address(configuration.core), address(scopeMembership), 100000, 2000000
        );
        StreamFinalityCoordinatorPolicyReads.Dependencies memory d;
        d.targets = [
            address(configuration.core),
            address(scopeMetadata),
            address(scopeMembership),
            address(f.sources)
        ];
        for (uint256 i; i < 4; ++i) {
            d.codeHashes[i] = d.targets[i].codehash;
        }
        d.chainId = block.chainid;
        d.readGas = 500000;
        d.inventoryGas = 3000000;
        f.factory = new StreamFinalityEntropySourceFactory(d);
    }

    function _prepare(NativePair memory f, StreamFinalityScope memory scope)
        private
        returns (StreamFinalityEntropySourceSet set)
    {
        bytes32 plan = f.sources.beginInventory(scope);
        f.sources.appendInventory(plan, 256);
        require(f.sources.requireCompleteInventory(plan).coordinatorCount == 2);
        require(
            executeSafe(
                governor,
                signers,
                address(f.factory),
                0,
                abi.encodeCall(f.factory.prepareSourceSet, (scope)),
                0
            )
        );
        (address target, bytes32 hash) = f.factory.sourceSetForPlan(plan);
        require(target.codehash == hash && target.code.length <= 24576);
        set = StreamFinalityEntropySourceSet(target);
        require(set.sourcePolicyAt(0).coordinator == address(f.firstNative));
        require(set.sourcePolicyAt(1).coordinator == address(f.secondNative));
        require(f.factory.requireCurrentComponent(scope).component == target);
    }

    function _fulfill(
        StreamEntropyCoordinator native,
        MockStreamEntropyProvider provider,
        uint256 id,
        bytes32 raw
    ) private returns (bytes32 seed) {
        (, uint256 request) = native.requestEntropy(id);
        require(provider.fulfill(request, raw) == 0);
        bool complete;
        (seed, complete) = native.tokenSeed(id);
        require(complete && seed != 0 && seed != raw);
    }

    function _seed(StreamFinalityEntropySourceSet set, uint256 id, bytes32 expected, bool completed)
        private
        view
    {
        (bytes32 seed, bool complete) =
            StreamFinalityEntropyServing.read(address(set), address(set), id);
        require(seed == expected && complete == completed, "actual native seed through typed route");
    }

    function testActualCoreNativeSourcesSurviveReplacementBurnAndRejectLaterCollectionToken()
        public
    {
        NativePair memory f = _pair();
        StreamFinalityScope memory scope =
            StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0);
        StreamFinalityEntropySourceSet set = _prepare(f, scope);
        _seed(set, f.ids[0], 0, false);
        bytes32 seed0 = _fulfill(f.firstNative, f.firstProvider, f.ids[0], keccak256("raw first"));
        bytes32 seed1 =
            _fulfill(f.secondNative, f.secondProvider, f.ids[1], keccak256("raw second"));
        require(seed0 != seed1);
        _seed(set, f.ids[0], seed0, true);
        _seed(set, f.ids[1], seed1, true);
        vm.prank(address(0xbeef));
        configuration.core.burn(f.ids[0]);
        require(configuration.core.tokenLifecycle(f.ids[0]) == 3);
        _seed(set, f.ids[0], seed0, true);
        uint256 later = scopeManager.mint(address(configuration.core), 1, address(0xbeef));
        vm.expectRevert();
        set.tokenSeedForFinality(later);
        require(set.finalityState(1).frozen, "retained prefix remains frozen");
        vm.expectRevert();
        f.factory.requireCurrentComponent(scope);
        uint256[] memory added = new uint256[](1);
        added[0] = later;
        scopeInventory.appendCollectionTokens(1, added);
        StreamFinalityEntropySourceSet next = _prepare(f, scope);
        require(address(next) != address(set));
        _seed(next, f.ids[0], seed0, true);
        _seed(next, f.ids[1], seed1, true);
        _seed(next, later, 0, false);
    }

    function testActualPublishedFamiliesResolveBothNativeSourcesAfterParentExtends() public {
        NativePair memory f = _pair();
        bytes32 seed0 =
            _fulfill(f.firstNative, f.firstProvider, f.ids[0], keccak256("release first"));
        bytes32 seed1 =
            _fulfill(f.secondNative, f.secondProvider, f.ids[1], keccak256("release second"));
        StreamFinalityEntropySourceSet[3] memory sets;
        StreamFinalityScope[3] memory scopes;
        for (uint8 family = 2; family <= 4; ++family) {
            (, scopes[family - 2]) = _scopePublish(family, f.ids, "ipfs://stream/actual-native-scope");
            scopeMembership.continueScopeMembership(scopes[family - 2], 1);
            sets[family - 2] = _prepare(f, scopes[family - 2]);
        }
        uint256 later = scopeManager.mint(address(configuration.core), 1, address(0xbeef));
        for (uint256 i; i < 3; ++i) {
            _seed(sets[i], f.ids[0], seed0, true);
            _seed(sets[i], f.ids[1], seed1, true);
            vm.expectRevert();
            sets[i].tokenSeedForFinality(later);
            require(f.factory.requireCurrentComponent(scopes[i]).component == address(sets[i]));
        }
        bytes memory prior = address(f.firstNative).code;
        vm.etch(address(f.firstNative), hex"00");
        vm.expectRevert();
        sets[0].finalityStateForScope(scopes[0]);
        vm.etch(address(f.firstNative), prior);
        require(sets[0].finalityStateForScope(scopes[0]).frozen);
        _seed(sets[0], f.ids[0], seed0, true);
    }
}
