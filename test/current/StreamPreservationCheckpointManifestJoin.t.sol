// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/PreservationPolicyContentFixtureV1.sol";
import { OfficialSafe } from "../helpers/OfficialSafeFixture.sol";
import {
    StreamPreservationPolicyOutputManifestV1 as JoinManifest
} from "../../smart-contracts/domains/finality/StreamPreservationPolicyOutputManifestV1.sol";
import {
    StreamScopedPreservationPolicyContentCheckpointV1 as JoinCheckpoint
} from "../../smart-contracts/domains/finality/StreamScopedPreservationPolicyContentCheckpointV1.sol";
import {
    IStreamPreservationPolicyOutputManifestV1 as JoinV
} from "../../smart-contracts/interfaces/stream/finality/IStreamPreservationPolicyOutputManifestV1.sol";
import {
    StreamPreservationPolicyOutputSchemasV1 as JoinDefinitions
} from "../../smart-contracts/domains/finality/StreamPreservationPolicyOutputSchemasV1.sol";
import {
    StreamFinalityArtifactCoverage as JoinCoverage
} from "../../smart-contracts/domains/preservation/StreamFinalityArtifactCoverage.sol";
import {
    IStreamFinalityArtifactCoverage as JoinCoverageInterface
} from "../../smart-contracts/interfaces/stream/preservation/IStreamFinalityArtifactCoverage.sol";
import {
    StreamFinalityArtifactTypes as JoinF
} from "../../smart-contracts/interfaces/stream/preservation/StreamFinalityArtifactTypes.sol";
import {
    IStreamSchemaRegistry as JoinSchema
} from "../../smart-contracts/interfaces/stream/metadata/IStreamSchemaRegistry.sol";
import {
    LeafManifestArchiveBoundary as JoinArchiveBoundary,
    LeafManifestFinalityBoundary as JoinFinalityBoundary
} from "../helpers/scoped-preservation-boundaries/StreamContentLeafManifestBoundaries.sol";
import {
    LeafManifestVm as JoinVm
} from "../helpers/scoped-preservation-boundaries/StreamContentLeafManifestVm.sol";

interface PortableJoinVm {
    function createDir(string calldata path, bool recursive) external;
    function dumpState(string calldata path) external;
}

/// @notice Real V1 checkpoint -> exact full-row manifest -> SSTORE2 artifact/coverage -> verifier.
/// @dev Native entropy policies/finalization, factory CREATE, membership, selection, checkpoint,
/// Schema/Store, ArtifactCoverage and manifest verification are actual contracts. Preservation
/// output and per-version Registry admission are authenticated typed boundaries, seeded by the
/// inherited Router/Renderer. Core identities, Artist authorization, scoped governance, selected
/// Finality and independent archival-family receipts remain the named inherited boundaries.
/// This does not claim actual preservation rendering, Artist, real governance/finality ceremony,
/// independent archival providers, or transaction-gas acceptance. No frozen suite cap is changed.
contract StreamPreservationCheckpointManifestJoinTest is PreservationPolicyContentFixtureV1 {
    JoinVm private constant jvm = JoinVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    PortableJoinVm private constant pvm =
        PortableJoinVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    bytes32 private constant JOIN_ARTIST = keccak256("artist");
    bytes32 private constant MANIFEST_READ =
        keccak256("6529STREAM_GGP_STATIC_OUTPUT_MANIFEST_READ_GAS");
    uint256 private constant JOIN_TX_CEILING = 16777216;
    JoinCoverage private joinCoverage;
    JoinArchiveBoundary private joinArchive;
    StreamSchemaDocumentStore private joinStore;

    struct Joined {
        Capture capture;
        JoinManifest verifier;
        bytes raw;
        bytes32 artifact;
        bytes32 coverage;
        bytes32 plan;
    }

    struct JoinModel {
        uint64 accepted;
        bytes32 expectedRecord;
        bytes32 checkpointHistory;
        bytes32 artifactHistory;
        bytes32 coverageHistory;
        bytes32 manifestHistory;
        bool complete;
    }

    struct DriftSnapshot {
        bool admission;
        uint256 index;
        bytes admissionBytes;
        string json;
        string html;
    }

    event OutputManifestVerified(
        uint16 schemaVersion,
        bytes32 indexed recordHash,
        bytes32 indexed planHash,
        JoinV.Manifest manifest
    );

    event CappedJoinCall(bytes4 indexed selector, uint256 callerGasSpent, uint256 ceiling);
    event StatefulJoinSchedule(uint8 indexed schedule, bytes32 indexed plan, bytes32 record);

    event PortableJoinCut(
        address manifest,
        address checkpoint,
        address core,
        bytes32 checkpointId,
        bytes32 artifact,
        bytes32 coverage,
        bytes32 plan,
        bytes32 expectedManifestHash,
        uint256 outputCount,
        uint256 chainId,
        uint256 timestamp,
        uint256 blockNumber,
        uint256 gasLimit
    );

    event PortableSafeJoinCut(
        address safe,
        address manifest,
        bytes32 checkpointId,
        bytes32 artifact,
        bytes32 coverage,
        bytes32 plan,
        bytes32 expectedManifestHash,
        uint256 outputCount,
        bytes tamperedTransaction,
        bytes beginTransaction,
        bytes verifyTransaction,
        uint256 chainId,
        uint256 timestamp,
        uint256 gasLimit
    );

    function testCheckpointManifestJoinAllCanonicalScopesAndOriginalGasMismatch() external {
        _joinFixture();
        for (uint8 kind; kind < 4; ++kind) {
            Joined memory j = _prepareJoin(kind, kind == 0);
            vm.recordLogs();
            bytes32 record = j.verifier.verifyNextOutputs(j.plan, j.capture.producers.length);
            Vm.Log[] memory emitted = vm.getRecordedLogs();
            _assertJoined(j, record);
            JoinV.Manifest memory m = j.verifier.manifestRecord(record);
            vm.recordLogs();
            emit OutputManifestVerified(1, record, j.plan, m);
            Vm.Log[] memory oracle = vm.getRecordedLogs();
            require(
                emitted.length == 2 && emitted[1].emitter == address(j.verifier),
                "real advance and completion events"
            );
            require(
                keccak256(abi.encode(emitted[1].topics)) == keccak256(abi.encode(oracle[0].topics))
                    && keccak256(emitted[1].data) == keccak256(oracle[0].data),
                "literal full manifest completion event"
            );
            require(
                j.verifier.beginManifest(j.capture.id, j.artifact, j.coverage, JOIN_ARTIST)
                        == j.plan && j.verifier.manifestPlan(j.plan).recordHash == record,
                "same original input retains completed plan"
            );
        }
    }

    function testCheckpointManifestJoinAdmissionAndOutputDriftPreserveHistoryAndRestore() external {
        _joinFixture();
        Joined memory j = _prepareJoin(2, false);
        bytes32 record = j.verifier.verifyNextOutputs(j.plan, 2);
        _assertJoined(j, record);
        bytes32 savedCheckpoint = _history(j.capture);
        bytes32 savedManifest = keccak256(abi.encode(j.verifier.manifestRecord(record)));
        PreservationTypes.Admission memory admitted = _admission(j.capture, 1);
        bytes memory originalAdmission = abi.encode(_binding(j.capture, 1), admitted);
        admitted.goldenHash = keccak256("different typed executed-golden admission");
        _setAdmission(j.capture, 1, abi.encode(_binding(j.capture, 1), admitted));
        _expectCheckpointFailure(j);
        j.verifier.requireCurrentManifest(record, JOIN_ARTIST);
        require(
            _history(j.capture) == savedCheckpoint
                && keccak256(abi.encode(j.verifier.manifestRecord(record))) == savedManifest,
            "admission currentness refusal cannot rewrite either historical receipt"
        );
        _setAdmission(j.capture, 1, originalAdmission);
        _assertJoined(j, record);
        uint256 token = j.capture.host.outputAt(j.capture.id, 1).leaf.tokenId;
        string memory json = j.capture.producers[1].preservationTokenJSON(token);
        string memory html = j.capture.producers[1].preservationTokenHTML(token);
        j.capture.producers[1].setBytes(token, string(abi.encodePacked(" ", json)), html);
        _expectCheckpointFailure(j);
        j.verifier.requireCurrentManifest(record, JOIN_ARTIST);
        require(
            _history(j.capture) == savedCheckpoint
                && keccak256(abi.encode(j.verifier.manifestRecord(record))) == savedManifest,
            "changed actual producer bytes fail current admission and preserve saved full rows"
        );
        j.capture.producers[1].setBytes(token, json, html);
        _assertJoined(j, record);
    }

    function testCheckpointManifestJoinLateCoverageRollbackAndIdenticalCalldataRetry() external {
        _joinFixture();
        Joined memory j = _prepareJoin(3, false);
        require(j.verifier.verifyNextOutputs(j.plan, 1) == 0, "real partial full-row verification");
        bytes memory input = abi.encodeCall(JoinV.verifyNextOutputs, (j.plan, uint256(1)));
        bytes32 savedPlan = keccak256(abi.encode(j.verifier.manifestPlan(j.plan)));
        bytes32 savedCheckpoint = _history(j.capture);
        bytes32 savedCoverage = keccak256(abi.encode(joinCoverage.coverage(j.coverage)));
        bytes32 savedArtifact = keccak256(abi.encode(joinCoverage.artifact(j.artifact)));
        joinArchive.advanceEpoch();
        (bool ok, bytes memory result) = address(j.verifier).call(input);
        require(
            !ok
                && keccak256(result)
                    == keccak256(
                        abi.encodeWithSelector(
                            JoinV.OutputManifestReadFailed.selector,
                            address(joinCoverage),
                            JoinCoverageInterface.requireArtifactCoverage.selector
                        )
                    ),
            "real final currentness path reaches stale artifact coverage"
        );
        require(
            keccak256(abi.encode(j.verifier.manifestPlan(j.plan))) == savedPlan
                && j.verifier.manifestPlan(j.plan).nextIndex == 1
                && j.verifier.manifestPlan(j.plan).recordHash == 0,
            "late rejection atomically rolls the tentative cursor back"
        );
        require(
            _history(j.capture) == savedCheckpoint
                && keccak256(abi.encode(joinCoverage.coverage(j.coverage))) == savedCoverage
                && keccak256(abi.encode(joinCoverage.artifact(j.artifact))) == savedArtifact,
            "no checkpoint, original coverage or artifact history mutation"
        );
        JoinF.Artifact memory a = joinCoverage.artifact(j.artifact);
        for (uint32 i; i < a.chunkHashes.length; ++i) {
            joinCoverage.refreshNextChunk(j.coverage, i, a.chunkHashes[i]);
        }
        (ok, result) = address(j.verifier).call(input);
        require(ok, "same saved verifier calldata retries after actual complete coverage refresh");
        bytes32 record = abi.decode(result, (bytes32));
        _assertJoined(j, record);
        require(
            keccak256(abi.encode(joinCoverage.coverage(j.coverage))) == savedCoverage
                && joinCoverage.currentCoverageValidation(j.coverage).validationEpoch
                    == joinArchive.coverageValidationEpoch(),
            "new validation head preserves original immutable coverage receipt"
        );
    }

    function testCheckpointManifestJoinFreshBudgetsFitOriginalTransactionCeiling() external {
        (Joined memory j, bytes32 portablePlan) = _preparePortableJoin(1);
        pvm.createDir("artifacts/native-assembly", true);
        pvm.dumpState("artifacts/native-assembly/preservation-join-portable-v1.dump.json");
        emit PortableJoinCut(
            address(j.verifier),
            address(j.capture.host),
            address(core),
            j.capture.id,
            j.artifact,
            j.coverage,
            portablePlan,
            keccak256(abi.encode(_expectedManifest(j))),
            j.capture.producers.length,
            block.chainid,
            block.timestamp,
            block.number,
            block.gaslimit
        );
        bytes memory input = abi.encodeCall(
            JoinV.beginManifest, (j.capture.id, j.artifact, j.coverage, JOIN_ARTIST)
        );
        uint256 beforeGas = gasleft();
        (bool ok, bytes memory result) =
            address(j.verifier).call{gas: JOIN_TX_CEILING}(input);
        uint256 spent = beforeGas - gasleft();
        require(ok && spent + 100000 < JOIN_TX_CEILING, "capped actual begin call");
        emit CappedJoinCall(JoinV.beginManifest.selector, spent, JOIN_TX_CEILING);
        j.plan = abi.decode(result, (bytes32));
        require(
            j.plan == portablePlan && j.plan == _planHash(j.verifier, _expectedManifest(j)),
            "capped full plan identity"
        );
        input = abi.encodeCall(JoinV.verifyNextOutputs, (j.plan, j.capture.producers.length));
        beforeGas = gasleft();
        (ok, result) = address(j.verifier).call{gas: JOIN_TX_CEILING}(input);
        spent = beforeGas - gasleft();
        require(ok && spent + 100000 < JOIN_TX_CEILING, "capped actual verify call");
        emit CappedJoinCall(JoinV.verifyNextOutputs.selector, spent, JOIN_TX_CEILING);
        _assertJoined(j, abi.decode(result, (bytes32)));
    }

    function _preparePortableJoin(uint8 kind)
        private
        returns (Joined memory j, bytes32 portablePlan)
    {
        _joinFixture();
        j.capture = _capture(_scope(kind), true);
        Preservation original = j.capture.host;
        j.capture.host = Preservation(
            address(
                JoinCheckpoint(
                    _artistArtifactCreate(
                        "smart-contracts/domains/finality/StreamScopedPreservationPolicyContentCheckpointV1.sol:StreamScopedPreservationPolicyContentCheckpointV1",
                        abi.encode(
                            address(scopedSelections),
                            original.entropySourceSet(),
                            original.terminalReadiness(),
                            address(executor),
                            _scopedGas("STATIC_CONTENT_READ_GAS", 8000000, 2),
                            _scopedGas("STATIC_CONTENT_RENDER_GAS", 2000000, 2)
                        )
                    )
                )
            )
        );
        require(
            IStreamGasParameterHost(address(j.capture.host))
                    .gasParameter(keccak256("6529STREAM_GGP_STATIC_CONTENT_READ_GAS"))
                == 8000000
                && IStreamGasParameterHost(address(j.capture.host))
                        .gasParameter(keccak256("6529STREAM_GGP_STATIC_CONTENT_RENDER_GAS"))
                    == 2000000,
            "fresh checkpoint retains readiness read and uses measured render allowance"
        );
        // A later account-state export cannot carry Foundry mock rules. Exercise the
        // stored typed Core and Registry responses before the capped calls.
        StaticRouteVm(address(vm)).clearMockedCalls();
        j.capture.id = j.capture.host.begin(j.capture.selection, keccak256("capped preservation"));
        j.capture.host.append(j.capture.id, _payload(j.capture));
        _assertComplete(j.capture);
        j.raw = _manifestBytes(j.capture);
        (j.artifact, j.coverage) = _archiveManifest(j.raw);
        j.verifier = _manifest(j.capture, 12000000);
        (uint256 value, uint256 floor, uint8 failure, uint64 revision) =
            j.verifier.gasParameterInfo(MANIFEST_READ);
        require(
            value == 12000000 && floor == 100000 && failure == 2 && revision == 1,
            "fresh verifier genesis is lawful without lowering a governed parameter"
        );
        portablePlan = _planHash(j.verifier, _expectedManifest(j));
    }

    function testCheckpointManifestJoinOfficialSafeColdTransactionCut() external {
        (Joined memory j, bytes32 portablePlan) = _preparePortableJoin(1);
        uint256[] memory owners = new uint256[](3);
        owners[0] = 0xA1101;
        owners[1] = 0xA1102;
        owners[2] = 0xA1103;
        uint256[] memory signers = new uint256[](2);
        signers[0] = owners[0];
        signers[1] = owners[1];
        SafeComponents memory components = deploySafeComponents("1.4.1");
        OfficialSafe account = createOfficialSafe(components, safeOwnerAddresses(owners), 2, 6529);
        require(
            account.getThreshold() == 2 && account.getOwners().length == 3
                && account.nonce() == 0 && address(account).balance == 0
                && keccak256(bytes(account.VERSION())) == keccak256("1.4.1"),
            "official zero-value threshold Safe"
        );
        bytes memory beginCall = abi.encodeCall(
            JoinV.beginManifest, (j.capture.id, j.artifact, j.coverage, JOIN_ARTIST)
        );
        bytes memory verifyCall = abi.encodeCall(
            JoinV.verifyNextOutputs, (portablePlan, j.capture.producers.length)
        );
        bytes memory beginSignatures = _safeJoinSignatures(
            account, signers, address(j.verifier), beginCall, 0
        );
        bytes memory beginTransaction =
            _safeJoinTransaction(address(j.verifier), beginCall, beginSignatures);
        bytes memory verifyTransaction = _safeJoinTransaction(
            address(j.verifier),
            verifyCall,
            _safeJoinSignatures(account, signers, address(j.verifier), verifyCall, 1)
        );
        bytes memory tamperedCall = abi.encodeCall(
            JoinV.beginManifest,
            (bytes32(uint256(j.capture.id) ^ 1), j.artifact, j.coverage, JOIN_ARTIST)
        );
        bytes memory tamperedTransaction =
            _safeJoinTransaction(address(j.verifier), tamperedCall, beginSignatures);
        pvm.createDir("artifacts/native-assembly", true);
        pvm.dumpState("artifacts/native-assembly/preservation-safe-join-portable-v1.dump.json");
        emit PortableSafeJoinCut(
            address(account),
            address(j.verifier),
            j.capture.id,
            j.artifact,
            j.coverage,
            portablePlan,
            keccak256(abi.encode(_expectedManifest(j))),
            j.capture.producers.length,
            tamperedTransaction,
            beginTransaction,
            verifyTransaction,
            block.chainid,
            block.timestamp,
            block.gaslimit
        );
        (bool tampered,) = address(account).call{gas: JOIN_TX_CEILING}(tamperedTransaction);
        require(
            !tampered && account.nonce() == 0
                && j.verifier.manifestPlan(portablePlan).manifest.tokenCount == 0,
            "tampered threshold transaction rolls back Safe nonce and manifest plan"
        );
        _executeSafeJoin(account, beginTransaction);
        require(
            account.nonce() == 1
                && j.verifier.manifestPlan(portablePlan).manifest.tokenCount
                    == j.capture.producers.length
                && j.verifier.manifestPlan(portablePlan).nextIndex == 0,
            "Safe begins exact manifest plan"
        );
        _executeSafeJoin(account, verifyTransaction);
        j.plan = portablePlan;
        bytes32 record = j.verifier.manifestPlan(portablePlan).recordHash;
        _assertJoined(j, record);
        require(account.nonce() == 2 && address(account).balance == 0, "two zero-value Safe calls");
    }

    function _safeJoinSignatures(
        OfficialSafe account,
        uint256[] memory signers,
        address target,
        bytes memory callData,
        uint256 nonce
    ) private returns (bytes memory) {
        bytes32 digest = account.getTransactionHash(
            target, 0, callData, 0, 0, 0, 0, address(0), address(0), nonce
        );
        return safeThresholdSignature(signers, digest);
    }

    function _safeJoinTransaction(address target, bytes memory callData, bytes memory signatures)
        private
        pure
        returns (bytes memory)
    {
        return abi.encodeCall(
            OfficialSafe.execTransaction,
            (target, 0, callData, 0, 0, 0, 0, address(0), payable(address(0)), signatures)
        );
    }

    function _executeSafeJoin(OfficialSafe account, bytes memory transaction) private {
        vm.recordLogs();
        (bool ok, bytes memory result) = address(account).call{gas: JOIN_TX_CEILING}(transaction);
        require(ok && result.length == 32 && abi.decode(result, (bool)), "Safe target success");
        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 successes;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == address(account) && logs[i].topics.length != 0
                    && logs[i].topics[0] == keccak256("ExecutionSuccess(bytes32,uint256)")
            ) ++successes;
        }
        require(successes == 1, "actual Safe ExecutionSuccess event");
    }

    /// @dev Separate tests give each schedule a fresh fixture. Together they cover both
    /// invalid counts, both drift orders and either output index.
    function testStatefulJoinSchedule0() external { _exerciseStatefulJoin(0, true); }
    function testStatefulJoinSchedule1() external { _exerciseStatefulJoin(1, true); }
    function testStatefulJoinSchedule2() external { _exerciseStatefulJoin(2, true); }
    function testStatefulJoinSchedule3() external { _exerciseStatefulJoin(3, true); }
    function testStatefulJoinSchedule4() external { _exerciseStatefulJoin(4, true); }
    function testStatefulJoinSchedule5() external { _exerciseStatefulJoin(5, true); }
    function testStatefulJoinSchedule6() external { _exerciseStatefulJoin(6, true); }
    function testStatefulJoinSchedule7() external { _exerciseStatefulJoin(7, true); }

    function testFuzzStatefulJoinMixedValidInvalid(uint256 seed) external {
        _exerciseStatefulJoin(uint8(seed & 7), false);
    }

    function _exerciseStatefulJoin(uint8 schedule, bool thorough) private {
        (Joined memory j, bytes32 expectedPlan) = _preparePortableJoin(2);
        require(j.capture.producers.length == 2, "two independently selected output rows");
        bytes memory beginInput = abi.encodeCall(
            JoinV.beginManifest, (j.capture.id, j.artifact, j.coverage, JOIN_ARTIST)
        );
        (bool ok, bytes memory result) =
            address(j.verifier).call{gas: JOIN_TX_CEILING}(beginInput);
        require(ok && result.length == 32, "bounded initial manifest begin");
        j.plan = abi.decode(result, (bytes32));
        require(j.plan == expectedPlan, "independent expected plan identity");
        JoinModel memory model = JoinModel({
            accepted: 0,
            expectedRecord: keccak256(
                abi.encode(
                    keccak256("6529STREAM_PRESERVATION_POLICY_OUTPUT_MANIFEST_VERIFIED_V1"),
                    expectedPlan
                )
            ),
            checkpointHistory: _history(j.capture),
            artifactHistory: keccak256(abi.encode(joinCoverage.artifact(j.artifact))),
            coverageHistory: keccak256(abi.encode(joinCoverage.coverage(j.coverage))),
            manifestHistory: keccak256(abi.encode(_expectedManifest(j))),
            complete: false
        });
        _assertJoinModel(j, model);

        uint256 invalidBefore = (schedule & 1) == 0 ? 0 : 3;
        _rejectVerify(j, invalidBefore, true);
        _assertJoinModel(j, model);
        require(_acceptVerify(j, 1) == 0, "one accepted row is partial");
        model.accepted = 1;
        _assertJoinModel(j, model);
        require(
            j.verifier.beginManifest(j.capture.id, j.artifact, j.coverage, JOIN_ARTIST)
                == expectedPlan,
            "identical begin retains partial progress"
        );
        _assertJoinModel(j, model);

        uint256 index = uint256(schedule >> 2);
        DriftSnapshot memory first = _applyJoinDrift(j, (schedule & 2) != 0, index, schedule);
        _rejectVerify(j, 1, false);
        _assertJoinModel(j, model);
        _restoreJoinDrift(j, first);
        _rejectVerify(j, (schedule & 1) == 0 ? 2 : 0, true);
        _assertJoinModel(j, model);
        require(_acceptVerify(j, 1) == model.expectedRecord, "restored terminal retry");
        model.accepted = 2;
        model.complete = true;
        _assertJoinModel(j, model);

        DriftSnapshot memory second =
            _applyJoinDrift(j, !first.admission, 1 - index, schedule + 8);
        (ok, result) = address(j.verifier).staticcall{gas: JOIN_TX_CEILING}(
            abi.encodeCall(JoinV.requireCurrentManifest, (model.expectedRecord, JOIN_ARTIST))
        );
        require(
            !ok
                && keccak256(result)
                    == keccak256(
                        abi.encodeWithSelector(
                            JoinV.OutputManifestReadFailed.selector,
                            address(j.capture.host),
                            Preservation.requireCurrentCheckpoint.selector
                        )
                    ),
            "drift invalidates currentness without replacing history"
        );
        _assertJoinModel(j, model);
        _restoreJoinDrift(j, second);
        require(
            keccak256(abi.encode(j.verifier.requireCurrentManifest(model.expectedRecord, JOIN_ARTIST)))
                == model.manifestHistory,
            "restored currentness returns original full row"
        );
        _rejectVerify(j, 1, true);
        require(
            j.verifier.beginManifest(j.capture.id, j.artifact, j.coverage, JOIN_ARTIST)
                == expectedPlan,
            "identical completed begin cannot reset progress"
        );
        _assertJoinModel(j, model);
        if (thorough) _assertJoined(j, model.expectedRecord);
        emit StatefulJoinSchedule(schedule, expectedPlan, model.expectedRecord);
    }

    function _acceptVerify(Joined memory j, uint256 count) private returns (bytes32 record) {
        (bool ok, bytes memory result) = address(j.verifier).call{gas: JOIN_TX_CEILING}(
            abi.encodeCall(JoinV.verifyNextOutputs, (j.plan, count))
        );
        require(ok && result.length == 32, "bounded accepted verification");
        record = abi.decode(result, (bytes32));
    }

    function _rejectVerify(Joined memory j, uint256 count, bool invalidBatch) private {
        (bool ok, bytes memory result) = address(j.verifier).call{gas: JOIN_TX_CEILING}(
            abi.encodeCall(JoinV.verifyNextOutputs, (j.plan, count))
        );
        require(!ok, "invalid verification accepted");
        if (invalidBatch) {
            require(
                keccak256(result)
                    == keccak256(abi.encodeWithSelector(JoinV.OutputManifestBatch.selector, count)),
                "invalid count rejected by original batch rule"
            );
        }
    }

    function _applyJoinDrift(Joined memory j, bool admission, uint256 index, uint256 salt)
        private
        returns (DriftSnapshot memory d)
    {
        d.admission = admission;
        d.index = index;
        if (admission) {
            PreservationTypes.Admission memory altered = _admission(j.capture, index);
            d.admissionBytes = abi.encode(_binding(j.capture, index), altered);
            altered.goldenHash = keccak256(abi.encode("stateful admission drift", salt, index));
            _setAdmission(j.capture, index, abi.encode(_binding(j.capture, index), altered));
        } else {
            uint256 token = scopedSelections.selectionAt(j.capture.selection, index).tokenId;
            d.json = j.capture.producers[index].preservationTokenJSON(token);
            d.html = j.capture.producers[index].preservationTokenHTML(token);
            j.capture.producers[index].setBytes(
                token, string(abi.encodePacked(d.json, " drift")), d.html
            );
        }
    }

    function _restoreJoinDrift(Joined memory j, DriftSnapshot memory d) private {
        if (d.admission) {
            _setAdmission(j.capture, d.index, d.admissionBytes);
        } else {
            uint256 token = scopedSelections.selectionAt(j.capture.selection, d.index).tokenId;
            j.capture.producers[d.index].setBytes(token, d.json, d.html);
        }
    }

    function _assertJoinModel(Joined memory j, JoinModel memory model) private view {
        JoinV.Plan memory actual = j.verifier.manifestPlan(j.plan);
        require(
            actual.manifest.tokenCount == 2 && actual.nextIndex == model.accepted
                && actual.recordHash == (model.complete ? model.expectedRecord : bytes32(0))
                && keccak256(abi.encode(actual.manifest)) == model.manifestHistory,
            "only accepted rows advance the original full manifest plan"
        );
        require(
            _history(j.capture) == model.checkpointHistory
                && keccak256(abi.encode(joinCoverage.artifact(j.artifact)))
                    == model.artifactHistory
                && keccak256(abi.encode(joinCoverage.coverage(j.coverage)))
                    == model.coverageHistory,
            "invalid attempts and input drift preserve checkpoint/artifact history"
        );
        if (model.complete) {
            require(
                keccak256(abi.encode(j.verifier.manifestRecord(model.expectedRecord)))
                    == model.manifestHistory,
                "accepted record remains append-only while currentness changes"
            );
        } else {
            (bool ok,) = address(j.verifier).staticcall(
                abi.encodeCall(JoinV.manifestRecord, (model.expectedRecord))
            );
            require(!ok, "partial progress cannot expose a completed record");
        }
    }

    function _joinFixture() private {
        // Real original native disabled/finalized policies, actual factory/current source routes.
        _scopedFixture(1, true);
        _scopedDocument(
            "STREAM_PRESERVATION_POLICY_OUTPUT_MANIFEST_V1",
            false,
            JoinDefinitions.document(JoinDefinitions.SCHEMA)
        );
        _scopedDocument(
            "STREAM_ABI_PRESERVATION_POLICY_OUTPUT_MANIFEST_V1",
            true,
            JoinDefinitions.document(JoinDefinitions.CANON)
        );
        joinStore = StreamSchemaDocumentStore(schemas.chunkStore());
        joinArchive = JoinArchiveBoundary(
            _artistArtifactCreate(
                "test/helpers/scoped-preservation-boundaries/StreamContentLeafManifestBoundaries.sol:LeafManifestArchiveBoundary",
                abi.encode(address(core), address(executor))
            )
        );
        address predicted =
            jvm.computeCreateAddress(address(this), uint256(jvm.getNonce(address(this))) + 1);
        joinCoverage = JoinCoverage(
            _artistArtifactCreate(
                "smart-contracts/domains/preservation/StreamFinalityArtifactCoverage.sol:StreamFinalityArtifactCoverage",
                abi.encode(
                    address(core),
                    address(joinArchive),
                    address(schemas),
                    address(joinStore),
                    predicted,
                    address(executor),
                    IStreamGasParameterHost.GasParameterConfig(
                        "FINALITY_ARTIFACT_DEPENDENCY_READ_GAS", 300000, 300000, 2
                    )
                )
            )
        );
        address finality = _artistArtifactCreate(
            "test/helpers/scoped-preservation-boundaries/StreamContentLeafManifestBoundaries.sol:LeafManifestFinalityBoundary",
            abi.encode(address(core), address(joinCoverage))
        );
        require(finality == predicted, "actual fixed CREATE dependency binding");
        _scopedPointer(keccak256("ARTWORK_FINALITY_REGISTRY"), finality, bytes4(0));
        require(
            joinCoverage.core() == address(core) && joinCoverage.chunkStore() == address(joinStore)
                && joinCoverage.schemaRegistry() == address(schemas)
                && joinCoverage.archivalCoverage() == address(joinArchive)
                && joinCoverage.finalityRegistry() == finality,
            "all real artifact coverage dependency edges"
        );
    }

    function _prepareJoin(uint8 kind, bool originalMismatch) private returns (Joined memory j) {
        j.capture = _capture(_scope(kind), true);
        j.capture.host.append(j.capture.id, _payload(j.capture));
        _assertComplete(j.capture);
        j.raw = _manifestBytes(j.capture);
        (j.artifact, j.coverage) = _archiveManifest(j.raw);
        if (originalMismatch) _originalGasMismatch(j);
        j.verifier = _manifest(j.capture, 16000000);
        _raiseManifestGas(j.verifier);
        require(
            j.verifier.core() == address(core)
                && j.verifier.contentCheckpoint() == address(j.capture.host)
                && j.verifier.artifactCoverage() == address(joinCoverage)
                && j.verifier.schemaRegistry() == address(schemas)
                && j.verifier.checkpointCodeHash() == address(j.capture.host).codehash
                && j.verifier.coverageCodeHash() == address(joinCoverage).codehash
                && j.verifier.schemaCodeHash() == address(schemas).codehash,
            "real verifier pins checkpoint/coverage/schema"
        );
        j.plan = j.verifier.beginManifest(j.capture.id, j.artifact, j.coverage, JOIN_ARTIST);
        require(
            j.plan == _planHash(j.verifier, _expectedManifest(j)),
            "literal original V1 plan commitment"
        );
    }

    function _originalGasMismatch(Joined memory j) private {
        // Preserve the original 3m -> checkpoint 8m/read,16m/render mismatch as a negative.
        JoinManifest low = _manifest(j.capture, 3000000);
        require(
            IStreamGasParameterHost(address(j.capture.host))
                    .gasParameter(keccak256("6529STREAM_GGP_STATIC_CONTENT_READ_GAS")) == 8000000
                && IStreamGasParameterHost(address(j.capture.host))
                    .gasParameter(keccak256("6529STREAM_GGP_STATIC_CONTENT_RENDER_GAS"))
                == 16000000,
            "original checkpoint parameters are unchanged"
        );
        bytes32 plan = _planHash(low, _expectedManifest(j));
        bytes32 before_ = keccak256(abi.encode(low.manifestPlan(plan)));
        vm.expectRevert(
            abi.encodeWithSelector(
                JoinV.OutputManifestReadFailed.selector,
                address(j.capture.host),
                Preservation.requireCurrentCheckpoint.selector
            )
        );
        low.beginManifest(j.capture.id, j.artifact, j.coverage, JOIN_ARTIST);
        JoinV.Plan memory absent = low.manifestPlan(plan);
        require(
            keccak256(abi.encode(absent)) == before_ && absent.nextIndex == 0
                && absent.recordHash == 0 && absent.manifest.tokenCount == 0,
            "original incompatible read budget produces no plan/cursor/record writes"
        );
        bytes32 record = keccak256(
            abi.encode(
                keccak256("6529STREAM_PRESERVATION_POLICY_OUTPUT_MANIFEST_VERIFIED_V1"), plan
            )
        );
        vm.expectRevert(abi.encodeWithSelector(JoinV.OutputManifestUnknown.selector, record));
        low.manifestRecord(record);
        require(
            low.gasParameter(MANIFEST_READ) == 3000000,
            "negative instance remains at original parameter"
        );
    }

    function _manifest(Capture memory c, uint256 readGas) private returns (JoinManifest) {
        return JoinManifest(
            _artistArtifactCreate(
                "smart-contracts/domains/finality/StreamPreservationPolicyOutputManifestV1.sol:StreamPreservationPolicyOutputManifestV1",
                abi.encode(
                    address(core),
                    address(c.host),
                    address(joinCoverage),
                    address(executor),
                    IStreamGasParameterHost.GasParameterConfig(
                        "STATIC_OUTPUT_MANIFEST_READ_GAS", readGas, 100000, 2
                    )
                )
            )
        );
    }

    function _raiseManifestGas(JoinManifest verifier) private {
        require(
            verifier.DEPENDENCY_READ_GAS() == MANIFEST_READ
                && verifier.governanceAuthority() == address(executor),
            "original fixed GGP identity and authority"
        );
        (uint256 value, uint256 floor, uint8 failure, uint64 revision) =
            verifier.gasParameterInfo(MANIFEST_READ);
        require(
            value == 16000000 && floor == 100000 && failure == 2 && revision == 1,
            "fresh explicit genesis gas configuration"
        );
        // Original StreamGasParameterHost V2 literal scope/state domains; no direct storage write.
        bytes32 scope = keccak256(
            abi.encode(
                bytes32(0x9533611d402c2b44cf950a4a8900d25f6829bfac541dc4d5353094f966bb1a71),
                block.chainid,
                address(verifier),
                MANIFEST_READ
            )
        );
        bytes32 old = _gasState(scope, value, floor, failure, revision);
        bytes32 next = _gasState(scope, uint256(32000000), floor, failure, uint64(2));
        vm.recordLogs();
        executor.execute(
            address(verifier),
            abi.encodeCall(
                IStreamGasParameterHost.raiseGasParameter, (MANIFEST_READ, uint256(32000000))
            ),
            scope,
            old,
            next
        );
        Vm.Log[] memory logs = vm.getRecordedLogs();
        (value, floor, failure, revision) = verifier.gasParameterInfo(MANIFEST_READ);
        require(
            value == 32000000 && floor == 100000 && failure == 2 && revision == 2,
            "actual class1 governed monotonic setter effect"
        );
        require(
            logs.length == 1 && logs[0].emitter == address(verifier) && logs[0].topics.length == 4
                && logs[0].topics[0]
                    == keccak256(
                        "GasParameterUpdated(uint16,bytes32,address,bytes32,uint256,uint256,uint256)"
                    ) && logs[0].topics[1] == MANIFEST_READ
                && logs[0].topics[2] == bytes32(uint256(uint160(address(verifier))))
                && logs[0].topics[3] == bytes32(uint256(1))
                && keccak256(logs[0].data)
                    == keccak256(
                        abi.encode(uint16(2), uint256(16000000), uint256(32000000), uint256(100000))
                    ),
            "original gas setter event and exact active action"
        );
    }

    function _gasState(bytes32 scope, uint256 value, uint256 floor, uint8 failure, uint64 revision)
        private
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                bytes32(0x5059a253d3f7dd63b5d9fd1f0568caf72967f501a3db678b31cefe911334159c),
                scope,
                value,
                floor,
                failure,
                revision
            )
        );
    }

    function _manifestBytes(Capture memory c) private view returns (bytes memory raw) {
        Preservation.Plan memory p = c.host.requireCurrentCheckpoint(c.id);
        Preservation.Output[] memory rows = new Preservation.Output[](p.tokenCount);
        for (uint256 i; i < rows.length; ++i) {
            rows[i] = c.host.outputAt(c.id, i);
        }
        raw = abi.encode(
            JoinDefinitions.SCHEMA,
            block.chainid,
            address(core),
            address(c.host),
            c.id,
            keccak256(abi.encode(p)),
            c.host.entropySourceSet(),
            p.inventoryHash,
            p.policyChainHash,
            c.host.metadataRouter(),
            p.preservationProfile,
            p.scope,
            p.contentRoot,
            p.outputRoot,
            p.tokenCount,
            rows
        );
        require(
            raw.length == 640 + 1152 * rows.length && _word(raw, 18) == bytes32(uint256(608))
                && _word(raw, 19) == bytes32(rows.length),
            "literal original19-word head and dynamic count"
        );
        for (uint256 i; i < rows.length; ++i) {
            require(
                abi.encode(rows[i]).length == 1152
                    && keccak256(_slice(raw, 640 + 1152 * i, 1152))
                        == keccak256(abi.encode(rows[i]))
                    && keccak256(_slice(raw, 640 + 1152 * i + 640, 288))
                        == keccak256(abi.encode(rows[i].preservation))
                    && keccak256(_slice(raw, 640 + 1152 * i + 928, 224))
                        == keccak256(abi.encode(rows[i].preservationAdmission)),
                "all36 original output words, including every binding and admission word"
            );
        }
    }

    function _archiveManifest(bytes memory raw)
        private
        returns (bytes32 artifact, bytes32 coverage)
    {
        JoinF.Artifact memory a;
        a.artistId = JOIN_ARTIST;
        a.schemaId = JoinDefinitions.SCHEMA;
        a.canonicalizationId = JoinDefinitions.CANON;
        a.hashAlgorithm = 1;
        a.contentHash = keccak256(raw);
        a.byteLength = uint64(raw.length);
        uint256 count = (raw.length + 8191) / 8192;
        a.chunkHashes = new bytes32[](count);
        a.chunkLengths = new uint32[](count);
        for (uint256 i; i < count; ++i) {
            uint256 size = raw.length - i * 8192;
            if (size > 8192) size = 8192;
            address pointer;
            (a.chunkHashes[i], pointer) = joinStore.publishChunk(_slice(raw, i * 8192, size));
            a.chunkLengths[i] = uint32(size);
            joinArchive.add(a.chunkHashes[i], pointer);
        }
        artifact = joinCoverage.recordArtifact(a);
        require(
            artifact
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_FINALITY_ARTIFACT_V1"),
                        block.chainid,
                        address(joinCoverage),
                        address(core),
                        a
                    )
                ),
            "literal exact whole-object artifact identity"
        );
        bytes32 plan = joinCoverage.beginCoverage(
            artifact, keccak256("archive family A"), keccak256("archive family B")
        );
        for (uint32 i; i < count; ++i) {
            coverage = joinCoverage.coverNextChunk(plan, i, a.chunkHashes[i]);
        }
        JoinF.Plan memory completed = joinCoverage.coveragePlan(plan);
        require(
            completed.nextIndex == count && completed.completionHash == coverage
                && coverage
                    == keccak256(
                        abi.encode(
                            keccak256("6529STREAM_FINALITY_ARTIFACT_COVERAGE_COMPLETE_V1"),
                            plan,
                            artifact,
                            completed.validationEpoch,
                            completed.evidenceChainHash,
                            completed.nextIndex
                        )
                    ),
            "actual ordered complete coverage and literal original completion identity"
        );
    }

    function _expectedManifest(Joined memory j) private view returns (JoinV.Manifest memory) {
        Preservation.Plan memory p = j.capture.host.checkpoint(j.capture.id);
        return JoinV.Manifest(
            j.capture.id,
            keccak256(abi.encode(p)),
            j.capture.host.entropySourceSet(),
            p.inventoryHash,
            p.policyChainHash,
            address(router),
            p.preservationProfile,
            j.artifact,
            j.coverage,
            JOIN_ARTIST,
            p.contentRoot,
            p.outputRoot,
            keccak256(j.raw),
            p.scope,
            p.tokenCount,
            uint64(j.raw.length)
        );
    }

    function _planHash(JoinManifest verifier, JoinV.Manifest memory m)
        private
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_PRESERVATION_POLICY_OUTPUT_MANIFEST_PLAN_V1"),
                block.chainid,
                address(verifier),
                address(core),
                verifier.contentCheckpoint(),
                address(joinCoverage),
                m
            )
        );
    }

    function _assertJoined(Joined memory j, bytes32 record) private view {
        _assertComplete(j.capture);
        JoinV.Manifest memory current = j.verifier.requireCurrentManifest(record, JOIN_ARTIST);
        JoinV.Manifest memory expected = _expectedManifest(j);
        require(
            keccak256(abi.encode(current)) == keccak256(abi.encode(expected))
                && keccak256(abi.encode(j.verifier.manifestRecord(record)))
                    == keccak256(abi.encode(expected)),
            "all original manifest fields join exact actual checkpoint rows and artifact"
        );
        require(
            j.plan == _planHash(j.verifier, current)
                && record
                    == keccak256(
                        abi.encode(
                            keccak256("6529STREAM_PRESERVATION_POLICY_OUTPUT_MANIFEST_VERIFIED_V1"),
                            j.plan
                        )
                    ) && j.verifier.manifestPlan(j.plan).nextIndex == current.tokenCount,
            "literal completion identity covers every original row"
        );
        JoinF.Artifact memory a = joinCoverage.artifact(j.artifact);
        JoinF.Coverage memory covered =
            joinCoverage.requireArtifactCoverage(j.coverage, JOIN_ARTIST, j.artifact);
        require(
            a.artistId == JOIN_ARTIST && a.contentHash == keccak256(j.raw)
                && a.byteLength == j.raw.length && a.schemaId == JoinDefinitions.SCHEMA
                && a.canonicalizationId == JoinDefinitions.CANON
                && covered.completionHash == j.coverage && covered.artifactHash == j.artifact
                && covered.artistId == a.artistId && covered.contentHash == a.contentHash
                && covered.byteLength == a.byteLength && covered.schemaId == a.schemaId
                && covered.canonicalizationId == a.canonicalizationId
                && covered.chunkCount == a.chunkHashes.length
                && covered.firstFamilyRecordHash == keccak256("archive family A")
                && covered.secondFamilyRecordHash == keccak256("archive family B"),
            "full artifact and exact two-family receipt join"
        );
        require(
            keccak256(schemas.documentBytes(JoinDefinitions.SCHEMA))
                    == keccak256(JoinDefinitions.document(JoinDefinitions.SCHEMA))
                && keccak256(schemas.documentBytes(JoinDefinitions.CANON))
                    == keccak256(JoinDefinitions.document(JoinDefinitions.CANON))
                && schemas.document(JoinDefinitions.SCHEMA).status
                    == JoinSchema.DocumentStatus.ACTIVE
                && schemas.document(JoinDefinitions.CANON).status
                    == JoinSchema.DocumentStatus.ACTIVE,
            "actual exact original V1 interpretation documents remain current"
        );
        for (uint32 i; i < a.chunkHashes.length; ++i) {
            (address pointer, bytes32 pin) = joinCoverage.artifactChunk(j.artifact, i);
            bytes memory code = pointer.code;
            require(
                pointer.codehash == pin && code.length == uint256(a.chunkLengths[i]) + 1
                    && code[0] == 0
                    && keccak256(_slice(code, 1, a.chunkLengths[i])) == a.chunkHashes[i]
                    && a.chunkHashes[i]
                        == keccak256(_slice(j.raw, uint256(i) * 8192, a.chunkLengths[i])),
                "actual SSTORE2 code bytes equal the complete canonical manifest"
            );
        }
    }

    function _expectCheckpointFailure(Joined memory j) private {
        vm.expectRevert(
            abi.encodeWithSelector(
                JoinV.OutputManifestReadFailed.selector,
                address(j.capture.host),
                Preservation.requireCurrentCheckpoint.selector
            )
        );
    }

    function _slice(bytes memory raw, uint256 start, uint256 size)
        private
        pure
        returns (bytes memory result)
    {
        result = new bytes(size);
        for (uint256 i; i < size; ++i) {
            result[i] = raw[start + i];
        }
    }

    function _word(bytes memory raw, uint256 index) private pure returns (bytes32 result) {
        assembly ("memory-safe") { result := mload(add(add(raw, 32), mul(index, 32))) }
    }
}
