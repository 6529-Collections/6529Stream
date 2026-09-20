// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamRightsRecordSelection.t.sol";
import "../../../smart-contracts/domains/metadata/StreamConservationSaleRights.sol";

contract ConservationSaleRightsConsumer {
    function current(StreamConservationSaleRights.Dependencies calldata d, uint256 collectionId)
        external
        view
        returns (IStreamRightsRecordSelection.Selection memory)
    {
        return StreamConservationSaleRights.requireCurrent(d, collectionId);
    }
}

/// @notice Actual Metadata, Schema/Store, full original RIGHTS publication and selection.
/// @dev Reuses the existing concrete fixture; run only testSaleRights* for this focused cohort.
///      Core/Artist/Executor are typed boundaries. Adversarial mocked reads are explicit and
///      cleared before the healthy retry. No WORK publisher or finality lock is installed.
contract StreamConservationSaleRightsTest is StreamRightsRecordSelectionTest {
    bytes32 private constant _RIGHTS = keccak256("RIGHTS_STATEMENT");

    function _dependencies()
        private
        view
        returns (StreamConservationSaleRights.Dependencies memory d)
    {
        d.targets = [
            address(core), address(metadata), address(schemas), address(store), address(selection)
        ];
        for (uint256 i; i < 5; ++i) {
            d.codeHashes[i] = d.targets[i].codehash;
        }
        d.chainId = block.chainid;
        d.readGas = 300000;
        d.selectionGas = 3000000;
    }

    function _selected()
        private
        returns (bytes32 hash, StreamRightsRecordTypes.Statement memory statement)
    {
        _prepare();
        statement = _statement();
        statement.grants.publication.extension = "Retain the original attribution on museum labels.";
        hash = _published(statement);
        selection.selectCurrent(1, subject, hash, 0, 0, statement);
    }

    function _receipt(bytes32 hash)
        private
        view
        returns (IStreamCollectionMetadataV1.RecordReceipt memory)
    {
        return metadata.collectionRecordReceipt(hash);
    }

    function _mockReceipt(bytes32 hash, IStreamCollectionMetadataV1.RecordReceipt memory receipt)
        private
    {
        RightsSelectionFileVm(address(vm))
            .mockCall(
                address(metadata),
                abi.encodeCall(IStreamCollectionRecordReceipts.collectionRecordReceipt, (hash)),
                abi.encode(receipt)
            );
    }

    function _expectReceipt(bytes32 hash) private {
        vm.expectRevert(
            abi.encodeWithSelector(StreamConservationSaleRights.SaleRightsReceipt.selector, hash)
        );
    }

    function _expectCurrentRead() private {
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamConservationSaleRights.SaleRightsRead.selector,
                address(selection),
                IStreamRightsRecordSelection.requireCurrent.selector
            )
        );
    }

    function testSaleRightsActualFullBytesPassWithoutWorkOrLock() public {
        (bytes32 hash, StreamRightsRecordTypes.Statement memory statement) = _selected();
        ConservationSaleRightsConsumer consumer = new ConservationSaleRightsConsumer();
        StreamConservationSaleRights.Dependencies memory d = _dependencies();
        IStreamRightsRecordSelection.Selection memory result = consumer.current(d, 1);
        (, bytes memory original) = metadata.recordPayload(hash);
        require(
            keccak256(original) == keccak256(StreamRightsRecordJson.serialize(statement))
                && result.payloadHash == keccak256(original),
            "actual complete original statement bytes"
        );
        require(
            result.recordHash == hash && result.recordIndex == 0
                && result.recorder == address(this),
            "actual original selector and receipt"
        );
        IStreamCollectionMetadataV1.RecordReceipt memory receipt = _receipt(hash);
        require(
            receipt.schemaDefinitionHash == StreamRightsRecordDefinitions.SCHEMA_HASH
                && receipt.canonicalizationDefinitionHash
                    == StreamRightsRecordDefinitions.CANON_HASH
                && metadata.recordHashAt(1, _RIGHTS, receipt.recordIndex) == hash,
            "original definitions and lane position"
        );
        (, uint64 workCount) = metadata.recordChainHash(1, keccak256("WORK_DESCRIPTION"));
        require(
            workCount == 0 && !selection.selectionLock(1, subject).locked,
            "no WORK or finality lock requirement"
        );
    }

    function testSaleRightsEveryWrongRuntimePinRejects() public {
        _selected();
        ConservationSaleRightsConsumer consumer = new ConservationSaleRightsConsumer();
        for (uint256 i; i < 5; ++i) {
            StreamConservationSaleRights.Dependencies memory d = _dependencies();
            d.codeHashes[i] = bytes32(uint256(d.codeHashes[i]) ^ 1);
            vm.expectRevert(
                abi.encodeWithSelector(
                    StreamConservationSaleRights.SaleRightsDependency.selector, d.targets[i]
                )
            );
            consumer.current(d, 1);
        }
        require(consumer.current(_dependencies(), 1).recordHash != 0, "healthy exact pins retry");
    }

    function testSaleRightsForeignSourceAndSelectorBindingPinsReject() public {
        _selected();
        ConservationSaleRightsConsumer consumer = new ConservationSaleRightsConsumer();
        StreamConservationSaleRights.Dependencies memory d = _dependencies();
        MetadataCoreBoundary foreign = new MetadataCoreBoundary();
        d.targets[0] = address(foreign);
        d.codeHashes[0] = address(foreign).codehash;
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamConservationSaleRights.SaleRightsDependency.selector, address(selection)
            )
        );
        consumer.current(d, 1);
        d = _dependencies();
        RightsSelectionFileVm(address(vm))
            .mockCall(
                address(selection),
                abi.encodeCall(IStreamRightsRecordSelection.metadata, ()),
                abi.encode(address(schemas))
            );
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamConservationSaleRights.SaleRightsDependency.selector, address(selection)
            )
        );
        consumer.current(d, 1);
        RightsSelectionFileVm(address(vm)).clearMockedCalls();
        require(consumer.current(d, 1).recordHash != 0, "original producer retry");
    }

    function testSaleRightsAlteredOriginalReceiptFieldsRejectAndRetry() public {
        (bytes32 hash,) = _selected();
        ConservationSaleRightsConsumer consumer = new ConservationSaleRightsConsumer();
        StreamConservationSaleRights.Dependencies memory d = _dependencies();
        bytes memory original = abi.encode(_receipt(hash));
        for (uint256 field; field < 8; ++field) {
            IStreamCollectionMetadataV1.RecordReceipt memory receipt =
                abi.decode(original, (IStreamCollectionMetadataV1.RecordReceipt));
            if (field == 0) receipt.collectionId = 2;
            if (field == 1) receipt.recordIndex += 1;
            if (field == 2) receipt.recorder = address(0xBAD);
            if (field == 3) receipt.authorizationClass = 8;
            if (field == 4) receipt.schemaDefinitionHash = keccak256("different schema");
            if (field == 5) {
                receipt.canonicalizationDefinitionHash = keccak256("different canonicalizer");
            }
            if (field == 6) receipt.recordChainHash = 0;
            if (field == 7) receipt.recordedAt = 0;
            _mockReceipt(hash, receipt);
            _expectReceipt(hash);
            consumer.current(d, 1);
            RightsSelectionFileVm(address(vm)).clearMockedCalls();
        }
        require(consumer.current(d, 1).recordHash == hash, "unaltered original receipt accepted");
    }

    function testSaleRightsWrongOriginalLanePositionRejects() public {
        (bytes32 hash,) = _selected();
        ConservationSaleRightsConsumer consumer = new ConservationSaleRightsConsumer();
        StreamConservationSaleRights.Dependencies memory d = _dependencies();
        RightsSelectionFileVm(address(vm))
            .mockCall(
                address(metadata),
                abi.encodeCall(
                    IStreamCollectionMetadataV1.recordHashAt, (uint256(1), _RIGHTS, uint256(0))
                ),
                abi.encode(keccak256("different original record"))
            );
        _expectReceipt(hash);
        consumer.current(d, 1);
        RightsSelectionFileVm(address(vm)).clearMockedCalls();
        require(consumer.current(d, 1).recordIndex == 0, "original lane position restored");
    }

    function testSaleRightsAbsentSelectionAndWrongCollectionCannotReuseRecord() public {
        _prepare();
        StreamRightsRecordTypes.Statement memory statement = _statement();
        bytes32 hash = _published(statement);
        ConservationSaleRightsConsumer consumer = new ConservationSaleRightsConsumer();
        StreamConservationSaleRights.Dependencies memory d = _dependencies();
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamConservationSaleRights.SaleRightsSelection.selector, bytes32(0)
            )
        );
        consumer.current(d, 1);
        selection.selectCurrent(1, subject, hash, 0, 0, statement);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamConservationSaleRights.SaleRightsSelection.selector, bytes32(0)
            )
        );
        consumer.current(d, 2);
        require(
            consumer.current(d, 1).recordHash == hash,
            "correct collection consumes actual selected record"
        );
    }

    function testSaleRightsSuccessorUsesCurrentHeadAndKeepsOriginalHistory() public {
        (bytes32 first, StreamRightsRecordTypes.Statement memory statement) = _selected();
        ConservationSaleRightsConsumer consumer = new ConservationSaleRightsConsumer();
        StreamConservationSaleRights.Dependencies memory d = _dependencies();
        require(consumer.current(d, 1).recordHash == first, "initial current record");
        statement.predecessor = first;
        statement.grants.print.status = StreamRightsRecordTypes.Status.DENIED;
        bytes32 second = _published(statement);
        selection.selectCurrent(1, subject, second, first, 1, statement);
        IStreamRightsRecordSelection.Selection memory result = consumer.current(d, 1);
        require(
            result.recordHash == second && result.revision == 2 && result.recordIndex == 1,
            "new consumer uses actual current revision"
        );
        require(
            selection.rightsSelectionAt(1, subject, 1).recordHash == first
                && metadata.recordHashAt(1, _RIGHTS, 0) == first,
            "original records and selection remain"
        );
    }

    function testSaleRightsStaleCurrentSlotCannotBypassNativeRequireCurrent() public {
        (bytes32 first, StreamRightsRecordTypes.Statement memory statement) = _selected();
        IStreamRightsRecordSelection.Selection memory prior = selection.currentRights(1, subject);
        statement.predecessor = first;
        statement.grants.print.status = StreamRightsRecordTypes.Status.DENIED;
        bytes32 second = _published(statement);
        selection.selectCurrent(1, subject, second, first, 1, statement);
        ConservationSaleRightsConsumer consumer = new ConservationSaleRightsConsumer();
        StreamConservationSaleRights.Dependencies memory d = _dependencies();
        RightsSelectionFileVm(address(vm))
            .mockCall(
                address(selection),
                abi.encodeCall(IStreamRightsRecordSelection.currentRights, (uint256(1), subject)),
                abi.encode(prior)
            );
        _expectCurrentRead();
        consumer.current(d, 1);
        RightsSelectionFileVm(address(vm)).clearMockedCalls();
        require(consumer.current(d, 1).recordHash == second, "native current revision succeeds");
    }

    function testSaleRightsChangedSelectedMetadataHostRefusesHistoricalSelection() public {
        (bytes32 hash,) = _selected();
        ConservationSaleRightsConsumer consumer = new ConservationSaleRightsConsumer();
        StreamConservationSaleRights.Dependencies memory d = _dependencies();
        core.setPointer(keccak256("COLLECTION_METADATA"), address(schemas));
        _expectCurrentRead();
        consumer.current(d, 1);
        require(selection.currentRights(1, subject).recordHash == hash, "history still readable");
        core.setPointer(keccak256("COLLECTION_METADATA"), address(metadata));
        require(consumer.current(d, 1).recordHash == hash, "actual selected host retry");
    }

    function testSaleRightsSchemaDefinitionHashAndFullChunkBytesAreRechecked() public {
        (bytes32 hash,) = _selected();
        ConservationSaleRightsConsumer consumer = new ConservationSaleRightsConsumer();
        StreamConservationSaleRights.Dependencies memory d = _dependencies();
        bytes32 schema = StreamRightsRecordDefinitions.SCHEMA_ID;
        IStreamSchemaDocumentFacts.DocumentFacts memory facts = schemas.documentFacts(schema);
        facts.contentHash = keccak256("different registered schema");
        RightsSelectionFileVm(address(vm))
            .mockCall(
                address(schemas),
                abi.encodeCall(IStreamSchemaDocumentFacts.documentFacts, (schema)),
                abi.encode(facts)
            );
        _expectCurrentRead();
        consumer.current(d, 1);
        RightsSelectionFileVm(address(vm)).clearMockedCalls();
        bytes32 lastChunk = schemas.documentChunkHashAt(schema, 1);
        RightsSelectionFileVm(address(vm))
            .mockCall(
                address(store),
                abi.encodeCall(StreamSchemaDocumentStore.readChunk, (lastChunk)),
                abi.encode(bytes("truncated last schema chunk"))
            );
        _expectCurrentRead();
        consumer.current(d, 1);
        RightsSelectionFileVm(address(vm)).clearMockedCalls();
        require(
            consumer.current(d, 1).recordHash == hash, "complete exact two-chunk definition retry"
        );
    }

    function testSaleRightsRetiredDefinitionCannotBeConsumedThoughHistorySurvives() public {
        (bytes32 hash,) = _selected();
        ConservationSaleRightsConsumer consumer = new ConservationSaleRightsConsumer();
        StreamConservationSaleRights.Dependencies memory d = _dependencies();
        bytes32 id = StreamRightsRecordDefinitions.PROFILE_ID;
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            schemas.statusTransition(id, IStreamSchemaRegistry.DocumentStatus.DEPRECATED);
        executor.execute(
            address(schemas),
            abi.encodeCall(
                schemas.setDocumentStatus, (id, IStreamSchemaRegistry.DocumentStatus.DEPRECATED)
            ),
            scope,
            oldHash,
            newHash
        );
        _expectCurrentRead();
        consumer.current(d, 1);
        require(
            selection.currentRights(1, subject).recordHash == hash,
            "retirement never erases original selection"
        );
    }

    function testSaleRightsMalformedOriginalReceiptAndSelectionReadsFailClosed() public {
        (bytes32 hash,) = _selected();
        ConservationSaleRightsConsumer consumer = new ConservationSaleRightsConsumer();
        StreamConservationSaleRights.Dependencies memory d = _dependencies();
        for (uint256 i; i < 2; ++i) {
            RightsSelectionFileVm(address(vm))
                .mockCall(
                    address(metadata),
                    abi.encodeCall(IStreamCollectionRecordReceipts.collectionRecordReceipt, (hash)),
                    new bytes(i == 0 ? 256 : 320)
                );
            vm.expectRevert(
                abi.encodeWithSelector(
                    StreamConservationSaleRights.SaleRightsRead.selector,
                    address(metadata),
                    IStreamCollectionRecordReceipts.collectionRecordReceipt.selector
                )
            );
            consumer.current(d, 1);
            RightsSelectionFileVm(address(vm)).clearMockedCalls();
            RightsSelectionFileVm(address(vm))
                .mockCall(
                    address(selection),
                    abi.encodeCall(
                        IStreamRightsRecordSelection.currentRights, (uint256(1), subject)
                    ),
                    new bytes(i == 0 ? 416 : 480)
                );
            vm.expectRevert(
                abi.encodeWithSelector(
                    StreamConservationSaleRights.SaleRightsRead.selector,
                    address(selection),
                    IStreamRightsRecordSelection.currentRights.selector
                )
            );
            consumer.current(d, 1);
            RightsSelectionFileVm(address(vm)).clearMockedCalls();
        }
        require(consumer.current(d, 1).recordHash == hash, "exact return shapes retry");
    }

    function testSaleRightsAlteredSelectedMeaningCannotReuseOriginalSelectionHash() public {
        (bytes32 hash,) = _selected();
        ConservationSaleRightsConsumer consumer = new ConservationSaleRightsConsumer();
        StreamConservationSaleRights.Dependencies memory d = _dependencies();
        IStreamRightsRecordSelection.Selection memory selected = selection.currentRights(1, subject);
        selected.payloadHash = keccak256("changed meaning");
        RightsSelectionFileVm(address(vm))
            .mockCall(
                address(selection),
                abi.encodeCall(IStreamRightsRecordSelection.currentRights, (uint256(1), subject)),
                abi.encode(selected)
            );
        vm.expectRevert(
            abi.encodeWithSelector(StreamConservationSaleRights.SaleRightsSelection.selector, hash)
        );
        consumer.current(d, 1);
        RightsSelectionFileVm(address(vm)).clearMockedCalls();
        require(consumer.current(d, 1).recordHash == hash, "exact original commitment retry");
    }

    function testSaleRightsChainAndGasConfigurationFailClosed() public {
        _selected();
        ConservationSaleRightsConsumer consumer = new ConservationSaleRightsConsumer();
        for (uint256 i; i < 3; ++i) {
            StreamConservationSaleRights.Dependencies memory d = _dependencies();
            if (i == 0) d.chainId += 1;
            if (i == 1) d.readGas = 0;
            if (i == 2) d.selectionGas = d.readGas - 1;
            vm.expectRevert(
                abi.encodeWithSelector(
                    StreamConservationSaleRights.InvalidSaleRightsConfiguration.selector
                )
            );
            consumer.current(d, 1);
        }
    }

    function executeSaleRightsSafe(
        OfficialSafe account,
        uint256[] calldata keys,
        ConservationSaleRightsConsumer consumer,
        StreamConservationSaleRights.Dependencies calldata d
    ) external {
        require(msg.sender == address(this), "test wrapper only");
        require(
            executeSafe(
                account,
                keys,
                address(consumer),
                0,
                abi.encodeCall(consumer.current, (d, uint256(1))),
                0
            ),
            "actual Safe rights floor read"
        );
    }

    function testSaleRightsActualSafeReadsAndBadPinRollsBackNonce() public {
        (bytes32 hash,) = _selected();
        ConservationSaleRightsConsumer consumer = new ConservationSaleRightsConsumer();
        StreamConservationSaleRights.Dependencies memory d = _dependencies();
        uint256[] memory keys = new uint256[](2);
        keys[0] = 791;
        keys[1] = 792;
        OfficialSafe account =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 7910);
        this.executeSaleRightsSafe(account, keys, consumer, d);
        require(
            account.nonce() == 1 && selection.currentRights(1, subject).recordHash == hash,
            "threshold read preserves original selection"
        );
        d.codeHashes[1] = keccak256("bad metadata pin");
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeSaleRightsSafe(account, keys, consumer, d);
        require(account.nonce() == 1, "failed pinned dependency read rolls back Safe nonce");
    }

    function testSaleRightsFuzzReceiptSchemaHashMustBeExact(bytes32 replacement) public {
        if (replacement == StreamRightsRecordDefinitions.SCHEMA_HASH) return;
        (bytes32 hash,) = _selected();
        ConservationSaleRightsConsumer consumer = new ConservationSaleRightsConsumer();
        StreamConservationSaleRights.Dependencies memory d = _dependencies();
        IStreamCollectionMetadataV1.RecordReceipt memory receipt = _receipt(hash);
        receipt.schemaDefinitionHash = replacement;
        _mockReceipt(hash, receipt);
        _expectReceipt(hash);
        consumer.current(d, 1);
        RightsSelectionFileVm(address(vm)).clearMockedCalls();
        require(consumer.current(d, 1).recordHash == hash, "original schema hash only");
    }
}
