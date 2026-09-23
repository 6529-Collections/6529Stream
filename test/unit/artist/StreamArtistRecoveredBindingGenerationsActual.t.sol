// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredAuthorityActualTest
} from "./StreamArtistRecoveredAuthorityActual.t.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistBindingLifecycleTypes as L
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistBindingLifecycleTypes.sol";
import {
    StreamArtistCollaboratorTypes as C
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistCollaboratorTypes.sol";
import {
    IStreamArtistBindingOwner as Binding
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistBindingOwner.sol";
import {
    IStreamArtistBindingTerminationOwner as Terminal
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistBindingTerminationOwner.sol";
import {
    IStreamArtistCollaboratorBindingOwner as Terms
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistCollaboratorBindingOwner.sol";
import {
    IStreamArtistBindingLifecycle
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistBindingLifecycle.sol";
import {
    IStreamArtistAcceptanceOwner as Acceptance
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAcceptanceOwner.sol";
import {
    IStreamArtistAttributionOwner as Attribution
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAttributionOwner.sol";
import {
    IStreamArtistIdentityOwner as Identity
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistIdentityOwner.sol";
import {
    IStreamArtistConsentOwner as Consent
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistConsentOwner.sol";
import {
    IStreamArtistOnboarding
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistOnboarding.sol";
import {
    IStreamArtistIdentityRevision as Documents,
    StreamArtistIdentityRevisionTypes as Doc
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistIdentityRevision.sol";
import {
    IStreamArtistOwner as Owner
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistOwner.sol";
import {
    IStreamArtistArchiveV2 as Archive
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistArchiveV2.sol";
import {
    IStreamArtistAuthorityCheckpoint as CP
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAuthorityCheckpoint.sol";
import {
    IStreamArtistNativeReceipts as Native,
    StreamArtistHistoryTypes as H
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistHistory.sol";
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

/// @notice Real pending1/refused3/withdrawn4/reproposed1/accepted2 history followed by actual35/60.
/// @dev Core and governance are the inherited explicitly typed fixture boundaries. Seven owners,
/// Registry, Coordinator, Archive, original signature checks and threshold Safes are real.
/// Withdrawal is a mutation plus replay cell and Archive evidence; it creates no native receipt.
/// Identity2/3 likewise have actual authorization points, never invented Identity native rows.
/// Scope is one same-Artist, PRIMARY_ONLY mode1 collection with complete generations and policy14.
/// No capability, checkpoint, semantic storage or provenance mocks. Native execution remains pending.
contract StreamArtistRecoveredBindingGenerationsActualTest is
    StreamArtistRecoveredAuthorityActualTest
{
    struct Generation {
        T.Binding binding;
        C.BindingTerms terms;
        L.Terminal terminal;
        L.Termination termination;
        RH.Position proposal;
        RH.Position refusal;
        RH.Point terminalPoint;
        bytes32 archiveId;
        bytes32 archiveHash;
    }

    struct Authorization {
        bytes32 record;
        bytes32 digest;
        T.Authorization value;
        RH.Point point;
    }

    struct Policy {
        T.PolicyConsent terms;
        bytes32 record;
        RH.Position position;
    }
    Generation[] private bgGenerations;
    Authorization[] private bgAuthorizations;
    Policy[] private bgPolicies;
    address private bgOriginalArchive;
    bytes32 private bgAcceptance;
    uint64 private bgAcceptedAt;
    RH.Position private bgAcceptancePosition;
    address private bgAcceptanceSigner;
    Doc.Record private bgRevision;
    bytes private bgDocument;
    RH.Position private bgRevisionPosition;

    function testRecoveredGenerationsRefusalWithdrawalAndAcceptedThirdRemainExact() external {
        _bgBaseline(2);
        T.SuiteConfiguration memory original = suite;
        Successor memory next = _rhCutover();
        bytes32 sourceBefore =
            _bgSource(original, bgAuthorizations.length, bgPolicies.length, false);
        _bgTransfer(next);
        _bgAssert(
            next.coordinator.suiteConfiguration(), bgAuthorizations.length, bgPolicies.length, false
        );
        _rhAdopt(next);
        bytes32 before_ = _rhDestinationHash(next);
        L.Termination memory old = bgGenerations[0].termination;
        T.Authorization memory fresh = _authorization(false);
        fresh.signature = _signature(ingress.bindingRefusalDigest(old, fresh));
        vm.expectRevert(abi.encodeWithSelector(T.InvalidAttribution.selector, uint256(1)));
        ingress.refuseArtistBinding(old, fresh);
        vm.expectRevert(abi.encodeWithSelector(T.InvalidAttribution.selector, uint256(1)));
        ingress.withdrawArtistBinding(bgGenerations[1].termination);
        vm.expectRevert(abi.encodeWithSelector(T.InvalidAttribution.selector, uint256(1)));
        ingress.acceptArtistBindingExpected(1, 1, bgGenerations[0].binding.bindingHash, fresh);
        require(
            _rhDestinationHash(next) == before_
                && !Identity(suite.owners[2]).nonceUsed(artistId, fresh.nonce),
            "terminated originals and accepted final head never reopen"
        );
        require(
            _bgSource(original, bgAuthorizations.length, bgPolicies.length, false) == sourceBefore,
            "all sealed generation originals untouched"
        );
    }

    function testRecoveredGenerationsWithdrawalSecondThenFreshBRevisionPolicyAndC() external {
        _bgBaseline(0);
        T.SuiteConfiguration memory original = suite;
        uint256 aAuthorizations = bgAuthorizations.length;
        uint256 aPolicies = bgPolicies.length;
        Successor memory middle = _rhCutover();
        bytes32 aBefore = _bgSource(original, aAuthorizations, aPolicies, false);
        Commit.Prepared memory first = _bgTransfer(middle);
        _rhAdopt(middle);
        _bgRevise();
        _bgPolicy(2);
        T.SuiteConfiguration memory intermediate = suite;
        uint256 bAuthorizations = bgAuthorizations.length;
        uint256 bPolicies = bgPolicies.length;
        _bgAssert(intermediate, bAuthorizations, bPolicies, true);
        Successor memory last = _rhCutover();
        bytes32 bBefore = _bgSource(intermediate, bAuthorizations, bPolicies, true);
        Commit.Prepared memory second = _bgTransfer(last);
        require(second.admission.provenance.eras.length == 2, "actual flattened A/B eras");
        for (uint8 owner; owner < 7; ++owner) {
            RH.JournalEntry[] memory a = first.admission.provenance.journals[owner];
            RH.JournalEntry[] memory ab = second.admission.provenance.journals[owner];
            require(
                ab.length == a.length + ((owner == 2 || owner == 6) ? 1 : 0),
                "only B25/B14 extend original native inventories"
            );
            for (uint256 i; i < a.length; ++i) {
                require(
                    keccak256(abi.encode(a[i])) == keccak256(abi.encode(ab[i])),
                    "A generations and paired35 keep ultimate coordinates"
                );
            }
        }
        _bgAssert(last.coordinator.suiteConfiguration(), bAuthorizations, bPolicies, true);
        _rhAdopt(last);
        _bgPolicy(3);
        _bgAssert(suite, bgAuthorizations.length, bgPolicies.length, true);
        require(
            _bgSource(original, aAuthorizations, aPolicies, false) == aBefore
                && _bgSource(intermediate, bAuthorizations, bPolicies, true) == bBefore,
            "C import and fresh signing do not grow either ancestor oracle"
        );
    }

    function testRecoveredGenerationsRefusedSecondKeepsCurrentDomainAndSpentPrincipalLane()
        external
    {
        _bgBaseline(1);
        Successor memory next = _rhCutover();
        _bgTransfer(next);
        _bgAssert(
            next.coordinator.suiteConfiguration(), bgAuthorizations.length, bgPolicies.length, false
        );
        _rhAdopt(next);
        Authorization memory original = bgAuthorizations[bgAuthorizations.length - 1];
        T.PolicyConsent memory policy = bgPolicies[0].terms;
        bytes32 before_ = _rhDestinationHash(next);
        avm.expectRevert(T.InvalidSignature.selector);
        ingress.recordPolicyConsent(policy, original.value);
        T.Authorization memory a = original.value;
        a.signature = _signature(ingress.policyConsentDigest(policy, a));
        vm.expectRevert(
            abi.encodeWithSelector(
                T.Replay.selector,
                _bgKey(
                    suite,
                    2,
                    "identity_authority.replay.nonce_allocator",
                    keccak256(abi.encode(artistId, a.nonce))
                )
            )
        );
        ingress.recordPolicyConsent(policy, a);
        a = _authorization(false);
        a.signature = _signature(ingress.policyConsentDigest(policy, a));
        vm.expectRevert(
            abi.encodeWithSelector(
                T.Replay.selector,
                _bgKey(
                    suite,
                    6,
                    "consent_finality.replay.policy_consent_key",
                    keccak256(abi.encode(policy.collectionId, policy.phaseId, policy.policyHash))
                )
            )
        );
        ingress.recordPolicyConsent(policy, a);
        require(
            _rhDestinationHash(next) == before_
                && !Identity(suite.owners[2]).nonceUsed(artistId, a.nonce),
            "original policy replay restores tentative current authorization"
        );
        _bgPolicy(4);
        _bgAssert(suite, bgAuthorizations.length, bgPolicies.length, false);
    }

    function testRecoveredGenerationsValidPrepareThenExactSourceCapabilityAndArchiveRetry()
        external
    {
        _bgBaseline(2);
        T.SuiteConfiguration memory original = suite;
        Successor memory next = _rhCutover();
        RH.Request memory request = _bgRequest();
        Commit.Prepared memory prepared = _bgPrepared(next, request);
        request.expectedSemanticInventory = Prepared.inventory(prepared);
        bytes32 before_ = _rhDestinationHash(next);
        bytes32 sourceBefore =
            _bgSource(original, bgAuthorizations.length, bgPolicies.length, false);
        request.expectedCapabilities[0].supportedFeatures &= ~uint256(512);
        avm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        Recovered(address(next.registry)).hydrateRecoveredArtistAuthority(request);
        request.expectedCapabilities[0].supportedFeatures |= 512;
        ++request.records.authority.expectedSource[0].ownerState.revision;
        avm.expectRevert(RH.InvalidRecoveredHydrationProvenance.selector);
        Recovered(address(next.registry)).hydrateRecoveredArtistAuthority(request);
        --request.records.authority.expectedSource[0].ownerState.revision;
        AH.Origin memory correct = AH.Origin(
            request.records.authority.replayOrigins[0][0].surface,
            request.records.authority.replayOrigins[0][0].scope
        );
        request.records.authority.replayOrigins[0][0].scope = keccak256("omitted actual generation");
        avm.expectRevert(RH.InvalidRecoveredHydrationProvenance.selector);
        Recovered(address(next.registry)).hydrateRecoveredArtistAuthority(request);
        request.records.authority.replayOrigins[0][0] = correct;
        require(
            _rhDestinationHash(next) == before_,
            "complete positive prepare precedes malformed-certificate negatives"
        );
        bytes memory call_ = abi.encodeCall(Recovered.hydrateRecoveredArtistAuthority, (request));
        uint256 oldBlock = block.number;
        uint256 nonce = rotationSafe.nonce();
        vm.roll(uint256(type(uint64).max) + 1);
        vm.expectRevert(
            abi.encodeWithSignature(
                "ArtistArchiveBlockNumberOverflow(uint256)", uint256(type(uint64).max) + 1
            )
        );
        Recovered(address(next.registry)).hydrateRecoveredArtistAuthority(request);
        vm.expectRevert(bytes("GS013"));
        this.rhExecuteNewSafe(address(next.registry), call_);
        T.SuiteConfiguration memory target = next.coordinator.suiteConfiguration();
        require(
            _rhDestinationHash(next) == before_ && rotationSafe.nonce() == nonce,
            "late Archive restores all owner roots/catalogs and Safe nonce"
        );
        for (uint64 generation = 1; generation <= bgGenerations.length; ++generation) {
            require(
                Binding(target.owners[0]).bindingAt(1, generation).bindingHash == 0
                    && Terminal(target.owners[0]).bindingTermination(1, generation).kind == 0,
                "all generation bodies and terminal maps reverted"
            );
        }
        require(
            Acceptance(target.owners[3]).acceptanceRecord(bgGenerations[2].binding.bindingHash) == 0
                && _bgSource(original, bgAuthorizations.length, bgPolicies.length, false)
                    == sourceBefore,
            "acceptance map restored and source never written"
        );
        vm.roll(oldBlock);
        require(
            this.rhExecuteNewSafe(address(next.registry), call_),
            "identical threshold Safe request succeeds after restoring Archive bound"
        );
        require(rotationSafe.nonce() == nonce + 1, "only accepted retry spends Safe nonce");
        _rhImported(next, prepared, HydrationOwner(next.identity).authorityHydrationCommitment());
        _bgAssert(target, bgAuthorizations.length, bgPolicies.length, false);
    }

    // path0: withdrawal→2; path1: refusal→2; path2: refusal→2→withdrawal→3.
    function _bgBaseline(uint8 path) private {
        bgOriginalArchive = address(archive);
        _bgCapturePending();
        _bgTerminate(path != 0);
        _bgRepropose();
        if (path == 2) {
            _bgTerminate(false);
            _bgRepropose();
        }
        uint64 generation = uint64(bgGenerations.length);
        T.Authorization memory a = T.Authorization(nextNonce, uint64(block.timestamp + 1 days), "");
        bytes32 digest = ingress.acceptanceDigest(1, a);
        a.signature = _signature(digest);
        bgAcceptanceSigner = address(artist);
        uint64 observed = uint64(block.timestamp);
        // The inherited call is a signed relay; its digest pins the actual pending generation.
        // Its unused gen1 acceptance candidate creates no state. Add the actual generation below.
        _rhBaseline();
        bgAcceptance = Acceptance(suite.owners[3])
            .acceptanceRecord(bgGenerations[generation - 1].binding.bindingHash);
        bgAcceptedAt = Acceptance(suite.owners[3])
            .acceptedAt(bgGenerations[generation - 1].binding.bindingHash);
        require(
            bgAcceptance
                    == keccak256(
                        abi.encode(
                            keccak256("6529STREAM_ARTIST_ACCEPTANCE_RECORD_V1"),
                            block.chainid,
                            address(ingress),
                            address(core),
                            uint256(1),
                            generation,
                            bgGenerations[generation - 1].binding.bindingHash,
                            uint8(1),
                            bgAcceptanceSigner,
                            uint8(1),
                            a.nonce,
                            observed
                        )
                    ) && bgAcceptedAt == observed,
            "literal original acceptance belongs only to final generation"
        );
        _bgAuthorization(bgAcceptance, digest, a);
        _rhCandidate(
            3,
            "acceptance_lifecycle.replay.record_uniqueness",
            keccak256(abi.encode(uint256(1), generation, uint8(1), bgAcceptanceSigner))
        );
        bgAcceptancePosition = _bgPosition(3, 2, bgAcceptance);
        bgGenerations[generation - 1].binding = Binding(suite.owners[0]).bindingAt(1, generation);
        _adoptRotatedSafe();
        uint64 end = ingress.artistTransitionState(rhRecovery).postWindowEndsAt;
        if (block.timestamp < end) vm.warp(end);
        _bgPolicy(1);
        require(
            Native(suite.owners[0]).artistNativeReceiptCount() == generation + (path == 0 ? 0 : 1)
                && Native(suite.owners[3]).artistNativeReceiptCount() == 1
                && Native(suite.owners[4]).artistNativeReceiptCount() == 0,
            "only original proposals/refusal and final acceptance are native, never withdrawal/base Attribution"
        );
        _bgAssert(suite, bgAuthorizations.length, bgPolicies.length, false);
    }

    function _bgCapturePending() private {
        Generation memory g;
        g.binding = Binding(suite.owners[0]).binding(1);
        g.terms = Terms(suite.owners[0]).bindingTerms(1, g.binding.generation);
        require(
            !g.binding.accepted && g.binding.artistId == artistId
                && g.binding.generation == bgGenerations.length + 1 && g.terms.count == 0
                && g.binding.consentMode == 1,
            "complete same-Artist singleton PRIMARY_ONLY generation prefix"
        );
        require(
            g.binding.bindingHash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_BINDING_V1"),
                        block.chainid,
                        address(ingress),
                        address(core),
                        uint256(1),
                        g.binding.generation,
                        artistId,
                        g.binding.artistAddress,
                        g.binding.identityRecordHash,
                        g.binding.consentMode,
                        g.binding.saleConsentScope,
                        g.binding.registryImmutabilityElection,
                        uint8(0),
                        uint32(0),
                        g.terms.collaboratorSetHash,
                        g.terms.capabilityPolicySetHash
                    )
                ),
            "literal original generation-specific proposal hash"
        );
        g.proposal = _bgPosition(0, 1, g.binding.bindingHash);
        bgGenerations.push(g);
        _rhCandidate(
            0,
            "binding_lifecycle.replay.proposal_key",
            keccak256(abi.encode(uint256(1), g.binding.generation))
        );
    }

    function _bgTerminate(bool refused) private {
        uint256 index = bgGenerations.length - 1;
        Generation storage g = bgGenerations[index];
        L.Termination memory p = _termination(1);
        uint256 identityCount = Native(suite.owners[2]).artistNativeReceiptCount();
        uint256 bindingCount = Native(suite.owners[0]).artistNativeReceiptCount();
        uint64 bindingRevision = Owner(suite.owners[0]).ownerStateSnapshotV2().revision;
        uint64 attributionRevision = Owner(suite.owners[4]).ownerStateSnapshotV2().revision;
        bytes32 record;
        string memory surface;
        if (refused) {
            T.Authorization memory a = _authorization(false);
            bytes32 digest = ingress.bindingRefusalDigest(p, a);
            a.signature = _signature(digest);
            record = ingress.refuseArtistBinding(p, a);
            require(
                record
                    == keccak256(
                        abi.encode(
                            bytes32(
                                0x61e2c527c98d65328522fa0ac36862f52a59a2035e3e2ca4a0bfd5da13ee95ed
                            ),
                            block.chainid,
                            address(ingress),
                            address(core),
                            uint256(1),
                            p.generation,
                            p.bindingHash,
                            artistId,
                            address(artist),
                            uint8(1),
                            p.reasonHash,
                            a.nonce,
                            uint64(block.timestamp)
                        )
                    ),
                "literal original3 refusal record"
            );
            _bgAuthorization(record, digest, a);
            g.refusal = _bgPosition(0, 3, record);
            surface = "binding_lifecycle.replay.refusal_uniqueness";
        } else {
            require(g.binding.proposer == address(this), "withdrawal uses actual saved proposer");
            ingress.withdrawArtistBinding(p);
            surface = "binding_lifecycle.replay.proposal_terminal_transition_key";
        }
        g.termination = p;
        g.terminal = Terminal(suite.owners[0]).bindingTermination(1, p.generation);
        require(
            g.terminal.kind == (refused ? 1 : 2) && g.terminal.reasonHash == p.reasonHash
                && g.terminal.recordHash == record,
            "exact historical terminal kind/reason and no synthetic withdrawal record"
        );
        require(
            Native(suite.owners[2]).artistNativeReceiptCount() == identityCount
                && Native(suite.owners[0]).artistNativeReceiptCount()
                    == bindingCount + (refused ? 1 : 0)
                && Native(suite.owners[4]).artistNativeReceiptCount() == 0,
            "Identity3 and all4 mutations create no artificial native receipt"
        );
        require(
            Owner(suite.owners[0]).ownerStateSnapshotV2().revision == bindingRevision + 1
                && Owner(suite.owners[4]).ownerStateSnapshotV2().revision
                    == attributionRevision + 1,
            "original terminal updates both original owner clocks once"
        );
        bytes32 scope = keccak256(abi.encode(uint256(1), p.generation));
        _rhCandidate(0, surface, scope);
        g.terminalPoint = RecoveredOwner(suite.owners[0])
            .recoveredHydrationReplayPoint(_bgKey(suite, 0, surface, scope));
        uint16 op = refused ? 3 : 4;
        bytes32 recordRef = refused ? record : p.bindingHash;
        g.archiveId = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"),
                block.chainid,
                address(ingress),
                address(coordinator),
                op,
                address(this),
                recordRef
            )
        );
        g.archiveHash = keccak256(Archive(bgOriginalArchive).artistEvidenceBytesV2(g.archiveId, 1));
        require(
            _operationPayload(op, address(this), recordRef).length != 0,
            "original termination Archive evidence exists"
        );
    }

    function _bgRepropose() private {
        uint256 count = Native(suite.owners[2]).artistNativeReceiptCount();
        _repropose(1);
        require(
            Native(suite.owners[2]).artistNativeReceiptCount() == count,
            "reproposal reuses the real registered Artist"
        );
        _bgCapturePending();
    }

    function _bgPolicy(uint256 salt) private {
        T.PolicyConsent memory p = T.PolicyConsent(
            1,
            keccak256(abi.encode("generation policy phase", salt)),
            keccak256(abi.encode("generation policy body", salt))
        );
        T.Authorization memory a = _authorization(false);
        bytes32 digest = ingress.policyConsentDigest(p, a);
        a.signature = _signature(digest);
        bytes32 record = ingress.recordPolicyConsent(p, a);
        _bgAuthorization(record, digest, a);
        _rhCandidate(
            6,
            "consent_finality.replay.policy_consent_key",
            keccak256(abi.encode(p.collectionId, p.phaseId, p.policyHash))
        );
        bgPolicies.push(Policy(p, record, _bgPosition(6, 14, record)));
    }

    function _bgRevise() private {
        bgDocument = bytes("actual B revised identity after retained generations and recovery");
        Doc.Revision memory p = _revisionProposal(bgDocument);
        T.Authorization memory a = _authorization(true);
        bytes32 digest = ingress.identityRevisionDigest(p, a);
        a.signature = _signature(digest);
        bytes32 record = ingress.recordIdentityRevision(p, a, bgDocument, "Recovered B artist");
        bgRevision = ingress.identityRevisionRecord(record);
        _bgAuthorization(record, digest, a);
        _rhCandidate(
            2,
            "identity_authority.replay.identity_revision_chain",
            keccak256(
                abi.encode(
                    artistId, bgRevision.previousRevisionRecord, bgRevision.previousRecordHash
                )
            )
        );
        bgRevisionPosition = _bgPosition(2, 25, record);
        require(
            ingress.operativeIdentityRecord(artistId) == keccak256(bgDocument),
            "genuine fresh25 updates operative identity"
        );
    }

    function _bgAuthorization(bytes32 record, bytes32 digest, T.Authorization memory a) private {
        _rhAuthorization(digest, a.nonce);
        bytes32 key = _bgKey(
            suite,
            2,
            "identity_authority.replay.nonce_allocator",
            keccak256(abi.encode(artistId, a.nonce))
        );
        T.ReplayCell memory actual = Owner(suite.owners[2]).replayCell(key);
        RH.Point memory point = RecoveredOwner(suite.owners[2]).recoveredHydrationReplayPoint(key);
        require(
            actual.commitment == digest && actual.status == 2
                && point.ownerRevision == actual.touchedRevision,
            "actual producer admission point, not guessed time/native position"
        );
        bgAuthorizations.push(Authorization(record, digest, a, point));
    }

    function _bgRequest() private view returns (RH.Request memory p) {
        p = _rhRequest();
        p.records.authority.collections[0].policies = new AH.PolicyKey[](bgPolicies.length);
        for (uint256 i; i < bgPolicies.length; ++i) {
            p.records.authority.collections[0].policies[i] =
                AH.PolicyKey(bgPolicies[i].terms.phaseId, bgPolicies[i].terms.policyHash);
        }
    }

    function _bgPrepared(Successor memory next, RH.Request memory p)
        private
        view
        returns (Commit.Prepared memory prepared)
    {
        prepared = Prepared.prepare(next.coordinator.suiteConfiguration(), p);
        for (uint8 i; i < 7; ++i) {
            (RH.ExportHeader memory h,) = Payload.decode(prepared.data[i].typedState, i);
            uint256 features = uint256(512) | RH.CLASS_ONE;
            if (prepared.admission.provenance.eras.length > 1) features |= RH.REPEATED_IMPORT;
            require(
                h.requiredFeatures == features
                    && (p.expectedCapabilities[i].supportedFeatures & 1023) == 1023,
                "actual generations select explicit512 without unrelated content/delegation features"
            );
        }
    }

    function _bgTransfer(Successor memory next) private returns (Commit.Prepared memory prepared) {
        RH.Request memory p = _bgRequest();
        prepared = _bgPrepared(next, p);
        p.expectedSemanticInventory = Prepared.inventory(prepared);
        require(
            this.rhExecuteNewSafe(
                address(next.registry),
                abi.encodeCall(Recovered.hydrateRecoveredArtistAuthority, (p))
            ),
            "real threshold Safe original operation60 entry point"
        );
        _rhImported(next, prepared, HydrationOwner(next.identity).authorityHydrationCommitment());
    }

    function _bgAssert(
        T.SuiteConfiguration memory target,
        uint256 authCount,
        uint256 policyCount,
        bool revision
    ) private view {
        uint64 count = uint64(bgGenerations.length);
        for (uint64 i; i < count; ++i) {
            Generation memory g = bgGenerations[i];
            require(
                keccak256(abi.encode(Binding(target.owners[0]).bindingAt(1, i + 1)))
                        == keccak256(abi.encode(g.binding))
                    && keccak256(abi.encode(Terms(target.owners[0]).bindingTerms(1, i + 1)))
                        == keccak256(abi.encode(g.terms))
                    && keccak256(
                        abi.encode(Terminal(target.owners[0]).bindingTermination(1, i + 1))
                    ) == keccak256(abi.encode(g.terminal)),
                "all original binding bodies/empty collaborator terms/terminal tuples exact"
            );
            _bgOccurrence(target, 1, g.binding.bindingHash, g.proposal);
            _bgCell(
                target,
                0,
                "binding_lifecycle.replay.proposal_key",
                keccak256(abi.encode(uint256(1), i + 1)),
                g.binding.bindingHash,
                g.proposal.point
            );
            if (g.terminal.kind != 0) {
                bool refused = g.terminal.kind == 1;
                _bgCell(
                    target,
                    0,
                    refused
                        ? "binding_lifecycle.replay.refusal_uniqueness"
                        : "binding_lifecycle.replay.proposal_terminal_transition_key",
                    keccak256(abi.encode(uint256(1), i + 1)),
                    refused ? g.terminal.recordHash : g.binding.bindingHash,
                    g.terminalPoint
                );
                if (refused) _bgOccurrence(target, 3, g.terminal.recordHash, g.refusal);
                require(
                    Acceptance(target.owners[3]).acceptanceRecord(g.binding.bindingHash) == 0
                        && Acceptance(target.owners[3]).acceptedAt(g.binding.bindingHash) == 0,
                    "terminated generations never acquire acceptance"
                );
                require(
                    keccak256(Archive(bgOriginalArchive).artistEvidenceBytesV2(g.archiveId, 1))
                        == g.archiveHash,
                    "original refusal/withdrawal Archive evidence preserved"
                );
            }
        }
        T.Binding memory last = bgGenerations[count - 1].binding;
        require(
            last.accepted
                && keccak256(abi.encode(Binding(target.owners[0]).binding(1)))
                    == keccak256(abi.encode(last)),
            "exact final accepted generation is sole current head"
        );
        require(
            Acceptance(target.owners[3]).acceptanceRecord(last.bindingHash) == bgAcceptance
                && Acceptance(target.owners[3]).acceptedAt(last.bindingHash) == bgAcceptedAt,
            "original final acceptance and time retained"
        );
        _bgOccurrence(target, 2, bgAcceptance, bgAcceptancePosition);
        _bgCell(
            target,
            3,
            "acceptance_lifecycle.replay.record_uniqueness",
            keccak256(abi.encode(uint256(1), count, uint8(1), bgAcceptanceSigner)),
            bgAcceptance,
            bgAcceptancePosition.point
        );
        (uint8 state, uint64 generation) = Attribution(target.owners[4]).attributionState(1);
        require(
            state == 2 && generation == count
                && Native(target.owners[4]).artistNativeReceiptCount() == 0,
            "base Attribution remains accepted at actual final generation, never fabricated native history"
        );
        for (uint256 i; i < authCount; ++i) {
            Authorization memory a = bgAuthorizations[i];
            require(
                keccak256(Identity(target.owners[2]).signatureBundle(a.record))
                        == keccak256(a.value.signature)
                    && Identity(target.owners[2]).nonceUsed(artistId, a.value.nonce),
                "full original Safe signatures and principal nonces retained"
            );
            _bgCell(
                target,
                2,
                "identity_authority.replay.nonce_allocator",
                keccak256(abi.encode(artistId, a.value.nonce)),
                a.digest,
                a.point
            );
            _bgCell(
                target,
                2,
                "identity_authority.replay.authorization_consumed_digest",
                keccak256(abi.encode(artistId, a.digest)),
                a.digest,
                a.point
            );
        }
        for (uint256 i; i < policyCount; ++i) {
            Policy memory p = bgPolicies[i];
            require(
                Consent(target.owners[6]).policyRecord(1, p.terms.phaseId, p.terms.policyHash)
                    == p.record,
                "current generation policy map retained"
            );
            _bgOccurrence(target, 14, p.record, p.position);
            _bgCell(
                target,
                6,
                "consent_finality.replay.policy_consent_key",
                keccak256(abi.encode(uint256(1), p.terms.phaseId, p.terms.policyHash)),
                p.record,
                p.position.point
            );
        }
        require(
            Identity(target.owners[2]).identity(artistId).identityRecordHash
                == last.identityRecordHash,
            "immutable registration/binding identity stays separate from later document revision"
        );
        if (revision) {
            require(
                keccak256(
                        abi.encode(
                            Documents(target.registry).identityRevisionRecord(bgRevision.recordHash)
                        )
                    ) == keccak256(abi.encode(bgRevision))
                    && Documents(target.registry).operativeIdentityRecord(artistId)
                        == keccak256(bgDocument)
                    && keccak256(
                        Documents(target.registry).identityDocumentBytes(keccak256(bgDocument))
                    ) == keccak256(bgDocument),
                "entire fresh B25 original and operative document survive next import"
            );
            _bgOccurrence(target, 25, bgRevision.recordHash, bgRevisionPosition);
        }
    }

    function _bgPosition(uint8 owner, uint16 op, bytes32 record)
        private
        view
        returns (RH.Position memory p)
    {
        uint256 index = Native(suite.owners[owner]).artistNativeReceiptCount() - 1;
        H.Receipt memory row = Native(suite.owners[owner]).artistNativeReceiptAt(index);
        require(
            row.operation == op && row.recordHash == record && row.artistId == artistId
                && row.collectionId == (owner == 2 ? 0 : 1),
            "genuine original native occurrence"
        );
        p = RH.Position(
            RH.Point(
                RH.originHash(_bgOrigin(suite)),
                owner,
                NativeClock(suite.owners[owner]).artistNativeReceiptRevisionAt(index)
            ),
            index
        );
    }

    function _bgOccurrence(
        T.SuiteConfiguration memory target,
        uint16 op,
        bytes32 record,
        RH.Position memory p
    ) private view {
        uint8 owner = p.point.ownerIndex;
        (RH.OwnerProvenance memory prefix,,) =
            RecoveredOwner(target.owners[owner]).recoveredHydrationImportedPrefix();
        uint256 found;
        for (uint256 i; i < prefix.journal.length; ++i) {
            if (prefix.journal[i].receipt.recordHash == record) {
                require(
                    prefix.journal[i].receipt.operation == op
                        && keccak256(abi.encode(prefix.journal[i].position))
                            == keccak256(abi.encode(p)),
                    "original imported occurrence and ultimate coordinate exact"
                );
                ++found;
            }
        }
        for (uint256 i; i < Native(target.owners[owner]).artistNativeReceiptCount(); ++i) {
            if (Native(target.owners[owner]).artistNativeReceiptAt(i).recordHash == record) {
                require(
                    Native(target.owners[owner]).artistNativeReceiptAt(i).operation == op
                        && i == p.nativeIndex
                        && NativeClock(target.owners[owner]).artistNativeReceiptRevisionAt(i)
                            == p.point.ownerRevision
                        && RH.originHash(_bgOrigin(target)) == p.point.environmentHash,
                    "real current native occurrence"
                );
                ++found;
            }
        }
        require(found == 1, "exactly one original occurrence");
    }

    function _bgCell(
        T.SuiteConfiguration memory target,
        uint8 owner,
        string memory surface,
        bytes32 scope,
        bytes32 commitment,
        RH.Point memory point
    ) private view {
        bytes32 key = _bgKey(target, owner, surface, scope);
        T.ReplayCell memory cell = Owner(target.owners[owner]).replayCell(key);
        require(
            cell.kind == 1 && cell.status == 2 && cell.commitment == commitment
                && cell.touchedRevision == point.ownerRevision
                && keccak256(
                    abi.encode(
                        RecoveredOwner(target.owners[owner]).recoveredHydrationReplayPoint(key)
                    )
                ) == keccak256(abi.encode(point)),
            "original replay cell with separate actual source clock"
        );
    }

    function _bgSource(
        T.SuiteConfiguration memory target,
        uint256 authCount,
        uint256 policyCount,
        bool revision
    ) private view returns (bytes32 value) {
        value = _rhRecoveryFacts(target.owners[2]);
        for (uint8 i; i < 7; ++i) {
            value = keccak256(
                abi.encode(
                    value,
                    CP(target.owners[i]).authorityCheckpoint(),
                    Publications.collect(target.owners[i], i),
                    Guards.collectNonces(
                        target.owners[i], CP(target.owners[i]).authorityCheckpoint()
                    )
                )
            );
        }
        for (uint64 i = 1; i <= bgGenerations.length; ++i) {
            bytes32 hash = bgGenerations[i - 1].binding.bindingHash;
            value = keccak256(
                abi.encode(
                    value,
                    Binding(target.owners[0]).bindingAt(1, i),
                    Terms(target.owners[0]).bindingTerms(1, i),
                    Terminal(target.owners[0]).bindingTermination(1, i),
                    Acceptance(target.owners[3]).acceptanceRecord(hash),
                    Acceptance(target.owners[3]).acceptedAt(hash)
                )
            );
        }
        for (uint256 i; i < authCount; ++i) {
            value = keccak256(
                abi.encode(
                    value, Identity(target.owners[2]).signatureBundle(bgAuthorizations[i].record)
                )
            );
        }
        for (uint256 i; i < policyCount; ++i) {
            value = keccak256(
                abi.encode(
                    value,
                    Consent(target.owners[6])
                        .policyRecord(
                            1, bgPolicies[i].terms.phaseId, bgPolicies[i].terms.policyHash
                        )
                )
            );
        }
        if (revision) {
            value = keccak256(
                abi.encode(
                    value,
                    Documents(target.registry).identityRevisionRecord(bgRevision.recordHash),
                    Documents(target.registry).operativeIdentityRecord(artistId),
                    Documents(target.registry).identityDocumentBytes(bgRevision.revisedRecordHash)
                )
            );
        }
    }

    function _bgKey(
        T.SuiteConfiguration memory target,
        uint8 owner,
        string memory surface,
        bytes32 scope
    ) private view returns (bytes32) {
        return Guards.replayKey(
            _bgOrigin(target), owner, AH.Origin(keccak256(bytes(surface)), scope)
        );
    }

    function _bgOrigin(T.SuiteConfiguration memory target)
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
