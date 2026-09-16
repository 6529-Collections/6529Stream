// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamOnchainContentCheckpoint.t.sol";
import "../../../smart-contracts/domains/finality/StreamContentLeafManifest.sol";
import "../../../smart-contracts/domains/preservation/StreamFinalityArtifactCoverage.sol";
import "../../../smart-contracts/domains/metadata/StreamSchemaDocumentStore.sol";

interface LeafManifestVm {
    function mockCall(address target, bytes calldata input, bytes calldata output) external;
    function getNonce(address target) external view returns (uint64);
    function computeCreateAddress(address target, uint256 nonce) external pure returns (address);
}

/// @dev Explicit archival-family/receipt boundary; actual whole-object bytes and coverage aggregation below.
contract LeafManifestArchiveBoundary {
    address public immutable core;
    address public immutable governanceAuthority;
    uint64 public coverageValidationEpoch = 1;
    mapping(bytes32 => address) private _pointers;

    constructor(address c, address g) {
        core = c;
        governanceAuthority = g;
    }

    function advanceEpoch() external {
        ++coverageValidationEpoch;
    }

    function requireCoverageEnvironment() external pure returns (bytes32) {
        return keccak256("fixture archival environment");
    }

    function add(bytes32 hash, address pointer) external {
        _pointers[hash] = pointer;
    }

    function requireCoverage(bytes32 hash, bytes32 artistId, bytes32 evidence)
        external
        view
        returns (A.CoverageFacts memory f)
    {
        require(
            hash == evidence && _pointers[evidence] != address(0),
            "unrecognized archival fixture bytes"
        );
        f.coverageRecordHash = hash;
        f.envelopeHash = hash;
        f.artistId = artistId;
        f.evidenceHash = evidence;
        f.firstFamilyRecordHash = keccak256("archive family A");
        f.secondFamilyRecordHash = keccak256("archive family B");
    }

    function chunkEnvelopePointer(bytes32 hash) external view returns (address, bytes32) {
        address p = _pointers[hash];
        return (p, p.codehash);
    }

    function coverage(bytes32 hash) external view returns (A.CoverageFacts memory) {
        return this.requireCoverage(hash, keccak256("artist"), hash);
    }
}

contract LeafManifestSchemaBoundary {
    address public immutable chunkStore;
    address public immutable governanceAuthority;

    constructor(address s, address g) {
        chunkStore = s;
        governanceAuthority = g;
    }
}

contract LeafManifestGovernanceBoundary {
    function isStreamGovernedParameterAuthority() external pure returns (bool) {
        return true;
    }

    function currentAction()
        external
        pure
        returns (bool, bytes32, uint8, bytes32, bytes32, bytes32)
    {
        return (false, 0, 0, 0, 0, 0);
    }
}

contract LeafManifestFinalityBoundary {
    address public immutable core;
    address public immutable artifactCoverage;

    constructor(address c, address a) {
        core = c;
        artifactCoverage = a;
    }
}

/// @notice Actual checkpoint, inventory, document store, artifact aggregator and manifest verifier.
/// @dev Core/Router/entropy, archival receipts/families, schema admission and finality are explicit boundaries.
contract StreamContentLeafManifestTest is CharacterizationTestBase, OfficialSafeFixture {
    LeafManifestVm private constant mvm =
        LeafManifestVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    bytes32 private constant ARTIST = keccak256("artist");
    CheckpointCoreBoundary private core;
    CheckpointRouterBoundary private router;
    StreamCollectionTokenInventory private inventory;
    StreamOnchainContentCheckpoint private checkpoint;
    StreamSchemaDocumentStore private store;
    StreamFinalityArtifactCoverage private artifacts;
    LeafManifestArchiveBoundary private archive;
    StreamContentLeafManifest private verifier;

    function setUp() public {
        core = new CheckpointCoreBoundary();
        router = new CheckpointRouterBoundary(address(core));
        core.configure(address(router), address(new CheckpointEntropyBoundary()));
        inventory = new StreamCollectionTokenInventory(
            address(core), address(0), _gas("TOKEN_INVENTORY_CORE_READ_GAS", 100_000, 1)
        );
        checkpoint = new StreamOnchainContentCheckpoint(
            address(core),
            address(router),
            address(inventory),
            address(0),
            _gas("CONTENT_CHECKPOINT_READ_GAS", 250_000, 1),
            _gas("CONTENT_CHECKPOINT_RENDER_GAS", 2_000_000, 1)
        );
        address governance = address(new LeafManifestGovernanceBoundary());
        store = new StreamSchemaDocumentStore();
        address schema = address(new LeafManifestSchemaBoundary(address(store), governance));
        archive = new LeafManifestArchiveBoundary(address(core), governance);
        address predicted =
            mvm.computeCreateAddress(address(this), uint256(mvm.getNonce(address(this))) + 1);
        artifacts = new StreamFinalityArtifactCoverage(
            address(core),
            address(archive),
            schema,
            address(store),
            predicted,
            governance,
            IStreamGasParameterHost.GasParameterConfig(
                "FINALITY_ARTIFACT_DEPENDENCY_READ_GAS", 300_000, 300_000, 2
            )
        );
        address finality =
            address(new LeafManifestFinalityBoundary(address(core), address(artifacts)));
        require(finality == predicted, "fixed construction order");
        // Exact single Core pointer read is a boundary; actual aggregator validates its reciprocal binding.
        bytes32 kind = keccak256("ARTWORK_FINALITY_REGISTRY");
        mvm.mockCall(
            address(core),
            abi.encodeCall(IStreamCorePointers.getSatellitePointer, (kind)),
            abi.encode(
                finality,
                finality.codehash,
                false,
                kind,
                bytes4(0),
                address(0),
                uint8(1),
                bytes32(0),
                bytes32(0),
                uint64(1)
            )
        );
        verifier = new StreamContentLeafManifest(
            address(core),
            address(checkpoint),
            address(artifacts),
            address(0),
            _gas("CONTENT_LEAF_MANIFEST_READ_GAS", 2_000_000, 2)
        );
    }

    function _gas(string memory name, uint256 value, uint8 failure)
        private
        pure
        returns (IStreamGasParameterHost.GasParameterConfig memory)
    {
        return IStreamGasParameterHost.GasParameterConfig(name, value, 50_000, failure);
    }

    function _checkpoint(uint256 count) private returns (bytes32 hash) {
        core.setCount(count);
        uint256[] memory tokens = new uint256[](count);
        for (uint256 i; i < count; ++i) {
            tokens[i] = (i + 1) * 2;
        }
        inventory.appendCollectionTokens(1, tokens);
        hash = checkpoint.beginCollectionCheckpoint(1);
        for (uint256 i; i < count;) {
            uint256 take = count - i;
            if (take > 8) take = 8;
            IStreamOnchainContentCheckpoint.TokenPayload[] memory batch =
                new IStreamOnchainContentCheckpoint.TokenPayload[](take);
            for (uint256 j; j < take; ++j) {
                batch[j] = IStreamOnchainContentCheckpoint.TokenPayload(
                    tokens[i + j], "", router.animation(tokens[i + j])
                );
            }
            checkpoint.appendCheckpointTokens(hash, batch);
            i += take;
        }
    }

    function _bytes(bytes32 hash) private view returns (bytes memory) {
        IStreamOnchainContentCheckpoint.Plan memory p = checkpoint.requireCurrentCheckpoint(hash);
        StreamTokenContentLeaf[] memory leaves = new StreamTokenContentLeaf[](p.tokenCount);
        for (uint256 i; i < leaves.length; ++i) {
            leaves[i] = checkpoint.checkpointLeaf(hash, i);
        }
        // Independent normal Solidity ABI encoding, including its dynamic-array offset and count.
        return abi.encode(
            keccak256("STREAM_TOKEN_CONTENT_LEAF_MANIFEST_V1"),
            block.chainid,
            address(core),
            address(checkpoint),
            hash,
            uint256(1),
            p.contentRoot,
            p.tokenCount,
            leaves
        );
    }

    function _archive(bytes memory raw, bytes32 schema, bytes32 canon)
        private
        returns (bytes32 artifact, bytes32 coverage)
    {
        F.Artifact memory a;
        a.artistId = ARTIST;
        a.schemaId = schema;
        a.canonicalizationId = canon;
        a.hashAlgorithm = 1;
        a.contentHash = keccak256(raw);
        a.byteLength = uint64(raw.length);
        uint256 count = (raw.length + 8191) / 8192;
        a.chunkHashes = new bytes32[](count);
        a.chunkLengths = new uint32[](count);
        for (uint256 i; i < count; ++i) {
            uint256 offset = i * 8192;
            uint256 take = raw.length - offset;
            if (take > 8192) take = 8192;
            bytes memory part = new bytes(take);
            for (uint256 j; j < take; ++j) {
                part[j] = raw[offset + j];
            }
            address pointer;
            (a.chunkHashes[i], pointer) = store.publishChunk(part);
            a.chunkLengths[i] = uint32(take);
            archive.add(a.chunkHashes[i], pointer);
        }
        artifact = artifacts.recordArtifact(a);
        bytes32 plan = artifacts.beginCoverage(
            artifact, keccak256("archive family A"), keccak256("archive family B")
        );
        for (uint32 i; i < count; ++i) {
            coverage = artifacts.coverNextChunk(plan, i, a.chunkHashes[i]);
        }
    }

    function _begin(bytes32 cp, bytes memory raw)
        private
        returns (bytes32 plan, bytes32 artifact, bytes32 coverage)
    {
        (artifact, coverage) = _archive(raw, verifier.SCHEMA_ID(), verifier.CANONICALIZATION_ID());
        plan = verifier.beginManifest(cp, artifact, coverage, ARTIST);
    }

    function testCompleteManifestExactRecordAndEvents() public {
        bytes32 cp = _checkpoint(3);
        bytes memory raw = _bytes(cp);
        (bytes32 plan, bytes32 artifact, bytes32 coverage) = _begin(cp, raw);
        require(verifier.verifyNextLeaves(plan, 1) == 0, "incomplete cannot publish evidence");
        vm.recordLogs();
        bytes32 record = verifier.verifyNextLeaves(plan, 2);
        IStreamContentLeafManifest.Manifest memory m =
            verifier.requireCurrentManifest(record, ARTIST);
        require(
            m.checkpointHash == cp && m.artifactHash == artifact && m.coverageHash == coverage
                && m.manifestHash == keccak256(raw) && m.tokenCount == 3
                && m.byteLength == raw.length,
            "actual preserved identity"
        );
        require(m.contentRoot == checkpoint.requireCurrentCheckpoint(cp).contentRoot, "exact root");
        require(
            record
                == keccak256(
                    abi.encode(keccak256("6529STREAM_CONTENT_LEAF_MANIFEST_VERIFIED_V1"), plan)
                ),
            "record preimage"
        );
        Vm.Log[] memory logs = vm.getRecordedLogs();
        require(
            logs.length == 2 && logs[1].emitter == address(verifier) && logs[1].topics[1] == record
                && logs[1].topics[2] == plan && keccak256(logs[1].data) == keccak256(abi.encode(m)),
            "permanent event"
        );
        require(
            verifier.beginManifest(cp, artifact, coverage, ARTIST) == plan
                && verifier.manifestPlan(plan).recordHash == record,
            "idempotent begin retains completion"
        );
    }

    function testCrossChunkLeafAndPartitionIndependentCompletion() public {
        bytes32 cp = _checkpoint(86); // Leaf83 spans bytes16256..16447 across the second chunk boundary.
        (bytes32 plan,,) = _begin(cp, _bytes(cp));
        for (uint256 i; i < 5; ++i) {
            verifier.verifyNextLeaves(plan, 16);
        }
        uint256 snapshot = vm.snapshotState();
        bytes32 first = verifier.verifyNextLeaves(plan, 6);
        require(vm.revertToState(snapshot), "restore");
        verifier.verifyNextLeaves(plan, 3);
        bytes32 second = verifier.verifyNextLeaves(plan, 3);
        require(
            first == second && verifier.requireCurrentManifest(second, ARTIST).tokenCount == 86,
            "partition-independent exact record"
        );
    }

    function testWrongLeafRollsBackWholeBatch() public {
        bytes32 cp = _checkpoint(3);
        bytes memory raw = _bytes(cp);
        raw[320 + 192 + 191] ^= 0x01;
        (bytes32 plan,,) = _begin(cp, raw);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamContentLeafManifest.LeafManifestMismatch.selector, uint256(1)
            )
        );
        verifier.verifyNextLeaves(plan, 3);
        require(
            verifier.manifestPlan(plan).nextIndex == 0
                && verifier.manifestPlan(plan).recordHash == 0,
            "batch rollback"
        );
    }

    function testFuzzAllSixLeafFieldsAreCompared(uint8 choice, uint8 byteIndex) public {
        bytes32 cp = _checkpoint(1);
        bytes memory raw = _bytes(cp);
        uint256 field = uint256(choice) % 6;
        raw[320 + field * 32 + uint256(byteIndex) % 32] ^= 0x01;
        (bytes32 plan,,) = _begin(cp, raw);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamContentLeafManifest.LeafManifestMismatch.selector, uint256(0)
            )
        );
        verifier.verifyNextLeaves(plan, 1);
        require(verifier.manifestPlan(plan).nextIndex == 0, "no unverified field");
    }

    function testChainAndDependencyChangesDoNotEraseHistoricalRecord() public {
        bytes32 cp = _checkpoint(1);
        (bytes32 plan,,) = _begin(cp, _bytes(cp));
        bytes32 record = verifier.verifyNextLeaves(plan, 1);
        uint256 chain = verifier.deploymentChainId();
        vm.chainId(chain + 1);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamContentLeafManifest.InvalidLeafManifest.selector)
        );
        verifier.requireCurrentManifest(record, ARTIST);
        vm.chainId(chain);
        vm.etch(address(checkpoint), hex"00");
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamContentLeafManifest.LeafManifestComponentChanged.selector,
                address(checkpoint)
            )
        );
        verifier.requireCurrentManifest(record, ARTIST);
        require(verifier.manifestRecord(record).tokenCount == 1, "history remains inspectable");
    }

    function testFuzzEveryHeaderWordIsExact(uint8 choice, bytes32 replacement) public {
        bytes32 cp = _checkpoint(1);
        bytes memory raw = _bytes(cp);
        uint256 index = uint256(choice) % 10;
        bytes32 old;
        assembly ("memory-safe") { old := mload(add(add(raw, 32), mul(index, 32))) }
        if (replacement == old) replacement = bytes32(uint256(old) ^ 1);
        assembly ("memory-safe") { mstore(add(add(raw, 32), mul(index, 32)), replacement) }
        (bytes32 a, bytes32 c) = _archive(raw, verifier.SCHEMA_ID(), verifier.CANONICALIZATION_ID());
        vm.expectRevert(
            abi.encodeWithSelector(IStreamContentLeafManifest.InvalidLeafManifest.selector)
        );
        verifier.beginManifest(cp, a, c, ARTIST);
    }

    function testSchemaCanonicalizationAndTrailingBytesRejected() public {
        bytes32 cp = _checkpoint(1);
        bytes memory raw = _bytes(cp);
        for (uint256 i; i < 3; ++i) {
            (bytes32 a, bytes32 c) = _archive(
                i == 2 ? abi.encodePacked(raw, bytes1(0)) : raw,
                i == 0 ? bytes32(uint256(8)) : verifier.SCHEMA_ID(),
                i == 1 ? bytes32(uint256(9)) : verifier.CANONICALIZATION_ID()
            );
            vm.expectRevert(
                abi.encodeWithSelector(IStreamContentLeafManifest.InvalidLeafManifest.selector)
            );
            verifier.beginManifest(cp, a, c, ARTIST);
        }
    }

    function testStaleArchiveBlocksCompletionAndRefreshRetainsOriginalIdentity() public {
        bytes32 cp = _checkpoint(3);
        (bytes32 plan, bytes32 artifact, bytes32 coverage) = _begin(cp, _bytes(cp));
        verifier.verifyNextLeaves(plan, 1);
        archive.advanceEpoch();
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamContentLeafManifest.LeafManifestReadFailed.selector,
                address(artifacts),
                IStreamFinalityArtifactCoverage.requireArtifactCoverage.selector
            )
        );
        verifier.verifyNextLeaves(plan, 2);
        require(verifier.manifestPlan(plan).nextIndex == 1, "late stale archive rollback");
        F.Artifact memory a = artifacts.artifact(artifact);
        for (uint32 i; i < a.chunkHashes.length; ++i) {
            artifacts.refreshNextChunk(coverage, i, a.chunkHashes[i]);
        }
        bytes32 record = verifier.verifyNextLeaves(plan, 2);
        require(
            verifier.requireCurrentManifest(record, ARTIST).coverageHash == coverage,
            "stable completion, not mutable validation head"
        );
    }

    function testNewMintBlocksCurrentAdmissionButRetainsHistory() public {
        bytes32 cp = _checkpoint(1);
        (bytes32 plan,,) = _begin(cp, _bytes(cp));
        bytes32 record = verifier.verifyNextLeaves(plan, 1);
        core.setCount(2);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamContentLeafManifest.LeafManifestReadFailed.selector,
                address(checkpoint),
                IStreamOnchainContentCheckpoint.requireCurrentCheckpoint.selector
            )
        );
        verifier.requireCurrentManifest(record, ARTIST);
        require(verifier.manifestRecord(record).tokenCount == 1, "history survives growth");
    }

    function testChunkCodeMutationRejectedWithoutLosingPriorProgress() public {
        bytes32 cp = _checkpoint(3);
        (bytes32 plan, bytes32 artifact,) = _begin(cp, _bytes(cp));
        verifier.verifyNextLeaves(plan, 1);
        (address pointer,) = artifacts.artifactChunk(artifact, 0);
        vm.etch(pointer, hex"00");
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamContentLeafManifest.LeafManifestComponentChanged.selector, pointer
            )
        );
        verifier.verifyNextLeaves(plan, 2);
        require(verifier.manifestPlan(plan).nextIndex == 1, "prior progress retained");
    }

    function testInvalidBatchUnknownPlanWrongArtistAndDuplicateCompletion() public {
        bytes32 cp = _checkpoint(1);
        (bytes32 plan,,) = _begin(cp, _bytes(cp));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamContentLeafManifest.LeafManifestUnknown.selector, bytes32(0)
            )
        );
        verifier.verifyNextLeaves(0, 1);
        for (uint256 i; i < 3; ++i) {
            uint256 count = i == 0 ? 0 : i == 1 ? 2 : 17;
            vm.expectRevert(
                abi.encodeWithSelector(IStreamContentLeafManifest.LeafManifestBatch.selector, count)
            );
            verifier.verifyNextLeaves(plan, count);
        }
        bytes32 record = verifier.verifyNextLeaves(plan, 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamContentLeafManifest.LeafManifestBatch.selector, uint256(1)
            )
        );
        verifier.verifyNextLeaves(plan, 1);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamContentLeafManifest.InvalidLeafManifest.selector)
        );
        verifier.requireCurrentManifest(record, bytes32(uint256(2)));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamContentLeafManifest.LeafManifestUnknown.selector, bytes32(0)
            )
        );
        verifier.manifestRecord(0);
    }

    function testActualSafeAllTwentySixSelectors() public {
        bytes32 cp = _checkpoint(1);
        (bytes32 a, bytes32 c) =
            _archive(_bytes(cp), verifier.SCHEMA_ID(), verifier.CANONICALIZATION_ID());
        uint256[] memory keys = new uint256[](2);
        keys[0] = 0x652931;
        keys[1] = 0x652932;
        address[] memory owners = new address[](2);
        owners[0] = safeVm.addr(keys[0]);
        owners[1] = safeVm.addr(keys[1]);
        OfficialSafe account = createOfficialSafe(deploySafeComponents("1.4.1"), owners, 2, 31);
        require(
            executeSafe(
                account,
                keys,
                address(verifier),
                0,
                abi.encodeCall(verifier.beginManifest, (cp, a, c, ARTIST)),
                0
            ),
            "Safe begin"
        );
        bytes32 plan = verifier.beginManifest(cp, a, c, ARTIST);
        require(
            executeSafe(
                account,
                keys,
                address(verifier),
                0,
                abi.encodeCall(verifier.verifyNextLeaves, (plan, 1)),
                0
            ),
            "Safe advance"
        );
        bytes32 record = verifier.manifestPlan(plan).recordHash;
        require(
            executeSafe(
                account,
                keys,
                address(verifier),
                0,
                abi.encodeCall(verifier.requireCurrentManifest, (record, ARTIST)),
                0
            ),
            "Safe current read"
        );
        require(
            executeSafe(
                account,
                keys,
                address(verifier),
                0,
                abi.encodeCall(verifier.manifestRecord, (record)),
                0
            ),
            "Safe historic read"
        );
        bytes[] memory reads = new bytes[](21);
        reads[0] = abi.encodeCall(verifier.core, ());
        reads[1] = abi.encodeCall(verifier.contentCheckpoint, ());
        reads[2] = abi.encodeCall(verifier.artifactCoverage, ());
        reads[3] = abi.encodeCall(verifier.checkpointCodeHash, ());
        reads[4] = abi.encodeCall(verifier.coverageCodeHash, ());
        reads[5] = abi.encodeCall(verifier.deploymentChainId, ());
        reads[6] = abi.encodeCall(verifier.SCHEMA_ID, ());
        reads[7] = abi.encodeCall(verifier.CANONICALIZATION_ID, ());
        reads[8] = abi.encodeCall(verifier.DEPENDENCY_READ_GAS, ());
        reads[9] = abi.encodeCall(verifier.MAX_VERIFY_BATCH, ());
        reads[10] = abi.encodeCall(
            verifier.supportsInterface, (type(IStreamContentLeafManifest).interfaceId)
        );
        reads[11] = abi.encodeCall(verifier.manifestPlan, (plan));
        reads[12] = abi.encodeCall(verifier.gasParameter, (verifier.DEPENDENCY_READ_GAS()));
        reads[13] = abi.encodeCall(verifier.gasParameterInfo, (verifier.DEPENDENCY_READ_GAS()));
        reads[14] = abi.encodeCall(verifier.gasParameterIds, ());
        reads[15] = abi.encodeCall(verifier.governanceAuthority, ());
        reads[16] = abi.encodeCall(verifier.GAS_PARAMETER_SCHEMA_VERSION, ());
        reads[17] = abi.encodeCall(verifier.FAILURE_CLASS_NONE, ());
        reads[18] = abi.encodeCall(verifier.FAILURE_CLASS_FORWARDING_CAP, ());
        reads[19] = abi.encodeCall(verifier.FAILURE_CLASS_FAIL_CLOSED_PRECHECK, ());
        reads[20] = abi.encodeCall(verifier.FAILURE_CLASS_MIN_GAS_GATE, ());
        for (uint256 i; i < reads.length; ++i) {
            require(executeSafe(account, keys, address(verifier), 0, reads[i], 0), "Safe getter");
        }
        bytes32 gasId = verifier.DEPENDENCY_READ_GAS();
        vm.prank(address(account));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterNotAuthority.selector, address(account)
            )
        );
        verifier.raiseGasParameter(gasId, 4_000_000);
    }

    function testLowParentGasFailsBeforeDependencyRead() public {
        bytes32 cp = _checkpoint(1);
        (bytes32 plan,,) = _begin(cp, _bytes(cp));
        (bool ok, bytes memory result) = address(verifier).call{ gas: 150_000 }(
            abi.encodeCall(verifier.verifyNextLeaves, (plan, 1))
        );
        require(
            !ok && result.length == 68
                && bytes4(result) == IStreamContentLeafManifest.LeafManifestParentGas.selector,
            "explicit precheck"
        );
        require(verifier.manifestPlan(plan).nextIndex == 0, "no partial progress");
    }
}
