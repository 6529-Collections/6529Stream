// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../interfaces/stream/finality/StreamFinalityEvidenceTypes.sol";
import "../../interfaces/stream/finality/IStreamFinalitySanctionReview.sol";

import {
    StreamFinalityNativeProviderReads as Native
} from "./StreamFinalityNativeProviderReads.sol";
import {
    StreamCurrentAuthorityPreservationPolicyProviderReadsV1 as Sources
} from "./StreamCurrentAuthorityPreservationPolicyProviderReadsV1.sol";
import {
    StreamFinalityPreservationPolicyInputManifestReadsV1 as Manifest
} from "./StreamFinalityPreservationPolicyInputManifestReadsV1.sol";
import {
    StreamFinalityPreservationPolicyInputManifestTypesV1 as Types
} from "../../interfaces/stream/finality/StreamFinalityPreservationPolicyInputManifestTypesV1.sol";
import {
    StreamCurrentAuthorityPreservationPolicySanctionReviewV1 as Review
} from "./StreamCurrentAuthorityPreservationPolicySanctionReviewV1.sol";
import "./StreamFinalityRouteReads.sol";
import "../../interfaces/stream/finality/IStreamFinalityRouterEvidenceBinding.sol";

/// @notice Fixed same-host COLLECTION V2 operations for the actual selected combined provider.
/// @dev Constructor-owned Config is supplied by the host. Prepared operations authenticate the
/// original Registry first. Current sources, original anchors, exact manifest and Artist review
/// remain independent joins. No persistent ready cache or caller-selected source configuration.
library StreamCurrentAuthorityPreservationPolicyProviderOperationsV1 {
    struct Config {
        Native.Config source;
        address outputManifest;
        bytes32 outputManifestCodeHash;
    }
    error PolicyProviderRegistryOnly();

    function manifest(Config memory configured, StreamFinalityScope memory scope)
        public
        view
        returns (bytes memory)
    {
        Native.Config memory c = configured.source;
        _candidate(configured, scope);
        Types.Statement memory s = Sources.statement(
            c,
            scope,
            Native.currentComponents(c, scope),
            configured.outputManifest,
            configured.outputManifestCodeHash
        );
        return Manifest.encode(
            Sources.manifestDependencies(c), s, keccak256("6529STREAM_TOKEN_PRESERVATION_FAMILY_V2")
        );
    }

    function inputs(Config memory configured, StreamFinalityScope memory scope, bytes32 hash)
        public
        view
        returns (StreamFinalityScopeInputs memory, bytes32 schema, bytes32 canon)
    {
        Native.Config memory c = configured.source;
        _candidate(configured, scope);
        Types.Statement memory s = Sources.statement(
            c,
            scope,
            Native.currentComponents(c, scope),
            configured.outputManifest,
            configured.outputManifestCodeHash
        );
        (schema, canon) = Manifest.requireCurrent(
            Sources.manifestDependencies(c),
            s,
            hash,
            keccak256("6529STREAM_TOKEN_PRESERVATION_FAMILY_V2")
        );
        return (s.inputs, schema, canon);
    }

    function review(Config memory configured, StreamFinalityScope memory scope, bytes32 hash)
        public
        view
        returns (IStreamFinalitySanctionReview.ReviewFacts memory)
    {
        Native.Config memory c = configured.source;
        _candidate(configured, scope);
        Types.Statement memory s = Sources.statement(
            c,
            scope,
            Native.currentComponents(c, scope),
            configured.outputManifest,
            configured.outputManifestCodeHash
        );
        Manifest.requireCurrent(
            Sources.manifestDependencies(c),
            s,
            hash,
            keccak256("6529STREAM_TOKEN_PRESERVATION_FAMILY_V2")
        );
        return Review.review(c, s);
    }

    function prepared(
        Config memory configured,
        StreamFinalityScope memory scope,
        bytes32 hash,
        StreamFinalityComponentExpectation[] calldata components,
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
        Native.Config memory c = configured.source;
        if (
            msg.sender != c.targets[12] || msg.sender.code.length == 0
                || msg.sender.codehash != c.codeHashes[12]
        ) revert PolicyProviderRegistryOnly();
        _candidate(configured, scope);
        if (!StreamFinalityRouteReads.verifyIfSupported(
                c.targets[13], scope, components, components.length == 10, c.sourceGas
            )) revert Sources.NativeProviderSource();
        Types.Statement memory s = Sources.statement(
            c,
            scope,
            Native.independentComponents(components),
            configured.outputManifest,
            configured.outputManifestCodeHash
        );
        (schema, canon) = Manifest.requireCurrent(
            Sources.manifestDependencies(c),
            s,
            hash,
            keccak256("6529STREAM_TOKEN_PRESERVATION_FAMILY_V2")
        );
        inputs_ = s.inputs;
        if (withReview) review_ = Review.review(c, s);
    }

    function _candidate(Config memory configured, StreamFinalityScope memory scope) private view {
        Native.Config memory c = configured.source;
        Sources.requirePins(c, configured.outputManifest, configured.outputManifestCodeHash);
        if (
            scope.scopeType != StreamFinalityScopeType.COLLECTION || scope.collectionId == 0
                || scope.tokenId != 0 || scope.scopeId != 0
        ) revert Sources.NativeProviderScope();
        // Exact original selected Router/Metadata/Registry and durable Artist anchor checks.
        IStreamFinalityRouterEvidenceBinding(address(this))
            .requireCurrentRouterCandidate(scope.collectionId, c.targets[12]);
    }
}
