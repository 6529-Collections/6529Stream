// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamScopedContentRootPublication as R
} from "../../interfaces/stream/metadata/IStreamScopedContentRootPublication.sol";
import {
    IStreamScopedPolicySnapshotPublicationV2 as Snap
} from "../../interfaces/stream/metadata/IStreamScopedPolicySnapshotPublicationV2.sol";
import {
    StreamScopedPolicySnapshotTypesV2 as S
} from "../../interfaces/stream/metadata/StreamScopedPolicySnapshotTypesV2.sol";
import {
    IStreamScopedPolicyContentRootEvidenceBindingV2 as Provider
} from "../../interfaces/stream/finality/IStreamScopedPolicyContentRootEvidenceBindingV2.sol";
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
import { IERC165 } from "../../vendor/openzeppelin/IERC165.sol";
import {
    IStreamScopedPolicyContentRootPublicationV2 as V
} from "../../interfaces/stream/metadata/IStreamScopedPolicyContentRootPublicationV2.sol";
import {
    StreamFinalityScopedPolicySnapshotReadsV2 as SnapshotReads
} from "../finality/StreamFinalityScopedPolicySnapshotReadsV2.sol";
import {
    StreamScopedPolicyContentRootSchemasV2 as Schemas
} from "../finality/StreamScopedPolicyContentRootSchemasV2.sol";
import {
    StreamScopedPolicyOutputSchemasV2 as OutputSchemas
} from "../finality/StreamScopedPolicyOutputSchemasV2.sol";
import { StreamWorkRecordContext as Documents } from "../records/StreamWorkRecordContext.sol";
import {
    IStreamSchemaRegistry as Schema
} from "../../interfaces/stream/metadata/IStreamSchemaRegistry.sol";

/// @notice Exact full-policy V2 sources for the original Router's scoped CONTENT_ROOT write.
/// @dev Source selection belongs to the selected, pinned finality provider. This worker
/// neither consumes Artist consent nor writes an independent authority/replay map.
library StreamMetadataScopedPolicyContentSourceV2 {
    bytes32 private constant SNAPSHOT_PROFILE = keccak256("6529STREAM_SCOPED_POLICY_SNAPSHOT_V2");

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
        returns (R.Record memory r, V.Binding memory binding)
    {
        bytes32 subject = StreamMetadataScopedContentState.subject(ctx.core, p.scope);
        if (publisher == address(0) || p.snapshotRecordHash == 0 || p.snapshotRevision == 0) {
            revert R.InvalidScopedContentRoot();
        }
        StreamMetadataRenderer.requireValidUtf8ContentUri(
            "scopedContentRootURI", p.manifestURI, 2048, false
        );
        Route memory route = _route(ctx, p.scope);
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
        (S.Source memory source, S.Receipt memory receipt, S.Dependencies memory dependencies) =
            _snapshot(ctx, route, p);
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
        binding = _binding(dependencies, source, receipt);
        _schemas(dependencies, route.readGas);
        r.routeHash = route.hash;
        r.stateHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_SCOPED_POLICY_CONTENT_ROOT_STATE_V2"),
                block.chainid,
                address(this),
                ctx.core,
                r,
                binding
            )
        );
    }

    function _snapshot(Context memory ctx, Route memory route, R.Publication memory p)
        private
        view
        returns (S.Source memory source, S.Receipt memory receipt, S.Dependencies memory d)
    {
        SnapshotReads.Dependencies memory known = SnapshotReads.Dependencies(
            ctx.core,
            route.metadata,
            address(this),
            route.snapshots,
            ctx.core.codehash,
            route.metadata.codehash,
            address(this).codehash,
            route.snapshotCodeHash,
            block.chainid,
            route.readGas,
            route.validationGas
        );
        S.Publication memory publication;
        (publication, receipt) =
            SnapshotReads.original(known, p.scope, p.snapshotRecordHash, p.snapshotRevision);
        bytes memory raw = _read(
            route.snapshots,
            abi.encodeCall(
                Snap.requireCurrent, (p.scope, p.snapshotRecordHash, p.snapshotRevision)
            ),
            544,
            route.validationGas
        );
        _canonical(raw, abi.encode(receipt));
        raw = _read(route.snapshots, abi.encodeCall(Snap.dependencies, ()), 832, route.readGas);
        d = abi.decode(raw, (S.Dependencies));
        _canonical(raw, abi.encode(d));
        if (
            d.chainId != block.chainid || d.targets[0] != ctx.core || d.targets[1] != route.metadata
                || d.targets[4] != address(this)
        ) revert R.InvalidScopedContentRoot();
        for (uint256 i; i < d.targets.length; ++i) {
            _pin(d.targets[i], d.codeHashes[i]);
        }
        source = _payload(route, d, publication, receipt);
    }

    function _payload(
        Route memory route,
        S.Dependencies memory d,
        S.Publication memory originalPublication,
        S.Receipt memory receipt
    ) private view returns (S.Source memory source) {
        bytes memory out = StreamFinalityRouterEvidence.dynamicRead(
            route.snapshots,
            abi.encodeCall(Snap.snapshotPayload, (receipt.recordHash)),
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
        _canonical(raw, abi.encode(domain, chain, host, targets, pins, publication, fields, source));
        // The producer erases only these preview-circular fields from its retained payload.
        S.Publication memory expectedPublication =
            abi.decode(abi.encode(originalPublication), (S.Publication));
        expectedPublication.expectedSourceHash = 0;
        S.Receipt memory expectedReceipt = abi.decode(abi.encode(receipt), (S.Receipt));
        expectedReceipt.recordHash = 0;
        expectedReceipt.chainHash = 0;
        expectedReceipt.manifestHash = 0;
        expectedReceipt.manifestBytes = 0;
        expectedReceipt.recordedAt = 0;
        if (
            domain != keccak256("6529STREAM_SCOPED_POLICY_SNAPSHOT_PAYLOAD_V2")
                || chain != block.chainid || host != route.snapshots
                || keccak256(abi.encode(targets, pins))
                    != keccak256(abi.encode(d.targets, d.codeHashes))
                || keccak256(abi.encode(publication)) != keccak256(abi.encode(expectedPublication))
                || keccak256(abi.encode(fields)) != keccak256(abi.encode(expectedReceipt))
                || keccak256(abi.encode(source.scope))
                    != keccak256(abi.encode(originalPublication.scope))
                || receipt.sourceHash
                    != keccak256(
                        abi.encode(
                            keccak256("6529STREAM_SCOPED_POLICY_SNAPSHOT_SOURCES_V2"),
                            chain,
                            host,
                            targets,
                            pins,
                            source
                        )
                    ) || source.outputs.contentRoot == 0 || source.outputs.tokenCount == 0
                || source.outputs.manifestHash == 0 || source.outputs.outputRoot == 0
                || source.outputs.checkpointHash == 0 || source.outputs.checkpointStateHash == 0
                || source.outputs.entropySourceSet != d.targets[10]
                || source.outputs.inventoryHash == 0 || source.outputs.policyChainHash == 0
                || source.sourceFactory == address(0) || source.sourceFactoryCodeHash == 0
                || source.factoryDependenciesHash == 0
        ) {
            revert R.InvalidScopedContentRoot();
        }
        _pin(source.sourceFactory, source.sourceFactoryCodeHash);
        // requireCurrent has revalidated the actual factory, complete membership, every original
        // policy and complete output manifest. No terminal policy is relabeled finalized here.
    }

    function _binding(S.Dependencies memory d, S.Source memory source, S.Receipt memory receipt)
        private
        pure
        returns (V.Binding memory b)
    {
        b.profileId = Schemas.PROFILE;
        b.outputManifest = d.targets[8];
        b.outputManifestCodeHash = d.codeHashes[8];
        b.checkpoint = d.targets[7];
        b.checkpointCodeHash = d.codeHashes[7];
        b.checkpointHash = source.outputs.checkpointHash;
        b.checkpointStateHash = source.outputs.checkpointStateHash;
        b.entropySourceSet = d.targets[10];
        b.entropySourceSetCodeHash = d.codeHashes[10];
        b.inventoryHash = source.outputs.inventoryHash;
        b.policyChainHash = source.outputs.policyChainHash;
        b.outputRoot = source.outputs.outputRoot;
        b.outputSchemaHash = Schemas.definitionHash(OutputSchemas.SCHEMA);
        b.outputCanonicalizationHash = Schemas.definitionHash(OutputSchemas.CANON);
        b.leafSchemaHash = Schemas.definitionHash(OutputSchemas.LEAF_SCHEMA);
        b.rootSchemaHash = Schemas.definitionHash(Schemas.ROOT_SCHEMA);
        b.rootCanonicalizationHash = Schemas.definitionHash(Schemas.ROOT_CANON);
        b.sourceFactory = source.sourceFactory;
        b.sourceFactoryCodeHash = source.sourceFactoryCodeHash;
        b.factoryDependenciesHash = source.factoryDependenciesHash;
        b.snapshotSchemaHash = receipt.schemaHash;
        b.snapshotProfileHash = receipt.profileHash;
        b.snapshotCanonicalizationHash = receipt.canonicalizationHash;
    }

    function _schemas(S.Dependencies memory d, uint256 readGas) private view {
        Documents.Dependencies memory known;
        for (uint256 i; i < 4; ++i) {
            known.targets[i] = d.targets[i];
            known.codeHashes[i] = d.codeHashes[i];
        }
        known.chainId = d.chainId;
        known.readGas = readGas;
        bytes32[5] memory ids = [
            OutputSchemas.SCHEMA,
            OutputSchemas.CANON,
            OutputSchemas.LEAF_SCHEMA,
            Schemas.ROOT_SCHEMA,
            Schemas.ROOT_CANON
        ];
        for (uint256 i; i < ids.length; ++i) {
            bytes memory document = Schemas.document(ids[i]);
            Documents.definition(
                known,
                ids[i],
                (i == 1 || i == 4)
                    ? Schema.DocumentKind.CANONICALIZATION
                    : Schema.DocumentKind.SCHEMA,
                keccak256(document),
                document.length,
                keccak256("RAW_BYTES"),
                true
            );
        }
    }

    function _route(Context memory ctx, StreamFinalityScope memory scope)
        private
        view
        returns (Route memory r)
    {
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
        if (
            _word(
                        r.provider,
                        abi.encodeCall(IERC165.supportsInterface, (type(Provider).interfaceId)),
                        r.readGas
                    ) != 1
                || bytes32(
                        _word(
                            r.provider,
                            abi.encodeCall(Provider.scopedPolicySnapshotProfile, ()),
                            r.readGas
                        )
                    ) != SNAPSHOT_PROFILE
        ) revert R.InvalidScopedContentRoot();
        r.snapshots = _address(
            r.provider, abi.encodeCall(Provider.scopedPolicySnapshotHost, (scope)), r.readGas
        );
        r.snapshotCodeHash = bytes32(
            _word(
                r.provider,
                abi.encodeCall(Provider.scopedPolicySnapshotCodeHash, (scope)),
                r.readGas
            )
        );
        _pin(r.snapshots, r.snapshotCodeHash);
        r.validationGas = _word(
            r.provider,
            abi.encodeCall(Provider.scopedPolicySnapshotValidationGas, (scope)),
            r.readGas
        );
        if (
            r.validationGas < r.readGas || r.validationGas > type(uint32).max
                || _word(
                        r.snapshots,
                        abi.encodeCall(IERC165.supportsInterface, (type(Snap).interfaceId)),
                        r.readGas
                    ) != 1
                || bytes32(
                        _word(
                            r.snapshots,
                            abi.encodeCall(Snap.scopedPolicySnapshotProfile, ()),
                            r.readGas
                        )
                    ) != SNAPSHOT_PROFILE
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
                keccak256("6529STREAM_SCOPED_POLICY_CONTENT_ROOT_ROUTE_V2"),
                block.chainid,
                targets,
                hashes,
                r.metadata,
                r.metadata.codehash,
                scope
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

    function _canonical(bytes memory supplied, bytes memory expected) private pure {
        if (supplied.length != expected.length || keccak256(supplied) != keccak256(expected)) {
            revert R.InvalidScopedContentRoot();
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
