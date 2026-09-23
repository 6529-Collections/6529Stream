// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { ScopedPolicySnapshotRootProviderBoundaryV2 } from "../../helpers/scoped-preservation-boundaries/ScopedPolicySnapshotRootProviderBoundaryV2.sol";
import {
    StreamScopedPolicyPublicationGraphTypesV2 as SnapshotGraph442
} from "../../../smart-contracts/interfaces/stream/finality/StreamScopedPolicyPublicationGraphTypesV2.sol";
import {
    StreamScopedPolicyPublicationSnapshotDeploymentV2 as SnapshotDeployment442
} from "../../../smart-contracts/domains/finality/StreamScopedPolicyPublicationSnapshotDeploymentV2.sol";

import {
    ScopedPolicyContentFixtureV2
} from "../finality/StreamScopedPolicyContentCheckpointV2.t.sol";
import { StaticRouteVm } from "../../helpers/StaticMetadataRoutingFixture.sol";
import { OfficialSafe } from "../../helpers/OfficialSafeFixture.sol";
import { Vm } from "../../regression/legacy/helpers/CharacterizationTestBase.sol";
import { LeafManifestVm } from "../finality/StreamContentLeafManifest.t.sol";
import {
    LeafManifestArchiveBoundary,
    LeafManifestFinalityBoundary
} from "../../helpers/scoped-preservation-boundaries/StreamContentLeafManifestBoundaries.sol";
import {
    StreamScopedPolicySnapshotPublicationV2 as Snapshot
} from "../../../smart-contracts/domains/metadata/StreamScopedPolicySnapshotPublicationV2.sol";
import {
    StreamScopedPolicySnapshotTypesV2 as Snap
} from "../../../smart-contracts/interfaces/stream/metadata/StreamScopedPolicySnapshotTypesV2.sol";
import {
    IStreamScopedPolicySnapshotPublicationV2 as SnapshotInterface
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamScopedPolicySnapshotPublicationV2.sol";
import {
    IStreamScopedSnapshotPublication as OriginalScopedSnapshot
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamScopedSnapshotPublication.sol";
import {
    IStreamPolicySnapshotPublicationV2 as CollectionPolicySnapshot
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamPolicySnapshotPublicationV2.sol";
import {
    StreamScopedPolicyContentCheckpointV2 as ContentHost
} from "../../../smart-contracts/domains/finality/StreamScopedPolicyContentCheckpointV2.sol";
import {
    IStreamScopedPolicyContentCheckpointV2 as Content
} from "../../../smart-contracts/interfaces/stream/finality/IStreamScopedPolicyContentCheckpointV2.sol";
import {
    StreamScopedPolicyOutputManifestV2 as OutputHost
} from "../../../smart-contracts/domains/finality/StreamScopedPolicyOutputManifestV2.sol";
import {
    IStreamScopedPolicyOutputManifestV2 as Outputs
} from "../../../smart-contracts/interfaces/stream/finality/IStreamScopedPolicyOutputManifestV2.sol";
import {
    StreamScopedPolicyOutputSchemasV2 as OutputDocuments
} from "../../../smart-contracts/domains/finality/StreamScopedPolicyOutputSchemasV2.sol";
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
    StreamScopedPolicySnapshotDefinitionsV2 as SnapshotDocuments
} from "../../../smart-contracts/domains/records/StreamScopedPolicySnapshotDefinitionsV2.sol";
import {
    StreamFinalityScopedPolicySnapshotReadsV2 as SnapshotReads
} from "../../../smart-contracts/domains/finality/StreamFinalityScopedPolicySnapshotReadsV2.sol";
import {
    StreamFinalitySnapshotEvidence
} from "../../../smart-contracts/interfaces/stream/finality/StreamFinalitySnapshotTypes.sol";
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
    IStreamScopedPolicyContentRootEvidenceBindingV2 as RootProvider
} from "../../../smart-contracts/interfaces/stream/finality/IStreamScopedPolicyContentRootEvidenceBindingV2.sol";
import {
    IStreamScopedContentRootPublication as ScopedRoot
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamScopedContentRootPublication.sol";
import {
    IStreamScopedPolicyContentRootPublicationV2 as PolicyRoot
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamScopedPolicyContentRootPublicationV2.sol";
import {
    StreamScopedPolicyContentRootSchemasV2 as RootDocuments
} from "../../../smart-contracts/domains/finality/StreamScopedPolicyContentRootSchemasV2.sol";

contract ScopedPolicySnapshotReaderProbeV2 {
    function current(
        SnapshotReads.Dependencies calldata d,
        StreamFinalityScope calldata scope,
        bytes32 hash,
        uint64 revision
    ) external view returns (StreamFinalitySnapshotEvidence memory) {
        return SnapshotReads.requireCurrent(d, scope, hash, revision);
    }

    function original(
        SnapshotReads.Dependencies calldata d,
        StreamFinalityScope calldata scope,
        bytes32 hash,
        uint64 revision
    ) external view returns (Snap.Publication memory, Snap.Receipt memory) {
        return SnapshotReads.original(d, scope, hash, revision);
    }

    function locked(
        SnapshotReads.Dependencies calldata d,
        StreamFinalityScope calldata scope,
        bytes32 hash,
        uint64 revision
    ) external view returns (StreamFinalitySnapshotEvidence memory) {
        return SnapshotReads.requireLocked(d, scope, hash, revision);
    }
}

/// @notice Actual native policy/finalization, scoped factory/source set, membership, selection,
/// rendered checkpoint, covered output manifest, Metadata grants, shared schemas/Store and Safe.
/// @dev The inherited Core identities, Artist consent, governance and module/renderer admissions
/// remain typed boundaries. A single Router ArtistPresentation read explicitly supplies a locked
/// Artist boundary; this does not exercise the actual Artist lock ceremony. Original archive-family
/// receipts, selected Finality/provider and Artist root consent are boundaries too. No current-stack, finality or gas acceptance
/// follows from these tests. Authored coverage requires the separately coordinated native run.
contract StreamScopedPolicySnapshotPublicationV2Test is ScopedPolicyContentFixtureV2 {
    /// @dev Actual deployment worker and new child publish; no moved helper is mocked.
    function testCapacitySnapshotDeploymentPreservesCreateArgumentsAndIndependentHistory() public {
        _initialize(1);
        _prepare(1);
        Snap.Dependencies memory d = snapshotHost.dependencies();
        SnapshotGraph442.Recipe memory r;
        SnapshotGraph442.Graph memory g;
        for (uint256 i; i < 5; ++i) {
            r.inventory.targets[i] = d.targets[i];
            r.inventory.codeHashes[i] = d.codeHashes[i];
        }
        r.inventory.chainId = d.chainId;
        r.targets[0] = d.targets[5];
        r.codeHashes[0] = d.codeHashes[5];
        r.targets[1] = d.targets[6];
        r.codeHashes[1] = d.codeHashes[6];
        r.targets[3] = address(executor);
        r.codeHashes[3] = address(executor).codehash;
        r.inventory.targets[10] = d.targets[9];
        r.inventory.codeHashes[10] = d.codeHashes[9];
        g.children[1] = d.targets[7];
        g.codeHashes[1] = d.codeHashes[7];
        g.children[2] = d.targets[8];
        g.codeHashes[2] = d.codeHashes[8];
        g.sourceSet = d.targets[10];
        g.sourceSetCodeHash = d.codeHashes[10];
        r.snapshotGas = _snapshotGas();

        uint64 nonce = createVm.getNonce(address(this));
        Snapshot deployed = Snapshot(SnapshotDeployment442.deploy(r, g));
        require(
            address(deployed) == createVm.computeCreateAddress(address(this), nonce),
            "same host CREATE caller and nonce"
        );
        require(createVm.getNonce(address(this)) == nonce + 1, "exactly one child CREATE");
        require(
            keccak256(abi.encode(deployed.dependencies())) == keccak256(abi.encode(d))
                && deployed.governanceAuthority() == address(executor)
                && deployed.authorityCodeHash() == address(executor).codehash,
            "complete projected arguments and immutable authority"
        );
        Snapshot second = Snapshot(SnapshotDeployment442.deploy(r, g));
        require(
            address(second) == createVm.computeCreateAddress(address(this), uint256(nonce) + 1)
                && createVm.getNonce(address(this)) == nonce + 2
                && address(second) != address(deployed),
            "duplicate arguments create independent next host"
        );
        snapshotHost = deployed;
        bytes32 record = _publish();
        require(
            snapshotHost.currentSnapshot(publication.scope).recordHash == record,
            "real publication through deployed child"
        );
        require(
            second.snapshotCount(publication.scope) == 0
                && second.currentSnapshot(publication.scope).recordHash == 0,
            "constructor worker cannot share history storage"
        );
    }

    function testCapacityAdmissionKeepsCandidateBeforeAuthorityAndRechecksRevokedGrant() public {
        _initialize(1);
        _prepare(1);
        Snap.Publication memory bad = publication;
        bad.snapshotId = 0;
        vm.expectRevert(abi.encodeWithSelector(Snap.InvalidScopedPolicySnapshot.selector));
        snapshotHost.previewSnapshot(bad, address(0));
        bad = publication;
        bad.expectedHead = keccak256("unrecorded predecessor");
        bad.expectedRevision = 1;
        vm.expectRevert(
            abi.encodeWithSelector(
                Snap.ScopedPolicySnapshotLineage.selector, bad.expectedHead, bytes32(0)
            )
        );
        snapshotHost.previewSnapshot(bad, address(0));
        vm.expectRevert(
            abi.encodeWithSelector(Snap.ScopedPolicySnapshotAuthority.selector, address(0))
        );
        snapshotHost.previewSnapshot(publication, address(0));
        address publisher = address(0xAD442);
        _familyGrant(publication.scope.collectionId, Families.SNAPSHOT, 7, publisher, true);
        vm.expectRevert(
            abi.encodeWithSelector(Snap.ScopedPolicySnapshotAuthority.selector, publisher)
        );
        snapshotHost.previewSnapshot(publication, publisher);
        _familyGrant(publication.scope.collectionId, Families.IDENTITY, 7, publisher, true);
        bytes memory firstPreview = _preview(publisher);
        _upload(firstPreview, false);
        _familyGrant(publication.scope.collectionId, Families.IDENTITY, 7, publisher, false);
        vm.expectRevert(
            abi.encodeWithSelector(Snap.ScopedPolicySnapshotAuthority.selector, publisher)
        );
        vm.prank(publisher);
        snapshotHost.publishSnapshot(publication);
        require(
            snapshotHost.snapshotCount(publication.scope) == 0
                && snapshotHost.currentSnapshot(publication.scope).recordHash == 0,
            "revoked authority leaves no state"
        );
        _familyGrant(publication.scope.collectionId, Families.IDENTITY, 7, publisher, true);
        bytes memory restored = _preview(publisher);
        require(
            keccak256(restored) != keccak256(firstPreview),
            "new grant revision enters original receipt bytes"
        );
        _upload(restored, false);
        vm.prank(publisher);
        bytes32 record = snapshotHost.publishSnapshot(publication);
        Snap.Receipt memory receipt = snapshotHost.requireCurrent(publication.scope, record, 1);
        require(
            receipt.publisher == publisher && receipt.grantRevision == 1
                && receipt.displayGrantRevision == 3,
            "fresh independent authority revisions"
        );
        require(
            keccak256(snapshotHost.snapshotPayload(record)) == keccak256(restored),
            "no cached stale authority receipt"
        );
    }

    /// @dev Real Assembly/Admission/Writer calls and Metadata grants. The inherited named
    /// source boundaries remain unchanged; this is not full current-stack gas acceptance.
    function testCapacityExtractionPreservesPreviewCopiesPublisherEventAndRollback() public {
        _initialize(1);
        _prepare(1);
        address publisher = address(0xCA442);
        _familyGrant(publication.scope.collectionId, Families.SNAPSHOT, 7, publisher, true);
        _familyGrant(publication.scope.collectionId, Families.IDENTITY, 7, publisher, true);
        publication.expectedSourceHash = keccak256("preview-only circularity sentinel");
        (bytes32 source, bytes memory raw) = snapshotHost.previewSnapshot(publication, publisher);
        require(
            source != 0 && source != publication.expectedSourceHash, "independent source commitment"
        );
        (,,,,, Snap.Publication memory canonicalPublication, Snap.Receipt memory expected,) = abi.decode(
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
            canonicalPublication.expectedSourceHash == 0 && expected.sourceHash == source
                && expected.publisher == publisher && expected.authorizationClass == 7
                && expected.displayAuthorizationClass == 7 && expected.grantRevision == 1
                && expected.displayGrantRevision == 1 && expected.recordHash == 0
                && expected.chainHash == 0 && expected.manifestHash == 0
                && expected.manifestBytes == 0 && expected.recordedAt == 0,
            "assembly returns normalized bytes and retains full receipt fields"
        );
        publication.expectedSourceHash = keccak256("a different preview sentinel");
        (bytes32 sameSource, bytes memory sameRaw) =
            snapshotHost.previewSnapshot(publication, publisher);
        require(
            source == sameSource && keccak256(raw) == keccak256(sameRaw),
            "preview has no circular input"
        );
        publication.expectedSourceHash = source;
        _upload(raw, false);
        Snap.Publication memory wrong = publication;
        wrong.expectedSourceHash = keccak256("wrong actual source commitment");
        vm.expectRevert(abi.encodeWithSelector(Snap.InvalidScopedPolicySnapshot.selector));
        vm.prank(publisher);
        snapshotHost.publishSnapshot(wrong);
        require(
            snapshotHost.snapshotCount(publication.scope) == 0
                && snapshotHost.currentSnapshot(publication.scope).recordHash == 0,
            "expected-source refusal leaves no receipt, head or consumed snapshot id"
        );
        expected.manifestHash = keccak256(raw);
        expected.manifestBytes = uint32(raw.length);
        expected.recordedAt = uint64(block.timestamp);
        bytes32 literalRecord = keccak256(
            abi.encode(
                keccak256("6529STREAM_SCOPED_POLICY_SNAPSHOT_RECORD_V2"),
                block.chainid,
                address(snapshotHost),
                address(core),
                address(metadata),
                publication,
                expected
            )
        );
        vm.recordLogs();
        vm.prank(publisher);
        bytes32 record = snapshotHost.publishSnapshot(publication);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        require(
            record == literalRecord,
            "writer hash retains original publisher and restored sourceHash"
        );
        expected.recordHash = record;
        expected.chainHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_SCOPED_POLICY_SNAPSHOT_CHAIN_V2"),
                block.chainid,
                address(snapshotHost),
                address(core),
                publication.scope,
                bytes32(0),
                uint64(1),
                record
            )
        );
        (Snap.Publication memory stored, Snap.Receipt memory receipt) =
            snapshotHost.snapshotRecord(record);
        require(
            keccak256(abi.encode(stored)) == keccak256(abi.encode(publication)),
            "stored request keeps nonzero expectedSourceHash"
        );
        require(
            keccak256(abi.encode(receipt)) == keccak256(abi.encode(expected)),
            "all receipt words exact"
        );
        require(
            logs.length == 1 && logs[0].emitter == address(snapshotHost)
                && logs[0].topics.length == 4,
            "event emitted by original host"
        );
        require(
            logs[0].topics[0]
                == keccak256(
                    "ScopedPolicySnapshotPublished(uint16,bytes32,bytes32,bytes32,((uint8,uint256,uint256,bytes32),bytes32,bytes32,uint64,bytes32,bytes32,bytes32,string,uint64,bytes32),(bytes32,bytes32,bytes32,uint64,bytes32,bytes32,uint32,bytes32,address,uint8,uint64,uint8,uint64,uint64,bytes32,bytes32,bytes32))"
                ),
            "original event signature"
        );
        (
            uint16 eventVersion,
            Snap.Publication memory eventPublication,
            Snap.Receipt memory eventReceipt
        ) = abi.decode(logs[0].data, (uint16, Snap.Publication, Snap.Receipt));
        require(
            eventVersion == 2 && logs[0].topics[1] == expected.scopeSubject
                && logs[0].topics[2] == publication.snapshotId && logs[0].topics[3] == record
                && keccak256(abi.encode(eventPublication, eventReceipt))
                    == keccak256(abi.encode(stored, receipt)),
            "original event and storage agree"
        );
        require(
            keccak256(snapshotHost.snapshotPayload(record)) == keccak256(raw),
            "complete immutable payload"
        );
        require(
            snapshotHost.requireCurrent(publication.scope, record, 1).recordHash == record,
            "restored currentness"
        );
        vm.expectRevert(abi.encodeWithSelector(Snap.InvalidScopedPolicySnapshot.selector));
        vm.prank(publisher);
        snapshotHost.publishSnapshot(publication);
        require(
            snapshotHost.snapshotCount(publication.scope) == 1
                && snapshotHost.snapshotAt(publication.scope, 0) == record,
            "replay cannot append"
        );
        require(
            keccak256(snapshotHost.snapshotPayload(record)) == keccak256(raw),
            "replay keeps original bytes"
        );
    }

    bytes32 private constant SNAPSHOT_ARTIST = keccak256("scoped snapshot locked artist boundary");
    StaticRouteVm private constant snapshotVm = StaticRouteVm(address(vm));
    LeafManifestVm private constant createVm = LeafManifestVm(address(vm));
    StreamSchemaDocumentStore private snapshotStore;
    StreamFinalityArtifactCoverage private snapshotCoverage;
    LeafManifestArchiveBoundary private snapshotArchive;
    ContentHost private snapshotContent;
    OutputHost private snapshotOutputs;
    Snapshot private snapshotHost;
    Snap.Publication private publication;
    Serving.ArtistPresentation private lockedArtistBoundary;

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
            require(version == 2 && logs[0].topics.length == 4);
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
        require(!snapshotHost.supportsInterface(type(CollectionPolicySnapshot).interfaceId));
        require(
            snapshotHost.scopedPolicySnapshotProfile()
                == keccak256("6529STREAM_SCOPED_POLICY_SNAPSHOT_V2")
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

    function testSuccessorLineageChangesCurrentHeadButPreservesOriginalPayloadAndReceipt() public {
        _initialize(1);
        _prepare(3);
        bytes32 first = _publish();
        bytes32 rawHash = keccak256(snapshotHost.snapshotPayload(first));
        bytes32 saved = _historyHash(first);
        Snap.Receipt memory previous = snapshotHost.currentSnapshot(publication.scope);
        ScopedPolicySnapshotReaderProbeV2 reader = new ScopedPolicySnapshotReaderProbeV2();
        SnapshotReads.Dependencies memory dependencies = _readerDependencies();
        StreamFinalitySnapshotEvidence memory evidence =
            reader.current(dependencies, publication.scope, first, 1);
        require(evidence.inputHash != 0 && !evidence.locked && evidence.recordHash == first);
        vm.expectRevert();
        snapshotHost.publishSnapshot(publication);
        publication.snapshotId = keccak256("second scoped snapshot");
        publication.expectedHead = first;
        publication.expectedRevision = 1;
        bytes32 second = _publish();
        require(first != second && snapshotHost.snapshotCount(publication.scope) == 2);
        Snap.Receipt memory r = snapshotHost.requireCurrent(publication.scope, second, 2);
        require(r.predecessor == first && r.revision == 2);
        require(
            r.chainHash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_SCOPED_POLICY_SNAPSHOT_CHAIN_V2"),
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
        vm.expectRevert();
        snapshotHost.requireCurrent(publication.scope, first, 1);
        vm.expectRevert();
        reader.current(dependencies, publication.scope, first, 1);
        (, Snap.Receipt memory original) =
            reader.original(dependencies, publication.scope, first, 1);
        require(keccak256(abi.encode(original)) == keccak256(abi.encode(previous)));
        require(reader.current(dependencies, publication.scope, second, 2).recordHash == second);
        require(
            _historyHash(first) == saved
                && keccak256(snapshotHost.snapshotPayload(first)) == rawHash
        );
        require(snapshotHost.snapshotAt(publication.scope, 0) == first);
        require(snapshotHost.snapshotAt(publication.scope, 1) == second);
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

    function testRendererAdmissionAndRenderedSourceDriftPreserveOriginalHistory() public {
        _initialize(1);
        _prepare(3);
        bytes32 hash = _publish();
        bytes32 saved = _historyHash(hash);
        terminalVersions.setAdmitted(false);
        vm.expectRevert();
        snapshotHost.requireCurrent(publication.scope, hash, 1);
        terminalVersions.setAdmitted(true);
        attribution.setFail(true);
        vm.expectRevert();
        snapshotHost.requireCurrent(publication.scope, hash, 1);
        attribution.setFail(false);
        require(_historyHash(hash) == saved);
        require(snapshotHost.requireCurrent(publication.scope, hash, 1).recordHash == hash);
    }

    function testOnlyExactClassTwoActionLocksCurrentSnapshotAndPreventsSuccessor() public {
        _initialize(1);
        _prepare(2);
        bytes32 hash = _publish();
        (bytes32 scope, bytes32 oldState, bytes32 newState) =
            snapshotHost.lockTransition(publication.scope);
        ScopedPolicySnapshotReaderProbeV2 reader = new ScopedPolicySnapshotReaderProbeV2();
        SnapshotReads.Dependencies memory dependencies = _readerDependencies();
        StreamFinalitySnapshotEvidence memory unlocked =
            reader.current(dependencies, publication.scope, hash, 1);
        require(!unlocked.locked);
        vm.expectRevert();
        reader.locked(dependencies, publication.scope, hash, 1);
        vm.expectRevert();
        snapshotHost.lockSnapshot(publication.scope);
        _lockAction(1, scope, oldState, newState);
        vm.expectRevert();
        vm.prank(address(executor));
        snapshotHost.lockSnapshot(publication.scope);
        _lockAction(2, scope, oldState, newState ^ bytes32(uint256(1)));
        vm.expectRevert();
        vm.prank(address(executor));
        snapshotHost.lockSnapshot(publication.scope);
        require(snapshotHost.snapshotLock(publication.scope).actionId == 0);
        _lockAction(2, scope, oldState, newState);
        terminalVersions.setAdmitted(false);
        vm.expectRevert();
        vm.prank(address(executor));
        snapshotHost.lockSnapshot(publication.scope);
        terminalVersions.setAdmitted(true);
        vm.recordLogs();
        vm.prank(address(executor));
        snapshotHost.lockSnapshot(publication.scope);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        (uint16 version, Snap.Lock memory eventLock) = abi.decode(logs[0].data, (uint16, Snap.Lock));
        Snap.Lock memory locked = snapshotHost.snapshotLock(publication.scope);
        require(logs.length == 1 && logs[0].emitter == address(snapshotHost) && version == 2);
        require(keccak256(abi.encode(eventLock)) == keccak256(abi.encode(locked)));
        require(
            locked.recordHash == hash && locked.revision == 1
                && locked.actionId == keccak256("exact class two snapshot lock")
        );
        publication.snapshotId = keccak256("successor after lock");
        StreamFinalitySnapshotEvidence memory evidence =
            reader.locked(dependencies, publication.scope, hash, 1);
        require(
            evidence.locked && evidence.recordHash == hash
                && evidence.inputHash != unlocked.inputHash
        );
        require(
            evidence.lockEvidenceHash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_FINALITY_SCOPED_POLICY_SNAPSHOT_LOCK_V2"),
                        block.chainid,
                        address(snapshotHost),
                        publication.scope,
                        locked
                    )
                )
        );
        publication.expectedHead = hash;
        publication.expectedRevision = 1;
        vm.expectRevert();
        snapshotHost.previewSnapshot(publication, address(this));
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

    function testTypedReaderRejectsWrongProfileCapabilityPinsAndRevisionBeforeTrustingReceipt()
        public
    {
        _initialize(1);
        _prepare(1);
        bytes32 hash = _publish();
        ScopedPolicySnapshotReaderProbeV2 reader = new ScopedPolicySnapshotReaderProbeV2();
        SnapshotReads.Dependencies memory d = _readerDependencies();
        require(reader.current(d, publication.scope, hash, 1).recordHash == hash);
        snapshotVm.mockCall(
            address(snapshotHost),
            abi.encodeCall(SnapshotInterface.scopedPolicySnapshotProfile, ()),
            abi.encode(keccak256("original or collection snapshot profile"))
        );
        vm.expectRevert();
        reader.original(d, publication.scope, hash, 1);
        snapshotVm.mockCall(
            address(snapshotHost),
            abi.encodeCall(SnapshotInterface.scopedPolicySnapshotProfile, ()),
            abi.encode(keccak256("6529STREAM_SCOPED_POLICY_SNAPSHOT_V2"))
        );
        snapshotVm.mockCall(
            address(snapshotHost),
            abi.encodeWithSignature(
                "supportsInterface(bytes4)", type(SnapshotInterface).interfaceId
            ),
            abi.encode(false)
        );
        vm.expectRevert();
        reader.current(d, publication.scope, hash, 1);
        snapshotVm.mockCall(
            address(snapshotHost),
            abi.encodeWithSignature(
                "supportsInterface(bytes4)", type(SnapshotInterface).interfaceId
            ),
            abi.encode(true)
        );
        vm.expectRevert();
        reader.original(d, publication.scope, hash, 2);
        d.routerCodeHash ^= bytes32(uint256(1));
        vm.expectRevert();
        reader.original(d, publication.scope, hash, 1);
        d = _readerDependencies();
        bytes memory originalFactory = address(scopedFactory).code;
        vm.etch(address(scopedFactory), hex"00");
        vm.expectRevert();
        reader.current(d, publication.scope, hash, 1);
        // Historical authentication remains available when current output eligibility fails.
        (, Snap.Receipt memory r) = reader.original(d, publication.scope, hash, 1);
        require(r.recordHash == hash);
        vm.etch(address(scopedFactory), originalFactory);
        require(reader.current(d, publication.scope, hash, 1).recordHash == hash);
    }

    function testWrongFactoryCurrentPlanAndAuthoritativeMembershipRejectCurrentKeepHistory()
        public
    {
        _initialize(1);
        _prepare(2);
        bytes32 hash = _publish();
        bytes32 saved = _historyHash(hash);
        ScopedPolicySnapshotReaderProbeV2 reader = new ScopedPolicySnapshotReaderProbeV2();
        SnapshotReads.Dependencies memory d = _readerDependencies();
        bytes32 actualPlan = scopedFactory.currentInventoryPlan(publication.scope);
        snapshotVm.mockCall(
            address(scopedFactory),
            abi.encodeCall(FactoryReads.currentInventoryPlan, (publication.scope)),
            abi.encode(actualPlan ^ bytes32(uint256(1)))
        );
        vm.expectRevert();
        reader.current(d, publication.scope, hash, 1);
        (, Snap.Receipt memory retained) = reader.original(d, publication.scope, hash, 1);
        require(retained.recordHash == hash && _historyHash(hash) == saved);
        snapshotVm.mockCall(
            address(scopedFactory),
            abi.encodeCall(FactoryReads.currentInventoryPlan, (publication.scope)),
            abi.encode(actualPlan)
        );
        require(reader.current(d, publication.scope, hash, 1).recordHash == hash);
        StreamScopeMembershipFacts memory membership =
            scopedMembership.requireScopeMembership(publication.scope);
        bytes memory original = abi.encode(membership);
        membership.membershipHash ^= bytes32(uint256(1));
        snapshotVm.mockCall(
            address(scopedMembership),
            abi.encodeCall(MembershipReads.requireScopeMembership, (publication.scope)),
            abi.encode(membership)
        );
        vm.expectRevert();
        reader.current(d, publication.scope, hash, 1);
        (, retained) = reader.original(d, publication.scope, hash, 1);
        require(retained.recordHash == hash && _historyHash(hash) == saved);
        snapshotVm.mockCall(
            address(scopedMembership),
            abi.encodeCall(MembershipReads.requireScopeMembership, (publication.scope)),
            original
        );
        require(reader.current(d, publication.scope, hash, 1).recordHash == hash);
    }

    function testTokenCollectionTupleCannotAliasCurrentHeadOrClassTwoLock() public {
        _initialize(1);
        _prepare(1);
        bytes32 hash = _publish();
        bytes32 saved = _historyHash(hash);
        StreamFinalityScope memory wrong = publication.scope;
        wrong.collectionId = 2;
        require(wrong.tokenId == publication.scope.tokenId);
        vm.expectRevert();
        snapshotHost.currentSnapshot(wrong);
        vm.expectRevert();
        snapshotHost.requireCurrent(wrong, hash, 1);
        vm.expectRevert();
        snapshotHost.lockTransition(wrong);
        ScopedPolicySnapshotReaderProbeV2 reader = new ScopedPolicySnapshotReaderProbeV2();
        SnapshotReads.Dependencies memory d = _readerDependencies();
        vm.expectRevert();
        reader.current(d, wrong, hash, 1);
        vm.expectRevert();
        reader.original(d, wrong, hash, 1);
        bytes32 wrongScope = keccak256(
            abi.encode(
                keccak256("6529STREAM_SCOPED_POLICY_SNAPSHOT_LOCK_V2"),
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
        vm.expectRevert();
        vm.prank(address(executor));
        snapshotHost.lockSnapshot(wrong);
        require(snapshotHost.snapshotLock(publication.scope).actionId == 0);
        require(_historyHash(hash) == saved && snapshotHost.snapshotCount(publication.scope) == 1);
        require(snapshotHost.currentSnapshot(publication.scope).recordHash == hash);
        require(reader.current(d, publication.scope, hash, 1).recordHash == hash);
    }

    function testGenuineSnapshotAdoptsIntoOriginalRouterAndRemainsCurrentAfterRootPublication()
        public
    {
        _initialize(1);
        _prepare(2);
        _configureJoinedRootBoundary();
        bytes32 snapshot = _publish();
        bytes32 history = _historyHash(snapshot);
        Snap.Source memory source = _source(snapshotHost.snapshotPayload(snapshot));
        require(source.entropy.policyCount == 2);
        ScopedRoot.Publication memory p = ScopedRoot.Publication(
            publication.scope, 0, snapshot, 1, "ipfs://genuine-scoped-policy-root"
        );
        bytes32 nextFamily = router.previewScopedPolicyContentRootPublication(p, address(this));
        bytes32 consent = keccak256("explicit Artist root op17 consent boundary");
        artist.approve(1, keccak256("CONTENT_ROOT"), nextFamily, consent);
        bytes32 root = router.publishScopedPolicyContentRootPublication(p);
        ScopedRoot.Record memory record = router.scopedContentRootRecord(root);
        PolicyRoot.Binding memory binding = router.scopedPolicyContentRootBinding(root);
        require(root != 0 && router.scopedContentRootHead(publication.scope) == root);
        require(
            record.publication.snapshotRecordHash == snapshot
                && record.publication.snapshotRevision == 1
        );
        require(
            record.snapshotHost == address(snapshotHost)
                && record.snapshotCodeHash == address(snapshotHost).codehash
        );
        require(
            record.snapshotManifestHash
                == snapshotHost.currentSnapshot(publication.scope).manifestHash
        );
        require(
            record.contentRoot == source.outputs.contentRoot && record.leafCount == 2
                && record.artistConsent == consent
        );
        require(binding.profileId == RootDocuments.PROFILE);
        require(
            binding.sourceFactory == address(scopedFactory)
                && binding.sourceFactoryCodeHash == address(scopedFactory).codehash
        );
        require(binding.factoryDependenciesHash == keccak256(abi.encode(_scopedDependencies())));
        require(
            binding.checkpoint == address(snapshotContent)
                && binding.outputManifest == address(snapshotOutputs)
        );
        require(binding.entropySourceSet == snapshotContent.entropySourceSet());
        require(
            binding.inventoryHash == source.content.inventoryHash
                && binding.policyChainHash == source.content.policyChainHash
        );
        require(binding.outputRoot == source.outputs.outputRoot);
        ScopedRoot.Aggregate memory aggregate = router.scopedContentRootAggregate(1);
        require(aggregate.revision == 1 && aggregate.transitionChain != 0);
        require(
            root
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_SCOPED_POLICY_CONTENT_ROOT_RECORD_V2"),
                        block.chainid,
                        address(router),
                        address(core),
                        record,
                        binding,
                        aggregate
                    )
                )
        );
        (bytes32 contentRoot, uint64 leafCount, bytes32 leafSchema) =
            router.scopedTokenContentRoot(publication.scope);
        require(
            contentRoot == source.outputs.contentRoot && leafCount == 2
                && leafSchema == OutputDocuments.LEAF_SCHEMA
        );
        // The source payload contains no adopted root. Actual Router publication must not stale it.
        require(snapshotHost.requireCurrent(publication.scope, snapshot, 1).recordHash == snapshot);
        require(
            _historyHash(snapshot) == history && snapshotHost.snapshotCount(publication.scope) == 1
        );
        require(
            snapshotOutputs.requireCurrentManifest(
                publication.outputManifestRecord, SNAPSHOT_ARTIST
            )
            .contentRoot == contentRoot
        );
        require(snapshotCoverage.finalityRegistry() == _joinedFinalityAddress());
    }

    function _configureJoinedRootBoundary() private {
        _register(
            "STREAM_SCOPED_POLICY_TOKEN_CONTENT_LEAF_V2",
            Schema.DocumentKind.SCHEMA,
            OutputDocuments.document(OutputDocuments.LEAF_SCHEMA)
        );
        _register(
            "STREAM_SCOPED_POLICY_CONTENT_ROOT_RECORD_V2",
            Schema.DocumentKind.SCHEMA,
            RootDocuments.document(RootDocuments.ROOT_SCHEMA)
        );
        _register(
            "STREAM_ABI_SCOPED_POLICY_CONTENT_ROOT_RECORD_V2",
            Schema.DocumentKind.CANONICALIZATION,
            RootDocuments.document(RootDocuments.ROOT_CANON)
        );
        ScopedPolicySnapshotRootProviderBoundaryV2 provider = new ScopedPolicySnapshotRootProviderBoundaryV2(
            address(snapshotHost), publication.scope
        );
        // Keep the coverage constructor's original selected Finality and runtime pin. Only these
        // missing deployment/read capabilities of that explicitly named boundary are supplied.
        address finality = _joinedFinalityAddress();
        _mockWord(finality, "scopeEvidenceProvider()", abi.encode(address(provider)));
        _mockWord(
            finality, "scopeEvidenceProviderCodeHash()", abi.encode(address(provider).codehash)
        );
        _mockWord(finality, "coreReads()", abi.encode(address(core)));
        _mockWord(finality, "metadataReads()", abi.encode(address(metadata)));
        _mockWord(finality, "sanctionReads()", abi.encode(address(artist)));
        snapshotVm.mockCall(
            finality,
            abi.encodeCall(
                Gas.gasParameter, (keccak256("6529STREAM_GGP_FINALITY_COMPONENT_READ_GAS"))
            ),
            abi.encode(uint256(2000000))
        );
        snapshotVm.mockCall(
            finality,
            abi.encodeWithSignature(
                "artworkFreezeMode((uint8,uint256,uint256,bytes32))", publication.scope
            ),
            abi.encode(uint8(0))
        );
        _mockWord(address(artist), "finalityRegistry()", abi.encode(finality));
        _mockWord(address(artist), "finalityRegistryCodeHash()", abi.encode(finality.codehash));
        snapshotVm.mockCall(
            address(artist),
            abi.encodeWithSignature("collectionArtistState(uint256)", uint256(1)),
            abi.encode(
                uint8(2),
                lockedArtistBoundary.bindingGeneration,
                SNAPSHOT_ARTIST,
                uint8(1),
                lockedArtistBoundary.bindingHash
            )
        );
    }

    function _joinedFinalityAddress() private view returns (address finality) {
        (finality,,,,,,,,,) = core.getSatellitePointer(keccak256("ARTWORK_FINALITY_REGISTRY"));
    }

    function _mockWord(address target, string memory selector, bytes memory value) private {
        snapshotVm.mockCall(target, abi.encodeWithSignature(selector), value);
    }

    function _initialize(uint8 terminalStatus) private {
        _scopedFixture(terminalStatus, true);
        snapshotStore = StreamSchemaDocumentStore(schemas.chunkStore());
        _register(
            "STREAM_SCOPED_POLICY_OUTPUT_MANIFEST_V2",
            Schema.DocumentKind.SCHEMA,
            OutputDocuments.document(OutputDocuments.SCHEMA)
        );
        _register(
            "STREAM_ABI_SCOPED_POLICY_OUTPUT_MANIFEST_V2",
            Schema.DocumentKind.CANONICALIZATION,
            OutputDocuments.document(OutputDocuments.CANON)
        );
        _register(
            "STREAM_SCOPED_POLICY_SNAPSHOT_ABI_V2",
            Schema.DocumentKind.SCHEMA,
            SnapshotDocuments.document(SnapshotDocuments.SCHEMA_ID)
        );
        _register(
            "STREAM_SCOPED_POLICY_SNAPSHOT_PROFILE_V2",
            Schema.DocumentKind.CATALOG,
            SnapshotDocuments.document(SnapshotDocuments.PROFILE_ID)
        );
        _register(
            "STREAM_ABI_SCOPED_POLICY_SNAPSHOT_V2",
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

    function _prepare(uint8 kind) private {
        StreamFinalityScope memory scope = _scopedScope(kind);
        bytes32 selected;
        (snapshotContent, selected) = _scopedCapture(scope);
        bytes32 checkpoint =
            snapshotContent.begin(selected, keccak256("original scoped snapshot output"));
        snapshotContent.append(checkpoint, _scopedPayload(scope));
        Content.Plan memory p = snapshotContent.requireCurrentCheckpoint(checkpoint);
        Content.Output[] memory rows = new Content.Output[](p.tokenCount);
        for (uint256 i; i < rows.length; ++i) {
            rows[i] = snapshotContent.outputAt(checkpoint, i);
        }
        bytes memory raw = abi.encode(
            OutputDocuments.SCHEMA,
            block.chainid,
            address(core),
            address(snapshotContent),
            checkpoint,
            keccak256(abi.encode(p)),
            snapshotContent.entropySourceSet(),
            p.inventoryHash,
            p.policyChainHash,
            p.scope,
            p.contentRoot,
            p.outputRoot,
            p.tokenCount,
            rows
        );
        (bytes32 artifact, bytes32 coverage) = _archive(raw);
        snapshotOutputs = new OutputHost(
            address(core),
            address(snapshotContent),
            address(snapshotCoverage),
            address(executor),
            Gas.GasParameterConfig("STATIC_OUTPUT_MANIFEST_READ_GAS", 32000000, 100000, 2)
        );
        bytes32 plan =
            snapshotOutputs.beginManifest(checkpoint, artifact, coverage, SNAPSHOT_ARTIST);
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
            keccak256(abi.encode("scoped snapshot", kind)),
            0,
            0,
            output,
            SourceSet(d.targets[10]).inventoryPlan(),
            0,
            "ipfs://scoped-policy-snapshot",
            1000,
            keccak256("complete original native policies and output")
        );
    }

    function _snapshotGas() private pure returns (Gas.GasParameterConfig[3] memory configs) {
        // Reserve genuine nested checkpoint/render reads; these caps are not a gas acceptance claim.
        configs[0] = Gas.GasParameterConfig("SCOPED_POLICY_SNAPSHOT_READ_GAS", 2000000, 50000, 2);
        configs[1] = Gas.GasParameterConfig("SCOPED_POLICY_SNAPSHOT_SOURCE_GAS", 64000000, 50000, 2);
        configs[2] =
            Gas.GasParameterConfig("SCOPED_POLICY_SNAPSHOT_INVENTORY_GAS", 8000000, 50000, 2);
    }

    function _readerDependencies() private view returns (SnapshotReads.Dependencies memory) {
        // The outer reader must reserve the producer's 64m full-output cap as well.
        return SnapshotReads.Dependencies(
            address(core),
            address(metadata),
            address(router),
            address(snapshotHost),
            address(core).codehash,
            address(metadata).codehash,
            address(router).codehash,
            address(snapshotHost).codehash,
            block.chainid,
            2000000,
            128000000
        );
    }

    function _assertPayload(bytes memory raw, uint256 count) private view {
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
            domain == keccak256("6529STREAM_SCOPED_POLICY_SNAPSHOT_PAYLOAD_V2")
                && chain == block.chainid
        );
        require(producer == address(snapshotHost) && targets[0] == address(core));
        require(targets[2] == address(schemas) && targets[3] == address(snapshotStore));
        for (uint256 i; i < targets.length; ++i) {
            require(runtimes[i] == targets[i].codehash);
        }
        require(p.expectedSourceHash == 0 && r.sourceHash == publication.expectedSourceHash);
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

    function _assertRecordIdentity(bytes32 hash, Snap.Receipt memory r) private view {
        r.recordHash = 0;
        r.chainHash = 0;
        require(
            hash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_SCOPED_POLICY_SNAPSHOT_RECORD_V2"),
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

    function _source(bytes memory raw) private pure returns (Snap.Source memory f) {
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

    function _historyHash(bytes32 hash) private view returns (bytes32) {
        (Snap.Publication memory p, Snap.Receipt memory r) = snapshotHost.snapshotRecord(hash);
        return keccak256(abi.encode(p, r, snapshotHost.snapshotPayload(hash)));
    }

    function _setLockedArtistBoundary() private {
        snapshotVm.mockCall(
            address(router),
            abi.encodeCall(Serving.artistPresentation, (uint256(1))),
            abi.encode(lockedArtistBoundary)
        );
    }

    function _lockAction(uint8 cls, bytes32 scope, bytes32 oldState, bytes32 next) private {
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
    ) private {
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

    function _preview(address publisher) private returns (bytes memory raw) {
        (bytes32 source, bytes memory canonical) =
            snapshotHost.previewSnapshot(publication, publisher);
        publication.expectedSourceHash = source;
        return canonical;
    }

    function _publish() private returns (bytes32) {
        _upload(_preview(address(this)), false);
        return snapshotHost.publishSnapshot(publication);
    }

    function _upload(bytes memory raw, bool omitLast) private {
        uint256 count = (raw.length + 8191) / 8192;
        for (uint256 i; i < count - (omitLast ? 1 : 0); ++i) {
            snapshotStore.publishChunk(_chunk(raw, i));
        }
    }

    function _archive(bytes memory raw) private returns (bytes32 artifact, bytes32 coverage) {
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

    function _register(string memory name, Schema.DocumentKind kind, bytes memory raw) private {
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

    function _chunk(bytes memory raw, uint256 index) private pure returns (bytes memory part) {
        uint256 take = raw.length - index * 8192;
        if (take > 8192) take = 8192;
        part = new bytes(take);
        for (uint256 i; i < take; ++i) {
            part[i] = raw[index * 8192 + i];
        }
    }
}
