// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamExternalArtifactCoverage.t.sol";

/// @dev Setup and helper bodies copied verbatim from the retained CurrentPair fixture;
/// only this new test contract owns the additional environment assertions.
contract StreamExternalArtifactEnvironmentTest is OfficialSafeFixture {
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

    function testEnvironmentTracksEveryFamilyAndFixityMutation() public {
        (bytes32 environment, uint64 revision) = host.currentExternalArtifactEnvironment();
        require(environment != 0 && revision == 2);
        (bytes32 a, bytes32 b,) = _covered();
        (bytes32 same, uint64 afterCoverage) = host.currentExternalArtifactEnvironment();
        require(same == environment && afterCoverage == revision + 2);
        _recordFixity(a, 1, false);
        (, uint64 passing) = host.currentExternalArtifactEnvironment();
        require(passing == afterCoverage + 1);
        _recordFixity(a, 2, false);
        (, uint64 failed) = host.currentExternalArtifactEnvironment();
        require(failed == passing + 1);
        _fails(
            address(host),
            abi.encodeCall(host.currentReceiptPair, (a, b, object.artistId, objectHash))
        );
        _recordFixity(a, 1, true);
        (, uint64 repaired) = host.currentExternalArtifactEnvironment();
        require(repaired == failed + 1);
        _status(firstFamily, 2);
        (, uint64 suspended) = host.currentExternalArtifactEnvironment();
        require(suspended == repaired + 1);
        _status(firstFamily, 1);
        (, uint64 restored) = host.currentExternalArtifactEnvironment();
        require(restored == suspended + 1);
        host.currentReceiptPair(a, b, object.artistId, objectHash);
        _admit("third-institution", _family("third-institution", false, address(0x1234)));
        (, uint64 admitted) = host.currentExternalArtifactEnvironment();
        require(admitted == restored + 1);
    }

    function testEnvironmentPreservesOriginalRoleSemanticsAndFailedAppendRollback() public {
        (bytes32 a, bytes32 b,) = _covered();
        (bytes32 environment, uint64 revision) = host.currentExternalArtifactEnvironment();
        _role(address(fixitySafe), false);
        (bytes32 same, uint64 sameRevision) = host.currentExternalArtifactEnvironment();
        require(same == environment && sameRevision == revision);
        host.currentReceiptPair(a, b, object.artistId, objectHash);
        E.Fixity memory f = _fixity(a, 1);
        _fails(address(host), abi.encodeCall(host.recordFixity, (f, bytes(""))));
        (same, sameRevision) = host.currentExternalArtifactEnvironment();
        require(same == environment && sameRevision == revision);
        _role(address(fixitySafe), true);
        _recordFixity(a, 1, false);
        (, sameRevision) = host.currentExternalArtifactEnvironment();
        require(sameRevision == revision + 1);
    }

    function testEnvironmentBindsActualCompleteGraphAndCanonicalTwoWordRead() public {
        (bytes32 environment, uint64 revision) = host.currentExternalArtifactEnvironment();
        bytes memory input = abi.encodeCall(host.currentExternalArtifactEnvironment, ());
        (bool ok, bytes memory raw) = address(host).staticcall(input);
        require(
            ok && raw.length == 64 && keccak256(raw) == keccak256(abi.encode(environment, revision))
        );
        require(host.supportsInterface(type(IStreamExternalArtifactEnvironment).interfaceId));
        require(host.supportsInterface(type(IStreamExternalArtifactCoverage).interfaceId));
        require(host.supportsInterface(type(IStreamExternalArtifactCurrentPair).interfaceId));
        address prior = core.pointers(keccak256("MODULE_REGISTRY"));
        core.set(
            keccak256("MODULE_REGISTRY"),
            address(new ExternalArchiveModuleBoundary(address(governance)))
        );
        (bytes32 changed, uint64 sameRevision) = host.currentExternalArtifactEnvironment();
        require(changed != environment && sameRevision == revision);
        core.set(keccak256("MODULE_REGISTRY"), prior);
        (changed, sameRevision) = host.currentExternalArtifactEnvironment();
        require(changed == environment && sameRevision == revision);
        bytes memory code = address(verifier).code;
        vm.etch(address(verifier), hex"00");
        _fails(address(host), input);
        vm.etch(address(verifier), code);
        (changed, sameRevision) = host.currentExternalArtifactEnvironment();
        require(changed == environment && sameRevision == revision);
    }
}
