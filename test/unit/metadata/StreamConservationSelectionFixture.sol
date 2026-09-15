// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamCollectionMetadataV1.t.sol";
import "../../../smart-contracts/domains/metadata/StreamConservationRecordSelection.sol";

interface ConservationSelectionVm {
    function mockCall(address target, bytes calldata input, bytes calldata output) external;
    function clearMockedCalls() external;
}

/// @dev Explicit typed artist-owner response fixtures; no real op24 signature execution claim.
contract ConservationSelectionOwnerBoundary {
    address public core;
    address public artistRegistry;
    address public operationCoordinator;
    uint256 public deploymentChainId;
    T.Binding private savedBinding;
    uint8 private state;
    address private authority;
    uint8 private authorityClass = 1;
    uint8 private authorityStatus = 1;
    bytes32 private registration;
    mapping(bytes32 => IStreamArtistRecordPublicationOwner.Record) private publications;
    mapping(bytes32 => T.AttestationRecord) private attestations;
    mapping(bytes32 => bytes) private statements;

    function configure(address c, address facade, address coordinator) external {
        core = c;
        artistRegistry = facade;
        operationCoordinator = coordinator;
        deploymentChainId = block.chainid;
    }

    function setBinding(T.Binding memory value, uint8 status) external {
        savedBinding = value;
        state = status;
    }

    function binding(uint256) external view returns (T.Binding memory) {
        return savedBinding;
    }

    function attributionState(uint256) external view returns (uint8, uint64) {
        return (state, savedBinding.generation);
    }

    function setIdentity(address signer, uint8 class_, uint8 status_, bytes32 hash) external {
        authority = signer;
        authorityClass = class_;
        authorityStatus = status_;
        registration = hash;
    }

    function authorityState(bytes32) external view returns (address, uint8, uint8, bytes32) {
        return (authority, authorityClass, authorityStatus, registration);
    }

    function savePublication(IStreamArtistRecordPublicationOwner.Record memory r) external {
        publications[r.evidence.attestationRecordHash] = r;
        bytes memory statement = abi.encode(uint16(1), r.publication);
        bytes32 hash = keccak256(statement);
        attestations[r.evidence.attestationRecordHash] = T.AttestationRecord(
            r.evidence.attestationRecordHash,
            r.publication.recordType == keccak256("ARTIST_STATEMENT")
                ? bytes32(0)
                : r.publication.candidateRecordHash,
            keccak256("6529STREAM_ARTIST_RECORD_PUBLICATION_V1"),
            hash,
            r.evidence.bindingGeneration,
            r.evidence.signedAt,
            r.evidence.signer
        );
        statements[hash] = statement;
    }

    function publicationAttestation(bytes32 id)
        external
        view
        returns (IStreamArtistRecordPublicationOwner.Record memory)
    {
        return publications[id];
    }

    function attestationRecord(bytes32 id) external view returns (T.AttestationRecord memory) {
        return attestations[id];
    }

    function statementBytes(bytes32 hash) external view returns (bytes memory) {
        return statements[hash];
    }
}

contract ConservationSelectionCoordinatorBoundary {
    T.SuiteConfiguration private suite;
    uint256 public deploymentChainId = block.chainid;

    function setSuite(T.SuiteConfiguration memory value) external {
        suite = value;
    }

    function suiteConfiguration() external view returns (T.SuiteConfiguration memory) {
        return suite;
    }
}

contract ConservationSelectionFacadeBoundary {
    address public core;
    address public operationCoordinator;
    address public currentSigner;
    ConservationSelectionOwnerBoundary public publications;

    constructor(address c, address coordinator, ConservationSelectionOwnerBoundary owner) {
        core = c;
        operationCoordinator = coordinator;
        publications = owner;
    }

    function setSigner(address value) external {
        currentSigner = value;
    }

    function requireRecordPublication(bytes32 id, P.Publication calldata p)
        external
        view
        returns (P.Evidence memory)
    {
        IStreamArtistRecordPublicationOwner.Record memory r =
            publications.publicationAttestation(id);
        require(
            p.recorder == currentSigner
                && keccak256(abi.encode(p)) == keccak256(abi.encode(r.publication)),
            "typed original publication"
        );
        (bytes32 hash, uint8 kind) =
            IStreamArtistRecordPublicationHost(p.metadataHost).requireArtistRecordCandidate(p);
        require(
            hash == p.candidateRecordHash
                && kind == (p.recordType == keccak256("ARTIST_STATEMENT") ? 8 : 7),
            "actual conservation host candidate"
        );
        return r.evidence;
    }
}

abstract contract ConservationSelectionFixture is CollectionMetadataV1Fixture {
    ConservationSelectionVm internal constant cvm =
        ConservationSelectionVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    StreamConservationRecordSelection internal selection;
    ConservationSelectionFacadeBoundary internal facade;
    ConservationSelectionCoordinatorBoundary internal coordinator;
    ConservationSelectionOwnerBoundary internal identityOwner;
    ConservationSelectionOwnerBoundary internal bindingOwner;
    ConservationSelectionOwnerBoundary internal attributionOwner;
    bytes32 internal constant INTENT = keccak256("ARTIST_INTENT");
    bytes32 internal constant WAIVER = keccak256("ARTIST_INTENT_WAIVER");
    bytes32 internal constant INTERVIEW = keccak256("ARTIST_STATEMENT");
    bytes32 internal constant ARTIST_ID = keccak256("registered artist");
    bytes32 internal constant BINDING = keccak256("accepted binding");
    bytes32 internal constant IDENTITY = keccak256("immutable identity registration");
    address internal constant ORIGINAL = address(0xa47157);
    address internal constant ESTATE = address(0xe57a7e);
    address internal constant RELAYER = address(0xde11);
    uint256 private publicationNonce;
    string internal registrationURI;
    string internal recordURI = "ipfs://original-conservation";
    mapping(bytes32 => IStreamPreservationRecords.CollectionRecord) internal originals;
    modifier ready() {
        _prepare();
        _bound();
        _;
    }

    function _prepare() internal {
        // The borrowed generic fixture deliberately registers a placeholder interview schema.
        // This profile uses a fresh real registry/store and the exact retained full definitions.
        schemas = new StreamSchemaRegistry(address(executor));
        store = StreamSchemaDocumentStore(schemas.chunkStore());
        _registerDocument(
            "RAW_BYTES",
            IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
            bytes(schemas.RAW_BYTES_DEFINITION()),
            schemas.RAW_BYTES()
        );
        coordinator = new ConservationSelectionCoordinatorBoundary();
        identityOwner = new ConservationSelectionOwnerBoundary();
        bindingOwner = new ConservationSelectionOwnerBoundary();
        attributionOwner = new ConservationSelectionOwnerBoundary();
        facade = new ConservationSelectionFacadeBoundary(
            address(core), address(coordinator), attributionOwner
        );
        identityOwner.configure(address(core), address(facade), address(coordinator));
        bindingOwner.configure(address(core), address(facade), address(coordinator));
        attributionOwner.configure(address(core), address(facade), address(coordinator));
        T.SuiteConfiguration memory suite;
        suite.registry = address(facade);
        suite.core = address(core);
        suite.owners[0] = address(bindingOwner);
        suite.owners[2] = address(identityOwner);
        suite.owners[4] = address(attributionOwner);
        coordinator.setSuite(suite);
        StreamCollectionMetadataV1.Configuration memory c;
        c.core = address(core);
        c.executor = address(executor);
        c.schemas = address(schemas);
        c.artistRegistry = address(facade);
        c.deploymentManifestHash = bytes32(uint256(11));
        c.manifestHash = bytes32(uint256(12));
        c.manifestURI = "ipfs://conservation-test-metadata";
        c.dependencyReadGas = IStreamGasParameterHost.GasParameterConfig(
            "METADATA_DEPENDENCY_READ_GAS", 150000, 100000, 2
        );
        c.artistReadGas = IStreamGasParameterHost.GasParameterConfig(
            "METADATA_ARTIST_READ_GAS", 2000000, 1000000, 2
        );
        metadata = new StreamCollectionMetadataV1(c);
        core.setPointer(keccak256("COLLECTION_METADATA"), address(metadata));
        core.setPointer(keccak256("ARTIST_REGISTRY"), address(facade));
        _registerDocument(
            "RFC8785_JCS",
            IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
            bytes(vm.readFile("schemas/museum/account-profile/RFC8785_JCS.json")),
            schemas.RAW_BYTES()
        );
        _registerDocument(
            "STREAM_ARTIST_INTENT_V1",
            IStreamSchemaRegistry.DocumentKind.SCHEMA,
            bytes(vm.readFile("schemas/records/STREAM_ARTIST_INTENT_V1.json")),
            schemas.RAW_BYTES()
        );
        _registerDocument(
            "STREAM_ARTIST_INTENT_JSON_PROFILE_V1",
            IStreamSchemaRegistry.DocumentKind.CATALOG,
            bytes(vm.readFile("schemas/records/STREAM_ARTIST_INTENT_JSON_PROFILE_V1.json")),
            schemas.RAW_BYTES()
        );
        _registerDocument(
            "STREAM_ARTIST_INTENT_WAIVER_V1",
            IStreamSchemaRegistry.DocumentKind.SCHEMA,
            bytes(vm.readFile("schemas/records/STREAM_ARTIST_INTENT_WAIVER_V1.json")),
            schemas.RAW_BYTES()
        );
        _registerDocument(
            "STREAM_ARTIST_INTENT_WAIVER_JSON_PROFILE_V1",
            IStreamSchemaRegistry.DocumentKind.CATALOG,
            bytes(vm.readFile("schemas/records/STREAM_ARTIST_INTENT_WAIVER_JSON_PROFILE_V1.json")),
            schemas.RAW_BYTES()
        );
        _registerDocument(
            "STREAM_ARTIST_INTERVIEW_V1",
            IStreamSchemaRegistry.DocumentKind.SCHEMA,
            bytes(vm.readFile("schemas/records/STREAM_ARTIST_INTERVIEW_V1.json")),
            schemas.RAW_BYTES()
        );
        _registerDocument(
            "STREAM_ARTIST_INTERVIEW_JSON_PROFILE_V1",
            IStreamSchemaRegistry.DocumentKind.CATALOG,
            bytes(vm.readFile("schemas/records/STREAM_ARTIST_INTERVIEW_JSON_PROFILE_V1.json")),
            schemas.RAW_BYTES()
        );
        _registerDocument(
            "STREAM_CONSERVATION_FORMAT_CATALOG_V1",
            IStreamSchemaRegistry.DocumentKind.SCHEMA,
            bytes(vm.readFile("schemas/records/STREAM_CONSERVATION_FORMAT_CATALOG_V1.json")),
            schemas.RAW_BYTES()
        );
        _registerDocument(
            "STREAM_CONSERVATION_FORMAT_CATALOG_JSON_PROFILE_V1",
            IStreamSchemaRegistry.DocumentKind.CATALOG,
            bytes(
                vm.readFile(
                    "schemas/records/STREAM_CONSERVATION_FORMAT_CATALOG_JSON_PROFILE_V1.json"
                )
            ),
            schemas.RAW_BYTES()
        );
        _admit(INTENT, StreamRecordFamilies.ARTIST, 2);
        _admit(WAIVER, StreamRecordFamilies.ARTIST, 2);
        _admit(INTERVIEW, StreamRecordFamilies.ARTIST, 2);
        selection = new StreamConservationRecordSelection(
            address(core), address(metadata), address(schemas)
        );
    }

    function _registerDocument(
        string memory name,
        IStreamSchemaRegistry.DocumentKind kind,
        bytes memory payload,
        bytes32 canon
    ) internal returns (bytes32) {
        bytes32[] memory chunks = new bytes32[]((payload.length + 8191) / 8192);
        for (uint256 i; i < chunks.length; ++i) {
            uint256 size = payload.length - i * 8192;
            if (size > 8192) size = 8192;
            bytes memory part = new bytes(size);
            for (uint256 j; j < size; ++j) {
                part[j] = payload[i * 8192 + j];
            }
            (chunks[i],) = store.publishChunk(part);
        }
        IStreamSchemaRegistry.DocumentSpec memory spec = IStreamSchemaRegistry.DocumentSpec(
            name, kind, keccak256(payload), canon, 0, registrationURI, uint32(payload.length)
        );
        (bytes32 s, bytes32 o, bytes32 n) = schemas.registrationTransition(spec, chunks);
        return abi.decode(
            executor.execute(
                address(schemas), abi.encodeCall(schemas.registerDocument, (spec, chunks)), s, o, n
            ),
            (bytes32)
        );
    }

    function _bound() internal {
        T.Binding memory b =
            T.Binding(ARTIST_ID, ORIGINAL, IDENTITY, BINDING, 1, 1, 0, 0, address(this), true);
        bindingOwner.setBinding(b, 2);
        attributionOwner.setBinding(b, 2);
        identityOwner.setIdentity(ORIGINAL, 1, 1, IDENTITY);
        facade.setSigner(ORIGINAL);
    }

    function _ref(string memory uri)
        internal
        pure
        returns (StreamConservationRecordTypes.Reference memory r)
    {
        r.algorithm = 1;
        r.canonicalizationId = keccak256("RAW_BYTES");
        r.digest = abi.encodePacked(keccak256(bytes(uri)));
        r.uri = uri;
    }

    function _intent() internal view returns (StreamConservationRecordTypes.Intent memory v) {
        v.subjectId = subject;
        v.profileHash = StreamConservationDefinitions.INTENT_PROFILE_HASH;
        v.artist = StreamConservationRecordTypes.ArtistClaim(
            ARTIST_ID, 1, BINDING, StreamConservationRecordTypes.StatementOrigin.ARTIST_INTENT
        );
        v.display.scale = _ref("ipfs://scale");
        v.display.timing = _ref("ipfs://timing");
        v.display.color = _ref("ipfs://color");
        v.display.interaction = _ref("ipfs://interaction");
        v.display.motion = _ref("ipfs://motion");
        v.display.frameRate = _ref("ipfs://frameRate");
        v.variabilityTolerances = _ref("ipfs://variability");
        v.dependencyAging = _ref("ipfs://aging");
        v.significantProperties = _ref("ipfs://significant");
        v.interview.status = StreamConservationRecordTypes.InterviewStatus.WAIVED;
        v.interview.waiverStatement = _ref("ipfs://deliberately-waived-interview");
    }

    function _waiver() internal view returns (StreamConservationRecordTypes.IntentWaiver memory v) {
        v.subjectId = subject;
        v.profileHash = StreamConservationDefinitions.WAIVER_PROFILE_HASH;
        v.artist = StreamConservationRecordTypes.ArtistClaim(
            ARTIST_ID, 1, BINDING, StreamConservationRecordTypes.StatementOrigin.ARTIST_INTENT
        );
        v.waiverStatement = _ref("ipfs://explicit-intent-waiver");
        v.interview.status = StreamConservationRecordTypes.InterviewStatus.WAIVED;
        v.interview.waiverStatement = _ref("ipfs://distinct-interview-waiver");
    }

    function _interview() internal view returns (StreamConservationRecordTypes.Interview memory v) {
        v.subjectId = subject;
        v.profileHash = StreamConservationDefinitions.INTERVIEW_PROFILE_HASH;
        v.instrument.document = _ref("ipfs://questionnaire");
        v.participants = new StreamConservationRecordTypes.Participant[](2);
        v.participants[0] = StreamConservationRecordTypes.Participant(
            StreamConservationRecordTypes.ParticipantRole.ARTIST,
            "",
            _ref("ipfs://declared-artist-identity")
        );
        v.participants[1] = StreamConservationRecordTypes.Participant(
            StreamConservationRecordTypes.ParticipantRole.INTERVIEWER,
            "",
            _ref("ipfs://interviewer")
        );
        v.interviewDate = 20240229;
        v.languages = new string[](2);
        v.languages[0] = "en-US";
        v.languages[1] = "fr";
        v.transcript.content = _ref("ipfs://transcript");
        v.transcript.format.formatId = keccak256("PRONOM:fmt/111");
        v.transcript.format.puid = "fmt/111";
        v.captures = new StreamConservationRecordTypes.Capture[](0);
    }

    function _publish(
        IStreamConservationRecordSelection.RecordKind kind,
        bytes memory payload,
        uint8 authorityClass
    ) internal returns (bytes32 hash, bytes32 authorization) {
        (bytes32 recordType, bytes32 schemaId,) =
            StreamConservationPublicationReads.definition(kind);
        IStreamPreservationRecords.CollectionRecord memory r = _record(recordType, payload);
        r.schemaId = schemaId;
        r.uri = recordURI;
        r.contentHash.canonicalizationId = StreamWorkRecordDefinitions.CANON_ID;
        address signer = authorityClass == 1 ? ORIGINAL : ESTATE;
        facade.setSigner(signer);
        P.Publication memory p = _publication(signer, r);
        authorization = keccak256(abi.encode("fixture executed op24", ++publicationNonce, p));
        P.Evidence memory e = P.Evidence(
            authorization,
            ARTIST_ID,
            BINDING,
            1,
            signer,
            authorityClass,
            kind == IStreamConservationRecordSelection.RecordKind.INTERVIEW ? 1 : 64,
            uint64(block.timestamp),
            keccak256(abi.encode(p))
        );
        attributionOwner.savePublication(
            IStreamArtistRecordPublicationOwner.Record(p, e, address(metadata).codehash)
        );
        hash = metadata.recordArtistCollectionRecordWithPayload(
            signer, 1, r, payload, authorization
        );
        originals[hash] = r;
        require(hash == p.candidateRecordHash, "exact original record hash");
    }

    function _intentWitness(bytes32 hash, StreamConservationRecordTypes.Intent memory v)
        internal
        view
        returns (IStreamConservationRecordSelection.IntentWitness memory w)
    {
        w.original = originals[hash];
        w.intent = v;
    }

    function _waiverWitness(bytes32 hash, StreamConservationRecordTypes.IntentWaiver memory v)
        internal
        view
        returns (IStreamConservationRecordSelection.WaiverWitness memory w)
    {
        w.original = originals[hash];
        w.waiver = v;
    }

    function _withInterview(
        StreamConservationRecordTypes.Intent memory v,
        StreamConservationRecordTypes.Interview memory interview,
        uint8 auth
    )
        internal
        returns (
            StreamConservationRecordTypes.Intent memory,
            IStreamConservationRecordSelection.InterviewWitness memory w
        )
    {
        bytes memory payload = StreamArtistInterviewJson.serialize(interview);
        (bytes32 hash,) =
            _publish(IStreamConservationRecordSelection.RecordKind.INTERVIEW, payload, auth);
        v.interview.status = StreamConservationRecordTypes.InterviewStatus.PRESENT;
        StreamConservationRecordTypes.Reference memory empty;
        v.interview.waiverStatement = empty;
        v.interview.record = StreamConservationRecordTypes.InterviewRecord(
            block.chainid,
            address(core),
            address(metadata),
            hash,
            StreamConservationDefinitions.INTERVIEW_SCHEMA_ID,
            StreamConservationDefinitions.INTERVIEW_PROFILE_HASH,
            StreamConservationRecordTypes.Reference(
                1,
                StreamWorkRecordDefinitions.CANON_ID,
                abi.encodePacked(keccak256(payload)),
                "ipfs://separate-interview-mirror"
            )
        );
        w.original = originals[hash];
        w.interview = interview;
        return (v, w);
    }
}
