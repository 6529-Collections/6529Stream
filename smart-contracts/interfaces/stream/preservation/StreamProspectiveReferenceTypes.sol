// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamConservationFloorTypes as F } from "../metadata/StreamConservationFloorTypes.sol";
import { StreamCollectionManifestTypes as M } from "../metadata/StreamCollectionManifestTypes.sol";
import { IStreamMetadataServingFacts as V } from "../metadata/IStreamMetadataServingFacts.sol";
import { StreamReferenceRenderTypes as R } from "./StreamReferenceRenderTypes.sol";
import { StreamExternalArtifactTypes as E } from "./StreamExternalArtifactTypes.sol";

/// @notice Pre-sale simulation observations; never token, finalized entropy or finality evidence.
library StreamProspectiveReferenceTypes {
    struct Dependencies {
        // Stable Core, permanent Floor, Schema, Store, archive, fixed simulation encoder.
        address[6] targets;
        bytes32[6] codeHashes;
        uint256 chainId;
        bytes32 rendererCatalogId;
        bytes32 rendererCatalogHash;
        uint32 rendererCatalogBytes;
        uint256 readGas;
        uint256 sourceGas;
        uint256 archiveGas;
    }

    struct Vector {
        string name;
        bytes32 seed;
        bytes input;
    }

    struct Capture {
        Vector vector;
        bytes animationHTML;
        bytes32 objectHash;
        bytes32 coverageHash;
        bytes32[2] repeatCaptureSha256;
        uint64 capturedAt;
        // Canonical abi.encode(Execution), retained verbatim; an attributed local observation.
        bytes execution;
    }

    struct Execution {
        bytes32 profile;
        bytes32 sourceHash;
        bytes32 vectorHash;
        bytes32 environmentManifestHash;
        bytes32 htmlSha256;
        bytes32[2] pngSha256;
        uint64 observedAt;
        uint32 exitCode;
    }

    struct Source {
        uint64 floorSourceId;
        bytes32 floorSourceSetHash;
        F.Source provider;
        F.ReleaseContext release;
        address router;
        bytes32 routerCodeHash;
        bytes32 artistId;
        V.LiveArtistStatus artist;
        V.ServingFacts serving;
        V.ServingSource display;
        R.RendererDeclaration renderer;
        bytes32 scriptManifestHash;
        M.ScriptManifest scriptManifest;
        bytes32 mediaManifestHash;
        M.MediaManifest mediaManifest;
        bytes script;
    }

    struct Publication {
        uint256 collectionId;
        bytes32 referenceId;
        bytes32 expectedHead;
        uint64 expectedRevision;
        bytes32 expectedSourceHash;
        Capture[] captures;
        R.Environment environment;
        string manifestURI;
        uint64 effectiveAt;
        bytes32 reasonHash;
    }

    struct Evidence {
        bytes32 sourceHash;
        E.Coverage environmentCoverage;
        E.Coverage[] captureCoverage;
    }

    struct Receipt {
        bytes32 recordHash;
        bytes32 chainHash;
        uint256 collectionId;
        bytes32 referenceId;
        bytes32 predecessor;
        uint64 revision;
        bytes32 subject;
        bytes32 membershipHash;
        bytes32 sourceHash;
        bytes32 payloadHash;
        uint32 payloadBytes;
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
    error InvalidProspectiveReference();
    error ProspectiveDependency(address target);
    error ProspectiveAuthority(address actor);
    error ProspectiveLineage(bytes32 expected, bytes32 actual);
}
