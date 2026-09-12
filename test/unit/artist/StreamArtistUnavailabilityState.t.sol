// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../smart-contracts/domains/artist/StreamArtistUnavailabilityState.sol";
import "../../../smart-contracts/domains/artist/StreamArtistOwner.sol";

interface UnavailabilityVm {
    struct Log {
        bytes32[] topics;
        bytes data;
        address emitter;
    }
    function warp(uint256 time) external;
    function expectRevert(bytes4 selector) external;
    function expectRevert(bytes calldata reason) external;
    function recordLogs() external;
    function getRecordedLogs() external returns (Log[] memory);
}

/// @dev State/commit harness. Governance, binding, recovery and proof observations are test inputs.
contract UnavailabilityOwnerHarness is StreamArtistOwner {
    mapping(bytes32 => T.Identity) private _identity;
    StreamArtistUnavailabilityState.State private _findings;

    constructor()
        StreamArtistOwner(
            address(0x101),
            msg.sender,
            address(0x202),
            keccak256("domain:identity_authority"),
            address(0x303),
            address(0x404)
        )
    {
        _identity[bytes32(uint256(1))] = T.Identity(
            address(0x505), 1, 1, 100, 100, bytes32(uint256(11)), "identity", "artist", 0
        );
    }

    function ownerContext()
        public
        view
        returns (StreamArtistUnavailabilityState.OwnerContext memory)
    {
        return StreamArtistUnavailabilityState.OwnerContext(
            _environment(), operationCoordinator, archiveV2, domainId, _revision
        );
    }

    function findingContext(U.Input memory p) public view returns (U.Context memory) {
        return StreamArtistUnavailabilityState.context(
            _findings, ownerContext(), _identity[p.terms.artistId], p
        );
    }

    function record(U.Input memory p, bool failTail) external returns (bytes32 hash) {
        require(msg.sender == operationCoordinator, "harness caller");
        T.ActionContext memory c = T.ActionContext(23, msg.sender, ownerStateSnapshotV2());
        StreamArtistUnavailabilityState.Mutation memory m = StreamArtistUnavailabilityState.record(
            _findings, _replay, ownerContext(), _identity[p.terms.artistId], p
        );
        this.commitFixture(c, m.action, m.state, m.replay, m.record);
        require(!failTail, "late append");
        return m.record;
    }

    function authenticatedActivity(bool failTail) external {
        require(msg.sender == operationCoordinator, "harness caller");
        T.ActionContext memory c = T.ActionContext(24, msg.sender, ownerStateSnapshotV2());
        bytes32 delta = StreamArtistUnavailabilityState.noteActivity(
            _findings, bytes32(uint256(1)), address(0x505), 1, 24
        );
        this.commitFixture(c, bytes32(uint256(100)), delta, bytes32(0), bytes32(0));
        require(!failTail, "late append");
    }

    function finding(bytes32 hash)
        external
        view
        returns (Recovery.FindingRecord memory, U.Admission memory)
    {
        return (_findings.records[hash], _findings.admissions[hash]);
    }

    function commitFixture(
        T.ActionContext calldata c,
        bytes32 action,
        bytes32 state,
        bytes32 replay,
        bytes32 recordHash
    ) external {
        require(msg.sender == address(this), "self commit fixture");
        _commit(c, action, state, replay, recordHash);
    }

    function live(bytes32 hash, T.Binding memory b) external view returns (bool) {
        return StreamArtistUnavailabilityState.live(_findings, hash, b);
    }

    function setTimingFixture(uint64 duration, uint64 revision) external {
        _findings.noticeSeconds = duration;
        _findings.timingRevision = revision;
    }
}

contract StreamArtistUnavailabilityStateTest {
    UnavailabilityVm private constant vm =
        UnavailabilityVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    UnavailabilityOwnerHarness private owner;

    function setUp() public {
        vm.warp(1000);
        owner = new UnavailabilityOwnerHarness();
    }

    function _input() private view returns (U.Input memory p) {
        p.terms = Recovery.FindingRequest(
            bytes32(uint256(1)), 7, bytes32(uint256(2)), bytes32(uint256(3))
        );
        p.target = U.Target(
            address(0x606),
            bytes32(uint256(4)),
            StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 7, 0, bytes32(0)),
            bytes32(uint256(5)),
            bytes32(uint256(6))
        );
        p.binding_ = T.Binding(
            bytes32(uint256(1)),
            address(0x505),
            bytes32(uint256(11)),
            bytes32(uint256(12)),
            1,
            1,
            1,
            0,
            address(0x707),
            true
        );
        p.recoveryIntentFactsHash = keccak256("state fixture actual intent facts boundary");
        p.recoveryRegistryCodeHash = bytes32(uint256(13));
        p.recoveryNotBefore = 1000 + 91 days;
        p.recoveryExpiresAfter = 1000 + 98 days;
        return _governance(p, bytes32(uint256(15)));
    }

    function _governance(U.Input memory p, bytes32 action) private view returns (U.Input memory) {
        U.Context memory c = owner.findingContext(p);
        p.governance = Contest.GovernanceWitness(
            action,
            address(0x808),
            2,
            bytes32(uint256(16)),
            1,
            c.scopeHash,
            c.oldValueHash,
            c.newValueHash
        );
        return p;
    }

    function _snapshot() private view returns (bytes32) {
        return keccak256(abi.encode(owner.ownerStateSnapshotV2()));
    }

    function _replayKey(bytes32 surface, bytes32 scope) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"),
                block.chainid,
                address(0x101),
                address(this),
                address(0x202),
                address(owner),
                keccak256("domain:identity_authority"),
                surface,
                scope
            )
        );
    }

    function _flatRecord(Recovery.FindingRecord memory r) private view returns (bytes32) {
        bytes32[10] memory w;
        w[0] = 0xc087b73d3ef4933341423d2630b88eca87257e38716a129b316ebc148a7fa1f5;
        w[1] = bytes32(block.chainid);
        w[2] = bytes32(uint256(0x101));
        w[3] = r.terms.artistId;
        w[4] = bytes32(r.terms.collectionId);
        w[5] = r.terms.evidenceHash;
        w[6] = r.terms.reasonHash;
        w[7] = r.governanceActionId;
        w[8] = bytes32(uint256(r.noticeEndsAt));
        w[9] = bytes32(uint256(r.recordedAt));
        return keccak256(abi.encode(w));
    }

    function testRecordExactEventReplayAndSeparateRecoveryAction() public {
        U.Input memory p = _input();
        vm.recordLogs();
        bytes32 hash = owner.record(p, false);
        UnavailabilityVm.Log[] memory logs = vm.getRecordedLogs();
        (Recovery.FindingRecord memory r, U.Admission memory a) = owner.finding(hash);
        require(hash == _flatRecord(r), "literal10");
        require(
            r.governanceActionId == p.governance.actionId
                && r.governanceActionId != a.target.recoveryActionId,
            "separate action"
        );
        require(r.recordedAt == 1000 && r.noticeEndsAt == 1000 + 90 days, "observed notice");
        require(r.noticeSeconds == 90 days && r.timingRevision == 1, "captured timing");
        require(keccak256(abi.encode(a.target)) == keccak256(abi.encode(p.target)), "target exact");
        require(logs.length == 1 && logs[0].emitter == address(owner), "owner event");
        require(
            logs[0].topics[0] == 0x0a1bf2c6613fdf21329929e98beb59b65b2d9b7e81eb774659542e5011175841,
            "topic"
        );
        require(
            logs[0].topics[1] == p.terms.artistId && logs[0].topics[2] == bytes32(uint256(7)),
            "indexed"
        );
        require(
            keccak256(logs[0].data)
                == keccak256(
                    abi.encode(
                        uint16(1),
                        r.noticeEndsAt,
                        r.recordedAt,
                        p.terms.evidenceHash,
                        p.terms.reasonHash,
                        hash,
                        p.governance.actionId
                    )
                ),
            "event words"
        );
        bytes32 actionKey = _replayKey(
            keccak256("identity_authority.replay.governance_action_id"),
            keccak256(abi.encode(p.governance.actionId))
        );
        T.ReplayCell memory cell = owner.replayCell(actionKey);
        require(
            cell.commitment == hash && cell.touchedRevision == 1 && cell.kind == 1
                && cell.status == 2,
            "action cell"
        );
        bytes32 scope = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_UNAVAILABILITY_FINDING_KEY_V1"),
                p.terms.artistId,
                p.binding_.generation,
                p.binding_.bindingHash,
                p.target
            )
        );
        cell =
            owner.replayCell(_replayKey(keccak256("identity_authority.replay.finding_key"), scope));
        require(
            cell.commitment == hash && cell.status == 2 && cell.touchedRevision == 1, "finding cell"
        );
    }

    function testActivitySameBlockAtNoticeEndAndAfterNotice() public {
        for (uint256 i; i < 3; ++i) {
            vm.warp(1000);
            owner = new UnavailabilityOwnerHarness();
            U.Input memory p = _input();
            bytes32 hash = owner.record(p, false);
            (Recovery.FindingRecord memory prior, U.Admission memory admission) =
                owner.finding(hash);
            if (i == 1) vm.warp(1000 + 90 days);
            if (i == 2) vm.warp(1001 + 90 days);
            require(owner.live(hash, p.binding_), "live before activity");
            owner.authenticatedActivity(false);
            require(!owner.live(hash, p.binding_), "cancelled current use");
            (Recovery.FindingRecord memory after_, U.Admission memory afterAdmission) =
                owner.finding(hash);
            require(
                keccak256(abi.encode(prior, admission))
                    == keccak256(abi.encode(after_, afterAdmission)),
                "history fixed"
            );
        }
    }

    function testLateRecordAndActivityFailureRollBackAndRetry() public {
        U.Input memory p = _input();
        bytes32 before_ = _snapshot();
        (bool ok,) = address(owner).call(abi.encodeCall(owner.record, (p, true)));
        require(!ok && _snapshot() == before_, "record rollback");
        bytes32 hash = owner.record(p, false);
        before_ = _snapshot();
        (ok,) = address(owner).call(abi.encodeCall(owner.authenticatedActivity, (true)));
        require(!ok && _snapshot() == before_ && owner.live(hash, p.binding_), "activity rollback");
        owner.authenticatedActivity(false);
        require(!owner.live(hash, p.binding_), "same activity retry");
    }

    function testActiveFindingAndSpentTargetCannotBeReused() public {
        U.Input memory p = _input();
        bytes32 hash = owner.record(p, false);
        vm.expectRevert(abi.encodeWithSelector(U.UnavailabilityFindingActive.selector, hash));
        owner.findingContext(p);
        owner.authenticatedActivity(false);
        p = _governance(p, bytes32(uint256(20)));
        bytes32 before_ = _snapshot();
        bytes32 scope = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_UNAVAILABILITY_FINDING_KEY_V1"),
                p.terms.artistId,
                p.binding_.generation,
                p.binding_.bindingHash,
                p.target
            )
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                T.Replay.selector,
                _replayKey(keccak256("identity_authority.replay.finding_key"), scope)
            )
        );
        owner.record(p, false);
        require(_snapshot() == before_ && !owner.live(hash, p.binding_), "target replay rollback");
        p.target.recoveryActionId = bytes32(uint256(21));
        p = _governance(p, bytes32(uint256(20)));
        bytes32 next = owner.record(p, false);
        require(next != hash && owner.live(next, p.binding_), "fresh action and full notice");
    }

    function testTimingAndAssociationSnapshotsRemainFixed() public {
        U.Input memory p = _input();
        bytes32 hash = owner.record(p, false);
        owner.setTimingFixture(120 days, 2);
        (Recovery.FindingRecord memory r,) = owner.finding(hash);
        require(
            r.noticeEndsAt == 1000 + 90 days && r.noticeSeconds == 90 days && r.timingRevision == 1,
            "old timing fixed"
        );
        T.Binding memory b = p.binding_;
        b.artistAddress = address(0x999);
        require(owner.live(hash, b), "authority address not association");
        ++b.generation;
        require(!owner.live(hash, b), "generation invalid");
        b = p.binding_;
        b.bindingHash = bytes32(uint256(100));
        require(!owner.live(hash, b), "binding invalid");
        b = p.binding_;
        b.artistId = bytes32(uint256(101));
        require(!owner.live(hash, b), "artist invalid");
    }

    function testWrongGovernanceNoticeWindowAndScopePreserveState() public {
        U.Input memory p = _input();
        bytes32 before_ = _snapshot();
        p.governance.actionClass = 1;
        vm.expectRevert(Recovery.InvalidUnavailabilityFinding.selector);
        owner.record(p, false);
        p = _input();
        p.recoveryNotBefore = 1000 + 89 days;
        vm.expectRevert(Recovery.InvalidUnavailabilityFinding.selector);
        owner.record(p, false);
        p = _input();
        p.target.scope.tokenId = 1;
        vm.expectRevert(Recovery.InvalidUnavailabilityFinding.selector);
        owner.record(p, false);
        require(_snapshot() == before_, "negative roots unchanged");
        p = _input();
        require(owner.record(p, false) != bytes32(0), "unchanged healthy control");
    }
}
