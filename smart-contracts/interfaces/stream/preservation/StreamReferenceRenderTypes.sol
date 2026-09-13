// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamExternalArtifactTypes as E } from "./StreamExternalArtifactTypes.sol";
import "../metadata/IStreamMetadataServingFacts.sol";
import "../finality/StreamFinalitySnapshotTypes.sol";

/// @notice Native static reference-render publication; declarations and authenticated facts differ.
library StreamReferenceRenderTypes {
    struct Dependencies {
        // Core, Metadata, SchemaRegistry, Store, Router, Snapshots, external object coverage.
        address[7] targets;
        bytes32[7] codeHashes;
        uint256 chainId;
        // One fixed authoritative registered renderer declaration, never caller-chosen per record.
        bytes32 rendererCatalogId;
        bytes32 rendererCatalogHash;
        uint32 rendererCatalogBytes;
        uint256 readGas;
        uint256 sourceGas;
        uint256 snapshotGas;
        uint256 archiveGas;
    }

    struct RendererDeclaration {
        address renderer;
        bytes32 rendererCodeHash;
        bytes32 routerVersion;
        bytes32 routerManifestHash;
        bytes32 presentationProfile;
        bytes32 rendererContext;
        bytes32 dependencyReadSet;
        bytes32 rendererClass;
    }

    struct PackageFile {
        string path;
        uint64 byteSize;
        bytes32 sha256Digest;
    }

    /// @dev Scope-wide STATIC artwork and BYTE_EXACT are explicit curatorial declarations.
    ///      Renderer STATIC is separately authenticated from the one fixed registered catalog.
    struct Environment {
        bytes32 objectHash;
        bytes32 coverageHash;
        bytes32 manifestHash;
        uint32 manifestBytes;
        string engineName;
        string engineVersion;
        bytes32 engineExecutableSha256;
        string toolchainName;
        string toolchainVersion;
        bytes32 toolchainSha256;
        string engineExecutablePath;
        string toolchainPath;
        PackageFile[] packageFiles;
        PackageFile[] platformPrerequisites;

        string operatingSystem;
        string operatingSystemVersion;
        string architecture;
        uint16 viewportWidth;
        uint16 viewportHeight;
        uint8 devicePixelRatio;
        string colorSpace;
        bool softwareRasterization;
        bytes32 captureProfile;
        // This native proprietary-browser profile has an explicit undetermined license basis.
        string licenseNote;
    }

    struct Capture {
        uint256 tokenId;
        uint256 collectionSerial;
        bytes32 metadataJSONHash;
        bytes32 htmlHash;
        uint32 htmlBytes;
        bytes animationHTML;
        bytes32 objectHash;
        bytes32 coverageHash;
        bytes32 sourceSha256;
        bytes32[2] repeatCaptureSha256;
        bytes32 environmentManifestHash;
        uint64 capturedAt;
    }

    struct Publication {
        uint256 collectionId;
        bytes32 referenceId;
        bytes32 expectedHead;
        uint64 expectedRevision;
        bytes32 snapshotRecordHash;
        uint64 snapshotRevision;
        bytes32 expectedSourcesHash;
        // This bounded profile admits exactly the required first/last sample, one if identical.
        Capture[] captures;
        Environment environment;
        string manifestURI;
        uint64 effectiveAt;
        bytes32 reasonHash;
    }

    struct SampleFacts {
        uint256 tokenId;
        uint256 collectionSerial;
        address originalCoordinator;
        bytes32 seed;
        bytes32 tokenDataHash;
        uint32 tokenDataBytes;
        bytes32 metadataJSONHash;
        bytes32 htmlHash;
        uint32 htmlBytes;
        E.Coverage captureCoverage;
    }

    /// @dev Immutable original snapshot facts only; later lock observations are not content inputs.
    struct SnapshotBinding {
        bytes32 recordHash;
        bytes32 manifestHash;
        bytes32 sourceHash;
        bytes32 inventoryPlan;
        uint64 revision;
        bytes32 schemaHash;
        bytes32 profileHash;
        bytes32 canonicalizationHash;
    }

    struct SourceFacts {
        bytes32 subject;
        uint256 mintedEver;
        bytes32 artistId;
        SnapshotBinding snapshot;
        RendererDeclaration renderer;
        E.Coverage environmentCoverage;
        SampleFacts[] samples;
    }

    struct Receipt {
        bytes32 recordHash;
        bytes32 recordChainHash;
        uint256 collectionId;
        bytes32 referenceId;
        bytes32 predecessor;
        uint64 revision;
        bytes32 payloadHash;
        uint32 payloadBytes;
        bytes32 sourcesHash;
        bytes32 snapshotRecordHash;
        uint64 snapshotRevision;
        address recorder;
        uint8 authorizationClass;
        uint64 grantRevision;
        uint64 effectiveAt;
        uint64 recordedAt;
        bytes32 reasonHash;
        bytes32 schemaHash;
        bytes32 profileHash;
        bytes32 canonicalizationHash;
    }

    struct Lock {
        bytes32 recordHash;
        uint64 revision;
        bytes32 actionId;
        uint64 lockedAt;
    }

    error InvalidReferenceRender();
    error ReferenceDependency(address target);
    error ReferenceAuthority(address actor);
    error ReferenceLineage(bytes32 expected, bytes32 actual);
    error ReferenceLocked();
}
