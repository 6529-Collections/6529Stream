// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./ArtistOnboardingFixture.sol";
import "../../../smart-contracts/domains/artist/StreamArtistRoyaltyModeReads.sol";
import "../../../smart-contracts/domains/artist/StreamArtistOnboardingReadDeployment.sol";
import "../../../smart-contracts/interfaces/stream/artist/IStreamArtistSnapshotRoyaltyFacts.sol";
import "../../../smart-contracts/interfaces/stream/revenue/IStreamRoyaltySnapshot.sol";

/// @dev Actual Artist owners/Coordinator/Archive/Safe/RoyaltyResolver and split profiles.
///      Core, governance and corrective binding remain labelled unit read boundaries.
contract StreamArtistSnapshotRoyaltyConsentTest is ArtistOnboardingFixture {
    error ProviderUnavailable();
    bytes32 private constant ROYALTY = keccak256("ROYALTY_ERC2981");

    function testSnapshotSafeOp15BindsOriginalSourceElectionArchiveAndMintRead() public {
        _accept();
        _policy();
        _payout();
        _elect(2);
        (T.EconomicsConsent memory p, T.FixedEconomicsCandidate memory candidate) =
            _snapshotCandidate(600);
        T.Authorization memory a = _signedSnapshot(p);
        StreamArtistOnboardingReads reads = coordinator.reads();
        T.Binding memory binding_ = reads.acceptedBinding(1);
        T.Payout memory payout;
        (payout.account, payout.recordHash) = ingress.artistPayoutAccount(artistId);
        bytes32 expected = StreamArtistEconomicsHashes.economicsRecord(
            StreamArtistHashes.Environment(
                block.chainid, address(ingress), suite.core, suite.mintManager
            ),
            p,
            payout.recordHash,
            artistId,
            address(artist),
            a.nonce,
            uint64(block.timestamp)
        );
        IStreamRoyaltyResolver.RoyaltyConfig memory before_ = royalty.collectionRoyalty(1);
        vm.recordLogs();
        bytes32 record = ingress.recordProspectiveEconomicsConsent(p, candidate, a);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        require(
            record == expected
                && keccak256(abi.encode(royalty.collectionRoyalty(1)))
                    == keccak256(abi.encode(before_)),
            "original op15 does not install rights"
        );
        _associationEvent(logs, record, p, binding_, record);
        _snapshotArchive(p, candidate, a, binding_, payout, record);
        _installSnapshot(candidate);
        IStreamRoyaltySnapshot.Source memory source = royalty.currentRoyaltySnapshotSource(1);
        (T.AssignmentFact memory raw,) = royalty.royaltyEconomicsFacts(1, 1, 1);
        require(
            source.modeAssignmentHash == p.assignmentHash
                && source.sourceAssignmentHash == raw.assignmentHash
                && source.sourceAssignmentHash != p.assignmentHash,
            "raw source and signed mode remain distinct"
        );
        (T.AssignmentFact memory primaryFact, T.AssignmentFact memory royaltyFact) =
            reads.currentAssignments(1);
        require(royaltyFact.assignmentHash == p.assignmentHash, "mint observes mode authority");
        _economicsRecord(primaryFact);
        _ratify();
        _attestations();
        ingress.requireMintConsent(1, PHASE, POLICY);
        require(
            !royalty.royaltySnapshot(1).exists,
            "Artist consent does not fabricate a prepared token snapshot"
        );
    }

    function testDirectThresholdSafeCurrentSnapshotApprovalAvoidsConsentRecursion() public {
        _accept();
        _payout();
        _elect(2);
        StreamArtistOnboardingReads reads = coordinator.reads();
        (, T.AssignmentFact memory fact) = reads.currentAssignments(1);
        T.EconomicsConsent memory p = _snapshotTerms(fact);
        vm.expectRevert(
            abi.encodeWithSelector(T.MissingMintPrerequisite.selector, keccak256("economics"))
        );
        royalty.currentRoyaltySnapshotSource(1);
        T.Authorization memory a = _authorization(false);
        uint256 beforeNonce = artist.nonce();
        require(
            executeSafe(
                artist,
                keys,
                address(ingress),
                0,
                abi.encodeCall(IStreamArtistOnboarding.recordEconomicsConsent, (p, a)),
                0
            ),
            "actual direct Safe approval"
        );
        require(
            artist.nonce() == beforeNonce + 1
                && royalty.currentRoyaltySnapshotSource(1).modeAssignmentHash == p.assignmentHash,
            "original current transport approves elected source"
        );
        bytes32 roots = _roots();
        a = _signedSnapshot(p);
        avm.expectPartialRevert(T.Replay.selector);
        ingress.recordEconomicsConsent(p, a);
        require(_roots() == roots, "same original replay lane");
    }

    function testOldLiveConsentCannotAuthorizeSnapshotMintOrSetter() public {
        _all();
        StreamArtistOnboardingReads reads = coordinator.reads();
        (, T.AssignmentFact memory original) = reads.currentAssignments(1);
        ingress.requireMintConsent(1, PHASE, POLICY);
        _elect(2);
        vm.expectRevert(abi.encodeWithSelector(T.MissingMintPrerequisite.selector, ROYALTY));
        ingress.requireMintConsent(1, PHASE, POLICY);
        vm.expectRevert(
            abi.encodeWithSelector(T.MissingMintPrerequisite.selector, keccak256("economics"))
        );
        royalty.currentRoyaltySnapshotSource(1);
        IStreamRoyaltyResolver.RoyaltyConfig memory config = royalty.collectionRoyalty(1);
        address owner = royalty.owner();
        vm.expectRevert(
            abi.encodeWithSelector(T.MissingMintPrerequisite.selector, keccak256("economics"))
        );
        vm.prank(owner);
        royalty.configureCollectionRoyalty(1, config.profileId, config.royaltyBps);
        (, T.AssignmentFact memory elected) = reads.currentAssignments(1);
        require(elected.assignmentHash != original.assignmentHash, "new signed assignment");
        T.EconomicsConsent memory oldTerms = _snapshotTerms(original);
        T.Authorization memory oldAuth = _signedSnapshot(oldTerms);
        avm.expectRevert(T.InvalidRecord.selector);
        ingress.recordEconomicsConsent(oldTerms, oldAuth);
        _economicsRecord(elected);
        ingress.requireMintConsent(1, PHASE, POLICY);
    }

    function testImplicitAndExplicitLiveModePreserveOriginalFactsAndEvidence() public {
        _accept();
        _payout();
        StreamArtistOnboardingReads reads = coordinator.reads();
        (, T.AssignmentFact memory fact) = reads.currentAssignments(1);
        T.EconomicsConsent memory p = _snapshotTerms(fact);
        IStreamRoyaltyResolver.RoyaltyConfig memory config = royalty.collectionRoyalty(1);
        bytes memory expected =
            abi.encode(keccak256("6529STREAM_CURRENT_ROYALTY_ECONOMICS_EVIDENCE_V1"), fact, config);
        require(
            keccak256(reads.requireCurrentEconomics(p, address(artist))) == keccak256(expected),
            "implicit live evidence exact"
        );
        _elect(1);
        (uint8 mode, bytes32 election) = royalty.collectionRoyaltyMode(1);
        require(mode == 1 && election != 0, "explicit live election retained");
        (, T.AssignmentFact memory after_) = reads.currentAssignments(1);
        require(
            keccak256(abi.encode(after_)) == keccak256(abi.encode(fact))
                && keccak256(reads.requireCurrentEconomics(p, address(artist)))
                    == keccak256(expected),
            "explicit live original bytes"
        );
        _economicsRecord(fact);
        // An old provider's explicit capability absence remains the exact live route.
        avm.mockCall(
            address(royalty),
            abi.encodeCall(
                IERC165.supportsInterface, (type(IStreamArtistSnapshotRoyaltyFacts).interfaceId)
            ),
            abi.encode(false)
        );
        require(
            keccak256(reads.requireCurrentEconomics(p, address(artist))) == keccak256(expected),
            "unadvertised old route"
        );
        avm.clearMockedCalls();
    }

    function testAdvertisedSnapshotFailurePreservesNonceAndIdenticalSignedRetry() public {
        _accept();
        _payout();
        _elect(2);
        StreamArtistOnboardingReads reads = coordinator.reads();
        (T.EconomicsConsent memory p, T.FixedEconomicsCandidate memory candidate) =
            _snapshotCandidate(550);
        T.Authorization memory a = _signedSnapshot(p);
        bytes memory callData = abi.encodeCall(
            IStreamArtistSnapshotRoyaltyFacts.previewArtistSnapshotRoyaltyAssignment,
            (1, candidate.profileHash, candidate.royaltyBps, false)
        );
        bytes32 roots = _roots();
        avm.mockCallRevert(
            address(royalty), callData, abi.encodeWithSelector(ProviderUnavailable.selector)
        );
        avm.expectRevert(ProviderUnavailable.selector);
        ingress.recordProspectiveEconomicsConsent(p, candidate, a);
        require(
            _roots() == roots
                && !IStreamArtistIdentityOwner(suite.owners[2]).nonceUsed(artistId, a.nonce),
            "atomic provider failure"
        );
        avm.clearMockedCalls();
        ingress.recordProspectiveEconomicsConsent(p, candidate, a);
        _installSnapshot(candidate);
        callData = abi.encodeCall(
            IStreamArtistSnapshotRoyaltyFacts.currentArtistSnapshotRoyaltyAssignment, (1)
        );
        avm.mockCallRevert(
            address(royalty), callData, abi.encodeWithSelector(ProviderUnavailable.selector)
        );
        avm.expectRevert(ProviderUnavailable.selector);
        reads.currentAssignments(1);
        avm.clearMockedCalls();
        reads.requireCurrentEconomics(p, address(artist));
    }

    function testMalformedElectionModeAndForeignChainHashFailClosed() public {
        _accept();
        _payout();
        _elect(2);
        StreamArtistOnboardingReads reads = coordinator.reads();
        bytes memory callData =
            abi.encodeCall(IStreamArtistSnapshotRoyaltyFacts.collectionRoyaltyMode, (1));
        for (uint8 i; i < 4; ++i) {
            uint8 mode = i == 0 ? 3 : 2;
            bytes32 election = i == 1
                ? bytes32(0)
                : keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ROYALTY_MODE_ELECTION_V1"),
                        block.chainid + 1,
                        address(royalty),
                        suite.core,
                        uint256(1),
                        mode
                    )
                );
            if (i == 3) mode = 1;
            avm.mockCall(address(royalty), callData, abi.encode(mode, election));
            avm.expectRevert(T.InvalidRecord.selector);
            reads.currentAssignments(1);
        }
        avm.mockCallRevert(
            address(royalty), callData, abi.encodeWithSelector(ProviderUnavailable.selector)
        );
        avm.expectRevert(ProviderUnavailable.selector);
        reads.currentAssignments(1);
        avm.clearMockedCalls();
        reads.currentAssignments(1);
    }

    function testCurrentAndProspectiveModeHashMustBindExactRawSource() public {
        _accept();
        _payout();
        _elect(2);
        StreamArtistOnboardingReads reads = coordinator.reads();
        (T.EconomicsConsent memory p, T.FixedEconomicsCandidate memory candidate) =
            _snapshotCandidate(700);
        T.Authorization memory a = _signedSnapshot(p);
        T.AssignmentFact memory forged =
            T.AssignmentFact(address(royalty), ROYALTY, 1, 1, keccak256("other mode"));
        bytes memory previewCall = abi.encodeCall(
            IStreamArtistSnapshotRoyaltyFacts.previewArtistSnapshotRoyaltyAssignment,
            (1, candidate.profileHash, candidate.royaltyBps, false)
        );
        avm.mockCall(address(royalty), previewCall, abi.encode(forged));
        avm.expectRevert(T.InvalidRecord.selector);
        ingress.recordProspectiveEconomicsConsent(p, candidate, a);
        avm.clearMockedCalls();
        bytes memory rawCall = abi.encodeCall(
            IStreamArtistRoyaltyScopeFacts.previewArtistRoyaltyAssignmentForScope,
            (1, uint8(1), 1, candidate.profileHash, candidate.royaltyBps, false)
        );
        avm.mockCall(address(royalty), rawCall, abi.encode(forged));
        avm.expectRevert(T.InvalidRecord.selector);
        ingress.recordProspectiveEconomicsConsent(p, candidate, a);
        avm.clearMockedCalls();
        ingress.recordProspectiveEconomicsConsent(p, candidate, a);
        _installSnapshot(candidate);
        avm.mockCall(
            address(royalty),
            abi.encodeCall(
                IStreamArtistSnapshotRoyaltyFacts.currentArtistSnapshotRoyaltyAssignment, (1)
            ),
            abi.encode(forged)
        );
        avm.expectRevert(T.InvalidRecord.selector);
        reads.requireCurrentEconomics(p, address(artist));
        avm.clearMockedCalls();
        reads.requireCurrentEconomics(p, address(artist));
    }

    function testSnapshotTokenDefaultClearFreezeAndMixedZeroConsentAreExplicitlyClosed() public {
        _accept();
        _payout();
        _elect(2);
        StreamArtistOnboardingReads reads = coordinator.reads();
        (T.EconomicsConsent memory original, T.FixedEconomicsCandidate memory originalCandidate) =
            _snapshotCandidate(600);
        bytes32 roots = _roots();
        for (uint256 i; i < 6; ++i) {
            T.EconomicsConsent memory p = _snapshotTerms(
                T.AssignmentFact(address(royalty), ROYALTY, 1, 1, original.assignmentHash)
            );
            T.FixedEconomicsCandidate memory candidate =
                T.FixedEconomicsCandidate(originalCandidate.profileHash, 0, 600, false);
            if (i == 0) {
                p.scope = 2;
                p.scopeId = 9;
            }
            if (i == 1) {
                p.scope = 0;
                p.scopeId = 0;
            }
            if (i == 2) {
                p.assignmentHash = 0;
                candidate.profileHash = 0;
                candidate.royaltyBps = 0;
            }
            if (i == 3) candidate.frozen = true;
            if (i == 4) {
                candidate.profileHash = 0;
                candidate.royaltyBps = 600;
            }
            if (i == 5) candidate.royaltyBps = 1001;
            T.Authorization memory a = _signedSnapshot(p);
            avm.expectRevert(T.UnsupportedProfile.selector);
            ingress.recordProspectiveEconomicsConsent(p, candidate, a);
            require(
                _roots() == roots
                    && !IStreamArtistIdentityOwner(suite.owners[2]).nonceUsed(artistId, a.nonce),
                "closed shapes leave state exact"
            );
        }
        for (uint8 scope; scope < 3; scope += 2) {
            T.EconomicsConsent memory p = T.EconomicsConsent(
                1, address(royalty), ROYALTY, scope, scope == 0 ? 0 : 9, original.assignmentHash
            );
            avm.expectRevert(T.UnsupportedProfile.selector);
            reads.requireCurrentEconomics(p, address(artist));
        }
        ingress.recordProspectiveEconomicsConsent(
            original, originalCandidate, _signedSnapshot(original)
        );
    }

    function testOldFreezeAuthorizationCannotCrossSnapshotElection() public {
        _accept();
        _payout();
        StreamArtistOnboardingReads reads = coordinator.reads();
        T.RoyaltyFreeze memory proposal = _authorizeFreeze();
        require(
            reads.isRoyaltyFreezeAuthorized(1, proposal.expectedAssignmentHash),
            "original live freeze authorization"
        );
        _elect(2);
        require(
            !reads.isRoyaltyFreezeAuthorized(1, proposal.expectedAssignmentHash),
            "mode2 defensive freeze explicitly refused"
        );
        avm.expectRevert(T.UnsupportedProfile.selector);
        reads.currentRoyaltyAssignment(1);
        avm.expectRevert(T.UnsupportedProfile.selector);
        reads.requireRoyaltyFreezeProposal(proposal);
        address owner = royalty.owner();
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRoyaltySnapshot.RoyaltySnapshotMutationClosed.selector, uint256(1)
            )
        );
        vm.prank(owner);
        royalty.freezeCollectionRoyalty(1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRoyaltySnapshot.RoyaltySnapshotMutationClosed.selector, uint256(1)
            )
        );
        vm.prank(owner);
        royalty.clearCollectionRoyalty(1);
    }

    function testSnapshotPayoutDriftRejectsUnchangedSignedCandidateAndRetainsRetry() public {
        _accept();
        _payout();
        _elect(2);
        (T.EconomicsConsent memory p, T.FixedEconomicsCandidate memory candidate) =
            _snapshotCandidate(600);
        T.Authorization memory a = _signedSnapshot(p);
        _snapshotPayout(address(0xCAFE));
        bytes32 roots = _roots();
        avm.expectRevert(T.InvalidRecord.selector);
        ingress.recordProspectiveEconomicsConsent(p, candidate, a);
        require(
            _roots() == roots
                && !IStreamArtistIdentityOwner(suite.owners[2]).nonceUsed(artistId, a.nonce),
            "payout mismatch rollback"
        );
        _snapshotPayout(address(artist));
        ingress.recordProspectiveEconomicsConsent(p, candidate, a);
        _installSnapshot(candidate);
    }

    function testSnapshotBindingReplacementNeedsFreshOriginalAssociation() public {
        _accept();
        _payout();
        _elect(2);
        StreamArtistOnboardingReads reads = coordinator.reads();
        (T.EconomicsConsent memory p, T.FixedEconomicsCandidate memory candidate) =
            _snapshotCandidate(650);
        T.Binding memory originalBinding = reads.acceptedBinding(1);
        bytes32 original =
            ingress.recordProspectiveEconomicsConsent(p, candidate, _signedSnapshot(p));
        _installSnapshot(candidate);
        address originalPayout = address(artist);
        T.Binding memory next = _correctEconomicsBinding(originalPayout);
        vm.expectRevert(
            abi.encodeWithSelector(T.MissingMintPrerequisite.selector, keccak256("economics"))
        );
        royalty.currentRoyaltySnapshotSource(1);
        bytes32 fresh = ingress.recordProspectiveEconomicsConsent(p, candidate, _signedSnapshot(p));
        IStreamArtistEconomicsEvidence evidence = IStreamArtistEconomicsEvidence(suite.owners[6]);
        require(
            fresh != original
                && evidence.economicsRecordForBinding(
                    p,
                    originalBinding.artistId,
                    originalBinding.generation,
                    originalBinding.bindingHash
                ) == original
                && evidence.economicsRecordForBinding(
                    p, next.artistId, next.generation, next.bindingHash
                ) == fresh && evidence.economicsRecordAssociation(fresh).originalRecord == original,
            "exact current binding continuation"
        );
        require(
            royalty.currentRoyaltySnapshotSource(1).modeAssignmentHash == p.assignmentHash,
            "fresh current consent restores source"
        );
    }

    function testSnapshotCurrentEvidenceAndAllChangedArtistLibrariesFit() public {
        _accept();
        _payout();
        _elect(2);
        StreamArtistOnboardingReads reads = coordinator.reads();
        (, T.AssignmentFact memory fact) = reads.currentAssignments(1);
        (T.AssignmentFact memory raw, IStreamRoyaltyResolver.RoyaltyConfig memory config) =
            royalty.royaltyEconomicsFacts(1, 1, 1);
        (, bytes32 election) = royalty.collectionRoyaltyMode(1);
        require(
            keccak256(reads.requireCurrentEconomics(_snapshotTerms(fact), address(artist)))
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_CURRENT_SNAPSHOT_ROYALTY_ECONOMICS_EVIDENCE_V1"),
                        election,
                        raw,
                        fact,
                        config
                    )
                ),
            "full mode/source/config evidence"
        );
        require(
            address(reads).code.length <= 24576
                && address(StreamArtistOnboardingReadDeployment).code.length <= 24576
                && address(StreamArtistRoyaltyModeReads).code.length <= 24576
                && address(ingress).code.length <= 24576
                && address(coordinator).code.length <= 24576,
            "actual linked Artist product sizes"
        );
    }

    function testDisabledSnapshotSafeOp15PreservesOriginalArchiveAndAllMintPrerequisites() public {
        _accept(); _policy(); _payout(); _elect(2);
        _forbidDisabledProfileReads();
        (T.EconomicsConsent memory p, T.FixedEconomicsCandidate memory candidate) = _disabledSnapshotCandidate();
        T.Authorization memory a = _signedSnapshot(p);
        StreamArtistOnboardingReads reads = coordinator.reads();
        T.Binding memory binding_ = reads.acceptedBinding(1);
        T.Payout memory payout;
        (payout.account, payout.recordHash) = ingress.artistPayoutAccount(artistId);
        bytes32 expected = StreamArtistEconomicsHashes.economicsRecord(
            StreamArtistHashes.Environment(block.chainid, address(ingress), suite.core, suite.mintManager),
            p, payout.recordHash, artistId, address(artist), a.nonce, uint64(block.timestamp));
        IStreamRoyaltyResolver.RoyaltyConfig memory before_ = royalty.collectionRoyalty(1);
        vm.recordLogs();
        bytes32 record = ingress.recordProspectiveEconomicsConsent(p, candidate, a);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        require(record == expected && keccak256(abi.encode(royalty.collectionRoyalty(1))) == keccak256(abi.encode(before_)),
            "same original Safe op15 approves zero economics without installing them");
        _associationEvent(logs, record, p, binding_, record);
        _snapshotArchive(p, candidate, a, binding_, payout, record);
        _installSnapshot(candidate);
        IStreamRoyaltySnapshot.Source memory source = royalty.currentRoyaltySnapshotSource(1);
        require(source.config.configured && !source.config.frozen && source.config.profileId == 0
            && source.config.wallet == address(0) && source.config.royaltyBps == 0
            && source.sourceAssignmentHash != 0 && source.sourceRoyaltyPolicyHash != 0
            && source.modeAssignmentHash == p.assignmentHash && p.assignmentHash != source.sourceAssignmentHash,
            "disabled SET retains original nonzero source plus exact mode authority");
        (T.AssignmentFact memory primaryFact, T.AssignmentFact memory royaltyFact) = reads.currentAssignments(1);
        require(royaltyFact.assignmentHash == p.assignmentHash, "current Artist reads see zero mode consent");
        _economicsRecord(primaryFact); _ratify(); _attestations();
        ingress.requireMintConsent(1, PHASE, POLICY);
        require(!royalty.royaltySnapshot(1).exists, "Artist approval is not prepared Core proof");
        bytes32 roots = _roots();
        avm.expectPartialRevert(T.Replay.selector);
        ingress.recordProspectiveEconomicsConsent(p, candidate, a);
        require(_roots() == roots, "original authorization nonce still protects disabled consent");
        avm.clearMockedCalls();
    }

    function testDisabledSnapshotMissingPayoutRollsBackAndIdenticalSignedConsentRetries() public {
        _accept(); _elect(2);
        (T.EconomicsConsent memory p, T.FixedEconomicsCandidate memory candidate) = _disabledSnapshotCandidate();
        T.Authorization memory a = _signedSnapshot(p);
        bytes memory exact = abi.encodeCall(IStreamArtistEconomicsAuthority.recordProspectiveEconomicsConsent, (p, candidate, a));
        bytes32 roots = _roots();
        (bool ok, bytes memory why) = address(ingress).call(exact);
        require(!ok && keccak256(why) == keccak256(abi.encodeWithSelector(T.MissingMintPrerequisite.selector, keccak256("payout")))
            && _roots() == roots && !IStreamArtistIdentityOwner(suite.owners[2]).nonceUsed(artistId, a.nonce),
            "zero economics cannot bypass actual Artist payout designation");
        _payout();
        (ok,) = address(ingress).call(exact); require(ok, "identical original signed consent retries after actual prerequisite");
        _installSnapshot(candidate);
        T.Binding memory next = _correctEconomicsBinding(address(artist));
        vm.expectRevert(abi.encodeWithSelector(T.MissingMintPrerequisite.selector, keccak256("economics")));
        royalty.currentRoyaltySnapshotSource(1);
        bytes32 fresh = ingress.recordProspectiveEconomicsConsent(p, candidate, _signedSnapshot(p));
        require(IStreamArtistEconomicsEvidence(suite.owners[6]).economicsRecordForBinding(p, next.artistId, next.generation, next.bindingHash) == fresh
            && royalty.currentRoyaltySnapshotSource(1).modeAssignmentHash == p.assignmentHash,
            "disabled source retains exact current binding association requirement");
    }

    function testDefaultSnapshotCurrentSafeApprovalPreservesOriginalArchiveAndMintRead() public {
        _defaultSnapshotSetup(false, 500); _policy();
        StreamArtistOnboardingReads reads = coordinator.reads();
        (T.AssignmentFact memory primaryFact, T.AssignmentFact memory fact) = reads.currentAssignments(1);
        (T.AssignmentFact memory raw, IStreamRoyaltyResolver.RoyaltyConfig memory config) = royalty.royaltyEconomicsFacts(1, 0, 0);
        (, bytes32 election) = royalty.collectionRoyaltyMode(1);
        require(fact.scope == 1 && fact.scopeId == 1 && raw.scope == 0 && raw.scopeId == 0
            && fact.assignmentHash == keccak256(abi.encode(keccak256("6529STREAM_SNAPSHOT_ROYALTY_ASSIGNMENT_V1"),
                block.chainid, address(royalty), suite.core, uint256(1), election, raw.assignmentHash)),
            "current approval binds actual collection and original default key");
        T.EconomicsConsent memory p = _snapshotTerms(fact); T.Authorization memory a = _authorization(false);
        T.Binding memory binding_ = reads.acceptedBinding(1);
        (, bytes32 payoutRecord) = ingress.artistPayoutAccount(artistId);
        bytes32 expected = StreamArtistEconomicsHashes.economicsRecord(
            StreamArtistHashes.Environment(block.chainid, address(ingress), suite.core, suite.mintManager),
            p, payoutRecord, artistId, address(artist), a.nonce, uint64(block.timestamp));
        vm.recordLogs();
        require(executeSafe(artist, keys, address(ingress), 0,
            abi.encodeCall(IStreamArtistOnboarding.recordEconomicsConsent, (p, a)), 0), "original direct Artist Safe current approval");
        _associationEvent(vm.getRecordedLogs(), expected, p, binding_, expected);
        _assertRoyaltyCurrentArchive(p, a, expected, binding_, abi.encode(
            keccak256("6529STREAM_CURRENT_SNAPSHOT_ROYALTY_ECONOMICS_EVIDENCE_V1"), election, raw, fact, config));
        IStreamRoyaltySnapshot.Source memory source = royalty.currentRoyaltySnapshotSource(1);
        require(!royalty.collectionRoyalty(1).configured && source.sourceAssignmentHash == raw.assignmentHash
            && source.sourceRoyaltyPolicyHash == keccak256(abi.encode(keccak256("6529STREAM_ROYALTY_POLICY_V1"),
                block.chainid, address(royalty), uint256(0), uint256(0), config.profileId, config.wallet,
                config.royaltyBps, raw.assignmentHash)), "default approval never installs an override or changes canonical source policy");
        _economicsRecord(primaryFact); _ratify(); _attestations(); ingress.requireMintConsent(1, PHASE, POLICY);
        T.FixedEconomicsCandidate memory candidate = T.FixedEconomicsCandidate(config.profileId, 0, config.royaltyBps, false);
        T.Authorization memory wrong = _signedSnapshot(p);
        avm.expectRevert(T.InvalidRecord.selector); ingress.recordProspectiveEconomicsConsent(p, candidate, wrong);
        address owner = royalty.owner();
        vm.expectRevert(abi.encodeWithSelector(T.MissingMintPrerequisite.selector, keccak256("economics")));
        vm.prank(owner); royalty.configureCollectionRoyalty(1, config.profileId, config.royaltyBps);
    }

    function testDefaultSnapshotPayoutFailurePreservesIdenticalSignedSafeRetry() public {
        _defaultSnapshotSetup(false, 500);
        StreamArtistOnboardingReads reads = coordinator.reads();
        (, T.AssignmentFact memory fact) = reads.currentAssignments(1);
        T.EconomicsConsent memory p = _snapshotTerms(fact); T.Authorization memory a = _signedSnapshot(p);
        bytes memory data = abi.encodeCall(IStreamArtistOnboarding.recordEconomicsConsent, (p, a));
        uint256 nonce = artist.nonce();
        bytes32 digest = artist.getTransactionHash(address(ingress), 0, data, 0, 0, 0, 0, address(0), address(0), nonce);
        bytes memory exact = abi.encodeCall(artist.execTransaction,
            (address(ingress), 0, data, 0, 0, 0, 0, address(0), payable(address(0)), safeThresholdSignature(keys, digest)));
        _snapshotPayout(address(0xCAFE)); bytes32 roots = _roots();
        (bool ok,) = address(artist).call(exact);
        require(!ok && artist.nonce() == nonce && _roots() == roots
            && !IStreamArtistIdentityOwner(suite.owners[2]).nonceUsed(artistId, a.nonce), "payout mismatch rolls back original current-consent lanes");
        _snapshotPayout(address(artist)); (ok,) = address(artist).call(exact);
        require(ok && artist.nonce() == nonce + 1 && royalty.currentRoyaltySnapshotSource(1).modeAssignmentHash == p.assignmentHash,
            "same signed Safe transaction and op15 payload retry after actual payout repair");
        vm.prank(royalty.owner()); royalty.freezeDefaultRoyalty();
        vm.expectRevert(abi.encodeWithSelector(T.MissingMintPrerequisite.selector, keccak256("economics")));
        royalty.currentRoyaltySnapshotSource(1);
        (, fact) = reads.currentAssignments(1); require(fact.assignmentHash != p.assignmentHash, "default freeze changes mode-bound approval");
        _economicsRecord(fact); require(royalty.currentRoyaltySnapshotSource(1).config.frozen, "current approval accepts original frozen default");
    }

    function testDisabledDefaultSnapshotCurrentApprovalRetainsPayoutAndZeroHashDistinction() public {
        _defaultSnapshotSetup(true, 0); _forbidDisabledProfileReads();
        StreamArtistOnboardingReads reads = coordinator.reads();
        (, T.AssignmentFact memory fact) = reads.currentAssignments(1);
        (T.AssignmentFact memory raw,) = royalty.royaltyEconomicsFacts(1, 0, 0);
        require(raw.assignmentHash != 0 && fact.assignmentHash != 0 && raw.assignmentHash != fact.assignmentHash
            && !royalty.collectionRoyalty(1).configured, "frozen disabled default is configured source, never clear result");
        _economicsRecord(fact);
        IStreamRoyaltySnapshot.Source memory source = royalty.currentRoyaltySnapshotSource(1);
        require(source.config.configured && source.config.frozen && source.config.wallet == address(0)
            && source.config.royaltyBps == 0 && source.config.profileId == 0 && source.sourceAssignmentHash == raw.assignmentHash,
            "original zero source needs no invented profile observations");
    }

    function _defaultSnapshotSetup(bool frozen, uint16 bps) private {
        _accept(); _payout();
        bytes32 profile = royalty.collectionRoyalty(1).profileId;
        _clearRoyalty(1, 1);
        vm.prank(royalty.owner()); royalty.configureDefaultRoyalty(bps == 0 ? bytes32(0) : profile, bps);
        if (frozen) { vm.prank(royalty.owner()); royalty.freezeDefaultRoyalty(); }
        _elect(2);
    }

    function _disabledSnapshotCandidate()
        private view returns (T.EconomicsConsent memory p, T.FixedEconomicsCandidate memory candidate)
    {
        candidate = T.FixedEconomicsCandidate(0, 0, 0, false);
        T.AssignmentFact memory raw = royalty.previewArtistRoyaltyAssignmentForScope(1, 1, 1, 0, 0, false);
        T.AssignmentFact memory fact = royalty.previewArtistSnapshotRoyaltyAssignment(1, 0, 0, false);
        (, bytes32 election) = royalty.collectionRoyaltyMode(1);
        require(raw.assignmentHash != 0 && fact.assignmentHash == keccak256(abi.encode(
            keccak256("6529STREAM_SNAPSHOT_ROYALTY_ASSIGNMENT_V1"), block.chainid, address(royalty), suite.core,
            uint256(1), election, raw.assignmentHash)), "disabled is an original configured source plus signed mode, never clear-zero");
        p = _snapshotTerms(fact);
    }

    function _forbidDisabledProfileReads() private {
        bytes memory reason = abi.encodeWithSelector(ProviderUnavailable.selector);
        IStreamSplitFactory selected = royalty.splitFactory();
        avm.mockCallRevert(address(selected), abi.encodeCall(selected.splitWalletExists, (bytes32(0))), reason);
        avm.mockCallRevert(address(selected), abi.encodeCall(selected.walletFor, (bytes32(0))), reason);
        avm.mockCallRevert(address(selected), abi.encodeCall(selected.profileEntriesHash, (bytes32(0))), reason);
        avm.mockCallRevert(address(selected), abi.encodeCall(selected.profileMetadataURIHash, (bytes32(0))), reason);
    }

    function _elect(uint8 mode) private {
        // This unit Core historically models a minted item. Only the pre-mint election
        // read is explicitly supplied; this is not actual Core lifecycle evidence.
        avm.mockCall(
            suite.core,
            abi.encodeCall(IStreamCoreCollectionView.collectionNextSerial, (1)),
            abi.encode(uint256(1))
        );
        vm.prank(royalty.owner());
        royalty.electCollectionRoyaltyMode(1, mode);
        avm.clearMockedCalls();
        (uint8 actual, bytes32 election) = royalty.collectionRoyaltyMode(1);
        require(
            actual == mode
                && election
                    == keccak256(
                        abi.encode(
                            keccak256("6529STREAM_ROYALTY_MODE_ELECTION_V1"),
                            block.chainid,
                            address(royalty),
                            suite.core,
                            uint256(1),
                            mode
                        )
                    ),
            "exact retained election"
        );
    }

    function _snapshotCandidate(uint16 bps)
        private
        returns (T.EconomicsConsent memory p, T.FixedEconomicsCandidate memory candidate)
    {
        (, candidate) = _candidate(address(royalty), address(artist), bps, false);
        T.AssignmentFact memory fact =
            royalty.previewArtistSnapshotRoyaltyAssignment(1, candidate.profileHash, bps, false);
        (T.AssignmentFact memory raw) = royalty.previewArtistRoyaltyAssignmentForScope(
            1, 1, 1, candidate.profileHash, bps, false
        );
        (, bytes32 election) = royalty.collectionRoyaltyMode(1);
        require(
            fact.assignmentHash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_SNAPSHOT_ROYALTY_ASSIGNMENT_V1"),
                        block.chainid,
                        address(royalty),
                        suite.core,
                        uint256(1),
                        election,
                        raw.assignmentHash
                    )
                ),
            "independent mode preimage"
        );
        p = _snapshotTerms(fact);
    }

    function _snapshotTerms(T.AssignmentFact memory fact)
        private
        pure
        returns (T.EconomicsConsent memory)
    {
        return T.EconomicsConsent(
            1, fact.resolver, fact.revenueClass, fact.scope, fact.scopeId, fact.assignmentHash
        );
    }

    function _signedSnapshot(T.EconomicsConsent memory p)
        private
        returns (T.Authorization memory a)
    {
        a = _authorization(false);
        a.signature = _signature(ingress.economicsConsentDigest(p, a));
    }

    function _installSnapshot(T.FixedEconomicsCandidate memory candidate) private {
        vm.prank(royalty.owner());
        royalty.configureCollectionRoyalty(1, candidate.profileHash, candidate.royaltyBps);
    }

    function _snapshotPayout(address account) private {
        (, bytes32 previous) = ingress.artistPayoutAccount(artistId);
        T.PayoutDesignation memory p = T.PayoutDesignation(artistId, account, previous);
        T.Authorization memory a = _authorization(true);
        a.signature = _signature(ingress.payoutDesignationDigest(p, a));
        ingress.recordPayoutDesignation(p, a);
    }

    function _snapshotArchive(
        T.EconomicsConsent memory p,
        T.FixedEconomicsCandidate memory candidate,
        T.Authorization memory a,
        T.Binding memory binding_,
        T.Payout memory payout,
        bytes32 record
    ) private view {
        bytes32 id = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"),
                block.chainid,
                address(ingress),
                address(coordinator),
                uint16(15),
                address(this),
                record
            )
        );
        (
            uint16 schema,
            bytes32 config,
            uint16 op,
            address actor,
            bytes32 saved,,,
            bytes memory payload
        ) = abi.decode(
            archive.artistEvidenceBytesV2(id, 1),
            (uint16, bytes32, uint16, address, bytes32, T.Snapshot[7], T.Snapshot[7], bytes)
        );
        require(
            schema == 1 && config == coordinator.configurationHash() && op == 15
                && actor == address(this) && saved == record,
            "original archive envelope"
        );
        T.AssignmentFact memory fact =
            T.AssignmentFact(p.resolver, p.revenueClass, p.scope, p.scopeId, p.assignmentHash);
        T.SignerApproval memory proof =
            T.SignerApproval(address(artist), ingress.economicsConsentDigest(p, a), false);
        IStreamArtistEconomicsEvidence.Association memory association =
            IStreamArtistEconomicsEvidence(suite.owners[6]).economicsRecordAssociation(record);
        require(
            keccak256(payload)
                == keccak256(
                    abi.encode(
                        binding_,
                        p,
                        payout,
                        a,
                        proof,
                        abi.encode(candidate, fact, bytes32(0)),
                        association
                    )
                ),
            "original op15 transport with exact signed mode fact"
        );
    }
}
