// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Artist-approved adoption of an actually verified collection content manifest.
interface IStreamContentRootPublication {
    struct Publication {
        uint256 collectionId;
        bytes32 expectedPredecessor;
        bytes32 verifiedManifestRecordHash;
        string manifestURI;
    }

    struct Record {
        Publication publication;
        bytes32 contentRoot;
        uint64 leafCount;
        bytes32 manifestHash;
        bytes32 artistId;
        uint64 bindingGeneration;
        bytes32 bindingHash;
        address publisher;
        uint8 authorizationClass;
        uint64 grantRevision;
        bytes32 routeHash;
        bytes32 stateHash;
        bytes32 artistConsent;
        uint64 publishedAt;
    }

    error InvalidContentRootPublication();
    error ContentRootReadFailed(address target, bytes4 selector);
    error ContentRootComponentChanged(address target);
    error ContentRootAuthorityRequired(address caller);
    error ContentRootLineageChanged(bytes32 expected, bytes32 actual);
    error ContentRootAlreadyFinalized(uint256 collectionId);
    error ContentRootRecordUnknown(bytes32 recordHash);

    event TokenContentRootPublished(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        bytes32 indexed scopeSubject,
        bytes32 indexed recordHash,
        Record record
    );

    /// @notice Computes the exact new CONTENT_ROOT family state for operation17 approval.
    /// @dev The nominated publisher must have an active metadata/global grant.
    function previewContentRootPublication(Publication calldata publication, address publisher)
        external
        view
        returns (bytes32 newStateHash);
    function publishVerifiedTokenContentRoot(Publication calldata publication)
        external
        returns (bytes32 recordHash);
    function tokenContentRoot(uint256 collectionId, bytes32 scopeSubject)
        external
        view
        returns (bytes32 contentRoot, uint64 leafCount, bytes32 schemaId);
    function contentRootRecord(bytes32 recordHash) external view returns (Record memory);
    function collectionContentRootHead(uint256 collectionId) external view returns (bytes32);
}
