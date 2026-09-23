// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamCurrentAuthorityNativeEvidenceProvider.sol";

/// @notice Original COLLECTION operations for the deferred provider's fixed native profile.
/// @dev The existing graph.original root is an immutable duplicate of the inherited native
/// configuration. Its first four pins, chain and read budget equal the original Router
/// immutables by construction. Delegatecalls retain the host identity and original caller;
/// original Registry admission and the existing self-call to the Router anchor stay ordered.
library StreamCurrentAuthorityDeferredScopedPolicyNativeWorkerV2 {
    error NativeProviderOriginalRegistryOnly();
    error RouterProviderConfiguration();
    error RouterProviderDependency(address target);
    error RouterProviderScope();

    function inputManifestBytes(
        StreamFinalityNativeProviderReads.Config storage original,
        StreamFinalityScope calldata scope
    ) public view returns (bytes memory) {
        StreamFinalityNativeProviderReads.Config memory c = original;
        _candidate(c, scope);
        StreamFinalityInputManifestTypes.Statement memory s =
            StreamCurrentAuthorityNativeProviderReads.statement(
                c, scope, StreamCurrentAuthorityNativeProviderReads.currentComponents(c, scope)
            );
        return StreamFinalityInputManifestReads.encode(
            StreamCurrentAuthorityNativeProviderReads.manifestDependencies(c), s
        );
    }

    function requireFinalityScopeInputs(
        StreamFinalityNativeProviderReads.Config storage original,
        StreamFinalityScope calldata scope,
        bytes32 manifestHash
    ) public view returns (StreamFinalityScopeInputs memory, bytes32, bytes32) {
        StreamFinalityNativeProviderReads.Config memory c = original;
        _candidate(c, scope);
        return _admit(
            c,
            scope,
            manifestHash,
            StreamCurrentAuthorityNativeProviderReads.currentComponents(c, scope)
        );
    }

    function requireSanctionReviewFacts(
        StreamFinalityNativeProviderReads.Config storage original,
        StreamFinalityScope calldata scope,
        bytes32 manifestHash
    ) public view returns (IStreamFinalitySanctionReview.ReviewFacts memory) {
        StreamFinalityNativeProviderReads.Config memory c = original;
        _candidate(c, scope);
        StreamFinalityInputManifestTypes.Statement memory s =
            StreamCurrentAuthorityNativeProviderReads.statement(
                c, scope, StreamCurrentAuthorityNativeProviderReads.currentComponents(c, scope)
            );
        StreamFinalityInputManifestReads.requireCurrent(
            StreamCurrentAuthorityNativeProviderReads.manifestDependencies(c), s, manifestHash
        );
        return StreamCurrentAuthorityNativeSanctionReview.review(c, s);
    }

    function requirePreparedFinalityScopeInputs(
        StreamFinalityNativeProviderReads.Config storage original,
        StreamFinalityScope calldata scope,
        bytes32 manifestHash,
        StreamFinalityComponentExpectation[] calldata components
    ) public view returns (StreamFinalityScopeInputs memory, bytes32, bytes32) {
        StreamFinalityNativeProviderReads.Config memory c = original;
        _requirePreparedCandidate(c, scope, components);
        return _admit(
            c,
            scope,
            manifestHash,
            StreamCurrentAuthorityNativeProviderReads.independentComponents(components)
        );
    }

    function requirePreparedFinalityScopeInputsAndReview(
        StreamFinalityNativeProviderReads.Config storage original,
        StreamFinalityScope calldata scope,
        bytes32 manifestHash,
        StreamFinalityComponentExpectation[] calldata components
    )
        public
        view
        returns (
            StreamFinalityScopeInputs memory inputs,
            bytes32 schema,
            bytes32 canon,
            IStreamFinalitySanctionReview.ReviewFacts memory review
        )
    {
        StreamFinalityNativeProviderReads.Config memory c = original;
        _requirePreparedCandidate(c, scope, components);
        StreamFinalityInputManifestTypes.Statement memory s =
            StreamCurrentAuthorityNativeProviderReads.statement(
                c,
                scope,
                StreamCurrentAuthorityNativeProviderReads.independentComponents(components)
            );
        (schema, canon) = StreamFinalityInputManifestReads.requireCurrent(
            StreamCurrentAuthorityNativeProviderReads.manifestDependencies(c), s, manifestHash
        );
        inputs = s.inputs;
        review = StreamCurrentAuthorityNativeSanctionReview.review(c, s);
    }

    function _requirePreparedCandidate(
        StreamFinalityNativeProviderReads.Config memory c,
        StreamFinalityScope calldata scope,
        StreamFinalityComponentExpectation[] calldata components
    ) private view {
        if (
            msg.sender != c.targets[12] || msg.sender.code.length == 0
                || msg.sender.codehash != c.codeHashes[12]
        ) {
            revert NativeProviderOriginalRegistryOnly();
        }
        _candidate(c, scope);
        if (!StreamFinalityRouteReads.verifyIfSupported(
                c.targets[13], scope, components, components.length == 10, c.sourceGas
            )) {
            revert StreamCurrentAuthorityNativeProviderReads.NativeProviderSource();
        }
    }

    function _admit(
        StreamFinalityNativeProviderReads.Config memory c,
        StreamFinalityScope memory scope,
        bytes32 manifestHash,
        StreamFinalityComponentExpectation[] memory components
    ) private view returns (StreamFinalityScopeInputs memory, bytes32 schema, bytes32 canon) {
        StreamFinalityInputManifestTypes.Statement memory s =
            StreamCurrentAuthorityNativeProviderReads.statement(c, scope, components);
        (schema, canon) = StreamFinalityInputManifestReads.requireCurrent(
            StreamCurrentAuthorityNativeProviderReads.manifestDependencies(c), s, manifestHash
        );
        return (s.inputs, schema, canon);
    }

    function _candidate(
        StreamFinalityNativeProviderReads.Config memory c,
        StreamFinalityScope memory scope
    ) private view {
        StreamCurrentAuthorityNativeProviderReads.requirePins(c);
        if (
            scope.scopeType != StreamFinalityScopeType.COLLECTION || scope.tokenId != 0
                || scope.scopeId != 0 || _collectionMetadataMode(c, scope.collectionId) != 1
        ) revert RouterProviderScope();
        IStreamFinalityRouterEvidenceBinding(address(this))
            .requireCurrentRouterCandidate(scope.collectionId, c.targets[12]);
    }

    function _collectionMetadataMode(StreamFinalityNativeProviderReads.Config memory c, uint256 cid)
        private
        view
        returns (uint8)
    {
        _pins(c);
        bytes memory raw = StreamFinalityBoundedReads.read(
            c.targets[2],
            abi.encodeCall(IStreamMetadataServingFacts.collectionServingFacts, (cid)),
            512,
            c.readGas
        );
        IStreamMetadataServingFacts.ServingFacts memory f =
            abi.decode(raw, (IStreamMetadataServingFacts.ServingFacts));
        if (!f.configured || keccak256(raw) != keccak256(abi.encode(f))) {
            revert RouterProviderScope();
        }
        if (f.mode == keccak256("ONCHAIN")) return 1;
        if (f.mode == keccak256("OFFCHAIN")) return 0;
        revert RouterProviderScope();
    }

    function _pins(StreamFinalityNativeProviderReads.Config memory c) private view {
        if (block.chainid != c.chainId) revert RouterProviderConfiguration();
        for (uint256 i; i < 4; ++i) {
            address target = c.targets[i];
            if (target.code.length == 0 || target.codehash != c.codeHashes[i]) {
                revert RouterProviderDependency(target);
            }
        }
    }
}
