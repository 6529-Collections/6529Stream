// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistGuardianSupersessionActualTest
} from "./StreamArtistGuardianSupersessionActual.t.sol";
import { ArtistUnitGovernance, ArtistUnitRoles } from "./ArtistOnboardingFixture.sol";
import { ArtistSanctionFinalityFixture } from "./ArtistSanctionFinalityFixture.sol";
import {
    StreamArtistOnboardingRegistry
} from "../../../smart-contracts/domains/artist/StreamArtistOnboardingRegistry.sol";
import {
    StreamArtistOnboardingCoordinator
} from "../../../smart-contracts/domains/artist/StreamArtistOnboardingCoordinator.sol";
import {
    StreamArtistArchiveV2
} from "../../../smart-contracts/domains/artist/StreamArtistArchiveV2.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    IStreamArtistRecoveredHydration as Recovered,
    IStreamArtistRecoveredHydrationOwner as RecoveredOwner,
    IStreamArtistRecoveredNativeChronology as NativeClock
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistRecoveredHydration.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH,
    IStreamArtistAuthorityHydrationOwner as HydrationOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistMultipleHydrationTypes as MH
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistMultipleAuthorityHydration.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistRotationTypes as R
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRotationTypes.sol";
import {
    IStreamArtistOwner as Owner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistOwner.sol";
import {
    IStreamArtistOnboarding
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistOnboarding.sol";
import {
    IStreamArtistRotation
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistRotation.sol";
import {
    IStreamArtistRotationReads
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistRotationOwner.sol";
import {
    IStreamArtistIdentityOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistIdentityOwner.sol";
import {
    IStreamArtistIdentityRecoveryOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistIdentityRecovery.sol";
import {
    IStreamArtistGuardianVestingHistory
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistGuardianVestingHistory.sol";
import {
    StreamArtistIdentityRecoveryOperationTypes as Recovery
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistIdentityRecoveryOperationTypes.sol";
import {
    IStreamArtistRecoveryActionOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistRecoveryAction.sol";
import {
    StreamArtistRecoveryActionTypes as RecoveryAction
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveryActionTypes.sol";
import {
    IStreamArtistIdentityContest
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistIdentityContest.sol";
import {
    IStreamArtistIdentityRecoveryV2
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistIdentityRecoveryV2.sol";
import {
    StreamArtistRecoveryEvidenceTypes as EV2
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveryEvidenceTypes.sol";
import {
    IStreamArtistRecoveryEvidence,
    IStreamArtistRecoveryEvidenceBinding
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistRecoveryEvidence.sol";
import {
    IStreamArtistRecoverySelectionPreparation,
    IStreamArtistRecoverySelectionBinding
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistRecoverySelectionPreparation.sol";
import {
    StreamArtistGuardianSelectionTypes as Selection
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistGuardianSelectionTypes.sol";
import {
    StreamArtistRecoverySelectionTypesV2 as SV2
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoverySelectionTypesV2.sol";
import {
    StreamArtistIdentityDismissalTypes as Dismissal
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistIdentityDismissalTypes.sol";
import {
    IStreamArtistArchiveV2
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistArchiveV2.sol";
import {
    IStreamArtistAuthorityCheckpoint as CP
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityCheckpoint.sol";
import {
    IStreamArtistHistory as History,
    IStreamArtistNativeReceipts as Native,
    StreamArtistHistoryTypes as HT
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistHistory.sol";
import {
    IStreamGovernanceReads
} from "../../../smart-contracts/interfaces/stream/governance/IStreamGovernanceReads.sol";
import {
    GovernanceCall,
    GovernanceActionStatus
} from "../../../smart-contracts/interfaces/stream/governance/StreamGovernanceTypes.sol";
import {
    StreamArtistRecoveredHydrationPrepared as Prepared
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationPrepared.sol";
import {
    StreamArtistRecoveredHydrationCommit as Commit
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationCommit.sol";
import {
    StreamArtistRecoveredHydrationGuards as Guards
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationGuards.sol";
import {
    StreamArtistRecoveredHydrationOwnerPayload as Payload
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationOwnerPayload.sol";
import {
    StreamArtistRecoveredPayloadHydration as Publications
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredPayloadHydration.sol";
import {
    StreamArtistRecoveredTimingTypes as TM,
    IStreamArtistRecoveredTimingInventory
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredTimingTypes.sol";

/// @notice Authored real Safe/Registry/seven-owner/Coordinator/Archive class1 operation60 flow.
/// @dev Core and scheduled governance facts remain the inherited explicit typed unit boundaries.
/// Source/destination capabilities are read unchanged from the production first-graph profile.
/// These positive cases await native execution and gas acceptance. They deliberately do not
/// mock capabilities, checkpoints, original record storage, or owner hydration admission.
import { ArtistRecoveredAuthorityFixture } from "./ArtistRecoveredAuthorityFixture.sol";

contract StreamArtistRecoveredAuthorityActualTest is StreamArtistGuardianSupersessionActualTest, ArtistRecoveredAuthorityFixture {
    function testRecoveredActualSecondImportFlattensOriginalPrefixAndFreshNativeSuffix() external {
        _rhTwoImports();
    }

    function testRecoveredActualThirdRegistryRotatesContestsAndRecoversWithV2() external {
        (Successor memory last, bytes32 retained) = _rhTwoImports();
        bytes32 priorFacts = _rhRecoveryFacts(last.identity);
        _rhAdopt(last);
        R.TransitionState memory original = ingress.artistTransitionState(rhRecovery);
        if (block.timestamp < original.postWindowEndsAt) vm.warp(original.postWindowEndsAt);
        _newRotationSafe(871001);
        bytes32 rotation = _stageRotation(rhRecovery);
        require(
            executeSafe(
                delegateSafe,
                delegateKeys,
                address(ingress),
                0,
                abi.encodeCall(IStreamArtistRotation.approveArtistRotation, (artistId, rotation)),
                0
            ),
            "retained actual guardian Safe approves fresh C29"
        );
        _executeTimedRotation(rotation);
        _adoptRotatedSafe();
        require(
            ingress.rotationRecord(rotation).transition.phase == 2
                && _snapshot(rotation).previousTransitionRecordHash == rhRecovery,
            "actual C32 extends A original35"
        );
        _rhCompromise(rotation);
        _rhRecoverV2(rotation, retained);
        require(
            _rhRecoveryFacts(last.identity) == priorFacts,
            "new C35 preserves A original35 receipts, action and vesting"
        );
    }

    function testRecoveredActualClassOneImportPreservesOriginalsAndFreshGuardian() external {
        _rhBaseline();
        Successor memory next = _rhCutover();
        RH.Request memory request = _rhRequest();
        Commit.Prepared memory prepared =
            Prepared.prepare(next.coordinator.suiteConfiguration(), request);
        request.expectedSemanticInventory = Prepared.inventory(prepared);
        bytes32 sourceBefore = _rhSourceHash();
        bytes32 value = Recovered(address(next.registry)).hydrateRecoveredArtistAuthority(request);
        _rhImported(next, prepared, value);
        require(_rhSourceHash() == sourceBefore, "source originals unchanged");
        _rhFreshGuardian(next);
        require(_rhSourceHash() == sourceBefore, "fresh destination write never changes source");
    }

    function testRecoveredActualChangedSourceCheckpointRejectsAndExactSourceRetry() external {
        _rhBaseline();
        Successor memory next = _rhCutover();
        RH.Request memory request = _rhRequest();
        Commit.Prepared memory prepared =
            Prepared.prepare(next.coordinator.suiteConfiguration(), request);
        request.expectedSemanticInventory = Prepared.inventory(prepared);
        bytes32 before_ = _rhDestinationHash(next);
        ++request.records.authority.expectedSource[2].ownerState.revision;
        avm.expectRevert(RH.InvalidRecoveredHydrationProvenance.selector);
        Recovered(address(next.registry)).hydrateRecoveredArtistAuthority(request);
        require(
            _rhDestinationHash(next) == before_, "bad source certificate leaves all owners intact"
        );
        --request.records.authority.expectedSource[2].ownerState.revision;
        bytes32 value = Recovered(address(next.registry)).hydrateRecoveredArtistAuthority(request);
        _rhImported(next, prepared, value);
    }

    function testRecoveredActualLateArchiveFailureRollsBackAndIdenticalRetry() external {
        _rhBaseline();
        Successor memory next = _rhCutover();
        RH.Request memory request = _rhRequest();
        Commit.Prepared memory prepared =
            Prepared.prepare(next.coordinator.suiteConfiguration(), request);
        request.expectedSemanticInventory = Prepared.inventory(prepared);
        bytes memory call_ = abi.encodeCall(Recovered.hydrateRecoveredArtistAuthority, (request));
        bytes32 before_ = _rhDestinationHash(next);
        bytes32 sourceBefore = _rhSourceHash();
        uint256 nonce = rotationSafe.nonce();
        // Original Archive rejects its uint64 block bound after actual owner applies. No
        // capability, checkpoint, owner, or Archive response is replaced by a mock.
        uint256 originalBlock = block.number;
        vm.roll(uint256(type(uint64).max) + 1);
        vm.expectRevert(
            abi.encodeWithSignature(
                "ArtistArchiveBlockNumberOverflow(uint256)", uint256(type(uint64).max) + 1
            )
        );
        Recovered(address(next.registry)).hydrateRecoveredArtistAuthority(request);
        require(
            _rhDestinationHash(next) == before_, "exact original Archive error restores every owner"
        );
        vm.expectRevert(bytes("GS013"));
        this.rhExecuteNewSafe(address(next.registry), call_);
        require(
            rotationSafe.nonce() == nonce && _rhDestinationHash(next) == before_,
            "Safe plus seven owners and catalogs rollback"
        );
        require(_rhSourceHash() == sourceBefore, "source unchanged after late failure");
        vm.roll(originalBlock);
        require(
            this.rhExecuteNewSafe(address(next.registry), call_), "identical Safe request retries"
        );
        require(rotationSafe.nonce() == nonce + 1, "one successful Safe mutation");
        bytes32 value = HydrationOwner(next.identity).authorityHydrationCommitment();
        _rhImported(next, prepared, value);
    }
}
