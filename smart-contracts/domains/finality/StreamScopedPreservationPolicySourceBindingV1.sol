// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    IStreamFinalityScopedEntropyPolicySourceFactoryV2 as Factory
} from "../../interfaces/stream/finality/IStreamFinalityScopedEntropyPolicySourceFactoryV2.sol";
import {
    IStreamFinalityEntropySourceFactory as FactoryBase
} from "../../interfaces/stream/finality/IStreamFinalityEntropySourceFactory.sol";
import {
    IStreamFinalityEntropyPolicySourceSet as Source
} from "../../interfaces/stream/finality/IStreamFinalityEntropyPolicySourceSet.sol";
import {
    IStreamStaticSelectionCheckpoint as Selection
} from "../../interfaces/stream/finality/IStreamStaticSelectionCheckpoint.sol";
import {
    IStreamFinalityCurrentEntropyRoute,
    StreamFinalityCurrentComponentRoute
} from "../../interfaces/stream/finality/IStreamFinalityCurrentComponentRoutes.sol";
import {
    IStreamArtworkScopedFinalityComponent
} from "../../interfaces/stream/finality/IStreamArtworkFinalityComponents.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType,
    StreamFinalityDomains
} from "../../interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import { IERC165 } from "../../vendor/openzeppelin/IERC165.sol";
import {
    StreamFinalityCoordinatorPolicyReadsV2 as Policies
} from "./StreamFinalityCoordinatorPolicyReadsV2.sol";
import { StreamFinalityRouterEvidence as Reads } from "./StreamFinalityRouterEvidence.sol";

/// @notice Original scoped policy factory joins for new preservation consumers.
/// @dev Consumers retain the returned constructor binding and their own source/runtime pins.
/// This leaf does not establish preservation-render admission, complete selection, or the
/// source set's full current policy proof; the consuming checkpoint must establish those.
/// Every external source read here is an exact-size bounded STATICCALL. readGas must cover
/// the aggregate factory current-plan/current-route calls, not merely scalar getters.
library StreamScopedPreservationPolicySourceBindingV1 {
    struct Binding {
        address factory;
        bytes32 factoryCodeHash;
        bytes32 dependenciesHash;
    }

    error InvalidScopedPreservationPolicySourceBinding(address target);

    function bind(address core, address selection, address sourceSet, uint256 readGas)
        public
        view
        returns (Binding memory result)
    {
        _pin(core, core.codehash);
        _pin(selection, selection.codehash);
        _pin(sourceSet, sourceSet.codehash);
        result.factory = abi.decode(
            Reads.read(sourceSet, abi.encodeCall(Source.factory, ()), 32, readGas), (address)
        );
        result.factoryCodeHash = result.factory.codehash;
        _pin(result.factory, result.factoryCodeHash);
        if (
            abi.decode(
                        Reads.read(
                            result.factory,
                            abi.encodeCall(IERC165.supportsInterface, (type(Factory).interfaceId)),
                            32,
                            readGas
                        ),
                        (uint256)
                    ) != 1
                || abi.decode(
                        Reads.read(
                            result.factory,
                            abi.encodeCall(Factory.scopedPolicyFactoryProfile, ()),
                            32,
                            readGas
                        ),
                        (bytes32)
                    ) != keccak256("6529STREAM_SCOPED_ENTROPY_POLICY_SOURCE_FACTORY_V2")
        ) revert InvalidScopedPreservationPolicySourceBinding(result.factory);
        bytes memory raw =
            Reads.read(result.factory, abi.encodeCall(Factory.dependencies, ()), 352, readGas);
        Policies.Dependencies memory d = abi.decode(raw, (Policies.Dependencies));
        result.dependenciesHash = keccak256(raw);
        if (
            result.dependenciesHash != keccak256(abi.encode(d)) || d.targets[0] != core
                || d.codeHashes[0] != core.codehash
                || d.targets[2]
                    != abi.decode(
                        Reads.read(
                            selection, abi.encodeCall(Selection.scopeMembership, ()), 32, readGas
                        ),
                        (address)
                    )
                || d.targets[1]
                    != abi.decode(
                        Reads.read(
                            selection, abi.encodeWithSignature("metadataHost()"), 32, readGas
                        ),
                        (address)
                    )
        ) revert InvalidScopedPreservationPolicySourceBinding(result.factory);
        Policies.validateDependencies(d);
    }

    /// @dev The base separately checks its deployment chain, selection and complete membership.
    /// No caller-created source set can borrow another genuine scope's factory registration.
    function requireCurrent(
        Binding memory fixedBinding,
        address sourceSet,
        bytes32 sourceSetCodeHash,
        StreamFinalityScope memory scope,
        uint256 readGas
    ) public view returns (bytes32 plan) {
        _scope(scope);
        _pin(fixedBinding.factory, fixedBinding.factoryCodeHash);
        _pin(sourceSet, sourceSetCodeHash);
        if (
            fixedBinding.dependenciesHash == 0
                || keccak256(
                        Reads.read(
                            fixedBinding.factory,
                            abi.encodeCall(Factory.dependencies, ()),
                            352,
                            readGas
                        )
                    ) != fixedBinding.dependenciesHash
                || abi.decode(
                        Reads.read(sourceSet, abi.encodeCall(Source.factory, ()), 32, readGas),
                        (address)
                    ) != fixedBinding.factory
        ) revert InvalidScopedPreservationPolicySourceBinding(fixedBinding.factory);
        plan = abi.decode(
            Reads.read(
                fixedBinding.factory,
                abi.encodeCall(FactoryBase.currentInventoryPlan, (scope)),
                32,
                readGas
            ),
            (bytes32)
        );
        (address saved, bytes32 runtime) = abi.decode(
            Reads.read(
                fixedBinding.factory,
                abi.encodeCall(FactoryBase.sourceSetForPlan, (plan)),
                64,
                readGas
            ),
            (address, bytes32)
        );
        if (
            plan == 0 || saved != sourceSet || runtime != sourceSetCodeHash
                || plan
                    != abi.decode(
                        Reads.read(
                            sourceSet, abi.encodeCall(Source.inventoryPlan, ()), 32, readGas
                        ),
                        (bytes32)
                    )
        ) revert InvalidScopedPreservationPolicySourceBinding(sourceSet);
        bytes memory raw = Reads.read(
            fixedBinding.factory,
            abi.encodeCall(IStreamFinalityCurrentEntropyRoute.requireCurrentRoute, (scope)),
            128,
            readGas
        );
        StreamFinalityCurrentComponentRoute memory route =
            abi.decode(raw, (StreamFinalityCurrentComponentRoute));
        if (
            keccak256(raw) != keccak256(abi.encode(route)) || route.component != sourceSet
                || route.codeHash != sourceSetCodeHash
                || route.componentType != StreamFinalityDomains.COMPONENT_ENTROPY_COORDINATOR
                || route.interfaceId != type(IStreamArtworkScopedFinalityComponent).interfaceId
        ) revert InvalidScopedPreservationPolicySourceBinding(fixedBinding.factory);
    }

    function _scope(StreamFinalityScope memory scope) private pure {
        if (
            scope.collectionId == 0
                || (scope.scopeType == StreamFinalityScopeType.TOKEN
                        ? scope.tokenId == 0 || scope.scopeId != 0
                        : (scope.scopeType != StreamFinalityScopeType.RELEASE
                            && scope.scopeType != StreamFinalityScopeType.SEASON)
                        || scope.tokenId != 0 || scope.scopeId == 0)
        ) revert InvalidScopedPreservationPolicySourceBinding(address(0));
    }

    function _pin(address target, bytes32 runtime) private view {
        if (target.code.length == 0 || runtime == 0 || target.codehash != runtime) {
            revert InvalidScopedPreservationPolicySourceBinding(target);
        }
    }
}
