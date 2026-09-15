// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../metadata/StreamWorkSelectionFixture.sol";
import "../../../smart-contracts/domains/metadata/StreamRightsRecordSelection.sol";
import "../../../smart-contracts/domains/finality/StreamFinalityDescriptionReads.sol";

/// @dev Fixed graph boundary for the developing complete provider. No membership or finality claim.
contract FinalityDescriptionConsumerBoundary {
    StreamFinalityDescriptionReads.Dependencies private dependencies;

    constructor(StreamFinalityDescriptionReads.Dependencies memory d) {
        dependencies = d;
    }

    function requireCurrent(StreamFinalityScope calldata scope)
        external
        view
        returns (StreamFinalityDescriptionEvidence memory)
    {
        return StreamFinalityDescriptionReads.requireCurrent(dependencies, scope);
    }
}

interface DescriptionEvidenceVm {
    function etch(address, bytes calldata) external;
    function chainId(uint256) external;
}

/// @notice Actual WORK/RIGHTS selectors, Metadata, Schema and Store in one shared graph.
/// @dev Core, Executor and artist owners are the existing typed domain boundaries. The fixed
///      consumer is not a complete provider; independent scope membership remains required.
contract StreamFinalityDescriptionReadsTest is WorkSelectionFixture {
    DescriptionEvidenceVm private constant evm = DescriptionEvidenceVm(address(vm));
    StreamRightsRecordSelection private rights;
    FinalityDescriptionConsumerBoundary private consumer;
    bytes32 private workHash;
    bytes32 private rightsHash;
    bytes32 private constant RIGHTS_TYPE = keccak256("RIGHTS_STATEMENT");
    event log_named_uint(string key, uint256 value);

    modifier descriptionsReady() {
        _prepareDescriptions();
        _;
    }

    function _prepareDescriptions() private {
        _prepare();
        _registerDocument(
            "STREAM_RIGHTS_V1",
            IStreamSchemaRegistry.DocumentKind.SCHEMA,
            bytes(vm.readFile("schemas/records/STREAM_RIGHTS_V1.json")),
            schemas.RAW_BYTES()
        );
        _registerDocument(
            "STREAM_RIGHTS_JSON_PROFILE_V1",
            IStreamSchemaRegistry.DocumentKind.CATALOG,
            bytes(vm.readFile("schemas/records/STREAM_RIGHTS_JSON_PROFILE_V1.json")),
            schemas.RAW_BYTES()
        );
        _admit(RIGHTS_TYPE, StreamRecordFamilies.RIGHTS, 0x0180);
        _grant(1, StreamRecordFamilies.RIGHTS, 7, address(this), true);
        rights = new StreamRightsRecordSelection(address(core), address(metadata), address(schemas));
        consumer = new FinalityDescriptionConsumerBoundary(_dependencies());
    }

    function _dependencies()
        private
        view
        returns (StreamFinalityDescriptionReads.Dependencies memory d)
    {
        d.targets = [
            address(core),
            address(metadata),
            address(schemas),
            address(store),
            address(selection),
            address(rights)
        ];
        for (uint256 i; i < 6; ++i) {
            d.codeHashes[i] = d.targets[i].codehash;
        }
        d.chainId = block.chainid;
        d.readGas = 500000;
        d.selectionGas = 3000000;
    }

    function _scope() private pure returns (StreamFinalityScope memory) {
        return StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0);
    }

    function _selectWork(StreamWorkRecordTypes.Description memory description) private {
        bytes32 previous = workHash;
        uint64 revision = selection.currentWork(1, subject).revision;
        workHash = _curatorPublish(description);
        selection.selectCurrent(
            1, subject, workHash, previous, revision, _witness(workHash, description)
        );
    }

    function _rightsStatement(bytes32 predecessor)
        private
        view
        returns (StreamRightsRecordTypes.Statement memory s)
    {
        s.subjectId = subject;
        s.profileHash = StreamRightsRecordDefinitions.PROFILE_HASH;
        s.predecessor = predecessor;
        s.licensor.kind = StreamRightsRecordTypes.LicensorKind.ACCOUNT;
        s.licensor.account = address(0x123);
        s.startDate = 20260912;
        s.openEnd = true;
    }

    function _publishRights(StreamRightsRecordTypes.Statement memory statement)
        private
        returns (bytes32)
    {
        bytes memory payload = StreamRightsRecordJson.serialize(statement);
        IStreamPreservationRecords.CollectionRecord memory r = _record(RIGHTS_TYPE, payload);
        r.schemaId = StreamRightsRecordDefinitions.SCHEMA_ID;
        r.contentHash.canonicalizationId = StreamRightsRecordDefinitions.CANON_ID;
        return metadata.recordCollectionRecordWithPayload(1, r, payload);
    }

    function _selectRights() private {
        StreamRightsRecordTypes.Statement memory s = _rightsStatement(rightsHash);
        uint64 revision = rights.currentRights(1, subject).revision;
        bytes32 hash = _publishRights(s);
        rights.selectCurrent(1, subject, hash, rightsHash, revision, s);
        rightsHash = hash;
    }

    function _pair() private {
        _selectWork(_named());
        _selectRights();
    }

    function testActualDescriptionsHaveExactScopeOriginalBytesAndSelectionReceipts()
        public
        descriptionsReady
    {
        _pair();
        StreamFinalityDescriptionEvidence memory e = consumer.requireCurrent(_scope());
        require(
            e.scopeSubject == subject && e.workDescriptionRecordHash == workHash
                && e.rightsStatementRecordHash == rightsHash
        );
        require(e.workPayloadHash == keccak256(StreamWorkRecordJson.serialize(_named())));
        require(
            e.rightsPayloadHash == keccak256(StreamRightsRecordJson.serialize(_rightsStatement(0)))
        );
        require(e.workSelectionHash == selection.currentWork(1, subject).selectionHash);
        require(e.rightsSelectionHash == rights.currentRights(1, subject).selectionHash);
        require(e.workRevision == 1 && e.rightsRevision == 1);
    }

    function testExplicitDescriptionAbsenceAndUnspecifiedRightsAreRecordedInputs()
        public
        descriptionsReady
    {
        _selectWork(_absence(0));
        _selectRights();
        StreamFinalityDescriptionEvidence memory e = consumer.requireCurrent(_scope());
        require(
            e.workDescriptionRecordHash == workHash && e.rightsStatementRecordHash == rightsHash
        );
        require(e.workPayloadHash == keccak256(StreamWorkRecordJson.serialize(_absence(0))));
    }

    function testMissingRightsHeadIsNotAnUnspecifiedRightsDeclaration() public descriptionsReady {
        _selectWork(_named());
        vm.expectRevert();
        consumer.requireCurrent(_scope());
    }

    function testMissingWorkHeadIsNotAnExplicitAbsenceDeclaration() public descriptionsReady {
        _selectRights();
        vm.expectRevert();
        consumer.requireCurrent(_scope());
    }

    function testUnselectedLaterOriginalsDoNotReplaceAuthorizedHeads() public descriptionsReady {
        _pair();
        bytes32 beforeHash = keccak256(abi.encode(consumer.requireCurrent(_scope())));
        _curatorPublish(_absence(workHash));
        _publishRights(_rightsStatement(rightsHash));
        require(keccak256(abi.encode(consumer.requireCurrent(_scope()))) == beforeHash);
    }

    function testActualSupersessionAdvancesEachIndependentReferenceAndRetainsHistory()
        public
        descriptionsReady
    {
        _pair();
        bytes32 oldWork = workHash;
        bytes32 oldRights = rightsHash;
        _selectWork(_absence(workHash));
        _selectRights();
        StreamFinalityDescriptionEvidence memory e = consumer.requireCurrent(_scope());
        require(e.workDescriptionRecordHash != oldWork && e.rightsStatementRecordHash != oldRights);
        require(e.workRevision == 2 && e.rightsRevision == 2);
        require(selection.workSelectionAt(1, subject, 1).recordHash == oldWork);
        require(rights.rightsSelectionAt(1, subject, 1).recordHash == oldRights);
    }

    function testLaterGrantRevocationDoesNotReplayOriginalPublicationAuthority()
        public
        descriptionsReady
    {
        _pair();
        bytes32 beforeHash = keccak256(abi.encode(consumer.requireCurrent(_scope())));
        _grant(1, StreamRecordFamilies.CURATOR, 3, address(this), false);
        _grant(1, StreamRecordFamilies.RIGHTS, 7, address(this), false);
        require(keccak256(abi.encode(consumer.requireCurrent(_scope()))) == beforeHash);
    }

    function testCurrentArtistAssociationChangeRejectsButOriginalSelectionRemains()
        public
        descriptionsReady
    {
        _bound(1, BINDING, 2);
        _selectWork(_artistDescription());
        _selectRights();
        consumer.requireCurrent(_scope());
        _bound(2, keccak256("new binding"), 2);
        vm.expectRevert();
        consumer.requireCurrent(_scope());
        require(selection.currentWork(1, subject).recordHash == workHash);
    }

    function testRetiredDefinitionStopsNewConsumptionAndKeepsOriginalHistory()
        public
        descriptionsReady
    {
        _pair();
        bytes32 id = StreamRightsRecordDefinitions.SCHEMA_ID;
        (bytes32 scope, bytes32 oldHash, bytes32 nextHash) =
            schemas.statusTransition(id, IStreamSchemaRegistry.DocumentStatus.DEPRECATED);
        executor.execute(
            address(schemas),
            abi.encodeCall(
                schemas.setDocumentStatus, (id, IStreamSchemaRegistry.DocumentStatus.DEPRECATED)
            ),
            scope,
            oldHash,
            nextHash
        );
        vm.expectRevert();
        consumer.requireCurrent(_scope());
        require(rights.currentRights(1, subject).recordHash == rightsHash);
    }

    function testNoImplicitCollectionDescriptionInheritanceIntoTokenScope()
        public
        descriptionsReady
    {
        _pair();
        core.setToken(7, address(this), 2);
        vm.expectRevert();
        consumer.requireCurrent(StreamFinalityScope(StreamFinalityScopeType.TOKEN, 1, 7, 0));
    }

    function testMalformedScopeRejectedBeforeAnyReadinessClaim() public descriptionsReady {
        _pair();
        vm.expectRevert();
        consumer.requireCurrent(StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 7, 0));
    }

    function testMissingPredictedSelectorCannotServeUntilExactRuntimeIsDeployed()
        public
        descriptionsReady
    {
        _pair();
        bytes memory runtime = address(rights).code;
        evm.etch(address(rights), hex"");
        vm.expectRevert();
        consumer.requireCurrent(_scope());
        evm.etch(address(rights), runtime);
        require(consumer.requireCurrent(_scope()).rightsStatementRecordHash == rightsHash);
    }

    function testReciprocalSelectorBindingCannotNameAnotherMetadataHost() public descriptionsReady {
        _pair();
        workVm.mockCall(
            address(rights), abi.encodeCall(rights.metadata, ()), abi.encode(address(0x123))
        );
        vm.expectRevert();
        consumer.requireCurrent(_scope());
    }

    function testChainChangeCannotReuseOriginalSelectionEvidence() public descriptionsReady {
        _pair();
        evm.chainId(block.chainid + 1);
        vm.expectRevert();
        consumer.requireCurrent(_scope());
    }

    function testChangedValidatedReadbackCannotReplaceRawHead() public descriptionsReady {
        _pair();
        IStreamRightsRecordSelection.Selection memory r = rights.currentRights(1, subject);
        r.recorder = address(0xbad);
        workVm.mockCall(
            address(rights),
            abi.encodeCall(rights.requireCurrent, (1, subject, rightsHash, 1)),
            abi.encode(r)
        );
        vm.expectRevert();
        consumer.requireCurrent(_scope());
    }

    function testChangedOriginalReceiptCannotMatchSavedSelection() public descriptionsReady {
        _pair();
        IStreamCollectionMetadataV1.RecordReceipt memory r =
            metadata.collectionRecordReceipt(workHash);
        ++r.recordIndex;
        workVm.mockCall(
            address(metadata),
            abi.encodeCall(metadata.collectionRecordReceipt, (workHash)),
            abi.encode(r)
        );
        vm.expectRevert();
        consumer.requireCurrent(_scope());
    }

    function testExtraReturnBytesAreRejectedWithoutUnboundedCopy() public descriptionsReady {
        _pair();
        bytes memory r = abi.encode(rights.currentRights(1, subject));
        workVm.mockCall(
            address(rights),
            abi.encodeCall(rights.currentRights, (1, subject)),
            bytes.concat(r, abi.encode(uint256(1)))
        );
        vm.expectRevert();
        consumer.requireCurrent(_scope());
    }

    function testFuzzRetainedSelectionHashCannotBeReplaced(bytes32 replacement)
        public
        descriptionsReady
    {
        _pair();
        IStreamWorkRecordSelection.Selection memory w = selection.currentWork(1, subject);
        if (replacement == w.selectionHash) return;
        w.selectionHash = replacement;
        workVm.mockCall(
            address(selection), abi.encodeCall(selection.currentWork, (1, subject)), abi.encode(w)
        );
        vm.expectRevert();
        consumer.requireCurrent(_scope());
    }

    function testThresholdSafeConsumesBothActualSelectedRecords() public descriptionsReady {
        _pair();
        uint256[] memory keys = new uint256[](2);
        keys[0] = 701;
        keys[1] = 702;
        OfficialSafe safe =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 1201);
        bytes memory input = abi.encodeCall(consumer.requireCurrent, (_scope()));
        require(executeSafe(safe, keys, address(consumer), 0, input, 0));
        require(consumer.requireCurrent(_scope()).workDescriptionRecordHash == workHash);
    }

    function testNamedColdSourcesFitMeasuredConsumerEnvelope() public descriptionsReady {
        _pair();
        StreamFinalityDescriptionReads.Dependencies memory d = _dependencies();
        for (uint256 i; i < 6; ++i) {
            safeVm.cool(d.targets[i]);
        }
        safeVm.cool(address(facade));
        safeVm.cool(address(coordinator));
        safeVm.cool(address(identityOwner));
        safeVm.cool(address(bindingOwner));
        safeVm.cool(address(attributionOwner));
        safeVm.cool(address(consumer));
        bytes memory input = abi.encodeCall(consumer.requireCurrent, (_scope()));
        uint256 beforeGas = gasleft();
        (bool ok, bytes memory result) = address(consumer).staticcall{ gas: 8000000 }(input);
        uint256 used = beforeGas - gasleft();
        require(ok && result.length == 288, "named cold composition under explicit envelope");
        emit log_named_uint("named cold WORK/RIGHTS consumer gas", used);
    }

    function testActualSafeCanCallTheLinkedDescriptionRead() public descriptionsReady {
        _pair();
        uint256[] memory keys = new uint256[](2);
        keys[0] = 711;
        keys[1] = 712;
        OfficialSafe safe =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 1202);
        bytes memory input = abi.encodeWithSelector(
            StreamFinalityDescriptionReads.requireCurrent.selector, _dependencies(), _scope()
        );
        (bool ok, bytes memory output) = address(StreamFinalityDescriptionReads).staticcall(input);
        require(ok && keccak256(output) == keccak256(abi.encode(consumer.requireCurrent(_scope()))));
        require(executeSafe(safe, keys, address(StreamFinalityDescriptionReads), 0, input, 0));
    }

    function testExact8192ByteCatalogAndMaximumOriginalURIsFitActualConsumer() public {
        registrationURI = _filledURI(2048);
        _prepareDescriptions();
        StreamWorkRecordTypes.Description memory d = _named();
        d.full.format.kind = StreamWorkRecordTypes.FormatKind.CATALOG;
        d.full.format.formatId = bytes32(uint256(1));
        StreamWorkRecordTypes.Catalog memory catalog;
        catalog.name = "MAXIMUM_FINALITY_WORK_FORMAT_V1";
        catalog.selectedEntryId = bytes32(uint256(1));
        catalog.entries = new StreamWorkRecordTypes.CatalogEntry[](4);
        for (uint256 i; i < 4; ++i) {
            catalog.entries[i].entryId = bytes32(i + 1);
            catalog.entries[i].kind = StreamWorkRecordTypes.MappingKind.SPECIFICATION;
            catalog.entries[i].specification =
                StreamWorkRecordTypes.Specification("ipfs://a", bytes32(i + 1));
        }
        uint256 remaining = 8192 - StreamWorkFormatJson.catalogDocument(catalog).length;
        for (uint256 i; i < 4 && remaining != 0; ++i) {
            uint256 added = remaining > 2040 ? 2040 : remaining;
            catalog.entries[i].specification.uri = _filledURI(8 + added);
            remaining -= added;
        }
        bytes memory catalogBytes = StreamWorkFormatJson.catalogDocument(catalog);
        require(remaining == 0 && catalogBytes.length == 8192, "exact full catalog bytes");
        _registerDocument(
            catalog.name,
            IStreamSchemaRegistry.DocumentKind.CATALOG,
            catalogBytes,
            StreamWorkRecordDefinitions.CANON_ID
        );
        d.full.format.catalog = catalog;
        bytes memory payload = StreamWorkRecordJson.serialize(d);
        IStreamPreservationRecords.CollectionRecord memory original = _workRecord(payload);
        original.uri = registrationURI;
        workHash = metadata.recordCollectionRecordWithPayload(1, original, payload);
        originals[workHash] = original;
        selection.selectCurrent(1, subject, workHash, 0, 0, _witness(workHash, d));
        StreamRightsRecordTypes.Statement memory s = _rightsStatement(0);
        payload = StreamRightsRecordJson.serialize(s);
        original = _record(RIGHTS_TYPE, payload);
        original.uri = registrationURI;
        original.schemaId = StreamRightsRecordDefinitions.SCHEMA_ID;
        original.contentHash.canonicalizationId = StreamRightsRecordDefinitions.CANON_ID;
        rightsHash = metadata.recordCollectionRecordWithPayload(1, original, payload);
        rights.selectCurrentWithRecord(
            1, subject, rightsHash, 0, 0, IStreamRightsRecordWitnessSelection.Witness(original, s)
        );
        StreamFinalityDescriptionReads.Dependencies memory dependencies = _dependencies();
        for (uint256 i; i < 6; ++i) {
            safeVm.cool(dependencies.targets[i]);
        }
        safeVm.cool(address(facade));
        safeVm.cool(address(coordinator));
        safeVm.cool(address(identityOwner));
        safeVm.cool(address(bindingOwner));
        safeVm.cool(address(attributionOwner));
        uint256 beforeGas = gasleft();
        StreamFinalityDescriptionEvidence memory e = consumer.requireCurrent(_scope());
        uint256 used = beforeGas - gasleft();
        require(
            e.workDescriptionRecordHash == workHash && e.rightsStatementRecordHash == rightsHash
        );
        emit log_named_uint("maximum catalog and URI named cold consumer gas", used);
    }

    function _filledURI(uint256 length) private pure returns (string memory) {
        bytes memory value = new bytes(length);
        bytes memory prefix = bytes("ipfs://");
        for (uint256 i; i < length; ++i) {
            value[i] = i < prefix.length ? prefix[i] : bytes1("a");
        }
        return string(value);
    }

    function testAbsurdConfiguredGasUsesConfigurationErrorBeforeArithmeticOrDependencyCalls()
        public
        descriptionsReady
    {
        StreamFinalityDescriptionReads.Dependencies memory d = _dependencies();
        d.selectionGas = type(uint256).max;
        FinalityDescriptionConsumerBoundary invalid = new FinalityDescriptionConsumerBoundary(d);
        vm.expectRevert(
            abi.encodeWithSelector(StreamFinalityDescriptionReads.DescriptionConfiguration.selector)
        );
        invalid.requireCurrent(_scope());
    }
}
