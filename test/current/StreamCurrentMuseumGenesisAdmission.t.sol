// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/StreamFullV1ActivationFixture.sol";
import { StreamMuseumGenesisSource } from "../helpers/StreamMuseumGenesisSource.sol";
import {
    StreamSchemaAdmissionPlan as Admission
} from "../../script/current/StreamSchemaAdmissionPlan.sol";
import {
    StreamFullV1ActivationPlan as Activation
} from "../../script/current/StreamFullV1ActivationPlan.sol";
import {
    IStreamSchemaRegistry as MuseumSchema
} from "../../smart-contracts/interfaces/stream/metadata/IStreamSchemaRegistry.sol";

/// @notice Canonical Museum source admission through the original full37 graph and 2-of-2 Safe.
/// @dev Authored recipe, not runtime acceptance, JSON conformance or a complete activated system.
contract StreamCurrentMuseumGenesisAdmissionTest is StreamFullV1ActivationFixture {
    bytes private retainedSource;
    bytes32 private retainedHash;

    struct ManifestSnapshot {
        StreamSystemManifest.AggregateState aggregate;
        address pointer;
        uint256 count;
        bytes32 historyHash;
    }

    struct SavedAdmission {
        GenesisBatch batch;
        Activation.Publication publication;
        ManifestSnapshot manifestBefore;
        bytes32 actionId;
        bytes executorData;
        bytes safeData;
        bytes32 safeDataHash;
        bytes32 safeTransactionHash;
        uint256 safeNonce;
        uint256 governanceNonce;
        uint256 pending;
        uint256 documents;
        uint256 pointers;
    }

    function setUp() public {
        _constructActivationCandidate();
        (Admission.Document[] memory rows, string[] memory paths, bytes32 sourceHash) =
            StreamMuseumGenesisSource.load();
        Admission.Plan memory p = Admission.capture(assemblySchemas, sourceHash, rows);
        retainedHash = Admission.planHash(p);
        retainedSource = abi.encode(p, paths);
    }

    function _additionalOperatingPolicies()
        internal
        view
        override
        returns (GovernanceActionPolicyEntry[] memory rows)
    {
        rows = new GovernanceActionPolicyEntry[](2);
        rows[0] = _policy(assemblySchemas.registerDocument.selector);
        rows[1] = _policy(assemblySchemas.setDocumentStatus.selector);
    }

    function testActualSafeAdmitsAll51CanonicalDocumentsAndReusesExactActiveReadback() public {
        (Admission.Plan memory p, string[] memory paths) = _source();
        uint256 beforeCount = assemblySchemas.documentCount();
        uint256 missing = Admission.pending(p, retainedHash);
        require(p.documents.length == 51, "all reviewed source documents");
        for (uint256 i; i < p.documents.length; ++i) {
            _admit(p, paths, i);
        }
        Admission.requireRegistered(p, retainedHash);
        require(assemblySchemas.documentCount() == beforeCount + missing, "no extra admissions");
        uint256 chunks;
        uint256 totalBytes;
        for (uint256 i; i < p.documents.length; ++i) {
            Admission.Document memory row = p.documents[i];
            bytes32 id = keccak256(bytes(row.specification.name));
            require(Admission.next(p, retainedHash, i).calls.length == 0, "exact ACTIVE no-op");
            require(
                keccak256(assemblySchemas.documentBytes(id))
                    == keccak256(bytes(vm.readFile(paths[i]))),
                "full canonical bytes"
            );
            for (uint256 j; j < row.chunkHashes.length; ++j) {
                require(
                    assemblySchemas.documentChunkHashAt(id, j) == row.chunkHashes[j],
                    "original ordered occurrence"
                );
            }
            chunks += row.chunkHashes.length;
            totalBytes += row.specification.totalBytes;
        }
        require(chunks == 78 && totalBytes == 401717, "all original source bytes");
        require(
            p.documents[17].specification.totalBytes == 34843
                && p.documents[17].chunkHashes.length == 5,
            "largest dossier retains five chunks"
        );
        require(
            !ledger.ledgerWriter(address(products.continuity.manager)),
            "schema admission grants no reserve writer"
        );
    }

    function testUploadIsPermissionlessButOriginalGovernanceAndDelayRemainRequired() public {
        (Admission.Plan memory p, string[] memory paths) = _source();
        uint256 count = assemblySchemas.documentCount();
        require(
            !assemblySchemas.document(keccak256("RAW_BYTES")).exists,
            "fresh current schema registry"
        );
        Admission.publish(p, retainedHash, 0, bytes(vm.readFile(paths[0])));
        require(assemblySchemas.documentCount() == count, "upload is not admission");
        MuseumSchema.DocumentSpec memory spec = p.documents[0].specification;
        bytes32[] memory hashes = p.documents[0].chunkHashes;
        vm.expectRevert(
            abi.encodeWithSelector(MuseumSchema.UnauthorizedDocumentGovernance.selector)
        );
        assemblySchemas.registerDocument(spec, hashes);
        _admit(p, paths, 0);
        require(assemblySchemas.documentCount() == count + 1, "actual delayed Safe admission");
    }

    function testCanonicalizationMustBeAdmittedBeforeItsDependentDocument() public {
        (Admission.Plan memory p, string[] memory paths) = _source();
        _admit(p, paths, 0);
        Admission.publish(p, retainedHash, 2, bytes(vm.readFile(paths[2])));
        vm.expectRevert(
            abi.encodeWithSelector(
                MuseumSchema.InvalidCanonicalization.selector, keccak256("RFC8785_JCS")
            )
        );
        this.planNext(p, retainedHash, 2);
        _admit(p, paths, 1);
        _admit(p, paths, 2);
        require(
            p.documents[2].specification.canonicalizationId == keccak256("RFC8785_JCS")
                && p.documents[24].specification.canonicalizationId == keccak256("RAW_BYTES"),
            "preserve supplied RAW and JCS choices"
        );
    }

    function testChangedSourceBytesAndReorderedChunkOccurrencesAreRejected() public {
        (Admission.Plan memory p, string[] memory paths) = _source();
        bytes memory raw = bytes(vm.readFile(paths[3]));
        raw[0] = bytes1(uint8(raw[0]) ^ 1);
        vm.expectRevert();
        this.publishSource(p, retainedHash, 3, raw);
        raw = bytes(vm.readFile(paths[3]));
        (p.documents[3].chunkHashes[1], p.documents[3].chunkHashes[2]) =
        (p.documents[3].chunkHashes[2], p.documents[3].chunkHashes[1]);
        bytes32 changed = Admission.planHash(p);
        vm.expectRevert();
        this.publishSource(p, changed, 3, raw);
        (address pointer,) = assemblyStore.chunk(p.documents[3].chunkHashes[0]);
        require(pointer == address(0), "failed publication remains atomic");
    }

    function testSavedPlanRejectsChangedMetadataAndChainBeforePublication() public {
        (Admission.Plan memory p, string[] memory paths) = _source();
        p.documents[0].specification.uri = "urn:unreviewed:change";
        bytes memory raw = bytes(vm.readFile(paths[0]));
        vm.expectRevert();
        this.publishSource(p, retainedHash, 0, raw);
        (p, paths) = _source();
        vm.chainId(block.chainid + 1);
        vm.expectRevert();
        this.planNext(p, retainedHash, 0);
    }

    function testExistingNameWithDifferentDefinitionBlocksCanonicalPlan() public {
        (Admission.Plan memory p, string[] memory paths) = _source();
        _admit(p, paths, 0);
        _admit(p, paths, 1);
        Admission.Document[] memory different = new Admission.Document[](1);
        different[0] = p.documents[2];
        different[0].specification.uri = "urn:fixture:conflicting-definition";
        Admission.Plan memory conflict =
            Admission.capture(assemblySchemas, keccak256("explicit conflict fixture"), different);
        bytes32 conflictHash = Admission.planHash(conflict);
        Admission.publish(conflict, conflictHash, 0, bytes(vm.readFile(paths[2])));
        _run(Admission.next(conflict, conflictHash, 0));
        // Reload because Solidity memory struct assignment can alias nested fields.
        (p, paths) = _source();
        vm.expectRevert();
        this.planNext(p, retainedHash, 2);
        vm.expectRevert();
        this.countPending(p, retainedHash);
    }

    function testRetiredDocumentRemainsReadableButCannotBeReusedAsActive() public {
        (Admission.Plan memory p, string[] memory paths) = _source();
        for (uint256 i; i < 3; ++i) {
            _admit(p, paths, i);
        }
        bytes32 id = keccak256(bytes(p.documents[2].specification.name));
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            assemblySchemas.statusTransition(id, MuseumSchema.DocumentStatus.DEPRECATED);
        _govern(
            _governanceRequest(
                1,
                address(assemblySchemas),
                abi.encodeCall(
                    assemblySchemas.setDocumentStatus, (id, MuseumSchema.DocumentStatus.DEPRECATED)
                ),
                scope,
                oldHash,
                newHash
            )
        );
        require(
            keccak256(assemblySchemas.documentBytes(id))
                == p.documents[2].specification.contentHash,
            "historical bytes retained"
        );
        vm.expectRevert();
        this.planNext(p, retainedHash, 2);
    }

    function testChangedStoredChunkFailsExistingDocumentReadback() public {
        (Admission.Plan memory p, string[] memory paths) = _source();
        _admit(p, paths, 0);
        (address pointer,) = assemblyStore.chunk(p.documents[0].chunkHashes[0]);
        vm.etch(pointer, hex"00626164");
        vm.expectRevert();
        this.planNext(p, retainedHash, 0);
    }

    function testChangedRegistryRuntimeRejectsSavedPlanBeforeAnyOriginalCall() public {
        (Admission.Plan memory p,) = _source();
        vm.etch(address(p.registry), hex"00");
        vm.expectRevert();
        this.planNext(p, retainedHash, 0);
    }

    function testCaptureRejectsDuplicateNamesAndPartialNonfinalChunks() public {
        (Admission.Plan memory p,) = _source();
        Admission.Document[] memory rows = new Admission.Document[](2);
        rows[0] = p.documents[0];
        rows[1] = p.documents[0];
        vm.expectRevert();
        this.captureDocuments(rows);
        rows = new Admission.Document[](1);
        rows[0] = p.documents[3];
        --rows[0].chunkLengths[0];
        ++rows[0].chunkLengths[2];
        vm.expectRevert();
        this.captureDocuments(rows);
    }

    function testRepeatedChunkOccurrencesRetainOrderDespiteStoreDeduplication() public {
        (Admission.Plan memory canonical, string[] memory paths) = _source();
        _admit(canonical, paths, 0);
        bytes memory part = new bytes(8192);
        for (uint256 i; i < part.length; ++i) {
            part[i] = 0x61;
        }
        bytes memory raw = bytes.concat(part, part);
        Admission.Document[] memory rows = new Admission.Document[](1);
        rows[0].specification = MuseumSchema.DocumentSpec(
            "REPEATED_CHUNK_FIXTURE_V1",
            MuseumSchema.DocumentKind.SCHEMA,
            keccak256(raw),
            keccak256("RAW_BYTES"),
            0,
            "urn:fixture:repeated-chunks",
            uint32(raw.length)
        );
        rows[0].chunkHashes = new bytes32[](2);
        rows[0].chunkLengths = new uint32[](2);
        for (uint256 i; i < 2; ++i) {
            rows[0].chunkHashes[i] = keccak256(part);
            rows[0].chunkLengths[i] = 8192;
        }
        Admission.Plan memory p =
            Admission.capture(assemblySchemas, keccak256("explicit repeated-chunk fixture"), rows);
        bytes32 hash = Admission.planHash(p);
        uint256 beforePointers = assemblySchemas.payloadPointerCount(0);
        Admission.publish(p, hash, 0, raw);
        _run(Admission.next(p, hash, 0));
        Admission.requireRegistered(p, hash);
        require(
            assemblySchemas.payloadPointerCount(0) == beforePointers + 1,
            "one accepted chunk pointer"
        );
        MuseumSchema.DocumentView memory found =
            assemblySchemas.document(keccak256("REPEATED_CHUNK_FIXTURE_V1"));
        require(
            found.chunkHashes.length == 2 && found.chunkHashes[0] == found.chunkHashes[1]
                && keccak256(assemblySchemas.documentBytes(keccak256("REPEATED_CHUNK_FIXTURE_V1")))
                    == keccak256(raw),
            "two exact occurrences"
        );
    }

    function testLateManifestFailureRollsBackAdmissionAndRetriesIdenticalSignedSafeCall() public {
        (Admission.Plan memory p, string[] memory paths) = _source();
        Admission.publish(p, retainedHash, 0, bytes(vm.readFile(paths[0])));
        bytes32 documentId = keccak256(bytes(p.documents[0].specification.name));
        require(!assemblySchemas.document(documentId).exists, "fresh admission");
        SavedAdmission memory saved;
        saved.publication = _publication();
        saved.manifestBefore = _manifestSnapshot();
        saved.batch = Activation.withManifestTail(
            Activation.Context(foundation, configuration, products, savedInventoryHash),
            Admission.next(p, retainedHash, 0),
            saved.publication
        );
        require(
            saved.batch.actionClass == 1 && saved.batch.calls.length == 2
                && saved.batch.calls[0].target == address(assemblySchemas)
                && saved.batch.calls[1].target == address(manifest),
            "schema registration precedes the manifest failure"
        );
        uint64 ready;
        (saved.actionId, ready) = _scheduleBatchAsGovernor(
            saved.batch.actionClass, saved.batch.calls, saved.batch.callDatas
        );
        saved.safeNonce = governorSafe.nonce();
        saved.governanceNonce = executor.governanceNonce();
        saved.pending = executor.pendingScheduledActionCount();
        saved.documents = assemblySchemas.documentCount();
        saved.pointers = assemblySchemas.payloadPointerCount(0);
        saved.executorData = abi.encodeCall(
            executor.executeGovernanceBatch,
            (saved.actionId, saved.batch.calls, saved.batch.callDatas)
        );
        saved.safeTransactionHash = governorSafe.getTransactionHash(
            address(executor),
            0,
            saved.executorData,
            0,
            0,
            0,
            0,
            address(0),
            address(0),
            saved.safeNonce
        );
        // Sign once. Failure, repair and replay reuse this complete Safe calldata.
        bytes memory signatures = safeThresholdSignature(governorKeys, saved.safeTransactionHash);
        saved.safeData = abi.encodeCall(
            OfficialSafe.execTransaction,
            (
                address(executor),
                0,
                saved.executorData,
                0,
                0,
                0,
                0,
                address(0),
                payable(address(0)),
                signatures
            )
        );
        saved.safeDataHash = keccak256(saved.safeData);
        vm.warp(ready);
        require(
            executor.governanceAction(saved.actionId).status == GovernanceActionStatus.SCHEDULED,
            "original action remains scheduled"
        );
        bytes32 beforeState = _admissionState(saved.actionId, documentId);
        bytes memory descriptorCode = saved.publication.payload.code;
        vm.etch(saved.publication.payload, hex"00");
        // Only the final call reads the descriptor; schema registration succeeds first.
        vm.expectRevert(
            abi.encodeWithSelector(IStreamGovernanceExecutor.InvalidManifestTail.selector)
        );
        executor.executeGovernanceBatch(saved.actionId, saved.batch.calls, saved.batch.callDatas);
        require(_admissionState(saved.actionId, documentId) == beforeState, "direct batch rollback");
        _savedSafeFailure(saved, "GS013");
        require(
            _admissionState(saved.actionId, documentId) == beforeState,
            "schema, manifest, executor and Safe nonce roll back together"
        );
        // Repair only the exact descriptor: no rescheduling, changed calldata or new signature.
        vm.etch(saved.publication.payload, descriptorCode);
        require(
            saved.publication.payload.codehash == keccak256(descriptorCode), "exact payload repair"
        );
        require(
            governorSafe.nonce() == saved.safeNonce
                && governorSafe.getTransactionHash(
                    address(executor),
                    0,
                    saved.executorData,
                    0,
                    0,
                    0,
                    0,
                    address(0),
                    address(0),
                    governorSafe.nonce()
                ) == saved.safeTransactionHash,
            "retry retains the signed Safe nonce and digest"
        );
        vm.recordLogs();
        (bool ok, bytes memory result) = _savedSafeCall(saved);
        require(
            ok && result.length == 32 && abi.decode(result, (bool)),
            "identical signed retry succeeds"
        );
        _assertDocumentEvent(vm.getRecordedLogs(), p.documents[0], saved.actionId);
        require(
            Admission.next(p, retainedHash, 0).calls.length == 0
                && assemblySchemas.documentCount() == saved.documents + 1
                && assemblySchemas.payloadPointerCount(0) == saved.pointers + 1,
            "one document and one accepted RAW_BYTES chunk"
        );
        require(
            keccak256(assemblySchemas.documentBytes(documentId))
                == p.documents[0].specification.contentHash,
            "permissionless uploaded bytes survive the failed admission"
        );
        GovernanceAction memory action = executor.governanceAction(saved.actionId);
        require(
            action.status == GovernanceActionStatus.EXECUTED
                && action.proposer == address(governorSafe)
                && action.executor == address(governorSafe)
                && governorSafe.nonce() == saved.safeNonce + 1
                && executor.governanceNonce() == saved.governanceNonce
                && executor.pendingScheduledActionCount() + 1 == saved.pending,
            "one execution consumes only the saved Safe nonce and pending action"
        );
        _assertManifestAdvanced(saved.publication, saved.manifestBefore);
        bytes32 afterState = _admissionState(saved.actionId, documentId);
        _savedSafeFailure(saved, "GS026");
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGovernanceExecutor.GovernanceActionNotScheduled.selector, saved.actionId
            )
        );
        executor.executeGovernanceBatch(saved.actionId, saved.batch.calls, saved.batch.callDatas);
        require(
            _admissionState(saved.actionId, documentId) == afterState,
            "both replay refusals are atomic"
        );
    }

    function _savedSafeCall(SavedAdmission memory saved) private returns (bool, bytes memory) {
        require(
            keccak256(saved.safeData) == saved.safeDataHash,
            "unchanged saved Safe calldata and signatures"
        );
        return address(governorSafe).call(saved.safeData);
    }

    function _savedSafeFailure(SavedAdmission memory saved, string memory reason) private {
        (bool ok, bytes memory result) = _savedSafeCall(saved);
        require(
            !ok && keccak256(result) == keccak256(abi.encodeWithSignature("Error(string)", reason)),
            "exact original Safe refusal"
        );
    }

    function _admissionState(bytes32 actionId, bytes32 documentId) private view returns (bytes32) {
        (
            bool executing,
            bytes32 activeId,
            uint8 actionClass,
            bytes32 scope,
            bytes32 oldHash,
            bytes32 newHash
        ) = executor.currentAction();
        require(
            !executing && activeId == 0 && actionClass == 0 && scope == 0 && oldHash == 0
                && newHash == 0,
            "no residual execution context"
        );
        bytes32 schemaState = keccak256(
            abi.encode(
                assemblySchemas.documentCount(),
                assemblySchemas.payloadPointerCount(0),
                assemblySchemas.document(documentId)
            )
        );
        bytes32 manifestState = keccak256(abi.encode(_manifestSnapshot()));
        return keccak256(
            abi.encode(
                schemaState,
                manifestState,
                executor.governanceAction(actionId),
                executor.governanceNonce(),
                executor.pendingScheduledActionCount(),
                governorSafe.nonce()
            )
        );
    }

    function _manifestSnapshot() private view returns (ManifestSnapshot memory saved) {
        saved.aggregate = StreamGenesisManifestPlan.readAggregate(manifest);
        saved.pointer = manifest.streamSystemManifestPointer();
        saved.count = manifest.streamSystemManifestPointerCount();
        saved.historyHash = _manifestHistoryHash(saved.count);
    }

    function _manifestHistoryHash(uint256 count) private view returns (bytes32 result) {
        for (uint256 i; i < count; ++i) {
            (address pointer, bytes32 hash, uint64 timestamp) =
                manifest.streamSystemManifestPointerAt(i);
            result = keccak256(abi.encode(result, i, pointer, hash, timestamp));
        }
    }

    function _assertManifestAdvanced(
        Activation.Publication memory publication,
        ManifestSnapshot memory beforeState
    ) private view {
        StreamSystemManifest.AggregateState memory current =
            StreamGenesisManifestPlan.readAggregate(manifest);
        require(
            current.revision == beforeState.aggregate.revision + 1
                && current.manifestHash == publication.update.manifestHash
                && keccak256(bytes(current.manifestURI))
                    == keccak256(bytes(publication.update.manifestURI))
                && keccak256(abi.encode(current.modules))
                    == keccak256(abi.encode(beforeState.aggregate.modules))
                && keccak256(abi.encode(current.discovery))
                    == keccak256(abi.encode(beforeState.aggregate.discovery)),
            "exact manifest head, revision, modules and discovery"
        );
        require(
            manifest.streamSystemManifestPointer() == publication.payload
                && manifest.streamSystemManifestPointerCount() == beforeState.count + 1
                && _manifestHistoryHash(beforeState.count) == beforeState.historyHash,
            "one manifest pointer appended to unchanged history"
        );
        (address pointer, bytes32 hash, uint64 timestamp) =
            manifest.streamSystemManifestPointerAt(beforeState.count);
        require(
            pointer == publication.payload && hash == publication.update.manifestHash
                && timestamp == block.timestamp,
            "exact appended manifest publication"
        );
    }

    function _source() private view returns (Admission.Plan memory p, string[] memory paths) {
        return abi.decode(retainedSource, (Admission.Plan, string[]));
    }

    function _admit(Admission.Plan memory p, string[] memory paths, uint256 index) private {
        Admission.publish(p, retainedHash, index, bytes(vm.readFile(paths[index])));
        GenesisBatch memory batch = Admission.next(p, retainedHash, index);
        if (batch.calls.length == 0) return;
        bytes32 actionId = _run(batch);
        _assertDocumentEvent(vm.getRecordedLogs(), p.documents[index], actionId);
        require(
            Admission.next(p, retainedHash, index).calls.length == 0,
            "exact post-execution readback"
        );
    }

    function _assertDocumentEvent(
        Vm.Log[] memory logs,
        Admission.Document memory row,
        bytes32 actionId
    ) private view {
        bytes32 topic = keccak256(
            "DocumentRegistered(uint16,bytes32,bytes32,bytes32,bytes32,(string,uint8,bytes32,bytes32,bytes32,string,uint32),bytes32[])"
        );
        uint256 matched;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter != address(assemblySchemas) || logs[i].topics.length != 4
                    || logs[i].topics[0] != topic
            ) continue;
            require(
                logs[i].topics[1] == keccak256(bytes(row.specification.name))
                    && logs[i].topics[2] == row.specification.contentHash
                    && logs[i].topics[3] == actionId,
                "original document and Safe action event"
            );
            require(
                keccak256(logs[i].data)
                    == keccak256(
                        abi.encode(
                            uint16(1),
                            keccak256(abi.encode(row.specification, row.chunkHashes)),
                            row.specification,
                            row.chunkHashes
                        )
                    ),
                "full document event version, declaration, specification and ordered chunks"
            );
            ++matched;
        }
        require(matched == 1, "one original admission event");
    }

    function _run(GenesisBatch memory intent) private returns (bytes32 id) {
        Activation.Context memory x =
            Activation.Context(foundation, configuration, products, savedInventoryHash);
        Activation.Publication memory publication = _publication();
        ManifestSnapshot memory beforeState = _manifestSnapshot();
        GenesisBatch memory batch = Activation.withManifestTail(x, intent, publication);
        require(
            batch.actionClass == 1 && batch.calls.length == 2
                && batch.calls[0].target == address(assemblySchemas)
                && batch.calls[1].target == address(manifest),
            "original schema call and manifest tail"
        );
        uint64 ready;
        (id, ready) = _scheduleBatchAsGovernor(batch.actionClass, batch.calls, batch.callDatas);
        bytes memory data =
            abi.encodeCall(executor.executeGovernanceBatch, (id, batch.calls, batch.callDatas));
        vm.expectRevert();
        this.executeCurrentGovernorCall(address(executor), data);
        vm.warp(ready);
        vm.recordLogs();
        this.executeCurrentGovernorCall(address(executor), data);
        GovernanceAction memory action = executor.governanceAction(id);
        require(
            action.status == GovernanceActionStatus.EXECUTED
                && action.proposer == address(governorSafe),
            "original threshold Safe action executed"
        );
        _assertManifestAdvanced(publication, beforeState);
    }

    function _publication() private returns (Activation.Publication memory p) {
        StreamSystemManifest.AggregateState memory current =
            StreamGenesisManifestPlan.readAggregate(manifest);
        (p.payload, p.update.manifestHash) = StreamGenesisManifestPlan.writePayload(
            bytes("{\"fixture\":true,\"scope\":\"Museum document admission only\"}")
        );
        p.update.manifestURI = "urn:fixture:museum-admission-stage";
        p.update.eventCatalogHash = current.discovery.eventCatalogHash;
        p.update.compatibilityMatrixHash = current.discovery.compatibilityMatrixHash;
        p.update.numericIdCatalogHash = current.discovery.numericIdCatalogHash;
        p.update.schemaCatalogHash = current.discovery.schemaCatalogHash;
        p.update.canonicalizationCatalogHash = current.discovery.canonicalizationCatalogHash;
        p.update.specBundleHash = current.discovery.specBundleHash;
        p.update.reconstructionClientHash = current.discovery.reconstructionClientHash;
    }

    function _policy(bytes4 selector) private view returns (GovernanceActionPolicyEntry memory) {
        return GovernanceActionPolicyEntry(
            1,
            address(assemblySchemas),
            selector,
            address(assemblySchemas).codehash,
            keccak256(abi.encode(DEPLOYMENT_HASH, address(assemblySchemas))),
            1,
            0,
            0,
            0
        );
    }

    function planNext(Admission.Plan memory p, bytes32 hash, uint256 index) external view {
        Admission.next(p, hash, index);
    }

    function captureDocuments(Admission.Document[] memory rows) external view {
        Admission.capture(assemblySchemas, keccak256("explicit shape fixture"), rows);
    }

    function countPending(Admission.Plan memory p, bytes32 hash) external view {
        Admission.pending(p, hash);
    }

    function publishSource(Admission.Plan memory p, bytes32 hash, uint256 index, bytes memory raw)
        external
    {
        Admission.publish(p, hash, index, raw);
    }
}
