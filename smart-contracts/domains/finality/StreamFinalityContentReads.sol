// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/finality/StreamFinalityContentTypes.sol";
import "../../interfaces/stream/finality/IStreamContentRootEvidenceBinding.sol";
import "../../interfaces/stream/finality/IStreamFinalityDeploymentBindings.sol";
import "../../interfaces/stream/finality/IStreamFinalityEvidenceProvider.sol";
import "../../interfaces/stream/finality/IStreamContentLeafManifest.sol";
import "../../interfaces/stream/finality/IStreamOnchainContentCheckpoint.sol";
import "../../interfaces/stream/metadata/IStreamContentRootPublication.sol";
import "../../interfaces/stream/metadata/IStreamCollectionMetadataV1.sol";
import "../../interfaces/stream/metadata/IStreamSchemaRegistry.sol";
import "../../interfaces/stream/core/IStreamCorePointers.sol";
import "../../interfaces/stream/artist/IStreamArtistAttributionState.sol";
import "../../interfaces/stream/artist/IStreamArtistFinalityBinding.sol";
import "../../interfaces/stream/preservation/IStreamFinalityArtifactCoverage.sol";
import "../metadata/StreamMetadataSubjects.sol";
import "./StreamContentRootSchemas.sol";

/// @notice Joins a current published root to its actual complete checkpoint and preserved leaf bytes.
/// @dev The consuming provider must construct Dependencies from its immutable deployment bindings,
///      never accept them from a caller. This library grants no publication or finality authority.
library StreamFinalityContentReads {
    /// @dev Same order as CONTENT_ROOT_ROUTE_V1: Core, artist, Router, Finality, provider,
    ///      generic metadata, schemas, leaf verifier, checkpoint and archival coverage.
    struct Dependencies {
        address[10] targets;
        bytes32[10] codeHashes;
        uint256 chainId;
        uint256 readGas;
    }

    struct SelectedPointer {
        address target;
        bytes32 codeHash;
        bool frozen;
        bytes32 moduleType;
        bytes4 interfaceId;
        address registry;
        uint8 registryStatus;
        bytes32 moduleManifestHash;
        bytes32 deploymentManifestHash;
        uint64 revision;
    }

    error ContentEvidenceConfiguration();
    error ContentEvidenceDependency(address target);
    error ContentEvidenceRead(address target, bytes4 selector);
    error ContentEvidenceMissing(uint256 collectionId);
    error ContentEvidenceMismatch(bytes32 recordHash);
    error ContentEvidenceArtistChanged(uint256 collectionId);
    error ContentEvidenceSchema(bytes32 schemaId);

    function requireCurrentCollection(Dependencies memory d, uint256 collectionId)
        public
        view
        returns (StreamFinalityContentEvidence memory e)
    {
        if (collectionId == 0) revert ContentEvidenceMissing(collectionId);
        _bindings(d);
        e.rootRecordHash = bytes32(
            _word(
                d,
                2,
                abi.encodeCall(
                    IStreamContentRootPublication.collectionContentRootHead, (collectionId)
                )
            )
        );
        if (e.rootRecordHash == 0) revert ContentEvidenceMissing(collectionId);
        IStreamContentRootPublication.Record memory r = abi.decode(
            _read(
                d,
                2,
                abi.encodeCall(IStreamContentRootPublication.contentRootRecord, (e.rootRecordHash)),
                4096,
                false
            ),
            (IStreamContentRootPublication.Record)
        );
        _record(d, collectionId, e.rootRecordHash, r);
        _artist(d, collectionId, r);
        _schemas(d);
        IStreamContentLeafManifest.Manifest memory m = abi.decode(
            _read(
                d,
                7,
                abi.encodeCall(
                    IStreamContentLeafManifest.requireCurrentManifest,
                    (r.publication.verifiedManifestRecordHash, r.artistId)
                ),
                288,
                true
            ),
            (IStreamContentLeafManifest.Manifest)
        );
        IStreamOnchainContentCheckpoint.Plan memory p = abi.decode(
            _read(
                d,
                8,
                abi.encodeCall(
                    IStreamOnchainContentCheckpoint.requireCurrentCheckpoint, (m.checkpointHash)
                ),
                224,
                true
            ),
            (IStreamOnchainContentCheckpoint.Plan)
        );
        if (
            m.collectionId != collectionId || m.artistId != r.artistId
                || m.contentRoot != r.contentRoot || m.tokenCount != r.leafCount
                || m.manifestHash != r.manifestHash || m.checkpointHash == 0 || m.artifactHash == 0
                || m.coverageHash == 0 || m.byteLength != 320 + uint256(m.tokenCount) * 192
                || p.collectionId != collectionId || p.tokenCount != r.leafCount
                || p.nextIndex != p.tokenCount || p.contentRoot != r.contentRoot
                || p.inventoryHash == 0 || p.servingStateHash == 0 || p.leafChainHash == 0
        ) revert ContentEvidenceMismatch(e.rootRecordHash);
        e.verifiedManifestRecordHash = r.publication.verifiedManifestRecordHash;
        e.checkpointHash = m.checkpointHash;
        e.leafArtifactHash = m.artifactHash;
        e.leafCoverageHash = m.coverageHash;
        e.artistId = r.artistId;
        e.bindingHash = r.bindingHash;
        e.inventoryHash = p.inventoryHash;
        e.servingStateHash = p.servingStateHash;
        e.contentRoot = r.contentRoot;
        e.manifestHash = r.manifestHash;
        e.bindingGeneration = r.bindingGeneration;
        e.leafCount = r.leafCount;
    }

    function _record(
        Dependencies memory d,
        uint256 cid,
        bytes32 hash,
        IStreamContentRootPublication.Record memory r
    ) private view {
        if (
            r.publication.collectionId != cid || r.publication.verifiedManifestRecordHash == 0
                || r.publisher == address(0)
                || (r.authorizationClass != 7 && r.authorizationClass != 8) || r.grantRevision == 0
                || r.artistConsent == 0 || r.publishedAt == 0 || r.leafCount == 0
                || r.contentRoot == 0 || r.manifestHash == 0
                || bytes(r.publication.manifestURI).length == 0
                || bytes(r.publication.manifestURI).length > 2048
                || r.routeHash
                    != keccak256(
                        abi.encode(
                            keccak256("6529STREAM_CONTENT_ROOT_ROUTE_V1"),
                            d.chainId,
                            [d.targets[0], d.targets[1]],
                            d.targets,
                            d.codeHashes
                        )
                    )
                || hash
                    != keccak256(
                        abi.encode(
                            keccak256("6529STREAM_CONTENT_ROOT_RECORD_V1"),
                            d.chainId,
                            d.targets[2],
                            r
                        )
                    )
        ) revert ContentEvidenceMismatch(hash);
        bytes32 subject = StreamMetadataSubjects.scopeSubject(
            d.chainId,
            d.targets[0],
            StreamFinalityScope(StreamFinalityScopeType.COLLECTION, cid, 0, 0)
        );
        (bytes32 root, uint64 count, bytes32 schema) = abi.decode(
            _read(
                d,
                2,
                abi.encodeCall(IStreamContentRootPublication.tokenContentRoot, (cid, subject)),
                96,
                true
            ),
            (bytes32, uint64, bytes32)
        );
        if (
            root != r.contentRoot || count != r.leafCount
                || schema != StreamContentRootSchemas.LEAF_SCHEMA
        ) {
            revert ContentEvidenceMismatch(hash);
        }
        bytes32 stateHash = r.stateHash;
        r.stateHash = 0;
        r.artistConsent = 0;
        r.publishedAt = 0;
        if (
            stateHash
                != keccak256(
                    abi.encode(
                        keccak256("6529STREAM_CONTENT_ROOT_STATE_V1"), d.chainId, d.targets[2], r
                    )
                )
        ) revert ContentEvidenceMismatch(hash);
    }

    function _artist(
        Dependencies memory d,
        uint256 cid,
        IStreamContentRootPublication.Record memory r
    ) private view {
        (uint8 state, uint64 generation, bytes32 id,, bytes32 binding) = abi.decode(
            _read(
                d,
                1,
                abi.encodeCall(IStreamArtistAttributionState.collectionArtistState, (cid)),
                160,
                true
            ),
            (uint8, uint64, bytes32, uint8, bytes32)
        );
        if (
            (state != 2 && state != 3) || id == 0 || generation == 0 || binding == 0
                || id != r.artistId || generation != r.bindingGeneration || binding != r.bindingHash
        ) {
            revert ContentEvidenceArtistChanged(cid);
        }
    }

    function _bindings(Dependencies memory d) private view {
        if (d.chainId != block.chainid || d.readGas < 50_000 || d.readGas > type(uint256).max / 64)
        {
            revert ContentEvidenceConfiguration();
        }
        for (uint256 i; i < 10; ++i) {
            if (d.targets[i].code.length == 0 || d.targets[i].codehash != d.codeHashes[i]) {
                revert ContentEvidenceDependency(d.targets[i]);
            }
        }
        _selected(d, keccak256("METADATA_ROUTER"), 2);
        _selected(d, keccak256("ARTWORK_FINALITY_REGISTRY"), 3);
        _selected(d, keccak256("COLLECTION_METADATA"), 5);
        _address(d, 1, IStreamArtistFinalityBinding.finalityRegistry.selector, 3);
        _hash(d, 1, IStreamArtistFinalityBinding.finalityRegistryCodeHash.selector, 3);
        _address(d, 3, IStreamFinalityDeploymentBindings.coreReads.selector, 0);
        _address(d, 3, IStreamFinalityDeploymentBindings.sanctionReads.selector, 1);
        _address(d, 3, IStreamFinalityDeploymentBindings.scopeEvidenceProvider.selector, 4);
        _hash(d, 3, IStreamFinalityDeploymentBindings.scopeEvidenceProviderCodeHash.selector, 4);
        _address(d, 3, IStreamFinalityDeploymentBindings.metadataReads.selector, 5);
        _address(d, 3, IStreamFinalityDeploymentBindings.artifactCoverage.selector, 9);
        _address(d, 4, IStreamFinalityEvidenceProvider.metadataHost.selector, 5);
        _hash(d, 4, IStreamContentRootEvidenceBinding.metadataHostCodeHash.selector, 5);
        _address(d, 4, IStreamContentRootEvidenceBinding.schemaRegistry.selector, 6);
        _hash(d, 4, IStreamContentRootEvidenceBinding.schemaRegistryCodeHash.selector, 6);
        _address(d, 4, IStreamContentRootEvidenceBinding.contentLeafManifest.selector, 7);
        _hash(d, 4, IStreamContentRootEvidenceBinding.contentLeafManifestCodeHash.selector, 7);
        _address(d, 5, IStreamCollectionMetadataV1.core.selector, 0);
        _address(d, 5, IStreamCollectionMetadataV1.schemaRegistry.selector, 6);
        _address(d, 7, IStreamContentLeafManifest.core.selector, 0);
        _address(d, 7, IStreamContentLeafManifest.contentCheckpoint.selector, 8);
        _address(d, 7, IStreamContentLeafManifest.artifactCoverage.selector, 9);
        _address(d, 8, IStreamOnchainContentCheckpoint.core.selector, 0);
        _address(d, 8, IStreamOnchainContentCheckpoint.metadataRouter.selector, 2);
        _address(d, 9, IStreamFinalityArtifactCoverage.schemaRegistry.selector, 6);
    }

    function _schemas(Dependencies memory d) private view {
        bytes32[4] memory ids = [
            StreamContentRootSchemas.LEAF_SCHEMA,
            StreamContentRootSchemas.LEAF_CANON,
            StreamContentRootSchemas.ROOT_SCHEMA,
            StreamContentRootSchemas.ROOT_CANON
        ];
        for (uint256 i; i < 4; ++i) {
            IStreamSchemaRegistry.DocumentView memory s = abi.decode(
                _read(d, 6, abi.encodeCall(IStreamSchemaRegistry.document, (ids[i])), 8192, false),
                (IStreamSchemaRegistry.DocumentView)
            );
            if (
                !s.exists || s.status != IStreamSchemaRegistry.DocumentStatus.ACTIVE
                    || uint8(s.specification.kind) != i % 2
                    || keccak256(bytes(s.specification.name)) != ids[i]
                    || s.specification.canonicalizationId != keccak256("RAW_BYTES")
                    || s.specification.contentHash
                        != StreamContentRootSchemas.definitionHash(ids[i])
            ) {
                revert ContentEvidenceSchema(ids[i]);
            }
        }
    }

    function _selected(Dependencies memory d, bytes32 kind, uint256 index) private view {
        SelectedPointer memory p = abi.decode(
            _read(d, 0, abi.encodeCall(IStreamCorePointers.getSatellitePointer, (kind)), 320, true),
            (SelectedPointer)
        );
        if (
            p.target != d.targets[index] || p.codeHash != d.codeHashes[index]
                || p.moduleType != kind || p.interfaceId == bytes4(0) || p.registry == address(0)
                || p.registryStatus != 1 || p.moduleManifestHash == 0
                || p.deploymentManifestHash == 0 || p.revision == 0
        ) revert ContentEvidenceDependency(d.targets[index]);
    }

    function _address(Dependencies memory d, uint256 index, bytes4 selector, uint256 expected)
        private
        view
    {
        if (
            _word(d, index, abi.encodeWithSelector(selector))
                != uint256(uint160(d.targets[expected]))
        ) {
            revert ContentEvidenceDependency(d.targets[index]);
        }
    }

    function _hash(Dependencies memory d, uint256 index, bytes4 selector, uint256 expected)
        private
        view
    {
        if (bytes32(_word(d, index, abi.encodeWithSelector(selector))) != d.codeHashes[expected]) {
            revert ContentEvidenceDependency(d.targets[index]);
        }
    }

    function _word(Dependencies memory d, uint256 index, bytes memory input)
        private
        view
        returns (uint256)
    {
        return abi.decode(_read(d, index, input, 32, true), (uint256));
    }

    function _read(
        Dependencies memory d,
        uint256 index,
        bytes memory input,
        uint256 maximum,
        bool exact
    ) private view returns (bytes memory out) {
        address target = d.targets[index];
        uint256 cap = d.readGas;
        if (gasleft() <= cap + cap / 63 + 100_000) {
            revert ContentEvidenceRead(target, bytes4(input));
        }
        out = new bytes(maximum);
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(input, 32), mload(input), add(out, 32), maximum)
            size := returndatasize()
        }
        if (!ok || size > maximum || (exact && size != maximum)) {
            revert ContentEvidenceRead(target, bytes4(input));
        }
        assembly ("memory-safe") { mstore(out, size) }
    }
}
