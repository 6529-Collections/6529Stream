// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredAuthorityActualTest
} from "./StreamArtistRecoveredAuthorityActual.t.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistAuthorityHydrationTypes as AH,
    IStreamArtistAuthorityHydrationOwner as HydrationOwner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistMultipleRecordsTypes as MR
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistMultipleRecordsHydration.sol";
import {
    StreamArtistReadinessHydrationTypes as Ready
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistReadinessAuthorityHydration.sol";
import {
    IStreamArtistRecoveredHydration as Recovered,
    IStreamArtistRecoveredHydrationOwner as RecoveredOwner,
    IStreamArtistRecoveredNativeChronology as NativeClock
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistRecoveredHydration.sol";
import {
    IStreamArtistOnboarding
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistOnboarding.sol";
import {
    IStreamArtistEconomicsAuthority
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistEconomicsAuthority.sol";
import {
    IStreamArtistEconomicsEvidence as Economics
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistEconomicsEvidence.sol";
import {
    IStreamArtistConsentOwner as Consent
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistConsentOwner.sol";
import {
    IStreamArtistBindingOwner as Binding
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistBindingOwner.sol";
import {
    IStreamArtistIdentityOwner as Identity
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistIdentityOwner.sol";
import {
    IStreamArtistPayoutOwner as Payout
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistPayoutOwner.sol";
import {
    IStreamArtistOwner as Owner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistOwner.sol";
import {
    IStreamArtistAuthorityCheckpoint as CP
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityCheckpoint.sol";
import {
    IStreamArtistNativeReceipts as Native,
    StreamArtistHistoryTypes as H
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistHistory.sol";
import {
    IStreamSplitWallet
} from "../../../smart-contracts/interfaces/stream/revenue/IStreamSplitWallet.sol";
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

/// @notice Real original35,18,15,14 and Safe/55/56/57/60 composition across fresh registries.
/// @dev The inherited Core and governance fixtures remain explicit typed unit boundaries.
/// No capability, checkpoint, semantic record, owner apply or resolver response is mocked here.
/// Source-authenticated historical associations are distinct from fresh prospective approval.
contract StreamArtistRecoveredEconomicsAuthorityActualTest is
    StreamArtistRecoveredAuthorityActualTest
{
    struct Approval {
        T.EconomicsConsent terms;
        bytes32 record;
        Economics.Association association;
        bytes32 digest;
        uint256 nonce;
        bytes signature;
        RH.Position position;
        RH.Point authorizationPoint;
    }

    Approval[] private ecApprovals;
    T.PolicyConsent private ecPolicy;
    bytes32 private ecPolicyRecord;
    bytes private ecPolicySignature;
    T.PayoutDesignation private ecPayout;
    bytes32 private ecPayoutRecord;

    function testRecoveredEconomicsOriginal35AndMixed15HistoryRemainOperativeAfterImport()
        external
    {
        _ecBaseline();
        T.SuiteConfiguration memory original = suite;
        Successor memory next = _rhCutover();
        bytes32 originalBefore = _ecSource(original, 2);
        _ecTransfer(next);
        _ecAssert(next.coordinator.suiteConfiguration(), 2);
        require(
            _ecSource(original, 2) == originalBefore, "import preserves sealed source economics"
        );

        _rhAdopt(next);
        Approval memory first = ecApprovals[0];
        T.Authorization memory fresh = _authorization(false);
        fresh.signature = _signature(ingress.economicsConsentDigest(first.terms, fresh));
        bytes32 key = _ecKey(
            suite, 6, "consent_finality.replay.consent_key", keccak256(abi.encode(first.terms))
        );
        bytes32 before_ = _rhDestinationHash(next);
        require(
            !Identity(suite.owners[2]).nonceUsed(artistId, fresh.nonce),
            "fresh nonce before duplicate payload"
        );
        vm.expectRevert(abi.encodeWithSelector(T.Replay.selector, key));
        ingress.recordEconomicsConsent(first.terms, fresh);
        require(
            _rhDestinationHash(next) == before_
                && !Identity(suite.owners[2]).nonceUsed(artistId, fresh.nonce),
            "old consent remains spent and failed fresh authorization is atomic"
        );
        _ecAssert(suite, 2);
    }

    function testRecoveredEconomicsFreshBApprovalAndSecondImportPreserveUltimateOrigins() external {
        _ecBaseline();
        T.SuiteConfiguration memory original = suite;
        Successor memory middle = _rhCutover();
        bytes32 originalBefore = _ecSource(original, 2);
        Commit.Prepared memory first = _ecTransfer(middle);
        _rhAdopt(middle);
        _ecFreshProspective();
        T.SuiteConfiguration memory intermediate = suite;
        _ecAssert(intermediate, 3);
        require(
            Consent(original.owners[6]).economicsRecord(ecApprovals[2].terms) == 0
                && Native(intermediate.owners[6]).artistNativeReceiptCount() == 1
                && Native(intermediate.owners[2]).artistNativeReceiptCount() == 0,
            "fresh B15 affects B Consent and Identity authorization, never fabricates Identity15"
        );

        Successor memory last = _rhCutover();
        bytes32 middleBefore = _ecSource(intermediate, 3);
        Commit.Prepared memory second = _ecTransfer(last);
        require(second.admission.provenance.eras.length == 2, "flat A and B eras");
        RH.JournalEntry[] memory beforeRows = first.admission.provenance.journals[6];
        RH.JournalEntry[] memory afterRows = second.admission.provenance.journals[6];
        require(beforeRows.length == 3 && afterRows.length == 4, "complete A15 A14 A15 and B15");
        for (uint256 i; i < beforeRows.length; ++i) {
            require(
                keccak256(abi.encode(beforeRows[i])) == keccak256(abi.encode(afterRows[i])),
                "A coordinates never relabelled B"
            );
        }
        require(
            afterRows[3].receipt.operation == 15
                && afterRows[3].receipt.recordHash == ecApprovals[2].record
                && keccak256(abi.encode(afterRows[3].position))
                    == keccak256(abi.encode(ecApprovals[2].position))
                && afterRows[3].position.point.environmentHash
                    == second.admission.provenance.eras[1].originHash
                && afterRows[3].position.nativeIndex == 0
                && afterRows[3].position.point.ownerRevision == 2,
            "B native15 retains genuine B local index and revision"
        );
        require(
            keccak256(abi.encode(first.admission.provenance.journals[2]))
                == keccak256(abi.encode(second.admission.provenance.journals[2])),
            "economics authorization adds no synthetic Identity native row"
        );
        _ecAssert(last.coordinator.suiteConfiguration(), 3);
        require(
            _ecSource(original, 2) == originalBefore && _ecSource(intermediate, 3) == middleBefore,
            "C import leaves both original suites unchanged"
        );
    }

    function testRecoveredEconomicsIncompleteAndReorderedWitnessesAndLateArchiveRetry() external {
        _ecBaseline();
        T.SuiteConfiguration memory original = suite;
        Successor memory next = _rhCutover();
        RH.Request memory request = _ecRequest();
        Commit.Prepared memory prepared =
            Prepared.prepare(next.coordinator.suiteConfiguration(), request);
        request.expectedSemanticInventory = Prepared.inventory(prepared);
        bytes32 before_ = _rhDestinationHash(next);
        bytes32 sourceBefore = _ecSource(original, 2);
        T.EconomicsConsent[] memory complete = request.records.witnesses[0].economics;
        request.records.witnesses[0].economics = new T.EconomicsConsent[](1);
        request.records.witnesses[0].economics[0] = complete[0];
        avm.expectRevert(T.UnsupportedProfile.selector);
        Recovered(address(next.registry)).hydrateRecoveredArtistAuthority(request);
        require(
            _rhDestinationHash(next) == before_, "missing original15 rejected before installation"
        );
        request.records.witnesses[0].economics = new T.EconomicsConsent[](2);
        request.records.witnesses[0].economics[0] = complete[1];
        request.records.witnesses[0].economics[1] = complete[0];
        avm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        Recovered(address(next.registry)).hydrateRecoveredArtistAuthority(request);
        require(
            _rhDestinationHash(next) == before_,
            "witnesses cannot reorder original native15 occurrences"
        );
        request.records.witnesses[0].economics = complete;
        bytes memory call_ = abi.encodeCall(Recovered.hydrateRecoveredArtistAuthority, (request));
        uint256 originalBlock = block.number;
        uint256 safeNonce = rotationSafe.nonce();
        vm.roll(uint256(type(uint64).max) + 1);
        vm.expectRevert(
            abi.encodeWithSignature(
                "ArtistArchiveBlockNumberOverflow(uint256)", uint256(type(uint64).max) + 1
            )
        );
        Recovered(address(next.registry)).hydrateRecoveredArtistAuthority(request);
        require(
            _rhDestinationHash(next) == before_,
            "late Archive restores all seven owners and catalogs"
        );
        vm.expectRevert(bytes("GS013"));
        this.rhExecuteNewSafe(address(next.registry), call_);
        require(
            rotationSafe.nonce() == safeNonce && _rhDestinationHash(next) == before_,
            "actual Safe nonce and typed economics apply roll back"
        );
        require(_ecSource(original, 2) == sourceBefore, "failed attempts never mutate source");
        vm.roll(originalBlock);
        require(
            this.rhExecuteNewSafe(address(next.registry), call_),
            "identical full request succeeds after Archive bound restored"
        );
        require(rotationSafe.nonce() == safeNonce + 1, "one successful Safe execution");
        _rhImported(next, prepared, HydrationOwner(next.identity).authorityHydrationCommitment());
        _ecAssert(next.coordinator.suiteConfiguration(), 2);
    }

    function _ecBaseline() private {
        _rhBaseline();
        _adoptRotatedSafe();
        uint64 end = ingress.artistTransitionState(rhRecovery).postWindowEndsAt;
        if (block.timestamp < end) vm.warp(end);
        T.Binding memory binding_ = Binding(suite.owners[0]).binding(1);
        ecPayout = T.PayoutDesignation(artistId, binding_.artistAddress, 0);
        T.Authorization memory a = _authorization(true);
        bytes32 digest = ingress.payoutDesignationDigest(ecPayout, a);
        _rhAuthorization(digest, a.nonce);
        a.signature = _signature(digest);
        ecPayoutRecord = ingress.recordPayoutDesignation(ecPayout, a);
        _rhCandidate(
            5, "payout_lifecycle.replay.designation_chain", keccak256(abi.encode(artistId))
        );
        (address actual, bytes32 actualRecord) = ingress.artistPayoutAccount(artistId);
        require(
            actual == ecPayout.payoutAccount && actualRecord == ecPayoutRecord,
            "real mature payout18 after original35"
        );
        (T.AssignmentFact memory first, T.AssignmentFact memory second) =
            coordinator.reads().currentAssignments(1);
        _ecCurrent(first);
        ecPolicy = T.PolicyConsent(
            1,
            keccak256("recovered economics interleaved phase"),
            keccak256("recovered economics policy")
        );
        a = _authorization(false);
        digest = ingress.policyConsentDigest(ecPolicy, a);
        _rhAuthorization(digest, a.nonce);
        a.signature = _signature(digest);
        ecPolicySignature = a.signature;
        ecPolicyRecord = ingress.recordPolicyConsent(ecPolicy, a);
        _rhCandidate(
            6,
            "consent_finality.replay.policy_consent_key",
            keccak256(abi.encode(ecPolicy.collectionId, ecPolicy.phaseId, ecPolicy.policyHash))
        );
        _ecCurrent(second);
        require(
            Native(suite.owners[6]).artistNativeReceiptCount() == 3
                && Native(suite.owners[6]).artistNativeReceiptAt(0).operation == 15
                && Native(suite.owners[6]).artistNativeReceiptAt(1).operation == 14
                && Native(suite.owners[6]).artistNativeReceiptAt(2).operation == 15,
            "real complete interleaved direct economics history"
        );
    }

    function _ecCurrent(T.AssignmentFact memory fact) private {
        T.EconomicsConsent memory p = T.EconomicsConsent(
            1, fact.resolver, fact.revenueClass, fact.scope, fact.scopeId, fact.assignmentHash
        );
        T.Authorization memory a = _authorization(false);
        bytes32 digest = ingress.economicsConsentDigest(p, a);
        a.signature = _signature(digest);
        bytes32 record = ingress.recordEconomicsConsent(p, a);
        _ecRemember(p, a, digest, record);
    }

    function _ecFreshProspective() private {
        IStreamSplitWallet.SplitEntry[] memory entries = new IStreamSplitWallet.SplitEntry[](2);
        entries[0] =
            IStreamSplitWallet.SplitEntry(ecPayout.payoutAccount, 800_000, keccak256("artist"));
        entries[1] = IStreamSplitWallet.SplitEntry(address(0xFEE), 200_000, keccak256("protocol"));
        (bytes32 profile,) =
            factory.createProfile(entries, keccak256("recovered B prospective economics"));
        T.AssignmentFact memory fact = primary.previewArtistPrimaryAssignment(1, profile, 0, false);
        T.EconomicsConsent memory p =
            T.EconomicsConsent(1, address(primary), PRIMARY, 1, 1, fact.assignmentHash);
        T.Authorization memory a = _authorization(false);
        bytes32 digest = ingress.economicsConsentDigest(p, a);
        a.signature = _signature(digest);
        T.Snapshot memory beforeIdentity = Owner(suite.owners[2]).ownerStateSnapshotV2();
        T.Snapshot memory beforeConsent = Owner(suite.owners[6]).ownerStateSnapshotV2();
        bytes32 record = IStreamArtistEconomicsAuthority(address(ingress))
            .recordProspectiveEconomicsConsent(
                p, T.FixedEconomicsCandidate(profile, 0, 0, false), a
            );
        _ecRemember(p, a, digest, record);
        require(
            Owner(suite.owners[2]).ownerStateSnapshotV2().revision == beforeIdentity.revision + 1
                && Owner(suite.owners[6]).ownerStateSnapshotV2().revision
                    == beforeConsent.revision + 1,
            "fresh signed B economics uses actual local authorization and original owner commits"
        );
        (T.AssignmentFact memory current,) = coordinator.reads().currentAssignments(1);
        require(
            current.assignmentHash == ecApprovals[0].terms.assignmentHash
                && current.assignmentHash != p.assignmentHash,
            "prospective approval does not replace current assignment or historical consent"
        );
    }

    function _ecRemember(
        T.EconomicsConsent memory p,
        T.Authorization memory a,
        bytes32 digest,
        bytes32 record
    ) private {
        _rhAuthorization(digest, a.nonce);
        _rhCandidate(6, "consent_finality.replay.consent_key", keccak256(abi.encode(p)));
        uint256 index = Native(suite.owners[6]).artistNativeReceiptCount() - 1;
        H.Receipt memory row = Native(suite.owners[6]).artistNativeReceiptAt(index);
        require(
            row.operation == 15 && row.artistId == artistId && row.collectionId == 1
                && row.recordHash == record,
            "actual original15 occurrence"
        );
        Approval memory approval;
        approval.terms = p;
        approval.record = record;
        approval.association = Economics(suite.owners[6]).economicsRecordAssociation(record);
        approval.digest = digest;
        approval.nonce = a.nonce;
        approval.signature = a.signature;
        approval.position = RH.Position(
            RH.Point(
                RH.originHash(_ecOrigin(suite)),
                6,
                NativeClock(suite.owners[6]).artistNativeReceiptRevisionAt(index)
            ),
            index
        );
        approval.authorizationPoint = RH.Point(
            approval.position.point.environmentHash,
            2,
            Owner(suite.owners[2]).ownerStateSnapshotV2().revision
        );
        ecApprovals.push(approval);
    }

    function _ecRequest() private view returns (RH.Request memory p) {
        p = _rhRequest();
        p.records.authority.collections[0].policies = new AH.PolicyKey[](1);
        p.records.authority.collections[0].policies[0] =
            AH.PolicyKey(ecPolicy.phaseId, ecPolicy.policyHash);
        p.records.witnesses = new MR.CollectionWitness[](1);
        p.records.witnesses[0].collectionId = 1;
        p.records.witnesses[0].economics = new T.EconomicsConsent[](ecApprovals.length);
        p.records.witnesses[0].attestations = new Ready.AttestationInput[](0);
        for (uint256 i; i < ecApprovals.length; ++i) {
            p.records.witnesses[0].economics[i] = ecApprovals[i].terms;
        }
    }

    function _ecTransfer(Successor memory next) private returns (Commit.Prepared memory p) {
        RH.Request memory request = _ecRequest();
        p = Prepared.prepare(next.coordinator.suiteConfiguration(), request);
        for (uint8 i; i < 7; ++i) {
            (RH.ExportHeader memory header,) = Payload.decode(p.data[i].typedState, i);
            require(
                (header.requiredFeatures & RH.DIRECT_ECONOMICS) != 0,
                "all owner headers bind actual economics feature"
            );
        }
        request.expectedSemanticInventory = Prepared.inventory(p);
        bytes32 value = Recovered(address(next.registry)).hydrateRecoveredArtistAuthority(request);
        _rhImported(next, p, value);
    }

    function _ecAssert(T.SuiteConfiguration memory target, uint256 count) private {
        T.Binding memory binding_ = Binding(target.owners[0]).binding(1);
        require(
            binding_.artistId == artistId && binding_.generation == 1 && binding_.accepted,
            "unchanged accepted original binding"
        );
        require(
            Consent(target.owners[6]).policyRecord(1, ecPolicy.phaseId, ecPolicy.policyHash)
                    == ecPolicyRecord
                && keccak256(Identity(target.owners[2]).signatureBundle(ecPolicyRecord))
                == keccak256(ecPolicySignature)
                && keccak256(abi.encode(Payout(target.owners[5]).designationRecord(ecPayoutRecord)))
                == keccak256(abi.encode(ecPayout)),
            "interleaved policy and actual historical payout remain exact"
        );
        (RH.OwnerProvenance memory prefix,,) =
            RecoveredOwner(target.owners[6]).recoveredHydrationImportedPrefix();
        for (uint256 i; i < count; ++i) {
            Approval memory a = ecApprovals[i];
            require(
                Consent(target.owners[6]).economicsRecord(a.terms) == a.record
                    && Economics(target.owners[6])
                        .economicsRecordForBinding(a.terms, artistId, 1, binding_.bindingHash)
                    == a.record
                    && keccak256(
                        abi.encode(Economics(target.owners[6]).economicsRecordAssociation(a.record))
                    ) == keccak256(abi.encode(a.association))
                    && Economics(target.owners[6])
                        .economicsRecordForBinding(a.terms, artistId, 2, binding_.bindingHash) == 0,
                "exact raw payload and original binding association; no new-generation consent"
            );
            require(
                keccak256(Identity(target.owners[2]).signatureBundle(a.record))
                        == keccak256(a.signature)
                    && Identity(target.owners[2]).nonceUsed(artistId, a.nonce),
                "original domain signature bytes and nonce remain retained"
            );
            _ecAuthorization(target, a);
            bytes32 key = _ecKey(
                target, 6, "consent_finality.replay.consent_key", keccak256(abi.encode(a.terms))
            );
            T.ReplayCell memory cell = Owner(target.owners[6]).replayCell(key);
            require(
                cell.commitment == a.record && cell.kind == 1 && cell.status == 2
                    && cell.touchedRevision == a.position.point.ownerRevision,
                "retained consumed cell never rewrites original revision"
            );
            require(
                keccak256(
                    abi.encode(RecoveredOwner(target.owners[6]).recoveredHydrationReplayPoint(key))
                ) == keccak256(abi.encode(a.position.point)),
                "rekeyed or local cell resolves exact ultimate producer point"
            );
            uint256 matches;
            for (uint256 j; j < prefix.journal.length; ++j) {
                if (prefix.journal[j].receipt.recordHash != a.record) continue;
                require(
                    keccak256(abi.encode(prefix.journal[j].position))
                        == keccak256(abi.encode(a.position)),
                    "imported economics occurrence retains original coordinate"
                );
                ++matches;
            }
            uint256 nativeCount = Native(target.owners[6]).artistNativeReceiptCount();
            for (uint256 j; j < nativeCount; ++j) {
                if (Native(target.owners[6]).artistNativeReceiptAt(j).recordHash == a.record) {
                    ++matches;
                }
            }
            require(matches == 1, "one genuine imported or native economics occurrence");
            vm.prank(a.terms.resolver);
            IStreamArtistEconomicsAuthority(target.registry)
                .requireEconomicsConsent(
                    1, a.terms.revenueClass, a.terms.scope, a.terms.scopeId, a.terms.assignmentHash
                );
        }
    }

    function _ecAuthorization(T.SuiteConfiguration memory target, Approval memory a) private view {
        bytes32[2] memory keys_;
        keys_[0] = _ecKey(
            target,
            2,
            "identity_authority.replay.authorization_consumed_digest",
            keccak256(abi.encode(artistId, a.digest))
        );
        keys_[1] = _ecKey(
            target,
            2,
            "identity_authority.replay.nonce_allocator",
            keccak256(abi.encode(artistId, a.nonce))
        );
        for (uint256 j; j < keys_.length; ++j) {
            T.ReplayCell memory cell = Owner(target.owners[2]).replayCell(keys_[j]);
            require(
                cell.commitment == a.digest && cell.kind == 1 && cell.status == 2
                    && cell.touchedRevision == a.authorizationPoint.ownerRevision
                    && keccak256(
                        abi.encode(
                            RecoveredOwner(target.owners[2]).recoveredHydrationReplayPoint(keys_[j])
                        )
                    ) == keccak256(abi.encode(a.authorizationPoint)),
                "Identity retains its own original authorization clock independently of Consent"
            );
        }
    }

    function _ecSource(T.SuiteConfiguration memory target, uint256 count)
        private
        view
        returns (bytes32 value)
    {
        value = _rhRecoveryFacts(target.owners[2]);
        for (uint8 i; i < 7; ++i) {
            value = keccak256(
                abi.encode(
                    value,
                    CP(target.owners[i]).authorityCheckpoint(),
                    Publications.collect(target.owners[i], i)
                )
            );
        }
        for (uint256 i; i < count; ++i) {
            Approval memory a = ecApprovals[i];
            value = keccak256(
                abi.encode(
                    value,
                    Consent(target.owners[6]).economicsRecord(a.terms),
                    Economics(target.owners[6]).economicsRecordAssociation(a.record),
                    Economics(target.owners[6])
                        .economicsRecordForBinding(a.terms, artistId, 1, a.association.bindingHash),
                    Identity(target.owners[2]).signatureBundle(a.record)
                )
            );
        }
    }

    function _ecKey(
        T.SuiteConfiguration memory target,
        uint8 owner,
        string memory surface,
        bytes32 scope
    ) private view returns (bytes32) {
        return Guards.replayKey(
            _ecOrigin(target), owner, AH.Origin(keccak256(bytes(surface)), scope)
        );
    }

    function _ecOrigin(T.SuiteConfiguration memory target)
        private
        view
        returns (RH.OriginEnvironment memory e)
    {
        e.chainId = block.chainid;
        e.registry = target.registry;
        e.coordinator = Owner(target.owners[2]).operationCoordinator();
        e.archive = target.archive;
        e.owners = target.owners;
        for (uint8 i; i < 7; ++i) {
            e.ownerCodeHashes[i] = target.owners[i].codehash;
        }
        e.core = target.core;
        e.manager = target.mintManager;
        e.suiteConfigurationHash = keccak256(abi.encode(target));
    }
}
