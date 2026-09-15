// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistPlatformWorks.t.sol";
import "../../../smart-contracts/interfaces/stream/artist/IStreamArtistSnapshotRoyaltyFacts.sol";

/// @dev Reuses the exact real Artist/Safe/declaration/claim/correction recipes above.
///      Unit Core pre-mint serial remains explicit; actual prepared proof is in the current suite.
contract StreamArtistPlatformRoyaltySnapshotTest is StreamArtistPlatformWorksTest {
    error UnexpectedPlatformEconomicsConsent();

    function _platformElection() private {
        avm.mockCall(
            suite.core,
            abi.encodeCall(IStreamCoreCollectionView.collectionNextSerial, (uint256(2))),
            abi.encode(uint256(1))
        );
        address owner = royalty.owner();
        vm.prank(owner);
        royalty.electCollectionRoyaltyMode(2, 2);
        avm.clearMockedCalls();
    }

    function testDeclaredPlatformDefaultPositiveAndDisabledSnapshotsNeedNoArtistOp15() public {
        bytes32 declaration = ingress.declarePlatformWorks(2, keccak256("platform royalty terms"));
        bytes32 profile = royalty.collectionRoyalty(1).profileId;
        address owner = royalty.owner();
        vm.prank(owner);
        royalty.configureDefaultRoyalty(profile, 350);
        _platformElection();
        avm.mockCallRevert(
            address(ingress),
            abi.encodeWithSelector(
                IStreamArtistEconomicsAuthority.requireEconomicsConsent.selector
            ),
            abi.encodeWithSelector(UnexpectedPlatformEconomicsConsent.selector)
        );
        IStreamRoyaltySnapshot.Source memory source = royalty.currentRoyaltySnapshotSource(2);
        (T.AssignmentFact memory raw,) = royalty.royaltyEconomicsFacts(2, 0, 0);
        require(
            source.sourceAssignmentHash == raw.assignmentHash && raw.scope == 0 && raw.scopeId == 0
                && source.config.royaltyBps == 350
                && ingress.platformWorksState(2).declaration.recordHash == declaration,
            "real declaration and canonical default source; no synthetic op15"
        );
        vm.prank(owner);
        royalty.configureCollectionRoyalty(2, profile, 450);
        source = royalty.currentRoyaltySnapshotSource(2);
        (raw,) = royalty.royaltyEconomicsFacts(2, 1, 2);
        require(
            source.sourceAssignmentHash == raw.assignmentHash && source.config.royaltyBps == 450,
            "real owner installs positive collection override"
        );
        vm.prank(owner);
        royalty.configureCollectionRoyalty(2, bytes32(0), 0);
        source = royalty.currentRoyaltySnapshotSource(2);
        require(
            source.config.configured && source.config.profileId == 0
                && source.config.wallet == address(0) && source.config.royaltyBps == 0
                && source.sourceAssignmentHash != 0 && source.sourceRoyaltyPolicyHash != 0,
            "configured disabled suppresses default and retains canonical hashes"
        );
        require(
            ingress.consentMode(2) == 3 && ingress.acceptedArtist(2) == address(0),
            "no Artist fabricated"
        );
        avm.clearMockedCalls();
    }

    function testActualSustainedPlatformCannotUseValidSnapshotDefault() public {
        // Original staged op11, real claim evidence and append-only sustained history.
        testGovernedContestStopsMintDismissalResumesAndSustainedIsPermanent();
        bytes32 profile = royalty.collectionRoyalty(1).profileId;
        address owner = royalty.owner();
        vm.prank(owner);
        royalty.configureDefaultRoyalty(profile, 350);
        _platformElection();
        require(
            royalty.defaultRoyalty().configured && ingress.platformWorksState(2).contestState == 3,
            "valid configured economics with actual sustained state"
        );
        vm.expectRevert(
            abi.encodeWithSelector(IStreamRoyaltySnapshot.InvalidRoyaltySnapshot.selector)
        );
        royalty.currentRoyaltySnapshotSource(2);
        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamRoyaltySnapshot.InvalidRoyaltySnapshot.selector)
        );
        royalty.configureCollectionRoyalty(2, profile, 350);
    }

    function testActualCorrectiveSafeBindingRequiresFreshModeBoundRoyaltyConsent() public {
        // Exact original correction/true-author acceptance, payout, policy, economics and attestations.
        testSustainedCorrectionActualSafeAcceptanceAndFreshMintPrerequisites();
        bytes32 declaration = ingress.platformWorksState(2).declaration.recordHash;
        require(
            ingress.consentMode(2) == 1 && ingress.platformWorksState(2).correction.accepted,
            "complete real corrected binding"
        );
        _platformElection();
        vm.expectRevert(
            abi.encodeWithSelector(T.MissingMintPrerequisite.selector, keccak256("economics"))
        );
        royalty.currentRoyaltySnapshotSource(2);
        T.AssignmentFact memory fact = royalty.currentArtistSnapshotRoyaltyAssignment(2);
        T.EconomicsConsent memory consent = T.EconomicsConsent(
            2, address(royalty), keccak256("ROYALTY_ERC2981"), 1, 2, fact.assignmentHash
        );
        T.Authorization memory a = _authorization(false);
        a.signature = _signature(ingress.economicsConsentDigest(consent, a));
        bytes32 record = ingress.recordEconomicsConsent(consent, a);
        IStreamRoyaltySnapshot.Source memory source = royalty.currentRoyaltySnapshotSource(2);
        require(
            record != 0 && source.modeAssignmentHash == fact.assignmentHash
                && source.sourceAssignmentHash != fact.assignmentHash
                && ingress.platformWorksState(2).declaration.recordHash == declaration
                && ingress.platformWorksState(2).contestState == 3,
            "original Safe op15 restores new mode; history stays"
        );
    }
}
