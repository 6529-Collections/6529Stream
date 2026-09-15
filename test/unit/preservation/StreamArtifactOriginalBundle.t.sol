// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArchivalCoverage.t.sol";
import {
    StreamPreservationArchiveBundleReads as OriginalBundles
} from "../../../smart-contracts/domains/preservation/StreamPreservationArchiveBundleReads.sol";
import {
    StreamBundleArchiveReads as BundleReads
} from "../../../smart-contracts/domains/preservation/StreamBundleArchiveReads.sol";
import {
    StreamBundleArchiveTypes as B
} from "../../../smart-contracts/interfaces/stream/preservation/StreamBundleArchiveTypes.sol";
import {
    StreamPreservationInventoryTypes as T
} from "../../../smart-contracts/interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";

/// @dev Setup/helpers copied literally from root 8b7b5822 StreamArchivalCoverageTest.
/// Actual archive/checkpoint/RoleRegistry/Store/aggregate/Safes; Core/facade/Executor/schema/finality boundaries retained.
contract StreamArtifactOriginalBundleTest is OfficialSafeFixture {
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

    function artifactSafeTarget(address target, bytes calldata data) external {
        require(msg.sender == address(this), "test wrapper only");
        require(executeSafe(agentSafe, agentKeys, target, 0, data, 0), "actual Safe target call");
    }

    function _safeArtifactRead(address target, bytes memory data) private {
        (bool beforeOK, bytes memory before_) = target.staticcall(data);
        require(beforeOK, "static preparation succeeds");
        require(executeSafe(agentSafe, agentKeys, target, 0, data, 0), "actual Safe read CALL");
        (bool afterOK, bytes memory after_) = target.staticcall(data);
        require(afterOK && keccak256(before_) == keccak256(after_), "ordinary static return parity");
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

    function testOriginalPartLocatorAndFullStateBundlesSurvivePassingRefresh() public {
        (StreamFinalityArtifactCoverage aggregate, StreamSchemaDocumentStore store) =
            _artifactHost();
        _canonicalChunk(store);
        bytes32 artifact = aggregate.recordArtifact(_artifactTerms(1));
        (bytes32 first, bytes32 second, bytes32 covered) = _covered();
        bytes32 plan = aggregate.beginCoverage(artifact, firstFamily, secondFamily);
        bytes32 completion = aggregate.coverNextChunk(plan, 0, covered);
        require(
            aggregate.originalArtifactChunkCoverage(completion, 0) == covered,
            "original exact locator"
        );
        bytes32 original = OriginalBundles.chunk(
            address(host),
            covered,
            terms.artistId,
            keccak256(payload),
            firstFamily,
            secondFamily,
            500000
        );
        require(original != 0, "complete original payload and signatures");
        (bytes32 env, uint64 epoch) = aggregate.currentArtifactEnvironment();
        require(env != 0 && epoch == host.coverageValidationEpoch(), "exact current epoch");
        vm.warp(block.timestamp + 1);
        _recordFixity(first, 1, false);
        bytes32 refreshed = host.recordCoverage(first, second);
        require(refreshed != covered, "passing successor is distinct");
        aggregate.refreshNextChunk(completion, 0, refreshed);
        (bytes32 nextEnv, uint64 nextEpoch) = aggregate.currentArtifactEnvironment();
        require(nextEnv == env && nextEpoch > epoch, "health revision separate from environment");
        require(
            aggregate.originalArtifactChunkCoverage(completion, 0) == covered,
            "refresh never substitutes original locator"
        );
        require(
            OriginalBundles.chunk(
                address(host),
                covered,
                terms.artistId,
                keccak256(payload),
                firstFamily,
                secondFamily,
                500000
            ) == original,
            "exact original bytes unchanged"
        );
        B.Dependencies memory d;
        d.targets[3] = address(aggregate);
        d.codeHashes[3] = address(aggregate).codehash;
        d.chainId = block.chainid;
        d.readGas = 500000;
        d.archiveGas = 1000000;
        T.Item memory item = _onchainItem(aggregate, artifact, completion);
        (B.Admission memory admitted,) =
            BundleReads.admit(d, terms.artistId, item, B.Proof(2, completion, artifact));
        require(
            admitted.originalBundleHash != 0 && admitted.immutablePartsHash != 0,
            "actual onchain child and original bundle joins"
        );
        require(
            admitted.onchainOriginal.completionHash == completion, "immutable original completion"
        );
        BundleReads.current(d, terms.artistId, item, admitted);
    }

    function testUnknownAndIncompleteOriginalLocatorsCannotUseCurrentHead() public {
        (StreamFinalityArtifactCoverage aggregate, StreamSchemaDocumentStore store) =
            _artifactHost();
        _canonicalChunk(store);
        bytes32 artifact = aggregate.recordArtifact(_artifactTerms(1));
        (,, bytes32 covered) = _covered();
        bytes32 plan = aggregate.beginCoverage(artifact, firstFamily, secondFamily);
        _badLocator(aggregate, 0, 0);
        _badLocator(aggregate, plan, 0);
        _badLocator(aggregate, covered, 0);
        bytes32 completion = aggregate.coverNextChunk(plan, 0, covered);
        _badLocator(aggregate, completion, 1);
        require(
            aggregate.originalArtifactChunkCoverage(completion, 0) == covered,
            "healthy original remains readable"
        );
        address finality = aggregate.finalityRegistry();
        core.set(keccak256("ARTWORK_FINALITY_REGISTRY"), address(0));
        (bool ok,) =
            address(aggregate).staticcall(abi.encodeCall(aggregate.currentArtifactEnvironment, ()));
        require(!ok, "current graph fails");
        require(
            aggregate.originalArtifactChunkCoverage(completion, 0) == covered,
            "historical locator is not current readiness"
        );
        core.set(keccak256("ARTWORK_FINALITY_REGISTRY"), finality);
        aggregate.currentArtifactEnvironment();
    }

    function testOriginalBundleWrongScopeAndEvidenceFailThenSafeReads() public {
        (StreamFinalityArtifactCoverage aggregate, StreamSchemaDocumentStore store) =
            _artifactHost();
        _canonicalChunk(store);
        bytes32 artifact = aggregate.recordArtifact(_artifactTerms(1));
        (,, bytes32 covered) = _covered();
        bytes32 completion = aggregate.coverNextChunk(
            aggregate.beginCoverage(artifact, firstFamily, secondFamily), 0, covered
        );
        (bool ok,) = address(this)
            .staticcall(
                abi.encodeCall(
                    this.originalBundle,
                    (
                        address(host),
                        covered,
                        bytes32(uint256(1)),
                        keccak256(payload),
                        firstFamily,
                        secondFamily,
                        500000
                    )
                )
            );
        require(!ok, "wrong artist");
        (ok,) = address(this)
            .staticcall(
                abi.encodeCall(
                    this.originalBundle,
                    (
                        address(host),
                        covered,
                        terms.artistId,
                        bytes32(uint256(1)),
                        firstFamily,
                        secondFamily,
                        500000
                    )
                )
            );
        require(!ok, "wrong original content");
        (ok,) = address(this)
            .staticcall(
                abi.encodeCall(
                    this.originalBundle,
                    (
                        address(host),
                        covered,
                        terms.artistId,
                        keccak256(payload),
                        secondFamily,
                        firstFamily,
                        500000
                    )
                )
            );
        require(!ok, "ordered original families");
        _safeArtifactRead(
            address(aggregate),
            abi.encodeCall(aggregate.originalArtifactChunkCoverage, (completion, 0))
        );
        _safeArtifactRead(
            address(aggregate), abi.encodeCall(aggregate.currentArtifactEnvironment, ())
        );
        require(
            aggregate.supportsInterface(type(IStreamArtifactOriginalEvidence).interfaceId)
                && aggregate.supportsInterface(type(IStreamArtifactEnvironment).interfaceId),
            "additive capabilities"
        );
        require(
            aggregate.supportsInterface(type(IStreamFinalityArtifactCoverage).interfaceId),
            "old interface preserved"
        );
    }

    function testFuzzOriginalLocatorIndexAndCount(uint32 extra) public {
        (StreamFinalityArtifactCoverage aggregate, StreamSchemaDocumentStore store) =
            _artifactHost();
        _canonicalChunk(store);
        bytes32 artifact = aggregate.recordArtifact(_artifactTerms(1));
        (,, bytes32 covered) = _covered();
        bytes32 completion = aggregate.coverNextChunk(
            aggregate.beginCoverage(artifact, firstFamily, secondFamily), 0, covered
        );
        uint32 index = uint32(uint256(extra) % type(uint32).max + 1);
        _badLocator(aggregate, completion, index);
        require(
            aggregate.originalArtifactChunkCoverage(completion, 0) == covered,
            "failed out of range preserves original"
        );
    }

    function originalBundle(
        address h,
        bytes32 hash,
        bytes32 artistId,
        bytes32 content,
        bytes32 first,
        bytes32 second,
        uint256 cap
    ) external view returns (bytes32) {
        return OriginalBundles.chunk(h, hash, artistId, content, first, second, cap);
    }

    function _badLocator(StreamFinalityArtifactCoverage aggregate, bytes32 completion, uint32 index)
        private
        view
    {
        (bool ok,) = address(aggregate)
            .staticcall(
                abi.encodeCall(aggregate.originalArtifactChunkCoverage, (completion, index))
            );
        require(!ok, "invalid locator rejected");
    }

    function _onchainItem(
        StreamFinalityArtifactCoverage aggregate,
        bytes32 artifact,
        bytes32 completion
    ) private view returns (T.Item memory item) {
        item.kind = T.Kind.ONCHAIN_OBJECT;
        item.role = keccak256("ORIGINAL_ARTIFACT_TEST");
        item.source = address(aggregate);
        item.sourceRecord = completion;
        item.algorithm = 1;
        item.canonicalizationId = keccak256("BINARY_EXACT_V1");
        item.digest = abi.encodePacked(keccak256(payload));
        item.byteSize = uint64(payload.length);
        item.objectHash = artifact;
        item.originalCoverageHash = completion;
    }
}
