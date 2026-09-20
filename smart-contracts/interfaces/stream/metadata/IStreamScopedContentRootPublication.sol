// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../finality/StreamArtworkFinalityTypes.sol";

/// @notice Additive original-Router adoption of an exact current scoped STATIC snapshot.
interface IStreamScopedContentRootPublication {
    struct Publication {
        StreamFinalityScope scope;
        bytes32 expectedPredecessor;
        bytes32 snapshotRecordHash;
        uint64 snapshotRevision;
        string manifestURI;
    }

    struct Record {
        Publication publication;
        address snapshotHost;
        bytes32 snapshotCodeHash;
        bytes32 snapshotManifestHash;
        bytes32 snapshotSourceHash;
        bytes32 contentRoot;
        uint64 leafCount;
        bytes32 outputManifestHash;
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

    struct Aggregate {
        uint64 revision;
        bytes32 transitionChain;
    }
    error InvalidScopedContentRoot();
    error ScopedContentRootRead(address target, bytes4 selector);
    error ScopedContentRootDependency(address target);
    error ScopedContentRootLineage(bytes32 expected, bytes32 actual);
    error ScopedContentRootAuthority(address publisher);
    error ScopedContentRootFrozen(bytes32 subject);
    error ScopedContentRootUnknown(bytes32 recordHash);
    event ScopedContentRootPublished(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        bytes32 indexed scopeSubject,
        bytes32 indexed recordHash,
        Record record,
        Aggregate collectionAggregate
    );
    function previewScopedContentRootPublication(
        Publication calldata publication,
        address publisher
    ) external view returns (bytes32 newFamilyStateHash);
    function publishScopedContentRootPublication(Publication calldata publication)
        external
        returns (bytes32 recordHash);
    function scopedContentRootHead(StreamFinalityScope calldata scope)
        external
        view
        returns (bytes32);
    function scopedContentRootRecord(bytes32 recordHash) external view returns (Record memory);
    function scopedContentRootAggregate(uint256 collectionId)
        external
        view
        returns (Aggregate memory);
    function scopedTokenContentRoot(StreamFinalityScope calldata scope)
        external
        view
        returns (bytes32 contentRoot, uint64 leafCount, bytes32 schemaId);
}
