// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./ArtistPrimaryCollaboratorFixture.sol";
import {
    StreamArtistRecoveredHydrationSource as CHProvenance
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationSource.sol";
import {
    StreamArtistCompleteHistoryCatalogue as CHCatalogue
} from "../../../smart-contracts/domains/artist/StreamArtistCompleteHistoryCatalogue.sol";
import {
    StreamArtistCompleteHistoryBindingSource as CHBindings
} from "../../../smart-contracts/domains/artist/StreamArtistCompleteHistoryBindingSource.sol";
import {
    StreamArtistCompleteHistoryBindingProof as CHBindingProof
} from "../../../smart-contracts/domains/artist/StreamArtistCompleteHistoryBindingProof.sol";
import {
    StreamArtistCompleteHistoryCollaborators as CHCollaborators
} from "../../../smart-contracts/domains/artist/StreamArtistCompleteHistoryCollaborators.sol";
import {
    StreamArtistCompleteHistoryClocks as CHClocks
} from "../../../smart-contracts/domains/artist/StreamArtistCompleteHistoryClocks.sol";
import {
    StreamArtistPrimaryCollaboratorClocks as PCClocks
} from "../../../smart-contracts/domains/artist/StreamArtistPrimaryCollaboratorClocks.sol";
import {
    StreamArtistCompleteHistoryAcceptance as CHAcceptance
} from "../../../smart-contracts/domains/artist/StreamArtistCompleteHistoryAcceptance.sol";
import {
    StreamArtistCompleteHistoryPlatformSource as CHPlatform
} from "../../../smart-contracts/domains/artist/StreamArtistCompleteHistoryPlatformSource.sol";
import {
    StreamArtistRecoveredPlatformTypes as CHP
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredPlatformTypes.sol";
import {
    StreamArtistRecoveredAcceptedGenerationTypes as CHA
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredAcceptedGenerationTypes.sol";
import {
    StreamArtistRecoveredSanctionHistoryTypes as CHH
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredSanctionHistoryTypes.sol";

/// @notice Real original owners, Archive and threshold Safes produce each latest head.
/// @dev These source-family scenarios retain inherited Core/governance unit boundaries.
/// They do not claim operation60 integration or execution until the combined suite runs.
contract StreamArtistCompleteHistoryChronologyActualTest is ArtistPrimaryCollaboratorFixture {
    struct Observed {
        M.State scope;
        RH.Provenance provenance;
        PC.BindingInventory bindings;
        PC.Inventory archive;
        CHP.Platform[] platforms;
        PCClocks.Result clocks;
        CHA.AcceptanceBundle[] accepted;
    }

    function testCompleteHistoryLatestPendingHeadAtGenuineCutover() external {
        _pendingSource(0);
        _multiCutover();
        Observed memory x = _observe();
        require(!x.bindings.bindings[1].bindings.current.accepted, "original pending head");
        require(x.accepted[1].rows[0].recordHash == 0, "no fabricated primary acceptance");
        require(
            x.clocks.clocks.collections[1].completions[0].environmentHash == 0,
            "pending has no completion clock"
        );
        require(x.clocks.clocks.counts[0] == 3, "two proposals and accepted sibling completion");
    }

    function testCompleteHistoryLatestPrimaryPartialPreservesOriginalSavedMap() external {
        _pendingSource(1);
        _multiCutover();
        Observed memory x = _observe();
        require(!x.bindings.bindings[1].bindings.current.accepted, "collaborator still pending");
        require(x.accepted[1].rows[0].recordHash == pcPrimary[0], "authentic partial primary map");
        require(x.accepted[1].rows[0].acceptedAt != 0, "original primary acceptance time");
        require(x.clocks.accepted[1][0] == 0, "no fabricated collaborator acceptance");
        require(
            x.clocks.clocks.collections[1].completions[0].environmentHash == 0,
            "primary receipt does not imply full binding completion"
        );
    }

    function testCompleteHistoryLatestCollaboratorPartialPreservesJoinWithoutPrimary() external {
        _pendingSource(2);
        _multiCutover();
        Observed memory x = _observe();
        require(!x.bindings.bindings[1].bindings.current.accepted, "primary still pending");
        require(
            x.clocks.accepted[1][0] == 1 && x.archive.accepted.length == 1,
            "actual collaborator count and receipt"
        );
        require(
            x.archive.accepted[0].join.artistId == collaboratorId,
            "ordinary collaborator retains original identity"
        );
        require(x.accepted[1].rows[0].recordHash == 0, "primary remains absent");
    }

    function testCompleteHistoryLatestRefusedPreservesPartialJoinAndTerminalClock() external {
        _pendingSource(3);
        _multiCutover();
        Observed memory x = _observe();
        require(
            x.bindings.bindings[1].bindings.rows[0].terminal.kind == 1,
            "original latest refusal retained"
        );
        require(
            x.clocks.accepted[1][0] == 1 && x.accepted[1].rows[0].recordHash == 0,
            "refusal does not discard partial original acceptance"
        );
        require(
            x.clocks.clocks.collections[1].completions[0].environmentHash != 0,
            "authentic refusal completion clock"
        );
    }

    function testCompleteHistoryLatestWithdrawnPreservesPrimaryReceiptAndTerminal() external {
        _pendingSource(4);
        _multiCutover();
        Observed memory x = _observe();
        require(
            x.bindings.bindings[1].bindings.rows[0].terminal.kind == 2,
            "original latest withdrawal retained"
        );
        require(
            x.bindings.bindings[1].bindings.rows[0].terminal.recordHash == 0,
            "withdrawal has no invented native record"
        );
        require(
            x.accepted[1].rows[0].recordHash == pcPrimary[0],
            "terminal head retains real partial primary map"
        );
    }

    function testCompleteHistoryLatestPendingRetainsBothPrimaryOccurrencesAfterRecovery() external {
        _pendingSource(1);
        _pcPrimaryAccept();
        _multiCutover();
        Observed memory x = _observe();
        require(
            pcPrimary.length == 2 && pcPrimary[0] != pcPrimary[1],
            "genuine original authority change yields distinct receipts"
        );
        require(
            x.clocks.primary.length == 3 && x.clocks.finalPrimary[1][0] == pcPrimary[1],
            "all native occurrences and exact final map"
        );
        require(
            !x.bindings.bindings[1].bindings.current.accepted,
            "repeated primary still cannot substitute for collaborator acceptance"
        );
        x.accepted[1].rows[0].recordHash = pcPrimary[0];
        avm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        CHAcceptance.validate(x.accepted, x.scope, x.provenance, x.bindings, x.archive, x.clocks);
    }

    function testCompleteHistoryLatestPendingRejectsOmittedOriginalArchiveOperation() external {
        _pendingSource(2);
        _multiCutover();
        Observed memory x = _observe();
        CHH.OperationEvidence[] memory omitted =
            new CHH.OperationEvidence[](x.archive.operations.length - 1);
        for (uint256 i; i < omitted.length; ++i) {
            omitted[i] = x.archive.operations[i];
        }
        x.archive.operations = omitted;
        avm.expectRevert(RH.InvalidRecoveredHydrationProfile.selector);
        CHClocks.validate(x.scope, x.provenance, x.bindings, x.archive, x.platforms);
    }

    function _pendingSource(uint8 mode) internal {
        _pcIdentity();
        C.BindingAcceptance memory row = _pcPropose();
        if (mode == 1 || mode == 4) _pcPrimaryAccept();
        if (mode == 2 || mode == 3) _pcAccept(row, false);
        if (mode == 3) _pcRefuse();
        if (mode == 4) {
            T.Binding memory b = Binding(suite.owners[0]).binding(2);
            ingress.withdrawArtistBinding(
                L.Termination(
                    2,
                    b.generation,
                    b.bindingHash,
                    keccak256("original latest withdrawal"),
                    "urn:complete-history:withdrawal"
                )
            );
            _rhCandidate(
                0,
                "binding_lifecycle.replay.proposal_terminal_transition_key",
                keccak256(abi.encode(uint256(2), b.generation))
            );
        }
        _rhBaseline();
        _adoptRotatedSafe();
        vm.warp(ingress.artistTransitionState(rhRecovery).postWindowEndsAt);
        multiRecovery = [rhRecovery, rhRecovery];
        multiCollectionArtists = [artistId, artistId];
        multiArtists = new bytes32[](2);
        multiArtists[0] = artistId < collaboratorId ? artistId : collaboratorId;
        multiArtists[1] = artistId < collaboratorId ? collaboratorId : artistId;
    }

    function _observe() internal view returns (Observed memory x) {
        RH.Request memory r = _rhRequest();
        x.provenance =
            CHProvenance.collect(suite, address(coordinator), r.records.authority.replayOrigins);
        x.scope.artists = new AH.Query[](multiArtists.length);
        for (uint256 i; i < multiArtists.length; ++i) {
            x.scope.artists[i].artistId = multiArtists[i];
        }
        x.scope.collections = new AH.Query[](2);
        for (uint256 k; k < 2; ++k) {
            T.Binding memory b = Binding(suite.owners[0]).binding(k + 1);
            x.scope.collections[k].collectionId = k + 1;
            x.scope.collections[k].artistId = b.artistId;
            x.scope.collections[k].bindingHash = b.bindingHash;
        }
        x.bindings =
            CHBindings.collect(suite.owners[0], x.scope, RH.ownerProvenance(x.provenance, 0));
        (x.archive.catalogues, x.archive.operations) = CHCatalogue.collect(x.provenance);
        x.archive =
            CHCollaborators.collect(x.provenance, x.archive.catalogues, x.archive.operations);
        x.platforms = CHPlatform.collect(
            suite.owners[4],
            x.scope,
            RH.ownerProvenance(x.provenance, 4),
            x.archive.catalogues,
            x.archive.operations
        );
        x.clocks = CHClocks.validate(x.scope, x.provenance, x.bindings, x.archive, x.platforms);
        CHBindingProof.validate(
            x.scope, RH.ownerProvenance(x.provenance, 0), x.bindings, x.archive, x.clocks
        );
        x.accepted = CHAcceptance.collect(
            suite.owners[3], x.scope, x.provenance, x.bindings, x.archive, x.clocks
        );
    }
}
