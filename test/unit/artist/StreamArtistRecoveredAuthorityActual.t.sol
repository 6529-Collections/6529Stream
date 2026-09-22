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
contract StreamArtistRecoveredAuthorityActualTest is StreamArtistGuardianSupersessionActualTest {
    bytes32 private constant RH_LEAF =
        0xea04da6644046a7c731e99312c32df311e81aa7e137dfc2a49c2116bb325195d;
    bytes32 private constant RH_POINTER = keccak256("ARTIST_REGISTRY");

    struct Successor {
        StreamArtistOnboardingRegistry registry;
        StreamArtistArchiveV2 archive;
        StreamArtistOnboardingCoordinator coordinator;
        address identity;
    }
    AH.Origin[][7] private rhCandidates;
    bytes32 private rhGuardian;
    bytes32 internal rhRecovery;
    bytes32 private rhOriginalAction;

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

    function _rhCompromise(bytes32 subject) private {
        ArtistUnitRoles(suite.roleRegistry).setArbiter(address(artist), true);
        bytes32 evidence = keccak256("fresh C original compromise evidence");
        bytes32 reason = keccak256("fresh C original compromise reason");
        ArtistUnitGovernance authority = ArtistUnitGovernance(manager.governanceAuthority());
        authority.configureContestReads(
            suite.roleRegistry, address(artist), reason, "urn:recovered:C33"
        );
        (bytes32 scope, bytes32 old_, bytes32 next_) =
            ingress.identityContestGovernanceContext(artistId, subject, evidence, reason);
        _rhActive(keccak256("unit authority gas raise"), 1, scope, old_, next_);
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
        _rhInactive();
        Dismissal.Cause memory cause = ingress.currentIdentityContestCause(artistId);
        require(
            cause.facts.kind == 1 && cause.facts.executedTransitionHash == subject
                && cause.facts.incumbent == address(artist)
                && cause.facts.enteredAt == block.timestamp,
            "actual C33 captures current C32"
        );
        require(
            ingress.identityContestRecord(cause.facts.referenceHash).terms.subjectRecordHash
                == subject,
            "original Contest body retained"
        );
    }

    function _rhRecoverV2(bytes32 executed, bytes32 retained) private {
        _newRotationSafe(871002);
        Dismissal.Cause memory cause = ingress.currentIdentityContestCause(artistId);
        Recovery.Request memory p = Recovery.Request(
            artistId,
            address(rotationSafe),
            1,
            cause.causeHash,
            ingress.latestIdentityContestDismissal(artistId),
            keccak256("independent C resolution evidence"),
            cause.facts.reasonHash,
            new bytes32[](0)
        );
        EV2.ResolutionManifest memory manifest = EV2.ResolutionManifest(
            artistId,
            _ownerSnapshot().revision,
            cause.causeHash,
            p.expectedResolutionHash,
            executed,
            EV2.VestingBasis.DECLARED_VESTINGS,
            EV2.requestCommitment(p),
            p.evidenceHash,
            new EV2.VestingReference[](1),
            new bytes32[](0)
        );
        manifest.contestedVestings[0] =
            EV2.VestingReference(executed, _snapshot(executed).commitment);
        (address publisherAddress, bytes32 publisherPin) =
            IStreamArtistRecoveryEvidenceBinding(suite.owners[2]).recoveryEvidenceBinding();
        require(
            publisherAddress.codehash == publisherPin && publisherPin != 0,
            "actual current C publisher"
        );
        bytes32 manifestHash =
            IStreamArtistRecoveryEvidence(publisherAddress).publishResolutionManifest(manifest);
        require(
            manifestHash
                == EV2.manifestHash(
                    block.chainid,
                    address(ingress),
                    suite.owners[2],
                    suite.owners[2].codehash,
                    address(coordinator),
                    suite.archive,
                    suite.core,
                    suite.mintManager,
                    manifest
                ),
            "published C manifest binds real current cause and original C32 snapshot"
        );
        (address workerAddress, bytes32 workerPin) = IStreamArtistRecoverySelectionBinding(
                suite.owners[2]
            ).recoverySelectionPreparationBinding();
        require(
            workerAddress.codehash == workerPin && workerPin != 0, "fixed current C election worker"
        );
        IStreamArtistRecoverySelectionPreparation worker =
            IStreamArtistRecoverySelectionPreparation(workerAddress);
        bytes32 key = worker.beginSelectionV2(manifestHash);
        (SV2.Basis memory basis, Selection.Progress memory progress) = worker.selectionV2(key);
        require(
            basis.history.count == 2 && !progress.complete,
            "complete A and B guardian prefix selected in C"
        );
        for (uint64 i; i < basis.history.count; ++i) {
            progress = worker.continueSelectionV2(key, 1);
        }
        Selection.Result memory election = worker.requireSelectionV2(manifestHash);
        require(
            progress.complete && election.selectedRecordHash == retained
                && election.commitment != 0,
            "actual mature B guardian elected through imported history"
        );
        T.Authorization memory acceptance = _acceptance(p);
        IStreamArtistIdentityRecoveryV2 api = IStreamArtistIdentityRecoveryV2(address(ingress));
        Recovery.Context memory context = api.identityRecoveryContextV2(p, acceptance, manifestHash);
        currentId = keccak256("current C V2 recovery action");
        GovernanceCall[] memory calls = new GovernanceCall[](1);
        calls[0] = GovernanceCall(
            address(ingress),
            0,
            IStreamArtistIdentityRecoveryV2.recoverArtistIdentityV2.selector,
            keccak256(
                abi.encodeCall(
                    IStreamArtistIdentityRecoveryV2.recoverArtistIdentityV2,
                    (p, acceptance, manifestHash)
                )
            ),
            context.scopeHash,
            context.oldValueHash,
            context.newValueHash
        );
        scheduled.status = GovernanceActionStatus.SCHEDULED;
        scheduled.actionClass = 2;
        scheduled.target = address(ingress);
        scheduled.selector = calls[0].selector;
        scheduled.callHash = keccak256(
            abi.encode(
                bytes32(0x10f09566fb70f7947b61639c2a53b3aec872069a8b46edd08ba14eb2b5942b70), calls
            )
        );
        scheduled.notBefore = uint64(block.timestamp + 72 hours);
        scheduled.expiresAfter = scheduled.notBefore + 1 days;
        scheduled.proposer = address(artist);
        scheduled.executor = address(0);
        scheduled.canceller = address(0);
        scheduled.vetoer = address(0);
        scheduled.reasonHash = p.reasonHash;
        scheduled.reasonURI = "urn:recovered:C-V2";
        scheduled.manifestHash = keccak256("sealed current fixture manifest");
        ArtistUnitGovernance authority = ArtistUnitGovernance(manager.governanceAuthority());
        authority.configureContestReads(
            suite.roleRegistry, address(artist), p.reasonHash, scheduled.reasonURI
        );
        _publish();
        bytes32 association =
            api.registerIdentityRecoveryActionV2(currentId, calls, p, acceptance, manifestHash);
        require(
            association != 0
                && api.identityRecoveryEvidenceState(artistId, currentId).manifestHash
                    == manifestHash,
            "real C V2 preparation retains new evidence"
        );
        vm.warp(scheduled.notBefore);
        scheduled.status = GovernanceActionStatus.EXECUTED;
        _publish();
        uint256 receiptCount = Native(suite.owners[2]).artistNativeReceiptCount();
        uint64 revision = _ownerSnapshot().revision;
        bytes32 causeKey = _rhSourceKey(
            2,
            AH.Origin(
                keccak256("identity_authority.replay.contest_resolution"),
                keccak256(abi.encode(artistId, cause.causeHash))
            )
        );
        require(
            Owner(suite.owners[2]).replayCell(causeKey).status == 0,
            "new current cause initially unused"
        );
        _rhActive(currentId, 2, context.scopeHash, context.oldValueHash, context.newValueHash);
        authority.executeModuleContext(
            address(ingress),
            abi.encodeCall(
                IStreamArtistIdentityRecoveryV2.recoverArtistIdentityV2,
                (p, acceptance, manifestHash)
            ),
            2,
            context.scopeHash,
            context.oldValueHash,
            context.newValueHash
        );
        _rhInactive();
        bytes32 record = ingress.latestIdentityRecovery(artistId);
        require(
            record != rhRecovery
                && ingress.identityRecoveryRecord(record).fields.newAddress == address(rotationSafe)
                && _snapshot(record).previousTransitionRecordHash == executed
                && _ownerSnapshot().revision == revision + 1,
            "actual C V2 produces original35 and extends C32"
        );
        require(
            Native(suite.owners[2]).artistNativeReceiptCount() == receiptCount + 2
                && Native(suite.owners[2]).artistNativeReceiptAt(receiptCount).recordHash == record
                && Native(suite.owners[2]).artistNativeReceiptAt(receiptCount + 1).operation == 35,
            "new adjacent original35 pair only"
        );
        require(
            Owner(suite.owners[2]).replayCell(causeKey).commitment == record
                && Owner(suite.owners[2]).replayCell(causeKey).status == 2,
            "actual new cause consumed once"
        );
        (bool accepted,) =
            ingress.rotationAcceptanceNonceState(artistId, p.newAddress, acceptance.nonce);
        require(
            accepted
                && api.identityRecoveryEvidenceState(artistId, currentId).associationHash
                    == association,
            "actual Safe acceptance and V2 association retained"
        );
    }

    function _rhActive(bytes32 action, uint8 class_, bytes32 scope, bytes32 old_, bytes32 next_)
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

    function _rhInactive() private {
        _inactive();
        (bool active, bytes32 id, uint8 c, bytes32 s, bytes32 o, bytes32 n) =
            IStreamGovernanceReads(manager.governanceAuthority()).currentAction();
        require(
            !active && id == 0 && c == 0 && s == 0 && o == 0 && n == 0,
            "all-zero inactive context restored"
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

    function rhExecuteNewSafe(address target, bytes calldata data) external returns (bool) {
        require(msg.sender == address(this), "fixture caller");
        return executeSafe(rotationSafe, rotationKeys, target, 0, data, 0);
    }

    function _rhCandidate(uint8 owner, string memory surface, bytes32 scope) internal {
        rhCandidates[owner].push(AH.Origin(keccak256(bytes(surface)), scope));
    }

    function _rhAuthorization(bytes32 digest, uint256 nonce) internal {
        _rhCandidate(
            2,
            "identity_authority.replay.authorization_consumed_digest",
            keccak256(abi.encode(artistId, digest))
        );
        _rhCandidate(
            2, "identity_authority.replay.nonce_allocator", keccak256(abi.encode(artistId, nonce))
        );
    }

    /// @dev Scoped test extension for later real governance contexts; original default unchanged.
    function _rhExecuteRecovery(Recovery.Request memory p, T.Authorization memory a)
        internal virtual returns (bytes32)
    {
        return this.executeRegistered(p, a);
    }

    function _rhBaseline() internal {
        _rhCandidate(
            0, "binding_lifecycle.replay.proposal_key", keccak256(abi.encode(uint256(1), uint64(1)))
        );
        _rhCandidate(
            2,
            "identity_authority.replay.nonce_allocator",
            keccak256(abi.encode(bytes32(0), uint256(0)))
        );
        T.Authorization memory accepted = _authorization(false);
        bytes32 digest = ingress.acceptanceDigest(1, accepted);
        _rhAuthorization(digest, accepted.nonce);
        accepted.signature = _signature(digest);
        _artistCall(abi.encodeCall(IStreamArtistOnboarding.acceptArtistBinding, (1, accepted)));
        _rhCandidate(
            3,
            "acceptance_lifecycle.replay.record_uniqueness",
            keccak256(abi.encode(uint256(1), uint64(1), uint8(1), address(artist)))
        );
        rhGuardian = _guarded();
        R.GuardianRecord memory guardian = ingress.guardianSetRecord(rhGuardian);
        _rhAuthorization(
            ingress.guardianSetDigest(
                guardian.terms, T.Authorization(guardian.nonce, guardian.signedAt, "")
            ),
            guardian.nonce
        );
        _rhCandidate(
            2,
            "identity_authority.replay.guardian_set_chain",
            keccak256(abi.encode(artistId, guardian.nonce))
        );
        bytes32 contest = ingress.currentIdentityContestCause(artistId).facts.referenceHash;
        _rhCandidate(
            2,
            "identity_authority.replay.contest_record_hash_and_subject_key",
            keccak256(
                abi.encode(
                    keccak256("subject"),
                    artistId,
                    bytes32(0),
                    keccak256("compromise evidence"),
                    keccak256("compromise reason")
                )
            )
        );
        _rhCandidate(
            2,
            "identity_authority.replay.contest_record_hash_and_subject_key",
            keccak256(abi.encode(keccak256("record"), contest))
        );
        Recovery.Request memory p = _terms();
        T.Authorization memory a = _acceptance(p);
        GovernanceCall[] memory calls = _schedule(keccak256("recovered actual source action"), p, a);
        rhOriginalAction = currentId;
        ingress.registerIdentityRecoveryAction(currentId, calls, p, a);
        _rhCandidate(2, "identity_authority.replay.recovery_preparation", currentId);
        vm.warp(scheduled.notBefore);
        scheduled.status = GovernanceActionStatus.EXECUTED;
        _publish();
        Recovery.Context memory c = ingress.identityRecoveryContext(p, a);
        rhRecovery = _rhExecuteRecovery(p, a);
        Recovery.Record memory recovery = ingress.identityRecoveryRecord(rhRecovery);
        require(
            recovery.fields.vestedAuthorityClass == 1
                && recovery.fields.newAddress == address(rotationSafe),
            "actual original class1 recovery"
        );
        _rhCandidate(
            2,
            "identity_authority.replay.authorization_consumed_digest",
            keccak256(abi.encode(artistId, recovery.acceptanceDigest))
        );
        _rhCandidate(
            2,
            "identity_authority.replay.nonce_allocator",
            keccak256(
                abi.encode(
                    keccak256("rotation_acceptance"), artistId, address(rotationSafe), a.nonce
                )
            )
        );
        _rhCandidate(
            2,
            "identity_authority.replay.contest_resolution",
            keccak256(abi.encode(artistId, c.causeHash))
        );
        _rhCandidate(
            2,
            "identity_authority.replay.recovery_action",
            keccak256(abi.encode(currentId, c.scopeHash, c.oldValueHash, c.newValueHash))
        );
        _rhCandidate(
            2,
            "identity_authority.replay.standing_retirement",
            keccak256(abi.encode(artistId, c.incumbent, rhRecovery))
        );
        _rhCandidate(2, "identity_authority.replay.one_way_cutover_latch", 0);
        uint256 count = Native(suite.owners[2]).artistNativeReceiptCount();
        require(
            count >= 2
                && Native(suite.owners[2]).artistNativeReceiptAt(count - 2).recordHash
                    == rhRecovery,
            "actual primary35 occurrence"
        );
        require(
            Native(suite.owners[2]).artistNativeReceiptAt(count - 1).operation == 35
                && NativeClock(suite.owners[2]).artistNativeReceiptRevisionAt(count - 2)
                    == NativeClock(suite.owners[2]).artistNativeReceiptRevisionAt(count - 1),
            "same original revision paired35"
        );
    }

    function _rhRequest() internal view returns (RH.Request memory p) {
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
                for (uint256 k; k < rhCandidates[owner].length; ++k) {
                    if (_rhSourceKey(owner, rhCandidates[owner][k]) != key) continue;
                    p.records.authority.replayOrigins[owner][j] = rhCandidates[owner][k];
                    found = true;
                    break;
                }
                require(found, "exact writer preimage for every real source key");
            }
        }
    }

    function _rhSourceKey(uint8 owner, AH.Origin memory logical) private view returns (bytes32) {
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

    function _rhImported(Successor memory next, Commit.Prepared memory prepared, bytes32 value)
        internal
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
            _rhGuardCells(
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
            keccak256(abi.encode(next.registry.guardianSetRecord(rhGuardian)))
                == keccak256(abi.encode(ingress.guardianSetRecord(rhGuardian))),
            "exact original guardian body"
        );
        require(
            keccak256(abi.encode(next.registry.identityRecoveryRecord(rhRecovery)))
                == keccak256(abi.encode(ingress.identityRecoveryRecord(rhRecovery))),
            "exact original35 body"
        );
        require(
            _rhRecoveryFacts(next.identity) == _rhRecoveryFacts(suite.owners[2]),
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

    function _rhGuardCells(
        address owner,
        uint8 index,
        AH.OwnerData memory data,
        RH.OwnerProvenance memory prefix,
        T.SuiteConfiguration memory destination,
        address destinationCoordinator
    ) internal view {
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

    function _rhRecoveryFacts(address owner) internal view returns (bytes32) {
        (bytes32 primary, bytes32 occurrence, bytes32 secondary) =
            IStreamArtistIdentityRecoveryOwner(owner).identityRecoveryReceipts(rhRecovery);
        // The fourth return is today's lifetime guardian count, which a fresh28 must increase.
        // Only the original immutable action association/veto/execution belong in this digest.
        (
            RecoveryAction.Association memory action,
            RecoveryAction.Veto memory veto,
            bytes32 execution,
        ) = IStreamArtistRecoveryActionOwner(owner)
            .identityRecoveryActionState(artistId, rhOriginalAction);
        return keccak256(
            abi.encode(
                IStreamArtistRotationReads(owner).artistTransitionState(rhRecovery),
                IStreamArtistGuardianVestingHistory(owner)
                    .guardianVestingSnapshot(artistId, rhRecovery),
                primary,
                occurrence,
                secondary,
                action,
                veto,
                execution
            )
        );
    }

    function _rhFreshGuardian(Successor memory next) private returns (bytes32 record) {
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
            this.rhExecuteNewSafe(
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
        _rhAuthorization(digest, a.nonce);
        _rhCandidate(
            2,
            "identity_authority.replay.guardian_set_chain",
            keccak256(abi.encode(artistId, a.nonce))
        );
        require(
            row.operation == 28 && row.artistId == artistId && row.recordHash != rhGuardian,
            "new original guardian receipt"
        );
        R.GuardianRecord memory guardian = next.registry.guardianSetRecord(row.recordHash);
        require(
            guardian.signer == address(rotationSafe)
                && guardian.provisional.transitionRecordHash == rhRecovery,
            "new record keeps original source35 association"
        );
        require(
            NativeClock(next.identity).artistNativeReceiptRevisionAt(0)
                == Owner(next.identity).ownerStateSnapshotV2().revision,
            "actual local mutation counter without a revision jump"
        );
        require(
            _rhRecoveryFacts(next.identity) == _rhRecoveryFacts(suite.owners[2]),
            "fresh28 preserves original35 and registered action"
        );
    }

    function _rhSourceHash() private view returns (bytes32 hash) {
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
                _rhRecoveryFacts(suite.owners[2]),
                ingress.identityRecoveryRecord(rhRecovery),
                ingress.guardianSetRecord(rhGuardian)
            )
        );
    }

    function _rhDestinationHash(Successor memory next) internal view returns (bytes32 hash) {
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

    // Original operation55/56 root/leaf recipes below are copied from AuthorityHydrationTest.
    // They admit actual predecessor lanes; no imported authority is installed by these steps.
    function _rhCutover() internal returns (Successor memory next) {
        next = _rhNext();
        HT.Leaf[] memory rows = _rhLeaves(History(address(ingress)));
        (bytes32 root,) = _rhProof(address(ingress), rows, 0);
        bytes32 manifest = keccak256("recovered actual source manifest");
        HT.Context memory c = History(address(next.registry))
            .artistHistoryImportContext(address(ingress), uint64(block.number), root, manifest);
        _rhCandidate(
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
        _rhCandidate(
            2,
            "identity_authority.replay.import_binding_key",
            keccak256(
                abi.encode(HT.Binding(address(ingress), uint64(block.number), root, manifest))
            )
        );
        _rhCandidate(
            2,
            "identity_authority.replay.verified_lane_key",
            keccak256(abi.encode(uint8(1), artistId))
        );
        _rhCandidate(
            2,
            "identity_authority.replay.import_binding",
            keccak256(abi.encode(uint256(0), uint8(1), artistId))
        );
        _rhCandidate(
            2,
            "identity_authority.replay.verified_lane_key",
            keccak256(abi.encode(uint8(2), bytes32(uint256(1))))
        );
        _rhCandidate(
            2,
            "identity_authority.replay.import_binding",
            keccak256(abi.encode(uint256(0), uint8(2), bytes32(uint256(1))))
        );
        _rhCommitHistory(next, c, root, manifest);
        core.set(RH_POINTER, address(next.registry), false);
        History(address(ingress)).observeRegistryCutover();
        (, uint64 count) = History(address(ingress)).artistHistoryLane(1, artistId);
        (, bytes32[] memory proof) = _rhProof(address(ingress), rows, count - 1);
        History(address(next.registry)).verifyImportedLaneTip(0, rows[count - 1], proof);
        (, proof) = _rhProof(address(ingress), rows, rows.length - 1);
        History(address(next.registry)).verifyImportedLaneTip(0, rows[rows.length - 1], proof);
    }

    /// @dev The default preserves the historical mock recipe; successors can use scoped actions.
    function _rhCommitHistory(Successor memory next, HT.Context memory c, bytes32 root, bytes32 manifest)
        internal virtual
    {
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
    }

    function _rhTwoImports() private returns (Successor memory last, bytes32 fresh) {
        _rhBaseline();
        address originalIdentity = suite.owners[2];
        Successor memory middle = _rhCutover();
        RH.Request memory request = _rhRequest();
        Commit.Prepared memory first =
            Prepared.prepare(middle.coordinator.suiteConfiguration(), request);
        request.expectedSemanticInventory = Prepared.inventory(first);
        bytes32 firstValue =
            Recovered(address(middle.registry)).hydrateRecoveredArtistAuthority(request);
        _rhImported(middle, first, firstValue);
        fresh = _rhFreshGuardian(middle);
        bytes32 originalFacts = _rhRecoveryFacts(originalIdentity);
        _rhAdopt(middle);
        last = _rhCutover();
        request = _rhRequest();
        require(
            request.expectedSourceImportCommitment == firstValue,
            "second import names real original60 certificate"
        );
        Commit.Prepared memory second =
            Prepared.prepare(last.coordinator.suiteConfiguration(), request);
        require(
            second.admission.provenance.eras.length == 2
                && second.admission.provenance.origins.length == 2,
            "flat A prefix followed by B current era"
        );
        RH.JournalEntry[] memory journal = second.admission.provenance.journals[2];
        require(
            journal.length == first.admission.provenance.journals[2].length + 1,
            "A original occurrences plus exactly B fresh28"
        );
        for (uint256 i; i + 1 < journal.length; ++i) {
            require(
                keccak256(abi.encode(journal[i]))
                    == keccak256(abi.encode(first.admission.provenance.journals[2][i])),
                "every A position remains exact including secondary35"
            );
        }
        require(
            journal[journal.length - 1].receipt.recordHash == fresh
                && journal[journal.length - 1].position.point.environmentHash
                    == second.admission.provenance.eras[1].originHash
                && journal[journal.length - 1].position.nativeIndex == 0,
            "B original native occurrence keeps local index and era"
        );
        require(
            second.admission.provenance.eras[1].lowerRevisions[2] == 4
                && second.admission.provenance.eras[1].priorImportCommitment == firstValue,
            "B actual55/56 then60 boundary preserved"
        );
        request.expectedSemanticInventory = Prepared.inventory(second);
        bytes32 middleBefore = _rhSourceHash();
        bytes32 value = Recovered(address(last.registry)).hydrateRecoveredArtistAuthority(request);
        _rhImported(last, second, value);
        require(
            _rhRecoveryFacts(last.identity) == originalFacts && _rhSourceHash() == middleBefore,
            "C preserves A original35 and sealed B state"
        );
        require(
            keccak256(abi.encode(last.registry.guardianSetRecord(fresh)))
                == keccak256(abi.encode(ingress.guardianSetRecord(fresh))),
            "C retains exact B guardian body and source35 association"
        );
        // The original A source stays sealed; only direct immutable facts are inspected again.
        require(
            _rhRecoveryFacts(originalIdentity) == originalFacts, "original A action and35 unchanged"
        );
    }

    function _rhAdopt(Successor memory next) internal {
        ingress = next.registry;
        coordinator = next.coordinator;
        archive = next.archive;
        suite = next.coordinator.suiteConfiguration();
        artist = rotationSafe;
        keys = rotationKeys;
        nextNonce = IStreamArtistIdentityOwner(next.identity).identity(artistId).nonceHint;
    }

    function _rhNext() private returns (Successor memory next) {
        T.SuiteConfiguration memory s = suite;
        address governance = manager.governanceAuthority();
        ArtistSanctionFinalityFixture finalityFixture = ArtistSanctionFinalityFixture(_artistArtifactCreate(
            "test/unit/artist/ArtistSanctionFinalityFixture.sol:ArtistSanctionFinalityFixture",
            abi.encode()
        ));
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

    function _rhLeaves(History h) private view returns (HT.Leaf[] memory rows) {
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

    function _rhLeaf(address predecessor, HT.Leaf memory p) private view returns (bytes32) {
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

    function _rhProof(address predecessor, HT.Leaf[] memory leaves, uint256 index)
        private
        view
        returns (bytes32 root, bytes32[] memory proof)
    {
        bytes32[] memory layer = new bytes32[](leaves.length);
        proof = new bytes32[](64);
        uint256 used;
        uint256 n = leaves.length;
        for (uint256 i; i < n; ++i) {
            layer[i] = _rhLeaf(predecessor, leaves[i]);
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
