// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamFinalityEntropyPolicySourceDeploymentV2.sol";
import "../../interfaces/stream/finality/IStreamFinalityEntropyPolicySourceFactoryV2.sol";
import "../../interfaces/stream/finality/IStreamFinalityCurrentComponentRoutes.sol";
import "../../interfaces/stream/finality/IStreamFinalityEntropySourceFactory.sol";

/// @notice Permissionless preparation of complete COLLECTION V2 policy source sets.
/// @dev The matched V2 provider pins this factory separately from its unchanged original V1 factory.
/// Actual complete original inventory and full frozen V2 policies determine every source set.
/// Terminal status never fabricates a finalized seed. No caller list or current-pointer substitution.
contract StreamFinalityEntropyPolicySourceFactoryV2 is
    IStreamFinalityEntropyPolicySourceFactoryV2,
    IStreamFinalityCurrentEntropyRoute
{
    address public immutable override core;
    address public immutable override metadataHost;
    address public immutable override scopeMembershipHost;
    address public immutable override coordinatorInventory;
    StreamFinalityCoordinatorPolicyReadsV2.Dependencies private _dependencies;
    mapping(bytes32 => address) private _sets;
    mapping(bytes32 => bytes32) private _codeHashes;
    error EntropyPolicyFactoryScope();
    error EntropySourceSetMissing(bytes32 planId);
    error EntropySourceSetChanged(address sourceSet);

    constructor(StreamFinalityCoordinatorPolicyReadsV2.Dependencies memory d) {
        StreamFinalityCoordinatorPolicyReadsV2.validateDependencies(d);
        _dependencies = d;
        core = d.targets[0];
        metadataHost = d.targets[1];
        scopeMembershipHost = d.targets[2];
        coordinatorInventory = d.targets[3];
    }

    function supportsInterface(bytes4 id) external pure override returns (bool) {
        return id == type(IERC165).interfaceId
            || id == type(IStreamFinalityEntropySourceFactory).interfaceId
            || id == type(IStreamFinalityEntropyPolicySourceFactoryV2).interfaceId
            || id == type(IStreamFinalityCurrentEntropyRoute).interfaceId;
    }

    function policyFactoryProfile() external pure override returns (bytes32) {
        return keccak256("6529STREAM_ENTROPY_POLICY_SOURCE_FACTORY_V2");
    }

    function dependencies()
        external
        view
        override
        returns (StreamFinalityCoordinatorPolicyReadsV2.Dependencies memory)
    {
        return _dependencies;
    }

    function currentInventoryPlan(StreamFinalityScope calldata scope)
        public
        view
        override
        returns (bytes32)
    {
        if (
            scope.scopeType != StreamFinalityScopeType.COLLECTION || scope.collectionId == 0
                || scope.tokenId != 0 || scope.scopeId != 0
        ) revert EntropyPolicyFactoryScope();
        return StreamFinalityCoordinatorPolicyReadsV2.currentInventoryPlan(_dependencies, scope);
    }

    function prepareSourceSet(StreamFinalityScope calldata scope)
        external
        override
        returns (address sourceSet)
    {
        bytes32 plan = currentInventoryPlan(scope);
        sourceSet = _sets[plan];
        if (sourceSet == address(0)) {
            sourceSet =
                StreamFinalityEntropyPolicySourceDeploymentV2.deploy(_dependencies, scope, plan);
            _sets[plan] = sourceSet;
            _codeHashes[plan] = sourceSet.codehash;
            emit EntropySourceSetPrepared(
                plan,
                sourceSet,
                IStreamFinalityEntropyPolicySourceSet(sourceSet)
                .scopeMembershipFacts()
                .scopeSubject,
                sourceSet.codehash,
                StreamFinalityEntropyPolicySourceSet(sourceSet).sourceSetDataHash()
            );
        } else {
            _requireSet(plan, sourceSet);
            IStreamFinalityEntropyPolicySourceSet(sourceSet).requireCurrentSourceSet();
        }
    }

    function sourceSetForPlan(bytes32 plan)
        external
        view
        override
        returns (address sourceSet, bytes32 codeHash)
    {
        return (_sets[plan], _codeHashes[plan]);
    }

    function requireCurrentComponent(StreamFinalityScope calldata scope)
        external
        view
        override
        returns (StreamFinalityComponentExpectation memory)
    {
        bytes32 plan = currentInventoryPlan(scope);
        address sourceSet = _sets[plan];
        if (sourceSet == address(0)) revert EntropySourceSetMissing(plan);
        _requireSet(plan, sourceSet);
        // Whole discovery consumes this projection; the Registry does not perform this gate for it.
        IStreamFinalityEntropyPolicySourceSet(sourceSet).requireCurrentSelection();
        StreamFinalityComponentState memory s = scope.scopeType
            == StreamFinalityScopeType.COLLECTION
            ? IStreamFinalityEntropyPolicySourceSet(sourceSet).finalityState(scope.collectionId)
            : IStreamFinalityEntropyPolicySourceSet(sourceSet).finalityStateForScope(scope);
        return StreamFinalityComponentExpectation(
            s.componentType,
            s.component,
            s.interfaceId,
            s.codeHash,
            s.moduleVersion,
            s.manifestHash,
            s.dataHash
        );
    }

    function requireCurrentRoute(StreamFinalityScope calldata scope)
        external
        view
        override
        returns (StreamFinalityCurrentComponentRoute memory)
    {
        bytes32 plan = currentInventoryPlan(scope);
        address sourceSet = _sets[plan];
        if (sourceSet == address(0)) revert EntropySourceSetMissing(plan);
        _requireSet(plan, sourceSet);
        // Current completeness and selected Metadata remain mandatory. Historical finalityState
        // alone does not establish them; the Registry independently reads that state afterward.
        IStreamFinalityEntropyPolicySourceSet(sourceSet).requireCurrentSelection();
        return StreamFinalityCurrentComponentRoute(
            StreamFinalityDomains.COMPONENT_ENTROPY_COORDINATOR,
            sourceSet,
            scope.scopeType == StreamFinalityScopeType.COLLECTION
                ? type(IStreamArtworkFinalityComponent).interfaceId
                : type(IStreamArtworkScopedFinalityComponent).interfaceId,
            _codeHashes[plan]
        );
    }

    function _requireSet(bytes32 plan, address sourceSet) private view {
        if (
            sourceSet.code.length == 0 || sourceSet.codehash != _codeHashes[plan]
                || IStreamFinalityEntropyPolicySourceSet(sourceSet).factory() != address(this)
                || IStreamFinalityEntropyPolicySourceSet(sourceSet).core() != core
                || IStreamFinalityEntropyPolicySourceSet(sourceSet).inventoryPlan() != plan
        ) {
            revert EntropySourceSetChanged(sourceSet);
        }
    }
}
