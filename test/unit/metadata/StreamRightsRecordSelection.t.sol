// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamCollectionMetadataV1.t.sol";
import "../../../smart-contracts/domains/metadata/StreamRightsRecordSelection.sol";
import "./StreamRecordArtistIdentityReads.t.sol";

interface RightsSelectionFileVm {
    struct Log {
        bytes32[] topics;
        bytes data;
        address emitter;
    }

    function readFileBinary(string calldata path) external view returns (bytes memory);
    function recordLogs() external;
    function getRecordedLogs() external returns (Log[] memory);
}

/// @notice Actual metadata, multi-chunk definitions, rights selection and threshold Safe.
/// @dev Core membership/execution remain explicit fixture boundaries; no full Finality claim.
contract StreamRightsRecordSelectionTest is CollectionMetadataV1Fixture {
    StreamRightsRecordSelection private selection;
    RecordArtistReadFixture private rightsArtistFacade;
    RecordArtistReadFixture private rightsArtistCoordinator;
    RecordArtistReadFixture private rightsArtistIdentity;
    bytes32 private constant RIGHTS_TYPE = keccak256("RIGHTS_STATEMENT");

    function _prepare() private {
        _register(
            "RFC8785_JCS",
            IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
            RightsSelectionFileVm(address(vm))
                .readFileBinary("schemas/museum/account-profile/RFC8785_JCS.json")
        );
        _register(
            "STREAM_RIGHTS_JSON_PROFILE_V1",
            IStreamSchemaRegistry.DocumentKind.CATALOG,
            RightsSelectionFileVm(address(vm))
                .readFileBinary("schemas/records/STREAM_RIGHTS_JSON_PROFILE_V1.json")
        );
        bytes memory payload = RightsSelectionFileVm(address(vm))
            .readFileBinary("schemas/records/STREAM_RIGHTS_V1.json");
        bytes32[] memory chunks = new bytes32[]((payload.length + 8191) / 8192);
        for (uint256 i; i < chunks.length; ++i) {
            uint256 length = payload.length - i * 8192;
            if (length > 8192) length = 8192;
            bytes memory chunk = new bytes(length);
            for (uint256 j; j < length; ++j) {
                chunk[j] = payload[i * 8192 + j];
            }
            (chunks[i],) = store.publishChunk(chunk);
        }
        IStreamSchemaRegistry.DocumentSpec memory spec = IStreamSchemaRegistry.DocumentSpec(
            "STREAM_RIGHTS_V1",
            IStreamSchemaRegistry.DocumentKind.SCHEMA,
            keccak256(payload),
            schemas.RAW_BYTES(),
            0,
            "",
            uint32(payload.length)
        );
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            schemas.registrationTransition(spec, chunks);
        executor.execute(
            address(schemas),
            abi.encodeCall(schemas.registerDocument, (spec, chunks)),
            scope,
            oldHash,
            newHash
        );
        _configureArtistGraph();
        _admit(RIGHTS_TYPE, StreamRecordFamilies.RIGHTS, 0x0180);
        _grant(1, StreamRecordFamilies.RIGHTS, 7, address(this), true);
        selection =
            new StreamRightsRecordSelection(address(core), address(metadata), address(schemas));
    }

    function _configureArtistGraph() private {
        rightsArtistFacade = new RecordArtistReadFixture();
        rightsArtistCoordinator = new RecordArtistReadFixture();
        rightsArtistIdentity = new RecordArtistReadFixture();
        rightsArtistFacade.set(bytes4(keccak256("core()")), abi.encode(address(core)));
        rightsArtistFacade.set(
            bytes4(keccak256("operationCoordinator()")),
            abi.encode(address(rightsArtistCoordinator))
        );
        rightsArtistCoordinator.set(
            bytes4(keccak256("deploymentChainId()")), abi.encode(block.chainid)
        );
        uint256[17] memory words;
        words[0] = uint160(address(rightsArtistFacade));
        words[4] = uint160(address(rightsArtistIdentity));
        words[9] = uint160(address(core));
        rightsArtistCoordinator.set(bytes4(keccak256("suiteConfiguration()")), abi.encode(words));
        rightsArtistIdentity.set(bytes4(keccak256("core()")), abi.encode(address(core)));
        rightsArtistIdentity.set(
            bytes4(keccak256("artistRegistry()")), abi.encode(address(rightsArtistFacade))
        );
        rightsArtistIdentity.set(
            bytes4(keccak256("operationCoordinator()")),
            abi.encode(address(rightsArtistCoordinator))
        );
        rightsArtistIdentity.set(
            bytes4(keccak256("deploymentChainId()")), abi.encode(block.chainid)
        );
        rightsArtistIdentity.set(
            bytes4(keccak256("authorityState(bytes32)")),
            abi.encode(address(0), uint8(0), uint8(0), bytes32(uint256(77)))
        );
        StreamCollectionMetadataV1.Configuration memory c;
        c.core = address(core);
        c.executor = address(executor);
        c.schemas = address(schemas);
        c.artistRegistry = address(rightsArtistFacade);
        c.deploymentManifestHash = bytes32(uint256(1));
        c.manifestHash = bytes32(uint256(2));
        c.manifestURI = "ipfs://metadata-module";
        c.dependencyReadGas = IStreamGasParameterHost.GasParameterConfig(
            "METADATA_DEPENDENCY_READ_GAS", 150000, 100000, 2
        );
        c.artistReadGas = IStreamGasParameterHost.GasParameterConfig(
            "METADATA_ARTIST_READ_GAS", 2000000, 1000000, 2
        );
        metadata = new StreamCollectionMetadataV1(c);
        core.setPointer(keccak256("COLLECTION_METADATA"), address(metadata));
        core.setPointer(keccak256("ARTIST_REGISTRY"), address(rightsArtistFacade));
    }

    function _statement() private view returns (StreamRightsRecordTypes.Statement memory s) {
        s.subjectId = subject;
        s.profileHash = StreamRightsRecordDefinitions.PROFILE_HASH;
        s.licensor.kind = StreamRightsRecordTypes.LicensorKind.ACCOUNT;
        s.licensor.account = address(0x123);
        s.startDate = 20260912;
        s.openEnd = true;
    }

    function _published(StreamRightsRecordTypes.Statement memory s) private returns (bytes32) {
        bytes memory payload = StreamRightsRecordJson.serialize(s);
        IStreamPreservationRecords.CollectionRecord memory record = _record(RIGHTS_TYPE, payload);
        record.subjectId = s.subjectId;
        record.schemaId = StreamRightsRecordDefinitions.SCHEMA_ID;
        record.contentHash.canonicalizationId = StreamRightsRecordDefinitions.CANON_ID;
        return metadata.recordCollectionRecordWithPayload(1, record, payload);
    }

    function _select(
        bytes32 hash,
        StreamRightsRecordTypes.Statement memory s,
        bytes32 oldHead,
        uint64 revision
    ) private returns (IStreamRightsRecordSelection.Selection memory) {
        return selection.selectCurrent(1, s.subjectId, hash, oldHead, revision, s);
    }

    function testActualTwoChunkSchemaExplicitUnspecifiedAndSelectedHistory() public {
        _prepare();
        StreamRightsRecordTypes.Statement memory s = _statement();
        bytes32 hash = _published(s);
        RightsSelectionFileVm(address(vm)).recordLogs();
        IStreamRightsRecordSelection.Selection memory selected = _select(hash, s, 0, 0);
        _assertSelectionEvent(hash, selected);
        require(
            schemas.document(StreamRightsRecordDefinitions.SCHEMA_ID).chunkHashes.length == 2,
            "whole schema"
        );
        require(
            selected.recordHash == hash && selected.revision == 1 && selected.recordIndex == 0,
            "first selected record"
        );
        require(
            selected.selector == address(this) && selected.authorizationClass == 7
                && selected.grantScope == 1 && selected.grantRevision == 1,
            "saved exact selector grant"
        );
        require(
            selection.requireCurrent(1, subject, hash, 1).payloadHash
                == keccak256(StreamRightsRecordJson.serialize(s)),
            "actual bytes"
        );
        require(selection.rightsSelectionAt(1, subject, 1).recordHash == hash, "history");
    }

    function _assertSelectionEvent(
        bytes32 hash,
        IStreamRightsRecordSelection.Selection memory selected
    ) private {
        RightsSelectionFileVm.Log[] memory logs =
            RightsSelectionFileVm(address(vm)).getRecordedLogs();
        require(logs.length == 1 && logs[0].emitter == address(selection), "selection event host");
        require(
            logs[0].topics.length == 4
                && logs[0].topics[0]
                    == keccak256(
                        "RightsRecordSelected(uint256,bytes32,bytes32,(bytes32,bytes32,bytes32,address,uint256,uint64,uint64,uint64,uint64,uint8,address,uint8,bytes32,bytes32))"
                    ) && logs[0].topics[1] == bytes32(uint256(1)) && logs[0].topics[2] == subject
                && logs[0].topics[3] == hash,
            "selection event identity"
        );
        require(
            keccak256(logs[0].data) == keccak256(abi.encode(selected)), "complete event receipt"
        );
    }

    function testKnownArtistReferencePreservesRegistrationWithoutCurrentAuthorityGate() public {
        _prepare();
        StreamRightsRecordTypes.Statement memory s = _statement();
        s.licensor.kind = StreamRightsRecordTypes.LicensorKind.ARTIST;
        s.licensor.account = address(0);
        s.licensor.artistId = bytes32(uint256(33));
        bytes32 hash = _published(s);
        IStreamRightsRecordSelection.Selection memory selected = _select(hash, s, 0, 0);
        require(
            selected.artistIdentityRecordHash == bytes32(uint256(77)),
            "known registration despite zero current authority"
        );
        require(
            selected.recorder == address(this) && selected.recorderAuthorizationClass == 7,
            "original receipt distinct from selector"
        );
        rightsArtistIdentity.set(
            bytes4(keccak256("authorityState(bytes32)")),
            abi.encode(address(0xBEEF), uint8(255), uint8(255), bytes32(uint256(77)))
        );
        require(
            selection.requireCurrent(1, subject, hash, 1).artistIdentityRecordHash
                == bytes32(uint256(77)),
            "mutable authority does not rewrite saved rights reference"
        );
    }

    function testUnknownArtistRejectsWithoutSelectingAndExactRecordCanRetry() public {
        _prepare();
        StreamRightsRecordTypes.Statement memory s = _statement();
        s.licensor.kind = StreamRightsRecordTypes.LicensorKind.ARTIST;
        s.licensor.account = address(0);
        s.licensor.artistId = bytes32(uint256(33));
        bytes32 hash = _published(s);
        rightsArtistIdentity.set(
            bytes4(keccak256("authorityState(bytes32)")),
            abi.encode(address(0), uint8(0), uint8(0), bytes32(0))
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamRecordArtistIdentityReads.UnknownRecordArtist.selector, s.licensor.artistId
            )
        );
        _select(hash, s, 0, 0);
        require(selection.currentRights(1, subject).revision == 0, "no partially selected artist");
        rightsArtistIdentity.set(
            bytes4(keccak256("authorityState(bytes32)")),
            abi.encode(address(0), uint8(0), uint8(0), bytes32(uint256(77)))
        );
        require(
            _select(hash, s, 0, 0).artistIdentityRecordHash == bytes32(uint256(77)),
            "same record and revision retry"
        );
    }

    function testChangedArtistRuntimeFailsBeforeReadsAndRestoredGraphRetries() public {
        _prepare();
        StreamRightsRecordTypes.Statement memory s = _statement();
        bytes32 hash = _published(s);
        bytes memory original = address(rightsArtistIdentity).code;
        RecordArtistVm(address(vm)).etch(address(rightsArtistIdentity), hex"60006000fd");
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRightsRecordSelection.RightsDependencyChanged.selector,
                address(rightsArtistIdentity)
            )
        );
        _select(hash, s, 0, 0);
        RecordArtistVm(address(vm)).etch(address(rightsArtistIdentity), original);
        _select(hash, s, 0, 0);
    }

    function testLowParentGasRejectsWithoutStateThenSameCapHealthyRetry() public {
        _prepare();
        StreamRightsRecordTypes.Statement memory s = _statement();
        bytes32 hash = _published(s);
        bytes memory input =
            abi.encodeCall(selection.selectCurrent, (1, subject, hash, bytes32(0), uint64(0), s));
        (bool ok, bytes memory reason) = address(selection).call{ gas: 100000 }(input);
        require(
            !ok && reason.length >= 4
                && bytes4(reason)
                    == IStreamRightsRecordSelection.RightsDependencyReadFailed.selector,
            "explicit parent budget admission"
        );
        require(selection.currentRights(1, subject).revision == 0, "low-gas attempt left no state");
        _select(hash, s, 0, 0);
        require(
            metadata.gasParameter(metadata.DEPENDENCY_READ_GAS()) == 150000,
            "governed child cap unchanged"
        );
    }

    function testSelectedCommitmentUsesIndependentLiteralWordsAndScope() public {
        _prepare();
        StreamRightsRecordTypes.Statement memory s = _statement();
        bytes32 hash = _published(s);
        IStreamRightsRecordSelection.Selection memory selected = _select(hash, s, 0, 0);
        bytes32[23] memory words;
        words[0] = keccak256("6529STREAM_RIGHTS_SELECTION_V1");
        words[1] = bytes32(block.chainid);
        words[2] = bytes32(uint256(uint160(address(selection))));
        words[3] = bytes32(uint256(uint160(address(core))));
        words[4] = bytes32(uint256(uint160(address(metadata))));
        words[5] = bytes32(uint256(uint160(address(schemas))));
        words[6] = bytes32(uint256(uint160(address(store))));
        words[7] = bytes32(uint256(1));
        words[8] = subject;
        words[9] = hash;
        words[11] = keccak256(StreamRightsRecordJson.serialize(s));
        words[12] = bytes32(uint256(uint160(address(this))));
        words[13] = bytes32(uint256(1));
        words[14] = bytes32(uint256(1));
        words[15] = bytes32(uint256(1));
        words[17] = bytes32(block.timestamp);
        words[18] = bytes32(uint256(7));
        words[19] = bytes32(uint256(uint160(address(this))));
        words[20] = bytes32(uint256(7));
        require(
            selected.selectionHash == keccak256(abi.encode(words)), "literal full selected preimage"
        );
        require(
            selection.rightsSelectionAt(1, subject, 1).selectionHash == selected.selectionHash,
            "same historical commitment"
        );
    }

    function testTimestampOverflowLeavesNoSelectionAndSameRecordRetries() public {
        _prepare();
        StreamRightsRecordTypes.Statement memory s = _statement();
        bytes32 hash = _published(s);
        vm.warp(uint256(type(uint64).max) + 1);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamRightsRecordSelection.RightsSelectionConflict.selector)
        );
        _select(hash, s, 0, 0);
        require(selection.currentRights(1, subject).revision == 0, "timestamp rejection atomic");
        vm.warp(1000);
        _select(hash, s, 0, 0);
    }

    function testLaterOpaqueAuthorAppendDoesNotVetoExplicitValidBootstrap() public {
        _prepare();
        StreamRightsRecordTypes.Statement memory s = _statement();
        bytes32 valid = _published(s);
        IStreamPreservationRecords.CollectionRecord memory bad = _record(RIGHTS_TYPE, bytes("{}"));
        bad.schemaId = StreamRightsRecordDefinitions.SCHEMA_ID;
        bad.contentHash.canonicalizationId = StreamRightsRecordDefinitions.CANON_ID;
        bytes32 latest = metadata.recordCollectionRecordWithPayload(1, bad, bytes("{}"));
        require(
            metadata.latestCollectionRecordHashFor(1, RIGHTS_TYPE, subject, address(this))
                == latest,
            "later generic dossier entry"
        );
        _select(valid, s, 0, 0);
        require(
            selection.requireCurrent(1, subject, valid, 1).recordHash == valid,
            "selected valid older record"
        );
    }

    function testCompetingSuccessorStaleHeadAndSameRecordReplayFailAtomically() public {
        _prepare();
        StreamRightsRecordTypes.Statement memory s = _statement();
        bytes32 first = _published(s);
        _select(first, s, 0, 0);
        s.predecessor = first;
        s.grants.print.status = StreamRightsRecordTypes.Status.DENIED;
        bytes32 second = _published(s);
        _select(second, s, first, 1);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamRightsRecordSelection.RightsSelectionConflict.selector)
        );
        _select(second, s, first, 1);
        s.grants.print.status = StreamRightsRecordTypes.Status.GRANTED;
        bytes32 competitor = _published(s);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamRightsRecordSelection.RightsSelectionConflict.selector)
        );
        _select(competitor, s, second, 2);
        require(
            selection.currentRights(1, subject).recordHash == second,
            "failed selection does not move head"
        );
        require(selection.rightsSelectionAt(1, subject, 1).recordHash == first, "original retained");
    }

    function testRightsGrantRevocationPreservesCurrentEvidenceButStopsNewSelection() public {
        _prepare();
        StreamRightsRecordTypes.Statement memory s = _statement();
        bytes32 first = _published(s);
        _select(first, s, 0, 0);
        s.predecessor = first;
        bytes32 second = _published(s);
        _grant(1, StreamRecordFamilies.RIGHTS, 7, address(this), false);
        require(
            selection.requireCurrent(1, subject, first, 1).grantRevision == 1,
            "historical grant provenance"
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRightsRecordSelection.RightsSelectionAuthorityRequired.selector
            )
        );
        _select(second, s, first, 1);
        _grant(0, StreamRecordFamilies.RIGHTS, 8, address(this), true);
        IStreamRightsRecordSelection.Selection memory selected = _select(second, s, first, 1);
        require(
            selected.authorizationClass == 8 && selected.grantScope == 0,
            "same original publisher; separate current selector authority"
        );
    }

    function testGrantPrecedenceMatchesMetadataHostAndSnapshotGrantConfersNothing() public {
        _prepare();
        StreamRightsRecordTypes.Statement memory s = _statement();
        bytes32 hash = _published(s);
        _grant(1, StreamRecordFamilies.RIGHTS, 7, address(this), false);
        _grant(0, StreamRecordFamilies.SNAPSHOT, 8, address(this), true);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRightsRecordSelection.RightsSelectionAuthorityRequired.selector
            )
        );
        _select(hash, s, 0, 0);
        _grant(0, StreamRecordFamilies.RIGHTS, 7, address(this), true);
        _grant(1, StreamRecordFamilies.RIGHTS, 8, address(this), true);
        IStreamRightsRecordSelection.Selection memory selected = _select(hash, s, 0, 0);
        require(
            selected.authorizationClass == 7 && selected.grantScope == 0,
            "class7 first, then class8"
        );
    }

    function testCompletePayloadWitnessCannotOmitOrChangeAuthoredMeaning() public {
        _prepare();
        StreamRightsRecordTypes.Statement memory s = _statement();
        s.grants.publication.extension = "Keep attribution on museum labels.";
        bytes32 hash = _published(s);
        s.grants.publication.extension = "";
        vm.expectRevert(abi.encodeWithSelector(StreamRecordJson.RecordPayloadMismatch.selector));
        _select(hash, s, 0, 0);
        require(selection.currentRights(1, subject).revision == 0, "no partial state");
        s.grants.publication.extension = "Keep attribution on museum labels.";
        _select(hash, s, 0, 0);
    }

    function testWrongScopeProfileAndHostCannotSelectAnExistingRecord() public {
        _prepare();
        StreamRightsRecordTypes.Statement memory s = _statement();
        bytes32 hash = _published(s);
        s.profileHash = bytes32(uint256(1));
        vm.expectRevert(
            abi.encodeWithSelector(IStreamRightsRecordSelection.InvalidRightsRecord.selector, hash)
        );
        _select(hash, s, 0, 0);
        s.profileHash = StreamRightsRecordDefinitions.PROFILE_HASH;
        s.subjectId = bytes32(uint256(2));
        vm.expectRevert(
            abi.encodeWithSelector(IStreamRightsRecordSelection.InvalidRightsRecord.selector, hash)
        );
        _select(hash, s, 0, 0);
        s.subjectId = subject;
        core.setPointer(keccak256("COLLECTION_METADATA"), address(schemas));
        vm.expectRevert(
            abi.encodeWithSelector(IStreamRightsRecordSelection.RightsHostNotSelected.selector)
        );
        _select(hash, s, 0, 0);
        core.setPointer(keccak256("COLLECTION_METADATA"), address(metadata));
        _select(hash, s, 0, 0);
    }

    function testRetiredProfilePreservesHistoryAndStopsNewConsumption() public {
        _prepare();
        StreamRightsRecordTypes.Statement memory s = _statement();
        bytes32 hash = _published(s);
        _select(hash, s, 0, 0);
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
        require(selection.currentRights(1, subject).recordHash == hash, "current receipt retained");
        require(selection.rightsSelectionAt(1, subject, 1).recordHash == hash, "history retained");
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRightsRecordSelection.RightsDefinitionUnavailable.selector, id
            )
        );
        selection.requireCurrent(1, subject, hash, 1);
    }

    function testCollectionAndBurnedTokenKeepIndependentSelectedRecords() public {
        _prepare();
        StreamRightsRecordTypes.Statement memory s = _statement();
        bytes32 collectionRecord = _published(s);
        _select(collectionRecord, s, 0, 0);
        core.setToken(9, address(0), 3);
        bytes32 tokenSubject = metadata.registerTokenSubject(9);
        s.subjectId = tokenSubject;
        s.grants.reproduction.status = StreamRightsRecordTypes.Status.GRANTED;
        bytes32 tokenRecord = _published(s);
        _select(tokenRecord, s, 0, 0);
        require(
            selection.requireCurrent(1, subject, collectionRecord, 1).recordHash
                == collectionRecord,
            "scope own requirement retained"
        );
        require(
            selection.requireCurrent(1, tokenSubject, tokenRecord, 1).recordHash == tokenRecord,
            "token variance alongside collection"
        );
    }

    function testThresholdSafeSelectsAndReadsCurrentHistory() public {
        _prepare();
        uint256[] memory keys = new uint256[](2);
        keys[0] = 1001;
        keys[1] = 1002;
        OfficialSafe account =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 1);
        _grant(0, StreamRecordFamilies.RIGHTS, 8, address(account), true);
        StreamRightsRecordTypes.Statement memory s = _statement();
        bytes32 hash = _published(s);
        require(
            executeSafe(
                account,
                keys,
                address(selection),
                0,
                abi.encodeCall(
                    selection.selectCurrent, (1, subject, hash, bytes32(0), uint64(0), s)
                ),
                0
            ),
            "Safe selects"
        );
        require(
            selection.currentRights(1, subject).selector == address(account), "Safe is selector"
        );
        require(
            executeSafe(
                account,
                keys,
                address(selection),
                0,
                abi.encodeCall(selection.currentRights, (1, subject)),
                0
            ),
            "Safe reads current"
        );
        require(
            executeSafe(
                account,
                keys,
                address(selection),
                0,
                abi.encodeCall(selection.rightsSelectionAt, (1, subject, uint64(1))),
                0
            ),
            "Safe reads history"
        );
        require(
            executeSafe(
                account,
                keys,
                address(selection),
                0,
                abi.encodeCall(selection.requireCurrent, (1, subject, hash, uint64(1))),
                0
            ),
            "Safe verifies current"
        );
    }

    function testFuzzSupersessionPreservesOriginalReceiptAndIndependentSelectionRevision(uint16 value)
        public
    {
        _prepare();
        StreamRightsRecordTypes.Statement memory s = _statement();
        bytes32 first = _published(s);
        _select(first, s, 0, 0);
        s.predecessor = first;
        s.grants.derivative.extension = StreamRecordJson.unsigned(value);
        bytes32 second = _published(s);
        IStreamRightsRecordSelection.Selection memory selected = _select(second, s, first, 1);
        require(
            selected.revision == 2 && selected.predecessor == first,
            "selection revision distinct from literal JSON version1"
        );
        require(
            selection.rightsSelectionAt(1, subject, 1).recordHash == first, "append-only selection"
        );
        (IStreamPreservationRecords.CollectionRecord memory record,) =
            metadata.collectionRecord(first);
        require(record.subjectId == subject, "original record remains readable");
    }
}
