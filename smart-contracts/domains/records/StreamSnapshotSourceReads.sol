// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/metadata/StreamSnapshotTypes.sol";
import "../../interfaces/stream/metadata/IStreamCollectionMetadataV1.sol";
import "../../interfaces/stream/metadata/IStreamMetadataRouter.sol";
import "../../interfaces/stream/metadata/IStreamMetadataRouterBinding.sol";
import "../../interfaces/stream/metadata/IStreamMetadataRenderingProfile.sol";
import "../../interfaces/stream/core/IStreamCoreCollectionView.sol";
import "../metadata/StreamMetadataRecoveryRoutes.sol";
import "../metadata/StreamMetadataSubjects.sol";
import "../finality/StreamFinalityRouterEvidence.sol";
import "../finality/StreamContentRootSchemas.sol";

import { StreamChunkedContentEvidence } from "../finality/StreamChunkedContentEvidence.sol";
import {
    IStreamChunkedContentCheckpoint
} from "../../interfaces/stream/finality/IStreamChunkedContentCheckpoint.sol";

/// @notice Reconstructs the native source side of an assembled snapshot from fixed actual hosts.
/// @dev Exact configured script bytes are retained. The renderer's contract read-set profile
///      is not proof that arbitrary JavaScript has no web or execution-environment dependencies.
library StreamSnapshotSourceReads {
    bytes32 private constant PRESENTATION = keccak256("6529STREAM_ROUTER_STABLE_PRESENTATION_V1");

    function requireCurrent(StreamSnapshotTypes.Dependencies memory d, uint256 collectionId)
        public
        view
        returns (StreamSnapshotTypes.NativeFacts memory f)
    {
        return _current(d, collectionId, false);
    }

    function requireCurrentChunked(StreamSnapshotTypes.Dependencies memory d, uint256 collectionId)
        public
        view
        returns (StreamSnapshotTypes.NativeFacts memory f)
    {
        return _current(d, collectionId, true);
    }

    function _current(StreamSnapshotTypes.Dependencies memory d, uint256 collectionId, bool chunked)
        private
        view
        returns (StreamSnapshotTypes.NativeFacts memory f)
    {
        bindings(d);
        if (
            collectionId == 0
                || _word(
                        d,
                        d.targets[0],
                        abi.encodeCall(IStreamCoreCollectionView.collectionExists, (collectionId))
                    ) != bytes32(uint256(1))
        ) {
            revert StreamSnapshotTypes.SnapshotSource();
        }
        f.collectionId = collectionId;
        f.subject = StreamMetadataSubjects.scopeSubject(
            d.chainId,
            d.targets[0],
            StreamFinalityScope(StreamFinalityScopeType.COLLECTION, collectionId, 0, 0)
        );
        bytes memory raw = StreamFinalityRouterEvidence.dynamicRead(
            d.targets[4],
            abi.encodeCall(IStreamMetadataServingFacts.collectionServingSource, (collectionId)),
            14976,
            d.sourceGas
        );
        f.source = abi.decode(raw, (IStreamMetadataServingFacts.ServingSource));
        _canonical(d.targets[4], raw, abi.encode(f.source));
        if (
            bytes(f.source.name).length > 256 || bytes(f.source.description).length > 2048
                || bytes(f.source.imageURI).length > 2048
                || bytes(f.source.animationBaseURI).length > 2048
                || (chunked
                        ? bytes(f.source.script).length != 0
                        : (bytes(f.source.script).length == 0
                            || bytes(f.source.script).length > 8192))
        ) {
            revert StreamSnapshotTypes.SnapshotSource();
        }
        raw = _read(
            d.targets[4],
            abi.encodeCall(IStreamMetadataServingFacts.collectionServingFacts, (collectionId)),
            512,
            d.sourceGas
        );
        f.serving = abi.decode(raw, (IStreamMetadataServingFacts.ServingFacts));
        _canonical(d.targets[4], raw, abi.encode(f.serving));
        if (
            !f.serving.configured
                || f.serving.presentationProfile
                    != (chunked ? StreamChunkedContentEvidence.PROFILE : PRESENTATION)
                || f.serving.mode != keccak256("ONCHAIN") || !f.serving.scriptLocked
                || !f.serving.mediaLocked || !f.serving.baseURILocked
                || !f.serving.dependenciesLocked || !f.serving.artistIdentityLocked
                || !f.serving.displayMetadataLocked
                || (!chunked
                    && (f.serving.scriptHash != keccak256(bytes(f.source.script))
                        || f.serving.scriptBytes != bytes(f.source.script).length))
                || f.serving.imageURIHash != keccak256(bytes(f.source.imageURI))
                || f.serving.animationBaseURIHash != keccak256(bytes(f.source.animationBaseURI))
        ) {
            revert StreamSnapshotTypes.SnapshotSource();
        }
        _pin(f.serving.renderer, f.serving.rendererCodeHash);
        f.serving.coreFrozen = false;
        raw = _read(
            d.targets[4],
            abi.encodeCall(IStreamMetadataServingFacts.artistPresentation, (collectionId)),
            384,
            d.readGas
        );
        f.artist = abi.decode(raw, (IStreamMetadataServingFacts.ArtistPresentation));
        _canonical(d.targets[4], raw, abi.encode(f.artist));
        if (
            !f.artist.locked || f.artist.registry == address(0) || f.artist.registryCodeHash == 0
                || f.artist.artistId == 0 || f.artist.bindingGeneration == 0
                || f.artist.bindingHash == 0 || f.artist.nominatedArtist == address(0)
                || f.artist.identityRecordHash == 0 || f.artist.acceptanceRecordHash == 0
                || f.artist.acceptedAt == 0 || f.artist.lockedAt == 0 || f.artist.snapshotHash == 0
        ) {
            revert StreamSnapshotTypes.SnapshotSource();
        }
        if (chunked) {
            StreamChunkedContentEvidence.Evidence memory e = StreamChunkedContentEvidence.source(
                d.targets[0], d.targets[4], d.chainId, collectionId, f.serving, d.sourceGas, true
            );
            if (e.selection.host != d.targets[1] || e.selection.codeHash != d.codeHashes[1]) {
                revert StreamSnapshotTypes.SnapshotSource();
            }
            f.presentationProfile = StreamChunkedContentEvidence.PROFILE;
            (f.rendererContext, f.dependencyProfile) =
                StreamChunkedContentEvidence.renderer(f.serving, d.readGas);
        } else {
            (f.presentationProfile, f.rendererContext, f.dependencyProfile) = abi.decode(
                _read(
                    d.targets[4],
                    abi.encodeCall(IStreamMetadataRenderingProfile.renderingProfile, ()),
                    96,
                    d.readGas
                ),
                (bytes32, bytes32, bytes32)
            );
            if (
                f.presentationProfile != PRESENTATION
                    || f.rendererContext != keccak256("6529STREAM_METADATA_TOKEN_RENDER_CONTEXT_V1")
                    || f.dependencyProfile
                        != keccak256("6529STREAM_METADATA_RENDER_NO_EXTERNAL_READS_V1")
            ) {
                revert StreamSnapshotTypes.SnapshotSource();
            }
        }
        (f.routerVersion, f.routerManifestHash) =
            StreamFinalityRouterEvidence.moduleIdentity(d.targets[4], d.sourceGas);
        _content(d, f);
        if (
            chunked
                && _word(
                        d,
                        d.targets[6],
                        abi.encodeCall(
                            IStreamChunkedContentCheckpoint.checkpointProfile,
                            (f.leafManifest.checkpointHash)
                        )
                    ) != keccak256("6529STREAM_CONTENT_CHUNKED_ONCHAIN_V1")
        ) revert StreamSnapshotTypes.SnapshotSource();
    }

    function bindings(StreamSnapshotTypes.Dependencies memory d) public view {
        if (
            d.chainId != block.chainid || d.readGas < 50000 || d.sourceGas < d.readGas
                || d.evidenceGas < d.readGas || d.inventoryGas < d.readGas
        ) {
            revert StreamSnapshotTypes.SnapshotConfiguration();
        }
        for (uint256 i; i < d.targets.length; ++i) {
            _pin(d.targets[i], d.codeHashes[i]);
        }
        StreamMetadataRecoveryRoutes.requireCurrentHost(
            d.targets[0],
            keccak256("COLLECTION_METADATA"),
            d.targets[1],
            keccak256("COLLECTION_METADATA"),
            type(IStreamCollectionMetadataV1).interfaceId
        );
        StreamMetadataRecoveryRoutes.requireCurrentHost(
            d.targets[0],
            keccak256("METADATA_ROUTER"),
            d.targets[4],
            keccak256("METADATA_ROUTER"),
            type(IStreamMetadataRouter).interfaceId
        );
        _address(d, d.targets[1], "core()", d.targets[0]);
        _address(d, d.targets[1], "schemaRegistry()", d.targets[2]);
        _address(d, d.targets[1], "chunkStore()", d.targets[3]);
        _address(d, d.targets[2], "chunkStore()", d.targets[3]);
        _address(d, d.targets[4], "core()", d.targets[0]);
        _address(d, d.targets[5], "core()", d.targets[0]);
        _address(d, d.targets[5], "contentCheckpoint()", d.targets[6]);
        _address(d, d.targets[6], "core()", d.targets[0]);
        _address(d, d.targets[6], "metadataRouter()", d.targets[4]);
        if (
            _word(d, d.targets[1], abi.encodeWithSignature("coreCodeHash()")) != d.codeHashes[0]
                || _word(d, d.targets[1], abi.encodeWithSignature("schemaRegistryCodeHash()"))
                    != d.codeHashes[2]
                || _word(d, d.targets[1], abi.encodeWithSignature("chunkStoreCodeHash()"))
                    != d.codeHashes[3]
        ) {
            revert StreamSnapshotTypes.SnapshotConfiguration();
        }
    }

    function _content(
        StreamSnapshotTypes.Dependencies memory d,
        StreamSnapshotTypes.NativeFacts memory f
    ) private view {
        f.contentRootRecordHash = _word(
            d,
            d.targets[4],
            abi.encodeCall(
                IStreamContentRootPublication.collectionContentRootHead, (f.collectionId)
            )
        );
        if (f.contentRootRecordHash == 0) revert StreamSnapshotTypes.SnapshotSource();
        bytes memory raw = StreamFinalityRouterEvidence.dynamicRead(
            d.targets[4],
            abi.encodeCall(
                IStreamContentRootPublication.contentRootRecord, (f.contentRootRecordHash)
            ),
            4096,
            d.evidenceGas
        );
        f.contentRoot = abi.decode(raw, (IStreamContentRootPublication.Record));
        _canonical(d.targets[4], raw, abi.encode(f.contentRoot));
        if (
            f.contentRoot.publication.collectionId != f.collectionId
                || f.contentRoot.artistId != f.artist.artistId
                || f.contentRoot.bindingGeneration != f.artist.bindingGeneration
                || f.contentRoot.bindingHash != f.artist.bindingHash
                || f.contentRoot.artistConsent == 0 || f.contentRoot.publisher == address(0)
                || f.contentRoot.grantRevision == 0
                || (f.contentRoot.authorizationClass != 7 && f.contentRoot.authorizationClass != 8)
                || f.contentRoot.publishedAt == 0 || f.contentRoot.stateHash == 0
                || f.contentRoot.routeHash == 0 || f.contentRoot.contentRoot == 0
                || f.contentRoot.leafCount == 0 || f.contentRoot.manifestHash == 0
                || bytes(f.contentRoot.publication.manifestURI).length > 2048
                || keccak256(
                        abi.encode(
                            keccak256("6529STREAM_CONTENT_ROOT_RECORD_V1"),
                            d.chainId,
                            d.targets[4],
                            f.contentRoot
                        )
                    ) != f.contentRootRecordHash
        ) {
            revert StreamSnapshotTypes.SnapshotSource();
        }
        raw = _read(
            d.targets[5],
            abi.encodeCall(
                IStreamContentLeafManifest.requireCurrentManifest,
                (f.contentRoot.publication.verifiedManifestRecordHash, f.artist.artistId)
            ),
            288,
            d.evidenceGas
        );
        f.leafManifest = abi.decode(raw, (IStreamContentLeafManifest.Manifest));
        _canonical(d.targets[5], raw, abi.encode(f.leafManifest));
        if (
            f.leafManifest.collectionId != f.collectionId
                || f.leafManifest.artistId != f.artist.artistId
                || f.leafManifest.contentRoot != f.contentRoot.contentRoot
                || f.leafManifest.tokenCount != f.contentRoot.leafCount
                || f.leafManifest.manifestHash != f.contentRoot.manifestHash
                || f.leafManifest.artifactHash == 0 || f.leafManifest.coverageHash == 0
                || f.leafManifest.byteLength == 0 || f.leafManifest.checkpointHash == 0
        ) {
            revert StreamSnapshotTypes.SnapshotSource();
        }
        bytes32 coverageWord = _word(d, d.targets[5], abi.encodeWithSignature("artifactCoverage()"));
        if (uint256(coverageWord) > type(uint160).max || coverageWord == 0) {
            revert StreamSnapshotTypes.SnapshotSource();
        }
        address coverage = address(uint160(uint256(coverageWord)));
        _pin(coverage, _word(d, d.targets[5], abi.encodeWithSignature("coverageCodeHash()")));
        bytes32 leafPlan = keccak256(
            abi.encode(
                keccak256("6529STREAM_CONTENT_LEAF_MANIFEST_PLAN_V1"),
                d.chainId,
                d.targets[5],
                d.targets[0],
                d.targets[6],
                coverage,
                f.leafManifest
            )
        );
        if (
            keccak256(
                    abi.encode(keccak256("6529STREAM_CONTENT_LEAF_MANIFEST_VERIFIED_V1"), leafPlan)
                ) != f.contentRoot.publication.verifiedManifestRecordHash
        ) {
            revert StreamSnapshotTypes.SnapshotSource();
        }
        raw = _read(
            d.targets[6],
            abi.encodeCall(
                IStreamOnchainContentCheckpoint.requireCurrentCheckpoint,
                (f.leafManifest.checkpointHash)
            ),
            224,
            d.evidenceGas
        );
        f.checkpoint = abi.decode(raw, (IStreamOnchainContentCheckpoint.Plan));
        _canonical(d.targets[6], raw, abi.encode(f.checkpoint));
        if (
            f.checkpoint.collectionId != f.collectionId
                || f.checkpoint.tokenCount != f.leafManifest.tokenCount
                || f.checkpoint.nextIndex != f.checkpoint.tokenCount
                || f.checkpoint.inventoryHash == 0 || f.checkpoint.servingStateHash == 0
                || f.checkpoint.leafChainHash == 0
                || f.checkpoint.contentRoot != f.contentRoot.contentRoot
        ) {
            revert StreamSnapshotTypes.SnapshotSource();
        }
    }

    function _pin(address target, bytes32 hash) private view {
        if (target.code.length == 0 || hash == 0 || target.codehash != hash) {
            revert StreamSnapshotTypes.SnapshotDependency(target);
        }
    }

    function _address(
        StreamSnapshotTypes.Dependencies memory d,
        address target,
        string memory getter,
        address expected
    ) private view {
        if (
            _word(d, target, abi.encodeWithSignature(getter)) != bytes32(uint256(uint160(expected)))
        ) {
            revert StreamSnapshotTypes.SnapshotDependency(target);
        }
    }

    function _word(StreamSnapshotTypes.Dependencies memory d, address target, bytes memory input)
        private
        view
        returns (bytes32)
    {
        return abi.decode(_read(target, input, 32, d.readGas), (bytes32));
    }

    function _read(address target, bytes memory input, uint256 length, uint256 cap)
        private
        view
        returns (bytes memory)
    {
        return StreamFinalityRouterEvidence.read(target, input, length, cap);
    }

    function _canonical(address target, bytes memory raw, bytes memory encoded) private pure {
        if (keccak256(raw) != keccak256(encoded)) {
            revert StreamSnapshotTypes.SnapshotDependency(target);
        }
    }
}
