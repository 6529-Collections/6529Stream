// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamFinalityRouterEvidence.sol";
import "../metadata/StreamMetadataSubjects.sol";
import {
    IStreamStaticSelectionCheckpoint as C
} from "../../interfaces/stream/finality/IStreamStaticSelectionCheckpoint.sol";
import {
    IStreamStaticMetadataRouter as S
} from "../../interfaces/stream/metadata/IStreamStaticMetadataRouter.sol";
import { IStreamRenderer as R } from "../../interfaces/stream/metadata/IStreamRenderer.sol";

/// @notice Local immutable STATIC component commitments for explicitly authenticated profiles.
/// @dev A fixed scoped/V2 adapter supplies the exact source projection after checking its original
/// snapshot/root. The worker independently rechecks complete current selection and original bytes.
/// No finality/input manifest, sanction, component array, or render inventory enters these hashes.
/// Live annotation and profile currentness remains an output/reference obligation, not frozen here.
library StreamFinalityStaticComponentFacts {
    struct Config {
        address core;
        address metadata;
        address router;
        address selection;
        bytes32 coreCodeHash;
        bytes32 metadataCodeHash;
        bytes32 routerCodeHash;
        bytes32 selectionCodeHash;
        uint256 chainId;
        uint256 readGas;
        uint256 sourceGas;
    }

    struct AuthenticatedSelection {
        StreamFinalityScope scope;
        bytes32 sourceProfile;
        bytes32 selectionId;
        bytes32 membershipHash;
        bytes32 selectionRoot;
        uint64 tokenCount;
        bytes32 lockedArtistSnapshotHash;
    }

    struct Original {
        C.TokenSelection row;
        S.ConfigRecord config;
        S.RawSource source;
    }
    bytes32 private constant DOMAIN = keccak256("6529STREAM_AUTHENTICATED_STATIC_COMPONENT_V1");
    bytes32 private constant ROW = keccak256("6529STREAM_AUTHENTICATED_STATIC_COMPONENT_ROW_V1");
    bytes32 private constant FOLD = keccak256("6529STREAM_AUTHENTICATED_STATIC_COMPONENT_FOLD_V1");
    error StaticComponentSource();
    error StaticComponentFamily(bytes32 family);

    function facts(Config memory c, AuthenticatedSelection memory a, bytes32 family)
        public
        view
        returns (bool frozen, bytes32 dataHash)
    {
        if (!StreamFinalityRouterEvidence.supported(family)) {
            revert StaticComponentFamily(family);
        }
        _pins(c);
        StreamMetadataSubjects.scopeSubject(c.chainId, c.core, a.scope);
        if (
            a.sourceProfile == 0 || a.selectionId == 0 || a.membershipHash == 0
                || a.selectionRoot == 0 || a.tokenCount == 0
        ) revert StaticComponentSource();
        bytes memory raw = StreamFinalityRouterEvidence.read(
            c.selection,
            abi.encodeCall(C.requireCurrentCheckpoint, (a.selectionId)),
            288,
            c.sourceGas
        );
        C.Plan memory p = abi.decode(raw, (C.Plan));
        if (
            keccak256(raw) != keccak256(abi.encode(p))
                || keccak256(abi.encode(p.scope)) != keccak256(abi.encode(a.scope))
                || p.membershipHash != a.membershipHash || p.selectionRoot != a.selectionRoot
                || p.tokenCount != a.tokenCount || p.nextIndex != p.tokenCount
        ) revert StaticComponentSource();
        bytes32 identity = keccak256(
            abi.encode(
                DOMAIN,
                family,
                c.chainId,
                c.core,
                c.metadata,
                c.router,
                c.selection,
                c.selectionCodeHash,
                a
            )
        );
        bytes32 selectedRoot;
        bytes32 folded;
        frozen = true;
        for (uint256 i; i < a.tokenCount; ++i) {
            Original memory o = _original(c, a, i);
            bytes32 selectedRow = keccak256(
                abi.encode(
                    keccak256("6529STREAM_STATIC_SELECTION_ROW_V1"),
                    c.chainId,
                    c.core,
                    c.router,
                    o.row
                )
            );
            selectedRoot = keccak256(
                abi.encode(
                    keccak256("6529STREAM_STATIC_SELECTION_CHAIN_V1"), selectedRoot, i, selectedRow
                )
            );
            bytes32 componentRow = keccak256(
                abi.encode(
                    ROW,
                    identity,
                    family,
                    i,
                    o.row.tokenId,
                    o.row.configRecordHash,
                    o.row.configHash,
                    o.row.sourceSnapshotHash,
                    o.row.rawSourceHash,
                    _fields(family, o)
                )
            );
            folded = keccak256(
                abi.encode(FOLD, identity, family, folded, i, o.row.tokenId, componentRow)
            );
        }
        if (selectedRoot != a.selectionRoot) revert StaticComponentSource();
        if (family == StreamFinalityDomains.COMPONENT_METADATA_ROUTER) {
            raw = StreamFinalityRouterEvidence.read(
                c.router,
                abi.encodeCall(
                    IStreamMetadataServingFacts.artistPresentation, (a.scope.collectionId)
                ),
                384,
                c.readGas
            );
            IStreamMetadataServingFacts.ArtistPresentation memory artist =
                abi.decode(raw, (IStreamMetadataServingFacts.ArtistPresentation));
            if (
                keccak256(raw) != keccak256(abi.encode(artist)) || !artist.locked
                    || artist.snapshotHash == 0 || artist.snapshotHash != a.lockedArtistSnapshotHash
            ) revert StaticComponentSource();
            folded = keccak256(abi.encode(FOLD, identity, family, folded, artist));
        }
        dataHash = keccak256(abi.encode(DOMAIN, identity, family, a.tokenCount, folded));
    }

    function _original(Config memory c, AuthenticatedSelection memory a, uint256 i)
        private
        view
        returns (Original memory o)
    {
        bytes memory raw = StreamFinalityRouterEvidence.read(
            c.selection, abi.encodeCall(C.selectionAt, (a.selectionId, i)), 896, c.readGas
        );
        o.row = abi.decode(raw, (C.TokenSelection));
        if (keccak256(raw) != keccak256(abi.encode(o.row)) || o.row.tokenId == 0) {
            revert StaticComponentSource();
        }
        raw = StreamFinalityRouterEvidence.dynamicRead(
            c.router,
            abi.encodeCall(S.metadataConfigRecord, (o.row.configRecordHash)),
            8192,
            c.readGas
        );
        o.config = abi.decode(raw, (S.ConfigRecord));
        if (
            keccak256(raw) != keccak256(abi.encode(o.config)) || keccak256(raw) != o.row.configHash
                || o.config.recordHash != o.row.configRecordHash
                || o.config.collectionId != a.scope.collectionId
                || (o.config.tokenId != 0 && o.config.tokenId != o.row.tokenId)
                || !o.config.config.frozen || o.config.config.mode != R.MetadataMode.ONCHAIN
                || o.config.config.renderer != o.row.selection.renderer
                || o.config.sourceSnapshotHash != o.row.sourceSnapshotHash
                || keccak256(abi.encode(o.config.selection))
                    != keccak256(abi.encode(o.row.selection))
        ) revert StaticComponentSource();
        bytes32 saved = o.config.recordHash;
        o.config.recordHash = 0;
        if (
            keccak256(
                    abi.encode(
                        keccak256("6529STREAM_STATIC_METADATA_CONFIG_RECORD_V1"),
                        c.core,
                        c.router,
                        o.config
                    )
                ) != saved
        ) revert StaticComponentSource();
        o.config.recordHash = saved;
        raw = StreamFinalityRouterEvidence.dynamicRead(
            c.router,
            abi.encodeCall(S.staticRenderSourceForConfig, (a.scope.collectionId, saved)),
            24000,
            c.readGas
        );
        R.MetadataConfig memory selected;
        (o.source, selected) = abi.decode(raw, (S.RawSource, R.MetadataConfig));
        if (
            keccak256(raw) != keccak256(abi.encode(o.source, selected))
                || keccak256(abi.encode(selected)) != keccak256(abi.encode(o.config.config))
                || !o.source.configured || o.source.chainId != c.chainId
                || keccak256(abi.encode(o.source)) != o.row.rawSourceHash
                || keccak256(
                        abi.encode(keccak256("6529STREAM_STATIC_SOURCE_SNAPSHOT_V1"), o.source)
                    ) != o.row.sourceSnapshotHash
        ) revert StaticComponentSource();
    }

    function _fields(bytes32 family, Original memory o) private pure returns (bytes32) {
        S.Selection memory s = o.row.selection;
        if (family == StreamFinalityDomains.COMPONENT_RENDERER) {
            return keccak256(
                abi.encode(
                    s.registry,
                    s.registryCodeHash,
                    s.versionKey,
                    s.renderer,
                    s.rendererCodeHash,
                    s.rendererId,
                    s.rendererVersion,
                    s.registrationHash
                )
            );
        }
        if (family == StreamFinalityDomains.COMPONENT_RENDER_CONTEXT) {
            return keccak256(abi.encode(s.contextVersion, s.schemaHash, o.config.config));
        }
        if (family == StreamFinalityDomains.COMPONENT_DEPENDENCY_SOURCE) {
            return keccak256(
                abi.encode(
                    s.registry,
                    s.registryCodeHash,
                    s.versionKey,
                    s.readSetHash,
                    s.registrationHash,
                    o.row.sources,
                    o.row.sourceCodeHashes,
                    o.source.scriptManifest
                )
            );
        }
        if (family == StreamFinalityDomains.COMPONENT_SCRIPT_SOURCE) {
            return keccak256(abi.encode(keccak256(bytes(o.source.script)), o.source.scriptManifest));
        }
        if (family == StreamFinalityDomains.COMPONENT_MEDIA_MANIFEST) {
            return keccak256(
                abi.encode(
                    keccak256(bytes(o.source.imageURI)),
                    keccak256(bytes(o.source.animationBaseURI)),
                    o.source.mediaManifest,
                    keccak256(bytes(o.config.config.baseURI)),
                    keccak256(bytes(o.config.config.pendingURI)),
                    o.config.config.offchainURIIdMode
                )
            );
        }
        return keccak256(
            abi.encode(
                keccak256(bytes(o.source.name)),
                keccak256(bytes(o.source.description)),
                o.source.configured,
                o.config.config.mode
            )
        );
    }

    function _pins(Config memory c) private view {
        if (c.chainId != block.chainid || c.readGas < 50000 || c.sourceGas < c.readGas) {
            revert StaticComponentSource();
        }
        address[4] memory targets = [c.core, c.metadata, c.router, c.selection];
        bytes32[4] memory hashes =
            [c.coreCodeHash, c.metadataCodeHash, c.routerCodeHash, c.selectionCodeHash];
        for (uint256 i; i < 4; ++i) {
            if (targets[i].code.length == 0 || hashes[i] == 0 || targets[i].codehash != hashes[i]) {
                revert StaticComponentSource();
            }
        }
        if (
            _address(c, c.selection, abi.encodeCall(C.core, ())) != c.core
                || _address(c, c.selection, abi.encodeCall(C.metadataRouter, ())) != c.router
                || _address(c, c.selection, abi.encodeWithSignature("metadataHost()")) != c.metadata
        ) revert StaticComponentSource();
    }

    function _address(Config memory c, address target, bytes memory input)
        private
        view
        returns (address)
    {
        return
            abi.decode(StreamFinalityRouterEvidence.read(target, input, 32, c.readGas), (address));
    }
}
