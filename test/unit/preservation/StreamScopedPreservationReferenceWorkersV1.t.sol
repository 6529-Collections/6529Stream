// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    ScopedPreservationReferenceFixtureV1
} from "./StreamScopedPreservationPolicyReferencePublicationV1.t.sol";
import {
    StreamScopedPreservationPolicyReferenceRecordsV1 as WorkerRecords
} from "../../../smart-contracts/domains/preservation/StreamScopedPreservationPolicyReferenceRecordsV1.sol";
import {
    StreamScopedPreservationReferenceSnapshotWorkerV1 as SnapshotWorker
} from "../../../smart-contracts/domains/preservation/StreamScopedPreservationReferenceSnapshotWorkerV1.sol";
import {
    StreamScopedPreservationReferenceRootWorkerV1 as RootWorker
} from "../../../smart-contracts/domains/preservation/StreamScopedPreservationReferenceRootWorkerV1.sol";
import {
    StreamScopedPreservationPolicyReferenceTypesV1 as WorkerT
} from "../../../smart-contracts/interfaces/stream/preservation/StreamScopedPreservationPolicyReferenceTypesV1.sol";
import {
    StreamScopedPreservationPolicySnapshotTypesV1 as WorkerS
} from "../../../smart-contracts/interfaces/stream/metadata/StreamScopedPreservationPolicySnapshotTypesV1.sol";
import {
    IStreamScopedPreservationPolicySnapshotPublicationV1 as SnapshotABI
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamScopedPreservationPolicySnapshotPublicationV1.sol";
import {
    IStreamScopedContentRootPublication as RootABI
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamScopedContentRootPublication.sol";
import {
    IStreamScopedPreservationPolicyContentRootPublicationV1 as BindingABI
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamScopedPreservationPolicyContentRootPublicationV1.sol";
import {
    IStreamPreservationPolicyOutputManifestV1 as OutputABI
} from "../../../smart-contracts/interfaces/stream/finality/IStreamPreservationPolicyOutputManifestV1.sol";
import {
    StreamPreservationTokenProducerProfilesV1 as WorkerProfiles
} from "../../../smart-contracts/interfaces/stream/finality/StreamPreservationTokenProducerProfilesV1.sol";
import {
    StreamPreservationPolicyReferenceFamiliesV2 as WorkerFamilies
} from "../../../smart-contracts/domains/preservation/StreamPreservationPolicyReferenceFamiliesV2.sol";
import {
    StreamFinalityRouterEvidence as WorkerReads
} from "../../../smart-contracts/domains/finality/StreamFinalityRouterEvidence.sol";
import {
    StreamSnapshotManifestBytes as WorkerBytes
} from "../../../smart-contracts/domains/records/StreamSnapshotManifestBytes.sol";

import {
    IStreamSchemaDocumentFacts as WorkerSchemaFacts
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamSchemaDocumentFacts.sol";
import {
    IStreamWorkRecordSelection as WorkerWorkErrors
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamWorkRecordSelection.sol";

interface ScopedReferenceWorkerVm {
    function expectRevert(bytes calldata data) external;
    function expectCall(address callee, bytes calldata data, uint64 count) external;
    function mockCall(address callee, bytes calldata data, bytes calldata result) external;
    function mockCallRevert(address callee, bytes calldata data, bytes calldata result) external;
}

/// @dev Retains actual original Store chunks. It supplies no publication or Artist authority.
contract ScopedReferencePayloadWorkerHarness {
    address private _store;
    mapping(bytes32 => WorkerBytes.Manifest) private _payloads;
    mapping(bytes32 => WorkerT.Receipt) private _recordReceipts;

    constructor(address store) {
        _store = store;
    }

    function retain(bytes memory raw) external returns (bytes32 hash) {
        hash = keccak256(raw);
        WorkerBytes.retain(_payloads[hash], _store, raw);
    }

    function source(bytes32 hash, bytes32 family) external view returns (bytes memory) {
        return WorkerRecords.source(_payloads[hash], family);
    }

    function originalSource(bytes32 hash) external view returns (bytes memory) {
        return WorkerRecords.source(_payloads[hash]);
    }

    function retainRecord(bytes memory raw, WorkerT.Receipt memory receipt)
        external
        returns (bytes32 hash)
    {
        hash = keccak256(raw);
        WorkerBytes.retain(_payloads[hash], _store, raw);
        _recordReceipts[hash] = receipt;
    }

    function recordBytes(bytes32 hash) external view returns (bytes memory) {
        return WorkerRecords.recordBytes(_payloads[hash], _recordReceipts[hash]);
    }

    function publication(bytes32 hash) external view returns (WorkerT.Publication memory) {
        return WorkerRecords.publication(_payloads[hash]);
    }
}

/// @dev Reuses the existing original publication fixture and its explicitly typed source/Archive
/// boundaries. These are focused factoring regressions, not a new complete Artist ceremony proof.
contract StreamScopedPreservationReferenceWorkersV1Test is ScopedPreservationReferenceFixtureV1 {
    ScopedReferenceWorkerVm private constant workerVm =
        ScopedReferenceWorkerVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function testFactoredSourceKeepsOriginalSnapshotAndAllReturnedRootFields() public {
        _reference(1, 2);
        bytes32 record = _publishReference();
        WorkerT.SourceFacts memory facts = referenceHost.referenceSource(record);
        (, WorkerS.Receipt memory snapshot) = snapshotHost.snapshotRecord(adoptedSnapshot);
        require(
            snapshot.recordHash != 0 && snapshot.manifestHash != 0 && snapshot.manifestBytes != 0
        );
        require(keccak256(abi.encode(facts.snapshot)) == keccak256(abi.encode(snapshot)));
        require(facts.contentRootRecordHash == adoptedRoot);
        require(
            keccak256(abi.encode(facts.contentRoot))
                == keccak256(abi.encode(router.scopedContentRootRecord(adoptedRoot)))
        );
        require(
            keccak256(abi.encode(facts.contentRootBinding))
                == keccak256(
                    abi.encode(
                        BindingABI(address(router))
                            .scopedPreservationPolicyContentRootBinding(adoptedRoot)
                    )
                )
        );
        WorkerT.Receipt memory receipt =
            referenceHost.requireCurrent(referenceInput.scope, record, 1);
        WorkerT.Dependencies memory d = referenceHost.dependencies();
        require(
            receipt.observation.sourcesHash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_REFERENCE_SOURCES_V1"),
                        block.chainid,
                        address(referenceHost),
                        d.targets,
                        d.codeHashes,
                        facts
                    )
                )
        );
        require(referenceInput.observation.expectedSourcesHash != 0);
        _assertReferencePayload(referenceHost.referencePayload(record), facts);
    }

    function testSnapshotWorkerKeepsCallerReceiptAndUsesExactPayloadKey() public {
        _reference(1, 2);
        bytes32 record = _publishReference();
        WorkerT.SourceFacts memory expected = referenceHost.referenceSource(record);
        WorkerT.Dependencies memory d = referenceHost.dependencies();
        WorkerS.Dependencies memory source = snapshotHost.dependencies();
        (WorkerS.Publication memory p, WorkerS.Receipt memory receipt) =
            snapshotHost.snapshotRecord(adoptedSnapshot);
        bytes32 beforeReceipt = keccak256(abi.encode(receipt));
        bytes32 beforePublication = keccak256(abi.encode(p));
        workerVm.expectCall(
            address(snapshotHost),
            abi.encodeCall(SnapshotABI.snapshotPayload, (adoptedSnapshot)),
            uint64(1)
        );
        WorkerS.Source memory actual =
            SnapshotWorker.read(d, source, p, receipt, WorkerProfiles.ORIGINAL_PROFILE);
        require(keccak256(abi.encode(actual)) == keccak256(abi.encode(expected.snapshotSource)));
        // The linked worker receives copies; the facade alone reapplies the original publication mutation.
        require(keccak256(abi.encode(receipt)) == beforeReceipt);
        require(keccak256(abi.encode(p)) == beforePublication);
        require(receipt.recordHash == adoptedSnapshot && receipt.manifestHash != 0);
    }

    function testSnapshotWorkerRejectsPaddedReturnAndReadFailureThenRestores() public {
        _reference(1, 2);
        WorkerT.Dependencies memory d = referenceHost.dependencies();
        WorkerS.Dependencies memory source = snapshotHost.dependencies();
        (WorkerS.Publication memory p, WorkerS.Receipt memory receipt) =
            snapshotHost.snapshotRecord(adoptedSnapshot);
        bytes memory callData = abi.encodeCall(SnapshotABI.snapshotPayload, (adoptedSnapshot));
        bytes memory raw = snapshotHost.snapshotPayload(adoptedSnapshot);
        WorkerS.Source memory healthy =
            SnapshotWorker.read(d, source, p, receipt, WorkerProfiles.ORIGINAL_PROFILE);
        // The extra return word fits the original +96 bound, so canonical return validation must reject it.
        workerVm.mockCall(
            address(snapshotHost), callData, bytes.concat(abi.encode(raw), bytes32(0))
        );
        workerVm.expectRevert(
            abi.encodeWithSelector(
                WorkerT.ScopedPolicyReferenceDependency.selector, address(snapshotHost)
            )
        );
        SnapshotWorker.read(d, source, p, receipt, WorkerProfiles.ORIGINAL_PROFILE);
        workerVm.mockCall(address(snapshotHost), callData, abi.encode(raw));
        require(
            keccak256(
                abi.encode(
                    SnapshotWorker.read(d, source, p, receipt, WorkerProfiles.ORIGINAL_PROFILE)
                )
            ) == keccak256(abi.encode(healthy))
        );
        workerVm.mockCallRevert(address(snapshotHost), callData, hex"12345678");
        workerVm.expectRevert(
            abi.encodeWithSelector(
                WorkerReads.RouterEvidenceRead.selector,
                address(snapshotHost),
                SnapshotABI.snapshotPayload.selector
            )
        );
        SnapshotWorker.read(d, source, p, receipt, WorkerProfiles.ORIGINAL_PROFILE);
        workerVm.mockCall(address(snapshotHost), callData, abi.encode(raw));
        require(
            keccak256(
                abi.encode(
                    SnapshotWorker.read(d, source, p, receipt, WorkerProfiles.ORIGINAL_PROFILE)
                )
            ) == keccak256(abi.encode(healthy))
        );
    }

    function testRootWorkerRejectsOriginalOutputTupleSubstitutionThenRestores() public {
        _reference(1, 2);
        bytes32 record = _publishReference();
        WorkerT.SourceFacts memory facts = referenceHost.referenceSource(record);
        WorkerT.Dependencies memory d = referenceHost.dependencies();
        WorkerS.Dependencies memory source = snapshotHost.dependencies();
        bytes32 outputRecord = publication.outputManifestRecord;
        (bytes32 rootHash, RootABI.Record memory root, BindingABI.Binding memory binding) = RootWorker.read(
            d,
            source,
            referenceInput.scope,
            outputRecord,
            facts.snapshotSource,
            facts.snapshot,
            WorkerProfiles.ORIGINAL_PROFILE
        );
        require(rootHash == facts.contentRootRecordHash);
        require(
            keccak256(abi.encode(root, binding))
                == keccak256(abi.encode(facts.contentRoot, facts.contentRootBinding))
        );
        OutputABI.Manifest memory original = snapshotOutputs.manifestRecord(outputRecord);
        OutputABI.Manifest memory changed = abi.decode(abi.encode(original), (OutputABI.Manifest));
        changed.checkpointStateHash = bytes32(uint256(changed.checkpointStateHash) ^ 1);
        bytes memory callData = abi.encodeCall(OutputABI.manifestRecord, (outputRecord));
        workerVm.mockCall(address(snapshotOutputs), callData, abi.encode(changed));
        workerVm.expectCall(address(snapshotOutputs), callData, uint64(2));
        workerVm.expectRevert(abi.encodeWithSelector(WorkerT.InvalidScopedPolicyReference.selector));
        RootWorker.read(
            d,
            source,
            referenceInput.scope,
            outputRecord,
            facts.snapshotSource,
            facts.snapshot,
            WorkerProfiles.ORIGINAL_PROFILE
        );
        workerVm.mockCall(address(snapshotOutputs), callData, abi.encode(original));
        (bytes32 restored,,) = RootWorker.read(
            d,
            source,
            referenceInput.scope,
            outputRecord,
            facts.snapshotSource,
            facts.snapshot,
            WorkerProfiles.ORIGINAL_PROFILE
        );
        require(restored == rootHash);
    }

    function testRetainedPayloadWorkerPreservesBothClosedFramesAndRejectsWrongFamily() public {
        _reference(1, 2);
        bytes32 record = _publishReference();
        bytes memory raw = referenceHost.referencePayload(record);
        WorkerT.SourceFacts memory expected = referenceHost.referenceSource(record);
        ScopedReferencePayloadWorkerHarness harness =
            new ScopedReferencePayloadWorkerHarness(address(snapshotStore));
        bytes32 key = harness.retain(raw);
        require(keccak256(harness.originalSource(key)) == keccak256(abi.encode(expected)));
        require(
            keccak256(harness.source(key, WorkerProfiles.ORIGINAL_PROFILE))
                == keccak256(abi.encode(expected))
        );
        workerVm.expectRevert(abi.encodeWithSelector(WorkerT.InvalidScopedPolicyReference.selector));
        harness.source(key, WorkerProfiles.FAMILY_PROFILE);
        // Historical byte decoder frame coverage only: this does not manufacture a V2 publication.
        bytes memory familyFrame = bytes.concat(raw);
        bytes32 domain = keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_REFERENCE_PAYLOAD_V2");
        assembly ("memory-safe") { mstore(add(familyFrame, 32), domain) }
        _upload(familyFrame, false);
        bytes32 familyKey = harness.retain(familyFrame);
        require(
            keccak256(harness.source(familyKey, WorkerProfiles.FAMILY_PROFILE))
                == keccak256(abi.encode(expected))
        );
        workerVm.expectRevert(abi.encodeWithSelector(WorkerT.InvalidScopedPolicyReference.selector));
        harness.originalSource(familyKey);
    }

    function testRetainedPayloadWorkerRejectsCanonicalPaddingAndUnknownFamily() public {
        _reference(1, 2);
        bytes32 record = _publishReference();
        bytes memory raw = referenceHost.referencePayload(record);
        ScopedReferencePayloadWorkerHarness harness =
            new ScopedReferencePayloadWorkerHarness(address(snapshotStore));
        bytes32 key = harness.retain(raw);
        bytes memory healthy = harness.originalSource(key);
        bytes memory padded = bytes.concat(raw, bytes32(0));
        _upload(padded, false);
        bytes32 paddedKey = harness.retain(padded);
        workerVm.expectRevert(abi.encodeWithSelector(WorkerT.InvalidScopedPolicyReference.selector));
        harness.originalSource(paddedKey);
        workerVm.expectRevert(
            abi.encodeWithSelector(WorkerFamilies.InvalidPreservationReferenceFamily.selector)
        );
        harness.source(key, keccak256("unsupported reference family"));
        require(keccak256(harness.originalSource(key)) == keccak256(healthy));
    }

    function testHistoryWorkerKeepsOriginalTupleAndRejectsPaddedPublication() public {
        _reference(1, 2);
        bytes32 record = _publishReference();
        // The direct head getter reads the stored receipt without the moved record codec.
        WorkerT.Receipt memory receipt = referenceHost.currentReference(referenceInput.scope);
        require(receipt.observation.recordHash == record);
        bytes memory original = abi.encode(referenceInput);
        bytes memory expected = abi.encode(referenceInput, receipt);
        ScopedReferencePayloadWorkerHarness harness =
            new ScopedReferencePayloadWorkerHarness(address(snapshotStore));
        bytes32 key = harness.retainRecord(original, receipt);
        require(keccak256(harness.recordBytes(key)) == keccak256(expected));
        require(keccak256(abi.encode(harness.publication(key))) == keccak256(original));
        (WorkerT.Publication memory stored, WorkerT.Receipt memory storedReceipt) =
            referenceHost.referenceRecord(record);
        require(keccak256(abi.encode(stored, storedReceipt)) == keccak256(expected));

        // Valid retained Store bytes with noncanonical trailing data must fail in both routes.
        bytes memory padded = bytes.concat(original, bytes32(0));
        _upload(padded, false);
        bytes32 badKey = harness.retainRecord(padded, receipt);
        workerVm.expectRevert(abi.encodeWithSelector(WorkerT.InvalidScopedPolicyReference.selector));
        harness.publication(badKey);
        workerVm.expectRevert(abi.encodeWithSelector(WorkerT.InvalidScopedPolicyReference.selector));
        harness.recordBytes(badKey);
        require(keccak256(harness.recordBytes(key)) == keccak256(expected));
        require(keccak256(abi.encode(harness.publication(key))) == keccak256(original));
    }

    function testDefinitionsWorkerKeepsFamilyAndDocumentFailureOrderThenRestores() public {
        _reference(1, 2);
        WorkerT.Dependencies memory d = referenceHost.dependencies();
        bytes32 originalDependencies = keccak256(abi.encode(d));
        bytes32 first = keccak256("STREAM_SCOPED_PRESERVATION_POLICY_REFERENCE_ABI_V1");
        bytes32 last = keccak256("STREAM_REFERENCE_NATIVE_FORMATS_V1");
        WorkerSchemaFacts registry = WorkerSchemaFacts(d.targets[2]);
        WorkerSchemaFacts.DocumentFacts memory firstFacts = registry.documentFacts(first);
        WorkerSchemaFacts.DocumentFacts memory lastFacts = registry.documentFacts(last);
        require(firstFacts.exists && lastFacts.exists);
        bytes memory firstCall = abi.encodeCall(WorkerSchemaFacts.documentFacts, (first));
        bytes memory lastCall = abi.encodeCall(WorkerSchemaFacts.documentFacts, (last));
        WorkerRecords.definitions(d);
        WorkerSchemaFacts.DocumentFacts memory unavailable;
        workerVm.mockCall(d.targets[2], firstCall, abi.encode(unavailable));
        workerVm.mockCall(d.targets[2], lastCall, abi.encode(unavailable));

        // An unsupported family must fail before either unavailable document is read.
        workerVm.expectRevert(
            abi.encodeWithSelector(WorkerFamilies.InvalidPreservationReferenceFamily.selector)
        );
        WorkerRecords.definitions(d, keccak256("unknown scoped reference family"));
        workerVm.expectRevert(
            abi.encodeWithSelector(WorkerWorkErrors.WorkDefinitionUnavailable.selector, first)
        );
        WorkerRecords.definitions(d, WorkerProfiles.ORIGINAL_PROFILE);
        workerVm.mockCall(d.targets[2], firstCall, abi.encode(firstFacts));
        workerVm.expectRevert(
            abi.encodeWithSelector(WorkerWorkErrors.WorkDefinitionUnavailable.selector, last)
        );
        WorkerRecords.definitions(d);
        workerVm.mockCall(d.targets[2], lastCall, abi.encode(lastFacts));
        WorkerRecords.definitions(d);
        WorkerRecords.definitions(d, WorkerProfiles.ORIGINAL_PROFILE);
        require(keccak256(abi.encode(d)) == originalDependencies);
    }
}
