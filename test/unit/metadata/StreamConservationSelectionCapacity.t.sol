// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamConservationSelectionFixture.sol";

contract StreamConservationSelectionCapacityTest is ConservationSelectionFixture {
    event log_named_uint(string name, uint256 value);

    function testColdMaximumDefinitionAndRecordURIsKeepExactBoundedReads() public {
        registrationURI = _uri(2048);
        recordURI = _uri(2048);
        _prepare();
        _bound();
        StreamConservationRecordTypes.Intent memory v = _intent();
        (bytes32 hash,) = _publish(
            IStreamConservationRecordSelection.RecordKind.INTENT,
            StreamArtistIntentJson.serialize(v),
            1
        );
        IStreamConservationRecordSelection.IntentWitness memory w = _intentWitness(hash, v);
        bytes memory data = abi.encodeCall(selection.adoptIntent, (1, subject, hash, 0, 0, w));
        _cool();
        uint256 start = gasleft();
        (bool ok, bytes memory raw) = address(selection).call{ gas: 16_000_000 }(data);
        emit log_named_uint(
            "maximum URI adoption/named host+library cooling/callee budget16M", start - gasleft()
        );
        require(ok, "complete maximum URI adoption");
        require(
            abi.decode(raw, (IStreamConservationRecordSelection.Selection)).record.recordHash
                == hash,
            "exact original record"
        );
        _cool();
        start = gasleft();
        selection.requireCurrent(1, subject, v.artist.origin, hash, 1);
        emit log_named_uint("maximum URI current-use/named cooling", start - gasleft());
    }

    function testColdExact8192ThousandTagInterviewSelectionMeasured() public ready {
        StreamConservationRecordTypes.Interview memory interview = _interview();
        interview.languages = new string[](1000);
        for (uint256 i; i < 1000; ++i) {
            interview.languages[i] = "en";
        }
        uint256 length = StreamArtistInterviewJson.serialize(interview).length;
        require(length < 8192, "room for exact boundary padding");
        interview.transcript.content.uri =
            _uri(bytes(interview.transcript.content.uri).length + 8192 - length);
        require(
            StreamArtistInterviewJson.serialize(interview).length == 8192,
            "complete exact8192 original"
        );
        StreamConservationRecordTypes.Intent memory v = _intent();
        IStreamConservationRecordSelection.InterviewWitness memory iw;
        (v, iw) = _withInterview(v, interview, 1);
        (bytes32 hash,) = _publish(
            IStreamConservationRecordSelection.RecordKind.INTENT,
            StreamArtistIntentJson.serialize(v),
            1
        );
        IStreamConservationRecordSelection.IntentWitness memory w = _intentWitness(hash, v);
        w.interview = iw;
        bytes memory data = abi.encodeCall(selection.adoptIntent, (1, subject, hash, 0, 0, w));
        _cool();
        uint256 start = gasleft();
        (bool ok, bytes memory raw) = address(selection).call{ gas: 32_000_000 }(data);
        emit log_named_uint(
            "exact8192/1000tags selection/named cooling/callee budget32M", start - gasleft()
        );
        require(ok, "complete thousand-tag original selection");
        require(
            abi.decode(raw, (IStreamConservationRecordSelection.Selection)).interview.payloadHash
                == keccak256(StreamArtistInterviewJson.serialize(interview)),
            "actual full interview bytes"
        );
    }

    function testColdExact8192PreparedInterviewAndParentEachFit16M() public ready {
        StreamConservationRecordTypes.Interview memory interview = _interview();
        interview.languages = new string[](1000);
        for (uint256 i; i < 1000; ++i) {
            interview.languages[i] = "en";
        }
        uint256 length = StreamArtistInterviewJson.serialize(interview).length;
        require(length < 8192, "room for exact boundary padding");
        interview.transcript.content.uri =
            _uri(bytes(interview.transcript.content.uri).length + 8192 - length);
        require(
            StreamArtistInterviewJson.serialize(interview).length == 8192,
            "complete exact8192 original"
        );
        StreamConservationRecordTypes.Intent memory v = _intent();
        IStreamConservationRecordSelection.InterviewWitness memory iw;
        (v, iw) = _withInterview(v, interview, 1);
        (bytes32 hash,) = _publish(
            IStreamConservationRecordSelection.RecordKind.INTENT,
            StreamArtistIntentJson.serialize(v),
            1
        );
        IStreamConservationRecordSelection.IntentWitness memory w = _intentWitness(hash, v);
        w.interview = iw;
        bytes32 interviewHash = v.interview.record.recordHash;
        bytes memory prepareData =
            abi.encodeCall(selection.prepareInterview, (1, subject, interviewHash, iw));
        _cool();
        uint256 start = gasleft();
        (bool prepared, bytes memory preparedRaw) =
            address(selection).call{ gas: 16_000_000 }(prepareData);
        emit log_named_uint(
            "exact8192/1000tags immutable preparation/named cooling/callee16M", start - gasleft()
        );
        require(prepared, "complete interview preparation fits16M");
        IStreamConservationRecordSelection.PreparedInterview memory p =
            abi.decode(preparedRaw, (IStreamConservationRecordSelection.PreparedInterview));
        require(
            p.record.recordHash == interviewHash && p.preparationHash != 0
                && selection.currentConservation(1, subject, v.artist.origin).revision == 0,
            "preparation is not selection"
        );
        IStreamConservationRecordSelection.InterviewWitness memory empty;
        w.interview = empty;
        bytes memory data =
            abi.encodeCall(selection.adoptIntentWithPreparedInterview, (1, subject, hash, 0, 0, w));
        _cool();
        start = gasleft();
        (bool ok, bytes memory raw) = address(selection).call{ gas: 16_000_000 }(data);
        emit log_named_uint("prepared parent adoption/named cooling/callee16M", start - gasleft());
        require(ok, "complete prepared parent adoption fits16M");
        require(
            abi.decode(raw, (IStreamConservationRecordSelection.Selection)).interview.payloadHash
                == p.record.payloadHash,
            "same exact validated original interview"
        );
    }

    function testLowParentGasRollsBackHeadThenSameWitnessSucceeds() public ready {
        StreamConservationRecordTypes.Intent memory v = _intent();
        (bytes32 hash,) = _publish(
            IStreamConservationRecordSelection.RecordKind.INTENT,
            StreamArtistIntentJson.serialize(v),
            1
        );
        IStreamConservationRecordSelection.IntentWitness memory w = _intentWitness(hash, v);
        bytes memory data = abi.encodeCall(selection.adoptIntent, (1, subject, hash, 0, 0, w));
        (bool ok,) = address(selection).call{ gas: 100000 }(data);
        require(
            !ok && selection.currentConservation(1, subject, v.artist.origin).revision == 0,
            "insufficient parent causes no partial head"
        );
        selection.adoptIntent(1, subject, hash, 0, 0, w);
    }

    function testActualThresholdSafeAdoptsReadsAndLocksAfterOrdinaryRotation() public ready {
        uint256[] memory keys = new uint256[](2);
        keys[0] = 9301;
        keys[1] = 9302;
        OfficialSafe safe =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 1930);
        StreamConservationRecordTypes.Intent memory v = _intent();
        (bytes32 hash,) = _publish(
            IStreamConservationRecordSelection.RecordKind.INTENT,
            StreamArtistIntentJson.serialize(v),
            1
        );
        require(
            executeSafe(
                safe,
                keys,
                address(selection),
                0,
                abi.encodeCall(
                    selection.adoptIntent,
                    (1, subject, hash, bytes32(0), uint64(0), _intentWitness(hash, v))
                ),
                0
            ),
            "actual Safe adoption"
        );
        IStreamConservationRecordSelection.Selection memory saved =
            selection.currentConservation(1, subject, v.artist.origin);
        require(
            saved.submitter == address(safe) && saved.record.recorder == ORIGINAL,
            "Safe submitter does not become original author"
        );
        bytes memory input = abi.encodeCall(
            selection.requireCurrent, (1, subject, v.artist.origin, hash, uint64(1))
        );
        (bool ok, bytes memory raw) = address(selection).staticcall(input);
        require(ok && keccak256(raw) == keccak256(abi.encode(saved)), "ordinary exact typed result");
        require(
            executeSafe(safe, keys, address(selection), 0, input, 0), "actual Safe read success"
        );
        identityOwner.setIdentity(address(safe), 1, 1, IDENTITY);
        facade.setSigner(address(safe));
        require(
            executeSafe(
                safe,
                keys,
                address(selection),
                0,
                abi.encodeCall(selection.lockArtistIntent, (1, subject, hash, uint64(1))),
                0
            ),
            "actual new-principal Safe lock"
        );
        require(
            selection.intentLock(1, subject).locker == address(safe)
                && selection.currentConservation(1, subject, v.artist.origin).record.recorder
                    == ORIGINAL,
            "new lock authority never rewrites original publication"
        );
    }

    function testActualTokenSubjectOriginalDoesNotBecomeCollectionEvidence() public ready {
        bytes32 collectionSubject = subject;
        core.setToken(77, ORIGINAL, 3);
        subject = metadata.registerTokenSubject(77);
        StreamConservationRecordTypes.Intent memory v = _intent();
        (bytes32 hash,) = _publish(
            IStreamConservationRecordSelection.RecordKind.INTENT,
            StreamArtistIntentJson.serialize(v),
            1
        );
        IStreamConservationRecordSelection.IntentWitness memory w = _intentWitness(hash, v);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamConservationRecordSelection.InvalidConservationRecord.selector, hash
            )
        );
        selection.adoptIntent(1, collectionSubject, hash, 0, 0, w);
        selection.adoptIntent(1, subject, hash, 0, 0, w);
        selection.requireCurrent(1, subject, v.artist.origin, hash, 1);
        require(
            selection.currentConservation(1, collectionSubject, v.artist.origin).revision == 0,
            "burned token original is scoped independently"
        );
    }

    function _cool() private {
        safeVm.cool(address(core));
        safeVm.cool(address(metadata));
        safeVm.cool(address(schemas));
        safeVm.cool(address(store));
        safeVm.cool(address(facade));
        safeVm.cool(address(coordinator));
        safeVm.cool(address(identityOwner));
        safeVm.cool(address(bindingOwner));
        safeVm.cool(address(attributionOwner));
        safeVm.cool(address(selection));
        safeVm.cool(address(StreamConservationRecordContext));
        safeVm.cool(address(StreamConservationPublicationReads));
        safeVm.cool(address(StreamConservationRecordReads));
        safeVm.cool(address(StreamRecordArtistIdentityReads));
        safeVm.cool(address(StreamArtistIntentJson));
        safeVm.cool(address(StreamArtistIntentWaiverJson));
        safeVm.cool(address(StreamArtistInterviewJson));
        safeVm.cool(address(StreamConservationRecordFields));
        safeVm.cool(address(StreamConservationFormatJson));
        safeVm.cool(address(StreamConservationLanguage));
        safeVm.cool(address(StreamRecordJson));
        safeVm.cool(address(StreamMetadataRenderer));
    }

    function _uri(uint256 length) private pure returns (string memory) {
        require(length >= 7 && length <= 2048, "valid URI length");
        bytes memory raw = new bytes(length);
        bytes memory prefix = bytes("ipfs://");
        for (uint256 i; i < length; ++i) {
            raw[i] = i < prefix.length ? prefix[i] : bytes1("a");
        }
        return string(raw);
    }
}
