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
    StreamArtistIdentityDismissalTypes as Dismissal
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistIdentityDismissalTypes.sol";
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
    IStreamArtistRecoveredTimingInventory
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredTimingTypes.sol";

import {
    StreamArtistEstateTypes as Estate
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistEstateTypes.sol";
import {
    IStreamArtistEstateOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistEstateOwner.sol";
import {
    StreamArtistSuccessionTypes as Succ
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistSuccessionTypes.sol";
import {
    IStreamArtistSuccessionReads
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistSuccessionRecords.sol";
import {
    IStreamArtistIdentityDismissalOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistIdentityDismissal.sol";

/// @notice Authored actual class3 operation60 transport and retained estate-authority consumers.
/// @dev The original36/38/40/33/35 recipe follows EstateRecoveryActualTest using its inherited
/// Artist/Safe/Archive producers. Core and scheduled governance facts are explicit unit boundaries.
/// All seven production owners, original payloads, checkpoints and capabilities remain actual.
/// Production first-graph feature flags are read unchanged; native and gas acceptance are pending.
contract StreamArtistRecoveredEstateAuthorityActualTest is
    StreamArtistGuardianSupersessionActualTest
{
    bytes32 private constant RH_LEAF =
        0xea04da6644046a7c731e99312c32df311e81aa7e137dfc2a49c2116bb325195d;
    bytes32 private constant RH_POINTER = keccak256("ARTIST_REGISTRY");

    struct Successor {
        StreamArtistOnboardingRegistry registry;
        StreamArtistArchiveV2 archive;
        StreamArtistOnboardingCoordinator coordinator;
        address identity;
    }
    AH.Origin[][7] private ehCandidates;
    bytes32 private ehGuardian;
    bytes32 private ehRecovery;
    bytes32 private ehOriginalAction;

    bytes32 private ehEstate;
    bytes32 private ehPendingAction;
    bytes32 private ehPendingCause;
    bytes32 private ehPendingContext;
    uint64 private ehEstateExecutionRevision;

    function testRecoveredEstateImportPreservesOriginal40AndConsumesClassThreeAuthority() external {
        _ehBaseline(2304);
        Successor memory next = _ehImport();
        bytes32 sourceBefore = _ehSourceHash();
        address originalOwner = suite.owners[2];
        bytes32 originals = _ehRecoveryFacts(originalOwner);
        _ehFreshGuardian(next);
        require(_ehSourceHash() == sourceBefore, "fresh B28 never changes source state");
        _ehAdopt(next);
        _ehFreshRotation();
        require(
            _ehEstateFacts(next.identity) == ehOriginalEstate,
            "fresh class3 writers retain original38/40 and designation"
        );
        require(
            _ehRecoveryFacts(originalOwner) == originals
                && _ehEstateFacts(originalOwner) == ehOriginalEstate,
            "fresh B32 leaves original A35 and A40 unchanged"
        );
    }

    function testRecoveredEstateImportKeepsZeroCapabilityMask() external {
        _ehBaseline(0);
        Successor memory next = _ehImport();
        bytes32 before_ = _ehDestinationHash(next);
        _ehAdopt(next);
        vm.expectRevert(
            abi.encodeWithSelector(
                Estate.EstateCapabilityUnavailable.selector, artistId, uint32(2048)
            )
        );
        this.ehWriteGuardians();
        require(_ehDestinationHash(next) == before_, "zero-mask denial has no owner/catalog effect");
        _ehRights(next.identity, address(artist), 0, 3);
    }

    function testRecoveredEstateImportRetainsExecutedAndPendingRegisteredActions() external {
        _ehBaseline(2304);
        _adoptRotatedSafe();
        vm.warp(ingress.artistTransitionState(ehRecovery).postWindowEndsAt);
        _ehCompromise(ehRecovery);
        _newRotationSafe(882003);
        Recovery.Request memory p = _ehTerms();
        T.Authorization memory a = _acceptance(p);
        ehPendingAction = keccak256("estate source second pending recovery");
        GovernanceCall[] memory calls = _schedule(ehPendingAction, p, a);
        ingress.registerIdentityRecoveryAction(ehPendingAction, calls, p, a);
        _ehCandidate(2, "identity_authority.replay.recovery_preparation", ehPendingAction);
        ehPendingCause = p.expectedCauseHash;
        ehPendingContext = keccak256(abi.encode(ingress.identityRecoveryContext(p, a)));
        (RecoveryAction.Association memory pending,, bytes32 executed,) = IStreamArtistRecoveryActionOwner(
                suite.owners[2]
            ).identityRecoveryActionState(artistId, ehPendingAction);
        require(
            pending.associationHash != 0 && executed == 0, "real65534 pending without synthetic35"
        );
        (bool used,) = ingress.rotationAcceptanceNonceState(artistId, p.newAddress, a.nonce);
        require(!used, "pending original acceptance remains unconsumed");
        Successor memory next = _ehImport();
        (RecoveryAction.Association memory copied,, bytes32 destinationExecution,) = IStreamArtistRecoveryActionOwner(
                next.identity
            ).identityRecoveryActionState(artistId, ehPendingAction);
        require(
            keccak256(abi.encode(copied)) == keccak256(abi.encode(pending))
                && destinationExecution == 0 && copied.contextHash == ehPendingContext
                && next.registry.currentIdentityContestCause(artistId).causeHash == ehPendingCause,
            "original scheduled action, context and current cause imported exactly"
        );
        (used,) = next.registry.rotationAcceptanceNonceState(artistId, p.newAddress, a.nonce);
        require(!used, "import does not execute scheduled35 or consume its acceptance");
        _ehRights(next.identity, address(artist), 2304, 4);
    }

    function testRecoveredEstateFreshRotationThenRegisteredClassThreeRecovery() external {
        _ehBaseline(2304);
        Successor memory next = _ehImport();
        _ehFreshGuardian(next);
        _ehAdopt(next);
        bytes32 rotation = _ehFreshRotation();
        vm.warp(ingress.artistTransitionState(rotation).postWindowEndsAt);
        _ehCompromise(rotation);
        _newRotationSafe(882004);
        Recovery.Request memory p = _ehTerms();
        T.Authorization memory a = _acceptance(p);
        Recovery.Context memory context = ingress.identityRecoveryContext(p, a);
        GovernanceCall[] memory calls = _schedule(keccak256("current B class3 recovery"), p, a);
        ingress.registerIdentityRecoveryAction(currentId, calls, p, a);
        vm.warp(scheduled.notBefore);
        scheduled.status = GovernanceActionStatus.EXECUTED;
        _publish();
        uint256 count = Native(next.identity).artistNativeReceiptCount();
        bytes32 originalFacts = _ehRecoveryFacts(next.identity);
        bytes32 record = this.executeRegistered(p, a);
        _ehInactive();
        Recovery.Record memory recovered = ingress.identityRecoveryRecord(record);
        require(
            record != ehRecovery && recovered.fields.vestedAuthorityClass == 3
                && recovered.delegationEpoch == context.delegationEpoch + 1
                && _snapshot(record).previousTransitionRecordHash == rotation,
            "real current B35 extends current B32 while retaining class3"
        );
        require(
            Native(next.identity).artistNativeReceiptCount() == count + 2
                && Native(next.identity).artistNativeReceiptAt(count).recordHash == record
                && Native(next.identity).artistNativeReceiptAt(count + 1).recordHash
                    == recovered.fields.supersededRecordsHash
                && NativeClock(next.identity).artistNativeReceiptRevisionAt(count)
                    == NativeClock(next.identity).artistNativeReceiptRevisionAt(count + 1),
            "actual adjacent current35 receipts keep one local mutation revision"
        );
        (bool used,) = ingress.rotationAcceptanceNonceState(artistId, p.newAddress, a.nonce);
        require(
            used && _ehRecoveryFacts(next.identity) == originalFacts,
            "fresh acceptance consumed; original35 intact"
        );
        _ehRights(next.identity, p.newAddress, 2304, 3);
        require(
            _ehEstateFacts(next.identity) == ehOriginalEstate,
            "original40 remains the capability origin"
        );
    }

    bytes32 private ehOriginalEstate;

    function ehWriteGuardians() external returns (bytes32) {
        require(msg.sender == address(this), "fixture caller");
        return _guardianRecord(new address[](0), 0, 0, nextNonce);
    }

    function _ehImport() private returns (Successor memory next) {
        next = _ehCutover();
        RH.Request memory request = _ehRequest();
        // A genuine successful read is a prerequisite of every later assertion. Flags0 therefore
        // cannot make a negative test pass by failing at the profile admission gate.
        Commit.Prepared memory prepared =
            Prepared.prepare(next.coordinator.suiteConfiguration(), request);
        request.expectedSemanticInventory = Prepared.inventory(prepared);
        bytes32 before_ = _ehSourceHash();
        bytes32 value = Recovered(address(next.registry)).hydrateRecoveredArtistAuthority(request);
        _ehImported(next, prepared, value);
        require(_ehSourceHash() == before_, "source owner/checkpoint/catalog originals unchanged");
        require(
            _ehEstateFacts(next.identity) == ehOriginalEstate,
            "exact original estate notice and execution imported"
        );
        RH.Point memory point = RecoveredOwner(next.identity)
            .recoveredHydrationAuxiliaryPoint(
                keccak256("identity_authority.hydration.guardian_vesting"), ehEstate
            );
        require(
            point.ownerIndex == 2 && point.ownerRevision == ehEstateExecutionRevision
                && point.environmentHash == RH.originHash(prepared.admission.provenance.origins[0]),
            "original40 auxiliary execution retains its own source coordinate"
        );
        uint256 source38;
        uint256 source35;
        for (uint256 i; i < prepared.admission.provenance.journals[2].length; ++i) {
            RH.JournalEntry memory row = prepared.admission.provenance.journals[2][i];
            require(row.receipt.operation != 40, "no invented operation40 native receipt");
            if (row.receipt.operation == 38 && row.receipt.recordHash == ehEstate) {
                ++source38;
                require(
                    row.position.point.ownerRevision < point.ownerRevision,
                    "original38 precedes actual40"
                );
            }
            if (row.receipt.operation == 35) ++source35;
        }
        require(
            source38 == 1 && source35 == 2, "one original38 and exactly two original35 occurrences"
        );
    }

    function _ehBaseline(uint32 capabilities) private {
        _ehCandidate(
            0, "binding_lifecycle.replay.proposal_key", keccak256(abi.encode(uint256(1), uint64(1)))
        );
        _ehCandidate(
            2,
            "identity_authority.replay.nonce_allocator",
            keccak256(abi.encode(bytes32(0), uint256(0)))
        );
        T.Authorization memory accepted = _authorization(false);
        bytes32 digest = ingress.acceptanceDigest(1, accepted);
        _ehAuthorization(digest, accepted.nonce);
        accepted.signature = _signature(digest);
        _artistCall(abi.encodeCall(IStreamArtistOnboarding.acceptArtistBinding, (1, accepted)));
        _ehCandidate(
            3,
            "acceptance_lifecycle.replay.record_uniqueness",
            keccak256(abi.encode(uint256(1), uint64(1), uint8(1), address(artist)))
        );
        _delegateSetup();
        address[] memory members = new address[](1);
        members[0] = address(artist);
        ehGuardian = _guardianRecord(members, 1, 10 days, nextNonce);
        R.GuardianRecord memory guardian = ingress.guardianSetRecord(ehGuardian);
        _ehAuthorization(
            ingress.guardianSetDigest(
                guardian.terms, T.Authorization(guardian.nonce, guardian.signedAt, "")
            ),
            guardian.nonce
        );
        _ehCandidate(
            2,
            "identity_authority.replay.guardian_set_chain",
            keccak256(abi.encode(artistId, guardian.nonce))
        );
        Estate.Execution memory activation = _estatePendingFixture(capabilities);
        ehEstate = activation.expectedActivationRecordHash;
        (Estate.RequestRecord memory item,,) = ingress.estateActivationRecord(ehEstate);
        Succ.DesignationRecord memory designation =
            ingress.successorDesignationRecord(item.designationRecordHash);
        _ehAuthorization(
            ingress.successorDesignationDigest(
                designation.terms, T.Authorization(designation.nonce, designation.signedAt, "")
            ),
            designation.nonce
        );
        _ehCandidate(
            2,
            "identity_authority.replay.succession_chain",
            keccak256(abi.encode(designation.recordHash))
        );
        digest = ingress.estateActivationDigest(item.terms, item.authorization);
        _ehCandidate(
            2,
            "identity_authority.replay.authorization_consumed_digest",
            keccak256(abi.encode(artistId, digest))
        );
        _ehCandidate(
            2,
            "identity_authority.replay.nonce_allocator",
            keccak256(
                abi.encode(
                    "estate_activation", artistId, item.terms.successor, item.authorization.nonce
                )
            )
        );
        _ehCandidate(2, "identity_authority.replay.activation_request_key", ehEstate);
        uint256 nativeBefore = Native(suite.owners[2]).artistNativeReceiptCount();
        vm.warp(item.noticeEndsAt);
        ingress.executeEstateActivation(activation);
        ehEstateExecutionRevision = _ownerSnapshot().revision;
        require(
            Native(suite.owners[2]).artistNativeReceiptCount() == nativeBefore,
            "original40 has no normative new native row"
        );
        require(
            _snapshot(ehEstate).operationId == 40 && _snapshot(ehEstate).authorityClass == 3
                && _snapshot(ehEstate).guardians.count == 1,
            "real40 freezes exact living guardian prefix"
        );
        _ehCandidate(2, "identity_authority.replay.activation_execution_key", ehEstate);
        _ehCandidate(
            2,
            "identity_authority.replay.standing_retirement",
            keccak256(abi.encode(artistId, item.incumbent, ehEstate))
        );
        artist = delegateSafe;
        keys = delegateKeys;
        nextNonce = IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId).nonceHint;
        vm.warp(ingress.artistTransitionState(ehEstate).postWindowEndsAt);
        _ehCompromise(ehEstate);
        _newRotationSafe(882001);
        Recovery.Request memory p = _ehTerms();
        T.Authorization memory a = _acceptance(p);
        GovernanceCall[] memory calls =
            _schedule(keccak256("estate source original recovery"), p, a);
        ehOriginalAction = currentId;
        ingress.registerIdentityRecoveryAction(currentId, calls, p, a);
        _ehCandidate(2, "identity_authority.replay.recovery_preparation", currentId);
        vm.warp(scheduled.notBefore);
        scheduled.status = GovernanceActionStatus.EXECUTED;
        _publish();
        Recovery.Context memory context = ingress.identityRecoveryContext(p, a);
        ehRecovery = this.executeRegistered(p, a);
        _ehInactive();
        Recovery.Record memory recovered = ingress.identityRecoveryRecord(ehRecovery);
        require(
            recovered.fields.vestedAuthorityClass == 3
                && recovered.fields.newAddress == address(rotationSafe)
                && recovered.delegationEpoch == context.delegationEpoch + 1
                && _snapshot(ehRecovery).previousTransitionRecordHash == ehEstate,
            "genuine registered class3 original35 retains40 ancestry"
        );
        _ehOriginalReceipts(recovered);
        _ehRights(suite.owners[2], address(rotationSafe), capabilities, 3);
        _ehCandidate(
            2,
            "identity_authority.replay.authorization_consumed_digest",
            keccak256(abi.encode(artistId, recovered.acceptanceDigest))
        );
        _ehCandidate(
            2,
            "identity_authority.replay.nonce_allocator",
            keccak256(
                abi.encode(
                    keccak256("rotation_acceptance"), artistId, address(rotationSafe), a.nonce
                )
            )
        );
        _ehCandidate(
            2,
            "identity_authority.replay.contest_resolution",
            keccak256(abi.encode(artistId, context.causeHash))
        );
        _ehCandidate(
            2,
            "identity_authority.replay.recovery_action",
            keccak256(
                abi.encode(currentId, context.scopeHash, context.oldValueHash, context.newValueHash)
            )
        );
        _ehCandidate(
            2,
            "identity_authority.replay.standing_retirement",
            keccak256(abi.encode(artistId, context.incumbent, ehRecovery))
        );
        _ehCandidate(2, "identity_authority.replay.one_way_cutover_latch", 0);
        ehOriginalEstate = _ehEstateFacts(suite.owners[2]);
    }

    function _ehOriginalReceipts(Recovery.Record memory recovered) private view {
        uint256 count = Native(suite.owners[2]).artistNativeReceiptCount();
        HT.Receipt memory first = Native(suite.owners[2]).artistNativeReceiptAt(count - 2);
        HT.Receipt memory second = Native(suite.owners[2]).artistNativeReceiptAt(count - 1);
        require(
            first.operation == 35 && second.operation == 35 && first.artistId == artistId
                && second.artistId == artistId && first.recordHash == ehRecovery
                && second.recordHash == recovered.fields.supersededRecordsHash
                && NativeClock(suite.owners[2]).artistNativeReceiptRevisionAt(count - 2)
                    == _snapshot(ehRecovery).ownerRevision
                && NativeClock(suite.owners[2]).artistNativeReceiptRevisionAt(count - 1)
                    == _snapshot(ehRecovery).ownerRevision,
            "actual original adjacent35 occurrences share their own vesting revision"
        );
        (bytes32 primary, bytes32 occurrence, bytes32 secondary) =
            IStreamArtistIdentityRecoveryOwner(suite.owners[2]).identityRecoveryReceipts(ehRecovery);
        (
            RecoveryAction.Association memory action,
            RecoveryAction.Veto memory veto,
            bytes32 execution,
        ) = IStreamArtistRecoveryActionOwner(suite.owners[2])
            .identityRecoveryActionState(artistId, ehOriginalAction);
        require(
            primary != 0 && occurrence != 0 && secondary != 0 && primary != secondary
                && action.associationHash != 0 && veto.vetoer == address(0)
                && execution == ehRecovery,
            "actual registered action executed once with both original receipt commitments"
        );
    }

    function _ehTerms() private view returns (Recovery.Request memory) {
        Dismissal.Cause memory cause = ingress.currentIdentityContestCause(artistId);
        return Recovery.Request(
            artistId,
            address(rotationSafe),
            3,
            cause.causeHash,
            ingress.latestIdentityContestDismissal(artistId),
            cause.facts.evidenceHash,
            cause.facts.reasonHash,
            new bytes32[](0)
        );
    }

    function _ehCompromise(bytes32 subject) private {
        ArtistUnitGovernance authority = ArtistUnitGovernance(manager.governanceAuthority());
        ArtistUnitRoles(suite.roleRegistry).setArbiter(address(artist), true);
        bytes32 evidence = keccak256(abi.encode("estate import real compromise", subject));
        bytes32 reason = keccak256(abi.encode("estate import compromise reason", subject));
        authority.configureContestReads(
            suite.roleRegistry, address(artist), reason, "urn:estate-import:33"
        );
        (bytes32 scope, bytes32 old_, bytes32 next_) =
            ingress.identityContestGovernanceContext(artistId, subject, evidence, reason);
        _ehActive(keccak256("unit authority gas raise"), 1, scope, old_, next_);
        authority.executeModuleContext(
            address(ingress),
            abi.encodeCall(
                IStreamArtistIdentityContest.contestArtistIdentity,
                (artistId, subject, evidence, reason)
            ),
            1,
            scope,
            old_,
            next_
        );
        _ehInactive();
        Dismissal.Cause memory cause = ingress.currentIdentityContestCause(artistId);
        require(
            cause.facts.kind == 1 && cause.facts.authorityClass == 3 && cause.facts.priorStatus == 3
                && cause.facts.executedTransitionHash == subject
                && cause.facts.incumbent == address(artist),
            "real original class3 compromise producer"
        );
        _ehCandidate(
            2,
            "identity_authority.replay.contest_record_hash_and_subject_key",
            keccak256(abi.encode(keccak256("subject"), artistId, subject, evidence, reason))
        );
        _ehCandidate(
            2,
            "identity_authority.replay.contest_record_hash_and_subject_key",
            keccak256(abi.encode(keccak256("record"), cause.facts.referenceHash))
        );
    }

    function _ehRights(address owner, address account, uint32 mask, uint8 status) private view {
        Estate.AuthorityCapabilities memory rights =
            IStreamArtistEstateOwner(owner).currentAuthorityCapabilities(artistId);
        require(
            rights.authorityAddress == account && rights.authorityClass == 3
                && rights.status == status && rights.effectiveCapabilities == mask
                && rights.activationRecordHash == ehEstate,
            "exact original40 capability origin and current class3 principal"
        );
    }

    function _ehEstateFacts(address owner) private view returns (bytes32) {
        (Estate.RequestRecord memory item, uint8 phase, Estate.ExecutionFacts memory execution) =
            IStreamArtistEstateOwner(owner).estateActivationRecord(ehEstate);
        (address prior, bytes32 guardian, uint64 tail) =
            IStreamArtistEstateOwner(owner).estateTransitionStanding(ehEstate);
        return keccak256(
            abi.encode(
                item,
                phase,
                execution,
                IStreamArtistRotationReads(owner).artistTransitionState(ehEstate),
                IStreamArtistGuardianVestingHistory(owner)
                    .guardianVestingSnapshot(artistId, ehEstate),
                IStreamArtistIdentityDismissalOwner(owner)
                    .identityTransitionClosure(artistId, ehEstate),
                IStreamArtistSuccessionReads(owner)
                    .successorDesignationRecord(item.designationRecordHash),
                prior,
                guardian,
                tail
            )
        );
    }

    function _ehFreshRotation() private returns (bytes32 record) {
        R.TransitionState memory prior = ingress.artistTransitionState(ehRecovery);
        if (block.timestamp < prior.postWindowEndsAt) vm.warp(prior.postWindowEndsAt);
        bytes32 originalFacts = _ehRecoveryFacts(suite.owners[2]);
        _newRotationSafe(882002);
        record = _stageRotation(ehRecovery);
        require(
            executeSafe(
                delegateSafe,
                delegateKeys,
                address(ingress),
                0,
                abi.encodeCall(IStreamArtistRotation.approveArtistRotation, (artistId, record)),
                0
            ),
            "retained estate Safe now acts as fresh28 guardian for B29"
        );
        _executeTimedRotation(record);
        _adoptRotatedSafe();
        require(
            ingress.rotationRecord(record).transition.phase == 2
                && _snapshot(record).operationId == 32 && _snapshot(record).authorityClass == 3
                && _snapshot(record).previousTransitionRecordHash == ehRecovery,
            "actual B32 consumes retained original40 authority"
        );
        _ehRights(suite.owners[2], address(artist), 2304, 3);
        require(
            _ehRecoveryFacts(suite.owners[2]) == originalFacts,
            "fresh32 preserves original35 and its action"
        );
    }

    function _ehActive(bytes32 action, uint8 class_, bytes32 scope, bytes32 old_, bytes32 next_)
        private
    {
        address authority = manager.governanceAuthority();
        avm.mockCall(
            authority,
            abi.encodeCall(IStreamGovernanceReads.currentAction, ()),
            abi.encode(true, action, class_, scope, old_, next_)
        );
        (bool active, bytes32 id, uint8 c, bytes32 s, bytes32 o, bytes32 n) =
            IStreamGovernanceReads(authority).currentAction();
        require(
            active && id == action && c == class_ && s == scope && o == old_ && n == next_,
            "exact governed current-action witness"
        );
    }

    function _ehInactive() private {
        _inactive();
        (bool active, bytes32 id, uint8 c, bytes32 s, bytes32 o, bytes32 n) =
            IStreamGovernanceReads(manager.governanceAuthority()).currentAction();
        require(
            !active && id == 0 && c == 0 && s == 0 && o == 0 && n == 0,
            "all-zero inactive context restored"
        );
    }

    function ehExecuteNewSafe(address target, bytes calldata data) external returns (bool) {
        require(msg.sender == address(this), "fixture caller");
        return executeSafe(rotationSafe, rotationKeys, target, 0, data, 0);
    }

    function _ehCandidate(uint8 owner, string memory surface, bytes32 scope) private {
        ehCandidates[owner].push(AH.Origin(keccak256(bytes(surface)), scope));
    }

    function _ehAuthorization(bytes32 digest, uint256 nonce) private {
        _ehCandidate(
            2,
            "identity_authority.replay.authorization_consumed_digest",
            keccak256(abi.encode(artistId, digest))
        );
        _ehCandidate(
            2, "identity_authority.replay.nonce_allocator", keccak256(abi.encode(artistId, nonce))
        );
    }

    function _ehRequest() private view returns (RH.Request memory p) {
        (, p.expectedSourceImportCommitment,) =
            RecoveredOwner(suite.owners[2]).recoveredHydrationImportedPrefix();
        p.records.authority.artistIds = new bytes32[](1);
        p.records.authority.artistIds[0] = artistId;
        p.records.authority.collections = new MH.Collection[](1);
        p.records.authority.collections[0] = MH.Collection(artistId, 1, new AH.PolicyKey[](0));
        for (uint8 owner; owner < 7; ++owner) {
            p.expectedCapabilities[owner] =
                RecoveredOwner(suite.owners[owner]).recoveredAuthorityHydrationCapability();
            CP.Checkpoint memory checkpoint = CP(suite.owners[owner]).authorityCheckpoint();
            p.records.authority.expectedSource[owner] = checkpoint;
            p.records.authority.replayOrigins[owner] = new AH.Origin[](checkpoint.replayCount);
            for (uint256 j; j < checkpoint.replayCount; ++j) {
                (bytes32 key,) = CP(suite.owners[owner]).authorityReplayAt(j);
                bool found;
                for (uint256 k; k < ehCandidates[owner].length; ++k) {
                    if (_ehSourceKey(owner, ehCandidates[owner][k]) != key) continue;
                    p.records.authority.replayOrigins[owner][j] = ehCandidates[owner][k];
                    found = true;
                    break;
                }
                require(found, "exact writer preimage for every real source key");
            }
        }
    }

    function _ehSourceKey(uint8 owner, AH.Origin memory logical) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"),
                block.chainid,
                address(ingress),
                address(coordinator),
                address(archive),
                suite.owners[owner],
                Owner(suite.owners[owner]).domainId(),
                logical.surface,
                logical.scope
            )
        );
    }

    function _ehImported(Successor memory next, Commit.Prepared memory prepared, bytes32 value)
        private
        view
    {
        require(value != 0, "actual operation60 commitment");
        T.SuiteConfiguration memory destination = next.coordinator.suiteConfiguration();
        for (uint8 i; i < 7; ++i) {
            address owner = destination.owners[i];
            T.Snapshot memory after_ = Owner(owner).ownerStateSnapshotV2();
            require(
                after_.revision == prepared.admission.before_[i].revision + 1
                    && after_.recordChainTip == prepared.admission.before_[i].recordChainTip,
                "one destination mutation without fake original receipts"
            );
            require(
                HydrationOwner(owner).authorityHydrationCommitment() == value
                    && Native(owner).artistNativeReceiptCount() == 0,
                "every owner installed, local native journal still empty"
            );
            (RH.OwnerProvenance memory prefix, bytes32 commitment, uint64 installedAt) =
                RecoveredOwner(owner).recoveredHydrationImportedPrefix();
            require(
                commitment == value && installedAt == after_.revision
                    && keccak256(abi.encode(prefix))
                        == keccak256(
                            abi.encode(RH.ownerProvenance(prepared.admission.provenance, i))
                        ),
                "exact full imported prefix including paired native occurrences"
            );
            (, Payload.Payload memory payload) = Payload.decode(prepared.data[i].typedState, i);
            require(
                keccak256(abi.encode(Publications.collect(owner, i)))
                    == keccak256(abi.encode(payload.publications)),
                "original source pointers remain catalogued"
            );
            RH.NonceInventory[] memory nonces =
                Guards.collectNonces(owner, CP(owner).authorityCheckpoint());
            require(
                keccak256(abi.encode(nonces)) == keccak256(abi.encode(payload.nonces)),
                "complete original nonce words and hints"
            );
            _ehGuardCells(
                owner, i, prepared.data[i], prefix, destination, address(next.coordinator)
            );
        }
        require(
            keccak256(abi.encode(IStreamArtistIdentityOwner(next.identity).identity(artistId)))
                == keccak256(
                    abi.encode(IStreamArtistIdentityOwner(suite.owners[2]).identity(artistId))
                ),
            "exact recovered identity"
        );
        require(
            keccak256(abi.encode(next.registry.guardianSetRecord(ehGuardian)))
                == keccak256(abi.encode(ingress.guardianSetRecord(ehGuardian))),
            "exact original guardian body"
        );
        require(
            keccak256(abi.encode(next.registry.identityRecoveryRecord(ehRecovery)))
                == keccak256(abi.encode(ingress.identityRecoveryRecord(ehRecovery))),
            "exact original35 body"
        );
        require(
            _ehRecoveryFacts(next.identity) == _ehRecoveryFacts(suite.owners[2]),
            "original transition, vesting, action and receipt oracle"
        );
        (,,, uint64 sourceCount) = IStreamArtistRecoveryActionOwner(suite.owners[2])
            .identityRecoveryActionState(artistId, currentId);
        (,,, uint64 targetCount) = IStreamArtistRecoveryActionOwner(next.identity)
            .identityRecoveryActionState(artistId, currentId);
        require(sourceCount == targetCount, "full lifetime guardian count imported");
        require(
            keccak256(
                abi.encode(
                    IStreamArtistRecoveredTimingInventory(next.identity).recoveredTimingCheckpoint()
                )
            ) == keccak256(abi.encode(prepared.timing)),
            "separate timing retained"
        );
    }

    function _ehGuardCells(
        address owner,
        uint8 index,
        AH.OwnerData memory data,
        RH.OwnerProvenance memory prefix,
        T.SuiteConfiguration memory destination,
        address destinationCoordinator
    ) private view {
        RH.OriginEnvironment memory env;
        env.chainId = block.chainid;
        env.registry = destination.registry;
        env.coordinator = destinationCoordinator;
        env.archive = destination.archive;
        env.owners = destination.owners;
        for (uint256 j; j < data.origins.length; ++j) {
            bytes32 key = Guards.replayKey(env, index, data.origins[j]);
            if (
                index == 2
                    && data.origins[j].surface
                        == keccak256("identity_authority.replay.one_way_cutover_latch")
            ) {
                require(
                    Owner(owner).replayCell(key).status == 0,
                    "source57 history does not seal destination"
                );
                continue;
            }
            if (
                index == 2
                    && (data.origins[j].surface
                            == keccak256("identity_authority.replay.verified_lane_key")
                        || data.origins[j].surface
                            == keccak256("identity_authority.replay.import_binding"))
            ) {
                T.ReplayCell memory local = Owner(owner).replayCell(key);
                require(
                    local.commitment != 0 && local.kind == 1 && local.status == 2,
                    "actual current56 latch stays current"
                );
                RH.Point memory point = RecoveredOwner(owner).recoveredHydrationReplayPoint(key);
                require(
                    point.ownerIndex == 2
                        && point.ownerRevision < Owner(owner).ownerStateSnapshotV2().revision,
                    "current56 point precedes local60"
                );
                continue;
            }
            require(
                keccak256(abi.encode(Owner(owner).replayCell(key)))
                    == keccak256(abi.encode(data.cells[j])),
                "exact current guard retained"
            );
            bool found;
            for (uint256 k; k < prefix.aliases.length; ++k) {
                if (prefix.aliases[k].originalKey != data.sourceKeys[j]) continue;
                require(
                    keccak256(abi.encode(RecoveredOwner(owner).recoveredHydrationReplayPoint(key)))
                        == keccak256(abi.encode(prefix.aliases[k].admittedAt)),
                    "copied mutation clock retains source origin"
                );
                found = true;
            }
            require(found, "guard belongs to original prefix");
        }
    }

    function _ehRecoveryFacts(address owner) private view returns (bytes32) {
        (bytes32 primary, bytes32 occurrence, bytes32 secondary) =
            IStreamArtistIdentityRecoveryOwner(owner).identityRecoveryReceipts(ehRecovery);
        // The fourth return is today's lifetime guardian count, which a fresh28 must increase.
        // Only the original immutable action association/veto/execution belong in this digest.
        (
            RecoveryAction.Association memory action,
            RecoveryAction.Veto memory veto,
            bytes32 execution,
        ) = IStreamArtistRecoveryActionOwner(owner)
            .identityRecoveryActionState(artistId, ehOriginalAction);
        return keccak256(
            abi.encode(
                IStreamArtistRotationReads(owner).artistTransitionState(ehRecovery),
                IStreamArtistGuardianVestingHistory(owner)
                    .guardianVestingSnapshot(artistId, ehRecovery),
                IStreamArtistIdentityDismissalOwner(owner)
                    .identityTransitionClosure(artistId, ehRecovery),
                primary,
                occurrence,
                secondary,
                action,
                veto,
                execution
            )
        );
    }

    function _ehFreshGuardian(Successor memory next) private returns (bytes32 record) {
        (,,, uint64 priorCount) = IStreamArtistRecoveryActionOwner(next.identity)
            .identityRecoveryActionState(artistId, currentId);
        address[] memory members = new address[](1);
        members[0] = address(delegateSafe);
        R.GuardianSet memory terms = R.GuardianSet(artistId, members, 1, 10 days);
        T.Authorization memory a = T.Authorization(
            IStreamArtistIdentityOwner(next.identity).identity(artistId).nonceHint,
            uint64(block.timestamp),
            ""
        );
        bytes32 digest = next.registry.guardianSetDigest(terms, a);
        a.signature = safeThresholdSignature(
            rotationKeys, safeMessageDigest(rotationSafe, abi.encode(digest))
        );
        require(
            this.ehExecuteNewSafe(
                address(next.registry),
                abi.encodeCall(IStreamArtistRotation.setArtistGuardians, (terms, a))
            ),
            "real recovered Safe fresh guardian write"
        );
        require(Native(next.identity).artistNativeReceiptCount() == 1, "one actual local suffix28");
        (,,, uint64 currentCount) = IStreamArtistRecoveryActionOwner(next.identity)
            .identityRecoveryActionState(artistId, currentId);
        require(
            currentCount == priorCount + 1, "new actual28 extends lifetime membership exactly once"
        );
        HT.Receipt memory row = Native(next.identity).artistNativeReceiptAt(0);
        record = row.recordHash;
        _ehAuthorization(digest, a.nonce);
        _ehCandidate(
            2,
            "identity_authority.replay.guardian_set_chain",
            keccak256(abi.encode(artistId, a.nonce))
        );
        require(
            row.operation == 28 && row.artistId == artistId && row.recordHash != ehGuardian,
            "new original guardian receipt"
        );
        R.GuardianRecord memory guardian = next.registry.guardianSetRecord(row.recordHash);
        require(
            guardian.signer == address(rotationSafe)
                && guardian.provisional.transitionRecordHash == ehRecovery,
            "new record keeps original source35 association"
        );
        require(
            NativeClock(next.identity).artistNativeReceiptRevisionAt(0)
                == Owner(next.identity).ownerStateSnapshotV2().revision,
            "actual local mutation counter without a revision jump"
        );
        require(
            _ehRecoveryFacts(next.identity) == _ehRecoveryFacts(suite.owners[2]),
            "fresh28 preserves original35 and registered action"
        );
    }

    function _ehSourceHash() private view returns (bytes32 hash) {
        for (uint8 i; i < 7; ++i) {
            hash = keccak256(
                abi.encode(
                    hash,
                    CP(suite.owners[i]).authorityCheckpoint(),
                    Publications.collect(suite.owners[i], i)
                )
            );
        }
        return keccak256(
            abi.encode(
                hash,
                _ehRecoveryFacts(suite.owners[2]),
                _ehEstateFacts(suite.owners[2]),
                ingress.identityRecoveryRecord(ehRecovery),
                ingress.guardianSetRecord(ehGuardian)
            )
        );
    }

    function _ehDestinationHash(Successor memory next) private view returns (bytes32 hash) {
        T.SuiteConfiguration memory s = next.coordinator.suiteConfiguration();
        for (uint8 i; i < 7; ++i) {
            (RH.OwnerProvenance memory prefix, bytes32 value, uint64 importedAt) =
                RecoveredOwner(s.owners[i]).recoveredHydrationImportedPrefix();
            hash = keccak256(
                abi.encode(
                    hash,
                    CP(s.owners[i]).authorityCheckpoint(),
                    prefix,
                    value,
                    importedAt,
                    Publications.collect(s.owners[i], i)
                )
            );
        }
        return keccak256(
            abi.encode(
                hash,
                IStreamArtistIdentityOwner(next.identity).identity(artistId),
                IStreamArtistRecoveredTimingInventory(next.identity).recoveredTimingCheckpoint()
            )
        );
    }

    function _ehCutover() private returns (Successor memory next) {
        next = _ehNext();
        HT.Leaf[] memory rows = _ehLeaves(History(address(ingress)));
        (bytes32 root,) = _ehProof(address(ingress), rows, 0);
        bytes32 manifest = keccak256("recovered estate actual source manifest");
        HT.Context memory c = History(address(next.registry))
            .artistHistoryImportContext(address(ingress), uint64(block.number), root, manifest);
        _ehCandidate(
            2,
            "identity_authority.replay.governance_action",
            keccak256(
                abi.encode(
                    keccak256("unit authority gas raise"),
                    c.scopeHash,
                    c.oldValueHash,
                    c.newValueHash
                )
            )
        );
        _ehCandidate(
            2,
            "identity_authority.replay.import_binding_key",
            keccak256(
                abi.encode(HT.Binding(address(ingress), uint64(block.number), root, manifest))
            )
        );
        _ehCandidate(
            2,
            "identity_authority.replay.verified_lane_key",
            keccak256(abi.encode(uint8(1), artistId))
        );
        _ehCandidate(
            2,
            "identity_authority.replay.import_binding",
            keccak256(abi.encode(uint256(0), uint8(1), artistId))
        );
        _ehCandidate(
            2,
            "identity_authority.replay.verified_lane_key",
            keccak256(abi.encode(uint8(2), bytes32(uint256(1))))
        );
        _ehCandidate(
            2,
            "identity_authority.replay.import_binding",
            keccak256(abi.encode(uint256(0), uint8(2), bytes32(uint256(1))))
        );
        ArtistUnitGovernance authority = ArtistUnitGovernance(manager.governanceAuthority());
        authority.configureContestReads(
            suite.roleRegistry, address(artist), manifest, "urn:history"
        );
        avm.mockCall(
            address(authority),
            abi.encodeWithSignature("currentAction()"),
            abi.encode(
                true,
                keccak256("unit authority gas raise"),
                uint8(1),
                c.scopeHash,
                c.oldValueHash,
                c.newValueHash
            )
        );
        (
            bool active,
            bytes32 action,
            uint8 class_,
            bytes32 scope,
            bytes32 oldHash,
            bytes32 newHash
        ) = IStreamGovernanceReads(address(authority)).currentAction();
        require(
            active && action == keccak256("unit authority gas raise") && class_ == 1
                && scope == c.scopeHash && oldHash == c.oldValueHash && newHash == c.newValueHash,
            "exact current op55 witness"
        );
        require(
            this.executeTargetSafe(
                address(authority),
                abi.encodeCall(
                    ArtistUnitGovernance.executeModuleContext,
                    (
                        address(next.registry),
                        abi.encodeCall(
                            History.commitArtistHistoryImportRoot,
                            (address(ingress), uint64(block.number), root, manifest)
                        ),
                        uint8(1),
                        c.scopeHash,
                        c.oldValueHash,
                        c.newValueHash
                    )
                )
            ),
            "actual Safe governed55"
        );
        _inactive();
        (active, action, class_, scope, oldHash, newHash) =
            IStreamGovernanceReads(address(authority)).currentAction();
        require(
            !active && action == 0 && class_ == 0 && scope == 0 && oldHash == 0 && newHash == 0,
            "inactive after actual55"
        );
        core.set(RH_POINTER, address(next.registry), false);
        History(address(ingress)).observeRegistryCutover();
        (, uint64 count) = History(address(ingress)).artistHistoryLane(1, artistId);
        (, bytes32[] memory proof) = _ehProof(address(ingress), rows, count - 1);
        History(address(next.registry)).verifyImportedLaneTip(0, rows[count - 1], proof);
        (, proof) = _ehProof(address(ingress), rows, rows.length - 1);
        History(address(next.registry)).verifyImportedLaneTip(0, rows[rows.length - 1], proof);
    }

    function _ehAdopt(Successor memory next) private {
        ingress = next.registry;
        coordinator = next.coordinator;
        archive = next.archive;
        suite = next.coordinator.suiteConfiguration();
        artist = rotationSafe;
        keys = rotationKeys;
        nextNonce = IStreamArtistIdentityOwner(next.identity).identity(artistId).nonceHint;
    }

    function _ehNext() private returns (Successor memory next) {
        T.SuiteConfiguration memory s = suite;
        address governance = manager.governanceAuthority();
        ArtistSanctionFinalityFixture finalityFixture = new ArtistSanctionFinalityFixture();
        uint256 nonce = avm.getNonce(address(this));
        address registry_ = avm.computeCreateAddress(address(this), nonce);
        address archive_ = avm.computeCreateAddress(address(this), nonce + 1);
        address coordinator_ = avm.computeCreateAddress(address(this), nonce + 9);
        address identity_ = avm.computeCreateAddress(address(this), nonce + 4);
        address[3] memory facade;
        address[3] memory identity;
        for (uint8 i; i < 3; ++i) {
            facade[i] = artistExtensionFactory.deployRegistry(i + 4, registry_, coordinator_);
        }
        for (uint8 i; i < 3; ++i) {
            identity[i] = artistExtensionFactory.deployIdentity(
                i + 1, [identity_, registry_, coordinator_, archive_, s.core, s.mintManager]
            );
        }
        next.registry = StreamArtistOnboardingRegistry(
            payable(_artistArtifactCreate(
                    "smart-contracts/domains/artist/StreamArtistOnboardingRegistry.sol:StreamArtistOnboardingRegistry",
                    abi.encode(
                        s.core,
                        s.mintManager,
                        coordinator_,
                        governance,
                        address(estateCoverageProvider),
                        keccak256("recovered successor deployment"),
                        "urn:recovered-successor",
                        keccak256("recovered successor manifest"),
                        address(artistExtensionFactory),
                        facade
                    )
                ))
        );
        next.archive = StreamArtistArchiveV2(
            payable(_artistArtifactCreate(
                    "smart-contracts/domains/artist/StreamArtistArchiveV2.sol:StreamArtistArchiveV2",
                    abi.encode(registry_, coordinator_)
                ))
        );
        s.registry = registry_;
        s.archive = archive_;
        string[7] memory artifacts_ = [
            "smart-contracts/domains/artist/StreamArtistBindingLifecycle.sol:StreamArtistBindingLifecycle",
            "smart-contracts/domains/artist/StreamArtistCollaboratorLifecycle.sol:StreamArtistCollaboratorLifecycle",
            "smart-contracts/domains/artist/StreamArtistIdentityAuthority.sol:StreamArtistIdentityAuthority",
            "smart-contracts/domains/artist/StreamArtistAcceptanceLifecycle.sol:StreamArtistAcceptanceLifecycle",
            "smart-contracts/domains/artist/StreamArtistAttributionLifecycle.sol:StreamArtistAttributionLifecycle",
            "smart-contracts/domains/artist/StreamArtistPayoutLifecycle.sol:StreamArtistPayoutLifecycle",
            "smart-contracts/domains/artist/StreamArtistConsentFinalityLifecycle.sol:StreamArtistConsentFinalityLifecycle"
        ];
        for (uint8 i; i < 7; ++i) {
            bytes memory args = i == 2
                ? abi.encode(
                    registry_,
                    coordinator_,
                    archive_,
                    s.core,
                    s.mintManager,
                    address(artistExtensionFactory),
                    identity
                )
                : abi.encode(registry_, coordinator_, archive_, s.core, s.mintManager);
            s.owners[i] = _artistArtifactCreate(artifacts_[i], args);
        }
        ArtistUnitGovernance(governance)
            .configureContestReads(
                s.roleRegistry,
                address(artist),
                keccak256("recovered successor finality"),
                "urn:successor"
            );
        address finality = finalityFixture.deploy(s.core, s.metadata, registry_, governance);
        next.coordinator = StreamArtistOnboardingCoordinator(
            payable(_artistArtifactCreate(
                    "smart-contracts/domains/artist/StreamArtistOnboardingCoordinator.sol:StreamArtistOnboardingCoordinator",
                    abi.encode(s, finality)
                ))
        );
        next.identity = s.owners[2];
        require(
            address(next.registry) == registry_ && address(next.archive) == archive_
                && address(next.coordinator) == coordinator_ && next.identity == identity_,
            "actual successor deployment pins"
        );
    }

    function _ehLeaves(History h) private view returns (HT.Leaf[] memory rows) {
        (, uint64 a) = h.artistHistoryLane(1, artistId);
        (, uint64 b) = h.artistHistoryLane(2, bytes32(uint256(1)));
        rows = new HT.Leaf[](uint256(a) + b);
        for (uint64 i; i < a; ++i) {
            (bytes32 r, bytes32 c) = h.artistHistoryRecordAt(1, artistId, i);
            rows[i] = HT.Leaf(1, artistId, i, r, c);
        }
        for (uint64 i; i < b; ++i) {
            (bytes32 r, bytes32 c) = h.artistHistoryRecordAt(2, bytes32(uint256(1)), i);
            rows[uint256(a) + i] = HT.Leaf(2, bytes32(uint256(1)), i, r, c);
        }
    }

    function _ehLeaf(address predecessor, HT.Leaf memory p) private view returns (bytes32) {
        return keccak256(
            bytes.concat(
                keccak256(
                    abi.encode(
                        RH_LEAF,
                        block.chainid,
                        predecessor,
                        p.laneKind,
                        p.laneKey,
                        p.sequence,
                        p.recordHash,
                        p.recordChainHash
                    )
                )
            )
        );
    }

    function _ehProof(address predecessor, HT.Leaf[] memory leaves, uint256 index)
        private
        view
        returns (bytes32 root, bytes32[] memory proof)
    {
        bytes32[] memory layer = new bytes32[](leaves.length);
        proof = new bytes32[](64);
        uint256 used;
        uint256 n = leaves.length;
        for (uint256 i; i < n; ++i) {
            layer[i] = _ehLeaf(predecessor, leaves[i]);
        }
        while (n > 1) {
            if ((index ^ 1) < n) proof[used++] = layer[index ^ 1];
            uint256 nextN = (n + 1) / 2;
            for (uint256 i; i < nextN; ++i) {
                uint256 j = i * 2;
                if (j + 1 == n) {
                    layer[i] = layer[j];
                } else {
                    bytes32 a = layer[j];
                    bytes32 b = layer[j + 1];
                    layer[i] = a < b ? keccak256(abi.encode(a, b)) : keccak256(abi.encode(b, a));
                }
            }
            index /= 2;
            n = nextN;
        }
        root = layer[0];
        assembly ("memory-safe") { mstore(proof, used) }
    }
}
