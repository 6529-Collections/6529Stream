// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    PreservationPolicyContentFixtureV1,
    PreservationOutputBoundary
} from "../finality/StreamPreservationPolicyContentCheckpointV1.t.sol";
import { StaticRouteVm } from "../../helpers/StaticMetadataRoutingFixture.sol";
import { OfficialSafe } from "../../helpers/OfficialSafeFixture.sol";
import { Vm } from "../../regression/legacy/helpers/CharacterizationTestBase.sol";
import {
    LeafManifestArchiveBoundary,
    LeafManifestFinalityBoundary,
    LeafManifestVm
} from "../finality/StreamContentLeafManifest.t.sol";
import {
    StreamPreservationPolicySnapshotPublicationV1 as Snapshot
} from "../../../smart-contracts/domains/metadata/StreamPreservationPolicySnapshotPublicationV1.sol";
import {
    StreamPreservationPolicySnapshotTypesV1 as Snap
} from "../../../smart-contracts/interfaces/stream/metadata/StreamPreservationPolicySnapshotTypesV1.sol";
import {
    IStreamPreservationPolicySnapshotPublicationV1 as SnapshotInterface
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamPreservationPolicySnapshotPublicationV1.sol";
import {
    IStreamScopedPolicySnapshotPublicationV2 as OldPolicySnapshot
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamScopedPolicySnapshotPublicationV2.sol";
import {
    IStreamScopedSnapshotPublication as OriginalScopedSnapshot
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamScopedSnapshotPublication.sol";
import {
    IStreamPolicySnapshotPublicationV2 as CollectionPolicySnapshot
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamPolicySnapshotPublicationV2.sol";
import {
    IStreamPreservationPolicyContentCheckpointV1 as Content
} from "../../../smart-contracts/interfaces/stream/finality/IStreamPreservationPolicyContentCheckpointV1.sol";
import {
    StreamPreservationPolicyOutputTypesV1 as PreservationTypes
} from "../../../smart-contracts/interfaces/stream/finality/StreamPreservationPolicyOutputTypesV1.sol";
import {
    StreamPreservationPolicyOutputManifestV1 as OutputHost
} from "../../../smart-contracts/domains/finality/StreamPreservationPolicyOutputManifestV1.sol";
import {
    IStreamPreservationPolicyOutputManifestV1 as Outputs
} from "../../../smart-contracts/interfaces/stream/finality/IStreamPreservationPolicyOutputManifestV1.sol";
import {
    StreamPreservationPolicyOutputSchemasV1 as OutputDocuments
} from "../../../smart-contracts/domains/finality/StreamPreservationPolicyOutputSchemasV1.sol";
import {
    StreamFinalityArtifactCoverage
} from "../../../smart-contracts/domains/preservation/StreamFinalityArtifactCoverage.sol";
import {
    StreamFinalityArtifactTypes as Artifacts
} from "../../../smart-contracts/interfaces/stream/preservation/StreamFinalityArtifactTypes.sol";
import {
    StreamSchemaDocumentStore
} from "../../../smart-contracts/domains/metadata/StreamSchemaDocumentStore.sol";
import {
    IStreamSchemaRegistry as Schema
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamSchemaRegistry.sol";
import {
    IStreamMetadataServingFacts as Serving
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamMetadataServingFacts.sol";
import {
    IStreamMetadataRouter
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamMetadataRouter.sol";
import {
    IStreamCorePointers
} from "../../../smart-contracts/interfaces/stream/core/IStreamCorePointers.sol";
import {
    IStreamGasParameterHost as Gas
} from "../../../smart-contracts/interfaces/stream/parameters/IStreamGasParameterHost.sol";
import {
    IStreamFinalityEntropyPolicySourceSet as SourceSet
} from "../../../smart-contracts/interfaces/stream/finality/IStreamFinalityEntropyPolicySourceSet.sol";
import {
    IStreamEntropyCollectionPolicy as EntropyPolicy
} from "../../../smart-contracts/interfaces/stream/entropy/IStreamEntropyCollectionPolicy.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType
} from "../../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import {
    StreamRecordFamilies as Families
} from "../../../smart-contracts/domains/records/StreamRecordFamilies.sol";
import {
    StreamPreservationPolicySnapshotDefinitionsV1 as SnapshotDocuments
} from "../../../smart-contracts/domains/records/StreamPreservationPolicySnapshotDefinitionsV1.sol";
import {
    IStreamFinalityEntropySourceFactory as FactoryReads
} from "../../../smart-contracts/interfaces/stream/finality/IStreamFinalityEntropySourceFactory.sol";
import {
    IStreamFinalityScopeMembership as MembershipReads
} from "../../../smart-contracts/interfaces/stream/finality/IStreamFinalityScopeMembership.sol";
import {
    StreamScopeMembershipFacts
} from "../../../smart-contracts/interfaces/stream/finality/StreamScopeMembershipTypes.sol";

import {
    IStreamContentRootPublication as Root
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamContentRootPublication.sol";
import {
    IStreamPreservationPolicyContentRootPublicationV1 as RootProfile
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamPreservationPolicyContentRootPublicationV1.sol";
import {
    StreamPreservationPolicyContentRootSchemasV1 as RootDocuments
} from "../../../smart-contracts/domains/finality/StreamPreservationPolicyContentRootSchemasV1.sol";
import {
    IERC165 as SnapshotERC165
} from "../../../smart-contracts/vendor/openzeppelin/IERC165.sol";

/// @notice Actual complete mixed original policies, membership, selection, preservation checkpoint,
/// covered output manifest, snapshot, Metadata grants, Schema/Store and threshold Safe.
/// @dev Inherited Core/Artist/module/producer/admission and archive-family boundaries remain explicit.
/// A canonical prior Router root and locked Artist presentation are supplied as named typed read
/// boundaries. This suite checks their exact original record/binding joins; it does not execute
/// Artist operation17 or root adoption, certify ADR0054 projection, or claim full finality/gas acceptance.
abstract contract PreservationSnapshotFixtureV1 is PreservationPolicyContentFixtureV1 {
    bytes32 internal constant SNAPSHOT_ARTIST =
        keccak256("collection preservation snapshot artist boundary");
    StaticRouteVm internal constant snapshotVm = StaticRouteVm(address(vm));
    LeafManifestVm internal constant createVm = LeafManifestVm(address(vm));
    StreamSchemaDocumentStore internal snapshotStore;
    StreamFinalityArtifactCoverage internal snapshotCoverage;
    LeafManifestArchiveBoundary internal snapshotArchive;
    Content internal snapshotContent;
    OutputHost internal snapshotOutputs;
    Snapshot internal snapshotHost;
    Snap.Publication internal publication;
    Serving.ArtistPresentation internal lockedArtistBoundary;
    Capture internal snapshotCapture;
    Root.Record internal canonicalRoot;
    RootProfile.Binding internal rootBinding;

    function _initialize() internal {
        _scopedFixture(1, true);
        snapshotStore = StreamSchemaDocumentStore(schemas.chunkStore());
        _register(
            "STREAM_PRESERVATION_POLICY_OUTPUT_MANIFEST_V1",
            Schema.DocumentKind.SCHEMA,
            OutputDocuments.document(OutputDocuments.SCHEMA)
        );
        _register(
            "STREAM_ABI_PRESERVATION_POLICY_OUTPUT_MANIFEST_V1",
            Schema.DocumentKind.CANONICALIZATION,
            OutputDocuments.document(OutputDocuments.CANON)
        );
        string[3] memory names = [
            "STREAM_PRESERVATION_POLICY_COLLECTION_SNAPSHOT_ABI_V1",
            "STREAM_PRESERVATION_POLICY_COLLECTION_SNAPSHOT_PROFILE_V1",
            "STREAM_ABI_PRESERVATION_POLICY_COLLECTION_SNAPSHOT_V1"
        ];
        string[3] memory paths = [
            "docs/schemas/preservation/preservation-policy-collection-snapshot-v1.schema.json",
            "docs/schemas/preservation/preservation-policy-collection-snapshot-v1.profile.json",
            "docs/schemas/preservation/preservation-policy-collection-snapshot-v1.abi.json"
        ];
        for (uint256 i; i < 3; ++i) {
            _register(
                names[i],
                i == 0
                    ? Schema.DocumentKind.SCHEMA
                    : i == 1 ? Schema.DocumentKind.CATALOG : Schema.DocumentKind.CANONICALIZATION,
                bytes(vm.readFile(paths[i]))
            );
        }
        _register(
            "STREAM_PRESERVATION_POLICY_CONTENT_ROOT_RECORD_V1",
            Schema.DocumentKind.SCHEMA,
            RootDocuments.document(RootDocuments.ROOT_SCHEMA)
        );
        _register(
            "STREAM_ABI_PRESERVATION_POLICY_CONTENT_ROOT_RECORD_V1",
            Schema.DocumentKind.CANONICALIZATION,
            RootDocuments.document(RootDocuments.ROOT_CANON)
        );
        _register(
            "STREAM_PRESERVATION_POLICY_TOKEN_CONTENT_LEAF_V1",
            Schema.DocumentKind.SCHEMA,
            OutputDocuments.document(OutputDocuments.LEAF_SCHEMA)
        );
        _familyGrant(1, Families.SNAPSHOT, 7, address(this), true);
        _familyGrant(1, Families.IDENTITY, 7, address(this), true);
        // Explicitly extend the fixture's typed module admission to the genuine Router.
        snapshotVm.mockCall(
            address(scopedModules),
            abi.encodeWithSignature(
                "isModuleEligible(address,bytes32,bytes4)",
                address(router),
                keccak256("METADATA_ROUTER"),
                type(IStreamMetadataRouter).interfaceId
            ),
            abi.encode(true)
        );
        lockedArtistBoundary = Serving.ArtistPresentation(
            true,
            address(artist),
            address(artist).codehash,
            SNAPSHOT_ARTIST,
            1,
            keccak256("locked Artist binding boundary"),
            address(0xA11CE),
            keccak256("locked Artist identity boundary"),
            keccak256("locked Artist acceptance boundary"),
            900,
            950,
            keccak256("locked Artist presentation boundary")
        );
        _setLockedArtistBoundary();
        snapshotArchive = new LeafManifestArchiveBoundary(address(core), address(executor));
        address predicted = createVm.computeCreateAddress(
            address(this), uint256(createVm.getNonce(address(this))) + 1
        );
        snapshotCoverage = new StreamFinalityArtifactCoverage(
            address(core),
            address(snapshotArchive),
            address(schemas),
            address(snapshotStore),
            predicted,
            address(executor),
            Gas.GasParameterConfig("FINALITY_ARTIFACT_DEPENDENCY_READ_GAS", 300000, 300000, 2)
        );
        address finality =
            address(new LeafManifestFinalityBoundary(address(core), address(snapshotCoverage)));
        require(finality == predicted);
        snapshotVm.mockCall(
            address(core),
            abi.encodeCall(
                IStreamCorePointers.getSatellitePointer, (keccak256("ARTWORK_FINALITY_REGISTRY"))
            ),
            abi.encode(
                finality,
                finality.codehash,
                false,
                keccak256("ARTWORK_FINALITY_REGISTRY"),
                bytes4(0),
                address(0),
                uint8(1),
                bytes32(0),
                bytes32(0),
                uint64(1)
            )
        );
    }

    function _prepare() internal {
        StreamFinalityScope memory scope =
            StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0);
        Capture memory c = _capture(scope, true);
        snapshotCapture = c;
        snapshotContent = Content(address(c.host));
        snapshotContent.append(c.id, _payload(c));
        Content.Plan memory p = snapshotContent.requireCurrentCheckpoint(c.id);
        Content.Output[] memory rows = new Content.Output[](p.tokenCount);
        for (uint256 i; i < rows.length; ++i) {
            rows[i] = snapshotContent.outputAt(c.id, i);
        }
        bytes memory raw = abi.encode(
            OutputDocuments.SCHEMA,
            block.chainid,
            address(core),
            address(snapshotContent),
            c.id,
            keccak256(abi.encode(p)),
            snapshotContent.entropySourceSet(),
            p.inventoryHash,
            p.policyChainHash,
            address(router),
            p.preservationProfile,
            p.scope,
            p.contentRoot,
            p.outputRoot,
            p.tokenCount,
            rows
        );
        require(raw.length == 640 + 1152 * p.tokenCount);
        (bytes32 artifact, bytes32 coverage) = _archive(raw);
        snapshotOutputs = new OutputHost(
            address(core),
            address(snapshotContent),
            address(snapshotCoverage),
            address(executor),
            Gas.GasParameterConfig("STATIC_OUTPUT_MANIFEST_READ_GAS", 32000000, 100000, 2)
        );
        bytes32 plan = snapshotOutputs.beginManifest(c.id, artifact, coverage, SNAPSHOT_ARTIST);
        bytes32 output = snapshotOutputs.verifyNextOutputs(plan, p.tokenCount);
        require(output != 0 && snapshotOutputs.schemaRegistry() == address(schemas));
        Snap.Dependencies memory d;
        d.targets = [
            address(core),
            address(metadata),
            address(schemas),
            address(snapshotStore),
            address(router),
            address(scopedMembership),
            address(scopedSelections),
            address(snapshotContent),
            address(snapshotOutputs),
            address(snapshotCoverage),
            snapshotContent.entropySourceSet()
        ];
        for (uint256 i; i < d.targets.length; ++i) {
            d.codeHashes[i] = d.targets[i].codehash;
        }
        d.chainId = block.chainid;
        snapshotHost = new Snapshot(d, address(executor), _snapshotGas());
        publication = Snap.Publication(
            scope,
            keccak256("collection preservation snapshot"),
            0,
            0,
            output,
            bytes32(0),
            SourceSet(d.targets[10]).inventoryPlan(),
            0,
            "ipfs://collection-preservation-policy-snapshot",
            1000,
            keccak256("complete original native policies and admitted preservation output")
        );
        _rootFromOutputs(output);
    }

    function _snapshotGas() internal pure returns (Gas.GasParameterConfig[3] memory configs) {
        // Reserve genuine nested checkpoint/render reads; these caps are not a gas acceptance claim.
        configs[0] = Gas.GasParameterConfig("POLICY_SNAPSHOT_READ_GAS", 2000000, 50000, 2);
        configs[1] = Gas.GasParameterConfig("POLICY_SNAPSHOT_SOURCE_GAS", 64000000, 50000, 2);
        configs[2] = Gas.GasParameterConfig("POLICY_SNAPSHOT_INVENTORY_GAS", 8000000, 50000, 2);
    }

    function _setLockedArtistBoundary() internal {
        snapshotVm.mockCall(
            address(router),
            abi.encodeCall(Serving.artistPresentation, (uint256(1))),
            abi.encode(lockedArtistBoundary)
        );
    }

    function _lockAction(uint8 cls, bytes32 scope, bytes32 oldState, bytes32 next) internal {
        snapshotVm.mockCall(
            address(executor),
            abi.encodeWithSignature("currentAction()"),
            abi.encode(true, keccak256("exact class two snapshot lock"), cls, scope, oldState, next)
        );
    }

    function _familyGrant(
        uint256 collection,
        bytes32 family,
        uint8 cls,
        address account,
        bool enabled
    ) internal {
        (bytes32 scope, bytes32 old, bytes32 next) = metadata.familyWriterTransition(
            collection, family, cls, account, enabled
        );
        executor.execute(
            address(metadata),
            abi.encodeCall(metadata.setFamilyWriter, (collection, family, cls, account, enabled)),
            scope,
            old,
            next
        );
    }

    function _preview(address publisher) internal returns (bytes memory raw) {
        (bytes32 source, bytes memory canonical) =
            snapshotHost.previewSnapshot(publication, publisher);
        publication.expectedSourceHash = source;
        return canonical;
    }

    function _publish() internal returns (bytes32) {
        _upload(_preview(address(this)), false);
        return snapshotHost.publishSnapshot(publication);
    }

    function _upload(bytes memory raw, bool omitLast) internal {
        uint256 count = (raw.length + 8191) / 8192;
        for (uint256 i; i < count - (omitLast ? 1 : 0); ++i) {
            snapshotStore.publishChunk(_chunk(raw, i));
        }
    }

    function _archive(bytes memory raw) internal returns (bytes32 artifact, bytes32 coverage) {
        Artifacts.Artifact memory a;
        a.artistId = SNAPSHOT_ARTIST;
        a.schemaId = OutputDocuments.SCHEMA;
        a.canonicalizationId = OutputDocuments.CANON;
        a.hashAlgorithm = 1;
        a.contentHash = keccak256(raw);
        a.byteLength = uint64(raw.length);
        uint256 count = (raw.length + 8191) / 8192;
        a.chunkHashes = new bytes32[](count);
        a.chunkLengths = new uint32[](count);
        for (uint256 i; i < count; ++i) {
            bytes memory part = _chunk(raw, i);
            address pointer;
            (a.chunkHashes[i], pointer) = snapshotStore.publishChunk(part);
            a.chunkLengths[i] = uint32(part.length);
            snapshotArchive.add(a.chunkHashes[i], pointer);
        }
        artifact = snapshotCoverage.recordArtifact(a);
        bytes32 plan = snapshotCoverage.beginCoverage(
            artifact, keccak256("archive family A"), keccak256("archive family B")
        );
        for (uint32 i; i < count; ++i) {
            coverage = snapshotCoverage.coverNextChunk(plan, i, a.chunkHashes[i]);
        }
    }

    function _register(string memory name, Schema.DocumentKind kind, bytes memory raw) internal {
        bytes32[] memory chunks = new bytes32[]((raw.length + 8191) / 8192);
        for (uint256 i; i < chunks.length; ++i) {
            (chunks[i],) = snapshotStore.publishChunk(_chunk(raw, i));
        }
        Schema.DocumentSpec memory spec = Schema.DocumentSpec(
            name, kind, keccak256(raw), schemas.RAW_BYTES(), 0, "", uint32(raw.length)
        );
        (bytes32 scope, bytes32 old, bytes32 next) = schemas.registrationTransition(spec, chunks);
        executor.execute(
            address(schemas),
            abi.encodeCall(schemas.registerDocument, (spec, chunks)),
            scope,
            old,
            next
        );
    }

    function _chunk(bytes memory raw, uint256 index) internal pure returns (bytes memory part) {
        uint256 take = raw.length - index * 8192;
        if (take > 8192) take = 8192;
        part = new bytes(take);
        for (uint256 i; i < take; ++i) {
            part[i] = raw[index * 8192 + i];
        }
    }

    function _rootFromOutputs(bytes32 output) internal {
        Outputs.Manifest memory m = snapshotOutputs.manifestRecord(output);
        canonicalRoot.publication =
            Root.Publication(1, 0, output, "ipfs://original-preservation-root");
        canonicalRoot.contentRoot = m.contentRoot;
        canonicalRoot.leafCount = m.tokenCount;
        canonicalRoot.manifestHash = m.manifestHash;
        canonicalRoot.artistId = SNAPSHOT_ARTIST;
        canonicalRoot.bindingGeneration = lockedArtistBoundary.bindingGeneration;
        canonicalRoot.bindingHash = lockedArtistBoundary.bindingHash;
        canonicalRoot.publisher = address(this);
        canonicalRoot.authorizationClass = 7;
        canonicalRoot.grantRevision = 1;
        canonicalRoot.routeHash = keccak256("original root route boundary");
        canonicalRoot.stateHash = keccak256("original Artist approved family state boundary");
        canonicalRoot.artistConsent = keccak256("original Artist operation17 receipt boundary");
        canonicalRoot.publishedAt = 1000;
        rootBinding = RootProfile.Binding(
            keccak256("6529STREAM_PRESERVATION_POLICY_CONTENT_V1"),
            address(snapshotOutputs),
            address(snapshotOutputs).codehash,
            address(snapshotContent),
            address(snapshotContent).codehash,
            m.checkpointHash,
            m.checkpointStateHash,
            m.entropySourceSet,
            m.entropySourceSet.codehash,
            m.inventoryHash,
            m.policyChainHash,
            m.outputRoot,
            RootDocuments.definitionHash(OutputDocuments.SCHEMA),
            RootDocuments.definitionHash(OutputDocuments.CANON),
            RootDocuments.definitionHash(OutputDocuments.LEAF_SCHEMA),
            RootDocuments.definitionHash(RootDocuments.ROOT_SCHEMA),
            RootDocuments.definitionHash(RootDocuments.ROOT_CANON),
            address(router),
            keccak256("6529STREAM_PRESERVATION_RENDER_V1")
        );
        _refreshRoot();
    }

    function _refreshRoot() internal {
        publication.contentRootRecord = keccak256(
            abi.encode(
                keccak256("6529STREAM_PRESERVATION_POLICY_CONTENT_ROOT_RECORD_V1"),
                block.chainid,
                address(router),
                canonicalRoot,
                rootBinding
            )
        );
        snapshotVm.mockCall(
            address(router),
            abi.encodeCall(Root.collectionContentRootHead, (uint256(1))),
            abi.encode(publication.contentRootRecord)
        );
        snapshotVm.mockCall(
            address(router),
            abi.encodeCall(Root.contentRootRecord, (publication.contentRootRecord)),
            abi.encode(canonicalRoot)
        );
        snapshotVm.mockCall(
            address(router),
            abi.encodeCall(
                RootProfile.preservationPolicyContentRootBinding, (publication.contentRootRecord)
            ),
            abi.encode(rootBinding)
        );
    }

    function _source(bytes memory raw) internal pure returns (Snap.Source memory f) {
        (,,,,,,, f) = abi.decode(
            raw,
            (
                bytes32,
                uint256,
                address,
                address[11],
                bytes32[11],
                Snap.Publication,
                Snap.Receipt,
                Snap.Source
            )
        );
    }

    function _historyHash(bytes32 hash) internal view returns (bytes32) {
        (Snap.Publication memory p, Snap.Receipt memory r) = snapshotHost.snapshotRecord(hash);
        return keccak256(abi.encode(p, r, snapshotHost.snapshotPayload(hash)));
    }

    function _ready() internal {
        _initialize();
        _prepare();
        snapshotHost.previewSnapshot(publication, address(this));
    }
}

contract StreamPreservationPolicySnapshotPublicationV1Test is PreservationSnapshotFixtureV1 {
    function testCollectionPreservationCompleteMixedPolicySourceAndLiteralRootPayload() public {
        _ready();
        bytes memory raw = _preview(address(this));
        Snap.Source memory f = _source(raw);
        require(
            f.membership.tokenCount == 2 && f.selection.nextIndex == 2 && f.content.nextIndex == 2
                && f.outputs.tokenCount == 2
        );
        require(f.entropy.policies.length == 2 && f.entropy.policyCount == 2 && f.entropy.allFrozen);
        require(snapshotContent.outputAt(f.outputs.checkpointHash, 0).entropy.terminal);
        require(snapshotContent.outputAt(f.outputs.checkpointHash, 1).entropy.finalized);
        require(
            snapshotContent.outputAt(f.outputs.checkpointHash, 0).preservation.producer
                != snapshotContent.outputAt(f.outputs.checkpointHash, 1).preservation.producer
        );
        require(
            abi.encode(f.content).length == 448 && abi.encode(f.outputs).length == 608
                && abi.encode(f.rootBinding).length == 608
        );
        require(
            f.rootBinding.metadataRouter == address(router)
                && f.rootBinding.preservationOutputProfile == f.content.preservationProfile
        );
        require(
            f.rootBinding.outputRoot == f.content.outputRoot
                && f.root.artistConsent == canonicalRoot.artistConsent
        );
        require(
            keccak256(
                abi.encode(
                    keccak256("6529STREAM_PRESERVATION_POLICY_CONTENT_ROOT_RECORD_V1"),
                    block.chainid,
                    address(router),
                    f.root,
                    f.rootBinding
                )
            ) == publication.contentRootRecord
        );
        require(
            snapshotHost.preservationPolicySnapshotProfile()
                == keccak256("6529STREAM_PRESERVATION_POLICY_SNAPSHOT_V1")
        );
        require(snapshotHost.supportsInterface(type(SnapshotInterface).interfaceId));
        require(!snapshotHost.supportsInterface(type(CollectionPolicySnapshot).interfaceId));
        _upload(raw, false);
        bytes32 hash = snapshotHost.publishSnapshot(publication);
        Snap.Receipt memory r = snapshotHost.requireCurrent(publication.scope, hash, 1);
        require(keccak256(snapshotHost.snapshotPayload(hash)) == keccak256(raw));
        (
            bytes32 domain,
            uint256 chain,
            address producer,
            address[11] memory targets,
            bytes32[11] memory pins,
            Snap.Publication memory p,
            Snap.Receipt memory normalized,
        ) = abi.decode(
            raw,
            (
                bytes32,
                uint256,
                address,
                address[11],
                bytes32[11],
                Snap.Publication,
                Snap.Receipt,
                Snap.Source
            )
        );
        require(
            domain == keccak256("6529STREAM_PRESERVATION_POLICY_SNAPSHOT_PAYLOAD_V1")
                && chain == block.chainid && producer == address(snapshotHost)
        );
        require(
            p.expectedSourceHash == 0 && normalized.recordHash == 0 && normalized.chainHash == 0
                && normalized.manifestHash == 0 && normalized.manifestBytes == 0
                && normalized.recordedAt == 0
        );
        require(
            normalized.sourceHash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_PRESERVATION_POLICY_SNAPSHOT_SOURCES_V1"),
                        chain,
                        producer,
                        targets,
                        pins,
                        f
                    )
                )
        );
        require(r.sourceHash == normalized.sourceHash && r.manifestHash == keccak256(raw));
        bytes32 originalChain = r.chainHash;
        r.recordHash = 0;
        r.chainHash = 0;
        require(
            hash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_PRESERVATION_POLICY_SNAPSHOT_RECORD_V1"),
                        chain,
                        producer,
                        address(core),
                        address(metadata),
                        publication,
                        r
                    )
                )
        );
        require(
            originalChain
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_PRESERVATION_POLICY_SNAPSHOT_CHAIN_V1"),
                        chain,
                        producer,
                        address(core),
                        publication.scope,
                        bytes32(0),
                        uint64(1),
                        hash
                    )
                )
        );
    }

    function testCollectionPreservationAllNineteenRootBindingWordsAreAuthenticated() public {
        _ready();
        bytes memory canonical = abi.encode(rootBinding);
        bytes32 original = publication.contentRootRecord;
        for (uint256 i; i < 19; ++i) {
            bytes memory corrupt = abi.encode(rootBinding);
            // Flip the low byte; addresses retain canonical padding, reaching the semantic join.
            corrupt[i * 32 + 31] = bytes1(uint8(corrupt[i * 32 + 31]) ^ uint8(1));
            rootBinding = abi.decode(corrupt, (RootProfile.Binding));
            _refreshRoot();
            vm.expectRevert(abi.encodeWithSelector(Snap.InvalidPolicySnapshot.selector));
            snapshotHost.previewSnapshot(publication, address(this));
            rootBinding = abi.decode(canonical, (RootProfile.Binding));
            _refreshRoot();
            require(publication.contentRootRecord == original);
            snapshotHost.previewSnapshot(publication, address(this));
        }
    }

    function testCollectionPreservationRootAuthorityFieldsAndRecordPreimageAreNotOptional() public {
        _ready();
        Root.Record memory saved = abi.decode(abi.encode(canonicalRoot), (Root.Record));
        for (uint256 i; i < 6; ++i) {
            if (i == 0) {
                canonicalRoot.artistConsent = 0;
            } else if (i == 1) {
                canonicalRoot.authorizationClass = 2;
            } else if (i == 2) {
                canonicalRoot.bindingGeneration += 1;
            } else if (i == 3) {
                canonicalRoot.publication.verifiedManifestRecordHash = keccak256("foreign output");
            } else if (i == 4) {
                canonicalRoot.publisher = address(0);
            } else {
                canonicalRoot.routeHash = 0;
            }
            _refreshRoot();
            vm.expectRevert(abi.encodeWithSelector(Snap.InvalidPolicySnapshot.selector));
            snapshotHost.previewSnapshot(publication, address(this));
            canonicalRoot = abi.decode(abi.encode(saved), (Root.Record));
            _refreshRoot();
        }
        snapshotVm.mockCall(
            address(router),
            abi.encodeCall(Root.contentRootRecord, (publication.contentRootRecord)),
            abi.encode(abi.decode(abi.encode(saved), (Root.Record)))
        );
        canonicalRoot.stateHash = keccak256("different original family preimage");
        // Change only retained body under the original key: no fabricated matching record hash.
        snapshotVm.mockCall(
            address(router),
            abi.encodeCall(Root.contentRootRecord, (publication.contentRootRecord)),
            abi.encode(canonicalRoot)
        );
        vm.expectRevert(abi.encodeWithSelector(Snap.InvalidPolicySnapshot.selector));
        snapshotHost.previewSnapshot(publication, address(this));
        canonicalRoot = saved;
        _refreshRoot();
        snapshotHost.previewSnapshot(publication, address(this));
    }

    function testCollectionPreservationOldProfileAndWrongScopeFailBeforePublication() public {
        _ready();
        for (uint8 kind = 1; kind <= 4; ++kind) {
            Snap.Publication memory p = abi.decode(abi.encode(publication), (Snap.Publication));
            p.scope.scopeType = StreamFinalityScopeType(kind);
            p.scope.tokenId = kind == 1 ? 91 : 0;
            p.scope.scopeId = kind > 1 ? keccak256("other scope") : bytes32(0);
            vm.expectRevert(abi.encodeWithSelector(Snap.InvalidPolicySnapshot.selector));
            snapshotHost.previewSnapshot(p, address(this));
        }
        bytes memory key = abi.encodeWithSignature("preservationPolicyProfile()");
        snapshotVm.mockCall(
            address(snapshotContent),
            key,
            abi.encode(keccak256("6529STREAM_POLICY_CURRENT_FULL_CONTENT_V2"))
        );
        vm.expectRevert(abi.encodeWithSelector(Snap.InvalidPolicySnapshot.selector));
        snapshotHost.previewSnapshot(publication, address(this));
        snapshotVm.mockCall(
            address(snapshotContent),
            key,
            abi.encode(keccak256("6529STREAM_PRESERVATION_POLICY_CONTENT_V1"))
        );
        snapshotHost.previewSnapshot(publication, address(this));
        rootBinding.profileId = keccak256("6529STREAM_POLICY_CURRENT_FULL_CONTENT_V2");
        _refreshRoot();
        vm.expectRevert(abi.encodeWithSelector(Snap.InvalidPolicySnapshot.selector));
        snapshotHost.previewSnapshot(publication, address(this));
    }

    function testCollectionPreservationBothGrantsGlobalFallbackAndExpectedSourceAreExact() public {
        _ready();
        _familyGrant(1, Families.SNAPSHOT, 7, address(this), false);
        vm.expectRevert(
            abi.encodeWithSelector(Snap.PolicySnapshotAuthority.selector, address(this))
        );
        snapshotHost.previewSnapshot(publication, address(this));
        _familyGrant(1, Families.SNAPSHOT, 7, address(this), true);
        _familyGrant(1, Families.IDENTITY, 7, address(this), false);
        // Inherited fixture owns a real global identity writer; revoke it to isolate this family.
        _familyGrant(0, Families.IDENTITY, 8, address(this), false);
        vm.expectRevert(
            abi.encodeWithSelector(Snap.PolicySnapshotAuthority.selector, address(this))
        );
        snapshotHost.previewSnapshot(publication, address(this));
        _familyGrant(0, Families.SNAPSHOT, 8, address(this), true);
        _familyGrant(1, Families.SNAPSHOT, 7, address(this), false);
        _familyGrant(0, Families.IDENTITY, 8, address(this), true);
        bytes memory raw = _preview(address(this));
        _upload(raw, false);
        bytes32 source = publication.expectedSourceHash;
        publication.expectedSourceHash = keccak256("wrong current source");
        vm.expectRevert(abi.encodeWithSelector(Snap.InvalidPolicySnapshot.selector));
        snapshotHost.publishSnapshot(publication);
        require(snapshotHost.snapshotCount(publication.scope) == 0);
        publication.expectedSourceHash = source;
        bytes32 hash = snapshotHost.publishSnapshot(publication);
        Snap.Receipt memory r = snapshotHost.requireCurrent(publication.scope, hash, 1);
        require(r.authorizationClass == 8 && r.displayAuthorizationClass == 8);
    }

    function testCollectionPreservationHeadSourceAndRuntimeDriftPreserveHistoricalBytes() public {
        _ready();
        bytes32 hash = _publish();
        bytes32 before = _historyHash(hash);
        snapshotVm.mockCall(
            address(router),
            abi.encodeCall(Root.collectionContentRootHead, (uint256(1))),
            abi.encode(keccak256("later root"))
        );
        vm.expectRevert(abi.encodeWithSelector(Snap.InvalidPolicySnapshot.selector));
        snapshotHost.requireCurrent(publication.scope, hash, 1);
        require(_historyHash(hash) == before);
        _refreshRoot();
        Capture memory c = snapshotCapture;
        string memory j = c.producers[1].preservationTokenJSON(92);
        string memory h = c.producers[1].preservationTokenHTML(92);
        c.producers[1].setBytes(92, string(abi.encodePacked(" ", j)), h);
        vm.expectRevert();
        snapshotHost.requireCurrent(publication.scope, hash, 1);
        require(_historyHash(hash) == before);
        c.producers[1].setBytes(92, j, h);
        address target = snapshotContent.entropySourceSet();
        bytes memory code = target.code;
        vm.etch(target, hex"00");
        vm.expectRevert(abi.encodeWithSelector(Snap.PolicySnapshotDependency.selector, target));
        snapshotHost.requireCurrent(publication.scope, hash, 1);
        require(_historyHash(hash) == before);
        vm.etch(target, code);
        require(snapshotHost.requireCurrent(publication.scope, hash, 1).recordHash == hash);
    }

    function testCollectionPreservationLineageUniqueIdsAndClassTwoLockRetainHistory() public {
        _ready();
        bytes32 first = _publish();
        bytes32 firstHistory = _historyHash(first);
        vm.expectRevert(abi.encodeWithSelector(Snap.InvalidPolicySnapshot.selector));
        snapshotHost.publishSnapshot(publication);
        publication.snapshotId = keccak256("second snapshot");
        publication.expectedHead = first;
        publication.expectedRevision = 1;
        bytes32 second = _publish();
        require(
            snapshotHost.snapshotCount(publication.scope) == 2
                && snapshotHost.snapshotAt(publication.scope, 0) == first
                && snapshotHost.snapshotAt(publication.scope, 1) == second
        );
        require(_historyHash(first) == firstHistory);
        vm.expectRevert(abi.encodeWithSelector(Snap.PolicySnapshotLineage.selector, first, second));
        snapshotHost.requireCurrent(publication.scope, first, 1);
        (bytes32 scope, bytes32 old, bytes32 next) = snapshotHost.lockTransition(publication.scope);
        _lockAction(1, scope, old, next);
        vm.prank(address(executor));
        vm.expectRevert(
            abi.encodeWithSelector(Snap.PolicySnapshotAuthority.selector, address(executor))
        );
        snapshotHost.lockSnapshot(publication.scope);
        require(snapshotHost.snapshotLock(publication.scope).actionId == 0);
        _lockAction(2, scope, old, next);
        vm.prank(address(executor));
        snapshotHost.lockSnapshot(publication.scope);
        Snap.Lock memory locked = snapshotHost.snapshotLock(publication.scope);
        require(
            locked.recordHash == second && locked.revision == 2
                && locked.actionId == keccak256("exact class two snapshot lock")
        );
        publication.snapshotId = keccak256("after lock");
        publication.expectedHead = second;
        publication.expectedRevision = 2;
        vm.expectRevert(
            abi.encodeWithSelector(
                Snap.PolicySnapshotLocked.selector,
                snapshotHost.currentSnapshot(publication.scope).scopeSubject
            )
        );
        snapshotHost.publishSnapshot(publication);
        require(_historyHash(first) == firstHistory);
    }

    function testCollectionPreservationOfficialSafeLateMissingChunkAndIdenticalRetry() public {
        _ready();
        uint256[] memory keys = new uint256[](2);
        keys[0] = 0x551281;
        keys[1] = 0x551282;
        OfficialSafe account =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 929);
        _familyGrant(1, Families.SNAPSHOT, 7, address(account), true);
        _familyGrant(1, Families.IDENTITY, 7, address(account), true);
        bytes memory raw = _preview(address(account));
        _upload(raw, true);
        bytes memory input = abi.encodeCall(snapshotHost.publishSnapshot, (publication));
        uint256 nonce = account.nonce();
        bytes memory signatures = safeThresholdSignature(
            keys,
            account.getTransactionHash(
                address(snapshotHost), 0, input, 0, 0, 0, 0, address(0), address(0), nonce
            )
        );
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        account.execTransaction(
            address(snapshotHost), 0, input, 0, 0, 0, 0, address(0), payable(address(0)), signatures
        );
        require(
            account.nonce() == nonce && snapshotHost.snapshotCount(publication.scope) == 0
                && snapshotHost.currentSnapshot(publication.scope).recordHash == 0
        );
        _upload(raw, false);
        require(
            account.execTransaction(
                address(snapshotHost),
                0,
                input,
                0,
                0,
                0,
                0,
                address(0),
                payable(address(0)),
                signatures
            )
        );
        Snap.Receipt memory r = snapshotHost.currentSnapshot(publication.scope);
        require(account.nonce() == nonce + 1 && r.publisher == address(account) && r.revision == 1);
        require(keccak256(snapshotHost.snapshotPayload(r.recordHash)) == keccak256(raw));
        snapshotHost.requireCurrent(publication.scope, r.recordHash, 1);
    }

    function testCollectionPreservationExactSchemasAndCompleteChunkReassembly() public {
        _ready();
        require(
            keccak256(
                bytes(
                    vm.readFile(
                        "docs/schemas/preservation/preservation-policy-collection-snapshot-v1.schema.json"
                    )
                )
            ) == SnapshotDocuments.SCHEMA_HASH
        );
        require(
            keccak256(
                bytes(
                    vm.readFile(
                        "docs/schemas/preservation/preservation-policy-collection-snapshot-v1.profile.json"
                    )
                )
            ) == SnapshotDocuments.PROFILE_HASH
        );
        require(
            keccak256(
                bytes(
                    vm.readFile(
                        "docs/schemas/preservation/preservation-policy-collection-snapshot-v1.abi.json"
                    )
                )
            ) == SnapshotDocuments.CANON_HASH
        );
        bytes memory tail = new bytes(1800);
        for (uint256 i; i < tail.length; ++i) {
            tail[i] = 0x61;
        }
        publication.manifestURI = string.concat("https://", string(tail));
        canonicalRoot.publication.manifestURI = publication.manifestURI;
        _refreshRoot();
        bytes memory raw = _preview(address(this));
        require(raw.length > 8192);
        _upload(raw, false);
        bytes32 hash = snapshotHost.publishSnapshot(publication);
        uint256 count = snapshotHost.snapshotChunkCount(hash);
        require(count == (raw.length + 8191) / 8192);
        bytes memory joined;
        for (uint256 i; i < count; ++i) {
            (address pointer, bytes32 digest, uint32 length) = snapshotHost.snapshotChunkAt(hash, i);
            bytes memory part = snapshotStore.readChunk(digest);
            require(
                pointer.code.length == uint256(length) + 1 && part.length == length
                    && keccak256(part) == digest
            );
            joined = bytes.concat(joined, part);
        }
        require(
            keccak256(joined) == keccak256(raw)
                && keccak256(snapshotHost.snapshotPayload(hash)) == keccak256(raw)
        );
    }
}
