// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamCollectionManifestTypes as M
} from "./StreamCollectionManifestTypes.sol";

/// @dev Typed selector declarations only; the Router retains these exact public signatures.
interface IStreamMetadataRouterContentSelectors {
    function setCollectionMetadata(
        uint256 collectionId,
        string calldata name,
        string calldata description,
        string calldata image,
        string calldata animationBaseURI
    ) external;
    function setCollectionScript(uint256 collectionId, string calldata script) external;
    function setCollectionScriptManifest(uint256 collectionId, M.ScriptManifest calldata value)
        external;
    function setCollectionMediaManifest(uint256 collectionId, M.MediaManifest calldata value)
        external;
    function previewArtistScriptManifestState(uint256 collectionId, M.ScriptManifest calldata value)
        external
        view
        returns (bytes32);
    function previewArtistMediaManifestState(uint256 collectionId, M.MediaManifest calldata value)
        external
        view
        returns (bytes32);
    function selectedCollectionManifest(uint256 collectionId, uint8 kind)
        external
        view
        returns (M.Selection memory);
    function previewArtistScriptState(uint256 collectionId, string calldata script)
        external
        view
        returns (bytes32);
    function previewArtistMediaState(
        uint256 collectionId,
        string calldata image,
        string calldata animationBaseURI
    ) external view returns (bytes32);
    function artistContentFamilyState(uint256 collectionId, bytes32 familyId)
        external
        view
        returns (bool supported, bytes32 currentStateHash);
    function artistContentFreezeState(uint256 collectionId) external view returns (bytes32);
}
