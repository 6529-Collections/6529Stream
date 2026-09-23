// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamViewRouteReadBudgetV1 as ViewBudget
} from "../finality/StreamViewRouteReadBudgetV1.sol";
import {
    IStreamScopedContentRootPublication as R
} from "../../interfaces/stream/metadata/IStreamScopedContentRootPublication.sol";
import {
    IStreamViewPreservationSnapshotPublicationV1 as Snap
} from "../../interfaces/stream/metadata/IStreamViewPreservationSnapshotPublicationV1.sol";
import {
    StreamViewPreservationSnapshotTypesV1 as S
} from "../../interfaces/stream/metadata/StreamViewPreservationSnapshotTypesV1.sol";
import "../../interfaces/stream/finality/IStreamViewPreservationEvidenceBindingV1.sol";
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

import {
    IStreamViewPreservationContentRootV1 as B
} from "../../interfaces/stream/metadata/IStreamViewPreservationContentRootV1.sol";
import {
    StreamFinalityViewPreservationSnapshotReadsV1 as Snapshot
} from "../finality/StreamFinalityViewPreservationSnapshotReadsV1.sol";
import {
    StreamViewPreservationContentDefinitionsV1 as Definitions
} from "../records/StreamViewPreservationContentDefinitionsV1.sol";
import {
    StreamViewPreservationSnapshotDefinitionsV1 as SnapshotDefinitions
} from "../records/StreamViewPreservationSnapshotDefinitionsV1.sol";
import {
    StreamViewPreservationOutputSchemasV1 as OutputDefinitions
} from "../finality/StreamViewPreservationOutputSchemasV1.sol";
import { StreamViewPolicyTypesV2 as Policy } from "./StreamViewPolicyTypesV2.sol";
import {
    StreamViewPreservationCheckpointTypesV1 as C
} from "../../interfaces/stream/finality/StreamViewPreservationCheckpointTypesV1.sol";
import {
    IStreamViewPreservationContentCheckpointV1 as Checkpoint
} from "../../interfaces/stream/finality/IStreamViewPreservationContentCheckpointV1.sol";
import { StreamWorkRecordContext as Documents } from "../records/StreamWorkRecordContext.sol";
import {
    IStreamSchemaRegistry as Schema
} from "../../interfaces/stream/metadata/IStreamSchemaRegistry.sol";
import { IERC165 } from "../../vendor/openzeppelin/IERC165.sol";

/// @notice Fixed source reads for the original Router's scoped CONTENT_ROOT write.
/// @dev Source selection belongs to the selected, pinned finality provider. This worker
/// neither consumes Artist consent nor writes an independent authority/replay map.
library StreamMetadataViewPreservationContentSourceV1 {
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
        returns (R.Record memory r, B.Binding memory binding)
    {
        bytes32 subject = StreamMetadataScopedContentState.viewSubject(ctx.core, p.scope);
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
        Snapshot.Dependencies memory d = Snapshot.Dependencies(
            ctx.core,
            route.metadata,
            route.snapshots,
            ctx.core.codehash,
            route.metadata.codehash,
            route.snapshotCodeHash,
            block.chainid,
            route.readGas,
            route.validationGas
        );
        Snapshot.Evidence memory evidence =
            Snapshot.requireCurrent(d, p.scope, p.snapshotRecordHash, p.snapshotRevision);
        S.Receipt memory receipt = evidence.receipt;
        S.Source memory source = evidence.source;
        S.Dependencies memory graph = abi.decode(
            _read(route.snapshots, abi.encodeCall(Snap.dependencies, ()), 768, route.readGas),
            (S.Dependencies)
        );
        if (
            graph.targets[4] != address(this) || graph.codeHashes[4] != address(this).codehash
                || source.adoption.adoption.source.route.router != address(this)
                || source.adoption.adoption.source.route.artist != ctx.artist
                || source.adoption.adoption.source.route.artistCodeHash != ctx.artist.codehash
        ) {
            revert R.InvalidScopedContentRoot();
        }
        binding = _binding(route, graph, source);
        _definitions(graph);
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
        r.contentRoot = source.outputs.header.contentRoot;
        r.leafCount = source.outputs.header.tokenCount;
        r.outputManifestHash = source.outputs.carrier.contentHash;
        r.artistId = artistId;
        r.bindingGeneration = generation;
        r.bindingHash = bindingHash;
        r.publisher = publisher;
        (r.authorizationClass, r.grantRevision) = _authority(route, p.scope.collectionId, publisher);
        r.routeHash = route.hash;
        r.stateHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_VIEW_PRESERVATION_CONTENT_ROOT_STATE_V1"),
                block.chainid,
                address(this),
                ctx.core,
                r,
                binding
            )
        );
    }

    function _binding(Route memory route, S.Dependencies memory d, S.Source memory f)
        private
        view
        returns (B.Binding memory b)
    {
        C.Configuration memory c = abi.decode(
            _read(d.targets[6], abi.encodeCall(Checkpoint.configuration, ()), 384, route.readGas),
            (C.Configuration)
        );
        b.profileId = Definitions.PROFILE;
        b.outputProfile = C.OUTPUT_PROFILE;
        b.adoptionRecord = f.adoption.adoption.recordHash;
        b.adoptionProfile = Policy.PROFILE;
        b.membershipHash = f.membership.membershipHash;
        b.policyChainHash = f.entropy.policyChainHash;
        b.checkpoint = d.targets[6];
        b.checkpointCodeHash = d.codeHashes[6];
        b.checkpointRecord = f.outputs.header.checkpointId;
        b.checkpointStateHash = f.outputs.header.checkpointStateHash;
        b.outputManifest = d.targets[7];
        b.outputManifestCodeHash = d.codeHashes[7];
        b.outputManifestRecord = f.outputs.recordHash;
        b.manifestIndexHash = f.outputs.carrier.contentHash;
        b.partChain = f.outputs.partChain;
        b.preservationRenderer = c.serving;
        b.preservationRendererCodeHash = c.servingCodeHash;
        b.preservationConfigurationHash = c.servingConfigurationHash;
        b.liveRenderer = f.adoption.preservation.liveRenderer;
        b.liveRendererCodeHash = f.adoption.preservation.liveRendererRuntimeHash;
        b.preservationAttribution = f.adoption.preservation.preservationAttribution;
        b.preservationAttributionCodeHash =
        f.adoption.preservation.preservationAttributionRuntimeHash;
        b.leafSchemaHash = keccak256(OutputDefinitions.document(OutputDefinitions.LEAF));
        b.rootSchemaHash = Definitions.SCHEMA_HASH;
        b.rootCanonicalizationHash = Definitions.CANON_HASH;
        b.snapshotSchemaHash = SnapshotDefinitions.SCHEMA_HASH;
        b.snapshotProfileHash = SnapshotDefinitions.PROFILE_HASH;
        b.snapshotCanonicalizationHash = SnapshotDefinitions.CANON_HASH;
    }

    function _definitions(S.Dependencies memory d) private view {
        Documents.Dependencies memory known;
        for (uint256 i; i < 4; ++i) {
            known.targets[i] = d.targets[i];
            known.codeHashes[i] = d.codeHashes[i];
        }
        known.chainId = d.chainId;
        known.readGas = d.readGas;
        Documents.definition(
            known,
            Definitions.SCHEMA_ID,
            Schema.DocumentKind.SCHEMA,
            Definitions.SCHEMA_HASH,
            Definitions.SCHEMA_BYTES,
            keccak256("RAW_BYTES"),
            true
        );
        Documents.definition(
            known,
            Definitions.CANON_ID,
            Schema.DocumentKind.CANONICALIZATION,
            Definitions.CANON_HASH,
            Definitions.CANON_BYTES,
            keccak256("RAW_BYTES"),
            true
        );
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
        (r.readGas,) = ViewBudget.select(r.finality, r.readGas);
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
                    abi.encodeCall(
                        IERC165.supportsInterface,
                        (type(IStreamViewPreservationEvidenceBindingV1).interfaceId)
                    ),
                    r.readGas
                ) != 1
        ) revert R.InvalidScopedContentRoot();
        r.snapshots = _address(
            r.provider,
            abi.encodeCall(
                IStreamViewPreservationEvidenceBindingV1.viewPreservationSnapshotHost, ()
            ),
            r.readGas
        );
        r.snapshotCodeHash = bytes32(
            _word(
                r.provider,
                abi.encodeCall(
                    IStreamViewPreservationEvidenceBindingV1.viewPreservationSnapshotCodeHash, ()
                ),
                r.readGas
            )
        );
        _pin(r.snapshots, r.snapshotCodeHash);
        r.validationGas = _word(
            r.provider,
            abi.encodeCall(
                IStreamViewPreservationEvidenceBindingV1.viewPreservationSnapshotValidationGas, ()
            ),
            r.readGas
        );
        if (
            r.validationGas < r.readGas || r.validationGas > 16777216
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
                keccak256("6529STREAM_VIEW_PRESERVATION_CONTENT_ROOT_ROUTE_V1"),
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
