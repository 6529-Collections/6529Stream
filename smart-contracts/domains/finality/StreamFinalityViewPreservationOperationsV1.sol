// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../interfaces/stream/finality/StreamFinalityEvidenceTypes.sol";
import "../../interfaces/stream/finality/IStreamFinalitySanctionReview.sol";

import {
    StreamFinalityNativeProviderReads as Native
} from "./StreamFinalityNativeProviderReads.sol";
import {
    StreamFinalityViewPreservationProviderReadsV1 as Sources
} from "./StreamFinalityViewPreservationProviderReadsV1.sol";
import {
    StreamFinalityViewPreservationInputReadsV1 as Manifest
} from "./StreamFinalityViewPreservationInputReadsV1.sol";
import {
    StreamFinalityViewPreservationInputTypesV1 as Types
} from "../../interfaces/stream/finality/StreamFinalityViewPreservationInputTypesV1.sol";
import {
    StreamFinalityViewPreservationSanctionReviewV1 as Review
} from "./StreamFinalityViewPreservationSanctionReviewV1.sol";
import "./StreamFinalityRouteReads.sol";
import "../../interfaces/stream/finality/IStreamFinalityRouterEvidenceBinding.sol";

import {
    StreamFinalityViewPreservationConfigurationV1 as Configuration
} from "./StreamFinalityViewPreservationConfigurationV1.sol";

/// @notice Fixed same-host VIEW preservation operations for the actual selected combined provider.
/// @dev Constructor-owned Config is supplied by the host. Prepared operations authenticate the
/// original Registry first. Current sources, original anchors, exact manifest and Artist review
/// remain independent joins. No persistent ready cache or caller-selected source configuration.
library StreamFinalityViewPreservationOperationsV1 {
    error PolicyProviderRegistryOnly();

    function manifest(Native.Config memory c, StreamFinalityScope memory scope)
        public
        view
        returns (bytes memory)
    {
        _candidate(c, scope);
        Types.Statement memory s = Sources.statement(c, scope, Sources.currentComponents(c, scope));
        return Manifest.encode(Sources.manifestDependencies(c), s);
    }

    function inputs(Native.Config memory c, StreamFinalityScope memory scope, bytes32 hash)
        public
        view
        returns (StreamFinalityScopeInputs memory, bytes32 schema, bytes32 canon)
    {
        _candidate(c, scope);
        Types.Statement memory s = Sources.statement(c, scope, Sources.currentComponents(c, scope));
        (schema, canon) = Manifest.requireCurrent(Sources.manifestDependencies(c), s, hash);
        return (s.inputs, schema, canon);
    }

    function review(Native.Config memory c, StreamFinalityScope memory scope, bytes32 hash)
        public
        view
        returns (IStreamFinalitySanctionReview.ReviewFacts memory)
    {
        _candidate(c, scope);
        Types.Statement memory s = Sources.statement(c, scope, Sources.currentComponents(c, scope));
        Manifest.requireCurrent(Sources.manifestDependencies(c), s, hash);
        return Review.review(c, s);
    }

    function prepared(
        Native.Config memory c,
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
        if (
            msg.sender != c.targets[12] || msg.sender.code.length == 0
                || msg.sender.codehash != c.codeHashes[12]
        ) revert PolicyProviderRegistryOnly();
        _candidate(c, scope);
        if (!StreamFinalityRouteReads.verifyIfSupported(
                c.targets[13], scope, components, components.length == 10, c.sourceGas
            )) revert Sources.InvalidViewFinalityInputs();
        Types.Statement memory s =
            Sources.statement(c, scope, Native.independentComponents(components));
        (schema, canon) = Manifest.requireCurrent(Sources.manifestDependencies(c), s, hash);
        inputs_ = s.inputs;
        if (withReview) review_ = Review.review(c, s);
    }

    function _candidate(Native.Config memory c, StreamFinalityScope memory scope) private view {
        Configuration.requireScope(c, scope);
        Configuration.resolve(c);
        // Exact original selected Router/Metadata/Registry and durable Artist anchor checks.
        IStreamFinalityRouterEvidenceBinding(address(this))
            .requireCurrentRouterCandidate(scope.collectionId, c.targets[12]);
    }
}
