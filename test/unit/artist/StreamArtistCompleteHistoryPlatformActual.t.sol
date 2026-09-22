// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./ArtistUnboundPlatformFixture.sol";
import {
    StreamArtistCompleteHistoryPlatformSource as CHPlatform
} from "../../../smart-contracts/domains/artist/StreamArtistCompleteHistoryPlatformSource.sol";
import {
    StreamArtistCompleteHistoryCatalogue as CHCatalogue
} from "../../../smart-contracts/domains/artist/StreamArtistCompleteHistoryCatalogue.sol";
import {
    StreamArtistCompleteHistoryBindingSource as CHBinding
} from "../../../smart-contracts/domains/artist/StreamArtistCompleteHistoryBindingSource.sol";
import {
    StreamArtistCompleteHistoryClocks as CHClocks
} from "../../../smart-contracts/domains/artist/StreamArtistCompleteHistoryClocks.sol";
import {
    StreamArtistRecoveredHydrationSource as CHProvenance
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationSource.sol";
import {
    StreamArtistPrimaryCollaboratorTypes as CHPC
} from "../../../smart-contracts/domains/artist/StreamArtistPrimaryCollaboratorTypes.sol";
import {
    StreamArtistPrimaryCollaboratorClocks as CHOriginalClocks
} from "../../../smart-contracts/domains/artist/StreamArtistPrimaryCollaboratorClocks.sol";
import {
    StreamArtistBindingLifecycleTypes as CHLifecycle
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistBindingLifecycleTypes.sol";

/// @notice Actual producer family oracles for the new shared chronology, without a hydration claim.
/// @dev The original Platform, Binding, Identity and Archive writers run unchanged. Inherited
/// Core, governance scheduling and document coverage remain the fixture's typed boundaries.
contract StreamArtistCompleteHistoryPlatformActualTest is ArtistUnboundPlatformFixture {
    struct Captured {
        M.State scope;
        RH.Provenance provenance;
        CHPC.Inventory archive_;
        CHPC.BindingInventory bindings;
        P.Platform[] platforms;
        CHOriginalClocks.Result clocks;
    }

    function testCompletePlatformCollectorSeparatesAllOriginalCollectionSubjects() external {
        _upSource(true);
        bytes32 claim = _hpClaim(false);
        bytes32 allegation = _hpClaim(true);
        _hpContest(1, claim, false);
        _hpContest(2, claim, false);
        Captured memory captured = _capture();
        require(
            captured.platforms.length == 2 && P.nativeCount(captured.platforms[0]) == 0
                && captured.platforms[0].collectionId == 1
                && captured.platforms[1].collectionId == 2
                && captured.platforms[1].claims[0].record.recordHash == claim
                && captured.platforms[1].latestDisplayClaim == allegation
                && captured.platforms[1].contests.length == 2,
            "one complete journal partition, no invented Platform sibling"
        );
        require(
            captured.platforms[1].catalogues.length == 0
                && captured.platforms[1].operations.length == 0
                && captured.archive_.catalogues.length == 1,
            "single shared complete Archive inventory"
        );
    }

    function testCompletePlatformChronologyKeepsApprovedUnusedCorrection() external {
        _approvedPlatform();
        Captured memory captured = _capture();
        require(
            captured.bindings.generations[0].length == 0
                && captured.platforms[0].state.correction.recordHash != 0
                && captured.platforms[0].state.correction.correctiveGeneration == 0
                && !captured.platforms[0].state.correction.accepted,
            "genuine unbound approval without invented binding"
        );
    }

    function testCompletePlatformChronologyKeepsPendingOriginalRegisteredArtist() external {
        _approvedPlatform();
        _bindPlatform();
        Captured memory captured = _capture();
        require(
            captured.bindings.bindings[0].bindings.current.artistId == artistId
                && !captured.bindings.bindings[0].bindings.current.accepted
                && captured.platforms[0].state.correction.correctiveGeneration == 1
                && !captured.platforms[0].state.correction.accepted
                && captured.clocks.clocks.collections[0].completions[0].ownerRevision == 0
                && captured.clocks.clocks.collections[0].attributionProposals[0].ownerRevision != 0,
            "real registration, consumed correction and unfinished head"
        );
    }

    function testCompletePlatformChronologyKeepsLatestWithdrawnOriginalCorrection() external {
        _approvedPlatform();
        _bindPlatform();
        CHLifecycle.Termination memory terminal = _termination(1);
        ingress.withdrawArtistBinding(terminal);
        _rhCandidate(
            0,
            "binding_lifecycle.replay.proposal_terminal_transition_key",
            keccak256(abi.encode(uint256(1), uint64(1)))
        );
        Captured memory captured = _capture();
        require(
            captured.bindings.bindings[0].bindings.rows[0].terminal.kind == 2
                && captured.clocks.clocks.collections[0].completions[0].ownerRevision != 0
                && captured.platforms[0].state.correction.correctiveGeneration == 1
                && !captured.platforms[0].state.correction.accepted,
            "terminal latest head retains original Platform consumption"
        );
    }

    function testCompletePlatformAcceptedCorrectionKeepsLaterOriginalClaimState() external {
        _approvedPlatform();
        _bindPlatform();
        _rhBaseline();
        bytes32 claim = _hpClaim(false);
        Captured memory captured = _capture();
        require(
            captured.bindings.bindings[0].bindings.current.accepted
                && captured.platforms[0].state.correction.correctiveGeneration == 1
                && captured.platforms[0].state.correction.accepted
                && captured.platforms[0].status.effectiveAccepted
                && captured.platforms[0].claims.length == 2
                && captured.platforms[0].latestDisplayClaim == claim
                && captured.clocks.clocks.collections[0].completions[0].ownerRevision != 0,
            "later Platform state root retains actual binding consumption and acceptance"
        );
    }

    function testCompletePlatformCollectorRejectsOmittedUnboundSubject() external {
        _upSource(true);
        Captured memory captured = _capture();
        AH.Query[] memory omitted = new AH.Query[](1);
        omitted[0] = captured.scope.collections[0];
        captured.scope.collections = omitted;
        avm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        this.chCollect(captured);
    }

    function testCompletePlatformChronologyRejectsForgedConsumedGeneration() external {
        _approvedPlatform();
        _bindPlatform();
        Captured memory captured = _capture();
        captured.platforms[0].state.correction.correctiveGeneration = 2;
        avm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        this.chClocks(captured);
    }

    function testCompletePlatformPostReadRejectsFreshOriginalClaim() external {
        _upSource(false);
        Captured memory captured = _capture();
        _hpClaim(true);
        avm.expectRevert(RH.InvalidRecoveredHydrationProvenance.selector);
        this.chCurrent(captured);
    }

    function chCollect(Captured calldata captured) external view {
        CHPlatform.collect(
            suite.owners[4],
            captured.scope,
            RH.ownerProvenance(captured.provenance, 4),
            captured.archive_.catalogues,
            captured.archive_.operations
        );
    }

    function chClocks(Captured calldata captured) external view {
        CHClocks.validate(
            captured.scope,
            captured.provenance,
            captured.bindings,
            captured.archive_,
            captured.platforms
        );
    }

    function chCurrent(Captured calldata captured) external view {
        CHPlatform.requireCurrent(
            suite.owners[4],
            captured.scope,
            RH.ownerProvenance(captured.provenance, 4),
            captured.archive_.catalogues,
            captured.archive_.operations,
            captured.platforms
        );
    }

    function _approvedPlatform() private {
        _upSource(false);
        bytes32 claim = _hpClaim(false);
        _hpContest(1, claim, false);
        _hpContest(3, claim, false);
        _hpContest(3, claim, true);
    }

    function _bindPlatform() private {
        T.BindingProposal memory proposal = _proposal(0);
        (artistId,) = ingress.proposeArtistBinding(
            1, proposal, bytes("unit identity document"), "Artist Safe"
        );
        _rhCandidate(
            0, "binding_lifecycle.replay.proposal_key", keccak256(abi.encode(uint256(1), uint64(1)))
        );
        _rhCandidate(
            2,
            "identity_authority.replay.nonce_allocator",
            keccak256(abi.encode(bytes32(0), uint256(0)))
        );
    }

    function _capture() private view returns (Captured memory captured) {
        RH.Request memory request = _rhRequest();
        captured.provenance = CHProvenance.collect(
            suite, address(coordinator), request.records.authority.replayOrigins
        );
        captured.scope.artists = new AH.Query[](artistId == 0 ? 0 : 1);
        if (artistId != 0) captured.scope.artists[0].artistId = artistId;
        captured.scope.collections = new AH.Query[](upMixed ? 2 : 1);
        for (uint256 k; k < captured.scope.collections.length; ++k) {
            T.Binding memory bound = Binding(suite.owners[0]).binding(k + 1);
            captured.scope.collections[k].collectionId = k + 1;
            captured.scope.collections[k].artistId = bound.artistId;
            captured.scope.collections[k].bindingHash = bound.bindingHash;
        }
        (captured.archive_.catalogues, captured.archive_.operations) =
            CHCatalogue.collect(captured.provenance);
        captured.platforms = CHPlatform.collect(
            suite.owners[4],
            captured.scope,
            RH.ownerProvenance(captured.provenance, 4),
            captured.archive_.catalogues,
            captured.archive_.operations
        );
        captured.bindings = CHBinding.collect(
            suite.owners[0], captured.scope, RH.ownerProvenance(captured.provenance, 0)
        );
        captured.clocks = CHClocks.validate(
            captured.scope,
            captured.provenance,
            captured.bindings,
            captured.archive_,
            captured.platforms
        );
    }
}
