// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamCurrentGovernanceStagePlan.t.sol";
import "../../script/current/StreamGovernanceCatalogStagePlan.sol";
import "../../smart-contracts/domains/metadata/StreamSchemaRegistry.sol";
import {
    IStreamSchemaRegistry as Schema
} from "../../smart-contracts/interfaces/stream/metadata/IStreamSchemaRegistry.sol";

/// @notice Retained document bytes under a real two-of-three Safe and canonical Executor.
/// @dev Fixture documents exercise byte/authority mechanics, not JSON or museum conformance.
contract StreamCurrentSchemaRegistryTest is StreamCurrentGovernanceStagePlanTest {
    StreamSchemaRegistry private schemas;
    StreamSchemaDocumentStore private store;
    event SchemaStageGas(bytes32 indexed stage, uint256 gasUsed);
    event SchemaReadGas(uint256 logicalBytes, uint256 gasUsed);

    function testSchemaBootstrapNeedsExactDefinitionAndCannotRetire() public {
        _schemaSetup();
        (Schema.DocumentSpec memory spec, bytes32[] memory chunks) =
            _prepare("TEST_SCHEMA_V1", Schema.DocumentKind.SCHEMA, bytes("uninterpreted bytes"));
        vm.expectRevert(
            abi.encodeWithSelector(Schema.InvalidCanonicalization.selector, schemas.RAW_BYTES())
        );
        schemas.registrationTransition(spec, chunks);
        spec.name = "RAW_BYTES";
        vm.expectRevert(
            abi.encodeWithSelector(Schema.InvalidCanonicalization.selector, schemas.RAW_BYTES())
        );
        schemas.registrationTransition(spec, chunks);
        spec.kind = Schema.DocumentKind.CANONICALIZATION;
        vm.expectRevert(
            abi.encodeWithSelector(Schema.InvalidCanonicalization.selector, schemas.RAW_BYTES())
        );
        schemas.registrationTransition(spec, chunks);
        _bootstrap();
        bytes32 rawId = schemas.RAW_BYTES();
        require(
            keccak256(schemas.documentBytes(schemas.RAW_BYTES()))
                == keccak256(bytes(schemas.RAW_BYTES_DEFINITION())),
            "fixed definition retained"
        );
        vm.expectRevert(abi.encodeWithSelector(Schema.InvalidDocumentStatus.selector));
        schemas.statusTransition(rawId, Schema.DocumentStatus.DEPRECATED);
        vm.expectRevert(abi.encodeWithSelector(Schema.InvalidDocumentStatus.selector));
        schemas.setDocumentStatus(rawId, Schema.DocumentStatus.ARCHIVED);
    }

    function testSchemaSafeRegistrationLineageRetirementAndHistoricalBytes() public {
        _schemaSetup();
        _bootstrap();
        (Schema.DocumentSpec memory spec, bytes32[] memory chunks) = _prepare(
            "FIXTURE_CANON_V1",
            Schema.DocumentKind.CANONICALIZATION,
            bytes("fixture identity transform")
        );
        bytes32 canonicalId = _register(spec, chunks);
        (spec, chunks) = _prepare(
            "FIXTURE_SCHEMA_V1", Schema.DocumentKind.SCHEMA, bytes("{\"type\":\"string\"}")
        );
        spec.canonicalizationId = canonicalId;
        bytes32 oldId = _register(spec, chunks);
        _status(oldId, Schema.DocumentStatus.DEPRECATED);
        spec.name = "FIXTURE_SCHEMA_V2";
        spec.supersedesId = oldId;
        bytes32 nextId = _register(spec, chunks);
        _status(oldId, Schema.DocumentStatus.ARCHIVED);
        require(
            schemas.document(oldId).status == Schema.DocumentStatus.ARCHIVED, "explicit retirement"
        );
        require(schemas.document(nextId).specification.supersedesId == oldId, "immutable lineage");
        require(
            keccak256(schemas.documentBytes(oldId)) == keccak256(schemas.documentBytes(nextId)),
            "history remains decodable"
        );
        _status(canonicalId, Schema.DocumentStatus.ARCHIVED);
        require(
            keccak256(schemas.documentBytes(nextId)) == spec.contentHash,
            "retired canonicalizer cannot rewrite history"
        );
        spec.name = "FIXTURE_SCHEMA_V3";
        vm.expectRevert(
            abi.encodeWithSelector(Schema.InvalidCanonicalization.selector, canonicalId)
        );
        schemas.registrationTransition(spec, chunks);
        vm.expectRevert(abi.encodeWithSelector(Schema.InvalidDocumentStatus.selector));
        schemas.statusTransition(oldId, Schema.DocumentStatus.ACTIVE);
        require(
            schemas.documentCount() == 4 && schemas.documentIdAt(2) == oldId,
            "append-only identity index"
        );
    }

    function testSchemaSafeReadsAndPermissionlessUploadsPreserveAuthority() public {
        _schemaSetup();
        bytes memory payload = bytes("bytes published by the actual Safe");
        _safeRead(address(store), abi.encodeCall(store.publishChunk, (payload)));
        (address pointer, uint32 size) = store.chunk(keccak256(payload));
        require(pointer != address(0) && size == payload.length, "Safe published carrier");
        (bytes32 hash, address duplicate) = store.publishChunk(payload);
        require(duplicate == pointer && hash == keccak256(payload), "permissionless deduplication");
        require(
            schemas.documentCount() == 0 && schemas.payloadPointerCount(0) == 0,
            "upload grants no authority"
        );
        _bootstrap();
        (Schema.DocumentSpec memory spec, bytes32[] memory chunks) =
            _prepare("SAFE_SCHEMA_V1", Schema.DocumentKind.SCHEMA, payload);
        bytes32 id = _register(spec, chunks);
        _safeRead(
            address(schemas), abi.encodeCall(schemas.supportsInterface, (type(Schema).interfaceId))
        );
        _safeRead(address(schemas), abi.encodeCall(schemas.governanceAuthority, ()));
        _safeRead(address(schemas), abi.encodeCall(schemas.chunkStore, ()));
        _safeRead(address(schemas), abi.encodeCall(schemas.document, (id)));
        _safeRead(address(schemas), abi.encodeCall(schemas.documentBytes, (id)));
        _safeRead(address(schemas), abi.encodeCall(schemas.documentCount, ()));
        _safeRead(address(schemas), abi.encodeCall(schemas.documentIdAt, (1)));
        _safeRead(address(schemas), abi.encodeCall(schemas.payloadPointerCount, (0)));
        _safeRead(address(schemas), abi.encodeCall(schemas.payloadPointerAt, (0, 1)));
        _safeRead(
            address(schemas),
            abi.encodeCall(schemas.statusTransition, (id, Schema.DocumentStatus.DEPRECATED))
        );
        spec.name = "SAFE_SCHEMA_V2";
        _safeRead(address(schemas), abi.encodeCall(schemas.registrationTransition, (spec, chunks)));
        _safeRead(address(store), abi.encodeCall(store.chunk, (hash)));
        _safeRead(address(store), abi.encodeCall(store.readChunk, (hash)));
        require(
            schemas.supportsInterface(type(Schema).interfaceId)
                && !schemas.supportsInterface(0xffffffff),
            "exact interface beacon"
        );
    }

    function testSchemaDirectSafeAndEOACannotApproveDocuments() public {
        _schemaSetup();
        _bootstrap();
        (Schema.DocumentSpec memory spec, bytes32[] memory chunks) =
            _prepare("UNAPPROVED_V1", Schema.DocumentKind.SCHEMA, bytes("unapproved"));
        address outsider = vm.addr(0x65290001);
        vm.expectRevert(abi.encodeWithSelector(Schema.UnauthorizedDocumentGovernance.selector));
        vm.prank(outsider);
        schemas.registerDocument(spec, chunks);
        uint256 nonceBefore = governor.nonce();
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.callSchemaWithSafe(abi.encodeCall(schemas.registerDocument, (spec, chunks)));
        require(governor.nonce() == nonceBefore, "failed direct write leaves Safe nonce unchanged");
        require(schemas.documentCount() == 1, "no rejected write indexed");
        bytes32 id = _register(spec, chunks);
        nonceBefore = governor.nonce();
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.callSchemaWithSafe(
            abi.encodeCall(schemas.setDocumentStatus, (id, Schema.DocumentStatus.ARCHIVED))
        );
        require(
            governor.nonce() == nonceBefore, "failed direct retirement leaves Safe nonce unchanged"
        );
        require(
            schemas.document(id).status == Schema.DocumentStatus.ACTIVE,
            "status requires Executor context"
        );
    }

    function testSchemaRejectsAdmittedWrongClassAndWrongTransition() public {
        _schemaSetup();
        _bootstrap();
        (Schema.DocumentSpec memory spec, bytes32[] memory chunks) =
            _prepare("EXACT_CONTEXT_V1", Schema.DocumentKind.SCHEMA, bytes("exact context"));
        GenesisBatch memory batch = _registrationBatch(spec, chunks);
        batch.actionClass = 2; // This exact selector/class is admitted, so rejection is in the registry.
        StreamGovernanceStagePlan.Plan memory p = _build(keccak256("WRONG_CLASS"), batch);
        bytes32 id = _schedule(p);
        vm.warp(p.notBefore);
        vm.expectRevert(abi.encodeWithSelector(Schema.UnauthorizedDocumentGovernance.selector));
        this.executeSaved(p, id);
        require(schemas.documentCount() == 1, "class2 cannot impersonate ordinary registration");
        batch.actionClass = 1;
        batch.calls[0].newValueHash = keccak256("wrong new state");
        p = _build(keccak256("WRONG_TRANSITION"), batch);
        id = _schedule(p);
        vm.warp(p.notBefore);
        vm.expectRevert(abi.encodeWithSelector(Schema.UnauthorizedDocumentGovernance.selector));
        this.executeSaved(p, id);
        require(schemas.documentCount() == 1, "wrong commitment rejected atomically");
        _register(spec, chunks);
    }

    function testSchemaRejectsDuplicateIdentityUnknownAndWrongKindPredecessors() public {
        _schemaSetup();
        _bootstrap();
        (Schema.DocumentSpec memory spec, bytes32[] memory chunks) =
            _prepare("IMMUTABLE_V1", Schema.DocumentKind.SCHEMA, bytes("immutable"));
        bytes32 id = _register(spec, chunks);
        vm.expectRevert(abi.encodeWithSelector(Schema.DocumentAlreadyRegistered.selector, id));
        schemas.registrationTransition(spec, chunks);
        spec.name = "IMMUTABLE_V2";
        spec.supersedesId = keccak256("missing");
        vm.expectRevert(
            abi.encodeWithSelector(Schema.InvalidDocumentPredecessor.selector, spec.supersedesId)
        );
        schemas.registrationTransition(spec, chunks);
        spec.supersedesId = schemas.RAW_BYTES();
        vm.expectRevert(
            abi.encodeWithSelector(Schema.InvalidDocumentPredecessor.selector, spec.supersedesId)
        );
        schemas.registrationTransition(spec, chunks);
        spec.supersedesId = keccak256(bytes(spec.name));
        vm.expectRevert(
            abi.encodeWithSelector(Schema.InvalidDocumentPredecessor.selector, spec.supersedesId)
        );
        schemas.registrationTransition(spec, chunks);
        spec.supersedesId = 0;
        spec.canonicalizationId = id;
        vm.expectRevert(abi.encodeWithSelector(Schema.InvalidCanonicalization.selector, id));
        schemas.registrationTransition(spec, chunks);
        vm.expectRevert(
            abi.encodeWithSelector(Schema.DocumentUnknown.selector, keccak256("missing"))
        );
        schemas.documentBytes(keccak256("missing"));
        require(!schemas.document(keccak256("missing")).exists, "explicit missing read");
    }

    function testSchemaPreflightRejectsSegmentationHashOrderAndBounds() public {
        _schemaSetup();
        _bootstrap();
        bytes memory payload = _pattern(9000);
        (Schema.DocumentSpec memory spec, bytes32[] memory chunks) =
            _prepare("BOUNDED_V1", Schema.DocumentKind.DEPENDENCY, payload);
        schemas.registrationTransition(spec, chunks);
        (chunks[0], chunks[1]) = (chunks[1], chunks[0]);
        vm.expectRevert(abi.encodeWithSelector(Schema.InvalidDocument.selector));
        schemas.registrationTransition(spec, chunks);
        (chunks[0], chunks[1]) = (chunks[1], chunks[0]);
        spec.contentHash = keccak256("wrong bytes");
        vm.expectRevert(
            abi.encodeWithSelector(
                Schema.DocumentHashMismatch.selector, spec.contentHash, keccak256(payload)
            )
        );
        schemas.registrationTransition(spec, chunks);
        spec.contentHash = keccak256(payload);
        spec.totalBytes -= 1;
        vm.expectRevert(abi.encodeWithSelector(Schema.InvalidDocument.selector));
        schemas.registrationTransition(spec, chunks);
        spec.totalBytes += 1;
        vm.expectRevert(abi.encodeWithSelector(Schema.InvalidDocument.selector));
        schemas.registrationTransition(spec, new bytes32[](0));
        vm.expectRevert(abi.encodeWithSelector(Schema.InvalidDocument.selector));
        schemas.registrationTransition(spec, new bytes32[](65));
        spec.totalBytes = 524289;
        vm.expectRevert(abi.encodeWithSelector(Schema.InvalidDocument.selector));
        schemas.registrationTransition(spec, chunks);
        vm.expectRevert(
            abi.encodeWithSelector(StreamSchemaDocumentStore.InvalidChunkLength.selector, 0)
        );
        store.publishChunk(bytes(""));
        bytes memory tooLarge = new bytes(8193);
        vm.expectRevert(
            abi.encodeWithSelector(StreamSchemaDocumentStore.InvalidChunkLength.selector, 8193)
        );
        store.publishChunk(tooLarge);
    }

    function testSchemaMaximumDocumentReconstructsAndAcceptedPointersDeduplicatePerKind() public {
        _schemaSetup();
        _bootstrap();
        bytes memory block_ = _pattern(8192);
        (bytes32 chunkHash, address pointer) = store.publishChunk(block_);
        bytes32[] memory chunks = new bytes32[](64);
        bytes memory payload = new bytes(524288);
        for (uint256 i; i < 64; ++i) {
            chunks[i] = chunkHash;
            for (uint256 j; j < 8192; ++j) {
                payload[i * 8192 + j] = block_[j];
            }
        }
        Schema.DocumentSpec memory spec = Schema.DocumentSpec(
            "MAXIMUM_V1",
            Schema.DocumentKind.DEPENDENCY,
            keccak256(payload),
            schemas.RAW_BYTES(),
            0,
            "urn:fixture:maximum",
            524288
        );
        bytes32 id = _register(spec, chunks);
        require(
            keccak256(schemas.documentBytes(id)) == keccak256(payload),
            "all64 ordered chunks reconstructed"
        );
        require(
            schemas.document(id).chunkHashes.length == 64,
            "repetitions retained in logical document"
        );
        require(
            schemas.payloadPointerCount(0) == 2, "bootstrap and one unique accepted family/chunk"
        );
        (address accepted,, bytes32 acceptedHash) = schemas.payloadPointerAt(0, 1);
        require(
            accepted == pointer && acceptedHash == chunkHash,
            "physical accepted pointer is authoritative"
        );
        spec.name = "MAXIMUM_V2";
        _register(spec, chunks);
        require(schemas.payloadPointerCount(0) == 2, "same kind deduplicates across documents");
        spec.name = "MAXIMUM_CATALOG_V1";
        spec.kind = Schema.DocumentKind.CATALOG;
        _register(spec, chunks);
        require(
            schemas.payloadPointerCount(0) == 3,
            "same bytes in distinct kind retain both family meanings"
        );
        vm.expectRevert(abi.encodeWithSelector(Schema.InvalidDocumentScope.selector, 1));
        schemas.payloadPointerCount(1);
    }

    function testSchemaCRMDependencyShapeRetains54DistinctChunks() public {
        _distinctDocument(434213, 54);
    }

    function testSchemaExactEventsAndPublicConstantSafeCalls() public {
        _schemaSetup();
        _bootstrap();
        (Schema.DocumentSpec memory spec, bytes32[] memory chunks) =
            _prepare("EVENT_SCHEMA_V1", Schema.DocumentKind.SCHEMA, bytes("event payload"));
        StreamGovernanceStagePlan.Plan memory p =
            _build(keccak256("EVENT_REGISTER"), _registrationBatch(spec, chunks));
        bytes32 actionId = _schedule(p);
        bytes32 documentId = keccak256(bytes(spec.name));
        vm.warp(p.notBefore);
        vm.recordLogs();
        require(this.executeSaved(p, actionId), "document action executed");
        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 matched;
        bytes32 registrationTopic = keccak256(
            "DocumentRegistered(uint16,bytes32,bytes32,bytes32,bytes32,(string,uint8,bytes32,bytes32,bytes32,string,uint32),bytes32[])"
        );
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter != address(schemas)) continue;
            require(
                logs[i].topics.length == 4 && logs[i].topics[0] == registrationTopic,
                "exact registry event signature"
            );
            require(
                logs[i].topics[1] == documentId && logs[i].topics[2] == spec.contentHash
                    && logs[i].topics[3] == actionId,
                "exact indexed identity and action"
            );
            bytes memory expected =
                abi.encode(uint16(1), keccak256(abi.encode(spec, chunks)), spec, chunks);
            require(
                keccak256(logs[i].data) == keccak256(expected),
                "exact specification and ordered chunks"
            );
            ++matched;
        }
        require(matched == 1, "one accepted document event");
        p = _build(
            keccak256("EVENT_RETIRE"), _statusBatch(documentId, Schema.DocumentStatus.ARCHIVED)
        );
        actionId = _schedule(p);
        vm.warp(p.notBefore);
        vm.recordLogs();
        require(this.executeSaved(p, actionId), "retirement action executed");
        logs = vm.getRecordedLogs();
        matched = 0;
        bytes32 statusTopic = keccak256("DocumentStatusChanged(uint16,bytes32,uint8,uint8,bytes32)");
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter != address(schemas)) continue;
            require(
                logs[i].topics.length == 3 && logs[i].topics[0] == statusTopic
                    && logs[i].topics[1] == documentId && logs[i].topics[2] == actionId,
                "exact retirement identity and real action"
            );
            require(
                keccak256(logs[i].data) == keccak256(abi.encode(uint16(1), uint8(0), uint8(2))),
                "exact previous and next status"
            );
            ++matched;
        }
        require(matched == 1, "one retirement event");
        _safeRead(address(schemas), abi.encodeWithSignature("MAX_DOCUMENT_CHUNKS()"));
        _safeRead(address(schemas), abi.encodeWithSignature("CHUNK_BYTES()"));
        _safeRead(address(schemas), abi.encodeWithSignature("MAX_DOCUMENT_BYTES()"));
        _safeRead(address(schemas), abi.encodeWithSignature("RAW_BYTES()"));
        _safeRead(address(schemas), abi.encodeWithSignature("RAW_BYTES_DEFINITION()"));
        _safeRead(address(schemas), abi.encodeWithSignature("governanceAuthorityCodeHash()"));
        _safeRead(address(store), abi.encodeWithSignature("MAX_CHUNK_BYTES()"));
        require(
            schemas.MAX_DOCUMENT_CHUNKS() == 64 && schemas.CHUNK_BYTES() == 8192
                && schemas.MAX_DOCUMENT_BYTES() == 524288 && store.MAX_CHUNK_BYTES() == 8192,
            "exact declared operational bounds"
        );
        require(
            schemas.governanceAuthorityCodeHash() == address(configuration.executor).codehash,
            "actual immutable Executor code pin"
        );
    }

    function testSchemaMaximumDistinctDocumentRetains64Chunks() public {
        _distinctDocument(524288, 64);
    }

    function _distinctDocument(uint256 length, uint256 count) private {
        _schemaSetup();
        _bootstrap();
        // Synthetic bytes, including an exact-size CRM dependency fixture. Gas is diagnostic:
        // this test does not clear access warmth or claim a cold transaction/candidate ceiling.
        bytes memory payload = _pattern(length);
        (Schema.DocumentSpec memory spec, bytes32[] memory chunks) =
            _prepare("CRM_SIZE_FIXTURE_V1", Schema.DocumentKind.DEPENDENCY, payload);
        require(chunks.length == count, "whole logical dependency fits one immutable document");
        bytes32 id = _register(spec, chunks);
        uint256 beforeRead = gasleft();
        bytes memory recovered = schemas.documentBytes(id);
        emit SchemaReadGas(payload.length, beforeRead - gasleft());
        require(
            recovered.length == payload.length && keccak256(recovered) == keccak256(payload),
            "exact distinct-part reconstruction"
        );
        require(
            schemas.payloadPointerCount(0) == count + 1, "bootstrap plus distinct accepted chunks"
        );
    }

    function callSchemaWithSafe(bytes memory data) external {
        require(
            executeSafe(governor, signers, address(schemas), 0, data, 0), "Safe target execution"
        );
    }

    function testFuzzSchemaExactPayloadReconstruction(bytes32 seed, uint16 size) public {
        _schemaSetup();
        _bootstrap();
        uint256 length = 1 + uint256(size) % 17000;
        bytes memory payload = new bytes(length);
        for (uint256 i; i < length; ++i) {
            payload[i] = seed[i % 32];
        }
        (Schema.DocumentSpec memory spec, bytes32[] memory chunks) =
            _prepare("FUZZ_SCHEMA_V1", Schema.DocumentKind.SCHEMA, payload);
        bytes32 id = _register(spec, chunks);
        bytes memory recovered = schemas.documentBytes(id);
        require(
            recovered.length == length && keccak256(recovered) == keccak256(payload),
            "exact state-only bytes across word/chunk boundaries"
        );
    }

    function _schemaSetup() private {
        _initialize();
        schemas = new StreamSchemaRegistry(address(configuration.executor));
        store = StreamSchemaDocumentStore(schemas.chunkStore());
        require(
            address(schemas).code.length <= 24576 && address(store).code.length <= 24576,
            "deployable document hosts"
        );
        GovernanceActionPolicyEntry[] memory rows = new GovernanceActionPolicyEntry[](3);
        rows[0] = _row(1, schemas.registerDocument.selector);
        rows[1] = _row(1, schemas.setDocumentStatus.selector);
        rows[2] = _row(2, schemas.registerDocument.selector);
        for (uint256 i = 1; i < rows.length; ++i) {
            for (uint256 j = i; j > 0 && _key(rows[j - 1]) > _key(rows[j]); --j) {
                (rows[j - 1], rows[j]) = (rows[j], rows[j - 1]);
            }
        }
        StreamGovernanceCatalogStagePlan.Inventory memory inventory =
            StreamGovernanceCatalogStagePlan.inventory(configuration.executor, rows);
        StreamSystemManifest.AggregateState memory current =
            StreamGenesisManifestPlan.readAggregate(configuration.manifest);
        (address pointer, bytes32 hash) = StreamGenesisManifestPlan.writePayload(
            bytes("{\"purpose\":\"schema registry test admission\"}")
        );
        StreamSystemManifestUpdate memory update = StreamSystemManifestUpdate(
            hash,
            "urn:fixture:schema-admission",
            current.discovery.eventCatalogHash,
            current.discovery.compatibilityMatrixHash,
            current.discovery.numericIdCatalogHash,
            current.discovery.schemaCatalogHash,
            current.discovery.canonicalizationCatalogHash,
            current.discovery.specBundleHash,
            current.discovery.reconstructionClientHash
        );
        (GenesisBatch memory batch,) = StreamGovernanceCatalogStagePlan.nextBatch(
            inventory,
            StreamGovernanceCatalogStagePlan.inventoryHash(inventory),
            0,
            configuration.manifest,
            pointer,
            update
        );
        _execute(batch, keccak256("ADMIT_SCHEMA_REGISTRY"));
    }

    function _bootstrap() private {
        (Schema.DocumentSpec memory spec, bytes32[] memory chunks) = _prepare(
            "RAW_BYTES", Schema.DocumentKind.CANONICALIZATION, bytes(schemas.RAW_BYTES_DEFINITION())
        );
        require(_register(spec, chunks) == schemas.RAW_BYTES(), "exact bootstrap identifier");
    }

    function _prepare(string memory name, Schema.DocumentKind kind, bytes memory payload)
        private
        returns (Schema.DocumentSpec memory spec, bytes32[] memory chunks)
    {
        spec = Schema.DocumentSpec(
            name,
            kind,
            keccak256(payload),
            schemas.RAW_BYTES(),
            0,
            "urn:fixture:document",
            uint32(payload.length)
        );
        chunks = new bytes32[]((payload.length + 8191) / 8192);
        for (uint256 i; i < chunks.length; ++i) {
            uint256 start = i * 8192;
            uint256 count = payload.length - start;
            if (count > 8192) count = 8192;
            bytes memory part = new bytes(count);
            for (uint256 j; j < count; ++j) {
                part[j] = payload[start + j];
            }
            (chunks[i],) = store.publishChunk(part);
        }
    }

    function _registrationBatch(Schema.DocumentSpec memory spec, bytes32[] memory chunks)
        private
        view
        returns (GenesisBatch memory batch)
    {
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            schemas.registrationTransition(spec, chunks);
        batch.actionClass = 1;
        batch.calls = new GovernanceCall[](1);
        batch.callDatas = new bytes[](1);
        batch.callDatas[0] = abi.encodeCall(schemas.registerDocument, (spec, chunks));
        batch.calls[0] = StreamCurrentStackPlan.call(
            address(schemas), batch.callDatas[0], scope, oldHash, newHash
        );
    }

    function _register(Schema.DocumentSpec memory spec, bytes32[] memory chunks)
        private
        returns (bytes32 id)
    {
        _execute(_registrationBatch(spec, chunks), keccak256(bytes(spec.name)));
        id = keccak256(bytes(spec.name));
        Schema.DocumentView memory row = schemas.document(id);
        require(
            row.exists && row.declarationHash == keccak256(abi.encode(spec, chunks)),
            "exact accepted preimage"
        );
    }

    function _statusBatch(bytes32 id, Schema.DocumentStatus next)
        private
        view
        returns (GenesisBatch memory batch)
    {
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) = schemas.statusTransition(id, next);
        batch.actionClass = 1;
        batch.calls = new GovernanceCall[](1);
        batch.callDatas = new bytes[](1);
        batch.callDatas[0] = abi.encodeCall(schemas.setDocumentStatus, (id, next));
        batch.calls[0] = StreamCurrentStackPlan.call(
            address(schemas), batch.callDatas[0], scope, oldHash, newHash
        );
    }

    function _status(bytes32 id, Schema.DocumentStatus next) private {
        _execute(_statusBatch(id, next), keccak256(abi.encode(id, next)));
    }

    function _execute(GenesisBatch memory batch, bytes32 stage) private {
        StreamGovernanceStagePlan.Plan memory p = _build(stage, batch);
        bytes32 id = _schedule(p);
        vm.warp(p.notBefore);
        uint256 beforeExecute = gasleft();
        require(this.executeSaved(p, id), "exact delayed document stage");
        emit SchemaStageGas(stage, beforeExecute - gasleft());
    }

    function _row(uint8 actionClass, bytes4 selector)
        private
        view
        returns (GovernanceActionPolicyEntry memory)
    {
        return GovernanceActionPolicyEntry(
            actionClass,
            address(schemas),
            selector,
            address(schemas).codehash,
            keccak256("schema fixture admission"),
            1,
            0,
            0,
            0
        );
    }

    function _key(GovernanceActionPolicyEntry memory row) private pure returns (bytes32) {
        return keccak256(abi.encode(row.actionClass, row.target, row.selector));
    }

    function _pattern(uint256 length) private pure returns (bytes memory payload) {
        payload = new bytes(length);
        for (uint256 i; i < length; ++i) {
            payload[i] = bytes1(uint8(i % 251));
        }
    }

    function _safeRead(address target, bytes memory data) private {
        require(
            executeSafe(governor, signers, target, 0, data, 0),
            "real Safe can call declared read/publication"
        );
    }
}
