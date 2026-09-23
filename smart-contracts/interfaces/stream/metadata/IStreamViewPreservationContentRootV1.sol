// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamScopedContentRootPublication as R
} from "./IStreamScopedContentRootPublication.sol";

/// @notice VIEW preservation roots in the original Router CONTENT_ROOT history and op17 book.
/// @dev RENDERER_CONFIG adoption is a prerequisite, never this distinct content authorization.
interface IStreamViewPreservationContentRootV1 {
    struct Binding {
        bytes32 profileId;
        bytes32 outputProfile;
        bytes32 adoptionRecord;
        bytes32 adoptionProfile;
        bytes32 membershipHash;
        bytes32 policyChainHash;
        address checkpoint;
        bytes32 checkpointCodeHash;
        bytes32 checkpointRecord;
        bytes32 checkpointStateHash;
        address outputManifest;
        bytes32 outputManifestCodeHash;
        bytes32 outputManifestRecord;
        bytes32 manifestIndexHash;
        bytes32 partChain;
        address preservationRenderer;
        bytes32 preservationRendererCodeHash;
        bytes32 preservationConfigurationHash;
        address liveRenderer;
        bytes32 liveRendererCodeHash;
        address preservationAttribution;
        bytes32 preservationAttributionCodeHash;
        bytes32 leafSchemaHash;
        bytes32 rootSchemaHash;
        bytes32 rootCanonicalizationHash;
        bytes32 snapshotSchemaHash;
        bytes32 snapshotProfileHash;
        bytes32 snapshotCanonicalizationHash;
    }
    event ViewPreservationContentRootBindingPublished(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        bytes32 indexed scopeSubject,
        bytes32 indexed recordHash,
        Binding binding
    );
    function previewViewPreservationContentRoot(
        R.Publication calldata publication,
        address publisher
    ) external view returns (bytes32 prospectiveContentFamilyState);
    function publishViewPreservationContentRoot(R.Publication calldata publication)
        external
        returns (bytes32 recordHash);
    /// @notice Absent binding returns zero profile; new typed readers require this closed profile.
    function viewPreservationContentRootBinding(bytes32 recordHash)
        external
        view
        returns (Binding memory);
}
