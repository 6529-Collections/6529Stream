// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { PreservationPolicyContentFixtureV1 } from "../finality/StreamPreservationPolicyContentCheckpointV1.t.sol";
import { PreservationOutputBoundary } from "../../helpers/scoped-preservation-boundaries/StreamPreservationPolicyContentCheckpointV1Boundaries.sol";
import { StaticRouteVm } from "../../helpers/StaticMetadataRoutingFixture.sol";
import { OfficialSafe } from "../../helpers/OfficialSafeFixture.sol";
import { Vm } from "../../regression/legacy/helpers/CharacterizationTestBase.sol";
import { LeafManifestVm } from "../finality/StreamContentLeafManifest.t.sol";
import {
    LeafManifestArchiveBoundary,
    LeafManifestFinalityBoundary
} from "../../helpers/scoped-preservation-boundaries/StreamContentLeafManifestBoundaries.sol";
import {
    StreamScopedPreservationPolicySnapshotPublicationV1 as Snapshot
} from "../../../smart-contracts/domains/metadata/StreamScopedPreservationPolicySnapshotPublicationV1.sol";
import {
    StreamScopedPreservationPolicySnapshotTypesV1 as Snap
} from "../../../smart-contracts/interfaces/stream/metadata/StreamScopedPreservationPolicySnapshotTypesV1.sol";
import {
    IStreamScopedPreservationPolicySnapshotPublicationV1 as SnapshotInterface
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamScopedPreservationPolicySnapshotPublicationV1.sol";
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
    StreamScopedPreservationPolicySnapshotDefinitionsV1 as SnapshotDocuments
} from "../../../smart-contracts/domains/records/StreamScopedPreservationPolicySnapshotDefinitionsV1.sol";
import {
    IStreamFinalityEntropySourceFactory as FactoryReads
} from "../../../smart-contracts/interfaces/stream/finality/IStreamFinalityEntropySourceFactory.sol";
import {
    IStreamFinalityScopeMembership as MembershipReads
} from "../../../smart-contracts/interfaces/stream/finality/IStreamFinalityScopeMembership.sol";
import {
    StreamScopeMembershipFacts
} from "../../../smart-contracts/interfaces/stream/finality/StreamScopeMembershipTypes.sol";

/// @notice Actual native full policies/factory, membership/selection, new preservation checkpoint,
/// covered output manifest, scoped snapshot, Metadata grants, shared Schema/Store and official Safe.
/// @dev The inherited preservation producer and its Registry admission are explicitly typed
/// boundaries, not an implementation of ADR0054's projection or governed analysis/golden evidence.
/// Original Core/Artist/module/governance and archive-family receipts retain their named boundaries.
/// A locked ArtistPresentation is supplied explicitly. No Artist lock, Router root adoption,
/// current-stack finality ceremony, transaction gas or runtime acceptance follows from these tests.
abstract contract ScopedPreservationSnapshotFixtureV1 is PreservationPolicyContentFixtureV1 {
    bytes32 internal constant SNAPSHOT_ARTIST = keccak256("scoped snapshot locked artist boundary");
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

    function _initialize(uint8 terminalStatus) internal {
        _scopedFixture(terminalStatus, true);
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
        _register(
            "STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_ABI_V1",
            Schema.DocumentKind.SCHEMA,
            SnapshotDocuments.document(SnapshotDocuments.SCHEMA_ID)
        );
        _register(
            "STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_PROFILE_V1",
            Schema.DocumentKind.CATALOG,
            SnapshotDocuments.document(SnapshotDocuments.PROFILE_ID)
        );
        _register(
            "STREAM_ABI_SCOPED_PRESERVATION_POLICY_SNAPSHOT_V1",
            Schema.DocumentKind.CANONICALIZATION,
            SnapshotDocuments.document(SnapshotDocuments.CANON_ID)
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

    function _prepare(uint8 kind) internal {
        StreamFinalityScope memory scope = _scopedScope(kind);
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
            keccak256(abi.encode("scoped preservation snapshot", kind)),
            0,
            0,
            output,
            SourceSet(d.targets[10]).inventoryPlan(),
            0,
            "ipfs://scoped-preservation-policy-snapshot",
            1000,
            keccak256("complete original native policies and admitted preservation output")
        );
    }

    function _snapshotGas() internal pure returns (Gas.GasParameterConfig[3] memory configs) {
        // Reserve genuine nested checkpoint/render reads; these caps are not a gas acceptance claim.
        configs[0] = Gas.GasParameterConfig("SCOPED_POLICY_SNAPSHOT_READ_GAS", 2000000, 50000, 2);
        configs[1] = Gas.GasParameterConfig("SCOPED_POLICY_SNAPSHOT_SOURCE_GAS", 64000000, 50000, 2);
        configs[2] =
            Gas.GasParameterConfig("SCOPED_POLICY_SNAPSHOT_INVENTORY_GAS", 8000000, 50000, 2);
    }

    function _assertPayload(bytes memory raw, uint256 count) internal view {
        (
            bytes32 domain,
            uint256 chain,
            address producer,
            address[11] memory targets,
            bytes32[11] memory runtimes,
            Snap.Publication memory p,
            Snap.Receipt memory r,
            Snap.Source memory f
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
            domain == keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_PAYLOAD_V1")
                && chain == block.chainid
        );
        require(producer == address(snapshotHost) && targets[0] == address(core));
        require(targets[2] == address(schemas) && targets[3] == address(snapshotStore));
        for (uint256 i; i < targets.length; ++i) {
            require(runtimes[i] == targets[i].codehash);
        }
        require(p.expectedSourceHash == 0 && r.sourceHash == publication.expectedSourceHash);
        require(abi.encode(f.content).length == 448 && abi.encode(f.outputs).length == 608);
        require(
            f.outputs.metadataRouter == address(router)
                && f.content.preservationProfile == keccak256("6529STREAM_PRESERVATION_RENDER_V1")
                && f.outputs.preservationProfile == f.content.preservationProfile
        );
        require(
            r.sourceHash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_SOURCES_V1"),
                        chain,
                        producer,
                        targets,
                        runtimes,
                        f
                    )
                )
        );
        require(
            keccak256(raw)
                == keccak256(abi.encode(domain, chain, producer, targets, runtimes, p, r, f))
        );
        require(
            r.recordHash == 0 && r.chainHash == 0 && r.manifestHash == 0 && r.manifestBytes == 0
                && r.recordedAt == 0
        );
        require(keccak256(abi.encode(f.scope)) == keccak256(abi.encode(publication.scope)));
        require(
            f.membership.tokenCount == count && f.selection.tokenCount == count
                && f.content.tokenCount == count
        );
        require(
            f.outputs.tokenCount == count && f.entropy.policyCount == count && f.entropy.allFrozen
        );
        require(
            f.sourceFactory == address(scopedFactory)
                && f.sourceFactoryCodeHash == address(scopedFactory).codehash
        );
        require(f.factoryDependenciesHash == keccak256(abi.encode(_scopedDependencies())));
        require(f.entropy.planId == publication.coordinatorInventoryPlan);
        require(
            f.entropy.inventoryHash == f.content.inventoryHash
                && f.entropy.policyChainHash == f.content.policyChainHash
        );
        SourceSet set = SourceSet(targets[10]);
        require(
            set.factory() == address(scopedFactory) && f.outputs.entropySourceSet == address(set)
        );
        for (uint256 i; i < count; ++i) {
            require(
                keccak256(abi.encode(f.entropy.policies[i]))
                    == keccak256(abi.encode(set.sourcePolicyAt(i)))
            );
            Content.Output memory row = snapshotContent.outputAt(f.outputs.checkpointHash, i);
            require(abi.encode(row).length == 1152);
            Capture memory c = snapshotCapture;
            require(
                keccak256(abi.encode(row.preservation)) == keccak256(abi.encode(_binding(c, i)))
            );
            require(
                keccak256(abi.encode(row.preservationAdmission))
                    == keccak256(abi.encode(_admission(c, i)))
            );
            require(row.entropy.coordinator == f.entropy.policies[i].coordinator);
            require(row.entropy.policyHash == f.entropy.policies[i].policyHash);
            if (i == 0) {
                require(
                    row.entropy.terminal && row.entropy.seed == 0 && row.terminalAdmissionHash != 0
                );
            } else {
                require(
                    row.entropy.finalized && row.entropy.seed == scopedFinalizedSeed
                        && row.terminalAdmissionHash == 0
                );
            }
        }
    }

    function _assertRecordIdentity(bytes32 hash, Snap.Receipt memory r) internal view {
        r.recordHash = 0;
        r.chainHash = 0;
        require(
            hash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_RECORD_V1"),
                        block.chainid,
                        address(snapshotHost),
                        address(core),
                        address(metadata),
                        publication,
                        r
                    )
                )
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
}

contract StreamScopedPreservationPolicySnapshotPublicationV1Test is
    ScopedPreservationSnapshotFixtureV1
{
    function testGenuineTokenReleaseSeasonPayloadsRetainFullOriginalPolicies() public {
        _initialize(1);
        for (uint8 kind = 1; kind <= 3; ++kind) {
            _prepare(kind);
            bytes memory raw = _preview(address(this));
            _upload(raw, false);
            vm.recordLogs();
            bytes32 hash = snapshotHost.publishSnapshot(publication);
            Vm.Log[] memory logs = vm.getRecordedLogs();
            require(logs.length == 1 && logs[0].emitter == address(snapshotHost));
            (
                uint16 version,
                Snap.Publication memory eventPublication,
                Snap.Receipt memory eventReceipt
            ) = abi.decode(logs[0].data, (uint16, Snap.Publication, Snap.Receipt));
            Snap.Receipt memory r = snapshotHost.requireCurrent(publication.scope, hash, 1);
            require(version == 1 && logs[0].topics.length == 4);
            require(
                logs[0].topics[1] == r.scopeSubject && logs[0].topics[2] == publication.snapshotId
            );
            require(logs[0].topics[3] == hash);
            require(keccak256(abi.encode(eventPublication)) == keccak256(abi.encode(publication)));
            require(keccak256(abi.encode(eventReceipt)) == keccak256(abi.encode(r)));
            require(keccak256(snapshotHost.snapshotPayload(hash)) == keccak256(raw));
            _assertPayload(raw, kind == 1 ? 1 : 2);
            _assertRecordIdentity(hash, r);
            require(snapshotHost.snapshotCount(publication.scope) == 1);
            require(snapshotHost.snapshotAt(publication.scope, 0) == hash);
        }
    }

    function testExplicitNotRequiredPolicyKeepsNativeTerminalEvidence() public {
        _initialize(2);
        _prepare(2);
        bytes32 hash = _publish();
        Snap.Source memory f = _source(snapshotHost.snapshotPayload(hash));
        Content.Output memory terminal = snapshotContent.outputAt(f.outputs.checkpointHash, 0);
        Content.Output memory random = snapshotContent.outputAt(f.outputs.checkpointHash, 1);
        require(terminal.entropy.status == 2 && terminal.entropy.mode == 2);
        require(
            terminal.entropy.terminal && !terminal.entropy.finalized && terminal.entropy.seed == 0
        );
        require(
            random.entropy.finalized && !random.entropy.terminal
                && random.entropy.seed == scopedFinalizedSeed
        );
        require(
            f.entropy.policies[0].explicitPolicy && f.entropy.policies[0].collectionPolicy.frozen
        );
        require(f.entropy.policies[0].collectionPolicy.renderRequirement == 1);
        snapshotHost.requireCurrent(publication.scope, hash, 1);
    }

    function testCapabilitiesAndCollectionViewMalformedScopesCannotBorrowEvidence() public {
        _initialize(1);
        _prepare(2);
        require(snapshotHost.supportsInterface(type(SnapshotInterface).interfaceId));
        require(!snapshotHost.supportsInterface(type(OriginalScopedSnapshot).interfaceId));
        require(!snapshotHost.supportsInterface(type(OldPolicySnapshot).interfaceId));
        require(!snapshotHost.supportsInterface(type(CollectionPolicySnapshot).interfaceId));
        require(
            snapshotHost.scopedPreservationPolicySnapshotProfile()
                == keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_V1")
        );
        StreamFinalityScope[6] memory bad = [
            StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0),
            StreamFinalityScope(StreamFinalityScopeType.VIEW, 1, 0, bytes32(uint256(1))),
            StreamFinalityScope(StreamFinalityScopeType.TOKEN, 1, 0, 0),
            StreamFinalityScope(StreamFinalityScopeType.TOKEN, 1, 91, bytes32(uint256(1))),
            StreamFinalityScope(StreamFinalityScopeType.RELEASE, 1, 91, publication.scope.scopeId),
            StreamFinalityScope(StreamFinalityScopeType.SEASON, 1, 0, 0)
        ];
        Snap.Publication memory p = publication;
        for (uint256 i; i < bad.length; ++i) {
            p.scope = bad[i];
            vm.expectRevert();
            snapshotHost.previewSnapshot(p, address(this));
        }
        Snap.Dependencies memory d = snapshotHost.dependencies();
        snapshotVm.mockCall(
            address(snapshotContent),
            abi.encodeWithSignature("supportsInterface(bytes4)", type(Content).interfaceId),
            abi.encode(false)
        );
        vm.expectRevert();
        new Snapshot(d, address(executor), _snapshotGas());
    }

    function testSnapshotAndIdentityAuthorityAreIndependentWithCollectionPrecedence() public {
        _initialize(1);
        _prepare(1);
        address publisher = address(0xB00B);
        _familyGrant(1, Families.SNAPSHOT, 7, publisher, true);
        vm.expectRevert();
        snapshotHost.previewSnapshot(publication, publisher);
        _familyGrant(1, Families.SNAPSHOT, 7, publisher, false);
        _familyGrant(1, Families.IDENTITY, 7, publisher, true);
        vm.expectRevert();
        snapshotHost.previewSnapshot(publication, publisher);
        _familyGrant(0, Families.SNAPSHOT, 8, publisher, true);
        _familyGrant(0, Families.IDENTITY, 8, publisher, true);
        _familyGrant(1, Families.SNAPSHOT, 7, publisher, true);
        bytes memory raw = _preview(publisher);
        _upload(raw, false);
        vm.prank(publisher);
        bytes32 hash = snapshotHost.publishSnapshot(publication);
        Snap.Receipt memory r = snapshotHost.requireCurrent(publication.scope, hash, 1);
        require(
            r.publisher == publisher && r.authorizationClass == 7
                && r.displayAuthorizationClass == 7
        );
        require(r.grantRevision == 3 && r.displayGrantRevision == 1);
        _familyGrant(1, Families.SNAPSHOT, 7, publisher, false);
        _familyGrant(1, Families.IDENTITY, 7, publisher, false);
        // Currentness authenticates original publication authority; it does not rewrite old grants.
        require(snapshotHost.requireCurrent(publication.scope, hash, 1).recordHash == hash);
        publication.snapshotId = keccak256("global grant successor");
        publication.expectedHead = hash;
        publication.expectedRevision = 1;
        _upload(_preview(publisher), false);
        vm.prank(publisher);
        bytes32 next = snapshotHost.publishSnapshot(publication);
        r = snapshotHost.requireCurrent(publication.scope, next, 2);
        require(r.authorizationClass == 8 && r.displayAuthorizationClass == 8);
    }

    function testLockedArtistBoundaryIsRequiredAndExactSourceCommitmentCannotBeSubstituted()
        public
    {
        _initialize(1);
        _prepare(1);
        lockedArtistBoundary.locked = false;
        _setLockedArtistBoundary();
        vm.expectRevert();
        snapshotHost.previewSnapshot(publication, address(this));
        lockedArtistBoundary.locked = true;
        lockedArtistBoundary.acceptanceRecordHash = 0;
        _setLockedArtistBoundary();
        vm.expectRevert();
        snapshotHost.previewSnapshot(publication, address(this));
        lockedArtistBoundary.acceptanceRecordHash = keccak256("locked Artist acceptance boundary");
        _setLockedArtistBoundary();
        _upload(_preview(address(this)), false);
        bytes32 expected = publication.expectedSourceHash;
        publication.expectedSourceHash ^= bytes32(uint256(1));
        vm.expectRevert();
        snapshotHost.publishSnapshot(publication);
        require(snapshotHost.snapshotCount(publication.scope) == 0);
        publication.expectedSourceHash = expected;
        bytes32 hash = snapshotHost.publishSnapshot(publication);
        require(snapshotHost.requireCurrent(publication.scope, hash, 1).recordHash == hash);
    }

    function testFactorySourceSetAndCheckpointPinsFailClosedWithoutRewritingHistory() public {
        _initialize(1);
        _prepare(2);
        bytes32 hash = _publish();
        bytes32 saved = _historyHash(hash);
        address[3] memory targets =
            [address(scopedFactory), snapshotContent.entropySourceSet(), address(snapshotContent)];
        for (uint256 i; i < targets.length; ++i) {
            bytes memory original = targets[i].code;
            vm.etch(targets[i], hex"00");
            vm.expectRevert();
            snapshotHost.requireCurrent(publication.scope, hash, 1);
            require(_historyHash(hash) == saved);
            vm.etch(targets[i], original);
            require(snapshotHost.requireCurrent(publication.scope, hash, 1).recordHash == hash);
        }
    }

    function testFullNativePolicyReceiptDriftStalesSnapshotWithoutChangingTerminalStatus() public {
        _initialize(1);
        _prepare(2);
        bytes32 hash = _publish();
        bytes32 saved = _historyHash(hash);
        EntropyPolicy.PolicyRecord memory policy =
            EntropyPolicy(address(terminalCoordinator)).collectionEntropyPolicy(1);
        bytes memory original = abi.encode(policy);
        policy.artistConsentRecord ^= bytes32(uint256(1));
        // Negative corruption of one original native read, never a positive fabricated SourceSet.
        snapshotVm.mockCall(
            address(terminalCoordinator),
            abi.encodeCall(EntropyPolicy.collectionEntropyPolicy, (uint256(1))),
            abi.encode(policy)
        );
        vm.expectRevert();
        snapshotHost.requireCurrent(publication.scope, hash, 1);
        require(_historyHash(hash) == saved);
        snapshotVm.mockCall(
            address(terminalCoordinator),
            abi.encodeCall(EntropyPolicy.collectionEntropyPolicy, (uint256(1))),
            original
        );
        require(snapshotHost.requireCurrent(publication.scope, hash, 1).recordHash == hash);
    }

    function testOfficialSafeMissingLastChunkRollsBackAndRetriesIdenticalSignedCall() public {
        _initialize(1);
        _prepare(3);
        uint256[] memory keys = new uint256[](2);
        keys[0] = 0x819121;
        keys[1] = 0x819122;
        OfficialSafe account =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 1902);
        _familyGrant(1, Families.SNAPSHOT, 7, address(account), true);
        _familyGrant(1, Families.IDENTITY, 7, address(account), true);
        bytes memory suffix = new bytes(1900);
        for (uint256 i; i < suffix.length; ++i) {
            suffix[i] = 0x61;
        }
        publication.manifestURI = string.concat("https://", string(suffix));
        bytes memory raw = _preview(address(account));
        require(raw.length != 0, "original payload requires retained Store bytes");
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
        require(account.nonce() == nonce && snapshotHost.snapshotCount(publication.scope) == 0);
        require(snapshotHost.currentSnapshot(publication.scope).recordHash == 0);
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
        require(
            snapshotHost.requireCurrent(publication.scope, r.recordHash, 1).recordHash
                == r.recordHash
        );
    }

    function testSuccessorPreservesOriginalPayloadAndReceiptWhileChangingCurrentHead() public {
        _initialize(1);
        _prepare(3);
        bytes32 first = _publish();
        bytes32 history = _historyHash(first);
        Snap.Receipt memory previous = snapshotHost.currentSnapshot(publication.scope);
        vm.expectRevert(abi.encodeWithSelector(Snap.InvalidScopedPolicySnapshot.selector));
        snapshotHost.publishSnapshot(publication);
        publication.snapshotId = keccak256("second preservation snapshot");
        publication.expectedHead = first;
        publication.expectedRevision = 1;
        bytes32 second = _publish();
        Snap.Receipt memory r = snapshotHost.requireCurrent(publication.scope, second, 2);
        require(first != second && r.predecessor == first && r.revision == 2);
        require(
            r.chainHash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_CHAIN_V1"),
                        block.chainid,
                        address(snapshotHost),
                        address(core),
                        publication.scope,
                        previous.chainHash,
                        uint64(2),
                        second
                    )
                )
        );
        vm.expectRevert(
            abi.encodeWithSelector(Snap.ScopedPolicySnapshotLineage.selector, first, second)
        );
        snapshotHost.requireCurrent(publication.scope, first, 1);
        require(_historyHash(first) == history);
        require(
            snapshotHost.snapshotCount(publication.scope) == 2
                && snapshotHost.snapshotAt(publication.scope, 0) == first
                && snapshotHost.snapshotAt(publication.scope, 1) == second
        );
    }

    function testNewProducerBytesAndGovernedAdmissionBoundaryDriftKeepHistoricalSnapshot() public {
        _initialize(1);
        _prepare(2);
        bytes32 hash = _publish();
        bytes32 history = _historyHash(hash);
        Capture memory c = snapshotCapture;
        uint256 token = scopedSelections.selectionAt(c.selection, 1).tokenId;
        string memory json = c.producers[1].preservationTokenJSON(token);
        string memory html = c.producers[1].preservationTokenHTML(token);
        c.producers[1].setBytes(token, string.concat(json, " "), html);
        vm.expectRevert();
        snapshotHost.requireCurrent(publication.scope, hash, 1);
        require(_historyHash(hash) == history);
        c.producers[1].setBytes(token, json, html);
        require(snapshotHost.requireCurrent(publication.scope, hash, 1).recordHash == hash);
        PreservationTypes.Admission memory a = _admission(c, 1);
        bytes32 originalGolden = a.goldenHash;
        a.goldenHash = keccak256("changed preservation golden boundary");
        _setAdmission(c, 1, abi.encode(_binding(c, 1), a));
        vm.expectRevert();
        snapshotHost.requireCurrent(publication.scope, hash, 1);
        require(_historyHash(hash) == history);
        a.goldenHash = originalGolden;
        _setAdmission(c, 1, abi.encode(_binding(c, 1), a));
        require(snapshotHost.requireCurrent(publication.scope, hash, 1).recordHash == hash);
        terminalVersions.setAdmitted(false);
        vm.expectRevert();
        snapshotHost.requireCurrent(publication.scope, hash, 1);
        terminalVersions.setAdmitted(true);
        require(snapshotHost.requireCurrent(publication.scope, hash, 1).recordHash == hash);
    }

    function testExactClassTwoActionLocksCurrentSnapshotAndPreventsSuccessor() public {
        _initialize(1);
        _prepare(2);
        bytes32 hash = _publish();
        (bytes32 scope, bytes32 oldState, bytes32 newState) =
            snapshotHost.lockTransition(publication.scope);
        vm.expectRevert(
            abi.encodeWithSelector(Snap.ScopedPolicySnapshotAuthority.selector, address(this))
        );
        snapshotHost.lockSnapshot(publication.scope);
        _lockAction(1, scope, oldState, newState);
        vm.expectRevert(
            abi.encodeWithSelector(Snap.ScopedPolicySnapshotAuthority.selector, address(executor))
        );
        vm.prank(address(executor));
        snapshotHost.lockSnapshot(publication.scope);
        _lockAction(2, scope, oldState, newState ^ bytes32(uint256(1)));
        vm.expectRevert(
            abi.encodeWithSelector(Snap.ScopedPolicySnapshotAuthority.selector, address(executor))
        );
        vm.prank(address(executor));
        snapshotHost.lockSnapshot(publication.scope);
        require(snapshotHost.snapshotLock(publication.scope).actionId == 0);
        _lockAction(2, scope, oldState, newState);
        snapshotCapture.producers[1].setFail(true);
        vm.expectRevert();
        vm.prank(address(executor));
        snapshotHost.lockSnapshot(publication.scope);
        require(snapshotHost.snapshotLock(publication.scope).actionId == 0);
        snapshotCapture.producers[1].setFail(false);
        vm.recordLogs();
        vm.prank(address(executor));
        snapshotHost.lockSnapshot(publication.scope);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        (uint16 version, Snap.Lock memory eventLock) = abi.decode(logs[0].data, (uint16, Snap.Lock));
        Snap.Lock memory locked = snapshotHost.snapshotLock(publication.scope);
        require(logs.length == 1 && logs[0].emitter == address(snapshotHost) && version == 1);
        require(keccak256(abi.encode(eventLock)) == keccak256(abi.encode(locked)));
        require(
            locked.recordHash == hash && locked.revision == 1
                && locked.actionId == keccak256("exact class two snapshot lock")
        );
        publication.snapshotId = keccak256("successor after lock");
        publication.expectedHead = hash;
        publication.expectedRevision = 1;
        vm.expectRevert(
            abi.encodeWithSelector(
                Snap.ScopedPolicySnapshotLocked.selector,
                snapshotHost.currentSnapshot(publication.scope).scopeSubject
            )
        );
        snapshotHost.previewSnapshot(publication, address(this));
        require(snapshotHost.requireCurrent(publication.scope, hash, 1).recordHash == hash);
    }

    function testWrongFactoryPlanAndAuthoritativeMembershipRejectCurrentKeepHistory() public {
        _initialize(1);
        _prepare(2);
        bytes32 hash = _publish();
        bytes32 saved = _historyHash(hash);
        bytes32 actualPlan = scopedFactory.currentInventoryPlan(publication.scope);
        snapshotVm.mockCall(
            address(scopedFactory),
            abi.encodeCall(FactoryReads.currentInventoryPlan, (publication.scope)),
            abi.encode(actualPlan ^ bytes32(uint256(1)))
        );
        vm.expectRevert();
        snapshotHost.requireCurrent(publication.scope, hash, 1);
        require(_historyHash(hash) == saved);
        snapshotVm.mockCall(
            address(scopedFactory),
            abi.encodeCall(FactoryReads.currentInventoryPlan, (publication.scope)),
            abi.encode(actualPlan)
        );
        require(snapshotHost.requireCurrent(publication.scope, hash, 1).recordHash == hash);
        StreamScopeMembershipFacts memory facts =
            scopedMembership.requireScopeMembership(publication.scope);
        bytes memory original = abi.encode(facts);
        facts.membershipHash ^= bytes32(uint256(1));
        snapshotVm.mockCall(
            address(scopedMembership),
            abi.encodeCall(MembershipReads.requireScopeMembership, (publication.scope)),
            abi.encode(facts)
        );
        vm.expectRevert();
        snapshotHost.requireCurrent(publication.scope, hash, 1);
        require(_historyHash(hash) == saved);
        snapshotVm.mockCall(
            address(scopedMembership),
            abi.encodeCall(MembershipReads.requireScopeMembership, (publication.scope)),
            original
        );
        require(snapshotHost.requireCurrent(publication.scope, hash, 1).recordHash == hash);
    }

    function testTokenCollectionTupleCannotAliasCurrentHeadOrClassTwoLock() public {
        _initialize(1);
        _prepare(1);
        bytes32 hash = _publish();
        bytes32 saved = _historyHash(hash);
        StreamFinalityScope memory wrong = publication.scope;
        wrong.collectionId = 2;
        vm.expectRevert(abi.encodeWithSelector(Snap.InvalidScopedPolicySnapshot.selector));
        snapshotHost.currentSnapshot(wrong);
        vm.expectRevert(abi.encodeWithSelector(Snap.InvalidScopedPolicySnapshot.selector));
        snapshotHost.requireCurrent(wrong, hash, 1);
        vm.expectRevert(abi.encodeWithSelector(Snap.InvalidScopedPolicySnapshot.selector));
        snapshotHost.lockTransition(wrong);
        bytes32 wrongScope = keccak256(
            abi.encode(
                keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_LOCK_V1"),
                block.chainid,
                address(snapshotHost),
                address(core),
                wrong
            )
        );
        _lockAction(
            2,
            wrongScope,
            keccak256(abi.encode(wrongScope, hash, uint64(1), false)),
            keccak256(abi.encode(wrongScope, hash, uint64(1), true))
        );
        vm.expectRevert(abi.encodeWithSelector(Snap.InvalidScopedPolicySnapshot.selector));
        vm.prank(address(executor));
        snapshotHost.lockSnapshot(wrong);
        require(snapshotHost.snapshotLock(publication.scope).actionId == 0);
        require(
            _historyHash(hash) == saved
                && snapshotHost.currentSnapshot(publication.scope).recordHash == hash
        );
    }

    function testNewOutputRouterProfileAndCanonicalWidthsCannotBorrowOldEvidence() public {
        _initialize(1);
        _prepare(2);
        bytes32 hash = _publish();
        bytes32 saved = _historyHash(hash);
        Outputs.Manifest memory m = snapshotOutputs.requireCurrentManifest(
            publication.outputManifestRecord, SNAPSHOT_ARTIST
        );
        bytes memory original = abi.encode(m);
        bytes memory input = abi.encodeCall(
            Outputs.requireCurrentManifest, (publication.outputManifestRecord, SNAPSHOT_ARTIST)
        );
        m.metadataRouter = address(snapshotContent);
        snapshotVm.mockCall(address(snapshotOutputs), input, abi.encode(m));
        vm.expectRevert(abi.encodeWithSelector(Snap.InvalidScopedPolicySnapshot.selector));
        snapshotHost.requireCurrent(publication.scope, hash, 1);
        m.metadataRouter = address(router);
        m.preservationProfile = keccak256("old full live output");
        snapshotVm.mockCall(address(snapshotOutputs), input, abi.encode(m));
        vm.expectRevert(abi.encodeWithSelector(Snap.InvalidScopedPolicySnapshot.selector));
        snapshotHost.requireCurrent(publication.scope, hash, 1);
        snapshotVm.mockCall(address(snapshotOutputs), input, new bytes(544));
        vm.expectRevert();
        snapshotHost.requireCurrent(publication.scope, hash, 1);
        snapshotVm.mockCall(address(snapshotOutputs), input, original);
        require(
            snapshotHost.requireCurrent(publication.scope, hash, 1).recordHash == hash
                && _historyHash(hash) == saved
        );
        Snap.Dependencies memory d = snapshotHost.dependencies();
        snapshotVm.mockCall(
            address(snapshotOutputs),
            abi.encodeCall(Outputs.outputProfile, ()),
            abi.encode(keccak256("6529STREAM_SCOPED_POLICY_CURRENT_FULL_CONTENT_V2"))
        );
        vm.expectRevert(abi.encodeWithSelector(Snap.InvalidScopedPolicySnapshot.selector));
        new Snapshot(d, address(executor), _snapshotGas());
    }
}
