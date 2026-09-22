// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistExtendedHydrationFeatures as XF
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistExtendedHydrationFeatures.sol";
import "../../regression/legacy/helpers/CharacterizationTestBase.sol";
import {
    StreamArtistAttributionLifecycle
} from "../../../smart-contracts/domains/artist/StreamArtistAttributionLifecycle.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistAttributionDisputeTypes as AD
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAttributionDisputes.sol";
import {
    StreamArtistRepudiationTypes as RP
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAttributionRepudiation.sol";
import {
    StreamArtistIdentityContestTypes as Contest
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistIdentityContestTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";

import {
    StreamArtistPersonhoodTypes as Personhood
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistPersonhoodEvidence.sol";

import {
    StreamArtistRecoveredHydrationTypes as Recovered
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";

interface AttributionTransportArtifactVm {
    function getCode(string calldata path) external view returns (bytes memory);
}

/// @dev Actual unchanged owner/worker storage and commits. This test is the explicitly typed
/// Coordinator boundary; it does not exercise facade signature/governance/Archive admission.
/// Original dispute, repudiation and withdrawal Safe/Archive suites remain separate oracles.
contract StreamArtistAttributionTransportTest is CharacterizationTestBase {
    StreamArtistAttributionLifecycle private owner;
    T.Binding private binding_;
    address private constant REGISTRY = address(0x101);
    address private constant ARCHIVE = address(0x202);
    bytes32 private constant ARTIST = keccak256("transport artist");
    error LateTransportFailure();

    function setUp() public {
        bytes memory code = abi.encodePacked(
            AttributionTransportArtifactVm(address(vm))
                .getCode("StreamArtistAttributionLifecycle.sol:StreamArtistAttributionLifecycle"),
            abi.encode(REGISTRY, address(this), ARCHIVE, address(0x303), address(0x404))
        );
        address deployed;
        assembly ("memory-safe") { deployed := create(0, add(code, 32), mload(code)) }
        require(deployed != address(0), "actual Attribution deployment must fit");
        owner = StreamArtistAttributionLifecycle(deployed);
        binding_.generation = 1;
        binding_.artistId = ARTIST;
        binding_.artistAddress = address(this);
        binding_.bindingHash = keccak256("binding");
        binding_.consentMode = 1;
        owner.claim(_context(1), 1, binding_, 0, "");
        owner.accept(_context(2), 1, binding_, keccak256("acceptance"));
        binding_.accepted = true;
    }

    function _context(uint16 op) private view returns (T.ActionContext memory) {
        return T.ActionContext(op, address(this), owner.ownerStateSnapshotV2());
    }

    function _filing(uint8 action, bytes32 label) private pure returns (AD.Filing memory) {
        return AD.Filing(1, 1, action, keccak256(abi.encode("evidence", label)), label);
    }

    function _admission() private view returns (AD.Admission memory a) {
        a.binding_ = binding_;
        a.standing = AD.Standing(ARTIST, 1, 0, 0);
        a.signer = address(this);
        a.authorityClass = 1;
        a.recordedAt = uint64(block.timestamp);
        a.digest = keccak256("already authenticated Coordinator facts");
    }

    function _record(AD.Filing memory p, AD.Admission memory a, uint256 nonce)
        private
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_DISPUTE_RECORD_V1"),
                block.chainid,
                REGISTRY,
                p.collectionId,
                p.bindingGeneration,
                p.disputeAction,
                a.signer,
                a.authorityClass,
                p.evidenceHash,
                p.reasonHash,
                nonce,
                a.recordedAt
            )
        );
    }

    function _key(bytes32 surface, bytes32 scope) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"),
                block.chainid,
                REGISTRY,
                address(this),
                ARCHIVE,
                address(owner),
                owner.domainId(),
                surface,
                scope
            )
        );
    }

    function _cell(bytes32 key, bytes32 commitment, uint64 revision) private view {
        T.ReplayCell memory cell = owner.replayCell(key);
        require(
            keccak256(abi.encode(cell))
                == keccak256(abi.encode(T.ReplayCell(commitment, revision, 1, 2))),
            "original exact replay cell"
        );
    }

    function _root(
        T.Snapshot memory before_,
        uint16 op,
        bytes32 action,
        bytes32 delta,
        bytes32 replay,
        bytes32 record
    ) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_OWNER_STATE_TRANSITION_V2"),
                block.chainid,
                REGISTRY,
                address(this),
                ARCHIVE,
                address(owner),
                before_.domainId,
                before_.revision,
                uint64(before_.revision + 1),
                before_.stateRoot,
                keccak256(abi.encode(op, address(this), action)),
                delta,
                replay,
                keccak256(abi.encode(record))
            )
        );
    }

    function _fingerprint() private view returns (bytes32) {
        return keccak256(
            abi.encode(
                owner.ownerStateSnapshotV2(),
                owner.authorityCheckpoint(),
                owner.artistNativeReceiptCount(),
                owner.storedPayloadCount(),
                owner.attributionDispute(1, 1),
                owner.rawPendingRepudiation(1)
            )
        );
    }

    function _open(bytes32 label) private returns (bytes32 record) {
        Contest.GovernanceWitness memory g;
        record = owner.applyDispute(_context(44), _filing(1, label), _admission(), 7, g);
    }

    function testSingleReplayExactOriginalRecordStateAndPayloadBytes() public {
        AD.Filing memory p = _filing(1, keccak256("single"));
        AD.Admission memory a = _admission();
        Contest.GovernanceWitness memory g;
        T.Snapshot memory before_ = owner.ownerStateSnapshotV2();
        bytes32 record = owner.applyDispute(_context(44), p, a, 7, g);
        require(record == _record(p, a, 7), "independent original record domain");
        bytes32 key = _key(
            keccak256("attribution_lifecycle.replay.dispute_key"),
            keccak256(
                abi.encode(
                    uint256(1), uint64(1), bytes32(0), a.signer, p.evidenceHash, p.reasonHash
                )
            )
        );
        _cell(key, record, before_.revision + 1);
        bytes32 state = keccak256(
            abi.encode(
                uint8(4),
                uint64(1),
                owner.attributionDispute(1, 1),
                owner.attributionDisputeRecord(record)
            )
        );
        require(
            owner.ownerStateSnapshotV2().stateRoot
                == _root(
                    before_, 44, keccak256(abi.encode(p, a, uint256(7), g)), state, key, record
                ),
            "single replay original state preimage"
        );
        require(
            owner.artistNativeReceiptCount() == 1
                && owner.artistNativeReceiptAt(0).recordHash == record,
            "one original native receipt"
        );
        require(
            keccak256(owner.recordPreimageBytes(record)) == record, "exact stored original bytes"
        );
        (address pointer, bytes32 kind, bytes32 hash) = owner.storedPayloadAt(0);
        require(
            pointer.code.length > 1 && kind == keccak256("ARTIST_RECORD_PREIMAGE")
                && hash == record,
            "catalog tuple parity"
        );
    }

    function testGovernanceOpeningUsesOrderedPairAndResolutionKeepsZeroRecordTip() public {
        AD.Filing memory p = _filing(1, keccak256("governed"));
        AD.Admission memory a = _admission();
        a.authorityClass = 0;
        Contest.GovernanceWitness memory g;
        g.actionId = keccak256("open action");
        g.proposer = address(this);
        g.actionClass = 1;
        T.Snapshot memory before_ = owner.ownerStateSnapshotV2();
        bytes32 record = owner.applyDispute(_context(44), p, a, 0, g);
        bytes32 first = _key(
            keccak256("attribution_lifecycle.replay.dispute_key"),
            keccak256(
                abi.encode(
                    uint256(1), uint64(1), bytes32(0), a.signer, p.evidenceHash, p.reasonHash
                )
            )
        );
        bytes32 second =
            _key(keccak256("attribution_lifecycle.replay.governance_action"), g.actionId);
        _cell(first, record, before_.revision + 1);
        _cell(second, record, before_.revision + 1);
        bytes32 delta = keccak256(
            abi.encode(
                uint8(4),
                uint64(1),
                owner.attributionDispute(1, 1),
                owner.attributionDisputeRecord(record)
            )
        );
        require(
            owner.ownerStateSnapshotV2().stateRoot
                == _root(
                    before_,
                    44,
                    keccak256(abi.encode(p, a, uint256(0), g)),
                    delta,
                    keccak256(abi.encode(first, second)),
                    record
                ),
            "ordered governance pair"
        );
        AD.ResolutionRequest memory q = AD.ResolutionRequest(
            1, 1, record, 1, keccak256("resolve evidence"), keccak256("resolve reason"), 0
        );
        g.actionId = keccak256("resolution action");
        before_ = owner.ownerStateSnapshotV2();
        require(
            owner.applyDisputeResolution(_context(46), q, binding_, g) == g.actionId,
            "distinct original action return"
        );
        first = _key(keccak256("attribution_lifecycle.replay.dispute_resolution_key"), record);
        second = _key(keccak256("attribution_lifecycle.replay.governance_action"), g.actionId);
        _cell(first, g.actionId, before_.revision + 1);
        _cell(second, record, before_.revision + 1);
        delta = keccak256(
            abi.encode(
                uint8(2),
                uint64(1),
                owner.attributionDispute(1, 1),
                owner.attributionDisputeResolution(g.actionId)
            )
        );
        require(
            owner.ownerStateSnapshotV2().stateRoot
                == _root(
                    before_,
                    46,
                    keccak256(abi.encode(q, binding_, g)),
                    delta,
                    keccak256(abi.encode(first, second)),
                    0
                ),
            "resolution zero-record original root"
        );
        require(
            owner.ownerStateSnapshotV2().recordChainTip == before_.recordChainTip
                && owner.artistNativeReceiptCount() == 1,
            "resolution creates neither record nor native occurrence"
        );
    }

    function testCounterThenWithdrawalKeepsCounterAndOriginalNativeOccurrences() public {
        bytes32 opening = _open(keccak256("opening"));
        Contest.GovernanceWitness memory g;
        AD.Filing memory counter = _filing(3, keccak256("counter"));
        bytes32 record = owner.applyDispute(_context(45), counter, _admission(), 8, g);
        AD.Filing memory p = _filing(2, keccak256("withdraw"));
        T.Snapshot memory before_ = owner.ownerStateSnapshotV2();
        bytes32 withdrawal = owner.applyDisputeWithdrawal(_context(61), p, _admission(), 9);
        _cell(
            _key(keccak256("attribution_lifecycle.replay.dispute_withdrawal_key"), opening),
            withdrawal,
            before_.revision + 1
        );
        require(
            owner.attributionDisputeWithdrawal(opening).recordHash == withdrawal
                && owner.attributionDisputeWithdrawal(opening).counterStatementRecordHash == record,
            "exact outcome"
        );
        require(
            !owner.attributionDispute(1, 1).open
                && owner.attributionDispute(1, 1).counterStatementRecordHash == record,
            "head retained"
        );
        require(
            owner.artistNativeReceiptCount() == 3 && owner.artistNativeReceiptAt(2).operation == 61,
            "withdrawal native occurrence"
        );
    }

    function _stage() private returns (RP.Record memory r) {
        AD.Filing memory p = _filing(4, keccak256("repudiation"));
        RP.Admission memory a;
        a.binding_ = binding_;
        a.authorityHead.principal = address(this);
        a.authorityHead.authorityClass = 1;
        a.stagedAt = uint64(block.timestamp);
        a.executableAt = a.stagedAt + 100;
        a.windowRevision = 1;
        a.guardianSet = keccak256("guardians");
        bytes32 record = owner.stageRepudiation(_context(47), p, a, 10);
        r = owner.attributionRepudiationRecord(record);
        require(
            owner.artistNativeReceiptCount() == 1 && owner.artistNativeReceiptAt(0).operation == 47,
            "stage one receipt"
        );
    }

    function testRepudiationCancellationIsOneReplayAndNoNewRecord() public {
        RP.Record memory r = _stage();
        T.Snapshot memory before_ = owner.ownerStateSnapshotV2();
        owner.cancelRepudiation(_context(49), r);
        _cell(
            _key(
                keccak256("attribution_lifecycle.replay.repudiation_cancellation_key"), r.recordHash
            ),
            keccak256(abi.encode(r.recordHash, uint8(3), bytes32(0))),
            before_.revision + 1
        );
        require(
            owner.ownerStateSnapshotV2().recordChainTip == before_.recordChainTip
                && owner.artistNativeReceiptCount() == 1,
            "no cancellation record"
        );
        require(owner.attributionRepudiationTerminal(r.recordHash).phase == 3, "cancel terminal");
    }

    function testRepudiationVetoAndExecutionRetainDistinctReplaySurfaces() public {
        RP.Record memory r = _stage();
        uint256 snap = vm.snapshotState();
        RP.GuardianProof memory p = RP.GuardianProof(
            1,
            r.recordHash,
            r.capturedGuardianSet,
            0,
            address(this),
            keccak256("veto"),
            uint64(block.timestamp)
        );
        T.Snapshot memory before_ = owner.ownerStateSnapshotV2();
        owner.vetoRepudiation(_context(48), r, p);
        _cell(
            _key(keccak256("attribution_lifecycle.replay.repudiation_veto_key"), r.recordHash),
            keccak256(abi.encode(r.recordHash, uint8(2), p.reasonHash)),
            before_.revision + 1
        );
        require(
            owner.attributionRepudiationTerminal(r.recordHash).phase == 2
                && owner.artistNativeReceiptCount() == 1,
            "veto terminal"
        );
        require(vm.revertToState(snap));
        vm.warp(r.executableAt);
        owner.executeRepudiation(_context(50), r);
        _cell(
            _key(keccak256("attribution_lifecycle.replay.repudiation_execution_key"), r.recordHash),
            keccak256(abi.encode(r.recordHash, uint8(4), r.terms.reasonHash)),
            before_.revision + 1
        );
        require(
            owner.attributionRepudiationTerminal(r.recordHash).phase == 4
                && owner.attributionDispute(1, 1).revocationReason == 3,
            "permanent repudiation"
        );
        require(owner.artistNativeReceiptCount() == 1, "execution no new receipt");
    }

    function testOpeningInvalidatesPendingRepudiationBeforeOriginalStateCommit() public {
        RP.Record memory r = _stage();
        _open(keccak256("invalidate"));
        require(
            owner.rawPendingRepudiation(1) == 0
                && owner.attributionRepudiationTerminal(r.recordHash).phase == 5,
            "pending invalidated"
        );
        require(owner.artistNativeReceiptCount() == 2, "both original occurrences");
    }

    function testOriginalCheckPrecedenceAndMalformedCallCannotMutate() public {
        AD.Filing memory p = _filing(1, keccak256("denied"));
        AD.Admission memory a = _admission();
        Contest.GovernanceWitness memory g;
        T.ActionContext memory c = _context(44);
        c.operationId = 45;
        c.actor = address(0);
        c.expected.revision = 99;
        bytes32 before_ = _fingerprint();
        vm.prank(address(0xBAD));
        vm.expectRevert(abi.encodeWithSelector(T.Unauthorized.selector, address(0xBAD)));
        owner.applyDispute(c, p, a, 0, g);
        vm.expectRevert(abi.encodeWithSelector(T.Unauthorized.selector, address(0)));
        owner.applyDispute(c, p, a, 0, g);
        c.actor = address(this);
        vm.expectRevert(abi.encodeWithSelector(T.InvalidOperation.selector, uint16(45)));
        owner.applyDispute(c, p, a, 0, g);
        bytes memory valid = abi.encodeCall(owner.applyDispute, (_context(44), p, a, uint256(0), g));
        bytes memory cut = new bytes(valid.length - 1);
        for (uint256 i; i < cut.length; ++i) {
            cut[i] = valid[i];
        }
        (bool ok,) = address(owner).call(cut);
        require(!ok && _fingerprint() == before_, "malformed no mutation");
    }

    function lateOpening(bytes calldata data, bool failLate)
        external
        returns (bytes memory result)
    {
        require(msg.sender == address(this));
        (bool ok, bytes memory returned) = address(owner).call(data);
        if (!ok) assembly ("memory-safe") { revert(add(returned, 32), mload(returned)) }
        if (failLate) revert LateTransportFailure();
        return returned;
    }

    function testLateCallerRollbackRestoresAllOwnerEffectsAndIdenticalRetry() public {
        AD.Filing memory p = _filing(1, keccak256("retry"));
        AD.Admission memory a = _admission();
        Contest.GovernanceWitness memory g;
        bytes memory data = abi.encodeCall(owner.applyDispute, (_context(44), p, a, uint256(7), g));
        bytes32 before_ = _fingerprint();
        vm.expectRevert(abi.encodeWithSelector(LateTransportFailure.selector));
        this.lateOpening(data, true);
        require(_fingerprint() == before_, "whole owner rollback");
        require(
            abi.decode(this.lateOpening(data, false), (bytes32)) == _record(p, a, 7),
            "identical retry"
        );
    }

    function testSupplementalHydrationOuterBytesAndEmptyCatalog() public view {
        AH.Query memory q;
        q.collectionId = 1;
        bytes memory observed = owner.authorityHydrationState(q);
        require(
            keccak256(observed) == keccak256(abi.encode(uint8(2), uint64(1))),
            "unchanged nested hydration bytes"
        );
        require(owner.storedPayloadCount() == 0, "empty original catalog");
    }

    function testPersonhoodEmptyOuterTuplesAndSelfOnlyGuardRemainExact() public {
        Personhood.Selection memory emptySelection;
        (bool ok, bytes memory raw) = address(owner)
            .staticcall(abi.encodeCall(owner.personhoodEvidence, (uint256(1), ARTIST)));
        require(
            ok && keccak256(raw) == keccak256(abi.encode(emptySelection)),
            "exact empty selection ABI"
        );
        (bytes32 head, Personhood.Status status) = owner.personhoodEvidenceStatus(1, ARTIST);
        require(head == 0 && status == Personhood.Status.NONE, "original absent evidence");
        Personhood.Summary memory emptySummary;
        (ok, raw) = address(owner)
            .staticcall(abi.encodeCall(owner.personhoodProofSummary, (bytes32(uint256(5)))));
        require(
            ok && raw.length == 1536 && keccak256(raw) == keccak256(abi.encode(emptySummary)),
            "all forty-eight original summary ABI words"
        );
        require(owner.personhoodProofSummaryHash(bytes32(uint256(5))) == 0, "empty retained hash");
        vm.expectRevert(abi.encodeWithSelector(Personhood.InvalidPersonhoodReference.selector));
        owner.auditPersonhoodEvidence(bytes32(uint256(5)));
        T.AttestationRecord memory record;
        vm.expectRevert(abi.encodeWithSelector(T.Unauthorized.selector, address(this)));
        owner.personhoodResolution(1, ARTIST, record, false);
    }

    function testPlatformValidatedOperationBranchesRetainOriginalReplayAndState() public {
        bytes32 evidence = keccak256("claim evidence");
        bytes32 reason = keccak256("claim reason");
        string memory uri = "urn:claim";
        T.ActionContext memory wrong = _context(9);
        bytes32 fingerprint = _fingerprint();
        vm.expectRevert(abi.encodeWithSelector(T.InvalidOperation.selector, uint16(9)));
        owner.fileAttributionClaim(wrong, 1, evidence, reason, uri, address(this));
        require(_fingerprint() == fingerprint, "mismatch refuses before operation10 branch");
        T.Snapshot memory before_ = owner.ownerStateSnapshotV2();
        bytes32 claim =
            owner.fileAttributionClaim(_context(10), 1, evidence, reason, uri, address(this));
        bytes32 key = _key(
            keccak256("attribution_lifecycle.replay.claim_record_hash_uniqueness"),
            keccak256(abi.encode(uint256(1), address(this), evidence, reason))
        );
        _cell(key, claim, before_.revision + 1);
        require(
            owner.ownerStateSnapshotV2().stateRoot
                == _root(
                    before_,
                    10,
                    keccak256(
                        abi.encode(uint256(1), address(this), evidence, reason, uri, address(this))
                    ),
                    keccak256(abi.encode(owner.attributionClaimRecord(claim))),
                    key,
                    claim
                ),
            "operation10 original state and action"
        );
        before_ = owner.ownerStateSnapshotV2();
        bytes32 declared =
            owner.declarePlatformWorks(_context(8), 2, keccak256("platform statement"));
        key = _key(keccak256(abi.encode("PLATFORM_WORKS", uint16(8))), bytes32(uint256(2)));
        _cell(key, declared, before_.revision + 1);
        require(
            owner.ownerStateSnapshotV2().stateRoot
                == _root(
                    before_,
                    8,
                    declared,
                    keccak256(abi.encode(uint256(2), owner.platformWorksState(2))),
                    key,
                    declared
                ),
            "ordinary platform state and replay branch"
        );
        require(
            owner.artistNativeReceiptAt(0).operation == 10
                && owner.artistNativeReceiptAt(1).operation == 8,
            "original native order"
        );
    }
    // Explicit typed Coordinator suite boundary for the unchanged recovered read worker.
    bool private wrongRecoveredSuite;

    function authorityHydrationSuite() external view returns (T.SuiteConfiguration memory suite) {
        suite.registry = wrongRecoveredSuite ? address(0xDEAD) : REGISTRY;
        suite.archive = ARCHIVE;
        suite.core = address(0x303);
        suite.mintManager = address(0x404);
        suite.owners[4] = address(owner);
    }

    function testRecoveredCapabilityAndEmptyPrefixKeepExactOuterBytes() public view {
        (bool ok, bytes memory raw) = address(owner)
            .staticcall(abi.encodeCall(owner.recoveredAuthorityHydrationCapability, ()));
        Recovered.Capability memory capability = owner.recoveredAuthorityHydrationCapability();
        require(
            (capability.supportedFeatures & uint256(31)) == 31
                && (capability.supportedFeatures & ~XF.KNOWN_FEATURES) == 0,
            "supported recovered baseline, no unknown feature promotion"
        );
        require(
            ok
                && keccak256(raw)
                    == keccak256(
                        abi.encode(
                            keccak256("6529STREAM_ARTIST_RECOVERED_AUTHORITY_HYDRATION_V1"),
                            uint16(1),
                            uint8(4),
                            keccak256("domain:attribution_lifecycle"),
                            keccak256("6529STREAM_ARTIST_GUARD_CHECKPOINT_V1"),
                            keccak256("6529STREAM_ARTIST_RECOVERED_ATTRIBUTION_STATE_V1"),
                            capability.supportedFeatures
                        )
                    ),
            "original capability identity and typed outer bytes"
        );
        Recovered.OwnerProvenance memory empty;
        (ok, raw) =
            address(owner).staticcall(abi.encodeCall(owner.recoveredHydrationImportedPrefix, ()));
        require(
            ok && keccak256(raw) == keccak256(abi.encode(empty, bytes32(0), uint64(0))),
            "exact empty dynamic prefix and commitment/revision"
        );
    }

    function testRecoveredOriginRetainsCurrentAndUnknownAndWrongSuiteBranches() public {
        T.SuiteConfiguration memory suite = this.authorityHydrationSuite();
        Recovered.OriginEnvironment memory expected;
        expected.chainId = block.chainid;
        expected.registry = REGISTRY;
        expected.coordinator = address(this);
        expected.archive = ARCHIVE;
        expected.owners = suite.owners;
        for (uint256 i; i < 7; ++i) {
            expected.ownerCodeHashes[i] = suite.owners[i].codehash;
        }
        expected.core = address(0x303);
        expected.manager = address(0x404);
        expected.suiteConfigurationHash = keccak256(abi.encode(suite));
        bytes32 hash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_RECOVERED_HYDRATION_ORIGIN_V1"), uint16(1), expected
            )
        );
        (bool ok, bytes memory raw) =
            address(owner).staticcall(abi.encodeCall(owner.recoveredHydrationOrigin, (hash)));
        require(
            ok && raw.length == 672 && keccak256(raw) == keccak256(abi.encode(expected)),
            "all original twenty-one origin words"
        );
        vm.expectRevert(
            abi.encodeWithSelector(Recovered.InvalidRecoveredHydrationProvenance.selector)
        );
        owner.recoveredHydrationOrigin(keccak256("unknown origin"));
        wrongRecoveredSuite = true;
        vm.expectRevert(
            abi.encodeWithSelector(Recovered.InvalidRecoveredHydrationProvenance.selector)
        );
        owner.recoveredHydrationOrigin(hash);
        wrongRecoveredSuite = false;
        require(
            keccak256(abi.encode(owner.recoveredHydrationOrigin(hash))) == keccak256(raw),
            "restored suite same current origin"
        );
    }
}
