// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./ArtistOnboardingFixture.sol";
import "./ConservationCanonicalPublicationFixture.sol";
import "../../../smart-contracts/domains/metadata/StreamConservationRecordSelection.sol";

/// @notice Actual Artist owners/op24/threshold Safes and Metadata/Schema/Store.
/// @dev Core and governance authorization remain the explicit ArtistOnboardingFixture boundaries.
contract StreamConservationActualArtistTest is ArtistOnboardingFixture {
    ConservationCanonicalPublicationFixture private hostFixture;
    StreamCollectionMetadataV1 private host;
    StreamConservationRecordSelection private selector;
    bytes32 private subject;

    function testActualSafeInterviewAndIntentRemainOriginalAfterRotationThenLock() public {
        _actualHost();
        IStreamConservationRecordSelection.IntentWitness memory w = _presentIntent();
        bytes memory payload = StreamArtistIntentJson.serialize(w.intent);
        bytes32 hash;
        (hash, w.original) = _publishActual(
            keccak256("ARTIST_INTENT"), StreamConservationDefinitions.INTENT_SCHEMA_ID, payload
        );
        address originalArtist = address(artist);
        _newRotationSafe(12345);
        bytes32 rotation = _stageRotation(0);
        _executeTimedRotation(rotation);
        _adoptRotatedSafe();
        IStreamConservationRecordSelection.Selection memory selected =
            selector.adoptIntent(1, subject, hash, 0, 0, w);
        require(
            selected.record.recorder == originalArtist
                && selected.interview.recorder == originalArtist,
            "both original Safe authors remain after real key rotation"
        );
        require(
            selected.record.publication.requiredCapability == 64
                && selected.interview.publication.requiredCapability == 1
                && selected.interviewPayloadCorrespondence
                    == IStreamConservationRecordSelection.PayloadCorrespondence.EXACT_JCS_KECCAK256,
            "actual op24 classes and exact original interview payload"
        );
        require(
            executeSafe(
                artist,
                keys,
                address(selector),
                0,
                abi.encodeCall(selector.lockArtistIntent, (1, subject, hash, uint64(1))),
                0
            ),
            "rotated threshold Safe authorizes independent one-way lock"
        );
        require(selector.intentLock(1, subject).locker == address(artist), "real current principal");
        selector.requireCurrent(1, subject, w.intent.artist.origin, hash, 1);
    }

    function testActualEstateWaiverRetainsLifetimeChainAndInterviewOrigins() public {
        _actualHost();
        IStreamConservationRecordSelection.IntentWitness memory w = _presentIntent();
        bytes32 hash;
        (hash, w.original) = _publishActual(
            keccak256("ARTIST_INTENT"),
            StreamConservationDefinitions.INTENT_SCHEMA_ID,
            StreamArtistIntentJson.serialize(w.intent)
        );
        address lifetimeArtist = address(artist);
        _estateActivateAndAdopt(65);
        // Indexing a lifetime publication is not a new statement by the successor.
        selector.adoptIntent(1, subject, hash, 0, 0, w);
        IStreamConservationRecordSelection.WaiverWitness memory e;
        e.waiver.subjectId = subject;
        e.waiver.profileHash = StreamConservationDefinitions.WAIVER_PROFILE_HASH;
        e.waiver.artist = w.intent.artist;
        e.waiver.artist.origin = StreamConservationRecordTypes.StatementOrigin.ESTATE_STATEMENT;
        e.waiver.waiverStatement = _ref("ipfs://estate-declared-intent-waiver");
        e.waiver.interview = w.intent.interview;
        e.interview = w.interview;
        bytes32 estateHash;
        (estateHash, e.original) = _publishActual(
            keccak256("ARTIST_INTENT_WAIVER"),
            StreamConservationDefinitions.WAIVER_SCHEMA_ID,
            StreamArtistIntentWaiverJson.serialize(e.waiver)
        );
        IStreamConservationRecordSelection.Selection memory saved =
            selector.adoptWaiver(1, subject, estateHash, 0, 0, e);
        require(
            saved.record.publication.authorityClass == 3
                && saved.record.recorder == address(artist),
            "actual successor publication is a distinct estate statement"
        );
        require(
            saved.interview.publication.authorityClass == 1
                && saved.interview.recorder == lifetimeArtist,
            "estate reference never relabels lifetime interview author"
        );
        require(
            selector.currentConservation(
                    1, subject, StreamConservationRecordTypes.StatementOrigin.ARTIST_INTENT
                ).record.recordHash == hash,
            "original artist voice remains separate"
        );
    }

    function testActualSignedFailureRollbackThenPreparedParentAdoption() public {
        _actualHost();
        IStreamConservationRecordSelection.IntentWitness memory w = _presentIntent();
        selector.prepareInterview(1, subject, w.intent.interview.record.recordHash, w.interview);
        bytes memory payload = StreamArtistIntentJson.serialize(w.intent);
        P.Publication memory pub;
        (w.original, pub) = hostFixture.prepare(
            address(artist),
            keccak256("ARTIST_INTENT"),
            StreamConservationDefinitions.INTENT_SCHEMA_ID,
            payload,
            "ipfs://retry-original"
        );
        (T.Attestation memory p, bytes memory statement) =
            _canonicalAttestation(pub, w.original.uri);
        T.Authorization memory a = _authorization(true);
        bytes memory healthy = _signature(ingress.attestationDigest(p, a));
        a.signature = bytes("invalid threshold Safe proof");
        bytes32 roots = _roots();
        vm.expectRevert();
        ingress.recordArtistAttestation(p, a, statement);
        require(_roots() == roots, "invalid Safe proof changes no artist state or nonce root");
        a.signature = healthy;
        bytes32 authorization = ingress.recordArtistAttestation(p, a, statement);
        this.executePublicationSafe(
            address(host),
            abi.encodeCall(
                IStreamCollectionMetadataV1.recordArtistCollectionRecordWithPayload,
                (address(artist), uint256(1), w.original, payload, authorization)
            )
        );
        IStreamConservationRecordSelection.InterviewWitness memory empty;
        w.interview = empty;
        IStreamConservationRecordSelection.Selection memory selected =
            selector.adoptIntentWithPreparedInterview(1, subject, pub.candidateRecordHash, 0, 0, w);
        require(
            selected.record.publication.attestationRecordHash == authorization
                && selected.interview.recordHash == w.intent.interview.record.recordHash,
            "same healthy authorization plus exact prepared actual interview"
        );
        selector.requireCurrent(1, subject, w.intent.artist.origin, pub.candidateRecordHash, 1);
    }

    function _actualHost() private {
        actualSaleRegistryFixture = true;
        setUp();
        _accept();
        hostFixture = new ConservationCanonicalPublicationFixture();
        bytes[] memory docs = new bytes[](9);
        docs[0] = bytes(vm.readFile("schemas/museum/account-profile/RFC8785_JCS.json"));
        string[8] memory names = [
            "STREAM_ARTIST_INTENT_V1",
            "STREAM_ARTIST_INTENT_JSON_PROFILE_V1",
            "STREAM_ARTIST_INTENT_WAIVER_V1",
            "STREAM_ARTIST_INTENT_WAIVER_JSON_PROFILE_V1",
            "STREAM_ARTIST_INTERVIEW_V1",
            "STREAM_ARTIST_INTERVIEW_JSON_PROFILE_V1",
            "STREAM_CONSERVATION_FORMAT_CATALOG_V1",
            "STREAM_CONSERVATION_FORMAT_CATALOG_JSON_PROFILE_V1"
        ];
        for (uint256 i; i < names.length; ++i) {
            docs[i + 1] = bytes(vm.readFile(string.concat("schemas/records/", names[i], ".json")));
        }
        hostFixture.deploy(address(core), address(ingress), docs);
        host = hostFixture.metadata();
        _saleRegister(
            saleModules,
            factory.governanceAuthority(),
            address(host),
            keccak256("COLLECTION_METADATA"),
            type(IStreamCollectionMetadataV1).interfaceId
        );
        core.set(keccak256("COLLECTION_METADATA"), address(host), false);
        selector = new StreamConservationRecordSelection(
            address(core), address(host), address(hostFixture.schemas())
        );
        subject = StreamMetadataSubjects.scopeSubject(
            block.chainid,
            address(core),
            StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0)
        );
    }

    function _publishActual(bytes32 kind, bytes32 schema, bytes memory payload)
        private
        returns (bytes32 hash, IStreamPreservationRecords.CollectionRecord memory r)
    {
        P.Publication memory pub;
        (r, pub) =
            hostFixture.prepare(address(artist), kind, schema, payload, "ipfs://actual-original");
        require(
            pub.candidateRecordHash == _canonicalRecordHash(r, pub), "independent14-word original"
        );
        bytes memory statement = abi.encode(uint16(1), pub);
        bool intent = kind != keccak256("ARTIST_STATEMENT");
        T.Attestation memory p = T.Attestation(
            1,
            intent ? 7 : 8,
            subject,
            intent ? pub.candidateRecordHash : bytes32(0),
            keccak256("6529STREAM_ARTIST_RECORD_PUBLICATION_V1"),
            keccak256(statement),
            r.uri
        );
        T.Authorization memory a = _authorization(true);
        a.signature = _signature(ingress.attestationDigest(p, a));
        bytes32 authorization = ingress.recordArtistAttestation(p, a, statement);
        this.executePublicationSafe(
            address(host),
            abi.encodeCall(
                IStreamCollectionMetadataV1.recordArtistCollectionRecordWithPayload,
                (address(artist), uint256(1), r, payload, authorization)
            )
        );
        (, IStreamCollectionMetadataV1.RecordReceipt memory receipt) =
            host.collectionRecord(pub.candidateRecordHash);
        require(
            receipt.artistAuthorization == authorization && receipt.recorder == address(artist),
            "actual op24 then actual Safe Metadata append"
        );
        hash = pub.candidateRecordHash;
    }

    function _presentIntent()
        private
        returns (IStreamConservationRecordSelection.IntentWitness memory w)
    {
        StreamConservationRecordTypes.Interview memory interview;
        interview.subjectId = subject;
        interview.profileHash = StreamConservationDefinitions.INTERVIEW_PROFILE_HASH;
        interview.instrument.document = _ref("ipfs://questionnaire");
        interview.participants = new StreamConservationRecordTypes.Participant[](2);
        interview.participants[0] = StreamConservationRecordTypes.Participant(
            StreamConservationRecordTypes.ParticipantRole.ARTIST, "", _ref("ipfs://declared-artist")
        );
        interview.participants[1] = StreamConservationRecordTypes.Participant(
            StreamConservationRecordTypes.ParticipantRole.INTERVIEWER,
            "",
            _ref("ipfs://declared-interviewer")
        );
        interview.interviewDate = 20240229;
        interview.languages = new string[](1);
        interview.languages[0] = "en-US";
        interview.transcript.content = _ref("ipfs://transcript");
        interview.transcript.format.formatId = keccak256("PRONOM:fmt/111");
        interview.transcript.format.puid = "fmt/111";
        bytes memory interviewPayload = StreamArtistInterviewJson.serialize(interview);
        bytes32 interviewHash;
        (interviewHash, w.interview.original) = _publishActual(
            keccak256("ARTIST_STATEMENT"),
            StreamConservationDefinitions.INTERVIEW_SCHEMA_ID,
            interviewPayload
        );
        w.interview.interview = interview;
        T.Binding memory b = coordinator.reads().acceptedBinding(1);
        w.intent.subjectId = subject;
        w.intent.profileHash = StreamConservationDefinitions.INTENT_PROFILE_HASH;
        w.intent.artist = StreamConservationRecordTypes.ArtistClaim(
            artistId,
            b.generation,
            b.bindingHash,
            StreamConservationRecordTypes.StatementOrigin.ARTIST_INTENT
        );
        w.intent.display.scale = _ref("ipfs://scale");
        w.intent.display.timing = _ref("ipfs://timing");
        w.intent.display.color = _ref("ipfs://color");
        w.intent.display.interaction = _ref("ipfs://interaction");
        w.intent.display.motion = _ref("ipfs://motion");
        w.intent.display.frameRate = _ref("ipfs://frame-rate");
        w.intent.variabilityTolerances = _ref("ipfs://variability");
        w.intent.dependencyAging = _ref("ipfs://aging");
        w.intent.significantProperties = _ref("ipfs://significant");
        w.intent.interview.status = StreamConservationRecordTypes.InterviewStatus.PRESENT;
        w.intent.interview.record = StreamConservationRecordTypes.InterviewRecord(
            block.chainid,
            address(core),
            address(host),
            interviewHash,
            StreamConservationDefinitions.INTERVIEW_SCHEMA_ID,
            StreamConservationDefinitions.INTERVIEW_PROFILE_HASH,
            StreamConservationRecordTypes.Reference(
                1,
                StreamWorkRecordDefinitions.CANON_ID,
                abi.encodePacked(keccak256(interviewPayload)),
                "ipfs://distinct-interview-mirror"
            )
        );
    }

    function _ref(string memory uri)
        private
        pure
        returns (StreamConservationRecordTypes.Reference memory)
    {
        return StreamConservationRecordTypes.Reference(
            1, keccak256("RAW_BYTES"), abi.encodePacked(keccak256(bytes(uri))), uri
        );
    }
}
