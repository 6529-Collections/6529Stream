// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamProspectiveReferenceTypes as P
} from "../../interfaces/stream/preservation/StreamProspectiveReferenceTypes.sol";
import {
    StreamConservationFloorTypes as F
} from "../../interfaces/stream/metadata/StreamConservationFloorTypes.sol";
import {
    StreamCollectionManifestTypes as M
} from "../../interfaces/stream/metadata/StreamCollectionManifestTypes.sol";
import {
    StreamReferenceRenderTypes as R
} from "../../interfaces/stream/preservation/StreamReferenceRenderTypes.sol";
import {
    IStreamMetadataServingFacts as V
} from "../../interfaces/stream/metadata/IStreamMetadataServingFacts.sol";
import {
    IStreamScriptBundles as B,
    IStreamScriptBundleSelection
} from "../../interfaces/stream/metadata/IStreamScriptBundles.sol";
import "../../interfaces/stream/metadata/IStreamCollectionManifestReads.sol";
import "../../interfaces/stream/metadata/IStreamMetadataRenderingProfile.sol";
import "../../interfaces/stream/core/IStreamCorePointers.sol";
import "../../interfaces/stream/core/IStreamCoreCollectionView.sol";
import { StreamMetadataSubjects } from "../metadata/StreamMetadataSubjects.sol";
import { StreamStaticText } from "../metadata/StreamStaticText.sol";
import { StreamFinalityRouterEvidence } from "../finality/StreamFinalityRouterEvidence.sol";
import { StreamReferenceRendererCatalog } from "../records/StreamReferenceRendererCatalog.sol";
import { StreamProspectiveReferenceEncoding } from "./StreamProspectiveReferenceEncoding.sol";

/// @notice Acyclic, current Floor-selected source. No prospective caller chooses a provider.
import { StreamChunkedContentEvidence } from "../finality/StreamChunkedContentEvidence.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType
} from "../../interfaces/stream/finality/StreamArtworkFinalityTypes.sol";

library StreamProspectiveReferenceSourceReads {
    bytes32 private constant STABLE = keccak256("6529STREAM_ROUTER_STABLE_PRESENTATION_V1");
    bytes32 private constant CHUNKED = keccak256("6529STREAM_ROUTER_CHUNKED_PRESENTATION_V1");

    function validate(P.Dependencies memory d) public view {
        if (
            d.chainId != block.chainid || d.readGas < 50000 || d.sourceGas < d.readGas
                || d.archiveGas < d.readGas || d.rendererCatalogId == 0
                || d.rendererCatalogHash == 0 || d.rendererCatalogBytes == 0
                || d.targets[5] != address(StreamProspectiveReferenceEncoding)
        ) {
            revert P.InvalidProspectiveReference();
        }
        for (uint256 i; i < 6; ++i) {
            pin(d.targets[i], d.codeHashes[i]);
        }
        same(d.targets[1], "core()", d.targets[0], d.readGas);
        if (
            word(d.targets[1], abi.encodeWithSignature("coreCodeHash()"), d.readGas)
                    != d.codeHashes[0]
                || uint256(
                        word(
                            d.targets[1], abi.encodeWithSignature("deploymentChainId()"), d.readGas
                        )
                    ) != d.chainId
        ) {
            revert P.ProspectiveDependency(d.targets[1]);
        }
        bytes memory raw =
            read(d.targets[0], abi.encodeWithSignature("conservationFloor()"), 64, d.readGas);
        (address floor, bytes32 codeHash) = abi.decode(raw, (address, bytes32));
        canonical(raw, abi.encode(floor, codeHash));
        if (floor != d.targets[1] || codeHash != d.codeHashes[1]) {
            revert P.ProspectiveDependency(floor);
        }
        same(d.targets[2], "chunkStore()", d.targets[3], d.readGas);
        same(d.targets[4], "core()", d.targets[0], d.readGas);
    }

    function current(P.Dependencies memory d, uint256 cid) public view returns (P.Source memory s) {
        validate(d);
        if (
            cid == 0
                || uint256(
                        word(
                            d.targets[0],
                            abi.encodeCall(IStreamCoreCollectionView.collectionExists, (cid)),
                            d.readGas
                        )
                    ) != 1
        ) {
            revert P.InvalidProspectiveReference();
        }
        bytes memory raw =
            read(d.targets[1], abi.encodeWithSignature("sourceSetHead()"), 64, d.readGas);
        (s.floorSourceId, s.floorSourceSetHash) = abi.decode(raw, (uint64, bytes32));
        canonical(raw, abi.encode(s.floorSourceId, s.floorSourceSetHash));
        if (
            s.floorSourceId == 0 || s.floorSourceSetHash == 0
                || uint256(word(d.targets[1], abi.encodeWithSignature("sourceCount()"), d.readGas))
                    != s.floorSourceId
                || word(
                        d.targets[1],
                        abi.encodeWithSignature("sourceSetHashAt(uint64)", s.floorSourceId),
                        d.readGas
                    ) != s.floorSourceSetHash
        ) {
            revert P.InvalidProspectiveReference();
        }
        raw = read(
            d.targets[1],
            abi.encodeWithSignature("sourceAt(uint64)", s.floorSourceId),
            256,
            d.readGas
        );
        s.provider = abi.decode(raw, (F.Source));
        canonical(raw, abi.encode(s.provider));
        F.Source memory f = s.provider;
        if (
            f.configurationHash == 0 || f.actionId == 0 || f.admittedAt == 0
                || f.admittedAt > block.timestamp || f.predecessor >= s.floorSourceId
        ) revert P.InvalidProspectiveReference();
        pin(f.metadata, f.metadataCodeHash);
        pin(f.provider, f.providerCodeHash);
        (address metadata, bytes32 metadataPin) = selected(d, keccak256("COLLECTION_METADATA"));
        if (metadata != f.metadata || metadataPin != f.metadataCodeHash) {
            revert P.ProspectiveDependency(metadata);
        }
        (s.router, s.routerCodeHash) = selected(d, keccak256("METADATA_ROUTER"));
        same(f.metadata, "core()", d.targets[0], d.readGas);
        same(f.metadata, "schemaRegistry()", d.targets[2], d.readGas);
        same(f.metadata, "chunkStore()", d.targets[3], d.readGas);
        same(s.router, "core()", d.targets[0], d.readGas);
        same(f.provider, "core()", d.targets[0], d.readGas);
        same(f.provider, "metadata()", f.metadata, d.readGas);
        if (
            word(f.provider, abi.encodeWithSignature("coreCodeHash()"), d.readGas)
                    != d.codeHashes[0]
                || word(f.provider, abi.encodeWithSignature("metadataCodeHash()"), d.readGas)
                    != f.metadataCodeHash
                || word(f.provider, abi.encodeWithSignature("configurationHash()"), d.readGas)
                    != f.configurationHash
                || uint256(
                        word(f.provider, abi.encodeWithSignature("deploymentChainId()"), d.readGas)
                    ) != d.chainId
                || uint256(
                        word(
                            f.provider,
                            abi.encodeWithSelector(
                                bytes4(0x01ffc9a7),
                                bytes4(keccak256("currentReleaseContext(uint256)"))
                            ),
                            d.readGas
                        )
                    ) != 1
        ) {
            revert P.ProspectiveDependency(f.provider);
        }
        raw = read(
            f.provider,
            abi.encodeWithSignature("currentReleaseContext(uint256)", cid),
            192,
            d.sourceGas
        );
        s.release = abi.decode(raw, (F.ReleaseContext));
        canonical(raw, abi.encode(s.release));
        bytes32 subject = StreamMetadataSubjects.scopeSubject(
            d.chainId,
            d.targets[0],
            StreamFinalityScope(StreamFinalityScopeType.COLLECTION, cid, 0, 0)
        );
        if (
            s.release.scopeSubject != subject || !s.release.scriptWork
                || s.release.scriptSourceHash == 0 || s.release.sourceContextHash == 0
                || s.release.membershipHash == 0
        ) revert P.InvalidProspectiveReference();
        raw = read(s.router, abi.encodeCall(V.collectionServingFacts, (cid)), 512, d.sourceGas);
        s.serving = abi.decode(raw, (V.ServingFacts));
        canonical(raw, abi.encode(s.serving));
        if (
            !s.serving.configured || s.serving.mode != keccak256("ONCHAIN")
                || s.serving.scriptBytes == 0 || s.serving.scriptBytes > 24576
                || (s.serving.presentationProfile != STABLE
                    && s.serving.presentationProfile != CHUNKED)
        ) {
            revert P.InvalidProspectiveReference();
        }
        pin(s.serving.renderer, s.serving.rendererCodeHash);
        raw = dynamicRead(
            s.router, abi.encodeCall(V.collectionServingSource, (cid)), 14976, d.sourceGas
        );
        s.display = abi.decode(raw, (V.ServingSource));
        canonical(raw, abi.encode(s.display));
        if (
            bytes(s.display.name).length > 256 || bytes(s.display.description).length > 2048
                || bytes(s.display.imageURI).length > 2048
                || bytes(s.display.animationBaseURI).length != 0
                || bytes(s.display.script).length > 8192
                || keccak256(bytes(s.display.imageURI)) != s.serving.imageURIHash
                || keccak256(bytes(s.display.animationBaseURI)) != s.serving.animationBaseURIHash
        ) revert P.InvalidProspectiveReference();
        raw = read(s.router, abi.encodeCall(V.collectionLiveArtistStatus, (cid)), 224, d.sourceGas);
        s.artist = abi.decode(raw, (V.LiveArtistStatus));
        canonical(raw, abi.encode(s.artist));
        (address artist,) = selected(d, keccak256("ARTIST_REGISTRY"));
        if (s.artist.registry != artist) revert P.ProspectiveDependency(artist);
        s.artistId = s.artist.artistId;
        _script(d, cid, s);
        _media(d, cid, s);
        if (
            s.release.membershipHash
                != keccak256(
                    abi.encode(
                        keccak256("6529STREAM_CONSERVATION_COLLECTION_RELEASE_V1"),
                        d.chainId,
                        d.targets[0],
                        cid,
                        subject,
                        s.release.mediaInventoryHash,
                        s.release.scriptSourceHash
                    )
                )
        ) revert P.InvalidProspectiveReference();
        _renderer(d, s);
    }

    function _script(P.Dependencies memory d, uint256 cid, P.Source memory s) private view {
        address metadata = s.provider.metadata;
        s.scriptManifestHash = word(
            metadata,
            abi.encodeCall(IStreamCollectionManifestReads.scriptManifestHash, (cid)),
            d.sourceGas
        );
        bytes memory raw = dynamicRead(
            metadata,
            abi.encodeCall(IStreamCollectionManifestReads.scriptManifest, (cid)),
            8192,
            d.sourceGas
        );
        s.scriptManifest = abi.decode(raw, (M.ScriptManifest));
        canonical(raw, abi.encode(s.scriptManifest));
        M.ScriptManifest memory m = abi.decode(raw, (M.ScriptManifest));
        if (
            s.scriptManifestHash == 0 || !m.executable || m.scriptHash != s.serving.scriptHash
                || bytes(m.libraryURI).length != 0
                || m.rendererCompatibility != s.serving.presentationProfile
                || keccak256(bytes(m.mimeType)) != keccak256("application/javascript")
        ) revert P.InvalidProspectiveReference();
        if (s.serving.presentationProfile == STABLE) {
            if (
                m.sourceType != M.PayloadSourceType.INLINE_CHUNKS || m.chunkCount != 1
                    || bytes(m.sourcePointer).length != 0
            ) revert P.InvalidProspectiveReference();
            s.script = bytes(s.display.script);
            raw = dynamicRead(
                metadata,
                abi.encodeCall(IStreamCollectionManifestReads.scriptChunk, (cid, 0)),
                8256,
                d.sourceGas
            );
            bytes memory original = abi.decode(raw, (bytes));
            canonical(raw, abi.encode(original));
            if (keccak256(original) != keccak256(s.script)) revert P.InvalidProspectiveReference();
        } else {
            StreamChunkedContentEvidence.Evidence memory bundle = StreamChunkedContentEvidence.source(
                d.targets[0], s.router, d.chainId, cid, s.serving, d.sourceGas, false
            );
            if (
                bundle.selection.host != metadata
                    || bundle.selection.codeHash != s.provider.metadataCodeHash
                    || bundle.selection.manifestHash != s.scriptManifestHash
                    || bundle.script.libraryBundle != 0 || bundle.script.chunkCount != m.chunkCount
                    || bundle.script.sourceType != m.sourceType
            ) revert P.InvalidProspectiveReference();
            s.script = new bytes(s.serving.scriptBytes);
            uint256 cursor;
            uint256 size = m.sourceType == M.PayloadSourceType.SSTORE2 ? 24576 : 8192;
            for (uint256 i; i < m.chunkCount; ++i) {
                raw = dynamicRead(
                    metadata,
                    abi.encodeCall(B.scriptBundleChunk, (bundle.selection.bundleId, i)),
                    size + 64,
                    d.sourceGas
                );
                bytes memory part = abi.decode(raw, (bytes));
                canonical(raw, abi.encode(part));
                uint256 count = s.script.length - cursor;
                if (count > size) count = size;
                if (count == 0 || part.length != count) revert P.InvalidProspectiveReference();
                for (uint256 j; j < count; ++j) {
                    s.script[cursor + j] = part[j];
                }
                cursor += count;
            }
            if (cursor != s.script.length) revert P.InvalidProspectiveReference();
            m.sourcePointer = "";
        }
        if (
            s.script.length != s.serving.scriptBytes || keccak256(s.script) != s.serving.scriptHash
                || !StreamStaticText.isValidUtf8(string(s.script))
                || s.release.scriptSourceHash
                    != keccak256(
                        abi.encode(
                            keccak256("6529STREAM_CONSERVATION_NATIVE_SCRIPT_V1"),
                            m,
                            s.serving.scriptBytes,
                            s.serving.renderer,
                            s.serving.rendererCodeHash
                        )
                    )
        ) revert P.InvalidProspectiveReference();
    }

    function _media(P.Dependencies memory d, uint256 cid, P.Source memory s) private view {
        s.mediaManifestHash = word(
            s.provider.metadata,
            abi.encodeCall(IStreamCollectionManifestReads.mediaManifestHash, (cid)),
            d.sourceGas
        );
        bytes memory raw = dynamicRead(
            s.provider.metadata,
            abi.encodeCall(IStreamCollectionManifestReads.mediaManifest, (cid)),
            16384,
            d.sourceGas
        );
        s.mediaManifest = abi.decode(raw, (M.MediaManifest));
        canonical(raw, abi.encode(s.mediaManifest));
        M.MediaManifest memory m = s.mediaManifest;
        if (
            s.mediaManifestHash == 0 || m.manifestHash != 0 || bytes(m.manifestURI).length != 0
                || m.alternatesHash != 0 || bytes(m.alternatesURI).length != 0
                || keccak256(bytes(m.imageURI)) != keccak256(bytes(s.display.imageURI))
        ) revert P.InvalidProspectiveReference();
        _slot(m.imageSourceType, m.imageURI, m.imageHash);
        _slot(m.animationSourceType, m.animationURI, m.animationHash);
        _slot(m.contentSourceType, m.contentURI, m.contentHash);
        uint8 mask = (m.imageHash == 0 ? 0 : 1) | (m.animationHash == 0 ? 0 : 2)
            | (m.contentHash == 0 ? 0 : 4);
        if (
            s.release.mediaInventoryHash
                    != keccak256(abi.encode(keccak256("6529STREAM_MEDIA_MASTER_INVENTORY_V1"), m))
                || s.release.sourceContextHash
                    != keccak256(
                        abi.encode(
                            s.provider.configurationHash,
                            s.mediaManifestHash,
                            s.scriptManifestHash,
                            mask,
                            s.serving,
                            s.release.membershipHash
                        )
                    )
        ) revert P.InvalidProspectiveReference();
    }

    function _slot(M.PayloadSourceType kind, string memory uri, bytes32 digest) private pure {
        if (kind == M.PayloadSourceType.NONE
                ? bytes(uri).length != 0 || digest != 0
                : bytes(uri).length == 0 || digest == 0) revert P.InvalidProspectiveReference();
    }

    function _renderer(P.Dependencies memory d, P.Source memory s) private view {
        R.RendererDeclaration memory r;
        (r.routerVersion, r.routerManifestHash) =
            StreamFinalityRouterEvidence.moduleIdentity(s.router, d.readGas);
        r.renderer = s.serving.renderer;
        r.rendererCodeHash = s.serving.rendererCodeHash;
        r.presentationProfile = s.serving.presentationProfile;
        r.rendererClass = keccak256("STATIC");
        if (r.presentationProfile == CHUNKED) {
            (r.rendererContext, r.dependencyReadSet) =
                StreamChunkedContentEvidence.renderer(s.serving, d.readGas);
        } else {
            bytes memory raw = read(
                s.router,
                abi.encodeCall(IStreamMetadataRenderingProfile.renderingProfile, ()),
                96,
                d.readGas
            );
            bytes32 profile;
            (profile, r.rendererContext, r.dependencyReadSet) =
                abi.decode(raw, (bytes32, bytes32, bytes32));
            if (
                profile != STABLE
                    || r.rendererContext != keccak256("6529STREAM_METADATA_TOKEN_RENDER_CONTEXT_V1")
                    || r.dependencyReadSet
                        != keccak256("6529STREAM_METADATA_RENDER_NO_EXTERNAL_READS_V1")
            ) revert P.InvalidProspectiveReference();
        }
        s.renderer = StreamReferenceRendererCatalog.requireStatic(referenceDependencies(d, s), r);
    }

    function referenceDependencies(P.Dependencies memory d, P.Source memory s)
        internal
        pure
        returns (R.Dependencies memory r)
    {
        r.targets[0] = d.targets[0];
        r.codeHashes[0] = d.codeHashes[0];
        r.targets[1] = s.provider.metadata;
        r.codeHashes[1] = s.provider.metadataCodeHash;
        r.targets[2] = d.targets[2];
        r.codeHashes[2] = d.codeHashes[2];
        r.targets[3] = d.targets[3];
        r.codeHashes[3] = d.codeHashes[3];
        r.targets[4] = s.router;
        r.codeHashes[4] = s.routerCodeHash;
        r.targets[6] = d.targets[4];
        r.codeHashes[6] = d.codeHashes[4];
        r.chainId = d.chainId;
        r.readGas = d.readGas;
        r.sourceGas = d.sourceGas;
        r.archiveGas = d.archiveGas;
        r.rendererCatalogId = d.rendererCatalogId;
        r.rendererCatalogHash = d.rendererCatalogHash;
        r.rendererCatalogBytes = d.rendererCatalogBytes;
    }

    function sourceHash(P.Dependencies memory d, uint256 cid, P.Source memory s)
        public
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_PROSPECTIVE_SOURCE_V1"), d.chainId, address(this), d, cid, s
            )
        );
    }

    function selected(P.Dependencies memory d, bytes32 role)
        internal
        view
        returns (address target, bytes32 pinHash)
    {
        uint256[10] memory w = abi.decode(
            read(
                d.targets[0],
                abi.encodeCall(IStreamCorePointers.getSatellitePointer, (role)),
                320,
                d.readGas
            ),
            (uint256[10])
        );
        target = address(uint160(w[0]));
        pinHash = bytes32(w[1]);
        if (
            w[0] > type(uint160).max || w[2] > 1 || bytes32(w[3]) != role
                || (w[4] & type(uint224).max) != 0 || w[5] > type(uint160).max || w[6] != 1
                || w[7] == 0 || w[8] == 0 || w[9] == 0 || w[9] > type(uint64).max
        ) revert P.ProspectiveDependency(target);
        pin(target, pinHash);
    }

    function pin(address target, bytes32 hash) internal view {
        if (target.code.length == 0 || hash == 0 || target.codehash != hash) {
            revert P.ProspectiveDependency(target);
        }
    }

    function same(address target, string memory getter, address expected, uint256 cap)
        internal
        view
    {
        if (
            word(target, abi.encodeWithSignature(getter), cap)
                != bytes32(uint256(uint160(expected)))
        ) revert P.ProspectiveDependency(target);
    }

    function word(address target, bytes memory input, uint256 cap) internal view returns (bytes32) {
        return abi.decode(read(target, input, 32, cap), (bytes32));
    }

    function read(address target, bytes memory input, uint256 length, uint256 cap)
        internal
        view
        returns (bytes memory)
    {
        return StreamFinalityRouterEvidence.read(target, input, length, cap);
    }

    function dynamicRead(address target, bytes memory input, uint256 maximum, uint256 cap)
        internal
        view
        returns (bytes memory)
    {
        return StreamFinalityRouterEvidence.dynamicRead(target, input, maximum, cap);
    }

    function canonical(bytes memory raw, bytes memory encoded) internal pure {
        if (keccak256(raw) != keccak256(encoded)) revert P.InvalidProspectiveReference();
    }
}
