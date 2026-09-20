// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamScopedContentRootPublication as R
} from "./IStreamScopedContentRootPublication.sol";

/// @notice Explicit ADR0054 preservation roots in the original Router history and operation17 family.
/// @dev The original Publication tuple and one-use authority remain unchanged. The binding
/// commits the complete admitted non-sanction output, independently of the live presentation.
/// Every historical profile retains its original schema, selectors and signing domains.
interface IStreamScopedPreservationPolicyContentRootPublicationV1 {
    struct Binding {
        bytes32 profileId;
        address outputManifest;
        bytes32 outputManifestCodeHash;
        address checkpoint;
        bytes32 checkpointCodeHash;
        bytes32 checkpointHash;
        bytes32 checkpointStateHash;
        address entropySourceSet;
        bytes32 entropySourceSetCodeHash;
        bytes32 inventoryHash;
        bytes32 policyChainHash;
        bytes32 outputRoot;
        bytes32 outputSchemaHash;
        bytes32 outputCanonicalizationHash;
        bytes32 leafSchemaHash;
        bytes32 rootSchemaHash;
        bytes32 rootCanonicalizationHash;
        address sourceFactory;
        bytes32 sourceFactoryCodeHash;
        bytes32 factoryDependenciesHash;
        bytes32 snapshotSchemaHash;
        bytes32 snapshotProfileHash;
        bytes32 snapshotCanonicalizationHash;
        address metadataRouter;
        bytes32 preservationOutputProfile;
    }

    event ScopedPreservationPolicyContentRootBindingPublished(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        bytes32 indexed scopeSubject,
        bytes32 indexed recordHash,
        Binding binding
    );

    function previewScopedPreservationPolicyContentRootPublication(
        R.Publication calldata publication,
        address publisher
    ) external view returns (bytes32);
    function publishScopedPreservationPolicyContentRootPublication(
        R.Publication calldata publication
    ) external returns (bytes32 recordHash);
    /// @notice A zero profile means no preservation binding is recorded for this hash.
    function scopedPreservationPolicyContentRootBinding(bytes32 recordHash)
        external
        view
        returns (Binding memory);
}
