// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamFinalityRecoveryBindings.sol";
import "./StreamFinalityRecoveryState.sol";
import "./StreamFinalityRecoveryScopeMembership.sol";
import "../artist/StreamArtistRecoveryOriginalReads.sol";
import { IStreamCoreIdentity } from "../../interfaces/stream/core/IStreamCoreIdentity.sol";

/// @notice Original artist-sanctioned lineage and exact-scope recovery route selection.
/// @dev Inherited families use the original Registry's fixed membership universe. Historical
///      exact recovery heads retain their admitted original scope without fresh membership reads.
library StreamFinalityRecoveryRoutes {
    error FinalityRecoveryRouteMissing(bytes32 routeType);
    error FinalityRecoveryRouteAmbiguous(bytes32 routeType);
    error FinalityRecoveryOriginalRecordMissing(bytes32 scopeKey);
    error FinalityRecoveryOriginalRecordMismatch(bytes32 expected, bytes32 actual);
    error FinalityRecoveryReplacementUnreadable(bytes32 routeType, address target);
    error FinalityRecoveryReplacementTypeMismatch(bytes32 expected, bytes32 actual);
    error FinalityRecoveryInheritedScopeUnsupported(uint8 scopeType);
    error FinalityRecoveryScopeMembershipInvalid();

    struct Selection {
        bool pinned;
        StreamFinalityComponentExpectation route;
        bytes32 originalFinalityRecordHash;
        StreamFinalityScope originalScope;
        StreamFinalityScope routeScope;
        bytes32 recoveryId;
        bytes32 exactHead;
        uint64 exactGeneration;
        bytes32 artistId;
    }

    function resolve(
        StreamFinalityRecoveryState.State storage state,
        StreamFinalityRecoveryBindings.Bound memory b,
        bytes32 routeType,
        StreamFinalityScope memory scope
    ) public view returns (Selection memory s) {
        StreamFinalityRecoveryIntentState.shape(scope);
        StreamFinalityRecoveryBindings.pins(b, false);
        bytes32 key = StreamFinalityRecoveryHashes.scopeKey(scope);
        StreamFinalityRecoveryState.Head memory head = state.heads[key];
        s.exactHead = head.recoveryId;
        s.exactGeneration = head.generation;
        bytes32 selectedKey = key;
        bytes32 original =
            head.recoveryId == 0 ? _original(b, scope, routeType) : head.originalFinalityRecordHash;
        if (original == 0 && scope.scopeType != StreamFinalityScopeType.COLLECTION) {
            StreamFinalityScope memory collection =
                StreamFinalityScope(StreamFinalityScopeType.COLLECTION, scope.collectionId, 0, 0);
            selectedKey = StreamFinalityRecoveryHashes.scopeKey(collection);
            StreamFinalityRecoveryState.Head memory collectionHead = state.heads[selectedKey];
            original = collectionHead.recoveryId == 0
                ? _original(b, collection, routeType)
                : collectionHead.originalFinalityRecordHash;
        }
        if (original == 0) return s;
        StreamArtistRecoveryOriginalReads.Observation memory o =
            StreamArtistRecoveryOriginalReads.observe(
                b.suite,
                StreamArtistRecoveryOriginalReads.Pins(
                    b.inputs.originalFinality,
                    b.codeHashes[4],
                    b.codeHashes[0],
                    b.codeHashes[1],
                    b.inputs.readGas
                ),
                original
            );
        if (o.scope.collectionId != scope.collectionId) {
            revert FinalityRecoveryScopeMembershipInvalid();
        }
        if (head.recoveryId != 0) {
            if (keccak256(abi.encode(head.originalScope)) != keccak256(abi.encode(o.scope))) {
                revert FinalityRecoveryOriginalRecordMismatch(
                    head.originalFinalityRecordHash, original
                );
            }
        } else if (keccak256(abi.encode(scope)) != keccak256(abi.encode(o.scope))) {
            if (o.scope.scopeType != StreamFinalityScopeType.COLLECTION) {
                revert FinalityRecoveryScopeMembershipInvalid();
            }
            _inherited(b, scope);
        }
        s.originalFinalityRecordHash = original;
        s.originalScope = o.scope;
        s.routeScope = o.scope;
        s.artistId = o.sanction.artistId;
        uint256 found;
        for (uint256 i; i < o.components.length; ++i) {
            if (o.components[i].componentType == routeType) {
                ++found;
                s.route = o.components[i];
            }
        }
        if (found > 1) revert FinalityRecoveryRouteAmbiguous(routeType);
        if (found == 0) return s;
        s.pinned = true;
        bytes32 overrideId = state.routeOverrides[selectedKey][routeType];
        if (overrideId != 0) {
            StreamFinalityRecoveryRecord storage r = state.records[overrideId];
            if (
                !r.executed || r.originalFinalityRecordHash != original
                    || r.replacementRoute.componentType != routeType
                    || StreamFinalityRecoveryHashes.scopeKey(r.scope) != selectedKey
            ) {
                revert FinalityRecoveryOriginalRecordMismatch(
                    original, r.originalFinalityRecordHash
                );
            }
            s.route = r.replacementRoute;
            s.routeScope = r.scope;
            s.recoveryId = overrideId;
        }
        StreamFinalityRecoveryBindings.pins(b, false);
    }

    function requireReplacement(
        StreamFinalityComponentExpectation memory route,
        StreamFinalityScope memory scope,
        bytes32 expectedType,
        uint256 cap
    ) public view {
        if (route.componentType != expectedType) {
            revert FinalityRecoveryReplacementTypeMismatch(expectedType, route.componentType);
        }
        bytes4 expectedInterface = scope.scopeType == StreamFinalityScopeType.COLLECTION
            ? type(IStreamArtworkFinalityComponent).interfaceId
            : type(IStreamArtworkScopedFinalityComponent).interfaceId;
        if (
            route.componentType == 0 || route.interfaceId != expectedInterface
                || route.moduleVersion == 0 || route.manifestHash == 0
                || !matches(route, scope, cap)
        ) revert FinalityRecoveryReplacementUnreadable(route.componentType, route.component);
    }

    /// @notice Current exact component health, separate from the immutable selected route.
    function matches(
        StreamFinalityComponentExpectation memory route,
        StreamFinalityScope memory scope,
        uint256 cap
    ) public view returns (bool) {
        if (cap == 0 || cap > type(uint256).max / 64) {
            revert StreamFinalityRecoveryBindings.FinalityRecoveryBindingInvalid(route.component);
        }
        bytes memory data = scope.scopeType == StreamFinalityScopeType.COLLECTION
            ? abi.encodeCall(IStreamArtworkFinalityComponent.finalityState, (scope.collectionId))
            : abi.encodeCall(IStreamArtworkScopedFinalityComponent.finalityStateForScope, (scope));
        uint256 required = cap + cap / 63 + 100000;
        if (gasleft() <= required) {
            revert StreamFinalityRecoveryBindings.FinalityRecoveryParentGas(gasleft(), required);
        }
        return StreamFinalityComponentSet.componentStillMatches(route, data, cap);
    }

    function _original(
        StreamFinalityRecoveryBindings.Bound memory b,
        StreamFinalityScope memory scope,
        bytes32 kind
    ) private view returns (bytes32) {
        bytes memory raw = StreamFinalityRecoveryBindings.fixedRead(
            b.inputs.originalFinality,
            abi.encodeCall(
                IStreamArtworkScopedFrozenRouteRegistry.frozenRouteForScope, (kind, scope)
            ),
            128,
            b.inputs.readGas
        );
        uint256 pin;
        uint256 module_;
        bytes32 route;
        bytes32 hash;
        assembly ("memory-safe") {
            pin := mload(add(raw, 32))
            module_ := mload(add(raw, 64))
            route := mload(add(raw, 96))
            hash := mload(add(raw, 128))
        }
        if (
            pin > 1 || module_ >> 160 != 0
                || (pin == 1 && (module_ == 0 || route == 0 || hash == 0))
                || (pin == 0 && (module_ != 0 || route != 0))
        ) revert FinalityRecoveryScopeMembershipInvalid();
        // The pinned original runtime reports an exact record hash even when this route is absent.
        // observe() separately authenticates that record, scope, sorted components and sanction.
        return hash;
    }

    function _inherited(
        StreamFinalityRecoveryBindings.Bound memory b,
        StreamFinalityScope memory scope
    ) private view {
        if (scope.scopeType != StreamFinalityScopeType.TOKEN) {
            _family(b, scope);
            return;
        }
        bytes memory raw = StreamFinalityRecoveryBindings.fixedRead(
            b.inputs.core,
            abi.encodeCall(IStreamCoreIdentity.tokenCollectionIdentity, (scope.tokenId)),
            128,
            b.inputs.readGas
        );
        uint256 mapped;
        uint256 collection;
        uint256 serial;
        uint256 burned;
        assembly ("memory-safe") {
            mapped := mload(add(raw, 32))
            collection := mload(add(raw, 64))
            serial := mload(add(raw, 96))
            burned := mload(add(raw, 128))
        }
        if (mapped != 1 || collection != scope.collectionId || serial == 0 || burned > 1) {
            revert FinalityRecoveryScopeMembershipInvalid();
        }
        raw = StreamFinalityRecoveryBindings.fixedRead(
            b.inputs.core,
            abi.encodeCall(IStreamCoreIdentity.tokenLifecycle, (scope.tokenId)),
            32,
            b.inputs.readGas
        );
        uint256 lifecycle = abi.decode(raw, (uint256));
        if ((lifecycle != 2 && lifecycle != 3) || (burned == 1) != (lifecycle == 3)) {
            revert FinalityRecoveryScopeMembershipInvalid();
        }
    }

    /// @notice New preparation rechecks inherited family membership even after an exact head exists.
    /// @dev Exact original scopes and TOKEN retain their existing independent admission rules.
    function requireInheritedFamily(
        StreamFinalityRecoveryBindings.Bound memory b,
        StreamFinalityScope memory original,
        StreamFinalityScope memory requested
    ) public view {
        if (
            original.scopeType != StreamFinalityScopeType.COLLECTION
                || requested.scopeType < StreamFinalityScopeType.RELEASE
        ) return;
        if (
            original.collectionId == 0 || original.collectionId != requested.collectionId
                || original.tokenId != 0 || original.scopeId != 0
        ) revert FinalityRecoveryScopeMembershipInvalid();
        _family(b, requested);
    }

    function _family(
        StreamFinalityRecoveryBindings.Bound memory b,
        StreamFinalityScope memory scope
    ) private view {
        StreamFinalityRecoveryScopeMembership.read(
            StreamFinalityRecoveryScopeMembership.Environment(
                b.inputs.core,
                b.inputs.originalFinality,
                b.codeHashes[4],
                b.suite.metadata,
                b.inputs.readGas
            ),
            scope
        );
    }
}
