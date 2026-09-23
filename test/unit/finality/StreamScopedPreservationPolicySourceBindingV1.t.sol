// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ScopedPolicyContentFixtureV2 } from "./StreamScopedPolicyContentCheckpointV2.t.sol";
import {
    StreamScopedPreservationPolicySourceBindingV1 as Binding
} from "../../../smart-contracts/domains/finality/StreamScopedPreservationPolicySourceBindingV1.sol";
import {
    StreamFinalityCoordinatorPolicyReadsV2 as Policies
} from "../../../smart-contracts/domains/finality/StreamFinalityCoordinatorPolicyReadsV2.sol";
import {
    IStreamFinalityScopedEntropyPolicySourceFactoryV2 as Factory
} from "../../../smart-contracts/interfaces/stream/finality/IStreamFinalityScopedEntropyPolicySourceFactoryV2.sol";
import {
    IStreamFinalityEntropySourceFactory as FactoryBase
} from "../../../smart-contracts/interfaces/stream/finality/IStreamFinalityEntropySourceFactory.sol";
import {
    IStreamFinalityEntropyPolicySourceSet as Source
} from "../../../smart-contracts/interfaces/stream/finality/IStreamFinalityEntropyPolicySourceSet.sol";
import {
    IStreamFinalityCurrentEntropyRoute,
    StreamFinalityCurrentComponentRoute
} from "../../../smart-contracts/interfaces/stream/finality/IStreamFinalityCurrentComponentRoutes.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType
} from "../../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import { IERC165 } from "../../../smart-contracts/vendor/openzeppelin/IERC165.sol";
import {
    StreamFinalityRouterEvidence as Reads
} from "../../../smart-contracts/domains/finality/StreamFinalityRouterEvidence.sol";

interface ScopedPreservationBindingVm {
    function expectRevert(bytes calldata reason) external;
    function mockCall(address target, bytes calldata input, bytes calldata output) external;
}

/// @dev Constructor-owned binding models the new checkpoint seam, not preservation admission.
contract ScopedPreservationBindingHarness {
    Binding.Binding private fixedBinding;
    address public immutable sourceSet;
    bytes32 public immutable sourceCodeHash;
    uint256 public immutable readGas;

    constructor(address core, address selection, address source, uint256 cap) {
        fixedBinding = Binding.bind(core, selection, source, cap);
        sourceSet = source;
        sourceCodeHash = source.codehash;
        readGas = cap;
    }

    function binding() external view returns (Binding.Binding memory) {
        return fixedBinding;
    }

    function current(StreamFinalityScope calldata scope) external view returns (bytes32) {
        return Binding.requireCurrent(fixedBinding, sourceSet, sourceCodeHash, scope, readGas);
    }
}

/// @notice Actual scoped factory, immutable source set, complete original policy inventory and
/// sealed Metadata membership exercise the new source-binding leaf.
/// @dev The inherited Core/Artist/module/renderer admission boundaries remain explicit. This
/// suite does not claim the new preservation renderer's admission or a finality ceremony.
contract StreamScopedPreservationPolicySourceBindingV1Test is ScopedPolicyContentFixtureV2 {
    ScopedPreservationBindingVm private constant bindingVm =
        ScopedPreservationBindingVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    uint256 private constant SOURCE_GAS = 8000000;

    function _source(StreamFinalityScope memory scope)
        private
        returns (ScopedPreservationBindingHarness probe, bytes32 plan)
    {
        plan = scopedSources.beginInventory(scope);
        scopedSources.appendInventory(plan, 256);
        address source = scopedFactory.prepareSourceSet(scope);
        Source(source).requireCurrentSourceSet();
        probe = new ScopedPreservationBindingHarness(
            address(core), address(scopedSelections), source, SOURCE_GAS
        );
        require(probe.current(scope) == plan, "valid actual source baseline");
    }

    function _invalid(address target) private pure returns (bytes memory) {
        return abi.encodeWithSelector(
            Binding.InvalidScopedPreservationPolicySourceBinding.selector, target
        );
    }

    function testScopedPreservationBindingAllThreeCompleteActualScopeFactories() public {
        _scopedFixture(1, true);
        for (uint8 kind = 1; kind <= 3; ++kind) {
            StreamFinalityScope memory scope = _scopedScope(kind);
            (ScopedPreservationBindingHarness probe, bytes32 plan) = _source(scope);
            Binding.Binding memory saved = probe.binding();
            require(
                saved.factory == address(scopedFactory)
                    && saved.factoryCodeHash == address(scopedFactory).codehash
                    && saved.dependenciesHash == keccak256(abi.encode(_scopedDependencies()))
                    && Source(probe.sourceSet()).inventoryPlan() == plan,
                "original fixed factory and complete dependency tuple"
            );
            require(
                scopedMembership.requireScopeMembership(scope).tokenCount == (kind == 1 ? 1 : 2),
                "full retained membership"
            );
        }
    }

    function testScopedPreservationBindingBurnedRetainedMembersUseOriginalFactory() public {
        _scopedFixture(1, true);
        _scopedToken(91, 1, 3, address(terminalCoordinator));
        _scopedToken(92, 2, 3, address(randomCoordinator));
        StreamFinalityScope memory scope = _scopedScope(2);
        (ScopedPreservationBindingHarness probe, bytes32 plan) = _source(scope);
        require(
            scopedMembership.scopeTokenAt(scope, 0) == 91
                && scopedMembership.scopeTokenAt(scope, 1) == 92,
            "burned original ordinal identities"
        );
        require(probe.current(scope) == plan, "burned membership remains admitted");
    }

    function testScopedPreservationBindingWrongGenuineScopeCannotBorrowSource() public {
        _scopedFixture(1, true);
        StreamFinalityScope memory release = _scopedScope(2);
        (ScopedPreservationBindingHarness probe, bytes32 plan) = _source(release);
        StreamFinalityScope memory season = _scopedScope(3);
        (ScopedPreservationBindingHarness other,) = _source(season);
        require(probe.sourceSet() != other.sourceSet(), "distinct actual factory children");
        bindingVm.expectRevert(_invalid(probe.sourceSet()));
        probe.current(season);
        require(probe.current(release) == plan, "original exact scope retries");
    }

    function testScopedPreservationBindingCanonicalScopeGuardsBeforeFactoryReads() public {
        _scopedFixture(1, true);
        StreamFinalityScope memory scope = _scopedScope(1);
        (ScopedPreservationBindingHarness probe, bytes32 plan) = _source(scope);
        StreamFinalityScope[6] memory invalid = [
            StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0),
            StreamFinalityScope(StreamFinalityScopeType.VIEW, 1, 0, bytes32(uint256(1))),
            StreamFinalityScope(StreamFinalityScopeType.TOKEN, 0, 91, 0),
            StreamFinalityScope(StreamFinalityScopeType.TOKEN, 1, 91, bytes32(uint256(1))),
            StreamFinalityScope(StreamFinalityScopeType.RELEASE, 1, 91, bytes32(uint256(1))),
            StreamFinalityScope(StreamFinalityScopeType.SEASON, 1, 0, 0)
        ];
        for (uint256 i; i < invalid.length; ++i) {
            bindingVm.expectRevert(_invalid(address(0)));
            probe.current(invalid[i]);
        }
        require(probe.current(scope) == plan, "canonical TOKEN remains usable");
    }

    function testScopedPreservationBindingMissingCapabilityAndWrongProfileRejectConstruction()
        public
    {
        _scopedFixture(1, true);
        StreamFinalityScope memory scope = _scopedScope(1);
        (ScopedPreservationBindingHarness probe, bytes32 plan) = _source(scope);
        bytes memory capabilityInput =
            abi.encodeCall(IERC165.supportsInterface, (type(Factory).interfaceId));
        bindingVm.mockCall(address(scopedFactory), capabilityInput, abi.encode(false));
        bindingVm.expectRevert(_invalid(address(scopedFactory)));
        new ScopedPreservationBindingHarness(
            address(core), address(scopedSelections), probe.sourceSet(), SOURCE_GAS
        );
        bindingVm.mockCall(address(scopedFactory), capabilityInput, abi.encode(true));
        bytes memory profile = abi.encodeCall(Factory.scopedPolicyFactoryProfile, ());
        bindingVm.mockCall(address(scopedFactory), profile, abi.encode(bytes32(uint256(1))));
        bindingVm.expectRevert(_invalid(address(scopedFactory)));
        new ScopedPreservationBindingHarness(
            address(core), address(scopedSelections), probe.sourceSet(), SOURCE_GAS
        );
        bindingVm.mockCall(
            address(scopedFactory),
            profile,
            abi.encode(keccak256("6529STREAM_SCOPED_ENTROPY_POLICY_SOURCE_FACTORY_V2"))
        );
        ScopedPreservationBindingHarness retry = new ScopedPreservationBindingHarness(
            address(core), address(scopedSelections), probe.sourceSet(), SOURCE_GAS
        );
        require(retry.current(scope) == plan, "same factory admission restored");
    }

    function testScopedPreservationBindingExactDependenciesAndReverseFactoryRestore() public {
        _scopedFixture(1, true);
        StreamFinalityScope memory scope = _scopedScope(1);
        (ScopedPreservationBindingHarness probe, bytes32 plan) = _source(scope);
        Policies.Dependencies memory original = _scopedDependencies();
        bytes memory input = abi.encodeCall(Factory.dependencies, ());
        bytes memory canonical = abi.encode(original);
        bindingVm.mockCall(address(scopedFactory), input, bytes.concat(canonical, bytes32(0)));
        bindingVm.expectRevert(
            abi.encodeWithSelector(
                Reads.RouterEvidenceRead.selector,
                address(scopedFactory),
                Factory.dependencies.selector
            )
        );
        probe.current(scope);
        ++original.readGas;
        bindingVm.mockCall(address(scopedFactory), input, abi.encode(original));
        bindingVm.expectRevert(_invalid(address(scopedFactory)));
        probe.current(scope);
        bindingVm.mockCall(address(scopedFactory), input, canonical);
        bindingVm.mockCall(
            probe.sourceSet(), abi.encodeCall(Source.factory, ()), abi.encode(address(core))
        );
        bindingVm.expectRevert(_invalid(address(scopedFactory)));
        probe.current(scope);
        bindingVm.mockCall(
            probe.sourceSet(),
            abi.encodeCall(Source.factory, ()),
            abi.encode(address(scopedFactory))
        );
        require(probe.current(scope) == plan, "exact original dependency and reverse binding retry");
    }

    function testScopedPreservationBindingConstructorRejectsWrongCoreMetadataMembership() public {
        _scopedFixture(1, true);
        StreamFinalityScope memory scope = _scopedScope(1);
        (ScopedPreservationBindingHarness probe, bytes32 plan) = _source(scope);
        bytes memory original = abi.encode(_scopedDependencies());
        for (uint256 i; i < 3; ++i) {
            Policies.Dependencies memory changed = abi.decode(original, (Policies.Dependencies));
            changed.targets[i] = address(probe);
            changed.codeHashes[i] = address(probe).codehash;
            bindingVm.mockCall(
                address(scopedFactory),
                abi.encodeCall(Factory.dependencies, ()),
                abi.encode(changed)
            );
            bindingVm.expectRevert(_invalid(address(scopedFactory)));
            new ScopedPreservationBindingHarness(
                address(core), address(scopedSelections), probe.sourceSet(), SOURCE_GAS
            );
        }
        bindingVm.mockCall(
            address(scopedFactory), abi.encodeCall(Factory.dependencies, ()), original
        );
        require(probe.current(scope) == plan, "all constructor dependency joins restored");
    }

    function testScopedPreservationBindingFactoryPlanRegistrationAndRouteExactRetry() public {
        _scopedFixture(1, true);
        StreamFinalityScope memory scope = _scopedScope(1);
        (ScopedPreservationBindingHarness probe, bytes32 plan) = _source(scope);
        bytes memory registration = abi.encodeCall(FactoryBase.sourceSetForPlan, (plan));
        bindingVm.mockCall(
            address(scopedFactory), registration, abi.encode(probe.sourceSet(), bytes32(uint256(1)))
        );
        bindingVm.expectRevert(_invalid(probe.sourceSet()));
        probe.current(scope);
        bindingVm.mockCall(
            address(scopedFactory),
            registration,
            abi.encode(probe.sourceSet(), probe.sourceCodeHash())
        );
        bytes memory routeInput =
            abi.encodeCall(IStreamFinalityCurrentEntropyRoute.requireCurrentRoute, (scope));
        StreamFinalityCurrentComponentRoute memory original =
            scopedFactory.requireCurrentRoute(scope);
        bytes memory canonical = abi.encode(original);
        for (uint256 i; i < 4; ++i) {
            StreamFinalityCurrentComponentRoute memory changed =
                abi.decode(canonical, (StreamFinalityCurrentComponentRoute));
            if (i == 0) changed.component = address(core);
            else if (i == 1) changed.codeHash = bytes32(uint256(1));
            else if (i == 2) changed.componentType = bytes32(uint256(1));
            else changed.interfaceId = bytes4(0);
            bindingVm.mockCall(address(scopedFactory), routeInput, abi.encode(changed));
            bindingVm.expectRevert(_invalid(address(scopedFactory)));
            probe.current(scope);
        }
        bindingVm.mockCall(address(scopedFactory), routeInput, canonical);
        require(probe.current(scope) == plan, "exact original registered child and route retry");
    }

    function testScopedPreservationBindingRuntimePinsPreserveExactOriginalRetry() public {
        _scopedFixture(1, true);
        StreamFinalityScope memory scope = _scopedScope(1);
        (ScopedPreservationBindingHarness probe, bytes32 plan) = _source(scope);
        address[2] memory targets = [address(scopedFactory), probe.sourceSet()];
        for (uint256 i; i < targets.length; ++i) {
            bytes memory original = targets[i].code;
            vm.etch(targets[i], hex"00");
            bindingVm.expectRevert(_invalid(targets[i]));
            probe.current(scope);
            vm.etch(targets[i], original);
            require(probe.current(scope) == plan, "original runtime and factory identity restored");
        }
    }

    function testScopedPreservationBindingAggregateFactoryBudgetIsNotScalarGetterBudget() public {
        _scopedFixture(1, true);
        StreamFinalityScope memory scope = _scopedScope(1);
        (ScopedPreservationBindingHarness probe, bytes32 plan) = _source(scope);
        // Construction reads scalar factory facts. The same factory's current-plan call
        // must forward its actual 3m inventory budget, so a 500k outer frame cannot suffice.
        ScopedPreservationBindingHarness low = new ScopedPreservationBindingHarness(
            address(core), address(scopedSelections), probe.sourceSet(), 500000
        );
        require(
            keccak256(abi.encode(low.binding())) == keccak256(abi.encode(probe.binding())),
            "identical original facts before transport failure"
        );
        bindingVm.expectRevert(
            abi.encodeWithSelector(
                Reads.RouterEvidenceRead.selector,
                address(scopedFactory),
                FactoryBase.currentInventoryPlan.selector
            )
        );
        low.current(scope);
        require(probe.current(scope) == plan, "adequate aggregate budget preserves exact plan");
    }
}
