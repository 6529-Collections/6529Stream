// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamFinalityScopedPolicyProviderReadsV2
} from "./StreamFinalityScopedPolicyProviderReadsV2.sol";
import {
    IStreamMetadataServingFacts
} from "../../interfaces/stream/metadata/IStreamMetadataServingFacts.sol";
import "./StreamCurrentAuthorityScopedPolicyProviderReadsV2.sol";
import "./StreamCurrentAuthorityScopedPolicySanctionReviewV2.sol";
import "./StreamFinalityRouteReads.sol";

interface IStreamCurrentAuthorityScopedPolicyProviderOriginalAnchorV2 {
    function requireCurrentRouterCandidate(uint256 collectionId, address registry) external view;
}

/// @notice Fixed operations for the selected combined provider's distinct scoped profile.
/// @dev Runs in that host's context using only its constructor-owned Config. Original Registry
/// caller/route checks remain mandatory for prepared inputs. This is not a detached provider.
library StreamCurrentAuthorityScopedPolicyProviderOperationsV2 {
    error ScopedProviderRegistryOnly();

    function manifest(
        StreamFinalityScopedPolicyProviderReadsV2.Config memory c,
        StreamFinalityScope memory scope
    ) public view returns (bytes memory) {
        _candidate(c, scope);
        StreamScopedFinalityInputManifestTypes.Statement memory s =
            StreamCurrentAuthorityScopedPolicyProviderReadsV2.statement(
                c,
                scope,
                StreamCurrentAuthorityScopedPolicyProviderReadsV2.currentComponents(c, scope)
            );
        return StreamScopedFinalityInputManifestReads.encode(
            StreamCurrentAuthorityScopedPolicyProviderReadsV2.manifestDependencies(c), s
        );
    }

    function inputs(
        StreamFinalityScopedPolicyProviderReadsV2.Config memory c,
        StreamFinalityScope memory scope,
        bytes32 manifestHash
    ) public view returns (StreamFinalityScopeInputs memory, bytes32 schema, bytes32 canon) {
        _candidate(c, scope);
        StreamScopedFinalityInputManifestTypes.Statement memory s =
            StreamCurrentAuthorityScopedPolicyProviderReadsV2.statement(
                c,
                scope,
                StreamCurrentAuthorityScopedPolicyProviderReadsV2.currentComponents(c, scope)
            );
        (schema, canon) = StreamScopedFinalityInputManifestReads.requireCurrent(
            StreamCurrentAuthorityScopedPolicyProviderReadsV2.manifestDependencies(c),
            s,
            manifestHash
        );
        return (s.inputs, schema, canon);
    }

    function review(
        StreamFinalityScopedPolicyProviderReadsV2.Config memory c,
        StreamFinalityScope memory scope,
        bytes32 manifestHash
    ) public view returns (IStreamFinalitySanctionReview.ReviewFacts memory) {
        _candidate(c, scope);
        StreamScopedFinalityInputManifestTypes.Statement memory s =
            StreamCurrentAuthorityScopedPolicyProviderReadsV2.statement(
                c,
                scope,
                StreamCurrentAuthorityScopedPolicyProviderReadsV2.currentComponents(c, scope)
            );
        StreamScopedFinalityInputManifestReads.requireCurrent(
            StreamCurrentAuthorityScopedPolicyProviderReadsV2.manifestDependencies(c),
            s,
            manifestHash
        );
        return StreamCurrentAuthorityScopedPolicySanctionReviewV2.review(c, s);
    }

    function prepared(
        StreamFinalityScopedPolicyProviderReadsV2.Config memory c,
        StreamFinalityScope memory scope,
        bytes32 manifestHash,
        StreamFinalityComponentExpectation[] memory components,
        bool withReview
    )
        public
        view
        returns (
            StreamFinalityScopeInputs memory inputs_,
            bytes32 schema,
            bytes32 canon,
            IStreamFinalitySanctionReview.ReviewFacts memory review_
        )
    {
        if (
            msg.sender != c.targets[12] || msg.sender.code.length == 0
                || msg.sender.codehash != c.codeHashes[12]
        ) {
            revert ScopedProviderRegistryOnly();
        }
        _candidate(c, scope);
        if (!StreamFinalityRouteReads.verifyIfSupported(
                c.targets[13], scope, components, components.length == 10, c.sourceGas
            )) {
            revert StreamCurrentAuthorityScopedPolicyProviderReadsV2.NativeProviderSource();
        }
        StreamScopedFinalityInputManifestTypes.Statement memory s =
            StreamCurrentAuthorityScopedPolicyProviderReadsV2.statement(
                c,
                scope,
                StreamCurrentAuthorityScopedPolicyProviderReadsV2.independentComponents(components)
            );
        (schema, canon) = StreamScopedFinalityInputManifestReads.requireCurrent(
            StreamCurrentAuthorityScopedPolicyProviderReadsV2.manifestDependencies(c),
            s,
            manifestHash
        );
        inputs_ = s.inputs;
        if (withReview) review_ = StreamCurrentAuthorityScopedPolicySanctionReviewV2.review(c, s);
    }

    function _candidate(
        StreamFinalityScopedPolicyProviderReadsV2.Config memory c,
        StreamFinalityScope memory scope
    ) private view {
        StreamCurrentAuthorityScopedPolicyProviderReadsV2.requirePins(c);
        if (
            scope.scopeType != StreamFinalityScopeType.TOKEN
                && scope.scopeType != StreamFinalityScopeType.RELEASE
                && scope.scopeType != StreamFinalityScopeType.SEASON
        ) revert StreamCurrentAuthorityScopedPolicyProviderReadsV2.NativeProviderScope();
        // Validate every canonical scope coordinate before asking the original common anchor.
        StreamMetadataSubjects.scopeSubject(c.chainId, c.targets[0], scope);
        bytes memory raw = StreamFinalityBoundedReads.read(
            c.targets[2],
            abi.encodeCall(
                IStreamMetadataServingFacts.collectionServingFacts, (scope.collectionId)
            ),
            512,
            c.readGas
        );
        IStreamMetadataServingFacts.ServingFacts memory f =
            abi.decode(raw, (IStreamMetadataServingFacts.ServingFacts));
        if (
            !f.configured || f.mode != keccak256("ONCHAIN")
                || keccak256(raw) != keccak256(abi.encode(f))
        ) {
            revert StreamCurrentAuthorityScopedPolicyProviderReadsV2.NativeProviderScope();
        }
        // This is the actual selected host, never an external descriptor supplied by a caller.
        // Its original method checks Core/Metadata/Router/Registry and the locked Artist anchor.
        IStreamCurrentAuthorityScopedPolicyProviderOriginalAnchorV2(address(this))
            .requireCurrentRouterCandidate(scope.collectionId, c.targets[12]);
    }
}
