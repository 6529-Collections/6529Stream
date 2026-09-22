// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./ArtistCompleteHistoryChronologyFixture.sol";

contract StreamArtistCompleteHistoryChronologyActualTest is ArtistCompleteHistoryChronologyFixture {
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
}
