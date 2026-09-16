// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamFinalityEntropySourceSet.sol";
import "../../interfaces/stream/finality/IStreamFinalityCurrentComponentRoutes.sol";
import "../../interfaces/stream/finality/IStreamFinalityEntropySourceFactory.sol";

/// @notice Permissionless preparation of immutable complete entropy source sets.
/// @dev The complete provider/discovery pins this factory before the original Registry exists.
/// Later scopes derive from actual membership and must already have a complete original inventory.
/// No mutable allowlist, current coordinator substitution or caller source list is introduced.
contract StreamFinalityEntropySourceFactory is
    IStreamFinalityEntropySourceFactory,
    IStreamFinalityCurrentEntropyRoute
{
    address public immutable override core;
    address public immutable override metadataHost;
    address public immutable override scopeMembershipHost;
    address public immutable override coordinatorInventory;
    StreamFinalityCoordinatorPolicyReads.Dependencies private _dependencies;
    mapping(bytes32 => address) private _sets;
    mapping(bytes32 => bytes32) private _codeHashes;
    error EntropySourceSetMissing(bytes32 planId);
    error EntropySourceSetChanged(address sourceSet);

    constructor(StreamFinalityCoordinatorPolicyReads.Dependencies memory d) {
        StreamFinalityCoordinatorPolicyReads.validateDependencies(d);
        _dependencies = d;
        core = d.targets[0];
        metadataHost = d.targets[1];
        scopeMembershipHost = d.targets[2];
        coordinatorInventory = d.targets[3];
    }

    function supportsInterface(bytes4 id) external pure override returns (bool) {
        return id == type(IERC165).interfaceId
            || id == type(IStreamFinalityEntropySourceFactory).interfaceId
            || id == type(IStreamFinalityCurrentEntropyRoute).interfaceId;
    }

    function currentInventoryPlan(StreamFinalityScope calldata scope)
        public
        view
        override
        returns (bytes32)
    {
        return StreamFinalityCoordinatorPolicyReads.currentInventoryPlan(_dependencies, scope);
    }

    function prepareSourceSet(StreamFinalityScope calldata scope)
        external
        override
        returns (address sourceSet)
    {
        bytes32 plan = currentInventoryPlan(scope);
        sourceSet = _sets[plan];
        if (sourceSet == address(0)) {
            sourceSet = address(new StreamFinalityEntropySourceSet(_dependencies, scope, plan));
            _sets[plan] = sourceSet;
            _codeHashes[plan] = sourceSet.codehash;
            emit EntropySourceSetPrepared(
                plan,
                sourceSet,
                IStreamFinalityEntropySourceSet(sourceSet).scopeMembershipFacts().scopeSubject,
                sourceSet.codehash,
                StreamFinalityEntropySourceSet(sourceSet).sourceSetDataHash()
            );
        } else {
            _requireSet(plan, sourceSet);
            IStreamFinalityEntropySourceSet(sourceSet).requireCurrentSourceSet();
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
        IStreamFinalityEntropySourceSet(sourceSet).requireCurrentSelection();
        StreamFinalityComponentState memory s = scope.scopeType
            == StreamFinalityScopeType.COLLECTION
            ? IStreamFinalityEntropySourceSet(sourceSet).finalityState(scope.collectionId)
            : IStreamFinalityEntropySourceSet(sourceSet).finalityStateForScope(scope);
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
        IStreamFinalityEntropySourceSet(sourceSet).requireCurrentSelection();
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
        if (sourceSet.code.length == 0 || sourceSet.codehash != _codeHashes[plan]) {
            revert EntropySourceSetChanged(sourceSet);
        }
    }
}
