// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../smart-contracts/domains/metadata/StreamCollectionMetadataV1.sol";
import "../../../smart-contracts/domains/metadata/StreamSchemaRegistry.sol";

/// @notice Actual canonical metadata/schema/bytes hosts with an explicit governance boundary.
/// @dev The artist suite and Safe remain real in the caller. Canonical Executor/Core composition
///      is separate; this fixture never substitutes an artist publication permit or candidate.
contract ConservationCanonicalPublicationFixture {
    address public immutable root;
    bytes32 private immutable _rootCodeHash;
    bool private _executing;
    bytes32 private _scope;
    bytes32 private _old;
    bytes32 private _next;
    StreamSchemaRegistry public schemas;
    StreamSchemaDocumentStore public store;
    StreamCollectionMetadataV1 public metadata;

    constructor() {
        root = msg.sender;
        _rootCodeHash = msg.sender.codehash;
    }

    function isStreamGovernedParameterAuthority() external pure returns (bool) {
        return true;
    }

    function governanceRootState() external view returns (address, bytes32, uint64) {
        return (root, _rootCodeHash, 1);
    }

    function currentAction()
        external
        view
        returns (bool, bytes32, uint8, bytes32, bytes32, bytes32)
    {
        return (
            _executing,
            _executing ? keccak256("unit metadata initialization") : bytes32(0),
            _executing ? 1 : 0,
            _scope,
            _old,
            _next
        );
    }

    function governanceAction(bytes32) external view returns (GovernanceAction memory a) {
        a.status = GovernanceActionStatus.EXECUTED;
        a.actionClass = 1;
        a.proposer = root;
        a.target = address(0xbeef); // The actual call uses currentAction, not the batch's first target.
        a.selector = 0x12345678;
    }

    function deploy(address core, address artistRegistry, bytes[] calldata definitions) external {
        require(msg.sender == root && address(metadata) == address(0), "fixture deploy once");
        schemas = new StreamSchemaRegistry(address(this));
        store = StreamSchemaDocumentStore(schemas.chunkStore());
        _register(
            "RAW_BYTES",
            IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
            bytes(schemas.RAW_BYTES_DEFINITION())
        );
        require(definitions.length == 9, "exact conservation definitions");
        string[9] memory names = [
            "RFC8785_JCS",
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
            _register(
                names[i],
                i == 0
                    ? IStreamSchemaRegistry.DocumentKind.CANONICALIZATION
                    : (i % 2 == 1
                            ? IStreamSchemaRegistry.DocumentKind.SCHEMA
                            : IStreamSchemaRegistry.DocumentKind.CATALOG),
                definitions[i]
            );
        }
        StreamCollectionMetadataV1.Configuration memory c;
        c.core = core;
        c.executor = address(this);
        c.schemas = address(schemas);
        c.artistRegistry = artistRegistry;
        c.deploymentManifestHash = keccak256("actual metadata domain fixture deployment");
        c.manifestURI = "ipfs://actual-metadata-domain-fixture";
        c.manifestHash = keccak256("actual metadata domain fixture manifest");
        c.dependencyReadGas = IStreamGasParameterHost.GasParameterConfig(
            "METADATA_DEPENDENCY_READ_GAS", 150000, 100000, 2
        );
        c.artistReadGas = IStreamGasParameterHost.GasParameterConfig(
            "METADATA_ARTIST_READ_GAS", 2000000, 1000000, 2
        );
        metadata = new StreamCollectionMetadataV1(c);
        _admit(keccak256("ARTIST_INTENT"));
        _admit(keccak256("ARTIST_STATEMENT"));
        _admit(keccak256("ARTIST_INTENT_WAIVER"));
    }

    function prepare(
        address recorder,
        bytes32 kind,
        bytes32 schema,
        bytes calldata payload,
        string calldata uri
    )
        external
        returns (IStreamPreservationRecords.CollectionRecord memory r, P.Publication memory p)
    {
        require(msg.sender == root, "fixture owner");
        (bytes32 payloadHash,) = store.publishChunk(payload);
        r.recordType = kind;
        r.subjectId = StreamMetadataSubjects.scopeSubject(
            block.chainid,
            metadata.core(),
            StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0)
        );
        r.schemaId = schema;
        r.contentHash = IStreamPreservationRecords.HashRef(
            1, abi.encode(payloadHash), keccak256("RFC8785_JCS")
        );
        r.uri = uri;
        r.effectiveAt = uint64(block.timestamp);
        p = P.Publication(
            address(metadata),
            recorder,
            1,
            r.subjectId,
            kind,
            schema,
            keccak256("RFC8785_JCS"),
            1,
            payloadHash,
            keccak256(bytes(uri)),
            r.effectiveAt,
            metadata.deriveCollectionRecordHashFor(recorder, 1, r)
        );
    }

    function _register(
        string memory name,
        IStreamSchemaRegistry.DocumentKind kind,
        bytes memory payload
    ) private {
        bytes32 hash = keccak256(payload);
        bytes32[] memory chunks = new bytes32[]((payload.length + 8191) / 8192);
        for (uint256 i; i < chunks.length; ++i) {
            uint256 size = payload.length - i * 8192;
            if (size > 8192) size = 8192;
            bytes memory chunk = new bytes(size);
            for (uint256 j; j < size; ++j) {
                chunk[j] = payload[i * 8192 + j];
            }
            (chunks[i],) = store.publishChunk(chunk);
        }
        IStreamSchemaRegistry.DocumentSpec memory spec = IStreamSchemaRegistry.DocumentSpec(
            name, kind, hash, schemas.RAW_BYTES(), 0, "", uint32(payload.length)
        );
        (bytes32 s, bytes32 o, bytes32 n) = schemas.registrationTransition(spec, chunks);
        _execute(
            address(schemas), abi.encodeCall(schemas.registerDocument, (spec, chunks)), s, o, n
        );
    }

    function _admit(bytes32 kind) private {
        (bytes32 s, bytes32 o, bytes32 n) =
            metadata.recordTypeTransition(kind, StreamRecordFamilies.ARTIST, 2);
        _execute(
            address(metadata),
            abi.encodeCall(
                metadata.admitRecordType, (kind, StreamRecordFamilies.ARTIST, uint16(2))
            ),
            s,
            o,
            n
        );
    }

    function _execute(
        address target,
        bytes memory data,
        bytes32 scope,
        bytes32 oldHash,
        bytes32 nextHash
    ) private {
        _executing = true;
        _scope = scope;
        _old = oldHash;
        _next = nextHash;
        (bool ok, bytes memory result) = target.call(data);
        if (!ok) assembly ("memory-safe") { revert(add(result, 32), mload(result)) }
        _executing = false;
        _scope = 0;
        _old = 0;
        _next = 0;
    }
}
