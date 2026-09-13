// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../metadata/StreamConservationSelectionFixture.sol";
import "../../../smart-contracts/domains/finality/StreamFinalityConservationReads.sol";

interface FinalityConservationVm {
    function assume(bool condition) external;
}

contract FinalityConservationFixedBoundary {
    StreamFinalityConservationReads.Dependencies private dependencies;

    constructor(StreamFinalityConservationReads.Dependencies memory d) {
        dependencies = d;
    }

    function current(StreamFinalityScope memory scope)
        external
        view
        returns (StreamFinalityConservationEvidence memory)
    {
        return StreamFinalityConservationReads.requireCurrent(dependencies, scope);
    }

    function locked(StreamFinalityScope memory scope)
        external
        view
        returns (StreamFinalityConservationEvidence memory)
    {
        return StreamFinalityConservationReads.requireLocked(dependencies, scope);
    }
}

/// @dev Actual Metadata/Schema/Store/selector; explicit Core/Executor/artist response fixtures.
contract StreamFinalityConservationReadsTest is ConservationSelectionFixture {
    FinalityConservationFixedBoundary internal consumer;
    event log_named_uint(string name, uint256 value);

    modifier initialized() {
        _prepare();
        _bound();
        _consumer();
        _;
    }

    function _consumer() internal {
        consumer = new FinalityConservationFixedBoundary(_dependencies());
    }

    function _dependencies()
        internal
        view
        returns (StreamFinalityConservationReads.Dependencies memory d)
    {
        d.targets = [
            address(core), address(metadata), address(schemas), address(store), address(selection)
        ];
        for (uint256 i; i < 5; ++i) {
            d.codeHashes[i] = d.targets[i].codehash;
        }
        d.chainId = block.chainid;
        d.readGas = 500000;
        d.selectionGas = 3000000;
    }

    function _scope() internal pure returns (StreamFinalityScope memory) {
        return StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0);
    }

    function probe(
        StreamFinalityConservationReads.Dependencies memory d,
        StreamFinalityScope memory scope
    ) external view returns (StreamFinalityConservationEvidence memory) {
        return StreamFinalityConservationReads.requireCurrent(d, scope);
    }

    function _adopt(StreamConservationRecordTypes.Intent memory v)
        internal
        returns (IStreamConservationRecordSelection.Selection memory s)
    {
        (bytes32 hash,) = _publish(
            IStreamConservationRecordSelection.RecordKind.INTENT,
            StreamArtistIntentJson.serialize(v),
            1
        );
        IStreamConservationRecordSelection.Selection memory previous =
            selection.currentConservation(1, subject, v.artist.origin);
        s = selection.adoptIntent(
            1, subject, hash, previous.record.recordHash, previous.revision, _intentWitness(hash, v)
        );
    }

    function _present(uint8 authorityClass, uint16 algorithm)
        internal
        returns (IStreamConservationRecordSelection.Selection memory s)
    {
        StreamConservationRecordTypes.Intent memory v = _intent();
        IStreamConservationRecordSelection.InterviewWitness memory iw;
        (v, iw) = _withInterview(v, _interview(), authorityClass);
        v.interview.record.payload.algorithm = algorithm;
        if (algorithm == 2) {
            v.interview.record.payload.digest =
                abi.encodePacked(sha256(StreamArtistInterviewJson.serialize(iw.interview)));
        }
        if (algorithm == 4) {
            v.interview.record.payload.canonicalizationId = keccak256("RAW_BYTES");
            v.interview.record.payload.digest = hex"f0123456";
        }
        (bytes32 hash,) = _publish(
            IStreamConservationRecordSelection.RecordKind.INTENT,
            StreamArtistIntentJson.serialize(v),
            1
        );
        IStreamConservationRecordSelection.IntentWitness memory w = _intentWitness(hash, v);
        w.interview = iw;
        s = selection.adoptIntent(1, subject, hash, 0, 0, w);
    }

    function testOriginalIntentAndExplicitInterviewWaiverHaveNonzeroDistinctEvidence()
        public
        initialized
    {
        IStreamConservationRecordSelection.Selection memory s = _adopt(_intent());
        StreamFinalityConservationEvidence memory e = consumer.current(_scope());
        require(
            e.scopeSubject == subject && e.intentRecordHash == s.record.recordHash
                && e.intentWaiverRecordHash == 0,
            "exact intent union"
        );
        require(
            e.interviewEvidenceHash != 0 && !e.intentLock.locked,
            "waiver is explicit status, lock absent"
        );
        require(
            e.selected.interview.recordHash == 0 && e.selected.interviewArchiveReferenceHash == 0,
            "no invented interview or standalone waiver ref"
        );
        require(
            e.archiveRequirement
                == StreamConservationArchiveRequirement.DUAL_FAMILY_REFERENCES_AND_SIGNATURE_BUNDLES,
            "archive still required"
        );
        bytes32 literal = keccak256(
            abi.encode(
                keccak256("6529STREAM_FINALITY_WAIVED_INTERVIEW_V1"),
                block.chainid,
                _dependencies().targets,
                _scope(),
                subject,
                s,
                keccak256("STREAM_ARTIST_INTERVIEW_V1"),
                StreamConservationDefinitions.INTERVIEW_PROFILE_HASH
            )
        );
        require(
            e.interviewEvidenceHash == literal && abi.encode(e).length == 2048,
            "independent exact preimage and fixed64 words"
        );
    }

    function testIntentWaiverNeverManufacturesInterviewAbsence() public initialized {
        StreamConservationRecordTypes.IntentWaiver memory v = _waiver();
        (bytes32 hash,) = _publish(
            IStreamConservationRecordSelection.RecordKind.INTENT_WAIVER,
            StreamArtistIntentWaiverJson.serialize(v),
            1
        );
        selection.adoptWaiver(1, subject, hash, 0, 0, _waiverWitness(hash, v));
        StreamFinalityConservationEvidence memory e = consumer.current(_scope());
        require(
            e.intentRecordHash == 0 && e.intentWaiverRecordHash == hash
                && e.interviewEvidenceHash != 0,
            "two independent explicit waiver declarations"
        );
        require(
            e.selected.interviewStatus == StreamConservationRecordTypes.InterviewStatus.WAIVED,
            "explicit status"
        );
    }

    function testPresentInterviewActualKeccakPayloadAndSeparateOriginalAuthority()
        public
        initialized
    {
        IStreamConservationRecordSelection.Selection memory s = _present(3, 1);
        StreamFinalityConservationEvidence memory e = consumer.current(_scope());
        require(
            e.selected.record.publication.authorityClass == 1
                && e.selected.interview.publication.authorityClass == 3,
            "estate interview not relabeled original artist speech"
        );
        require(
            e.selected.interview.recorder == ESTATE && e.selected.record.recorder == ORIGINAL,
            "separate original authors"
        );
        require(
            e.selected.interviewPayloadCorrespondence
                == IStreamConservationRecordSelection.PayloadCorrespondence.EXACT_JCS_KECCAK256,
            "exact local correspondence"
        );
        require(
            e.interviewEvidenceHash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_FINALITY_PRESENT_INTERVIEW_V1"),
                        block.chainid,
                        _dependencies().targets,
                        _scope(),
                        subject,
                        s,
                        StreamConservationDefinitions.INTERVIEW_SCHEMA_ID,
                        StreamConservationDefinitions.INTERVIEW_PROFILE_HASH
                    )
                ),
            "present exact preimage"
        );
    }

    function testPresentSha256AndOpaqueReferenceNeverBecomeArchiveProof() public initialized {
        _present(1, 2);
        StreamFinalityConservationEvidence memory e = consumer.current(_scope());
        require(
            e.selected.interviewPayloadCorrespondence
                == IStreamConservationRecordSelection.PayloadCorrespondence.EXACT_JCS_SHA256,
            "actual sha256"
        );
        _prepare();
        _bound();
        _consumer();
        _present(1, 4);
        e = consumer.current(_scope());
        require(
            e.selected.interviewPayloadCorrespondence
                    == IStreamConservationRecordSelection.PayloadCorrespondence.UNVERIFIED_REFERENCE
                && e.selected.interviewArchiveReferenceHash != 0,
            "opaque remains full attributed commitment"
        );
        require(
            e.archiveRequirement
                == StreamConservationArchiveRequirement.DUAL_FAMILY_REFERENCES_AND_SIGNATURE_BUNDLES,
            "opaque needs archives"
        );
    }

    function testMissingHeadAndEstateOnlyNeverYieldZeroReferenceSuccess() public initialized {
        vm.expectRevert();
        consumer.current(_scope());
        StreamConservationRecordTypes.Intent memory v = _intent();
        v.artist.origin = StreamConservationRecordTypes.StatementOrigin.ESTATE_STATEMENT;
        (bytes32 hash,) = _publish(
            IStreamConservationRecordSelection.RecordKind.INTENT,
            StreamArtistIntentJson.serialize(v),
            3
        );
        selection.adoptIntent(1, subject, hash, 0, 0, _intentWitness(hash, v));
        vm.expectRevert();
        consumer.current(_scope());
    }

    function testLaterUnselectedOriginalCannotReplaceAuthoritativeHead() public initialized {
        IStreamConservationRecordSelection.Selection memory s = _adopt(_intent());
        StreamConservationRecordTypes.Intent memory v = _intent();
        v.predecessor = s.record.recordHash;
        (bytes32 next,) = _publish(
            IStreamConservationRecordSelection.RecordKind.INTENT,
            StreamArtistIntentJson.serialize(v),
            1
        );
        require(
            consumer.current(_scope()).intentRecordHash == s.record.recordHash,
            "author latest is not selected head"
        );
        selection.adoptIntent(1, subject, next, s.record.recordHash, 1, _intentWitness(next, v));
        StreamFinalityConservationEvidence memory e = consumer.current(_scope());
        require(e.intentRecordHash == next && e.selected.revision == 2, "actual supersession");
        require(
            selection.conservationSelectionAt(1, subject, v.artist.origin, 1).record.recordHash
                == s.record.recordHash,
            "retained original history"
        );
    }

    function testHistoricalOriginalSurvivesRotationSuccessionAndLateMaterialization()
        public
        initialized
    {
        IStreamConservationRecordSelection.Selection memory s = _adopt(_intent());
        StreamConservationRecordTypes.Intent memory v = _intent();
        v.predecessor = s.record.recordHash;
        (bytes32 hash,) = _publish(
            IStreamConservationRecordSelection.RecordKind.INTENT,
            StreamArtistIntentJson.serialize(v),
            1
        );
        identityOwner.setIdentity(ESTATE, 3, 3, IDENTITY);
        facade.setSigner(ESTATE);
        selection.adoptIntent(1, subject, hash, s.record.recordHash, 1, _intentWitness(hash, v));
        StreamFinalityConservationEvidence memory e = consumer.current(_scope());
        require(
            e.intentRecordHash == hash && e.selected.record.recorder == ORIGINAL
                && !e.intentLock.locked,
            "lifetime chain remains materializable"
        );
        vm.expectRevert();
        consumer.locked(_scope());
    }

    function testLockIsExactIndependentAndCurrentFactsRemainExplicit() public initialized {
        IStreamConservationRecordSelection.Selection memory s = _adopt(_intent());
        vm.expectRevert();
        consumer.locked(_scope());
        vm.prank(ORIGINAL);
        selection.lockArtistIntent(1, subject, s.record.recordHash, 1);
        StreamFinalityConservationEvidence memory e = consumer.locked(_scope());
        require(
            e.intentLock.locked && e.intentLock.recordHash == s.record.recordHash
                && e.intentLock.locker == ORIGINAL,
            "exact reference lock"
        );
        identityOwner.setIdentity(ESTATE, 3, 3, IDENTITY);
        require(
            consumer.locked(_scope()).selected.record.recorder == ORIGINAL,
            "historical lock never freezes operative keys"
        );
    }

    function testRetiredDefinitionBlocksCurrentButPreservesSavedEvidence() public initialized {
        IStreamConservationRecordSelection.Selection memory s = _adopt(_intent());
        StreamFinalityConservationEvidence memory e = consumer.current(_scope());
        bytes32 id = StreamConservationDefinitions.INTENT_PROFILE_ID;
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
        vm.expectRevert();
        consumer.current(_scope());
        require(
            e.intentRecordHash == s.record.recordHash
                && selection.currentConservation(1, subject, e.selected.origin).record.recordHash
                    == s.record.recordHash,
            "old evidence is not erased"
        );
    }

    function testChangedAssociationBlocksCurrentEvenWithOriginalLock() public initialized {
        IStreamConservationRecordSelection.Selection memory s = _adopt(_intent());
        vm.prank(ORIGINAL);
        selection.lockArtistIntent(1, subject, s.record.recordHash, 1);
        T.Binding memory b = T.Binding(
            ARTIST_ID, ORIGINAL, IDENTITY, keccak256("replacement"), 2, 1, 0, 0, address(this), true
        );
        bindingOwner.setBinding(b, 2);
        attributionOwner.setBinding(b, 2);
        vm.expectRevert();
        consumer.current(_scope());
    }

    function testExactScopeNoTokenInheritanceAndInvalidShape() public initialized {
        _adopt(_intent());
        StreamFinalityScope memory scope =
            StreamFinalityScope(StreamFinalityScopeType.TOKEN, 1, 77, 0);
        vm.expectRevert();
        consumer.current(scope);
        scope = _scope();
        scope.tokenId = 77;
        vm.expectRevert();
        consumer.current(scope);
        scope = _scope();
        scope.collectionId = 0;
        vm.expectRevert();
        consumer.current(scope);
    }

    function testCodePinsAndReciprocalBindingsRejectSubstitutionThenRestore() public initialized {
        _adopt(_intent());
        bytes memory code = address(store).code;
        vm.etch(address(store), hex"00");
        vm.expectRevert();
        consumer.current(_scope());
        vm.etch(address(store), code);
        require(consumer.current(_scope()).intentRecordHash != 0, "same evidence after restore");
        cvm.mockCall(
            address(selection), abi.encodeCall(selection.core, ()), abi.encode(address(0x1234))
        );
        vm.expectRevert();
        consumer.current(_scope());
        cvm.clearMockedCalls();
        cvm.mockCall(
            address(selection),
            abi.encodeCall(
                selection.supportsInterface, (type(IStreamConservationRecordSelection).interfaceId)
            ),
            abi.encode(uint256(2))
        );
        vm.expectRevert();
        consumer.current(_scope());
    }

    function testChangedChainAndGasConfigurationFailClosed() public initialized {
        _adopt(_intent());
        StreamFinalityConservationReads.Dependencies memory d = _dependencies();
        d.chainId += 1;
        vm.expectRevert();
        this.probe(d, _scope());
        d = _dependencies();
        d.readGas = 0;
        vm.expectRevert();
        this.probe(d, _scope());
        d = _dependencies();
        d.selectionGas = d.readGas - 1;
        vm.expectRevert();
        this.probe(d, _scope());
        d = _dependencies();
        d.selectionGas = type(uint256).max;
        vm.expectRevert();
        this.probe(d, _scope());
    }

    function testMalformedOrChangedValidatingReadbackAndTrailingBytesReject() public initialized {
        IStreamConservationRecordSelection.Selection memory s = _adopt(_intent());
        bytes memory input = abi.encodeCall(
            selection.requireCurrent, (1, subject, s.origin, s.record.recordHash, uint64(1))
        );
        cvm.mockCall(address(selection), input, abi.encodePacked(abi.encode(s), bytes32(0)));
        vm.expectRevert();
        consumer.current(_scope());
        cvm.clearMockedCalls();
        s.submitter = address(0x123);
        cvm.mockCall(address(selection), input, abi.encode(s));
        vm.expectRevert();
        consumer.current(_scope());
        cvm.clearMockedCalls();
        cvm.mockCall(address(selection), _rawSelector(), new bytes(1599));
        vm.expectRevert();
        consumer.current(_scope());
    }

    function testOriginalReceiptLaneAndConsumedBacklinkMutationsReject() public initialized {
        IStreamConservationRecordSelection.Selection memory s = _adopt(_intent());
        IStreamCollectionMetadataV1.RecordReceipt memory r =
            metadata.collectionRecordReceipt(s.record.recordHash);
        r.recorder = address(0x999);
        cvm.mockCall(
            address(metadata),
            abi.encodeCall(metadata.collectionRecordReceipt, (s.record.recordHash)),
            abi.encode(r)
        );
        vm.expectRevert();
        consumer.current(_scope());
        cvm.clearMockedCalls();
        cvm.mockCall(
            address(metadata),
            abi.encodeCall(metadata.recordHashAt, (1, INTENT, uint256(s.record.recordIndex))),
            abi.encode(bytes32(uint256(7)))
        );
        vm.expectRevert();
        consumer.current(_scope());
        cvm.clearMockedCalls();
        cvm.mockCall(
            address(metadata),
            abi.encodeWithSignature(
                "consumedArtistAuthorization(bytes32)", s.record.publication.attestationRecordHash
            ),
            abi.encode(false)
        );
        vm.expectRevert();
        consumer.current(_scope());
    }

    function testRehashedWrongOriginOrClassCannotMasqueradeAsArtist() public initialized {
        IStreamConservationRecordSelection.Selection memory s = _adopt(_intent());
        s.origin = StreamConservationRecordTypes.StatementOrigin.ESTATE_STATEMENT;
        _mockSelection(s);
        vm.expectRevert();
        consumer.current(_scope());
        cvm.clearMockedCalls();
        s = selection.currentConservation(
            1, subject, StreamConservationRecordTypes.StatementOrigin.ARTIST_INTENT
        );
        s.record.publication.authorityClass = 3;
        _mockSelection(s);
        vm.expectRevert();
        consumer.current(_scope());
    }

    function testWaivedInactiveInterviewAndReferenceFieldsRejectEvenRehashed() public initialized {
        IStreamConservationRecordSelection.Selection memory original = _adopt(_intent());
        IStreamConservationRecordSelection.Selection memory s = original;
        s.interviewArchiveReferenceHash = bytes32(uint256(1));
        _mockSelection(s);
        vm.expectRevert();
        consumer.current(_scope());
        cvm.clearMockedCalls();
        s = selection.currentConservation(1, subject, original.origin);
        s.interview.publication.signer = ORIGINAL;
        _mockSelection(s);
        vm.expectRevert();
        consumer.current(_scope());
        cvm.clearMockedCalls();
        s = selection.currentConservation(1, subject, original.origin);
        s.interviewPayloadCorrespondence =
        IStreamConservationRecordSelection.PayloadCorrespondence.EXACT_JCS_SHA256;
        _mockSelection(s);
        vm.expectRevert();
        consumer.current(_scope());
    }

    function testFalseLockDirtyFieldsAndWrongHeadReject() public initialized {
        IStreamConservationRecordSelection.Selection memory s = _adopt(_intent());
        IStreamConservationRecordSelection.IntentLock memory locked;
        locked.locker = ORIGINAL;
        cvm.mockCall(
            address(selection),
            abi.encodeCall(selection.intentLock, (1, subject)),
            abi.encode(locked)
        );
        vm.expectRevert();
        consumer.current(_scope());
        cvm.clearMockedCalls();
        vm.prank(ORIGINAL);
        selection.lockArtistIntent(1, subject, s.record.recordHash, 1);
        locked = selection.intentLock(1, subject);
        locked.recordHash = bytes32(uint256(99));
        cvm.mockCall(
            address(selection),
            abi.encodeCall(selection.intentLock, (1, subject)),
            abi.encode(locked)
        );
        vm.expectRevert();
        consumer.current(_scope());
    }

    function testFuzzSelectionCommitmentCannotMutate(bytes32 altered) public initialized {
        IStreamConservationRecordSelection.Selection memory s = _adopt(_intent());
        FinalityConservationVm(address(vm)).assume(altered != s.selectionHash);
        s.selectionHash = altered;
        cvm.mockCall(address(selection), _rawSelector(), abi.encode(s));
        vm.expectRevert();
        consumer.current(_scope());
    }

    function testFuzzCanonicalReceiptWidthAndTrailingReturnReject(uint256 high) public initialized {
        FinalityConservationVm(address(vm)).assume(high > type(uint64).max);
        IStreamConservationRecordSelection.Selection memory s = _adopt(_intent());
        IStreamCollectionMetadataV1.RecordReceipt memory r =
            metadata.collectionRecordReceipt(s.record.recordHash);
        bytes memory raw = abi.encode(r);
        assembly ("memory-safe") { mstore(add(raw, 128), high) }
        cvm.mockCall(
            address(metadata),
            abi.encodeCall(metadata.collectionRecordReceipt, (s.record.recordHash)),
            raw
        );
        vm.expectRevert();
        consumer.current(_scope());
        cvm.clearMockedCalls();
        cvm.mockCall(
            address(metadata),
            abi.encodeCall(metadata.collectionRecordReceipt, (s.record.recordHash)),
            abi.encodePacked(abi.encode(r), bytes32(0))
        );
        vm.expectRevert();
        consumer.current(_scope());
    }

    function testActualThresholdSafeReadAndLockPreserveOriginalAuthor() public initialized {
        IStreamConservationRecordSelection.Selection memory s = _adopt(_intent());
        uint256[] memory keys = new uint256[](2);
        keys[0] = 9391;
        keys[1] = 9392;
        OfficialSafe safe =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 1939);
        StreamFinalityConservationEvidence memory before_ = consumer.current(_scope());
        require(
            executeSafe(
                safe, keys, address(consumer), 0, abi.encodeCall(consumer.current, (_scope())), 0
            ),
            "actual threshold Safe current CALL"
        );
        identityOwner.setIdentity(address(safe), 1, 1, IDENTITY);
        facade.setSigner(address(safe));
        require(
            executeSafe(
                safe,
                keys,
                address(selection),
                0,
                abi.encodeCall(
                    selection.lockArtistIntent, (1, subject, s.record.recordHash, uint64(1))
                ),
                0
            ),
            "actual current Safe lock"
        );
        require(
            executeSafe(
                safe, keys, address(consumer), 0, abi.encodeCall(consumer.locked, (_scope())), 0
            ),
            "actual Safe locked CALL"
        );
        StreamFinalityConservationEvidence memory after_ = consumer.locked(_scope());
        require(
            after_.intentLock.locker == address(safe) && after_.selected.record.recorder == ORIGINAL
                && after_.interviewEvidenceHash == before_.interviewEvidenceHash,
            "lock and current signer don't rewrite original status evidence"
        );
    }

    function testLowParentGasFailsThenHealthyExactReadSucceeds() public initialized {
        _adopt(_intent());
        bytes memory data = abi.encodeCall(consumer.current, (_scope()));
        (bool ok,) = address(consumer).staticcall{ gas: 250000 }(data);
        require(!ok, "parent cap rejected");
        StreamFinalityConservationEvidence memory e = consumer.current(_scope());
        require(e.intentRecordHash != 0, "same original healthy");
    }

    function testColdMaximumRegistrationAndRecordURIReadFitsBoundedConsumer() public {
        registrationURI = _uri(2048);
        recordURI = _uri(2048);
        _prepare();
        _bound();
        _consumer();
        _present(1, 1);
        bytes memory data = abi.encodeCall(consumer.current, (_scope()));
        _cool();
        uint256 start = gasleft();
        (bool ok, bytes memory raw) = address(consumer).staticcall{ gas: 6000000 }(data);
        emit log_named_uint(
            "max registration/record URI current consumer named-cold callee6M", start - gasleft()
        );
        require(
            ok
                && abi.decode(raw, (StreamFinalityConservationEvidence)).selected.interview
                        .recordHash != 0,
            "exact bounded original facts"
        );
    }

    function testIntentWaiverCanCommitActualPresentInterviewIndependently() public initialized {
        (
            StreamConservationRecordTypes.Intent memory intent,
            IStreamConservationRecordSelection.InterviewWitness memory iw
        ) = _withInterview(_intent(), _interview(), 1);
        StreamConservationRecordTypes.IntentWaiver memory v = _waiver();
        v.interview = intent.interview;
        (bytes32 hash,) = _publish(
            IStreamConservationRecordSelection.RecordKind.INTENT_WAIVER,
            StreamArtistIntentWaiverJson.serialize(v),
            1
        );
        IStreamConservationRecordSelection.WaiverWitness memory w = _waiverWitness(hash, v);
        w.interview = iw;
        selection.adoptWaiver(1, subject, hash, 0, 0, w);
        StreamFinalityConservationEvidence memory e = consumer.current(_scope());
        require(
            e.intentRecordHash == 0 && e.intentWaiverRecordHash == hash
                && e.selected.interviewStatus
                    == StreamConservationRecordTypes.InterviewStatus.PRESENT,
            "waiver plus actual present interview"
        );
        require(
            e.selected.interview.recordHash == intent.interview.record.recordHash
                && e.interviewEvidenceHash != 0,
            "exact original locator"
        );
    }

    function testStaleRawHeadCannotPassActualCurrentSelectionRead() public initialized {
        IStreamConservationRecordSelection.Selection memory old = _adopt(_intent());
        StreamConservationRecordTypes.Intent memory v = _intent();
        v.predecessor = old.record.recordHash;
        _adopt(v);
        cvm.mockCall(address(selection), _rawSelector(), abi.encode(old));
        vm.expectRevert();
        consumer.current(_scope());
        cvm.clearMockedCalls();
        require(consumer.current(_scope()).selected.revision == 2, "healthy actual current head");
    }

    function testActualInterviewReceiptAndAssociationCannotBeSubstituted() public initialized {
        IStreamConservationRecordSelection.Selection memory s = _present(1, 1);
        IStreamCollectionMetadataV1.RecordReceipt memory receipt =
            metadata.collectionRecordReceipt(s.interview.recordHash);
        receipt.schemaDefinitionHash = StreamConservationDefinitions.INTENT_SCHEMA_HASH;
        cvm.mockCall(
            address(metadata),
            abi.encodeCall(metadata.collectionRecordReceipt, (s.interview.recordHash)),
            abi.encode(receipt)
        );
        vm.expectRevert();
        consumer.current(_scope());
        cvm.clearMockedCalls();
        s.interview.publication.bindingHash = keccak256("foreign interview association");
        _mockSelection(s);
        vm.expectRevert();
        consumer.current(_scope());
    }

    function testSelectedCompleteFormatCatalogRetirementBlocksCurrentConsumer() public initialized {
        StreamConservationRecordTypes.Interview memory interview = _interview();
        StreamConservationRecordTypes.Format memory format;
        format.kind = StreamConservationRecordTypes.FormatKind.CATALOG;
        format.formatId = bytes32(uint256(99));
        format.catalog.selectedEntryId = format.formatId;
        format.catalog.name = "FINALITY_CONSERVATION_FORMATS_V1";
        format.catalog.entries = new StreamConservationRecordTypes.CatalogEntry[](2);
        format.catalog.entries[0].entryId = bytes32(uint256(98));
        format.catalog.entries[0].puid = "fmt/199";
        format.catalog.entries[1].entryId = format.formatId;
        format.catalog.entries[1].puid = "fmt/111";
        interview.transcript.format = format;
        bytes32 id = _registerDocument(
            format.catalog.name,
            IStreamSchemaRegistry.DocumentKind.CATALOG,
            StreamConservationFormatJson.catalogDocument(format.catalog),
            StreamWorkRecordDefinitions.CANON_ID
        );
        (
            StreamConservationRecordTypes.Intent memory v,
            IStreamConservationRecordSelection.InterviewWitness memory iw
        ) = _withInterview(_intent(), interview, 1);
        selection.prepareInterview(1, subject, v.interview.record.recordHash, iw);
        (bytes32 hash,) = _publish(
            IStreamConservationRecordSelection.RecordKind.INTENT,
            StreamArtistIntentJson.serialize(v),
            1
        );
        selection.adoptIntentWithPreparedInterview(1, subject, hash, 0, 0, _intentWitness(hash, v));
        StreamFinalityConservationEvidence memory e = consumer.current(_scope());
        IStreamConservationRecordSelection.CatalogPin[] memory pins =
            new IStreamConservationRecordSelection.CatalogPin[](1);
        pins[0] = IStreamConservationRecordSelection.CatalogPin(
            id,
            keccak256(StreamConservationFormatJson.catalogDocument(format.catalog)),
            StreamConservationFormatJson.catalogDocument(format.catalog).length
        );
        require(
            e.selected.catalogsHash == keccak256(abi.encode(pins)), "complete exact catalog pins"
        );
        (bytes32 sc, bytes32 old, bytes32 next) =
            schemas.statusTransition(id, IStreamSchemaRegistry.DocumentStatus.DEPRECATED);
        executor.execute(
            address(schemas),
            abi.encodeCall(
                schemas.setDocumentStatus, (id, IStreamSchemaRegistry.DocumentStatus.DEPRECATED)
            ),
            sc,
            old,
            next
        );
        vm.expectRevert();
        consumer.current(_scope());
        require(
            selection.preparedInterview(v.interview.record.recordHash).preparationHash != 0,
            "original preparation remains historical"
        );
    }

    function _rawSelector() internal view returns (bytes memory) {
        return abi.encodeCall(
            selection.currentConservation,
            (1, subject, StreamConservationRecordTypes.StatementOrigin.ARTIST_INTENT)
        );
    }

    function _mockSelection(IStreamConservationRecordSelection.Selection memory s) internal {
        s.selectionHash = 0;
        s.selectionHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_CONSERVATION_SELECTION_V1"),
                block.chainid,
                address(selection),
                address(core),
                address(metadata),
                address(schemas),
                address(store),
                uint256(1),
                subject,
                s
            )
        );
        cvm.mockCall(address(selection), _rawSelector(), abi.encode(s));
        cvm.mockCall(
            address(selection),
            abi.encodeCall(
                selection.requireCurrent,
                (
                    1,
                    subject,
                    StreamConservationRecordTypes.StatementOrigin.ARTIST_INTENT,
                    s.record.recordHash,
                    s.revision
                )
            ),
            abi.encode(s)
        );
    }

    function _cool() internal {
        safeVm.cool(address(consumer));
        safeVm.cool(address(core));
        safeVm.cool(address(metadata));
        safeVm.cool(address(schemas));
        safeVm.cool(address(store));
        safeVm.cool(address(selection));
        safeVm.cool(address(facade));
        safeVm.cool(address(coordinator));
        safeVm.cool(address(identityOwner));
        safeVm.cool(address(bindingOwner));
        safeVm.cool(address(attributionOwner));
        safeVm.cool(address(StreamFinalityConservationReads));
        safeVm.cool(address(StreamConservationRecordContext));
        safeVm.cool(address(StreamConservationRecordReads));
        safeVm.cool(address(StreamRecordArtistIdentityReads));
    }

    function _uri(uint256 length) internal pure returns (string memory) {
        bytes memory raw = new bytes(length);
        bytes memory prefix = bytes("ipfs://");
        for (uint256 i; i < length; ++i) {
            raw[i] = i < 7 ? prefix[i] : bytes1("a");
        }
        return string(raw);
    }
}
