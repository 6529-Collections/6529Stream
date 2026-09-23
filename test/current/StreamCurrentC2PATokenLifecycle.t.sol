// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/CurrentC2PATokenLifecycleFixture.sol";

/// @notice Current C2PA adoption and literal output using original authority/record producers.
contract StreamCurrentC2PATokenLifecycleTest is CurrentC2PATokenLifecycleFixture {
    function setUp() public {
        _constructC2PAToken();
    }

    function testActualCredentialVerifierReceiptAdoptionAndFullTokenRendering() public {
        CR.Report memory p = _report(tokenSubject, CR.AuthorshipStatus.CONSISTENT);
        bytes32 hash = _publish(p, verifierSafe, 6);
        bytes32 authorityBefore = _artistOwnersHash();
        CR.Selection memory selected = _adopt(p, hash, 0, 0);
        require(
            _artistOwnersHash() == authorityBefore, "verifier adoption cannot mutate Artist owners"
        );
        _assertC2PAOutput(hash, tokenSubject, "valid", "consistent", true, "none", false);
        vm.expectRevert(abi.encodeWithSelector(CR.C2PASelectionConflict.selector));
        c2pa.reconciliation.adopt(2, tokenSubject, hash, selected.selectionHash, 1);
        require(
            keccak256(abi.encode(c2pa.reconciliation.currentSelection(2, tokenSubject)))
                == keccak256(abi.encode(selected)),
            "adoption replay preserves historical selection"
        );
    }

    function testActualVerifierGrantFailureThenByteIdenticalSafePublicationAndAdoption() public {
        CR.Report memory p = _report(tokenSubject, CR.AuthorshipStatus.CONSISTENT);
        Records.CollectionRecord memory r = _recordInput(p);
        bytes32 hash = _recordHash(verifierSafe, r);
        bytes memory exact = _tokenPayload(
            verifierSafe,
            address(assemblyMetadata),
            0,
            abi.encodeCall(
                assemblyMetadata.recordCollectionRecordWithPayload, (uint256(2), r, abi.encode(p))
            )
        );
        _verifierGrant(verifierSafe, 6, false);
        _tokenFailure(verifierSafe, exact);
        (bytes32 chain, uint64 count) =
            assemblyMetadata.recordChainHash(2, keccak256("C2PA_VALIDATION"));
        require(
            count == 0 && chain == 0
                && assemblyMetadata.latestCollectionRecordHashFor(
                    2, keccak256("C2PA_VALIDATION"), tokenSubject, address(verifierSafe)
                ) == 0 && c2pa.reconciliation.currentSelection(2, tokenSubject).selectionHash == 0,
            "denied recorder leaves exact original empty history"
        );
        _verifierGrant(verifierSafe, 6, true);
        vm.recordLogs();
        _tokenSuccess(verifierSafe, exact);
        _checkPublished(p, verifierSafe, 6, hash, vm.getRecordedLogs());
        _adopt(p, hash, 0, 0);
        _assertC2PAOutput(hash, tokenSubject, "valid", "consistent", true, "none", false);
    }

    function testWrongOriginalRecorderAndClassEightReceiptsNeverBecomeVerifierAuthority() public {
        _verifierGrant(otherSafe, 6, true);
        CR.Report memory wrong = _report(tokenSubject, CR.AuthorshipStatus.CONSISTENT);
        bytes32 wrongHash = _publish(wrong, otherSafe, 6);
        vm.expectRevert(abi.encodeWithSelector(CR.InvalidC2PAReport.selector));
        c2pa.reconciliation.adopt(2, tokenSubject, wrongHash, 0, 0);
        _verifierGrant(verifierSafe, 6, false);
        _verifierGrant(verifierSafe, 8, true);
        CR.Report memory elevated = _report(tokenSubject, CR.AuthorshipStatus.CONSISTENT);
        bytes32 elevatedHash = _publish(elevated, verifierSafe, 8);
        vm.expectRevert(abi.encodeWithSelector(CR.InvalidC2PAReport.selector));
        c2pa.reconciliation.adopt(2, tokenSubject, elevatedHash, 0, 0);
        require(
            c2pa.reconciliation.currentSelection(2, tokenSubject).revision == 0
                && c2pa.reconciliation.standingConflict(2, tokenSubject).revision == 0,
            "no invented report or adverse selection"
        );
        _verifierGrant(verifierSafe, 8, false);
        _verifierGrant(verifierSafe, 6, true);
        CR.Report memory right = _report(tokenSubject, CR.AuthorshipStatus.CONSISTENT);
        bytes32 hash = _publish(right, verifierSafe, 6);
        _adopt(right, hash, 0, 0);
        _assertC2PAOutput(hash, tokenSubject, "valid", "consistent", true, "none", false);
    }

    function testOriginalDivergenceSurvivesVerifierSupersessionAndCredentialWithdrawal() public {
        CR.Report memory p = _report(tokenSubject, CR.AuthorshipStatus.DIVERGENT);
        bytes32 hash = _publish(p, verifierSafe, 6);
        CR.Selection memory first = _adopt(p, hash, 0, 0);
        CF.Standing memory empty;
        CF.Conflict memory conflict = _assertConflict(first, empty);
        _assertC2PAOutput(hash, tokenSubject, "valid", "divergent", true, "standing", true);
        CR.Report memory corrected = _report(tokenSubject, CR.AuthorshipStatus.CONSISTENT);
        bytes32 next = _publish(corrected, verifierSafe, 6);
        _assertC2PAOutput(hash, tokenSubject, "unevaluated", "unevaluated", false, "standing", true);
        _adopt(corrected, next, first.selectionHash, 1);
        _assertC2PAOutput(next, tokenSubject, "valid", "consistent", true, "standing", true);
        credential = _credentials(true);
        _assertC2PAOutput(next, tokenSubject, "unevaluated", "unevaluated", false, "standing", true);
        require(
            keccak256(abi.encode(c2pa.reconciliation.conflictRecord(conflict.conflictId)))
                    == keccak256(abi.encode(conflict))
                && c2pa.reconciliation.standingConflict(2, tokenSubject).unresolvedCount == 1
                && c2pa.reconciliation.conflictResolution(conflict.conflictId).actionId == 0,
            "report and credential changes never erase adverse history"
        );
    }

    function testActualTokenSelectionTakesPrecedenceOverCurrentCollectionReportEvenWhenStale()
        public
    {
        CR.Report memory collection = _report(collectionSubject, CR.AuthorshipStatus.CONSISTENT);
        bytes32 collectionHash = _publish(collection, verifierSafe, 6);
        _adopt(collection, collectionHash, 0, 0);
        _assertC2PAOutput(
            collectionHash, collectionSubject, "valid", "consistent", true, "none", false
        );
        CR.Report memory token = _report(tokenSubject, CR.AuthorshipStatus.DIVERGENT);
        bytes32 tokenHash = _publish(token, verifierSafe, 6);
        CR.Selection memory tokenSelection = _adopt(token, tokenHash, 0, 0);
        CF.Standing memory empty;
        _assertConflict(tokenSelection, empty);
        _assertC2PAOutput(tokenHash, tokenSubject, "valid", "divergent", true, "standing", true);
        _publish(_report(tokenSubject, CR.AuthorshipStatus.CONSISTENT), verifierSafe, 6);
        require(
            c2pa.reconciliation.display(2, collectionSubject).current, "collection remains current"
        );
        _assertC2PAOutput(
            tokenHash, tokenSubject, "unevaluated", "unevaluated", false, "standing", true
        );
    }

    function _artistOwnersHash() private view returns (bytes32 hash) {
        T.Snapshot[7] memory snapshots;
        for (uint256 i; i < 7; ++i) {
            snapshots[i] = IStreamArtistOwner(artistSuite.owners[i]).ownerStateSnapshotV2();
        }
        hash = keccak256(abi.encode(snapshots));
    }

    function testActualDualFamilyEvidenceOriginalOp46AndIdenticalSafeAcknowledgementRetry() public {
        CR.Report memory p = _report(tokenSubject, CR.AuthorshipStatus.DIVERGENT);
        bytes32 hash = _publish(p, verifierSafe, 6);
        CR.Selection memory selected = _adopt(p, hash, 0, 0);
        CF.Standing memory empty;
        CF.Conflict memory conflict = _assertConflict(selected, empty);
        _resolveConflictWithExactRetry(conflict);
        require(
            keccak256(abi.encode(c2pa.reconciliation.conflictRecord(conflict.conflictId)))
                == keccak256(abi.encode(conflict)),
            "original divergent report retained after acknowledgement"
        );
        _assertC2PAOutput(hash, tokenSubject, "valid", "divergent", true, "acknowledged", false);
    }
}
