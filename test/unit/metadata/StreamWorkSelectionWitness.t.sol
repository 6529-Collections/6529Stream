// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamWorkSelectionFixture.sol";

contract StreamWorkSelectionWitnessTest is WorkSelectionFixture {
    function testAllOptionalAVAndFullWidthValuesRemainExactThroughSelection() public ready {
        _bound(type(uint64).max, BINDING, 2);
        StreamWorkRecordTypes.Description memory d = _artistDescription();
        d.full.creator.bindingGeneration = type(uint64).max;
        d.full.title = unicode"Exact é 🎨 title";
        d.full.creation =
            StreamWorkRecordTypes.Creation(StreamWorkRecordTypes.DateKind.RANGE, 10101, 99991231);
        d.full.measurements = StreamWorkRecordTypes.Measurements(
            StreamWorkRecordTypes.MeasurementKind.MEASURED,
            true,
            type(uint256).max,
            type(uint256).max - 1,
            true,
            StreamWorkRecordTypes.Rational(2, 4),
            true,
            StreamWorkRecordTypes.Rational(type(uint256).max - 1, type(uint256).max)
        );
        d.full.edition = StreamWorkRecordTypes.Edition(
            StreamWorkRecordTypes.EditionKind.SERIAL, type(uint256).max - 1, type(uint256).max, ""
        );
        d.full.creditLine = "Credit\r\nretained";
        d.full.hasInscription = true;
        d.full.inscription = "Exact inscription\x01";
        d.full.alternateTitles = new string[](1);
        d.full.alternateTitles[0] = "Titre";
        d.full.languageVariants = new StreamWorkRecordTypes.LanguageVariant[](1);
        d.full.languageVariants[0] = StreamWorkRecordTypes.LanguageVariant(
            StreamWorkRecordTypes.VariantField.ALTERNATE_TITLE, 0, "fr", "Titre"
        );
        d.full.authorityReferences = new StreamWorkRecordTypes.AuthorityReference[](1);
        d.full.authorityReferences[0] = StreamWorkRecordTypes.AuthorityReference(
            StreamWorkRecordTypes.AuthorityRole.TECHNIQUE,
            StreamWorkRecordTypes.Authority.GETTY_AAT,
            "300054698"
        );
        d.full.format.kind = StreamWorkRecordTypes.FormatKind.PRONOM;
        d.full.format.puid = "fmt/199";
        d.full.format.formatId = keccak256("PRONOM:fmt/199");
        bytes memory exact = StreamWorkRecordJson.serialize(d);
        bytes32 hash = _curatorPublish(d);
        IStreamWorkRecordSelection.Selection memory s =
            selection.selectCurrent(1, subject, hash, 0, 0, _witness(hash, d));
        (, bytes memory saved) = metadata.recordPayload(hash);
        require(
            saved.length == exact.length && keccak256(saved) == keccak256(exact)
                && s.payloadHash == keccak256(exact),
            "complete original canonical bytes"
        );
        require(s.creatorAssociation.generation == type(uint64).max, "no generation narrowing");
    }

    function testConstructorRejectsMissingCompactCapabilityAndHealthyRetry() public ready {
        address[2] memory targets = [address(metadata), address(schemas)];
        bytes4[2] memory ids = [
            type(IStreamCollectionRecordReceipts).interfaceId,
            type(IStreamSchemaDocumentFacts).interfaceId
        ];
        for (uint256 i; i < targets.length; ++i) {
            workVm.mockCall(
                targets[i], abi.encodeCall(IERC165.supportsInterface, (ids[i])), abi.encode(false)
            );
            vm.expectRevert(
                abi.encodeWithSelector(IStreamWorkRecordSelection.InvalidWorkConfiguration.selector)
            );
            new StreamWorkRecordSelection(address(core), address(metadata), address(schemas));
            workVm.clearMockedCalls();
        }
        StreamWorkRecordSelection healthy =
            new StreamWorkRecordSelection(address(core), address(metadata), address(schemas));
        require(
            healthy.metadata() == address(metadata), "healthy identical constructor dependencies"
        );
    }

    function testEveryOuterRecordFieldIsCommittedAndOriginalWitnessRetries() public ready {
        StreamWorkRecordTypes.Description memory d = _named();
        bytes32 hash = _curatorPublish(d);
        for (uint256 i; i < 12; ++i) {
            IStreamWorkRecordSelection.Witness memory w = _witness(hash, d);
            if (i == 0) w.original.recordType = keccak256("FOREIGN");
            if (i == 1) w.original.subjectId = keccak256("foreign subject");
            if (i == 2) w.original.schemaId = keccak256("foreign schema");
            if (i == 3) w.original.uri = "ipfs://foreign-record";
            if (i == 4) w.original.effectiveAt += 1;
            if (i == 5) w.original.contentHash.algorithm = 2;
            if (i == 6) w.original.contentHash.digest = abi.encode(keccak256("foreign payload"));
            if (i == 7) w.original.contentHash.canonicalizationId = keccak256("FOREIGN_CANON");
            if (i == 8) w.original.signatureScheme = keccak256("inactive signature scheme");
            if (i == 9) w.original.signatureHash.algorithm = 1;
            if (i == 10) w.original.signatureHash.digest = hex"00";
            if (i == 11) {
                w.original.signatureHash.canonicalizationId = keccak256("inactive canonicalization");
            }
            vm.expectRevert(
                abi.encodeWithSelector(IStreamWorkRecordSelection.InvalidWorkRecord.selector, hash)
            );
            selection.selectCurrent(1, subject, hash, 0, 0, w);
            require(
                selection.currentWork(1, subject).recordHash == 0, "outer mismatch did not advance"
            );
        }
        selection.selectCurrent(1, subject, hash, 0, 0, _witness(hash, d));
    }

    function testActualReceiptAndIndexedLaneAreBothRequired() public ready {
        StreamWorkRecordTypes.Description memory d = _named();
        bytes32 hash = _curatorPublish(d);
        bytes memory input = abi.encodeCall(IStreamCollectionMetadataV1.recordHashAt, (1, WORK, 0));
        workVm.mockCall(address(metadata), input, abi.encode(keccak256("foreign lane member")));
        vm.expectRevert(
            abi.encodeWithSelector(IStreamWorkRecordSelection.InvalidWorkRecord.selector, hash)
        );
        selection.selectCurrent(1, subject, hash, 0, 0, _witness(hash, d));
        workVm.clearMockedCalls();
        IStreamWorkRecordSelection.Witness memory w = _witness(hash, d);
        bytes32 unknown = keccak256("unrecorded original");
        vm.expectRevert();
        selection.selectCurrent(1, subject, unknown, 0, 0, w);
        require(
            selection.currentWork(1, subject).revision == 0,
            "neither unrecorded nor unindexed admitted"
        );
        selection.selectCurrent(1, subject, hash, 0, 0, w);
    }

    function testCompactDefinitionHeaderNarrowWordsAndSemanticPinsReject() public ready {
        StreamWorkRecordTypes.Description memory d = _named();
        bytes32 hash = _curatorPublish(d);
        bytes32 id = StreamWorkRecordDefinitions.SCHEMA_ID;
        IStreamSchemaDocumentFacts.DocumentFacts memory facts =
            IStreamSchemaDocumentFacts(address(schemas)).documentFacts(id);
        bytes memory input = abi.encodeCall(IStreamSchemaDocumentFacts.documentFacts, (id));
        for (uint256 i; i < 9; ++i) {
            bytes memory raw = abi.encode(facts);
            if (i == 0) _setWord(raw, 0, 2); // noncanonical bool
            if (i == 1) _setWord(raw, 1, 256); // noncanonical/closed kind
            if (i == 2) _setWord(raw, 2, 256); // noncanonical/closed status
            if (i == 3) _setWord(raw, 3, uint256(keccak256("foreign content")));
            if (i == 4) _setWord(raw, 4, uint256(keccak256("foreign canonicalization")));
            if (i == 5) _setWord(raw, 5, 1); // fixed interpretation is its first version
            if (i == 6) _setWord(raw, 6, uint256(1) << 32); // dirty uint32
            if (i == 7) _setWord(raw, 7, 65); // full document bound
            if (i == 8) _setWord(raw, 8, 0); // missing immutable declaration provenance
            workVm.mockCall(address(schemas), input, raw);
            vm.expectRevert();
            selection.selectCurrent(1, subject, hash, 0, 0, _witness(hash, d));
            workVm.clearMockedCalls();
        }
        selection.selectCurrent(1, subject, hash, 0, 0, _witness(hash, d));
    }

    function testCompleteDefinitionChunkOrderAndCountAreNotGlobalInventory() public ready {
        StreamWorkRecordTypes.Description memory d = _named();
        bytes32 hash = _curatorPublish(d);
        bytes32 id = StreamWorkRecordDefinitions.SCHEMA_ID;
        IStreamSchemaDocumentFacts source = IStreamSchemaDocumentFacts(address(schemas));
        require(source.documentFacts(id).chunkCount == 2, "real multichunk schema");
        bytes32 second = source.documentChunkHashAt(id, 1);
        bytes memory input = abi.encodeCall(IStreamSchemaDocumentFacts.documentChunkHashAt, (id, 0));
        workVm.mockCall(address(schemas), input, abi.encode(second));
        vm.expectRevert();
        selection.selectCurrent(1, subject, hash, 0, 0, _witness(hash, d));
        workVm.clearMockedCalls();
        IStreamSchemaDocumentFacts.DocumentFacts memory facts = source.documentFacts(id);
        facts.chunkCount = 1;
        workVm.mockCall(
            address(schemas),
            abi.encodeCall(IStreamSchemaDocumentFacts.documentFacts, (id)),
            abi.encode(facts)
        );
        vm.expectRevert();
        selection.selectCurrent(1, subject, hash, 0, 0, _witness(hash, d));
        workVm.clearMockedCalls();
        selection.selectCurrent(1, subject, hash, 0, 0, _witness(hash, d));
    }

    function testRepeatedDocumentChunksReconstructExactBytes() public ready {
        bytes memory part = new bytes(8192);
        for (uint256 i; i < part.length; ++i) {
            part[i] = bytes1(uint8(i));
        }
        bytes memory original = bytes.concat(part, part, hex"00ff");
        bytes32 id = _registerDocument(
            "REPEATED_EXACT_BYTES",
            IStreamSchemaRegistry.DocumentKind.CATALOG,
            original,
            schemas.RAW_BYTES()
        );
        IStreamSchemaDocumentFacts source = IStreamSchemaDocumentFacts(address(schemas));
        require(
            source.documentChunkHashAt(id, 0) == source.documentChunkHashAt(id, 1),
            "ordered repeated chunks retained"
        );
        StreamWorkRecordContext.Dependencies memory deps;
        deps.targets = [address(core), address(metadata), address(schemas), address(store)];
        deps.readGas = 150000;
        bytes memory actual = StreamWorkRecordContext.definition(
            deps,
            id,
            IStreamSchemaRegistry.DocumentKind.CATALOG,
            keccak256(original),
            original.length,
            schemas.RAW_BYTES(),
            true
        );
        require(
            actual.length == original.length && keccak256(actual) == keccak256(original),
            "whole raw bytes including repetition"
        );
    }

    function testReceiptCanonicalWidthsAndRollingChainMutationReject() public ready {
        StreamWorkRecordTypes.Description memory d = _named();
        bytes32 hash = _curatorPublish(d);
        IStreamCollectionMetadataV1.RecordReceipt memory receipt =
            IStreamCollectionRecordReceipts(address(metadata)).collectionRecordReceipt(hash);
        bytes memory input =
            abi.encodeCall(IStreamCollectionRecordReceipts.collectionRecordReceipt, (hash));
        for (uint256 i; i < 7; ++i) {
            bytes memory raw = abi.encode(receipt);
            if (i == 0) _setWord(raw, 1, uint256(1) << 160);
            if (i == 1) _setWord(raw, 2, 256);
            if (i == 2) _setWord(raw, 3, uint256(1) << 64);
            if (i == 3) _setWord(raw, 4, uint256(1) << 64);
            if (i == 4) _setWord(raw, 5, uint256(keccak256("foreign chain")));
            if (i == 5) _setWord(raw, 6, uint256(keccak256("foreign schema bytes")));
            if (i == 6) _setWord(raw, 7, uint256(keccak256("foreign canon bytes")));
            workVm.mockCall(address(metadata), input, raw);
            vm.expectRevert();
            selection.selectCurrent(1, subject, hash, 0, 0, _witness(hash, d));
            workVm.clearMockedCalls();
        }
        selection.selectCurrent(1, subject, hash, 0, 0, _witness(hash, d));
    }

    function _setWord(bytes memory raw, uint256 index, uint256 value) private pure {
        assembly ("memory-safe") { mstore(add(add(raw, 32), mul(index, 32)), value) }
    }
}
