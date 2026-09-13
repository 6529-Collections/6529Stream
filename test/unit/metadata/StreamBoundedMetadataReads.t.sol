// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamOwnerRecords.t.sol";

interface BoundedMetadataVm {
    function mockCall(address target, bytes calldata input, bytes calldata output) external;
    function clearMockedCalls() external;
}

/// @notice Actual shared hosts at maximum supported registration/record shapes.
contract StreamBoundedMetadataReadsTest is CollectionMetadataV1Fixture {
    function testMetadataConstructorRequiresTheBoundedSchemaCapability() public {
        StreamCollectionMetadataV1.Configuration memory c;
        c.core = address(core);
        c.executor = address(executor);
        c.schemas = address(schemas);
        c.artistRegistry = address(artist);
        c.deploymentManifestHash = bytes32(uint256(1));
        c.manifestHash = bytes32(uint256(2));
        c.manifestURI = "ipfs://metadata-module";
        c.dependencyReadGas = IStreamGasParameterHost.GasParameterConfig(
            "METADATA_DEPENDENCY_READ_GAS", 150000, 100000, 2
        );
        c.artistReadGas = IStreamGasParameterHost.GasParameterConfig(
            "METADATA_ARTIST_READ_GAS", 2000000, 1000000, 2
        );
        BoundedMetadataVm(address(vm))
            .mockCall(
                address(schemas),
                abi.encodeCall(
                    IERC165.supportsInterface, (type(IStreamSchemaDocumentFacts).interfaceId)
                ),
                abi.encode(false)
            );
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamCollectionMetadataV1.InvalidMetadataConfiguration.selector
            )
        );
        new StreamCollectionMetadataV1(c);
        BoundedMetadataVm(address(vm)).clearMockedCalls();
        StreamCollectionMetadataV1 healthy = new StreamCollectionMetadataV1(c);
        require(
            healthy.schemaRegistry() == address(schemas),
            "same configuration with required registry succeeds"
        );
    }

    function _repeat(uint256 length, bytes1 value) private pure returns (bytes memory b) {
        b = new bytes(length);
        for (uint256 i; i < length; ++i) {
            b[i] = value;
        }
    }

    function _maximumDocument() private returns (bytes32 id, bytes32 chunkHash) {
        (chunkHash,) = store.publishChunk(new bytes(8192));
        bytes32[] memory chunks = new bytes32[](64);
        for (uint256 i; i < 64; ++i) {
            chunks[i] = chunkHash;
        }
        IStreamSchemaRegistry.DocumentSpec memory spec = IStreamSchemaRegistry.DocumentSpec(
            string(_repeat(128, 0x41)),
            IStreamSchemaRegistry.DocumentKind.SCHEMA,
            keccak256(new bytes(8192 * 64)),
            schemas.RAW_BYTES(),
            0,
            string(_repeat(2048, 0x75)),
            uint32(8192 * 64)
        );
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            schemas.registrationTransition(spec, chunks);
        id = abi.decode(
            executor.execute(
                address(schemas),
                abi.encodeCall(schemas.registerDocument, (spec, chunks)),
                scope,
                oldHash,
                newHash
            ),
            (bytes32)
        );
    }

    function testMaximumDefinitionColdReadAndOwnerAdmissionKeepExistingCap() public {
        (bytes32 id, bytes32 chunkHash) = _maximumDocument();
        safeVm.cool(address(schemas));
        (bool legacyOk,) =
            address(schemas).staticcall{ gas: 150000 }(abi.encodeCall(schemas.document, (id)));
        require(!legacyOk, "maximum legacy dynamic read diagnostic");
        safeVm.cool(address(schemas));
        (bool ok, bytes memory output) =
            address(schemas).staticcall{ gas: 150000 }(abi.encodeCall(schemas.documentFacts, (id)));
        require(ok && output.length == 288, "bounded header cold150k");
        IStreamSchemaDocumentFacts.DocumentFacts memory facts =
            abi.decode(output, (IStreamSchemaDocumentFacts.DocumentFacts));
        IStreamSchemaRegistry.DocumentView memory full = schemas.document(id);
        require(
            facts.exists && facts.kind == full.specification.kind && facts.status == full.status
                && facts.contentHash == full.specification.contentHash
                && facts.canonicalizationId == full.specification.canonicalizationId
                && facts.supersedesId == full.specification.supersedesId
                && facts.totalBytes == 524288 && facts.chunkCount == 64
                && facts.declarationHash == full.declarationHash,
            "all nine facts"
        );
        for (uint256 i; i < 64; ++i) {
            require(schemas.documentChunkHashAt(id, i) == chunkHash, "ordered repeated chunk");
        }
        StreamOwnerRecords.Configuration memory c;
        c.core = address(core);
        c.schemas = address(schemas);
        c.executor = address(executor);
        c.deploymentManifestHash = bytes32(uint256(1));
        c.manifestHash = bytes32(uint256(2));
        c.manifestURI = "ipfs://owners";
        c.signatureGas = IStreamGasParameterHost.GasParameterConfig(
            "METADATA_ERC1271_VERIFY_GAS", 150000, 90000, 2
        );
        c.dependencyReadGas = IStreamGasParameterHost.GasParameterConfig(
            "METADATA_DEPENDENCY_READ_GAS", 150000, 100000, 2
        );
        StreamOwnerRecords dossier = new StreamOwnerRecords(c);
        core.setToken(7, address(this), 2);
        IStreamOwnerRecords.OwnerRecord memory r;
        r.recordType = keccak256("ACCESSION");
        r.subjectId = dossier.deriveOwnerSubject(7);
        r.schemaId = id;
        r.contentHash = IStreamPreservationRecords.HashRef(
            1, abi.encode(keccak256(bytes("evidence"))), schemas.RAW_BYTES()
        );
        r.payload = bytes("evidence");
        r.effectiveAt = 1;
        safeVm.cool(address(schemas));
        dossier.recordOwnerRecord(7, r);
        (, IStreamOwnerRecords.Receipt memory receipt) =
            dossier.ownerRecord(dossier.recordHashAt(7, r.recordType, 0));
        require(
            receipt.schemaDefinitionHash == facts.contentHash,
            "actual owner admission maximum schema"
        );
    }

    function testUnknownDefinitionIndicesAndAdditiveInterfaceDiscovery() public {
        bytes32 unknown = keccak256("UNKNOWN");
        IStreamSchemaDocumentFacts.DocumentFacts memory absent = schemas.documentFacts(unknown);
        require(keccak256(abi.encode(absent)) == keccak256(new bytes(288)), "explicit zero absence");
        vm.expectRevert(
            abi.encodeWithSelector(IStreamSchemaRegistry.DocumentUnknown.selector, unknown)
        );
        schemas.documentChunkHashAt(unknown, 0);
        vm.expectRevert(abi.encodeWithSignature("Panic(uint256)", uint256(0x32)));
        schemas.documentChunkHashAt(schemaId, 1);
        require(
            schemas.supportsInterface(type(IStreamSchemaRegistry).interfaceId)
                && schemas.supportsInterface(type(IStreamSchemaDocumentFacts).interfaceId)
                && schemas.supportsInterface(0x01ffc9a7) && !schemas.supportsInterface(0xffffffff),
            "additive schema IDs"
        );
    }

    function testMaximumRecordUriColdReceiptPreservesAllOriginalFields() public {
        bytes memory payload = bytes("{\"meaning\":\"long URI\"}");
        IStreamPreservationRecords.CollectionRecord memory r = _record(CURATOR, payload);
        r.uri = string(abi.encodePacked("ipfs://", _repeat(2041, 0x75)));
        bytes32 hash = metadata.recordCollectionRecordWithPayload(1, r, payload);
        safeVm.cool(address(metadata));
        (bool legacyOk,) = address(metadata).staticcall{ gas: 150000 }(
            abi.encodeCall(metadata.collectionRecord, (hash))
        );
        require(!legacyOk, "maximum legacy record diagnostic");
        safeVm.cool(address(metadata));
        (bool ok, bytes memory output) = address(metadata).staticcall{ gas: 150000 }(
            abi.encodeCall(metadata.collectionRecordReceipt, (hash))
        );
        require(ok && output.length == 288, "actual receipt cold150k");
        (, IStreamCollectionMetadataV1.RecordReceipt memory full) = metadata.collectionRecord(hash);
        require(keccak256(output) == keccak256(abi.encode(full)), "all nine original receipt words");
        require(
            hash == _oldRecordHash(address(this), r)
                && metadata.recordHashAt(1, CURATOR, full.recordIndex) == hash,
            "complete witness and actual lane"
        );
        require(
            metadata.supportsInterface(type(IStreamCollectionMetadataV1).interfaceId)
                && metadata.supportsInterface(type(IStreamCollectionRecordReceipts).interfaceId)
                && !metadata.supportsInterface(0xffffffff),
            "additive metadata IDs"
        );
        bytes32 unknown = keccak256("UNKNOWN");
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamCollectionMetadataV1.UnknownMetadataRecord.selector, unknown
            )
        );
        metadata.collectionRecordReceipt(unknown);
    }

    function testCollectionIngressUsesMaximumColdDefinitionWithoutCapChange() public {
        (bytes32 id,) = _maximumDocument();
        bytes memory payload = bytes("{\"meaning\":\"maximum schema\"}");
        IStreamPreservationRecords.CollectionRecord memory r = _record(CURATOR, payload);
        r.schemaId = id;
        safeVm.cool(address(schemas));
        bytes32 hash = metadata.recordCollectionRecordWithPayload(1, r, payload);
        IStreamCollectionMetadataV1.RecordReceipt memory receipt =
            metadata.collectionRecordReceipt(hash);
        require(
            receipt.schemaDefinitionHash == keccak256(new bytes(524288)),
            "cold ingress complete definition identity"
        );
    }
}
