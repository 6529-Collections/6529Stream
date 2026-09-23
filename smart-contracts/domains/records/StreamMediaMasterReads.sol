// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamMediaMasterPublicationReads.sol";
import "../../interfaces/stream/metadata/IStreamCollectionManifestReads.sol";
import "../../interfaces/stream/metadata/StreamCollectionManifestTypes.sol";
import "../../interfaces/stream/metadata/IStreamMetadataServingFacts.sol";
import "../../interfaces/stream/preservation/IStreamExternalArtifactCoverage.sol";
import "../../interfaces/stream/preservation/StreamExternalArtifactTypes.sol";

/// @notice Bounded full native manifest denominator and current original archive coverage.
library StreamMediaMasterReads {
    function definitions(StreamConservationRecordContext.Dependencies memory d, bool isWaiver)
        public view
    {
        StreamConservationRecordContext.definition(d,
            isWaiver ? StreamMediaMasterDefinitions.WAIVER_SCHEMA_ID : StreamMediaMasterDefinitions.MASTER_SCHEMA_ID,
            IStreamSchemaRegistry.DocumentKind.SCHEMA,
            isWaiver ? StreamMediaMasterDefinitions.WAIVER_SCHEMA_HASH : StreamMediaMasterDefinitions.MASTER_SCHEMA_HASH,
            isWaiver ? StreamMediaMasterDefinitions.WAIVER_SCHEMA_BYTES : StreamMediaMasterDefinitions.MASTER_SCHEMA_BYTES,
            keccak256("RAW_BYTES"), true);
        StreamConservationRecordContext.definition(d, StreamMediaMasterDefinitions.PROFILE_ID,
            IStreamSchemaRegistry.DocumentKind.CATALOG, StreamMediaMasterDefinitions.PROFILE_HASH,
            StreamMediaMasterDefinitions.PROFILE_BYTES, keccak256("RAW_BYTES"), true);
        StreamConservationRecordContext.definition(d, StreamWorkRecordDefinitions.CANON_ID,
            IStreamSchemaRegistry.DocumentKind.CANONICALIZATION, StreamWorkRecordDefinitions.CANON_HASH,
            StreamWorkRecordDefinitions.CANON_BYTES, keccak256("RAW_BYTES"), true);
    }

    function media(StreamConservationRecordContext.Dependencies memory d, uint256 collectionId, uint256 manifestCap)
        public view returns (bytes32 manifestHash, bytes32[3] memory hashes, bytes32 inventoryHash)
    {
        bytes memory raw = read(d.targets[1],
            abi.encodeCall(IStreamCollectionManifestReads.mediaManifestHash, (collectionId)),
            32, manifestCap);
        if (raw.length != 32) revert StreamMediaMasterTypes.UnsupportedMediaDenominator();
        manifestHash = abi.decode(raw, (bytes32));
        if (manifestHash == 0) revert StreamMediaMasterTypes.UnsupportedMediaDenominator();
        // This native Metadata read authenticates Core's selected live Router, its kind3
        // selection's host/codehash, and the original manifest's collection/router binding.
        raw = read(d.targets[1], abi.encodeCall(IStreamCollectionManifestReads.mediaManifest,
            (collectionId)), 16384, manifestCap);
        StreamCollectionManifestTypes.MediaManifest memory m =
            abi.decode(raw, (StreamCollectionManifestTypes.MediaManifest));
        canonical(raw, abi.encode(m));
        if (m.manifestHash != 0 || bytes(m.manifestURI).length != 0 || m.alternatesHash != 0
            || bytes(m.alternatesURI).length != 0) {
            revert StreamMediaMasterTypes.UnsupportedMediaDenominator();
        }
        // Token-derived animation URLs are outside this three shared-payload profile even
        // if a collection's native manifest itself leaves the animation slot empty.
        raw = read(d.targets[0], abi.encodeWithSignature("getSatellitePointer(bytes32)",
            keccak256("METADATA_ROUTER")), 320, d.readGas);
        if (raw.length != 320) revert StreamMediaMasterTypes.UnsupportedMediaDenominator();
        (address router, bytes32 codeHash,,,,,uint8 status,,,) = abi.decode(raw,
            (address,bytes32,bool,bytes32,bytes4,address,uint8,bytes32,bytes32,uint64));
        if (status != 1 || router.code.length == 0 || router.codehash != codeHash) {
            revert StreamMediaMasterTypes.UnsupportedMediaDenominator();
        }
        raw = read(router, abi.encodeCall(IStreamMetadataServingFacts.collectionServingSource,
            (collectionId)), 16384, manifestCap);
        IStreamMetadataServingFacts.ServingSource memory source =
            abi.decode(raw, (IStreamMetadataServingFacts.ServingSource));
        canonical(raw, abi.encode(source));
        if (bytes(source.animationBaseURI).length != 0
            || keccak256(bytes(source.imageURI)) != keccak256(bytes(m.imageURI))) {
            revert StreamMediaMasterTypes.UnsupportedMediaDenominator();
        }
        hashes[0] = slot(m.imageSourceType, m.imageURI, m.imageHash);
        hashes[1] = slot(m.animationSourceType, m.animationURI, m.animationHash);
        hashes[2] = slot(m.contentSourceType, m.contentURI, m.contentHash);
        // Full typed fields include source kinds, URIs, MIME declarations and all slot hashes.
        // This semantic digest deliberately excludes provider addresses and manifest locator hash.
        // No mediaClass is inferred from the declared MIME type.
        inventoryHash = keccak256(abi.encode(keccak256("6529STREAM_MEDIA_MASTER_INVENTORY_V1"), m));
    }

    function slot(StreamCollectionManifestTypes.PayloadSourceType source, string memory uri,
        bytes32 contentHash) private pure returns (bytes32)
    {
        if (source == StreamCollectionManifestTypes.PayloadSourceType.NONE) {
            if (bytes(uri).length != 0 || contentHash != 0) {
                revert StreamMediaMasterTypes.UnsupportedMediaDenominator();
            }
        } else if (bytes(uri).length == 0 || contentHash == 0) {
            // Legacy native manifests permit a URI without a hash. It is unavailable here.
            revert StreamMediaMasterTypes.UnsupportedMediaDenominator();
        }
        return contentHash;
    }

    function coverage(address host, bytes32 hostCodeHash,
        StreamConservationRecordContext.Dependencies memory d,
        StreamMediaMasterTypes.Selection memory s, uint256 cap)
        public view returns (bytes32)
    {
        if (s.association.artistId == 0) revert StreamMediaMasterTypes.PlatformMasterUnavailable();
        if (host.code.length == 0 || host.codehash != hostCodeHash) {
            revert StreamMediaMasterTypes.MasterCoverageUnavailable();
        }
        bytes memory raw = read(host, abi.encodeCall(IStreamExternalArtifactCoverage.core, ()), 32, d.readGas);
        if (raw.length != 32 || abi.decode(raw, (address)) != d.targets[0]) {
            revert StreamMediaMasterTypes.MasterCoverageUnavailable();
        }
        raw = read(host, abi.encodeCall(IStreamExternalArtifactCoverage.objectIdentity,
            (s.masterObjectHash)), 320, d.readGas);
        StreamExternalArtifactTypes.ObjectIdentity memory o =
            abi.decode(raw, (StreamExternalArtifactTypes.ObjectIdentity));
        canonical(raw, abi.encode(o));
        if (o.artistId != s.association.artistId || o.contentHash == 0 || o.contentHash == s.displayHash
            || o.sha256Digest == 0 || o.arweaveDataRoot == 0 || o.byteSize == 0) {
            revert StreamMediaMasterTypes.MasterCoverageUnavailable();
        }
        raw = read(host, abi.encodeCall(IStreamExternalArtifactCoverage.requireCoverage,
            (s.coverageHash, s.association.artistId, s.masterObjectHash)), 480, cap);
        StreamExternalArtifactTypes.Coverage memory c = abi.decode(raw, (StreamExternalArtifactTypes.Coverage));
        canonical(raw, abi.encode(c));
        if (c.coverageHash != s.coverageHash || c.objectHash != s.masterObjectHash
            || c.artistId != s.association.artistId || c.contentHash != o.contentHash
            || c.sha256Digest != o.sha256Digest || c.arweaveDataRoot != o.arweaveDataRoot
            || c.byteSize != o.byteSize || c.profileHash != keccak256("STREAM_EXTERNAL_ARTIFACT_COVERAGE_V1")) {
            revert StreamMediaMasterTypes.MasterCoverageUnavailable();
        }
        return keccak256(abi.encode(o, c));
    }

    function read(address target, bytes memory input, uint256 maximum, uint256 cap)
        public view returns (bytes memory raw)
    {
        if (cap == 0 || cap > type(uint64).max || gasleft() <= cap + cap / 63 + 10000) {
            revert StreamMediaMasterTypes.MasterCoverageUnavailable();
        }
        raw = new bytes(maximum);
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(input, 32), mload(input), add(raw, 32), maximum)
            size := returndatasize()
        }
        if (!ok || size > maximum) revert StreamMediaMasterTypes.MasterCoverageUnavailable();
        assembly ("memory-safe") { mstore(raw, size) }
    }

    function canonical(bytes memory raw, bytes memory encoded) public pure {
        if (raw.length != encoded.length || keccak256(raw) != keccak256(encoded)) {
            revert StreamMediaMasterTypes.MasterCoverageUnavailable();
        }
    }
}
