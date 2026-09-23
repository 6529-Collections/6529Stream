// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamScopedContentRootPublication as R
} from "../../interfaces/stream/metadata/IStreamScopedContentRootPublication.sol";
import {
    IStreamScopedSnapshotPublication as Snap
} from "../../interfaces/stream/metadata/IStreamScopedSnapshotPublication.sol";
import {
    StreamScopedSnapshotTypes as S
} from "../../interfaces/stream/metadata/StreamScopedSnapshotTypes.sol";
import "../../interfaces/stream/finality/IStreamScopedContentRootEvidenceBinding.sol";
import "../../interfaces/stream/finality/IStreamArtworkFinalityRegistry.sol";
import "../../interfaces/stream/finality/IStreamFinalityDeploymentBindings.sol";
import "../../interfaces/stream/finality/IStreamFinalityEvidenceProvider.sol";
import "../../interfaces/stream/core/IStreamCorePointers.sol";
import "../../interfaces/stream/core/IStreamCoreCollectionView.sol";
import "../../interfaces/stream/artist/IStreamArtistAttributionState.sol";
import "../../interfaces/stream/artist/IStreamArtistFinalityBinding.sol";
import "../../interfaces/stream/metadata/IStreamCollectionMetadataV1.sol";
import "../../interfaces/stream/parameters/IStreamGasParameterHost.sol";
import "../finality/StreamFinalityRouterEvidence.sol";
import "../records/StreamRecordFamilies.sol";
import "./StreamMetadataScopedContentState.sol";
import "./StreamMetadataRenderer.sol";

/// @notice Fixed source reads for the original Router's scoped CONTENT_ROOT write.
/// @dev Source selection belongs to the selected, pinned finality provider. This worker
/// neither consumes Artist consent nor writes an independent authority/replay map.
library StreamMetadataScopedContentSource {
    struct Context {
        address core;
        address artist;
    }

    struct Route {
        address finality;
        address provider;
        address metadata;
        address snapshots;
        bytes32 snapshotCodeHash;
        uint256 readGas;
        uint256 validationGas;
        bytes32 hash;
    }

    function prepare(Context memory ctx, R.Publication memory p, address publisher)
        public
        view
        returns (R.Record memory r)
    {
        bytes32 subject = StreamMetadataScopedContentState.subject(ctx.core, p.scope);
        if (publisher == address(0) || p.snapshotRecordHash == 0 || p.snapshotRevision == 0) {
            revert R.InvalidScopedContentRoot();
        }
        StreamMetadataRenderer.requireValidUtf8ContentUri(
            "scopedContentRootURI", p.manifestURI, 2048, false
        );
        Route memory route = _route(ctx);
        if (
            _word(
                        ctx.core,
                        abi.encodeCall(
                            IStreamCoreCollectionView.collectionExists, (p.scope.collectionId)
                        ),
                        route.readGas
                    ) != 1
                || _word(
                        ctx.core,
                        abi.encodeCall(
                            IStreamCoreCollectionView.collectionFreezeStatus, (p.scope.collectionId)
                        ),
                        route.readGas
                    ) != 0
                || _word(
                        route.finality,
                        abi.encodeCall(IStreamArtworkFinalityRegistry.artworkFreezeMode, (p.scope)),
                        route.readGas
                    ) != uint256(StreamArtworkFreezeMode.NONE)
        ) {
            revert R.ScopedContentRootFrozen(subject);
        }
        S.Receipt memory receipt = abi.decode(
            _read(
                route.snapshots,
                abi.encodeCall(
                    Snap.requireCurrent, (p.scope, p.snapshotRecordHash, p.snapshotRevision)
                ),
                544,
                route.validationGas
            ),
            (S.Receipt)
        );
        if (
            receipt.recordHash != p.snapshotRecordHash || receipt.revision != p.snapshotRevision
                || receipt.scopeSubject != subject || receipt.manifestHash == 0
                || receipt.manifestBytes == 0 || receipt.manifestBytes > 524288
        ) revert R.InvalidScopedContentRoot();
        S.Source memory source = _snapshot(ctx, route, p, receipt);
        (uint8 attribution, uint64 generation, bytes32 artistId,, bytes32 bindingHash) = abi.decode(
            _read(
                ctx.artist,
                abi.encodeCall(
                    IStreamArtistAttributionState.collectionArtistState, (p.scope.collectionId)
                ),
                160,
                route.readGas
            ),
            (uint8, uint64, bytes32, uint8, bytes32)
        );
        if (
            (attribution != 2 && attribution != 3) || artistId == 0 || generation == 0
                || bindingHash == 0 || source.artist.artistId != artistId
                || source.artist.bindingGeneration != generation
                || source.artist.bindingHash != bindingHash
        ) revert R.InvalidScopedContentRoot();
        r.publication = p;
        r.snapshotHost = route.snapshots;
        r.snapshotCodeHash = route.snapshotCodeHash;
        r.snapshotManifestHash = receipt.manifestHash;
        r.snapshotSourceHash = receipt.sourceHash;
        r.contentRoot = source.outputs.contentRoot;
        r.leafCount = source.outputs.tokenCount;
        r.outputManifestHash = source.outputs.manifestHash;
        r.artistId = artistId;
        r.bindingGeneration = generation;
        r.bindingHash = bindingHash;
        r.publisher = publisher;
        (r.authorizationClass, r.grantRevision) = _authority(route, p.scope.collectionId, publisher);
        r.routeHash = route.hash;
        r.stateHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_SCOPED_CONTENT_ROOT_STATE_V1"),
                block.chainid,
                address(this),
                ctx.core,
                r
            )
        );
    }

    function _snapshot(
        Context memory ctx,
        Route memory route,
        R.Publication memory p,
        S.Receipt memory receipt
    ) private view returns (S.Source memory source) {
        bytes memory out = StreamFinalityRouterEvidence.dynamicRead(
            route.snapshots,
            abi.encodeCall(Snap.snapshotPayload, (p.snapshotRecordHash)),
            receipt.manifestBytes + 96,
            route.validationGas
        );
        bytes memory raw = abi.decode(out, (bytes));
        if (
            keccak256(out) != keccak256(abi.encode(raw)) || raw.length != receipt.manifestBytes
                || keccak256(raw) != receipt.manifestHash
        ) revert R.InvalidScopedContentRoot();
        bytes32 domain;
        uint256 chain;
        address host;
        address[11] memory targets;
        bytes32[11] memory pins;
        S.Publication memory publication;
        S.Receipt memory fields;
        (domain, chain, host, targets, pins, publication, fields, source) = abi.decode(
            raw,
            (
                bytes32,
                uint256,
                address,
                address[11],
                bytes32[11],
                S.Publication,
                S.Receipt,
                S.Source
            )
        );
        if (
            domain != keccak256("6529STREAM_SCOPED_SNAPSHOT_PAYLOAD_V1") || chain != block.chainid
                || host != route.snapshots || targets[0] != ctx.core || targets[1] != route.metadata
                || targets[4] != address(this) || pins[0] != ctx.core.codehash
                || pins[1] != route.metadata.codehash || pins[4] != address(this).codehash
                || fields.sourceHash != receipt.sourceHash
                || keccak256(abi.encode(publication.scope)) != keccak256(abi.encode(p.scope))
                || keccak256(abi.encode(source.scope)) != keccak256(abi.encode(p.scope))
                || source.outputs.contentRoot == 0 || source.outputs.tokenCount == 0
                || source.outputs.manifestHash == 0
        ) {
            revert R.InvalidScopedContentRoot();
        }
        // The pinned source producer just revalidated this exact receipt and original canonical
        // payload. This decoded record grants no authority independently of requireCurrent above.
    }

    function _route(Context memory ctx) private view returns (Route memory r) {
        r.finality = _selected(ctx.core, keccak256("ARTWORK_FINALITY_REGISTRY"), 100000);
        if (
            _address(
                        ctx.artist,
                        abi.encodeCall(IStreamArtistFinalityBinding.finalityRegistry, ()),
                        100000
                    ) != r.finality
                || bytes32(
                        _word(
                            ctx.artist,
                            abi.encodeCall(
                                IStreamArtistFinalityBinding.finalityRegistryCodeHash, ()
                            ),
                            100000
                        )
                    ) != r.finality.codehash
        ) {
            revert R.ScopedContentRootDependency(r.finality);
        }
        r.readGas = _word(
            r.finality,
            abi.encodeCall(
                IStreamGasParameterHost.gasParameter,
                (keccak256("6529STREAM_GGP_FINALITY_COMPONENT_READ_GAS"))
            ),
            100000
        );
        if (r.readGas < 50000 || r.readGas > type(uint32).max) revert R.InvalidScopedContentRoot();
        if (
            _address(
                        r.finality,
                        abi.encodeCall(IStreamFinalityDeploymentBindings.coreReads, ()),
                        r.readGas
                    ) != ctx.core
                || _address(
                        r.finality,
                        abi.encodeCall(IStreamFinalityDeploymentBindings.sanctionReads, ()),
                        r.readGas
                    ) != ctx.artist
                || _selected(ctx.core, keccak256("METADATA_ROUTER"), r.readGas) != address(this)
        ) revert R.InvalidScopedContentRoot();
        r.provider = _address(
            r.finality,
            abi.encodeCall(IStreamFinalityDeploymentBindings.scopeEvidenceProvider, ()),
            r.readGas
        );
        _pin(
            r.provider,
            bytes32(
                _word(
                    r.finality,
                    abi.encodeCall(
                        IStreamFinalityDeploymentBindings.scopeEvidenceProviderCodeHash, ()
                    ),
                    r.readGas
                )
            )
        );
        r.metadata = _address(
            r.finality,
            abi.encodeCall(IStreamFinalityDeploymentBindings.metadataReads, ()),
            r.readGas
        );
        if (
            r.metadata != _selected(ctx.core, keccak256("COLLECTION_METADATA"), r.readGas)
                || _address(
                        r.provider,
                        abi.encodeCall(IStreamFinalityEvidenceProvider.metadataHost, ()),
                        r.readGas
                    ) != r.metadata
        ) {
            revert R.ScopedContentRootDependency(r.metadata);
        }
        r.snapshots = _address(
            r.provider,
            abi.encodeCall(IStreamScopedContentRootEvidenceBinding.scopedSnapshotHost, ()),
            r.readGas
        );
        r.snapshotCodeHash = bytes32(
            _word(
                r.provider,
                abi.encodeCall(IStreamScopedContentRootEvidenceBinding.scopedSnapshotCodeHash, ()),
                r.readGas
            )
        );
        _pin(r.snapshots, r.snapshotCodeHash);
        r.validationGas = _word(
            r.provider,
            abi.encodeCall(IStreamScopedContentRootEvidenceBinding.scopedSnapshotValidationGas, ()),
            r.readGas
        );
        if (
            r.validationGas < r.readGas || r.validationGas > type(uint32).max
                || _address(r.snapshots, abi.encodeCall(Snap.core, ()), r.readGas) != ctx.core
                || _address(r.snapshots, abi.encodeCall(Snap.metadataHost, ()), r.readGas)
                    != r.metadata
        ) revert R.InvalidScopedContentRoot();
        address[6] memory targets =
            [ctx.core, ctx.artist, address(this), r.finality, r.provider, r.snapshots];
        bytes32[6] memory hashes;
        for (uint256 i; i < targets.length; ++i) {
            hashes[i] = targets[i].codehash;
        }
        r.hash = keccak256(
            abi.encode(
                keccak256("6529STREAM_SCOPED_CONTENT_ROOT_ROUTE_V1"),
                block.chainid,
                targets,
                hashes,
                r.metadata,
                r.metadata.codehash
            )
        );
    }

    function _authority(Route memory r, uint256 cid, address publisher)
        private
        view
        returns (uint8, uint64)
    {
        for (uint8 i; i < 2; ++i) {
            uint8 cls = i == 0 ? 7 : 8;
            bytes memory raw = _read(
                r.metadata,
                abi.encodeCall(
                    IStreamCollectionMetadataV1.familyWriter,
                    (i == 0 ? cid : 0, StreamRecordFamilies.SNAPSHOT, cls, publisher)
                ),
                64,
                r.readGas
            );
            (bool enabled, uint64 revision) = abi.decode(raw, (bool, uint64));
            if (keccak256(raw) != keccak256(abi.encode(enabled, revision))) {
                revert R.InvalidScopedContentRoot();
            }
            if (enabled && revision != 0) return (cls, revision);
        }
        revert R.ScopedContentRootAuthority(publisher);
    }

    function _selected(address core, bytes32 key, uint256 cap)
        private
        view
        returns (address target)
    {
        bytes32 hash;
        uint8 status;
        uint64 revision;
        (target, hash,,,,, status,,, revision) = abi.decode(
            _read(core, abi.encodeCall(IStreamCorePointers.getSatellitePointer, (key)), 320, cap),
            (address, bytes32, bool, bytes32, bytes4, address, uint8, bytes32, bytes32, uint64)
        );
        _pin(target, hash);
        if (status != 1 || revision == 0) revert R.ScopedContentRootDependency(target);
    }

    function _pin(address target, bytes32 hash) private view {
        if (target.code.length == 0 || target.codehash != hash) {
            revert R.ScopedContentRootDependency(target);
        }
    }

    function _address(address target, bytes memory input, uint256 cap)
        private
        view
        returns (address)
    {
        uint256 value = _word(target, input, cap);
        if (value == 0 || value > type(uint160).max) {
            revert R.ScopedContentRootRead(target, bytes4(input));
        }
        return address(uint160(value));
    }

    function _word(address target, bytes memory input, uint256 cap) private view returns (uint256) {
        return abi.decode(_read(target, input, 32, cap), (uint256));
    }

    function _read(address target, bytes memory input, uint256 size, uint256 cap)
        private
        view
        returns (bytes memory)
    {
        return StreamFinalityRouterEvidence.read(target, input, size, cap);
    }
}
