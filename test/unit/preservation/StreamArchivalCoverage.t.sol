// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../smart-contracts/domains/preservation/StreamArchivalCoverage.sol";
import "../../../smart-contracts/domains/preservation/StreamArweaveCheckpointVerifier.sol";
import "../../../smart-contracts/domains/governance/StreamRoleRegistry.sol";
import "../../../smart-contracts/domains/metadata/StreamSchemaDocumentStore.sol";
import "../../../smart-contracts/domains/preservation/StreamFinalityArtifactCoverage.sol";
import "../../../smart-contracts/domains/finality/StreamFinalityHashes.sol";
import "../../../smart-contracts/interfaces/stream/finality/StreamFinalityEvidenceTypes.sol";
import "../../helpers/OfficialSafeFixture.sol";

interface CoverageTestVm {
    struct Log {
        bytes32[] topics;
        bytes data;
        address emitter;
    }
    function warp(uint256 timestamp) external;
    function etch(address target, bytes calldata code) external;
    function getNonce(address target) external view returns (uint64);
    function computeCreateAddress(address deployer, uint256 nonce) external pure returns (address);
    function recordLogs() external;
    function getRecordedLogs() external returns (Log[] memory);
    function prank(address actor) external;
    function expectRevert(bytes calldata errorData) external;
    function parseJsonUint(string calldata json, string calldata key)
        external
        pure
        returns (uint256);
}

/// @dev Governance/Core/facade context doubles; actual RoleRegistry and proof hosts are deployed below.
contract CoverageGovernanceFixture {
    address public roleRegistry;
    bytes32 private _scope;
    bytes32 private _old;
    bytes32 private _new;
    bool private _executing;

    function bindRoles(address roles) external {
        roleRegistry = roles;
    }

    function isStreamGovernedParameterAuthority() external pure returns (bool) {
        return true;
    }

    function currentAction()
        external
        view
        returns (bool, bytes32, uint8, bytes32, bytes32, bytes32)
    {
        return (
            _executing,
            _executing ? keccak256(abi.encode(_scope, _old, _new)) : bytes32(0),
            _executing ? 1 : 0,
            _scope,
            _old,
            _new
        );
    }

    function execute(
        address target,
        bytes memory data,
        bytes32 scope,
        bytes32 oldHash,
        bytes32 newHash
    ) external returns (bytes memory out) {
        _executing = true;
        _scope = scope;
        _old = oldHash;
        _new = newHash;
        bool ok;
        (ok, out) = target.call(data);
        if (!ok) assembly ("memory-safe") { revert(add(out, 32), mload(out)) }
        _executing = false;
        _scope = 0;
        _old = 0;
        _new = 0;
    }
}

contract CoverageModuleFixture {
    address public immutable governanceExecutor;

    constructor(address e) {
        governanceExecutor = e;
    }
}

contract CoverageCoreFixture {
    mapping(bytes32 => address) public pointers;

    function set(bytes32 kind, address target) external {
        pointers[kind] = target;
    }

    function getSatellitePointer(bytes32 kind)
        external
        view
        returns (address, bytes32, bool, bytes32, bytes4, address, uint8, bytes32, bytes32, uint64)
    {
        address a = pointers[kind];
        return (a, a.codehash, false, kind, bytes4(0), address(0), 1, bytes32(0), bytes32(0), 1);
    }
}

contract CoverageArtistFixture {
    address public immutable core;
    address public immutable archivalCoverage;

    constructor(address c, address p) {
        core = c;
        archivalCoverage = p;
    }
}

/// @dev Deliberate fixed-read adversary; healthy mode is an explicit facade-boundary fixture.
contract CoverageReadAdversary {
    address private immutable _core;
    address private immutable _provider;
    uint8 public mode;

    constructor(address c, address p) {
        _core = c;
        _provider = p;
    }

    function setMode(uint8 next) external {
        mode = next;
    }

    function core() external view returns (address) {
        uint8 m = mode;
        if (m == 1) {
            assembly ("memory-safe") {
                mstore(0, 0)
                return(0, 31)
            }
        }
        if (m == 2) {
            assembly ("memory-safe") {
                mstore(0, 0)
                mstore(32, 0)
                return(0, 64)
            }
        }
        if (m == 3) assembly ("memory-safe") { for { } 1 { } { } }
        if (m == 4) {
            assembly ("memory-safe") {
                mstore(0, shl(200, 1))
                return(0, 32)
            }
        }
        return _core;
    }

    function archivalCoverage() external view returns (address) {
        return _provider;
    }
}

contract ArtifactSchemaFixture {
    address public immutable chunkStore;
    address public immutable governanceAuthority;

    constructor(address store, address executor) {
        chunkStore = store;
        governanceAuthority = executor;
    }
}

contract ArtifactFinalityFixture {
    address public immutable core;
    address public immutable artifactCoverage;

    constructor(address core_, address aggregate) {
        core = core_;
        artifactCoverage = aggregate;
    }
}

contract StreamArchivalCoverageTest is OfficialSafeFixture {
    event ArtifactDeployedRuntime(address indexed target, bytes runtime);
    CoverageTestVm private constant vm =
        CoverageTestVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    StreamArchivalCoverage private host;
    StreamArweaveCheckpointVerifier private verifier;
    StreamRoleRegistry private roles;
    CoverageGovernanceFixture private governance;
    CoverageCoreFixture private core;
    address private facade;
    OfficialSafe private agentSafe;
    OfficialSafe private fixitySafe;
    uint256[] private agentKeys;
    uint256[] private fixityKeys;
    uint256 private observerA = 0x652921;
    uint256 private observerB = 0x652922;
    uint256 private secondAgentKey = 0x652925;
    bytes private payload;
    A.Envelope private terms;
    bytes32 private envelopeHash;
    bytes32 private checkpointHash;
    bytes32 private transactionId;
    bytes32 private firstFamily;
    bytes32 private secondFamily;

    function setUp() public {
        vm.warp(1_900_000_000);
        governance = new CoverageGovernanceFixture();
        roles = new StreamRoleRegistry(address(governance));
        governance.bindRoles(address(roles));
        core = new CoverageCoreFixture();
        core.set(
            keccak256("MODULE_REGISTRY"), address(new CoverageModuleFixture(address(governance)))
        );
        A.Observer[] memory observers = new A.Observer[](2);
        observers[0] = A.Observer(safeVm.addr(observerA), keccak256("observer-one"));
        observers[1] = A.Observer(safeVm.addr(observerB), keccak256("observer-two"));
        if (observers[0].account > observers[1].account) {
            (observers[0], observers[1]) = (observers[1], observers[0]);
        }
        verifier =
            new StreamArweaveCheckpointVerifier(address(governance), observers, 2, _sigConfig());
        host = new StreamArchivalCoverage(
            address(core),
            address(governance),
            address(roles),
            address(verifier),
            _sigConfig(),
            IStreamGasParameterHost.GasParameterConfig(
                "ARCHIVAL_DEPENDENCY_READ_GAS", 150000, 50000, 2
            )
        );
        // Actual construction order: provider exists before the facade reciprocal pin and Core selection.
        facade = address(new CoverageArtistFixture(address(core), address(host)));
        core.set(keccak256("ARTIST_REGISTRY"), facade);
        SafeComponents memory components = deploySafeComponents("1.4.1");
        agentKeys.push(0x652931);
        agentKeys.push(0x652932);
        fixityKeys.push(0x652933);
        fixityKeys.push(0x652934);
        agentSafe = createOfficialSafe(components, safeOwnerAddresses(agentKeys), 2, 31);
        fixitySafe = createOfficialSafe(components, safeOwnerAddresses(fixityKeys), 2, 32);
        _role(address(fixitySafe), true);
        firstFamily = _admit("arweave-family", _family("arweave-family", true, address(agentSafe)));
        secondFamily =
            _admit("ipfs-family", _family("ipfs-family", false, safeVm.addr(secondAgentKey)));
        checkpointHash = _checkpoint();
        terms = A.Envelope(
            keccak256("artist"),
            keccak256(payload),
            keccak256("6529STREAM_PUBLIC_ESTATE_EVIDENCE_V1"),
            keccak256("BINARY_EXACT_V1"),
            2,
            sha256(payload),
            uint64(payload.length),
            1,
            0
        );
        envelopeHash = host.recordEnvelope(terms, payload);
    }

    function _sigConfig() private pure returns (IStreamGasParameterHost.GasParameterConfig memory) {
        return IStreamGasParameterHost.GasParameterConfig(
            "ARCHIVAL_ERC1271_VERIFY_GAS", 400000, 90000, 2
        );
    }

    function _sign(uint256 key, bytes32 digest) private returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = safeVm.sign(key, digest);
        return abi.encodePacked(r, s, v);
    }

    function _family(string memory name, bool endowed, address agent)
        private
        view
        returns (A.Family memory f)
    {
        bytes memory salt = bytes(endowed ? "one" : "two");
        f = A.Family(
            keccak256(bytes(name)),
            endowed ? verifier.networkId() : keccak256("IPFS"),
            keccak256(bytes.concat(salt, "protocol")),
            keccak256(bytes.concat(salt, "addressing")),
            keccak256(bytes.concat(salt, "custodian")),
            keccak256(bytes.concat(salt, "funding")),
            keccak256(bytes.concat(salt, "retrieval")),
            keccak256("same jurisdiction allowed"),
            endowed ? 1 : 2,
            agent,
            endowed ? verifier.profileHash() : host.POSSESSION_PROFILE()
        );
    }

    function _admit(string memory name, A.Family memory f) private returns (bytes32 hash) {
        bytes32 scope;
        bytes32 oldHash;
        bytes32 newHash;
        (hash, scope, oldHash, newHash) = host.familyRegistrationContext(name, f);
        bytes memory result = governance.execute(
            address(host), abi.encodeCall(host.admitFamily, (name, f)), scope, oldHash, newHash
        );
        require(abi.decode(result, (bytes32)) == hash, "admission hash");
    }

    function _status(bytes32 hash, uint8 next) private {
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) = host.familyStatusContext(hash, next);
        governance.execute(
            address(host),
            abi.encodeCall(host.setFamilyStatus, (hash, next)),
            scope,
            oldHash,
            newHash
        );
    }

    function _role(address holder, bool granted) private {
        bytes32 role = keccak256("ROLE_FIXITY_OPERATOR");
        (bytes32 chain, uint64 revision) = roles.roleMutationState(role);
        (bytes32 globalChain, uint64 globalRevision) = roles.globalRoleMutationState();
        bytes32 scope = keccak256(
            abi.encode(
                keccak256("6529STREAM_ROLE_MUTATION_SCOPE_V1"),
                block.chainid,
                address(roles),
                role,
                holder
            )
        );
        bytes32 nextChain = keccak256(
            abi.encode(
                keccak256("6529STREAM_ROLE_MUTATION_V1"),
                chain,
                block.chainid,
                address(roles),
                role,
                holder,
                granted,
                revision + 1
            )
        );
        bytes32 nextGlobal = keccak256(
            abi.encode(
                keccak256("6529STREAM_GLOBAL_ROLE_MUTATION_V1"),
                globalChain,
                block.chainid,
                address(roles),
                role,
                holder,
                granted,
                globalRevision + 1
            )
        );
        bytes32 oldHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ROLE_MUTATION_STATE_V1"),
                block.chainid,
                address(roles),
                scope,
                !granted,
                chain,
                revision,
                globalChain,
                globalRevision
            )
        );
        bytes32 newHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ROLE_MUTATION_STATE_V1"),
                block.chainid,
                address(roles),
                scope,
                granted,
                nextChain,
                revision + 1,
                nextGlobal,
                globalRevision + 1
            )
        );
        governance.execute(
            address(roles),
            granted
                ? abi.encodeCall(roles.grantRole, (role, holder))
                : abi.encodeCall(roles.revokeRole, (role, holder)),
            scope,
            oldHash,
            newHash
        );
    }

    function _checkpoint() private returns (bytes32) {
        string memory json =
            safeVm.readFile("test/fixtures/preservation/arweave-single-chunk-v1.json");
        payload = safeVm.parseJsonBytes(json, ".second.payload");
        A.Checkpoint memory c;
        c.networkId = verifier.networkId();
        c.blockHash = new bytes(48);
        c.blockHash[0] = 0x65;
        c.blockHeight = 1500000;
        c.transactionRoot = bytes32(safeVm.parseJsonBytes(json, ".second.transactionRoot"));
        c.blockDataSize = vm.parseJsonUint(json, ".second.blockDataSize");
        c.transactionId = keccak256("synthetic network fixture");
        transactionId = c.transactionId;
        c.dataRoot = bytes32(safeVm.parseJsonBytes(json, ".second.dataRoot"));
        c.dataSize = uint64(payload.length);
        c.transactionStart = vm.parseJsonUint(json, ".second.transactionStart");
        c.transactionEnd = vm.parseJsonUint(json, ".second.transactionEnd");
        c.observedAt = uint64(block.timestamp);
        c.configurationHash = verifier.configurationHash();
        bytes32 digest = verifier.checkpointDigest(c);
        A.ObserverProof[] memory p = new A.ObserverProof[](2);
        p[0] = A.ObserverProof(safeVm.addr(observerA), _sign(observerA, digest));
        p[1] = A.ObserverProof(safeVm.addr(observerB), _sign(observerB, digest));
        if (p[0].account > p[1].account) (p[0], p[1]) = (p[1], p[0]);
        return verifier.recordCheckpoint(
            c,
            safeVm.parseJsonBytes(json, ".second.transactionPath"),
            safeVm.parseJsonBytes(json, ".second.dataPath"),
            payload,
            p
        );
    }

    function _receiptTerms(bool endowed, uint256 nonce)
        private
        returns (A.ReceiptTerms memory r, bytes memory id)
    {
        id = endowed
            ? abi.encodePacked(transactionId)
            : abi.encodePacked(bytes4(0x01551220), terms.payloadDigest);
        r = A.ReceiptTerms(
            envelopeHash,
            endowed ? firstFamily : secondFamily,
            keccak256(id),
            keccak256(bytes(endowed ? "CONTENT_ADDRESSED_INCLUSION" : "ATTESTED_POSSESSION")),
            endowed ? verifier.profileHash() : host.POSSESSION_PROFILE(),
            endowed ? checkpointHash : bytes32(0),
            endowed ? address(agentSafe) : safeVm.addr(secondAgentKey),
            uint64(block.timestamp),
            nonce,
            uint64(block.timestamp + 1 days)
        );
        if (!endowed) {
            r.proofRecordHash = host.possessionHash(
                A.Possession(
                    r.envelopeHash,
                    r.familyRecordHash,
                    r.storageIdentifierHash,
                    r.writer,
                    r.observedAt
                )
            );
        }
    }

    function _recordReceipt(bool endowed, uint256 nonce) private returns (bytes32 hash) {
        (A.ReceiptTerms memory r, bytes memory id) = _receiptTerms(endowed, nonce);
        hash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARCHIVAL_RECEIPT_RECORD_V1"), block.chainid, address(host), r
            )
        );
        if (endowed) {
            require(
                executeSafe(
                    agentSafe,
                    agentKeys,
                    address(host),
                    0,
                    abi.encodeCall(host.recordReceipt, (r, id, bytes(""))),
                    0
                ),
                "actual Safe writer"
            );
        } else {
            require(
                host.recordReceipt(r, id, _sign(secondAgentKey, host.receiptDigest(r))) == hash,
                "relayed receipt"
            );
        }
        (A.ReceiptTerms memory saved,,) = host.receipt(hash);
        require(saved.writer == r.writer, "authenticated writer retained");
    }

    function _fixityTerms(bytes32 receiptHash, uint8 outcome)
        private
        view
        returns (A.FixityTerms memory f)
    {
        (A.ReceiptTerms memory r,,) = host.receipt(receiptHash);
        bytes32 prior = host.latestFixity(receiptHash);
        f = A.FixityTerms(
            receiptHash,
            r.envelopeHash,
            r.familyRecordHash,
            terms.payloadDigest,
            outcome == 1 ? terms.payloadDigest : keccak256("corrupt"),
            uint64(payload.length),
            uint64(block.timestamp),
            outcome,
            keccak256(abi.encode("audit", prior, outcome)),
            prior,
            0,
            address(fixitySafe),
            uint256(prior),
            uint64(block.timestamp + 1 days)
        );
    }

    function _recordFixity(bytes32 receiptHash, uint8 outcome, bool repair)
        private
        returns (bytes32 hash)
    {
        A.FixityTerms memory f = _fixityTerms(receiptHash, outcome);
        if (repair) f.repairReportHash = keccak256("repair report");
        hash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARCHIVAL_FIXITY_RECORD_V1"), block.chainid, address(host), f
            )
        );
        require(
            executeSafe(
                fixitySafe,
                fixityKeys,
                address(host),
                0,
                abi.encodeCall(host.recordFixity, (f, bytes(""))),
                0
            ),
            "actual Safe fixity operator"
        );
        require(host.latestFixity(receiptHash) == hash, "fixity current head");
    }

    function _covered() private returns (bytes32 first, bytes32 second, bytes32 hash) {
        first = _recordReceipt(true, 0);
        second = _recordReceipt(false, 0);
        _recordFixity(first, 1, false);
        _recordFixity(second, 1, false);
        hash = host.recordCoverage(first, second);
    }

    function _chunkTerms() private view returns (A.Envelope memory e) {
        e = terms;
        e.schemaId = keccak256("6529STREAM_FINALITY_ARTIFACT_CHUNK_V1");
    }

    function _artifactHost()
        private
        returns (StreamFinalityArtifactCoverage aggregate, StreamSchemaDocumentStore store)
    {
        store = new StreamSchemaDocumentStore();
        ArtifactSchemaFixture schema =
            new ArtifactSchemaFixture(address(store), address(governance));
        address predicted =
            vm.computeCreateAddress(address(this), uint256(vm.getNonce(address(this))) + 1);
        aggregate = new StreamFinalityArtifactCoverage(
            address(core),
            address(host),
            address(schema),
            address(store),
            predicted,
            address(governance),
            IStreamGasParameterHost.GasParameterConfig(
                "FINALITY_ARTIFACT_DEPENDENCY_READ_GAS", 500000, 300000, 2
            )
        );
        ArtifactFinalityFixture finality =
            new ArtifactFinalityFixture(address(core), address(aggregate));
        require(address(finality) == predicted, "actual fixed counterpart CREATE");
        core.set(keccak256("ARTWORK_FINALITY_REGISTRY"), address(finality));
        emit ArtifactDeployedRuntime(address(aggregate), address(aggregate).code);
        emit ArtifactDeployedRuntime(address(finality), address(finality).code);
        emit ArtifactDeployedRuntime(address(store), address(store).code);
        emit ArtifactDeployedRuntime(address(schema), address(schema).code);
        emit ArtifactDeployedRuntime(address(host), address(host).code);
        emit ArtifactDeployedRuntime(
            address(StreamFinalityHashes), address(StreamFinalityHashes).code
        );
    }

    function _artifactTerms(uint32 repeats) private view returns (F.Artifact memory a) {
        bytes memory whole;
        a.artistId = terms.artistId;
        a.schemaId = keccak256("TEST_EXECUTION_ENVIRONMENT_BYTES_V1");
        a.canonicalizationId = keccak256("BINARY_EXACT_V1");
        a.hashAlgorithm = 1;
        a.chunkHashes = new bytes32[](repeats);
        a.chunkLengths = new uint32[](repeats);
        for (uint32 i; i < repeats; ++i) {
            whole = bytes.concat(whole, payload);
            a.chunkHashes[i] = keccak256(payload);
            a.chunkLengths[i] = uint32(payload.length);
        }
        a.contentHash = keccak256(whole);
        a.byteLength = uint64(whole.length);
    }

    function _canonicalChunk(StreamSchemaDocumentStore store) private returns (address pointer) {
        (, pointer) = store.publishChunk(payload);
        terms = _chunkTerms();
        envelopeHash = host.recordChunkEnvelope(terms, pointer);
    }

    function testArtifactWholeBytesActualCoverageAndHistoricalReadAfterSelectionChange() public {
        (StreamFinalityArtifactCoverage aggregate, StreamSchemaDocumentStore store) =
            _artifactHost();
        _canonicalChunk(store);
        F.Artifact memory a = _artifactTerms(1);
        bytes32 artifactHash = aggregate.recordArtifact(a);
        require(
            artifactHash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_FINALITY_ARTIFACT_V1"),
                        block.chainid,
                        address(aggregate),
                        address(core),
                        a
                    )
                ),
            "independent artifact preimage"
        );
        (,, bytes32 covered) = _covered();
        bytes32 plan = aggregate.beginCoverage(artifactHash, firstFamily, secondFamily);
        bytes32 completed = aggregate.coverNextChunk(plan, 0, covered);
        F.Coverage memory saved =
            aggregate.requireArtifactCoverage(completed, a.artistId, artifactHash);
        require(
            saved.contentHash == keccak256(payload) && saved.byteLength == payload.length
                && saved.chunkCount == 1 && saved.firstFamilyRecordHash == firstFamily
                && saved.secondFamilyRecordHash == secondFamily,
            "whole bytes and actual pair"
        );
        address actualFinality = aggregate.finalityRegistry();
        core.set(keccak256("ARTWORK_FINALITY_REGISTRY"), address(0));
        require(
            keccak256(abi.encode(aggregate.coverage(completed))) == keccak256(abi.encode(saved)),
            "historical evidence independent of replacement"
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamFinalityArtifactCoverage.ArtifactComponentChanged.selector, address(0)
            )
        );
        aggregate.requireArtifactCoverage(completed, a.artistId, artifactHash);
        core.set(keccak256("ARTWORK_FINALITY_REGISTRY"), actualFinality);
        require(
            aggregate.requireArtifactCoverage(completed, a.artistId, artifactHash).completionHash
                == completed,
            "same current evidence restored"
        );
    }

    function testArtifactAlternatePointerCoverageCannotConsumeCanonicalIndex() public {
        (StreamFinalityArtifactCoverage aggregate, StreamSchemaDocumentStore store) =
            _artifactHost();
        terms = _chunkTerms();
        address alternate = SSTORE2.write(payload);
        envelopeHash = host.recordChunkEnvelope(terms, alternate);
        (,, bytes32 wrongCoverage) = _covered();
        _canonicalChunk(store);
        bytes32 artifactHash = aggregate.recordArtifact(_artifactTerms(1));
        bytes32 plan = aggregate.beginCoverage(artifactHash, firstFamily, secondFamily);
        bytes32 before_ = keccak256(abi.encode(aggregate.coveragePlan(plan)));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamFinalityArtifactCoverage.InvalidArtifactCoverage.selector, plan
            )
        );
        aggregate.coverNextChunk(plan, 0, wrongCoverage);
        require(
            keccak256(abi.encode(aggregate.coveragePlan(plan))) == before_, "failed index unchanged"
        );
        bytes32 first = _recordReceipt(true, 1);
        bytes32 second = _recordReceipt(false, 1);
        _recordFixity(first, 1, false);
        _recordFixity(second, 1, false);
        bytes32 correctCoverage = host.recordCoverage(first, second);
        bytes32 completed = aggregate.coverNextChunk(plan, 0, correctCoverage);
        require(
            aggregate.coverage(completed).artifactHash == artifactHash,
            "same canonical plan healthy retry"
        );
    }

    function _largeCheckpoint() private {
        payload = new bytes(8192);
        for (uint256 i; i < payload.length; ++i) {
            payload[i] = bytes1(uint8(i));
        }
        A.Checkpoint memory c;
        c.networkId = verifier.networkId();
        c.blockHash = new bytes(48);
        c.blockHash[0] = 0x66;
        c.blockHeight = 1500001;
        c.dataRoot = sha256(
            abi.encodePacked(
                sha256(abi.encodePacked(sha256(payload))),
                sha256(abi.encodePacked(uint256(payload.length)))
            )
        );
        c.transactionRoot = sha256(
            abi.encodePacked(
                sha256(abi.encodePacked(c.dataRoot)),
                sha256(abi.encodePacked(uint256(payload.length)))
            )
        );
        c.blockDataSize = payload.length;
        c.transactionId = keccak256("synthetic full8192 transaction");
        c.dataSize = uint64(payload.length);
        c.transactionEnd = payload.length;
        c.observedAt = uint64(block.timestamp);
        c.configurationHash = verifier.configurationHash();
        bytes32 digest = verifier.checkpointDigest(c);
        A.ObserverProof[] memory p = new A.ObserverProof[](2);
        p[0] = A.ObserverProof(safeVm.addr(observerA), _sign(observerA, digest));
        p[1] = A.ObserverProof(safeVm.addr(observerB), _sign(observerB, digest));
        if (p[0].account > p[1].account) (p[0], p[1]) = (p[1], p[0]);
        checkpointHash = verifier.recordCheckpoint(
            c,
            abi.encodePacked(c.dataRoot, uint256(payload.length)),
            abi.encodePacked(sha256(payload), uint256(payload.length)),
            payload,
            p
        );
        transactionId = c.transactionId;
        terms.evidenceHash = keccak256(payload);
        terms.payloadDigest = sha256(payload);
        terms.byteSize = uint64(payload.length);
    }

    function testArtifactRepeatedPartsOrderedProgressAndOldEpochRestart() public {
        (StreamFinalityArtifactCoverage aggregate, StreamSchemaDocumentStore store) =
            _artifactHost();
        _largeCheckpoint();
        _canonicalChunk(store);
        F.Artifact memory a = _artifactTerms(2);
        bytes32 artifactHash = aggregate.recordArtifact(a);
        (bytes32 first, bytes32 second, bytes32 covered) = _covered();
        bytes32 plan = aggregate.beginCoverage(artifactHash, firstFamily, secondFamily);
        require(
            aggregate.coverNextChunk(plan, 0, covered) == 0, "one chunk cannot claim whole artifact"
        );
        F.Plan memory savedPartial = aggregate.coveragePlan(plan);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamFinalityArtifactCoverage.ArtifactCoverageIndex.selector, uint32(1), uint32(0)
            )
        );
        aggregate.coverNextChunk(plan, 0, covered);
        vm.warp(block.timestamp + 1);
        _recordFixity(first, 1, false);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamFinalityArtifactCoverage.ArtifactCoverageStale.selector, plan
            )
        );
        aggregate.coverNextChunk(plan, 1, covered);
        require(
            keccak256(abi.encode(aggregate.coveragePlan(plan)))
                == keccak256(abi.encode(savedPartial)),
            "old partial immutable"
        );
        bytes32 currentCoverage = host.recordCoverage(first, second);
        bytes32 fresh = aggregate.beginCoverage(artifactHash, firstFamily, secondFamily);
        require(
            fresh != plan && aggregate.coveragePlan(fresh).nextIndex == 0,
            "new epoch restarts ordered proof"
        );
        aggregate.coverNextChunk(fresh, 0, currentCoverage);
        bytes32 completion = aggregate.coverNextChunk(fresh, 1, currentCoverage);
        require(
            aggregate.requireArtifactCoverage(completion, a.artistId, artifactHash).chunkCount == 2,
            "equal bytes in distinct positions are legitimate"
        );
        _status(secondFamily, 2);
        _status(secondFamily, 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamFinalityArtifactCoverage.ArtifactCoverageStale.selector, fresh
            )
        );
        aggregate.requireArtifactCoverage(completion, a.artistId, artifactHash);
        require(
            aggregate.coverage(completion).completionHash == completion,
            "historical completion retained"
        );
    }

    function testArtifactCanonicalPartitionWholeHashAndSafeAdmission() public {
        (StreamFinalityArtifactCoverage aggregate, StreamSchemaDocumentStore store) =
            _artifactHost();
        store.publishChunk(payload);
        F.Artifact memory a = _artifactTerms(2);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamFinalityArtifactCoverage.InvalidArtifact.selector)
        );
        aggregate.recordArtifact(a);
        a = _artifactTerms(1);
        bytes32 actualHash = a.contentHash;
        a.contentHash = keccak256("only a manifest cannot prove whole bytes");
        vm.expectRevert(
            abi.encodeWithSelector(IStreamFinalityArtifactCoverage.InvalidArtifact.selector)
        );
        aggregate.recordArtifact(a);
        a.contentHash = actualHash;
        bytes32 hash = keccak256(
            abi.encode(
                keccak256("6529STREAM_FINALITY_ARTIFACT_V1"),
                block.chainid,
                address(aggregate),
                address(core),
                a
            )
        );
        uint256 nonce = agentSafe.nonce();
        require(
            executeSafe(
                agentSafe,
                agentKeys,
                address(aggregate),
                0,
                abi.encodeCall(aggregate.recordArtifact, (a)),
                0
            ),
            "actual Safe permissionless bytes admission"
        );
        require(
            agentSafe.nonce() == nonce + 1 && aggregate.artifact(hash).contentHash == actualHash,
            "same exact candidate succeeds"
        );
    }

    /// @dev Unit candidate preimages, not actual metadata or a completed finality ceremony.
    function _candidateBytes(StreamFinalityArtifactCoverage aggregate, bytes32 completion)
        private
        view
        returns (bytes memory)
    {
        F.Coverage memory saved = aggregate.coverage(completion);
        StreamFinalityScope memory scope =
            StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0);
        StreamFinalityScopeInputs memory inputs;
        inputs.rootRecordHash = keccak256("fixed unit root");
        inputs.renderCriticalEvidenceHash = saved.artifactHash;
        inputs.bundleCoverageHash = keccak256(abi.encode(saved));
        bytes32 inputsHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_FINALITY_SCOPE_INPUTS_V1"),
                block.chainid,
                address(core),
                address(this),
                scope,
                inputs
            )
        );
        StreamFinalityManifestRef memory manifest = StreamFinalityManifestRef(
            "ipfs://unit-finality-manifest",
            keccak256("ipfs://unit-finality-manifest"),
            keccak256(abi.encode(inputsHash, inputs)),
            keccak256("unit finality schema"),
            keccak256("unit canonicalization")
        );
        bytes32 subject = StreamFinalityHashes.sanctionSubjectHash(
            address(core),
            scope,
            keccak256("fixed core facts"),
            keccak256("fixed non-sanction components"),
            manifest
        );
        return abi.encode(inputs, inputsHash, manifest, subject);
    }

    function testArtifactValidationRefreshKeepsCompletionAndCandidateCommitmentsExact() public {
        (StreamFinalityArtifactCoverage aggregate, StreamSchemaDocumentStore store) =
            _artifactHost();
        _canonicalChunk(store);
        bytes32 artifactHash = aggregate.recordArtifact(_artifactTerms(1));
        (bytes32 first, bytes32 second, bytes32 covered) = _covered();
        bytes32 plan = aggregate.beginCoverage(artifactHash, firstFamily, secondFamily);
        bytes32 completion = aggregate.coverNextChunk(plan, 0, covered);
        bytes32 immutableCompletion = keccak256(abi.encode(aggregate.coverage(completion)));
        bytes32 candidate = keccak256(_candidateBytes(aggregate, completion));
        F.Validation memory original = aggregate.currentCoverageValidation(completion);
        vm.warp(block.timestamp + 1);
        _recordFixity(first, 1, false);
        bytes32 currentCoverage = host.recordCoverage(first, second);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamFinalityArtifactCoverage.ArtifactCoverageStale.selector, plan
            )
        );
        aggregate.requireArtifactCoverage(completion, terms.artistId, artifactHash);
        bytes32 refreshed = aggregate.refreshNextChunk(completion, 0, currentCoverage);
        require(
            refreshed != 0 && refreshed != original.validationRecordHash
                && aggregate.currentCoverageValidation(completion).validationEpoch
                    == host.coverageValidationEpoch(),
            "fresh cache is separately visible"
        );
        require(
            keccak256(abi.encode(aggregate.coverageValidationRecord(original.validationRecordHash)))
                == keccak256(abi.encode(original)),
            "old validation history immutable"
        );
        require(
            aggregate.requireArtifactCoverage(completion, terms.artistId, artifactHash)
                    .completionHash == completion
                && keccak256(abi.encode(aggregate.coverage(completion))) == immutableCompletion
                && keccak256(_candidateBytes(aggregate, completion)) == candidate,
            "healthy same receipt refresh preserves input manifest and sanction commitments"
        );
        bytes32 unrelated = _recordReceipt(true, 17);
        _recordFixity(unrelated, 1, false);
        require(
            aggregate.currentCoverageValidation(completion).validationEpoch
                == host.coverageValidationEpoch(),
            "unrelated initial fixity does not invalidate"
        );
        vm.warp(block.timestamp + 1);
        _recordFixity(unrelated, 1, false);
        aggregate.refreshNextChunk(completion, 0, currentCoverage);
        require(
            aggregate.requireArtifactCoverage(completion, terms.artistId, artifactHash)
                    .completionHash == completion
                && keccak256(_candidateBytes(aggregate, completion)) == candidate,
            "unrelated replacement refresh leaves original candidate exact"
        );
    }

    function testArtifactCurrentValidationRequiresEveryPartAndHealthyExactReceipts() public {
        (StreamFinalityArtifactCoverage aggregate, StreamSchemaDocumentStore store) =
            _artifactHost();
        _largeCheckpoint();
        _canonicalChunk(store);
        bytes32 artifactHash = aggregate.recordArtifact(_artifactTerms(2));
        (bytes32 first, bytes32 second, bytes32 covered) = _covered();
        bytes32 plan = aggregate.beginCoverage(artifactHash, firstFamily, secondFamily);
        aggregate.coverNextChunk(plan, 0, covered);
        bytes32 completion = aggregate.coverNextChunk(plan, 1, covered);
        bytes32 priorValidation =
            aggregate.currentCoverageValidation(completion).validationRecordHash;
        vm.warp(block.timestamp + 1);
        _recordFixity(first, 2, false);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamFinalityArtifactCoverage.ArtifactReadFailed.selector, address(host)
            )
        );
        aggregate.refreshNextChunk(completion, 0, covered);
        require(
            aggregate.currentCoverageValidation(completion).validationRecordHash == priorValidation,
            "bad fixity cannot update cache"
        );
        vm.warp(block.timestamp + 1);
        _recordFixity(first, 1, true);
        bytes32 healthy = host.recordCoverage(first, second);
        require(
            aggregate.refreshNextChunk(completion, 0, healthy) == 0,
            "one part is not validation completeness"
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamFinalityArtifactCoverage.ArtifactCoverageStale.selector, plan
            )
        );
        aggregate.requireArtifactCoverage(completion, terms.artistId, artifactHash);
        vm.warp(block.timestamp + 1);
        _recordFixity(second, 1, false);
        bytes32 newest = host.recordCoverage(first, second);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamFinalityArtifactCoverage.ArtifactCoverageIndex.selector, uint32(0), uint32(1)
            )
        );
        aggregate.refreshNextChunk(completion, 1, newest);
        aggregate.refreshNextChunk(completion, 0, newest);
        bytes32 validation = aggregate.refreshNextChunk(completion, 1, newest);
        require(
            validation != 0 && validation != priorValidation
                && aggregate.requireArtifactCoverage(completion, terms.artistId, artifactHash)
                    .chunkCount == 2,
            "all exact receipt positions revalidated at same current epoch"
        );
    }

    function artifactSafeTarget(address target, bytes calldata data) external {
        require(msg.sender == address(this), "test wrapper only");
        require(executeSafe(agentSafe, agentKeys, target, 0, data, 0), "actual Safe target call");
    }

    /// @dev CALL success/nonce and ordinary static-return parity; Safe does not return target returndata.
    function _safeArtifactRead(address target, bytes memory data) private {
        (bool beforeOK, bytes memory before_) = target.staticcall(data);
        require(beforeOK, "static preparation succeeds");
        require(executeSafe(agentSafe, agentKeys, target, 0, data, 0), "actual Safe read CALL");
        (bool afterOK, bytes memory after_) = target.staticcall(data);
        require(afterOK && keccak256(before_) == keccak256(after_), "ordinary static return parity");
    }

    function testArtifactActualSafeAllTwentyEightPublicSelectors() public {
        (StreamFinalityArtifactCoverage aggregate, StreamSchemaDocumentStore store) =
            _artifactHost();
        _canonicalChunk(store);
        (bytes32 first, bytes32 second, bytes32 covered) = _covered();
        F.Artifact memory a = _artifactTerms(1);
        bytes32 artifactHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_FINALITY_ARTIFACT_V1"),
                block.chainid,
                address(aggregate),
                address(core),
                a
            )
        );
        address target = address(aggregate);
        uint256 nonce = agentSafe.nonce();
        this.artifactSafeTarget(target, abi.encodeCall(aggregate.recordArtifact, (a)));
        vm.recordLogs();
        this.artifactSafeTarget(
            target,
            abi.encodeCall(aggregate.beginCoverage, (artifactHash, firstFamily, secondFamily))
        );
        CoverageTestVm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 plan;
        uint256 matches;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter == target && logs[i].topics.length == 2) {
                plan = logs[i].topics[1];
                ++matches;
            }
        }
        require(
            matches == 1 && aggregate.coveragePlan(plan).artifactHash == artifactHash,
            "actual Safe plan"
        );
        this.artifactSafeTarget(
            target, abi.encodeCall(aggregate.coverNextChunk, (plan, uint32(0), covered))
        );
        bytes32 completion = aggregate.coveragePlan(plan).completionHash;
        require(completion != 0, "actual Safe completion");
        vm.warp(block.timestamp + 1);
        _recordFixity(first, 1, false);
        bytes32 fresh = host.recordCoverage(first, second);
        this.artifactSafeTarget(
            target, abi.encodeCall(aggregate.refreshNextChunk, (completion, uint32(0), fresh))
        );
        bytes32 validation = aggregate.currentCoverageValidation(completion).validationRecordHash;
        bytes32 gasId = keccak256("6529STREAM_GGP_FINALITY_ARTIFACT_DEPENDENCY_READ_GAS");
        bytes[] memory reads = new bytes[](23);
        reads[0] = abi.encodeCall(aggregate.CHUNK_BYTES, ());
        reads[1] = abi.encodeCall(aggregate.FAILURE_CLASS_FAIL_CLOSED_PRECHECK, ());
        reads[2] = abi.encodeCall(aggregate.FAILURE_CLASS_FORWARDING_CAP, ());
        reads[3] = abi.encodeCall(aggregate.FAILURE_CLASS_MIN_GAS_GATE, ());
        reads[4] = abi.encodeCall(aggregate.FAILURE_CLASS_NONE, ());
        reads[5] = abi.encodeCall(aggregate.GAS_PARAMETER_SCHEMA_VERSION, ());
        reads[6] = abi.encodeCall(aggregate.MAX_CHUNKS, ());
        reads[7] = abi.encodeCall(aggregate.archivalCoverage, ());
        reads[8] = abi.encodeCall(aggregate.artifact, (artifactHash));
        reads[9] = abi.encodeCall(aggregate.artifactChunk, (artifactHash, uint32(0)));
        reads[10] = abi.encodeCall(aggregate.chunkStore, ());
        reads[11] = abi.encodeCall(aggregate.core, ());
        reads[12] = abi.encodeCall(aggregate.coverage, (completion));
        reads[13] = abi.encodeCall(aggregate.coveragePlan, (plan));
        reads[14] = abi.encodeCall(aggregate.coverageValidationRecord, (validation));
        reads[15] = abi.encodeCall(aggregate.currentCoverageValidation, (completion));
        reads[16] = abi.encodeCall(aggregate.finalityRegistry, ());
        reads[17] = abi.encodeCall(aggregate.gasParameter, (gasId));
        reads[18] = abi.encodeCall(aggregate.gasParameterIds, ());
        reads[19] = abi.encodeCall(aggregate.gasParameterInfo, (gasId));
        reads[20] = abi.encodeCall(aggregate.governanceAuthority, ());
        reads[21] = abi.encodeCall(
            aggregate.requireArtifactCoverage, (completion, terms.artistId, artifactHash)
        );
        reads[22] = abi.encodeCall(aggregate.schemaRegistry, ());
        for (uint256 i; i < reads.length; ++i) {
            _safeArtifactRead(target, reads[i]);
        }
        require(agentSafe.nonce() == nonce + 27, "four writers and23 actual read calls");
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.artifactSafeTarget(
            target, abi.encodeCall(aggregate.raiseGasParameter, (gasId, uint256(1000000)))
        );
        require(agentSafe.nonce() == nonce + 27, "direct Safe governance denial rolls back nonce");
    }

    function _chunkHash(A.Envelope memory e, address pointer) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARCHIVAL_CHUNK_ENVELOPE_V1"),
                block.chainid,
                address(host),
                e,
                pointer,
                pointer.codehash
            )
        );
    }

    function testChunkAlternatePointerFirstPreservesCanonicalStoreAndEstate() public {
        StreamSchemaDocumentStore store = new StreamSchemaDocumentStore();
        A.Envelope memory e = _chunkTerms();
        address alternate = SSTORE2.write(payload);
        bytes32 alternateHash = host.recordChunkEnvelope(e, alternate);
        (bytes32 chunkHash, address canonical) = store.publishChunk(payload);
        require(chunkHash == e.evidenceHash && canonical != alternate, "actual store pointer");
        vm.recordLogs();
        bytes32 canonicalHash = host.recordChunkEnvelope(e, canonical);
        CoverageTestVm.Log[] memory logs = vm.getRecordedLogs();
        uint256 matches;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == address(host)
                    && logs[i].topics[0]
                        == keccak256(
                            "ArchivalChunkEnvelopeRecorded(uint16,bytes32,address,bytes32)"
                        )
            ) {
                require(
                    logs[i].topics.length == 3 && logs[i].topics[1] == canonicalHash
                        && logs[i].topics[2] == bytes32(uint256(uint160(canonical)))
                        && keccak256(logs[i].data)
                            == keccak256(abi.encode(uint16(1), canonical.codehash)),
                    "exact chunk event"
                );
                ++matches;
            }
        }
        require(
            matches == 1 && canonicalHash == _chunkHash(e, canonical)
                && alternateHash == _chunkHash(e, alternate) && canonicalHash != alternateHash,
            "pointer bound preimages"
        );
        (address stored, bytes32 codeHash) = host.chunkEnvelopePointer(canonicalHash);
        require(stored == canonical && codeHash == canonical.codehash, "canonical immutable pin");
        (, bytes memory first) = host.envelope(alternateHash);
        (, bytes memory second) = host.envelope(canonicalHash);
        require(
            keccak256(first) == e.evidenceHash && keccak256(second) == e.evidenceHash,
            "both records retained"
        );
        (A.Envelope memory estate, bytes memory original) = host.envelope(envelopeHash);
        require(
            keccak256(abi.encode(estate)) == keccak256(abi.encode(terms))
                && keccak256(original) == terms.evidenceHash
                && envelopeHash
                    == keccak256(
                        abi.encode(
                            keccak256("6529STREAM_ARCHIVAL_ENVELOPE_V1"),
                            block.chainid,
                            address(host),
                            terms
                        )
                    ),
            "estate unchanged"
        );
        vm.expectRevert(abi.encodeWithSelector(A.ArchivalRecordExists.selector, canonicalHash));
        host.recordChunkEnvelope(e, canonical);
    }

    function testChunkExactBytesAndPointerNegativesThenHealthyCoverage() public {
        StreamSchemaDocumentStore store = new StreamSchemaDocumentStore();
        (, address pointer) = store.publishChunk(payload);
        A.Envelope memory e = _chunkTerms();
        bytes memory code = pointer.code;
        bytes memory wrongPrefix = bytes.concat(hex"01", payload);
        vm.etch(pointer, wrongPrefix);
        vm.expectRevert(abi.encodeWithSelector(A.InvalidArchivalEnvelope.selector));
        host.recordChunkEnvelope(e, pointer);
        vm.etch(pointer, code);
        bytes32 digest = e.payloadDigest;
        e.payloadDigest = bytes32(uint256(digest) ^ 1);
        vm.expectRevert(abi.encodeWithSelector(A.InvalidArchivalEnvelope.selector));
        host.recordChunkEnvelope(e, pointer);
        e.payloadDigest = digest;
        e.byteSize += 1;
        vm.expectRevert(abi.encodeWithSelector(A.InvalidArchivalEnvelope.selector));
        host.recordChunkEnvelope(e, pointer);
        e.byteSize -= 1;
        terms = e;
        envelopeHash = host.recordChunkEnvelope(e, pointer);
        (,, bytes32 coverageHash) = _covered();
        A.CoverageFacts memory facts =
            host.requireCoverage(coverageHash, e.artistId, e.evidenceHash);
        require(facts.envelopeHash == envelopeHash, "actual chunk receipts and fixity");
        vm.etch(pointer, wrongPrefix);
        vm.expectRevert(abi.encodeWithSelector(A.ArchivalComponentChanged.selector, pointer));
        host.requireCoverage(coverageHash, e.artistId, e.evidenceHash);
        vm.etch(pointer, code);
        require(
            host.requireCoverage(coverageHash, e.artistId, e.evidenceHash).coverageRecordHash
                == coverageHash,
            "same coverage restored"
        );
    }

    function testChunkValidationEpochOnlyReplacementAndFamilyTransitions() public {
        uint64 firstEpoch = host.coverageValidationEpoch();
        require(firstEpoch == 1, "genesis epoch");
        (bytes32 first, bytes32 second, bytes32 coverageHash) = _covered();
        require(host.coverageValidationEpoch() == firstEpoch, "initial unrelated fixities stable");
        vm.warp(block.timestamp + 1);
        _recordFixity(first, 1, false);
        require(host.coverageValidationEpoch() == firstEpoch + 1, "replacement invalidates caches");
        _status(firstFamily, 2);
        require(host.coverageValidationEpoch() == firstEpoch + 2, "disable invalidates caches");
        _status(firstFamily, 1);
        require(host.coverageValidationEpoch() == firstEpoch + 3, "restore invalidates caches");
        bytes32 fresh = host.recordCoverage(first, second);
        require(
            fresh != coverageHash
                && host.requireCoverage(fresh, terms.artistId, terms.evidenceHash)
                    .coverageRecordHash == fresh,
            "fresh latest fixity evidence"
        );
    }

    function testChunkEnvironmentFreshPinsWithoutEpochChangeAndSafeSelectors() public {
        bytes32 environment = host.requireCoverageEnvironment();
        uint64 epoch = host.coverageValidationEpoch();
        address foreign = address(new CoverageArtistFixture(address(core), address(verifier)));
        core.set(keccak256("ARTIST_REGISTRY"), foreign);
        vm.expectRevert(abi.encodeWithSelector(A.ArchivalComponentChanged.selector, foreign));
        host.requireCoverageEnvironment();
        require(host.coverageValidationEpoch() == epoch, "external drift has no epoch mutation");
        core.set(keccak256("ARTIST_REGISTRY"), facade);
        require(host.requireCoverageEnvironment() == environment, "same environment restored");
        StreamSchemaDocumentStore store = new StreamSchemaDocumentStore();
        (, address pointer) = store.publishChunk(payload);
        A.Envelope memory e = _chunkTerms();
        bytes32 hash = _chunkHash(e, pointer);
        uint256 nonce = agentSafe.nonce();
        require(
            executeSafe(
                agentSafe,
                agentKeys,
                address(host),
                0,
                abi.encodeCall(host.recordChunkEnvelope, (e, pointer)),
                0
            ),
            "Safe chunk record"
        );
        require(
            executeSafe(
                agentSafe,
                agentKeys,
                address(host),
                0,
                abi.encodeCall(host.chunkEnvelopePointer, (hash)),
                0
            ),
            "Safe pointer read"
        );
        require(
            executeSafe(
                agentSafe,
                agentKeys,
                address(host),
                0,
                abi.encodeCall(host.coverageValidationEpoch, ()),
                0
            ),
            "Safe epoch read"
        );
        require(
            executeSafe(
                agentSafe,
                agentKeys,
                address(host),
                0,
                abi.encodeCall(host.requireCoverageEnvironment, ()),
                0
            ),
            "Safe environment read"
        );
        require(agentSafe.nonce() == nonce + 4, "four actual Safe calls");
        (address actual, bytes32 actualCode) = host.chunkEnvelopePointer(hash);
        require(
            actual == pointer && actualCode == pointer.codehash
                && host.requireCoverageEnvironment() == environment,
            "static exact read control"
        );
    }

    function testActualQuorumReceiptsRoleFixityAndDualFamilyCoverage() public {
        (bytes32 first, bytes32 second, bytes32 hash) = _covered();
        A.CoverageFacts memory f = host.requireCoverage(hash, terms.artistId, terms.evidenceHash);
        require(
            f.firstReceiptRecordHash == first && f.secondReceiptRecordHash == second
                && f.checkpointRecordHash == checkpointHash,
            "actual joins"
        );
        require(
            executeSafe(
                agentSafe,
                agentKeys,
                address(host),
                0,
                abi.encodeCall(host.requireCoverage, (hash, terms.artistId, terms.evidenceHash)),
                0
            ),
            "actual Safe validating read"
        );
        (A.Envelope memory saved, bytes memory actual) = host.envelope(envelopeHash);
        require(
            saved.evidenceHash == keccak256(actual) && saved.payloadDigest == sha256(actual),
            "retained exact public bytes"
        );
    }

    function testMissingFixityCannotUseOnlyReceiptHashes() public {
        bytes32 first = _recordReceipt(true, 0);
        bytes32 second = _recordReceipt(false, 0);
        vm.expectRevert(abi.encodeWithSelector(A.InvalidArchivalCoverage.selector));
        host.recordCoverage(first, second);
        _recordFixity(first, 1, false);
        vm.expectRevert(abi.encodeWithSelector(A.InvalidArchivalCoverage.selector));
        host.recordCoverage(first, second);
        _recordFixity(second, 1, false);
        require(host.recordCoverage(first, second) != bytes32(0), "both independent audits");
    }

    function testKnownFailureAndRepairCannotSelectAnOldPassingHead() public {
        (bytes32 first, bytes32 second, bytes32 hash) = _covered();
        _recordFixity(second, 2, false);
        vm.expectRevert(abi.encodeWithSelector(A.InvalidArchivalCoverage.selector));
        host.requireCoverage(hash, terms.artistId, terms.evidenceHash);
        A.FixityTerms memory f = _fixityTerms(second, 1);
        bytes memory proof = safeThresholdSignature(
            fixityKeys, safeMessageDigest(fixitySafe, abi.encode(host.fixityDigest(f)))
        );
        vm.expectRevert(abi.encodeWithSelector(A.InvalidArchivalFixity.selector));
        host.recordFixity(f, proof);
        _recordFixity(second, 1, true);
        vm.expectRevert(abi.encodeWithSelector(A.InvalidArchivalCoverage.selector));
        host.requireCoverage(hash, terms.artistId, terms.evidenceHash);
        bytes32 replacement = host.recordCoverage(first, second);
        require(replacement != hash, "new coverage evidence");
        host.requireCoverage(replacement, terms.artistId, terms.evidenceHash);
    }

    function testCurrentRoleRemovalRejectsSameProofAndRestorationSucceeds() public {
        bytes32 first = _recordReceipt(true, 0);
        A.FixityTerms memory f = _fixityTerms(first, 1);
        bytes memory proof = safeThresholdSignature(
            fixityKeys, safeMessageDigest(fixitySafe, abi.encode(host.fixityDigest(f)))
        );
        _role(address(fixitySafe), false);
        vm.expectRevert(
            abi.encodeWithSelector(A.ArchivalUnauthorized.selector, address(fixitySafe))
        );
        host.recordFixity(f, proof);
        _role(address(fixitySafe), true);
        require(
            host.recordFixity(f, proof) != bytes32(0), "same valid proof after real role restore"
        );
    }

    function testWrongCIDAndNoncircularPossessionProofHaveHealthyRetry() public {
        (A.ReceiptTerms memory r, bytes memory id) = _receiptTerms(false, 0);
        bytes32 original = r.proofRecordHash;
        r.proofRecordHash = keccak256("opaque self assertion");
        bytes memory proof = _sign(secondAgentKey, host.receiptDigest(r));
        vm.expectRevert(abi.encodeWithSelector(A.InvalidArchivalReceipt.selector));
        host.recordReceipt(r, id, proof);
        r.proofRecordHash = original;
        id[4] ^= 0x01;
        r.storageIdentifierHash = keccak256(id);
        r.proofRecordHash = host.possessionHash(
            A.Possession(
                r.envelopeHash, r.familyRecordHash, r.storageIdentifierHash, r.writer, r.observedAt
            )
        );
        proof = _sign(secondAgentKey, host.receiptDigest(r));
        vm.expectRevert(abi.encodeWithSelector(A.InvalidArchivalReceipt.selector));
        host.recordReceipt(r, id, proof);
        (r, id) = _receiptTerms(false, 0);
        require(
            host.recordReceipt(r, id, _sign(secondAgentKey, host.receiptDigest(r))) != bytes32(0),
            "same nonce healthy CID"
        );
    }

    function testReciprocalFacadeSelectionAndEnvelopeScopeAreMandatory() public {
        (,, bytes32 hash) = _covered();
        vm.expectRevert(abi.encodeWithSelector(A.InvalidArchivalCoverage.selector));
        host.requireCoverage(hash, keccak256("other artist"), terms.evidenceHash);
        address wrong = address(new CoverageArtistFixture(address(core), address(verifier)));
        core.set(keccak256("ARTIST_REGISTRY"), wrong);
        vm.expectRevert(abi.encodeWithSelector(A.ArchivalComponentChanged.selector, wrong));
        host.requireCoverage(hash, terms.artistId, terms.evidenceHash);
        core.set(keccak256("ARTIST_REGISTRY"), facade);
        host.requireCoverage(hash, terms.artistId, terms.evidenceHash);
    }

    function testTaxonomyDegradationAndReactivationUsesFreshRevision() public {
        (,, bytes32 hash) = _covered();
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            host.familyStatusContext(secondFamily, 2);
        _status(secondFamily, 2);
        vm.expectRevert(abi.encodeWithSelector(A.InvalidArchivalCoverage.selector));
        host.requireCoverage(hash, terms.artistId, terms.evidenceHash);
        _status(secondFamily, 1);
        vm.expectRevert(
            abi.encodeWithSelector(A.ArchivalUnauthorized.selector, address(governance))
        );
        governance.execute(
            address(host),
            abi.encodeCall(host.setFamilyStatus, (secondFamily, uint8(2))),
            scope,
            oldHash,
            newHash
        );
        require(host.familyRevision(secondFamily) == 3, "monotonic taxonomy revision");
        host.requireCoverage(hash, terms.artistId, terms.evidenceHash);
    }

    function testFuzzSharedFamilyDependencyCannotSatisfyIndependence(uint8 dimension) public {
        A.Family memory f = _family("shared-family", false, safeVm.addr(secondAgentKey));
        (A.Family memory original,) = host.family(firstFamily);
        uint8 d = dimension % 6;
        if (d == 0) f.networkId = original.networkId;
        else if (d == 1) f.protocolLineage = original.protocolLineage;
        else if (d == 2) f.addressingLineage = original.addressingLineage;
        else if (d == 3) f.custodianId = original.custodianId;
        else if (d == 4) f.fundingDependency = original.fundingDependency;
        else f.retrievalDependency = original.retrievalDependency;
        bytes32 healthy = secondFamily;
        secondFamily = _admit("shared-family", f);
        bytes32 first = _recordReceipt(true, 0);
        bytes32 invalidSecond = _recordReceipt(false, 0);
        _recordFixity(first, 1, false);
        _recordFixity(invalidSecond, 1, false);
        vm.expectRevert(abi.encodeWithSelector(A.InvalidArchivalCoverage.selector));
        host.recordCoverage(first, invalidSecond);
        secondFamily = healthy;
        bytes32 goodSecond = _recordReceipt(false, 0);
        _recordFixity(goodSecond, 1, false);
        require(
            host.recordCoverage(first, goodSecond) != bytes32(0), "only shared dimension changed"
        );
    }

    function testTwoAuditedRenewalFamiliesStillDoNotSupplyEndowedCoverage() public {
        bytes32 first = _recordReceipt(false, 0);
        _recordFixity(first, 1, false);
        secondAgentKey = 0x652926;
        A.Family memory f = _family("second-renewal", false, safeVm.addr(secondAgentKey));
        f.networkId = keccak256("separate-network");
        f.protocolLineage = keccak256("separate-protocol");
        f.addressingLineage = keccak256("separate-addressing");
        f.custodianId = keccak256("separate-custodian");
        f.fundingDependency = keccak256("separate-funding");
        f.retrievalDependency = keccak256("separate-retrieval");
        secondFamily = _admit("second-renewal", f);
        bytes32 second = _recordReceipt(false, 0);
        _recordFixity(second, 1, false);
        vm.expectRevert(abi.encodeWithSelector(A.InvalidArchivalCoverage.selector));
        host.recordCoverage(first, second);
        bytes32 endowed = _recordReceipt(true, 0);
        _recordFixity(endowed, 1, false);
        require(host.recordCoverage(endowed, second) != bytes32(0), "actual endowed replacement");
    }

    function testUnknownEnvelopeSchemaSealedAndWrongDigestCannotCount() public {
        A.Envelope memory e = terms;
        e.schemaId = keccak256("unsupported schema");
        vm.expectRevert(abi.encodeWithSelector(A.InvalidArchivalEnvelope.selector));
        host.recordEnvelope(e, payload);
        e = terms;
        e.visibility = 2;
        e.custodyPolicyHash = keccak256("unaudited custody assertion");
        vm.expectRevert(abi.encodeWithSelector(A.InvalidArchivalEnvelope.selector));
        host.recordEnvelope(e, payload);
        e = terms;
        e.payloadDigest = keccak256("wrong digest");
        vm.expectRevert(abi.encodeWithSelector(A.InvalidArchivalEnvelope.selector));
        host.recordEnvelope(e, payload);
        e = terms;
        e.artistId = keccak256("second valid artist");
        require(host.recordEnvelope(e, payload) != bytes32(0), "valid exact bytes scope");
    }

    function testReceiptReplayLaneAndWriterCannotBeChangedByRelayer() public {
        (A.ReceiptTerms memory r, bytes memory id) = _receiptTerms(false, 19);
        bytes memory proof = _sign(secondAgentKey, host.receiptDigest(r));
        bytes32 hash = host.recordReceipt(r, id, proof);
        bytes32 key = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARCHIVAL_RECEIPT_NONCE_V1"),
                r.writer,
                r.familyRecordHash,
                r.nonce
            )
        );
        require(host.nonceUsed(key), "exact receipt lane consumed");
        vm.expectRevert(abi.encodeWithSelector(A.ArchivalReplay.selector, key));
        host.recordReceipt(r, id, proof);
        (A.ReceiptTerms memory saved,,) = host.receipt(hash);
        require(
            saved.writer == safeVm.addr(secondAgentKey) && saved.writer != address(this),
            "relayer never writer"
        );
    }

    function testReceiptWriterCannotSelfAuditEvenWithRealRole() public {
        bytes32 first = _recordReceipt(true, 0);
        _role(address(agentSafe), true);
        A.FixityTerms memory f = _fixityTerms(first, 1);
        f.verifier = address(agentSafe);
        bytes memory proof = safeThresholdSignature(
            agentKeys, safeMessageDigest(agentSafe, abi.encode(host.fixityDigest(f)))
        );
        vm.expectRevert(abi.encodeWithSelector(A.InvalidArchivalFixity.selector));
        host.recordFixity(f, proof);
        require(_recordFixity(first, 1, false) != bytes32(0), "independent actual operator");
    }

    function testDirectSafeCannotActAsGovernanceAndAllHistoricalReadsWork() public {
        (bytes32 first,, bytes32 hash) = _covered();
        A.Family memory f = _family("unauthorized", false, safeVm.addr(secondAgentKey));
        bytes memory callData = abi.encodeCall(host.admitFamily, ("unauthorized", f));
        bytes32 safeDigest = agentSafe.getTransactionHash(
            address(host), 0, callData, 0, 0, 0, 0, address(0), address(0), agentSafe.nonce()
        );
        bytes memory signatures = safeThresholdSignature(agentKeys, safeDigest);
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        agentSafe.execTransaction(
            address(host), 0, callData, 0, 0, 0, 0, address(0), payable(address(0)), signatures
        );
        require(
            executeSafe(
                agentSafe,
                agentKeys,
                address(host),
                0,
                abi.encodeCall(host.envelope, (envelopeHash)),
                0
            ),
            "Safe payload read"
        );
        require(
            executeSafe(
                agentSafe, agentKeys, address(host), 0, abi.encodeCall(host.receipt, (first)), 0
            ),
            "Safe receipt read"
        );
        bytes32 fix = host.latestFixity(first);
        require(
            executeSafe(
                agentSafe, agentKeys, address(host), 0, abi.encodeCall(host.fixity, (fix)), 0
            ),
            "Safe fixity read"
        );
        require(
            executeSafe(
                agentSafe, agentKeys, address(host), 0, abi.encodeCall(host.coverage, (hash)), 0
            ),
            "Safe historical coverage read"
        );
        require(
            executeSafe(
                agentSafe,
                agentKeys,
                address(host),
                0,
                abi.encodeCall(host.family, (firstFamily)),
                0
            ),
            "Safe taxonomy read"
        );
    }

    function testActualForeignRoleRegistryOwnerRejectsBeforeCanonicalControl() public {
        CoverageGovernanceFixture foreignExecutor = new CoverageGovernanceFixture();
        StreamRoleRegistry foreignRoles = new StreamRoleRegistry(address(foreignExecutor));
        governance.bindRoles(address(foreignRoles));
        vm.expectRevert(abi.encodeWithSelector(A.InvalidArchivalConfiguration.selector));
        new StreamArchivalCoverage(
            address(core),
            address(governance),
            address(foreignRoles),
            address(verifier),
            _sigConfig(),
            IStreamGasParameterHost.GasParameterConfig(
                "ARCHIVAL_DEPENDENCY_READ_GAS", 150000, 50000, 2
            )
        );
        governance.bindRoles(address(roles));
        StreamArchivalCoverage canonical = new StreamArchivalCoverage(
            address(core),
            address(governance),
            address(roles),
            address(verifier),
            _sigConfig(),
            IStreamGasParameterHost.GasParameterConfig(
                "ARCHIVAL_DEPENDENCY_READ_GAS", 150000, 50000, 2
            )
        );
        require(
            canonical.roleRegistry() == address(roles) && roles.owner() == address(governance),
            "exact real role mutation owner"
        );
    }

    function testMalformedTargetReadsAndParentGasFailClosedWithHealthyControl() public {
        (,, bytes32 hash) = _covered();
        CoverageReadAdversary adversary = new CoverageReadAdversary(address(core), address(host));
        core.set(keccak256("ARTIST_REGISTRY"), address(adversary));
        for (uint8 mode = 1; mode <= 4; ++mode) {
            adversary.setMode(mode);
            vm.expectRevert(
                abi.encodeWithSelector(A.ArchivalComponentChanged.selector, address(adversary))
            );
            host.requireCoverage(hash, terms.artistId, terms.evidenceHash);
            adversary.setMode(0);
            host.requireCoverage(hash, terms.artistId, terms.evidenceHash);
        }
        (bool ok, bytes memory data) = address(host).staticcall{ gas: 100000 }(
            abi.encodeCall(host.requireCoverage, (hash, terms.artistId, terms.evidenceHash))
        );
        require(
            !ok && bytes4(data) == A.ArchivalParentGas.selector, "parent cap failure is explicit"
        );
        host.requireCoverage(hash, terms.artistId, terms.evidenceHash);
    }
}
