// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { IStreamContentRootPublication as R } from "./IStreamContentRootPublication.sol";

/// @notice Explicit ADR0054 preservation roots in the original Router history and operation17 family.
/// @dev The original Publication tuple and one-use authority remain unchanged. The binding
/// commits the complete admitted non-sanction output, independently of the live presentation.
/// Every historical profile retains its original schema, selectors and signing domains.
interface IStreamPreservationPolicyContentRootPublicationV1 {
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
        address metadataRouter;
        bytes32 preservationOutputProfile;
    }

    event PreservationPolicyContentRootBindingPublished(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        bytes32 indexed recordHash,
        Binding binding
    );

    /// @notice Exact next CONTENT_ROOT family hash, including the original scoped aggregate.
    function previewPreservationPolicyContentRootPublication(
        R.Publication calldata publication,
        address publisher
    ) external view returns (bytes32);
    function publishVerifiedPreservationPolicyContentRoot(R.Publication calldata publication)
        external
        returns (bytes32 recordHash);
    /// @notice A zero profile means no preservation binding is recorded for this hash.
    function preservationPolicyContentRootBinding(bytes32 recordHash)
        external
        view
        returns (Binding memory);
}
