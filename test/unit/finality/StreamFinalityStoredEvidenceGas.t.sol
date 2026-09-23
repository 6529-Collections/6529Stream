// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../smart-contracts/domains/finality/StreamFinalitySanctionArchive.sol";
import "../../../smart-contracts/domains/metadata/StreamSchemaRegistry.sol";

interface StoredEvidenceVm {
    function readFile(string calldata path) external view returns (string memory);
    function etch(address target, bytes calldata code) external;
    function mockCall(address target, bytes calldata data, bytes calldata result) external;
    function clearMockedCalls() external;
}

/// @dev Typed executing-action boundary; this cohort does not simulate Safe governance.
contract StoredEvidenceAuthority {
    bytes32 private _scope;
    bytes32 private _old;
    bytes32 private _next;
    bool private _active;

    function isStreamGovernedParameterAuthority() external pure returns (bool) {
        return true;
    }

    function currentAction()
        external
        view
        returns (bool, bytes32, uint8, bytes32, bytes32, bytes32)
    {
        return (_active, keccak256("schema action"), 1, _scope, _old, _next);
    }

    function run(
        address target,
        bytes memory data,
        bytes32 scope,
        bytes32 oldHash,
        bytes32 nextHash
    ) external {
        _active = true;
        _scope = scope;
        _old = oldHash;
        _next = nextHash;
        (bool ok, bytes memory reason) = target.call(data);
        if (!ok) assembly ("memory-safe") { revert(add(reason, 32), mload(reason)) }
        _active = false;
    }
}

/// @dev Artist facts and coverage boundaries; original SchemaRegistry/Store are real below.
contract StoredEvidenceBoundary {
    mapping(bytes4 => bytes) private _replies;
    bytes4 private _burn;
    bytes4 private _reject;

    function reply(bytes4 selector, bytes memory raw) external {
        _replies[selector] = raw;
    }

    function burn(bytes4 selector) external {
        _burn = selector;
    }

    function reject(bytes4 selector) external {
        _reject = selector;
    }

    fallback() external {
        if (msg.sig == _burn) assembly ("memory-safe") { for { } 1 { } { } }
        require(msg.sig != _reject, "current coverage rejected");
        bytes memory raw = _replies[msg.sig];
        assembly ("memory-safe") { return(add(raw, 32), mload(raw)) }
    }
}

contract StoredEvidenceHost {
    uint256 public writes;
    bytes32 public evidence;

    function accept(
        StreamFinalitySanctionArchive.Pins memory pins,
        StreamFinalityComponentExpectation[] calldata components,
        StreamFinalitySanctionArchiveProof memory proof
    ) external returns (bytes32) {
        ++writes;
        evidence = StreamFinalitySanctionArchive.requireProof(pins, components, proof);
        return evidence;
    }

    function schemas(address artifact, uint256 cap) external {
        ++writes;
        StreamFinalitySanctionSchemas.requireDefinitions(artifact, cap);
    }
}

/// @notice Actual linked stored-evidence reads under isolated bounded calls at a 30M configured maximum.
/// @dev Real schema registration/storage, typed action/Artist/coverage boundaries; no full finality capacity claim.
contract StreamFinalityStoredEvidenceGasTest {
    StoredEvidenceVm private constant vm =
        StoredEvidenceVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    StoredEvidenceAuthority private authority;
    StreamSchemaRegistry private registry;
    StreamSchemaDocumentStore private store;
    StoredEvidenceBoundary private artist;
    StoredEvidenceBoundary private artifact;
    StoredEvidenceHost private host;
    StreamFinalitySanctionArchive.Pins private pins;
    StreamFinalitySanctionArchiveProof private proof;
    StreamFinalityComponentExpectation[] private components;
    bytes private facts;
    bytes private coverage;

    function setUp() public {
        authority = new StoredEvidenceAuthority();
        registry = new StreamSchemaRegistry(address(authority));
        store = StreamSchemaDocumentStore(registry.chunkStore());
        artist = new StoredEvidenceBoundary();
        artifact = new StoredEvidenceBoundary();
        host = new StoredEvidenceHost();
        _register(
            "RAW_BYTES",
            IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
            bytes(registry.RAW_BYTES_DEFINITION())
        );
        _register(
            "6529STREAM_ARTIST_SANCTION_ARCHIVE_V1",
            IStreamSchemaRegistry.DocumentKind.SCHEMA,
            bytes(vm.readFile("docs/schemas/finality/sanction-archive-v1.schema.json"))
        );
        _register(
            "6529STREAM_ARTIST_SANCTION_ARCHIVE_ABI_V1",
            IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
            bytes(vm.readFile("docs/schemas/finality/sanction-archive-abi-v1.json"))
        );
        _register(
            "6529STREAM_ARTIST_SANCTION_CEREMONY_V1",
            IStreamSchemaRegistry.DocumentKind.SCHEMA,
            bytes(vm.readFile("docs/schemas/finality/sanction-ceremony-v1.schema.json"))
        );
        _register(
            "6529STREAM_ARTIST_SANCTION_CEREMONY_JCS_V1",
            IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
            bytes(vm.readFile("docs/schemas/finality/sanction-ceremony-jcs-v1.json"))
        );
        proof = StreamFinalitySanctionArchiveProof(
            keccak256("sanction"), keccak256("artifact"), keccak256("completion")
        );
        pins = StreamFinalitySanctionArchive.Pins(
            address(0xC0),
            address(artist),
            address(artifact),
            address(artifact).codehash,
            30_000_000
        );
        components.push(
            StreamFinalityComponentExpectation(
                keccak256("ARTIST_SANCTION"),
                address(artist),
                bytes4(0),
                bytes32(0),
                bytes32(0),
                bytes32(0),
                proof.sanctionRecordHash
            )
        );
        bytes32 schema = keccak256("6529STREAM_ARTIST_SANCTION_ARCHIVE_V1");
        bytes32 canon = keccak256("6529STREAM_ARTIST_SANCTION_ARCHIVE_ABI_V1");
        facts = abi.encode(
            IStreamArtistSanctionArchiveFacts.Facts(
                proof.sanctionRecordHash,
                keccak256("artist"),
                schema,
                canon,
                keccak256("content"),
                9000
            )
        );
        coverage = abi.encode(
            F.Coverage(
                proof.completionHash,
                proof.artifactHash,
                keccak256("artist"),
                schema,
                canon,
                keccak256("content"),
                9000,
                2,
                keccak256("family1"),
                keccak256("family2"),
                3,
                keccak256("chain")
            )
        );
        artist.reply(IStreamArtistSanctionArchiveFacts.sanctionArchiveFacts.selector, facts);
        artifact.reply(IStreamFinalityArtifactCoverage.requireArtifactCoverage.selector, coverage);
        artifact.reply(
            IStreamFinalityArtifactCoverage.schemaRegistry.selector, abi.encode(address(registry))
        );
    }

    function _register(
        string memory name,
        IStreamSchemaRegistry.DocumentKind kind,
        bytes memory raw
    ) private {
        (bytes32 hash,) = store.publishChunk(raw);
        bytes32[] memory chunks = new bytes32[](1);
        chunks[0] = hash;
        IStreamSchemaRegistry.DocumentSpec memory spec = IStreamSchemaRegistry.DocumentSpec(
            name, kind, hash, keccak256("RAW_BYTES"), 0, "ipfs://definition", uint32(raw.length)
        );
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            registry.registrationTransition(spec, chunks);
        authority.run(
            address(registry),
            abi.encodeCall(registry.registerDocument, (spec, chunks)),
            scope,
            oldHash,
            newHash
        );
    }

    function _data() private view returns (bytes memory) {
        return abi.encodeCall(host.accept, (pins, components, proof));
    }

    function _healthy(bytes memory data) private {
        uint256 before_ = host.writes();
        (bool ok, bytes memory raw) = address(host).call{ gas: 2_000_000 }(data);
        require(ok && host.writes() == before_ + 1, "healthy bounded call");
        bytes32 expected = keccak256(
            abi.encode(
                keccak256("6529STREAM_FINALITY_SANCTION_ARCHIVE_EVIDENCE_V1"),
                block.chainid,
                pins.core,
                address(host),
                address(artifact),
                proof
            )
        );
        require(
            abi.decode(raw, (bytes32)) == expected && host.evidence() == expected,
            "exact original evidence"
        );
    }

    function _reject(bytes memory data, uint256 gasAmount, bytes memory expected) private {
        uint256 before_ = host.writes();
        bytes32 saved = host.evidence();
        (bool ok, bytes memory raw) = address(host).call{ gas: gasAmount }(data);
        require(!ok && keccak256(raw) == keccak256(expected), "exact typed rejection");
        require(host.writes() == before_ && host.evidence() == saved, "rollback");
    }

    function _failed(address target) private pure returns (bytes memory) {
        return abi.encodeWithSelector(
            IStreamFinalitySanctionArchive.FinalitySanctionArchiveReadFailed.selector, target
        );
    }

    function testArchiveHighCapUsesOriginalSchemaBytesWithinSmallParent() external {
        _healthy(_data());
    }

    function testArchiveRetiredDefinitionsPreserveOriginalEvidence() external {
        bytes memory original = _data();
        _healthy(original);
        bytes32 id = keccak256("6529STREAM_ARTIST_SANCTION_ARCHIVE_V1");
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            registry.statusTransition(id, IStreamSchemaRegistry.DocumentStatus.ARCHIVED);
        authority.run(
            address(registry),
            abi.encodeCall(
                registry.setDocumentStatus, (id, IStreamSchemaRegistry.DocumentStatus.ARCHIVED)
            ),
            scope,
            oldHash,
            newHash
        );
        _healthy(original);
    }

    function testArchiveBurningFactsAndCoverageRollbackThenIdenticalRetry() external {
        bytes memory original = _data();
        artist.burn(IStreamArtistSanctionArchiveFacts.sanctionArchiveFacts.selector);
        _reject(original, 250_000, _failed(address(artist)));
        artist.burn(bytes4(0));
        _healthy(original);
        artifact.burn(IStreamFinalityArtifactCoverage.requireArtifactCoverage.selector);
        _reject(original, 1_000_000, _failed(address(artifact)));
        artifact.burn(bytes4(0));
        _healthy(original);
    }

    function testSchemasBurnerAndInsufficientReserveThenIdenticalRetry() external {
        bytes memory original = abi.encodeCall(host.schemas, (address(artifact), 30_000_000));
        _reject(original, 100_000, _failed(address(artifact)));
        bytes memory code = address(registry).code;
        vm.etch(address(registry), hex"5b600056");
        _reject(original, 1_000_000, _failed(address(registry)));
        vm.etch(address(registry), code);
        uint256 before_ = host.writes();
        (bool ok,) = address(host).call{ gas: 2_000_000 }(original);
        require(ok && host.writes() == before_ + 1, "schema exact retry");
    }

    function testArchiveInsufficientReserveThenIdenticalRetry() external {
        bytes memory original = _data();
        _reject(original, 100_000, _failed(address(artist)));
        _healthy(original);
    }

    function testArchiveExactLengthsAndCurrentCoverageStillReject() external {
        bytes memory original = _data();
        artist.reply(
            IStreamArtistSanctionArchiveFacts.sanctionArchiveFacts.selector,
            bytes.concat(facts, bytes32(0))
        );
        _reject(original, 2_000_000, _failed(address(artist)));
        artist.reply(IStreamArtistSanctionArchiveFacts.sanctionArchiveFacts.selector, facts);
        artifact.reply(
            IStreamFinalityArtifactCoverage.requireArtifactCoverage.selector, new bytes(383)
        );
        _reject(original, 2_000_000, _failed(address(artifact)));
        artifact.reply(IStreamFinalityArtifactCoverage.requireArtifactCoverage.selector, coverage);
        artifact.reject(IStreamFinalityArtifactCoverage.requireArtifactCoverage.selector);
        _reject(original, 2_000_000, _failed(address(artifact)));
        artifact.reject(bytes4(0));
        _healthy(original);
    }

    function testSchemaMaximumAndExactDefinitionHashStillReject() external {
        bytes memory original = _data();
        bytes32 id = keccak256("6529STREAM_ARTIST_SANCTION_ARCHIVE_V1");
        bytes memory data = abi.encodeCall(registry.documentBytes, (id));
        vm.mockCall(address(registry), data, new bytes(8257));
        _reject(original, 2_000_000, _failed(address(registry)));
        vm.clearMockedCalls();
        vm.mockCall(address(registry), data, abi.encode(new bytes(2574)));
        _reject(
            original,
            2_000_000,
            abi.encodeWithSelector(
                IStreamFinalitySanctionArchive.FinalitySanctionArchiveInvalid.selector
            )
        );
        vm.clearMockedCalls();
        _healthy(original);
    }

    function testArchiveInvalidAndTinyCapsRemainBounded() external {
        pins.readGas = 0;
        _reject(_data(), 2_000_000, _failed(address(artist)));
        pins.readGas = type(uint256).max;
        _reject(_data(), 2_000_000, _failed(address(artist)));
        pins.readGas = 1;
        _reject(_data(), 2_000_000, _failed(address(artist)));
        pins.readGas = 30_000_000;
        _healthy(_data());
    }
}
