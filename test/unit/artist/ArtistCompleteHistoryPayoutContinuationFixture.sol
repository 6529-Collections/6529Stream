// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./ArtistCompleteHistoryClassThreeFixture.sol";
import {
    StreamArtistRecoveryRewindTypes as CHW
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveryRewindTypes.sol";
import {
    IStreamArtistIdentityRecoveryV3 as CHWRecovery,
    IStreamArtistIdentityRecoveryOwnerV3 as CHWIdentity
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistIdentityRecoveryV3.sol";
import {
    IStreamArtistRecoveryRewindEvidence as CHWPublisher
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistRecoveryRewindEvidence.sol";
import {
    IStreamArtistRecoveryRewindSelection as CHWSelector
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistRecoveryRewindSelection.sol";
import {
    IStreamArtistRecoveryPayoutOwnerV3 as CHWPayout
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistRecoveryPayoutOwnerV3.sol";
import {
    IStreamArtistRecoveredPayoutHydration as CHWApplied
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistRecoveredPayoutHydration.sol";
import {
    StreamArtistRecoveredRuntimeReads as CHWRuntime
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredRuntimeReads.sol";
import {
    StreamArtistHashes as CHWHashes
} from "../../../smart-contracts/domains/artist/StreamArtistHashes.sol";
import {
    StreamArtistGuardianAppealTypes as CHWAppeal
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistGuardianAppealTypes.sol";

/// @notice Genuine V3/35 payout rewind and original18 continuation in the mixed CT fixture.
/// @dev Inherited Core/documentary/Finality and scheduled governance are typed unit boundaries.
/// No Identity/Payout owner, journal, Archive, replay cell, or continuation response is mocked.
/// The enclosing test performs the original Safe seven-owner imports before/after consumption.
abstract contract ArtistCompleteHistoryPayoutContinuationFixture is
    ArtistCompleteHistoryClassThreeFixture
{
    bytes32 internal chRewindStable;
    bytes32 internal chRewindExcluded;
    bytes32 internal chRewindRecovery;
    bytes32 internal chRewindAction;
    bytes32 internal chRewindManifest;
    bytes32 internal chRewindPlan;
    bytes32 internal chRewindContinuation;
    bytes32 internal chRewindConsumer;
    RH.Point internal chRewindCreationPoint;
    RH.Point internal chRewindConsumptionPoint;
    CHW.PayoutOriginalV3[] private chRewindOriginals;
    uint256[] private chRewindLogicalIndexes;

    struct CHRewindPlan {
        Recovery.Request request;
        T.Authorization acceptance;
        CHW.ResolutionManifestV3 manifest;
        bytes32 manifestHash;
        CHW.ResultV3 selected;
    }

    function _chRewindPayoutPair() internal {
        require(
            chRewindStable == 0 && chClassThreeActivation != 0
                && ingress.currentAuthorityCapabilities(artistId).authorityClass == 3
                && ingress.currentAuthorityCapabilities(artistId).authorityAddress
                    == address(artist),
            "actual current Class3 payout authority"
        );
        uint256 identityCount = Native(suite.owners[2]).artistNativeReceiptCount();
        uint256 payoutCount = Native(suite.owners[5]).artistNativeReceiptCount();
        // A live transition permits one provisional child. Keep the genuine earlier stable
        // designation and create that child before the original40 post-window ends.
        (, chRewindStable) = ingress.artistPayoutAccount(artistId);
        require(
            chRewindStable != 0
                && block.timestamp
                    < ingress.artistTransitionState(chClassThreeActivation).postWindowEndsAt,
            "actual retained stable payout and live Class3 window"
        );
        chRewindExcluded = _chPayout(address(0xC302));
        require(
            Native(suite.owners[2]).artistNativeReceiptCount() == identityCount
                && Native(suite.owners[5]).artistNativeReceiptCount() == payoutCount + 1
                && CHFPayout(suite.owners[5])
                .designationRecord(chRewindExcluded)
                .previousDesignationRecordHash == chRewindStable,
            "genuine Class3 child of the retained original18 without synthetic Identity entries"
        );
    }

    /// @dev Call after the separate fixture's original33, with no intervening owner mutation.
    function _chRewindPayoutRecover() internal returns (bytes32 record) {
        Dismissal.Cause memory cause = ingress.currentIdentityContestCause(artistId);
        require(
            chRewindExcluded != 0 && chRewindRecovery == 0 && cause.facts.kind == 1
                && cause.facts.authorityClass == 3
                && cause.facts.executedTransitionHash == chClassThreeActivation
                && cause.facts.incumbent == address(artist),
            "actual Class3 compromise before the V3 election"
        );
        _chRewindPublishPayouts();
        _newRotationSafe(882099);
        CHRewindPlan memory p;
        bytes32[] memory excluded = new bytes32[](1);
        excluded[0] = chRewindExcluded;
        p.request = Recovery.Request(
            artistId,
            address(rotationSafe),
            3,
            cause.causeHash,
            ingress.latestIdentityContestDismissal(artistId),
            keccak256(abi.encode("complete payout V3 evidence", chRewindExcluded)),
            cause.facts.reasonHash,
            excluded
        );
        CHW.RecordReference[] memory references = new CHW.RecordReference[](1);
        references[0] = CHW.RecordReference(CHW.RecordKind.PAYOUT_DESIGNATION, chRewindExcluded);
        p.manifest = CHW.ResolutionManifestV3(
            artistId,
            _chRewindPrefix(2),
            _chRewindPrefix(5),
            cause.causeHash,
            p.request.expectedResolutionHash,
            ingress.lastArtistTransition(artistId),
            EV2.VestingBasis.NO_CONTESTED_VESTING,
            CHWAppeal.requestCommitment(p.request),
            p.request.evidenceHash,
            new EV2.VestingReference[](0),
            references
        );
        bytes32 originals = _chRewindOriginalsHash(suite);
        p.manifestHash = _chRewindPublisher(suite.owners[2]).publishResolutionManifestV3(p.manifest);
        require(
            p.manifestHash == CHW.manifestHash(_chRewindEnvironment(suite), p.manifest),
            "original fixed-suite manifest preimage"
        );
        p.acceptance = _acceptance(p.request);
        _chRewindSelect(p);
        require(
            p.selected.payout.operative.recordHash == chRewindStable
                && p.selected.payout.retainedCandidateRecordHash == 0,
            "full election restores the retained predecessor with an empty candidate"
        );
        Recovery.Context memory context = _chRewindRegister(p);
        uint256 identityCount = Native(suite.owners[2]).artistNativeReceiptCount();
        uint256 payoutCount = Native(suite.owners[5]).artistNativeReceiptCount();
        vm.warp(scheduled.notBefore);
        scheduled.status = GovernanceActionStatus.EXECUTED;
        _publish();
        ArtistUnitGovernance(manager.governanceAuthority())
            .executeModuleContextWithAction(
                chRewindAction,
                address(ingress),
                abi.encodeCall(
                    CHWRecovery.recoverArtistIdentityV3, (p.request, p.acceptance, p.manifestHash)
                ),
                2,
                context.scopeHash,
                context.oldValueHash,
                context.newValueHash
            );
        record = ingress.latestIdentityRecovery(artistId);
        chRewindRecovery = record;
        chRewindManifest = p.manifestHash;
        chRewindPlan = p.selected.commitment;
        Recovery.Record memory saved = ingress.identityRecoveryRecord(record);
        require(
            record != 0 && saved.fields.vestedAuthorityClass == 3
                && saved.fields.newAddress == address(rotationSafe)
                && saved.delegationEpoch == context.delegationEpoch + 1
                && _snapshot(record).previousTransitionRecordHash == chClassThreeActivation
                && Native(suite.owners[2]).artistNativeReceiptCount() == identityCount + 2
                && Native(suite.owners[5]).artistNativeReceiptCount() == payoutCount
                && _chRewindOriginalsHash(suite) == originals,
            "original paired35 and auxiliary Payout apply preserve every earlier original"
        );
        for (uint256 i; i < 2; ++i) {
            HT.Receipt memory row = Native(suite.owners[2]).artistNativeReceiptAt(identityCount + i);
            require(
                row.operation == 35
                    && row.recordHash == (i == 0 ? record : saved.fields.supersededRecordsHash)
                    && row.artistId == artistId,
                "original35 primary recovery then secondary supersession occurrence"
            );
        }
        _chRewindRemember(p, context, saved);
        CHW.PayoutInventoryV3 memory inventory =
            CHWPayout(suite.owners[5]).payoutRewindInventoryV3(artistId);
        chRewindContinuation = inventory.continuationCommitment;
        CHW.PayoutContinuationV3 memory continuation =
            CHWPayout(suite.owners[5]).payoutRecoveryContinuationV3(chRewindContinuation);
        require(
            chRewindContinuation != 0 && continuation.recoveryRecordHash == record
                && continuation.stable.recordHash == chRewindStable
                && continuation.releasedChildRecordHash == chRewindExcluded
                && continuation.candidate.recordHash == 0
                && CHW.payoutContinuationHash(_chRewindEnvironment(suite), continuation)
                    == chRewindContinuation
                && CHWApplied(suite.owners[5]).payoutRecoveryAppliedCommitmentV3(record) != 0,
            "actual35 installs the authentic unspent Payout continuation"
        );
        chRewindCreationPoint = RecoveredOwner(suite.owners[5])
            .recoveredHydrationAuxiliaryPoint(
                keccak256("payout_lifecycle.hydration.continuation_v3"), chRewindContinuation
            );
        require(
            chRewindCreationPoint.ownerRevision == continuation.payoutOwnerRevision,
            "original Payout auxiliary mutation point"
        );
        _adoptRotatedSafe();
        vm.warp(ingress.artistTransitionState(record).postWindowEndsAt);
        _chAssertPayoutContinuation(suite);
    }

    /// @notice Invoke after a genuine CT import/adoption to consume the retained branch there.
    function _chConsumePayoutContinuation(address account) internal returns (bytes32 record) {
        require(chRewindContinuation != 0 && chRewindConsumer == 0, "one continuation use");
        uint256 beforeIdentity = Native(suite.owners[2]).artistNativeReceiptCount();
        uint256 beforePayout = Native(suite.owners[5]).artistNativeReceiptCount();
        record = _chPayout(account);
        chRewindConsumer = record;
        bytes32 scope = keccak256(abi.encode(artistId, chRewindContinuation, chRewindStable));
        _rhCandidate(5, "payout_lifecycle.replay.recovery_continuation", scope);
        bytes32 key =
            _chRewindKey(suite, keccak256("payout_lifecycle.replay.recovery_continuation"), scope);
        T.ReplayCell memory cell = Owner(suite.owners[5]).replayCell(key);
        chRewindConsumptionPoint =
            RecoveredOwner(suite.owners[5]).recoveredHydrationReplayPoint(key);
        require(
            CHFPayout(suite.owners[5]).designationRecord(record).previousDesignationRecordHash
                    == chRewindStable
                && CHWPayout(suite.owners[5]).payoutDesignationRecoveryContinuationV3(record)
                == chRewindContinuation && cell.commitment == record && cell.kind == 1
                && cell.status == 2
                && cell.touchedRevision
                    == NativeClock(suite.owners[5]).artistNativeReceiptRevisionAt(beforePayout)
                && chRewindConsumptionPoint.ownerRevision == cell.touchedRevision
                && Native(suite.owners[2]).artistNativeReceiptCount() == beforeIdentity
                && Native(suite.owners[5]).artistNativeReceiptCount() == beforePayout + 1,
            "fresh original18 consumes the imported continuation at its actual native point"
        );
        HT.Receipt memory row = Native(suite.owners[5]).artistNativeReceiptAt(beforePayout);
        require(
            row.operation == 18 && row.recordHash == record && row.artistId == artistId,
            "one actual successor payout occurrence"
        );
        _chAssertPayoutContinuation(suite);
    }

    function _chRewindSelect(CHRewindPlan memory p) private {
        CHWSelector selector = _chRewindSelector();
        bytes32 key = selector.beginSelectionV3(p.manifestHash);
        (CHW.BasisV3 memory basis, CHW.ProgressV3 memory progress) = selector.selectionV3(key);
        uint256 bound = p.manifest.identity.receiptCount + p.manifest.payout.receiptCount
            + basis.identity.guardianHistory.count + 2;
        for (uint256 i; i < bound && !progress.complete; ++i) {
            uint256 prior =
                progress.identityProcessed + progress.payoutProcessed + progress.guardiansProcessed;
            progress = selector.continueSelectionV3(key, 1);
            require(
                progress.complete
                    || progress.identityProcessed + progress.payoutProcessed
                            + progress.guardiansProcessed > prior,
                "bounded original V3 scan advances"
            );
        }
        p.selected = selector.requireSelectionV3(p.manifestHash);
        require(
            progress.complete && p.selected.commitment != 0 && p.selected.sourceKey == key
                && progress.identityProcessed == p.manifest.identity.receiptCount
                && progress.payoutProcessed == p.manifest.payout.receiptCount,
            "whole original global owner2 and owner5 journals scanned"
        );
    }

    function _chRewindRegister(CHRewindPlan memory p)
        private
        returns (Recovery.Context memory context)
    {
        address authority = manager.governanceAuthority();
        uint256[29] memory bootstrap;
        bootstrap[0] = 1;
        bootstrap[1] = 1;
        bootstrap[2] = uint256(uint160(suite.roleRegistry));
        bootstrap[3] = uint256(suite.roleRegistry.codehash);
        bootstrap[4] = uint256(uint160(authority));
        bootstrap[5] = uint256(authority.codehash);
        avm.mockCall(
            authority,
            abi.encodeCall(IStreamGovernanceReads.systemManifestBootstrapState, ()),
            abi.encode(bootstrap)
        );
        avm.mockCall(
            authority,
            abi.encodeCall(IStreamGovernanceReads.minimumDelay, (uint8(2))),
            abi.encode(uint256(72 hours))
        );
        CHWRecovery api = CHWRecovery(address(ingress));
        context = api.identityRecoveryContextV3(p.request, p.acceptance, p.manifestHash);
        chRewindAction =
            keccak256(abi.encode("complete original V3 payout recovery", p.manifestHash));
        currentId = chRewindAction;
        GovernanceCall[] memory calls = new GovernanceCall[](1);
        calls[0] = GovernanceCall(
            address(ingress),
            0,
            CHWRecovery.recoverArtistIdentityV3.selector,
            keccak256(
                abi.encodeCall(
                    CHWRecovery.recoverArtistIdentityV3, (p.request, p.acceptance, p.manifestHash)
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
        scheduled.reasonHash = p.request.reasonHash;
        scheduled.reasonURI = "urn:complete:original-rewind-v3";
        scheduled.manifestHash = keccak256("complete fixture scheduled manifest");
        ArtistUnitGovernance(authority)
            .configureContestReads(
                suite.roleRegistry, address(artist), p.request.reasonHash, scheduled.reasonURI
            );
        _publish();
        uint256 count = Native(suite.owners[2]).artistNativeReceiptCount();
        bytes32 association = api.registerIdentityRecoveryActionV3(
            chRewindAction, calls, p.request, p.acceptance, p.manifestHash
        );
        CHW.EvidenceStateV3 memory evidence =
            api.identityRecoveryEvidenceStateV3(artistId, chRewindAction);
        CHW.PreparationSealV3 memory seal =
            _chRewindSelector().preparationSealV3(p.selected.sourceKey);
        require(
            association != 0 && evidence.associationHash == association
                && evidence.manifestHash == p.manifestHash
                && evidence.selectionCommitment == p.selected.commitment
                && evidence.requiredRole == CHWAppeal.ARBITER && seal.associationHash == association
                && seal.commitment != 0
                && Native(suite.owners[2]).artistNativeReceiptCount() == count
                && keccak256(abi.encode(context))
                    == keccak256(
                        abi.encode(
                            api.identityRecoveryContextV3(p.request, p.acceptance, p.manifestHash)
                        )
                    ),
            "original registered V3 preparation is auxiliary and context remains exact"
        );
    }

    function _chRewindRemember(
        CHRewindPlan memory p,
        Recovery.Context memory c,
        Recovery.Record memory r
    ) private {
        _rhCandidate(2, "identity_authority.replay.recovery_preparation", chRewindAction);
        _rhCandidate(
            2,
            "identity_authority.replay.authorization_consumed_digest",
            keccak256(abi.encode(artistId, r.acceptanceDigest))
        );
        _rhCandidate(
            2,
            "identity_authority.replay.nonce_allocator",
            keccak256(
                abi.encode(
                    keccak256("rotation_acceptance"),
                    artistId,
                    p.request.newAddress,
                    p.acceptance.nonce
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
            keccak256(abi.encode(chRewindAction, c.scopeHash, c.oldValueHash, c.newValueHash))
        );
        _rhCandidate(
            2,
            "identity_authority.replay.standing_retirement",
            keccak256(abi.encode(artistId, c.incumbent, r.recordHash))
        );
        _rhCandidate(2, "identity_authority.replay.one_way_cutover_latch", 0);
        _rhCandidate(5, "payout_lifecycle.replay.recovery_rewind", r.recordHash);
        // Recovery acceptance lives in the original35 Archive envelope and signature payload
        // catalogue. Its writer does not create a signatureBundle[recovery] mapping entry.
    }

    /// @dev All logical payout rows remain in the manifest. Election witnesses are Artist-local.
    function _chRewindPublishPayouts() private {
        CHWRuntime.Context memory clock = CHWRuntime.load(_chRewindEnvironment(suite), 5);
        uint256 count = CHWRuntime.logicalCount(clock);
        for (uint256 i; i < count; ++i) {
            CHWRuntime.ReceiptFact memory f = CHWRuntime.receiptAt(clock, i);
            if (f.receipt.operation != 18 || f.receipt.artistId != artistId) continue;
            bytes32 record = f.receipt.recordHash;
            bytes32 id = keccak256(
                abi.encode(
                    keccak256("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"),
                    f.environment.chainId,
                    f.environment.registry,
                    f.environment.coordinator,
                    uint16(18),
                    address(this),
                    record
                )
            );
            bytes memory envelope =
                StreamArtistArchiveV2(f.environment.archive).artistEvidenceBytesV2(id, 1);
            (,,,,,,, bytes memory payload) = abi.decode(
                envelope,
                (uint16, bytes32, uint16, address, bytes32, T.Snapshot[7], T.Snapshot[7], bytes)
            );
            (
                T.PayoutDesignation memory terms,,
                T.SignerApproval memory proof,
                T.Authorization memory a,,,
            ) = abi.decode(
                payload,
                (
                    T.PayoutDesignation,
                    T.Authorization,
                    T.SignerApproval,
                    T.Authorization,
                    R.TransitionState,
                    R.TransitionState,
                    Dismissal.PayoutResolutionFacts
                )
            );
            CHWHashes.Environment memory original = CHWHashes.Environment(
                f.environment.chainId,
                f.environment.registry,
                f.environment.core,
                f.environment.manager
            );
            uint8 class_ = CHWHashes.payoutRecordForAuthority(
                    original, terms, proof.signer, 1, a.nonce, a.time
                ) == record
                ? 1
                : 3;
            require(
                CHWHashes.payoutRecordForAuthority(
                        original, terms, proof.signer, class_, a.nonce, a.time
                    ) == record && proof.digest == CHWHashes.payoutDigest(original, terms, a),
                "actual original18 Archive preimage"
            );
            if (record == chRewindExcluded) {
                require(
                    class_ == 3 && proof.signer == address(chClassThreeEstateSafe)
                        && terms.previousDesignationRecordHash == chRewindStable,
                    "excluded child retains the real Class3 signer and stable parent"
                );
            }
            CHW.PayoutOriginalV3 memory item =
                CHW.PayoutOriginalV3(record, terms, proof.signer, class_, a.nonce, a.time);
            CHWPublisher publisher = _chRewindPublisher(f.environment.owners[2]);
            bytes32 commitment = publisher.publishPayoutOriginalV3(item);
            (
                CHW.PayoutOriginalV3 memory saved,
                bytes32 hash,
                bytes32 identityPin,
                bytes32 payoutPin
            ) = publisher.payoutOriginalV3(record);
            require(
                commitment == hash && hash != 0 && identityPin == f.environment.owners[2].codehash
                    && payoutPin == f.environment.owners[5].codehash
                    && keccak256(abi.encode(saved)) == keccak256(abi.encode(item)),
                "immutable evidence stays with the actual original publisher"
            );
            chRewindOriginals.push(item);
            chRewindLogicalIndexes.push(i);
        }
        require(
            chRewindOriginals.length >= 3,
            "earlier rich-family payouts and the actual Class3 child included"
        );
    }

    function _chPayoutContinuationHash(T.SuiteConfiguration memory target)
        internal
        view
        returns (bytes32 h)
    {
        CHWPayout payout = CHWPayout(target.owners[5]);
        CHW.PayoutContinuationV3 memory continuation =
            payout.payoutRecoveryContinuationV3(chRewindContinuation);
        RH.Point memory creation;
        if (continuation.continuationHash != 0) {
            creation = RecoveredOwner(target.owners[5])
                .recoveredHydrationAuxiliaryPoint(
                    keccak256("payout_lifecycle.hydration.continuation_v3"), chRewindContinuation
                );
        }
        h = keccak256(
            abi.encode(
                _chRewindOriginalsHash(target),
                payout.payoutRewindInventoryV3(artistId),
                payout.payoutRecoveryRecordStatusV3(chRewindExcluded),
                continuation,
                CHWApplied(target.owners[5]).payoutRecoveryAppliedCommitmentV3(chRewindRecovery),
                CHWIdentity(target.owners[2])
                    .identityRecoveryEvidenceStateV3(artistId, chRewindAction),
                creation,
                payout.payoutDesignationRecoveryContinuationV3(chRewindConsumer)
            )
        );
        bytes32 applyKey = _chRewindKey(
            target, keccak256("payout_lifecycle.replay.recovery_rewind"), chRewindRecovery
        );
        bytes32 consumedKey = _chRewindKey(
            target,
            keccak256("payout_lifecycle.replay.recovery_continuation"),
            keccak256(abi.encode(artistId, chRewindContinuation, chRewindStable))
        );
        T.ReplayCell memory applied = Owner(target.owners[5]).replayCell(applyKey);
        T.ReplayCell memory consumed = Owner(target.owners[5]).replayCell(consumedKey);
        RH.Point memory appliedPoint;
        RH.Point memory consumedPoint;
        if (applied.status != 0) {
            appliedPoint = RecoveredOwner(target.owners[5]).recoveredHydrationReplayPoint(applyKey);
        }
        if (consumed.status != 0) {
            consumedPoint =
                RecoveredOwner(target.owners[5]).recoveredHydrationReplayPoint(consumedKey);
        }
        h = keccak256(abi.encode(h, applied, appliedPoint, consumed, consumedPoint));
    }

    function _chAssertPayoutContinuation(T.SuiteConfiguration memory target) internal view {
        require(
            _chPayoutContinuationHash(target) == _chPayoutContinuationHash(suite),
            "exact retained V3 Payout maps and original points"
        );
        CHWPayout payout = CHWPayout(target.owners[5]);
        CHW.StatusV3 memory status = payout.payoutRecoveryRecordStatusV3(chRewindExcluded);
        require(
            status.artistId == artistId && status.kind == CHW.RecordKind.PAYOUT_DESIGNATION
                && status.recoveryRecordHash == chRewindRecovery
                && status.actionId == chRewindAction && status.planCommitment == chRewindPlan,
            "immutable explicit exclusion status"
        );
        require(
            keccak256(
                abi.encode(
                    RecoveredOwner(target.owners[5])
                        .recoveredHydrationAuxiliaryPoint(
                            keccak256("payout_lifecycle.hydration.continuation_v3"),
                            chRewindContinuation
                        )
                )
            ) == keccak256(abi.encode(chRewindCreationPoint)),
            "continuation retains its original source auxiliary point"
        );
        bytes32 key = _chRewindKey(
            target,
            keccak256("payout_lifecycle.replay.recovery_continuation"),
            keccak256(abi.encode(artistId, chRewindContinuation, chRewindStable))
        );
        T.ReplayCell memory cell = Owner(target.owners[5]).replayCell(key);
        if (chRewindConsumer == 0) {
            require(
                cell.status == 0 && cell.commitment == 0,
                "first import carries unspent continuation"
            );
        } else {
            require(
                cell.status == 2 && cell.commitment == chRewindConsumer
                    && payout.payoutDesignationRecoveryContinuationV3(chRewindConsumer)
                        == chRewindContinuation
                    && keccak256(
                        abi.encode(
                            RecoveredOwner(target.owners[5]).recoveredHydrationReplayPoint(key)
                        )
                    ) == keccak256(abi.encode(chRewindConsumptionPoint)),
                "second import preserves spent continuation and original successor point"
            );
        }
    }

    function _chRewindOriginalsHash(T.SuiteConfiguration memory target)
        private
        view
        returns (bytes32 h)
    {
        for (uint256 i; i < chRewindOriginals.length; ++i) {
            CHW.PayoutOriginalV3 memory original = chRewindOriginals[i];
            T.PayoutDesignation memory body =
                CHFPayout(target.owners[5]).designationRecord(original.recordHash);
            bytes32 occurrence;
            // Empty destination maps are deliberately observable before the first atomic write.
            if (body.artistId != 0) {
                CHWRuntime.Context memory clock = CHWRuntime.load(_chRewindEnvironment(target), 5);
                CHWRuntime.ReceiptFact memory fact =
                    CHWRuntime.receiptAt(clock, chRewindLogicalIndexes[i]);
                require(
                    fact.receipt.recordHash == original.recordHash,
                    "original logical payout index unchanged"
                );
                occurrence = keccak256(abi.encode(fact));
            }
            h = keccak256(
                abi.encode(
                    h,
                    body,
                    occurrence,
                    IStreamArtistIdentityOwner(target.owners[2])
                        .signatureBundle(original.recordHash),
                    IStreamArtistIdentityOwner(target.owners[2]).nonceUsed(artistId, original.nonce)
                )
            );
        }
    }

    function _chRewindKey(T.SuiteConfiguration memory target, bytes32 surface, bytes32 scope)
        private
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"),
                block.chainid,
                target.registry,
                StreamArtistOnboardingRegistry(target.registry).operationCoordinator(),
                target.archive,
                target.owners[5],
                keccak256("domain:payout_lifecycle"),
                surface,
                scope
            )
        );
    }

    function _chRewindPrefix(uint8 index) private view returns (CHW.ReceiptPrefix memory) {
        return CHW.ReceiptPrefix(
            Owner(suite.owners[index]).ownerStateSnapshotV2(),
            CHWRuntime.logicalCount(CHWRuntime.load(_chRewindEnvironment(suite), index))
        );
    }

    function _chRewindEnvironment(T.SuiteConfiguration memory target)
        private
        view
        returns (CHW.EnvironmentV3 memory)
    {
        return CHW.EnvironmentV3(
            block.chainid,
            target.registry,
            target.owners[2],
            target.owners[2].codehash,
            target.owners[5],
            target.owners[5].codehash,
            StreamArtistOnboardingRegistry(target.registry).operationCoordinator(),
            target.archive,
            target.core,
            target.mintManager
        );
    }

    function _chRewindPublisher(address identity) private view returns (CHWPublisher publisher) {
        (address target, bytes32 code) = CHWIdentity(identity).recoveryRewindEvidenceBinding();
        require(code != 0 && target.codehash == code, "actual pinned V3 evidence worker");
        publisher = CHWPublisher(target);
        require(
            publisher.owner() == identity,
            "original evidence publisher belongs to its Identity owner"
        );
    }

    function _chRewindSelector() private view returns (CHWSelector selector) {
        (address target, bytes32 code) =
            CHWIdentity(suite.owners[2]).recoveryRewindSelectionBinding();
        require(code != 0 && target.codehash == code, "actual pinned V3 selection worker");
        selector = CHWSelector(target);
    }
}
