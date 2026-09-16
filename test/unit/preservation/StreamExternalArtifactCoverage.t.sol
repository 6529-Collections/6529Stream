// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../smart-contracts/domains/preservation/StreamExternalArtifactCoverage.sol";
import "../../../smart-contracts/domains/preservation/StreamArweaveObjectCheckpointVerifier.sol";
import "../../../smart-contracts/domains/governance/StreamRoleRegistry.sol";
import "../../helpers/OfficialSafeFixture.sol";

interface ExternalArtifactVm {
    function warp(uint256 timestamp) external;
    function etch(address target, bytes calldata code) external;
    function prank(address actor) external;
    function cool(address target) external;
    function parseJsonUint(string calldata json, string calldata key)
        external
        pure
        returns (uint256);
}

/// @dev Explicit typed Core/Executor/module boundaries; proof/coverage/roles and Safes are actual.
contract ExternalArchiveGovernanceBoundary {
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

contract ExternalArchiveModuleBoundary {
    address public immutable governanceExecutor;

    constructor(address e) {
        governanceExecutor = e;
    }
}

contract ExternalArchiveCoreBoundary {
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

/// @notice Uses the complete 253 MB archived object's real flat/native commitments and paths.
/// @dev Quorum network anchoring and institution identities are local fixtures, not public uploads.
contract StreamExternalArtifactCoverageTest is OfficialSafeFixture {
    event log_named_uint(string key, uint256 value);
    ExternalArtifactVm private constant vm =
        ExternalArtifactVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    StreamExternalArtifactCoverage private host;
    StreamArweaveObjectCheckpointVerifier private verifier;
    StreamRoleRegistry private roles;
    ExternalArchiveGovernanceBoundary private governance;
    ExternalArchiveCoreBoundary private core;
    OfficialSafe private agentSafe;
    OfficialSafe private fixitySafe;
    uint256[] private agentKeys;
    uint256[] private fixityKeys;
    uint256 private constant OBSERVER_A = 0x652921;
    uint256 private constant OBSERVER_B = 0x652922;
    uint256 private constant SECOND_AGENT = 0x652925;
    E.ObjectIdentity private object;
    bytes32 private objectHash;
    bytes32 private checkpointHash;
    bytes32 private transactionId;
    bytes32 private firstFamily;
    bytes32 private secondFamily;
    bytes private firstPath;
    bytes private lastPath;

    function setUp() public {
        vm.warp(1_900_000_000);
        governance = new ExternalArchiveGovernanceBoundary();
        roles = new StreamRoleRegistry(address(governance));
        governance.bindRoles(address(roles));
        core = new ExternalArchiveCoreBoundary();
        core.set(
            keccak256("MODULE_REGISTRY"),
            address(new ExternalArchiveModuleBoundary(address(governance)))
        );
        A.Observer[] memory observers = new A.Observer[](2);
        observers[0] = A.Observer(safeVm.addr(OBSERVER_A), keccak256("observer-one"));
        observers[1] = A.Observer(safeVm.addr(OBSERVER_B), keccak256("observer-two"));
        if (observers[0].account > observers[1].account) {
            (observers[0], observers[1]) = (observers[1], observers[0]);
        }
        verifier = new StreamArweaveObjectCheckpointVerifier(
            address(governance),
            observers,
            2,
            IStreamGasParameterHost.GasParameterConfig(
                "ARCHIVAL_ERC1271_VERIFY_GAS", 400000, 90000, 2
            )
        );
        host = new StreamExternalArtifactCoverage(
            address(core),
            address(governance),
            address(roles),
            address(verifier),
            IStreamGasParameterHost.GasParameterConfig(
                "EXTERNAL_ARCHIVE_READ_GAS", 300000, 150000, 2
            ),
            IStreamGasParameterHost.GasParameterConfig(
                "EXTERNAL_ARCHIVE_SIGNATURE_GAS", 400000, 90000, 2
            )
        );
        SafeComponents memory components = deploySafeComponents("1.4.1");
        agentKeys.push(0x652931);
        agentKeys.push(0x652932);
        fixityKeys.push(0x652933);
        fixityKeys.push(0x652934);
        agentSafe = createOfficialSafe(components, safeOwnerAddresses(agentKeys), 2, 31);
        fixitySafe = createOfficialSafe(components, safeOwnerAddresses(fixityKeys), 2, 32);
        _role(address(fixitySafe), true);
        firstFamily = _admit("arweave-object", _family("arweave-object", true, address(agentSafe)));
        secondFamily = _admit(
            "institution-object", _family("institution-object", false, safeVm.addr(SECOND_AGENT))
        );
        string memory json =
            safeVm.readFile("test/fixtures/preservation/reference-browser-object-v1.json");
        object = E.ObjectIdentity(
            keccak256("artist"),
            keccak256("external object schema declaration"),
            keccak256("BINARY_EXACT_V1"),
            bytes32(safeVm.parseJsonBytes(json, ".contentHash")),
            bytes32(safeVm.parseJsonBytes(json, ".sha256Digest")),
            bytes32(safeVm.parseJsonBytes(json, ".arweaveDataRoot")),
            uint64(vm.parseJsonUint(json, ".byteSize")),
            keccak256("ZIP catalog entry"),
            keccak256("format catalog declaration"),
            keccak256("complete catalog byte commitment")
        );
        firstPath = safeVm.parseJsonBytes(json, ".firstDataPath");
        lastPath = safeVm.parseJsonBytes(json, ".lastDataPath");
        objectHash = host.recordObject(object);
        A.Checkpoint memory c = _checkpointTerms();
        transactionId = c.transactionId;
        checkpointHash = verifier.recordCheckpoint(
            c, abi.encode(c.dataRoot, uint256(c.dataSize)), firstPath, lastPath, _certificate(c)
        );
    }

    function _sign(uint256 key, bytes32 digest) private returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = safeVm.sign(key, digest);
        return abi.encodePacked(r, s, v);
    }

    function _checkpointTerms() private view returns (A.Checkpoint memory c) {
        c.networkId = verifier.networkId();
        c.configurationHash = verifier.configurationHash();
        c.blockHash = new bytes(48);
        c.blockHash[0] = 0x65;
        c.blockHeight = 1;
        c.transactionId =
            keccak256("explicit local quorum network fixture for complete browser object");
        c.dataRoot = object.arweaveDataRoot;
        c.dataSize = object.byteSize;
        c.transactionRoot = sha256(
            abi.encodePacked(
                sha256(abi.encodePacked(c.dataRoot)), sha256(abi.encode(uint256(c.dataSize)))
            )
        );
        c.transactionEnd = c.dataSize;
        c.blockDataSize = c.dataSize;
        c.observedAt = uint64(block.timestamp);
    }

    function _certificate(A.Checkpoint memory c) private returns (A.ObserverProof[] memory p) {
        bytes32 digest = verifier.checkpointDigest(c);
        p = new A.ObserverProof[](2);
        p[0] = A.ObserverProof(safeVm.addr(OBSERVER_A), _sign(OBSERVER_A, digest));
        p[1] = A.ObserverProof(safeVm.addr(OBSERVER_B), _sign(OBSERVER_B, digest));
        if (p[0].account > p[1].account) (p[0], p[1]) = (p[1], p[0]);
    }

    function _family(string memory name, bool endowed, address agent)
        private
        view
        returns (A.Family memory)
    {
        bytes memory salt = bytes(endowed ? "one" : "two");
        return A.Family(
            keccak256(bytes(name)),
            endowed ? verifier.networkId() : keccak256("INSTITUTIONAL_ARCHIVE"),
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
        require(
            abi.decode(
                governance.execute(
                    address(host),
                    abi.encodeCall(host.admitFamily, (name, f)),
                    scope,
                    oldHash,
                    newHash
                ),
                (bytes32)
            ) == hash
        );
    }

    function _status(bytes32 hash, uint8 status) private {
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) = host.familyStatusContext(hash, status);
        governance.execute(
            address(host),
            abi.encodeCall(host.setFamilyStatus, (hash, status)),
            scope,
            oldHash,
            newHash
        );
    }

    function _receipt(bool first, uint256 nonce)
        private
        returns (E.Receipt memory r, bytes memory id)
    {
        id = first
            ? abi.encodePacked(transactionId)
            : bytes(
                "https://institution.example.invalid/objects/sha256/d2eabd7dffeed4f37632e9e8d5a861d7fe5df621d66e62cd43234ecb9a572417"
            );
        r = E.Receipt(
            objectHash,
            first ? firstFamily : secondFamily,
            keccak256(id),
            keccak256(bytes(first ? "CONTENT_ADDRESSED_INCLUSION" : "ATTESTED_POSSESSION")),
            first ? verifier.profileHash() : host.POSSESSION_PROFILE(),
            first ? checkpointHash : bytes32(0),
            first ? address(agentSafe) : safeVm.addr(SECOND_AGENT),
            uint64(block.timestamp),
            nonce,
            uint64(block.timestamp + 1 days)
        );
        if (!first) r.proofRecordHash = host.possessionHash(r);
    }

    function _recordReceipt(bool first, uint256 nonce) private returns (bytes32 hash) {
        (E.Receipt memory r, bytes memory id) = _receipt(first, nonce);
        bytes memory sig = first
            ? safeThresholdSignature(
                agentKeys, safeMessageDigest(agentSafe, abi.encodePacked(host.receiptDigest(r)))
            )
            : _sign(SECOND_AGENT, host.receiptDigest(r));
        return host.recordReceipt(r, id, sig);
    }

    function _fixity(bytes32 receiptHash, uint8 outcome) private view returns (E.Fixity memory f) {
        (E.Receipt memory r,,) = host.receipt(receiptHash);
        f.receiptHash = receiptHash;
        f.objectHash = r.objectHash;
        f.familyRecordHash = r.familyRecordHash;
        f.storageIdentifierHash = r.storageIdentifierHash;
        f.profileHash = host.FIXITY_PROFILE();
        f.expectedSha256 = object.sha256Digest;
        f.expectedKeccak256 = object.contentHash;
        f.expectedArweaveRoot = object.arweaveDataRoot;
        f.expectedSize = object.byteSize;
        if (outcome == 1) {
            f.observedSha256 = object.sha256Digest;
            f.observedKeccak256 = object.contentHash;
            f.observedArweaveRoot = object.arweaveDataRoot;
            f.observedSize = object.byteSize;
        }
        f.checkedAt = uint64(block.timestamp);
        f.outcome = outcome;
        f.reportHash = keccak256("full locally retrieved original package fixity report fixture");
        f.previousFixityHash = host.latestFixity(receiptHash);
        f.verifier = address(fixitySafe);
        f.deadline = uint64(block.timestamp + 1 days);
        f.nonce = uint256(f.previousFixityHash);
    }

    function _recordFixity(bytes32 receiptHash, uint8 outcome, bool repair)
        private
        returns (bytes32)
    {
        E.Fixity memory f = _fixity(receiptHash, outcome);
        if (repair) f.repairReportHash = keccak256("repair report");
        return host.recordFixity(
            f,
            safeThresholdSignature(
                fixityKeys, safeMessageDigest(fixitySafe, abi.encodePacked(host.fixityDigest(f)))
            )
        );
    }

    function _covered() private returns (bytes32 first, bytes32 second, bytes32 hash) {
        first = _recordReceipt(true, 0);
        second = _recordReceipt(false, 0);
        _recordFixity(first, 1, false);
        _recordFixity(second, 1, false);
        hash = host.recordCoverage(first, second);
    }

    function _fails(address target, bytes memory data) private {
        (bool ok,) = target.call(data);
        require(!ok, "expected rejection");
    }

    function testActualFullBrowserObjectReceiptAndFixityComposition() public {
        (bytes32 first, bytes32 second, bytes32 hash) = _covered();
        E.Coverage memory c = host.requireCoverage(hash, object.artistId, objectHash);
        require(
            c.byteSize == 253440410
                && c.contentHash
                    == 0x68c77c4fc0ab6e7bec76afe7f82d84d0112fd1cacbd8bcfe26a18d2849f2d473
        );
        require(
            c.sha256Digest == 0xd2eabd7dffeed4f37632e9e8d5a861d7fe5df621d66e62cd43234ecb9a572417
        );
        require(
            c.firstReceiptHash == first && c.secondReceiptHash == second
                && c.checkpointHash == checkpointHash
        );
        E.NativeRecord memory n = verifier.checkpointRecord(checkpointHash);
        require(
            keccak256(n.firstDataPath) == keccak256(firstPath)
                && keccak256(n.lastDataPath) == keccak256(lastPath) && n.certificate.length == 2
        );
        (E.Receipt memory r, bytes memory id, bytes memory signature) = host.receipt(first);
        require(
            r.objectHash == objectHash && keccak256(id) == r.storageIdentifierHash
                && signature.length == 130
        );
    }

    function testOriginalCheckpointFlatPreimageUnchangedByPrivateExtraction() public view {
        E.NativeRecord memory n = verifier.checkpointRecord(checkpointHash);
        bytes32 expected = keccak256(
            abi.encode(
                keccak256("6529STREAM_EXTERNAL_OBJECT_CHECKPOINT_RECORD_V1"),
                block.chainid,
                address(verifier),
                n.checkpoint,
                n.firstChunkDigest,
                n.lastChunkDigest,
                keccak256(n.transactionPath),
                keccak256(n.firstDataPath),
                keccak256(n.lastDataPath)
            )
        );
        require(expected == checkpointHash && n.recordHash == expected);
    }

    function testNativeInclusionAloneCannotBecomeCoverage() public {
        bytes32 a = _recordReceipt(true, 0);
        bytes32 b = _recordReceipt(false, 0);
        _fails(address(host), abi.encodeCall(host.recordCoverage, (a, b)));
        _recordFixity(a, 1, false);
        _fails(address(host), abi.encodeCall(host.recordCoverage, (a, b)));
    }

    function testLatestFailureInvalidatesAndRepairKeepsOriginalHistory() public {
        (bytes32 a, bytes32 b, bytes32 old) = _covered();
        bytes32 passing = host.latestFixity(a);
        _recordFixity(a, 2, false);
        _fails(
            address(host), abi.encodeCall(host.requireCoverage, (old, object.artistId, objectHash))
        );
        E.Fixity memory bad = _fixity(a, 1);
        _fails(address(host), abi.encodeCall(host.recordFixity, (bad, bytes(""))));
        _recordFixity(a, 1, true);
        bytes32 fresh = host.recordCoverage(a, b);
        require(fresh != old);
        host.requireCoverage(fresh, object.artistId, objectHash);
        require(host.coverage(old).firstFixityHash == passing);
        _fails(
            address(host), abi.encodeCall(host.requireCoverage, (old, object.artistId, objectHash))
        );
    }

    function testExpectedAndObservedCompleteObjectTupleMutationsRejected() public {
        bytes32 a = _recordReceipt(true, 0);
        for (uint256 i; i < 8; ++i) {
            E.Fixity memory f = _fixity(a, 1);
            if (i == 0) f.expectedSha256 = bytes32(uint256(1));
            if (i == 1) f.observedSha256 = bytes32(uint256(1));
            if (i == 2) f.expectedKeccak256 = bytes32(uint256(1));
            if (i == 3) f.observedKeccak256 = bytes32(uint256(1));
            if (i == 4) f.expectedArweaveRoot = bytes32(uint256(1));
            if (i == 5) f.observedArweaveRoot = bytes32(uint256(1));
            if (i == 6) ++f.expectedSize;
            if (i == 7) ++f.observedSize;
            bytes memory sig = safeThresholdSignature(
                fixityKeys, safeMessageDigest(fixitySafe, abi.encodePacked(host.fixityDigest(f)))
            );
            _fails(address(host), abi.encodeCall(host.recordFixity, (f, sig)));
        }
        require(host.latestFixity(a) == 0);
        _recordFixity(a, 1, false);
    }

    function testExactReceiptAndRoleIndependenceRequired() public {
        bytes32 a = _recordReceipt(true, 0);
        E.Fixity memory f = _fixity(a, 1);
        f.verifier = address(agentSafe);
        _role(address(agentSafe), true);
        _fails(address(host), abi.encodeCall(host.recordFixity, (f, bytes(""))));
        _role(address(fixitySafe), false);
        f = _fixity(a, 1);
        _fails(address(host), abi.encodeCall(host.recordFixity, (f, bytes(""))));
    }

    function testWrongObjectSizeOrNativeRootCannotBorrowCheckpoint() public {
        for (uint256 i; i < 2; ++i) {
            E.ObjectIdentity memory o = object;
            if (i == 0) ++o.byteSize;
            else o.arweaveDataRoot = bytes32(uint256(1));
            bytes32 other = host.recordObject(o);
            (E.Receipt memory r, bytes memory id) = _receipt(true, 0);
            r.objectHash = other;
            _fails(address(host), abi.encodeCall(host.recordReceipt, (r, id, bytes(""))));
        }
    }

    function testSameRootWrongFlatDigestNeedsIndependentObservedCorrespondence() public {
        E.ObjectIdentity memory o = object;
        o.sha256Digest = bytes32(uint256(1));
        bytes32 other = host.recordObject(o);
        (E.Receipt memory r, bytes memory id) = _receipt(true, 0);
        r.objectHash = other;
        bytes32 receiptHash = host.recordReceipt(
            r,
            id,
            safeThresholdSignature(
                agentKeys, safeMessageDigest(agentSafe, abi.encodePacked(host.receiptDigest(r)))
            )
        );
        E.Fixity memory f = _fixity(receiptHash, 1);
        f.expectedSha256 = o.sha256Digest;
        _fails(
            address(host),
            abi.encodeCall(
                host.recordFixity,
                (
                    f,
                    safeThresholdSignature(
                        fixityKeys,
                        safeMessageDigest(fixitySafe, abi.encodePacked(host.fixityDigest(f)))
                    )
                )
            )
        );
    }

    function testBadSafeProofRollsBackThenExactRetryAndReplayFails() public {
        (E.Receipt memory r, bytes memory id) = _receipt(true, 0);
        bytes memory signature = safeThresholdSignature(
            agentKeys, safeMessageDigest(agentSafe, abi.encodePacked(host.receiptDigest(r)))
        );
        bytes memory bad = bytes.concat(signature);
        bad[0] ^= 0x01;
        _fails(address(host), abi.encodeCall(host.recordReceipt, (r, id, bad)));
        host.recordReceipt(r, id, signature);
        _fails(address(host), abi.encodeCall(host.recordReceipt, (r, id, signature)));
    }

    function testDirectThresholdSafeCallIsRealWriter() public {
        (E.Receipt memory r, bytes memory id) = _receipt(true, 0);
        require(
            executeSafe(
                agentSafe,
                agentKeys,
                address(host),
                0,
                abi.encodeCall(host.recordReceipt, (r, id, bytes(""))),
                0
            )
        );
        bytes32 expected = keccak256(
            abi.encode(keccak256("6529STREAM_EXTERNAL_RECEIPT_V1"), block.chainid, address(host), r)
        );
        (E.Receipt memory saved,,) = host.receipt(expected);
        require(saved.writer == address(agentSafe));
    }

    function testFamilyLifecycleInvalidatesCurrentWithoutErasingOriginal() public {
        (,, bytes32 hash) = _covered();
        _status(secondFamily, 2);
        _fails(
            address(host), abi.encodeCall(host.requireCoverage, (hash, object.artistId, objectHash))
        );
        require(host.coverage(hash).coverageHash == hash);
        _status(secondFamily, 1);
        host.requireCoverage(hash, object.artistId, objectHash);
    }

    function testWrongCanonicalGovernanceContextCannotAdmitFamily() public {
        A.Family memory f = _family("another", true, address(agentSafe));
        _fails(address(host), abi.encodeCall(host.admitFamily, ("another", f)));
    }

    function testInstitutionalIdentifierCannotPretendRawCIDOrCredentials() public {
        bytes[8] memory invalid = [
            bytes(hex"01551220"),
            bytes("https://user@institution.example/file"),
            bytes("https://institution.example/file#fragment"),
            bytes("https://institution.example/"),
            bytes("https://./file"),
            bytes("https://a..b/file"),
            bytes("https://-a.example/file"),
            bytes("https://a-.example/file")
        ];
        for (uint256 i; i < invalid.length; ++i) {
            (E.Receipt memory r,) = _receipt(false, 0);
            r.storageIdentifierHash = keccak256(invalid[i]);
            r.proofRecordHash = host.possessionHash(r);
            _fails(
                address(host),
                abi.encodeCall(
                    host.recordReceipt, (r, invalid[i], _sign(SECOND_AGENT, host.receiptDigest(r)))
                )
            );
        }
    }

    function testNativeEndpointsAndRangeMutationsRejected() public {
        A.Checkpoint memory c = _checkpointTerms();
        bytes memory txPath = abi.encode(c.dataRoot, uint256(c.dataSize));
        _fails(address(this), abi.encodeCall(this.nativeProof, (c, txPath, firstPath, firstPath)));
        _fails(address(this), abi.encodeCall(this.nativeProof, (c, txPath, lastPath, lastPath)));
        ++c.transactionStart;
        _fails(address(this), abi.encodeCall(this.nativeProof, (c, txPath, firstPath, lastPath)));
    }

    function nativeProof(
        A.Checkpoint calldata c,
        bytes calldata txPath,
        bytes calldata first,
        bytes calldata last
    ) external pure returns (bytes32, bytes32) {
        return StreamArweaveObjectInclusion.verify(c, txPath, first, last);
    }

    function testDuplicateQuorumAndExpiredReceiptRejected() public {
        A.Checkpoint memory c = _checkpointTerms();
        c.transactionId = bytes32(uint256(123));
        A.ObserverProof[] memory p = _certificate(c);
        p[1] = p[0];
        _fails(
            address(verifier),
            abi.encodeCall(
                verifier.recordCheckpoint,
                (c, abi.encode(c.dataRoot, uint256(c.dataSize)), firstPath, lastPath, p)
            )
        );
        (E.Receipt memory r, bytes memory id) = _receipt(false, 0);
        r.deadline = uint64(block.timestamp - 1);
        _fails(
            address(host),
            abi.encodeCall(host.recordReceipt, (r, id, _sign(SECOND_AGENT, host.receiptDigest(r))))
        );
    }

    function testRuntimeAndModuleGraphChangesFailCurrent() public {
        (,, bytes32 hash) = _covered();
        bytes memory code = address(verifier).code;
        vm.etch(address(verifier), hex"00");
        _fails(
            address(host), abi.encodeCall(host.requireCoverage, (hash, object.artistId, objectHash))
        );
        vm.etch(address(verifier), code);
        core.set(
            keccak256("MODULE_REGISTRY"), address(new ExternalArchiveModuleBoundary(address(1)))
        );
        _fails(
            address(host), abi.encodeCall(host.requireCoverage, (hash, object.artistId, objectHash))
        );
    }

    function testFuzzWrongFullObjectCannotConsumeCoverage(bytes32 replacement) public {
        if (replacement == objectHash) return;
        (,, bytes32 hash) = _covered();
        _fails(
            address(host),
            abi.encodeCall(host.requireCoverage, (hash, object.artistId, replacement))
        );
    }

    function testFullObjectCurrentReadHasConstantBulkSizeCost() public {
        (,, bytes32 hash) = _covered();
        bytes memory data =
            abi.encodeCall(host.requireCoverage, (hash, object.artistId, objectHash));
        vm.cool(address(host));
        vm.cool(address(core));
        vm.cool(address(governance));
        vm.cool(address(roles));
        vm.cool(address(verifier));
        uint256 beforeGas = gasleft();
        (bool ok, bytes memory out) = address(host).staticcall{ gas: 2000000 }(data);
        uint256 spent = beforeGas - gasleft();
        emit log_named_uint("full253MBcurrent5namedcold", spent);
        require(ok && out.length == 480);
        E.Coverage memory c = abi.decode(out, (E.Coverage));
        require(c.byteSize == 253440410);
    }

    function testSignedSameFamilyIdentityCannotCountTwice() public {
        A.Family memory f = _family("arweave-object", false, safeVm.addr(SECOND_AGENT));
        secondFamily = _admit("arweave-object", f);
        bytes32 first = _recordReceipt(true, 0);
        bytes32 second = _recordReceipt(false, 0);
        _recordFixity(first, 1, false);
        _recordFixity(second, 1, false);
        _fails(address(host), abi.encodeCall(host.recordCoverage, (first, second)));
    }

    function testSignedSharedIndependenceDimensionsRejectedIndividually() public {
        (A.Family memory first,,) = host.family(firstFamily);
        bytes32 a = _recordReceipt(true, 0);
        _recordFixity(a, 1, false);
        for (uint256 i; i < 6; ++i) {
            A.Family memory f = _family("shared-dimension", false, safeVm.addr(SECOND_AGENT));
            if (i == 0) f.networkId = first.networkId;
            if (i == 1) f.protocolLineage = first.protocolLineage;
            if (i == 2) f.addressingLineage = first.addressingLineage;
            if (i == 3) f.custodianId = first.custodianId;
            if (i == 4) f.fundingDependency = first.fundingDependency;
            if (i == 5) f.retrievalDependency = first.retrievalDependency;
            secondFamily = _admit("shared-dimension", f);
            bytes32 b = _recordReceipt(false, 0);
            _recordFixity(b, 1, false);
            _fails(address(host), abi.encodeCall(host.recordCoverage, (a, b)));
        }
    }

    function testUnregisteredObserverAndLegacyDomainSignaturesRejected() public {
        A.Checkpoint memory c = _checkpointTerms();
        c.transactionId = bytes32(uint256(777));
        A.ObserverProof[] memory p = _certificate(c);
        p[0] = A.ObserverProof(safeVm.addr(0x652999), _sign(0x652999, verifier.checkpointDigest(c)));
        if (p[0].account > p[1].account) (p[0], p[1]) = (p[1], p[0]);
        _fails(
            address(verifier),
            abi.encodeCall(
                verifier.recordCheckpoint,
                (c, abi.encode(c.dataRoot, uint256(c.dataSize)), firstPath, lastPath, p)
            )
        );
        p = _certificate(c);
        bytes32 legacyDomain = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("6529Stream Arweave Checkpoints"),
                keccak256("1"),
                block.chainid,
                address(verifier)
            )
        );
        bytes32 body = keccak256(
            abi.encode(
                keccak256(
                    "StreamArweaveCheckpoint(bytes32 networkId,bytes blockHash,uint64 blockHeight,bytes32 transactionRoot,uint256 blockDataSize,bytes32 transactionId,bytes32 dataRoot,uint64 dataSize,uint256 transactionStart,uint256 transactionEnd,uint64 observedAt,bytes32 configurationHash)"
                ),
                c.networkId,
                keccak256(c.blockHash),
                c.blockHeight,
                c.transactionRoot,
                c.blockDataSize,
                c.transactionId,
                c.dataRoot,
                c.dataSize,
                c.transactionStart,
                c.transactionEnd,
                c.observedAt,
                c.configurationHash
            )
        );
        bytes32 legacy = keccak256(abi.encodePacked(hex"1901", legacyDomain, body));
        p[0].signature =
            _sign(p[0].account == safeVm.addr(OBSERVER_A) ? OBSERVER_A : OBSERVER_B, legacy);
        p[1].signature =
            _sign(p[1].account == safeVm.addr(OBSERVER_A) ? OBSERVER_A : OBSERVER_B, legacy);
        _fails(
            address(verifier),
            abi.encodeCall(
                verifier.recordCheckpoint,
                (c, abi.encode(c.dataRoot, uint256(c.dataSize)), firstPath, lastPath, p)
            )
        );
    }

    function testMalformedAndRebasedNativePathsRejected() public {
        A.Checkpoint memory c = _checkpointTerms();
        bytes memory txPath = abi.encode(c.dataRoot, uint256(c.dataSize));
        _fails(
            address(this),
            abi.encodeCall(
                this.nativeProof, (c, bytes.concat(txPath, hex"00"), firstPath, lastPath)
            )
        );
        _fails(address(this), abi.encodeCall(this.nativeProof, (c, txPath, bytes(""), lastPath)));
        bytes memory rebased = bytes.concat(new bytes(32), firstPath);
        _fails(address(this), abi.encodeCall(this.nativeProof, (c, txPath, rebased, lastPath)));
        bytes memory wrong = bytes.concat(firstPath);
        wrong[wrong.length - 1] ^= 0x01;
        _fails(address(this), abi.encodeCall(this.nativeProof, (c, txPath, wrong, lastPath)));
    }

    function testZeroOrOversizedLeafCannotPassEndpointProof() public {
        A.Checkpoint memory c = _checkpointTerms();
        for (uint256 i; i < 2; ++i) {
            bytes32 digest = i == 0 ? bytes32(0) : keccak256("declared oversized leaf");
            c.dataSize = i == 0 ? 1 : 262145;
            c.transactionEnd = c.dataSize;
            c.blockDataSize = c.dataSize;
            bytes memory path = abi.encode(digest, uint256(c.dataSize));
            c.dataRoot = sha256(
                abi.encodePacked(
                    sha256(abi.encodePacked(digest)), sha256(abi.encode(uint256(c.dataSize)))
                )
            );
            c.transactionRoot = sha256(
                abi.encodePacked(
                    sha256(abi.encodePacked(c.dataRoot)), sha256(abi.encode(uint256(c.dataSize)))
                )
            );
            _fails(
                address(this),
                abi.encodeCall(
                    this.nativeProof, (c, abi.encode(c.dataRoot, uint256(c.dataSize)), path, path)
                )
            );
        }
    }

    function testExactLegacyReceiptDomainCannotAuthorizeNewObject() public {
        (E.Receipt memory r, bytes memory id) = _receipt(false, 0);
        bytes32 legacyDomain = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("6529Stream Archival Coverage"),
                keccak256("1"),
                block.chainid,
                address(host)
            )
        );
        bytes32 body = keccak256(
            abi.encode(
                keccak256(
                    "StreamExternalArtifactReceipt(bytes32 objectHash,bytes32 familyRecordHash,bytes32 storageIdentifierHash,bytes32 evidenceClass,bytes32 proofProfileHash,bytes32 proofRecordHash,address writer,uint64 observedAt,uint256 nonce,uint64 deadline)"
                ),
                r
            )
        );
        _fails(
            address(host),
            abi.encodeCall(
                host.recordReceipt,
                (
                    r,
                    id,
                    _sign(SECOND_AGENT, keccak256(abi.encodePacked(hex"1901", legacyDomain, body)))
                )
            )
        );
        _recordReceipt(false, 0);
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

    function testCurrentPairRefreshPreservesExactOriginalCoverage() public {
        (bytes32 a, bytes32 b, bytes32 original) = _covered();
        E.Coverage memory saved = host.coverage(original);
        bytes32 savedHash = keccak256(abi.encode(saved));
        E.CurrentPair memory initial = host.currentReceiptPair(a, b, object.artistId, objectHash);
        require(initial.firstFixityHash == saved.firstFixityHash);
        bytes32 refresh = _recordFixity(a, 1, false);
        E.CurrentPair memory current = host.currentReceiptPair(a, b, object.artistId, objectHash);
        require(
            current.firstFixityHash == refresh && current.firstFixityHash != initial.firstFixityHash
        );
        require(current.secondFixityHash == initial.secondFixityHash);
        require(current.firstReceiptHash == a && current.secondReceiptHash == b);
        require(current.firstFamilyRecordHash == saved.firstFamilyRecordHash);
        require(current.secondFamilyRecordHash == saved.secondFamilyRecordHash);
        require(current.objectHash == saved.objectHash && current.artistId == saved.artistId);
        require(
            current.contentHash == saved.contentHash && current.sha256Digest == saved.sha256Digest
        );
        require(
            current.arweaveDataRoot == saved.arweaveDataRoot && current.byteSize == saved.byteSize
        );
        require(
            current.checkpointHash == saved.checkpointHash
                && current.profileHash == saved.profileHash
        );
        require(keccak256(abi.encode(host.coverage(original))) == savedHash);
        _fails(
            address(host),
            abi.encodeCall(host.requireCoverage, (original, object.artistId, objectHash))
        );
    }

    function testCurrentPairFailureRepairNeedsSameOriginalReceipts() public {
        (bytes32 a, bytes32 b, bytes32 original) = _covered();
        bytes32 failing = _recordFixity(a, 2, false);
        _fails(
            address(host),
            abi.encodeCall(host.currentReceiptPair, (a, b, object.artistId, objectHash))
        );
        E.Fixity memory invalid = _fixity(a, 1);
        bytes memory signature = safeThresholdSignature(
            fixityKeys, safeMessageDigest(fixitySafe, abi.encodePacked(host.fixityDigest(invalid)))
        );
        _fails(address(host), abi.encodeCall(host.recordFixity, (invalid, signature)));
        require(host.latestFixity(a) == failing);
        bytes32 repair = _recordFixity(a, 1, true);
        E.CurrentPair memory current = host.currentReceiptPair(a, b, object.artistId, objectHash);
        require(
            current.firstReceiptHash == a && current.secondReceiptHash == b
                && current.firstFixityHash == repair
        );
        require(host.coverage(original).firstFixityHash != repair);
        _fails(
            address(host),
            abi.encodeCall(host.requireCoverage, (original, object.artistId, objectHash))
        );
    }

    function testCurrentPairDoesNotSelectReplacementReceipt() public {
        (bytes32 a, bytes32 b,) = _covered();
        bytes32 replacement = _recordReceipt(true, 1);
        _recordFixity(replacement, 1, false);
        _recordFixity(a, 2, false);
        _fails(
            address(host),
            abi.encodeCall(host.currentReceiptPair, (a, b, object.artistId, objectHash))
        );
        E.CurrentPair memory other =
            host.currentReceiptPair(replacement, b, object.artistId, objectHash);
        require(other.firstReceiptHash == replacement && other.firstReceiptHash != a);
        // A caller retaining the original pair must compare identities and cannot substitute other.
        _fails(
            address(host),
            abi.encodeCall(host.currentReceiptPair, (b, replacement, object.artistId, objectHash))
        );
        _fails(
            address(host),
            abi.encodeCall(host.currentReceiptPair, (b, b, object.artistId, objectHash))
        );
    }

    function testCurrentPairFamilyAndGraphInvalidationRestore() public {
        (bytes32 a, bytes32 b,) = _covered();
        bytes memory callData =
            abi.encodeCall(host.currentReceiptPair, (a, b, object.artistId, objectHash));
        _status(firstFamily, 2);
        _fails(address(host), callData);
        _status(firstFamily, 1);
        host.currentReceiptPair(a, b, object.artistId, objectHash);
        bytes memory code = address(verifier).code;
        vm.etch(address(verifier), hex"00");
        _fails(address(host), callData);
        vm.etch(address(verifier), code);
        host.currentReceiptPair(a, b, object.artistId, objectHash);
        core.set(
            keccak256("MODULE_REGISTRY"), address(new ExternalArchiveModuleBoundary(address(1)))
        );
        _fails(address(host), callData);
    }

    function testCurrentPairIsAdditiveUnsavedExactFourteenWords() public {
        (bytes32 a, bytes32 b,) = _covered();
        require(host.supportsInterface(type(IStreamExternalArtifactCoverage).interfaceId));
        require(host.supportsInterface(type(IStreamExternalArtifactCurrentPair).interfaceId));
        bytes memory data =
            abi.encodeCall(host.currentReceiptPair, (a, b, object.artistId, objectHash));
        vm.cool(address(host));
        vm.cool(address(core));
        vm.cool(address(governance));
        vm.cool(address(roles));
        vm.cool(address(verifier));
        uint256 beforeGas = gasleft();
        (bool ok, bytes memory out) = address(host).staticcall{ gas: 2000000 }(data);
        emit log_named_uint("currentPair14words5namedcold", beforeGas - gasleft());
        require(ok && out.length == 448);
        E.CurrentPair memory current = abi.decode(out, (E.CurrentPair));
        require(keccak256(out) == keccak256(abi.encode(current)));
        _role(address(fixitySafe), false);
        host.currentReceiptPair(a, b, object.artistId, objectHash);
        // Original authority survives revocation; a fresh fixity still needs today's role.
        E.Fixity memory f = _fixity(a, 1);
        _fails(address(host), abi.encodeCall(host.recordFixity, (f, bytes(""))));
    }

    function testFuzzCurrentPairCannotBorrowWrongArtistOrObject(bytes32 replacement) public {
        (bytes32 a, bytes32 b,) = _covered();
        if (replacement != objectHash) {
            _fails(
                address(host),
                abi.encodeCall(host.currentReceiptPair, (a, b, object.artistId, replacement))
            );
        }
        if (replacement != object.artistId) {
            _fails(
                address(host),
                abi.encodeCall(host.currentReceiptPair, (a, b, replacement, objectHash))
            );
        }
    }
}
