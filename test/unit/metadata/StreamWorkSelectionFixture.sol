// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamCollectionMetadataV1.t.sol";
import "../../../smart-contracts/domains/metadata/StreamWorkRecordSelection.sol";

interface WorkSelectionVm {
    function mockCall(address target, bytes calldata input, bytes calldata output) external;
    function clearMockedCalls() external;
}

/// @dev Explicit typed artist-owner response fixtures; no real op24 signature execution claim.
contract WorkSelectionOwnerBoundary {
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
            0,
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

contract WorkSelectionCoordinatorBoundary {
    T.SuiteConfiguration private suite;
    uint256 public deploymentChainId = block.chainid;

    function setSuite(T.SuiteConfiguration memory value) external {
        suite = value;
    }

    function suiteConfiguration() external view returns (T.SuiteConfiguration memory) {
        return suite;
    }
}

contract WorkSelectionFacadeBoundary {
    address public core;
    address public operationCoordinator;
    address public currentSigner;
    WorkSelectionOwnerBoundary public publications;

    constructor(address c, address coordinator, WorkSelectionOwnerBoundary owner) {
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
        require(hash == p.candidateRecordHash && kind == 8, "actual WORK host candidate");
        return r.evidence;
    }
}

abstract contract WorkSelectionFixture is CollectionMetadataV1Fixture {
    WorkSelectionVm internal constant workVm =
        WorkSelectionVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    StreamWorkRecordSelection internal selection;
    WorkSelectionFacadeBoundary internal facade;
    WorkSelectionCoordinatorBoundary internal coordinator;
    WorkSelectionOwnerBoundary internal identityOwner;
    WorkSelectionOwnerBoundary internal bindingOwner;
    WorkSelectionOwnerBoundary internal attributionOwner;
    bytes32 internal constant WORK = keccak256("WORK_DESCRIPTION");
    bytes32 internal constant ARTIST_ID = keccak256("registered artist");
    bytes32 internal constant BINDING = keccak256("accepted binding");
    bytes32 internal constant IDENTITY = keccak256("immutable identity registration");
    address internal constant ORIGINAL = address(0xa47157);
    address internal constant RELAYER = address(0xde11);
    uint256 private publicationNonce;
    string internal registrationURI;
    uint8 internal publicationAuthorityClass = 1;
    mapping(bytes32 => IStreamPreservationRecords.CollectionRecord) internal originals;

    modifier ready() {
        _prepare();
        _;
    }

    function _prepare() internal {
        coordinator = new WorkSelectionCoordinatorBoundary();
        identityOwner = new WorkSelectionOwnerBoundary();
        bindingOwner = new WorkSelectionOwnerBoundary();
        attributionOwner = new WorkSelectionOwnerBoundary();
        facade =
            new WorkSelectionFacadeBoundary(address(core), address(coordinator), attributionOwner);
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
        c.manifestURI = "ipfs://work-test-metadata";
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
            "STREAM_WORK_DESCRIPTION_V1",
            IStreamSchemaRegistry.DocumentKind.SCHEMA,
            bytes(vm.readFile("schemas/records/STREAM_WORK_DESCRIPTION_V1.json")),
            schemas.RAW_BYTES()
        );
        _registerDocument(
            "STREAM_WORK_DESCRIPTION_JSON_PROFILE_V1",
            IStreamSchemaRegistry.DocumentKind.CATALOG,
            bytes(vm.readFile("schemas/records/STREAM_WORK_DESCRIPTION_JSON_PROFILE_V1.json")),
            schemas.RAW_BYTES()
        );
        _registerDocument(
            "STREAM_WORK_FORMAT_CATALOG_V1",
            IStreamSchemaRegistry.DocumentKind.SCHEMA,
            bytes(vm.readFile("schemas/records/STREAM_WORK_FORMAT_CATALOG_V1.json")),
            schemas.RAW_BYTES()
        );
        _registerDocument(
            "STREAM_WORK_FORMAT_CATALOG_JSON_PROFILE_V1",
            IStreamSchemaRegistry.DocumentKind.CATALOG,
            bytes(vm.readFile("schemas/records/STREAM_WORK_FORMAT_CATALOG_JSON_PROFILE_V1.json")),
            schemas.RAW_BYTES()
        );
        _admit(WORK, StreamRecordFamilies.CURATOR, 0x010a);
        _grant(1, StreamRecordFamilies.CURATOR, 3, address(this), true);
        selection =
            new StreamWorkRecordSelection(address(core), address(metadata), address(schemas));
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

    function _named() internal view returns (StreamWorkRecordTypes.Description memory d) {
        d.subjectId = subject;
        d.profileHash = StreamWorkRecordDefinitions.PROFILE_HASH;
        d.full.title = "Exact title";
        d.full.creator.kind = StreamWorkRecordTypes.CreatorKind.NAMED;
        d.full.creator.name = "Declared creator";
        d.full.creation.start = 20240229;
        d.full.medium = "Generative instructions";
        d.full.measurements.kind = StreamWorkRecordTypes.MeasurementKind.DIMENSIONLESS_GENERATIVE;
        d.full.creditLine = "Exact credit";
    }

    function _bound(uint64 generation, bytes32 bindingHash, uint8 state) internal {
        T.Binding memory b = T.Binding(
            ARTIST_ID, ORIGINAL, IDENTITY, bindingHash, generation, 0, 0, 0, address(this), true
        );
        bindingOwner.setBinding(b, state);
        attributionOwner.setBinding(b, state);
        identityOwner.setIdentity(ORIGINAL, 1, 1, IDENTITY);
        facade.setSigner(ORIGINAL);
    }

    function _artistDescription()
        internal
        view
        returns (StreamWorkRecordTypes.Description memory d)
    {
        d = _named();
        d.full.creator = StreamWorkRecordTypes.Creator(
            StreamWorkRecordTypes.CreatorKind.ARTIST, ARTIST_ID, 1, BINDING, ""
        );
    }

    function _absence(bytes32 predecessor)
        internal
        view
        returns (StreamWorkRecordTypes.Description memory d)
    {
        d.subjectId = subject;
        d.profileHash = StreamWorkRecordDefinitions.PROFILE_HASH;
        d.predecessor = predecessor;
        d.form = StreamWorkRecordTypes.Form.DESCRIPTION_ABSENT;
        d.absence = StreamWorkRecordTypes.Absence("Explicit authored absence", 20260912);
    }

    function _workRecord(bytes memory payload)
        internal
        view
        returns (IStreamPreservationRecords.CollectionRecord memory r)
    {
        r = _record(WORK, payload);
        r.schemaId = StreamWorkRecordDefinitions.SCHEMA_ID;
        r.contentHash.canonicalizationId = StreamWorkRecordDefinitions.CANON_ID;
    }

    function _curatorPublish(StreamWorkRecordTypes.Description memory d)
        internal
        returns (bytes32)
    {
        bytes memory payload = StreamWorkRecordJson.serialize(d);
        IStreamPreservationRecords.CollectionRecord memory r = _workRecord(payload);
        bytes32 hash = metadata.recordCollectionRecordWithPayload(1, r, payload);
        originals[hash] = r;
        return hash;
    }

    function _artistPublish(StreamWorkRecordTypes.Description memory d)
        internal
        returns (bytes32 hash, bytes32 authorization)
    {
        bytes memory payload = StreamWorkRecordJson.serialize(d);
        IStreamPreservationRecords.CollectionRecord memory r = _workRecord(payload);
        P.Publication memory p = _publication(ORIGINAL, r);
        authorization = keccak256(abi.encode("fixture executed op24", ++publicationNonce, p));
        P.Evidence memory e = P.Evidence(
            authorization,
            ARTIST_ID,
            BINDING,
            1,
            ORIGINAL,
            publicationAuthorityClass,
            1,
            uint64(block.timestamp),
            keccak256(abi.encode(p))
        );
        attributionOwner.savePublication(
            IStreamArtistRecordPublicationOwner.Record(p, e, address(metadata).codehash)
        );
        hash = metadata.recordArtistCollectionRecordWithPayload(
            ORIGINAL, 1, r, payload, authorization
        );
        originals[hash] = r;
        require(hash == p.candidateRecordHash, "literal original record hash");
    }

    function _witness(bytes32 hash, StreamWorkRecordTypes.Description memory d)
        internal
        view
        returns (IStreamWorkRecordSelection.Witness memory w)
    {
        // A local exact fixture copy avoids calling any dependency after an expectRevert.
        w.original = originals[hash];
        w.description = d;
    }
}
