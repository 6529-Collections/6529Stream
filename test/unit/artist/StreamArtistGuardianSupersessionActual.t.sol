// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistGuardianAppealTypes as GuardianAppeal
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistGuardianAppealTypes.sol";
import {
    IStreamArtistGuardianSelectionPreparation,
    IStreamArtistGuardianSelectionBinding,
    IStreamArtistGuardianSelectionOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistGuardianSelectionPreparation.sol";
import {
    StreamArtistGuardianSelectionTypes as Selection
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistGuardianSelectionTypes.sol";
import {
    StreamArtistGuardianSupersessionTypes as GS
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistGuardianSupersessionTypes.sol";
import {
    IStreamArtistGuardianSupersession
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistGuardianSupersession.sol";
import {
    StreamArtistIdentityRecoveryHashes as RecoveryHashes
} from "../../../smart-contracts/domains/artist/StreamArtistIdentityRecoveryHashes.sol";

import {
    StreamArtistEstateExtensionDeployment
} from "../../../smart-contracts/domains/artist/StreamArtistEstateExtensionDeployment.sol";
import {
    IStreamArtistRotation
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistRotation.sol";
import {
    IStreamArtistGuardianHistory
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistGuardianHistory.sol";
import {
    StreamArtistGuardianHistoryTypes as GH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistGuardianHistoryTypes.sol";

import {
    ArtistOnboardingFixture,
    ArtistUnitGovernance,
    ArtistUnitRoles
} from "./ArtistOnboardingFixture.sol";
import { Vm } from "../../regression/legacy/helpers/CharacterizationTestBase.sol";
import { OfficialSafe } from "../../helpers/OfficialSafeFixture.sol";
import {
    IStreamArtistIdentityRecovery,
    IStreamArtistIdentityRecoveryOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistIdentityRecovery.sol";
import {
    IStreamArtistIdentityOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistIdentityOwner.sol";
import {
    IStreamArtistOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistOwner.sol";
import {
    IStreamArtistIdentityContest
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistIdentityContest.sol";
import {
    IStreamArtistRotationOwner,
    IStreamArtistRotationReads
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistRotationOwner.sol";
import {
    IStreamGovernanceReads
} from "../../../smart-contracts/interfaces/stream/governance/IStreamGovernanceReads.sol";
import {
    StreamArtistIdentityRecoveryOperationTypes as IdentityRecovery
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistIdentityRecoveryOperationTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistRotationTypes as R
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRotationTypes.sol";
import {
    StreamArtistIdentityContestTypes as Contest
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistIdentityContestTypes.sol";
import {
    StreamArtistIdentityDismissalTypes as Dismissal
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistIdentityDismissalTypes.sol";
import {
    StreamArtistIdentityAuthority
} from "../../../smart-contracts/domains/artist/StreamArtistIdentityAuthority.sol";
import {
    StreamArtistIdentityRecoveryExtension
} from "../../../smart-contracts/domains/artist/StreamArtistIdentityRecoveryExtension.sol";
import {
    StreamArtistIdentityRecoveryGovernance
} from "../../../smart-contracts/domains/artist/StreamArtistIdentityRecoveryGovernance.sol";

import {
    IStreamArtistRecoveryAction,
    IStreamArtistRecoveryActionOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistRecoveryAction.sol";
import {
    StreamArtistRecoveryActionTypes as A
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveryActionTypes.sol";
import {
    IStreamGovernanceActionFacts
} from "../../../smart-contracts/interfaces/stream/governance/IStreamGovernanceActionFacts.sol";
import {
    GovernanceCall,
    GovernanceAction,
    GovernanceActionStatus
} from "../../../smart-contracts/interfaces/stream/governance/StreamGovernanceTypes.sol";

/// @dev Actual Identity/facade/Coordinator/Safe/Archive; scheduled governance facts and current context are explicit typed boundaries.
import {
    StreamArtistGuardianVestingTypes as V
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistGuardianVestingTypes.sol";
import {
    IStreamArtistGuardianVestingHistory
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistGuardianVestingHistory.sol";
import {
    StreamArtistEstateTypes as Estate
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistEstateTypes.sol";

import { ArtistGuardianSupersessionFixture } from "./ArtistGuardianSupersessionFixture.sol";

contract StreamArtistGuardianSupersessionActualTest is ArtistGuardianSupersessionFixture {
    function testActualRecoverySnapshotSharesOneRevisionAndTwoReceiptsWithArchiveRetry() public {
        _guarded();
        IdentityRecovery.Request memory p = _terms();
        T.Authorization memory a = _acceptance(p);
        GovernanceCall[] memory calls = _schedule(keccak256("vesting recovery action"), p, a);
        ingress.registerIdentityRecoveryAction(currentId, calls, p, a);
        vm.warp(scheduled.notBefore);
        scheduled.status = GovernanceActionStatus.EXECUTED;
        _publish();
        T.Snapshot memory before_ = _ownerSnapshot();
        bytes32 roots = _roots();
        _overflow();
        this.executeRegistered(p, a);
        _inactive();
        (bool used,) = ingress.rotationAcceptanceNonceState(artistId, p.newAddress, a.nonce);
        require(
            _roots() == roots && !used && ingress.latestIdentityRecovery(artistId) == 0,
            "recovery nonce/records/snapshot transaction rollback"
        );
        vm.roll(restoreBlock);
        vm.recordLogs();
        bytes32 recovered = this.executeRegistered(p, a);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        V.Snapshot memory saved = _snapshot(recovered);
        _assertSnapshot(saved, 35, before_, logs);
        require(
            saved.guardians.count == 1 && saved.oldAddress == address(artist)
                && saved.newAddress == p.newAddress && saved.previousTransitionRecordHash == 0,
            "same admitted recovery primary and original prefix"
        );
        (bytes32 primary, bytes32 occurrence, bytes32 secondary) =
            IStreamArtistIdentityRecoveryOwner(suite.owners[2]).identityRecoveryReceipts(recovered);
        require(
            primary != 0 && secondary != 0 && occurrence != 0 && primary != occurrence
                && _ownerSnapshot().recordChainTip != before_.recordChainTip,
            "original ordered two-receipt append remains present"
        );
        _sizes();
    }

    function testActualNonemptyGuardianRecoveryAndAtomicArchiveRetry() public {
        _nonempty(false, false);
        IdentityRecovery.Request memory p = _nonemptyTerms();
        T.Authorization memory a = _acceptance(p);
        GovernanceCall[] memory calls = _schedule(keccak256("nonempty actual recovery"), p, a);
        ingress.registerIdentityRecoveryAction(currentId, calls, p, a);
        require(
            _status(attackerGuardian).recoveryRecordHash == 0,
            "preparation creates no executed adjudication"
        );
        bytes32 roots = _roots();
        vm.expectRevert();
        this.vetoByAttacker(keccak256("excluded guardian cannot veto"));
        require(_roots() == roots, "excluded Safe failure leaves owner roots");
        vm.prank(address(artist));
        vm.expectRevert(abi.encodeWithSelector(A.InvalidRecoveryGuardian.selector, address(artist)));
        ingress.vetoIdentityRecovery(artistId, keccak256("exact exclusion error"));
        vm.warp(scheduled.notBefore);
        scheduled.status = GovernanceActionStatus.EXECUTED;
        _publish();
        T.Snapshot memory before_ = _ownerSnapshot();
        _overflow();
        this.executeRegistered(p, a);
        _inactive();
        (bool used,) = ingress.rotationAcceptanceNonceState(artistId, p.newAddress, a.nonce);
        require(
            _roots() == roots && !used && ingress.latestIdentityRecovery(artistId) == 0
                && _status(attackerGuardian).recoveryRecordHash == 0,
            "late Archive rolls back adjudication, acceptance and both receipts"
        );
        vm.roll(restoreBlock);
        vm.recordLogs();
        bytes32 record = this.executeRegistered(p, a);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        IdentityRecovery.Record memory item = ingress.identityRecoveryRecord(record);
        GS.Status memory status = _status(attackerGuardian);
        require(
            status.artistId == artistId && status.recoveryRecordHash == record
                && status.actionId == currentId,
            "actual permanent adjudication coordinate"
        );
        require(
            item.fields.supersededRecordsHash
                    == RecoveryHashes.supersession(p.supersededRecordHashes)
                && keccak256(abi.encode(item.terms.supersededRecordHashes))
                    == keccak256(abi.encode(p.supersededRecordHashes)),
            "unchanged semantic list hash and complete retained list"
        );
        require(
            guardianBeforeHash == keccak256(abi.encode(ingress.guardianSetRecord(attackerGuardian)))
                && rotationBeforeHash
                    == keccak256(abi.encode(ingress.rotationRecord(soleRotation))),
            "original record and executed history immutable"
        );
        (,,, bytes32 selected) = ingress.guardianSet(artistId);
        require(
            selected == lifetimeGuardian && _status(lifetimeGuardian).recoveryRecordHash == 0,
            "retained operative guardian remains selected"
        );
        _assertSnapshot(_snapshot(record), 35, before_, logs);
        (bytes32 primary, bytes32 occurrence, bytes32 secondary) =
            IStreamArtistIdentityRecoveryOwner(suite.owners[2]).identityRecoveryReceipts(record);
        require(
            primary != 0 && secondary != 0 && occurrence != 0 && primary != secondary,
            "actual two immutable receipt commitments"
        );
        bool eventFound;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == suite.owners[2] && logs[i].topics.length == 4
                    && logs[i].topics[0]
                        == keccak256(
                            "ArtistIdentityRecovered(uint16,bytes32,address,address,uint8,bytes32,bytes32,bytes32,uint64,bytes32,bytes32,bytes32[])"
                        )
            ) {
                require(
                    logs[i].topics[1] == artistId
                        && logs[i].topics[2] == bytes32(uint256(uint160(item.fields.oldAddress)))
                        && logs[i].topics[3] == bytes32(uint256(uint160(p.newAddress))),
                    "complete recovery event indexes"
                );
                require(
                    keccak256(logs[i].data)
                        == keccak256(
                            abi.encode(
                                uint16(2),
                                uint8(1),
                                p.evidenceHash,
                                p.reasonHash,
                                item.fields.supersededRecordsHash,
                                item.fields.recoveredAt,
                                record,
                                currentId,
                                p.supersededRecordHashes
                            )
                        ),
                    "complete recovery event data"
                );
                eventFound = true;
            }
        }
        require(eventFound, "actual nonempty owner event");
        _sizes();
    }

    function testActualRetainedGuardianMembershipSurvivesExcludedFirstMembership() public {
        _nonempty(true, false);
        IdentityRecovery.Request memory p = _nonemptyTerms();
        T.Authorization memory a = _acceptance(p);
        GovernanceCall[] memory calls = _schedule(keccak256("retained later membership"), p, a);
        ingress.registerIdentityRecoveryAction(currentId, calls, p, a);
        vm.warp(uint256(scheduled.notBefore) + 1);
        this.vetoByAttacker(keccak256("same actor has a retained later set"));
        (, A.Veto memory veto,,) = _read();
        require(veto.vetoer == address(artist), "later nonexcluded membership preserves Safe veto");
        scheduled.status = GovernanceActionStatus.EXECUTED;
        _publish();
        bytes32 roots = _roots();
        vm.expectRevert(abi.encodeWithSelector(A.RecoveryActionVetoed.selector, currentId));
        this.executeRegistered(p, a);
        _inactive();
        require(
            _roots() == roots && _status(attackerGuardian).recoveryRecordHash == 0,
            "vetoed action cannot apply any adjudication"
        );
        _sizes();
    }

    function testActualPreVestingHeadAndEvidenceExclusionsRejected() public {
        _nonempty(false, true);
        IdentityRecovery.Request memory p = _nonemptyTerms();
        T.Authorization memory a = _acceptance(p);
        bytes32 roots = _roots();
        p.supersededRecordHashes[0] = lifetimeGuardian;
        vm.expectRevert(
            abi.encodeWithSelector(GuardianAppeal.InvalidGuardianAppeal.selector, p.evidenceHash)
        );
        ingress.identityRecoveryContext(p, a);
        p.supersededRecordHashes[0] = retainedAttackerGuardian;
        IStreamArtistGuardianSelectionPreparation preparation = _selectionPreparation();
        bytes32 key = preparation.begin(artistId, soleRotation, p.supersededRecordHashes);
        (GH.Head memory head,,,) = IStreamArtistGuardianHistory(suite.owners[2])
            .guardianHistoryState(artistId, 0, address(0), 0);
        vm.expectRevert(
            abi.encodeWithSelector(
                Selection.IncompleteGuardianSelection.selector, key, uint64(0), head.count
            )
        );
        ingress.identityRecoveryContext(p, a);
        p.supersededRecordHashes[0] = attackerGuardian;
        p.evidenceHash = keccak256("unbound evidence");
        bytes32 contest = ingress.currentIdentityContestCause(artistId).facts.referenceHash;
        vm.expectRevert(abi.encodeWithSelector(GS.InvalidGuardianSupersession.selector, contest));
        ingress.identityRecoveryContext(p, a);
        p.evidenceHash = keccak256("compromise evidence");
        p.supersededRecordHashes = new bytes32[](2);
        p.supersededRecordHashes[0] = attackerGuardian;
        p.supersededRecordHashes[1] = attackerGuardian;
        vm.expectRevert(
            abi.encodeWithSelector(GS.InvalidGuardianSupersession.selector, attackerGuardian)
        );
        ingress.identityRecoveryContext(p, a);
        require(
            _roots() == roots && _status(attackerGuardian).recoveryRecordHash == 0,
            "rejected profiles create no state"
        );
        _sizes();
    }
}
