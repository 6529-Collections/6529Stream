// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistEconomicsAuthorityHydration.t.sol";
import {
    IStreamRoyaltySnapshot
} from "../../../smart-contracts/interfaces/stream/revenue/IStreamRoyaltySnapshot.sol";
import {
    StreamRevenueArtistSelection,
    IStreamRevenueArtistConfiguration
} from "../../../smart-contracts/domains/revenue/StreamRevenueArtistSelection.sol";
import {
    StreamPrimaryIdentityReads
} from "../../../smart-contracts/domains/revenue/StreamPrimaryIdentityReads.sol";

/// @notice Actual two Artist suites, original Resolvers, op60, Archive and threshold Safe.
/// @dev Retains the original typed Core/governance fixture boundary. Adverse mocks
/// change a single observed proof word after genuine hydration; no positive import is mocked.
contract StreamArtistResolverSuccessorTest is StreamArtistEconomicsAuthorityHydrationTest {
    function _completed()
        private
        returns (StreamArtistOnboardingRegistry current, T.SuiteConfiguration memory s)
    {
        // Existing body remains unchanged, including original evidence and fresh Safe consent.
        this.testEconomicsHydrationPreservesBothResolverApprovalsAndFreshSafeConsent();
        current = StreamArtistOnboardingRegistry(core.targets(keccak256("ARTIST_REGISTRY")));
        s = StreamArtistOnboardingCoordinator(current.operationCoordinator()).suiteConfiguration();
        require(address(current) != address(ingress), "real successor");
    }

    function _bothReadable() private view {
        require(primary.resolvePrimaryAssignment(1, 0, PRIMARY).exists, "current primary");
        (T.AssignmentFact memory fact,) = royalty.royaltyEconomicsFacts(1, 1, 1);
        require(fact.assignmentHash != 0, "current royalty");
    }

    function _bothRejected(address current) private {
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRevenueResolver.InvalidPrimaryArtistRegistry.selector, current
            )
        );
        primary.resolvePrimaryAssignment(1, 0, PRIMARY);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamRoyaltyResolver.InvalidArtistRegistryBinding.selector, current
            )
        );
        royalty.royaltyEconomicsFacts(1, 1, 1);
    }

    function testSuccessorResolversRetainOriginalIdentityHashesAndApprovedOwnerMutations()
        external
    {
        bytes32 primaryHash = primary.resolvePrimaryAssignment(1, 0, PRIMARY).assignmentHash;
        (T.AssignmentFact memory oldRoyalty, IStreamRoyaltyResolver.RoyaltyConfig memory terms) =
            royalty.royaltyEconomicsFacts(1, 1, 1);
        _completed();
        require(
            primary.artistRegistry() == address(ingress)
                && address(royalty.artistRegistry()) == address(ingress),
            "origin immutables retained"
        );
        require(
            primary.resolvePrimaryAssignment(1, 0, PRIMARY).assignmentHash == primaryHash,
            "primary preimage retained"
        );
        (T.AssignmentFact memory nowRoyalty,) = royalty.royaltyEconomicsFacts(1, 1, 1);
        require(
            keccak256(abi.encode(oldRoyalty)) == keccak256(abi.encode(nowRoyalty)),
            "whole royalty fact retained"
        );
        IStreamRevenueResolver.ResolvedPrimaryAssignment memory original =
            primary.resolvePrimaryAssignment(1, 0, PRIMARY);
        vm.prank(primary.owner());
        primary.setPrimaryProfileAssignment(PRIMARY, 1, 1, original.profileId, 0);
        vm.prank(royalty.owner());
        royalty.configureCollectionRoyalty(1, terms.profileId, terms.royaltyBps);
        _bothReadable();
    }

    function testSuccessorResolversRejectAnUnrelatedActualResolverInTheSelectedSuite() external {
        (StreamArtistOnboardingRegistry current,) = _completed();
        StreamRevenueResolver otherPrimary = new StreamRevenueResolver(
            IStreamCore(address(core)),
            factory,
            primary.owner(),
            IStreamArtistAttribution(address(ingress)),
            IStreamGasParameterHost.GasParameterConfig(
                "ARTIST_BENEFICIARY_READ_GAS", 200000, 50000, 2
            )
        );
        StreamRoyaltyResolver otherRoyalty = new StreamRoyaltyResolver(
            IStreamCore(address(core)),
            factory,
            royalty.owner(),
            IStreamArtistAttribution(address(ingress))
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRevenueResolver.InvalidPrimaryArtistRegistry.selector, address(current)
            )
        );
        otherPrimary.resolvePrimaryAssignment(1, 0, PRIMARY);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamRoyaltyResolver.InvalidArtistRegistryBinding.selector, address(current)
            )
        );
        otherRoyalty.royaltyEconomicsFacts(1, 1, 1);
        _bothReadable();
    }

    function testSuccessorResolversRequireEveryEqualNonzeroOwnerCompletion() external {
        (StreamArtistOnboardingRegistry current, T.SuiteConfiguration memory s) = _completed();
        for (uint256 i; i < 7; ++i) {
            bytes memory callData = abi.encodeCall(HydrationOwner.authorityHydrationCommitment, ());
            avm.mockCall(s.owners[i], callData, abi.encode(bytes32(0)));
            _bothRejected(address(current));
            avm.mockCall(s.owners[i], callData, abi.encode(keccak256("different completion")));
            _bothRejected(address(current));
            avm.clearMockedCalls();
            _bothReadable();
        }
    }

    function testSuccessorResolversRejectMalformedLineageAndChangedConstructorCommitment()
        external
    {
        (StreamArtistOnboardingRegistry current,) = _completed();
        bytes memory countCall = abi.encodeCall(History.importedHistoryBindingCount, ());
        avm.mockCall(address(current), countCall, abi.encode(uint256(2)));
        _bothRejected(address(current));
        avm.mockCall(address(current), countCall, hex"01");
        _bothRejected(address(current));
        avm.clearMockedCalls();
        address target = current.operationCoordinator();
        bytes memory configCall =
            abi.encodeCall(IStreamRevenueArtistConfiguration.configurationHash, ());
        avm.mockCall(target, configCall, abi.encode(keccak256("not constructor commitment")));
        _bothRejected(address(current));
        avm.mockCall(target, configCall, hex"01");
        _bothRejected(address(current));
        avm.clearMockedCalls();
        _bothReadable();
    }

    function testSuccessorRoyaltyFreshApprovalUsesExactSafeRetryAndOriginalOwnerSet() external {
        (StreamArtistOnboardingRegistry current, T.SuiteConfiguration memory s) = _completed();
        (T.EconomicsConsent memory p, T.FixedEconomicsCandidate memory candidate) =
            _candidate(address(royalty), address(artist), 550, false);
        T.Authorization memory a = T.Authorization(
            IStreamArtistIdentityOwner(s.owners[2]).identity(artistId).nonceHint,
            uint64(block.timestamp),
            ""
        );
        bytes memory data = abi.encodeCall(
            IStreamArtistEconomicsAuthority.recordProspectiveEconomicsConsent, (p, candidate, a)
        );
        uint256 nonce = artist.nonce();
        bytes32 digest = artist.getTransactionHash(
            address(current), 0, data, 0, 0, 0, 0, address(0), address(0), nonce
        );
        bytes memory signatures = safeThresholdSignature(keys, digest);
        avm.mockCall(
            s.owners[0],
            abi.encodeCall(HydrationOwner.authorityHydrationCommitment, ()),
            abi.encode(bytes32(0))
        );
        vm.expectRevert(bytes("GS013"));
        artist.execTransaction(
            address(current), 0, data, 0, 0, 0, 0, address(0), payable(address(0)), signatures
        );
        require(
            artist.nonce() == nonce
                && IStreamArtistConsentOwner(s.owners[6]).economicsRecord(p) == 0,
            "failed approval rolled back"
        );
        avm.clearMockedCalls();
        require(
            artist.execTransaction(
                address(current), 0, data, 0, 0, 0, 0, address(0), payable(address(0)), signatures
            ),
            "identical signed Safe retry"
        );
        require(
            artist.nonce() == nonce + 1
                && IStreamArtistConsentOwner(s.owners[6]).economicsRecord(p) != 0,
            "current record consumed once"
        );
        require(
            IStreamArtistConsentOwner(suite.owners[6]).economicsRecord(p) == 0,
            "predecessor record untouched"
        );
        vm.prank(royalty.owner());
        royalty.configureCollectionRoyalty(1, candidate.profileHash, candidate.royaltyBps);
        (T.AssignmentFact memory currentFact,) = royalty.royaltyEconomicsFacts(1, 1, 1);
        require(currentFact.assignmentHash == p.assignmentHash, "original exact configured hash");
        (bool replay,) = address(artist)
            .call(
                abi.encodeCall(
                    OfficialSafe.execTransaction,
                    (
                        address(current),
                        0,
                        data,
                        0,
                        0,
                        0,
                        0,
                        address(0),
                        payable(address(0)),
                        signatures
                    )
                )
            );
        require(
            !replay && artist.nonce() == nonce + 1, "original signed Safe transaction cannot replay"
        );
    }

    function testSuccessorCollectionTemplateUsesCurrentPayoutAndStoredDisclosureStaysIndependent()
        external
    {
        (StreamArtistOnboardingRegistry current, T.SuiteConfiguration memory s) = _completed();
        address payout = address(0xCAFE1234);
        (, bytes32 priorPayout) = current.artistPayoutAccount(artistId);
        T.PayoutDesignation memory change = T.PayoutDesignation(artistId, payout, priorPayout);
        T.Authorization memory a = T.Authorization(
            IStreamArtistIdentityOwner(s.owners[2]).identity(artistId).nonceHint,
            uint64(block.timestamp),
            ""
        );
        require(
            this.executeTargetSafe(
                address(current),
                abi.encodeCall(IStreamArtistOnboarding.recordPayoutDesignation, (change, a))
            ),
            "actual successor payout"
        );
        IStreamRevenueResolver.PrimaryTemplateEntry[] memory entries =
            new IStreamRevenueResolver.PrimaryTemplateEntry[](1);
        entries[0] = IStreamRevenueResolver.PrimaryTemplateEntry(
            address(0), keccak256("COLLECTION_ARTIST"), 1000000, keccak256("artist")
        );
        vm.prank(primary.owner());
        bytes32 templateId =
            primary.createPrimaryTemplate(entries, keccak256("successor payout template"));
        (bytes32 profile,,) =
            primary.materializeCollectionPrimaryProfile(templateId, 1, address(0xB0B), true);
        IStreamSplitWallet.SplitEntry[] memory expected = new IStreamSplitWallet.SplitEntry[](1);
        expected[0] = IStreamSplitWallet.SplitEntry(payout, 1000000, keccak256("artist"));
        (bytes32 expectedProfile,) = factory.createProfile(expected, bytes32(0));
        // Template materialization owns metadata, so compare canonical entries as well as payout.
        require(
            factory.profileEntriesHash(profile) == factory.profileEntriesHash(expectedProfile),
            "current payout rather than predecessor"
        );
        IStreamRoyaltyResolver.RoyaltyConfig memory saved = royalty.collectionRoyalty(1);
        core.set(keccak256("ARTIST_REGISTRY"), address(primary), false);
        _bothRejected(address(primary));
        require(
            keccak256(abi.encode(royalty.collectionRoyalty(1))) == keccak256(abi.encode(saved)),
            "stored royalties survive unavailable current authority"
        );
        entries[0] = IStreamRevenueResolver.PrimaryTemplateEntry(
            address(0xB0B), 0, 1000000, keccak256("static")
        );
        vm.prank(primary.owner());
        templateId = primary.createPrimaryTemplate(entries, keccak256("context free"));
        (profile,,) = primary.materializePrimaryProfile(templateId, address(0xB0B));
        require(profile != 0, "old context-free route independent");
    }

    function testSuccessorSnapshotSourceRequiresItsOwnModeBoundConsent() external {
        (StreamArtistOnboardingRegistry current, T.SuiteConfiguration memory s) = _completed();
        (T.AssignmentFact memory original,) = royalty.royaltyEconomicsFacts(1, 1, 1);
        // Only the already explicit typed Core's pre-mint coordinate is supplied;
        // all election, source hashing, current Artist approval and reads are real.
        avm.mockCall(
            address(core),
            abi.encodeWithSignature("collectionNextSerial(uint256)", uint256(1)),
            abi.encode(uint256(1))
        );
        vm.prank(royalty.owner());
        royalty.electCollectionRoyaltyMode(1, 2);
        avm.clearMockedCalls();
        T.AssignmentFact memory fact = royalty.currentArtistSnapshotRoyaltyAssignment(1);
        require(fact.assignmentHash != original.assignmentHash, "mode wrapper is distinct");
        (bool beforeConsent,) = address(royalty)
            .staticcall(abi.encodeCall(IStreamRoyaltySnapshot.currentRoyaltySnapshotSource, (1)));
        require(!beforeConsent, "old live approval cannot approve snapshot mode");
        T.EconomicsConsent memory p =
            T.EconomicsConsent(1, address(royalty), fact.revenueClass, 1, 1, fact.assignmentHash);
        T.Authorization memory a = T.Authorization(
            IStreamArtistIdentityOwner(s.owners[2]).identity(artistId).nonceHint,
            uint64(block.timestamp),
            ""
        );
        require(
            this.executeTargetSafe(
                address(current),
                abi.encodeCall(IStreamArtistOnboarding.recordEconomicsConsent, (p, a))
            ),
            "real successor mode approval"
        );
        IStreamRoyaltySnapshot.Source memory source = royalty.currentRoyaltySnapshotSource(1);
        require(
            source.sourceAssignmentHash == original.assignmentHash
                && source.modeAssignmentHash == fact.assignmentHash,
            "original source and current mode consent joined"
        );
        avm.mockCall(
            s.owners[6],
            abi.encodeCall(HydrationOwner.authorityHydrationCommitment, ()),
            abi.encode(bytes32(0))
        );
        avm.expectRevert(IStreamRoyaltySnapshot.InvalidRoyaltySnapshot.selector);
        royalty.currentRoyaltySnapshotSource(1);
        avm.clearMockedCalls();
        require(
            keccak256(abi.encode(royalty.currentRoyaltySnapshotSource(1)))
                == keccak256(abi.encode(source)),
            "unchanged exact source after proof repair"
        );
    }

    function testSuccessorProofReadsWithColdNamedTargetsAndClippedGovernedCeiling() external {
        (StreamArtistOnboardingRegistry current, T.SuiteConfiguration memory s) = _completed();
        address[9] memory extra = [
            address(core),
            address(ingress),
            address(current),
            current.operationCoordinator(),
            address(primary),
            address(royalty),
            address(factory),
            address(StreamRevenueArtistSelection),
            address(StreamPrimaryIdentityReads)
        ];
        for (uint256 i; i < 7; ++i) {
            safeVm.cool(s.owners[i]);
        }
        for (uint256 i; i < extra.length; ++i) {
            safeVm.cool(extra[i]);
        }
        // This is a concrete named-target cold control, not every linked descendant
        // or a transaction-capacity claim. The origin ceiling is 2m per read.
        (bool ok, bytes memory data) = address(primary).staticcall{ gas: 1500000 }(
            abi.encodeCall(IStreamRevenueResolver.resolvePrimaryAssignment, (1, 0, PRIMARY))
        );
        require(
            ok && abi.decode(data, (IStreamRevenueResolver.ResolvedPrimaryAssignment)).exists,
            "success below full per-read ceiling"
        );
        for (uint256 i; i < 7; ++i) {
            safeVm.cool(s.owners[i]);
        }
        for (uint256 i; i < extra.length; ++i) {
            safeVm.cool(extra[i]);
        }
        (ok, data) = address(royalty).staticcall{ gas: 1500000 }(
            abi.encodeCall(IStreamArtistRoyaltyScopeFacts.royaltyEconomicsFacts, (1, 1, 1))
        );
        require(ok && data.length != 0, "cold royalty current read");
    }
}
