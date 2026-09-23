// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredExternalGuards as X
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredExternalGuards.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    IStreamArtistAuthorityCheckpoint as CP
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityCheckpoint.sol";
import {
    StreamArtistHistoryTypes as H
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistHistory.sol";
import {
    StreamArtistEntropyUnavailabilityTypes as EU
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistEntropyUnavailability.sol";
import {
    IStreamGovernanceActionFacts as G
} from "../../../smart-contracts/interfaces/stream/governance/IStreamGovernanceActionFacts.sol";
import {
    GovernanceActionStatus as Status
} from "../../../smart-contracts/interfaces/stream/governance/StreamGovernanceTypes.sol";
import {
    StreamFinalityRecoveryRecord
} from "../../../smart-contracts/interfaces/stream/finality/StreamFinalityRecoveryTypes.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType
} from "../../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import {
    IStreamEntropyFreshRecovery as E
} from "../../../smart-contracts/interfaces/stream/entropy/IStreamEntropyFreshRecovery.sol";
import {
    StreamArtistHashes as Hashes
} from "../../../smart-contracts/domains/artist/StreamArtistHashes.sol";
import {
    StreamArtistRecoveryHashes as RecoveryHashes
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveryHashes.sol";

interface RecoveredExternalVm {
    function expectRevert(bytes calldata reason) external;
    function mockCall(address target, bytes calldata input, bytes calldata output) external;
    function mockCallRevert(address target, bytes calldata input, bytes calldata reason) external;
    function clearMockedCalls() external;
    function warp(uint256 timestamp) external;
    function etch(address target, bytes calldata code) external;
}

/// @dev Typed synthetic external guard controls, not Governance/Finality/Entropy producer evidence.
contract RecoveredExternalGovernor {
    mapping(bytes32 => G.ActionFacts) private facts;

    function set(bytes32 key, Status status) external {
        facts[key] = G.ActionFacts(status, 2, keccak256("original exact calls"), 1, 2);
    }

    function governanceActionFacts(bytes32 key) external view returns (G.ActionFacts memory) {
        return facts[key];
    }
}

contract RecoveredExternalFinality {
    address public immutable core;
    address public immutable governanceAuthority;
    mapping(bytes32 => StreamFinalityRecoveryRecord) private records;

    constructor(address core_, address executor_) {
        core = core_;
        governanceAuthority = executor_;
    }

    function set(bytes32 key, StreamFinalityRecoveryRecord memory record) external {
        records[key] = record;
    }

    function finalityRecoveryRecord(bytes32 key)
        external
        view
        returns (StreamFinalityRecoveryRecord memory)
    {
        return records[key];
    }
}

contract RecoveredExternalEntropy {
    address public immutable core;
    mapping(bytes32 => bool) private terminal;
    mapping(bytes32 => E.RecoveryReceipt) private receipts;
    mapping(bytes32 => X.EntropyEvidence) private evidence;

    constructor(address core_) {
        core = core_;
    }

    function setTerminal(bytes32 key, bool value) external {
        terminal[key] = value;
    }

    function set(bytes32 key, E.RecoveryReceipt memory r, X.EntropyEvidence memory e) external {
        receipts[key] = r;
        evidence[key] = e;
    }

    function entropyRecoveryIntentTerminal(bytes32 key) external view returns (bool) {
        return terminal[key];
    }

    function freshRecoveryReceipt(bytes32 key) external view returns (E.RecoveryReceipt memory) {
        return receipts[key];
    }

    function entropyUnavailabilityEvidence(bytes32 key)
        external
        view
        returns (bytes32, bytes32, uint64)
    {
        X.EntropyEvidence memory e = evidence[key];
        return (e.findingRecordHash, e.intentHash, e.noticeEndsAt);
    }
}

contract RecoveredExternalAtomicHost {
    uint256 public completed;

    function run(RH.Provenance memory p, IH.Bundle memory b, bool mutate) external {
        X.Snapshot memory s = X.collect(p, b);
        ++completed;
        if (mutate) {
            RecoveredExternalGovernor(s.actions[0].witness.executor)
                .set(s.actions[0].witness.actionId, Status.CANCELLED);
        }
        X.requireCurrent(s);
    }
}

/// @notice Source-only authored tests of guard snapshots using typed mutable dependency controls.
/// @dev The fixture supplies provenance/record shapes; it does not establish actual operation60 admission.
contract StreamArtistRecoveredExternalGuardsTest {
    RecoveredExternalVm private constant vm =
        RecoveredExternalVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    bytes32 private constant ARTIST = keccak256("original artist");
    bytes32 private constant ACTION = keccak256("original action");
    address private constant CORE = address(0x6529);
    RecoveredExternalGovernor private governor;
    RecoveredExternalFinality private finality;
    RecoveredExternalEntropy private entropy;

    function setUp() public {
        governor = new RecoveredExternalGovernor();
        governor.set(ACTION, Status.EXECUTED);
        finality = new RecoveredExternalFinality(CORE, address(governor));
        entropy = new RecoveredExternalEntropy(CORE);
        vm.warp(100);
    }

    function testEmptyDependencySetHasExplicitCanonicalSnapshot() public view {
        (RH.Provenance memory p, IH.Bundle memory b) = _base();
        X.Snapshot memory s = X.collect(p, b);
        require(
            s.schema == X.SCHEMA && s.provenanceCommitment == RH.provenanceHash(p),
            "canonical empty snapshot"
        );
        require(
            s.actions.length == 0 && s.finality.length == 0 && s.entropy.length == 0,
            "empty dependency set"
        );
        X.requireCurrent(s);
    }

    function testExecutedActionRemainsAdmissibleAfterItsOriginalExpiry() public view {
        (RH.Provenance memory p, IH.Bundle memory b) = _action();
        require(
            block.timestamp > b.actions[0].association.action.expiresAfter,
            "historical execution expired"
        );
        X.Snapshot memory s = X.collect(p, b);
        require(s.actions[0].facts.status == Status.EXECUTED, "original consumed action retained");
        X.requireCurrent(s);
    }

    function testUnexecutedPreparationsKeepEveryActualTerminalStatus() public {
        (RH.Provenance memory p, IH.Bundle memory b) = _action();
        b.actions[0].execution = 0;
        for (uint8 i = 1; i <= uint8(Status.VETOED); ++i) {
            governor.set(ACTION, Status(i));
            X.Snapshot memory s = X.collect(p, b);
            require(uint8(s.actions[0].facts.status) == i, "status not normalized");
            X.requireCurrent(s);
        }
    }

    function testActionStatusMutationFailsReadbackAndRestorationRetries() public {
        (RH.Provenance memory p, IH.Bundle memory b) = _action();
        X.Snapshot memory s = X.collect(p, b);
        governor.set(ACTION, Status.CANCELLED);
        _rejectCurrent(s, ACTION);
        governor.set(ACTION, Status.EXECUTED);
        X.requireCurrent(s);
    }

    function testActionMissingFactsWrongCallsAndChangedCodeFailClosed() public {
        (RH.Provenance memory p, IH.Bundle memory b) = _action();
        governor.set(ACTION, Status.NONE);
        _rejectCollect(p, b, ACTION);
        governor.set(ACTION, Status.EXECUTED);
        b.actions[0].association.action.callsHash = keccak256("different calls");
        _rejectCollect(p, b, ACTION);
        (p, b) = _action();
        X.Snapshot memory s = X.collect(p, b);
        bytes memory code = address(governor).code;
        vm.etch(address(governor), hex"00");
        vm.expectRevert(
            abi.encodeWithSelector(X.RecoveredExternalDependencyChanged.selector, address(governor))
        );
        this.current(s);
        vm.etch(address(governor), code);
        X.requireCurrent(s);
    }

    function testFinalityKeepsUnusedAndAlreadyExecutedOriginalAction() public {
        (RH.Provenance memory p, IH.Bundle memory b) = _finding(false);
        X.Snapshot memory empty = X.collect(p, b);
        require(
            !empty.finality[0].record.executed && empty.finality[0].actionTerminal,
            "actual external state retained"
        );
        StreamFinalityRecoveryRecord memory r = _finalityRecord(b);
        finality.set(ACTION, r);
        X.Snapshot memory consumed = X.collect(p, b);
        require(consumed.finality[0].record.executed, "historical finality consumption accepted");
        X.requireCurrent(consumed);
        _rejectCurrent(empty, b.findings[0].record.recordHash);
    }

    function testFinalityReadbackCatchesRecordAndTerminalChanges() public {
        (RH.Provenance memory p, IH.Bundle memory b) = _finding(false);
        StreamFinalityRecoveryRecord memory r = _finalityRecord(b);
        finality.set(ACTION, r);
        X.Snapshot memory s = X.collect(p, b);
        r.reasonHash = keccak256("mutated immutable typed result");
        finality.set(ACTION, r);
        _rejectCurrent(s, b.findings[0].record.recordHash);
        finality.set(ACTION, _finalityRecord(b));
        governor.set(ACTION, Status.SCHEDULED);
        _rejectCurrent(s, b.findings[0].record.recordHash);
        governor.set(ACTION, Status.EXECUTED);
        X.requireCurrent(s);
    }

    function testFinalityOriginalTargetPinAndDerivedExecutorCannotBeRebound() public {
        (RH.Provenance memory p, IH.Bundle memory b) = _finding(false);
        X.Snapshot memory s = X.collect(p, b);
        vm.mockCall(
            address(finality),
            abi.encodeWithSignature("governanceAuthority()"),
            abi.encode(address(entropy))
        );
        vm.expectRevert(
            abi.encodeWithSelector(X.RecoveredExternalDependencyChanged.selector, address(finality))
        );
        this.current(s);
        vm.clearMockedCalls();
        b.findings[0].admission.recoveryRegistryCodeHash = keccak256("wrong original pin");
        vm.expectRevert(
            abi.encodeWithSelector(X.RecoveredExternalDependencyChanged.selector, address(finality))
        );
        this.collect(p, b);
    }

    function testEntropyCapturesEmptyAndConsumedReceiptWithoutInventingFindingUseBit() public {
        (RH.Provenance memory p, IH.Bundle memory b) = _finding(true);
        X.Snapshot memory first = X.collect(p, b);
        require(
            !first.entropy[0].terminal && first.entropy[0].receipt.artistRecordHash == 0,
            "exact empty reads"
        );
        E.RecoveryReceipt memory r;
        r.previousRequestKey = b.findings[0].entropyAdmission.intent.oldRequestKey;
        // A later admitted finding can consume the same original intent.
        r.artistRecordHash = keccak256("later finding for original intent");
        r.evidenceHash = keccak256("executed entropy evidence");
        r.requestedAtBlock = 71;
        X.EntropyEvidence memory e = X.EntropyEvidence(
            r.artistRecordHash, b.findings[0].entropyAdmission.target.intentHash, 400
        );
        entropy.set(b.findings[0].entropyAdmission.intent.newRequestKey, r, e);
        entropy.setTerminal(r.previousRequestKey, true);
        X.Snapshot memory used = X.collect(p, b);
        require(
            used.entropy[0].terminal
                && used.entropy[0].receipt.artistRecordHash == r.artistRecordHash,
            "exact different finding receipt"
        );
        X.requireCurrent(used);
        _rejectCurrent(first, b.findings[0].record.recordHash);
    }

    function testEntropyEachAvailableReadIsRecheckedIndependently() public {
        (RH.Provenance memory p, IH.Bundle memory b) = _finding(true);
        X.Snapshot memory s = X.collect(p, b);
        bytes32 oldKey = b.findings[0].entropyAdmission.intent.oldRequestKey;
        bytes32 newKey = b.findings[0].entropyAdmission.intent.newRequestKey;
        entropy.setTerminal(oldKey, true);
        _rejectCurrent(s, b.findings[0].record.recordHash);
        entropy.setTerminal(oldKey, false);
        E.RecoveryReceipt memory r;
        X.EntropyEvidence memory e;
        r.artistRecordHash = b.findings[0].record.recordHash;
        entropy.set(newKey, r, e);
        _rejectCurrent(s, b.findings[0].record.recordHash);
        r.artistRecordHash = 0;
        e.intentHash = keccak256("evidence changed alone");
        entropy.set(newKey, r, e);
        _rejectCurrent(s, b.findings[0].record.recordHash);
        e.intentHash = 0;
        entropy.set(newKey, r, e);
        X.requireCurrent(s);
    }

    function testMissingEntropyGetterOrDerivedNewKeyIsNotAnUnusedFinding() public {
        (RH.Provenance memory p, IH.Bundle memory b) = _finding(true);
        bytes32 key = b.findings[0].entropyAdmission.intent.newRequestKey;
        vm.mockCallRevert(address(entropy), abi.encodeCall(E.freshRecoveryReceipt, (key)), hex"01");
        vm.expectRevert(
            abi.encodeWithSelector(X.RecoveredExternalReadFailed.selector, address(entropy))
        );
        this.collect(p, b);
        vm.clearMockedCalls();
        b.findings[0].entropyAdmission.intent.newRequestKey = 0;
        _rejectCollect(p, b, b.findings[0].record.recordHash);
    }

    function testFindingUsesActualOriginalEraAndCannotRelabelToCurrentRegistry() public {
        (RH.Provenance memory p, IH.Bundle memory b) = _finding(true);
        b.findings[0].entropyOrigin = address(0xBAD);
        _rejectCollect(p, b, b.findings[0].record.recordHash);
        (p, b) = _finding(false);
        b.findings[0].position.nativeIndex = 1;
        _rejectCollect(p, b, b.findings[0].record.recordHash);
    }

    function testGuardFailureRollsBackDestinationAndCallbackThenExactRetry() public {
        (RH.Provenance memory p, IH.Bundle memory b) = _action();
        RecoveredExternalAtomicHost host = new RecoveredExternalAtomicHost();
        vm.expectRevert(abi.encodeWithSelector(X.InvalidRecoveredExternalGuard.selector, ACTION));
        host.run(p, b, true);
        require(
            host.completed() == 0
                && governor.governanceActionFacts(ACTION).status == Status.EXECUTED,
            "atomic guard rollback"
        );
        host.run(p, b, false);
        require(host.completed() == 1, "exact retry");
    }

    function collect(RH.Provenance memory p, IH.Bundle memory b)
        external
        view
        returns (X.Snapshot memory)
    {
        return X.collect(p, b);
    }

    function current(X.Snapshot memory s) external view {
        X.requireCurrent(s);
    }

    function _base() private view returns (RH.Provenance memory p, IH.Bundle memory b) {
        p.origins = new RH.OriginEnvironment[](1);
        p.eras = new RH.Era[](1);
        RH.OriginEnvironment memory o;
        o.chainId = block.chainid;
        o.registry = address(1);
        o.coordinator = address(2);
        o.archive = address(3);
        o.core = CORE;
        o.manager = address(5);
        o.suiteConfigurationHash = keccak256("original fixed suite fixture");
        for (uint8 i; i < 7; ++i) {
            o.owners[i] = address(uint160(100 + uint256(i)));
            o.ownerCodeHashes[i] = bytes32(uint256(i) + 1);
            p.eras[0].checkpoints[i] = CP.Checkpoint(
                RH.CHECKPOINT,
                T.Snapshot(RH.ownerDomain(i), 100, bytes32(uint256(1)), bytes32(uint256(2))),
                0,
                0,
                0,
                0
            );
        }
        p.origins[0] = o;
        p.eras[0].originHash = RH.originHash(o);
        b.artistId = ARTIST;
    }

    function _action() private view returns (RH.Provenance memory p, IH.Bundle memory b) {
        (p, b) = _base();
        b.actions = new IH.ActionRow[](1);
        IH.ActionRow memory a;
        a.point = RH.Point(p.eras[0].originHash, 2, 90);
        a.association.artistId = ARTIST;
        a.association.associationHash = keccak256("original association");
        a.association.ownerRevision = 90;
        a.association.action.actionId = ACTION;
        a.association.action.executor = address(governor);
        a.association.action.executorCodeHash = address(governor).codehash;
        a.association.action.callsHash = keccak256("original exact calls");
        a.association.action.notBefore = 1;
        a.association.action.expiresAfter = 2;
        a.execution = keccak256("original35");
        b.actions[0] = a;
    }

    function _finding(bool entropy_)
        private
        view
        returns (RH.Provenance memory p, IH.Bundle memory b)
    {
        (p, b) = _base();
        b.findings = new IH.FindingRow[](1);
        IH.FindingRow memory row;
        row.position = RH.Position(RH.Point(p.eras[0].originHash, 2, 90), 0);
        row.record.terms.artistId = ARTIST;
        row.record.terms.collectionId = 77;
        row.record.terms.reasonHash = keccak256("original reason");
        row.record.governanceActionId = keccak256("original finding action");
        row.record.recordedAt = 3;
        row.record.noticeEndsAt = 300;
        if (entropy_) {
            EU.Admission memory a;
            a.target.coordinator = address(entropy);
            a.target.recovery.oldRequestKey = keccak256("old entropy request");
            a.target.unavailableEvidenceHash = keccak256("provider unavailability");
            a.intent.collectionId = 77;
            a.intent.oldRequestKey = a.target.recovery.oldRequestKey;
            a.intent.newRequestKey = keccak256("exact original next request");
            a.target.intentHash = EU.intentHash(address(entropy), CORE, a.intent);
            a.coordinatorCodeHash = address(entropy).codehash;
            a.governanceWitnessHash = keccak256("original finding witness");
            row.entropyAdmission = a;
            row.entropyOrigin = p.origins[0].registry;
            row.record.terms.evidenceHash = EU.evidenceHash(
                p.origins[0].registry, CORE, a.target, a.intent, a.coordinatorCodeHash
            );
        } else {
            row.admission.target.recoveryRegistry = address(finality);
            row.admission.target.recoveryActionId = ACTION;
            row.admission.target.scope =
                StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 77, 0, 0);
            row.admission.target.originalFinalityRecordHash = keccak256("original finality");
            row.admission.target.recoveryManifestHash = keccak256("original manifest");
            row.admission.recoveryRegistryCodeHash = address(finality).codehash;
            row.admission.recoveryIntentFactsHash = keccak256("original intent facts");
            row.admission.governanceWitnessHash = keccak256("original finding witness");
            row.record.terms.evidenceHash = keccak256("original ordinary evidence");
        }
        row.record.recordHash = RecoveryHashes.findingRecord(
            Hashes.Environment(block.chainid, p.origins[0].registry, CORE, p.origins[0].manager),
            row.record
        );
        b.findings[0] = row;
        p.eras[0].nativeCounts[2] = 1;
        p.journals[2] = new RH.JournalEntry[](1);
        p.journals[2][0] =
            RH.JournalEntry(row.position, H.Receipt(23, ARTIST, 77, row.record.recordHash));
    }

    function _finalityRecord(IH.Bundle memory b)
        private
        pure
        returns (StreamFinalityRecoveryRecord memory r)
    {
        r.executed = true;
        r.recoveryId = ACTION;
        r.scope = b.findings[0].admission.target.scope;
        r.originalFinalityRecordHash = b.findings[0].admission.target.originalFinalityRecordHash;
        r.recoveryManifest.contentHash = b.findings[0].admission.target.recoveryManifestHash;
        r.reasonURI = "ipfs://retained-original-recovery";
        r.executedAt = 2;
    }

    function _rejectCollect(RH.Provenance memory p, IH.Bundle memory b, bytes32 key) private {
        vm.expectRevert(abi.encodeWithSelector(X.InvalidRecoveredExternalGuard.selector, key));
        this.collect(p, b);
    }

    function _rejectCurrent(X.Snapshot memory s, bytes32 key) private {
        vm.expectRevert(abi.encodeWithSelector(X.InvalidRecoveredExternalGuard.selector, key));
        this.current(s);
    }
}
