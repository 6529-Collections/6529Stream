// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamExternalArtifactCoverage.t.sol";
import "../../../smart-contracts/domains/preservation/StreamBundleArchiveCoverage.sol";
import {
    StreamPreservationInventoryItems as InventoryItems
} from "../../../smart-contracts/domains/preservation/StreamPreservationInventoryItems.sol";
import {
    StreamBundleArchiveReads as ApplicabilityReads
} from "../../../smart-contracts/domains/preservation/StreamBundleArchiveReads.sol";

/// @dev Typed inventory/source and whole-byte environment boundaries. The new bundle host,
/// external archive, real full browser identity, native proofs, signed fixity and Safes are actual.
contract BundleInventoryBoundary {
    address public core;
    address public metadataHost;
    address public artifactCoverage;
    address public externalCoverage;
    T.Evidence private e;
    T.Segment[] private segments;

    constructor(address c, address m, address a, address x) {
        core = c;
        metadataHost = m;
        artifactCoverage = a;
        externalCoverage = x;
    }

    function configure(T.Evidence memory e_, T.Segment[] memory s) external {
        e = e_;
        for (uint256 i; i < s.length; ++i) {
            segments.push(s[i]);
        }
    }

    function inventoryEvidence(bytes32 id) external view returns (T.Evidence memory) {
        require(id == e.planId);
        return e;
    }

    function inventorySegment(bytes32 id, uint64 i) external view returns (T.Segment memory) {
        require(id == e.planId);
        return segments[i];
    }

    function changeItemCount(uint64 count) external {
        e.itemCount = count;
    }
}

contract BundleOnchainEnvironmentBoundary {
    bytes32 public environmentHash = keccak256("actual whole-byte environment boundary");
    uint64 public epoch = 1;

    function currentArtifactEnvironment() external view returns (bytes32, uint64) {
        return (environmentHash, epoch);
    }

    function advance() external {
        ++epoch;
    }
}

contract StreamBundleArchiveCoverageTest is OfficialSafeFixture {
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

    function _setupArchive() private {
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

    StreamBundleArchiveCoverage private bundle;
    BundleInventoryBoundary private inventory;
    BundleOnchainEnvironmentBoundary private onchain;
    T.Item[] private rows;
    bytes32[] private suffix;
    bytes32 private planId;
    bytes32 private renderHash;
    bytes32 private originalCoverage;
    bytes32 private firstReceipt;
    bytes32 private secondReceipt;

    function setUp() public {
        _setupArchive();
        (firstReceipt, secondReceipt, originalCoverage) = _covered();
        onchain = new BundleOnchainEnvironmentBoundary();
        inventory = new BundleInventoryBoundary(
            address(core), address(agentSafe), address(onchain), address(host)
        );
        B.Dependencies memory d;
        d.targets = [
            address(core),
            address(agentSafe),
            address(inventory),
            address(onchain),
            address(host),
            address(fixitySafe)
        ];
        for (uint256 i; i < 6; ++i) {
            d.codeHashes[i] = d.targets[i].codehash;
        }
        d.chainId = block.chainid;
        d.readGas = 500000;
        d.archiveGas = 3000000;
        bundle = new StreamBundleArchiveCoverage(d);
        planId = keccak256("explicit typed current source fixture plan");
        renderHash = keccak256("explicit typed current render evidence");
        T.Item memory row;
        row.kind = T.Kind.EXTERNAL_OBJECT;
        row.role = keccak256("first distinct role");
        row.source = address(inventory);
        row.sourceRecord = keccak256("original source record");
        row.algorithm = 1;
        row.canonicalizationId = object.canonicalizationId;
        row.digest = abi.encodePacked(object.contentHash);
        row.byteSize = object.byteSize;
        row.schemaId = object.schemaId;
        row.formatId = object.formatId;
        row.catalogId = object.formatCatalogId;
        row.catalogHash = object.formatCatalogHash;
        row.objectHash = objectHash;
        row.originalCoverageHash = originalCoverage;
        rows.push(row);
        row.role = keccak256("second distinct role for same exact object");
        rows.push(row);
        rows.push(
            InventoryItems.bytesItem(
                T.Kind.NATIVE_BYTES,
                keccak256("exact empty native field"),
                address(core),
                keccak256("source"),
                0,
                bytes("")
            )
        );
        rows.push(
            InventoryItems.absent(
                keccak256("actual source-derived absent field"),
                address(core),
                keccak256("source"),
                0
            )
        );
        T.Segment[] memory segments = new T.Segment[](2);
        T.Item[] memory pair = new T.Item[](2);
        pair[0] = rows[0];
        pair[1] = rows[1];
        segments[0] = Chains.segment(keccak256("first"), keccak256("original first witness"), pair);
        suffix.push(Chains.link(segments[0].key, 2, 1, rows[1], 0));
        suffix.push(0);
        pair[0] = rows[2];
        pair[1] = rows[3];
        segments[1] =
            Chains.segment(keccak256("second"), keccak256("original second witness"), pair);
        suffix.push(Chains.link(segments[1].key, 2, 1, rows[3], 0));
        suffix.push(0);
        T.Evidence memory e;
        e.planId = planId;
        e.collectionId = 1;
        e.scopeSubject = keccak256("typed collection");
        e.artistId = object.artistId;
        e.segmentCount = 2;
        e.itemCount = 4;
        e.renderCriticalEvidenceHash = renderHash;
        e.segmentChainHash = Chains.append(Chains.append(0, 0, segments[0]), 1, segments[1]);
        inventory.configure(e, segments);
    }

    function _proof(uint256 i) private view returns (B.Proof memory) {
        return i < 2 ? B.Proof(1, originalCoverage, objectHash) : B.Proof(0, 0, 0);
    }

    function _next(uint256 i) private {
        bundle.coverNext(planId, rows[i], suffix[i], _proof(i));
    }

    function _complete() private returns (T.BundleEvidence memory result) {
        bundle.beginCoverage(planId);
        for (uint256 i; i < 4; ++i) {
            _next(i);
        }
        return bundle.requireCoverage(planId, renderHash);
    }

    function testCompleteActualExternalProofAndIntrinsicApplicabilityHaveDistinctEvidence() public {
        T.BundleEvidence memory e = _complete();
        require(
            e.itemCount == 4 && e.bundleCoverageHash != 0 && e.bundleCoverageHash != renderHash
                && e.inventoryPlan == planId
        );
        (T.Item memory first, B.Admission memory a) = bundle.admittedItem(planId, 0);
        require(
            first.objectHash == objectHash && a.originalBundleHash != 0
                && a.externalOriginal.firstReceiptHash == firstReceipt
        );
        (, B.Admission memory duplicate) = bundle.admittedItem(planId, 1);
        require(duplicate.externalOriginal.coverageHash == a.externalOriginal.coverageHash);
        (, B.Admission memory empty) = bundle.admittedItem(planId, 2);
        (, B.Admission memory absent) = bundle.admittedItem(planId, 3);
        require(
            empty.proof.backend == 0 && absent.proof.backend == 0
                && empty.originalBundleHash != absent.originalBundleHash
        );
        require(
            bundle.requireFullCurrentCoverage(planId).bundleCoverageHash == e.bundleCoverageHash
        );
        _fails(address(bundle), abi.encodeCall(bundle.requireCoverage, (planId, bytes32(0))));
    }

    function testOriginalFixityRefreshFailureRepairInvalidatesBeforeDuringAfterProgress() public {
        bytes32 original = _complete().bundleCoverageHash;
        _recordFixity(firstReceipt, 1, false);
        _fails(address(bundle), abi.encodeCall(bundle.requireCoverage, (planId, renderHash)));
        bytes32 firstRefresh = bundle.beginRefresh(planId);
        bundle.refreshNext(planId, 0);
        require(bundle.refresh(firstRefresh).nextIndex == 1);
        _recordFixity(firstReceipt, 2, false);
        bytes32 failedRefresh = bundle.beginRefresh(planId);
        require(failedRefresh != firstRefresh && bundle.refresh(failedRefresh).nextIndex == 0);
        _fails(address(bundle), abi.encodeCall(bundle.refreshNext, (planId, uint64(0))));
        require(bundle.refresh(failedRefresh).nextIndex == 0);
        _recordFixity(firstReceipt, 1, true);
        bytes32 repaired = bundle.beginRefresh(planId);
        require(repaired != failedRefresh);
        for (uint64 i; i < 4; ++i) {
            bundle.refreshNext(planId, i);
        }
        require(bundle.requireCoverage(planId, renderHash).bundleCoverageHash == original);
        _role(address(fixitySafe), false);
        require(bundle.requireCoverage(planId, renderHash).bundleCoverageHash == original);
    }

    function testFamilyAndOnchainEnvironmentChangesNeverReuseStaleValidation() public {
        bytes32 original = _complete().bundleCoverageHash;
        _status(firstFamily, 2);
        _fails(address(bundle), abi.encodeCall(bundle.requireCoverage, (planId, renderHash)));
        _status(firstFamily, 1);
        bundle.beginRefresh(planId);
        for (uint64 i; i < 4; ++i) {
            bundle.refreshNext(planId, i);
        }
        require(bundle.requireCoverage(planId, renderHash).bundleCoverageHash == original);
        onchain.advance();
        _fails(address(bundle), abi.encodeCall(bundle.requireCoverage, (planId, renderHash)));
        bytes32 key = bundle.beginRefresh(planId);
        bundle.refreshNext(planId, 0);
        require(bundle.beginRefresh(planId) == key && bundle.refresh(key).nextIndex == 1);
        for (uint64 i = 1; i < 4; ++i) {
            bundle.refreshNext(planId, i);
        }
        require(bundle.requireCoverage(planId, renderHash).bundleCoverageHash == original);
    }

    function testNoSubsetNoReorderNoFakeAbsenceAndFinalCountRollback() public {
        inventory.changeItemCount(3);
        bundle.beginCoverage(planId);
        _fails(
            address(bundle),
            abi.encodeCall(bundle.coverNext, (planId, rows[1], suffix[0], _proof(0)))
        );
        _fails(
            address(bundle),
            abi.encodeCall(bundle.coverNext, (planId, rows[2], suffix[0], B.Proof(0, 0, 0)))
        );
        require(bundle.progress(planId).itemCount == 0);
        _next(0);
        _next(1);
        _next(2);
        _fails(
            address(bundle),
            abi.encodeCall(bundle.coverNext, (planId, rows[3], suffix[3], _proof(3)))
        );
        require(bundle.progress(planId).itemCount == 3 && !bundle.progress(planId).complete);
        _fails(address(bundle), abi.encodeCall(bundle.requireCoverage, (planId, renderHash)));
    }

    function testActualSafeSubmissionAndLowGasRollbackThenExactRetry() public {
        bundle.beginCoverage(planId);
        bytes memory input =
            abi.encodeCall(bundle.coverNext, (planId, rows[0], suffix[0], _proof(0)));
        (bool ok,) = address(bundle).call{ gas: 50000 }(input);
        require(!ok && bundle.progress(planId).itemCount == 0);
        require(executeSafe(agentSafe, agentKeys, address(bundle), 0, input, 0));
        require(bundle.progress(planId).itemCount == 1);
        _next(1);
        _next(2);
        _next(3);
        bundle.requireCoverage(planId, renderHash);
    }

    function testFuzzItemProvenanceAndTerminalSubstitutionNeverAdvance(bytes32 mutation) public {
        bundle.beginCoverage(planId);
        T.Item memory row = rows[0];
        row.provenanceHash = mutation;
        if (mutation != 0) {
            _fails(
                address(bundle),
                abi.encodeCall(bundle.coverNext, (planId, row, suffix[0], _proof(0)))
            );
        }
        _fails(
            address(bundle),
            abi.encodeCall(bundle.coverNext, (planId, rows[0], bytes32(0), _proof(0)))
        );
        require(bundle.progress(planId).itemCount == 0);
    }

    function emptyMemberRead(T.Item calldata item, B.Proof calldata proof)
        external
        view
        returns (bytes32)
    {
        B.Dependencies memory d;
        (B.Admission memory a,) = ApplicabilityReads.admit(d, keccak256("artist"), item, proof);
        return a.originalBundleHash;
    }

    function testEmptyPackageMemberRetainsShaPathAndRejectsNonemptyOrProofSubstitution() public {
        T.Item memory item;
        item.kind = T.Kind.EMPTY_PACKAGE_MEMBER;
        item.role = keccak256("RUNNABLE_PACKAGE_MEMBER");
        item.source = address(this);
        item.sourceRecord = keccak256("original reference");
        item.sourceIndex = 17;
        item.algorithm = 2;
        item.canonicalizationId = keccak256("RAW_BYTES");
        item.digest = abi.encodePacked(sha256(bytes("")));
        item.uri = "python/websockets/py.typed";
        B.Proof memory noProof;
        bytes32 first = this.emptyMemberRead(item, noProof);
        require(first != 0);
        item.uri = "python/websockets/asyncio/__init__.py";
        require(this.emptyMemberRead(item, noProof) != first, "empty path identity retained");
        item.byteSize = 1;
        _fails(address(this), abi.encodeCall(this.emptyMemberRead, (item, noProof)));
        item.byteSize = 0;
        item.digest = abi.encodePacked(keccak256(bytes("")));
        _fails(address(this), abi.encodeCall(this.emptyMemberRead, (item, noProof)));
        item.digest = abi.encodePacked(sha256(bytes("")));
        item.uri = "";
        _fails(address(this), abi.encodeCall(this.emptyMemberRead, (item, noProof)));
        item.uri = "python/websockets/py.typed";
        _fails(
            address(this),
            abi.encodeCall(this.emptyMemberRead, (item, B.Proof(1, originalCoverage, objectHash)))
        );
        require(this.emptyMemberRead(item, noProof) == first, "exact unchanged applicability retry");
        item.kind = T.Kind.NATIVE_OS_PREREQUISITE;
        require(
            this.emptyMemberRead(item, noProof) != first,
            "empty OS prerequisite retains its separate applicability"
        );
        item.digest = abi.encodePacked(keccak256("wrong empty SHA"));
        _fails(address(this), abi.encodeCall(this.emptyMemberRead, (item, noProof)));
    }

    function testBoundedCurrentReadReturnsExactFiveWordsAfterEightNamedColdTargets() public {
        _complete();
        bytes memory input = abi.encodeCall(bundle.requireCoverage, (planId, renderHash));
        vm.cool(address(bundle));
        vm.cool(address(inventory));
        vm.cool(address(onchain));
        vm.cool(address(host));
        vm.cool(address(core));
        vm.cool(address(governance));
        vm.cool(address(roles));
        vm.cool(address(verifier));
        uint256 beforeGas = gasleft();
        (bool ok, bytes memory raw) = address(bundle).staticcall{ gas: 6000000 }(input);
        emit log_named_uint("bundleCurrentFiveWordsEightNamedCold", beforeGas - gasleft());
        require(ok && raw.length == 160);
        T.BundleEvidence memory e = abi.decode(raw, (T.BundleEvidence));
        require(keccak256(raw) == keccak256(abi.encode(e)) && e.bundleCoverageHash != 0);
    }
}
