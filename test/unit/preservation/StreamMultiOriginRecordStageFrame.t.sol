// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamMultiOriginRecordStages as Stages
} from "../../../smart-contracts/domains/preservation/StreamMultiOriginRecordStages.sol";
import {
    StreamRenderCriticalInventoryState as State
} from "../../../smart-contracts/domains/preservation/StreamRenderCriticalInventoryState.sol";
import {
    StreamMultiOriginInventoryState as Origins
} from "../../../smart-contracts/domains/preservation/StreamMultiOriginInventoryState.sol";
import {
    StreamPreservationTypedReferences as References
} from "../../../smart-contracts/domains/preservation/StreamPreservationTypedReferences.sol";
import {
    StreamPreservationOriginalReads as Originals
} from "../../../smart-contracts/domains/preservation/StreamPreservationOriginalReads.sol";
import {
    StreamPreservationInventoryChains as Chains
} from "../../../smart-contracts/domains/preservation/StreamPreservationInventoryChains.sol";
import {
    StreamArtistArchiveOriginTypes as O
} from "../../../smart-contracts/interfaces/stream/preservation/StreamArtistArchiveOriginTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamRenderCriticalSourceTypes as S
} from "../../../smart-contracts/interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../../smart-contracts/interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";
import {
    StreamConservationRecordTypes as C
} from "../../../smart-contracts/interfaces/stream/metadata/StreamConservationRecordTypes.sol";
import {
    IStreamArtistArchiveOriginReads as Reads
} from "../../../smart-contracts/interfaces/stream/preservation/IStreamArtistArchiveOriginReads.sol";
import "../../../smart-contracts/interfaces/stream/metadata/IStreamConservationRecordSelection.sol";
import "../../../smart-contracts/interfaces/stream/metadata/IStreamCollectionMetadataV1.sol";
import "../../../smart-contracts/domains/records/StreamArtistIntentJson.sol";
import "../../../smart-contracts/domains/records/StreamArtistIntentWaiverJson.sol";

interface RecordFrameVm {
    struct Log {
        bytes32[] topics;
        bytes data;
        address emitter;
    }
    function mockCall(address, bytes calldata, bytes calldata) external;
    function etch(address, bytes calldata) external;
    function expectRevert() external;
    function expectRevert(bytes4) external;
    function expectRevert(bytes calldata) external;
    function recordLogs() external;
    function getRecordedLogs() external returns (Log[] memory);
}

contract RecordFramePin {
    function core() external view returns (address) {
        return address(this);
    }

    function archiveCoverage() external view returns (address) {
        return address(this);
    }
}

/// @dev Synthetic pre-stage storage and canonical source responses; the actual stage,
/// reference/original readers, origin table and segment chain execute without replacement.
contract RecordStageFrameHarness {
    State.State private state;
    Origins.State private origins;

    function seed(
        bytes32 id,
        S.Dependencies memory d,
        S.Context memory c,
        O.Origin memory initial,
        bytes32 context
    ) external {
        state.dependencies = d;
        state.contexts[id] = c;
        state.plans[id].collectionId = c.collectionId;
        state.plans[id].sourceContextHash = context;
        state.plans[id].completedStages = 4;
        origins.dependencies = O.Dependencies(d.targets[0], d.codeHashes[0], 2_000_000, O.PROFILE);
        Origins.initialize(origins, id, initial, initial, keccak256("synthetic lineage"));
    }

    function appendIntent(bytes32, C.Intent calldata, address, O.ReceiptWitness calldata) external {
        Stages.appendIntent(state, origins, msg.data);
    }

    function appendIntentWaiver(
        bytes32,
        C.IntentWaiver calldata,
        address,
        O.ReceiptWitness calldata
    ) external {
        Stages.appendIntentWaiver(state, origins, msg.data);
    }

    function raw(bool waiver, bytes calldata input) external {
        if (waiver) Stages.appendIntentWaiver(state, origins, input);
        else Stages.appendIntent(state, origins, input);
    }

    function setSegmentCount(bytes32 id, uint64 count) external {
        state.plans[id].segmentCount = count;
    }

    function setStage(bytes32 id, uint16 stage) external {
        state.plans[id].completedStages = stage;
    }

    function plan(bytes32 id) external view returns (T.Plan memory) {
        return state.plans[id];
    }

    function segment(bytes32 id, uint64 index) external view returns (T.Segment memory) {
        return state.segments[id][index];
    }

    function count(bytes32 id) external view returns (uint256) {
        return origins.origins[id].length;
    }

    function record(bytes32 id, bytes32 key) external view returns (O.RecordOrigin memory) {
        return origins.records[id][key];
    }

    function stateHash(bytes32 id, bytes32 key) external view returns (bytes32) {
        return keccak256(
            abi.encode(
                state.plans[id],
                state.contexts[id],
                origins.chain[id],
                origins.origins[id].length,
                origins.records[id][key]
            )
        );
    }
}

/// @notice Regression for the private ParentFrame: flat call ABI, dynamic row order,
/// original actor/receipt forwarding, events and rollback after origin admission.
/// @dev Component fixtures do not establish genuine Metadata/Archive or migration validity.
contract StreamMultiOriginRecordStageFrameTest {
    RecordFrameVm private constant vm =
        RecordFrameVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    bytes32 private constant ID = keccak256("frame plan");
    bytes32 private constant CONTEXT = keccak256("frame source context");
    bytes32 private constant RECORD = keccak256("selected original record");
    bytes32 private constant ROLE = keccak256("ORIGINAL_ARTIST_PUBLICATION_AUTHORIZATION");
    address private constant ACTOR = address(0xa123);
    address private constant PAYLOAD = address(0xb123);
    RecordStageFrameHarness private host;
    S.Dependencies private dependencies;
    S.Context private context;
    C.Intent private intent;
    C.IntentWaiver private waiver;
    O.ReceiptWitness private witness;
    T.Item private publication;
    O.RecordOrigin private original;

    function testIntentFlatAbiPreservesThirteenOrderedRowsAndOriginalReceipt() public {
        _prepare(false, O.Lane.NATIVE);
        _assertAppend(false, 13);
    }

    function testWaiverFlatAbiPreservesFiveOrderedRowsAndImportedReceipt() public {
        _prepare(true, O.Lane.IMPORTED);
        _assertAppend(true, 5);
    }

    function testWrongActorAndReceiptRevertWithoutOriginOrSegmentWrites() public {
        _prepare(true, O.Lane.IMPORTED);
        bytes32 before_ = host.stateHash(ID, Chains.itemHash(publication));
        vm.expectRevert();
        host.appendIntentWaiver(ID, waiver, address(0xdead), witness);
        O.ReceiptWitness memory wrong = witness;
        wrong.index += 1;
        vm.expectRevert();
        host.appendIntentWaiver(ID, waiver, ACTOR, wrong);
        wrong = witness;
        wrong.lane = O.Lane.NATIVE;
        vm.expectRevert();
        host.appendIntentWaiver(ID, waiver, ACTOR, wrong);
        require(
            host.stateHash(ID, Chains.itemHash(publication)) == before_,
            "failed locator rebound writes"
        );
        _assertAppend(true, 5);
    }

    function testLateSegmentOverflowRollsBackOriginAdmissionAndAllowsIdenticalRetry() public {
        _prepare(false, O.Lane.NATIVE);
        host.setSegmentCount(ID, type(uint64).max);
        bytes32 before_ = host.stateHash(ID, Chains.itemHash(publication));
        vm.expectRevert(abi.encodeWithSignature("Panic(uint256)", uint256(0x11)));
        host.appendIntent(ID, intent, ACTOR, witness);
        require(
            host.stateHash(ID, Chains.itemHash(publication)) == before_, "late failure rollback"
        );
        require(
            host.count(ID) == 1 && host.segment(ID, type(uint64).max).key == 0,
            "no partial origin/segment"
        );
        host.setSegmentCount(ID, 0);
        _assertAppend(false, 13);
    }

    function testWrongKindStagePayloadAndMalformedFlatCallRemainRejected() public {
        _prepare(true, O.Lane.NATIVE);
        bytes32 before_ = host.stateHash(ID, Chains.itemHash(publication));
        vm.expectRevert(T.InvalidInventoryItem.selector);
        host.appendIntent(ID, intent, ACTOR, witness);
        C.IntentWaiver memory changed = waiver;
        changed.waiverStatement.uri = "ipfs://changed-valid-reference";
        vm.expectRevert(T.InvalidInventoryItem.selector);
        host.appendIntentWaiver(ID, changed, ACTOR, witness);
        vm.expectRevert();
        host.raw(true, hex"12345678");
        require(
            host.stateHash(ID, Chains.itemHash(publication)) == before_, "rejected input writes"
        );
        host.setStage(ID, 3);
        vm.expectRevert(T.InventoryIncomplete.selector);
        host.appendIntentWaiver(ID, waiver, ACTOR, witness);
        require(host.plan(ID).completedStages == 3 && host.count(ID) == 1, "wrong stage writes");
    }

    function _assertAppend(bool isWaiver, uint256 expectedCount) private {
        T.Item[] memory refs = isWaiver
            ? References.waiver(
                dependencies.targets[1], RECORD, context.conservation.record.payloadHash, waiver
            )
            : References.intent(
                dependencies.targets[1], RECORD, context.conservation.record.payloadHash, intent
            );
        T.Item[] memory originalRows =
            Originals.items(dependencies, context, RECORD, context.conservation.record.payloadHash);
        T.Item[] memory expected = new T.Item[](originalRows.length + 1 + refs.length);
        for (uint256 i; i < originalRows.length; ++i) {
            expected[i] = originalRows[i];
        }
        expected[originalRows.length] = publication;
        for (uint256 i; i < refs.length; ++i) {
            expected[originalRows.length + 1 + i] = refs[i];
        }
        require(
            expected.length == expectedCount
                && expected[0].role == keccak256("ORIGINAL_METADATA_RECORD_AND_RECEIPT")
                && expected[1].role == keccak256("ORIGINAL_TYPED_METADATA_PAYLOAD")
                && expected[2].role == ROLE,
            "original order"
        );
        bytes32 key = keccak256(
            abi.encode(keccak256("6529STREAM_RENDER_CRITICAL_SEGMENT_V1"), ID, uint64(0))
        );
        T.Segment memory expectedSegment =
            Chains.segment(key, context.conservation.selectionHash, expected);
        vm.recordLogs();
        if (isWaiver) host.appendIntentWaiver(ID, waiver, ACTOR, witness);
        else host.appendIntent(ID, intent, ACTOR, witness);
        RecordFrameVm.Log[] memory logs = vm.getRecordedLogs();
        require(
            logs.length == 1 && logs[0].emitter == address(host) && logs[0].topics.length == 3
                && logs[0].topics[1] == ID && logs[0].topics[2] == bytes32(0),
            "one host event with plan/index"
        );
        require(
            keccak256(logs[0].data) == keccak256(abi.encode(expectedSegment, expected)),
            "complete event rows and segment"
        );
        T.Plan memory p = host.plan(ID);
        require(
            p.completedStages == 5 && p.segmentCount == 1 && p.itemCount == expectedCount,
            "stage counts"
        );
        require(
            p.segmentChainHash == Chains.append(0, 0, expectedSegment)
                && keccak256(abi.encode(host.segment(ID, 0)))
                    == keccak256(abi.encode(expectedSegment)),
            "segment and chain"
        );
        require(
            host.count(ID) == 2
                && O.recordOriginHash(host.record(ID, Chains.itemHash(publication)))
                    == O.recordOriginHash(original),
            "original actor and receipt capsule"
        );
        vm.expectRevert(T.InventoryIncomplete.selector);
        if (isWaiver) host.appendIntentWaiver(ID, waiver, ACTOR, witness);
        else host.appendIntent(ID, intent, ACTOR, witness);
    }

    function _prepare(bool isWaiver, O.Lane lane) private {
        host = new RecordStageFrameHarness();
        address pin = address(new RecordFramePin());
        S.Dependencies memory d;
        d.chainId = block.chainid;
        d.readGas = 2_000_000;
        d.sourceGas = d.readGas;
        d.selectionGas = d.readGas;
        d.snapshotGas = d.readGas;
        d.referenceGas = d.readGas;
        for (uint256 i; i < 12; ++i) {
            d.targets[i] = pin;
            d.codeHashes[i] = pin.codehash;
        }
        for (uint256 i; i < 5; ++i) {
            d.artistTargets[i] = pin;
            d.artistCodeHashes[i] = pin.codehash;
        }
        d.artistContentOwner = pin;
        d.artistContentOwnerCodeHash = pin.codehash;
        dependencies = d;
        _witnesses();
        bytes memory payload = isWaiver
            ? StreamArtistIntentWaiverJson.serialize(waiver)
            : StreamArtistIntentJson.serialize(intent);
        S.Context memory c;
        c.collectionId = 7;
        c.subject = keccak256("frame subject");
        c.conservation.selectionHash = keccak256("original selection");
        c.conservation.record.kind = isWaiver
            ? IStreamConservationRecordSelection.RecordKind.INTENT_WAIVER
            : IStreamConservationRecordSelection.RecordKind.INTENT;
        c.conservation.record.recordHash = RECORD;
        c.conservation.record.payloadHash = keccak256(payload);
        c.conservation.record.publication.attestationRecordHash = keccak256("original receipt");
        context = c;
        witness = O.ReceiptWitness(lane, lane == O.Lane.NATIVE ? 5 : 9);
        _originalMetadata(pin, c, payload);
        _publication(pin, c, lane);
        host.seed(ID, d, c, _origin(pin, 1), CONTEXT);
    }

    function _originalMetadata(address pin, S.Context memory c, bytes memory payload) private {
        IStreamPreservationRecords.CollectionRecord memory r;
        r.recordType = keccak256("original type");
        r.subjectId = c.subject;
        r.schemaId = keccak256("original schema");
        r.contentHash = IStreamPreservationRecords.HashRef(
            1, abi.encodePacked(keccak256(payload)), keccak256("RFC8785_JCS")
        );
        IStreamCollectionMetadataV1.RecordReceipt memory receipt;
        receipt.collectionId = c.collectionId;
        receipt.recorder = ACTOR;
        receipt.recordedAt = 1;
        receipt.recordIndex = 6;
        receipt.recordChainHash = keccak256("original chain");
        vm.etch(PAYLOAD, bytes.concat(hex"00", payload));
        vm.mockCall(
            pin,
            abi.encodeCall(IStreamCollectionMetadataV1.collectionRecord, (RECORD)),
            abi.encode(r, receipt)
        );
        vm.mockCall(
            pin,
            abi.encodeCall(
                IStreamCollectionMetadataV1.deriveCollectionRecordHashFor,
                (ACTOR, c.collectionId, r)
            ),
            abi.encode(RECORD)
        );
        vm.mockCall(
            pin,
            abi.encodeCall(
                IStreamCollectionMetadataV1.recordHashAt, (c.collectionId, r.recordType, uint256(6))
            ),
            abi.encode(RECORD)
        );
        vm.mockCall(
            pin,
            abi.encodeCall(IStreamCollectionMetadataV1.recordPayload, (RECORD)),
            abi.encode(PAYLOAD, payload)
        );
    }

    function _publication(address pin, S.Context memory c, O.Lane lane) private {
        O.RecordOrigin memory r;
        r.producer = _origin(pin, 2);
        r.actor = ACTOR;
        r.sourceContextHash = CONTEXT;
        r.role = ROLE;
        r.semanticRecordHash = keccak256("original semantic record");
        r.occurrence.position.point.environmentHash = RH.originHash(r.producer.environment);
        r.occurrence.position.point.ownerIndex = 4;
        r.occurrence.position.point.ownerRevision = 1;
        if (lane == O.Lane.NATIVE) r.occurrence.position.nativeIndex = witness.index;
        r.occurrence.receipt.operation = 24;
        r.occurrence.receipt.recordHash = c.conservation.record.publication.attestationRecordHash;
        if (lane == O.Lane.IMPORTED) {
            r.importCommitment = keccak256("import prefix");
            r.importedAtRevision = 3;
        }
        T.Item memory item;
        item.kind = T.Kind.STATE_BUNDLE;
        item.role = ROLE;
        item.source = pin;
        item.sourceRecord = O.evidenceId(r);
        item.sourceIndex = 1;
        item.algorithm = 1;
        item.canonicalizationId = keccak256("RAW");
        item.digest = abi.encodePacked(keccak256("original Archive bytes"));
        item.byteSize = 22;
        item.provenanceHash = O.recordOriginHash(r);
        publication = item;
        original = r;
        vm.mockCall(
            pin,
            abi.encodeCall(
                Reads.publicationItem,
                (dependencies, c.conservation.record.publication, RECORD, ACTOR, CONTEXT, witness)
            ),
            abi.encode(item, r)
        );
    }

    function _origin(address pin, uint256 n) private view returns (O.Origin memory o) {
        o.environment.chainId = block.chainid;
        o.environment.registry = pin;
        o.environment.coordinator = pin;
        o.environment.archive = pin;
        o.environment.core = pin;
        o.environment.manager = pin;
        o.environment.suiteConfigurationHash = keccak256(abi.encode(n));
        o.registryCodeHash = pin.codehash;
        o.coordinatorCodeHash = pin.codehash;
        o.archiveCodeHash = pin.codehash;
        for (uint256 i; i < 7; ++i) {
            o.environment.owners[i] = pin;
            o.environment.ownerCodeHashes[i] = pin.codehash;
        }
    }

    function _witnesses() private {
        C.ArtistClaim memory artist = C.ArtistClaim(
            keccak256("artist"), 1, keccak256("binding"), C.StatementOrigin.ARTIST_INTENT
        );
        C.InterviewEntry memory interview;
        interview.status = C.InterviewStatus.WAIVED;
        interview.waiverStatement = _reference("ipfs://independent-interview");
        C.Intent memory i;
        i.subjectId = keccak256("frame subject");
        i.profileHash = StreamConservationDefinitions.INTENT_PROFILE_HASH;
        i.artist = artist;
        i.display = C.Display(
            _reference("ipfs://scale"),
            _reference("ipfs://timing"),
            _reference("ipfs://color"),
            _reference("ipfs://interaction"),
            _reference("ipfs://motion"),
            _reference("ipfs://frame-rate")
        );
        i.variabilityTolerances = _reference("ipfs://variability");
        i.dependencyAging = _reference("ipfs://aging");
        i.significantProperties = _reference("ipfs://properties");
        i.interview = interview;
        intent = i;
        waiver = C.IntentWaiver(
            i.subjectId,
            StreamConservationDefinitions.WAIVER_PROFILE_HASH,
            0,
            artist,
            _reference("ipfs://intent-waiver"),
            interview
        );
    }

    function _reference(string memory uri) private pure returns (C.Reference memory) {
        return C.Reference(1, keccak256("RAW"), abi.encodePacked(keccak256(bytes(uri))), uri);
    }
}
