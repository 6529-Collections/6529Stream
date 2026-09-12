// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    IStreamContentRootPublication as R
} from "../../interfaces/stream/metadata/IStreamContentRootPublication.sol";
import "../../interfaces/stream/finality/IStreamContentRootEvidenceBinding.sol";
import "../../interfaces/stream/finality/IStreamFinalityDeploymentBindings.sol";
import "../../interfaces/stream/finality/IStreamFinalityEvidenceProvider.sol";
import "../../interfaces/stream/finality/IStreamContentLeafManifest.sol";
import "../../interfaces/stream/finality/IStreamOnchainContentCheckpoint.sol";
import "../../interfaces/stream/preservation/IStreamFinalityArtifactCoverage.sol";
import "../../interfaces/stream/core/IStreamCorePointers.sol";
import "../../interfaces/stream/core/IStreamCoreCollectionView.sol";
import "../../interfaces/stream/artist/IStreamArtistAttributionState.sol";
import "../../interfaces/stream/artist/IStreamArtistFinalityBinding.sol";
import "../../interfaces/stream/metadata/IStreamCollectionMetadataV1.sol";
import "../../interfaces/stream/parameters/IStreamGasParameterHost.sol";
import "../../interfaces/stream/metadata/IStreamSchemaRegistry.sol";
import "../records/StreamRecordFamilies.sol";
import "../finality/StreamContentRootSchemas.sol";
import "./StreamMetadataSubjects.sol";
import "./StreamMetadataRenderer.sol";

/// @notice Authoritative root state in Router storage, using its fixed library and artist consent.
library StreamMetadataContentRoot {
    struct State {
        mapping(uint256 => bytes32) heads;
        mapping(bytes32 => R.Record) records;
    }

    struct Context {
        address core;
        address artist;
    }

    struct Route {
        address finality;
        address provider;
        address metadata;
        address schemas;
        address manifest;
        address artifacts;
        uint256 readGas;
        bytes32 hash;
    }

    event TokenContentRootPublished(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        bytes32 indexed scopeSubject,
        bytes32 indexed recordHash,
        R.Record record
    );

    function familyState(State storage state, address core, uint256 collectionId)
        public
        view
        returns (bytes32)
    {
        bytes32 head = state.heads[collectionId];
        if (head != 0) return state.records[head].stateHash;
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_EMPTY_CONTENT_ROOT_STATE_V1"),
                block.chainid,
                address(this),
                core,
                collectionId
            )
        );
    }

    function prepare(
        State storage state,
        Context memory ctx,
        R.Publication memory p,
        address publisher
    ) public view returns (R.Record memory r) {
        if (p.collectionId == 0 || p.verifiedManifestRecordHash == 0 || publisher == address(0)) revert R.InvalidContentRootPublication();
        bytes32 previous = state.heads[p.collectionId];
        if (p.expectedPredecessor != previous) {
            revert R.ContentRootLineageChanged(p.expectedPredecessor, previous);
        }
        StreamMetadataRenderer.requireValidUtf8ContentUri(
            "contentRootManifestURI", p.manifestURI, 2048, false
        );
        Route memory route = _route(ctx);
        if (
            _word(
                        ctx.core,
                        abi.encodeCall(
                            IStreamCoreCollectionView.collectionExists, (p.collectionId)
                        ),
                        route.readGas
                    ) != 1
                || _word(
                        ctx.core,
                        abi.encodeCall(
                            IStreamCoreCollectionView.collectionFreezeStatus, (p.collectionId)
                        ),
                        route.readGas
                    ) != 0
        ) {
            revert R.InvalidContentRootPublication();
        }
        r.publication = p;
        r.publisher = publisher;
        (r.authorizationClass, r.grantRevision) = _authority(route, p.collectionId, publisher);
        (uint8 attribution, uint64 generation, bytes32 artistId,, bytes32 bindingHash) = abi.decode(
            _read(
                ctx.artist,
                abi.encodeCall(
                    IStreamArtistAttributionState.collectionArtistState, (p.collectionId)
                ),
                160,
                route.readGas
            ),
            (uint8, uint64, bytes32, uint8, bytes32)
        );
        if (
            (attribution != 2 && attribution != 3) || generation == 0 || artistId == 0
                || bindingHash == 0
        ) revert R.InvalidContentRootPublication();
        r.artistId = artistId;
        r.bindingGeneration = generation;
        r.bindingHash = bindingHash;
        IStreamContentLeafManifest.Manifest memory m = abi.decode(
            _read(
                route.manifest,
                abi.encodeCall(
                    IStreamContentLeafManifest.requireCurrentManifest,
                    (p.verifiedManifestRecordHash, artistId)
                ),
                288,
                route.readGas
            ),
            (IStreamContentLeafManifest.Manifest)
        );
        if (
            m.collectionId != p.collectionId || m.artistId != artistId || m.tokenCount == 0
                || m.contentRoot == 0 || m.manifestHash == 0
        ) revert R.InvalidContentRootPublication();
        r.contentRoot = m.contentRoot;
        r.leafCount = m.tokenCount;
        r.manifestHash = m.manifestHash;
        _schemas(route);
        r.routeHash = route.hash;
        r.stateHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_CONTENT_ROOT_STATE_V1"), block.chainid, address(this), r
            )
        );
    }

    function publish(
        State storage state,
        Context memory ctx,
        R.Publication memory p,
        R.Record memory prepared,
        bytes32 artistConsent
    ) public returns (bytes32 hash) {
        if (artistConsent == 0 || block.timestamp > type(uint64).max) {
            revert R.InvalidContentRootPublication();
        }
        R.Record memory current = prepare(state, ctx, p, msg.sender);
        if (keccak256(abi.encode(current)) != keccak256(abi.encode(prepared))) {
            revert R.InvalidContentRootPublication();
        }
        current.artistConsent = artistConsent;
        current.publishedAt = uint64(block.timestamp);
        hash = keccak256(
            abi.encode(
                keccak256("6529STREAM_CONTENT_ROOT_RECORD_V1"),
                block.chainid,
                address(this),
                current
            )
        );
        if (state.records[hash].publisher != address(0)) revert R.InvalidContentRootPublication();
        state.records[hash] = current;
        state.heads[p.collectionId] = hash;
        emit TokenContentRootPublished(
            1, p.collectionId, _subject(ctx.core, p.collectionId), hash, current
        );
    }

    function readRoot(State storage state, address core, uint256 collectionId, bytes32 subject)
        public
        view
        returns (bytes32, uint64, bytes32)
    {
        if (subject != _subject(core, collectionId)) return (0, 0, 0);
        R.Record storage r = state.records[state.heads[collectionId]];
        return (
            r.contentRoot,
            r.leafCount,
            r.leafCount == 0 ? bytes32(0) : StreamContentRootSchemas.LEAF_SCHEMA
        );
    }

    function readRecord(State storage state, bytes32 hash) public view returns (R.Record memory) {
        if (hash == 0 || state.records[hash].publisher == address(0)) {
            revert R.ContentRootRecordUnknown(hash);
        }
        return state.records[hash];
    }

    function _route(Context memory ctx) private view returns (Route memory r) {
        r.finality = _selected(ctx.core, keccak256("ARTWORK_FINALITY_REGISTRY"), 100_000);
        if (
            _address(
                        ctx.artist,
                        abi.encodeCall(IStreamArtistFinalityBinding.finalityRegistry, ()),
                        100_000
                    ) != r.finality
                || bytes32(
                        _word(
                            ctx.artist,
                            abi.encodeCall(
                                IStreamArtistFinalityBinding.finalityRegistryCodeHash, ()
                            ),
                            100_000
                        )
                    ) != r.finality.codehash
        ) revert R.ContentRootComponentChanged(r.finality);
        r.readGas = _word(
            r.finality,
            abi.encodeCall(
                IStreamGasParameterHost.gasParameter,
                (keccak256("6529STREAM_GGP_FINALITY_COMPONENT_READ_GAS"))
            ),
            100_000
        );
        if (r.readGas < 50_000 || r.readGas > type(uint256).max / 64) {
            revert R.InvalidContentRootPublication();
        }
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
        ) revert R.InvalidContentRootPublication();
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
        ) revert R.ContentRootComponentChanged(r.metadata);
        _pin(
            r.metadata,
            bytes32(
                _word(
                    r.provider,
                    abi.encodeCall(IStreamContentRootEvidenceBinding.metadataHostCodeHash, ()),
                    r.readGas
                )
            )
        );
        r.schemas = _address(
            r.provider,
            abi.encodeCall(IStreamContentRootEvidenceBinding.schemaRegistry, ()),
            r.readGas
        );
        _pin(
            r.schemas,
            bytes32(
                _word(
                    r.provider,
                    abi.encodeCall(IStreamContentRootEvidenceBinding.schemaRegistryCodeHash, ()),
                    r.readGas
                )
            )
        );
        if (
            _address(r.metadata, abi.encodeCall(IStreamCollectionMetadataV1.core, ()), r.readGas)
                    != ctx.core
                || _address(
                        r.metadata,
                        abi.encodeCall(IStreamCollectionMetadataV1.schemaRegistry, ()),
                        r.readGas
                    ) != r.schemas
        ) revert R.InvalidContentRootPublication();
        r.manifest = _address(
            r.provider,
            abi.encodeCall(IStreamContentRootEvidenceBinding.contentLeafManifest, ()),
            r.readGas
        );
        _pin(
            r.manifest,
            bytes32(
                _word(
                    r.provider,
                    abi.encodeCall(
                        IStreamContentRootEvidenceBinding.contentLeafManifestCodeHash, ()
                    ),
                    r.readGas
                )
            )
        );
        address checkpoint = _address(
            r.manifest, abi.encodeCall(IStreamContentLeafManifest.contentCheckpoint, ()), r.readGas
        );
        if (
            _address(r.manifest, abi.encodeCall(IStreamContentLeafManifest.core, ()), r.readGas)
                    != ctx.core
                || _address(
                        checkpoint,
                        abi.encodeCall(IStreamOnchainContentCheckpoint.core, ()),
                        r.readGas
                    ) != ctx.core
                || _address(
                        checkpoint,
                        abi.encodeCall(IStreamOnchainContentCheckpoint.metadataRouter, ()),
                        r.readGas
                    ) != address(this)
                || _selected(ctx.core, keccak256("METADATA_ROUTER"), r.readGas) != address(this)
        ) revert R.InvalidContentRootPublication();
        r.artifacts = _address(
            r.finality,
            abi.encodeCall(IStreamFinalityDeploymentBindings.artifactCoverage, ()),
            r.readGas
        );
        if (
            _address(
                        r.manifest,
                        abi.encodeCall(IStreamContentLeafManifest.artifactCoverage, ()),
                        r.readGas
                    ) != r.artifacts
                || _address(
                        r.artifacts,
                        abi.encodeCall(IStreamFinalityArtifactCoverage.schemaRegistry, ()),
                        r.readGas
                    ) != r.schemas
        ) revert R.InvalidContentRootPublication();
        address[10] memory targets = [
            ctx.core,
            ctx.artist,
            address(this),
            r.finality,
            r.provider,
            r.metadata,
            r.schemas,
            r.manifest,
            checkpoint,
            r.artifacts
        ];
        bytes32[10] memory runtimeHashes;
        for (uint256 i; i < targets.length; ++i) {
            runtimeHashes[i] = targets[i].codehash;
        }
        r.hash = keccak256(
            abi.encode(
                keccak256("6529STREAM_CONTENT_ROOT_ROUTE_V1"),
                block.chainid,
                ctx,
                targets,
                runtimeHashes
            )
        );
    }

    function _authority(Route memory r, uint256 collectionId, address publisher)
        private
        view
        returns (uint8, uint64)
    {
        (bool enabled, uint64 revision) = abi.decode(
            _read(
                r.metadata,
                abi.encodeCall(
                    IStreamCollectionMetadataV1.familyWriter,
                    (collectionId, StreamRecordFamilies.SNAPSHOT, 7, publisher)
                ),
                64,
                r.readGas
            ),
            (bool, uint64)
        );
        if (enabled && revision != 0) return (7, revision);
        (enabled, revision) = abi.decode(
            _read(
                r.metadata,
                abi.encodeCall(
                    IStreamCollectionMetadataV1.familyWriter,
                    (0, StreamRecordFamilies.SNAPSHOT, 8, publisher)
                ),
                64,
                r.readGas
            ),
            (bool, uint64)
        );
        if (enabled && revision != 0) return (8, revision);
        revert R.ContentRootAuthorityRequired(publisher);
    }

    function _schemas(Route memory r) private view {
        bytes32[4] memory ids = [
            StreamContentRootSchemas.LEAF_SCHEMA,
            StreamContentRootSchemas.LEAF_CANON,
            StreamContentRootSchemas.ROOT_SCHEMA,
            StreamContentRootSchemas.ROOT_CANON
        ];
        for (uint256 i; i < ids.length; ++i) {
            bytes memory input = abi.encodeCall(IStreamSchemaRegistry.document, (ids[i]));
            bytes memory out = _readBounded(r.schemas, input, 8192, r.readGas);
            IStreamSchemaRegistry.DocumentView memory d =
                abi.decode(out, (IStreamSchemaRegistry.DocumentView));
            if (
                !d.exists || d.status != IStreamSchemaRegistry.DocumentStatus.ACTIVE
                    || uint8(d.specification.kind) != i % 2
                    || keccak256(bytes(d.specification.name)) != ids[i]
                    || d.specification.canonicalizationId != keccak256("RAW_BYTES")
                    || d.specification.contentHash
                        != StreamContentRootSchemas.definitionHash(ids[i])
            ) revert R.InvalidContentRootPublication();
        }
    }

    function _subject(address core, uint256 collectionId) private view returns (bytes32) {
        return StreamMetadataSubjects.scopeSubject(
            block.chainid,
            core,
            StreamFinalityScope(StreamFinalityScopeType.COLLECTION, collectionId, 0, 0)
        );
    }

    function _pin(address target, bytes32 hash) private view {
        if (target.code.length == 0 || target.codehash != hash) {
            revert R.ContentRootComponentChanged(target);
        }
    }

    function _selected(address core, bytes32 kind, uint256 gasCap)
        private
        view
        returns (address target)
    {
        bytes32 hash;
        (target, hash,,,,,,,,) = abi.decode(
            _read(
                core, abi.encodeCall(IStreamCorePointers.getSatellitePointer, (kind)), 320, gasCap
            ),
            (address, bytes32, bool, bytes32, bytes4, address, uint8, bytes32, bytes32, uint64)
        );
        _pin(target, hash);
    }

    function _address(address target, bytes memory input, uint256 gasCap)
        private
        view
        returns (address)
    {
        uint256 word = _word(target, input, gasCap);
        if (word == 0 || word > type(uint160).max) {
            revert R.ContentRootReadFailed(target, bytes4(input));
        }
        return address(uint160(word));
    }

    function _word(address target, bytes memory input, uint256 gasCap)
        private
        view
        returns (uint256)
    {
        return abi.decode(_read(target, input, 32, gasCap), (uint256));
    }

    function _read(address target, bytes memory input, uint256 size, uint256 gasCap)
        private
        view
        returns (bytes memory out)
    {
        out = _readBounded(target, input, size, gasCap);
        if (out.length != size) revert R.ContentRootReadFailed(target, bytes4(input));
    }

    function _readBounded(address target, bytes memory input, uint256 size, uint256 gasCap)
        private
        view
        returns (bytes memory out)
    {
        if (gasleft() <= gasCap + gasCap / 63 + 100_000) {
            revert R.ContentRootReadFailed(target, bytes4(input));
        }
        out = new bytes(size);
        bool ok;
        uint256 actual;
        assembly ("memory-safe") {
            ok := staticcall(gasCap, target, add(input, 32), mload(input), add(out, 32), size)
            actual := returndatasize()
        }
        if (!ok || actual > size) revert R.ContentRootReadFailed(target, bytes4(input));
        assembly ("memory-safe") { mstore(out, actual) }
    }
}
