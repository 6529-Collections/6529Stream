// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { IStreamContentRootPublication as R } from "./IStreamContentRootPublication.sol";

/// @notice Distinct V2 root adoption through the original Router and original Artist operation17.
/// @dev Publication uses the original four-field tuple. The manifest is exclusively a verified
/// V2 policy/output manifest. Existing canonical head, one-use consent and evolution state apply.
interface IStreamPolicyContentRootPublicationV2 {
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
    }

    event PolicyContentRootBindingPublished(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        bytes32 indexed recordHash,
        Binding binding
    );

    /// @notice Exact next CONTENT_ROOT family hash, including the original scoped aggregate.
    function previewPolicyContentRootPublication(
        R.Publication calldata publication,
        address publisher
    ) external view returns (bytes32);
    function publishVerifiedPolicyContentRoot(R.Publication calldata publication)
        external
        returns (bytes32 recordHash);
    /// @notice Literal-zero profile means the canonical record belongs to the original V1 path.
    function policyContentRootBinding(bytes32 recordHash) external view returns (Binding memory);
}
